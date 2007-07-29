#  Subscribe.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements subscription parts.
#      
#  Copyright (c) 2001-2005  Mats Bengtsson
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
# $Id: Subscribe.tcl,v 1.39 2007-07-29 10:28:14 matben Exp $

package provide Subscribe 1.0

namespace eval ::Subscribe:: {

    # Use option database for customization.
    option add *JSubscribe.adduserImage           adduser         widgetDefault
    option add *JSubscribe.adduserDisImage        adduserDis      widgetDefault

    
    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          ::Subscribe::InitPrefsHook
    ::hooks::register prefsBuildHook         ::Subscribe::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::Subscribe::SavePrefsHook
    ::hooks::register prefsCancelHook        ::Subscribe::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::Subscribe::UserDefaultsHook

    # Store everything in 'locals($uid, ... )'.
    variable locals   
    variable uid 0
    
    set ::config(subscribe,show-head) 1
}

# Subscribe::NewDlg --
#
#       Ask for user response on a subscribe presence element.
#
# Arguments:
#       jid    the jid we receive a 'subscribe' presence element from.
#       
# Results:
#       none

proc ::Subscribe::NewDlg {jid} {
    global  this prefs wDlgs config

    variable uid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Subscribe::NewDlg jid=$jid"
    
    # Initialize the state variable, an array.    
    set token [namespace current]::dlg[incr uid]
    variable $token
    upvar 0 $token state
    
    set w $wDlgs(jsubsc)$uid
    set state(w)        $w
    set state(jid)      $jid
    set state(finished) -1
    set state(name)     ""
    set state(group)    ""

    ::UI::Toplevel $w -macstyle documentProc -macclass {document closeBox} \
      -closecommand [list [namespace current]::CloseCmd $token] \
      -usemacmainmenu 1 -class JSubscribe
    wm title $w [mc {Presence Subscription}]  
    
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jsubsc)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jsubsc)
    }
  
    set jlib $jstate(jlib)

    # Find all our groups for any jid.
    set allGroups [$jlib roster getgroups]
    set subscription [$jlib roster getsubscription $jid]
    
    switch -- $subscription none - from {
	set havesubsc 0
    } default {
	set havesubsc 1
    }

    # Global frame.
    set wall $w.fr
    ttk::frame $wall
    pack $wall -fill both -expand 1

    if {$config(subscribe,show-head)} {
	set im  [::Theme::GetImage [option get $w adduserImage {}]]
	set imd [::Theme::GetImage [option get $w adduserDisImage {}]]

	ttk::label $wall.head -style Headlabel \
	  -text [mc {Presence Subscription}] -compound left \
	  -image [list $im background $imd]
	pack $wall.head -side top -fill both -expand 1
	
	ttk::separator $wall.s -orient horizontal
	pack $wall.s -side top -fill x
    }
    set wbox $wall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    set ujid [jlib::unescapejid $jid]
    set str [mc jasubwant2 $ujid]
    if {!$havesubsc} {
	append str " [mc jasubopts2]"
    }
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 200 -justify left -text $str
    pack $wbox.msg -side top -anchor w

    # If we already have a subscription we've already got the opportunity
    # to select nickname and group. Do not repeat that.
    if {!$havesubsc} {
	set frmid $wbox.frmid
	ttk::frame $frmid
	pack $frmid -side top -fill both -expand 1
	
	ttk::label $frmid.lnick -text "[mc {Nickname}]:" -anchor e
	ttk::entry $frmid.enick -width 24 -textvariable $token\(name)
	ttk::label $frmid.lgroup -text "[mc Group]:" -anchor e
	ttk::combobox $frmid.egroup -values [concat None $allGroups] \
	  -textvariable $token\(group)

	grid  $frmid.lnick   $frmid.enick  -sticky e -pady 2
	grid  $frmid.lgroup  $frmid.egroup -sticky e -pady 2
	grid  $frmid.enick   $frmid.egroup -sticky ew	
    }
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Yes] -default active \
      -command [list [namespace current]::Accept $token]
    ttk::button $frbot.btcancel -text [mc No]  \
      -command [list [namespace current]::Deny $token]
    ttk::button $frbot.bvcard -text [mc mBusinessCard] \
      -command [list ::VCard::Fetch other $jid]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
	pack $frbot.bvcard -side left -padx 4
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
	pack $frbot.bvcard -side left -padx 4
    }
    pack $frbot -side top -fill x
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]

    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 30]
    } $wbox.msg $w]    
    after idle $script

    return
}

# Subscribe::Deny --
# 
#       Deny the subscription request.

proc ::Subscribe::Deny {token} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate

    # Deny presence to this user.
    $jstate(jlib) send_presence -to $state(jid) -type "unsubscribed"
    
    ::UI::SaveWinPrefixGeom $wDlgs(jsubsc)
    set state(finished) 0
    destroy $state(w)
    unset state
}

# Subscribe::Accept --
# 
#       Accept the subscription request.

proc ::Subscribe::Accept {token} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    set jid $state(jid)
    set subscription [$jstate(jlib) roster getsubscription $jid]
    
    switch -- $subscription none - from {
	set sendsubsc 1
	set havesubsc 0
    } default {
	set sendsubsc 0
	set havesubsc 1
    }
    set jlib $jstate(jlib)

    # Accept (allow) subscription.
    $jlib send_presence -to $jid -type "subscribed"
	
    # Add user to my roster. Send subscription request.	
    if {$sendsubsc} {
	set opts [list]
	if {[string length $state(name)]} {
	    lappend opts -name $state(name)
	}
	if {($state(group) ne "") && ($state(group) ne "None")} {
	    lappend opts -groups [list $state(group)]
	}
	eval {$jlib roster send_set $jid  \
	  -command [namespace current]::ResProc} $opts
	
	set opts [list]
	set nickname [::Profiles::GetSelected -nickname]
	if {$nickname ne ""} {
	    lappend opts -xlist [list [::Nickname::Element $nickname]]
	}
	eval {$jlib send_presence -to $jid -type "subscribe"} $opts
    }  
    
    ::UI::SaveWinPrefixGeom $wDlgs(jsubsc)
    set state(finished) 0
    destroy $state(w)
    unset state
}

proc ::Subscribe::CloseCmd {token w} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
        
    # Deny presence to this user.
    $jstate(jlib) send_presence -to $state(jid) -type "unsubscribed"
    ::UI::SaveWinPrefixGeom $wDlgs(jsubsc)
    unset state
}

# Subscribe::ResProc --
#
#       This is our callback proc when setting the roster item from the
#       subscription dialog. Catch any errors here.

proc ::Subscribe::ResProc {type queryE} {
        
    ::Debug 2 "::Subscribe::ResProc: type=$type"

    if {[string equal $type "error"]} {
	::UI::MessageBox -type ok -message "We got an error from the\
	  Subscribe::ResProc callback"
    }   
}

# Prefs page ...................................................................

proc ::Subscribe::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    
    # Defaults...
    set jprefs(subsc,inrost)        ask
    set jprefs(subsc,notinrost)     ask
    set jprefs(subsc,auto)          0
    set jprefs(subsc,group)         {}
	
    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(subsc,inrost)     jprefs_subsc_inrost      $jprefs(subsc,inrost)]  \
      [list ::Jabber::jprefs(subsc,notinrost)  jprefs_subsc_notinrost   $jprefs(subsc,notinrost)]  \
      [list ::Jabber::jprefs(subsc,auto)       jprefs_subsc_auto        $jprefs(subsc,auto)]  \
      [list ::Jabber::jprefs(subsc,group)      jprefs_subsc_group       $jprefs(subsc,group)]  \
      ]
    
}

proc ::Subscribe::BuildPrefsHook {wtree nbframe} {
    
    ::Preferences::NewTableItem {Jabber Subscriptions} [mc {Presence Subscription}]
    
    # Subscriptions page ---------------------------------------------------
    set wpage [$nbframe page {Subscriptions}]
    ::Subscribe::BuildPageSubscriptions $wpage    
}

proc ::Subscribe::BuildPageSubscriptions {page} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    foreach key {inrost notinrost auto group} {
	set tmpJPrefs(subsc,$key) $jprefs(subsc,$key)
    }

    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]
    
    set wsubs $wc.fr
    ttk::labelframe $wsubs -text [mc Subscribe] \
      -padding [option get . groupSmallPadding {}]

    ttk::label $wsubs.la1 -text [mc prefsuif2]
    ttk::label $wsubs.lin -text [mc prefsuis]
    ttk::label $wsubs.lnot -text [mc prefsuisnot]
    ttk::separator $wsubs.s -orient vertical
    
    grid  $wsubs.la1  -         -            -sticky w
    grid  $wsubs.lin  -         $wsubs.lnot  -sticky w
    grid  x           $wsubs.s  x            -sticky ns -padx 16
    
    foreach  \
      val { accept        reject        ask }   \
      txt { "Auto-accept" "Auto-reject" "Ask each time" } {
	foreach val2 {inrost notinrost} {
	    ttk::radiobutton $wsubs.${val2}${val}  \
	      -text [mc $txt] -value $val  \
	      -variable [namespace current]::tmpJPrefs(subsc,$val2)	      
	}
	grid  $wsubs.inrost${val}  ^  $wsubs.notinrost${val}  -sticky w
    }
    
    set wauto [ttk::frame $wc.auto]
    ttk::checkbutton $wauto.autosub -text [mc prefsuauto2] \
      -variable [namespace current]::tmpJPrefs(subsc,auto)
    ttk::label $wauto.autola -text [mc {Default group}]:
    ttk::entry $wauto.autoent -font CociSmallFont -width 22   \
      -textvariable [namespace current]::tmpJPrefs(subsc,group)
    
    grid  $wauto.autosub  -               -sticky w
    grid  $wauto.autola   $wauto.autoent  
    grid  $wauto.autoent  -sticky ew
    grid columnconfigure $wauto 1 -weight 1
    
    pack  $wsubs  -side top -fill x
    pack  $wauto  -side top -fill x -pady 12
}

proc ::Subscribe::SavePrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    array set jprefs [array get tmpJPrefs]
    unset tmpJPrefs
}

proc ::Subscribe::CancelPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	if {![string equal $jprefs($key) $tmpJPrefs($key)]} {
	    ::Preferences::HasChanged
	    break
	}
    }
}

proc ::Subscribe::UserDefaultsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	set tmpJPrefs($key) $jprefs($key)
    }
}

#-------------------------------------------------------------------------------
