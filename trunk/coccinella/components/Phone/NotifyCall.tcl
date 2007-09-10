# NotifyCall.tcl --
# 
#       NotifyCall is an Dialog Window with Inbound and Outbound call
#       notifications.
#       
#  Copyright (c) 2006 Antonio Cano Damas
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
# $Id: NotifyCall.tcl,v 1.18 2007-09-10 12:31:55 matben Exp $

package provide NotifyCall 0.1

namespace eval ::NotifyCall { }

proc ::NotifyCall::Init { } {
    
    ::hooks::register  avatarNewPhotoHook   ::NotifyCall::AvatarNewPhotoHook

    variable wmain .notifycall
}

#-----------------------------------------------------------------------
#--------------------------- Notify Call Window ------------------------
#-----------------------------------------------------------------------

# NotifyCall::InboundCall  --
# 

proc ::NotifyCall::InboundCall { {line ""} {phoneNumber ""} } {
    variable wmain
    
    if { $phoneNumber ne "" } { 
	Toplevel $wmain $line $phoneNumber "in"
    }
}

# NotifyCall::OutboundCall  --
#

proc ::NotifyCall::OutboundCall { {line ""} {phoneNumber ""} } {
    variable wmain

    if { $phoneNumber ne "" } {
	Toplevel $wmain $line $phoneNumber "out"
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
    set subPath [file join components Phone timages]
    set images(microphone) [::Theme::GetImage microphone $subPath]
    set images(speaker)    [::Theme::GetImage speaker $subPath]    

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
	# Bug in 8.4.1 but ok in 8.4.9
	if {[regexp {^8\.4\.[0-5]$} [info patchlevel]]} {
	    label $win.ava.avatar -relief sunken -bd 1 -bg white
	} else {
	    ttk::label $win.ava.avatar -style Sunken.TLabel -compound image
	}	
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

# Slot for roster main window --- @@@ TODO

proc ::NotifyCall::Slot {win} {
    
    # Have state array with same name as frame.
    variable $win
    upvar #0 $win state
	  
    # Level controls.
    set subPath [file join components Phone timages]
    set images(microphone) [::Theme::GetImage microphone $subPath]
    set images(speaker)    [::Theme::GetImage speaker $subPath]    

    ttk::frame $win -padding {4 2}
    
    # Microphone.
    ttk::progressbar $win.pmic -orient horizontal  \
      -variable $win\(inlevel)
    ttk::scale $win.smic -orient horizontal -length 60 -from 0 -to 100  \
      -variable $win\(microphone-100)  \
      -command [list ::NotifyCall::MicCmd $win]
    ttk::checkbutton $win.cmic -style Toolbutton  \
      -variable $win\(cmicrophone) -image $images(microphone)  \
      -onvalue 0 -offvalue 1 -padding {1}  \
      -command [list ::NotifyCall::Mute $win microphone]

    # Speakers.
    ttk::progressbar $win.pspk -orient horizontal  \
      -variable $win\(outlevel)
    ttk::scale $win.sspk -orient horizontal -length 60 -from 0 -to 100  \
      -variable $win\(speaker-100)  \
      -command [list ::NotifyCall::SpkCmd $win]
    ttk::checkbutton $win.cspk -style Toolbutton  \
      -variable $win\(cspeaker) -image $images(speaker)  \
      -onvalue 0 -offvalue 1 -padding {1}  \
      -command [list ::NotifyCall::Mute $win speaker]

    grid  $win.pmic  $win.smic  $win.cmic  -padx 2
    grid  $win.pspk  $win.sspk  $win.cspk  -padx 2
    grid $win.pmic $win.pspk -sticky ew
    grid columnconfigure $win 0 -weight 1
    
    return $win
}

#-----------------------------------------------------------------------
#--------------------------- Notify Call Actions -----------------------
#-----------------------------------------------------------------------

proc ::NotifyCall::CloseDialer {w} {
    
    set msg [mc "Do you actually want to hang up?"]
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
        
    if {[winfo exists $wmain]} {
	set win [GetFrame $wmain]
	variable $win
	upvar #0 $win state
    
	set state(inlevel)  $in
	set state(outlevel) $out
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
