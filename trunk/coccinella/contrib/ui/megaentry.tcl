# megaentry.tcl --
# 
#       A mega widget dialog with a message and a single entry.
#       Only a convenient wrapper around ui::dialog.
#
# Copyright (c) 2006 Mats Bengtsson
#  
# This file is distributed under BSD style license.
#       
# $Id: megaentry.tcl,v 1.2 2007-07-19 06:28:12 matben Exp $

package require ui::dialog

package provide ui::megaentry 0.1

proc ui::megaentry {args} {
 
    set w [autoname]
    variable $w
    upvar #0 $w state

    array set dlgA {
	-modal 1
    }
    array set dlgA $args
    unset -nocomplain dlgA(-label) dlgA(-textvariable)
    set dlgA(-variable) $w\(var)

    array set optA {
	-label  ""
    }
    array set optA $args

    eval {ui::dialog::widget $w} [array get dlgA]
    set fr [$w clientframe]
    ttk::label $fr.l -text $optA(-label)
    ttk::entry $fr.e -textvariable $w\(textvar)
    
    grid  $fr.l  $fr.e  -sticky e
    grid $fr.e -sticky ew
    grid columnconfigure $fr 1 -weight 1
    
    if {[info exists optA(-textvariable)]} {
	upvar $optA(-textvariable) textvar
	if {![info exists textvar]} {
	    set textvar ""
	}
	$fr.e insert end $textvar
    }
    Grab $w
    
    if {[info exists state(textvar)]} {
	set textvar $state(textvar)
    }    
    set ans $state(var)
    unset -nocomplain state
    return $ans
}

if {0} {
    set str "These two must be able to call before any dialog instance created."
    set str2 "Elvis has left the building"
    set ans [ui::megaentry -message $str -detail $str2 -label Enter -textvariable xvar -type okcancel]
    puts "xvar=$xvar"
    
}

