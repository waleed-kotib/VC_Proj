# optionmenu.tcl --
# 
#       Menubutton with associated menu.
# 
# Copyright (c) 2005-2007 Mats Bengtsson
#  
# This file is distributed under BSD style license.
#       
# $Id: optionmenu.tcl,v 1.19 2007-10-03 06:48:16 matben Exp $

package require snit 1.0
package require tile

package provide ui::optionmenu 0.1

namespace eval ui::optionmenu {}

interp alias {} ui::optionmenu {} ui::optionmenu::widget

# ui::optionmenu --
# 
#       Menubutton with associated menu.
#       
#       -menulist   {{name ?-value str -image im ...?} ...}
#                   We assume that the -value is unique for each entry
#                   but not necessarily the name. If not the result is
#                   unpredictable.

snit::widgetadaptor ui::optionmenu::widget {
    
    variable nameVar
    variable menuValue
    variable name2val
    variable val2name
    variable val2im
    variable longest

    delegate option * to hull except {-menulist -command -variable}
    delegate method * to hull
    
    option -command  -default {}
    option -menulist -default {} -configuremethod OnConfigMenulist
    option -variable
    
    constructor {args} {
	from args -textvariable
	installhull using ttk::menubutton
	set menuValue ""
	set m $win.menu
	menu $m -tearoff 0

	$self configurelist $args
	
	# Be sure to set nameVar and menuValue to first entry by default.
	if {[llength $options(-menulist)]} {
	    set nameVar [lindex $options(-menulist) 0 0]
	    set value $nameVar
	    array set opts [lrange [lindex $options(-menulist) 0] 1 end]
	    if {[info exists opts(-value)]} {
		set value $opts(-value)
	    }
	    set menuValue $value
	}
		
	# If the variable exists must set our own nameVar.
	if {[info exists $options(-variable)]} {
	    set value [set $options(-variable)]
	    if {[info exists val2name($value)]} {
		set menuValue $value
		set nameVar $val2name($value)
	    }
	}
	
	# If variable is changed must update us.
	if {$options(-variable) ne ""} {
	    trace add variable $options(-variable) write [list $self Trace]
	}

	$win configure -textvariable [myvar nameVar] -menu $m -compound left
	if {[info exists val2im($menuValue)]} {
	    $win configure -image $val2im($menuValue)
	}
	return
    }
    
    destructor {
	if {$options(-variable) ne ""} {
	    trace remove variable $options(-variable) write [list $self Trace]
	}
    }
    
    method Command {} {
	set nameVar $val2name($menuValue)
	if {[info exists val2im($menuValue)]} {
	    $win configure -image $val2im($menuValue)
	}
	if {$options(-variable) ne ""} {
	    uplevel #0 [list set $options(-variable) $menuValue]
	}
	if {$options(-command) ne ""} {
	    uplevel #0 $options(-command) [list $menuValue]
	}
    }
    
    method Trace {varName index op} {
	if {[info exists $options(-variable)]} {
	    set value [set $options(-variable)]
	    set menuValue $value
	    set nameVar $val2name($value)
	}
    }
    
    method OnConfigMenulist {option value} {
	set options($option) $value
	$self BuildMenuList
    }
    
    method BuildMenuList {} {
	set m $win.menu
	destroy $m
	menu $m -tearoff 0

	set maxLen 0
	set longest ""

	# Build the menu.

	foreach mdef $options(-menulist) {
	    array unset opts
	    set name [lindex $mdef 0]
	    if {$name eq "separator"} {
		$m add separator
	    } else {
		set value $name
		array set opts [lrange $mdef 1 end]
		if {[info exists opts(-value)]} {
		    set value $opts(-value)
		}
		set name2val($name) $value
		set val2name($value) $name
		if {[info exists opts(-image)]} {
		    set val2im($value) $opts(-image)
		}
		if {[tk windowingsystem] eq "aqua"} {
		    unset -nocomplain opts(-image)
		}
		if {[set len [string length $name]] > $maxLen} {
		    set maxLen $len
		    set longest $name
		}
		# @@@ TODO: keep a -value since labels can be identical!
		eval {$m add radiobutton -label $name -variable [myvar menuValue] \
		  -command [list $self Command] -compound left} [array get opts]
	    }
	}
    }
    
    method set {value} {
	if {[info exists val2name($value)]} {
	    set menuValue $value
	    set nameVar $val2name($value)
	} else {
	    return -code error "value \"$value\" is outside the given range"
	}
    }

    method get {} {
	return $menuValue
    }
    
    method maxwidth {} {
	
	# Ugly! 
	# Just pick any image assuming same size.
	set image ""
	if {[llength [array names val2im]]} {
	    set image $val2im([lindex [array names val2im] 0])
	}
	set tmp .__tmp_menubutton
	ttk::menubutton $tmp -text $longest -image $image -compound left
	set W [winfo reqwidth $tmp]
	destroy $tmp
	return [expr {$W + 8}]
    }
}

if {0} {
    package require ui::optionmenu
    set menuDef {
	{"Ten seconds"     -value 10}
	{"One minute"      -value 60}
	{"Ten minutes"     -value 600}
	{"One hour"        -value 3600}
	{"No restriction"  -value 0}
    }
    set xmenuDef {
	{AIM    -value aim}
	{MSN    -value msn1}
	{MSN    -value msn2}
	{MSN    -value msn3}
	{Yahoo  -value yahoo}
    }
    #set var 0
    proc Cmd {value} {puts "Cmd value=$value"}

    toplevel .t
    ui::optionmenu .t.mb -menulist $menuDef -direction flush \
      -variable ::var -command Cmd
    pack .t.mb
    .t.mb maxwidth
    
    set mlist [.t.mb cget -menulist]
    lappend mlist {"Extra" -value extra}
    .t.mb configure -menulist $mlist
}

#-------------------------------------------------------------------------------
