#  can2svg.tcl ---
#  
#      This file provides translation from canvas commands to XML/SVG format.
#      
#  Copyright (c) 2002  Mats Bengtsson
#
# $Id: can2svg.tcl,v 1.1.1.1 2002-12-08 10:54:10 matben Exp $
# 
# ########################### USAGE ############################################
#
#   NAME
#      can2svg - translate canvas command to SVG.
#      
#   SYNOPSIS
#      can2svg canvasCmd ?options?
#           canvasCmd is everything except the widget path name.
#           
#      canvas2file widgetPath fileName ?options?
#           options:   -height
#                      -width
#      
#
# ########################### CHANGES ##########################################
#
#   0.1      first release
#   0.2      URI encoded image file path, 
#
# ########################### TODO #############################################
# 
#   handle units (m->mm etc.) 
#   better support for stipple patterns
#   how to handle tk editing? DOM?
#   
#   ...

# We need URN encoding for the file path in images. From my whiteboard code.

package require uriencode

package provide can2svg 0.1

namespace eval ::can2svg:: {

    namespace export can2svg canvas2file
    
    variable formatArrowMarker
    variable formatArrowMarkerLast
    
    # The key into this array is 'arrowMarkerDef_$col_$a_$b_$c', where
    # col is color, and a, b, c are the arrow's shape.
    variable defsArrowMarkerArr

    # Similarly for stipple patterns.
    variable defsStipplePatternArr

    # This shouldn't be hardcoded!
    variable defaultFont {Helvetica 12}

    variable anglesToRadians [expr 3.14159265359/180.0]
    variable grayStipples {gray75 gray50 gray25 gray12}
        
    # Make 4x4 squares. Perhaps could be improved.
    variable stippleDataArr
    
    set stippleDataArr(gray75)  \
      {M 0 0 h3 M 0 1 h1 m 1 0 h2 M 0 2 h2 m 1 0 h1 M 0 3 h3}
    set stippleDataArr(gray50)  \
      {M 0 0 h1 m 1 0 h1 M 1 1 h1 m 1 0 h1 \
      M 0 2 h1 m 1 0 h1 M 1 3 h1 m 1 0 h1}
    set stippleDataArr(gray25)  \
      {M 0 0 h1 M 2 1 h1 M 1 2 h1 M 3 3 h1}
    set stippleDataArr(gray12) {M 0 0 h1 M 2 2 h1}
    
}

# ::can2svg::can2svg --
#
#       Make xml out of a canvas command, widgetPath removed.
#       
# Arguments:
#       cmd         canvas command without prepending widget path.
#       args    -usetags    0|all|first|last
#       
# Results:
#   xml data

proc ::can2svg::can2svg {cmd args} {

    variable defsArrowMarkerArr
    variable defsStipplePatternArr
    variable anglesToRadians
    variable defaultFont
    variable grayStipples
    
    set nonum_ {[^0-9]}
    set wsp_ {[ ]+}
    set xml ""
    
    array set argsArr {-usetags all}
    array set argsArr $args
    
    switch -- [lindex $cmd 0] {
	
	create {
	    set type [lindex $cmd 1]
	    set rest [lrange $cmd 2 end]
	    regexp -indices -- "-${nonum_}" $rest ind
	    set ind1 [lindex $ind 0]
	    set coo [string trim [string range $rest 0 [expr $ind1 - 1]]]
	    set opts [string range $rest $ind1 end]
	    array set optArr $opts
	    
	    # Figure out if we've got a spline.
	    set haveSpline 0
	    if {[info exists optArr(-smooth)] && ($optArr(-smooth) != "0") &&  \
	      [info exists optArr(-splinesteps)] && ($optArr(-splinesteps) > 2)} {
		set haveSpline 1
	    }
	    if {[info exists optArr(-fill)]} {
		set fillValue $optArr(-fill)
		if {![regexp {#[0-9]+} $fillValue]} {
		    set fillValue [FormatColorName $fillValue]
		}
	    } else {
		set fillValue black
	    }
	    if {($argsArr(-usetags) != "0") && [info exists optArr(-tags)]} {
		switch -- $argsArr(-usetags) {
		    all {			
			set idAttr [list "id" $optArr(-tags)]
		    }
		    first {
			set idAttr [list "id" [lindex $optArr(-tags) 0]]
		    }
		    last {
			set idAttr [list "id" [lindex $optArr(-tags) end]]
		    }
		}
	    } else {
		set idAttr ""
	    }
		
	    # If we need a marker (arrow head) need to make that first.
	    if {[info exists optArr(-arrow)]} {
		if {[info exists optArr(-arrowshape)]} {
		    
		    # Make a key of the arrowshape list into the array.
		    regsub -all -- $wsp_ $optArr(-arrowshape) _ shapeKey
		    set arrowKey ${fillValue}_${shapeKey}
		    set arrowShape $optArr(-arrowshape)
		} else {
		    set arrowKey ${fillValue}
		    set arrowShape {8 10 3}
		}
		if {![info exists defsArrowMarkerArr($arrowKey)]} {
		    set defsArrowMarkerArr($arrowKey)  \
		      [eval {MakeArrowMarker} $arrowShape {$fillValue}]
		    append xml $defsArrowMarkerArr($arrowKey)
		    append xml "\n\t"
		}
	    }
	    
	    # If we need a stipple bitmap, need to make that first. Limited!!!
	    # Only: gray12, gray25, gray50, gray75
	    foreach key {-stipple -outlinestipple} {
		if {[info exists optArr($key)] &&  \
		  ([lsearch $grayStipples $optArr($key)] >= 0)} {
		    set stipple $optArr($key)
		    if {![info exists defsStipplePatternArr($stipple)]} {
			set defsStipplePatternArr($stipple)  \
			  [MakeGrayStippleDef $stipple]
		    }
		    append xml $defsStipplePatternArr($stipple)
		    append xml "\n\t"
		}
	    }
	    	    
	    switch -- $type {
		
		arc {
		    
		    # Had to do it the hard way! (?)
		    # "Wrong" coordinate system :-(
		    set elem "path"
		    set style [MakeStyle $type $opts]
		    foreach {x1 y1 x2 y2} $coo {}
		    set cx [expr ($x1 + $x2)/2.0]
		    set cy [expr ($y1 + $y2)/2.0]
		    set rx [expr abs($x1 - $x2)/2.0]
		    set ry [expr abs($y1 - $y2)/2.0]
		    set rmin [expr $rx > $ry ? $ry : $rx]
		    
		    # This approximation gives a maximum half pixel error.
		    set deltaPhi [expr 2.0/sqrt($rmin)]
		    set extent [expr $anglesToRadians * $optArr(-extent)]
		    set start [expr $anglesToRadians * $optArr(-start)]
		    set nsteps [expr int(abs($extent)/$deltaPhi) + 2]
		    set delta [expr $extent/$nsteps]
		    set data [format "M %.1f %.1f L"   \
		      [expr $cx + $rx*cos($start)] [expr $cy - $ry*sin($start)]]
		    for {set i 0} {$i <= $nsteps} {incr i} {
			set phi [expr $start + $i * $delta]
			append data [format " %.1f %.1f"  \
			  [expr $cx + $rx*cos($phi)] [expr $cy - $ry*sin($phi)]]
		    }
		    if {[info exists optArr(-style)]} {
			switch -- $optArr(-style) {
			    chord {
				append data " Z"
			    }
			    pieslice {
				append data [format " %.1f %.1f Z" $cx $cy]
			    }
			}
		    } else {
			
			# Pieslice is the default.
			append data [format " %.1f %.1f Z" $cx $cy]
		    }
		    set attr [list "d" $data "style" $style]
		    if {[string length $idAttr] > 0} {
			set attr [concat $attr $idAttr]
		    }
		    set xmlList [MakeXMLList $elem -attrlist $attr]
		}
		image - bitmap {
		    set elem "image"
		    set attr [MakeImageAttr $coo $opts]
		    if {[string length $idAttr] > 0} {
			set attr [concat $attr $idAttr]
		    }
		    set xmlList [MakeXMLList $elem -attrlist $attr]
		}
		line {
		    if {$haveSpline} {
			set elem "path"
			set style [MakeStyle $type $opts]
			set data "M [lrange $coo 0 1] Q"
			set i 4
			foreach {x y} [lrange $coo 2 end-4] {
			    set x0 [expr ($x + [lindex $coo $i])/2.0]
			    incr i
			    set y0 [expr ($y + [lindex $coo $i])/2.0]
			    incr i
			    append data " $x $y $x0 $y0"			    
			}
			append data " [lrange $coo end-3 end]"
			set attr [list "d" $data "style" $style]
		    } else {
			set elem "polyline"
			set style [MakeStyle $type $opts]
			set attr [list "points" $coo "style" $style]
		    }
		    if {[string length $idAttr] > 0} {
			set attr [concat $attr $idAttr]
		    }
		    set xmlList [MakeXMLList $elem -attrlist $attr]
		}
		oval {
		    foreach {x y w h} [NormalizeRectCoords $coo] {}
		    if {[expr $w == $h]} {
			set elem "circle"
			set attr [list  \
			  "cx" [expr $x + $w/2.0]  \
			  "cy" [expr $y + $h/2.0]  \
			  "r"  [expr $w/2.0]]
		    } else {
			set elem "ellipse"
			set attr [list  \
			  "cx" [expr $x + $w/2.0]  \
			  "cy" [expr $y + $h/2.0]  \
			  "rx" [expr $w/2.0]       \
			  "ry" [expr $h/2.0]]
		    }
		    set style [MakeStyle $type $opts]
		    lappend attr "style" $style
		    if {[string length $idAttr] > 0} {
			set attr [concat $attr $idAttr]
		    }
		    set xmlList [MakeXMLList $elem -attrlist $attr]
		}
		polygon {
		    if {$haveSpline} {
			set elem "path"
			set style [MakeStyle $type $opts]

			# Translating a closed polygon into a qubic bezier
			# path is a little bit tricky.
			set x0 [expr ([lindex $coo end-1] + [lindex $coo 0])/2.0]
			set y0 [expr ([lindex $coo end] + [lindex $coo 1])/2.0]
			set data "M $x0 $y0 Q"
			set i 2
			foreach {x y} [lrange $coo 0 end-2] {
			    set x1 [expr ($x + [lindex $coo $i])/2.0]
			    incr i
			    set y1 [expr ($y + [lindex $coo $i])/2.0]
			    incr i
			    append data " $x $y $x1 $y1"			    
			}
			append data " [lrange $coo end-1 end] $x0 $y0"
			set attr [list "d" $data "style" $style]
		    } else {
			set elem "polygon"
			set style [MakeStyle $type $opts]
			set attr [list "points" $coo "style" $style]
		    }
		    if {[string length $idAttr] > 0} {
			set attr [concat $attr $idAttr]
		    }
		    set xmlList [MakeXMLList $elem -attrlist $attr]
		}
		rectangle {
		    set elem "rect"
		    set style [MakeStyle $type $opts]

		    # width and height must be non-negative!
		    foreach {x y w h} [NormalizeRectCoords $coo] {}
		    set attr [list "x" $x "y" $y "width" $w "height" $h]
		    lappend attr "style" $style
		    if {[string length $idAttr] > 0} {
			set attr [concat $attr $idAttr]
		    }
		    set xmlList [MakeXMLList $elem -attrlist $attr]		    
		}
		text {
		    set elem "text"
		    set style [MakeStyle $type $opts]
		    set nlines 1
		    if {[info exists optArr(-text)]} {
			set chdata $optArr(-text)
			set nlines [expr [regexp -all "\n" $chdata] + 1]
		    } else {
			set chdata ""
		    }
		    
		    # Figure out the coords of the first baseline.
		    set anchor center
		    if {[info exists optArr(-anchor)]} {
			set anchor $optArr(-anchor)
		    }		    		    
		    if {[info exists optArr(-font)]} {
			set theFont $optArr(-font)
		    } else {
			set theFont $defaultFont
		    }
		    set ascent [font metrics $theFont -ascent]
		    set lineSpace [font metrics $theFont -linespace]

		    foreach {xbase ybase}  \
		      [GetTextSVGCoords $coo $anchor $chdata $theFont $nlines] {}
		    		    
		    set attr [list "x" $xbase "y" $ybase]
		    lappend attr "style" $style
		    if {[string length $idAttr] > 0} {
			set attr [concat $attr $idAttr]
		    }
		    set dy 0
		    if {$nlines > 1} {
			
			# Use the 'tspan' trick here.
			set subList {}
			foreach line [split $chdata "\n"] {
			    lappend subList [MakeXMLList "tspan"  \
			      -attrlist [list "x" $xbase "dy" $dy] -chdata $line]
			    set dy $lineSpace
			}
			set xmlList [MakeXMLList $elem -attrlist $attr \
			  -subtags $subList]
		    } else {
			set xmlList [MakeXMLList $elem -attrlist $attr \
			  -chdata $chdata]
		    }
		}
	    }
	}
	move {
	    foreach {tag dx dy} [lrange $cmd 1 3] {}
	    set attr [list "transform" "translate($dx,$dy)"  \
	      "xlink:href" "#$tag"]
	    set xmlList [MakeXMLList "use" -attrlist $gattr]
	}
	scale {
	    
	}
    }
    append xml [MakeXML $xmlList]
    return $xml
}

# ::can2svg::MakeStyle --
#
#       Produce the SVG style attribute from the canvas item options.
#
# Arguments:
#       type        tk canvas widget item type
#       opts
#       
# Results:
#       The SVG style attribute as a a string.

proc ::can2svg::MakeStyle {type opts} {

    # Defaults for everything except text.
    if {![string equal $type "text"]} {
	array set styleArr {fill none stroke black}
    }
    set fillCol black
    
    foreach {key value} $opts {
	
	switch -- $key {
	    -arrow {
		set arrowValue $value
	    }
	    -arrowshape {
		set arrowShape $value
	    }
	    -capstyle {
		if {[string equal $value "projecting"]} {
		    set value "square"
		}
		if {![string equal $value "butt"]} {
		    set styleArr(stroke-linecap) $value
		}
	    }
	    -dash {
		set dashValue $value
	    }
	    -dashoffset {
		if {$value != 0} {
		    set styleArr(stroke-dashoffset) $value
		}
	    }
	    -fill {
		
		# Need to translate names to hex spec.
		if {![regexp {#[0-9]+} $value]} {
		    set value [FormatColorName $value]
		}
		set fillCol $value		
		if {[string equal $type "line"]} {
		    set styleArr(stroke) [MapEmptyToNone $value]
		} else {
		    set styleArr(fill) [MapEmptyToNone $value]
		}
	    }
	    -font {
		set styleArr(font-family) [lindex $value 0]
		if {[llength $value] > 1} {
		    set styleArr(font-size) [lindex $value 1]
		}
		if {[llength $value] > 2} {
		    set tkstyle [lindex $value 2]
		    switch -- $tkstyle {
			bold {
			    set styleArr(font-weight) $tkstyle
			}
			italic {
			    set styleArr(font-style) $tkstyle
			}
			underline {
			    set styleArr(text-decoration) underline
			}
			overstrike {
			    set styleArr(text-decoration) overline
			}
		    }
		}		
		
	    }
	    -joinstyle {
		set styleArr(stroke-linejoin) $value		
	    }
	    -outline {
		set styleArr(stroke) [MapEmptyToNone $value]
	    }
	    -outlinestipple {
		set outlineStippleValue $value
	    }
	    -stipple {
		set stippleValue $value
	    }
	    -width {
		set styleArr(stroke-width) $value
	    }
	}
    }
    
    # If any arrow specify its marker def url key.
    if {[info exists arrowValue]} {
	if {[info exists arrowShape]} {	
	    foreach {a b c} $arrowShape {}
	    set arrowIdKey "arrowMarkerDef_${fillCol}_${a}_${b}_${c}"
	    set arrowIdKeyLast "arrowMarkerLastDef_${fillCol}_${a}_${b}_${c}"
	} else {
	    set arrowIdKey "arrowMarkerDef_${fillCol}"
	}
	switch -- $arrowValue {
	    first {
		set styleArr(marker-start) "url(#$arrowIdKey)"
	    }
	    last {
		set styleArr(marker-end) "url(#$arrowIdKeyLast)"
	    }
	    both {
		set styleArr(marker-start) "url(#$arrowIdKey)"
		set styleArr(marker-end) "url(#$arrowIdKeyLast)"
	    }
	}
    }
    
    if {[info exists stippleValue]} {
	
	# Overwrite any existing.
	set styleArr(fill) "url(#tile$stippleValue)"
    }
    if {[info exists outlineStippleValue]} {
	
	# Overwrite any existing.
	set styleArr(stroke) "url(#tile$stippleValue)"
    }
    
    # Transform dash value.
    if {[info exists dashValue]} {
		
	# Two different syntax here.		
	if {[regexp {[\.,\-_ ]} $dashValue]} {
	    
	    # .=2 ,=4 -=6 space=4    times stroke width.
	    # A space enlarges the... space.
	    # Not foolproof!
	    regsub -all -- {[^ ]} $dashValue "& " dash
	    regsub -all -- "   "  $dash  "12 " dash
	    regsub -all -- "  "   $dash  "8 " dash
	    regsub -all -- " "    $dash  "4 " dash
	    regsub -all -- {\.}   $dash  "2 " dash
	    regsub -all -- {,}    $dash  "4 " dash
	    regsub -all -- {-}    $dash  "6 " dash		    
	
	    # Multiply with stroke width if > 1.
	    if {[info exists styleArr(stroke-width)] &&  \
	      ($styleArr(stroke-width) > 1)} {
		set width $styleArr(stroke-width)
		set dashOrig $dash
		set dash {}
		foreach num $dashOrig {
		    lappend dash [expr int($width * $num)]
		}
	    }
	    set styleArr(stroke-dasharray) [string trim $dash]
	} else {
	    set styleArr(stroke-dasharray) $value
	}
    }
    if {[string equal $type "polygon"]} {
	set styleArr(fill-rule) "evenodd"
    }
        
    set style ""
    foreach {key value} [array get styleArr] {
	append style "${key}: ${value}; "
    }
    return [string trim $style]
}

proc ::can2svg::FormatColorName {value} {

    if {[string length $value] == 0} {
	return $value
    }
    foreach rgb [winfo rgb . $value] {
	lappend rgbx [expr $rgb >> 8]
    }
    return [eval {format "#%02x%02x%02x"} $rgbx]
}

# ::can2svg::MakeImageAttr --
#
#       Special code is needed to make the attributes for an image item.
#       
# Arguments:
#       elem 
#       
# Results:
#   

proc ::can2svg::MakeImageAttr {coo opts} {
    
    array set optArr {-anchor nw}
    array set optArr $opts
    set theImage $optArr(-image)
    set w [image width $theImage]
    set h [image height $theImage]
    
    # We should make this an URI.
    set theFile [$theImage cget -file]
    set uri [UriFromLocalFile $theFile]
    foreach {x0 y0} $coo {}
    switch -- $optArr(-anchor) {
	nw {
	    set x $x0
	    set y $y0
	}
	n {
	    set x [expr $x0 - $w/2.0]
	    set y $y0
	}
	ne {
	    set x [expr $x0 - $w]
	    set y $y0
	}
	e {
	    set x $x0
	    set y [expr $y0 - $h/2.0]
	}
	se {
	    set x [expr $x0 - $w]
	    set y [expr $y0 - $h]
	}
	s {
	    set x [expr $x0 - $w/2.0]
	    set y [expr $y0 - $h]
	}
	sw {
	    set x $x0
	    set y [expr $y0 - $h]
	} 
	w {
	    set x $x0
	    set y [expr $y0 - $h/2.0]
	}
	center {
	    set x [expr $x0 - $w/2.0]
	    set y [expr $y0 - $h/2.0]
	}
    }
    set attrList [list "x" $x "y" $y "width" $w "height" $h  \
      "xlink:href" $uri]
    return $attrList
}

# ::can2svg::GetTextSVGCoords --
# 
#       Figure out the baseline coords of the svg text element from
#       the canvas text item.
#
# Arguments:
#       coo         {x y}
#       anchor
#       chdata      character data, newlines included.
#       
# Results:
#       raw xml data of the marker def element.

proc ::can2svg::GetTextSVGCoords {coo anchor chdata theFont nlines} {
    
    foreach {x y} $coo {}
    set ascent [font metrics $theFont -ascent]
    set lineSpace [font metrics $theFont -linespace]

    # If not anchored to the west it gets more complicated.
    if {![string match $anchor "*w*"]} {
	
	# Need to figure out the extent of the text.
	if {$nlines <= 1} {
	    set textWidth [font measure $theFont $chdata]
	} else {
	    set textWidth 0
	    foreach line [split $chdata "\n"] {
		set lineWidth [font measure $theFont $line]
		if {$lineWidth > $textWidth} {
		    set textWidth $lineWidth
		}
	    }
	}
    }
    
    switch -- $anchor {
	nw {
	    set xbase $x
	    set ybase [expr $y + $ascent]
	}
	w {
	    set xbase $x
	    set ybase [expr $y - $nlines*$lineSpace/2.0 + $ascent]
	}
	sw {
	    set xbase $x
	    set ybase [expr $y - $nlines*$lineSpace + $ascent]
	}
	s {
	    set xbase [expr $x - $textWidth/2.0]
	    set ybase [expr $y - $nlines*$lineSpace + $ascent]
	}
	se {
	    set xbase [expr $x - $textWidth]
	    set ybase [expr $y - $nlines*$lineSpace + $ascent]
	}
	e {
	    set xbase [expr $x - $textWidth]
	    set ybase [expr $y - $nlines*$lineSpace/2.0 + $ascent]
	}
	ne {
	    set xbase [expr $x - $textWidth]
	    set ybase [expr $y + $ascent]
	} 
	n {
	    set xbase [expr $x - $textWidth/2.0]
	    set ybase [expr $y + $ascent]
	}
	center {
	    set xbase [expr $x - $textWidth/2.0]
	    set ybase [expr $y - $nlines*$lineSpace/2.0 + $ascent]
	}
    }
    
    return [list $xbase $ybase]
}

# ::can2svg::MakeArrowMarker --
# 
#       Make the xml for an arrow marker def element.
#
# Arguments:
#       a           arrows length along its symmetry line
#       b           arrows total length
#       c           arrows half width
#       col         its color
#       
# Results:
#       raw xml data of the marker def elements, both start and last.

proc ::can2svg::MakeArrowMarker {a b c col} {
    
    variable formatArrowMarker
    variable formatArrowMarkerLast
    
    catch {unset formatArrowMarker}
    
    if {![info exists formatArrowMarker]} {
	
	# "M 0 c, b 0, a c, b 2*c Z" for the start marker.
	# "M 0 0, b c, 0 2*c, b-a c Z" for the last marker.
	set data "M 0 %s, %s 0, %s %s, %s %s Z"
	set style "fill: %s; stroke: %s;"
	set attr [list "d" $data "style" $style]
	set arrowList [MakeXMLList "path" -attrlist $attr]
	set markerAttr [list "id" %s "markerWidth" %s "markerHeight" %s  \
	  "refX" %s "refY" %s "orient" "auto"]
	set defElemList [MakeXMLList "defs" -subtags  \
	  [list [MakeXMLList "marker" -attrlist $markerAttr \
	  -subtags [list $arrowList] ] ] ]
	set formatArrowMarker [MakeXML $defElemList]
	
	# ...and the last arrow marker.
	set dataLast "M 0 0, %s %s, 0 %s, %s %s Z"
	set attrLast [list "d" $dataLast "style" $style]
	set arrowLastList [MakeXMLList "path" -attrlist $attrLast]
	set defElemLastList [MakeXMLList "defs" -subtags  \
	  [list [MakeXMLList "marker" -attrlist $markerAttr \
	  -subtags [list $arrowLastList] ] ] ]
	set formatArrowMarkerLast [MakeXML $defElemLastList]
    }
    set idKey "arrowMarkerDef_${col}_${a}_${b}_${c}"
    set idKeyLast "arrowMarkerLastDef_${col}_${a}_${b}_${c}"
    
    # Figure out the order of all %s substitutions.
    set markerXML [format $formatArrowMarker $idKey  \
      $b [expr 2*$c] 0 $c  \
      $c $b $a $c $b [expr 2*$c] $col $col]
    set markerLastXML [format $formatArrowMarkerLast $idKeyLast  \
      $b [expr 2*$c] $b $c \
      $b $c [expr 2*$c] [expr $b-$a] $c $col $col]
    
    return "$markerXML\n\t$markerLastXML"
}

# ::can2svg::MakeGrayStippleDef --
#
#

proc ::can2svg::MakeGrayStippleDef {stipple} {
    
    variable stippleDataArr
    
    set pathList [MakeXMLList "path" -attrlist  \
      [list "d" $stippleDataArr($stipple) "style" "stroke: black; fill: none;"]]
    set patterAttr [list "id" "tile$stipple" "x" 0 "y" 0 "width" 4 "height" 4 \
      "patternUnits" "userSpaceOnUse"]
    set defElemList [MakeXMLList "defs" -subtags  \
      [list [MakeXMLList "pattern" -attrlist $patterAttr \
      -subtags [list $pathList] ] ] ]
    
    return [MakeXML $defElemList]
}

# ::can2svg::MapEmptyToNone --
#
#
# Arguments:
#       elem 
#       
# Results:
#   

proc ::can2svg::MapEmptyToNone {val} {

    if {[string length $val] == 0} {
	return "none"
    } else {
	return $val
    }
}

# ::can2svg::NormalizeRectCoords --
#
#
# Arguments:
#       elem 
#       
# Results:
#   

proc ::can2svg::NormalizeRectCoords {coo} {
    
    foreach {x1 y1 x2 y2} $coo {}
    return [list [expr $x2 > $x1 ? $x1 : $x2]  \
      [expr $y2 > $y1 ? $y1 : $y2]  \
      [expr abs($x1-$x2)]  \
      [expr abs($y1-$y2)]]
}

# ::can2svg::makedocument --
#
#       Adds the prefix and suffix elements to make a complete XML/SVG
#       document.
#
# Arguments:
#       elem 
#       
# Results:
#   

proc ::can2svg::makedocument {width height xml} {
    
    set pre "<?xml version='1.0'?>\n\
      <!DOCTYPE svg PUBLIC \"-//W3C//DTD SVG 1.0//EN\"\
      \"http://www.w3.org/TR/2001/REC-SVG-20010904/DTD/svg10.dtd\">"
    
    set svgStart "<svg width='$width' height='$height'>"
    set svgEnd "</svg>"
    return "${pre}\n${svgStart}\n${xml}${svgEnd}"
}

# ::can2svg::canvas2file --
#
#       Takes everything on a canvas widget, translates it to XML/SVG,
#       and puts it on a file.
#       
# Arguments:
#       wcan        the canvas widget path
#       path        the file path
#       args:   -height
#               -width 
#       
# Results:
#   

proc ::can2svg::canvas2file {wcan path args} {
    
    variable defsArrowMarkerArr
    variable defsStipplePatternArr

    # Need to make a fresh start for marker def's.
    catch {unset defsArrowMarkerArr}
    catch {unset defsStipplePatternArr}

    array set argsArr  \
      [list -width [winfo width $wcan] -height [winfo height $wcan]]
    array set argsArr $args
    
    set fd [open $path w]

    set xml ""
    foreach id [$wcan find all] {
	set type [$wcan type $id]
	set opts [$wcan itemconfigure $id]
	set opcmd {}
	foreach opt $opts {
	    set op [lindex $opt 0]
	    set val [lindex $opt 4]
	    
	    # Empty val's except -fill can be stripped off.
	    if {![string equal $op "-fill"] && ([string length $val] == 0)} {
		continue
	    }
	    lappend opcmd $op $val
	}
	set co [$wcan coords $id]
	set cmd [concat "create" $type $co $opcmd]
	append xml "\t[can2svg $cmd]\n"	
    }
    puts $fd [makedocument $argsArr(-width) $argsArr(-height) $xml]
    close $fd
}

# ::can2svg::MakeXML --
#
#       Creates raw xml data from a hierarchical list of xml code.
#       This proc gets called recursively for each child.
#       It makes also internal entity replacements on character data.
#       Mixed elements aren't treated correctly generally.
#       
# Arguments:
#       xmlList     a list of xml code in the format described in the header.
#       
# Results:
#       raw xml data.

proc ::can2svg::MakeXML {xmlList} {
        
    # Extract the XML data items.
    foreach {tag attrlist isempty chdata childlist} $xmlList {}
    set rawxml "<$tag"
    foreach {attr value} $attrlist {
	append rawxml " ${attr}='${value}'"
    }
    if {$isempty} {
	append rawxml "/>"
	return $rawxml
    } else {
	append rawxml ">"
    }
    
    # Call ourselves recursively for each child element. 
    # There is an arbitrary choice here where childs are put before PCDATA.
    foreach child $childlist {
	append rawxml [MakeXML $child]
    }
    
    # Make standard entity replacements.
    if {[string length $chdata]} {
	append rawxml [XMLCrypt $chdata]
    }
    append rawxml "</$tag>"
    return $rawxml
}

# ::can2svg::MakeXMLList --
#
#       Build an element list given the tag and the args.
#
# Arguments:
#       tagname:    the name of this element.
#       args:       
#           -empty   0|1      Is this an empty tag? If $chdata 
#                             and $subtags are empty, then whether 
#                             to make the tag empty or not is decided 
#                             here. (default: 1)
#	    -attrlist {attr1 value1 attr2 value2 ..}   Vars is a list 
#                             consisting of attr/value pairs, as shown.
#	    -chdata $chdata   ChData of tag (default: "").
#	    -subtags {$subchilds $subchilds ...} is a list containing xmldata
#                             of $tagname's subtags. (default: no sub-tags)
#       
# Results:
#       a list suitable for ::can2svg::MakeXML.

proc ::can2svg::MakeXMLList {tagname args} {
        
    # Fill in the defaults.
    array set xmlarr {-isempty 1 -attrlist {} -chdata {} -subtags {}}
    
    # Override the defults with actual values.
    if {[llength $args] > 0} {
	array set xmlarr $args
    }
    if {!(($xmlarr(-chdata) == "") && ($xmlarr(-subtags) == ""))} {
	set xmlarr(-isempty) 0
    }
    
    # Build sub elements list.
    set sublist {}
    foreach child $xmlarr(-subtags) {
	lappend sublist $child
    }
    set xmlList [list $tagname $xmlarr(-attrlist) $xmlarr(-isempty)  \
      $xmlarr(-chdata) $sublist]
    return $xmlList
}

# ::can2svg::XMLCrypt --
#
#       Makes standard XML entity replacements.
#
# Arguments:
#       chdata:     character data.
#       
# Results:
#       chdata with XML standard entities replaced.

proc ::can2svg::XMLCrypt {chdata} {

    foreach from {\& < > {"} {'}}   \
      to {{\&amp;} {\&lt;} {\&gt;} {\&quot;} {\&apos;}} {
	regsub -all $from $chdata $to chdata
    }	
    return $chdata
}

# ::can2svg::UriFromLocalFile --
#
#       Not foolproof!

proc ::can2svg::UriFromLocalFile {path} {
        
    # Quote the disallowed characters according to the RFC for URN scheme.
    # ref: RFC2141 sec2.2
    return file://[uriencode::quotepath $path]
}

#-------------------------------------------------------------------------------
