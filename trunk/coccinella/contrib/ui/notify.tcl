# notify.tcl
# 
#       A pure Tcl Growl like x-platform notification window.
#       Do not mixup with the outdated notebox package.
#
#  Copyright (c) 2008
#  
#  This source file is distributed under the BSD license.
#  
#  $Id: notify.tcl,v 1.1 2008-03-20 08:49:01 matben Exp $

package require Tk 8.5
package require tkpath 0.2.8 ;# switch to 0.3 later on
package require snit 1.0
package require msgcat
package require ui::util

package provide ui::notify 0.1

namespace eval ui::notify {}

interp alias {} ui::notify {} ui::notify::widget

snit::widgetadaptor ui::notify::widget {
    delegate option * to hull except {
	-title -message
    }

    delegate method * to hull

    option -image
    option -message
    option -title
    
    constructor {args} {
	set opts [list]
	switch -- [tk windowingsystem] {
	    aqua {
		lappend opts -transparent 1 -topmost 1
	    }
	    win32 {
		lappend opts -alpha 0.8 -transparentcolor purple -topmost 1
	    }
	}
	installhull using toplevel -class Growl
	wm overrideredirect $win 1
	wm withdraw $win
	switch -- [tk windowingsystem] {
	    aqua {
		#tk::unsupported::MacWindowStyle style $win help hideOnSuspend
		$win configure -bg systemTransparent
	    }
	    win32 {
		$win configure -bg purple
	    }
	}
	wm attributes $win {*}$opts

	# NB: If we do this before 'unsupported' it takes focus !?
	wm resizable $win 0 0 
	$self configurelist $args
	
	set canvas $win.c
	canvas $canvas -width 300 -height 80 -bd 0 -highlightthickness 0
	switch -- [tk windowingsystem] {
	    aqua {
		$canvas configure -bg systemTransparent
	    }
	    win32 {
		$canvas configure -bg purple
	    }
	}
	pack $canvas
	$canvas create prect 1 1 299 79 -rx 12 -stroke "" -fill black \
	  -fillopacity 0.6



    }
    
    destructor {

    }

    # Public methods:
    
}

if {0} {
    set tkpath::antialias 1
    package require ui::notify
    set cociFile [file join $this(imagePath) bug-128.png]
    ui::notify .ntfy -message "Hej svejs i lingonskogen"
    
    
}

#-------------------------------------------------------------------------------








