#  MailBox.tcl ---
#  
#      This file is part of the whiteboard application. 
#      It implements a mailbox for jabber messages.
#      
#  Copyright (c) 2002-2003  Mats Bengtsson
#  
# $Id: MailBox.tcl,v 1.5 2003-02-24 17:52:05 matben Exp $

package provide MailBox 1.0

namespace eval ::Jabber::MailBox:: {

    variable locals
    upvar ::Jabber::jstate jstate
    
    set locals(inited) 0
    set jstate(inboxVis) 0
    
    # Running id for incoming messages; never reused.
    set locals(msgId) 1000

    # The actual mailbox content.
    # Content: {subject from date isread msgid message ?canvasid?}
    variable mailbox
    
    # Keep a level of abstraction between column index and name.
    variable colindex
    array set colindex {
	iswb      0
	subject   1
	from      2
	date      3
	isread    4
	msgid     5
    }
}

proc ::Jabber::MailBox::Init { } {
    
    variable locals
    variable mailbox
    upvar ::Jabber::jstate jstate
    
    set locals(inited) 1
    
    if {$jstate(debug) > 1} {
	set mailbox([incr locals(msgId)])  \
	  [list "Nasty" olle@athlon.se/ff "yesterday 19:10:01" 0 $locals(msgId) "Tja,\n\nwww.mats.se, Nytt?"]
	set mailbox([incr locals(msgId)])  \
	  [list "Re: Shit" kk@athlon.se/hh "today 08:33:02" 0 $locals(msgId) "Hej,\n\nKass?\nlink www.apple.com\nshit www.mats.se/home"]
	set mailbox([incr locals(msgId)])  \
	  [list "Re: Shit" kk@athlon.se/zzz "today 08:43:02" 0 $locals(msgId) "Hej,\n\nAny :cool: stuff? I'm :bored: and :cheeky:."]
	set mailbox([incr locals(msgId)])  \
	  [list "Re: special braces" brace@athlon.se/co "today 08:43:02" 0 $locals(msgId) "Testing unmatched braces:  if \{1\} \{"]
	set mailbox([incr locals(msgId)])  \
	  [list "Re: special amp" brace@athlon.se/co "today 08:43:02" 0 $locals(msgId) "Testing ampersand:  amp &"]
	set mailbox([incr locals(msgId)])  \
	  [list "Re: special brackets" bracket@athlon.se/co "today 08:43:02" 0 $locals(msgId) "Testing brackets  \[\["]
	set mailbox([incr locals(msgId)])  \
	  [list "Re: special quotes" quote@athlon.se/co "today 08:43:02" 0 $locals(msgId) "Testing \"quotes\" "]
    }
}

proc ::Jabber::MailBox::Show {w args} {

    upvar ::Jabber::jstate jstate

    array set argsArr $args
    if {[info exists argsArr(-visible)]} {
	set jstate(inboxVis) $argsArr(-visible)
    }
    if {$jstate(inboxVis)} {
	if {[winfo exists $w]} {
	    catch {wm deiconify $w}
	} else {
	    ::Jabber::MailBox::Build $w
	}
    } else {
	catch {wm withdraw $w}
    }
}

proc ::Jabber::MailBox::Build {w args} {
    global  this sysFont prefs wDlgs
    
    variable locals  
    variable colindex
    variable mailbox
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    upvar ::UI::icons icons
    
    ::Jabber::Debug 2 "::Jabber::MailBox::Build args='$args'"

    if {!$locals(inited)} {
	::Jabber::MailBox::Init
	if {$jprefs(inboxSave)} {
	    ::Jabber::MailBox::ReadMailbox
	}
    }
    if {[winfo exists $w]} {
	return
    }
    toplevel $w -class MailBox
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	wm transient $w .
    }
    wm title $w [::msgcat::mc Inbox]
    wm protocol $w WM_DELETE_WINDOW [list [namespace current]::CloseDlg $w]
    
    # Toplevel menu for mac only. Only when multiinstance.
    if {0 && [string match "mac*" $this(platform)]} {
	set wmenu ${w}.menu
	menu $wmenu -tearoff 0
	::UI::MakeMenu $w ${wmenu}.apple   {}       $::UI::menuDefs(main,apple)
	::UI::MakeMenu $w ${wmenu}.file    mFile    $::UI::menuDefs(min,file)
	::UI::MakeMenu $w ${wmenu}.edit    mEdit    $::UI::menuDefs(min,edit)	
	::UI::MakeMenu $w ${wmenu}.jabber  mJabber  $::UI::menuDefs(main,jabber)
	$w configure -menu ${wmenu}
    }
    set locals(wtop) $w
    set jstate(inboxVis) 1
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 4
    
    # Button part.
    set frtop [frame $w.frall.frtop -borderwidth 0]
    pack $frtop -side top -fill x -padx 4 -pady 2
    ::UI::InitShortcutButtonPad $w $frtop 50
    ::UI::NewButton $w new $icons(btnew) $icons(btnewdis)  \
      [list ::Jabber::NewMsg::Build $wDlgs(jsendmsg)]
    ::UI::NewButton $w reply $icons(btreply) $icons(btreplydis)  \
      [list ::Jabber::MailBox::ReplyTo] -state disabled
    ::UI::NewButton $w forward $icons(btforward) $icons(btforwarddis)  \
      [list ::Jabber::MailBox::ForwardTo] -state disabled
    ::UI::NewButton $w save $icons(btsave) $icons(btsavedis)  \
      [list ::Jabber::MailBox::SaveMsg] -state disabled
    ::UI::NewButton $w print $icons(btprint) $icons(btprintdis)  \
      [list ::Jabber::MailBox::DoPrint] -state disabled
    ::UI::NewButton $w trash $icons(bttrash) $icons(bttrashdis)  \
      ::Jabber::MailBox::TrashMsg -state disabled
    
    pack [frame $w.frall.divt -bd 2 -relief sunken -height 2] -fill x -side top
    set wccp $w.frall.ccp
    pack [::UI::NewCutCopyPaste $wccp] -padx 10 -pady 2 -side top -anchor w
    ::UI::CutCopyPasteConfigure $wccp cut -state disabled
    ::UI::CutCopyPasteConfigure $wccp copy -state disabled
    ::UI::CutCopyPasteConfigure $wccp paste -state disabled
    pack [frame $w.frall.div2 -bd 2 -relief sunken -height 2] -fill x -side top
    
    # Frame to serve as container for the pane geometry manager.
    set frmid $w.frall.frmid
    pack [frame $frmid -height 250 -width 380 -relief sunken -bd 1]  \
      -side top -fill both -expand 1 -padx 4 -pady 4
    
    # The actual mailbox list as a tablelist.
    set wfrmbox $frmid.frmbox
    set locals(wfrmbox) $wfrmbox
    frame $wfrmbox
    set wtbl $wfrmbox.tbl
    set wysctbl $wfrmbox.ysc
    set columns [list 0 {} 0 [::msgcat::mc Subject] 0 [::msgcat::mc From] \
      0 [::msgcat::mc Date] 0 {} 0 {}]
    scrollbar $wysctbl -orient vertical -command [list $wtbl yview]
    tablelist::tablelist $wtbl -columns $columns  \
      -font $sysFont(sb) -labelfont $sysFont(s) -background white  \
      -yscrollcommand [list $wysctbl set]  \
      -labelbackground #cecece -stripebackground #dedeff  \
      -labelcommand "[namespace current]::LabelCommand"  \
      -stretch all -width 60 -selectmode extended
    # Pressed -labelbackground #8c8c8c
    $wtbl columnconfigure $colindex(iswb) -labelimage $icons(wbicon)  \
      -resizable 0 -align center -showarrow 0
    $wtbl columnconfigure $colindex(date) -sortmode command  \
      -sortcommand "[namespace current]::SortTimeColumn"
    $wtbl columnconfigure $colindex(isread) -hide 1
    $wtbl columnconfigure $colindex(msgid) -hide 1
    grid $wtbl -column 0 -row 0 -sticky news
    grid $wysctbl -column 1 -row 0 -sticky ns
    grid columnconfigure $wfrmbox 0 -weight 1
    grid rowconfigure $wfrmbox 0 -weight 1
    
    set i 0
    foreach id [lsort -integer [array names mailbox]] {
	::Jabber::MailBox::InsertRow $wtbl $mailbox($id) $i
	incr i
    }
    
    # Display message in a text widget.
    set wfrmsg $frmid.frmsg    
    frame $wfrmsg
    set wtextmsg $wfrmsg.text
    set wyscmsg $wfrmsg.ysc
    text $wtextmsg -height 4 -width 1 -font $sysFont(s) -wrap word  \
      -borderwidth 1 -relief sunken -yscrollcommand [list $wyscmsg set]  \
      -state normal
    $wtextmsg tag configure normal -foreground black
    ::Text::ConfigureLinkTagForTextWidget $wtextmsg linktag tact
    scrollbar $wyscmsg -orient vertical -command [list $wtextmsg yview]
    grid $wtextmsg -column 0 -row 0 -sticky news
    grid $wyscmsg -column 1 -row 0 -sticky ns
    grid columnconfigure $wfrmsg 0 -weight 1
    grid rowconfigure $wfrmsg 0 -weight 1
    
    if {[info exists prefs(paneGeom,$w)]} {
	set relpos $prefs(paneGeom,$w)
    } else {
	set relpos {0.5 0.5}
    }
    ::pane::pane $wfrmbox $wfrmsg -orient vertical -limit 0.0 -relative $relpos
    
    if {[string match "mac*" $this(platform)]} {
	pack [frame $w.frall.pad -height 14] -side bottom
    }
    set locals(wtbl) $wtbl
    set locals(wtextmsg) $wtextmsg
    set locals(wccp) $wccp
        
    if {[info exists prefs(winGeom,$w)]} {
	wm geometry $w $prefs(winGeom,$w)
    }
    wm minsize $w 300 260
    wm maxsize $w 1200 1000
    
    # Grab and focus.
    focus $w
    
    # Make selection available in text widget but not editable!
    # Seems to stop the tablelist from getting focus???
    #$wtextmsg bind <Key> {break}

    # Special bindings for the tablelist.
    set body [$wtbl bodypath]
    bind $body <Button-1> {+ focus %W}
    bind $body <Double-1> [list [namespace current]::DoubleClickMsg]
    bind $wtbl <<ListboxSelect>> [list [namespace current]::SelectMsg]
    
    ::Jabber::MailBox::LabelCommand $wtbl $colindex(date)
}

# Jabber::MailBox::InsertRow --
#
#

proc ::Jabber::MailBox::InsertRow {wtbl row i} {
    global  sysFont
    
    variable colindex
    upvar ::UI::icons icons

    set jid [lindex $row 1]
    if {![regexp {^(.+@[^/]+)(/(.+))?} $jid match jidNoRes x res]} {
	set jidNoRes $jid
    }
    set row [lreplace $row 1 1 $jidNoRes]
    set haswb 0
    if {([llength $row] > 6) && ([string length [lindex $row 6]] > 0)} {
	set haswb 1
    }
    set row "{} $row"
    $wtbl insert end [lrange $row 0 5]
    if {$haswb} {
	$wtbl cellconfigure "${i},$colindex(iswb)" -image $icons(wboard)
    }
    set colsub $colindex(subject)
    if {[lindex $row $colindex(isread)] == 0} {
	$wtbl rowconfigure $i -font $sysFont(sb)
	$wtbl cellconfigure "${i},${colsub}" -image $icons(unreadMsg)
    } else {
	$wtbl rowconfigure $i -font $sysFont(s)
	$wtbl cellconfigure "${i},${colsub}" -image $icons(readMsg)
    }
}

proc ::Jabber::MailBox::GetToplevel { } {
    
    variable locals
    if {[info exists locals(wtop)] && [winfo exists $locals(wtop)]} {
	return $locals(wtop)
    } else {
	return {}
    }
}

proc ::Jabber::MailBox::GetCCP { } {
    
    variable locals
    if {[info exists locals(wccp)]} {
	return $locals(wccp)
    } else {
	return {}
    }
}

proc ::Jabber::MailBox::IsLastMessage {id} {
    variable mailbox

    set sorted [lsort -integer [array names mailbox]]
    return [expr ($id >= [lindex $sorted end]) ? 1 : 0]
}

proc ::Jabber::MailBox::GetNextMsgID {id} {
    variable mailbox

    set nextid $id
    set sorted [lsort -integer [array names mailbox]]
    set ind [lsearch $sorted $id]
    if {($ind >= 0) && ([expr $ind + 1] < [llength $sorted])} {
	set next [lindex $sorted [incr ind]]
    }
    return $next
}

proc ::Jabber::MailBox::GetMsgFromId {id} {
    variable mailbox
    
    if {[info exists mailbox($id)]} {
	return $mailbox($id)
    } else {
	return {}
    }
}

# Jabber::MailBox::GetCanvasHexUID --
#
#       Rteurns the unique hex id for canvas if message has any, else empty.

proc ::Jabber::MailBox::GetCanvasHexUID {id} {
    variable mailbox

    set ans ""
    set row $mailbox($id)
    if {[llength $row] > 6} {
	set ans [lindex $row 6]
    }
    return $ans
}

proc ::Jabber::MailBox::MarkMsgAsRead {id} {
    
    variable mailbox

    # Incomplete.
    #$wtbl rowconfigure $item -font $sysFont(s)
    #$wtbl cellconfigure "$item,0" -image $icons(readMsg)
    set mailbox($id) [lreplace $mailbox($id) 3 3 1]
}

# Jabber::MailBox::GotMsg --
#
#       Called when we get an incoming message. Stores the message.
#
# Arguments:
#       bodytxt     the body chdata
#       args        the xml attributes and elements as a '-key value' list
#       
# Results:
#       updates UI.

proc ::Jabber::MailBox::GotMsg {bodytxt args} {
    global  sysFont prefs

    variable locals
    variable mailbox
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    upvar ::UI::icons icons
    
    ::Jabber::Debug 2 "::Jabber::MailBox::GotMsg args='$args'"

    array set opts {
	-from unknown -subject {}
    }
    array set opts $args
    regexp {^(.+@[^/]+)(/(.+))?} $opts(-from) match jid2 x res
        
    # Here we should probably check som 'jabber:x:delay' element...
    set timeDate ""
    if {[info exists opts(-x)]} {
	set timeDate [::Jabber::FormatAnyDelayElem $opts(-x)]
    }
    if {$timeDate == ""} {
	set timeDate [SmartClockFormat [clock seconds]]
    }
    
    # If any whiteboard elements in this message (binary entities?).
    # Generate unique hex id which is stored in mailbox and used in file name.
    if {[info exists opts(-whiteboard)]} {
	set uid [::Utils::GenerateHexUID]
	set fileName ${uid}.can
	set filePath [file join $prefs(inboxCanvasPath) $fileName]
	::CanvasFile::DataToFile $filePath $opts(-whiteboard)
    } else {
	set uid ""
    }
    
    # Collect this message.
    incr locals(msgId)
    set mailbox($locals(msgId)) [list $opts(-subject) $opts(-from)  \
      $timeDate 0 $locals(msgId) $bodytxt $uid]
    
    # Alert sound?
    ::Sounds::Play newmsg

    set readQ 0
    if {$jprefs(showMsgNewWin) && ([string length $bodytxt] > 0)} {
	::Jabber::GotMsg::GotMsg $locals(msgId)
	::Jabber::MailBox::MarkMsgAsRead $locals(msgId)
	set readQ 1
    }

    # Show in mailbox. Sorting?
    set w [::Jabber::MailBox::GetToplevel]
    if {$w != ""} {
	::Jabber::MailBox::InsertRow $locals(wtbl) $mailbox($locals(msgId)) end
	$locals(wtbl) see end
    }
}

proc ::Jabber::MailBox::SaveMsg { } {
    global  this
    
    variable colindex
    variable locals
    
    set wtextmsg $locals(wtextmsg)
    set wtbl $locals(wtbl)
    
    # Need selected line here.
    set item [$wtbl curselection]
    if {[string length $item] == 0} {
	return
    }
    set ans [tk_getSaveFile -title {Save message} -initialfile Untitled.txt]
    if {[string length $ans] > 0} {
	set row [$wtbl get $item]
	set from [lindex $row $colindex(from)]
	set subject [lindex $row $colindex(subject)]
	set time [lindex $row $colindex(date)]
	if {[catch {open $ans w} fd]} {
	    tk_messageBox -title {Open Failed} -parent $wtbl -type ok \
	      -message "Failed opening file [file tail $ans]: $fd"
	    return
	}
	puts $fd "From: $from"
	puts $fd "Subject: $subject"
	puts $fd "Time: $time"
	puts $fd "\n"
	puts $fd [::Text::TransformToPureText $wtextmsg]
	close $fd
	if {[string match "mac*" $this(platform)]} {
	    file attributes $ans -type TEXT -creator ttxt
	}
    }
}

proc ::Jabber::MailBox::TrashMsg { } {
    global  prefs
    
    variable locals
    variable mailbox
    variable colindex
    
    # Need selected line here.
    set wtbl $locals(wtbl)
    set items [$wtbl curselection]
    set wtop $locals(wtop)
    set lastitem [lindex $items end]
    if {[llength $items] == 0} {
	return
    }
    set last [expr [$wtbl size] - 1]
    
    # Careful, delete in reversed order!
    foreach item [lsort -integer -decreasing $items] {
	set id [lindex [$wtbl get $item] $colindex(msgid)]
	set uid [::Jabber::MailBox::GetCanvasHexUID $id]
	if {[string length $uid] > 0} {
	    set fileName ${uid}.can
	    set filePath [file join $prefs(inboxCanvasPath) $fileName]
	    catch {file delete $filePath}
	}
	unset mailbox($id)
	$wtbl delete $item
    }
    
    # Make new selection if not empty.
    if {[$wtbl size] > 0} {
	if {$lastitem == $last} {
	    set sel [expr [$wtbl size] - 1]
	} else {
	    set sel [expr $lastitem + 1 - [llength $items]]
	}
	$wtbl selection set $sel
	::Jabber::MailBox::SelectMsg 
    } else {
	::UI::ButtonConfigure $wtop reply -state disabled
	::UI::ButtonConfigure $wtop forward -state disabled
	::UI::ButtonConfigure $wtop save -state disabled
	::UI::ButtonConfigure $wtop print -state disabled
	::UI::ButtonConfigure $wtop trash -state disabled
	::Jabber::MailBox::MsgDisplayClear
    }
}

proc ::Jabber::MailBox::SelectMsg { } {
    global  sysFont prefs

    variable locals
    variable mailbox
    variable colindex
    upvar ::Jabber::jstate jstate
    upvar ::UI::icons icons
    
    set wtextmsg $locals(wtextmsg)
    set wtbl $locals(wtbl)
    set wtop $locals(wtop)
    set item [$wtbl curselection]
    if {[llength $item] == 0} {
	return
    } elseif {[llength $item] > 1} {
	
	# If multiple selected items.
	::UI::ButtonConfigure $wtop reply -state disabled
	::UI::ButtonConfigure $wtop forward -state disabled
	::UI::ButtonConfigure $wtop save -state disabled
	::UI::ButtonConfigure $wtop print -state disabled
	::Jabber::MailBox::MsgDisplayClear
	return
    }
    set row [$wtbl get $item]
    set id [lindex $row $colindex(msgid)]
    
    # 2-tier jid.
    set jid2 [lindex $row $colindex(from)]
        
    # 3-tier jid.
    set jid3 [lindex $mailbox($id) 1]

    # Mark as read.
    set colsub $colindex(subject)
    $wtbl rowconfigure $item -font $sysFont(s)
    $wtbl cellconfigure "${item},${colsub}" -image $icons(readMsg)
    ::Jabber::MailBox::MarkMsgAsRead $id
    ::Jabber::MailBox::DisplayMsg $id
    
    # Configure buttons.
    ::UI::ButtonConfigure $wtop reply -state normal
    ::UI::ButtonConfigure $wtop forward -state normal
    ::UI::ButtonConfigure $wtop save -state normal
    ::UI::ButtonConfigure $wtop print -state normal
    ::UI::ButtonConfigure $wtop trash -state normal
    
    # If any whiteboard stuff in message...
    set uid [::Jabber::MailBox::GetCanvasHexUID $id]
    if {[string length $uid] > 0} {
	set wbtoplevel .maininbox
	set title "Inbox: $jid2"
	if {[winfo exists $wbtoplevel]} {
	    ::ImageAndMovie::HttpResetAll ${wbtoplevel}.
	    ::UserActions::EraseAll ${wbtoplevel}.
	    ::UI::ConfigureMain ${wbtoplevel}. -title $title -jid $jid2
	    undo::reset [::UI::GetUndoToken ${wbtoplevel}.]
	} else {
	    ::UI::BuildMain ${wbtoplevel}. -state disabled -title $title \
	    -jid $jid2 -type normal
	}
	
	# Only if user available shall we try to import.
	set tryimport 0
	if {[$jstate(roster) isavailable $jid3] || \
	  ($jid3 == $jstate(mejidres))} {
	    set tryimport 1
	}
		
	set fileName ${uid}.can
	set filePath [file join $prefs(inboxCanvasPath) $fileName]
	set numImports [::CanvasFile::DrawCanvasItemFromFile ${wbtoplevel}. \
	  $filePath -where local -tryimport $tryimport]
	if {!$tryimport && $numImports > 0} {
	    
	    # Perhaps we shall inform the user that no binary entities
	    # could be obtained.
	    tk_messageBox -type ok -title {Missing Entities}  \
	      -icon info -message \
	      [FormatTextForMessageBox "There were $numImports images or\
	      similar entities that could not be obtained because the user\
	      is not online."]
	}
    }
}

proc ::Jabber::MailBox::DoubleClickMsg { } {
    global  wDlgs
    
    variable locals
    variable mailbox
    variable colindex
    upvar ::Jabber::jprefs jprefs
    
    set wtbl $locals(wtbl)
    set item [$wtbl curselection]
    if {[string length $item] == 0} {
	return
    }
    set row [$wtbl get $item]
    set id [lindex $row $colindex(msgid)]

    # We shall have the original, unparsed, text here.
    set allText [lindex $mailbox($id) 5]
    foreach {subject to time} [lrange $mailbox($id) 0 2] { break }

    if {[string equal $jprefs(inbox2click) "newwin"]} {
	::Jabber::GotMsg::GotMsg $id
    } elseif {[string equal $jprefs(inbox2click) "reply"]} {
	if {![regexp -nocase {^ *re:} $subject]} {
	    set subject "Re: $subject"
	}	
	::Jabber::NewMsg::Build $wDlgs(jsendmsg) -to $to -subject $subject  \
	  -quotemessage $allText -time $time
    }
}

proc ::Jabber::MailBox::LabelCommand {w column} {

    variable locals    
    tablelist::sortByColumn $w $column
}

proc ::Jabber::MailBox::SortTimeColumn {elem1 elem2} {

    variable locals
    
    # 'clock scan' shall take care of formats like 'today' etc.
    set long1 [clock scan $elem1]
    set long2 [clock scan $elem2]
    if {$long1 > $long2} {
	return 1
    } elseif {$long1 == $long2} {
	return 0
    } else {
	return -1
    }
}

proc ::Jabber::MailBox::MsgDisplayClear { } {
    
    variable locals
    set wtextmsg $locals(wtextmsg)    
    $wtextmsg delete 1.0 end
}

proc ::Jabber::MailBox::DisplayMsg {id} {
    global  prefs

    variable locals
    variable mailbox
    upvar ::Jabber::jprefs jprefs
    
    set wtextmsg $locals(wtextmsg)    
    #$wtextmsg configure -state normal
    $wtextmsg delete 1.0 end
    set body [lindex $mailbox($id) 5]
    set textCmds [::Text::ParseAllForTextWidget $body normal linktag]
    foreach cmd $textCmds {
	eval $wtextmsg $cmd
    }
    #$wtextmsg configure -state disabled
    
    if {$jprefs(speakMsg)} {
	::UserActions::Speak $body $prefs(voiceOther)
    }
}

proc ::Jabber::MailBox::ReplyTo { } {
    global  wDlgs

    variable locals
    variable mailbox
    variable colindex
    
    set wtbl $locals(wtbl)
    set item [$wtbl curselection]
    if {[string length $item] == 0} {
	return
    }
    set row [$wtbl get $item]
    set id [lindex $row $colindex(msgid)]

    # We shall have the original, unparsed, text here.
    set allText [lindex $mailbox($id) 5]
    foreach {subject to time} [lrange $mailbox($id) 0 2] { break }
    if {![regexp -nocase {^ *re:} $subject]} {
	set subject "Re: $subject"
    }
    ::Jabber::NewMsg::Build $wDlgs(jsendmsg) -to $to -subject $subject  \
      -quotemessage $allText -time $time
}

proc ::Jabber::MailBox::ForwardTo { } {
    global  wDlgs

    variable locals
    variable mailbox
    variable colindex
    
    set wtbl $locals(wtbl)
    set item [$wtbl curselection]
    if {[string length $item] == 0} {
	return
    }
    set row [$wtbl get $item]
    set id [lindex $row $colindex(msgid)]

    # We shall have the original, unparsed, text here.
    set allText [lindex $mailbox($id) 5]
    foreach {subject to time} [lrange $mailbox($id) 0 2] { break }
    set subject "Forwarded: $subject"
    ::Jabber::NewMsg::Build $wDlgs(jsendmsg) -subject $subject  \
      -forwardmessage $allText -time $time
}

proc ::Jabber::MailBox::DoPrint { } {
    global  sysFont

    variable locals

    set allText [::Text::TransformToPureText $locals(wtextmsg)]
    
    ::UserActions::DoPrintText $locals(wtextmsg)  \
      -data $allText -font $sysFont(s)
}

proc ::Jabber::MailBox::SaveMailbox { } {
    global  this
    
    variable locals
    variable mailbox
    upvar ::Jabber::jprefs jprefs
    
    # Work on a temporary file and switch later.
    set tmpFile $jprefs(inboxPath).tmp
    if {[catch {open $tmpFile w} fid]} {
	tk_messageBox -type ok -icon error -message  \
	  [FormatTextForMessageBox [::msgcat::mc jamesserrinboxopen $tmpFile]]
	return
    }
    
    # Header information.
    puts $fid "#\n#   User's Jabber Message Box for the Whiteboard application."
    puts $fid "#   The data written at: [clock format [clock seconds]]\n#"
    
    # Save as list.
    set locals(mailbox) {}
    foreach id [lsort -integer [array names mailbox]] {
	set row $mailbox($id)
	lappend locals(mailbox) $row
    }
    puts $fid "set locals(mailbox) {"
    foreach msg $locals(mailbox) {
	puts $fid "\t{$msg}"
    }
    puts $fid "}"
    close $fid
    if {[catch {file rename -force $tmpFile $jprefs(inboxPath)} msg]} {
	tk_messageBox -type ok -message {Error renaming preferences file.}  \
	  -icon error
	return
    }
    if {[string match "mac*" $this(platform)]} {
	file attributes $jprefs(inboxPath) -type pref
    }
}

proc ::Jabber::MailBox::ReadMailbox { } {

    variable locals
    variable mailbox
    upvar ::Jabber::jprefs jprefs

    if {![file exist $jprefs(inboxPath)]} {
	
	# Think we should keep quiet about this.
	return
	
	set ans [tk_messageBox -title [::msgcat::mc {No Inbox}] -icon error  \
	  -type yesno -message [FormatTextForMessageBox \
	  "Couldn't find the mailbox file \"[file tail $jprefs(inboxPath)]\".\
	  Do you want to locate it?"]]
	if {$ans == "no"} {
	    return
	} else {
	    set new [tk_getOpenFile -title {Pick Mailbox File}  \
	      -filetypes {{{Tcl File} {.tcl}}}]
	    if {[string length $new] == 0} {
		return
	    }
	    set jprefs(inboxPath) $new
	}
    }
    if {[catch {source $jprefs(inboxPath)} msg]} {
	set tail [file tail $jprefs(inboxPath)]
	tk_messageBox -title [::msgcat::mc {Mailbox Error}] -icon error  \
	  -type ok -message [FormatTextForMessageBox \
	  [::msgcat::mcset en jamesserrinboxread $tail $msg]]
    } else {
	
	# The mailbox on file is just a hierarchical list that needs to be
	# translated to an array. Be sure to update the msgId's!
	set msgId $locals(msgId)
	foreach row $locals(mailbox) {
	    set id [incr msgId]
	    set mailbox($id) [lreplace $row 4 4 $id]
	}
	set locals(msgId) $msgId
    }
}

proc ::Jabber::MailBox::CloseDlg {w} {
    global  prefs

    variable locals
    upvar ::Jabber::jstate jstate

    set jstate(inboxVis) 0
    ::UI::SaveWinGeom $w
    array set infoArr [::pane::pane info $locals(wfrmbox)]
    set paneGeomList  \
      [list $infoArr(-relheight) [expr 1.0 - $infoArr(-relheight)]]
    set prefs(paneGeom,$w) $paneGeomList
    set locals(panePosList) [list $locals(wtop) $paneGeomList]
    catch {destroy $w}
}

proc ::Jabber::MailBox::GetPanePos { } {

    variable locals
    
    if {[info exists locals(wtop)] && [winfo exists $locals(wtop)]} {
	array set infoArr [::pane::pane info $locals(wfrmbox)]
	set ans [list $locals(wtop)   \
	  [list $infoArr(-relheight) [expr 1.0 - $infoArr(-relheight)]]]
    } elseif {[info exists locals(panePosList)]} {
	set ans $locals(panePosList)
    } else {
	set ans {}
    }
    return $ans
}

#-------------------------------------------------------------------------------
