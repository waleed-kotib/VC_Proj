#  util.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides small utility functions.
#      
#  Copyright (c) 2006  Mats Bengtsson
#  
# $Id: util.tcl,v 1.3 2006-05-24 08:38:15 matben Exp $

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
    set lans {}
    foreach l $list1 {
	if {[lsearch $list2 $l] >= 0} {
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
    set idx [lsearch $listValue $elem]
    if {$idx >= 0} {
	uplevel [list set $listName [lreplace $listValue $idx $idx]]
    }
    return
}
