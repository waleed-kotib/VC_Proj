# megaentry.tcl --
# 
#       A mega widget dialog with a message and a single entry.
#       Only a convenient wrapper around ui::dialog.
#
# Copyright (c) 2006-2007 Mats Bengtsson
#  
# This file is distributed under BSD style license.
#       
# $Id: megaentry.tcl,v 1.5 2007-08-08 13:01:07 matben Exp $

package require ui::dialog

package provide ui::megaentry 0.1

proc ui::megaentry {args} {
 
    set w [autoname]
    variable $w
    upvar 0 $w state
    set token [namespace current]::$w    

    set state(-label) [ui::from args -label]
    set state(-modal) [ui::from args -modal]
    set state(-show)  [ui::from args -show]
    set state(-value) [ui::from args -value]
    ui::from args -textvariable
    ui::from args -type
    ui::from args -variable
    
    set state(-textvariable) ""
    
    eval {ui::dialog::widget $w -type okcancel -variable $token\(dlgbt)} $args
    set fr [$w clientframe]
    ttk::label $fr.l -text $state(-label)
    ttk::entry $fr.e -textvariable $token\(-textvariable)
    if {$state(-show) ne ""} {
	$fr.e configure -show $state(show)
    }
    
    grid  $fr.l  $fr.e  -sticky e
    grid $fr.e -sticky ew
    grid columnconfigure $fr 1 -weight 1
    
    if {$state(-value) ne ""} {
	$fr.e insert 0 $state(-value)
    }
    focus $fr.e    
    Grab $w
    
    if {$state(dlgbt) eq "ok"} {
	# Return result this way to be able to set empty results which is not
	# possible else.
	set ans [list "ok" $state(-textvariable)]
    } else {
	set ans ""
    }
    unset -nocomplain state
    return $ans
}

# ui::megaentrytext --
# 
#       Simple accessor function to get entry text.

proc ui::megaentrytext {ans} {
    return [lindex $ans 1]
}

if {0} {
    set str "These two must be able to call before any dialog instance created."
    set str2 "Elvis has left the building"
    set ans [ui::megaentry -message $str -detail $str2 -label Enter]    
}

