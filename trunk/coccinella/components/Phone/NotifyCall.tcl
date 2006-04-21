# NotifyCall.tcl --
# 
#       NotifyCall is an Dialog Window with Inbound and Outbound call
#       notifications.
#       
#  Copyright (c) 2006 Antonio Cano Damas
#  
# $Id: NotifyCall.tcl,v 1.9 2006-04-21 08:19:04 antoniofcano Exp $

package provide NotifyCall 0.1

namespace eval ::NotifyCall { }

proc ::NotifyCall::Init { } {
    
    ::hooks::register  avatarNewPhotoHook       ::NotifyCall::AvatarNewPhotoHook

    InitState
}

proc ::NotifyCall::InitState { } {
    variable  state
    
    set state(win) .notifycall

    # Variables used for the widgets. Levels only temporary.
    set state(cmicrophone)    1
    set state(cspeaker)       1
    set state(microphone)     50
    set state(speaker)        50
    set state(old:microphone) 50
    set state(old:speaker)    50
    set state(type)           -
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
        BuildDialer $win $line $phoneNumber "in"
    }
}

# NotifyCall::OutboundCall  --
#

proc ::NotifyCall::OutboundCall { {line ""} {phoneNumber ""} } {
    variable state

    set win $state(win)

    if { $phoneNumber ne "" } {
        BuildDialer $win $line $phoneNumber "out"
    }
}

# NotifyCall::BuildDialer --
# 
#       Dialog for incoming and outgoing calls.
       
proc ::NotifyCall::BuildDialer {w line phoneNumber type} {
    variable state

    # Make sure only single instance of this dialog.
    if {[winfo exists $w]} {
	raise $w
	return
    }

    set state(type) "pbx"

    set state(microphone) [::Phone::GetInputLevel]
    set state(speaker)    [::Phone::GetOutputLevel]
    
    ::UI::Toplevel $w -class PhoneNotify \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand ::NotifyCall::CloseDialer

    if { $type eq "in" } {
        wm title $w [mc notifyCall]
    } else {
        wm title $w [mc outCall]
    }

    ::UI::SetWindowPosition $w

    # Global frame.
    ttk::frame $w.f
    grid $w.f  -sticky we

    #---------  Window Head information -------------
    if { $type eq "in" } {
        set msgHead [mc {inboundCall}]:
    } else {
        set msgHead [mc {outboundCall}]:
    } 
    ttk::label $w.f.head -style Headlabel -text $msgHead
    grid $w.f.head -column 0 -row 0 -columnspan 2 

    ttk::separator $w.f.s -orient horizontal
    grid $w.f.s -column 0 -row 1 -sticky ew -pady 4 -columnspan 2

    ttk::label $w.f.phoneNumber -style Headlabel -text $phoneNumber
    grid $w.f.phoneNumber -column 0 -row 2 

    #------- Only Incoming from Jingle (jid and res)  has Avatar -----------
    jlib::splitjid $phoneNumber jid2 res
    if { $res ne "" } {
        set state(type) "jingle"

        #---- Gets Avatar from Incoming Number -----
        # Bug in 8.4.1 but ok in 8.4.9
        if {[regexp {^8\.4\.[0-5]$} [info patchlevel]]} {
            label $w.f.avatar -relief sunken -bd 1 -bg white
        } else {
            ttk::label $w.f.avatar -style Sunken.TLabel -compound image
        }

        ::Avatar::GetAsyncIfExists $jid2
        ::NotifyCall::AvatarNewPhotoHook $jid2
    }

    ttk::separator $w.f.s2 -orient horizontal
    grid $w.f.s2 -column 0 -row 3 -sticky ew -pady 4 -columnspan 2

    #--------- Control Buttons -----------
    set wbox $w.f.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    grid $wbox  -sticky nswe 
    
    set box $wbox.b
    ttk::frame $box
    grid $box -sticky we
    
#    ttk::label $box.l -text "[mc phoneNumber]:"
#    ttk::entry $box.e -textvariable [namespace current]::phoneNumber  \
#      -width 18

    ttk::button $box.hungup -text [mc callHungUp]  \
      -command [list [namespace current]::HungUp $w $line]
 
    grid $box.hungup -column 0 -row 4 -padx 1 -pady 4

    if { $type eq "in" } {
        ttk::button $box.answer -text [mc callAnswer]  \
          -command [list [namespace current]::Answer $w $line]
        grid $box.answer -column 1 -row 4 -padx 1 -pady 4
    }

    set subPath [file join components Phone timages]

    set images(microphone) [::Theme::GetImage microphone $subPath]
    ttk::frame $box.mic
    ttk::scale $box.mic.s -orient horizontal -from 0 -to 100 \
      -variable [list ::NotifyCall::state(microphone)]  \
      -command [list ::NotifyCall::MicCmd $w] -length 60
    ttk::checkbutton $box.mic.l -style Toolbutton  \
      -variable [list ::NotifyCall::state(cmicrophone)] -image $images(microphone)  \
      -onvalue 0 -offvalue 1 -padding {1}  \
      -command [list ::NotifyCall::Mute $w microphone]  -state disabled
    grid $box.mic.l  $box.mic.s

    set images(speaker) [::Theme::GetImage speaker $subPath]    
    ttk::frame $box.spk
    ttk::scale $box.spk.s -orient horizontal -from 0 -to 100 \
      -variable [list ::NotifyCall::state(speaker)] -command [list ::NotifyCall::SpkCmd $w] -length 60
    ttk::checkbutton $box.spk.l -style Toolbutton  \
      -variable [list ::NotifyCall::state(cspeaker)] -image $images(speaker)  \
      -onvalue 0 -offvalue 1 -padding {1}  \
      -command [list ::NotifyCall::Mute $w speaker] -state disabled
    grid $box.spk.l  $box.spk.s 

    grid $box.mic $box.spk -padx 4
    grid $box.mic -column 0 -row 5 -sticky w
    grid $box.spk -column 1 -row 5 -sticky e
    grid columnconfigure $box 1 -weight 1

    #--- Button info, is available only for Jingle Calls ---
    if { $res ne "" } {
        ttk::button $box.info -text [mc callInfo]  \
          -command [list [namespace current]::CallInfo $w $phoneNumber]
        grid $box.info -row 6 -padx 1 
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
    variable state
 
    ::Debug 4 "::NotifyCall::HungUp"

    if { $state(type) eq "pbx" } {    
        ::Phone::Hangup $line
    } else {
        ::Phone::HangupJingle $line
    }
    destroy $w
}

proc ::NotifyCall::CallInfo {w phoneNumber} {

    ::UserInfo::Get $phoneNumber 
}

proc ::NotifyCall::MicCmd {w level} {
    variable state
    
    if {$level != $state(old:microphone)} {
	::Phone::SetInputLevel $level
    }
    set state(old:microphone) $level
}

proc ::NotifyCall::SpkCmd {w level} {
    variable state    

    if {$level != $state(old:speaker)} {
	::Phone::SetOutputLevel $level        
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

proc ::NotifyCall::TimeUpdate {time} {
    variable state

    #What to do when user is talking
    #set win $state(win)
    #set wbox .notify.l

    #ttk::separator $wbox.s4 -orient horizontal
    #pack  $wbox.s4  -side top -fill x
        
    #ttk::label $wbox.lcd -text "[mc callDuration]:  $time"
    #pack  $wbox.lcd  -side bottom -fill x


#    puts "Update Time: $time"
}

# These are the interfaces that the Phone component calls.......................

proc ::NotifyCall::SubjectEvent {textmessage} {

    # Adding the Subject from Caller

}

proc ::NotifyCall::IncomingEvent {callNo remote remote_name} {

    ::Debug 4 "::NotifyCall::IncomingEvent $callNo $remote $remote_name"
    
    set phoneNameInput $remote
    set phoneNumberInput $remote_name
    InboundCall $callNo  "$phoneNameInput ($phoneNumberInput)"
}

proc ::NotifyCall::OutgoingEvent {remote_name} {

    set phoneNameInput $remote_name
    OutboundCall 1 $phoneNameInput
}

proc ::NotifyCall::HangupEvent {args} {
    variable state

   set win $state(win)
   if {[winfo exists $win]} {
       destroy $win
   }
}

proc ::NotifyCall::TalkingEvent {args} {
    variable state
    
    # What to do when user is talking
    set win $state(win)
    set wbox $win.f.f.b

    $wbox.answer configure -state disabled
    $wbox.mic.l  configure -state enabled
    $wbox.spk.l  configure -state enabled
}

proc ::NotifyCall::AvatarNewPhotoHook {jid2} {
    variable state

    set w $state(win)
    if {[winfo exists $w]} {
        set avatar [::Avatar::GetPhotoOfSize $jid2 64]

        if {$avatar eq ""} {
            grid forget $w.f.avatar
        } else {
            # Make sure it is mapped
            grid $w.f.avatar -row 2 -column 1 -padx 4
            $w.f.avatar configure -image $avatar
        }
    }
}
