#  Chat.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements chat type of UI for jabber.
#      
#  Copyright (c) 2001-2007  Mats Bengtsson
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
# $Id: Chat.tcl,v 1.212 2007-10-04 14:01:07 matben Exp $

package require ui::entryex
package require ui::optionmenu
package require uriencode
package require colorutils
package require History
package require UI::WSearch

package provide Chat 1.0

# TODO:   o Register presence per jid instead, see code below


namespace eval ::Chat:: {
    global  wDlgs
    
    # Add all event hooks.
    ::hooks::register quitAppHook                ::Chat::QuitHook
    ::hooks::register newChatMessageHook         ::Chat::GotMsg         20
    ::hooks::register newMessageHook             ::Chat::GotNormalMsg
    ::hooks::register loginHook                  ::Chat::LoginHook
    ::hooks::register logoutHook                 ::Chat::LogoutHook

    ::hooks::register avatarNewPhotoHook         ::Chat::AvatarNewPhotoHook
    ::hooks::register menuChatEditPostHook       ::Chat::MenuEditPostHook
    ::hooks::register nicknameEventHook          ::Chat::NicknameEventHook

    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          ::Chat::InitPrefsHook
    ::hooks::register prefsBuildHook         ::Chat::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::Chat::SavePrefsHook
    ::hooks::register prefsCancelHook        ::Chat::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::Chat::UserDefaultsHook
    ::hooks::register prefsDestroyHook       ::Chat::DestroyPrefsHook

    # Use option database for customization. 
    # These are nonstandard option valaues and we may therefore keep priority
    # widgetDefault.

    # Icons
    option add *StartChat.chatImage       newmsg                widgetDefault
    option add *StartChat.chatDisImage    newmsgDis             widgetDefault

    option add *Chat*sendImage            send                  widgetDefault
    option add *Chat*sendDisImage         sendDis               widgetDefault
    option add *Chat*sendFileImage        sendfile              widgetDefault
    option add *Chat*sendFileDisImage     sendfileDis           widgetDefault
    option add *Chat*saveImage            save                  widgetDefault
    option add *Chat*saveDisImage         saveDis               widgetDefault
    option add *Chat*historyImage         history               widgetDefault
    option add *Chat*historyDisImage      historyDis            widgetDefault
    option add *Chat*settingsImage        settings              widgetDefault
    option add *Chat*settingsDisImage     settingsDis           widgetDefault
    option add *Chat*printImage           print                 widgetDefault
    option add *Chat*printDisImage        printDis              widgetDefault
    option add *Chat*whiteboardImage      whiteboard            widgetDefault
    option add *Chat*whiteboardDisImage   whiteboardDis         widgetDefault
    option add *Chat*inviteImage          invite                widgetDefault
    option add *Chat*inviteDisImage       inviteDis             widgetDefault

    option add *Chat*notifierImage        notifier              widgetDefault    
    option add *Chat*tabAlertImage        ktip                  widgetDefault    

    if {[tk windowingsystem] eq "aqua"} {
	option add *Chat*tabClose16Image        closeAqua         widgetDefault    
	option add *Chat*tabCloseActive16Image  closeAquaActive   widgetDefault    
    } else {
	option add *Chat*tabClose16Image        close             widgetDefault    
	option add *Chat*tabCloseActive16Image  close             widgetDefault    
    }
    
    # These are stored in images/16 so no conflicts.
    option add *Chat*history16Image       history               widgetDefault    
    option add *Chat*history16DisImage    historyDis            widgetDefault    
    
    option add *Chat*mePreForeground      red                   widgetDefault
    option add *Chat*mePreBackground      ""                    widgetDefault
    option add *Chat*mePreFont            ""                    widgetDefault                                     
    option add *Chat*meTextForeground     ""                    widgetDefault
    option add *Chat*meTextBackground     ""                    widgetDefault
    option add *Chat*meTextFont           ""                    widgetDefault                                     
    option add *Chat*youPreForeground     blue                  widgetDefault
    option add *Chat*youPreBackground     ""                    widgetDefault
    option add *Chat*youPreFont           ""                    widgetDefault
    option add *Chat*youTextForeground    ""                    widgetDefault
    option add *Chat*youTextBackground    ""                    widgetDefault
    option add *Chat*youTextFont          ""                    widgetDefault
    option add *Chat*sysPreForeground     "#26b412"             widgetDefault
    option add *Chat*sysTextForeground    "#26b412"             widgetDefault
    option add *Chat*sysPreFont           ""                    widgetDefault
    option add *Chat*sysTextFont          ""                    widgetDefault
    option add *Chat*histHeadForeground   ""                    widgetDefault
    option add *Chat*histHeadBackground   gray80                widgetDefault
    option add *Chat*histHeadFont         ""                    widgetDefault
    option add *Chat*clockFormat          "%H:%M"               widgetDefault
    option add *Chat*clockFormatNotToday  "%b %d %H:%M"         widgetDefault

    # List of: {tagName optionName resourceName resourceClass}
    variable chatOptions {
	{mepre       -foreground          mePreForeground       Foreground}
	{mepre       -background          mePreBackground       Background}
	{mepre       -font                mePreFont             Font}
	{metext      -foreground          meTextForeground      Foreground}
	{metext      -background          meTextBackground      Background}
	{metext      -font                meTextFont            Font}
	{youpre      -foreground          youPreForeground      Foreground}
	{youpre      -background          youPreBackground      Background}
	{youpre      -font                youPreFont            Font}
	{youtext     -foreground          youTextForeground     Foreground}
	{youtext     -background          youTextBackground     Background}
	{youtext     -font                youTextFont           Font}
	{syspre      -foreground          sysPreForeground      Foreground}
	{syspre      -font                sysPreFont            Font}
	{systext     -foreground          sysTextForeground     Foreground}
	{systext     -font                sysTextFont           Font}
	{histhead    -foreground          histHeadForeground    Foreground}
	{histhead    -background          histHeadBackground    Background}
	{histhead    -font                histHeadFont          Font}
    }

    # Standard widgets.
    if {[tk windowingsystem] eq "aqua"} {
	option add *Chat*TNotebook.padding         {8 8 8 18}       50
    } else {
	option add *Chat*TNotebook.padding         {8 8 8 8}        50
    }
    option add *ChatThread*Text.borderWidth     0               50
    option add *ChatThread*Text.relief          flat            50
    option add *ChatThread.padding              {12  0 12  0}   50
    option add *ChatThread*active.padding       {1}             50
    option add *ChatThread*TMenubutton.padding  {1}             50
    option add *ChatThread*top.padding          {12  8 12  8}   50
    option add *ChatThread*bot.padding          {0   6  0  6}   50

    
    # Local preferences.
    variable cprefs
    set cprefs(usexevents)    1
    set cprefs(xeventsmillis) 10000
    set cprefs(xeventid)      0
    set cprefs(lastActiveRet) 0
    
    # Running number for chat thread token and dialog token.
    variable uiddlg  0
    variable uidchat 0
    variable uidpage 0

    # Bindtags instead of binding to toplevel.
    bind ChatToplevel <Destroy> {+::Chat::OnDestroyToplevel %W}

    variable chatStateMap 
    array set chatStateMap {
        active,lostfocus     inactive
        active,close         gone
        active,typing        composing
        inactive,focus       active
        inactive,typing      composing
        inactive,close       gone
        inactive,send        active
        composing,lostfocus  inactive
        composing,close      gone
        composing,send       active
    }
    
    # Shall we allow multiple chast threads (and dialogs) per JID?
    variable allowMultiThreadPerJID 0
    
    set ::config(chat,show-head) 1
}

# Chat::OnToolButton --
# 
#       Toolbar button command.

proc ::Chat::OnToolButton { } {
    OnMenu
}

proc ::Chat::OnMenu { } {
    
    if {[llength [grab current]]} { return }

    if {[::JUI::GetConnectState] eq "connectfin"} {
	set jidL [::RosterTree::GetSelectedJID]
	if {[llength $jidL]} {
	    foreach jid $jidL {
		if {[::Jabber::RosterCmd isavailable $jid]} {
		    set jid2 [jlib::barejid $jid]
		    StartThread $jid2
		} else {
		    if {[llength $jidL] == 1} {
			StartThreadDlg -jid $jid
		    }
		}
	    }
	} else {
	    StartThreadDlg
	}
    }
}

# Chat::StartThreadDlg --
#
#       Start a chat, ask for user in dialog.
#       
# Arguments:
#       args        ?-key value? pairs
#       
# Results:
#       updates UI.

proc ::Chat::StartThreadDlg {args} {
    global  prefs this wDlgs config

    variable finished -1
    variable user ""
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Chat::StartThreadDlg args='$args'"

    array set argsA $args
    set w $wDlgs(jstartchat)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    
    ::UI::Toplevel $w -class StartChat  \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox}
    wm title $w [mc mChat]
    ::UI::SetWindowPosition $w
       
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    if {$config(chat,show-head)} {
	set im  [::Theme::GetImage [option get $w chatImage {}]]
	set imd [::Theme::GetImage [option get $w chatDisImage {}]]
	
	ttk::label $w.frall.head -style Headlabel \
	  -text [mc mChat] -compound left   \
	  -image [list $im background $imd]
	pack $w.frall.head -side top -fill both -expand 1
	
	ttk::separator $w.frall.s -orient horizontal
	pack $w.frall.s -side top -fill x
    }
    
    # Entries etc.
    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -side top -fill both -expand 1
    
    set frmid $wbox.frmid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1

    set jidlist [::Jabber::RosterCmd getusers -type available]
    ttk::label $frmid.luser -text "[mc {Contact ID}]:"  \
      -anchor e
    ui::comboboxex $frmid.euser -library $jidlist -width 26  \
      -textvariable [namespace current]::user

    grid  $frmid.luser  $frmid.euser  -sticky e -padx 2
    grid  $frmid.euser  -sticky w
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc OK] \
      -default active -command [list [namespace current]::DoStart $w]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::DoCancel $w]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side top -fill x
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    
    if {[info exists argsA(-jid)]} {
	set user [jlib::unescapestr $argsA(-jid)]
    }

    # Grab and focus.
    set oldFocus [focus]
    focus $frmid.euser
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    # Clean up.
    ::UI::SaveWinGeom $wDlgs(jstartchat)
    catch {focus $oldFocus}
    return [expr {($finished <= 0) ? "cancel" : "ok"}]
}

proc ::Chat::DoCancel {w} {
    variable finished
    
    ::UI::SaveWinGeom $w
    set finished 0
    destroy $w
}

proc ::Chat::DoStart {w} {
    variable finished
    variable user
    upvar ::Jabber::jstate jstate
    
    set ans yes
    
    set jid [jlib::escapejid $user]
    if {![jlib::jidvalidate $jid]} {
	set ans [::UI::MessageBox -message [mc jamessbadjid2 $jid] \
	  -icon error -title [mc Error] -type yesno]
	if {[string equal $ans "no"]} {
	    return
	}
    }    
    
    # User must be online.
    if {![$jstate(jlib) roster isavailable $jid]} {
	set ans [::UI::MessageBox -icon warning -type yesno -parent $w  \
	  -default no  \
	  -message "The user you intend chatting with,\
	  \"$user\", is not online, and this chat makes no sense.\
	  Do you want to chat anyway?"]
    }
    
    ::UI::SaveWinGeom $w
    set finished 1
    destroy $w
    if {$ans eq "yes"} {
	StartThread $jid
    }
}

# Chat::StartThread --
# 
#       According to XMPP def sect. 4.1, we should use user@domain when
#       initiating a new chat or sending a new message that is not a reply.
# 
# Arguments:
#       jid
#       args        -message, -thread

proc ::Chat::StartThread {jid args} {

    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Chat::StartThread jid=$jid, args=$args"
    
    array set argsA $args
    set havedlg 0
    set jid2 [jlib::barejid $jid]

    # Make unique thread id.
    if {[info exists argsA(-thread)]} {
	set threadID $argsA(-thread)
	
	# Do we already have a dialog with this thread?
	set chattoken [GetTokenFrom chat threadid $threadID]
	if {$chattoken ne ""} {
	    set havedlg 1
	    upvar 0 $chattoken chatstate
	}
    } else {
	set threadID [jlib::generateuuid]
    }
    
    if {!$havedlg} {
	set chattoken [eval {NewChat $threadID $jid} $args]
	SelectPage $chattoken
	
	variable $chattoken
	upvar 0 $chattoken chatstate
    }
  
    # Since we initated this thread need to set recipient to jid2 unless room.
    if {[::Jabber::JlibCmd service isroom $jid2]} {
	set chatstate(fromjid) $jid
    } else {
	set chatstate(fromjid) $jid2
    }

    return $chattoken
}

# Chat::NewChat --
# 
#       Takes a threadID and handles building of dialog and chat thread stuff.
#       @@@ Add more code here...
#       
# Results:
#       chattoken

proc ::Chat::NewChat {threadID jid args} {
    upvar ::Jabber::jprefs jprefs
    
    if {$jprefs(chat,tabbedui)} {
	set dlgtoken [GetFirstDlgToken]
	if {$dlgtoken eq ""} {
	    set dlgtoken [eval {Build $threadID -from $jid} $args]
	    set chattoken [GetTokenFrom chat threadid $threadID]
	} else {
	    set chattoken [NewPage $dlgtoken $threadID -from $jid]
	}
    } else {
	set dlgtoken [eval {Build $threadID -from $jid} $args]		
	set chattoken [GetActiveChatToken $dlgtoken]
    }
    MakeAndInsertHistory $chattoken
    RegisterPresence $chattoken        
    
    return $chattoken
}

# Chat::GotMsg --
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

proc ::Chat::GotMsg {body args} {
    global  prefs

    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    variable allowMultiThreadPerJID
    
    ::Debug 2 "::Chat::GotMsg args='$args'"

    array set argsA $args    
    set xmldata $argsA(-xmldata)
    
    # -from is a 3-tier jid /resource included.
    set jid [wrapper::getattribute $xmldata from]
    set jid2  [jlib::barejid $jid]
    set mjid  [jlib::jidmap $jid]
    set mjid2 [jlib::barejid $mjid]
    
    # We must follow the thread...
    # There are several cases to deal with: Have thread page, have dialog?
    if {[info exists argsA(-thread)] && $allowMultiThreadPerJID} {
	set threadID $argsA(-thread)
	set chattoken [GetTokenFrom chat threadid $threadID]
    } else {
	
	# Try to find a reasonable fallback for clients that fail here (Psi).
	# Find if we have registered any chat for this jid 2/3.
	set chattoken [GetTokenFrom chat jid [jlib::ESC $mjid2]*]
	if {$chattoken eq ""} {
	    
	    # Need to create a new thread ID.
	    set threadID [jlib::generateuuid]
	} else {
	    variable $chattoken
	    upvar 0 $chattoken chatstate

	    set threadID $chatstate(threadid)
	}
    }
    
    # At this stage we have a threadID.
    # We may not yet have a dialog and/or page for this thread. Make them.
    set newdlg 0
    if {$chattoken eq ""} {
	if {$body eq ""} {
	    # Junk
	    return
	} else {
	    set chattoken [eval {NewChat $threadID $jid} $args]
	    variable $chattoken
	    upvar 0 $chattoken chatstate

            #First ChatState is active
            set chatstate(chatstate) active
	    
	    eval {::hooks::run newChatThreadHook $body} $args
	}
    } else {
	variable $chattoken
	upvar 0 $chattoken chatstate
    }
    set dlgtoken $chatstate(dlgtoken)
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate

    # We may have reset its jid to a 2-tier jid if it has been offline.
    set chatstate(jid)         $mjid
    set chatstate(fromjid)     $jid
    set chatstate(displayname) [::Roster::GetDisplayName $jid2]
        
    set w $dlgstate(w)

    # Check for ChatState (XEP-0085) support
    set msgChatState ""
    if {[info exists argsA(-active)]} {
        set chatstate(havecs) true
        set msgChatState active
    } elseif {[info exists argsA(-composing)]} {
        set chatstate(havecs) true
        set msgChatState composing
    } elseif {[info exists argsA(-paused)]} {
        set chatstate(havecs) true
        set msgChatState paused
    } elseif {[info exists argsA(-inactive)]} {
        set chatstate(havecs) true
        set msgChatState inactive
    } elseif {[info exists argsA(-gone)]} {
        set chatstate(havecs) true
        set msgChatState gone
    } else {
        if { $chatstate(havecs) ne "true" } {
            set chatstate(havecs) false 
        }
    }

    if {$chatstate(havecs) eq "true"} {
        if { $msgChatState ne "" } {
	    set jid2 [jlib::barejid $chatstate(jid)]
            set name [::Jabber::RosterCmd getname $jid2]
            if {$name eq ""} {
                if {[::Jabber::JlibCmd service isroom $jid2]} {
                    set name [::Jabber::JlibCmd service nick $chatstate(jid)]
                } else {
                    set name $chatstate(displayname)
                }
            }
            $chatstate(wnotifier) configure -image $dlgstate(iconNotifier)
            set notifyString "chatcomp$msgChatState"
            set chatstate(notifier) " [mc $notifyString $name]"
        }
    } 

    set opts [list]
    set tm [::Jabber::GetDelayStamp $xmldata]
    if {$tm ne ""} {
	set secs [clock scan $tm -gmt 1]
	lappend opts -secs $secs
    }

    # If doesn't come a ChatState event (XEP-0085).
    # See if we've got a jabber:x:event (XEP-0022).
    # 
    # @@@ Should we handle this with hooks?
    if {[info exists argsA(-x)] && $chatstate(havecs) eq "true"} {
	eval {XEventHandleAnyXElem $chattoken} $args
    }

    # This is important since clicks may have reset the insert mark.
    $chatstate(wtext) mark set insert end

    if {[info exists argsA(-subject)]} {
	set chatstate(subject) $argsA(-subject)
	set chatstate(lastsubject) $chatstate(subject)
	eval {
	    InsertMessage $chattoken sys "[mc Subject]: $chatstate(subject)"
	} $opts
    }
    
    if {$body ne ""} {
	
	# Put in chat window.
	eval {InsertMessage $chattoken you $body} $opts

	# Put in history file.
       ::History::XPutItem recv $jid2 $xmldata
       
	eval {TabAlert $chattoken} $args
	XEventCancel $chattoken
	    
	# Put an extra (*) in the windows title if not in focus.
	if {([set wfocus [focus]] eq "") ||  \
	  ([winfo toplevel $wfocus] ne $dlgstate(w))} {
	    incr dlgstate(nhiddenmsgs)
	    SetTitle [GetActiveChatToken $dlgtoken]
	}
    }
    
    # Handle the situation if other end is just invisible and still online.
    if {$chatstate(state) eq "disabled"} {
	SetState $chattoken normal
	set icon [::Roster::GetPresenceIcon $jid invisible]
	$chatstate(wpresimage) configure -image $icon
    }
    
    # Run this hook (speech).
    eval {::hooks::run displayChatMessageHook $body} $args
}

# Chat::GotNormalMsg --
# 
#       Treats a 'normal' message as a chat message.

proc ::Chat::GotNormalMsg {body args} {
    global  prefs
    upvar ::Jabber::jprefs jprefs
        
    # Whiteboard messages are handled elsewhere. A guard:
    if {$jprefs(chat,normalAsChat) && ($body ne "")} {
	
	::Debug 2 "::Chat::GotNormalMsg args='$args'"
	eval {GotMsg $body} $args
    }
    
    # Try identify if composing event sent as normal message.
    array set argsA $args
    set xmldata $argsA(-xmldata)
    set jid2 [jlib::barejid [wrapper::getattribute $xmldata from]]
    set mjid2 [jlib::jidmap $jid2]
    set chattoken [GetTokenFrom chat jid [jlib::ESC $mjid2]*]
    
    if {($chattoken ne "") && [info exists argsA(-x)]} {
	eval {XEventHandleAnyXElem $chattoken} $args
    }
}

# NB: @@@ Change this to take complete xml stanzas instead!

# Chat::InsertMessage --
# 
#       Puts message in text chat window.
#       
# Arguments:
#       spec    {me|you|sys ?history?}
#       body    text
#       args:   -secs seconds
#               -jidfrom jid

proc ::Chat::InsertMessage {chattoken spec body args} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    upvar ::Jabber::jprefs jprefs
    
    array set argsA $args
    
    set w       $chatstate(w)
    set wtext   $chatstate(wtext)
    set jid     $chatstate(jid)
    set whom    [lindex $spec 0]
    set history [expr {[lsearch $spec "history"] >= 0 ? 1 : 0}]
        
    switch -- $whom {
	me {
	    if {[info exists argsA(-jidfrom)]} {
		set myjid $argsA(-jidfrom)
	    } else {
		set myjid [::Jabber::GetMyJid]
	    }
	    jlib::splitjidex $myjid node host res	    
	    if {$node eq ""} {
		set name $host
		set from $host
	    } else {
		set name [jlib::unescapestr $node]
		set from $node@$host
	    }
	    if {$jprefs(chat,mynick) ne ""} {
		set name $jprefs(chat,mynick)
	    }
	}
	you {
	    if {[info exists argsA(-jidfrom)]} {
		set youjid $argsA(-jidfrom)
	    } else {
		set youjid $jid
	    }
	    set jid2 [jlib::barejid $youjid]
	    if {[::Jabber::JlibCmd service isroom $jid2]} {
		set name [::Jabber::JlibCmd service nick $jid]
		set from $jid2/$name
	    } else {
		set name $chatstate(displayname)
		set from $jid2
	    }
	}
	sys {
	    set from ""
	    if {[info exists argsA(-jidfrom)]} {
		set from $argsA(-jidfrom)
	    }
	    set jid2 [jlib::barejid $from]
	    
	    # Figure out where this comes from.
	    if {[::Jabber::JlibCmd service isroom $jid2]} {
		set name [::Jabber::JlibCmd service nick $jid]
		set from $jid2/$name
	    } elseif {[jlib::jidequal $chatstate(jid2) $jid2]} {
		set name $chatstate(displayname)
		set from $jid2
	    } elseif {$jid2 ne ""} {
		set name [::Roster::GetDisplayName $jid2]
		set from $jid2
	    } else {
		set name $chatstate(displayname)
		set from $jid2
	    }
	}
    }
    if {[info exists argsA(-secs)]} {
	set secs $argsA(-secs)
    } else {
	set secs [clock seconds]
    }
    if {[::Utils::IsToday $secs]} {
	set clockFormat [option get $w clockFormat {}]
    } else {
	set clockFormat [option get $w clockFormatNotToday {}]
    }
    if {$clockFormat ne ""} {
	set theTime [clock format $secs -format $clockFormat]
	set prefix "\[$theTime\] "
    } else {
	set prefix ""
    }
    set body [string trimright $body]
    
    switch -- $whom {
	me - you {
	    append prefix "<$name>"
	}
	sys {
	    append prefix "<$name>"
	}
    }
    set htag ""
    if {$history} {
	set htag -history
    }
    $wtext configure -state normal
    
    switch -- $whom {
	me {
	    set pretags [concat mepre$htag $spec]
	    set txttags [concat metext$htag $spec]
	}
	you {
	    set pretags [concat youpre$htag $spec]
	    set txttags [concat youtext$htag $spec]
	}
	sys {
	    set pretags [concat syspre$htag $spec]
	    set txttags [concat systext$htag $spec]
	}
    }
    
    # Actually insert.
    $wtext insert insert $prefix $pretags
    $wtext insert insert "   "   $txttags
    ::Text::ParseMsg chat $from $wtext $body $txttags
    $wtext insert insert "\n"    $spec
    
    $wtext configure -state disabled
    $wtext see end
}

# Handle new xml based history format which has different api ------------------
#
# @@@ Cleanup old history code later.
#
# Chat::MakeAndInsertHistory --
# 
#       If new chat dialog check to see if we have got a thread history to insert.

proc ::Chat::MakeAndInsertHistory {chattoken} {
    global  this
    variable $chattoken
    upvar 0 $chattoken chatstate
    upvar ::Jabber::jprefs jprefs
    
    # If chatting with a room member we must use jid3.
    set jid2 $chatstate(jid2)
    if {[::Jabber::JlibCmd service isroom $jid2]} {
	set jidH $chatstate(jid)	
    } else {
	set jidH $jid2	
    }  
    set chatstate(havehistory) 0
    
    # We cannot merge old and new formats.
    # New format(s):
    if {[::History::XHaveHistory $jidH]} {
	
	# Write the selected item list to tmp file.
	# We MUST take a snaphot of our history before first message to avoid
	# any duplicates.
	set itemL [::History::XFastParseFiles $jidH \
	  $jprefs(chat,histLen) $jprefs(chat,histAge)]
	
	set fileH [::tfileutils::tempfile $this(tmpPath) ""]
	set fd [open $fileH w]
	fconfigure $fd -encoding utf-8
	puts $fd $itemL
	close $fd
	
	set chatstate(historyfile) $fileH
	set chatstate(historytype) xml	
	set chatstate(havehistory) 1
	
	# Old format:
    } elseif {[::History::HaveMessageFile $jidH]} {
    
	# We MUST take a snaphot of our history before first message to avoid
	# any duplicates.
	set fileH [::tfileutils::tempfile $this(tmpPath) ""]
	file copy -force [::History::GetMessageFile $jidH] $fileH
	set chatstate(historyfile) $fileH
	set chatstate(historytype) old
	set chatstate(havehistory) 1
    }
    HistoryCmd $chattoken
}

# Chat::GetHistory --
# 
#       Find any matching history record and return as list.
#       This is the OLD history format.

proc ::Chat::GetHistory {chattoken args} {
    global  prefs this
    variable $chattoken
    upvar 0 $chattoken chatstate
   
    ::Debug 2 "::Chat::GetHistory $args"
    
    if {![info exists chatstate(historyfile)]} {
	return
    }    
    array set opts {
        -last      -1
        -maxage     0
        -thread     0
    }
    array set opts $args
  
    # First find any matching history file.
    set jid2     $chatstate(jid2)
    set threadID $chatstate(threadid)

    # If chatting with a room member we must use jid3.
    if {[::Jabber::JlibCmd service isroom $jid2]} {
        set jidH $chatstate(jid)
    } else {
        set jidH $jid2
    }

    array set msg [::History::ReadMessageFromFile $chatstate(historyfile) $jidH]
    set names [lsort -integer [array names msg]]
    set keys $names

    # Start with the complete message history and limit using the options.
    if {$opts(-thread)} {

        # Collect all matching threads.
        set keys {}
        foreach i $names {
            array unset tmp
            array set tmp $msg($i)
            if {[info exists tmp(-thread)] && \
              [string equal $tmp(-thread) $threadID]} {
                lappend keys $i
            }
        }
    }
    if {$opts(-last) >= 0} {
        set keys [lrange $names end-$opts(-last) end]
    }
    set now [clock seconds]
    set maxage $opts(-maxage)

    set result {}
    foreach i $keys {
        array unset tmp
        foreach key {body name tag type thread} {
            set tmp(-$key) ""
        }
        array set tmp $msg($i)

        if {$tmp(-time) ne ""} {
            set secs [clock scan $tmp(-time)]
            if {$maxage} {
                if {[expr {$now - $secs}] > $maxage} {
                    continue
                }
            }
        } else {
            set secs ""
        }
        if {[string equal $tmp(-name) $jid2]} {
            set whom you
        } else {
            set whom me
        }
        set spec [list $whom history]

        lappend result [list -body $tmp(-body) -name $tmp(-name) -secs $secs -spec $spec -whom $whom]
    }
    return $result
}

# Chat::InsertHistoryOld --
# 
#       Find any matching history record and insert into dialog.

proc ::Chat::InsertHistoryOld {chattoken args} {
    global  prefs this
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    ::Debug 2 "::Chat::InsertHistoryOld $args"
    if {![info exists chatstate(historyfile)]} {
	return
    }    
    array set opts {
	-last      -1
	-maxage     0
	-thread     0
    }
    array set opts $args
 
    if {$opts(-last) == 0} {
	return
    }
    set wtext    $chatstate(wtext)
    $wtext mark set insert 1.0

    set result [GetHistory $chattoken -last $opts(-last) -maxage $opts(-maxage)]
    foreach elem $result {
        array set arrResult $elem
        InsertMessage $chattoken $arrResult(-spec) $arrResult(-body) -secs $arrResult(-secs) \
          -jidfrom $arrResult(-name)
    }
    $wtext mark set insert end
}

# Using the new xml based preprocessed format.

proc ::Chat::InsertHistoryXML {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate

    if {![info exists chatstate(historyfile)]} {
	return
    }    
    set fd [open $chatstate(historyfile) r]
    fconfigure $fd -encoding utf-8
    set itemL [read $fd]
    close $fd

    set wtext $chatstate(wtext)
    $wtext mark set insert 1.0

    foreach itemE $itemL {
	set itemTag [tinydom::tagname $itemE]	
	if {($itemTag ne "send") && ($itemTag ne "recv")} {
	    continue
	}
	set time [tinydom::getattribute $itemE time]
	set secs [clock scan $time]
	set body ""

	if {$itemTag eq "send"} {
	    set tag me
	} elseif {$itemTag eq "recv"} {
	    set tag you
	}
	set xmppE [lindex [tinydom::children $itemE] 0]
	set from [tinydom::getattribute $xmppE from]

	switch -- [tinydom::tagname $xmppE] {
	    message {
		set bodyE [tinydom::getfirstchildwithtag $xmppE body]
		if {$bodyE ne {}} {
		    set body [tinydom::chdata $bodyE]
		}
		set subjectE [tinydom::getfirstchildwithtag $xmppE subject]
		if {$subjectE ne {}} {
		    if {$body ne ""} {
			append body ", "
		    }
		    append body "[mc Subject]: "
		    append body [tinydom::chdata $subjectE]
		    set tag sys
		}
	    }
	    presence {
		set show [tinydom::getattribute $xmppE type]
		if {$show eq ""} {
		    set show available
		}
		set showE [tinydom::getfirstchildwithtag $xmppE show]
		if {$showE ne {}} {
		    set show [tinydom::chdata $showE]
		}
		set showStr [::Roster::MapShowToText $show]
		set body $showStr
		set statusE [tinydom::getfirstchildwithtag $xmppE status]
		if {$statusE ne {}} {
		    append body ", " [tinydom::chdata $statusE]
		}
		set tag sys
	    }
	}	
	set tagspec [list $tag history]
	InsertMessage $chattoken $tagspec $body -secs $secs -jidfrom $from
    }
    $wtext mark set insert end
}

proc ::Chat::InsertHistory {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    upvar ::Jabber::jprefs jprefs

    if {$chatstate(historytype) eq "old"} {
	InsertHistoryOld $chattoken -last $jprefs(chat,histLen)  \
	  -maxage $jprefs(chat,histAge)
    } else {
	
	# XML based preprocessed format
	InsertHistoryXML $chattoken
    }    
}

proc ::Chat::HistoryCmd {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    upvar ::Jabber::jprefs jprefs

    if {$chatstate(history) && $chatstate(havehistory)} {
	InsertHistory $chattoken
    } else {
	set wtext $chatstate(wtext)
	set ranges [$wtext tag ranges history]
	if {[llength $ranges]} {
	    $wtext configure -state normal
	    $wtext delete [lindex $ranges 0] [lindex $ranges end]
	    $wtext configure -state disabled
	}
    }
}

namespace eval ::Chat {
    
    variable buildInited 0
    variable havednd 0
}

proc ::Chat::BuildInit {} {
    variable buildInited
    variable havednd
    
    if {![catch {package require tkdnd}]} {
	set havednd 1
    }       
    set buildInited 1
}

# Chat::Build --
#
#       Builds the chat dialog.
#
# Arguments:
#       threadID    unique thread id.
#       args        ?-subject subject -from fromJid -message text?
#       
# Results:
#       dlgtoken; shows window.

proc ::Chat::Build {threadID args} {
    global  this prefs wDlgs
    
    variable uiddlg
    variable cprefs
    variable buildInited
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Chat::Build threadID=$threadID, args='$args'"
    
    if {!$buildInited} {
	BuildInit
    }

    # Initialize the state variable, an array, that keeps is the storage.
    
    set dlgtoken [namespace current]::dlg[incr uiddlg]
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    set w $wDlgs(jchat)${uiddlg}
    array set argsA $args

    set dlgstate(exists)      1
    set dlgstate(w)           $w
    set dlgstate(uid)         0
    set dlgstate(recentctokens) {}
    set dlgstate(nhiddenmsgs) 0
    
    # Toplevel with class Chat.
    ::UI::Toplevel $w -class Chat \
      -usemacmainmenu 1 -macstyle documentProc -closecommand ::Chat::CloseCmd

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    # Widget paths.
    set wtop        $w.frall.top
    set wtray       $w.frall.top.tray
    set wavatar     $w.frall.top.ava
    set wcont       $w.frall.cc        ;# container frame for wthread or wnb
    set wthread     $w.frall.fthr      ;# the chat thread widget container
    set wnb         $w.frall.nb        ;# tabbed notebook
    set dlgstate(wtop)       $wtop
    set dlgstate(wtray)      $wtray
    set dlgstate(wavatar)    $wavatar
    set dlgstate(wcont)      $wcont
    set dlgstate(wthread)    $wthread
    set dlgstate(wnb)        $wnb

    ttk::frame $wtop
    pack $wtop -side top -fill x
        
    # Shortcut button part.
    set iconSend        [::Theme::GetImage [option get $w sendImage {}]]
    set iconSendDis     [::Theme::GetImage [option get $w sendDisImage {}]]
    set iconSendFile    [::Theme::GetImage [option get $w sendFileImage {}]]
    set iconSendFileDis [::Theme::GetImage [option get $w sendFileDisImage {}]]
    set iconSave        [::Theme::GetImage [option get $w saveImage {}]]
    set iconSaveDis     [::Theme::GetImage [option get $w saveDisImage {}]]
    set iconHistory     [::Theme::GetImage [option get $w historyImage {}]]
    set iconHistoryDis  [::Theme::GetImage [option get $w historyDisImage {}]]
    set iconSettings    [::Theme::GetImage [option get $w settingsImage {}]]
    set iconSettingsDis [::Theme::GetImage [option get $w settingsDisImage {}]]
    set iconPrint       [::Theme::GetImage [option get $w printImage {}]]
    set iconPrintDis    [::Theme::GetImage [option get $w printDisImage {}]]
    set iconWB          [::Theme::GetImage [option get $w whiteboardImage {}]]
    set iconWBDis       [::Theme::GetImage [option get $w whiteboardDisImage {}]]
    set iconInvite      [::Theme::GetImage [option get $w inviteImage {}]]
    set iconInviteDis   [::Theme::GetImage [option get $w inviteDisImage {}]]

    set iconNotifier    [::Theme::GetImage [option get $w notifierImage {}]]
    set dlgstate(iconNotifier) $iconNotifier
    
    # Bug in 8.4.1 but ok in 8.4.9
    # We create the avatar widget but map it in SetAnyAvatar.
    if {[regexp {^8\.4\.[0-5]$} [info patchlevel]]} {
	label $wavatar -relief sunken -bd 1 -bg white
    } else {
	ttk::label $wavatar -style Sunken.TLabel -compound image
    }

    ::ttoolbar::ttoolbar $wtray
    grid  $wtray  x  
    grid $wtray -sticky nws
    grid columnconfigure $wtop 0 -weight 1

    $wtray newbutton send  \
      -text [mc Send] -image $iconSend   \
      -disabledimage $iconSendDis    \
      -command [list [namespace current]::Send $dlgtoken]
    $wtray newbutton sendfile \
      -text [mc {Send File}] -image $iconSendFile \
      -disabledimage $iconSendFileDis    \
      -command [list [namespace current]::SendFile $dlgtoken]
    $wtray newbutton save  \
      -text [mc Save] -image $iconSave  \
      -disabledimage $iconSaveDis    \
      -command [list [namespace current]::Save $dlgtoken]
    $wtray newbutton history  \
      -text [mc History] -image $iconHistory \
      -disabledimage $iconHistoryDis \
      -command [list [namespace current]::BuildHistory $dlgtoken]
    $wtray newbutton print  \
      -text [mc Print] -image $iconPrint  \
      -disabledimage $iconPrintDis   \
      -command [list [namespace current]::Print $dlgtoken]
    if {[::Jabber::HaveWhiteboard]} {
	$wtray newbutton whiteboard  \
	  -text [mc Whiteboard] -image $iconWB  \
	  -disabledimage $iconWBDis   \
	  -command [list [namespace current]::Whiteboard $dlgtoken]
    }
    $wtray newbutton invite \
      -text [mc Invite] -image $iconInvite \
      -disabledimage $iconInviteDis  \
      -command [list [namespace current]::Invite $dlgtoken]
    
    # D =
    ttk::separator $w.frall.divt -orient horizontal
    pack $w.frall.divt -side top -fill x

    # Having the frame with thread frame as a sibling makes it possible
    # to pack it in a different place.
    ttk::frame $wcont
    pack $wcont -side top -fill both -expand 1
    
    # Use an extra frame that contains everything thread specific.
    set chattoken [eval {
	BuildThreadWidget $dlgtoken $wthread $threadID
    } $args]
    pack $wthread -in $wcont -fill both -expand 1
    variable $chattoken
    upvar 0 $chattoken chatstate
             
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jchat)]]
    if {$nwin == 1} {
	::UI::SetWindowGeometry $w $wDlgs(jchat)
    }
    SetTitle $chattoken
    SetThreadState $dlgtoken $chattoken
 
    # We do it here to be sure that we have the chattoken.
    ::hooks::run buildChatButtonTrayHook $wtray $dlgtoken
        
    set minsize [$wtray minwidth]
    if {[lsearch [grid slaves $wtop] $wavatar] >= 0} {
	array set gridInfo [grid info $wavatar]
	incr minsize [expr 2*$gridInfo(-padx)]
	incr minsize [winfo reqwidth $wavatar]	
    }
    wm minsize $w [expr {$minsize < 220} ? 220 : $minsize] 320

    bind $w <<Find>>         [namespace code [list Find $dlgtoken]]
    bind $w <<FindAgain>>    [namespace code [list FindAgain $dlgtoken]]  
    bind $w <<FindPrevious>> [namespace code [list FindAgain $dlgtoken -1]]  
    bind $w <FocusIn>       +[namespace code [list FocusIn $dlgtoken]]
    
    # For toplevel binds.
    if {[lsearch [bindtags $w] ChatToplevel] < 0} {
	bindtags $w [linsert [bindtags $w] 0 ChatToplevel]
    }
    
    focus $w
    return $dlgtoken
}

# Chat::BuildThreadWidget --
# 
#       Builds page with all thread specific ui parts.
#       
# Arguments:
#       dlgtoken    topwindow token
#       wthread     mega widget path
#       threadID
#       
# Results:
#       chattoken

proc ::Chat::BuildThreadWidget {dlgtoken wthread threadID args} {
    global  prefs this wDlgs config
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate

    variable uidchat
    variable cprefs
    variable havednd
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Chat::BuildThreadWidget args=$args"
    array set argsA $args

    # Initialize the state variable, an array, that keeps is the storage.
    
    set chattoken [namespace current]::chat[incr uidchat]
    variable $chattoken
    upvar 0 $chattoken chatstate

    lappend dlgstate(chattokens)    $chattoken
    lappend dlgstate(recentctokens) $chattoken
    
    set jlib $jstate(jlib)

    # -from is sometimes a 3-tier jid /resource included.
    # Try to keep any /resource part unless not possible.
    
    if {[info exists argsA(-from)]} {
	set jid [$jstate(jlib) getrecipientjid $argsA(-from)]
    } else {
	return
    }
    set mjid [jlib::jidmap $jid]
    set mfrom [jlib::jidmap $argsA(-from)]
    jlib::splitjidex $jid node domain res
    set jid2 [jlib::barejid $mjid]

    # Chatting with room member must be made with full JID.
    if {[$jlib service isroom $jid2]} {
	set chatstate(minjid) $mfrom
    } else {
	set chatstate(minjid) $jid2
    }
    
    set chatstate(exists)           1
    set chatstate(fromjid)          $jid
    set chatstate(jid)              $mjid
    set chatstate(jid2)             $jid2
    set chatstate(displayname)      [::Roster::GetDisplayName $jid2]
    set chatstate(dlgtoken)         $dlgtoken
    set chatstate(threadid)         $threadID
    set chatstate(nameorjid)        [::Roster::GetNameOrJID $jid2]
    set chatstate(state)            normal    
    set chatstate(subject)          ""
    set chatstate(lastsubject)      ""
    set chatstate(subjectOld)       ""
    set chatstate(notifier)         ""
    set chatstate(active)           $cprefs(lastActiveRet)
    set chatstate(history)          1
    set chatstate(xevent,status)    ""
    set chatstate(xevent,msgidlist) ""
    set chatstate(xevent,type)      chat
    set chatstate(nhiddenmsgs)      0
    set chatstate(havehistory)      0
    set chatstate(havesent)         0
    
    set chatstate(havecs)           first
    set chatstate(chatstate)        active

    if {[info exists argsA(-subject)]} {
	set chatstate(subject) $argsA(-subject)
    }
    
    if {$jprefs(chatActiveRet)} {
	set chatstate(active) 1
    }
    
    # We need to kep track of current presence/status since we may get
    # duplicate presence (delay).
    array set presArr [$jlib roster getpresence $jid2 -resource $res]
    set chatstate(presence) $presArr(-type)
    if {[info exists presArr(-show)]} {
	set chatstate(presence) $presArr(-show)
    }
    
    # Use an extra frame that contains everything thread specific.
    ttk::frame $wthread -class ChatThread
    set w [winfo toplevel $wthread]
    set chatstate(w) $w

    SetTitle $chattoken

    set wtop        $wthread.top
    set wbot        $wthread.bot
    set wsubject    $wthread.top.e
    set wpresimage  $wthread.top.i
    set wnotifier   $wthread.bot.lnot
    set wsmile      $wthread.bot.smile
    
    # To and subject fields.
    ttk::frame $wtop
    pack $wtop -side top -anchor w -fill x
    
    set icon [::Roster::GetPresenceIconFromJid $jid]
    
    # D =
    ttk::label $wtop.l -style Small.TLabel -text "[mc Subject]:" -padding {4 0}
    ttk::entry $wtop.e -font CociSmallFont -textvariable $chattoken\(subject)
    ttk::frame $wtop.p1 -width 8
    ttk::label $wtop.i  -image $icon
    pack  $wtop.l  -side left
    pack  $wtop.i  -side right
    pack  $wtop.p1 -side right
    pack  $wtop.e  -side top -fill x

    # Special bindings for setting subject.
    bind $wsubject <FocusIn>  [list ::Chat::OnFocusInSubject $chattoken]
    bind $wsubject <FocusOut> [list ::Chat::OnFocusOutSubject $chattoken]
    bind $wsubject <Return>   [list ::Chat::OnReturnSubject $chattoken]    

    # Notifier label.
    set chatstate(wnotifier) $wnotifier
        
    # The bottom frame.
    set subPath [file join images 16]    
    set im  [::Theme::GetImage [option get $w history16Image {}] $subPath]
    set imd [::Theme::GetImage [option get $w history16DisImage {}] $subPath]
    set imH [list $im disabled $imd background $imd]

    
    ttk::frame $wbot
    ttk::checkbutton $wbot.active -style Toolbutton \
      -image [::Theme::GetImage return] \
      -command [list [namespace current]::ActiveCmd $chattoken] \
      -variable $chattoken\(active)
    set cmd [list [namespace current]::SmileyCmd $chattoken]
    ttk::checkbutton $wbot.hist -style Toolbutton \
      -image $imH -variable $chattoken\(history)  \
      -command [list [namespace current]::HistoryCmd $chattoken]
    ::Emoticons::MenuButton $wsmile -command $cmd
    ttk::label $wnotifier -style Small.TLabel \
      -textvariable $chattoken\(notifier) \
      -padding {10 0} -compound left -anchor w

    pack  $wbot         -side bottom -anchor w -fill x
    pack  $wbot.active  -side left -fill y -padx 4
    pack  $wbot.hist    -side left -fill y -padx 4
    pack  $wsmile       -side left -fill y -padx 4
    pack  $wnotifier    -side left         -padx 4
    
    ::balloonhelp::balloonforwindow $wbot.hist [mc jachathist]
    ::balloonhelp::balloonforwindow $wbot.active [mc jaactiveret]

    set wmid        $wthread.m
    set wpane       $wthread.m.pane
    set wtxt        $wthread.m.pane.frtxt
    set wtxtsnd     $wthread.m.pane.frtxtsnd        
    set wtext       $wthread.m.pane.frtxt.text
    set wysc        $wthread.m.pane.frtxt.ysc
    set wtextsnd    $wthread.m.pane.frtxtsnd.text
    set wyscsnd     $wthread.m.pane.frtxtsnd.ysc
    set wfind       $wthread.m.pane.frtxt.find

    # Frame to serve as container for the pane geometry manager.
    # D =
    frame $wmid
    pack  $wmid -side top -fill both -expand 1

    # Pane geometry manager.
    ttk::paned $wpane -orient vertical
    pack $wpane -side top -fill both -expand 1    

    # Text chat dialog.
    if {$config(ui,aqua-text)} {
	frame $wtxt
	set wcont [::UI::Text $wtext -height 12 -width 1 -state disabled -cursor {} -wrap word  \
	  -yscrollcommand [list ::UI::ScrollSet $wysc \
	  [list grid $wysc -column 1 -row 0 -sticky ns]]]
    } else {
	frame $wtxt -bd 1 -relief sunken
	text $wtext -height 12 -width 1 -state disabled -cursor {} -wrap word  \
	  -yscrollcommand [list ::UI::ScrollSet $wysc \
	  [list grid $wysc -column 1 -row 0 -sticky ns]]
	set wcont $wtext
    }
    ttk::scrollbar $wysc -orient vertical -command [list $wtext yview]
    bindtags $wtext [linsert [bindtags $wtext] 0 ReadOnlyText]
    
    grid  $wcont  -column 0 -row 0 -sticky news
    grid  $wysc   -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxt 0 -weight 1
    grid rowconfigure    $wtxt 0 -weight 1
    
    # The tags.
    ConfigureTextTags $w $wtext

    # Text send.
    if {$config(ui,aqua-text)} {
	frame $wtxtsnd
	set wcont2 [::UI::Text  $wtextsnd -height 2 -width 1 -wrap word \
	  -yscrollcommand [list ::UI::ScrollSet $wyscsnd \
	  [list grid $wyscsnd -column 1 -row 0 -sticky ns]]]
    } else {
	frame $wtxtsnd -bd 1 -relief sunken
	text  $wtextsnd -height 2 -width 1 -wrap word \
	  -yscrollcommand [list ::UI::ScrollSet $wyscsnd \
	  [list grid $wyscsnd -column 1 -row 0 -sticky ns]]
	set wcont2 $wtextsnd
    }
    ttk::scrollbar $wyscsnd -orient vertical -command [list $wtextsnd yview]
    
    grid  $wcont2    -column 0 -row 0 -sticky news
    grid  $wyscsnd   -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxtsnd 0 -weight 1
    grid rowconfigure $wtxtsnd 0 -weight 1
    
    $wpane add $wtxt -weight 1
    $wpane add $wtxtsnd -weight 1

    if {$jprefs(chatFont) ne ""} {
	$wtextsnd configure -font $jprefs(chatFont)
    }
    if {[info exists argsA(-message)]} {
	$wtextsnd insert end $argsA(-message)	
    }
    if {$chatstate(active)} {
	ActiveCmd $chattoken
    }
    
    focus $wtextsnd
   
    # jabber:x:event
    if {$cprefs(usexevents)} {
	bind $wtextsnd <KeyPress>  \
	  +[list [namespace current]::KeyPressEvent $chattoken %A]
	bind $wtextsnd <Alt-KeyPress>     {# nothing}
	bind $wtextsnd <Meta-KeyPress>    {# nothing}
	bind $wtextsnd <Control-KeyPress> {# nothing}
	bind $wtextsnd <Escape>           {# nothing}
	bind $wtextsnd <KP_Enter>         {# nothing}
	bind $wtextsnd <Tab>              {# nothing}
	if {[string equal [tk windowingsystem] "aqua"]} {
	    bind $wtextsnd <Command-KeyPress> {# nothing}
	}
    }
    bind $wtextsnd <Return>  \
      [list [namespace current]::ReturnKeyPress $chattoken]    
    bind $wtextsnd <$this(modkey)-Return> \
      [list [namespace current]::CommandReturnKeyPress $chattoken]
    if {$havednd} {
	InitDnD $chattoken $wtextsnd
    }
    
    set chatstate(wthread)  $wthread
    set chatstate(wpane)    $wpane
    set chatstate(wtext)    $wtext
    set chatstate(wtxt)     $wtxt
    set chatstate(wtextsnd) $wtextsnd
    set chatstate(wsubject) $wsubject
    set chatstate(wsmile)   $wsmile
    set chatstate(wpresimage) $wpresimage
    set chatstate(wfind)    $wfind
    
    bind $wthread <Destroy> +[list ::Chat::OnDestroyThread $chattoken]
    
    ::UI::SetSashPos $wDlgs(jchat) $wpane

    ::Avatar::GetAsyncIfExists $jid2
    SetAnyAvatar $chattoken
    
    # ?
    after idle [list raise [winfo toplevel $wthread]]
    
    return $chattoken
}

proc ::Chat::NicknameEventHook {xmldata jid nickname} {
    
    set jid2 $jid
    
    foreach chattoken [GetAllTokensFrom chat jid2 [jlib::ESC $jid2]*] {
	variable $chattoken
	upvar 0 $chattoken chatstate

	set chatstate(displayname) [::Roster::GetDisplayName $jid2]
	set chatstate(nameorjid)   [::Roster::GetNameOrJID $jid2]
	SetTitle $chattoken
    }        
}

proc ::Chat::OnFocusInSubject {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set chatstate(subjectOld) $chatstate(subject)
}

proc ::Chat::OnFocusOutSubject {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    # Reset to previous subject.
    set chatstate(subject) $chatstate(subjectOld)
}

proc ::Chat::OnReturnSubject {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    upvar ::Jabber::jstate jstate

    set dlgtoken $chatstate(dlgtoken)
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate

    set threadID $chatstate(threadid)
    set chatstate(fromjid) [$jstate(jlib) getrecipientjid $chatstate(fromjid)]
    set jid     [jlib::jidmap $chatstate(fromjid)]  
    set jid2    [jlib::barejid $jid]
    set myjid   [$jstate(jlib) myjid]
    set subject $chatstate(subject)
    $chatstate(wtext) mark set insert end
    InsertMessage $chattoken sys "[mc Subject]: $subject" -jidfrom $myjid
    set xmldata [jlib::send_message_xmllist $jid  \
       -thread $threadID -type chat -from $myjid -subject $subject]
    ::History::XPutItem send $jid2 $xmldata
    $jstate(jlib) send_message $jid -type chat -subject $subject \
      -thread $threadID
    set chatstate(subjectOld) $chatstate(subject)
    set dlgstate(lastsentsecs) [clock seconds]
    focus $chatstate(w)
}

proc ::Chat::MenuEditPostHook {wmenu} {

    if {[winfo exists [focus]]} {
	set w [winfo toplevel [focus]]
	set dlgtoken [GetTokenFrom dlg w $w]
	if {$dlgtoken eq ""} {
	    return
	}
	set chattoken [GetActiveChatToken $dlgtoken]
	if {$chattoken eq ""} {
	    return
	}
	variable $chattoken
	upvar 0 $chattoken chatstate
	
	set wfind $chatstate(wfind)
	::UI::MenuMethod $wmenu entryconfigure mFind -state normal
	if {[winfo exists $wfind]} {
	    ::UI::MenuMethod $wmenu entryconfigure mFindNext -state normal
	    ::UI::MenuMethod $wmenu entryconfigure mFindPrevious -state normal
	}
    }
}

proc ::Chat::Find {dlgtoken} {

    set chattoken [GetActiveChatToken $dlgtoken]
    if {$chattoken eq ""} {
	return
    }
    variable $chattoken
    upvar 0 $chattoken chatstate

    set wfind $chatstate(wfind)
    if {![winfo exists $wfind]} {
	UI::WSearch $wfind $chatstate(wtext) -padding {6 2}
	grid  $wfind  -column 0 -row 2 -columnspan 2 -sticky ew
    }
}

proc ::Chat::FindAgain {dlgtoken {dir 1}} {

    set chattoken [GetActiveChatToken $dlgtoken]
    if {$chattoken eq ""} {
	return
    }
    variable $chattoken
    upvar 0 $chattoken chatstate

    set wfind $chatstate(wfind)
    if {[winfo exists $wfind]} {
	$wfind [expr {$dir == 1 ? "Next" : "Previous"}]
    }
}

proc ::Chat::InitDnD {chattoken win} {
    
    dnd bindtarget $win text/uri-list <Drop>      \
     [list ::Chat::DnDDrop $chattoken %W %D %T]
    dnd bindtarget $win text/uri-list <DragEnter> \
     [list ::Chat::DnDEnter $chattoken %W %A %D %T]
    dnd bindtarget $win text/uri-list <DragLeave> \
     [list ::Chat::DnDLeave $chattoken %W %D %T]
}

proc ::Chat::DnDDrop {chattoken win data dndtype} {
    variable $chattoken
    upvar 0 $chattoken chatstate

    # Take only first file.
    set f [lindex $data 0]
	
    # Strip off any file:// prefix.
    set f [string map {file:// ""} $f]
    set f [uriencode::decodefile $f]

    ::FTrans::Send $chatstate(jid) -filename $f
}

proc ::Chat::DnDEnter {chattoken win action data dndtype} {
    focus $win
    set act "none"
    return $act
}

proc ::Chat::DnDLeave {chattoken win data dndtype} {	
    focus [winfo toplevel $win] 
}

proc ::Chat::OnDestroyThread {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    Debug 4 "::Chat::OnDestroyThread chattoken=$chattoken"
    # For some strange reason [info vars ..] seem to find nonexisting variables.

    #Trigger Close chatstate
    if {$chatstate(havecs) eq "true"} {
        ChangeChatState $chattoken close
        SendChatState $chattoken $chatstate(chatstate)
    }
    DeregisterPresence $chattoken

    unset $chattoken
    array unset $chattoken    
}

proc ::Chat::SetTitle {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
        
    set str "[mc mChat]: $chatstate(displayname)"
    if {$chatstate(displayname) ne $chatstate(fromjid)} {
	set ujid [jlib::unescapestr $chatstate(fromjid)]
	append str " ($ujid)"
    }

    # Put an extra (*) in the windows title if not in focus.
    set dlgtoken $chatstate(dlgtoken)
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate

    if {$dlgstate(nhiddenmsgs) > 0} {
	set wfocus [focus]
	set n $dlgstate(nhiddenmsgs)
	if {$n > 0} {
	    if {$wfocus eq ""} {
		append str " ($n)"
	    } elseif {[winfo toplevel $wfocus] ne $chatstate(w)} {
		append str " ($n)"
	    }
	}
    }
    wm title $chatstate(w) $str
}

proc ::Chat::SetAnyAvatar {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set dlgtoken $chatstate(dlgtoken)
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate

    set wavatar $dlgstate(wavatar)
    set avatar [::Avatar::GetPhotoOfSize $chatstate(jid2) 32]
    if {$avatar eq ""} {
	grid forget $wavatar
    } else {

	# Make sure it is mapped
	set padx 10
	grid  $wavatar  -column 1 -row 0 -padx $padx -pady 4
	$wavatar configure -image $avatar
	
	set mintray [$dlgstate(wtray) minwidth]
	set minava [winfo reqwidth $wavatar]
	set min [expr {$mintray + $minava + 2*$padx}]
	
	wm minsize $dlgstate(w) [expr {$min < 220} ? 220 : $min] 320
    }    
}

# Chat::AvatarNewPhotoHook --
# 
#       Gets called when ANY avatar is updated or created.

proc ::Chat::AvatarNewPhotoHook {jid2} {
    
    foreach chattoken [GetAllTokensFrom chat jid2 [jlib::ESC $jid2]*] {
	SetAnyAvatar $chattoken
    }    
}

# Chat::NewPage, ... --
# 
#       Several procs to handle the tabbed interface; creates and deletes
#       notebook and pages.

proc ::Chat::NewPage {dlgtoken threadID args} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    upvar ::Jabber::jprefs jprefs
        
    # If no notebook, move chat widget to first notebook page.
    if {[string equal [winfo class [pack slaves $dlgstate(wcont)]] "ChatThread"]} {
	set wthread $dlgstate(wthread)
	set chattoken [lindex $dlgstate(chattokens) 0]
	variable $chattoken
	upvar 0 $chattoken chatstate

	# Repack the ChatThread in notebook page.
	MoveThreadToPage $dlgtoken $chattoken
	DrawCloseButton $dlgtoken
    } 

    # Make fresh page with chat widget.
    set chattoken [eval {MakeNewPage $dlgtoken $threadID} $args]
    return $chattoken
}

proc ::Chat::DrawCloseButton {dlgtoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    # Close button (exp). 
    set w $dlgstate(w)
    
    set subPath [file join images 16]    
    set im  [::Theme::GetImage [option get $w tabClose16Image {}] $subPath]
    set ima [::Theme::GetImage [option get $w tabCloseActive16Image {}] $subPath]
    set wclose $dlgstate(wnb).close

    ttk::button $wclose -style Plain  \
      -image [list $im active $ima] -compound image  \
      -command [list [namespace current]::ClosePageCmd $dlgtoken]
    place $wclose -anchor ne -relx 1.0 -x -6 -y 6

    ::balloonhelp::balloonforwindow $wclose [mc "Close page"]
    set dlgstate(wclose) $wclose
}

proc ::Chat::MoveThreadToPage {dlgtoken chattoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    # Repack the  in notebook page.
    set wnb      $dlgstate(wnb)
    set wcont    $dlgstate(wcont)
    set wthread  $chatstate(wthread)
    set dispname $chatstate(displayname)
    
    pack forget $wthread

    ttk::notebook $wnb
    bind $wnb <<NotebookTabChanged>> \
      [list [namespace current]::TabChanged $dlgtoken]
    ttk::notebook::enableTraversal $wnb
    pack $wnb -in $wcont -fill both -expand true -side right

    set wpage $wnb.p[incr dlgstate(uid)]
    ttk::frame $wpage
    $wnb add $wpage -sticky news -text $dispname -compound left
    pack $wthread -in $wpage -fill both -expand true -side right
    raise $wthread
    
    set chatstate(wpage) $wpage
    set dlgstate(wpage2token,$wpage) $chattoken
}

proc ::Chat::MakeNewPage {dlgtoken threadID args} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    variable uidpage
    array set argsA $args
        
    # Make fresh page with chat widget.
    set dispname [::Roster::GetDisplayName $argsA(-from)]
    set wnb $dlgstate(wnb)
    set wpage $wnb.p[incr dlgstate(uid)]
    ttk::frame $wpage
    $wnb add $wpage -sticky news -text $dispname -compound left

    # We must make the new page a sibling of the notebook in order to be
    # able to reparent it when notebook gons.
    set wthread $dlgstate(wthread)[incr uidpage]
    set chattoken [eval {
	BuildThreadWidget $dlgtoken $wthread $threadID
    } $args]
    pack $wthread -in $wpage -fill both -expand true

    variable $chattoken
    upvar 0 $chattoken chatstate
    set chatstate(wpage) $wpage
    set dlgstate(wpage2token,$wpage) $chattoken
    
    return $chattoken
}

proc ::Chat::CloseThreadPage {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set dlgtoken $chatstate(dlgtoken)
    DeletePage $chattoken
    set newchattoken [GetActiveChatToken $dlgtoken]

    # Set state of new page.
    SetThreadState $dlgtoken $newchattoken
}

proc ::Chat::DeletePage {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set dlgtoken $chatstate(dlgtoken)
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    set wpage $chatstate(wpage)
    $dlgstate(wnb) forget $wpage
    unset dlgstate(wpage2token,$wpage)
    
    # Delete the actual widget.
    set dlgstate(chattokens)  \
      [lsearch -all -inline -not $dlgstate(chattokens) $chattoken]
    destroy $chatstate(wthread)
    
    # If only a single page left then reparent and delete notebook.
    if {[llength $dlgstate(chattokens)] == 1} {
	set chattoken [lindex $dlgstate(chattokens) 0]
	variable $chattoken
	upvar 0 $chattoken chatstate

	MoveThreadFromPage $dlgtoken $chattoken
    }
}

proc ::Chat::MoveThreadFromPage {dlgtoken chattoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set wnb     $dlgstate(wnb)
    set wcont   $dlgstate(wcont)
    set wthread $chatstate(wthread)
    
    # This seems necessary on mac in order to not get a blank page.
    update idletasks

    pack forget $wthread
    destroy $wnb
    pack $wthread -in $wcont -fill both -expand 1
    
    SetThreadState $dlgtoken $chattoken
}

proc ::Chat::ClosePageCmd {dlgtoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    set chattoken [GetActiveChatToken $dlgtoken]
    if {$chattoken ne ""} {	
	CloseThreadPage $chattoken
    }
}

# Chat::SelectPage --
# 
#       Make page frontmost.

proc ::Chat::SelectPage {chattoken} {    
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set dlgtoken $chatstate(dlgtoken)
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    if {[winfo exists $dlgstate(wnb)]} {
	$dlgstate(wnb) select $chatstate(wpage)
    }
}

# Chat::TabChanged --
# 
#       Callback command from notebook widget when selecting new tab.

proc ::Chat::TabChanged {dlgtoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    Debug 2 "::Chat::TabChanged"

    set wnb $dlgstate(wnb)
    set wpage [GetNotebookWpageFromIndex $wnb [$wnb index current]]
    set chattoken $dlgstate(wpage2token,$wpage)

    variable $chattoken
    upvar 0 $chattoken chatstate

    set chatstate(nhiddenmsgs) 0

    # Trigger Focus chatstate
    if {$chatstate(havecs) eq "true"} {
        set chattokens $dlgstate(chattokens)
        foreach ichattoken $chattokens {
            if { $ichattoken eq $chattoken } {
                ChangeChatState $ichattoken focus
            } else {
                ChangeChatState $ichattoken lostfocus
            }
            upvar 0 $ichattoken ichatstate
            SendChatState $ichattoken $ichatstate(chatstate)
        }
    }

    SetThreadState $dlgtoken $chattoken
    SetFocus $dlgtoken $chattoken
    
    lappend dlgstate(recentctokens) $chattoken
    set dlgstate(recentctokens) [lrange $dlgstate(recentctokens) end-1 end]
    
    ::hooks::run chatTabChangedHook $chattoken
}

proc ::Chat::GetNotebookWpageFromIndex {wnb index} {
    
    set wpage ""
    foreach w [$wnb tabs] {
	if {[$wnb index $w] == $index} {
	    set wpage $w
	    break
	}
    }
    return $wpage
}

proc ::Chat::SetThreadState {dlgtoken chattoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate

    variable $chattoken
    upvar 0 $chattoken chatstate
    upvar ::Jabber::jstate jstate

    Debug 6 "::Chat::SetThreadState chattoken=$chattoken"
    
    jlib::splitjid $chatstate(jid) user res
    if {[$jstate(jlib) roster isavailable $user]} {
	SetState $chattoken normal
    } else {
	SetState $chattoken disabled
    }
    if {[winfo exists $dlgstate(wnb)]} {
	$dlgstate(wnb) tab $chatstate(wpage) -image ""  \
	  -text $chatstate(displayname)
    }
    SetTitle $chattoken
    SetAnyAvatar $chattoken
    SetState $chattoken normal
}

# Chat::SetState --
# 
#       Set state of complete dialog to normal or disabled.
  
proc ::Chat::SetState {chattoken state} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    Debug 4 "::Chat::SetState chattoken=$chattoken, state=$state"
    
    if {[string equal $state $chatstate(state)]} {
	#return
    }
    set dlgtoken $chatstate(dlgtoken)
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate    
    
    set wtray $dlgstate(wtray)
    foreach name {send sendfile} {
	$wtray buttonconfigure $name -state $state 
    }
    if {[$wtray exists whiteboard] && ![::Roster::IsCoccinella $chatstate(jid)]} {
	$wtray buttonconfigure whiteboard -state disabled
    }	
    $chatstate(wtextsnd) configure -state $state
    $chatstate(wsubject) configure -state $state
    $chatstate(wsmile)   configure -state $state
    set chatstate(state) $state
}

# Chat::SetFocus --
# 
#       When selecting a new page we must move focus along.
#       This does not work reliable on MacOSX.

proc ::Chat::SetFocus {dlgtoken chattoken} {
    global  this
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate

    variable $chattoken
    upvar 0 $chattoken chatstate
	
    # Try remember any previous focus on previous page.
    # Important: the page must still exist! Else we get wrong token list.
    if {[llength dlgstate(recentctokens)]} {
	set ctoken [lindex $dlgstate(recentctokens) end]
	variable $ctoken
	upvar 0 $ctoken cstate
	if {[info exists cstate(w)]} {
	    set cstate(focus) [focus]
	}
    }
    if {[info exists chatstate(focus)]} {
	set wfocus $chatstate(focus)
    } else {
	set wfocus $chatstate(wtextsnd)
    }
    
    # This seems to be needed on macs.
    if {[string equal $this(platform) "macosx"]} {
	update idletasks
    }

    catch {focus $wfocus}
}

# Chat::GetDlgTokenValue, GetChatTokenValue --
# 
#       Outside code shall use these to get array values.

proc ::Chat::GetDlgTokenValue {dlgtoken key} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    return $dlgstate($key)
}

proc ::Chat::GetChatTokenValue {chattoken key} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    return $chatstate($key)
}

# Chat::GetActiveChatToken --
# 
#       Returns the chattoken corresponding to the frontmost thread.

proc ::Chat::GetActiveChatToken {dlgtoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    if {[winfo exists $dlgstate(wnb)]} {
	set wnb $dlgstate(wnb)
	set wpage [GetNotebookWpageFromIndex $wnb [$wnb index current]]
	set chattoken $dlgstate(wpage2token,$wpage)
    } else {
	set chattoken [lindex $dlgstate(chattokens) 0]
    }
    return $chattoken
}

proc ::Chat::TabAlert {chattoken args} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set dlgtoken $chatstate(dlgtoken)
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    if {[winfo exists $dlgstate(wnb)]} {
	set w       $dlgstate(w)
	set wnb     $dlgstate(wnb)
	
	# Show only if not current page.
	if {[GetActiveChatToken $dlgtoken] != $chattoken} {
	    incr chatstate(nhiddenmsgs)
	    set postfix " ($chatstate(nhiddenmsgs))"
	    set name $chatstate(displayname)
	    append name " " "($chatstate(nhiddenmsgs))"
	    set icon [::Theme::GetImage [option get $w tabAlertImage {}]]
	    $wnb tab $chatstate(wpage) -image $icon -text $name
	}
    }
}

proc ::Chat::FocusIn {dlgtoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    set dlgstate(nhiddenmsgs) 0
    SetTitle [GetActiveChatToken $dlgtoken]
}

proc ::Chat::SmileyCmd {chattoken im key} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    Emoticons::InsertSmiley $chatstate(wtextsnd) $im $key
}

# Chat::LoginHook, ... --
# 
#       Various hooks.

proc ::Chat::LoginHook { } {
    variable cprefs
    upvar ::Jabber::jstate jstate

    # Must keep track of last own jid.
    set cprefs(lastmejid) $jstate(mejidmap)
    BuildSavedDialogs
    
    return
}

proc ::Chat::LogoutHook { } {
    
    foreach dlgtoken [GetTokenList dlg] {
	variable $dlgtoken
	upvar 0 $dlgtoken dlgstate

	foreach chattoken $dlgstate(chattokens) {
	    SetState $chattoken disabled
	    
	    # Necessary to "zero" all presence.
	    variable $chattoken
	    upvar 0 $chattoken chatstate
	    
	    set chatstate(presence) unavailable
	}
    }
    SaveDialogs
    return
}

# Chat::Invite --
#
#      MUC 6.8. Converting One-to-One Chat Into a Conference 
#      
#      0: Creates a new room (which SHOULD be non-anonymous and MAY be an 
#         instant room as specified below) 
#      1: Optionally sends history of the one-to-one chat to the room 
#      2: Sends an invitation to the second person and the third person, 
#         including a <continue/> flag. 
#      
#      Note: Use of the Delayed Delivery protocol enables the room creator to 
#      specify the datetime of each message from the one-to-one chat history 
#      (via the 'stamp' attribute), as well as JID of the original sender of 
#      each message (via the 'from' attribute). The room creator SHOULD send 
#      the complete one-to-one chat history before inviting additional users 
#      to the room, and SHOULD also send as history any messages appearing in 
#      the one-to-one chat interface after joining the room and before the 
#      second person joins the room.
#      
# Arguments:
#       dlgtoken    topwindow token

proc ::Chat::Invite {dlgtoken} {
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
 
    set chattoken [GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate

    # First Create the Room 
    set timeStamp [clock format [clock seconds] -format %m%j%Y]
    set myjid [::Jabber::GetMyJid]
    jlib::splitjidex $myjid node host res 

    set chatservers [$jstate(jlib) disco getconferences]
    if {0 && $chatservers eq {}} {
	::UI::MessageBox -icon error -title [mc Error] \
	  -message [mc jamessnogroupchat2]
	return
    }
    set server [lindex $chatservers 0]
    set roomName "$node$timeStamp"
    set roomjid [jlib::joinjid $roomName $server ""]

    set result [::Create::Build -nickname $node -server $server \
      -roomname $roomName]
    if { $result eq "create" } {
	
	# Second Send History to MUC

	set jid2 $chatstate(jid2)
	if {[::Jabber::JlibCmd service isroom $jid2]} {
	    set jidH $chatstate(jid)	
	} else {
	    set jidH $jid2	
	}

	# We must reparse the history to get the latest.
	set itemL [::History::XFastParseFiles $jidH  \
	  $jprefs(chat,histLen) $jprefs(chat,histAge)]
	foreach itemE $itemL {
	    set xmppE [lindex [tinydom::children $itemE] 0]
	    if {[tinydom::tagname $xmppE] eq "message"} {
		set time [tinydom::getattribute $itemE time]
		set from [tinydom::getattribute $xmppE from]
		set xattr [list xmlns jabber:x:delay from $from stamp $time]
		set xelem [wrapper::createtag "x" -attrlist $xattr]
		set bodyE [tinydom::getfirstchildwithtag $xmppE body]
		if {$bodyE ne {}} {
		    set body [tinydom::chdata $bodyE]
		} else {
		    set body ""
		}
		$jstate(jlib) send_message $roomjid -type groupchat  \
		  -body $body -xlist [list $xelem]
	    }
	}

	# Third Invite the second user
	set opts [list -reason [mc mucChat2ConfInv] -continue true]
	eval {$jstate(jlib) muc invite $roomjid $chatstate(fromjid)} $opts

	# Third and Invite the third user
	::MUC::Invite $roomjid 1
    }
}

proc ::Chat::QuitHook { } {
    global  wDlgs
    
    ::UI::SaveWinGeom $wDlgs(jstartchat)
    ::UI::SaveWinPrefixGeom $wDlgs(jchat)
    GetFirstSashPos
    SaveDialogs
    
    # This sends cancel compose to all.
    foreach dlgtoken [GetTokenList dlg] {
	Close $dlgtoken
    }
    return
}

proc ::Chat::BuildSavedDialogs { } {
    variable cprefs
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    if {!$jprefs(rememberDialogs)} {
	return
    }
    if {$jprefs(chat,dialogs) == {}} {
	return
    }
    set mejidmap $jstate(mejidmap)
    array set dlgArr $jprefs(chat,dialogs)
    if {![info exists dlgArr($mejidmap)]} {
	return
    }
    
    # Build dialog only if not exists.
    foreach spec $dlgArr($mejidmap) {
	set jid  [lindex $spec 0]
	set opts [lindex $spec 1 end]
	set chattoken [GetTokenFrom chat jid [jlib::ESC $jid]*]
	if {$chattoken eq ""} {
	    set chattoken [StartThread $jid]
	    InsertHistory $chattoken
	}
    }
}

proc ::Chat::SaveDialogs { } {
    variable cprefs
    upvar ::Jabber::jprefs jprefs
    
    if {!$jprefs(rememberDialogs)} {
	return
    }
    if {![info exists cprefs(lastmejid)]} {
	return
    }
    set mejidmap $cprefs(lastmejid)
    array set dlgArr $jprefs(chat,dialogs)
    #array unset dlgArr [ESCglobs $mejidmap]
    unset -nocomplain dlgArr($mejidmap)
    
    foreach chattoken [GetTokenList chat] {
	variable $chattoken
	upvar 0 $chattoken chatstate

	lappend dlgArr($mejidmap) [list $chatstate(jid2)]
    }
    set jprefs(chat,dialogs) [array get dlgArr]
}

proc ::Chat::ConfigureTextTags {w wtext} {
    variable chatOptions
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Chat::ConfigureTextTags jprefs(chatFont)=$jprefs(chatFont)"
    
    set space 2
    set alltags {mepre metext youpre youtext syspre systext histhead}
        
    if {[string length $jprefs(chatFont)]} {
	set chatFont $jprefs(chatFont)
    } else {
	set chatFont [option get $wtext font Font]
    }
    set boldChatFont [lreplace $jprefs(chatFont) 2 2 bold]
    set foreground [$wtext cget -foreground]

    foreach tag $alltags {
	set opts($tag) [list -spacing1 $space -foreground $foreground]
    }
    foreach spec $chatOptions {
	lassign $spec tag optName resName resClass
	set value [option get $w $resName $resClass]
	if {[string equal $optName "-font"]} {
	    
	    switch $resName {
		mePreFont - youPreFont - sysPreFont {
		    set value $chatFont
		}
		meTextFont - youTextFont - sysTextFont {
		    set value $chatFont
		}
	    }
	}
	if {[string length $value]} {
	    lappend opts($tag) $optName $value
	}   
    }
    lappend opts(metext)   -spacing3 $space -lmargin1 20 -lmargin2 20
    lappend opts(youtext)  -spacing3 $space -lmargin1 20 -lmargin2 20
    lappend opts(systext)  -spacing3 $space -lmargin1 20 -lmargin2 20
    lappend opts(histhead) -spacing1 4 -spacing3 4 -lmargin1 20 -lmargin2 20

    foreach tag $alltags {
	eval {$wtext tag configure $tag} $opts($tag)
    }
    
    # History tags.
    foreach tag $alltags {
	set htag ${tag}-history
	array unset arr
	array set arr $opts($tag)
	set arr(-foreground) [::colorutils::getlighter $arr(-foreground)]
	eval {$wtext tag configure $htag} [array get arr]
    }
}

# Chat::SetFont --
# 
#       Sets the chat font in all text widgets.

proc ::Chat::SetFont {theFont} {    
    upvar ::Jabber::jprefs jprefs

    ::Debug 2 "::Chat::SetFont theFont=$theFont"
    
    # If theFont is empty it means the default font.
    set jprefs(chatFont) $theFont
        
    foreach chattoken [GetTokenList chat] {
	variable $chattoken
	upvar 0 $chattoken chatstate

	if {![info exists chatstate(w)]} {
	    continue
	}
	set w $chatstate(w)
	if {[winfo exists $w]} {
	    ConfigureTextTags $w $chatstate(wtext)
	    if {$jprefs(chatFont) eq ""} {
		
		# This should be the font set throught the option database.
		$chatstate(wtextsnd) configure -font \
		  [option get $chatstate(wtext) font Font]		
	    } else {
		$chatstate(wtextsnd) configure -font $jprefs(chatFont)
	    }
	} else {
	    unset -nocomplain chatstate
	}
    }
}

proc ::Chat::ActiveCmd {chattoken} {
    variable cprefs
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    # Remember last setting.
    set cprefs(lastActiveRet) $chatstate(active)
}

# Suggestion from marc@bruenink.de.
# 
#       inactive mode: 
#       Ret: word-wrap
#       Ctrl+Ret: send message
#
#       active mode:
#       Ret: send message
#       Ctrl+Ret: word-wrap

proc ::Chat::ReturnKeyPress {chattoken} {
    variable cprefs
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    if {$chatstate(active)} {
	Send $chatstate(dlgtoken)
	
	# Stop further handling in Text.
	return -code break
    } 
}

proc ::Chat::CommandReturnKeyPress {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate

    if {!$chatstate(active)} {
	Send $chatstate(dlgtoken)

	# Stop further handling in Text.
	return -code break
    }
}

proc ::Chat::Send {dlgtoken} {
    global  prefs
    
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    variable cprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::xmppxmlns xmppxmlns
    
    ::Debug 2 "::Chat::Send "
    
    set jlib $jstate(jlib)

    # Check that still connected to server.
    if {![::Jabber::IsConnected]} {
	::UI::MessageBox -type ok -icon error -title [mc Error] \
	  -message [mc jamessnotconnected2]
	return
    }
    set chattoken [GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate

    set w        $chatstate(w)
    set wtextsnd $chatstate(wtextsnd)
    set threadID $chatstate(threadid)
    
    # According to XMPP we should send to 3-tier jid if still online,
    # else to 2-tier.
    set chatstate(fromjid) [$jstate(jlib) getrecipientjid $chatstate(fromjid)]
    set jid [jlib::jidmap $chatstate(fromjid)]
    set jid2 [jlib::barejid $jid]
    set chatstate(jid) $jid
    
    if {![jlib::jidvalidate $jid]} {
	set ans [::UI::MessageBox -message [mc jamessbadjid2 $jid] \
	  -icon error -title [mc Error] -type yesno]
	if {[string equal $ans "no"]} {
	    return
	}
    }

    # Get text to send. Strip off any ending newlines.
    # There might by smiley icons in the text widget. Parse them to text.
    set text [::Text::TransformToPureText $wtextsnd]
    set text [string trimright $text]
    $wtextsnd delete 1.0 end
    if {$text eq ""} {
	return
    }
   
    # Have hook for complete text.
    if {[hooks::run sendTextChatHook $jid $text] eq "stop"} {	    
	return
    }

    # This is important since clicks may have reset the insert mark.
    $chatstate(wtext) mark set insert end

    # Need to detect if subject changed. If subject was changed it was already
    # sent alone but some clients (Psi) doesn't recognize this why it is
    # duplicated here. Good/bad? Skip!
    set opts {}
    if {0} {
	if {![string equal $chatstate(subject) $chatstate(lastsubject)]} {
	    lappend opts -subject $chatstate(subject)
	    InsertMessage $chattoken sys "[mc Subject]: $chatstate(subject)"
	}
    }
    set chatstate(lastsubject) $chatstate(subject)
    
    # Cancellations of any message composing jabber:x:event
    if {$cprefs(usexevents) &&  \
      [string equal $chatstate(xevent,status) "composing"]} {
	XEventSendCancelCompose $chattoken
    }
    set xlist [list]
    
    # Requesting composing notification.
    if {$cprefs(usexevents)} {
	lappend opts -id [incr cprefs(xeventid)]
	lappend xlist [wrapper::createtag "x" -attrlist {xmlns jabber:x:event} \
	  -subtags [list [wrapper::createtag "composing"]]]
    }


    #-- The <active ...> tag is only sended in the first message, 
    #-- for next messages we have to check if the contact has reply to us with the same active tag
    #-- this check is done with chatstate(havecs) but we need to send for first anyway
    set cselems [list]
    if { ($chatstate(havecs) eq "first") || ($chatstate(havecs) eq "true") } {
        #-- The cselems is sended for first and then wait for a right reply 
        if {$chatstate(havecs) eq "first"} {
            set chatstate(havecs) false
        }
        ChangeChatState $chattoken send
	set csE [wrapper::createtag $chatstate(chatstate) \
	  -attrlist [list xmlns $xmppxmlns(chatstates)]]
        lappend cselems $csE
        lappend xlist $csE
    }
    
    # Handle any nickname. Only first message.
    if {!$chatstate(havesent) && ![$jlib roster isitem $jid2]} {
	set nickname [::Profiles::GetSelected -nickname]
	if {$nickname ne ""} {
	    lappend xlist [::Nickname::Element $nickname]
	}
    }     
    if {[llength $xlist]} {
	lappend opts -xlist $xlist
    }
    
    # Put in history file.
    # Need to reconstruct our xmldata. Add -from for our history record.
    set myjid [::Jabber::JlibCmd myjid]
    set xmldata [eval {jlib::send_message_xmllist $jid  \
       -thread $threadID -type chat -body $text -from $myjid} $opts]
    ::History::XPutItem send $jid2 $xmldata

    eval {$jlib send_message $jid -thread $threadID -type chat -body $text} $opts

    set dlgstate(lastsentsecs) [clock seconds]
    
    # Add to chat window.        
    InsertMessage $chattoken me $text

    set chatstate(havesent) 1
    
    set opts [list -from $jid2]
    eval {::hooks::run displayChatMessageHook $text} $opts
}

proc ::Chat::TraceJid {dlgtoken name junk1 junk2} {
    variable $dlgtoken 
    upvar 0 $dlgtoken dlgstate
    
    # Call by name.
    upvar $name locName    
    wm title $dlgstate(w) "[mc mChat] ($chatstate(fromjid))"
}

proc ::Chat::SendFile {dlgtoken} {
     
    set chattoken [GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    ::FTrans::Send $chatstate(fromjid)

    #jlib::splitjid $chatstate(fromjid) jid2 res
    #::OOB::BuildSet $jid2
}

proc ::Chat::Settings {dlgtoken} {
    
    ::Preferences::Show {Jabber Chat}
}

proc ::Chat::Print {dlgtoken} {
    
    set chattoken [GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate

    ::UserActions::DoPrintText $chatstate(wtext)
}

proc ::Chat::Whiteboard {dlgtoken} {
    
    set chattoken [GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate

    set jid $chatstate(jid)
    if {![::JWB::HaveWhiteboard $jid]} {
	::JWB::NewWhiteboardTo $jid -type chat
    }
}

proc ::Chat::Save {dlgtoken} {
    global  this
    
    set chattoken [GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate

    set wtext $chatstate(wtext)
    
    set ans [tk_getSaveFile -title [mc Save] \
      -initialfile "Chat $chatstate(fromjid).txt"]
    
    if {[string length $ans]} {
	set allText [::Text::TransformToPureText $wtext]
	set fd [open $ans w]
	fconfigure $fd -encoding utf-8
	puts $fd "Chat with:\t$chatstate(fromjid)"
	puts $fd "Subject:\t$chatstate(subject)"
	puts $fd "\n"
	puts $fd $allText	
	close $fd
	if {[string equal $this(platform) "macintosh"]} {
	    file attributes $ans -type TEXT -creator ttxt
	}
    }
}

# Chat::RegisterPresence, DeregisterPresence, PresenceEvent --
# 
#       Handles all presence changes for chattoken.

proc ::Chat::RegisterPresence {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    # If we chat with a room member we shall not trigger on other JIDs.
    # Important: we register per chattoken and not per JID to allow
    # multiple threads per JID!
    set jid2 $chatstate(jid2)
    if {[::Jabber::JlibCmd service isroom $jid2]} {
	set presenceReg  \
	  [list [namespace code [list PresenceEvent $chattoken]] \
	  -from $chatstate(jid)]
    } else {
	set presenceReg  \
	  [list [namespace code [list PresenceEvent $chattoken]] \
	  -from2 $jid2]
    }
    
    # Cache it so it gets properly deregistered.
    set chatstate(presenceReg) $presenceReg
    eval {::Jabber::JlibCmd presence_register_ex} $presenceReg
}

proc ::Chat::DeregisterPresence {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    eval {::Jabber::JlibCmd presence_deregister_ex} $chatstate(presenceReg)
}

proc ::Chat::PresenceEvent {chattoken jlibname xmldata} {
    
    variable $chattoken
    upvar 0 $chattoken chatstate

    set from [wrapper::getattribute $xmldata from]
    set type [wrapper::getattribute $xmldata type]
    if {$type eq ""} {
	set type available
    }
    set show $type
    set showE [wrapper::getfirstchildwithtag $xmldata show]
    if {[llength $showE]} {
	set show [string tolower [wrapper::getcdata $showE]]
    }
        
    # Skip if duplicate presence. Bug?
    if {[string equal $chatstate(presence) $show]} {
	return
    }
    set status ""
    set statusE [wrapper::getfirstchildwithtag $xmldata status]
    if {[llength $statusE]} {
	set status [string tolower [wrapper::getcdata $statusE]]
    }

    # This is important since clicks may have reset the insert mark.
    $chatstate(wtext) mark set insert end

    set showStr [::Roster::MapShowToText $show]
    if {$status ne ""} {
	append showStr ", " $status
    }
    InsertMessage $chattoken sys $showStr
    ::History::XPutItem recv $chatstate(minjid) $xmldata
    
    if {[string equal $type "available"]} {
	SetState $chattoken normal
    } else {
	
	# There have been complaints about this...
	#SetState $chattoken disabled
    }
    set icon [::Roster::GetPresenceIconFromJid $from]
    if {$icon ne ""} {
	$chatstate(wpresimage) configure -image $icon
    }    
    set chatstate(presence) $show
    XEventCancel $chattoken
}

# Chat::GetWindow --
# 
#       Returns toplevel window if have chat, else empty.

proc ::Chat::GetWindow {jid} {

    set jid2 [jlib::barejid $jid]
    set mjid2 [jlib::jidmap $jid2]
    set chattoken [GetTokenFrom chat jid [jlib::ESC $mjid2]*]
    if {$chattoken ne ""} {
	variable $chattoken
	upvar 0 $chattoken chatstate

	if {[winfo exists $chatstate(w)]} {
	    return $chatstate(w)
	} else {
	    return
	}
    } else {
	return
    }
}

proc ::Chat::HaveChat {jid} {
 
    if {[GetWindow $jid] eq ""} {
	return 0
    } else {
	return 1
    }
}

# Chat::GetTokenFrom --
# 
#       Try to get the token state array from any stored key.
#       Only one token is returned if any.
#       
# Arguments:
#       type        'dlg' or 'chat'
#       key         w, jid, threadid etc...
#       pattern     glob matching
#       
# Results:
#       token or empty if not found.

proc ::Chat::GetTokenFrom {type key pattern} {
    
    # Search all tokens for this key into state array.
    foreach token [GetTokenList $type] {
	
	switch -- $type {
	    dlg {
		variable $token
		upvar 0 $token xstate
	    }
	    chat {
		variable $token
		upvar 0 $token xstate
	    }
	}	
	if {[info exists xstate($key)] && [string match $pattern $xstate($key)]} {
	    return $token
	}
    }
    return
}

# Chat::GetAllTokensFrom --
# 
#       As above but all tokens.

proc ::Chat::GetAllTokensFrom {type key pattern} {
    
    set alltokens [list]
    
    # Search all tokens for this key into state array.
    foreach token [GetTokenList $type] {
	
	switch -- $type {
	    dlg {
		variable $token
		upvar 0 $token xstate
	    }
	    chat {
		variable $token
		upvar 0 $token xstate
	    }
	}	
	if {[info exists xstate($key)] && [string match $pattern $xstate($key)]} {
	    lappend alltokens $token
	}
    }
    return $alltokens
}

proc ::Chat::GetFirstDlgToken { } {
 
    set token ""
    set dlgtokens [GetTokenList dlg]
    foreach dlgtoken $dlgtokens {
	variable $dlgtoken
	upvar 0 $dlgtoken dlgstate    
	
	if {[winfo exists $dlgstate(w)]} {
	    set token $dlgtoken
	    break
	}
    }
    return $token
}

# Chat::GetTokenList --
# 
# Arguments:
#       type        'dlg' or 'chat'

proc ::Chat::GetTokenList {type} {
    
    # For some strange reason [info vars] reports non existing arrays.
    set nskey [namespace current]::$type
    set tokens [list]
    foreach token [concat  \
      [info vars ${nskey}\[0-9\]] \
      [info vars ${nskey}\[0-9\]\[0-9\]] \
      [info vars ${nskey}\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${nskey}\[0-9\]\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${nskey}\[0-9\]\[0-9\]\[0-9\]\[0-9\]\[0-9\]]] {
	if {[array exists $token]} {
	    variable $token
	    upvar 0 $token state    
	    if {[info exists state(exists)]} {
		lappend tokens $token   
	    }
	}
    }
    return $tokens
}

# Chat::CloseCmd --
# 
#       This gets called from toplevels -closecommand 

proc ::Chat::CloseCmd {wclose} {

    set dlgtoken [GetTokenFrom dlg w $wclose]
    if {$dlgtoken ne ""} {
	return [Close $dlgtoken]
    } else {
	return
    }
}

# Chat::Close --
#
#

proc ::Chat::Close {dlgtoken} {
    global  wDlgs prefs
    
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate    
    
    ::Debug 2 "::Chat::Close: dlgtoken=$dlgtoken"
    
    set ans "yes"
    if {0} {
	set ans [::UI::MessageBox -icon info -parent $w -type yesno \
	  -message [mc jamesschatclose2]]
    }
    if {$ans eq "yes"} {
	set chattoken [GetActiveChatToken $dlgtoken]
	variable $chattoken
	upvar 0 $chattoken chatstate

	# Do we want to close each tab or complete window?
	set closetab 1
	set chattokens $dlgstate(chattokens)
	::UI::SaveSashPos $wDlgs(jchat) $chatstate(wpane)

	# User pressed windows close button.
	if {[::UI::GetCloseWindowType] eq "wm"} {
	    set closetab 0
	}
	if {$closetab} {
	    if {[llength $chattokens] >= 2} {
		XEventSendCancelCompose $chattoken
		CloseThreadPage $chattoken
		set closetoplevel 0
	    } else {
		set closetoplevel 1
	    }
	} else {
	    set closetoplevel 1
	}
	if {$closetoplevel} {
	    ::UI::SaveWinGeom $wDlgs(jchat) $dlgstate(w)
	    foreach chattoken $chattokens {
                #Send CancelCompose jabber:x:event
		XEventSendCancelCompose $chattoken
	    }
	    destroy $dlgstate(w)
	    return
	} else {
	    return "stop"
	}
    }
}

proc ::Chat::OnDestroyToplevel {w} {
    
    Debug 4 "::Chat::OnDestroyToplevel $w"
    set dlgtoken [GetTokenFrom dlg w $w]
    if {$dlgtoken ne ""} {
	unset $dlgtoken
    }    
}

proc ::Chat::Free {dlgtoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate 
    
    Debug 4 "::Chat::Free dlgtoken=$dlgtoken"
    
    foreach chattoken $dlgstate(chattokens) {
	variable $chattoken
	upvar 0 $chattoken chatstate
	unset -nocomplain chatstate
    }
    unset dlgstate
}

proc ::Chat::GetFirstSashPos { } {
    global  wDlgs
    
    set win [::UI::GetFirstPrefixedToplevel $wDlgs(jchat)]
    if {$win ne ""} {
	set dlgtoken [GetTokenFrom dlg w $win]
	if {$dlgtoken ne ""} {
	    set chattoken [GetActiveChatToken $dlgtoken]
	    variable $chattoken
	    upvar 0 $chattoken chatstate

	    ::UI::SaveSashPos $wDlgs(jchat) $chatstate(wpane)
	}
    }
}

# Support for jabber:x:event ...................................................

# Handle incoming jabber:x:event (XEP-0022).

proc ::Chat::XEventHandleAnyXElem {chattoken args} {

    # See if we've got a jabber:x:event (XEP-0022).
    # 
    #  Should we handle this with hooks????
    array set argsA $args
    set xmldata $argsA(-xmldata)
    set xeventE [wrapper::getfirstchild $xmldata x "jabber:x:event"]
    if {[llength $xeventE]} {

	# If we get xevents as normal messages, send them as normal as well.
	if {[info exists argsA(-type)]} {
	    variable $chattoken
	    upvar 0 $chattoken chatstate

	    if {$argsA(-type) eq "chat"} {
		set chatstate(xevent,type) chat
	    } else {
		set chatstate(xevent,type) normal
	    }
	}
	eval {XEventRecv $chattoken $xeventE} $args
    }
}

proc ::Chat::XEventRecv {chattoken xeventE args} {
    variable $chattoken
    upvar 0 $chattoken chatstate
	
    array set argsA $args

    # This can be one of three things:
    # 1) Request for event notification
    # 2) Notification of message composing
    # 3) Cancellations of message composing
    
    set msgid ""
    if {[info exists argsA(-id)]} {
	set msgid $argsA(-id)
	lappend chatstate(xevent,msgidlist) $msgid
    }
    set composeE [wrapper::getfirstchildwithtag $xeventE "composing"]
    set idE      [wrapper::getfirstchildwithtag $xeventE "id"]
        
    if {($msgid ne "") && ($composeE != {}) && ($idE == {})} {
	
	# 1) Request for event notification
	set chatstate(xevent,msgid) $msgid
	
    } elseif {($composeE != {}) && ($idE != {})} {
	
	# 2) Notification of message composing
	jlib::splitjid $chatstate(jid) jid2 res
	set name [::Jabber::RosterCmd getname $jid2]
	if {$name eq ""} {
	    if {[::Jabber::JlibCmd service isroom $jid2]} {
		set name [::Jabber::JlibCmd service nick $chatstate(jid)]
	    } else {
		set name $chatstate(displayname)
	    }
	}
	set dlgtoken $chatstate(dlgtoken)
	variable $dlgtoken
	upvar 0 $dlgtoken dlgstate

	$chatstate(wnotifier) configure -image $dlgstate(iconNotifier)
	set chatstate(notifier) " [mc chatcompreply $name]"
    } elseif {($composeE == {}) && ($idE != {})} {
	
	# 3) Cancellations of message composing
	$chatstate(wnotifier) configure -image ""
	set chatstate(notifier) " "
    }
}

proc ::Chat::XEventCancel {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    $chatstate(wnotifier) configure -image ""
    set chatstate(notifier) " "
}

proc ::Chat::KeyPressEvent {chattoken char} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    variable cprefs
    upvar ::Jabber::jstate jstate

    ::Debug 6 "::Chat::KeyPressEvent chattoken=$chattoken, char=$char"
   
    if {$char eq ""} {
	return
    }
    if {[info exists chatstate(xevent,afterid)]} {
	after cancel $chatstate(xevent,afterid)
	unset chatstate(xevent,afterid)
    }
    jlib::splitjid $chatstate(jid) user res
    if {[$jstate(jlib) roster isavailable $user] && ($chatstate(state) eq "normal")} {

	if {[info exists chatstate(xevent,msgid)]  \
	  && ($chatstate(xevent,status) eq "")} {
	    XEventSendCompose $chattoken
	}
    }
    if {$chatstate(xevent,status) eq "composing"} {
	set chatstate(xevent,afterid) [after $cprefs(xeventsmillis) \
	  [list [namespace current]::XEventSendCancelCompose $chattoken]]
    }

    #Sending keypress for ChatState
    if { ($chatstate(havecs) eq "true") && ($chatstate(chatstate) ne "composing")} {
        #Trigger Close chatstate
        ChangeChatState $chattoken typing
        SendChatState $chattoken $chatstate(chatstate)
    }
}

proc ::Chat::XEventSendCompose {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    variable cprefs

    ::Debug 2 "::Chat::XEventSendCompose chattoken=$chattoken"
    
    set chatstate(xevent,status) "composing"

    # Pick the id of the most recent event request and skip any previous.
    set id [lindex $chatstate(xevent,msgidlist) end]
    set chatstate(xevent,msgidlist) [lindex $chatstate(xevent,msgidlist) end]
    set chatstate(xevent,composeid) $id
    set opts {}
    if {$chatstate(xevent,type) eq "chat"} {
	set opts [list -thread $chatstate(threadid) -type chat]
    }
    
    set xelems [list \
      [wrapper::createtag "x" -attrlist {xmlns jabber:x:event}  \
      -subtags [list  \
      [wrapper::createtag "composing"] \
      [wrapper::createtag "id" -chdata $id]]]]

    eval {::Jabber::JlibCmd send_message $chatstate(jid) -xlist $xelems} $opts
}

proc ::Chat::XEventSendCancelCompose {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Chat::XEventSendCancelCompose chattoken=$chattoken"

    # We may have been destroyed.
    if {![info exists chatstate]} {
	return
    }
    if {$chatstate(state) ne "normal"} {
	return
    }
    if {![::Jabber::IsConnected]} {
	return
    }
    jlib::splitjid $chatstate(jid) user res
    if {![$jstate(jlib) roster isavailable $user]} {
	return
    }
    if {[info exists chatstate(xevent,afterid)]} {
	after cancel $chatstate(xevent,afterid)
	unset chatstate(xevent,afterid)
    }
    if {$chatstate(xevent,status) eq ""} {
	return
    }
    set id $chatstate(xevent,composeid)
    set chatstate(xevent,status) ""
    set chatstate(xevent,composeid) ""
    set opts {}
    if {$chatstate(xevent,type) eq "chat"} {
	set opts [list -thread $chatstate(threadid) -type chat]
    }

    set xelems [list \
      [wrapper::createtag "x" -attrlist {xmlns jabber:x:event}  \
      -subtags [list [wrapper::createtag "id" -chdata $id]]]]

    eval {::Jabber::JlibCmd send_message $chatstate(jid) -xlist $xelems} $opts
}

proc ::Chat::BuildHistory {dlgtoken} {

    set chattoken [GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    jlib::splitjid $chatstate(jid) jid2 res
    ::History::BuildHistory $jid2 chat -class Chat \
      -tagscommand ::Chat::ConfigureTextTags
}

proc ::Chat::BuildHistoryForJid {jid} {
    
    jlib::splitjid $jid jid2 res
    ::History::BuildHistory $jid2 chat -class Chat \
      -tagscommand ::Chat::ConfigureTextTags
}

# Support for XEP-0085 ChatState ...............................................

proc ::Chat::ChangeChatState {chattoken trigger} {
    upvar 0 $chattoken chatstate

    variable chatStateMap
    set actualState $chatstate(chatstate)

    if {[info exists chatStateMap($actualState,$trigger)]} {
	set chatstate(chatstate) $chatStateMap($actualState,$trigger)
    }
}

proc ::Chat::SendChatState {chattoken state} {
    upvar 0 $chattoken chatstate
    upvar ::Jabber::xmppxmlns xmppxmlns

    set cselems [list  \
      [wrapper::createtag $state -attrlist [list xmlns $xmppxmlns(chatstates)]]]

    eval {::Jabber::JlibCmd send_message $chatstate(jid)  \
      -thread $chatstate(threadid) -type chat -xlist $cselems}
}

# Preference page --------------------------------------------------------------

proc ::Chat::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    	
    set jprefs(chatActiveRet) 1
    set jprefs(showMsgNewWin) 1
    set jprefs(inbox2click)   "newwin"
    set jprefs(chat,normalAsChat) 0
    set jprefs(chat,histLen)      10
    set jprefs(chat,histAge)      0
    set jprefs(chat,mynick)       ""
    
    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(showMsgNewWin) jprefs_showMsgNewWin $jprefs(showMsgNewWin)]  \
      [list ::Jabber::jprefs(inbox2click)   jprefs_inbox2click   $jprefs(inbox2click)]  \
      [list ::Jabber::jprefs(chat,normalAsChat)   jprefs_chatnormalAsChat   $jprefs(chat,normalAsChat)]  \
      [list ::Jabber::jprefs(chat,histLen)  jprefs_chathistLen   $jprefs(chat,histLen)]  \
      [list ::Jabber::jprefs(chat,histAge)  jprefs_chathistAge   $jprefs(chat,histAge)]  \
      [list ::Jabber::jprefs(chat,mynick)   jprefs_chatmynick    $jprefs(chat,mynick)]  \
      [list ::Jabber::jprefs(chatActiveRet) jprefs_chatActiveRet $jprefs(chatActiveRet)] \
      ]    
}

proc ::Chat::BuildPrefsHook {wtree nbframe} {
    
    ::Preferences::NewTableItem {Jabber Chat} [mc mChat]
    
    set wpage [$nbframe page {Chat}]    
    ::Chat::BuildPrefsPage $wpage
}

proc ::Chat::BuildPrefsPage {wpage} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    foreach key {
	chatActiveRet showMsgNewWin inbox2click chat,normalAsChat
	chat,histLen chat,histAge chat,mynick
    } {
	set tmpJPrefs($key) $jprefs($key)
    }
    
    set wc $wpage.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]
 
    ttk::checkbutton $wc.active -text [mc prefchactret2]  \
      -variable [namespace current]::tmpJPrefs(chatActiveRet)
    ttk::checkbutton $wc.newwin -text [mc prefcushow] \
      -variable [namespace current]::tmpJPrefs(showMsgNewWin)
    ttk::checkbutton $wc.normal -text [mc prefchnormal]  \
      -variable [namespace current]::tmpJPrefs(chat,normalAsChat)

    ttk::separator $wc.sep -orient horizontal    

    ttk::label $wc.lmb2 -text "[mc prefcu2clk]:"
    ttk::radiobutton $wc.rb2new -text [mc prefcuopen] \
      -value newwin -variable [namespace current]::tmpJPrefs(inbox2click)
    ttk::radiobutton $wc.rb2re   \
      -text [mc prefcureply] -value reply \
      -variable [namespace current]::tmpJPrefs(inbox2click)

    ttk::separator $wc.sep2 -orient horizontal
    
    set whi $wc.hi
    ttk::frame $wc.hi
    ttk::label $whi.lhist -text "[mc {History length}]:"
    spinbox $whi.shist -width 4 -from 0 -increment 5 -to 1000 -state readonly \
      -textvariable [namespace current]::tmpJPrefs(chat,histLen)
    ttk::label $whi.lage -text "[mc {More recent than}]:"
    set mb $whi.mbage
    set menuDef [list                       \
	[list [mc {Ten seconds}]     -value 10]    \
	[list [mc {One minute}]      -value 60]    \
	[list [mc {Ten minutes}]     -value 600]   \
	[list [mc {One hour}]        -value 3600]  \
	[list [mc {No restriction}]  -value 0]     \
    ]
    ui::optionmenu $mb -menulist $menuDef -direction flush \
      -variable [namespace current]::tmpJPrefs(chat,histAge)

    grid  $whi.lhist   $whi.shist  $whi.lage  $whi.mbage  -sticky w
    grid columnconfigure $whi 1 -weight 1
    grid columnconfigure $whi 3 -minsize [$mb maxwidth]

    ::balloonhelp::balloonforwindow $whi.shist [mc tooltip-historymessages]

    ttk::separator $wc.sep3 -orient horizontal

    set wni $wc.ni
    ttk::frame $wc.ni
    ttk::label $wni.lni -text "[mc {Local nickname}]:"
    ttk::entry $wni.eni -textvariable [namespace current]::tmpJPrefs(chat,mynick)

    grid  $wni.lni  $wni.eni  -sticky w
    grid columnconfigure $wni 1 -weight 1

    ::balloonhelp::balloonforwindow $wni.eni [mc tooltip-localnick]

    grid  $wc.active  -sticky w
    grid  $wc.newwin  -sticky w
    grid  $wc.normal  -sticky w
    grid  $wc.sep     -sticky ew -pady 6
    grid  $wc.lmb2    -sticky w
    grid  $wc.rb2new  -sticky w
    grid  $wc.rb2re   -sticky w
    grid  $wc.sep2    -sticky ew -pady 6
    grid  $wc.hi      -sticky w
    grid  $wc.sep3    -sticky ew -pady 6
    grid  $wc.ni      -sticky ew
}

proc ::Chat::SavePrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    array set jprefs [array get tmpJPrefs]
}

proc ::Chat::CancelPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
        
    foreach key [array names tmpJPrefs] {
	if {![string equal $jprefs($key) $tmpJPrefs($key)]} {
	    ::Preferences::HasChanged
	    break
	}
    }
}

proc ::Chat::UserDefaultsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    foreach key [array names tmpJPrefs] {
	set tmpJPrefs($key) $jprefs($key)
    }
}

proc ::Chat::DestroyPrefsHook { } {
    variable tmpJPrefs
    
    unset -nocomplain tmpJPrefs
}

#-------------------------------------------------------------------------------
