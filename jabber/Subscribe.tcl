#  Subscribe.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements subscription parts.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
# $Id: Subscribe.tcl,v 1.7 2004-01-13 14:50:21 matben Exp $

package provide Subscribe 1.0

namespace eval ::Jabber::Subscribe:: {

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

proc ::Jabber::Subscribe::Subscribe {jid args} {
    global  this prefs wDlgs
    
    variable locals   
    variable uid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::Subscribe::Subscribe jid=$jid"

    set w $wDlgs(jsubsc)[incr uid]
    set locals($uid,finished) -1
    set locals($uid,wtop) $w
    set locals($uid,jid) $jid
    array set argsArr $args
    
    ::UI::Toplevel $w -macstyle documentProc
    wm title $w [::msgcat::mc Subscribe]
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
    pack [frame $w.frall -borderwidth 1 -relief raised]  \
      -fill both -expand 1 -ipadx 4
    
    ::headlabel::headlabel $w.frall.head -text [::msgcat::mc Subscribe]
    pack $w.frall.head -side top -fill both -expand 1
    message $w.frall.msg -width 260  \
      -text [::msgcat::mc jasubwant $jid]
    pack $w.frall.msg -side top -fill both -expand 1
    
    # Any -status attribute?
    if {[info exists argsArr(-status)] && [string length $argsArr(-status)]} {
	set txt "Message: \"$argsArr(-status)\""
	label $w.frall.status -wraplength 260 -text $txt
	pack $w.frall.status -side top -anchor w -padx 10
    }
	
    # Some action buttons.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    label $frmid.lvcard -text "[::msgcat::mc jasubgetvcard]:" -font $fontSB \
      -anchor e
    button $frmid.bvcard -text "[::msgcat::mc {Get vCard}]..."   \
      -command [list ::VCard::Fetch other $jid]
    label $frmid.lmsg -text [::msgcat::mc jasubsndmsg]   \
      -font $fontSB -anchor e
    button $frmid.bmsg -text "[::msgcat::mc Send]..."    \
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
    set frcont [::mylabelframe::mylabelframe $fropt {Options}]
    pack $fropt -side top -fill both -ipadx 10 -ipady 6
    checkbutton $frcont.pres -text "  [::msgcat::mc jasuballow $jid]" \
      -variable [namespace current]::locals($uid,allow)
    
    checkbutton $frcont.add -text "  [::msgcat::mc jasubadd $jid]" \
      -variable [namespace current]::locals($uid,add)
    pack $frcont.pres $frcont.add -side top -anchor w -padx 10 -pady 4
    set frsub [frame $frcont.frsub]
    pack $frsub -expand 1 -fill x -side top
    label $frsub.lnick -text "[::msgcat::mc {Nick name}]:" -font $fontSB \
      -anchor e
    entry $frsub.enick -width 26  \
      -textvariable [namespace current]::locals($uid,name)
    label $frsub.lgroup -text "[::msgcat::mc Group]:" -font $fontSB -anchor e
    
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
	$frcont.add configure -state disabled
	$frsub.enick configure -state disabled
	$frsub.egroup configure -state disabled
    }
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btconn -text [::msgcat::mc Accept] -width 8 -default active \
      -command [list [namespace current]::Doit $uid]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Deny] -width 8   \
      -command [list [namespace current]::Cancel $uid]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> "$frbot.btconn invoke"
    focus $w
    
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
    upvar ::Jabber::jstate jstate
    
    set jid $locals($uid,jid)
    ::Jabber::Debug 2 "::Jabber::Subscribe::Doit jid=$jid, locals($uid,add)=$locals($uid,add), locals($uid,allow)=$locals($uid,allow)"
    
    # Accept (allow) or deny subscription.
    if {$locals($uid,allow)} {
	$jstate(jlib) send_presence -to $jid -type "subscribed"
    } else {
	$jstate(jlib) send_presence -to $jid -type "unsubscribed"
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
	eval {$jstate(jlib) roster_set $jid ::Jabber::Subscribe::ResProc} \
	  $arglist
	$jstate(jlib) send_presence -to $jid -type "subscribe"
    }
    set locals($uid,finished) 1
    destroy $locals($uid,wtop)
}

proc ::Jabber::Subscribe::Cancel {uid} {    
    variable locals   
    upvar ::Jabber::jstate jstate
    
    set jid $locals($uid,jid)

    ::Jabber::Debug 2 "::Jabber::Subscribe::Cancel jid=$jid"
    
    # Deny presence to this user.
    $jstate(jlib) send_presence -to $jid -type {unsubscribed}

    set locals($uid,finished) 0
    destroy $locals($uid,wtop)
}

# Jabber::Subscribe::ResProc --
#
#       This is our callback proc when setting the roster item from the
#       subscription dialog. Catch any errors here.

proc ::Jabber::Subscribe::ResProc {jlibName what} {
    
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Subscribe::ResProc: jlibName=$jlibName, what=$what"

    if {[string equal $what "error"]} {
	tk_messageBox -type ok -message "We got an error from the\
	  Jabber::Subscribe::ResProc callback"
    }
    
}

#-------------------------------------------------------------------------------
