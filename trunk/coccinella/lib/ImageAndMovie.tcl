#  ImageAndMovie.tcl ---
#  
#      This file is part of the whiteboard application. It implements image
#      and movie stuff.
#      
#  Copyright (c) 2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: ImageAndMovie.tcl,v 1.1.1.1 2002-12-08 11:03:21 matben Exp $

namespace eval ::ImageAndMovie:: {
    
    namespace export what
    
    # Specials for 'xanim'
    variable xanimPipe2Frame 
    variable xanimPipe2Item
    
    # Cache latest opened dir.
    variable initialDir
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
#                       to own, 
#       
# Results:
#       Shows the image or movie in canvas and initiates transfer to other
#       clients if requested.

proc ::ImageAndMovie::DoImport {w optList args} {
    global  allIPnumsToSend prefs this  \
      prefMimeType2Package supportedMimeTypes

    variable xanimPipe2Frame 
    variable xanimPipe2Item
    variable loadstate
    
    Debug 2 "_  DoImport:: optList=$optList"
    Debug 2 " \targs='$args'"

    array set argsArr {-where all}
    array set argsArr $args
    if {![info exists argsArr(-file)] && ![info exists argsArr(-url)]} {
	error "::ImageAndMovie::DoImport needs -file or -url"
    }
    if {[info exists argsArr(-file)] && [info exists argsArr(-url)]} {
	error "::ImageAndMovie::DoImport needs -file or -url, not both"
    }
    if {[info exists argsArr(-file)]} {
	set isLocal 1
    } else {
	set isLocal 0
    }
    set wtopNS [::UI::GetToplevelNS $w]
    set dot_ {\.}
    
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
    set theMIME $optArr(Content-Type:)
    regexp {([^/]+)/([^/]+)} $theMIME match mimeBase mimeSubType
   
    if {[string equal $mimeBase "image"]} {
	
	# Image: seem to work identically for all packages.
	# There is a potential problem here for the Img package since
	# a postscript file is considered an image but has mime type
	# 'application'.
	
	if {$argsArr(-where) == "all" || $argsArr(-where) == "local"} {
	    
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
	    if {[info exists optArr(Zoom-Factor:)] &&   \
	      ($optArr(Zoom-Factor:) != "")} {
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
	}

	# Transfer image file to all other servers.
	# Be sure to keep the list structure of 'putOpts'.
	
	if {($argsArr(-where) != "local") && ([llength $allIPnumsToSend] > 0)} {
    
	    # Once the thing lives on the canvas, add a 'putOpts' "above" or
	    # "below" if not already there.
	    if {![info exists optArr(above:)] &&   \
	      ![info exists optArr(below:)]} {
		set idBelow [$w find below $useTag]
		if {[string length $idBelow] > 0} {
		    set itnoBelow [::CanvasUtils::GetUtag $w $idBelow 1]
		    if {[string length $itnoBelow] > 0} {
			lappend putOpts "above:" $itnoBelow
		    }
		} else {
		    set idAbove [$w find above $useTag]
		    if {[string length $idAbove] > 0} {
			set itnoAbove [::CanvasUtils::GetUtag $w $idAbove 1]
			if {[string length $itnoAbove] > 0} {
			    lappend putOpts "below:" $itnoAbove
			}
		    }
		}
	    }
	    ::PutFileIface::PutFile $wtopNS $fileName $argsArr(-where) $putOpts
	}	
	
    } elseif {([lsearch $supportedMimeTypes(QuickTimeTcl) $theMIME] >= 0) ||  \
      ([lsearch $supportedMimeTypes(xanim) $theMIME] >= 0) ||  \
      ([lsearch $supportedMimeTypes(snack) $theMIME] >= 0)} {

	# QuickTime and other movies.
	# In order to catch mouse events, we use a frame with a specific class
	# to put the movie in; used for dragging etc.
	
	set uniqueName [::CanvasUtils::UniqueImageName]		
	set wfr ${w}.fr_${uniqueName}
	
	if {$argsArr(-where) == "all" || $argsArr(-where) == "local"} {
	   
	    # Need to search each package or helper application to find out
	    # which to choose for this type of file.
	    
	    set importPackage $prefMimeType2Package($theMIME)
	    if {[string equal $importPackage "QuickTimeTcl"]} {
	    
		# QuickTime:
		# Import the movie only if not exists already.	    
		# Make a frame for the movie; need special class to catch 
		# mouse events.
		frame $wfr -height 1 -width 1 -bg gray40 -class QTFrame
		
		set wmovie ${wfr}.m	
		if {$isLocal} {
		    if {[catch {movie $wmovie -file $fileName -controller 1} msg]} {
			tk_messageBox  -icon error -type ok -message \
			  [FormatTextForMessageBox "[::msgcat::mc Error]:  $msg"]
			catch {destroy $wfr}
			return
		    }
		} else {
		    
		    # Here we should do this connection async!!!
		    set loadstate($wmovie) {}
		    set callback [list [namespace current]::MovieLoadCallback \
		      $argsArr(-url)]
		    if {[catch {movie $wmovie -url $argsArr(-url)  \
		      -loadcommand $callback} msg]} {
			tk_messageBox -icon error -type ok -message \
			  [FormatTextForMessageBox "[::msgcat::mc Error]:  $msg"]
			catch {destroy $wfr}
			return
		    }
		    ::UI::SetStatusMessage $wtopNS "Opening $argsArr(-url)"
		    
		    # Here we wait for a callback from the -loadstate proc.
		    tkwait variable [namespace current]::loadstate($wmovie)
		    if {[string equal $loadstate($wmovie) "error"]} {
			set msg "We got an error when trying to load the\
			  movie [file tail $fileName] with QuickTime."
			if {[info exists loadstate(errMsg,$wmovie)]} {
			    append msg " $loadstate(errMsg,$wmovie)"
			}
			::UI::SetStatusMessage $wtopNS ""
			tk_messageBox -icon error -type ok \
			  -message [FormatTextForMessageBox $msg]
			catch {destroy $wfr}
			return
		    }
		}
		$w create window $x $y -anchor nw -window $wfr   \
		  -tags [list movie $useTag]
		pack $wmovie -in $wfr -padx 3 -pady 3
		
		if {0 && $prefs(autoFitMovies)} {
		    set newSize [GetAutoFitSize $w $wmovie]
		    eval $wmovie configure  \
		      -width [lindex $newSize 0] -height [lindex $newSize 1]
		}
		if {[info exists optArr(above:)]} {
		    catch {$w raise $useTag $optArr(above:)}
		}
		set width [winfo reqwidth $wmovie]
		set height [winfo reqheight $wmovie]
		if {$isLocal} {
		    array set qtTime [$wmovie gettime]
		    set lenSecs [expr $qtTime(-movieduration)/$qtTime(-movietimescale)]
		    set lenMin [expr $lenSecs/60]
		    set secs [format "%02i" [expr $lenSecs % 60]]
		    set qtBalloonMsg "$fileTail\nLength: ${lenMin}:$secs"
		} else {
		    set qtBalloonMsg "$fileTail"
		}
		::balloonhelp::balloonforwindow $wmovie $qtBalloonMsg

	    } elseif {[string equal $importPackage "xanim"]} {

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
		
	    } elseif {[string equal $importPackage "snack"]} {
		
		# The snack plug-in for audio. Make a snack sound object.

		frame $wfr -height 1 -width 1 -bg gray40 -class SnackFrame
		if {[catch {::snack::sound $uniqueName -file $fileName} msg]} {
		    tk_messageBox -icon error -type ok -message \
		      [FormatTextForMessageBox "Snack failed: $msg"]
		    destroy $wfr
		    return
		}
		set wmovie ${wfr}.m
		::moviecontroller::moviecontroller $wmovie -snacksound $uniqueName
		$w create window $x $y -anchor nw -window $wfr   \
		  -tags [list movie $useTag]
		pack $wmovie -in $wfr -padx 3 -pady 3
		update idletasks
		if {[info exists optArr(above:)]} {
		    catch {$w raise $useTag $optArr(above:)}
		}
		set qtBalloonMsg "$fileTail"
		::balloonhelp::balloonforwindow $wmovie $qtBalloonMsg
	    }
	}
	
	# Transfer movie file to all other servers.
	# Several options possible:
	#   1) flatten, put in httpd directory, and transfer via http.
	#   2) make hint track and serve using RTP.
	#   3) put as an ordinary binary file, perhaps flattened.
	
	if {($argsArr(-where) != "local") && ([llength $allIPnumsToSend] > 0)} {
	    
	    # Need to flatten QT movie first?
	    #set tmpflat "flatten_$fileRoot"
	    #$wmovie flatten $tmpflat
	    
	    # Transfer the movie file to all other servers.
	    # Be sure to keep the list structure of 'putOpts'.
	    
	    # Once the thing lives on the canvas, add a 'putOpts' "above".
	    set idBelow [$w find below $useTag]
	    if {[string length $idBelow] > 0} {
		set itnoBelow [::CanvasUtils::GetUtag $w $idBelow 1]
		if {[string length $itnoBelow] > 0} {
		    lappend putOpts "above:" $itnoBelow
		}
	    }
	    
	    # Let the receiving client be able to load async over http
	    # via QuickTime for instance. Avoid mac server socket bug.
	    # Not possible if we are a "client" only.
	    if {![string equal $this(platform) "macintosh"] &&  \
	      ![string equal $prefs(protocol) "client"]} {
		lappend putOpts "preferred-transport:" "http"
	    }
	    
	    # The client must detemine how it wants the movie to be receieved,
	    # and respond to 'PutFile' how it wants it (http, RTP...).
	    ::PutFileIface::PutFile $wtopNS $fileName $argsArr(-where) $putOpts
	}
    }
    
    # Add to the lists of known files. If -url then we need to cache it
    # elsewhere. QuickTime's internal cache here is a problem...
    if {$isLocal} {
	::FileCache::Set $fileName
    }
}

proc ::ImageAndMovie::MovieLoadCallback {url w msg {err {}}} {
    variable loadstate
    
    set wtopNS [::UI::GetToplevelNS $w]
    if {[string equal $msg "error"]} {
	set loadstate($w) "error"
	set loadstate(errMsg,$w) $err
    } elseif {[string equal $msg "playable"]} {
	set loadstate($w) "playable"
	::UI::SetStatusMessage $wtopNS "Now playable: $url"
    } elseif {[string equal $msg "loading"]} {
	::UI::SetStatusMessage $wtopNS "Loading: $url"
    } elseif {[string equal $msg "complete"]} {
	set loadstate($w) "complete"
	::UI::SetStatusMessage $wtopNS "Completed: $url"
    }
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
#
#       line:       this is typically an "import" command similar to items but
#                   for images and movies that need to be transported.
#       args:   -where
#               -above
#               -below
#               -basepath

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
    set ind [lsearch -exact $line "-file"]
    if {$ind >= 0} {
	set path [lindex $line [expr $ind + 1]]
	if {[file pathtype $path] == "relative"} {
	    if {![info exists argsArr(-basepath) ]} {
		return -code error {Must have "-basebath" option if relative path}
	    }
	    set path [addabsolutepathwithrelative $argsArr(-basepath) $path]
	    set path [file nativename $path]
	}
	lappend impArgs -file $path
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

