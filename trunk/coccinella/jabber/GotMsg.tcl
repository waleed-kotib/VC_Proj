#  GotMsg.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements a dialog for jabber messages.
#      
#  Copyright (c) 2002  Mats Bengtsson
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
# $Id: GotMsg.tcl,v 1.51 2007-07-19 06:28:12 matben Exp $

package provide GotMsg 1.0

namespace eval ::GotMsg:: {

    # Add all event hooks.
    ::hooks::register quitAppHook        ::GotMsg::QuitAppHook
    ::hooks::register presenceHook       ::GotMsg::PresenceHook    
    #::hooks::register newMessageHook     ::GotMsg::MessageHook
    
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

# @@@ Enable this when solved the uidmsg vs. uuid mixup.
proc ::GotMsg::MessageHook {bodytxt args} {
    upvar ::Jabber::jprefs jprefs

    if {$jprefs(showMsgNewWin) && ($bodytxt ne "")} {
	array set argsA $args
	GotMsg $argsA(-uuid)
    }
}

# GotMsg::GotMsg --
#
#       Called when we get an incoming message.
#       Calls 'GotMsg::Show' if not mapped.
#
# Arguments:
#       uid          the message uuid
#       
# Results:
#       may show message window.

proc ::GotMsg::GotMsg {uid} {
    global  wDlgs
    
    variable w
    variable wbtnext
    
    ::Debug 2 "GotMsg::GotMsg uid=$uid"
    
    set w $wDlgs(jgotmsg)
        
    # Queue up this message or show right away?
    if {[winfo exists $w]} {
	$wbtnext state {!disabled}
    } else {
	Show $uid
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
    lassign [::MailBox::GetContentList $thisMsgId] subject jid date body
    set jid [::Jabber::JlibCmd getrecipientjid $jid]
    set jidtxt $jid
    set smartdate [::Utils::SmartClockFormat [clock scan $date]]
    
    # Split jid into jid2 and resource.
    jlib::splitjid $jid jid2 res
    
    set jlib $jstate(jlib)
    
    # Use nick name.
    set rname [$jlib roster getname $jid2]
    set ujid [jlib::unescapejid $jid]
    if {[string length $rname]} {
	set username "$rname <$ujid>"
    } else {
	set username $ujid
    }
    if {[jlib::jidequal $jid $jstate(mejidres)]} {
	set show [::Jabber::GetMyStatus]
    } else {
	array set presArr [$jlib roster getpresence $jid2 -resource $res]
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
    $wtext mark set insert end
    ::Text::ParseMsg normal $jid $wtext $body normal
    $wtext insert end \n
    $wtext configure -state disabled
    
    # If no more messages after this one...
    if {[::MailBox::IsLastMessage $msgIdDisplay]} {
	$wbtnext state {disabled}
    }
    
    # Run display message hook (speech).
    set opts [list -subject $subject -from $jid -time $date -msgid $thisMsgId]
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
	raise $w
	return
    }
    set finished 0
    
    # Toplevel with class GotMsg.
    ::UI::Toplevel $w -class GotMsg \
      -usemacmainmenu 1 -macstyle documentProc -closecommand ::GotMsg::CloseHook
    wm title $w [mc {Incoming Message}]
    
    set bg [option get . backgroundGeneral {}]
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot
    set wbtnext $frbot.btnext
    ttk::button $wbtnext -text [mc Next] -default active \
      -width -8 -command [list ::GotMsg::NextMsg]
    ttk::button $frbot.btreply -text [mc Reply]   \
      -width -8 -command [list ::GotMsg::Reply]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $wbtnext -side right
	pack $frbot.btreply -side right -padx $padx
    } else {
	pack $frbot.btreply -side right
	pack $wbtnext -side right -padx $padx
    }
    pack $frbot -side bottom -fill x

    ttk::checkbutton $wbox.ch -style Small.TCheckbutton \
      -text [mc jainmsgshow] \
      -variable ::Jabber::jprefs(showMsgNewWin)
    pack  $wbox.ch  -side bottom -anchor w -pady 4
    
    # From, subject, and time fields.
    set frmid $wbox.frmid
    ttk::frame $frmid
    pack $frmid -side top -fill x
    
    # From field.
    set wfrom     $frmid.lfrom
    set wpresence $frmid.ifrom
    ttk::label $frmid.lfrom -text "[mc From]:"
    ttk::label $frmid.efrom \
      -textvariable [namespace current]::username
    ttk::label $frmid.time -style Small.TLabel \
      -textvariable [namespace current]::smartdate
    ttk::label $frmid.ifrom -style Small.TLabel \
      -compound left -compound left -image "" \
      -textvariable [namespace current]::prestext

    # Subject field.
    ttk::label $frmid.lsub -text "[mc Subject]:" -anchor e
    ttk::label $frmid.esub \
      -textvariable [namespace current]::subject
    
    grid  $frmid.lfrom  $frmid.efrom  $frmid.time   -sticky e -padx 2 -pady 2
    grid  $frmid.lsub   $frmid.esub   $frmid.ifrom  -sticky e -padx 2 -pady 2
    grid  $frmid.efrom  $frmid.esub   -sticky w
    grid  $frmid.time   $frmid.ifrom  -sticky w
    grid columnconfigure $frmid 1 -weight 1
        
    # Text.
    set wtxtfr $wbox.frtxt
    set wtext  $wtxtfr.text
    set wysc   $wtxtfr.ysc
    ttk::frame $wtxtfr -padding {0 4 0 0}
    pack  $wtxtfr -side top -fill both -expand 1
    text $wtext -highlightthickness 0 -height 6 -width 48 -wrap word  \
      -borderwidth 1 -relief sunken \
      -yscrollcommand [list ::UI::ScrollSet $wysc \
      [list grid $wysc -column 1 -row 0 -sticky ns]]
    $wtext tag configure normal
    ttk::scrollbar $wysc -orient vertical -command [list $wtext yview]
    bindtags $wtext [linsert [bindtags $wtext] 0 ReadOnlyText]

    grid  $wtext  -column 0 -row 0 -sticky news
    grid  $wysc   -column 1 -row 0 -sticky ns
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
    variable locals
    
    ::UI::SaveWinGeom $wclose
    if {$locals(updateDateid) != ""} {
	after cancel $locals(updateDateid)
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
