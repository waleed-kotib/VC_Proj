# optionmenu.tcl --
# 
#       Menubutton with associated menu.
# 
# Copyright (c) 2005 Mats Bengtsson
#       
# $Id: optionmenu.tcl,v 1.1 2005-09-26 11:59:16 matben Exp $

package require snit 1.0
package require tile
package require msgcat

package provide ui::optionmenu 0.1

namespace eval ui::optionmenu {}

interp alias {} ui::optionmenu {} ui::optionmenu::widget

# ui::optionmenu --
# 
#       Menubutton with associated menu.

snit::widgetadaptor ui::optionmenu::widget {
    
    variable menuVar
    variable map
    variable imap
    variable longest

    delegate option * to hull except {-menulist -command -variable}
    delegate method * to hull
    
    option -command  -default {}
    option -menulist -default {}
    option -variable
    
    constructor {args} {
	installhull using ttk::menubutton
	if {[set idx [lsearch $args -textvariable]] >= 0} {
	    set args [lreplace $args $idx [expr {$idx+1}]]]
	}
	$self configurelist $args
	
	set m $win.menu
	menu $m -tearoff 0
	set maxLen 0
	set menuVar [lindex $options(-menulist) 0]
	foreach {str value} $options(-menulist) {
	    set map($str) $value
	    set imap($value) $str
	    if {[set len [string length $str]] > $maxLen} {
		set maxLen $len
		set longest $str
	    }
	    $m add radiobutton -label $str -variable [myvar menuVar] \
	      -command [list $self Command]
	}
	$win configure -textvariable [myvar menuVar] -menu $m
	return
    }
    
    method Command {} {
	if {$options(-variable) ne ""} {
	    uplevel #0 [list set $options(-variable) $map($menuVar)]
	}
	if {$options(-command) ne ""} {
	    uplevel #0 $options(-command)
	}
    }
    
    method set {value} {
	if {[info exists imap($value)]} {
	    set menuVar $imap($value)
	} else {
	    return -code error "value \"$value\" is outside the given range"
	}
    }

    method get {} {
	return $map($menuVar)
    }
    
    method maxwidth {} {
	set W [winfo reqwidth $win]
	set len  [font measure [$win cget -font] $menuVar]
	set mlen [font measure [$win cget -font] $longest]
	return [expr {$W - $len + $mlen + 8}]
    }
}

if {0} {
    package require ui::optionmenu
    set menuDef {
	"Ten seconds"       10
	"One minute"        60
	"Ten minutes"      600
	"One hour"        3600
	"No restriction"     0
    }
    proc Cmd {} {puts "Cmd var=$::var"}

    toplevel .t
    ui::optionmenu .t.mb -menulist $menuDef -direction flush \
      -variable var -command Cmd
    pack .t.mb
    .t.mb maxwidth
}


#-------------------------------------------------------------------------------
