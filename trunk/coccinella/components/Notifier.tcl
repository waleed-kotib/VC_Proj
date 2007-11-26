# Notifier.tcl --
# 
#       Notifies the user of certain events when application is in the
#       background.
#       This is just a first sketch.
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
# $Id: Notifier.tcl,v 1.9 2007-11-26 14:49:24 matben Exp $

namespace eval ::Notifier {
    
    # Use this on windows only.
    if {![string equal $::this(platform) "windows"]} {
	return
    }
    if {[catch {package require notebox}]} {
	return
    }
    component::define Notifier  \
      "Provides a small event notifier window."
}

proc ::Notifier::Init {} {
    global  this
    
    component::register Notifier

    # Add event hooks.
    ::hooks::register prefsInitHook         [namespace current]::InitPrefsHook
    ::hooks::register newMessageHook        [namespace current]::MessageHook
    #::hooks::register newChatMessageHook    [namespace current]::ChatHook
    ::hooks::register newChatThreadHook     [namespace current]::ThreadHook
    ::hooks::register oobSetRequestHook     [namespace current]::OOBSetHook
}

proc ::Notifier::InitPrefsHook {} {
    upvar ::Jabber::jprefs jprefs

    set jprefs(notifier,state) 0
    
    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(notifier,state)  jprefs_notifier_state  $jprefs(notifier,state)]]   
}

proc ::Notifier::MessageHook {xmldata uuid} {
    
    set body [wrapper::getcdata [wrapper::getfirstchildwithtag $xmldata body]]
    if {![string length $body]} {
	return
    }
    set from [wrapper::getattribute $xmldata from]
    set str "You just received a new message from $from"
    after 200 [list ::Notifier::DisplayMsg $str]
}

proc ::Notifier::ChatHook {xmldata} {
    
    set body [wrapper::getcdata [wrapper::getfirstchildwithtag $xmldata body]]
    if {![string length $body]} {
	return
    }
    set from [wrapper::getattribute $xmldata from]
    set str "You just received a new chat message from $from"
    after 200 [list ::Notifier::DisplayMsg $str]
}

proc ::Notifier::ThreadHook {xmldata} {
    
    set body [wrapper::getcdata [wrapper::getfirstchildwithtag $xmldata body]]
    if {![string length $body]} {
	return
    }
    set from [wrapper::getattribute $xmldata from]
    set str "The user $from just started a new chat thread"
    after 200 [list ::Notifier::DisplayMsg $str]
}

proc ::Notifier::OOBSetHook {from subiq args} {
    
    
}

proc ::Notifier::DisplayMsg {str} {
    upvar ::Jabber::jprefs jprefs
    
    # @@@ ::UI::IsAppInFront is not reliable...
    if {$jprefs(notifier,state) && ![::UI::IsAppInFront]} {
	::notebox::addmsg $str
    }
}

#-------------------------------------------------------------------------------
