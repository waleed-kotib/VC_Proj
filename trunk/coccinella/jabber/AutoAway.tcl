#  AutoAway.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements autoaway settings.
#      
#  Copyright (c) 2007  Mats Bengtsson
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
# $Id: AutoAway.tcl,v 1.4 2007-09-04 12:35:25 matben Exp $

package require idletime

package provide AutoAway 1.0

namespace eval ::AutoAway {
    
    ::hooks::register  loginHook       ::AutoAway::LoginHook
    ::hooks::register  logoutHook      ::AutoAway::LogoutHook
    
    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          ::AutoAway::InitPrefsHook
    ::hooks::register prefsBuildHook         ::AutoAway::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::AutoAway::SavePrefsHook
    ::hooks::register prefsCancelHook        ::AutoAway::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::AutoAway::UserDefaultsHook

    # Auto away and extended away are only set when the
    # current status has a lower priority than away or xa respectively.
    # After an idea by Zbigniew Baniewski.
    variable statusPriority
    array set statusPriority {
	chat            1
	available       2
	away            3
	xa              4
	dnd             5
	invisible       6
	unavailable     7
    }
    variable savedShowStatus {available ""}
}

proc ::AutoAway::LoginHook {} {
    puts "::AutoAway::LoginHook"
    ::idletime::init
    Setup
}

proc ::AutoAway::LogoutHook {} {    
    upvar ::Jabber::jprefs jprefs

    puts "::AutoAway::LogoutHook"
    ::idletime::stop
    if {$jprefs(aalogin)} {
	
    }
}

proc ::AutoAway::InitPrefsHook {} {
    global  prefs
    upvar ::Jabber::jprefs jprefs
    
    # Auto away page:
    set jprefs(autoaway)     0
    set jprefs(xautoaway)    0
    set jprefs(awaymin)      0
    set jprefs(xawaymin)     0
    set jprefs(awaymsg)      ""
    set jprefs(xawaymsg)     [mc prefuserinactive]
    set jprefs(autologout)   0
    set jprefs(logoutmin)    0
    set jprefs(logoutmsg)    ""
    set jprefs(aalogin)      0

    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(autoaway)    jprefs_autoaway     $jprefs(autoaway)]  \
      [list ::Jabber::jprefs(xautoaway)   jprefs_xautoaway    $jprefs(xautoaway)]  \
      [list ::Jabber::jprefs(awaymin)     jprefs_awaymin      $jprefs(awaymin)]  \
      [list ::Jabber::jprefs(xawaymin)    jprefs_xawaymin     $jprefs(xawaymin)]  \
      [list ::Jabber::jprefs(awaymsg)     jprefs_awaymsg      $jprefs(awaymsg)]  \
      [list ::Jabber::jprefs(xawaymsg)    jprefs_xawaymsg     $jprefs(xawaymsg)]  \
      [list ::Jabber::jprefs(autologout)  jprefs_autologout   $jprefs(autologout)]  \
      [list ::Jabber::jprefs(logoutmin)   jprefs_logoutmin    $jprefs(logoutmin)]  \
      [list ::Jabber::jprefs(logoutmsg)   jprefs_logoutmsg    $jprefs(logoutmsg)]  \
      [list ::Jabber::jprefs(aalogin)     jprefs_aalogin      $jprefs(aalogin)]  \
      ]
 
    variable allKeys
    set allKeys {
	autoaway   awaymin   awaymsg
	xautoaway  xawaymin  xawaymsg
	autologout logoutmin logoutmsg
	aalogin
    }
}

# AutoAway::Setup --
#
#       Setup the auto away callbacks using idletime.

proc ::AutoAway::Setup {} { 
    upvar ::Jabber::jprefs jprefs
    
    #puts "::AutoAway::Setup"
	       
    if {$jprefs(autoaway) && [string is integer -strict $jprefs(awaymin)]} {
	::idletime::add [namespace code AwayCmd] [expr {60*$jprefs(awaymin)}]
    } else {
	::idletime::remove [namespace code AwayCmd]
    }
    if {$jprefs(xautoaway) && [string is integer -strict $jprefs(xawaymin)]} {
	
	# We add a few seconds to xaway so in case both have the same timeout
	# time we send xa after away.
	::idletime::add [namespace code XAwayCmd] [expr {60*$jprefs(xawaymin) + 5}]
    } else {
	::idletime::remove [namespace code XAwayCmd]
    }
    if {$jprefs(autologout) && [string is integer -strict $jprefs(logoutmin)]} {
	::idletime::add [namespace code LogoutCmd] [expr {60*$jprefs(logoutmin)}]
    } else {
	::idletime::remove [namespace code LogoutCmd]
    }
}

proc ::AutoAway::AwayCmd {what} {
    Cmd away $what
}

proc ::AutoAway::XAwayCmd {what} {
    Cmd xa $what
}

proc ::AutoAway::LogoutCmd {what} {
    Cmd unavailable $what
}

proc ::AutoAway::Cmd {show what} {
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    variable statusPriority
    variable savedShowStatus
    variable pendingActive
    
    Debug 4 "::AutoAway::Cmd show=$show, what=$what"
    
    if {$show eq "xa"} {
	set key xaway
    } elseif {$show eq "unavailable"} {
	set key logout
    } else {
	set key $show
    }
    
    if {$what eq "idle"} {
	
	# Auto away and extended away are only set when the
	# current status has a lower priority than away or xa respectively.
	set pshow $jstate(show)
	if {$statusPriority($pshow) >= $statusPriority($show)} {
	    return
	}
	
	# Save show/status only if going to 'xa' from a lower priority
	# than 'away'. This to avoid saving show/status when first autoaway
	# sets 'away' and then later 'xa'.
	if {$show eq "away"} {
	    set savedShowStatus $jstate(show+status)
	} elseif {($show eq "xa") && \
	  ($statusPriority($pshow) < $statusPriority(away))} {
	    set savedShowStatus $jstate(show+status)
	}
	set status $jprefs(${key}msg)
	::Jabber::SetStatus $show -status $status
	::Status::ExAddMessage $show $status
    } elseif {$what eq "active"} {

	# Must be sure to not trigger this twice!!!
	if {![info exists pendingActive]} {
	    set pendingActive [after idle [namespace code Active]]
	}
    }
}

proc ::AutoAway::Active {} {
    variable pendingActive
    variable savedShowStatus

    unset -nocomplain pendingActive
    
    # Set it to what it was before auto away.
    lassign $savedShowStatus show status
    ::Jabber::SetStatus $show -status $status	
}

proc ::AutoAway::BuildPrefsHook {wtree nbframe} {
	
    ::Preferences::NewTableItem {Jabber {Auto Away}} [mc {Auto Away}]
    
    # Auto Away page -------------------------------------------------------
    set wpage [$nbframe page {Auto Away}]    
    BuildPage $wpage
    
    bind <Destroy> $nbframe +::AutoAway::DestroyPrefsHook
}

proc ::AutoAway::BuildPage {page} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    variable allKeys
    
    foreach key $allKeys {
	set tmpJPrefs($key) $jprefs($key)
    }
    
    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]
    
    ttk::frame $wc.head -padding {0 0 0 6}
    ttk::label $wc.head.l -text [mc prefaaset]
    ttk::separator $wc.head.s -orient horizontal
    
    grid  $wc.head.l  $wc.head.s
    grid $wc.head.s -sticky ew
    grid columnconfigure $wc.head 1 -weight 1
    pack  $wc.head  -side top -fill x
    
    set waa $wc.aa
    ttk::frame $waa
    
    set varName [namespace current]::tmpJPrefs(autoaway)
    ttk::checkbutton $waa.lminaw -text [mc prefminaw] -variable $varName \
      -command [namespace code [list SetEntryState $waa.eminaw $waa.eawmsg $varName]]
    ttk::entry $waa.eminaw -font CociSmallFont -width 3 \
      -validate key -validatecommand {::Utils::ValidMinutes %S} \
      -textvariable [namespace current]::tmpJPrefs(awaymin)
    ttk::label $waa.law -text [mc Message]:
    ttk::entry $waa.eawmsg -font CociSmallFont -width 32  \
      -textvariable [namespace current]::tmpJPrefs(awaymsg)
    ttk::frame $waa.paw -height 6

    SetEntryState $waa.eminaw $waa.eawmsg $varName

    grid  $waa.lminaw  -         -            $waa.eminaw
    grid  x            $waa.law  $waa.eawmsg  -
    grid  $waa.paw
    grid $waa.lminaw -sticky w
    grid $waa.eawmsg -sticky ew

    set varName [namespace current]::tmpJPrefs(xautoaway)
    ttk::checkbutton $waa.lminxa -text [mc prefminea] -variable $varName \
      -command [namespace code [list SetEntryState $waa.eminxa $waa.examsg $varName]]
    ttk::entry $waa.eminxa -font CociSmallFont -width 3  \
      -validate key -validatecommand {::Utils::ValidMinutes %S} \
      -textvariable [namespace current]::tmpJPrefs(xawaymin)
    ttk::label $waa.lxa -text [mc Message]:
    ttk::entry $waa.examsg -font CociSmallFont -width 32  \
      -textvariable [namespace current]::tmpJPrefs(xawaymsg)
    ttk::frame $waa.pxa -height 6

    SetEntryState $waa.eminxa $waa.examsg $varName

    grid  $waa.lminxa  -         -            $waa.eminxa
    grid  x            $waa.lxa  $waa.examsg  -
    grid  $waa.pxa
    grid $waa.lminaw -sticky w
    grid $waa.eawmsg -sticky ew    
        
    set varName [namespace current]::tmpJPrefs(autologout)
    ttk::checkbutton $waa.clo -text [mc prefminlogout] -variable $varName \
      -command [namespace code [list SetEntryState $waa.elomin $waa.elomsg $varName]]
    ttk::entry $waa.elomin -font CociSmallFont -width 3  \
      -validate key -validatecommand {::Utils::ValidMinutes %S} \
      -textvariable [namespace current]::tmpJPrefs(logoutmin)
    ttk::label $waa.llo -text [mc Message]:
    ttk::entry $waa.elomsg -font CociSmallFont -width 32  \
      -textvariable [namespace current]::tmpJPrefs(logoutmsg)
    ttk::checkbutton $waa.cli -text [mc prefaalogin] \
      -variable [namespace current]::tmpJPrefs(aalogin)

    SetEntryState $waa.elomin $waa.elomsg $varName
    
    grid  $waa.clo  -         -            $waa.elomin
    grid  x         $waa.llo  $waa.elomsg  -
    grid  x         $waa.cli  -            -
    grid $waa.clo -sticky w
    grid $waa.cli -sticky w
    grid $waa.elomsg -sticky ew    
    
    grid columnconfigure $waa 0 -minsize 32
    grid columnconfigure $waa 2 -weight 1

    pack  $waa  -side top -fill x
}

proc ::AutoAway::SetEntryState {win1 win2 varName} {
    upvar #0 $varName var
    if {$var} {
	$win1 state {!disabled}
	$win2 state {!disabled}
    } else {
	$win1 state {disabled}
	$win2 state {disabled}
    }
}

proc ::AutoAway::BuildPageXXX {page} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    foreach key {autoaway awaymin xautoaway xawaymin awaymsg xawaymsg \
      logoutmsg} {
	set tmpJPrefs($key) $jprefs($key)
    }
    
    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]
    
    # Auto away stuff.
    set waf $wc.fm

    ttk::label $wc.lab -text [mc prefaaset]
    ttk::frame $waf

    ttk::checkbutton $waf.lminaw -text [mc prefminaw]  \
      -variable [namespace current]::tmpJPrefs(autoaway)
    ttk::entry $waf.eminaw -font CociSmallFont -width 3 \
      -validate key -validatecommand {::Utils::ValidMinutes %S} \
      -textvariable [namespace current]::tmpJPrefs(awaymin)
    ttk::checkbutton $waf.lminxa -text [mc prefminea]  \
      -variable [namespace current]::tmpJPrefs(xautoaway)
    ttk::entry $waf.eminxa -font CociSmallFont -width 3  \
      -validate key -validatecommand {::Utils::ValidMinutes %S} \
      -textvariable [namespace current]::tmpJPrefs(xawaymin)

    grid  $waf.lminaw  $waf.eminaw  -sticky w -pady 1
    grid  $waf.lminxa  $waf.eminxa  -sticky w -pady 1

    set was $wc.fs
    ttk::frame $was
    ttk::label $was.lawmsg -text "[mc {Away status}]:"
    ttk::entry $was.eawmsg -font CociSmallFont -width 32  \
      -textvariable [namespace current]::tmpJPrefs(awaymsg)
    ttk::label $was.lxa -text "[mc {Extended Away status}]:"
    ttk::entry $was.examsg -font CociSmallFont -width 32  \
      -textvariable [namespace current]::tmpJPrefs(xawaymsg)
    
    grid  $was.lawmsg  $was.eawmsg  -sticky e -pady 1
    grid  $was.lxa     $was.examsg  -sticky e -pady 1

    pack  $wc.lab  $waf  $was  -side top -anchor w
}

proc ::AutoAway::SavePrefsHook {} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
        
    array set jprefs [array get tmpJPrefs]
    
    # If changed present auto away settings, may need to reconfigure.
    Setup  
}

proc ::AutoAway::CancelPrefsHook {} {
    global  prefs
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	if {![string equal $jprefs($key) $tmpJPrefs($key)]} {
	    ::Preferences::HasChanged
	    return
	}
    }    
}

proc ::AutoAway::UserDefaultsHook {} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	set tmpJPrefs($key) $jprefs($key)
    }
}

proc ::AutoAway::DestroyPrefsHook {} {
    variable tmpJPrefs
    
    unset -nocomplain tmpJPrefs
}

#-------------------------------------------------------------------------------
