#  CanvasUtils.tcl ---
#  
#      This file is part of the whiteboard application. It implements some
#      miscellaneous utilities for canvas operations.
#      
#  Copyright (c) 2000-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: CanvasUtils.tcl,v 1.12 2003-09-28 06:29:08 matben Exp $

package provide CanvasUtils 1.0
package require sha1pure

namespace eval ::CanvasUtils:: {
    
    variable itemAfterId
    variable popupVars
}

proc ::CanvasUtils::Init { } {
    global  this prefs env
    variable utaguid
    variable utagpref
    variable utagpref2
    variable importAnchor
    
    # Present anchor coordinates when importing images and movies.
    # Gets translated with 'prefs(offsetCopy)' for each new imported item.
    set importAnchor(x) $prefs(offsetCopy)
    set importAnchor(y) $prefs(offsetCopy)
    
    # Running tag number must be unique for each item.
    # It is always used in conjunction with the local prefix as $prefix/$itno.
    # It is *never* reused during the lifetime of the application.
    # It is updated *only* when writing to own canvas.
    # When the server part writes to the canvas it is the prefix/no of the
    # remote client that is used.
    # Need to make sure we don't get: "integer value too large to represent"
    
    if {[catch {
        set utaguid [format %i 0x[string range [sha1pure::sha1 [clock clicks]$this(hostname)] 0 6]]
    }]} {
        set utaguid [string trimleft [string range [expr rand()] 2 10] 0]
    }
    
    # Unique tag prefix for items created by this client.
    set utagpref $this(hostname)
    if {$utagpref == ""} {
        set utagpref $this(internalIPname)
    }
    
    # Incompatible change!!!
    if {$this(ipver) == 4} {
	set utagpref2 "u[eval {format %02x%02x%02x%02x} [split $this(ipnum) .]]"
    } else {
	
	# Needs to be investigated!
	set utagpref2 "u[join [split $this(ipnum) :] ""]"
    }
    
    # On multiuser platforms (unix) prepend the user name; no spaces allowed.
    if {[string equal $this(platform) "unix"] && [info exists env(USER)]} {
        set user $this(username)
        regsub -all " " $user "" user
        set utagpref ${user}@${utagpref}
    }
}

# CanvasUtils::Command --
#
#       Executes a canvas command both in the local canvas and all remotely
#       connected. Useful for implementing Undo/Redo.
#       
# Arguments:
#       wtop    namespaced toplevel (.top.)
#       cmd     canvas command without canvasPath
#       where   (D="all"):
#               "local"  only local canvas
#               "remote" only remote canvases
#               ip       name or number; send only to this address, not local.

proc ::CanvasUtils::Command {wtop cmd {where all}} {
    global  allIPnumsToSend
    
    set w [::UI::GetCanvasFromWtop $wtop]
    if {[string equal $where "all"] || [string equal $where "local"]} {
        eval {$w} $cmd
    }
    if {[string equal $where "all"] || [string equal $where "remote"]} {
        if {[llength $allIPnumsToSend]} {
            SendClientCommand $wtop "CANVAS: $cmd"
        }    
    } elseif {![string equal $where "local"]} {
        SendClientCommand $wtop "CANVAS: $cmd"  
    }
}

# CanvasUtils::CommandList --
#
#       Gives an opportunity to have a list of commands to be executed.

proc ::CanvasUtils::CommandList {wtop cmdList {where all}} {
    
    foreach cmd $cmdList {
        ::CanvasUtils::Command $wtop $cmd $where
    }
}

# CanvasUtils::CommandExList --
#
#
#       Makes it possible to have different commands local and remote.

proc ::CanvasUtils::CommandExList {wtop cmdExList} {
    
    foreach cmdList $cmdExList {
        foreach {cmd where} $cmdList {
            ::CanvasUtils::Command $wtop $cmd $where
        }
    }
}

# Identical to the procedures above but are not constrained to the
# "CANVAS:" prefix. The prefix shall be included in 'cmd'.

proc ::CanvasUtils::GenCommand {wtop cmd {where all}} {
    global  allIPnumsToSend
    
    set w [::UI::GetCanvasFromWtop $wtop]
    if {[string equal $where "all"] || [string equal $where "local"]} {
        eval {$w} $cmd
    }
    if {[string equal $where "all"] || [string equal $where "remote"]} {
        if {[llength $allIPnumsToSend]} {
            SendClientCommand $wtop $cmd
        }    
    } elseif {![string equal $where "local"]} {
        SendClientCommand $wtop $cmd
    }
}

proc ::CanvasUtils::GenCommandList {wtop cmdList {where all}} {
    
    foreach cmd $cmdList {
        ::CanvasUtils::GenCommand $wtop $cmd $where
    }
}

proc ::CanvasUtils::GenCommandExList {wtop cmdExList} {
    
    foreach cmdList $cmdExList {
        foreach {cmd where} $cmdList {
            ::CanvasUtils::GenCommand $wtop $cmd $where
        }
    }
}

# CanvasUtils::NewUtag --
#
#       Return unique id tag for a canvas item.

proc ::CanvasUtils::NewUtag {{doincr 1}} {
    variable utaguid
    variable utagpref
    variable utagpref2
    
    if {$doincr} {
        incr utaguid
    }
    
    # Incompatible change!
    return ${utagpref}/${utaguid}
    #return ${utagpref2}/${utaguid}
}

# CanvasUtils::GetUtag --
#   
#       Finds the specific item identifier from 'fromWhat'.
#      If 'privacy' then returns empty string of not item made here or
#      if made by xxx...
#   
# Arguments:
#       c         the canvas widget path.
#       fromWhat  "current": picks the current item
#                 "focus": picks the item that has focus
#                 canvas id number: takes the specified canvas id
#       force     If 'force' then do not respect privacy.
#       
# Results:
#       app specific item identifier

proc ::CanvasUtils::GetUtag {c fromWhat {force 0}} {
    global  prefs
    variable utagpref
    variable utagpref2
    
    # Find the 'utag'.
    set pre_ {[^/ ]+}
    set digits_ {[0-9]+}
    set wild_ {[xX]+}
    set utagpre_ ${wild_}|${utagpref}|${utagpref2}
    
    if {[string equal $fromWhat "current"]} {
        set tags [$c gettags current]
    } elseif {[string equal $fromWhat "focus"]} {
        set tags [$c gettags [$c focus]]
    } else {
        set tags [$c gettags $fromWhat]
    }
    if {$tags == ""} {
        return ""
    }
    if {$prefs(privacy) && !$force} {
	
	# Need to be compatible with both 'utagpref' and 'utagpref2'!
	# Introduced with 0.94.4
        if {[regexp "((${utagpre_})/${digits_})" $tags utag]} {
	    return $utag
        } else {
	    return ""
	}
    } else {
        if {[regexp "(^| )(${pre_}/${digits_})" $tags m junk utag]} {
	    return $utag
        } else {
	    return ""
	}
    }
}

# CanvasUtils::GetUtagPrefix --
#
#       Returns the unique tag prefix for this client.

proc ::CanvasUtils::GetUtagPrefix { } {
    variable utagpref
    
    return $utagpref
}

# CanvasUtils::GetUtagFromCmd --
#
#       Takes a canvas command and returns the utag if any.

proc ::CanvasUtils::GetUtagFromCmd {str} {
    
    set utag ""
    set ind [lsearch -exact $str "-tags"]
    if {$ind >= 0} {
        regexp {[^/ ]+/[0-9]+} [lindex $str [incr ind]] utag
    }    
    return $utag
}

# CanvasUtils::ReplaceUtag --
#
#       Takes a canvas command and replaces the utag with new utag.

proc ::CanvasUtils::ReplaceUtag {str newUtag} {
    
    set ind [lsearch -exact $str "-tags"]
    if {$ind >= 0} {
        incr ind
        set tags [lindex $str $ind]
        if {[regsub {[^/ ]+/[0-9]+} $tags $newUtag tags]} {
            #set str [lreplace $str $ind $ind $tags]
            lset str $ind $tags
	}
    }    
    return $str
}

# CanvasUtils::GetUndoCommand --
#
#       Finds the inverse canvas command. The actual item is assumed
#       to exist except for the 'create' method.
#   
# Arguments:
#       cmd         a canvas command without pathName.
#       
# Results:
#       a complete command

proc ::CanvasUtils::GetUndoCommand {wtop cmd} {
    
    set w [::UI::GetCanvasFromWtop $wtop]
    set undo {}
    
    switch -- [lindex $cmd 0] {
	coords {
	    set utag [lindex $cmd 1]
	    set canUndo [concat [list coords $utag] [$w coords $utag]]
	}
	create {
	    set ind [lsearch -exact $cmd "-tags"]
	    if {$ind > 0} {
		set tags [lindex $cmd [expr $ind + 1]]
		if {[regexp {([^ ]+/[0-9]+)} $tags match utag]} {
		    set canUndo [list delete $utag]
		}
	    }
	}
	dchars {
	    set utag [lindex $cmd 1]
	    set ind [lindex $cmd 2]
	    set ilast [lindex $cmd end]
	    set thetext [$w itemcget $utag -text]
	    set str [string range $thetext $ind $ilast]
	    set canUndo [list insert $utag $ind $str]
	}
	delete {
	    set utag [lindex $cmd 1]
	    set type [$w type $utag]
	    
	    switch -- $type {
		window {
		    
		    # This is something that is embedded. QuickTime?
		    # We need to reconstruct how it was imported.
		    set win [$w itemcget $utag -window]
		    if {$win != ""} {
			set winClass [winfo class $win]

			switch -- $winClass {
			    QTFrame {
				set undo [::Import::QTImportCmd $w $utag]
			    }
			    SnackFrame {
				set undo [::Import::SnackImportCmd $w $utag]
			    }
			    default {

				# Typically a plugin.
				set undo [::Import::FrameImportCmd $w $utag]
			    }
			}
		    }
		}
		default {
		    set co [$w coords $utag]
		    set opts [GetItemOpts $w $utag]
		    set canUndo [concat [list create $type] $co $opts]
		    #set canUndo [concat [list create $type] $co $opts  \
		    #  [::CanvasUtils::GetStackingOption $w $utag]]
		}
	    }
	}
	insert {
	    foreach {dum utag ind str} $cmd break
	    set canUndo [list dchars $utag $ind [expr $ind + [string length $str]]]
	}
	move {
	    foreach {dum utag dx dy} $cmd break
	    set canUndo [list move $utag [expr -$dx] [expr -$dy]]
	}
	lower - raise {
	    set utag [lindex $cmd 1]
	    set canUndo [GetStackingCmd $w $utag]
	}
    }
    
    # If we've got a canvas command, make a complete command.
    if {[info exists canUndo]} {
	set undo [list ::CanvasUtils::Command $wtop $canUndo]	
    }
    return $undo
}


proc ::CanvasUtils::RegisterUndoRedoCmd {cmd} {
    
    

}

# CanvasUtils::GetOnelinerForItem --
#
#       Returns an item as a single line suitable for storing on file or
#       sending on network. Not for images or windows!

proc ::CanvasUtils::GetOnelinerForItem {w id} {
    global  prefs fontPoints2Size
    
    set opts [$w itemconfigure $id]
    set type [$w type $id]
    if {[string equal $type "image"] || [string equal $type "window"]} {
	return -code error "items of type \"$type\" not allowed here"
    }
    set opcmd {}
    set nl_ {\\n}
    
    foreach opt $opts {
	set op [lindex $opt 0]
	set defval [lindex $opt 3]
	set val [lindex $opt 4]
	if {[string equal $defval $val]} {
	    continue
	}
	if {[string equal $op "-text"]} {
	    
	    # If multine text, encode as one line with explicit "\n".
	    regsub -all "\n" $val $nl_ oneliner
	    regsub -all "\r" $oneliner $nl_ oneliner
	    set val $oneliner
	} elseif {[string equal $op "-tags"]} {
	    
	    # Any tags "current" or "selected" must be removed 
	    # before save, else when writing them on canvas things 
	    # become screwed up.		
	    regsub -all "current" $val "" val
	    regsub -all "selected" $val "" val
	} elseif {[string equal $op "-smooth"]} {
	    
	    # Seems to be a bug in tcl8.3; -smooth should be 0/1, 
	    # not bezier.		
	    if {$val == "bezier"} {
		set val 1
	    }
	}
	if {$prefs(useHtmlSizes) && [string equal $op "-font"]} {
	    set val [lreplace $val 1 1 $fontPoints2Size([lindex $val 1])]
	}
	lappend opcmd $op $val
    }
    
    return [concat "create" $type [$w coords $id] $opcmd]
}

# CanvasUtils::GetOnelinerForImage, ... --
#
#       Makes a line that is suitable for file storage. Shall be understood
#       by '::Import::HandleImportCmd'.
#
# Arguments:
#       w           the canvas widget
#       id
#       args:
#           -basepath absolutePath    translate image -file to a relative path.
#           -uritype ( file | http )

proc ::CanvasUtils::GetOnelinerForImage {w id args} {
    
    set type [$w type $id]
    if {![string equal $type "image"]} {
	return -code error "must have an \"image\" item type"
    }
    array set argsArr {
	-uritype file
    }
    array set argsArr $args
    set impArgs {}
    set wtop [::UI::GetToplevelNS $w]
    
    # The 'broken image' options are cached.
    set cachedOpts [::CanvasUtils::ItemCGet $wtop $id]
    
    if {$cachedOpts == ""} {
	set imageName [$w itemcget $id -image]
   
	# Find out if zoomed.		
	if {[regexp {(.+)_zoom(|-)([0-9]+)} $imageName match origImName \
	  sign factor]} {
	    
	    # Find out the '-file' option from the original image.
	    set imageFile [$origImName cget -file]
	    lappend impArgs -zoom-factor ${sign}${factor}
	} else {
	    set imageFile [$imageName cget -file]		    
	}
	lappend impArgs -width [image width $imageName] \
	  -height [image height $imageName]
	
	switch -- $argsArr(-uritype) {
	    file {
		if {[info exists argsArr(-basepath)]} {
		    set imageFile [filerelative $argsArr(-basepath) $imageFile]
		}
		lappend impArgs -file $imageFile
	    }
	    http {
		lappend impArgs -url [::CanvasUtils::GetHttpFromFile $imageFile]
	    }
	    default {
		return -code error "Unknown -uritype \"$argsArr(-uritype)\""
	    }
	}
    } else {
	set impArgs $cachedOpts
    }
    array set impArr $impArgs
    
    # -above & -below??? Be sure to overwrite any cached options.
    #array set impArr [::CanvasUtils::GetStackingOption $w $id]
    array set impArr [list -tags [::CanvasUtils::GetUtag $w $id 1]]
    return "import [$w coords $id] [array get impArr]"
}

proc ::CanvasUtils::GetOnelinerForQTMovie {w id args} {
    
    array set argsArr {
	-uritype file
    }
    array set argsArr $args
    set windowName [$w itemcget $id -window]
    set windowClass [winfo class $windowName]
    set movieName ${windowName}.m
    set movFile [$movieName cget -file]
    set movUrl [$movieName cget -url]
    set impArgs {}
    lappend impArgs -width [winfo width $windowName] \
      -height [winfo height $windowName]
    
    switch -- $argsArr(-uritype) {
	file {
	    if {$movFile != ""} {
		if {[info exists argsArr(-basepath)]} {
		    set movFile [filerelative $argsArr(-basepath) $movFile]	    
		} 
		lappend impArgs -file $movFile
	    } elseif {$movUrl != ""} {
		
		# In this case we don't have access to QT's internal cache.
		lappend impArgs -url $movUrl
	    }
	}
	http {
	    if {$movFile != ""} {
		lappend impArgs -url [::CanvasUtils::GetHttpFromFile $movFile]
	    } elseif {$movUrl != ""} {
		lappend impArgs -url $movUrl
	    }	    
	}
	default {
	    return -code error "Unknown -uritype \"$argsArr(-uritype)\""
	}
    }
    lappend impArgs -tags [::CanvasUtils::GetUtag $w $id 1]
    return "import [$w coords $id] $impArgs"		    
}

proc ::CanvasUtils::GetOnelinerForSnack {w id args} {
    
    array set argsArr {
	-uritype file
    }
    array set argsArr $args
    set windowName [$w itemcget $id -window]
    set windowClass [winfo class $windowName]
    set movieName ${windowName}.m
    set soundObject [$movieName cget -snacksound]
    set soundFile [$soundObject cget -file]
    set impArgs {}
    lappend impArgs -width [winfo width $windowName] \
      -height [winfo height $windowName]
    
    switch -- $argsArr(-uritype) {
	file {
	    if {[info exists argsArr(-basepath)]} {
		set soundFile [filerelative $argsArr(-basepath) $soundFile]
	    }
	    lappend impArgs -file $soundFile
	}
	http {
	    lappend impArgs -url [::CanvasUtils::GetHttpFromFile $soundFile]
	}
	default {
	    return -code error "Unknown -uritype \"$argsArr(-uritype)\""
	}
    }
    lappend impArgs -tags [::CanvasUtils::GetUtag $w $id 1]
    return "import [$w coords $id] $impArgs"		    
}

# CanvasUtils::GetHttpFromFile --
# 
#       Translates an absolute file path to an uri encoded http address
#       for our built in http server.

proc ::CanvasUtils::GetHttpFromFile {filePath} {
    global  prefs this
    
    set relPath [filerelative $prefs(httpdRootDir) $filePath]
    set relPath [uriencode::quotepath $relPath]
    set ip [::Network::GetThisOutsideIPAddress]
    return "http://${ip}:$prefs(httpdPort)/$relPath"
}

# CanvasUtils::ItemConfigure --
#
#       Makes an canvas itemconfigure that propagates to all clients.
#       Selection, if any, redone.
#       
# Arguments:
#       w      the canvas.
#       id     the item id to configure, could be "current" etc.
#       args   list of '-key value' pairs.
#       
# Results:
#       item configured, here and there.

proc ::CanvasUtils::ItemConfigure {w id args} {
    global  prefs
    
    Debug 2 "::CanvasUtils::ItemConfigure id=$id, args=$args"

    set wtop [::UI::GetToplevelNS $w]
    
    # Be sure to get the real id (number).
    set id [$w find withtag $id]
    set utag [::CanvasUtils::GetUtag $w $id]
    set cmd "itemconfigure $utag $args"
    set undocmd "itemconfigure $utag [::CanvasUtils::GetItemOpts $w $utag $args]"
    
    # Handle font points -> size for the network command.
    set cmdremote [::CanvasUtils::FontHtmlToPointSize $cmd -1]
    set undocmdremote [::CanvasUtils::FontHtmlToPointSize $undocmd -1]
    
    set redo [list ::CanvasUtils::CommandExList $wtop  \
      [list [list $cmd "local"] [list $cmdremote "remote"]]]
    set undo [list ::CanvasUtils::CommandExList $wtop  \
      [list [list $undocmd "local"] [list $undocmdremote "remote"]]]
    eval $redo
    undo::add [::UI::GetUndoToken $wtop] $undo $redo
    
    # If selected, redo the selection to fit.
    set idsMarker [$w find withtag id$id]
    if {[string length $idsMarker] > 0} {
	$w delete id$id
	::CanvasDraw::MarkBbox $w 1 $id
    }
}

# CanvasUtils::ItemCoords --
#
#       Makes an canvas coords that propagates to all clients.
#       Selection, if any, redone.
#       
# Arguments:
#       w      the canvas.
#       id     the item id to configure, could be "current" etc.
#       coords
#       
# Results:
#       item coords set, here and there.

proc ::CanvasUtils::ItemCoords {w id coords} {
    global  prefs
    
    Debug 2 "::CanvasUtils::ItemCoords id=$id"

    set wtop [::UI::GetToplevelNS $w]
    
    # Be sure to get the real id (number).
    set id [$w find withtag $id]
    set utag [::CanvasUtils::GetUtag $w $id]
    set cmd "coords $utag $coords"
    set undocmd "coords $utag [$w coords $id]"
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]
    eval $redo
    undo::add [::UI::GetUndoToken $wtop] $undo $redo
    
    # If selected, redo the selection to fit.
    set idsMarker [$w find withtag id$id]
    if {[string length $idsMarker] > 0} {
	$w delete id$id
	::CanvasDraw::MarkBbox $w 1 $id
    }
}

# CanvasUtils::StartTimerToItemPopup --
#
#       Sets a timer (after) for the item popup menu.
#       
# Arguments:
#       w           the canvas.
#       x           mouse in global coords.
#       y           mouse in global coords.
#       
# Results:
#       none

proc ::CanvasUtils::StartTimerToItemPopup {w x y} {

    variable itemAfterId
    
    if {[info exists itemAfterId]} {
	catch {after cancel $itemAfterId}
    }
    set itemAfterId [after 1000 [list ::CanvasUtils::DoItemPopup $w $x $y]]
}

proc ::CanvasUtils::StopTimerToItemPopup { } {
    variable itemAfterId
    
    if {[info exists itemAfterId]} {
	catch {after cancel $itemAfterId}
    }
}

# Same as above but hardcoded to windows.

proc ::CanvasUtils::StartTimerToWindowPopup {w x y} {

    variable winAfterId
    
    if {[info exists winAfterId]} {
	catch {after cancel $winAfterId}
    }
    set winAfterId [after 1000 [list ::CanvasUtils::DoWindowPopup $w $x $y]]
}

proc ::CanvasUtils::StopTimerToWindowPopup { } {
    variable winAfterId
    
    if {[info exists winAfterId]} {
	catch {after cancel $winAfterId}
    }
}

# CanvasUtils::DoItemPopup --
#
#       Posts the item popup menu depending on item type.
#       
# Arguments:
#       w           the canvas.
#       x           mouse in global coords.
#       y           mouse in global coords.
#       
# Results:
#       none

proc ::CanvasUtils::DoItemPopup {w x y} {
    global  prefs fontPoints2Size
    variable itemAfterId
    variable popupVars
    
    Debug 2 "::CanvasUtils::DoItemPopup: w=$w"

    set wtop [::UI::GetToplevelNS $w]
    
    # Cancel the gray box drag rectangle. x and y must be canvas local coords.
    set xloc [expr $x - [winfo rootx $w]]
    set yloc [expr $y - [winfo rooty $w]]
    
    # Clear and cancel the triggering of any selections.
    ::CanvasDraw::CancelBox $w
    set id [$w find withtag current]
    if {$id == ""} {
	return
    }
    
    # Get 'type', broken is a special form of image.
    set type [$w type $id]
    set tags [$w gettags $id]
    if {[lsearch $tags broken] >= 0} {
	set type broken
    }
    Debug 2 "   type=$type"
        
    # In order to get the present value of id it turned out to be 
    # easiest to make a fresh menu each time.
        
    # Build popup menu.
    set m .popup${type}
    catch {destroy $m}
    if {![winfo exists $m]} {	
	::UI::NewMenu $wtop $m {} "pop,$type" normal -id $id -w $w
	if {[string equal $type "text"]} {
	    ::UI::BuildCanvasPopupFontMenu $w ${m}.mfont $id $prefs(canvasFonts)
	}
	
	# This one is needed on the mac so the menu is built before
	# it is posted.
	update idletasks
    }
    
    # Set actual values for this particular item.
    if {[regexp {arc|line|oval|rectangle|polygon} $type]} {
	set ::UI::popupVars(-width) [expr int([$w itemcget $id -width])]
	set dashShort [$w itemcget $id -dash]
	if {$dashShort == ""} {
	    set dashShort " "
	}
	set ::UI::popupVars(-dash) $dashShort
	if {!$prefs(haveDash)} {
	    $m entryconfigure "*Dash*" -state disabled
	}
    }
    if {[regexp {line|polygon} $type]} {
	set smooth [$w itemcget $id -smooth]
	if {[string equal $smooth "bezier"]} {
	    set smooth 1
	}
	set ::UI::popupVars(-smooth) $smooth
    }
    if {[regexp {text} $type]} {
	set fontOpt [$w itemcget $id -font]
	if {[llength $fontOpt] >= 3} {
	    set ::UI::popupVars(-fontfamily) [lindex $fontOpt 0]
	    set pointSize [lindex $fontOpt 1]
	    if {[info exists fontPoints2Size($pointSize)]} {
		set ::UI::popupVars(-fontsize) $fontPoints2Size($pointSize)
	    }
	    set ::UI::popupVars(-fontweight) [lindex $fontOpt 2]
	}
    }
    
    # Post popup menu.
    tk_popup $m [expr int($x) - 10] [expr int($y) - 10]
}

proc ::CanvasUtils::DoWindowPopup {w x y} {
    
    switch -- [winfo class $w] {
	QTFrame {
	    ::CanvasUtils::PostGeneralMenu $w $x $y .popupqt \
	      $::UI::menuDefs(pop,qt)
	}
	SnackFrame {
	    ::CanvasUtils::PostGeneralMenu $w $x $y .popupsnack \
	      $::UI::menuDefs(pop,snack)
	}
	default {
	    
	    # Add a hook here for plugin support.
	    
	}
    }
}

proc ::CanvasUtils::PostGeneralMenu {w x y m mDef} {
            
    set wtop [::UI::GetToplevelNS $w]    

    set xloc [expr $x - [winfo rootx $w]]
    set yloc [expr $y - [winfo rooty $w]]
        
    # Build popup menu.
    catch {destroy $m}
    if {![winfo exists $m]} {
	::UI::MakeMenu $wtop $m {} $mDef normal -winfr $w
	
	# This one is needed on the mac so the menu is built before
	# it is posted.
	update idletasks
    }
    
    # Post popup menu.
    tk_popup $m [expr int($x) - 10] [expr int($y) - 10]
}
    
# SetItemColorDialog, SetTextItemFontFamily, SetTextItemFontSize, 
#    SetTextItemFontWeight --
#
#       Some handy utilities for the popup menu callbacks.

proc ::CanvasUtils::ItemSmooth {w id} {
    
    set smooth [$w itemcget $id -smooth]
    if {[string equal $smooth "bezier"]} {
	set smooth 1
    }
    
    # Just toggle smooth state.
    ::CanvasUtils::ItemConfigure $w $id -smooth [expr 1 - $smooth]
}

proc ::CanvasUtils::ItemStraighten {w id} {
    global  prefs
    
    set frac $prefs(straightenFrac)
    set coords [$w coords $id]
    set len [expr [llength $coords]/2]
    set type [$w type $id]
    switch -- $type {
	line {
	    if {$len <= 2} {
		return
	    }
	}
	polygon {
	    if {$len <= 3} {
		return
	    }
	}
    }
    set dsorted [lsort -real [::CanvasDraw::GetDistList $coords]]
    set dlimit [lindex $dsorted [expr int($len * $frac + 1)]]
    set coords [::CanvasDraw::StripClosePoints $coords $dlimit]
    ::CanvasUtils::ItemCoords $w $id $coords
}

proc ::CanvasUtils::SetItemColorDialog {w id opt} {
    
    set presentColor [$w itemcget $id $opt]
    if {$presentColor == ""} {
	set presentColor black
    }
    set color [tk_chooseColor -initialcolor $presentColor  \
      -title [::msgcat::mc {New Color}]]
    if {$color != ""} {
	::CanvasUtils::ItemConfigure $w $id $opt $color
    }
}

proc ::CanvasUtils::SetTextItemFontFamily {w id fontfamily} {
    
    # First, get existing font value.
    set fontOpts [$w itemcget $id -font]
    
    # Then configure with new one.
    set fontOpts [list {-font} [lreplace $fontOpts 0 0 $fontfamily]]
    eval {CanvasUtils::ItemConfigure $w $id} $fontOpts    
}
    
proc ::CanvasUtils::SetTextItemFontSize {w id fontsize} {
    
    # First, get existing font value.
    set fontOpts [$w itemcget $id -font]
    
    # Then configure with new one.
    set fontOpts [lreplace $fontOpts 1 1 $fontsize]
    set fontOpts [::CanvasUtils::FontHtmlToPointSize [list {-font} $fontOpts]]
    eval {CanvasUtils::ItemConfigure $w $id} $fontOpts
}

proc ::CanvasUtils::SetTextItemFontWeight {w id fontweight} {
    
    # First, get existing font value.
    set fontOpts [$w itemcget $id -font]
    
    # Then configure with new one.
    set fontOpts [list {-font} [lreplace $fontOpts 2 2 $fontweight]]
    eval {CanvasUtils::ItemConfigure $w $id} $fontOpts    
}

# CanvasUtils::NewImportAnchor --
#
#       Creates new coordinates that takes care of the finite size of
#       the canvas. Uses cyclic boundary conditions.
#            
# Arguments:
#       
# Results:
#       list of x and y.

proc ::CanvasUtils::NewImportAnchor { } {
    global  prefs
    
    variable importAnchor
    upvar ::UI::dims dims
    
    set x $importAnchor(x)
    set y $importAnchor(y)
    
    # Update 'importAnchor'.
    incr importAnchor(x) $prefs(offsetCopy)
    incr importAnchor(y) $prefs(offsetCopy)
    if {($importAnchor(x) > [expr $dims(wCanvas) - 60]) ||   \
      ($importAnchor(y) > [expr $dims(hCanvas) - 60])} {
	set importAnchor(x) $prefs(offsetCopy)
	set importAnchor(y) $prefs(offsetCopy)
    }
    return [list $x $y]
}

# CanvasUtils::GetItemOpts --
#
#       As canvas itemconfigure but only the actual options.
#       
# Arguments:
#       w         the canvas widget path.
#       id        item tag or id.
#       which   nondef:  return only values that are not identical to defaults.
#               all:     return all options.
#               -key value ... list: pick only options in this list.
#       
# Results:
#       list of options and values as '-option value' ....

proc ::CanvasUtils::GetItemOpts {w id {which "nondef"}} {
    
    set opcmd {}
    if {[llength $which] > 1} {
	foreach {op val} $which {
	    lappend opcmd $op [$w itemcget $id $op]
	}
    } else {
	set all [string equal $which "all"]
	set opts [$w itemconfigure $id]
	foreach oplist $opts {
	    foreach {op x y defval val} $oplist {
		if {[string equal $op "-tags"]} {
		    regsub current $val "" val
		    regsub selected $val "" val
		}
		if {[string equal $op "-smooth"]} {
		    regsub bezier $val 1 val
		}
		if {$all || ![string equal $defval $val]} {
		    lappend opcmd $op $val
		}
	    }
	}
    }
    return $opcmd
}

# CanvasUtils::FindAboveUtag, FindBelowUtag --
# 
#       As 'canvasPath find above/below tagOrId' but that only returns
#       ordinary items, for which there is a utag, and not markers etc.
#       Returns a utag if found, else empty.

proc ::CanvasUtils::FindAboveUtag {w id} {

    set aboveutag ""
    set aboveid [$w find above $id]
    while {[set aboveutag [GetUtag $w $aboveid 1]] == ""} {
	if {[set aboveid [$w find above $id]] == ""} {
	    break
	}
	set id $aboveid
    }
    return $aboveutag
}

proc ::CanvasUtils::FindBelowUtag {w id} {

    set belowutag ""
    set belowid [$w find below $id]
    while {[set belowutag [GetUtag $w $belowid 1]] == ""} {
	if {[set belowid [$w find below $id]] == ""} {
	    break
	}
	set id $belowid
    }
    return $belowutag
}

# CanvasUtils::GetStackingOption --
#
#       Returns a list '-below utag', '-above utag' or empty.

proc ::CanvasUtils::GetStackingOption {w id} {
    
    # below before above since stacking order when saving to file.
    set opt {}
    set belowutag [FindBelowUtag $w $id]
    if {[string length $belowutag]} {
	lappend opt -above $belowutag
    }
    set aboveutag [FindAboveUtag $w $id]
    if {[string length $aboveutag]} {
	lappend opt -below $aboveutag
    }
    return $opt
}

# CanvasUtils::GetStackingCmd --
#
#       Returns a canvas command (without pathName) that restores the
#       stacking order of $utag.

proc ::CanvasUtils::GetStackingCmd {w utag} {
    
    set aboveid [$w find above $utag]
    if {[string length $aboveid]} {
	set cmd [list lower $utag [GetUtag $w $aboveid 1]]
    } else {
	set belowid [$w find below $utag]
	if {[string length $belowid]} {
	    set cmd [list raise $utag [GetUtag $w $belowid 1]]
	} else {
	    
	    # If a single item on canvas, do dummy.
	    set cmd [list raise $utag]
	}
    }
    return $cmd
}

# CanvasUtils::UniqueImageName --
#
#       Uses the ip number to create a unique image name.

proc ::CanvasUtils::UniqueImageName { } {
    global  this
    variable utaguid
    
    set str ""
    foreach i [split $this(ipnum) .] {
	append str [format "%02x" $i]
    }
    append str [format "%x" $utaguid]
    incr utaguid
    return "im${str}"
}

# CanvasUtils::FindTypeFromOverlapping --
#   
#       Finds the specific item at given coords and with tag 'type'.
#   
# Arguments:
#       c         the canvas widget path.
#       x, y      coords
#       type
#       
# Results:
#       item id or empty if none.

proc ::CanvasUtils::FindTypeFromOverlapping {c x y type} {    
    
    set ids [$c find overlapping [expr $x-2] [expr $y-2]  \
      [expr $x+2] [expr $y+2]]
    set id {}
    
    # Choose the first item with tags $type.
    foreach i $ids {
	if {[lsearch [$c gettags $i] $type] >= 0} {
	    
	    # Found "$type".
	    set id $i
	    break
	}
    }
    return $id
}

# CanvasUtils::FontHtmlToPointSize --
#
#       Change the -font option in a canvas command from html size type
#       to point size, or vice versa if 'inverse'.
#
# Arguments:
#       canCmd     a canvas command which need not have the widget prepended.
#       inverse    (optional, defaults to 0) if 1, PointSizeToHtml size instead.
# 
# Results:
#       the modified canvas command.

proc ::CanvasUtils::FontHtmlToPointSize {canCmd {inverse 0}} {
    global  fontSize2Points fontPoints2Size
    
    set ind [lsearch -exact $canCmd {-font}]
    if {$ind < 0} {
	return $canCmd
    }
    set valInd [expr $ind + 1]
    set fontSpec [lindex $canCmd $valInd]
    set fontSize [lindex $fontSpec 1]
    
    if {!$inverse} {
	
	# This is the default  html->points.
	# Check that it is between 1 and 6.
	if {$fontSize >= 1 && $fontSize <= 6} {
	    set newFontSpec   \
	      [lreplace $fontSpec 1 1 $fontSize2Points($fontSize)]
	    
	    # Replace font specification in drawing command.
	    set canCmd [lreplace $canCmd $valInd $valInd $newFontSpec]
	}
    } else {
	
	# This is points->html.
	set newFontSpec   \
	  [lreplace $fontSpec 1 1 $fontPoints2Size($fontSize)]
	
	# Replace font specification in drawing command.
	set canCmd [lreplace $canCmd $valInd $valInd $newFontSpec]
    }
    return $canCmd
}

# CanvasUtils::CreateFontSizeMapping --
#
#       Creates the mapping between Html sizes (1 2 3 4 5 6) and font point
#       sizes on this specific platform dynamically by measuring the length in
#       pixels of a fixed reference string.
#
# Results:
#       is put in the global variables 'fontSize2Points' and 'fontPoints2Size'.

proc ::CanvasUtils::CreateFontSizeMapping { } {
    global  fontSize2Points fontPoints2Size this
    
    # The reference is chosen to get point sizes on Mac as: 10, 12, 14, 18, 
    # 24, 36. Found via 'font measure {Times 10} {Mats Bengtsson}'.
    
    array set refHtmlSizeToLength {1 64 2 76 3 88 4 116 5 154 6 231}
    set refStr {Mats Bengtsson}
    
    # Pick to point sizes and reconstruct a linear relation from the font size
    # in points and the reference string length in pixels: y = kx + m.
    
    set p0 10
    set p1 36
    set y0 [font measure "Times $p0" $refStr]
    set y1 [font measure "Times $p1" $refStr]
    set k [expr ($y1 - $y0)/double($p1 - $p0)]
    set m [expr $y1 - $k*$p1]
    
    # For what x (font size in points) do we get 'refHtmlSizeToLength(1)', etc.
    # x = (y - m)/k
    # Mac and Windows are hardcoded for optimal view.
    
    switch -- $this(platform) {
	"macintosh" - "macosx" {
	    array set fontSize2Points {1 10 2 12 3 14 4 18 5 24 6 36}
	}
	"windows" {
	    array set fontSize2Points {1 7 2 9 3 11 4 14 5 18 6 28}
	}
	default {
	    foreach htmlSize {1 2 3 4 5 6} {
		set fontSize2Points($htmlSize)  \
		  [expr int( ($refHtmlSizeToLength($htmlSize) - $m)/$k + 0.9)]
	    }
	}
    }
    
    # We also need the inverse mapping.
    
    foreach pt [array names fontSize2Points] {
	set fontPoints2Size($fontSize2Points($pt)) $pt
    }
}

# CanvasUtils::HandleCanvasDraw --
# 
#       Handle a CANVAS drawing command from the server.
#       
# Arguments:
#       wtop        toplevel window. ("." or ".main2." with extra dot!)
#       instr       everything after CANVAS:
#
# Returns:
#       none.

proc ::CanvasUtils::HandleCanvasDraw {wtop instr} {
    global  prefs canvasSafeInterp
    
    # Special chars.
    set bs_ {\\}
    set lb_ {\{}
    set rb_ {\}}
    set punct_ {[.,;?!]}

    # Regular drawing commands in the canvas.
    set wServCan [::UI::GetServerCanvasFromWtop $wtop]
    
    # If html sizes in text items, be sure to translate them into
    # platform specific point sizes.
    
    if {$prefs(useHtmlSizes) && ([lsearch -exact $instr "-font"] >= 0)} {
	set instr [::CanvasUtils::FontHtmlToPointSize $instr]
    }
    
    # Careful, make newline (backslash) substitutions only for the command
    # being eval'd, else the tcl interpretation may be screwed up.
    # Fix special chars such as braces since they are parsed 
    # when doing 'subst' below. Pad extra backslash for each '\{' and
    # '\}' to protect them.
    # Seems like an identity operation but is not!
    
    regsub -all "$bs_$lb_" $instr "$bs_$lb_" padinstr
    regsub -all "$bs_$rb_" $padinstr "$bs_$rb_" padinstr
    set bsinstr [subst -nocommands -novariables $padinstr]
    
    # Intercept the canvas command if delete to remove any markers
    # *before* it is deleted! See below for other commands.
    
    set cmd [lindex $instr 0]
    if {[string equal $cmd "delete"]} {
	set utag [lindex $instr 1]
	set id [$wServCan find withtag $utag]
	$wServCan delete id$id
    }
    
    # Find and register the undo command (and redo), and push
    # on our undo/redo stack. Security ???
    if {$prefs(privacy) == 0} {
	set redo [list ::CanvasUtils::Command $wtop $instr]
	set undo [::CanvasUtils::GetUndoCommand $wtop $instr]
	undo::add [::UI::GetUndoToken $wtop] $undo $redo
    }
    
    # The 'import' command is an exception case (for the future). 
    if {[string equal $cmd "import"]} {
	::Import::HandleImportCmd $wServCan $bsinstr
    } else {
	
	# Make the actual canvas command, either straight or in the 
	# safe interpreter.
	if {$prefs(makeSafeServ)} {
	    if {[catch {$canvasSafeInterp eval SafeCanvasDraw  \
	      $wServCan $bsinstr} idnew]} {
		puts stderr "--->error: did not understand: $idnew"
		return
	    }
	} else {
	    if {[catch {eval $wServCan $bsinstr} idnew]} {
		puts stderr "--->error: did not understand: $idnew"
		return
	    }
	}
    }
    
    # Intercept the canvas command in certain cases:
    # If moving a selected item, be sure to move the markers with it.
    # The item can either be selected by remote client or here.
    
    if {[string equal $cmd "move"] ||  \
      [string equal $cmd "coords"] || \
      [string equal $cmd "scale"] ||  \
      [string equal $cmd "itemconfigure"]} {
	set utag [lindex $instr 1]
	set id [$wServCan find withtag $utag]
	set idsMarker [$wServCan find withtag id$id]
	
	# If we have selected the item in question.
	if {[string length $idsMarker] > 0} {
	    $wServCan delete id$id
	    $wServCan dtag $id "selected"
	    ::CanvasDraw::MarkBbox $wServCan 1 $id
	}
    } 
    
    # If text then speak up to last punct.
    
    if {$prefs(SpeechOn)} {
	if {[string equal $cmd "create"] ||  \
	  [string equal $cmd "insert"]} {
	    if {[string equal $cmd "create"]} {
		set utag $idnew
	    } else {
		set utag [lindex $instr 1]
	    }
	    set type [$wServCan type $utag]
	    if {[string equal $type "text"]} {
		
		# Extract the actual text. TclSpeech not foolproof!
		set theText [$wServCan itemcget $utag -text]
		if {[string match *${punct_}* $theText]} {
		    catch {::UserActions::Speak $theText $prefs(voiceOther)}
		}
	    }
	}
    }
}

# CanvasUtils::ItemSet, ItemCGet, ItemFree --
#
#       Handling cached info for items not set elsewhere.
#       Automatically garbage collected.

proc ::CanvasUtils::ItemSet {wtop id args} {
    upvar ::${wtop}::itemopts itemopts

    set itemopts($id) $args
}

proc ::CanvasUtils::ItemCGet {wtop id} {
    upvar ::${wtop}::itemopts itemopts
    
    if {[info exists itemopts($id)]} {
	return $itemopts($id)
    } else {
	return ""
    }
}

proc ::CanvasUtils::ItemFree {wtop} {
    upvar ::${wtop}::itemopts itemopts
    
    catch {unset itemopts}
}

# CanvasUtils::DefineWhiteboardBindtags --
# 
#       Defines a number of binding tags for the whiteboard canvas.
#       This is helpful when switching bindings depending on which tool is 
#       selected. It defines only widget bindtags, not item binding.

proc ::CanvasUtils::DefineWhiteboardBindtags { } {
    global  this
    
    # WhiteboardPoint
    bind WhiteboardPoint <Button-1> {
	::CanvasDraw::MarkBbox %W 0
	::CanvasDraw::InitBox %W [%W canvasx %x] [%W canvasy %y] rect
    }
    bind WhiteboardPoint <Shift-Button-1> {
	::CanvasDraw::MarkBbox %W 1
	::CanvasDraw::InitBox %W [%W canvasx %x] [%W canvasy %y] rect
    }
    bind WhiteboardPoint <B1-Motion> {
	::CanvasDraw::BoxDrag %W [%W canvasx %x] [%W canvasy %y] 0 rect 1
	::CanvasUtils::StopTimerToItemPopup
    }
    bind WhiteboardPoint <ButtonRelease-1> {
	::CanvasDraw::FinalizeBox %W [%W canvasx %x] [%W canvasy %y] 0 rect 1
    }
    
    # WhiteboardMove
    # Bindings for moving items; movies need special class.
    # The frame with the movie the mouse events, not the canvas.
    # With shift constrained move.
    bind WhiteboardMove <Button-1> {
	::CanvasDraw::InitMove %W [%W canvasx %x] [%W canvasy %y]
    }
    bind WhiteboardMove <B1-Motion> {
	::CanvasDraw::DoMove %W [%W canvasx %x] [%W canvasy %y] item
    }
    bind WhiteboardMove <ButtonRelease-1> {
	::CanvasDraw::FinalizeMove %W [%W canvasx %x] [%W canvasy %y]
    }
    bind WhiteboardMove <Shift-B1-Motion> {
	::CanvasDraw::DoMove %W [%W canvasx %x] [%W canvasy %y] item 1
    }    
    
    # WhiteboardLine
    bind WhiteboardLine <Button-1> {
	::CanvasDraw::InitLine %W [%W canvasx %x] [%W canvasy %y]
    }
    bind WhiteboardLine <B1-Motion> {
	::CanvasDraw::LineDrag %W [%W canvasx %x] [%W canvasy %y] 0
    }
    bind WhiteboardLine <Shift-B1-Motion> {
	::CanvasDraw::LineDrag %W [%W canvasx %x] [%W canvasy %y] 1
    }
    bind WhiteboardLine <ButtonRelease-1> {
	::CanvasDraw::FinalizeLine %W [%W canvasx %x] [%W canvasy %y] 0
    }
    bind WhiteboardLine <Shift-ButtonRelease-1> {
	::CanvasDraw::FinalizeLine %W [%W canvasx %x] [%W canvasy %y] 1
    }

    # WhiteboardArrow
    bind WhiteboardArrow <Button-1> {
	::CanvasDraw::InitLine %W [%W canvasx %x] [%W canvasy %y] arrow
    }
    bind WhiteboardArrow <B1-Motion> {
	::CanvasDraw::LineDrag %W [%W canvasx %x] [%W canvasy %y] 0 arrow
    }
    bind WhiteboardArrow <Shift-B1-Motion> {
	::CanvasDraw::LineDrag %W [%W canvasx %x] [%W canvasy %y] 1 arrow
    }
    bind WhiteboardArrow <ButtonRelease-1> {
	::CanvasDraw::FinalizeLine %W [%W canvasx %x] [%W canvasy %y] 0 arrow
    }
    bind WhiteboardArrow <Shift-ButtonRelease-1> {
	::CanvasDraw::FinalizeLine %W [%W canvasx %x] [%W canvasy %y] 1 arrow
    }
    
    # WhiteboardRect
    bind WhiteboardRect <Button-1> {
	::CanvasDraw::InitBox %W [%W canvasx %x] [%W canvasy %y] rect
    }
    bind WhiteboardRect <B1-Motion> {
	::CanvasDraw::BoxDrag %W [%W canvasx %x] [%W canvasy %y] 0 rect
    }
    bind WhiteboardRect <Shift-B1-Motion> {
	::CanvasDraw::BoxDrag %W [%W canvasx %x] [%W canvasy %y] 1 rect
    }
    bind WhiteboardRect <ButtonRelease-1> {
	::CanvasDraw::FinalizeBox %W [%W canvasx %x] [%W canvasy %y] 0 rect
    }
    bind WhiteboardRect <Shift-ButtonRelease-1> {
	::CanvasDraw::FinalizeBox %W [%W canvasx %x] [%W canvasy %y] 1 rect
    }
    
    # WhiteboardOval
    bind WhiteboardOval <Button-1> {
	::CanvasDraw::InitBox %W [%W canvasx %x] [%W canvasy %y] oval
    }
    bind WhiteboardOval <B1-Motion> {
	::CanvasDraw::BoxDrag %W [%W canvasx %x] [%W canvasy %y] 0 oval
    }
    bind WhiteboardOval <Shift-B1-Motion> {
	::CanvasDraw::BoxDrag %W [%W canvasx %x] [%W canvasy %y] 1 oval
    }
    bind WhiteboardOval <ButtonRelease-1> {
	::CanvasDraw::FinalizeBox %W [%W canvasx %x] [%W canvasy %y] 0 oval
    }
    bind WhiteboardOval <Shift-ButtonRelease-1> {
	::CanvasDraw::FinalizeBox %W [%W canvasx %x] [%W canvasy %y] 1 oval
    }

    # WhiteboardText
    bind WhiteboardText <Button-1> {
	::CanvasText::CanvasFocus %W [%W canvasx %x] [%W canvasy %y]
    }
    bind WhiteboardText <Button-2> {
	::CanvasCCP::CanvasTextPaste %W [%W canvasx %x] [%W canvasy %y]
    }
    # Stop certain keyboard accelerators from firing:
    bind WhiteboardText <Control-a> break

    # WhiteboardDel
    bind WhiteboardDel <Button-1> {
	::CanvasDraw::DeleteItem %W [%W canvasx %x] [%W canvasy %y]
    }
    
    # WhiteboardPen
    bind WhiteboardPen <Button-1> {
	::CanvasDraw::InitStroke %W [%W canvasx %x] [%W canvasy %y]
    }
    bind WhiteboardPen <B1-Motion> {
	::CanvasDraw::StrokeDrag %W [%W canvasx %x] [%W canvasy %y]
    }
    bind WhiteboardPen <ButtonRelease-1> {
	::CanvasDraw::FinalizeStroke %W [%W canvasx %x] [%W canvasy %y]
    }

    # WhiteboardBrush
    bind WhiteboardBrush <Button-1> {
	::CanvasDraw::InitStroke %W [%W canvasx %x] [%W canvasy %y]
    }
    bind WhiteboardBrush <B1-Motion> {
	::CanvasDraw::StrokeDrag %W [%W canvasx %x] [%W canvasy %y] 1
    }
    bind WhiteboardBrush <ButtonRelease-1> {
	::CanvasDraw::FinalizeStroke %W [%W canvasx %x] [%W canvasy %y] 1
    }

    # WhiteboardPaint
    bind WhiteboardPaint  <Button-1> {
	::CanvasDraw::DoPaint %W [%W canvasx %x] [%W canvasy %y]
    }
    bind WhiteboardPaint  <Shift-Button-1> {
	::CanvasDraw::DoPaint %W [%W canvasx %x] [%W canvasy %y] 1
    }

    # WhiteboardPoly
    bind WhiteboardPoly  <Button-1> {
	::CanvasDraw::PolySetPoint %W [%W canvasx %x] [%W canvasy %y]
    }

    # WhiteboardArc
    bind WhiteboardArc <Button-1> {
	::CanvasDraw::InitArc %W [%W canvasx %x] [%W canvasy %y]
    }
    bind WhiteboardArc <Shift-Button-1> {
	::CanvasDraw::InitArc %W [%W canvasx %x] [%W canvasy %y] 1
    }

    # WhiteboardRot
    bind WhiteboardRot <Button-1> {
	::CanvasDraw::InitRotateItem %W [%W canvasx %x] [%W canvasy %y]
    }
    bind WhiteboardRot <B1-Motion> {
	::CanvasDraw::DoRotateItem %W [%W canvasx %x] [%W canvasy %y] 0
    }
    bind WhiteboardRot <Shift-B1-Motion> {
	::CanvasDraw::DoRotateItem %W [%W canvasx %x] [%W canvasy %y] 1
    }
    bind WhiteboardRot <ButtonRelease-1> {
	::CanvasDraw::FinalizeRotate %W [%W canvasx %x] [%W canvasy %y]
    }
    
    # Generic nontext bindings.
    bind WhiteboardNonText <BackSpace> {
	::CanvasDraw::DeleteItem %W %x %y selected
    }
    bind WhiteboardNonText <Control-d> {
	::CanvasDraw::DeleteItem %W %x %y selected
    }
}

#-------------------------------------------------------------------------------
