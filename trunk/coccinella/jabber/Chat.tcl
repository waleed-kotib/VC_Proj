#  Chat.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements chat type of UI for jabber.
#      
#  Copyright (c) 2001-2004  Mats Bengtsson
#  
# $Id: Chat.tcl,v 1.69 2004-07-30 12:55:53 matben Exp $

package require entrycomp
package require uriencode

package provide Chat 1.0


namespace eval ::Jabber::Chat:: {
    global  wDlgs
    
    # Add all event hooks.
    ::hooks::add quitAppHook                ::Jabber::Chat::QuitHook
    ::hooks::add newChatMessageHook         ::Jabber::Chat::GotMsg
    ::hooks::add presenceHook               ::Jabber::Chat::PresenceHook
    ::hooks::add closeWindowHook            ::Jabber::Chat::CloseHook
    ::hooks::add closeWindowHook            ::Jabber::Chat::CloseHistoryHook
    ::hooks::add loginHook                  ::Jabber::Chat::LoginHook
    ::hooks::add logoutHook                 ::Jabber::Chat::LogoutHook

    # Define all hooks for preference settings.
    ::hooks::add prefsInitHook          ::Jabber::Chat::InitPrefsHook
    ::hooks::add prefsBuildHook         ::Jabber::Chat::BuildPrefsHook
    ::hooks::add prefsSaveHook          ::Jabber::Chat::SavePrefsHook
    ::hooks::add prefsCancelHook        ::Jabber::Chat::CancelPrefsHook
    ::hooks::add prefsUserDefaultsHook  ::Jabber::Chat::UserDefaultsHook

    # Use option database for customization. 
    # These are nonstandard option valaues and we may therefore keep priority
    # widgetDefault.
    set fontS  [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]

    # Icons
    option add *Chat*sendImage            send                  widgetDefault
    option add *Chat*sendDisImage         sendDis               widgetDefault
    option add *Chat*sendFileImage        sendfile              widgetDefault
    option add *Chat*sendFileDisImage     sendfileDis           widgetDefault
    option add *Chat*saveImage            save                  widgetDefault
    option add *Chat*saveDisImage         saveDis               widgetDefault
    option add *Chat*historyImage         history               widgetDefault
    option add *Chat*historyDisImage      historyDis            widgetDefault
    option add *Chat*printImage           print                 widgetDefault
    option add *Chat*printDisImage        printDis              widgetDefault

    option add *Chat*notifierImage        notifier              widgetDefault    
    option add *Chat*tabAlertImage        notifier              widgetDefault    
    
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
    option add *Chat*sysPreForeground     #26b412               widgetDefault
    option add *Chat*sysTextForeground    #26b412               widgetDefault
    option add *Chat*sysPreFont           ""                    widgetDefault
    option add *Chat*sysTextFont          ""                    widgetDefault
    option add *Chat*histHeadForeground   ""                    widgetDefault
    option add *Chat*histHeadBackground   gray60                widgetDefault
    option add *Chat*histHeadFont         ""                    widgetDefault
    option add *Chat*clockFormat          "%H:%M"               widgetDefault

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
}

# Jabber::Chat::StartThreadDlg --
#
#       Start a chat, ask for user in dialog.
#       
# Arguments:
#       args        ?-key value? pairs
#       
# Results:
#       updates UI.

proc ::Jabber::Chat::StartThreadDlg {args} {
    global  prefs this wDlgs

    variable finished -1
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Jabber::Chat::StartThreadDlg args='$args'"

    set w $wDlgs(jstartchat)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w [mc {Start Chat}]
    
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 12 -ipady 4
    
    ::headlabel::headlabel $w.frall.head -text [mc {Chat with}]
    pack $w.frall.head -side top -fill both -expand 1
    
    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    pack $frmid -side top -fill both -expand 1
    
    set jidlist [::Jabber::RosterCmd getusers -type available]
    label $frmid.luser -text "[mc {Jabber user id}]:"  \
      -font $fontSB -anchor e
    ::entrycomp::entrycomp $frmid.euser $jidlist -width 26    \
      -textvariable [namespace current]::user
    grid $frmid.luser -column 0 -row 1 -sticky e
    grid $frmid.euser -column 1 -row 1 -sticky w
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [mc OK] \
      -default active -command [list [namespace current]::DoStart $w]] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::DoCancel $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    ::UI::SetWindowPosition $w
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    
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

proc ::Jabber::Chat::DoCancel {w} {
    variable finished
    
    ::UI::SaveWinGeom $w
    set finished 0
    destroy $w
}

proc ::Jabber::Chat::DoStart {w} {
    variable finished
    variable user
    upvar ::Jabber::jstate jstate
    
    set ans yes
    
    # User must be online.
    if {![$jstate(roster) isavailable $user]} {
	set ans [tk_messageBox -icon warning -type yesno -parent $w  \
	  -default no  \
	  -message [FormatTextForMessageBox "The user you intend chatting with,\
	  \"$user\", is not online, and this chat makes no sense.\
	  Do you want to chat anyway?"]]
    }
    
    ::UI::SaveWinGeom $w
    set finished 1
    destroy $w
    if {$ans == "yes"} {
	::Jabber::Chat::StartThread $user
    }
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

    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Jabber::Chat::GotMsg args='$args'"

    array set argsArr $args
    
    # -from is a 3-tier jid /resource included.
    set jid $argsArr(-from)
    jlib::splitjidex $jid node domain res
    set jid2 [jlib::joinjid $node $domain ""]
    set mjid  [jlib::jidmap $jid]
    set mjid2 [jlib::jidmap $jid2]
    
    # We must follow the thread...
    # There are several cases to deal with: Have thread page, have dialog?
    if {[info exists argsArr(-thread)]} {
	set threadID $argsArr(-thread)
	set chattoken [::Jabber::Chat::GetTokenFrom chat threadid $threadID]
    } else {
	
	# Try to find a reasonable fallback for clients that fail here (Psi).
	# Find if we have registered any chat for this jid 2/3.
	set chattoken [::Jabber::Chat::GetTokenFrom chat jid ${mjid2}*]
	if {$chattoken == ""} {
	    
	    # Need to create a new thread ID.
	    set threadID [::sha1pure::sha1 "$jstate(mejid)[clock seconds]"]
	} else {
	    variable $chattoken
	    upvar 0 $chattoken chatstate

	    set threadID $chatstate(threadid)
	}
    }
    
    # At this stage we have a threadID.
    # We may not yet have a dialog and/or page for this thread. Make them.
    if {$chattoken == ""} {
	if {$body == ""} {
	    # Junk
	    return
	} else {
	    if {$jprefs(chat,tabbedui)} {
		set dlgtoken [::Jabber::Chat::GetFirstDlgToken]
		if {$dlgtoken == ""} {
		    set dlgtoken [eval {::Jabber::Chat::Build $threadID} $args]
		    set chattoken [::Jabber::Chat::GetActiveChatToken $dlgtoken]
		} else {
		    set chattoken [eval {
			::Jabber::Chat::NewPage $dlgtoken $threadID
		    } $args]
		}
	    } else {
		set dlgtoken [eval {::Jabber::Chat::Build $threadID} $args]		
		set chattoken [::Jabber::Chat::GetActiveChatToken $dlgtoken]
	    }
	    eval {::hooks::run newChatThreadHook $body} $args
	    variable $chattoken
	    upvar 0 $chattoken chatstate
	}
    } else {
	variable $chattoken
	upvar 0 $chattoken chatstate

	set dlgtoken $chatstate(dlgtoken)
    }
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate

    if {$chatstate(rosterName) != ""} {
	set username $chatstate(rosterName)
    } elseif {$node == ""} {
	set username $domain
    } else {
	set username $node
    }

    # We may have reset its jid to a 2-tier jid if it has been offline.
    set chatstate(jid)      $mjid
    set chatstate(fromjid)  $jid
    set chatstate(username) $username
    
    set w $dlgstate(w)
    if {[info exists argsArr(-subject)]} {
	set chatstate(subject) $argsArr(-subject)
	set chatstate(lastsubject) $chatstate(subject)
	::Jabber::Chat::InsertMessage $chattoken systext "Subject: $chatstate(subject)\n"
    }
    
    # See if we've got a jabber:x:event (JEP-0022).
    # 
    #  Should we handle this with hooks????
    if {[info exists argsArr(-x)]} {
	set xevent [lindex [wrapper::getnamespacefromchilds  \
	  $argsArr(-x) x "jabber:x:event"] 0]
	if {[llength $xevent]} {
	    eval {::Jabber::Chat::XEventRecv $chattoken $xevent} $args
	}
    }
    
    # And put message in window if nonempty, and history file.
    if {$body != ""} {
	::Jabber::Chat::InsertMessage $chattoken you $body
	set dateISO [clock format [clock seconds] -format "%Y%m%dT%H:%M:%S"]
	::Jabber::Chat::PutMessageInHistoryFile $jid2 \
	  [list $jid2 $threadID $dateISO $body]
	eval {::Jabber::Chat::TabAlert $chattoken} $args
    }
    if {$dlgstate(got1stMsg) == 0} {
	set dlgstate(got1stMsg) 1
    }
    
    # Run this hook (speech).
    eval {::hooks::run displayChatMessageHook $body} $args
}

# Jabber::Chat::InsertMessage --
# 
#       Puts message in text chat window.

proc ::Jabber::Chat::InsertMessage {chattoken whom body} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set w        $chatstate(w)
    set wtext    $chatstate(wtext)
    set jid      $chatstate(jid)
    set secs  [clock seconds]
    set clockFormat [option get $w clockFormat {}]
    
    switch -- $whom {
	me {
	    jlib::splitjidex [::Jabber::GetMyJid] node host res
	    if {$node == ""} {
		set name $host
	    } else {
		set name $node
	    }
	}
	you {
	    jlib::splitjid $jid jid2 res
	    if {[::Jabber::JlibCmd service isroom $jid2]} {
		set name [::Jabber::JlibCmd service nick $jid]
	    } else {
		set name $chatstate(username)
	    }
	}
    }

    set prefix ""
    if {$clockFormat != ""} {
	set theTime [clock format $secs -format $clockFormat]
	set prefix "\[$theTime\] "
    }        
    
    switch -- $whom {
	me - you {
	    append prefix "<$name>"
	}
	sys {
	}
    }
    $wtext configure -state normal
    
    switch -- $whom {
	me {
	    $wtext insert end $prefix mepre
	    $wtext insert end "   " metext
	    ::Jabber::ParseAndInsertText $wtext $body metext urltag
	}
	you {
	    $wtext insert end $prefix youpre
	    $wtext insert end "   " youtext
	    ::Jabber::ParseAndInsertText $wtext $body youtext urltag
	}
	sys {
	    $wtext insert end $prefix syspre
	    $wtext insert end $body systext
	}
    }

    $wtext configure -state disabled
    $wtext see end
}

# Jabber::Chat::StartThread --
# 
# Arguments:
#       jid
#       args        -message, -thread

proc ::Jabber::Chat::StartThread {jid args} {

    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Jabber::Chat::StartThread jid=$jid, args=$args"
    array set argsArr $args
    set havedlg 0

    # Make unique thread id.
    if {[info exists argsArr(-thread)]} {
	set threadID $argsArr(-thread)
	
	# Do we already have a dialog with this thread?
	set chattoken [::Jabber::Chat::GetTokenFrom chat threadid $threadID]
	if {$chattoken != ""} {
	    set havedlg 1
	    upvar 0 $chattoken chatstate
	}
    } else {
	set threadID [::sha1pure::sha1 "$jstate(mejid)[clock seconds]"]
    }
    
    if {!$havedlg} {
	if {$jprefs(chat,tabbedui)} {
	    set dlgtoken [::Jabber::Chat::GetFirstDlgToken]
	    if {$dlgtoken == ""} {
		set dlgtoken [eval {
		    ::Jabber::Chat::Build $threadID -from $jid} $args]
		set chattoken [::Jabber::Chat::GetTokenFrom chat threadid $threadID]

		variable $chattoken
		upvar 0 $chattoken chatstate
	    } else {
		set chattoken [::Jabber::Chat::NewPage $dlgtoken $threadID \
		  -from $jid]
		
		# Make page frontmost.
		variable $chattoken
		upvar 0 $chattoken chatstate
		
		set dlgtoken $chatstate(dlgtoken)
		variable $dlgtoken
		upvar 0 $dlgtoken dlgstate
		
		$dlgstate(wnb) displaypage $chatstate(pagename)
	    }
	} else {
	    eval {::Jabber::Chat::Build $threadID -from $jid} $args
	}
    }
}

# Jabber::Chat::Build --
#
#       Builds the chat dialog.
#
# Arguments:
#       threadID    unique thread id.
#       args        ?-to jid -subject subject -from fromJid -message text?
#       
# Results:
#       dlgtoken; shows window.

proc ::Jabber::Chat::Build {threadID args} {
    global  this prefs wDlgs
    
    variable uiddlg
    variable cprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Jabber::Chat::Build threadID=$threadID, args='$args'"

    # Initialize the state variable, an array, that keeps is the storage.
    
    set dlgtoken [namespace current]::dlg[incr uiddlg]
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    set w $wDlgs(jchat)${uiddlg}
    array set argsArr $args

    set dlgstate(w)           $w
    set dlgstate(active)      $cprefs(lastActiveRet)
    set dlgstate(got1stMsg)   0
    
    if {$jprefs(chatActiveRet)} {
	set dlgstate(active) 1
    }
    
    # Toplevel with class Chat.
    ::UI::Toplevel $w -class Chat -usemacmainmenu 1 -macstyle documentProc

    set fontSB [option get . fontSmallBold {}]
    if {$dlgstate(active)} {
	::Jabber::Chat::ActiveCmd $dlgtoken
    }

    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 4
    
    # Widget paths.
    set wtray       $w.frall.tray
    set wcont       $w.frall.cc        ;# container frame for wthread or wnb
    set wthread     $w.frall.fthr
    set wnb         $w.frall.nb        ;# tabbed notebook
    set dlgstate(wtray)      $wtray
    set dlgstate(wcont)      $wcont
    set dlgstate(wthread)    $wthread
    set dlgstate(wnb)        $wnb
        
    # Shortcut button part.
    set iconSend        [::Theme::GetImage [option get $w sendImage {}]]
    set iconSendDis     [::Theme::GetImage [option get $w sendDisImage {}]]
    set iconSendFile    [::Theme::GetImage [option get $w sendFileImage {}]]
    set iconSendFileDis [::Theme::GetImage [option get $w sendFileDisImage {}]]
    set iconSave        [::Theme::GetImage [option get $w saveImage {}]]
    set iconSaveDis     [::Theme::GetImage [option get $w saveDisImage {}]]
    set iconHistory     [::Theme::GetImage [option get $w historyImage {}]]
    set iconHistoryDis  [::Theme::GetImage [option get $w historyDisImage {}]]
    set iconPrint       [::Theme::GetImage [option get $w printImage {}]]
    set iconPrintDis    [::Theme::GetImage [option get $w printDisImage {}]]
    set iconNotifier    [::Theme::GetImage [option get $w notifierImage {}]]
    set dlgstate(iconNotifier) $iconNotifier

    ::buttontray::buttontray $wtray 50
    pack $wtray -side top -fill x -padx 4 -pady 2

    $wtray newbutton send    Send    $iconSend    $iconSendDis    \
      [list [namespace current]::Send $dlgtoken]
    $wtray newbutton sendfile {Send File} $iconSendFile $iconSendFileDis    \
      [list [namespace current]::SendFile $dlgtoken]
    $wtray newbutton save    Save    $iconSave    $iconSaveDis    \
       [list [namespace current]::Save $dlgtoken]
    $wtray newbutton history History $iconHistory $iconHistoryDis \
      [list [namespace current]::BuildHistory $dlgtoken]
    $wtray newbutton print   Print   $iconPrint   $iconPrintDis   \
      [list [namespace current]::Print $dlgtoken]
    
    ::hooks::run buildChatButtonTrayHook $wtray $dlgtoken
    
    set shortBtWidth [$wtray minwidth]

    # Button part.
    pack [frame $w.frall.pady -height 8] -side bottom
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [mc Send] -default active \
      -command [list [namespace current]::Send $dlgtoken]]  \
      -side right -padx 5
    pack [button $frbot.btcancel -text [mc Close]  \
      -command [list [namespace current]::Close $dlgtoken]]  \
      -side right -padx 5
    set cmd [list [namespace current]::SmileyCmd $dlgtoken]
    pack [::Emoticons::MenuButton $frbot.smile -command $cmd]  \
      -side right -padx 5
    pack [checkbutton $frbot.active -text " [mc {Active <Return>}]" \
      -command [list [namespace current]::ActiveCmd $dlgtoken] \
      -variable $dlgtoken\(active)]  \
      -side left -padx 5
    pack $frbot -side bottom -fill x -padx 10
    
    pack [frame $w.frall.div2 -bd 2 -relief sunken -height 2] -fill x -side top

    # Having the frame with thread frame as a sibling makes it possible
    # to pack it in a different place.
    frame $wcont -bd 0
    pack  $wcont -side top -fill both -expand 1
    
    # Use an extra frame that contains everything thread specific.
    set chattoken [eval {
	::Jabber::Chat::BuildThreadWidget $dlgtoken $wthread $threadID} $args]
    pack $wthread -in $wcont -fill both -expand 1
    variable $chattoken
    upvar 0 $chattoken chatstate
            
    set dlgstate(wbtsend)    $w.frall.frbot.btok
 
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jchat)]]
    if {$nwin == 1} {
	::UI::SetWindowGeometry $w $wDlgs(jchat)
    }
    ::Jabber::Chat::SetTitle $w $chatstate(rosterName) $chatstate(fromjid)
    wm minsize $w [expr {$shortBtWidth < 220} ? 220 : $shortBtWidth] 320
    wm maxsize $w 800 2000
    
    focus $w
    return $dlgtoken
}

# Jabber::Chat::BuildThreadWidget --
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

proc ::Jabber::Chat::BuildThreadWidget {dlgtoken wthread threadID args} {
    global  wDlgs prefs
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate

    variable uidchat
    variable cprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    array set argsArr $args

    # Initialize the state variable, an array, that keeps is the storage.
    
    set chattoken [namespace current]::chat[incr uidchat]
    variable $chattoken
    upvar 0 $chattoken chatstate

    lappend dlgstate(chattokens) $chattoken

    set fontS  [option get . fontSmall {}]

    # -from is sometimes a 3-tier jid /resource included.
    # Try to keep any /resource part unless not possible.
    
    if {[info exists argsArr(-from)]} {
	set jid [$jstate(jlib) getrecipientjid $argsArr(-from)]
    } else {
	set jid ""
    }
    set mjid [jlib::jidmap $jid]
    jlib::splitjidex $jid node domain res
    jlib::splitjid   $mjid jid2 x
    set rosterName [$jstate(roster) getname $jid2]
    if {$rosterName != ""} {
	set username $rosterName
    } elseif {$node == ""} {
	set username $domain
    } else {
	set username $node
    }
    set chatstate(username) $username
    set chatstate(fromjid)  $jid
    set chatstate(jid)      $mjid

    set chatstate(dlgtoken)     $dlgtoken
    set chatstate(threadid)     $threadID
    set chatstate(rosterName)   $rosterName
    set chatstate(state)        normal    
    set chatstate(subject)          ""
    set chatstate(lastsubject)      ""
    set chatstate(notifier)         ""
    set chatstate(xevent,status)    ""
    set chatstate(xevent,msgidlist) ""
    if {[info exists argsArr(-subject)]} {
	set chatstate(subject) $argsArr(-subject)
    }
    
    # We need to kep track of current presence/status since we may get
    # duplicate presence (delay).
    array set presArr [$jstate(roster) getpresence $jid2 -resource $res]
    set chatstate(presence) $presArr(-type)
    if {[info exists presArr(-show)]} {
	set chatstate(presence) $presArr(-show)
    }
    
    # Use an extra frame that contains everything thread specific.
    frame $wthread -class ChatThread
    set w [winfo toplevel $wthread]
    set chatstate(w) $w

    ::Jabber::Chat::SetTitle $w $rosterName $chatstate(fromjid)

    set wfrmid      $wthread.frmid
    set wtxt        $wfrmid.frtxt
    set wtext       $wtxt.text
    set wysc        $wtxt.ysc
    set wtxtsnd     $wfrmid.frtxtsnd        
    set wtextsnd    $wtxtsnd.text
    set wyscsnd     $wtxtsnd.ysc
    set wnotifier   $wthread.f.lnot
    set wclose      $wthread.f.close
    set wsubject    $wthread.frtop.fsub.e
    set wpresimage  $wthread.frtop.fsub.i
    
    # To and subject fields.
    set frtop [frame $wthread.frtop -borderwidth 0]
    pack $frtop -side top -anchor w -fill x
    
    set icon [::Jabber::Roster::GetPresenceIconEx $jid]

    frame $frtop.fsub
    label $frtop.fsub.l -text "[mc Subject]:"
    entry $frtop.fsub.e -textvariable $chattoken\(subject)
    label $frtop.fsub.i -image $icon
    pack  $frtop.fsub -side top -anchor w -padx 6 -pady 2 -fill x
    pack  $frtop.fsub.l -side left -padx 2
    pack  $frtop.fsub.i -side right -padx 6
    pack  $frtop.fsub.e -side top -padx 2 -fill x

    # Notifier label.
    set chatstate(wnotifier) $wnotifier
    pack [frame $wthread.f] -side bottom -anchor w -fill x -padx 16 -pady 0
    pack [frame $wthread.f.pad -width 1 -height  \
      [image height $dlgstate(iconNotifier)]] -side left -pady 0
    pack [label $wnotifier -textvariable $chattoken\(notifier)  \
      -pady 0 -bd 0 -compound left] -side left -pady 0
    if {$jprefs(chat,tabbedui)} {
	pack [button $wclose -text [mc {Close Thread}] \
	  -command [list [namespace current]::CloseThread $chattoken] \
	  -font $fontS] \
	  -pady 0 -padx 2 -side right
    }
    if {[llength $dlgstate(chattokens)] == 1} {
	pack forget $wclose
    }
    
    # Text chat.
    pack [frame $wfrmid -height 250 -width 300 -relief sunken -bd 1 -class Pane] \
      -side top -fill both -expand 1 -padx 4 -pady 2
    frame $wtxt
	
    text $wtext -height 12 -width 1 -state disabled -cursor {} \
      -borderwidth 1 -relief sunken -wrap word  \
      -yscrollcommand [list ::UI::ScrollSet $wysc \
      [list grid $wysc -column 1 -row 0 -sticky ns]]
    scrollbar $wysc -orient vertical -command [list $wtext yview]
    grid $wtext -column 0 -row 0 -sticky news
    grid $wysc -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxt 0 -weight 1
    grid rowconfigure $wtxt 0 -weight 1
    
    # The tags.
    ::Jabber::Chat::ConfigureTextTags $w $wtext

    # Text send.
    frame $wtxtsnd
    text  $wtextsnd -height 4 -width 1 -wrap word \
      -borderwidth 1 -relief sunken  \
      -yscrollcommand [list ::UI::ScrollSet $wyscsnd \
      [list grid $wyscsnd -column 1 -row 0 -sticky ns]]
    scrollbar $wyscsnd -orient vertical -command [list $wtextsnd yview]
    grid $wtextsnd -column 0 -row 0 -sticky news
    grid $wyscsnd -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxtsnd 0 -weight 1
    grid rowconfigure $wtxtsnd 0 -weight 1
    
    if {$jprefs(chatFont) != ""} {
	$wtextsnd configure -font $jprefs(chatFont)
    }
    if {[info exists argsArr(-message)]} {
	$wtextsnd insert end $argsArr(-message)	
    }
    
    set imageHorizontal \
      [::Theme::GetImage [option get $wfrmid imageHorizontal {}]]
    set sashHBackground [option get $wfrmid sashHBackground {}]

    set paneopts [list -orient vertical -limit 0.0]
    if {[info exists prefs(paneGeom,$wDlgs(jchat))]} {
	lappend paneopts -relative $prefs(paneGeom,$wDlgs(jchat))
    } else {
	lappend paneopts -relative {0.75 0.25}
    }
    if {$sashHBackground != ""} {
	lappend paneopts -image "" -handlelook [list -background $sashHBackground]
    } elseif {$imageHorizontal != ""} {
	lappend paneopts -image $imageHorizontal
    }    
    eval {::pane::pane $wtxt $wtxtsnd} $paneopts

    bind $wtextsnd <Return>  \
      [list [namespace current]::ReturnKeyPress $dlgtoken]
   
    # jabber:x:event
    if {$cprefs(usexevents)} {
	bind $wtextsnd <KeyPress>  \
	  [list +[namespace current]::KeyPressEvent $chattoken %A]
    }
    set chatstate(wthread)  $wthread
    set chatstate(wtext)    $wtext
    set chatstate(wtxt)     $wtxt
    set chatstate(wtextsnd) $wtextsnd
    set chatstate(wclose)   $wclose
    set chatstate(wsubject) $wsubject
    set chatstate(wpresimage) $wpresimage
 
    return $chattoken
}

proc ::Jabber::Chat::SetTitle {w rosterName fromjid} {
    
    if {$rosterName == ""} {
	wm title $w "[mc Chat]: $fromjid"
    } else {
	wm title $w "[mc Chat]: $rosterName ($fromjid)"
    }
}

# ::Jabber::Chat::NewPage, ... --
# 
#       Several procs to handle the tabbed interface; creates and deletes
#       notebook and pages.

proc ::Jabber::Chat::NewPage {dlgtoken threadID args} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    upvar ::Jabber::jprefs jprefs
        
    # If no notebook, move chat widget to first notebook page.
    if {[string equal [winfo class [pack slaves $dlgstate(wcont)]] "ChatThread"]} {
	set wthread $dlgstate(wthread)
	set chattoken [lindex $dlgstate(chattokens) 0]
	variable $chattoken
	upvar 0 $chattoken chatstate

	set name $chatstate(username)
	set chatstate(pagename) $name
	set dlgstate(name2token,$name) $chattoken
	
	# Repack the ChatThread in notebook page.
	::Jabber::Chat::MoveThreadToPage $dlgtoken $chattoken
    } 

    # Make fresh page with chat widget.
    set chattoken [eval {::Jabber::Chat::MakeNewPage $dlgtoken $threadID} $args]

    # Make sure all "Close Thread" buttons enabled.
    if {$jprefs(chat,tabbedui)} {
	foreach ctoken $dlgstate(chattokens) {
	    variable $ctoken
	    upvar 0 $ctoken cstate

	    pack $cstate(wclose) -pady 0 -padx 2 -side right
	}
    }
    return $chattoken
}

proc ::Jabber::Chat::MakeNewPage {dlgtoken threadID args} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    variable uidpage
    array set argsArr $args
        
    # Make fresh page with chat widget.
    jlib::splitjidex $argsArr(-from) node domain res
    if {$node == ""} {
	set name $domain
    } else {
	set name $node
    }
    set wnb $dlgstate(wnb)
    set name [$wnb getuniquename $name]
    set wpage [$wnb newpage $name]

    # We must make thye new page a sibling of the notebook in order to be
    # able to reparent it when notebook gons.
    set wthread $dlgstate(wthread)[incr uidpage]
    set chattoken [eval {
	::Jabber::Chat::BuildThreadWidget $dlgtoken $wthread $threadID
    } $args]
    pack $wthread -in $wpage -fill both -expand true
    
    variable $chattoken
    upvar 0 $chattoken chatstate
    set chatstate(pagename) $name
    set dlgstate(name2token,$name) $chattoken
    return $chattoken
}

proc ::Jabber::Chat::MoveThreadToPage {dlgtoken chattoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    # Repack the WBCanvas in notebook page.
    set wnb     $dlgstate(wnb)
    set wcont   $dlgstate(wcont)
    set wthread $chatstate(wthread)
    set name    $chatstate(pagename)
    
    pack forget $wthread
    ::mactabnotebook::mactabnotebook $wnb  \
      -selectcommand [list [namespace current]::SelectPageCmd $dlgtoken]
    pack $wnb -in $wcont -fill both -expand true -side right
    set wpage [$wnb newpage $name]	
    pack $wthread -in $wpage -fill both -expand true -side right
    raise $wthread
}

proc ::Jabber::Chat::CloseThread {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set dlgtoken $chatstate(dlgtoken)
    ::Jabber::Chat::DeletePage $chattoken
     set newchattoken [::Jabber::Chat::GetActiveChatToken $dlgtoken]

    # Set state of new page.
    ::Jabber::Chat::SetThreadState $dlgtoken $newchattoken
}

proc ::Jabber::Chat::DeletePage {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set dlgtoken $chatstate(dlgtoken)
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    set name $chatstate(pagename)
    $dlgstate(wnb) deletepage $name
    unset dlgstate(name2token,$name)
    
    # Delete the actual widget.
    destroy $chatstate(wthread)
    set dlgstate(chattokens)  \
      [lsearch -all -inline -not $dlgstate(chattokens) $chattoken]
    unset chatstate
    
    # If only a single page left then reparent and delete notebook.
    if {[llength $dlgstate(chattokens)] == 1} {
	set chattoken [lindex $dlgstate(chattokens) 0]
	variable $chattoken
	upvar 0 $chattoken chatstate

	::Jabber::Chat::MoveThreadFromPage $dlgtoken $chattoken
	pack forget $chatstate(wclose)
    }
}

proc ::Jabber::Chat::MoveThreadFromPage {dlgtoken chattoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set wnb     $dlgstate(wnb)
    set wcont   $dlgstate(wcont)
    set name    $chatstate(pagename)
    set wthread $chatstate(wthread)

    pack forget $wthread
    destroy $wnb
    pack $wthread -in $wcont -fill both -expand true
}

# Jabber::Chat::SelectPageCmd --
# 
#       Callback command from tab notebook widget when selecting new tab.

proc ::Jabber::Chat::SelectPageCmd {dlgtoken w name} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    Debug 3 "::Jabber::Chat::SelectPageCmd name=$name"
        
    set chattoken $dlgstate(name2token,$name)
    ::Jabber::Chat::SetThreadState $dlgtoken $chattoken
}

proc ::Jabber::Chat::SetThreadState {dlgtoken chattoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate

    variable $chattoken
    upvar 0 $chattoken chatstate
    upvar ::Jabber::jstate jstate

    Debug 3 "::Jabber::Chat::SetThreadState chattoken=$chattoken"
    jlib::splitjid $chatstate(jid) user res
    if {[$jstate(roster) isavailable $user]} {
	::Jabber::Chat::SetState $chattoken normal
    } else {
	::Jabber::Chat::SetState $chattoken disabled
    }
    if {[winfo exists $dlgstate(wnb)]} {
	$dlgstate(wnb) pageconfigure $chatstate(pagename) -image ""
    }
    ::Jabber::Chat::SetTitle $dlgstate(w) $chatstate(rosterName) \
      $chatstate(fromjid)
}

# Jabber::Chat::SetState --
# 
#       Set state of complete dialog to normal or disabled.
  
proc ::Jabber::Chat::SetState {chattoken state} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    Debug 4 "::Jabber::Chat::SetState chattoken=$chattoken, state=$state"
    if {[string equal $state $chatstate(state)]} {
	#return
    }
    set dlgtoken $chatstate(dlgtoken)
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate    
    
    foreach name {send sendfile} {
	$dlgstate(wtray) buttonconfigure $name -state $state 
    }
    $dlgstate(wbtsend)   configure -state $state
    $chatstate(wtextsnd) configure -state $state
    $chatstate(wsubject) configure -state $state
    set chatstate(state) $state
}

# Jabber::Chat::GetActiveChatToken --
# 
#       Returns the chattoken corresponding to the frontmost thread.

proc ::Jabber::Chat::GetActiveChatToken {dlgtoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    if {[winfo exists $dlgstate(wnb)]} {
	set name [$dlgstate(wnb) displaypage]
	set chattoken $dlgstate(name2token,$name)
    } else {
	set chattoken [lindex $dlgstate(chattokens) 0]
    }
    return $chattoken
}

proc ::Jabber::Chat::TabAlert {chattoken args} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set dlgtoken $chatstate(dlgtoken)
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    if {[winfo exists $dlgstate(wnb)]} {
	set w       $dlgstate(w)
	set wnb     $dlgstate(wnb)
	set name    $chatstate(pagename)
	if {[$wnb displaypage] != $name} {
	    set icon [::Theme::GetImage [option get $w tabAlertImage {}]]
	    $wnb pageconfigure $name -image $icon
	}
    }
}

proc ::Jabber::Chat::SmileyCmd {dlgtoken im key} {
    
    set chattoken [::Jabber::Chat::GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    Emoticons::InsertSmiley $chatstate(wtextsnd) $im $key
}

# Jabber::Chat::CloseHook, ... --
# 
#       Various hooks.

proc ::Jabber::Chat::CloseHook {wclose} {
    global  wDlgs
    
    if {[string match $wDlgs(jchat)* $wclose]} {
	set dlgtoken [::Jabber::Chat::GetTokenFrom dlg w $wclose]
	if {$dlgtoken != ""} {
	    ::Jabber::Chat::Close $dlgtoken
	}
    }   
    return ""
}

proc ::Jabber::Chat::LoginHook { } {

    foreach dlgtoken [::Jabber::Chat::GetTokenList dlg] {
	set chattoken [::Jabber::Chat::GetActiveChatToken $dlgtoken]
	::Jabber::Chat::SetThreadState $dlgtoken $chattoken
    }
    return ""
}

proc ::Jabber::Chat::LogoutHook { } {
    
    foreach dlgtoken [::Jabber::Chat::GetTokenList dlg] {
	variable $dlgtoken
	upvar 0 $dlgtoken dlgstate

	foreach ctoken $dlgstate(chattokens) {
	    ::Jabber::Chat::SetState $ctoken disabled
	}
    }
    return ""
}

proc ::Jabber::Chat::QuitHook { } {
    global  wDlgs
    
    ::UI::SaveWinGeom $wDlgs(jstartchat)
    ::UI::SaveWinPrefixGeom $wDlgs(jchat)
    ::Jabber::Chat::GetFirstPanePos
    
    # This sends cancel compose to all.
    foreach dlgtoken [::Jabber::Chat::GetTokenList dlg] {
	::Jabber::Chat::Close $dlgtoken
    }    
    return ""
}

proc ::Jabber::Chat::ConfigureTextTags {w wtext} {
    variable chatOptions
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Jabber::Chat::ConfigureTextTags jprefs(chatFont)=$jprefs(chatFont)"
    
    set space 2
    set alltags {mepre metext youpre youtext syspre systext histhead}
        
    if {[string length $jprefs(chatFont)]} {
	set chatFont $jprefs(chatFont)
    } else {
	set chatFont [option get $wtext font Font]
    }
    set boldChatFont [lreplace $jprefs(chatFont) 2 2 bold]

    foreach tag $alltags {
	set opts($tag) [list -spacing1 $space]
    }
    foreach spec $chatOptions {
	foreach {tag optName resName resClass} $spec break
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
    
    ::Text::ConfigureLinkTagForTextWidget $wtext urltag activeurltag
}

# Jabber::Chat::SetFont --
# 
#       Sets the chat font in all text widgets.

proc ::Jabber::Chat::SetFont {theFont} {    
    upvar ::Jabber::jprefs jprefs

    ::Debug 2 "::Jabber::Chat::SetFont theFont=$theFont"
    
    # If theFont is empty it means the default font.
    set jprefs(chatFont) $theFont
        
    foreach chattoken [GetTokenList chat] {
	variable $chattoken
	upvar 0 $chattoken chatstate

	set w $chatstate(w)
	if {[winfo exists $w]} {
	    ::Jabber::Chat::ConfigureTextTags $w $chatstate(wtext)
	    if {$jprefs(chatFont) == ""} {
		
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

proc ::Jabber::Chat::ActiveCmd {dlgtoken} {
    variable cprefs
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    # Remember last setting.
    set cprefs(lastActiveRet) $dlgstate(active)
}

proc ::Jabber::Chat::ReturnKeyPress {dlgtoken} {
    variable cprefs
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    if {$dlgstate(active)} {
	::Jabber::Chat::Send $dlgtoken
	
	# Stop further handling in Text.
	return -code break
    } 
}

proc ::Jabber::Chat::Send {dlgtoken} {
    global  prefs
    
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    variable cprefs
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::Chat::Send "
    
    # Check that still connected to server.
    if {![::Jabber::IsConnected]} {
	tk_messageBox -type ok -icon error -title [mc {Not Connected}] \
	  -message [mc jamessnotconnected]
	return
    }
    set chattoken [::Jabber::Chat::GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate

    set w        $chatstate(w)
    set wtextsnd $chatstate(wtextsnd)
    set threadID $chatstate(threadid)
    
    # According to XMPP we should send to 3-tier jid if still online,
    # else to 2-tier.
    set chatstate(fromjid) [$jstate(jlib) getrecipientjid $chatstate(fromjid)]
    set jid [jlib::jidmap $chatstate(fromjid)]
    jlib::splitjid $jid jid2 res
    set chatstate(jid) $jid
    
    if {![jlib::jidvalidate $jid]} {
	set ans [tk_messageBox -message [FormatTextForMessageBox  \
	  [mc jamessbadjid $jid]] \
	  -icon error -type yesno]
	if {[string equal $ans "no"]} {
	    return
	}
    }

    # Get text to send. Strip off any ending newlines.
    # There might by smiley icons in the text widget. Parse them to text.
    set allText [::Text::TransformToPureText $wtextsnd]
    set allText [string trimright $allText "\n"]
    if {$allText == ""} {
	return
    }
    
    # Put in history file.
    set secs [clock seconds]
    set dateISO [clock format $secs -format "%Y%m%dT%H:%M:%S"]
    ::Jabber::Chat::PutMessageInHistoryFile $jid2 \
      [list $jstate(mejid) $threadID $dateISO $allText]
    
    # Need to detect if subject changed.
    set opts {}
    if {![string equal $chatstate(subject) $chatstate(lastsubject)]} {
	lappend opts -subject $chatstate(subject)
	::Jabber::Chat::InsertMessage $chattoken sys  \
	  "Subject: $chatstate(subject)\n"
    }
    set chatstate(lastsubject) $chatstate(subject)
    
    # Cancellations of any message composing jabber:x:event
    if {$cprefs(usexevents) &&  \
      [string equal $chatstate(xevent,status) "composing"]} {
	::Jabber::Chat::XEventCancelCompose $chattoken
    }
    
    # Requesting composing notification.
    if {$cprefs(usexevents)} {
	lappend opts -id [incr cprefs(xeventid)]
	lappend opts -xlist [list \
	  [wrapper::createtag "x" -attrlist {xmlns jabber:x:event}  \
	  -subtags [list [wrapper::createtag "composing"]]]]
    }
    
    if {[catch {
	eval {::Jabber::JlibCmd send_message $jid  \
	  -thread $threadID -type chat -body $allText} $opts
    } err]} {
	tk_messageBox -type ok -icon error -title "Network Error" \
	  -message "Network error ocurred: $err"
	return
    }
    set dlgstate(lastsentsecs) $secs
    
    # Add to chat window and clear send.        
    ::Jabber::Chat::InsertMessage $chattoken me $allText
    $wtextsnd delete 1.0 end

    if {$dlgstate(got1stMsg) == 0} {
	set dlgstate(got1stMsg) 1
    }
    
    # Run this hook (speech).
    set opts [list -from $jid2]
    eval {::hooks::run displayChatMessageHook $allText} $opts
}

proc ::Jabber::Chat::TraceJid {dlgtoken name junk1 junk2} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    # Call by name.
    upvar $name locName    
    wm title $dlgstate(w) "[mc Chat] ($chatstate(fromjid))"
}

proc ::Jabber::Chat::SendFile {dlgtoken} {
     
    set chattoken [::Jabber::Chat::GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate

    jlib::splitjid $chatstate(fromjid) jid2 res
    ::Jabber::OOB::BuildSet $jid2
}

proc ::Jabber::Chat::Print {dlgtoken} {
    
    set chattoken [::Jabber::Chat::GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate

    ::UserActions::DoPrintText $chatstate(wtext)
}

proc ::Jabber::Chat::Save {dlgtoken} {
    global  this
    
    set chattoken [::Jabber::Chat::GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate

    set wtext $chatstate(wtext)
    
    set ans [tk_getSaveFile -title [mc Save] \
      -initialfile "Chat $chatstate(fromjid).txt"]
    
    if {[string length $ans]} {
	set allText [::Text::TransformToPureText $wtext]
	set fd [open $ans w]
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

proc ::Jabber::Chat::PresenceHook {jid type args} {
    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::mapShowTextToElem mapShowTextToElem

    Debug 4 "::Jabber::Chat::PresenceHook jid=$jid, type=$type, args=$args"

    # ::Jabber::Chat::PresenceHook: args=marilu@jabber.dk unavailable 
    #-resource Psi -type unavailable -type unavailable -from marilu@jabber.dk/Psi
    #-to matben@jabber.dk -status Disconnected
    array set argsArr $args
    set from $jid
    if {[info exists argsArr(-from)]} {
	set from $argsArr(-from)
    }
    set mjid [jlib::jidmap $jid]
    set chattoken [::Jabber::Chat::GetTokenFrom chat jid ${mjid}*]
    if {$chattoken == ""} {
	
	# Likely no chat with this jid.
	return
    }
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set show $type
    if {[info exists argsArr(-show)]} {
	set show $argsArr(-show)
    }
    
    # Skip if duplicate presence.
    if {[string equal $chatstate(presence) $show]} {
	return
    }
    set status ""
    if {[info exists argsArr(-status)]} {
	set status "$argsArr(-status)\n"
    }
    ::Jabber::Chat::InsertMessage $chattoken sys  \
      "$from is: $mapShowTextToElem($show)\n$status"
    
    if {[string equal $type "available"]} {
	::Jabber::Chat::SetState $chattoken normal
    } else {
	::Jabber::Chat::SetState $chattoken disabled
    }
    set icon [::Jabber::Roster::GetPresenceIconEx $from]
    if {$icon != ""} {
	$chatstate(wpresimage) configure -image $icon
    }

    jlib::splitjid $from jid2 res
    array set presArr [$jstate(roster) getpresence $jid2 -resource $res]
    set chatstate(presence) $presArr(-type)
    if {[info exists presArr(-show)]} {
	set chatstate(presence) $presArr(-show)
    }
}

# Jabber::Chat::HaveChat --
# 
#       Returns toplevel window if have chat, else empty.

proc ::Jabber::Chat::HaveChat {jid} {

    jlib::splitjid $jid jid2 res
    set mjid2 [jlib::jidmap $jid2]
    set chattoken [::Jabber::Chat::GetTokenFrom chat jid ${mjid2}*]
    if {$chattoken != ""} {
	variable $chattoken
	upvar 0 $chattoken chatstate

	if {[winfo exists $chatstate(w)]} {
	    return $chatstate(w)
	} else {
	    return ""
	}
    } else {
	return ""
    }
}

# Jabber::Chat::GetTokenFrom --
# 
#       Try to get the token state array from any stored key.
#       
# Arguments:
#       type        'dlg' or 'chat'
#       key         w, jid, threadid etc...
#       pattern     glob matching
#       
# Results:
#       token or empty if not found.

proc ::Jabber::Chat::GetTokenFrom {type key pattern} {
    
    # Search all tokens for this key into state array.
    foreach token [::Jabber::Chat::GetTokenList $type] {
	
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
    return ""
}

proc ::Jabber::Chat::GetFirstDlgToken { } {
 
    set token ""
    set dlgtokens [::Jabber::Chat::GetTokenList dlg]
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

# Jabber::Chat::GetTokenList --
# 
# Arguments:
#       type        'dlg' or 'chat'

proc ::Jabber::Chat::GetTokenList {type} {
    
    set nskey [namespace current]::$type
    return [concat  \
      [info vars ${nskey}\[0-9\]] \
      [info vars ${nskey}\[0-9\]\[0-9\]] \
      [info vars ${nskey}\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${nskey}\[0-9\]\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${nskey}\[0-9\]\[0-9\]\[0-9\]\[0-9\]\[0-9\]]]
}

# Jabber::Chat::Close --
#
#

proc ::Jabber::Chat::Close {dlgtoken} {
    global  wDlgs prefs
    
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate    
    
    ::Debug 2 "::Jabber::Chat::Close: dlgtoken=$dlgtoken"
    set ans "yes"
    if {0} {
	set ans [tk_messageBox -icon info -parent $w -type yesno \
	  -message [FormatTextForMessageBox [mc jamesschatclose]]]
    }
    if {$ans == "yes"} {
	set chattoken [::Jabber::Chat::GetActiveChatToken $dlgtoken]
	variable $chattoken
	upvar 0 $chattoken chatstate

	::UI::SaveWinGeom $wDlgs(jchat) $dlgstate(w)
	::UI::SavePanePos $wDlgs(jchat) $chatstate(wtxt)
	destroy $dlgstate(w)
	
	foreach chattoken $dlgstate(chattokens) {
	    ::Jabber::Chat::XEventCancelCompose $chattoken
	}
	::Jabber::Chat::Free $dlgtoken
    }
}

proc ::Jabber::Chat::Free {dlgtoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate 
    
    foreach chattoken $dlgstate(chattokens) {
	variable $chattoken
	upvar 0 $chattoken chatstate
	unset -nocomplain chatstate
    }
    unset dlgstate
}

proc ::Jabber::Chat::GetFirstPanePos { } {
    global  wDlgs
    
    set win [::UI::GetFirstPrefixedToplevel $wDlgs(jchat)]
    if {$win != ""} {
	set dlgtoken [::Jabber::Chat::GetTokenFrom dlg w $win]
	if {$dlgtoken != ""} {
	    set chattoken [::Jabber::Chat::GetActiveChatToken $dlgtoken]
	    variable $chattoken
	    upvar 0 $chattoken chatstate

	    ::UI::SavePanePos $wDlgs(jchat) $chatstate(wtxt)
	}
    }
}

# Support for jabber:x:event ...................................................

# Handle incoming jabber:x:event (JEP-0022).

proc ::Jabber::Chat::XEventRecv {chattoken xevent args} {
    variable $chattoken
    upvar 0 $chattoken chatstate
	
    array set argsArr $args

    # This can be one of three things:
    # 1) Request for event notification
    # 2) Notification of message composing
    # 3) Cancellations of message composing
    
    set msgid ""
    if {[info exists argsArr(-id)]} {
	set msgid $argsArr(-id)
	lappend chatstate(xevent,msgidlist) $msgid
    }
    set composeElem [wrapper::getchildswithtag $xevent "composing"]
    set idElem [wrapper::getchildswithtag $xevent "id"]
    ::Debug 6 "::Jabber::Chat::XEventRecv \
      msgid=$msgid, composeElem=$composeElem, idElem=$idElem"
    if {($msgid != "") && ($composeElem != "") && ($idElem == "")} {
	
	# 1) Request for event notification
	set chatstate(xevent,msgid) $argsArr(-id)
	
    } elseif {($composeElem != "") && ($idElem != "")} {
	
	# 2) Notification of message composing
	jlib::splitjid $chatstate(jid) jid2 res
	set name [::Jabber::RosterCmd getname $jid2]
	if {$name == ""} {
	    if {[::Jabber::JlibCmd service isroom $jid2]} {
		set name [::Jabber::JlibCmd service nick $chatstate(jid)]

	    } else {
		set name $chatstate(username)
	    }
	}
	set dlgtoken $chatstate(dlgtoken)
	variable $dlgtoken
	upvar 0 $dlgtoken dlgstate

	$chatstate(wnotifier) configure -image $dlgstate(iconNotifier)
	set chatstate(notifier) " [mc chatcompreply $name]"
    } elseif {($composeElem == "") && ($idElem != "")} {
	
	# 3) Cancellations of message composing
	$chatstate(wnotifier) configure -image ""
	set chatstate(notifier) " "
    }
}

proc ::Jabber::Chat::KeyPressEvent {chattoken char} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    variable cprefs

    ::Debug 6 "::Jabber::Chat::KeyPressEvent chattoken=$chattoken, char=$char"
    
    if {$char == ""} {
	return
    }
    if {[info exists chatstate(xevent,afterid)]} {
	after cancel $chatstate(xevent,afterid)
	unset chatstate(xevent,afterid)
    }    
    if {[info exists chatstate(xevent,msgid)] && ($chatstate(xevent,status) == "")} {
	::Jabber::Chat::XEventSendCompose $chattoken
    }
    if {$chatstate(xevent,status) == "composing"} {
	set chatstate(xevent,afterid) [after $cprefs(xeventsmillis) \
	  [list [namespace current]::XEventCancelCompose $chattoken]]
    }
}

proc ::Jabber::Chat::XEventSendCompose {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    variable cprefs

    ::Debug 2 "::Jabber::Chat::XEventSendCompose chattoken=$chattoken"
    
    if {$chatstate(state) != "normal"} {
	return
    }
    set chatstate(xevent,status) "composing"

    # Pick the id of the most recent event request and skip any previous.
    set id [lindex $chatstate(xevent,msgidlist) end]
    set chatstate(xevent,msgidlist) [lindex $chatstate(xevent,msgidlist) end]
    set chatstate(xevent,composeid) $id
    
    set xelems [list \
      [wrapper::createtag "x" -attrlist {xmlns jabber:x:event}  \
      -subtags [list  \
      [wrapper::createtag "composing"] \
      [wrapper::createtag "id" -chdata $id]]]]
    
    if {[catch {
	::Jabber::JlibCmd send_message $chatstate(jid)  \
	  -thread $chatstate(threadid) -type chat -xlist $xelems
    } err]} {
	tk_messageBox -type ok -icon error -title "Network Error" \
	  -message "Network error ocurred: $err"
	return
    }    
}

proc ::Jabber::Chat::XEventCancelCompose {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate

    ::Debug 2 "::Jabber::Chat::XEventCancelCompose chattoken=$chattoken"

    # We may have been destroyed.
    if {![info exists chatstate]} {
	return
    }
    if {$chatstate(state) != "normal"} {
	return
    }
    if {![::Jabber::IsConnected]} {
	return
    }
    if {[info exists chatstate(xevent,afterid)]} {
	after cancel $chatstate(xevent,afterid)
	unset chatstate(xevent,afterid)
    }
    if {$chatstate(xevent,status) == ""} {
	return
    }
    set id $chatstate(xevent,composeid)
    set chatstate(xevent,status) ""
    set chatstate(xevent,composeid) ""

    set xelems [list \
      [wrapper::createtag "x" -attrlist {xmlns jabber:x:event}  \
      -subtags [list [wrapper::createtag "id" -chdata $id]]]]

    if {[catch {
	::Jabber::JlibCmd send_message $chatstate(jid)  \
	  -thread $chatstate(threadid) -type chat -xlist $xelems
    } err]} {
	tk_messageBox -type ok -icon error -title "Network Error" \
	  -message "Network error ocurred: $err"
	return
    }
}

# Various methods to handle chat history .......................................

namespace eval ::Jabber::Chat:: {
    
    variable uidhist 1000
}

# Jabber::Chat::PutMessageInHistoryFile --
#
#       Writes chat event send/received to history file.
#       
# Arguments:
#       jid       2-tier jid
#       msg       {jid2 threadID dateISO body}
#       
# Results:
#       none.

proc ::Jabber::Chat::PutMessageInHistoryFile {jid msg} {
    global  prefs
    
    set mjid [jlib::jidmap $jid]
    set path [file join $prefs(historyPath) [uriencode::quote $jid]]    
    if {![catch {open $path a} fd]} {
	puts $fd "set message(\[incr uid]) {$msg}"
	close $fd
    }
}

proc ::Jabber::Chat::BuildHistory {dlgtoken} {

    set chattoken [::Jabber::Chat::GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    ::Jabber::Chat::BuildHistoryForJid $chatstate(jid)
}

# Jabber::Chat::BuildHistoryForJid --
#
#       Builds chat history dialog for jid.
#       
# Arguments:
#       jid       2-tier jid
#       
# Results:
#       dialog displayed.

proc ::Jabber::Chat::BuildHistoryForJid {jid} {
    global  prefs this wDlgs
    variable uidhist
    variable historyOptions
    
    set jid [jlib::jidmap $jid]
    set w $wDlgs(jchist)[incr uidhist]
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
    wm title $w "[mc {Chat History}]: $jid"
    
    set wtxt  $w.frall.fr
    set wtext $wtxt.t
    set wysc  $wtxt.ysc
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btclose -text [mc Close] \
      -command "destroy $w"] -side right -padx 5 -pady 5
    pack [button $frbot.btclear -text [mc Clear]  \
      -command [list [namespace current]::ClearHistory $jid $wtext]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btprint -text [mc Print]  \
      -command [list [namespace current]::PrintHistory $wtext]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btsave -text [mc Save]  \
      -command [list [namespace current]::SaveHistory $jid $wtext]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side bottom -fill x -padx 8 -pady 6
    
    # Text.
    set wchatframe $w.frall.fr
    pack [frame $wchatframe -class Chat] -fill both -expand 1
    text $wtext -height 20 -width 72 -cursor {} \
      -borderwidth 1 -relief sunken -yscrollcommand [list $wysc set] -wrap word
    scrollbar $wysc -orient vertical -command [list $wtext yview]
    grid $wtext -column 0 -row 0 -sticky news
    grid $wysc -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxt 0 -weight 1
    grid rowconfigure $wtxt 0 -weight 1    
        
    # The tags.
    ::Jabber::Chat::ConfigureTextTags $wchatframe $wtext    
    
    set path [file join $prefs(historyPath) [uriencode::quote $jid]] 
    if {[file exists $path]} {
	set uidstart 1000
	set uid $uidstart
	incr uidstart
	catch {source $path}
	set uidstop $uid
	
	# Organize chat sessions into the threads.
	# First, identify the threads and order them.
	set allThreads {}
	for {set i $uidstart} {$i <= $uidstop} {incr i} {
	    set thread [lindex $message($i) 1]
	    if {![info exists threadDate($thread)]} {
		set threadDate($thread) [lindex $message($i) 2]
		lappend allThreads $thread
	    }
	}	

	foreach thread $allThreads {
	    set when [clock format [clock scan $threadDate($thread)]  \
	      -format "%A %e %B %Y"]
	    $wtext insert end "[mc {Thread started}] $when\n" histhead
	    
	    for {set i $uidstart} {$i <= $uidstop} {incr i} {
		foreach {cjid cthread time body} $message($i) break
		if {![string equal $cthread $thread]} {
		    continue
		}
		set syssecs [clock scan $time]
		set cwhen [clock format $syssecs -format "%H:%M:%S"]
		if {[string equal $cjid $jid]} {
		    set ptag youpre
		    set ptxttag youtext
		} else {
		    set ptag mepre
		    set ptxttag metext
		}
		$wtext insert end "\[$cwhen\] <$cjid>" $ptag
		$wtext insert end "   " $ptxttag
		
		::Jabber::ParseAndInsertText $wtext $body $ptxttag urltag
	    }
	}
    } else {
	$wtext insert end "No registered chat history for $jid\n" histhead
    }
    $wtext configure -state disabled
    ::UI::SetWindowGeometry $w $wDlgs(jchist)
    wm minsize $w 200 320
}

proc ::Jabber::Chat::ClearHistory {jid wtext} {
    global  prefs
    
    $wtext configure -state normal
    $wtext delete 1.0 end
    $wtext configure -state disabled
    set path [file join $prefs(historyPath) [uriencode::quote $jid]] 
    if {[file exists $path]} {
	file delete $path
    }
}

proc ::Jabber::Chat::CloseHistoryHook {wclose} {
    global  wDlgs
    
    if {[string match $wDlgs(jchist)* $wclose]} {
	::UI::SaveWinPrefixGeom $wDlgs(jchist)
    }   
}

proc ::Jabber::Chat::PrintHistory {wtext} {
        
    ::UserActions::DoPrintText $wtext
}

proc ::Jabber::Chat::SaveHistory {jid wtext} {
    global  this
	
    set ans [tk_getSaveFile -title [mc Save] \
      -initialfile "Chat ${jid}.txt"]

    if {[string length $ans]} {
	set allText [::Text::TransformToPureText $wtext]
	set fd [open $ans w]
	puts $fd $allText	
	close $fd
	if {[string equal $this(platform) "macintosh"]} {
	    file attributes $ans -type TEXT -creator ttxt
	}
    }
}

# Preference page --------------------------------------------------------------

proc ::Jabber::Chat::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    	
    set jprefs(chatActiveRet) 0
    set jprefs(showMsgNewWin) 1
    set jprefs(inbox2click)   "newwin"
    
    ::PreferencesUtils::Add [list  \
      [list ::Jabber::jprefs(showMsgNewWin) jprefs_showMsgNewWin $jprefs(showMsgNewWin)]  \
      [list ::Jabber::jprefs(inbox2click)   jprefs_inbox2click   $jprefs(inbox2click)]  \
      [list ::Jabber::jprefs(chatActiveRet) jprefs_chatActiveRet $jprefs(chatActiveRet)]]    
}

proc ::Jabber::Chat::BuildPrefsHook {wtree nbframe} {
    
    $wtree newitem {Jabber Chat} -text [mc Chat]
    
    set wpage [$nbframe page {Chat}]    
    ::Jabber::Chat::BuildPrefsPage $wpage
}

proc ::Jabber::Chat::BuildPrefsPage {wpage} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    set fontS  [option get . fontSmall {}]    
    set fontSB [option get . fontSmallBold {}]

    foreach key {chatActiveRet showMsgNewWin inbox2click} {
	set tmpJPrefs($key) $jprefs($key)
    }
    
    set labfr ${wpage}.alrt
    labelframe $labfr -text [mc {Chat}]
    pack $labfr -side top -anchor w -padx 8 -pady 4
    
    set fr $labfr.fr
    pack [frame $fr] -side top -anchor w -padx 10 -pady 2
 
    checkbutton $fr.active -text " [mc prefchactret]"  \
      -variable [namespace current]::tmpJPrefs(chatActiveRet)
    checkbutton $fr.newwin -text " [mc prefcushow]" \
      -variable [namespace current]::tmpJPrefs(showMsgNewWin)
    label $fr.lmb2 -text [mc prefcu2clk]
    radiobutton $fr.rb2new -text " [mc prefcuopen]" \
      -value newwin -variable [namespace current]::tmpJPrefs(inbox2click)
    radiobutton $fr.rb2re   \
      -text " [mc prefcureply]" -value reply \
      -variable [namespace current]::tmpJPrefs(inbox2click)

    grid $fr.active -sticky w
    grid $fr.newwin -sticky w
    grid $fr.lmb2   -sticky w
    grid $fr.rb2new -sticky w
    grid $fr.rb2re  -sticky w
}

proc ::Jabber::Chat::SavePrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    array set jprefs [array get tmpJPrefs]
    unset tmpJPrefs
}

proc ::Jabber::Chat::CancelPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
        
    foreach key [array names tmpJPrefs] {
	if {![string equal $jprefs($key) $tmpJPrefs($key)]} {
	    ::Preferences::HasChanged
	    break
	}
    }
}

proc ::Jabber::Chat::UserDefaultsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    foreach key [array names tmpJPrefs] {
	set tmpJPrefs($key) $jprefs($key)
    }
}

#-------------------------------------------------------------------------------
