#  Chat.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements chat type of UI for jabber.
#      
#  Copyright (c) 2001-2004  Mats Bengtsson
#  
# $Id: Chat.tcl,v 1.99 2004-12-09 15:20:27 matben Exp $

package require entrycomp
package require uriencode

package provide Chat 1.0


namespace eval ::Chat:: {
    global  wDlgs
    
    # Add all event hooks.
    ::hooks::register quitAppHook                ::Chat::QuitHook
    ::hooks::register newChatMessageHook         ::Chat::GotMsg
    ::hooks::register newMessageHook             ::Chat::GotNormalMsg
    ::hooks::register presenceHook               ::Chat::PresenceHook
    ::hooks::register closeWindowHook            ::Chat::CloseHook
    ::hooks::register closeWindowHook            ::Chat::CloseHistoryHook
    ::hooks::register loginHook                  ::Chat::LoginHook
    ::hooks::register logoutHook                 ::Chat::LogoutHook

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
    option add *Chat*settingsImage        settings              widgetDefault
    option add *Chat*settingsDisImage     settingsDis           widgetDefault
    option add *Chat*printImage           print                 widgetDefault
    option add *Chat*printDisImage        printDis              widgetDefault

    option add *Chat*notifierImage        notifier              widgetDefault    
    option add *Chat*tabAlertImage        lightbulbon           widgetDefault    
    
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
    option add *Chat.frall.borderWidth          1               50
    option add *Chat.frall.relief               raised          50
    option add *Chat*top.padX                   4               50
    option add *Chat*top.padY                   2               50
    option add *Chat*divt.borderWidth           2               50
    option add *Chat*divt.height                2               50
    option add *Chat*divt.relief                sunken          50

    option add *ChatThread*fsub.padX            6               50
    option add *ChatThread*fsub.padY            2               50
    option add *ChatThread*fsub.l.padX          2               50
    option add *ChatThread*fsub.p1.width        6               50
    option add *ChatThread*fsub.p2.width        6               50
    option add *ChatThread*mid.padX             6               50
    option add *ChatThread*mid.padY             2               50
    option add *ChatThread*pane.borderWidth     1               50
    option add *ChatThread*pane.relief          sunken          50
    option add *ChatThread*frtxt.text.borderWidth     1                50
    option add *ChatThread*frtxt.text.relief          sunken           50
    option add *ChatThread*frtxtsnd.text.borderWidth  1                50
    option add *ChatThread*frtxtsnd.text.relief       sunken           50
    option add *ChatThread*bot.padX             16              50
    option add *ChatThread*bot.smile.padX       6               50
    option add *ChatThread*bot.smile.padY       2               50
    

    
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
    global  prefs this wDlgs

    variable finished -1
    variable user ""
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Chat::StartThreadDlg args='$args'"

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
    pack $frmid -side top -fill both -expand 1 -pady 6
    
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
    
    if {![jlib::jidvalidate $user]} {
	set ans [::UI::MessageBox -message [mc jamessbadjid $user] \
	  -icon error -type yesno]
	if {[string equal $ans "no"]} {
	    return
	}
    }    
    
    # User must be online.
    if {![$jstate(roster) isavailable $user]} {
	set ans [::UI::MessageBox -icon warning -type yesno -parent $w  \
	  -default no  \
	  -message "The user you intend chatting with,\
	  \"$user\", is not online, and this chat makes no sense.\
	  Do you want to chat anyway?"]
    }
    
    ::UI::SaveWinGeom $w
    set finished 1
    destroy $w
    if {$ans == "yes"} {
	StartThread $user
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
    
    array set argsArr $args
    set havedlg 0

    # Make unique thread id.
    if {[info exists argsArr(-thread)]} {
	set threadID $argsArr(-thread)
	
	# Do we already have a dialog with this thread?
	set chattoken [GetTokenFrom chat threadid $threadID]
	if {$chattoken != ""} {
	    set havedlg 1
	    upvar 0 $chattoken chatstate
	}
    } else {
	set threadID [::sha1pure::sha1 "$jstate(mejid)[clock seconds]"]
    }
    
    if {!$havedlg} {
	if {$jprefs(chat,tabbedui)} {
	    set dlgtoken [GetFirstDlgToken]
	    if {$dlgtoken == ""} {
		set dlgtoken [eval {Build $threadID -from $jid} $args]
		set chattoken [GetTokenFrom chat threadid $threadID]

		variable $chattoken
		upvar 0 $chattoken chatstate
	    } else {
		set chattoken [NewPage $dlgtoken $threadID \
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
	    eval {Build $threadID -from $jid} $args
	}
    }
    
    # Since we initated this thread need to set recipient to jid2.
    jlib::splitjid $jid jid2 res
    set chatstate(fromjid) $jid2
    SetTitle $chattoken
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

    ::Debug 2 "::Chat::GotMsg args='$args'"

    array set argsArr $args
    
    # -from is a 3-tier jid /resource included.
    set jid $argsArr(-from)
    jlib::splitjidex $jid node domain res
    set jid2  [jlib::joinjid $node $domain ""]
    set mjid  [jlib::jidmap $jid]
    set mjid2 [jlib::jidmap $jid2]
    
    # We must follow the thread...
    # There are several cases to deal with: Have thread page, have dialog?
    if {[info exists argsArr(-thread)]} {
	set threadID $argsArr(-thread)
	set chattoken [GetTokenFrom chat threadid $threadID]
    } else {
	
	# Try to find a reasonable fallback for clients that fail here (Psi).
	# Find if we have registered any chat for this jid 2/3.
	set chattoken [GetTokenFrom chat jid ${mjid2}*]
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
    set newdlg 0
    if {$chattoken == ""} {
	if {$body == ""} {
	    # Junk
	    return
	} else {
	    if {$jprefs(chat,tabbedui)} {
		set dlgtoken [GetFirstDlgToken]
		if {$dlgtoken == ""} {
		    set dlgtoken [eval {Build $threadID} $args]
		    set chattoken [GetActiveChatToken $dlgtoken]
		} else {
		    set chattoken [eval {
			NewPage $dlgtoken $threadID
		    } $args]
		}
	    } else {
		set dlgtoken [eval {Build $threadID} $args]		
		set chattoken [GetActiveChatToken $dlgtoken]
	    }
	    set newdlg 1
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

    # We may have reset its jid to a 2-tier jid if it has been offline.
    set chatstate(jid)       $mjid
    set chatstate(fromjid)   $jid
    set chatstate(shortname) [::Roster::GetDisplayName $jid]
    
    # If new chat dialog check to see if we have got a thread history to insert.
    if {$newdlg} {
	InsertAnyThreadHistory $chattoken
    }
    set w $dlgstate(w)

    set opts {}
    if {[info exists argsArr(-x)]} {
	set tm [::Jabber::GetAnyDelayElem $argsArr(-x)]
	if {$tm != ""} {
	    set secs [clock scan $tm -gmt 1]
	    lappend opts -secs $secs
	}

	# See if we've got a jabber:x:event (JEP-0022).
	# 
	#  Should we handle this with hooks????
	set xevent [lindex [wrapper::getnamespacefromchilds  \
	  $argsArr(-x) x "jabber:x:event"] 0]
	if {[llength $xevent]} {
	    eval {XEventRecv $chattoken $xevent} $args
	}
    }

    if {[info exists argsArr(-subject)]} {
	set chatstate(subject) $argsArr(-subject)
	set chatstate(lastsubject) $chatstate(subject)
	eval {
	    InsertMessage $chattoken systext "Subject: $chatstate(subject)\n"
	} $opts
    }
    
    if {$body != ""} {
	
	# Put in chat window.
	eval {InsertMessage $chattoken you $body} $opts

	# Put in history file.
	if {![info exists secs]} {
	    set secs [clock seconds]
	}
	set dateISO [clock format $secs -format "%Y%m%dT%H:%M:%S"]
	PutMessageInHistoryFile $jid2 [list $jid2 $threadID $dateISO $body]
	eval {TabAlert $chattoken} $args
    }
    if {$dlgstate(got1stMsg) == 0} {
	set dlgstate(got1stMsg) 1
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
    if {$jprefs(chat,normalAsChat) && ($body != "")} {
	
	::Debug 2 "::Chat::GotNormalMsg args='$args'"
	eval {GotMsg $body} $args
    }
}

# Chat::InsertMessage --
# 
#       Puts message in text chat window.
#       
#       args:   -secs seconds

proc ::Chat::InsertMessage {chattoken whom body args} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    array set argsArr $args
    
    set w     $chatstate(w)
    set wtext $chatstate(wtext)
    set jid   $chatstate(jid)
        
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
		set name $chatstate(shortname)
	    }
	}
    }
    if {[info exists argsArr(-secs)]} {
	set secs $argsArr(-secs)
    } else {
	set secs [clock seconds]
    }
    if {[::Utils::IsToday $secs]} {
	set clockFormat [option get $w clockFormat {}]
    } else {
	set clockFormat [option get $w clockFormatNotToday {}]
    }
    if {$clockFormat != ""} {
	set theTime [clock format $secs -format $clockFormat]
	set prefix "\[$theTime\] "
    } else {
	set prefix ""
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
	    ::Text::Parse $wtext $body metext
	    $wtext insert end \n
	}
	you {
	    $wtext insert end $prefix youpre
	    $wtext insert end "   " youtext
	    ::Text::Parse $wtext $body youtext
	    $wtext insert end \n
	}
	sys {
	    $wtext insert end $prefix syspre
	    $wtext insert end $body systext
	}
    }

    $wtext configure -state disabled
    $wtext see end
}

proc ::Chat::InsertAnyThreadHistory {chattoken} {
    global  prefs
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    ::Debug 2 "::Chat::InsertAnyThreadHistory"
    
    # First find any matching history file.
    jlib::splitjid $chatstate(jid) jid2 res
    set path [file join $prefs(historyPath) [uriencode::quote $jid2]] 
    if {[file exists $path]} {
	
	# Collect all matching threads.
	set threadID $chatstate(threadid)
	set uidstart 1000
	set uid $uidstart
	incr uidstart
	catch {source $path}
	set uidstop $uid
	
	set msgList {}
	for {set i $uidstart} {$i <= $uidstop} {incr i} {
	    set cthread [lindex $message($i) 1]
	    if {[string equal $cthread $threadID]} {
		set cjid [lindex $message($i) 0]
		set date [lindex $message($i) 2]
		set body [lindex $message($i) 3]
		set secs [clock scan $date]
		if {[string equal $cjid $jid2]} {
		    set whom you
		} else {
		    set whom me
		}
		InsertMessage $chattoken $whom $body -secs $secs
	    }
	}
    }
}

# Chat::Build --
#
#       Builds the chat dialog.
#
# Arguments:
#       threadID    unique thread id.
#       args        ?-to jid -subject subject -from fromJid -message text?
#       
# Results:
#       dlgtoken; shows window.

proc ::Chat::Build {threadID args} {
    global  this prefs wDlgs
    
    variable uiddlg
    variable cprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Chat::Build threadID=$threadID, args='$args'"

    # Initialize the state variable, an array, that keeps is the storage.
    
    set dlgtoken [namespace current]::dlg[incr uiddlg]
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    set w $wDlgs(jchat)${uiddlg}
    array set argsArr $args

    set dlgstate(w)           $w
    set dlgstate(got1stMsg)   0
    
    # Toplevel with class Chat.
    ::UI::Toplevel $w -class Chat -usemacmainmenu 1 -macstyle documentProc

    set fontSB [option get . fontSmallBold {}]

    # Global frame. D = -borderwidth 1 -relief raised
    frame $w.frall
    pack  $w.frall -fill both -expand 1
    
    # Widget paths.
    set wtop        $w.frall.top
    set wtray       $wtop.tray
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
    set iconSettings    [::Theme::GetImage [option get $w settingsImage {}]]
    set iconSettingsDis [::Theme::GetImage [option get $w settingsDisImage {}]]
    set iconPrint       [::Theme::GetImage [option get $w printImage {}]]
    set iconPrintDis    [::Theme::GetImage [option get $w printDisImage {}]]
    set iconNotifier    [::Theme::GetImage [option get $w notifierImage {}]]
    set dlgstate(iconNotifier) $iconNotifier

    # D = -padx 4 -pady 2
    frame $wtop
    pack  $wtop -side top -fill x

    ::buttontray::buttontray $wtray
    pack $wtray -side top -fill x

    $wtray newbutton send  \
      -text [mc Send] -image $iconSend  \
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
    $wtray newbutton settings  \
      -text [mc Settings] -image $iconSettings \
      -disabledimage $iconSettingsDis \
      -command [list [namespace current]::Settings $dlgtoken]
    $wtray newbutton print  \
      -text [mc Print] -image $iconPrint  \
      -disabledimage $iconPrintDis   \
      -command [list [namespace current]::Print $dlgtoken]
    
    ::hooks::run buildChatButtonTrayHook $wtray $dlgtoken
    
    set shortBtWidth [$wtray minwidth]
    
    # D = -bd 2 -relief sunken
    pack [frame $w.frall.divt] -fill x -side top

    # Having the frame with thread frame as a sibling makes it possible
    # to pack it in a different place.
    frame $wcont -bd 0
    pack  $wcont -side top -fill both -expand 1
    
    # Use an extra frame that contains everything thread specific.
    set chattoken [eval {
	BuildThreadWidget $dlgtoken $wthread $threadID} $args]
    pack $wthread -in $wcont -fill both -expand 1
    variable $chattoken
    upvar 0 $chattoken chatstate
            
    set dlgstate(wbtsend)    $w.frall.frbot.btok
 
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jchat)]]
    if {$nwin == 1} {
	::UI::SetWindowGeometry $w $wDlgs(jchat)
    }
    SetTitle $chattoken
    SetThreadState $dlgtoken $chattoken

    wm minsize $w [expr {$shortBtWidth < 220} ? 220 : $shortBtWidth] 320
    wm maxsize $w 800 2000
    
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
    global  wDlgs prefs osprefs
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate

    variable uidchat
    variable cprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Chat::BuildThreadWidget args=$args"
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
    
    set chatstate(fromjid)          $jid
    set chatstate(jid)              $mjid
    set chatstate(shortname)        [::Roster::GetDisplayName $mjid]
    set chatstate(dlgtoken)         $dlgtoken
    set chatstate(threadid)         $threadID
    set chatstate(nameorjid)        [::Roster::GetNameOrjid $jid2]
    set chatstate(state)            normal    
    set chatstate(subject)          ""
    set chatstate(lastsubject)      ""
    set chatstate(notifier)         ""
    set chatstate(active)           $cprefs(lastActiveRet)
    set chatstate(xevent,status)    ""
    set chatstate(xevent,msgidlist) ""
    if {[info exists argsArr(-subject)]} {
	set chatstate(subject) $argsArr(-subject)
    }
    
    if {$jprefs(chatActiveRet)} {
	set chatstate(active) 1
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

    SetTitle $chattoken

    set wbot        $wthread.bot
    set wnotifier   $wbot.lnot
    set wsmile      $wbot.smile.pad
    set wsubject    $wthread.frtop.fsub.e
    set wpresimage  $wthread.frtop.fsub.i
    
    # To and subject fields.
    set frtop [frame $wthread.frtop]
    pack $frtop -side top -anchor w -fill x
    
    set icon [::Roster::GetPresenceIconFromJid $jid]
    
    # D = -padx 6 -pady 2
    set   wsub $frtop.fsub
    frame $wsub
    label $wsub.l -text "[mc Subject]:"
    entry $wsub.e -textvariable $chattoken\(subject)
    frame $wsub.p1
    label $wsub.i  -image $icon
    frame $wsub.p2
    pack  $wsub    -side top -anchor w -fill x
    pack  $wsub.l  -side left
    pack  $wsub.p2 -side right
    pack  $wsub.i  -side right
    pack  $wsub.p1 -side right
    pack  $wsub.e  -side top -fill x

    # Notifier label.
    set chatstate(wnotifier) $wnotifier
        
    # The bottom frame.
    frame $wbot
    pack  $wbot -side bottom -anchor w -fill x
    checkbutton $wbot.active -text " [mc {Active <Return>}]" \
      -command [list [namespace current]::ActiveCmd $chattoken] \
      -variable $chattoken\(active)
    pack $wbot.active -side left
    frame $wbot.p1
    pack  $wbot.p1 -side left
    frame $wbot.smile
    pack  $wbot.smile -side left
    set cmd [list [namespace current]::SmileyCmd $chattoken]
    ::Emoticons::MenuButton $wsmile -command $cmd
    pack $wsmile -side left	
    label $wnotifier -textvariable $chattoken\(notifier) -pady 0 -bd 0 \
      -compound left
    pack $wnotifier -side left

    set wmid        $wthread.mid
    set wpane       $wmid.pane
    set wtxt        $wpane.frtxt
    set wtext       $wtxt.text
    set wysc        $wtxt.ysc
    set wtxtsnd     $wpane.frtxtsnd        
    set wtextsnd    $wtxtsnd.text
    set wyscsnd     $wtxtsnd.ysc

    frame $wmid
    pack  $wmid -side top -fill both -expand 1

    # Text chat.
    frame $wpane -height 250 -width 300 -class Pane
    pack  $wpane -side top -fill both -expand 1
    frame $wtxt
	
    text $wtext -height 12 -width 1 -state disabled -cursor {} -wrap word  \
      -yscrollcommand [list ::UI::ScrollSet $wysc \
      [list grid $wysc -column 1 -row 0 -sticky ns]]
    scrollbar $wysc -orient vertical -command [list $wtext yview]
    grid $wtext -column 0 -row 0 -sticky news
    grid $wysc  -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxt 0 -weight 1
    grid rowconfigure    $wtxt 0 -weight 1
    
    # The tags.
    ConfigureTextTags $w $wtext

    # Text send.
    frame $wtxtsnd
    text  $wtextsnd -height 4 -width 1 -wrap word \
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
    if {$chatstate(active)} {
	ActiveCmd $chattoken
    }
    
    set imageHorizontal \
      [::Theme::GetImage [option get $wpane imageHorizontal {}]]
    set sashHBackground [option get $wpane sashHBackground {}]

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
      [list [namespace current]::ReturnKeyPress $chattoken]    
    bind $wtextsnd <$osprefs(mod)-Return> \
      [list [namespace current]::CommandReturnKeyPress $chattoken]
   
    # jabber:x:event
    if {$cprefs(usexevents)} {
	bind $wtextsnd <KeyPress>  \
	  [list +[namespace current]::KeyPressEvent $chattoken %A]
    }
    set chatstate(wthread)  $wthread
    set chatstate(wtext)    $wtext
    set chatstate(wtxt)     $wtxt
    set chatstate(wtextsnd) $wtextsnd
    #set chatstate(wclose)   $wclose
    set chatstate(wsubject) $wsubject
    set chatstate(wsmile)   $wsmile
    set chatstate(wpresimage) $wpresimage
 
    after idle [list raise $w]
    
    return $chattoken
}

proc ::Chat::SetTitle {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
        
    wm title $chatstate(w) \
      "[mc Chat]: $chatstate(shortname) ($chatstate(fromjid))"
}

# ::Chat::NewPage, ... --
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

	set name $chatstate(shortname)
	set chatstate(pagename) $name
	set dlgstate(name2token,$name) $chattoken
	
	# Repack the ChatThread in notebook page.
	MoveThreadToPage $dlgtoken $chattoken
    } 

    # Make fresh page with chat widget.
    set chattoken [eval {MakeNewPage $dlgtoken $threadID} $args]
    return $chattoken
}

proc ::Chat::MakeNewPage {dlgtoken threadID args} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    variable uidpage
    array set argsArr $args
        
    # Make fresh page with chat widget.
    set name [::Roster::GetDisplayName $argsArr(-from)]
    set wnb $dlgstate(wnb)
    set name [$wnb getuniquename $name]
    set wpage [$wnb newpage $name]

    # We must make thye new page a sibling of the notebook in order to be
    # able to reparent it when notebook gons.
    set wthread $dlgstate(wthread)[incr uidpage]
    set chattoken [eval {
	BuildThreadWidget $dlgtoken $wthread $threadID
    } $args]
    pack $wthread -in $wpage -fill both -expand true
    
    variable $chattoken
    upvar 0 $chattoken chatstate
    set chatstate(pagename) $name
    set dlgstate(name2token,$name) $chattoken
    return $chattoken
}

proc ::Chat::MoveThreadToPage {dlgtoken chattoken} {
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
    ::mactabnotebook::mactabnotebook $wnb -closebutton 1  \
      -closecommand [list [namespace current]::ClosePageCmd $dlgtoken]  \
      -selectcommand [list [namespace current]::SelectPageCmd $dlgtoken]
    pack $wnb -in $wcont -fill both -expand true -side right
    set wpage [$wnb newpage $name]	
    pack $wthread -in $wpage -fill both -expand true -side right
    raise $wthread
}

proc ::Chat::CloseThread {chattoken} {
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

	MoveThreadFromPage $dlgtoken $chattoken
	pack forget $chatstate(wclose)
    }
}

proc ::Chat::MoveThreadFromPage {dlgtoken chattoken} {
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
    
    SetThreadState $dlgtoken $chattoken
}

proc ::Chat::ClosePageCmd {dlgtoken w name} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    # We could issue some kind of info/warning here?
    
    set chattoken [GetTokenFrom chat pagename $name]
    if {$chattoken != ""} {	
	CloseThread $chattoken
    }
    
    # We handle the page destruction here already since need to clean up after.
    return -code break
}

# Chat::SelectPageCmd --
# 
#       Callback command from tab notebook widget when selecting new tab.

proc ::Chat::SelectPageCmd {dlgtoken w name} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    Debug 3 "::Chat::SelectPageCmd name=$name"
        
    set chattoken $dlgstate(name2token,$name)
    SetThreadState $dlgtoken $chattoken
}

proc ::Chat::SetThreadState {dlgtoken chattoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate

    variable $chattoken
    upvar 0 $chattoken chatstate
    upvar ::Jabber::jstate jstate

    Debug 3 "::Chat::SetThreadState chattoken=$chattoken"
    
    jlib::splitjid $chatstate(jid) user res
    if {[$jstate(roster) isavailable $user]} {
	SetState $chattoken normal
    } else {
	SetState $chattoken disabled
    }
    if {[winfo exists $dlgstate(wnb)]} {
	$dlgstate(wnb) pageconfigure $chatstate(pagename) -image ""
    }
    SetTitle $chattoken
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
    
    foreach name {send sendfile} {
	$dlgstate(wtray) buttonconfigure $name -state $state 
    }
    #$dlgstate(wbtsend)   configure -state $state
    $chatstate(wtextsnd) configure -state $state
    $chatstate(wsubject) configure -state $state
    $chatstate(wsmile)   configure -state $state
    set chatstate(state) $state
}

# Chat::GetActiveChatToken --
# 
#       Returns the chattoken corresponding to the frontmost thread.

proc ::Chat::GetActiveChatToken {dlgtoken} {
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

proc ::Chat::TabAlert {chattoken args} {
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

proc ::Chat::SmileyCmd {chattoken im key} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    Emoticons::InsertSmiley $chatstate(wtextsnd) $im $key
}

# Chat::CloseHook, ... --
# 
#       Various hooks.

proc ::Chat::CloseHook {wclose} {
    global  wDlgs
    
    if {[string match $wDlgs(jchat)* $wclose]} {
	set dlgtoken [GetTokenFrom dlg w $wclose]
	if {$dlgtoken != ""} {
	    Close $dlgtoken
	}
    }   
    return ""
}

proc ::Chat::LoginHook { } {

    # handled by presence hook instead
    return ""
    
    foreach dlgtoken [GetTokenList dlg] {
	set chattoken [GetActiveChatToken $dlgtoken]
	SetThreadState $dlgtoken $chattoken
    }
    return ""
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
    return ""
}

proc ::Chat::QuitHook { } {
    global  wDlgs
    
    ::UI::SaveWinGeom $wDlgs(jstartchat)
    ::UI::SaveWinPrefixGeom $wDlgs(jchat)
    GetFirstPanePos
    
    # This sends cancel compose to all.
    foreach dlgtoken [GetTokenList dlg] {
	Close $dlgtoken
    }    
    return ""
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

	set w $chatstate(w)
	if {[winfo exists $w]} {
	    ConfigureTextTags $w $chatstate(wtext)
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

proc ::Chat::ActiveCmd {chattoken} {
    variable cprefs
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    # Remember last setting.
    set cprefs(lastActiveRet) $chatstate(active)
}

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

    Send $chatstate(dlgtoken)

    # Stop further handling in Text.
    return -code break
}

proc ::Chat::Send {dlgtoken} {
    global  prefs
    
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    variable cprefs
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Chat::Send "
    
    # Check that still connected to server.
    if {![::Jabber::IsConnected]} {
	::UI::MessageBox -type ok -icon error -title [mc {Not Connected}] \
	  -message [mc jamessnotconnected]
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
    jlib::splitjid $jid jid2 res
    set chatstate(jid) $jid
    
    if {![jlib::jidvalidate $jid]} {
	set ans [::UI::MessageBox -message [mc jamessbadjid $jid] \
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
    PutMessageInHistoryFile $jid2 \
      [list $jstate(mejid) $threadID $dateISO $allText]
    
    # Need to detect if subject changed.
    set opts {}
    if {![string equal $chatstate(subject) $chatstate(lastsubject)]} {
	lappend opts -subject $chatstate(subject)
	InsertMessage $chattoken sys "Subject: $chatstate(subject)\n"
    }
    set chatstate(lastsubject) $chatstate(subject)
    
    # Cancellations of any message composing jabber:x:event
    if {$cprefs(usexevents) &&  \
      [string equal $chatstate(xevent,status) "composing"]} {
	XEventSendCancelCompose $chattoken
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
	::UI::MessageBox -type ok -icon error -title "Network Error" \
	  -message "Network error ocurred: $err"
	return
    }
    set dlgstate(lastsentsecs) $secs
    
    # Add to chat window and clear send.        
    InsertMessage $chattoken me $allText
    $wtextsnd delete 1.0 end

    if {$dlgstate(got1stMsg) == 0} {
	set dlgstate(got1stMsg) 1
    }
    
    set opts [list -from $jid2]
    eval {::hooks::run displayChatMessageHook $allText} $opts
}

proc ::Chat::TraceJid {dlgtoken name junk1 junk2} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    # Call by name.
    upvar $name locName    
    wm title $dlgstate(w) "[mc Chat] ($chatstate(fromjid))"
}

proc ::Chat::SendFile {dlgtoken} {
     
    set chattoken [GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate

    jlib::splitjid $chatstate(fromjid) jid2 res
    ::OOB::BuildSet $jid2
}

proc ::Chat::Settings {dlgtoken} {
    
    ::Preferences::Build -page {Jabber Chat}
}

proc ::Chat::Print {dlgtoken} {
    
    set chattoken [GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate

    ::UserActions::DoPrintText $chatstate(wtext)
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

proc ::Chat::PresenceHook {jid type args} {
    
    upvar ::Jabber::jstate jstate

    Debug 4 "::Chat::PresenceHook jid=$jid, type=$type"

    # ::Chat::PresenceHook: args=marilu@jabber.dk unavailable 
    #-resource Psi -type unavailable -type unavailable -from marilu@jabber.dk/Psi
    #-to matben@jabber.dk -status Disconnected
    array set argsArr $args
    set from $jid
    if {[info exists argsArr(-from)]} {
	set from $argsArr(-from)
    }    
    set show $type
    if {[info exists argsArr(-show)]} {
	set show $argsArr(-show)
    }
    set status ""
    if {[info exists argsArr(-status)]} {
	set status "$argsArr(-status)\n"
    }
    set mjid [jlib::jidmap $jid]
    jlib::splitjid $from jid2 res
    array set presArr [$jstate(roster) getpresence $jid2 -resource $res]
    set icon [::Roster::GetPresenceIconFromJid $from]
    
    foreach chattoken [GetAllTokensFrom chat jid ${mjid}*] {
	variable $chattoken
	upvar 0 $chattoken chatstate
	
	# Skip if duplicate presence.
	if {[string equal $chatstate(presence) $show]} {
	    return
	}
	set showStr [::Roster::MapShowToText $show]
	InsertMessage $chattoken sys "$from is: $showStr\n$status"
	
	if {[string equal $type "available"]} {
	    SetState $chattoken normal
	} else {
	    SetState $chattoken disabled
	}
	if {$icon != ""} {
	    $chatstate(wpresimage) configure -image $icon
	}
	
	set chatstate(presence) $presArr(-type)
	if {[info exists presArr(-show)]} {
	    set chatstate(presence) $presArr(-show)
	}
	XEventCancel $chattoken
    }
}

# Chat::HaveChat --
# 
#       Returns toplevel window if have chat, else empty.

proc ::Chat::HaveChat {jid} {

    jlib::splitjid $jid jid2 res
    set mjid2 [jlib::jidmap $jid2]
    set chattoken [GetTokenFrom chat jid ${mjid2}*]
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
    return ""
}

# Chat::GetAllTokensFrom --
# 
#       As above but all tokens.

proc ::Chat::GetAllTokensFrom {type key pattern} {
    
    set alltokens {}
    
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
    
    set nskey [namespace current]::$type
    return [concat  \
      [info vars ${nskey}\[0-9\]] \
      [info vars ${nskey}\[0-9\]\[0-9\]] \
      [info vars ${nskey}\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${nskey}\[0-9\]\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${nskey}\[0-9\]\[0-9\]\[0-9\]\[0-9\]\[0-9\]]]
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
	  -message [mc jamesschatclose]]
    }
    if {$ans == "yes"} {
	set chattoken [GetActiveChatToken $dlgtoken]
	variable $chattoken
	upvar 0 $chattoken chatstate

	::UI::SaveWinGeom $wDlgs(jchat) $dlgstate(w)
	::UI::SavePanePos $wDlgs(jchat) $chatstate(wtxt)
	destroy $dlgstate(w)
	
	foreach chattoken $dlgstate(chattokens) {
	    XEventSendCancelCompose $chattoken
	}
	Free $dlgtoken
    }
}

proc ::Chat::Free {dlgtoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate 
    
    foreach chattoken $dlgstate(chattokens) {
	variable $chattoken
	upvar 0 $chattoken chatstate
	unset -nocomplain chatstate
    }
    unset dlgstate
}

proc ::Chat::GetFirstPanePos { } {
    global  wDlgs
    
    set win [::UI::GetFirstPrefixedToplevel $wDlgs(jchat)]
    if {$win != ""} {
	set dlgtoken [GetTokenFrom dlg w $win]
	if {$dlgtoken != ""} {
	    set chattoken [GetActiveChatToken $dlgtoken]
	    variable $chattoken
	    upvar 0 $chattoken chatstate

	    ::UI::SavePanePos $wDlgs(jchat) $chatstate(wtxt)
	}
    }
}

# Support for jabber:x:event ...................................................

# Handle incoming jabber:x:event (JEP-0022).

proc ::Chat::XEventRecv {chattoken xevent args} {
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
    
    ::Debug 6 "::Chat::XEventRecv \
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
		set name $chatstate(shortname)
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

    ::Debug 6 "::Chat::KeyPressEvent chattoken=$chattoken, char=$char"
    
    if {$char == ""} {
	return
    }
    if {[info exists chatstate(xevent,afterid)]} {
	after cancel $chatstate(xevent,afterid)
	unset chatstate(xevent,afterid)
    }
    if {[info exists chatstate(xevent,msgid)] && ($chatstate(xevent,status) == "")} {
	XEventSendCompose $chattoken
    }
    if {$chatstate(xevent,status) == "composing"} {
	set chatstate(xevent,afterid) [after $cprefs(xeventsmillis) \
	  [list [namespace current]::XEventSendCancelCompose $chattoken]]
    }
}

proc ::Chat::XEventSendCompose {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    variable cprefs

    ::Debug 2 "::Chat::XEventSendCompose chattoken=$chattoken"
    
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
	::UI::MessageBox -type ok -icon error -title "Network Error" \
	  -message "Network error ocurred: $err"
	return
    }    
}

proc ::Chat::XEventSendCancelCompose {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate

    ::Debug 2 "::Chat::XEventSendCancelCompose chattoken=$chattoken"

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
	::UI::MessageBox -type ok -icon error -title "Network Error" \
	  -message "Network error ocurred: $err"
	return
    }
}

# Various methods to handle chat history .......................................

namespace eval ::Chat:: {
    
    variable uidhist 1000
}

# Chat::PutMessageInHistoryFile --
#
#       Writes chat event send/received to history file.
#       
# Arguments:
#       jid       2-tier jid
#       msg       {jid2 threadID dateISO body}
#       
# Results:
#       none.

proc ::Chat::PutMessageInHistoryFile {jid msg} {
    global  prefs
    
    set mjid [jlib::jidmap $jid]
    set path [file join $prefs(historyPath) [uriencode::quote $jid]]    
    if {![catch {open $path a} fd]} {
	puts $fd "set message(\[incr uid]) {$msg}"
	close $fd
    }
}

proc ::Chat::BuildHistory {dlgtoken} {

    set chattoken [GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    jlib::splitjid $chatstate(jid) jid2 res
    BuildHistoryForJid $jid2
}

# Chat::BuildHistoryForJid --
#
#       Builds chat history dialog for jid.
#       
# Arguments:
#       jid       2-tier jid
#       
# Results:
#       dialog displayed.

proc ::Chat::BuildHistoryForJid {jid} {
    global  prefs this wDlgs
    variable uidhist
    variable historyOptions
    upvar ::Jabber::jstate jstate
    
    set jid [jlib::jidmap $jid]
    set w $wDlgs(jchist)[incr uidhist]
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
    
    set rosterName [$jstate(roster) getname $jid]
    if {$rosterName == ""} {
	set title "[mc {Chat History}]: $jid"
    } else {
	set title "[mc {Chat History}]: $rosterName ($jid)"
    }
    wm title $w $title
    
    set wtxt  $w.frall.fr
    set wtext $wtxt.t
    set wysc  $wtxt.ysc
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btclose -text [mc Close] \
      -command [list [namespace current]::CloseHistory $w]] \
      -side right -padx 5 -pady 5
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
    ConfigureTextTags $wchatframe $wtext    
    
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
		
		::Text::Parse $wtext $body $ptxttag
		$wtext insert end \n
	    }
	}
    } else {
	$wtext insert end "No registered chat history for $jid\n" histhead
    }
    $wtext configure -state disabled
    ::UI::SetWindowGeometry $w $wDlgs(jchist)
    wm minsize $w 200 320
}

proc ::Chat::ClearHistory {jid wtext} {
    global  prefs
    
    $wtext configure -state normal
    $wtext delete 1.0 end
    $wtext configure -state disabled
    set path [file join $prefs(historyPath) [uriencode::quote $jid]] 
    if {[file exists $path]} {
	file delete $path
    }
}

proc ::Chat::CloseHistory {w} {

    CloseHistoryHook $w
    destroy $w
}

proc ::Chat::CloseHistoryHook {wclose} {
    global  wDlgs
    
    if {[string match $wDlgs(jchist)* $wclose]} {
	::UI::SaveWinPrefixGeom $wDlgs(jchist)
    }   
}

proc ::Chat::PrintHistory {wtext} {
        
    ::UserActions::DoPrintText $wtext
}

proc ::Chat::SaveHistory {jid wtext} {
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

proc ::Chat::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    	
    set jprefs(chatActiveRet) 0
    set jprefs(showMsgNewWin) 1
    set jprefs(inbox2click)   "newwin"
    set jprefs(chat,normalAsChat) 0
    
    ::PreferencesUtils::Add [list  \
      [list ::Jabber::jprefs(showMsgNewWin) jprefs_showMsgNewWin $jprefs(showMsgNewWin)]  \
      [list ::Jabber::jprefs(inbox2click)   jprefs_inbox2click   $jprefs(inbox2click)]  \
      [list ::Jabber::jprefs(chat,normalAsChat)   jprefs_chatnormalAsChat   $jprefs(chat,normalAsChat)]  \
      [list ::Jabber::jprefs(chatActiveRet) jprefs_chatActiveRet $jprefs(chatActiveRet)]]    
}

proc ::Chat::BuildPrefsHook {wtree nbframe} {
    
    $wtree newitem {Jabber Chat} -text [mc Chat]
    
    set wpage [$nbframe page {Chat}]    
    ::Chat::BuildPrefsPage $wpage
}

proc ::Chat::BuildPrefsPage {wpage} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    set fontS  [option get . fontSmall {}]    
    set fontSB [option get . fontSmallBold {}]

    foreach key {chatActiveRet showMsgNewWin inbox2click chat,normalAsChat} {
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
    checkbutton $fr.normal -text " [mc prefchnormal]"  \
      -variable [namespace current]::tmpJPrefs(chat,normalAsChat)
    label $fr.lmb2 -text [mc prefcu2clk]
    radiobutton $fr.rb2new -text " [mc prefcuopen]" \
      -value newwin -variable [namespace current]::tmpJPrefs(inbox2click)
    radiobutton $fr.rb2re   \
      -text " [mc prefcureply]" -value reply \
      -variable [namespace current]::tmpJPrefs(inbox2click)

    grid $fr.active -sticky w
    grid $fr.newwin -sticky w
    grid $fr.normal -sticky w
    grid $fr.lmb2   -sticky w
    grid $fr.rb2new -sticky w
    grid $fr.rb2re  -sticky w
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
