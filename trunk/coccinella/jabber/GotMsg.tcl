#  GotMsg.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements a dialog for jabber messages.
#      
#  Copyright (c) 2002  Mats Bengtsson
#  
# $Id: GotMsg.tcl,v 1.40 2005-05-28 07:04:15 matben Exp $

package provide GotMsg 1.0

namespace eval ::GotMsg:: {

    # Add all event hooks.
    ::hooks::register quitAppHook        ::GotMsg::QuitAppHook
    ::hooks::register closeWindowHook    ::GotMsg::CloseHook
    ::hooks::register presenceHook       ::GotMsg::PresenceHook    
    
    # Wait for this variable to be set.
    variable finished  
        
    # msgId for the one in the dialog.
    variable msgIdDisplay 0
    
    variable locals
    set locals(updateDateid)  ""
    set locals(updateDatems)  [expr 1000*60]
}

proc ::GotMsg::QuitAppHook { } {
    global  wDlgs
    
    ::UI::SaveWinGeom $wDlgs(jgotmsg)
}

# GotMsg::GotMsg --
#
#       Called when we get an incoming message.
#       Calls 'GotMsg::Show' if not mapped.
#
# Arguments:
#       id          the message id, see Inbox.
#       
# Results:
#       may show message window.

proc ::GotMsg::GotMsg {id} {
    global  wDlgs
    
    variable w
    variable wbtnext
    variable msgIdDisplay
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "GotMsg::GotMsg id=$id"
    set w $wDlgs(jgotmsg)
    
    # Queue up this message or show right away?
    if {[winfo exists $w]} {
	$wbtnext configure -state normal
    } else {
	Show $id
    }
}

# GotMsg::Show --
#
#       Fills in all entries etc in message window.

proc ::GotMsg::Show {thisMsgId} {
    global  prefs
    
    variable w
    variable msgIdDisplay
    variable jid
    variable jidtxt
    variable username
    variable subject
    variable smartdate
    variable prestext
    variable wtext
    variable wbtnext
    variable wpresence
    variable body
    variable date
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::GotMsg::Show thisMsgId=$thisMsgId"
    
    # Build if not mapped.
    Build
    
    set msgIdDisplay $thisMsgId
    ::MailBox::MarkMsgAsRead $thisMsgId
    
    set subject [::MailBox::Get $thisMsgId subject]
    set jid     [::MailBox::Get $thisMsgId from]
    set date    [::MailBox::Get $thisMsgId date]
    set body    [::MailBox::Get $thisMsgId message]
    
    set jid [::Jabber::JlibCmd getrecipientjid $jid]
    set jidtxt $jid
    set smartdate [::Utils::SmartClockFormat [clock scan $date]]
    
    # Split jid into jid2 and resource.
    jlib::splitjid $jid jid2 res
    
    # Use nick name.
    set displayName [$jstate(roster) getname $jid2]
    if {[string length $displayName]} {
	set username "${username} <${jid}>"
    } else {
	set username $jid
    }
    if {[jlib::jidequal $jid $jstate(mejidres)]} {
	set show [::Jabber::GetMyStatus]
    } else {
	array set presArr [$jstate(roster) getpresence $jid2 -resource $res]
	set show $presArr(-type)
	if {[info exists presArr(-show)]} {
	    set show $presArr(-show)
	}
	set prestext [::Roster::MapShowToText $show]
    }
    set icon [::Roster::GetPresenceIconFromJid $jid]
    $wpresence configure -image $icon
    
    # Insert the actual body of the message.
    $wtext configure -state normal
    $wtext delete 1.0 end
    ::Text::Parse $wtext $body normal
    $wtext insert end \n
    $wtext configure -state disabled
    
    # If no more messages after this one...
    if {[::MailBox::IsLastMessage $msgIdDisplay]} {
	$wbtnext configure -state disabled
    }
    
    # Run display message hook (speech).
    set opts [list -subject $subject -from $jid -time $date]
    eval {::hooks::run displayMessageHook $body} $opts
}

# GotMsg::Build --
#
#       Builds the standard got message dialog.
#
# Arguments:
#       
# Results:
#       shows window.

proc ::GotMsg::Build { } {
    global  this prefs wDlgs

    variable w
    variable finished 
    variable msgStorage
    variable msgIdDisplay
    variable jid
    variable username
    variable jidtxt
    variable subject
    variable smartdate
    variable prestext
    variable wtext
    variable wbtnext
    variable wpresence
    variable locals
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::GotMsg::Build"

    set w $wDlgs(jgotmsg)
    if {[winfo exists $w]} {
	return
    }
    set finished 0
    
    # Toplevel with class GotMsg.
    ::UI::Toplevel $w -class GotMsg -usemacmainmenu 1 -macstyle documentProc
    wm title $w [mc {Incoming Message}]
    
    set bg [option get . backgroundGeneral {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 0   

    pack [frame $w.frall.pad -height 8] -side bottom

    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set wbtnext $frbot.btnext
    set bwidth [expr [::Utils::GetMaxMsgcatWidth Next Reply] + 2]
    pack [button $wbtnext -text [mc Next] -default active \
      -width $bwidth -state normal -command [list ::GotMsg::NextMsg]] \
      -side right -padx 5
    pack [button $frbot.btreply -text [mc Reply]   \
      -width $bwidth -command [list ::GotMsg::Reply]]  \
      -side right -padx 5
    pack $frbot -side bottom -fill x -padx 10 -pady 0
    pack [checkbutton $w.frall.ch -text " [mc jainmsgshow]" \
      -variable ::Jabber::jprefs(showMsgNewWin)] \
      -side bottom -anchor w -padx 8

    # From, subject, and time fields.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    pack $frmid -side top -fill x -padx 0 -pady 0
    
    # From field.
    set wfrom     $frmid.from
    set wpresence $wfrom.icon
    labelframe $wfrom -text [mc From]
    pack $wfrom -side top -fill both -padx 10 -pady 4
    entry $wfrom.username -width 10 \
      -textvariable [namespace current]::username -state disabled \
      -borderwidth 1 -relief sunken -background $bg
    pack  $wfrom.username -side left -fill x -expand 1
    label $wfrom.time -textvariable [namespace current]::smartdate
    pack  $wfrom.time -side left -padx 8 -pady 0
    label $wpresence -compound left -image "" \
      -textvariable [namespace current]::prestext
    pack  $wpresence -side right -padx 4 -pady 0
        
    # Subject field.
    pack [frame $frmid.fsub -border 0] -side top -fill x -expand 1 -padx 6
    pack [label $frmid.fsub.l -text "[mc Subject]:"  \
      -anchor e] -side left -padx 2 -pady 1
    pack [entry $frmid.fsub.e -width 10 \
      -borderwidth 1 -relief sunken -background $bg \
      -textvariable [namespace current]::subject -state disabled] \
      -side left -padx 4 -pady 1 -fill x -expand 1
    
    # Text.
    set wtxtfr $w.frall.frtxt
    pack [frame $wtxtfr] -side top -fill both -expand 1 -padx 4 -pady 4
    set wtext $wtxtfr.text
    set wysc $wtxtfr.ysc
    text $wtext -height 6 -width 48 -wrap word  \
      -borderwidth 1 -relief sunken -yscrollcommand [list $wysc set]
    $wtext tag configure normal
    scrollbar $wysc -orient vertical -command [list $wtext yview]
    grid $wtext -column 0 -row 0 -sticky news
    grid $wysc -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxtfr 0 -weight 1
    grid rowconfigure $wtxtfr 0 -weight 1
    
    ::UI::SetWindowGeometry $w

    wm minsize $w 240 220
    wm maxsize $w 600 600    

    set locals(updateDateid) [after $locals(updateDatems) \
      [namespace current]::UpdateDate]
    
    # Grab and focus.
    focus $w
}

proc ::GotMsg::UpdateDate { } {
    variable w
    variable locals
    variable date
    variable smartdate
    
    if {![winfo exists $w] || ![info exists date]} {
	return
    }
    set smartdate [::Utils::SmartClockFormat [clock scan $date]]
    
    # Reschedule ourselves.
    set locals(updateDateid) [after $locals(updateDatems) \
      [namespace current]::UpdateDate]
}

proc ::GotMsg::CloseHook {wclose} {
    global  wDlgs
    variable locals
    
    if {[string equal $wDlgs(jgotmsg) $wclose]} {
	::UI::SaveWinGeom $wclose
	if {$locals(updateDateid) != ""} {
	    after cancel $locals(updateDateid)
	}
    }   
}

proc ::GotMsg::PresenceHook {pjid2 type args} {
    global  wDlgs
    variable w
    variable wpresence
    variable prestext
    variable jid
    
    ::Debug 4 "::GotMsg::PresenceHook pjid2=$pjid2, type=$type"

    set w $wDlgs(jgotmsg)
    
    if {[winfo exists $w]} {
	array set argsArr $args
	set from $pjid2
	if {[info exists argsArr(-from)]} {
	    set from $argsArr(-from)
	}
	jlib::splitjid $jid jid2 res
	if {[jlib::jidequal $pjid2 $jid2]} {
	    set show $type
	    if {[info exists argsArr(-show)]} {
		set show $argsArr(-show)
	    }
	    set prestext [::Roster::MapShowToText $show]
	    set icon [::Roster::GetPresenceIconFromJid $from]
	    $wpresence configure -image $icon
	}
    }
}

proc ::GotMsg::NextMsg { } {
    
    variable msgIdDisplay
    
    # Query the mailbox for next message id.
    set nextid [::MailBox::GetNextMsgID $msgIdDisplay]
    Show $nextid  
}

proc ::GotMsg::Reply { } {
    variable jid
    variable subject
    variable date
    variable body
    
    if {![regexp -nocase {^ *re:} $subject]} {
	set resubject "Re: $subject"
    } else {
	set resubject $subject
    }
    ::NewMsg::Build -to $jid -subject $resubject  \
      -quotemessage $body -time $date
}

proc ::GotMsg::Close {w} {
    
    ::UI::SaveWinGeom $w  
    destroy $w
}

#-------------------------------------------------------------------------------
