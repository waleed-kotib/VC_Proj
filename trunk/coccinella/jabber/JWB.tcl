#  JWB.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It provides the glue between jabber and the whiteboard.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: JWB.tcl,v 1.38 2004-10-26 12:46:51 matben Exp $

package require can2svgwb
package require svgwb2can

package provide JWB 1.0

# The ::Jabber::WB:: namespace -------------------------------------------------

namespace eval ::Jabber::WB:: {
       
    ::hooks::register jabberInitHook               ::Jabber::WB::Init
    
    # Internal storage for jabber specific parts of whiteboard.
    variable jwbstate
    
    # Cache for get/put ip addresses. 
    variable ipCache
    set ipCache(getid) 1000
            
    variable initted 0
    variable xmlnsSVGWB "http://jabber.org/protocol/svgwb"
}

proc ::Jabber::WB::Init {jlibName} {
    global  this prefs
    variable xmlnsSVGWB
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::coccixmlns coccixmlns
    
    ::Debug 4 "::Jabber::WB::Init"
    
    ::hooks::register whiteboardPreBuildHook       ::Jabber::WB::PreBuildHook
    ::hooks::register whiteboardPostBuildHook      ::Jabber::WB::PostBuildHook
    ::hooks::register whiteboardBuildEntryHook     ::Jabber::WB::BuildEntryHook
    ::hooks::register whiteboardSetMinsizeHook     ::Jabber::WB::SetMinsizeHook    
    ::hooks::register whiteboardCloseHook          ::Jabber::WB::CloseHook        20
    ::hooks::register whiteboardSendMessageHook    ::Jabber::WB::SendMessageListHook
    ::hooks::register whiteboardSendGenMessageHook ::Jabber::WB::SendGenMessageListHook
    ::hooks::register whiteboardPutFileHook        ::Jabber::WB::PutFileOrScheduleHook
    ::hooks::register whiteboardConfigureHook      ::Jabber::WB::Configure
    ::hooks::register serverPutRequestHook         ::Jabber::WB::HandlePutRequest
    ::hooks::register presenceHook                 ::Jabber::WB::PresenceHook

    #       OUTDATED!!!
    ::hooks::register autobrowsedCoccinellaHook    ::Jabber::WB::AutoBrowseHook
    
    ::hooks::register loginHook                    ::Jabber::WB::LoginHook
    ::hooks::register logoutHook                   ::Jabber::WB::LogoutHook
    ::hooks::register groupchatEnterRoomHook       ::Jabber::WB::EnterRoomHook
    ::hooks::register groupchatExitRoomHook        ::Jabber::WB::ExitRoomHook

    # Configure the Tk->SVG translation to use http.
    # Must be reconfigured when we know our address after connecting???
    set ip [::Network::GetThisPublicIPAddress]
    can2svg::config                      \
      -uritype http                      \
      -httpaddr ${ip}:$prefs(httpdPort)  \
      -httpbasedir $this(httpdRootPath)  \
      -ovalasellipse 1                   \
      -reusedefs 0                       \
      -allownewlines 1
    #  -filtertags [namespace current]::FilterTags
    
    # Register for the messages we want. Duplicate protocols.
    $jstate(jlib) message_register normal coccinella:wb  \
      [namespace current]::HandleSpecialMessage 20
    $jstate(jlib) message_register chat coccinella:wb  \
      [namespace current]::HandleRawChatMessage
    $jstate(jlib) message_register groupchat coccinella:wb  \
      [namespace current]::HandleRawGroupchatMessage

    $jstate(jlib) message_register normal $coccixmlns(whiteboard)  \
      [namespace current]::HandleSpecialMessage 20
    $jstate(jlib) message_register chat $coccixmlns(whiteboard)  \
      [namespace current]::HandleRawChatMessage
    $jstate(jlib) message_register groupchat $coccixmlns(whiteboard)  \
      [namespace current]::HandleRawGroupchatMessage

    # Not completed SVG protocol...
    $jstate(jlib) message_register chat $xmlnsSVGWB \
      [namespace current]::HandleSVGWBChatMessage
    $jstate(jlib) message_register groupchat $xmlnsSVGWB \
      [namespace current]::HandleSVGWBGroupchatMessage

    ::Jabber::AddClientXmlns [list "coccinella:wb"]
    
    # Get protocol handlers, present and future.
    GetRegisteredHandlers
    
    # Add Advanced Message Processing elements. <amp/>
    # Deliver only to specified resource, and do not store offline?
    variable ampElem
    set rule1 [wrapper::createtag "rule"  \
      -attrlist {condition deliver-at value stored action error}]
    set rule2 [wrapper::createtag "rule"  \
      -attrlist {condition match-resource value exact action error}]
    set ampElem [wrapper::createtag "amp" -attrlist \
      {xmlns http://jabber.org/protocol/amp} -subtags [list $rule2]]
}

proc ::Jabber::WB::InitUI { } {
    global  prefs
    variable initted
    
    ::Debug 2 "::Jabber::WB::InitUI"

    set buttonTrayDefs {
	save       {::CanvasFile::SaveCanvasFileDlg $wtop}
	open       {::CanvasFile::OpenCanvasFileDlg $wtop}
	import     {::Import::ImportImageOrMovieDlg $wtop}
	send       {::Jabber::WB::DoSendCanvas $wtop}
	print      {::UserActions::DoPrintCanvas $wtop}
	stop       {::Jabber::WB::Stop $wtop}
    }
    ::WB::SetButtonTrayDefs $buttonTrayDefs

    set menuDefsFile {
	{command   mNew                {::WB::NewWhiteboard}             normal   N}
	{command   mCloseWindow        {::UI::DoCloseWindow}             normal   W}
	{separator}
	{command   mOpenImage/Movie    {::Import::ImportImageOrMovieDlg $wtop}    normal   I}
	{command   mOpenURLStream      {::Multicast::OpenMulticast $wtop}     normal   {}}
	{command   mStopPut/Get/Open   {::Jabber::WB::Stop $wtop}        normal {}}
	{separator}
	{command   mOpenCanvas         {::CanvasFile::OpenCanvasFileDlg $wtop}     normal   O}
	{command   mSaveCanvas         {::CanvasFile::SaveCanvasFileDlg $wtop}     normal   S}
	{separator}
	{command   mSaveAs             {::CanvasCmd::SavePostscript $wtop}      normal   {}}
	{command   mSaveAsItem         {::CanvasCmd::DoSaveAsItem $wtop}       normal   {}}
	{command   mPageSetup          {::UserActions::PageSetup $wtop}           normal   {}}
	{command   mPrintCanvas        {::UserActions::DoPrintCanvas $wtop}       normal   P}
	{separator}
	{command   mQuit               {::UserActions::DoQuit}                    normal   Q}
    }

    if {![::Plugins::HavePackage QuickTimeTcl]} {
	lset menuDefsFile 4 3 disabled
    } else {
	package require Multicast
    }
    # If embedded the embedding app should close us down.
    if {$prefs(embedded)} {
	lset menuDefsFile end 3 disabled
    }
    
    # Get any registered menu entries.
    # I don't like this solution!
    set insertInd [expr [llength $menuDefsFile] - 1]
    set mdef [::UI::Public::GetRegisteredMenuDefs file]
    if {$mdef != ""} {
	set menuDefsFile [linsert $menuDefsFile $insertInd {separator}]
	set menuDefsFile [linsert $menuDefsFile $insertInd $mdef]
    }
    ::WB::SetMenuDefs file $menuDefsFile

    set initted 1
}

proc ::Jabber::WB::NewWhiteboard {args} {
    variable jwbstate
    variable initted
    
    if {!$initted} {
	InitUI
    }    

    array set argsArr $args
    if {[info exists argsArr(-wtop)]} {
	set wtop $argsArr(-wtop)
    } else {
	set wtop [::WB::GetNewToplevelPath]
    }
    set jwbstate($wtop,type) normal
    set jwbstate($wtop,send) 0
    set jwbstate($wtop,jid)  ""
    set restargs {}

    foreach {key value} $args {
	
	switch -- $key {
	    -wtop {
		continue
	    }
	    -jid {
		set jwbstate($wtop,jid) [jlib::jidmap $value]
	    }
	    -send - -type {
		set jwbstate($wtop,[string trimleft $key -]) $value
	    }
	    default {
		lappend restargs $key $value
	    }
	}
    }
    eval {::WB::BuildWhiteboard $wtop} $restargs
    
    if {[info exists argsArr(-state)] && ($argsArr(-state) == "disabled")} {
	$jwbstate($wtop,wjid)  configure -state disabled
	$jwbstate($wtop,wsend) configure -state disabled
    }
}

# Jabber::WB::NewWhiteboardTo --
#
#       Starts a new whiteboard session.
#       
# Arguments:
#       jid         jid, usually 3-tier, but should be 2-tier if groupchat.
#       args        -thread, -from, -to, -type, -x
#                   -force: creates whiteboard even if not in room
#       
# Results:
#       none

proc ::Jabber::WB::NewWhiteboardTo {jid args} {
    variable initted
    variable delayed
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::WB::NewWhiteboardTo jid=$jid, args='$args'"
    
    array set argsArr {
	-state   normal
	-jid     ""
	-type    normal
	-send    0
	-force   0
    }
    array set argsArr $args
    
    if {!$initted} {
	InitUI
    }
    set force $argsArr(-force)
    unset argsArr(-force)

    # Make a fresh whiteboard window. Use any -type argument.
    # Note that the jid can belong to a room but we may still have a p2p chat.
    #    jid is room: groupchat live
    #    jid is a user in a room: chat
    #    jid is ordinary available user: chat
    #    jid is ordinary but unavailable user: normal message

    set jid [jlib::jidmap $jid]
    jlib::splitjid $jid jid2 res
    set isRoom 0
    if {[string equal $argsArr(-type) "groupchat"]} {
	set isRoom 1
    } elseif {[$jstate(jlib) service isroom $jid]} {
	set isRoom 1
    }
    set isUserInRoom 0
    if {[$jstate(jlib) service isroom $jid2] && [string length $res]} {
	set isUserInRoom 1
    }
    set isAvailable [$jstate(roster) isavailable $jid]
    
    ::Debug 2 "\t isRoom=$isRoom, isUserInRoom=$isUserInRoom, isAvailable=$isAvailable"

    set doBuild 1
    set argsArr(-jid) $jid
    
    if {$isRoom} {
	
	# Must enter room in the usual way if not there already.
	set inrooms [$jstate(jlib) service allroomsin]
	::Debug 4 "\t inrooms=$inrooms"
	
	set roomName [$jstate(jlib) service name $jid]
	if {[llength $roomName]} {
	    set title "Groupchat room $roomName"
	} else {
	    set title "Groupchat room $jid"
	}
	set argsArr(-title) $title
	set argsArr(-type)  groupchat
	set argsArr(-send)  1
	if {!$force && ([lsearch $inrooms $jid] < 0)} {
	    set ans [::Jabber::GroupChat::EnterOrCreate enter -roomjid $jid \
	      -autoget 1]
	    if {$ans == "cancel"} {
		Free $wtop
		return ""
	    }
	    set doBuild 0
	}
	
	# Set flag for delayed create.
	set delayed($jid,jid)  1
	set delayed($jid,args) [array get argsArr]
    } elseif {$isAvailable || $isUserInRoom} {
	
	# Two person whiteboard chat.
	if {[info exists argsArr(-thread)]} {
	    set thread $argsArr(-thread)
	} else {
	    set thread [::sha1pure::sha1 "$jstate(mejid)[clock seconds]"]
	}
	set name [$jstate(roster) getname $jid]
	if {[string length $name]} {
	    set title "Chat with $name"
	} else {
	    set title "Chat with $jid"
	}	
	set argsArr(-title)  $title
	set argsArr(-type)   chat
	set argsArr(-thread) $thread
	set argsArr(-send)   1
    } else {
	
	# Normal whiteboard message.
	set name [$jstate(roster) getname $jid]
	if {[string length $name]} {
	    set title "Send Message to $name"
	} else {
	    set title "Send Message to $jid"
	}
	set argsArr(-title) $title
    }
    
    # This is too early to have a whiteboard for groupchat since we don't
    # know if we succeed to enter.
    set wtop ""
    if {$doBuild} {
	set wtop [eval {::WB::NewWhiteboard} [array get argsArr]]
    }
    return $wtop
}

# Jabber::WB::PreBuildHook, PostBuildHook --
# 
#       Sets up custom state for whiteboard. Called during build process.

proc ::Jabber::WB::PreBuildHook {wtop args} {
    variable jwbstate
    variable initted
    
    ::Debug 4 "::Jabber::WB::PreBuildHook wtop=$wtop, args=$args"
    
    array set argsArr {
	-state   normal
	-jid     ""
	-type    normal
	-send    0
    }
    array set argsArr $args
    foreach {key value} [array get argsArr] {
	set jwbstate($wtop,[string trimleft $key -]) $value
    }
    
    # Be sure to be able to map wtop->jid and jid->wtop.
    set jid [jlib::jidmap $argsArr(-jid)]
    set jwbstate($wtop,jid) $jid
    set jwbstate($jid,jid,wtop) $wtop
    
    # Be sure to be able to map wtop->thread and thread->wtop if chat.
    if {[info exists jwbstate($wtop,thread)]} {
	set thread $jwbstate($wtop,thread)
	set jwbstate($thread,thread,wtop) $wtop
    }
    if {!$initted} {
	InitUI
    }    
}

proc ::Jabber::WB::PostBuildHook {wtop} {
    variable jwbstate
       
    ::Debug 4 "::Jabber::WB::PostBuildHook wtop=$wtop"
    
    if {$jwbstate($wtop,state) == "disabled"} {
	$jwbstate($wtop,wjid)  configure -state disabled
	$jwbstate($wtop,wsend) configure -state disabled
    }
}

# ::Jabber::WB::EnterRoomHook --
# 
#       We create only whiteboard if enter succeeds.

proc ::Jabber::WB::EnterRoomHook {roomjid protocol} {
    variable delayed
    
    ::Debug 4 "::Jabber::WB::EnterRoomHook roomjid=$roomjid"
    
    if {[info exists delayed($roomjid,jid)]} {
	eval {::WB::NewWhiteboard} $delayed($roomjid,args)
	array unset delayed $roomjid,*
    }
}

# ::Jabber::WB::BuildEntryHook --
# 
#       Build the jabber specific part of the whiteboard.

proc ::Jabber::WB::BuildEntryHook {wtop wclass wcomm} {
    variable jwbstate
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::WB::BuildEntryHook wcomm=$wcomm"
	
    set contactOffImage [::Theme::GetImage \
      [option get $wclass contactOffImage {}]]
    set contactOnImage  [::Theme::GetImage \
      [option get $wclass contactOnImage {}]]
    set iconResize      [::Theme::GetImage \
      [option get $wclass resizeHandleImage {}]]

    set jidlist [$jstate(roster) getusers]

    set wframe $wcomm.f
    frame $wframe -relief raised -borderwidth 1
    pack  $wframe -side bottom -fill x

    label $wframe.ljid -text "  [mc {Jabber Id}]:"
    ::entrycomp::entrycomp $wframe.ejid $jidlist -relief sunken \
      -textvariable [namespace current]::jwbstate($wtop,jid)
    checkbutton $wframe.to -highlightthickness 0 -state disabled \
      -text [mc {Send Live}] \
      -variable [namespace current]::jwbstate($wtop,send)
    if {[::Jabber::IsConnected]} {
	label $wframe.icon -image $contactOnImage
    } else {
	label $wframe.icon -image $contactOffImage
    }

    # Resize handle.
    frame $wframe.pad
    label $wframe.pad.hand -relief flat -borderwidth 0 -image $iconResize
    pack  $wframe.pad.hand -side right -anchor sw
    
    pack $wframe.ljid -side left
    pack $wframe.pad  -side right -fill both
    pack $wframe.icon -side right
    pack $wframe.to   -side right -padx 6
    pack $wframe.ejid -side right -fill x -expand true
     
    # Cache widgets paths.
    set jwbstate($wtop,wclass)    $wclass
    set jwbstate($wtop,wframe)    $wframe
    set jwbstate($wtop,wfrja)     $wframe
    set jwbstate($wtop,wjid)      $wframe.ejid
    set jwbstate($wtop,wsend)     $wframe.to
    set jwbstate($wtop,wcontact)  $wframe.icon
    
    # Fix widget states.
    set netstate logout
    if {[::Jabber::IsConnected]} {
	set netstate login
    }
    SetStateFromType $wtop
    SetNetworkState  $wtop $netstate
}

# Jabber::WB::SetStateFromType --
# 
# 

proc ::Jabber::WB::SetStateFromType {wtop} {
    variable jwbstate
    
    switch -- $jwbstate($wtop,type) {
	normal {
	    set jwbstate($wtop,send) 0
	}
	chat - groupchat {
	    set wtray [::WB::GetButtonTray $wtop]
	    $wtray buttonconfigure send -state disabled
	    set jwbstate($wtop,send) 1
	    $jwbstate($wtop,wjid) configure -state disabled
	}
    }
}

# Jabber::WB::SetNetworkState --
# 
#       Sets the state of all jabber specific ui parts of whiteboard when
#       login/logout.

proc ::Jabber::WB::SetNetworkState {wtop what} {
    variable jwbstate
    
    set wclass   $jwbstate($wtop,wclass)
    set wcontact $jwbstate($wtop,wcontact)
    array set optsArr [::WB::ConfigureMain $wtop]
    
    switch -- $what {
	login {
	    set server [::Jabber::GetServerJid]
	    if {$jwbstate($wtop,jid) == ""} {
		set jwbstate($wtop,jid) "@${server}"
	    }
	    
	    switch -- $jwbstate($wtop,type) {
		chat - groupchat {
		    #$jwbstate($wtop,wsend) configure -state normal
		}
		default {
		    if {$optsArr(-state) == "normal"} {
			set wtray [::WB::GetButtonTray $wtop]
			$wtray buttonconfigure send -state normal
		    }
		}
	    }
	    set contactOnImage  [::Theme::GetImage \
	      [option get $wclass contactOnImage {}]]
	    after 400 [list $wcontact configure -image $contactOnImage]
	}
	logout {
	    set wtray [::WB::GetButtonTray $wtop]
	    $wtray buttonconfigure send -state disabled
	    $jwbstate($wtop,wsend) configure -state disabled
	    set contactOffImage [::Theme::GetImage \
	       [option get $wclass contactOffImage {}]]
	     after 400 [list $wcontact configure -image $contactOffImage]
	}
    }
}

proc ::Jabber::WB::SetMinsizeHook {wtop} {
    
    # It is our responsibilty to set new minsize since we have added stuff.
    after idle ::Jabber::WB::SetMinsize $wtop
}

proc ::Jabber::WB::SetMinsize {wtop} {
    variable jwbstate

    if {[string equal $wtop "."]} {
	set w .
    } else {
	set w [string trimright $wtop .]
    }
    
    foreach {wMin hMin} [::WB::GetBasicWhiteboardMinsize $wtop] break
    set wMinEntry [winfo reqwidth  $jwbstate($wtop,wfrja)]
    set hMinEntry [winfo reqheight $jwbstate($wtop,wframe)]
    set wMin [max $wMin $wMinEntry]
    set hMin [expr $hMin + $hMinEntry]
    wm minsize $w $wMin $hMin
}

# Jabber::WB::Stop --
#
#       It is supposed to stop every put and get operation taking place.
#       This may happen when the user presses a stop button or something.
#       
# Arguments:
#
# Results:

proc ::Jabber::WB::Stop {wtop} {
    variable jwbstate
    
    switch -- $jwbstate($wtop,type) {
	chat - groupchat {
	    ::GetFileIface::CancelAllWtop $wtop
	    ::Import::HttpResetAll $wtop
	}
	default {
	    ::Import::HttpResetAll $wtop
	}
    }
    ::WB::SetStatusMessage $wtop {}
    ::WB::StartStopAnimatedWave $wtop 0
}

# Jabber::WB::LoginHook --
# 
#       The login hook command.

proc ::Jabber::WB::LoginHook { } {
    
    # Multiinstance whiteboard UI stuff.
    foreach w [::WB::GetAllWhiteboards] {
	set wtop [::UI::GetToplevelNS $w]
	SetNetworkState $wtop login
    }
}


proc ::Jabber::WB::LogoutHook { } {
    variable delayed
    
    unset -nocomplain delayed
    foreach w [::WB::GetAllWhiteboards] {
	set wtop [::UI::GetToplevelNS $w]
	SetNetworkState $wtop logout
    }    
}

proc ::Jabber::WB::CloseHook {wtop} {
    variable jwbstate
    
    ::Debug 2 "::Jabber::WB::CloseHook wtop=$wtop"
    
    if {$wtop == "."} {
	set w .
    } else {
	set w [string trimright $wtop .]
    }
    
    switch -- $jwbstate($wtop,type) {
	chat {
	    set ans [tk_messageBox -icon info -parent $w -type yesno \
	      -message [FormatTextForMessageBox [mc jamesswbchatlost]]]
	    if {$ans != "yes"} {
		return stop
	    }
	}
	groupchat {
	    
	    # Everything handled from Jabber::GroupChat
	    set ans [::Jabber::GroupChat::ExitRoom $jwbstate($wtop,jid)]
	    if {$ans != "yes"} {
		return stop
	    }
	}
	default {
	    # empty
	}
    }
    Free $wtop
}

proc ::Jabber::WB::ExitRoomHook {roomJid} {
    variable jwbstate
    
    set wtop [GetWtopFromMessage groupchat $roomJid]
    if {[string length $wtop]} {
	::WB::CloseWhiteboard $wtop
	Free $wtop
    }
}

# Various procs for sending wb messages ........................................

# Jabber::WB::SendMessageHook --
#
#       This is just a shortcut for sending a message. 
#       
# Arguments:
#       wtop
#       msg         canvas command without the widgetPath or CANVAS: prefix.
#       args        ?-key value ...?
#                   -force 0|1   (D=0) override doSend checkbutton?
#       
# Results:
#       none.

proc ::Jabber::WB::SendMessageHook {wtop msg args} {
    variable jwbstate
    
    ::Debug 2 "::Jabber::WB::SendMessageHook"
    
    # Check that still connected to server.
    if {![::Jabber::IsConnected]} {
	return
    }
    
    # Check that still online if chat!
    if {![CheckIfOnline $wtop]} {
	return
    }
    array set opts {-force 0}
    array set opts $args
        
    if {$jwbstate($wtop,send) || $opts(-force)} {
	if {[VerifyJIDWhiteboard $wtop]} {
	    
	    # Here we shall decide the 'type' of message sent (normal, chat, groupchat)
	    # depending on the type of whiteboard (via wtop).
	    set argsList [SendArgs $wtop]
	    set jid $jwbstate($wtop,jid)
	    
	    eval {SendMessage $wtop $jid $msg} $argsList
	} else {
	    
	    # Perhaps we should give some aid here; set focus?
	}
    }
    return {}
}

# Jabber::WB::SendMessageListHook --
#
#       As above but for a list of commands.

proc ::Jabber::WB::SendMessageListHook {wtop msgList args} {
    variable jwbstate
    
    ::Debug 2 "::Jabber::WB::SendMessageListHook msgList=$msgList; $args"
    
    if {![::Jabber::IsConnected]} {
	return
    }

    # Check that still online if chat!
    if {![CheckIfOnline $wtop]} {
	return
    }
    array set opts {-force 0}
    array set opts $args
    
    if {$jwbstate($wtop,send) || $opts(-force)} {
	if {[VerifyJIDWhiteboard $wtop]} {
	    set jid $jwbstate($wtop,jid)
	    set argsList [SendArgs $wtop]
	    eval {SendMessageList $wtop $jid $msgList} $argsList
	} else {
	    
	    # Perhaps we should give some aid here; set focus?
	}
    }
    return {}
}

# Jabber::WB::SendGenMessageListHook --
# 
#       As above but includes a prefix in each message from the old
#       protocol. BAD!!!

proc ::Jabber::WB::SendGenMessageListHook {wtop msgList args} {
    variable jwbstate
    
    ::Debug 2 "::Jabber::WB::SendGenMessageListHook"
    
    if {![::Jabber::IsConnected]} {
	return
    }

    # Check that still online if chat!
    if {![CheckIfOnline $wtop]} {
	return
    }
    array set opts {-force 0}
    array set opts $args

    if {$jwbstate($wtop,send) || $opts(-force)} {
	if {[VerifyJIDWhiteboard $wtop]} {
	    set jid $jwbstate($wtop,jid)
	    set argsList [SendArgs $wtop]
	    eval {SendRawMessageList $jid $msgList} $argsList
	}    
    }
    return {}
}

proc ::Jabber::WB::SendArgs {wtop} {
    variable jwbstate

    set argsList {}
    set type $jwbstate($wtop,type)
    if {[string equal $type "normal"]} {
	set type ""
    }
    if {[llength $type] > 0} {
	lappend argsList -type $type
	if {[string equal $type "chat"]} {
	    lappend argsList -thread $jwbstate($wtop,thread)
	}
    }
    return $argsList
}

proc ::Jabber::WB::CheckIfOnline {wtop} {
    variable jwbstate
    upvar ::Jabber::jstate jstate

    set isok 1
    if {[string equal $jwbstate($wtop,type) "chat"]} {
	set isok [$jstate(roster) isavailable $jwbstate($wtop,jid)]
	if {!$isok} {
	    tk_messageBox -type ok -icon warning \
	      -parent [string trimright $wtop .] \
	      -message [mc jamesschatoffline]
	}
    }
    return $isok
}

# Jabber::WB::SendMessage --
#
#       Actually send whiteboard commands as messages.
#       
# Arguments:
#       jid
#       msg
#       args    ?-key value? list to use for 'send_message'.
#       
# Results:
#       none.

proc ::Jabber::WB::SendMessage {wtop jid msg args} {    
    upvar ::Jabber::jstate jstate
    
    set xlist [CanvasCmdListToMessageXElement $wtop [list $msg]]
    if {[catch {
	eval {$jstate(jlib) send_message $jid -xlist $xlist} $args
    } err]} {
	::Jabber::DoCloseClientConnection
	tk_messageBox -title [mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox $err]
    }
}

# Jabber::WB::SendMessageList --
#
#       As above but for a list of commands.

proc ::Jabber::WB::SendMessageList {wtop jid msgList args} {
    upvar ::Jabber::jstate jstate
    
    set xlist [CanvasCmdListToMessageXElement $wtop $msgList]
    if {[catch {
	eval {$jstate(jlib) send_message $jid -xlist $xlist} $args
    } err]} {
	::Jabber::DoCloseClientConnection
	tk_messageBox -title [mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox $err]
    }
}

# Jabber::WB::SendRawMessageList --
# 
#       Handles any prefixed canvas command using the "raw" protocol.

proc ::Jabber::WB::SendRawMessageList {jid msgList args} {
    upvar ::Jabber::jstate jstate
 
    # Form an <x xmlns='coccinella:wb'><raw> element in message.
    set subx {}
    foreach cmd $msgList {
	lappend subx [wrapper::createtag "raw" -chdata $cmd]
    }
    set xlist [list [wrapper::createtag x -attrlist  \
      {xmlns coccinella:wb} -subtags $subx]]

    if {[catch {
	eval {$jstate(jlib) send_message $jid -xlist $xlist} $args
    } err]} {
	::Jabber::DoCloseClientConnection
	tk_messageBox -title [mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox $err]
    }    
}

# Jabber::WB::CanvasCmdListToMessageXElement --
# 
#       Takes a list of canvas commands and returns the xml
#       x element xmllist appropriate.
#       
# Arguments:
#       cmdList     a list of canvas commands without the widgetPath.
#                   no CANVAS:

proc ::Jabber::WB::CanvasCmdListToMessageXElement {wtop cmdList} {
    variable xmlnsSVGWB
    variable ampElem
    upvar ::Jabber::jprefs jprefs
    
    if {$jprefs(useSVGT)} {
	
	# Form SVG element.
	set subx {}
	set wcan [::WB::GetCanvasFromWtop $wtop]
	foreach cmd $cmdList {
	    set cmd [::CanvasUtils::FontHtmlToPixelSize $cmd]
	    set subx [concat $subx \
	      [can2svgwb::svgasxmllist $cmd -usestyleattribute 0 -canvas $wcan \
	      -unknownimporthandler ::CanvasUtils::GetSVGForeignFromImportCmd]]
	}
	set xlist [list [wrapper::createtag x -attrlist  \
	  [list xmlns $xmlnsSVGWB] -subtags $subx]]
    } else {
    
	# Form an <x xmlns='coccinella:wb'><raw> element in message.
	set subx {}
	foreach cmd $cmdList {
	    lappend subx [wrapper::createtag "raw" -chdata "CANVAS: $cmd"]
	}
	set xlist [list [wrapper::createtag x -attrlist  \
	  {xmlns coccinella:wb} -subtags $subx]]
    }
    
    # amp element for message processing directives.
    # Perhaps we should conserve bandwidth by skipping it?
    # 
    # Needs more testing...
    # lappend xlist $ampElem
    return $xlist
}

# Jabber::WB::DoSendCanvas --
# 
#       Wrapper for ::CanvasCmd::DoSendCanvas.

proc ::Jabber::WB::DoSendCanvas {wtop} {
    global  prefs
    variable jwbstate
    upvar ::Jabber::jstate jstate

    set wtoplevel [::UI::GetToplevel $wtop]
    set jid $jwbstate($wtop,jid)

    if {[jlib::jidvalidate $jid]} {
		
	# If user not online no files may be sent off.
	if {![$jstate(roster) isavailable $jid]} {
	    set ans [tk_messageBox -icon warning -type yesno  \
	      -parent $wtoplevel  \
	      -message [FormatTextForMessageBox "The user you are sending to,\
	      \"$jid\", is not online, and if this message contains any images\
	      or other similar entities, this user will not get them unless\
	      you happen to be online while this message is being read.\
	      Do you want to send it anyway?"]]
	    if {$ans == "no"} {
		return
	    }
	}
	::CanvasCmd::DoSendCanvas $wtop
	::WB::CloseWhiteboard     $wtop
    } else {
	tk_messageBox -icon warning -type ok -parent $wtoplevel -message \
	  [FormatTextForMessageBox [mc jamessinvalidjid]]
    }
}


proc ::Jabber::WB::FilterTags {tags} {
    
    return [::CanvasUtils::GetUtagFromTagList $tags]
}

# Various message handlers......................................................

# Jabber::WB::HandleSpecialMessage --
# 
#       Takes care of any special (BAD) commands from the old protocol.

proc ::Jabber::WB::HandleSpecialMessage {jlibname xmlns args} {
        
    ::Debug 2 "::Jabber::WB::HandleSpecialMessage $xmlns, args=$args"
    array set argsArr $args
        
    set rawList [GetRawMessageList $argsArr(-x) $xmlns]
    set ishandled 1
    foreach raw $rawList {
	
	switch -glob -- $raw {
	    "GET IP:*" {
		if {[regexp {^GET IP: +([^ ]+)$} $raw m id]} {
		    PutIPnumber $argsArr(-from) $id
		}
	    }
	    "PUT IP:*" {
		    
		# We have got the requested ip number from the client.
		if {[regexp {^PUT IP: +([^ ]+) +([^ ]+)$} $raw m id ip]} {
		    GetIPCallback $argsArr(-from) $id $ip
		}		
	    }	
	    "CANVAS:*" {		
		# Let these through.
		set ishandled 0
		continue
	    }
	    default {
		# Junk.
	    }
	}
    }
    
    # We have handled this message completely.
    return $ishandled
}

# Jabber::WB::HandleRawChatMessage --
# 
#       This is the dispatcher for "raw" chat whiteboard messages using the
#       CANVAS: (and RESIZE IMAGE: etc.) prefixed drawing commands.

proc ::Jabber::WB::HandleRawChatMessage {jlibname xmlns args} {
        
    ::Debug 2 "::Jabber::WB::HandleRawChatMessage args=$args"
    array set argsArr $args
        
    set cmdList [GetRawMessageList $argsArr(-x) $xmlns]
    set cmdList [eval {HandleNonCanvasCmds chat $cmdList} $args]

    eval {ChatMsg $cmdList} $args
    eval {::hooks::run newWBChatMessageHook} $args
    
    # We have handled this message completely.
    return 1
}

# Jabber::WB::HandleRawGroupchatMessage --
# 
#       This is the dispatcher for "raw" chat whiteboard messages using the
#       CANVAS: (and RESIZE IMAGE: etc.) prefixed drawing commands.

proc ::Jabber::WB::HandleRawGroupchatMessage {jlibname xmlns args} {
	
    ::Debug 2 "::Jabber::WB::HandleRawGroupchatMessage args=$args"	
    array set argsArr $args
    
    # Do not duplicate ourselves!
    if {![::Jabber::IsMyGroupchatJid $argsArr(-from)]} {
	set cmdList [GetRawMessageList $argsArr(-x) $xmlns]
	set cmdList [eval {HandleNonCanvasCmds groupchat $cmdList} $args]

	eval {GroupChatMsg $cmdList} $args
	eval {::hooks::run newWBGroupChatMessageHook} $args
    }
    
    # We have handled this message completely.
    return 1
}

proc ::Jabber::WB::HandleSVGWBChatMessage {jlibname xmlns args} {
    
    ::Debug 2 "::Jabber::WB::HandleSVGWBChatMessage"
    array set argsArr $args
	
    # Need to have the actual canvas before doing svg -> canvas translation.
    # This is a duplicate; fix later...
    set wtop [eval {GetWtopFromMessage chat $argsArr(-from)} $args]
    if {$wtop == ""} {
	set wtop [eval {NewWhiteboardTo $argsArr(-from)} $args]
    }
    
    set cmdList [GetSVGWBMessageList $wtop $argsArr(-x)]
    if {[llength $cmdList]} {
	eval {ChatMsg $cmdList} $args
	eval {::hooks::run newWBChatMessageHook} $args
    }
    
    # We have handled this message completely.
    return 1
}

proc ::Jabber::WB::HandleSVGWBGroupchatMessage {jlibname xmlns args} {
    
    ::Debug 2 "::Jabber::WB::HandleSVGWBGroupchatMessage"
    array set argsArr $args
    
    # Need to have the actual canvas before doing svg -> canvas translation.
    # This is a duplicate; fix later...
    jlib::splitjid $argsArr(-from) roomjid resource
    set wtop [GetWtopFromMessage groupchat $roomjid]
    if {$wtop == ""} {
	set wtop [eval {NewWhiteboardTo $roomjid -force 1} $args]
    }
    
    # Do not duplicate ourselves!
    if {![::Jabber::IsMyGroupchatJid $argsArr(-from)]} {
	set cmdList [GetSVGWBMessageList $wtop $argsArr(-x)]
	
	if {[llength $cmdList]} {
	    eval {GroupChatMsg $cmdList} $args
	    eval {::hooks::run newWBGroupChatMessageHook} $args
	}
    }
        
    # We have handled this message completely.
    return 1
}

# Jabber::WB::GetRawMessageList --
# 
#       Extracts the raw canvas drawing commands from an x list elements.
#       
# Arguments:
#       xlist       list of x elements.
#       xmlns       the xml namespace to look for
#       
# Results:
#       a list of raw element drawing commands, or empty. Keeps CANVAS: prefix.

proc ::Jabber::WB::GetRawMessageList {xlist xmlns} {
    
    set rawElemList {}
    
    foreach xelem $xlist {
	array set attrArr [wrapper::getattrlist $xelem]
	if {[string equal $attrArr(xmlns) $xmlns]} {
	    foreach xraw [wrapper::getchildren $xelem] {
		if {[string equal [wrapper::gettag $xraw] "raw"]} {
		    lappend rawElemList [wrapper::getcdata $xraw]
		}	
	    }
	}
    }
    return $rawElemList
}

# Jabber::WB::GetRawCanvasMessageList --
# 
#       As above but skips the CANVAS: prefix. Assumes CANVAS: prefix!

proc ::Jabber::WB::GetRawCanvasMessageList {xlist xmlns} {
    
    set cmdList {}
    
    foreach xelem $xlist {
	array set attrArr [wrapper::getattrlist $xelem]
	if {[string equal $attrArr(xmlns) $xmlns]} {
	    foreach xraw [wrapper::getchildren $xelem] {
		if {[string equal [wrapper::gettag $xraw] "raw"]} {
		    lappend cmdList [lrange [wrapper::getcdata $xraw] 1 end]
		}	
	    }
	}
    }
    return $cmdList
}

# Jabber::WB::GetSVGWBMessageList --
# 
#       Translates the SVGWB protocol to a list of canvas commands.
#       Needs the canvas widget path for this due to the bad design
#       of the Tk canvas (-fill/-outline needs type when item configure).

proc ::Jabber::WB::GetSVGWBMessageList {wtop xlist} {
    variable xmlnsSVGWB

    set wcan [::WB::GetCanvasFromWtop $wtop]
    set cmdList {}
    
    foreach xelem $xlist {
	array set attrArr [wrapper::getattrlist $xelem]
	if {[string equal $attrArr(xmlns) $xmlnsSVGWB]} {
	    set cmdList [svgwb2can::parsesvgdocument $xelem -canvas $wcan \
	      -foreignobjecthandler \
	      [list [namespace current]::SVGForeignObjectHandler $wtop] \
	      -httphandler [list [namespace current]::SVGHttpHandler $wtop]]
	}
    }
    return $cmdList
}

# Jabber::WB::SVGForeignObjectHandler --
# 
#       The only excuse for this is to add '-where local'.

proc ::Jabber::WB::SVGForeignObjectHandler {wtop xmllist paropts transformList args} {
    
    array set argsArr $args
    set argsArr(-where) local
    eval {::CanvasUtils::SVGForeignObjectHandler $wtop $xmllist $paropts \
      $transformList} [array get argsArr]
}

# Jabber::WB::SVGHttpHandler --
# 
#       Callback for SVG to canvas translator for http uri's.
#       
#       cmd:        create image $x $y -key value ...

proc ::Jabber::WB::SVGHttpHandler {wtop cmd} {
    variable jwbstate
    upvar ::Jabber::jstate jstate
        
    # Design the import line.
    # import 226.0 104.0 -http ... -below */117748804 -tags */117748801
    set line [concat import [lrange $cmd 2 end]]
    set wcan [::WB::GetCanvasFromWtop $wtop]
    
    # We should make sure wtop exists!
    
    # Only if user available shall we try to import.
    set tryimport 0
    # THIS IS NOT A 3-tier JID!!!!!
    set jid3 $jwbstate($wtop,jid)

    if {[$jstate(roster) isavailable $jid3] || \
      [jlib::jidequal $jid3 $jstate(mejidres)]} {
	set tryimport 1
    }
    
    set errMsg [eval {
	 ::Import::HandleImportCmd $wcan $line -where local \
	   -progress [list ::Import::ImportProgress $line] \
	   -command  [list ::Import::ImportCommand $line] \
	   -tryimport $tryimport
     }]

}

# Jabber::WB::HandleNonCanvasCmds --
# 
#       Until we have a better protocol for this handle it here.
#       This really SUCKS!!!
#       Handles RESIZE IMAGE, strips off CANVAS: prefix of rest and returns this.

proc ::Jabber::WB::HandleNonCanvasCmds {type cmdList args} {
    variable handler
    
    ::Debug 4 "::Jabber::WB::HandleNonCanvasCmds type=$type"
    
    set canCmdList {}
    foreach cmd $cmdList {
	regexp {^([^:]+):.*} $cmd match prefix
	
	switch -- $prefix {
	    CANVAS {
		lappend canCmdList [lrange $cmd 1 end]
	    }
	    "RESIZE IMAGE" {
		if {[regexp {^RESIZE IMAGE: +([^ ]+) +([^ ]+) +([-0-9]+)$}  \
		  $cmd match utag utagNew zoom]} {
		    array set argsArr $args
		    set wtop ""
		
		    # Make sure whiteboard exists.
		    switch -- $type {
			chat - groupchat {
			    set wtop [eval {GetWtopFromMessage \
			      $type $argsArr(-from)} $args]
			    if {$wtop == ""} {
				continue
				set wtop [eval {
				    NewWhiteboardTo $argsArr(-from)} $args]
			    }
			}
		    }
		    ::Import::ResizeImage $wtop $zoom $utag $utagNew "local"
		}
	    }
	    default {
		if {[info exists handler($prefix)]} {
		    array set argsArr $args
		    set wtop ""

		    switch -- $type {
			chat - groupchat {
			    set wtop [eval {GetWtopFromMessage \
			      $type $argsArr(-from)} $args]
			}
		    }
		    if {$wtop != ""} {
			set w [::WB::GetCanvasFromWtop $wtop]
			set code [catch {
			    uplevel #0 $handler($prefix) [list $w $type $cmd] $args
			} ans]
		    }
		}
	    }
	}
    }
    return $canCmdList
}

# ::Jabber::WB::GetRegisteredHandlers --
# 
#       Get protocol handlers, present and future.

proc ::Jabber::WB::GetRegisteredHandlers { } {
    variable handler
    
    array set handler [::WB::GetRegisteredHandlers]
    ::hooks::register whiteboardRegisterHandlerHook  ::Jabber::WB::RegisterHandlerHook
}

proc ::Jabber::WB::RegisterHandlerHook {prefix cmd} {
    variable handler
    
    set handler($prefix) $cmd
}

# ::Jabber::WB::ChatMsg, GroupChatMsg --
# 
#       Handles incoming chat/groupchat message aimed for a whiteboard.
#       It may not exist, for instance, if we receive a new chat thread.
#       Then create a specific whiteboard for this chat/groupchat.
#       The commands shall only be CANVAS: types but with no prefix!!!
#       
# Arguments:
#       args        -from, -to, -type, -thread, -x,...

proc ::Jabber::WB::ChatMsg {cmdList args} {    
    upvar ::Jabber::jstate jstate

    array set argsArr $args
    ::Debug 2 "::Jabber::WB::ChatMsg args='$args'"
    
    # This one returns empty if not exists.
    set wtop [eval {GetWtopFromMessage chat $argsArr(-from)} \
      $args]
    if {$wtop == ""} {
	set wtop [eval {NewWhiteboardTo $argsArr(-from)} $args]
    }
    foreach line $cmdList {
	::CanvasUtils::HandleCanvasDraw $wtop $line
    }     
}

proc ::Jabber::WB::GroupChatMsg {cmdList args} {    
    upvar ::Jabber::jstate jstate

    array set argsArr $args
    ::Debug 2 "::Jabber::WB::GroupChatMsg args='$args'"
    
    # The -from argument is either the room itself, or usually a user in
    # the room.
    jlib::splitjid $argsArr(-from) roomjid resource
    set wtop [GetWtopFromMessage groupchat $roomjid]
    if {$wtop == ""} {
	set wtop [eval {NewWhiteboardTo $roomjid -force 1} $args]
    }

    foreach line $cmdList {
	::CanvasUtils::HandleCanvasDraw $wtop $line
    }
}

proc ::Jabber::WB::Free {wtop} {
    variable jwbstate
    variable delayed
    
    catch {
	unset -nocomplain jwbstate($jwbstate($wtop,thread),thread,wtop) \
	  jwbstate($jwbstate($wtop,jid),jid,wtop)
    }
    array unset jwbstate "$wtop,*"    
}

#--- Getting ip addresses ------------------------------------------------------
#
#       These are replaced by extra presence elements in most cases.

# Jabber::WB::GetIPnumber / PutIPnumber --
#
#       Utilites to put/get ip numbers from clients.
#
# Arguments:
#       jid:        fully qualified "username@host/resource".
#       cmd:        (optional) callback command when gets ip number.
#       
# Results:
#       none.

proc ::Jabber::WB::GetIPnumber {jid {cmd {}}} {    
    variable ipCache

    ::Debug 2 "::Jabber::WB::GetIPnumber:: jid=$jid, cmd='$cmd'"
    
    set getid $ipCache(getid)
    if {$cmd != ""} {
	set ipCache(cmd,$getid) $cmd
    }
    set mjid [jlib::jidmap $jid]
    
    # What shall we do when we already have the IP number?
    if {[info exists ipCache(ip,$mjid)]} {
	GetIPCallback $jid $getid $ipCache(ip,$mjid)
    } else {
	SendRawMessageList $jid [list "GET IP: $getid"]
	set ipCache(req,$mjid) 1
    }
    incr ipCache(getid)
}

# Jabber::WB::GetIPCallback --
#
#       This proc gets called when a requested ip number is received
#       by our server.
#
# Arguments:
#       jid     fully qualified  "username@host/resource"
#       id
#       ip
#       
# Results:
#       Any registered callback proc is eval'ed.

proc ::Jabber::WB::GetIPCallback {jid id ip} {    
    upvar ::Jabber::jstate jstate
    variable ipCache

    ::Debug 2 "::Jabber::WB::GetIPCallback: jid=$jid, id=$id, ip=$ip"

    set mjid [jlib::jidmap $jid]
    set ipCache(ip,$mjid) $ip
    if {[info exists ipCache(cmd,$id)]} {
	::Debug 2 "\t ipCache(cmd,$id)=$ipCache(cmd,$id)"
	eval $ipCache(cmd,$id) $jid
	unset -nocomplain ipCache(cmd,$id) ipCache(req,$mjid)
    }
}

proc ::Jabber::WB::PutIPnumber {jid id} {
    
    ::Debug 2 "::Jabber::WB::PutIPnumber:: jid=$jid, id=$id"
    
    set ip [::Network::GetThisPublicIPAddress]
    SendRawMessageList $jid [list "PUT IP: $id $ip"]
}

# Jabber::WB::GetCoccinellaServers --
# 
#       Get Coccinella server ports and ip via <iq>.

proc ::Jabber::WB::GetCoccinellaServers {jid3 {cmd {}}} {
    variable ipCache
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::coccixmlns coccixmlns
    
    set mjid3 [jlib::jidmap $jid3]
    set ipCache(req,$mjid3) 1
    $jstate(jlib) iq_get $coccixmlns(servers) -to $jid3  \
      -command [list ::Jabber::WB::GetCoccinellaServersCallback $jid3 $cmd]
}

proc ::Jabber::WB::GetCoccinellaServersCallback {jid3 cmd jlibname type subiq} {
    variable ipCache
    
    # ::Jabber::WB::GetCoccinellaServersCallback jabberlib1 ok 
    #  {query {xmlns http://coccinella.sourceforge.net/protocol/servers} 0 {} {
    #     {ip {protocol putget port 8235} 0 212.214.113.57 {}} 
    #     {ip {protocol http port 8077} 0 212.214.113.57 {}}
    #  }}
    ::Debug 2 "::Jabber::WB::GetCoccinellaServersCallback"

    if {$type == "error"} {
	return
    }
    set mjid3 [jlib::jidmap $jid3]
    set ipElements [wrapper::getchildswithtag $subiq ip]
    set ip [wrapper::getcdata [lindex $ipElements 0]]
    set ipCache(ip,$mjid3) $ip
    if {$cmd != ""} {
	eval $cmd
    }
    unset -nocomplain ipCache(req,$mjid3)
}

# Jabber::WB::PresenceHook --
# 
#       Administrate our internal ip cache.

proc ::Jabber::WB::PresenceHook {jid type args} {
    variable ipCache
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::coccixmlns coccixmlns
    
    ::Debug 2 "::Jabber::WB::PresenceHook jid=$jid, type=$type"
    
    array set argsArr $args
    if {[info exists argsArr(-resource)] && [string length $argsArr(-resource)]} {
	set jid $jid/$argsArr(-resource)
    }
    set mjid [jlib::jidmap $jid]
    
    switch -- $type {
	unavailable {
	    
	    # Need to remove our cached ip number for this jid.
	    unset -nocomplain ipCache(ip,$mjid) ipCache(req,$mjid)
	}
	available {
	    
	    # Starting with 0.95.1 we send server info along the initial 
	    # presence element.
	    set coccielem [$jstate(roster) getextras $mjid $coccixmlns(servers)]
	    if {$coccielem != {}} {
		set ipElements [wrapper::getchildswithtag $coccielem ip]
		set ip [wrapper::getcdata [lindex $ipElements 0]]
		set ipCache(ip,$mjid) $ip
	    }
	}
    }
}

# Jabber::WB::AutoBrowseHook --
# 
#       Gets called when we have identified a Coccinella user using
#       browsing. Query for its ip address.
#       
#       OUTDATED!!!

proc ::Jabber::WB::AutoBrowseHook {jid} {
    variable ipCache
    upvar ::Jabber::jprefs jprefs

    ::Debug 2 "::Jabber::WB::AutoBrowseHook jid=$jid"
    
    # Shall we query for its ip address right away?
    # Get only if not yet requested.
    set mjid [jlib::jidmap $jid]
    if {$jprefs(preGetIP) && ![info exists ipCache(ip,$mjid)] && \
      ![info exists ipCache(req,$mjid)]} {
	if {$jprefs(getIPraw)} {
	    GetIPnumber $jid
	} else {
	    GetCoccinellaServers $jid
	}
    }    
}

# Jabber::WB::PutFileOrScheduleHook --
# 
#       Handles everything needed to put a file to the jid's corresponding
#       to the 'wtop'. Users that we haven't got ip number from are scheduled
#       for delivery as a callback.
#       
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       fileName    the path to the file to be put.
#       opts        a list of '-key value' pairs, where most keys correspond 
#                   to a valid "canvas create" option, and everything is on 
#                   a single line.
#       
# Results:
#       none.

proc ::Jabber::WB::PutFileOrScheduleHook {wtop fileName opts} {    
    variable ipCache
    variable jwbstate
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::WB::PutFileOrScheduleHook: \
      wtop=$wtop, fileName=$fileName, opts='$opts'"
    
    # Before doing anything check that the Send checkbutton is on. ???
    if {!$jwbstate($wtop,send)} {
	::Debug 2 "    doSend=0 => return"
	return
    }
    
    # Verify that jid is well formed.
    if {![VerifyJIDWhiteboard $wtop]} {
	return
    }
    
    # This must never fail (application/octet-stream as fallback).
    set mime [::Types::GetMimeTypeForFileName $fileName]
    
    # Need to add jabber specific info to the 'optList', such as
    # -to, -from, -type, -thread etc.
    lappend opts -type $jwbstate($wtop,type)
    if {[info exists jwbstate($wtop,thread)]} {
	lappend opts -thread $jwbstate($wtop,thread)
    }
    
    set tojid $jwbstate($wtop,jid)
    jlib::splitjid $tojid jid2 res
    set isRoom 0
    
    if {[string length $res] > 0} {
	
	# The 'tojid' is already complete with resource.
	set allJid3 $tojid
	lappend opts -from $jstate(mejidresmap)
    } else {
	
	# If 'tojid' is without a resource, it can be a room.
	if {[$jstate(jlib) service isroom $tojid]} {
	    set isRoom 1
	    set allJid3 [$jstate(jlib) service roomparticipants $tojid]
	    
	    # Exclude ourselves.
	    foreach {meRoomJid nick} [$jstate(jlib) service hashandnick $tojid] \
	      break
	    set ind [lsearch $allJid3 $meRoomJid]
	    if {$ind >= 0} {
		set allJid3 [lreplace $allJid3 $ind $ind]
	    }
	    
	    # Be sure to have our room jid and not the real one.
	    lappend opts -from $meRoomJid
	} else {
	    
	    # Else put to resource with highest priority.
	    set res [$jstate(roster) gethighestresource $tojid]
	    if {$res == ""} {
		
		# This is someone we haven't got presence from.
		set allJid3 $tojid
	    } else {
		set allJid3 $tojid/$res
	    }
	    lappend opts -from $jstate(mejidresmap)
	}
    }
    
    ::Debug 2 "\t allJid3=$allJid3"
    
    # We shall put to all resources. Treat each in turn.
    foreach jid3 $allJid3 {
	
	# If we are in a room all must be available, else check.
	if {$isRoom} {
	    set avail 1
	} else {
	    set avail [$jstate(roster) isavailable $jid3]
	}
	set mjid3 [jlib::jidmap $jid3]
	
	# Each jid must get its own -to attribute.
	set optjidList [concat $opts -to $jid3]
	
	::Debug 2 "\t jid3=$jid3, avail=$avail"
	
	if {$avail} {
	    if {[info exists ipCache(ip,$mjid3)]} {
		
		# This one had already told us its ip number, good!
		PutFile $wtop $fileName $mime $optjidList $jid3
	    } else {
		
		# This jid is online but has not told us its ip number.
		# We need to get this jid's ip number and register the
		# PutFile as a callback when receiving this ip.
		if {0} {
		    
		    # OBSOLETE !!!
		    GetIPnumber $jid3 \
		      [list ::Jabber::WB::PutFile $wtop $fileName $mime $optjidList]
		} else {
		    
		    # New through <iq> element.
		    # Switch to this with version 0.94.8 or later!
		    GetCoccinellaServers $jid3  \
		      [list ::Jabber::WB::PutFile $wtop $fileName $mime  \
		      $optjidList $jid3]
		}
	    }
	} else {
	    
	    # We need to tell this jid to get this file from a server,
	    # possibly as an OOB http transfer.
	    array set optArr $opts
	    if {[info exists optArr(-url)]} {
		$jstate(jlib) oob_set $jid3 ::Jabber::OOB::SetCallback  \
		  $optArr(-url)  \
		  -desc {This file is part of a whiteboard conversation.\
		  You were not online when I opened this file}
	    } else {
		puts "   missing optArr(-url)"
	    }
	}
    }
	
    # This is an activity that may not be registered with jabberlib's auto away
    # functions, and must therefore schedule it here. ???????
    $jstate(jlib) schedule_auto_away
}

# Jabber::WB::PutFile --
#
#       Puts the file to the given jid provided the client has
#       told us its ip number.
#       Calls '::PutFileIface::PutFile' to do the real work for us.
#
# Arguments:
#       wtop        toplevel window. (.) If not "." then ".top."; extra dot!
#       fileName    the path to the file to be put.
#       opts        a list of '-key value' pairs, where most keys correspond 
#                   to a valid "canvas create" option, and everything is on 
#                   a single line.
#       jid         fully qualified  "username@host/resource"
#       
# Results:

proc ::Jabber::WB::PutFile {wtop fileName mime opts jid} {
    global  prefs
    variable ipCache
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::WB::PutFile: fileName=$fileName, opts='$opts', jid=$jid"

    set mjid [jlib::jidmap $jid]
    if {![info exists ipCache(ip,$mjid)]} {
	puts "::Jabber::WB::PutFile: Houston, we have a problem. \
	  ipCache(ip,$mjid) not there"
	return
    }
    
    # Check first that the user has not closed the window since this
    # call may be async.
    if {$wtop == "."} {
	set win .
    } else {
	set win [string trimright $wtop "."]
    }    
    if {![winfo exists $win]} {
	return
    }
    
    # Translate tcl type '-key value' list to 'Key: value' option list.
    set optList [::Import::GetTransportSyntaxOptsFromTcl $opts]

    ::PutFileIface::PutFile $wtop $fileName $ipCache(ip,$mjid) $optList
}

# Jabber::WB::HandlePutRequest --
# 
#       Takes care of a PUT command from the server.

proc ::Jabber::WB::HandlePutRequest {channel fileName opts} {
	
    ::Debug 2 "::Jabber::WB::HandlePutRequest"
    
    # The whiteboard must exist!
    set wtop [MakeWhiteboardExist $opts]
    ::GetFileIface::GetFile $wtop $channel $fileName $opts
}

# Jabber::WB::MakeWhiteboardExist --
# 
#       Verifies that there exists a whiteboard for this message.
#       
# Arguments:
#       opts
#       
# Results:
#       $wtop; may create new toplevel whiteboard

proc ::Jabber::WB::MakeWhiteboardExist {opts} {

    array set optArr $opts
    
    ::Debug 2 "::Jabber::WB::MakeWhiteboardExist"

    switch -- $optArr(-type) {
	chat {
	    set wtop [eval {GetWtopFromMessage chat \
	      $optArr(-from)} $opts]
	    if {$wtop == ""} {
		set wtop [NewWhiteboardTo $optArr(-from)  \
		  -thread $optArr(-thread)]
	    }
	}
	groupchat {
	    jlib::splitjid $optArr(-from) roomjid resource
	    if {[string length $roomjid] == 0} {
		return -code error  \
		  "The jid we got \"$optArr(-from)\" was not well-formed!"
	    }
	    set wtop [GetWtopFromMessage groupchat $optArr(-from)]
	    if {$wtop == ""} {
		set wtop [NewWhiteboardTo $roomjid -force 1]
	    }
	}
	default {
	    # Normal message. Shall go in inbox ???????????
	    set wtop [GetWtopFromMessage normal $optArr(-from)]
	}
    }
    return $wtop
}

# ::Jabber::WB::GetWtopFromMessage --
# 
#       Figures out if we've got an existing whiteboard for an incoming
#       message. Need to map 'type', 'jid', and -thread 'thread'. 
#       
# Arguments:
#       type        chat | groupchat | normal
#       jid
#       args        -thread ...
#       
# Results:
#       $wtop or empty

proc ::Jabber::WB::GetWtopFromMessage {type jid args} {
    variable jwbstate
    
    set wtop ""
    array set argsArr $args
    
    switch -- $type {
	 chat {
	     if {[info exists argsArr(-thread)]} {
		 set thread $argsArr(-thread)
		 if {[info exists jwbstate($thread,thread,wtop)]} {
		     set wtop $jwbstate($thread,thread,wtop)
		 }
	     }	    
	 }
	 groupchat {
	 
	     # The jid is typically the 'roomjid/nick' but can be the room itself.
	     set mjid [jlib::jidmap $jid]
	     jlib::splitjid $mjid jid2 res
	     if {[info exists jwbstate($jid2,jid,wtop)]} {
		 set wtop $jwbstate($jid2,jid,wtop)
	     }	    
	 }
	 normal {
	     # Mailbox!!!
	     set wtop ""
	 }
     }
     
     # Verify that toplevel actually exists.
     if {$wtop != ""} {
	 if {[string equal $wtop "."]} {
	     set w .
	 } else {
	     set w [string trimright $wtop "."]
	 }
	 if {![winfo exists $w]} {
	     set wtop ""
	 }
     }
     ::Debug 2 "\twtop=$wtop"
     return $wtop
}

# ::Jabber::WB::DispatchToImporter --
# 
#       Is called as a response to a GET file event. 
#       We've received a file that should be imported somewhere.
#       
# Arguments:
#       mime
#       opts
#       args        -file, -where; for importer proc.

proc ::Jabber::WB::DispatchToImporter {mime opts args} {
	
    ::Debug 2 "::Jabber::WB::DispatchToImporter"

    array set optArr $opts

    # Creates WB if not exists.
    set wtop [MakeWhiteboardExist $opts]

    switch -- $optArr(-type) {
	chat - groupchat {
	    set display 1
	}
	default {
	    set display 0
	}
    }
    
    if {$display} {
	if {[::Plugins::HaveImporterForMime $mime]} {
	    set wCan [::WB::GetCanvasFromWtop $wtop]
	    set errMsg [eval {::Import::DoImport $wCan $opts} $args]
	    if {$errMsg != ""} {
		tk_messageBox -title [mc Error] -icon error -type ok \
		  -message "Failed importing: $errMsg" \
		  -parent [winfo toplevel $wCan]
	    }
	} else {
	    tk_messageBox -title [mc Error] -icon error -type ok \
	      -message [mc messfailmimeimp $mime] \
	      -parent [winfo toplevel $wCan]
	}
    }
}

# Jabber::WB::VerifyJIDWhiteboard --
#
#       Validate entry for jid.
#       
# Arguments:
#       jid     username@server
#       
# Results:
#       boolean: 0 if reject, 1 if accept

proc ::Jabber::WB::VerifyJIDWhiteboard {wtop} {
    variable jwbstate
    
    if {[string equal $wtop "."]} {
	set w .
    } else {
	set w [string trimright $wtop .]
    }
    if {$jwbstate($wtop,send)} {
	if {![jlib::jidvalidate $jwbstate($wtop,jid)]} {
	    tk_messageBox -icon warning -type ok -parent $w -message  \
	      [FormatTextForMessageBox [mc jamessinvalidjid]]
	    return 0
	}
    }
    return 1
}

#-------------------------------------------------------------------------------
