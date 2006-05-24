# Iax.tcl --
# 
#       Phone component for the iax client.
#       It must handle things on two levels:
#         o the iaxclient library; transport level
#         o the Jingle protocol; signalling level
#         
#       Initiating is started on the protocol level (jingle) and first when
#       that is established the transport (iaxclient) is invoked.
#       
#  Copyright (c) 2006 Mats Bengtsson
#  Copyright (c) 2006 Antonio Cano damas
#  
# $Id: Iax.tcl,v 1.14 2006-05-24 17:14:59 antoniofcano Exp $

namespace eval ::Iax { }

proc ::Iax::Init { } {

    if {![component::exists Phone]} {
	return
    }
    if {[catch {package require iaxclient}]} {
	return
    }
    if {[catch {package require IaxPrefs}]} {
	return
    }
    if {[catch {package require JingleIax}]} {
	return
    }
    component::register IAX "Provides the iax client softphone."
    
    ::Phone::RegisterPhone iax "IAX Phone"  \
      ::Iax::InitProc ::Iax::CmdProc ::Iax::DeleteProc
    
    # Setting up Callbacks functions.
    iaxclient::notify <State>         [namespace current]::NotifyState
    iaxclient::notify <Registration>  [namespace current]::NotifyRegister
    iaxclient::notify <Levels>        [namespace current]::NotifyLevels
    iaxclient::notify <NetStats>      [namespace current]::NotifyNetStats
    iaxclient::notify <Text>          [namespace current]::NotifyText
    
    # @@@ temporary
    ::Phone::SetPhone iax
    
    ::JingleIAX::Init

    # Keep track of internal iaxclient state to be able to detect changes.
    variable iaxstate
    set iaxstate(old) "free"
    set iaxstate(now) "free"
    
    # Register ID.
    set iaxstate(registerid) -
}

proc ::Iax::InitProc {} {
    # Empty.
}

# Iax::CmdProc --
# 
#       This is our registered command procedure that gets invoked from the
#       Phone component.

proc ::Iax::CmdProc {type args} {
    variable iaxstate
    
    ::Debug 4 "::Iax::CmdProc type=$type, args=$args"
    
    set value [lindex $args 0]

    switch -- $type {
	answer {
	    iaxclient::answer $value
	    #::Phone::SetTalkingState
	}
	callerid {
	    eval CallerID $args
	}
	changeline {
	    iaxclient::changeline $value
	}
	dial {
	    eval Dial $args
	}
	dialjingle {
	    eval DialJingle $args
	}
	getinputlevel {
	    return [iaxclient::level input]
	}
	getoutputlevel {
	    return [iaxclient::level output]
	}	
	getport {
	    return [iaxclient::getport]
	}
	hangup {
	    iaxclient::hangup
	}
        hangupjingle {

	    # Handle both transport and protocol levels.
            iaxclient::hangup
            ::JingleIAX::SessionTerminate
        }
	hold {
	    #iaxclient::hold $value
	}
	inputlevel {
	    iaxclient::level input $value 
	}
	loadprefs {
	    eval LoadPrefs $args
	}
	outputlevel {
	    iaxclient::level output $value 
	}
	playtone {
	    iaxclient::playtone $value 
	}
	register {
	    eval Register $args
	}
	reject {
	    iaxclient::reject $value
	}
	sendtone {
	    iaxclient::sendtone $value
	}
	state {
	    eval ::JingleIAX::SendJinglePresence $args
	}
	transfer {
	    iaxclient::transfer $value
	}
	unhold {
	    #iaxclient::unhold $value
	}
	unregister {
	    if {[string is integer -strict $iaxstate(registerid)]} {
		iaxclient::unregister $iaxstate(registerid)
	    }
	}
    }
}

proc ::Iax::DeleteProc {} {
    
}

proc ::Iax::Register {} {
    variable iaxstate
   
    # Set plain variable names.
    foreach {name value} [::IaxPrefs::GetAll] {
	set $name $value
    }

    # If Host is blank then we don't  need to register into the PBX
    if {$host ne ""} {
        set iaxstate(registerid) [iaxclient::register $user $password $host]
    }

    ## This is tricky, when we got two iaxclient instances in the same box 
    ## the second one has the port 0
    # the socket is initialized with a random port one register is called
    ::JingleIAX::InitState
}

#---------------------------------------------------------------------------
#--------------------------- Protocol CallBacks Hooks ----------------------
#---------------------------------------------------------------------------

proc ::Iax::NotifyLevels {args} {
    
    # This callbak is called every X milliseconds during the call
    # It is intended for level meters (todo)
    # We are using for counting the call duration length in the TPhone Widget and NotifyCall too 
    ::Phone::UpdateLevels $args
}

proc ::Iax::NotifyNetStats {args} {
#    puts "NetStats: $args"
}

proc ::Iax::NotifyText { type callno textmessage args} {
    if { $type eq "-" && $textmessage ne ""} {
	::Phone::UpdateText $callno $textmessage
    }
}

proc ::Iax::NotifyRegister {id reply msgcount} {
    variable iaxstate

    ::Debug 4 "::Iax::NotifyRegister id=$id, reply=$reply"
    
    switch -- $reply {
	timeout {
	    if {$iaxstate(registerid) == $id} {
		::Phone::HidePhone
	    }
	}
	ack {
	    ::Phone::ShowPhone
	    ::Phone::UpdateRegister $id $reply $msgcount
	}
    }
}

# Iax::NotifyState --
# 
#       Callback when the iaxclient state changes.
#       This controls the phone state and all state changes such as extended
#       presence originate from here.
#       The Phone component then delegates the state change to the selected
#       softphone component (us).

proc ::Iax::NotifyState {callNo state codec remote remote_name args} {
    variable iaxstate

    ::Debug 4 "::Iax::NotifyState state=$state, old=$iaxstate(now)"
    
    # Do this to be able to do string comparisons on lists.
    set state [lsort $state]

    # Push the state change on our internal cache.
    set iaxstate(old) $iaxstate(now)
    set iaxstate(now) $state
    
    # Skip non changes which we get from changeline actions.
    if {$state eq $iaxstate(old)} {
	return
    }
    ::Phone::UpdateState $callNo $state

    #----------------------------------------------------------------------
    #------------ Sending Outgoing/Incoming Calls actions -----------------
    #----------------------------------------------------------------------
    #----- Originate Outgoing Call
    if { $state eq [list active outgoing ringing] } {
	iaxclient::ringstart 0
    }

    # Connect Peers Right (Outgoing & Incoming calls).
    if { [lsearch $state "complete"] >= 0 } {
	::Phone::SetTalkingState $callNo
	iaxclient::ringstop
    }

    #----- Incoming Call Notify
    if { $state eq [list active ringing] } {
	::Phone::IncomingCall $callNo $remote $remote_name
	iaxclient::ringstart 1
    }

    #----- Connection free (incoming & outgoing) Or ChangeLine,
    #--------- IAXClient sometimes return free state for a changeline action
    if { $state eq "free" || $state eq "selected"  } {
	::Phone::SetNormalState $callNo
	iaxclient::ringstop
    } 
}

#---------------------------------------------------------------------------
#------------------------------- Protocol Actions --------------------------
#---------------------------------------------------------------------------

proc ::Iax::CallerID { {_cidname ""} {_cidnum ""} } {

    # Set plain variable names. Note name conflicts!
    foreach {name value} [::IaxPrefs::GetAll] {
	set $name $value
    }

    if { $_cidname eq "" } {
        iaxclient::callerid $cidname $cidnum
    } else {
        iaxclient::callerid $_cidname $_cidnum
    }
}

proc ::Iax::DialJingle {peer {line ""} {subject ""} {user ""} {password ""}} {

    ::Debug 4 "::Iax::DialJingle peer=$peer"
    
    if {$line eq ""} {
	set callNo 1 
    } else {
	set callNo $line
    }
    set callNo 1 

    #---- Peer String: IP[:Port]/extension
    #---- Dial Peer String: [user[:password]@]peer
    set userDef ""
    if {$user ne ""} {
        append userDef $user
    }
    if {$password ne ""} {
	append userDef ":$password"
    }
    if {$userDef ne ""} {
	append userDef "@"
    }

    #----- Dial Peer -------
    ::Debug 4 "\t iaxclient::dial $userDef$peer $callNo"
    iaxclient::dial ${userDef}${peer} $callNo
    if { $subject ne "" } {
	iaxclient::sendtext $subject
    }
}

proc ::Iax::Dial {phonenumber {line ""} {subject ""}} {

    ::Debug 4 "::Iax::Dial phonenumber=$phonenumber "
    
    # Set plain variable names.
    foreach {name value} [::IaxPrefs::GetAll] {
	set $name $value
    }

    if {$line eq ""} {
	set callNo 1 
    } else {
	set callNo $line
    }
    set callNo 1 
 
    ::Debug 4 "\t iaxclient::dial ..."
    iaxclient::dial "${user}:${password}@${host}/${phonenumber}" $callNo
    if { $subject ne "" } {
	iaxclient::sendtext $subject
    }
}

#---------------------------------------------------------------------------
#------------------------- Protocol Preferences Actions --------------------
#---------------------------------------------------------------------------

proc ::Iax::LoadPrefs {} {
    global prefs
    
    ::Debug 4 "::Iax::LoadPrefs"

    # Set plain variable names.
    foreach {name value} [::IaxPrefs::GetAll] {
	set $name $value
    }
    set echo 0

    iaxclient::applyfilters $agc $aagc $comfort $noise $echo

    # Pick matching device name.
    foreach device [iaxclient::devices output] {
	if { [lindex $device 0] eq $outputDevices} {
	    iaxclient::setdevices output [lindex $device 1]
	    break
	}
    }
    foreach device [iaxclient::devices input] {
	if { [lindex $device 0] eq $inputDevices} {
	    iaxclient::setdevices input [lindex $device 1]
	    break
	}
    }
    
    iaxclient::callerid $cidname $cidnum
    if {$codec ne ""} {
        iaxclient::formats $codec
    }

    iaxclient::toneinit 880 960 16000 48000 10
}

proc ::Iax::Reload {} {
    variable iaxstate

    if {[string is integer -strict $iaxstate(registerid)]} {
	if { $iaxstate(registerid) >= 0 } {
	    ::iaxclient::unregister $iaxstate(registerid)
	}
    }
    LoadPrefs
    Register
}
