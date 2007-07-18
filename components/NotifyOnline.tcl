#  NotifyOnline.tcl ---
#  
#      This file is part of The Coccinella application.
#      It is an experiment to set login/logout to web service.
#
#  Copyright (c) 2006  Mats Bengtsson
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
# $Id: NotifyOnline.tcl,v 1.3 2007-07-18 09:40:09 matben Exp $

package require http

namespace eval ::NotifyOnline:: {
    
    # So far only logout (and quit).
    set url "http://www.evaal.com/index.php"

    set ::config(notifyonline,do)  0
    set ::config(notifyonline,url) $url
}

proc ::NotifyOnline::Init { } {

    ::Debug 2 "::NotifyOnline::Init"
	
    # Let any custom config override component registration.
    ::hooks::register initHook ::NotifyOnline::InitHook
}

proc ::NotifyOnline::InitHook { } {
    global  config
    
    if {$config(notifyonline,do)} {
	component::register NotifyOnline  \
	  "Does http actions as a response to login/logout."
	
	::hooks::register loginHook        ::NotifyOnline::LoginHook
	::hooks::register logoutHook       ::NotifyOnline::LogoutHook
	::hooks::register preQuitAppHook   ::NotifyOnline::PreQuitHook
	::hooks::register setPresenceHook  ::NotifyOnline::PresenceHook
    }
}

proc ::NotifyOnline::LoginHook {} {
    # empty
    return
}

proc ::NotifyOnline::LogoutHook {} {
    PostLogout
    return
}

proc ::NotifyOnline::PreQuitHook {} {
    if {[::Jabber::IsConnected]} {
	PostLogout
    }
    return
}

proc ::NotifyOnline::PresenceHook {type args} {
    array set argsArr $args
    if {![info exists argsArr(-to)] && ($type eq "invisible")} {
	PostLogout
    }
    return
}

proc ::NotifyOnline::PostLogout {args} {
    global  config
    
    ::Debug 2 "::NotifyOnline::PostLogout"
    
    set url $config(notifyonline,url)
    set jid [::Jabber::GetMyJid]
    #set query [::http::formatQuery user $jid]
    set query [::http::formatQuery act expert]
    
    # Can't currently not fo this async during quit.
    catch {
	::http::geturl $url -query $query 
	#-command [namespace current]::Command
    }
}

proc ::NotifyOnline::Command {token} {
    upvar #0 $token state
    
    # Investigate 'state' for any exceptions.
    set status [::http::status $token]
    
    ::Debug 2 "::NotifyOnline::Command status=$status"
    
    ::http::cleanup $token    
}

#-------------------------------------------------------------------------------
