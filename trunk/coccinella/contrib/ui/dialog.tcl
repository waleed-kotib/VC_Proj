# dialog.tcl --
# 
#       Flexible dialog box.
#       Some code from ttk::dialog.
#
# Copyright (c) 2005 Mats Bengtsson
#       
# $Id: dialog.tcl,v 1.3 2005-09-21 09:53:23 matben Exp $

package require snit 1.0
package require tile
package require msgcat
package require ui::util

package provide ui::dialog 0.1

namespace eval ui::dialog {

    variable dialogTypes	;# map -type => list of dialog options
    variable buttonOptions	;# map button name => list of button options

    variable images
    set images(names) {}
    
    option add *Dialog.f.t.message.wrapLength      300            widgetDefault
    option add *Dialog.f.t.detail.wrapLength       300            widgetDefault
    option add *Dialog.f.t.message.font            DlgDefaultFont widgetDefault
    option add *Dialog.f.t.detail.font             DlgSmallFont   widgetDefault
    
    switch -- [tk windowingsystem] {
	aqua {
	    option add *Dialog.f.padding           {20 15 20 16}  widgetDefault
	    option add *Dialog.f.t.message.padding { 0  0  0  6}  widgetDefault
	    option add *Dialog.f.t.detail.padding  { 0  0  0  8}  widgetDefault
	    option add *Dialog.f.t.icon.padding    { 0  0 16  0}  widgetDefault
	    option add *Dialog.f.t.client.padding  { 0  0  0  8}  widgetDefault
	    option add *Dialog.buttonAnchor        e              widgetDefault
	    option add *Dialog.buttonOrder         "cancelok"     widgetDefault
	    option add *Dialog.buttonPadX          8              widgetDefault
	}
	win32 {
	    option add *Dialog.f.padding           {12  6}        widgetDefault
	    option add *Dialog.f.t.message.padding { 0  0  0  4}  widgetDefault
	    option add *Dialog.f.t.detail.padding  { 0  0  0  6}  widgetDefault
	    option add *Dialog.f.t.icon.padding    { 0  0  8  0}  widgetDefault
	    option add *Dialog.buttonAnchor        center         widgetDefault
	    option add *Dialog.buttonOrder         "okcancel"     widgetDefault
	    option add *Dialog.buttonPadX          4              widgetDefault
	}
	x11 {
	    option add *Dialog.f.padding           {12  6}        widgetDefault
	    option add *Dialog.f.t.message.padding { 0  0  0  4}  widgetDefault
	    option add *Dialog.f.t.detail.padding  { 0  0  0  6}  widgetDefault
	    option add *Dialog.f.t.icon.padding    { 0  0  8  0}  widgetDefault
	    option add *Dialog.buttonAnchor        e              widgetDefault
	    option add *Dialog.buttonOrder         "okcancel"     widgetDefault
	    option add *Dialog.buttonPadX          4              widgetDefault
	}
    }    
}
if {0} {
    package require Img
    
    set f "/Users/matben/Graphics/Crystal Clear/64x64/actions/info.png"
    set im [image create photo -file $f]
    ui::dialog::setimage info $im

    set f "/Users/matben/Graphics/Crystal Clear/64x64/actions/stop.png"
    set im [image create photo -file $f]
    ui::dialog::setimage error $im

    set f "/Users/matben/Graphics/Crystal Clear/64x64/apps/miscellaneous2.png"
    set im [image create photo -file $f]
    ui::dialog::setimage question $im

    set f "/Users/matben/Graphics/Crystal Clear/64x64/apps/important.png"
    set im [image create photo -file $f]
    ui::dialog::setimage warning $im
    
    set f "/Users/matben/Tcl/cvs/coccinella/images/Coccinella.png"
    set im [image create photo -file $f]
    ui::dialog::setbadge $im
    
    ui::dialog .d -message "These two must be able to call before any dialog instance created." \
      -detail "These two must be able to call before any dialog instance created."
    ui::dialog .d2 -message "These two must be able to call before any dialog instance created." \
      -detail "These two must be able to call before any dialog instance created." \
      -icon error -buttons {yes no cancel} -default yes
    ui::dialog .d3 -message "These two must be able to call before any dialog instance created." \
      -detail "These two must be able to call before any dialog instance created." \
      -icon error -type yesnocancel

    proc cmd {w bt} {
	destroy $w
	tk_getSaveFile
    }
    ui::dialog .d4 -message "Check destroy from -command" -command cmd
}

# These two must be able to call before any dialog instance created.
# We always take copies to be on the safe side.

proc ui::dialog::setimage {name image} {
    variable images

    # Garbage collection.
    if {[info exists images($name)]} {
	image delete $images($name)
    }
    set new [image create photo]
    $new blank
    $new copy $image
    set images($name) $new
    lappend images(names) $name
    set images(names) [lsort -unique $images(names)]
    
    # Badge?
    CreateBadgeImage $name
}

proc ui::dialog::setbadge {badge} {
    variable images

    # Garbage collection.
    if {[info exists images(badge)]} {
	image delete $images(badge)
    }
    set new [image create photo]
    $new blank
    set W [image width $badge]
    set H [image height $badge]
    if {$W > 32 || $H > 32} {
	
	# Find common scale factor so that smaller than 32x32.
	set fW [expr {1 + ($W - 1)/32}]
	set fH [expr {1 + ($H - 1)/32}]
	set factor [expr {$fW > $fH ? $fW : $fH}]	
	$new copy $badge -subsample $factor
    } else {
	$new copy $badge
    }
    set images(badge) $new
    
    # Badge all icons.
    foreach name $images(names) {
	CreateBadgeImage $name
    }
}

proc ui::dialog::CreateBadgeImage {name} {
    variable images
    if {[info exists images(badge)]} {
	if {[info exists images($name,badge)]} {
	    image delete $images($name,badge)
	}
	set new [image create photo]
	$new blank
	$new copy $images($name)
	BadgeImage $new
	set images($name,badge) $new
    }
}

proc ui::dialog::BadgeImage {image} {
    variable images
    set badge $images(badge)
    set x [expr {[image width $image]  - [image width $badge]}]
    set y [expr {[image height $image] - [image height $badge]}]
    $image copy $badge -to $x $y
}

proc ui::dialog::Nop {args} { }

interp alias {} ui::dialog {} ui::dialog::widget

snit::widget ui::dialog::widget {
    hulltype toplevel
    widgetclass Dialog
    
    typevariable dialogTypes	;# map -type => list of dialog options
    typevariable buttonOptions	;# map button name => list of button options

    variable client
    
    delegate option -message to message as -text
    delegate option -detail  to detail  as -text

    option -command                   \
      -default ui::dialog::Nop
    option -geovariable
    option -type                      \
      -validatemethod ValidateType    \
      -default ok
    option -title                     \
      -configuremethod OnConfigTitle
    option -buttons     {ok}
    option -default     {}
    option -cancel      {}
    option -default     {}
    option -icon                      \
      -default info                   \
      -validatemethod ValidateIcon
    
    typeconstructor {

	# Built-in button types:
	#
	StockButton ok 	   -text [::msgcat::mc OK]
	StockButton cancel -text [::msgcat::mc Cancel]
	StockButton yes	   -text [::msgcat::mc Yes]
	StockButton no	   -text [::msgcat::mc No]
	StockButton retry  -text [::msgcat::mc Retry]

	# Built-in dialog types:
	#
	StockDialog ok \
	  -icon info -buttons {ok} -default ok
	StockDialog okcancel \
	  -icon info -buttons {ok cancel} -default ok -cancel cancel
	StockDialog retrycancel \
	  -icon question -buttons {retry cancel} -cancel cancel
	StockDialog yesno \
	  -icon question -buttons {yes no}
	StockDialog yesnocancel \
	  -icon question -buttons {yes no cancel} -cancel cancel
    }

    constructor {args} {
	upvar ::ui::dialog::images images
	
	set f $win.f
	set top $f.t
	install f using ttk::frame $win.f -class Dialog
	ttk::frame $top
	install message using ttk::label $top.message -anchor w -justify left
	install detail  using ttk::label $top.detail  -anchor w -justify left
	
	# Trick to let individual options override -type ones.
	set dlgtype ok
	if {[set idx [lsearch $args -type]] >= 0} {
	    set dlgtype [lindex $args [incr idx]]
	}
	if {[info exists dialogTypes($dlgtype)]} {
	    array set options $dialogTypes($dlgtype)
	}
	$self configurelist $args	
	
	if {[tk windowingsystem] eq "aqua"} {
	    ::tk::unsupported::MacWindowStyle style $win document none
	}
	wm title $win $options(-title)
	set wraplength [$top.message cget -wraplength]
	
	set icon $options(-icon)
	if {[info exists images($icon,badge)]} {
	    set im $images($icon,badge)
	} else {
	    set im $images($icon)
	}
	ttk::label $top.icon -image $im
	
	grid $top.icon    -column 0 -row 0 -rowspan 2 -sticky n
	grid $top.message -column 1 -row 0 -sticky nw
	grid $top.detail  -column 1 -row 1 -sticky nw
	grid columnconfigure $top 0 -minsize 64
	grid columnconfigure $top 1 -minsize $wraplength

	set client $top.client
	set bottom $f.b
	ttk::frame $f.b
	
	set buttons $options(-buttons)
	if {[option get $win buttonOrder {}] eq "cancelok"} {
	    set buttons {}
	    foreach b $options(-buttons) {
		set buttons [linsert $buttons 0 $b]
	    }
	}
	set column 0
	set padx [option get $win buttonPadX {}]
	
	foreach bt $buttons {
	    
	    # Using -padx wont work here due to -uniform
	    incr column
	    eval [linsert $buttonOptions($bt) 0 ttk::button $bottom.$bt]
	    $bottom.$bt configure -command [list $self Done $bt]
	    grid $bottom.$bt -row 0 -column $column -sticky ew
	    grid columnconfigure $bottom $column -uniform buttons
	    if {$bt ne [lindex $buttons end]} {
		incr column
		ttk::frame $bottom.$column
		grid columnconfigure $bottom $column -minsize $padx
	    }
	}

	if {$options(-default) ne ""} {
	    bind $win <KeyPress-Return> \
	      [list event generate $bottom.$options(-default) <<Invoke>>]
	    focus $bottom.$options(-default)
	}
	if {$options(-cancel) ne ""} {
	    bind $win <KeyPress-Escape> \
	      [list event generate $bottom.$options(-cancel) <<Invoke>>]
	}

	pack $f
	pack $top    -side top
	pack $bottom -side bottom -anchor [option get $win buttonAnchor {}]
	
	if {[string length $options(-geovariable)]} {
	    ui::PositionWindow $win $options(-geovariable)
	}	
	return
    }
    
    destructor {
	if {$options(-cancel) ne ""} {
	    $self Done $options(-cancel)
	}
    }

    # StockButton -- define new built-in button
    #
    proc StockButton {button args} {
	set buttonOptions($button) $args
    }

    # StockDialog -- define new dialog type.
    #
    proc StockDialog {dlgtype args} {
	set dialogTypes($dlgtype) $args
    }
    
    # Private methods:
    
    method OnConfigTitle {option value} {
	wm title $win $value
	set options($option) $value
    }
    
    method ValidateType {option value} {
	if {![info exists dialogTypes($value)]} {
	    set valid [join [lsort [array names dialogTypes]] ", "]
	    return -code error "unrecognized type $value, must be one of $valid"
	}
    }
    
    method ValidateIcon {option value} {
	upvar ::ui::dialog::images images
	if {![info exists images($value)]} {
	    set valid [join $images(names) ", "]
	    return -code error "unrecognized icon $value, must be one of $valid"
	}
    }
	
    method Done {button} {
	set rc [catch [linsert $options(-command) end $win $button] result]
	if {$rc == 1} {
	    return -code $rc -errorinfo $::errorInfo -errorcode $::errorCode $result
	} elseif {$rc == 3 || $rc == 4} {
	    # break or continue -- don't dismiss dialog
	    return
	} 
	
	# We can have been destroyed already!
	if {[lsearch [ui::dialog::widget info instances] $win] >= 0} {
	    $self Dismiss
	}
    }
    
    method Dismiss {} {
	destroy $win
    }
    
    # Public methods:
    
    method clientframe {} { 
	if {![winfo exists $client]} {
	    ttk::frame $client
	    grid $client -column 1 -row 2 -sticky news
	    lower $client	;# so it's first in keyboard traversal order
	}
	return $client 
    }

    method grab {} {
	ui::Grab $win
    }
}

#-------------------------------------------------------------------------------
