#  svg2can.tcl ---
#  
#      This file provides translation from canvas commands to XML/SVG format.
#      
#  Copyright (c) 2004  Mats Bengtsson
#
# $Id: svg2can.tcl,v 1.11 2004-02-26 15:11:29 matben Exp $
# 
# ########################### USAGE ############################################
#
#   NAME
#      svg2can - translate XML/SVG to canvas command.
#      
#   SYNOPSIS
#      svg2can::parsesvgdocument xmllist
#      svg2can::parseelement xmllist
#      
#
# ########################### CHANGES ##########################################
#
#   0.1      first release
#
# ########################### TODO #############################################
#
#       A lot...
#
# ########################### INTERNALS ########################################
# 
# The whole parse tree is stored as a hierarchy of lists as:
# 
#       xmllist = {tag attrlist isempty cdata {child1 child2 ...}}

# We need URN decoding for the file path in images. From my whiteboard code.

package require uriencode

package provide svg2can 1.0

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
    
    variable systemFont
    switch -- $::tcl_platform(platform) {
	unix {
	    set systemFont {Helvetica 10}
	    if {[package vcompare [info tclversion] 8.3] == 1} {	
		if {[string equal [tk windowingsystem] "aqua"]} {
		    set systemFont system
		}
	    }
	}
	windows - macintosh {
	    set systemFont system
	}
    }
}

# svg2can::parsesvgdocument --
# 
# 
# Arguments:
#       xmllist     the parsed document as a xml list
#       args        
#       
# Results:
#       a list of canvas commands without the widgetPath

proc svg2can::parsesvgdocument {xmllist args} {
        
    set ans {}
    foreach c [getchildren $xmllist] {
	set ans [concat $ans [parseelement $c {}]]
    }
    return $ans
}

# svg2can::parseelement --
# 
# 
# Arguments:
#       xmllist     the elements xml list
#       transformList
#       args        list of attributes from any enclosing element (g).
#       
# Results:
#       a list of canvas commands without the widgetPath

proc svg2can::parseelement {xmllist transformList args} {

    set cmdList {}
    set tag [gettag $xmllist]
    
    # Handle any tranform attribute; may be recursive, so keep a list.
    set transformList [concat $transformList \
      [ParseTransformAttr [getattr $xmllist]]]
    puts "transformList=$transformList"

    switch -- $tag {
	circle - ellipse - image - line - polyline - polygon - rect - path - text {
	    set cmdList [concat $cmdList \
	      [eval {parse${tag} $xmllist $transformList} $args]]
	}
	g {
	    # Need to collect the attributes for the g element since
	    # the child elements inherit them. g elements may be nested!
	    array set attrArr $args
	    array set attrArr [getattr $xmllist]
	    foreach c [getchildren $xmllist] {
		set cmdList [concat $cmdList \
		  [eval {parseelement $c $transformList} [array get attrArr]]]
	    }	    
	}
    }
    return $cmdList
}

# svg2can::parsecircle, parseellipse, parseline, parserect, parsepath, 
#   parsepolyline, parsepolygon, parseimage --
# 
#       Makes the necessary canvas commands needed to reproduce the
#       svg element.
#       
# Arguments:
#       xmllist
#       args        list of attributes from any enclosing element (g).
#       
# Results:
#       list of canvas create command without the widgetPath.

proc svg2can::parsecircle {xmllist transformList args} {
    
    set opts {}
    set presentationAttr {}
    set cx 0
    set cy 0
    set r 0
    array set attrArr $args
    array set attrArr [getattr $xmllist]
    
    foreach {key value} [array get attrArr] {
	
	switch -- $key {
	    cx - cy - r {
		set $key $value
	    }
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [StyleToOpts oval [StyleAttrToList $value]]
	    }
	    default {
		# Valid itemoptions will be sorted out below.
		lappend presentationAttr $key $value
	    }
	}
    }
    set coords [list [expr $cx - $r] [expr $cy - $r] \
      [expr $cx + $r] [expr $cy + $r]]
    set opts [MergePresentationAttr oval $opts $presentationAttr]
    return [list [concat create oval $coords $opts]]
}

proc svg2can::parseellipse {xmllist transformList args} {
    
    set opts {}
    set presentationAttr {}
    set cx 0
    set cy 0
    set rx 0
    set ry 0
    array set attrArr $args
    array set attrArr [getattr $xmllist]
    
    foreach {key value} [array get attrArr] {
	
	switch -- $key {
	    cx - cy - rx - ry {
		set $key $value
	    }
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [StyleToOpts oval [StyleAttrToList $value]]
	    }
	    default {
		lappend presentationAttr $key $value
	    }
	}
    }
    set coords [list [expr $cx - $rx] [expr $cy - $ry] \
      [expr $cx + $rx] [expr $cy + $ry]]
    set opts [MergePresentationAttr oval $opts $presentationAttr]
    return [list [concat create oval $coords $opts]]
}

proc svg2can::parseimage {xmllist transformList args} {
    
    set x 0
    set y 0    
    set presentationAttr {}
    set photo {}
    array set attrArr $args
    array set attrArr [getattr $xmllist]

    foreach {key value} [array get attrArr] {
	
	switch -- $key {
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [StyleToOpts image [StyleAttrToList $value]]
	    }
	    x - y {
		set $key $value
	    }
	    xlink:href {
		set path [uriencode::decodefile $value]
		set path [string map {file:/// /} $path]
		set photo [image create photo -file $path]
		lappend opts -image $photo
	    }
	    default {
		lappend presentationAttr $key $value
	    }
	}
    }
    set opts [MergePresentationAttr image $opts $presentationAttr]
    return [list [concat create image $x $y $opts]]
}

proc svg2can::parseline {xmllist transformList args} {
    
    set opts {}
    set coords {0 0 0 0}
    set presentationAttr {}
    array set attrArr $args
    array set attrArr [getattr $xmllist]
    
    foreach {key value} [array get attrArr] {
	
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
    return [list [concat create line $coords $opts]]
}

proc svg2can::parsepath {xmllist transformList args} {
    
    set cmdList {}
    set opts {}
    set presentationAttr {}
    set path {}
    set styleList {}
    set lineopts {}
    set polygonopts {}
    array set attrArr $args
    array set attrArr [getattr $xmllist]
    
    foreach {key value} [array get attrArr] {
	
	switch -- $key {
	    d {
		set path $value
	    }
	    id {
		lappend lineopts -tags $value
		lappend polygonopts -tags $value
	    }
	    style {
		# Need to parse separately for each canvas item since different
		# default values.
		set lineopts [StyleToOpts line [StyleAttrToList $value]]
		set polygonopts [StyleToOpts polygon [StyleAttrToList $value]]
	    }
	    default {
		lappend presentationAttr $key $value
	    }
	}
    }

    # The resulting canvas items are typically lines and polygons.
    # Since the style parsing is different keep separate copies.
    set lineopts [MergePresentationAttr line $lineopts $presentationAttr]
    set polygonopts [MergePresentationAttr polygon $polygonopts $presentationAttr]
    
    # Parse the actual path data. 
    set co {}
    set cantype line
    set itemopts {}
    
    regsub -all -- {([a-zA-Z])([0-9])} $path {\1 \2} path
    regsub -all -- {([0-9])([a-zA-Z])} $path {\1 \2} path
    set path [string map {- " -"} $path]
    set path [string map {, " "} $path]
    
    set i 0
    set len  [llength $path]
    set len1 [expr $len - 1]
    set len2 [expr $len - 2]
    set len4 [expr $len - 4]
    set len6 [expr $len - 6]
    
    while {$i < $len} {
	set elem [lindex $path $i]
	set isabsolute 1
	if {[string is lower $elem]} {
	    set isabsolute 0
	}
	#puts "elem=$elem"
	
	switch -glob -- $elem {
	    A - a {
		# Not part of Tiny SVG.
		incr i
	    }
	    C - c {
		# We could have a sequence of pairs of points here...
		# Approximate by quadratic bezier.
		# There are three options here: 
		# C (p1 p2 p3) (p4 p5 p6)...           finalize item
		# C (p1 p2 p3) S (p4 p5)...            let S trigger below
		# C p1 p2 p3 anything else             finalize here
		while {![regexp {[a-zA-Z]} [lindex $path [expr $i+1]]] && \
		  ($i < $len6)} {
		    set co [list $cpx $cpy] 
		    if {$isabsolute} {
			lappend co [lindex $path [incr i]] [lindex $path [incr i]]
			lappend co [lindex $path [incr i]] [lindex $path [incr i]]
			lappend co [lindex $path [incr i]] [lindex $path [incr i]]
			set cpx [lindex $co end-1]
			set cpy [lindex $co end]
		    } else {			
			PathAddRelative $path co i cpx cpy
			PathAddRelative $path co i cpx cpy
			PathAddRelative $path co i cpx cpy
		    }
		    
		    # If S instruction do not finalize item.
		    if {![string equal -nocase [lindex $path [expr $i+1]] "S"]} {
			#puts "\ti=$i, current=($cpx,$cpy), co=$co"
			lappend itemopts -smooth 1
			set opts [concat $lineopts $itemopts]
			lappend cmdList [concat create line $co $opts]
			set co {}
			set itemopts {}
		    }
		}
		incr i
	    }
	    H {
		while {![regexp {[a-zA-Z]} [lindex $path [expr $i+1]]] && \
		  ($i < $len1)} {
		    lappend co [lindex $path [incr i]] $cpy
		}
		incr i
	    }
	    h {
		while {![regexp {[a-zA-Z]} [lindex $path [expr $i+1]]] && \
		  ($i < $len1)} {
		    lappend co [expr $cpx + [lindex $path [incr i]]] $cpy
		}
		incr i
	    }
	    L - {[0-9]+} - {-[0-9]+} {
		while {![regexp {[a-zA-Z]} [lindex $path [expr $i+1]]] && \
		  ($i < $len2)} {
		    lappend co [lindex $path [incr i]] [lindex $path [incr i]]
		}
		incr i
	    }
	    l {
		while {![regexp {[a-zA-Z]} [lindex $path [expr $i+1]]] && \
		  ($i < $len2)} {
		    lappend co [expr $cpx + [lindex $path [incr i]]] \
		      [expr $cpy + [lindex $path [incr i]]]
		}
		incr i
	    }
	    M - m {
		# Make a fresh canvas item and finalize any previous command.
		if {[llength $co]} {
		    set opts [concat [set ${cantype}opts] $itemopts]
		    lappend cmdList [concat create $cantype $co $opts]
		}
		if {!$isabsolute && [info exists cpx]} {
		    set co [list  \
		      [expr $cpx + [lindex $path [incr i]]]
		      [expr $cpy + [lindex $path [incr i]]]]
		} else {
		    set co [list [lindex $path [incr i]] [lindex $path [incr i]]]
		}
		set itemopts {}
		incr i
	    }
	    Q - q {
		# There are three options here: 
		# Q p1 p2 p3 p4...           finalize item
		# Q p1 p2 T p3...            let T trigger below
		# Q p1 p2 anything else      finalize here
		#puts "Q: i=$i, path=$path"
		#puts "\tcurrent=($cpx,$cpy)"
		
		# We may have a sequence of pairs of points following the Q.
		# Make a fresh item for each.
		while {![regexp {[a-zA-Z]} [lindex $path [expr $i+1]]] && \
		  ($i < $len4)} {
		    set co [list $cpx $cpy] 
		    if {$isabsolute} {
			lappend co [lindex $path [incr i]] [lindex $path [incr i]]
			lappend co [lindex $path [incr i]] [lindex $path [incr i]]
			set cpx [lindex $co end-1]
			set cpy [lindex $co end]
		    } else {
			PathAddRelative $path co i cpx cpy
			PathAddRelative $path co i cpx cpy
		    }
		    
		    # If T instruction do not finalize item.
		    if {![string equal -nocase [lindex $path [expr $i+1]] "T"]} {
			#puts "\ti=$i, current=($cpx,$cpy), co=$co"
			lappend itemopts -smooth 1
			set opts [concat $lineopts $itemopts]
			lappend cmdList [concat create line $co $opts]
			set co {}
			set itemopts {}
		    }
		}
		incr i
	    }
	    S - s {
		# Must annihilate last point added and use its mirror instead.
		#puts "S: i=$i, path=$path"
		while {![regexp {[a-zA-Z]} [lindex $path [expr $i+1]]] && \
		  ($i < $len4)} {
		    # Control point from mirroring.
		    set ctrlpx [expr 2 * $cpx - [lindex $co end-3]]
		    set ctrlpy [expr 2 * $cpy - [lindex $co end-2]]
		    lset co end-1 $ctrlpx
		    lset co end $ctrlpy
		    if {$isabsolute} {
			lappend co [lindex $path [incr i]] [lindex $path [incr i]]
			lappend co [lindex $path [incr i]] [lindex $path [incr i]]
			set cpx [lindex $co end-1]
			set cpy [lindex $co end]
		    } else {
			PathAddRelative $path co i cpx cpy
			PathAddRelative $path co i cpx cpy
		    }
		    #puts "\ti=$i, ctrl=($ctrlpx,$ctrlpy), co=$co"
		}		
		incr i
		lappend itemopts -smooth 1
	    }
	    T - t {
		# Must annihilate last point added and use its mirror instead.
		#puts "T: i=$i, path=$path"
		while {![regexp {[a-zA-Z]} [lindex $path [expr $i+1]]] && \
		  ($i < $len2)} {
		    # Control point from mirroring.
		    set ctrlpx [expr 2 * $cpx - [lindex $co end-3]]
		    set ctrlpy [expr 2 * $cpy - [lindex $co end-2]]
		    lset co end-1 $ctrlpx
		    lset co end $ctrlpy
		    if {$isabsolute} {
			lappend co [lindex $path [incr i]] [lindex $path [incr i]]
			set cpx [lindex $co end-1]
			set cpy [lindex $co end]
		    } else {
			PathAddRelative $path co i cpx cpy
		    }
		    #puts "\ti=$i, ctrl=($ctrlpx,$ctrlpy), co=$co"
		}		
		incr i
		lappend itemopts -smooth 1
	    }
	    V {
		while {![regexp {[a-zA-Z]} [lindex $path [expr $i+1]]] && \
		  ($i < $len1)} {
		    lappend co $cpx [lindex $path [incr i]]
		}
		incr i
	    }
	    v {
		while {![regexp {[a-zA-Z]} [lindex $path [expr $i+1]]] && \
		  ($i < $len1)} {
		    lappend co $cpx [expr $cpy + [lindex $path [incr i]]]
		}
		incr i
	    }
	    Z - z {
		if {[llength $co]} {
		    set opts [concat $polygonopts $itemopts]
		    lappend cmdList [concat create polygon $co $opts]
		}
		set cantype line
		set itemopts {}
		incr i
		set co {}
	    }
	    default {
		# ?
		incr i
	    }
	}
	
	# Keep track of the pens current point.
	set cpx [lindex $co end-1]
	set cpy [lindex $co end]
	#puts "cp=($cpx,$cpy)"
    }
    
    # Finalize the last element if any.
    if {[llength $co]} {
	set opts [concat [set ${cantype}opts] $itemopts]
	lappend cmdList [concat create $cantype $co $opts]
    }
    return $cmdList
}

proc svg2can::parsepolyline {xmllist transformList args} {
    
    set coords {}
    set opts {}
    set presentationAttr {}
    array set attrArr $args
    array set attrArr [getattr $xmllist]

    foreach {key value} [array get attrArr] {
	
	switch -- $key {
	    points {
		set coords [PointsToList $value]
	    }
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [StyleToOpts line [StyleAttrToList $value]]
	    }
	    default {
		lappend presentationAttr $key $value
	    }
	}
    }
    set opts [MergePresentationAttr line $opts $presentationAttr]
    return [list [concat create line $coords $opts]]
}

proc svg2can::parsepolygon {xmllist transformList args} {
    
    set coords {}
    set opts {}
    set presentationAttr {}
    array set attrArr $args
    array set attrArr [getattr $xmllist]

    foreach {key value} [array get attrArr] {
	
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
    return [list [concat create polygon $coords $opts]]
}

proc svg2can::parserect {xmllist transformList args} {
    
    set opts {}
    set coords {0 0 0 0}
    set presentationAttr {}
    array set attrArr $args
    array set attrArr [getattr $xmllist]
    
    foreach {key value} [array get attrArr] {
	
	switch -- $key {
	    id {
		lappend opts -tags $value
		set id $value
	    }
	    rx - ry {
		# unsupported :-(
	    }
	    style {
		set opts [StyleToOpts rectangle [StyleAttrToList $value]]
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
    set opts [MergePresentationAttr rectangle $opts $presentationAttr]
    set cmdList [list [concat create rectangle $coords $opts]]
    if {[info exists id]} {
	set cmdList [concat $cmdList \
	  [CreateTransformCanvasCmdList $id $transformList]]
    }
    return $cmdList
}

# svg2can::parsetext --
# 
#       Takes a text element and returns a list of canvas create text commands.
#       Assuming that chdata is not mixed with elements, we should now have
#       either chdata OR more elements (tspan).

proc svg2can::parsetext {xmllist transformList args} {
    
    set x 0
    set y 0
    set xAttr 0
    set yAttr 0
    set cmdList [ParseTspan $xmllist x y xAttr yAttr {}]
    return [FlattenList $cmdList]
}

# svg2can::ParseTspan --
# 
#       Takes a tspan or text element and returns a list of canvas
#       create text commands.

proc svg2can::ParseTspan {xmllist xVar yVar xAttrVar yAttrVar opts} { 
    variable systemFont
    upvar $xVar x
    upvar $yVar y
    upvar $xAttrVar xAttr
    upvar $yAttrVar yAttr

    # Nested tspan elements do not inherit x, y, dx, or dy attributes set.
    # Sibling tspan elements do inherit x, y attributes.
    # Keep two separate sets of x and y; (x,y) and (xAttr,yAttr):
    # (x,y) 
    
    # Inherit opts.
    array set optsArr $opts
    array set optsArr [ParseTextAttr $xmllist xAttr yAttr]
    set opts [array get optsArr]

    set tag [gettag $xmllist]
    set childList [getchildren $xmllist]
    set cmdList {}
    if {[string equal $tag "text"]} {
	set x $xAttr
	set y $yAttr
    }
    #puts "x=$x, y=$y, xAttr=$xAttr, yAttr=$yAttr"
    
    if {[llength $childList]} {
	
	# Nested tspan elements do not inherit x, y set via attributes.
	if {[string equal $tag "tspan"]} {
	    set xAttr $x
	    set yAttr $y
	}
	foreach c $childList {
	    
	    switch -- [gettag $c] {
		tspan {
		    lappend cmdList [ParseTspan $c x y xAttr yAttr $opts]
		}
		default {
		    # empty
		}
	    }
	}
    } else {
	set str [getcdata $xmllist]
	lappend opts -text $str
	set cmdList [concat create text $xAttr $yAttr $opts]
	set theFont $systemFont
	if {[info exists optsArr(-font)]} {
	    set theFont $optsArr(-font)
	}
	
	# Each text insert moves both the running coordinate sets.
	# newlines???
	set deltax [font measure $theFont $str]
	set x     [expr $x + $deltax]
	set xAttr [expr $xAttr + $deltax]
    }
    return $cmdList
}

# svg2can::ParseTextAttr --
# 
#       Parses the attributes in xmllist and returns the translated canvas
#       option list.

proc svg2can::ParseTextAttr {xmllist xVar yVar} {    
    variable systemFont
    upvar $xVar x
    upvar $yVar y

    # svg defaults to start (w) while tk default is c.
    set opts {-anchor w}
    set presentationAttr {}
    
    foreach {key value} [getattr $xmllist] {
	
	switch -- $key {
	    baseline-shift {
		set baselineshift $value
	    }
	    dx {
		set x [expr $x + $value]
	    }
	    dy {
		set y [expr $y + $value]
	    }
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [concat $opts \
		  [StyleToOpts text [StyleAttrToList $value]]]
	    }
	    x - y {
		set $key $value
	    }
	    default {
		lappend presentationAttr $key $value
	    }
	}
    }
    array set optsArr $opts
    set theFont $systemFont
    if {[info exists optsArr(-font)]} {
	set theFont $optsArr(-font)
    }
    if {[info exists baselineshift]} {
	set y [expr $y + [BaselineShiftToDy $baselineshift $theFont]]
    }
    return [MergePresentationAttr text $opts $presentationAttr]
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
	set col [MapNoneToEmpty $color]
    }
    return $col
}

# svg2can::StyleToOpts --
# 
#       Takes the style attribute as a list and parses it into
#       resonable canvas drawing options.
#       Discards all attributes that don't map to an item option.
#       
# Arguments:
#       type        tk canvas item type
#       styleList
#       
# Results:
#       list of canvas options

proc svg2can::StyleToOpts {type styleList} {
    
    variable textAnchorMap
    
    # SVG and canvas have different defaults.
    switch -- $type {
	oval - polygon - rectangle {
	    array set optsArr {-fill black -outline ""}
	}
	line {
	    array set optsArr {-fill black}
	}
    }
    set fontSpec {Helvetica 12}
    set haveFont 0
    
    foreach {key value} $styleList {
	
	switch -- $key {
	    fill {
		switch -- $type {
		    oval - polygon - rectangle - text {
			set optsArr(-fill) [parseColor $value]
		    }
		}
	    }
	    font-family {
		lset fontSpec 0 $value
		set haveFont 1
	    }
	    font-size {
		if {[regexp {([0-9]+)pt} $value match pts]} {
		    lset fontSpec 1 $pts
		} else {
		    lset fontSpec 1 $value
		}
		set haveFont 1
	    }
	    font-style {
		switch -- $value {
		    italic {
			lappend fontSpec italic
		    }
		}
		set haveFont 1
	    }
	    font-weight {
		switch -- $value {
		    bold {
			lappend fontSpec bold
		    }
		}
		set haveFont 1
	    }
	    stroke {
		switch -- $type {
		    oval - polygon - rectangle {
			set optsArr(-outline) [parseColor $value]
		    }
		    line {
			set optsArr(-fill) [parseColor $value]
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
		    set optsArr(-capstyle) "projecting"
		}
		if {![string equal $value "butt"]} {
		    set optsArr(-capstyle) $value
		}
	    }
	    stroke-linejoin {
		set optsArr(-joinstyle) $value
	    }
	    stroke-miterlimit {
		# empty
	    }
	    stroke-opacity {
		if {[expr {$value == 0}]} {
		    
		}
	    }
	    stroke-width {
		if {![string equal $type "text"]} {
		    set optsArr(-width) $value
		}
	    }
	    text-anchor {
		set optsArr(-anchor) $textAnchorMap($value)
	    }
	    text-decoration {
		switch -- $value {
		    line-through {
			lappend fontSpec overstrike
		    }
		    underline {
			lappend fontSpec underline
		    }
		}
		set haveFont 1
	    }
	}
    }
    if {$haveFont} {
	set optsArr(-font) $fontSpec
    }
    return [array get optsArr]
}

# svg2can::MergePresentationAttr --
# 
#       Let the style attribute override the presentaion attributes.

proc svg2can::MergePresentationAttr {type opts presentationAttr} {
    
    if {[llength $presentationAttr]} {
	array set optsArr [StyleToOpts $type $presentationAttr]
	array set optsArr $opts
	set opts [array get optsArr]
    }
    return $opts
}

proc svg2can::StyleAttrToList {style} {
    
    return [split [string trim [string map {" " ""} $style] \;] :\;]
}

proc svg2can::BaselineShiftToDy {baselineshift fontSpec} {
    
    set linespace [font metrics $fontSpec -linespace]
    
    switch -regexp -- $baselineshift {
	sub {
	    set dy [expr 0.8 * $linespace]
	}
	super {
	    set dy [expr -0.8 * $linespace]
	}
	{-?[0-9]+%} {
	    set dy [expr 0.01 * $linespace * [string trimright $baselineshift %]]
	}
	default {
	    # 0.5em ?
	    set dy $baselineshift
	}
    }
    return $dy
}

# svg2can::PathAddRelative --
# 
#       Utility function to add a relative point from the path to the 
#       coordinate list. Updates iVar, and the current point.

proc svg2can::PathAddRelative {path coVar iVar cpxVar cpyVar} {
    upvar $coVar  co
    upvar $iVar   i
    upvar $cpxVar cpx
    upvar $cpyVar cpy

    set newx [expr $cpx + [lindex $path [incr i]]]
    set newy [expr $cpy + [lindex $path [incr i]]]
    lappend co $newx $newy
    set cpx $newx
    set cpy $newy
}

proc svg2can::PointsToList {points} {
    
    return [string map {, " "} $points]
}

# svg2can::ParseTransformAttr --
# 
#       Parse the svg syntax for the transform attribute to a simple tcl
#       list.

proc svg2can::ParseTransformAttr {attrlist} {
    
    set cmd ""
    set idx [lsearch -exact $attrlist "transform"]
    if {$idx >= 0} {
	set cmd [lindex $attrlist [incr idx]]
	regsub -all -- {\( *([-0-9]+) *\)} $cmd { \1} cmd
	regsub -all -- {\( *([-0-9]+) *, *([-0-9]+) *\)} $cmd { {\1 \2}} cmd
	regsub -all -- {\( *([-0-9]+) *, *([-0-9]+) *, *([-0-9]+) *\)} \
	  $cmd { {\1 \2 \3}} cmd
    }
    return $cmd
}

# svg2can::CreateTransformCanvasCmdList --
# 
#       Takes a parsed list of transform attributes and turns them
#       into a sequence of canvas commands.

proc svg2can::CreateTransformCanvasCmdList {id transformList} {
    
    set cmdList {}
    foreach {key argument} $transformList {
	
	switch -- $key {
	    translate {
		set dy 0
		foreach {dx dy} $argument break
		lappend cmdList [list move $id $dx $dy]
	    }
	    scale {
		set yScale 0
		foreach {xScale yScale} $argument break
		lappend cmdList [list scale $id 0 0 $xScale $yScale]
	    }
	}
    }
    return $cmdList
}

proc svg2can::MapNoneToEmpty {val} {

    if {[string equal $val "none"]} {
	return ""
    } else {
	return $val
    }
}

proc svg2can::FlattenList {hilist} {
    
    set flatlist {}
    FlatListRecursive $hilist flatlist
    return $flatlist
}

proc svg2can::FlatListRecursive {hilist flatlistVar} {
    upvar $flatlistVar flatlist
    
    if {[string equal [lindex $hilist 0] "create"]} {
	set flatlist [list $hilist]
    } else {
	foreach c $hilist {
	    if {[string equal [lindex $c 0] "create"]} {
		lappend flatlist $c
	    } else {
		FlatListRecursive $c flatlist
	    }
	}
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

# Tests...
if {0} {
    package require svg2can
    toplevel .t
    pack [canvas .t.c -width 600 -height 500]    
    set i 0
    
    set xml([incr i]) {<polyline points='400 10 10 10 10 400' \
      style='stroke: #000000; stroke-width: 1.0; fill: none;'/>}
                    
    # Text
    set xml([incr i]) {<text x='10.0' y='20.0' \
      style='stroke-width: 0; font-family: Helvetica; font-size: 12; \
      fill: #000000;' id='std text t001'>\
      <tspan>Start</tspan><tspan>Mid</tspan><tspan>End</tspan></text>}
    set xml([incr i]) {<text x='10.0' y='40.0' \
      style='stroke-width: 0; font-family: Helvetica; font-size: 12; \
      fill: #000000;' id='std text t002'>One\
      straight text data</text>}
    set xml([incr i]) {<text x='10.0' y='60.0' \
      style='stroke-width: 0; font-family: Helvetica; font-size: 12; \
      fill: #000000;' id='std text t003'>\
      <tspan>Online</tspan><tspan dy='6'>dy=6</tspan><tspan dy='-6'>End</tspan></text>}
    set xml([incr i]) {<text x='10.0' y='90.0' \
      style='stroke-width: 0; font-family: Helvetica; font-size: 16; \
      fill: #000000;' id='std text t004'>\
      <tspan>First</tspan>\
      <tspan dy='10'>Online (dy=10)</tspan>\
      <tspan><tspan>Nested</tspan></tspan><tspan>End</tspan></text>}
    
    # Paths
    set xml([incr i]) {<path d='M 200 100 L 300 100 300 200 200 200 Z' \
      style='fill-rule: evenodd; fill: none; stroke: black; stroke-width: 1.0;\
      stroke-linejoin: round;' id='std poly t005'/>}
    set xml([incr i]) {<path d='M 30 100 Q 80 30 100 100 130 65 200 80' \
      style='fill-rule: evenodd; stroke: #af5da8; stroke-width: 4.0;\
      stroke-linejoin: round;' id='std poly t006'/>}
    set xml([incr i]) {<polyline points='30 100,80 30,100 100,130 65,200 80' \
      style='stroke: red;'/>}
    set xml(8) {<path d='M 10 200 Q 50 150 100 200   \
      150 250 200 200    250 150 300 200    350 250 400 200'\
      style='fill-rule: evenodd; stroke: black; stroke-width: 2.0;\
      stroke-linejoin: round; fill: #d7ffb5;' id='std t008'/>}
    set xml([incr i])  {<path d='M 10 200 H 100 200 v20h 10'\
      style='fill-rule: evenodd; stroke: black; stroke-width: 2.0;\
      stroke-linejoin: round; fill: #d7ffb5;' id='std t008'/>}
    set xml([incr i])  {<path d='M 20 200 V 300 310 h 10 v 10'\
      style='fill-rule: evenodd; stroke: blue; stroke-width: 2.0;\
      stroke-linejoin: round; fill: #d7ffb5;' id='std t008'/>}
    set xml([incr i]) {<path d='M 30 100 Q 80 30 100 100 T 200 80' \
      style='stroke: green; stroke-width: 2.0;' id='t006'/>}
    set xml([incr i]) {<path d='M 30 200 Q 80 130 100 200 T 150 180 200 180 250 180 300 180' \
      style='stroke: gray50; stroke-width: 2.0;' id='t006'/>}
    set xml([incr i]) {<path d='M 30 300 Q 80 230 100 300 t 50 0 50 0 50 0 50 0' \
      style='stroke: gray50; stroke-width: 1.0;' id='std poly t006'/>}
    set xml([incr i]) {<path d="M100,200 C100,100 250,100 250,200 \
      S400,300 400,200" />}
    
    # g
    set xml([incr i]) {<g fill="none" stroke="red" stroke-width="3" > \
      <line x1="300" y1="10" x2="350" y2="10" /> \
      <line x1="300" y1="10" x2="300" y2="50" /> \
      </g>}
    
    # translate
    set xml([incr i]) {<rect id="t0012" x="10" y="10" width="20" height="20" \
      transform="translate(200,200)"/>}
    set xml([incr i]) {<rect id="t0013" x="10" y="10" width="20" height="20" \
      transform="scale(2)"/>}
    
    foreach i [lsort -integer [array names xml]] {
	set xmllist [tinydom::documentElement [tinydom::parse $xml($i)]]
	set cmdList [svg2can::parseelement $xmllist {}]
	foreach c $cmdList {
	    puts $c
	    eval .t.c $c
	}
    }
    
}
    
#-------------------------------------------------------------------------------
