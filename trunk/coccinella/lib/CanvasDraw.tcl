#  CanvasDraw.tcl ---
#  
#      This file is part of the whiteboard application. It implements the
#      drawings commands associated with the tools.
#      
#  Copyright (c) 2000-2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: CanvasDraw.tcl,v 1.3 2003-02-06 17:23:33 matben Exp $

#  All code in this file is placed in one common namespace.

package provide CanvasDraw 1.0

namespace eval ::CanvasDraw:: {
    
    # Not sure that all should be exported.
    namespace export InitMove DoMove FinalizeMove
    namespace export InitBox BoxDrag FinalizeBox
    namespace export InitArc ArcDrag FinalizeArc ArcCancel
    namespace export InitLine LineDrag FinalizeLine
    namespace export InitStroke StrokeDrag FinalizeStroke
    namespace export PolySetPoint PolyDrag FinalizePoly
    namespace export InitRotateItem DoRotateItem FinalizeRotate
    namespace export DoPaint
    namespace export DeleteItem ConstrainedDrag
    
    # Arrays that collects a information needed for the move, box etc..
    # Is unset when finished.
    variable xDrag
    variable theBox
    variable arcBox
    variable thePoly
    variable theLine
    variable stroke
    variable rotDrag
}

#--- The 'move' tool procedures ------------------------------------------------

# CanvasDraw::InitMove --
#
#       Initializes a move operation.
#   
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       'what' = "item": move an ordinary item.
#       'what' = "point": move one single point. Has always first priority.
#       'what' = "movie": QuickTime movie, make ghost rectangle instead.
#       
# Results:
#       none

proc ::CanvasDraw::InitMove {w x y {what item}} {
    global  kGrad2Rad
    
    variable  xDrag
    
    Debug 2 "InitMove:: w=$w, x=$x, y=$y, what=$what"
    
    # If more than one item triggered, choose the "point".
    if {[info exists xDrag(what)] && $xDrag(what) == "point"} {
	Debug 2 "  InitMove:: rejected"
	return
    }
    set id_ {[0-9]+}
    set xDrag(what) $what
    set xDrag(baseX) $x
    set xDrag(baseY) $y
    set xDrag(anchorX) $x
    set xDrag(anchorY) $y
    
    # In some cases we need the anchor point to be an exact item 
    # specific coordinate.
    
    set xDrag(type) [$w type current]
    
    # Are we moving one point of a single segment line?
    set xDrag(singleSeg) 0
    
    if {$what == "movie"} {
	
	# If movie then make ghost rectangle. 
	# Movies (and windows) do not obey the usual stacking order!
	
	set id [::CanvasUtils::FindTypeFromOverlapping $w $x $y "movie"]
	if {$id == ""} {
	    return
	}
	set it [::CanvasUtils::GetUtag $w $id]
	if {$it == ""} {
	    return
	}
	set xDrag(undocmd) "coords $it [$w coords $id]"
	$w addtag selectedmovie withtag $id
	set bbox [$w bbox $id]
	set x1 [expr [lindex $bbox 0] - 1]
	set y1 [expr [lindex $bbox 1] - 1]
	set x2 [expr [lindex $bbox 2] + 1]
	set y2 [expr [lindex $bbox 3] + 1]
	$w create rectangle $x1 $y1 $x2 $y2 -outline gray50 -width 3 \
	  -stipple gray50 -tags "ghostrect"	
    } elseif {$what == "point"} {
	
	# Moving a marker of a selected item, highlight marker.
	# 'current' must be a marker with tag 'tbbox'.
	
	set id [$w find withtag current]
	$w addtag hitBbox withtag $id
	
	# Find associated id for the actual item. Saved in the tags of the marker.
	if {![regexp " +id($id_)" [$w gettags current] match theItemId]} {
	    #puts "no match: w gettags current=[$w gettags current]"
	    return
	}
	set xDrag(type) [$w type $theItemId]
	if {($xDrag(type) == "text") || ($xDrag(type) == "image")} {
	    #unset xDrag
	    return
	}
	
	# Make a highlightbox at the 'hitBbox' marker.
	set bbox [$w bbox $id]
	set x1 [expr [lindex $bbox 0] - 1]
	set y1 [expr [lindex $bbox 1] - 1]
	set x2 [expr [lindex $bbox 2] + 1]
	set y2 [expr [lindex $bbox 3] + 1]
	$w create rectangle $x1 $y1 $x2 $y2 -outline black -width 1 \
	  -tags "lightBbox id$theItemId" -fill white
	
	# Get the index of the coordinates that was 'hit'. Then update only
	# this coordinate when moving.
	# For rectangle and oval items a list with all four coordinates is used,
	# but only the hit corner and the diagonally opposite one are kept.
	
	set oldCoords [$w coords $theItemId]
	if {[string equal $xDrag(type) "rectangle"] ||  \
	  [string equal $xDrag(type) "oval"]} {
	    
	    # Need to reconstruct all four coordinates as: 0---1
	    #                                              |   |
	    #                                              2---3
	    set fullListCoords [concat   \
	      [lindex $oldCoords 0] [lindex $oldCoords 1]  \
	      [lindex $oldCoords 2] [lindex $oldCoords 1]  \
	      [lindex $oldCoords 0] [lindex $oldCoords 3]  \
	      [lindex $oldCoords 2] [lindex $oldCoords 3] ]
	} else {
	    set fullListCoords $oldCoords
	}
	
	# Deal first with the arc points.
	if {[string equal $xDrag(type) "arc"]} {
	    set xDrag(coords) $fullListCoords
	    
	    # Some geometry. We have got the coordinates defining the box.
	    # Find out if we clicked the 'start' or 'extent' "point".
	    # Tricky part: be sure that the branch cut is at +-180 degrees!
	    # 'itemcget' gives angles 0-360, while atan2 gives -180-180.
	    set xDrag(arcX) $x
	    set xDrag(arcY) $y
	    set theCoords $xDrag(coords)
	    foreach {x1 y1 x2 y2} $fullListCoords { break }
	    set r [expr abs(($x1 - $x2)/2.0)]
	    set cx [expr ($x1 + $x2)/2.0]
	    set cy [expr ($y1 + $y2)/2.0]
	    set xDrag(arcCX) $cx
	    set xDrag(arcCY) $cy
	    set startAng [$w itemcget $theItemId -start]
	    
	    # Put branch cut at +-180!
	    if {$startAng > 180} {
		set startAng [expr $startAng - 360]
	    }
	    set extentAng [$w itemcget $theItemId -extent]
	    set xstart [expr $cx + $r * cos($kGrad2Rad * $startAng)]
	    set ystart [expr $cy - $r * sin($kGrad2Rad * $startAng)]
	    set xfin [expr $cx + $r * cos($kGrad2Rad * ($startAng + $extentAng))]
	    set yfin [expr $cy - $r * sin($kGrad2Rad * ($startAng + $extentAng))]
	    set dstart [expr hypot($xstart - $x,$ystart - $y)]
	    set dfin [expr hypot($xfin - $x,$yfin - $y)]
	    set xDrag(arcStart) $startAng
	    set xDrag(arcExtent) $extentAng
	    set xDrag(arcFin) [expr $startAng + $extentAng]
	    if {$dstart < $dfin} {
		set xDrag(arcHit) "start"
	    } else {
		set xDrag(arcHit) "extent"
	    }
	    set xDrag(undocmd)  \
	      "itemconfigure $theItemId -start $startAng -extent $extentAng"
	    
	} else {
	    
	    # Deal with other item points.
	    # Find the one closest to the hit marker.
	    
	    set xDrag(undocmd) "coords $theItemId [$w coords $theItemId]"
	    set n [llength $fullListCoords]
	    set minDist 1000
	    for {set i 0} {$i < $n} {incr i 2} {
		set len [expr hypot([lindex $fullListCoords $i] - $x,  \
		  [lindex $fullListCoords [expr $i + 1]] - $y)]
		if {$len < $minDist} {
		    set ind $i
		    set minDist $len
		}
	    }
	    set ptInd [expr $ind/2]
	    if {[string equal $xDrag(type) "rectangle"] ||  \
	      [string equal $xDrag(type) "oval"]} {
		
		# Keep only hit corner and the diagonally opposite one.
		set coords [concat [lindex $fullListCoords $ind]  \
		  [lindex $fullListCoords [expr $ind + 1]] ]
		if {$ptInd == 0} {
		    set coords [lappend coords    \
		      [lindex $fullListCoords 6] [lindex $fullListCoords 7] ]
		} elseif {$ptInd == 1} {
		    set coords [lappend coords    \
		      [lindex $fullListCoords 4] [lindex $fullListCoords 5] ]
		} elseif {$ptInd == 2} {
		    set coords [lappend coords    \
		      [lindex $fullListCoords 2] [lindex $fullListCoords 3] ]
		} elseif {$ptInd == 3} {
		    set coords [lappend coords    \
		      [lindex $fullListCoords 0] [lindex $fullListCoords 1] ]
		}	    
		set ind 0
		set fullListCoords $coords
	    }
	    
	    # If moving a single line segment with shift, we need the
	    # anchor point to be the "other" point.
	    if {[string equal $xDrag(type) "line"] &&  \
	      ([llength $oldCoords] == 4)} {
		set xDrag(singleSeg) 1
		# Other point denoted remote x and y.
		if {$ind == 0} {
		    set xDrag(remX) [lindex $oldCoords 2]
		    set xDrag(remY) [lindex $oldCoords 3]
		} else {
		    set xDrag(remX) [lindex $oldCoords 0]
		    set xDrag(remY) [lindex $oldCoords 1]
		}
	    }
	    set xDrag(hitInd) $ind
	    set xDrag(coords) $fullListCoords
	}
	
    } elseif {$what == "item"} {

	# Add specific tag to the item being moved for later use.
	set id [$w find withtag current]	
	$w addtag ismoved withtag $id
    }
}

# CanvasDraw::DoMove --
#
#       If selected items, move them, else move current item if exists.
#       It uses the xDrag array to keep track of start and current position.
#   
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       'what' = "item": move an ordinary item.
#       'what' = "point": move one single point. Has always first priority.
#       'what' = "movie": QuickTime movie, make ghost rectangle instead.
#       shift  constrains the movement.
#       
# Results:
#       none

proc ::CanvasDraw::DoMove {w x y what {shift 0}} {
    global  kGrad2Rad kRad2Grad
    
    variable  xDrag

    if {![info exists xDrag]} {
	return
    }
    
    # If we drag a point, then reject events triggered by non-point events.
    if {[string equal $xDrag(what) "point"] && ![string equal $what "point"]} {
	return
    }
    
    # If dragging 'point' (marker) of a fixed size item, return.
    if {[string equal $xDrag(what) "point"] &&   \
      ( [string equal $xDrag(type) "text"] ||  \
      [string equal $xDrag(type) "image"] )} {
	return
    }
    set id_ {[0-9]+}

    # If constrained to 90/45 degrees.
    # Should this be item dependent?
    if {$shift} {
	if {[string equal $xDrag(what) "point"] &&  \
	  [string equal $xDrag(type) "arc"]} {
	    set newco [ConstrainedDrag $x $y $xDrag(arcCX) $xDrag(arcCY)]
	} else {
	    # Are we moving one point of a single segment line?
	    if {$xDrag(singleSeg)} {
		set newco [ConstrainedDrag $x $y $xDrag(remX) $xDrag(remY)]
	    } else {
		set newco [ConstrainedDrag $x $y $xDrag(anchorX) $xDrag(anchorY)]
	    }
	}
	foreach {x y} $newco { break }
    }
    
    # First, get canvas objects with tag 'selected'.
    set ids [$w find withtag selected]
    if {[string equal $what "item"]} {
	
	# If no selected items.
	if {[string length $ids] == 0} {
	    
	    # Be sure to exclude nonmovable items.
	    set tagsCurrent [$w gettags current]
	    set it [::CanvasUtils::GetUtag $w current]
	    if {[string length $it] == 0} {
		return
	    }
	    if {[lsearch $tagsCurrent grid] >= 0 } {
		return
	    }
	    $w move current [expr $x - $xDrag(baseX)] [expr $y - $xDrag(baseY)]
	} else {
	    
	    # If selected, move all items and markers.
	    foreach id $ids {
		set it [::CanvasUtils::GetUtag $w $id]
		if {$it != ""}  {
		    $w move $id [expr $x - $xDrag(baseX)] [expr $y - $xDrag(baseY)]
		}
	    }
	    
	    # Move markers with them.
	    $w move tbbox [expr $x - $xDrag(baseX)] [expr $y - $xDrag(baseY)]
	} 
    } elseif {[string equal $what "movie"]} {
	
	# Moving a movie.
	$w move ghostrect [expr $x - $xDrag(baseX)] [expr $y - $xDrag(baseY)]
	
    } elseif {[string equal $what "point"]} {
	
	# Find associated id for the actual item. Saved in the tags of the marker.
	if {![regexp " +id($id_)" [$w gettags hitBbox] match theItemId]} {
	    #puts "no match: w gettags hitBbox=[$w gettags hitBbox]"
	    return
	}
	if {[lsearch [$w gettags current] hitBbox] == -1} {
	    #puts "DoMove:: Warning, no match"
	    return
	}
	
	# Find the item type of the item that is marked. Depending on type,
	# do different things.
	
	if {[string equal $xDrag(type) "arc"]} {
	    
	    # Some geometry. We have got the coordinates defining the box.
	    set theCoords $xDrag(coords)
	    foreach {x1 y1 x2 y2} $theCoords { break }
	    set r [expr abs(($x1 - $x2)/2.0)]
	    set cx [expr ($x1 + $x2)/2.0]
	    set cy [expr ($y1 + $y2)/2.0]
	    set startAng [$w itemcget $theItemId -start]
	    set extentAng [$w itemcget $theItemId -extent]
	    set xstart [expr $cx + $r * cos($kGrad2Rad * $startAng)]
	    set ystart [expr $cy - $r * sin($kGrad2Rad * $startAng)]
	    set xfin [expr $cx + $r * cos($kGrad2Rad * ($startAng + $extentAng))]
	    set yfin [expr $cy - $r * sin($kGrad2Rad * ($startAng + $extentAng))]
	    set newAng [expr $kRad2Grad * atan2($cy - $y,-($cx - $x))]
	    
	    # Dragging the 'extent' point or the 'start' point?
	    if {[string compare $xDrag(arcHit) "extent"] == 0} { 
		set extentAng [expr $newAng - $xDrag(arcStart)]
		
		# Same trick as when drawing it; take care of the branch cut.
		if {$xDrag(arcExtent) - $extentAng > 180} {
		    set extentAng [expr $extentAng + 360]
		} elseif {$xDrag(arcExtent) - $extentAng < -180} {
		    set extentAng [expr $extentAng - 360]
		}
		set xDrag(arcExtent) $extentAng
		
		# Update angle.
		$w itemconfigure $theItemId -extent $extentAng
		
		# Move highlight box.
		$w move hitBbox [expr $xfin - $xDrag(arcX)]   \
		  [expr $yfin - $xDrag(arcY)]
		$w move lightBbox [expr $xfin - $xDrag(arcX)]   \
		  [expr $yfin - $xDrag(arcY)]
		set xDrag(arcX) $xfin
		set xDrag(arcY) $yfin
		
	    } elseif {[string equal $xDrag(arcHit) "start"]} {

		# Need to update start angle as well as extent angle.
		set newExtentAng [expr $xDrag(arcFin) - $newAng]
		# Same trick as when drawing it; take care of the branch cut.
		if {$xDrag(arcExtent) - $newExtentAng > 180} {
		    set newExtentAng [expr $newExtentAng + 360]
		} elseif {$xDrag(arcExtent) - $newExtentAng < -180} {
		    set newExtentAng [expr $newExtentAng - 360]
		}
		set xDrag(arcExtent) $newExtentAng
		set xDrag(arcStart) $newAng
		$w itemconfigure $theItemId -start $newAng
		$w itemconfigure $theItemId -extent $newExtentAng
		
		# Move highlight box.
		$w move hitBbox [expr $xstart - $xDrag(arcX)]   \
		  [expr $ystart - $xDrag(arcY)]
		$w move lightBbox [expr $xstart - $xDrag(arcX)]   \
		  [expr $ystart - $xDrag(arcY)]
		set xDrag(arcX) $xstart
		set xDrag(arcY) $ystart
	    }
	} else {

	    set ind $xDrag(hitInd)
	    set newCoords [lreplace $xDrag(coords) $ind [expr $ind + 1] $x $y]
	    eval $w coords $theItemId $newCoords
	    $w move hitBbox [expr $x - $xDrag(baseX)] [expr $y - $xDrag(baseY)]
	    $w move lightBbox [expr $x - $xDrag(baseX)] [expr $y - $xDrag(baseY)]
	}
    }
    set xDrag(baseX) $x
    set xDrag(baseY) $y
}

# CanvasDraw::FinalizeMove --
#
#       Finished moving using DoMove. Make sure that all connected clients
#       also moves either the selected items or the current item.
#   
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       'what' = "item": move an ordinary item.
#       'what' = "point": move one single point. Has always first priority.
#       'what' = "movie": QuickTime movie, make ghost rectangle instead.
#       
# Results:
#       none

proc ::CanvasDraw::FinalizeMove {w x y {what item}} {
    
    variable  xDrag
    
    Debug 2 "FinalizeMove:: what=$what, info exists xDrag=[info exists xDrag]"

    if {![info exists xDrag]} {
	return
    }
    
    # If we drag a point, then reject events triggered by non-point events.
    if {$xDrag(what) == "point" && $what != "point"} {
	return
    }
    set id_ {[0-9]+}
    
    # Get item(s).
    # First, get canvas objects with tag 'selected', 'ismoved' or 'selectedmovie'.
    
    set ids [$w find withtag selected]
    if {[string equal $what "movie"]} {
	set id [$w find withtag selectedmovie]
    } else {
	set id [$w find withtag ismoved]
    }
    set theItno [::CanvasUtils::GetUtag $w $id]
    Debug 2 "  FinalizeMove:: ids=$ids, id=$id, theItno=$theItno, x=$x, y=$y"

    if {[string equal $what "item"] && $ids == "" && $theItno == ""} {
	return
    }
    
    # Find item tags ('theItno') for the items being moved.
    if {[string equal $what "item"] || [string equal $what "movie"]} {
	
	# If no selected items.
	if {$ids == ""} {
	    
	    # We already have 'theItno' from above.
	} else {
	    
	    # If selected, move all items.
	    set theItno {}
	    foreach id $ids {
		lappend theItno [::CanvasUtils::GetUtag $w $id]
	    }
	} 
	
    } elseif {[string equal $what "point"]} {
	
	# Dragging points of items.
	# Find associated id for the actual item. Saved in the tags of the marker.
	
	if {![regexp " +id($id_)" [$w gettags current] match theItemId]} {
	    #puts "no match: w gettags current=[$w gettags current]"
	    return
	}
	set theItno [::CanvasUtils::GetUtag $w $theItemId]
	if {$theItno == ""} {
	    return
	}
	
	# If endpoints overlap in line item, make closed polygon.
	# Find out if closed polygon or open line item. If closed, remove duplicate.
	set isClosed 0
	if {[string equal $xDrag(type) "line"]} {
	    set n [llength $xDrag(coords)]
	    set len [expr hypot(  \
	      [lindex $xDrag(coords) [expr $n - 2]] -  \
	      [lindex $xDrag(coords) 0],  \
	      [lindex $xDrag(coords) [expr $n - 1]] -  \
	      [lindex $xDrag(coords) 1] )]
	    if {$len < 8} {
		
		# Make the line segments to a closed polygon.
		set isClosed 1
		# Get all actual options.
		set opcmd [::CanvasUtils::GetItemOpts $w $theItemId]
		set theCoords [$w coords $theItemId]
		set polyCoords [lreplace $theCoords end end]
		set polyCoords [lreplace $polyCoords end end]
		set cmd1 [list $w delete $theItemId]
		eval $cmd1
		
		# Make the closed polygon. Get rid of non-applicable options.
		foreach op {-arrow -arrowshape -capstyle -joinstyle} {
		    set ind [lsearch -exact $opcmd $op]
		    if {$ind >= 0} {
			set opcmd [lreplace $opcmd $ind [expr $ind + 1]]
		    }
		}
		
		# Replace -fill with -outline.
		set ind [lsearch -exact $opcmd "-fill"]
		if {$ind >= 0} {
		    set opcmd [lreplace $opcmd $ind $ind "-outline"]
		}
		set opcmd [concat $opcmd "-fill {}"]
		
		# Update the new item id.
		set cmd2 "$w create polygon $polyCoords $opcmd"
		set theItemId [eval {$w create polygon} $polyCoords $opcmd]
	    }
	}
	if {!$isClosed} {
	    if {[string equal $xDrag(type) "arc"]} {
		
		# The arc item: update both angles.
		set cmd "itemconfigure $theItno -start $xDrag(arcStart)   \
		  -extent $xDrag(arcExtent)"
	    } else {
		
		# Not arc, and not closed line item.
		set cmd "coords $theItno [$w coords $theItno]"
	    }
	}
	
	# Move all markers along.
	$w delete id$theItemId
	MarkBbox $w 0 $theItemId
    }
    
    # For QT movies: move the actual movie to the position of the ghost rectangle.
    if {[string equal $what "movie"]} {
	$w move selectedmovie [expr $x - $xDrag(anchorX)]  \
	  [expr $y - $xDrag(anchorY)]
	$w dtag selectedmovie selectedmovie
	set cmd "coords $theItno [$w coords $theItno]"
    }
    
    # Delete the ghost rect or highlighted marker if any. Remove temporary tags.
    $w delete ghostrect
    $w delete lightBbox
    $w dtag all hitBbox 
    $w dtag all ismoved
    set wtop [::UI::GetToplevelNS $w]
    
    # Do send to all connected.
    if {[string equal $what "point"]} {
	if {$isClosed} {
	    set redo [list ::CanvasUtils::CommandList $wtop [list $cmd1 $cmd2]]
	} else {
	    set redo [list ::CanvasUtils::Command $wtop $cmd]
	}
	set undo [list ::CanvasUtils::Command $wtop $xDrag(undocmd)]
    } elseif {[string equal $what "movie"]} {
	set redo [list ::CanvasUtils::Command $wtop $cmd]
	set undo [list ::CanvasUtils::Command $wtop $xDrag(undocmd)]
    } else {
	
	# Have moved a bunch of ordinary items. Images coords?
	set dx [expr $x - $xDrag(anchorX)]
	set dy [expr $y - $xDrag(anchorY)]
	set mdx [expr -$dx]
	set mdy [expr -$dy]
	set cmdList {}
	set cmdUndoList {}
	foreach it $theItno {
	    lappend cmdList [list move $it $dx $dy]
	    lappend cmdUndoList [list move $it $mdx $mdy]
	}
	set redo [list ::CanvasUtils::CommandList $wtop $cmdList]
	set undo [list ::CanvasUtils::CommandList $wtop $cmdUndoList]
    }
    eval $redo "remote"
    undo::add [::UI::GetUndoToken $wtop] $undo $redo
	
    catch {unset xDrag}
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
#       type   item type (rect, oval, ...).
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
#       type   item type (rect, oval, ...).
#       mark   If not 'mark', then draw ordinary rectangle if 'type' is rect,
#              or oval if 'type' is oval.
#       
# Results:
#       none

proc ::CanvasDraw::BoxDrag {w x y shift type {mark 0}} {
    global  prefs
    
    variable theBox
    set wtop [::UI::GetToplevelNS $w]
    upvar ::${wtop}::state state

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
	if {$state(fill) == 0} {
	    set theBox($w,last) [eval {$w create $type} $boxOrig  \
	      {$x $y -outline $state(fgCol) -width $state(penThick)  \
	      -tags $type} $extras]
	} else {
	    set theBox($w,last) [eval {$w create $type} $boxOrig  \
	      {$x $y -outline $state(fgCol) -fill $state(fgCol)  \
	      -width $state(penThick) -tags $type}  \
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
#       type   item type (rect, oval, ...).
#       mark   If not 'mark', then draw ordinary rectangle if 'type' is rect,
#              or oval if 'type' is oval.
#       
# Results:
#       none

proc ::CanvasDraw::FinalizeBox {w x y shift type {mark 0}} {
    global  prefs
    
    variable theBox
    set wtop [::UI::GetToplevelNS $w]
    upvar ::${wtop}::state state
    
    # If no theBox($w,anchor) defined just return.
    if {![info exists theBox($w,anchor)]}  {
	return
    }
    catch {$w delete $theBox($w,last)}
    foreach {xanch yanch} $theBox($w,anchor) { break }
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
	    append extras " -fill $state(fgCol)"
	}
	set cmd "create $type $boxOrig $x $y	\
	  -tags {$type $utag} -outline $state(fgCol)  \
	  -width $state(penThick) $extras"
	set undocmd "delete $utag"
	set redo [list ::CanvasUtils::Command $wtop $cmd]
	set undo [list ::CanvasUtils::Command $wtop $undocmd]
	eval $redo
	undo::add [::UI::GetUndoToken $wtop] $undo $redo
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
#       With the 'shift' key pressed, the rect and oval items are contrained
#       to squares and circles respectively.
#       
# Arguments:
#       xanch,yanch      the anchor coordinates.
#       x,y    the mouse coordinates.
#       type   item type (rect, oval, ...).
#       
# Results:
#       List of the (two) new coordinates for the item.

proc ::CanvasDraw::ConstrainedBoxDrag {xanch yanch x y type} {
    
    set deltax [expr $x - $xanch]
    set deltay [expr $y - $yanch]
    set prod [expr $deltax * $deltay]
    if {$type == "rect"} {
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
	
	# A pure circle is not made with the bounding rect model.
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
#       type   item type (rect, oval, ...).
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
		    -outline gray50 -fill {} -tag tcent
	    $w create line [expr $x - 5] $y [expr $x + 5] $y -fill gray50 -tag tcent
	    $w create line $x [expr $y - 5] $x [expr $y + 5] -fill gray50 -tag tcent 
	} else {
	    $w create oval [expr $x - 3] [expr $y - 3] [expr $x + 3] [expr $y + 3]  \
		    -outline gray50 -fill {} -tag tcent
	    $w create line [expr $x - 5] $y [expr $x + 6] $y -fill gray50 -tag tcent
	    $w create line $x [expr $y - 5] $x [expr $y + 6] -fill gray50 -tag tcent 
	}
	focus $w
	bind $w <KeyPress-space> {ArcCancel %W}
	::UI::SetStatusMessage $wtop [::msgcat::mc uastatarc2]
	
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
	bind $w <B1-Motion> {ArcDrag %W [%W canvasx %x] [%W canvasy %y]}
	bind $w <Shift-B1-Motion> {ArcDrag %W [%W canvasx %x] [%W canvasy %y] 1}
	bind $w <ButtonRelease-1> {FinalizeArc %W [%W canvasx %x] [%W canvasy %y]}
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
    upvar ::${wtop}::state state

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
	set theFill "-fill {}"
    } else {
	set theFill "-fill $state(fgCol)"
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
    upvar ::${wtop}::state state

    Debug 2 "FinalizeArc:: w=$w"

    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatarc]
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
      -tags {arc $utag} $theFill $extras"
    set undocmd "delete $utag"
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]
    eval $redo
    undo::add [::UI::GetUndoToken $wtop] $undo $redo
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

    ::UI::SetStatusMessage $wtop [::msgcat::mc uastatarc]
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
    bind $w <Motion> {PolyDrag %W [%W canvasx %x] [%W canvasy %y]}
    bind $w <Shift-Motion> {PolyDrag %W [%W canvasx %x] [%W canvasy %y] 1}
    bind $w <KeyPress-space> {FinalizePoly %W [%W canvasx %x] [%W canvasy %y]}
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
    upvar ::${wtop}::state state

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
    upvar ::${wtop}::state state

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
	set theFill "-fill {}"
    } else {
	set theFill "-fill $state(fgCol)"
    }
    if {$prefs(haveDash)} {
	set extras [list -dash $state(dash)]
    } else {
	set extras ""
    }
    set utag [::CanvasUtils::NewUtag]
    if {$isClosed} {
	
	# This is a (closed) polygon.
	set cmd "create polygon $coords -tags {poly $utag}  \
	  -outline $state(fgCol) $theFill -width $state(penThick)  \
	  -smooth $state(smooth) -splinesteps $state(splinesteps) $extras"
    } else {
	
	# This is an open line segment.
	set cmd "create line $coords -tags {poly $utag}  \
	  -fill $state(fgCol) -width $state(penThick)  \
	  -smooth $state(smooth) -splinesteps $state(splinesteps) $extras"
    }
    set undocmd "delete $utag"
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]
    eval $redo
    undo::add [::UI::GetUndoToken $wtop] $undo $redo
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
    upvar ::${wtop}::state state

    # If anchor not set just return.
    if {![info exists theLine($w,anchor)]} {
	return
    }

    catch {$w delete $theLine($w,last)}
    if {[string compare $opt "arrow"] == 0} {
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
    upvar ::${wtop}::state state

    # If anchor not set just return.
    if {![info exists theLine($w,anchor)]} {
	return
    }
    catch {$w delete $theLine($w,last)}

    # If not dragged, zero line, and just return.
    if {![info exists theLine($w,last)]} {
	return
    }
    if {[string compare $opt {arrow}] == 0} {
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
	foreach {x y} $newco { break }
    }
    set utag [::CanvasUtils::NewUtag]
    set cmd "create line $theLine($w,anchor) $x $y	\
      -tags {line $utag} -joinstyle round	\
      -smooth true -fill $state(fgCol) -width $state(penThick) $extras"
    set undocmd "delete $utag"
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]
    eval $redo
    undo::add [::UI::GetUndoToken $wtop] $undo $redo
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
    upvar ::${wtop}::state state

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
    global  prefs allIPnumsToSend
    
    variable stroke
    set wtop [::UI::GetToplevelNS $w]
    upvar ::${wtop}::state state

    Debug 2 "FinalizeStroke::"

    # If stroke not set just return.
    set coords {}
    if {![info exists stroke(N)]} {
	return
    }
    for {set i 0} {$i <= $stroke(N)} {incr i} {
	append coords $stroke($i) " "
    }
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
    set cmd "create line $coords  \
      -tags {line $utag} -joinstyle round  \
      -smooth $state(smooth) -splinesteps $state(splinesteps) \
      -fill $state(fgCol) -width $thisThick $extras"
    set undocmd "delete $utag"
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]
    eval $redo
    undo::add [::UI::GetUndoToken $wtop] $undo $redo
    catch {unset stroke}
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
    upvar ::${wtop}::state state

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
		undo::add [::UI::GetUndoToken $wtop] $undo $redo	    
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
	set rotDrag(undocmd) "coords $it [$w coords $it]"
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
    #puts "InitRotateItem:: rotDrag=[parray rotDrag]"
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
	set cmd "itemconfigure $rotDrag(itno) -start   \
	      [$w itemcget $rotDrag(itno) -start]"
    } else {
	# Or update all coordinates.
	set cmd "coords $rotDrag(itno) [$w coords $rotDrag(id)]"
    }    
    set undocmd $rotDrag(undocmd)
    set redo [list ::CanvasUtils::Command $wtop $cmd]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]
    ::CanvasUtils::Command $wtop $cmd "remote"
    undo::add [::UI::GetUndoToken $wtop] $undo $redo	    
    catch {unset rotDrag}
}

#--- End of rotate tool --------------------------------------------------------

# CanvasDraw::DeleteItem --
#
#       Delete item in canvas. Notifies all other clients.
#   
# Arguments:
#       w      the canvas widget.
#       x,y    the mouse coordinates.
#       id     can be "current", "selected", "movie" or just an id number.
#       where    "all": erase this canvas and all others.
#                "remote": erase only client canvases.
#                "local": erase only own canvas.
#       
# Results:
#       none

proc ::CanvasDraw::DeleteItem {w x y {id current} {where all}} {

    Debug 4 "DeleteItem:: w=$w, x=$x, y=$y, id=$id, where=$where"

    set wtop [::UI::GetToplevelNS $w]
    set cmdList {}
    set undoList {}
    set needDeselect 0
    
    # Get item.
    switch -- $id {
	current {
	    set utag [::CanvasUtils::GetUtag $w current]
	    if {[string length $utag] > 0} {
		lappend cmdList [list delete $utag]
		set opts [::CanvasUtils::GetItemOpts $w $id]
		set undocmd "create [$w type $id] [$w coords $id] $opts"
		lappend undoList $undocmd [::CanvasUtils::GetStackingCmd $w $utag]
	    }
	}
	selected {
	
	    # First, get canvas objects with tag 'selected'.	
	    foreach id [$w find withtag selected] {
		set utag [::CanvasUtils::GetUtag $w $id]
		if {[string length $utag] > 0} {
		    lappend cmdList [list delete $utag]
		    set opts [::CanvasUtils::GetItemOpts $w $id]
		    set undocmd "create [$w type $id] [$w coords $id] $opts"
		    lappend undoList $undocmd  \
		      [::CanvasUtils::GetStackingCmd $w $utag]
		}
	    }
	    set needDeselect 1
	}
	movie {
	    set id [lindex [$w find closest $x $y 3] 0]
	    set utag [::CanvasUtils::GetUtag $w $id]
	    if {[string length $utag] > 0} {
	    
		# Delete both the window item and the window (with subwindows).
		lappend cmdList [list delete $utag]
		set win [$w itemcget $utag -window]
		set extraCmd [list destroy $win]
		
		# We need to reconstruct how it was imported.
		switch -- [winfo class $win] {
		    QTFrame {
			set extraUndo [::ImageAndMovie::QTImportCmd $w $utag]
		    }
		    SnackFrame {
			set extraUndo [::ImageAndMovie::SnackImportCmd $w $utag]
		    }
		    default {
			# ?
		    }
		}
	    }
	}
	window {
	    
	    # Here we may have code to call custom handlers.
	    
	}
	default {
	
	    # 'id' is an actual item number.
	    set utag [::CanvasUtils::GetUtag $w $id]
	    if {[string length $utag] > 0} {
		lappend cmdList [list delete $utag]
		set opts [::CanvasUtils::GetItemOpts $w $id]
		set undocmd "create [$w type $id] [$w coords $id] $opts"
		lappend undoList $undocmd [::CanvasUtils::GetStackingCmd $w $utag]
	    }
	}
    }
    if {[llength $cmdList] == 0} {
	return
    }
    if {[llength $cmdList] > 0} {
	set redo [list ::CanvasUtils::CommandList $wtop $cmdList $where]
	if {[info exists extraCmd]} {
	    set redo [list EvalCommandList [list $redo $extraCmd]]
	}
    }
    if {[llength $undoList] > 0} {
	set undo [list ::CanvasUtils::CommandList $wtop $undoList $where]
	if {[info exists extraUndo]} {
	    set undo [list EvalCommandList [list $undo $extraUndo]]
	}
    } else {
	set undo [list EvalCommandList [list $extraUndo]]
    }
    eval $redo
    undo::add [::UI::GetUndoToken $wtop] $undo $redo
    
    # Remove select marks.
    if {$needDeselect} {
	::UserActions::DeselectAll $wtop
    }
}

# CanvasDraw::MarkBbox --
#
#        Makes four tiny squares at the corners of the specified items.
#       
# Arguments:
#       w      the canvas widget.
#       shift  If 'shift', then just select item, else deselect all other first.
#       which  can either be "current", another tag, or an id.
#       
# Results:
#       none

proc ::CanvasDraw::MarkBbox {w shift {which current}} {
    global  prefs kGrad2Rad
    
    Debug 3 "MarkBbox (entry):: w=$w, shift=$shift, which=$which"

    set wtop [::UI::GetToplevelNS $w]
    set a $prefs(aBBox)
    
    # If no shift key, deselect all.
    if {$shift == 0} {
	::UserActions::DeselectAll $wtop
    }
    if {[string equal $which "current"]} {
	set thebbox [$w bbox current]
    } else {
	set thebbox [$w bbox $which]
    }
    if {[llength $thebbox] == 0} {
	return
    }
    if {[string equal $which "current"]} {
	set utag [::CanvasUtils::GetUtag $w current]
	set id [$w find withtag current]
    } else {
	set utag [::CanvasUtils::GetUtag $w $which]

	# If 'which' a tag, find true id; ok also if 'which' true id.
	set id [$w find withtag $which]
    }
    if {($utag == "") || [llength $id] == 0} {
	return
    }
    
    # Movies may not be selected this way; temporary solution?
    if {[lsearch [$w gettags $utag] "movie"] >= 0} {
	return
    }
    
    # Add tag 'selected' to the selected item. Indicate to which item id
    # a marker belongs with adding a tag 'id$id'.
    set type [$w type $which]
    if {[string equal $type "window"]} {
	return
    }
    
    # If already selected, and shift clicked, deselect.
    if {$shift == 1} {
	set taglist [$w gettags $utag]
	if {[lsearch $taglist "selected"] >= 0} {
	    $w dtag $utag "selected"
	    $w delete id$id
	    return
	}
    }
    
    $w addtag "selected" withtag $utag
    set tmark [list tbbox id$id]

    # If mark the bounding box. Also for all "regular" shapes.
    if {$prefs(bboxOrCoords) || ($type == "oval") || ($type == "text")  \
      || ($type == "rectangle") || ($type == "image")} {

	foreach {x1 y1 x2 y2} $thebbox { break }
	$w create rect [expr $x1-$a] [expr $y1-$a] [expr $x1+$a] [expr $y1+$a] \
	  -tags $tmark -fill white
	$w create rect [expr $x1-$a] [expr $y2-$a] [expr $x1+$a] [expr $y2+$a] \
	  -tags $tmark -fill white
	$w create rect [expr $x2-$a] [expr $y1-$a] [expr $x2+$a] [expr $y1+$a] \
	  -tags $tmark -fill white
	$w create rect [expr $x2-$a] [expr $y2-$a] [expr $x2+$a] [expr $y2+$a] \
	  -tags $tmark -fill white
    } else {
	
	set theCoords [$w coords $which]
	if {[string length $theCoords] == 0} {
	    return
	}
	set n [llength $theCoords]
	
	# For an arc item, mark start and stop endpoints.
	# Beware, mixes of two coordinate systems, y <-> -y.
	if {[string equal $type "arc"]} {
	    if {$n != 4} {
		return
	    }
	    foreach {x1 y1 x2 y2} $theCoords { break }
	    set r [expr abs(($x1 - $x2)/2.0)]
	    set cx [expr ($x1 + $x2)/2.0]
	    set cy [expr ($y1 + $y2)/2.0]
	    set startAng [$w itemcget $id -start]
	    set extentAng [$w itemcget $id -extent]
	    set xstart [expr $cx + $r * cos($kGrad2Rad * $startAng)]
	    set ystart [expr $cy - $r * sin($kGrad2Rad * $startAng)]
	    set xfin [expr $cx + $r * cos($kGrad2Rad * ($startAng + $extentAng))]
	    set yfin [expr $cy - $r * sin($kGrad2Rad * ($startAng + $extentAng))]
	    $w create rect [expr $xstart-$a] [expr $ystart-$a]   \
	      [expr $xstart+$a] [expr $ystart+$a] -tags $tmark -fill white
	    $w create rect [expr $xfin-$a] [expr $yfin-$a]   \
	      [expr $xfin+$a] [expr $yfin+$a] -tags $tmark -fill white
	    
	} else {
	    
	    # Mark each coordinate. {x0 y0 x1 y1 ... }
	    for {set i 0} {$i < $n} {incr i 2} {
		set x [lindex $theCoords $i]
		set y [lindex $theCoords [expr $i + 1]]
		$w create rect [expr $x-$a] [expr $y-$a] [expr $x+$a] [expr $y+$a] \
		  -tags $tmark -fill white
	    }
	}
    }
    
    focus $w
    
    # Enable cut and paste etc.
    ::UI::FixMenusWhenSelection $w
    
    # Testing..
    selection own -command [list ::CanvasDraw::LostSelection $wtop] $w
}

# CanvasDraw::LostSelection --
#
#       Lost selection to other window. Deselect only if same toplevel.

proc ::CanvasDraw::LostSelection {wtop} {
    
    if {$wtop == "."} {
	set wtopReal $wtop
    } else {
	set wtopReal [string trimright $wtop "."]
    }
    if {$wtopReal == [selection own]} {
	::UserActions::DeselectAll $wtop
    }
}

proc ::CanvasDraw::SyncMarks {wtop} {

    upvar ::${wtop}::wapp wapp
    
    set w $wapp(can)
    $w delete withtag tbbox
    foreach id [$w find withtag "selected"] {
	::CanvasDraw::MarkBbox $w 1 $id	
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
    foreach {utag redocmd} [::CanvasDraw::SpeechBubbleCmd $w $bbox] { break }
    set undocmd "delete $utag"
    set cmdLower [list lower $utag $utagtext]
    
    set redo [list ::CanvasUtils::CommandList $wtop [list $redocmd $cmdLower]]
    set undo [list ::CanvasUtils::Command $wtop $undocmd]
    eval $redo
    undo::add [::UI::GetUndoToken $wtop] $undo $redo
}

proc ::CanvasDraw::SpeechBubbleCmd {w bbox args} {
    
    set a 8
    set b 12
    set c 40
    set d 20
    foreach {left top right bottom} $bbox { break }
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
    set cmd "create polygon $coords -tags {polylines $utag} [array get optsArr]"
    return [list $utag $cmd]
}


# EvalCommandList --
#
#       A utility function to evaluate more than a single command.
#       Useful for the undo/redo implementation.

proc EvalCommandList {cmdList} {
    
    foreach cmd $cmdList {
	eval $cmd
    }
}

#-------------------------------------------------------------------------------