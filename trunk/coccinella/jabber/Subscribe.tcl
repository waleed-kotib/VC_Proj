#  Subscribe.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements subscription parts.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
# $Id: Subscribe.tcl,v 1.21 2004-09-28 13:50:19 matben Exp $

package provide Subscribe 1.0

namespace eval ::Jabber::Subscribe:: {

    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          ::Jabber::Subscribe::InitPrefsHook
    ::hooks::register prefsBuildHook         ::Jabber::Subscribe::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::Jabber::Subscribe::SavePrefsHook
    ::hooks::register prefsCancelHook        ::Jabber::Subscribe::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::Jabber::Subscribe::UserDefaultsHook

    # Store everything in 'locals($uid, ... )'.
    variable locals   
    variable uid 0
}

# Jabber::Subscribe::NewDlg --
#
#       Ask for user response on a subscribe presence element.
#
# Arguments:
#       jid    the jid we receive a 'subscribe' presence element from.
#       args   ?-key value ...? look for any '-status' only.
#       
# Results:
#       "deny" or "accept".

proc ::Jabber::Subscribe::NewDlg {jid args} {
    global  this prefs wDlgs

    variable uid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Jabber::Subscribe::NewDlg jid=$jid"
    
    # Initialize the state variable, an array.    
    set token [namespace current]::dlg[incr uid]
    variable $token
    upvar 0 $token state
    
    set w $wDlgs(jsubsc)${uid}
    set state(w)        $w
    set state(jid)      $jid
    set state(args)     $args
    set state(finished) -1
    set state(name)     ""
    set state(group)    ""

    ::UI::Toplevel $w -macstyle documentProc -macclass {document closeBox} \
      -closecommand [list [namespace current]::CloseCmd $token] \
      -usemacmainmenu 1
    wm title $w [mc Subscribe]  
    
    # Find all our groups for any jid.
    set allGroups [$jstate(roster) getgroups]

    # Global frame.
    set wall $w.fr
    frame $wall -borderwidth 1 -relief raised
    pack  $wall -fill both -expand 1 -ipadx 2 -ipady 4

    ::headlabel::headlabel $wall.head -text [mc Subscribe]
    pack $wall.head -side top -fill both -expand 1

    label $wall.msg -wraplength 200 -justify left \
      -text [mc jasubwant $jid]
    pack $wall.msg -padx 10 -side top -fill both -expand 1

    set wbox $wall.opt
    labelframe $wbox -text [mc {Options}]
    pack $wbox -side top -fill both -padx 20 -pady 6

    label $wbox.lnick -text "[mc {Nick name}]:" -anchor e
    entry $wbox.enick -width 24 -textvariable $token\(name)
    label $wbox.lgroup -text "[mc Group]:" -anchor e
    ::combobox::combobox $wbox.egroup -width 12  \
      -textvariable $token\(group)
    eval {$wbox.egroup list insert end} "None $allGroups"

    grid $wbox.lnick  $wbox.enick  -sticky e
    grid $wbox.lgroup $wbox.egroup -sticky e
    grid $wbox.enick  $wbox.egroup -sticky ew
    
    # Button part.
    set frbot [frame $wall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [mc Accept] -default active \
      -command [list [namespace current]::Accept $token]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Deny]  \
      -command [list [namespace current]::Deny $token]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.bvcard -text "[mc {Get vCard}]..."  \
      -command [list ::VCard::Fetch other $jid]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jsubsc)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jsubsc)
    }
    wm resizable $w 0 0
    bind $w <Return> [list $wall.frbot invoke]

    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 10]
    } $wall.msg $w]    
    after idle $script

    # Wait here for a button press and window to be destroyed.
    tkwait window $w

    set ans [expr {($state(finished) <= 0) ? "deny" : "accept"}]
    unset state
    return $ans
}

# Jabber::Subscribe::Deny --
# 
#       Deny the subscription request.

proc ::Jabber::Subscribe::Deny {token} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate

    # Deny presence to this user.
    $jstate(jlib) send_presence -to $state(jid) -type "unsubscribed"
    
    ::UI::SaveWinPrefixGeom $wDlgs(jsubsc)
    set state(finished) 0
    destroy $state(w)
}

# Jabber::Subscribe::Accept --
# 
#       Accept the subscription request.

proc ::Jabber::Subscribe::Accept {token} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    set jid $state(jid)
    set subscription [$jstate(roster) getsubscription $jid]
    
    switch -- $subscription none - from {
	set sendsubsc 1
    } default {
	set sendsubsc 0
    }

    # Accept (allow) subscription.
    $jstate(jlib) send_presence -to $jid -type "subscribed"
	
    # Add user to my roster. Send subscription request.	
    if {$sendsubsc} {
	set opts {}
	if {[string length $state(name)]} {
	    lappend opts -name $state(name)
	}
	if {($state(group) != "") && ($state(group) != "None")} {
	    lappend opts -groups [list $state(group)]
	}
	eval {$jstate(jlib) roster_set $jid [namespace current]::ResProc} $opts
	$jstate(jlib) send_presence -to $jid -type "subscribe"
    }  
    
    ::UI::SaveWinPrefixGeom $wDlgs(jsubsc)
    set state(finished) 0
    destroy $state(w)
}

proc ::Jabber::Subscribe::CloseCmd {token w} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
        
    # Deny presence to this user.
    $jstate(jlib) send_presence -to $state(jid) -type "unsubscribed"
    ::UI::SaveWinPrefixGeom $wDlgs(jsubsc)
}

# Jabber::Subscribe::ResProc --
#
#       This is our callback proc when setting the roster item from the
#       subscription dialog. Catch any errors here.

proc ::Jabber::Subscribe::ResProc {jlibName what} {
        
    ::Debug 2 "::Jabber::Subscribe::ResProc: jlibName=$jlibName, what=$what"

    if {[string equal $what "error"]} {
	tk_messageBox -type ok -message "We got an error from the\
	  Jabber::Subscribe::ResProc callback"
    }   
}

# Prefs page ...................................................................

proc ::Jabber::Subscribe::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    
    # Defaults...
    set jprefs(subsc,inrost)        ask
    set jprefs(subsc,notinrost)     ask
    set jprefs(subsc,auto)          0
    set jprefs(subsc,group)         {}
	
    ::PreferencesUtils::Add [list  \
      [list ::Jabber::jprefs(subsc,inrost)     jprefs_subsc_inrost      $jprefs(subsc,inrost)]  \
      [list ::Jabber::jprefs(subsc,notinrost)  jprefs_subsc_notinrost   $jprefs(subsc,notinrost)]  \
      [list ::Jabber::jprefs(subsc,auto)       jprefs_subsc_auto        $jprefs(subsc,auto)]  \
      [list ::Jabber::jprefs(subsc,group)      jprefs_subsc_group       $jprefs(subsc,group)]  \
      ]
    
}

proc ::Jabber::Subscribe::BuildPrefsHook {wtree nbframe} {
    
    $wtree newitem {Jabber Subscriptions} -text [mc Subscriptions]
    
    # Subscriptions page ---------------------------------------------------
    set wpage [$nbframe page {Subscriptions}]
    ::Jabber::Subscribe::BuildPageSubscriptions $wpage    
}

proc ::Jabber::Subscribe::BuildPageSubscriptions {page} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs

    set ypad [option get [winfo toplevel $page] yPad {}]
    
    foreach key {inrost notinrost auto group} {
	set tmpJPrefs(subsc,$key) $jprefs(subsc,$key)
    }
    
    set labfrpsubs $page.fr
    labelframe $labfrpsubs -text [mc Subscribe]
    pack $labfrpsubs -side top -anchor w -padx 8 -pady 4
    set psubs [frame $labfrpsubs.frin]
    pack $psubs -padx 10 -pady 6 -side left

    label $psubs.la1 -text [mc prefsuif]
    label $psubs.lin -text [mc prefsuis]
    label $psubs.lnot -text [mc prefsuisnot]
    grid $psubs.la1 -columnspan 2 -sticky w -pady $ypad
    grid $psubs.lin $psubs.lnot -sticky w -pady $ypad
    foreach  \
      val {accept      reject      ask}   \
      txt {Auto-accept Auto-reject {Ask each time}} {
	foreach val2 {inrost notinrost} {
	    radiobutton ${psubs}.${val2}${val}  \
	      -text [mc $txt] -value $val  \
	      -variable [namespace current]::tmpJPrefs(subsc,$val2)	      
	}
	grid $psubs.inrost${val} $psubs.notinrost${val} -sticky w -pady $ypad
    }

    set frauto [frame $page.auto]
    pack $frauto -side top -anchor w -padx 10 -pady $ypad
    checkbutton $frauto.autosub -text "  [mc prefsuauto]"  \
      -variable [namespace current]::tmpJPrefs(subsc,auto)
    label $frauto.autola -text [mc {Default group}]:
    entry $frauto.autoent -width 22   \
      -textvariable [namespace current]::tmpJPrefs(subsc,group)
    pack $frauto.autosub -side top -pady $ypad
    pack $frauto.autola $frauto.autoent -side left -pady $ypad -padx 4
}

proc ::Jabber::Subscribe::SavePrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    array set jprefs [array get tmpJPrefs]
    unset tmpJPrefs
}

proc ::Jabber::Subscribe::CancelPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	if {![string equal $jprefs($key) $tmpJPrefs($key)]} {
	    ::Preferences::HasChanged
	    break
	}
    }
}

proc ::Jabber::Subscribe::UserDefaultsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	set tmpJPrefs($key) $jprefs($key)
    }
}

#-------------------------------------------------------------------------------
