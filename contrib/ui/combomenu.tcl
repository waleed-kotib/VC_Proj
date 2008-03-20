# combomenu.tcl --
# 
#       A combobox with options similar to ui::optionmenu.
#       It is supposed to help the menubutton/mac vs.
#       combobox/win mixup.
# 
# Copyright (c) 2008 Mats Bengtsson
#  
# This file is distributed under BSD style license.
#       
# $Id: combomenu.tcl,v 1.1 2008-03-20 08:49:01 matben Exp $

package require snit 1.0

package provide ui::combomenu 0.1

namespace eval ui::combomenu {}

interp alias {} ui::combomenu {} ui::combomenu::widget

# Compatibility layer.
if {[tk windowingsystem] eq "aqua"} {
    interp alias {} ui::combobutton {} ui::optionmenu
} else {
    interp alias {} ui::combobutton {} ui::combomenu    
}

# ui::combomenu --
# 
#       A combobox with options similar to ui::optionmenu
#       
#       -menulist   {{name ?-value str -image im ...?} ...}
#                   We assume that the -value is unique for each entry
#                   but not necessarily the name. If not the result is
#                   unpredictable.

snit::widgetadaptor ui::combomenu::widget {
    
    variable textVar
    variable name2val
    variable val2name
    variable longest
    variable values {}

    delegate option * to hull except {-command -direction -menulist -variable}
    delegate method * to hull
    
    option -command   -default {}
    option -direction -default {}
    option -menulist  -default {} -configuremethod OnConfigMenulist
    option -variable  -default {} ;# -configuremethod OnConfigVariable
    
    constructor {args} {
	from args -textvariable
	installhull using ttk::combobox

	$self configurelist $args
			
	# Be sure to set textVar to first entry by default.
	if {[llength $options(-menulist)]} {
	    set textVar [lindex $options(-menulist) 0 0]
	}

	# If the variable exists must set our own textVar.
	if {[info exists $options(-variable)]} {
	    set value [set $options(-variable)]
	    if {[info exists val2name($value)]} {
		set textVar $val2name($value)
	    }
	}
	
	# If variable is changed must update us.
	if {$options(-variable) ne ""} {
	    trace add variable $options(-variable) write [list $self Trace]
	}
 	bind $win <<ComboboxSelected>> [list $self OnSelected]
	$win configure -textvariable [myvar textVar] -state readonly
	return
    }
    
    destructor {
	if {$options(-variable) ne ""} {
	    trace remove variable $options(-variable) write [list $self Trace]
	}
    }
    
    method OnSelected {} {
	set selected [$win get]
	if {$options(-command) ne ""} {
	    uplevel #0 $options(-command) [list $name2val($textVar)]
	}
    }
    
    method Trace {varName index op} {
	if {[info exists $options(-variable)]} {
	    set value [set $options(-variable)]
	    set textVar $val2name($value)
	}
    }
    
    method OnConfigMenulist {option value} {
	set options($option) $value
	$self BuildMenuList
    }
    
    method OnConfigVariable {option value} {
	# @@@ NB: Minimal tested!
	if {$options(-variable) ne ""} {
	    trace remove variable $options(-variable) write [list $self Trace]
	}
	set options($option) $value
	
	if {$options(-variable) ne ""} {
	    trace add variable $options(-variable) write [list $self Trace]
	}
	if {[info exists $options(-variable)]} {
	    set value [set $options(-variable)]
	    if {[info exists val2name($value)]} {
		set textVar $val2name($value)
	    }
	}
    }
    
    method BuildMenuList {} {
	set values [list]
	foreach mdef $options(-menulist) {
	    array unset opts
	    set name [lindex $mdef 0]
	    set value $name
	    array set opts [lrange $mdef 1 end]
	    if {[info exists opts(-value)]} {
		set value $opts(-value)
	    }
	    set name2val($name) $value
	    set val2name($value) $name
	    lappend values $name
	}
	$win configure -values $values
    }
    
    method set {value} {
	if {[info exists val2name($value)]} {
	    set textVar $val2name($value)
	} else {
	    return -code error "value \"$value\" is outside the given range"
	}
    }

    method get {} {
	return $name2val($textVar)
    }
    
    method maxwidth {} {
	return [winfo reqwidth $win]
    }
}

if {0} {
    package require ui::combomenu
    set menuDef {
	{"Ten seconds"     -value 10}
	{"One minute"      -value 60}
	{"Ten minutes"     -value 600}
	{"One hour"        -value 3600}
	{"No restriction"  -value 0}
    }
    set var 0
    proc Cmd {value} {puts "Cmd value=$value"}

    toplevel .t
    ui::combomenu .t.mb -menulist $menuDef -direction flush \
      -variable ::var -command Cmd
    pack .t.mb -pady 12
    puts "maxwidth=[.t.mb maxwidth]"
}

#-------------------------------------------------------------------------------
