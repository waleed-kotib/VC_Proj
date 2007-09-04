# Carbon.tcl --
# 
#       Interface for the carbon package.
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
# $Id: Carbon.tcl,v 1.5 2007-09-04 12:35:24 matben Exp $

namespace eval ::Carbon { 

    # Keep track of number of messages we receive while in the background.
    variable nHiddenMsgs 0
}

proc ::Carbon::Init { } {
    
    if {[tk windowingsystem] ne "aqua"} {
	return
    }
    if {[catch {package require carbon}]} {
	return
    }
    component::register Carbon  \
      "Provides Mac OS X specific support such as various dock features."
    
    ::carbon::sleep add ::Carbon::Sleep

    # Add event hooks.
    ::hooks::register newMessageHook      [list [namespace current]::NewMsgHook]
    ::hooks::register newChatMessageHook  [list [namespace current]::NewMsgHook]
    ::hooks::register newChatThreadHook   [list [namespace current]::NotifyHook]
    ::hooks::register newMessageBox       [list [namespace current]::NotifyHook]
    ::hooks::register appInFrontHook      [list [namespace current]::AppInFrontHook]
    ::hooks::register quitAppHook         [list [namespace current]::QuitHook]
    ::hooks::register fileTransferReceiveHook  [list [namespace current]::NotifyHook]
}

proc ::Carbon::NewMsgHook {body args} {
    variable nHiddenMsgs
    
    if {($body ne {}) && ![::UI::IsAppInFront]} {
	incr nHiddenMsgs
	::carbon::dock overlay -text $nHiddenMsgs
	Bounce
    }
}

proc ::Carbon::NotifyHook {args} {
    
    # Notify only if in background.
    if {![::UI::IsAppInFront]} {
	Bounce
    }
}

proc ::Carbon::Bounce {} {
    after idle { ::carbon::dock bounce 1 }
}

proc ::Carbon::AppInFrontHook {} {
    variable nHiddenMsgs
    
    set nHiddenMsgs 0
    ::carbon::dock overlay -text ""
}

proc ::Carbon::QuitHook {} {
    ::carbon::dock overlay -text ""
}

proc ::Carbon::Sleep {type} {
    
    switch -- $type {
	sleep - willsleep {
	    if {[::Jabber::IsConnected]} {
		::Jabber::DoCloseClientConnection
	    }
	}
	wakeup {
	    if {![::Jabber::IsConnected]} {
		# ::Login::LoginCmd
	    }
	}
    }
}

#-------------------------------------------------------------------------------
