#  can2svgwb.tcl ---
#  
#      This file provides translation from canvas commands to ...
#      
#  Copyright (c) 2004  Mats Bengtsson
#
# $Id: can2svgwb.tcl,v 1.2 2004-03-18 14:11:18 matben Exp $

package require can2svg

package provide can2svgwb 1.0

namespace eval can2svgwb {


}

# can2svgwb::svgasxmllist --
#
#       Make a list of xmllists out of a canvas command, widgetPath removed.
#       
# Arguments:
#       cmd         canvas command without prepending widget path.
#       args    -httpbasedir  path
#               -uritype    file|http
#               -usetags    0|all|first|last
#               -usestyleattribute 0|1
#       
# Results:
#       a list of xmllist = {tag attrlist isempty cdata {child1 child2 ...}}

proc can2svgwb::svgasxmllist {cmd args} {
    
    set instr [lindex $cmd 0]
    set xmllist {}
    
    switch -- $instr {
	create {
	    set xmllist [eval {can2svg::svgasxmllist $cmd} $args]
	}
	lower - move - raise {
	    set xmllist [list [parse${instr} $cmd]]
	}
	scale {
	    set xmllist [parsescale $cmd]
	}
	insert - dchars {
	    set xmllist [list [parse${instr} $cmd]]
	}
	itemconfigure {
	    set xmllist [list [parseconfigure $cmd]]
	}
	coords {
	    # ?
	}
	import {
	    # Assume image for the moment...
	    set xmllist [list [eval {parseimage $cmd} $args]]
	}
    }
    return $xmllist
}

proc can2svgwb::parseconfigure {cmd} {
    
    set opts [lrange $cmd 2 end]
    # How on earth to get the item type???????????????????????????
    set attrlist [can2svg::MakeStyleList line $opts]
    lappend attrlist id [lindex $cmd 1]
    return [wrapper::createtag configure -attrlist $attrlist]
}

proc can2svgwb::parseimage {cmd args} {

    set imcmd [concat [list create image] [lrange $cmd 1 end]]
    set xmllist [eval {can2svg::svgasxmllist $imcmd} $args]

}

proc can2svgwb::parsedchars {cmd} {

    set attrlist [list id [lindex $cmd 1] first [lindex $cmd 2]]
    if {[llength $cmd] == 4} {
	lappend attrlist last [lindex $cmd 3]
    }
    return [wrapper::createtag dchars -attrlist $attrlist]
}

proc can2svgwb::parseinsert {cmd} {

    foreach {id ind str} [lrange $cmd 1 3] break
    return [wrapper::createtag insert -attrlist \
      [list id $id before $ind] -chdata $str]
}

proc can2svgwb::parselower {cmd} {
    
    set attrlist [list id [lindex $cmd 1]]
    if {[llength $cmd] == 2} {
	lappend attrlist belowid [lindex $cmd 1]
    }
    return [wrapper::createtag lower -attrlist $attrlist]
}

proc can2svgwb::parsemove {cmd} {
    
    return [wrapper::createtag transform -attrlist \
      [list id [lindex $cmd 1] \
      transform translate([lindex $cmd 2],[lindex $cmd 3])]]
}

proc can2svgwb::parseraise {cmd} {
    
    set attrlist [list id [lindex $cmd 1]]
    if {[llength $cmd] == 2} {
	lappend attrlist aboveid [lindex $cmd 1]
    }
    return [wrapper::createtag raise -attrlist $attrlist]
}

proc can2svgwb::parsescale {cmd} {

    set id [lindex $cmd 1]
    set attrlist [list id $id]
    foreach {xOrig yOrig xScale yScale} [lrange $cmd 2 5] break
    if {$xScale == $yScale} {
	lappend attrlist transform scale($xScale)
    } else {
	lappend attrlist transform scale($xScale,$yScale)
    }
    if {($xOrig = 0.0) && ($yOrig = 0.0)} {
	set xmllist [list [wrapper::createtag transform -attrlist $attrlist]]
    } else {
	set xml1 [parsemove [list move $id [expr -1*$xOrig] [expr -1*$yOrig]]]
	set xml2 [list [wrapper::createtag transform -attrlist $attrlist]]
	set xml3 [parsemove [list move $id $xOrig $yOrig]]
	set xmllist [concat $xml1 $xml2 $xml3]
    }
    return $xmllist
}

#-------------------------------------------------------------------------------
