#  Chat.tcl ---
#  
#      This file is part of the whiteboard application. 
#      It implements chat type of UI for jabber.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
# $Id: Chat.tcl,v 1.26 2003-12-29 09:02:29 matben Exp $

package require entrycomp
package require uriencode

package provide Chat 1.0


namespace eval ::Jabber::Chat:: {
    global  wDlgs
    
    # Use option database for customization. 
    # These are nonstandard option valaues and we may therefore keep priority
    # widgetDefault.
    set fontS  [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]

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
    option add *Chat*sysPreForeground     green                 widgetDefault
    option add *Chat*sysForeground        green                 widgetDefault
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
    }

    # Add all event hooks.
    hooks::add quitAppHook        [list ::UI::SaveWinGeom $wDlgs(jstartchat)]
    hooks::add quitAppHook        [list ::UI::SaveWinPrefixGeom $wDlgs(jchat)]
    hooks::add quitAppHook        ::Jabber::Chat::GetFirstPanePos    
    hooks::add newChatMessageHook ::Jabber::Chat::GotMsg
    hooks::add presenceHook       ::Jabber::Chat::PresenceCallback
        
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
	return
    }
    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
	::UI::MacUseMainMenu $w
    } else {

    }
    wm title $w [::msgcat::mc {Start Chat}]
    
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]  \
      -fill both -expand 1 -ipadx 12 -ipady 4
    
    ::headlabel::headlabel $w.frall.head -text [::msgcat::mc {Chat with}]
    pack $w.frall.head -side top -fill both -expand 1
    
    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    pack $frmid -side top -fill both -expand 1
    
    set jidlist [$jstate(roster) getusers -type available]
    label $frmid.luser -text "[::msgcat::mc {Jabber user id}]:"  \
      -font $fontSB -anchor e
    ::entrycomp::entrycomp $frmid.euser $jidlist -width 26    \
      -textvariable [namespace current]::user
    grid $frmid.luser -column 0 -row 1 -sticky e
    grid $frmid.euser -column 1 -row 1 -sticky w
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [::msgcat::mc OK] -width 8 \
      -default active -command [list [namespace current]::DoStart $w]] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command [list [namespace current]::DoCancel $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    ::UI::SetWindowPosition $w
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    
    # Grab and focus.
    set oldFocus [focus]
    focus $frmid.euser
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    # Clean up.
    ::UI::SaveWinGeom $wDlgs(jstartchat)
    catch {grab release $w}
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
	set token [eval {::Jabber::Chat::Build $threadID} $args]	
	eval {hooks::run newChatThreadHook $body} $args
    }
    variable $token
    upvar 0 $token state

    # We may have reset its jid to a 2-tier jid if it has been offline.
    set state(jid) $jid

    set w $state(w)
    if {[info exists argsArr(-subject)]} {
	set state(subject) $argsArr(-subject)
    }

    ::Jabber::Chat::InsertMessage $token you $body
    
    if {$state(got1stMsg) == 0} {
	$state(wtojid) configure -state disabled
	set state(got1stMsg) 1
    }
    set dateISO [clock format [clock seconds] -format "%Y%m%dT%H:%M:%S"]
    ::Jabber::Chat::PutMessageInHistoryFile $jid2 \
      [list $jid2 $threadID $dateISO $body]
    
    # Run this hook (speech).
    eval {hooks::run displayChatMessageHook $body} $args
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
	    set mejid [::Jabber::GetMyJid]
	    jlib::splitjid $mejid jid2 res
	}
	you {
	    jlib::splitjid $jid jid2 res
	}
    }

    switch -- $whom {
	me - you {
	    set username $jid2
	    regexp {^([^@]+)@} $jid2 match username
	    if {$clockFormat != ""} {
		set theTime [clock format $secs -format $clockFormat]
		set prefix "\[$theTime\] <$username>"
	    } else {
		set prefix <$username>
	    }    
	}
	presence {
	    if {$clockFormat != ""} {
		set theTime [clock format $secs -format $clockFormat]
		set prefix "\[$theTime\] "
	    } else {
		set prefix ""
	    }
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
	subject {
	    $wtext insert end "Subject: $state(subject)" sys
	}
	presence {
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
    global  this prefs wDlgs osprefs
    
    variable uid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::Chat::Build threadID=$threadID, args='$args'"

    # Initialize the state variable, an array, that keeps is the storage.
    
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
    
    set w $wDlgs(jchat)${uid}
    array set argsArr $args

    set state(w)          $w
    set state(threadid)   $threadID
    set state(active)     0
    set state(got1stMsg)  0
    set state(subject)    ""
    
    # Toplevel with class Chat.
    toplevel $w -class Chat
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
	::UI::MacUseMainMenu $w
    } else {

    }

    # -from is sometimes a 3-tier jid /resource included.
    # Try to keep any /resource part unless not possible.
    
    if {[info exists argsArr(-from)]} {
	set state(jid) [$jstate(jlib) getrecipientjid $argsArr(-from)]
    } else {
	set state(jid) ""
    }
    jlib::splitjid $state(jid) jid2 res
    
    if {[info exists argsArr(-subject)]} {
	set state(subject) $argsArr(-subject)
    }

    wm title $w "Chat ($state(jid))"
    wm protocol $w WM_DELETE_WINDOW  \
      [list [namespace current]::Close $token]

    # On non macs we need to explicitly bind certain commands.
    if {![string match "mac*" $this(platform)]} {
	bind $w <$osprefs(mod)-Key-w>  \
	  [list ::Jabber::Chat::Close $token]
    }
    
    # Toplevel menu for mac only. Crashes in menudefs; BowelsOfTheMemoryMgr
    if {[string match "mac*" $this(platform)]} {
	$w configure -menu [::Jabber::UI::GetRosterWmenu]
    }
    set fontSB [option get . fontSmallBold {}]

    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 4
    
    # Widget paths.
    set frmid    $w.frall.frmid
    set wtxt     $frmid.frtxt
    set wtext    $wtxt.text
    set wysc     $wtxt.ysc
    set wtxtsnd  $frmid.frtxtsnd        
    set wtextsnd $wtxtsnd.text
    set wyscsnd  $wtxtsnd.ysc
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btconn -text [::msgcat::mc Send] -width 8 -default active \
      -command [list [namespace current]::Send $token]]  \
      -side right -padx 5 -pady 2
    pack [button $frbot.btcancel -text [::msgcat::mc Close] -width 8   \
      -command [list [namespace current]::Close $token]]  \
      -side right -padx 5 -pady 2
    pack [::Jabber::UI::SmileyMenuButton $frbot.smile $wtextsnd]  \
      -side right -padx 5 -pady 2
    pack [checkbutton $frbot.active -text "  Active <Return>"   \
      -command [list [namespace current]::ActiveCmd $token] \
      -variable $token\(active)]  \
      -side left -padx 5 -pady 2
    pack $frbot -side bottom -fill x -padx 10 -pady 6
    
    # CCP etc.
    pack [frame $w.frall.fccp] -side top -fill x
    set wccp $w.frall.fccp.ccp
    pack [::UI::NewCutCopyPaste $wccp] -padx 10 -pady 2 -side left
    ::UI::CutCopyPasteConfigure $wccp cut -state disabled
    ::UI::CutCopyPasteConfigure $wccp copy -state disabled
    ::UI::CutCopyPasteConfigure $wccp paste -state disabled
    pack [frame $w.frall.fccp.div -bd 2 -relief raised -width 2] -fill y -side left
    pack [::UI::NewPrint $w.frall.fccp.pr [list [namespace current]::Print $token]] \
      -side left -padx 10
    button $w.frall.fccp.hist -text [msgcat::mc History]  \
      -command [list [namespace current]::BuildHistory $jid2] 
    pack [frame $w.frall.div2 -bd 2 -relief sunken -height 2] -fill x -side top
    pack $w.frall.fccp.hist -side right -padx 6
    
    # To and subject fields.
    set frtop [frame $w.frall.frtop -borderwidth 0]
    pack $frtop -side top -fill x   
    label $frtop.lto -text "[::msgcat::mc {To/from JID}]:" -font $fontSB \
      -anchor e
    entry $frtop.eto -textvariable $token\(jid)
    label $frtop.lsub -text "[::msgcat::mc Subject]:" -font $fontSB \
      -anchor e
    entry $frtop.esub -textvariable $token\(subject)
    grid $frtop.lto -column 0 -row 0 -sticky e -padx 6
    grid $frtop.eto -column 1 -row 0 -sticky ew -padx 6
    grid $frtop.lsub -column 0 -row 1 -sticky e -padx 6
    grid $frtop.esub -column 1 -row 1 -sticky ew -padx 6
    grid columnconfigure $frtop 1 -weight 1

    set state(wtojid) $frtop.eto

    # Text chat.
    pack [frame $frmid -height 250 -width 300 -relief sunken -bd 1 -class Pane] \
      -side top -fill both -expand 1 -padx 4 -pady 4
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
        
    set state(wtext)    $wtext
    set state(wtxt)     $wtxt
    set state(wtextsnd) $wtextsnd

    # We need the window title to reflect the receiving jid.
    trace variable $token\(jid) w  \
      [list [namespace current]::TraceJid $token]

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jchat)]]
    if {$nwin == 1} {
	::UI::SetWindowGeometry $w $wDlgs(jchat)
    }
    wm minsize $w 220 320
    wm maxsize $w 800 2000
    
    focus $w
    return $token
}

proc ::Jabber::Chat::ConfigureTextTags {w wtext} {
    variable chatOptions
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::Chat::ConfigureTextTags"
    
    set space 2
    set alltags {mepre metext youpre youtext syspre sys}
        
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
		    set value $boldChatFont
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
    lappend opts(metext)  -spacing3 $space -lmargin1 20 -lmargin2 20
    lappend opts(youtext) -spacing3 $space -lmargin1 20 -lmargin2 20
    lappend opts(sys) -spacing3 $space -lmargin1 20 -lmargin2 20
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
    variable $token
    upvar 0 $token state

    ::Jabber::Debug 2 "::Jabber::Chat::ActiveCmd: token=$token"
    
    set w $state(w)
    if {$state(active)} {
	bind $w <Return> [list [namespace current]::Send $token]
    } else {
	bind $w <Return> {}
    }
}

proc ::Jabber::Chat::Send {token} {
    global  prefs
    
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::Chat::Send "
    
    # Check that still connected to server.
    if {![::Jabber::IsConnected]} {
	tk_messageBox -type ok -icon error -title [::msgcat::mc {Not Connected}] \
	  -message [::msgcat::mc jamessnotconnected]
	return
    }
    
    # According to XMPP we should send to 3-tier jid if still online,
    # else to 2-tier.
    set jid [$jstate(jlib) getrecipientjid $state(jid)]
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
    set w        $state(w)
    set wtextsnd $state(wtextsnd)
    set threadID $state(threadid)

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
    
    set opts {}
    if {$state(subject) != ""} {
	lappend opts -subject $state(subject)
    }
    if {[catch {
	eval {$jstate(jlib) send_message $jid  \
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
	$state(wtojid) configure -state disabled
	set state(got1stMsg) 1
    }
    
    # Run this hook (speech).
    set opts [list -from $jid2]
    eval {hooks::run displayChatMessageHook $allText} $opts
}

proc ::Jabber::Chat::TraceJid {token name junk1 junk2} {
    variable $token
    upvar 0 $token state
    
    # Call by name.
    upvar $name locName    
    wm title $state(w) "Chat ($state(jid))"
}

proc ::Jabber::Chat::Print {token} {
    variable $token
    upvar 0 $token state
    
    ::UserActions::DoPrintText $state(wtext)
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
    ::Jabber::Chat::InsertMessage $token presence  \
      "$jid is: $mapShowTextToElem($show)\n$status"
    
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
	
	if {[string match $pattern $state($key)]} {
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
    
# Jabber::Chat::Close --
#
#

proc ::Jabber::Chat::Close {token} {
    global  wDlgs prefs
    
    variable $token
    upvar 0 $token state    
    
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
    upvar ::Jabber::jprefs jprefs
    
    set w $wDlgs(jchist)[incr uidhist]
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
	::UI::MacUseMainMenu $w
    } else {
	
    }
    wm title $w "Chat History: $jid"
    wm protocol $w WM_DELETE_WINDOW [list [namespace current]::CloseHistory]
    
    set wtxt  $w.frall.fr
    set wtext $wtxt.t
    set wysc  $wtxt.ysc
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1

    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btclose -text [::msgcat::mc Close] -width 8 \
      -command "destroy $w"] -side right -padx 5 -pady 5
    pack [button $frbot.btclear -text [::msgcat::mc Clear] -width 8  \
      -command [list [namespace current]::ClearHistory $jid $wtext]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btprint -text [::msgcat::mc Print] -width 8  \
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
	    $wtext insert end "Thread started $when\n" headtag
	    
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
		$wtext insert end "$cwhen <$cjid>" $ptag
		$wtext insert end "   " $ptxttag
		
		::Text::ParseAndInsert $wtext $body $ptxttag linktag
	    }
	}
    } else {
	$wtext insert end "No registered chat history for $jid\n" headtag
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

proc ::Jabber::Chat::CloseHistory { } {
    global  wDlgs
    
    ::UI::SaveWinPrefixGeom $wDlgs(jchist)
}

proc ::Jabber::Chat::PrintHistory {wtext} {
        
    ::UserActions::DoPrintText $wtext
}

#-------------------------------------------------------------------------------
