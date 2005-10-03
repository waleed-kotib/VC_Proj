# progress.tcl --
#
#       Progress megawidgets.
#
# Copyright (c) 2005 Mats Bengtsson
#       
# $Id: progress.tcl,v 1.4 2005-10-03 12:49:55 matben Exp $

package require snit 1.0
package require tile
package require msgcat
package require ui::util

package provide ui::progress 0.1

namespace eval ui::progress {
       
    style default TProgressFrame.TButton -font DlgSmallFont

    option add *ProgressWindow.title   [::msgcat::mc Progress]     widgetDefault

    option add *TProgressFrame.font     DlgDefaultFont             widgetDefault
    option add *TProgressFrame.font2    DlgSmallFont               widgetDefault
    option add *TProgressFrame.font3    DlgSmallFont               widgetDefault 
    option add *TProgressFrame.length   200                        widgetDefault
    option add *TProgressFrame.text     [::msgcat::mc Progress]    widgetDefault
    option add *TProgressFrame*TButton.style TProgressFrame.TButton widgetDefault

    option add *ProgressFrame.font      DlgDefaultFont             widgetDefault
    option add *ProgressFrame.font2     DlgSmallFont               widgetDefault
    option add *ProgressFrame.font3     DlgSmallFont               widgetDefault 
    option add *ProgressFrame.length    200                        widgetDefault
    option add *ProgressFrame.text      [::msgcat::mc Progress]    widgetDefault
    option add *ProgressFrame*Button.font DlgSmallFont             widgetDefault

    switch -- [tk windowingsystem] {
	aqua {
	    option add *TProgressFrame.padding       {14 4}        widgetDefault

	    option add *ProgressFrame.padX           14            widgetDefault
	    option add *ProgressFrame.padY            4            widgetDefault
	}
	default {
	    option add *TProgressFrame.padding       {10 4}        widgetDefault

	    option add *ProgressFrame.padX           10            widgetDefault
	    option add *ProgressFrame.padY            4            widgetDefault
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
    variable children {}
    variable wbase
    
    option -geovariable
    option -title        -configuremethod OnConfigTitle
    option -style        -default plain
    
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
	if {$options(-style) eq "tray"} {
	    ttk::frame $win.f -padding 10
	    frame $win.f.f -bd 1 -relief sunken
	    pack $win.f   -expand 1 -fill both
	    pack $win.f.f -expand 1 -fill both
	    set wbase $win.f.f
	} else {
	    set wbase $win
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
	if {$children == {}} {
	    set wframe $wbase.p[incr uid]
	    eval {ui::progress::frame $wframe} $args	
	    grid  $wframe   -sticky ew
	} else {
	    set name p[incr uid]
	    set wframe $wbase.$name
	    set wsep   $wbase.s$name
	    ttk::separator $wsep -orient horizontal
	    eval {ui::progress::frame $wframe} $args	
	    grid  $wsep    -sticky ew
	    grid  $wframe  -sticky ew
	}
	if {$children == {}} {
	    after idle [list wm deiconify $win]
	}
	lappend children $wframe
	return $wframe
    }
    
    method delete {wframe} {
	if {[lsearch $children $wframe] < 0} {
	    return -code error "bad window path name \"$wframe\""
	}
	set name [winfo name $wframe]
	set parent [winfo parent $wframe]
	set wsep $parent.s$name
	destroy $wframe
	if {[winfo exists $wsep]} {
	    destroy $wsep
	}
	
	# If we delete the top frame we must also delete separator *below*.
	set min 100000
	foreach slave [grid slaves $wbase] {
	    array set opts [grid info $slave]
	    if {$opts(-row) < $min} {
		set min $opts(-row)
		set mslave $slave
	    }
	}
	if {[info exists mslave]} {
	    if {[winfo class $mslave] eq "TSeparator"} {
		destroy $mslave
	    }
	}
	set children [lsearch -all -not -inline $children $wframe]
	if {$children == {}} {
	    wm withdraw $win
	}
    }
}

if {0} {
    ui::progress::container .m -style tray
    .m add -percent 22
    .m add -percent 55
    .m add -percent 88    
}

# ui::progress::toplevel --
# 
#       Megawidget progress dialog.

snit::widget ui::progress::toplevel {
    hulltype toplevel
    widgetclass ProgressWindow

    delegate option * to frm except {-menu -title -style}
    delegate option -menu to hull
    delegate method * to frm

    option -geovariable
    option -style "ttk"
    option -title
    
    constructor {args} {
	set style [from args -style "ttk"]
	install frm using ui::progress::frame $win.frm -style $style

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

if {0} {
    option add *ProgressFrame*background  white
    toplevel .t
    ui::progress::frame .t.t -style tk -percent 66
    pack .t.t
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
    #delegate option -padding to hull
    delegate option -font    to lbl
    delegate option -text    to lbl
    delegate option -font2   to lbl2 as -font
    delegate option -text2   to lbl2 as -text
    delegate option -font3   to lbl3 as -font
    delegate option -text3   to lbl3 as -text
    delegate option -length  to prg
    #delegate option -buttonstyle   to bt  as -style
    delegate option -cancelcommand to bt  as -command

    option -pausecommand                    \
      -configuremethod OnConfigPauseCmd
    option -percent -default 0              \
      -configuremethod OnConfigSetPercent   \
      -validatemethod  ValidPercent
    option -style -default "ttk"
	    
    constructor {args} {	
	set style [from args -style "ttk"]
	if {$style eq "ttk"} {
	    installhull using ttk::frame -class TProgressFrame
	    eval {$self TtkConstructor} $args
	} elseif {$style eq "tk"} {
	    installhull using frame -class ProgressFrame
	    eval {$self TkConstructor} $args
	} else {
	    return -code error "unrecognized -style \"$style\""
	}	
	if {$heartbeat} {
	    if {[llength [ui::progress::frame info instances]] == 1} {
		set heartbeatid [after $heartbeat [mytypemethod Beat]]
	    }
	}		
	$self configurelist $args
	return
    }
    
    method TtkConstructor {args} {
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
    }
    
    method TkConstructor {args} {
	install lbl  using label  $win.lbl
	install lbl2 using label  $win.lbl2
	install lbl3 using label  $win.lbl3
	install bt   using button $win.bt   -text [::msgcat::mc Cancel]
	install prg  using ttk::progressbar $win.prg  \
	  -orient horizontal -maximum 100

	grid  $win.lbl   -        -pady 4 -sticky w
	grid  $win.prg   $win.bt  -padx 4 -pady 0
	grid  $win.lbl2  -        -pady 0 -sticky w
	grid  $win.lbl3  -        -pady 0 -sticky w
	grid columnconfigure $win 0 -weight 1
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

if {0} {
    package require ui::progress
    
    ui::progress::toplevel .p1 -percent 66
    ui::progress::toplevel .p2 -percent 44 -style tk
    
}

#-------------------------------------------------------------------------------
