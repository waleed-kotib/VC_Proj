#  JWB.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It provides the glue between jabber and the whiteboard.
#      
#  Copyright (c) 2004-2005  Mats Bengtsson
#  
# $Id: JWB.tcl,v 1.61 2006-04-06 07:28:31 matben Exp $

package require can2svgwb
package require svgwb2can
package require ui::entryex

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
    upvar ::Jabber::xmppxmlns xmppxmlns
    
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
    
    ::hooks::register loginHook                    ::Jabber::WB::LoginHook
    ::hooks::register logoutHook                   ::Jabber::WB::LogoutHook
    ::hooks::register groupchatEnterRoomHook       ::Jabber::WB::EnterRoomHook
    ::hooks::register groupchatExitRoomHook        ::Jabber::WB::ExitRoomHook

    # Configure the Tk->SVG translation to use http.
    # Must be reconfigured when we know our address after connecting???
    set ip [::Network::GetThisPublicIP]
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
      [list xmlns $xmppxmlns(amp)] -subtags [list $rule2]]
}

proc ::Jabber::WB::InitUI { } {
    global  prefs this
    variable initted
    
    ::Debug 2 "::Jabber::WB::InitUI"

    set buttonTrayDefs {
	save       {::CanvasFile::Save $w}
	open       {::CanvasFile::OpenCanvasFileDlg $w}
	import     {::Import::ImportImageOrMovieDlg $w}
	send       {::Jabber::WB::DoSendCanvas $w}
	print      {::UserActions::DoPrintCanvas $w}
	stop       {::Jabber::WB::Stop $w}
    }
    ::WB::SetButtonTrayDefs $buttonTrayDefs

    # We don't want a Quit button here:
    #     Aqua: handled in apple menu
    #     Else: handled in main window
    set menuDefsFile {
	{command   mNew                {::WB::NewWhiteboard}             normal   N}
	{command   mCloseWindow        {::UI::DoCloseWindow $w}          normal   W}
	{separator}
	{command   mOpenImage/Movie    {::Import::ImportImageOrMovieDlg $w}    normal   I}
	{command   mOpenURLStream      {::Multicast::OpenMulticast $w}     normal   {}}
	{command   mStopPut/Get/Open   {::Jabber::WB::Stop $w}        normal {}}
	{separator}
	{command   mOpenCanvas         {::CanvasFile::OpenCanvasFileDlg $w}     normal   O}
	{command   mSaveCanvas         {::CanvasFile::Save $w}           normal   S}
	{separator}
	{command   mSaveAs             {::CanvasFile::SaveAsDlg $w}      normal   {}}
	{command   mSaveAsItem         {::CanvasCmd::DoSaveAsItem $w}    normal   {}}
	{command   mPageSetup          {::UserActions::PageSetup $w}           normal   {}}
	{command   mPrintCanvas        {::UserActions::DoPrintCanvas $w}       normal   P}
    }
    if {![::Plugins::HavePackage QuickTimeTcl]} {
	lset menuDefsFile 4 3 disabled
    } else {
	package require Multicast
    }
     
    # Get any registered menu entries. 
    # Mac: add above last separator; Others: add at end
    # @@@ I don't like this solution!
    if {[tk windowingsystem] eq "aqua"} {
	set ind [lindex [lsearch -exact -all $menuDefsFile separator] end]
	incr ind
    } else {
	set ind end
    }
    set mdef [::UI::Public::GetRegisteredMenuDefs file]
    if {$mdef != {}} {
	set menuDefsFile [linsert $menuDefsFile $ind {separator}]
	set menuDefsFile [linsert $menuDefsFile $ind $mdef]
    }
    ::WB::SetMenuDefs file $menuDefsFile
    
    bind WhiteboardToplevel <Destroy> {+::Jabber::WB::Free %W}

    set initted 1
}

proc ::Jabber::WB::NewWhiteboard {args} {
    variable jwbstate
    variable initted
    
    if {!$initted} {
	InitUI
    }    
    
    ::Debug 4 "::Jabber::WB::NewWhiteboard $args"

    array set argsArr $args
    if {[info exists argsArr(-w)]} {
	set w $argsArr(-w)
    } else {
	set w [::WB::GetNewToplevelPath]
    }
    set jwbstate($w,type) normal
    set jwbstate($w,send) 0
    set jwbstate($w,jid)  ""
    set restargs {}

    foreach {key value} $args {
	
	switch -- $key {
	    -w {
		continue
	    }
	    -jid {
		set jwbstate($w,jid) [jlib::jidmap $value]
		lappend restargs $key $value
	    }
	    -send - -type {
		set jwbstate($w,[string trimleft $key -]) $value
	    }
	    default {
		lappend restargs $key $value
	    }
	}
    }
    eval {::WB::BuildWhiteboard $w} $restargs
    
    if {[info exists argsArr(-state)] && ($argsArr(-state) eq "disabled")} {
	$jwbstate($w,wjid)  state {disabled}
	$jwbstate($w,wsend) state {disabled}
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
#       toplevel widget path

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
    # Note that the jid can belong to a room but we may still have a 2p chat.
    #    jid is room:  groupchat live
    #    jid is a user in a room:  chat
    #    jid is ordinary available user:  chat
    #    jid is ordinary but unavailable user:  normal message

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
	    set ans [::GroupChat::EnterOrCreate enter -roomjid $jid \
	      -autoget 1]
	    if {$ans eq "cancel"} {
		Free $w
		return
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
	    set thread [::sha1::sha1 "$jstate(mejid)[clock seconds]"]
	}
	set name [$jstate(roster) getname $jid]
	if {[string length $name]} {
	    set title "[mc {Chat With}] $name"
	} else {
	    set title "[mc {Chat With}] $jid"
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
    set w ""
    if {$doBuild} {
	set w [eval {::WB::NewWhiteboard} [array get argsArr]]
    }
    return $w
}

# Jabber::WB::PreBuildHook, PostBuildHook --
# 
#       Sets up custom state for whiteboard. Called during build process.

proc ::Jabber::WB::PreBuildHook {w args} {
    variable jwbstate
    variable initted
    
    ::Debug 4 "::Jabber::WB::PreBuildHook w=$w, args=$args"
    
    array set argsArr {
	-state   normal
	-jid     ""
	-type    normal
	-send    0
    }
    array set argsArr $args
    foreach {key value} [array get argsArr] {
	set jwbstate($w,[string trimleft $key -]) $value
    }
    
    # Be sure to be able to map wtoplevel->jid and jid->wtoplevel.
    set jid [jlib::jidmap $argsArr(-jid)]
    set jwbstate($w,jid) $jid
    set jwbstate($jid,jid,w) $w
    
    # Be sure to be able to map wtoplevel->thread and thread->wtoplevel if chat.
    if {[info exists jwbstate($w,thread)]} {
	set thread $jwbstate($w,thread)
	set jwbstate($thread,thread,w) $w
    }
    if {!$initted} {
	InitUI
    }
}

proc ::Jabber::WB::PostBuildHook {w} {
    variable jwbstate
       
    ::Debug 4 "::Jabber::WB::PostBuildHook w=$w"
    
    if {$jwbstate($w,state) eq "disabled"} {
	$jwbstate($w,wjid)  state {disabled}
	$jwbstate($w,wsend) state {disabled}
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

proc ::Jabber::WB::BuildEntryHook {w wcomm} {
    variable jwbstate
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::WB::BuildEntryHook wcomm=$wcomm"
	
    set contactOffImage [::Theme::GetImage [option get $w contactOffImage {}]]
    set contactOnImage  [::Theme::GetImage [option get $w contactOnImage {}]]
    set iconResize      [::Theme::GetImage [option get $w resizeHandleImage {}]]

    set jidlist [$jstate(roster) getusers]
    
    set wframe $wcomm.f
    ttk::frame $wframe
    pack  $wframe -side bottom -fill x

    # Resize handle unless MacOSX.
    if {[tk windowingsystem] ne "aqua"} {
	ttk::label $wframe.hand -image $iconResize
	pack  $wframe.hand  -side right -anchor s
    }

    ttk::label $wframe.ljid -style Small.TLabel \
      -text "[mc {Jabber ID}]:" -padding {16 4 4 4}
    ui::entryex $wframe.ejid -font CociSmallFont  \
      -library $jidlist -textvariable [namespace current]::jwbstate($w,jid)
    ttk::checkbutton $wframe.to -style Small.TCheckbutton \
      -text [mc {Send Live}] \
      -variable [namespace current]::jwbstate($w,send)
    $wframe.to state {disabled}
    if {[::Jabber::IsConnected]} {
	set im $contactOnImage
    } else {
	set im $contactOffImage
    }
    ttk::label $wframe.icon -image $im -padding {10 4}
    pack  $wframe.ljid  -side left
    pack  $wframe.icon  -side right
    pack  $wframe.to    -side right
    pack  $wframe.ejid  -side right -fill x -expand true
     
    # Cache widgets paths.
    set jwbstate($w,w)         $w
    set jwbstate($w,wframe)    $wframe
    set jwbstate($w,wfrja)     $wframe
    set jwbstate($w,wjid)      $wframe.ejid
    set jwbstate($w,wsend)     $wframe.to
    set jwbstate($w,wcontact)  $wframe.icon
    
    # Fix widget states.
    set netstate logout
    if {[::Jabber::IsConnected]} {
	set netstate login
    }
    SetStateFromType $w
    SetNetworkState  $w $netstate
}

proc ::Jabber::WB::Configure {w args} {
    variable jwbstate
    
    foreach {key value} $args {
	set akey [string trimleft $key -]
	set jwbstate($w,$akey) $value
    }
}

# Jabber::WB::SetStateFromType --
# 
# 

proc ::Jabber::WB::SetStateFromType {w} {
    variable jwbstate
    
    switch -- $jwbstate($w,type) {
	normal {
	    set jwbstate($w,send) 0
	}
	chat - groupchat {
	    set wtray [::WB::GetButtonTray $w]
	    $wtray buttonconfigure send -state disabled
	    set jwbstate($w,send) 1
	    $jwbstate($w,wjid) state {disabled}
	}
    }
}

# Jabber::WB::SetNetworkState --
# 
#       Sets the state of all jabber specific ui parts of whiteboard when
#       login/logout.

proc ::Jabber::WB::SetNetworkState {w what} {
    variable jwbstate
    
    if {![info exists jwbstate($w,w)]} {
	return
    }
    set wcontact $jwbstate($w,wcontact)
    array set optsArr [::WB::ConfigureMain $w]
    
    switch -- $what {
	login {
	    set server [::Jabber::GetServerJid]
	    if {$jwbstate($w,jid) eq ""} {
		set jwbstate($w,jid) "@${server}"
	    }
	    
	    switch -- $jwbstate($w,type) {
		chat - groupchat {
		    #$jwbstate($w,wsend) configure -state normal
		}
		default {
		    if {$optsArr(-state) eq "normal"} {
			set wtray [::WB::GetButtonTray $w]
			$wtray buttonconfigure send -state normal
		    }
		}
	    }
	    set contactOnImage  [::Theme::GetImage \
	      [option get $w contactOnImage {}]]
	    after 400 [list $wcontact configure -image $contactOnImage]
	}
	logout {
	    set wtray [::WB::GetButtonTray $w]
	    $wtray buttonconfigure send -state disabled
	    $jwbstate($w,wsend) state {disabled}
	    set contactOffImage [::Theme::GetImage \
	       [option get $w contactOffImage {}]]
	     after 400 [list $wcontact configure -image $contactOffImage]
	}
    }
}

proc ::Jabber::WB::SetMinsizeHook {w} {
    
    # It is our responsibilty to set new minsize since we have added stuff.
    after idle ::Jabber::WB::SetMinsize $w
}

proc ::Jabber::WB::SetMinsize {w} {
    variable jwbstate
    
    lassign [::WB::GetBasicWhiteboardMinsize $w] wMin hMin
    set wMinEntry [winfo reqwidth  $jwbstate($w,wfrja)]
    set hMinEntry [winfo reqheight $jwbstate($w,wframe)]
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

proc ::Jabber::WB::Stop {w} {
    variable jwbstate
    
    switch -- $jwbstate($w,type) {
	chat - groupchat {
	    ::GetFileIface::CancelAllWtop $w
	    ::Import::HttpResetAll $w
	}
	default {
	    ::Import::HttpResetAll $w
	}
    }
    ::WB::SetStatusMessage $w ""
    ::WB::StartStopAnimatedWave $w 0
}

# Jabber::WB::LoginHook --
# 
#       The login hook command.

proc ::Jabber::WB::LoginHook { } {
    
    # Multiinstance whiteboard UI stuff.
    foreach w [::WB::GetAllWhiteboards] {
	SetNetworkState $w login
    }
}


proc ::Jabber::WB::LogoutHook { } {
    variable delayed
    
    unset -nocomplain delayed
    foreach w [::WB::GetAllWhiteboards] {
	SetNetworkState $w logout
    }    
}

proc ::Jabber::WB::CloseHook {w} {
    variable jwbstate
    
    ::Debug 2 "::Jabber::WB::CloseHook w=$w"
        
    switch -- $jwbstate($w,type) {
	chat {
	    set ans [::UI::MessageBox -icon info -parent $w -type yesno \
	      -message [mc jamesswbchatlost]]
	    if {$ans ne "yes"} {
		return stop
	    }
	}
	groupchat {
	    
	    # Everything handled from Jabber::GroupChat
	    set ans [::GroupChat::ExitRoomJID $jwbstate($w,jid)]
	    if {$ans ne "yes"} {
		return stop
	    }
	}
	default {
	    # empty
	}
    }
}

proc ::Jabber::WB::ExitRoomHook {roomJid} {
    variable jwbstate
    
    set w [GetWtopFromMessage groupchat $roomJid]
    if {$w ne ""} {
	::WB::CloseWhiteboard $w
    }
}

# Various procs for sending wb messages ........................................

# Jabber::WB::SendMessageHook --
#
#       This is just a shortcut for sending a message. 
#       
# Arguments:
#       w           toplevel widget path
#       msg         canvas command without the widgetPath or CANVAS: prefix.
#       args        ?-key value ...?
#                   -force 0|1   (D=0) override doSend checkbutton?
#       
# Results:
#       none.

proc ::Jabber::WB::SendMessageHook {w msg args} {
    variable jwbstate
    
    ::Debug 2 "::Jabber::WB::SendMessageHook"
    
    # Check that still connected to server.
    if {![::Jabber::IsConnected]} {
	return
    }
    
    # Check that still online if chat!
    if {![CheckIfOnline $w]} {
	return
    }
    array set opts {-force 0}
    array set opts $args
        
    if {$jwbstate($w,send) || $opts(-force)} {
	if {[VerifyJIDWhiteboard $w]} {
	    
	    # Here we shall decide the 'type' of message sent (normal, chat, groupchat)
	    # depending on the type of whiteboard (via w).
	    set argsList [SendArgs $w]
	    set jid $jwbstate($w,jid)
	    
	    eval {SendMessage $w $jid $msg} $argsList
	} else {
	    
	    # Perhaps we should give some aid here; set focus?
	}
    }
    return {}
}

# Jabber::WB::SendMessageListHook --
#
#       As above but for a list of commands.

proc ::Jabber::WB::SendMessageListHook {w msgList args} {
    variable jwbstate
    
    ::Debug 2 "::Jabber::WB::SendMessageListHook msgList=$msgList; $args"
    
    if {![::Jabber::IsConnected]} {
	return
    }

    # Check that still online if chat!
    if {![CheckIfOnline $w]} {
	return
    }
    array set opts {-force 0}
    array set opts $args
    
    if {$jwbstate($w,send) || $opts(-force)} {
	if {[VerifyJIDWhiteboard $w]} {
	    set jid $jwbstate($w,jid)
	    set argsList [SendArgs $w]
	    eval {SendMessageList $w $jid $msgList} $argsList
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

proc ::Jabber::WB::SendGenMessageListHook {w msgList args} {
    variable jwbstate
    
    ::Debug 2 "::Jabber::WB::SendGenMessageListHook"
    
    if {![::Jabber::IsConnected]} {
	return
    }

    # Check that still online if chat!
    if {![CheckIfOnline $w]} {
	return
    }
    array set opts {-force 0}
    array set opts $args

    if {$jwbstate($w,send) || $opts(-force)} {
	if {[VerifyJIDWhiteboard $w]} {
	    set jid $jwbstate($w,jid)
	    set argsList [SendArgs $w]
	    eval {SendRawMessageList $jid $msgList} $argsList
	}    
    }
    return {}
}

proc ::Jabber::WB::SendArgs {w} {
    variable jwbstate

    set argsList {}
    set type $jwbstate($w,type)
    if {[string equal $type "normal"]} {
	set type ""
    }
    if {[llength $type] > 0} {
	lappend argsList -type $type
	if {[string equal $type "chat"]} {
	    lappend argsList -thread $jwbstate($w,thread)
	}
    }
    return $argsList
}

proc ::Jabber::WB::CheckIfOnline {w} {
    variable jwbstate
    upvar ::Jabber::jstate jstate

    set isok 1
    if {[string equal $jwbstate($w,type) "chat"]} {
	set isok [$jstate(roster) isavailable $jwbstate($w,jid)]
	if {!$isok} {
	    ::UI::MessageBox -type ok -icon warning -parent $w \
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

proc ::Jabber::WB::SendMessage {w jid msg args} {    
    upvar ::Jabber::jstate jstate
    
    set xlist [CanvasCmdListToMessageXElement $w [list $msg]]

    eval {$jstate(jlib) send_message $jid -xlist $xlist} $args
}

# Jabber::WB::SendMessageList --
#
#       As above but for a list of commands.

proc ::Jabber::WB::SendMessageList {w jid msgList args} {
    upvar ::Jabber::jstate jstate
    
    set xlist [CanvasCmdListToMessageXElement $w $msgList]

    eval {$jstate(jlib) send_message $jid -xlist $xlist} $args
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

    eval {$jstate(jlib) send_message $jid -xlist $xlist} $args
}

# Jabber::WB::CanvasCmdListToMessageXElement --
# 
#       Takes a list of canvas commands and returns the xml
#       x element xmllist appropriate.
#       
# Arguments:
#       cmdList     a list of canvas commands without the widgetPath.
#                   no CANVAS:

proc ::Jabber::WB::CanvasCmdListToMessageXElement {w cmdList} {
    variable xmlnsSVGWB
    variable ampElem
    upvar ::Jabber::jprefs jprefs
    
    if {$jprefs(useSVGT)} {
	
	# Form SVG element.
	set subx {}
	set wcan [::WB::GetCanvasFromWtop $w]
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

proc ::Jabber::WB::DoSendCanvas {w} {
    global  prefs
    variable jwbstate
    upvar ::Jabber::jstate jstate

    set jid $jwbstate($w,jid)

    if {[jlib::jidvalidate $jid]} {
		
	# If user not online no files may be sent off.
	if {![$jstate(roster) isavailable $jid]} {
	    set ans [::UI::MessageBox -icon warning -type yesno -parent $w  \
	      -message "The user you are sending to,\
	      \"$jid\", is not online, and if this message contains any images\
	      or other similar entities, this user will not get them unless\
	      you happen to be online while this message is being read.\
	      Do you want to send it anyway?"]
	    if {$ans eq "no"} {
		return
	    }
	}
	::CanvasCmd::DoSendCanvas $w
	::WB::CloseWhiteboard     $w
    } else {
	::UI::MessageBox -icon warning -type ok -parent $w \
	  -message [mc jamessinvalidjid]
    }
}


proc ::Jabber::WB::FilterTags {tags} {
    
    return [::CanvasUtils::GetUtagFromTagList $tags]
}

# Various message handlers......................................................

# Jabber::WB::HandleSpecialMessage --
# 
#       Takes care of any special (BAD) commands from the old protocol.

proc ::Jabber::WB::HandleSpecialMessage {jlibname xmlns msgElem args} {
        
    ::Debug 2 "::Jabber::WB::HandleSpecialMessage $xmlns, args=$args"
    array set argsArr $args
    if {![info exists argsArr(-x)]} {
	return
    }
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

proc ::Jabber::WB::HandleRawChatMessage {jlibname xmlns msgElem args} {
        
    ::Debug 2 "::Jabber::WB::HandleRawChatMessage args=$args"
    array set argsArr $args
    if {![info exists argsArr(-x)]} {
	return
    }
        
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

proc ::Jabber::WB::HandleRawGroupchatMessage {jlibname xmlns msgElem args} {
	
    ::Debug 2 "::Jabber::WB::HandleRawGroupchatMessage args=$args"	
    array set argsArr $args
    if {![info exists argsArr(-x)]} {
	return
    }
    
    # Don't do anything if we haven't entered the room using whiteboard.
    set mjid [jlib::jidmap $argsArr(-from)]
    jlib::splitjid $mjid roomjid res
    if {[HaveWhiteboard $roomjid]} {
	
	# Do not duplicate ourselves!
	if {![::Jabber::IsMyGroupchatJid $argsArr(-from)]} {
	    set cmdList [GetRawMessageList $argsArr(-x) $xmlns]
	    set cmdList [eval {HandleNonCanvasCmds groupchat $cmdList} $args]
	    
	    eval {GroupchatMsg $cmdList} $args
	    eval {::hooks::run newWBGroupChatMessageHook} $args
	}
	
	# We have handled this message completely.
	set ishandled 1
    } else {
	set ishandled 0
    }
    return $ishandled
}

proc ::Jabber::WB::HandleSVGWBChatMessage {jlibname xmlns msgElem args} {
    
    ::Debug 2 "::Jabber::WB::HandleSVGWBChatMessage"
    array set argsArr $args
    if {![info exists argsArr(-x)]} {
	return
    }
	
    # Need to have the actual canvas before doing svg -> canvas translation.
    # This is a duplicate; fix later...
    set w [eval {GetWtopFromMessage chat $argsArr(-from)} $args]
    if {$w eq ""} {
	set w [eval {NewWhiteboardTo $argsArr(-from)} $args]
    }
    
    set cmdList [GetSVGWBMessageList $w $argsArr(-x)]
    if {[llength $cmdList]} {
	eval {ChatMsg $cmdList} $args
	eval {::hooks::run newWBChatMessageHook} $args
    }
    
    # We have handled this message completely.
    return 1
}

proc ::Jabber::WB::HandleSVGWBGroupchatMessage {jlibname xmlns msgElem args} {
    
    ::Debug 2 "::Jabber::WB::HandleSVGWBGroupchatMessage"
    array set argsArr $args
    if {![info exists argsArr(-x)]} {
	return
    }
    
    # Don't do anything if we haven't entered the room using whiteboard.
    set mjid [jlib::jidmap $argsArr(-from)]
    jlib::splitjid $mjid roomjid res
    if {[HaveWhiteboard $roomjid]} {

	# Need to have the actual canvas before doing svg -> canvas translation.
	# This is a duplicate; fix later...
	set w [GetWtopFromMessage groupchat $roomjid]
	if {$w eq ""} {
	    set w [eval {NewWhiteboardTo $roomjid -force 1} $args]
	}
	
	# Do not duplicate ourselves!
	if {![::Jabber::IsMyGroupchatJid $argsArr(-from)]} {
	    set cmdList [GetSVGWBMessageList $w $argsArr(-x)]
	    
	    if {[llength $cmdList]} {
		eval {GroupchatMsg $cmdList} $args
		eval {::hooks::run newWBGroupChatMessageHook} $args
	    }
	}
	
	# We have handled this message completely.
	set ishandled 1
    } else {
	set ishandled 0
    }
    return $ishandled
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

proc ::Jabber::WB::GetSVGWBMessageList {w xlist} {
    variable xmlnsSVGWB

    set wcan [::WB::GetCanvasFromWtop $w]
    set cmdList {}
    
    foreach xelem $xlist {
	array set attrArr [wrapper::getattrlist $xelem]
	if {[string equal $attrArr(xmlns) $xmlnsSVGWB]} {
	    set cmdList [svgwb2can::parsesvgdocument $xelem -canvas $wcan \
	      -foreignobjecthandler \
	      [list [namespace current]::SVGForeignObjectHandler $w] \
	      -httphandler [list [namespace current]::SVGHttpHandler $w]]
	}
    }
    return $cmdList
}

# Jabber::WB::SVGForeignObjectHandler --
# 
#       The only excuse for this is to add '-where local'.

proc ::Jabber::WB::SVGForeignObjectHandler {w xmllist paropts transformList args} {
    
    array set argsArr $args
    set argsArr(-where) local
    eval {::CanvasUtils::SVGForeignObjectHandler $w $xmllist $paropts \
      $transformList} [array get argsArr]
}

# Jabber::WB::SVGHttpHandler --
# 
#       Callback for SVG to canvas translator for http uri's.
#       
#       cmd:        create image $x $y -key value ...

proc ::Jabber::WB::SVGHttpHandler {w cmd} {
    variable jwbstate
    upvar ::Jabber::jstate jstate
        
    # Design the import line.
    # import 226.0 104.0 -http ... -below */117748804 -tags */117748801
    set line [concat import [lrange $cmd 2 end]]
    set wcan [::WB::GetCanvasFromWtop $w]
    
    # We should make sure w exists!
    
    # Only if user available shall we try to import.
    set tryimport 0
    # THIS IS NOT A 3-tier JID!!!!!
    set jid3 $jwbstate($w,jid)

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
		    set w ""
		
		    # Make sure whiteboard exists.
		    switch -- $type {
			chat - groupchat {
			    set w [eval {GetWtopFromMessage \
			      $type $argsArr(-from)} $args]
			    if {$w eq ""} {
				continue
				set w [eval {
				    NewWhiteboardTo $argsArr(-from)} $args]
			    }
			}
		    }
		    ::Import::ResizeImage $w $zoom $utag $utagNew "local"
		}
	    }
	    default {
		if {[info exists handler($prefix)]} {
		    array set argsArr $args
		    set w ""

		    switch -- $type {
			chat - groupchat {
			    set w [eval {GetWtopFromMessage \
			      $type $argsArr(-from)} $args]
			}
		    }
		    if {$w ne ""} {
			set w [::WB::GetCanvasFromWtop $w]
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

# ::Jabber::WB::ChatMsg, GroupchatMsg --
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
    set w [eval {GetWtopFromMessage chat $argsArr(-from)} $args]
    if {$w eq ""} {
	set w [eval {NewWhiteboardTo $argsArr(-from)} $args]
    }
    foreach line $cmdList {
	::CanvasUtils::HandleCanvasDraw $w $line
    }     
}

proc ::Jabber::WB::GroupchatMsg {cmdList args} {    
    upvar ::Jabber::jstate jstate

    array set argsArr $args
    ::Debug 2 "::Jabber::WB::GroupchatMsg args='$args'"
    
    # The -from argument is either the room itself, or usually a user in
    # the room.
    jlib::splitjid $argsArr(-from) roomjid resource
    set w [GetWtopFromMessage groupchat $roomjid]
    if {$w eq ""} {
	set w [eval {NewWhiteboardTo $roomjid -force 1} $args]
    }

    foreach line $cmdList {
	::CanvasUtils::HandleCanvasDraw $w $line
    }
}

proc ::Jabber::WB::Free {w} {
    variable jwbstate
    variable delayed
    
    ::Debug 2 "::Jabber::WB::Free"
    
    catch {
	unset -nocomplain jwbstate($jwbstate($w,thread),thread,w) \
	  jwbstate($jwbstate($w,jid),jid,w)
    }
    array unset jwbstate "$w,*"    
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
    if {$cmd ne ""} {
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
    
    set ip [::Network::GetThisPublicIP]
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

    if {$type eq "error"} {
	return
    }
    set mjid3 [jlib::jidmap $jid3]
    set ipElements [wrapper::getchildswithtag $subiq ip]
    set ip [wrapper::getcdata [lindex $ipElements 0]]
    set ipCache(ip,$mjid3) $ip
    if {$cmd ne ""} {
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

# Jabber::WB::PutFileOrScheduleHook --
# 
#       Handles everything needed to put a file to the jid's corresponding
#       to the 'w'. Users that we haven't got ip number from are scheduled
#       for delivery as a callback.
#       
# Arguments:
#       w           toplevel widget path
#       fileName    the path to the file to be put.
#       opts        a list of '-key value' pairs, where most keys correspond 
#                   to a valid "canvas create" option, and everything is on 
#                   a single line.
#       
# Results:
#       none.

proc ::Jabber::WB::PutFileOrScheduleHook {w fileName opts} {    
    variable ipCache
    variable jwbstate
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::WB::PutFileOrScheduleHook: \
      w=$w, fileName=$fileName, opts='$opts'"
    
    # Before doing anything check that the Send checkbutton is on. ???
    if {!$jwbstate($w,send)} {
	::Debug 2 "    doSend=0 => return"
	return
    }
    
    # Verify that jid is well formed.
    if {![VerifyJIDWhiteboard $w]} {
	return
    }
    
    # This must never fail (application/octet-stream as fallback).
    set mime [::Types::GetMimeTypeForFileName $fileName]
    
    # Need to add jabber specific info to the 'optList', such as
    # -to, -from, -type, -thread etc.
    lappend opts -type $jwbstate($w,type)
    if {[info exists jwbstate($w,thread)]} {
	lappend opts -thread $jwbstate($w,thread)
    }
    
    set tojid $jwbstate($w,jid)
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
	    if {$res eq ""} {
		
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
		PutFile $w $fileName $mime $optjidList $jid3
	    } else {
		
		# This jid is online but has not told us its ip number.
		# We need to get this jid's ip number and register the
		# PutFile as a callback when receiving this ip.
		GetCoccinellaServers $jid3  \
		  [list ::Jabber::WB::PutFile $w $fileName $mime  \
		  $optjidList $jid3]
	    }
	} else {
	    
	    # We are silent about this.
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
#       w           toplevel widget path
#       fileName    the path to the file to be put.
#       opts        a list of '-key value' pairs, where most keys correspond 
#                   to a valid "canvas create" option, and everything is on 
#                   a single line.
#       jid         fully qualified  "username@host/resource"
#       
# Results:

proc ::Jabber::WB::PutFile {w fileName mime opts jid} {
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
    if {![winfo exists $w]} {
	return
    }
    
    # Translate tcl type '-key value' list to 'Key: value' option list.
    set optList [::Import::GetTransportSyntaxOptsFromTcl $opts]

    ::PutFileIface::PutFile $w $fileName $ipCache(ip,$mjid) $optList
}

# Jabber::WB::HandlePutRequest --
# 
#       Takes care of a PUT command from the server.

proc ::Jabber::WB::HandlePutRequest {channel fileName opts} {
	
    ::Debug 2 "::Jabber::WB::HandlePutRequest"
    
    # The whiteboard must exist!
    set w [MakeWhiteboardExist $opts]
    ::GetFileIface::GetFile $w $channel $fileName $opts
}

# Jabber::WB::MakeWhiteboardExist --
# 
#       Verifies that there exists a whiteboard for this message.
#       
# Arguments:
#       opts
#       
# Results:
#       $w; may create new toplevel whiteboard

proc ::Jabber::WB::MakeWhiteboardExist {opts} {

    array set optArr $opts
    
    ::Debug 2 "::Jabber::WB::MakeWhiteboardExist"

    switch -- $optArr(-type) {
	chat {
	    set w [eval {GetWtopFromMessage chat \
	      $optArr(-from)} $opts]
	    if {$w eq ""} {
		set w [NewWhiteboardTo $optArr(-from)  \
		  -thread $optArr(-thread)]
	    }
	}
	groupchat {
	    jlib::splitjid $optArr(-from) roomjid resource
	    if {[string length $roomjid] == 0} {
		return -code error  \
		  "The jid we got \"$optArr(-from)\" was not well-formed!"
	    }
	    set w [GetWtopFromMessage groupchat $optArr(-from)]
	    if {$w eq ""} {
		set w [NewWhiteboardTo $roomjid -force 1]
	    }
	}
	default {
	    # Normal message. Shall go in inbox ???????????
	    set w [GetWtopFromMessage normal $optArr(-from)]
	}
    }
    return $w
}

proc ::Jabber::WB::HaveWhiteboard {jid} {
    variable jwbstate
    
    if {[info exists jwbstate($jid,jid,w)]} {
	return 1
    } else {
	return 0
    }
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
#       $w or empty

proc ::Jabber::WB::GetWtopFromMessage {type jid args} {
    variable jwbstate
    
    set w ""
    array set argsArr $args
    
    switch -- $type {
	 chat {
	     if {[info exists argsArr(-thread)]} {
		 set thread $argsArr(-thread)
		 if {[info exists jwbstate($thread,thread,w)]} {
		     set w $jwbstate($thread,thread,w)
		 }
	     }	    
	 }
	 groupchat {
	 
	     # The jid is typically the 'roomjid/nick' but can be the room itself.
	     set mjid [jlib::jidmap $jid]
	     jlib::splitjid $mjid jid2 res
	     if {[info exists jwbstate($jid2,jid,w)]} {
		 set w $jwbstate($jid2,jid,w)
	     }	    
	 }
	 normal {
	     # Mailbox!!!
	     set w ""
	 }
     }
     
     # Verify that toplevel actually exists.
     if {$w ne ""} {
	 if {![winfo exists $w]} {
	     set w ""
	 }
     }
     ::Debug 2 "\tw=$w"
     return $w
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
    set w [MakeWhiteboardExist $opts]

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
	    set wcan [::WB::GetCanvasFromWtop $w]
	    set errMsg [eval {::Import::DoImport $wcan $opts} $args]
	    if {$errMsg ne ""} {
		::UI::MessageBox -title [mc Error] -icon error -type ok \
		  -message "Failed importing: $errMsg" \
		  -parent [winfo toplevel $wcan]
	    }
	} else {
	    ::UI::MessageBox -title [mc Error] -icon error -type ok \
	      -message [mc messfailmimeimp $mime] \
	      -parent [winfo toplevel $wcan]
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

proc ::Jabber::WB::VerifyJIDWhiteboard {w} {
    variable jwbstate
    
    if {$jwbstate($w,send)} {
	if {![jlib::jidvalidate $jwbstate($w,jid)]} {
	    ::UI::MessageBox -icon warning -type ok -parent $w \
	      -message [mc jamessinvalidjid]
	    return 0
	}
    }
    return 1
}

#-------------------------------------------------------------------------------
