#  Nickname.tcl --
#  
#       This is part of The Coccinella application.
#       It provides support for XEP-0172: User Nickname.
#       
#  Copyright (c) 2007  Mats Bengtsson
#  
# $Id: Nickname.tcl,v 1.2 2007-06-28 06:14:20 matben Exp $

package provide Nickname 1.0

namespace eval ::Nickname {

    # Add event hooks.
    ::hooks::register jabberInitHook        ::Nickname::JabberInitHook
    ::hooks::register loginHook             ::Nickname::LoginHook

    
    variable xmlns
    set xmlns(nick)        "http://jabber.org/protocol/nick"
    set xmlns(nick+notify) "http://jabber.org/protocol/nick+notify"
    set xmlns(node_config) "http://jabber.org/protocol/pubsub#node_config"

}

# Nickname::JabberInitHook --
# 
#       Here we announce that we have User Nickname support and is interested in
#       getting notifications.

proc ::Nickname::JabberInitHook {jlibname} {
    variable xmlns
    
    set E [list]
    lappend E [wrapper::createtag "identity"  \
      -attrlist [list category hierarchy type leaf name "User Nickname"]]
    lappend E [wrapper::createtag "feature" \
      -attrlist [list var $xmlns(nick)]]    
    lappend E [wrapper::createtag "feature" \
      -attrlist [list var $xmlns(nick+notify)]]
    
    $jlibname caps register nick $E [list $xmlns(nick) $xmlns(nick+notify)]
}

# Setting own nickname ---------------------------------------------------------
#

proc ::Nickname::LoginHook {} {
    variable xmlns
   
    # Disco server for pubsub/pep support.
    set server [::Jabber::JlibCmd getserver]
    ::Jabber::JlibCmd pep have $server [namespace code HavePEP]
    ::Jabber::JlibCmd pubsub register_event [namespace code Event] \
      -node $xmlns(nick)
}

proc ::Nickname::HavePEP {jlibname have} {
    variable menuDef
    variable xmlns

    if {$have} {
	set nickname [::Profiles::GetSelected -nickname]
	if {$nickname ne ""} {
	    Publish $nickname
	} else {
	    Retract
	}
    }
}

proc ::Nickname::Element {nickname} {
    variable xmlns
    
    return [wrapper::createtag nick  \
      -attrlist [list xmlns $xmlns(nick)] -chdata $nickname]
}

proc ::Nickname::Publish {nickname} {
    variable xmlns

    set itemE [wrapper::createtag item -subtags [list [Element $nickname]]]
    ::Jabber::JlibCmd pep publish $xmlns(nick) $itemE
}

proc ::Nickname::Retract {} {
    variable xmlns
    
    ::Jabber::JlibCmd pep retract $xmlns(nick) -notify 1
}

# Getting others nicknames -----------------------------------------------------
#
# Nickname::Event --
# 
#       Nickname event handler for incoming nickname messages:

proc ::Nickname::Event {jlibname xmldata} {
    variable state
    variable xmlns

    #puts "\n::Nickname::Event +++++++++++++++++++++\n"
    
    # The server MUST set the 'from' address on the notification to the 
    # bare JID (<node@domain.tld>) of the account owner.
    set from [wrapper::getattribute $xmldata from]
    
    # Buggy ejabberd PEP patch!
    set from [jlib::barejid $from]
    set eventE [wrapper::getfirstchildwithtag $xmldata event]
    if {[llength $eventE]} {
	set itemsE [wrapper::getfirstchildwithtag $eventE items]
	if {[llength $itemsE]} {
	    
	    set node [wrapper::getattribute $itemsE node]    
	    if {$node ne $xmlns(nick)} {
		return
	    }

	    set retractE [wrapper::getfirstchildwithtag $itemsE retract]
	    if {[llength $retractE]} {
		set nick ""
	    } else {
		set itemE [wrapper::getfirstchildwithtag $itemsE item]
		set nickE [wrapper::getfirstchildwithtag $itemE nick]
		if {![llength $nickE]} {
		    return
		}
		set nick [wrapper::getcdata $nickE]
	    }
	    
	    # Cache the result.
	    set mjid [jlib::jidmap $from]
	    set state($mjid,nick) $nick

	    # 'from' shall be a bare JID.
	    ::hooks::run nicknameEventHook $xmldata $from $nick
	}
    }   
}

# Nickname::Get --
# 
#       Get users nickname if any. Must use the bare jid.

proc ::Nickname::Get {jid} {
    variable state
  
    set mjid [jlib::jidmap $jid]
    if {[info exists state($mjid,nick)]} {
	return $state($mjid,nick)
    } else {
	return ""
    }
}

