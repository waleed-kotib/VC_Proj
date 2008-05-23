# TSearch.tcl
#
#       Megawidget for searching a TreeCtrl widget.
#       Guard against dynamic changes in TreeCtrl. Must be 100% bullet proof!
#       
# Copyright (c) 2007 Mats Bengtsson
#  
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#       
# $Id: TSearch.tcl,v 1.8 2008-05-23 14:33:22 matben Exp $

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
    
    option -nextstyle    -default Small.Url
    option -closecommand -default [list]

    constructor {_T _column args} {
	
	set T $_T
	set column $_column
	set wentry $win.entry
	set wnext $win.next

	installhull using ttk::frame -class TSearch
	$self configurelist $args

	set im  [::Theme::FindIconSize 16 close-aqua]
	set ima [::Theme::FindIconSize 16 close-aqua-active]

	ttk::button $win.close -style Plain  \
	  -image [list $im active $ima] -compound image  \
	  -command [list $self Close]
	ttk::label $win.find -style Small.TLabel -padding {4 0 0 0}  \
	  -text "[mc Search]:"
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
	if {[llength $options(-closecommand)]} {
	    uplevel $options(-closecommand)
	} else {
	    destroy $win
	}
    }
}
    
