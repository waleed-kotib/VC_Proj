#  util.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides small utility functions.
#      
#  Copyright (c) 2006  Mats Bengtsson
# 
# This file is distributed under BSD style license.
#  
# $Id: util.tcl,v 1.6 2007-09-06 13:20:47 matben Exp $

package provide jlib::util 0.1

namespace eval jlib::util {}

# Standin for a 8.5 feature.
if {![llength [info commands lassign]]} {
    proc lassign {vals args} {uplevel 1 [list foreach $args $vals break] }
}

# jlib::util::lintersect --
# 
#       Picks out the common list elements from two lists, their intersection.

proc jlib::util::lintersect {list1 list2} {
    set lans [list]
    foreach l $list1 {
	if {[lsearch -exact $list2 $l] >= 0} {
	    lappend lans $l
	}
    }
    return $lans
}

# jlib::util::lprune --
# 
#       Removes element from list, silently.

proc jlib::util::lprune {listName elem} {
    upvar $listName listValue    
    set idx [lsearch -exact $listValue $elem]
    if {$idx >= 0} {
	uplevel [list set $listName [lreplace $listValue $idx $idx]]
    }
    return
}

# jlib::util::from --
# 
#       The from command plucks an option value from a list of options and their 
#       values. If it is found, it and its value are removed from the list, 
#       and the value is returned. 

proc jlib::util::from {argvName option {defvalue ""}} {
    upvar $argvName argv

    set ioption [lsearch -exact $argv $option]
    if {$ioption == -1} {
	return $defvalue
    } else {
	set ivalue [expr {$ioption + 1}]
	set value [lindex $argv $ivalue]
	set argv [lreplace $argv $ioption $ivalue] 
	return $value
    }
}
