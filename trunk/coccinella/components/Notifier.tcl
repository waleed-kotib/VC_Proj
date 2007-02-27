# Notifier.tcl --
# 
#       Notifies the user of certain events when application is in the
#       background.
#       This is just a first sketch.
#       
# $Id: Notifier.tcl,v 1.5 2007-02-27 10:02:13 matben Exp $

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
    
    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(notifier,state)  jprefs_notifier_state  $jprefs(notifier,state)]]   
}

proc ::Notifier::MessageHook {body args} {
    
    if {![string length $body]} {
	return
    }
    array set argsA $args
    set xmldata $argsA(-xmldata)
    set from [wrapper::getattribute $xmldata from]
    set str "You just received a new message from $from"
    after 200 [list ::Notifier::DisplayMsg $str]
}

proc ::Notifier::ChatHook {body args} {
    
    if {![string length $body]} {
	return
    }
    array set argsA $args
    set xmldata $argsA(-xmldata)
    set from [wrapper::getattribute $xmldata from]
    set str "You just received a new chat message from $from"
    after 200 [list ::Notifier::DisplayMsg $str]
}

proc ::Notifier::ThreadHook {body args} {
    
    if {![string length $body]} {
	return
    }
    array set argsA $args
    set xmldata $argsA(-xmldata)
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
