#  tinydom.tcl ---
#  
#      This file is part of the whiteboard application. It implements 
#      a tiny DOM model which wraps xml int tcl lists.
#
#  Copyright (c) 2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: tinydom.tcl,v 1.1 2003-07-26 13:41:42 matben Exp $

package require xml

package provide tinydom 0.1

# This is an attempt to make a minimal DOM thing to store xml data as
# an hierarchical list which is better suited to Tcl.

namespace eval tinydom {

    variable xmlobj
    variable level 0
    variable uid 0
    variable cache
}

proc tinydom::parse {xml} {
    variable xmlobj
    variable uid
    variable cache

    set xmlparser [xml::parser]
    $xmlparser configure -reportempty 1   \
      -elementstartcommand  [namespace current]::XmlElementStart     \
      -elementendcommand    [namespace current]::XmlElementEnd       \
      -characterdatacommand [namespace current]::XmlCHdata           \
      -ignorewhitespace     1
    $xmlparser parse $xml
    
    # Store in internal array and return token which is the array index.
    set token tinydom[incr uid]
    set cache($token) $xmlobj(1)
    unset xmlobj
    return $token
}

# This is an attempt to make a minimal DOM thing to store xml data as
# an hierarchical list which is better suited to Tcl.

proc tinydom::XmlElementStart {tagname attrlist args} {
    variable xmlobj
    variable level

    #puts "XmlElementStart: tagname=$tagname, attrlist=$attrlist, args=$args"
    set xmlobj([incr level]) [list $tagname $attrlist {} {}]
}

proc tinydom::XmlElementEnd {tagname args} {
    variable xmlobj
    variable level

    if {$level > 1} {
    
	# Insert the child tree in the parent tree.
	tinydom::XmlAppend [expr $level-1] $xmlobj($level)
    }
    incr level -1
}

proc tinydom::XmlCHdata {chdata} {
    variable xmlobj
    variable level

    set cdata [lindex $xmlobj($level) 2]
    append cdata [xmldecrypt $chdata]
    lset xmlobj($level) 2 $cdata
}

proc tinydom::XmlAppend {plevel childtree} {
    variable xmlobj
    
    # Get child list at parent level (level).
    set childlist [lindex $xmlobj($plevel) 3]
    lappend childlist $childtree
    
    # Build the new parent tree.
    lset xmlobj($plevel) 3 $childlist
}

proc tinydom::xmldecrypt {chdata} {

    foreach from {{\&amp;} {\&lt;} {\&gt;} {\&quot;} {\&apos;}}   \
      to {{\&} < > {"} {'}} {
	regsub -all $from $chdata $to chdata
    }	
    return $chdata
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
    
    return [lindex $xmllist 2]
}

proc tinydom::children {xmllist} {
    
    return [lindex $xmllist 3]
}

proc tinydom::cleanup {token} {
    variable cache
    
    catch {unset cache($token)}
}

#-------------------------------------------------------------------------------
