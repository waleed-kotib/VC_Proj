#  utils.tcl ---
#  
#      This file is part of The Coccinella application. We collect some handy 
#      small utility procedures here.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: utils.tcl,v 1.3 2005-10-04 13:02:53 matben Exp $

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
	uplevel set $listName [list [lreplace $listValue $idx $idx]]
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
