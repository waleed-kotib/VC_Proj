#  GroupChat.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the group chat GUI part.
#      
#  Copyright (c) 2001-2006  Mats Bengtsson
#  
# $Id: GroupChat.tcl,v 1.142 2006-04-08 07:02:48 matben Exp $

package require Enter
package require History
package require Bookmarks
package require colorutils

package provide GroupChat 1.0

# Provides dialog for old-style gc-1.0 groupchat but the rest should work for 
# any protocol.


namespace eval ::GroupChat:: {

    # Add all event hooks.
    ::hooks::register quitAppHook             ::GroupChat::QuitAppHook
    ::hooks::register quitAppHook             ::GroupChat::GetFirstPanePos
    ::hooks::register newGroupChatMessageHook ::GroupChat::GotMsg
    ::hooks::register newMessageHook          ::GroupChat::NormalMsgHook
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

    option add *GroupChat*tabAlertImage        ktip               widgetDefault    
    option add *GroupChat*tabCloseImage        closebutton        widgetDefault    
    option add *GroupChat*tabCloseActiveImage  closebuttonActive  widgetDefault    

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
    option add *GroupChat*sysPreForeground     "#26b412"        widgetDefault
    option add *GroupChat*sysTextForeground    "#26b412"        widgetDefault
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
    if {[tk windowingsystem] eq "aqua"} {
	option add *GroupChat*TNotebook.padding       {8 8 8 18}       50
    } else {
	option add *GroupChat*TNotebook.padding       {8 8 8 8}        50
    }
    option add *GroupChatRoom*Text.borderWidth     0               50
    option add *GroupChatRoom*Text.relief          flat            50
    option add *GroupChatRoom.padding              {12  0 12  0}   50
    option add *GroupChatRoom*active.padding       {1}             50
    option add *GroupChatRoom*TMenubutton.padding  {1}             50
    option add *GroupChatRoom*top.padding          {12  8 12  8}   50
    option add *GroupChatRoom*bot.padding          { 0  6  0  6}   50
    
    # Local stuff
    variable enteruid 0
    variable dlguid 0

    # Running numbers for tokens.
    variable uiddlg  0
    variable uidchat 0
    variable uidpage 0

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
	{check     mIgnore        {::GroupChat::Ignore $chattoken $jid} {
	    -variable $chattoken\(ignore,$jid)
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
	set allConfServ [$jstate(jlib) disco getconferences]
	foreach serv $allConfServ {
	    if {[$jstate(jlib) disco hasfeature $xmppxmlns(muc) $serv]} {
		set ans 1
	    }
	}
    } else {
	
	# We must query the service, not the room, for browse to work.
	jlib::splitjidex $jid node service -
	if {$service ne ""} {
	    if {[$jstate(jlib) disco hasfeature $xmppxmlns(muc) $service]} {
		set ans 1
	    }
	}
    }
    ::Debug 4 "::GroupChat::HaveMUC = $ans, jid=$jid"
    
    return $ans
}

# GroupChat::EnterOrCreate --
#
#       Dispatch entering or creating a room to either 'groupchat' (gc-1.0)
#       or 'muc' methods.
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
	set protocol "muc"
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
	    set ans [eval {::Create::Build} $args]
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
}

# GroupChat::SetProtocol --
# 
#       Cache groupchat protocol in use for specific room.

proc ::GroupChat::SetProtocol {roomjid _protocol} {    
    variable protocol

    ::Debug 2 "::GroupChat::SetProtocol +++++++++ $roomjid $_protocol"
    set roomjid [jlib::jidmap $roomjid]
    
    # We need a separate cache for this since the room may not yet exist.
    set protocol($roomjid) $_protocol
    
    set chattoken [GetTokenFrom chat roomjid $roomjid]
    if {$chattoken eq ""} {
	return
    }
    
    if {$_protocol eq "muc"} {
	variable $chattoken
	upvar 0 $chattoken chatstate

	set dlgtoken $chatstate(dlgtoken)
	variable $dlgtoken
	upvar 0 $dlgtoken dlgstate

	set wtray $dlgstate(wtray)
	$wtray buttonconfigure invite -state normal
	$wtray buttonconfigure info   -state normal
	$chatstate(wbtnick) configure -state normal
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

    set chatservers [$jstate(jlib) disco getconferences]
    ::Debug 2 "::GroupChat::BuildEnter chatservers=$chatservers args='$args'"
    
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

# GroupChat::NewChat --
# 
#       Takes a room JID and handles building of dialog and chat room stuff.
#       @@@ Add more code here...
#       
# Results:
#       chattoken

proc ::GroupChat::NewChat {roomjid args} {
    upvar ::Jabber::jprefs jprefs
    
    if {$jprefs(chat,tabbedui)} {
	set dlgtoken [GetFirstDlgToken]
	if {$dlgtoken eq ""} {
	    set dlgtoken [eval {Build $roomjid} $args]
	    set chattoken [GetTokenFrom chat roomjid $roomjid]
	} else {
	    set chattoken [NewPage $dlgtoken $roomjid]
	}
    } else {
	set dlgtoken [eval {Build $roomjid} $args]
	set chattoken [GetActiveChatToken $dlgtoken]
    }
    
    return $chattoken
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
    set chattoken [GetTokenFrom chat roomjid $roomjid]
    if {$chattoken eq ""} {
	set chattoken [eval {NewChat $roomjid} $args]
    }
    variable $chattoken
    upvar 0 $chattoken chatstate

    set dlgtoken $chatstate(dlgtoken)
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate

    # We may get a history from users not in the room anymore.
    if {[info exists chatstate(ignore,$from)] && $chatstate(ignore,$from)} {
	return
    }
    if {[info exists argsArr(-subject)]} {
	set chatstate(subject) $argsArr(-subject)
	set str "[mc Subject]: $chatstate(subject)"
	eval {InsertMessage $chattoken $from $str} $args
    }
    if {$body ne ""} {

	# And put message in window.
	eval {InsertMessage $chattoken $from $body} $args
	eval {TabAlert $chattoken} $args
	    
	# Put an extra (*) in the windows title if not in focus.
	if {([set wfocus [focus]] eq "") ||  \
	  ([winfo toplevel $wfocus] ne $dlgstate(w))} {
	    incr dlgstate(nhiddenmsgs)
	    SetTitle [GetActiveChatToken $dlgtoken]
	}
	
	# Run display hooks (speech).
	eval {::hooks::run displayGroupChatMessageHook $body} $args
    }
}

# GroupChat::Build --
#
#       Builds the group chat dialog.
#
# Arguments:
#       roomjid     The roomname@server
#       args        ??
#       
# Results:
#       shows window, returns token.

proc ::GroupChat::Build {roomjid args} {
    global  prefs wDlgs
    
    variable protocol
    variable uiddlg
    variable cprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::GroupChat::Build roomjid=$roomjid, args='$args'"

    # Initialize the state variable, an array, that keeps is the storage.
    
    set dlgtoken [namespace current]::dlg[incr uiddlg]
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate

    # Make unique toplevel name.
    set w $wDlgs(jgc)$uiddlg
    array set argsArr $args

    set dlgstate(w)             $w
    set dlgstate(uid)           0
    set dlgstate(nhiddenmsgs)   0
        
    # Toplevel of class GroupChat.
    ::UI::Toplevel $w -class GroupChat \
      -usemacmainmenu 1 -macstyle documentProc  \
      -closecommand ::GroupChat::CloseCmd
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
        
    # Widget paths.
    set wtop        $w.frall.top
    set wtray       $w.frall.top.tray
    set wcont       $w.frall.cc        ;# container frame for wroom or wnb
    set wroom       $w.frall.room      ;# the chat room widget container
    set wnb         $w.frall.nb        ;# tabbed notebook
    set dlgstate(wtop)       $wtop
    set dlgstate(wtray)      $wtray
    set dlgstate(wcont)      $wcont
    set dlgstate(wroom)      $wroom
    set dlgstate(wnb)        $wnb

    ttk::frame $wtop
    pack $wtop -side top -fill x
        
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
      -command [list [namespace current]::Send $dlgtoken]
    $wtray newbutton save -text [mc Save] \
      -image $iconSave -disabledimage $iconSaveDis    \
       -command [list [namespace current]::Save $dlgtoken]
    $wtray newbutton history -text [mc History] \
      -image $iconHistory -disabledimage $iconHistoryDis \
      -command [list [namespace current]::BuildHistory $dlgtoken]
    $wtray newbutton invite -text [mc Invite] \
      -image $iconInvite -disabledimage $iconInviteDis  \
      -command [list [namespace current]::Invite $dlgtoken]
    $wtray newbutton info -text [mc Info] \
      -image $iconInfo -disabledimage $iconInfoDis    \
      -command [list [namespace current]::Info $dlgtoken]
    $wtray newbutton print -text [mc Print] \
      -image $iconPrint -disabledimage $iconPrintDis   \
      -command [list [namespace current]::Print $dlgtoken]
    
    ::hooks::run buildGroupChatButtonTrayHook $wtray $roomjid
    
    set shortBtWidth [expr [$wtray minwidth] + 8]

    # Top separator.
    ttk::separator $w.frall.divt -orient horizontal
    pack $w.frall.divt -side top -fill x
    
    # Having the frame with room frame as a sibling makes it possible
    # to pack it in a different place.
    ttk::frame $wcont
    pack $wcont -side top -fill both -expand 1
    
    # Use an extra frame that contains everything room specific.
    set chattoken [eval {
	BuildRoomWidget $dlgtoken $wroom $roomjid
    } $args]
    pack $wroom -in $wcont -fill both -expand 1

    if {!( [info exists protocol($roomjid)] && ($protocol($roomjid) eq "muc") )} {
	$wtray buttonconfigure invite -state disabled
	$wtray buttonconfigure info   -state disabled
    }
    
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jgc)]]
    if {$nwin == 1} {
	::UI::SetWindowGeometry $w $wDlgs(jgc)
    }
    SetTitle $chattoken
    
    wm minsize $w [expr {$shortBtWidth < 240} ? 240 : $shortBtWidth] 320
    wm maxsize $w 800 2000

    bind $w <FocusIn> [list [namespace current]::FocusIn $dlgtoken]

    focus $w
    set tag TopTag$w
    bindtags $w [concat $tag [bindtags $w]]
    bind $tag <Destroy> +[list ::GroupChat::OnDestroyDlg $dlgtoken]
    
    return $dlgtoken
}

# GroupChat::BuildRoomWidget --
# 
#       Builds page with all room specific ui parts.
#       
# Arguments:
#       dlgtoken    topwindow token
#       wroom       megawidget frame
#       roomjid
#       args
#       
# Results:
#       chattoken

proc ::GroupChat::BuildRoomWidget {dlgtoken wroom roomjid args} {
    global  this
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate

    variable uidchat
    variable cprefs
    variable protocol

    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::GroupChat::BuildRoomWidget, roomjid=$roomjid, args=$args"
    array set argsArr $args

    # Initialize the state variable, an array, that keeps is the storage.
    
    set chattoken [namespace current]::chat[incr uidchat]
    variable $chattoken
    upvar 0 $chattoken chatstate

    lappend dlgstate(chattokens)    $chattoken
    lappend dlgstate(recentctokens) $chattoken
    
    # Widget paths.
    set wtop        $wroom.top
    set wbot        $wroom.bot
    set wmid        $wroom.mid
    
    set wpanev      $wroom.mid.pv
    set wfrsend     $wroom.mid.pv.b
    set wtextsend   $wroom.mid.pv.b.text
    set wyscsend    $wroom.mid.pv.b.ysc
    
    set wpaneh      $wroom.mid.pv.t
    set wfrchat     $wroom.mid.pv.l
    set wfrusers    $wroom.mid.pv.r
	
    set wtext       $wroom.mid.pv.l.text
    set wysc        $wroom.mid.pv.l.ysc
    set wusers      $wroom.mid.pv.r.tree
    set wyscusers   $wroom.mid.pv.r.ysc
    
    set chatstate(wroom)        $wroom
    set chatstate(roomjid)      $roomjid
    set chatstate(dlgtoken)     $dlgtoken
    set chatstate(roomName)     [$jstate(jlib) disco name $roomjid]
    set chatstate(subject)      ""
    set chatstate(status)       "available"
    set chatstate(oldStatus)    "available"
    set chatstate(ignore,$roomjid)  0
    set chatstate(afterids)     {}
    set chatstate(nhiddenmsgs)  0
    
    # For the tabs and title etc.
    if {$chatstate(roomName) ne ""} {
	set chatstate(displayName) $chatstate(roomName)
    } else {
	set chatstate(displayName) $roomjid
    }
    set chatstate(wtext)        $wtext
    set chatstate(wtextsend)    $wtextsend
    set chatstate(wusers)       $wusers
    set chatstate(wpanev)       $wpanev
    set chatstate(wpaneh)       $wpaneh

    set chatstate(active)       $cprefs(lastActiveRet)
	
    # Use an extra frame that contains everything room specific.
    ttk::frame $wroom -class GroupChatRoom
#      -padding [option get . dialogSmallPadding {}]
    
    set w [winfo toplevel $wroom]
    set chatstate(w) $w    

    # Button part.
    ttk::frame $wbot
    ttk::button $wbot.btok -text [mc Send]  \
      -default active -command [list [namespace current]::Send $dlgtoken]
    ttk::button $wbot.btcancel -text [mc Exit]  \
      -command [list [namespace current]::ExitAndClose $chattoken]
    
    set wgroup    $wbot.grp
    set wbtstatus $wgroup.stat
    set wbtbmark  $wgroup.bmark

    ttk::frame $wgroup
    ttk::checkbutton $wgroup.active -style Toolbutton \
      -image [::Theme::GetImage return]               \
      -command [list [namespace current]::ActiveCmd $chattoken] \
      -variable $chattoken\(active)
    ttk::button $wgroup.bmark -style Toolbutton  \
      -image [::Theme::GetImage bookmarkAdd]     \
      -command [list [namespace current]::BookmarkRoom $chattoken]

    ::Jabber::Status::Button $wgroup.stat $chattoken\(status)   \
      -command [list [namespace current]::StatusCmd $chattoken] 
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
	
    set wbtsend $wbot.btok

    ::balloonhelp::balloonforwindow $wgroup.active [mc jaactiveret]
    ::balloonhelp::balloonforwindow $wgroup.bmark  [mc {Bookmark this room}]

    # Header fields.
    ttk::frame $wtop
    pack $wtop -side top -fill x

    ttk::button $wtop.btp -style Small.TButton \
      -text "[mc Topic]:" \
      -command [list [namespace current]::SetTopic $chattoken]
    ttk::entry $wtop.etp -font CociSmallFont \
      -textvariable $chattoken\(subject) -state disabled
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
    }
    
    # Main frame for panes.
    frame $wmid -height 250 -width 300
    pack  $wmid -side top -fill both -expand 1

    # Pane geometry manager.
    ttk::paned $wpanev -orient vertical
    pack $wpanev -side top -fill both -expand 1    

    # Text send.
    frame $wfrsend -height 40 -width 300 -bd 1 -relief sunken
    text  $wtextsend -height 2 -width 1 -font CociSmallFont -wrap word \
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
    Tree $chattoken $w $wusers $wyscusers

    grid  $wusers     -column 0 -row 0 -sticky news
    grid  $wyscusers  -column 1 -row 0 -sticky ns -padx 2
    grid columnconfigure $wfrusers 0 -weight 1
    grid rowconfigure    $wfrusers 0 -weight 1
    
    $wpaneh add $wfrchat  -weight 1
    $wpaneh add $wfrusers -weight 1
    
    # The tags.
    ConfigureTextTags $w $wtext
	
    set chatstate(wbtsend)      $wbtsend
    set chatstate(wbtnick)      $wbtnick
    set chatstate(wbtsubject)   $wbtsubject
    set chatstate(wbtstatus)    $wbtstatus
    set chatstate(wbtbmark)     $wbtbmark
    
    set ancient [expr {[clock clicks -milliseconds] - 1000000}]
    foreach whom {me you sys} {
	set chatstate(last,$whom) $ancient
    }

    if {$jprefs(chatActiveRet)} {
	set chatstate(active) 1
    } else {
	set chatstate(active) $cprefs(lastActiveRet)
    }
    if {$chatstate(active)} {
	ActiveCmd $chattoken
    }
    AddUsers $chattoken
        
    ::UI::SetSashPos groupchatDlgVert $wpanev
    ::UI::SetSashPos groupchatDlgHori $wpaneh
    
    bind $wtextsend <Return> \
      [list [namespace current]::ReturnKeyPress $chattoken]
    bind $wtextsend <$this(modkey)-Return> \
      [list [namespace current]::CommandReturnKeyPress $chattoken]
    bind $wroom <Destroy> +[list ::GroupChat::OnDestroyChat $chattoken]
    
    return $chattoken
}

proc ::GroupChat::OnDestroyDlg {dlgtoken} {

    unset -nocomplain $dlgtoken
}

proc ::GroupChat::OnDestroyChat {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    foreach id $chatstate(afterids) {
	after cancel $id
    }
    unset -nocomplain $chattoken
}

# GroupChat::NewPage, ... --
# 
#       Several procs to handle the tabbed interface; creates and deletes
#       notebook and pages.

proc ::GroupChat::NewPage {dlgtoken roomjid args} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    upvar ::Jabber::jprefs jprefs
	
    # If no notebook, move chat widget to first notebook page.
    if {[string equal [winfo class [pack slaves $dlgstate(wcont)]] "GroupChatRoom"]} {
	set wroom $dlgstate(wroom)
	set chattoken [lindex $dlgstate(chattokens) 0]
	variable $chattoken
	upvar 0 $chattoken chatstate

	# Repack the GroupChatRoom in notebook page.
	MoveRoomToPage $dlgtoken $chattoken
	DrawCloseButton $dlgtoken
    } 

    # Make fresh page with chat widget.
    set chattoken [eval {MakeNewPage $dlgtoken $roomjid} $args]
    return $chattoken
}

proc ::GroupChat::DrawCloseButton {dlgtoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    # Close button (exp). 
    set w $dlgstate(w)
    set im       [::Theme::GetImage [option get $w tabCloseImage {}]]
    set imactive [::Theme::GetImage [option get $w tabCloseActiveImage {}]]
    set wclose $dlgstate(wnb).close
    ttk::button $wclose -style Plain.TButton  \
      -image [list $im active $imactive] -compound image  \
      -command [list [namespace current]::ClosePageCmd $dlgtoken]
    place $wclose -anchor ne -relx 1.0 -x -6 -y 6

    ::balloonhelp::balloonforwindow $wclose [mc {Close page}]
    set dlgstate(wclose) $wclose
}

proc ::GroupChat::MoveRoomToPage {dlgtoken chattoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    # Repack the  in notebook page.
    set wnb      $dlgstate(wnb)
    set wcont    $dlgstate(wcont)
    set wroom    $chatstate(wroom)
    set dispname $chatstate(displayName)
    
    pack forget $wroom

    ttk::notebook $wnb
    bind $wnb <<NotebookTabChanged>> \
      [list [namespace current]::TabChanged $dlgtoken]
    ttk::notebook::enableTraversal $wnb
    pack $wnb -in $wcont -fill both -expand true -side right

    set wpage $wnb.p[incr dlgstate(uid)]
    ttk::frame $wpage
    $wnb add $wpage -sticky news -text $dispname -compound left
    pack $wroom -in $wpage -fill both -expand true -side right
    raise $wroom
    
    set chatstate(wpage) $wpage
    set dlgstate(wpage2token,$wpage) $chattoken
}

proc ::GroupChat::MakeNewPage {dlgtoken roomjid args} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    variable uidpage
    array set argsArr $args
	
    # Make fresh page with chat widget.
    set wnb $dlgstate(wnb)
    set wpage $wnb.p[incr dlgstate(uid)]
    ttk::frame $wpage
    $wnb add $wpage -sticky news -compound left

    # We must make the new page a sibling of the notebook in order to be
    # able to reparent it when notebook gons.
    set wroom $dlgstate(wroom)[incr uidpage]
    set chattoken [eval {
	BuildRoomWidget $dlgtoken $wroom $roomjid
    } $args]
    pack $wroom -in $wpage -fill both -expand true

    variable $chattoken
    upvar 0 $chattoken chatstate
    $wnb tab $wpage -text $chatstate(displayName)
    set chatstate(wpage) $wpage
    set dlgstate(wpage2token,$wpage) $chattoken
    
    return $chattoken
}

proc ::GroupChat::DeletePage {chattoken} {
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
    destroy $chatstate(wroom)
    
    # If only a single page left then reparent and delete notebook.
    if {[llength $dlgstate(chattokens)] == 1} {
	set chattoken [lindex $dlgstate(chattokens) 0]
	variable $chattoken
	upvar 0 $chattoken chatstate

	MoveThreadFromPage $dlgtoken $chattoken
    }
}

proc ::GroupChat::MoveThreadFromPage {dlgtoken chattoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set wnb     $dlgstate(wnb)
    set wcont   $dlgstate(wcont)
    set wroom   $chatstate(wroom)
    
    # This seems necessary on mac in order to not get a blank page.
    update idletasks

    pack forget $wroom
    destroy $wnb
    pack $wroom -in $wcont -fill both -expand 1
    
    SetRoomState $dlgtoken $chattoken
}

proc ::GroupChat::ClosePageCmd {dlgtoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    set chattoken [GetActiveChatToken $dlgtoken]
    if {$chattoken ne ""} {	
	ExitAndClose $chattoken
    }
}

# GroupChat::SelectPage --
# 
#       Make page frontmost.

proc ::GroupChat::SelectPage {chattoken} {    
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set dlgtoken $chatstate(dlgtoken)
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    if {[winfo exists $dlgstate(wnb)]} {
	$dlgstate(wnb) select $chatstate(wpage)
    }
}

# GroupChat::TabChanged --
# 
#       Callback command from notebook widget when selecting new tab.

proc ::GroupChat::TabChanged {dlgtoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    Debug 2 "::GroupChat::TabChanged"

    set wnb $dlgstate(wnb)
    set wpage [GetNotebookWpageFromIndex $wnb [$wnb index current]]
    set chattoken $dlgstate(wpage2token,$wpage)

    variable $chattoken
    upvar 0 $chattoken chatstate

    set chatstate(nhiddenmsgs) 0

    SetRoomState $dlgtoken $chattoken
    SetFocus $dlgtoken $chattoken
    
    lappend dlgstate(recentctokens) $chattoken
    set dlgstate(recentctokens) [lrange $dlgstate(recentctokens) end-1 end]
}

proc ::GroupChat::GetNotebookWpageFromIndex {wnb index} {
    
    set wpage ""
    foreach w [$wnb tabs] {
	if {[$wnb index $w] == $index} {
	    set wpage $w
	    break
	}
    }
    return $wpage
}

proc ::GroupChat::SetRoomState {dlgtoken chattoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate

    variable $chattoken
    upvar 0 $chattoken chatstate
    
    puts "::GroupChat::SetRoomState $dlgtoken $chattoken"
    
    if {[winfo exists $dlgstate(wnb)]} {
	$dlgstate(wnb) tab $chatstate(wpage) -image ""  \
	  -text $chatstate(displayName)
    }
    SetTitle $chattoken
    if {[::Jabber::IsConnected]} {
	SetState $chattoken normal
    } else {
	SetState $chattoken disabled
    }
}

# GroupChat::SetState --
# 
#       Set state of complete dialog to normal or disabled.

proc ::GroupChat::SetState {chattoken _state} {
    variable $chattoken
    upvar 0 $chattoken chatstate

    puts "::GroupChat::SetState $chattoken $_state"
    
    set dlgtoken $chatstate(dlgtoken)
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate    

    foreach name {send invite info} {
	$dlgstate(wtray) buttonconfigure $name -state $_state 
    }
    $chatstate(wbtsubject) configure -state $_state
    $chatstate(wbtnick)    configure -state $_state
    $chatstate(wbtsend)    configure -state $_state
    $chatstate(wbtstatus)  configure -state $_state
    $chatstate(wbtbmark)   configure -state $_state
    $chatstate(wtextsend)  configure -state $_state
}

# GroupChat::SetFocus --
# 
#       When selecting a new page we must move focus along.
#       This does not work reliable on MacOSX.

proc ::GroupChat::SetFocus {dlgtoken chattoken} {
    global  this
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate

    variable $chattoken
    upvar 0 $chattoken chatstate

    
    # @@@ TODO
}

proc ::GroupChat::SetTitle {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate

    set name    $chatstate(roomName)
    set roomjid $chatstate(roomjid)
    if {$name ne ""} {
	set str "[mc Groupchat]: $name"
    } else {
	set str "[mc Groupchat]: $roomjid"
    }

    # Put an extra (*) in the windows title if not in focus.
    set dlgtoken $chatstate(dlgtoken)
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate

    if {$dlgstate(nhiddenmsgs) > 0} {
	set wfocus [focus]
	set n $dlgstate(nhiddenmsgs)
	if {$wfocus eq ""} {
	    append str " ($n)"
	} elseif {[winfo toplevel $wfocus] ne $chatstate(w)} {
	    append str " ($n)"
	}
    }
    wm title $chatstate(w) $str
}

proc ::GroupChat::TabAlert {chattoken args} {
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
	    set name $chatstate(displayName)
	    append name " " "($chatstate(nhiddenmsgs))"
	    set icon [::Theme::GetImage [option get $w tabAlertImage {}]]
	    $wnb tab $chatstate(wpage) -image $icon -text $name
	}
    }
}

proc ::GroupChat::FocusIn {dlgtoken} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    set dlgstate(nhiddenmsgs) 0
    SetTitle [GetActiveChatToken $dlgtoken]
}

# GroupChat::GetDlgTokenValue, GetChatTokenValue --
# 
#       Outside code shall use these to get array values.

proc ::GroupChat::GetDlgTokenValue {dlgtoken key} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    return $dlgstate($key)
}

proc ::GroupChat::GetChatTokenValue {chattoken key} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    return $chatstate($key)
}

# GroupChat::GetActiveChatToken --
# 
#       Returns the chattoken corresponding to the frontmost room.

proc ::GroupChat::GetActiveChatToken {dlgtoken} {
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

# GroupChat::GetTokenFrom --
# 
#       Try to get the token state array from any stored key.
#       Only one token is returned if any.
#       
# Arguments:
#       type        'dlg' or 'chat'
#       key         w, jid, roomjid etc...
#       pattern     glob matching
#       
# Results:
#       token or empty if not found.

proc ::GroupChat::GetTokenFrom {type key pattern} {
    
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

# GroupChat::GetAllTokensFrom --
# 
#       As above but all tokens.

proc ::GroupChat::GetAllTokensFrom {type key pattern} {
    
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

proc ::GroupChat::GetFirstDlgToken { } {
 
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

# GroupChat::GetTokenList --
# 
# Arguments:
#       type        'dlg' or 'chat'

proc ::GroupChat::GetTokenList {type} {
    
    # For some strange reason [info vars] reports non existing arrays.
    set nskey [namespace current]::$type
    set tokens {}
    foreach token [concat  \
      [info vars ${nskey}\[0-9\]] \
      [info vars ${nskey}\[0-9\]\[0-9\]] \
      [info vars ${nskey}\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${nskey}\[0-9\]\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${nskey}\[0-9\]\[0-9\]\[0-9\]\[0-9\]\[0-9\]]] {

	# We need to check array size becaus also empty arrays are reported.
	if {[array size $token]} {
	    lappend tokens $token
	}
    }
    return $tokens
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

proc ::GroupChat::Tree {chattoken w T wysc} {
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
    
    bind UsersTreeTag <Button-1>        [list ::GroupChat::TreeButtonPress $chattoken %W %x %y ]
    bind UsersTreeTag <ButtonRelease-1> { ::GroupChat::TreeButtonRelease %W %x %y }        
    bind UsersTreeTag <<ButtonPopup>>   [list ::GroupChat::TreePopup $chattoken %W %x %y ]
    bind UsersTreeTag <Double-1>        { ::GroupChat::DoubleClick %W %x %y }        
    bind UsersTreeTag <Destroy>         {+::GroupChat::TreeOnDestroy %W }
    
    ::treeutil::setdboptions $T $w utree
}

proc ::GroupChat::TreeButtonPress {chattoken T x y} {
    variable buttonAfterId
    variable buttonPressMillis

    if {[tk windowingsystem] eq "aqua"} {
	if {[info exists buttonAfterId]} {
	    catch {after cancel $buttonAfterId}
	}
	set cmd [list ::GroupChat::TreePopup $chattoken $T $x $y]
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

proc ::GroupChat::TreePopup {chattoken T x y} {
    variable tag2item

    set id [$T identify $x $y]
    if {[lindex $id 0] eq "item"} {
	set item [lindex $id 1]
	set tag [$T item element cget $item cTag eText -text]
    } else {
	set tag {}
    }
    Popup $chattoken $T $tag $x $y
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

proc ::GroupChat::TreeCreateUserItem {chattoken jid3 presence args} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    variable userRoleToStr
    upvar ::Jabber::jstate jstate
    
    set T $chatstate(wusers)
    
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

proc ::GroupChat::TreeRemoveUser {chattoken jid3} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set T $chatstate(wusers)
    set tag [list jid $jid3]
    TreeDeleteItem $T $tag

    unset -nocomplain chatstate(ignore,$jid3)
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

proc ::GroupChat::StatusCmd {chattoken status} {
    variable $chattoken
    upvar 0 $chattoken chatstate

    ::Debug 2 "::GroupChat::StatusCmd status=$status"

    if {$status eq "unavailable"} {
	set ans [ExitAndClose $chattoken]
	if {$ans eq "no"} {
	    set chatstate(status) $chatstate(oldStatus)
	}
    } else {
    
	# Send our status.
	::Jabber::SetStatus $status -to $chatstate(roomjid)
	set chatstate(oldStatus) $status
    }
}

# GroupChat::InsertMessage --
# 
#       Puts message in text groupchat window.

proc ::GroupChat::InsertMessage {chattoken from body args} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    array set argsArr $args

    set w       $chatstate(w)
    set wtext   $chatstate(wtext)
    set roomjid $chatstate(roomjid)
        
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
    set chatstate(last,$whom) [clock clicks -milliseconds]
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

# GroupChat::CloseCmd --
# 
#       This gets called from toplevels -closecommand 

proc ::GroupChat::CloseCmd {wclose} {
    global  wDlgs

    #puts "::GroupChat::CloseCmd $wclose"
    
    set dlgtoken [GetTokenFrom dlg w $wclose]
    if {$dlgtoken ne ""} {
	variable $dlgtoken
	upvar 0 $dlgtoken dlgstate    

	set chattoken [GetActiveChatToken $dlgtoken]
	variable $chattoken
	upvar 0 $chattoken chatstate

	# Do we want to close each tab or complete window?
	set closetab 1
	set chattokens $dlgstate(chattokens)
	::UI::SaveSashPos groupchatDlgVert $chatstate(wpanev)
	::UI::SaveSashPos groupchatDlgHori $chatstate(wpaneh)

	# User pressed windows close button.
	if {[::UI::GetCloseWindowType] eq "wm"} {
	    set closetab 0
	}
	
	# All rooms need an explicit Exit, but tab only needs CloseRoomPage.
	if {$closetab} {
	    if {[llength $chattokens] >= 2} {
		Exit $chattoken
		CloseRoomPage $chattoken
		set closetoplevel 0
	    } else {
		set closetoplevel 1
	    }
	} else {
	    set closetoplevel 1
	}
	if {$closetoplevel} {
	    ::UI::SaveWinGeom $wDlgs(jgc) $dlgstate(w)
	    foreach chattoken $chattokens {
		Exit $chattoken
	    }
	} else {
	    # Since we only want to close a tab.
	    return "stop"
	}
    } else {
	return
    }
}

proc ::GroupChat::CloseRoomPage {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
        
    set dlgtoken $chatstate(dlgtoken)
    DeletePage $chattoken
    set newchattoken [GetActiveChatToken $dlgtoken]

    # Set state of new page.
    SetRoomState $dlgtoken $newchattoken
}

# GroupChat::ExitAndClose --
#
#       Handles both protocol and ui parts for closing a room.
#       
# Arguments:
#       roomjid
#       
# Results:
#       yes/no if actually exited or not.

proc ::GroupChat::ExitAndClose {chattoken} {
    global  wDlgs
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    #puts "::GroupChat::ExitAndClose $chattoken"
        
    set ans "yes"
    if {[::Jabber::IsConnected]} {
	if {0} {
	    # This could be optional.
	    set ans [ExitWarn $chattoken]
	}
	if {$ans eq "yes"} {
	    Exit $chattoken
	} else {
	    return $ans
	}
    } 
    
    # Do we want to close each tab or complete window?
    set dlgtoken $chatstate(dlgtoken)
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate    

    set chattokens $dlgstate(chattokens)
    
    if {[llength $chattokens] >= 2} {
	::UI::SaveSashPos groupchatDlgVert $chatstate(wpanev)
	::UI::SaveSashPos groupchatDlgHori $chatstate(wpaneh)
	CloseRoomPage $chattoken
    } else {
	::UI::SaveWinGeom $wDlgs(jgc) $dlgstate(w)
	destroy $dlgstate(w)
    }
    return $ans
}

proc ::GroupChat::ExitWarn {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate

    if {[info exists chatstate(w)] && [winfo exists $chatstate(w)]} {
	set opts [list -parent $chatstate(w)]
    } else {
	set opts ""
    }
    set roomjid $chatstate(roomjid)
    return [eval {::UI::MessageBox -icon warning -type yesno  \
      -message [mc jamesswarnexitroom $roomjid]} $opts]
}

# GroupChat::Exit --
# 
#       Handles the protocol part of exiting room.

proc ::GroupChat::Exit {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    upvar ::Jabber::jstate jstate

    #puts "::GroupChat::Exit $chattoken"

    if {[::Jabber::IsConnected]} {
	set roomjid $chatstate(roomjid)
	$jstate(jlib) service exitroom $roomjid
	::hooks::run groupchatExitRoomHook $roomjid
    }
}

# GroupChat::ExitRoomJID --
# 
#       Just a wrapper for Exit.

proc ::GroupChat::ExitRoomJID {roomjid} {

    set roomjid [jlib::jidmap $roomjid]
    set chattoken [GetTokenFrom chat roomjid $roomjid]
    if {$chattoken ne ""} {
	ExitAndClose $chattoken
    }
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

proc ::GroupChat::SetTopic {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    upvar ::Jabber::jstate jstate
    
    set topic   $chatstate(subject)
    set roomjid $chatstate(roomjid)
    
    set ans [::UI::MegaDlgMsgAndEntry  \
      [mc {Set New Topic}]             \
      [mc jasettopic2]                 \
      "[mc {New Topic}]:"              \
      topic [mc Cancel] [mc OK]]

    if {($ans eq "ok") && ($topic ne "")} {
	::Jabber::JlibCmd send_message $roomjid -type groupchat \
	  -subject $topic
    }
    return $ans
}

proc ::GroupChat::Send {dlgtoken} {
    
    # Check that still connected to server.
    if {![::Jabber::IsConnected]} {
	::UI::MessageBox -type ok -icon error -title [mc {Not Connected}] \
	  -message [mc jamessnotconnected]
	return
    }
    SendChat [GetActiveChatToken $dlgtoken]
}

proc ::GroupChat::SendChat {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate

    set wtextsend $chatstate(wtextsend)
    set roomjid   $chatstate(roomjid)

    # Get text to send. Strip off any ending newlines from Return.
    # There might by smiley icons in the text widget. Parse them to text.
    set allText [::Text::TransformToPureText $wtextsend]
    set allText [string trimright $allText]
    if {$allText ne ""} {	
	::Jabber::JlibCmd send_message $roomjid -type groupchat -body $allText
    }
    
    # Clear send.
    $wtextsend delete 1.0 end
    set chatstate(hot1stmsg) 1
}

proc ::GroupChat::ActiveCmd {chattoken} {
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
#       Ctrl+Ret: send messgae
#
#       active mode:
#       Ret: send message
#       Ctrl+Ret: word-wrap

proc ::GroupChat::ReturnKeyPress {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate

    if {$chatstate(active)} {
	SendChat $chattoken
	
	# Stop the actual return to be inserted.
	return -code break
    }
}

proc ::GroupChat::CommandReturnKeyPress {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    if {!$chatstate(active)} {
	SendChat $chattoken
	
	# Stop further handling in Text.
	return -code break
    }
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
    set conferences [$jstate(jlib) disco getconferences]
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
	
	set chattoken [GetTokenFrom chat roomjid $jid2]
	if {$chattoken ne ""} {
	    set cmd [concat \
	      [list ::GroupChat::InsertPresenceChange $chattoken $presence $jid3] \
	      $args]
	    lappend chatstate(afterids) [after 200 $cmd]
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

proc ::GroupChat::InsertPresenceChange {chattoken presence jid3 args} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    variable show2String
    
    array set argsArr $args
    
    if {[info exists chatstate(w)] && [winfo exists $chatstate(w)]} {
	
	# Some services send out presence changes automatically.
	# This should only be called if not the room does it.
	set ms [clock clicks -milliseconds]
	if {[expr {$ms - $chatstate(last,sys) < 400}]} {
	    return
	}
	set nick [::Jabber::JlibCmd service nick $jid3]	
	set show $presence
	if {[info exists argsArr(-show)]} {
	    set show $argsArr(-show)
	}
	InsertMessage $chattoken $chatstate(roomjid) "${nick}: $show2String($show)"
    }
}

proc ::GroupChat::AddUsers {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    upvar ::Jabber::jstate jstate
    
    set roomjid $chatstate(roomjid)
    
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
    set chattoken [GetTokenFrom chat roomjid $roomjid]
    if {$chattoken eq ""} {
	set chattoken [eval {NewChat $roomjid} $args]
    }       
    variable $chattoken
    upvar 0 $chattoken chatstate
        
    # If we got a browse push with a <user>, assume is available.
    if {$presence eq ""} {
	set presence available
    }    
    
    # Don't forget to init the ignore state.
    if {![info exists chatstate(ignore,$jid3)]} {
	set chatstate(ignore,$jid3) 0
    }
    eval {TreeCreateUserItem $chattoken $jid3 $presence} $args
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

proc ::GroupChat::Popup {chattoken w tag x y} {
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
    
    ::AMenu::Build $m $mDef -varlist [list jid $jid chattoken $chattoken]
    
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

proc ::GroupChat::Ignore {chattoken jid3} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set T $chatstate(wusers)
    if {$chatstate(ignore,$jid3)} {
	TreeSetIgnoreState $T $jid3
    } else {
	TreeSetIgnoreState $T $jid3 !
    }
}

proc ::GroupChat::RemoveUser {roomjid jid3} {

    ::Debug 4 "::GroupChat::RemoveUser roomjid=$roomjid, jid3=$jid3"
    
    set roomjid [jlib::jidmap $roomjid]
    set chattoken [GetTokenFrom chat roomjid $roomjid]
    if {$chattoken ne ""} {
	TreeRemoveUser $chattoken $jid3
    }
}

proc ::GroupChat::BuildHistory {dlgtoken} {

    set chattoken [GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate

    ::History::BuildHistory $chatstate(roomjid) groupchat -class GroupChat  \
      -tagscommand ::GroupChat::ConfigureTextTags
}

proc ::GroupChat::Save {dlgtoken} {

    set chattoken [GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate

    set wtext   $chatstate(wtext)
    set roomjid $chatstate(roomjid)
    
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
    }
}

proc ::GroupChat::Invite {dlgtoken} {
    
    set chattoken [GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    ::MUC::Invite $chatstate(roomjid)
}

proc ::GroupChat::Info {dlgtoken} {
    
    set chattoken [GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    ::MUC::BuildInfo $chatstate(roomjid)
}

proc ::GroupChat::Print {dlgtoken} {

    set chattoken [GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    ::UserActions::DoPrintText $chatstate(wtext) 
}

proc ::GroupChat::StatusSyncHook {status args} {
    upvar ::Jabber::jprefs jprefs

    if {$status eq "unavailable"} {
	# This is better handled via the logout hook.
	return
    }
    array set argsArr $args

    if {$jprefs(gchat,syncPres) && ![info exists argsArr(-to)]} {
	foreach chattoken [GetTokenList chat] {
	    variable $chattoken
	    upvar 0 $chattoken chatstate
	    
	    # Send our status.
	    ::Jabber::SetStatus $status -to $state(roomjid)
	    set chatstate(status)    $status
	    set chatstate(oldStatus) $status
	    #::Jabber::Status::ConfigImage $state(wbtstatus) $status
	}
    }
}

# GroupChat::LogoutHook --
#
#       Sets logged out status on all groupchats, that is, disable all buttons.

proc ::GroupChat::LogoutHook { } {    
    variable autojoinDone

    set autojoinDone 0

    foreach chattoken [GetTokenList chat] {
	variable $chattoken
	upvar 0 $chattoken chatstate

	SetState $chattoken disabled
	::hooks::run groupchatExitRoomHook $chatstate(roomjid)
    }
}

proc ::GroupChat::GetFirstPanePos { } {
    global  wDlgs
    
    set win [::UI::GetFirstPrefixedToplevel $wDlgs(jgc)]
    set chattoken [GetTokenFrom chat w $win]
    if {$chattoken ne ""} {
	variable $chattoken
	upvar 0 $chattoken chatstate

	::UI::SaveSashPos groupchatDlgVert $chatstate(wpanev)
	::UI::SaveSashPos groupchatDlgHori $chatstate(wpaneh)
    }
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

proc ::GroupChat::BookmarkRoom {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    variable bookmarks
    upvar ::Jabber::jstate jstate
    
    set roomjid $chatstate(roomjid)
    set name [$jstate(jlib) disco name $roomjid]
    if {$name eq ""} {
	set name $roomjid
    }
    lassign [$jstate(jlib) service hashandnick $roomjid] myroomjid nick
    
    # Add only if name not there already.
    foreach bmark $bookmarks {
	if {[lindex $bmark 0] eq $name} {
	    return
	}
    }
    lappend bookmarks [list $name $roomjid -nick $nick]
    
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
    set jprefs(defnick)         ""
    set jprefs(gchat,syncPres)  0
    
    # Unused but keep it if we want client stored bookmarks.
    set jprefs(gchat,bookmarks) {}
	
    ::PrefUtils::Add [list  \
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
    
    set tmpJPrefs(gchat,syncPres) $jprefs(gchat,syncPres)
    set tmpJPrefs(defnick)        $jprefs(defnick)
    
    # Conference (groupchat) stuff.
    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]
    
    set wnick $wc.n
    ttk::frame $wnick
    ttk::label $wnick.l -text "[mc {Default nickname}]:"
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
