# MeBeam.tcl --
# 
#       Interface for MeBeam web based video conferencing.
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
# $Id: MeBeam.tcl,v 1.3 2007-11-07 13:36:32 matben Exp $

namespace eval ::MeBeam {}

proc ::MeBeam::Init {} {

    set menuDef [list command "Invite MeBeam" {::MeBeam::Cmd} {} {}]
    ::JUI::RegisterMenuEntry action $menuDef

    ::hooks::register menuPostCommand         ::MeBeam::MainMenuPostHook
    ::hooks::register menuChatActionPostHook  ::MeBeam::ChatMenuPostHook
    
    variable url "http://www.mebeam.com/coccinella.php?ccn_"
    
    component::register MeBeam "MeBeam web based video conferencing"
}

proc ::MeBeam::MainMenuPostHook {type m} {
    
    if {$type eq "main-action"} {
	::UI::MenuMethod $m entryconfigure "Invite MeBeam" -state disabled
	
	# If selected single online roster item.
	if {[::JUI::GetConnectState] eq "connectfin"} {
	    set jidL [::RosterTree::GetSelectedJID]
	    if {[llength $jidL] == 1} {
		set jid [lindex $jidL 0]
		if {[::Jabber::RosterCmd isavailable $jid]} {
		    ::UI::MenuMethod $m entryconfigure "Invite MeBeam" -state normal
		}
	    }
	}
    }
}

# Active chat dialog. This works only for Mac OS X.

proc ::MeBeam::ChatMenuPostHook {m} {
    if {[::JUI::GetConnectState] eq "connectfin"} {
	::UI::MenuMethod $m entryconfigure "Invite MeBeam" -state normal
    }
}

proc ::MeBeam::Cmd {} {

    if {[::JUI::GetConnectState] ne "connectfin"} {
	return
    }
    
    # Active chat dialog. This works only for Mac OS X.
    if {[winfo exists [focus]]} {
	set top [winfo toplevel [focus]]
	set wclass [winfo class $top]
	if {$wclass eq "Chat"} {
	    set dlgtoken [::Chat::GetTokenFrom dlg w $top]
	    set token [::Chat::GetActiveChatToken $dlgtoken]
	    ::Chat::SendText $token [Invite]
	    return
	}
    }
    
    # Selected roster item.
    set jidL [::RosterTree::GetSelectedJID]
    if {[llength $jidL] == 1} {
	set jid [lindex $jidL 0]
	if {[::Jabber::RosterCmd isavailable $jid]} {
	    set jid2 [jlib::barejid $jid]
	    set mjid2 [jlib::jidmap $jid2]
	    set token [::Chat::GetTokenFrom chat jid [jlib::ESC $mjid2]*]
	    if {$token ne ""} {
		::Chat::SendText $token [Invite]
	    } else {
		::Chat::StartThread $jid2 -message [Invite]
	    }
	}
    }
}

proc ::MeBeam::Invite {} {
    variable url
    
    set str [mc "Please join me for video chat on"]
    append str " "
    append str $url
    append str [uuid::uuid generate]
    ::Utils::OpenURLInBrowser $url
    
    return $str
}


