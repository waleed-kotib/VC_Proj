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
# $Id: Notifier.tcl,v 1.10 2008-01-06 12:11:00 matben Exp $

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
    ::hooks::register newChatThreadHook     [namespace current]::ThreadHook
    ::hooks::register presenceNewHook       [namespace current]::PresenceHook
    ::hooks::register fileTransferReceiveHook [namespace current]::FileTransferRecvHook
    
    set subPath [file join images 16]    
    set im [::Theme::GetImage close $subPath]

    option add *Notebox.closeButtonImage  $im     widgetDefault
    option add *Notebox.millisecs         10000   widgetDefault
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
    set djid [::Roster::GetDisplayName $from]
    set str "You just received a new message from $djid"
    after 200 [list ::Notifier::DisplayMsg $str]
}

proc ::Notifier::ThreadHook {xmldata} {
    
    if {![::UI::IsAppInFront]} {
	set body [wrapper::getcdata [wrapper::getfirstchildwithtag $xmldata body]]
	if {![string length $body]} {
	    return
	}
	set from [wrapper::getattribute $xmldata from]
	set djid [::Roster::GetDisplayName $from]
	set str "The user $djid just started a new chat thread"
	after 200 [list ::Notifier::DisplayMsg $str]
    }
}

proc ::Notifier::PresenceHook {jid type args} {

    if {![::UI::IsAppInFront]} {

	set delay [::Jabber::Jlib roster getx $jid "jabber:x:delay"]
	if {$delay ne ""} {
	    return
	}
	if {[::Jabber::Jlib service isroom $jid]} {
	    return
	}
	set wasavail [::Jabber::Jlib roster wasavailable $jid]
	set isavail [expr {$type eq "available"}]
	if {(!$wasavail && $isavail) || ($wasavail && !$isavail)} {
	    
	    array set argsA $args
	    set show $type
	    if {[info exists argsA(-show)]} {
		set show $argsA(-show)
	    }
	    set status ""
	    if {[info exists argsA(-status)]} {
		set status $argsA(-status)
	    }
	    
	    # This just translates the show code into a readable text.
	    set showMsg [::Roster::MapShowToText $show]
	    set djid [::Roster::GetDisplayName $jid]

	    set msg "$djid $showMsg"
	    if {$status ne ""} {
		append msg "\n$status"
	    }
	    after 200 [list ::Notifier::DisplayMsg $msg]
	}
    }
}

proc ::Notifier::FileTransferRecvHook {jid name size} {
    
    if {![::UI::IsAppInFront]} {
	set str "\n[mc File]: $name\n[mc Size]: [::Utils::FormatBytes $size]\n"
	set djid [::Roster::GetDisplayName $jid]
	set msg [mc jamessoobask2 $djid $str]
	after 200 [list ::Notifier::DisplayMsg $str]
    }
}

proc ::Notifier::DisplayMsg {str} {
    upvar ::Jabber::jprefs jprefs
    
    # @@@ ::UI::IsAppInFront is not reliable...
    if {$jprefs(notifier,state) && ![::UI::IsAppInFront]} {
	::notebox::addmsg $str
    }
}

#-------------------------------------------------------------------------------
