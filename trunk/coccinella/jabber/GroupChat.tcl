#  GroupChat.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the group chat GUI part.
#      
#  Copyright (c) 2001-2005  Mats Bengtsson
#  
# $Id: GroupChat.tcl,v 1.135 2006-03-15 13:56:49 matben Exp $

package require Enter
package require History
package require Bookmarks
package require colorutils

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
    ::hooks::register setPresenceHook         ::GroupChat::StatusSyncHook
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
    option add *GroupChat*Text.borderWidth     0               50
    option add *GroupChat*Text.relief          flat            50
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
    
    # Keep track of if we have made autojoin when getting bookmarks.
    variable autojoinDone 0

    variable popMenuDefs
    set popMenuDefs(groupchat,def) {
	{command   mMessage       {::NewMsg::Build -to $jid}    }
	{command   mChat          {::Chat::StartThread $jid}    }
	{command   mSendFile      {::FTrans::Send $jid}         }
	{command   mUserInfo      {::UserInfo::Get $jid}        }
	{command   mWhiteboard    {::Jabber::WB::NewWhiteboardTo $jid} }
	{check     mIgnore        {::GroupChat::Ignore $token $jid} {
	    -variable $token\(ignore,$jid)
	}}
    }
    set popMenuDefs(groupchat,type) {
	{mMessage       user        }
	{mChat          user        }
	{mSendFile      user        }
	{mUserInfo      user        }
	{mWhiteboard    wb          }
	{mIgnore        user        }
    }

    # Keeps track of all registered menu entries.
    variable regPopMenuDef {}
    variable regPopMenuType {}

    variable userRoleToStr
    set userRoleToStr(moderator)   [mc Moderators]
    set userRoleToStr(none)        [mc None]
    set userRoleToStr(participant) [mc Participants]
    set userRoleToStr(visitor)     [mc Visitors]
    
    variable userRoleSortOrder
    array set userRoleSortOrder {
	moderator   0
	participant 1
	visitor     2
	none        3
    }
    
    variable show2String
    set show2String(available)   [mc available]
    set show2String(away)        [mc away]
    set show2String(chat)        [mc chat]
    set show2String(dnd)         [mc {do not disturb}]
    set show2String(xa)          [mc {extended away}]
    set show2String(invisible)   [mc invisible]
    set show2String(unavailable) [mc {not available}]

    # @@@ Should get this from a global reaource.
    variable buttonPressMillis 1000
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
    if {$service eq ""} {
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
    upvar ::Jabber::xmppxmlns xmppxmlns

    set ans 0
    if {$jid eq ""} {
	set allConfServ [$jstate(jlib) service getconferences]
	foreach serv $allConfServ {
	    if {[$jstate(jlib) service hasfeature $serv $xmppxmlns(muc)]} {
		set ans 1
	    }
	}
    } else {
	
	# We must query the service, not the room, for browse to work.
	jlib::splitjidex $jid node service -
	if {$service ne ""} {
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
    upvar ::Jabber::jprefs jprefs

    ::Debug 2 "::GroupChat::EnterOrCreate what=$what, args='$args'"
    
    set service  ""
    set ans      "cancel"
    
    array set argsArr $args
    if {[info exists argsArr(-roomjid)]} {
	set roomjid $argsArr(-roomjid)
	jlib::splitjidex $roomjid node service -
    } elseif {[info exists argsArr(-server)]} {
	set service $argsArr(-server)
    }

    if {[info exists argsArr(-protocol)]} {
	set protocol $argsArr(-protocol)
    } else {
	
	# Preferred groupchat protocol (gc-1.0|muc).
	# Consistency checking.
	if {![regexp {(gc-1.0|muc)} $jprefs(prefgchatproto)]} {
	    set jprefs(prefgchatproto) "muc"
	}
	set protocol $jprefs(prefgchatproto)
	if {$service ne ""} {
	    if {($protocol eq "muc") && ![HaveMUC $service]} {
		set protocol "gc-1.0"
	    }
	}
    }
    
    ::Debug 2 "\t protocol=$protocol"
    
    switch -glob -- $what,$protocol {
	enter,* {
	    set ans [eval {::Enter::Build $protocol} $args]
	}
	create,gc-1.0 {
	    set ans [eval {BuildEnter} $args]
	}
	create,muc {
	    # @@@ This should go in a new place...
	    set ans [eval {::Conference::BuildCreate} $args]
	}
	xxxxx {
	    ##### OUTDATED #####
	}
	*,gc-1.0 {
	    set ans [eval {BuildEnter} $args]
	}
	OUTDATED-enter,conference {
	    set ans [eval {::Conference::BuildEnter} $args]
	}
	OUTDATED-create,conference {
	    set ans [eval {::Conference::BuildCreate} $args]
	}
	enter,muc {
	    set ans [eval {::Enter::Build $protocol} $args]
	}
	enter,* {
	    
	    # This is typically a service on a nondiscovered server.
	    set ans [eval {::Enter::Build $protocol} $args]
	}	    
	default {
	    ::ui::dialog -icon error -message [mc jamessnogroupchat]
	}
    }    
    
    # @@@ BAD only used in JWB.
    return $ans
}

proc ::GroupChat::EnterHook {roomjid protocol} {
    
    ::Debug 2 "::GroupChat::EnterHook roomjid=$roomjid $protocol"
    
    SetProtocol $roomjid $protocol
    
    # If we are using the 'conference' protocol we must browse
    # the room to get the participants.
    if {$protocol eq "conference"} {
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
    if {$token eq ""} {
	return
    }
    variable $token
    upvar 0 $token state
    
    if {$inprotocol eq "muc"} {
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
#       args        -server, -roomjid, -nickname
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
    
    if {0 && $chatservers == {}} {
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
    if {($enter(server) eq "") || ($enter(roomname) eq "") ||  \
      ($enter(nickname) eq "")} {
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
    if {$token eq ""} {
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
    set state(afterids)         {}
    
    set ancient [expr {[clock clicks -milliseconds] - 1000000}]
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
    set wusers      $wfrusers.tree
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
    
    set wgroup    $wbot.grp
    set wbtstatus $wgroup.stat
    set wbtbmark  $wgroup.bmark

    ttk::frame $wgroup
    ttk::checkbutton $wgroup.active -style Toolbutton \
      -image [::Theme::GetImage return]               \
      -command [list [namespace current]::ActiveCmd $token] \
      -variable $token\(active)
    ttk::button $wgroup.bmark -style Toolbutton  \
      -image [::Theme::GetImage bookmarkAdd]     \
      -command [list [namespace current]::BookmarkRoom $token]

    ::Jabber::Status::Button $wgroup.stat \
      $token\(status) -command [list [namespace current]::StatusCmd $token] 
    ::Jabber::Status::ConfigImage $wgroup.stat available
    ::Emoticons::MenuButton $wgroup.smile -text $wtextsend
    
    grid  $wgroup.active  $wgroup.bmark  $wgroup.stat  $wgroup.smile  \
      -padx 1 -sticky news
    foreach c {0 1} {
	grid columnconfigure $wgroup $c -uniform bt -weight 1
    }
    foreach c {2 3} {
	grid columnconfigure $wgroup $c -uniform mb -weight 1
    }
    
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $wbot.btok  -side right
	pack $wbot.btcancel -side right -padx $padx
    } else {
	pack $wbot.btcancel -side right
	pack $wbot.btok -side right -padx $padx
    }
    pack  $wgroup -side left
    pack  $wbot   -side bottom -fill x
        
    set wbtsend   $wbot.btok

    ::balloonhelp::balloonforwindow $wgroup.active [mc jaactiveret]
    ::balloonhelp::balloonforwindow $wgroup.bmark  [mc {Bookmark this room}]

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

    if {!( [info exists protocol($roomjid)] && ($protocol($roomjid) eq "muc") )} {
	$wbtnick state {disabled}
	$wtray buttonconfigure invite -state disabled
	$wtray buttonconfigure info   -state disabled
    }
    
    # Main frame for panes.
    frame $wmid -height 250 -width 300
    pack  $wmid -side top -fill both -expand 1

    # Pane geometry manager.
    ttk::paned $wpanev -orient vertical
    pack $wpanev -side top -fill both -expand 1    

    # Text send.
    frame $wfrsend -height 100 -width 300 -bd 1 -relief sunken
    text  $wtextsend -height 4 -width 1 -font CociSmallFont -wrap word \
      -yscrollcommand [list ::UI::ScrollSet $wyscsend \
      [list grid $wyscsend -column 1 -row 0 -sticky ns]]
    ttk::scrollbar $wyscsend -orient vertical -command [list $wtextsend yview]

    grid  $wtextsend  -column 0 -row 0 -sticky news
    grid  $wyscsend   -column 1 -row 0 -sticky ns
    grid columnconfigure $wfrsend 0 -weight 1
    grid rowconfigure    $wfrsend 0 -weight 1
    
    # Pane for chat and users list.
    ttk::paned $wpaneh -orient horizontal
    $wpanev add $wpaneh -weight 1
    $wpanev add $wfrsend -weight 1
    
    # Chat text widget.
    frame $wfrchat -bd 1 -relief sunken
    text  $wtext -height 12 -width 40 -font CociSmallFont -state disabled  \
      -wrap word -cursor {}  \
      -yscrollcommand [list ::UI::ScrollSet $wysc \
      [list grid $wysc -column 1 -row 0 -sticky ns -padx 2]]
    ttk::scrollbar $wysc -orient vertical -command [list $wtext yview]
 
    grid  $wtext  -column 0 -row 0 -sticky news
    grid  $wysc   -column 1 -row 0 -sticky ns -padx 2
    grid columnconfigure $wfrchat 0 -weight 1
    grid rowconfigure    $wfrchat 0 -weight 1
    
    # Users list.
    frame $wfrusers -bd 1 -relief sunken
    ttk::scrollbar $wyscusers -orient vertical -command [list $wusers yview]
    Tree $token $w $wusers $wyscusers

    grid  $wusers     -column 0 -row 0 -sticky news
    grid  $wyscusers  -column 1 -row 0 -sticky ns -padx 2
    grid columnconfigure $wfrusers 0 -weight 1
    grid rowconfigure    $wfrusers 0 -weight 1
    
    $wpaneh add $wfrchat  -weight 1
    $wpaneh add $wfrusers -weight 1
    
    # The tags.
    ConfigureTextTags $w $wtext
        
    set state(wtray)      $wtray
    set state(wbtnick)    $wbtnick
    set state(wbtsubject) $wbtsubject
    set state(wbtstatus)  $wbtstatus
    set state(wbtbmark)   $wbtbmark
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
    set tag TopTag$w
    bindtags $w [concat $tag [bindtags $w]]
    bind $tag <Destroy> [list ::GroupChat::OnDestroy $token]
    
    return $token
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
#   Functions to handle the treectrl widget.
#   It isolates some details to the rest of the code.
#   
#   An invisible column stores tags for each item:
#       {role $role}
#           {jid $jid}
#           {jid $jid}
#           ...

namespace eval ::GroupChat {

    variable initedTreeDB 0
}

proc ::GroupChat::TreeInitDB { } {
    global  this
    variable initedTreeDB
    
    # Use option database for customization. 
    # We use a specific format: 
    #   element options:    prefix:elementName-option
    #   style options:      prefix:styleName:elementName-option

    set fillT {
	white {selected focus !ignore} 
	black {selected !focus !ignore} 
	red   {ignore}
    }
    set fillB [list $this(sysHighlight) {selected focus} gray {selected !focus}]
    
    # Element options:
    option add *GroupChat.utree:eText-font         CociSmallFont           widgetDefault
    option add *GroupChat.utree:eText-fill         $fillT                  widgetDefault
    option add *GroupChat.utree:eRoleText-font     CociSmallBoldFont       widgetDefault
    option add *GroupChat.utree:eRoleText-fill     $fillT                  widgetDefault
    option add *GroupChat.utree:eBorder-fill       $fillB                  widgetDefault

    
    # Style layout options:
    option add *GroupChat.utree:styUser:eText-padx       2                 widgetDefault
    option add *GroupChat.utree:styUser:eText-pady       2                 widgetDefault
    option add *GroupChat.utree:styUser:eImage-padx      2                 widgetDefault
    option add *GroupChat.utree:styUser:eImage-pady      2                 widgetDefault

    option add *GroupChat.utree:styRole:eRoleText-padx       2             widgetDefault
    option add *GroupChat.utree:styRole:eRoleText-pady       2             widgetDefault
    option add *GroupChat.utree:styRole:eRoleImage-padx      2             widgetDefault
    option add *GroupChat.utree:styRole:eRoleImage-pady      2             widgetDefault

    set initedTreeDB 1
}

proc ::GroupChat::Tree {token w T wysc} {
    global this
    variable initedTreeDB

    if {!$initedTreeDB} {
	TreeInitDB
    }
    
    treectrl $T -usetheme 1 -selectmode extended  \
      -showroot 0 -showrootbutton 0 -showbuttons 0 -showheader 0  \
      -yscrollcommand [list ::UI::ScrollSet $wysc     \
      [list grid $wysc -row 0 -column 1 -sticky ns]]  \
      -borderwidth 0 -highlightthickness 0            \
      -height 0 -width 20

    # State for ignore.
    $T state define ignore
    
    # The columns.
    $T column create -tag cTree -resize 0 -expand 1
    $T column create -tag cTag  -visible 0
    
    # The elements.
    $T element create eImage       image
    $T element create eText        text
    $T element create eRoleImage   image
    $T element create eRoleText    text
    $T element create eBorder      rect  -open new -showfocus 1

    # Styles collecting the elements.
    set S [$T style create styUser]
    $T style elements $S {eBorder eImage eText}
    $T style layout $S eImage  -expand ns
    $T style layout $S eText   -squeeze x -expand ns
    $T style layout $S eBorder -detach 1 -iexpand xy

    set S [$T style create styRole]
    $T style elements $S {eBorder eRoleImage eRoleText}
    $T style layout $S eRoleImage -expand ns
    $T style layout $S eRoleText  -squeeze x -expand ns
    $T style layout $S eBorder    -detach 1 -iexpand xy

    set S [$T style create styTag]
    $T style elements $S {eText}

    $T configure -defaultstyle {{} styTag}

    # This automatically cleans up the tag array.
    $T notify bind UsersTreeTag <ItemDelete> {
	foreach item %i {
	    ::GroupChat::TreeUnsetTags %T $item
	} 
    }
    bindtags $T [concat UsersTreeTag [bindtags $T]]
    
    bind UsersTreeTag <Button-1>        { ::GroupChat::TreeButtonPress %W %x %y }        
    bind UsersTreeTag <ButtonRelease-1> { ::GroupChat::TreeButtonRelease %W %x %y }        
    bind UsersTreeTag <<ButtonPopup>>   [list ::GroupChat::TreePopup $token %W %x %y ]
    bind UsersTreeTag <Double-1>        { ::GroupChat::DoubleClick %W %x %y }        
    bind UsersTreeTag <Destroy>         {+::GroupChat::TreeOnDestroy %W }
    
    ::treeutil::setdboptions $T $w utree
}

proc ::GroupChat::TreeButtonPress {T x y} {
    variable buttonAfterId
    variable buttonPressMillis

    if {[tk windowingsystem] eq "aqua"} {
	if {[info exists buttonAfterId]} {
	    catch {after cancel $buttonAfterId}
	}
	set cmd [list ::GroupChat::TreePopup $T $x $y]
	set buttonAfterId [after $buttonPressMillis $cmd]
    }
}

proc ::GroupChat::TreeButtonRelease {T x y} {
    variable buttonAfterId
    
    if {[info exists buttonAfterId]} {
	catch {after cancel $buttonAfterId}
	unset buttonAfterId
    }    
}

proc ::GroupChat::TreePopup {token T x y} {
    variable tag2item

    set id [$T identify $x $y]
    if {[lindex $id 0] eq "item"} {
	set item [lindex $id 1]
	set tag [$T item element cget $item cTag eText -text]
    } else {
	set tag {}
    }
    Popup $token $T $tag $x $y
}

proc ::GroupChat::DoubleClick {T x y} {
    upvar ::Jabber::jprefs jprefs

    set id [$T identify $x $y]
    if {([lindex $id 0] eq "item") && ([llength $id] == 6)} {
	set item [lindex $id 1]
	set tags [$T item element cget $item cTag eText -text]
	if {[lindex $tags 0] eq "jid"} {
	    set jid [lindex $tags 1]		    
	    if {[string equal $jprefs(rost,dblClk) "normal"]} {
		::NewMsg::Build -to $jid
	    } elseif {[string equal $jprefs(rost,dblClk) "chat"]} {
		::Chat::StartThread $jid
	    }
	}
    }   
}

proc ::GroupChat::TreeOnDestroy {T} {
    variable tag2item
    
    array unset tag2item $T,*
}

proc ::GroupChat::TreeCreateUserItem {token jid3 presence args} {
    variable $token
    upvar 0 $token state
    variable userRoleToStr
    upvar ::Jabber::jstate jstate
    
    set T $state(wusers)
    
    # Cover both a "flat" users list and muc's with the roles 
    # moderator, participant, and visitor.
    set role [GetRoleFromJid $jid3]
    if {$role eq ""} {
	set pitem root
    } else {
	set ptag [list role $role]
	set pitem [TreeFindWithTag $T $ptag]
	if {$pitem eq ""} {
	    set pitem [TreeCreateWithTag $T $ptag root]
	    set text $userRoleToStr($role)
	    $T item style set $pitem cTree styRole
	    $T item element configure $pitem cTree eRoleText -text $text
	    $T item sort root -command [list ::GroupChat::TreeSortRoleCmd $T]
	}
    }
    set tag [list jid $jid3]
    set item [TreeFindWithTag $T $tag]
    if {$item eq ""} {
	set item [TreeCreateWithTag $T $tag $pitem]
	$T item style set $item cTree styUser
    }
    set text [$jstate(jlib) service nick $jid3]
    set image [eval {::Roster::GetPresenceIcon $jid3 $presence} $args]
    $T item element configure $item cTree  \
      eText -text $text + eImage -image $image
}

proc ::GroupChat::TreeSortRoleCmd {T item1 item2} {
    variable userRoleSortOrder

    set tag1 [$T item element cget $item1 cTag eText -text]
    set tag2 [$T item element cget $item2 cTag eText -text]
    if {([lindex $tag1 0] eq "role") && ([lindex $tag2 0] eq "role")} {
	set role1 [lindex $tag1 1]
	set role2 [lindex $tag2 1]
	if {$userRoleSortOrder($role1) < $userRoleSortOrder($role2)} {
	    return -1
	} elseif {$userRoleSortOrder($role1) > $userRoleSortOrder($role2)} {
	    return 1
	} else {
	    return 0
	}
    } else {
	return 0
    }
}

proc ::GroupChat::TreeCreateWithTag {T tag parent} {
    variable tag2item
    
    set item [$T item create -parent $parent]
    
    # Handle the hidden cTag column.
    $T item style set $item cTag styTag
    $T item element configure $item cTag eText -text $tag
    
    set tag2item($T,$tag) $item

    return $item
}

proc ::GroupChat::TreeFindWithTag {T tag} {
    variable tag2item
    
    if {[info exists tag2item($T,$tag)]} {
	return $tag2item($T,$tag)
    } else {
	return {}
    }
}

proc ::GroupChat::TreeSetIgnoreState {T jid3 {prefix ""}} {
    variable tag2item
    
    set tag [list jid $jid3]
    if {[info exists tag2item($T,$tag)]} {
	set item $tag2item($T,$tag)
	$T item state set $item ${prefix}ignore
    }
}

proc ::GroupChat::TreeRemoveUser {token jid3} {
    variable $token
    upvar 0 $token state
    
    set T $state(wusers)
    set tag [list jid $jid3]
    TreeDeleteItem $T $tag

    unset -nocomplain state(ignore,$jid3)
}

proc ::GroupChat::TreeDeleteItem {T tag} {
    variable tag2item
    
    if {[info exists tag2item($T,$tag)]} {
	set item $tag2item($T,$tag)
	$T item delete $item
    }    
}

proc ::GroupChat::TreeUnsetTags {T item} {
    variable tag2item

    set tag [$T item element cget $item cTag eText -text]
    unset -nocomplain tag2item($T,$tag)    
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

proc ::GroupChat::StatusCmd {token status} {
    variable $token
    upvar 0 $token state

    ::Debug 2 "::GroupChat::StatusCmd status=$status"

    if {$status eq "unavailable"} {
	set ans [Exit $token]
	if {$ans eq "no"} {
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
	me - they {
	    set nick [::Jabber::JlibCmd service nick $from]	    
	}
    }
    set history 0
    set secs ""
    if {[info exists argsArr(-x)]} {
	set tm [::Jabber::GetAnyDelayElem $argsArr(-x)]
	if {$tm ne ""} {
	    set secs [clock scan $tm -gmt 1]
	    set history 1
	}
    }
    if {$secs eq ""} {
	set secs [clock seconds]
    }
    set state(last,$whom) [clock clicks -milliseconds]
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
    if {$nick ne ""} {
	append prefix "<$nick>"
    }
    set htag ""
    if {$history} {
	set htag -history
    }
    
    $wtext configure -state normal
    $wtext insert end $prefix ${whom}pre${htag}
    
    ::Text::ParseMsg groupchat $from $wtext "  $body" ${whom}text${htag}
    $wtext insert end \n
    
    $wtext configure -state disabled
    $wtext see end

    # History.
    set dateISO [clock format $secs -format "%Y%m%dT%H:%M:%S"]
    ::History::PutToFileEx $roomjid \
      -type groupchat -name $nick -time $dateISO -body $body -tag $whom
}

proc ::GroupChat::SetState {token _state} {
    variable $token
    upvar 0 $token state

    $state(wtray) buttonconfigure send   -state $_state
    $state(wtray) buttonconfigure invite -state $_state
    $state(wtray) buttonconfigure info   -state $_state
    $state(wbtsubject) configure -state $_state
    $state(wbtsend)    configure -state $_state
    $state(wbtstatus)  configure -state $_state
    $state(wbtbmark)   configure -state $_state
}

proc ::GroupChat::CloseHook {wclose} {
    
    set result ""
    set token [GetTokenFrom w $wclose]
    if {$token ne ""} {
	set w $wclose
	set ans [Exit $token]
	if {$ans eq "no"} {
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
    set foreground [$wtext cget -foreground]
    foreach tag $alltags {
	set opts($tag) [list -spacing1 $space -foreground $foreground]
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
    
    # History tags.
    foreach tag $alltags {
	set htag ${tag}-history
	array unset arr
	array set arr $opts($tag)
	set arr(-foreground) [::colorutils::getlighter $arr(-foreground)]
	eval {$wtext tag configure $htag} [array get arr]
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

    if {($ans eq "ok") && ($topic ne "")} {
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
    if {$allText ne ""} {	
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
    set tvars [concat  \
      [info vars ${ns}::\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]\[0-9\]\[0-9\]\[0-9\]]]

    # We need to check array size becaus also empty arrays are reported.
    set tokens {}
    foreach token $tvars {
	if {[array size $token]} {
	    lappend tokens $token
	}
    }
    return $tokens
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

# @@@ Much better to register for presence info for room only.
#     Register for room jid and any member.
#     Register directly with jabberlib somehow and not via application hooks.

proc ::GroupChat::PresenceHook {jid presence args} {
    
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::GroupChat::PresenceHook jid=$jid, presence=$presence, args='$args'"
    
    array set argsArr $args
    set jid2 $jid
    set jid3 $jid
    if {[info exists argsArr(-resource)]} {
	set jid3 $jid2/$argsArr(-resource)
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
    
    # @@@ This one just gives us problems:
    # RECV: <presence from='msn.jabber.dk' to='matben@jabber.dk'/>
    if {0 && $isinvite} {
	
	# This seems to be a kind of invitation for a groupchat.
	set str [mc jamessgcinvite $jid2 $argsArr(-from)]
	set ans [::UI::MessageBox -icon info -type yesno -message $str]
	if {$ans eq "yes"} {
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
	
	set token [GetTokenFrom roomjid $jid2]
	if {$token ne ""} {
	    set cmd [concat \
	      [list ::GroupChat::InsertPresenceChange $token $presence $jid3] \
	      $args]
	    lappend state(afterids) [after 200 $cmd]
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
	# This should only be called if not the room does it.
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
	if {$res ne ""} {
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
        
    # If we got a browse push with a <user>, assume is available.
    if {$presence eq ""} {
	set presence available
    }    
    
    # Don't forget to init the ignore state.
    if {![info exists state(ignore,$jid3)]} {
	set state(ignore,$jid3) 0
    }
    eval {TreeCreateUserItem $token $jid3 $presence} $args
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
    
# GroupChat::RegisterPopupEntry --
# 
#       Components or plugins can add their own menu entries here.

proc ::GroupChat::RegisterPopupEntry {menuDef menuType} {
    variable regPopMenuDef
    variable regPopMenuType
    
    set regPopMenuDef  [concat $regPopMenuDef $menuDef]
    set regPopMenuType [concat $regPopMenuType $menuType]
}

proc ::Disco::UnRegisterPopupEntry {name} {
    variable regPopMenuDef
    variable regPopMenuType
    
    set idx [lsearch -glob $regPopMenuDef "* $name *"]
    if {$idx >= 0} {
	set regPopMenuDef [lreplace $regPopMenuDef $idx $idx]
    }
    set idx [lsearch -glob $regPopMenuType "$name *"]
    if {$idx >= 0} {
	set regPopMenuType [lreplace $regPopMenuType $idx $idx]
    }
}

# GroupChat::Popup --
#
#       Handle popup menu in groupchat dialog.
#       
# Arguments:
#       w           widgetPath of treectrl
#       
# Results:
#       popup menu displayed

proc ::GroupChat::Popup {token w tag x y} {
    global  wDlgs this
    
    variable popMenuDefs
    variable regPopMenuDef
    variable regPopMenuType
    upvar ::Jabber::jstate jstate
            
    set clicked ""
    set jid ""
    if {[lindex $tag 0] eq "role"} {
	set clicked role
    } elseif {[lindex $tag 0] eq "jid"} {
	set clicked user
	set jid [lindex $tag 1]
    }

    ::Debug 2 "\t jid=$jid, clicked=$clicked"
        
    # Insert any registered popup menu entries.
    set mDef  $popMenuDefs(groupchat,def)
    set mType $popMenuDefs(groupchat,type)
    if {[llength $regPopMenuDef]} {
	set idx [lindex [lsearch -glob -all $mDef {sep*}] end]
	if {$idx eq ""} {
	    set idx end
	}
	foreach line $regPopMenuDef {
	    set mDef [linsert $mDef $idx $line]
	}
	set mDef [linsert $mDef $idx {separator}]
    }
    foreach line $regPopMenuType {
	lappend mType $line
    }

    # Make the appropriate menu.
    set m $jstate(wpopup,groupchat)
    catch {destroy $m}
    menu $m -tearoff 0  \
      -postcommand [list ::GroupChat::PostMenuCmd $m $mType $clicked]
    
    ::AMenu::Build $m $mDef -varlist [list jid $jid token $token]
    
    # This one is needed on the mac so the menu is built before it is posted.
    update idletasks
    
    # Post popup menu.
    set X [expr [winfo rootx $w] + $x]
    set Y [expr [winfo rooty $w] + $y]
    tk_popup $m [expr int($X) - 10] [expr int($Y) - 10]   
}

proc ::GroupChat::PostMenuCmd {m mType clicked} {
    
    set online [::Jabber::IsConnected]
    ::hooks::run groupchatUserPostCommandHook $m $clicked  
    
    foreach mspec $mType {
	lassign $mspec name type subType
	
	# State of menu entry. 
	# We use the 'type' and 'clicked' lists to set the state.
	if {$type eq "normal"} {
	    set state normal
	} elseif {$online} {
	    if {[listintersectnonempty $type $clicked]} {
		set state normal
	    } elseif {$type eq ""} {
		set state normal
	    } else {
		set state disabled
	    }
	} else {
	    set state disabled
	}
	set midx [::AMenu::GetMenuIndex $m $name]
	if {[string equal $state "disabled"]} {
	    $m entryconfigure $midx -state disabled
	}
	if {[llength $subType]} {
	    set mt [$m entrycget $midx -menu]
	    PostMenuCmd $mt $subType $clicked
	}
    }
}

proc ::GroupChat::Ignore {token jid3} {
    variable $token
    upvar 0 $token state
    
    set T $state(wusers)
    if {$state(ignore,$jid3)} {
	TreeSetIgnoreState $T $jid3
    } else {
	TreeSetIgnoreState $T $jid3 !
    }
}

proc ::GroupChat::RemoveUser {roomjid jid3} {

    ::Debug 4 "::GroupChat::RemoveUser roomjid=$roomjid, jid3=$jid3"
    
    set roomjid [jlib::jidmap $roomjid]
    set token [GetTokenFrom roomjid $roomjid]
    if {$token ne ""} {
	TreeRemoveUser $token $jid3
    }
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

proc ::GroupChat::StatusSyncHook {status args} {
    upvar ::Jabber::jprefs jprefs

    if {$status eq "unavailable"} {
	# This is better handled via the logout hook.
	return
    }
    array set argsArr $args

    if {$jprefs(gchat,syncPres) && ![info exists argsArr(-to)]} {
	foreach token [GetTokenList] {
	    variable $token
	    upvar 0 $token state
	    
	    # Send our status.
	    ::Jabber::SetStatus $status -to $state(roomjid)
	    set state(status)    $status
	    set state(oldStatus) $status
	    #::Jabber::Status::ConfigImage $state(wbtstatus) $status
	}
    }
}

proc ::GroupChat::ExitRoom {roomjid} {

    set roomjid [jlib::jidmap $roomjid]
    set token [GetTokenFrom roomjid $roomjid]
    if {$token ne ""} {
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
	if {$ans eq "yes"} {
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
	Free $token
	destroy $state(w)
    }
    
    # Make sure any associated whiteboard is closed as well.
    # ::hooks::run groupchatExitRoomHook $roomjid
}

proc ::GroupChat::Free {token} {
    variable $token
    upvar 0 $token state
     
    foreach id $state(afterids) {
	after cancel $id
    }
}

# GroupChat::LogoutHook --
#
#       Sets logged out status on all groupchats, that is, disable all buttons.

proc ::GroupChat::LogoutHook { } {    
    variable autojoinDone

    set autojoinDone 0

    foreach token [GetTokenList] {
	variable $token
	upvar 0 $token state

	SetState $token disabled
	::hooks::run groupchatExitRoomHook $state(roomjid)
    }
}

proc ::GroupChat::LoginHook { } {    
    
    foreach token [GetTokenList] {
	variable $token
	upvar 0 $token state

	SetState $token normal
    }
}

proc ::GroupChat::GetFirstPanePos { } {
    global  wDlgs
    
    set win [::UI::GetFirstPrefixedToplevel $wDlgs(jgc)]
    set token [GetTokenFrom w $win]
    if {$token ne ""} {
	variable $token
	upvar 0 $token state

	::UI::SaveSashPos groupchatDlgVert $state(wpanev)
	::UI::SaveSashPos groupchatDlgHori $state(wpaneh)
    }
}

proc ::GroupChat::OnDestroy {token} {

    unset -nocomplain $token
}

# --- Support for JEP-0048 ---
# 
# @@@ Perhaps this should be in a separate file?
# 
#       Note that a user can be connected with multiple resources which
#       means that we cannot rely that the bookmarks are always in sync.
#       We therefore makes some assumptions when they must be obtained:
#         1) login
#         2) when edit them
#         
#       @@@ There is a potential problem if other types of bookmarks (url) 
#           are influenced
# 
# <xs:element name='conference'>
#    <xs:complexType>
#      <xs:sequence>
#        <xs:element name='nick' type='xs:string' minOccurs='0'/>
#        <xs:element name='password' type='xs:string' minOccurs='0'/>
#      </xs:sequence>
#      <xs:attribute name='autojoin' type='xs:boolean' use='optional' default='false'/>
#      <xs:attribute name='jid' type='xs:string' use='required'/>
#      <xs:attribute name='name' type='xs:string' use='required'/>
#    </xs:complexType>
#  </xs:element> 

namespace eval ::GroupChat:: {
    
    # Bookmarks stored as {{name jid ?-nick . -password . -autojoin .?} ...}
    variable bookmarks {}

    ::hooks::register loginHook  ::GroupChat::BookmarkLoginHook
    ::hooks::register logoutHook ::GroupChat::BookmarkLogoutHook
}

proc ::GroupChat::BookmarkLoginHook { } {
    
    BookmarkSendGet [namespace current]::BookmarkExtractFromCB
}

proc ::GroupChat::BookmarkLogoutHook { } {
    variable bookmarks
    
    set bookmarks {}
}

proc ::GroupChat::BookmarkGet { } {
    variable bookmarks
    
    return $bookmarks
}

proc ::GroupChat::BookmarkExtractFromCB {type queryElem args} {

    if {$type eq "result"} {
	BookmarkExtractFromElem $queryElem
	DoAnyAutoJoin
    }
}

proc ::GroupChat::BookmarkExtractFromElem {queryElem} {
    variable bookmarks
    
    set bookmarks {}
    set storageElem  \
      [wrapper::getfirstchild $queryElem "storage" "storage:bookmarks"]
    set confElems [wrapper::getchildswithtag $storageElem "conference"]
    foreach elem $confElems {
	array unset bmarr
	array set bmarr [list name "" jid ""]
	array set bmarr [wrapper::getattrlist $elem]
	set bmark [list $bmarr(name) $bmarr(jid)]
	set nickElem [wrapper::getfirstchildwithtag $elem "nick"]
	if {$nickElem ne ""} {
	    lappend bmark -nick [wrapper::getcdata $nickElem]
	}
	set passElem [wrapper::getfirstchildwithtag $elem "password"]
	if {$passElem ne ""} {
	    lappend bmark -password [wrapper::getcdata $passElem]
	}
	if {[info exists bmarr(autojoin)]} {
	    lappend bmark -autojoin $bmarr(autojoin)
	}
	lappend bookmarks $bmark
    }    
    return $bookmarks
}

# GroupChat::BookmarkRoom --
# 

proc ::GroupChat::BookmarkRoom {token} {
    variable $token
    upvar 0 $token state
    variable bookmarks
    upvar ::Jabber::jstate jstate
    
    set jid $state(roomjid)
    set name [$jstate(jlib) service name $jid]
    if {$name eq ""} {
	set name $jid
    }
    lassign [$jstate(jlib) service hashandnick $jid] myroomjid nick
    
    # Add only if name not there already.
    foreach bmark $bookmarks {
	if {[lindex $bmark 0] eq $name} {
	    return
	}
    }
    lappend bookmarks [list $name $jid -nick $nick]
    
    # We assume here that we already have the complete bookmark list from
    # the login hook.
    BookmarkSendSet
}

# GroupChat::BookmarkSendSet --
# 
#       Store the complete 'bookmarks' state on server.

proc ::GroupChat::BookmarkSendSet { } {
    variable bookmarks
    upvar ::Jabber::jstate jstate
    
    set confElems {}
    foreach bmark $bookmarks {
	set name [lindex $bmark 0]
	set jid  [lindex $bmark 1]
	set opts [lrange $bmark 2 end]	
	set attrs [list jid $jid name $name]
	set elems {}
	foreach {key value} $opts {
	    
	    switch -- $key {
		-nick - -password {
		    lappend elems [string trimleft $key -] $value
		}
		-autojoin {
		    lappend attrs autojoin $value
		}
	    }
	}
	set confChilds {}
	foreach {tag value} $elems {
	    lappend confChilds [wrapper::createtag $tag -chdata $value]
	}
	set confElem [wrapper::createtag "conference"  \
	  -attrlist $attrs -subtags $confChilds]
	lappend confElems $confElem
    }
    set storageElem [wrapper::createtag "storage"  \
      -attrlist [list xmlns "storage:bookmarks"] -subtags $confElems]
    set queryElem [wrapper::createtag "query"  \
      -attrlist [list xmlns "jabber:iq:private"] -subtags [list $storageElem]]
    
    $jstate(jlib) send_iq set [list $queryElem]
}

proc ::GroupChat::BookmarkSendGet {callback} {
    upvar ::Jabber::jstate jstate
    
    set storageElem [wrapper::createtag "storage"  \
      -attrlist [list xmlns storage:bookmarks]]
    set queryElem [wrapper::createtag "query"  \
      -attrlist [list xmlns "jabber:iq:private"] -subtags [list $storageElem]]

    $jstate(jlib) send_iq get [list $queryElem] -command $callback
}

proc ::GroupChat::EditBookmarks { } {
    global  wDlgs
    variable bookmarksVar
    
    set dlg $wDlgs(jgcbmark)
    if {[winfo exists $dlg]} {
	raise $dlg
	return
    }
    set m [::UI::GetMainMenu]
    set columns [list  \
      0 [mc Bookmark] 0 [mc Address]  \
      0 [mc Nickname] 0 [mc Password] \
      0 [mc Autojoin]]

    set bookmarksVar {}
    ::Bookmarks::Dialog $dlg [namespace current]::bookmarksVar  \
      -menu $m -geovariable prefs(winGeom,$dlg) -columns $columns  \
      -command [namespace current]::BookmarksDlgSave
    ::UI::SetMenuAcceleratorBinds $dlg $m
    
    $dlg boolean 4
    $dlg state disabled
    $dlg wait
    
    BookmarkSendGet [namespace current]::BookmarkSendGetCB
}

proc ::GroupChat::BookmarkSendGetCB {type queryElem args} {
    global  wDlgs
    variable bookmarks
        
    set dlg $wDlgs(jgcbmark)
    if {![winfo exists $dlg]} {
	return
    }
    
    if {$type eq "error"} {
	::UI::MessageBox -type ok -icon [mc Error]  \
	  -message "Failed to obtain conference bookmarks: [lindex $queryElem 1]"
	destroy $dlg
    } else {
	$dlg state {!disabled}
	$dlg wait 0
    
	# Extract the relevant 'conference' elements.
	set bookmarks [BookmarkExtractFromElem $queryElem]
	set flat [BookmarkToFlat $bookmarks]
	foreach row $flat {
	    $dlg add $row
	}
    }
}

proc ::GroupChat::BookmarksDlgSave { } {
    variable bookmarks
    variable bookmarksVar
    	
    set bookmarks [BookmarkFlatToBookmarks $bookmarksVar]
    BookmarkSendSet
    
    # Let other components that depend on this a chance to update themselves.
    ::hooks::run groupchatBookmarksSet
}

# GroupChat::BookmarkToFlat --
# 
#       Translate internal 'bookmarks' list into {{name jid nick pass} ...}

proc ::GroupChat::BookmarkToFlat {bookmarks} {

    set flat {}
    foreach bmark $bookmarks {
	array set opts [list -nick "" -password "" -autojoin 0]
	array set opts [lrange $bmark 2 end]	
	set row [lrange $bmark 0 1]
	lappend row $opts(-nick) $opts(-password) $opts(-autojoin)
	lappend flat $row
    }
    return $flat
}

proc ::GroupChat::BookmarkFlatToBookmarks {flat} {
    
    set bookmarks {}
    foreach row $flat {
	set bmark [lrange $row 0 1]
	set nick     [lindex $row 2]
	set password [lindex $row 3]
	set autojoin [lindex $row 4]
	if {$nick ne ""} {
	    lappend bmark -nick $nick
	}
	if {$password ne ""} {
	    lappend bmark -password $password
	}
	if {$autojoin} {
	    lappend bmark -autojoin $autojoin
	}
	lappend bookmarks $bmark
    }
    return $bookmarks
}

proc ::GroupChat::BookmarkBuildMenu {m cmd} {
    variable bookmarks
    upvar ::Jabber::jprefs jprefs
   
    menu $m -tearoff 0

    foreach bmark $bookmarks {
	set name [lindex $bmark 0]
	set jid  [lindex $bmark 1]
	set opts [lrange $bmark 2 end]	
	set mcmd [concat $cmd [list $name $jid $opts]]
	$m add command -label $name -command $mcmd
    }
    return $m
}

proc ::GroupChat::DoAnyAutoJoin {} {
    variable autojoinDone
    variable bookmarks

    if {!$autojoinDone} {
	foreach bmark $bookmarks {
	    array unset opts
	    set name [lindex $bmark 0]
	    set jid  [lindex $bmark 1]
	    array set opts [lrange $bmark 2 end]	
	    if {[info exists opts(-autojoin)] && $opts(-autojoin)} {
		if {[info exists opts(-nick)]} {
		    set nick $opts(-nick)
		} else {
		    jlib::splitjidex [::Jabber::JlibCmd myjid] nick - -
		}
		set eopts [list -command ::GroupChat::BookmarkAutoJoinCB]
		if {[info exists opts(-password)]} {
		    lappend eopts -password $opts(-password)
		}
		lappend eopts -protocol muc
		::Debug 4 "::GroupChat::DoAnyAutoJoin jid=$jid, nick=$nick $eopts"
		eval {::Enter::EnterRoom $jid $nick} $eopts
	    }
	}
    }
    set autojoinDone 1
}

proc ::GroupChat::BookmarkAutoJoinCB {args} {
    
    ::Debug 4 "::GroupChat::BookmarkAutoJoinCB $args"
    # anything ?
}

# Prefs page ...................................................................

proc ::GroupChat::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    
    # Defaults...    
    # Preferred groupchat protocol (gc-1.0|muc).
    # 'muc' uses 'conference' as fallback.
    set jprefs(prefgchatproto)  "muc"
    set jprefs(defnick)         ""
    set jprefs(gchat,syncPres)  0
    
    # Unused but keep it if we want client stored bookmarks.
    set jprefs(gchat,bookmarks) {}
	
    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(prefgchatproto)   jprefs_prefgchatproto    $jprefs(prefgchatproto)]  \
      [list ::Jabber::jprefs(defnick)          jprefs_defnick           $jprefs(defnick)]  \
      [list ::Jabber::jprefs(gchat,syncPres)   jprefs_gchat_syncPres    $jprefs(gchat,syncPres)]  \
      [list ::Jabber::jprefs(gchat,bookmarks)  jprefs_gchat_bookmarks   $jprefs(gchat,bookmarks)]  \
      ]   
}

proc ::GroupChat::BuildPrefsHook {wtree nbframe} {
    
    ::Preferences::NewTableItem {Jabber Conference} [mc Conference]
    
    # Conference page ------------------------------------------------------
    set wpage [$nbframe page {Conference}]
    BuildPageConf $wpage
}

proc ::GroupChat::BuildPageConf {page} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    set tmpJPrefs(prefgchatproto) $jprefs(prefgchatproto)
    set tmpJPrefs(gchat,syncPres) $jprefs(gchat,syncPres)
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
    pack $wnick.e -fill x
    pack $wnick -side top -anchor w -pady 8 -fill x
    
    ttk::checkbutton $wc.sync -text [mc jagcsyncpres]  \
      -variable [namespace current]::tmpJPrefs(gchat,syncPres)	      
    pack $wc.sync -side top -anchor w
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
