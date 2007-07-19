#  Import.tcl ---
#  
#      This file is part of The Coccinella application. It implements image
#      and movie stuff.
#      
#  Copyright (c) 2002-2005  Mats Bengtsson
#  
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#  
# $Id: Import.tcl,v 1.28 2007-07-19 06:28:19 matben Exp $

package require http
package require httpex

package provide Import 1.0

namespace eval ::Import:: {
    
    # Filter all canvas commands to see if anyone related to anything
    # just being transported but not yet in canvas.
    ::hooks::register whiteboardPostCanvasDraw   ::Import::TrptCachePostDrawHook
    
    # Specials for 'xanim'
    variable xanimPipe2Frame 
    variable xanimPipe2Item
        
    variable locals
    set locals(httpuid) 0
}

# Import::ImportImageOrMovieDlg --
#
#       Handles the dialog of opening a file ans then lets 
#       'DoImport' do the rest. On Mac either file extension or 
#       'type' must match.
#       
# Arguments:
#       wcan        canvas widget
#       
# Results:
#       Defines option arrays and icons for movie controllers.

proc ::Import::ImportImageOrMovieDlg {wcan} {    
    global  prefs    
    
    set userDir [::Utils::GetDirIfExist $prefs(userPath)]
    set opts [list -initialdir $userDir]
    set fileName [eval {tk_getOpenFile -title [mc {Open Image/Movie}] \
      -filetypes [::Plugins::GetTypeListDialogOption all]} $opts]
    if {$fileName eq ""} {
	return
    }
    set prefs(userPath) [file dirname $fileName]
    
    # Once the file name is chosen continue...
    # Perhaps we should dispatch to the registered import procedure for
    # this MIME type.
    set mime [::Types::GetMimeTypeForFileName $fileName]
    if {[::Plugins::HaveImporterForMime $mime]} {
	set opts [list -coords [::CanvasUtils::NewImportAnchor $wcan]]	
	set errMsg [::Import::DoImport $wcan $opts -file $fileName]
	if {$errMsg ne ""} {
	    ::UI::MessageBox -title [mc Error] -icon error -type ok \
	      -message "Failed importing: $errMsg"
	}
    } else {
	::UI::MessageBox -title [mc Error] -icon error -type ok \
	  -message [mc messfailmimeimp $mime]
    }
}

# Import::DoImport --
# 
#       Dispatches importing images/audio/video etc., to the whiteboard.  
#       There shall be a registered import procedure for the mime type
#       to be imported. It may import from local disk (-file) or remotely
#       (-url). 
#
# Arguments:
#       wcan      the canvas widget path.
#       opts      a list of '-key value' pairs, and everything is on 
#                 a single line.
#       args:          
#            -file      the complete absolute and native path name to the file 
#                       containing the image or movie.
#            -data      base64 encoded data (preliminary)
#            -url       complete URL, then where="local".
#            -where     "all": write to this canvas and all others,
#                       "remote": write only to remote client canvases,
#                       "local": write only to this canvas and not to any other.
#                       ip number: write only to this remote client canvas and 
#                       not to own.
#            -commmand  a callback command for errors that cannot be reported
#                       right away, using -url http for instance.
#            -progress  progress command if using -url
#            -addundo   (0|1)  shall this command be added to the undo stack
#       
# Side Effects:
#       Shows the image or movie in canvas and initiates transfer to other
#       clients if requested.
#       
# Results:
#       an error string which is empty if things went ok so far.

proc ::Import::DoImport {wcan opts args} {
    global  prefs this
    
    ::Debug 2 "DoImport:: opts=$opts \n\t args='$args'"
    
    array set argsArr {
	-where      all
	-addundo    1
    }
    array set argsArr $args
    
    # We must have exactly one of -file, -data, -url.
    set haveSource 0
    foreach {key value} [array get argsArr] {
	switch -- $key {
	    -file - -data - -url {
		if {$haveSource} {
		    return -code error  \
		      "::Import::DoImport needs one of -file, -data, or -url"
		}
		set haveSource 1
	    }
	}
    }    
    if {!$haveSource} {
	return -code error "::Import::DoImport needs -file, -data, or -url"
    }
    if {[info exists argsArr(-url)]} {
	set isLocal 0
    } else {
	set isLocal 1
    }
    set w [winfo toplevel $wcan]
    set errMsg ""
        
    # Define a standard set of put/import options that may be overwritten by
    # the options in the procedure argument 'opts'.
    
    if {$isLocal} {
	set fileName $argsArr(-file)
	
	# Verify that it exists.
	if {!([file exists $fileName] && [file isfile $fileName])} {
	    return "The file \"$fileName\" not found"
	}
	
	# An ordinary file on our disk.
	array set optArr [list   \
	  -mime     [::Types::GetMimeTypeForFileName $fileName] \
	  -size     [file size $fileName]                       \
	  -coords   [::CanvasUtils::NewImportAnchor $wcan]         \
	  -tags     [::CanvasUtils::NewUtag]]
    } else {
	    
	# This was an Url.
	set fileName [::Utils::GetFilePathFromUrl $argsArr(-url)]
	array set optArr [list   \
	  -mime     [::Types::GetMimeTypeForFileName $fileName]   \
	  -coords   {0 0}                                         \
	  -tags     [::CanvasUtils::NewUtag]]
    }
    set fileTail [file tail $fileName]
    
    # Now apply the 'opts' and possibly overwrite some of the default options.
    array set optArr $opts
        
    # Extract tags which must be there. error checking?
    set useTag $optArr(-tags)
    
    # Depending on the MIME type do different things; the MIME type is the
    # primary key for classifying the file. 
    # Note: image/* always through tk's photo handler; package neutral.
    set mime $optArr(-mime)
    regexp {([^/]+)/([^/]+)} $mime match mimeBase mimeSubType
    
    # Find import package if any for this MIME type.
    set importPackage [::Plugins::GetPreferredPackageForMime $mime]
    if {$importPackage eq ""} {
	return "No importer found for the file \"$fileTail\" with\
	  MIME type $mime"
    }
    
    # Images are dispatched internally by tk's photo command.
    if {[string equal $mimeBase "image"]} {
	set importer "image"
    } else {
	set importer $importPackage
    }    
    if {$argsArr(-where) eq "all" || $argsArr(-where) eq "local"} {
	set drawLocal 1
    } else {
	set drawLocal 0
    }
    if {![string equal $argsArr(-where) "local"]} {
	set doPut 1
    } else {
	set doPut 0
    }
    
    switch -- $importer {
	image {
	    
	    if {![info exists optArr(-image)]} {
		set optArr(-image) [::CanvasUtils::UniqueImageName]
	    }
	    set putOpts [array get optArr]
	    
	    # Either '-file localPath', '-data bytes', or '-url http://...'
	    if {$drawLocal} {
		if {$isLocal} {
		    set errMsg [eval {
			DrawImage $wcan putOpts
		    } [array get argsArr]]
		} else {
		    HttpGet2 $w $argsArr(-url) $putOpts
		}
	    }
	}
	QuickTimeTcl {	    

	    # Let the receiving client be able to load async over http
	    # via QuickTime for instance.
	    set optArr(-preferred-transport) "http"
	    set putOpts [array get optArr]
	    if {$drawLocal} {
		if {$isLocal} {
		    set errMsg [eval {
			DrawQuickTimeTcl $wcan putOpts
		    } [array get argsArr]]
		} else {
		    set errMsg [eval {
			HttpGetQuickTimeTcl $w $argsArr(-url) $putOpts
		    } [array get argsArr]]
			
		    # Perhaps there shall be an option to get QT stuff via
		    # http without streaming it?
		    if {0} {
			HttpGet2 $w $argsArr(-url) $putOpts
		    }
		}
	    }
	}
	snack {

	    # Let the receiving client be able to load async over http
	    # via QuickTime for instance.
	    set optArr(-preferred-transport) "http"
	    set putOpts [array get optArr]
	    if {$drawLocal} {
		if {$isLocal} {
		    set errMsg [eval {
			DrawSnack $wcan putOpts
		    } [array get argsArr]]
		} else {
		    HttpGet2 $w $argsArr(-url) $putOpts
		}    
	    }
	}	    
	xanim {	    

	    # Let the receiving client be able to load async over http
	    # via QuickTime for instance.
	    set optArr(-preferred-transport) "http"
	    set putOpts [array get optArr]
	    if {$drawLocal} {
		if {$isLocal} {
		    set errMsg [eval {
			DrawXanim $wcan putOpts
		    } [array get argsArr]]
		} else {
		    HttpGet2 $w $argsArr(-url) $putOpts
		}
	    }
	}
	default {
		
	    # Dispatch to any registerd importer for this MIME type.
	    set putOpts [array get optArr]
	    if {$drawLocal} {
		if {$isLocal} {
		    set importProc [::Plugins::GetImportProcForMime $mime]
		    set errMsg [eval {
			$importProc $wcan putOpts} [array get argsArr]]
		} else {
		    
		    # Find out if this plugin has registerd a special proc
		    # to get from http.
		    if {[::Plugins::HaveHTTPTransportForPlugin $importer]} {
			set impHTTPProc \
			  [::Plugins::GetHTTPImportProcForPlugin $importer]
			set errMsg [eval {
			    $impHTTPProc $w $argsArr(-url) $putOpts
			} [array get argsArr]]
		    } else {			
			HttpGet2 $w $argsArr(-url) $putOpts
		    }
		}    
	    }
	}
    }
    
    # Put to remote peers but require we did not fail ourself.   
    if {$doPut && ($errMsg eq "")} {	
	if {$isLocal} {
	    set optArr(-url) [::Utils::GetHttpFromFile $fileName]
	    set putOpts [array get optArr]
	    set putOpts [GetStackOptions $wcan $putOpts $useTag]
	    	    
	    # Either we use the put/get method with a new connection,
	    # or use standard http.
	    
	    switch -- $prefs(trptMethod) {
		putget {
		    set putArgs {}
		    if {$argsArr(-where) ne "all"} {
			lappend putArgs -where $argsArr(-where)
		    }
		    eval {::WB::PutFile $w $fileName $putOpts} $putArgs
		}
		http {
		    set id [$wcan find withtag $useTag]
		    set line [::CanvasUtils::GetOneLinerForAny $wcan $id  \
		      -uritype http]
		    
		    # There are a few things we should add from $opts.
		    array set impArr [lrange $line 3 end]
		    foreach key {-above -below -size} {
			if {[info exists optArr($key)]} {
			    set impArr($key) $optArr($key)
			}
		    }
		    set line [concat [lrange $line 0 2] [array get impArr]]
		    if {[llength $line]} {
			::WB::SendMessageList $w [list $line]
		    }
		}
	    }
	} else {
	    
	    # This fails if we have -url. Need 'import here. TODO!
	}
    }
    
    # Construct redo/undo entry.
    if {$argsArr(-addundo) && ($errMsg eq "")} {
	set redo [concat [list ::Import::DoImport $wcan $opts -addundo 0] $args]
	set undo [list ::CanvasUtils::Command $w [list delete $useTag]]
	undo::add [::WB::GetUndoToken $wcan] $undo $redo
    }
    return $errMsg
}

# Import::DrawImage --
# 
#       Draws the image in 'fileName' onto canvas, taking options
#       in 'opts' into account.
#       
# Arguments:
#       wcan        the canvas widget path.
#       optsVar     the *name* of the 'opts' variable.
#       args     -file
#                -data
#       
# Results:
#       an error string which is empty if things went ok.

proc ::Import::DrawImage {wcan optsVar args} {
    upvar $optsVar opts

    ::Debug 2 "::Import::DrawImage args='$args',\n\t opts=$opts"
    
    array set argsArr $args
    array set optArr $opts
    set errMsg ""
    
    # These are programming errors which are reported directly.
    if {![info exists argsArr(-file)] && ![info exists argsArr(-data)]} {
	return -code error "Missing both -file and -data options"
    }
    
    # Extract coordinates and tags which must be there. error checking?
    foreach {x y} $optArr(-coords) break
    set utag [::CanvasUtils::GetUtagFromTagList $optArr(-tags)]
    set theTags [list std image $utag]
    set mime $optArr(-mime)
    regexp {([^/]+)/([^/]+)} $mime match mimeBase mimeSubType
    set w [winfo toplevel $wcan]
    
    if {[info exists optArr(-image)]} {
	set imageName $optArr(-image)
    } else {
	set imageName [::CanvasUtils::UniqueImageName]
    }
        
    # Create internal image.
    if {[catch {
	eval {::WB::CreateImageForWtop $w $imageName} $args
    } err]} {
	return $err
    }
    
    # Treat if image should be zoomed.
    if {[info exists optArr(-zoom-factor)] && ($optArr(-zoom-factor) ne "")} {
	set zoomFactor $optArr(-zoom-factor)
	set newImName ${imageName}_zoom${zoomFactor}
	
	# Make new scaled image.
	image create photo $newImName
	::WB::AddImageToGarbageCollector $w $newImName
	if {$zoomFactor > 0} {
	    $newImName copy $imageName -zoom $zoomFactor
	} else {
	    $newImName copy $imageName -subsample [expr abs($zoomFactor)]
	}
	set imageName $newImName
    }
    set cmd [list create image $x $y -image $imageName -anchor nw  \
      -tags $theTags]
    set id [eval {$wcan} $cmd]
    
    # Handle stacking order. Need catch since relative items may not yet exist.
    if {[info exists optArr(-above)]} {
	catch {$wcan raise $utag $optArr(-above)}
    } 
    if {[info exists optArr(-below)]} {
	catch {$wcan lower $utag $optArr(-below)}
    }
    lappend opts -width [image width $imageName]  \
      -height [image height $imageName]

    # Cache options.
    set configOpts {}
    if {[info exists argsArr(-file)]} {
	lappend configOpts -file $argsArr(-file)
    }
    if {[info exists optArr(-url)]} {
	lappend configOpts -url $optArr(-url)
    }
    if {[info exists optArr(-zoom-factor)]} {
	lappend configOpts -zoom-factor $optArr(-zoom-factor)
    }
    eval {::CanvasUtils::ItemSet $w $id} $configOpts
    
    return $errMsg
}

# Import::DrawQuickTimeTcl --
# 
#       Draws a local QuickTime movie onto canvas.
#       If inside VFS file is first copied to tmp space.
#       
# Arguments:
#       wcan        the canvas widget path.
#       optsVar     the *name* of the 'opts' variable.
#       args
#
# Results:
#       an error string which is empty if things went ok.

proc ::Import::DrawQuickTimeTcl {wcan optsVar args} {
    global  this
    upvar $optsVar opts
    
    ::Debug 2 "::Import::DrawQuickTimeTcl args='$args'"
    
    array set argsArr $args
    array set optArr $opts
    set errMsg ""
    if {![info exists argsArr(-file)] && ![info exists argsArr(-data)]} {
	return -code error "Missing both -file and -data options"
    }
    if {[info exists argsArr(-data)]} {
	return -code error "Does not yet support -data option"
    }
    set fileName $argsArr(-file)
    
    # QuickTime doesn't know about VFS.
    set fs [file system $fileName]
    if {[lindex $fs 0] ne "native"} {
	set root [file rootname [file tail $fileName]]
	set tmp [::tfileutils::tempfile $this(tmpPath) $root]
	append tmp [file extension $fileName]
	file copy $fileName $tmp
	set fileName $tmp
    }
    
    # Extract coordinates and tags which must be there. error checking?
    foreach {x y} $optArr(-coords) break
    set utag [::CanvasUtils::GetUtagFromTagList $optArr(-tags)]
    set w [winfo toplevel $wcan]
    set wtopname [winfo name [winfo toplevel $wcan]]
    
    # Make a frame for the movie; need special class to catch 
    # mouse events.
    set uniqueName [::CanvasUtils::UniqueImageName]		
    set wfr $wcan.fr_${uniqueName}
    frame $wfr -height 1 -width 1 -bg gray40 -class QTFrame    
    set wmovie $wfr.m	

    if {[catch {movie $wmovie -file $fileName -controller 1} err]} {
	catch {destroy $wfr}
	return $err
    }
    
    set id [$wcan create window $x $y -anchor nw -window $wfr  \
      -tags [list frame $utag]]
    pack $wmovie -in $wfr -padx 3 -pady 3
    
    if {[info exists optArr(-above)]} {
	catch {$wcan raise $utag $optArr(-above)}
    }
    
    # 'fileName' can be the cached name. If -url use its tail instead.
    if {[info exists optArr(-url)]} {
	set name [::uriencode::decodefile [file tail  \
	  [::Utils::GetFilePathFromUrl $optArr(-url)]]]
    } else {
	set name $fileName
    }
    set qtBalloonMsg [::Import::QuickTimeBalloonMsg $wmovie $name]
    ::balloonhelp::balloonforwindow $wmovie $qtBalloonMsg
    lappend opts -width [winfo reqwidth $wmovie]  \
      -height [winfo reqheight $wmovie]

    # Cache options.
    set configOpts {}
    if {[info exists argsArr(-file)]} {
	
	# @@@ What if VFS?
	lappend configOpts -file $argsArr(-file)
    }
    if {[info exists optArr(-url)]} {
	lappend configOpts -url $optArr(-url)
    }
    eval {::CanvasUtils::ItemSet $w $id} $configOpts

    return $errMsg
}

# Import::QuickTimeBalloonMsg --
# 
#       Makes a text for balloon message for an mp3 typically.

proc ::Import::QuickTimeBalloonMsg {wmovie fileName} {
    
    set msg [file tail $fileName]
    if {[string equal [file extension $fileName] ".mp3"]} {
	array set userArr [$wmovie userdata]
	if {[info exists userArr(-artist)]} {
	    append msg "\nArtist: $userArr(-artist)"
	}
	if {[info exists userArr(-fullname)]} {
	    append msg "\nName: $userArr(-fullname)"
	}
    }
    array set qtTime [$wmovie gettime]
    set lenSecs [expr $qtTime(-movieduration)/$qtTime(-movietimescale)]
    set lenMin [expr $lenSecs/60]
    set secs [format "%02i" [expr $lenSecs % 60]]
    append msg "\nLength: ${lenMin}:$secs"
    return $msg
}

# Import::DrawSnack --
# 
#       Draws a local snack movie onto canvas. 
#       
# Arguments:
#       wcan        the canvas widget path.
#       optsVar  the *name* of the opts variable.
#       args
#
# Results:
#       an error string which is empty if things went ok.

proc ::Import::DrawSnack {wcan optsVar args} {
    upvar $optsVar opts
    variable snackSounds
    
    ::Debug 2 "::Import::DrawSnack args='$args'"
    
    array set argsArr $args
    array set optArr $opts
    set errMsg ""
    if {![info exists argsArr(-file)] && ![info exists argsArr(-data)]} {
	return -code error "Missing both -file and -data options"
    }
    if {[info exists argsArr(-data)]} {
	return -code error "Does not yet support -data option"
    }
    set fileName $argsArr(-file)
    
    # Extract coordinates and tags which must be there. error checking?
    foreach {x y} $optArr(-coords) break
    set utag [::CanvasUtils::GetUtagFromTagList $optArr(-tags)]
    set w [winfo toplevel $wcan]
    
    set uniqueName [::CanvasUtils::UniqueImageName]		
    
    # The snack plug-in for audio. Make a snack sound object.
    
    if {[catch {::snack::sound $uniqueName -file $fileName} err]} {
	return $err
    }
    lappend snackSounds($wcan) $uniqueName
    set wfr $wcan.fr_${uniqueName}
    frame $wfr -height 1 -width 1 -bg gray40 -class SnackFrame
    set wmovie $wfr.m
    ::moviecontroller::moviecontroller $wmovie -snacksound $uniqueName
    set id [$wcan create window $x $y -anchor nw -window $wfr  \
      -tags [list frame $utag]]
    pack $wmovie -in $wfr -padx 3 -pady 3
    update idletasks
    if {[info exists optArr(-above)]} {
	catch {$wcan raise $utag $optArr(-above)}
    }
    set fileTail [file tail $fileName]
    
    # 'fileName' can be the cached name. If -url use its tail instead.
    if {[info exists optArr(-url)]} {
	set name [::uriencode::decodefile [file tail  \
	  [::Utils::GetFilePathFromUrl $optArr(-url)]]]
    } else {
	set name $fileName
    }
    ::balloonhelp::balloonforwindow $wmovie $name
    
    lappend opts -width [winfo reqwidth $wmovie]  \
      -height [winfo reqheight $wmovie]

    # Cache options.
    set configOpts {}
    if {[info exists argsArr(-file)]} {
	lappend configOpts -file $argsArr(-file)
    }
    if {[info exists optArr(-url)]} {
	lappend configOpts -url $optArr(-url)
    }
    eval {::CanvasUtils::ItemSet $w $id} $configOpts

    return $errMsg
}

# Import::DrawXanim --
# 
#       Draws a local xanim movie onto canvas.
#       
# Arguments:
#       wcan        the canvas widget path.
#       optsVar     the *name* of the opts variable.
#       args
#
# Results:
#       an error string which is empty if things went ok.

proc ::Import::DrawXanim {wcan optsVar args} {
    upvar $optsVar opts
    
    variable xanimPipe2Frame 
    variable xanimPipe2Item
    
    ::Debug 2 "::Import::DrawXanim args='$args'"
    
    array set argsArr $args
    array set optArr $opts
    set errMsg ""
    if {![info exists argsArr(-file)] && ![info exists argsArr(-data)]} {
	return -code error "Missing both -file and -data options"
    }
    if {[info exists argsArr(-data)]} {
	return -code error "Does not yet support -data option"
    }
    set fileName $argsArr(-file)
    
    # Extract coordinates and tags which must be there. error checking?
    foreach {x y} $optArr(-coords) break
    set utag [::CanvasUtils::GetUtagFromTagList $optArr(-tags)]
    
    set uniqueName [::CanvasUtils::UniqueImageName]		
    set wfr $wcan.fr_${uniqueName}
    
    frame $wfr -height 1 -width 1 -bg gray40 -class XanimFrame
    
    # Special handling using the 'xanim' application:
    # First, query the size of the movie without starting it.
    set size [XanimQuerySize $fileName]
    if {[llength $size] != 2} {
	return
    }
    set width [lindex $size 0]
    set height [lindex $size 1]
    $wfr configure -width [expr $width + 6] -height [expr $height + 6]
    $wcan create window $x $y -anchor nw -window $wfr -tags [list frame $utag]
    
    # Make special frame for xanim to draw in.
    set frxanim [frame $wfr.xanim -container 1 -bg black  \
      -width $width -height $height]
    place $frxanim -in $wfr -anchor nw -x 3 -y 3
    if {[info exists optArr(-above)]} {
	catch {$wcan raise $utag $optArr(-above)}
    }
    
    # Important, make sure that the frame is mapped before continuing.
    update idletasks
    set xatomid [winfo id $frxanim]
    
    # Note trick to pipe stdout as well as stderr. Forks without &.
    if {[catch {open "|xanim +W$xatomid $fileName 2>@stdout"} xpipe]} {
	return "Xanim failed: $xpipe"
    } else {
	set xanimPipe2Frame($xpipe) $wfr
	set xanimPipe2Item($xpipe) $utag
	fileevent $xpipe readable [list XanimReadOutput $wcan $wfr $xpipe]
    }    
    lappend opts -width $width -height $height
    
    return $errMsg
}

proc ::Import::Free {w} {
    variable snackSounds
    
    set wcan [::WB::GetCanvasFromWtop $w]
    if {[info exists snackSounds($wcan)]} {
	foreach s $snackSounds($wcan) {
	    $s stop
	    $s destroy
	}
    }
}


# Experimental!!!!!!!!!!!!!! Try using the general HttpTrpt packge.

# Import::HttpGet2 --
# 
#       Imports a remote file using the HttpTrpt package that handles all
#       ui stuff during transport, such as progress etc.
#       
# Arguments:
#       w
#       url
#       opts      a list of '-key value' pairs, where most keys correspond 
#                 to a valid "canvas create" option, and everything is on 
#                 a single line.
#
# Results:
#       none

proc ::Import::HttpGet2 {w url opts} {
    global  this prefs
    variable locals
    
    ::Debug 2 "::Import::HttpGet2 w=$w, url=$url, \n\t opts=$opts"

    # Make local state array for convenient storage. 
    # Use 'variable' for permanent storage.
    set gettoken [namespace current]::[incr locals(httpuid)]
    variable $gettoken
    upvar 0 $gettoken getstate

    # We store file names with cached names to avoid name clashes.
    set fileTail [::uriencode::decodefile [file tail  \
      [::Utils::GetFilePathFromUrl $url]]]
    set dstPath [::FileCache::MakeCacheFileName $fileTail]

    set getstate(w)          $w
    set getstate(url)           $url
    set getstate(dstPath)       $dstPath
    set getstate(tail)          $fileTail
    set getstate(opts)          $opts
    set getstate(transport)     http
    set getstate(utag)          [::CanvasUtils::GetUtagFromCreateCmd $opts]
    
    set httptoken [::HttpTrpt::Get $url $dstPath \
      -dialog 0 -silent 1   \
      -command          [list [namespace current]::HttpCmd2 $gettoken] \
      -progressmessage  [list [namespace current]::HttpProgress2 $gettoken]]
    
    # We may have been freed here already!
    if {[array exists getstate]} {
	set getstate(httptoken) $httptoken
    }
    return
}

# Import::HttpCmd2, HttpProgress2 --
# 
#       Callbacks for HttpGet2.

proc ::Import::HttpCmd2 {gettoken httptoken status {msg ""}} {
    variable $gettoken
    upvar 0 $gettoken getstate

    ::Debug 2 "::Import::HttpCmd2 status=$status, gettoken=$gettoken"

    set w $getstate(w)
    set wcan [::WB::GetCanvasFromWtop $w]

    switch -- $status {
	ok {
	    ::WB::SetStatusMessage $w $msg
	    
	    # Add to the lists of known files.
	    ::FileCache::Set $getstate(url) $getstate(dstPath)
	    
	    # This should delegate the actual drawing to the correct proc.
	    DoImport $wcan $getstate(opts) -file $getstate(dstPath) -where local
	}
	default {
	    ::WB::SetStatusMessage $w $msg
	    array set opts $getstate(opts)
	    eval {NewBrokenImage $wcan $opts(-coords) -url $getstate(url)} \
	      $getstate(opts)
	}
    }
    
    # Evaluate any commands affecting this item.
    TrptCachePostImport $gettoken
    
    # And cleanup.
    unset getstate
}

proc ::Import::HttpProgress2 {gettoken str} {
    variable $gettoken
    upvar 0 $gettoken getstate
    
    ::WB::SetStatusMessage $getstate(w) $str
}

#  OUTDATED !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#  
# Import::HttpGet --  
# 
#       Imports the specified file using http to file.
#       The actual work done via callbacks to the http package.
#       The principle is that if we have any -comman or -progress command
#       all UI is redirected to these procs.
#       
# Arguments:
#       w
#       url
#       importPackage
#       opts      a list of '-key value' pairs, where most keys correspond 
#                 to a valid "canvas create" option, and everything is on 
#                 a single line.
#       args:          
#            -commmand  a callback command for errors that cannot be reported
#                       right away, using -url http for instance.
#            -progress  http progress command
# Results:
#       an error string which is empty if things went ok so far.

proc ::Import::HttpGet {w url importPackage opts args} {
    global  this prefs
    variable locals
    
    ::Debug 2 "::Import::HttpGet w=$w, url=$url, \
      importPackage=$importPackage,\n\t opts=$opts,\n\t args='$args'"

    # Make local state array for convenient storage. 
    # Use 'variable' for permanent storage.
    set gettoken [namespace current]::[incr locals(httpuid)]
    variable $gettoken
    upvar 0 $gettoken getstate
    
    # We store file names with cached names to avoid name clashes.
    set fileTail [::uriencode::decodefile [file tail  \
      [::Utils::GetFilePathFromUrl $url]]]
    set dstPath [::FileCache::MakeCacheFileName $fileTail]
    if {[catch {open $dstPath w} dst]} {
	return $dst
    }
    
    # Store stuff in gettoken array.
    set getstate(w)             $w
    set getstate(wcan)          [::WB::GetCanvasFromWtop $w]
    set getstate(url)           $url
    set getstate(importPackage) $importPackage
    set getstate(optList)       $opts
    set getstate(args)          $args
    set getstate(dstPath)       $dstPath
    set getstate(dst)           $dst
    set getstate(tail)          $fileTail
    set getstate(utag)          [::CanvasUtils::GetUtagFromCreateCmd $opts]
    set getstate(transport)     http
    set getstate(status)        ""
    set getstate(error)         ""
    
    # Timing data.
    set getstate(firstmillis) [clock clicks -milliseconds]
    set getstate(lastmillis)  $getstate(firstmillis)
    set getstate(timingkey)   $gettoken
        
    if {[catch {
	::httpex::get $url -channel $dst -timeout $prefs(timeoutMillis) \
	  -progress [list [namespace current]::HttpProgress $gettoken]  \
	  -command  [list [namespace current]::HttpCommand $gettoken]
    } token]} {
	return $token
    }
    upvar #0 $token state
    set getstate(token) $token

    # Handle URL redirects
    foreach {name value} $state(meta) {
        if {[regexp -nocase ^location$ $name]} {
	    close $dst
            eval {::Import::HttpGet $w [string trim $value] \
	      $importPackage $opts} $args
        }
    }
    return
}

#  OUTDATED !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#  
# Import::HttpProgress --
# 
#       Progress callback for the http package.
#       Any -progress command gets only called at an prefs(progUpdateMillis) 
#       interval unless there is an error.


proc ::Import::HttpProgress {gettoken token total current} {
    global prefs
    
    upvar #0 $token state
    upvar #0 $gettoken getstate
    
    ::Debug 9 "."
    array set argsArr $getstate(args)
    if {[info exists argsArr(-progress)] && ($argsArr(-progress) ne "")} {
	set haveProgress 1
    } else {
	set haveProgress 0
    }
    
    # Cache timing info.
    ::timing::setbytes $getstate(timingkey) $current
    
    # Investigate 'state' for any exceptions.
    set status [::httpex::status $token]
    
    if {[string equal $status "error"]} {
	if {$haveProgress} {
	    uplevel #0 $argsArr(-progress)  \
	      [list $status $gettoken $token $total $current]
	} else {	
	    set errmsg "File transfer error for \"$getstate(url)\""
	    ::UI::MessageBox -title [mc Error] -icon error -type ok \
	      -message "Failed getting url: $errmsg"
	}
	catch {file delete $getstate($dstPath)}
	set getstate(status) "error"
	
	# Cleanup:
	::httpex::cleanup $token
	unset getstate
    } else {
	
	# Update only when minimum time has passed.
	set ms [clock clicks -milliseconds]
	if {[expr $ms - $getstate(lastmillis)] > $prefs(progUpdateMillis)} {
	    set getstate(lastmillis) $ms
	    
	    if {$haveProgress} {
		uplevel #0 $argsArr(-progress)  \
		  [list $status $gettoken $token $total $current]	
	    } else {
		set tmsg [::timing::getmessage $getstate(timingkey) $total]
		set msg "Getting \"$getstate(tail)\", $tmsg"
		::WB::SetStatusMessage $getstate(w) $msg
	    }	    
	}
    }
}

#  OUTDATED !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#  
# Import::HttpCommand --
# 
#       Callback for httpex package.
#       If ok it dispatches drawing to the right proc.
#       
#       httpex: The 'state' sequence is normally: 
#          connect -> putheader -> waiting -> getheader -> body -> final
#       The 'status' is only defined for state=eof, and is then any of:
#       ok, reset, eof, timeout, or error.

proc ::Import::HttpCommand {gettoken token} {    
    upvar #0 $token state
    upvar #0 $gettoken getstate 
    
    # Investigate 'state' for any exceptions and return code (404)!!!
    set getstate(state)  [::httpex::state $token]
    set getstate(status) [::httpex::status $token]
    set getstate(ncode)  [httpex::ncode $token]

    ::Debug 2 "::Import::HttpCommand state = $getstate(state)"
    
    set w     $getstate(w)
    set wcan     $getstate(wcan)
    set dstPath  $getstate(dstPath)
    set opts     $getstate(optList)
    set tail     $getstate(tail)
    set thestate $getstate(state)
    set status   $getstate(status)
    
    # Combined state+status.
    if {[string equal $thestate "final"]} {
	set stateStatus $status
    } else {
	set stateStatus $thestate
    }
    
    array set argsArr $getstate(args)
    if {[info exists argsArr(-command)] && ($argsArr(-command) ne "")} {
	set haveCommand 1
    } else {
	set haveCommand 0
    }
    set errMsg ""
    
    # Catch the case when we get a non 200 return code and is otherwise ok.
    if {($thestate eq "final") && ($status eq "ok") && ($getstate(ncode) ne "200")} {
	set status error
 	set stateStatus error
	set httpMsg [httpex::ncodetotext $getstate(ncode)]
	set errMsg "Failed getting file \"$tail\": $httpMsg"
    }
	
    if {$haveCommand} {
	uplevel #0 $argsArr(-command) [list $stateStatus $gettoken $token]	
    } elseif {[string equal $thestate "final"]} {
	
	switch -- $status {
	    timeout {
		set msg "Timeout waiting for file \"$tail\""
		::WB::SetStatusMessage $w $msg
		::UI::MessageBox -title [mc Timeout] -icon info \
		  -type ok -message $msg
	    }
	    ok {
		::WB::SetStatusMessage $w "Finished getting file \"$tail\""
	    }
	    error {
		::WB::SetStatusMessage $w $errMsg
	    }
	    default {
		# ???
	    }
	}
    }    
    
    # httpex makes callbacks during the process as well. Important!
    # We should be final here!
    if {[string equal $thestate "final"]} {
	catch {close $getstate(dst)}
	set impErr ""
	
	# Import stuff.
	if {($status eq "ok") && ($getstate(ncode) eq "200")} {
	    
	    # Add to the lists of known files.
	    ::FileCache::Set $getstate(url) $dstPath
	    
	    # This should delegate the actual drawing to the correct proc.
	    set impErr [::Import::DoImport $wcan $opts -file $dstPath \
	      -where local]
	    ::Import::TrptCachePostImport $gettoken
	}
	
	# Catch errors from 'errMsg'.
	if {$errMsg ne ""} {
	    set stateStatus error
	    set getstate(error) $errMsg
	} elseif {$impErr ne ""} {
	    set stateStatus error
	    set getstate(error) $impErr
	}
	if {$haveCommand} {
	    uplevel #0 $argsArr(-command) [list $stateStatus $gettoken $token]	
	} elseif {$errMsg ne ""} {
	    ::WB::SetStatusMessage $w "Failed importing \"$tail\" $errMsg"
	}
	
	# Cleanup:
	::httpex::cleanup $token
	if {($errMsg ne "") || ($impErr ne "")} {
	    catch {file delete -force $getstate(dstPath)}
	}
	unset getstate
    } 	
}

# Import::ImportProgress --
# 
#       Handles http progress UI stuff. 
#       Gets only called at an prefs(progUpdateMillis) interval unless 
#       there is an error.

proc ::Import::ImportProgress {line status gettoken httptoken total current} {

    upvar #0 $token state
    upvar #0 $gettoken getstate
    
    set w $getstate(w)
    
    if {[string equal $status "error"]} {
	if {[info exists state(error)]} {
	    set errmsg $state(error)
	} else {
	    set errmsg "File transfer error for \"$getstate(url)\""
	}
	::WB::SetStatusMessage $w "Failed getting url: $errmsg"
    } else {
	set tmsg [::timing::getmessage $getstate(timingkey) $total]
	set msg "Getting \"$getstate(tail)\", $tmsg"
	::WB::SetStatusMessage $w $msg
    }
}

# Import::ImportCommand --
# 
#       Callback procedure for the '::Import::HandleImportCmd'
#       command. 
#       Takes care of state reports not reported by direct return. 

proc ::Import::ImportCommand {line stateStatus gettoken httptoken} {
    upvar #0 $gettoken getstate          

    Debug 2 "::Import::ImportCommand stateStatus=$stateStatus"
    
    if {[string equal $stateStatus "reset"]} {
	return
    }
    set wcan     $getstate(wcan)
    set w     $getstate(w)
    set tail     $getstate(tail)
    set thestate $getstate(state)
    set status   $getstate(status)

    switch -- $stateStatus {
	timeout {
	    ::WB::SetStatusMessage $w "Timeout waiting for file \"$tail\""
	}
	connect {
	    set domain [::Utils::GetDomainNameFromUrl $getstate(url)]
	    ::WB::SetStatusMessage $w "Contacting $domain..."
	}
	ok {
	    ::WB::SetStatusMessage $w "Finished getting file \"$tail\""
	}
	error {
	    if {$getstate(ncode) ne "200"} {
		set status error
		set httpMsg [httpex::ncodetotext $getstate(ncode)]
		set msg "Failed getting file \"$tail\": $httpMsg"
	    } else {
		set msg "Error getting file \"$tail\": "
		append msg [httpex::error $httptoken]
		append msg $getstate(error)
	    }
	    ::WB::SetStatusMessage $w $msg
	}
	eof {
	    ::WB::SetStatusMessage $w "Error getting file \"$tail\""
	}
    }

    # We should be final here!
    if {[string equal $thestate "final"]} {
	if {$status ne "ok"} {
	    eval {NewBrokenImage $wcan [lrange $line 1 2]} [lrange $line 3 end]
	}
    }
}

# Import::HttpResetAll --
# 
#       Cancel and reset all ongoing http transactions for this w.

proc ::Import::HttpResetAll {w} {

    set gettokenList [GetTokenList]
    
    ::Debug 2 "::Import::HttpResetAll w=$w, gettokenList='$gettokenList'"
    
    foreach gettoken $gettokenList {
	upvar #0 $gettoken getstate          

	if {[info exists getstate(w)] && ($getstate(w) == $w)} {
	    HttpReset $gettoken
	    ::WB::SetStatusMessage $w "All file transport reset"
	}
    }
}

proc ::Import::HttpReset {gettoken} {
    upvar #0 $gettoken getstate          
	
    ::Debug 4 "::Import::HttpReset getstate(transport)=$getstate(transport)"	    

    switch -- $getstate(transport) {
	http {
	    
	    # It may be that the http transaction never started.
	    if {[info exists getstate(httptoken)]} {
		::HttpTrpt::Reset $getstate(httptoken)
	    }
	}
	quicktimehttp {
	    
	    # This should reset everything for this movie.
	    catch {destroy $getstate(wfr)}
	}
    }
}

proc ::Import::GetTokenFrom {key pattern} {
    
    foreach gettoken [GetTokenList] {
	upvar #0 $gettoken getstate          

	if {[info exists getstate($key)] && \
	  [string match $pattern $getstate($key)]} {
	    return $gettoken
	}
    }
    return
}

proc ::Import::GetTokenList { } {
    
    return [concat  \
      [info vars ::Import::\[0-9\]] \
      [info vars ::Import::\[0-9\]\[0-9\]] \
      [info vars ::Import::\[0-9\]\[0-9\]\[0-9\]]]
}

# Import::TrptCachePostDrawHook, TrptCachePostImport --
# 
#       Two routines to cache incoming commands while file is transported.
#       This must be done since commands received during transport are
#       otherwise lost.

proc ::Import::TrptCachePostDrawHook {w cmd args} {
    
    set utag [::CanvasUtils::GetUtagFromCanvasCmd $cmd]
    set gettoken [GetTokenFrom utag $utag]

    if {$gettoken ne ""} {
	upvar #0 $gettoken getstate          
	
	switch -- [lindex $cmd 0] {
	    delete {
		
		# Note order since reset triggers unsetting gettoken.
		set msg "Cancelled transport of \"$getstate(tail)\"; was deleted"
		::WB::SetStatusMessage $getstate(w) $msg
		HttpReset $gettoken
	    }
	    import {
		# empty
	    }
	    default {
		lappend getstate(trptcmds) $cmd
	    }
	}
    }
    return {}
}

proc ::Import::TrptCachePostImport {gettoken} {
    upvar #0 $gettoken getstate          
    
    if {[info exists getstate(trptcmds)]} {
	foreach cmd $getstate(trptcmds) {
	    ::CanvasUtils::HandleCanvasDraw $getstate(w) $cmd -where local
	}
    }
}

# Import::HttpGetQuickTimeTcl --
# 
#       Obtains a QuickTime movie from an url. This is streaming and the
#       movie being streamed must be prepared for this. Currently there
#       is no mechanism for checking this.

proc ::Import::HttpGetQuickTimeTcl {w url opts args} {
    variable locals
    
    ::Debug 2 "::Import::HttpGetQuickTimeTcl"

    # Make local state array for convenient storage. 
    # Use 'variable' for permanent storage.
    set gettoken [namespace current]::[incr locals(httpuid)]
    variable $gettoken
    upvar 0 $gettoken getstate
    
    array set optArr $opts
    set wcan [::WB::GetCanvasFromWtop $w]    
    
    # Make a frame for the movie; need special class to catch 
    # mouse events. Postpone display until playable from callback.
    set uniqueName [::CanvasUtils::UniqueImageName]		
    set wfr $wcan.fr_${uniqueName}
    frame $wfr -height 1 -width 1 -bg gray40 -class QTFrame    
    set wmovie $wfr.m	

    set getstate(w) $w
    set getstate(url) $url
    set getstate(optList) $opts
    set getstate(args) $args
    set getstate(wfr) $wfr
    set getstate(wmovie) $wmovie
    set getstate(transport) quicktimehttp
    set getstate(qtstate) ""
    set getstate(mapped) 0
    set getstate(tail)  \
      [::uriencode::decodefile [file tail [::Utils::GetFilePathFromUrl $url]]]
    
    # Here we should do this connection async!!!
    set callback [list [namespace current]::QuickTimeTclCallback $gettoken]

    # This one shall return almost immediately.
    if {[catch {movie $wmovie -url $url -loadcommand $callback} msg]} {
	::UI::MessageBox -icon error -type ok -message "[mc Error]: $msg"
	catch {destroy $wfr}
	return
    }
    ::WB::SetStatusMessage $w "Opening $url"
    
    # Be sure to return empty here!
    return
}

# Import::QuickTimeTclCallback --
# 
#       Callback for QuickTimeTcl package when using -url.

proc ::Import::QuickTimeTclCallback {gettoken wmovie msg {err {}}} {

    upvar #0 $gettoken getstate          
    
    set w $getstate(w)
    set url $getstate(url)
    set getstate(qtstate) $msg
    set canmap 0
    
    switch -- $msg {
	error {
	    catch {destroy $getstate(wfr)}
	    set msg "We got an error when trying to load the\
	      movie \"$url\" with QuickTime."
	    if {[string length $err]} {
		append msg " $err"
	    }
	    ::WB::SetStatusMessage $w ""
	    ::UI::MessageBox -icon error -type ok -message $msg
	    unset getstate
	    return
	}
	loading {	    
	    ::WB::SetStatusMessage $w "Loading: \"$getstate(tail)\""
	}
	playable {
	    set canmap 1
	    ::WB::SetStatusMessage $w "Now playable: \"$getstate(tail)\""
	}
	complete {
	    set canmap 1	    
	    ::WB::SetStatusMessage $w "Completed: \"$getstate(tail)\""
	}
    }
    
    # If possible to map as a canvas item but is unmapped.
    if {$canmap && !$getstate(mapped)} {
	set getstate(mapped) 1
	::Import::DrawQuickTimeTclFromHttp $gettoken
	::Import::TrptCachePostImport $gettoken
    }
    
    # Cleanup when completely finished.
    if {$msg eq "complete"} {
	unset getstate
    }
}

# Import::DrawQuickTimeTclFromHttp --
#
#       Performs the final stage of drawing the movie to canvas when
#       obtained via the internal QT -url option.

proc ::Import::DrawQuickTimeTclFromHttp {gettoken} {
    upvar #0 $gettoken getstate          
    
    set w $getstate(w)
    set url $getstate(url)
        
    set wcan [::WB::GetCanvasFromWtop $w]
    set wfr $getstate(wfr)
    set wmovie $getstate(wmovie)
    array set optArr $getstate(optList)
    
    # Extract coordinates and tags which must be there. error checking?
    foreach {x y} $optArr(-coords) break
    set utag [::CanvasUtils::GetUtagFromTagList $optArr(-tags)]

    $wcan create window $x $y -anchor nw -window $wfr \
      -tags [list frame $utag]
    pack $wmovie -in $wfr -padx 3 -pady 3
    
    if {[info exists optArr(-above)]} {
	catch {$wcan raise $utag $optArr(-above)}
    }

    set qtBalloonMsg [::Import::QuickTimeBalloonMsg $wmovie $getstate(tail)]
    ::balloonhelp::balloonforwindow $wmovie $qtBalloonMsg
    
    # Nothing to cache, not possible to transport further.
    # Perhaps possible to do: $wmovie saveas filepath
    #::FileCache::Set $getstate(url) $dstPath
}

# Import::GetStackOptions --
# 
#       Like ::CanvasUtils::GetStackingOption but using apriori info from opts.

proc ::Import::GetStackOptions {wcan opts tag} {
    
    array set optsArr $opts

    if {![info exists optsArr(-above)]} {
	set belowutag [::CanvasUtils::FindBelowUtag $wcan $tag]
	if {[string length $belowutag]} {
	    set optsArr(-above) $belowutag
	}
     }
     if {![info exists optsArr(-below)]} {
	 set aboveutag [::CanvasUtils::FindAboveUtag $wcan $tag]
	 if {[string length $aboveutag]} {
	     set optsArr(-below) $aboveutag
	 }
     }    
    return [array get optsArr]
}

# Import::XanimQuerySize --
#
#       Gets size of the movie. If any error, return {}.
#       Check also version number ( >= 2.70 ).

proc ::Import::XanimQuerySize {fileName} {
    
    set num_ {[0-9]+}
    set ver_ {[0-9]+\.[0-9]+}
    if {![catch {exec xanim +v +Zv $fileName} res]} {
	
	# Check version number.
	if {[regexp "Rev +($ver_)" $res match ver]} {
	    if {$ver < 2.7} {
		puts stderr "[mc Error]: xanim must have at least version 2.7"
		return {}
	    }
	}
	
	# Ok, parse size.
	if {[regexp "Size=(${num_})x(${num_})" $res match w h]} {
	    return [list $wcan $h]
	} else {
	    return {}
	}
    } else {
	# Error checking...
	puts "XanimQuerySize:: error, res=$res"
	return {}
    }
}

proc ::Import::XanimReadOutput {wcan wfr xpipe} {
    
    variable xanimPipe2Frame 
    variable xanimPipe2Item

    if [eof $xpipe] {
	
	# Movie is stopped, cleanup.
	set co [$wcan coords $xanimPipe2Item($xpipe)]
	::CanvasDraw::DeleteFrame $wcan $wfr [lindex $co 0] [lindex $co 1]
	catch {close $xpipe}
    } else {
	
       # Read each line and try to figure out if anything went wrong.
       gets $xpipe line
       if {[regexp -nocase "(unknown|error)" $line match junk]} {
	   ::UI::MessageBox -message "Something happened when trying to\
	     run 'xanim': $line" -icon info -type ok
       }
   }
}

# Import::HandleImportCmd --
#
#       Shall be canvasPath neutral and also neutral to file path type.
#       Typically used when reading canvas file version 2.
#
# Arguments:
#       wcan        the canvas widget path.
#       line:       this is typically an "import" command similar to items but
#                   for images and movies that need to be transported.
#                   It shall contain either a -file or -url option, but not both.
#       args: 
#               -where     "all": write to this canvas and all others,
#                          "remote": write only to remote client canvases,
#                          "local": write only to this canvas and not to any 
#                          other.
#                          ip number: write only to this remote client canvas 
#                          and not to own.
#               -basepath
#               -commmand  a callback command for errors that cannot be reported
#                          right away, using -url http for instance.
#               -progress  http progress callback
#               -addundo   (0|1)
#               -showbroken (0|1)
#               -tryimport (0|1)
#               
# Results:
#       an error string which is empty if things went ok.

proc ::Import::HandleImportCmd {wcan line args} {
    
    Debug 2 "::Import::HandleImportCmd \n\t line=$line \n\t args=$args"
    
    if {![string equal [lindex $line 0] "import"]} {
	return -code error "Line is not an \"import\" line"
    }
    array set argsArr {
	-showbroken   1
	-tryimport    1
	-where        all
	-acceptcache  1
    }
    array set argsArr $args
    set errMsg ""
    
    # Make a suitable '-key value' list from the $line argument.
    set opts [concat [list -coords [lrange $line 1 2]] [lrange $line 3 end]]
    array set optArr $opts
    
    # The logic of importing.
    set doImport 0
    if {$argsArr(-tryimport)} {
        set doImport 1
    } elseif {$argsArr(-acceptcache)} {
	if {[info exists optArr(-url)]} {
	    if {[::FileCache::IsCached $optArr(-url)]} {
		set doImport 1
	    }
	}
    }
    
    if {$doImport} {
	
	# Sort out the switches that shall go as impArgs.
	set impArgs {}
	foreach {key value} $args {
	    switch -- $key {
		-where - -addundo {
		    lappend impArgs $key $value
		}
	    }
	}
	
	# We must provide the importer with an absolute path if relative path.
	# in 'line'.
	if {[info exists optArr(-file)]} {
	    set path $optArr(-file)
	    if {[file pathtype $path] eq "relative"} {
		if {![info exists argsArr(-basepath) ]} {
		    return -code error "Must have \"-basebath\" option if relative path"
		}
		set path [addabsolutepathwithrelative $argsArr(-basepath) $path]
		set path [file nativename $path]
	    }
	    lappend impArgs -file $path
	    
	    # If have an -url seek our file cache first and switch -url for -file.
	} elseif {[info exists optArr(-url)]} {
	    set url $optArr(-url)
	    if {[::FileCache::IsCached $url]} {
		set path [::FileCache::Get $url]
		lappend impArgs -file $path
		
		Debug 2 "\t url is cached \"$url\""
	    } else {
		lappend impArgs -url $optArr(-url)
		if {[info exists argsArr(-command)]} {
		    lappend impArgs -command $argsArr(-command)
		}
	    }
	}	

	set errMsg [eval {DoImport $wcan $opts} $impArgs]
    }
    
    # Not -tryimport or error.
    if {$argsArr(-showbroken) && (($errMsg ne "") || !$doImport)} {
	
	# Display a broken image to indicate for the user.
	eval {NewBrokenImage $wcan [lrange $line 1 2]} [lrange $line 3 end]
    }
    
    return $errMsg
}

# Import::ImageImportCmd, QTImportCmd, SnackImportCmd,
#    FrameImportCmd --
#
#       These are handy commands for the undo method.
#       Executing any of these commands should be package neutral.
#       Must be called *before* item is deleted.

proc ::Import::ImageImportCmd {wcan utag} {
    
    set imageName [$wcan itemcget $utag -image]
    set imageFile [$imageName cget -file]
    set imArgs [list -file $imageFile]
    set optList [list -coords [$wcan coords $utag] -tags $utag]
    
    return [concat  \
      [list ::Import::DoImport $wcan $optList] $imArgs]
}
    
proc ::Import::QTImportCmd {wcan utag} {
    
    # We need to reconstruct how it was imported.
    set win [$wcan itemcget $utag -window]
    set wmovie $win.m
    set movFile [$wmovie cget -file]
    set movUrl [$wmovie cget -url]
    set optList [list -coords [$wcan coords $utag] -tags $utag]
    if {$movFile ne ""} {
	set movargs [list -file $movFile]
    } elseif {$movUrl ne ""} {
	set movargs [list -url $movUrl]
    }
    return [concat  \
      [list ::Import::DoImport $wcan $optList] $movargs]
}

proc ::Import::SnackImportCmd {wcan utag} {
    
    # We need to reconstruct how it was imported.
    # 'wmovie' is a moviecontroller widget.
    set win [$wcan itemcget $utag -window]
    set wmovie $win.m
    set soundObject [$wmovie cget -snacksound]
    set soundFile [$soundObject cget -file]
    set optList [list -coords [$wcan coords $utag] -tags $utag]
    set movargs [list -file $soundFile]
    return [concat  \
      [list ::Import::DoImport $wcan $optList] $movargs]
}

# Generic command for plugins, typically.

proc ::Import::FrameImportCmd {wcan utag} {
    
    set w [winfo toplevel $wcan]
    set opts [::CanvasUtils::ItemCGet $w $utag]
    array set optsArr $opts
    set impArgs {}
    if {[info exists optsArr(-file)]} {
	lappend impArgs -file $optsArr(-file)
    }
    set optList [list -coords [$wcan coords $utag] -tags $utag]
    
    return [concat  \
      [list ::Import::DoImport $wcan $optList] $impArgs]
}
    
# Import::GetTclSyntaxOptsFromTransport --
# 
# 

proc ::Import::GetTclSyntaxOptsFromTransport {optList} {

    set opts {}

    foreach {key val} $optList {
	switch -- [string tolower $key] {
	    image-name: {
		lappend opts -image $val
	    }
	    content-length: {
		lappend opts -size $val
	    }
	    content-type: {
		lappend opts -mime $val
	    }
	    get-url: {
		lappend opts -url $val
	    }
	    default {
		lappend opts "-[string trimright $key :]" $val
	    }
	}
    }
    return $opts
}

# Import::GetTransportSyntaxOptsFromTcl --
# 
# 

proc ::Import::GetTransportSyntaxOptsFromTcl {optList} {

    set opts {}

    foreach {key val} $optList {
	switch -- $key {
	    -image {
		lappend opts Image-Name: $val
	    }
	    -size {
		lappend opts Content-Length: $val
	    }
	    -mime {
		lappend opts Content-Type: $val
	    }
	    -url {
		lappend opts Get-Url: $val
	    }
	    -zoom-factor {
		lappend opts Zoom-Factor: $val
	    }	    
	    default {
		lappend opts "[string trimleft $key -]:" $val
	    }
	}
    }
    return $opts
}

# Import::ResizeImage --
#
#       Uhh.. resizes the selected images. 'zoomFactor' is 0,1 for no resize,
#       2 for an enlargement with a factor of two, and
#       -2 for a size decrease to half size.   
#       
# Arguments:
#       w           canvas widget
#       zoomFactor   an integer factor to scale with.
#       which    "sel": selected images, or a specific image with tag 'which'.
#       newTag   "auto": generate a new utag, 
#                else 'newTag' is the tag to use.
#       where    "all": write to this canvas and all others.
#                "remote": write only to remote client canvases.
#                "local": write only to this canvas and not to any other.
#                ip number: write only to this remote client canvas and not 
#                to own.
#       
# Results:
#       image item resized, propagated to clients.

proc ::Import::ResizeImage {wcan zoomFactor which newTag {where all}} {
        
    set scaleFactor 2
    set int_ {[-0-9]+}
    
    set w [winfo toplevel $wcan]
    
    # Compute total resize factor.
    if {($zoomFactor >= 0) && ($zoomFactor <= 1)} {
	return
    } elseif {$zoomFactor == 2} {
	set theScale 2
    } elseif {$zoomFactor == -2} {
	set theScale 0.5
    } else {
	return
    }
    if {$which eq "sel"} {
	set ids [$wcan find withtag selected]
    } else {
	set ids [$wcan find withtag $which]
	if {[llength $ids] == 0} {
	    return
	}
    }
    set idsNewSelected {}
    foreach id $ids {
	
	if {$where eq "all" || $where eq "local"} {	    
	    set type [$wcan type $id]
	    if {![string equal $type "image"]} {
		continue
	    }
	    
	    # Check if no privacy problems. Only if 'which' is the selected.
	    set utagOrig [::CanvasUtils::GetUtag $wcan $id]
	    if {$which eq "sel" && $utagOrig eq ""} {
		continue
	    }
	    set coords [$wcan coords $id]
	    set theIm [$wcan itemcget $id -image]
	    
	    # Resized photos add tag to name '_zoom2' for double size,
	    # '_zoom-2' for half size etc.
	    if {[regexp "_zoom(${int_})$" $theIm match sizeNo]} {
		
		# This image already resized.
		if {$zoomFactor == 2} {
		    if {$sizeNo >= 2} {
			set newSizeNo [expr $sizeNo * $zoomFactor]
		    } elseif {$sizeNo == -2} {
			set newSizeNo 0
		    } else {
			set newSizeNo [expr $sizeNo/$zoomFactor]
		    }
		} elseif {$zoomFactor == -2} {
		    if {$sizeNo <= -2} {
			set newSizeNo [expr -$sizeNo * $zoomFactor]
		    } elseif {$sizeNo == 2} {
			set newSizeNo 0
		    } else {
			set newSizeNo [expr -$sizeNo/$zoomFactor]
		    }
		}

		if {$newSizeNo == 0} {
		    
		    # Get original image. Strip off the _zoom tag.
		    regsub "_zoom$sizeNo" $theIm  "" newImName
		} else {
		    regsub "_zoom$sizeNo" $theIm "_zoom$newSizeNo" newImName
		}
	    } else {
		
		# Add tag to name indicating that it has been resized.
		set newSizeNo $zoomFactor
		set newImName ${theIm}_zoom${newSizeNo}
	    }
	    
	    # Create new image for the scaled version if it does not exist before.
	    if {[lsearch -exact [image names] $newImName] < 0} {
		image create photo $newImName
		if {$zoomFactor > 0} {
		    $newImName copy $theIm -zoom $theScale
		} else {
		    $newImName copy $theIm -subsample [expr round(1.0/$theScale)]
		}
	    }
	    
	    # Choose this clients automatic tags or take 'newTag'.
	    if {$newTag eq "auto"} {
		set useTag [::CanvasUtils::NewUtag]
	    } else {
		set useTag $newTag
	    }
	    
	    # Be sure to keep old stacking order.
	    set isAbove [$wcan find above $id]
	    set cmdlocal "create image $coords -image $newImName -anchor nw  \
	      -tags {std image $useTag}"
	    set cmdExList [list [list $cmdlocal local]]
	    if {$isAbove ne ""} {
		lappend cmdExList [list [list lower $useTag $isAbove] local]
	    }
	    set undocmd  \
	      "create image $coords [::CanvasUtils::GetItemOpts $wcan $id all]"
	    set undocmdExList [list [list $undocmd local]  \
	      [list [list delete $useTag] local]]
	    
	    # Collect tags of selected originals.
	    if {[lsearch [$wcan itemcget $id -tags] "selected"] >= 0} {
		lappend idsNewSelected $useTag
	    }
	}
	
	# We need to do something different here!!!!!!!!!!!!!!!!!!!!!!!!!
	
	# Assemble remote command.
	if {$where ne "local"} {
	    set cmdremote "RESIZE IMAGE: $utagOrig $useTag $zoomFactor"
	    set undocmdremote "RESIZE IMAGE: $useTag $utagOrig [expr -$zoomFactor]"
	    if {$where eq "remote" || $where eq "all"} {
		lappend cmdExList [list $cmdremote remote]
		lappend undocmdExList [list $undocmdremote remote]
	    } else {
		lappend cmdExList [list $cmdremote $where]
		lappend undocmdExList [list $undocmdremote $where]
	    }    
	}
	
	# Remove old.
	lappend cmdExList [list [list delete $utagOrig] local]
	set redo [list ::CanvasUtils::GenCommandExList $w $cmdExList]
	set undo [list ::CanvasUtils::GenCommandExList $w $undocmdExList]
	eval $redo
	undo::add [::WB::GetUndoToken $wcan] $undo $redo
    }
    ::CanvasCmd::DeselectAll $wcan
    
    # Mark the new ones if old ones selected.
    foreach id $idsNewSelected {
	::CanvasDraw::MarkBbox $wcan 1 $id
    }
}

# Import::GetAutoFitSize --
#
#       Gives a new smaller size of 'theMovie' if it is too large for canvas 'w'.
#       It is rescaled by factors of two.
#       
# Arguments:
#       wcan        the canvas widget path.
#
# Results:

proc ::Import::GetAutoFitSize {wcan theMovie} {

    set factor 2.0
    set canw [winfo width $wcan]
    set canh [winfo height $wcan]
    set msize [$theMovie size]
    set imw [lindex $msize 0]
    set imh [lindex $msize 1]
    set maxRatio [max [expr $imw/($canw + 0.0)] [expr $imh/($canh + 0.0)]]
    if {$maxRatio >= 1.0} {
	set k [expr ceil(log($maxRatio)/log(2.0))]
	return [list [expr int($imw/pow(2.0, $k))] [expr int($imh/pow(2.0, $k))]]
    } else {
	return [list $imw $imh]
    }
}

# SaveImageAsFile, ExportImageAsFile,... --
#
#       Some handy utilities for the popup menu callbacks.

proc ::Import::SaveImageAsFile {wcan id} {

    set imageName [$wcan itemcget $id -image]
    set origFile [$imageName cget -file]
    
    # Do different things depending on if in cache or not.
    if {[file exists $origFile]} {
	set ext [file extension $origFile]
	set initFile Untitled${ext}
	set fileName [tk_getSaveFile -defaultextension $ext   \
	  -title [mc {Save As}] -initialfile $initFile]
	if {$fileName ne ""} {
	    file copy $origFile $fileName
	}
    } else {
	set initFile Untitled.gif
	set fileName [tk_getSaveFile -defaultextension gif   \
	  -title [mc {Save As GIF}] -initialfile $initFile]
	if {$fileName ne ""} {
	    $imageName write $fileName -format gif
	}
    }
}

proc ::Import::ExportImageAsFile {wcan id} {
    
    set imageName [$wcan itemcget $id -image]
    catch {$imageName write {Untitled.gif} -format {quicktime -dialog}}
}

proc ::Import::ExportMovie {w winfr} {
    
    set wmov $winfr.m
    $wmov export
}

# Import::SyncPlay --
# 
#       Synchronized playback for linear QuickTime movies.

proc ::Import::SyncPlay {w winfr} {
    
    set wmov $winfr.m
    set cmd [$wmov cget -mccommand]
    if {$cmd == {}} {
	
	# We need to get the corresponding utag.
	set utag [::CanvasUtils::GetUtagFromWindow $winfr]
	if {$utag eq ""} {
	    return
	}
	$wmov configure -mccommand [list ::Import::QuickTimeMCCallback $utag]
    } else {
	$wmov configure -mccommand {}
    }
}

# Import::QuickTimeMCCallback --
# 
#       Procedure for the -mccommand for QuickTime widgets.

proc ::Import::QuickTimeMCCallback {utag wmovie msg {par {}}} {
    variable moviestate

    set w [winfo toplevel $wmovie]
        
    # It is possible to add more commands.

    switch -- $msg {
	play {
	    set time [$wcan time]
	    set rate $par
	    
	    # If any of them are different from cached state then send.
	    set timetrig 1
	    if {[info exists moviestate($utag,time)] && \
	      ($moviestate($utag,time) == $time)} {
		set timetrig 0		
	    }
	    set ratetrig 1
	    if {[info exists moviestate($utag,rate)] && \
	      ($moviestate($utag,rate) == $rate)} {
		set ratetrig 0		
	    }
	    if {$timetrig || $ratetrig} {
		set str "QUICKTIME: play $utag $time $rate"
		::CanvasUtils::GenCommand $w $str remote
	    }
	}
    }
}

# Import::QuickTimeHandler --
# 
#       Callback for "QUICKTIME" commands.

proc ::Import::QuickTimeHandler {wcan type cmd args} {
    variable moviestate
    
    ::Debug 4 "::Import::QuickTimeHandler cmd=$cmd"
    
    set instr [lindex $cmd 1]
    set utag  [lindex $cmd 2]
    if {![string equal [$wcan type $utag] "window"]} {
	return
    }
    set w [$wcan itemcget $utag -window]
    if {![string equal [winfo class $w] "QTFrame"]} {
	return
    }
    if {![winfo exists $w]} {
	return
    }
    set wmov [lindex [winfo children $w] 0]
    
    # It is very easy to end up in an infinite loop here!
    # It is possible to add more commands.
    
    switch -- $instr {
	play {
	    set dsttime [lindex $cmd 3]
	    set dstrate [lindex $cmd 4]
	    array set timeArr [$wmov gettime]
	    # $timeArr(-movieduration)
	    if {$dsttime == $timeArr(-movieduration)} {
		set dstrate 0.0
	    }
	    
	    # Cache target state which must not be resent via callback!
	    set moviestate($utag,time) $dsttime
	    set moviestate($utag,rate) $dstrate
	    if {$dstrate == 0.0} {
		if {[$wmov rate] != $dstrate} {
		    $wmov rate 0.0
		}
		if {[$wmov time] != $dsttime} {
		    $wmov time $dsttime
		}
	    } else {
		if {[$wmov time] != $dsttime} {
		    $wmov time $dsttime
		}
		if {[$wmov rate] != $dstrate} {
		    $wmov play
		}
	    }
	}
    }
}

proc ::Import::TakeShot {w winfr} {
    global  this
    
    set utag [::CanvasUtils::GetUtagFromWindow $winfr]
    if {$utag eq ""} {
	return
    }
    set wcan [::WB::GetCanvasFromWtop $w]
    set wmov $winfr.m
    set im [image create photo]
    $wmov picture [$wmov time] $im
    
    # We must save the image on disk in order to transport it.
    set tmpfile [::tfileutils::tempfile $this(tmpPath) shot]
    append tmpfile .jpg
    $im write $tmpfile -format quicktimejpeg
    set coo [$wcan coords $utag]
    set height [winfo height $winfr]
    set x [lindex $coo 0]
    set y [expr [lindex $coo 1] + $height]
    
    set opts [list -coords [list $x $y]]
    DoImport $wcan $opts -file $tmpfile
}

proc ::Import::TimeCode {w winfr} {
    
    set wmov $winfr.m
    if {![$wmov isvisual]} {
	return
    }
    set videoTrackID [lindex [$wmov tracks list -mediatype vide] 0]
    if {$videoTrackID == {}} {
	return
    }
    set tmTrackID [$wmov tracks list -mediatype tmcd]
    if {$tmTrackID == {}} {
	
	# Create a timecode track.
	array set tmarr [$wmov nextinterestingtime vide]
	array set moarr [$wmov gettime]
	set frameduration $tmarr(-sampleduration)
	set timescale $moarr(-movietimescale)
	set framespersecond [expr $timescale/$frameduration]
	
	set res [$wmov timecode new $videoTrackID -foreground black \
	  -background white -frameduration $tmarr(-sampleduration) \
	  -timescale $timescale -framespersecond $framespersecond]
	set id [lindex $res 1]
	$wmov tracks configure $id -graphicsmode addmin
    } else {
	$wmov timecode toggle
    }
}

# Import::ReloadImage --
# 
#       Reloads a binary entity, image and such.

proc ::Import::ReloadImage {w id} {
        
    ::Debug 3 "::Import::ReloadImage"
    
    # Need to have an url stored here.
    set wcan [::WB::GetCanvasFromWtop $w]
    set opts [::CanvasUtils::ItemCGet $w $id]
    array set optsArr $opts  
    set coords [$wcan coords $id]
        
    if {![info exists optsArr(-url)]} {
	::UI::MessageBox -icon error -type ok -message \
	  "No url found for the file \"$fileTail\" with MIME type $mime"
	return
    }

    # Unselect and delete. Any new failure will make a new broken image.
    # Only locally and not tracked by undo/redo.
    ::CanvasDraw::DeselectItem $wcan $id
    catch {$wcan delete $id}
    set line [concat import $coords $opts]
    
    set errMsg [eval {
	# -progress & -command outdated!!!
	HandleImportCmd $wcan $line -where local   \
	  -progress [list [namespace current]::ImportProgress $line] \
	  -command  [list [namespace current]::ImportCommand $line]
    }]
    if {$errMsg ne ""} {

	# Display a broken image to indicate for the user.
	eval {NewBrokenImage $wcan $coords} $opts
	::UI::MessageBox -icon error -type ok -message \
	  "Failed loading \"$optsArr(-url)\": $errMsg"
    }
}

# Import::NewBrokenImage --
# 
#       Draws a broken image instaed of an ordinary image to indicate some
#       kind of failure somewhere.
# 
# Arguments:
#       wcan        the canvas widget path.
#
# Results:

proc ::Import::NewBrokenImage {wcan coords args} {

    ::Debug 2 "::Import::NewBrokenImage coords=$coords, args='$args'"
    
    array set argsArr {
	-width      0
	-height     0
	-tags       std
    }
    array set argsArr $args

    foreach {key value} $args {
	switch -- $key {
	    -tags {
		set utag $value
		break
	    }
	}
    }
    if {![info exists utag]} {
	set utag [::CanvasUtils::NewUtag]
    }
    
    # Special 'broken' tag to make it distinct from ordinary images.
    if {[lsearch $argsArr(-tags) broken] < 0} {
	set argsArr(-tags) [list std broken $utag]
    }
    set w [winfo toplevel $wcan]

    set name [::WB::CreateBrokenImage $wcan $argsArr(-width) $argsArr(-height)]

    set id [eval {$wcan create image} $coords \
      {-image $name -anchor nw -tags $argsArr(-tags)}]
    if {[info exists argsArr(-above)]} {
	catch {$wcan raise $utag $argsArr(-above)}
    } 
    if {[info exists optArr(-below)]} {
	catch {$wcan lower $utag $argsArr(-below)}
    }

    # Cache options.
    eval {::CanvasUtils::ItemSet $w $id} [array get argsArr]
}

#-------------------------------------------------------------------------------

