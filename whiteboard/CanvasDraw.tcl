#  CanvasDraw.tcl ---
#  
#      This file is part of The Coccinella application. It implements the
#      drawings commands associated with the tools.
#      
#  Copyright (c) 2000-2005  Mats Bengtsson
#  
# $Id: CanvasDraw.tcl,v 1.17 2005-10-15 07:03:35 matben Exp $

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
#                   
#  Other tags:
#       locked      used for locked items
#       
#  Temporary tags:
#       _move       temporary tag for moving items
#       _ghostrect
#       _selectedwindow
#       _polylines

package provide CanvasDraw 1.0

namespace eval ::CanvasDraw:: {}

#--- The 'move' tool procedures ------------------------------------------------

# CanvasDraw::InitMoveSelected, DragMoveSelected, FinalMoveSelected --
# 
#       Moves all selected items.

proc ::CanvasDraw::InitMoveSelected {wcan x y} {
    variable moveArr
    
    set selected [$wcan find withtag selected&&!locked]
    if {[llength $selected] == 0} {
	return
    }
    if {[HitMovableTBBox $wcan $x $y]} {
	return
    }
    $wcan dtag _move
    $wcan addtag _move withtag selected&&!locked
    set moveArr(x)  $x
    set moveArr(y)  $y
    set moveArr(x0) $x
    set moveArr(y0) $y
    set moveArr(bindType) selected
    set moveArr(type) selected
    set moveArr(selected) $selected
    foreach id $selected {
	set moveArr(coords0,$id) [$wcan coords $id]
    }
}

proc ::CanvasDraw::DragMoveSelected {wcan x y {modifier {}}} {
    variable moveArr
    
    set selected [$wcan find withtag _move]
    if {[llength $selected] == 0} {
	return
    }
    if {![string equal $moveArr(bindType) "selected"]} {
	return
    }
    
    # @@@ These to interfere for 45degree constraints.
    lassign [ToScroll $wcan _move $moveArr(x) $moveArr(y) $x $y] x y
    if {[string equal $modifier "shift"]} {
	lassign [GetConstrainedXY $x $y] x y
    }
    set dx [expr {$x - $moveArr(x)}]
    set dy [expr {$y - $moveArr(y)}]
    $wcan move _move $dx $dy
    $wcan move tbbox&&!locked $dx $dy
    set moveArr(x) $x
    set moveArr(y) $y
}

proc ::CanvasDraw::FinalMoveSelected {wcan x y} {
    variable moveArr
    
    # Protect this from beeing trigged when moving individual points.
    set selected [$wcan find withtag _move]
    if {$selected == {}} {
	return
    }
    if {![info exists moveArr]} {
	return
    }
    if {![string equal $moveArr(bindType) "selected"]} {
	return
    }
    
    # Have moved a bunch of ordinary items.
    # Need to get the actual, constrained, coordinates and not the mouses.
    set x $moveArr(x)
    set y $moveArr(y)
    set dx [expr {$x - $moveArr(x0)}]
    set dy [expr {$y - $moveArr(y0)}]
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
		lassign $moveArr(coords0,$id) x0 y0
		set x [expr {$x0 + $dx}]
		set y [expr {$y0 + $dy}]
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
    set w [winfo toplevel $wcan]
    set redo [list ::CanvasUtils::CommandList $w $cmdList]
    set undo [list ::CanvasUtils::CommandList $w $cmdUndoList]
    eval $redo remote
    undo::add [::WB::GetUndoToken $w] $undo $redo    
    
    $wcan dtag _move
    unset -nocomplain moveArr
}

# CanvasDraw::InitMoveCurrent, DragMoveCurrent, FinalMoveCurrent  --
# 
#       Moves 'current' item.

proc ::CanvasDraw::InitMoveCurrent {wcan x y} {
    variable moveArr
    
    set selected [$wcan find withtag selected&&!locked]
    if {[llength $selected] > 0} {
	return
    }
    set id [$wcan find withtag current]
    set moveArr(x) $x
    set moveArr(y) $y
    set moveArr(x0) $x
    set moveArr(y0) $y
    set moveArr(id) $id
    set moveArr(coords0,$id) [$wcan coords $id]
    set moveArr(bindType) std
    set moveArr(type) [$wcan type $id]
}

proc ::CanvasDraw::DragMoveCurrent {wcan x y {modifier {}}} {
    variable moveArr
    
    set selected [$wcan find withtag selected&&!locked]
    if {[llength $selected] > 0} {
	return
    }
    lassign [ToScroll $wcan $moveArr(id) $moveArr(x) $moveArr(y) $x $y] x y
    if {[string equal $modifier "shift"]} {
	lassign [GetConstrainedXY $x $y] x y
    }
    set dx [expr {$x - $moveArr(x)}]
    set dy [expr {$y - $moveArr(y)}]
    $wcan move $moveArr(id) $dx $dy
    set moveArr(x) $x
    set moveArr(y) $y
}

proc ::CanvasDraw::FinalMoveCurrent {wcan x y} {
    variable moveArr
    
    set selected [$wcan find withtag selected&&!locked]
    if {$selected != {}} {
	return
    }
    if {![info exists moveArr]} {
	return
    }

    # Need to get the actual, constrained, coordinates and not the mouses.
    set x $moveArr(x)
    set y $moveArr(y)
    set dx [expr {$x - $moveArr(x0)}]
    set dy [expr {$y - $moveArr(y0)}]
    set mdx [expr {-1*$dx}]
    set mdy [expr {-1*$dy}]
    set cmdList {}
    set cmdUndoList {}
    
    set id $moveArr(id)
    set utag [::CanvasUtils::GetUtag $wcan $id]
	
    # Let images use coords instead since more robust if transported.
    switch -- [$wcan type $id] {
	image {
	    
	    # Find new coords.
	    lassign $moveArr(coords0,$id) x0 y0
	    set x [expr {$x0 + $dx}]
	    set y [expr {$y0 + $dy}]
	    lappend cmdList [list coords $utag $x $y]
	    lappend cmdUndoList \
	      [concat coords $utag $moveArr(coords0,$id)]
	}
	default {
	    lappend cmdList [list move $utag $dx $dy]
	    lappend cmdUndoList [list move $utag $mdx $mdy]
	}
    }
    set w [winfo toplevel $wcan]
    set redo [list ::CanvasUtils::CommandList $w $cmdList]
    set undo [list ::CanvasUtils::CommandList $w $cmdUndoList]
    eval $redo remote
    undo::add [::WB::GetUndoToken $w] $undo $redo    
    
    unset -nocomplain moveArr
}

# CanvasDraw::InitMoveRectPoint, DragMoveRectPoint, FinalMoveRectPoint --
# 
#       For rectangle and oval corner points.

proc ::CanvasDraw::InitMoveRectPoint {wcan x y} {
    variable moveArr
    
    if {![HitTBBox $wcan $x $y]} {
	return
    }

    # Moving a marker of a selected item, highlight marker.
    # 'current' must be a marker with tag 'tbbox'.
    set id [$wcan find withtag current]
    $wcan addtag hitBbox withtag $id

    # Find associated id for the actual item. Saved in the tags of the marker.
    if {![regexp {id:([0-9]+)} [$wcan gettags $id] match itemid]} {
	return
    }
    DrawHighlightBox $wcan $itemid $id
    set itemcoords [$wcan coords $itemid]
    set utag [::CanvasUtils::GetUtag $wcan $itemid]

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
  
    set ind [FindClosestCoordsIndex $x $y $longcoo]
    set ptind [expr {$ind/2}]
    
    # Keep only hit corner and the diagonally opposite one.
    set coords [list [lindex $longcoo $ind]  \
      [lindex $longcoo [expr {$ind + 1}]]]
    
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
    set moveArr(coords0) [$wcan coords $id]
    set moveArr(itemcoords0) $coo
    set moveArr(undocmd) [concat coords $utag $itemcoords]
    set moveArr(bindType) tbbox:rect
    set moveArr(type) [$wcan type $itemid]
}

proc ::CanvasDraw::DragMoveRectPoint {wcan x y {modifier {}}} {
    variable moveArr
    
    if {![info exists moveArr]} {
	return
    }
    if {![string equal $moveArr(bindType) "tbbox:rect"]} {
	return
    }
    lassign [ToScroll $wcan $moveArr(itemid) $moveArr(x) $moveArr(y) $x $y] x y
    if {[string equal $modifier "shift"]} {
	lassign [GetConstrainedXY $x $y] x y
    }
    set dx [expr {$x - $moveArr(x)}]
    set dy [expr {$y - $moveArr(y)}]
    set newcoo [lreplace $moveArr(itemcoords0) 0 1 $x $y]
    eval $wcan coords $moveArr(itemid) $newcoo
    $wcan move hitBbox $dx $dy
    $wcan move lightBbox $dx $dy
    set moveArr(x) $x
    set moveArr(y) $y
}

proc ::CanvasDraw::FinalMoveRectPoint {wcan x y} {
    variable moveArr
    
    if {![info exists moveArr]} {
	return
    }
    if {![string equal $moveArr(bindType) "tbbox:rect"]} {
	return
    }
    $wcan delete lightBbox
    $wcan dtag all hitBbox 

    # Move all markers along.
    $wcan delete id$moveArr(itemid)
    MarkBbox $wcan 0 $moveArr(itemid)

    set itemid $moveArr(itemid)
    set utag $moveArr(utag)
    set utag [::CanvasUtils::GetUtag $wcan $itemid]
    set cmd [concat coords $utag [$wcan coords $itemid]]

    set w [winfo toplevel $wcan]
    set redo [list ::CanvasUtils::Command $w $cmd]
    set undo [list ::CanvasUtils::Command $w $moveArr(undocmd)]
    eval $redo remote
    undo::add [::WB::GetUndoToken $w] $undo $redo

    unset -nocomplain moveArr
}

# CanvasDraw::InitMoveArcPoint, DragMoveArcPoint, FinalMoveArcPoint --
#
#       @@@ Pretty buggy!

proc ::CanvasDraw::InitMoveArcPoint {wcan x y} {
    global  kGrad2Rad
    variable moveArr
    
    if {![HitTBBox $wcan $x $y]} {
	return
    }

    # Moving a marker of a selected item, highlight marker.
    # 'current' must be a marker with tag 'tbbox'.
    set id [$wcan find withtag current]
    $wcan addtag hitBbox withtag $id

    set moveArr(x) $x
    set moveArr(y) $y
    set moveArr(x0) $x
    set moveArr(y0) $y
    set moveArr(bindType) tbbox:arc
    set moveArr(type) arc

    # Find associated id for the actual item. Saved in the tags of the marker.
    if {![regexp {id:([0-9]+)} [$wcan gettags $id] match itemid]} {
	return
    }
    DrawHighlightBox $wcan $itemid $id
    set itemcoords [$wcan coords $itemid]
    set utag [::CanvasUtils::GetUtag $wcan $itemid]
    
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
    set r [expr {abs(($x1 - $x2)/2.0)}]
    set cx [expr {($x1 + $x2)/2.0}]
    set cy [expr {($y1 + $y2)/2.0}]
    set moveArr(arcCX) $cx
    set moveArr(arcCY) $cy
    set startAng [$wcan itemcget $itemid -start]
    
    # Put branch cut at +-180!
    if {$startAng > 180} {
	set startAng [expr {$startAng - 360}]
    }
    set extentAng [$wcan itemcget $itemid -extent]
    set xstart [expr {$cx + $r * cos($kGrad2Rad * $startAng)}]
    set ystart [expr {$cy - $r * sin($kGrad2Rad * $startAng)}]
    set xfin [expr {$cx + $r * cos($kGrad2Rad * ($startAng + $extentAng))}]
    set yfin [expr {$cy - $r * sin($kGrad2Rad * ($startAng + $extentAng))}]
    set dstart [expr {hypot($xstart - $x,$ystart - $y)}]
    set dfin [expr {hypot($xfin - $x,$yfin - $y)}]
    set moveArr(arcStart) $startAng
    set moveArr(arcExtent) $extentAng
    set moveArr(arcFin) [expr {$startAng + $extentAng}]
    if {$dstart < $dfin} {
	set moveArr(arcHit) "start"
    } else {
	set moveArr(arcHit) "extent"
    }
    set moveArr(undocmd) [concat itemconfigure $utag \
      -start $startAng -extent $extentAng]
}

proc ::CanvasDraw::DragMoveArcPoint {wcan x y {modifier {}}} {
    global  kGrad2Rad kRad2Grad
    variable moveArr
    
    lassign [ToScroll $wcan $moveArr(itemid) $moveArr(x) $moveArr(y) $x $y] x y
    if {[string equal $modifier "shift"]} {
	lassign [GetConstrainedXY $x $y] x y
    }
    set dx [expr {$x - $moveArr(x)}]
    set dy [expr {$y - $moveArr(y)}]
    set moveArr(x) $x
    set moveArr(y) $y
    
    # Some geometry. We have got the coordinates defining the box.
    set coords $moveArr(coords)
    set itemid $moveArr(itemid)

    lassign $coords x1 y1 x2 y2
    set r [expr {abs(($x1 - $x2)/2.0)}]
    set cx [expr {($x1 + $x2)/2.0}]
    set cy [expr {($y1 + $y2)/2.0}]
    set startAng [$wcan itemcget $itemid -start]
    set extentAng [$wcan itemcget $itemid -extent]
    set xstart [expr {$cx + $r * cos($kGrad2Rad * $startAng)}]
    set ystart [expr {$cy - $r * sin($kGrad2Rad * $startAng)}]
    set xfin [expr {$cx + $r * cos($kGrad2Rad * ($startAng + $extentAng))}]
    set yfin [expr {$cy - $r * sin($kGrad2Rad * ($startAng + $extentAng))}]
    set newAng [expr {$kRad2Grad * atan2($cy - $y,-($cx - $x))}]
    
    # Dragging the 'extent' point or the 'start' point?
    if {[string equal $moveArr(arcHit) "extent"]} { 
	set extentAng [expr {$newAng - $moveArr(arcStart)}]
	
	# Same trick as when drawing it; take care of the branch cut.
	if {$moveArr(arcExtent) - $extentAng > 180} {
	    set extentAng [expr {$extentAng + 360}]
	} elseif {$moveArr(arcExtent) - $extentAng < -180} {
	    set extentAng [expr {$extentAng - 360}]
	}
	set moveArr(arcExtent) $extentAng
	
	# Update angle.
	$wcan itemconfigure $itemid -extent $extentAng
	
	# Move highlight box.
	$wcan move hitBbox [expr {$xfin - $moveArr(arcX)}]   \
	  [expr {$yfin - $moveArr(arcY)}]
	$wcan move lightBbox [expr {$xfin - $moveArr(arcX)}]   \
	  [expr {$yfin - $moveArr(arcY)}]
	set moveArr(arcX) $xfin
	set moveArr(arcY) $yfin
	
    } elseif {[string equal $moveArr(arcHit) "start"]} {

	# Need to update start angle as well as extent angle.
	set newExtentAng [expr {$moveArr(arcFin) - $newAng}]
	# Same trick as when drawing it; take care of the branch cut.
	if {$moveArr(arcExtent) - $newExtentAng > 180} {
	    set newExtentAng [expr {$newExtentAng + 360}]
	} elseif {$moveArr(arcExtent) - $newExtentAng < -180} {
	    set newExtentAng [expr {$newExtentAng - 360}]
	}
	set moveArr(arcExtent) $newExtentAng
	set moveArr(arcStart) $newAng
	$wcan itemconfigure $itemid -start $newAng
	$wcan itemconfigure $itemid -extent $newExtentAng
	
	# Move highlight box.
	$wcan move hitBbox [expr {$xstart - $moveArr(arcX)}]   \
	  [expr {$ystart - $moveArr(arcY)}]
	$wcan move lightBbox [expr {$xstart - $moveArr(arcX)}]   \
	  [expr {$ystart - $moveArr(arcY)}]
	set moveArr(arcX) $xstart
	set moveArr(arcY) $ystart
    }
}

proc ::CanvasDraw::FinalMoveArcPoint {wcan x y} {
    variable moveArr
    
    if {![info exists moveArr]} {
	return
    }
    set id $moveArr(itemid)
    set w [winfo toplevel $wcan]

    $wcan delete lightBbox
    $wcan dtag all hitBbox 

    # The arc item: update both angles.
    set utag $moveArr(utag)
    set cmd [concat itemconfigure $utag -start $moveArr(arcStart)   \
      -extent $moveArr(arcExtent)]
    set redo [list ::CanvasUtils::Command $w $cmd]
    set undo [list ::CanvasUtils::Command $w $moveArr(undocmd)]

    eval $redo remote
    undo::add [::WB::GetUndoToken $w] $undo $redo
    
    unset -nocomplain moveArr
}

# CanvasDraw::InitMovePolyLinePoint, DragMovePolyLinePoint, 
#   FinalMovePolyLinePoint --
# 
#       For moving polygon and line item points.

proc ::CanvasDraw::InitMovePolyLinePoint {wcan x y} {
    variable moveArr
    
    if {![HitTBBox $wcan $x $y]} {
	return
    }

    # Moving a marker of a selected item, highlight marker.
    # 'current' must be a marker with tag 'tbbox'.
    set id [$wcan find withtag current]
    $wcan addtag hitBbox withtag $id

    set moveArr(x) $x
    set moveArr(y) $y
    set moveArr(x0) $x
    set moveArr(y0) $y

    # Find associated id for the actual item. Saved in the tags of the marker.
    if {![regexp {id:([0-9]+)} [$wcan gettags $id] match itemid]} {
	return
    }
    DrawHighlightBox $wcan $itemid $id
    set itemcoords [$wcan coords $itemid]
    set ind [FindClosestCoordsIndex $x $y $itemcoords]

    set moveArr(itemid) $itemid
    set moveArr(coords) $itemcoords
    set moveArr(hitInd) $ind
    set moveArr(type) [$wcan type $itemid]
    set moveArr(bindType) tbbox:polyline
}

proc ::CanvasDraw::DragMovePolyLinePoint {wcan x y {modifier {}}} {
    variable moveArr

    lassign [ToScroll $wcan $moveArr(itemid) $moveArr(x) $moveArr(y) $x $y] x y
    if {[string equal $modifier "shift"]} {
	lassign [GetConstrainedXY $x $y] x y
    }
    set dx [expr {$x - $moveArr(x)}]
    set dy [expr {$y - $moveArr(y)}]
    set moveArr(x) $x
    set moveArr(y) $y
    
    set coords $moveArr(coords)
    set itemid $moveArr(itemid)

    set ind $moveArr(hitInd)
    set newcoo [lreplace $coords $ind [expr {$ind + 1}] $x $y]
    eval $wcan coords $itemid $newcoo
    $wcan move hitBbox $dx $dy
    $wcan move lightBbox $dx $dy
}

proc ::CanvasDraw::FinalMovePolyLinePoint {wcan x y} {
    variable moveArr

    if {![info exists moveArr]} {
	return
    }
    set itemid $moveArr(itemid)
    set coords $moveArr(coords)
    set utag [::CanvasUtils::GetUtag $wcan $itemid]
    set w [winfo toplevel $wcan]
    set itemcoo [$wcan coords $itemid]

    $wcan delete lightBbox
    $wcan dtag all hitBbox 
 
    # If endpoints overlap in line item, make closed polygon.
    # Find out if closed polygon or open line item. If closed, remove duplicate.

    set len [expr {hypot(  \
      [lindex $itemcoo end-1] - [lindex $itemcoo 0],  \
      [lindex $itemcoo end] -  [lindex $itemcoo 1] )}]
    if {[string equal $moveArr(type) "line"] && ($len < 8)} {
	    
	# Make the line segments to a closed polygon.
	# Get all actual options.
	set lineopts [::CanvasUtils::GetItemOpts $wcan $itemid]
	set polycoo [lreplace $itemcoo end-1 end]
	set cmd1 [list delete $utag]
	eval $wcan $cmd1
	
	# Make the closed polygon. Get rid of non-applicable options.
	set opcmd $lineopts
	array set opcmdArr $opcmd
	foreach op {arrow arrowshape capstyle joinstyle tags} {
	    unset -nocomplain opcmdArr(-$op)
	}
	set opcmdArr(-outline) black
	
	# Replace -fill with -outline.
	set ind [lsearch -exact $lineopts -fill]
	if {$ind >= 0} {
	    set opcmdArr(-outline) [lindex $lineopts [expr {$ind+1}]]
	}
	set utag [::CanvasUtils::NewUtag]
	set opcmdArr(-fill) {} 
	set opcmdArr(-tags) [list polygon std $utag]
	set cmd2 [concat create polygon $polycoo [array get opcmdArr]]
	set polyid [eval $wcan $cmd2]
	set ucmd1 [list delete $utag]
	set ucmd2 [concat create line $coords $lineopts]
	set undo [list ::CanvasUtils::CommandList $w [list $ucmd1 $ucmd2]]
	set redo [list ::CanvasUtils::CommandList $w [list $cmd1 $cmd2]]
	
	# Move all markers along.
	$wcan delete id:$itemid
	MarkBbox $wcan 0 $polyid
    } else {
	set undocmd [concat coords $utag $coords]
	set cmd [concat coords $utag [$wcan coords $itemid]]
	set undo [list ::CanvasUtils::Command $w $undocmd]
	set redo [list ::CanvasUtils::Command $w $cmd]
    }

    eval $redo remote
    undo::add [::WB::GetUndoToken $w] $undo $redo
   
    unset -nocomplain moveArr
}

# CanvasDraw::InitMoveFrame, DoMoveFrame FinMoveFrame --
# 
#       Generic and general move functions for framed (window) items.

proc ::CanvasDraw::InitMoveFrame {wcan wframe x y} {
    global  kGrad2Rad    
    variable  xDragFrame
        
    # If frame then make ghost rectangle. 
    # Movies (and windows) do not obey the usual stacking order!    
    set utag [::CanvasUtils::GetUtagFromWindow $wframe]
    if {$utag eq ""} {
	return
    }

    # Fix x and y.
    set x [$wcan canvasx [expr {[winfo x $wframe] + $x}]]
    set y [$wcan canvasx [expr {[winfo y $wframe] + $y}]]
    
    Debug 2 "InitMoveFrame:: wcan=$wcan, wframe=$wframe x=$x, y=$y"
	
    set xDragFrame(what) "frame"
    set xDragFrame(baseX) $x
    set xDragFrame(baseY) $y
    set xDragFrame(anchorX) $x
    set xDragFrame(anchorY) $y
    
    # In some cases we need the anchor point to be an exact item 
    # specific coordinate.
    
    set xDragFrame(type) [$wcan type current]
    set xDragFrame(undocmd) [concat coords $utag [$wcan coords $utag]]
    $wcan addtag _moveframe withtag $utag
    lassign [$wcan bbox $utag] x1 y1 x2 y2
    incr x1 -1
    incr y1 -1
    incr x2 +1
    incr y2 +1
    $wcan create rectangle $x1 $y1 $x2 $y2 -outline gray50 -width 3 \
      -stipple gray50 -tags _ghostrect	
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
    set x [$wcan canvasx [expr {[winfo x $wframe] + $x}]]
    set y [$wcan canvasx [expr {[winfo y $wframe] + $y}]]
    lassign [ToScroll $wcan _selectedwindow $xDragWin(baseX) $xDragWin(baseY) $x $y] x y

    # Moving a frame window item (_ghostrect).
    $wcan move _ghostrect \
      [expr {$x - $xDragFrame(baseX)}] [expr {$y - $xDragFrame(baseY)}]
    
    set xDragFrame(baseX) $x
    set xDragFrame(baseY) $y
}

proc ::CanvasDraw::FinMoveFrame {wcan wframe  x y} {
    variable  xDragFrame
    
    Debug 2 "FinMoveFrame info exists xDragFrame=[info exists xDragFrame]"

    if {![info exists xDragFrame]} {
	return
    }
   
    # Need to get the actual, constrained, coordinates and not the mouses.
    set x $xDragFrame(baseX)
    set y $xDragFrame(baseY)
    set id [$wcan find withtag _moveframe]
    set utag [::CanvasUtils::GetUtag $wcan $id]
    
    Debug 2 "\t id=$id, utag=$utag, x=$x, y=$y"

    if {$utag eq ""} {
	return
    }
    $wcan move _moveframe [expr {$x - $xDragFrame(anchorX)}]  \
      [expr {$y - $xDragFrame(anchorY)}]
    $wcan dtag _moveframe _moveframe
    set cmd [concat coords $utag [$wcan coords $utag]]
    
    # Delete the ghost rect or highlighted marker if any. Remove temporary tags.
    $wcan delete _ghostrect
    
    # Do send to all connected.
    set w [winfo toplevel $wcan]
    set redo [list ::CanvasUtils::Command $w $cmd]
    if {[info exists xDragFrame(undocmd)]} {
	set undo [list ::CanvasUtils::Command $w $xDragFrame(undocmd)]
    }
    eval $redo remote
    if {[info exists undo]} {
	undo::add [::WB::GetUndoToken $w] $undo $redo
    }    
    unset -nocomplain xDragFrame
}

# CanvasDraw::InitMoveWindow --
# 
#       Generic and general move functions for window items.

proc ::CanvasDraw::InitMoveWindow {wcan win x y} {
    global  kGrad2Rad    
    variable xDragWin
    
    set utag [::CanvasUtils::GetUtagFromWindow $win]
    if {$utag eq ""} {
	return
    }

    # Fix x and y.
    set x [$wcan canvasx [expr {[winfo x $win] + $x}]]
    set y [$wcan canvasx [expr {[winfo y $win] + $y}]]
    Debug 2 "InitMoveWindow:: wcan=$wcan, win=$win x=$x, y=$y"
	
    set xDragWin(what) "window"
    set xDragWin(baseX) $x
    set xDragWin(baseY) $y
    set xDragWin(anchorX) $x
    set xDragWin(anchorY) $y
    
    # In some cases we need the anchor point to be an exact item 
    # specific coordinate.    
    set xDragWin(type) [$wcan type current]
    set xDragWin(winbg) [$win cget -bg]
    set xDragWin(undocmd) [concat coords $utag [$wcan coords $utag]]
    $win configure -bg gray20
    $wcan addtag _selectedwindow withtag $utag
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
    set x [$wcan canvasx [expr {[winfo x $win] + $x}]]
    set y [$wcan canvasx [expr {[winfo y $win] + $y}]]
    lassign [ToScroll $wcan _selectedwindow $xDragWin(baseX) $xDragWin(baseY) $x $y] x y
    
    # Moving a frame window item (_selectedwindow).
    $wcan move _selectedwindow \
      [expr {$x - $xDragWin(baseX)}] [expr {$y - $xDragWin(baseY)}]
    
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
   
    # Need to get the actual, constrained, coordinates and not the mouses.
    set x $xDragWin(baseX)
    set y $xDragWin(baseY)
    
    set id [$wcan find withtag _selectedwindow]
    set utag [::CanvasUtils::GetUtag $wcan $id]

    Debug 2 "\t id=$id, utag=$utag, x=$x, y=$y"

    if {$utag eq ""} {
	return
    }
    $wcan dtag _selectedwindow _selectedwindow
    set cmd [concat coords $utag [$wcan coords $utag]]
    $win configure -bg $xDragWin(winbg)
	
    # Do send to all connected.
    set w [winfo toplevel $wcan]
    set redo [list ::CanvasUtils::Command $w $cmd]
    if {[info exists xDragWin(undocmd)]} {
	set undo [list ::CanvasUtils::Command $w $xDragWin(undocmd)]
    }
    eval $redo remote
    if {[info exists undo]} {
	undo::add [::WB::GetUndoToken $w] $undo $redo
    }    
    unset -nocomplain xDragWin
}

# CanvasDraw::FinalMoveCurrentGrid --
# 
#       A way to constrain movements to a grid.

proc ::CanvasDraw::FinalMoveCurrentGrid {wcan x y grid args} {
    variable moveArr
    
    Debug 2 "::CanvasDraw::FinalMoveCurrentGrid"

    set selected [$wcan find withtag selected&&!locked]
    if {$selected != {}} {
	return
    }
    set dx [expr {$x - $moveArr(x0)}]
    set dy [expr {$y - $moveArr(y0)}]    
    set id $moveArr(id)
    set utag [::CanvasUtils::GetUtag $wcan $id]
    if {$utag eq ""} {
	return
    }
    array set argsArr {
	-anchor     nw
    }
    array set argsArr $args
    set w [winfo toplevel $wcan]

    # Extract grid specifiers.
    foreach {xmin dx nx} [lindex $grid 0] break
    foreach {ymin dy ny} [lindex $grid 1] break
    
    # Position of item.
    foreach {x0 y0 x1 y1} [$wcan bbox $id] break
    set xc [expr {int(($x0 + $x1)/2)}]
    set yc [expr {int(($y0 + $y1)/2)}]
    set width2 [expr {int(($x1 - $x0)/2)}]
    set height2 [expr {int(($y1 - $y0)/2)}]
    set ix [expr {round(double($xc - $xmin)/$dx)}]
    set iy [expr {round(double($yc - $ymin)/$dy)}]
    
    # Figure out if in the domain of the grid.
    if {($ix >= 0) && ($ix <= $nx) && ($iy >= 0) && ($iy <= $ny)} {
	set doGrid 1
	set newx [expr {$xmin + $ix * $dx}]
	set newy [expr {$ymin + $iy * $dy}]
    } else {
	set doGrid 0
	set newx [expr {int($x)}]
	set newy [expr {int($y)}]
    }
       
    if {[string equal $moveArr(type) "image"]} {
	if {$doGrid} {
	    set anchor [$wcan itemcget $id -anchor]
	    
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
	    set redo [list ::CanvasUtils::Command $w $cmd]
	} else {
	    set redo [list ::CanvasUtils::Command $w $cmd remote]
	}
	set undoCmd [concat coords $utag $moveArr(coords0,$id)]
    } else {
	
	# Non image items. 
	# If grid then compute distances to be moved:
	#    local item need only move to closest grid,
	#    remote item needs to be moved all the way.
	if {$doGrid} {
	    set anchor c
	    set cmdlocal [list move $utag [expr {$newx - $xc}] [expr {$newy - $yc}]]
	    set deltax [expr {$newx - $moveArr(x0)}]
	    set deltay [expr {$newy - $moveArr(y0)}]
	    set cmdremote [list move $utag $deltax $deltay]
	    set redo [list ::CanvasUtils::CommandExList $w  \
	      [list [list $cmdlocal local] [list $cmdremote remote]]]
	    set undoCmd [list move $utag [expr {-1*$deltax}] [expr {-1*$deltay}]]
	} else {
	    set cmd [list move $utag $dx $dy]
	    set redo [list ::CanvasUtils::Command $w $cmd remote]
	    set undoCmd [list move $utag [expr {-1*($x - $moveArr(x0))}] \
	      [expr {-1*($y - $moveArr(y0))}]]
	}
    }
	
    # Do send to all connected.
    set undo [list ::CanvasUtils::Command $w $undoCmd]
    eval $redo
    undo::add [::WB::GetUndoToken $w] $undo $redo    

    unset -nocomplain moveArr
}

proc ::CanvasDraw::HitTBBox {wcan x y} {
    
    set hit 0
    set d 2
    $wcan addtag _tmp overlapping  \
      [expr {$x-$d}] [expr {$y-$d}] [expr {$x+$d}] [expr {$y+$d}]
    if {[$wcan find withtag tbbox&&_tmp&&!locked] != {}} {
	set hit 1
    }
    $wcan dtag _tmp
    return $hit
}

proc ::CanvasDraw::HitMovableTBBox {wcan x y} {

    set hit 0
    set d 2
    set movable {arc line polygon rectangle oval}
    set ids [$wcan find overlapping \
      [expr {$x-$d}] [expr {$y-$d}] [expr {$x+$d}] [expr {$y+$d}]]
    foreach id $ids {
	set tags [$wcan gettags $id]
	if {[lsearch $tags tbbox] >= 0} {
	    if {[regexp {id:([0-9]+)} $tags match itemid]} {
		if {[lsearch $movable [$wcan type $itemid]] >= 0} {
		    set hit 1
		    break
		}
	    }
	}
    }
    return $hit
}

proc ::CanvasDraw::DrawHighlightBox {wcan itemid id} {
    
    # Make a highlightbox at the 'hitBbox' marker.
    set bbox [$wcan bbox $id]
    set x1 [expr {[lindex $bbox 0] - 1}]
    set y1 [expr {[lindex $bbox 1] - 1}]
    set x2 [expr {[lindex $bbox 2] + 1}]
    set y2 [expr {[lindex $bbox 3] + 1}]

    $wcan create rectangle $x1 $y1 $x2 $y2 -outline black -width 1 \
      -tags [list lightBbox id:${itemid}] -fill white
}

proc ::CanvasDraw::FindClosestCoordsIndex {x y coords} {
    
    set n [llength $coords]
    set min 1000000
    set ind 0
    for {set i 0} {$i < $n} {incr i 2} {
	set len [expr {hypot([lindex $coords $i] - $x,  \
	  [lindex $coords [expr {$i+1}]] - $y)}]
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
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       type   item type (rectangle, oval, ...).
#       
# Results:
#       none

proc ::CanvasDraw::InitBox {wcan x y type} {
    
    variable theBox
    
    set theBox($wcan,anchor) [list $x $y]
    set theBox($wcan,x) $x
    set theBox($wcan,y) $y
    unset -nocomplain theBox($wcan,last)
}

# CanvasDraw::BoxDrag --
#
#       Draws rectangles, ovals, and ghost rectangles.
#   
# Arguments:
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       shift  constrain to square or circle.
#       type   item type (rectangle, oval, ...).
#       mark   If not 'mark', then draw ordinary rectangle if 'type' is 
#              rectangle or oval if 'type' is oval.
#       
# Results:
#       none

proc ::CanvasDraw::BoxDrag {wcan x y shift type {mark 0}} {
    global  prefs
    
    variable theBox
    
    set w [winfo toplevel $wcan]
    array set state [::WB::GetStateArray $w]

    catch {$wcan delete $theBox($wcan,last)}
    
    # If not set anchor, just return.
    if {![info exists theBox($wcan,anchor)]} {
	return
    }
    set boxOrig $theBox($wcan,anchor)
    if {!$mark} {
	lassign [XYToScroll $wcan $x $y] x y
    }
    
    # If 'shift' constrain to square or circle.
    if {$shift} {
	set box [ConstrainedBoxDrag $theBox($wcan,anchor) $x $y $type]
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
    if {$mark} {
	set theBox($wcan,last) [eval {$wcan create $type} $boxOrig	\
	  {$x $y -outline gray50 -stipple gray50 -width 2 -tags "markbox" }]
    } else {
	set tags [list std $type]
	if {$state(fill)} {
	    set theBox($wcan,last) [eval {$wcan create $type} $boxOrig  \
	      {$x $y -outline $state(fgCol) -fill $state(fgCol)  \
	      -width $state(penThick) -tags $tags}  \
	      $extras]
	} else {
	    set theBox($wcan,last) [eval {$wcan create $type} $boxOrig  \
	      {$x $y -outline $state(fgCol) -width $state(penThick)  \
	      -tags $tags} $extras]
	}
    }
    set theBox($wcan,x) $x
    set theBox($wcan,y) $y
}

# CanvasDraw::FinalizeBox --
#
#       Take action when finsished with BoxDrag, mark items, let all other
#       clients know etc.
#   
# Arguments:
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       shift  constrain to square or circle.
#       type   item type (rectangle, oval, ...).
#       mark   If not 'mark', then draw ordinary rectangle if 'type' is rectangle,
#              or oval if 'type' is oval.
#       
# Results:
#       none

proc ::CanvasDraw::FinalizeBox {wcan x y shift type {mark 0}} {
    global  prefs
    
    variable theBox
    set w [winfo toplevel $wcan]
    array set state [::WB::GetStateArray $w]
    
    # If no theBox($wcan,anchor) defined just return.
    if {![info exists theBox($wcan,anchor)]}  {
	return
    }
    catch {$wcan delete $theBox($wcan,last)}
    lassign $theBox($wcan,anchor) xanch yanch

    # Need to get the constrained "mouse point".
    set x $theBox($wcan,x)
    set y $theBox($wcan,y)
    if {($xanch == $x) && ($yanch == $y)} {
	set nomove 1
	return
    } else {
	set nomove 0
    }
    if {$mark} {
	set ids [eval {$wcan find overlapping} $theBox($wcan,anchor) {$x $y}]
	foreach id $ids {
	    MarkBbox $wcan 1 $id
	}
	$wcan delete withtag markbox
    }
    set extras {}
    if {$prefs(haveDash)} {
	set extras [list -dash $state(dash)]
    }
    
    # Create real objects.
    if {!$mark && !$nomove} {
	set boxOrig $theBox($wcan,anchor)
	if {$mark} {
	    set utag [::CanvasUtils::NewUtag 0]
	} else {
	    set utag [::CanvasUtils::NewUtag]
	}
	if {$state(fill)} {
	    lappend extras -fill $state(fgCol)
	}
	set tags [list std $type $utag]
	set coo [concat $boxOrig $x $y]
	set cmd [list create $type $coo -tags $tags -outline $state(fgCol) \
	  -width $state(penThick)]
	set cmd [concat $cmd $extras]
	set undocmd [list delete $utag]
	set redo [list ::CanvasUtils::Command $w $cmd]
	set undo [list ::CanvasUtils::Command $w $undocmd]
	eval $redo
	undo::add [::WB::GetUndoToken $w] $undo $redo
    }
    array unset theBox $wcan,*
}

proc ::CanvasDraw::CancelBox {wcan} {
    
    variable theBox
    unset -nocomplain theBox
    $wcan delete withtag markbox
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
    
    set deltax [expr {$x - $xanch}]
    set deltay [expr {$y - $yanch}]
    set prod [expr {$deltax * $deltay}]
    if {$type eq "rectangle"} {
	set boxOrig [list $xanch $yanch]
	if {$prod != 0} {
	    set sign [expr {$prod / abs($prod)}]
	} else {
	    set sign 1
	}
	if {[expr {abs($deltax)}] > [expr {abs($deltay)}]} {
	    set x [expr {$sign * ($y - $yanch) + $xanch}]
	} else {
	    set y [expr {$sign * ($x - $xanch) + $yanch}]
	}
	
	# A pure circle is not made with the bounding rectangle model.
	# The anchor and the present x, y define the diagonal instead.
    } elseif {$type eq "oval"} {
	set r [expr {hypot($deltax, $deltay)/2.0}]
	set midx [expr {($xanch + $x)/2.0}]
	set midy [expr {($yanch + $y)/2.0}]
	set boxOrig [list [expr {int($midx - $r)}] [expr {int($midy - $r)}]]
	set x [expr {int($midx + $r)}]
	set y [expr {int($midy + $r)}]
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
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       type   item type (rectangle, oval, ...).
#       shift  constrain to 45 or 90 degree arcs.
#       
# Results:
#       none

proc ::CanvasDraw::InitArc {wcan x y {shift 0}} {
    global  kRad2Grad this
    
    variable arcBox
    set w [winfo toplevel $wcan]
    
    Debug 2 "InitArc:: wcan=$wcan, x=$x, y=$y, shift=$shift"

    if {![info exists arcBox($wcan,setcent)] || $arcBox($wcan,setcent) == 0} {
	
	# First button press.
	set arcBox($wcan,center) [list $x $y]
	set arcBox($wcan,setcent) 1
	# Hack.
	if {[string match "mac*" $this(platform)]} {
	    $wcan create oval [expr {$x - 2}] [expr {$y - 2}] [expr {$x + 3}] [expr {$y + 3}]  \
	      -outline gray50 -fill {} -tags tcent
	    $wcan create line [expr {$x - 5}] $y [expr {$x + 5}] $y -fill gray50 -tags tcent
	    $wcan create line $x [expr {$y - 5}] $x [expr {$y + 5}] -fill gray50 -tags tcent 
	} else {
	    $wcan create oval [expr {$x - 3}] [expr {$y - 3}] [expr {$x + 3}] [expr {$y + 3}]  \
	      -outline gray50 -fill {} -tags tcent
	    $wcan create line [expr {$x - 5}] $y [expr {$x + 6}] $y -fill gray50 -tags tcent
	    $wcan create line $x [expr {$y - 5}] $x [expr {$y + 6}] -fill gray50 -tags tcent 
	}
	focus $wcan
	bind $wcan <KeyPress-space> {
	    ::CanvasDraw::ArcCancel %W
	}
	::WB::SetStatusMessage $w [mc uastatarc2]
	
    } else {
	
	# If second button press, bind mouse motion.
	set cx [lindex $arcBox($wcan,center) 0]
	set cy [lindex $arcBox($wcan,center) 1]
	if {$shift} {
	    set newco [ConstrainedDrag $x $y $cx $cy]
	    foreach {x y} $newco {}
	}
	set arcBox($wcan,first) [list $x $y]
	set arcBox($wcan,startAng) [expr {$kRad2Grad * atan2($cy - $y, -($cx - $x))}]
	set arcBox($wcan,extent) {0.0}
	set r [expr {hypot($cx - $x, $cy - $y)}]
	set x1 [expr {$cx + $r}]
	set y1 [expr {$cy + $r}]
	set arcBox($wcan,co1) [list $x1 $y1]
	set arcBox($wcan,co2) [list [expr {$cx - $r}] [expr {$cy - $r}]]
	bind $wcan <B1-Motion> {
	    ::CanvasDraw::ArcDrag %W [%W canvasx %x] [%W canvasy %y]
	}
	bind $wcan <Shift-B1-Motion> {
	    ::CanvasDraw::ArcDrag %W [%W canvasx %x] [%W canvasy %y] 1
	}
	bind $wcan <ButtonRelease-1> {
	    ::CanvasDraw::FinalizeArc %W [%W canvasx %x] [%W canvasy %y]
	}
    }
    unset -nocomplain arcBox($wcan,last)
}

# CanvasDraw::ArcDrag --
#
#       Draw an arc.
#       The tricky part is to choose one of the two possible solutions, CW or CCW.
#       
# Arguments:
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       shift  constrain to 45 or 90 degree arcs.
#       
# Results:
#       none

proc ::CanvasDraw::ArcDrag {wcan x y {shift 0}} {
    global  kRad2Grad prefs

    variable arcBox
    set w [winfo toplevel $wcan]
    array set state [::WB::GetStateArray $w]
    
    # @@@ Remains to constrain to scrollregion.
    
    # If constrained to 90/45 degrees.
    if {$shift} {
	lassign $arcBox($wcan,center) cx cy
	lassign [ConstrainedDrag $x $y $cx $cy] x y
    }
    
    # Choose one of two possible solutions, either CW or CCW.
    # Make sure that the 'extent' angle is more or less continuous.
    
    set stopAng [expr {$kRad2Grad *   \
      atan2([lindex $arcBox($wcan,center) 1] - $y, -([lindex $arcBox($wcan,center) 0] - $x))}]
    set extentAng [expr {$stopAng - $arcBox($wcan,startAng)}]
    if {[expr {$arcBox($wcan,extent) - $extentAng}] > 180} {
	set extentAng [expr {$extentAng + 360}]
    } elseif {[expr {$arcBox($wcan,extent) - $extentAng}] < -180} {
	set extentAng [expr {$extentAng - 360}]
    }
    set arcBox($wcan,extent) $extentAng
    catch {$wcan delete $arcBox($wcan,last)}
    if {$state(fill)} {
	set theFill [list -fill $state(fgCol)]
    } else {
	set theFill [list -fill {}]
    }
    if {$prefs(haveDash)} {
	set extras [list -dash $state(dash)]
    } else {
	set extras {}
    }
    set arcBox($wcan,last) [eval {$wcan create arc} $arcBox($wcan,co1)   \
      $arcBox($wcan,co2) {-start $arcBox($wcan,startAng) -extent $extentAng  \
      -width $state(penThick) -style $state(arcstyle) -outline $state(fgCol)  \
      -tags arc} $theFill $extras]
}

# CanvasDraw::FinalizeArc --
#
#       Finalize the arc drawing, tell all other clients.
#       
# Arguments:
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       
# Results:
#       none

proc ::CanvasDraw::FinalizeArc {wcan x y} {
    global  prefs 

    variable arcBox
    set w [winfo toplevel $wcan]
    array set state [::WB::GetStateArray $w]

    Debug 2 "FinalizeArc:: wcan=$wcan"

    ::WB::SetStatusMessage $w [mc uastatarc]
    bind $wcan <B1-Motion> {}
    bind $wcan <ButtonRelease-1> {}
    bind $wcan <KeyPress-space> {}
    catch {$wcan delete tcent}
    catch {$wcan delete $arcBox($wcan,last)}
    
    # If extent angle zero, nothing to draw, nothing to send.
    if {$arcBox($wcan,extent) eq "0.0"} {
	unset -nocomplain arcBox
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
    set cmd "create arc $arcBox($wcan,co1)   \
      $arcBox($wcan,co2) -start $arcBox($wcan,startAng) -extent $arcBox($wcan,extent)  \
      -width $state(penThick) -style $state(arcstyle) -outline $state(fgCol)  \
      -tags {std arc $utag} $theFill $extras"
    set undocmd "delete $utag"
    set redo [list ::CanvasUtils::Command $w $cmd]
    set undo [list ::CanvasUtils::Command $w $undocmd]
    eval $redo
    undo::add [::WB::GetUndoToken $w] $undo $redo
    unset -nocomplain arcBox
}

# CanvasDraw::ArcCancel --
#
#       Cancel the arc drawing.
#       
# Arguments:
#       wcan      the canvas widget.
#       
# Results:
#       none

proc ::CanvasDraw::ArcCancel {wcan} {
    
    variable arcBox
    set w [winfo toplevel $wcan]

    ::WB::SetStatusMessage $w [mc uastatarc]
    catch {$wcan delete tcent}
    unset -nocomplain arcBox
}

#--- End of the arc tool procedures --------------------------------------------

#--- Polygon tool procedures ---------------------------------------------------

# CanvasDraw::PolySetPoint --
#
#       Polygon drawing routines.
#   
# Arguments:
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       
# Results:
#       none

proc ::CanvasDraw::PolySetPoint {wcan x y} {
    
    variable thePoly

    if {![info exists thePoly(0)]} {
	
	# First point.
	unset -nocomplain thePoly
	set thePoly(N) 0
	set thePoly(0) [list $x $y]
    } elseif {[expr   \
      {hypot([lindex $thePoly(0) 0] - $x, [lindex $thePoly(0) 1] - $y)}] < 6} {
	
	# If this point close enough to 'thePoly(0)', close polygon.
	PolyDrag $wcan [lindex $thePoly(0) 0] [lindex $thePoly(0) 1]
	set thePoly(last) {}
	incr thePoly(N)
	set thePoly($thePoly(N)) $thePoly(0)
	FinalizePoly $wcan [lindex $thePoly(0) 0] [lindex $thePoly(0) 1]
	return
    } else {
	set thePoly(last) {}
	incr thePoly(N)
	set thePoly($thePoly(N)) $thePoly(xy)
    }
    
    # Let the latest line segment follow the mouse movements.
    focus $wcan
    bind $wcan <Motion> {
	::CanvasDraw::PolyDrag %W [%W canvasx %x] [%W canvasy %y]
    }
    bind $wcan <Shift-Motion> {
	::CanvasDraw::PolyDrag %W [%W canvasx %x] [%W canvasy %y] 1
    }
    bind $wcan <KeyPress-space> {
	::CanvasDraw::FinalizePoly %W [%W canvasx %x] [%W canvasy %y]
    }
}               

# CanvasDraw::PolyDrag --
#
#       Polygon drawing routines.
#   
# Arguments:
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       shift  constrain.
#       
# Results:
#       none

proc ::CanvasDraw::PolyDrag {wcan x y {shift 0}} {
    global  prefs

    variable thePoly
    set w [winfo toplevel $wcan]
    array set state [::WB::GetStateArray $w]

    # Move one end point of the latest line segment of the polygon.
    # If anchor not set just return.
    if {![info exists thePoly(0)]} {
	return
    }
    catch {$wcan delete $thePoly(last)}

    lassign [XYToScroll $wcan $x $y] x y

    # Vertical or horizontal.
    if {$shift} {
	lassign $thePoly($thePoly(N)) x0 y0
	lassign [ConstrainedDrag $x $y $x0 $y0] x y
    }
    if {$prefs(haveDash)} {
	set extras [list -dash $state(dash)]
    } else {
	set extras {}
    }
    
    # Keep track of last coordinates. Important for 'shift'.
    set thePoly(xy) [list $x $y]
    set thePoly(last) [eval {$wcan create line} $thePoly($thePoly(N))  \
      {$x $y -tags _polylines -fill $state(fgCol)  \
      -width $state(penThick)} $extras]
}

# CanvasDraw::FinalizePoly --
#
#       Polygon drawing routines.
#   
# Arguments:
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       
# Results:
#       none

proc ::CanvasDraw::FinalizePoly {wcan x y} {
    global  prefs    
    variable thePoly

    set w [winfo toplevel $wcan]
    array set state [::WB::GetStateArray $w]

    bind $wcan <Motion> {}
    bind $wcan <KeyPress-space> {}
    
    # If anchor not set just return.
    if {![info exists thePoly(0)]} {
	return
    }
    
    # If too few segment.
    if {$thePoly(N) <= 1} {
	$wcan delete _polylines
	unset -nocomplain thePoly
	return
    }
    
    # Delete last line segment.
    catch {$wcan delete $thePoly(last)}
    
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
    $wcan delete _polylines
    set extras {}
    if {$state(fill)} {
	lappend extras -fill $state(fgCol)
    } else {
	lappend extras -fill {}
    }
    if {$prefs(haveDash)} {
	lappend extras -dash $state(dash)
    }
    set utag [::CanvasUtils::NewUtag]
    if {$isClosed} {
	
	# This is a (closed) polygon.
	set tags [list std polygon $utag]
	set cmd [list create polygon $coords -tags $tags  \
	  -outline $state(fgCol) -width $state(penThick)  \
	  -smooth $state(smooth)]
	set cmd [concat $cmd $extras]
    } else {
	
	# This is an open line segment.
	set tags [list std line $utag]
	set cmd [list create line $coords -tags $tags  \
	  -fill $state(fgCol) -width $state(penThick)  \
	  -smooth $state(smooth)]
	set cmd [concat $cmd $extras]
    }
    set undocmd [list delete $utag]
    set redo [list ::CanvasUtils::Command $w $cmd]
    set undo [list ::CanvasUtils::Command $w $undocmd]
    eval $redo
    undo::add [::WB::GetUndoToken $w] $undo $redo
    unset -nocomplain thePoly
}

proc ::CanvasDraw::CancelPoly {wcan} {
    variable thePoly

    unset -nocomplain thePoly
}

#--- End of polygon drawing procedures -----------------------------------------

#--- Line and arrow drawing procedures ----------------------------------------- 

# CanvasDraw::InitLine --
#
#       Handles drawing of a straight line. Uses global 'theLine' variable
#       to store anchor point and end point of the line.
#       
# Arguments:
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       opt    0 for line and arrow for arrow.
#       
# Results:
#       none

proc ::CanvasDraw::InitLine {wcan x y {opt 0}} {

    variable theLine
    
    set theLine($wcan,anchor) [list $x $y]
    set theLine($wcan,x)  $x
    set theLine($wcan,y)  $y
    set theLine($wcan,x0) $x
    set theLine($wcan,y0) $y
    unset -nocomplain theLine($wcan,last)
}

# CanvasDraw::LineDrag --
#
#       Handles drawing of a straight line. Uses global 'theLine' variable
#       to store anchor point and end point of the line.
#       
# Arguments:
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       shift  constrain the line to be vertical or horizontal.
#       opt    If 'opt'=arrow draw an arrow at the final line end.
#       
# Results:
#       none

proc ::CanvasDraw::LineDrag {wcan x y shift {opt 0}} {
    global  prefs
    
    variable theLine
    set w [winfo toplevel $wcan]
    array set state [::WB::GetStateArray $w]

    # If anchor not set just return.
    if {![info exists theLine($wcan,anchor)]} {
	return
    }


    catch {$wcan delete $theLine($wcan,last)}
    if {[string equal $opt "arrow"]} {
	set extras [list -arrow last]
    } else {
	set extras {}
    }
    if {$prefs(haveDash)} {
	lappend extras -dash $state(dash)
    }
    lassign [XYToScroll $wcan $x $y] x y
    
    # Vertical or horizontal.
    if {$shift} {
	lassign [ConstrainedDrag $x $y $theLine($wcan,x0) $theLine($wcan,y0)] x y
    }
    set theLine($wcan,last) [eval {$wcan create line} $theLine($wcan,anchor)  \
      {$x $y -tags line -fill $state(fgCol) -width $state(penThick)} $extras]

    set theLine($wcan,x) $x
    set theLine($wcan,y) $y
}

# CanvasDraw::FinalizeLine --
#
#       Handles drawing of a straight line. Uses global 'theLine' variable
#       to store anchor point and end point of the line.
#       Lets all other clients know.
#       
# Arguments:
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       shift  constrain the line to be vertical or horizontal.
#       opt    If 'opt'=arrow draw an arrow at the final line end.
#       
# Results:
#       none

proc ::CanvasDraw::FinalizeLine {wcan x y shift {opt 0}} {
    global  prefs
    
    variable theLine
    set w [winfo toplevel $wcan]
    array set state [::WB::GetStateArray $w]

    # If anchor not set just return.
    if {![info exists theLine($wcan,anchor)]} {
	return
    }
    catch {$wcan delete $theLine($wcan,last)}

    # If not dragged, zero line, and just return.
    if {![info exists theLine($wcan,last)]} {
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

    # Need to get the actual, constrained, coordinates and not the mouses.
    set x $theLine($wcan,x)
    set y $theLine($wcan,y)
    
    # Vertical or horizontal.
    if {$shift} {
	lassign [ConstrainedDrag $x $y $theLine($wcan,x0) $theLine($wcan,y0)] x y
    }
    set utag [::CanvasUtils::NewUtag]
    set tags [list std line $utag]
    set cmd [list create line $theLine($wcan,x0) $theLine($wcan,y0) $x $y  \
      -tags $tags -joinstyle round -fill $state(fgCol) -width $state(penThick)]
    set cmd [concat $cmd $extras]
    set undocmd [list delete $utag]
    set redo [list ::CanvasUtils::Command $w $cmd]
    set undo [list ::CanvasUtils::Command $w $undocmd]
    eval $redo
    undo::add [::WB::GetUndoToken $w] $undo $redo
    unset -nocomplain theLine
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
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       
# Results:
#       none

proc ::CanvasDraw::InitStroke {wcan x y} {

    variable stroke
    
    unset -nocomplain stroke
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
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       brush  (D=0) boolean, 1 for brush, 0 for pen.
#       
# Results:
#       none

proc ::CanvasDraw::StrokeDrag {wcan x y {brush 0}} {
    global  prefs
    
    variable stroke
    set w [winfo toplevel $wcan]
    array set state [::WB::GetStateArray $w]

    # If stroke not set just return.
    if {![info exists stroke(N)]} {
	return
    }
    lassign [XYToScroll $wcan $x $y] x y
    set coords $stroke($stroke(N))
    lappend coords $x $y
    incr stroke(N)
    set stroke($stroke(N)) [list $x $y]
    if {$brush} {
	set thick $state(brushThick)
    } else {
	set thick $state(penThick)
    }
    if {$prefs(haveDash)} {
	set extras [list -dash $state(dash)]
    } else {
	set extras {}
    }
    eval {$wcan create line} $coords {-tags segments -fill $state(fgCol)  \
      -width $thick} $extras
}

# CanvasDraw::FinalizeStroke --
#
#       Handles drawing of an arbitrary line. Uses global 'stroke' variable
#       to store all intermediate points on the line, and stroke(N) to store
#       the number of such points.
#   
# Arguments:
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       brush  (D=0) boolean, 1 for brush, 0 for pen.
#       
# Results:
#       none

proc ::CanvasDraw::FinalizeStroke {wcan x y {brush 0}} {
    global  prefs
    
    variable stroke
    set w [winfo toplevel $wcan]
    array set state [::WB::GetStateArray $w]

    Debug 2 "FinalizeStroke::"

    # If stroke not set just return.
    set coords {}
    if {![info exists stroke(N)]} {
	return
    }
    if {$prefs(wb,strokePost)} {
	set coords [StrokePostProcess $wcan]
    } else {
	set coords [StrokeGetCoords $wcan]
    }
    $wcan delete segments
    if {[llength $coords] <= 2} {
	return
    }
    if {$brush} {
	set thick $state(brushThick)
    } else {
	set thick $state(penThick)
    }
    if {$prefs(haveDash)} {
	set extras [list -dash $state(dash)]
    } else {
	set extras {}
    }
    if {$prefs(wb,strokePost)} {
	set smooth $state(smooth)
    } else {
	set smooth 0
    }
    set utag [::CanvasUtils::NewUtag]
    set cmd [list create line $coords  \
      -tags [list std line $utag] -joinstyle round  \
      -smooth $smooth -fill $state(fgCol) -width $thick]
    set cmd [concat $cmd $extras]
    set undocmd [list delete $utag]
    set redo [list ::CanvasUtils::Command $w $cmd]
    set undo [list ::CanvasUtils::Command $w $undocmd]
    eval $redo
    undo::add [::WB::GetUndoToken $w] $undo $redo
    unset -nocomplain stroke
}

# CanvasDraw::StrokePostProcess --
# 
#       Reduce the number of coords in the stroke in a smart way that also
#       smooths it. Always keep first and last.

proc ::CanvasDraw::StrokePostProcess {wcan} {    
    variable stroke
    
    set coords [StrokeGetCoords $wcan]
    
    # Next pass: remove points that are close to each other.
    set coords [StripClosePoints $coords 6]
    
    # Next pass: remove points that gives a too small radius or points
    # lying on a straight line.
    set coords [StripExtremeRadius $coords 6 10000]
    return $coords
}

proc ::CanvasDraw::StrokeGetCoords {wcan} {
    variable stroke
    
    set coords $stroke(0)
    
    # First pass: remove duplicates if any. Seems not to be the case!
    for {set i 0} {$i <= [expr {$stroke(N) - 1}]} {incr i} {
	if {$stroke($i) != $stroke([expr {$i+1}])} {
	    set coords [concat $coords $stroke([expr {$i+1}])]
	}
    }
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
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       shift  makes transparent.
#       
# Results:
#       none

proc ::CanvasDraw::DoPaint {wcan x y {shift 0}} {
    global  prefs kRad2Grad

    set w [winfo toplevel $wcan]
    array set state [::WB::GetStateArray $w]

    Debug 2 "DoPaint:: wcan=$wcan, x=$x, y=$y, shift=$shift"
    
    # Find items overlapping x and y. Doesn't work for transparent items.
    #set ids [$wcan find overlapping $x $y $x $y]
    # This is perhaps not an efficient solution.
    set ids [$wcan find all]

    foreach id $ids {
	set theType [$wcan type $id]

	# Sort out uninteresting items early.
	if {![string equal $theType "rectangle"] &&   \
	  ![string equal $theType "oval"] &&  \
	  ![string equal $theType "arc"]} {
	    continue
	}
	
	# Must be in bounding box.
	set theBbox [$wcan bbox $id]

	if {$x >= [lindex $theBbox 0] && $x <= [lindex $theBbox 2] &&  \
	  $y >= [lindex $theBbox 1] && $y <= [lindex $theBbox 3]} {
	    # OK, inside!
	    # Allow privacy.
	    set theItno [::CanvasUtils::GetUtag $wcan $id]
	    if {$theItno eq ""} {
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
		set centx [expr {([lindex $theBbox 0] + [lindex $theBbox 2])/2.0}]
		set centy [expr {([lindex $theBbox 1] + [lindex $theBbox 3])/2.0}]
		set a [expr {abs($centx - [lindex $theBbox 0])}]
		set b [expr {abs($centy - [lindex $theBbox 1])}]
		if {[expr {($x-$centx)*($x-$centx)/($a*$a) +   \
		  ($y-$centy)*($y-$centy)/($b*$b)}] <= 1} {
		    # Inside!
		    if {$shift == 0} {
			set cmd [list itemconfigure $theItno -fill $state(fgCol)]
		    } elseif {$shift == 1} {
			set cmd [list itemconfigure $theItno -fill {}]
		    }
		}
	    } elseif {[string equal $theType "arc"]} {
		set theCoords [$wcan coords $id]
		set cx [expr {([lindex $theCoords 0] + [lindex $theCoords 2])/2.0}]
		set cy [expr {([lindex $theCoords 1] + [lindex $theCoords 3])/2.0}]
		set r [expr {abs([lindex $theCoords 2] - [lindex $theCoords 0])/2.0}]
		set rp [expr {hypot($x - $cx, $y - $cy)}]
		
		# Sort out point outside the radius of the arc.
		if {$rp > $r} {
		    continue
		}
		set phi [expr $kRad2Grad * atan2(-($y - $cy),$x - $cx)]
		if {$phi < 0} {
		    set phi [expr $phi + 360]
		}
		set startPhi  [$wcan itemcget $id -start]
		set extentPhi [$wcan itemcget $id -extent]
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
	    if {$cmd != {}} {
		set undocmd [list itemconfigure $theItno  \
		  -fill [$wcan itemcget $theItno -fill]]
		set redo [list ::CanvasUtils::Command $w $cmd]
		set undo [list ::CanvasUtils::Command $w $undocmd]
		eval $redo
		undo::add [::WB::GetUndoToken $w] $undo $redo	    
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
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       
# Results:
#       none

proc ::CanvasDraw::InitRotateItem {wcan x y} {
    
    variable rotDrag

    # Only one single selected item is allowed to be rotated.
    set id [$wcan find withtag selected&&!locked]
    if {[llength $id] != 1} {
	return
    }
    set utag [::CanvasUtils::GetUtag $wcan $id]
    if {$utag eq ""} {
	return
    }
    
    # Certain item types cannot be rotated.
    set rotDrag(type) [$wcan type $id]
    if {[string equal $rotDrag(type) "text"]} {
	unset rotDrag
	return
    }
    
    # Get center of gravity and cache undo command.
    if {[string equal $rotDrag(type) "arc"]} {
	set colist [$wcan coords $id]
	set rotDrag(arcStart) [$wcan itemcget $id -start]
	set rotDrag(undocmd) [list itemconfigure $utag -start $rotDrag(arcStart)]
    } else {
	set colist [$wcan bbox $id]
	set rotDrag(undocmd) [concat coords $utag [$wcan coords $utag]]
    }
    set rotDrag(cgX) [expr ([lindex $colist 0] + [lindex $colist 2])/2.0]
    set rotDrag(cgY) [expr ([lindex $colist 1] + [lindex $colist 3])/2.0]
    set rotDrag(anchorX) $x
    set rotDrag(anchorY) $y
    set rotDrag(id)   $id
    set rotDrag(utag) $utag
    set rotDrag(lastAng) 0.0
    
    # Save coordinates relative cg.
    set theCoords [$wcan coords $id]
    set rotDrag(n) [expr [llength $theCoords]/2]    ;# Number of points.
    set i 0
    foreach {cx cy} $theCoords {
	set rotDrag(x,$i) [expr $cx - $rotDrag(cgX)]
	set rotDrag(y,$i) [expr $cy - $rotDrag(cgY)]
	incr i
    }
    
    # Observe coordinate system.
    set rotDrag(startAng) [expr atan2($y - $rotDrag(cgY), $x - $rotDrag(cgX)) ]

    # Keep an invisible fake copy to deal with constraints (scroll region).
    set cmdFake [::CanvasUtils::DuplicateItem $wcan $id -fill {} -outline {}]
    set rotDrag(idx) [eval $cmdFake]
}

# CanvasDraw::DoRotateItem --
#
#       Rotates an item.
#   
# Arguments:
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       shift  constrains rotation.
#       
# Results:
#       none

proc ::CanvasDraw::DoRotateItem {wcan x y {shift 0}} {
    global  kPI kRad2Grad prefs
    
    variable rotDrag

    if {![info exists rotDrag]} {
	return
    }
    set newAng [expr atan2($y - $rotDrag(cgY), $x - $rotDrag(cgX))]
    set deltaAng [expr $rotDrag(startAng) - $newAng]
    set angle 0.0
    
    # Certain items are only rotated in 90 degree intervals, other continuously.
    switch -- $rotDrag(type) {
	arc - line - polygon {
	    if {$shift} {
		if {!$prefs(45)} {
		    set angle [expr ($kPI/2.0) * round($deltaAng/($kPI/2.0))]
		} elseif {$prefs(45)} {
		    set angle [expr ($kPI/4.0) * round($deltaAng/($kPI/4.0))]
		}
	    } else {
		set angle $deltaAng
	    }
	}
	rectangle - oval {
	
	    # Find the rotated angle in steps of 90 degrees.
	    set angle [expr ($kPI/2.0) * round($deltaAng/($kPI/2.0))]
	}
    }
    
    # Find the new coordinates; arc: only start angle.
    if {[expr abs($angle)] > 1e-4 ||   \
      [expr abs($rotDrag(lastAng) - $angle)] > 1e-4} {
	set sinAng [expr sin($angle)]
	set cosAng [expr cos($angle)]
	set id  $rotDrag(id)
	set idx $rotDrag(idx)
	if {[string equal $rotDrag(type) "arc"]} {
	    
	    # Different coordinate system for arcs...and units...
	    set start [expr $kRad2Grad * $angle + $rotDrag(arcStart)]
	    set cmdReal [list $wcan itemconfigure $id -start $start]
	    set cmdFake [list $wcan itemconfigure $idx -start $start]
	} else {
	    
	    # Compute new coordinates from the original ones.
	    set new {}
	    for {set i 0} {$i < $rotDrag(n)} {incr i} {
		lappend new [expr $rotDrag(cgX) + $cosAng * $rotDrag(x,$i) +  \
		  $sinAng * $rotDrag(y,$i)]
		lappend new [expr $rotDrag(cgY) - $sinAng * $rotDrag(x,$i) +  \
		  $cosAng * $rotDrag(y,$i)]
	    }
	    set cmdReal [list $wcan coords $id $new]
	    set cmdFake [list $wcan coords $idx $new]
	}
	eval $cmdFake
	set bbox [$wcan bbox $idx]
	if {[BboxInsideScroll $wcan $bbox]} {
	    eval $cmdReal
	}
    }
    set rotDrag(lastAng) $angle
}

# CanvasDraw::FinalizeRotate --
#
#       Finalizes the rotation operation. Tells all other clients.
#   
# Arguments:
#       wcan   the canvas widget.
#       x,y    the mouse coordinates.
#       
# Results:
#       none

proc ::CanvasDraw::FinalizeRotate {wcan x y} {
    global  kRad2Grad        
    variable rotDrag

    if {![info exists rotDrag]} {
	return
    }
    set w [winfo toplevel $wcan]    
    $wcan delete $rotDrag(idx)
    
    # Move all markers along.
    set id   $rotDrag(id)
    set utag $rotDrag(utag)
    $wcan delete id$id
    MarkBbox $wcan 0 $id
    if {[string equal $rotDrag(type) "arc"]} {
	
	# Get new start angle.
	set start [$wcan itemcget $id -start]
	set cmd [list itemconfigure $utag -start $start]
    } else {
	# Or update all coordinates.
	set cmd [concat coords $utag [$wcan coords $utag]]
    }    
    set undocmd $rotDrag(undocmd)
    set redo [list ::CanvasUtils::Command $w $cmd]
    set undo [list ::CanvasUtils::Command $w $undocmd]
    ::CanvasUtils::Command $w $cmd remote
    undo::add [::WB::GetUndoToken $w] $undo $redo	    
    unset -nocomplain rotDrag
}

#--- End of rotate tool --------------------------------------------------------

namespace eval ::CanvasDraw:: {
    
    variable itemImagesDeleted {}
}

# CanvasDraw::DeleteCurrent --
# 
#       Bindings to the 'std' tag.

proc ::CanvasDraw::DeleteCurrent {wcan} {

    set utag [::CanvasUtils::GetUtag $wcan current]
    if {$utag ne ""} {
	DeleteIds $wcan $utag all
    }
}

proc ::CanvasDraw::DeleteSelected {wcan} {
    
    set ids [$wcan find withtag selected&&!locked]
    if {$ids == {}} {
	return
    }
    DeleteIds $wcan $ids all
    set w [winfo toplevel $wcan]
    ::CanvasCmd::DeselectAll $w
}

# CanvasDraw::DeleteIds --
# 
# 

proc ::CanvasDraw::DeleteIds {wcan ids where args} {
    global  prefs this
    variable itemImagesDeleted

    ::Debug 6 "::CanvasDraw::DeleteIds ids=$ids"
    
    array set argsArr {
	-trashunusedimages 1
    }
    array set argsArr $args
    set trashImages $argsArr(-trashunusedimages)
    set w [winfo toplevel $wcan]

    # List of canvas commands without widget path.
    set cmdList {}
    
    # List of complete commands.
    set redoCmdList {}
    set undoCmdList {}
    
    foreach id $ids {
	set utag [::CanvasUtils::GetUtag $wcan $id]
	if {$utag eq ""} {
	    continue
	}
	set tags [$wcan gettags $id]
	set type [$wcan type $id]
	set havestd [expr [lsearch -exact $tags std] < 0 ? 0 : 1]
	
	# We are only allowed to delete 'std' items.
	switch -glob -- $type,$havestd {
	    image,1 {
		set cmd [list delete $utag]
		lappend cmdList $cmd
		lappend undoCmdList [::CanvasUtils::GetUndoCommand $w $cmd]
		if {$trashImages} {
		    lappend itemImagesDeleted [$wcan itemcget $id -image]
		}
	    } 
	    window,* {
		set cmd [list delete $utag]
		lappend cmdList $cmd
		set win [$wcan itemcget $utag -window]
		lappend redoCmdList [list destroy $win]		
		lappend undoCmdList [::CanvasUtils::GetUndoCommand $w $cmd]
	    }
	    *,1 {
		set cmd [list delete $utag]
		lappend cmdList $cmd
		lappend undoCmdList [::CanvasUtils::GetUndoCommand $w $cmd]
	    }
	    default {
		
		# A non window item witout 'std' tag.
		# Look for any Itcl object with a Delete method.
		if {$this(package,Itcl)} {
		    if {[regexp {object:([^ ]+)} $tags match object]} {
			if {![catch {
			    set objdel [$object Delete $id]
			}]} {
			    if {[llength $objdel] == 2} {
				lassign $objdel del undo
				if {$del != {}} {
				    lappend cmdList $del
				    if {$undo != {}} {
					lappend undoCmdList $undo
				    }
				}
			    }
			}
		    }
		}
	    }
	}
    }
    
    # Manufacture complete commands.
    set canRedo [list ::CanvasUtils::CommandList $w $cmdList $where]
    set redo [list ::CanvasDraw::EvalCommandList  \
      [concat [list $canRedo] $redoCmdList]]
    set undo [list ::CanvasDraw::EvalCommandList $undoCmdList]
    
    eval $redo
    undo::add [::WB::GetUndoToken $w] $undo $redo

    # Garbage collect unused images with 'std' tag.
    GarbageUnusedImages
}

# CanvasDraw::GarbageUnusedImages --
# 
#       Handle image garbage collection for 'std' image items.
#       Only for deleted ones. Else see Whiteboard.tcl

proc ::CanvasDraw::GarbageUnusedImages { } {
    variable itemImagesDeleted
    
    # Image garbage collection. TEST!
    set ims {}
    foreach name [lsort -unique $itemImagesDeleted] {
	if {![image inuse $name]} {
	    lappend ims $name
	}
    }
    eval {image delete} $ims
    set itemImagesDeleted {}
}

proc ::CanvasDraw::AddGarbageImages {name args} {
    variable itemImagesDeleted

    eval {lappend itemImagesDeleted $name} $args
}

# CanvasDraw::DeleteFrame --
# 
#       Generic binding for deleting a frame that typically contains
#       something from a plugin. 
#       Note that this is trigger by the frame's event handler and not the 
#       canvas!
#       
# Arguments:
#       wcan
#       wframe the frame widget.
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
    set w [winfo toplevel $wcan]
    set cmdList {}
    set canUndoList {}
    set undoCmdList {}
    
    set utag [::CanvasUtils::GetUtagFromWindow $wframe]
    if {$utag eq ""} {
	return
    }
    
    # Delete both the window item and the window (with subwindows).
    lappend cmdList [list delete $utag]
    set extraCmd [list destroy $wframe]
    
    set redo [list ::CanvasUtils::CommandList $w $cmdList $where]
    set redo [list ::CanvasDraw::EvalCommandList [list $redo $extraCmd]]
        
    # We need to reconstruct how it was imported.
    set undo [::CanvasUtils::GetUndoCommand $w [list delete $utag]]
    eval $redo
    undo::add [::WB::GetUndoToken $w] $undo $redo
}

# CanvasDraw::DeleteWindow --
# 
#       Generic binding for deleting a window that typically contains
#       something from a plugin. 
#       
# Arguments:
#       wcan
#       win    the frame widget.
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
    set w [winfo toplevel $wcan]
    set cmdList {}
    set canUndoList {}
    set undoCmdList {}
    
    set utag [::CanvasUtils::GetUtagFromWindow $win]
    if {$utag eq ""} {
	return
    }
    
    # Delete both the window item and the window (with subwindows).
    lappend cmdList [list delete $utag]
    set extraCmd [list destroy $win]
    
    set redo [list ::CanvasUtils::CommandList $w $cmdList $where]
    set redo [list ::CanvasDraw::EvalCommandList [list $redo $extraCmd]]
        
    # We need to reconstruct how it was imported.
    set undo [::CanvasUtils::GetUndoCommand $w [list delete $utag]]
    eval $redo
    undo::add [::WB::GetUndoToken $w] $undo $redo
}

proc ::CanvasDraw::PointButton {wcan x y {modifier {}}} {
    
    if {[string equal $modifier "shift"]} {
	MarkBbox $wcan 1
    } else {
	MarkBbox $wcan 0
    }
}

# CanvasDraw::MarkBbox --
#
#        Administrates a selection, drawing, ui etc.
#       
# Arguments:
#       wcan        the canvas widget.
#       shift       If 'shift', then just select item, else deselect all 
#                   other first.
#       which       can either be "current", another tag, or an id.
#       
# Results:
#       none

proc ::CanvasDraw::MarkBbox {wcan shift {which current}} {
    global  prefs kGrad2Rad
    
    Debug 3 "MarkBbox:: wcan=$wcan, shift=$shift, which=$which"

    set w [winfo toplevel $wcan]
    
    # If no shift key, deselect all.
    if {$shift == 0} {
	::CanvasCmd::DeselectAll $w
    }
    set id [$wcan find withtag $which]
    if {$id eq ""} {
	return
    }
    set utag [::CanvasUtils::GetUtag $wcan $which]
    if {$utag eq ""} {
	return
    }
    if {[lsearch [$wcan gettags $id] "std"] < 0} {
	return
    }
    
    # If already selected, and shift clicked, deselect.
    if {$shift == 1} {
	if {[IsSelected $wcan $id]} {
	    $wcan delete tbbox&&id:${id}
	    $wcan dtag $id selected
	    return
	}
    }    
    SelectItem $wcan $which
    focus $wcan
        
    # Testing..
    selection own -command [list ::CanvasDraw::LostSelection $w] $wcan
}

proc ::CanvasDraw::SelectItem {wcan which} {
    
    # Add tag 'selected' to the selected item. Indicate to which item id
    # a marker belongs with adding a tag 'id$id'.
    set type [$wcan type $which]
    $wcan addtag "selected" withtag $which
    set id [$wcan find withtag $which]
    if {[::CanvasUtils::IsLocked $wcan $id]} {
	set tmark [list tbbox $type id:${id} locked]	
    } else {
	set tmark [list tbbox $type id:${id}]
    }
    DrawItemSelection $wcan $which $tmark
}

proc ::CanvasDraw::DeselectItem {wcan which} {
    
    set id [$wcan find withtag $which]
    $wcan delete tbbox&&id:${id}
    $wcan dtag $id selected
}

proc ::CanvasDraw::DeleteSelection {wcan which} {
    
    set id [$wcan find withtag $which]
    $wcan delete tbbox&&id:${id}
    $wcan dtag $id selected
}

proc ::CanvasDraw::IsSelected {wcan which} {
    
    return [expr [lsearch [$wcan gettags $which] "selected"] < 0 ? 0 : 1]
}

proc ::CanvasDraw::AnySelected {wcan} {
    
    return [expr {[$wcan find withtag "selected"] eq ""} ? 0 : 1]
}

# CanvasDraw::DrawItemSelection --
# 
#       Does the actual drawing of any selection.

proc ::CanvasDraw::DrawItemSelection {wcan which tmark} {
    global  prefs kGrad2Rad
        
    set type [$wcan type $which]
    set bbox [$wcan bbox $which]
    set id   [$wcan find withtag $which]

    set w [winfo toplevel $wcan]
    set a  [option get $w aSelect {}]
    if {[::CanvasUtils::IsLocked $wcan $id]} {
	set fg [option get $w fgSelectLocked {}]
    } else {
	set fg [option get $w fgSelectNormal {}]
    }

    # If mark the bounding box. Also for all "regular" shapes.
    
    if {$prefs(bboxOrCoords) || ($type eq "oval") || ($type eq "text")  \
      || ($type eq "rectangle") || ($type eq "image")} {

	foreach {x1 y1 x2 y2} $bbox break
	$wcan create rectangle [expr $x1-$a] [expr $y1-$a] [expr $x1+$a] [expr $y1+$a] \
	  -tags $tmark -fill white -outline $fg
	$wcan create rectangle [expr $x1-$a] [expr $y2-$a] [expr $x1+$a] [expr $y2+$a] \
	  -tags $tmark -fill white -outline $fg
	$wcan create rectangle [expr $x2-$a] [expr $y1-$a] [expr $x2+$a] [expr $y1+$a] \
	  -tags $tmark -fill white -outline $fg
	$wcan create rectangle [expr $x2-$a] [expr $y2-$a] [expr $x2+$a] [expr $y2+$a] \
	  -tags $tmark -fill white -outline $fg
    } else {
	
	set coords [$wcan coords $which]
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
	    set startAng [$wcan itemcget $id -start]
	    set extentAng [$wcan itemcget $id -extent]
	    set xstart [expr $cx + $r * cos($kGrad2Rad * $startAng)]
	    set ystart [expr $cy - $r * sin($kGrad2Rad * $startAng)]
	    set xfin [expr $cx + $r * cos($kGrad2Rad * ($startAng + $extentAng))]
	    set yfin [expr $cy - $r * sin($kGrad2Rad * ($startAng + $extentAng))]
	    $wcan create rectangle [expr $xstart-$a] [expr $ystart-$a]   \
	      [expr $xstart+$a] [expr $ystart+$a] -tags $tmark -fill white \
	      -outline $fg
	    $wcan create rectangle [expr $xfin-$a] [expr $yfin-$a]   \
	      [expr $xfin+$a] [expr $yfin+$a] -tags $tmark -fill white \
	      -outline $fg
	    
	} else {
	    
	    # Mark each coordinate. {x0 y0 x1 y1 ... }
	    foreach {x y} $coords {
		$wcan create rectangle [expr $x-$a] [expr $y-$a] [expr $x+$a] [expr $y+$a] \
		  -tags $tmark -fill white -outline $fg
	    }
	}
    }
}

# CanvasDraw::LostSelection --
#
#       Lost selection to other window. Deselect only if same toplevel.

proc ::CanvasDraw::LostSelection {w} {
    
    if {$w == [selection own]} {
	::CanvasCmd::DeselectAll $w
    }
}

proc ::CanvasDraw::SyncMarks {w} {

    set wcan [::WB::GetCanvasFromWtop $w]
    $wcan delete withtag tbbox
    foreach id [$wcan find withtag "selected"] {
	MarkBbox $wcan 1 $id	
    }
}
    
#--- Various assistant procedures ----------------------------------------------

# CanvasDraw::ToScroll --
# 
#       Confine movement to the canvas scrollregion.
#       
# Arguments:
#       wcan   the canvas widget.
#       tag
#       x0,y0  present "mouse point"
#       x,y    the mouse coordinates.
#       type   item type (rectangle, oval, ...).
#       
# Results:
#       none

proc ::CanvasDraw::ToScroll {wcan tag x0 y0 x y} {

    # @@@ In order to speed up things we could get this at init move and
    # update it ourselves.
    set bbox   [$wcan bbox $tag]
    set scroll [$wcan cget -scrollregion]
    set inset  [$wcan cget -highlightthickness]
    lassign $bbox X0 Y0 X1 Y1
    lassign $scroll XS0 YS0 XS1 YS1
    
    set dx [expr {$x - $x0}]
    set dy [expr {$y - $y0}]
    
    if {$dx < 0} {
	if {($X0 < 0) || ([expr {$dx + $X0}] < 0)} {
	    set x [expr {$x0 - $X0}]
	}
    } elseif {$dx > 0} {
	if {($X1 > $XS1) || ([expr {$dx + $X1}] > $XS1)} {
	    set x [expr {$x0 + $XS1 - $X1}]	    
	}
    }
    if {$dy < 0} {
	if {($Y0 < 0) || ([expr {$dy + $Y0}] < 0)} {
	    set y [expr {$y0 - $Y0}]
	}
    } elseif {$dy > 0} {
	if {($Y1 > $YS1) || ([expr {$dy + $Y1}] > $YS1)} {
	    set y [expr {$y0 + $YS1 - $Y1}]	    
	}
    }    
    return [list $x $y]
}

proc ::CanvasDraw::XYToScroll {wcan x y} {
    
    set scroll [$wcan cget -scrollregion]
    lassign $scroll X0 Y0 X1 Y1
    set x [expr {$x < $X0 ? $X0 : $x}]
    set y [expr {$y < $Y0 ? $Y0 : $y}]
    set x [expr {$x > $X1 ? $X1 : $x}]
    set y [expr {$y > $Y1 ? $Y1 : $y}]
    return [list $x $y]
}

proc ::CanvasDraw::ItemInsideScroll {wcan tag} {
    
    return [BboxInsideScroll $wcan [$wcan bbox $tag]]
}

proc ::CanvasDraw::BboxInsideScroll {wcan bbox} {

    set scroll [$wcan cget -scrollregion]
    set inset  [$wcan cget -highlightthickness]
    lassign $bbox X0 Y0 X1 Y1
    lassign $scroll XS0 YS0 XS1 YS1
    
    if {$X0 < $XS0} {
	return 0
    } elseif {$X1 > $XS1} {
	return 0
    } elseif {$Y0 < $XS0} {
	return 0
    } elseif {$Y1 > $YS1} {
	return 0
    } else {
	return 1
    }
}

proc ::CanvasDraw::ResizeBbox {bbox add} {
    
    lassign $bbox X0 Y0 X1 Y1
    return [list  \
      [expr {$X0-$add}] [expr {$Y0-$add}]  \
      [expr {$X1+$add}] [expr {$Y1+$add}]]
}

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
	set deltax [expr {int($x - $xanch)}]
	set deltay [expr {int($y - $yanch)}]
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

proc ::CanvasDraw::MakeSpeechBubble {wcan id} {
    
    set w [winfo toplevel $wcan]
    set bbox [$wcan bbox $id]
    set utagtext [::CanvasUtils::GetUtag $wcan $id]
    foreach {utag redocmd} [::CanvasDraw::SpeechBubbleCmd $wcan $bbox] break
    set undocmd [list delete $utag]
    set cmdLower [list lower $utag $utagtext]
    
    set redo [list ::CanvasUtils::CommandList $w [list $redocmd $cmdLower]]
    set undo [list ::CanvasUtils::Command $w $undocmd]
    eval $redo
    undo::add [::WB::GetUndoToken $w] $undo $redo
}

proc ::CanvasDraw::SpeechBubbleCmd {wcan bbox args} {
    
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
	set r [ThreePointRadius [list $x1 $y1 $x2 $y2 $x3 $y3]]
	
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
	lappend rlist [ThreePointRadius  \
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