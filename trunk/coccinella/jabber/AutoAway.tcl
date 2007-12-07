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
# $Id: AutoAway.tcl,v 1.15 2007-12-07 15:22:28 matben Exp $

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
    variable savedShowStatus [list available ""]
    variable wasAutoLoggedOut 0
    
    # Shall we allow the user to have autoaway on "hidden chat tabs".
    set ::config(aa,on-hidden-tabs) 0
    
    # Send global busy presence if we have many tabs open.
    set ::config(aa,busy-chats) 1
}

proc ::AutoAway::GetPriorityForShow {show} {
    variable statusPriority
    return $statusPriority($show)
}

proc ::AutoAway::LoginHook {} {
    variable wasAutoLoggedOut
    
    set wasAutoLoggedOut 0
    ::idletime::init
    Setup
}

proc ::AutoAway::LogoutHook {} {    
    upvar ::Jabber::jprefs jprefs

    #::idletime::stop
    ::idletime::remove [namespace code AwayCmd]
    ::idletime::remove [namespace code XAwayCmd]
}

proc ::AutoAway::InitPrefsHook {} {
    global  prefs config
    upvar ::Jabber::jprefs jprefs
    
    # Auto away page:
    set jprefs(autoaway)     1
    set jprefs(xautoaway)    1
    set jprefs(awaymin)      15
    set jprefs(xawaymin)     30
    set jprefs(awaymsg)      ""
    set jprefs(xawaymsg)     ""
    set jprefs(autologout)   0
    set jprefs(logoutmin)    0
    set jprefs(logoutmsg)    ""
    set jprefs(aalogin)      0

    ::PrefUtils::Add [list \
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

    # Set some kind of auto-away on hidden tabs.
    set jprefs(aa,on-hidden-tabs) 0
    
    # Set busy presence when several active chat tabs.
    set jprefs(aa,busy-chats)     0
    set jprefs(aa,busy-chats-n)   3
    set jprefs(aa,busy-chats-msg) ""

    ::PrefUtils::Add [list \
      [list ::Jabber::jprefs(aa,on-hidden-tabs)  jprefs_aa_on-hidden-tabs  $jprefs(aa,on-hidden-tabs)]  \
      [list ::Jabber::jprefs(aa,busy-chats)      jprefs_aa_busy-chats      $jprefs(aa,busy-chats)]  \
      [list ::Jabber::jprefs(aa,busy-chats-n)    jprefs_aa_busy-chats-n    $jprefs(aa,busy-chats-n)]  \
      [list ::Jabber::jprefs(aa,busy-chats-msg)  jprefs_aa_busy-chats-msg  $jprefs(aa,busy-chats-msg)]  \
      ]
    if {!$config(aa,on-hidden-tabs)} {
	set jprefs(aa,on-hidden-tabs) 0
    }
    if {!$config(aa,busy-chats)} {
	set jprefs(aa,busy-chats) 0
    }
    
    variable allKeys
    set allKeys {
	autoaway   awaymin   awaymsg
	xautoaway  xawaymin  xawaymsg
	autologout logoutmin logoutmsg
	aalogin    
	aa,on-hidden-tabs
	aa,busy-chats        aa,busy-chats-n      aa,busy-chats-msg
    }
}

# AutoAway::Setup --
#
#       Setup the auto away callbacks using idletime.

proc ::AutoAway::Setup {} { 
    upvar ::Jabber::jprefs jprefs
	       
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
    variable wasAutoLoggedOut
    
    set wasAutoLoggedOut 1
    Cmd unavailable $what
}

proc ::AutoAway::Cmd {show what} {
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    variable statusPriority
    variable savedShowStatus
    variable pendingActive
    variable wasAutoLoggedOut
    
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
	if {$jprefs(autologout) && $wasAutoLoggedOut} {
	    ::Login::LoginCmd   
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
	
    ::Preferences::NewTableItem {Jabber {Auto Away}} [mc "Auto Away"]
    
    # Auto Away page -------------------------------------------------------
    set wpage [$nbframe page {Auto Away}]    
    BuildPage $wpage
    
    bind <Destroy> $nbframe +::AutoAway::DestroyPrefsHook
}

proc ::AutoAway::BuildPage {page} {
    global  config
    upvar ::Jabber::jprefs jprefs
    variable tmpp
    variable allKeys
    
    foreach key $allKeys {
	set tmpp($key) $jprefs($key)
    }
    
    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]
    
    ttk::frame $wc.head -padding {0 0 0 6}
    ttk::label $wc.head.l -text [mc "Auto Away"]
    ttk::separator $wc.head.s -orient horizontal
    
    grid  $wc.head.l  $wc.head.s
    grid $wc.head.s -sticky ew
    grid columnconfigure $wc.head 1 -weight 1
    pack  $wc.head  -side top -fill x
    
    set waa $wc.aa
    ttk::frame $waa
    pack  $waa  -side top -fill x
    
    set str "[mc prefminaw2] ([mc Minutes]):"
    set varName [namespace current]::tmpp(autoaway)
    ttk::checkbutton $waa.lminaw -text $str -variable $varName \
      -command [namespace code [list SetEntryState [list $waa.eminaw $waa.eawmsg] $varName]]
    ttk::entry $waa.eminaw -font CociSmallFont -width 3 \
      -validate key -validatecommand {::Utils::ValidMinutes %S} \
      -textvariable [namespace current]::tmpp(awaymin)
    ttk::label $waa.law -text [mc Message]:
    ttk::entry $waa.eawmsg -font CociSmallFont -width 32  \
      -textvariable [namespace current]::tmpp(awaymsg)
    ttk::frame $waa.paw -height 6

    SetEntryState [list $waa.eminaw $waa.eawmsg] $varName

    grid  $waa.lminaw  -         -            $waa.eminaw  -pady 1
    grid  x            $waa.law  $waa.eawmsg  -            -pady 1
    grid  $waa.paw
    grid $waa.lminaw -sticky w
    grid $waa.eawmsg -sticky ew

    set str "[mc prefminea2] ([mc Minutes]):"
    set varName [namespace current]::tmpp(xautoaway)
    ttk::checkbutton $waa.lminxa -text $str -variable $varName \
      -command [namespace code [list SetEntryState [list $waa.eminxa $waa.examsg] $varName]]
    ttk::entry $waa.eminxa -font CociSmallFont -width 3  \
      -validate key -validatecommand {::Utils::ValidMinutes %S} \
      -textvariable [namespace current]::tmpp(xawaymin)
    ttk::label $waa.lxa -text [mc Message]:
    ttk::entry $waa.examsg -font CociSmallFont -width 32  \
      -textvariable [namespace current]::tmpp(xawaymsg)
    ttk::frame $waa.pxa -height 6

    SetEntryState [list $waa.eminxa $waa.examsg] $varName

    grid  $waa.lminxa  -         -            $waa.eminxa  -pady 1
    grid  x            $waa.lxa  $waa.examsg  -            -pady 1
    grid  $waa.pxa
    grid $waa.lminxa -sticky w
    grid $waa.eawmsg -sticky ew    
        
    set str "[mc prefminlogout] ([mc Minutes]):"
    set varName [namespace current]::tmpp(autologout)
    ttk::checkbutton $waa.clo -text $str -variable $varName \
      -command [namespace code [list SetEntryState [list $waa.elomin $waa.elomsg $waa.cli] $varName]]
    ttk::entry $waa.elomin -font CociSmallFont -width 3  \
      -validate key -validatecommand {::Utils::ValidMinutes %S} \
      -textvariable [namespace current]::tmpp(logoutmin)
    ttk::label $waa.llo -text [mc Message]:
    ttk::entry $waa.elomsg -font CociSmallFont -width 32  \
      -textvariable [namespace current]::tmpp(logoutmsg)
    ttk::checkbutton $waa.cli -text [mc "Relogin on activity"] \
      -variable [namespace current]::tmpp(aalogin)

    SetEntryState [list $waa.elomin $waa.elomsg $waa.cli] $varName
    
    grid  $waa.clo  -         -            $waa.elomin  -pady 1
    grid  x         $waa.llo  $waa.elomsg  -            -pady 1
    grid  x         $waa.cli  -            -
    grid $waa.clo -sticky w
    grid $waa.cli -sticky w
    grid $waa.elomsg -sticky ew    
    
    grid columnconfigure $waa 0 -minsize 32
    grid columnconfigure $waa 2 -weight 1

    if {$config(aa,on-hidden-tabs)} {
	ttk::checkbutton $waa.htabs -text [mc "Apply auto-away on hidden chat tabs"] \
	  -variable [namespace current]::tmpp(aa,on-hidden-tabs)
	
	grid  $waa.htabs  -  -  -  -sticky w
	
	::balloonhelp::balloonforwindow $waa.htabs \
	  "If activated then directed auto-away presence will be sent to users on hidden chat tabs"
    }
    
    if {$config(aa,busy-chats)} {
	set varName [namespace current]::tmpp(aa,busy-chats)
	ttk::checkbutton $waa.cbusy -text [mc "Busy when (active chat sessions)"]: \
	  -variable $varName \
	  -command [namespace code [list SetEntryState [list $waa.ebusy $waa.mbusy] $varName]]
	ttk::entry $waa.ebusy -font CociSmallFont -width 3  \
	  -validate key -validatecommand {::Utils::ValidMinutes %S} \
	  -textvariable [namespace current]::tmpp(aa,busy-chats-n)
	ttk::label $waa.lbusy -text [mc Message]:
	ttk::entry $waa.mbusy -font CociSmallFont -width 32  \
	  -textvariable [namespace current]::tmpp(aa,busy-chats-msg)
	
	grid  $waa.cbusy  -           -           $waa.ebusy  -pady 1
	grid  x           $waa.lbusy  $waa.mbusy  -           -pady 1 
	grid $waa.cbusy -sticky w
	grid $waa.mbusy -sticky ew    

	SetEntryState [list $waa.ebusy $waa.mbusy] $varName

	set bstr [mc "When you have <number> or more active chat sessions, presence state will be automatically changed to Busy."]
	::balloonhelp::balloonforwindow $waa.cbusy $bstr
    }
    return $page
}

proc ::AutoAway::SetEntryState {winL varName} {
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

proc ::AutoAway::SavePrefsHook {} {
    upvar ::Jabber::jprefs jprefs
    variable tmpp
        
    array set jprefs [array get tmpp]
    
    # If changed present auto away settings, may need to reconfigure.
    Setup  
}

proc ::AutoAway::CancelPrefsHook {} {
    global  prefs
    upvar ::Jabber::jprefs jprefs
    variable tmpp
	
    foreach key [array names tmpp] {
	if {![string equal $jprefs($key) $tmpp($key)]} {
	    ::Preferences::HasChanged
	    return
	}
    }    
}

proc ::AutoAway::UserDefaultsHook {} {
    upvar ::Jabber::jprefs jprefs
    variable tmpp
	
    foreach key [array names tmpp] {
	set tmpp($key) $jprefs($key)
    }
}

proc ::AutoAway::DestroyPrefsHook {} {
    variable tmpp
    
    unset -nocomplain tmpp
}

#-------------------------------------------------------------------------------
