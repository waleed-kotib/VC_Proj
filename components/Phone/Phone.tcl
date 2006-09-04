#  Phone.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the core interface for softphone components.
#      
#  Copyright (c) 2006 Mats Bengtsson
#  Copyright (c) 2006 Antonio Cano Damas
#  
# $Id: Phone.tcl,v 1.20 2006-09-04 06:32:04 matben Exp $

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# A plugin system for softphones:
# 
#                    softphones
# 
#                /--- Jingle/Jingle
#               /
#              /
#	Phone ------- IAX/iax
#	  |    \
#         |     \
#         |      \--- Jive/JivePhone
#	 TPhone
#	 AdBook
#	 NotifyCall
#	      
#   Each softphone registers with the Phone and gets the necessary callbacks
#   from the registered procedures. Hooks shall not be used for communications
#   from the Phone to its softphones since only one of the softphones,
#   the 'selected' phone, is active. 
#   If a softphone wants something executed in Phone it shall call a procedure
#   directly.
#   
#   TODO: - how to handle '::hooks::run protocol*' ?
#         - search for @@@ to see where question marks are

namespace eval ::Phone {
    variable phone

    set phone(selected) ""
    set phone(previous) ""

    variable scriptPath [file dirname [info script]]
}

proc ::Phone::Init { } {
    variable scriptPath

    if {[catch {package require TPhone}]} {
	return
    }
    if {[catch {package require NotifyCall}]} {
	return
    }

    component::register Phone "Provides protocol abstraction for softphones."
    
    # This seems necessary since the 'package require' only searches two
    # directory levels?
    lappend ::auto_path $scriptPath
    
    ::NotifyCall::Init
    
    variable wphone -

    variable phonenumber ""
    variable phoneNumberInput ""
    variable state -

    ::hooks::register loginHook             ::Phone::LoginHook
    # @@@ The Phone could be registered into a PBX, 
    # in that case it is independant of the Jabber network.
    # At this moment logoutHook only hide the Phone widget wich is wrong 
    # because the reason for hide the widget is when Asterisk (Or other PBX) 
    # says that the phone isn't registered.
    #    ::hooks::register logoutHook            ::Phone::LogoutHook
    ::hooks::register launchFinalHook       ::Phone::LoginHook

    option add *Phone.phone16Image              phone16          widgetDefault
    option add *Phone.phone16DisImage           phone16Dis       widgetDefault

    # Values for onhold -> no, hold, mute
    # Values for status -> returned by ::protocol:: library
    variable statePhone
    array set statePhone {
	registered          0
	activeLine          0
	onholdLine0         no
	statusLine0         free
	fromStateLine0      ""
	numberLine0         ""
	nameLine0           ""
	inputVolume0        0
	outputVolume0       0
	inputMuteVolume0    0
	outputMuteVolume0   0
	receivedDate0       -1
	initDate0           -1
	callLength0         0
    }
}

# These procedures handle registration, administration, and dispatching to
# softphone components.
#...............................................................................

proc ::Phone::RegisterPhone {name label initProc cmdProc deleteProc} {	
    variable phone
    
    set phone($name,name)        $name
    set phone($name,label)       $label
    set phone($name,init)        $initProc
    set phone($name,command)     $cmdProc
    set phone($name,delete)      $deleteProc
}

proc ::Phone::SetPhone {name} {
    variable phone

    # @@@ Call initProc ?
    set phone(previous) $phone(selected)
    set phone(selected) $name
}

proc ::Phone::GetPhone {} {
    variable phone
    
    return $phone(selected)
}

proc ::Phone::GetPreviousPhone {} {
    variable phone
    
    return $phone(previous)
}

proc ::Phone::GetAllPhones {} {
    variable phone
 
    set names {}
    foreach {key name} [array get phone *,name] {
	lappend names $name $phone($name,label)
    }
    return $names
}

proc ::Phone::InitPhone {} {
    variable phone
    
    set name $phone(selected)
    $phone($name,init)
}

# Phone::CommandPhone --
# 
#       Dispatches a command to the selected softphone.

proc ::Phone::CommandPhone {args} {
    variable phone
    
    # @@@ We could guard ourselves against no selected ("").
    set name $phone(selected)
    if {$name ne ""} {
	uplevel #0 $phone($name,command) $args
    }
}

proc ::Phone::DeletePhone {name} {
    variable phone
    
    $phone($name,delete)
}

#...............................................................................

proc ::Phone::LoadPrefs { } {
    variable statePhone
    
    CommandPhone loadprefs
    CommandPhone register

    set statePhone(inputVolume0) [CommandPhone getinputlevel]
    set statePhone(outputVolume0) [CommandPhone getoutputlevel]

    SetInputLevel [expr double($statePhone(inputVolume0))*100]
    SetOutputLevel [expr double($statePhone(outputVolume0))*100]

    InitPhone
    ::hooks::run phoneInit
}

proc ::Phone::LogoutHook {} {
    variable statePhone
    variable wphone

    if {[GetPhone] ne ""} {
	CommandPhone unregister
    
	if {[winfo exists $wphone]} {
	    set wnb [::JUI::GetNotebook]
	    $wnb forget $wphone
	    destroy $wphone
	}
    }
}

proc ::Phone::LoginHook {} {
    variable statePhone

    if {[GetPhone] ne ""} {
	LoadPrefs
    }

}

proc ::Phone::ShowPhone {} {
    if {[GetPhone] ne ""} {
        NewPage
        ::AddressBook::NewPage
    }
}

proc ::Phone::HidePhone {} {
    variable statePhone
    variable wphone

    if {[GetPhone] ne ""} {
        CommandPhone unregister
   
        if {[winfo exists $wphone]} {
            set wnb [::JUI::GetNotebook]
            $wnb forget $wphone
            destroy $wphone
        }
        ::AddressBook::CloseAddressBook
    }
}

##################################################
# Protocol Call Events
##################################################

proc ::Phone::IncomingCall {callNo remote remote_name} {
   variable statePhone
   variable wphone
   variable phoneNumberInput
   
   ::Debug 4 "::Phone::IncomingCall $callNo $remote $remote_name"

    # For the moment the phone just have one line
    if { $callNo == 0 } {
        # Set Active Line
        set statePhone(activeLine) $callNo
        set statePhone(fromStateLine0) "Incoming"
	
        # Set State for Incoming
        set statePhone(numberLine0) $remote
	set AddressBookName [::AddressBook::Search $remote]
	if { $AddressBookName ne "" } {
	    set statePhone(nameLine0) $AddressBookName
	} else {
	    set statePhone(nameLine0) $remote_name
	}

        set phoneNumberInput $remote

        set statePhone(receivedDate0) [clock seconds]

	if {[winfo exists $wphone]} {
            ::TPhone::Number $wphone $remote
        }

        set initLength 0
	if {[winfo exists $wphone]} {
	    ::TPhone::TimeUpdate $wphone  \
	      [clock format [expr {$initLength - 3600}] -format %X]
        } 
	
	::NotifyCall::TimeUpdate  \
	  [clock format [expr {$initLength - 3600}] -format %X]
	::NotifyCall::IncomingEvent $callNo $remote $statePhone(nameLine0)
	::AddressBook::ReceivedCall $callNo $remote $statePhone(nameLine0)
	SetIncomingState

	::hooks::run phoneNotifyIncomingCall $callNo $remote $statePhone(nameLine0)

    } else {
        puts "No more than one line, Reject"
    }
}

proc ::Phone::UpdateState {callNo state} {
    variable statePhone

    set statePhone(statusLine0) $state 
}

proc ::Phone::UpdateText {callno textmessage} {
    variable wphone

    if {[winfo exists $wphone]} {
        ::TPhone::SetSubject $wphone $textmessage
    }

    ::NotifyCall::SubjectEvent $textmessage
}

proc ::Phone::UpdateLevels {args} {
    variable statePhone
    variable wphone
    
    # Update Call Length
    if { $statePhone(initDate0) >= 0 } {
        set tempDate [clock seconds]
        set statePhone(callLength0) [expr $tempDate - $statePhone(initDate0)]
	if {[winfo exists $wphone]} {
	    ::TPhone::TimeUpdate $wphone  \
	      [clock format [expr {$statePhone(callLength0) - 3600}] -format %X]
	}
	::NotifyCall::TimeUpdate  \
	  [clock format [expr {$statePhone(callLength0) - 3600}] -format %X]
    }
}

proc ::Phone::UpdateRegister {id reply msgcount} {
    variable statePhone
    variable phoneMWI
    variable wphone

    # Sets MWI
    set phoneMWI 0
    if { $msgcount > 0} {
        set phoneMWI $msgcount
    }
    ::TPhone::MWIUpdate $wphone $phoneMWI
    
    # Registration Ok, start game
    if { $reply eq "ack"} {
        if {$state(registered) == 0} {
            SetNormalState
            set state(registered) 1
        }
    }

}

##################################################
# Build User Interface
##################################################

proc ::Phone::NewPage { } {
    variable statePhone
    variable wphone

    set wnb [::JUI::GetNotebook]
    set wphone $wnb.phone
    if {![winfo exists $wphone]} {
	set subPath [file join components Phone images]
	::TPhone::New $wphone ::Phone::Actions -class Phone -padding {8 4}
	set im  [::Theme::GetImage [option get $wphone phone16Image {}] $subPath]
	set imd [::Theme::GetImage [option get $wphone phone16DisImage {}] $subPath]
        set imSpec [list $im disabled $imd background $imd]
        $wnb add $wphone -text [mc Phone] -image $imSpec -compound image \
	  -sticky nw
    }

    #SetUnregisterState
}

proc ::Phone::NewTransferDlg {} {
    variable state
    variable transferPhoneNumber
    
    set w .phonetransfer
    
    # Make sure only single instance of this dialog.
    if {[winfo exists $w]} {
	raise $w
	return
    }
    ::UI::Toplevel $w -class PhoneDialer \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand [namespace current]::CloseCmd

    wm title $w [mc phoneDialerForward]
    
    ::UI::SetWindowPosition $w
    set phoneNumber ""

    # Global frame.
    ttk::frame $w.f
    pack  $w.f  -fill x
				 
    ttk::label $w.f.head -style Headlabel -text [mc {Phone}]
    pack  $w.f.head  -side top -fill both -expand 1

    ttk::separator $w.f.s -orient horizontal
    pack  $w.f.s  -side top -fill x

    set wbox $w.f.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack  $wbox  -fill both -expand 1
    
    set box $wbox.b
    ttk::frame $box
    pack $box -side bottom -fill x
    
    ttk::label $box.l -text "[mc phoneNumber]:"
    ttk::entry $box.e -textvariable [namespace current]::transferPhoneNumber  \
      -width 18
    ttk::button $box.dial -text [mc phoneDial]  \
      -command [list [namespace current]::TransferTo $w]
    ttk::button $box.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelEnter $w]

    grid  $box.l  $box.e  $box.dial $box.btcancel -padx 1 -pady 4
 
    focus $box.e
    wm resizable $w 0 0
}

proc ::Phone::CancelEnter {w} {

    ::UI::SaveWinGeom $w
    destroy $w
}

proc ::Phone::CloseCmd {w} {

    ::UI::SaveWinGeom $w
}

# Phone::Actions --
# 
#       This is the callback function for the TPhone megawidget.
# 
##################################################
# Phone Actions:
#    - Actions
#    - Touch
#    - Dial
#    - Hangup
#    - Hold / Unhold
#    - Mute / Unmute
#    - ChangeLine
#    - SetInputLevel
#    - SetOutputLevel
#    - transferTo
#
################################################

proc ::Phone::Actions { type args } {
        switch -- $type {
            call {
                Dial
            }
            hangup {
                Hangup
            }
            hangupjingle {
                Hangup
            }
            mute {
                set which [lindex $args 0]
                set onoff [lindex $args 1]
                Mute $which $onoff
            }
            speaker {
                SetOutputLevel [lindex $args 0]
            }
            microphone {
                SetInputLevel [lindex $args 0]
            }
            backspace {
                Touch 
            }
            0 - 1 - 2 - 3 - 4 - 5 - 6 - 7 - 8 - 9 - * - \# {
                Touch $type
            }
            transfer {
                NewTransferDlg
            }
            mwi {
                puts "Mwi pressed"
            }
            default {
                Touch $type
            }
        }
}

proc ::Phone::UpdateDisplay {text} {
    variable wphone
    variable phoneNumberInput

    set phoneNumberInput $text
    if {[winfo exists $wphone]} {
        ::TPhone::Number $wphone $text
    }
}

proc ::Phone::Touch {{key ""} {alt_key ""}} {
    variable phoneNumberInput
    variable statePhone
    variable wphone

    set phonenumber $statePhone(numberLine0)$key
    set phoneNumberInput $phonenumber

    # BackSpace key pressed.
    if { $key eq "" && $alt_key eq "" } {
        set last [string length $phonenumber]
        if { $last > 0} {
            set phonenumber [string range $phonenumber 0 [expr $last - 2] ]
            set phoneNumberInput $phonenumber
            ::TPhone::KeyDelete $wphone
        } else {
            #@@@ This is ugly tricky. 
            #@@@ What we can do  when Display different from phoneNumberInput,
            #@@@ Maybe remove all the display with the first backspace.
            ::Phone::UpdateDisplay ""
        }
    }
    set statePhone(numberLine0) $phoneNumberInput

    if { [lsearch {0 1 2 3 4 5 6 7 8 9 C * # D} $key] >= 0 } {
	CommandPhone playtone $key
	
        if { $statePhone(statusLine0) ne "free" } {
	    CommandPhone sendtone $key
        }
    }
}

# Phone::DialJingle --
# 
#       Public interface for the phone components, special for Jingle/IAX.

proc ::Phone::DialJingle  { ipPeer portPeer calledName callerName {user ""} {password ""} } {
    variable statePhone
    variable phoneNumberInput
    variable wphone 
    
    ::Debug 4 "::Phone::DialJingle ipPeer=$ipPeer,portPeer=$portPeer,calledName=$calledName"
    
    #---- Set Caller and Called Identification ------
    ::Phone::UpdateDisplay $calledName
    CommandPhone callerid "Jingle" $callerName

    #---- Make Dial ---------
    if { $ipPeer ne "" } {
        set phoneNumberInput "$ipPeer:$portPeer/"
    }

    set activeLine 0

    set statePhone(statusLine0) "outgoing"
    set statePhone(numberLine$activeLine) $phoneNumberInput
    set statePhone(onholdLine$activeLine) "no"

    set subject ""
    if {[winfo exists $wphone]} {
        set subject [::TPhone::GetSubject $wphone]
    }
    if {$subject eq ""} {
        set subject "Jingle Call"
    }

    ::NotifyCall::OutgoingEvent $calledName
    CommandPhone dialjingle $phoneNumberInput $statePhone(activeLine) $subject $user $password
    
    ::hooks::run phoneNotifyOutgoingCall $calledName
        
    set statePhone(fromStateLine0) "Dial"
    set statePhone(initDate0)  [clock seconds]
    SetDialState
 
}

proc ::Phone::Answer {} {

    ::Debug 4 "::Phone::Answer"
    
    set activeLine 0
    CommandPhone answer $activeLine

    hooks::run phoneNotifyTalkingState

    # IAX gets a notifier 'active complete' event which calls 'SetTalkingState'.
}

proc ::Phone::Dial {{phoneNumber ""}} {
    variable statePhone
    variable phoneNumberInput 
    variable wphone
    
    #----- if Dial is called from AddressBook -------
    if { $phoneNumber ne "" } {
        UpdateDisplay $phoneNumber
        set phoneNumberInput $phoneNumber
    }

    set activeLine 0
    set statePhone(numberLine$activeLine) $phoneNumberInput
    set statePhone(onholdLine$activeLine) "no"

    if { [lsearch $statePhone(statusLine0) "ringing"] >= 0 } {
	CommandPhone answer $activeLine
	::NotifyCall::TalkingEvent
	
	hooks::run phoneNotifyTalkingState
    } else {
	set subject [::TPhone::GetSubject $wphone]

        CommandPhone callerid
	CommandPhone dial $phoneNumberInput $statePhone(activeLine) $subject
        
        set statePhone(fromStateLine0) "Dial"
        set statePhone(initDate0)  [clock seconds]
	::AddressBook::Called $phoneNumberInput
        SetDialState
    }
}

# Phone::HangupJingle --
# 
#       Public interface for the phone components, special for Jingle/IAX.

proc ::Phone::HangupJingle {{callNo ""}} {
    variable statePhone

    ::Debug 4 "::Phone::HangupJingle"
    
    if { [lsearch $statePhone(statusLine0) "ringing"] >= 0 } {
        CommandPhone reject $statePhone(activeLine)
    } else {

	# @@@ Why do we change line?
	CommandPhone changeline $statePhone(activeLine)
        CommandPhone hangupjingle
    }

    # IAX gets a notifier free event which calls 'SetNormalState'.
}

proc ::Phone::Hangup {{callNo ""}} {
    variable statePhone

    ::Debug 4 "::Phone::Hangup"

    if { [lsearch $statePhone(statusLine0) "ringing"] >= 0 } {
	CommandPhone reject $statePhone(activeLine)
    } else {

	# @@@ Why do we change line?
	CommandPhone changeline $statePhone(activeLine)
	CommandPhone hangup
    }

    # IAX gets a notifier free event which calls 'SetNormalState'.
}

proc ::Phone::Mute {type onoff} {
    variable statePhone

    set line $statePhone(activeLine)
    set  onHoldLine "onholdLine$line"

    switch $onoff {
        "1" {
            set statePhone($onHoldLine) "no"
            if {$type eq "microphone"} {
                SetInputLevel [expr double($statePhone(inputMuteVolume$line))*100]
            } else {
                SetOutputLevel [expr double($statePhone(outputMuteVolume$line))*100]
            }
        }
        "0" {
            set statePhone($onHoldLine) "mute"                   
            if {$type eq "microphone"} {
                set statePhone(inputMuteVolume$line) [CommandPhone getinputlevel]
                SetInputLevel 0
            } else {
                set statePhone(outputMuteVolume$line) [CommandPhone getoutputlevel]
                SetOutputLevel 0
            }      
        }
    }
}

# Set/get audio levels. Note the rescaling of 100.

proc ::Phone::SetInputLevel {args} {
    variable statePhone
    variable wphone

    set inputLevel [expr double($args)/100.0]
    CommandPhone inputlevel $inputLevel
    set statePhone(inputVolume0) $inputLevel
    if {[winfo exists $wphone]} {
        ::TPhone::Volume $wphone microphone $args
    }
}

proc ::Phone::SetOutputLevel {args} {
    variable statePhone
    variable wphone

    set outputLevel [expr double($args)/100.0]
    CommandPhone outputlevel $outputLevel
    set statePhone(outputVolume0) $outputLevel

    if {[winfo exists $wphone]} {
        ::TPhone::Volume $wphone speaker $args
    }
}

proc ::Phone::GetInputLevel {} {
    return [expr {100.0*[CommandPhone getinputlevel]}]
}

proc ::Phone::GetOutputLevel {} {
    return [expr {100.0*[CommandPhone getoutputlevel]}]
}

proc ::Phone::TransferTo {w} {
    variable transferPhoneNumber

    CommandPhone transfer  $transferPhoneNumber
    destroy $w
    
    SetNormalState
}

#----------------------------- DialPad State -----------------------------------
#   ______________________________
#  |                              |
#  |                              v
#  |  --> Normal-----> Dial ----> Talking ---> Normal
#  |         |          |                      ^ ^
#  |         |          |______________________| |
#  |         v                                   |
#  |_____ Incoming ------------------------------+ 
#
# Dial. State originate by Dial button
# Normal. State is the Start state and it is originate by Hangup button or 
# Free event, too.
# All the others states are originate by Events
#
#-------------------------------------------------------------------------------

# These functions control all state changes and calls the selected softphone 
# component which is responsible for protocol stuff.
# 
# Note: try to call these only from the selected softphone to avoid
#       duplicate presence elements.
# 
# States: Normal, Dial, Talking, Incoming.

proc ::Phone::SetUnregisterState {} {

#    $wpath.pad.hangup configure -text "Hangup"
#    $wpath.pad.dial configure -text "Dial"
#
#    $wpath.pad.hangup state {disabled}
#    $wpath.pad.transfer state {disabled}
#    $wpath.pad.hold state {disabled}
#    $wpath.pad.mute state {disabled}
#    $wpath.pad.dial state {disabled}
#    $wpath.pad.c state {disabled}

#    set [namespace current]::phoneNumberInput ""

    SetNormalState

}

proc ::Phone::SetNormalState {{noCall ""}} {
    variable statePhone
    variable wphone
    
    ::Debug 4 "::Phone::SetNormalState"
    
    ###### Update Calls Logs (NormalState stands for Free or Hangup state too) ###########
    if { [info exists statePhone(fromStateLine0)] } {
        if { $statePhone(fromStateLine0) ne ""} {
            set type ""
            set date $statePhone(receivedDate0)
            switch $statePhone(fromStateLine0) {
                "Incoming" {
                    set type "Received"
                    if { $statePhone(callLength0) == 0 } {
                        set type "Missed"
                    }
                }
                "Dial" {
                    set type "Called"
                    set date $statePhone(initDate0)
                }
            }
	    ::AddressBook::UpdateLogs $type $statePhone(numberLine0) $statePhone(nameLine0) $date $statePhone(callLength0)
        }
    }
    
    ::AddressBook::NormalState
    ::NotifyCall::HangupEvent

    ::hooks::run phoneNotifyNormalState

    if {[winfo exists $wphone]} {
        ::TPhone::SetSubject $wphone ""
    }

    ####### Initialize State Machine information #########
    set statePhone(nameLine0)       ""
    set statePhone(initDate0)       -1
    set statePhone(receivedDate0)   -1
    set statePhone(callLength0)     0
    set statePhone(fromStateLine0)  ""
    set statePhone(statusLine0)     "free"
    set statePhone(activeLine)      0
    set statePhone(onholdLine0)     "no"
    
    ########## Sets Widget Buttons State ######################    
    if {[winfo exists $wphone]} {
        ::TPhone::State $wphone  "call"      {!disabled}
        ::TPhone::State $wphone  "backspace" {!disabled} 
        ::TPhone::State $wphone  "hangup"    {disabled}
        ::TPhone::State $wphone  "transfer"  {disabled}
    }

    ::Phone::CommandPhone state "available"
    ::hooks::run phoneChangeState "available"
}

proc ::Phone::SetDialState {} {
    variable wphone
    
    ::Debug 4 "::Phone::SetDialState"

    ########## Sets Widgets State ######################    
    if {[winfo exists $wphone]} {
        ::TPhone::State $wphone  "hangup"    {!disabled}
        ::TPhone::State $wphone  "call"      {disabled}
        ::TPhone::State $wphone  "transfer"  {disabled}
        ::TPhone::State $wphone  "backspace" {disabled}
    }

    ::Phone::CommandPhone state "ring"
    ::hooks::run phoneChangeState "ring"
}

proc ::Phone::SetTalkingState {{noCall ""} } {
    variable statePhone
    variable wphone
    
    ::Debug 4 "::Phone::SetTalkingState"
    
    set statePhone(initDate0)  [clock seconds]

    if {[winfo exists $wphone]} {
        ::TPhone::State $wphone  "hangup"    {!disabled}
        ::TPhone::State $wphone  "transfer"  {!disabled}
        ::TPhone::State $wphone  "call"      {disabled}
        ::TPhone::State $wphone  "backspace" {disabled}
    }

    ::AddressBook::TalkingState

    ::Phone::CommandPhone state "on_phone"
    ::hooks::run phoneChangeState "on_phone"
}

proc ::Phone::SetIncomingState { {noCall ""}} {
    variable statePhone
    variable wphone

    ::Debug 4 "::Phone::SetIncomingState"
    
    if {[winfo exists $wphone]} {
        ::TPhone::State $wphone  "hangup"    {!disabled}
        ::TPhone::State $wphone  "call"      {!disabled}
        ::TPhone::State $wphone  "transfer"  {disabled}
        ::TPhone::State $wphone  "backspace" {disabled}   
    }

    ::Phone::CommandPhone state "ring"
    ::hooks::run phoneChangeState "ring" 
}

############# TO-DO ##################
# Features:
#---------- Advanced ----------
# 3. Call Recording
# 4. Open three calls and mix channels, like an audio  conference room
# 5. Multi Server - Multi Protocol (Preferences)
#
# Known bugs and errors:
# ..... A lot of Debug work
