#  svg2can.tcl ---
#  
#      This file provides translation from canvas commands to XML/SVG format.
#      
#  Copyright (c) 2004  Mats Bengtsson
#
# $Id: svg2can.tcl,v 1.1 2004-02-17 07:43:32 matben Exp $
# 
# ########################### USAGE ############################################
#
#   NAME
#      svg2can - translate XML/SVG to canvas command.
#      
#   SYNOPSIS
#      svg2can xmllist
#           
#      
#
# ########################### CHANGES ##########################################
#
#   0.1      first release
#
# ########################### TODO #############################################
#
# ########################### INTERNALS ########################################
# 
# The whole parse tree is stored as a hierarchy of lists as:
# 
#       xmllist = {tag attrlist isempty cdata {child1 child2 ...}}

# We need URN encoding for the file path in images. From my whiteboard code.

package require uriencode

package provide svg2can 0.1

namespace eval svg2can {

}


proc svg2can::parseelement {xmllist} {

    set tag [gettag $xmllist]
    
    switch -- $tag {
	line - circle - rect - polyline - polygon {
	    set cmd [parse${tag} $xmllist]
	}
    }
    return $cmd
}

proc svg2can::parseline {xmllist} {
    
    set opts {...}
    set coords {0 0 0 0}
    
    foreach {key value} [getattr $xmllist] {
	
	switch -- $key {
	    x1 {
		lset coords 0 $value
	    }
	    y1 {
		lset coords 1 $value
	    }
	    x2 {
		lset coords 2 $value
	    }
	    y2 {
		lset coords 3 $value
	    }
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [style2opts $value]
	    }
	    default {
		# empty
	    }
	}
    }
    return [concat create line $coords $opts]
}

proc svg2can::parsecircle {xmllist} {
    
    set opts {...}
    set cx 0
    set cy 0
    set r 0
    
    foreach {key value} [getattr $xmllist] {
	
	switch -- $key {
	    cx - cy - r {
		set $key $value
	    }
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [style2opts $value]
	    }
	    default {
		# empty
	    }
	}
    }
    set coords [list [expr $cx - $r] [expr $cy - $r] \
      [expr $cx + $r] [expr $cy + $r]]
    return [concat create oval $coords $opts]
}

proc svg2can::parseellipse {xmllist} {
    
    set opts {...}
    set cx 0
    set cy 0
    set rx 0
    set ry 0
    
    foreach {key value} [getattr $xmllist] {
	
	switch -- $key {
	    cx - cy - rx - ry {
		set $key $value
	    }
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [style2opts $value]
	    }
	    default {
		# empty
	    }
	}
    }
    set coords [list [expr $cx - $rx] [expr $cy - $ry] \
      [expr $cx + $rx] [expr $cy + $ry]]
    return [concat create oval $coords $opts]
}

proc svg2can::parserect {xmllist} {
    
    set opts {...}
    set coords {0 0 0 0}
    
    foreach {key value} [getattr $xmllist] {
	
	switch -- $key {
	    x - y - width - height {
		set $key $value
	    }
	    rx - ry {
		# unsupported :-(
	    }
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [style2opts $value]
	    }
	    default {
		# empty
	    }
	}
    }
    if {[info exists x]} {
	lset coords 0 $x
    }
    if {[info exists y]} {
	lset coords 1 $y
    }
    if {[info exists width]} {
	lset coords 2 [expr [lindex $coords 0] + $width]
    }
    if {[info exists height]} {
	lset coords 2 [expr [lindex $coords 1] + $height]
    }
    return [concat create rectangle $coords $opts]
}

proc svg2can::parsepolyline {xmllist} {
    
    
}

proc svg2can::parsepolygon {xmllist} {
    
    
}

proc svg2can::parseColor {color} {
    
    if {[regexp {rgb\(([0-9]{1,3})%, +([0-9]{1,3})%, +([0-9]{1,3})%\)}  \
      $color match r g b]} {
	set col #
	foreach c [list $r $g $b] {
	    append col [format %2x [expr round(2.55 * $c)]]
	}
    } elseif {[regexp {rgb\(([0-9]{1,3}), +([0-9]{1,3}), +([0-9]{1,3})\)}  \
      $color match r g b]} {
	set col #
	foreach c [list $r $g $b] {
	    append col [format %2x [expr round(2.55 * $c)]]
	}
    } else {
	set col $color
    }
    return $col
}

proc svg2can::style2opts {style} {
    
    set opts {}
    set font {Helvetica 12 normal}
    set haveFont 0
    
    foreach {key value} [split $style ":;"] {
	
	switch -- $key {
	    font-family {
		lset font 0 $value
		set haveFont 1
	    }
	    font-size {
		if {[regexp {([0-9]+)pt} $value match pts]} {
		    lset font 1 $pts
		} else {
		    lset font 1 $value
		}
		set haveFont 1
	    }
	    font-style {
		
		set haveFont 1
	    }
	    font-weight {
		
		set haveFont 1
	    }
	    stroke {
		lappend opts -outline/-fill [parseColor $value]
	    }
	    stroke-dasharray {
		set dash [split $value ,]
		if {[expr [llength $dash]%2 == 1]} {
		    set dash [concat $dash $dash]
		}
	    }
	    stroke-linejoin {
		lappend opts -joinstyle $value
	    }
	    stroke-opacity {
		if {[expr {$value == 0}]} {
		    
		}
	    }
	    stroke-width {
		lappend opts -width $value
	    }
	    text-anchor {
		
	    }
	    text-decoration {

	    }
	}
    }
    if {$haveFont} {
	lappend opts -font $font
    }
    return $opts
}

proc ::svg2can::MapNoneToEmpty {val} {

    if {[string equal $val "none"]} {
	return ""
    } else {
	return $val
    }
}

proc svg2can::gettag {xmllist} { 
    return [lindex $xmllist 0]
}

proc svg2can::getattr {xmllist} { 
    return [lindex $xmllist 1]
}

proc svg2can::getcdata {xmllist} { 
    return [lindex $xmllist 3]
}

proc svg2can::getchildren {xmllist} { 
    return [lindex $xmllist 4]
}

#-------------------------------------------------------------------------------
