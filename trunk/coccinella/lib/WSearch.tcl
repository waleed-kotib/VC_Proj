# WSearch.tcl
#
#       Megawidget for searching a text widget.
#       
# Copyright (c) 2006 Mats Bengtsson
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
# $Id: WSearch.tcl,v 1.5 2007-07-19 06:28:18 matben Exp $

package require snit 1.0
package require tileutils 0.1

package provide UI::WSearch 1.0

namespace eval UI::WSearch {
    
    option add *WSearch.highlightBackground   yellow
    option add *WSearch.foundBackground       green
}

interp alias {} UI::WSearch    {} UI::WSearch::widget

# UI::WSearch --
# 
#       Search text megawidget.

snit::widgetadaptor UI::WSearch::widget {
    
    variable wtext
    variable wentry
    variable wnext
    variable idxs     {}
    variable idxfocus {}
    variable string   {}
    
    delegate method * to hull
    delegate option * to hull 

    constructor {_wtext args} {
	
	set wtext $_wtext
	set wentry $win.entry
	set wnext $win.next

	installhull using ttk::frame -class WSearch
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
	ttk::button $win.next -style Small.TButton -command [list $self Next] \
	  -text [mc Next]
	
	grid  $win.close  $win.find  $win.entry  $win.next
	grid $win.entry -sticky ew
	grid $win.next -padx 4
	grid columnconfigure $win 2 -weight 1
	
	$wnext state {disabled}
	
	set hbg [option get $win highlightBackground {}]
	set fbg [option get $win foundBackground {}]
	
	if {[lsearch [$wtext tag names] thighlight] < 0} {
	    $wtext tag configure thighlight -background $hbg
	}
	if {[lsearch [$wtext tag names] tfound] < 0} {
	    $wtext tag configure tfound -background $fbg
	}
	focus $wentry
	trace add variable [myvar string] write [list $self Trace]
	
	return
    }
    
    destructor {
	trace remove variable [myvar string] write [list $self Trace]
	if {[winfo exists $wtext]} {
	    $wtext tag remove thighlight 1.0 end
	    $wtext tag remove tfound 1.0 end
	}
    }
    
    method Trace {name1 name2 op} {
	$self Event
    }

    method Event {} {
	$wtext tag remove thighlight 1.0 end
	$wtext tag remove tfound 1.0 end
	set idxs [$self FindAll]
	set idx0 [lindex $idxs 0]
	if {$idxs eq {}} {
	    $wentry state {invalid}
	} else {
	    $wentry state {!invalid}
	    $wtext see [lindex $idxs 0]
	    set len [string length $string]
	    foreach idx $idxs {
		$wtext tag add thighlight $idx "$idx + $len chars"
	    }
	    $wtext tag add tfound $idx0 "$idx0 + $len chars"
	}
	if {[llength $idxs] > 1} {
	    $wnext state {!disabled}
	} else {
	    $wnext state {disabled}
	}
	set idxfocus $idx0
    }
    
    method FindAll {} {
	set idxs {}
	set len [string length $string]
	set idx [$wtext search -nocase $string 1.0]
	if {$idx ne ""} {
	    set first $idx
	    lappend idxs $idx
	    while {[set idx [$wtext search -nocase $string "$idx + $len chars"]] ne $first} {
		lappend idxs $idx
	    }
	}
	return $idxs
    }

    method Next {} {
	$wtext tag remove tfound 1.0 end
	set ind [lsearch $idxs $idxfocus]
	if {$ind >= 0} {
	    if {[expr {$ind+1}] == [llength $idxs]} {
		set ind 0
	    } else {
		incr ind
	    }
	    set idxfocus [lindex $idxs $ind]
	    set len [string length $string]
	    $wtext tag add tfound $idxfocus "$idxfocus + $len chars"
	    $wtext see $idxfocus
	}
    }

    method Previous {} {
	$wtext tag remove tfound 1.0 end
	set ind [lsearch $idxs $idxfocus]
	if {$ind >= 0} {
	    if {$ind == 0} {
		set ind [expr {[llength $idxs] - 1}]
	    } else {
		incr ind -1
	    }
	    set idxfocus [lindex $idxs $ind]
	    set len [string length $string]
	    $wtext tag add tfound $idxfocus "$idxfocus + $len chars"
	    $wtext see $idxfocus
	}
    }
    
    method Close {} {
	destroy $win
    }
}
    
