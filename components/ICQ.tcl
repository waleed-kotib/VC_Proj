# ICQ.tcl --
# 
#       Provides some specific ICQ handling elements.
#       
# $Id: ICQ.tcl,v 1.3 2004-09-27 12:57:37 matben Exp $

namespace eval ::ICQ:: {
    
}

proc ::ICQ::Init { } {
    global  this
    
    ::Debug 2 "::ICQ::Init"
    
    # Add all hooks we need.
    ::hooks::add browseSetHook          ::ICQ::BrowseSetHook
    ::hooks::add discoInfoHook          ::ICQ::DiscoInfoHook
    ::hooks::add logoutHook             ::ICQ::LogoutHook
    
    component::register ICQ  \
      "The roster name is automatically set to the ICQ user's vCard nickname."

    # Cache for vCard nickname.
    variable vcardnick
}


proc ::ICQ::BrowseSetHook {from subiq} {

    ::Debug 4 "::ICQ::BrowseSetHook from=$from"

    set server [::Jabber::GetServerJid]
    if {[jlib::jidequal $from $server]} {
	::ICQ::InvestigateRoster
    }
}

proc ::ICQ::DiscoInfoHook {type from subiq args} {
    
    ::Debug 4 "::ICQ::DiscoInfoHook"
    
    set cattype [lindex [::Jabber::DiscoCmd types $from] 0]
    if {$cattype == "gateway/icq"} {
	::ICQ::InvestigateRoster
    }
}

proc ::ICQ::InvestigateRoster { } {
    variable vcardnick
    
    set wtree [::Jabber::Roster::GetWtree]
    set server [::Jabber::GetServerJid]
    set icqHosts [::Jabber::JlibCmd service gettransportjids "icq"]
    
    ::Debug 4 "::ICQ::InvestigateRoster icqHosts=$icqHosts"

    # We must loop through all roster items to search for ICQ users.
    foreach v [$wtree find withtag all] {
	set tags [$wtree itemconfigure $v -tags]
	
	switch -- $tags {
	    "" - head - group {
		# skip
	    } 
	    default {
		set jid [lindex $v end]
		set mjid [jlib::jidmap $jid]
		jlib::splitjidex $mjid node host res
		
		# Not a user.
		if {$node == ""} {
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
		    if {$name == ""} {
			
			# Get vCard
			::Jabber::JlibCmd vcard_get $jid \
			  [list [namespace current]::VCardGetCB $jid]
		    }
		}
	    }
	}	
    }   
}

proc ::ICQ::VCardGetCB {from jlibName type subiq} {
    variable vcardnick
    
    ::Debug 4 "::ICQ::VCardGetCB from=$from, type=$type"

    if {$type == "error"} {
	::Jabber::AddErrorLog $from "Failed getting vCard: [lindex $subiq 1]"
    } else {
	set name [::Jabber::RosterCmd getname $from]
	
	# Do not override any previous roster name (?)
	if {$name == ""} {

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
