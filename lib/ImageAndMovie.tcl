#  ImageAndMovie.tcl ---
#  
#      This file is part of the whiteboard application. It implements image
#      and movie stuff.
#      
#  Copyright (c) 2002-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: ImageAndMovie.tcl,v 1.2 2003-01-11 16:16:09 matben Exp $

package require http

namespace eval ::ImageAndMovie:: {
    
    # Specials for 'xanim'
    variable xanimPipe2Frame 
    variable xanimPipe2Item
    
    # Cache latest opened dir.
    variable initialDir
    
    variable locals
    set locals(httpuid) 0
}

# ImageAndMovie::ImportImageOrMovieDlg --
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

proc ::ImageAndMovie::ImportImageOrMovieDlg {wtop} {
    global  typelistImageMovie prefMimeType2Package plugin
    
    variable initialDir
    upvar ::${wtop}::wapp wapp

    set wCan $wapp(can)
    if {[info exists initialDir]} {
	set opts {-initialdir $initialDir}
    } else {
	set opts {}
    }
    set fileName [eval {tk_getOpenFile -title [::msgcat::mc {Open Image/Movie}] \
      -filetypes $typelistImageMovie} $opts]
    if {$fileName == ""} {
	return
    }
    set initialDir [file dirname $fileName]
    
    # Once the file name is chosen continue...
    # Perhaps we should dispatch to the registered import procedure for
    # this MIME type.
    set theMime [GetMimeTypeFromFileName $fileName]
    if {[llength $theMime]} {
	set importPackage $prefMimeType2Package($theMime)
	if {[llength $importPackage]} {
	    eval [list $plugin($importPackage,importProc) $wCan  \
	      [list coords: [::CanvasUtils::NewImportAnchor]] -file $fileName]
	} else {
	    tk_messageBox -title [::msgcat::mc Error] -icon error -type ok -message \
	      [::msgcat::mc messfailmimeimp $theMime]
	}
    } else {
	set tail [file tail $fileName]
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok -message \
	  [FormatTextForMessageBox [::msgcat::mc messfailnomime $tail]]
    }
}

# ImageAndMovie::DoImport --
# 
#       Opens an image in the canvas and puts it to all other clients.
#       If QuickTime is supported, a movie can be opened as well.
#       This is the preferred import procedure for QuickTimeTcl, xanim, 
#       and the snack package.
#
# Arguments:
#       w         the canvas widget path.
#       optList   a list of 'key: value' pairs, resembling the html protocol 
#                 for getting files, but where most keys correspond to a valid
#                 "canvas create" option, and everything is on a single line.
#                 BAD!
#       args:          
#            -file      the complete absolute and native path name to the file 
#                       containing the image or movie.
#            -url       complete URL, then where="local".
#            -where     "all": write to this canvas and all others,
#                       "remote": write only to remote client canvases,
#                       "local": write only to this canvas and not to any other.
#                       ip number: write only to this remote client canvas and not
#                       to own.
#       
# Results:
#       Shows the image or movie in canvas and initiates transfer to other
#       clients if requested.

proc ::ImageAndMovie::DoImport {w optList args} {
    global  allIPnumsToSend prefs this prefMimeType2Package supportedMimeTypes
    
    variable xanimPipe2Frame 
    variable xanimPipe2Item
    
    ::Debug 2 "_  DoImport:: optList=$optList"
    ::Debug 2 " \targs='$args'"
    
    array set argsArr {
	-where all
    }
    array set argsArr $args
    if {![info exists argsArr(-file)] && ![info exists argsArr(-url)]} {
	return -code error "::ImageAndMovie::DoImport needs -file or -url"
    }
    if {[info exists argsArr(-file)] && [info exists argsArr(-url)]} {
	return -code error "::ImageAndMovie::DoImport needs -file or -url, not both"
    }
    if {[info exists argsArr(-file)]} {
	set isLocal 1
    } else {
	set isLocal 0
    }
    set wtopNS [::UI::GetToplevelNS $w]
    
    # Define a standard set of put/import options that may be overwritten by
    # the options in the procedure argument 'optList'.
    
    if {$isLocal} {
	
	# An ordinary file on our disk.
	set fileName $argsArr(-file)
	set fileTail [file tail $fileName]
	array set optArr [list   \
	  Content-Type:     [GetMimeTypeFromFileName $fileName]      \
	  size:             [file size $fileName]                    \
	  coords:           {0 0}                                    \
	  tags:             [::CanvasUtils::NewUtag]                 ]
    } else {
	
	# This was an Url.
	set fileName [GetFilePathFromUrl $argsArr(-url)]
	set fileTail [file tail $fileName]
	array set optArr [list   \
	  Content-Type:     [GetMimeTypeFromFileName $fileName]   \
	  coords:           {0 0}                                 \
	  tags:             [::CanvasUtils::NewUtag]              ]
    }
    
    # Now apply the 'optList' and possibly overwrite some of the default options.
    array set optArr $optList
    
    # Make it as a list for PutFile below.
    set putOpts [array get optArr]
    
    # Extract coordinates and tags which must be there. error checking?
    foreach {x y} $optArr(coords:) { break }
    set useTag $optArr(tags:)
    
    # Depending on the MIME type do different things; the MIME type is the
    # primary key for classifying the file. 
    # Note: image/* always through tk's photo handler; package neutral.
    set theMIME $optArr(Content-Type:)
    regexp {([^/]+)/([^/]+)} $theMIME match mimeBase mimeSubType
    set importPackage $prefMimeType2Package($theMIME)
    if {[string equal $mimeBase "image"]} {
	set importer "image"
    } else {
	set importer $importPackage
    }
    
    if {$argsArr(-where) == "all" || $argsArr(-where) == "local"} {
	
	switch -- $importer {
	    
	    image {
		
		# Either '-file localPath' or '-url http://...'
		if {$isLocal} {
		    eval {::ImageAndMovie::DrawImage $wtopNS $fileName $putOpts} \
		      [array get argsArr]
		} else {
		    eval {::ImageAndMovie::HttpGet $wtopNS $argsArr(-url) \
		      $importer $putOpts} [array get argsArr]
		}
	    }
	    
	    QuickTimeTcl {	    
		if {$isLocal} {
		    eval {::ImageAndMovie::DrawQuickTimeTcl $wtopNS $fileName \
		      $putOpts} [array get argsArr]
		} else {
		    eval {::ImageAndMovie::HttpGetQuickTimeTcl $wtopNS  \
		      $argsArr(-url) $putOpts} [array get argsArr]
		    
		    # Perhaps there shall be an option to get QT stuff via
		    # http but without streaming it?
		    if {0} {
		    eval {::ImageAndMovie::HttpGet $wtopNS $argsArr(-url) \
		      $importer $putOpts} [array get argsArr]
		      }
		}
	    }
	    
	    snack {
		if {$isLocal} {
		    eval {::ImageAndMovie::DrawSnack $wtopNS $fileName \
		      $putOpts} [array get argsArr]
		} else {
		    eval {::ImageAndMovie::HttpGet $wtopNS $argsArr(-url) \
		      $importer $putOpts} [array get argsArr]
		}
	    }
	    
	    xanim {	    
		if {$isLocal} {
		    eval {::ImageAndMovie::DrawXanim $wtopNS $fileName \
		      $putOpts} [array get argsArr]
		} else {
		    eval {::ImageAndMovie::HttpGet $wtopNS $argsArr(-url) \
		      $importer $putOpts} [array get argsArr]
		}


	    }
	    default {
		return -code error "Unknown importer for MIME $theMIME"
	    }
	}
    }
}

# ImageAndMovie::DrawImage --
# 
#       Draws the image in 'fileName' onto canvas, taking options
#       in 'optList' into account. May put image to remote peers.

proc ::ImageAndMovie::DrawImage {wtop fileName optList args} {
    global  allIPnumsToSend    
    upvar ::${wtop}::wapp wapp

    ::Debug 2 "::ImageAndMovie::DrawImage wtop=$wtop, args='$args'"
    
    array set optArr $optList
    array set argsArr $args
    set w $wapp(can)
    
    # Extract coordinates and tags which must be there. error checking?
    foreach {x y} $optArr(coords:) { break }
    set useTag $optArr(tags:)
    set theMIME $optArr(Content-Type:)
    regexp {([^/]+)/([^/]+)} $theMIME match mimeBase mimeSubType
    
    # Create internal image.
    if {[info exists optArr(Image-Name:)]} {
	set imageName $optArr(Image-Name:)
    } else {
	set imageName [::CanvasUtils::UniqueImageName]
	lappend putOpts "Image-Name:" $imageName
    }
    
    if {[string equal $mimeSubType "gif"]} {
	image create photo $imageName -file $fileName -format gif
    } else {
	image create photo $imageName -file $fileName
    }
    
    # Treat if image should be zoomed.
    if {[info exists optArr(Zoom-Factor:)] && ($optArr(Zoom-Factor:) != "")} {
	set zoomFactor $optArr(Zoom-Factor:)
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
    set cmd [list create image $x $y   \
      -image $imageName -anchor nw -tags [list image $useTag]]
    eval $w $cmd
    if {[info exists optArr(above:)]} {
	
	# Need a catch here since we can't be sure that other item exists.
	catch {$w raise $useTag $optArr(above:)}
    } elseif {[info exists optArr(below:)]} {
	catch {$w lower $useTag $optArr(below:)}
    }

    # Add to the lists of known files.
    ::FileCache::Set $fileName
    
    # Once the thing lives on the canvas, add a 'putOpts' "above" or
    # "below" if not already there.
    if {($argsArr(-where) != "local") && ([llength $allIPnumsToSend] > 0)} {
	::ImageAndMovie::PutFile $wtop $fileName $argsArr(-where) $putOpts \
	  $useTag
    }
}

# ImageAndMovie::DrawQuickTimeTcl --
# 
#       Draws a local QuickTime movie onto canvas. May initiate put request to
#       remote peers.

proc ::ImageAndMovie::DrawQuickTimeTcl {wtop fileName optList args} {
    global  allIPnumsToSend    
    upvar ::${wtop}::wapp wapp
    
    ::Debug 2 "::ImageAndMovie::DrawQuickTimeTcl args='$args'"
    
    array set optArr $optList
    array set argsArr $args
    set w $wapp(can)
    
    # Extract coordinates and tags which must be there. error checking?
    foreach {x y} $optArr(coords:) { break }
    set useTag $optArr(tags:)    
    
    # Make a frame for the movie; need special class to catch 
    # mouse events.
    set uniqueName [::CanvasUtils::UniqueImageName]		
    set wfr ${w}.fr_${uniqueName}
    frame $wfr -height 1 -width 1 -bg gray40 -class QTFrame    
    set wmovie ${wfr}.m	

    if {[catch {movie $wmovie -file $fileName -controller 1} msg]} {
	tk_messageBox  -icon error -type ok -message \
	  [FormatTextForMessageBox "[::msgcat::mc Error]:  $msg"]
	catch {destroy $wfr}
	return
    }
    
    $w create window $x $y -anchor nw -window $wfr   \
      -tags [list movie $useTag]
    pack $wmovie -in $wfr -padx 3 -pady 3
    
    if {[info exists optArr(above:)]} {
	catch {$w raise $useTag $optArr(above:)}
    }
    set width [winfo reqwidth $wmovie]
    set height [winfo reqheight $wmovie]
    set fileTail [file tail $fileName]

    array set qtTime [$wmovie gettime]
    set lenSecs [expr $qtTime(-movieduration)/$qtTime(-movietimescale)]
    set lenMin [expr $lenSecs/60]
    set secs [format "%02i" [expr $lenSecs % 60]]
    set qtBalloonMsg "$fileTail\nLength: ${lenMin}:$secs"
    
    ::balloonhelp::balloonforwindow $wmovie $qtBalloonMsg

    # Add to the lists of known files.
    ::FileCache::Set $fileName
    
    if {($argsArr(-where) != "local") && ([llength $allIPnumsToSend] > 0)} {
	::ImageAndMovie::PutFile $wtop $fileName $argsArr(-where)  \
	  $optList $useTag
    }
}

# ImageAndMovie::DrawSnack --
# 
#       Draws a local snack movie onto canvas. May initiate put request to
#       remote peers.

proc ::ImageAndMovie::DrawSnack {wtop fileName optList args} {
    global  allIPnumsToSend    
    upvar ::${wtop}::wapp wapp
    
    ::Debug 2 "::ImageAndMovie::DrawSnack args='$args'"
    
    array set optArr $optList
    array set argsArr $args
    set w $wapp(can)
    
    # Extract coordinates and tags which must be there. error checking?
    foreach {x y} $optArr(coords:) { break }
    set useTag $optArr(tags:)    
    
    set uniqueName [::CanvasUtils::UniqueImageName]		
    
    # The snack plug-in for audio. Make a snack sound object.
    
    if {[catch {::snack::sound $uniqueName -file $fileName} msg]} {
	tk_messageBox -icon error -type ok -message \
	  [FormatTextForMessageBox "Snack failed: $msg"]
	return
    }
    set wfr ${w}.fr_${uniqueName}
    frame $wfr -height 1 -width 1 -bg gray40 -class SnackFrame
    set wmovie ${wfr}.m
    ::moviecontroller::moviecontroller $wmovie -snacksound $uniqueName
    $w create window $x $y -anchor nw -window $wfr  \
      -tags [list movie $useTag]
    pack $wmovie -in $wfr -padx 3 -pady 3
    update idletasks
    if {[info exists optArr(above:)]} {
	catch {$w raise $useTag $optArr(above:)}
    }
    set qtBalloonMsg $fileTail
    ::balloonhelp::balloonforwindow $wmovie $qtBalloonMsg
    
    # Add to the lists of known files.
    ::FileCache::Set $fileName
    
    if {($argsArr(-where) != "local") && ([llength $allIPnumsToSend] > 0)} {
	::ImageAndMovie::PutFile $wtop $fileName $argsArr(-where)  \
	  $optList $useTag
    }
}

# ImageAndMovie::DrawXanim --
# 
#       Draws a local xanim movie onto canvas. May initiate put request to
#       remote peers.

proc ::ImageAndMovie::DrawXanim {wtop fileName optList args} {
    global  allIPnumsToSend    
    upvar ::${wtop}::wapp wapp
    
    ::Debug 2 "::ImageAndMovie::DrawXanim args='$args'"
    
    array set optArr $optList
    array set argsArr $args
    set w $wapp(can)
    
    # Extract coordinates and tags which must be there. error checking?
    foreach {x y} $optArr(coords:) { break }
    set useTag $optArr(tags:)    
    
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
    $w create window $x $y -anchor nw -window $wfr -tags "movie $useTag"
    
    # Make special frame for xanim to draw in.
    set frxanim [frame $wfr.xanim -container 1 -bg black  \
      -width $width -height $height]
    place $frxanim -in $wfr -anchor nw -x 3 -y 3
    if {[info exists optArr(above:)]} {
	catch {$w raise $useTag $optArr(above:)}
    }
    
    # Important, make sure that the frame is mapped before continuing.
    update idletasks
    set xatomid [winfo id $frxanim]
    
    # Note trick to pipe stdout as well as stderr. Forks without &.
    if {[catch {open "|xanim +W$xatomid $fileName 2>@stdout"} xpipe]} {
	puts "xanim err: xpipe=$xpipe"
    } else {
	set xanimPipe2Frame($xpipe) $wfr
	set xanimPipe2Item($xpipe) $useTag
	fileevent $xpipe readable [list XanimReadOutput $w $xpipe]
    }    
    
    # Add to the lists of known files.
    ::FileCache::Set $fileName
    
    if {($argsArr(-where) != "local") && ([llength $allIPnumsToSend] > 0)} {
	::ImageAndMovie::PutFile $wtop $fileName $argsArr(-where)  \
	  $optList $useTag
    }
}

# ImageAndMovie::HttpGet --
# 
#       Imports the specified file using http to file.
#       The actual work done via callbacks to the http package.

proc ::ImageAndMovie::HttpGet {wtop url importer optList args} {
    global  this prefs
    variable locals
    
    ::Debug 2 "::ImageAndMovie::HttpGet wtop=$wtop, url=$url, importer=$importer"

    # Make local state array for convenient storage. 
    # Use 'variable' for permanent storage.
    set gettoken [namespace current]::[incr locals(httpuid)]
    variable $gettoken
    upvar 0 $gettoken getstate
    
    set fileTail [file tail [GetFilePathFromUrl $url]]
    set dstPath [file join $prefs(incomingFilePath)  \
      [::uriencode::decodefile $fileTail]]
    if {[catch {open $dstPath w} dst]} {
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox $dst]
	return
    }
    if {[string equal $this(platform) "macintosh"]} {
	set tmopts ""
    } else {
	set tmopts [list -timeout [expr 1000 * $prefs(timeout)]]
    }
    
    # Store stuff in gettoken array.
    set getstate(wtop) $wtop
    set getstate(url) $url
    set getstate(importer) $importer
    set getstate(optList) $optList
    set getstate(args) $args
    set getstate(dstPath) $dstPath
    set getstate(dst) $dst
    set getstate(transport) http
    set getstate(status) ""
    
    # Be sure to set translation correctly for this MIME type.
    # Should be auto detected by ::http::geturl!
    set progCB [list ::ImageAndMovie::HttpProgress $gettoken]
    set commandCB [list ::ImageAndMovie::HttpFinished $gettoken]
    
    if {[catch {eval {
	::http::geturl $url -channel $dst -progress $progCB -command $commandCB
    } $tmopts} token]} {
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox $token]
	return
    }
    upvar #0 $token state
    set getstate(token) $token

    # Handle URL redirects
    foreach {name value} $state(meta) {
        if {[regexp -nocase ^location$ $name]} {
	    close $dst
            eval {::ImageAndMovie::HttpGet $wtop [string trim $value] \
	      $importer $optList} $args
        }
    }
}

# ImageAndMovie::HttpProgress --
# 
#       Progress callback for the http package.

proc ::ImageAndMovie::HttpProgress {gettoken token total current} {
    
    upvar #0 $token state
    upvar #0 $gettoken getstate
    
    set wtop $getstate(wtop)
    set tail [file tail $getstate(dstPath)]
    
    ::Debug 4 "Getting file $tail: $current out of $total"
    
    ::UI::SetStatusMessage $wtop "Getting file $tail: $current out of $total"
    
    # Investigate 'state' for any exceptions.
    if {[::http::status $token] == "error"} {
	# some 2.3 versions seem to lack ::http::error !
	if {[info exists state(error)]} {
	    set errmsg $state(error)
	} else {
	    set errmsg "File transfer error for \"$getstate(url)\""
	}
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok -message \
	  [FormatTextForMessageBox "Failed getting url: $errmsg"]
	catch {file delete $getstate($dstPath)}
	set getstate(status) "error"
	::http::reset $token
    }
}

# ImageAndMovie::HttpFinished --
# 
#       Callback for http package.
#       Invoked callback after the HTTP transaction completes.

proc ::ImageAndMovie::HttpFinished {gettoken token} {

    ::Debug 2 "::ImageAndMovie::HttpFinished gettoken=$gettoken, token=$token"

    upvar #0 $token state
    upvar #0 $gettoken getstate          

    set wtop $getstate(wtop)
    set dstPath $getstate(dstPath)
    set optList $getstate(optList)
    set tail [file tail $getstate(dstPath)]

    # Investigate 'state' for any exceptions.
    set getstate(status) [::http::status $token]
    ::Debug 2 "    ::http::status = $getstate(status)"
    
    switch -- $getstate(status) {
    	timeout {
	tk_messageBox -title [::msgcat::mc Timeout] -icon info -type ok  \
	  -message timeout
	::UI::SetStatusMessage $wtop "Timeout waiting for file $tail"
	catch {close $getstate(dst)}
	return
	}
	ok {
	::UI::SetStatusMessage $wtop "Finished getting file $tail"
	catch {close $getstate(dst)}
	}
	default {
		# ???
	}
    }
    
    if {$getstate(status) == "ok"} {
	switch -- $getstate(importer) {
	    image {
		eval {::ImageAndMovie::DrawImage $wtop $dstPath $optList} \
		  $getstate(args)
	    }
	    QuickTimeTcl {
		
		# This transport method is different from the QT streaming http.
		eval {::ImageAndMovie::DrawQuickTimeTcl $wtop $dstPath $optList} \
		  $getstate(args)
	    }
	    snack {
		eval {::ImageAndMovie::DrawSnack $wtop $dstPath $optList} \
		  $getstate(args)
	    }
	    xanim {
		eval {::ImageAndMovie::DrawXanim $wtop $dstPath $optList} \
		  $getstate(args)
	    }
	    default {
		# ? Registered callback ???
	    }
	}
    }
    
    # Cleanup:
    ::http::cleanup $token
    unset getstate
}

# ImageAndMovie::ResetAllHttp --
# 
#       Cancel and reset all ongoing http transactions for this wtop.

proc ::ImageAndMovie::ResetAllHttp {wtop} {

    set gettokenList [concat  \
      [info vars ::ImageAndMovie::\[0-9\]] \
      [info vars ::ImageAndMovie::\[0-9\]\[0-9\]] \
      [info vars ::ImageAndMovie::\[0-9\]\[0-9\]\[0-9\]]]
    
    ::Debug 2 "::ImageAndMovie::ResetAllHttp gettokenList='$gettokenList'"
    
    foreach gettoken $gettokenList {
	upvar #0 $gettoken getstate          

	if {[info exists getstate(wtop)] && [string equal $getstate(wtop) $wtop]} {
	    switch -- $getstate(transport) {
		http {
		    ::http::reset $getstate(token)
		}
		quicktimehttp {
		    
		    # This should reset everything for this movie.
		    catch {destroy $getstate(wfr)}
		}
	    }
	}
    }
}

# ImageAndMovie::HttpGetQuickTimeTcl --
# 
#       Obtains a QuickTime movie from an url. This is streaming and the
#       movie being streamed must be prepared for this. Currently there
#       is no mechanism for checking this.

proc ::ImageAndMovie::HttpGetQuickTimeTcl {wtop url optList args} {
    upvar ::${wtop}::wapp wapp
    variable locals
    
    ::Debug 2 "::ImageAndMovie::HttpGetQuickTimeTcl"

    # Make local state array for convenient storage. 
    # Use 'variable' for permanent storage.
    set gettoken [namespace current]::[incr locals(httpuid)]
    variable $gettoken
    upvar 0 $gettoken getstate
    
    array set optArr $optList
    set w $wapp(can)    
    
    # Make a frame for the movie; need special class to catch 
    # mouse events. Postpone display until playable from callback.
    set uniqueName [::CanvasUtils::UniqueImageName]		
    set wfr ${w}.fr_${uniqueName}
    frame $wfr -height 1 -width 1 -bg gray40 -class QTFrame    
    set wmovie ${wfr}.m	

    set getstate(wtop) $wtop
    set getstate(url) $url
    set getstate(optList) $optList
    set getstate(args) $args
    set getstate(wfr) $wfr
    set getstate(wmovie) $wmovie
    set getstate(transport) quicktimehttp
    set getstate(qtstate) ""
    set getstate(mapped) 0
    
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

# ImageAndMovie::QuickTimeTclCallback --
# 
#       Callback for QuickTimeTcl package when using -url.

proc ::ImageAndMovie::QuickTimeTclCallback {gettoken w msg {err {}}} {

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
	    ::UI::SetStatusMessage $wtop "Loading: $url"
	}
	playable {
	    set canmap 1
	    ::UI::SetStatusMessage $wtop "Now playable: $url"
	}
	complete {
	    set canmap 1	    
	    ::UI::SetStatusMessage $wtop "Completed: $url"
	}
    }
    
    # If possible to map as a canvas item but is unmapped.
    if {$canmap && !$getstate(mapped)} {
	set getstate(mapped) 1
	::ImageAndMovie::DrawQuickTimeTclFromHttp $gettoken
    }
    
    # Cleanup when completely finished.
    if {$msg == "complete"} {
	unset getstate
    }
}

# ImageAndMovie::DrawQuickTimeTclFromHttp --
#
#       Performs the final stage of drawing the movie to canvas when
#       obtained via the internal QT -url option.

proc ::ImageAndMovie::DrawQuickTimeTclFromHttp {gettoken} {
    upvar #0 $gettoken getstate          
    
    set wtop $getstate(wtop)
    set url $getstate(url)
    
    upvar ::${wtop}::wapp wapp
    
    set w $wapp(can)
    set wfr $getstate(wfr)
    set wmovie $getstate(wmovie)
    array set optArr $getstate(optList)
    
    # Extract coordinates and tags which must be there. error checking?
    foreach {x y} $optArr(coords:) { break }
    set useTag $optArr(tags:)    
    
    $w create window $x $y -anchor nw -window $wfr \
      -tags [list movie $useTag]
    pack $wmovie -in $wfr -padx 3 -pady 3
    
    if {[info exists optArr(above:)]} {
	catch {$w raise $useTag $optArr(above:)}
    }
    set fileName [GetFilePathFromUrl $url]
    set fileTail [file tail $fileName]
    set width [winfo reqwidth $wmovie]
    set height [winfo reqheight $wmovie]
    set qtBalloonMsg "$fileTail"
    ::balloonhelp::balloonforwindow $wmovie $qtBalloonMsg
    
    # Nothing to cache, not possible to transport further.
    # Perhaps possible to do: $wmovie saveas filepath
}

# ImageAndMovie::PutFile --
# 
#       Interface to the PutFile. Must be called after item created to
#       process the canvas stacking order correctly.
#       
# Transfer movie file to all other servers.
# Several options possible:
#   1) flatten, put in httpd directory, and transfer via http.
#   2) make hint track and serve using RTP.
#   3) put as an ordinary binary file, perhaps flattened.

proc ::ImageAndMovie::PutFile {wtop fileName where optList tag} {
    upvar ::${wtop}::wapp wapp

    ::Debug 2 "::ImageAndMovie::PutFile"
        
    set w $wapp(can)
    array set optArr $optList

    if {![info exists optArr(above:)] && ![info exists optArr(below:)]} {
	set idBelow [$w find below $tag]
	if {[string length $idBelow] > 0} {
	    set itnoBelow [::CanvasUtils::GetUtag $w $idBelow 1]
	    if {[string length $itnoBelow] > 0} {
		lappend optList "above:" $itnoBelow
	    }
	} else {
	    set idAbove [$w find above $tag]
	    if {[string length $idAbove] > 0} {
		set itnoAbove [::CanvasUtils::GetUtag $w $idAbove 1]
		if {[string length $itnoAbove] > 0} {
		    lappend optList "below:" $itnoAbove
		}
	    }
	}
    }
    ::PutFileIface::PutFile $wtop $fileName $where $optList
}

# ImageAndMovie::XanimQuerySize --
#
#       Gets size of the movie. If any error, return {}.
#       Check also version number ( >= 2.70 ).

proc ::ImageAndMovie::XanimQuerySize {fileName} {
    global  plugin
    
    set num_ {[0-9]+}
    set ver_ {[0-9]+\.[0-9]+}
    if {![catch {exec xanim +v +Zv $fileName} res]} {
	
	# Check version number.
	if {[regexp "Rev +($ver_)" $res match ver]} {
	    set plugin(xanim,ver) $ver
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

proc ::ImageAndMovie::XanimReadOutput {w xpipe} {
    
    variable xanimPipe2Frame 
    variable xanimPipe2Item

    if [eof $xpipe] {
	
	# Movie is stopped, cleanup.
	set co [$w coords $xanimPipe2Item($xpipe)]
	::CanvasDraw::DeleteItem $w [lindex $co 0] [lindex $co 1] movie
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

# ImageAndMovie::HandleImportCmd --
#
#       Shall be canvasPath neutral and also neutral to file path type.
#       Typically used when reading canvas file version 2.
#
# Arguments:
#       line:       this is typically an "import" command similar to items but
#                   for images and movies that need to be transported.
#                   It shall contain either a -file or -url option, but not both.
#       args:   -where
#               -above
#               -below
#               -basepath
# Results:
#       none. calls importer.

proc ::ImageAndMovie::HandleImportCmd {w line args} {

    Debug 2 "HandleImportCmd: line=$line, args=$args"
    
    if {![string equal [lindex $line 0] "import"]} {
	return -code error {Line is not an "import" line}
    }
    set coords [lrange $line 1 2]
    set opts [lrange $line 3 end]
    array set optArr $opts
    array set argsArr $args
    set impArgs {}
    if {[info exists argsArr(-where)]} {
	lappend impArgs -where $argsArr(-where)
    }
    
    # We must provide the importer with an absolute path if relative path.
    # in 'line'.
    if {[info exists optArr(-file)]} {
	set path $optArr(-file)
	if {[file pathtype $path] == "relative"} {
	    if {![info exists argsArr(-basepath) ]} {
		return -code error {Must have "-basebath" option if relative path}
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
	    
	    Debug 2 "    url \"$url\" is cached"
	} else {
	    lappend impArgs -url $optArr(-url)
	}
    }
    
    # Some options given in 'line' shall be translated to the 'optList'.
    #
    # This is a bit messy with the mixture of optList and '-key value ...'
    set optList [list "coords:" $coords]
    if {[info exists optArr(-tags)]} {
	lappend optList "tags:" $optArr(-tags)
    }
    if {[info exists optArr(-zoom-factor)]} {
	lappend optList "Zoom-Factor:" $optArr(-zoom-factor)
    }
    if {[info exists argsArr(-above)]} {
	lappend optList "above:" $argsArr(-above)
    }
    if {[info exists argsArr(-below)]} {
	lappend optList "below:" $argsArr(-below)
    }
    
    eval {::ImageAndMovie::DoImport $w $optList} $impArgs
}

# ImageAndMovie::ImageImportCmd, QTImportCmd, SnackImportCmd --
#
#       These are handy commands for the undo method.
#       Executing any of these commands should be package neutral.

proc ::ImageAndMovie::ImageImportCmd {w utag} {
    
    set imageName [$w itemcget $utag -image]
    set imageFile [$imageName cget -file]
    set imArgs [list -file $imageFile]
    set optList [list "coords:" [$w coords $utag] "tags:" $utag]
    
    return [concat  \
      [list ::ImageAndMovie::DoImport $w $optList] $imArgs]
}
    
proc ::ImageAndMovie::QTImportCmd {w utag} {
    
    # We need to reconstruct how it was imported.
    set win [$w itemcget $utag -window]
    set wmovie ${win}.m
    set movFile [$wmovie cget -file]
    set movUrl [$wmovie cget -url]
    set optList [list "coords:" [$w coords $utag] "tags:" $utag]
    if {$movFile != ""} {
	set movargs [list -file $movFile]
    } elseif {$movUrl != ""} {
	set movargs [list -url $movUrl]
    }
    return [concat  \
      [list ::ImageAndMovie::DoImport $w $optList] $movargs]
}

proc ::ImageAndMovie::SnackImportCmd {w utag} {
    
    # We need to reconstruct how it was imported.
    # 'wmovie' is a moviecontroller widget.
    set win [$w itemcget $utag -window]
    set wmovie ${win}.m
    set soundObject [$wmovie cget -snacksound]
    set soundFile [$soundObject cget -file]
    set optList [list "coords:" [$w coords $utag] "tags:" $utag]
    set movargs [list -file $soundFile]
    return [concat  \
      [list ::ImageAndMovie::DoImport $w $optList] $movargs]
}

# ImageAndMovie::ResizeImage --
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

proc ::ImageAndMovie::ResizeImage {wtop zoomFactor which newTag {where all}} {
    
    upvar ::${wtop}::wapp wapp
    
    set w $wapp(can)
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
    set idsNew {}
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
	      -tags {image $useTag}"
	    set cmdExList [list [list $cmdlocal "local"]]
	    if {$isAbove != ""} {
		lappend cmdExList [list [list lower $useTag $isAbove] "local"]
	    }
	    set undocmd  \
	      "create image $coords [::CanvasUtils::GetItemOpts $w $id all]"
	    set undocmdExList [list [list $undocmd "local"]  \
	      [list [list delete $useTag] "local"]]
	    lappend idsNew $useTag
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
    
    # Mark the new ones.
    foreach id $idsNew {
	::CanvasDraw::MarkBbox $w 1 $id
    }
}

# GetAutoFitSize --
#
#       Gives a new smaller size of 'theMovie' if it is too large for canvas 'w'.
#       It is rescaled by factors of two.
#       
# Arguments:
#
# Results:

proc GetAutoFitSize {w theMovie} {

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

#-------------------------------------------------------------------------------

