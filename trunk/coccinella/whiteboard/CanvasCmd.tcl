# CanvasCmd.tcl ---
#  
#       Implementations of some whiteboard canvas actions.
#      
#  Copyright (c) 2000-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: CanvasCmd.tcl,v 1.1 2004-06-06 06:41:31 matben Exp $

package provide CanvasCmd 1.0


namespace eval ::CanvasCmd:: {
    
}

# CanvasCmd::SelectAll --
#
#       Selects all items in the canvas.
#   
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       
# Results:
#       none

proc ::CanvasCmd::SelectAll {wtop} {
    
    set wCan [::WB::GetCanvasFromWtop $wtop]
    $wCan delete tbbox
    set ids [$wCan find all]
    foreach id $ids {
	$wCan dtag $id selected
	::CanvasDraw::MarkBbox $wCan 1 $id
    }
}

# CanvasCmd::DeselectAll --
#
#       Deselects all items in the canvas.
#   
# Arguments:
#       w      the canvas widget.
#       
# Results:
#       none

proc ::CanvasCmd::DeselectAll {wtop} {
	
    set wCan [::WB::GetCanvasFromWtop $wtop]
    $wCan delete withtag tbbox
    $wCan dtag all selected
    
    # menus
    ::UI::FixMenusWhenSelection $wCan
}

# CanvasCmd::RaiseOrLowerItems --
#
#       Raise or lower the stacking order of the selected canvas item.
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       what   "raise" or "lower"
#       
# Results:
#       none.

proc ::CanvasCmd::RaiseOrLowerItems {wtop {what raise}} {
    
    upvar ::WB::${wtop}::state state
    
    set w [::WB::GetCanvasFromWtop $wtop]    

    set cmdList {}
    set undoList {}
    foreach id [$w find withtag selected] {
	set utag [::CanvasUtils::GetUtag $w $id]
	lappend cmdList [list $what $utag all]
	lappend undoList [::CanvasUtils::GetStackingCmd $w $utag]
    }
    if {$state(canGridOn) && [string equal $what "lower"]} {
	lappend cmdList [list lower grid all]
    }
    set redo [list ::CanvasUtils::CommandList $wtop $cmdList]
    set undo [list ::CanvasUtils::CommandList $wtop $undoList]
    eval $redo
    undo::add [::WB::GetUndoToken $wtop] $undo $redo
}

# CanvasCmd::SetCanvasBgColor --
#
#       Sets background color of canvas.
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       
# Results:
#       color dialog shown.

proc ::CanvasCmd::SetCanvasBgColor {wtop} {
    global  prefs state
	
    set w [::WB::GetCanvasFromWtop $wtop]
    set prevCol $state(bgColCan)
    set col [tk_chooseColor -initialcolor $state(bgColCan)]
    if {[string length $col] > 0} {
	
	# The change should be triggered automatically through the trace.
	set state(bgColCan) $col
	set cmd [list configure -bg $col]
	set undocmd [list configure -bg $prevCol]
	set redo [list ::CanvasUtils::Command $wtop $cmd]
	set undo [list ::CanvasUtils::Command $wtop $undocmd]
	eval $redo
	undo::add [::WB::GetUndoToken $wtop] $undo $redo
    }
}

# CanvasCmd::DoCanvasGrid --
#
#       Make a grid in the canvas; uses state(canGridOn) to toggle grid.
#       
# Arguments:
#       
# Results:
#       grid shown/hidden.

proc ::CanvasCmd::DoCanvasGrid {wtop} {
    global  prefs this
    
    upvar ::WB::${wtop}::state state

    set wCan [::WB::GetCanvasFromWtop $wtop]
    set length 2000
    set gridDist $prefs(gridDist)
    if {$state(canGridOn) == 0} {
	$wCan delete grid
	return
    }
    if {$this(platform) == "windows"} {
	for {set x $gridDist} {$x <= $length} {set x [expr $x + $gridDist]} {
	    $wCan create line $x 0 $x $length  \
	      -width 1 -fill gray50 -tags {notactive grid}
	}
	for {set y $gridDist} {$y <= $length} {set y [expr $y + $gridDist]} {
	    $wCan create line 0 $y $length $y  \
	      -width 1 -fill gray50 -tags {notactive grid}
	}
    } else {
	for {set x $gridDist} {$x <= $length} {set x [expr $x + $gridDist]} {
	    $wCan create line $x 0 $x $length  \
	      -width 1 -fill gray50 -tags {notactive grid} -stipple gray50
	}
	for {set y $gridDist} {$y <= $length} {set y [expr $y + $gridDist]} {
	    $wCan create line 0 $y $length $y  \
	      -width 1 -fill gray50 -tags {notactive grid} -stipple gray50
	}
    }
    $wCan lower grid
}
    
# CanvasCmd::SavePostscript --
#
#       Save canvas to a postscript file.
#       Save canvas to a XML/SVG file.
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       
# Results:
#       file save dialog shown, file written.

proc ::CanvasCmd::SavePostscript {wtop} {
    global  prefs this
    
    set w [::WB::GetCanvasFromWtop $wtop]
    if {![winfo exists $w]} {
	return
    }
    set typelist {
	{"Postscript File"    {.ps}}
	{"XML/SVG"            {.svg}}
    }
    set userDir [::Utils::GetDirIfExist $prefs(userPath)]
    set opts [list -initialdir $userDir]
    if {$prefs(haveSaveFiletypes)} {
	lappend opts -filetypes $typelist
    }
    set ans [eval {tk_getSaveFile -title [::msgcat::mc {Save As}]  \
      -filetypes $typelist -defaultextension ".ps"  \
      -initialfile "canvas.ps"} $opts]
    if {[string length $ans] > 0} {
	set prefs(userPath) [file dirname $ans]
	if {[file extension $ans] == ".svg"} {
	    ::can2svg::canvas2file $w $ans -uritype file -usetags 0
	} else {
	    eval {$w postscript} $prefs(postscriptOpts) {-file $ans}
	    if {[string equal $this(platform) "macintosh"]} {
		file attributes $ans -type TEXT -creator vgrd
	    }
	}
    }
}

# CanvasCmd::ResizeItem --
#
#       Scales each selected item in canvas 'w' by a factor 'factor'. 
#       Not all item types are rescaled. 
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       factor   a numerical factor to scale with.
#       
# Results:
#       item resized, propagated to clients.

proc ::CanvasCmd::ResizeItem {wtop factor} {
    global  prefs
	
    set w [::WB::GetCanvasFromWtop $wtop]
    set ids [$w find withtag selected]
    if {[string length $ids] == 0} {
	return
    }
    if {$prefs(scaleCommonCG)} {
	set bbox [eval $w bbox $ids]
	set cgx [expr ([lindex $bbox 0] + [lindex $bbox 2])/2.0]
	set cgy [expr ([lindex $bbox 1] + [lindex $bbox 3])/2.0]
    }
    set cmdList {}
    set undoList {}
    set invfactor [expr 1.0/$factor]
    foreach id $ids {
	set utag [::CanvasUtils::GetUtag $w $id]
	if {[string length $utag] == 0} {
	    continue
	}	

	# Sort out the nonrescalable ones.
	set theType [$w type $id]
	if {[string equal $theType "text"] ||   \
	  [string equal $theType "image"] ||    \
	  [string equal $theType "window"]} {
	    continue
	}
	if {!$prefs(scaleCommonCG)} {
	    foreach {left top right bottom} [$w bbox $id] break
	    set cgx [expr ($left + $right)/2.0]
	    set cgy [expr ($top + $bottom)/2.0]
	}
	lappend cmdList [list scale $utag $cgx $cgy $factor $factor]
	lappend undoList [list scale $utag $cgx $cgy $invfactor $invfactor]
    }    
    set redo [list ::CanvasUtils::CommandList $wtop $cmdList]
    set undo [list ::CanvasUtils::CommandList $wtop $undoList]
    eval $redo
    undo::add [::WB::GetUndoToken $wtop] $undo $redo
    
    # New markers.
    foreach id $ids {
	$w delete id$id
	$w dtag $id selected
	::CanvasDraw::MarkBbox $w 1 $id
    }
}

# CanvasCmd::FlipItem --
#
#

proc ::CanvasCmd::FlipItem {wtop direction} {
	
    set w [::WB::GetCanvasFromWtop $wtop]
    set id [$w find withtag selected]
    if {[llength $id] != 1} {
	return
    }
    set theType [$w type $id]
    if {![string equal $theType "line"] &&  \
      ![string equal $theType "polygon"]} {
	return
    }
    set utag [::CanvasUtils::GetUtag $w $id]
    foreach {left top right bottom} [$w bbox $id] break
    set xmid [expr ($left + $right)/2]
    set ymid [expr ($top + $bottom)/2]
    set flipco {}
    set coords [$w coords $id]
    if {[string equal $direction "horizontal"]} {
	foreach {x y} $coords {
	    lappend flipco [expr 2*$xmid - $x] $y
	}	
    } elseif {[string equal $direction "vertical"]} {
	foreach {x y} $coords {
	    lappend flipco $x [expr 2*$ymid - $y]
	}	
    }
    set cmd "coords $utag $flipco"
    set undocmd "coords $utag $coords"    
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]
    eval $redo
    undo::add [::WB::GetUndoToken $wtop] $undo $redo
	
    # New markers.
    $w delete id$id
    ::CanvasDraw::MarkBbox $w 1 $id
}

# CanvasCmd::Undo --
#
#       The undo command.

proc ::CanvasCmd::Undo {wtop} {
    
    # Make the text stuff in sync.
    set wCan [::WB::GetCanvasFromWtop $wtop]
    ::CanvasText::EvalBufferedText $wCan
    
    # The actual undo command.
    undo::undo [::WB::GetUndoToken $wtop]
    
    ::CanvasDraw::SyncMarks $wtop
}

# CanvasCmd::Redo --
#
#       The redo command.

proc ::CanvasCmd::Redo {wtop} {
    
    undo::redo [::WB::GetUndoToken $wtop]
}

# CanvasCmd::DoEraseAll --
#
#       Erases all items in canvas except for grids. Deselects all items.
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       where    "all": erase this canvas and all others.
#                "remote": erase only client canvases.
#                "local": erase only own canvas.
#       
# Results:
#       all items deleted, propagated to all clients.

proc ::CanvasCmd::DoEraseAll {wtop {where all}} {
	
    set wCan [::WB::GetCanvasFromWtop $wtop]
    ::CanvasCmd::DeselectAll $wtop
    foreach id [$wCan find all] {
	
	# Do not erase grid.
	set theTags [$wCan gettags $id]
	if {[lsearch $theTags grid] >= 0} {
	    continue
	}
	::CanvasDraw::DeleteItem $wCan 0 0 $id $where
    }
}

proc ::CanvasCmd::EraseAll {wtop} {
	
    set wCan [::WB::GetCanvasFromWtop $wtop]
    foreach id [$wCan find all] {
	$wCan delete $id
    }
}

# CanvasCmd::DoPutCanvasDlg --
#
#       Erases all client canvases, transfers this canvas to all clients.
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       
# Results:
#       all items deleted, propagated to all clients.

proc ::CanvasCmd::DoPutCanvasDlg {wtop} {
	
    set wCan [::WB::GetCanvasFromWtop $wtop]
    set ans [tk_messageBox -message [FormatTextForMessageBox \
      "Warning! Syncing this canvas first erases all client canvases."] \
      -icon warning -type okcancel -default ok]
    if {$ans != "ok"} {
	return
    }
    
    # Erase all other client canvases.
    DoEraseAll $wtop "remote"

    # Put this canvas to all others.
    ::CanvasCmd::DoPutCanvas $wCan all
}
    
# CanvasCmd::DoPutCanvas --
#   
#       Synchronizes, or puts, this canvas to all others. 
#       It uses a temporary file. Images don't work automatically.
#       If 'toIPnum' then put canvas 'w' only to that ip number.
#       
# Arguments:
#       w        the canvas.
#       toIPnum  if ip number given, then put canvas 'w' only to that ip number.
#                else put to all clients.
#       
# Results:
#       .

proc ::CanvasCmd::DoPutCanvas {w {toIPnum all}} {
    global  this

    Debug 2 "::CanvasCmd::DoPutCanvas w=$w, toIPnum=$toIPnum"

    set tmpFile ".tmp[clock seconds].can"
    set absFilePath [file join $this(path) $tmpFile]

    # Save canvas to temporary file.
    if {[catch [list open $absFilePath w] fileId]} {
	tk_messageBox -message [FormatTextForMessageBox  \
	  [::msgcat::mc messfailopwrite $tmpFile $fileId]] \
	  -icon error -type ok
    }
    ::CanvasFile::CanvasToFile $w $fileId $absFilePath
    catch {close $fileId}

    if {[catch [list open $absFilePath r] fileId]} {
	tk_messageBox -message [FormatTextForMessageBox  \
	  [::msgcat::mcset en messfailopread $tmpFile $fileId]] \
	  -icon error -type ok
    }
    
    # Distribute to all other client canvases.
    if {$toIPnum == "all"} {
	::CanvasFile::FileToCanvas $w $fileId $absFilePath -where remote
    } else {
	::CanvasFile::FileToCanvas $w $fileId $absFilePath -where $toIPnum
    }
    catch {close $fileId}

    # Finally delete the temporary file.
    file delete $absFilePath
}

# CanvasCmd::DoGetCanvas --
#
#       .
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       
# Results:
#       .

proc ::CanvasCmd::DoGetCanvas {wtop} {
    
    # The dialog to select remote client.
    set getCanIPNum [::Dialogs::GetCanvas .getcan]
    Debug 2 "DoGetCanvas:: getCanIPNum=$getCanIPNum"

    if {$getCanIPNum == ""} {
	return
    }    
    
    # Erase everything in own canvas.
    DoEraseAll $wtop "local"
    
    # GET CANVAS.
    ::WB::SendGenMessageList $wtop [list "GET CANVAS:"] -ips $getCanIPNum
}

# CanvasCmd::DoSendCanvas --
#
#       Puts the complete canvas to remote client(s).
#       Does not use a temporary file. Does not add anything to undo stack.
#       Needed because jabber should get everything in single batch.
#       Lets remote client get binary entities (images ...) via http.

proc ::CanvasCmd::DoSendCanvas {wtop} {
    
    set w [::WB::GetCanvasFromWtop $wtop]
    set cmdList [::CanvasUtils::GetCompleteCanvas $w]
        
    # Just invoke the send message hook.
    ::WB::SendMessageList $wtop $cmdList -force 1
}

#-------------------------------------------------------------------------------
