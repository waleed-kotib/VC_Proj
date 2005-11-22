# JivePhone.tcl --
# 
#       JivePhone bindings for the jive server and Asterisk.
#       
# $Id: JivePhone.tcl,v 1.2 2005-11-22 07:44:12 matben Exp $

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
    
    variable statuses {RING DIALED ON_PHONE HANG_UP}
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
    
    puts "::JivePhone::OnDiscoServer"
    
    # See comments above what my opinion is...
    if {$type eq "result"} {
	set childs [::Jabber::JlibCmd disco children $from]
	foreach elem $childs {
	    if {[wrapper::getattribute $elem name] eq "phone"} {
		set state(phoneserver) 1
		set state(service) [wrapper::getattribute $elem jid]
		break
	    }
	}
    }
    if {$state(phoneserver)} {
	
	# @@@ It is a bit unclear if we shall disco the phone service with
	# the username as each node.
	
	set users [::Jabber::RosterCmd getusers]
	foreach jid $users {
	    jlib::splitjidex $jid node domain -	
	    if {[::Jabber::GetServerJid] eq $domain} {
		::Jabber::JlibCmd disco get_async info $state(service)  \
		  ::JivePhone::OnDiscoUserNode -node $node
	    }
	}
    }
}

proc ::JivePhone::OnDiscoUserNode {jlibname type from subiq args} {
    variable xmlns
    variable state
    
    puts "::JivePhone::OnDiscoUserNode"
    
    if {$type eq "result"} {
	set node [wrapper::getattribute $subiq "node"]
	set havePhone [::Jabber::JlibCmd disco hasfeature $xmlns(jivephone)  \
	  $from $node]
	if {$havePhone} {
	
	    # @@@ What now?
	    
	    set image [::Rosticons::Get [string tolower phone/HANG_UP]]
	    ::RosterTree::StyleSetItemAlternative $jid jivephone image $image
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

    puts "::JivePhone::PresenceHook $args"

    array set argsArr $args
    if {[info exists argsArr(-extras)]} {
	set elems [wrapper::getnamespacefromchilds $argsArr(-extras)  \
	  phone-status $xmlns(jivephone)]
	if {$elems ne ""} {
	    set elem [lindex $elems 0]
	    set status [wrapper::getattribute $elem "status"]
	    set image [::Rosticons::Get [string tolower phone/$status]]
	    ::RosterTree::StyleSetItemAlternative $jid jivephone image $image
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

    puts "::JivePhone::MessageHook $args"
    
    array set argsArr $args

    if {[info exists argsArr(-phone-event)]} {
	set elem [lindex $argsArr(-phone-event) 0]
	set status [wrapper::getattribute $elem "status"]
	set image [::Rosticons::Get [string tolower phone/$status]]
	set win [::Jabber::UI::SetAlternativeStatusImage jivephone $image]
	
    }
    return
}

proc ::JivePhone::BuildDialer {w} {
    
    
    # @@@ TODO

}

#-------------------------------------------------------------------------------
