#  svgwb2can.tcl ---
#  
#      This file provides translation from canvas commands to ...
#      
#  Copyright (c) 2004  Mats Bengtsson
#
# $Id: svgwb2can.tcl,v 1.2 2004-03-18 14:11:18 matben Exp $

package require svg2can

package provide svgwb2can 1.0

namespace eval svgwb2can {


}

proc svgwb2can::parsesvgdocument {xmllist args} {

    set ans {}
    foreach c [svg2can::getchildren $xmllist] {
	set ans [concat $ans [parseelement $c {}]]
    }
    return $ans
}

proc svgwb2can::parseelement {xmllist args} {

    set tag [svg2can::gettag $xmllist]
    set cmdList {}
    
    switch -- $tag {
	configure - dchars - insert - lower - raise {
	    set cmdList [list [parse${tag} $xmllist]]
	}
	transform {
	    set cmdList [parsetransform $xmllist]
	}
	default {
	    set cmdList [svg2can::parseelement $xmllist {}]
	}
    }
    return $cmdList
}

proc svgwb2can::parseconfigure {xmllist args} {
    
    array set attrArr [svg2can::getattr $xmllist]
    # How on earth to get the item type???????????????????????????
    set opts [svg2can::StyleToOpts line $xmllist]
    return [concat [list itemconfigure $attrArr(id)] $opts]
}

proc svgwb2can::parsedchars {xmllist args} {
    
    array set attrArr [svg2can::getattr $xmllist]
    set cmd [list dchars $attrArr(id) $attrArr(first)]
    if {[info exists attrArr(last)]} {
	lappend cmd $attrArr(last)
    }
    return $cmd
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

#-------------------------------------------------------------------------------
