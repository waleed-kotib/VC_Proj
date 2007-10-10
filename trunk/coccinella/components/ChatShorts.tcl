#  ChatShorts.tcl --
#  
#      This file is part of The Coccinella application. 
#      It implements some shortcut commands for chats.
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
# $Id: ChatShorts.tcl,v 1.1 2007-10-10 12:50:00 matben Exp $

namespace eval ::ChatShorts {}

proc ::ChatShorts::Init {} {
    
    # Crashes, see below.
    return
    
    component::register ChatShorts \
      "Implements /clean, /retain commands for chats."

    # Add event hooks.
    ::hooks::register sendTextChatHook      [namespace code ChatTextHook]
    ::hooks::register sendTextGroupChatHook [namespace code TextGroupChatHook]
    
}

proc ::ChatShorts::ChatTextHook {chattoken jid str} {
    
    if {[regexp {^ */clean$} $str]} {
	set wtext [::Chat::GetChatTokenValue $chattoken wtext]
	puts "wtext=$wtext"
	$wtext tag configure telide -elide 1
	# This crashes my Mac Tcl 8.4.9
	$wtext tag add telide 1.0 end
	return stop
    } elseif {[regexp {^ */retain$} $str]} {
	set wtext [::Chat::GetChatTokenValue $chattoken wtext]
	$wtext tag delete telide
	return stop
    }
    return
}

proc ::ChatShorts::TextGroupChatHook {roomjid str} {

    
    
    
}

