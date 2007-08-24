# JingleIax.tcl --
# 
#       JingleIAX package, binding for the IAX transport over Jingle 
#       
#  Copyright (c) 2006 Antonio Cano damas  
#  Copyright (c) 2006 Mats Bengtsson
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
# $Id: JingleIax.tcl,v 1.37 2007-08-24 13:33:13 matben Exp $

if {[catch {package require stun}]} {
    return
}

if {[catch {package require jlib::jingle}]} {
    return
}

package provide JingleIax 0.1

namespace eval ::JingleIAX:: { }

proc ::JingleIAX::Init { } {
    
    option add *Chat*callImage           call                 widgetDefault
    option add *Chat*callDisImage        callDis              widgetDefault
    
    variable xmlns
    set xmlns(jingle)     "http://jabber.org/protocol/jingle/"
    set xmlns(media)      "http://jabber.org/protocol/jingle/media/audio"    
    set xmlns(transport)  "http://jabber.org/protocol/jingle/transport/iax"

    # Add event hooks.
    ::hooks::register initHook              ::JingleIAX::InitHook
    ::hooks::register jabberInitHook        ::JingleIAX::JabberInitHook
    ::hooks::register loginHook             ::JingleIAX::LoginHook
    ::hooks::register logoutHook            ::JingleIAX::LogoutHook
    ::hooks::register presenceHook          ::JingleIAX::PresenceHook
    ::hooks::register presenceHook          ::JingleIAX::PresenceHangUpHook
    ::hooks::register rosterPostCommandHook ::JingleIAX::RosterPostCommandHook
    ::hooks::register buildChatButtonTrayHook  ::JingleIAX::BuildChatButtonTrayHook
    ::hooks::register chatTabChangedHook    ::JingleIAX::ChatTabChangedHook
    
    # This shall be done generically and dispatched to relevant softphone.
    #--------------- Variables Uses For PopUP Menus -------------------------
    variable popMenuDef
    variable popMenuType
    set popMenuDef(call) {
	command  mCall {::JingleIAX::SessionInitiate $jid3}
    }
    set popMenuType(call) {
	mCall  {user avaliable}
    }

    #---------------  Other Variables and States ------------------
    variable state
    array set state {
        public,ip     127.0.0.1
        public,port   0
        local,ip      127.0.0.1
        local,port    0
	sid           ""
    }

    # Register Jingle.
    variable transportElem
    variable mediaElem

    set transportElem [wrapper::createtag "transport" \
      -attrlist [list xmlns $xmlns(transport) version 2 secure no] ]
    set mediaElem [wrapper::createtag "description" \
      -attrlist [list xmlns $xmlns(media)] ]

    jlib::jingle::register iax 50  \
      [list $mediaElem] [list $transportElem] ::JingleIAX::IQHandler
}

proc ::JingleIAX::InitHook {} {
    variable popMenuDef  
    variable popMenuType
        
    ::Roster::RegisterPopupEntry $popMenuDef(call) $popMenuType(call)
}

# JingleIAX::JabberInitHook --
# 
#       Gets called for each new jlib instance.
#       Do jlib instance specific stuff here.

proc ::JingleIAX::JabberInitHook {jlib} {
    variable xmlns

    # Caps specific iax stuff.
    set subtags [list [wrapper::createtag "identity"  \
      -attrlist [list category hierarchy type leaf name "IAX Phone"]]]
    lappend subtags [wrapper::createtag "feature" \
      -attrlist [list var $xmlns(transport)]]

    $jlib caps register iax $subtags $xmlns(transport)

    # @@@ Subject to experimentation!
    # Add an: 	  
    #   <x xmlns='http://jabber.org/protocol/jingle/media/audio' type='available'/>

    $jlib register_presence_stanza [GetXPresence available] -type available
}

proc ::JingleIAX::GetXPresence {type} {
    variable xmlns
    
    # @@@ Perhaps 'available' should be left out as usual.
    return [wrapper::createtag x -attrlist [list xmlns $xmlns(media) type $type]]
}

#----------------------------------------------------------------------------
#----------------------- Inits and Hooks ------------------------------------
#----------------------------------------------------------------------------

proc ::JingleIAX::LoginHook { } {

    InitState
}

proc ::JingleIAX::InitState {} {
    global this
    variable state

    set tempPort $state(local,port)
    if { $tempPort == 0 } {
	set tempPort [::Iax::CmdProc getport]
    }
    set state(public,port) $tempPort 
    set state(local,port)  $tempPort
    set state(local,ip)    $this(ipnum)

    #---- Gets Public IP  ------
    ::stun::request stun.fwdnet.net -command ::JingleIAX::StunCB
}

proc ::JingleIAX::StunCB {token status args} {
    variable state
    array set argsA $args

    if {$status eq "ok" && [info exists argsA(-address)]} {
	set state(public,ip)  $argsA(-address)
    }
}

proc ::JingleIAX::LogoutHook { } {

    ::JUI::RemoveAlternativeStatusImage JingleIAX
}

# JingleIAX::RosterPostCommandHook --
# 
#       Active/Disable the menu entry depending on JID.

proc ::JingleIAX::RosterPostCommandHook {m jidlist clicked status} {
    variable xmlns

    Debug "RosterPostCommandHook jidlist=$jidlist, clicked=$clicked, status=$status"

    set jid [lindex $jidlist 0]
    set midx [::AMenu::GetMenuIndex $m mCall]
    if {$midx eq ""} {
	# Probably a submenu.
	return
    }
    $m entryconfigure $midx -state disabled
    if {$status ne "available"} {
	return
    }
    
    # Check for the extended presence.
    set xelem [::Jabber::RosterCmd getx $jid "jingle/media/audio"]
    if {$xelem ne {}} {
	set status [wrapper::getattribute $xelem type]
	if {$status eq "available"} {
	    $m entryconfigure $midx -state normal
	}
    }
}

#-------------------------------------------------------------------------
#------------------- Jingle Session State Machine ------------------------
#-------------------------------------------------------------------------

# Initiator.....................................................................

proc ::JingleIAX::SessionInitiate {jid} {
    variable state
    variable transportElem
    variable mediaElem
    
    Debug "::JingleIAX::SessionInitiate $jid"

    set state(sid) [::Jabber::JlibCmd jingle initiate iax $jid  \
      [list $mediaElem] [list $transportElem] ::JingleIAX::SessionInitiateCB]
}

# JingleIAX::SessionInitiateCB --
#
#       This is the callback from 'SessionInitiate'.
#       We normally expect a single 'result' element but need to cancel
#       the call if an error.

proc ::JingleIAX::SessionInitiateCB {type subiq args} {
    
    Debug "::JingleIAX::SessionInitiateCB"
    
    #--------- Comes an Error from Initiate --------
    if { ($type eq "error") || ($type eq "cancel")} {
	
	# Cleanup!
	SessionTerminate
	ui::dialog -icon error -type ok -message [mc phoneFailedCalling] \
	  -detail $subiq
    }
}

# JingleIAX::SessionTerminate --
# 
#       This is supposed to terminate a session and trigger all cleaning up.
#       Shall also work to call in case of any errors during a call.

proc ::JingleIAX::SessionTerminate {} {
    variable state
    
    # @@@ Do we need to take any further action (iaxclient::hangup)?

    ::Jabber::JlibCmd jingle send_set $state(sid) "session-terminate"  \
      ::JingleIAX::EmptyCB
    set state(sid) ""
}

# Target (handlers).............................................................

# JingleIAX::IQHandler --
# 
#       This is our registered jlib jingle handler.

proc ::JingleIAX::IQHandler {jlib jelem args} {
    array set argsA $args
    variable state

    Debug "::JingleIAX::IQHandler"
    
    array set argsA $args
    set id   $argsA(-id)
    set from $argsA(-from)
    set sid    [wrapper::getattribute $jelem sid]
    set action [wrapper::getattribute $jelem action]

    switch -- $action {
        "session-initiate" {
             SessionInitiateHandler $from $jelem $sid $id
        }   
        "transport-accept" {
	    TransportAcceptHandler $from $jelem $sid $id
        }
	"session-terminate" {
	    SessionTerminateHandler $from $jelem $sid $id
	}
    }
    return
}

# JingleIAX::SessionInitiateHandler --
# 
#       Handler for a 'session-initiate' action.

proc ::JingleIAX::SessionInitiateHandler {from jingle sid id} {
    variable state

    Debug "::JingleIAX::SessionInitiateHandler from=$from, sid=$sid, id=$id"

    # XEP-0166: In order to decline the session initiation request, the target 
    # entity MUST acknowledge receipt of the session initiation request, then 
    # terminate the session.

    ::Jabber::JlibCmd send_iq result {} -to $from -id $id
    
    # Must check that we are free to answer.
    if {([iaxclient::state] eq "free") && ($state(sid) eq "")} {
	set state(sid) $sid
	TransportAccept $from
    } else {
	
	# Need a direct call since state(sid) can be busy with another sid.
	::Jabber::JlibCmd jingle send_set $sid "session-terminate"  \
	  ::JingleIAX::EmptyCB
    }
}

# JingleIAX::TransportAccept --
# 
#       This formulates our response to an incoming 'session-initiate' action.

proc ::JingleIAX::TransportAccept {from} {
    global prefs
    variable state
    variable xmlns

    Debug "::JingleIAX::TransportAccept from=$from"

    # -------- Transports Supported ------------------- 
    set locAttr [list name local ip $state(local,ip) port $state(local,port)]
    set localElem [wrapper::createtag "candidate" -attrlist $locAttr]
    set candidateElems [list $localElem]

    # Add only the public candidate if we've got a stun answer.
    if {$state(public,ip) ne "127.0.0.1"} {
	set pubAttr [list name public ip $state(public,ip) port $state(public,port)]
	set publicElem [wrapper::createtag "candidate" -attrlist $pubAttr]
	lappend candidateElems $publicElem
    }
    
    # Add only the hardcoded custom ip if nonempty.
    if {$prefs(NATip) ne ""} {
	set cusAttr [list name custom ip $prefs(NATip) port $state(public,port)]
	set customElem [wrapper::createtag "candidate" -attrlist $cusAttr]
	lappend candidateElems $customElem
    }

    set transportElem [wrapper::createtag "transport" \
      -attrlist [list xmlns $xmlns(transport) version 2] \
      -subtags $candidateElems]

    ::Jabber::JlibCmd jingle send_set $state(sid) "transport-accept"  \
      ::JingleIAX::EmptyCB [list $transportElem]
    ::Jabber::JlibCmd jingle send_set $state(sid) "session-accept"    \
      ::JingleIAX::EmptyCB
}

proc ::JingleIAX::EmptyCB {args} {
    
    # Empty.
}

# JingleIAX::TransportAcceptHandler --
# 
#       Handles incoming 'transport-accept' actions from the jingle handler.

proc ::JingleIAX::TransportAcceptHandler {from jingle sid id} {
    variable state
    variable xmlns

    Debug "::JingleIAX::TransportAcceptHandler"

    # Extract the command level XML data items.     
    #set jingle [wrapper::gettag $args]

    #set calledname [wrapper::getattribute $jingle initiator]   
    set transport [wrapper::getfirstchildwithtag $jingle "transport"]

    if {$transport ne {}} { 

	# We have to test if the Transport and version are supported
        set transportType [wrapper::getattribute $transport xmlns]
        set version [wrapper::getattribute $transport version]
        set secure [wrapper::getattribute $transport secure]

        if { ($transportType ne $xmlns(transport)) && ($version ne 2) } {
	    ::Jabber::JlibCmd jingle send_error $from $id unsupported-transports
	    SessionTerminate
            return
        }

        set candidateList [wrapper::getchildswithtag $transport candidate]
        if {$candidateList eq {}} {
	    ::Jabber::JlibCmd jingle send_error $from $id unsupported-media
	    SessionTerminate
	    return
	}
	foreach candidate $candidateList {
	    set name [wrapper::getattribute $candidate name]
	    if {$name ne ""} {
		set candidateDesc($name,ip) [wrapper::getattribute $candidate ip]
		set candidateDesc($name,port) [wrapper::getattribute $candidate port]
	    } else {
		::Jabber::JlibCmd send_iq_error $from $id 404 cancel bad-request
		SessionTerminate
		return
	    }
	}
	
        # ------------- User and Password, returned by Asterisk PBX node -------
        # ------- Are OPTIONAL
	set user ""
	set password ""
	set userElem [wrapper::getfirstchildwithtag $transport user]
        if {$userElem ne {}} {
            set user [wrapper::getcdata $userElem]
        }
        set pwdElem [wrapper::getfirstchildwithtag $transport password]
        if {$pwdElem ne {}} {
            set password [wrapper::getcdata $pwdElem]
        }
	
        #-------- At This moment we know how to call the Peer ------------
        #------ 1/ Discover what candidate to use: custom, local or public
        #------------- 2/ Give control to Phone Component ----------------
       	
	# Search the candidates in priority order.
	foreach name {custom public local} {
	    if {[info exists candidateDesc($name,ip)]} { 
		set ip   $candidateDesc($name,ip)
		set port $candidateDesc($name,port)
		break
	    }
	}
	
	# Sort a list of {host port} candidates in priority order.
	set cands {}
	foreach name {custom public local} {
	    if {[info exists candidateDesc($name,ip)]} { 
		set ip   $candidateDesc($name,ip)
		set port $candidateDesc($name,port)

		# If both users are on the same LAN they also have identical 
		# public IP. Exclude this candidate.
		if {$ip ne $state(public,ip)} {
		    lappend cands [list $ip $port]
		}
	    }
	}
	
	# If both users are on the same LAN they also have identical public IP.
	if {$ip eq $state(public,ip)} {
	    set ip   $candidateDesc(local,ip)
	    set port $candidateDesc(local,port)
	}	

	# @@@ We should provide a list of candidates to ::Phone::DialJingle.
	# There should be some kind of callback from 'DialJingle' for this???
	Debug "\t ::Phone::DialJingle ip=$ip, port=$port"
	set myjid [::Jabber::JlibCmd getthis myjid]
        if {0} {
	    ::Phone::DialJingle $ip $port $from $myjid $user $password
	} else {
	    ::Phone::DialJingleCandidates $cands $from $myjid $user $password
	}
    }
}

proc ::JingleIAX::SessionTerminateHandler {from jingle sid id} {
    variable state
    
    Debug "::JingleIAX::SessionTerminateHandler from=$from"
    
    ::Jabber::JlibCmd send_iq result {} -to $from -id $id
    set state(sid) ""
    
    # @@@ Do we need to take any further action (iaxclient::hangup)?
}

# JingleIAX::PresenceHangUpHook --
# 
#       The Jingle XEP specifies that if a user we have a session with becomes
#       unavailable we must close down the call.

proc ::JingleIAX::PresenceHangUpHook {jid type args} {
    variable state
    
    # Beware! jid without resource!
    Debug "::JingleIAX::PresenceHangUpHook jid=$jid, type=$type, $args"

    if {$type eq "unavailable"} {
	set sid $state(sid)
	if {[::Jabber::JlibCmd jingle havesession $sid]} {
	    array set argsA $args
	    set from $argsA(-from)
	    set jjid [::Jabber::JlibCmd jingle getvalue $sid jid]
	    if {[jlib::jidequal $jjid $from]} {
		::Phone::HangupJingle
	    }
	}
    }
}

#-------------------------------------------------------------------------
#---------------------- (Extended Presence) ------------------------------
#-------------------------------------------------------------------------

proc ::JingleIAX::PresenceHook {jid type args} {

    # Beware! jid without resource!
    Debug "::JingleIAX::PresenceHook jid=$jid, type=$type"
    
    if {$type ne "available"} {
	return
    }
    if {![::Jabber::RosterCmd isitem $jid]} {
	return
    }
    
    # Some transports propagate the complete prsence stanza.
    if {[::Roster::IsTransportHeuristics $jid]} {
	return
    }
    
    array set argsA $args
    set from $argsA(-from)

    # Set roster status icon if user has extended presence.
    set xelem [::Jabber::RosterCmd getx $from "jingle/media/audio"]
    if {$xelem ne {}} {
	set status [wrapper::getattribute $xelem type]
	set image [::Rosticons::Get [string tolower phone/$status]]
	::RosterTree::StyleSetItemAlternative $from jivephone image $image
    } 
    
    # As an alternative to extended presence we may have used the caps.
    if {0} {
	set ext [::Jabber::RosterCmd getcapsattr $from ext]
	if {[lsearch $ext iax] >= 0} {
	    ::Jabber::JlibCmd caps disco_ext $from iax ::JingleIAX::CapsDiscoCB
	}
    }
}

# Note the 'from' !!!!

proc ::JingleIAX::CapsDiscoCB {jlibname type from subiq args} {
    
    Debug "::JingleIAX::CapsDiscoCB"

    if {$type eq "result"} {
    
	
    }
}

# JingleIAX::SendJinglePresence --
# 
#       Sends our phone presence type using x-element.

proc ::JingleIAX::SendJinglePresence {type} {

    Debug "::JingleIAX::SendJinglePresence type=$type"

    # Send Info to all the contacts on the roster that Jingle Extended Presence.
    ::Jabber::JlibCmd register_presence_stanza [GetXPresence $type]  \
      -type available
    ::Jabber::SyncStatus
}

#-------------------------------------------------------------------------
#------------------- Jingle Chat UI Call Button --------------------------
#-------------------------------------------------------------------------

proc ::JingleIAX::BuildChatButtonTrayHook {wtray dlgtoken args} {

    # @@@ We must have a way to set state of this button when tab changes!!!
    set w [::Chat::GetDlgTokenValue $dlgtoken w]
    set subPath [file join components Phone images]
    set iconCall    [::Theme::GetImage [option get $w callImage {}] $subPath]
    set iconCallDis [::Theme::GetImage [option get $w callDisImage {}] $subPath]

    $wtray newbutton call  \
      -text [mc phoneMakeCall] -image $iconCall  \
      -disabledimage $iconCallDis   \
      -command [list ::JingleIAX::ChatCall $dlgtoken]

    set chattoken [::Chat::GetActiveChatToken $dlgtoken]
    SetChatButtonState $chattoken
}

proc ::JingleIAX::ChatCall {dlgtoken} {

    set chattoken [::Chat::GetActiveChatToken $dlgtoken]
    set jid [::Chat::GetChatTokenValue $chattoken jid]
    set xelem [::Jabber::RosterCmd getx $jid "jingle/media/audio"]
    if {$xelem ne {}} {
	SessionInitiate $jid
    }
}

proc ::JingleIAX::ChatTabChangedHook {chattoken} {
 
    SetChatButtonState $chattoken
}

proc ::JingleIAX::SetChatButtonState {chattoken} {
    
    set dlgtoken [::Chat::GetChatTokenValue $chattoken dlgtoken]
    set wtray [::Chat::GetDlgTokenValue $dlgtoken wtray]
    set jid [::Chat::GetChatTokenValue $chattoken jid]
    set xelem [::Jabber::RosterCmd getx $jid "jingle/media/audio"]
    if {$xelem ne {}} {
	set state normal
    } else {
	set state disabled
    }
    $wtray buttonconfigure call -state $state
}

proc ::JingleIAX::Debug {msg} {
    if {0} {
        puts "-------- $msg"
    }
}
