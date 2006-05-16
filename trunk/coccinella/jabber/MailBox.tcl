#  MailBox.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements a mailbox for jabber messages.
#      
#  Copyright (c) 2002-2005  Mats Bengtsson
#  
# $Id: MailBox.tcl,v 1.86 2006-05-16 06:06:29 matben Exp $

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

package require uuid

package provide MailBox 1.0

namespace eval ::MailBox:: {
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

    option add *MailBox*readMsgImage          eyeGray16        widgetDefault
    option add *MailBox*unreadMsgImage        eyeBlue16        widgetDefault
    option add *MailBox*whiteboard12Image     whiteboard12     widgetDefault
    option add *MailBox*whiteboard16Image     whiteboard16     widgetDefault

    # Standard widgets.
    if {[tk windowingsystem] eq "aqua"} {
	option add *MailBox*mid.padding                {12 10 12 18}    50
    } else {
	option add *MailBox*mid.padding                {10  8 10  8}    50
    }
    option add *MailBox*Text.borderWidth           0                50
    option add *MailBox*Text.relief                flat             50

    # Add some hooks...
    ::hooks::register initHook            ::MailBox::Init
    ::hooks::register prefsInitHook       ::MailBox::InitPrefsHook
    ::hooks::register launchFinalHook     ::MailBox::LaunchHook
    ::hooks::register newMessageHook      ::MailBox::MessageHook    10
    ::hooks::register jabberInitHook      ::MailBox::InitHandler
    ::hooks::register quitAppHook         ::MailBox::QuitHook
    ::hooks::register displayMessageHook  ::MailBox::DisplayMessageHook

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
    
    variable tableUid2Item

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
}

# MailBox::Init --
# 
#       Take care of things like translating any old version mailbox etc.

proc ::MailBox::Init { } {    
    variable locals
    variable icons
   
    TranslateAnyVer1ToCurrentVer
    
    set locals(inited) 1
}

proc ::MailBox::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
        
    set jprefs(mailbox,dialog) 0
    
    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(mailbox,dialog)  jprefs_mailbox_dialog  $jprefs(mailbox,dialog)]  \
      ]
}

proc ::MailBox::InitHandler {jlibName} {
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


proc ::MailBox::LaunchHook { } {
    upvar ::Jabber::jprefs jprefs
    
    if {$jprefs(rememberDialogs) && $jprefs(mailbox,dialog)} {
	ShowHide -visible 1
    }
}

# MailBox::ShowHide --
# 
#       Toggles the display of the inbox. With -visible 1 it forces it
#       to be displayed.

proc ::MailBox::ShowHide {args} {
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

# MailBox::Build --
# 
#       Creates the inbox window.

proc ::MailBox::Build {args} {
    global  this prefs wDlgs
    
    variable locals  
    variable mailbox
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::MailBox::Build args='$args'"

    # The inbox should only be read once to be economical.
    if {!$locals(mailboxRead)} {
	ReadMailbox
    }
    set w $wDlgs(jinbox)
    if {[winfo exists $w]} {
	return
    }
    
    # Toplevel of class MailBox.
    ::UI::Toplevel $w -class MailBox \
      -macstyle documentProc -usemacmainmenu 1 \
      -closecommand ::MailBox::CloseHook
    wm title $w [mc Inbox]

    set locals(w) $w
    set jstate(inboxVis) 1
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
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

    set locals(iconWB12) [::Theme::GetImage [option get $w whiteboard12Image {}]]
    set locals(iconWB16) [::Theme::GetImage [option get $w whiteboard16Image {}]]
    
    set locals(iconReadMsg)   [::Theme::GetImage [option get $w readMsgImage {}]]
    set locals(iconUnreadMsg) [::Theme::GetImage [option get $w unreadMsgImage {}]]

    set wtbar $w.frall.tbar
    ::ttoolbar::ttoolbar $wtbar
    pack $wtbar -side top -fill x
    set locals(wtbar) $wtbar

    $wtbar newbutton new  \
      -text [mc New] -image $iconNew -disabledimage $iconNewDis  \
      -command ::NewMsg::Build
    $wtbar newbutton reply  \
      -text [mc Reply] -image $iconReply -disabledimage $iconReplyDis  \
      -command ::MailBox::ReplyTo -state disabled
    $wtbar newbutton forward  \
      -text [mc Forward] -image $iconForward -disabledimage $iconForwardDis  \
      -command ::MailBox::ForwardTo -state disabled
    $wtbar newbutton save  \
      -text [mc Save] -image $iconSave -disabledimage $iconSaveDis  \
      -command ::MailBox::SaveMsg -state disabled
    $wtbar newbutton print  \
      -text [mc Print] -image $iconPrint -disabledimage $iconPrintDis  \
      -command ::MailBox::DoPrint -state disabled
    $wtbar newbutton trash  \
      -text [mc Trash] -image $iconTrash -disabledimage $iconTrashDis  \
      -command ::MailBox::TrashMsg -state disabled
    
    ::hooks::run buildMailBoxButtonTrayHook $wtbar

    # D = 
    ttk::separator $w.frall.divt -orient horizontal
    pack $w.frall.divt -side top -fill x
    
    # D = 
    set wmid $w.frall.mid
    ttk::frame $wmid
    pack $wmid -side top -fill both -expand 1

    # Frame to serve as container for the pane geometry manager.
    # D =
    frame $wmid.ff -bd 0 -highlightthickness 0
    pack  $wmid.ff -side top -fill both -expand 1

    # Pane geometry manager.
    set wpane $wmid.ff.pane
    ttk::paned $wpane -orient vertical
    pack $wpane -side top -fill both -expand 1
    
    # The actual mailbox list as a treectrl.
    set wfrmbox $wpane.frmbox
    frame $wfrmbox -bd 1 -relief sunken
    set wtbl    $wfrmbox.tbl
    set wysctbl $wfrmbox.ysc
	
    ttk::scrollbar $wysctbl -orient vertical -command [list $wtbl yview]	
    TreeCtrl $wtbl $wysctbl
    
    grid  $wtbl     -column 0 -row 0 -sticky news
    grid  $wysctbl  -column 1 -row 0 -sticky ns
    grid columnconfigure $wfrmbox 0 -weight 1
    grid rowconfigure $wfrmbox 0 -weight 1
    
    set i 0
    foreach id [lsort -integer [array names mailbox]] {
	InsertRow $wtbl $mailbox($id) $i
	incr i
    }
    
    # Display message in a text widget.
    set wfrmsg $wpane.frmsg    
    set wtextmsg $wfrmsg.text
    set wyscmsg  $wfrmsg.ysc
    frame $wfrmsg -bd 1 -relief sunken
    text $wtextmsg -height 4 -width 1 -wrap word \
      -yscrollcommand [list ::UI::ScrollSet $wyscmsg \
      [list grid $wyscmsg -column 1 -row 0 -sticky ns]] \
      -state disabled
    $wtextmsg tag configure normal
    ttk::scrollbar $wyscmsg -orient vertical -command [list $wtextmsg yview]

    grid  $wtextmsg  -column 0 -row 0 -sticky news
    grid  $wyscmsg   -column 1 -row 0 -sticky ns
    grid columnconfigure $wfrmsg 0 -weight 1
    grid rowconfigure $wfrmsg 0 -weight 1
    
    $wpane add $wfrmbox -weight 1
    $wpane add $wfrmsg  -weight 1
    
    set locals(wfrmbox)  $wfrmbox
    set locals(wtbl)     $wtbl
    set locals(wtextmsg) $wtextmsg
    set locals(wpane)  $wpane
        
    ::UI::SetWindowGeometry $w
    
    # sashpos unreliable
    #after 10 [list ::UI::SetSashPos $w $wpane]
    wm minsize $w 300 260
    wm maxsize $w 1200 1000
    
    # Add all event hooks.
    if {!$locals(hooksInited)} {
	set locals(hooksInited) 1
	::hooks::register quitAppHook [list ::UI::SaveWinGeom $w]
	::hooks::register quitAppHook [list ::UI::SaveSashPos $w $wpane]
    }
    
    # Grab and focus.
    focus $w
    
    # Make selection available in text widget but not editable!
    # Seems to stop the tablelist from getting focus???
    #$wtextmsg bind <Key> break
    
    # Default sorting.
    HeaderCmd $wtbl cDate
    
    set locals(updateDateid) [after $locals(updateDatems) \
      [list [namespace current]::UpdateDateAndTime $wtbl]]
}

# MailBox::TreeCtrl --
# 
#       Build and configure a treectrl widget.

proc ::MailBox::TreeCtrl {T wysc} {
    global  this
    variable locals  
    variable sortColumn
    
    treectrl $T -usetheme 1 -selectmode extended  \
      -showroot 0 -showrootbutton 0 -showbuttons 0 -showlines 0  \
      -yscrollcommand [list ::UI::ScrollSet $wysc \
      [list grid $wysc -column 1 -row 0 -sticky ns]]  \
      -borderwidth 0 -highlightthickness 0        

    # State for a read message
    $T state define read

    # State for an unread message.
    $T state define unread

    # This is a dummy option.
    set stripeBackground [option get $T stripeBackground {}]
    set stripes [list $stripeBackground {}]
    set bd [option get $T columnBorderWidth {}]
    set bg [option get $T columnBackground {}]

    $T column create -tag cWhiteboard -image $locals(iconWB16)  \
      -itembackground $stripes -resize 0 -borderwidth $bd -background $bg
    $T column create -tag cSubject -expand 1 -text [mc Subject] \
      -itembackground $stripes -button 1 -borderwidth $bd -background $bg
    $T column create -tag cFrom    -expand 1 -text [mc From]    \
      -itembackground $stripes -button 1 -squeeze 1 -borderwidth $bd  \
      -background $bg
    $T column create -tag cDate    -expand 1 -text [mc Date]    \
      -itembackground $stripes -button 1 -arrow up -borderwidth $bd  \
      -background $bg
    $T column create -tag cSecs -visible 0
    $T column create -tag cRead -visible 0
    $T column create -tag cUid  -visible 0

    set fill    [list $this(sysHighlight) {selected focus} gray {selected !focus}]
    set fillT   {white {selected focus} black {selected !focus}}
    set suImage [list $locals(iconReadMsg) {read} $locals(iconUnreadMsg) {unread}]
    set suFont  [list CociSmallFont read CociSmallBoldFont unread]
    
    $T element create eBorder rect -open new -outline gray -outlinewidth 1 \
      -fill $fill -showfocus 1
    $T element create eText     text -lines 1 -font $suFont -fill $fillT
    $T element create eImageEye image -image $suImage
    $T element create eImageWb  image
    
    set S [$T style create styText]
    $T style elements $S {eBorder eText}
    $T style layout $S eBorder -detach yes -iexpand xy
    $T style layout $S eText -padx 4 -squeeze x -expand ns -ipady 2
    
    set S [$T style create styImage]
    $T style elements $S {eBorder eImageWb}
    $T style layout $S eBorder -detach yes -iexpand xy
    $T style layout $S eImageWb -padx 4 -squeeze x -expand ns

    set S [$T style create stySubject]
    $T style elements $S {eBorder eImageEye eText}
    $T style layout $S eBorder -detach yes -iexpand xy
    $T style layout $S eImageEye -padx 4 -squeeze x -expand ns
    $T style layout $S eText -padx 4 -squeeze x -expand ns -ipady 2

    set S [$T style create styTag]
    $T style elements $S {eText}
    
    $T configure -defaultstyle {styImage stySubject styText styText  \
      styTag styTag styTag}

    $T notify install <Header-invoke>
    $T notify bind $T <Header-invoke> [list [namespace current]::HeaderCmd %T %C]
    $T notify bind $T <Selection> [list [namespace current]::Selection %T]
    bind $T <Double-1>            [list [namespace current]::DoubleClickMsg %W]
    bind $T <KeyPress-BackSpace>  [namespace current]::TrashMsg
    
    set sortColumn 0
}

# MailBox::InsertRow --
#
#       Does the actual job of adding a line in the mailbox widget.

proc ::MailBox::InsertRow {wtbl row i} {
    
    variable mailboxindex
    variable locals
    variable tableUid2Item
    
    # row:   {subject from date isread uidmsg message ?-key value ...?}
    
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
    set secs    [clock scan $date]
    set smartdate [::Utils::SmartClockFormat $secs -showsecs 0]

    set T $wtbl
    set item [$T item create]
    $T item text $item  \
      cSubject $subject cFrom $from   cDate $smartdate  \
      cSecs    $secs    cRead $isread cUid  $uidmsg
    $T item lastchild root $item
    
    if {$haswb} {
	$T item element configure $item cWhiteboard eImageWb  \
	  -image $locals(iconWB12)
    }
    if {$isread} {
	$T item state set $item read
    } else {
	$T item state set $item unread
    }
    set tableUid2Item($uidmsg) $item
}

# MailBox::Selection --
# 
#       Callback for treectrl <Selection>
       
proc ::MailBox::Selection {T} {
    variable locals
    variable mailbox
    
    set wtextmsg $locals(wtextmsg)
    set wtbl     $locals(wtbl)
    set w        $locals(w)
    set wtbar    $locals(wtbar)
    
    set n [$T selection count]

    if {$n == 0} {
	$wtbar buttonconfigure reply   -state disabled
	$wtbar buttonconfigure forward -state disabled
	$wtbar buttonconfigure save    -state disabled
	$wtbar buttonconfigure print   -state disabled
	$wtbar buttonconfigure trash   -state disabled
	MsgDisplayClear
    } elseif {$n == 1} {
	set item [$T selection get]
	set jid3 [$T item element cget $item cFrom eText -text]
	set uid  [$T item element cget $item cUid  eText -text]
	jlib::splitjid $jid3 jid2 res
		
	DisplayMsg $uid
	
	# Configure buttons.
	$wtbar buttonconfigure reply   -state normal
	$wtbar buttonconfigure forward -state normal
	$wtbar buttonconfigure save    -state normal
	$wtbar buttonconfigure print   -state normal
	$wtbar buttonconfigure trash   -state normal
	
	# If any whiteboard stuff in message...
	set uidcan [GetCanvasHexUID $uid]
	set svgElem [GetAnySVGElements $mailbox($uid)]

	::Debug 2 "::MailBox::Selection  uidcan=$uidcan, svgElem='$svgElem'"
	 
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
    } else {
	
	# If multiple selected items.
	$wtbar buttonconfigure reply   -state disabled
	$wtbar buttonconfigure forward -state disabled
	$wtbar buttonconfigure save    -state disabled
	$wtbar buttonconfigure print   -state disabled
	MsgDisplayClear
    }
}

proc ::MailBox::HeaderCmd {T C} {
    variable sortColumn
        
    if {[$T column compare $C == $sortColumn]} {
	if {[$T column cget $sortColumn -arrow] eq "down"} {
	    set order -increasing
	    set arrow up
	} else {
	    set order -decreasing
	    set arrow down
	}
    } else {
	if {[$T column cget $sortColumn -arrow] eq "down"} {
	    set order -decreasing
	    set arrow down
	} else {
	    set order -increasing
	    set arrow up
	}
	$T column configure $sortColumn -arrow none
	set sortColumn $C
    }
    $T column configure $C -arrow $arrow
    
    switch [$T column cget $C -tag] {
	cWhiteboard {
	    # empty
	}
	cDate {
	    set cmd [list [namespace current]::SortDate $T]
	    $T item sort root $order -column $C -command $cmd
	}
	default {
	    $T item sort root $order -column $C -dictionary
	}
    }
    return
}

proc ::MailBox::SortDate {T item1 item2} {
    
    set secs1 [$T item element cget $item1 cSecs eText -text]
    set secs2 [$T item element cget $item2 cSecs eText -text]
    
    if {$secs1 > $secs2} {
	return 1
    } elseif {$secs1 == $secs2} {
	return 0
    } else {
	return -1
    }
}

proc ::MailBox::UpdateDateAndTime {T} {
    
    variable mailbox
    variable mailboxindex
    variable locals
    
    foreach item [$T item children root] {
	set uid  [$T item element cget $item cUid eText -text]
	set secs [$T item element cget $item cSecs eText -text]
	set smartdate [::Utils::SmartClockFormat $secs -showsecs 0]
	$T item element configure $item cDate eText -text $smartdate
    }
    
    # Reschedule ourselves.
    set locals(updateDateid) [after $locals(updateDatems) \
      [list [namespace current]::UpdateDateAndTime $T]]
}

proc ::MailBox::DisplayMessageHook {body args} {

    array set argsArr $args
    if {[info exists argsArr(-msgid)]} {
	MarkMsgAsRead $argsArr(-msgid)
    }
}

proc ::MailBox::MarkMsgAsRead {uid} {
    global  wDlgs
    variable mailbox
    variable mailboxindex
    variable locals
    variable tableUid2Item
    
    if {[lindex $mailbox($uid) $mailboxindex(isread)] == 0} {
	lset mailbox($uid) $mailboxindex(isread) 1
	
	if {[winfo exists $wDlgs(jinbox)]} {
	    set T $locals(wtbl)
	    set item $tableUid2Item($uid)
	    $T item state set $item read
	}
	set locals(haveEdits) 1
    }
}

proc ::MailBox::CloseHook {wclose} {
    
    set result ""
    ShowHide -visible 0
    return stop
}

proc ::MailBox::GetToplevel { } {    
    variable locals
    
    if {[info exists locals(w)] && [winfo exists $locals(w)]} {
	return $locals(w)
    } else {
	return {}
    }
}

# Various accessor functions.

proc ::MailBox::Get {id key} {
    variable mailbox
    variable mailboxindex
    
    return [lindex $mailbox($id) $mailboxindex($key)]
}

proc ::MailBox::Set {id key value} {
    variable mailbox
    variable mailboxindex
    
    lset mailbox($id) $mailboxindex($key) $value
}

proc ::MailBox::IsLastMessage {id} {
    variable mailbox

    set sorted [lsort -integer [array names mailbox]]
    return [expr ($id >= [lindex $sorted end]) ? 1 : 0]
}

proc ::MailBox::AllRead { } {
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

proc ::MailBox::GetNextMsgID {id} {
    variable mailbox

    set nextid $id
    set sorted [lsort -integer [array names mailbox]]
    set ind [lsearch $sorted $id]
    if {($ind >= 0) && ([expr $ind + 1] < [llength $sorted])} {
	set next [lindex $sorted [incr ind]]
    }
    return $next
}

proc ::MailBox::GetMsgFromUid {id} {
    variable mailbox
    
    if {[info exists mailbox($id)]} {
	return $mailbox($id)
    } else {
	return {}
    }
}

# MailBox::GetCanvasHexUID --
#
#       Returns the unique hex id for canvas if message has any, else empty.

proc ::MailBox::GetCanvasHexUID {id} {
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

# MailBox::MessageHook --
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

proc ::MailBox::MessageHook {bodytxt args} {
    global  prefs

    variable locals
    variable mailbox
    variable uidmsg
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::MailBox::MessageHook bodytxt='$bodytxt', args='$args'"

    array set argsArr $args
    
    # Ignore messages with empty body and subject. 
    # They are probably not for display.
    if {$bodytxt eq ""} {
	if {![info exists argsArr(-subject)]} {
	    return
	}
	if {$argsArr(-subject) eq ""} {
	    return
	}
    }
    
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
    if {$w ne ""} {
	set wtbl $locals(wtbl)
	InsertRow $wtbl $mailbox($uidmsg) end
	$wtbl see end
    }
    ::Jabber::UI::MailBoxState nonempty
    
    # Any separate window.
    # @@@ as hook instead
    if {$jprefs(showMsgNewWin) && ($bodytxt ne "")} {
	::GotMsg::GotMsg $uidmsg
    }
}

# MailBox::HandleRawWBMessage --
# 
#       Same as above, but for raw whiteboard messages.

proc ::MailBox::HandleRawWBMessage {jlibname xmlns msgElem args} {
    global  prefs this

    variable mailbox
    variable uidmsg
    variable locals
    
    ::Debug 2 "::MailBox::HandleRawWBMessage args=$args"
    array set argsArr $args
    if {![info exists argsArr(-x)]} {
	return
    }
	
    # The inbox should only be read once to be economical.
    if {!$locals(mailboxRead)} {
	ReadMailbox
    }
    set messageList [eval {MakeMessageList ""} $args]
    set rawList     [::Jabber::WB::GetRawCanvasMessageList $argsArr(-x) $xmlns]
    set canvasuid   [uuid::uuid generate]
    set filePath    [file join $this(inboxCanvasPath) $canvasuid.can]
    ::CanvasFile::DataToFile $filePath $rawList
    lappend messageList -canvasuid $canvasuid
    set mailbox($uidmsg) $messageList
    PutMessageInInbox $messageList

    # Show in mailbox.
    set w [GetToplevel]
    if {$w != ""} {
	set wtbl $locals(wtbl)
	InsertRow $wtbl $mailbox($uidmsg) end
	$wtbl see end
    }
    ::Jabber::UI::MailBoxState nonempty
    
    eval {::hooks::run newWBMessageHook} $args

    # We have handled this message completely.
    return 1
}

# MailBox::HandleSVGWBMessage --
# 
#       As above but for SVG whiteboard messages.

proc ::MailBox::HandleSVGWBMessage {jlibname xmlns msgElem args} {
    global  prefs

    variable mailbox
    variable uidmsg
    variable locals
    
    ::Debug 2 "::MailBox::HandleSVGWBMessage args='$args'"
    array set argsArr $args
    if {![info exists argsArr(-x)]} {
	return
    }
	
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
	set wtbl $locals(wtbl)
	InsertRow $wtbl $mailbox($uidmsg) end
	$wtbl see end
    }
    ::Jabber::UI::MailBoxState nonempty
    
    eval {::hooks::run newWBMessageHook} $args

    # We have handled this message completely.
    return 1
}

proc ::MailBox::MakeMessageList {body args} {
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

proc ::MailBox::PutMessageInInbox {row} {
    global  this
    
    set exists 0
    if {[file exists $this(inboxFile)]} {
	set exists 1
    }
    if {![catch {open $this(inboxFile) a} fd]} {
	#fconfigure $fd -encoding utf-8
	if {!$exists} {
	    WriteInboxHeader $fd
	    if {[string equal $this(platform) "macintosh"]} {
		file attributes $this(inboxFile) -type pref
	    }
	}
	puts $fd "set mailbox(\[incr uidmsg]) {$row}"
	close $fd
    }
}

proc ::MailBox::SaveMsg { } {    
    variable locals
    
    set wtextmsg $locals(wtextmsg)
    set T $locals(wtbl)
    
    # Need selected line here.
    if {[$T selection count] != 1} {
	return
    }
    set item [$T selection get]
    set from [$T item element cget $item cFrom eText -text]
    jlib::splitjid $from jid2 res
    
    set ans [tk_getSaveFile -title {Save message} -initialfile $jid2.txt]
    if {[string length $ans]} {
	if {[catch {open $ans w} fd]} {
	    ::UI::MessageBox -title {Open Failed} -parent $wtbl -type ok \
	      -message "Failed opening file [file tail $ans]: $fd"
	    return
	}
	#fconfigure $fd -encoding utf-8
	set subject [$T item element cget $item cSubject eText -text]
	set secs    [$T item element cget $item cSecs eText -text]
	set date [::Utils::SmartClockFormat $secs -showsecs 0]
	set maxw 14
	puts $fd [format "%-*s %s" $maxw "From:" $from]
	puts $fd [format "%-*s %s" $maxw "Subject:" $subject]
	puts $fd [format "%-*s %s" $maxw "Time:" $date]
	puts $fd "\n"
	puts $fd [::Text::TransformToPureText $wtextmsg]
	close $fd
    }
}

proc ::MailBox::TrashMsg { } {
    global  prefs this
    
    variable locals
    variable mailbox
    
    set locals(haveEdits) 1
    set T $locals(wtbl)
    
    if {![$T selection count]} {
	return
    }
    set items [$T selection get]
    set select [$T item id "root lastchild"]
    
    foreach item $items {
	set uid  [$T item element cget $item cUid eText -text]
	set cuid [GetCanvasHexUID $uid]
	if {$cuid ne ""} {
	    set fileName $cuid.can
	    set filePath [file join $this(inboxCanvasPath) $fileName]
	    catch {file delete $filePath}
	}
	unset mailbox($uid)
	set select [$T item id "$item below"]
	if {$select eq ""} {
	    set select [$T item id "$item above"]
	}
	$T item delete $item
    }

    # Make new selection if not empty. Root item included!
    if {[$T item count] == 1} {
	set wtbar $locals(wtbar)

	$wtbar buttonconfigure reply   -state disabled
	$wtbar buttonconfigure forward -state disabled
	$wtbar buttonconfigure save    -state disabled
	$wtbar buttonconfigure print   -state disabled
	$wtbar buttonconfigure trash   -state disabled
	MsgDisplayClear
	::Jabber::UI::MailBoxState empty
    } elseif {$select ne ""} {
	$T selection add $select
    }
}

proc ::MailBox::GetAnySVGElements {row} {
    
    set svgElem {}
    set idx [lsearch $row -x]
    if {$idx > 0} {
	set xlist [lindex $row [expr $idx+1]]
	set svgElem [wrapper::getnamespacefromchilds $xlist x \
	  "http://jabber.org/protocol/svgwb"]
    }
    return $svgElem
}

# MailBox::DisplayRawMessage --
# 
#       Displays a raw whiteboard message when selected in inbox.

proc ::MailBox::DisplayRawMessage {jid3 uid} {
    global  prefs this wDlgs

    variable mailbox
    upvar ::Jabber::jstate jstate
    
    jlib::splitjid $jid3 jid2 res
    set w [MakeWhiteboard $jid2]
    
    # Only if user available shall we try to import.
    set tryimport 0
    if {[$jstate(roster) isavailable $jid3] || \
      [jlib::jidequal $jid3 $jstate(mejidres)]} {
	set tryimport 1
    }
	    
    set fileName ${uid}.can
    set filePath [file join $this(inboxCanvasPath) $fileName]
    set numImports [::CanvasFile::DrawCanvasItemFromFile $w \
      $filePath -where local -tryimport $tryimport]
    if {!$tryimport && $numImports > 0} {
	
	# Perhaps we shall inform the user that no binary entities
	# could be obtained.
	::UI::MessageBox -type ok -title {Missing Entities}  \
	  -icon info -message "There were $numImports images or\
	  similar entities that could not be obtained because the user\
	  is not online."
    }
}

proc ::MailBox::DisplayXElementSVG {jid3 xlist} {
    global  prefs wDlgs

    variable mailbox
    upvar ::Jabber::jstate jstate
    ::Debug 2 "::MailBox::DisplayXElementSVG jid3=$jid3"
    
    jlib::splitjid $jid3 jid2 res
    
    set w [MakeWhiteboard $jid2]
    
    # Only if user available shall we try to import.
    set tryimport 0
    if {[$jstate(roster) isavailable $jid3] || \
      [jlib::jidequal $jid3 $jstate(mejidres)]} {
	set tryimport 1
    }

    set cmdList [::Jabber::WB::GetSVGWBMessageList $w $xlist]
    foreach line $cmdList {
	::CanvasUtils::HandleCanvasDraw $w $line -tryimport $tryimport
    }         
}

# MailBox::MakeWhiteboard --
# 
#       Creates or configures the inbox whiteboard window.

proc ::MailBox::MakeWhiteboard {jid2} {
    global  prefs wDlgs
    
    set w    $wDlgs(jwbinbox)
    set title "Inbox: $jid2"
    
    if {[winfo exists $w]} {
	::Import::HttpResetAll  $w
	::CanvasCmd::EraseAll   $w
	::WB::ConfigureMain     $w -title $title	    
	::WB::SetStatusMessage  $w ""
	::Jabber::WB::Configure $w -jid $jid2
	undo::reset [::WB::GetUndoToken $w]
    } else {
	::Jabber::WB::NewWhiteboard -w $w -state disabled \
	  -title $title -jid $jid2 -usewingeom 1
    }
    return $w
}

proc ::MailBox::DoubleClickMsg {T} {
    variable locals
    variable mailbox
    variable mailboxindex
    upvar ::Jabber::jprefs jprefs
        
    if {[$T selection count] != 1} {
	return
    }
    set item [$T selection get]
    set uid  [$T item element cget $item cUid eText -text]

    # We shall have the original, unparsed, text here.
    set body    [lindex $mailbox($uid) $mailboxindex(message)]
    set subject [lindex $mailbox($uid) $mailboxindex(subject)]
    set to      [lindex $mailbox($uid) $mailboxindex(from)]
    set date    [lindex $mailbox($uid) $mailboxindex(date)]
    
    if {[string equal $jprefs(inbox2click) "newwin"]} {
	::GotMsg::GotMsg $uid
    } elseif {[string equal $jprefs(inbox2click) "reply"]} {
	if {![regexp -nocase {^ *re:} $subject]} {
	    set subject "Re: $subject"
	}	
	::NewMsg::Build -to $to -subject $subject  \
	  -quotemessage $body -time $date
    }
}

proc ::MailBox::MsgDisplayClear { } {    
    variable locals
    
    set wtextmsg $locals(wtextmsg)    
    $wtextmsg configure -state normal
    $wtextmsg delete 1.0 end
    $wtextmsg configure -state disabled
}

proc ::MailBox::DisplayMsg {id} {
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
    $wtextmsg mark set insert end
    ::Text::ParseMsg normal $from $wtextmsg $body normal
    $wtextmsg insert end \n
    $wtextmsg configure -state disabled
    
    # This hook triggers 'MarkMsgAsRead'.
    set opts [list -subject $subject -from $from -time $date -msgid $id]
    eval {::hooks::run displayMessageHook $body} $opts
}

proc ::MailBox::ReplyTo { } {
    variable locals
    variable mailbox
    variable mailboxindex
    upvar ::Jabber::jstate jstate
    
    set T $locals(wtbl)
    if {[$T selection count] != 1} {
	return
    }
    set item [$T selection get]
    set uid  [$T item element cget $item cUid eText -text]

    # We shall have the original, unparsed, text here.
    set subject [lindex $mailbox($uid) $mailboxindex(subject)]
    set from    [lindex $mailbox($uid) $mailboxindex(from)]
    set date    [lindex $mailbox($uid) $mailboxindex(date)]
    set body    [lindex $mailbox($uid) $mailboxindex(message)]
    
    set to [::Jabber::JlibCmd getrecipientjid $from]
    if {![regexp -nocase {^ *re:} $subject]} {
	set subject "Re: $subject"
    }
    ::NewMsg::Build -to $to -subject $subject  \
      -quotemessage $body -time $date
}

proc ::MailBox::ForwardTo { } {
    variable locals
    variable mailbox
    variable mailboxindex
    
    set T $locals(wtbl)
    if {[$T selection count] != 1} {
	return
    }
    set item [$T selection get]
    set uid  [$T item element cget $item cUid eText -text]

    # We shall have the original, unparsed, text here.
    set subject [lindex $mailbox($uid) $mailboxindex(subject)]
    set from    [lindex $mailbox($uid) $mailboxindex(from)]
    set date    [lindex $mailbox($uid) $mailboxindex(date)]
    set body    [lindex $mailbox($uid) $mailboxindex(message)]

    set subject "Forwarded: $subject"
    ::NewMsg::Build -subject $subject -forwardmessage $body -time $date
}

proc ::MailBox::DoPrint { } {

    variable locals

    set allText [::Text::TransformToPureText $locals(wtextmsg)]
    
    ::UserActions::DoPrintText $locals(wtextmsg)  \
      -data $allText -font CociSmallFont
}

proc ::MailBox::SaveMailbox {args} {

    eval {SaveMailboxVer2} $args
}
    
proc ::MailBox::SaveMailboxVer1 { } {
    global  this
    
    variable locals
    variable mailbox
    
    # Do not store anything if empty.
    if {[llength [array names mailbox]] == 0} {
	return
    }
    
    # Work on a temporary file and switch later.
    set tmpFile $this(inboxFile).tmp
    if {[catch {open $tmpFile w} fid]} {
	::UI::MessageBox -type ok -icon error \
	  -message [mc jamesserrinboxopen $tmpFile]
	return
    }
    #fconfigure $fid -encoding utf-8
    
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
    if {[catch {file rename -force $tmpFile $this(inboxFile)} msg]} {
	::UI::MessageBox -type ok -message {Error renaming preferences file.}  \
	  -icon error
	return
    }
    if {[string equal $this(platform) "macintosh"]} {
	file attributes $this(inboxFile) -type pref
    }
}

# MailBox::SaveMailboxVer2 --
# 
#       Saves current mailbox to the inbox file provided it is necessary.
#       
# Arguments:
#       args:       -force 0|1 (D=0) forces save unconditionally
#       

proc ::MailBox::SaveMailboxVer2 {args} {
    global  this
    
    variable mailbox
    variable locals
    
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
    ::Debug 2 "::MailBox::SaveMailboxVer2 args=$args"
    if {$locals(mailboxRead)} {

	# Be sure to not have any inbox that is empty.
	if {[llength [array names mailbox]] == 0} {
	    catch {file delete $this(inboxFile)}
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
    set tmpFile $this(inboxFile).tmp
    if {[catch {open $tmpFile w} fid]} {
	::UI::MessageBox -type ok -icon error \
	  -message [mc jamesserrinboxopen $tmpFile]
	return
    }
    #fconfigure $fid -encoding utf-8
    
    # Start by writing the header info.
    WriteInboxHeader $fid
    foreach id [lsort -integer [array names mailbox]] {
	puts $fid "set mailbox(\[incr uidmsg]) {$mailbox($id)}"
    }
    close $fid
    if {[catch {file rename -force $tmpFile $this(inboxFile)} msg]} {
	::UI::MessageBox -type ok -message {Error renaming preferences file.}  \
	  -icon error
	return
    }
    if {[string equal $this(platform) "macintosh"]} {
	file attributes $this(inboxFile) -type pref
    }
}

proc ::MailBox::WriteInboxHeader {fid} {
    global  prefs
    
    # Header information.
    puts $fid "# Version: 2"
    puts $fid "#\n#   User's Jabber Message Box for $prefs(theAppName)."
    puts $fid "#   The data written at: [clock format [clock seconds]]\n#"    
}

proc ::MailBox::ReadMailbox { } {
    global  this
    variable locals

    # Set this even if not there.
    set locals(mailboxRead) 1
    if {[file exists $this(inboxFile)]} {
	ReadMailboxVer2
    }
}

proc ::MailBox::TranslateAnyVer1ToCurrentVer { } {
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

# MailBox::GetMailboxVersion --
# 
#       Returns empty string if no mailbox exists, else the version number of
#       any existing mailbox.

proc ::MailBox::GetMailboxVersion { } {
    global  this
    
    set version ""
    if {[file exist $this(inboxFile)]} {
	if {![catch {open $this(inboxFile) r} fd]} {
	    #fconfigure $fd -encoding utf-8
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

proc ::MailBox::ReadMailboxVer1 { } {
    global  this
    variable locals
    variable uidmsg
    variable mailbox
    
    ::Debug 2 "::MailBox::ReadMailboxVer1"

    if {[catch {source $this(inboxFile)} msg]} {
	set tail [file tail $this(inboxFile)]
	::UI::MessageBox -title [mc {Mailbox Error}] -icon error  \
	  -type ok -message [mc jamesserrinboxread $tail $msg]
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

proc ::MailBox::ReadMailboxVer2 { } {
    global  this
    variable locals
    variable uidmsg
    variable mailbox
    variable mailboxindex

    ::Debug 2 "::MailBox::ReadMailboxVer2"

    if {[catch {source $this(inboxFile)} msg]} {
	set tail [file tail $this(inboxFile)]
	::UI::MessageBox -title [mc {Mailbox Error}] -icon error  \
	  -type ok -message [mc jamesserrinboxread $tail $msg]
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

proc ::MailBox::HaveMailBox { } {
    global  this

    if {[file exist $this(inboxFile)]} {
	set ans 1
    } else {
	set ans 0
    }
    return $ans
}

proc ::MailBox::DeleteMailbox { } {
    global prefs this

    if {[file exist $this(inboxFile)]} {
	catch {file delete $this(inboxFile)}
    }    
    foreach f [glob -nocomplain -directory $this(inboxCanvasPath) *.can] {
	catch {file delete $f}
    }
}

proc ::MailBox::QuitHook { } {
    global wDlgs
    upvar ::Jabber::jprefs jprefs
    variable locals
    
    if {[winfo exists $wDlgs(jinbox)] && [winfo ismapped $wDlgs(jinbox)]} {
	set jprefs(mailbox,dialog) 1
    } else {
	set jprefs(mailbox,dialog) 0
    }
    
    if {$jprefs(inboxSave)} {
	if {$locals(haveEdits)} {
	    SaveMailbox
	}
    } else {
	DeleteMailbox
    }
}


#-------------------------------------------------------------------------------
