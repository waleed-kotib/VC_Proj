# mstack.tcl ---
#
#       Provides a kind of multi stack package.
#       It is used to pick colors. Assume you have got n colors and you want
#       these distributed to a number of resources in an even way as possible.
#       Not optimized.
#       
#  Copyright (c) 2007  Mats Bengtsson
#  
#  This file is distributed under BSD style license.
#  
#  $Id: mstack.tcl,v 1.4 2007-10-01 07:56:46 matben Exp $

package provide mstack 1.0

namespace eval mstack {
    variable uid 0
}

proc mstack::init {n} {
    variable uid
    
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state

    for {set i 0} {$i < $n} {incr i} {
	set state($i) [list]
    }
    return $token
}

proc mstack::add {token key} {
    variable $token
    upvar 0 $token state
    
    set lengths [Apply llength [Avalues state]]
    set min [eval Min $lengths]
    set idx [lsearch $lengths $min]
    lappend state($idx) $key
    return $idx
}

proc mstack::exists {token key} {
    return [expr {[get $token $key] == -1 ? 0 : 1}]
}

proc mstack::get {token key} {
    variable $token
    upvar 0 $token state
    
    set indices [Apply [list lsearch -exact] [Avalues state] [list $key]]
    return [lsearch -exact -not $indices -1]
}

proc mstack::remove {token key} {
    variable $token
    upvar 0 $token state

    set indices [Apply [list lsearch -exact] [Avalues state] [list $key]]
    set idx [lsearch -not $indices -1]
    if {$idx >= 0} {
	set i [lsearch -exact $state($idx) $key]
	set state($idx) [lreplace $state($idx) $i $i]
    }
    return $idx
}

proc mstack::Avalues {arrName} {
    upvar $arrName arr
    set values [list]
    foreach i [lsort -integer [array names arr]] {
	lappend values $arr($i)
    }
    return $values
}

proc mstack::Apply {cmd alist {post ""}} {
    set applied [list]
    foreach e $alist {
	lappend applied [uplevel $cmd [list $e] $post]
    }
    return $applied
}

proc mstack::Min {args} {
    lindex [lsort -real $args] 0
}

proc mstack::free {token} {
    variable $token
    unset -nocomplain $token
}

# Test:
if {0} {
    set tok [mstack::init 5]
    mstack::add $tok "a a"
    mstack::add $tok b
    mstack::add $tok c
    mstack::add $tok d
    mstack::add $tok e
    mstack::add $tok f
    mstack::add $tok g
    mstack::add $tok h
    parray $tok
    mstack::get $tok "a a"
    mstack::get $tok d
    mstack::get $tok h
    mstack::get $tok x
    mstack::remove $tok d
    mstack::remove $tok g
    mstack::remove $tok y
    mstack::exists $tok "a a"
    mstack::exists $tok X
    parray $tok
    mstack::add $tok A
    mstack::add $tok B
    parray $tok
    mstack::free $tok
}

