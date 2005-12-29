#agents NotifyCall.tcl --
# 
#       NotifyCall is an Dialog Window with Inbound calls notifications 
#       

namespace eval ::NotifyCall:: { }

proc ::NotifyCall::Init { } {
    
    component::register NotifyCall  \
      "Provides support for Incoming Calls Dialog"

    ::hooks::register jivePhoneEvent      ::NotifyCall::JivePhoneEventHook
        
    #--------------- Variables Uses For SpeedDial Addressbook Tab ----------------
    InitState
}

proc ::NotifyCall::InitState { } {
    variable state
    
    array set state {
	phoneserver     0
	setui           0
	win             .notify
	wstatus         -
	phone		-
        abphonename     -
        abphonenumber   -
    }
}


#-----------------------------------------------------------------------
#--------------------------- Notify Call Window ------------------------
#-----------------------------------------------------------------------


# NotifyCall::InboundCall  --
# 

proc ::NotifyCall::InboundCall { {phoneNumber ""} callID} {
    variable state
  
    set win $state(win)

    if { $phoneNumber ne "" } { 
        BuildDialer $win $phoneNumber $callID
    }
}

# NotifyCall::BuildDialer --
# 
#       A toplevel dialer.
       
proc ::NotifyCall::BuildDialer {w phoneNumber callID} {
    variable state

    # Make sure only single instance of this dialog.
    if {[winfo exists $w]} {
	raise $w
	return
    }

    ::UI::Toplevel $w -class PhoneDialer \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand [namespace current]::CloseDialer

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
      -command [list [namespace current]::HungUp $w $callID]

    ttk::button $box.vm  -text [mc callVM]  \
      -command [list [namespace current]::HungUp $w $callID]

#    grid  $box.l  $box.e  $box.dial -padx 1 -pady 4
 
    grid $box.hungup $box.vm -padx 1 -pady 4

    focus $box.hungup
    wm resizable $w 0 0
}

proc ::NotifyCall::CloseDialer {w} {
    
    ::UI::SaveWinGeom $w   
}

proc ::NotifyCall::HungUp {w callID} {

    eval {::JivePhone::DialExtension "666" "FORWARD" $callID}

    destroy $w
}

proc ::NotifyCall::JivePhoneEventHook {type cid callID args} {
    variable cociFile
    variable state

    set win $state(win)

    if {$type eq "RING"} {
        InboundCall $cid $callID
    } else {
        destroy $win
    }
}

