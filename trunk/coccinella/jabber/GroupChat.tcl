#  GroupChat.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the group chat GUI part.
#      
#  Copyright (c) 2001-2005  Mats Bengtsson
#  
# $Id: GroupChat.tcl,v 1.103 2005-02-22 13:58:44 matben Exp $

package require History

package provide GroupChat 1.0

# Provides dialog for old-style gc-1.0 groupchat but the rest should work for 
# both groupchat and conference protocols.


namespace eval ::GroupChat:: {

    # Add all event hooks.
    ::hooks::register quitAppHook             ::GroupChat::QuitAppHook
    ::hooks::register quitAppHook             ::GroupChat::GetFirstPanePos
    ::hooks::register newGroupChatMessageHook ::GroupChat::GotMsg
    ::hooks::register closeWindowHook         ::GroupChat::CloseHook
    ::hooks::register loginHook               ::GroupChat::LoginHook
    ::hooks::register logoutHook              ::GroupChat::LogoutHook
    ::hooks::register presenceHook            ::GroupChat::PresenceHook
    ::hooks::register groupchatEnterRoomHook  ::GroupChat::EnterHook
    
    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook           ::GroupChat::InitPrefsHook
    ::hooks::register prefsBuildHook          ::GroupChat::BuildPrefsHook
    ::hooks::register prefsSaveHook           ::GroupChat::SavePrefsHook
    ::hooks::register prefsCancelHook         ::GroupChat::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook   ::GroupChat::UserDefaultsHook

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
    option add *GroupChat*clockFormatNotToday  "%b %d %H:%M"    widgetDefault

    option add *GroupChat*userForeground       ""               widgetDefault
    option add *GroupChat*userBackground       ""               widgetDefault
    option add *GroupChat*userFont             ""               widgetDefault
    
    option add *GroupChat*Tree.background      white            widgetDefault

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
    
    # Standard wigets.
    option add *GroupChat.frall.borderWidth          1               50
    option add *GroupChat.frall.relief               raised          50
    option add *GroupChat*top.padX                   0               50
    option add *GroupChat*top.padY                   0               50
    option add *GroupChat*divt.borderWidth           2               50
    option add *GroupChat*divt.height                2               50
    option add *GroupChat*divt.relief                sunken          50

    option add *GroupChat*bot.padX                   10              50
    option add *GroupChat*bot.padY                   8               50
    
    
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
	mMessage       user      {::NewMsg::Build -to $jid}
	mChat          user      {::Chat::StartThread $jid}
	mSendFile      user      {::OOB::BuildSet $jid}
	mWhiteboard    wb        {::Jabber::WB::NewWhiteboardTo $jid}
    }    
    
    variable userRoleToStr
    set userRoleToStr(moderator)   [mc Moderators]
    set userRoleToStr(none)        [mc None]
    set userRoleToStr(participant) [mc Participants]
    set userRoleToStr(visitor)     [mc Visitors]
}

proc ::GroupChat::QuitAppHook { } {
    global  wDlgs
    
    ::UI::SaveWinPrefixGeom $wDlgs(jgc)
}

# GroupChat::AllConference --
#
#       Returns 1 only if all services that provided groupchat also support
#       the 'jabber:iq:conference' protocol. This is implicitly obtained
#       by obtaining version number for the conference component. UGLY!!!

proc ::GroupChat::AllConference { } {
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

# GroupChat::HaveOrigConference --
#
#       Ad hoc method for finding out if possible to use the original
#       jabber:iq:conference method. Requires jabber:iq:browse

proc ::GroupChat::HaveOrigConference {{service ""}} {
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver

    set ans 0
    if {$service == ""} {
	if {[::Browse::HaveBrowseTree $jserver(this)] && [AllConference]} {
	    set ans 1
	}
    } else {
	
	# Require that conference service browsed and that we have the
	# original jabber:iq:conference
	if {[info exists jstate(browse)]} {
	    if {[$jstate(browse) isbrowsed $service]} {
		if {[info exists jstate(conference,$service)] && \
		  $jstate(conference,$service)} {
		    set ans 1
		}
	    }
	}
    }
    return $ans
}

# GroupChat::HaveMUC --
# 
#       Should perhaps be in jlib service part.
#       
# Arguments:
#       jid         is either a service or a room jid

proc ::GroupChat::HaveMUC {{jid ""}} {
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::xmppxmlns xmppxmlns

    set ans 0
    if {$jid == ""} {
	set allConfServ [$jstate(jlib) service getconferences]
	foreach serv $allConfServ {
	    if {[$jstate(jlib) service hasfeature $serv $xmppxmlns(muc)]} {
		set ans 1
	    }
	}
    } else {
	
	# We must query the service, not the room, for browse to work.
	jlib::splitjidex $jid node service res
	if {$service != ""} {
	    if {[$jstate(jlib) service hasfeature $service $xmppxmlns(muc)]} {
		set ans 1
	    }
	}
    }
    ::Debug 4 "::GroupChat::HaveMUC = $ans, jid=$jid"
    
    return $ans
}

# GroupChat::EnterOrCreate --
#
#       Dispatch entering or creating a room to either 'groupchat' (gc-1.0), 
#       'conference', or 'muc' methods depending on preferences.
#       The 'conference' method requires jabber:iq:browse and 
#       jabber:iq:conference.
#       The 'muc' method uses either jabber:iq:browse or disco.
#       
# Arguments:
#       what        'enter' or 'create'
#       args        -server, -roomjid, -autoget, -nickname, -protocol
#       
# Results:
#       "cancel" or "enter".

proc ::GroupChat::EnterOrCreate {what args} {
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    
    array set argsArr $args
    set roomjid ""
    set service ""
    if {[info exists argsArr(-roomjid)]} {
	set roomjid $argsArr(-roomjid)
	jlib::splitjidex $roomjid node service res
    } elseif {[info exists argsArr(-server)]} {
	set service $argsArr(-server)
    }

    if {[info exists argsArr(-protocol)]} {
	set protocol $argsArr(-protocol)
    } else {
	
	# Preferred groupchat protocol (gc-1.0|muc).
	# Use 'gc-1.0' as fallback.
	set protocol "gc-1.0"
	
	# Consistency checking.
	if {![regexp {(gc-1.0|muc)} $jprefs(prefgchatproto)]} {
	    set jprefs(prefgchatproto) muc
	}
	
	::Debug 2 "::GroupChat::EnterOrCreate prefgchatproto=$jprefs(prefgchatproto) \
	  what=$what, roomjid=$roomjid, service=$service, args='$args'"
	
	switch -- $jprefs(prefgchatproto) {
	    gc-1.0 {
		set protocol "gc-1.0"
	    }
	    muc {
		if {[HaveMUC $service]} {
		    set protocol "muc"
		} elseif {[HaveOrigConference $service]} {
		    set protocol "conference"
		}
	    }
	}
    }
    ::Debug 2 "\t protocol=$protocol"
    
    switch -glob -- $what,$protocol {
	*,gc-1.0 {
	    set ans [eval {BuildEnter} $args]
	}
	enter,conference {
	    set ans [eval {::Conference::BuildEnter} $args]
	}
	create,conference {
	    set ans [eval {::Conference::BuildCreate} $args]
	}
	enter,muc {
	    set ans [eval {::MUC::BuildEnter} $args]
	}
	create,muc {
	    set ans [eval {::Conference::BuildCreate} $args]
	}
	default {
	    # error
	}
    }    
    
    return $ans
}

proc ::GroupChat::EnterHook {roomjid protocol} {
    
    ::Debug 2 "::GroupChat::EnterHook roomjid=$roomjid $protocol"
    
    SetProtocol $roomjid $protocol
    
    # If we are using the 'conference' protocol we must browse
    # the room to get the participants.
    if {$protocol == "conference"} {
	::Browse::Get $roomjid
    }
}

# GroupChat::SetProtocol --
# 
#       Cache groupchat protocol in use for specific room.

proc ::GroupChat::SetProtocol {roomjid inprotocol} {
    
    variable protocol

    ::Debug 2 "::GroupChat::SetProtocol $roomjid $inprotocol"
    set roomjid [jlib::jidmap $roomjid]
    
    # We need a separate cache for this since the room may not yet exist.
    set protocol($roomjid) $inprotocol
    
    set token [GetTokenFrom roomjid $roomjid]
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

# GroupChat::BuildEnter --
#
#       This is to provide support for the old-style 'groupchat 1.0' protocol
#       which shall be used when not server is being browsed.
#       
# Arguments:
#       args        -server, -roomjid, -autoget, -nickname
#       
# Results:
#       "cancel" or "enter".
     
proc ::GroupChat::BuildEnter {args} {
    global  this wDlgs

    variable enteruid
    variable dlguid
    upvar ::Jabber::jstate jstate

    set chatservers [$jstate(jlib) service getjidsfor "groupchat"]
    ::Debug 2 "::GroupChat::BuildEnter args='$args'"
    ::Debug 2 "\t service getjidsfor groupchat: '$chatservers'"
    
    if {$chatservers == {}} {
	::UI::MessageBox -icon error -message [mc jamessnogchat]
	return
    }

    # State variable to collect instance specific variables.
    set token [namespace current]::enter[incr enteruid]
    variable $token
    upvar 0 $token enter
    
    set w $wDlgs(jgcenter)[incr dlguid]
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
    wm title $w [mc {Enter/Create Room}]
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
    set msg [mc jagchatmsg]
    message $frmid.msg -width 260 -text $msg
    label $frmid.lserv -text "[mc Servers]:" -anchor e

    set wcomboserver $frmid.eserv
    ::combobox::combobox $wcomboserver -width 18  \
      -textvariable $token\(server)
    eval {$frmid.eserv list insert end} $chatservers
    label $frmid.lroom -text "[mc Room]:" -anchor e
    entry $frmid.eroom -width 24    \
      -textvariable $token\(roomname) -validate key  \
      -validatecommand {::Jabber::ValidateUsernameStr %S}
    label $frmid.lnick -text "[mc {Nick name}]:" \
      -anchor e
    entry $frmid.enick -width 24    \
      -textvariable $token\(nickname) -validate key  \
      -validatecommand {::Jabber::ValidateResourceStr %S}
    
    grid $frmid.msg   -            -sticky ew
    grid $frmid.lserv $frmid.eserv
    grid $frmid.lroom $frmid.eroom
    grid $frmid.lnick $frmid.enick
    grid $frmid.lserv $frmid.lroom $frmid.lnick -sticky e
    grid $frmid.eserv $frmid.eroom $frmid.enick -sticky ew
    
    if {[info exists argsArr(-roomjid)]} {
	jlib::splitjidex $argsArr(-roomjid) node service res
	set enter(roomname) $node
	set enter(server)   $service
	$wcomboserver configure -state disabled
	$frmid.eroom configure -state disabled
    }
    if {[info exists argsArr(-server)]} {
	set server $argsArr(-server)
	set enter(server) $argsArr(-server)
	$wcomboserver configure -state disabled
    }
    if {[info exists argsArr(-nickname)]} {
	set enter(nickname) $argsArr(-nickname)
    }
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [mc Enter] -default active \
      -command [list [namespace current]::DoEnter $token]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel]   \
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

proc ::GroupChat::Cancel {token} {
    variable $token
    upvar 0 $token enter

    set enter(finished) 0
    catch {destroy $enter(w)}
}

proc ::GroupChat::DoEnter {token} {
    variable $token
    upvar 0 $token enter

    upvar ::Jabber::jstate jstate
    
    # Verify the fields first.
    if {($enter(server) == "") || ($enter(roomname) == "") ||  \
      ($enter(nickname) == "")} {
	::UI::MessageBox -title [mc Warning] -type ok -message \
	  [mc jamessgchatfields] -parent $enter(w)
	return
    }

    set roomjid [jlib::jidmap [jlib::joinjid $enter(roomname) $enter(server) ""]]
    $jstate(jlib) groupchat enter $roomjid $enter(nickname) \
      -command [namespace current]::EnterCallback

    set enter(finished) 1
    destroy $enter(w)
}

proc ::GroupChat::EnterCallback {jlibName type args} {
    
    array set argsArr $args
    if {[string equal $type "error"]} {
	set msg "We got an error when entering room \"$argsArr(-from)\"."
	if {[info exists argsArr(-error)]} {
	    foreach {errcode errmsg} $argsArr(-error) break
	    append msg " The error code is $errcode: $errmsg"
	}
	::UI::MessageBox -title "Error Enter Room" -message $msg -icon error
	return
    }
    
    # Cache groupchat protocol type (muc|conference|gc-1.0).
    ::hooks::run groupchatEnterRoomHook $argsArr(-from) "gc-1.0"
}

# GroupChat::GotMsg --
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

proc ::GroupChat::GotMsg {body args} {
    global  prefs
    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::GroupChat::GotMsg args='$args'"
    
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
    set token [GetTokenFrom roomjid $roomjid]
    if {$token == ""} {
	set token [eval {Build $roomjid} $args]
    }
    variable $token
    upvar 0 $token state
    
    if {[info exists argsArr(-subject)]} {
	set state(subject) $argsArr(-subject)
    }
    if {[string length $body] > 0} {

	# And put message in window.
	eval {InsertMessage $token $from $body} $args
	set state(got1stmsg) 1
	
	# Run display hooks (speech).
	eval {::hooks::run displayGroupChatMessageHook $body} $args
    }
}

# GroupChat::Build --
#
#       Builds the group chat dialog. Independently on protocol 'gc-1.0',
#       'conference', or 'muc'.
#
# Arguments:
#       roomjid     The roomname@server
#       args        ??
#       
# Results:
#       shows window, returns token.

proc ::GroupChat::Build {roomjid args} {
    global  this prefs wDlgs
    
    variable protocol
    variable groupChatOptions
    variable uid
    variable cprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::GroupChat::Build roomjid=$roomjid, args='$args'"

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
    wm title $w "[mc Groupchat]: $tittxt"
    
    set fontS  [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]

    foreach {optName optClass} $groupChatOptions {
	set $optName [option get $w $optName $optClass]
    }
    
    # Global frame.
    frame $w.frall
    pack  $w.frall -fill both -expand 1
    
    # Widget paths.
    set wtop      $w.frall.top
    set wtray     $wtop.tray
    set frmid     $w.frall.frmid
    set wtxt      $frmid.frtxt
    set wtext     $wtxt.0.text
    set wysc      $wtxt.0.ysc
    set wfrusers  $wtxt.1
    set wusers    $wfrusers.text
    set wyscusers $wfrusers.ysc
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

    frame $wtop
    pack  $wtop -side top -fill x

    ::buttontray::buttontray $wtray
    pack $wtray -side top -fill x

    $wtray newbutton send -text [mc Send] \
      -image $iconSend -disabledimage $iconSendDis    \
      -command [list [namespace current]::Send $token]
    $wtray newbutton save -text [mc Save] \
      -image $iconSave -disabledimage $iconSaveDis    \
       -command [list [namespace current]::Save $token]
    $wtray newbutton history -text [mc History] \
      -image $iconHistory -disabledimage $iconHistoryDis \
      -command [list [namespace current]::BuildHistory $token]
    $wtray newbutton invite -text [mc Invite] \
      -image $iconInvite -disabledimage $iconInviteDis  \
      -command [list ::MUC::Invite $roomjid]
    $wtray newbutton info -text [mc Info] \
      -image $iconInfo -disabledimage $iconInfoDis    \
      -command [list ::MUC::BuildInfo $roomjid]
    $wtray newbutton print -text [mc Print] \
      -image $iconPrint -disabledimage $iconPrintDis   \
      -command [list [namespace current]::Print $token]
    
    ::hooks::run buildGroupChatButtonTrayHook $wtray $roomjid
    
    set shortBtWidth [expr [$wtray minwidth] + 8]

    # Button part.
    set frbot [frame $w.frall.bot]
    pack $frbot -side bottom -fill x
    set wbtsend $frbot.btok
    pack [button $wbtsend -text [mc Send]  \
      -default active -command [list [namespace current]::Send $token]] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Exit]  \
      -command [list [namespace current]::Exit $token]]  \
      -side right -padx 5  
    pack [::Emoticons::MenuButton $frbot.smile -text $wtextsnd]  \
      -side right -padx 6
    set wbtstatus $frbot.stat
    
    set state(wbstatus) $wbtstatus

    ::Jabber::Status::Button $wbtstatus \
      $token\(status) -command [list [namespace current]::StatusCmd $token] 
    ::Jabber::Status::ConfigButton $wbtstatus available
    
    pack $wbtstatus -side right -padx 6

    pack [checkbutton $frbot.active -text " [mc {Active <Return>}]" \
      -command [list [namespace current]::ActiveCmd $token] \
      -variable $token\(active)]  \
      -side left -padx 5
            
    # D = -bd 2 -relief sunken
    pack [frame $w.frall.divt] -fill x -side top
    
    # Header fields.
    set   frtop [frame $w.frall.frtop -borderwidth 0]
    pack  $frtop -side top -fill x
    set wbtsubject $frtop.btp
    button $frtop.btp -text "[mc Topic]:" -font $fontS  \
      -command [list [namespace current]::SetTopic $token]
    entry $frtop.etp -textvariable $token\(subject) -state disabled
    set wbtnick $frtop.bni
    button $wbtnick -text "[mc {Nick name}]..."  \
      -font $fontS -command [list ::MUC::SetNick $roomjid]
    
    grid $frtop.btp -column 0 -row 0 -sticky w -padx 6 -pady 1
    grid $frtop.etp -column 1 -row 0 -sticky ew -padx 4 -pady 1
    grid $frtop.bni -column 2 -row 0 -sticky ew -padx 6 -pady 1
    grid columnconfigure $frtop 1 -weight 1
    
    if {!( [info exists protocol($roomjid)] && ($protocol($roomjid) == "muc") )} {
	$wbtnick configure -state disabled
	$wtray buttonconfigure invite -state disabled
	$wtray buttonconfigure info   -state disabled
    }
    
    # Text chat display.
    pack [frame $frmid -height 250 -width 300 -relief sunken -bd 1 -class Pane] \
      -side top -fill both -expand 1 -padx 4 -pady 4
    frame $wtxt -height 200
    frame $wtxt.0
    text $wtext -height 12 -width 1 -font $fontS -state disabled  \
      -borderwidth 1 -relief sunken -wrap word -cursor {}  \
      -yscrollcommand [list ::UI::ScrollSet $wysc \
      [list grid $wysc -column 1 -row 0 -sticky ns -padx 2]]
    scrollbar $wysc -orient vertical -command [list $wtext yview]
    grid $wtext -column 0 -row 0 -sticky news
    grid $wysc  -column 1 -row 0 -sticky ns -padx 2
    grid columnconfigure $wtxt.0 0 -weight 1
    grid rowconfigure    $wtxt.0 0 -weight 1
    
    # Users list.
    frame $wfrusers
    scrollbar $wyscusers -orient vertical -command [list $wusers yview]
    ::tree::tree $wusers -width 120 -height 100 -silent 1 -scrollwidth 400 \
      -treecolor "" -styleicons "" -indention 0 -pyjamascolor "" -xmargin 2 \
      -yscrollcommand [list ::UI::ScrollSet $wyscusers \
      [list grid $wyscusers -row 0 -column 1 -sticky ns]] \
      -eventlist [list [list <<ButtonPopup>> [namespace current]::Popup]]

    if {[string match "mac*" $this(platform)]} {
	$wusers configure -buttonpresscommand [namespace current]::Popup
    }

    grid $wusers    -column 0 -row 0 -sticky news
    grid $wyscusers -column 1 -row 0 -sticky ns -padx 2
    grid columnconfigure $wfrusers 0 -weight 1
    grid rowconfigure    $wfrusers 0 -weight 1
    
    set imageVertical   [::Theme::GetImage [option get $frmid imageVertical {}]]
    set imageHorizontal [::Theme::GetImage [option get $frmid imageHorizontal {}]]
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
    eval {::pane::pane $wtxt.0 $wfrusers} $paneopts
    
    # The tags.
    ConfigureTextTags $w $wtext
    
    # Text send.
    frame $wtxtsnd -height 100 -width 300
    text  $wtextsnd -height 4 -width 1 -font $fontS -wrap word \
      -borderwidth 1 -relief sunken -yscrollcommand \
      [list ::UI::ScrollSet $wyscsnd \
      [list grid $wyscsnd -column 1 -row 0 -sticky ns]]
    scrollbar $wyscsnd -orient vertical -command [list $wtextsnd yview]
    grid $wtextsnd -column 0 -row 0 -sticky news
    grid $wyscsnd  -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxtsnd 0 -weight 1
    grid rowconfigure    $wtxtsnd 0 -weight 1
    
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
    set state(wbtsend)    $wbtsend
    
    if {$state(active)} {
	ActiveCmd $token
    }
    AddUsers $token
        
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jgc)]]
    if {$nwin == 1} {
	::UI::SetWindowGeometry $w $wDlgs(jgc)
    }
    wm minsize $w [expr {$shortBtWidth < 240} ? 240 : $shortBtWidth] 320
    wm maxsize $w 800 2000

    bind $wtextsnd <Return> \
      [list [namespace current]::ReturnKeyPress $token]
    bind $wtextsnd <$this(modkey)-Return> \
      [list [namespace current]::CommandReturnKeyPress $token]
    
    focus $w
    return $token
}

proc ::GroupChat::StatusCmd {token status} {
    variable $token
    upvar 0 $token state

    ::Debug 2 "::GroupChat::StatusCmd status=$status"

    if {$status == "unavailable"} {
	set ans [Exit $token]
	if {$ans == "no"} {
	    set state(status) $state(oldStatus)
	}
    } else {
    
	# Send our status.
	::Jabber::SetStatus $status -to $state(roomjid)
	set state(oldStatus) $status
    }
}

# GroupChat::InsertMessage --
# 
#       Puts message in text groupchat window.

proc ::GroupChat::InsertMessage {token from body args} {
    variable $token
    upvar 0 $token state
    
    set w       $state(w)
    set wtext   $state(wtext)
    set roomjid $state(roomjid)
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
    set secs ""
    if {[info exists argsArr(-x)]} {
	set tm [::Jabber::GetAnyDelayElem $argsArr(-x)]
	if {$tm != ""} {
	    set secs [clock scan $tm -gmt 1]
	}
    }
    if {$secs == ""} {
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
    append prefix "<$nick>"
    
    $wtext configure -state normal
    $wtext insert end $prefix ${whom}pre
    
    ::Text::Parse $wtext "  $body" ${whom}text
    $wtext insert end \n
    
    $wtext configure -state disabled
    $wtext see end

    # History.
    set dateISO [clock format $secs -format "%Y%m%dT%H:%M:%S"]
    ::History::PutToFile $roomjid [list $nick $dateISO $body $whom]
}

proc ::GroupChat::SetState {token theState} {
    variable $token
    upvar 0 $token state

    $state(wtray) buttonconfigure send   -state $theState
    $state(wtray) buttonconfigure invite -state $theState
    $state(wtray) buttonconfigure info   -state $theState
    $state(wbtsubject) configure -state $theState
    $state(wbtsend)    configure -state $theState
}

proc ::GroupChat::CloseHook {wclose} {
    global  wDlgs
    
    set result ""
    if {[string match $wDlgs(jgc)* $wclose]} {
	set token [GetTokenFrom w $wclose]
	if {$token != ""} {
	    set w $wclose
	    set ans [Exit $token]
	    if {$ans == "no"} {
		set result stop
	    }
	}
    }  
    return $result
}

proc ::GroupChat::ConfigureTextTags {w wtext} {
    variable groupChatOptions
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::GroupChat::ConfigureTextTags"
    
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
}

proc ::GroupChat::SetTopic {token} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    set topic   $state(subject)
    set roomjid $state(roomjid)
    set ans [::UI::MegaDlgMsgAndEntry  \
      [mc {Set New Topic}]  \
      [mc jasettopic]  \
      "[mc {New Topic}]:"  \
      topic [mc Cancel] [mc OK]]

    if {($ans == "ok") && ($topic != "")} {
	::Jabber::JlibCmd send_message $roomjid -type groupchat \
	  -subject $topic
    }
    return $ans
}

proc ::GroupChat::Send {token} {
    global  prefs
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    # Check that still connected to server.
    if {![::Jabber::IsConnected]} {
	::UI::MessageBox -type ok -icon error -title [mc {Not Connected}] \
	  -message [mc jamessnotconnected]
	return
    }
    set wtextsnd $state(wtextsnd)
    set roomjid  $state(roomjid)

    # Get text to send. Strip off any ending newlines from Return.
    # There might by smiley icons in the text widget. Parse them to text.
    set allText [::Text::TransformToPureText $wtextsnd]
    set allText [string trimright $allText "\n"]
    if {$allText != ""} {	
	::Jabber::JlibCmd send_message $roomjid -type groupchat -body $allText
    }
    
    # Clear send.
    $wtextsnd delete 1.0 end
    set state(hot1stmsg) 1
}

proc ::GroupChat::ActiveCmd {token} {
    variable cprefs
    variable $token
    upvar 0 $token state
    
    # Remember last setting.
    set cprefs(lastActiveRet) $state(active)
}

# Suggestion from marc@bruenink.de.
# 
#       inactive mode: 
#       Ret: word-wrap
#       Ctrl+Ret: send messgae
#
#       active mode:
#       Ret: send message
#       Ctrl+Ret: word-wrap

proc ::GroupChat::ReturnKeyPress {token} {
    variable $token
    upvar 0 $token state

    if {$state(active)} {
	Send $token
	
	# Stop the actual return to be inserted.
	return -code break
    }
}

proc ::GroupChat::CommandReturnKeyPress {token} {
    variable $token
    upvar 0 $token state
    
    if {!$state(active)} {
	Send $token
	
	# Stop further handling in Text.
	return -code break
    }
}

# GroupChat::GetTokenFrom --
# 
#       Try to get the token state array from any stored key.
#       
# Arguments:
#       key         w, jid, roomjid etc...
#       pattern     glob matching
#       
# Results:
#       token or empty if not found.

proc ::GroupChat::GetTokenFrom {key pattern} {
    
    # Search all tokens for this key into state array.
    foreach token [GetTokenList] {
	variable $token
	upvar 0 $token state
	
	if {[info exists state($key)] && [string match $pattern $state($key)]} {
	    return $token
	}
    }
    return ""
}

proc ::GroupChat::GetTokenList { } {
    
    set ns [namespace current]
    return [concat  \
      [info vars ${ns}::\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]\[0-9\]\[0-9\]\[0-9\]]]
}

# GroupChat::Presence --
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

proc ::GroupChat::PresenceHook {jid presence args} {
    
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::GroupChat::PresenceHook jid=$jid, presence=$presence, args='$args'"
    
    array set argsArr $args
    set jid2 $jid
    set jid3 $jid
    if {[info exists argsArr(-resource)]} {
	set jid3 ${jid2}/$argsArr(-resource)
    }
    jlib::splitjidex $jid3 node service res
    
    # We must check that non of jid2 or jid3 are roster items.
    if {[$jstate(roster) isitem $jid2] || [$jstate(roster) isitem $jid3]} {
	return
    }

    # Some msn components may send presence directly from a room when
    # a chat invites you to a multichat:
    # <presence 
    #     from='r1@msn.jabber.ccc.de/marilund60@hotmail.com' 
    #     to='matben@jabber.ccc.de'/>
    #     
    # Note that a conference service may also be a gateway!
    set conferences [$jstate(jlib) service getconferences]
    set allroomsin  [$jstate(jlib) service allroomsin]
    set inroom [expr [lsearch $allroomsin $jid2] < 0 ? 0 : 1]
    set isconf [expr [lsearch $conferences $service] < 0 ? 0 : 1]
    set isroom [$jstate(jlib) service isroom $jid]
    ::Debug 4 "..........................."
    ::Debug 4 "conferences=$conferences"
    ::Debug 4 "allroomsin=$allroomsin"
    ::Debug 4 "inroom=$inroom, isconf=$isconf, isroom=$isroom"
    
    if {!$inroom && $isconf && ($presence == "available")} {
	
	# This seems to be a kind of invitation for a groupchat.
	set str [mc jamessgcinvite ${node}@${service} $argsArr(-from)]
	set ans [::UI::MessageBox -icon info -type yesno -message $str]
	if {$ans == "yes"} {
	    jlib::splitjidex $argsArr(-to) nd hst rs
	    EnterOrCreate enter -roomjid $jid2 -nickname $nd -protocol gc-1.0
	}
    } 
    
    # Only if we actually entered the room.
    if {$isroom} {
	# Since there should not be any /resource.
	set roomjid $jid
	if {[string equal $presence "available"]} {
	    eval {SetUser $roomjid $jid3 $presence} $args
	} elseif {[string equal $presence "unavailable"]} {
	    RemoveUser $roomjid $jid3
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
	
	if {[info exists argsArr(-x)]} {
	    foreach c $argsArr(-x) {
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

# GroupChat::BrowseUser --
#
#       This is a <user> element. Gets called for each <user> element
#       in the jabber:iq:browse set or result iq element.
#       Only called if have conference/browse stuff for this service.

proc ::GroupChat::BrowseUser {userXmlList} {
    
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::GroupChat::BrowseUser userXmlList='$userXmlList'"

    array set argsArr [lindex $userXmlList 1]
    
    # Direct it to the correct room. 
    set jid $argsArr(jid)
    set parentList [$jstate(browse) getparents $jid]
    set parent [lindex $parentList end]
    
    # Do something only if joined that room.
    if {[$jstate(jlib) service isroom $parent] &&  \
      ([lsearch [$jstate(jlib) conference allroomsin] $parent] >= 0)} {
	if {[info exists argsArr(type)] && [string equal $argsArr(type) "remove"]} {
	    RemoveUser $parent $jid
	} else {
	    SetUser $parent $jid {}
	}
    }
}

proc ::GroupChat::AddUsers {token} {
    variable $token
    upvar 0 $token state
    
    upvar ::Jabber::jstate jstate
    
    set roomjid $state(roomjid)
    
    set presenceList [$jstate(roster) getpresence $roomjid]
    foreach pres $presenceList {
	unset -nocomplain presArr
	array set presArr $pres
	
	set jid3 $roomjid/$presArr(-resource)
	eval {SetUser $roomjid $jid3 $presArr(-type)} $pres
    }
}

# GroupChat::SetUser --
#
#       Adds or updates a user item in the group chat dialog.
#       
# Arguments:
#       roomjid     the room's jid
#       jid3        roomjid/hashornick
#       presence    "available", "unavailable", or "unsubscribed"
#       args        list of '-key value' pairs where '-key' can be
#                   -resource, -from, -type, -show,...
#       
# Results:
#       updated UI.

proc ::GroupChat::SetUser {roomjid jid3 presence args} {
    global  this

    variable userRoleToStr
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::GroupChat::SetUser roomjid=$roomjid, jid3=$jid3 \
      presence=$presence args=$args"

    array set argsArr $args
    set roomjid [jlib::jidmap $roomjid]
    set jid3    [jlib::jidmap $jid3]

    # If we haven't a window for this thread, make one!
    set token [GetTokenFrom roomjid $roomjid]
    if {$token == ""} {
	set token [eval {Build $roomjid} $args]
    }       
    variable $token
    upvar 0 $token state
    
    # Get the hex string to use as tag. 
    # In old-style groupchat this is the nick name which should be unique
    # within this room aswell.
    jlib::splitjid $jid3 jid2 resource
    
    # If we got a browse push with a <user>, assume is available.
    if {$presence == ""} {
	set presence available
    }
    
    # Any show attribute?
    set showStatus $presence
    if {[info exists argsArr(-show)] && ($argsArr(-show) != "")} {
	set showStatus $argsArr(-show)
    } elseif {[info exists argsArr(-subscription)] &&   \
      [string equal $argsArr(-subscription) "none"]} {
	set showStatus "subnone"
    }
    
    # Remove any "old" line first. Image takes one character's space.
    set wusers $state(wusers)
    
    # Old-style groupchat and browser compatibility layer.
    set nick [$jstate(jlib) service nick $jid3]
    set icon [eval {::Roster::GetPresenceIcon $jid3 $presence} $args]
        
    # Cover both a "flat" users list and muc's with the roles 
    # moderator, participant, and visitor.
    set role [GetRoleFromJid $jid3]
    if {$role == ""} {
	$wusers newitem $jid3 -text $nick -image $icon -tags [list $jid3]
    } else {
	if {![$wusers isitem $role]} {
	    $wusers newitem $role -text $userRoleToStr($role) -dir 1 \
	      -sortcommand {lsort -dictionary}
	    if {[string equal $role "moderator"]} {
		$wusers raiseitem $role
	    }
	}
	$wusers newitem [list $role $jid3] -text $nick -image $icon  \
	  -tags [list $jid3]
    }
    
    # Noise.
    ::Sounds::PlayWhenIdle online
}

proc ::GroupChat::GetRoleFromJid {jid3} {
    upvar ::Jabber::jstate jstate
   
    set role ""
    set userElem [$jstate(roster) getx $jid3 "muc#user"]
    if {$userElem != {}} {
	set ilist [wrapper::getchildswithtag $userElem "item"]
	if {$ilist != {}} {
	    set item [lindex $ilist 0]
	    set role [wrapper::getattribute $item "role"]
	}
    }
    return $role
}

proc ::GroupChat::GetAnyRoleFromXElem {xelem} {
    upvar ::Jabber::xmppxmlns xmppxmlns

    set role ""
    set clist [wrapper::getnamespacefromchilds $xelem x $xmppxmlns(muc,user)]
    set userElem [lindex $clist 0]
    if {[llength $userElem]} {
	set ilist [wrapper::getchildswithtag $userElem "item"]
	set item [lindex $ilist 0]
	if {[llength $item]} {
	    set role [wrapper::getattribute $item "role"]
	}
    }
    return $role
}
    
proc ::GroupChat::RegisterPopupEntry {menuSpec} {
    variable popMenuDefs
    
    set popMenuDefs(groupchat,def) [concat $popMenuDefs(groupchat,def) $menuSpec]
}

proc ::GroupChat::PopupTimer {token jid3 x y} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::GroupChat::PopupTimer jid3=$jid3"

    # Set timer for this callback.
    if {[info exists state(afterid)]} {
	catch {after cancel $state(afterid)}
    }
    set w $state(wusers)
    set state(afterid) [after 1000  \
      [list [namespace current]::Popup $w $jid3 $x $y]]
}

proc ::GroupChat::PopupTimerCancel {token} {
    variable $token
    upvar 0 $token state

    catch {after cancel $state(afterid)}
}

# GroupChat::Popup --
#
#       Handle popup menu in groupchat dialog.
#       
# Arguments:
#       w           widget that issued the command: tree or text
#       v           for the tree widget it is the item path
#       
# Results:
#       popup menu displayed

proc ::GroupChat::Popup {w v x y} {
    global  wDlgs this
    
    variable popMenuDefs
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::GroupChat::Popup w=$w, v='$v', x=$x, y=$y"
    
    # The last element of $v is either a jid, (a namespace,) 
    # a header in roster, a group, or an agents xml tag.
    # The variables name 'jid' is a misnomer.
    # Find also type of thing clicked, 'typeClicked'.
    
    set typeClicked ""
    
    set jid [lindex $v end]
    set jid3 $jid
    if {[regexp {^[^@]+@[^@]+(/.*)?$} $jid match res]} {
	set typeClicked user
    }
    if {$jid == ""} {
	set typeClicked ""	
    }
    set X [expr [winfo rootx $w] + $x]
    set Y [expr [winfo rooty $w] + $y]
    
    ::Debug 2 "\t jid=$jid, typeClicked=$typeClicked"
    
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
	    set locname [mc $item]
	    $m add cascade -label $locname -menu $mt -state disabled
	    eval [string range $cmd 1 end] $mt
	    incr i
	} elseif {[string equal $item "separator"]} {
	    $m add separator
	    continue
	} else {
	    
	    # Substitute the jid arguments. Preserve list structure!
	    set cmd [eval list $cmd]
	    set locname [mc $item]
	    $m add command -label $locname -command [list after 40 $cmd]  \
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

proc ::GroupChat::RemoveUser {roomjid jid3} {

    ::Debug 4 "::GroupChat::RemoveUser roomjid=$roomjid, jid3=$jid3"
    
    set roomjid [jlib::jidmap $roomjid]
    set token [GetTokenFrom roomjid $roomjid]
    if {$token == ""} {
	return
    }
    variable $token
    upvar 0 $token state
    
    set wusers $state(wusers)
    set items [$wusers find withtag $jid3]
    foreach item $items {
	$wusers delitem $item
    }
    
    # Noise.
    ::Sounds::PlayWhenIdle offline
}

proc ::GroupChat::BuildHistory {token} {
    variable $token
    upvar 0 $token state

    
    ::History::BuildHistory $state(roomjid) -class GroupChat  \
      -tagscommand ::GroupChat::ConfigureTextTags
}

proc ::GroupChat::Save {token} {
    global  this
    variable $token
    upvar 0 $token state
    
    set wtext   $state(wtext)
    set roomjid $state(roomjid)
    
    set ans [tk_getSaveFile -title [mc Save] \
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

proc ::GroupChat::Print {token} {
    variable $token
    upvar 0 $token state
    
    ::UserActions::DoPrintText $state(wtext) 
}

proc ::GroupChat::ExitRoom {roomjid} {

    set roomjid [jlib::jidmap $roomjid]
    set token [GetTokenFrom roomjid $roomjid]
    if {$token != ""} {
	Exit $token
    }
}

# GroupChat::Exit --
#
#       Ask if wants to exit room. If then calls GroupChat::Close to do it.
#       
# Arguments:
#       roomjid
#       
# Results:
#       yes/no if actually exited or not.

proc ::GroupChat::Exit {token} {
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
	set ans [eval {::UI::MessageBox -icon warning -type yesno  \
	  -message [mc jamesswarnexitroom $roomjid]} $opts]
	if {$ans == "yes"} {
	    Close $token
	    $jstate(jlib) service exitroom $roomjid
	    ::hooks::run groupchatExitRoomHook $roomjid
	}
    } else {
	set ans "yes"
	Close $token
    }
    return $ans
}

# GroupChat::Close --
#
#       Handles the closing of a groupchat. Both text and whiteboard dialogs.

proc ::GroupChat::Close {token} {
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
    # ::hooks::run groupchatExitRoomHook $roomjid
}

# GroupChat::LogoutHook --
#
#       Sets logged out status on all groupchats, that is, disable all buttons.

proc ::GroupChat::LogoutHook { } {    
    upvar ::Jabber::jstate jstate

    set tokenList [GetTokenList]
    foreach token $tokenList {
	variable $token
	upvar 0 $token state

	SetState $token disabled
	::hooks::run groupchatExitRoomHook $state(roomjid)
    }
}

proc ::GroupChat::LoginHook { } {    
    upvar ::Jabber::jstate jstate

    set tokenList [GetTokenList]
    foreach token $tokenList {
	variable $token
	upvar 0 $token state

	SetState $token normal
    }
}

proc ::GroupChat::GetFirstPanePos { } {
    global  wDlgs
    
    set win [::UI::GetFirstPrefixedToplevel $wDlgs(jgc)]
    set token [GetTokenFrom w $win]
    if {$token != ""} {
	variable $token
	upvar 0 $token state

	::UI::SavePanePos groupchatDlgVert $state(wtxt)
	::UI::SavePanePos groupchatDlgHori $state(wtxt.0) vertical
    }
}

# Prefs page ...................................................................

proc ::GroupChat::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    
    # Defaults...    
    # Preferred groupchat protocol (gc-1.0|muc).
    # 'muc' uses 'conference' as fallback.
    set jprefs(prefgchatproto) "muc"
	
    ::PreferencesUtils::Add [list  \
      [list ::Jabber::jprefs(prefgchatproto)   jprefs_prefgchatproto    $jprefs(prefgchatproto)]  \
      ]   
}

proc ::GroupChat::BuildPrefsHook {wtree nbframe} {
    
    $wtree newitem {Jabber Conference} -text [mc Conference]
    
    # Conference page ------------------------------------------------------
    set wpage [$nbframe page {Conference}]
    BuildPageConf $wpage
}

proc ::GroupChat::BuildPageConf {page} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs

    set ypad [option get [winfo toplevel $page] yPad {}]
    
    set tmpJPrefs(prefgchatproto) $jprefs(prefgchatproto)
    
    # Conference (groupchat) stuff.
    set labfr $page.fr
    labelframe $labfr -text [mc {Preferred Protocol}]
    pack $labfr -side top -anchor w -padx 8 -pady 4
    set pbl [frame $labfr.frin]
    pack $pbl -padx 10 -pady 6 -side left
    
    foreach  \
      val {gc-1.0                     muc}   \
      txt {{Groupchat-1.0 (fallback)} prefmucconf} {
	set wrad ${pbl}.[string map {. ""} $val]
	radiobutton $wrad -text [mc $txt] -value $val  \
	  -variable [namespace current]::tmpJPrefs(prefgchatproto)	      
	grid $wrad -sticky w -pady $ypad
    }
}

proc ::GroupChat::SavePrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    array set jprefs [array get tmpJPrefs]
    unset tmpJPrefs
}

proc ::GroupChat::CancelPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	if {![string equal $jprefs($key) $tmpJPrefs($key)]} {
	    ::Preferences::HasChanged
	    break
	}
    }
}

proc ::GroupChat::UserDefaultsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	set tmpJPrefs($key) $jprefs($key)
    }
}

#-------------------------------------------------------------------------------
