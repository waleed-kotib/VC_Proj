#  GroupChat.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the group chat GUI part.
#      
#  Copyright (c) 2001-2004  Mats Bengtsson
#  
# $Id: GroupChat.tcl,v 1.63 2004-06-06 15:42:49 matben Exp $

package require History

package provide GroupChat 1.0

# Provides dialog for old-style gc-1.0 groupchat but the rest should work for 
# both groupchat and conference protocols.


namespace eval ::Jabber::GroupChat:: {
    global  wDlgs

    # Add all event hooks.
    ::hooks::add quitAppHook             [list ::UI::SaveWinPrefixGeom $wDlgs(jgc)]
    ::hooks::add quitAppHook             ::Jabber::GroupChat::GetFirstPanePos
    ::hooks::add newGroupChatMessageHook ::Jabber::GroupChat::GotMsg
    ::hooks::add closeWindowHook         ::Jabber::GroupChat::CloseHook
    ::hooks::add loginHook               ::Jabber::GroupChat::LoginHook
    ::hooks::add logoutHook              ::Jabber::GroupChat::LogoutHook
    ::hooks::add presenceHook            ::Jabber::GroupChat::PresenceHook
    ::hooks::add groupchatEnterRoomHook  ::Jabber::GroupChat::EnterHook
    
    # Define all hooks for preference settings.
    ::hooks::add prefsInitHook           ::Jabber::GroupChat::InitPrefsHook
    ::hooks::add prefsBuildHook          ::Jabber::GroupChat::BuildPrefsHook
    ::hooks::add prefsSaveHook           ::Jabber::GroupChat::SavePrefsHook
    ::hooks::add prefsCancelHook         ::Jabber::GroupChat::CancelPrefsHook
    ::hooks::add prefsUserDefaultsHook   ::Jabber::GroupChat::UserDefaultsHook

    # Icons
    option add *GroupChat*sendImage            send             widgetDefault
    option add *GroupChat*sendDisImage         sendDis          widgetDefault
    option add *GroupChat*saveImage            save             widgetDefault
    option add *GroupChat*saveDisImage         saveDis          widgetDefault
    option add *GroupChat*historyImage         history          widgetDefault
    option add *GroupChat*historyDisImage      historyDis       widgetDefault
    option add *GroupChat*inviteImage          invite           widgetDefault
    option add *GroupChat*inviteDisImage       inviteDis        widgetDefault
    option add *GroupChat*infoImage            info             widgetDefault
    option add *GroupChat*infoDisImage         infoDis          widgetDefault
    option add *GroupChat*printImage           print            widgetDefault
    option add *GroupChat*printDisImage        printDis         widgetDefault

    option add *GroupChat*mePreForeground      red              widgetDefault
    option add *GroupChat*mePreBackground      ""               widgetDefault
    option add *GroupChat*mePreFont            ""               widgetDefault                                     
    option add *GroupChat*meTextForeground     ""               widgetDefault
    option add *GroupChat*meTextBackground     ""               widgetDefault
    option add *GroupChat*meTextFont           ""               widgetDefault                                     
    option add *GroupChat*theyPreForeground    blue             widgetDefault
    option add *GroupChat*theyPreBackground    ""               widgetDefault
    option add *GroupChat*theyPreFont          ""               widgetDefault
    option add *GroupChat*theyTextForeground   ""               widgetDefault
    option add *GroupChat*theyTextBackground   ""               widgetDefault
    option add *GroupChat*theyTextFont         ""               widgetDefault
    option add *GroupChat*sysPreForeground     #26b412          widgetDefault
    option add *GroupChat*sysTextForeground    #26b412          widgetDefault
    option add *GroupChat*histHeadForeground   ""               widgetDefault
    option add *GroupChat*histHeadBackground   gray60           widgetDefault
    option add *GroupChat*histHeadFont         ""               widgetDefault
    option add *GroupChat*clockFormat          "%H:%M"          widgetDefault

    option add *GroupChat*userForeground       ""               widgetDefault
    option add *GroupChat*userBackground       ""               widgetDefault
    option add *GroupChat*userFont             ""               widgetDefault

    # List of: {tagName optionName resourceName resourceClass}
    variable groupChatOptions {
	{mepre       -foreground          mePreForeground       Foreground}
	{mepre       -background          mePreBackground       Background}
	{mepre       -font                mePreFont             Font}
	{metext      -foreground          meTextForeground      Foreground}
	{metext      -background          meTextBackground      Background}
	{metext      -font                meTextFont            Font}
	{theypre     -foreground          theyPreForeground     Foreground}
	{theypre     -background          theyPreBackground     Background}
	{theypre     -font                theyPreFont           Font}
	{theytext    -foreground          theyTextForeground    Foreground}
	{theytext    -background          theyTextBackground    Background}
	{theytext    -font                theyTextFont          Font}
	{syspre      -foreground          sysPreForeground      Foreground}
	{systext     -foreground          sysTextForeground     Foreground}
	{histhead    -foreground          histHeadForeground    Foreground}
	{histhead    -background          histHeadBackground    Background}
	{histhead    -font                histHeadFont          Font}
    }
    
    # Local stuff
    variable enteruid 0
    variable dlguid 0

    # Running number for groupchat thread token.
    variable uid 0

    # Local preferences.
    variable cprefs
    set cprefs(lastActiveRet) 0

    variable popMenuDefs
    set popMenuDefs(groupchat,def) {
	mMessage       user      {::Jabber::NewMsg::Build -to $jid}
	mChat          user      {::Jabber::Chat::StartThread $jid}
	mSendFile      user      {::Jabber::OOB::BuildSet $jid}
	mWhiteboard    wb        {::Jabber::WB::NewWhiteboardTo $jid}
    }    
    
}

# Jabber::GroupChat::AllConference --
#
#       Returns 1 only if all services that provided groupchat also support
#       the 'jabber:iq:conference' protocol. This is implicitly obtained
#       by obtaining version number for the conference component. UGLY!!!

proc ::Jabber::GroupChat::AllConference { } {
    upvar ::Jabber::jstate jstate

    set anyNonConf 0
    foreach jid [$jstate(jlib) service getjidsfor "groupchat"] {
	if {[info exists jstate(conference,$jid)] &&  \
	  ($jstate(conference,$jid) == 0)} {
	    set anyNonConf 1
	    break
	}
    }
    if {$anyNonConf} {
	return 0
    } else {
	return 1
    }
}

# Jabber::GroupChat::HaveOrigConference --
#
#       Ad hoc method for finding out if possible to use the original
#       jabber:iq:conference method. Requires jabber:iq:browse

proc ::Jabber::GroupChat::HaveOrigConference {{roomjid ""}} {
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver

    set ans 0
    if {$roomjid == ""} {
	if {[::Jabber::Browse::HaveBrowseTree $jserver(this)] &&  \
	  [::Jabber::GroupChat::AllConference]} {
	    set ans 1
	}
    } else {
	
	# Require that conference service browsed and that we have the
	# original jabber:iq:conference
	if {[info exists jstate(browse)]} {
	    set conf [$jstate(browse) getparentjid $roomjid]
	    if {[$jstate(browse) isbrowsed $conf]} {
		if {[info exists jstate(conference,$conf)] && \
		  $jstate(conference,$conf)} {
		    set ans 1
		}
	    }
	}
    }
    return $ans
}

# Jabber::GroupChat::HaveMUC --
# 
#       Should perhaps be in jlib service part.

proc ::Jabber::GroupChat::HaveMUC {{roomjid ""}} {
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver

    set ans 0
    if {$roomjid == ""} {
	if {1} {
	    set allConfServ [$jstate(jlib) service getconferences]
	    foreach serv $allConfServ {
		if {[$jstate(jlib) service hasfeature $serv  \
		  "http://jabber.org/protocol/muc"]} {
		    set ans 1
		}
	    }
	}
	
	if {0} { 
	    # Require at least one service that supports muc.
	    # 
	    # PROBLEM: some clients browsed return muc xmlns!!!
	    if {[info exists jstate(browse)]} {
		set jids [$jstate(browse) getservicesforns  \
		  "http://jabber.org/protocol/muc"]
		if {[llength $jids] > 0} {
		    set ans 1
		}
	    }
	    if {[info exists jstate(disco)]} {
		set jids [$jstate(disco) getjidsforfeature  \
		  "http://jabber.org/protocol/muc"]
		if {[llength $jids] > 0} {
		    set ans 1
		}
	    }
	}
    } else {
	if {1} {
	    
	    # We must query the service, not the room, for browse to work.
	    if {[regexp {^[^@]+@(.+)$} $roomjid match service]} {
		if {[$jstate(jlib) service hasfeature $service  \
		  "http://jabber.org/protocol/muc"]} {
		    set ans 1
		}
	    }
	}
	
	if {0} {
	    if {[info exists jstate(browse)]} {
		set confserver [$jstate(browse) getparentjid $roomjid]
		if {[$jstate(browse) isbrowsed $confserver]} {
		    set ans [$jstate(browse) hasnamespace $confserver  \
		      "http://jabber.org/protocol/muc"]
		}
	    }
	    if {[info exists jstate(disco)]} {
		set confserver [$jstate(disco) parent $roomjid]
		if {[$jstate(disco) isdiscoed info $confserver]} {
		    set ans [$jstate(disco) hasfeature   \
		      "http://jabber.org/protocol/muc" $confserver]
		}
	    }
	}
    }
    ::Debug 4 "::Jabber::GroupChat::HaveMUC $ans"
    return $ans
}

# Jabber::GroupChat::EnterOrCreate --
#
#       Dispatch entering or creating a room to either 'groupchat' (gc-1.0), 
#       'conference', or 'muc' methods depending on preferences.
#       The 'conference' method requires jabber:iq:browse and 
#       jabber:iq:conference.
#       The 'muc' method uses either jabber:iq:browse or disco.
#       
# Arguments:
#       what        'enter' or 'create'
#       args        -server, -roomjid, -autoget
#       
# Results:
#       "cancel" or "enter".

proc ::Jabber::GroupChat::EnterOrCreate {what args} {
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    
    array set argsArr $args
    if {[info exists argsArr(-roomjid)]} {
	set roomjid $argsArr(-roomjid)
    } else {
	set roomjid ""
    }

    # Preferred groupchat protocol (gc-1.0|muc).
    # Use 'gc-1.0' as fallback.
    set gchatprotocol "gc-1.0"
    
    # Consistency checking.
    if {![regexp {(gc-1.0|muc)} $jprefs(prefgchatproto)]} {
    	set jprefs(prefgchatproto) muc
    }
    
    switch -- $jprefs(prefgchatproto) {
	gc-1.0 {
	    set gchatprotocol "gc-1.0"
	}
	muc {
	    if {[::Jabber::GroupChat::HaveMUC $roomjid]} {
		set gchatprotocol "muc"
	    } elseif {[::Jabber::GroupChat::HaveOrigConference $roomjid]} {
		set gchatprotocol "conference"
	    }
	}
    }
    ::Debug 2 "::Jabber::GroupChat::EnterOrCreate prefgchatproto=$jprefs(prefgchatproto) \
      gchatprotocol=$gchatprotocol, what=$what, args='$args'"
    
    switch -- $gchatprotocol {
	gc-1.0 {
	    set ans [eval {::Jabber::GroupChat::BuildEnter} $args]
	}
	conference {
	    if {$what == "enter"} {
		set ans [eval {::Jabber::Conference::BuildEnter} $args]
	    } elseif {$what == "create"} {
		set ans [eval {::Jabber::Conference::BuildCreate} $args]
	    }
	}
	muc {
	    if {$what == "enter"} {
		set ans [eval {::Jabber::MUC::BuildEnter} $args]
	    } elseif {$what == "create"} {
		set ans [eval {::Jabber::Conference::BuildCreate} $args]
	    }
	}
    }    
    
    return $ans
}

proc ::Jabber::GroupChat::EnterHook {roomjid protocol} {
    
    ::Debug 2 "::Jabber::GroupChat::EnterHook roomjid=$roomjid $protocol"
    
    ::Jabber::GroupChat::SetProtocol $roomjid $protocol
    
    # If we are using the 'conference' protocol we must browse
    # the room to get the participants.
    if {$protocol == "conference"} {
	::Jabber::Browse::Get $roomjid
    }
}

# Jabber::GroupChat::SetProtocol --
# 
#       Cache groupchat protocol in use for specific room.

proc ::Jabber::GroupChat::SetProtocol {roomjid inprotocol} {
    
    variable protocol

    ::Debug 2 "::Jabber::GroupChat::SetProtocol $roomjid $inprotocol"
    set roomjid [jlib::jidmap $roomjid]
    
    # We need a separate cache for this since the room may not yet exist.
    set protocol($roomjid) $inprotocol
    
    set token [::Jabber::GroupChat::GetTokenFrom roomjid $roomjid]
    if {$token == ""} {
	return
    }
    variable $token
    upvar 0 $token state
    
    if {$inprotocol == "muc"} {
	set wtray           $state(wtray)
	$wtray buttonconfigure invite -state normal
	$wtray buttonconfigure info   -state normal
	$state(wbtnick)   configure -state normal
    }
}

# Jabber::GroupChat::BuildEnter --
#
#       This is to provide support for the old-style 'groupchat 1.0' protocol
#       which shall be used when not server is being browsed.
#       
# Arguments:
#       args        -server, -roomjid, -autoget
#       
# Results:
#       "cancel" or "enter".
     
proc ::Jabber::GroupChat::BuildEnter {args} {
    global  this wDlgs

    variable enteruid
    variable dlguid
    upvar ::Jabber::jstate jstate

    set chatservers [$jstate(jlib) service getjidsfor "groupchat"]
    ::Debug 2 "::Jabber::GroupChat::BuildEnter args='$args'"
    ::Debug 2 "    service getjidsfor groupchat: '$chatservers'"
    
    if {[llength $chatservers] == 0} {
	tk_messageBox -icon error -message [::msgcat::mc jamessnogchat]
	return
    }

    # State variable to collect instance specific variables.
    set token [namespace current]::enter[incr enteruid]
    variable $token
    upvar 0 $token enter
    
    set w $wDlgs(jgcenter)[incr dlguid]
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
    wm title $w [::msgcat::mc {Enter/Create Room}]
    set enter(w) $w
    array set enter {
	finished    -1
	server      ""
	roomname    ""
	nickname    ""
    }
    array set argsArr $args
    
    set fontSB [option get . fontSmallBold {}]

    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 4
        
    set enter(server) [lindex $chatservers 0]
    set frmid $w.frall.mid
    pack [frame $frmid] -side top -fill both -expand 1
    set msg [::msgcat::mc jagchatmsg]
    message $frmid.msg -width 260 -text $msg
    label $frmid.lserv -text "[::msgcat::mc Servers]:" -anchor e

    set wcomboserver $frmid.eserv
    ::combobox::combobox $wcomboserver -width 18  \
      -textvariable $token\(server)
    eval {$frmid.eserv list insert end} $chatservers
    label $frmid.lroom -text "[::msgcat::mc Room]:" -anchor e
    entry $frmid.eroom -width 24    \
      -textvariable $token\(roomname) -validate key  \
      -validatecommand {::Jabber::ValidateUsernameStr %S}
    label $frmid.lnick -text "[::msgcat::mc {Nick name}]:" \
      -anchor e
    entry $frmid.enick -width 24    \
      -textvariable $token\(nickname) -validate key  \
      -validatecommand {::Jabber::ValidateResourceStr %S}
    grid $frmid.msg -column 0 -columnspan 2 -row 0 -sticky ew
    grid $frmid.lserv -column 0 -row 1 -sticky e
    grid $frmid.eserv -column 1 -row 1 -sticky ew 
    grid $frmid.lroom -column 0 -row 2 -sticky e
    grid $frmid.eroom -column 1 -row 2 -sticky ew
    grid $frmid.lnick -column 0 -row 3 -sticky e
    grid $frmid.enick -column 1 -row 3 -sticky ew
    
    if {[info exists argsArr(-roomjid)]} {
	regexp {^([^@]+)@([^/]+)} $argsArr(-roomjid) match enter(roomname) \
	  server
	$wcomboserver configure -state disabled
	$frmid.eroom configure -state disabled
    }
    if {[info exists argsArr(-server)]} {
	set server $argsArr(-server)
	$wcomboserver configure -state disabled
    }
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [::msgcat::mc Enter] -default active \
      -command [list [namespace current]::DoEnter $token]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel]   \
      -command [list [namespace current]::Cancel $token]]  \
      -side right -padx 5 -pady 5  
    pack $frbot -side bottom -fill x
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    bind $w <Return> [list $frbot.btok invoke]
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {focus $oldFocus}
    set finished $enter(finished)
    unset enter
    return [expr {($finished <= 0) ? "cancel" : "enter"}]
}

proc ::Jabber::GroupChat::Cancel {token} {
    variable $token
    upvar 0 $token enter

    set enter(finished) 0
    catch {destroy $enter(w)}
}

proc ::Jabber::GroupChat::DoEnter {token} {
    variable $token
    upvar 0 $token enter

    upvar ::Jabber::jstate jstate
    
    # Verify the fields first.
    if {($enter(server) == "") || ($enter(roomname) == "") ||  \
      ($enter(nickname) == "")} {
	tk_messageBox -title [::msgcat::mc Warning] -type ok -message \
	  [::msgcat::mc jamessgchatfields] -parent $enter(w)
	return
    }

    set roomjid [jlib::jidmap [jlib::joinjid $enter(roomname) $enter(server) ""]]
    ::Jabber::JlibCmd groupchat enter $roomjid $enter(nickname) \
      -command [namespace current]::EnterCallback

    set enter(finished) 1
    destroy $enter(w)
}

proc ::Jabber::GroupChat::EnterCallback {jlibName type args} {
    
    array set argsArr $args
    if {[string equal $type "error"]} {
	set msg "We got an error when entering room \"$argsArr(-from)\"."
	if {[info exists argsArr(-error)]} {
	    foreach {errcode errmsg} $argsArr(-error) break
	    append msg " The error code is $errcode: $errmsg"
	}
	tk_messageBox -title "Error Enter Room" -message $msg
	return
    }
    
    # Cache groupchat protocol type (muc|conference|gc-1.0).
    ::hooks::run groupchatEnterRoomHook $argsArr(-from) "gc-1.0"
}

# Jabber::GroupChat::GotMsg --
#
#       Just got a group chat message. Fill in message in existing dialog.
#       If no dialog, make a freash one.
#       
# Arguments:
#       body        the text message.
#       args        ?-key value? pairs
#       
# Results:
#       updates UI.

proc ::Jabber::GroupChat::GotMsg {body args} {
    global  prefs
    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::GroupChat::GotMsg args='$args'"
    
    array set argsArr $args
    
    # We must follow the roomjid...
    if {[info exists argsArr(-from)]} {
	set from $argsArr(-from)
    } else {
	return -code error "Missing -from attribute in group message!"
    }
    set from [jlib::jidmap $from]
    jlib::splitjid $from roomjid res
        
    # If we haven't a window for this roomjid, make one!
    set token [::Jabber::GroupChat::GetTokenFrom roomjid $roomjid]
    if {$token == ""} {
	set token [eval {::Jabber::GroupChat::Build $roomjid} $args]
    }
    variable $token
    upvar 0 $token state
    
    if {[info exists argsArr(-subject)]} {
	set state(subject) $argsArr(-subject)
    }
    if {[string length $body] > 0} {

	# And put message in window.
	eval {::Jabber::GroupChat::InsertMessage $token $from $body} $args
	set state(got1stmsg) 1
	
	# Run display hooks (speech).
	eval {::hooks::run displayGroupChatMessageHook $body} $args
    }
}

# Jabber::GroupChat::Build --
#
#       Builds the group chat dialog. Independently on protocol 'groupchat'
#       and 'conference'.
#
# Arguments:
#       roomjid     The roomname@server
#       args        ??
#       
# Results:
#       shows window, returns token.

proc ::Jabber::GroupChat::Build {roomjid args} {
    global  this prefs wDlgs
    
    variable protocol
    variable groupChatOptions
    variable uid
    variable cprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Jabber::GroupChat::Build roomjid=$roomjid, args='$args'"

    # Initialize the state variable, an array, that keeps is the storage.
    
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state

    # Make unique toplevel name.
    set w $wDlgs(jgc)[incr uid]
    array set argsArr $args

    set state(w)                $w
    set state(roomjid)          $roomjid
    set state(subject)          ""
    set state(status)           "available"
    set state(oldStatus)        "available"
    set state(got1stmsg)        0
    if {$jprefs(chatActiveRet)} {
	set state(active) 1
    } else {
	set state(active)       $cprefs(lastActiveRet)
    }
    
    # Toplevel of class GroupChat.
    ::UI::Toplevel $w -class GroupChat -usemacmainmenu 1 -macstyle documentProc
    
    # Not sure how old-style groupchat works here???
    #set roomName [$jstate(browse) getname $roomjid]
    set roomName [$jstate(jlib) service name $roomjid]
    
    if {[llength $roomName]} {
	set tittxt $roomName
    } else {
	set tittxt $roomjid
    }
    wm title $w "[::msgcat::mc Groupchat]: $tittxt"
    
    set fontS  [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]

    foreach {optName optClass} $groupChatOptions {
	set $optName [option get $w $optName $optClass]
    }
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 4
    
    # Widget paths.
    set wtray     $w.frall.tray
    set frmid     $w.frall.frmid
    set wtxt      $frmid.frtxt
    set wtext     $wtxt.0.text
    set wysc      $wtxt.0.ysc
    set wusers    $wtxt.users
    set wtxtsnd   $frmid.frtxtsnd
    set wtextsnd  $wtxtsnd.text
    set wyscsnd   $wtxtsnd.ysc
    
    # Shortcut button part.
    set iconSend        [::Theme::GetImage [option get $w sendImage {}]]
    set iconSendDis     [::Theme::GetImage [option get $w sendDisImage {}]]
    set iconSave        [::Theme::GetImage [option get $w saveImage {}]]
    set iconSaveDis     [::Theme::GetImage [option get $w saveDisImage {}]]
    set iconHistory     [::Theme::GetImage [option get $w historyImage {}]]
    set iconHistoryDis  [::Theme::GetImage [option get $w historyDisImage {}]]
    set iconInvite      [::Theme::GetImage [option get $w inviteImage {}]]
    set iconInviteDis   [::Theme::GetImage [option get $w inviteDisImage {}]]
    set iconInfo        [::Theme::GetImage [option get $w infoImage {}]]
    set iconInfoDis     [::Theme::GetImage [option get $w infoDisImage {}]]
    set iconPrint       [::Theme::GetImage [option get $w printImage {}]]
    set iconPrintDis    [::Theme::GetImage [option get $w printDisImage {}]]

    ::buttontray::buttontray $wtray 50
    pack $wtray -side top -fill x -padx 4 -pady 2

    $wtray newbutton send    Send    $iconSend    $iconSendDis    \
      [list [namespace current]::Send $token]
     $wtray newbutton save   Save    $iconSave    $iconSaveDis    \
       [list [namespace current]::Save $token]
    $wtray newbutton history History $iconHistory $iconHistoryDis \
      [list [namespace current]::BuildHistory $token]
    $wtray newbutton invite  Invite  $iconInvite  $iconInviteDis  \
      [list ::Jabber::MUC::Invite $roomjid]
    $wtray newbutton info    Info    $iconInfo    $iconInfoDis    \
      [list ::Jabber::MUC::BuildInfo $roomjid]
    $wtray newbutton print   Print   $iconPrint   $iconPrintDis   \
      [list [namespace current]::Print $token]
    
    ::hooks::run buildGroupChatButtonTrayHook $wtray $roomjid
    
    set shortBtWidth [expr [$wtray minwidth] + 8]

    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack $frbot -side bottom -fill x -padx 10 -pady 8
    pack [button $frbot.btok -text [::msgcat::mc Send]  \
      -default active -command [list [namespace current]::Send $token]] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Exit]  \
      -command [list [namespace current]::Exit $token]]  \
      -side right -padx 5  
    pack [::Emoticons::MenuButton $frbot.smile -text $wtextsnd]  \
      -side right -padx 6
    set wbtstatus $frbot.stat
    
    set state(wbstatus) $wbtstatus
    ::Jabber::GroupChat::BuildStatusMenuButton $token $wbtstatus
    pack $wbtstatus -side right -padx 6
    ::Jabber::GroupChat::ConfigStatusMenuButton $token $wbtstatus available

    pack [checkbutton $frbot.active -text " [::msgcat::mc {Active <Return>}]" \
      -command [list [namespace current]::ActiveCmd $token] \
      -variable $token\(active)]  \
      -side left -padx 5
            
    pack [frame $w.frall.div2 -bd 2 -relief sunken -height 2] -fill x -side top
    
    # Header fields.
    set   frtop [frame $w.frall.frtop -borderwidth 0]
    pack  $frtop -side top -fill x
    set wbtsubject $frtop.btp
    button $frtop.btp -text "[::msgcat::mc Topic]:" -font $fontS  \
      -command [list [namespace current]::SetTopic $token]
    entry $frtop.etp -textvariable $token\(subject) -state disabled
    set wbtnick $frtop.bni
    button $wbtnick -text "[::msgcat::mc {Nick name}]..."  \
      -font $fontS -command [list ::Jabber::MUC::SetNick $roomjid]
    
    grid $frtop.btp -column 0 -row 0 -sticky w -padx 6 -pady 1
    grid $frtop.etp -column 1 -row 0 -sticky ew -padx 4 -pady 1
    grid $frtop.bni -column 2 -row 0 -sticky ew -padx 6 -pady 1
    grid columnconfigure $frtop 1 -weight 1
    
    if {!( [info exists protocol($roomjid)] && ($protocol($roomjid) == "muc") )} {
	$wbtnick configure -state disabled
	$wtray buttonconfigure invite -state disabled
	$wtray buttonconfigure info   -state disabled
    }
    
    # Text chat and user list.
    pack [frame $frmid -height 250 -width 300 -relief sunken -bd 1 -class Pane] \
      -side top -fill both -expand 1 -padx 4 -pady 4
    frame $wtxt -height 200
    frame $wtxt.0
    text $wtext -height 12 -width 1 -font $fontS -state disabled  \
      -borderwidth 1 -relief sunken -yscrollcommand [list $wysc set] -wrap word \
      -cursor {}
    text $wusers -height 12 -width 12 -state disabled  \
      -borderwidth 1 -relief sunken  \
      -spacing1 1 -spacing3 1 -wrap none -cursor {}
    scrollbar $wysc -orient vertical -command [list $wtext yview]
    pack $wtext -side left -fill both -expand 1
    pack $wysc -side right -fill y -padx 2
    
    set imageVertical   \
      [::Theme::GetImage [option get $frmid imageVertical {}]]
    set imageHorizontal \
      [::Theme::GetImage [option get $frmid imageHorizontal {}]]
    set sashVBackground [option get $frmid sashVBackground {}]
    set sashHBackground [option get $frmid sashHBackground {}]

    set paneopts [list -orient horizontal -limit 0.0]
    if {[info exists prefs(paneGeom,groupchatDlgHori)]} {
	lappend paneopts -relative $prefs(paneGeom,groupchatDlgHori)
    } else {
	lappend paneopts -relative {0.8 0.2}
    }
    if {$sashVBackground != ""} {
	lappend paneopts -image "" -handlelook [list -background $sashVBackground]
    } elseif {$imageVertical != ""} {
	lappend paneopts -image $imageVertical
    }    
    eval {::pane::pane $wtxt.0 $wusers} $paneopts
    
    # The tags.
    ::Jabber::GroupChat::ConfigureTextTags $w $wtext
    
    # Text send.
    frame $wtxtsnd -height 100 -width 300
    text  $wtextsnd -height 4 -width 1 -font $fontS -wrap word \
      -borderwidth 1 -relief sunken -yscrollcommand [list $wyscsnd set]
    scrollbar $wyscsnd -orient vertical -command [list $wtextsnd yview]
    grid $wtextsnd -column 0 -row 0 -sticky news
    grid $wyscsnd -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxtsnd 0 -weight 1
    grid rowconfigure $wtxtsnd 0 -weight 1
    
    set paneopts [list -orient vertical -limit 0.0]
    if {[info exists prefs(paneGeom,groupchatDlgVert)]} {
	lappend paneopts -relative $prefs(paneGeom,groupchatDlgVert)
    } else {
	lappend paneopts -relative {0.8 0.2}
    }
    if {$sashHBackground != ""} {
	lappend paneopts -image "" -handlelook [list -background $sashHBackground]
    } elseif {$imageHorizontal != ""} {
	lappend paneopts -image $imageHorizontal
    }    
    eval {::pane::pane $wtxt $wtxtsnd} $paneopts
    
    set state(wtray)      $wtray
    set state(wbtnick)    $wbtnick
    set state(wbtsubject) $wbtsubject
    set state(wbtstatus)  $wbtstatus
    set state(wtext)      $wtext
    set state(wtextsnd)   $wtextsnd
    set state(wusers)     $wusers
    set state(wtxt.0)     $wtxt.0
    set state(wtxt)       $wtxt
    
    if {$state(active)} {
	::Jabber::GroupChat::ActiveCmd $token
    }
        
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jgc)]]
    if {$nwin == 1} {
	::UI::SetWindowGeometry $w $wDlgs(jgc)
    }
    wm minsize $w [expr {$shortBtWidth < 240} ? 240 : $shortBtWidth] 320
    wm maxsize $w 800 2000
    
    focus $w
    return $token
}

# Jabber::GroupChat::BuildStatusMenuButton --
# 
#       Status megawidget menubutton.
#       
# Arguments:
#       w       widgetPath

proc ::Jabber::GroupChat::BuildStatusMenuButton {token w} {
    variable $token
    upvar 0 $token state
    
    set wmenu $w.menu
    button $w -bd 2 -width 16 -height 16 -image  \
      [::Jabber::Roster::GetPresenceIconFromKey $state(status)]
    $w configure -state disabled
    menu $wmenu -tearoff 0
    ::Jabber::Roster::BuildGenPresenceMenu $wmenu -variable $token\(status) \
      -command [list [namespace current]::StatusCmd $token]
    return $w
}

proc ::Jabber::GroupChat::ConfigStatusMenuButton {token w type} {
    variable $token
    upvar 0 $token state
    
    $w configure -image  \
      [::Jabber::Roster::GetPresenceIconFromKey $state(status)]
    if {[string equal $type "unavailable"]} {
	$w configure -state disabled
	bind $w <Button-1> {}
    } else {
	$w configure -state normal
	bind $w <Button-1> [list [namespace current]::PostMenu $w.menu %X %Y]
    }
}

proc ::Jabber::GroupChat::PostMenu {w x y} {
    
    tk_popup $w [expr int($x)] [expr int($y)]
}

proc ::Jabber::GroupChat::StatusCmd {token} {
    variable $token
    upvar 0 $token state

    set status $state(status)
    ::Debug 2 "::Jabber::GroupChat::StatusCmd status=$state(status)"

    if {$status == "unavailable"} {
	set ans [::Jabber::GroupChat::Exit $token]
	if {$ans == "no"} {
	    set state(status) $state(oldStatus)
	}
    } else {
    
	# Send our status.
	::Jabber::SetStatus $status -to $state(roomjid)
	set state(oldStatus) $status
    }
    $state(wbstatus) configure -image  \
      [::Jabber::Roster::GetPresenceIconFromKey $status]
}

# Jabber::GroupChat::InsertMessage --
# 
#       Puts message in text groupchat window.

proc ::Jabber::GroupChat::InsertMessage {token from body args} {
    variable $token
    upvar 0 $token state
    
    set w       $state(w)
    set wtext   $state(wtext)
    set roomjid $state(roomjid)
    set clockFormat [option get $w clockFormat {}]
    array set argsArr $args
    
    # Old-style groupchat and browser compatibility layer.
    set nick [::Jabber::JlibCmd service nick $from]
    
    # This can be room name or nick name.
    foreach {meRoomJid mynick}  \
      [::Jabber::JlibCmd service hashandnick $roomjid] break
    if {[string equal $meRoomJid $from]} {
	set whom me
    } elseif {[string equal $roomjid $from]} {
	set whom sys
    } else {
	set whom they
    }    
    set tm ""
    if {[info exists argsArr(-x)]} {
	set tm [::Jabber::GetAnyDelayElem $argsArr(-x)]
	if {$tm != ""} {
	    set tm [clock scan $tm -gmt 1]
	}
    }
    if {$tm == ""} {
	set tm [clock seconds]
    }

    set prefix ""
    if {$clockFormat != ""} {
	set theTime [clock format $tm -format $clockFormat]
	set prefix "\[$theTime\] "
    }        
    append prefix "<$nick>"
    
    $wtext configure -state normal
    $wtext insert end $prefix ${whom}pre
    ::Jabber::ParseAndInsertText $wtext "  $body" ${whom}text urltag	
    
    $wtext configure -state disabled
    $wtext see end

    # History.
    set dateISO [clock format $tm -format "%Y%m%dT%H:%M:%S"]
    ::History::PutToFile $roomjid [list $nick $dateISO $body $whom]
}

proc ::Jabber::GroupChat::SetState {token theState} {
    variable $token
    upvar 0 $token state

    $state(wtray) buttonconfigure send -state $theState
    $state(wbtsubject) configure -state $theState
}

proc ::Jabber::GroupChat::CloseHook {wclose} {
    global  wDlgs
    
    set result ""
    if {[string match $wDlgs(jgc)* $wclose]} {
	set token [::Jabber::GroupChat::GetTokenFrom w $wclose]
	if {$token != ""} {
	    set w $wclose
	    set ans [::Jabber::GroupChat::Exit $token]
	    if {$ans == "no"} {
		set result stop
	    }
	}
    }  
    return $result
}

proc ::Jabber::GroupChat::ConfigureTextTags {w wtext} {
    variable groupChatOptions
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Jabber::GroupChat::ConfigureTextTags"
    
    set space 2
    set alltags {mepre metext theypre theytext syspre systext histhead}
	
    if {[string length $jprefs(chatFont)]} {
	set chatFont $jprefs(chatFont)
	set boldChatFont [lreplace $jprefs(chatFont) 2 2 bold]
    }
    foreach tag $alltags {
	set opts($tag) [list -spacing1 $space]
    }
    foreach spec $groupChatOptions {
	foreach {tag optName resName resClass} $spec break
	set value [option get $w $resName $resClass]
	if {[string length $jprefs(chatFont)] && [string equal $optName "-font"]} {
	    set value $chatFont
	}
	if {[string length $value]} {
	    lappend opts($tag) $optName $value
	}   
    }
    lappend opts(metext)   -spacing3 $space -lmargin1 20 -lmargin2 20
    lappend opts(theytext) -spacing3 $space -lmargin1 20 -lmargin2 20
    lappend opts(systext)  -spacing3 $space -lmargin1 20 -lmargin2 20
    lappend opts(histhead) -spacing1 4 -spacing3 4 -lmargin1 20 -lmargin2 20
    foreach tag $alltags {
	eval {$wtext tag configure $tag} $opts($tag)
    }
    
    ::Text::ConfigureLinkTagForTextWidget $wtext urltag activeurltag
}

proc ::Jabber::GroupChat::SetTopic {token} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    set topic   $state(subject)
    set roomjid $state(roomjid)
    set ans [::UI::MegaDlgMsgAndEntry  \
      [::msgcat::mc {Set New Topic}]  \
      [::msgcat::mc jasettopic]  \
      "[::msgcat::mc {New Topic}]:"  \
      topic [::msgcat::mc Cancel] [::msgcat::mc OK]]

    if {($ans == "ok") && ($topic != "")} {
	if {[catch {
	    ::Jabber::JlibCmd send_message $roomjid -type groupchat \
	      -subject $topic
	} err]} {
	    tk_messageBox -type ok -icon error -title "Network Error" \
	      -message "Network error ocurred: $err"
	    return
	}
    }
    return $ans
}

proc ::Jabber::GroupChat::Send {token} {
    global  prefs
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    # Check that still connected to server.
    if {![::Jabber::IsConnected]} {
	tk_messageBox -type ok -icon error -title [::msgcat::mc {Not Connected}] \
	  -message [::msgcat::mc jamessnotconnected]
	return
    }
    set wtextsnd $state(wtextsnd)
    set roomjid  $state(roomjid)

    # Get text to send. Strip off any ending newlines from Return.
    # There might by smiley icons in the text widget. Parse them to text.
    set allText [::Text::TransformToPureText $wtextsnd]
    set allText [string trimright $allText "\n"]
    if {$allText != ""} {	
	if {[catch {
	    ::Jabber::JlibCmd send_message $roomjid -type groupchat \
	      -body $allText
	} err]} {
	    tk_messageBox -type ok -icon error -title "Network Error" \
	      -message "Network error ocurred: $err"
	    return
	}
    }
    
    # Clear send.
    $wtextsnd delete 1.0 end
    set state(hot1stmsg) 1
}

proc ::Jabber::GroupChat::ReturnCmd {token} {

    ::Jabber::GroupChat::Send $token
    
    # Stop the actual return to be inserted.
    return -code break
}

proc ::Jabber::GroupChat::ActiveCmd {token} {
    variable cprefs
    variable $token
    upvar 0 $token state

    ::Debug 2 "::Jabber::GroupChat::ActiveCmd token=$token"
    
    set wtextsnd $state(wtextsnd)
    if {$state(active)} {
	bind $wtextsnd <Return> [list [namespace current]::ReturnCmd $token]
    } else {
	bind $wtextsnd <Return> {}
    }
    
    # Remember last setting.
    set cprefs(lastActiveRet) $state(active)
}

# Jabber::GroupChat::GetTokenFrom --
# 
#       Try to get the token state array from any stored key.
#       
# Arguments:
#       key         w, jid, roomjid etc...
#       pattern     glob matching
#       
# Results:
#       token or empty if not found.

proc ::Jabber::GroupChat::GetTokenFrom {key pattern} {
    
    # Search all tokens for this key into state array.
    foreach token [::Jabber::GroupChat::GetTokenList] {
	variable $token
	upvar 0 $token state
	
	if {[info exists state($key)] && [string match $pattern $state($key)]} {
	    return $token
	}
    }
    return ""
}

proc ::Jabber::GroupChat::GetTokenList { } {
    
    set ns [namespace current]
    return [concat  \
      [info vars ${ns}::\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]\[0-9\]\[0-9\]\[0-9\]]]
}

# Jabber::GroupChat::Presence --
#
#       Sets the presence of the jid in our UI.
#
# Arguments:
#       jid         'user@server' without resource
#       presence    "available", "unavailable", or "unsubscribed"
#       args        list of '-key value' pairs where '-key' can be
#                   -resource, -from, -type, -show...
#       
# Results:
#       groupchat member list updated.

proc ::Jabber::GroupChat::PresenceHook {jid presence args} {
    
    upvar ::Jabber::jstate jstate
    
    if {[$jstate(jlib) service isroom $jid]} {
	::Debug 2 "::Jabber::GroupChat::PresenceHook jid=$jid, presence=$presence, args='$args'"
	
	array set attrArr $args
	
	# Since there should not be any /resource.
	set roomjid $jid
	set jid3 ${jid}/$attrArr(-resource)
	if {[string equal $presence "available"]} {
	    eval {::Jabber::GroupChat::SetUser $roomjid $jid3 $presence} $args
	} elseif {[string equal $presence "unavailable"]} {
	    ::Jabber::GroupChat::RemoveUser $roomjid $jid3
	}
	
	# When kicked etc. from a MUC room...
	# 
	# 
	#  <x xmlns='http://jabber.org/protocol/muc#user'>
	#    <item affiliation='none' role='none'>
	#      <actor jid='fluellen@shakespeare.lit'/>
	#      <reason>Avaunt, you cullion!</reason>
	#    </item>
	#    <status code='307'/>
	#  </x>
	
	if {[info exists attrArr(-x)]} {
	    foreach c $attrArr(-x) {
		set xmlns [wrapper::getattribute $c xmlns]
		
		switch -- $xmlns {
		    "http://jabber.org/protocol/muc#user" {
			# Seems hard to figure out anything here...		    
		    }
		}
	    }
	}
    }
}

# Jabber::GroupChat::BrowseUser --
#
#       This is a <user> element. Gets called for each <user> element
#       in the jabber:iq:browse set or result iq element.
#       Only called if have conference/browse stuff for this service.

proc ::Jabber::GroupChat::BrowseUser {userXmlList} {
    
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::GroupChat::BrowseUser userXmlList='$userXmlList'"

    array set attrArr [lindex $userXmlList 1]
    
    # Direct it to the correct room. 
    set jid $attrArr(jid)
    set parentList [$jstate(browse) getparents $jid]
    set parent [lindex $parentList end]
    
    # Do something only if joined that room.
    if {[$jstate(jlib) service isroom $parent] &&  \
      ([lsearch [$jstate(jlib) conference allroomsin] $parent] >= 0)} {
	if {[info exists attrArr(type)] && [string equal $attrArr(type) "remove"]} {
	    ::Jabber::GroupChat::RemoveUser $parent $jid
	} else {
	    ::Jabber::GroupChat::SetUser $parent $jid {}
	}
    }
}

# Jabber::GroupChat::SetUser --
#
#       Adds or updates a user item in the group chat dialog.
#       
# Arguments:
#       roomjid     the room's jid
#       jid3     $roomjid/hashornick
#       presence    "available", "unavailable", or "unsubscribed"
#       args        list of '-key value' pairs where '-key' can be
#                   -resource, -from, -type, -show...
#       
# Results:
#       updated UI.

proc ::Jabber::GroupChat::SetUser {roomjid jid3 presence args} {
    global  this

    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Jabber::GroupChat::SetUser roomjid=$roomjid,\
      jid3=$jid3 presence=$presence"

    array set attrArr $args
    set roomjid [jlib::jidmap $roomjid]
    set jid3    [jlib::jidmap $jid3]

    # If we haven't a window for this thread, make one!
    set token [::Jabber::GroupChat::GetTokenFrom roomjid $roomjid]
    if {$token == ""} {
	set token [eval {::Jabber::GroupChat::Build $roomjid} $args]
    }       
    variable $token
    upvar 0 $token state
    
    # Get the hex string to use as tag. 
    # In old-style groupchat this is the nick name which should be unique
    # within this room aswell.
    jlib::splitjid $jid3 jid2 resource
    
    # If we got a browse push with a <user>, asume is available.
    if {[string length $presence] == 0} {
	set presence available
    }
    
    # Any show attribute?
    set showStatus $presence
    if {[info exists attrArr(-show)] && [string length $attrArr(-show)]} {
	set showStatus $attrArr(-show)
    } elseif {[info exists attrArr(-subscription)] &&   \
      [string equal $attrArr(-subscription) "none"]} {
	set showStatus "subnone"
    }
    
    # Remove any "old" line first. Image takes one character's space.
    set wusers $state(wusers)
    
    # Old-style groupchat and browser compatibility layer.
    set nick [::Jabber::JlibCmd service nick $jid3]
    set icon [eval {::Jabber::Roster::GetPresenceIcon $jid3 $presence} $args]
    $wusers configure -state normal
    set insertInd end
    set begin end
    set range [$wusers tag ranges $resource]
    if {[llength $range]} {
	
	# Remove complete line including image.
	set insertInd [lindex $range 0]
	set begin "$insertInd linestart"
	$wusers delete "$insertInd linestart" "$insertInd lineend +1 char"
    }    
    
    # Icon that is popup sensitive.
    $wusers image create $begin -image $icon -align bottom
    $wusers tag add $resource "$begin linestart" "$begin lineend"

    # Use hex string, nickname (resource) as tag.
    $wusers insert "$begin +1 char" " $nick\n" $resource
    $wusers configure -state disabled
    
    # For popping up menu.
    if {[string match "mac*" $this(platform)]} {
	$wusers tag bind $resource <Button-1>  \
	  [list [namespace current]::PopupTimer $token $jid3 %x %y]
	$wusers tag bind $resource <ButtonRelease-1>   \
	  [list [namespace current]::PopupTimerCancel $token]
	$wusers tag bind $resource <Control-Button-1>  \
	  [list [namespace current]::Popup $token $jid3 %x %y]
    } else {
	$wusers tag bind $resource <Button-3>  \
	  [list [namespace current]::Popup $wusers $jid3 %x %y]
    }
    
    # Noise.
    ::Sounds::PlayWhenIdle online
}
    
proc ::Jabber::GroupChat::RegisterPopupEntry {menuSpec} {
    variable popMenuDefs
    
    set popMenuDefs(groupchat,def) [concat $popMenuDefs(groupchat,def) $menuSpec]
}

proc ::Jabber::GroupChat::PopupTimer {token jid3 x y} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Jabber::GroupChat::PopupTimer jid3=$jid3"

    # Set timer for this callback.
    if {[info exists state(afterid)]} {
	catch {after cancel $state(afterid)}
    }
    set w $state(wusers)
    set state(afterid) [after 1000  \
      [list [namespace current]::Popup $w $jid3 $x $y]]
}

proc ::Jabber::GroupChat::PopupTimerCancel {token} {
    variable $token
    upvar 0 $token state

    catch {after cancel $state(afterid)}
}

# Jabber::GroupChat::Popup --
#
#       Handle popup menu in groupchat dialog.
#       
# Arguments:
#       w           widget that issued the command: tree or text
#       v           for the tree widget it is the item path, 
#                   for text the jidhash.
#       
# Results:
#       popup menu displayed

proc ::Jabber::GroupChat::Popup {w v x y} {
    global  wDlgs this
    
    variable popMenuDefs
    upvar ::Jabber::privatexmlns privatexmlns
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::GroupChat::Popup w=$w, v='$v', x=$x, y=$y"
    
    # The last element of $v is either a jid, (a namespace,) 
    # a header in roster, a group, or an agents xml tag.
    # The variables name 'jid' is a misnomer.
    # Find also type of thing clicked, 'typeClicked'.
    
    set typeClicked ""
    
    set jid $v
    set jid3 $jid
    if {[regexp {^[^@]+@[^@]+(/.*)?$} $jid match res]} {
	set typeClicked user
    }
    if {[string length $jid] == 0} {
	set typeClicked ""	
    }
    set X [expr [winfo rootx $w] + $x]
    set Y [expr [winfo rooty $w] + $y]
    
    ::Debug 2 "    jid=$jid, typeClicked=$typeClicked"
    
    # Mads Linden's workaround for menu post problem on mac:
    # all in menubutton commands i add "after 40 the_command"
    # this way i can never have to posting error.
    # it is important after the tk_popup f.ex to
    #
    # destroy .mb
    # update
    #
    # this way the .mb is destroyd before the next window comes up, thats how I
    # got around this.
    
    # Make the appropriate menu.
    set m $jstate(wpopup,groupchat)
    set i 0
    catch {destroy $m}
    menu $m -tearoff 0
    
    foreach {item type cmd} $popMenuDefs(groupchat,def) {
	if {[string index $cmd 0] == "@"} {
	    set mt [menu ${m}.sub${i} -tearoff 0]
	    set locname [::msgcat::mc $item]
	    $m add cascade -label $locname -menu $mt -state disabled
	    eval [string range $cmd 1 end] $mt
	    incr i
	} elseif {[string equal $item "separator"]} {
	    $m add separator
	    continue
	} else {
	    
	    # Substitute the jid arguments.
	    set cmd [subst -nocommands $cmd]
	    set locname [::msgcat::mc $item]
	    $m add command -label $locname -command "after 40 $cmd"  \
	      -state disabled
	}
	
	# If a menu should be enabled even if not connected do it here.
	
	if {![::Jabber::IsConnected]} {
	    continue
	}
	if {[string equal $type "any"]} {
	    $m entryconfigure $locname -state normal
	    continue
	}
	
	# State of menu entry. We use the 'type' and 'typeClicked' to sort
	# out which capabilities to offer for the clicked item.
	set state disabled
	
	# We skip whiteboarding here since does not know if Coccinella.
	if {($type == "user") && ($typeClicked == "user")} {
	    set state normal
	}
	if {[string equal $state "normal"]} {
	    $m entryconfigure $locname -state normal
	}
    }   
    
    # This one is needed on the mac so the menu is built before it is posted.
    update idletasks
    
    # Post popup menu.
    tk_popup $m [expr int($X) - 10] [expr int($Y) - 10]   
    
    # Mac bug... (else can't post menu while already posted if toplevel...)
    if {[string equal "macintosh" $this(platform)]} {
	catch {destroy $m}
	update
    }
}

proc ::Jabber::GroupChat::RemoveUser {roomjid jid3} {

    set roomjid [jlib::jidmap $roomjid]
    set token [::Jabber::GroupChat::GetTokenFrom roomjid $roomjid]
    if {$token == ""} {
	return
    }
    variable $token
    upvar 0 $token state
    
    # Get the hex string to use as tag.
    jlib::splitjid $jid3 jid2 resource
    set wusers $state(wusers)
    $wusers configure -state normal
    set range [$wusers tag ranges $resource]
    if {[llength $range]} {
	set insertInd [lindex $range 0]
	$wusers delete "$insertInd linestart" "$insertInd lineend +1 char"
    }
    $wusers configure -state disabled
    
    # Noise.
    ::Sounds::PlayWhenIdle offline
}

proc ::Jabber::GroupChat::BuildHistory {token} {
    variable $token
    upvar 0 $token state

    
    ::History::BuildHistory $state(roomjid) -class GroupChat  \
      -tagscommand ::Jabber::GroupChat::ConfigureTextTags
}

proc ::Jabber::GroupChat::Save {token} {
    global  this
    variable $token
    upvar 0 $token state
    
    set wtext   $state(wtext)
    set roomjid $state(roomjid)
    
    set ans [tk_getSaveFile -title [::msgcat::mc Save] \
      -initialfile "Groupchat ${roomjid}.txt"]
    
    if {[string length $ans]} {
	set allText [::Text::TransformToPureText $wtext]
	foreach {meRoomJid mynick}  \
	  [::Jabber::JlibCmd service hashandnick $roomjid] break
	set fd [open $ans w]
	puts $fd "Groupchat in:\t$roomjid"
	puts $fd "Subject:     \t$state(subject)"
	puts $fd "My nick:     \t$mynick"
	puts $fd "\n"
	puts $fd $allText	
	close $fd
	if {[string equal $this(platform) "macintosh"]} {
	    file attributes $ans -type TEXT -creator ttxt
	}
    }
}

proc ::Jabber::GroupChat::Print {token} {
    variable $token
    upvar 0 $token state
    
    ::UserActions::DoPrintText $state(wtext) 
}

proc ::Jabber::GroupChat::ExitRoom {roomjid} {

    set roomjid [jlib::jidmap $roomjid]
    set token [::Jabber::GroupChat::GetTokenFrom roomjid $roomjid]
    if {$token != ""} {
	::Jabber::GroupChat::Exit $token
    }
}

# Jabber::GroupChat::Exit --
#
#       Ask if wants to exit room. If then calls GroupChat::Close to do it.
#       
# Arguments:
#       roomjid
#       
# Results:
#       yes/no if actually exited or not.

proc ::Jabber::GroupChat::Exit {token} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate

    set roomjid $state(roomjid)
    
    if {[info exists state(w)] && [winfo exists $state(w)]} {
	set opts [list -parent $state(w)]
    } else {
	set opts ""
    }
    
    if {[::Jabber::IsConnected]} {
	set ans [eval {tk_messageBox -icon warning -type yesno  \
	  -message [::msgcat::mc jamesswarnexitroom $roomjid]} $opts]
	if {$ans == "yes"} {
	    ::Jabber::GroupChat::Close $token
	    ::Jabber::JlibCmd service exitroom $roomjid
	    ::hooks::run groupchatExitRoomHook $roomjid
	}
    } else {
	set ans "yes"
	::Jabber::GroupChat::Close $token
    }
    return $ans
}

# Jabber::GroupChat::Close --
#
#       Handles the closing of a groupchat. Both text and whiteboard dialogs.

proc ::Jabber::GroupChat::Close {token} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    
    set roomjid $state(roomjid)

    if {[info exists state(w)] && [winfo exists $state(w)]} {
	::UI::SaveWinGeom $wDlgs(jgc) $state(w)
    	::UI::SavePanePos groupchatDlgVert $state(wtxt)
    	::UI::SavePanePos groupchatDlgHori $state(wtxt.0) vertical
	
    	# after idle seems to be needed to avoid crashing the mac :-(
    	# trace variable ???
    	#after idle destroy $state(w)
	destroy $state(w)
	
	# Array cleanup?
	unset state
    }
    
    # Make sure any associated whiteboard is closed as well.
    ::hooks::run groupchatExitRoomHook $roomjid
}

# Jabber::GroupChat::LogoutHook --
#
#       Sets logged out status on all groupchats, that is, disable all buttons.

proc ::Jabber::GroupChat::LogoutHook { } {    
    upvar ::Jabber::jstate jstate

    set tokenList [::Jabber::GroupChat::GetTokenList]
    foreach token $tokenList {
	variable $token
	upvar 0 $token state

	::Jabber::GroupChat::SetState $token disabled
	::hooks::run groupchatExitRoomHook $state(roomjid)
    }
}

proc ::Jabber::GroupChat::LoginHook { } {    
    upvar ::Jabber::jstate jstate

    set tokenList [::Jabber::GroupChat::GetTokenList]
    foreach token $tokenList {
	variable $token
	upvar 0 $token state

	::Jabber::GroupChat::SetState $token normal
    }
}

proc ::Jabber::GroupChat::GetFirstPanePos { } {
    global  wDlgs
    
    set win [::UI::GetFirstPrefixedToplevel $wDlgs(jgc)]
    set token [::Jabber::GroupChat::GetTokenFrom w $win]
    if {$token != ""} {
	variable $token
	upvar 0 $token state

	::UI::SavePanePos groupchatDlgVert $state(wtxt)
	::UI::SavePanePos groupchatDlgHori $state(wtxt.0) vertical
    }
}

# Prefs page ...................................................................

proc ::Jabber::GroupChat::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    
    # Defaults...    
    # Preferred groupchat protocol (gc-1.0|muc).
    # 'muc' uses 'conference' as fallback.
    set jprefs(prefgchatproto) "muc"
	
    ::PreferencesUtils::Add [list  \
      [list ::Jabber::jprefs(prefgchatproto)   jprefs_prefgchatproto    $jprefs(prefgchatproto)]  \
      ]   
}

proc ::Jabber::GroupChat::BuildPrefsHook {wtree nbframe} {
    
    $wtree newitem {Jabber Conference} -text [::msgcat::mc Conference]
    
    # Conference page ------------------------------------------------------
    set wpage [$nbframe page {Conference}]
    ::Jabber::GroupChat::BuildPageConf $wpage
}

proc ::Jabber::GroupChat::BuildPageConf {page} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs

    set ypad [option get [winfo toplevel $page] yPad {}]
    
    set tmpJPrefs(prefgchatproto) $jprefs(prefgchatproto)
    
    # Conference (groupchat) stuff.
    set labfr $page.fr
    labelframe $labfr -text [::msgcat::mc {Preferred Protocol}]
    pack $labfr -side top -anchor w -padx 8 -pady 4
    set pbl [frame $labfr.frin]
    pack $pbl -padx 10 -pady 6 -side left
    
    foreach  \
      val {gc-1.0                     muc}   \
      txt {{Groupchat-1.0 (fallback)} prefmucconf} {
	set wrad ${pbl}.[string map {. ""} $val]
	radiobutton $wrad -text [::msgcat::mc $txt] -value $val  \
	  -variable [namespace current]::tmpJPrefs(prefgchatproto)	      
	grid $wrad -sticky w -pady $ypad
    }
}

proc ::Jabber::GroupChat::SavePrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    array set jprefs [array get tmpJPrefs]
    unset tmpJPrefs
}

proc ::Jabber::GroupChat::CancelPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	if {![string equal $jprefs($key) $tmpJPrefs($key)]} {
	    ::Preferences::HasChanged
	    break
	}
    }
}

proc ::Jabber::GroupChat::UserDefaultsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	set tmpJPrefs($key) $jprefs($key)
    }
}

#-------------------------------------------------------------------------------
