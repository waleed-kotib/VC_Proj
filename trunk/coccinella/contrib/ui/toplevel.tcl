# toplevel.tcl --
# 
#
#
# Copyright (c) 2005 Mats Bengtsson
#  
# This file is distributed under BSD style license.
#       
# $Id: toplevel.tcl,v 1.4 2007-12-22 14:52:22 matben Exp $

package require snit 1.0
package require msgcat
package require ui::util

package provide ui::toplevel 0.1

namespace eval ui::toplevel {
    
    
}

interp alias {} ui::toplevel {} ui::toplevel::widget

snit::widgetadaptor ui::toplevel::widget {

    delegate option * to hull except {
	-alpha -class -closecommand -geovariable -padding -title
    }
    delegate option -padding to frm

    delegate method * to hull except {grab}

    option -class
    option -geovariable
    option -title
    option -closecommand
    option -alpha        -default 1.0  \
      -configuremethod OnConfigAlpha
    
    constructor {args} {
	set opts {}
	if {[set idx [lsearch $args "-class"]] >= 0} {
	    lappend opts -class [lindex $args [incr idx]]
	}
	eval {installhull using toplevel} $opts
	if {[tk windowingsystem] eq "aqua"} {
	    #::tk::unsupported::MacWindowStyle style $win document none
	}
	install frm using ttk::frame $win.f
	
	pack $win.f -fill both -expand 1

	$self configurelist $args

	wm title $win $options(-title)
	$self OnConfigAlpha -alpha $options(-alpha)
	if {[string length $options(-geovariable)]} {
	    ui::PositionClassWindow $win $options(-geovariable) "XXX"
	} 
	return
    }
    
    destructor {
	if {[string length $options(-closecommand)]} {
	    set code [catch {uplevel #0 $options(-closecommand)}]

	    # @@@ Can we stop destruction ???
	}
    }
    
    method OnConfigAlpha {option value} {
	array set attr [wm attributes $win]
	if {[info exists attr(-alpha)]} {
	    after idle [list wm attributes $win -alpha $value]
	}
	set options($option) $value
    }

    # Public methods:
    
    method clientframe {} { 
	return $win.f 
    }

    method grab {} {
	ui::Grab $win
    }
}

#-------------------------------------------------------------------------------
