# fontselector.tcl --
# 
#       Megawidget font selector.
# 
# Copyright (c) 2005 Mats Bengtsson
#       
# $Id: fontselector.tcl,v 1.2 2005-09-20 14:09:51 matben Exp $

package require snit 1.0
package require tile
package require msgcat
package require ui::util

package provide ui::fontselector 0.1

namespace eval ui::fontselector {

    set str   "Hello cruel World!"
    set title [::msgcat::mc {Select Font}]

    option add *FontSelector.text             $str                widgetDefault
    option add *FontSelector.title            $title              widgetDefault
    option add *FontSelector*Listbox.font     TkTooltipFont       widgetDefault

    switch -- [tk windowingsystem] {
	aqua {
	    option add *FontSelector.buttonOrder   "cancelok"     widgetDefault
	    option add *FontSelector.buttonPadX    12             widgetDefault
	    option add *FontSelector.padding       {20 14 20 20}  widgetDefault
	}
	default {
	    option add *FontSelector.buttonOrder   "okcancel"     widgetDefault
	    option add *FontSelector.buttonPadX    6              widgetDefault
	    option add *FontSelector.padding       {6 8 6 8}      widgetDefault
	}
    }
}

interp alias {} ui::fontselector {} ui::fontselector::widget

# ui::fontselector --
# 
#       Megawidget font selector.

snit::widget ui::fontselector::widget {
    hulltype toplevel
    widgetclass FontSelector
    
    set str     "Hello cruel World!"
    set defFont {Helvetica 12 normal}

    typevariable families {}
    
    variable family   Helvetica
    variable size     12
    variable weight   normal
    variable wlistbox
    variable wcanvas
    variable wdefault
    
    delegate option -menu    to hull
    delegate option -padding to frm

    option -defaultfont  -default $defFont -configuremethod OnConfigDefaultFont
    option -selectfont   -default $defFont
    option -text         -default $str     -configuremethod OnConfigText
    option -geovariable
    option -command
    option -title        -configuremethod OnConfigTitle

    typeconstructor {
	# Do this only once since expensive!
	set families [font families]
    }
    
    constructor {args} {
	install frm using ttk::frame $win.frm -class FontSelector
	
	$self configurelist $args

	wm withdraw $win
	if {[tk windowingsystem] eq "aqua"} {
	    ::tk::unsupported::MacWindowStyle style $win document closeBox
	} else {
	    $win configure -menu ""
	}
	wm title $win $options(-title)

	pack $win.frm -fill both -expand 1

	# Top frame.
	set wtop $win.frm.top
	ttk::frame $wtop
	pack  $wtop  -side top -fill x

	set frfont $wtop.font
	ttk::frame $frfont
	pack  $frfont  -side left -fill y
	
	set wlistbox $frfont.lb
	set ysc $frfont.ysc
	listbox $wlistbox -width 28 -height 10  \
	  -yscrollcommand [list $ysc set]  \
	  -listvariable [mytypevar families]
	scrollbar $ysc -orient vertical -command [list $wlistbox yview]
	pack  $wlistbox  $ysc  -side left -fill y
	
	# Font size, weight etc.
	set frprop $wtop.prop
	ttk::frame $frprop -padding {12 0 0 0}
	pack  $frprop  -side top -fill y

	ttk::label    $frprop.lsize -text "[::msgcat::mc {Font Size}]:"
	ttk::combobox $frprop.csize -width 8  \
	  -textvariable [myvar size]  \
	  -values {9 10 12 14 16 18 24 36 48 60 72}
	ttk::separator $frprop.s -orient horizontal

	grid  $frprop.lsize  -sticky w
	grid  $frprop.csize  -sticky ew
	grid  $frprop.s      -sticky ew -pady 12

	ttk::label    $frprop.lwe -text "[::msgcat::mc {Font Weight}]:"
	ttk::combobox $frprop.cwe -width 10  \
	  -textvariable [myvar weight] -state readonly \
	  -values {normal bold italic}

	grid  $frprop.lwe  -sticky w
	grid  $frprop.cwe  -sticky ew

	bind $frprop.csize <<ComboboxSelected>> [list $self Select]
	bind $frprop.cwe   <<ComboboxSelected>> [list $self Select]

	# Font text.
	set frmid  $win.frm.frmid
	ttk::frame $frmid
	set wcanvas $frmid.can
	canvas $wcanvas -width 200 -height 48 \
	  -highlightthickness 0 -border 1 -relief sunken -bg white
	pack  $frmid      -side top -fill both -expand 1 -pady 16
	pack  $frmid.can  -fill both -expand 1

	# Button part.
	set frbot  $win.frm.b
	ttk::frame $frbot
	ttk::button $frbot.btset -text [::msgcat::mc Select] -default active  \
	  -command [list $self OK]
	ttk::button $frbot.btcancel -text [::msgcat::mc Cancel]  \
	  -command [list $self Cancel]
	ttk::button $frbot.btdef -text [::msgcat::mc Default]  \
	  -command [list $self Default]
	set padx [option get $win buttonPadX {}]
	if {[option get $win buttonOrder {}] eq "cancelok"} {
	    pack  $frbot.btset     -side right
	    pack  $frbot.btcancel  -side right -padx $padx
	} else {
	    pack  $frbot.btcancel  -side right
	    pack  $frbot.btset     -side right -padx $padx
	}
	pack  $frbot.btdef  -side left
	pack  $frbot        -side top -fill x
	
	set wdefault $frbot.btdef
	
	bind $wlistbox <<ListboxSelect>> [list $self ListboxSelect]
	bind $wlistbox <Button-1>        {+focus %W }
	bind $win      <Escape>          [list $self Cancel]

	wm resizable $win 0 0
	
	if {[llength $options(-selectfont)]} {
	    array set farr [font actual $options(-selectfont)]
	    set idx [lsearch $families $farr(-family)]
	    if {$idx < 0} {
		set family "Helvetica"
	    } else {
		set family $farr(-family)
	    }
	    set size   $farr(-size)
	    set weight $farr(-weight)
	    $self Select
	}
	if {[llength $options(-defaultfont)]} {
	    $self Default
	} else {
	    $wdefault state {disabled}
	}
	if {[string length $options(-geovariable)]} {
	    ui::PositionClassWindow $win $options(-geovariable) "FontSelector"
	}
	wm deiconify $win
	return
    }
    
    destructor {
	$self Cancel
    }
    
    # Private methods:
	
    method OnConfigDefaultFont {option value} {
	if {[info exists wdefault]} {
	    if {$value == {}} {
		$wdefault state {disabled}
	    } else {
		$wdefault state {!disabled}
	    }
	}
	set options($option) $value
    }
    
    method OnConfigText {option value} {
	$self Select
	set options($option) $value
    }
    
    method OnConfigTitle {option value} {
	wm title $win $value
	set options($option) $value
    }
    
    method ListboxSelect {} {
	set idx [$wlistbox curselection]
	if {$idx == ""} return
	set family [$wlistbox get $idx]
	$self Select
    }
	
    method Select {} {
	$wcanvas delete all
	$wcanvas create text 6 24 -anchor w \
	  -text $options(-text)             \
	  -font [list $family $size $weight]
    }
    
    method OK {} {
	if {[llength $options(-command)]} {
	    uplevel #0 $options(-command) [list [list $family $size $weight]]
	}
	$self Destroy
    }

    method Cancel {} {
	if {[llength $options(-command)]} {
	    uplevel #0 $options(-command)
	}
	$self Destroy
    }
    
    method Destroy {} {
	if {[string length $options(-geovariable)]} {
	    ui::SaveGeometry $win $options(-geovariable)
	}
	destroy $win
    }
    
    method Default {} {
	array set defaultArr [font actual $options(-defaultfont)]
	set family $defaultArr(-family)
	set size   $defaultArr(-size)
	set weight $defaultArr(-weight)
	$wlistbox selection clear 0 end
	set idx [lsearch $families $family]
	$wlistbox selection set $idx
	$wlistbox see $idx
	$self Select
    }
    
    # Public methods:

    method grab {} {
	ui::Grab $win
    }
}

#-------------------------------------------------------------------------------
