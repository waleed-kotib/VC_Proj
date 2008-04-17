#  Gateway.tcl --
#  
#       This is part of The Coccinella application.
#       It provides support related to gateway interactions.
#       This is part of XEP-0100: Gateway Interaction, sect. 6.3
#       
#       NB1: We cache this info after logged out since it is assumed to
#            be fairly persistant.
#       NB2: We assume that any particular gateway/type is representative 
#            for all gateways belonging to that group independent of JID.
#       
#       @@@ Put all this in action when gateways are more reliable!
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
# $Id: Gateway.tcl,v 1.10 2008-04-17 15:00:29 matben Exp $

package provide Gateway 1.0

namespace eval ::Gateway {
    
    ::hooks::register  discoInfoGatewayHook  ::Gateway::DiscoHook

    # Common xml namespaces.
    variable xmlns
    array set xmlns {
	disco   "http://jabber.org/protocol/disco"
	items   "http://jabber.org/protocol/disco#items"
	info    "http://jabber.org/protocol/disco#info"
	gateway "jabber:iq:gateway"
    }
    
    # Do various mappings from the gateway type attribute.
    # Names for popup etc.
    # These go into the message catalog.
    variable shortName
    array set shortName {
	aim         AIM
	gadu-gadu   Gadu-Gadu
	icq         ICQ
	irc         IRC
	jabber      Jabber
	msn         MSN
	qq          QQ
	smtp        Email
	tlen        Tlen
	xmpp        Jabber
	yahoo       Yahoo
    }
    
    # Default prompts and descriptions.
    # These go into the message catalog.
    variable promptText
    set promptText(aim)        "Screen Name"
    set promptText(gadu-gadu)  "Gadu-Gadu Number"
    set promptText(icq)        "ICQ Number"
    set promptText(irc)        "IRC"
    set promptText(msn)        "MSN Address"
    set promptText(smtp)       "Email Address"
    set promptText(qq)         "QQ Number"
    set promptText(tlen)       "Tlen Address"
    set promptText(xmpp)       "Jabber ID"
    set promptText(yahoo)      "Yahoo ID"
    
    # Each gateway must transform its "prompt" (user ID) to a JID.
    # These templates provides such a mapping. 
    # Must substitute %s with gateway's JID. Note verbatim "%" as "%%".
    variable template
    array set template {
	aim         userName@%s
	icq         screeNumber@%s
	jabber      userName@%s
	msn         userName%%hotmail.com@%s
	smtp        userName%%emailserver@%s
	tlen        userName@%s
	xmpp        userName@%s
	yahoo       userName@%s
    }
}

proc ::Gateway::GetGatewayTypeFromJID {jid} {
    set gtype ""
    set cattypes [::Jabber::Jlib disco types $jid]
    regexp {gateway/([^ ]+)} $cattypes - gtype
    return $gtype
}

proc ::Gateway::DiscoHook {type from queryE args} {
    variable xmlns
    variable gateway
    
    # XEP-0100: Gateway Interaction:
    # If the client provides an 'xml:lang' attribute with the IQ-get, 
    # the gateway SHOULD return localized prompt names and text if available, 
    # or default to English if not available.

    set gtype [GetGatewayTypeFromJID $from]
    set mjid [jlib::jidmap $from]
    if {![info exists gateway(prompt,$gtype)]} {
	::Jabber::Jlib iq_get $xmlns(gateway) -to $from \
	  -xml:lang [jlib::getlang] \
	  -command [namespace code [list OnGateway $mjid]]
    }
}

proc ::Gateway::OnGateway {mjid jlibname type queryE args} {
    variable gateway
    
    if {$type eq "error"} {
	return
    }
    
    # Cache using the gateway type.
    set gtype [GetGatewayTypeFromJID $mjid]
    if {$gtype eq ""} {
	return
    }
    foreach E [wrapper::getchildren $queryE] {
	set tag [wrapper::gettag $E]
	switch -- $tag {
	    prompt - desc {
		
		# Some gateways send empty <prompt/>.
		set cdata [wrapper::getcdata $E]
		if {[string length $cdata]} {
		    set gateway($tag,$gtype) $cdata
		    set gateway($tag,$gtype) $cdata
		}
	    }
	}
    }
}

proc ::Gateway::GetShort {type} {
    variable shortName
    
    set type [string map {"x-" ""} $type]
    if {[info exists shortName($type)]} {
	return [mc $shortName($type)]
    } else {
	return [string totitle $type]
    }
}    

# Use this until 'GetJIDFromPrompt' is working with gateways.

proc ::Gateway::GetTemplateJID {type} {
    variable template
    
    set type [string map {"x-" ""} $type]
    if {[info exists template($type)]} {
	return $template($type)
    } else {
	return userName@%s
    }
}    


# @@@ Very few gateways return nonempty prompts :-(
#     We therefore provide complete fallbacks.

proc ::Gateway::GetPrompt {type} {
    variable gateway
    variable promptText
    
    set type [string map {"x-" ""} $type]
    if {[info exists gateway(prompt,$type)]} {
	return $gateway(prompt,$type)
    } elseif {[info exists promptText($type)]} {
	return [mc $promptText($type)]
    } else {
	return [string totitle $type]
    }
}

# @@@ I haven't found a single gateway where this works :-(

proc ::Gateway::GetJIDFromPrompt {prompt gatewayjid cmd} {
    variable xmlns
    
    set promptE [wrapper::createtag prompt -chdata $prompt]
    ::Jabber::Jlib iq_get $xmlns(gateway) \
      -to $gatewayjid -sublists [list $promptE] \
      -command [namespace code [list OnGetJIDFromPrompt $cmd]]
}

proc ::Gateway::OnGetJIDFromPrompt {cmd jlibname type queryE args} {    
    set jidE [wrapper::getfirstchildwithtag $queryE jid]
    set jid [wrapper::getcdata $jidE]
    uplevel #0 $cmd [list $jid]
}

# Gateway::EscapePercent --
# 
#       For msn, smtp and others that don't support JID Escaping XEP-0106

proc ::Gateway::EscapePercent {type prompt} {
    if {($type eq "msn") || ($type eq "smtp")} {
	return [string map {@ %} $prompt]
    } else {
	return $prompt
    }
}

# Try this instead:
# The 'prompt' is a system native ID, typically, but can be a complete JID.

proc ::Gateway::GetJIDFromPromptHeuristics {prompt type} {
    upvar ::Jabber::jstate jstate
    
    if {$type eq "xmpp"} {
	return $prompt
    }

    # First verify that we don't already have the JID with gateway JID.
    set gjidL [$jstate(jlib) disco getjidsforcategory "gateway/$type"]
    foreach gjid $gjidL {
	jlib::splitjidex $prompt node domain res
	if {[jlib::jidequal $domain $gjid]} {
	    set haveEsc [$jstate(jlib) disco hasfeature {jid\20escaping} $gjid]
	    if {$haveEsc} {
		set enode [jlib::escapestr $node]
	    } else {
		set enode [EscapePercent $type $node]
	    }
	    return $enode@$gjid
	}
    }
    
    # Just pick the first gateway we find.
    set gjid [lindex $gjidL 0]
    set haveEsc [$jstate(jlib) disco hasfeature {jid\20escaping} $gjid]
    if {$haveEsc} {
	set enode [jlib::escapestr $prompt]
    } else {
	set enode [EscapePercent $type $prompt]
    }
    return $enode@$gjid
}


