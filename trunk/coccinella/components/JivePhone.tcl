# JivePhone.tcl --
# 
#       JivePhone bindings for the jive server and Asterisk.
#       
#       Contributions and testing by Antonio Cano damas
#       
# $Id: JivePhone.tcl,v 1.13 2005-12-05 15:20:32 matben Exp $

# My notes on the present "Phone Integration Proto-JEP" document from
# Jive Software:
# 
#   1) server support for this is indicated by the disco child of the server
#      where it should instead be a disco info feature element.
#      
#   2) "The username must be set as the node attribute on the query"
#      when obtaining info if a particular user has support for this.
#      This seems wrong since only a specific instance of a user specified
#      by an additional resource can have specific features.

#    I could imagine a dialer as a tab page, but then we need nice buttons.
#

namespace eval ::JivePhone:: { }

proc ::JivePhone::Init { } {
    
    component::register JivePhone  \
      "Provides support for the VoIP notification in the jive server"
        
    # Add event hooks.
    ::hooks::register presenceHook    ::JivePhone::PresenceHook
    ::hooks::register newMessageHook  ::JivePhone::MessageHook
    ::hooks::register loginHook       ::JivePhone::LoginHook
    ::hooks::register logoutHook      ::JivePhone::LogoutHook
    
    variable xmlns
    set xmlns(jivephone) "http://jivesoftware.com/xmlns/phone"
    
    # Note the difference!
    variable feature
    set feature(jivephone) "http://jivesoftware.com/phone"
    
    variable statuses {AVAILABLE RING DIALED ON_PHONE HANG_UP}
    variable state
    array set state {
	phoneserver     0
	setui           0
	win             .dial
    }

    variable menuDef
    set menuDef {
	command  mCall     {user available} {::JivePhone::DialJID $jid "DIAL"} {}
	command  mForward  {user available} {::JivePhone::DialJID $jid "FORWARD"} {}
    }

}

proc ::JivePhone::LoginHook { } {
    
    set server [::Jabber::GetServerJid]
    ::Jabber::JlibCmd disco get_async items $server ::JivePhone::OnDiscoServer   
}

proc ::JivePhone::OnDiscoServer {jlibname type from subiq args} {
    variable state
    
    Debug "::JivePhone::OnDiscoServer"
        
    # See comments above what my opinion is...
    if {$type eq "result"} {
	set childs [::Jabber::JlibCmd disco children $from]
	foreach service $childs {
	    set name [::Jabber::JlibCmd disco name $service]
	    
	    Debug "\t service=$service, name=$name"

	    if {$name eq "phone"} {
		set state(phoneserver) 1
		set state(service) $service
		break
	    }
	}
    }
    if {$state(phoneserver)} {
	
	# @@@ It is a bit unclear if we shall disco the phone service with
	# the username as each node.
	
	# We may not yet have obtained the roster. Sync issue!
	if {[::Jabber::RosterCmd haveroster]} {
	    DiscoForUsers
	} else {
	    ::hooks::register rosterExit ::JivePhone::RosterHook
	}
    }
}

proc ::JivePhone::RosterHook {} {
        
    Debug "::JivePhone::RosterHook"
    ::hooks::deregister rosterExit ::JivePhone::RosterHook
    DiscoForUsers
}

proc ::JivePhone::DiscoForUsers {} {
    variable state
    
    Debug "::JivePhone::DiscoForUsers"
    set users [::Jabber::RosterCmd getusers]
    
    # We add ourselves to this list to figure out if we've got a jive phone.
    lappend users [::Jabber::JlibCmd getthis myjid2]
    
    foreach jid $users {
	jlib::splitjidex $jid node domain -	
	if {[::Jabber::GetServerJid] eq $domain} {
	    ::Jabber::JlibCmd disco get_async info $state(service)  \
	      ::JivePhone::OnDiscoUserNode -node $node
	}
    }
}

proc ::JivePhone::OnDiscoUserNode {jlibname type from subiq args} {
    variable xmlns
    variable state
    variable feature
    
    Debug "::JivePhone::OnDiscoUserNode"
    
    if {$type eq "result"} {
	set node [wrapper::getattribute $subiq "node"]
	set havePhone [::Jabber::JlibCmd disco hasfeature $feature(jivephone)  \
	  $from $node]
	#puts "\t from=$from, node=$node, havePhone=$havePhone"
	if {$havePhone} {
	
	    # @@@ What now?
	    # @@@ But if we've already got phone presence?

	    # Really stupid! It assumes user exist on login server.
	    set server [::Jabber::JlibCmd getserver]
	    set jid [jlib::joinjid $node $server ""]
	    #puts "\t jid=$jid"
	    
	    # Since we added ourselves to the list take action if have phone.
	    set myjid2 [::Jabber::JlibCmd getthis myjid2]
	    if {[jlib::jidequal $jid $myjid2]} {
		WeHavePhone
	    } else {
	    
		# Attempt to set icon only if this user is unavailable since
		# we do not have the full jid!
		# This way we shouldn't interfere with phone presence.
		# We could use [roster isavailable $jid] instead.
		
		set item [::RosterTree::FindWithTag [list jid $jid]]
		if {$item ne ""} {
		    set image [::Rosticons::Get [string tolower phone/available]]
		    ::RosterTree::StyleSetItemAlternative $jid jivephone  \
		      image $image
		}
	    }
	}
    }
}

proc ::JivePhone::WeHavePhone { } {
    variable state
    variable menuDef
    
    if {$state(setui)} {
	return
    }
    ::Jabber::UI::RegisterPopupEntry roster $menuDef
    
    set image [::Rosticons::Get [string tolower phone/available]]
    set win [::Jabber::UI::SetAlternativeStatusImage jivephone $image]
    bind $win <Button-1> [list ::JivePhone::DoDial "DIAL"]
    
    set state(setui) 1
}

proc ::JivePhone::LogoutHook { } {
    variable state
    
    unset -nocomplain state
    set state(phoneserver) 0
    set state(setui) 0
}

# JivePhone::PresenceHook --
# 
#       A user's presence is updated when on a phone call.

proc ::JivePhone::PresenceHook {jid type args} {
    variable xmlns

    Debug "::JivePhone::PresenceHook jid=$jid, type=$type, $args"
    
    if {$type ne "available"} {
	return
    }

    array set argsArr $args
    if {[info exists argsArr(-xmldata)]} {
	set xmldata $argsArr(-xmldata)
	set elems [wrapper::getchildswithtagandxmlns $xmldata  \
	  phone-status $xmlns(jivephone)]
	if {$elems ne ""} {
	    set from [wrapper::getattribute $xmldata from]
	    set elem [lindex $elems 0]
	    set status [wrapper::getattribute $elem "status"]
	    if {$status eq ""} {
		set status available
	    }
	    set image [::Rosticons::Get [string tolower phone/$status]]
	    ::RosterTree::StyleSetItemAlternative $from jivephone image $image
	    
	    eval {::hooks::run jivePhonePresence $from $type} $args
	}
    }
    return
}

# JivePhone::MessageHook --
#
#       Events are sent to the user when their phone is ringing, ...
#       ... message packets are used to send events for the time being. 

proc ::JivePhone::MessageHook {body args} {    
    variable xmlns
    variable state
    variable callID

    Debug "::JivePhone::MessageHook $args"
    
    array set argsArr $args
    if {[info exists argsArr(-xmldata)]} {
	set elem [wrapper::getfirstchildwithtag $argsArr(-xmldata)  \
	  "phone-event"]
	if {$elem != {}} {
	    set status [wrapper::getattribute $elem "status"]
	    if {$status eq ""} {
		set status available
	    }
	    set cidElem [wrapper::getfirstchildwithtag $elem callerID]
	    if {$cidElem != {}} {
		set cid [wrapper::getcdata $cidElem]
	    } else {
		set cid [mc {Unknown}]
	    }
	    set image [::Rosticons::Get [string tolower phone/$status]]
	    set win [::Jabber::UI::SetAlternativeStatusImage jivephone $image]
	    
	    set type [wrapper::getattribute $elem "type"]

	    # @@@ What to do more?
	    if {$type == "RING" } {
		set callID [wrapper::getattribute $elem "callID"]
		bind $win <Button-1> [list ::JivePhone::DoDial "FORWARD"]
		eval {::hooks::run jivePhoneEvent $type $cid} $args
	    }
	    if {$type == "HANG_UP"} {
		bind $win <Button-1> [list ::JivePhone::DoDial "DIAL"]
		eval {::hooks::run jivePhoneEvent $type $cid} $args
	    }
	    
	    # Provide a default notifier?
	    # @@@ Add a timeout to ui::dialog !
	    if {[hooks::info jivePhoneEvent] eq {}} {
		set title "Ring, ring..."
		set msg "Phone is ringing from $cid"
		ui::dialog -icon info -type ok -title $title  \
		  -message $msg
	    }
	}
    }
    return
}

# JivePhone::DoDial --
# 
#       type: FORWARD | DIAL

proc ::JivePhone::DoDial {type {jid ""}} {
    variable state
    variable phoneNumber
    
    set win $state(win)
    if {$jid eq ""} {
	BuildDialer $win $type
    } else {
	jlib::splitjidex $jid node domain -
	if {[::Jabber::GetServerJid] eq $domain} {
	    set phoneNumber ""
	    OnDial $win $type $jid
	} else {
	    BuildDialer $win $type
	}
    }
}

# JivePhone::BuildDialer --
# 
#       A toplevel dialer.
       
proc ::JivePhone::BuildDialer {w type} {
    variable state
    variable phoneNumber
    
    # Make sure only single instance of this dialog.
    if {[winfo exists $w]} {
	raise $w
	return
    }

    ::UI::Toplevel $w -class PhoneDialer \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand [namespace current]::CloseDialer
    wm title $w [mc {Dialer}]

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
    
    ttk::label $box.l -text "[mc Number]:"
    ttk::entry $box.e -textvariable [namespace current]::phoneNumber  \
      -width 18
    ttk::button $box.dial -text [mc Dial]  \
      -command [list [namespace current]::OnDial $w $type]
    
    grid  $box.l  $box.e  $box.dial -padx 1 -pady 4
 
    focus $box.e
    wm resizable $w 0 0
}

proc ::JivePhone::CloseDialer {w} {
    
    ::UI::SaveWinGeom $w   
}

proc ::JivePhone::OnDial {w type {jid ""}} {
    variable phoneNumber
    variable xmlns
    variable state
    variable callID
    
    Debug "::JivePhone::OnDial w=$w, type=$type, phoneNumber=$phoneNumber"
    
    if {!$state(phoneserver)} {
	return
    }

    if {$jid ne ""} {
	set dnid $jid
	set extensionElem [wrapper::createtag "jid" -chdata $jid]
    } elseif {$phoneNumber ne ""} {
	set extensionElem [wrapper::createtag "extension" -chdata $phoneNumber]
	set dnid $phoneNumber
    } else {
	Debug "\t return"
	return
    }
    
    if {$type eq "DIAL"} {
	set command "DIAL"
	set attr [list xmlns $xmlns(jivephone) type $command]
    } else {
	set command "FORWARD"
	set attr [list xmlns $xmlns(jivephone) id $callID type $command]
    }
    set phoneElem [wrapper::createtag "phone-action"  \
      -attrlist $attr -subtags [list $extensionElem]]

    ::Jabber::JlibCmd send_iq set [list $phoneElem]  \
      -to $state(service) -command [list ::JivePhone::DialCB $dnid]

    eval {::hooks::run jivePhoneEvent $command $dnid}

    destroy $w
}

proc ::JivePhone::DialJID {jid type} {
    variable state
    variable xmlns
    
    if {!$state(phoneserver)} {
	return
    }
    set extensionElem [wrapper::createtag "jid" -chdata $jid]

    if {$type eq "DIAL"} {
	set command "DIAL"
	set attr [list xmlns $xmlns(jivephone) type $command]
    } else {
	# @@@ Where comes callID from?
	set command "FORWARD"
	set attr [list xmlns $xmlns(jivephone) id $callID type $command]
    }
    set phoneElem [wrapper::createtag "phone-action"  \
      -attrlist $attr -subtags [list $extensionElem]]

    ::Jabber::JlibCmd send_iq set [list $phoneElem]  \
      -to $state(service) -command [list ::JivePhone::DialCB $jid]

    eval {::hooks::run jivePhoneEvent $command $jid}    
}

proc ::JivePhone::DialCB {dnid type subiq args} {
    
    if {$type eq "error"} {
	ui::dialog -icon error -type ok -message "Failed calling $dnid" \
	  -detail $subiq
    }
}

proc ::JivePhone::Debug {msg} {
    
    if {0} {
	puts "-------- $msg"
    }
}

#-------------------------------------------------------------------------------
