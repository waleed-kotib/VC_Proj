#  Disco.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the Disco application part.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: Disco.tcl,v 1.1 2004-02-02 13:41:56 matben Exp $

package provide Disco 1.0

namespace eval ::Jabber::Disco:: {

    # Common xml namespaces.
    variable xmlns
    array set xmlns {
	disco           http://jabber.org/protocol/disco 
	items           http://jabber.org/protocol/disco#items 
	info            http://jabber.org/protocol/disco#info
    }
}


# Jabber::Disco::Get --
#
#       Discover the services available for the $jid.
#
# Arguments:
#       jid         The jid to discover.
#       args    ?-silent 0/1? (D=0)
#       
# Results:
#       callback scheduled.

proc ::Jabber::Disco::Get {jid args} {    
    upvar ::Jabber::jstate jstate
    
    array set opts {
	-silent 0
    }
    array set opts $args
    
    # Discover services available.
    $jstate(disco) send_get items $jid ::Jabber::Disco::ItemsCB
    $jstate(disco) send_get info  $jid ::Jabber::Disco::InfoCB
}


proc ::Jabber::Disco::Command {discotype from subiq args} {
    upvar ::Jabber::jstate jstate

    puts "::Jabber::Disco::Command"
    
    if {[string equal $discotype "info"]} {
	eval {::Jabber::Disco::ParseGetInfo $from $subiq} $args
    } elseif {[string equal $discotype "items"]} {
	eval {::Jabber::Disco::ParseGetItems $from $subiq} $args
    }
        
    # Tell jlib's iq-handler that we handled the event.
    return 1
}

proc ::Jabber::Disco::ItemsCB {args} {
    
    
    
}

proc ::Jabber::Disco::InfoCB {args} {
    
    
}
	    
# Jabber::Disco::ParseGetInfo --
#
#       Respond to an incoming discovery get query.
#       
# Results:
#       none

proc ::Jabber::Disco::ParseGetInfo {from subiq args} {
    variable xmlns
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::privatexmlns privatexmlns

    ::Jabber::Debug 2 "::Jabber::Disco::ParseGetInfo: args='$args'"
    
    array set argsArr $args
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }

    # List everything this client supports. Starting with public namespaces.
    set vars {
	jabber:client
	jabber:iq:browse
	jabber:iq:conference
	jabber:iq:last
	jabber:iq:oob
	jabber:iq:roster
	jabber:iq:time
	jabber:iq:version
	jabber:x:data
	jabber:x:event
	coccinella:wb
    }
    lappend vars $xmlns(info) $xmlns(items)
    
    # Adding private namespaces.
    foreach {key ns} [array get privatexmlns] {
	lappend vars $ns
    }
    set subtags [list [wrapper::createtag "identity" -attrlist  \
      [list category user type client name Coccinella]]]
    foreach var $vars {
	lappend subtags [wrapper::createtag "feature" -attrlist [list var $var]]
    }
    
    set attr [list xmlns $xmlns(info)]
    set xmllist [wrapper::createtag "query" -subtags $subtags -attrlist $attr]
    eval {$jstate(jlib) send_iq "result" $xmllist -to $from} $opts
}

proc ::Jabber::Disco::ParseGetItems {from subiq args} {
    variable xmlns
    upvar ::Jabber::jstate jstate    
    
    array set argsArr $args
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }
    set attr [list xmlns $xmlns(items)]
    set xmllist [wrapper::createtag "query" -attrlist $attr]
    eval {$jstate(jlib) send_iq "result" $xmllist -to $from} $opts
}

if {0} {
    proc cb {args} {puts "cb: $args"}
    $::Jabber::jstate(disco) send_get info marilu@jabber.dk/coccinella cb
}

#-------------------------------------------------------------------------------
