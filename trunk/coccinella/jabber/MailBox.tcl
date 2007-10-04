#  MailBox.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements a mailbox for jabber messages.
#      
#  Copyright (c) 2002-2007  Mats Bengtsson
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
# $Id: MailBox.tcl,v 1.126 2007-10-04 06:55:28 matben Exp $

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
# 
# UPDATE: Now using a metakit database for storing all messages as they are
#         received, see below.
#         We keep both storage systems parallell for a while which creates
#         a conflict between uuid as generated, and the uidmsg for mailbox
#         array which is a running integer number.

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
    ::hooks::register prefsFilePathChangedHook  ::MailBox::PrefsFilePathHook

    variable locals
    
    set locals(inited)        0
    set locals(mailboxRead)   0
    set locals(haveEdits)     0
    set locals(hooksInited)   0
    set locals(updateDateid)  ""
    set locals(updateDatems)  [expr {1000*60}]
    
    set locals(w)    -
    set locals(wtbl) -
    
    # Running id for incoming messages; never reused.
    variable uidmsg 1000
    
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
    
    variable xmlns
    set xmlns(svg) "http://jabber.org/protocol/svgwb"
}

# MailBox::Init --
# 
#       Take care of things like translating any old version mailbox etc.

proc ::MailBox::Init {} {    
    variable locals
    variable icons
   
    TranslateAnyVer1ToCurrentVer
    
    set locals(inited) 1
}

proc ::MailBox::InitPrefsHook {} {
    upvar ::Jabber::jprefs jprefs
        
    set jprefs(mailbox,dialog) 0
    
    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(mailbox,dialog)  jprefs_mailbox_dialog  $jprefs(mailbox,dialog)]  \
      ]
}

proc ::MailBox::InitHandler {jlibName} {
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::coccixmlns coccixmlns
    variable xmlns
    
    # Register for the whiteboard messages we want. Duplicate protocols.
    if {[::Jabber::HaveWhiteboard]} {
	$jstate(jlib) message_register normal coccinella:wb  \
	  [namespace current]::HandleRawWBMessage
	$jstate(jlib) message_register normal $coccixmlns(whiteboard)  \
	  [namespace current]::HandleRawWBMessage
	$jstate(jlib) message_register normal $xmlns(svg) \
	  [namespace current]::HandleSVGWBMessage
    }
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
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 4 "::MailBox::MessageHook bodytxt='$bodytxt', args='$args'"

    array set argsA $args
    set xmldata $argsA(-xmldata)
    set uuid $argsA(-uuid)
    
    set xdataE [wrapper::getfirstchild $xmldata x "jabber:x:data"]
    set haveSubject 0
    if {[info exists argsA(-subject)] && [string length $argsA(-subject)]} {
	set haveSubject 1
    }    
	
    # Ignore messages with empty body, subject or no xdata form. 
    # They are probably not for display.
    if {($bodytxt eq "") && !$haveSubject && ![llength $xdataE]} {
	return
    }
    
    # Non whiteboard 'normal' messages treated as chat messages.
    if {$jprefs(chat,normalAsChat)} {
	return
    }
    
    # The inbox should only be read once to be economical.
    if {!$locals(mailboxRead)} {
	ReadMailbox
    }

    # Show in mailbox. Sorting?
    set w [GetToplevel]
    set wtbl $locals(wtbl)
    
    if {[MKHaveMetakit]} {
	set stamp [::Jabber::GetDelayStamp $xmldata]
	if {$stamp ne ""} {
	    set secs [clock scan $stamp -gmt 1]
	} else {
	    set secs [clock seconds]
	}
	set time [clock format $secs -format "%Y%m%dT%H:%M:%S"]
	MKAdd $uuid $time 0 $xmldata ""
	if {$w ne ""} {
	    MKInsertRow $uuid $time 0 $xmldata ""
	}
	set idxuuid $uuid
    } else {
	set bodytxt [string trimright $bodytxt "\n"]
	set messageList [eval {MakeMessageList $bodytxt} $args]    
	
	# All messages cached in 'mailbox' array.
	set mailbox($uidmsg) $messageList
	
	# Always cache it in inbox.
	PutMessageInInbox $messageList
	if {$w ne ""} {
	    InsertRow $wtbl $mailbox($uidmsg) end
	}
	set idxuuid $uidmsg
    }    
    if {$w ne ""} {
	$wtbl see end
    }
    ::JUI::MailBoxState nonempty

    # @@@ as hook instead when solved the uuid vs. uidmsg mixup!
    if {$jprefs(showMsgNewWin) && ($bodytxt ne "")} {
	::GotMsg::GotMsg $idxuuid
    }
}

# MailBox::HandleRawWBMessage --
# 
#       Same as above, but for raw whiteboard messages.

proc ::MailBox::HandleRawWBMessage {jlibname xmlns xmldata args} {
    global  prefs this

    variable mailbox
    variable uidmsg
    variable locals
    
    ::Debug 2 "::MailBox::HandleRawWBMessage args=$args"
    array set argsA $args
    if {![info exists argsA(-x)]} {
	return
    }
    
    # We get this message from jlib and need therefore to generate a uuid.
    set uuid [uuid::uuid generate]
	
    # The inbox should only be read once to be economical.
    if {!$locals(mailboxRead)} {
	ReadMailbox
    }
    
    # Show in mailbox.
    set w [GetToplevel]
    set wtbl $locals(wtbl)

    set rawList  [::JWB::GetRawCanvasMessageList $argsA(-x) $xmlns]
    set filePath [file join $this(inboxCanvasPath) $uuid.can]
    ::CanvasFile::DataToFile $filePath $rawList

    if {[MKHaveMetakit]} {
	set stamp [::Jabber::GetDelayStamp $xmldata]
	if {$stamp ne ""} {
	    set secs [clock scan $stamp -gmt 1]
	} else {
	    set secs [clock seconds]
	}
	set time [clock format $secs -format "%Y%m%dT%H:%M:%S"]
	
	# @@@ This will be duplicate storage!
	MKAdd $uuid $time 0 $xmldata $uuid.can
	if {$w ne ""} {
	    MKInsertRow $uuid $time 0 $xmldata $uuid.can
	}
    } else {
	set messageList [eval {MakeMessageList ""} $args]
	lappend messageList -canvasuid $uuid
	set mailbox($uidmsg) $messageList
	PutMessageInInbox $messageList
	if {$w ne ""} {
	    InsertRow $wtbl $mailbox($uidmsg) end
	}
    }
    if {$w ne ""} {
	$wtbl see end
    }
    ::JUI::MailBoxState nonempty
    
    eval {::hooks::run newWBMessageHook} $args

    # We have handled this message completely.
    return 1
}

# MailBox::HandleSVGWBMessage --
# 
#       As above but for SVG whiteboard messages.

proc ::MailBox::HandleSVGWBMessage {jlibname xmlns xmldata args} {
    global  prefs

    variable mailbox
    variable uidmsg
    variable locals
    
    ::Debug 2 "::MailBox::HandleSVGWBMessage args='$args'"
    array set argsA $args
    if {![info exists argsA(-x)]} {
	return
    }
    
    # We get this message from jlib and need therefore to generate a uuid.
    set uuid [uuid::uuid generate]
	
    # The inbox should only be read once to be economical.
    if {!$locals(mailboxRead)} {
	ReadMailbox
    }
    set w [GetToplevel]
    set wtbl $locals(wtbl)

    if {[MKHaveMetakit]} {
	set stamp [::Jabber::GetDelayStamp $xmldata]
	if {$stamp ne ""} {
	    set secs [clock scan $stamp -gmt 1]
	} else {
	    set secs [clock seconds]
	}
	set time [clock format $secs -format "%Y%m%dT%H:%M:%S"]
	MKAdd $uuid $time 0 $xmldata ""
	if {$w ne ""} {
	    MKInsertRow $uuid $time 0 $xmldata ""
	}
    } else {
	set messageList [eval {MakeMessageList ""} $args]

	# Store svg in x element.
	lappend messageList -x $argsA(-x)
	
	set mailbox($uidmsg) $messageList
	PutMessageInInbox $messageList
	if {$w ne ""} {
	    InsertRow $wtbl $mailbox($uidmsg) end
	}
    }
    if {$w ne ""} {
	$wtbl see end
    }
    ::JUI::MailBoxState nonempty
    
    eval {::hooks::run newWBMessageHook} $args

    # We have handled this message completely.
    return 1
}

proc ::MailBox::LaunchHook {} {
    upvar ::Jabber::jprefs jprefs
    
    if {$jprefs(rememberDialogs) && $jprefs(mailbox,dialog)} {
	ShowHide -visible 1
    }
}

proc ::MailBox::OnMenu {} {
    if {[llength [grab current]]} { return }
    ShowHide
}

proc ::MailBox::IsVisible {} {
    global wDlgs

    set w $wDlgs(jinbox)
    if {[winfo exists $w] && [winfo ismapped $w]} {
	return 1
    } else {
	return 0
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

    array set argsA $args
    set w $wDlgs(jinbox)
    
    if {[info exists argsA(-visible)]} {
	set visible $argsA(-visible)
    }
    if {![winfo exists $w]} {
	
	# First time we are being called.
	Build
    } else {
	set ismapped [winfo ismapped $w]
	set targetstate [expr $ismapped ? 0 : 1]
	if {[info exists argsA(-visible)]} {
	    set targetstate $argsA(-visible)
	}
	if {$targetstate} {
	    catch {wm deiconify $w}
	    raise $w
	} else {
	    catch {wm withdraw $w}
	}
    }
}

# MailBox::Build --
# 
#       Creates the inbox window.

proc ::MailBox::Build {args} {
    global  this prefs wDlgs config
    
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
      -text [mc Message] -image $iconNew -disabledimage $iconNewDis  \
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
      -text [mc Delete] -image $iconTrash -disabledimage $iconTrashDis  \
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
    
    # Display message in a text widget.
    set wfrmsg $wpane.frmsg    
    set wtextmsg $wfrmsg.text
    set wyscmsg  $wfrmsg.ysc
    
    if {$config(ui,aqua-text)} {
	frame $wfrmsg
	set wcont [::UI::Text $wtextmsg -height 4 -width 1 -wrap word \
	  -yscrollcommand [list ::UI::ScrollSet $wyscmsg \
	  [list grid $wyscmsg -column 1 -row 0 -sticky ns]] \
	  -state disabled]
    } else {
	frame $wfrmsg -bd 1 -relief sunken
	text $wtextmsg -height 4 -width 1 -wrap word \
	  -yscrollcommand [list ::UI::ScrollSet $wyscmsg \
	  [list grid $wyscmsg -column 1 -row 0 -sticky ns]] \
	  -state disabled
	set wcont $wtextmsg
    }
    $wtextmsg tag configure normal
    $wtextmsg tag configure xdata -foreground red
    bindtags $wtextmsg [linsert [bindtags $wtextmsg] 0 ReadOnlyText]
    ttk::scrollbar $wyscmsg -orient vertical -command [list $wtextmsg yview]

    grid  $wcont    -column 0 -row 0 -sticky news
    grid  $wyscmsg  -column 1 -row 0 -sticky ns
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
    
    InsertAll
    
    # Default sorting.
    HeaderCmd $wtbl cDate
    
    set locals(updateDateid) [after $locals(updateDatems) \
      [list [namespace current]::UpdateDateAndTime $wtbl]]
    
    bind $wtbl <Destroy> +[namespace code OnDestroyTree]
}

# MailBox::TreeCtrl --
# 
#       Build and configure a treectrl widget.

proc ::MailBox::TreeCtrl {T wysc} {
    global  this
    variable locals  
    variable sortColumn
    
    treectrl $T -selectmode extended  \
      -showroot 0 -showrootbutton 0 -showbuttons 0 -showlines 0  \
      -yscrollcommand [list ::UI::ScrollSet $wysc \
      [list grid $wysc -column 1 -row 0 -sticky ns]]  \
      -borderwidth 0 -highlightthickness 0        

    # State for a read message
    $T state define read

    # State for an unread message.
    $T state define unread

    # These are dummy options.
    set itemBg [option get $T itemBackground {}]
    set itemFg [option get $T itemFill {}]
    set bd [option get $T columnBorderWidth {}]
    set bg [option get $T columnBackground {}]
    set fg [option get $T textColor {}]

    $T column create -tags cWhiteboard -image $locals(iconWB16)  \
      -itembackground $itemBg -resize 0 -borderwidth $bd -background $bg \
      -textcolor $fg
    $T column create -tags cSubject -expand 1 -text [mc Subject] \
      -itembackground $itemBg -button 1 -borderwidth $bd -background $bg \
      -textcolor $fg
    $T column create -tags cFrom    -expand 1 -text [mc From]    \
      -itembackground $itemBg -button 1 -squeeze 1 -borderwidth $bd  \
      -background $bg -textcolor $fg
    $T column create -tags cDate    -expand 1 -text [mc Date]    \
      -itembackground $itemBg -button 1 -arrow up -borderwidth $bd  \
      -background $bg  -textcolor $fg
    $T column create -tags cSecs -visible 0
    $T column create -tags cRead -visible 0

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
    
    $T column configure cWhiteboard -itemstyle styImage
    $T column configure cSubject -itemstyle stySubject
    $T column configure cFrom -itemstyle styText
    $T column configure cDate -itemstyle styText
    $T column configure cSecs -itemstyle styTag
    $T column configure cRead -itemstyle styTag
    
    $T notify install <Header-invoke>
    $T notify bind $T <Header-invoke> [list [namespace current]::HeaderCmd %T %C]
    $T notify bind $T <Selection> [list [namespace current]::Selection %T]
    bind $T <Double-1>            [list [namespace current]::DoubleClickMsg %W]
    bind $T <KeyPress-BackSpace>  [namespace current]::TrashMsg
    
    if {$itemFg ne ""} {
	treeutil::configureelementtype $T text -fill $itemFg
    }
    set sortColumn 0
}

proc ::MailBox::OnDestroyTree {} {
    variable locals
    
    after cancel $locals(updateDateid)
}

proc ::MailBox::InsertAll {} {

    if {[MKHaveMetakit]} {
	MKInsertAll
    } else {
	variable mailbox
	variable locals

	set wtbl $locals(wtbl)
	set i 0
	foreach id [lsort -integer [array names mailbox]] {
	    InsertRow $wtbl $mailbox($id) $i
	    incr i
	}
    }
}

# MailBox::InsertRow --
#
#       Does the actual job of adding a line in the mailbox widget.

proc ::MailBox::InsertRow {wtbl row i} {
    
    variable mailboxindex
    variable locals
    
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
    set ujid2 [jlib::unescapejid [jlib::barejid $from]]
    
    set T $wtbl
    set item [$T item create -tags $uidmsg]
    $T item text $item  \
      cSubject $subject  cFrom $ujid2   cDate $smartdate  \
      cSecs    $secs     cRead $isread
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
	
	# Configure buttons.
	$wtbar buttonconfigure reply   -state normal
	$wtbar buttonconfigure forward -state normal
	$wtbar buttonconfigure save    -state normal
	$wtbar buttonconfigure print   -state normal
	$wtbar buttonconfigure trash   -state normal
	DisplayAny [$T selection get]
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
	set uid  [$T item tag names $item]
	set secs [$T item element cget $item cSecs eText -text]
	set smartdate [::Utils::SmartClockFormat $secs -showsecs 0]
	$T item element configure $item cDate eText -text $smartdate
    }
    
    # Reschedule ourselves.
    set locals(updateDateid) [after $locals(updateDatems) \
      [list [namespace current]::UpdateDateAndTime $T]]
}

proc ::MailBox::DisplayMessageHook {body args} {

    array set argsA $args
    if {[info exists argsA(-msgid)]} {
	MarkMsgAsRead $argsA(-msgid)
    }
}

proc ::MailBox::MarkMsgAsRead {uid} {
    global  wDlgs
    variable locals
    
    if {[MKHaveMetakit]} {
	MKMarkAsRead $uid
    } else {
	variable mailbox
	variable mailboxindex

	if {[lindex $mailbox($uid) $mailboxindex(isread)] == 0} {
	    lset mailbox($uid) $mailboxindex(isread) 1	    
	    set locals(haveEdits) 1
	}
    }
    if {[winfo exists $wDlgs(jinbox)]} {
	$locals(wtbl) item state set [list tag $uid] read
    }
}

proc ::MailBox::CloseHook {wclose} {
    
    set result ""
    ShowHide -visible 0
    return stop
}

proc ::MailBox::GetToplevel {} {    
    variable locals
    
    if {[winfo exists $locals(w)]} {
	return $locals(w)
    } else {
	return {}
    }
}

# Various accessor functions.

proc ::MailBox::Get {uid key} {

    if {[MKHaveMetakit]} {
	lassign [MKGetContentList $uid] subject from date body
	switch -- $key {
	    subject - from - date {
		return [set $key]
	    }
	    message {
		return $body
	    }
	}
    } else {
	variable mailbox
	variable mailboxindex
    
	return [lindex $mailbox($uid) $mailboxindex($key)]
    }
}

proc ::MailBox::GetContentList {uid} {
    
    if {[MKHaveMetakit]} {
	return [MKGetContentList $uid]
    } else {
	variable mailbox
	variable mailboxindex
	
	return [list  \
	  [lindex $mailbox($uid) $mailboxindex(subject)] \
	  [lindex $mailbox($uid) $mailboxindex(from)]    \
	  [lindex $mailbox($uid) $mailboxindex(date)]    \
	  [lindex $mailbox($uid) $mailboxindex(message)] \
	  ]
    }
}

proc ::MailBox::Set {id key value} {

    if {[MKHaveMetakit]} {
	# @@@ TODO or remove?
    } else {
	variable mailbox
	variable mailboxindex
	
	lset mailbox($id) $mailboxindex($key) $value
    }
}

proc ::MailBox::IsLastMessage {uid} {
    
    if {[MKHaveMetakit]} {
	return [MKIsLast $uid]
    } else {
	variable mailbox
	
	set sorted [lsort -integer [array names mailbox]]
	return [expr ($uid >= [lindex $sorted end]) ? 1 : 0]
    }
}

proc ::MailBox::AllRead {} {

    if {[MKHaveMetakit]} {
	return [MKAllRead]
    } else {
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
}

proc ::MailBox::GetNextMsgID {uid} {
    
    if {[MKHaveMetakit]} {
	return [MKGetNextUUID $uid]
    } else {
	variable mailbox
	
	set nextid $uid
	set sorted [lsort -integer [array names mailbox]]
	set ind [lsearch $sorted $uid]
	if {($ind >= 0) && ([expr $ind + 1] < [llength $sorted])} {
	    set next [lindex $sorted [incr ind]]
	}
	return $next
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

proc ::MailBox::MakeMessageList {body args} {
    variable locals
    variable uidmsg
        
    array set argsA {
	-subject {}
    }
    array set argsA $args
    set xmldata $argsA(-xmldata)
    set from [wrapper::getattribute $xmldata from]
    set jid2 [jlib::barejid $from]

    # Here we should probably check som 'jabber:x:delay' element...
    # This is ISO 8601.
    set secs ""
    set tm [::Jabber::GetDelayStamp $xmldata]
    if {$tm ne ""} {
	# Always use local time!
	set secs [clock scan $tm -gmt 1]
    }
    if {$secs eq ""} {
	set secs [clock seconds]
    }
    set date [clock format $secs -format "%Y%m%dT%H:%M:%S"]

    # List format for messages.
    return [list $argsA(-subject) $from $date 0 [incr uidmsg] $body]
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
	}
	puts $fd "set mailbox(\[incr uidmsg]) {$row}"
	close $fd
    }
}

proc ::MailBox::SaveMsg {} {    
    variable locals
    
    set wtextmsg $locals(wtextmsg)
    set T $locals(wtbl)
    
    # Need selected line here.
    if {[$T selection count] != 1} {
	return
    }
    set item [$T selection get]
    set from [$T item element cget $item cFrom eText -text]
    set jid2 [jlib::barejid $from]
    
    set ans [tk_getSaveFile -title [mc "Save Message"] -initialfile $jid2.txt]
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

proc ::MailBox::TrashMsg {} {
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
	set uid [$T item tag names $item]
	
	set fileTail ""
	if {[MKHaveMetakit]} {
	    array unset v
	    array set v [MKGet $uid]
	    if {($v(file) ne "") && ([file extension $v(file)] eq ".can")} {
		set fileTail $v(file)
	    }
	    MKDeleteRow $uid
	} else {
	    set cuid [GetCanvasHexUID $uid]
	    if {$cuid ne ""} {
		set fileTail $cuid.can
	    }
	    unset mailbox($uid)
	}
	if {$fileTail ne ""} {
	    set filePath [file join $this(inboxCanvasPath) $fileTail]
	    catch {file delete $filePath}
	}
	
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
	::JUI::MailBoxState empty
    } elseif {$select ne ""} {
	$T selection add $select
    }
}

proc ::MailBox::GetAnySVGElements {row} {
    variable xmlns
    
    set svgElem {}
    set idx [lsearch $row -x]
    if {$idx > 0} {
	set xlist [lindex $row [expr $idx+1]]
	set svgElem [wrapper::getnamespacefromchilds $xlist x $xmlns(svg)]
    }
    return $svgElem
}

proc ::MailBox::DisplayWhiteboardFile {jid3 fileName} {
    global  prefs this wDlgs
    upvar ::Jabber::jstate jstate
    
    jlib::splitjid $jid3 jid2 res
    set w [MakeWhiteboard $jid2]
    
    # Only if user available shall we try to import.
    set tryimport 0
    if {[$jstate(jlib) roster isavailable $jid3] || \
      [jlib::jidequal $jid3 $jstate(mejidres)]} {
	set tryimport 1
    }
	    
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
    
    set jid2 [jlib::barejid $jid3]    
    set w [MakeWhiteboard $jid2]
    
    # Only if user available shall we try to import.
    set tryimport 0
    if {[$jstate(jlib) roster isavailable $jid3] || \
      [jlib::jidequal $jid3 $jstate(mejidres)]} {
	set tryimport 1
    }

    set cmdList [::JWB::GetSVGWBMessageList $w $xlist]
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
	set wcan [::WB::GetCanvasFromWtop $w]
	::Import::HttpResetAll  $w
	::CanvasCmd::EraseAll   $wcan
	::WB::ConfigureMain     $w -title $title	    
	::WB::SetStatusMessage  $w ""
	::JWB::Configure $w -jid $jid2
	undo::reset [::WB::GetUndoToken $wcan]
    } else {
	::JWB::NewWhiteboard -w $w -state disabled \
	  -title $title -jid $jid2 -usewingeom 1
	bind $w <Destroy> {+::MailBox::OnDestroyWhiteboard %W}
    }
    return $w
}

proc ::MailBox::OnDestroyWhiteboard {w} {
    variable locals
    variable mailbox
    
    if {[winfo toplevel $w] eq $w} {
	
	# Deselect any selected whiteboards on destroy.
	set T $locals(wtbl)
	foreach item [$T selection get] {
	    set uid [$T item tag names $item]

	    if {[MKHaveMetakit]} {
		array set v [MKGet $uid]
		if {($v(file) ne "") && ([file extension $v(file)] eq ".can")} {
		    $T selection clear $item
		}
	    } else {
		set uidcan [GetCanvasHexUID $uid]
		set svgElem [GetAnySVGElements $mailbox($uid)]
		if {[string length $uidcan]} {	
		    $T selection clear $item
		} elseif {[llength $svgElem]} {
		    $T selection clear $item
		}
	    }
	}
    }
}

proc ::MailBox::DoubleClickMsg {T} {
    variable locals
    upvar ::Jabber::jprefs jprefs
        
    if {[$T selection count] != 1} {
	return
    }
    set item [$T selection get]
    set uid [$T item tag names $item]

    if {[MKHaveMetakit]} {
	lassign [MKGetContentList $uid] subject from date body
    } else {
	variable mailbox
	variable mailboxindex

	# We shall have the original, unparsed, text here.
	set body    [lindex $mailbox($uid) $mailboxindex(message)]
	set subject [lindex $mailbox($uid) $mailboxindex(subject)]
	set to      [lindex $mailbox($uid) $mailboxindex(from)]
	set date    [lindex $mailbox($uid) $mailboxindex(date)]
    }    
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

proc ::MailBox::MsgDisplayClear {} {    
    variable locals
    
    set wtextmsg $locals(wtextmsg)    
    $wtextmsg configure -state normal
    $wtextmsg delete 1.0 end
    $wtextmsg configure -state disabled
}

proc ::MailBox::DisplayAny {item} {
    variable locals
    variable xmlns
    
    set T $locals(wtbl)

    set jid3 [$T item element cget $item cFrom eText -text]
    set uid  [$T item tag names $item]
    set jid2 [jlib::barejid $jid3]
	    
    DisplayTextMsg $uid

    # If any whiteboard stuff in message...
    if {[::Jabber::HaveWhiteboard]} {
	if {[MKHaveMetakit]} {
	    array set v [MKGet $uid]
	    if {$v(file) ne ""} {
		# Raw wb protocol:
		DisplayWhiteboardFile $jid3 $v(file)
	    } else {
		# SVG protocol:
		set svgE [wrapper::getfirstchild $v(xmldata) x $xmlns(svg)]
		if {[llength $svgE]} {
		    DisplayXElementSVG $jid3 [list $svgE]
		}
	    }
	} else {
	    variable mailbox
	    variable mailboxindex
	    
	    set uidcan [GetCanvasHexUID $uid]
	    set svgEs [GetAnySVGElements $mailbox($uid)]
	    
	    # The "raw" protocol stores the canvas in a separate file indicated by
	    # the -canvasuid key in the message list.
	    # The SVG protocol stores the complete x element in the mailbox 
	    # -x listOfElements
	    
	    # The "raw" protocol.
	    if {[string length $uidcan] > 0} {	
		DisplayWhiteboardFile $jid3 $uidcan.can
	    } elseif {[llength $svgEs]} {
		DisplayXElementSVG $jid3 $svgEs
	    }
	}
    }
}

proc ::MailBox::DisplayTextMsg {uid} {
    global  prefs

    variable locals
    variable mailbox
    variable mailboxindex
    
    set wtextmsg $locals(wtextmsg)  
    $wtextmsg configure -state normal
    $wtextmsg delete 1.0 end
    $wtextmsg mark set insert end
    
    if {[MKHaveMetakit]} {
	array set v [MKGet $uid]
	lassign [MKGetContentList $uid] subject from date body
	set xdataE [wrapper::getfirstchild $v(xmldata) x "jabber:x:data"]
	if {[llength $xdataE]} {
	    set type [wrapper::getattribute $xdataE type]
	    if {$type eq "form"} {
		$wtextmsg insert end \
		  "This message contains a form that you can fill in by pressing the Reply button" \
		  xdata
		$wtextmsg insert end \n
	    }
	}
    } else {
	set subject [lindex $mailbox($uid) $mailboxindex(subject)]
	set from    [lindex $mailbox($uid) $mailboxindex(from)]
	set date    [lindex $mailbox($uid) $mailboxindex(date)]
	set body    [lindex $mailbox($uid) $mailboxindex(message)]
    }
    ::Text::ParseMsg normal $from $wtextmsg $body normal
    $wtextmsg insert end \n
    $wtextmsg configure -state disabled
    
    # This hook triggers 'MarkMsgAsRead'.
    set opts [list -subject $subject -from $from -time $date -msgid $uid]
    eval {::hooks::run displayMessageHook $body} $opts
}

proc ::MailBox::ReplyTo {} {
    variable locals
    variable mailbox
    variable mailboxindex
    upvar ::Jabber::jstate jstate
    
    set T $locals(wtbl)
    if {[$T selection count] != 1} {
	return
    }
    set item [$T selection get]
    set uid [$T item tag names $item]

    if {[MKHaveMetakit]} {
	array set v [MKGet $uid]
	set xmldata $v(xmldata)
	lassign [MKGetContentList $uid] subject from date body
    } else {
	set subject [lindex $mailbox($uid) $mailboxindex(subject)]
	set from    [lindex $mailbox($uid) $mailboxindex(from)]
	set date    [lindex $mailbox($uid) $mailboxindex(date)]
	set body    [lindex $mailbox($uid) $mailboxindex(message)]
	set xmldata [list]
    }    
    set to [::Jabber::JlibCmd getrecipientjid $from]
    if {![regexp -nocase {^ *re:} $subject]} {
	set subject "Re: $subject"
    }
    ::NewMsg::Build -to $to -subject $subject  \
      -quotemessage $body -time $date -replyxmldata $xmldata
}

proc ::MailBox::ForwardTo {} {
    variable locals
    variable mailbox
    variable mailboxindex
    
    set T $locals(wtbl)
    if {[$T selection count] != 1} {
	return
    }
    set item [$T selection get]
    set uid [$T item tag names $item]

    if {[MKHaveMetakit]} {
	array set v [MKGet $uid]
	set xmldata $v(xmldata)
	lassign [MKGetContentList $uid] subject from date body
    } else {
	set subject [lindex $mailbox($uid) $mailboxindex(subject)]
	set from    [lindex $mailbox($uid) $mailboxindex(from)]
	set date    [lindex $mailbox($uid) $mailboxindex(date)]
	set body    [lindex $mailbox($uid) $mailboxindex(message)]
	set xmldata [list]
    }
    set subject "Forwarded: $subject"
    ::NewMsg::Build -subject $subject -forwardmessage $body -time $date \
      -forwardxmldata $xmldata
}

proc ::MailBox::DoPrint {} {

    variable locals

    set allText [::Text::TransformToPureText $locals(wtextmsg)]
    
    ::UserActions::DoPrintText $locals(wtextmsg)  \
      -data $allText -font CociSmallFont
}

proc ::MailBox::SaveMailbox {args} {

    eval {SaveMailboxVer2} $args
}
    
proc ::MailBox::SaveMailboxVer1 {} {
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
	::UI::MessageBox -type ok -icon error -title [mc Error] \
	  -message [mc jamesserrinboxopen2 $tmpFile]
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
    
    array set argsA {
	-force      0
    }
    array set argsA $args
    
    # If the mailbox is read there can be edits. Needs therefore to save state.
    if {$argsA(-force)} {
	set doSave 1
    } else {
	set doSave 0
    }
    ::Debug 2 "::MailBox::SaveMailboxVer2 args=$args"
    if {$locals(mailboxRead)} {

	# Be sure to not have any inbox that is empty.
	if {[llength [array names mailbox]] == 0} {
	    catch {file delete $this(inboxFile)}
	    return
	} else {
	    
	    # Save only if mailbox read and have nonempty mailbox array.
	    set doSave 1
	}
    }
    if {!$doSave} {
	return
    }
        
    # Work on a temporary file and switch later.
    set tmpFile $this(inboxFile).tmp
    if {[catch {open $tmpFile w} fid]} {
	::UI::MessageBox -type ok -icon error -title [mc Error] \
	  -message [mc jamesserrinboxopen2 $tmpFile]
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

proc ::MailBox::ReadMailbox {} {
    global  this
    variable locals
    variable mailbox

    if {[file exists $this(inboxFile)]} {
	ReadMailboxVer2
    }
    if {[MKHaveMetakit]} {
	MKOpen
	if {[file exists $this(inboxFile)]} {
	    MKImportOld
	    
	    # Cleanup all old stuff which we don't use anymore.
	    array unset mailbox
	    
	    # Take backup.
	    set date [clock format [clock seconds] -format "%y-%m-%d"]
	    set bu [file rootname $this(inboxFile)]${date}-[pid].tcl
	    file rename -force $this(inboxFile) $bu
	}
    }
    
    # Set this even if not there.
    set locals(mailboxRead) 1
}

proc ::MailBox::TranslateAnyVer1ToCurrentVer {} {
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

proc ::MailBox::GetMailboxVersion {} {
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

proc ::MailBox::ReadMailboxVer1 {} {
    global  this
    variable locals
    variable uidmsg
    variable mailbox
    
    ::Debug 2 "::MailBox::ReadMailboxVer1"

    if {[catch {source $this(inboxFile)} msg]} {
	set tail [file tail $this(inboxFile)]
	::UI::MessageBox -title [mc Error] -icon error  \
	  -type ok -message [mc jamesserrinboxread2 $tail $msg]
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

proc ::MailBox::ReadMailboxVer2 {} {
    global  this
    variable locals
    variable uidmsg
    variable mailbox
    variable mailboxindex

    ::Debug 2 "::MailBox::ReadMailboxVer2"

    if {[catch {source $this(inboxFile)} msg]} {
	set tail [file tail $this(inboxFile)]
	::UI::MessageBox -title [mc Error] -icon error  \
	  -type ok -message [mc jamesserrinboxread2 $tail $msg]
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

proc ::MailBox::HaveMailBox {} {
    global  this

    if {[file exist $this(inboxFile)]} {
	set ans 1
    } else {
	set ans 0
    }
    return $ans
}

proc ::MailBox::DeleteMailbox {} {
    global prefs this

    if {[file exist $this(inboxFile)]} {
	catch {file delete $this(inboxFile)}
    }    
    foreach f [glob -nocomplain -directory $this(inboxCanvasPath) *.can] {
	catch {file delete $f}
    }
}

# MailBox::PrefsFilePathHook --
# 
#       This gets called when we want user prefs on a removable drive or
#       vice versa.

proc ::MailBox::PrefsFilePathHook {} {
    variable locals
    variable mailbox
    
    if {$locals(mailboxRead)} {
	if {[winfo exists $locals(wtbl)]} {
	    $locals(wtbl) item delete all
	}
	if {[MKHaveMetakit]} {
	    MKClose
	}
	unset -nocomplain mailbox
	ReadMailbox
	if {[winfo exists $locals(wtbl)]} {
	    InsertAll
	}
    }
}

proc ::MailBox::QuitHook {} {
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
	if {[MKHaveMetakit]} {
	    MKClose
	}
    } else {
	DeleteMailbox
	if {[MKHaveMetakit]} {
	    MKDelete
	}
    }
}

# Preliminary metakit mailbox --------------------------------------------------

proc ::MailBox::MKGetFile {} {
    global  this
    
    # Note that this(prefsPath) can vary!
    return [file join $this(prefsPath) Inbox.mk]
}

proc ::MailBox::MKHaveMetakit {} {
    variable mkhavemetakit
        
    if {[info exists mkhavemetakit]} {
	return $mkhavemetakit
    } else {
	if {[catch {
	    package require Mk4tcl
	}]} {
	    set mkhavemetakit 0
	    return 0
	} else {
	    set mkhavemetakit 1
	    return 1
	}
    }
}

proc ::MailBox::MKExists {} {
    return [file exists [MKGetFile]]
}

proc ::MailBox::MKOpen {} {
    global  this
    
    # This creates the file if not exists.
    mk::file open mailbox [MKGetFile]
    
    # The actual data. 
    # The 'file' property is the tail name for any externally stored data.
    mk::view layout mailbox.inbox {uuid:S time:S isread:S xmldata:S file:S}
    
    # Keep a view that maps view to a text label.
    mk::view layout mailbox.label {view:S label:S}
    
    # The first line must always be the default inbox.
    mk::set mailbox.label!0 view inbox label [mc Inbox]
}

proc ::MailBox::MKAdd {uuid time isread xmldata file} {
    set path mailbox.inbox
    set cursor [mk::row append $path  \
      uuid $uuid time $time isread $isread xmldata $xmldata file $file]
    mk::file commit mailbox
    return $cursor
}

proc ::MailBox::MKDeleteRow {uuid} {
    set path mailbox.inbox
    set idx [mk::select $path -exact uuid $uuid]
    mk::row delete $path!$idx
    mk::file commit mailbox
}

proc ::MailBox::MKGetContentList {uuid} {   
    array set v [MKGet $uuid]
    set xmldata $v(xmldata)
    set from [wrapper::getattribute $xmldata from]
    set subjectE [wrapper::getfirstchildwithtag $xmldata subject]
    set bodyE    [wrapper::getfirstchildwithtag $xmldata body]
    set subject  [wrapper::getcdata $subjectE]
    set body     [wrapper::getcdata $bodyE]
    
    return [list $subject $from $v(time) $body]
}

proc ::MailBox::MKGet {uuid} {
    set path mailbox.inbox
    set idx [mk::select $path -exact uuid $uuid]
    return [mk::get $path!$idx]
}

proc ::MailBox::MKInsertAll {} {   
    mk::loop cursor mailbox.inbox {
	array set v [mk::get $cursor]
	MKInsertRow $v(uuid) $v(time) $v(isread) $v(xmldata) $v(file)
    }
}

proc ::MailBox::MKInsertRow {uuid time isread xmldata file} {
    variable locals
    variable xmlns
        
    set secs [clock scan $time]
    set smartdate [::Utils::SmartClockFormat $secs -showsecs 0]
    
    set from [wrapper::getattribute $xmldata from]
    set subjectE [wrapper::getfirstchildwithtag $xmldata subject]
    set bodyE    [wrapper::getfirstchildwithtag $xmldata body]
    set subject [wrapper::getcdata $subjectE]
    set body    [wrapper::getcdata $bodyE]    
    set ujid2 [jlib::unescapejid [jlib::barejid $from]]
    
    set iswb 0
    if {[file extension $file] eq ".can"} {
	set iswb 1
    } else {
	set svgE [wrapper::getfirstchild $xmldata x $xmlns(svg)]
	if {[llength $svgE]} {
	    set iswb 1
	}
    }    
    set T $locals(wtbl)
    set item [$T item create -tags $uuid]
    $T item text $item  \
      cSubject $subject cFrom $ujid2  cDate $smartdate  \
      cSecs    $secs    cRead $isread
    $T item lastchild root $item
    
    if {$iswb} {
	$T item element configure $item cWhiteboard eImageWb  \
	  -image $locals(iconWB12)
    }
    if {$isread} {
	$T item state set $item read
    } else {
	$T item state set $item unread
    }
}

proc ::MailBox::MKMarkAsRead {uuid} {
    set path mailbox.inbox
    set idx [mk::select $path -exact uuid $uuid]
    mk::set $path!$idx isread 1
    mk::file commit mailbox
}

proc ::MailBox::MKAllRead {} {
    set path mailbox.inbox
    set idx [mk::select $path -exact isread 0]
    return [expr {[llength $idx] == 0 ? 1 : 0}]
}

proc ::MailBox::MKGetNextUUID {uuid} {
    set path mailbox.inbox
    set idx [mk::select $path -exact uuid $uuid]
    mk::cursor create c $path $idx
    mk::cursor incr c 1
    return [mk::get $c uuid] 
}

proc ::MailBox::MKIsLast {uuid} {
    set path mailbox.inbox
    set idx [mk::select $path -exact uuid $uuid]
    mk::cursor create c $path
    mk::cursor position c end
    return [expr {[string equal $path!$idx $c]}]
}

# MailBox::MKImportOld --
# 
#       Takes the old flat file inbox and imports it into the metakit.

proc ::MailBox::MKImportOld {} {
    global  this
    variable mailbox
    variable mailboxindex
    
    set path mailbox.inbox
    
    # We must be sure that all messages are time ordered.
    # Add a temporrary secs property just for sorting.
    mk::view layout $path {uuid:S time:S isread:S xmldata:S file:S secs:I}
     
    # Need to construct the xmldata for each message.
    # Must have read the old inbox first.
    foreach id [lsort -integer [array names mailbox]] {
	set row $mailbox($id)
	set subject [lindex $row $mailboxindex(subject)]
	set from    [lindex $row $mailboxindex(from)]
	set date    [lindex $row $mailboxindex(date)]
	set isread  [lindex $row $mailboxindex(isread)]
	set body    [lindex $row $mailboxindex(message)]
	set secs [clock scan $date]
	
	set attr [list from $from]
	set Es {}
	if {$body ne ""} {
	    lappend Es [wrapper::createtag "body" -chdata $body]
	}
	if {$subject ne ""} {
	    lappend Es [wrapper::createtag "subject" -chdata $subject]
	}
	set xmldata [wrapper::createtag "message"  \
	  -attrlist $attr -subtags $Es]
	
	# The canvas is stored in a file referenced by -canvasuid.
	array unset opts
	array set opts [lrange $row $mailboxindex(opts) end]
	if {[info exists opts(-canvasuid)]} {
	    set file $opts(-canvasuid).can
	} else {
	    set file ""
	}

	set uuid [uuid::uuid generate]
	set cursor [MKAdd $uuid $date $isread $xmldata $file]
	mk::set $cursor secs $secs
    }
    
    # Do the actual sorting and remove the secs.
    mk::select $path -sort secs
    mk::view layout $path {uuid:S time:S isread:S xmldata:S file:S}
    mk::file commit mailbox
}

proc ::MailBox::MKExportDlg {} {
    
    if {![MKHaveMetakit]} {
	tk_messageBox -message "Metakit is necessary to export as xml file."
	return
    }
    set fileName [tk_getSaveFile -title [mc {Save File}] \
      -initialfile myinbox.xml -defaultextension .xml \
      -filetypes { {"XML File" {.xml}} }]
    if {[llength $fileName]} {
	MKExportToXMLFile $fileName
    }
}

proc ::MailBox::MKExportToXMLFile {fileName} {
    global  this
    variable locals
    
    if {!$locals(mailboxRead)} {
	ReadMailbox
    }
    set path mailbox.inbox
    set label [mk::get mailbox.label!0 label]
    set today [clock format [clock seconds] -format "%Y%m%dT%H:%M:%S"]
    set fd [open $fileName w]
    fconfigure $fd -encoding utf-8
    puts $fd "<?xml version='1.0' encoding='UTF-8'?>"
    puts $fd "<?xml-stylesheet type='text/xsl' href='mailbox.xsl'?>"
    puts $fd "<!DOCTYPE mailbox>"
    puts $fd "<mailbox date='$today' view='inbox' label='$label'>"
    
    mk::loop cursor $path {
	array set v [mk::get $cursor]
	
	set attr [list time $v(time) read $v(isread)]
	if {$v(file) ne ""} {
	    set href [file join $this(inboxCanvasPath) $v(file)]
	    if {[file exists $href]} {
		set href [uriencode::quotepath $href]
		lappend attr xlink:href "file://$href"
	    }
	}
	set itemE [wrapper::createtag item  \
	  -attrlist $attr -subtags [list $v(xmldata)]]
	set xml [wrapper::formatxml $itemE -prefix "\t"]
	puts $fd $xml	
    }
    puts $fd "</mailbox>"
    close $fd
}

proc ::MailBox::MKClose {} {
    
    # Close only if open metakit.
    array set tagA [mk::file open]
    if {[info exists tagA(mailbox)]} {
	mk::file close mailbox
    }
}

proc ::MailBox::MKDelete {} {
    global  this
    MKClose
    file delete -force [MKGetFile]
}

#-------------------------------------------------------------------------------
