#  MailBox.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements a mailbox for jabber messages.
#      
#  Copyright (c) 2002-2004  Mats Bengtsson
#  
# $Id: MailBox.tcl,v 1.57 2004-10-27 14:42:36 matben Exp $

# There are two versions of the mailbox file, 1 and 2. Only version 2 is 
# described here.
# Each message is stored as a list in the 'mailbox' array as:
# 
#    mailbox(uid) = {subject from date isread uid message ?-key value ...?}
#
# where 'uid' is an integer unique for each message, but updated when the 
# mailbox is read. The date is ISO 8601. The keys can be: '-canvasuid',
# 
# The inbox must be read to memory when mailbox is displayed, or when (before)
# receiving first message. This is to keep the mailbox array in sync.
# The inbox needs only be saved if we have edits.

package provide MailBox 1.0

namespace eval ::Jabber::MailBox:: {
    global  wDlgs

    # Use option database for customization.
    option add *MailBox*newmsgImage           newmsg           widgetDefault
    option add *MailBox*newmsgDisImage        newmsgDis        widgetDefault
    option add *MailBox*replyImage            reply            widgetDefault
    option add *MailBox*replyDisImage         replyDis         widgetDefault
    option add *MailBox*forwardImage          forward          widgetDefault
    option add *MailBox*forwardDisImage       forwardDis       widgetDefault
    option add *MailBox*saveImage             save             widgetDefault
    option add *MailBox*saveDisImage          saveDis          widgetDefault
    option add *MailBox*printImage            print            widgetDefault
    option add *MailBox*printDisImage         printDis         widgetDefault
    option add *MailBox*trashImage            trash            widgetDefault
    option add *MailBox*trashDisImage         trashDis         widgetDefault

    option add *MailBox*readMsgImage          readMsg          widgetDefault
    option add *MailBox*unreadMsgImage        unreadMsg        widgetDefault
    option add *MailBox*wbIcon11Image         wbIcon11         widgetDefault
    option add *MailBox*wbIcon13Image         wbIcon13         widgetDefault

    # Add some hooks...
    ::hooks::register initHook        ::Jabber::MailBox::Init
    ::hooks::register newMessageHook  ::Jabber::MailBox::GotMsg
    ::hooks::register closeWindowHook ::Jabber::MailBox::CloseHook
    ::hooks::register jabberInitHook  ::Jabber::MailBox::InitHandler
    ::hooks::register quitAppHook     ::Jabber::MailBox::Exit

    variable locals
    
    set locals(inited)        0
    set locals(mailboxRead)   0
    set locals(haveEdits)     0
    set locals(hooksInited)   0
    set locals(updateDateid)  ""
    set locals(updateDatems)  [expr 1000*60]
    set jstate(inboxVis)      0
    
    # Running id for incoming messages; never reused.
    variable uidmsg 1000
    
    variable tableUid2Key

    # The actual mailbox content.
    # Content: {subject from date isread uidmsg message ?-key value ...?}
    variable mailbox
    variable mailboxindex
    array set mailboxindex {
	subject     0
	from        1
	date        2
	isread      3
	uidmsg      4
	message     5
	opts        6
    }
    
    # Keep a level of abstraction between column index and name.
    # Columns: {iswb subject from secs(H) date isread(H) uidmsg(H)}
    #    H=hidden
    variable colindex
    array set colindex {
	iswb      0
	subject   1
	from      2
	secs      3
	date      4
	isread    5
	uidmsg    6
    }
}

# Jabber::MailBox::Init --
# 
#       Take care of things like translating any old version mailbox etc.

proc ::Jabber::MailBox::Init { } {    
    variable locals
    variable icons
   
    TranslateAnyVer1ToCurrentVer
    
    # Icons for the mailbox.
    set icons(readMsg) [image create photo -data {
	R0lGODdhDgAKAKIAAP/////xsOjboMzMzHNzc2NjzjExYwAAACwAAAAADgAK
	AAADJli6vFMhyinMm1NVAkPzxdZhkhh9kUmWBie8cLwZdG3XxEDsfM8nADs=
    }]
    set icons(unreadMsg) [image create photo -data {
	R0lGODdhDgAKALMAAP/////xsOjboMzMzIHzeXNzc2Njzj7oGzXHFzExYwAA
	AAAAAAAAAAAAAAAAAAAAACwAAAAADgAKAAAENtBIcpC8cpgQKOKgkGicB0pi
	QazUUQVoUhhu/YXyZoNcugUvXsAnKBqPqYRyyVwWBoWodCqNAAA7
    }]
    set icons(wbIcon11) [image create photo -data {
	R0lGODlhEQALALMAANnZ2U9PT////wrXAKGhocbK/wAV/+Pl/zlK/46X/3F9
	//8cRf/G0P+quf8ALv///yH5BAEAAAAALAAAAAARAAsAAARmMMhJawABCinh
	kFIIIQIJQhQDzxBCDCGECCQIKJBJQwgxhBAiQBJEMQrBIeVaTAQSBFIHmiOE
	WK0tEUgo0ByBkhDCCeFEgCQgJURCQojVGlwikACNnEIIthYTgcAgJ62BAEjk
	pJVEADs=
    }]
    set icons(wbIcon13) [image create photo -data {
	R0lGODdhFQANALMAAP/////n5/9ze/9CQv8IEOfn/8bO/621/5ycnHN7/zlK
	/wC9AAAQ/wAAAAAAAAAAACwAAAAAFQANAAAEWrDJSWtFDejN+27YZjAHt5wL
	B2aaopAbmn4hMBYH7NGskmi5kiYwIAwCgJWNUdgkGBuBACBNhnyb4IawtWaY
	QJ2GO/YCGGi0MDqtKnccohG5stgtiLx+z+8jIgA7	
    }]
    
    set locals(inited) 1
}

proc ::Jabber::MailBox::InitHandler {jlibName} {
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::coccixmlns coccixmlns
    
    # Register for the whiteboard messages we want. Duplicate protocols.
    $jstate(jlib) message_register normal coccinella:wb  \
      [namespace current]::HandleRawWBMessage
    $jstate(jlib) message_register normal $coccixmlns(whiteboard)  \
      [namespace current]::HandleRawWBMessage
    $jstate(jlib) message_register normal "http://jabber.org/protocol/svgwb" \
      [namespace current]::HandleSVGWBMessage

}

# Jabber::MailBox::ShowHide --
# 
#       Toggles the display of the inbox. With -visible 1 it forces it
#       to be displayed.

proc ::Jabber::MailBox::ShowHide {args} {
    global wDlgs
    upvar ::Jabber::jstate jstate
    variable locals  

    array set argsArr $args
    set w $wDlgs(jinbox)
    
    if {[info exists argsArr(-visible)]} {
	set visible $argsArr(-visible)
    }
    if {![winfo exists $w]} {
	
	# First time we are being called.
	Build
	if {[info exists argsArr(-visible)] && \
	  ($argsArr(-visible) == 0)} {
	    set jstate(inboxVis) 0
	} else {
	    set jstate(inboxVis) 1
	}
    } else {
	set ismapped [winfo ismapped $w]
	set targetstate [expr $ismapped ? 0 : 1]
	if {[info exists argsArr(-visible)]} {
	    set targetstate $argsArr(-visible)
	}
	if {$targetstate} {
	    catch {wm deiconify $w}
	    raise $w
	    UpdateDateAndTime $locals(wtbl)
	} else {
	    catch {wm withdraw $w}
	    if {$locals(updateDateid) != ""} {
		after cancel $locals(updateDateid)
	    }
	}
	set jstate(inboxVis) $targetstate
    }
}

# Jabber::MailBox::Build --
# 
#       Creates the inbox window.

proc ::Jabber::MailBox::Build {args} {
    global  this prefs wDlgs
    
    variable locals  
    variable colindex
    variable mailbox
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Jabber::MailBox::Build args='$args'"

    # The inbox should only be read once to be economical.
    if {!$locals(mailboxRead)} {
	ReadMailbox
    }
    set w $wDlgs(jinbox)
    if {[winfo exists $w]} {
	return
    }
    
    # Toplevel of class MailBox.
    ::UI::Toplevel $w -macstyle documentProc -class MailBox -usemacmainmenu 1
    wm title $w [mc Inbox]

    set locals(wtop) $w
    set jstate(inboxVis) 1
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 4
    
    # Button part.
    set iconNew        [::Theme::GetImage [option get $w newmsgImage {}]]
    set iconNewDis     [::Theme::GetImage [option get $w newmsgDisImage {}]]
    set iconReply      [::Theme::GetImage [option get $w replyImage {}]]
    set iconReplyDis   [::Theme::GetImage [option get $w replyDisImage {}]]
    set iconForward    [::Theme::GetImage [option get $w forwardImage {}]]
    set iconForwardDis [::Theme::GetImage [option get $w forwardDisImage {}]]
    set iconSave       [::Theme::GetImage [option get $w saveImage {}]]
    set iconSaveDis    [::Theme::GetImage [option get $w saveDisImage {}]]
    set iconPrint      [::Theme::GetImage [option get $w printImage {}]]
    set iconPrintDis   [::Theme::GetImage [option get $w printDisImage {}]]
    set iconTrash      [::Theme::GetImage [option get $w trashImage {}]]
    set iconTrashDis   [::Theme::GetImage [option get $w trashDisImage {}]]

    # Since several of these are so frequently used, cache them!
    set locals(iconWb11)       [::Theme::GetImageFromExisting \
      [option get $w wbIcon11Image {}] ::Jabber::MailBox::icons]
    set locals(iconWb13)       [::Theme::GetImageFromExisting \
      [option get $w wbIcon13Image {}] ::Jabber::MailBox::icons]
    set locals(iconReadMsg)    [::Theme::GetImageFromExisting \
      [option get $w readMsgImage {}] ::Jabber::MailBox::icons]
    set locals(iconUnreadMsg)  [::Theme::GetImageFromExisting \
      [option get $w unreadMsgImage {}] ::Jabber::MailBox::icons]

    set wtray $w.frall.frtop
    ::buttontray::buttontray $wtray 50
    pack $wtray -side top -fill x -padx 4 -pady 2
    set locals(wtray) $wtray

    $wtray newbutton new New $iconNew $iconNewDis  \
      [list ::Jabber::NewMsg::Build]
    $wtray newbutton reply Reply $iconReply $iconReplyDis  \
      [list ::Jabber::MailBox::ReplyTo] -state disabled
    $wtray newbutton forward Forward $iconForward $iconForwardDis  \
      [list ::Jabber::MailBox::ForwardTo] -state disabled
    $wtray newbutton save Save $iconSave $iconSaveDis  \
      [list ::Jabber::MailBox::SaveMsg] -state disabled
    $wtray newbutton print Print $iconPrint $iconPrintDis  \
      [list ::Jabber::MailBox::DoPrint] -state disabled
    $wtray newbutton trash Trash $iconTrash $iconTrashDis  \
      ::Jabber::MailBox::TrashMsg -state disabled
    
    ::hooks::run buildMailBoxButtonTrayHook $wtray

    pack [frame $w.frall.divt -bd 2 -relief sunken -height 2] -fill x -side top
    
    if {[string match "mac*" $this(platform)]} {
	pack [frame $w.frall.pad -height 12] -side bottom
    }

    # Frame to serve as container for the pane geometry manager.
    set frmid $w.frall.frmid
    pack [frame $frmid -height 250 -width 380 -relief sunken -bd 1 -class Pane] \
      -side top -fill both -expand 1 -padx 4 -pady 4
    
    # The actual mailbox list as a tablelist.
    set wfrmbox $frmid.frmbox
    frame $wfrmbox
    set wtbl    $wfrmbox.tbl
    set wysctbl $wfrmbox.ysc

    # Columns: {iswb subject from secs(H) date isread(H) uidmsg(H)}
    set columns [list \
      0 {} 16 [mc Subject] 16 [mc From] 0 {} 0 [mc Date] 0 {} 0 {}]
    scrollbar $wysctbl -orient vertical -command [list $wtbl yview]
    tablelist::tablelist $wtbl -columns $columns  \
      -yscrollcommand [list ::UI::ScrollSet $wysctbl \
      [list grid $wysctbl -column 1 -row 0 -sticky ns]] \
      -labelcommand [namespace current]::LabelCommand  \
      -stretch all -width 60 -selectmode extended
    # Pressed -labelbackground #8c8c8c
    $wtbl columnconfigure $colindex(iswb) \
      -labelimage $locals(iconWb13)  \
      -resizable 0 -align center -showarrow 0
    $wtbl columnconfigure $colindex(date) \
      -sortmode command  \
      -sortcommand [namespace current]::SortTimeColumn
    
    # The -formatcommand gives an infinite loop :-(
    # -formatcommand [namespace current]::FormatDateCmd
    $wtbl columnconfigure $colindex(secs)   -hide 1
    $wtbl columnconfigure $colindex(isread) -hide 1
    $wtbl columnconfigure $colindex(uidmsg) -hide 1
    foreach {key value} [array get colindex] {
	$wtbl columnconfigure $value -name $key
    }
    
    grid $wtbl    -column 0 -row 0 -sticky news
    grid $wysctbl -column 1 -row 0 -sticky ns
    grid columnconfigure $wfrmbox 0 -weight 1
    grid rowconfigure $wfrmbox 0 -weight 1
    
    set i 0
    foreach id [lsort -integer [array names mailbox]] {
	InsertRow $wtbl $mailbox($id) $i
	incr i
    }
    
    # Display message in a text widget.
    set wfrmsg $frmid.frmsg    
    frame $wfrmsg
    set wtextmsg $wfrmsg.text
    set wyscmsg  $wfrmsg.ysc
    text $wtextmsg -height 4 -width 1 -wrap word \
      -borderwidth 1 -relief sunken  \
      -yscrollcommand [list ::UI::ScrollSet $wyscmsg \
      [list grid $wyscmsg -column 1 -row 0 -sticky ns]] \
      -state disabled
    $wtextmsg tag configure normal
    scrollbar $wyscmsg -orient vertical -command [list $wtextmsg yview]
    grid $wtextmsg -column 0 -row 0 -sticky news
    grid $wyscmsg -column 1 -row 0 -sticky ns
    grid columnconfigure $wfrmsg 0 -weight 1
    grid rowconfigure $wfrmsg 0 -weight 1
    
    set imageHorizontal  \
      [::Theme::GetImage [option get $frmid imageHorizontal {}]]
    set sashHBackground [option get $frmid sashHBackground {}]

    set paneopts [list -orient vertical -limit 0.0]
    if {[info exists prefs(paneGeom,$w]} {
	lappend paneopts -relative $prefs(paneGeom,$w)
    } else {
	lappend paneopts -relative {0.75 0.25}
    }
    if {$sashHBackground != ""} {
	lappend paneopts -image "" -handlelook [list -background $sashHBackground]
    } elseif {$imageHorizontal != ""} {
	lappend paneopts -image $imageHorizontal
    }    
    eval {::pane::pane $wfrmbox $wfrmsg} $paneopts
    
    set locals(wfrmbox)  $wfrmbox
    set locals(wtbl)     $wtbl
    set locals(wtextmsg) $wtextmsg
        
    ::UI::SetWindowGeometry $w
    wm minsize $w 300 260
    wm maxsize $w 1200 1000
    
    # Add all event hooks.
    if {!$locals(hooksInited)} {
	set locals(hooksInited) 1
	::hooks::register quitAppHook [list ::UI::SaveWinGeom $w]
	::hooks::register quitAppHook [list ::UI::SavePanePos $w $locals(wfrmbox)]
    }
    
    # Grab and focus.
    focus $w
    
    # Make selection available in text widget but not editable!
    # Seems to stop the tablelist from getting focus???
    #$wtextmsg bind <Key> break

    # Special bindings for the tablelist.
    set body [$wtbl bodypath]
    bind $body <Button-1> {+ focus %W}
    bind $body <Double-1> [list [namespace current]::DoubleClickMsg]
    bind $wtbl <<ListboxSelect>> [list [namespace current]::SelectMsg]
    
    LabelCommand $wtbl $colindex(secs)
    
    set locals(updateDateid) [after $locals(updateDatems) \
      [list [namespace current]::UpdateDateAndTime $wtbl]]
}


proc ::Jabber::MailBox::CloseHook {wclose} {
    global  wDlgs
    
    set result ""
    if {[string equal $wclose $wDlgs(jinbox)]} {
	ShowHide -visible 0
	set result stop
    }
    return $result
}

# Jabber::MailBox::InsertRow --
#
#       Does the actual job of adding a line in the mailbox widget.

proc ::Jabber::MailBox::InsertRow {wtbl row i} {
    
    variable mailboxindex
    variable colindex
    variable locals
    variable tableUid2Key
    
    # row:   {subject from date isread uidmsg message ?-key value ...?}
    # item:  {iswb subject from secs(H) date isread(H) uidmsg(H)}
    
    # Does this message contain a whiteboard message?
    set haswb 0
    set len [llength $row]
    if {($len > $mailboxindex(opts))} {
	array set rowOpts [lrange $row $mailboxindex(opts) end]
	if {[info exists rowOpts(-canvasuid)]} {
	    set haswb 1
	} elseif {[llength [GetAnySVGElements $row]]} {
	    set haswb 1
	}
    }
    set subject [lindex $row $mailboxindex(subject)]
    set from    [lindex $row $mailboxindex(from)]
    set date    [lindex $row $mailboxindex(date)]
    set isread  [lindex $row $mailboxindex(isread)]
    set uidmsg  [lindex $row $mailboxindex(uidmsg)]
    set secs      [clock scan $date]
    set smartdate [::Utils::SmartClockFormat $secs]
    
    set item [list {} $subject $from $secs $smartdate $isread $uidmsg]
    
    set fontS  [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]

    $wtbl insert end $item
    set tableUid2Key($uidmsg) [$wtbl getkeys end]
    if {$haswb} {
	$wtbl cellconfigure "${i},$colindex(iswb)" -image $locals(iconWb11)
    }
    set colsub $colindex(subject)
    if {[lindex $item $colindex(isread)] == 0} {
	$wtbl rowconfigure $i -font $fontSB
	$wtbl cellconfigure "${i},${colsub}" -image $locals(iconUnreadMsg)
    } else {
	$wtbl rowconfigure $i -font $fontS
	$wtbl cellconfigure "${i},${colsub}" -image $locals(iconReadMsg)
    }
}

proc ::Jabber::MailBox::FormatDateCmd {secs} {
    
    puts "::Jabber::MailBox::FormatDateCmd secs=$secs"
    set displaytime [::Jabber::MailBox::FormatDateCmd $secs]
    puts "displaytime=$displaytime"
    return [::Jabber::MailBox::FormatDateCmd $secs]
}

proc ::Jabber::MailBox::UpdateDateAndTime {wtbl} {
    
    variable mailbox
    variable colindex
    variable mailboxindex
    variable locals
    
    # Loop through the dates of all messages and update.
    set size [$wtbl size]
    for {set ind 0} {$ind < $size} {incr ind} {
	set uidmsg [lindex [$wtbl get $ind] $colindex(uidmsg)]
	set secs [clock scan [lindex $mailbox($uidmsg) $mailboxindex(date)]]
	set smartdate [::Utils::SmartClockFormat $secs]
	set cell $ind,$colindex(date)
	$wtbl cellconfigure $cell -text $smartdate
    }
    
    # Reschedule ourselves.
    set locals(updateDateid) [after $locals(updateDatems) \
      [list [namespace current]::UpdateDateAndTime $wtbl]]
}

proc ::Jabber::MailBox::GetToplevel { } {    
    variable locals
    
    if {[info exists locals(wtop)] && [winfo exists $locals(wtop)]} {
	return $locals(wtop)
    } else {
	return {}
    }
}

# Various accessor functions.

proc ::Jabber::MailBox::Get {id key} {
    variable mailbox
    variable mailboxindex
    
    return [lindex $mailbox($id) $mailboxindex($key)]
}

proc ::Jabber::MailBox::Set {id key value} {
    variable mailbox
    variable mailboxindex
    
    lset mailbox($id) $mailboxindex($key) $value
}

proc ::Jabber::MailBox::IsLastMessage {id} {
    variable mailbox

    set sorted [lsort -integer [array names mailbox]]
    return [expr ($id >= [lindex $sorted end]) ? 1 : 0]
}

proc ::Jabber::MailBox::AllRead { } {
    variable mailbox
    variable mailboxindex
    
    # Find first that is not read.
    set allRead 1
    foreach uid [array names mailbox] {
	if {![lindex $mailbox($uid) $mailboxindex(isread)]} {
	    set allRead 0
	    break
	}
    }
    return $allRead
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

proc ::Jabber::MailBox::GetMsgFromUid {id} {
    variable mailbox
    
    if {[info exists mailbox($id)]} {
	return $mailbox($id)
    } else {
	return {}
    }
}

# Jabber::MailBox::GetCanvasHexUID --
#
#       Returns the unique hex id for canvas if message has any, else empty.

proc ::Jabber::MailBox::GetCanvasHexUID {id} {
    variable mailbox
    variable mailboxindex

    set ans ""
    if {[llength $mailbox($id)] > $mailboxindex(opts)} {
	array set optsArr [lrange $mailbox($id) $mailboxindex(opts) end]
	if {[info exists optsArr(-canvasuid)]} {
	    set ans $optsArr(-canvasuid)
	}
    }
    return $ans
}

proc ::Jabber::MailBox::MarkMsgAsRead {uid} {
    global  wDlgs
    variable mailbox
    variable mailboxindex
    variable colindex
    variable locals
    variable tableUid2Key
    
    if {[lindex $mailbox($uid) $mailboxindex(isread)] == 0} {
	lset mailbox($uid) $mailboxindex(isread) 1
	
	if {[winfo exists $wDlgs(jinbox)]} {
	    set fontS [option get . fontSmall {}]
	    set colsub $colindex(subject)
	    set wtbl $locals(wtbl)
	    
	    # Map uid to row (item) index.
	    set key $tableUid2Key($uid)
	    set item [$wtbl index k${key}]
	    $wtbl rowconfigure $item -font $fontS
	    $wtbl cellconfigure "${item},${colsub}" -image $locals(iconReadMsg)
	}
	set locals(haveEdits) 1
    }
}

# Jabber::MailBox::GotMsg --
#
#       Called when we get an incoming message. Stores the message.
#       Should never be called for whiteboard messages.
#
# Arguments:
#       bodytxt     the body chdata
#       args        the xml attributes and elements as a '-key value' list
#       
# Results:
#       updates UI.

proc ::Jabber::MailBox::GotMsg {bodytxt args} {
    global  prefs

    variable locals
    variable mailbox
    variable uidmsg
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Jabber::MailBox::GotMsg args='$args'"
    
    # Non whiteboard 'normal' messages treated as chat messages.
    if {$jprefs(chat,normalAsChat)} {
	return
    }
    
    # The inbox should only be read once to be economical.
    if {!$locals(mailboxRead)} {
	ReadMailbox
    }
    set bodytxt [string trimright $bodytxt "\n"]
    set messageList [eval {MakeMessageList $bodytxt} $args]    
    
    # All messages cached in 'mailbox' array.
    set mailbox($uidmsg) $messageList
    
    # Always cache it in inbox.
    PutMessageInInbox $messageList
        
    # Show in mailbox. Sorting?
    set w [GetToplevel]
    if {$w != ""} {
	InsertRow $locals(wtbl) $mailbox($uidmsg) end
	$locals(wtbl) see end
    }
    ::Jabber::UI::MailBoxState nonempty
    
    # Any separate window.
    if {$jprefs(showMsgNewWin)} {
	::Jabber::GotMsg::GotMsg $uidmsg
    }
}

# Jabber::MailBox::HandleRawWBMessage --
# 
#       Same as above, but for raw whiteboard messages.

proc ::Jabber::MailBox::HandleRawWBMessage {jlibname xmlns args} {
    global  prefs

    variable mailbox
    variable uidmsg
    variable locals
    
    ::Debug 2 "::Jabber::MailBox::HandleRawWBMessage args=$args"
    array set argsArr $args
	
    # The inbox should only be read once to be economical.
    if {!$locals(mailboxRead)} {
	ReadMailbox
    }
    set messageList [eval {MakeMessageList ""} $args]
    set rawList     [::Jabber::WB::GetRawCanvasMessageList $argsArr(-x) $xmlns]
    set canvasuid   [::Utils::GenerateHexUID]
    set filePath    [file join $prefs(inboxCanvasPath) ${canvasuid}.can]
    ::CanvasFile::DataToFile $filePath $rawList
    lappend messageList -canvasuid $canvasuid
    set mailbox($uidmsg) $messageList
    PutMessageInInbox $messageList

    # Show in mailbox.
    set w [GetToplevel]
    if {$w != ""} {
	InsertRow $locals(wtbl) $mailbox($uidmsg) end
	$locals(wtbl) see end
    }
    ::Jabber::UI::MailBoxState nonempty
    
    eval {::hooks::run newWBMessageHook} $args

    # We have handled this message completely.
    return 1
}

# Jabber::MailBox::HandleSVGWBMessage --
# 
#       As above but for SVG whiteboard messages.

proc ::Jabber::MailBox::HandleSVGWBMessage {jlibname xmlns args} {
    global  prefs

    variable mailbox
    variable uidmsg
    variable locals
    
    ::Debug 2 "::Jabber::MailBox::HandleSVGWBMessage args='$args'"
    array set argsArr $args
	
    # The inbox should only be read once to be economical.
    if {!$locals(mailboxRead)} {
	ReadMailbox
    }
    set messageList [eval {MakeMessageList ""} $args]

    # Store svg in x element.
    lappend messageList -x $argsArr(-x)

    set mailbox($uidmsg) $messageList
    PutMessageInInbox $messageList

    # Show in mailbox.
    set w [GetToplevel]
    if {$w != ""} {
	InsertRow $locals(wtbl) $mailbox($uidmsg) end
	$locals(wtbl) see end
    }
    ::Jabber::UI::MailBoxState nonempty
    
    eval {::hooks::run newWBMessageHook} $args

    # We have handled this message completely.
    return 1
}

proc ::Jabber::MailBox::MakeMessageList {body args} {
    variable locals
    variable uidmsg
    
    array set argsArr {
	-from unknown -subject {}
    }
    array set argsArr $args

    jlib::splitjid $argsArr(-from) jid2 res

    # Here we should probably check som 'jabber:x:delay' element...
    # This is ISO 8601.
    set secs ""
    if {[info exists argsArr(-x)]} {
	set tm [::Jabber::GetAnyDelayElem $argsArr(-x)]
	if {$tm != ""} {
	    # Always use local time!
	    set secs [clock scan $tm -gmt 1]
	}
    }
    if {$secs == ""} {
	set secs [clock seconds]
    }
    set date [clock format $secs -format "%Y%m%dT%H:%M:%S"]

    # List format for messages.
    return [list $argsArr(-subject) $argsArr(-from) $date 0 [incr uidmsg] $body]
}

proc ::Jabber::MailBox::PutMessageInInbox {row} {
    global  this
    upvar ::Jabber::jprefs jprefs
    
    set exists 0
    if {[file exists $jprefs(inboxPath)]} {
	set exists 1
    }
    if {![catch {open $jprefs(inboxPath) a} fd]} {
	if {!$exists} {
	    WriteInboxHeader $fd
	    if {[string equal $this(platform) "macintosh"]} {
		file attributes $jprefs(inboxPath) -type pref
	    }
	}
	puts $fd "set mailbox(\[incr uidmsg]) {$row}"
	close $fd
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
	if {[catch {open $ans w} fd]} {
	    tk_messageBox -title {Open Failed} -parent $wtbl -type ok \
	      -message "Failed opening file [file tail $ans]: $fd"
	    return
	}
	set row [$wtbl get $item]
	set from    [lindex $row $colindex(from)]
	set subject [lindex $row $colindex(subject)]
	set time [lindex $row $colindex(secs)]
	set time [clock format [clock scan $time]]
	set maxw 14
	puts $fd [format "%-*s %s" $maxw "From:" $from]
	puts $fd [format "%-*s %s" $maxw "Subject:" $subject]
	puts $fd [format "%-*s %s" $maxw "Time:" $time]
	puts $fd "\n"
	puts $fd [::Text::TransformToPureText $wtextmsg]
	close $fd
	if {[string equal $this(platform) "macintosh"]} {
	    file attributes $ans -type TEXT -creator ttxt
	}
    }
}

proc ::Jabber::MailBox::TrashMsg { } {
    global  prefs
    
    variable locals
    variable mailbox
    variable colindex
    
    set locals(haveEdits) 1

    # Need selected line here.
    set wtbl  $locals(wtbl)
    set items [$wtbl curselection]
    set wtop  $locals(wtop)
    set wtray $locals(wtray)
    set lastitem [lindex $items end]
    if {[llength $items] == 0} {
	return
    }
    set last [expr [$wtbl size] - 1]
    
    # Careful, delete in reversed order!
    foreach item [lsort -integer -decreasing $items] {
	set id [lindex [$wtbl get $item] $colindex(uidmsg)]
	set uid [GetCanvasHexUID $id]
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
	SelectMsg 
    } else {
	$wtray buttonconfigure reply -state disabled
	$wtray buttonconfigure forward -state disabled
	$wtray buttonconfigure save -state disabled
	$wtray buttonconfigure print -state disabled
	$wtray buttonconfigure trash -state disabled
	MsgDisplayClear
	::Jabber::UI::MailBoxState empty
    }
}

# Jabber::MailBox::SelectMsg --
# 
#       Executed when selecting a message in the inbox.
#       Handles display of message, whiteboard, etc.
#       
#    mailbox(uid) = {subject from date isread uid message ?-key value ...?}

proc ::Jabber::MailBox::SelectMsg { } {
    global  prefs wDlgs

    variable locals
    variable mailbox
    variable mailboxindex
    variable colindex
    upvar ::Jabber::jstate jstate
    
    set wtextmsg $locals(wtextmsg)
    set wtbl     $locals(wtbl)
    set wtop     $locals(wtop)
    set wtray    $locals(wtray)
    set item     [$wtbl curselection]
    if {[llength $item] == 0} {
	return
    } elseif {[llength $item] > 1} {
	
	# If multiple selected items.
	$wtray buttonconfigure reply -state disabled
	$wtray buttonconfigure forward -state disabled
	$wtray buttonconfigure save -state disabled
	$wtray buttonconfigure print -state disabled
	MsgDisplayClear
	return
    }
    set row [$wtbl get $item]
    set uid [lindex $row $colindex(uidmsg)]
    
    # 2-tier jid.
    #set jid2 [lindex $row $colindex(from)]
        
    # 3-tier jid.
    set jid3 [lindex $mailbox($uid) $mailboxindex(from)]
    jlib::splitjid $jid3 jid2 res

    # Mark as read.
    MarkMsgAsRead $uid
    DisplayMsg $uid
    
    # Configure buttons.
    $wtray buttonconfigure reply   -state normal
    $wtray buttonconfigure forward -state normal
    $wtray buttonconfigure save    -state normal
    $wtray buttonconfigure print   -state normal
    $wtray buttonconfigure trash   -state normal
    
    # If any whiteboard stuff in message...
    set uidcan [GetCanvasHexUID $uid]
    set svgElem [GetAnySVGElements $mailbox($uid)]
    ::Debug 2 "::Jabber::MailBox::SelectMsg  uidcan=$uidcan, svgElem='$svgElem'"
     
    # The "raw" protocol stores the canvas in a separate file indicated by
    # the -canvasuid key in the message list.
    # The SVG protocol stores the complete x element in the mailbox 
    # -x listOfElements
    
    # The "raw" protocol.
    if {[string length $uidcan] > 0} {	
	DisplayRawMessage $jid3 $uidcan
    } elseif {[llength $svgElem]} {
	DisplayXElementSVG $jid3 $svgElem
    }
}

proc ::Jabber::MailBox::GetAnySVGElements {row} {
    
    set svgElem {}
    set idx [lsearch $row -x]
    if {$idx > 0} {
	set xlist [lindex $row [expr $idx+1]]
	set svgElem [wrapper::getnamespacefromchilds $xlist x \
	  "http://jabber.org/protocol/svgwb"]
    }
    return $svgElem
}

# Jabber::MailBox::DisplayRawMessage --
# 
#       Displays a raw whiteboard message when selected in inbox.

proc ::Jabber::MailBox::DisplayRawMessage {jid3 uid} {
    global  prefs wDlgs

    variable mailbox
    upvar ::Jabber::jstate jstate
    
    jlib::splitjid $jid3 jid2 res
    set wtop [MakeWhiteboard $jid2]
    
    # Only if user available shall we try to import.
    set tryimport 0
    if {[$jstate(roster) isavailable $jid3] || \
      [jlib::jidequal $jid3 $jstate(mejidres)]} {
	set tryimport 1
    }
	    
    set fileName ${uid}.can
    set filePath [file join $prefs(inboxCanvasPath) $fileName]
    set numImports [::CanvasFile::DrawCanvasItemFromFile $wtop \
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

proc ::Jabber::MailBox::DisplayXElementSVG {jid3 xlist} {
    global  prefs wDlgs

    variable mailbox
    upvar ::Jabber::jstate jstate
    ::Debug 2 "::Jabber::MailBox::DisplayXElementSVG jid3=$jid3"
    
    jlib::splitjid $jid3 jid2 res
    
    set wtop [MakeWhiteboard $jid2]
    
    # Only if user available shall we try to import.
    set tryimport 0
    if {[$jstate(roster) isavailable $jid3] || \
      [jlib::jidequal $jid3 $jstate(mejidres)]} {
	set tryimport 1
    }

    set cmdList [::Jabber::WB::GetSVGWBMessageList $wtop $xlist]
    foreach line $cmdList {
	::CanvasUtils::HandleCanvasDraw $wtop $line -tryimport $tryimport
    }         
}

# Jabber::MailBox::MakeWhiteboard --
# 
#       Creates or configures the inbox whiteboard window.

proc ::Jabber::MailBox::MakeWhiteboard {jid2} {
    global  prefs wDlgs
    
    set wwb  $wDlgs(jwbinbox)
    set wtop ${wwb}.
    set title "Inbox: $jid2"
    
    if {[winfo exists $wwb]} {
	::Import::HttpResetAll  $wtop
	::CanvasCmd::EraseAll   $wtop
	::WB::ConfigureMain     $wtop -title $title	    
	::WB::SetStatusMessage  $wtop ""
	::Jabber::WB::Configure $wtop -jid $jid2
	undo::reset [::WB::GetUndoToken $wtop]
    } else {
	::Jabber::WB::NewWhiteboard -wtop $wtop -state disabled \
	  -title $title -jid $jid2 -usewingeom 1
    }
    return $wtop
}

proc ::Jabber::MailBox::DoubleClickMsg { } {
    variable locals
    variable mailbox
    variable mailboxindex
    variable colindex
    upvar ::Jabber::jprefs jprefs
    
    set wtbl $locals(wtbl)
    set item [$wtbl curselection]
    if {[string length $item] == 0} {
	return
    }
    set row [$wtbl get $item]
    set id [lindex $row $colindex(uidmsg)]

    # We shall have the original, unparsed, text here.
    set body    [lindex $mailbox($id) $mailboxindex(message)]
    set subject [lindex $mailbox($id) $mailboxindex(subject)]
    set to      [lindex $mailbox($id) $mailboxindex(from)]
    set date    [lindex $mailbox($id) $mailboxindex(date)]
    
    if {[string equal $jprefs(inbox2click) "newwin"]} {
	::Jabber::GotMsg::GotMsg $id
    } elseif {[string equal $jprefs(inbox2click) "reply"]} {
	if {![regexp -nocase {^ *re:} $subject]} {
	    set subject "Re: $subject"
	}	
	::Jabber::NewMsg::Build -to $to -subject $subject  \
	  -quotemessage $body -time $date
    }
}

proc ::Jabber::MailBox::LabelCommand {w column} {
    variable locals    
    
    tablelist::sortByColumn $w $column
}

proc ::Jabber::MailBox::SortTimeColumn {tm1 tm2} {
    variable locals
    
    if {0} {
	# when -formatcommand is used.
	if {$tm1 > $tm2} {
	    return 1
	} elseif {$tm1 == $tm2} {
	    return 0
	} else {
	    return -1
	}    
    }

    # 'clock scan' shall take care of formats like 'today' etc.
    set long1 [clock scan $tm1]
    set long2 [clock scan $tm2]
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
    variable mailboxindex
    
    set wtextmsg $locals(wtextmsg)    

    set subject [lindex $mailbox($id) $mailboxindex(subject)]
    set from    [lindex $mailbox($id) $mailboxindex(from)]
    set date    [lindex $mailbox($id) $mailboxindex(date)]
    set body    [lindex $mailbox($id) $mailboxindex(message)]
    
    $wtextmsg configure -state normal
    $wtextmsg delete 1.0 end
    ::Text::Parse $wtextmsg $body normal
    $wtextmsg insert end \n
    $wtextmsg configure -state disabled
    
    set opts [list -subject $subject -from $from -time $date]
    eval {::hooks::run displayMessageHook $body} $opts
}

proc ::Jabber::MailBox::ReplyTo { } {
    variable locals
    variable mailbox
    variable mailboxindex
    variable colindex
    upvar ::Jabber::jstate jstate
    
    set wtbl $locals(wtbl)
    set item [$wtbl curselection]
    if {[string length $item] == 0} {
	return
    }
    set row [$wtbl get $item]
    set id [lindex $row $colindex(uidmsg)]

    # We shall have the original, unparsed, text here.
    set subject [lindex $mailbox($id) $mailboxindex(subject)]
    set from    [lindex $mailbox($id) $mailboxindex(from)]
    set date    [lindex $mailbox($id) $mailboxindex(date)]
    set body    [lindex $mailbox($id) $mailboxindex(message)]
    
    set to [::Jabber::JlibCmd getrecipientjid $from]
    if {![regexp -nocase {^ *re:} $subject]} {
	set subject "Re: $subject"
    }
    ::Jabber::NewMsg::Build -to $to -subject $subject  \
      -quotemessage $body -time $date
}

proc ::Jabber::MailBox::ForwardTo { } {
    variable locals
    variable mailbox
    variable mailboxindex
    variable colindex
    
    set wtbl $locals(wtbl)
    set item [$wtbl curselection]
    if {[string length $item] == 0} {
	return
    }
    set row [$wtbl get $item]
    set id [lindex $row $colindex(uidmsg)]

    # We shall have the original, unparsed, text here.
    set subject [lindex $mailbox($id) $mailboxindex(subject)]
    set from    [lindex $mailbox($id) $mailboxindex(from)]
    set date    [lindex $mailbox($id) $mailboxindex(date)]
    set body    [lindex $mailbox($id) $mailboxindex(message)]

    set subject "Forwarded: $subject"
    ::Jabber::NewMsg::Build -subject $subject -forwardmessage $body -time $date
}

proc ::Jabber::MailBox::DoPrint { } {

    variable locals

    set allText [::Text::TransformToPureText $locals(wtextmsg)]
    set fontS [option get . fontSmall {}]
    
    ::UserActions::DoPrintText $locals(wtextmsg)  \
      -data $allText -font $fontS
}

proc ::Jabber::MailBox::SaveMailbox {args} {

    eval {SaveMailboxVer2} $args
}
    
proc ::Jabber::MailBox::SaveMailboxVer1 { } {
    global  this
    
    variable locals
    variable mailbox
    upvar ::Jabber::jprefs jprefs
    
    # Do not store anything if empty.
    if {[llength [array names mailbox]] == 0} {
	return
    }
    
    # Work on a temporary file and switch later.
    set tmpFile $jprefs(inboxPath).tmp
    if {[catch {open $tmpFile w} fid]} {
	tk_messageBox -type ok -icon error -message  \
	  [FormatTextForMessageBox [mc jamesserrinboxopen $tmpFile]]
	return
    }
    
    # Header information.
    puts $fid "# Version: 1"
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
    if {[string equal $this(platform) "macintosh"]} {
	file attributes $jprefs(inboxPath) -type pref
    }
}

# Jabber::MailBox::SaveMailboxVer2 --
# 
#       Saves current mailbox to the inbox file provided it is necessary.
#       
# Arguments:
#       args:       -force 0|1 (D=0) forces save unconditionally
#       

proc ::Jabber::MailBox::SaveMailboxVer2 {args} {
    global  this
    
    variable mailbox
    variable locals
    upvar ::Jabber::jprefs jprefs
    
    array set argsArr {
	-force      0
    }
    array set argsArr $args
    
    # If the mailbox is read there can be edits. Needs therefore to save state.
    if {$argsArr(-force)} {
	set doSave 1
    } else {
	set doSave 0
    }
    ::Debug 2 "::Jabber::MailBox::SaveMailboxVer2 args=$args"
    if {$locals(mailboxRead)} {

	# Be sure to not have any inbox that is empty.
	if {[llength [array names mailbox]] == 0} {
	    catch {file delete $jprefs(inboxPath)}
	    ::Debug 2 "\tdelete inbox"
	    return
	} else {
	    
	    # Save only if mailbox read and have nonempty mailbox array.
	    set doSave 1
	}
    }
    ::Debug 2 "\t doSave=$doSave"
    if {!$doSave} {
	return
    }
        
    # Work on a temporary file and switch later.
    set tmpFile $jprefs(inboxPath).tmp
    if {[catch {open $tmpFile w} fid]} {
	tk_messageBox -type ok -icon error -message  \
	  [FormatTextForMessageBox [mc jamesserrinboxopen $tmpFile]]
	return
    }
    
    # Start by writing the header info.
    WriteInboxHeader $fid
    foreach id [lsort -integer [array names mailbox]] {
	puts $fid "set mailbox(\[incr uidmsg]) {$mailbox($id)}"
    }
    close $fid
    if {[catch {file rename -force $tmpFile $jprefs(inboxPath)} msg]} {
	tk_messageBox -type ok -message {Error renaming preferences file.}  \
	  -icon error
	return
    }
    if {[string equal $this(platform) "macintosh"]} {
	file attributes $jprefs(inboxPath) -type pref
    }
}

proc ::Jabber::MailBox::WriteInboxHeader {fid} {
    global  prefs
    
    # Header information.
    puts $fid "# Version: 2"
    puts $fid "#\n#   User's Jabber Message Box for $prefs(theAppName)."
    puts $fid "#   The data written at: [clock format [clock seconds]]\n#"    
}

proc ::Jabber::MailBox::ReadMailbox { } {
    variable locals
    upvar ::Jabber::jprefs jprefs

    # Set this even if not there.
    set locals(mailboxRead) 1
    if {[file exists $jprefs(inboxPath)]} {
	ReadMailboxVer2
    }
}

proc ::Jabber::MailBox::TranslateAnyVer1ToCurrentVer { } {
    variable locals
    variable mailbox
    
    set ver [GetMailboxVersion]
    if {[string equal $ver "1"]} {
	ReadMailboxVer1
	
	# This should save the inbox in its current version.
	SaveMailbox -force 1
	
	# Cleanup state variables.
	unset -nocomplain locals(mailbox) mailbox
    }
}

# Jabber::MailBox::GetMailboxVersion --
# 
#       Returns empty string if no mailbox exists, else the version number of
#       any existing mailbox.

proc ::Jabber::MailBox::GetMailboxVersion { } {
    upvar ::Jabber::jprefs jprefs
    
    set version ""
    if {[file exist $jprefs(inboxPath)]} {
	if {![catch {open $jprefs(inboxPath) r} fd]} {
	    if {[gets $fd line] >= 0} { 
		if {![regexp -nocase {^ *# *version: *([0-9]+)} $line match version]} {
		    set version 1
		}
	    }
	    close $fd
	}
    }
    return $version
}

proc ::Jabber::MailBox::ReadMailboxVer1 { } {
    variable locals
    variable uidmsg
    variable mailbox
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Jabber::MailBox::ReadMailboxVer1"

    if {[catch {source $jprefs(inboxPath)} msg]} {
	set tail [file tail $jprefs(inboxPath)]
	tk_messageBox -title [mc {Mailbox Error}] -icon error  \
	  -type ok -message [FormatTextForMessageBox \
	  [mc jamesserrinboxread $tail $msg]]
    } else {
	
	# The mailbox on file is just a hierarchical list that needs to be
	# translated to an array. Be sure to update the uidmsg's!
	foreach row $locals(mailbox) {
	    set id [incr uidmsg]
	    set mailbox($id) [lreplace $row 4 4 $id]

	    # Any canvas uid must be translated to '-canvasuid hex' option
	    # to be compatible with new mailbox format.
	    if {[llength $row] == 7} {
	     	if {[string length [lindex $row 6]]} {
		    set mailbox($id) [lreplace $row 6 end -canvasuid [lindex $row 6]]
		} else {
		    set mailbox($id) [lrange $row 0 5]
		}
	    }
	}
    }
}

proc ::Jabber::MailBox::ReadMailboxVer2 { } {
    variable locals
    variable uidmsg
    variable mailbox
    variable mailboxindex
    upvar ::Jabber::jprefs jprefs

    ::Debug 2 "::Jabber::MailBox::ReadMailboxVer2"

    if {[catch {source $jprefs(inboxPath)} msg]} {
	set tail [file tail $jprefs(inboxPath)]
	tk_messageBox -title [mc {Mailbox Error}] -icon error  \
	  -type ok -message [FormatTextForMessageBox \
	  [mc jamesserrinboxread $tail $msg]]
    } else {
	
	# Keep the uidmsg in sync for each list in mailbox.
	foreach id [lsort -integer [array names mailbox]] {
	    lset mailbox($id) $mailboxindex(uidmsg) $id
	    
	    # If stored as secs translate to formatted.
	    set date [lindex $mailbox($id) $mailboxindex(date)]
	    if {[string is integer $date]} {
		lset mailbox($id) $mailboxindex(date) \
		  [clock format $date -format "%Y%m%dT%H:%M:%S"]
	    }
	    
	    # Consistency check.
	    if {[expr [llength $mailbox($id)] % 2] == 1} {
	    	set mailbox($id) [lrange $mailbox($id) 0 5]
	    }
	}
    }
}

proc ::Jabber::MailBox::HaveMailBox { } {
    upvar ::Jabber::jprefs jprefs

    if {[file exist $jprefs(inboxPath)]} {
	set ans 1
    } else {
	set ans 0
    }
    return $ans
}

proc ::Jabber::MailBox::DeleteMailbox { } {
    global prefs
    upvar ::Jabber::jprefs jprefs

    if {[file exist $jprefs(inboxPath)]} {
	catch {file delete $jprefs(inboxPath)}
    }    
    foreach f [glob -nocomplain -directory $prefs(inboxCanvasPath) *.can] {
	catch {file delete $f}
    }
}

proc ::Jabber::MailBox::Exit { } {
    upvar ::Jabber::jprefs jprefs
    variable locals
    
    if {$jprefs(inboxSave)} {
	if {$locals(haveEdits)} {
	    SaveMailbox
	}
    } else {
	DeleteMailbox
    }
}

proc ::Jabber::MailBox::CloseDlg {w} {
    global  prefs wDlgs

    variable locals
    upvar ::Jabber::jstate jstate

    set jstate(inboxVis) 0
    ::UI::SaveWinGeom $w
    ::UI::SavePanePos $wDlgs(jinbox) $locals(wfrmbox)
    catch {destroy $w}
}

#-------------------------------------------------------------------------------
