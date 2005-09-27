#  GroupChat.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the group chat GUI part.
#      
#  Copyright (c) 2001-2005  Mats Bengtsson
#  
# $Id: GroupChat.tcl,v 1.119 2005-09-27 15:02:04 matben Exp $

package require History

package provide GroupChat 1.0

# Provides dialog for old-style gc-1.0 groupchat but the rest should work for 
# both groupchat and conference protocols.


namespace eval ::GroupChat:: {

    # Add all event hooks.
    ::hooks::register quitAppHook             ::GroupChat::QuitAppHook
    ::hooks::register quitAppHook             ::GroupChat::GetFirstPanePos
    ::hooks::register newGroupChatMessageHook ::GroupChat::GotMsg
    ::hooks::register newMessageHook          ::GroupChat::NormalMsgHook
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

    # Text displays.
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
    option add *GroupChat*histHeadBackground   gray80           widgetDefault
    option add *GroupChat*histHeadFont         ""               widgetDefault
    option add *GroupChat*clockFormat          "%H:%M"          widgetDefault
    option add *GroupChat*clockFormatNotToday  "%b %d %H:%M"    widgetDefault

    option add *GroupChat*userForeground       ""               widgetDefault
    option add *GroupChat*userBackground       ""               widgetDefault
    option add *GroupChat*userFont             ""               widgetDefault
    option add *GroupChat*userIgnore           red              widgetDefault
    
    option add *GroupChat*Tree.background      white            50

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
    option add *GroupChat.padding              {12  0 12  0}   50
    option add *GroupChat*active.padding       {1}             50
    option add *GroupChat*TMenubutton.padding  {1}             50
    option add *GroupChat*top.padding          { 0  0  0  8}   50
    option add *GroupChat*bot.padding          { 0  8  0  0}   50
    
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
	command   mMessage       user      {::NewMsg::Build -to $jid}   {}
	command   mChat          user      {::Chat::StartThread $jid}   {}
	command   mSendFile      user      {::FTrans::Send $jid}        {}
	command   mUserInfo      user      {::UserInfo::Get $jid}       {}
	command   mWhiteboard    wb        {::Jabber::WB::NewWhiteboardTo $jid} {}
	check     mIgnore        user      {::GroupChat::Ignore $token $jid} {
	    -variable $token\(ignore,$jid)
	}    
    }
    
    variable userRoleToStr
    set userRoleToStr(moderator)   [mc Moderators]
    set userRoleToStr(none)        [mc None]
    set userRoleToStr(participant) [mc Participants]
    set userRoleToStr(visitor)     [mc Visitors]
    
    variable show2String
    set show2String(available)   [mc available]
    set show2String(away)        [mc away]
    set show2String(chat)        [mc chat]
    set show2String(dnd)         [mc {do not disturb}]
    set show2String(xa)          [mc {extended away}]
    set show2String(invisible)   [mc invisible]
    set show2String(unavailable) [mc {not available}]
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
    upvar ::Jabber::jprefs jprefs

    set chatservers [$jstate(jlib) service getjidsfor "groupchat"]
    ::Debug 2 "::GroupChat::BuildEnter args='$args'"
    ::Debug 2 "\t service getjidsfor groupchat: '$chatservers'"
    
    if {$chatservers == {}} {
	::UI::MessageBox -icon error -message [mc jamessnogroupchat]
	return
    }

    # State variable to collect instance specific variables.
    set token [namespace current]::enter[incr enteruid]
    variable $token
    upvar 0 $token enter
    
    set w $wDlgs(jgcenter)[incr dlguid]
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox} \
      -closecommand [namespace current]::CloseEnterCB
    wm title $w [mc {Enter/Create Room}]
    
    set enter(w) $w
    array set enter {
	finished    -1
	server      ""
	roomname    ""
	nickname    ""
    }
    set enter(nickname) $jprefs(defnick)
    array set argsArr $args
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    set enter(server) [lindex $chatservers 0]
    set frmid $wbox.mid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1

    set msg [mc jagchatmsg]
    ttk::label $frmid.msg -style Small.TLabel \
      -padding {0 0 0 6} -anchor w -wraplength 300 -justify left -text $msg
    ttk::label $frmid.lserv -text "[mc Servers]:" -anchor e

    set wcomboserver $frmid.eserv
    ttk::combobox $wcomboserver -width 18  \
      -textvariable $token\(server) -values $chatservers
    ttk::label $frmid.lroom -text "[mc Room]:" -anchor e
    ttk::entry $frmid.eroom -width 24    \
      -textvariable $token\(roomname) -validate key  \
      -validatecommand {::Jabber::ValidateUsernameStr %S}
    ttk::label $frmid.lnick -text "[mc {Nick name}]:" \
      -anchor e
    ttk::entry $frmid.enick -width 24    \
      -textvariable $token\(nickname) -validate key  \
      -validatecommand {::Jabber::ValidateResourceStr %S}
    
    grid  $frmid.msg    -             -pady 2 -sticky w
    grid  $frmid.lserv  $frmid.eserv  -pady 2
    grid  $frmid.lroom  $frmid.eroom  -pady 2
    grid  $frmid.lnick  $frmid.enick  -pady 2
    grid  $frmid.lserv  $frmid.lroom  $frmid.lnick -sticky e
    grid  $frmid.eserv  $frmid.eroom  $frmid.enick -sticky ew
    
    if {[info exists argsArr(-roomjid)]} {
	jlib::splitjidex $argsArr(-roomjid) node service res
	set enter(roomname) $node
	set enter(server)   $service
	$wcomboserver state {disabled}
	$frmid.eroom  state {disabled}
    }
    if {[info exists argsArr(-server)]} {
	set server $argsArr(-server)
	set enter(server) $argsArr(-server)
	$wcomboserver state {disabled}
    }
    if {[info exists argsArr(-nickname)]} {
	set enter(nickname) $argsArr(-nickname)
    }
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Enter] -default active \
      -command [list [namespace current]::DoEnter $token]
    ttk::button $frbot.btcancel -text [mc Cancel]   \
      -command [list [namespace current]::Cancel $token]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side top -fill x
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    wm resizable $w 0 0
    ::UI::SetWindowPosition $w $wDlgs(jgcenter)
    bind $w <Return> [list $frbot.btok invoke]
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {focus $oldFocus}
    set finished $enter(finished)
    unset enter
    return [expr {($finished <= 0) ? "cancel" : "enter"}]
}

proc ::GroupChat::CloseEnterCB {w} {
    global  wDlgs
    
    ::UI::SaveWinPrefixGeom $wDlgs(jgcenter)
    return
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

# GroupChat::NormalMsgHook --
# 
#       MUC (and others) send invitations using normal messages. Catch!

proc ::GroupChat::NormalMsgHook {body args} {
    upvar ::Jabber::xmppxmlns xmppxmlns
    
    array set argsArr $args

    set isinvite 0
    if {[info exists argsArr(-x)]} {
    
	::Debug 2 "::GroupChat::NormalMsgHook args='$args'"

	set xList $argsArr(-x)
	set cList [wrapper::getnamespacefromchilds $xList x $xmppxmlns(muc,user)]
	set roomjid $argsArr(-from)
	
	if {$cList != {}} {
	    set inviteElem [wrapper::getfirstchildwithtag [lindex $cList 0] invite]
	    if {$inviteElem != {}} {
		set isinvite 1
		set str2 ""
		set invitejid [wrapper::getattribute $inviteElem from]
		set reasonElem [wrapper::getfirstchildwithtag $inviteElem reason]
		if {$reasonElem != {}} {
		    append str2 "Reason: [wrapper::getcdata $reasonElem]"
		}
		set passwordElem [wrapper::getfirstchildwithtag $cList password]
		if {$passwordElem != {}} {
		    append str2 " Password: [wrapper::getcdata $passwordElem]"
		}
	    }
	} else {
	    set cList [wrapper::getnamespacefromchilds $xList x \
	      "jabber:x:conference"]
	    if {$cList != {}} {
		set isinvite 1
		set xElem [lindex $cList 0]
		set invitejid [wrapper::getattribute $xElem jid]
		set str2 "Reason: [wrapper::getcdata $xElem]"
	    }	    
	}
    }
    if {$isinvite} {
	set str [mc jamessgcinvite $roomjid $invitejid]
	append str " " $str2
	set ans [::UI::MessageBox -title [mc Invite] -icon info -type yesno \
	  -message $str]
	if {$ans eq "yes"} {
	    EnterOrCreate enter -roomjid $roomjid
	}
	return stop
    } else {
	return
    }
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
    
    # We may get a history from users not in the room anymore.
    if {[info exists state(ignore,$from)] && $state(ignore,$from)} {
	return
    }
    if {[info exists argsArr(-subject)]} {
	set state(subject) $argsArr(-subject)
    }
    if {[string length $body]} {

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
    set state(ignore,$roomjid)  0
    
    set ancient [expr {[clock clicks -milliseconds] - 1000}]
    foreach whom {me you sys} {
	set state(last,$whom) $ancient
    }
    if {$jprefs(chatActiveRet)} {
	set state(active) 1
    } else {
	set state(active)       $cprefs(lastActiveRet)
    }
    
    # Toplevel of class GroupChat.
    ::UI::Toplevel $w -class GroupChat \
      -usemacmainmenu 1 -macstyle documentProc \
      -closecommand ::GroupChat::CloseHook
    
    # Not sure how old-style groupchat works here???
    set roomName [$jstate(jlib) service name $roomjid]
    
    if {[llength $roomName]} {
	set tittxt $roomName
    } else {
	set tittxt $roomjid
    }
    wm title $w "[mc Groupchat]: $tittxt"
    
    foreach {optName optClass} $groupChatOptions {
	set $optName [option get $w $optName $optClass]
    }
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    # Widget paths.
    set wtray       $w.frall.tray
    set wbox        $w.frall.f
    set wtop        $wbox.top
    set wbot        $wbox.bot
    set wmid        $wbox.m
    
    set wpanev      $wmid.pv
    set wfrsend     $wpanev.bot
    set wtextsend   $wfrsend.text
    set wyscsend    $wfrsend.ysc
    
    set wpaneh      $wpanev.top
    set wfrchat     $wpaneh.left
    set wfrusers    $wpaneh.right
        
    set wtext       $wfrchat.text
    set wysc        $wfrchat.ysc
    set wusers      $wfrusers.text
    set wyscusers   $wfrusers.ysc
    
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

    ::ttoolbar::ttoolbar $wtray
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

    ttk::separator $w.frall.divt -orient horizontal
    pack $w.frall.divt -side top -fill x
    
    ttk::frame $wbox -padding [option get . dialogSmallPadding {}]
    pack $wbox -fill both -expand 1

    # Button part.
    ttk::frame $wbot
    ttk::button $wbot.btok -text [mc Send]  \
      -default active -command [list [namespace current]::Send $token]
    ttk::button $wbot.btcancel -text [mc Exit]  \
      -command [list [namespace current]::Exit $token]
    ::Emoticons::MenuButton $wbot.smile -text $wtextsend
    ::Jabber::Status::Button $wbot.stat \
      $token\(status) -command [list [namespace current]::StatusCmd $token] 
    ::Jabber::Status::ConfigButton $wbot.stat available
    ttk::checkbutton $wbot.active -style Toolbutton \
      -image [::Theme::GetImage return] \
      -command [list [namespace current]::ActiveCmd $token] \
      -variable $token\(active)
    
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $wbot.btok  -side right
	pack $wbot.btcancel -side right -padx $padx
    } else {
	pack $wbot.btcancel -side right
	pack $wbot.btok -side right -padx $padx
    }
    pack  $wbot.active  -side left -fill y -padx 4
    pack  $wbot.stat    -side left -fill y -padx 4
    pack  $wbot.smile   -side left -fill y -padx 4    
    pack  $wbot  -side bottom -fill x
        
    set wbtsend   $wbot.btok
    set wbtstatus $wbot.stat    

    ::balloonhelp::balloonforwindow $wbot.active [mc jaactiveret]

    # Header fields.
    ttk::frame $wtop
    pack $wtop -side top -fill x

    ttk::button $wtop.btp -style Small.TButton \
      -text "[mc Topic]:" \
      -command [list [namespace current]::SetTopic $token]
    ttk::entry $wtop.etp -font CociSmallFont \
      -textvariable $token\(subject) -state disabled
    ttk::button $wtop.bni -style Small.TButton \
      -text "[mc {Nick name}]..."  \
      -command [list ::MUC::SetNick $roomjid]
    
    grid  $wtop.btp  $wtop.etp  $wtop.bni  -sticky e -padx 4
    grid  $wtop.etp  -sticky ew
    grid columnconfigure $wtop 1 -weight 1
    
    set wbtsubject $wtop.btp
    set wbtnick    $wtop.bni

    if {!( [info exists protocol($roomjid)] && ($protocol($roomjid) == "muc") )} {
	$wbtnick state {disabled}
	$wtray buttonconfigure invite -state disabled
	$wtray buttonconfigure info   -state disabled
    }
    
    # Main frame for panes.
    frame $wmid -height 250 -width 300 -relief sunken -bd 1
    pack  $wmid -side top -fill both -expand 1

    # Pane geometry manager.
    ttk::paned $wpanev -orient vertical
    pack $wpanev -side top -fill both -expand 1    

    # Text send.
    frame $wfrsend -height 100 -width 300
    text  $wtextsend -height 4 -width 1 -font CociSmallFont -wrap word \
      -borderwidth 1 -relief sunken -yscrollcommand \
      [list ::UI::ScrollSet $wyscsend \
      [list grid $wyscsend -column 1 -row 0 -sticky ns]]
    tuscrollbar $wyscsend -orient vertical -command [list $wtextsend yview]

    grid  $wtextsend  -column 0 -row 0 -sticky news
    grid  $wyscsend   -column 1 -row 0 -sticky ns
    grid columnconfigure $wfrsend 0 -weight 1
    grid rowconfigure    $wfrsend 0 -weight 1
    
    # Pane for chat and users list.
    ttk::paned $wpaneh -orient horizontal
    $wpanev add $wpaneh -weight 1
    $wpanev add $wfrsend -weight 1
    
    # Chat text widget.
    frame $wfrchat
    text  $wtext -height 12 -width 50 -font CociSmallFont -state disabled  \
      -borderwidth 1 -relief sunken -wrap word -cursor {}  \
      -yscrollcommand [list ::UI::ScrollSet $wysc \
      [list grid $wysc -column 1 -row 0 -sticky ns -padx 2]]
    tuscrollbar $wysc -orient vertical -command [list $wtext yview]
 
    grid  $wtext  -column 0 -row 0 -sticky news
    grid  $wysc   -column 1 -row 0 -sticky ns -padx 2
    grid columnconfigure $wfrchat 0 -weight 1
    grid rowconfigure    $wfrchat 0 -weight 1
    
    # Users list.
    frame $wfrusers
    set popupCmd [list [namespace current]::Popup $token]
    tuscrollbar $wyscusers -orient vertical -command [list $wusers yview]
    ::tree::tree $wusers -width 120 -height 100 -silent 1 -scrollwidth 400 \
      -treecolor "" -styleicons "" -indention 0 -pyjamascolor "" -xmargin 2 \
      -yscrollcommand [list ::UI::ScrollSet $wyscusers \
      [list grid $wyscusers -row 0 -column 1 -sticky ns]] \
      -eventlist [list [list <<ButtonPopup>> $popupCmd]]

    if {[string match "mac*" $this(platform)]} {
	$wusers configure -buttonpresscommand $popupCmd
    }

    grid  $wusers     -column 0 -row 0 -sticky news
    grid  $wyscusers  -column 1 -row 0 -sticky ns -padx 2
    grid columnconfigure $wfrusers 0 -weight 1
    grid rowconfigure    $wfrusers 0 -weight 1
    
    $wpaneh add $wfrchat -weight 1
    $wpaneh add $wfrusers -weight 1
    
    # The tags.
    ConfigureTextTags $w $wtext
        
    set state(wtray)      $wtray
    set state(wbtnick)    $wbtnick
    set state(wbtsubject) $wbtsubject
    set state(wbtstatus)  $wbtstatus
    set state(wtext)      $wtext
    set state(wtextsend)  $wtextsend
    set state(wusers)     $wusers
    set state(wbtsend)    $wbtsend
    set state(wpanev)     $wpanev
    set state(wpaneh)     $wpaneh
    
    if {$state(active)} {
	ActiveCmd $token
    }
    AddUsers $token
        
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jgc)]]
    if {$nwin == 1} {
	::UI::SetWindowGeometry $w $wDlgs(jgc)
    }
    ::UI::SetSashPos groupchatDlgVert $wpanev
    ::UI::SetSashPos groupchatDlgHori $wpaneh
    wm minsize $w [expr {$shortBtWidth < 240} ? 240 : $shortBtWidth] 320
    wm maxsize $w 800 2000

    bind $wtextsend <Return> \
      [list [namespace current]::ReturnKeyPress $token]
    bind $wtextsend <$this(modkey)-Return> \
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
    
    array set argsArr $args

    set w       $state(w)
    set wtext   $state(wtext)
    set roomjid $state(roomjid)
        
    # This can be room name or nick name.
    lassign [::Jabber::JlibCmd service hashandnick $roomjid] myroomjid mynick
    if {[string equal $myroomjid $from]} {
	set whom me
    } elseif {[string equal $roomjid $from]} {
	set whom sys
    } else {
	set whom they
    }    
    set nick ""
    
    switch -- $whom {
	me - you {
	    set nick [::Jabber::JlibCmd service nick $from]	    
	}
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
    set state(last,$whom) [clock clicks -milliseconds]
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
    if {$nick ne ""} {
	append prefix "<$nick>"
    }
    
    $wtext configure -state normal
    $wtext insert end $prefix ${whom}pre
    
    ::Text::ParseMsg groupchat $from $wtext "  $body" ${whom}text
    $wtext insert end \n
    
    $wtext configure -state disabled
    $wtext see end

    # History.
    set dateISO [clock format $secs -format "%Y%m%dT%H:%M:%S"]
    ::History::PutToFileEx $roomjid \
      -type groupchat -name $nick -time $dateISO -body $body -tag $whom
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
    
    set result ""
    set token [GetTokenFrom w $wclose]
    if {$token != ""} {
	set w $wclose
	set ans [Exit $token]
	if {$ans == "no"} {
	    set result stop
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
      [mc jasettopic2]  \
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
    set wtextsend $state(wtextsend)
    set roomjid  $state(roomjid)

    # Get text to send. Strip off any ending newlines from Return.
    # There might by smiley icons in the text widget. Parse them to text.
    set allText [::Text::TransformToPureText $wtextsend]
    set allText [string trimright $allText]
    if {$allText != ""} {	
	::Jabber::JlibCmd send_message $roomjid -type groupchat -body $allText
    }
    
    # Clear send.
    $wtextsend delete 1.0 end
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
    return
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
    set istrpt [::Roster::IsTransport $service]
    
    # @@@ BAD heuristics!
    set isinvite 0
    if {$istrpt && !$inroom && $isconf && ($presence eq "available")} {
	set isinvite 1
    }
    ::Debug 4 "\t conferences=$conferences"
    ::Debug 4 "\t allroomsin=$allroomsin"
    ::Debug 4 "\t inroom=$inroom, isconf=$isconf, isroom=$isroom, istrpt=$istrpt"
    
    if {$isinvite} {
	
	# This seems to be a kind of invitation for a groupchat.
	set str [mc jamessgcinvite $jid2 $argsArr(-from)]
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
	
	# This should only be called if not the room does it.
	set token [GetTokenFrom roomjid $jid2]
	if {$token ne ""} {
	    set cmd [concat \
	      [list ::GroupChat::InsertPresenceChange $token $presence $jid3] \
	      $args]
	    after 200 $cmd
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

proc ::GroupChat::InsertPresenceChange {token presence jid3 args} {
    variable $token
    upvar 0 $token state
    variable show2String
    
    array set argsArr $args
    
    if {[info exists state(w)] && [winfo exists $state(w)]} {
	
	# Some services send out presence changes automatically.
	set ms [clock clicks -milliseconds]
	if {[expr {$ms - $state(last,sys) < 400}]} {
	    return
	}
	set nick [::Jabber::JlibCmd service nick $jid3]	
	set show $presence
	if {[info exists argsArr(-show)]} {
	    set show $argsArr(-show)
	}
	InsertMessage $token $state(roomjid) "${nick}: $show2String($show)"
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
    
    set presenceList [$jstate(roster) getpresence $roomjid -type available]
    foreach pres $presenceList {
	unset -nocomplain presArr
	array set presArr $pres
	
	set res $presArr(-resource)
	if {$res != ""} {
	    set jid3 $roomjid/$res
	    eval {SetUser $roomjid $jid3 $presArr(-type)} $pres
	}
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
    if {$token eq ""} {
	set token [eval {Build $roomjid} $args]
    }       
    variable $token
    upvar 0 $token state
    
    # Get the hex string to use as tag. 
    # In old-style groupchat this is the nick name which should be unique
    # within this room aswell.
    jlib::splitjid $jid3 jid2 resource
    
    # If we got a browse push with a <user>, assume is available.
    if {$presence eq ""} {
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
    
    set wusers $state(wusers)
    
    # Old-style groupchat and browser compatibility layer.
    set nick [$jstate(jlib) service nick $jid3]
    set icon [eval {::Roster::GetPresenceIcon $jid3 $presence} $args]
            
    # Cover both a "flat" users list and muc's with the roles 
    # moderator, participant, and visitor.
    set role [GetRoleFromJid $jid3]
    if {$role eq ""} {
	set v $jid3
    } else {
	if {![$wusers isitem $role]} {
	    $wusers newitem $role -text $userRoleToStr($role) -dir 1 \
	      -sortcommand {lsort -dictionary}
	    if {[string equal $role "moderator"]} {
		$wusers raiseitem $role
	    }
	}
	set v [list $role $jid3]
    }
    if {[$wusers isitem $v]} {
	$wusers itemconfigure $v -text $nick -image $icon
    } else {
	set state(ignore,$jid3) 0
	$wusers newitem $v -text $nick -image $icon -tags [list $jid3]
    }
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

proc ::GroupChat::Popup {token w v x y} {
    global  wDlgs this
    
    variable popMenuDefs
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::GroupChat::Popup w=$w, v='$v', x=$x, y=$y"
    
    # The last element of $v is either a jid, (a namespace,) 
    # a header in roster, a group, or an agents xml tag.
    # The variables name 'jid' is a misnomer.
    # Find also type of thing clicked, 'clicked'.
    
    set clicked ""
    
    set jid [lindex $v end]
    set jid3 $jid
    if {[regexp {^[^@]+@[^@]+(/.*)?$} $jid match res]} {
	set clicked user
    }
    if {$jid == ""} {
	set clicked ""	
    }    
    ::Debug 2 "\t jid=$jid, clicked=$clicked"
    
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
    
    BuildMenu $token $m $popMenuDefs(groupchat,def) $jid3 $clicked
    
    # This one is needed on the mac so the menu is built before it is posted.
    update idletasks
    
    # Post popup menu.
    set X [expr [winfo rootx $w] + $x]
    set Y [expr [winfo rooty $w] + $y]
    tk_popup $m [expr int($X) - 10] [expr int($Y) - 10]   
}

proc ::GroupChat::BuildMenu {token m menuDef jid3 clicked} {
    
    set jid $jid3
    set i 0

    foreach {op item type cmd opts} $menuDef {	
	set locname [mc $item]
	set opts [subst $opts]
	puts "$op $item $type $opts"

	switch -- $op {
	    command {
    
		# Substitute the jid arguments. Preserve list structure!
		set cmd [eval list $cmd]
		eval {$m add command -label $locname -command [list after 40 $cmd]  \
		  -state disabled} $opts
	    }
	    radio {
		set cmd [eval list $cmd]
		eval {$m add radiobutton -label $locname -command [list after 40 $cmd]  \
		  -state disabled} $opts
	    }
	    check {
		set cmd [eval list $cmd]
		eval {$m add checkbutton -label $locname -command [list after 40 $cmd]  \
		  -state disabled} $opts
	    }
	    separator {
		$m add separator
		continue
	    }
	    cascade {
		set mt [menu $m.sub$i -tearoff 0]
		eval {$m add cascade -label $locname -menu $mt -state disabled} $opts
		BuildMenu $mt $cmd $jid3 $clicked $status $group
		incr i
	    }
	}
	if {![::Jabber::IsConnected] && ([lsearch $type always] < 0)} {
	    continue
	}
	
	# State of menu entry. 
	# We use the 'type' and 'clicked' lists to set the state.
	if {[listintersectnonempty $type $clicked]} {
	    set state normal
	} elseif {$type eq ""} {
	    set state normal
	} else {
	    set state disabled
	}
	if {[string equal $state "normal"]} {
	    $m entryconfigure $locname -state normal
	}
    }
}

proc ::GroupChat::Ignore {token jid3} {
    variable $token
    upvar 0 $token state
    
    if {$state(ignore,$jid3)} {
	set fg [option get $state(w) userIgnore {}]
    } else {
	set fg [option get $state(w) userForeground {}]
    }
    puts "::GroupChat::Ignore jid3=$jid3, fg=$fg"
    set wusers $state(wusers)
    set items [$wusers find withtag $jid3]
    puts "wusers=$wusers, items=$items"
    foreach item $items {
	$wusers itemconfigure $item -foreground $fg
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
    unset -nocomplain state(ignore,$jid3)
}

proc ::GroupChat::BuildHistory {token} {
    variable $token
    upvar 0 $token state

    ::History::BuildHistory $state(roomjid) groupchat -class GroupChat  \
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
	foreach {myroomjid mynick}  \
	  [::Jabber::JlibCmd service hashandnick $roomjid] break
	set fd [open $ans w]
	fconfigure $fd -encoding utf-8
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
    
    set ans "yes"
    if {[::Jabber::IsConnected]} {
	if {0} {
	    set ans [eval {::UI::MessageBox -icon warning -type yesno  \
	      -message [mc jamesswarnexitroom $roomjid]} $opts]
	}
	if {$ans == "yes"} {
	    Close $token
	    $jstate(jlib) service exitroom $roomjid
	    ::hooks::run groupchatExitRoomHook $roomjid
	}
    } else {
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
	::UI::SaveSashPos groupchatDlgVert $state(wpanev)
	::UI::SaveSashPos groupchatDlgHori $state(wpaneh)
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

	::UI::SaveSashPos groupchatDlgVert $state(wpanev)
	::UI::SaveSashPos groupchatDlgHori $state(wpaneh)
    }
}

# Prefs page ...................................................................

proc ::GroupChat::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    
    # Defaults...    
    # Preferred groupchat protocol (gc-1.0|muc).
    # 'muc' uses 'conference' as fallback.
    set jprefs(prefgchatproto) "muc"
    set jprefs(defnick)        ""
	
    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(prefgchatproto)   jprefs_prefgchatproto    $jprefs(prefgchatproto)]  \
      [list ::Jabber::jprefs(defnick)          jprefs_defnick           $jprefs(defnick)]  \
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
    
    set tmpJPrefs(prefgchatproto) $jprefs(prefgchatproto)
    set tmpJPrefs(defnick)        $jprefs(defnick)
    
    # Conference (groupchat) stuff.
    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    set wpp $wc.fr
    ttk::labelframe $wpp -text [mc {Preferred Protocol}] \
      -padding [option get . groupSmallPadding {}]
    pack  $wpp  -side top -anchor w
    
    foreach  \
      val { gc-1.0                     muc }         \
      txt { {Groupchat-1.0 (fallback)} prefmucconf } {
	set wrad $wpp.[string map {. ""} $val]
	ttk::radiobutton $wrad -text [mc $txt] -value $val  \
	  -variable [namespace current]::tmpJPrefs(prefgchatproto)	      
	grid $wrad -sticky w
    }
    
    set wnick $wc.n
    ttk::frame $wnick
    ttk::label $wnick.l -text "Default nickname:"
    ttk::entry $wnick.e \
      -textvariable [namespace current]::tmpJPrefs(defnick)
    pack $wnick.l $wnick.e -side left
    pack $wnick -side top -anchor w -pady 8
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
