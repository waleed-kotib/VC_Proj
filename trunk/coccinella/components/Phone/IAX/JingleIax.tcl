# JingleIax.tcl --
# 
#       JingleIAX Component, binding for the IAX transport over Jingle 
#       
#  Copyright (c) 2006 Antonio Cano damas  
#  Copyright (c) 2006 Mats Bengtsson
#  
# $Id

namespace eval ::JingleIAX:: { }

proc ::JingleIAX::Init { } {
    variable xmlns
    variable xmlnsTransportIAX
    variable xmlnsMediaAudio
    variable feature
    variable featureMediaAudio
    variable featureTransportIAX

    if {[catch {package require stun}]} {
        return
    }

    component::register JingleIAX  \
      "Provides support for the VoIP P2P using IAX over Jingle"

    option add *Chat*callImage           call                 widgetDefault
    option add *Chat*callDisImage        callDis              widgetDefault

    # Add event hooks.
    ::hooks::register loginHook             ::JingleIAX::LoginHook
    ::hooks::register logoutHook            ::JingleIAX::LogoutHook
    ::hooks::register presenceHook          ::JingleIAX::PresenceHook

    ::hooks::register phoneChangeState      ::JingleIAX::SendInfo
    ::hooks::register rosterPostCommandHook ::JingleIAX::RosterPostCommandHook

    ::hooks::register buildChatButtonTrayHook  ::JingleIAX::BuildChatButtonTrayHook
    
    #------------ Disco Features ----------------
    set feature               "http://jabber.org/protocol/jingle"
    set featureMediaAudio     "http://jabber.org/protocol/jingle"
    set featureTransportIAX   "http://jabber.org/protocol/jingle"

    set xmlns                 "http://jabber.org/protocol/jingle"
    set xmlnsTransportIAX     "http://jabber.org/protocol/jingle/transport/iax"
    set xmlnsMediaAudio       "http://jabber.org/protocol/jingle/media/audio"

    #---- Register Disco ----
    ::Jabber::AddClientXmlns [list $xmlns $xmlnsMediaAudio $xmlnsTransportIAX]

    jlib::disco::registerfeature $feature
    jlib::disco::registerfeature $featureMediaAudio
    jlib::disco::registerfeature $featureTransportIAX

    #---- Register CAPS -----
    set subtags [list [wrapper::createtag "identity" -attrlist  \
        [list category hierarchy type leaf name "Jingle"]]]

    lappend subtags [wrapper::createtag "feature" \
      -attrlist [list var $feature]]

    ::Jabber::RegisterCapsExtKey jingle  $subtags

    #--------------- Variables Uses For PopUP Menus -------------------------
    variable popMenuDef
    set popMenuDef(call) {
	command  mCall     {user avaliable} {::JingleIAX::SessionInitiate $jid3} {}
    }

    #---------------  Other Variables and States ------------------
    variable state
    array set state {
        phoneserver     0
        setui           0
        remoteIP        127.0.0.1
        remoteIAXPort   4569
        localIP         127.0.0.1
        localAXPort     4569
    }
    variable contacts
}

proc ::JingleIAX::InitState {} {
    variable state
    global this

    #---- Initialize ------
    if {[catch {array set stunInfo [stun::get stun.fwdnet.net]} err]} {
	# @@@ What shall we do in this situation?
	puts "---> catch stun::get stun.fwdnet.net : $err"
	return
    }
    set state(remoteIP)  $stunInfo(-address)
    set state(remoteIAXPort) [::Iax::CmdProc getport]

    set state(localIP) $this(internalIPnum)
    set state(localIAXPort) $state(remoteIAXPort) 
}

#----------------------------------------------------------------------------
#----------------------- Login And Disco Messages ---------------------------
#----------------------------------------------------------------------------

proc ::JingleIAX::LoginHook { } {
    variable popMenuDef  
    variable xmlns

    ::Jabber::UI::RegisterPopupEntry roster $popMenuDef(call) 

    #---- Register handlers for Jingle iq elements.
    ::Jabber::JlibCmd iq_register set    $xmlns     ::JingleIAX::SessionAccept
}

proc ::JingleIAX::PresenceHook {jid type args} {
    variable contacts   
    set xmlnsdiscoinfo "http://jabber.org/protocol/disco#info"

    array set arrArgs $args
    Debug "::JingleIAX::PresenceHook"

    #--- If the jid send presence for first, try to Disco features ---
    if { ![info exists contacts($jid,jingle)] } {
        # Try to Disco if user support Jingle??????
	jlib::splitjidex $jid node domain -
        eval {::Jabber::JlibCmd disco send_get info $arrArgs(-from) ::JingleIAX::OnDiscoUserNode}
    }
}

proc ::JingleIAX::OnDiscoUserNode {jlibname type from subiq args} {
    variable xmlns
    variable state
    variable feature
    variable contacts
    
    Debug "::JingleIAX::OnDiscoUserNode"
 
    #-------- If the JID has Jingle support cache
    set contacts($from,jingle) "false"
    if {$type eq "result"} {
	set node [wrapper::getattribute $subiq "node"]
	set haveJingle [::Jabber::JlibCmd disco hasfeature $feature $from $node]

	Debug "\t from=$from, node=$node, havePhone=$haveJingle"

	if {$haveJingle} {
            set contacts($from,jingle) "true"
	}
    }
    puts "Setting $from --> $contacts($from,jingle)"

}

proc ::JingleIAX::LogoutHook { } {
    variable state

    ::Roster::DeRegisterPopupEntry mCall
    ::Jabber::UI::RemoveAlternativeStatusImage JingleIAX
    
    unset -nocomplain state
}

# Active/Disable the popupMenu if user is online or offline

proc ::JingleIAX::RosterPostCommandHook {wmenu jidlist clicked status} {
    variable state
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
    variable xmlns
    variable xmlnsTransportIAX
    variable xmlnsMediaAudio

    set myjid [::Jabber::JlibCmd getthis myjid]

    set transportElem [wrapper::createtag "transport" \
      -attrlist [list xmlns $xmlnsTransportIAX version 2] ]

    set mediaElemAudio [wrapper::createtag "description" \
      -attrlist [list xmlns $xmlnsMediaAudio] ]

    ##### sid has to be a random string?????
    set uid [jlib::generateuuid]
    set attr [list xmlns $xmlns action "initiate" initiator $myjid sid $uid]
    set jingleElem [wrapper::createtag "jingle"  \
      -attrlist $attr -subtags [list $mediaElemAudio $transportElem]]

    ::Jabber::JlibCmd send_iq set [list $jingleElem]  \
      -to $jid -command [list ::JingleIAX::SessionInitiateReply]

}


proc ::JingleIAX::SessionAccept {jlib from subiq args} {
    array set argsArr $args

    if {[info exists argsArr(-xmldata)]} {
        set jingle [wrapper::getfirstchildwithtag $argsArr(-xmldata) "jingle"]
        if { $jingle != {} } {
            set action [wrapper::getattribute $jingle action]

	    #---- Jingle Initiation
            if { $action eq "initiate"} {
                SessionAcceptInitiate $jlib $from $jingle $argsArr(-id)
            }

	    #---- Jingle Info (Extended Presence)
            if { $action eq "info" } {
                SessionAcceptInfo $jlib $from $jingle
            }
        }
    }
}

proc ::JingleIAX::SessionAcceptInfo {jlib from jingle args} {
    variable xmlns
    variable xmlnsTransportIAX
    variable xmlnsMediaAudio

    set state [wrapper::getfirstchildwithxmlns $jingle $xmlnsMediaAudio]
    if {$state  != {}} {
        set stateType [wrapper::gettag $state]
        if {$stateType eq ""} {
	    set stateType available
	}
	# Cache this info. 
	# @@@ How do we get unavailable status?
	# Must check for "normal" presence info.
	#set state(stateType,$from) $status

	set image [::Rosticons::Get [string tolower phone/$stateType]]
	::RosterTree::StyleSetItemAlternative $from jivephone image $image
    } 
}

proc ::JingleIAX::SessionAcceptInitiate {jlib from jingle id} {
    variable state
    variable xmlns
    variable xmlnsTransportIAX
    variable xmlnsMediaAudio

    set media [wrapper::getfirstchildwithtag $jingle "description"]
    if {$media  != {}} {
        set mediaType [wrapper::getattribute $media xmlns]
        if { $mediaType ne $xmlnsMediaAudio } {
            ::Jabber::JlibCmd send_iq_error $from $id 404 cancel service-unavailable {feature-not-implemented unsupported-media}
            return
        }
    } else {
        return
    }

    set transport [wrapper::getfirstchildwithtag $jingle "transport"]
    if {$transport  != {}} {

	# Test If we support the Transport IAX
        set transportType [wrapper::getattribute $transport xmlns]
        set version [wrapper::getattribute $transport version]
        if { ($transportType ne $xmlnsTransportIAX) && ($version ne 2) } {
            ::Jabber::JlibCmd send_iq_error $from $id 404 cancel service-unavailable {feature-not-implemented unsupported-transport}
            return
        }

        # -------- Transport Supported ------------------- 
        set myjid [::Jabber::JlibCmd getthis myjid]
        set transportElemSecure  [wrapper::createtag "secure" -chdata "no"]
        set transportElemLocalLocation    [wrapper::createtag location -attrlist [list type local ip $state(localIP)  port  $state(localIAXPort)] ]
        set transportElemRemoteLocation   [wrapper::createtag location -attrlist [list type remote ip $state(remoteIP) port  $state(remoteIAXPort)]]

        set transportElem [wrapper::createtag transport \
            -attrlist [list xmlns $xmlnsTransportIAX version 2] \
            -subtags  [list $transportElemLocalLocation \
                            $transportElemRemoteLocation \
                            $transportElemSecure ] ]

	# @@@ This is wrong. Shall get sid from xml.
	set uid [jlib::generateuuid]
        set attr [list xmlns $xmlns action "accept" initiator $myjid sid $uid]
        set jingleElem [wrapper::createtag jingle  \
              -attrlist $attr \
              -subtags [list $transportElem]]

         #------ JEP-0166 , has to be an iq type set with action=accept
         ::Jabber::JlibCmd send_iq result [list $jingleElem] -to $from -id $id
    } 
}

proc ::JingleIAX::SessionInitiateReply {type subiq args} {

    #--------- Comes an Error from Initiate --------
    if { ($type eq "error") || ($type eq "cancel")} {
	ui::dialog -icon error -type ok -message [mc phoneFailedCalling] \
	  -detail $subiq
    }

    #--------- Comes an Accept from Initiate --------
    if {$type eq "result"} {
	::JingleIAX::SessionAcceptAck $subiq
    }
}

proc ::JingleIAX::SessionAcceptAck {args} {
    variable xmlnsTransportIAX
    variable state

    # Extract the command level XML data items.     
    set jingle [wrapper::gettag $args]
    set calledname [wrapper::getattribute $jingle initiator]

    if { $jingle != {} } {
        set transport [wrapper::getfirstchildwithtag $jingle "transport"]

        if {$transport != {}} {
            
	    # We have to test if the Transport and version are supported
            set transportType [wrapper::getattribute $transport xmlns]
            set version [wrapper::getattribute $transport version]
            if { ($transportType ne $xmlnsTransportIAX) && ($version ne 2) } {
                ::Jabber::JlibCmd send_iq_error $from $id 404 cancel service-unavailable {feature-not-implemented unsuported-transport}
                return
            }

            set locationList [wrapper::getchildswithtag $transport location]
            if {$locationList != {}} {
                foreach location $locationList {
                    set type [wrapper::getattribute $location type]
                    if {$type ne ""} {
                            set locationDescription($type,ip) [wrapper::getattribute $location ip]
                            set locationDescription($type,port) [wrapper::getattribute $location port]
                    } else {
                        ::Jabber::JlibCmd send_iq_error $from $id 404 cancel bad-request
                        return
                    }
                }
            } else {
                ::Jabber::JlibCmd send_iq_error $from $id 404 cancel bad-request
                return
            }

            set secureElem [wrapper::getfirstchildwithtag $transport secure]
            if {$secureElem != {}} {
                set secure [wrapper::getcdata $secureElem]
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
            #------ 1/ Discover what location to use, local or remote --------
            #------------- 2/ Give control to Phone Component ----------------
            set ip   $locationDescription(remote,ip)
            set port $locationDescription(remote,port)
            if {$ip eq $state(remoteIP)} {
                set ip   $locationDescription(local,ip)
                set port $locationDescription(local,port)
            }

            ::Phone::DialJingle $ip $port $calledname [::Jabber::JlibCmd getthis myjid] $user $password
        }
    }
}

#-------------------------------------------------------------------------
#----------------------- Jingle Session Info -----------------------------
# @@@@@@@	STILL NOT WELL DEFINED INTO JINGLE SESSION 0166/ Use MediaAudio instead (0167)
#-------------------------------------------------------------------------

proc ::JingleIAX::SendInfo {state} {
    variable contacts

    set listJID [::Jabber::RosterCmd getusers]

    #---- Send Info to all the contacts on the roster that has support for Jingle ----
    if {[info exists listJID] } {
        foreach jid $listJID {
            if { $contacts($jid,jingle) eq "true" } {
                ::JingleIAX::SetIqInfo $jid $state 
            }
       }
    }
}

proc ::JingleIAX::SetIqInfo {jid state} {
    variable xmlns
    variable xmlnsMediaAudio

    set myjid [::Jabber::JlibCmd getthis myjid]

    set infoElem [wrapper::createtag $state \
        -attrlist [list xmlns $xmlnsMediaAudio] ]

    set uid [jlib::generateuuid]
    set attr [list xmlns $xmlns action "info" initiator $myjid sid $uid]
    set jingleElem [wrapper::createtag "jingle"  \
      -attrlist $attr -subtags [list $infoElem]]

    ::Jabber::JlibCmd send_iq set [list $jingleElem] -to $jid 
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
    set jid [::Chat::GetChatTokenValue $chattoken jid3]

    if { $contacts($jid,jingle) eq "true" } {
        ::JingleIAX::SessionInitiate $jid
    }
}

proc ::JingleIAX::Debug {msg} {

    if {0} {
        puts "-------- $msg"
    }
}
