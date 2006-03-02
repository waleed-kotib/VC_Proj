#agents NotifyCall.tcl --
# 
#       NotifyCall is an Dialog Window with Inbound calls notifications 
#       

namespace eval ::NotifyCall:: { }

proc ::NotifyCall::Init { } {
    
    component::register NotifyCall  \
      "Provides support for Incoming Calls Dialog"

    ::hooks::register phoneNotifyIncomingCall         ::NotifyCall::IncomingEventHook
    ::hooks::register phoneNotifyNormalState          ::NotifyCall::HangupEventHook
    ::hooks::register phoneNotifyTalkingState         ::NotifyCall::HangupEventHook

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

proc ::NotifyCall::InboundCall { {line ""} {phoneNumber ""} } {
    variable state
  
    set win $state(win)

    if { $phoneNumber ne "" } { 
        BuildDialer $win $line $phoneNumber 
    }
}

# NotifyCall::BuildDialer --
# 
#       A toplevel dialer.
       
proc ::NotifyCall::BuildDialer {w line phoneNumber } {
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


    ttk::button $box.answer -text [mc callAnswer]  \
      -command [list [namespace current]::Answer $w $line]

    ttk::button $box.hungup -text [mc callHungUp]  \
      -command [list [namespace current]::HungUp $w $line]

#    grid  $box.l  $box.e  $box.dial -padx 1 -pady 4
 
    grid $box.answer $box.hungup -padx 1 -pady 4

    focus $box.hungup
    wm resizable $w 0 0

}

proc ::NotifyCall::CloseDialer {w} {
    
#    ::UI::SaveWinGeom $w   
}

proc ::NotifyCall::Answer  {w line} {
    ::Phone::Answer
    destroy $w
}

proc ::NotifyCall::HungUp {w line} {
    ::Phone::Hangup $line
    destroy $w
}

proc ::NotifyCall::SubjectEventHook {textmessage} {
    variable cociFile

#Adding the Subject from Caller


#
}

proc ::NotifyCall::IncomingEventHook {callNo remote remote_name} {
    variable cociFile

    set phoneNameInput $remote
    set phoneNumberInput $remote_name
    InboundCall $callNo  "$phoneNameInput ($phoneNumberInput)"
}

proc ::NotifyCall::HangupEventHook {args} {
    variable state

   set win $state(win)
   if {[winfo exists $win]} {
       destroy $win
   }
}
