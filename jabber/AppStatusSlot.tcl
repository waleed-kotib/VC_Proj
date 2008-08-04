#  AppStatusSlot.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements an application status slot.
#      
#  Copyright (c) 2008  Mats Bengtsson
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
# $Id: AppStatusSlot.tcl,v 1.1 2008-08-04 13:05:28 matben Exp $

package provide AppStatusSlot 1.0

namespace eval ::AppStatusSlot {
    
    option add *AppStatusSlot.padding       {4 2 2 2}     50
    option add *AppStatusSlot.box.padding   {8 2 8 2}     50
    option add *AppStatusSlot*TEntry.font   CociSmallFont widgetDefault
    
    ::JUI::SlotRegister appstatus [namespace code Build]

    ::hooks::register highLoginStartHook   [namespace code HighLoginStartHook]
    ::hooks::register highLoginCBHook      [namespace code HighLoginCBHook]
    ::hooks::register appStatusMessageHook [namespace code MsgHook]
}

proc ::AppStatusSlot::Build {w} {
    variable priv
    
    ttk::frame $w -class AppStatusSlot
    
    if {1} {
	set priv(collapse) 0
	ttk::checkbutton $w.arrow -style Arrow.TCheckbutton \
	  -command [list [namespace current]::Collapse $w] \
	  -variable [namespace current]::priv(collapse)
	pack $w.arrow -side left -anchor n	

	set im  [::Theme::FindIconSize 16 close-aqua]
	set ima [::Theme::FindIconSize 16 close-aqua-active]
	ttk::button $w.close -style Plain  \
	  -image [list $im active $ima] -compound image  \
	  -command [namespace code [list Close $w]]
	pack $w.close -side right -anchor n	

	::balloonhelp::balloonforwindow $w.arrow [mc "Right click to get the selector"]
        ::balloonhelp::balloonforwindow $w.close [mc "Close Slot"]
    }    
    set box $w.box
    ttk::frame $box
    pack $box -fill x -expand 1
    
    ::UI::ChaseArrows $box.a
    ttk::label $box.l -style Small.TLabel \
      -textvariable [namespace current]::priv(status) -anchor w
    
    grid  $box.l  $box.a
    grid $box.l -sticky ew
    grid $box.a -sticky e -padx 4
    grid columnconfigure $box 0 -weight 1
    
    set priv(box)    $w.box
    set priv(arrows) $w.box.a
    set priv(show)   1
    set priv(status) [mc mNotAvailable]

    foreach m [::JUI::SlotGetAllMenus] {
	$m add checkbutton -label [mc "Application Status"] \
	  -variable [namespace current]::priv(show) \
	  -command [namespace code Cmd]
    }
    return $w
}

proc ::AppStatusSlot::Cmd {} {
    if {[::JUI::SlotShowed appstatus]} {
	::JUI::SlotClose appstatus
    } else {
	::JUI::SlotShow appstatus
    }
}

proc ::AppStatusSlot::Collapse {w} {
    variable priv

    if {$priv(collapse)} {
	pack forget $priv(box)
    } else {
	pack $priv(box) -fill both -expand 1
    }
}

proc ::AppStatusSlot::HighLoginStartHook {} {
    variable priv
    $priv(arrows) start
}

proc ::AppStatusSlot::HighLoginCBHook {status errcode errmsg} {
    variable priv
    switch -- $status {
	ok - error {
	    $priv(arrows) stop
	}
    }
}

proc ::AppStatusSlot::MsgHook {msg} {
    variable priv
    set priv(status) $msg
}
    
proc ::AppStatusSlot::Close {w} {
    variable priv
    set priv(show) 0
    ::JUI::SlotClose appstatus
}
