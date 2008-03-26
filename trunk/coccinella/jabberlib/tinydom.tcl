#  tinydom.tcl ---
#  
#      This file is part of The Coccinella application. It implements 
#      a tiny DOM model which wraps xml into tcl lists.
#
#  Copyright (c) 2003  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: tinydom.tcl,v 1.14 2008-03-26 13:11:34 matben Exp $

package require xml

package provide tinydom 0.2

# This is an attempt to make a minimal DOM thing to store xml data as
# a hierarchical list which is better suited to Tcl.
# @@@ Try make a common syntax with wrapper.

namespace eval tinydom {
    variable uid 0
    variable cache
}

proc tinydom::parse {xml args} {
    variable uid
    variable cache

    array set argsA {
	-package xml
    }
    array set argsA $args
    switch -- $argsA(-package) {
	xml {
	    set xmlparser [xml::parser]
	}
	qdxml {
	    package require qdxml
	    set xmlparser [qdxml::create]
	}
	default {
	    return -code error "unknown -package \"$argsA(-package)\""
	}
    }

    # Store in internal array and return token which is the array index.
    set token [namespace current]::[incr uid]
    upvar #0 $token state
    
    set state(1) [list]
    set state(level) 0
    
    $xmlparser configure -reportempty 1   \
      -elementstartcommand  [namespace code [list ElementStart $token]] \
      -elementendcommand    [namespace code [list ElementEnd $token]]   \
      -characterdatacommand [namespace code [list CHdata $token]]       \
      -ignorewhitespace     1
    $xmlparser parse $xml

    set cache($token) $state(1)
    unset state
    return $token
}

proc tinydom::ElementStart {token tag attrlist args} {
    upvar #0 $token state

    array set argsA $args
    if {[info exists argsA(-namespacedecls)]} {
	lappend attrlist xmlns [lindex $argsA(-namespacedecls) 0]
    }
    set state([incr state(level)]) [list $tag $attrlist 0 {} {}]
}

proc tinydom::ElementEnd {token tagname args} {
    upvar #0 $token state

    set level $state(level)
    if {$level > 1} {
    
	# Insert the child tree in the parent tree.
	Append $token [expr $level-1] $state($level)
    }
    incr state(level) -1
}

proc tinydom::CHdata {token chdata} {
    upvar #0 $token state

    set level $state(level)
    set cdata [lindex $state($level) 3]
    append cdata [xmldecrypt $chdata]
    lset state($level) 3 $cdata
}

proc tinydom::Append {token plevel childtree} {
    upvar #0 $token state
    
    # Get child list at parent level (level).
    set childlist [lindex $state($plevel) 4]
    lappend childlist $childtree
    
    # Build the new parent tree.
    lset state($plevel) 4 $childlist
}

proc tinydom::xmldecrypt {chdata} {

    return [string map {
	{&amp;} {&} {&lt;} {<} {&gt;} {>} {&quot;} {"} {&apos;} {'}} $chdata]   
}

proc tinydom::documentElement {token} {
    variable cache
    return $cache($token)
}

proc tinydom::tagname {xmllist} {
    return [lindex $xmllist 0]
}

proc tinydom::attrlist {xmllist} {
    return [lindex $xmllist 1]
}

proc tinydom::chdata {xmllist} {
    return [lindex $xmllist 3]
}

proc tinydom::children {xmllist} {
    return [lindex $xmllist 4]
}

proc tinydom::getattribute {xmllist attrname} {
    foreach {attr val} [lindex $xmllist 1] {
	if {[string equal $attr $attrname]} {
	    return $val
	}
    }
    return
}

proc tinydom::getfirstchildwithtag {xmllist tag} {    
    set c [list]
    foreach celem [lindex $xmllist 4] {
	if {[string equal [lindex $celem 0] $tag]} {
	    set c $celem
	    break
	}
    }
    return $c
}

proc tinydom::cleanup {token} {
    variable cache
    unset -nocomplain cache($token)
}

#-------------------------------------------------------------------------------
