#  Subscribe.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements subscription parts.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
# $Id: Subscribe.tcl,v 1.20 2004-09-28 07:05:50 matben Exp $

package provide Subscribe 1.0

namespace eval ::Jabber::Subscribe:: {

    # Define all hooks for preference settings.
    ::hooks::add prefsInitHook          ::Jabber::Subscribe::InitPrefsHook
    ::hooks::add prefsBuildHook         ::Jabber::Subscribe::BuildPrefsHook
    ::hooks::add prefsSaveHook          ::Jabber::Subscribe::SavePrefsHook
    ::hooks::add prefsCancelHook        ::Jabber::Subscribe::CancelPrefsHook
    ::hooks::add prefsUserDefaultsHook  ::Jabber::Subscribe::UserDefaultsHook

    # Store everything in 'locals($uid, ... )'.
    variable locals   
    variable uid 0
}

# Jabber::Subscribe::Subscribe --
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
    set state(w) $w
    set state(jid) $jid
    set state(args) $args
    set state(finished) -1

    ::UI::Toplevel $w -macstyle documentProc -macclass {document closeBox} \
      -closecommand [list [namespace current]::CloseCmd $token]
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
    pack $wall.msg -side top -fill both -expand 1

    
    

    
    
    # Button part.
    set frbot [frame $wall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [mc Accept] -default active \
      -command [list [namespace current]::Doit $token]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Deny]  \
      -command [list [namespace current]::Cancel $token]]  \
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

    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 10]
    } $wall.msg $w]    
    after idle $script

    # Wait here for a button press and window to be destroyed.
    tkwait window $w

    
}

proc ::Jabber::Subscribe::CloseCmd {token} {
    global  wDlgs
    
    ::UI::SaveWinPrefixGeom $wDlgs(jsubsc)
}

proc ::Jabber::Subscribe::Subscribe {jid args} {
    global  this prefs wDlgs
    
    variable locals   
    variable uid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Jabber::Subscribe::Subscribe jid=$jid"

    set w $wDlgs(jsubsc)[incr uid]
    set locals($uid,finished) -1
    set locals($uid,wtop) $w
    set locals($uid,jid) $jid
    array set argsArr $args
    
    ::UI::Toplevel $w -macstyle documentProc -macclass {document closeBox}
    wm title $w [mc Subscribe]
    set fontSB [option get . fontSmallBold {}]
    
    # Find our present groups.
    set allGroups [$jstate(roster) getgroups]
	
    # This gets a list '-name ... -groups ...' etc. from our roster.
    # Note! -groups PLURAL!
    array set itemAttrArr {-name {} -groups {} -subscription none}
    array set itemAttrArr [$jstate(roster) getrosteritem $jid]
    
    # Textvariables for entry and combobox.
    set locals($uid,name) $itemAttrArr(-name)
    if {[llength $itemAttrArr(-groups)] > 0} {
	set locals($uid,group) [lindex $itemAttrArr(-groups) 0]
    }
    
    # Figure out if we shall send a 'subscribe' presence to this user.
    set maySendSubscribe 1
    if {$itemAttrArr(-subscription) == "to" ||  \
      $itemAttrArr(-subscription) == "both"} {
	set maySendSubscribe 0
    }

    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 4
    
    ::headlabel::headlabel $w.frall.head -text [mc Subscribe]
    pack $w.frall.head -side top -fill both -expand 1
    label $w.frall.msg -wraplength 200 -justify left \
      -text [mc jasubwant $jid]
    pack $w.frall.msg -side top -fill both -expand 1
    
    # Any -status attribute?
    if {[info exists argsArr(-status)] && [string length $argsArr(-status)]} {
	set txt "Message: \"$argsArr(-status)\""
	label $w.frall.status -wraplength 260 -text $txt
	pack $w.frall.status -side top -anchor w -padx 10
    }
	
    # Some action buttons.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    label $frmid.lvcard -text "[mc jasubgetvcard]:" -font $fontSB \
      -anchor e
    button $frmid.bvcard -text "[mc {Get vCard}]..."   \
      -command [list ::VCard::Fetch other $jid]
    label $frmid.lmsg -text [mc jasubsndmsg]   \
      -font $fontSB -anchor e
    button $frmid.bmsg -text "[mc Send]..."    \
      -command [list ::Jabber::Subscribe::SendMsg $uid]
    grid $frmid.lvcard -column 0 -row 0 -sticky e -padx 6 -pady 2
    grid $frmid.bvcard -column 1 -row 0 -sticky ew -padx 6 -pady 2
    grid $frmid.lmsg -column 0 -row 1 -sticky e -padx 6 -pady 2
    grid $frmid.bmsg -column 1 -row 1 -sticky ew -padx 6 -pady 2
    pack $frmid -side top -fill both -expand 1

    # The option part.
    set locals($uid,allow) 1
    set locals($uid,add) $jprefs(defSubscribe)
    set fropt $w.frall.fropt
    labelframe $fropt -text {Options}
    pack $fropt -side top -fill both -padx 10 -pady 6
    checkbutton $fropt.pres -text "  [mc jasuballow $jid]" \
      -variable [namespace current]::locals($uid,allow)
    
    checkbutton $fropt.add -text "  [mc jasubadd $jid]" \
      -variable [namespace current]::locals($uid,add)
    pack $fropt.pres $fropt.add -side top -anchor w -padx 10 -pady 4
    set frsub [frame $fropt.frsub]
    pack $frsub -expand 1 -side top -anchor w -padx 10 -pady 2
    label $frsub.lnick -text "[mc {Nick name}]:" -font $fontSB \
      -anchor e
    entry $frsub.enick -width 18  \
      -textvariable [namespace current]::locals($uid,name)
    label $frsub.lgroup -text "[mc Group]:" -font $fontSB -anchor e
    
    ::combobox::combobox $frsub.egroup -width 18  \
      -textvariable [namespace current]::locals($uid,group)
    eval {$frsub.egroup list insert end} "None $allGroups"
    
    grid $frsub.lnick -column 0 -row 0 -sticky e
    grid $frsub.enick -column 1 -row 0 -sticky ew
    grid $frsub.lgroup -column 0 -row 1 -sticky e
    grid $frsub.egroup -column 1 -row 1 -sticky w
    
    # If we may NOT send a 'subscribe' presence to this user.
    if {!$maySendSubscribe} {
	set locals($uid,add) 0
	$fropt.add configure -state disabled
	$frsub.enick configure -state disabled
	$frsub.egroup configure -state disabled
    }
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [mc Accept] -default active \
      -command [list [namespace current]::Doit $uid]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Deny]  \
      -command [list [namespace current]::Cancel $uid]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    focus $w
    
    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s.frall.msg configure -wraplength [expr [winfo reqwidth %s] - 30]
    } $w $w]    
    after idle $script
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    # Cleanup.
    set finito $locals($uid,finished)
    foreach key [array names locals "$uid,*"] {
	unset locals($key)
    }
    return [expr {($finito <= 0) ? "deny" : "accept"}]
}

proc ::Jabber::Subscribe::SendMsg {uid} {
    variable locals   
	
    ::Jabber::NewMsg::Build -to $locals($uid,jid)
}

# Jabber::Subscribe::Doit --
#
#	Execute the subscription.

proc ::Jabber::Subscribe::Doit {uid} {    
    variable locals   
    
    set jid $locals($uid,jid)
    ::Debug 2 "::Jabber::Subscribe::Doit jid=$jid, locals($uid,add)=$locals($uid,add), locals($uid,allow)=$locals($uid,allow)"
    
    # Accept (allow) or deny subscription.
    if {$locals($uid,allow)} {
	::Jabber::JlibCmd send_presence -to $jid -type "subscribed"
    } else {
	::Jabber::JlibCmd send_presence -to $jid -type "unsubscribed"
    }
	
    # Add user to my roster. Send subscription request.	
    if {$locals($uid,add)} {
	set arglist {}
	if {[string length $locals($uid,name)]} {
	    lappend arglist -name $locals($uid,name)
	}
	if {($locals($uid,group) != "") && ($locals($uid,group) != "None")} {
	    lappend arglist -groups [list $locals($uid,group)]
	}
	eval {::Jabber::JlibCmd roster_set $jid ::Jabber::Subscribe::ResProc} \
	  $arglist
	::Jabber::JlibCmd send_presence -to $jid -type "subscribe"
    }
    set locals($uid,finished) 1
    destroy $locals($uid,wtop)
}

proc ::Jabber::Subscribe::Cancel {uid} {    
    variable locals   
    
    set jid $locals($uid,jid)

    ::Debug 2 "::Jabber::Subscribe::Cancel jid=$jid"
    
    # Deny presence to this user.
    ::Jabber::JlibCmd send_presence -to $jid -type "unsubscribed"

    set locals($uid,finished) 0
    destroy $locals($uid,wtop)
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
