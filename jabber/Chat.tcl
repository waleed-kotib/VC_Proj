#  Chat.tcl ---
#  
#      This file is part of the whiteboard application. 
#      It implements chat type of UI for jabber.
#      
#  Copyright (c) 2001-2002  Mats Bengtsson
#  
# $Id: Chat.tcl,v 1.1.1.1 2002-12-08 10:59:22 matben Exp $

package provide Chat 1.0

namespace eval ::Jabber::Chat:: {

    variable locals
}

# Jabber::Chat::GotMsg --
#
#       Just got a chat message. Fill in message in existing dialog.
#       If no dialog, make a freash one.
#       
# Arguments:
#       body        the text message.
#       args        ?-key value? pairs
#       
# Results:
#       updates UI.

proc ::Jabber::Chat::GotMsg {body args} {
    global  prefs

    variable locals
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::Chat::GotMsg args='$args'"

    array set argsArr $args
    
    # We must follow the thread...
    if {[info exists argsArr(-thread)]} {
	set threadID $argsArr(-thread)
    } else {
	error "Missing thread ID!!!"
    }

    if {[info exists locals($threadID,wtop)] &&  \
      [winfo exists $locals($threadID,wtop)]} {

    } else {

	# If we haven't a window for this thread, make one!
	eval {::Jabber::Chat::Build $threadID} $args
    }   
    if {[info exists argsArr(-subject)]} {
	set locals($threadID,subject) $argsArr(-subject)
    }
    set wtext $locals($threadID,wtext)
    $wtext configure -state normal
    if {![regexp {(.+)@([^/]+)(/(.+))?} $argsArr(-from) match username host junk res]} {
	set username $argsArr(-from)
    }
    $wtext insert end <$username> youtag
    $wtext insert end "   " youtxttag
    #$wtext insert end "$body\n" youtxttag
    set textCmds [::Text::ParseAllForTextWidget $body youtxttag linktag]
    foreach cmd $textCmds {
	eval $wtext $cmd
    }
    $wtext insert end "\n"
    $wtext configure -state disabled
    $wtext see end
    if {$locals($threadID,got1stMsg) == 0} {
	$locals($threadID,wtojid) configure -state disabled   \
	  -bg $prefs(bgColGeneral)
	set locals($threadID,got1stMsg) 1
    }
    
    if {$jprefs(speakChat)} {
	catch {speak -voice $prefs(voiceOther) $body}
    }
}

# Jabber::Chat::StartThread --
# 
# Arguments:
#       args        -to jid

proc ::Jabber::Chat::StartThread {args} {

    variable locals
    upvar ::Jabber::jstate jstate

    array set argsArr $args
    
    # Make unique thread id.
    set threadID [::sha1pure::sha1 "$jstate(mejid)[clock seconds]"]
    set locals($threadID,jid) $jstate(.,tojid)
    if {[info exists argsArr(-to)]} {
	set locals($threadID,jid) $argsArr(-to)
    }
    ::Jabber::Chat::Build $threadID    
}

# Jabber::Chat::Build --
#
#       Builds the chat dialog.
#
# Arguments:
#       threadID    unique thread id.
#       args        ?-to jid -subject subject -from fromJid?
#       
# Results:
#       shows window.

proc ::Jabber::Chat::Build {threadID args} {
    global  this sysFont prefs wDlgs
    
    variable locals
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::Chat::Build threadID=$threadID, args='$args'"

    set w "$wDlgs(jchat)[string range $threadID 0 8]"
    set locals($threadID,wtop) $w
    set locals($w,threadid) $threadID
    if {[winfo exists $w]} {
	return
    }
    array set argsArr $args
    toplevel $w -class Chat
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	#wm transient $w .
    }
    if {[info exists argsArr(-from)]} {
	set locals($threadID,jid) $argsArr(-from)
    }
    if {[info exists argsArr(-subject)]} {
	set locals($threadID,subject) $argsArr(-subject)
    }
    set locals($threadID,got1stMsg) 0
    wm title $w "Chat ($locals($threadID,jid))"
    wm protocol $w WM_DELETE_WINDOW   \
      [list ::Jabber::Chat::Close -threadid $threadID]
    wm group $w .
    
    # Toplevel menu for mac only. Crashes in menudefs; BowelsOfTheMemoryMgr
    # Only when multiinstance.
    if {0 && [string match "mac*" $this(platform)]} {
	set wmenu ${w}.menu
	menu $wmenu -tearoff 0
	::UI::MakeMenu $w ${wmenu}.apple {} $::UI::menuDefs(main,apple)
	::UI::MakeMenu $w ${wmenu}.file    {File }        $::UI::menuDefs(min,file)
	::UI::MakeMenu $w ${wmenu}.edit    {Edit }        $::UI::menuDefs(min,edit)	
	if {!$prefs(stripJabber)} {
	    ::UI::MakeMenu $w ${wmenu}.jabber   {Jabber } $::UI::menuDefs(main,jabber)
	}
	$w configure -menu ${wmenu}
    }

    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 4
        
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btconn -text [::msgcat::mc Send] -width 8 -default active \
      -command [list ::Jabber::Chat::Send $threadID]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Close] -width 8   \
      -command [list ::Jabber::Chat::Close -threadid $threadID]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side bottom -fill x -padx 10 -pady 8
    
    # CCP
    pack [frame $w.frall.fccp] -side top -fill x
    set wccp $w.frall.fccp.ccp
    pack [::UI::NewCutCopyPaste $wccp] -padx 10 -pady 2 -side left
    ::UI::CutCopyPasteConfigure $wccp cut -state disabled
    ::UI::CutCopyPasteConfigure $wccp copy -state disabled
    ::UI::CutCopyPasteConfigure $wccp paste -state disabled
    pack [frame $w.frall.fccp.div -bd 2 -relief raised -width 2] -fill y -side left
    pack [::UI::NewPrint $w.frall.fccp.pr [list ::Jabber::Chat::Print $threadID]] \
      -side left -padx 10
    pack [frame $w.frall.div2 -bd 2 -relief sunken -height 2] -fill x -side top
        
    # To and subject fields.
    set frtop [frame $w.frall.frtop -borderwidth 0]
    pack $frtop -side top -fill x   
    label $frtop.lto -text "[::msgcat::mc {To/from JID}]:" -font $sysFont(sb) \
      -anchor e
    entry $frtop.eto   \
      -textvariable [namespace current]::locals($threadID,jid)
    label $frtop.lsub -text "[::msgcat::mc Subject]:" -font $sysFont(sb) \
      -anchor e
    entry $frtop.esub   \
      -textvariable [namespace current]::locals($threadID,subject)
    grid $frtop.lto -column 0 -row 0 -sticky e -padx 6
    grid $frtop.eto -column 1 -row 0 -sticky ew -padx 6
    grid $frtop.lsub -column 0 -row 1 -sticky e -padx 6
    grid $frtop.esub -column 1 -row 1 -sticky ew -padx 6
    grid columnconfigure $frtop 1 -weight 1
    set locals($threadID,wtojid) $frtop.eto

    # Text chat.
    set frmid $w.frall.frmid
    pack [frame $frmid -height 250 -width 300 -relief sunken -bd 1]  \
      -side top -fill both -expand 1 -padx 4 -pady 4
    set wtxt $frmid.frtxt
    set locals($threadID,wtxt) $wtxt
    frame $wtxt
    set boldChatFont [lreplace $jprefs(chatFont) 2 2 bold]
    
    set wtext $wtxt.text
    set wysc $wtxt.ysc
    set locals($threadID,wtext) $wtext
    text $wtext -height 12 -width 1 -font $jprefs(chatFont) -state disabled -cursor {} \
      -borderwidth 1 -relief sunken -yscrollcommand [list $wysc set] -wrap word
    scrollbar $wysc -orient vertical -command [list $wtext yview]
    grid $wtext -column 0 -row 0 -sticky news
    grid $wysc -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxt 0 -weight 1
    grid rowconfigure $wtxt 0 -weight 1
    
    # The tags.
    set space 2
    $wtext tag configure metag -foreground red -background #cecece  \
      -spacing1 $space -font $boldChatFont
    $wtext tag configure metxttag -foreground black -background #cecece  \
      -spacing1 $space -spacing3 $space -lmargin1 20 -lmargin2 20
    $wtext tag configure youtag -foreground blue -spacing1 $space  \
       -font $boldChatFont
    $wtext tag configure youtxttag -foreground black -spacing1 $space  \
      -spacing3 $space -lmargin1 20 -lmargin2 20
    ::Text::ConfigureLinkTagForTextWidget $wtext linktag tact

    # Text send.
    set wtxtsnd $frmid.frtxtsnd    
    frame $wtxtsnd
    
    set wtextsnd $wtxtsnd.text
    set wyscsnd $wtxtsnd.ysc
    text $wtextsnd -height 4 -width 1 -font $jprefs(chatFont) -wrap word \
      -borderwidth 1 -relief sunken -yscrollcommand [list $wyscsnd set]
    scrollbar $wyscsnd -orient vertical -command [list $wtextsnd yview]
    grid $wtextsnd -column 0 -row 0 -sticky news
    grid $wyscsnd -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxtsnd 0 -weight 1
    grid rowconfigure $wtxtsnd 0 -weight 1
    
    if {[info exists prefs(paneGeom,$wDlgs(jchat))]} {
	set relpos $prefs(paneGeom,$wDlgs(jchat))
    } else {
	set relpos {0.75 0.25}
    }
    ::pane::pane $wtxt $wtxtsnd -orient vertical -limit 0.0 -relative $relpos
    
    set locals($threadID,wtext) $wtext
    set locals($threadID,wtextsnd) $wtextsnd

    # We need the window title to reflect the receiving jid.
    trace variable [namespace current]::locals($threadID,jid) w  \
      [list [namespace current]::TraceJid $threadID]

    if {[info exists prefs(winGeom,$wDlgs(jchat))]} {
	wm geometry $w $prefs(winGeom,$wDlgs(jchat))
    }
    wm minsize $w 220 320
    wm maxsize $w 800 2000
    
    focus $w
}

proc ::Jabber::Chat::SetFont {theFont} {
    
    variable locals

    foreach key [array names locals "*,wtext"] {
	set wtext $locals($key)
	if {[winfo exists $wtext]} {
	    set boldChatFont [lreplace $theFont 2 2 bold]
	    $wtext configure -font $theFont
	    $wtext tag configure metag -font $boldChatFont
	    $wtext tag configure youtag -font $boldChatFont
	}
    }
    foreach key [array names locals "*,wtextsnd"] {
	set wtextsnd $locals($key)
	if {[winfo exists $wtextsnd]} {
	    $wtextsnd configure -font $theFont
	}
    }
}

proc ::Jabber::Chat::Send {threadID} {
    global  prefs
    
    variable locals
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Chat::Send "
    
    # Check that still connected to server.
    if {![::Jabber::IsConnected]} {
	tk_messageBox -type ok -icon error -title [::msgcat::mc {Not Connected}] \
	  -message [::msgcat::mc jamessnotconnected]
	return
    }
    set jid $locals($threadID,jid)
    if {![::Jabber::IsWellFormedJID $jid]} {
	set ans [tk_messageBox -message [FormatTextForMessageBox  \
	  [::msgcat::mc jamessbadjid $jid]] \
	  -icon error -type yesno]
	if {[string equal $ans "no"]} {
	    return
	}
    }
    set wtext $locals($threadID,wtext)
    set wtextsnd $locals($threadID,wtextsnd)

    # Get text to send.
    set allText [$wtextsnd get 1.0 "end - 1 char"]
    if {[string length $allText]} {	
	$jstate(jlib) send_message $jid -subject $locals($threadID,subject) \
	  -thread $threadID -type chat -body $allText 
    }
    
    # Add to chat window and clear send.
    $wtext configure -state normal
    if {![regexp {(.+)@([^/]+)(/(.+))?} $jstate(mejid) match username host junk res]} {
	set username $jstate(mejid)
    }
    $wtext insert end <$username> metag
    set textCmds [::Text::ParseAllForTextWidget "   $allText" metxttag linktag]
    foreach cmd $textCmds {
	eval $wtext $cmd
    }
    $wtext insert end "\n"
    $wtext configure -state disabled
    $wtextsnd delete 1.0 end
    $wtext see end
    if {$locals($threadID,got1stMsg) == 0} {
	$locals($threadID,wtojid) configure -state disabled  \
	  -bg $prefs(bgColGeneral)
	set locals($threadID,got1stMsg) 1
    }
}

proc ::Jabber::Chat::TraceJid {threadID name junk1 junk2} {
    
    # Call by name.
    upvar $name locName
    variable locals
    
    set w $locals($threadID,wtop)
    wm title $w "Chat ($locals($threadID,jid))"
}

proc ::Jabber::Chat::Print {threadID} {

    variable locals

    set wtext $locals($threadID,wtext)
    
    ::UserActions::DoPrintText $wtext
}
    
# Jabber::Chat::Close --
#
#       args: must be any of -threadid or -toplevel

proc ::Jabber::Chat::Close {args} {
    global  wDlgs prefs
    
    variable locals
    
    array set argsArr $args
    if {[info exists argsArr(-threadid)]} {
	set threadID $argsArr(-threadid)
	set w $locals($threadID,wtop)
    } elseif {[info exists argsArr(-toplevel)]} {
	set w $argsArr(-toplevel)
	set threadID $locals($w,threadid)
    } else {
	return -code error  \
	  {::Jabber::Chat::Close must have any of -threadid or -toplevel}
    }

    set ans [tk_messageBox -icon info -parent $w -type yesno \
      -message [FormatTextForMessageBox [::msgcat::mc jamesschatclose]]]
    if {$ans == "yes"} {
	::UI::SaveWinGeom $wDlgs(jchat) $locals($threadID,wtop)
	::UI::SavePanePos $wDlgs(jchat) $locals($threadID,wtxt)
	array set infoArr [::pane::pane info $locals($threadID,wtxt)]
	set paneList  \
	  [list $infoArr(-relheight) [expr 1.0 - $infoArr(-relheight)]]
	set prefs(paneGeom,$wDlgs(jchat)) $paneList
	set locals(panePosList) [list $wDlgs(jchat) $paneList]
	destroy $locals($threadID,wtop)
	
	# Remove trace on windows title.
	trace vdelete [namespace current]::locals($threadID,jid) w  \
	  [namespace current]::TraceJid
	
	# Array cleanup?
    }
}

# Jabber::Chat::GetPanePos --
#
#       Return typical pane position as list.

proc ::Jabber::Chat::GetPanePos { } {
    global  wDlgs
    variable locals
    
    # Figure out if any chat windows on screen.
    set found 0
    foreach key [array names locals "*,wtxt"] {
	set wtxt $locals($key)
	if {[winfo exists $wtxt]} {
	    set found 1
	    break
	}
    }
    if {$found} {
	array set infoArr [::pane::pane info $wtxt]
	set ans [list $wDlgs(jchat)   \
	  [list $infoArr(-relheight) [expr 1.0 - $infoArr(-relheight)]]]
    } elseif {[info exists locals(panePosList)]} {
	set ans $locals(panePosList)
    } else {
	set ans {}
    }
    return $ans
}

#-------------------------------------------------------------------------------
