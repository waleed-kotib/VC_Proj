# JivePhone.tcl --
# 
#       JivePhone bindings for the jive server and Asterisk.
#       
# $Id: JivePhone.tcl,v 1.11 2005-12-04 13:29:11 matben Exp $

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
	    
	    # Attempt to set icon only if this user is unavailable since
	    # we do not have the full jid!
	    # This way we shouldn't interfere with phone presence.
	    # We could use [roster isavailable $jid] instead.

	    set item [::RosterTree::FindWithTag [list jid $jid]]
	    if {$item ne ""} {
		set image [::Rosticons::Get [string tolower phone/available]]
		::RosterTree::StyleSetItemAlternative $jid jivephone image $image
	    }
	}
    }
}

proc ::JivePhone::LogoutHook { } {
    variable state
    
    unset -nocomplain state
    set state(phoneserver) 0
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
	    set cid ""
	    if {$cidElem != {}} {
		set cid [wrapper::getcdata $cidElem]
	    }
	    set image [::Rosticons::Get [string tolower phone/$status]]
	    set win [::Jabber::UI::SetAlternativeStatusImage jivephone $image]
	    
	    # @@@ What to do more?
	    if {$status == "RING" || $status == "DIALED"} {
		
	    }
	    bind $win <Button-1> [list ::JivePhone::BuildDialer .dial]

	    eval {::hooks::run jivePhoneEvent $status} $args
	    
	    # Provide a default notifier?
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

# JivePhone::BuildDialer --
# 
#       A toplevel dialer.
       
proc ::JivePhone::BuildDialer {w} {
    variable phoneNumber
    
    ::UI::Toplevel $w -class PhoneDialer \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand [namespace current]::Close
    wm title $w [mc {Dial Phone}]

    ::UI::SetWindowPosition $w
    set phoneNumber ""

    # Global frame.
    ttk::frame $w.f
    pack  $w.f  -fill x
				 
    ttk::label $w.f.head -style Headlabel \
      -text [mc {Dial Phone}]
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
      -command [list [namespace current]::OnDial $w]
    
    grid  $box.l  $box.e  $box.dial -padx 1 -pady 4
 
    focus $box.e
    wm resizable $w 0 0
}

proc ::JivePhone::CloseDialer {w} {
    
    ::UI::SaveWinGeom $w   
}

proc ::JivePhone::OnDial {w} {
    variable phoneNumber
    variable xmlns
    variable state
    
    if {!$state(phoneserver)} {
	return
    }
    set extensionElem [wrapper::createtag "extension" -chdata $phoneNumber]
    set phoneElem [wrapper::createtag "phone-action"      \
      -attrlist [list xmlns $xmlns(jivephone) type DIAL]  \
      -subtags [list $extensionElem]]
    
    ::Jabber::JlibCmd send_iq set [list $phoneElem]  \
      -to $state(service) -command [list ::JivePhone::DialCB $phoneNumber]
    
    destroy $w
}

proc ::JivePhone::DialCB {phoneNumber type subiq} {
    
    if {$type eq "error"} {
	ui::dialog -icon error -type ok -message "Failed calling $phoneNumber" \
	  -detail $subiq
    }
}

proc ::JivePhone::Debug {msg} {
    
    if {1} {
	puts "-------- $msg"
    }
}

#-------------------------------------------------------------------------------
