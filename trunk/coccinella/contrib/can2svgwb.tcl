#  can2svgwb.tcl ---
#  
#      This file provides translation from canvas commands to ...
#      
#  Copyright (c) 2004  Mats Bengtsson
#
# $Id: can2svgwb.tcl,v 1.1 2004-03-13 15:18:32 matben Exp $

package require can2svg

package provide can2svgwb 1.0

namespace eval can2svgwb {


}


proc can2svgwb::can2svgwb {cmd} {
    
    set instr [lindex $cmd 0]
    set xmllist {}
    
    switch -- $instr {
	create {
	    set xmllist [can2svg::svgasxmllist $cmd]
	}
	lower - move - raise - scale {
	    set xmllist [list [parse${instr} $cmd]]
	}
	coords {
	    # ?
	}
	import {
	    
	}
    }
    return $xmllist
}

proc can2svgwb::parselower {cmd} {
    
    set attrlist [list id [lindex $cmd 1]]
    if {[llength $cmd] == 2} {
	lappend attrlist belowid [lindex $cmd 1]
    }
    return [wrapper::createtag lower -attrlist $attrlist
}

proc can2svgwb::parsemove {cmd} {
    
    return [wrapper::createtag transform -attrlist \
      [list id [lindex $cmd 1] translate([lindex $cmd 2],[lindex $cmd 3])]]
}

proc can2svgwb::parseraise {cmd} {
    
    set attrlist [list id [lindex $cmd 1]]
    if {[llength $cmd] == 2} {
	lappend attrlist aboveid [lindex $cmd 1]
    }
    return [wrapper::createtag raise -attrlist $attrlist
}

proc can2svgwb::parsescale {cmd} {

    
}

#-------------------------------------------------------------------------------
