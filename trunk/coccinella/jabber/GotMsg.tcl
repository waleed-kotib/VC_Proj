#  GotMsg.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements a dialog for jabber messages.
#      
#  Copyright (c) 2002  Mats Bengtsson
#  
# $Id: GotMsg.tcl,v 1.25 2004-03-31 07:55:18 matben Exp $

package provide GotMsg 1.0

namespace eval ::Jabber::GotMsg:: {
    global  wDlgs

    # Add all event hooks.
    ::hooks::add quitAppHook        [list ::UI::SaveWinGeom $wDlgs(jgotmsg)]
    ::hooks::add displayMessageHook [list ::Speech::SpeakMessage normal]
    ::hooks::add closeWindowHook    ::Jabber::GotMsg::CloseHook
    
    
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
    
    ::Jabber::Debug 2 "Jabber::GotMsg::GotMsg id=$id"
    
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
    variable nick
    variable subject
    variable theTime
    variable isOnline
    variable wtext
    variable wbtnext
    variable wonline
    variable theMsg
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::GotMsg::Show thisMsgId=$thisMsgId"
    
    # Build if not mapped.
    ::Jabber::GotMsg::Build
    
    set msgIdDisplay $thisMsgId
    set spec [::Jabber::MailBox::GetMsgFromUid $thisMsgId]
    ::Jabber::MailBox::MarkMsgAsRead $thisMsgId
    if {$spec == ""} {
	return
    }
    foreach {subject jid timeAndDate isRead junk theMsg} $spec break
    set jid [::Jabber::InvokeJlibCmd getrecipientjid $jid]
    set jidtxt $jid
    set theTime [::Utils::SmartClockFormat [clock scan $timeAndDate]]
    
    # Split jid into jid2 and resource.
    jlib::splitjid $jid jid2 res
    
    # Use nick name.
    set nick [$jstate(roster) getname $jid2]
    if {[string length $nick]} {
	set jidtxt "${nick} <${jid}>"
    }
    if {[$jstate(roster) isavailable $jid2] || ($jid == $jstate(mejidres))} {
	set isOnline [::msgcat::mc Online]
	$wonline configure -fg blue
    } else {
	set isOnline [::msgcat::mc Offline]
	$wonline configure -fg red
    }
    
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
    variable nick
    variable jidtxt
    variable subject
    variable theTime
    variable isOnline
    variable wtext
    variable wbtnext
    variable wonline
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::GotMsg::Build w=$w"

    if {[winfo exists $w]} {
	return
    }
    set finished 0
    
    # Toplevel with class GotMsg.
    ::UI::Toplevel $w -class GotMsg -usemacmainmenu 1 -macstyle documentProc
    wm title $w [::msgcat::mc {Incoming Message}]
    
    set bg [option get . backgroundGeneral {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 0   
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set wbtnext $frbot.btnext
    set bwidth [expr [::Utils::GetMaxMsgcatWidth Next Reply] + 2]
    pack [button $wbtnext -text [::msgcat::mc Next] -default active \
      -width $bwidth -state normal -command [list ::Jabber::GotMsg::NextMsg]] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btreply -text [::msgcat::mc Reply]   \
      -width $bwidth -command [list ::Jabber::GotMsg::Reply]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side bottom -fill x -padx 10 -pady 8

    # From, subject, and time fields.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    pack $frmid -side top -fill x -padx 0 -pady 0
    
    # From field.
    set wfrom $frmid.from
    labelframe $wfrom -text [::msgcat::mc From]
    pack $wfrom -side top -fill both -padx 2 -pady 2
    pack [entry $wfrom.nick -width 14 \
      -textvariable [namespace current]::nick -state disabled \
      -borderwidth 1 -relief sunken -background $bg] \
      -side left 
    pack [entry $wfrom.jid   \
      -textvariable [namespace current]::jid -state disabled \
      -borderwidth 1 -relief sunken -background $bg] \
      -side left -fill x -expand 1
    
    # Time field.
    set ftm $frmid.ftm
    set wonline $ftm.eu
    pack [frame $ftm -border 0] -side top -fill x -expand 1 -pady 0
    pack [label $ftm.lt -text "[::msgcat::mc Time]:"] \
      -side left -padx 2 -pady 0
    pack [entry $ftm.et -width 16 \
      -textvariable [namespace current]::theTime -state disabled  \
      -borderwidth 1 -relief sunken -background $bg] \
      -side left -padx 1 -pady 0
    pack [frame $ftm.pad -relief raised -bd 1 -width 2]  \
      -padx 6 -fill y -side left
    pack [label $ftm.lu -text "[::msgcat::mc {User is}]:" \
      -anchor e -padx 0] -side left -padx 0 -pady 0    
    pack [entry $wonline -width 11 \
      -textvariable [namespace current]::isOnline -state disabled  \
      -borderwidth 1 -relief sunken -background $bg] \
      -side left -padx 4 -pady 0
    
    # Subject field.
    pack [frame $frmid.fsub -border 0] -side top -fill x -expand 1
    pack [label $frmid.fsub.l -text "[::msgcat::mc Subject]:"  \
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
