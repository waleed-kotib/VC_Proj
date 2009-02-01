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
# $Id: Gateway.tcl,v 1.12 2008-06-09 09:50:59 matben Exp $

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
    set shortName [dict create]
	dict set shortName aim         "AIM"
	dict set shortName gadu-gadu   "Gadu-Gadu"
	dict set shortName icq         "ICQ"
	dict set shortName irc         "IRC"
	dict set shortName jabber      "XMPP"
	dict set shortName msn         "MSN"
	dict set shortName qq          "QQ"
	dict set shortName smtp        [mc "Email"]
	dict set shortName tlen        "Tlen"
	dict set shortName xmpp        "XMPP"
	dict set shortName yahoo       "Yahoo"
    
    # Default prompts and descriptions.
    variable promptText
    set promptText [dict create]
    dict set promptText aim        [mc "Screen Name"]
    dict set promptText gadu-gadu  [mc "Gadu-Gadu Number"]
    dict set promptText icq        [mc "ICQ Number"]
    dict set promptText irc        [mc "IRC"]
    dict set promptText msn        [mc "MSN Address"]
    dict set promptText smtp       [mc "Email Address"]
    dict set promptText qq         [mc "QQ Number"]
    dict set promptText tlen       [mc "Tlen Address"]
    dict set promptText xmpp       [mc "IM Address"]
    dict set promptText yahoo      [mc "Yahoo ID"]
    
    # Each gateway must transform its "prompt" (user ID) to a JID.
    # These templates provides such a mapping. 
    # Must substitute %s with gateway's JID. Note verbatim "%" as "%%".
    variable template
    array set template {
	aim         userName@%s
	icq         screenNumber@%s
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
    if {[dict exists $shortName $type]} {
	return [dict get $shortName $type]
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
    } elseif {[dict exists $promptText $type]} {
	return [dict get $promptText $type]
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
    
    if {$type eq "xmpp"} {
	return $prompt
    }

    # First verify that we don't already have the JID with gateway JID.
    set gjidL [::Jabber::Jlib disco getjidsforcategory "gateway/$type"]
    foreach gjid $gjidL {
	jlib::splitjidex $prompt node domain res
	if {[jlib::jidequal $domain $gjid]} {
	    set haveEsc [::Jabber::Jlib disco hasfeature {jid\20escaping} $gjid]
	    if {$haveEsc} {
		set enode [jlib::escapestr $node]
	    } else {
		set enode [EscapePercent $type $node]
	    }
	    return $enode@$gjid
	}
    }
    
    # If multiple transports of the same type, 'gjid' is just any of them.
    # If we actually have a transport registered we must use that.
    set isregistered 0
    foreach gjid $gjidL {
	set rjid [::Jabber::Jlib roster getrosterjid $gjid]
	set isitem [string length $rjid]
	if {$isitem} {
	    set isregistered 1
	    break
	}
    }
    
    # Unless registered, just pick the first gateway we find.
    if {!$isregistered} {
	set gjid [lindex $gjidL 0]
    }
    set haveEsc [::Jabber::Jlib disco hasfeature {jid\20escaping} $gjid]
    if {$haveEsc} {
	set enode [jlib::escapestr $prompt]
    } else {
	set enode [EscapePercent $type $prompt]
    }
    return $enode@$gjid
}


