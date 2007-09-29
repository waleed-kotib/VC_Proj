# mstack.tcl ---
#
#       Provides a kind of multi stack package.
#       It is used to pick colors. Assume you have got n colors and you want
#       these distributed to a number of resources in an even way as possible.
#       
#  Copyright (c) 2007
#  
#  This file is distributed under BSD style license.
#  
#  $Id: mstack.tcl,v 1.1 2007-09-29 06:56:44 matben Exp $

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
    
    set min [Min [Avalues state]]
    puts "min=$min"
    
}

proc mstack::Avalues {arrName} {
    upvar $arrName arr
    set values [list]
    foreach {key value} [array get arr] {
	lappend values $value
    }
    return $values
}

proc mstack::Min {args} {
    lindex [lsort -real $args] 0
}


proc mstack::free {token} {
    variable $token
    unset -nocomplain $token
}

if {0} {
    set tok [mstack::init 5]
    mstack::add $tok black
    
}

