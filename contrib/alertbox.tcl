# alertbox.tcl ---
#
#       An alerbox that returns immediately (nonmodal).
#       
#  Copyright (c) 2004
#  This source file is distributed under the BSD licens.
#  
#  $Id: alertbox.tcl,v 1.5 2004-09-13 09:05:18 matben Exp $

package provide alertbox 1.0

namespace eval ::alertbox:: {
    global  tcl_platform

    variable this
    set this(wbase)      .alrtb7ysxzt5
    set this(uid)        0
    
    # We use a variable 'this(platform)' that is more convenient for MacOS X.
    switch -- $tcl_platform(platform) {
	unix {
	    set this(platform) $tcl_platform(platform)
	    if {[package vcompare [info tclversion] 8.3] == 1} {	
		if {[string equal [tk windowingsystem] "aqua"]} {
		    set this(platform) "macosx"
		}
	    }
	}
	windows - macintosh {
	    set this(platform) $tcl_platform(platform)
	}
    }
    
    # List all allowed options with their database names and class names.
    
    array set widgetOptions {
	-image        {image        Image     }      \
	-parent       {parent       Parent    }      \
	-title        {title        Title     }      \
    }

    option add *AlertBox.image           ""     widgetDefault
    option add *AlertBox.parent          ""     widgetDefault
    option add *AlertBox.title           ""     widgetDefault
    option add *AlertBox.msg.wrapLength 320     widgetDefault
    option add *AlertBox.offX            20     widgetDefault
    option add *AlertBox.offY            20     widgetDefault

    # A 'widgetDefault' lets resources override which we do not want.
    switch -- $this(platform) {
	macintosh - macosx {
	    option add *AlertBox.msg.font system
	}
	windows {
	    option add *AlertBox.msg.font {Arial 9}	    
	}
	default {
	    option add *AlertBox.msg.font {Helvetica 14} 
	}
    }
    bind AlertBox <Return> {destroy %W}
}

# alertbox::alertbox --
# 
#       Makes an alert dialog wich is nonmodel; i.e. no grab.
#       Returns immediately!
#       
# Arguments:
#       msg         test message to display
#       args    -image
#               -parent
#               -title
# Results:
#       widget toplevel path

proc ::alertbox::alertbox {msg args} {

    variable this
    variable widgetOptions
    
    foreach {name value} $args {
	if {![info exists widgetOptions($name)]} {
	    return -code error "unknown option \"$name\" for the alertbox widget"
	}
    }    
    set w $this(wbase)[incr this(uid)]
    toplevel $w -class AlertBox
    
    switch -- $this(platform) {
	macintosh {
	    ::tk::unsupported::MacWindowStyle style $w movableDBoxProc
	}
	macosx {
	    ::tk::unsupported::MacWindowStyle style $w document closeBox
	}
    }

    # Parse options for the notebook. First get widget defaults.
    foreach name [array names widgetOptions] {
	set optName [lindex $widgetOptions($name) 0]
	set optClass [lindex $widgetOptions($name) 1]
	set options($name) [option get $w $optName $optClass]
    }
    
    # Apply the options supplied in the widget command.
    # Overwrites defaults when option set in command.
    if {[llength $args] > 0}  {
	array set options $args
    }
    wm title $w $options(-title)
    
    frame $w.bot
    frame $w.top
    pack  $w.bot -side bottom -fill both
    pack  $w.top -side top -fill both -expand 1
    label $w.msg -justify left -text $msg
    pack  $w.msg -in $w.top -side right -expand 1 -fill both -padx 16 -pady 4
    if {[string length $options(-image)]} {
	label $w.top.icon -image $options(-image)
	pack $w.top.icon -side left -padx 8 -pady 4
    }
    button $w.bot.btok -text [::msgcat::mc OK] -command [list destroy $w]
    pack $w.bot.btok -side right -padx 16 -pady 10
    
    
    # An alone window shall always be positioned in the middle of the screen.
    set allAlerts [lsearch -all -inline -glob [wm stackorder .] $this(wbase)*]
    wm withdraw $w
    update idletasks
    
    if {[string length $options(-parent)] && \
      [winfo ismapped $options(-parent)]} {
	set x [expr {[winfo rootx $options(-parent)] + \
		([winfo width $options(-parent)]-[winfo reqwidth $w])/2}]
	set y [expr {[winfo rooty $options(-parent)] + \
		([winfo height $options(-parent)]-[winfo reqheight $w])/2}]
    } else {
	if {[llength $allAlerts] == 0} {
	    set x [expr {[winfo screenwidth $w]/2 - [winfo reqwidth $w]/2 \
	      - [winfo vrootx [winfo parent $w]]}]
	    set y [expr {[winfo screenheight $w]/2 - [winfo reqheight $w]/2 \
	      - [winfo vrooty [winfo parent $w]]}]
	} else {
	    set x [winfo x [lindex $allAlerts end]]
	    set y [winfo y [lindex $allAlerts end]]
	    incr x [option get $w offX {}]
	    incr y [option get $w offY {}]
	}
    }
    
    # Check bounds.
    if {$x < 0} {
	set x 0
    } elseif {$x > ([winfo screenwidth $w]-[winfo reqwidth $w])} {
	set x [expr {[winfo screenwidth $w]-[winfo reqwidth $w]}]
    }
    if {$y < 0} {
	set y 0
    } elseif {$y > ([winfo screenheight $w]-[winfo reqheight $w])} {
	set y [expr {[winfo screenheight $w]-[winfo reqheight $w]}]
    }
    if {[tk windowingsystem] eq "macintosh" \
      || [tk windowingsystem] eq "aqua"} {
	# Avoid the native menu bar which sits on top of everything.
	if {$y < 20} { set y 20 }
    }
    wm maxsize $w [winfo screenwidth $w] [winfo screenheight $w]
    wm resizable $w 0 0
    wm geom $w +$x+$y
    wm deiconify $w
    return $w
}

#-------------------------------------------------------------------------------
