#  utils.tcl ---
#  
#      This file is part of The Coccinella application. We collect some handy 
#      small utility procedures here.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
#  This file is distributed under BSD style license.
#  
# $Id: utils.tcl,v 1.14 2008-04-17 15:00:28 matben Exp $

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

# lapply --
# 
#       Applies a command to each list element.
#       NB: See mstack for a more general!

proc lapply {cmd alist} {
    set applied [list]
    foreach e $alist {
	lappend applied [uplevel $cmd [list $e]]
    }
    return $applied
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
    set tmp [list]
    set args [lindex $args 0]
    for {set i [expr [llength $args] - 1]} {$i >= 0} {incr i -1} {
	lappend tmp [lindex $args $i]
    }
    return $tmp
}

if {![llength [info commands lreverse]]} {
    interp alias {} lreverse {} lrevert
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

# A few routines: 
# Copyright (c) 1997-1999 Jeffrey Hobbs 
# 
# lintersect -- 
#   returns list of items that exist only in all lists 
# Arguments: 
#   args        lists 
# Returns: 
#   The list of common items, uniq'ed, order independent 
#
proc lintersect {args} {
    set len [llength $args]
    if {$len <= 1} {
	return [lindex $args 0]
    }
    array set a {}
    foreach l [lindex $args 0] {
	set a($l) 1
    }
    foreach list [lrange $args 1 end] {
	foreach l $list {
	    if {[info exists a($l)]} {
		incr a($l)
	    }
	}
    }
    set retval {}
    foreach l [array names a] {
	if {$a($l) == $len} {
	    lappend retval $l
	}
    }
    return $retval
} 

# lunique -- 
#   order independent list unique proc.  most efficient, but requires 
#   __LIST never be an element of the input list 
# Arguments: 
#   __LIST      list of items to make unique 
# Returns: 
#   list of only unique items, order not defined 
#   
proc lunique {__LIST} {
    if {[llength $__LIST]} {
	foreach $__LIST $__LIST break
	unset __LIST
	return [info locals]
    }
} 

# luniqueo -- 
#   order dependent list unique proc 
# Arguments: 
#   ls          list of items to make unique 
# Returns: 
#   list of only unique items in same order as input 
#   
proc luniqueo {ls} {
    set rs {}
    foreach l $ls {
	if {[info exist ($l)]} { continue }
	lappend rs $l
	set ($l) {}
    }
    return $rs
} 

# lsearchsublists --
# 
#       Search sublists instead. Very incomplete!
#       Note: returns empty if non found.
#
# @@@ OBSOLETE in 8.5!

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

# ESCglobs --
#
#	array get and array unset accepts glob characters. These need to be
#	escaped if they occur as part of a variable.

proc ESCglobs {s} {
    return [string map {* \\* ? \\? [ \\[ ] \\] \\ \\\\} $s]
}

# arraysequal --
# 
#       Compare two arrays.

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

# arraygetsublist --
# 
#       Extracts a flat array from another array that matches 'prefix',
#       and strips off all prefix. Use dict instead when that comes.

proc arraygetsublist {arrName prefix} {
    upvar 1 $arrName arr
    set subL [list]
    set len [string length $prefix]
    foreach {name value} [array get arr $prefix*] {
	set key [string range $name $len end]
	lappend subL $key $value
    }
    return $subL
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

proc dumpwidgethierarchy {{win .} {tabs "\t"}} {
    foreach w [winfo children $win] {
	puts "$tabs$w"
	dumpwidgethierarchy $w "$tabs\t"
    }
}

