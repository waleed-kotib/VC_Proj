#  Chat.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements chat type of UI for jabber.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
# $Id: Chat.tcl,v 1.47 2004-03-16 15:09:08 matben Exp $

package require entrycomp
package require uriencode

package provide Chat 1.0


namespace eval ::Jabber::Chat:: {
    global  wDlgs
    
    # Add all event hooks.
    ::hooks::add quitAppHook        [list ::UI::SaveWinGeom $wDlgs(jstartchat)]
    ::hooks::add quitAppHook        [list ::UI::SaveWinPrefixGeom $wDlgs(jchat)]
    ::hooks::add quitAppHook        ::Jabber::Chat::GetFirstPanePos    
    ::hooks::add newChatMessageHook ::Jabber::Chat::GotMsg
    ::hooks::add presenceHook       ::Jabber::Chat::PresenceCallback
    ::hooks::add closeWindowHook    ::Jabber::Chat::CloseHook
    ::hooks::add closeWindowHook    ::Jabber::Chat::CloseHistoryHook
    ::hooks::add loginHook          ::Jabber::Chat::LoginHook
    ::hooks::add logoutHook         ::Jabber::Chat::LogoutHook

    # Define all hooks for preference settings.
    ::hooks::add prefsInitHook      ::Jabber::Chat::InitPrefsHook
    ::hooks::add prefsBuildHook     ::Jabber::Chat::BuildPrefsHook
    ::hooks::add prefsSaveHook      ::Jabber::Chat::SavePrefsHook
    ::hooks::add prefsCancelHook    ::Jabber::Chat::CancelPrefsHook

    # Use option database for customization. 
    # These are nonstandard option valaues and we may therefore keep priority
    # widgetDefault.
    set fontS  [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]

    # Icons
    option add *Chat*sendImage            send                  widgetDefault
    option add *Chat*sendDisImage         sendDis               widgetDefault
    option add *Chat*sendFileImage        sendfile              widgetDefault
    option add *Chat*sendFileDisImage     sendfile              widgetDefault
    option add *Chat*saveImage            save                  widgetDefault
    option add *Chat*saveDisImage         saveDis               widgetDefault
    option add *Chat*historyImage         history               widgetDefault
    option add *Chat*historyDisImage      historyDis            widgetDefault
    option add *Chat*printImage           print                 widgetDefault
    option add *Chat*printDisImage        printDis              widgetDefault

    option add *Chat*notifierImage        notifier              widgetDefault    
    
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
    option add *Chat*sysForeground        #26b412               widgetDefault
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
	{sys         -foreground          sysForeground         Foreground}
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
    
    # Running number for chat thread token.
    variable uid 0
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

    ::Jabber::Debug 2 "::Jabber::Chat::StartThreadDlg args='$args'"

    set w $wDlgs(jstartchat)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w [::msgcat::mc {Start Chat}]
    
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 12 -ipady 4
    
    ::headlabel::headlabel $w.frall.head -text [::msgcat::mc {Chat with}]
    pack $w.frall.head -side top -fill both -expand 1
    
    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    pack $frmid -side top -fill both -expand 1
    
    set jidlist [::Jabber::InvokeRosterCmd getusers -type available]
    label $frmid.luser -text "[::msgcat::mc {Jabber user id}]:"  \
      -font $fontSB -anchor e
    ::entrycomp::entrycomp $frmid.euser $jidlist -width 26    \
      -textvariable [namespace current]::user
    grid $frmid.luser -column 0 -row 1 -sticky e
    grid $frmid.euser -column 1 -row 1 -sticky w
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [::msgcat::mc OK] \
      -default active -command [list [namespace current]::DoStart $w]] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel]  \
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
    if {![::Jabber::InvokeRosterCmd isavailable $user]} {
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

    ::Jabber::Debug 2 "::Jabber::Chat::GotMsg args='$args'"

    array set argsArr $args
    
    # -from is a 3-tier jid /resource included.
    set jid $argsArr(-from)
    jlib::splitjid $jid jid2 res
    set username $jid2
    regexp {^([^@]+)@} $jid2 match username
    
    # We must follow the thread...
    if {[info exists argsArr(-thread)]} {
	set threadID $argsArr(-thread)
	set token [::Jabber::Chat::GetTokenFrom threadid $threadID]
    } else {
	
	# Try to find a reasonable fallback for clients that fail here (Psi).
	# Find if we have registered any chat for this jid 2/3.
	set token [::Jabber::Chat::GetTokenFrom jid ${jid2}*]
	if {$token == ""} {
	    
	    # Need to create a new thread ID.
	    set threadID [::sha1pure::sha1 "$jstate(mejid)[clock seconds]"]
	} else {
	    variable $token
	    upvar 0 $token state

	    set threadID $state(threadid)
	}
    }
    
    # We may not yet have a dialog for this thread. Make one.
    if {$token == ""} {
	if {$body == ""} {
	    # Junk
	    return
	} else {
	    set token [eval {::Jabber::Chat::Build $threadID} $args]	
	    eval {::hooks::run newChatThreadHook $body} $args
	}
    }
    variable $token
    upvar 0 $token state

    # We may have reset its jid to a 2-tier jid if it has been offline.
    set state(jid) $jid
    
    set w $state(w)
    if {[info exists argsArr(-subject)]} {
	set state(subject) $argsArr(-subject)
	set state(lastsubject) $state(subject)
	::Jabber::Chat::InsertMessage $token sys "Subject: $state(subject)\n"
    }
    
    # See if we've got a jabber:x:event (JEP-0022).
    if {[info exists argsArr(-x)]} {
	set xevent [lindex [wrapper::getnamespacefromchilds  \
	  $argsArr(-x) x "jabber:x:event"] 0]
	if {[llength $xevent]} {
	    eval {::Jabber::Chat::XEventRecv $token $xevent} $args
	}
    }
    
    # And put message in window if nonempty, and history file.
    if {$body != ""} {
	::Jabber::Chat::InsertMessage $token you $body
	set dateISO [clock format [clock seconds] -format "%Y%m%dT%H:%M:%S"]
	::Jabber::Chat::PutMessageInHistoryFile $jid2 \
	  [list $jid2 $threadID $dateISO $body]
    }
    if {$state(got1stMsg) == 0} {
	set state(got1stMsg) 1
    }
    
    # Run this hook (speech).
    eval {::hooks::run displayChatMessageHook $body} $args
}

# Jabber::Chat::InsertMessage --
# 
#       Puts message in text chat window.

proc ::Jabber::Chat::InsertMessage {token whom body} {
    variable $token
    upvar 0 $token state
    
    set w     $state(w)
    set wtext $state(wtext)
    set jid   $state(jid)
    set secs  [clock seconds]
    set clockFormat [option get $w clockFormat {}]
    
    switch -- $whom {
	me {
	    jlib::splitjid [::Jabber::GetMyJid] jid2 res
	    set username $jid2
	    regexp {^([^@]+)@} $jid2 match username
	}
	you {
	    jlib::splitjid $jid jid2 res
	    if {[::Jabber::InvokeJlibCmd service isroom $jid2]} {
		set username [::Jabber::InvokeJlibCmd service nick $jid]
	    } else {
		set username $jid2
		regexp {^([^@]+)@} $jid2 match username
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
	    append prefix "<$username>"
	}
	sys {
	}
    }
    $wtext configure -state normal
    
    switch -- $whom {
	me {
	    $wtext insert end $prefix mepre
	    $wtext insert end "   " metext
	    ::Text::ParseAndInsert $wtext $body metext linktag
	}
	you {
	    $wtext insert end $prefix youpre
	    $wtext insert end "   " youtext
	    ::Text::ParseAndInsert $wtext $body youtext linktag
	}
	sys {
	    $wtext insert end $prefix syspre
	    $wtext insert end $body sys
	}
    }

    $wtext configure -state disabled
    $wtext see end
}

# Jabber::Chat::StartThread --
# 
# Arguments:
#       jid

proc ::Jabber::Chat::StartThread {jid} {

    upvar ::Jabber::jstate jstate

    # Make unique thread id.
    set threadID [::sha1pure::sha1 "$jstate(mejid)[clock seconds]"]
    ::Jabber::Chat::Build $threadID -from $jid
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
#       token; shows window.

proc ::Jabber::Chat::Build {threadID args} {
    global  this prefs wDlgs
    
    variable uid
    variable cprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::Chat::Build threadID=$threadID, args='$args'"

    # Initialize the state variable, an array, that keeps is the storage.
    
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
    
    set w $wDlgs(jchat)${uid}
    array set argsArr $args

    set state(w)                $w
    set state(threadid)         $threadID
    set state(active)           $cprefs(lastActiveRet)
    set state(got1stMsg)        0
    set state(subject)          ""
    set state(lastsubject)      ""
    set state(notifier)         " "
    set state(xevent,status)    ""
    set state(xevent,msgidlist) ""
    set state(dlgstate)         normal
    
    if {$jprefs(chatActiveRet)} {
	set state(active) 1
    }
    
    # Toplevel with class Chat.
    ::UI::Toplevel $w -class Chat -usemacmainmenu 1 -macstyle documentProc
 
    # -from is sometimes a 3-tier jid /resource included.
    # Try to keep any /resource part unless not possible.
    
    if {[info exists argsArr(-from)]} {
	set state(jid) [::Jabber::InvokeJlibCmd getrecipientjid $argsArr(-from)]
    } else {
	set state(jid) ""
    }
    jlib::splitjid $state(jid) jid2 res
    
    if {[info exists argsArr(-subject)]} {
	set state(subject) $argsArr(-subject)
    }

    wm title $w "[::msgcat::mc Chat] ($state(jid))"
    set fontSB [option get . fontSmallBold {}]
    if {$state(active)} {
	::Jabber::Chat::ActiveCmd $token
    }

    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall  -fill both -expand 1 -ipadx 4
    
    # Widget paths.
    set frmid    $w.frall.frmid
    set wtxt     $frmid.frtxt
    set wtext    $wtxt.text
    set wysc     $wtxt.ysc
    set wtxtsnd  $frmid.frtxtsnd        
    set wtextsnd $wtxtsnd.text
    set wyscsnd  $wtxtsnd.ysc
    set wtray    $w.frall.tray
        
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

    set iconNotifier   [::Theme::GetImage [option get $w notifierImage {}]]
    set state(iconNotifier) $iconNotifier

    ::buttontray::buttontray $wtray 50
    pack $wtray -side top -fill x -padx 4 -pady 2

    $wtray newbutton send    Send    $iconSend    $iconSendDis    \
      [list [namespace current]::Send $token]
    $wtray newbutton sendfile {Send File} $iconSendFile $iconSendFileDis    \
      [list [namespace current]::SendFile $token]
     $wtray newbutton save   Save    $iconSave    $iconSaveDis    \
       [list [namespace current]::Save $token]
    $wtray newbutton history History $iconHistory $iconHistoryDis \
      [list [namespace current]::BuildHistory $jid2]
    $wtray newbutton print   Print   $iconPrint   $iconPrintDis   \
      [list [namespace current]::Print $token]
    
    ::hooks::run buildChatButtonTrayHook $wtray $state(jid)
    
    set shortBtWidth [$wtray minwidth]

    # Button part.
    pack [frame $w.frall.pady -height 8] -side bottom
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [::msgcat::mc Send] -default active \
      -command [list [namespace current]::Send $token]]  \
      -side right -padx 5
    pack [button $frbot.btcancel -text [::msgcat::mc Close]  \
      -command [list [namespace current]::Close $token]]  \
      -side right -padx 5
    pack [::Jabber::UI::SmileyMenuButton $frbot.smile $wtextsnd]  \
      -side right -padx 5
    pack [checkbutton $frbot.active -text " [::msgcat::mc {Active <Return>}]" \
      -command [list [namespace current]::ActiveCmd $token] \
      -variable $token\(active)]  \
      -side left -padx 5
    pack $frbot -side bottom -fill x -padx 10
    
    # Notifier label.
    set state(wnotifier) $w.frall.f.lnot
    pack [frame $w.frall.f] -side bottom -anchor w -padx 16 -pady 0
    pack [frame $w.frall.f.pad -width 1 -height [image height $iconNotifier]] \
      -side left -pady 0
    pack [label $state(wnotifier) -textvariable $token\(notifier)  \
      -pady 0 -bd 0 -compound left] -side right -pady 0
    
    pack [frame $w.frall.div2 -bd 2 -relief sunken -height 2] -fill x -side top
    
    # To and subject fields.
    set frtop [frame $w.frall.frtop -borderwidth 0]
    pack $frtop -side top -anchor w -fill x
    
    frame $frtop.fjid
    label $frtop.fjid.l -text [::msgcat::mc {Chat with}]
    label $frtop.fjid.ljid -textvariable $token\(jid)
    pack $frtop.fjid -side top -anchor w -padx 6
    grid $frtop.fjid.l $frtop.fjid.ljid -sticky w -padx 1
    
    frame $frtop.fsub
    label $frtop.fsub.l -text "[::msgcat::mc Subject]:"
    entry $frtop.fsub.e -textvariable $token\(subject)
    pack $frtop.fsub -side top -anchor w -padx 6 -fill x
    pack $frtop.fsub.l -side left -padx 2
    pack $frtop.fsub.e -side top -padx 2 -fill x

    # Text chat.
    pack [frame $frmid -height 250 -width 300 -relief sunken -bd 1 -class Pane] \
      -side top -fill both -expand 1 -padx 4 -pady 2
    frame $wtxt
        
    text $wtext -height 12 -width 1 -state disabled -cursor {} \
      -borderwidth 1 -relief sunken -yscrollcommand [list $wysc set] -wrap word
    scrollbar $wysc -orient vertical -command [list $wtext yview]
    grid $wtext -column 0 -row 0 -sticky news
    grid $wysc -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxt 0 -weight 1
    grid rowconfigure $wtxt 0 -weight 1
    
    # The tags.
    ::Jabber::Chat::ConfigureTextTags $w $wtext

    # Text send.
    frame $wtxtsnd
    text $wtextsnd -height 4 -width 1 -wrap word \
      -borderwidth 1 -relief sunken -yscrollcommand [list $wyscsnd set]
    scrollbar $wyscsnd -orient vertical -command [list $wtextsnd yview]
    grid $wtextsnd -column 0 -row 0 -sticky news
    grid $wyscsnd -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxtsnd 0 -weight 1
    grid rowconfigure $wtxtsnd 0 -weight 1
    
    set imageHorizontal \
      [::Theme::GetImage [option get $frmid imageHorizontal {}]]
    set sashHBackground [option get $frmid sashHBackground {}]

    set paneopts [list -orient vertical -limit 0.0]
    if {[info exists prefs(paneGeom,$wDlgs(jchat)]} {
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
        
    set state(wtray)    $wtray
    set state(wtext)    $wtext
    set state(wtxt)     $wtxt
    set state(wtextsnd) $wtextsnd
    set state(wbtsend)  $w.frall.frbot.btok

    # We need the window title to reflect the receiving jid.
    trace variable $token\(jid) w  \
      [list [namespace current]::TraceJid $token]
    
    # jabber:x:event
    if {$cprefs(usexevents)} {
	bind $wtextsnd <KeyPress>  \
	  [list +[namespace current]::KeyPressEvent $token %A]
    }
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jchat)]]
    if {$nwin == 1} {
	::UI::SetWindowGeometry $w $wDlgs(jchat)
    }
    wm minsize $w [expr {$shortBtWidth < 220} ? 220 : $shortBtWidth] 320
    wm maxsize $w 800 2000
    
    focus $w
    return $token
}

proc ::Jabber::Chat::CloseHook {wclose} {
    global  wDlgs
    
    if {[string match $wDlgs(jchat)* $wclose]} {
	set token [::Jabber::Chat::GetTokenFrom w $wclose]
	if {$token != ""} {
	    ::Jabber::Chat::Close $token
	}
    }   
    return ""
}

proc ::Jabber::Chat::LoginHook { } {

    foreach token [::Jabber::Chat::GetTokenList] {
	variable $token
	upvar 0 $token state
	
	foreach name {send sendfile} {
	    $state(wtray) buttonconfigure $name -state normal 
	}
	$state(wbtsend) configure -state normal
    }
    return ""
}

proc ::Jabber::Chat::LogoutHook { } {
    
    foreach token [::Jabber::Chat::GetTokenList] {
	::Jabber::Chat::SetState $token disabled
    }
    return ""
}

proc ::Jabber::Chat::ConfigureTextTags {w wtext} {
    variable chatOptions
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::Chat::ConfigureTextTags"
    
    set space 2
    set alltags {mepre metext youpre youtext syspre sys histhead}
        
    if {[string length $jprefs(chatFont)]} {
	set chatFont $jprefs(chatFont)
	set boldChatFont [lreplace $jprefs(chatFont) 2 2 bold]
    }
    foreach tag $alltags {
	set opts($tag) [list -spacing1 $space]
    }
    foreach spec $chatOptions {
	foreach {tag optName resName resClass} $spec break
	set value [option get $w $resName $resClass]
	if {[string length $jprefs(chatFont)] && [string equal $optName "-font"]} {
	    
	    switch $resName {
		mePreFont - youPreFont {
		    #set value $boldChatFont
		    set value $chatFont
		}
		meTextFont - youTextFont {
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
    lappend opts(sys)      -spacing3 $space -lmargin1 20 -lmargin2 20
    lappend opts(histhead) -spacing1 4 -spacing3 4 -lmargin1 20 -lmargin2 20
    foreach tag $alltags {
	eval {$wtext tag configure $tag} $opts($tag)
    }
    
    ::Text::ConfigureLinkTagForTextWidget $wtext linktag tact
}

proc ::Jabber::Chat::SetFont {theFont} {    
    upvar ::Jabber::jprefs jprefs

    ::Jabber::Debug 2 "::Jabber::Chat::SetFont theFont=$theFont"

    set jprefs(chatFont) $theFont
        
    foreach token [GetTokenList] {
	variable $token
	upvar 0 $token state

	set w $state(w)
	if {[winfo exists $w]} {
	    ::Jabber::Chat::ConfigureTextTags $w $state(wtext)
	} else {
	    catch {unset state}
	}
    }
}

proc ::Jabber::Chat::ActiveCmd {token} {
    variable cprefs
    variable $token
    upvar 0 $token state

    ::Jabber::Debug 2 "::Jabber::Chat::ActiveCmd: token=$token"
    
    set w $state(w)
    if {$state(active)} {
	bind $w <Return> [list [namespace current]::Send $token]
    } else {
	bind $w <Return> {}
    }
    
    # Remember last setting.
    set cprefs(lastActiveRet) $state(active)
}

proc ::Jabber::Chat::Send {token} {
    global  prefs
    
    variable $token
    upvar 0 $token state
    variable cprefs
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Chat::Send "
    
    # Check that still connected to server.
    if {![::Jabber::IsConnected]} {
	tk_messageBox -type ok -icon error -title [::msgcat::mc {Not Connected}] \
	  -message [::msgcat::mc jamessnotconnected]
	return
    }
    set w        $state(w)
    set wtextsnd $state(wtextsnd)
    set threadID $state(threadid)
    
    # According to XMPP we should send to 3-tier jid if still online,
    # else to 2-tier.
    set jid [::Jabber::InvokeJlibCmd getrecipientjid $state(jid)]
    set state(jid) $jid
    jlib::splitjid $jid jid2 res

    if {![::Jabber::IsWellFormedJID $jid]} {
	set ans [tk_messageBox -message [FormatTextForMessageBox  \
	  [::msgcat::mc jamessbadjid $jid]] \
	  -icon error -type yesno]
	if {[string equal $ans "no"]} {
	    return
	}
    }

    # Get text to send. Strip off any ending newlines from Return.
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
    if {![string equal $state(subject) $state(lastsubject)]} {
	lappend opts -subject $state(subject)
	::Jabber::Chat::InsertMessage $token sys  \
	  "Subject: $state(subject)\n"
    }
    set state(lastsubject) $state(subject)
    
    # Cancellations of any message composing jabber:x:event
    if {$cprefs(usexevents) &&  \
      [string equal $state(xevent,status) "composing"]} {
	::Jabber::Chat::XEventCancelCompose $token
    }
    
    # Requesting composing notification.
    if {$cprefs(usexevents)} {
	lappend opts -id [incr cprefs(xeventid)]
	lappend opts -xlist [list \
	  [wrapper::createtag "x" -attrlist {xmlns jabber:x:event}  \
	  -subtags [list [wrapper::createtag "composing"]]]]
    }
    
    if {[catch {
	eval {::Jabber::InvokeJlibCmd send_message $jid  \
	  -thread $threadID -type chat -body $allText} $opts
    } err]} {
	tk_messageBox -type ok -icon error -title "Network Error" \
	  -message "Network error ocurred: $err"
	return
    }
    set state(lastsentsecs) $secs
    
    # Add to chat window and clear send.        
    ::Jabber::Chat::InsertMessage $token me $allText
    $wtextsnd delete 1.0 end

    if {$state(got1stMsg) == 0} {
	set state(got1stMsg) 1
    }
    
    # Run this hook (speech).
    set opts [list -from $jid2]
    eval {::hooks::run displayChatMessageHook $allText} $opts
}

proc ::Jabber::Chat::TraceJid {token name junk1 junk2} {
    variable $token
    upvar 0 $token state
    
    # Call by name.
    upvar $name locName    
    wm title $state(w) "Chat ($state(jid))"
}

proc ::Jabber::Chat::SendFile {token} {
    variable $token
    upvar 0 $token state
    
    jlib::splitjid $state(jid) jid2 res
    ::Jabber::OOB::BuildSet $jid2
}

proc ::Jabber::Chat::Print {token} {
    variable $token
    upvar 0 $token state
    
    ::UserActions::DoPrintText $state(wtext)
}

proc ::Jabber::Chat::Save {token} {
    global  this
    variable $token
    upvar 0 $token state
    
    set wtext $state(wtext)
    
    set ans [tk_getSaveFile -title [::msgcat::mc {Save Message}] \
      -initialfile "Chat $state(jid).txt"]
    
    if {[string length $ans]} {
	set allText [::Text::TransformToPureText $wtext]
	set fd [open $ans w]
	puts $fd "Chat with:\t$state(jid)"
	puts $fd "Subject:\t$state(subject)"
	puts $fd "\n"
	puts $fd $allText	
	close $fd
	if {[string equal $this(platform) "macintosh"]} {
	    file attributes $ans -type TEXT -creator ttxt
	}
    }
}

proc ::Jabber::Chat::PresenceCallback {jid type args} {
    
    upvar ::Jabber::mapShowTextToElem mapShowTextToElem

    # ::Jabber::Chat::PresenceCallback: args=marilu@jabber.dk unavailable 
    #-resource Psi -type unavailable -type unavailable -from marilu@jabber.dk/Psi
    #-to matben@jabber.dk -status Disconnected
    array set argsArr $args
    set from $jid
    if {[info exists argsArr(-from)]} {
	set from $argsArr(-from)
    }
    
    set token [::Jabber::Chat::GetTokenFrom jid ${jid}*]
    if {$token == ""} {
	
	# Likely no chat with this jid.
	return
    }
    variable $token
    upvar 0 $token state
    
    set show $type
    if {[info exists argsArr(-show)]} {
	set show $argsArr(-show)
    }
    set status ""
    if {[info exists argsArr(-status)]} {
	set status "$argsArr(-status)\n"
    }
    ::Jabber::Chat::InsertMessage $token sys  \
      "$jid is: $mapShowTextToElem($show)\n$status"
    
    if {[string equal $type "available"]} {
	::Jabber::Chat::SetState $token normal
    } else {
	::Jabber::Chat::SetState $token disabled
    }
}

# Jabber::Chat::GetTokenFrom --
# 
#       Try to get the token state array from any stored key.
#       
# Arguments:
#       key         w, jid, threadid etc...
#       pattern     glob matching
#       
# Results:
#       token or empty if not found.

proc ::Jabber::Chat::GetTokenFrom {key pattern} {
    
    # Search all tokens for this key into state array.
    foreach token [::Jabber::Chat::GetTokenList] {
	variable $token
	upvar 0 $token state
	
	if {[info exists state($key)] && [string match $pattern $state($key)]} {
	    return $token
	}
    }
    return ""
}

proc ::Jabber::Chat::GetTokenList { } {
    
    set ns [namespace current]
    return [concat  \
      [info vars ${ns}::\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]\[0-9\]\[0-9\]\[0-9\]]]
}

# Jabber::Chat::SetState --
# 
#       Set state of complete dialog to normal or disabled.
  
proc ::Jabber::Chat::SetState {token dlgstate} {
    variable $token
    upvar 0 $token state    
    
    foreach name {send sendfile} {
	$state(wtray) buttonconfigure $name -state $dlgstate 
    }
    $state(wbtsend)  configure -state $dlgstate
    $state(wtextsnd) configure -state $dlgstate
    set state(dlgstate) $dlgstate
}

# Jabber::Chat::Close --
#
#

proc ::Jabber::Chat::Close {token} {
    global  wDlgs prefs
    
    variable $token
    upvar 0 $token state    
    
    ::Jabber::Debug 2 "::Jabber::Chat::Close: token=$token"
    
    #set ans [tk_messageBox -icon info -parent $w -type yesno \
    #  -message [FormatTextForMessageBox [::msgcat::mc jamesschatclose]]]
    set ans "yes"
    if {$ans == "yes"} {
	::UI::SaveWinGeom $wDlgs(jchat) $state(w)
	::UI::SavePanePos $wDlgs(jchat) $state(wtxt)
	destroy $state(w)
	
	# Remove trace on windows title.
	trace vdelete $token\(jid) w  \
	  [namespace current]::TraceJid
	::Jabber::Chat::XEventCancelCompose $token
	
	# Array cleanup?
	unset state
    }
}

proc ::Jabber::Chat::GetFirstPanePos { } {
    global  wDlgs
    
    set win [::UI::GetFirstPrefixedToplevel $wDlgs(jchat)]
    if {$win != ""} {
	set token [::Jabber::Chat::GetTokenFrom w $win]
	if {$token != ""} {
	    variable $token
	    upvar 0 $token state    
	    ::UI::SavePanePos $wDlgs(jchat) $state(wtxt)
	}
    }
}

# Support for jabber:x:event ...................................................

# Handle incoming jabber:x:event (JEP-0022).

proc ::Jabber::Chat::XEventRecv {token xevent args} {
    variable $token
    upvar 0 $token state
	
    array set argsArr $args

    # This can be one of three things:
    # 1) Request for event notification
    # 2) Notification of message composing
    # 3) Cancellations of message composing
    
    set msgid ""
    if {[info exists argsArr(-id)]} {
	set msgid $argsArr(-id)
	lappend state(xevent,msgidlist) $msgid
    }
    set composeElem [wrapper::getchildswithtag $xevent "composing"]
    set idElem [wrapper::getchildswithtag $xevent "id"]
    ::Jabber::Debug 6 "::Jabber::Chat::XEventRecv \
      msgid=$msgid, composeElem=$composeElem, idElem=$idElem"
    if {($msgid != "") && ($composeElem != "") && ($idElem == "")} {
	
	# 1) Request for event notification
	set state(xevent,msgid) $argsArr(-id)
	
    } elseif {($composeElem != "") && ($idElem != "")} {
	
	# 2) Notification of message composing
	jlib::splitjid $state(jid) jid2 res
	set name [::Jabber::InvokeRosterCmd getname $jid2]
	if {$name == ""} {
	    if {[::Jabber::InvokeJlibCmd service isroom $jid2]} {
		set name [::Jabber::InvokeJlibCmd service nick $state(jid)]

	    } elseif {![regexp {^([^@]+)@.+} $jid2 m name]} {
		set name $jid2
	    }
	}
	$state(wnotifier) configure -image $state(iconNotifier)
	set state(notifier) " [::msgcat::mc chatcompreply $name]"
    } elseif {($composeElem == "") && ($idElem != "")} {
	
	# 3) Cancellations of message composing
	$state(wnotifier) configure -image ""
	set state(notifier) " "
    }
}

proc ::Jabber::Chat::KeyPressEvent {token char} {
    variable $token
    upvar 0 $token state
    variable cprefs

    ::Jabber::Debug 6 "::Jabber::Chat::KeyPressEvent token=$token, char=$char"
    
    if {$char == ""} {
	return
    }
    if {[info exists state(xevent,afterid)]} {
	after cancel $state(xevent,afterid)
	unset state(xevent,afterid)
    }    
    if {[info exists state(xevent,msgid)] && ($state(xevent,status) == "")} {
	::Jabber::Chat::XEventSendCompose $token
    }
    if {$state(xevent,status) == "composing"} {
	set state(xevent,afterid) [after $cprefs(xeventsmillis) \
	  [list [namespace current]::XEventCancelCompose $token]]
    }
}

proc ::Jabber::Chat::XEventSendCompose {token} {
    variable $token
    upvar 0 $token state
    variable cprefs

    ::Jabber::Debug 2 "::Jabber::Chat::XEventSendCompose token=$token"

    if {$state(dlgstate) != "normal"} {
	return
    }
    set state(xevent,status) "composing"

    # Pick the id of the most recent event request and skip any previous.
    set id [lindex $state(xevent,msgidlist) end]
    set state(xevent,msgidlist) [lindex $state(xevent,msgidlist) end]
    set state(xevent,composeid) $id
    
    set xelems [list \
      [wrapper::createtag "x" -attrlist {xmlns jabber:x:event}  \
      -subtags [list  \
      [wrapper::createtag "composing"] \
      [wrapper::createtag "id" -chdata $id]]]]
    
    if {[catch {
	::Jabber::InvokeJlibCmd send_message $state(jid)  \
	  -thread $state(threadid) -type chat -xlist $xelems
    } err]} {
	tk_messageBox -type ok -icon error -title "Network Error" \
	  -message "Network error ocurred: $err"
	return
    }    
}

proc ::Jabber::Chat::XEventCancelCompose {token} {
    variable $token
    upvar 0 $token state

    ::Jabber::Debug 2 "::Jabber::Chat::XEventCancelCompose token=$token"

    # We may have been destroyed.
    if {![info exists state]} {
	return
    }
    if {$state(dlgstate) != "normal"} {
	return
    }
    if {[info exists state(xevent,afterid)]} {
	after cancel $state(xevent,afterid)
	unset state(xevent,afterid)
    }
    if {$state(xevent,status) == ""} {
	return
    }
    set id $state(xevent,composeid)
    set state(xevent,status) ""
    set state(xevent,composeid) ""

    set xelems [list \
      [wrapper::createtag "x" -attrlist {xmlns jabber:x:event}  \
      -subtags [list [wrapper::createtag "id" -chdata $id]]]]

    if {[catch {
	::Jabber::InvokeJlibCmd send_message $state(jid)  \
	  -thread $state(threadid) -type chat -xlist $xelems
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
    
    set path [file join $prefs(historyPath) [uriencode::quote $jid]]    
    if {![catch {open $path a} fd]} {
	puts $fd "set message(\[incr uid]) {$msg}"
	close $fd
    }
}

# Jabber::Chat::PutMessageInHistoryFile --
#
#       Builds chat history dialog for jid.
#       
# Arguments:
#       jid       2-tier jid
#       
# Results:
#       dialog displayed.

proc ::Jabber::Chat::BuildHistory {jid} {
    global  prefs this wDlgs
    variable uidhist
    variable historyOptions
    
    set w $wDlgs(jchist)[incr uidhist]
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
    wm title $w "[::msgcat::mc {Chat History}]: $jid"
    
    set wtxt  $w.frall.fr
    set wtext $wtxt.t
    set wysc  $wtxt.ysc
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btclose -text [::msgcat::mc Close] \
      -command "destroy $w"] -side right -padx 5 -pady 5
    pack [button $frbot.btclear -text [::msgcat::mc Clear]  \
      -command [list [namespace current]::ClearHistory $jid $wtext]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btprint -text [::msgcat::mc Print]  \
      -command [list [namespace current]::PrintHistory $wtext]]  \
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
	    $wtext insert end "[::msgcat::mc {Thread started}] $when\n" histhead
	    
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
		
		::Text::ParseAndInsert $wtext $body $ptxttag linktag
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

# Preference page --------------------------------------------------------------

proc ::Jabber::Chat::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    
    set jprefs(chatActiveRet) 0

    ::PreferencesUtils::Add [list  \
      [list ::Jabber::jprefs(chatFont)      jprefs_chatFont      $jprefs(chatFont)]  \
      [list ::Jabber::jprefs(chatActiveRet) jprefs_chatActiveRet $jprefs(chatActiveRet)]]    
}

proc ::Jabber::Chat::BuildPrefsHook {wtree nbframe} {
    
    $wtree newitem {Jabber Chat} -text [::msgcat::mc Chat]
    
    set wpage [$nbframe page {Chat}]    
    ::Jabber::Chat::BuildPrefsPage $wpage
}

proc ::Jabber::Chat::BuildPrefsPage {wpage} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    set fontS  [option get . fontSmall {}]    
    set fontSB [option get . fontSmallBold {}]
    
    set tmpJPrefs(chatActiveRet) $jprefs(chatActiveRet)
    set tmpJPrefs(chatFont) $jprefs(chatFont)
    
    set labfr ${wpage}.alrt
    labelframe $labfr -text [::msgcat::mc {Chat}]
    pack $labfr -side top -anchor w -padx 8 -pady 4
    
    set fr $labfr.fr
    pack [frame $fr] -side top -anchor w -padx 8 -pady 2
 
    label $fr.lfont -text [::msgcat::mc prefcufont]
    button $fr.btfont -text "[::msgcat::mc Pick]..." -font $fontS \
      -command [namespace current]::PickFont
    checkbutton $fr.active -text "  [::msgcat::mc prefchactret]"  \
      -variable [namespace current]::tmpJPrefs(chatActiveRet)

    grid $fr.lfont $fr.btfont -padx 2 -sticky w
    grid $fr.active -sticky w
}

proc ::Jabber::Chat::PickFont { } {
    variable tmpJPrefs
    
    set fontS [option get . fontSmall {}]
    array set fontArr [font actual $fontS]

    if {[string length $tmpJPrefs(chatFont)]} {
	set opts [list  \
	  -defaultfont    "" \
	  -defaultsize    "" \
	  -defaultweight  "" \
	  -initialfont [lindex $tmpJPrefs(chatFont) 0]  \
	  -initialsize [lindex $tmpJPrefs(chatFont) 1]  \
	  -initialweight [lindex $tmpJPrefs(chatFont) 2]]
    } else {
	set opts {-defaultfont "" -defaultsize "" -defaultweight  ""}
    }
    
    # Default font is here {{} {} {}} which shall match an empty chatFont.
    set theFont [eval {::fontselection::fontselection .mnb} $opts]
    if {[llength $theFont]} {
	if {[lindex $theFont 0] == ""} {
	    set tmpJPrefs(chatFont) ""
	} else {
	    set tmpJPrefs(chatFont) $theFont
	}
    }
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

#-------------------------------------------------------------------------------
