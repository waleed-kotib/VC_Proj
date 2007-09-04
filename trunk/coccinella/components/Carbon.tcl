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
# $Id: Carbon.tcl,v 1.6 2007-09-04 14:55:18 matben Exp $
# 
# @@@ Move the sleep stuff to something more generic.

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
    ::hooks::register newMessageHook      [namespace code NewMsgHook]
    ::hooks::register newChatMessageHook  [namespace code NewMsgHook]
    ::hooks::register newChatThreadHook   [namespace code NotifyHook]
    ::hooks::register newMessageBox       [namespace code NotifyHook]
    ::hooks::register appInFrontHook      [namespace code AppInFrontHook]
    ::hooks::register quitAppHook         [namespace code QuitHook]
    ::hooks::register fileTransferReceiveHook  [namespace code NotifyHook]
    ::hooks::register  loginHook          [namespace code LoginHook]

    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          [namespace code InitPrefsHook]
    ::hooks::register prefsBuildHook         [namespace code BuildPrefsHook]
    ::hooks::register prefsSaveHook          [namespace code SavePrefsHook]
    ::hooks::register prefsCancelHook        [namespace code CancelPrefsHook]
    ::hooks::register prefsUserDefaultsHook  [namespace code UserDefaultsHook]
    
    variable wasSleepLoggedOut 0
}

proc ::Carbon::LoginHook {} {
    variable wasSleepLoggedOut
    set wasSleepLoggedOut 0
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
    upvar ::Jabber::jprefs jprefs
    variable wasSleepLoggedOut
    
    switch -- $type {
	sleep - willsleep {
	    if {[::Jabber::IsConnected]} {
		set wasSleepLoggedOut 1
		#::Jabber::DoCloseClientConnection
		::Jabber::SetStatus unavailable -status $jprefs(sleeploutmsg)
	    }
	}
	wakeup {
	    if {$wasSleepLoggedOut && $jprefs(sleeplogin)} {
		if {![::Jabber::IsConnected]} {
		    ::Login::LoginCmd
		}
	    }
	}
    }
}

proc ::Carbon::InitPrefsHook {} {
    upvar ::Jabber::jprefs jprefs

    set jprefs(sleeplogout)  0
    set jprefs(sleeplogin)   0
    set jprefs(sleeploutmsg) ""
    
    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(sleeplogout)  jprefs_sleeplogout   $jprefs(sleeplogout)]  \
      [list ::Jabber::jprefs(sleeplogin)   jprefs_sleeplogin    $jprefs(sleeplogin)]  \
      [list ::Jabber::jprefs(sleeploutmsg) jprefs_sleeploutmsg  $jprefs(sleeploutmsg)]  \
      ]
    
    variable allKeys {sleeplogout  sleeplogin  sleeploutmsg}
}

proc ::Carbon::BuildPrefsHook {wtree nbframe} {
    
    ::Preferences::NewTableItem {Jabber Sleep} [mc Sleep]
    
    set wpage [$nbframe page Sleep]    
    BuildPage $wpage
    bind <Destroy> $nbframe +::Carbon::DestroyPrefsHook
}

proc ::Carbon::BuildPage {page} {
    upvar ::Jabber::jprefs jprefs
    variable tmp
    variable allKeys
    
    foreach key $allKeys {
	set tmp($key) $jprefs($key)
    }

    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]
    
    ttk::frame $wc.head -padding {0 0 0 6}
    ttk::label $wc.head.l -text [mc "Machine Sleep"]
    ttk::separator $wc.head.s -orient horizontal

    grid  $wc.head.l  $wc.head.s
    grid $wc.head.s -sticky ew
    grid columnconfigure $wc.head 1 -weight 1
    pack  $wc.head  -side top -fill x

    set ws $wc.sleep
    ttk::frame $ws

    set varName [namespace current]::tmp(sleeplogout)
    ttk::checkbutton $ws.clout -text [mc "Logout on sleep:"] -variable $varName \
      -command [namespace code [list SetEntryState [list $ws.emsg $ws.clin] $varName]]
    ttk::label $ws.lmsg -text [mc Message]:
    ttk::entry $ws.emsg -font CociSmallFont -width 32  \
      -textvariable [namespace current]::tmp(sleeploutmsg)
    ttk::checkbutton $ws.clin -text [mc "Login again on wakeup"] \
      -variable [namespace current]::tmp(sleeplogin)

    SetEntryState [list $ws.emsg $ws.clin] $varName

    grid  $ws.clout  -         $ws.emsg
    grid  x          $ws.clin  -
    grid $ws.clout -sticky w
    grid $ws.clin -sticky w
    grid $ws.emsg -sticky ew    
    
    grid columnconfigure $ws 0 -minsize 32
    grid columnconfigure $ws 1 -weight 1
    grid columnconfigure $ws 2 -weight 1

    pack  $ws  -side top -fill x
}

proc ::Carbon::SetEntryState {winL varName} {
    upvar #0 $varName var
    if {$var} {
	foreach w $winL {
	    $w state {!disabled}
	}
    } else {
	foreach w $winL {
	    $w state {disabled}
	}
    }
}

proc ::Carbon::SavePrefsHook {} {
    upvar ::Jabber::jprefs jprefs
    variable tmp	
    array set jprefs [array get tmp]
}

proc ::Carbon::CancelPrefsHook {} {
    upvar ::Jabber::jprefs jprefs
    variable tmp
	
    foreach key [array names tmp] {
	if {![string equal $jprefs($key) $tmp($key)]} {
	    ::Preferences::HasChanged
	    return
	}
    }    
}

proc ::Carbon::UserDefaultsHook {} {
    upvar ::Jabber::jprefs jprefs
    variable tmp
	
    foreach key [array names tmp] {
	set tmp($key) $jprefs($key)
    }
}

proc ::Carbon::DestroyPrefsHook {} {
    variable tmp
    
    unset -nocomplain tmp
}

#-------------------------------------------------------------------------------
