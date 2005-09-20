# progress.tcl --
#
#       Progress megawidgets.
#
# Copyright (c) 2005 Mats Bengtsson
#       
# $Id: progress.tcl,v 1.2 2005-09-20 14:09:51 matben Exp $

package require snit 1.0
package require tile
package require msgcat
package require ui::util

package provide ui::progress 0.1

namespace eval ui::progress {
       
    style default ProgressFrame.TButton -font DlgSmallFont

    option add *ProgressWindow.title   [::msgcat::mc Progress]    widgetDefault

    option add *ProgressFrame.font     DlgDefaultFont             widgetDefault
    option add *ProgressFrame.font2    DlgSmallFont               widgetDefault
    option add *ProgressFrame.font3    DlgSmallFont               widgetDefault 
    option add *ProgressFrame.length   200                        widgetDefault
    option add *ProgressFrame.text     [::msgcat::mc Progress]    widgetDefault
    option add *ProgressFrame.buttonstyle  ProgressFrame.TButton  widgetDefault

    switch -- [tk windowingsystem] {
	aqua {
	    option add *ProgressFrame.padding       {14 4}        widgetDefault
	}
	default {
	    option add *ProgressFrame.padding       {10 4}        widgetDefault
	}
    }
}

# ui::progress::container --
# 
#       Toplevel progress dialog that can contain many progressframes.

snit::widget ui::progress::container {
    hulltype toplevel
    widgetclass ProgressMulti

    variable uid 0
    
    option -geovariable
    option -title        -configuremethod OnConfigTitle
    
    constructor {args} {
	$self configurelist $args
	if {[tk windowingsystem] eq "aqua"} {
	    ::tk::unsupported::MacWindowStyle style $win document \
	      {collapseBox verticalZoom}
	}
	wm title $win $options(-title)
	wm withdraw $win
	if {[string length $options(-geovariable)]} {
	    ui::PositionWindow $win $options(-geovariable)
	}	
	return
    }
    
    # Private methods:

    method OnConfigTitle {option value} {
	wm title $win $value
	set options($option) $value
    }
    
    # Public methods:
    
    method add {args} {
	if {![llength [grid slaves $win]]} {
	    set wframe $win.p[incr uid]
	    eval {ui::progress::frame $wframe} $args	
	    grid  $wframe   -sticky ew
	} else {
	    set wframe $win.p[incr uid]
	    set wsep   $win.s$uid
	    ttk::separator $wsep -orient horizontal
	    eval {ui::progress::frame $wframe} $args	
	    grid  $wsep    -sticky ew
	    grid  $wframe  -sticky ew
	}
	if {[llength [grid slaves $win]] == 1} {
	    after idle [list wm deiconify $win]
	}
	return $wframe
    }
    
    method remove {wframe} {
	set wtop [winfo toplevel $wframe]
	set num [string range [lindex [split $wframe .] end] 1 end]
	set wsep $wtop.s$num
	if {[winfo exists $wframe]} {
	    destroy $wframe
	}
	if {[winfo exists $wsep]} {
	    destroy $wsep
	}
	if {![llength [grid slaves $wtop]]} {
	    wm withdraw $win
	}
    }
}

# ui::progress::toplevel --
# 
#       Megawidget progress dialog.

snit::widget ui::progress::toplevel {
    hulltype toplevel
    widgetclass ProgressWindow

    delegate option -menu to hull
    delegate option * to frm except {-menu -type -title}
    delegate method * to frm

    option -type
    option -geovariable
    option -title
    
    constructor {args} {
	install frm using ui::progress::frame $win.frm

	$self configurelist $args
	if {[tk windowingsystem] eq "aqua"} {
	    ::tk::unsupported::MacWindowStyle style $win document \
	      {collapseBox verticalZoom}
	} else {
	    $win configure -menu ""
	}
	wm title $win $options(-title)
	
	grid  $win.frm  -sticky ew
	if {[string length $options(-geovariable)]} {
	    ui::PositionClassWindow $win $options(-geovariable) "ProgressWindow"
	}	
	return
    }
}

# ui::progress::frame --
# 
#       Megawidget progress frame.

snit::widgetadaptor ui::progress::frame {
	
    # If > 0 it is timer millisecs.
    typevariable heartbeat 1000
    typevariable heartbeatid
        
    variable configDelayed
    
    # @@@ Could add full option specs.
    delegate option -padding to hull
    delegate option -font    to lbl
    delegate option -text    to lbl
    delegate option -font2   to lbl2 as -font
    delegate option -text2   to lbl2 as -text
    delegate option -font3   to lbl3 as -font
    delegate option -text3   to lbl3 as -text
    delegate option -length  to prg
    delegate option -buttonstyle   to bt  as -style
    delegate option -cancelcommand to bt  as -command

    option -pausecommand                    \
      -configuremethod OnConfigPauseCmd
    option -percent -default 0              \
      -configuremethod OnConfigSetPercent   \
      -validatemethod  ValidPercent
	    
    constructor {args} {
	installhull using ttk::frame -class ProgressFrame
	
	install lbl  using ttk::label  $win.lbl
	install lbl2 using ttk::label  $win.lbl2
	install lbl3 using ttk::label  $win.lbl3
	install bt   using ttk::button $win.bt   -text [::msgcat::mc Cancel]
	install prg  using ttk::progressbar $win.prg  \
	  -orient horizontal -maximum 100

	grid  $win.lbl   -        -pady 4 -sticky w
	grid  $win.prg   $win.bt  -padx 4 -pady 0
	grid  $win.lbl2  -        -pady 0 -sticky w
	grid  $win.lbl3  -        -pady 0 -sticky w
	grid columnconfigure $win 0 -weight 1
	
	if {$heartbeat} {
	    if {[llength [ui::progress::frame info instances]] == 1} {
		set heartbeatid [after $heartbeat [mytypemethod Beat]]
	    }
	}
		
	$self configurelist $args
	return
    }
        
    typemethod Beat {} {
	set instances [ui::progress::frame info instances]
	if {[llength $instances]} {
	    foreach w $instances {
		$w Update
	    }
	    set heartbeatid [after $heartbeat [mytypemethod Beat]]
	}
    }
    
    method Update {} {
	if {[array size configDelayed]} {
	    eval {$self configure} [array get configDelayed]
	}
    }

    method ValidPercent {option value} {
	set str "expected a number 0-100, but got \"$value\""
	if {![string is double -strict $value]} {
	    return -code error $str
	} 
	if {($value < 0) || ($value > 100)} {
	    return -code error $str
	}	
    }
    
    method OnConfigSetPercent {option value} {
	
	# Provide default subtext.
	if {0} {
	    set str [::msgcat::mc Remaining]
	    append str ": "
	    append str [expr {100 - int($value + 0.5)}]
	    append str "%"
	    $win.lbl2 configure -text $str
	}
	$win.prg configure -value $value
	set options($option) $value
    }
    
    method OnConfigPauseCmd {option value} {
	
	set options($option) $value
    }
    
    # Public methods:

    typemethod heartbeat {millis} {
	set heartbeat $millis
    }
    
    method configuredelayed {args} {
	array set configDelayed $args
    }
}

#-------------------------------------------------------------------------------
