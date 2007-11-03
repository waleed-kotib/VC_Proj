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
# $Id: MeBeam.tcl,v 1.1 2007-11-03 06:57:25 matben Exp $

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
    }
}

proc ::MeBeam::ChatMenuPostHook {m} {
    if {[::JUI::GetConnectState] eq "connectfin"} {
	::UI::MenuMethod $m entryconfigure "Invite MeBeam" -state normal
    }
}

proc ::MeBeam::Cmd {} {
    variable url
    
    if {[winfo exists [focus]]} {
	set top [winfo toplevel [focus]]
	set wclass [winfo class $top]
	if {$wclass eq "Chat"} {
	    set dlgtoken [::Chat::GetTokenFrom dlg w $top]
	    set token [::Chat::GetActiveChatToken $dlgtoken]
	    
	    set str [mc "Please join me for video chat on"]
	    append str " "
	    append str $url
	    append str [uuid::uuid generate]
	    
	    ::Chat::SendText $token $str
	}
    }
}


