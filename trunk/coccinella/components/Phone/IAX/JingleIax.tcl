# JingleIax.tcl --
# 
#       JingleIAX package, binding for the IAX transport over Jingle 
#       
#  Copyright (c) 2006 Antonio Cano damas  
#  Copyright (c) 2006 Mats Bengtsson
#  
# $Id: JingleIax.tcl,v 1.10 2006-03-27 10:06:49 antoniofcano Exp $

if {[catch {package require stun}]} {
    return
}

if {[catch {package require jlib::jingle}]} {
    return
}

package provide JingleIax 0.1

namespace eval ::JingleIAX:: { }

proc ::JingleIAX::Init { } {
    variable xmlnsTransportIAX
    variable xmlnsMediaAudio

    set xmlnsTransportIAX     "http://jabber.org/protocol/jingle/transport/iax"
    set xmlnsMediaAudio       "http://jabber.org/protocol/jingle/media/audio"


    option add *Chat*callImage           call                 widgetDefault
    option add *Chat*callDisImage        callDis              widgetDefault

    # Add event hooks.
    ::hooks::register loginHook             ::JingleIAX::LoginHook
    ::hooks::register logoutHook            ::JingleIAX::LogoutHook
    ::hooks::register presenceHook          ::JingleIAX::PresenceHook

    ::hooks::register phoneChangeState      ::JingleIAX::SendJinglePresence
    ::hooks::register rosterPostCommandHook ::JingleIAX::RosterPostCommandHook

    ::hooks::register buildChatButtonTrayHook  ::JingleIAX::BuildChatButtonTrayHook


    #--------------- Variables Uses For PopUP Menus -------------------------
    variable popMenuDef
    set popMenuDef(call) {
	command  mCall     {user avaliable} {::JingleIAX::SessionInitiate $jid3} {}
    }

    #---------------  Other Variables and States ------------------
    variable state
    array set state {
        publicIP        127.0.0.1
        publicIAXPort   0
        localIP         127.0.0.1
        localIAXPort    0
	sid             ""
    }

    # -------- Register Jingle --------
    variable transportElem
    variable mediaElemAudio

    set transportElem [wrapper::createtag "transport" \
      -attrlist [list xmlns $xmlnsTransportIAX version 2 secure no] ]
    set mediaElemAudio [wrapper::createtag "description" \
      -attrlist [list xmlns $xmlnsMediaAudio] ]

    jlib::jingle::register iax 50  \
      [list $mediaElemAudio] [list $transportElem] ::JingleIAX::IQHandler

    variable contacts
}

proc ::JingleIAX::InitState {} {
    global this
    variable state

    set tempPort $state(localIAXPort)
    if { $tempPort == 0 } {
        set tempPort [::Iax::CmdProc getport]
    }

    set state(publicIAXPort) $tempPort 
    set state(localIAXPort)  $tempPort


    set state(localIP) $this(ipnum)
    #---- Gets Public IP  ------
    ::stun::request stun.fwdnet.net -command ::JingleIAX::StunCB

}

proc ::JingleIAX::StunCB {token status args} {
    variable state
    array set arrArgs $args

    if {$status eq "ok" && [info exists arrArgs(-address)]} {
        set state(publicIP)  $arrArgs(-address)
    }
}

#----------------------------------------------------------------------------
#----------------------- Login And Disco Messages ---------------------------
#----------------------------------------------------------------------------

proc ::JingleIAX::LoginHook { } {
    variable popMenuDef  

#    set state(publicIP) 127.0.0.1
#    set state(localIP) 127.0.0.1
#    set state(localIAXPort) 0
#    set state(publicIAXPort) 0

    InitState

    ::Jabber::UI::RegisterPopupEntry roster $popMenuDef(call) 
}

proc ::JingleIAX::LogoutHook { } {
    variable state

    ::Roster::DeRegisterPopupEntry mCall
    ::Jabber::UI::RemoveAlternativeStatusImage JingleIAX
    
#    unset -nocomplain state
}

# Active/Disable the popupMenu if user is online or offline

proc ::JingleIAX::RosterPostCommandHook {wmenu jidlist clicked status} {
    variable contacts
    variable popMenuDef

    set jid [lindex $jidlist 0]

    Debug "RosterPostCommandHook $jidlist $clicked $status"

    ::Roster::SetMenuEntryState $wmenu mCall disabled
    if {$status ne "available"} {
	return
    }

    if { [info exists contacts($jid,jingle)] } {
        if { $contacts($jid,jingle) eq "true"} {
            ::Roster::SetMenuEntryState $wmenu mCall normal
        }
    }
}

#-------------------------------------------------------------------------
#------------------- Jingle Session State Machine ------------------------
#-------------------------------------------------------------------------

proc ::JingleIAX::SessionInitiate {jid} {
    variable state
    variable transportElem
    variable mediaElemAudio
    variable myjid

    set state(sid) [::Jabber::JlibCmd jingle initiate iax $jid  \
      [list $mediaElemAudio] [list $transportElem] ::JingleIAX::SessionPending]
}


proc ::JingleIAX::IQHandler {jlib _jelem args} {
    array set argsArr $args
    variable state

    array set argsArr $args
    set id $argsArr(-id)
    set sid    [wrapper::getattribute $_jelem sid]
    set action [wrapper::getattribute $_jelem action]

    switch -- $action {
        "session-initiate" {
             SessionInitiateIncoming $jlib $argsArr(-from) $_jelem $sid $id
        }   
        "transport-accept" {
	    TransportIncomingAccept $jlib $argsArr(-from) $_jelem $sid $id
        }
    }
}

proc ::JingleIAX::SessionInitiateIncoming {jlib from jingle sid id} {
    variable state

    ::Jabber::JlibCmd send_iq result {} -to $from -id $id
    set state(sid) $sid
    TransportAccept $jlib $from

}

proc ::JingleIAX::TransportAccept {jlib from} {
    variable state
    global prefs

    # -------- Transport Supported ------------------- 
    set transportElemLocalCandidate    [wrapper::createtag candidate -attrlist [list name local ip $state(localIP)  port  $state(localIAXPort)] ]
    set transportElempublicCandidate   [wrapper::createtag candidate -attrlist [list name public ip $state(publicIP) port  $state(publicIAXPort)]]

    set transportElemCustomCandidate ""
    if { $prefs(NATip) ne "" } {
        set transportElemCustomCandidate   [wrapper::createtag candidate -attrlist [list name custom ip $prefs(NATip)  port  $state(publicIAXPort)]]
    }

    set transportElem [wrapper::createtag "transport" \
      -attrlist [list xmlns "http://jabber.org/protocol/jingle/transport/iax" version 2] \
      -subtags [list $transportElemLocalCandidate $transportElempublicCandidate $transportElemCustomCandidate]]

    ::Jabber::JlibCmd jingle send_set $state(sid) "transport-accept" {}  \
      [list $transportElem ]
    ::Jabber::JlibCmd jingle send_set $state(sid) "session-accept" {}
}

proc ::JingleIAX::SessionPending {type subiq args} {
    #--------- Comes an Error from Initiate --------
    if { ($type eq "error") || ($type eq "cancel")} {
	ui::dialog -icon error -type ok -message [mc phoneFailedCalling] \
	  -detail $subiq
    }
}

proc ::JingleIAX::TransportIncomingAccept {jlib from jingle sid id} {
    variable state
    variable xmlnsTransportIAX

    # Extract the command level XML data items.     
    #set jingle [wrapper::gettag $args]

    #set calledname [wrapper::getattribute $jingle initiator]   
    set transport [wrapper::getfirstchildwithtag $jingle "transport"]

    if {$transport != {}} { 
        # We have to test if the Transport and version are supported
        set transportType [wrapper::getattribute $transport xmlns]
        set version [wrapper::getattribute $transport version]
        set secure [wrapper::getattribute $transport secure]

        if { ($transportType ne $xmlnsTransportIAX) && ($version ne 2) } {
            ::Jabber::JlibCmd send_iq_error $from $id 404 cancel service-unavailable {feature-not-implemented unsuported-transport}
            return
        }

        set candidateList [wrapper::getchildswithtag $transport candidate]
        if {$candidateList != {}} {
            foreach candidate $candidateList {
                set name [wrapper::getattribute $candidate name]
                if {$name ne ""} {
                    set candidateDescription($name,ip) [wrapper::getattribute $candidate ip]
                    set candidateDescription($name,port) [wrapper::getattribute $candidate port]
                } else {
                    ::Jabber::JlibCmd send_iq_error $from $id 404 cancel bad-request
                    return
                }
            }
        } else {
            ::Jabber::JlibCmd send_iq_error $from $id 404 cancel bad-request
            return
        }

        # ------------- User and Password, returned by Asterisk PBX node -------------
        # ------- Are OPTIONAL
        set userElem [wrapper::getfirstchildwithtag $transport user]
        if {$userElem != {}} {
            set user [wrapper::getcdata $userElem]
        } else {
            set user ""
        }
        set pwdElem [wrapper::getfirstchildwithtag $transport password]
        if {$pwdElem != {}} {
            set password [wrapper::getcdata $pwdElem]
        } else {
            set password ""
        }
        #-------- At This moment we know how to call the Peer ------------
        #------ 1/ Discover what candidate to use: custom, local or public --------
        #------------- 2/ Give control to Phone Component ----------------
       

        if { [info exists candidateDescription(custom,ip)] } { 
            set ip   $candidateDescription(custom,ip)
            set port $candidateDescription(custom,port)
        } else {
            set ip   $candidateDescription(public,ip)
            set port $candidateDescription(public,port)

            if {$ip eq $state(publicIP)} {
                set ip   $candidateDescription(local,ip)
                set port $candidateDescription(local,port)
            }
        }
        ::Phone::DialJingle $ip $port $from [::Jabber::JlibCmd getthis myjid] $user $password
    }
}

#-------------------------------------------------------------------------
#---------------------- (Extended Presence) ------------------------------
#-------------------------------------------------------------------------
proc ::JingleIAX::PresenceHook {jid type args} {
    variable contacts   

    Debug "::JingleIAX::PresenceHook"
    array set argsArr $args

    #------- Set jingle status icon  ---------
    set isJID [string first "@" $argsArr(-from)]
    if { [info exists argsArr(-status)] && $isJID > 0 } {
        set jingleStatusIndex [string first - $argsArr(-status)]
        set jingleType        [string range $argsArr(-status) 0 [expr $jingleStatusIndex-1]]
        set jingleStatus      [string range $argsArr(-status) [expr $jingleStatusIndex+1] [expr [string length $argsArr(-status)] - 1] ]

        #------- Status spected to come in jingle-xxxxxx format, this is tricky 
        #------- correct way maybe using some tag <jingle status='xxxx'/> into presence xml info
        if {[::Jabber::RosterCmd haveroster]} {
            if { $jingleType eq "jingle" } {
                set image [::Rosticons::Get [string tolower phone/$jingleStatus]]
                ::RosterTree::StyleSetItemAlternative $argsArr(-from) jivephone image $image
            }
        }
    }

    #--- If the jid send presence for first, try to Disco features ---
    if { ![info exists contacts($jid,jingle)] } {
        # Try to Disco if user support Jingle??????
	jlib::splitjidex $jid node domain -
        array set arrArgs $args
        eval {::Jabber::JlibCmd disco send_get info $arrArgs(-from) ::JingleIAX::OnDiscoUserNode}
    }
}

proc ::JingleIAX::OnDiscoUserNode {jlibname type from subiq args} {
    variable contacts
    variable state

    Debug "::JingleIAX::OnDiscoUserNode"
 
    #-------- If the JID has Jingle support cache
    if {$type eq "result"} {
	set node [wrapper::getattribute $subiq "node"]
        set feature "http://jabber.org/protocol/jingle"
	set haveJingle [::Jabber::JlibCmd disco hasfeature $feature $from $node]

	Debug "\t from=$from, node=$node, havePhone=$haveJingle"

	if {$haveJingle} {
            if { ![info exists contacts($from,jingle)] } {
                #---- Cache the new Jingle Contact -------
                set contacts($from,jingle) "true"

                #----- Sends our Jingle Presence for the new available contact --------
                ::Jabber::JlibCmd send_presence -show available -status "jingle-available"
            }
	} 
    } else {
        set contacts($from,jingle) "false"
    }
}


proc ::JingleIAX::SendJinglePresence {state} {
    variable contacts

    #---- Send Info to all the contacts on the roster that Jingle Extended Presence ----
    if { $state ne "available" } {
        set show "dnd"
    } else {
        set show "available"
    }
    ::Jabber::JlibCmd send_presence -show $show -status "jingle-$state"
}

#-------------------------------------------------------------------------
#------------------- Jingle Chat UI Call Button --------------------------
#-------------------------------------------------------------------------

proc ::JingleIAX::BuildChatButtonTrayHook {wtray dlgtoken args} {

    set w [::Chat::GetDlgTokenValue $dlgtoken w]	
    set iconCall    [::Theme::GetImage [option get $w callImage {}]]
    set iconCallDis [::Theme::GetImage [option get $w callDisImage {}]]

    $wtray newbutton call  \
      -text [mc phoneMakeCall] -image $iconCall  \
      -disabledimage $iconCallDis   \
      -command [list ::JingleIAX::ChatCall $dlgtoken]
}

proc ::JingleIAX::ChatCall {dlgtoken} {
    variable contacts
    set chattoken [::Chat::GetActiveChatToken $dlgtoken]
    set jid [::Chat::GetChatTokenValue $chattoken jid]
    if {[info exists contacts($jid,jingle)] } {
        if { $contacts($jid,jingle) eq "true" } {
	    SessionInitiate $jid
        }
    }
}

proc ::JingleIAX::Debug {msg} {

    if {0} {
        puts "-------- $msg"
    }
}
