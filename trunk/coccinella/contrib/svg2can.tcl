#  svg2can.tcl ---
#  
#      This file provides translation from canvas commands to XML/SVG format.
#      
#  Copyright (c) 2004  Mats Bengtsson
#
# $Id: svg2can.tcl,v 1.4 2004-02-19 15:09:12 matben Exp $
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

# We need URN decoding for the file path in images. From my whiteboard code.

package require uriencode

package provide svg2can 0.1

namespace eval svg2can {

    variable textAnchorMap
    array set textAnchorMap {
	start   w
	middle  c
	end     e
    }
    
    variable fontWeightMap 
    array set fontWeightMap {
	normal    normal
	bold      bold
	bolder    bold
	lighter   normal
	100       normal
	200       normal
	300       normal
	400       normal
	500       normal
	600       bold
	700       bold
	800       bold
	900       bold
    }
}


proc svg2can::parsesvgdocument {xmllist args} {
        
    set ans {}
    foreach c [getchildren $xmllist] {
	lappend ans [parseelement $c]
    }
    return $ans
}

proc svg2can::parseelement {xmllist args} {

    set cmd {}
    set tag [gettag $xmllist]
    
    switch -- $tag {
	circle - ellipse - image - line - path - polyline - polygon - rect - text {
	    lappend cmd [parse${tag} $xmllist]
	}
	g {
	    foreach c [getchildren $xmllist] {
		set ctag [gettag $xmllist]
		lappend cmd [parse${ctag} $xmllist]
	    }	    
	}
    }
    return $cmd
}

# svg2can::parsecircle, parseellipse, parseline, parserect, parsepolyline,
#   parsepolygon, parseimage --
# 
#       Makes the necessary canvas commands needed to reproduce the
#       svg element.
#       
# Arguments:
#       xmllist
#       
# Results:
#       canvas create command without the widgetPath.

proc svg2can::parsecircle {xmllist} {
    
    # SVG and canvas have different defaults.
    set opts {-outline "" -fill black}
    set presentationAttr {}
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
		set opts [StyleToOpts circle [StyleAttrToList $value]]
	    }
	    default {
		lappend presentationAttr $key $value
	    }
	}
    }
    set coords [list [expr $cx - $r] [expr $cy - $r] \
      [expr $cx + $r] [expr $cy + $r]]
    set opts [MergePresentationAttr circle $opts $presentationAttr]
    return [concat create oval $coords $opts]
}

proc svg2can::parseellipse {xmllist} {
    
    # SVG and canvas have different defaults.
    set opts {-outline "" -fill black}
    set presentationAttr {}
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
		set opts [StyleToOpts ellipse [StyleAttrToList $value]]
	    }
	    default {
		lappend presentationAttr $key $value
	    }
	}
    }
    set coords [list [expr $cx - $rx] [expr $cy - $ry] \
      [expr $cx + $rx] [expr $cy + $ry]]
    set opts [MergePresentationAttr ellipse $opts $presentationAttr]
    return [concat create oval $coords $opts]
}

proc svg2can::parseimage {xmllist} {
    
    set x 0
    set y 0    
    set presentationAttr {}

    foreach {key value} [getattr $xmllist] {
	
	switch -- $key {
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [StyleToOpts polygon [StyleAttrToList $value]]
	    }
	    x - y {
		set $key $value
	    }
	    xlink:href {
		set uri $value
	    }
	    default {
		lappend presentationAttr $key $value
	    }
	}
    }
    set opts [MergePresentationAttr polygon $opts $presentationAttr]
    lappend opts -image \[image create photo -file $uri]
    return [concat create image $x $y $opts]
}

proc svg2can::parseline {xmllist} {
    
    set opts {}
    set coords {0 0 0 0}
    set presentationAttr {}
    
    foreach {key value} [getattr $xmllist] {
	
	switch -- $key {
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [StyleToOpts line [StyleAttrToList $value]]
	    }
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
	    default {
		lappend presentationAttr $key $value
	    }
	}
    }
    set opts [MergePresentationAttr line $opts $presentationAttr]    
    return [concat create line $coords $opts]
}

proc svg2can::parsepath {xmllist} {
    
    set coords {}
    set opts {}
    set presentationAttr {}
    set cantype line

    foreach {key value} [getattr $xmllist] {
	
	switch -- $key {
	    d {
		set coords [ParseStraightPath $value]
	    }
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [StyleToOpts path [StyleAttrToList $value]]
	    }
	    default {
		lappend presentationAttr $key $value
	    }
	}
    }
    set opts [MergePresentationAttr path $opts $presentationAttr]
    return [concat create $cantype $coords $opts]
}

proc svg2can::parsepolyline {xmllist} {
    
    set coords {}
    set opts {}
    set presentationAttr {}

    foreach {key value} [getattr $xmllist] {
	
	switch -- $key {
	    points {
		set coords [PointsToList $value]
	    }
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [StyleToOpts polyline [StyleAttrToList $value]]
	    }
	    default {
		lappend presentationAttr $key $value
	    }
	}
    }
    set opts [MergePresentationAttr polyline $opts $presentationAttr]
    return [concat create line $coords $opts]
}

proc svg2can::parsepolygon {xmllist} {
    
    set coords {}
    set opts {}
    set presentationAttr {}

    foreach {key value} [getattr $xmllist] {
	
	switch -- $key {
	    id {
		lappend opts -tags $value
	    }
	    points {
		set coords [PointsToList $value]
	    }
	    style {
		set opts [StyleToOpts polygon [StyleAttrToList $value]]
	    }
	    default {
		lappend presentationAttr $key $value
	    }
	}
    }
    set opts [MergePresentationAttr polygon $opts $presentationAttr]
    return [concat create polygon $coords $opts]
}

proc svg2can::parserect {xmllist} {
    
    # SVG and canvas have different defaults.
    set opts {-outline "" -fill black}
    set coords {0 0 0 0}
    set presentationAttr {}
    
    foreach {key value} [getattr $xmllist] {
	
	switch -- $key {
	    id {
		lappend opts -tags $value
	    }
	    rx - ry {
		# unsupported :-(
	    }
	    style {
		set opts [StyleToOpts rect [StyleAttrToList $value]]
	    }
	    x - y - width - height {
		set $key $value
	    }
	    default {
		lappend presentationAttr $key $value
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
	lset coords 3 [expr [lindex $coords 1] + $height]
    }
    set opts [MergePresentationAttr rect $opts $presentationAttr]
    return [concat create rectangle $coords $opts]
}

proc svg2can::parsetext {xmllist} {
    
    set x 0
    set y 0    
    set presentationAttr {}
    set cmdList {}

    foreach {key value} [getattr $xmllist] {
	
	switch -- $key {
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [StyleToOpts text [StyleAttrToList $value]]
	    }
	    x - y {
		set $key $value
	    }
	    default {
		lappend presentationAttr $key $value
	    }
	}
    }
    set opts [MergePresentationAttr text $opts $presentationAttr]
    
    # Assuming that chdata is not mixed with elements, we should now have
    # either chdata OR more elements (tspan).
    set childList [getchildren $xmllist]
    if {[llength $childList]} {
	foreach c $childList {
	    set tag [gettag $c]
	    
	    switch -- $tag {
		textPath {
		    # empty.
		}
		tspan {
		    lappend cmdList [ParseTspan x y $opts]
		}
		tref {
		    # empty.
		}
	    }
	}
    } else {
	lappend opts -text [getcdata $xmllist]
	lappend cmdList [concat create text $x $y $opts]
    }
    return $cmdList
}

proc svg2can::ParseTspan {xmllist xVar yVar opts} {
    
    upvar $xVar x
    upvar $yVar y

    set presentationAttr {}
    
    foreach {key value} [getattr $xmllist] {
	
	switch -- $key {
	    style {
		set opts [StyleToOpts text [StyleAttrToList $value]]
	    }
	    x - y {
		set $key $value
	    }
	    default {
		lappend presentationAttr $key $value
	    }
	}
    }
    set opts [MergePresentationAttr text $opts $presentationAttr]
    return [concat create text $x $y $opts]
}

# svg2can::parseColor --
# 
#       Takes a SVG color definition and turns it into a Tk color.
#       
# Arguments:
#       color       SVG color
#       
# Results:
#       tk color

proc svg2can::parseColor {color} {
    
    if {[regexp {rgb\(([0-9]{1,3})%, *([0-9]{1,3})%, *([0-9]{1,3})%\)}  \
      $color match r g b]} {
	set col #
	foreach c [list $r $g $b] {
	    append col [format %02x [expr round(2.55 * $c)]]
	}
    } elseif {[regexp {rgb\(([0-9]{1,3}), *([0-9]{1,3}), *([0-9]{1,3})\)}  \
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

# svg2can::StyleToOpts --
# 
#       Takes the style attribute as a list and parses it into
#       resonable canvas drawing options.
#       
# Arguments:
#       type        svg item type
#       styleList
#       
# Results:
#       list of canvas options

proc svg2can::StyleToOpts {type styleList} {
    
    variable textAnchorMap
    
    set opts {}
    set font {Helvetica 12 normal}
    set haveFont 0
    
    foreach {key value} $styleList {
	
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
		switch -- $type {
		    rect - circle - ellipse {
			lappend opts -outline [parseColor $value]
		    }
		    default {
			lappend opts -fill [parseColor $value]
		    }
		}
	    }
	    stroke-dasharray {
		set dash [split $value ,]
		if {[expr [llength $dash]%2 == 1]} {
		    set dash [concat $dash $dash]
		}
	    }
	    stroke-linecap {	
		# canvas: butt (D), projecting , round 
		# svg:    butt (D), square, round
		if {[string equal $value "square"]} {
		    lappend opts -capstyle "projecting"
		}
		if {![string equal $value "butt"]} {
		    lappend opts -capstyle $value
		}
	    }
	    stroke-linejoin {
		lappend opts -joinstyle $value
	    }
	    stroke-miterlimit {
		
	    }
	    stroke-opacity {
		if {[expr {$value == 0}]} {
		    
		}
	    }
	    stroke-width {
		if {![string equal $type "text"]} {
		    lappend opts -width $value
		}
	    }
	    text-anchor {
		lappend opts -anchor $textAnchorMap($value)
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

# svg2can::MergePresentationAttr --
# 
#       Let the style attribute override the presentaion attributes.

proc svg2can::MergePresentationAttr {type opts presentationAttr} {
    
    if {[llength $presentationAttr]} {
	array set optsArr [array get [StyleToOpts $type $presentationAttr]]
	array set optsArr [array get $opts]
	set opts [array get optsArr]
    }
    return $opts
}

proc svg2can::StyleAttrToList {style} {
    
    return [split [string trim [string map {" " ""} $style] \;] :\;]
}

proc svg2can::ParseStraightPath {path} {
    
    regsub -all -- {([a-zA-Z])([0-9])} $path {\1 \2} path
    regsub -all -- {([0-9])([a-zA-Z])} $path {\1 \2} path
    set path [string map {- " -"} $path]
    set path [string map {, " "} $path]
    
    set cantype line
    set i 0
    set len [llength $path]

    while {$i < $len} {
	set elem [lindex $path $i]
	
	switch -glob -- $elem {
	    M - m {
		set co [list [lindex $path [incr i]] [lindex $path [incr i]]]
		incr i
	    }
	    L - {[0-9]*} - {-[0-9]*} {
		if {$elem != "L"} {incr i -1}
		lappend co [lindex $path [incr i]] [lindex $path [incr i]]
		incr i
	    }
	    l {
		lappend co [expr [lindex $co end-1] + [lindex $path [incr i]]] \
		  [expr [lindex $co end] + [lindex $path [incr i]]]
		incr i
	    }
	    H {
		lappend co [lindex $path [incr i]] [lindex $co end]
		incr i
	    }
	    h {
		lappend co [expr [lindex $co end-1] + [lindex $path [incr i]]] \
		  [lindex $co end]
		incr i
	    }
	    V {
		lappend co [lindex $co end-1] [lindex $path [incr i]]
		incr i
	    }
	    v {
		lappend co [lindex $co end-1] \
		  [expr [lindex $co end] + [lindex $path [incr i]]]
		incr i
	    }
	    Z - z {
		set cantype polygon
		incr i
	    }
	}
    }
    return $co
}

proc svg2can::PointsToList {points} {
    
    return [string map {, " "} $points]
}

proc svg2can::MapNoneToEmpty {val} {

    if {[string equal $val "none"]} {
	return ""
    } else {
	return $val
    }
}

# svg2can::gettag, getattr, getcdata, getchildren --
# 
#       Accesor functions to the specific things in a xmllist.

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
