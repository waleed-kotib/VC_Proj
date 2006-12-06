# optionmenu.tcl --
# 
#       Menubutton with associated menu.
# 
# Copyright (c) 2005-2006 Mats Bengtsson
#       
# $Id: optionmenu.tcl,v 1.10 2006-12-06 07:39:40 matben Exp $

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
    variable mimage

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
	set menuVar [lindex $options(-menulist) 0 0]
	
	# Build the menu.

	foreach mdef $options(-menulist) {
	    array unset opts
	    set str [lindex $mdef 0]
	    set value $str
	    array set opts [lrange $mdef 1 end]
	    if {[info exists opts(-value)]} {
		set value $opts(-value)
	    }
	    set map($str) $value
	    set imap($value) $str
	    unset -nocomplain opts(-value)
	    if {[info exists opts(-image)]} {
		set mimage($value) $opts(-image)
	    }
	    if {[tk windowingsystem] eq "aqua"} {
		unset -nocomplain opts(-image)
	    }
	    if {[set len [string length $str]] > $maxLen} {
		set maxLen $len
		set longest $str
	    }
	    eval {$m add radiobutton -label $str -variable [myvar menuVar] \
	      -command [list $self Command] -compound left} [array get opts]
	}
	
	# If the variable exists must set our own menuVar.
	if {[info exists $options(-variable)]} {
	    set value [set $options(-variable)]
	    set menuVar $imap($value)
	}
	
	# If variable is changed must update us.
	if {$options(-variable) ne ""} {
	    trace add variable $options(-variable) write [list $self Trace]
	}

	$win configure -textvariable [myvar menuVar] -menu $m -compound left
	if {[info exists mimage($value)]} {
	    $win configure -image $mimage($value)
	}
	return
    }
    
    destructor {
	if {$options(-variable) ne ""} {
	    trace remove variable $options(-variable) write [list $self Trace]
	}
    }
    
    method Command {} {
	set value $map($menuVar)
	if {[info exists mimage($value)]} {
	    $win configure -image $mimage($value)
	}
	if {$options(-variable) ne ""} {
	    uplevel #0 [list set $options(-variable) $value]
	}
	if {$options(-command) ne ""} {
	    uplevel #0 $options(-command) [list $value]
	}
    }
    
    method Trace {varName index op} {
	if {[info exists $options(-variable)]} {
	    set value [set $options(-variable)]
	    set menuVar $imap($value)
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
	if {0} {
	    # This doesn't work in tile 0.7.1 since -font gone.
	    set W [winfo reqwidth $win]
	    set len  [font measure [$win cget -font] $menuVar]
	    set mlen [font measure [$win cget -font] $longest]
	}
	
	# Ugly! 
	# Just pick any image assuming same size.
	set image ""
	if {[llength [array names mimage]]} {
	    set image $mimage([lindex [array names mimage] 0])
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
    set var 0
    proc Cmd {value} {puts "Cmd value=$value"}

    toplevel .t
    ui::optionmenu .t.mb -menulist $menuDef -direction flush \
      -variable ::var -command Cmd
    pack .t.mb
    .t.mb maxwidth
}

#-------------------------------------------------------------------------------
