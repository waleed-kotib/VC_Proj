# TSearch.tcl
#
#       Megawidget for searching a TreeCtrl widget.
#       Guard against dynamic changes in TreeCtrl. Must be 100% bullet proof!
#       
# Copyright (c) 2007 Mats Bengtsson
#       
# $Id: TSearch.tcl,v 1.3 2007-04-27 06:59:27 matben Exp $

package require snit 1.0
package require tileutils

package provide UI::TSearch 1.0

namespace eval UI::TSearch {
    
}

interp alias {} UI::TSearch    {} UI::TSearch::widget

# UI::TSearch --
# 
#       Search treectrl megawidget.

snit::widgetadaptor UI::TSearch::widget {
    
    # Widget paths.
    variable T
    variable wentry
    variable wnext
    # Search column.
    variable column
    # Textvariable string in entry widget.
    variable string      ""
    # Item that is the currently found one.
    variable icurrent     ""
    # List of items from a find operation.
    variable ifound  [list]
    # List of {item isopen ...} for all ancestors of the current item which is
    # needed to restore its ancestors open states when picking next item.
    variable buttonStates [list]
     
    delegate method * to hull
    delegate option * to hull 
    
    option -nextstyle   -default Small.Url

    constructor {_T _column args} {
	
	set T $_T
	set column $_column
	set wentry $win.entry
	set wnext $win.next

	installhull using ttk::frame -class TSearch
	$self configurelist $args

	set subPath [file join images 16]
	set im  [::Theme::GetImage closeAqua $subPath]
	set ima [::Theme::GetImage closeAquaActive $subPath]

	ttk::button $win.close -style Plain  \
	  -image [list $im active $ima] -compound image  \
	  -command [list $self Close]
	ttk::label $win.find -style Small.TLabel -padding {4 0 0 0}  \
	  -text "[mc Find]:"
	ttk::entry $win.entry -style Small.Search.TEntry -font CociSmallFont \
	  -textvariable [myvar string]
	ttk::button $win.next -style $options(-nextstyle) \
	  -command [list $self Next] \
	  -text [mc Next] -takefocus 0
	
	grid  $win.close  $win.find  $win.entry  $win.next
	grid $win.entry -sticky ew
	grid $win.next -padx 4
	grid columnconfigure $win 2 -weight 1
	
	$wnext state {disabled}
	focus $wentry
	trace add variable [myvar string] write [list $self Trace]	

	bind $wentry <Return>        [list $self Find]
	bind $wentry <KeyPress-Up>   [list $self Previous]
	bind $wentry <KeyPress-Down> [list $self Next]
	
	return
    }
    
    destructor {
	trace remove variable [myvar string] write [list $self Trace]
    }

    method Trace {name1 name2 op} {
	$self Reset
    }
    
    method Clear {} {
	set string ""
	$self Reset
    }
    
    # Reset search state.

    method Reset {} {
	$T selection clear
	$wentry state {!invalid}
	$wnext  state {disabled}
	set ifound [list]
	set icurrent ""
	$self SetButtonStates
	set buttonStates [list]
    }
    
    # Selects an item.

    method Hit {item} {
	if {[$T item id $item] ne ""} {
	    $self GetButtonStates $item
	    
	    set icurrent $item
	    $self SeeItem $item
	    $T selection clear
	    $T selection add $icurrent
	}
    }
    
    # Stores a list {item isopen ...} for all ancestors of 'item'.

    method GetButtonStates {item} {
	
	# Get all ancestors, the last one is always the 'root'.
	set ancestors [$T item ancestors $item]
	set openL [list]
	foreach item $ancestors {
	    lappend openL $item [$T item isopen $item]
	}
	set buttonStates $openL
    }
    
    # Uses the current 'buttonStates' list and recreates each ancestors
    # button state.
    
    method SetButtonStates {} {
	foreach {item isopen} $buttonStates {
	    if {[$T item id $item] ne ""} {
		$T item [expr {$isopen ? "expand" : "collapse"}] $item
	    }
	}
    }
    
    method SeeItem {item} {
	foreach aitem [$T item ancestors $item] {
	    $T item expand $aitem
	}
	$T see $item	
    }
    
    method Find {} {
	$T selection clear
	set itemL [list]
	set ifound [list]
	if {[string length $string]} {
	    set lstring [string tolower $string]
	    foreach item [$T item descendants root] {
		set text [$T item text $item $column]
		if {[string match *${lstring}* [string tolower $text]]} {
		    lappend itemL $item
		}
	    }
	}
	set ifound $itemL
	set len [llength $itemL]
	if {$len > 1} {
	    $wnext state {!disabled}
	} elseif {$len == 0} {
	    $wentry state {invalid}
	    $wnext  state {disabled}
	}
	if {$len} {
	    $self Hit [lindex $itemL 0]
	} else {
	    set icurrent ""
	}
    }
    
    method GetNext {} {
	set item [lsearch -inline $ifound $icurrent]
	if {[string length $item]} {
	    if {[$T item id $item] ne "")} {
		return $item
	    } else {
		set idx [lsearch $ifound $icurrent]
		set ifound [lreplace $ifound $idx $idx]
		return ""
	    }
	} else {
	    return ""
	}
    }

    method Next {} {
	$self SetButtonStates
	$T selection clear
	set ind [lsearch $ifound $icurrent]
	if {$ind >= 0} {
	    if {[expr {$ind+1}] == [llength $ifound]} {
		set ind 0
	    } else {
		incr ind
	    }
	    $self Hit [lindex $ifound $ind]
	}
    }

    method Previous {} {
	$self SetButtonStates
	$T selection clear
	set ind [lsearch $ifound $icurrent]
	if {$ind >= 0} {
	    if {$ind == 0} {
		set ind [expr {[llength $ifound] - 1}]
	    } else {
		incr ind -1
	    }
	    $self Hit [lindex $ifound $ind]
	}
    }
    
    method Close {} {
	destroy $win
    }
}
    
