#  CanvasDraw.tcl ---
#  
#      This file is part of The Coccinella application. It implements the
#      drawings commands associated with the tools.
#      
#  Copyright (c) 2000-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: CanvasDraw.tcl,v 1.4 2004-07-22 15:56:45 matben Exp $

#  All code in this file is placed in one common namespace.
#  
#-- TAGS -----------------------------------------------------------------------
#  
#  All items are associated with tags. Each item must have a global unique
#  identifier, utag, so that the item can be identified on the net.
#  The standard items which are drawn and imported images, have two additional
#  tags:
#       std         verbatim; this is used for all items made by the standard
#                   tools
#       $type       line, oval, rectangle, arc, image, polygon corresponding 
#                   to the items 'type'

package provide CanvasDraw 1.0

namespace eval ::CanvasDraw:: {}

#--- The 'move' tool procedures ------------------------------------------------

# CanvasDraw::InitMoveSelected, DragMoveSelected, FinalMoveSelected --
# 
#       Moves all selected items.

proc ::CanvasDraw::InitMoveSelected {w x y} {
    variable moveArr
    
    set selected [$w find withtag selected]
    if {[llength $selected] == 0} {
	return
    }
    if {[::CanvasDraw::HitMovableTBBox $w $x $y]} {
	return
    }
    set moveArr(x) $x
    set moveArr(y) $y
    set moveArr(x0) $x
    set moveArr(y0) $y
    set moveArr(bindType) selected
    set moveArr(type) selected
    set moveArr(selected) $selected
    foreach id $selected {
	set moveArr(coords0,$id) [$w coords $id]
    }
}

proc ::CanvasDraw::DragMoveSelected {w x y {modifier {}}} {
    variable moveArr
    
    set selected [$w find withtag selected]
    if {[llength $selected] == 0} {
	return
    }
    if {![string equal $moveArr(bindType) "selected"]} {
	return
    }
    if {[string equal $modifier "shift"]} {
	foreach {x y} [::CanvasDraw::GetConstrainedXY $x $y] {break}
    }
    set dx [expr $x - $moveArr(x)]
    set dy [expr $y - $moveArr(y)]
    $w move selected $dx $dy
    $w move tbbox $dx $dy
    set moveArr(x) $x
    set moveArr(y) $y
}

proc ::CanvasDraw::FinalMoveSelected {w x y} {
    variable moveArr
    
    # Protect thsi from beeing trigged when moving individual points.
    set selected [$w find withtag selected]
    if {[llength $selected] == 0} {
	return
    }
    if {![info exists moveArr]} {
	return
    }
    if {![string equal $moveArr(bindType) "selected"]} {
	return
    }
    
    # Have moved a bunch of ordinary items.
    set dx [expr $x - $moveArr(x0)]
    set dy [expr $y - $moveArr(y0)]
    set mdx [expr -$dx]
    set mdy [expr -$dy]
    set cmdList {}
    set cmdUndoList {}
    
    foreach id $selected {
	set utag [::CanvasUtils::GetUtag $w $id]
	
	# Let images use coords instead since more robust if transported.
	switch -- [$w type $id] {
	    image {
		
		# Find new coords.
		foreach {x0 y0} $moveArr(coords0,$id) {break}
		set x [expr $x0 + $dx]
		set y [expr $y0 + $dy]
		lappend cmdList [list coords $utag $x $y]
		lappend cmdUndoList \
		  [concat coords $utag $moveArr(coords0,$id)]
	    }
	    default {
		lappend cmdList [list move $utag $dx $dy]
		lappend cmdUndoList [list move $utag $mdx $mdy]
	    }
	}
    }
    set wtop [::UI::GetToplevelNS $w]
    set redo [list ::CanvasUtils::CommandList $wtop $cmdList]
    set undo [list ::CanvasUtils::CommandList $wtop $cmdUndoList]
    eval $redo remote
    undo::add [::WB::GetUndoToken $wtop] $undo $redo    
    
    catch {unset moveArr}
}

# CanvasDraw::InitMoveCurrent, DragMoveCurrent, FinalMoveCurrent  --
# 
#       Moves 'current' item.

proc ::CanvasDraw::InitMoveCurrent {w x y} {
    variable moveArr
    
    set selected [$w find withtag selected]
    if {[llength $selected] > 0} {
	return
    }
    set id [$w find withtag current]
    set moveArr(x) $x
    set moveArr(y) $y
    set moveArr(x0) $x
    set moveArr(y0) $y
    set moveArr(id) $id
    set moveArr(coords0,$id) [$w coords $id]
    set moveArr(bindType) std
    set moveArr(type) [$w type $id]
}

proc ::CanvasDraw::DragMoveCurrent {w x y {modifier {}}} {
    variable moveArr
    
    set selected [$w find withtag selected]
    if {[llength $selected] > 0} {
	return
    }
    if {[string equal $modifier "shift"]} {
	foreach {x y} [::CanvasDraw::GetConstrainedXY $x $y] {break}
    }
    set dx [expr $x - $moveArr(x)]
    set dy [expr $y - $moveArr(y)]
    $w move $moveArr(id) $dx $dy
    set moveArr(x) $x
    set moveArr(y) $y
}

proc ::CanvasDraw::FinalMoveCurrent {w x y} {
    variable moveArr
    
    set selected [$w find withtag selected]
    if {[llength $selected] > 0} {
	return
    }
    set dx [expr $x - $moveArr(x0)]
    set dy [expr $y - $moveArr(y0)]
    set mdx [expr -$dx]
    set mdy [expr -$dy]
    set cmdList {}
    set cmdUndoList {}
    
    set id $moveArr(id)
    set utag [::CanvasUtils::GetUtag $w $id]
	
    # Let images use coords instead since more robust if transported.
    switch -- [$w type $id] {
	image {
	    
	    # Find new coords.
	    foreach {x0 y0} $moveArr(coords0,$id) {break}
	    set x [expr $x0 + $dx]
	    set y [expr $y0 + $dy]
	    lappend cmdList [list coords $utag $x $y]
	    lappend cmdUndoList \
	      [concat coords $utag $moveArr(coords0,$id)]
	}
	default {
	    lappend cmdList [list move $utag $dx $dy]
	    lappend cmdUndoList [list move $utag $mdx $mdy]
	}
    }
    set wtop [::UI::GetToplevelNS $w]
    set redo [list ::CanvasUtils::CommandList $wtop $cmdList]
    set undo [list ::CanvasUtils::CommandList $wtop $cmdUndoList]
    eval $redo remote
    undo::add [::WB::GetUndoToken $wtop] $undo $redo    
    
    catch {unset moveArr}
}

# CanvasDraw::InitMoveRectPoint, DragMoveRectPoint, FinalMoveRectPoint --
# 
#       For rectangle and oval corner points.

proc ::CanvasDraw::InitMoveRectPoint {w x y} {
    variable moveArr
    
    if {![::CanvasDraw::HitTBBox $w $x $y]} {
	return
    }

    # Moving a marker of a selected item, highlight marker.
    # 'current' must be a marker with tag 'tbbox'.
    set id [$w find withtag current]
    $w addtag hitBbox withtag $id

    # Find associated id for the actual item. Saved in the tags of the marker.
    if {![regexp {id:([0-9]+)} [$w gettags $id] match itemid]} {
	return
    }
    ::CanvasDraw::DrawHighlightBox $w $itemid $id
    set itemcoords [$w coords $itemid]
    set utag [::CanvasUtils::GetUtag $w $itemid]

    # Get the index of the coordinates that was 'hit'. Then update only
    # this coordinate when moving.
    # For rectangle and oval items a list with all four coordinates is used,
    # but only the hit corner and the diagonally opposite one are kept.
    	
    # Need to reconstruct all four coordinates as: 0---1
    #                                              |   |
    #                                              2---3
    set longcoo [concat   \
      [lindex $itemcoords 0] [lindex $itemcoords 1]  \
      [lindex $itemcoords 2] [lindex $itemcoords 1]  \
      [lindex $itemcoords 0] [lindex $itemcoords 3]  \
      [lindex $itemcoords 2] [lindex $itemcoords 3]]
  
    set ind [::CanvasDraw::FindClosestCoordsIndex $x $y $longcoo]
    set ptind [expr $ind/2]
    
    # Keep only hit corner and the diagonally opposite one.
    set coords [list [lindex $longcoo $ind]  \
      [lindex $longcoo [expr $ind + 1]]]
    
    switch -- $ptind {
	0 {
	    set coo [lappend coords [lindex $longcoo 6] [lindex $longcoo 7]]
	}
	1 {
	    set coo [lappend coords [lindex $longcoo 4] [lindex $longcoo 5]]
	}
	2 {
	    set coo [lappend coords [lindex $longcoo 2] [lindex $longcoo 3]]
	}
	3 {
	    set coo [lappend coords [lindex $longcoo 0] [lindex $longcoo 1]]
	}
    }
    
    set moveArr(x) $x
    set moveArr(y) $y
    set moveArr(x0) $x
    set moveArr(y0) $y
    set moveArr(id) $id
    set moveArr(itemid) $itemid
    set moveArr(utag) $utag
    set moveArr(coords0) [$w coords $id]
    set moveArr(itemcoords0) $coo
    set moveArr(undocmd) [concat coords $utag $itemcoords]
    set moveArr(bindType) tbbox:rect
    set moveArr(type) [$w type $itemid]
}

proc ::CanvasDraw::DragMoveRectPoint {w x y {modifier {}}} {
    variable moveArr
    
    if {![string equal $moveArr(bindType) "tbbox:rect"]} {
	return
    }
    if {[string equal $modifier "shift"]} {
	foreach {x y} [::CanvasDraw::GetConstrainedXY $x $y] {break}
    }
    set dx [expr $x - $moveArr(x)]
    set dy [expr $y - $moveArr(y)]
    set newcoo [lreplace $moveArr(itemcoords0) 0 1 $x $y]
    eval $w coords $moveArr(itemid) $newcoo
    $w move hitBbox $dx $dy
    $w move lightBbox $dx $dy
    set moveArr(x) $x
    set moveArr(y) $y
}

proc ::CanvasDraw::FinalMoveRectPoint {w x y} {
    variable moveArr
    
    if {![string equal $moveArr(bindType) "tbbox:rect"]} {
	return
    }
    $w delete lightBbox
    $w dtag all hitBbox 

    # Move all markers along.
    $w delete id$moveArr(itemid)
    MarkBbox $w 0 $moveArr(itemid)

    set itemid $moveArr(itemid)
    set utag $moveArr(utag)
    set utag [::CanvasUtils::GetUtag $w $itemid]
    set wtop [::UI::GetToplevelNS $w]
    set cmd [concat coords $utag [$w coords $itemid]]
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    set undo [list ::CanvasUtils::Command $wtop $moveArr(undocmd)]
    eval $redo remote
    undo::add [::WB::GetUndoToken $wtop] $undo $redo

    catch {unset moveArr}
}

# CanvasDraw::InitMoveArcPoint, DragMoveArcPoint, FinalMoveArcPoint --
#
#

proc ::CanvasDraw::InitMoveArcPoint {w x y} {
    global  kGrad2Rad
    variable moveArr
    
    if {![::CanvasDraw::HitTBBox $w $x $y]} {
	return
    }

    # Moving a marker of a selected item, highlight marker.
    # 'current' must be a marker with tag 'tbbox'.
    set id [$w find withtag current]
    $w addtag hitBbox withtag $id

    set moveArr(x) $x
    set moveArr(y) $y
    set moveArr(x0) $x
    set moveArr(y0) $y
    set moveArr(bindType) tbbox:arc
    set moveArr(type) arc

    # Find associated id for the actual item. Saved in the tags of the marker.
    if {![regexp {id:([0-9]+)} [$w gettags $id] match itemid]} {
	return
    }
    ::CanvasDraw::DrawHighlightBox $w $itemid $id
    set itemcoords [$w coords $itemid]
    set utag [::CanvasUtils::GetUtag $w $itemid]
    
    set moveArr(itemid) $itemid
    set moveArr(coords) $itemcoords
    set moveArr(utag)   $utag
    
    # Some geometry. We have got the coordinates defining the box.
    # Find out if we clicked the 'start' or 'extent' "point".
    # Tricky part: be sure that the branch cut is at +-180 degrees!
    # 'itemcget' gives angles 0-360, while atan2 gives -180-180.
    set moveArr(arcX) $x
    set moveArr(arcY) $y
    foreach {x1 y1 x2 y2} $itemcoords break
    set r [expr abs(($x1 - $x2)/2.0)]
    set cx [expr ($x1 + $x2)/2.0]
    set cy [expr ($y1 + $y2)/2.0]
    set moveArr(arcCX) $cx
    set moveArr(arcCY) $cy
    set startAng [$w itemcget $itemid -start]
    
    # Put branch cut at +-180!
    if {$startAng > 180} {
	set startAng [expr $startAng - 360]
    }
    set extentAng [$w itemcget $itemid -extent]
    set xstart [expr $cx + $r * cos($kGrad2Rad * $startAng)]
    set ystart [expr $cy - $r * sin($kGrad2Rad * $startAng)]
    set xfin [expr $cx + $r * cos($kGrad2Rad * ($startAng + $extentAng))]
    set yfin [expr $cy - $r * sin($kGrad2Rad * ($startAng + $extentAng))]
    set dstart [expr hypot($xstart - $x,$ystart - $y)]
    set dfin [expr hypot($xfin - $x,$yfin - $y)]
    set moveArr(arcStart) $startAng
    set moveArr(arcExtent) $extentAng
    set moveArr(arcFin) [expr $startAng + $extentAng]
    if {$dstart < $dfin} {
	set moveArr(arcHit) "start"
    } else {
	set moveArr(arcHit) "extent"
    }
    set moveArr(undocmd) [concat itemconfigure $utag \
      -start $startAng -extent $extentAng]
}

proc ::CanvasDraw::DragMoveArcPoint {w x y {modifier {}}} {
    global  kGrad2Rad kRad2Grad
    variable moveArr
    
    if {[string equal $modifier "shift"]} {
	foreach {x y} [::CanvasDraw::GetConstrainedXY $x $y] {break}
    }
    set dx [expr $x - $moveArr(x)]
    set dy [expr $y - $moveArr(y)]
    set moveArr(x) $x
    set moveArr(y) $y
    
    # Some geometry. We have got the coordinates defining the box.
    set coords $moveArr(coords)
    set itemid $moveArr(itemid)

    foreach {x1 y1 x2 y2} $coords break
    set r [expr abs(($x1 - $x2)/2.0)]
    set cx [expr ($x1 + $x2)/2.0]
    set cy [expr ($y1 + $y2)/2.0]
    set startAng [$w itemcget $itemid -start]
    set extentAng [$w itemcget $itemid -extent]
    set xstart [expr $cx + $r * cos($kGrad2Rad * $startAng)]
    set ystart [expr $cy - $r * sin($kGrad2Rad * $startAng)]
    set xfin [expr $cx + $r * cos($kGrad2Rad * ($startAng + $extentAng))]
    set yfin [expr $cy - $r * sin($kGrad2Rad * ($startAng + $extentAng))]
    set newAng [expr $kRad2Grad * atan2($cy - $y,-($cx - $x))]
    
    # Dragging the 'extent' point or the 'start' point?
    if {[string equal $moveArr(arcHit) "extent"]} { 
	set extentAng [expr $newAng - $moveArr(arcStart)]
	
	# Same trick as when drawing it; take care of the branch cut.
	if {$moveArr(arcExtent) - $extentAng > 180} {
	    set extentAng [expr $extentAng + 360]
	} elseif {$moveArr(arcExtent) - $extentAng < -180} {
	    set extentAng [expr $extentAng - 360]
	}
	set moveArr(arcExtent) $extentAng
	
	# Update angle.
	$w itemconfigure $itemid -extent $extentAng
	
	# Move highlight box.
	$w move hitBbox [expr $xfin - $moveArr(arcX)]   \
	  [expr $yfin - $moveArr(arcY)]
	$w move lightBbox [expr $xfin - $moveArr(arcX)]   \
	  [expr $yfin - $moveArr(arcY)]
	set moveArr(arcX) $xfin
	set moveArr(arcY) $yfin
	
    } elseif {[string equal $moveArr(arcHit) "start"]} {

	# Need to update start angle as well as extent angle.
	set newExtentAng [expr $moveArr(arcFin) - $newAng]
	# Same trick as when drawing it; take care of the branch cut.
	if {$moveArr(arcExtent) - $newExtentAng > 180} {
	    set newExtentAng [expr $newExtentAng + 360]
	} elseif {$moveArr(arcExtent) - $newExtentAng < -180} {
	    set newExtentAng [expr $newExtentAng - 360]
	}
	set moveArr(arcExtent) $newExtentAng
	set moveArr(arcStart) $newAng
	$w itemconfigure $itemid -start $newAng
	$w itemconfigure $itemid -extent $newExtentAng
	
	# Move highlight box.
	$w move hitBbox [expr $xstart - $moveArr(arcX)]   \
	  [expr $ystart - $moveArr(arcY)]
	$w move lightBbox [expr $xstart - $moveArr(arcX)]   \
	  [expr $ystart - $moveArr(arcY)]
	set moveArr(arcX) $xstart
	set moveArr(arcY) $ystart
    }
}

proc ::CanvasDraw::FinalMoveArcPoint {w x y} {
    variable moveArr
    
    set id $moveArr(itemid)
    set wtop [::UI::GetToplevelNS $w]

    $w delete lightBbox
    $w dtag all hitBbox 

    # The arc item: update both angles.
    set utag $moveArr(utag)
    set cmd [concat itemconfigure $utag -start $moveArr(arcStart)   \
      -extent $moveArr(arcExtent)]
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    set undo [list ::CanvasUtils::Command $wtop $moveArr(undocmd)]

    eval $redo remote
    undo::add [::WB::GetUndoToken $wtop] $undo $redo
    
    catch {unset moveArr}
}

# CanvasDraw::InitMovePolyLinePoint, DragMovePolyLinePoint, 
#   FinalMovePolyLinePoint --
# 
#       For moving polygon and line item points.

proc ::CanvasDraw::InitMovePolyLinePoint {w x y} {
    variable moveArr
    
    if {![::CanvasDraw::HitTBBox $w $x $y]} {
	return
    }

    # Moving a marker of a selected item, highlight marker.
    # 'current' must be a marker with tag 'tbbox'.
    set id [$w find withtag current]
    $w addtag hitBbox withtag $id

    set moveArr(x) $x
    set moveArr(y) $y
    set moveArr(x0) $x
    set moveArr(y0) $y

    # Find associated id for the actual item. Saved in the tags of the marker.
    if {![regexp {id:([0-9]+)} [$w gettags $id] match itemid]} {
	return
    }
    ::CanvasDraw::DrawHighlightBox $w $itemid $id
    set itemcoords [$w coords $itemid]
    set ind [::CanvasDraw::FindClosestCoordsIndex $x $y $itemcoords]

    set moveArr(itemid) $itemid
    set moveArr(coords) $itemcoords
    set moveArr(hitInd) $ind
    set moveArr(type) [$w type $itemid]
    set moveArr(bindType) tbbox:polyline
}

proc ::CanvasDraw::DragMovePolyLinePoint {w x y {modifier {}}} {
    variable moveArr

    if {[string equal $modifier "shift"]} {
	foreach {x y} [::CanvasDraw::GetConstrainedXY $x $y] {break}
    }
    set dx [expr $x - $moveArr(x)]
    set dy [expr $y - $moveArr(y)]
    set moveArr(x) $x
    set moveArr(y) $y
    
    set coords $moveArr(coords)
    set itemid $moveArr(itemid)

    set ind $moveArr(hitInd)
    set newcoo [lreplace $coords $ind [expr $ind + 1] $x $y]
    eval $w coords $itemid $newcoo
    $w move hitBbox $dx $dy
    $w move lightBbox $dx $dy
}

proc ::CanvasDraw::FinalMovePolyLinePoint {w x y} {
    variable moveArr

    set itemid $moveArr(itemid)
    set coords $moveArr(coords)
    set utag [::CanvasUtils::GetUtag $w $itemid]
    set wtop [::UI::GetToplevelNS $w]
    set itemcoo [$w coords $itemid]

    $w delete lightBbox
    $w dtag all hitBbox 
 
    # If endpoints overlap in line item, make closed polygon.
    # Find out if closed polygon or open line item. If closed, remove duplicate.

    set len [expr hypot(  \
      [lindex $itemcoo end-1] - [lindex $itemcoo 0],  \
      [lindex $itemcoo end] -  [lindex $itemcoo 1] )]
    if {[string equal $moveArr(type) "line"] && ($len < 8)} {
	    
	# Make the line segments to a closed polygon.
	# Get all actual options.
	set lineopts [::CanvasUtils::GetItemOpts $w $itemid]
	set polycoo [lreplace $itemcoo end-1 end]
	set cmd1 [list delete $utag]
	eval $w $cmd1
	
	# Make the closed polygon. Get rid of non-applicable options.
	set opcmd $lineopts
	array set opcmdArr $opcmd
	foreach op {arrow arrowshape capstyle joinstyle tags} {
	    catch {unset opcmdArr(-$op)}
	}
	set opcmdArr(-outline) black
	
	# Replace -fill with -outline.
	set ind [lsearch -exact $lineopts -fill]
	if {$ind >= 0} {
	    set opcmdArr(-outline) [lindex $lineopts [expr $ind+1]]
	}
	set utag [::CanvasUtils::NewUtag]
	set opcmdArr(-fill) {} 
	set opcmdArr(-tags) [list polygon std $utag]
	set cmd2 [concat create polygon $polycoo [array get opcmdArr]]
	set polyid [eval $w $cmd2]
	set ucmd1 [list delete $utag]
	set ucmd2 [concat create line $coords $lineopts]
	set undo [list ::CanvasUtils::CommandList $wtop [list $ucmd1 $ucmd2]]
	set redo [list ::CanvasUtils::CommandList $wtop [list $cmd1 $cmd2]]
	
	# Move all markers along.
	$w delete id:$itemid
	MarkBbox $w 0 $polyid
    } else {
	set undocmd [concat coords $utag $coords]
	set cmd [concat coords $utag [$w coords $itemid]]
	set undo [list ::CanvasUtils::Command $wtop $undocmd]
	set redo [list ::CanvasUtils::Command $wtop $cmd]
    }

    eval $redo remote
    undo::add [::WB::GetUndoToken $wtop] $undo $redo
   
    catch {unset moveArr}
}

# CanvasDraw::InitMoveFrame, DoMoveFrame FinMoveFrame --
# 
#       Generic and general move functions for framed (window) items.

proc ::CanvasDraw::InitMoveFrame {wcan wframe x y} {
    global  kGrad2Rad    
    variable  xDragFrame
    
    # Fix x and y.
    set x [$wcan canvasx [expr [winfo x $wframe] + $x]]
    set y [$wcan canvasx [expr [winfo y $wframe] + $y]]
    Debug 2 "InitMoveFrame:: wcan=$wcan, wframe=$wframe x=$x, y=$y"
	
    set xDragFrame(what) "frame"
    set xDragFrame(baseX) $x
    set xDragFrame(baseY) $y
    set xDragFrame(anchorX) $x
    set xDragFrame(anchorY) $y
    
    # In some cases we need the anchor point to be an exact item 
    # specific coordinate.
    
    set xDragFrame(type) [$wcan type current]
    
    # If frame then make ghost rectangle. 
    # Movies (and windows) do not obey the usual stacking order!
    
    set id [::CanvasUtils::FindTypeFromOverlapping $wcan $x $y "frame"]
    if {$id == ""} {
	Debug 2 "  InitMoveFrame:: FindTypeFromOverlapping rejected"
	return
    }
    set it [::CanvasUtils::GetUtag $wcan $id]
    if {$it == ""} {
	Debug 2 "  InitMoveFrame:: GetUtag rejected"
	return
    }
    set xDragFrame(undocmd) [concat coords $it [$wcan coords $id]]
    $wcan addtag selectedframe withtag $id
    foreach {x1 y1 x2 y2} [$wcan bbox $id] break
    incr x1 -1
    incr y1 -1
    incr x2 +1
    incr y2 +1
    $wcan create rectangle $x1 $y1 $x2 $y2 -outline gray50 -width 3 \
      -stipple gray50 -tags "ghostrect"	
    set xDragFrame(doMove) 1
}

# CanvasDraw::DoMoveFrame --
# 
#       Moves a ghost rectangle of a framed window.

proc ::CanvasDraw::DoMoveFrame {wcan wframe x y} {
    variable  xDragFrame

    if {![info exists xDragFrame]} {
	return
    }
    
    # Fix x and y.
    set x [$wcan canvasx [expr [winfo x $wframe] + $x]]
    set y [$wcan canvasx [expr [winfo y $wframe] + $y]]
    
    # Moving a frame window item (ghostrect).
    $wcan move ghostrect [expr $x - $xDragFrame(baseX)] [expr $y - $xDragFrame(baseY)]
    
    set xDragFrame(baseX) $x
    set xDragFrame(baseY) $y
}

proc ::CanvasDraw::FinMoveFrame {wcan wframe  x y} {
    variable  xDragFrame
    
    Debug 2 "FinMoveFrame info exists xDragFrame=[info exists xDragFrame]"

    if {![info exists xDragFrame]} {
	return
    }
   
    # Fix x and y.
    set x [$wcan canvasx [expr [winfo x $wframe] + $x]]
    set y [$wcan canvasx [expr [winfo y $wframe] + $y]]
    set id [$wcan find withtag selectedframe]
    set utag [::CanvasUtils::GetUtag $wcan $id]
    set wtop [::UI::GetToplevelNS $wcan]
    Debug 2 "  FinMoveFrame id=$id, utag=$utag, x=$x, y=$y"

    if {$utag == ""} {
	return
    }
    $wcan move selectedframe [expr $x - $xDragFrame(anchorX)]  \
      [expr $y - $xDragFrame(anchorY)]
    $wcan dtag selectedframe selectedframe
    set cmd [concat coords $utag [$wcan coords $utag]]
    
    # Delete the ghost rect or highlighted marker if any. Remove temporary tags.
    $wcan delete ghostrect
    
    # Do send to all connected.
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    if {[info exists xDragFrame(undocmd)]} {
	set undo [list ::CanvasUtils::Command $wtop $xDragFrame(undocmd)]
    }
    eval $redo remote
    if {[info exists undo]} {
	undo::add [::WB::GetUndoToken $wtop] $undo $redo
    }    
    catch {unset xDragFrame}
}

# CanvasDraw::InitMoveWindow --
# 
#       Generic and general move functions for window items.

proc ::CanvasDraw::InitMoveWindow {wcan win x y} {
    global  kGrad2Rad    
    variable  xDragWin
    
    # Fix x and y.
    set x [$wcan canvasx [expr [winfo x $win] + $x]]
    set y [$wcan canvasx [expr [winfo y $win] + $y]]
    Debug 2 "InitMoveWindow:: wcan=$wcan, win=$win x=$x, y=$y"
	
    set xDragWin(what) "window"
    set xDragWin(baseX) $x
    set xDragWin(baseY) $y
    set xDragWin(anchorX) $x
    set xDragWin(anchorY) $y
    
    # In some cases we need the anchor point to be an exact item 
    # specific coordinate.    
    set xDragWin(type) [$wcan type current]
	
    set id [::CanvasUtils::FindTypeFromOverlapping $wcan $x $y "frame"]
    if {$id == ""} {
	Debug 2 "  InitMoveWindow:: FindTypeFromOverlapping rejected"
	return
    }
    set it [::CanvasUtils::GetUtag $wcan $id]
    if {$it == ""} {
	Debug 2 "  InitMoveWindow:: GetUtag rejected"
	return
    }
    set xDragWin(winbg) [$win cget -bg]
    set xDragWin(undocmd) [concat coords $it [$wcan coords $id]]
    $win configure -bg gray20
    $wcan addtag selectedwindow withtag $id
    set xDragWin(doMove) 1
}

# CanvasDraw::DoMoveWindow --
# 
#       Moves a ghost rectangle of a framed window.

proc ::CanvasDraw::DoMoveWindow {wcan win x y} {
    variable  xDragWin

    if {![info exists xDragWin]} {
	return
    }
    
    # Fix x and y.
    set x [$wcan canvasx [expr [winfo x $win] + $x]]
    set y [$wcan canvasx [expr [winfo y $win] + $y]]
    
    # Moving a frame window item (ghostrect).
    $wcan move selectedwindow \
      [expr $x - $xDragWin(baseX)] [expr $y - $xDragWin(baseY)]
    
    set xDragWin(baseX) $x
    set xDragWin(baseY) $y
}

# CanvasDraw::FinMoveWindow --
# 
# 

proc ::CanvasDraw::FinMoveWindow {wcan win x y} {
    variable  xDragWin
    
    Debug 2 "FinMoveWindow info exists xDragWin=[info exists xDragWin]"

    if {![info exists xDragWin]} {
	return
    }
   
    # Fix x and y.
    set x [$wcan canvasx [expr [winfo x $win] + $x]]
    set y [$wcan canvasx [expr [winfo y $win] + $y]]
    set id [$wcan find withtag selectedwindow]
    set utag [::CanvasUtils::GetUtag $wcan $id]
    set wtop [::UI::GetToplevelNS $wcan]
    Debug 2 "  FinMoveWindow id=$id, utag=$utag, x=$x, y=$y"

    if {$utag == ""} {
	return
    }
    $wcan dtag selectedwindow selectedwindow
    set cmd [concat coords $utag [$wcan coords $utag]]
    $win configure -bg $xDragWin(winbg)
	
    # Do send to all connected.
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    if {[info exists xDragWin(undocmd)]} {
	set undo [list ::CanvasUtils::Command $wtop $xDragWin(undocmd)]
    }
    eval $redo remote
    if {[info exists undo]} {
	undo::add [::WB::GetUndoToken $wtop] $undo $redo
    }    
    catch {unset xDragWin}
}

# CanvasDraw::FinalMoveCurrentGrid --
# 
#       A way to constrain movements to a grid.

proc ::CanvasDraw::FinalMoveCurrentGrid {w x y grid args} {
    variable moveArr
    
    Debug 2 "::CanvasDraw::FinalMoveCurrentGrid"

    set selected [$w find withtag selected]
    if {[llength $selected] > 0} {
	return
    }
    set dx [expr $x - $moveArr(x0)]
    set dy [expr $y - $moveArr(y0)]    
    set id $moveArr(id)
    set utag [::CanvasUtils::GetUtag $w $id]
    if {$utag == ""} {
	return
    }
    array set argsArr {
	-anchor     nw
    }
    array set argsArr $args
    set wtop [::UI::GetToplevelNS $w]

    # Extract grid specifiers.
    foreach {xmin dx nx} [lindex $grid 0] break
    foreach {ymin dy ny} [lindex $grid 1] break
    
    # Position of item.
    foreach {x0 y0 x1 y1} [$w bbox $id] break
    set xc [expr int(($x0 + $x1)/2)]
    set yc [expr int(($y0 + $y1)/2)]
    set width2 [expr int(($x1 - $x0)/2)]
    set height2 [expr int(($y1 - $y0)/2)]
    set ix [expr round(double($xc - $xmin)/$dx)]
    set iy [expr round(double($yc - $ymin)/$dy)]
    
    # Figure out if in the domain of the grid.
    if {($ix >= 0) && ($ix <= $nx) && ($iy >= 0) && ($iy <= $ny)} {
	set doGrid 1
	set newx [expr $xmin + $ix * $dx]
	set newy [expr $ymin + $iy * $dy]
    } else {
	set doGrid 0
	set newx [expr int($x)]
	set newy [expr int($y)]
    }
       
    if {[string equal $moveArr(type) "image"]} {
	if {$doGrid} {
	    set anchor [$w itemcget $id -anchor]
	    
	    switch -- $anchor {
		nw {
		    set offx -$width2
		    set offy -$height2
		}
		default {
		    # missing...
		    set offx 0
		    set offy 0
		}
	    }
	    incr newx $offx
	    incr newy $offy
	}
	set cmd [list coords $utag $newx $newy]
	if {$doGrid} {
	    set redo [list ::CanvasUtils::Command $wtop $cmd]
	} else {
	    set redo [list ::CanvasUtils::Command $wtop $cmd remote]
	}
	set undoCmd [concat coords $utag $moveArr(coords0,$id)]
    } else {
	
	# Non image items. 
	# If grid then compute distances to be moved:
	#    local item need only move to closest grid,
	#    remote item needs to be moved all the way.
	if {$doGrid} {
	    set anchor c
	    set cmdlocal [list move $utag [expr $newx - $xc] [expr $newy - $yc]]
	    set deltax [expr $newx - $moveArr(x0)]
	    set deltay [expr $newy - $moveArr(y0)]
	    set cmdremote [list move $utag $deltax $deltay]
	    set redo [list ::CanvasUtils::CommandExList $wtop  \
	      [list [list $cmdlocal local] [list $cmdremote remote]]]
	    set undoCmd [list move $utag [expr -$deltax] [expr -$deltay]]
	} else {
	    set cmd [list move $utag $dx $dy]
	    set redo [list ::CanvasUtils::Command $wtop $cmd remote]
	    set undoCmd [list move $utag [expr -($x - $moveArr(x0))] \
	      [expr -($y - $moveArr(y0))]]
	}
    }
	
    # Do send to all connected.
    set undo [list ::CanvasUtils::Command $wtop $undoCmd]
    eval $redo
    undo::add [::WB::GetUndoToken $wtop] $undo $redo    

    catch {unset moveArr}
}

proc ::CanvasDraw::HitTBBox {w x y} {
    
    set hit 0
    set d 2
    set ids [$w find overlapping \
      [expr $x-$d] [expr $y-$d] [expr $x+$d] [expr $y+$d]]
    foreach id $ids {
	if {[lsearch [$w gettags $id] tbbox] >= 0} {
	    set hit 1
	    break
	}
    }
    return $hit
}

proc ::CanvasDraw::HitMovableTBBox {w x y} {

    set hit 0
    set d 2
    set movable {arc line polygon rectangle oval}
    set ids [$w find overlapping \
      [expr $x-$d] [expr $y-$d] [expr $x+$d] [expr $y+$d]]
    foreach id $ids {
	set tags [$w gettags $id]
	if {[lsearch $tags tbbox] >= 0} {
	    if {[regexp {id:([0-9]+)} $tags match itemid]} {
		if {[lsearch $movable [$w type $itemid]] >= 0} {
		    set hit 1
		    break
		}
	    }
	}
    }
    return $hit
}

proc ::CanvasDraw::DrawHighlightBox {w itemid id} {
    
    # Make a highlightbox at the 'hitBbox' marker.
    set bbox [$w bbox $id]
    set x1 [expr [lindex $bbox 0] - 1]
    set y1 [expr [lindex $bbox 1] - 1]
    set x2 [expr [lindex $bbox 2] + 1]
    set y2 [expr [lindex $bbox 3] + 1]

    $w create rectangle $x1 $y1 $x2 $y2 -outline black -width 1 \
      -tags [list lightBbox id:${itemid}] -fill white
}

proc ::CanvasDraw::FindClosestCoordsIndex {x y coords} {
    
    set n [llength $coords]
    set min 1000000
    set ind 0
    for {set i 0} {$i < $n} {incr i 2} {
	set len [expr hypot([lindex $coords $i] - $x,  \
	  [lindex $coords [expr $i+1]] - $y)]
	if {$len < $min} {
	    set ind $i
	    set min $len
	}
    }
    return $ind
}

proc ::CanvasDraw::GetConstrainedXY {x y} {
    variable moveArr

    if {[string match tbbox:* $moveArr(bindType)]} {
	if {[string equal $moveArr(type) "arc"]} {
	    set newco [ConstrainedDrag $x $y $moveArr(arcCX) $moveArr(arcCY)]
	} else {
	    set newco [ConstrainedDrag $x $y $moveArr(x0) $moveArr(y0)]
	}
    } else {
	set newco [ConstrainedDrag $x $y $moveArr(x0) $moveArr(y0)]
    }
    return $newco
}

#--- End of the 'move' tool procedures -----------------------------------------

#--- The rectangle, oval, and select from rectangle tool procedures ------------

# CanvasDraw::InitBox --
#
#       Initializes drawing of a rectangles, ovals, and ghost rectangles.
#   
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       type   item type (rectangle, oval, ...).
#       
# Results:
#       none

proc ::CanvasDraw::InitBox {w x y type} {
    
    variable theBox
    
    set theBox($w,anchor) [list $x $y]
    catch {unset theBox($w,last)}
}

# CanvasDraw::BoxDrag --
#
#       Draws rectangles, ovals, and ghost rectangles.
#   
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       shift  constrain to square or circle.
#       type   item type (rectangle, oval, ...).
#       mark   If not 'mark', then draw ordinary rectangle if 'type' is 
#              rectangle or oval if 'type' is oval.
#       
# Results:
#       none

proc ::CanvasDraw::BoxDrag {w x y shift type {mark 0}} {
    global  prefs
    
    variable theBox
    
    set wtop [::UI::GetToplevelNS $w]
    upvar ::WB::${wtop}::state state

    catch {$w delete $theBox($w,last)}
    
    # If not set anchor, just return.
    if {![info exists theBox($w,anchor)]} {
	return
    }
    set boxOrig $theBox($w,anchor)
    
    # If 'shift' constrain to square or circle.
    if {$shift} {
	set box [eval "ConstrainedBoxDrag $theBox($w,anchor) $x $y $type"]
	set boxOrig [lrange $box 0 1]
	set x [lindex $box 2]
	set y [lindex $box 3]
    }
    if {$prefs(haveDash)} {
	set extras [list -dash $state(dash)]
    } else {
	set extras ""
    }
    
    # Either mark rectangle or draw rectangle.
    if {$mark == 0} {
	set tags [list std $type]
	if {$state(fill) == 0} {
	    set theBox($w,last) [eval {$w create $type} $boxOrig  \
	      {$x $y -outline $state(fgCol) -width $state(penThick)  \
	      -tags $tags} $extras]
	} else {
	    set theBox($w,last) [eval {$w create $type} $boxOrig  \
	      {$x $y -outline $state(fgCol) -fill $state(fgCol)  \
	      -width $state(penThick) -tags $tags}  \
	      $extras]
	}
    } else {
	set theBox($w,last) [eval {$w create $type} $boxOrig	\
	  {$x $y -outline gray50 -stipple gray50 -width 2 -tags "markbox" }]
    }
}

# CanvasDraw::FinalizeBox --
#
#       Take action when finsished with BoxDrag, mark items, let all other
#       clients know etc.
#   
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       shift  constrain to square or circle.
#       type   item type (rectangle, oval, ...).
#       mark   If not 'mark', then draw ordinary rectangle if 'type' is rectangle,
#              or oval if 'type' is oval.
#       
# Results:
#       none

proc ::CanvasDraw::FinalizeBox {w x y shift type {mark 0}} {
    global  prefs
    
    variable theBox
    set wtop [::UI::GetToplevelNS $w]
    upvar ::WB::${wtop}::state state
    
    # If no theBox($w,anchor) defined just return.
    if {![info exists theBox($w,anchor)]}  {
	return
    }
    catch {$w delete $theBox($w,last)}
    foreach {xanch yanch} $theBox($w,anchor) break
    if {($xanch == $x) && ($yanch == $y)} {
	set nomove 1
	return
    } else {
	set nomove 0
    }
    if {$mark} {
	set ids [eval {$w find overlapping} $theBox($w,anchor) {$x $y}]
	Debug 2 "FinalizeBox:: ids=$ids"

	foreach id $ids {
	    MarkBbox $w 1 $id
	}
	$w delete withtag markbox
    }
    if {$prefs(haveDash)} {
	set extras [list -dash $state(dash)]
    } else {
	set extras ""
    }
    
    # Create real objects.
    if {!$mark && !$nomove} {
	set boxOrig $theBox($w,anchor)
	
	# If 'shift' constrain to square or circle.
	if {$shift} {
	    set box [eval "ConstrainedBoxDrag $theBox($w,anchor) $x $y $type"]
	    set boxOrig [lrange $box 0 1]
	    set x [lindex $box 2]
	    set y [lindex $box 3]
	}
	if {$mark} {
	    set utag [::CanvasUtils::NewUtag 0]
	} else {
	    set utag [::CanvasUtils::NewUtag]
	}
	if {$state(fill) == 1} {
	    lappend extras -fill $state(fgCol)
	}
	set cmd "create $type $boxOrig $x $y	\
	  -tags {std $type $utag} -outline $state(fgCol)  \
	  -width $state(penThick) $extras"
	set undocmd [list delete $utag]
	set redo [list ::CanvasUtils::Command $wtop $cmd]
	set undo [list ::CanvasUtils::Command $wtop $undocmd]
	eval $redo
	undo::add [::WB::GetUndoToken $wtop] $undo $redo
    }
    catch {unset theBox}
}

proc ::CanvasDraw::CancelBox {w} {
    
    variable theBox
    
    # If no theBox($w,anchor) defined, .
    catch {unset theBox($w,anchor)}
    $w delete withtag markbox
}

# ConstrainedBoxDrag --
#
#       With the 'shift' key pressed, the rectangle and oval items are contrained
#       to squares and circles respectively.
#       
# Arguments:
#       xanch,yanch      the anchor coordinates.
#       x,y    the mouse coordinates.
#       type   item type (rectangle, oval, ...).
#       
# Results:
#       List of the (two) new coordinates for the item.

proc ::CanvasDraw::ConstrainedBoxDrag {xanch yanch x y type} {
    
    set deltax [expr $x - $xanch]
    set deltay [expr $y - $yanch]
    set prod [expr $deltax * $deltay]
    if {$type == "rectangle"} {
	set boxOrig [list $xanch $yanch]
	if {$prod != 0} {
	    set sign [expr $prod / abs($prod)]
	} else {
	    set sign 1
	}
	if {[expr abs($deltax)] > [expr abs($deltay)]} {
	    set x [expr $sign * ($y - $yanch) + $xanch]
	} else {
	    set y [expr $sign * ($x - $xanch) + $yanch]
	}
	
	# A pure circle is not made with the bounding rectangle model.
	# The anchor and the present x, y define the diagonal instead.
    } elseif {$type == "oval"} {
	set r [expr hypot($deltax, $deltay)/2.0]
	set midx [expr ($xanch + $x)/2.0]
	set midy [expr ($yanch + $y)/2.0]
	set boxOrig [list [expr int($midx - $r)] [expr int($midy - $r)]]
	set x [expr int($midx + $r)]
	set y [expr int($midy + $r)]
    }
    return [concat $boxOrig $x $y]
}

#--- End of the rectangle, oval, and select from rectangle tool procedures -----

#--- The arc tool procedures ---------------------------------------------------

# CanvasDraw::InitArc --
#
#       First click sets center, second button press sets start point.
#       
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       type   item type (rectangle, oval, ...).
#       shift  constrain to 45 or 90 degree arcs.
#       
# Results:
#       none

proc ::CanvasDraw::InitArc {w x y {shift 0}} {
    global  kRad2Grad this
    
    variable arcBox
    set wtop [::UI::GetToplevelNS $w]
    
    Debug 2 "InitArc:: w=$w, x=$x, y=$y, shift=$shift"

    if {![info exists arcBox($w,setcent)] || $arcBox($w,setcent) == 0} {
	
	# First button press.
	set arcBox($w,center) [list $x $y]
	set arcBox($w,setcent) 1
	# Hack.
	if {[string match "mac*" $this(platform)]} {
	    $w create oval [expr $x - 2] [expr $y - 2] [expr $x + 3] [expr $y + 3]  \
	      -outline gray50 -fill {} -tags tcent
	    $w create line [expr $x - 5] $y [expr $x + 5] $y -fill gray50 -tags tcent
	    $w create line $x [expr $y - 5] $x [expr $y + 5] -fill gray50 -tags tcent 
	} else {
	    $w create oval [expr $x - 3] [expr $y - 3] [expr $x + 3] [expr $y + 3]  \
	      -outline gray50 -fill {} -tags tcent
	    $w create line [expr $x - 5] $y [expr $x + 6] $y -fill gray50 -tags tcent
	    $w create line $x [expr $y - 5] $x [expr $y + 6] -fill gray50 -tags tcent 
	}
	focus $w
	bind $w <KeyPress-space> {
	    ::CanvasDraw::ArcCancel %W
	}
	::WB::SetStatusMessage $wtop [mc uastatarc2]
	
    } else {
	
	# If second button press, bind mouse motion.
	set cx [lindex $arcBox($w,center) 0]
	set cy [lindex $arcBox($w,center) 1]
	if {$shift} {
	    set newco [ConstrainedDrag $x $y $cx $cy]
	    foreach {x y} $newco {}
	}
	set arcBox($w,first) [list $x $y]
	set arcBox($w,startAng) [expr $kRad2Grad * atan2($cy - $y, -($cx - $x))]
	set arcBox($w,extent) {0.0}
	set r [expr hypot($cx - $x, $cy - $y)]
	set x1 [expr $cx + $r]
	set y1 [expr $cy + $r]
	set arcBox($w,co1) [list $x1 $y1]
	set arcBox($w,co2) [list [expr $cx - $r] [expr $cy - $r]]
	bind $w <B1-Motion> {
	    ::CanvasDraw::ArcDrag %W [%W canvasx %x] [%W canvasy %y]
	}
	bind $w <Shift-B1-Motion> {
	    ::CanvasDraw::ArcDrag %W [%W canvasx %x] [%W canvasy %y] 1
	}
	bind $w <ButtonRelease-1> {
	    ::CanvasDraw::FinalizeArc %W [%W canvasx %x] [%W canvasy %y]
	}
    }
    catch {unset arcBox($w,last)}
}

# CanvasDraw::ArcDrag --
#
#       Draw an arc.
#       The tricky part is to choose one of the two possible solutions, CW or CCW.
#       
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       shift  constrain to 45 or 90 degree arcs.
#       
# Results:
#       none

proc ::CanvasDraw::ArcDrag {w x y {shift 0}} {
    global  kRad2Grad prefs

    variable arcBox
    set wtop [::UI::GetToplevelNS $w]
    upvar ::WB::${wtop}::state state

    # If constrained to 90/45 degrees.
    if {$shift} {
	foreach {cx cy} $arcBox($w,center) {}
	set newco [ConstrainedDrag $x $y $cx $cy]
	foreach {x y} $newco {}
    }
    
    # Choose one of two possible solutions, either CW or CCW.
    # Make sure that the 'extent' angle is more or less continuous.
    
    set stopAng [expr $kRad2Grad *   \
      atan2([lindex $arcBox($w,center) 1] - $y, -([lindex $arcBox($w,center) 0] - $x))]
    set extentAng [expr $stopAng - $arcBox($w,startAng)]
    if {$arcBox($w,extent) - $extentAng > 180} {
	set extentAng [expr $extentAng + 360]
    } elseif {$arcBox($w,extent) - $extentAng < -180} {
	set extentAng [expr $extentAng - 360]
    }
    set arcBox($w,extent) $extentAng
    catch {$w delete $arcBox($w,last)}
    if {$state(fill) == 0} {
	set theFill [list -fill {}]
    } else {
	set theFill [list -fill $state(fgCol)]
    }
    if {$prefs(haveDash)} {
	set extras [list -dash $state(dash)]
    } else {
	set extras {}
    }
    set arcBox($w,last) [eval {$w create arc} $arcBox($w,co1)   \
      $arcBox($w,co2) {-start $arcBox($w,startAng) -extent $extentAng  \
      -width $state(penThick) -style $state(arcstyle) -outline $state(fgCol)  \
      -tags arc} $theFill $extras]
}

# CanvasDraw::FinalizeArc --
#
#       Finalize the arc drawing, tell all other clients.
#       
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       
# Results:
#       none

proc ::CanvasDraw::FinalizeArc {w x y} {
    global  prefs 

    variable arcBox
    set wtop [::UI::GetToplevelNS $w]
    upvar ::WB::${wtop}::state state

    Debug 2 "FinalizeArc:: w=$w"

    ::WB::SetStatusMessage $wtop [mc uastatarc]
    bind $w <B1-Motion> {}
    bind $w <ButtonRelease-1> {}
    bind $w <KeyPress-space> {}
    catch {$w delete tcent}
    catch {$w delete $arcBox($w,last)}
    
    # If extent angle zero, nothing to draw, nothing to send.
    if {$arcBox($w,extent) == "0.0"} {
	catch {unset arcBox}
	return
    }
    
    # Let all other clients know.
    if {$state(fill) == 0} {
	set theFill "-fill {}"
    } else {
	set theFill "-fill $state(fgCol)"
    }
    if {$prefs(haveDash)} {
	set extras [list -dash $state(dash)]
    } else {
	set extras {}
    }
    set utag [::CanvasUtils::NewUtag]
    set cmd "create arc $arcBox($w,co1)   \
      $arcBox($w,co2) -start $arcBox($w,startAng) -extent $arcBox($w,extent)  \
      -width $state(penThick) -style $state(arcstyle) -outline $state(fgCol)  \
      -tags {std arc $utag} $theFill $extras"
    set undocmd "delete $utag"
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]
    eval $redo
    undo::add [::WB::GetUndoToken $wtop] $undo $redo
    catch {unset arcBox}
}

# CanvasDraw::ArcCancel --
#
#       Cancel the arc drawing.
#       
# Arguments:
#       w      the canvas widget.
#       
# Results:
#       none

proc ::CanvasDraw::ArcCancel {w} {
    
    variable arcBox
    set wtop [::UI::GetToplevelNS $w]

    ::WB::SetStatusMessage $wtop [mc uastatarc]
    catch {$w delete tcent}
    catch {unset arcBox}
}

#--- End of the arc tool procedures --------------------------------------------

#--- Polygon tool procedures ---------------------------------------------------

# CanvasDraw::PolySetPoint --
#
#       Polygon drawing routines.
#   
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       
# Results:
#       none

proc ::CanvasDraw::PolySetPoint {w x y} {
    
    variable thePoly

    if {![info exists thePoly(0)]} {
	
	# First point.
	catch {unset thePoly}
	set thePoly(N) 0
	set thePoly(0) [list $x $y]
    } elseif {[expr   \
      hypot([lindex $thePoly(0) 0] - $x, [lindex $thePoly(0) 1] - $y)] < 6} {
	
	# If this point close enough to 'thePoly(0)', close polygon.
	PolyDrag $w [lindex $thePoly(0) 0] [lindex $thePoly(0) 1]
	set thePoly(last) {}
	incr thePoly(N)
	set thePoly($thePoly(N)) $thePoly(0)
	FinalizePoly $w [lindex $thePoly(0) 0] [lindex $thePoly(0) 1]
	return
    } else {
	set thePoly(last) {}
	incr thePoly(N)
	set thePoly($thePoly(N)) $thePoly(xy)
    }
    
    # Let the latest line segment follow the mouse movements.
    focus $w
    bind $w <Motion> {
	::CanvasDraw::PolyDrag %W [%W canvasx %x] [%W canvasy %y]
    }
    bind $w <Shift-Motion> {
	::CanvasDraw::PolyDrag %W [%W canvasx %x] [%W canvasy %y] 1
    }
    bind $w <KeyPress-space> {
	::CanvasDraw::FinalizePoly %W [%W canvasx %x] [%W canvasy %y]
    }
}               

# CanvasDraw::PolyDrag --
#
#       Polygon drawing routines.
#   
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       shift  constrain.
#       
# Results:
#       none

proc ::CanvasDraw::PolyDrag {w x y {shift 0}} {
    global  prefs

    variable thePoly
    set wtop [::UI::GetToplevelNS $w]
    upvar ::WB::${wtop}::state state

    # Move one end point of the latest line segment of the polygon.
    # If anchor not set just return.
    if {![info exists thePoly(0)]} {
	return
    }
    catch {$w delete $thePoly(last)}
    
    # Vertical or horizontal.
    if {$shift} {
	set anch $thePoly($thePoly(N))
	set newco [ConstrainedDrag $x $y [lindex $anch 0] [lindex $anch 1]]
	foreach {x y} $newco {}
    }
    if {$prefs(haveDash)} {
	set extras [list -dash $state(dash)]
    } else {
	set extras ""
    }
    
    # Keep track of last coordinates. Important for 'shift'.
    set thePoly(xy) [list $x $y]
    set thePoly(last) [eval {$w create line} $thePoly($thePoly(N))  \
      {$x $y -tags "polylines" -fill $state(fgCol)  \
      -width $state(penThick)} $extras]
}

# CanvasDraw::FinalizePoly --
#
#       Polygon drawing routines.
#   
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       
# Results:
#       none

proc ::CanvasDraw::FinalizePoly {w x y} {
    global  prefs
    
    variable thePoly
    set wtop [::UI::GetToplevelNS $w]
    upvar ::WB::${wtop}::state state

    bind $w <Motion> {}
    bind $w <KeyPress-space> {}
    
    # If anchor not set just return.
    if {![info exists thePoly(0)]} {
	return
    }
    
    # If too few segment.
    if {$thePoly(N) <= 1} {
	$w delete polylines
	catch {unset thePoly}
	return
    }
    
    # Delete last line segment.
    catch {$w delete $thePoly(last)}
    
    # Find out if closed polygon or open line item. If closed, remove duplicate.
    set isClosed 0
    if {[expr   \
      hypot([lindex $thePoly(0) 0] - $x, [lindex $thePoly(0) 1] - $y)] < 4} {
	set isClosed 1
	unset thePoly($thePoly(N))
	incr thePoly(N) -1
    }
    
    # Transform the set of lines to a polygon (or line) item.
    set coords {}
    for {set i 0} {$i <= $thePoly(N)} {incr i} {
	append coords $thePoly($i) " "
    }
    $w delete polylines
    if {$state(fill) == 0} {
	set theFill [list -fill {}]
    } else {
	set theFill [list -fill $state(fgCol)]
    }
    if {$prefs(haveDash)} {
	set extras [list -dash $state(dash)]
    } else {
	set extras ""
    }
    set utag [::CanvasUtils::NewUtag]
    if {$isClosed} {
	
	# This is a (closed) polygon.
	set cmd "create polygon $coords -tags {std polygon $utag}  \
	  -outline $state(fgCol) $theFill -width $state(penThick)  \
	  -smooth $state(smooth) $extras"
    } else {
	
	# This is an open line segment.
	set cmd "create line $coords -tags {std line $utag}  \
	  -fill $state(fgCol) -width $state(penThick)  \
	  -smooth $state(smooth) $extras"
    }
    set undocmd [list delete $utag]
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]
    eval $redo
    undo::add [::WB::GetUndoToken $wtop] $undo $redo
    catch {unset thePoly}
}

#--- End of polygon drawing procedures -----------------------------------------

#--- Line and arrow drawing procedures ----------------------------------------- 

# CanvasDraw::InitLine --
#
#       Handles drawing of a straight line. Uses global 'theLine' variable
#       to store anchor point and end point of the line.
#       
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       opt    0 for line and arrow for arrow.
#       
# Results:
#       none

proc ::CanvasDraw::InitLine {w x y {opt 0}} {

    variable theLine
    
    set theLine($w,anchor) [list $x $y]
    catch {unset theLine($w,last)}
}

# CanvasDraw::LineDrag --
#
#       Handles drawing of a straight line. Uses global 'theLine' variable
#       to store anchor point and end point of the line.
#       
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       shift  constrain the line to be vertical or horizontal.
#       opt    If 'opt'=arrow draw an arrow at the final line end.
#       
# Results:
#       none

proc ::CanvasDraw::LineDrag {w x y shift {opt 0}} {
    global  prefs
    
    variable theLine
    set wtop [::UI::GetToplevelNS $w]
    upvar ::WB::${wtop}::state state

    # If anchor not set just return.
    if {![info exists theLine($w,anchor)]} {
	return
    }

    catch {$w delete $theLine($w,last)}
    if {[string equal $opt "arrow"]} {
	set extras [list -arrow last]
    } else {
	set extras {}
    }
    if {$prefs(haveDash)} {
	append extras " [list -dash $state(dash)]"
    }
    
    # Vertical or horizontal.
    if {$shift} {
	set newco [ConstrainedDrag $x $y [lindex $theLine($w,anchor) 0]  \
	  [lindex $theLine($w,anchor) 1]]
	foreach {x y} $newco {}
    }
    set theLine($w,last) [eval {$w create line} $theLine($w,anchor)  \
      {$x $y -tags line -fill $state(fgCol)  \
      -width $state(penThick)} $extras]
}

# CanvasDraw::FinalizeLine --
#
#       Handles drawing of a straight line. Uses global 'theLine' variable
#       to store anchor point and end point of the line.
#       Lets all other clients know.
#       
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       shift  constrain the line to be vertical or horizontal.
#       opt    If 'opt'=arrow draw an arrow at the final line end.
#       
# Results:
#       none

proc ::CanvasDraw::FinalizeLine {w x y shift {opt 0}} {
    global  prefs
    
    variable theLine
    set wtop [::UI::GetToplevelNS $w]
    upvar ::WB::${wtop}::state state

    # If anchor not set just return.
    if {![info exists theLine($w,anchor)]} {
	return
    }
    catch {$w delete $theLine($w,last)}

    # If not dragged, zero line, and just return.
    if {![info exists theLine($w,last)]} {
	return
    }
    if {[string equal $opt "arrow"]} {
	set extras [list -arrow last]
    } else {
	set extras {}
    }
    if {$prefs(haveDash)} {
	lappend extras -dash $state(dash)
    }
    
    # Vertical or horizontal.
    if {$shift} {
	set newco [ConstrainedDrag $x $y [lindex $theLine($w,anchor) 0]  \
	  [lindex $theLine($w,anchor) 1]]
	foreach {x y} $newco break
    }
    set utag [::CanvasUtils::NewUtag]
    set cmd "create line $theLine($w,anchor) $x $y	\
      -tags {std line $utag} -joinstyle round	\
      -fill $state(fgCol) -width $state(penThick) $extras"
    set undocmd "delete $utag"
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]
    eval $redo
    undo::add [::WB::GetUndoToken $wtop] $undo $redo
    catch {unset theLine}
}

#--- End of line and arrow drawing procedures ----------------------------------

#--- The stroke tool -----------------------------------------------------------

# CanvasDraw::InitStroke --
#
#       Handles drawing of an arbitrary line. Uses global 'stroke' variable
#       to store all intermediate points on the line, and stroke(N) to store
#       the number of such points. If 'thick'=-1, then use 'state(penThick)',
#       else use the 'thick' argument as line thickness.
#   
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       
# Results:
#       none

proc ::CanvasDraw::InitStroke {w x y} {

    variable stroke
    
    catch {unset stroke}
    set stroke(N) 0
    set stroke(0) [list $x $y]
}

# CanvasDraw::StrokeDrag --
#
#       Handles drawing of an arbitrary line. Uses global 'stroke' variable
#       to store all intermediate points on the line, and stroke(N) to store
#       the number of such points.
#   
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       brush  (D=0) boolean, 1 for brush, 0 for pen.
#       
# Results:
#       none

proc ::CanvasDraw::StrokeDrag {w x y {brush 0}} {
    global  prefs
    
    variable stroke
    set wtop [::UI::GetToplevelNS $w]
    upvar ::WB::${wtop}::state state

    # If stroke not set just return.
    if {![info exists stroke(N)]} {
	return
    }
    set coords $stroke($stroke(N))
    lappend coords $x $y
    incr stroke(N)
    set stroke($stroke(N)) [list $x $y]
    if {$brush} {
	set thisThick $state(brushThick)
    } else {
	set thisThick $state(penThick)
    }
    if {$prefs(haveDash)} {
	set extras [list -dash $state(dash)]
    } else {
	set extras ""
    }
    eval {$w create line} $coords {-tags segments -fill $state(fgCol)  \
      -width $thisThick} $extras
}

# CanvasDraw::FinalizeStroke --
#
#       Handles drawing of an arbitrary line. Uses global 'stroke' variable
#       to store all intermediate points on the line, and stroke(N) to store
#       the number of such points.
#   
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       brush  (D=0) boolean, 1 for brush, 0 for pen.
#       
# Results:
#       none

proc ::CanvasDraw::FinalizeStroke {w x y {brush 0}} {
    global  prefs
    
    variable stroke
    set wtop [::UI::GetToplevelNS $w]
    upvar ::WB::${wtop}::state state

    Debug 2 "FinalizeStroke::"

    # If stroke not set just return.
    set coords {}
    if {![info exists stroke(N)]} {
	return
    }
    set coords [::CanvasDraw::StrokePostProcess $w]
    $w delete segments
    if {[llength $coords] <= 2} {
	return
    }
    if {$brush} {
	set thisThick $state(brushThick)
    } else {
	set thisThick $state(penThick)
    }
    if {$prefs(haveDash)} {
	set extras [list -dash $state(dash)]
    } else {
	set extras ""
    }
    set utag [::CanvasUtils::NewUtag]
    set cmd [list create line $coords  \
      -tags [list std line $utag] -joinstyle round  \
      -smooth $state(smooth) -fill $state(fgCol) -width $thisThick]
    set cmd [concat $cmd $extras]
    set undocmd [list delete $utag]
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]
    eval $redo
    undo::add [::WB::GetUndoToken $wtop] $undo $redo
    catch {unset stroke}
}

# CanvasDraw::StrokePostProcess --
# 
#       Reduce the number of coords in the stroke in a smart way that also
#       smooths it. Always keep first and last.

proc ::CanvasDraw::StrokePostProcess {w} {    
    variable stroke
    
    set coords $stroke(0)
    
    # First pass: remove duplicates if any. Seems not to be the case!
    for {set i 0} {$i <= [expr $stroke(N) - 1]} {incr i} {
	if {$stroke($i) != $stroke([expr $i+1])} {
	    set coords [concat $coords $stroke([expr $i+1])]
	}
    }
    
    # Next pass: remove points that are close to each other.
    set coords [::CanvasDraw::StripClosePoints $coords 6]
    
    # Next pass: remove points that gives a too small radius or points
    # lying on a straight line.
    set coords [::CanvasDraw::StripExtremeRadius $coords 6 10000]
    return $coords
}

#--- End of stroke tool --------------------------------------------------------

#--- The Paint tool ------------------------------------------------------------

# CanvasDraw::DoPaint --
#
#       Fills item with the foreground color. If 'shift', then transparent.
#       Tell all other clients.
#   
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       shift  makes transparent.
#       
# Results:
#       none

proc ::CanvasDraw::DoPaint {w x y {shift 0}} {
    global  prefs kRad2Grad

    set wtop [::UI::GetToplevelNS $w]
    upvar ::WB::${wtop}::state state

    Debug 2 "DoPaint:: w=$w, x=$x, y=$y, shift=$shift"
    
    # Find items overlapping x and y. Doesn't work for transparent items.
    #set ids [$w find overlapping $x $y $x $y]
    # This is perhaps not an efficient solution.
    set ids [$w find all]

    foreach id $ids {
	set theType [$w type $id]

	# Sort out uninteresting items early.
	if {![string equal $theType "rectangle"] &&   \
	  ![string equal $theType "oval"] &&  \
	  ![string equal $theType "arc"]} {
	    continue
	}
	
	# Must be in bounding box.
	set theBbox [$w bbox $id]

	if {$x >= [lindex $theBbox 0] && $x <= [lindex $theBbox 2] &&  \
	  $y >= [lindex $theBbox 1] && $y <= [lindex $theBbox 3]} {
	    # OK, inside!
	    # Allow privacy.
	    set theItno [::CanvasUtils::GetUtag $w $id]
	    if {$theItno == ""} {
		continue
	    }
	    set cmd ""
	    if {[string equal $theType "rectangle"]} {
		if {$shift == 0} {
		    set cmd [list itemconfigure $theItno -fill $state(fgCol)]
		} elseif {$shift == 1} {
		    set cmd [list itemconfigure $theItno -fill {}]
		}
	    } elseif {[string equal $theType "oval"]} {
		
		# Use ellipsis equation (1 = x^2/a^2 + y^2/b^2) to find if inside.
		set centx [expr ([lindex $theBbox 0] + [lindex $theBbox 2])/2.0]
		set centy [expr ([lindex $theBbox 1] + [lindex $theBbox 3])/2.0]
		set a [expr abs($centx - [lindex $theBbox 0])]
		set b [expr abs($centy - [lindex $theBbox 1])]
		if {[expr ($x-$centx)*($x-$centx)/($a*$a) +   \
		  ($y-$centy)*($y-$centy)/($b*$b)] <= 1} {
		    # Inside!
		    if {$shift == 0} {
			set cmd [list itemconfigure $theItno -fill $state(fgCol)]
		    } elseif {$shift == 1} {
			set cmd [list itemconfigure $theItno -fill {}]
		    }
		}
	    } elseif {[string equal $theType "arc"]} {
		set theCoords [$w coords $id]
		set cx [expr ([lindex $theCoords 0] + [lindex $theCoords 2])/2.0]
		set cy [expr ([lindex $theCoords 1] + [lindex $theCoords 3])/2.0]
		set r [expr abs([lindex $theCoords 2] - [lindex $theCoords 0])/2.0]
		set rp [expr hypot($x - $cx, $y - $cy)]
		
		# Sort out point outside the radius of the arc.
		if {$rp > $r} {
		    continue
		}
		set phi [expr $kRad2Grad * atan2(-($y - $cy),$x - $cx)]
		if {$phi < 0} {
		    set phi [expr $phi + 360]
		}
		set startPhi [$w itemcget $id -start]
		set extentPhi [$w itemcget $id -extent]
		if {$extentPhi >= 0} {
		    set phi1 $startPhi
		    set phi2 [expr $startPhi + $extentPhi]
		} else {
		    set phi1 [expr $startPhi + $extentPhi]
		    set phi2 $startPhi
		}
		
		# Put branch cut at 360 degrees. Count CCW.
		if {$phi1 > 360} {
		    set phi1 [expr $phi1 - 360]
		} elseif {$phi1 < 0} {
		    set phi1 [expr $phi1 + 360]
		}
		if {$phi2 > 360} {
		    set phi2 [expr $phi2 - 360]
		} elseif {$phi2 < 0} {
		    set phi2 [expr $phi2 + 360]
		}
		set inside 0
		
		# Keep track of if the arc covers the branch cut or not.
		if {$phi2 > $phi1} {
		    if {$phi >= $phi1 && $phi <= $phi2} {
			set inside 1
		    }
		} else {
		    if {$phi >= $phi1 || $phi <= $phi2} {
			set inside 1
		    }
		}
		if {$inside} {
		    if {$shift == 0} {
			set cmd [list itemconfigure $theItno -fill $state(fgCol)]
		    } elseif {$shift == 1} {
			set cmd [list itemconfigure $theItno -fill {}]
		    }
		}
	    }
	    if {[string length $cmd] > 0} {
		set undocmd [list itemconfigure $theItno  \
		  -fill [$w itemcget $theItno -fill]]
		set redo [list ::CanvasUtils::Command $wtop $cmd]
		set undo [list ::CanvasUtils::Command $wtop $undocmd]
		eval $redo
		undo::add [::WB::GetUndoToken $wtop] $undo $redo	    
	    }
	}
    }

}

#--- End of paint tool ---------------------------------------------------------

#--- The rotate tool -----------------------------------------------------------

# CanvasDraw::InitRotateItem --
#
#       Inits a rotate operation.
#   
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       
# Results:
#       none

proc ::CanvasDraw::InitRotateItem {w x y} {
    
    variable rotDrag

    # Only one single selected item is allowed to be rotated.
    set id [$w find withtag selected]
    if {[llength $id] != 1} {
	return
    }
    set it [::CanvasUtils::GetUtag $w $id]
    if {[string length $it] == 0} {
	return
    }
    
    # Certain item types cannot be rotated.
    set rotDrag(type) [$w type $id]
    if {[string equal $rotDrag(type) "text"]} {
	unset rotDrag
	return
    }
    
    # Get center of gravity and cache undo command.
    if {[string equal $rotDrag(type) "arc"]} {
	set colist [$w coords $id]
	set rotDrag(arcStart) [$w itemcget $id -start]
	set rotDrag(undocmd) [list itemconfigure $it -start $rotDrag(arcStart)]
    } else {
	set colist [$w bbox $id]
	set rotDrag(undocmd) [concat coords $it [$w coords $it]]
    }
    set rotDrag(cgX) [expr ([lindex $colist 0] + [lindex $colist 2])/2.0]
    set rotDrag(cgY) [expr ([lindex $colist 1] + [lindex $colist 3])/2.0]
    set rotDrag(anchorX) $x
    set rotDrag(anchorY) $y
    set rotDrag(id) $id
    set rotDrag(itno) $it
    set rotDrag(lastAng) 0.0
    
    # Save coordinates relative cg.
    set theCoords [$w coords $id]
    set rotDrag(n) [expr [llength $theCoords]/2]    ;# Number of points.
    set i 0
    foreach {cx cy} $theCoords {
	set rotDrag(x,$i) [expr $cx - $rotDrag(cgX)]
	set rotDrag(y,$i) [expr $cy - $rotDrag(cgY)]
	incr i
    }
    
    # Observe coordinate system.
    set rotDrag(startAng) [expr atan2($y - $rotDrag(cgY),$x - $rotDrag(cgX)) ]
}

# CanvasDraw::DoRotateItem --
#
#       Rotates an item.
#   
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       shift  constrains rotation.
#       
# Results:
#       none

proc ::CanvasDraw::DoRotateItem {w x y {shift 0}} {
    global  kPI kRad2Grad prefs
    
    variable rotDrag

    if {![info exists rotDrag]} {
	return
    }
    set newAng [expr atan2($y - $rotDrag(cgY),$x - $rotDrag(cgX))]
    set deltaAng [expr $rotDrag(startAng) - $newAng]
    set new {}
    set angRot 0.0
    
    # Certain items are only rotated in 90 degree intervals, other continuously.
    switch -- $rotDrag(type) {
	arc - line - polygon {
	    if {$shift} {
		if {!$prefs(45)} {
		    set angRot [expr ($kPI/2.0) * round($deltaAng/($kPI/2.0))]
		} elseif {$prefs(45)} {
		    set angRot [expr ($kPI/4.0) * round($deltaAng/($kPI/4.0))]
		}
	    } else {
		set angRot $deltaAng
	    }
	}
	rectangle - oval {
	
	    # Find the rotated angle in steps of 90 degrees.
	    set angRot [expr ($kPI/2.0) * round($deltaAng/($kPI/2.0))]
	}
    }
    
    # Find the new coordinates; arc: only start angle.
    if {[expr abs($angRot)] > 1e-4 ||   \
      [expr abs($rotDrag(lastAng) - $angRot)] > 1e-4} {
	set sinAng [expr sin($angRot)]
	set cosAng [expr cos($angRot)]
	if {[string equal $rotDrag(type) "arc"]} {
	    
	    # Different coordinate system for arcs...and units...
	    $w itemconfigure $rotDrag(id) -start   \
	      [expr $kRad2Grad * $angRot + $rotDrag(arcStart)]
	} else {
	    # Compute new coordinates from the original ones.
	    for {set i 0} {$i < $rotDrag(n)} {incr i} {
		lappend new [expr $rotDrag(cgX) + $cosAng * $rotDrag(x,$i) +  \
		  $sinAng * $rotDrag(y,$i)]
		lappend new [expr $rotDrag(cgY) - $sinAng * $rotDrag(x,$i) +  \
		  $cosAng * $rotDrag(y,$i)]
	    }
	    eval $w coords $rotDrag(id) $new
	}
    }
    set rotDrag(lastAng) $angRot
}

# CanvasDraw::FinalizeRotate --
#
#       Finalizes the rotation operation. Tells all other clients.
#   
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       
# Results:
#       none

proc ::CanvasDraw::FinalizeRotate {w x y} {
    global  kRad2Grad        
    variable rotDrag

    if {![info exists rotDrag]} {
	return
    }
    set wtop [::UI::GetToplevelNS $w]
    
    # Move all markers along.
    $w delete id$rotDrag(id)
    MarkBbox $w 0 $rotDrag(id)
    if {[string equal $rotDrag(type) "arc"]} {
	
	# Get new start angle.
	set cmd [list itemconfigure $rotDrag(itno) -start   \
	      [$w itemcget $rotDrag(itno) -start]]
    } else {
	# Or update all coordinates.
	set cmd [concat coords $rotDrag(itno) [$w coords $rotDrag(id)]]
    }    
    set undocmd $rotDrag(undocmd)
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]
    ::CanvasUtils::Command $wtop $cmd remote
    undo::add [::WB::GetUndoToken $wtop] $undo $redo	    
    catch {unset rotDrag}
}

#--- End of rotate tool --------------------------------------------------------

# CanvasDraw::DeleteCurrent --
# 
#       Bindings to the 'std' tag.

proc ::CanvasDraw::DeleteCurrent {w x y} {

    ::CanvasDraw::DeleteItem $w $x $y
}

proc ::CanvasDraw::DeleteCurrentWithUndo {w x y {undoCmdList {}}} {
    
    set utag [::CanvasUtils::GetUtag $w current]
    if {$utag == ""} {
	return
    }
    set selected [expr [lsearch [$w gettags current] "selected"] >= 0 ? 1 : 0]
    set cmd [list delete $utag]
    set wtop [::UI::GetToplevelNS $w]
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    set undo [list ::CanvasUtils::CommandList $wtop $undoCmdList]
    eval $redo
    if {[llength $undoCmdList]} {
	undo::add [::WB::GetUndoToken $wtop] $undo $redo
    }
}
# CanvasDraw::DeleteItem --
#
#       Delete item in canvas. Notifies all other clients.
#   
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       id     can be "current", "selected", or just an id number.
#       where    "all": erase this canvas and all others.
#                "remote": erase only client canvases.
#                "local": erase only own canvas.
#       
# Results:
#       none

proc ::CanvasDraw::DeleteItem {w x y {id current} {where all}} {

    Debug 4 "DeleteItem:: w=$w, x=$x, y=$y, id=$id, where=$where"

    set wtop [::UI::GetToplevelNS $w]
    
    # List of canvas commands without widget path.
    set cmdList {}
    
    # List of complete commands.
    set redoCmdList {}
    set undoCmdList {}
    
    set utagList {}
    set needDeselect 0
    
    # Get item's utag in a list.
    switch -- $id {
	current {
	    set utag [::CanvasUtils::GetUtag $w current]
	    if {[string length $utag] > 0} {
		lappend utagList $utag
	    }
	}
	selected {
	
	    # First, get canvas objects with tag 'selected'.	
	    foreach id [$w find withtag selected] {
		set utag [::CanvasUtils::GetUtag $w $id]
		if {[string length $utag] > 0} {
		    lappend utagList $utag
		}
	    }
	    set needDeselect 1
	}
	window {	    
	    # Here we may have code to call custom handlers?	    
	}
	default {
	
	    # 'id' is an actual item number.
	    set utag [::CanvasUtils::GetUtag $w $id]
	    if {[string length $utag] > 0} {
		lappend utagList $utag
	    }
	}
    }
    if {[llength $utagList] == 0} {
	return
    }
    
    foreach utag $utagList {
	lappend cmdList [list delete $utag]
	if {[string equal [$w type $utag] "window"]} {
	    set win [$w itemcget $utag -window]
	    lappend redoCmdList [list destroy $win]		
	}
	lappend undoCmdList [::CanvasUtils::GetUndoCommand $wtop  \
	  [list delete $utag]]
    }
    if {[llength $cmdList] == 0} {
	return
    }
    
    # Manufacture complete commands.
    set canRedo [list ::CanvasUtils::CommandList $wtop $cmdList $where]
    set redo [list ::CanvasDraw::EvalCommandList  \
      [concat [list $canRedo] $redoCmdList]]
    set undo [list ::CanvasDraw::EvalCommandList $undoCmdList]

    eval $redo
    undo::add [::WB::GetUndoToken $wtop] $undo $redo
    
    # Remove select marks.
    if {$needDeselect} {
	::CanvasCmd::DeselectAll $wtop
    }
}

# CanvasDraw::DeleteFrame --
# 
#       Generic binding for deleting a frame that typically contains
#       something from a plugin. 
#       Note that this is trigger by the frame's event handler and not the 
#       canvas!
#       
# Arguments:
#       w      the frame widget.
#       x,y    the mouse coordinates.
#       where    "all": erase this canvas and all others.
#                "remote": erase only client canvases.
#                "local": erase only own canvas.
#       
# Results:
#       none

proc ::CanvasDraw::DeleteFrame {wcan wframe x y {where all}} {
    
    ::Debug 2 "::CanvasDraw::DeleteFrame wframe=$wframe, x=$x, y=$y"
    
    # Fix x and y (frame to canvas coordinates).
    set x [$wcan canvasx [expr [winfo x $wframe] + $x]]
    set y [$wcan canvasx [expr [winfo y $wframe] + $y]]
    set wtop [::UI::GetToplevelNS $wcan]
    set cmdList {}
    set canUndoList {}
    set undoCmdList {}
    
    # BAD solution...
    set id [lindex [$wcan find closest $x $y 3] 0]
    set utag [::CanvasUtils::GetUtag $wcan $id]
    if {$utag == ""} {
	return
    }
    
    # Delete both the window item and the window (with subwindows).
    lappend cmdList [list delete $utag]
    set extraCmd [list destroy $wframe]
    
    set redo [list ::CanvasUtils::CommandList $wtop $cmdList $where]
    set redo [list ::CanvasDraw::EvalCommandList [list $redo $extraCmd]]
        
    # We need to reconstruct how it was imported.
    set undo [::CanvasUtils::GetUndoCommand $wtop [list delete $utag]]
    eval $redo
    undo::add [::WB::GetUndoToken $wtop] $undo $redo
}

# CanvasDraw::DeleteWindow --
# 
#       Generic binding for deleting a window that typically contains
#       something from a plugin. 
#       
# Arguments:
#       w      the frame widget.
#       x,y    the mouse coordinates.
#       where    "all": erase this canvas and all others.
#                "remote": erase only client canvases.
#                "local": erase only own canvas.
#       
# Results:
#       none

proc ::CanvasDraw::DeleteWindow {wcan win x y {where all}} {
    
    ::Debug 2 "::CanvasDraw::DeleteWindow win=$win, x=$x, y=$y"
    
    # Fix x and y (frame to canvas coordinates).
    set x [$wcan canvasx [expr [winfo x $win] + $x]]
    set y [$wcan canvasx [expr [winfo y $win] + $y]]
    set wtop [::UI::GetToplevelNS $wcan]
    set cmdList {}
    set canUndoList {}
    set undoCmdList {}
    
    # BAD solution...
    set id [lindex [$wcan find closest $x $y 3] 0]
    set utag [::CanvasUtils::GetUtag $wcan $id]
    if {$utag == ""} {
	return
    }
    
    # Delete both the window item and the window (with subwindows).
    lappend cmdList [list delete $utag]
    set extraCmd [list destroy $win]
    
    set redo [list ::CanvasUtils::CommandList $wtop $cmdList $where]
    set redo [list ::CanvasDraw::EvalCommandList [list $redo $extraCmd]]
        
    # We need to reconstruct how it was imported.
    set undo [::CanvasUtils::GetUndoCommand $wtop [list delete $utag]]
    eval $redo
    undo::add [::WB::GetUndoToken $wtop] $undo $redo
}

proc ::CanvasDraw::PointButton {w x y {modifier {}}} {
    
    if {[string equal $modifier "shift"]} {
	::CanvasDraw::MarkBbox $w 1
    } else {
	::CanvasDraw::MarkBbox $w 0
    }
}

# CanvasDraw::MarkBbox --
#
#        Makes four tiny squares at the corners of the specified items.
#       
# Arguments:
#       w           the canvas widget.
#       shift       If 'shift', then just select item, else deselect all 
#                   other first.
#       which       can either be "current", another tag, or an id.
#       
# Results:
#       none

proc ::CanvasDraw::MarkBbox {w shift {which current}} {
    global  prefs kGrad2Rad
    
    Debug 3 "MarkBbox:: w=$w, shift=$shift, which=$which"

    set wtop [::UI::GetToplevelNS $w]
    
    # If no shift key, deselect all.
    if {$shift == 0} {
	::CanvasCmd::DeselectAll $wtop
    }
    set id [$w find withtag $which]
    if {$id == ""} {
	return
    }
    set utag [::CanvasUtils::GetUtag $w $which]
    if {$utag == ""} {
	return
    }
    if {[lsearch [$w gettags $id] "std"] < 0} {
	return
    }
    
    # If already selected, and shift clicked, deselect.
    if {$shift == 1} {
	if {[::CanvasDraw::IsSelected $w $id]} {
	    $w delete tbbox&&id:${id}
	    $w dtag $id selected
	    return
	}
    }    
    ::CanvasDraw::SelectItem $w $which
    focus $w
    
    # Enable cut and paste etc.
    ::UI::FixMenusWhenSelection $w
    
    # Testing..
    selection own -command [list ::CanvasDraw::LostSelection $wtop] $w
}

proc ::CanvasDraw::SelectItem {w which} {
    
    # Add tag 'selected' to the selected item. Indicate to which item id
    # a marker belongs with adding a tag 'id$id'.
    set type [$w type $which]
    $w addtag "selected" withtag $which
    set id [$w find withtag $which]
    set tmark [list tbbox $type id:${id}]
    ::CanvasDraw::DrawItemSelection $w $which $tmark
}

proc ::CanvasDraw::DeselectItem {w which} {
    
    set id [$w find withtag $which]
    $w delete tbbox&&id:${id}
    $w dtag $id selected

    # menus
    ::UI::FixMenusWhenSelection $w
}

proc ::CanvasDraw::IsSelected {w which} {
    
    return [expr [lsearch [$w gettags $which] "selected"] < 0 ? 0 : 1]
}

proc ::CanvasDraw::AnySelected {w} {
    
    return [expr {[$w find withtag "selected"] == ""} ? 0 : 1]
}

# CanvasDraw::DrawItemSelection --
# 
#       Does the actual drawing of any selection.

proc ::CanvasDraw::DrawItemSelection {w which tmark} {
    global  prefs kGrad2Rad
    
    set a $prefs(aBBox)
    set type [$w type $which]
    set bbox [$w bbox $which]
    set id   [$w find withtag $which]

    # If mark the bounding box. Also for all "regular" shapes.
    
    if {$prefs(bboxOrCoords) || ($type == "oval") || ($type == "text")  \
      || ($type == "rectangle") || ($type == "image")} {

	foreach {x1 y1 x2 y2} $bbox break
	$w create rectangle [expr $x1-$a] [expr $y1-$a] [expr $x1+$a] [expr $y1+$a] \
	  -tags $tmark -fill white
	$w create rectangle [expr $x1-$a] [expr $y2-$a] [expr $x1+$a] [expr $y2+$a] \
	  -tags $tmark -fill white
	$w create rectangle [expr $x2-$a] [expr $y1-$a] [expr $x2+$a] [expr $y1+$a] \
	  -tags $tmark -fill white
	$w create rectangle [expr $x2-$a] [expr $y2-$a] [expr $x2+$a] [expr $y2+$a] \
	  -tags $tmark -fill white
    } else {
	
	set coords [$w coords $which]
	if {[string length $coords] == 0} {
	    return
	}
	set n [llength $coords]
	
	# For an arc item, mark start and stop endpoints.
	# Beware, mixes of two coordinate systems, y <-> -y.
	if {[string equal $type "arc"]} {
	    if {$n != 4} {
		return
	    }
	    foreach {x1 y1 x2 y2} $coords break
	    set r [expr abs(($x1 - $x2)/2.0)]
	    set cx [expr ($x1 + $x2)/2.0]
	    set cy [expr ($y1 + $y2)/2.0]
	    set startAng [$w itemcget $id -start]
	    set extentAng [$w itemcget $id -extent]
	    set xstart [expr $cx + $r * cos($kGrad2Rad * $startAng)]
	    set ystart [expr $cy - $r * sin($kGrad2Rad * $startAng)]
	    set xfin [expr $cx + $r * cos($kGrad2Rad * ($startAng + $extentAng))]
	    set yfin [expr $cy - $r * sin($kGrad2Rad * ($startAng + $extentAng))]
	    $w create rectangle [expr $xstart-$a] [expr $ystart-$a]   \
	      [expr $xstart+$a] [expr $ystart+$a] -tags $tmark -fill white
	    $w create rectangle [expr $xfin-$a] [expr $yfin-$a]   \
	      [expr $xfin+$a] [expr $yfin+$a] -tags $tmark -fill white
	    
	} else {
	    
	    # Mark each coordinate. {x0 y0 x1 y1 ... }
	    foreach {x y} $coords {
		$w create rectangle [expr $x-$a] [expr $y-$a] [expr $x+$a] [expr $y+$a] \
		  -tags $tmark -fill white
	    }
	}
    }
}

# CanvasDraw::LostSelection --
#
#       Lost selection to other window. Deselect only if same toplevel.

proc ::CanvasDraw::LostSelection {wtop} {
    
    set wtopReal [::UI::GetToplevel $wtop]
    if {$wtopReal == [selection own]} {
	::CanvasCmd::DeselectAll $wtop
    }
}

proc ::CanvasDraw::SyncMarks {wtop} {

    set wCan [::WB::GetCanvasFromWtop $wtop]
    $wCan delete withtag tbbox
    foreach id [$wCan find withtag "selected"] {
	::CanvasDraw::MarkBbox $wCan 1 $id	
    }
}
    
#--- Various assistant procedures ----------------------------------------------

# CanvasDraw::ConstrainedDrag --
#
#       Compute new x and y coordinates constrained to 90 or 45 degree
#       intervals.
#       
# Arguments:
#       xanch,yanch      the anchor coordinates.
#       x,y    the mouse coordinates.
#       
# Results:
#       List of new x and y coordinates.

proc ::CanvasDraw::ConstrainedDrag {x y xanch yanch} {
    global  prefs kTan225 kTan675
    
    # Constrain movements to 90 degree intervals.
    if {!$prefs(45)} {
	if {[expr abs($x - $xanch)] > [expr abs($y - $yanch)]} {
	    set y $yanch
	} else {
	    set x $xanch
	}
	return [list $x $y]
    } else {
	
	# 45 degree intervals.
	set deltax [expr $x - $xanch]
	set deltay [expr $y - $yanch]
	if {[expr abs($deltay/($deltax + 0.5))] <= $kTan225} {
	    
	    # constrain to x-axis.
	    set y $yanch
	    return [list $x $y]
	} elseif {[expr abs($deltay/($deltax + 0.5))] >= $kTan675} {
	    
	    # constrain to y-axis.
	    set x $xanch
	    return [list $x $y]
	} else { 
	
	    # Do the same analysis in the coordinate system rotated 45 degree CCW.
	    set deltaxprim [expr 1./sqrt(2.0) * ($deltax + $deltay)]
	    set deltayprim [expr 1./sqrt(2.0) * (-$deltax + $deltay)]
	    if {[expr abs($deltayprim/($deltaxprim + 0.5))] <= $kTan225} {
		
		# constrain to x'-axis.
		set x [expr $xanch + ($deltax + $deltay)/2.0]
		set y [expr $yanch + $x - $xanch]
	    } else {
		
		# constrain to y'-axis.
		set y [expr $yanch + (-$deltax + $deltay)/2.0]
		set x [expr $xanch - $y + $yanch]
	    }
	    return [list $x $y]
	}
    }
}

# CanvasDraw::MakeSpeechBubble, SpeechBubbleCmd --
#
#       Makes and draws a speech bubble for a text item.

proc ::CanvasDraw::MakeSpeechBubble {w id} {
    
    set wtop [::UI::GetToplevelNS $w]
    set bbox [$w bbox $id]
    set utagtext [::CanvasUtils::GetUtag $w $id]
    foreach {utag redocmd} [::CanvasDraw::SpeechBubbleCmd $w $bbox] break
    set undocmd "delete $utag"
    set cmdLower [list lower $utag $utagtext]
    
    set redo [list ::CanvasUtils::CommandList $wtop [list $redocmd $cmdLower]]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]
    eval $redo
    undo::add [::WB::GetUndoToken $wtop] $undo $redo
}

proc ::CanvasDraw::SpeechBubbleCmd {w bbox args} {
    
    set a 8
    set b 12
    set c 40
    set d 20
    foreach {left top right bottom} $bbox break
    set midw [expr ($right+$left)/2.0]
    set midh [expr ($bottom+$top)/2.0]
    set coords [list  \
      [expr $left-$a] [expr $top-$a]  \
      $midw [expr $top-$b]  \
      [expr $right+$a] [expr $top-$a]  \
      [expr $right+$b] $midh  \
      [expr $right+$a] [expr $bottom+$a]  \
      [expr $right+$a] [expr $bottom+$c]  \
      [expr $right+$a] [expr $bottom+$c]  \
      [expr $right-$d+10] [expr $bottom+$a]  \
      [expr $right-$d] [expr $bottom+$a]  \
      $midw [expr $bottom+$b]  \
      [expr $left-$a] [expr $bottom+$a]  \
      [expr $left-$b] $midh  \
    ]
    array set optsArr {-outline black -fill white -smooth 1 -splinesteps 10}
    array set optsArr $args
    set utag [::CanvasUtils::NewUtag]
    set cmd "create polygon $coords -tags {std polygon $utag} [array get optsArr]"
    return [list $utag $cmd]
}

# CanvasDraw::StripClosePoints --
#
#       Removes points that are closer than 'd'.
#
# Arguments:
#       coords      list of coordinates {x0 y0 x1 y1 ...}
#       dmax        maximum allowed distance
#       
# Results:
#       list of new coordinates

proc ::CanvasDraw::StripClosePoints {coords dmax} {
  
    set len [llength $coords]
    if {$len < 6} {
	return $coords
    }
    set tmp [lrange $coords 0 1]
    for {set i1 0; set i2 2} {$i2 < $len} { } {
	foreach {x1 y1} [lrange $coords $i1 [expr $i1+1]] break
	foreach {x2 y2} [lrange $coords $i2 [expr $i2+1]] break
	set d [expr hypot($x2-$x1, $y2-$y1)]
	
	if {$i2 < [expr $len - 2]} {
	    
	    # To accept or not to accept.
	    if {$d < $dmax} {
		incr i2 2
	    } else {
		lappend tmp $x2 $y2
		set i1 $i2
		incr i2 2
	    }
	} else {
	    
	    # Last point.
	    if {$d < $dmax} {
		set tmp [lreplace $tmp end-1 end $x2 $y2]
	    } else {
		lappend tmp $x2 $y2
	    }
	    incr i2 2
	}
    }
    return $tmp
}

proc ::CanvasDraw::GetDistList {coords} {
    
    set dlist {}
    set len [llength $coords]
    for {set i1 0; set i2 2} {$i2 < $len} {incr i1 2; incr i2 2} {
	foreach {x1 y1} [lrange $coords $i1 [expr $i1+1]] break
	foreach {x2 y2} [lrange $coords $i2 [expr $i2+1]] break
	lappend dlist [expr hypot($x2-$x1, $y2-$y1)]
    }
    return $dlist
}

# CanvasDraw::StripExtremeRadius --
#
#       Strip points that form triplets with radius outside 'rmin' and 'rmax'.
#
# Arguments:
#       coords      list of coordinates {x0 y0 x1 y1 ...}
#       rmin
#       rmax
#       
# Results:
#       list of new coordinates

proc ::CanvasDraw::StripExtremeRadius {coords rmin rmax} {
    
    set len [llength $coords]
    if {$len < 8} {
	return $coords
    }
    set tmp [lrange $coords 0 1]
    for {set i1 0; set i2 2; set i3 4} {$i3 < $len} { } {
	foreach {x1 y1} [lrange $coords $i1 [expr $i1+1]] break
	foreach {x2 y2} [lrange $coords $i2 [expr $i2+1]] break
	foreach {x3 y3} [lrange $coords $i3 [expr $i3+1]] break
	set r [::CanvasDraw::ThreePointRadius [list $x1 $y1 $x2 $y2 $x3 $y3]]
	
	if {$i2 < [expr $len - 4]} {
	    
	    # To accept or not to accept.
	    if {($r > $rmax) || ($r < $rmin)} {
		incr i2 2
		incr i3 2
	    } else {
		lappend tmp $x2 $y2
		set i1 $i2
		set i2 $i3
		incr i3 2
	    }
	} else {

	    # Last point.
	    set tmp [concat $tmp [lrange $coords end-1 end]]
	    incr i3 2
	}
    }
    return $tmp
}

proc ::CanvasDraw::GetRadiusList {coords} {
    
    set rlist {}
    set imax [expr [llength $coords] - 4]
    for {set i 0} {$i < $imax} {incr i 2} {
	lappend rlist [::CanvasDraw::ThreePointRadius  \
	  [lrange $coords $i [expr $i + 5]]]
    }
    return $rlist
}

# CanvasDraw::ThreePointRadius --
#
#       Computes the radius of a circle that goes through three nonidentical
#       points.
#
# Arguments:
#       p           list {x1 y1 x2 y2 x3 y3}  of three points
#       
# Results:
#       radius

proc ::CanvasDraw::ThreePointRadius {p} {
    
    foreach {x1 y1 x2 y2 x3 y3} $p break
    set a [expr $x1 - $x2]
    set b [expr $y1 - $y2]
    set c [expr $x1 - $x3]
    set d [expr $y1 - $y3]
    set e [expr 0.5 * ($x1*$x1 + $y1*$y1 - ($x2*$x2 + $y2*$y2))]
    set f [expr 0.5 * ($x1*$x1 + $y1*$y1 - ($x3*$x3 + $y3*$y3))]
    set det [expr $a*$d - $b*$c]
    if {[expr abs($det)] < 1e-16} {
	
	# Straight line.
	return 1e+16
    }
    set rx [expr ($d*$e - $b*$f)/$det]
    set ry [expr ($a*$f - $c*$e)/$det]
    set dx [expr $rx - $x1]
    set dy [expr $ry - $y1]
    return [expr sqrt($dx*$dx + $dy*$dy)]
}

# CanvasDraw::EvalCommandList --
#
#       A utility function to evaluate more than a single command.
#       Useful for the undo/redo implementation.

proc ::CanvasDraw::EvalCommandList {cmdList} {
    
    foreach cmd $cmdList {
	eval $cmd
    }
}

#-------------------------------------------------------------------------------