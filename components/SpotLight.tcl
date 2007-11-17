#  SpotLight.tcl ---
#  
#       Integrated spotlight bindings for MacOSX.
#       
#  Copyright (c) 2006 Antonio Cano Damas
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
# $Id: SpotLight.tcl,v 1.9 2007-11-17 07:40:52 matben Exp $

namespace eval ::SpotLight:: { 

    # I switch off this since buggy!
    return
    
    if {[::SpotLight::Have]} {
	component::define SpotLight "Launch SpotLight with incoming messages."
    }
}

proc ::SpotLight::Init {} {
    global this
    global tcl_platform

    # Add event hooks.
    ::hooks::register newChatMessageHook ::SpotLight::ChatMessageHook 1

    component::register SpotLight
}

proc ::SpotLight::Have {} {
    global this
    global tcl_platform
  
    #---- Check support of Indexer into our Operating System -------
    if {![string equal $this(platform) "macosx"]} {
	if {![string equal $this(platform) "windows"]} {
	    #@@@ Support for Beagle in Linux coming...
	    return 0
	} else {
	    # Get Google Desktop Registry Entry
	    if {[catch {package require registry}]} {
		return 0
	    } else {
		variable gDesktopURL
		
		# If Google Desktop is Not installed return
		if {[catch {
		    set gDesktopURL [registry get "HKEY_CURRENT_USER\\Software\\Google\\Google Desktop\\API" "search_url"]
		}]} {
		    return 0
		}		
		if {$gDesktopURL eq ""} {
		    return 0
		}
	    }
	}
    } else {
	
	# Check that we are running over a Tiger or greater version of OSX
	set darwinVersion [string index $tcl_platform(osVersion) 0] 
	if { $darwinVersion < 8 } {
		return 0
	} else {
	    
	    # Load AppleScript support needed for launching SpotLight
	    if {[catch {package require Tclapplescript}]} {
		return 0
	    }
	}
    }
    return 1
}

proc ::SpotLight::ChatMessageHook {xmldata} {
    global this

    set body [wrapper::getcdata [wrapper::getfirstchildwithtag $xmldata body]]
    if {$body eq ""} {
        return
    }

    # -from is a 3-tier jid /resource included.
    set jid [wrapper::getattribute $xmldata from]
    set jid2 [jlib::barejid $jid]

    if {[::Chat::HaveChat $jid]} {
        return
    }

    set search_string "$jid2"

    set subject [wrapper::getcdata [wrapper::getfirstchildwithtag $xmldata subject]]
    if {$subject ne ""} {
        append search_string " $subject"
    }

    if {[string equal $this(platform) "macosx"]} {
        LaunchSL $search_string
    } else {
        LaunchGD $search_string
    }
}

#-------------------------------------------
#     Query Launchers
#-------------------------------------------

#-- Google Desktop for Windows
proc ::SpotLight::LaunchGD {search_string} {
    variable gDesktopURL

    set launchURL "$gDesktopURL$search_string"

    ::Utils::OpenURLInBrowser $launchURL
}

#-- SpotLight for Mac OSX Tiger
proc ::SpotLight::LaunchSL {search_string} {
    global  this
    
    if {$this(package,Tclapplescript)} {
	set script {
		--Search spotlight key shortcuts
		set pList to (path to preferences folder as string) & "com.apple.universalaccess.plist"
		tell application "System Events"
			set pList to property list file pList
			set pListItems to property list items of property list item "UserAssignableHotKeys" of contents of pList
			set theItem to 1st item of pListItems whose value of property list item 4 is 65 -- index of spotlight shortcut (or 64 for spotlight window)
			set {theKey, keyEnabled, ModifierKeys, idx} to value of property list items of theItem
			if (keyEnabled = 1) or (keyEnabled = true) then
				set ModifierKeys to ModifierKeys / 131072 as integer -- strip bits 0 - 16
				--Press shortcuts
				if ModifierKeys div 8 mod 2 = 1 then key down command
				if ModifierKeys div 4 mod 2 = 1 then key down option
				if ModifierKeys div 2 mod 2 = 1 then key down control
				if ModifierKeys mod 2 = 1 then key down shift
				key code theKey
				key up {command, option, control, shift}
				--Send to spotlight query text
				delay 1
				keystroke "%s"
			end if
		end tell
	}
	AppleScript execute [format $script $search_string]
    }
}

