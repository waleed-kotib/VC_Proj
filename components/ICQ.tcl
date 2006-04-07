# ICQ.tcl --
# 
#       Provides some specific ICQ handling elements.
#       
# $Id: ICQ.tcl,v 1.9 2006-04-07 14:08:26 matben Exp $

namespace eval ::ICQ:: {
    
}

proc ::ICQ::Init { } {
    global  this
    
    ::Debug 2 "::ICQ::Init"
    
    # Add all hooks we need.
    ::hooks::register browseSetHook          ::ICQ::BrowseSetHook
    ::hooks::register discoInfoHook          ::ICQ::DiscoInfoHook
    ::hooks::register logoutHook             ::ICQ::LogoutHook
    
    component::register ICQ  \
      "The roster name is automatically set to the ICQ user's vCard nickname."

    # Cache for vCard nickname.
    variable vcardnick
}


proc ::ICQ::BrowseSetHook {from subiq} {

    ::Debug 4 "::ICQ::BrowseSetHook from=$from"

    set server [::Jabber::GetServerJid]
    if {[jlib::jidequal $from $server]} {
	InvestigateRoster
    }
}

proc ::ICQ::DiscoInfoHook {type from subiq args} {
    
    ::Debug 4 "::ICQ::DiscoInfoHook"
    
    set cattype [lindex [::Jabber::DiscoCmd types $from] 0]
    if {$cattype eq "gateway/icq"} {
	InvestigateRoster
    }
}

proc ::ICQ::InvestigateRoster { } {
    variable vcardnick
    
    set wtree  [::Roster::GetWtree]
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
	    set nickElem [lindex [wrapper::getchildswithtag $subiq "NICKNAME"] 0]
	    set nick     [wrapper::getcdata $nickElem]
	    set vcardnick($from) $name
	    jlib::splitjid $from jid2 res
	    ::Jabber::JlibCmd roster_set $jid2  \
	      [namespace current]::RosterSetCB -name $nick
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
