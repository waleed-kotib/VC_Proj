#agents NotifyCall.tcl --
# 
#       NotifyCall is an Dialog Window with Inbound calls notifications 
#
#  Copyright (c) 2007 Mats Bengtsson
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

namespace eval ::NotifyCall { 

    return
    component::define NotifyCall  \
      "Provides support for Incoming Calls Dialog"
}

proc ::NotifyCall::Init {} {
    
    return
    
    component::register NotifyCall

    ::hooks::register jivePhoneEvent		::NotifyCall::JivePhoneEventHook
    ::hooks::register IAXPhoneEvent		::NotifyCall::IAXPhoneEventHook

    #--------------- Variables Uses For SpeedDial Addressbook Tab ----------------
    InitState
}

proc ::NotifyCall::InitState { } {
    variable state
    
    array set state {
	win             .notify
    }
}


#-----------------------------------------------------------------------
#--------------------------- Notify Call Window ------------------------
#-----------------------------------------------------------------------


# NotifyCall::InboundCall  --
# 

proc ::NotifyCall::InboundCall { {phoneNumber ""} } {
    variable state
  
    set win $state(win)

    if { $phoneNumber ne "" } { 
        BuildDialer $win $phoneNumber 
    }
}

# NotifyCall::BuildDialer --
# 
#       A toplevel dialer.
       
proc ::NotifyCall::BuildDialer {w phoneNumber } {
    variable state

    # Make sure only single instance of this dialog.
    if {[winfo exists $w]} {
	raise $w
	return
    }

    ::UI::Toplevel $w -class PhoneNotify \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand ::NotifyCall::CloseDialer

    wm title $w [mc notifyCall]

    ::UI::SetWindowPosition $w


    # Global frame.
    ttk::frame $w.f
    pack  $w.f  -fill x
				 
    ttk::label $w.f.head -style Headlabel -text "[mc {inboundCall}]: $phoneNumber"
    pack  $w.f.head  -side top -fill both -expand 1

    ttk::separator $w.f.s -orient horizontal
    pack  $w.f.s  -side top -fill x

    set wbox $w.f.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack  $wbox  -fill both -expand 1
    
    set box $wbox.b
    ttk::frame $box
    pack $box -side bottom -fill x
    
#    ttk::label $box.l -text "[mc phoneNumber]:"
#    ttk::entry $box.e -textvariable [namespace current]::phoneNumber  \
#      -width 18


    ttk::button $box.hungup -text [mc callHungUp]  \
      -command [list [namespace current]::HungUp $w ]

    ttk::button $box.vm  -text [mc callVM]  \
      -command [list [namespace current]::HungUp $w ]

#    grid  $box.l  $box.e  $box.dial -padx 1 -pady 4
 
    grid $box.hungup $box.vm -padx 1 -pady 4

    focus $box.hungup
    wm resizable $w 0 0

}

proc ::NotifyCall::CloseDialer {w} {
    
#    ::UI::SaveWinGeom $w   
}

proc ::NotifyCall::HungUp {w } {

    eval {::JivePhone::DialExtension "666" "FORWARD"}

    destroy $w
}

proc ::NotifyCall::JivePhoneEventHook {type ext cid args} {
    variable cociFile
    variable state

    set win $state(win)
    if {$type eq "RING"} {
        InboundCall $cid 
    } else {
        if {[winfo exists $win]} {
            destroy $win
        }
    }
}

proc ::NotifyCall::IAXPhoneEventHook {type cid args} {
    variable state

    set win $state(win)
    if {$type eq "RING"} {
        InboundCall $cid
    } else {
        if {[winfo exists $win]} {
            destroy $win
        }
    }
}
