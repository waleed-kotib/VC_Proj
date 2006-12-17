#  svg2can.tcl ---
#  
#      This file provides translation from canvas commands to XML/SVG format.
#      
#  Copyright (c) 2004-2005  Mats Bengtsson
#  This source file is distributed under the BSD license.
#
# $Id: svg2can.tcl,v 1.24 2006-12-17 15:51:22 matben Exp $
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
#   0.2      starting support for tkpath package
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

    variable confopts
    array set confopts {
	-foreignobjecthandler ""
	-httphandler          ""
	-imagehandler         ""
    }

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
    
    # We need to have a temporary tag for doing transformations.
    variable tmptag _tmp_transform
    variable pi 3.14159265359
    variable degrees2Radians [expr {2*$pi/360.0}]
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
    
    variable priv
    set priv(havetkpath) 0
    if {![catch {package require tkpath 0.2}]} {
	set priv(havetkpath) 1
    }
}

# svg2can::config --
# 
#       Processes the configuration options.

proc svg2can::config {args} {
    variable confopts
    
    set options [lsort [array names confopts -*]]
    set usage [join $options ", "]
    if {[llength $args] == 0} {
	set result {}
	foreach name $options {
	    lappend result $name $confopts($name)
	}
	return $result
    }
    regsub -all -- - $options {} options
    set pat ^-([join $options |])$
    if {[llength $args] == 1} {
	set flag [lindex $args 0]
	if {[regexp -- $pat $flag]} {
	    return $confopts($flag)
	} else {
	    return -code error "Unknown option $flag, must be: $usage"
	}
    } else {
	foreach {flag value} $args {
	    if {[regexp -- $pat $flag]} {
		set confopts($flag) $value
	    } else {
		return -code error "Unknown option $flag, must be: $usage"
	    }
	}
    }
}

# svg2can::parsesvgdocument --
# 
# 
# Arguments:
#       xmllist     the parsed document as a xml list
#       args        configuration options
#          -httphandler
#    	   -imagehandler            
#       
# Results:
#       a list of canvas commands without the widgetPath

proc svg2can::parsesvgdocument {xmllist args} {
    variable confopts

    array set argsA [array get confopts]
    array set argsA $args
    set paropts [array get argsA]
        
    set ans {}
    foreach c [getchildren $xmllist] {
	set ans [concat $ans [ParseElemRecursive $c $paropts {}]]
    }
    return $ans
}

# svg2can::parseelement --
# 
#       External interface for parsing a single element.
# 
# Arguments:
#       xmllist     the elements xml list
#       args        configuration options
#          -httphandler
#    	   -imagehandler            
#       
# Results:
#       a list of canvas commands without the widgetPath

proc svg2can::parseelement {xmllist args} {
    variable confopts

    array set argsA [array get confopts]
    array set argsA $args
    set paropts [array get argsA]
    
    return [ParseElemRecursive $xmllist $paropts {}]
}

# svg2can::ParseElemRecursive --
# 
#       Parses element for internal usage.
#       
# Arguments:
#       xmllist     the elements xml list
#       paropts     parse options
#       transformL
#       args        list of attributes from any enclosing element (g).
#       
# Results:
#       a list of canvas commands without the widgetPath

proc svg2can::ParseElemRecursive {xmllist paropts transformL args} {
    variable priv

    set cmdList {}
    set tag [gettag $xmllist]
    
    # Handle any tranform attribute; may be recursive, so keep a list.
    set transformL [concat $transformL [ParseTransformAttr [getattr $xmllist]]]

    switch -- $tag {
	circle - ellipse - image - line - polyline - polygon - rect - path - text {
	    set func [string totitle $tag]
	    if {$priv(havetkpath)} {
		set cmd [eval {Parse${func}Ex $xmllist $paropts} $args]]
		if {[llength $cmd]} {
		    lappend cmdList $cmd
		}
	    } else {
		set cmdL [eval {Parse${func} $xmllist $paropts $transformL} $args]]
		set cmdList [concat $cmdList $cmdL]
	    }
	}
	a - g {
	    # Need to collect the attributes for the g element since
	    # the child elements inherit them. g elements may be nested!
	    array set attrA $args
	    array set attrA [getattr $xmllist]
	    foreach c [getchildren $xmllist] {
		set cmdList [concat $cmdList [eval {
		    ParseElemRecursive $c $paropts $transformL
		} [array get attrA]]]
	    }	    
	}
	foreignObject {
	    array set parseArr $paropts
	    if {[string length $parseArr(-foreignobjecthandler)]} {
		set elem [uplevel #0 $parseArr(-foreignobjecthandler) \
		  [list $xmllist $paropts $transformL] $args]
		if {$elem != ""} {
		    set cmdList [concat $cmdList $elem]
		}
	    }
	}
	use - defs - marker - symbol {
	    # todo
	}
    }
    return $cmdList
}

# @@@ Maybe???
#     How to handle group elements matrix and x y attributes???

proc svg2can::ParseElemRecursiveEx {xmllist paropts args} {
    
    
}

# svg2can::ParseCircle, ParseEllipse, ParseLine, ParseRect, ParsePath, 
#   ParsePolyline, ParsePolygon, ParseImage --
# 
#       Makes the necessary canvas commands needed to reproduce the
#       svg element.
#       
# Arguments:
#       xmllist
#       paropts     parse options
#       transformL
#       args        list of attributes from any enclosing element (g).
#       
# Results:
#       list of canvas create command without the widgetPath.

proc svg2can::ParseCircle {xmllist paropts transformL args} {
    variable tmptag
    
    set opts {}
    set presAttr {}
    set cx 0
    set cy 0
    set r 0
    array set attrA $args
    array set attrA [getattr $xmllist]
    
    # We need to have a temporary tag for doing transformations.
    set tags {}
    if {[llength $transformL]} {
	lappend tags $tmptag
    }
    
    foreach {key value} [array get attrA] {	
	switch -- $key {
	    cx - cy - r {
		set $key [parseLength $value]
	    }
	    id {
		set tags [concat $tags $value]
	    }
	    style {
		set opts [StyleToOpts oval [StyleAttrToList $value]]
	    }
	    default {
		# Valid itemoptions will be sorted out below.
		lappend presAttr $key $value
	    }
	}
    }
    lappend opts -tags $tags
    set coords [list [expr {$cx - $r}] [expr {$cy - $r}] \
      [expr {$cx + $r}] [expr {$cy + $r}]]	
    set opts [MergepresAttr oval $opts $presAttr]
    set cmdList [list [concat create oval $coords $opts]]

    return [AddAnyTransformCmds $cmdList $transformL]
}

proc svg2can::ParseCircleEx {xmllist paropts args} {

    set opts {}
    set cx 0
    set cy 0
    set presAttr {}
    array set attrA $args
    array set attrA [getattr $xmllist]

    foreach {key value} [array get attrA] {	
	switch -- $key {
	    cx - cy {
		set $key [parseLength $value]
	    }
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [StyleToOptsEx [StyleAttrToList $value]]
	    }
	    default {
		lappend presAttr $key $value
	    }
	}
    }
    set opts [MergepresAttrEx $opts $presAttr]
    return [concat create circle $cx $cy $opts]
}

proc svg2can::ParseEllipse {xmllist paropts transformL args} {
    variable tmptag
    
    set opts {}
    set presAttr {}
    set cx 0
    set cy 0
    set rx 0
    set ry 0
    array set attrA $args
    array set attrA [getattr $xmllist]
    set tags {}
    if {[llength $transformL]} {
	lappend tags $tmptag
    }
    
    foreach {key value} [array get attrA] {
	
	switch -- $key {
	    cx - cy - rx - ry {
		set $key [parseLength $value]
	    }
	    id {
		set tags [concat $tags $value]
	    }
	    style {
		set opts [StyleToOpts oval [StyleAttrToList $value]]
	    }
	    default {
		lappend presAttr $key $value
	    }
	}
    }
    lappend opts -tags $tags
    set coords [list [expr $cx - $rx] [expr $cy - $ry] \
      [expr $cx + $rx] [expr $cy + $ry]]
    set opts [MergepresAttr oval $opts $presAttr]
    set cmdList [list [concat create oval $coords $opts]]

    return [AddAnyTransformCmds $cmdList $transformL]
}

proc svg2can::ParseEllipseEx {xmllist paropts args} {

    set opts {}
    set cx 0
    set cy 0
    set presAttr {}
    array set attrA $args
    array set attrA [getattr $xmllist]

    foreach {key value} [array get attrA] {	
	switch -- $key {
	    cx - cy {
		set $key [parseLength $value]
	    }
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [StyleToOptsEx [StyleAttrToList $value]]
	    }
	    default {
		lappend presAttr $key $value
	    }
	}
    }
    set opts [MergepresAttrEx $opts $presAttr]
    return [concat create ellipse $cx $cy $opts]    
}

proc svg2can::ParseImage {xmllist paropts transformL args} {
    variable tmptag
    
    set x 0
    set y 0    
    set presAttr {}
    set photo {}
    array set attrA $args
    array set attrA [getattr $xmllist]
    array set paroptsA $paropts
    set tags {}
    if {[llength $transformL]} {
	lappend tags $tmptag
    }

    foreach {key value} [array get attrA] {	
	switch -- $key {
	    x - y - height - width {
		# The canvas image item does not have width and height.
		# These are REQUIRED in SVG.
		set $key [parseLength $value]
	    }
	    id {
		set tags [concat $tags $value]
	    }
	    style {
		set opts [StyleToOpts image [StyleAttrToList $value]]
	    }
	    xlink:href {
		set xlinkhref $value
	    }
	    default {
		lappend presAttr $key $value
	    }
	}
    }
    lappend opts -tags $tags -anchor nw
    set opts [MergepresAttr image $opts $presAttr]
    
    # Handle the xlink:href attribute.
    if {[info exists xlinkhref]} {
	
	switch -glob -- $xlinkhref {
	    file:/* {			
		set path [uriencode::decodefile $xlinkhref]
		set path [string map {file:/// /} $path]
		if {[string length $paroptsA(-imagehandler)]} {		    
		    set cmd [concat create image $x $y $opts]
		    lappend cmd -file $path -height $height -width $width
		    set photo [uplevel #0 $paroptsA(-imagehandler) [list $cmd]]
		    lappend opts -image $photo
		} else {			
		    if {[string tolower [file extension $path]] eq ".gif"} {
			set photo [image create photo -file $path -format gif]
		    } else {
			set photo [image create photo -file $path]
		    }
		    lappend opts -image $photo
		}
	    }
	    http:/* {
		if {[string length $paroptsA(-httphandler)]} {
		    set cmd [concat create image $x $y $opts]
		    lappend cmd -url $xlinkhref  -height $height -width $width
		    uplevel #0 $paroptsA(-httphandler) [list $cmd]
		}
		return
	    }
	    default {
		return
	    }
	}	
    }
    set cmd [concat create image $x $y $opts]
    set cmdList [list $cmd]

    return [AddAnyTransformCmds $cmdList $transformL]
}

proc svg2can::ParseImageEx {xmllist paropts args} {

    set x 0
    set y 0    
    set width  0
    set height 0
    set opts {}
    set presAttr {}
    array set attrA $args
    array set attrA [getattr $xmllist]

    foreach {key value} [array get attrA] {	
	switch -- $key {
	    x - y {
		set $key [parseLength $value]
	    }
	    height - width {
		# A value of 0 disables rendering in SVG.
		# tkpath uses 0 for using natural sizes.
		if {$value == 0.0} {
		    return
		}
		set $key [parseLength $value]
	    }
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [StyleToOptsEx [StyleAttrToList $value]]
	    }
	    xlink:href {
		set xlinkhref $value
	    }
	    default {
		lappend presAttr $key $value
	    }
	}
    }
    lappend opts -width $width -height $height

    # Handle the xlink:href attribute.
    if {[info exists xlinkhref]} {

	switch -glob -- $xlinkhref {
	    file:/* {			
		set path [uriencode::decodefile $xlinkhref]
		set path [string map {file:/// /} $path]
		if {[string length $paroptsA(-imagehandler)]} {		    
		    set cmd [concat create image $x $y $opts]
		    lappend cmd -file $path -height $height -width $width
		    set photo [uplevel #0 $paroptsA(-imagehandler) [list $cmd]]
		    lappend opts -image $photo
		} else {			
		    if {[string tolower [file extension $path]] eq ".gif"} {
			set photo [image create photo -file $path -format gif]
		    } else {
			set photo [image create photo -file $path]
		    }
		    lappend opts -image $photo
		}
	    }
	    http:/* {
		if {[string length $paroptsA(-httphandler)]} {
		    set cmd [concat create image $x $y $opts]
		    lappend cmd -url $xlinkhref -height $height -width $width
		    uplevel #0 $paroptsA(-httphandler) [list $cmd]
		}
		return
	    }
	    default {
		return
	    }
	}	
    }
    
    set opts [MergepresAttrEx $opts $presAttr]
    return [concat create pimage $x $y $opts]    
}

proc svg2can::ParseLine {xmllist paropts transformL args} {
    variable tmptag
    
    set opts {}
    set coords {0 0 0 0}
    set presAttr {}
    array set attrA $args
    array set attrA [getattr $xmllist]
    set tags {}
    if {[llength $transformL]} {
	lappend tags $tmptag
    }
    
    foreach {key value} [array get attrA] {
	
	switch -- $key {
	    id {
		set tags [concat $tags $value]
	    }
	    style {
		set opts [StyleToOpts line [StyleAttrToList $value]]
	    }
	    x1 {
		lset coords 0 [parseLength $value]
	    }
	    y1 {
		lset coords 1 [parseLength $value]
	    }
	    x2 {
		lset coords 2 [parseLength $value]
	    }
	    y2 {
		lset coords 3 [parseLength $value]
	    }
	    default {
		lappend presAttr $key $value
	    }
	}
    }
    lappend opts -tags $tags
    set opts [MergepresAttr line $opts $presAttr]  
    set cmdList [list [concat create line $coords $opts]]

    return [AddAnyTransformCmds $cmdList $transformL]
}

proc svg2can::ParseLineEx {xmllist paropts args} {

    set x1 0
    set y1 0
    set x2 0
    set y2 0
    set opts {}
    set presAttr {}
    array set attrA $args
    array set attrA [getattr $xmllist]

    foreach {key value} [array get attrA] {	
	switch -- $key {
	    x1 - y1 - x2 - y2 {
		set $key [parseLength $value]
	    }
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [StyleToOptsEx [StyleAttrToList $value]]
	    }
	    default {
		lappend presAttr $key $value
	    }
	}
    }
    set opts [MergepresAttrEx $opts $presAttr]
    return [concat create line $x1 $y1 $x2 $y2 $opts]    
}

proc svg2can::ParsePath {xmllist paropts transformL args} {
    variable tmptag
    
    set debug 0
    set cmdList {}
    set opts {}
    set presAttr {}
    set path {}
    set styleList {}
    set lineopts {}
    set polygonopts {}
    array set attrA $args
    array set attrA [getattr $xmllist]
    set tags {}
    if {[llength $transformL]} {
	lappend tags $tmptag
    }
    
    foreach {key value} [array get attrA] {
	
	switch -- $key {
	    d {
		set path $value
	    }
	    id {
		set tags [concat $tags $value]
	    }
	    style {
		# Need to parse separately for each canvas item since different
		# default values.
		set lineopts    [StyleToOpts line    [StyleAttrToList $value]]
		set polygonopts [StyleToOpts polygon [StyleAttrToList $value]]
	    }
	    default {
		lappend presAttr $key $value
	    }
	}
    }

    # The resulting canvas items are typically lines and polygons.
    # Since the style parsing is different keep separate copies.
    lappend lineopts    -tags $tags
    lappend polygonopts -tags $tags
    set lineopts    [MergePresentationAttr line    $lineopts    $presAttr]
    set polygonopts [MergePresentationAttr polygon $polygonopts $presAttr]
    
    # Parse the actual path data. 
    set co {}
    set cantype line
    set itemopts {}
    
    regsub -all -- {([a-zA-Z])([0-9])} $path {\1 \2} path
    regsub -all -- {([0-9])([a-zA-Z])} $path {\1 \2} path
    set path [string map {- " -"} $path]
    set path [string map {, " "} $path]
    
    # Debug.
    if {$debug} {
	for {set i 0} {$i < [llength $path]} {incr i} {
	    puts "$i: [lindex $path $i]"
	}
    }
    
    set i 0
    set len  [llength $path]
    set len1 [expr $len - 1]
    set len2 [expr $len - 2]
    set len4 [expr $len - 4]
    set len6 [expr $len - 6]
    
    # 'i' is the index into the path list; points to the command (character).
    
    while {$i < $len} {
	set elem [lindex $path $i]
	set isabsolute 1
	if {[string is lower $elem]} {
	    set isabsolute 0
	}
	if {$debug} {
	    puts "elem=$elem"
	}
	
	switch -glob -- $elem {
	    A - a {
		# Not part of Tiny SVG.
		incr i
		foreach {rx ry phi fa fs x y} [lrange $path $i [expr $i + 6]] break
		if {!$isabsolute} {
		    set x [expr $cpx + $x] 
		    set y [expr $cpy + $y]
		    
		}
		set arcpars \
		  [EllipticArcParameters $cpx $cpy $rx $ry $phi $fa $fs $x $y]
		
		# Handle special cases.
		switch -- $arcpars {
		    skip {
			# Empty
		    }
		    lineto {
			lappend co [lindex $path [expr $i + 5]] \
			  [lindex $path [expr $i + 6]]
		    }
		    default {
			
			# Need to end any previous path.
			if {[llength $co] > 2} {
			    set opts [concat [set ${cantype}opts] $itemopts]
			    lappend cmdList [concat create $cantype $co $opts]
			}

			# Cannot handle rotations.
			foreach {cx cy rx ry theta delta phi} $arcpars break
			set box [list [expr $cx-$rx] [expr $cy-$ry] \
			  [expr $cx+$rx] [expr $cy+$ry]]
			set itemopts [list -start $theta -extent $delta]
			
			# Try to interpret any subsequent data as a
			# -style chord | pieslice.
			# Z: chord; float float Z: pieslice.
			set ia [expr $i + 7]
			set ib [expr $i + 10]
			
			if {[regexp -nocase {z} [lrange $path $ia $ia]]} {
			    lappend itemopts -style chord
			    incr i 1
			} elseif {[regexp -nocase {l +([-0-9\.]+) +([-0-9\.]+) +z} \
			  [lrange $path $ia $ib] m mx my] &&  \
			  [expr hypot($mx-$cx, $my-$cy)] < 4.0} {
			    lappend itemopts -style pieslice
			    incr i 4
			} else {
			    lappend itemopts -style arc
			}
			set opts [concat $polygonopts $itemopts]
			lappend cmdList [concat create arc $box $opts]
			set co {}
			set itemopts {}
		    }
		}
		incr i 6
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
			if {$debug} {
			    puts "PathAddRelative i=$i, cpx=$cpx, cpy=$cpy"
			}
			PathAddRelative $path co i cpx cpy
			PathAddRelative $path co i cpx cpy
			PathAddRelative $path co i cpx cpy
		    }
		    
		    # Do not finalize item if S instruction.
		    if {![string equal -nocase [lindex $path [expr $i+1]] "S"]} {
			if {$debug} {
			    puts "\tfinalize item: i=$i, cp=($cpx,$cpy), co=$co"
			}
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
		    
		    # Do not finalize item if T instruction.
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
		
		# Finalize item.
		lappend itemopts -smooth 1
		set dx [expr [lindex $co 0] - [lindex $co end-1]]
		set dy [expr [lindex $co 1] - [lindex $co end]]
		
		# Check endpoints to see if closed polygon.
		# Remove first AND end points if closed!
		if {[expr hypot($dx, $dy)] < 0.5} {
		    set opts [concat $polygonopts $itemopts]
		    set co [lrange $co 2 end-2]
		    lappend cmdList [concat create polygon $co $opts]
		} else {
		    set opts [concat $lineopts $itemopts]
		    lappend cmdList [concat create line $co $opts]
		}
		set co {}
		set itemopts {}
		incr i
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
		
		# Finalize item.
		lappend itemopts -smooth 1
		set dx [expr [lindex $co 0] - [lindex $co end-1]]
		set dy [expr [lindex $co 1] - [lindex $co end]]
		#puts "\tco=$co"
		
		# Check endpoints to see if closed polygon.
		# Remove first AND end points if closed!
		if {[expr hypot($dx, $dy)] < 0.5} {
		    set opts [concat $polygonopts $itemopts]
		    set co [lrange $co 2 end-2]
		    lappend cmdList [concat create polygon $co $opts]
		} else {
		    set opts [concat $lineopts $itemopts]
		    lappend cmdList [concat create line $co $opts]		    
		}
		set co {}
		set itemopts {}
		incr i
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
	}   ;# End switch.
	
	# Keep track of the pens current point.
	if {[llength $co]} {
	    set cpx [lindex $co end-1]
	    set cpy [lindex $co end]
	}
	if {$debug} {
	    puts "end loop: cp=($cpx,$cpy)"
	}
    }   ;# End while loop.
    
    # Finalize the last element if any.
    if {[llength $co]} {
	set opts [concat [set ${cantype}opts] $itemopts]
	lappend cmdList [concat create $cantype $co $opts]
    }
    if {$debug} {
	foreach cmd $cmdList {
	    puts "cmd=$cmd"
	}
    }
    return [AddAnyTransformCmds $cmdList $transformL]
}

proc svg2can::ParsePathEx {xmllist paropts args} {
    
    set opts {}
    set presAttr {}
    set path {}
    array set attrA $args
    array set attrA [getattr $xmllist]
    
    foreach {key value} [array get attrA] {
	switch -- $key {
	    d { 
		set path $value 
	    }
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [StyleToOptsEx [StyleAttrToList $value]] 
	    }
	    default {
		lappend presAttr $key $value 
	    }
	}
    }
    set opts [MergePresentationAttr line $opts $presAttr]  
    
    regsub -all -- {([a-zA-Z])([0-9])} $path {\1 \2} path
    regsub -all -- {([0-9])([a-zA-Z])} $path {\1 \2} path
    set path [string map {- " -"} $path]
    set path [string map {, " "} $path]
	
    set opts [MergepresAttrEx $opts $presAttr]
    return [concat create path [list $path] $opts]]  
}

proc svg2can::ParsePolyline {xmllist paropts transformL args} {
    variable tmptag
    
    set coords {}
    set opts {}
    set presAttr {}
    array set attrA $args
    array set attrA [getattr $xmllist]
    set tags {}
    if {[llength $transformL]} {
	lappend tags $tmptag
    }

    foreach {key value} [array get attrA] {
	
	switch -- $key {
	    points {
		set coords [PointsToList $value]
	    }
	    id {
		set tags [concat $tags $value]
	    }
	    style {
		set opts [StyleToOpts line [StyleAttrToList $value]]
	    }
	    default {
		lappend presAttr $key $value
	    }
	}
    }
    lappend opts -tags $tags
    set opts [MergePresentationAttr line $opts $presAttr]
    set cmdList [list [concat create line $coords $opts]]

    return [AddAnyTransformCmds $cmdList $transformL]
}

proc svg2can::ParsePolylineEx {xmllist paropts args} {

    set opts {}
    set points {0 0}
    set presAttr {}
    array set attrA $args
    array set attrA [getattr $xmllist]

    foreach {key value} [array get attrA] {	
	switch -- $key {
	    points {
		set points [PointsToList $value]
	    }
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [StyleToOptsEx [StyleAttrToList $value]]
	    }
	    default {
		lappend presAttr $key $value
	    }
	}
    }
    set opts [MergepresAttrEx $opts $presAttr]
    return [concat create polyline $points $opts]    
}

proc svg2can::ParsePolygon {xmllist paropts transformL args} {
    variable tmptag
    
    set coords {}
    set opts {}
    set presAttr {}
    array set attrA $args
    array set attrA [getattr $xmllist]
    set tags {}
    if {[llength $transformL]} {
	lappend tags $tmptag
    }

    foreach {key value} [array get attrA] {
	
	switch -- $key {
	    points {
		set coords [PointsToList $value]
	    }
	    id {
		set tags [concat $tags $value]
	    }
	    style {
		set opts [StyleToOpts polygon [StyleAttrToList $value]]
	    }
	    default {
		lappend presAttr $key $value
	    }
	}
    }
    lappend opts -tags $tags
    set opts [MergePresentationAttr polygon $opts $presAttr]
    set cmdList [list [concat create polygon $coords $opts]]

    return [AddAnyTransformCmds $cmdList $transformL]
}

proc svg2can::ParsePolygonEx {xmllist paropts args} {

    set opts {}
    set points {0 0}
    set presAttr {}
    array set attrA $args
    array set attrA [getattr $xmllist]

    foreach {key value} [array get attrA] {	
	switch -- $key {
	    points {
		set points [PointsToList $value]
	    }
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [StyleToOptsEx [StyleAttrToList $value]]
	    }
	    default {
		lappend presAttr $key $value
	    }
	}
    }
    set opts [MergepresAttrEx $opts $presAttr]
    return [concat create ppolygon $points $opts]    
}

proc svg2can::ParseRect {xmllist paropts transformL args} {
    variable tmptag
    
    set opts {}
    set coords {0 0 0 0}
    set presAttr {}
    array set attrA $args
    array set attrA [getattr $xmllist]
    set tags {}
    if {[llength $transformL]} {
	lappend tags $tmptag
    }
    
    foreach {key value} [array get attrA] {
	
	switch -- $key {
	    id {
		set tags [concat $tags $value]
	    }
	    rx - ry {
		# unsupported :-(
	    }
	    style {
		set opts [StyleToOpts rectangle [StyleAttrToList $value]]
	    }
	    x - y - width - height {
		set $key [parseLength $value]
	    }
	    default {
		lappend presAttr $key $value
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
    lappend opts -tags $tags
    set opts [MergePresentationAttr rectangle $opts $presAttr]
    set cmdList [list [concat create rectangle $coords $opts]]

    return [AddAnyTransformCmds $cmdList $transformL]
}

proc svg2can::ParseRectEx {xmllist paropts args} {

    set opts {}
    set x 0
    set y 0
    set width  0
    set height 0
    set presAttr {}
    array set attrA $args
    array set attrA [getattr $xmllist]

    foreach {key value} [array get attrA] {	
	switch -- $key {
	    x - y - width - height {
		set $key [parseLength $value]
	    }
	    id {
		lappend opts -tags $value
	    }
	    style {
		set opts [StyleToOptsEx [StyleAttrToList $value]]
	    }
	    default {
		lappend presAttr $key $value
	    }
	}
    }
    set x2 [expr {$x + $width}]
    set y2 [expr {$y + $height}]
    set opts [MergepresAttrEx $opts $presAttr]
    return [concat create prect $x $y $x2 $y2 $opts]    
}

# svg2can::ParseText --
# 
#       Takes a text element and returns a list of canvas create text commands.
#       Assuming that chdata is not mixed with elements, we should now have
#       either chdata OR more elements (tspan).

proc svg2can::ParseText {xmllist paropts transformL args} {
    
    set x 0
    set y 0
    set xAttr 0
    set yAttr 0
    set cmdList [ParseTspan $xmllist $transformL x y xAttr yAttr {}]

    return $cmdList
}

proc svg2can::ParseTextEx {xmllist paropts args} {
    return [eval {ParseText $xmllist $paropts {}} $args]
}

# svg2can::ParseTspan --
# 
#       Takes a tspan or text element and returns a list of canvas
#       create text commands.

proc svg2can::ParseTspan {xmllist transformL xVar yVar xAttrVar yAttrVar opts} { 
    variable tmptag
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
    array set optsA $opts
    array set optsA [ParseTextAttr $xmllist xAttr yAttr baselineShift]

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
	set opts [array get optsA]
	foreach c $childList {
	    
	    switch -- [gettag $c] {
		tspan {
		    set cmdList [concat $cmdList \
		      [ParseTspan $c $transformL x y xAttr yAttr $opts]]
		}
		default {
		    # empty
		}
	    }
	}
    } else {
	set str [getcdata $xmllist]
	set optsA(-text) $str
	if {[llength $transformL]} {
	    lappend optsA(-tags) $tmptag
	}
	set opts [array get optsA]
	set theFont $systemFont
	if {[info exists optsA(-font)]} {
	    set theFont $optsA(-font)
	}
	
	# Need to adjust the text position so that the baseline matches y.
	# nw to baseline
	set ascent [font metrics $theFont -ascent]
	set cmdList [list [concat create text  \
	  $xAttr [expr $yAttr - $ascent + $baselineShift] $opts]]	
	set cmdList [AddAnyTransformCmds $cmdList $transformL]
	
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

proc svg2can::ParseTextAttr {xmllist xVar yVar baselineShiftVar} {    
    variable systemFont
    upvar $xVar x
    upvar $yVar y
    upvar $baselineShiftVar baselineShift

    # svg defaults to start with y being the baseline while tk default is c.
    #set opts {-anchor sw}
    # Anchor nw is simplest when newlines.
    set opts {-anchor nw}
    set presAttr {}
    set baselineShift 0
    
    foreach {key value} [getattr $xmllist] {
	
	switch -- $key {
	    baseline-shift {
		set baselineShiftSet $value
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
		lappend presAttr $key $value
	    }
	}
    }
    array set optsA $opts
    set theFont $systemFont
    if {[info exists optsA(-font)]} {
	set theFont $optsA(-font)
    }
    if {[info exists baselineShiftSet]} {
	set baselineShift [BaselineShiftToDy $baselineShiftSet $theFont]
    }
    return [MergePresentationAttr text $opts $presAttr]
}

# svg2can::AttrToCoords --
# 
#       Returns coords from SVG attributes.
#       
# Arguments:
#       type        SVG type
#       attr        list of geometry attributes
#       
# Results:
#       list of coordinates

proc svg2can::AttrToCoords {type attrlist} {
    
    # Defaults.
    array set attr {
	cx      0
	cy      0
	height  0
	r       0
	rx      0
	ry      0
	width   0
	x       0
	x1      0
	x2      0
	y       0
	y1      0
	y2      0
    }
    array set attr $attrlist
    
    switch -- $type {
	circle {
	    set coords [list  \
	      [expr $attr(cx) - $attr(r)] [expr $attr(cy) - $attr(r)] \
	      [expr $attr(cx) + $attr(r)] [expr $attr(cy) + $attr(r)]]	
	}
	ellipse {
	    set coords [list  \
	      [expr $attr(cx) - $attr(rx)] [expr $attr(cy) - $attr(ry)] \
	      [expr $attr(cx) + $attr(rx)] [expr $attr(cy) + $attr(ry)]]
	}
	image {
	    set coords [list $attr(x) $attr(y)]
	}
	line {
	    set coords [list $attr(x1) $attr(y1) $attr(x2) $attr(y2)]
	}
	path {
	    # empty
	}
	polygon {
	    set coords [PointsToList $attr(points)] 
	}
	polyline {
	    set coords [PointsToList $attr(points)] 
	}
	rect {
	    set coords [list $attr(x) $attr(y) \
	      [expr $attr(x) + $attr(width)] [expr $attr(y) + $attr(height)]]
	}
	text {
	    set coords [list $attr(x) $attr(y)]
	}
    }
    return $coords
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

proc svg2can::parseLength {length} {    
    if {[string is double -strict $length]} {
	return $length
    }    
    # SVG is using: px, pt, mm, cm, em, ex, in, %.
    # @@@ Incomplete!
    set length [string map {px ""  pt p  mm m  cm c  in i} $length]
    return [winfo fpixels . $length]
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

proc svg2can::StyleToOpts {type styleList args} {
    
    variable textAnchorMap
    
    array set argsA {
	-setdefaults 1 
	-origfont    {Helvetica 12}
    }
    array set argsA $args

    # SVG and canvas have different defaults.
    if {$argsA(-setdefaults)} {
	switch -- $type {
	    oval - polygon - rectangle {
		array set optsA {-fill black -outline ""}
	    }
	    line {
		array set optsA {-fill black}
	    }
	}
    }
    
    set fontSpec $argsA(-origfont)
    set haveFont 0
    
    foreach {key value} $styleList {
	
	switch -- $key {
	    fill {
		switch -- $type {
		    arc - oval - polygon - rectangle - text {
			set optsA(-fill) [parseColor $value]
		    }
		}
	    }
	    font-family {
		lset fontSpec 0 $value
		set haveFont 1
	    }
	    font-size {
		
		# Use pixels instead of points.
		if {[regexp {([0-9\.]+)pt} $value match pts]} {
		    set pix [expr int($pts * [tk scaling] + 0.01)]
		    lset fontSpec 1 "-$pix"
		} elseif {[regexp {([0-9\.]+)px} $value match pix]} {
		    lset fontSpec 1 "-$pix"
		} else {
		    lset fontSpec 1 "-$value"
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
	    marker-end {
		set optsA(-arrow) last
	    }
	    marker-start {
		set optsA(-arrow) first		
	    }
	    stroke {
		switch -- $type {
		    arc - oval - polygon - rectangle {
			set optsA(-outline) [parseColor $value]
		    }
		    line {
			set optsA(-fill) [parseColor $value]
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
		    set optsA(-capstyle) "projecting"
		}
		if {![string equal $value "butt"]} {
		    set optsA(-capstyle) $value
		}
	    }
	    stroke-linejoin {
		set optsA(-joinstyle) $value
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
		    set optsA(-width) $value
		}
	    }
	    text-anchor {
		set optsA(-anchor) $textAnchorMap($value)
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
	set optsA(-font) $fontSpec
    }
    return [array get optsA]
}

proc svg2can::StyleToOptsEx {styleList args} {
    
    array set optsA {-fill black -stroke ""}
    
    foreach {key value} $styleList {
    
	switch -- $key {
	    fill - stroke {
		set optsA(-$key) [parseColor $value]		
	    }
	    stroke-dasharray - strokelinecap - strokelinejoin - \
	      strokemiterlimit - strokeopacity {		
		set name [string map {"-" ""} $key]
		set optsA(-$name) $value
	    }
	    strokewidth {		
		set optsA(-$name) [parseLength $value]
	    }
	    r - rx - ry - width - height {
		set optsA(-$name) [parseLength $value]
	    }
	    transform {
		if {[string length $value]} {
		    set optsA(-matrix) [TransformAttrToMatrix $value]
		}
	    }
	}
    }
    return [array get optsA]
}

# svg2can::EllipticArcParameters --
# 
#       Conversion from endpoint to center parameterization.
#       From: http://www.w3.org/TR/2003/REC-SVG11-20030114

proc svg2can::EllipticArcParameters {x1 y1 rx ry phi fa fs x2 y2} {
    variable pi

    # NOTE: direction of angles are opposite for Tk and SVG!
    
    # F.6.2 Out-of-range parameters 
    if {($x1 == $x2) && ($y1 == $y2)} {
	return skip
    }
    if {[expr $rx == 0] || [expr $ry == 0]} {
	return lineto
    }
    set rx [expr abs($rx)]
    set ry [expr abs($ry)]
    set phi [expr fmod($phi, 360) * $pi/180.0]
    if {$fa != 0} {
	set fa 1
    }
    if {$fs != 0} {
	set fs 1
    }
    
    # F.6.5 Conversion from endpoint to center parameterization 
    set dx [expr ($x1-$x2)/2.0]
    set dy [expr ($y1-$y2)/2.0]
    set x1prime [expr cos($phi) * $dx + sin($phi) * $dy]
    set y1prime [expr -sin($phi) * $dx + cos($phi) * $dy]
    
    # F.6.6 Correction of out-of-range radii
    set rx [expr abs($rx)]
    set ry [expr abs($ry)]
    set x1prime2 [expr $x1prime * $x1prime]
    set y1prime2 [expr $y1prime * $y1prime]
    set rx2 [expr $rx * $rx]
    set ry2 [expr $ry * $ry]
    set lambda [expr $x1prime2/$rx2 + $y1prime2/$ry2]
    if {$lambda > 1.0} {
	set rx [expr sqrt($lambda) * $rx]
	set ry [expr sqrt($lambda) * $ry]
	set rx2 [expr $rx * $rx]
	set ry2 [expr $ry * $ry]
    }    
    
    # Compute cx' and cy'
    set sign [expr {$fa == $fs} ? -1 : 1]
    set square [expr ($rx2 * $ry2 - $rx2 * $y1prime2 - $ry2 * $x1prime2) /  \
      ($rx2 * $y1prime2 + $ry2 * $x1prime2)]
    set root [expr sqrt(abs($square))]
    set cxprime [expr  $sign * $root * $rx * $y1prime/$ry]
    set cyprime [expr -$sign * $root * $ry * $x1prime/$rx]
    
    # Compute cx and cy from cx' and cy'
    set cx [expr $cxprime * cos($phi) - $cyprime * sin($phi) + ($x1 + $x2)/2.0]
    set cy [expr $cxprime * sin($phi) + $cyprime * cos($phi) + ($y1 + $y2)/2.0]

    # Compute start angle and extent
    set ux [expr ($x1prime - $cxprime)/double($rx)]
    set uy [expr ($y1prime - $cyprime)/double($ry)]
    set vx [expr (-$x1prime - $cxprime)/double($rx)]
    set vy [expr (-$y1prime - $cyprime)/double($ry)]

    set sign [expr {$uy > 0} ? 1 : -1]
    set theta [expr $sign * acos( $ux/hypot($ux, $uy) )]

    set sign [expr {$ux * $vy - $uy * $vx > 0} ? 1 : -1]
    set delta [expr $sign * acos( ($ux * $vx + $uy * $vy) /  \
      (hypot($ux, $uy) * hypot($vx, $vy)) )]
    
    # To degrees
    set theta [expr $theta * 180.0/$pi]
    set delta [expr $delta * 180.0/$pi]
    #set delta [expr fmod($delta, 360)]
    set phi   [expr fmod($phi, 360)]
    
    if {($fs == 0) && ($delta > 0)} {
	set delta [expr $delta - 360]
    } elseif {($fs ==1) && ($delta < 0)} {
	set delta [expr $delta + 360]
    }

    # NOTE: direction of angles are opposite for Tk and SVG!
    set theta [expr -1*$theta]
    set delta [expr -1*$delta]
    
    return [list $cx $cy $rx $ry $theta $delta $phi]
}

# svg2can::MergePresentationAttr --
# 
#       Let the style attribute override the presentation attributes.

proc svg2can::MergePresentationAttr {type opts presAttr} {
    
    if {[llength $presAttr]} {
	array set optsA [StyleToOpts $type $presAttr]
	array set optsA $opts
	set opts [array get optsA]
    }
    return $opts
}

proc svg2can::MergePresentationAttrEx {opts presAttr} {
    
    if {[llength $presAttr]} {
	array set optsA [StyleToOptsEx $presAttr]
	array set optsA $opts
	set opts [array get optsA]
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
	set cmd [TransformAttrToList [lindex $attrlist [incr idx]]]
    }
    return $cmd
}

proc svg2can::TransformAttrToList {cmd} {    
    regsub -all -- {\( *([-0-9.]+) *\)} $cmd { \1} cmd
    regsub -all -- {\( *([-0-9.]+)[ ,]+([-0-9.]+) *\)} $cmd { {\1 \2}} cmd
    regsub -all -- {\( *([-0-9.]+)[ ,]+([-0-9.]+)[ ,]+([-0-9.]+) *\)} \
      $cmd { {\1 \2 \3}} cmd
    regsub -all -- {,} $cmd {} cmd
    return $cmd
}

# svg2can::TransformAttrToMatrix --
# 
#       Processes a SVG transform attribute to a transformation matrix.
#       Used by tkpath only.
#       
#       | a c tx |
#       | b d ty |
#       | 0 0 1  |
#       
#       linear form : {a b c d tx ty}

proc svg2can::TransformAttrToMatrix {transform} {
    variable degrees2Radians
    
    # Note order of multiplication is reversed to list order!
    set i 0

    foreach {op value} [TransformAttrToList $transform] {
	
	switch -- $op {
	    matrix {
		set m([incr i]) $value
	    }
	    rotate {
		set phi [lindex $value 0]
		set cosPhi  [expr cos($degrees2Radians*$phi)]
		set sinPhi  [expr sin($degrees2Radians*$phi)]
		set msinPhi [expr {-1.0*$sinPhi}]
		if {[llength $value] == 1} {
		    set m([incr i])  \
		      [list $cosPhi $sinPhi $msinPhi $cosPhi 0 0]
		} else {
		    set cx [lindex $value 1]
		    set cy [lindex $value 2]
		    set m([incr i]) [list $cosPhi $sinPhi $msinPhi $cosPhi \
		      [expr {-$cx*$cosPhi + $cy*$sinPhi + $cx}] \
		      [expr {-$cx*$sinPhi - $cy*$cosPhi + $cy}]]
		}
	    }
	    scale {
		set sx [lindex $value 0]
		if {[llength $value] > 1} {
		    set sy [lindex $value 1]
		} else {
		    set sy $sx
		}
		set m([incr i]) [list $sx 0 0 $sy 0 0]
	    }
	    skewx {
		set tana [expr {tan($degrees2Radians*[lindex $value 0])}]
		set m([incr i]) [list 1 0 $tana 1 0 0]
	    }
	    skewy {
		set tana [expr {tan($degrees2Radians*[lindex $value 0])}]
		set m([incr i]) [list 1 $tana 0 1 0 0]
	    }
	    translate {
		set tx [lindex $value 0]
		if {[llength $value] > 1} {
		    set ty [lindex $value 1]
		} else {
		    set ty 0
		}
		set m([incr i]) [list 1 0 0 1 $tx $ty]
	    }
	}
    }
    if {$i == 1} {
	
	# This is the most common case.
	foreach {a b c d tx ty} $m(1) { break }
	set matrix [list [list $a $c] [list $b $d] [list $tx $ty]]
    } else {
	foreach m [lsort -integer -decreasing [array names m]] {
	    
	}
    }
    return $matrix
}

proc svg2can::MMult {m1 m2} {
    foreach {a1 b1 c1 d1 tx1 ty1} $m1 { break }
    foreach {a2 b2 c2 d2 tx2 ty2} $m2 { break }
    return [list \
      [expr {$a1*$a2  + $c1*$b2}]        \
      [expr {$b1*$a2  + $d1*$b2}]        \
      [expr {$a1*$c2  + $c1*$d2}]        \
      [expr {$b1*$c2  + $d1*$d2}]        \
      [expr {$a1*$tx2 + $c1*$ty2 + $tx}] \
      [expr {$b1*$tx2 + $d1*$ty2 + $ty}]]
}

# svg2can::CreateTransformCanvasCmdList --
# 
#       Takes a parsed list of transform attributes and turns them
#       into a sequence of canvas commands.
#       Standard items only which miss a matrix option.

proc svg2can::CreateTransformCanvasCmdList {tag transformL} {
    
    set cmdList {}
    foreach {key argument} $transformL {
	
	switch -- $key {
	    translate {
		lappend cmdList [concat [list move $tag] $argument]
	    }
	    scale {
		
		switch -- [llength $argument] {
		    1 {
			set xScale $argument
			set yScale $argument
		    }
		    2 {
			foreach {xScale yScale} $argument break
		    }
		    default {
			set xScale 1.0
			set yScale 1.0
		    }
		}
		lappend cmdList [list scale $tag 0 0 $xScale $yScale]
	    }
	}
    }
    return $cmdList
}

proc svg2can::AddAnyTransformCmds {cmdList transformL} {
    variable tmptag
    
    if {[llength $transformL]} {
	set cmdList [concat $cmdList \
	  [CreateTransformCanvasCmdList $tmptag $transformL]]
	lappend cmdList [list dtag $tmptag]
    }
    return $cmdList
}

proc svg2can::MapNoneToEmpty {val} {

    if {[string equal $val "none"]} {
	return
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

    set xml([incr i]) {<path d="M 125 75 A 100 50 0 0 0 225 125" \
      style='stroke: blue; stroke-width: 2.0;'/>}
    set xml([incr i]) {<path d="M 125 75 A 100 50 0 0 1 225 125" \
      style='stroke: red; stroke-width: 2.0;'/>}
    set xml([incr i]) {<path d="M 125 75 A 100 50 0 1 0 225 125" \
      style='stroke: green; stroke-width: 2.0;'/>}
    set xml([incr i]) {<path d="M 125 75 A 100 50 0 1 1 225 125" \
      style='stroke: gray50; stroke-width: 2.0;'/>}

    # g
    set xml([incr i]) {<g fill="none" stroke="red" stroke-width="3" > \
      <line x1="300" y1="10" x2="350" y2="10" /> \
      <line x1="300" y1="10" x2="300" y2="50" /> \
      </g>}
    
    # translate
    set xml([incr i]) {<rect id="t0012" x="10" y="10" width="20" height="20" \
      style="stroke: yellow; fill: none; stroke-width: 2.0;" \
      transform="translate(200,200)"/>}
    set xml([incr i]) {<rect id="t0013" x="10" y="10" width="20" height="20" \
      style="stroke: yellow; fill: none; stroke-width: 2.0;" transform="scale(4)"/>}
    set xml([incr i]) {<circle id="t0013" cx="10" cy="10" r="20" \
      style="stroke: yellow; fill: none; stroke-width: 2.0;"\
      transform="translate(200,300)"/>}
    set xml([incr i]) {<text x='10.0' y='40.0' transform="translate(200,300)" \
      style='font-family: Helvetica; font-size: 24; \
      fill: #000000;'>Translated Text</text>}
    
    foreach i [lsort -integer [array names xml]] {
	set xmllist [tinydom::documentElement [tinydom::parse $xml($i)]]
	set cmdList [svg2can::parseelement $xmllist]
	foreach c $cmdList {
	    puts $c
	    eval .t.c $c
	}
    }
    
}
    
#-------------------------------------------------------------------------------
