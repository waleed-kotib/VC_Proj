# Notifier.tcl --
# 
#       Notifies the user of certain events when application is in the
#       background.
#       This is just a first sketch.
#       
# $Id: Notifier.tcl,v 1.2 2004-12-10 10:01:42 matben Exp $

namespace eval ::Notifier:: {
    
}

proc ::Notifier::Init { } {
    global  this
    
    # Use this on windows only.
    if {![string equal $this(platform) "windows"]} {
	return
    }
    if {[catch {package require notebox}]} {
	return
    }
    component::register Notifier  \
      "Provides a small event notifier window."

    # Add event hooks.
    ::hooks::register prefsInitHook         [namespace current]::InitPrefsHook
    ::hooks::register newMessageHook        [namespace current]::MessageHook
    #::hooks::register newChatMessageHook    [namespace current]::ChatHook
    ::hooks::register newChatThreadHook     [namespace current]::ThreadHook
    ::hooks::register oobSetRequestHook     [namespace current]::OOBSetHook
}

proc ::Notifier::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs

    set jprefs(notifier,state) 0
    
    ::PreferencesUtils::Add [list  \
      [list ::Jabber::jprefs(notifier,state)  jprefs_notifier_state  $jprefs(notifier,state)]]   
}

proc ::Notifier::MessageHook {body args} {
    
    array set argsArr $args
    set str "You just received a new message from $argsArr(-from)"
    after 200 [list ::Notifier::DisplayMsg $str]
}

proc ::Notifier::ChatHook {body args} {
    
    array set argsArr $args
    set str "You just received a new chat message from $argsArr(-from)"
    after 200 [list ::Notifier::DisplayMsg $str]
}

proc ::Notifier::ThreadHook {body args} {
    
    array set argsArr $args
    set str "The user $argsArr(-from) just started a new chat thread"
    after 200 [list ::Notifier::DisplayMsg $str]
}

proc ::Notifier::OOBSetHook {from subiq args} {
    
    
}

proc ::Notifier::DisplayMsg {str} {
    upvar ::Jabber::jprefs jprefs
    
    if {$jprefs(notifier,state) && ![::UI::IsAppInFront]} {
	::notebox::addmsg $str
    }
}

#-------------------------------------------------------------------------------
