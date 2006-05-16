# Carbon.tcl --
# 
#       Interface for the carbon package.
#       
# $Id: Carbon.tcl,v 1.2 2006-05-16 06:06:28 matben Exp $

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
    }
}

#-------------------------------------------------------------------------------
