#  Import.tcl ---
#  
#      This file is part of the whiteboard application. It implements image
#      and movie stuff.
#      
#  Copyright (c) 2002-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Import.tcl,v 1.6 2003-11-30 11:46:47 matben Exp $

package require http
package require httpex

namespace eval ::Import:: {
    
    # Specials for 'xanim'
    variable xanimPipe2Frame 
    variable xanimPipe2Item
    
    # Cache latest opened dir.
    variable initialDir
    
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
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       
# Results:
#       Defines option arrays and icons for movie controllers.

proc ::Import::ImportImageOrMovieDlg {wtop} {    
    variable initialDir    
    
    set wCan [::UI::GetCanvasFromWtop $wtop]
    if {[info exists initialDir]} {
	set opts {-initialdir $initialDir}
    } else {
	set opts {}
    }
    set fileName [eval {tk_getOpenFile -title [::msgcat::mc {Open Image/Movie}] \
      -filetypes [::Plugins::GetTypeListDialogOption all]} $opts]
    if {$fileName == ""} {
	return
    }
    set initialDir [file dirname $fileName]
    
    # Once the file name is chosen continue...
    # Perhaps we should dispatch to the registered import procedure for
    # this MIME type.
    set mime [::Types::GetMimeTypeForFileName $fileName]
    if {[::Plugins::HaveImporterForMime $mime]} {
	set opts [list -coords [::CanvasUtils::NewImportAnchor]]	
	set errMsg [::Import::DoImport $wCan $opts -file $fileName]
	if {$errMsg != ""} {
	    tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	      -message "Failed importing: $errMsg"
	}
    } else {
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [::msgcat::mc messfailmimeimp $mime]
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
#       w         the canvas widget path.
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

proc ::Import::DoImport {w opts args} {
    global  prefs this allIPnumsToSend
    
    ::Debug 2 "_  DoImport:: opts=$opts"
    ::Debug 2 " \targs='$args'"
    
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
    set wtopNS [::UI::GetToplevelNS $w]
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
	  -coords   {0 0}                                       \
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
    if {$importPackage == ""} {
	return "No importer found for the file \"$fileTail\" with\
	  MIME type $mime"
    }
    
    # Images are dispatched internally by tk's photo command.
    if {[string equal $mimeBase "image"]} {
	set importer "image"
    } else {
	set importer $importPackage
    }    
    if {$argsArr(-where) == "all" || $argsArr(-where) == "local"} {
	set drawLocal 1
    } else {
	set drawLocal 0
    }
    if {($argsArr(-where) != "local") && ([llength $allIPnumsToSend] > 0)} {
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
			::Import::DrawImage $w putOpts} [array get argsArr]]
		} else {
		    set errMsg [eval {
			::Import::HttpGet $wtopNS $argsArr(-url) \
			  $importer $putOpts
		    } [array get argsArr]]
		}
	    }
	}
	QuickTimeTcl {	    

	    # Let the receiving client be able to load async over http
	    # via QuickTime for instance. Avoid mac server socket bug.
	    # Not possible if we are a "client" only.
	    if {![string equal $this(platform) "macintosh"] &&  \
	      ![string equal $prefs(protocol) "client"]} {
		set optArr(-preferred-transport) "http"
	    }
	    set putOpts [array get optArr]
	    if {$drawLocal} {
		if {$isLocal} {
		    set errMsg [eval {
			::Import::DrawQuickTimeTcl $w putOpts
		    } [array get argsArr]]
		} else {
		    set errMsg [eval {
			::Import::HttpGetQuickTimeTcl $wtopNS  \
			  $argsArr(-url) $putOpts} [array get argsArr]]
			
		    # Perhaps there shall be an option to get QT stuff via
		    # http but without streaming it?
		    if {0} {
			eval {::Import::HttpGet $wtopNS $argsArr(-url) \
			  $importer $putOpts} [array get argsArr]
		    }
		}
	    }
	}
	snack {

	    # Let the receiving client be able to load async over http
	    # via QuickTime for instance. Avoid mac server socket bug.
	    # Not possible if we are a "client" only.
	    if {![string equal $this(platform) "macintosh"] &&  \
	      ![string equal $prefs(protocol) "client"]} {
		set optArr(-preferred-transport) "http"
	    }
	    set putOpts [array get optArr]
	    if {$drawLocal} {
		if {$isLocal} {
		    set errMsg [eval {
			::Import::DrawSnack $w putOpts} [array get argsArr]]
		} else {
		    set errMsg [eval {
			::Import::HttpGet $wtopNS $argsArr(-url) \
			  $importer $putOpts
		    } [array get argsArr]]
		}    
	    }
	}	    
	xanim {	    

	    # Let the receiving client be able to load async over http
	    # via QuickTime for instance. Avoid mac server socket bug.
	    # Not possible if we are a "client" only.
	    if {![string equal $this(platform) "macintosh"] &&  \
	      ![string equal $prefs(protocol) "client"]} {
		set optArr(-preferred-transport) "http"
	    }
	    set putOpts [array get optArr]
	    if {$drawLocal} {
		if {$isLocal} {
		    set errMsg [eval {
			::Import::DrawXanim $w putOpts} [array get argsArr]]
		} else {
		    set errMsg [eval {
			::Import::HttpGet $wtopNS $argsArr(-url) \
			  $importer $putOpts
		    } [array get argsArr]]
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
			$importProc $w putOpts} [array get argsArr]]
		} else {
		    
		    # Find out if this plugin has registerd a special proc
		    # to get from http.
		    if {[::Plugins::HaveHTTPTransportForPlugin $importer]} {
			set impHTTPProc \
			  [::Plugins::GetHTTPImportProcForPlugin $importer]
			set errMsg [eval {
			    $impHTTPProc $wtopNS $argsArr(-url) $putOpts
			} [array get argsArr]]
		    } else {			
			set errMsg [eval {
			    ::Import::HttpGet $wtopNS $argsArr(-url) \
			      $importer $putOpts
			} [array get argsArr]]
		    }
		}    
	    }
	}
    }
    
    # Put to remote peers but require we did not fail ourself.   
    if {$doPut && ($errMsg == "")} {	
	if {$isLocal} {
	    ::Import::PutFile $wtopNS $fileName $argsArr(-where) \
	      $putOpts $useTag
	} else {
	    
	    # This fails if we have -url. Need 'import here. TODO!
	}
    }
    
    # Construct redo/undo entry.
    if {$argsArr(-addundo) && ($errMsg == "")} {
	set redo [concat [list ::Import::DoImport $w $opts -addundo 0] \
	  $args]
	set undo [list ::CanvasUtils::Command $wtopNS [list delete $useTag]]
	undo::add [::UI::GetUndoToken $wtopNS] $undo $redo
    }
    return $errMsg
}

# Import::DrawImage --
# 
#       Draws the image in 'fileName' onto canvas, taking options
#       in 'opts' into account.
#       
# Arguments:
#       w           canvas path
#       optsVar     the *name* of the 'opts' variable.
#       args     -file
#                -data
#       
# Results:
#       an error string which is empty if things went ok.

proc ::Import::DrawImage {w optsVar args} {
    upvar $optsVar opts

    ::Debug 2 "::Import::DrawImage args='$args',\n\topts=$opts"
    
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
    set wtop [::UI::GetToplevelNS $w]
    
    if {[info exists optArr(-image)]} {
	set imageName $optArr(-image)
    } else {
	set imageName [::CanvasUtils::UniqueImageName]
    }
        
    # Create internal image.
    set photoOpts {}
    if {[info exists argsArr(-file)]} {
	lappend photoOpts -file $argsArr(-file)
    } else {
	lappend photoOpts -data $argsArr(-data)
    }
    if {[string equal $mimeSubType "gif"]} {
	lappend photoOpts -format gif
    }
    if {[catch {
	eval {image create photo $imageName} $photoOpts
    } err]} {
	return $err
    }
    
    # Treat if image should be zoomed.
    if {[info exists optArr(-zoom-factor)] && ($optArr(-zoom-factor) != "")} {
	set zoomFactor $optArr(-zoom-factor)
	set newImName ${imageName}_zoom${zoomFactor}
	
	# Make new scaled image.
	image create photo $newImName
	if {$zoomFactor > 0} {
	    $newImName copy $imageName -zoom $zoomFactor
	} else {
	    $newImName copy $imageName -subsample [expr abs($zoomFactor)]
	}
	set imageName $newImName
    }
    set cmd [list create image $x $y -image $imageName -anchor nw  \
      -tags $theTags]
    set id [eval {$w} $cmd]
    
    # Handle stacking order. Need catch since relative items may not yet exist.
    if {[info exists optArr(-above)]} {
	catch {$w raise $utag $optArr(-above)}
    } 
    if {[info exists optArr(-below)]} {
	catch {$w lower $utag $optArr(-below)}
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
    eval {::CanvasUtils::ItemSet $wtop $id} $configOpts
    return $errMsg
}

# Import::DrawQuickTimeTcl --
# 
#       Draws a local QuickTime movie onto canvas.
#       
# Arguments:
#       w           canvas path
#       optsVar     the *name* of the 'opts' variable.
#       args
#
# Results:
#       an error string which is empty if things went ok.

proc ::Import::DrawQuickTimeTcl {w optsVar args} {
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
    
    # Extract coordinates and tags which must be there. error checking?
    foreach {x y} $optArr(-coords) break
    set utag [::CanvasUtils::GetUtagFromTagList $optArr(-tags)]
    set wtop [::UI::GetToplevelNS $w]
    
    # Make a frame for the movie; need special class to catch 
    # mouse events.
    set uniqueName [::CanvasUtils::UniqueImageName]		
    set wfr ${w}.fr_${uniqueName}
    frame $wfr -height 1 -width 1 -bg gray40 -class QTFrame    
    set wmovie ${wfr}.m	

    if {[catch {movie $wmovie -file $fileName -controller 1} err]} {
	catch {destroy $wfr}
	return $err
    }
    
    set id [$w create window $x $y -anchor nw -window $wfr  \
      -tags [list frame $utag]]
    pack $wmovie -in $wfr -padx 3 -pady 3
    
    if {[info exists optArr(-above)]} {
	catch {$w raise $utag $optArr(-above)}
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
	lappend configOpts -file $argsArr(-file)
    }
    if {[info exists optArr(-url)]} {
	lappend configOpts -url $optArr(-url)
    }
    eval {::CanvasUtils::ItemSet $wtop $id} $configOpts

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
#       w           canvas path
#       optsVar  the *name* of the opts variable.
#       args
#
# Results:
#       an error string which is empty if things went ok.

proc ::Import::DrawSnack {w optsVar args} {
    upvar $optsVar opts
    
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
    set wtop [::UI::GetToplevelNS $w]
    
    set uniqueName [::CanvasUtils::UniqueImageName]		
    
    # The snack plug-in for audio. Make a snack sound object.
    
    if {[catch {::snack::sound $uniqueName -file $fileName} err]} {
	return $err
    }
    set wfr ${w}.fr_${uniqueName}
    frame $wfr -height 1 -width 1 -bg gray40 -class SnackFrame
    set wmovie ${wfr}.m
    ::moviecontroller::moviecontroller $wmovie -snacksound $uniqueName
    set id [$w create window $x $y -anchor nw -window $wfr  \
      -tags [list frame $utag]]
    pack $wmovie -in $wfr -padx 3 -pady 3
    update idletasks
    if {[info exists optArr(-above)]} {
	catch {$w raise $utag $optArr(-above)}
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
    eval {::CanvasUtils::ItemSet $wtop $id} $configOpts

    return $errMsg
}

# Import::DrawXanim --
# 
#       Draws a local xanim movie onto canvas.
#       
# Arguments:
#       w           canvas path
#       optsVar     the *name* of the opts variable.
#       args
#
# Results:
#       an error string which is empty if things went ok.

proc ::Import::DrawXanim {w optsVar args} {
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
    set wfr ${w}.fr_${uniqueName}
    
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
    $w create window $x $y -anchor nw -window $wfr -tags [list frame $utag]
    
    # Make special frame for xanim to draw in.
    set frxanim [frame $wfr.xanim -container 1 -bg black  \
      -width $width -height $height]
    place $frxanim -in $wfr -anchor nw -x 3 -y 3
    if {[info exists optArr(-above)]} {
	catch {$w raise $utag $optArr(-above)}
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
	fileevent $xpipe readable [list XanimReadOutput $w $wfr $xpipe]
    }    
    lappend opts -width $width -height $height
    
    return $errMsg
}

# Import::HttpGet --
# 
#       Imports the specified file using http to file.
#       The actual work done via callbacks to the http package.
#       The principle is that if we have any -comman or -progress command
#       all UI is redirected to these procs.
#       
# Arguments:
#       wtop
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

proc ::Import::HttpGet {wtop url importPackage opts args} {
    global  this prefs
    variable locals
    
    ::Debug 2 "::Import::HttpGet wtop=$wtop, url=$url, \
      importPackage=$importPackage, args='$args'"

    # Make local state array for convenient storage. 
    # Use 'variable' for permanent storage.
    set gettoken [namespace current]::[incr locals(httpuid)]
    variable $gettoken
    upvar 0 $gettoken getstate
    
    # We store file names with cached names to avoid name clashes.
    set fileTail [::uriencode::decodefile [file tail  \
      [::Utils::GetFilePathFromUrl $url]]]
    set dstPath [::Import::NewCacheFilePath $fileTail]
    if {[catch {open $dstPath w} dst]} {
	return $dst
    }
    
    # Store stuff in gettoken array.
    set getstate(wtop) $wtop
    set getstate(wcan) [::UI::GetCanvasFromWtop $wtop]
    set getstate(url) $url
    set getstate(importPackage) $importPackage
    set getstate(optList) $opts
    set getstate(args) $args
    set getstate(dstPath) $dstPath
    set getstate(dst) $dst
    set getstate(tail) $fileTail
    set getstate(transport) http
    set getstate(status) ""
    set getstate(error) ""
    
    # Timing data.
    set getstate(firstmillis) [clock clicks -milliseconds]
    set getstate(lastmillis) $getstate(firstmillis)
    set getstate(timingkey) $gettoken
    
    # Be sure to set translation correctly for this MIME type.
    # Should be auto detected by ::httpex::get!
    if {0 && [string equal $this(platform) "macintosh"]} {
	set tmopts ""
    } else {
	set tmopts [list -timeout $prefs(timeoutMillis)]
    }
    
    if {[catch {eval {
	::httpex::get $url -channel $dst  \
	  -progress [list [namespace current]::HttpProgress $gettoken]  \
	  -command  [list [namespace current]::HttpCommand $gettoken]
    } $tmopts} token]} {
	return $token
    }
    upvar #0 $token state
    set getstate(token) $token

    # Handle URL redirects
    foreach {name value} $state(meta) {
        if {[regexp -nocase ^location$ $name]} {
	    close $dst
            eval {::Import::HttpGet $wtop [string trim $value] \
	      $importPackage $opts} $args
        }
    }
    return ""
}

# Import::HttpProgress --
# 
#       Progress callback for the http package.
#       Any -progess command gets only called at an prefs(progUpdateMillis) 
#       interval unless there is an error.


proc ::Import::HttpProgress {gettoken token total current} {
    global prefs
    
    upvar #0 $token state
    upvar #0 $gettoken getstate
    
    ::Debug 9 "."
    array set argsArr $getstate(args)
    if {[info exists argsArr(-progress)] && ($argsArr(-progress) != "")} {
	set haveProgress 1
    } else {
	set haveProgress 0
    }
    
    # Cache timing info.
    ::Timing::Set $getstate(timingkey) $current
    
    # Investigate 'state' for any exceptions.
    set status [::httpex::status $token]
    
    if {[string equal $status "error"]} {
	if {$haveProgress} {
	    uplevel #0 $argsArr(-progress)  \
	      [list $status $gettoken $token $total $current]
	} else {	
	    set errmsg "File transfer error for \"$getstate(url)\""
	    tk_messageBox -title [::msgcat::mc Error] -icon error -type ok -message \
	      [FormatTextForMessageBox "Failed getting url: $errmsg"]
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
		set wtop $getstate(wtop)
		::UI::SetStatusMessage $wtop \
		  "Getting file \"$getstate(tail)\", $current out of $total"
	    }	    
	}
    }
}

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
    set getstate(state) [::httpex::state $token]
    set getstate(status) [::httpex::status $token]
    set getstate(ncode) [httpex::ncode $token]

    ::Debug 2 "::Import::HttpCommand state = $getstate(state)"
    
    set wtop $getstate(wtop)
    set wcan $getstate(wcan)
    set dstPath $getstate(dstPath)
    set opts $getstate(optList)
    set tail $getstate(tail)
    set thestate $getstate(state)
    set status $getstate(status)
    
    # Combined state+status.
    if {[string equal $thestate "final"]} {
	set stateStatus $status
    } else {
	set stateStatus $thestate
    }
    
    array set argsArr $getstate(args)
    if {[info exists argsArr(-command)] && ($argsArr(-command) != "")} {
	set haveCommand 1
    } else {
	set haveCommand 0
    }
    set errMsg ""
    
    # Catch the case when we get a non 200 return code and is otherwise ok.
    if {($thestate == "final") && ($status == "ok") && ($getstate(ncode) != "200")} {
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
		::UI::SetStatusMessage $wtop $msg
		tk_messageBox -title [::msgcat::mc Timeout] -icon info \
		  -type ok -message $msg
	    }
	    ok {
		::UI::SetStatusMessage $wtop "Finished getting file \"$tail\""
	    }
	    error {
		::UI::SetStatusMessage $wtop $errMsg
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
	if {($status == "ok") && ($getstate(ncode) == "200")} {
	    
	    # Add to the lists of known files.
	    ::FileCache::Set $getstate(url) $dstPath
	    
	    # This should delegate the actual drawing to the correct proc.
	    set impErr [::Import::DoImport $wcan $opts -file $dstPath \
	      -where local]
	}
	
	# Catch errors from 'errMsg'.
	if {$errMsg != ""} {
	    set stateStatus error
	    set getstate(error) $errMsg
	} elseif {$impErr != ""} {
	    set stateStatus error
	    set getstate(error) $impErr
	}
	if {$haveCommand} {
	    uplevel #0 $argsArr(-command) [list $stateStatus $gettoken $token]	
	} elseif {$errMsg != ""} {
	    ::UI::SetStatusMessage $wtop "Failed importing \"$tail\" $errMsg"
	}
	
	# Cleanup:
	::httpex::cleanup $token
	if {($errMsg != "") || ($impErr != "")} {
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
    
    set wtop $getstate(wtop)
    
    if {[string equal $status "error"]} {
	# some 2.3 versions seem to lack ::http::error !
	if {[info exists state(error)]} {
	    set errmsg $state(error)
	} else {
	    set errmsg "File transfer error for \"$getstate(url)\""
	}
	::UI::SetStatusMessage $wtop "Failed getting url: $errmsg"
    } else {
	set wcan $getstate(wcan)
	set msg "Getting \"$getstate(tail)\", [::Timing::FormMessage $getstate(timingkey) $total]"
	::UI::SetStatusMessage $wtop $msg
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
    set wcan $getstate(wcan)
    set wtop $getstate(wtop)
    set tail $getstate(tail)
    set thestate $getstate(state)
    set status $getstate(status)

    switch -- $stateStatus {
	timeout {
	    ::UI::SetStatusMessage $wtop "Timeout waiting for file \"$tail\""
	}
	connect {
	    set domain [::Utils::GetDomainNameFromUrl $getstate(url)]
	    ::UI::SetStatusMessage $wtop "Contacting $domain..."
	}
	ok {
	    ::UI::SetStatusMessage $wtop "Finished getting file \"$tail\""
	}
	error {
	    if {$getstate(ncode) != "200"} {
		set status error
		set httpMsg [httpex::ncodetotext $getstate(ncode)]
		set msg "Failed getting file \"$tail\": $httpMsg"
	    } else {
		set msg "Error getting file \"$tail\": "
		append msg [httpex::error $httptoken]
		append msg $getstate(error)
	    }
	    ::UI::SetStatusMessage $wtop $msg
	}
	eof {
	    ::UI::SetStatusMessage $wtop "Error getting file \"$tail\""
	}
    }

    # We should be final here!
    if {[string equal $thestate "final"]} {
	if {$status != "ok"} {
	    eval {::Import::NewBrokenImage $wcan [lrange $line 1 2]} \
	      [lrange $line 3 end]
	}
    }
}

# Import::HttpResetAll --
# 
#       Cancel and reset all ongoing http transactions for this wtop.

proc ::Import::HttpResetAll {wtop} {

    set gettokenList [concat  \
      [info vars ::Import::\[0-9\]] \
      [info vars ::Import::\[0-9\]\[0-9\]] \
      [info vars ::Import::\[0-9\]\[0-9\]\[0-9\]]]
    
    ::Debug 2 "::Import::HttpResetAll wtop=$wtop, gettokenList='$gettokenList'"
    
    foreach gettoken $gettokenList {
	upvar #0 $gettoken getstate          

	if {[info exists getstate(wtop)] &&  \
	  [string equal $getstate(wtop) $wtop]} {
	    ::Debug 3 "\twtop=$wtop, getstate(transport)=$getstate(transport)"
	    
	    switch -- $getstate(transport) {
		http {
		
		    # It may be that the http transaction never started.
		    if {[info exists getstate(token)]} {
			::Debug 3 "\t::httpex::reset $getstate(token)"
		    	::httpex::reset $getstate(token)
		    }
		}
		quicktimehttp {
		    
		    # This should reset everything for this movie.
		    catch {destroy $getstate(wfr)}
		}
	    }
	}
    }
}

# Import::HttpGetQuickTimeTcl --
# 
#       Obtains a QuickTime movie from an url. This is streaming and the
#       movie being streamed must be prepared for this. Currently there
#       is no mechanism for checking this.

proc ::Import::HttpGetQuickTimeTcl {wtop url opts args} {
    variable locals
    
    ::Debug 2 "::Import::HttpGetQuickTimeTcl"

    # Make local state array for convenient storage. 
    # Use 'variable' for permanent storage.
    set gettoken [namespace current]::[incr locals(httpuid)]
    variable $gettoken
    upvar 0 $gettoken getstate
    
    array set optArr $opts
    set w [::UI::GetCanvasFromWtop $wtop]    
    
    # Make a frame for the movie; need special class to catch 
    # mouse events. Postpone display until playable from callback.
    set uniqueName [::CanvasUtils::UniqueImageName]		
    set wfr ${w}.fr_${uniqueName}
    frame $wfr -height 1 -width 1 -bg gray40 -class QTFrame    
    set wmovie ${wfr}.m	

    set getstate(wtop) $wtop
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
	tk_messageBox -icon error -type ok -message \
	  [FormatTextForMessageBox "[::msgcat::mc Error]: $msg"]
	catch {destroy $wfr}
	return
    }
    ::UI::SetStatusMessage $wtop "Opening $url"    
}

# Import::QuickTimeTclCallback --
# 
#       Callback for QuickTimeTcl package when using -url.

proc ::Import::QuickTimeTclCallback {gettoken w msg {err {}}} {

    upvar #0 $gettoken getstate          
    
    set wtop $getstate(wtop)
    set url $getstate(url)
    set getstate(qtstate) $msg
    set canmap 0
    
    switch -- $msg {
	error {
	    set msg "We got an error when trying to load the\
	      movie \"$url\" with QuickTime."
	    if {[string length $err]} {
		append msg " $err"
	    }
	    ::UI::SetStatusMessage $wtop ""
	    tk_messageBox -icon error -type ok \
	      -message [FormatTextForMessageBox $msg]
	    catch {destroy $getstate(wfr)}
	    return
	}
	loading {	    
	    ::UI::SetStatusMessage $wtop "Loading: \"$getstate(tail)\""
	}
	playable {
	    set canmap 1
	    ::UI::SetStatusMessage $wtop "Now playable: \"$getstate(tail)\""
	}
	complete {
	    set canmap 1	    
	    ::UI::SetStatusMessage $wtop "Completed: \"$getstate(tail)\""
	}
    }
    
    # If possible to map as a canvas item but is unmapped.
    if {$canmap && !$getstate(mapped)} {
	set getstate(mapped) 1
	::Import::DrawQuickTimeTclFromHttp $gettoken
    }
    
    # Cleanup when completely finished.
    if {$msg == "complete"} {
	unset getstate
    }
}

# Import::DrawQuickTimeTclFromHttp --
#
#       Performs the final stage of drawing the movie to canvas when
#       obtained via the internal QT -url option.

proc ::Import::DrawQuickTimeTclFromHttp {gettoken} {
    upvar #0 $gettoken getstate          
    
    set wtop $getstate(wtop)
    set url $getstate(url)
        
    set w [::UI::GetCanvasFromWtop $wtop]
    set wfr $getstate(wfr)
    set wmovie $getstate(wmovie)
    array set optArr $getstate(optList)
    
    # Extract coordinates and tags which must be there. error checking?
    foreach {x y} $optArr(-coords) break
    set utag [::CanvasUtils::GetUtagFromTagList $optArr(-tags)]

    $w create window $x $y -anchor nw -window $wfr \
      -tags [list frame $utag]
    pack $wmovie -in $wfr -padx 3 -pady 3
    
    if {[info exists optArr(-above)]} {
	catch {$w raise $utag $optArr(-above)}
    }

    set qtBalloonMsg [::Import::QuickTimeBalloonMsg $wmovie $getstate(tail)]
    ::balloonhelp::balloonforwindow $wmovie $qtBalloonMsg
    
    # Nothing to cache, not possible to transport further.
    # Perhaps possible to do: $wmovie saveas filepath
    #::FileCache::Set $getstate(url) $dstPath
}

# Import::PutFile --
# 
#       Interface to the PutFile. Must be called after item created to
#       process the canvas stacking order correctly.
#       
# Transfer movie file to all other servers.
# Several options possible:
#   1) flatten, put in httpd directory, and transfer via http.
#   2) make hint track and serve using RTP.
#   3) put as an ordinary binary file, perhaps flattened.

proc ::Import::PutFile {wtop fileName where opts tag} {

    ::Debug 2 "::Import::PutFile fileName=$fileName, where=$where"
        
    array set optArr $opts
    set w [::UI::GetCanvasFromWtop $wtop]

    if {![info exists optArr(-above)]} {
	set idBelow [$w find below $tag]
	if {[string length $idBelow] > 0} {
	    set utagBelow [::CanvasUtils::GetUtag $w $idBelow 1]
	    if {[string length $utagBelow] > 0} {
		lappend opts -above $utagBelow
	    }
	} 
    }
    if {![info exists optArr(-below)]} {
	set idAbove [$w find above $tag]
	if {[string length $idAbove] > 0} {
	    set utagAbove [::CanvasUtils::GetUtag $w $idAbove 1]
	    if {[string length $utagAbove] > 0} {
		lappend opts -below $utagAbove
	    }
	}
    }
    ::PutFileIface::PutFileToAll $wtop $fileName $where $opts
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
		puts stderr "[::msgcat::mc Error]: xanim must have at least version 2.7"
		return {}
	    }
	}
	
	# Ok, parse size.
	if {[regexp "Size=(${num_})x(${num_})" $res match w h]} {
	    return [list $w $h]
	} else {
	    return {}
	}
    } else {
	# Error checking...
	puts "XanimQuerySize:: error, res=$res"
	return {}
    }
}

proc ::Import::XanimReadOutput {w wfr xpipe} {
    
    variable xanimPipe2Frame 
    variable xanimPipe2Item

    if [eof $xpipe] {
	
	# Movie is stopped, cleanup.
	set co [$w coords $xanimPipe2Item($xpipe)]
	::CanvasDraw::DeleteFrame $w $wfr [lindex $co 0] [lindex $co 1]
	catch {close $xpipe}
    } else {
	
       # Read each line and try to figure out if anything went wrong.
       gets $xpipe line
       if {[regexp -nocase "(unknown|error)" $line match junk]} {
	   tk_messageBox -message "Something happened when trying to\
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
#       w:          the canvas widget path.
#       line:       this is typically an "import" command similar to items but
#                   for images and movies that need to be transported.
#                   It shall contain either a -file or -url option, but not both.
#       args:   -where
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

proc ::Import::HandleImportCmd {w line args} {
    
    Debug 2 "HandleImportCmd: line=$line, args=$args"
    
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
	    if {[file pathtype $path] == "relative"} {
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
		
		Debug 2 "    url is cached \"$url\""
	    } else {
		lappend impArgs -url $optArr(-url)
		if {[info exists argsArr(-command)]} {
		    lappend impArgs -command $argsArr(-command)
		}
	    }
	}	

	set errMsg [eval {::Import::DoImport $w $opts} $impArgs]
    }
    
    # Not -tryimport or error.
    if {$argsArr(-showbroken) && (($errMsg != "") || !$doImport)} {
	
	# Display a broken image to indicate for the user.
	eval {::Import::NewBrokenImage $w [lrange $line 1 2]} \
	  [lrange $line 3 end]
    }
    
    return $errMsg
}

# Import::ImageImportCmd, QTImportCmd, SnackImportCmd,
#    FrameImportCmd --
#
#       These are handy commands for the undo method.
#       Executing any of these commands should be package neutral.
#       Must be called *before* item is deleted.

proc ::Import::ImageImportCmd {w utag} {
    
    set imageName [$w itemcget $utag -image]
    set imageFile [$imageName cget -file]
    set imArgs [list -file $imageFile]
    set optList [list -coords [$w coords $utag] -tags $utag]
    
    return [concat  \
      [list ::Import::DoImport $w $optList] $imArgs]
}
    
proc ::Import::QTImportCmd {w utag} {
    
    # We need to reconstruct how it was imported.
    set win [$w itemcget $utag -window]
    set wmovie ${win}.m
    set movFile [$wmovie cget -file]
    set movUrl [$wmovie cget -url]
    set optList [list -coords [$w coords $utag] -tags $utag]
    if {$movFile != ""} {
	set movargs [list -file $movFile]
    } elseif {$movUrl != ""} {
	set movargs [list -url $movUrl]
    }
    return [concat  \
      [list ::Import::DoImport $w $optList] $movargs]
}

proc ::Import::SnackImportCmd {w utag} {
    
    # We need to reconstruct how it was imported.
    # 'wmovie' is a moviecontroller widget.
    set win [$w itemcget $utag -window]
    set wmovie ${win}.m
    set soundObject [$wmovie cget -snacksound]
    set soundFile [$soundObject cget -file]
    set optList [list -coords [$w coords $utag] -tags $utag]
    set movargs [list -file $soundFile]
    return [concat  \
      [list ::Import::DoImport $w $optList] $movargs]
}

# Generic command for plugins, typically.

proc ::Import::FrameImportCmd {w utag} {
    
    set wtop [::UI::GetToplevelNS $w]
    set opts [::CanvasUtils::ItemCGet $wtop $utag]
    array set optsArr $opts
    set impArgs {}
    if {[info exists optsArr(-file)]} {
	lappend impArgs -file $optsArr(-file)
    }
    set optList [list -coords [$w coords $utag] -tags $utag]
    
    return [concat  \
      [list ::Import::DoImport $w $optList] $impArgs]
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
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
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

proc ::Import::ResizeImage {wtop zoomFactor which newTag {where all}} {
        
    set w [::UI::GetCanvasFromWtop $wtop]

    Debug 2 "ResizeImage: wtop=$wtop, w=$w, which=$which"
    Debug 2 "    zoomFactor=$zoomFactor"

    set scaleFactor 2
    set int_ {[-0-9]+}
    
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
    if {$which == "sel"} {
	set ids [$w find withtag selected]
    } else {
	set ids [$w find withtag $which]
	if {[llength $ids] == 0} {
	    return
	}
    }
    set idsNewSelected {}
    foreach id $ids {
	
	if {$where == "all" || $where == "local"} {	    
	    set type [$w type $id]
	    if {![string equal $type "image"]} {
		continue
	    }
	    
	    # Check if no privacy problems. Only if 'which' is the selected.
	    set utagOrig [::CanvasUtils::GetUtag $w $id]
	    if {$which == "sel" && $utagOrig == ""} {
		continue
	    }
	    set coords [$w coords $id]
	    set theIm [$w itemcget $id -image]
	    
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
	    if {$newTag == "auto"} {
		set useTag [::CanvasUtils::NewUtag]
	    } else {
		set useTag $newTag
	    }
	    
	    # Be sure to keep old stacking order.
	    set isAbove [$w find above $id]
	    set cmdlocal "create image $coords -image $newImName -anchor nw  \
	      -tags {std image $useTag}"
	    set cmdExList [list [list $cmdlocal "local"]]
	    if {$isAbove != ""} {
		lappend cmdExList [list [list lower $useTag $isAbove] "local"]
	    }
	    set undocmd  \
	      "create image $coords [::CanvasUtils::GetItemOpts $w $id all]"
	    set undocmdExList [list [list $undocmd "local"]  \
	      [list [list delete $useTag] "local"]]
	    
	    # Collect tags of selected originals.
	    if {[lsearch [$w itemcget $id -tags] "selected"] >= 0} {
		lappend idsNewSelected $useTag
	    }
	}
	
	# Assemble remote command.
	if {$where != "local"} {
	    set cmdremote "RESIZE IMAGE: $utagOrig $useTag $zoomFactor"
	    set undocmdremote "RESIZE IMAGE: $useTag $utagOrig [expr -$zoomFactor]"
	    if {$where == "remote" || $where == "all"} {
		lappend cmdExList [list $cmdremote "remote"]
		lappend undocmdExList [list $undocmdremote "remote"]
	    } else {
		lappend cmdExList [list $cmdremote $where]
		lappend undocmdExList [list $undocmdremote $where]
	    }    
	}
	
	# Remove old.
	lappend cmdExList [list [list delete $utagOrig] "local"]
	set redo [list ::CanvasUtils::GenCommandExList $wtop $cmdExList]
	set undo [list ::CanvasUtils::GenCommandExList $wtop $undocmdExList]
	eval $redo
	undo::add [::UI::GetUndoToken $wtop] $undo $redo
    }
    ::UserActions::DeselectAll $wtop
    
    # Mark the new ones if old ones selected.
    foreach id $idsNewSelected {
	::CanvasDraw::MarkBbox $w 1 $id
    }
}

# Import::GetAutoFitSize --
#
#       Gives a new smaller size of 'theMovie' if it is too large for canvas 'w'.
#       It is rescaled by factors of two.
#       
# Arguments:
#
# Results:

proc ::Import::GetAutoFitSize {w theMovie} {

    set factor 2.0
    set canw [winfo width $w]
    set canh [winfo height $w]
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

proc ::Import::SaveImageAsFile {w id} {

    set imageName [$w itemcget $id -image]
    set origFile [$imageName cget -file]
    
    # Do different things depending on if in cache or not.
    if {[file exists $origFile]} {
	set ext [file extension $origFile]
	set initFile Untitled${ext}
	set fileName [tk_getSaveFile -defaultextension $ext   \
	  -title [::msgcat::mc {Save As}] -initialfile $initFile]
	if {$fileName != ""} {
	    file copy $origFile $fileName
	}
    } else {
	set initFile Untitled.gif
	set fileName [tk_getSaveFile -defaultextension gif   \
	  -title [::msgcat::mc {Save As GIF}] -initialfile $initFile]
	if {$fileName != ""} {
	    $imageName write $fileName -format gif
	}
    }
}

proc ::Import::ExportImageAsFile {w id} {
    
    set imageName [$w itemcget $id -image]
    catch {$imageName write {Untitled.gif} -format {quicktime -dialog}}
}

proc ::Import::ExportMovie {wtop winfr} {
    
    set wmov ${winfr}.m
    $wmov export
}

# Import::ReloadImage --
# 
#       Reloads a binary entity, image and such.

proc ::Import::ReloadImage {wtop id} {
        
    ::Debug 3 "::Import::ReloadImage"
    
    # Need to have an url stored here.
    set wcan [::UI::GetCanvasFromWtop $wtop]
    set opts [::CanvasUtils::ItemCGet $wtop $id]
    array set optsArr $opts  
    set coords [$wcan coords $id]
        
    if {![info exists optsArr(-url)]} {
	tk_messageBox -icon error -type ok -message \
	  "No url found for the file \"$fileTail\" with MIME type $mime"
	return
    }

    # Unselect and delete. Any new failure will make a new broken image.
    # Only locally and not tracked by undo/redo.
    ::CanvasDraw::DeselectItem $wtop $id
    catch {$wcan delete $id}
    set line [concat import $coords $opts]
    
    set errMsg [eval {
	::Import::HandleImportCmd $wcan $line -where local   \
	  -progess [list [namespace current]::ImportProgress $line] \
	  -command [list [namespace current]::ImportCommand $line]
    }]
    if {$errMsg != ""} {

	# Display a broken image to indicate for the user.
	eval {::Import::NewBrokenImage $wcan $coords} $opts
	tk_messageBox -icon error -type ok -message \
	  "Failed loading \"$optsArr(-url)\": $errMsg"
    }
}

# Import::NewBrokenImage --
# 
#       Draws a broken image instaed of an ordinary image to indicate some
#       kind of failure somewhere.
# 
# Arguments:
#
# Results:

proc ::Import::NewBrokenImage {w coords args} {

    ::Debug 2 "::Import::NewBrokenImage coords=$coords, args='$args'"
    
    array set argsArr {
	-width      0
	-height     0
	-tags       ""
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
	set argsArr(-tags) [list broken $utag]
    }
    set wtop [::UI::GetToplevelNS $w]

    set name [::UI::CreateBrokenImage $wtop $argsArr(-width) $argsArr(-height)]

    set id [eval {$w create image} $coords {-image $name -anchor nw  \
      -tags $argsArr(-tags)}]
    if {[info exists argsArr(-above)]} {
	catch {$w raise $utag $argsArr(-above)}
    } 
    if {[info exists optArr(-below)]} {
	catch {$w lower $utag $argsArr(-below)}
    }

    # Cache options.
    eval {::CanvasUtils::ItemSet $wtop $id} [array get argsArr]
}

# Import::NewCacheFilePath --
# 
#       Creates a unique file path to our incoming directory, keeping any
#       file suffix intact.

proc ::Import::NewCacheFilePath {fileName} {
    global  prefs
    
    set tail "[::Utils::GenerateHexUID][file extension $fileName]"
    return [file join $prefs(incomingPath) $tail]
}

#-------------------------------------------------------------------------------

