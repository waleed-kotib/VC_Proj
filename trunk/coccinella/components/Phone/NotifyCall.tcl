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
    ::hooks::register phoneNotifyTalkingState         ::NotifyCall::TalkingEventHook

    #--------------- Variables Uses For SpeedDial Addressbook Tab ----------------
    InitState
}

proc ::NotifyCall::InitState { } {
    variable  state
    
    set state(win) .notify

    set state(old:microphone) 50
    set state(old:speaker) 50
    set state(cmicrophone) 1
    set state(cspeaker) 1
    set state(microphone) 50
    set state(speaker) 50
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
				 
    ttk::label $w.f.head -style Headlabel -text "[mc {inboundCall}]:"
    pack  $w.f.head  -side top -fill both -expand 1

    ttk::separator $w.f.s -orient horizontal
    pack  $w.f.s  -side top -fill x

    ttk::label $w.f.phoneNumber -style Headlabel -text "$phoneNumber"
    pack $w.f.phoneNumber  -side top -fill both -expand 1

    #---- Gets Avatar from Incoming Number -----
    jlib::splitjid $phoneNumber jid2 res
    if { $res ne "" } {
        set avatar [::Avatar::GetPhoto $jid2]
        if { $avatar ne "" } {
            set width  [image width $avatar]
            set height [image height $avatar]
            canvas $w.f.avatar -width $width -height $height  \
              -highlightthickness 3 -bd 0 -highlightbackground gray87  \
              -insertwidth 0 -bg gray87
            $w.f.avatar create image 3 3 -anchor nw -image $avatar

            pack  $w.f.avatar  -side top -fill both -expand 1
        }
    }

    ttk::separator $w.f.s2 -orient horizontal
    pack  $w.f.s2  -side top -fill x

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
 
    grid $box.answer $box.hungup -padx 1 -pady 4

    #--- Button info, is available only for Jingle Calls ---
    if { $res ne "" } {
        set subPath [file join components Phone timages]

        set images(microphone) [::Theme::GetImage microphone $subPath]
        ttk::frame $box.mic
        ttk::scale $box.mic.s -orient horizontal -from 0 -to 100 \
          -variable [list ::NotifyCall::state(microphone)] -command [list ::NotifyCall::MicCmd $w] -length 60
        ttk::checkbutton $box.mic.l -style Toolbutton  \
          -variable [list ::NotifyCall::state(cmicrophone)] -image $images(microphone)  \
          -onvalue 0 -offvalue 1 -padding {1}  \
          -command [list ::NotifyCall::Mute $w microphone]  -state disabled

        pack  $box.mic.l  $box.mic.s  -side top
        pack $box.mic.s -padx 4


        set images(speaker) [::Theme::GetImage speaker $subPath]    
        ttk::frame $box.spk
        ttk::scale $box.spk.s -orient horizontal -from 0 -to 100 \
          -variable [list ::NotifyCall::state(speaker)] -command [list ::NotifyCall::SpkCmd $w] -length 60
        ttk::checkbutton $box.spk.l -style Toolbutton  \
          -variable [list ::NotifyCall::state(cspeaker)] -image $images(speaker)  \
          -onvalue 0 -offvalue 1 -padding {1}  \
          -command [list ::NotifyCall::Mute $w speaker] -state disabled
        pack  $box.spk.l  $box.spk.s  -side top
        pack $box.spk.s -padx 4

        grid  $box.mic $box.spk -padx 4
        grid $box.mic -sticky w
        grid $box.spk -sticky e
        grid columnconfigure $box 1 -weight 1


        ttk::button $box.info -text [mc callInfo]  \
          -command [list [namespace current]::CallInfo $w $phoneNumber]
        grid $box.info -padx 1 -pady 4
    }
    focus $box.hungup
    wm resizable $w 0 0
}


#-----------------------------------------------------------------------
#--------------------------- Notify Call Actions -----------------------
#-----------------------------------------------------------------------

proc ::NotifyCall::CloseDialer {w} {
    
#    ::UI::SaveWinGeom $w   
}

proc ::NotifyCall::Answer  {w line} {
    ::Phone::Answer
}

proc ::NotifyCall::HungUp {w line} {
    ::Phone::Hangup $line
    destroy $w
}

proc ::NotifyCall::CallInfo {w phoneNumber} {

    ::UserInfo::Get $phoneNumber 
}

proc ::NotifyCall::MicCmd {w level} {
    variable state
    
    if {$level != $state(old:microphone)} {
	::Phone::SetInputLevel [expr {100 - $level}]
    }
    set state(old:microphone) $level
}

proc ::NotifyCall::SpkCmd {w level} {
    variable state    

    if {$level != $state(old:speaker)} {
	::Phone::SetOutputLevel [expr {100 - $level}]        
    }
    set state(old:speaker) $level
}

proc ::NotifyCall::Mute {w type} {
    variable state
   
    if { $state(c$type) == 1 } {
        set state($type) 0
    } else {
        set state($type) $state(old:$type)
    }
    ::Phone::Mute $type $state(c$type)
}
#-----------------------------------------------------------------------
#------------------------ Notify Call Event Hooks ----------------------
#-----------------------------------------------------------------------

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

proc ::NotifyCall::TalkingEventHook {args} {
    variable state

    #What to do when user is talking
    set win $state(win)
    set wbox $win.f.f.b

    $wbox.answer configure -state disabled
    $wbox.mic.l  configure -state enabled
    $wbox.spk.l  configure -state enabled
}
