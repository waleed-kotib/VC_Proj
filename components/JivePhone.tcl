# JivePhone.tcl --
# 
#       JivePhone bindings for the jive server and Asterisk.
#       
# $Id: JivePhone.tcl,v 1.1 2005-11-19 11:36:56 matben Exp $

namespace eval ::JivePhone:: { }

proc ::JivePhone::Init { } {
    
    component::register JivePhone  \
      "Provides support for the VoIP notification in the jive server"
        
    # Add event hooks.
    ::hooks::register presenceHook    ::JivePhone::PresenceHook
    ::hooks::register newMessageHook  ::JivePhone::MessageHook
    
    variable xmlns
    set xmlns(jivephone) "http://jivesoftware.com/xmlns/phone"
    
    variable statuses {RING DIALED ON_PHONE HANG_UP}
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
	
    
	
    }
    return
}

#-------------------------------------------------------------------------------

