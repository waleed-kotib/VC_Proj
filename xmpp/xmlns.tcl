#  xmlns.tcl --
#  
#      This is a skeleton to create a xmpp library from scratch.
#      It keeps track of common xml namespaces in xmpp.
#      
#  Copyright (c) 2008  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: xmlns.tcl,v 1.1 2008-08-19 13:47:57 matben Exp $

package provide xmpp::xmlns 0.1

namespace eval xmpp::xmlns {
    
    variable ns
    
    # Core.
    array set ns {
	stream      "http://etherx.jabber.org/streams"
	streams     "urn:ietf:params:xml:ns:xmpp-streams"
	tls         "urn:ietf:params:xml:ns:xmpp-tls"
	sasl        "urn:ietf:params:xml:ns:xmpp-sasl"
	bind        "urn:ietf:params:xml:ns:xmpp-bind"
	stanzas     "urn:ietf:params:xml:ns:xmpp-stanzas"
	session     "urn:ietf:params:xml:ns:xmpp-session"
    }
    
    # XEP.
    array set ns {
	amp             "http://jabber.org/protocol/amp"
	caps            "http://jabber.org/protocol/caps"
	compress        "http://jabber.org/features/compress"
	disco           "http://jabber.org/protocol/disco"
	disco,items     "http://jabber.org/protocol/disco#items"
	disco,info      "http://jabber.org/protocol/disco#info"
	ibb             "http://jabber.org/protocol/ibb"
	muc             "http://jabber.org/protocol/muc"
	muc,user        "http://jabber.org/protocol/muc#user"
	muc,admin       "http://jabber.org/protocol/muc#admin"
	muc,owner       "http://jabber.org/protocol/muc#owner"
	pubsub          "http://jabber.org/protocol/pubsub"
    }
    
    namespace export xmpp::xmlns::ns
}

proc xmpp::xmlns::ns {key} {
    variable ns
    return $ns($key)
}




