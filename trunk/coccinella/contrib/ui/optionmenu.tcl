# optionmenu.tcl --
# 
#       Menubutton with associated menu.
# 
# Copyright (c) 2005-2007 Mats Bengtsson
#       
# $Id: optionmenu.tcl,v 1.12 2007-01-28 12:21:18 matben Exp $

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
    option -menulist -default {}
    option -variable
    
    constructor {args} {
	from args -textvariable
	installhull using ttk::menubutton
	$self configurelist $args
	
	set m $win.menu
	menu $m -tearoff 0
	set maxLen 0
	set nameVar [lindex $options(-menulist) 0 0]
	
	# Build the menu.

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
	    if {![info exists firstValue]} {
		set firstValue $value
	    }
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
	set value $firstValue
	set menuValue $firstValue
	
	# If the variable exists must set our own nameVar.
	if {[info exists $options(-variable)]} {
	    set value [set $options(-variable)]
	    set menuValue $value
	    set nameVar $val2name($value)
	}
	
	# If variable is changed must update us.
	if {$options(-variable) ne ""} {
	    trace add variable $options(-variable) write [list $self Trace]
	}

	$win configure -textvariable [myvar nameVar] -menu $m -compound left
	if {[info exists val2im($value)]} {
	    $win configure -image $val2im($value)
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
    set menuDef {
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
}

#-------------------------------------------------------------------------------
