#  svgwb2can.tcl ---
#  
#      This file provides translation from canvas commands to ...
#      
#  Copyright (c) 2004  Mats Bengtsson
#
# $Id: svgwb2can.tcl,v 1.4 2004-03-27 15:20:37 matben Exp $

package require svg2can

package provide svgwb2can 1.0

namespace eval svgwb2can {


}

# Due to the very unfortunate mix up of -fill & -outline in Tk which are used
# differently for different items we need to supply the widget path if
# doing the configure command.

# svgwb2can::parsesvgdocument --
#
#       Makes a list of canvas commands, widgetPath removed, from the child
#       elements of xmllist.
#       
# Arguments:
#       xmllist     a list of {tag attrlist isempty cdata {child1 child2 ...}}
#       args    -canvas     widgetPath
#               or any other option valid for svg2can.
#       
# Results:
#       list of canvas commands without prepending widget path.

proc svgwb2can::parsesvgdocument {xmllist args} {

    set ans {}
    foreach c [svg2can::getchildren $xmllist] {
	set ans [concat $ans [eval {parseelement $c} $args]]
    }
    return $ans
}

proc svgwb2can::parseelement {xmllist args} {

    set tag [svg2can::gettag $xmllist]
    set cmdList {}
    
    switch -- $tag {
	configure {
	    set cmdList [eval {parseconfigure $xmllist} $args]
	}
	dchars - delete - insert - lower - raise {
	    set cmdList [list [eval {parse${tag} $xmllist} $args]]
	}
	transform {
	    set cmdList [parsetransform $xmllist]
	}
	default {
	    set cmdList [eval {svg2can::parseelement $xmllist} $args]
	}
    }
    return $cmdList
}

proc svgwb2can::parseconfigure {xmllist args} {
    
    array set argsArr $args
    set attr [svg2can::getattr $xmllist]
    array set attrArr $attr
    set id $attrArr(id)
    set styleArgs {-setdefaults 0}
    # How on earth to get the item type???????????????????????????
    if {[info exists argsArr(-canvas)]} {
	set type [$argsArr(-canvas) type $id]
	if {[string equal $type "text"]} {
	    lappend styleArgs -origfont \
	      [$argsArr(-canvas) itemcget $id -font]
	}
    } else {
	return {}
    }
    
    # We must distinguish between the presentation attributes (style) and
    # coordinate specs.
    set presAttr {}
    set cooAttr {}
    set x 0
    set y 0
    
    foreach {key value} $attr {
	
	switch -- $key {
	    cx - cy - d - height - points - r - rx - ry - width - \
	      x - y - x1 - x2 - y1 - y2 {
		set $key $value
		lappend cooAttr $key $value
	    }
	    id {
		# skip
	    }
	    default {
		lappend presAttr $key $value
	    }
	}
    }
    puts "presAttr=$presAttr"
    puts "cooAttr=$cooAttr"
    set cmdList {}
    if {[llength $presAttr]} {
	set opts [eval {svg2can::StyleToOpts $type $presAttr} $styleArgs]
	lappend cmdList [concat itemconfigure $id $opts]
    }
    
    # If path (d attribute) or polygon (points) just replace these attributes.
    # Else we need to first get the items actual coords, and then overwrite
    if {[info exists d]} {
	
	# For a path element we need to compare with the original canvas item
	# to see if we they can be made to match.
	# If not, need to replace the item completely with one or more
	# new items.
	# This would have been much simpler if there was a path canvas item...

	# Assume for the moment line or polygon...
	set pxmlList [can2svg::MakeXMLList path -attrlist [list id $id d $d]]
	set pcmdList [svg2can::parsepath $pxmllist {}]
	set cmd [lindex $pcmdList 0]
	set idx [lsearch -glob $cmd {-[a-z]*}]
	if {$idx < 1} {
	    set idx end
	}
	set coo [lrange $cmd 2 [expr $idx - 1]]
	lappend cmdList [list coords $id $coo]
    } elseif {[info exists points]} {
	set coo [svg2can::PointsToList $points]
	lappend cmdList [concat coords $id $coo]
    } elseif {$type == "image"} {
	lappend cmdList [concat coords $id $x $y]
    } elseif {[llength $cooAttr]} {
	
	# Original coords.
	set coo [$argsArr(-canvas) coords $id]
	#puts "coo=$coo"
	set opts [GetOptsList $argsArr(-canvas) $id]
	array set attrArr [can2svg::CoordsToAttr $type $coo $opts svgElement]
	#puts "[array get attrArr]"
	
	# Overwrite using new attributes.
	array set attrArr $cooAttr
	#puts "[array get attrArr]"

	# And then back to Tk again...
	set coo [svg2can::AttrToCoords $svgElement [array get attrArr]]
	lappend cmdList [concat coords $id $coo]
    }
    puts "cmdList=$cmdList"
    return $cmdList
}

proc svgwb2can::parsedchars {xmllist args} {
    
    array set attrArr [svg2can::getattr $xmllist]
    set cmd [list dchars $attrArr(id) $attrArr(first)]
    if {[info exists attrArr(last)]} {
	lappend cmd $attrArr(last)
    }
    return $cmd
}

proc svgwb2can::parsedelete {xmllist args} {
    
    array set attrArr [svg2can::getattr $xmllist]
    return [list delete $attrArr(id)]
}

proc svgwb2can::parseinsert {xmllist args} {
    
    array set attrArr [svg2can::getattr $xmllist]
    set cmd [list insert $attrArr(id) $attrArr(before) \
      [svg2can::getcdata $xmllist]]
    return $cmd
}

proc svgwb2can::parselower {xmllist args} {
    
    array set attrArr [svg2can::getattr $xmllist]
    set cmd [list lower $attrArr(id)]
    if {[info exists attrArr(belowid)]} {
	lappend cmd $attrArr(belowid)
    }
    return $cmd
}

proc svgwb2can::parseraise {xmllist args} {
    
    array set attrArr [svg2can::getattr $xmllist]
    set cmd [list raise $attrArr(id)]
    if {[info exists attrArr(aboveid)]} {
	lappend cmd $attrArr(aboveid)
    }
    return $cmd
}

proc svgwb2can::parsetransform {xmllist args} {
    
    array set attrArr [svg2can::getattr $xmllist]
    set transList [svg2can::TransformAttrToList $attrArr(transform)]
    return [svg2can::CreateTransformCanvasCmdList $attrArr(id) $transList]
}

proc svgwb2can::GetOptsList {w id} {
    
    set opts {}
    foreach spec [$w itemconfigure $id] {
	foreach {name x y def val} $spec break
	if {$def != $val} {
	    lappend opts $name $val
	}
    }
    return $opts
}

#-------------------------------------------------------------------------------
