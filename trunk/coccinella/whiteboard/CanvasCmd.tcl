# CanvasCmd.tcl ---
#  
#       Implementations of some whiteboard canvas actions.
#      
#  Copyright (c) 2000-2003  Mats Bengtsson
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
# $Id: CanvasCmd.tcl,v 1.17 2008-03-25 08:52:31 matben Exp $

package provide CanvasCmd 1.0


namespace eval ::CanvasCmd:: {
    
}

# CanvasCmd::SelectAll --
#
#       Selects all items in the canvas.
#   
# Arguments:
#       wcan        canvas widget
#       
# Results:
#       none

proc ::CanvasCmd::SelectAll {wcan} {
    
    $wcan delete tbbox
    set ids [$wcan find all]
    foreach id $ids {
	$wcan dtag $id selected
	::CanvasDraw::MarkBbox $wcan 1 $id
    }
}

# CanvasCmd::DeselectAll --
#
#       Deselects all items in the canvas.
#   
# Arguments:
#       wcan        canvas widget
#       
# Results:
#       none

proc ::CanvasCmd::DeselectAll {wcan} {
	
    $wcan delete withtag tbbox
    $wcan dtag all selected
}

proc ::CanvasCmd::MoveSelected {wcan detail} {
    
    set selected [$wcan find withtag selected]
    if {![llength $selected]} {
	return
    }
    set dx 0
    set dy 0
    set step 10
    
    switch -- $detail {
	up {
	    set dy -$step
	}
	down {
	    set dy $step
	}
	right {
	    set dx $step
	}
	left {
	    set dx -$step
	}
    }
    
    set mdx [expr {-1*$dx}]
    set mdy [expr {-1*$dy}]
    set cmdList {}
    set cmdUndoList {}
    
    foreach id $selected {
	set utag [::CanvasUtils::GetUtag $wcan $id]
	
	# Let images use coords instead since more robust if transported.
	switch -- [$wcan type $id] {
	    image {
		
		# Find new coords.
		lassign [$wcan coords $id] x0 y0
		set x [expr {$x0 + $dx}]
		set y [expr {$y0 + $dy}]
		lappend cmdList [list coords $utag $x $y]
		lappend cmdUndoList [list coords $utag $x0 $y0]
	    }
	    default {
		lappend cmdList [list move $utag $dx $dy]
		lappend cmdUndoList [list move $utag $mdx $mdy]
	    }
	}
    }
    set w [winfo toplevel $wcan]
    set redo [list ::CanvasUtils::CommandList $w $cmdList]
    set undo [list ::CanvasUtils::CommandList $w $cmdUndoList]
    eval $redo
    undo::add [::WB::GetUndoToken $wcan] $undo $redo   

    ::CanvasFile::SetUnsaved $wcan
    
    DeselectAll $wcan
    foreach id $selected {
	::CanvasDraw::SelectItem $wcan $id
    }
}

# CanvasCmd::RaiseOrLowerItems --
#
#       Raise or lower the stacking order of the selected canvas item.
#       
# Arguments:
#       wcan        canvas widget
#       what        "raise" or "lower"
#       
# Results:
#       none.

proc ::CanvasCmd::RaiseOrLowerItems {wcan {what raise}} {
        
    set w [winfo toplevel $wcan]
    upvar ::WB::${w}::state state

    set cmdList {}
    set undoList {}
    
    # The items are returned in stacking order, with the lowest item first.
    # If lower we must start with the topmost, and then go downwards!
    set selected [$wcan find withtag selected]
    if {[string equal $what "lower"]} {
	set selected [lrevert $selected]
    }
    foreach id $selected {
	set utag [::CanvasUtils::GetUtag $wcan $id]
	lappend cmdList [list $what $utag all]
	lappend undoList [::CanvasUtils::GetStackingCmd $wcan $utag]
    }
    if {$state(canGridOn) && [string equal $what "lower"]} {
	lappend cmdList [list lower grid all]
    }
    set redo [list ::CanvasUtils::CommandList $w $cmdList]
    set undo [list ::CanvasUtils::CommandList $w $undoList]
    eval $redo
    undo::add [::WB::GetUndoToken $wcan] $undo $redo

    ::CanvasFile::SetUnsaved $wcan
}

# CanvasCmd::SetCanvasBgColor --
#
#       Sets background color of canvas.
#       
# Arguments:
#       w           toplevel widget path
#       
# Results:
#       color dialog shown.

proc ::CanvasCmd::SetCanvasBgColor {w} {
    global  prefs
    upvar ::WB::${w}::state state
	
    set wcan [::WB::GetCanvasFromWtop $w]
    set prevCol $state(bgColCan)
    set col [tk_chooseColor -initialcolor $state(bgColCan)]
    if {$col ne ""} {
	
	# The change should be triggered automatically through the trace.
	set state(bgColCan) $col
	set cmd [list configure -bg $col -highlightbackground $col]
	set undocmd [list configure -bg $prevCol -highlightbackground $prevCol]
	set redo [list ::CanvasUtils::Command $w $cmd]
	set undo [list ::CanvasUtils::Command $w $undocmd]
	eval $redo
	undo::add [::WB::GetUndoToken $wcan] $undo $redo
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

proc ::CanvasCmd::DoCanvasGrid {w} {
    global  prefs this
    
    upvar ::WB::${w}::state state

    set wcan [::WB::GetCanvasFromWtop $w]
    set length 2000
    set gridDist $prefs(gridDist)
    if {$state(canGridOn) == 0} {
	$wcan delete grid
	return
    }
    if {$this(platform) eq "windows"} {
	for {set x $gridDist} {$x <= $length} {set x [expr $x + $gridDist]} {
	    $wcan create line $x 0 $x $length  \
	      -width 1 -fill gray50 -tags {notactive grid}
	}
	for {set y $gridDist} {$y <= $length} {set y [expr $y + $gridDist]} {
	    $wcan create line 0 $y $length $y  \
	      -width 1 -fill gray50 -tags {notactive grid}
	}
    } else {
	for {set x $gridDist} {$x <= $length} {set x [expr $x + $gridDist]} {
	    $wcan create line $x 0 $x $length  \
	      -width 1 -fill gray50 -tags {notactive grid} -stipple gray50
	}
	for {set y $gridDist} {$y <= $length} {set y [expr $y + $gridDist]} {
	    $wcan create line 0 $y $length $y  \
	      -width 1 -fill gray50 -tags {notactive grid} -stipple gray50
	}
    }
    $wcan lower grid
}

# CanvasCmd::ResizeItem --
#
#       Scales each selected item in canvas 'w' by a factor 'factor'. 
#       Not all item types are rescaled. 
#       
# Arguments:
#       wcan        canvas widget
#       factor      a numerical factor to scale with.
#       
# Results:
#       item resized, propagated to clients.

proc ::CanvasCmd::ResizeItem {wcan factor} {
    global  prefs
	
    set w [winfo toplevel $wcan]
    set ids [$wcan find withtag selected]
    if {$ids eq {}} {
	return
    }
    if {$prefs(scaleCommonCG)} {
	set bbox [eval $wcan bbox $ids]
	set cgx [expr ([lindex $bbox 0] + [lindex $bbox 2])/2.0]
	set cgy [expr ([lindex $bbox 1] + [lindex $bbox 3])/2.0]
    }
    set cmdList {}
    set undoList {}
    set invfactor [expr 1.0/$factor]
    foreach id $ids {
	set utag [::CanvasUtils::GetUtag $wcan $id]
	if {$utag eq ""} {
	    continue
	}	

	# Sort out the nonrescalable ones.
	set type [$wcan type $id]
	if {[string equal $type "text"] ||   \
	  [string equal $type "image"] ||    \
	  [string equal $type "window"]} {
	    continue
	}
	if {!$prefs(scaleCommonCG)} {
	    foreach {left top right bottom} [$wcan bbox $id] break
	    set cgx [expr ($left + $right)/2.0]
	    set cgy [expr ($top + $bottom)/2.0]
	}
	lappend cmdList [list scale $utag $cgx $cgy $factor $factor]
	lappend undoList [list scale $utag $cgx $cgy $invfactor $invfactor]
    }    
    set redo [list ::CanvasUtils::CommandList $w $cmdList]
    set undo [list ::CanvasUtils::CommandList $w $undoList]
    eval $redo
    undo::add [::WB::GetUndoToken $wcan] $undo $redo

    ::CanvasFile::SetUnsaved $wcan

    # New markers.
    foreach id $ids {
	::CanvasDraw::DeleteSelection $wcan $id
	::CanvasDraw::MarkBbox $wcan 1 $id
    }
}

# CanvasCmd::FlipItem --
#
#

proc ::CanvasCmd::FlipItem {wcan direction} {

    set w [winfo toplevel $wcan]
    set id [$wcan find withtag selected]
    if {[llength $id] != 1} {
	return
    }
    set theType [$wcan type $id]
    if {![string equal $theType "line"] &&  \
      ![string equal $theType "polygon"]} {
	return
    }
    set utag [::CanvasUtils::GetUtag $wcan $id]
    foreach {left top right bottom} [$wcan bbox $id] break
    set xmid [expr ($left + $right)/2]
    set ymid [expr ($top + $bottom)/2]
    set flipco {}
    set coords [$wcan coords $id]
    if {[string equal $direction "horizontal"]} {
	foreach {x y} $coords {
	    lappend flipco [expr 2*$xmid - $x] $y
	}	
    } elseif {[string equal $direction "vertical"]} {
	foreach {x y} $coords {
	    lappend flipco $x [expr 2*$ymid - $y]
	}	
    }
    set cmd [concat coords $utag $flipco]
    set undocmd [concat coords $utag $coords]
    set redo [list ::CanvasUtils::Command $w $cmd]
    set undo [list ::CanvasUtils::Command $w $undocmd]
    eval $redo
    undo::add [::WB::GetUndoToken $wcan] $undo $redo

    ::CanvasFile::SetUnsaved $wcan

    # New markers.
    ::CanvasDraw::DeleteSelection $wcan $id
    ::CanvasDraw::MarkBbox $wcan 1 $id
}

proc ::CanvasCmd::Undo {wcan} {
    
    # Make the text stuff in sync.
    ::CanvasText::EvalBufferedText $wcan
    
    # The actual undo command.
    undo::undo [::WB::GetUndoToken $wcan]
    
    ::CanvasFile::SetUnsaved $wcan
    ::CanvasDraw::SyncMarks $wcan
}

# CanvasCmd::Redo --
#
#       The redo command.

proc ::CanvasCmd::Redo {wcan} {
    undo::redo [::WB::GetUndoToken $wcan]
    ::CanvasFile::SetUnsaved $wcan
}

# CanvasCmd::DoEraseAll --
#
#       Erases all items in canvas except for grids. Deselects all items.
#       
# Arguments:
#       w           canvas widget
#       where    "all": erase this canvas and all others.
#                "remote": erase only client canvases.
#                "local": erase only own canvas.
#       
# Results:
#       all items deleted, propagated to all clients.

proc ::CanvasCmd::DoEraseAll {wcan {where all}} {
    DeselectAll $wcan
    ::CanvasDraw::DeleteIds $wcan [$wcan find all] $where
}

proc ::CanvasCmd::EraseAll {wcan} {	
    foreach id [$wcan find all] {
	$wcan delete $id
    }
}

# CanvasCmd::DoPutCanvasDlg --
#
#       Erases all client canvases, transfers this canvas to all clients.
#       
# Arguments:
#       w           toplevel widget path
#       
# Results:
#       all items deleted, propagated to all clients.

proc ::CanvasCmd::DoPutCanvasDlg {w} {
	
    set wcan [::WB::GetCanvasFromWtop $w]
    set ans [::UI::MessageBox -message  \
      "Warning! Syncing this canvas first erases all client canvases." \
      -icon warning -type okcancel -default ok]
    if {$ans ne "ok"} {
	return
    }
    
    # Erase all other client canvases.
    DoEraseAll $wcan remote

    # Put this canvas to all others.
    ::CanvasCmd::DoPutCanvas $wcan all
}
    
# CanvasCmd::DoPutCanvas --
#   
#       Synchronizes, or puts, this canvas to all others. 
#       It uses a temporary file. Images don't work automatically.
#       If 'toIPnum' then put canvas 'w' only to that ip number.
#       
# Arguments:
#       wcan     the canvas.
#       toIPnum  if ip number given, then put canvas 'w' only to that ip number.
#                else put to all clients.
#       
# Results:
#       .

proc ::CanvasCmd::DoPutCanvas {wcan {toIPnum all}} {
    global  this

    Debug 2 "::CanvasCmd::DoPutCanvas wcan=$wcan, toIPnum=$toIPnum"

    set tmpFile ".tmp[clock seconds].can"
    set absFilePath [file join $this(tmpPath) $tmpFile]

    # Save canvas to temporary file.
    if {[catch {open $absFilePath w} fileId]} {
	::UI::MessageBox -message [mc messfailopwrite2 $tmpFile $fileId] \
	  -icon error -title [mc Error] -type ok
    }
    fconfigure $fileId -encoding utf-8
    ::CanvasFile::CanvasToChannel $wcan $fileId $absFilePath
    catch {close $fileId}

    if {[catch {open $absFilePath r} fileId]} {
	::UI::MessageBox -message [mcset en messfailopread2 $tmpFile $fileId] \
	  -icon error -title [mc Error] -type ok
    }
    fconfigure $fileId -encoding utf-8
    
    # Distribute to all other client canvases.
    if {$toIPnum eq "all"} {
	::CanvasFile::FileToCanvas $wcan $fileId $absFilePath -where remote
    } else {
	::CanvasFile::FileToCanvas $wcan $fileId $absFilePath -where $toIPnum
    }
    catch {close $fileId}

    # Finally delete the temporary file.
    file delete $absFilePath
}


# CanvasCmd::DoSendCanvas --
#
#       Puts the complete canvas to remote client(s).
#       Does not use a temporary file. Does not add anything to undo stack.
#       Needed because jabber should get everything in single batch.
#       Lets remote client get binary entities (images ...) via http.

proc ::CanvasCmd::DoSendCanvas {w} {
    
    set wcan [::WB::GetCanvasFromWtop $w]
    set cmdList [::CanvasUtils::GetCompleteCanvas $wcan]
        
    # Just invoke the send message hook.
    ::WB::SendMessageList $w $cmdList -force 1
}

#-------------------------------------------------------------------------------
