#  SpotLight.tcl ---
#  
#       Integrated spotlight bindings for MacOSX.
#       
#  Copyright (c) 2006 Antonio Cano Damas
#
# $Id: SpotLight.tcl,v 1.2 2006-11-24 08:01:54 matben Exp $

namespace eval ::SpotLight:: { }

proc ::SpotLight::Init { } {
    global  this

    if {![string equal $this(platform) "macosx"]} {
        return
    }

    if {[catch {package require Tclapplescript}]} {
        return
    }
    
    # Must check that spotlight exists on this machine.
    return
    
    # Add event hooks.
    ::hooks::register newChatMessageHook ::SpotLight::ChatMessageHook

    component::register SpotLight \
      {Launch SpotLight with incoming messages.}
}

proc ::SpotLight::ChatMessageHook {body args} {
    if {$body eq ""} {
        return
    }
    array set argsA $args

    # -from is a 3-tier jid /resource included.
    set jid $argsA(-from)
    jlib::splitjid $jid jid2 -

#    if {[::Chat::HaveChat $jid]} {
#        return
#    }

    set search_string "$jid2"

    if {[info exists argsA(-subject)]} {
        append search_string " $argsA(-subject)"
    }

    ::SpotLight::Launch $search_string
}

proc ::SpotLight::Launch {search_string} {
	set script " 
		--Search spotlight key shortcuts \n
		set pList to (path to preferences folder as string) & \"com.apple.universalaccess.plist\" \n
		tell application \"System Events\" \n
			set pList to property list file pList \n
			set pListItems to property list items of property list item \"UserAssignableHotKeys\" of contents of pList \n
			set theItem to 1st item of pListItems whose value of property list item 4 is 65 -- index of spotlight shortcut (or 64 for spotlight window) \n
			set {theKey, keyEnabled, ModifierKeys, idx} to value of property list items of theItem \n
			if (keyEnabled = 1) or (keyEnabled = true) then \n
				set ModifierKeys to ModifierKeys / 131072 as integer -- strip bits 0 - 16 \n
				--Press shortcuts \n
				if ModifierKeys div 8 mod 2 = 1 then key down command \n
				if ModifierKeys div 4 mod 2 = 1 then key down option \n
				if ModifierKeys div 2 mod 2 = 1 then key down control \n
				if ModifierKeys mod 2 = 1 then key down shift \n
				key code theKey \n
				key up {command, option, control, shift} \n
				--Send to spotlight query text \n
				delay 1 \n
				keystroke \"$search_string\" \n
			end if \n
		end tell"
	AppleScript execute $script
}

