# alertbox.tcl ---
#
#       An alerbox that returns immediately.
#       
#  Copyright (c) 2004
#  
#  $Id: alertbox.tcl,v 1.1 2004-06-15 14:30:11 matben Exp $

package provide alertbox 1.0

namespace eval ::alertbox:: {
    global  tcl_platform

    variable this
    set this(wbase)      .alrtb7ysxzt5
    set this(offx)       20
    set this(offy)       20
    
    variable uid         0
    
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
    
    option add *AlertBox.msg.wrapLength 180 widgetDefault
    switch -- $this(platform) {
	macintosh - macosx {
	    option add *AlertBox.msg.font system widgetDefault
	}
	windows {
	    option add *AlertBox.msg.font {Arial 8} widgetDefault	    
	}
	default {
	    option add *AlertBox.msg.font {Times 10} widgetDefault
	}
    }

}

# alertbox::alertbox --
# 
# 

proc ::alertbox::alertbox {msg args} {
    variable this
    variable uid
    
    set w $this(wbase)[incr uid]
    toplevel $w -class AlertBox
    switch -- $this(platform) {
	macintosh - macosx {
	    #::tk::unsupported::MacWindowStyle style $w dBoxProc
	}
    }
    wm title $w ""
    wm protocol $w WM_DELETE_WINDOW { }
    
    
    frame $w.bot
    frame $w.top
    pack $w.bot -side bottom -fill both
    pack $w.top -side top -fill both -expand 1
    label $w.msg -justify left -text $msg
    pack  $w.msg -in $w.top -side right -expand 1 -fill both -padx 3m -pady 3m
    button $w.bot.btok -text [::msgcat::mc OK] -default active \
      -command [list destroy $w]
    pack $w.bot.btok -side right -padx 12 -pady 6
    
    
    # An alone window shall always be positioned in the middle of the screen.
    set allAlerts [lsearch -all -inline -glob [wm stackorder .] $this(wbase)*]
    wm withdraw $w
    update idletasks
    if {[llength $allAlerts] == 0} {
	set x [expr {[winfo screenwidth $w]/2 - [winfo reqwidth $w]/2 \
	  - [winfo vrootx [winfo parent $w]]}]
	set y [expr {[winfo screenheight $w]/2 - [winfo reqheight $w]/2 \
	  - [winfo vrooty [winfo parent $w]]}]
    } else {
	set geom [wm geometry [lindex $allAlerts end]]
	regexp {[0-9]+x[0-9]+\+(\-?[0-9]+)\+(\-?[0-9]+)}  \
	  $geom m x y
	incr x $this(offx)
	incr y $this(offy)
    }
    if {$x < 0} {
	set x 0
    }
    if {$y < 0} {
	set y 0
    }
    wm maxsize $w [winfo screenwidth $w] [winfo screenheight $w]
    wm geom $w +$x+$y
    wm deiconify $w
    
    
    
}

#-------------------------------------------------------------------------------
