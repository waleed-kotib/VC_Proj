#  NotifyOnline.tcl ---
#  
#      This file is part of The Coccinella application.
#      It is an experiment to set login/logout to web service.
#
#  Copyright (c) 2006  Mats Bengtsson
#  
# $Id: NotifyOnline.tcl,v 1.1 2006-01-13 08:55:11 matben Exp $

package require http

namespace eval ::NotifyOnline:: {
    
    # So far only logout (and quit).
    set url "http://chat.evaal.com/logout_jb.php"

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
    set query [::http::formatQuery user $jid]
    
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
