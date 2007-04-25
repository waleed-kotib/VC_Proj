# TSearch.tcl
#
#       Megawidget for searching a TreeCtrl widget.
#       
# Copyright (c) 2007 Mats Bengtsson
#       
# $Id: TSearch.tcl,v 1.1 2007-04-25 14:06:59 matben Exp $

package require snit 1.0
package require tileutils 0.1

package provide UI::TSearch 1.0

namespace eval UI::TSearch {
    
}

interp alias {} UI::TSearch    {} UI::TSearch::widget

# UI::TSearch --
# 
#       Search treectrl megawidget.

snit::widgetadaptor UI::TSearch::widget {
    
    variable wtree
    variable wentry
    variable wnext
    variable column
    variable string      {}
    variable itemCurrent {}
    variable itemsFound  {}
    
    delegate method * to hull
    delegate option * to hull 

    constructor {_wtree _column args} {
	
	set wtree $_wtree
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
	ttk::button $win.next -style Small.Url -command [list $self Next] \
	  -text [mc Next] -takefocus 0
	
	grid  $win.close  $win.find  $win.entry  $win.next
	grid $win.entry -sticky ew
	grid $win.next -padx 4
	grid columnconfigure $win 2 -weight 1
	
	$wnext state {disabled}
	focus $wentry
	trace add variable [myvar string] write [list $self Trace]	
	bind $wentry <Return> [list $self Find]
	
	return
    }
    
    destructor {
	trace remove variable [myvar string] write [list $self Trace]
    }

    method Trace {name1 name2 op} {
	$self Event
    }

    method Event {} {
	
	# Reset search state.
	$wtree selection clear
	$wentry state {!invalid}
	set itemsFound [list]
	set itemCurrent {}
    }
    
    method Hit {item} {
	set itemCurrent $item
	$wtree selection clear
	$wtree selection add $itemCurrent
	$wtree see $itemCurrent
	set ancestors [$wtree item ancestors $itemCurrent]
	puts "ancestors=$ancestors"
	
    }
    
    method Find {} {
	$wtree selection clear
	set itemL [list]
	set itemsFound [list]
	if {[string length $string]} {
	    set lstring [string tolower $string]
	    foreach item [$wtree item descendants root] {
		set text [$wtree item text $item $column]
		if {[string match *${lstring}* [string tolower $text]]} {
		    lappend itemL $item
		}
	    }
	}
	set itemsFound $itemL
	set len [llength $itemL]
	if {$len > 1} {
	    $wnext state {!disabled}
	} elseif {!$len} {
	    $wentry state {invalid}
	}
	if {$len} {
	    $self Hit [lindex $itemL 0]
	} else {
	    set itemCurrent {}
	}
	puts "itemL=$itemL"
    }

    method Next {} {
	$wtree selection clear
	set ind [lsearch $itemsFound $itemCurrent]
	if {$ind >= 0} {
	    if {[expr {$ind+1}] == [llength $itemsFound]} {
		set ind 0
	    } else {
		incr ind
	    }
	    $self Hit [lindex $itemsFound $ind]
	}
    }

    method Previous {} {
	$wtree selection clear
	set ind [lsearch $itemsFound $itemCurrent]
	if {$ind >= 0} {
	    if {$ind == 0} {
		set ind [expr {[llength $itemsFound] - 1}]
	    } else {
		incr ind -1
	    }
	    $self Hit [lindex $itemsFound $ind]
	}
    }
    
    method Close {} {
	destroy $win
    }
}
    
