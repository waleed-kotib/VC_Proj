#  GotMsg.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements a dialog for jabber messages.
#      
#  Copyright (c) 2002  Mats Bengtsson
#  
# $Id: GotMsg.tcl,v 1.33 2004-10-16 13:32:50 matben Exp $

package provide GotMsg 1.0

namespace eval ::Jabber::GotMsg:: {
    global  wDlgs

    # Add all event hooks.
    ::hooks::register quitAppHook        [list ::UI::SaveWinGeom $wDlgs(jgotmsg)]
    ::hooks::register closeWindowHook    ::Jabber::GotMsg::CloseHook
    ::hooks::register presenceHook       ::Jabber::GotMsg::PresenceHook    
    
    # Wait for this variable to be set.
    variable finished  
    variable w $wDlgs(jgotmsg)
        
    # msgId for the one in the dialog.
    variable msgIdDisplay 0
}

# Jabber::GotMsg::GotMsg --
#
#       Called when we get an incoming message.
#       Calls 'Jabber::GotMsg::Show' if not mapped.
#
# Arguments:
#       id          the message id, see Inbox.
#       
# Results:
#       may show message window.

proc ::Jabber::GotMsg::GotMsg {id} {
    
    variable w
    variable wbtnext
    variable msgIdDisplay
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "Jabber::GotMsg::GotMsg id=$id"
    
    # Queue up this message or show right away?
    if {[winfo exists $w]} {
	$wbtnext configure -state normal
    } else {
	::Jabber::GotMsg::Show $id
    }
}

# Jabber::GotMsg::Show --
#
#       Fills in all entries etc in message window.

proc ::Jabber::GotMsg::Show {thisMsgId} {
    global  prefs
    
    variable w
    variable msgIdDisplay
    variable jid
    variable jidtxt
    variable username
    variable subject
    variable theTime
    variable prestext
    variable wtext
    variable wbtnext
    variable wpresence
    variable theMsg
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::mapShowTextToElem mapShowTextToElem
    
    ::Debug 2 "::Jabber::GotMsg::Show thisMsgId=$thisMsgId"
    
    # Build if not mapped.
    ::Jabber::GotMsg::Build
    
    set msgIdDisplay $thisMsgId
    set spec [::Jabber::MailBox::GetMsgFromUid $thisMsgId]
    ::Jabber::MailBox::MarkMsgAsRead $thisMsgId
    if {$spec == ""} {
	return
    }
    foreach {subject jid timeAndDate isRead junk theMsg} $spec break
    set jid [::Jabber::JlibCmd getrecipientjid $jid]
    set jidtxt $jid
    set theTime [::Utils::SmartClockFormat [clock scan $timeAndDate]]
    
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
	set prestext $mapShowTextToElem($show)
    }
    set icon [::Jabber::Roster::GetPresenceIconFromJid $jid]
    $wpresence configure -image $icon
    
    # Insert the actual body of the message.
    $wtext configure -state normal
    $wtext delete 1.0 end
    ::Jabber::ParseAndInsertText $wtext $theMsg normal urltag
    $wtext configure -state disabled
    
    # If no more messages after this one...
    if {[::Jabber::MailBox::IsLastMessage $msgIdDisplay]} {
	$wbtnext configure -state disabled
    }
    
    # Run display message hook (speech).
    set opts [list -subject $subject -from $jid -time $timeAndDate]
    eval {::hooks::run displayMessageHook $theMsg} $opts
}

# Jabber::GotMsg::Build --
#
#       Builds the standard got message dialog.
#
# Arguments:
#       
# Results:
#       shows window.

proc ::Jabber::GotMsg::Build { } {
    global  this prefs wDlgs

    variable w
    variable finished 
    variable msgStorage
    variable msgIdDisplay
    variable jid
    variable username
    variable jidtxt
    variable subject
    variable theTime
    variable prestext
    variable wtext
    variable wbtnext
    variable wpresence
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Jabber::GotMsg::Build w=$w"

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
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set wbtnext $frbot.btnext
    set bwidth [expr [::Utils::GetMaxMsgcatWidth Next Reply] + 2]
    pack [button $wbtnext -text [mc Next] -default active \
      -width $bwidth -state normal -command [list ::Jabber::GotMsg::NextMsg]] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btreply -text [mc Reply]   \
      -width $bwidth -command [list ::Jabber::GotMsg::Reply]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side bottom -fill x -padx 10 -pady 8

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
    label $wfrom.time -textvariable [namespace current]::theTime
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
    ::Text::ConfigureLinkTagForTextWidget $wtext urltag activeurltag
    scrollbar $wysc -orient vertical -command [list $wtext yview]
    grid $wtext -column 0 -row 0 -sticky news
    grid $wysc -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxtfr 0 -weight 1
    grid rowconfigure $wtxtfr 0 -weight 1
    
    ::UI::SetWindowGeometry $w

    wm minsize $w 240 220
    wm maxsize $w 600 600    
    
    # Grab and focus.
    focus $w
}


proc ::Jabber::GotMsg::CloseHook {wclose} {
    global  wDlgs
    
    if {[string equal $wDlgs(jgotmsg) $wclose]} {
	::UI::SaveWinGeom $wclose
    }   
}

proc ::Jabber::GotMsg::PresenceHook {pjid2 type args} {
    variable w
    variable wpresence
    variable prestext
    variable jid
    upvar ::Jabber::mapShowTextToElem mapShowTextToElem
    
    ::Debug 4 "::Jabber::GotMsg::PresenceHook pjid2=$pjid2, type=$type"

    if {[winfo exists $w]} {
	array set argsArr $args
	set from $pjid2
	if {[info exists argsArr(-from)]} {
	    set from $argsArr(-from)
	}
	jlib::splitjid $jid jid2 res
	puts "pjid2=$pjid2"
	if {[jlib::jidequal $pjid2 $jid2]} {
	    set show $type
	    if {[info exists argsArr(-show)]} {
		set show $argsArr(-show)
	    }
	    set prestext $mapShowTextToElem($show)
	    set icon [::Jabber::Roster::GetPresenceIconFromJid $from]
	    $wpresence configure -image $icon
	}
    }
}

proc ::Jabber::GotMsg::NextMsg { } {
    
    variable msgIdDisplay
    
    # Query the mailbox for next message id.
    set nextid [::Jabber::MailBox::GetNextMsgID $msgIdDisplay]
    ::Jabber::GotMsg::Show $nextid  
}

proc ::Jabber::GotMsg::Reply { } {
    variable jid
    variable subject
    variable theTime
    variable theMsg
    
    if {![regexp -nocase {^ *re:} $subject]} {
	set resubject "Re: $subject"
    } else {
	set resubject $subject
    }
    ::Jabber::NewMsg::Build -to $jid -subject $resubject  \
      -quotemessage $theMsg -time $theTime
}

proc ::Jabber::GotMsg::Close {w} {
    
    ::UI::SaveWinGeom $w  
    destroy $w
}

#-------------------------------------------------------------------------------
