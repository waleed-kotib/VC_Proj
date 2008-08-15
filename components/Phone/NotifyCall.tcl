# NotifyCall.tcl --
# 
#       NotifyCall is an Dialog Window with Inbound and Outbound call
#       notifications.
#       
#  Copyright (c) 2006 Antonio Cano Damas
#  Copyright (c) 2006-2008 Mats Bengtsson
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
# $Id: NotifyCall.tcl,v 1.27 2008-08-15 13:18:05 matben Exp $

package provide NotifyCall 0.1

namespace eval ::NotifyCall {}

proc ::NotifyCall::Init {} {
    
    ::hooks::register  avatarNewPhotoHook   ::NotifyCall::AvatarNewPhotoHook

    variable wmain .notifycall
    variable wslot -
    
    # How shall the phone be dispayed: slot|dialog
    set ::config(phone,notify,type) dialog
    #set ::config(phone,notify,type) slot
}

#-----------------------------------------------------------------------
#--------------------------- Notify Call Window ------------------------
#-----------------------------------------------------------------------

# NotifyCall::InboundCall --
# 

proc ::NotifyCall::InboundCall { {line ""} {phoneNumber ""} } {
    global config
    variable wmain
    variable wslot
    
    if { $phoneNumber ne "" } { 
	if {$config(phone,notify,type) eq "dialog"} {
	    Toplevel $wmain $line $phoneNumber "in"
	} elseif {$config(phone,notify,type) eq "slot"} {
	    set wslot [::NotifyCallSlot::InboundCall $line $phoneNumber]
	}
    }
}

# NotifyCall::OutboundCall --
#

proc ::NotifyCall::OutboundCall { {line ""} {phoneNumber ""} } {
    global config
    variable wmain
    variable wslot

    if { $phoneNumber ne "" } {
	if {$config(phone,notify,type) eq "dialog"} {
	    Toplevel $wmain $line $phoneNumber "out"
	} elseif {$config(phone,notify,type) eq "slot"} {
	    set wslot [::NotifyCallSlot::OutboundCall $line $phoneNumber]
	}
    }
}

# NotifyCall::Toplevel --
# 
#       Build a toplevel dialog for call admin.
#       Dialog for incoming and outgoing calls.
#
# Arguments:
#       w
#       line
#       phoneNumber
#       inout        'in' or 'out'
#       
# Results:
#       $w

proc ::NotifyCall::Toplevel {w line phoneNumber inout} {
    
    # Make sure only single instance of this dialog.
    if {[winfo exists $w]} {
	raise $w
	return
    }
    
    ::UI::Toplevel $w -class PhoneNotify \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand ::NotifyCall::CloseDialer

    if { $inout eq "in" } {
	wm title $w [mc notifyCall]
	set msgHead [mc inboundCall]:
    } else {
	wm title $w [mc outCall]
	set msgHead [mc outboundCall]:
    }
    
    # Global frame.
    ttk::frame $w.f
    pack $w.f

    ttk::label $w.f.head -style Headlabel -text $msgHead
    pack $w.f.head -side top -fill x

    ttk::separator $w.f.s -orient horizontal
    pack $w.f.s -side top -fill x
    
    Frame $w.f.call $line $phoneNumber $inout
    pack $w.f.call -side top -fill x
    $w.f.call configure -padding [option get . dialogPadding {}]

    wm resizable $w 0 0
    ::UI::SetWindowPosition $w
    
    return $w
}

proc ::NotifyCall::GetFrame {w} {
    return $w.f.call
}

proc ::NotifyCall::InitState {win} {
    variable $win
    upvar #0 $win state

    # Variables used for the widgets. Levels only temporary.
    set state(cmicrophone)    1
    set state(cspeaker)       1
    set state(microphone)     50
    set state(speaker)        50
    set state(old:microphone) 50
    set state(old:speaker)    50
    set state(type)           "pbx"
}

# NotifyCall::Frame --
# 
#       Build the actual megawidget frame. Multi instance.
#       @@@ This can be used to put in a notebook page.
#
# Arguments:
#       win
#       line
#       phoneNumber
#       inout
#       
# Results:
#       $win

proc ::NotifyCall::Frame {win line phoneNumber inout} {

    # Have state array with same name as frame.
    variable $win
    upvar #0 $win state
          
    InitState $win

    jlib::splitjid $phoneNumber jid2 res

    # The vertical scales need a 100-level rescale!
    set state(microphone) [::Phone::GetInputLevel]
    set state(speaker)    [::Phone::GetOutputLevel]
    set state(microphone-100) [expr {100 - $state(microphone)}]
    set state(speaker-100)    [expr {100 - $state(speaker)}]
    
    set state(inlevel)  0
    set state(outlevel) 0
    
    set state(line)        $line
    set state(inout)       $inout
    set state(phoneNumber) $phoneNumber
    
    set state(whangup) $win.hangup
    set state(wanswer) $win.answer
    
    set state(jid2) $jid2

    ttk::frame $win    
    ttk::label $win.num -text $jid2
    ttk::label $win.time -text "(00:00:00)" 
    set state(wtime) $win.time

    ttk::frame $win.left
    ttk::frame $win.right

    if {1} {
	ttk::button $win.hangup -text [mc callHungUp]  \
	  -command [list [namespace current]::HangUp $win]
	ttk::button $win.answer -text [mc callAnswer]  \
	  -command [list [namespace current]::Answer $win]
    } else {
	# Alternative style buttons.
	::TPhone::Button $win.hangup hangup  \
	  -command [list [namespace current]::HangUp $win]
	::TPhone::Button $win.answer call  \
	  -command [list [namespace current]::Answer $win]
    }
    ttk::button $win.info -text [mc callInfo]  \
      -command [list [namespace current]::CallInfo $win]
    ttk::frame $win.ava
        
    grid  $win.num     -            -sticky ew -padx 4 -pady 4
    grid  $win.time    -            -sticky ew -padx 4 -pady 4
    grid  $win.left    $win.right   -sticky ew -padx 4 -pady 4
    grid  $win.info    $win.ava     -sticky ew -padx 4 -pady 4
    grid  $win.hangup  $win.answer  -sticky ew -padx 4 -pady 4
    grid columnconfigure $win 0 -uniform a
    grid columnconfigure $win 1 -uniform a
    
    # Level controls.
    set images(microphone) [::Theme::FindIconSize 16 audio-input-microphone]
    set images(speaker)    [::Theme::FindIconSize 16 audio-output-speaker]

    # Microphone:
    set wmic $win.left.mic
    ttk::frame $wmic
    ttk::progressbar $wmic.p -length 60 -orient vertical  \
      -variable $win\(inlevel)
    ttk::scale $wmic.s -orient vertical -from 0 -to 100 -length 60  \
      -variable $win\(microphone-100)  \
      -command [list ::NotifyCall::MicCmd $win]
    ttk::checkbutton $wmic.c -style Toolbutton  \
      -variable $win\(cmicrophone) -image $images(microphone)  \
      -onvalue 0 -offvalue 1 -padding {1}  \
      -command [list ::NotifyCall::Mute $win microphone]
    
    grid  $wmic.p  $wmic.s  -sticky ns
    grid  $wmic.c    -
    grid $wmic.c -pady 4

    pack $wmic
    
    # Speakers:
    set wspk $win.right.spk
    ttk::frame $wspk
    ttk::progressbar $wspk.p -length 60 -orient vertical  \
      -variable $win\(outlevel)
    ttk::scale $wspk.s -orient vertical -from 0 -to 100 -length 60  \
      -variable $win\(speaker-100)  \
      -command [list ::NotifyCall::SpkCmd $win]
    ttk::checkbutton $wspk.c -style Toolbutton  \
      -variable $win\(cspeaker) -image $images(speaker)  \
      -onvalue 0 -offvalue 1 -padding {1}  \
      -command [list ::NotifyCall::Mute $win speaker]

    grid  $wspk.p  $wspk.s  -sticky ns
    grid  $wspk.c    -
    grid $wspk.c -pady 4

    pack $wspk
    
    # Only Incoming from Jingle (jid and res)  has Avatar.
    # @@@ Antonio: we should have a better mechanism to separate calls
    # via Asterisk and Jingle p2p calls.
    if { $res ne "" } {
	set state(type) "jingle"
	set state(wavatar) $win.ava.avatar
	
	#---- Gets Avatar from Incoming Number -----
	ttk::label $win.ava.avatar -style Sunken.TLabel -compound image
	::Avatar::GetAsyncIfExists $jid2
	AvatarNewPhotoHook $jid2
    }

    # Button info is available only for Jingle Calls.
    if { $res eq "" } {
	$win.info state {disabled}
    }
    if { $inout ne "in" } {
	$win.answer state {disabled}
    }    

    bind $win <Destroy>  { ::NotifyCall::Free %W }
    return $win
}

proc ::NotifyCall::SetTalkingState {win} {
    variable $win
    upvar #0 $win state

    $state(wanswer) state {disabled}
}

#-----------------------------------------------------------------------
#--------------------------- Notify Call Actions -----------------------
#-----------------------------------------------------------------------

proc ::NotifyCall::CloseDialer {w} {
    
    set msg [mc "Do you want to hang up?"]
    set ans [tk_messageBox -icon question -type yesno -message [mc $msg]]
    if {$ans eq "no"} {
	return stop
    } else {
	::UI::SaveWinGeom $w
	HangUp [GetFrame $w]
	return
    }
}

proc ::NotifyCall::Answer {win} {
    variable $win
    upvar #0 $win state

    $state(wanswer) state {disabled}
    ::Phone::Answer
}

proc ::NotifyCall::HangUp {win} {
    variable $win
    upvar #0 $win state
    
    ::Debug 4 "::NotifyCall::HangUp"
    
    if { $state(type) eq "pbx" } {    
	::Phone::Hangup $state(line)
    } else {
	::Phone::HangupJingle $state(line)
    }
    
    # @@@ What to do? BAD!!!
    set w [winfo toplevel $win]
    if {[winfo class $w] eq "PhoneNotify"} {
	::UI::SaveWinGeom $w
	destroy $w
    }
}

proc ::NotifyCall::CallInfo {win} {
    variable $win
    upvar #0 $win state

    ::UserInfo::Get $state(phoneNumber) 
}

proc ::NotifyCall::MicCmd {win level} {
    variable $win
    upvar #0 $win state
    
    set level [expr {100 - $level}]
    set state(microphone) $level
    if {$level != $state(old:microphone)} {
	::Phone::SetInputLevel $level
    }
    set state(old:microphone) $level
}

proc ::NotifyCall::SpkCmd {win level} {
    variable $win
    upvar #0 $win state

    set level [expr {100 - $level}]
    set state(speaker) $level
    if {$level != $state(old:speaker)} {
	::Phone::SetOutputLevel $level        
    }
    set state(old:speaker) $level
}

proc ::NotifyCall::Mute {win what} {
    variable $win
    upvar #0 $win state
   
    if { $state(c$what) } {
        set state($what) 0
    } else {
        set state($what) $state(old:$what)
    }
    ::Phone::Mute $what $state(c$what)
}

proc ::NotifyCall::TimeUpdate {time} {
    variable wmain

    if {[winfo exists $wmain]} {
        set win [GetFrame $wmain]
        variable $win
        upvar #0 $win state

        # Make sure it is mapped
        grid  $state(wtime)  -padx 4 -pady 4
        $state(wtime) configure -text "($time)"
    }
}

proc ::NotifyCall::Free {win} {
    variable $win
    upvar #0 $win state
    
    unset -nocomplain state
}

# These are the interfaces that the Phone component calls.......................

proc ::NotifyCall::SubjectEvent {textmessage} {

    # Adding the Subject from Caller

}

proc ::NotifyCall::IncomingEvent {callNo remote remote_name} {

    ::Debug 4 "::NotifyCall::IncomingEvent $callNo $remote $remote_name"
    
    set phoneNameInput $remote
    set phoneNumberInput $remote_name
    InboundCall $callNo "$phoneNameInput ($phoneNumberInput)"
}

proc ::NotifyCall::OutgoingEvent {remote_name} {

    ::Debug 4 "::NotifyCall::OutgoingEvent"
    
    set phoneNameInput $remote_name
    OutboundCall 1 $phoneNameInput
}

proc ::NotifyCall::HangupEvent {args} {
    variable wmain

    destroy $wmain
}

proc ::NotifyCall::TalkingEvent {args} {
    variable wmain
    
    # What to do when user is talking
    SetTalkingState [GetFrame $wmain]
}

proc ::NotifyCall::LevelEvent {in out} {
    variable wmain
    variable wslot
    
    if {[winfo exists $wmain]} {
	set win [GetFrame $wmain]
	variable $win
	upvar #0 $win state
    
	set state(inlevel)  $in
	set state(outlevel) $out
    } elseif {[winfo exists $wslot]} {
	::NotifyCallSlot::LevelEvent $in $out
    }
}

proc ::NotifyCall::AvatarNewPhotoHook {jid2} {
    variable wmain

    if {[winfo exists $wmain]} {
 	set win [GetFrame $wmain]
	variable $win
	upvar #0 $win state

	# 'phoneNumber' first part is the JID. I don't like this!
	if {[jlib::jidequal [jlib::barejid $state(phoneNumber)] $jid2]} {
	
	    set avatar [::Avatar::GetPhotoOfSize $jid2 64]
	    if {$avatar eq ""} {
		grid forget $state(wavatar)
	    } else {
		
		# Make sure it is mapped
		grid  $state(wavatar)  -padx 4 -pady 4
		$state(wavatar) configure -image $avatar
	    }
	}
    }
}

#--- Experiment using slots ----------------------------------------------------

namespace eval ::NotifyCallSlot {
    
    option add *NotifyCallSlot.padding       {4 2 2 2}     50
    option add *NotifyCallSlot.box.padding   {4 2 8 2}     50
    option add *NotifyCallSlot*TLabel.style  Small.TLabel  widgetDefault
    
    ::JUI::SlotRegister notifycall [namespace code BuildEmpty]

    variable images
    set images(microphone) [::Theme::FindIconSize 16 audio-input-microphone]
    set images(speaker)    [::Theme::FindIconSize 16 audio-output-speaker]
    set images(online)     [::Theme::FindIconSize 16 phone-online]
    set images(talk)       [::Theme::FindIconSize 16 phone-talk]
}

# NotifyCallSlot::BuildEmpty --
#
#       This just reserves room for the slot and add menus.
#       The actual slot is only built when having a call.

proc ::NotifyCallSlot::BuildEmpty {w args} {
    variable slot
    
    ttk::frame $w

    # Add menu.    
    # This isn't the right way!
    foreach m [::JUI::SlotGetAllMenus] {
	$m add checkbutton -label [mc "Call Notification"] \
	  -variable [namespace current]::slot(show) \
	  -command [namespace code SlotCmd] \
	  -state disabled
    }
    set slot(wempty) $w
    set slot(show)   0

    ::JUI::SlotShow notifycall
    
    return $w
}

proc ::NotifyCallSlot::Build {w inout args} {
    variable slot
    
    ttk::frame $w -class NotifyCallSlot

    if {1} {
	set slot(collapse) 0
	ttk::checkbutton $w.arrow -style Arrow.TCheckbutton \
	  -command [list [namespace current]::Collapse $w] \
	  -variable [namespace current]::slot(collapse)
	pack $w.arrow -side left -anchor n	
	bind $w.arrow <<ButtonPopup>> [list [namespace current]::Popup $w %x %y]

	set im  [::Theme::FindIconSize 16 close-aqua]
	set ima [::Theme::FindIconSize 16 close-aqua-active]
	ttk::button $w.close -style Plain  \
	  -image [list $im active $ima] -compound image  \
	  -command [namespace code [list Close $w]]
	pack $w.close -side right -anchor n	

	::balloonhelp::balloonforwindow $w.close [mc "Close Slot"]
    }    
    set box $w.box
    ttk::frame $box
    pack $box -fill x -expand 1
    
    set win [Frame $box.f $inout]
    pack $win -fill x -expand 1
    
    set slot(w)     $w
    set slot(box)   $w.box
    set slot(win)   $win
    
    return $w
}

proc ::NotifyCallSlot::InboundCall {line number} {
    variable slot
    
    ::JUI::SlotDisplay
    
    set win $slot(wempty).slot
    set slot(line)   $line
    set slot(number) $number

    Build $win in
    pack $win -fill x -expand 1
    
    return $win
}

proc ::NotifyCallSlot::OutboundCall {line number} {
    variable slot
    
    ::JUI::SlotDisplay
    
    set win $slot(wempty).slot
    set slot(line)   $line
    set slot(number) $number

    Build $win out
    pack $win -fill x -expand 1
    
    return $win
}

proc ::NotifyCallSlot::Frame {win inout} {
    variable images
    
    # Have state array with same name as frame.
    variable $win
    upvar #0 $win state
    
    # Just make sure they exist.
    set state(inlevel)        0
    set state(outlevel)       0
    set state(old:microphone) 50
    set state(old:speaker)    50
    set state(cmicrophone)    1
    set state(cspeaker)       1
    set state(time)           "(00:00:00)"
    set state(caller) [mc "%s is calling..." "Mats"]

    # The vertical scales need a 100-level rescale!
    set state(microphone) [::Phone::GetInputLevel]
    set state(speaker)    [::Phone::GetOutputLevel]
	  
    ttk::frame $win -class NotifyCallSlotFrame
    
    # Caller info.
    set winfo $win.info
    #ttk::frame $win.info
    frame $win.info -bg red
    pack $win.info -side top -fill x

    ttk::button $winfo.answer -style Plain \
      -image $images(online) \
      -command [namespace code [list Answer $win]]
    ttk::label $winfo.name -textvariable $win\(caller)
    ttk::button $winfo.hangup -style Plain \
      -image $images(talk) \
      -command [namespace code [list HangUp $win]]
    
    grid  $winfo.answer  $winfo.name  $winfo.hangup  -padx 4
    grid $winfo.name -sticky ew
    grid $winfo.hangup -sticky e
    grid columnconfigure $win 1 -weight 1
    
    ::balloonhelp::balloonforwindow $winfo.answer [mc "Answer call"]
    ::balloonhelp::balloonforwindow $winfo.hangup [mc "Hangup call"]
    
    # Level controls.
    # These are only displayed when we have answered the call. Bad?
    set wctrl $win.ctrl
    ttk::frame $win.ctrl
    #pack $win.ctrl -side top -fill x
    
    # Microphone.
    ttk::progressbar $wctrl.pmic -orient horizontal  \
      -variable $win\(inlevel)
    ttk::scale $wctrl.smic -orient horizontal -length 60 -from 0 -to 100  \
      -variable $win\(microphone)  \
      -command [namespace code [list MicCmd $win]]
    ttk::checkbutton $wctrl.cmic -style Plain  \
      -variable $win\(cmicrophone) -image $images(microphone)  \
      -onvalue 0 -offvalue 1 -padding {1}  \
      -command [namespace code [list Mute $win microphone]]

    # Speakers.
    ttk::progressbar $wctrl.pspk -orient horizontal  \
      -variable $win\(outlevel)
    ttk::scale $wctrl.sspk -orient horizontal -length 60 -from 0 -to 100  \
      -variable $win\(speaker)  \
      -command [namespace code [list SpkCmd $win]]
    ttk::checkbutton $wctrl.cspk -style Plain  \
      -variable $win\(cspeaker) -image $images(speaker)  \
      -onvalue 0 -offvalue 1 -padding {1}  \
      -command [namespace code [list Mute $win speaker]]

    grid  $wctrl.pmic  $wctrl.smic  $wctrl.cmic
    grid  $wctrl.pspk  $wctrl.sspk  $wctrl.cspk
    grid $wctrl.pmic $wctrl.pspk -sticky ew
    grid $wctrl.smic $wctrl.sspk -padx 16
    grid columnconfigure $wctrl 0 -weight 1
    
    set state(winfo) $winfo
    set state(wctrl) $wctrl
    set state(wcall) $winfo.name
    set state(wanswer) $winfo.answer
    
    bind $win <Destroy> [namespace code [list FrameFree $win]]
    
    return $win
}

proc ::NotifyCallSlot::Answer {win} {
    variable images
    variable $win
    upvar #0 $win state
    
    pack $state(wctrl) -side top -fill x

    set state(caller) [mc "%s is on the phone" "Mats"]
    
    $state(wanswer) state {disabled}
    ::Phone::Answer

}

proc ::NotifyCallSlot::HangUp {win} {
    variable slot
    variable $win
    upvar #0 $win state
    
    ::Phone::HangupJingle $slot(line)
    
    destroy $slot(win)

    set slot(show) 0
    ::JUI::SlotClose notifycall
}

proc ::NotifyCallSlot::MicCmd {win level} {
    variable $win
    upvar #0 $win state
    
    set state(microphone) $level
    if {$level != $state(old:microphone)} {
	::Phone::SetInputLevel $level
    }
    set state(old:microphone) $level
}

proc ::NotifyCallSlot::SpkCmd {win level} {
    variable $win
    upvar #0 $win state

    set state(speaker) $level
    if {$level != $state(old:speaker)} {
	::Phone::SetOutputLevel $level        
    }
    set state(old:speaker) $level
}

proc ::NotifyCallSlot::Mute {win which} {
    variable $win
    upvar #0 $win state
    
    
}

proc ::NotifyCallSlot::LevelEvent {in out} {
    variable slot

    set win $slot(win)
    variable $win
    upvar #0 $win state
    
    set state(inlevel)  $in
    set state(outlevel) $out
}

proc ::NotifyCallSlot::FrameFree {win} {
    variable $win
    upvar #0 $win state

    unset -nocomplain state
}

proc ::NotifyCallSlot::SlotCmd {} {
    if {[::JUI::SlotShowed notifycall]} {
	::JUI::SlotClose notifycall
    } else {
	::JUI::SlotShow notifycall
    }
}

proc ::NotifyCallSlot::Collapse {w} {
    variable slot

    if {$slot(collapse)} {
	pack forget $slot(box)
    } else {
	pack $slot(box) -fill both -expand 1
    }
    #event generate $w <<Xxx>>
}

proc ::NotifyCallSlot::Close {w} {
    variable slot
    
    set msg [mc "Do you want to hang up?"]
    set ans [tk_messageBox -icon question -type yesno -message [mc $msg]]
    if {$ans eq "yes"} {
	HangUp $slot(win)
    }
}



