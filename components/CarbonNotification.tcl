# CarbonNotification.tcl --
# 
#       Demo of some of the functionality for components.
#       This is just a first sketch.
#       
# $Id: CarbonNotification.tcl,v 1.5 2005-08-14 08:37:51 matben Exp $

namespace eval ::CarbonNotification:: {
    
}

proc ::CarbonNotification::Init { } {
    global  this
    
    if {[tk windowingsystem] ne "aqua"} {
	return
    }
    if {[catch {package require tclCarbonNotification}]} {
	return
    }
    component::register CarbonNotification  \
      "Provides the bouncing dock icon on Mac OS X."

    # Add event hooks.
    ::hooks::register newMessageHook          [list [namespace current]::EventHook]
    ::hooks::register newChatMessageHook      [list [namespace current]::EventHook]
    ::hooks::register newChatThreadHook       [list [namespace current]::EventHook]
}

proc ::CarbonNotification::EventHook {args} {    

    # Notify only if in background.
    if {![::UI::IsAppInFront]} {
	tclCarbonNotification 1 ""
    }
}

#-------------------------------------------------------------------------------
