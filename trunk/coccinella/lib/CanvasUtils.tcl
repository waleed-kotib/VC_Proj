#  CanvasUtils.tcl ---
#  
#      This file is part of the whiteboard application. It implements some
#      miscellaneous utilities for canvas operations.
#      
#  Copyright (c) 2000-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: CanvasUtils.tcl,v 1.3 2003-01-30 17:33:54 matben Exp $

package provide CanvasUtils 1.0
package require sha1pure

namespace eval ::CanvasUtils:: {
    
    variable itemAfterId
    variable popupVars
}

proc ::CanvasUtils::Init { } {
    global  this internalIPname prefs env
    variable utaguid
    variable utagPref
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
    set utagPref $this(hostname)
    if {$utagPref == ""} {
	set utagPref $internalIPname
    }
    
    # On multiuser platforms (unix) prepend the user name; no spaces allowed.
    if {[string equal $this(platform) "unix"] && [info exists env(USER)]} {
	set user $this(username)
	regsub -all " " $user "" user
	set utagPref ${user}@${utagPref}
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
    
    upvar ::${wtop}::wapp wapp
    
    set w $wapp(can)
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
    
    upvar ::${wtop}::wapp wapp
    
    set w $wapp(can)
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
    variable utagPref
    
    if {$doincr} {
	incr utaguid
    }
    return ${utagPref}/${utaguid}
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
    variable utagPref
    
    # Find the 'itno'.
    set pre_ {[^/ ]+}
    set digit_ {[0-9]}
    set wild_ {[xX]+}
    if {[string equal $fromWhat "current"]} {
	set tcurr [$c gettags current]
    } elseif {[string equal $fromWhat "focus"]} {
	set tcurr [$c gettags [$c focus]]
    } else {
	set tcurr [$c gettags $fromWhat]
    }
    if {$tcurr == ""} {
	return {}
    }
    if {$prefs(privacy) && !$force} {
	if {[regexp "(($wild_|$utagPref)/$digit_+)" "$tcurr" utag] == 0} {
	    return {}
	}
    } else {
	if {[regexp "(^| )($pre_/$digit_+)" "$tcurr" junk junk2 utag] == 0} {
	    return {}
	}
    }
    return $utag
}

# CanvasUtils::GetUtagPrefix --
#
#       Returns the unique tag prefix for this client.

proc ::CanvasUtils::GetUtagPrefix { } {
    variable utagPref
    return $utagPref
}

# CanvasUtils::GetUtagFromCmd --
#
#       Takes a canvas command and returns the utag if any.

proc ::CanvasUtils::GetUtagFromCmd {str} {
    
    set utag ""
    set ind [lsearch -exact $str "-tags"]
    if {$ind >= 0} {
	set ind [expr $ind + 1]
	set tags [lindex $str $ind]
	if {[regexp {[^/ ]+/[0-9]+} $tags match]} {
	    set utag $match
	}
    }    
    return $utag
}

# CanvasUtils::ReplaceUtag --
#
#       Takes a canvas command and replaces the utag with new utag.

proc ::CanvasUtils::ReplaceUtag {str newUtag} {
    
    set ind [lsearch -exact $str "-tags"]
    if {$ind >= 0} {
	set ind [expr $ind + 1]
	set tags [lindex $str $ind]
	if {[regsub {[^/ ]+/[0-9]+} $tags $newUtag tags]} {
	    set str [lreplace $str $ind $ind $tags]
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
#       a canvas command without pathName

proc ::CanvasUtils::GetUndoCommand {wtop cmd} {

    upvar ::${wtop}::wapp wapp
    
    set w $wapp(can)
    set undo {}
    switch -- [lindex $cmd 0] {
	coords {
	    set utag [lindex $cmd 1]
	    set undo [concat [list coords $utag] [$w coords $utag]]
	}
	create {
	    set ind [lsearch -exact $cmd "-tags"]
	    if {$ind > 0} {
		set tags [lindex $cmd [expr $ind + 1]]
		if {[regexp {([^ ]+/[0-9]+)} $tags match utag]} {
		    set undo [list delete $utag]
		}
	    }
	}
	dchars {
	    set utag [lindex $cmd 1]
	    set ind [lindex $cmd 2]
	    set ilast [lindex $cmd end]
	    set thetext [$w itemcget $utag -text]
	    set str [string range $thetext $ind $ilast]
	    set undo [list insert $utag $ind $str]
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
			switch -- [winfo class $win] {
			    QTFrame {
				set undo [::ImageAndMovie::QTImportCmd $w $utag]
			    }
			    SnackFrame {
				set undo [::ImageAndMovie::SnackImportCmd $w $utag]
			    }
			    default {
				
				# Here we may have code to call custom handlers.
				
			    }
			}
		    }
		}
		default {
		    set co [$w coords $utag]
		    set opts [GetItemOpts $w $utag]
		    set undo [concat [list create $type] $co $opts]
		}
	    }
	}
	insert {
	    foreach {dum utag ind str} $cmd { break }
	    set undo [list dchars $utag $ind [expr $ind + [string length $str]]]
	}
	move {
	    foreach {dum utag dx dy} $cmd { break }
	    set undo [list move $utag [expr -$dx] [expr -$dy]]
	}
	lower - raise {
	    set utag [lindex $cmd 1]
	    set undo [GetStackingCmd $w $utag]
	}
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

# CanvasUtils::GetOnelinerForImage --
#
#       Makes a line that is suitable for file storage. Shall be understood
#       by '::ImageAndMovie::HandleImportCmd'.
#
# Arguments:
#       w
#       id
#       args:
#           -basepath absolutePath    translate image -file to a relative path.
#           -uritype ( file | http )

proc ::CanvasUtils::GetOnelinerForImage {w id args} {
    
    set type [$w type $id]
    if {![string equal $type "image"]} {
	return -code error {must have an "image" item type}
    }
    array set argsArr {
	-uritype file
    }
    array set argsArr $args
    set imageName [$w itemcget $id -image]
    set impArgs {}
    
    # Find out if zoomed.		
    if {[regexp {(.+)_zoom(|-)([0-9]+)} $imageName match origImName  \
      sign factor]} {
	
	# Find out the '-file' option from the original image.
	set imageFile [$origImName cget -file]
	lappend impArgs -zoom-factor ${sign}${factor}
    } else {
	set imageFile [$imageName cget -file]		    
    }
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
    
    # -above & -below???
    set impArgs [concat $impArgs [::CanvasUtils::GetStackingOption $w $id]]
    lappend impArgs -tags [::CanvasUtils::GetUtag $w $id 1]
    return "import [$w coords $id] $impArgs"
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
    if {$movFile != ""} {
	if {[info exists argsArr(-basepath)]} {
	    set movFile [filerelative $argsArr(-basepath) $movFile]	    
	} 
	lappend impArgs -file $movFile
    } elseif {$movUrl != ""} {
	lappend impArgs -url $movUrl
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
    if {[info exists argsArr(-basepath)]} {
	set soundFile [filerelative $argsArr(-basepath) $soundFile]
    }
    set impArgs [list -file $soundFile]
    lappend impArgs -tags [::CanvasUtils::GetUtag $w $id 1]
    return "import [$w coords $id] $impArgs"		    
}

# CanvasUtils::GetHttpFromFile --
# 
#       Translates an absolute file path to an uri encoded http address
#       for our built in http server.

proc ::CanvasUtils::GetHttpFromFile {filePath} {
    global  prefs this
    
    set relPath [filerelative $prefs(httpdBaseDir) $filePath]
    set relPath [uriencode::quotepath $relPath]
    return "http://$this(ipnum):$prefs(httpdPort)/$relPath"
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
    set type [$w type $id]
    set ns [namespace current]
    Debug 2 "   type=$type"
        
    # In order to get the present value of id it turned out to be 
    # easiest to make a fresh menu each time.
        
    # Build popup menu.
    set m .popup${type}
    catch {destroy $m}
    if {![winfo exists $m]} {	
	::UI::MakeMenu $wtop $m {} $::UI::menuDefs(pop,$type) -id $id -w $w
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
    }
    if {[regexp {line|polygon} $type]} {
	set smooth [$w itemcget $id -smooth]
	if {[string equal $smooth "bezier"]} {
	    set smooth 1
	}
	set splinesteps [$w itemcget $id -splinesteps]
	if {$smooth} {
	    set ::UI::popupVars(-smooth) $splinesteps
	} else {
	    set ::UI::popupVars(-smooth) 0
	}
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
	::UI::MakeMenu $wtop $m {} $mDef -winfr $w
	
	# This one is needed on the mac so the menu is built before
	# it is posted.
	update idletasks
    }
    
    # Post popup menu.
    tk_popup $m [expr int($x) - 10] [expr int($y) - 10]
}
    
# SaveImageAsFile, ExportImageAsFile, SetItemColorDialog, SetTextItemFontFamily,
# SetTextItemFontSize, SetTextItemFontWeight
#
#       Some handy utilities for the popup menu callbacks.

proc ::CanvasUtils::SaveImageAsFile {w id} {

    set imageName [$w itemcget $id -image]
    set origFile [$imageName cget -file]
    if {[string length $origFile]} {
	set initFile [file tail $origFile]
    } else {
	set initFile {Untitled.gif}
    }
    set fileName [tk_getSaveFile -defaultextension gif   \
      -title [::msgcat::mc {Save As GIF}] -initialfile $initFile]
    if {$fileName != ""} {
	$imageName write $fileName -format gif
    }
}

proc ::CanvasUtils::ExportImageAsFile {w id} {
    
    set imageName [$w itemcget $id -image]
    catch {$imageName write {Untitled.gif} -format {quicktime -dialog}}
}

proc ::CanvasUtils::ExportMovie {wtop winfr} {
    
    set wmov ${winfr}.m
    $wmov export
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
    
    set opt {}
    set aboveutag [FindAboveUtag $w $id]
    if {[string length $aboveutag]} {
	set opt [list -below $aboveutag]
    } else {
	set belowutag [FindBelowUtag $w $id]
	if {[string length $belowutag]} {
	    set opt [list -above $belowutag]
	}
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

#-------------------------------------------------------------------------------
