#  GroupChat.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the group chat GUI part.
#      
#  Copyright (c) 2001-2006  Mats Bengtsson
#  
# $Id: GroupChat.tcl,v 1.178 2007-01-22 16:09:53 matben Exp $

package require Create
package require Enter
package require History
package require Bookmarks
package require UI::WSearch
package require colorutils

package provide GroupChat 1.0


namespace eval ::GroupChat:: {

    # Add all event hooks.
    ::hooks::register quitAppHook             ::GroupChat::QuitAppHook
    ::hooks::register quitAppHook             ::GroupChat::GetFirstPanePos
    ::hooks::register newGroupChatMessageHook ::GroupChat::GotMsg
    ::hooks::register newMessageHook          ::GroupChat::NormalMsgHook
    ::hooks::register loginHook               ::GroupChat::LoginHook
    ::hooks::register logoutHook              ::GroupChat::LogoutHook
    ::hooks::register setPresenceHook         ::GroupChat::StatusSyncHook
    ::hooks::register groupchatEnterRoomHook  ::GroupChat::EnterHook
    ::hooks::register menuGroupChatEditPostHook   ::GroupChat::MenuEditPostHook
    
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
    option add *GroupChat*whiteboardImage      whiteboard       widgetDefault
    option add *GroupChat*whiteboardDisImage   whiteboardDis    widgetDefault

    option add *GroupChat*tabAlertImage        ktip               widgetDefault    

    if {[tk windowingsystem] eq "aqua"} {
	option add *GroupChat*tabClose16Image        closeAqua         widgetDefault    
	option add *GroupChat*tabCloseActive16Image  closeAquaActive   widgetDefault    
    } else {
	option add *GroupChat*tabClose16Image        close             widgetDefault    
	option add *GroupChat*tabCloseActive16Image  close             widgetDefault    
    }
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
	{command   mWhiteboard    {::JWB::NewWhiteboardTo $jid} }
	{command   mEditNick      {::GroupChat::TreeEditUserStart $chattoken $jid} }
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
	{mEditNick      me          }
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
    
    # Not used.
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
    variable waitUntilEditMillis 2000
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

proc ::GroupChat::OnMenuEnter {} {
    if {[llength [grab current]]} { return }
    if {[::JUI::GetConnectState] eq "connectfin"} {
	EnterOrCreate enter
    }
}

proc ::GroupChat::OnMenuCreate {} {
    if {[llength [grab current]]} { return }
    if {[::JUI::GetConnectState] eq "connectfin"} {
	EnterOrCreate create
    }
}

proc ::GroupChat::IsInRoom {roomjid} {
    if {[lsearch [::Jabber::JlibCmd service allroomsin] $roomjid] < 0} {
	return 0
    } else {
	return 1
    }
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
    
    array set argsA $args
    if {[info exists argsA(-roomjid)]} {
	set roomjid $argsA(-roomjid)
	jlib::splitjidex $roomjid node service -
    } elseif {[info exists argsA(-server)]} {
	set service $argsA(-server)
    }

    if {[info exists argsA(-protocol)]} {
	set protocol $argsA(-protocol)
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
	    set ans [eval {::Create::GCBuild} $args]
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
  
    set chattoken [GetTokenFrom chat roomjid $roomjid]
    if {$chattoken eq ""} {

	# If we haven't a window for this roomjid, make one!
	set chattoken [NewChat $roomjid]
    } else {
	
	# Refresh any existing room widget.
	variable $chattoken
	upvar 0 $chattoken chatstate
	
	TreeDeleteAll $chatstate(wusers)
	AddUsers $chattoken
	SetState $chattoken normal
	$chatstate(wbtexit) configure -text [mc Exit]

	set chatstate(show)           "available"
	set chatstate(oldShow)        "available"
	set chatstate(show+status)    [list available ""]
	set chatstate(oldShow+status) [list available ""]
    }
    
    SetProtocol $roomjid $protocol
    
    ::Jabber::JlibCmd presence_register_ex [namespace code PresenceEvent] \
      -from2 $roomjid
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
        $wtray buttonconfigure whiteboard   -state normal
    }
}

# GroupChat::NormalMsgHook --
# 
#       MUC (and others) send invitations using normal messages. Catch!

proc ::GroupChat::NormalMsgHook {body args} {
    upvar ::Jabber::xmppxmlns xmppxmlns
    
    array set argsA $args

    set isinvite 0
    if {[info exists argsA(-x)]} {
    
	::Debug 2 "::GroupChat::NormalMsgHook args='$args'"

	set xList $argsA(-x)
	set cList [wrapper::getnamespacefromchilds $xList x $xmppxmlns(muc,user)]
	set roomjid $argsA(-from)
	
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

proc ::GroupChat::NewChat {roomjid} {
    upvar ::Jabber::jprefs jprefs
    
    if {$jprefs(chat,tabbedui)} {
	set dlgtoken [GetFirstDlgToken]
	if {$dlgtoken eq ""} {
	    set dlgtoken [Build $roomjid]
	    set chattoken [GetTokenFrom chat roomjid $roomjid]
	} else {
	    set chattoken [NewPage $dlgtoken $roomjid]
	}
    } else {
	set dlgtoken [Build $roomjid]
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
    
    array set argsA $args
    
    # We must follow the roomjid...
    if {[info exists argsA(-from)]} {
	set from $argsA(-from)
    } else {
	return
    }
    set from [jlib::jidmap $from]
    jlib::splitjid $from roomjid res
        
    # If we haven't a window for this roomjid, make one!
    set chattoken [GetTokenFrom chat roomjid $roomjid]
    if {$chattoken eq ""} {
	set chattoken [NewChat $roomjid]
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
    if {[info exists argsA(-subject)]} {
	set chatstate(subject) $argsA(-subject)
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
#       
# Results:
#       shows window, returns token.

proc ::GroupChat::Build {roomjid} {
    global  prefs wDlgs
    
    variable protocol
    variable uiddlg
    variable cprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::GroupChat::Build roomjid=$roomjid"

    # Initialize the state variable, an array, that keeps is the storage.
    
    set dlgtoken [namespace current]::dlg[incr uiddlg]
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate

    # Make unique toplevel name.
    set w $wDlgs(jgc)$uiddlg

    set dlgstate(exists)        1
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
    set iconWB          [::Theme::GetImage [option get $w whiteboardImage {}]]
    set iconWBDis       [::Theme::GetImage [option get $w whiteboardDisImage {}]]

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
    $wtray newbutton whiteboard -text [mc Whiteboard] \
      -image $iconWB -disabledimage $iconWBDis    \
      -command [list [namespace current]::Whiteboard $dlgtoken] 

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
    set chattoken [BuildRoomWidget $dlgtoken $wroom $roomjid]
    pack $wroom -in $wcont -fill both -expand 1

    if {!( [info exists protocol($roomjid)] && ($protocol($roomjid) eq "muc") )} {
	$wtray buttonconfigure invite -state disabled
	$wtray buttonconfigure info   -state disabled
        $wtray buttonconfigure whiteboard   -state disabled
    }
    
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jgc)]]
    if {$nwin == 1} {
	::UI::SetWindowGeometry $w $wDlgs(jgc)
    }
    SetTitle $chattoken
    
    wm minsize $w [expr {$shortBtWidth < 240} ? 240 : $shortBtWidth] 320
    
    bind $w <<Find>>         [namespace code [list Find $dlgtoken]]
    bind $w <<FindAgain>>    [namespace code [list FindAgain $dlgtoken]]  
    bind $w <<FindPrevious>> [namespace code [list FindAgain $dlgtoken -1]]  
    bind $w <FocusIn>       +[namespace code [list FocusIn $dlgtoken]]

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
#       
# Results:
#       chattoken

proc ::GroupChat::BuildRoomWidget {dlgtoken wroom roomjid} {
    global  this config
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate

    variable uidchat
    variable cprefs
    variable protocol

    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::GroupChat::BuildRoomWidget, roomjid=$roomjid"

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
    set wfind       $wroom.mid.pv.l.find
    set wusers      $wroom.mid.pv.r.tree
    set wyscusers   $wroom.mid.pv.r.ysc
    
    set roomjid [jlib::jidmap $roomjid]
    jlib::splitjidex $roomjid node domain -

    set chatstate(exists)         1
    set chatstate(wroom)          $wroom
    set chatstate(roomjid)        $roomjid
    set chatstate(dlgtoken)       $dlgtoken
    set chatstate(roomName)       [$jstate(jlib) disco name $roomjid]
    set chatstate(subject)        ""
    set chatstate(show)           "available"
    set chatstate(oldShow)        "available"
    set chatstate(show+status)    [list available ""]
    set chatstate(oldShow+status) [list available ""]
    set chatstate(ignore,$roomjid)  0
    set chatstate(afterids)       {}
    set chatstate(nhiddenmsgs)    0
    
    # For the tabs and title etc.
    if {$chatstate(roomName) ne ""} {
	set chatstate(displayName) $chatstate(roomName)
    } else {
	set chatstate(displayName) $roomjid
    }
    set chatstate(roomNode)     $node
    set chatstate(wtext)        $wtext
    set chatstate(wfind)        $wfind
    set chatstate(wtextsend)    $wtextsend
    set chatstate(wusers)       $wusers
    set chatstate(wpanev)       $wpanev
    set chatstate(wpaneh)       $wpaneh

    set chatstate(active)       $cprefs(lastActiveRet)
	
    # Use an extra frame that contains everything room specific.
    ttk::frame $wroom -class GroupChatRoom
    
    set w [winfo toplevel $wroom]
    set chatstate(w) $w    

    # Button part.
    set wbtexit   $wbot.btcancel
    set wgroup    $wbot.grp
    set wbtstatus $wgroup.stat
    set wbtbmark  $wgroup.bmark

    ttk::frame $wbot
    ttk::button $wbot.btok -text [mc Send]  \
      -default active -command [list [namespace current]::Send $dlgtoken]
    ttk::button $wbot.btcancel -text [mc Exit]  \
      -command [list [namespace current]::ExitAndClose $chattoken]

    ttk::frame $wgroup
    ttk::checkbutton $wgroup.active -style Toolbutton \
      -image [::Theme::GetImage return]               \
      -command [list [namespace current]::ActiveCmd $chattoken] \
      -variable $chattoken\(active)
    ttk::button $wgroup.bmark -style Toolbutton  \
      -image [::Theme::GetImage bookmarkAdd]     \
      -command [list [namespace current]::BookmarkRoom $chattoken]

    if {$config(ui,status,menu) eq "plain"} {
	::Status::Button $wgroup.stat $chattoken\(show)   \
	  -command [list [namespace current]::StatusCmd $chattoken] 
	::Status::ConfigImage $wgroup.stat available
	::Status::MenuConfig $wgroup.stat  \
	  -postcommand [list [namespace current]::StatusPostCmd $chattoken]
    } elseif {$config(ui,status,menu) eq "dynamic"} {
	::Status::ExButton $wgroup.stat $chattoken\(show+status)   \
	  -command [list [namespace current]::ExStatusCmd $chattoken] \
	  -postcommand [list [namespace current]::ExStatusPostCmd $chattoken]
    }
    
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

    ttk::label $wtop.btp -style Small.TLabel -text "[mc Topic]:"
    ttk::entry $wtop.etp -font CociSmallFont -textvariable $chattoken\(subject)
    
    grid  $wtop.btp  $wtop.etp  -sticky e -padx 0
    grid  $wtop.etp  -sticky ew
    grid columnconfigure $wtop 1 -weight 1
    
    # Special bindings for setting subject.
    set wsubject $wtop.etp
    bind $wsubject <FocusIn>  [list ::GroupChat::OnFocusInSubject $chattoken]
    bind $wsubject <FocusOut> [list ::GroupChat::OnFocusOutSubject $chattoken]
    bind $wsubject <Return>   [list ::GroupChat::OnReturnSubject $chattoken]    
    
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
    bindtags $wtext [linsert [bindtags $wtext] 0 ReadOnlyText]
 
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
    set chatstate(wbtstatus)    $wbtstatus
    set chatstate(wbtbmark)     $wbtbmark
    set chatstate(wbtexit)      $wbtexit
    
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

proc ::GroupChat::OnFocusInSubject {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set chatstate(subjectOld) $chatstate(subject)
}

proc ::GroupChat::OnFocusOutSubject {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    # Reset to previous subject.
    set chatstate(subject) $chatstate(subjectOld)
}

proc ::GroupChat::OnReturnSubject {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    ::Jabber::JlibCmd send_message $chatstate(roomjid) -type groupchat \
      -subject $chatstate(subject)
    focus $chatstate(w)
}

proc ::GroupChat::Find {dlgtoken} {

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

proc ::GroupChat::FindAgain {dlgtoken {dir 1}} {

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

proc ::GroupChat::MenuEditPostHook {wmenu} {
    
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
	    ::UI::MenuMethod $wmenu entryconfigure mFindAgain -state normal
	    ::UI::MenuMethod $wmenu entryconfigure mFindPrevious -state normal
	}
    }
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
    
    set subPath [file join images 16]    
    set im  [::Theme::GetImage [option get $w tabClose16Image {}] $subPath]
    set ima [::Theme::GetImage [option get $w tabCloseActive16Image {}] $subPath]
    set wclose $dlgstate(wnb).close

    ttk::button $wclose -style Plain  \
      -image [list $im active $ima] -compound image  \
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
    set roomNode $chatstate(roomNode)
    
    pack forget $wroom

    ttk::notebook $wnb
    bind $wnb <<NotebookTabChanged>> \
      [list [namespace current]::TabChanged $dlgtoken]
    ttk::notebook::enableTraversal $wnb
    pack $wnb -in $wcont -fill both -expand true -side right

    set wpage $wnb.p[incr dlgstate(uid)]
    ttk::frame $wpage
    $wnb add $wpage -sticky news -text $roomNode -compound left
    pack $wroom -in $wpage -fill both -expand true -side right
    raise $wroom
    
    set chatstate(wpage) $wpage
    set dlgstate(wpage2token,$wpage) $chattoken
}

proc ::GroupChat::MakeNewPage {dlgtoken roomjid args} {
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate
    
    variable uidpage
    array set argsA $args
	
    # Make fresh page with chat widget.
    set wnb $dlgstate(wnb)
    set wpage $wnb.p[incr dlgstate(uid)]
    ttk::frame $wpage
    $wnb add $wpage -sticky news -compound left

    # We must make the new page a sibling of the notebook in order to be
    # able to reparent it when notebook gons.
    set wroom $dlgstate(wroom)[incr uidpage]
    set chattoken [BuildRoomWidget $dlgtoken $wroom $roomjid]
    pack $wroom -in $wpage -fill both -expand true

    variable $chattoken
    upvar 0 $chattoken chatstate
    $wnb tab $wpage -text $chatstate(roomNode)
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

    ::hooks::run groupchatTabChangedHook $chattoken
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
    
    ::Debug 2 "::GroupChat::SetRoomState $dlgtoken $chattoken"
    
    if {[winfo exists $dlgstate(wnb)]} {
	$dlgstate(wnb) tab $chatstate(wpage) -image ""  \
	  -text $chatstate(roomNode)
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

    ::Debug 2 "::GroupChat::SetState $chattoken $_state"
    
    if {$_state eq "normal"} {
	set tstate {!disabled}
    } else {
	set tstate {disabled}
    }
    
    set dlgtoken $chatstate(dlgtoken)
    variable $dlgtoken
    upvar 0 $dlgtoken dlgstate    

    foreach name {send invite info} {
	$dlgstate(wtray) buttonconfigure $name -state $_state 
    }
    $chatstate(wbtsend)    state $tstate
    $chatstate(wbtstatus)  state $tstate
    $chatstate(wbtbmark)   state $tstate
    $chatstate(wtextsend)  configure -state $_state
}

proc ::GroupChat::SetLogout {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
        
    set clockFormat [option get $chatstate(w) clockFormat {}]
    if {$clockFormat ne ""} {
	set theTime [clock format [clock seconds] -format $clockFormat]
	set prefix "\[$theTime\] "
    } else {
	set prefix ""
    }
    InsertTagString $chattoken $prefix syspre
    InsertTagString $chattoken "  [mc jagclogoutmsg]\n" systext    

    set nick [::Jabber::JlibCmd service mynick $chatstate(roomjid)]
    set myjid $chatstate(roomjid)/$nick
    TreeRemoveUser $chattoken $myjid

    $chatstate(wbtexit) configure -text [mc Close]
    
    set chatstate(show)           "unavailable"
    set chatstate(oldShow)        "unavailable"
    set chatstate(show+status)    [list unavailable ""]
    set chatstate(oldShow+status) [list unavailable ""]
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
	if {[GetActiveChatToken $dlgtoken] ne $chattoken} {
	    incr chatstate(nhiddenmsgs)
	    set name $chatstate(roomNode)
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
    
    if {$key eq "roomjid"} {
	set pattern [jlib::jidmap $pattern]
    }
    
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
    
    if {$key eq "roomjid"} {
	set pattern [jlib::jidmap $pattern]
    }
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
    $T element create eImage     image
    $T element create eText      text
    $T element create eRoleImage image
    $T element create eRoleText  text
    $T element create eBorder    rect  -open new -showfocus 1
    $T element create eWindow    window

    # Styles collecting the elements.
    set S [$T style create styUser]
    $T style elements $S {eBorder eImage eText}
    $T style layout $S eImage  -expand ns
    $T style layout $S eText   -squeeze x -expand ns
    $T style layout $S eBorder -detach 1 -iexpand xy

    set S [$T style create styEntry]
    $T style elements $S {eBorder eImage eWindow}
    $T style layout $S eImage  -expand ns
    #$T style layout $S eWindow -sticky ew -iexpand xy
    $T style layout $S eWindow -iexpand xy
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
    
    bind $T <Button-1>        [list ::GroupChat::TreeButtonPress $chattoken %W %x %y ]
    bind $T <ButtonRelease-1> [list ::GroupChat::TreeButtonRelease $chattoken %W %x %y ]
    bind $T <<ButtonPopup>>   [list ::GroupChat::TreePopup $chattoken %W %x %y ]
    bind $T <Double-1>        { ::GroupChat::DoubleClick %W %x %y }        
    bind $T <Destroy>         {+::GroupChat::TreeOnDestroy %W }
    bind $T <KeyPress>        +[list ::GroupChat::TreeEditTimerCancel $chattoken]
    
    ::treeutil::setdboptions $T $w utree
}

proc ::GroupChat::TreeButtonPress {chattoken T x y} {
    variable buttonAfterId
    variable buttonPressMillis
    variable editTimer

    if {[tk windowingsystem] eq "aqua"} {
	if {[info exists buttonAfterId]} {
	    catch {after cancel $buttonAfterId}
	}
	set cmd [list ::GroupChat::TreePopup $chattoken $T $x $y]
	set buttonAfterId [after $buttonPressMillis $cmd]
    }

    # Edit bindings.
    if {[info exists editTimer(after)]} {
	set item [$T identify $x $y]
	if {$item eq $editTimer(id)} {
	    TreeEditUserStart $chattoken $editTimer(jid)
	}
    }
}

proc ::GroupChat::TreeButtonRelease {chattoken T x y} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    variable buttonAfterId
    variable waitUntilEditMillis
    variable editTimer
    
    if {[info exists buttonAfterId]} {
	after cancel $buttonAfterId
	unset buttonAfterId
    }    
    
    # Edit bindings.
    set id [$T identify $x $y]
    if {([lindex $id 0] eq "item") && ([llength $id] == 6)} {
	set item [lindex $id 1]
	set tags [$T item element cget $item cTag eText -text]
	if {[lindex $tags 0] eq "jid"} {
	    set jid [lindex $tags 1]
	    set nick [::Jabber::JlibCmd service mynick $chatstate(roomjid)]
	    set myjid $chatstate(roomjid)/$nick
	    if {[jlib::jidequal $jid $myjid]} {
		set cmd [list ::GroupChat::TreeEditTimerCancel $chattoken]
		set editTimer(id)    $id
		set editTimer(jid)   $jid
		set editTimer(after) [after $waitUntilEditMillis $cmd]
	    }
	}
    }
}

proc ::GroupChat::TreeEditTimerCancel {chattoken} {
    variable editTimer

    if {[info exists editTimer(after)]} {
	after cancel $editTimer(after)
    }
    unset -nocomplain editTimer
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
    variable editTimer
    upvar ::Jabber::jprefs jprefs

    unset -nocomplain editTimer

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

proc ::GroupChat::TreeCreateUserItem {chattoken jid3} {
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
    set image [::Roster::GetPresenceIconFromJid $jid3]
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

proc ::GroupChat::TreeEditUserStart {chattoken jid3} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    variable tag2item
    
    set T $chatstate(wusers)
    set tag [list jid $jid3]
    
    if {[info exists tag2item($T,$tag)]} {
	set item $tag2item($T,$tag)
	set image [::Roster::GetPresenceIconFromJid $jid3]
	set wentry $T.entry
	set chatstate(editNick) [jlib::resourcejid $jid3]
	entry $wentry -font CociSmallFont \
	  -textvariable $chattoken\(editNick) -width 1
	$T item style set $item cTree styEntry
	$T item element configure $item cTree \
	  eImage -image $image + eWindow -window $wentry
	focus $wentry
	# This creates a focus out on mac!
	#$wentry selection range 0 end 
	bind $wentry <Return>   \
	  [list ::GroupChat::TreeOnReturnEdit $chattoken $jid3]
	bind $wentry <FocusOut> \
	  [list ::GroupChat::TreeEditUserEnd $chattoken $jid3]
    }    
}

proc ::GroupChat::TreeOnReturnEdit {chattoken jid3} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set T $chatstate(wusers)
    set wentry $T.entry
    set nick $chatstate(editNick)
    if {[string length $nick]} {
	SetNick $chattoken $nick
    }    
    focus $chatstate(w)
}

proc ::GroupChat::TreeEditUserEnd {chattoken jid3} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    variable tag2item

    set T $chatstate(wusers)
    set tag [list jid $jid3]
    
    if {[info exists tag2item($T,$tag)]} {
	set item $tag2item($T,$tag)
	set image [::Roster::GetPresenceIconFromJid $jid3]
	set text [jlib::resourcejid $jid3]
	$T item style set $item cTree styUser
	$T item element configure $item cTree \
	  eImage -image $image + eText -text $text
	destroy $T.entry
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

proc ::GroupChat::TreeDeleteAll {T} {
    variable tag2item
    
    $T item delete all
    array unset tag2item $T,*
}

proc ::GroupChat::TreeOnDestroy {T} {
    variable tag2item
    
    array unset tag2item $T,*
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

proc ::GroupChat::StatusPostCmd {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set wbtstatus $chatstate(wbtstatus)
    if {[IsInRoom $chatstate(roomjid)]} {
	::Status::MenuSetState $wbtstatus all normal
    } else {
	::Status::MenuSetState $wbtstatus all disabled
	::Status::MenuSetState $wbtstatus available normal
    }
}

proc ::GroupChat::StatusCmd {chattoken show args} {
    variable $chattoken
    upvar 0 $chattoken chatstate

    ::Debug 2 "::GroupChat::StatusCmd show=$show, args=$args"

    if {$show eq "unavailable"} {
	set ans [ExitAndClose $chattoken]
	if {$ans eq "no"} {
	    set chatstate(show) $chatstate(oldShow)
	}
    } else {
	set roomjid $chatstate(roomjid)
	if {[IsInRoom $roomjid]} {
	    eval {::Jabber::SetStatus $show -to $roomjid} $args
	    set chatstate(oldShow) $show
	} else {
	    EnterOrCreate enter -roomjid $roomjid
	}
    }
}

proc ::GroupChat::ExStatusPostCmd {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set wbtstatus $chatstate(wbtstatus)
    set m [::Status::ExGetMenu $wbtstatus]
    if {[IsInRoom $chatstate(roomjid)]} {
	::Status::ExMenuSetState $m all normal
    } else {
	::Status::ExMenuSetState $m all disabled
	::Status::ExMenuSetState $m available normal
    }
}

proc ::GroupChat::ExStatusCmd {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set show   [lindex $chatstate(show+status) 0]
    set status [lindex $chatstate(show+status) 1]
    if {$show eq "unavailable"} {
	set ans [ExitAndClose $chattoken]
	if {$ans eq "no"} {
	    set chatstate(show+status) $chatstate(oldShow+status)
	}
    } else {
	set roomjid $chatstate(roomjid)
	if {[IsInRoom $roomjid]} {
	    ::Jabber::SetStatus $show -to $roomjid -status $status
	    set chatstate(oldShow+status) $show
	} else {
	    EnterOrCreate enter -roomjid $roomjid
	}
    }
}

proc ::GroupChat::StatusSyncHook {show args} {
    upvar ::Jabber::jprefs jprefs

    if {$show eq "unavailable"} {
	# This is better handled via the logout hook.
	return
    }
    set argsA(-status) ""
    array set argsA $args

    if {$jprefs(gchat,syncPres) && ![info exists argsA(-to)]} {
	foreach chattoken [GetTokenList chat] {
	    variable $chattoken
	    upvar 0 $chattoken chatstate

	    set roomjid $chatstate(roomjid)
	    if {[IsInRoom $roomjid]} {
		::Jabber::SetStatus $show -to $roomjid -status $argsA(-status)
		set chatstate(show)    $show
		set chatstate(oldShow) $show
		set chatstate(show+status)    [list $show $argsA(-status)]
		set chatstate(oldShow+status) [list $show $argsA(-status)]
	    }
	}
    }
}

# GroupChat::InsertMessage --
# 
#       Puts message in text groupchat window.

proc ::GroupChat::InsertMessage {chattoken from body args} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    array set argsA $args
    
    set xmldata $argsA(-xmldata)

    set w       $chatstate(w)
    set wtext   $chatstate(wtext)
    set roomjid $chatstate(roomjid)
            
    # This can be room name or nick name.
    set mynick [::Jabber::JlibCmd service mynick $roomjid]
    set myroomjid $roomjid/$mynick
    if {[jlib::jidequal $myroomjid $from]} {
	set whom me
	set historyTag send
    } elseif {[string equal $roomjid $from]} {
	set whom sys
	set historyTag recv
    } else {
	set whom they
	set historyTag recv
    }    
    set nick ""
    
    switch -- $whom {
	me - they {
	    set nick [::Jabber::JlibCmd service nick $from]	    
	}
    }
    set history 0
    set secs ""
    
    set stamp [::Jabber::GetDelayStamp $xmldata]
    if {$stamp ne ""} {
	set secs [clock scan $stamp -gmt 1]
	set history 1
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
    
    $wtext mark set insert end
    $wtext configure -state normal
    $wtext insert end $prefix ${whom}pre${htag}
    
    ::Text::ParseMsg groupchat $from $wtext "  $body" ${whom}text${htag}
    $wtext insert end \n
    
    $wtext configure -state disabled
    $wtext see end
    
    # Even though we also receive what we send, denote this with send anyway.
    # This can be used to get our own room JID (nick name).
    ::History::XPutItem $historyTag $roomjid $xmldata
}

proc ::GroupChat::InsertTagString {chattoken str tag} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set wtext $chatstate(wtext)
    
    $wtext mark set insert end
    $wtext configure -state normal

    $wtext insert end $str $tag
    
    $wtext configure -state disabled
    $wtext see end
}

# GroupChat::CloseCmd --
# 
#       This gets called from toplevels -closecommand 

proc ::GroupChat::CloseCmd {wclose} {
    global  wDlgs

    ::Debug 2  "::GroupChat::CloseCmd $wclose"
    
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
    
    ::Debug 2  "::GroupChat::ExitAndClose $chattoken"
        
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

    ::Debug 2  "::GroupChat::Exit $chattoken"

    set roomjid $chatstate(roomjid)
    $jstate(jlib) presence_deregister_ex [namespace code PresenceEvent]  \
      -from2 $roomjid
    if {[::Jabber::IsConnected]} {
	$jstate(jlib) service exitroom $roomjid	
	::hooks::run groupchatExitRoomHook $roomjid

	set nick [::Jabber::JlibCmd service mynick $roomjid]
	set myroomjid $roomjid/$nick
	set attr [list from $myroomjid to $roomjid type unavailable]
	set xmldata [wrapper::createtag "presence" -attrlist $attr]
	::History::XPutItem send $roomjid $xmldata
    }
}

# GroupChat::ExitRoomJID --
# 
#       Just a wrapper for Exit.

proc ::GroupChat::ExitRoomJID {roomjid} {

    set roomjid [jlib::jidmap $roomjid]
    set chattoken [GetTokenFrom chat roomjid $roomjid]
    if {$chattoken ne ""} {
	return [ExitAndClose $chattoken]
    } else {
	return ""
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

proc ::GroupChat::SetNick {chattoken nick} {
    variable $chattoken
    upvar 0 $chattoken chatstate

    set jid $chatstate(roomjid)/$nick
    ::Jabber::JlibCmd service setnick $chatstate(roomjid) $nick \
      -command [list ::GroupChat::SetNickCB $chattoken]
    
    #::Jabber::JlibCmd send_presence -to $jid \
    #  -command [list ::GroupChat::SetNickCB $chattoken]
}

proc ::GroupChat::SetNickCB {chattoken xmldata} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    set from [wrapper::getattribute $xmldata from]
    set type [wrapper::getattribute $xmldata type]
    if {[string equal $type "error"]} {
	set errspec [jlib::getstanzaerrorspec $xmldata]
	set errmsg ""
	if {[llength $errspec]} {
	    set errcode [lindex $errspec 0]
	    set errmsg  [lindex $errspec 1]
	}
	jlib::splitjidex $from roomName - -
	::UI::MessageBox -type ok -icon error -title [mc Error]  \
	  -message [mc mucIQError $roomName $errmsg]
    }    
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

# GroupChat::PresenceEvent --
# 
#       Callback for any presence change related to roomjid and roomjid/*
#       Note that our own "enter presence" comes too early to be detected.
#       
# Some msn components may send presence directly from a room when
# a chat invites you to a multichat:
# <presence 
#     from='r1@msn.jabber.ccc.de/marilund60@hotmail.com' 
#     to='matben@jabber.ccc.de'/>
#     
# Note that a conference service may also be a gateway!

proc ::GroupChat::PresenceEvent {jlibname xmldata} {
    upvar ::Jabber::xmppxmlns xmppxmlns
        
    set from [wrapper::getattribute $xmldata from]
    set type [wrapper::getattribute $xmldata type]
    if {$type eq ""} {
	set type available
    }
    jlib::splitjid $from roomjid nick
        
    set chattoken [GetTokenFrom chat roomjid $roomjid]
    if {$chattoken ne ""} {
	if {[string equal $type "available"]} {
	    SetUser $roomjid $from
	} elseif {[string equal $type "unavailable"]} {
	    RemoveUser $roomjid $from
	}
    
	lappend chatstate(afterids) [after 200 [list  \
	  ::GroupChat::InsertPresenceChange $chattoken $xmldata]]
    
	# When kicked etc. from a MUC room...
	# 
	#  <x xmlns='http://jabber.org/protocol/muc#user'>
	#    <item affiliation='none' role='none'>
	#      <actor jid='fluellen@shakespeare.lit'/>
	#      <reason>Avaunt, you cullion!</reason>
	#    </item>
	#    <status code='307'/>
	#  </x>

	set xE [wrapper::getfirstchild $xmldata x $xmppxmlns(muc,user)]

	# @@@ TODO
    }
}

proc ::GroupChat::InsertPresenceChange {chattoken xmldata} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    upvar ::Jabber::jstate jstate
        
    if {[info exists chatstate(w)] && [winfo exists $chatstate(w)]} {
	
	# Some services send out presence changes automatically.
	# This should only be called if not the room does it.
	set ms [clock clicks -milliseconds]
	if {[expr {$ms - $chatstate(last,sys) < 400}]} {
	    return
	}
	set jid3 [wrapper::getattribute $xmldata from]
	jlib::splitjid $jid3 jid2 res
	if {$res eq ""} {
	    jlib::splitjidex $jid3 node domain res
	    set name $node
	} else {
	    set name $res
	}
	if {$res eq ""} {
	    array set presA [lindex [$jstate(jlib) roster getpresence $jid2] 0]
	} else {
	    array set presA [$jstate(jlib) roster getpresence $jid2 -resource $res]
	}
	set show $presA(-type)
	if {[info exists presA(-show)]} {
	    set show $presA(-show)
	}
	set str [string tolower [::Roster::MapShowToText $show]]
	if {[info exists presA(-status)]} {
	    append str " " $presA(-status)
	}
	InsertMessage $chattoken $chatstate(roomjid) "$name: $str"  \
	  -xmldata $xmldata
    }
}

proc ::GroupChat::AddUsers {chattoken} {
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    upvar ::Jabber::jstate jstate
    
    set roomjid $chatstate(roomjid)
    
    set presenceList [$jstate(jlib) roster getpresence $roomjid -type available]
    foreach pres $presenceList {
	unset -nocomplain presA
	array set presA $pres
	
	set res $presA(-resource)
	if {$res ne ""} {
	    set jid3 $roomjid/$res
	    SetUser $roomjid $jid3
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
#       
# Results:
#       updated UI.

proc ::GroupChat::SetUser {roomjid jid3} {
    global  this

    variable userRoleToStr
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::GroupChat::SetUser roomjid=$roomjid, jid3=$jid3"

    set roomjid [jlib::jidmap $roomjid]
    set jid3    [jlib::jidmap $jid3]

    # If we haven't a window for this thread, make one!
    # @@@ This shouldn't be necessary since we fill in all users when
    #     making the room widget.
    set chattoken [GetTokenFrom chat roomjid $roomjid]
    if {$chattoken eq ""} {
	set chattoken [NewChat $roomjid]
    }       
    variable $chattoken
    upvar 0 $chattoken chatstate
        
    # Don't forget to init the ignore state.
    if {![info exists chatstate(ignore,$jid3)]} {
	set chatstate(ignore,$jid3) 0
    }
    TreeCreateUserItem $chattoken $jid3
}

proc ::GroupChat::GetRoleFromJid {jid3} {
    upvar ::Jabber::jstate jstate
   
    set role ""
    set userElem [$jstate(jlib) roster getx $jid3 "muc#user"]
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
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    variable popMenuDefs
    variable regPopMenuDef
    variable regPopMenuType
            
    set clicked ""
    set jid ""
    set nick [::Jabber::JlibCmd service mynick $chatstate(roomjid)]
    set myjid $chatstate(roomjid)/$nick
    if {[lindex $tag 0] eq "role"} {
	set clicked role
    } elseif {[lindex $tag 0] eq "jid"} {
	set clicked user
	set jid [lindex $tag 1]
	if {[jlib::jidequal $jid $myjid]} {
	    set clicked me
	}
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
    set m $wDlgs(jpopupgroupchat)
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
	set mynick [::Jabber::JlibCmd service mynick $roomjid]
	set myroomjid $roomjid/$mynick
	set fd [open $ans w]
	fconfigure $fd -encoding utf-8
	puts $fd "Groupchat in:\t$roomjid"
	puts $fd "Subject:     \t$chatstate(subject)"
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

proc ::GroupChat::Whiteboard {dlgtoken} {

    set chattoken [GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate

   ::JWB::NewWhiteboardTo $chatstate(roomjid)
}

proc ::GroupChat::Print {dlgtoken} {

    set chattoken [GetActiveChatToken $dlgtoken]
    variable $chattoken
    upvar 0 $chattoken chatstate
    
    ::UserActions::DoPrintText $chatstate(wtext) 
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
	SetLogout $chattoken
	::hooks::run groupchatExitRoomHook $chatstate(roomjid)
    }
}

proc ::GroupChat::LoginHook { } {
    
    # @@@ Perhaps we should autojoin any open groupchat dialogs?
    
    foreach chattoken [GetTokenList chat] {
	variable $chattoken
	upvar 0 $chattoken chatstate

	$chatstate(wbtstatus) state {!disabled}
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

# --- Support for XEP-0048 ---
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
    set nick [$jstate(jlib) service mynick $roomjid]
    
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

proc ::GroupChat::OnMenuBookmark { } {
    if {[llength [grab current]]} { return }
    if {[::JUI::GetConnectState] eq "connectfin"} {
	EditBookmarks
    }   
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
      0 [mc {Auto Join}]]

    set bookmarksVar {}
    ::Bookmarks::Dialog $dlg [namespace current]::bookmarksVar  \
      -menu $m -geovariable prefs(winGeom,$dlg) -columns $columns  \
      -command [namespace current]::BookmarksDlgSave
    ::UI::SetMenubarAcceleratorBinds $dlg $m
    
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
