#  stanzaerror.tcl --
#  
#      This file is part of the jabberlib. It provides english clear text
#      messages that gives some detail of 'urn:ietf:params:xml:ns:xmpp-stanzas'.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: stanzaerror.tcl,v 1.7 2006-09-13 14:09:12 matben Exp $
# 

package provide stanzaerror 1.0

namespace eval stanzaerror {
    
    # This maps Defined Conditions to clear text messages.
    # draft-ietf-xmpp-core23; 9.3.3 Defined Conditions
    # @@@ Add to message catalogs.
    
    variable msg
    array set msg {
	bad-request	      {The sender has sent XML that is malformed or that cannot be processed.}
	conflict	      {Access cannot be granted because an existing resource or session exists with the same name or address.}
	feature-not-implemented	 {The feature requested is not implemented by the recipient or server and therefore cannot be processed.}
	forbidden             {The requesting entity does not possess the required permissions to perform the action.}
	gone                  {The recipient or server can no longer be contacted at this address.}
	internal-server-error {The server could not process the stanza because of a misconfiguration or an otherwise-undefined internal server error.}
	item-not-found        {The addressed JID or item requested cannot be found.}
	jid-malformed         {The sending entity has provided or communicated an XMPP address or aspect thereof that does not adhere to the syntax defined in Addressing Scheme.}
	not-acceptable        {The recipient or server understands the request but is refusing to process it because it does not meet criteria defined by the recipient or server.}
	not-allowed           {The recipient or server does not allow any entity to perform the action.}
        not-authorized        {The sender must provide proper credentials before being allowed to perform the action, or has provided improper credentials.}
	payment-required      {The requesting entity is not authorized to access the requested service because payment is required.}
	recipient-unavailable {The intended recipient is temporarily unavailable.}
	redirect              {The recipient or server is redirecting requests for this information to another entity, usually temporarily.}
	registration-required {The requesting entity is not authorized to access the requested service because registration is required.}
	remote-server-not-found {A remote server or service specified as part or all of the JID of the intended recipient does not exist.}
	remote-server-timeout {A remote server or service specified as part or all of the JID of the intended recipient (or required to fulfill a request) could not be contacted within a reasonable amount of time.}
	resource-constraint   {The server or recipient lacks the system resources necessary to service the request.}
	service-unavailable   {The server or recipient does not currently provide the requested service.}
	subscription-required {The requesting entity is not authorized to access the requested service because a subscription is required.}
	undefined-condition   {The error condition is not one of those defined by the other conditions in this list.}
	unexpected-request    {The recipient or server understood the request but was not expecting it at this time (e.g., the request was out of order).}
    }
}

# stanzaerror::getmsg --
# 
#       Return the english clear text message from a defined-condition.

proc stanzaerror::getmsg {condition} {
    variable msg

    if {[info exists msg($condition)]} {
	return $msg($condition)
    } else {
	return
    }
}

#-------------------------------------------------------------------------------

