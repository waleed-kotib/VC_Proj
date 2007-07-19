#  utils.tcl ---
#  
#      This file is part of The Coccinella application. We collect some handy 
#      small utility procedures here.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
#  This file is distributed under BSD style license.
#  
# $Id: utils.tcl,v 1.7 2007-07-19 06:28:11 matben Exp $

package provide utils 1.0
    
# InvertArray ---
#
#    Inverts an array so that ...
#    No spaces allowed; no error checking made that the inverse is unique.

proc InvertArray {arrName invArrName} {
    
    # Pretty tricky to make it work. Perhaps the new array should be unset?
    upvar $arrName locArr
    upvar $invArrName locInvArr
    foreach name [array names locArr] {
	set locInvArr($locArr($name)) $name
    }
}

# max, min ---
#
#    Finds max and min of numerical values. From the WikiWiki page.

proc max {args} {
    lindex [lsort -real $args] end
}

proc min {args} {
    lindex [lsort -real $args] 0
}

# lprune --
# 
#       Removes element from list, silently.

proc lprune {listName elem} {
    upvar $listName listValue
    set idx [lsearch $listValue $elem]
    if {$idx >= 0} {
	uplevel [list set $listName [lreplace $listValue $idx $idx]]
    }
    return
}

# lrevert --
# 
#       Revert the order of the list elements.

proc lrevert {args} {
    set tmp {}
    set args [lindex $args 0]
    for {set i [expr [llength $args] - 1]} {$i >= 0} {incr i -1} {
	lappend tmp [lindex $args $i]
    }
    return $tmp
}

# listintersect --
# 
#       Intersections of two lists.

proc listintersect {alist blist} {
    set tmp {}
    foreach a $alist {
	if {[lsearch $blist $a] >= 0} {
	    lappend tmp $a
	}
    }
    return $tmp
}

# listintersectnonempty --
# 
#       Is intersection of two lists non empty.

proc listintersectnonempty {alist blist} {
    foreach a $alist {
	if {[lsearch $blist $a] >= 0} {
	    return 1
	}
    }
    return 0
}

# lsearchsublists --
# 
#       Search sublists instead. Very incomplete!
#       Note: returns empty if non found.

proc lsearchsublists {args} {
    
    if {[llength $args] < 2} {
	return -code error "Usage: lsearchsublists ?options? list pattern"
    }
    set pattern [lindex $args end]
    set list    [lindex $args end-1]
    set options [lrange $args 0 end-2]
    
    set idx0 0
    set idx1 -1
    foreach elem $list {
	set idx1 [eval [concat lsearch $options [list $elem $pattern]]]
	if {$idx1 >= 0} {
	    break
	} else {
	    incr idx0
	}
    }
    if {$idx1 < 0} {
	return
    } else {
	return [list $idx0 $idx1]
    }
}

# @@@ TODO: advanced list logic
# 
# type = {{user | wb} & available & junk}
# compare with an arbitrary list where at least one of the element
# must fulfill the logic implied by 'type', say {user unavailable} (=0)

# fromoptionlist --
# 
#       This command plucks an option value from a list of options and their 
#       values. listName must be the name of a variable containing such a list; 
#       name is the name of the specific option. It looks for option in the 
#       option list. If it is found, it and its value are removed from the 
#       list, and the value is returned. If option doesn't appear in the list,
#       then the value is returned. 

proc fromoptionlist {listName name {value ""}} {
    upvar $listName listValue
   
    if {[set idx [lsearch $listValue $name]] >= 0} {
	set idx2 [expr {$idx+1}]
	set value [lindex $listValue $idx2]
	uplevel set $listName [list [lreplace $listValue $idx $idx2]]
    }
    return $value
}

# ESCglobs --
#
#	array get and array unset accepts glob characters. These need to be
#	escaped if they occur as part of a variable.

proc ESCglobs {s} {
    return [string map {* \\* ? \\? [ \\[ ] \\] \\ \\\\} $s]
}

proc arraysequal {arrName1 arrName2} {
    upvar 1 $arrName1 arr1 $arrName2 arr2
    
    if {![array exists arr1]} {
	return -code error "$arrName1 is not an array"
    }
    if {![array exists arr2]} {
	return -code error "$arrName2 is not an array"
    } 
    if {[array size arr1] != [array size arr2]} {
	return 0
    }
    if {[array size arr1] == 0} {
	return 1
    }
    foreach {key value} [array get arr1] {
	if {![info exists arr2($key)]} {
	    return 0
	}
	if {![string equal $arr1($key) $arr2($key)]} {
	    return 0
	}
    }
    return 1
}

# arraysequalnames --
# 
#       Checked named array indexes only.

proc arraysequalnames {arrName1 arrName2 names} {
    upvar 1 $arrName1 arr1 $arrName2 arr2
    
    foreach name $names {
	set ex1 [info exists arr1($name)]
	set ex2 [info exists arr2($name)]
	if {$ex1 && $ex2} {
	    if {$arr1($name) != $arr2($name)} {
		return 0
	    }
	} elseif {($ex1 && !$ex2) || (!$ex1 && $ex2)} {
	    return 0
	}
    }
    return 1
}

if {![llength [info commands lassign]]} {
    proc lassign {vals args} {uplevel 1 [list foreach $args $vals break] }
}

# getdirname ---
#
#       Returns the path from 'filePath' thus stripping of any file name.
#       This is a workaround for the strange [file dirname ...] which strips
#       off "the last thing."
#       We need actual files here, not fake ones.
#    
# Arguments:
#       filePath       the path.

proc getdirname {filePath} {
    
    if {[file isfile $filePath]} {
	return [file dirname $filePath]
    } else {
	return $filePath
    }
}
