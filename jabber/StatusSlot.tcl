#  StatusSlot.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements a plain status slot.
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
# $Id: StatusSlot.tcl,v 1.7 2008-09-13 22:11:26 sdevrieze Exp $

package provide StatusSlot 1.0

namespace eval ::StatusSlot {
    
    option add *StatusSlot.padding       {4 2 2 2}     50
    option add *StatusSlot.box.padding   {8 2 8 2}     50
    option add *StatusSlot*TEntry.font   CociSmallFont widgetDefault
    
    variable msgSlotD
    dict set msgSlotD mejid    [mc "Own Contact ID"]
    dict set msgSlotD mejidres [mc "Own Full Contact ID"]
    dict set msgSlotD server   [mc Server]
    dict set msgSlotD status   [mc Status]

    ::JUI::SlotRegister plainstatus [namespace code BuildMessageSlot]
}

proc ::StatusSlot::BuildMessageSlot {w} {
    variable slot
    variable msgSlotD
    
    ttk::frame $w -class StatusSlot
    
    if {1} {
	set slot(collapse) 0
	ttk::checkbutton $w.arrow -style Arrow.TCheckbutton \
	  -command [list [namespace current]::Collapse $w] \
	  -variable [namespace current]::slot(collapse)
	pack $w.arrow -side left -anchor n	
	bind $w       <<ButtonPopup>> [list [namespace current]::Popup $w %x %y]
	bind $w.arrow <<ButtonPopup>> [list [namespace current]::Popup $w %x %y]

	set im  [::Theme::FindIconSize 16 close-aqua]
	set ima [::Theme::FindIconSize 16 close-aqua-active]
	ttk::button $w.close -style Plain  \
	  -image [list $im active $ima] -compound image  \
	  -command [namespace code [list Close $w]]
	pack $w.close -side right -anchor n	

	::balloonhelp::balloonforwindow $w.arrow [mc "Right click to open menu"]
        ::balloonhelp::balloonforwindow $w.close [mc "Close Slot"]
    }    
    set box $w.box
    ttk::frame $box
    pack $box -fill x -expand 1
    
    ttk::label $box.e -style Small.Sunken.TLabel \
      -textvariable ::Jabber::jstate(mejid) -anchor w
    
    grid  $box.e  -sticky ew
    grid columnconfigure $box 0 -weight 1
    
    set slot(box)   $w.box
    set slot(value) mejid
    set slot(show)  0

    bind $box   <<ButtonPopup>> [list [namespace current]::Popup $w %x %y]
    bind $box.e <<ButtonPopup>> [list [namespace current]::Popup $w %x %y]
    ::balloonhelp::balloonforwindow $box.e [dict get $msgSlotD mejid]

    foreach m [::JUI::SlotGetAllMenus] {
	$m add checkbutton -label [mc "Status Info"] \
	  -variable [namespace current]::slot(show) \
	  -command [namespace code Cmd]
    }
    if {[::JUI::SlotPrefsMapped plainstatus]} {
	::JUI::SlotShow plainstatus
	set slot(show) 1
    }
    return $w
}

proc ::StatusSlot::Cmd {} {
    if {[::JUI::SlotShowed plainstatus]} {
	::JUI::SlotClose plainstatus
    } else {
	::JUI::SlotShow plainstatus
    }
}

proc ::StatusSlot::Collapse {w} {
    variable slot

    if {$slot(collapse)} {
	pack forget $slot(box)
    } else {
	pack $slot(box) -fill both -expand 1
    }
    #event generate $w <<Xxx>>
}

proc ::StatusSlot::Popup {w x y} {
    variable msgSlotD
    
    set m $w.m
    destroy $m
    menu $m -tearoff 0
    
    # NB: The value is the array index of the jstate array having this info.
    dict for {value label} $msgSlotD {
	$m add radiobutton -label $label \
	  -variable [namespace current]::slot(value) -value $value \
	  -command [namespace code [list MenuCmd $w $value]]
    }
    update idletasks
    
    set X [expr [winfo rootx $w] + $x]
    set Y [expr [winfo rooty $w] + $y]
    tk_popup $m [expr {int($X) - 0}] [expr {int($Y) - 0}]   
    
    return -code break
}

proc ::StatusSlot::MenuCmd {w value} {
    variable slot
    variable msgSlotD

    $slot(box).e configure -textvariable ::Jabber::jstate($value)
    ::balloonhelp::balloonforwindow $slot(box).e [dict get $msgSlotD $value]
}

proc ::StatusSlot::Close {w} {
    variable slot
    set slot(show) 0
    ::JUI::SlotClose plainstatus
}
