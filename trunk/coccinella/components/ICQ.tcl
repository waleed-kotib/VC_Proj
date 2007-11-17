# ICQ.tcl --
# 
#       Provides some specific ICQ handling elements.
#
#  Copyright (c) 2007 Mats Bengtsson
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
# $Id: ICQ.tcl,v 1.17 2007-11-17 07:40:52 matben Exp $

namespace eval ::ICQ {
    
    component::define ICQ "Use ICQ nickname in roster"
}

proc ::ICQ::Init { } {
    global  this
    
    ::Debug 2 "::ICQ::Init"
    
    # Add all hooks we need.
    ::hooks::register discoInfoGatewayIcqHook   ::ICQ::DiscoInfoHook
    ::hooks::register logoutHook                ::ICQ::LogoutHook
    
    component::register ICQ

    # Cache for vCard nickname.
    variable vcardnick
}

proc ::ICQ::DiscoInfoHook {type from subiq args} {
    InvestigateRoster
}

proc ::ICQ::InvestigateRoster { } {
    variable vcardnick
    
    set server [::Jabber::GetServerJid]
    set icqHosts [::Jabber::JlibCmd disco getjidsforcategory "gateway/icq"]
    
    ::Debug 4 "::ICQ::InvestigateRoster icqHosts=$icqHosts"

    # We must loop through all roster items to search for ICQ users.

    foreach jid [::Jabber::RosterCmd getusers] {
	set mjid [jlib::jidmap $jid]
	jlib::splitjidex $mjid node host res
	
	# Not a user.
	if {$node eq ""} {
	    continue
	}
	
	# Allready got it.
	if {[info exists vcardnick($mjid)]} {
	    continue
	}
	
	# Exclude jid's that belong to our login jabber server.
	if {[string equal $server $host]} {
	    continue
	}
	if {[lsearch -exact $icqHosts $host] >= 0} {
	    set name [::Jabber::RosterCmd getname $mjid]
	    if {$name eq ""} {
		
		# Get vCard
		::Jabber::JlibCmd vcard send_get $jid \
		  [list [namespace current]::VCardGetCB $jid]
	    }
	}	
    }   
}

proc ::ICQ::VCardGetCB {from jlibName type subiq} {
    variable vcardnick
    
    ::Debug 4 "::ICQ::VCardGetCB from=$from, type=$type"

    if {$type eq "error"} {
	::Jabber::AddErrorLog $from "Failed getting vCard: [lindex $subiq 1]"
    } else {
	set name [::Jabber::RosterCmd getname $from]
	
	# Do not override any previous roster name (?)
	if {$name eq ""} {

	    # Find any NICKNAME element.
	    set nickElem [wrapper::getfirstchildwithtag $subiq "NICKNAME"]
	    set nick     [wrapper::getcdata $nickElem]
	    set vcardnick($from) $name
	    jlib::splitjid $from jid2 res
	    ::Jabber::JlibCmd roster send_set $jid2 -name $nick
	}
    }
}

proc ::ICQ::RosterSetCB {args} {
    
    # puts "++++++++args='$args'"
}

proc ::ICQ::LogoutHook { } {
    variable vcardnick
    
    # Cleanup.
    unset -nocomplain vcardnick
}

#-------------------------------------------------------------------------------
