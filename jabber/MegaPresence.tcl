#  MegaPresence.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements a mega presence widget.
#      
#  Copyright (c) 2007  Mats Bengtsson
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
# $Id: MegaPresence.tcl,v 1.2 2007-08-11 13:56:29 matben Exp $

package provide MegaPresence 1.0

namespace eval ::MegaPresence {

    option add *MegaPresence.padding       {0 2 0 2}     50
    option add *MegaPresence.box.padding   {0 6 8 4}     50
    option add *MegaPresence*TLabel.style  Small.TLabel  widgetDefault
    
    variable widgets
    set widgets(all) [list]
}

proc ::MegaPresence::Register {name label cmd} {
    variable widgets
    
    set widgets($name,name)  $name
    set widgets($name,label) $label
    set widgets($name,cmd)   $cmd
    lappend widgets(all) $name
    return $name
}

# Test:
if {1} {
    proc MPmake {name win} {
	ttk::menubutton $win -style SunkenMenubutton
	return {}
    }
    foreach name {mood activity tune} {
	::MegaPresence::Register $name [string totitle $name] [list MPmake $name]
    }
}

proc ::MegaPresence::Build {w} {
    global  config
    variable widgets
    
    ttk::frame $w -class MegaPresence
    
    if {1} {
	set widgets(collapse) 0
	ttk::checkbutton $w.arrow -style Arrow.TCheckbutton \
	  -command [list [namespace current]::CollapseCmd $w] \
	  -variable [namespace current]::widgets(collapse)
	pack $w.arrow -side left -anchor n	
	bind $w.arrow <<ButtonPopup>> [list [namespace current]::Popup $w %x %y]
    }    
    set box $w.box
    set widgets(box) $w.box
    ttk::frame $box
    pack $box -fill x -expand 1

    if {$config(ui,status,menu) eq "plain"} {
	::Status::MainButton $box.pres ::Jabber::jstate(show)
    } elseif {$config(ui,status,menu) eq "dynamic"} {
	::Status::ExMainButton $box.pres ::Jabber::jstate(show+status) \
	  -style SunkenMenubutton
    }
    ttk::label $box.lpres -text [mc Status]
    
    grid  $box.pres   -column 0 -row 0
    grid  $box.lpres  -column 0 -row 1
    
    ::AvatarMB::Button $box.avatar
    ttk::label $box.lavatar -text [mc Avatar]
    
    grid  $box.avatar   -column 100 -row 0
    grid  $box.lavatar  -column 100 -row 1
    
    set column 1
    foreach name $widgets(all) {
	set opts [uplevel #0 $widgets($name,cmd) $box.$column]
	eval {grid  $box.$column  -row 0 -column $column} $opts
	ttk::label $box.l$column -text $widgets($name,label)
	grid  $box.l$column  -row 1 -column $column -padx 2 -pady 0
	set widgets($name,column) $column
	set widgets($name,win) $box.$column
	set widgets($name,lwin) $box.l$column
	set widgets($name,display) 1
	incr column
    }
    
    ttk::frame $box.pad
    grid  $box.pad  -column 99 -sticky ew
    grid columnconfigure $box 99 -weight 1
    
    return $w
}

proc ::MegaPresence::CollapseCmd {w} {
    variable widgets

    if {$widgets(collapse)} {
	pack forget $widgets(box)
    } else {
	pack $widgets(box) -fill both -expand 1
    }
    event generate $w <<Xxx>>
}

proc ::MegaPresence::Popup {w x y} {
    variable widgets

    set m $w.m
    destroy $m
    menu $m -tearoff 0
    
    foreach name $widgets(all) {
	$m add checkbutton -label $widgets($name,label) \
	  -command [namespace code [list MenuCmd $w $name]] \
	  -variable [namespace current]::widgets($name,display)
    }
    
    update idletasks
    
    set X [expr [winfo rootx $w] + $x]
    set Y [expr [winfo rooty $w] + $y]
    tk_popup $m [expr {int($X) - 0}] [expr {int($Y) - 0}]   
    
    return -code break
}

proc ::MegaPresence::MenuCmd {w name} {
    variable widgets
    
    if {$widgets($name,display)} {
	set column $widgets($name,column)
	grid  $widgets($name,win)   -row 0 -column $column
	grid  $widgets($name,lwin)  -row 1 -column $column -padx 2 -pady 2
    } else {
	grid forget $widgets($name,win) $widgets($name,lwin)
    }
}


