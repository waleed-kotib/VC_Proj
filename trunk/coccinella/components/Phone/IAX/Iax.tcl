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
# $Id: Iax.tcl,v 1.10 2006-04-21 08:19:04 antoniofcano Exp $

namespace eval ::Iax { }

proc ::Iax::Init { } {

    variable iaxPrefs

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

    array set iaxPrefs {
	registerid   -
        user         ""
        password     ""
        host         ""
        cidname      ""
        cidnum       ""
        codecs       ""
    }
    
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
}

proc ::Iax::InitProc {} {
    # Empty.
}

# Iax::CmdProc --
# 
#       This is our registered command procedure that gets invoked from the
#       Phone component.

proc ::Iax::CmdProc {type args} {
    variable iaxPrefs
    
    ::Debug 4 "::Iax::CmdProc type=$type, args=$args"
    
    set value [lindex $args 0]

    switch -- $type {
	answer {
	    iaxclient::answer $value
	    #::Phone::SetTalkingState
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
        callerid {
            eval CallerID $args
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
	getinputlevel {
	    return [iaxclient::level input]
	}
	getoutputlevel {
	    return [iaxclient::level output]
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
	transfer {
	    iaxclient::transfer $value
	}
	unhold {
	    #iaxclient::unhold $value
	}
	unregister {
	    if {[string is integer -strict $iaxPrefs(registerid)]} {
		iaxclient::unregister $iaxPrefs(registerid)
	    }
	}
    }
}

proc ::Iax::DeleteProc {} {
    
}

proc ::Iax::Register {} {
    variable iaxPrefs
   
    set iaxPrefs(registerid) [iaxclient::register $iaxPrefs(user) $iaxPrefs(password) $iaxPrefs(host)]

    ## This is tricky, when we got two iaxclient instances in the same box 
    ## the second one has the port 0
    # the socket is initialized with a random port one register is called
    ::JingleIAX::InitState
}

#---------------------------------------------------------------------------
#--------------------------- Protocol CallBacks Hooks ----------------------
#---------------------------------------------------------------------------

proc ::Iax::NotifyLevels {args} {
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
    variable iaxPrefs

    ::Debug 4 "::Iax::NotifyRegister id=$id, reply=$reply"
    
    if { ($iaxPrefs(registerid) == $id) && ($reply eq "timeout") } {
        ::Phone::HidePhone
    }

    if { $reply eq "ack"} {
        ::Phone::ShowPhone
        ::Phone::UpdateRegister $id $reply $msgcount
    }
}

proc ::Iax::NotifyState {callNo state codec remote remote_name args} {

    ::Debug 4 "::Iax::NotifyState state=$state"
    
    # Do this to be able to do string comparisons on list.
    set state [lsort $state]
    ::Phone::UpdateState $callNo $state

    #----------------------------------------------------------------------
    #------------ Sending Outgoing/Incoming Calls actions -----------------
    #----------------------------------------------------------------------
    #----- Originate Outgoing Call
    if { $state eq [list active outgoing ringing] } {
	iaxclient::ringstart 0
    }

    # Connect Peers Right (Outgoing & Incoming calls)
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

proc ::Iax::CallerID { {cidname ""} {cidnum ""} } {
    variable iaxPrefs

    if { $cidname eq "" } {
        iaxclient::callerid $iaxPrefs(cidname) $iaxPrefs(cidnum)
    } else {
        iaxclient::callerid $cidname $cidnum
    }
}

proc ::Iax::DialJingle {peer {line ""} {subject ""} {user ""} {password ""}} {
    variable iaxPrefs

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
        set userDef $user
    }
    if {$password ne ""} {
        set userDef "$userDef:$password"
    }
    if {$userDef ne ""} {
        set userDef "$userDef@"
    }

    #----- Dial Peer -------
    ::Debug 4 "\t iaxclient::dial $userDef$peer $callNo"
    iaxclient::dial "$userDef$peer" $callNo
    if { $subject ne "" } {
	iaxclient::sendtext $subject
    }
}

proc ::Iax::Dial {phonenumber {line ""} {subject ""}} {
    variable iaxPrefs

    ::Debug 4 "::Iax::Dial phonenumber=$phonenumber "
    
    if {$line eq ""} {
	set callNo 1 
    } else {
	set callNo $line
    }
    set callNo 1 
 
    ::Debug 4 "\t iaxclient::dial ..."
    iaxclient::dial "$iaxPrefs(user):$iaxPrefs(password)@$iaxPrefs(host)/$phonenumber" $callNo
    if { $subject ne "" } {
	iaxclient::sendtext $subject
    }
}

proc ::Iax::LoadPrefs {} {
    global prefs
    variable iaxPrefs
    
    set iaxPrefs(user)			$prefs(iaxPhone,user)
    set iaxPrefs(password)		$prefs(iaxPhone,password)
    set iaxPrefs(host)	 	        $prefs(iaxPhone,host) 
    set iaxPrefs(cidnum)		$prefs(iaxPhone,cidnum)
    set iaxPrefs(cidname)		$prefs(iaxPhone,cidname)
    set iaxPrefs(codec)			$prefs(iaxPhone,codec)
    
    if { $prefs(iaxPhone,agc) eq ""} {
	set value 0
    } else {
	set value $prefs(iaxPhone,agc)
    }
    set iaxPrefs(agc)			$value

    if { $prefs(iaxPhone,aagc) eq ""} {
	set value 0
    } else {
	set value $prefs(iaxPhone,aagc)
    }
    set iaxPrefs(aagc)			$value
    
    if { $prefs(iaxPhone,noise) eq ""} {
	set value 0
    } else {
	set value $prefs(iaxPhone,noise)
    }
    set iaxPrefs(noise)			$value
    
    if { $prefs(iaxPhone,comfort) eq ""} {
	set value 0
    } else {
	set value $prefs(iaxPhone,comfort)
    }
    set iaxPrefs(comfort)		$value

#    if { $prefs(iaxPhone,echo) eq ""} {
#	set value 0
#    } else {
#	set value $prefs(iaxPhone,echo)
#    }

    set value 0
    set iaxPrefs(echo)		$value

    iaxclient::applyfilters $iaxPrefs(agc) $iaxPrefs(aagc) $iaxPrefs(comfort) $iaxPrefs(noise) $iaxPrefs(echo)

    set iaxPrefs(outputDevices)		""
    set listOutputDevices [iaxclient::devices output]
    foreach {device} $listOutputDevices {
        if { [lindex $device 0] eq $prefs(iaxPhone,outputDevices)} {
	    set iaxPrefs(outputDevices) [lindex $device 1]
	    iaxclient::setdevices output $iaxPrefs(outputDevices) 
	}
    }

    set iaxPrefs(inputDevices)		""
    set listInputDevices [iaxclient::devices "input"]
    foreach {device} $listInputDevices {
        if { [lindex $device 0] eq $prefs(iaxPhone,inputDevices)} {
	    set iaxPrefs(inputDevices) [lindex $device 1] 
	    iaxclient::setdevices input $iaxPrefs(inputDevices)
	}
    }

    iaxclient::callerid $iaxPrefs(cidname) $iaxPrefs(cidnum)
    if {$iaxPrefs(codec) ne ""} {
        iaxclient::formats $iaxPrefs(codec)
    }

    iaxclient::toneinit 880 960 16000 48000 10
}

proc ::Iax::Reload {} {
    variable iaxPrefs

    if { $iaxPrefs(registerid) >= 0 } {
	::iaxclient::unregister $iaxPrefs(registerid)
    }
    LoadPrefs
    Register
}
