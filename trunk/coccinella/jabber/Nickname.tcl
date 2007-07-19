#  Nickname.tcl --
#  
#       This is part of The Coccinella application.
#       It provides support for XEP-0172: User Nickname.
#       
#  Copyright (c) 2007  Mats Bengtsson
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
# $Id: Nickname.tcl,v 1.4 2007-07-19 06:28:16 matben Exp $

# @@@ There is one thing I don't yet understand. While I always publish any 
# nickname when I log on, online users will receive the event, but what about
# users which are already online when I log in? I wont receive any event
# since they already have published their nickname. Perhaps I need to:
# 
#   $jlibname pubsub items $jid "http://jabber.org/protocol/nick"
# 
# for all users?

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

