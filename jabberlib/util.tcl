#  util.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides small utility functions.
#      
#  Copyright (c) 2006  Mats Bengtsson
#  
# $Id: util.tcl,v 1.1 2006-03-09 10:40:32 matben Exp $

package provide jlib::util 0.1

namespace eval jlib::util { }

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

