#  JWB.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It provides the glue between jabber and the whiteboard.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: JWB.tcl,v 1.1 2004-03-13 15:16:10 matben Exp $

package provide JWB 1.0

# The ::Jabber::WB:: namespace -------------------------------------------------

namespace eval ::Jabber::WB:: {
       
    ::hooks::add jabberInitHook               ::Jabber::WB::Init
    
    # Internal storage for jabber specific parts of whiteboard.
    variable jwbstate
    
    # Get/put ip numbers.
    variable getid 1001
    
    # Records any callback procs, index from 'getid'.
    variable getcmd
    
    # Array that maps 'jid' to its ip number.
    variable jidToIP
    variable initted 0
}

proc ::Jabber::WB::Init { } {
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::privatexmlns privatexmlns
    
    ::hooks::add whiteboardBuildEntryHook     ::Jabber::WB::BuildEntryHook
    ::hooks::add whiteboardSetMinsizeHook     ::Jabber::WB::SetMinsizeHook    
    ::hooks::add whiteboardCloseHook          ::Jabber::WB::CloseHook        20
    ::hooks::add whiteboardSendMessageHook    ::Jabber::WB::SendMessageListHook
    ::hooks::add whiteboardSendGenMessageHook ::Jabber::WB::SendGenMessageListHook
    ::hooks::add whiteboardPutFileHook        ::Jabber::WB::PutFileOrScheduleHook
    ::hooks::add whiteboardConfigureHook      ::Jabber::WB::Configure
    ::hooks::add serverPutRequestHook         ::Jabber::WB::HandlePutRequest
    ::hooks::add presenceHook                 ::Jabber::WB::PresenceHook
    ::hooks::add autobrowsedCoccinellaHook    ::Jabber::WB::AutoBrowseHook
    ::hooks::add loginHook                    ::Jabber::WB::LoginHook
    ::hooks::add logoutHook                   ::Jabber::WB::LogoutHook
    ::hooks::add groupchatExitRoomHook        ::Jabber::WB::ExitRoomHook

    # Register for the messages we want. Duplicate protocols.
    $jstate(jlib) message_register normal coccinella:wb  \
      [namespace current]::HandleSpecialMessage 20
    $jstate(jlib) message_register chat coccinella:wb  \
      [namespace current]::HandleRawChatMessage
    $jstate(jlib) message_register groupchat coccinella:wb  \
      [namespace current]::HandleRawGroupchatMessage

    $jstate(jlib) message_register normal $privatexmlns(whiteboard)  \
      [namespace current]::HandleSpecialMessage 20
    $jstate(jlib) message_register chat $privatexmlns(whiteboard)  \
      [namespace current]::HandleRawChatMessage
    $jstate(jlib) message_register groupchat $privatexmlns(whiteboard)  \
      [namespace current]::HandleRawGroupchatMessage

    # Not completed SVG protocol...
    $jstate(jlib) message_register chat "http://jabber.org/protocol/svgwb" \
      [namespace current]::HandleSVGWBChatMessage
    $jstate(jlib) message_register groupchat "http://jabber.org/protocol/svgwb" \
      [namespace current]::HandleSVGWBGroupchatMessage

  }

proc ::Jabber::WB::InitUI { } {
    global  prefs
    variable initted

    set buttonTrayDefs {
	save       {::CanvasFile::DoSaveCanvasFile $wtop}
	open       {::CanvasFile::DoOpenCanvasFile $wtop}
	import     {::Import::ImportImageOrMovieDlg $wtop}
	send       {::Jabber::WB::DoSendCanvas $wtop}
	print      {::UserActions::DoPrintCanvas $wtop}
	stop       {::Jabber::WB::Stop $wtop}
    }
    ::WB::SetButtonTrayDefs $buttonTrayDefs

    set menuDefsFile {
	{command   mNew                {::Jabber::WB::NewWhiteboard}     normal   N}
	{command   mCloseWindow        {::UI::DoCloseWindow}             normal   W}
	{separator}
	{command   mOpenImage/Movie    {::Import::ImportImageOrMovieDlg $wtop}    normal   I}
	{command   mOpenURLStream      {::OpenMulticast::OpenMulticast $wtop}     normal   {}}
	{command   mStopPut/Get/Open   {::CanvasCmd::CancelAllPutGetAndPendingOpen $wtop} normal {}}
	{separator}
	{command   mOpenCanvas         {::CanvasFile::DoOpenCanvasFile $wtop}     normal   O}
	{command   mSaveCanvas         {::CanvasFile::DoSaveCanvasFile $wtop}     normal   S}
	{separator}
	{command   mSaveAs             {::CanvasCmd::SavePostscript $wtop}      normal   {}}
	{command   mPageSetup          {::UserActions::PageSetup $wtop}           normal   {}}
	{command   mPrintCanvas        {::UserActions::DoPrintCanvas $wtop}       normal   P}
	{separator}
	{command   mQuit               {::UserActions::DoQuit}                    normal   Q}
    }
    if {![::Plugins::HavePackage QuickTimeTcl]} {
	lset menuDefsFile 4 3 disabled
    }
    # If embedded the embedding app should close us down.
    if {$prefs(embedded)} {
	lset menuDefsFile end 3 disabled
    }
    ::WB::SetMenuDefs file $menuDefsFile

    set initted 1
}

# Jabber::WB::InitWhiteboard --
#
#       Initialize jabber things for this specific whiteboard instance.

proc ::Jabber::WB::InitWhiteboard {wtop} {
    variable jwbstate
   
    set jwbstate($wtop,send) 0

    # The current receiver of our messages. 'textvariable' in UI entry.
    # Identical to 'tojid' for standard chats, but a list of jid's
    # with /nick for groupchat's.
    set jwbstate($wtop,jid) ""

    set jwbstate($wtop,type) normal
}


proc ::Jabber::WB::NewWhiteboard {args} {
    variable jwbstate
    variable initted
    
    if {!$initted} {
	::Jabber::WB::InitUI
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
	    -jid - -send - -type {
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
#       
# Results:
#       $wtop; may create new toplevel whiteboard

proc ::Jabber::WB::NewWhiteboardTo {jid args} {
    variable initted
    variable jwbstate
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::WB::NewWhiteboardTo jid=$jid, args='$args'"
    
    array set argsArr $args
    
    if {!$initted} {
	::Jabber::WB::InitUI
    }
    
    # Make a fresh whiteboard window. Use any -type argument.
    # Note that the jid can belong to a room but we may still have a p2p chat.
    #    jid is room: groupchat live
    #    jid is a user in a room: chat
    #    jid is ordinary available user: chat
    #    jid is ordinary but unavailable user: normal message
    jlib::splitjid $jid jid2 res
    set isRoom 0
    if {[info exists argsArr(-type)]} {
	if {[string equal $argsArr(-type) "groupchat"]} {
	    set isRoom 1
	}
    } elseif {[$jstate(jlib) service isroom $jid]} {
	set isRoom 1
    }
    set isUserInRoom 0
    if {[$jstate(jlib) service isroom $jid2] && [string length $res]} {
	set isUserInRoom 1
    }
    set isAvailable [$jstate(roster) isavailable $jid]
    
    ::Jabber::Debug 2 "\tisRoom=$isRoom, isUserInRoom=$isUserInRoom, isAvailable=$isAvailable"
 
    set wtop [::WB::GetNewToplevelPath]

    if {$isRoom} {
	
	# Must enter room in the usual way if not there already.
	set allRooms [$jstate(jlib) service allroomsin]
	::Jabber::Debug 3 "\tallRooms=$allRooms"
	
	if {[lsearch $allRooms $jid] < 0} {
	    set ans [::Jabber::GroupChat::EnterOrCreate \
	      enter -roomjid $jid -autoget 1]
	    if {$ans == "cancel"} {
		return
	    }
	}
	set roomName [$jstate(browse) getname $jid]    
	if {[llength $roomName]} {
	    set title "Groupchat room $roomName"
	} else {
	    set title "Groupchat room $jid"
	}
	set jwbstate($wtop,type)   groupchat
	set jwbstate($wtop,send)   1
    } elseif {$isAvailable || $isUserInRoom} {
	if {[info exists argsArr(-thread)]} {
	    set thread $argsArr(-thread)
	} else {
	    
	    # Make unique thread id.
	    set thread [::sha1pure::sha1 "$jstate(mejid)[clock seconds]"]
	}
	set name [$jstate(roster) getname $jid]
	if {[string length $name]} {
	    set title "Chat with $name"
	} else {
	    set title "Chat with $jid"
	}	
	set jwbstate($wtop,type)   chat
	set jwbstate($wtop,thread) $thread
	set jwbstate($wtop,send)   1
	set jwbstate($thread,wtop) $wtop
    } else {
	set name [$jstate(roster) getname $jid]
	if {[string length $name]} {
	    set title "Send Message to $name"
	} else {
	    set title "Send Message to $jid"
	}
	set jwbstate($wtop,type)   normal
	set jwbstate($wtop,send)   0
    }
    set jwbstate($wtop,jid) $jid
    set jwbstate($jid,wtop) $wtop

    ::WB::BuildWhiteboard $wtop -title $title
        
    return $wtop
}

# ::Jabber::WB::BuildEntryHook --
# 
#       Build the jabber specific part of the whiteboard.

proc ::Jabber::WB::BuildEntryHook {wtop wclass wcomm} {
    variable jwbstate
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::WB::BuildEntryHook wcomm=$wcomm"
	
    set contactOffImage [::Theme::GetImage \
      [option get $wclass contactOffImage {}]]
    set contactOnImage  [::Theme::GetImage \
      [option get $wclass contactOnImage {}]]
    set iconResize      [::Theme::GetImage \
      [option get $wclass resizeHandleImage {}]]
    
    frame $wcomm.f -relief raised -borderwidth 1
    pack  $wcomm.f -side bottom -fill x

    set   frja $wcomm.f.ja
    frame $frja
    pack  $frja -side left
     
    # The header.
    label $frja.comm -anchor w -text [::msgcat::mc {Jabber Server}]
    label $frja.user -anchor w -text [::msgcat::mc {Jabber Id}]
    if {[::Jabber::IsConnected]} {
	label $frja.icon -image $contactOnImage
    } else {
	label $frja.icon -image $contactOffImage
    }
    grid $frja.comm $frja.user -sticky w -padx 8 -pady 0
    grid $frja.icon -row 0 -column 2 -sticky w -pady 0
    
    # The entries.
    set jidlist [$jstate(roster) getusers]
    entry $frja.ad -width 14 -relief sunken -state disabled \
      -textvariable ::Jabber::jserver(this)
    ::entrycomp::entrycomp $frja.us $jidlist -width 18 -relief sunken \
      -textvariable [namespace current]::jwbstate($wtop,jid)
    checkbutton $frja.to -highlightthickness 0 -state disabled \
      -text [::msgcat::mc {Send Live}] \
      -variable [namespace current]::jwbstate($wtop,send)
    
    grid $frja.ad -row 1 -column 0 -sticky ew -padx 4
    grid $frja.us -row 1 -column 1 -sticky ew -padx 4
    grid $frja.to -row 1 -column 2 -padx 6

    # Resize handle.
    frame $wcomm.f.pad
    pack  $wcomm.f.pad -side right -fill both -expand true
    label $wcomm.f.pad.hand -relief flat -borderwidth 0 -image $iconResize
    pack  $wcomm.f.pad.hand -side right -anchor sw

    # Cache widgets paths.
    set jwbstate($wtop,wclass)    $wclass
    set jwbstate($wtop,wframe)    $wcomm.f
    set jwbstate($wtop,wfrja)     $frja
    set jwbstate($wtop,wjid)      $frja.us
    set jwbstate($wtop,wsend)     $frja.to
    set jwbstate($wtop,wcontact)  $frja.icon
    
    # Fix widget states.
    set netstate logout
    if {[::Jabber::IsConnected]} {
	set netstate login
    }
    ::Jabber::WB::SetStateFromType $wtop
    ::Jabber::WB::SetNetworkState  $wtop $netstate
}

proc ::Jabber::WB::Configure {wtop args} {
    variable jwbstate
    
    foreach {key value} $args {
	set akey [string trimleft $key -]
	set jwbstate($wtop,$akey) $value
    }
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
    set wMinEntry [winfo reqwidth $jwbstate($wtop,wfrja)]
    set hMinEntry [winfo reqheight $jwbstate($wtop,wframe)]
    set wMin [min $wMin $wMinEntry]
    set hMin [expr $hMin + $hMinEntry]
    wm minsize $w $wMin $hMin
}

proc ::Jabber::WB::Stop {wtop} {
    variable jwbstate
    
    switch -- $jwbstate($wtop,type) {
	chat - groupchat {
	    ::CanvasCmd::CancelAllPutGetAndPendingOpen $wtop
	}
	default {
	    ::Import::HttpResetAll $wtop
	}
    }
}

# Jabber::WB::LoginHook --
# 
#       The login hook command.

proc ::Jabber::WB::LoginHook { } {
    
    # Multiinstance whiteboard UI stuff.
    foreach w [::WB::GetAllWhiteboards] {
	set wtop [::UI::GetToplevelNS $w]
	::Jabber::WB::SetNetworkState $wtop login
    }
}


proc ::Jabber::WB::LogoutHook { } {
    
    foreach w [::WB::GetAllWhiteboards] {
	set wtop [::UI::GetToplevelNS $w]
	::Jabber::WB::SetNetworkState $wtop logout
    }    
}

proc ::Jabber::WB::CloseHook {wtop} {
    variable jwbstate
    
    ::Jabber::Debug 2 "::Jabber::WB::CloseHook wtop=$wtop"
    
    if {$wtop == "."} {
	set w .
    } else {
	set w [string trimright $wtop .]
    }
    
    switch -- $jwbstate($wtop,type) {
	chat {
	    set ans [tk_messageBox -icon info -parent $w -type yesno \
	      -message [FormatTextForMessageBox [::msgcat::mc jamesswbchatlost]]]
	    if {$ans != "yes"} {
		return stop
	    }
	}
	groupchat {
	    
	    # Everything handled from Jabber::GroupChat
	    set ans [::Jabber::GroupChat::Exit $jwbstate($wtop,jid)]
	    if {$ans != "yes"} {
		return stop
	    }
	}
	default {
	    # empty
	}
    }
    ::Jabber::WB::Free $wtop
}

proc ::Jabber::WB::ExitRoomHook {roomJid} {
    variable jwbstate
    
    set wtop [::Jabber::WB::GetWtopFromMessage "groupchat" $roomJid]
    if {[string length $wtop]} {
	::WB::DestroyMain $wtop
	::Jabber::WB::Free $wtop
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
    
    ::Jabber::Debug 2 "::Jabber::WB::SendMessageHook"
    
    # Check that still connected to server.
    if {![::Jabber::IsConnected]} {
	return
    }
    array set opts {-force 0}
    array set opts $args
        
    if {$jwbstate($wtop,send) || $opts(-force)} {
	if {[::Jabber::WB::VerifyJIDWhiteboard $wtop]} {
	    
	    # Here we shall decide the 'type' of message sent (normal, chat, groupchat)
	    # depending on the type of whiteboard (via wtop).
	    set argsList [::Jabber::WB::SendArgs $wtop]
	    set jid $jwbstate($wtop,jid)
	    
	    eval {::Jabber::WB::SendMessage $jid $msg} $argsList
	} else {
	    
	    # Perhaps we should give some aid here; set focus?
	}
    }
}

# Jabber::WB::SendMessageListHook --
#
#       As above but for a list of commands.

proc ::Jabber::WB::SendMessageListHook {wtop msgList args} {
    variable jwbstate
    
    ::Jabber::Debug 2 "::Jabber::WB::SendMessageListHook"
    
    if {![::Jabber::IsConnected]} {
	return
    }
    array set opts {-force 0}
    array set opts $args
    
    if {$jwbstate($wtop,send) || $opts(-force)} {
	if {[::Jabber::WB::VerifyJIDWhiteboard $wtop]} {
	    set jid $jwbstate($wtop,jid)
	    set argsList [::Jabber::WB::SendArgs $wtop]
	    eval {::Jabber::WB::SendMessageList $jid $msgList} $argsList
	} else {
	    
	    # Perhaps we should give some aid here; set focus?
	}
    }
}

# Jabber::WB::SendGenMessageListHook --
# 
#       As above but includes a prefix in each message from the old
#       protocol. BAD!!!

proc ::Jabber::WB::SendGenMessageListHook {wtop msgList args} {
    variable jwbstate
    
    ::Jabber::Debug 2 "::Jabber::WB::SendGenMessageListHook"
    
    if {![::Jabber::IsConnected]} {
	return
    }
    array set opts {-force 0}
    array set opts $args

    if {$jwbstate($wtop,send) || $opts(-force)} {
	if {[::Jabber::WB::VerifyJIDWhiteboard $wtop]} {
	    set jid $jwbstate($wtop,jid)
	    set argsList [::Jabber::WB::SendArgs $wtop]
	    eval {::Jabber::WB::SendRawMessageList $jid $msgList} $argsList
	}    
    }
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

proc ::Jabber::WB::SendMessage {jid msg args} {    
    upvar ::Jabber::jstate jstate
    
    set xlist [::Jabber::WB::CanvasCmdListToMessageXElement [list $msg]]
    if {[catch {
	eval {$jstate(jlib) send_message $jid -xlist $xlist} $args
    } err]} {
	::Jabber::DoCloseClientConnection
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox $err]
    }
}

# Jabber::WB::SendMessageList --
#
#       As above but for a list of commands.

proc ::Jabber::WB::SendMessageList {jid msgList args} {
    upvar ::Jabber::jstate jstate
    
    set xlist [::Jabber::WB::CanvasCmdListToMessageXElement $msgList]
    if {[catch {
	eval {$jstate(jlib) send_message $jid -xlist $xlist} $args
    } err]} {
	::Jabber::DoCloseClientConnection
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
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
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
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

proc ::Jabber::WB::CanvasCmdListToMessageXElement {cmdList} {
    upvar ::Jabber::jprefs jprefs
    
    if {$jprefs(useSVGT)} {
	
	# Form SVG element.
	set subx {}
	foreach cmd $cmdList {
	    set subx [concat $subx \
	      [can2svg::svgasxmllist $cmd -usestyleattribute 0]]
	}
	set xlist [list [wrapper::createtag x -attrlist  \
	  {xmlns http://jabber.org/protocol/svgwb} -subtags $subx]]
    } else {
    
	# Form an <x xmlns='coccinella:wb'><raw> element in message.
	set subx {}
	foreach cmd $cmdList {
	    lappend subx [wrapper::createtag "raw" \
	      -chdata "CANVAS: $cmd"]
	}
	set xlist [list [wrapper::createtag x -attrlist  \
	  {xmlns coccinella:wb} -subtags $subx]]
    }
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

    if {[::Jabber::IsWellFormedJID $jid]} {
		
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
	  [FormatTextForMessageBox [::msgcat::mc jamessinvalidjid]]
    }
}

# Various message handlers......................................................

# Jabber::WB::HandleSpecialMessage --
# 
#       Takes care of any special (BAD) commands from the old protocol.

proc ::Jabber::WB::HandleSpecialMessage {jlibname xmlns args} {
        
    ::Jabber::Debug 2 "::Jabber::WB::HandleSpecialMessage $xmlns, args=$args"
    array set argsArr $args
        
    set rawList [::Jabber::WB::GetRawMessageList $argsArr(-x) $xmlns]
    set ishandled 1
    foreach raw $rawList {
	
	switch -glob -- $raw {
	    "GET IP:*" {
		if {[regexp {^GET IP: +([^ ]+)$} $raw m id]} {
		    ::Jabber::WB::PutIPnumber $argsArr(-from) $id
		}
	    }
	    "PUT IP:*" {
		    
		# We have got the requested ip number from the client.
		if {[regexp {^PUT IP: +([^ ]+) +([^ ]+)$} $raw m id ip]} {
		    ::Jabber::WB::GetIPCallback $argsArr(-from) $id $ip
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
#       CANVAS: prefixed drawing commands.

proc ::Jabber::WB::HandleRawChatMessage {jlibname xmlns args} {
        
    ::Jabber::Debug 2 "::Jabber::WB::HandleRawChatMessage args=$args"
    array set argsArr $args
        
    set rawList [::Jabber::WB::GetRawMessageList $argsArr(-x) $xmlns]
    eval {::Jabber::WB::ChatMsg $rawList} $args
    eval {::hooks::run newWBChatMessageHook} $args
    
    # We have handled this message completely.
    return 1
}

# Jabber::WB::HandleRawGroupchatMessage --
# 
#       This is the dispatcher for "raw" chat whiteboard messages using the
#       CANVAS: prefixed drawing commands.

proc ::Jabber::WB::HandleRawGroupchatMessage {jlibname xmlns args} {
	
    ::Jabber::Debug 2 "::Jabber::WB::HandleRawGroupchatMessage args=$args"	
    array set argsArr $args
    
    # Do not duplicate ourselves!
    if {![::Jabber::IsMyGroupchatJid $argsArr(-from)]} {
	set rawList [::Jabber::WB::GetRawMessageList $argsArr(-x) $xmlns]
	eval {::Jabber::WB::GroupChatMsg $rawList} $args
	eval {::hooks::run newWBGroupChatMessageHook} $args
    }
    
    # We have handled this message completely.
    return 1
}


proc ::Jabber::WB::HandleSVGWBChatMessage {jlibname xmlns args} {
    
    ::Jabber::Debug 2 "::Jabber::WB::HandleSVGWBChatMessage"
    
    # We have handled this message completely.
    return 1
}

proc ::Jabber::WB::HandleSVGWBGroupchatMessage {jlibname xmlns args} {
    
    ::Jabber::Debug 2 "::Jabber::WB::HandleSVGWBGroupchatMessage"
    
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
#       a list of raw element drawing commands, or empty.

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

proc ::Jabber::WB::Free {wtop} {
    variable jwbstate
    
    if {[info exists jwbstate($wtop,thread)]} {
	catch {unset jwbstate($jwbstate($wtop,thread),wtop)}
    }
    if {[info exists jwbstate($wtop,jid)]} {
	catch {unset jwbstate($jwbstate($wtop,jid),wtop)}
    }
    array unset jwbstate "$wtop,*"    
}

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
    variable getcmd
    variable getid
    variable jidToIP

    ::Jabber::Debug 2 "::Jabber::WB::GetIPnumber:: jid=$jid, cmd='$cmd'"
    
    if {$cmd != ""} {
	set getcmd($getid) $cmd
    }
    
    # What shall we do when we already have the IP number?
    if {[info exists jidToIP($jid)]} {
	::Jabber::WB::GetIPCallback $jid $getid $jidToIP($jid)
    } else {
	::Jabber::WB::SendRawMessageList $jid [list "GET IP: $getid"]
    }
    incr getid
}

# Jabber::WB::GetIPCallback --
#
#       This proc gets called when a requested ip number is received
#       by our server.
#
# Arguments:
#       fromjid     fully qualified  "username@host/resource"
#       id
#       ip
#       
# Results:
#       Any registered callback proc is eval'ed.

proc ::Jabber::WB::GetIPCallback {fromjid id ip} {    
    upvar ::Jabber::jstate jstate
    variable getcmd
    variable jidToIP

    ::Jabber::Debug 2 "::Jabber::WB::GetIPCallback: fromjid=$fromjid, id=$id, ip=$ip"

    set jidToIP($fromjid) $ip
    if {[info exists getcmd($id)]} {
	::Jabber::Debug 2 "   getcmd($id)='$getcmd($id)'"
	eval $getcmd($id) $fromjid
	unset getcmd($id)
    }
}

proc ::Jabber::WB::PutIPnumber {jid id} {
    
    ::Jabber::Debug 2 "::Jabber::WB::PutIPnumber:: jid=$jid, id=$id"
    
    set ip [::Network::GetThisOutsideIPAddress]
    ::Jabber::WB::SendRawMessageList $jid [list "PUT IP: $id $ip"]
}

# Jabber::WB::GetCoccinellaServers --
# 
#       Get Coccinella server ports and ip via <iq>.

proc ::Jabber::WB::GetCoccinellaServers {jid3 {cmd {}}} {
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::privatexmlns privatexmlns
    
    $jstate(jlib) iq_get $privatexmlns(servers) $jid3  \
      -command [list ::Jabber::WB::GetCoccinellaServersCallback $jid3 $cmd]
}

proc ::Jabber::WB::GetCoccinellaServersCallback {jid3 cmd jlibname type subiq} {
    variable jidToIP
    
    # ::Jabber::WB::GetCoccinellaServersCallback jabberlib1 ok 
    #  {query {xmlns http://coccinella.sourceforge.net/protocol/servers} 0 {} {
    #     {ip {protocol putget port 8235} 0 212.214.113.57 {}} 
    #     {ip {protocol http port 8077} 0 212.214.113.57 {}}
    #  }}
    ::Jabber::Debug 2 "::Jabber::WB::GetCoccinellaServersCallback"

    if {$type == "error"} {
	return
    }
    set ipElements [wrapper::getchildswithtag $subiq ip]
    set ip [wrapper::getcdata [lindex $ipElements 0]]
    set jidToIP($jid3) $ip
    if {$cmd != ""} {
	eval $cmd
    }
}

proc ::Jabber::WB::PresenceHook {jid type args} {
    variable jidToIP
    
    ::Jabber::Debug 2 "::Jabber::WB::PresenceHook jid=$jid, type=$type"
    
    switch -- $type {
	unavailable {
	    
	    # Need to remove our cached ip number for this jid.
	    catch {unset jidToIP($jid)}
	}
	available {
	    
	}
    }
}

proc ::Jabber::WB::AutoBrowseHook {jid} {
    upvar ::Jabber::jprefs jprefs

    ::Jabber::Debug 2 "::Jabber::WB::AutoBrowseHook jid=$jid"
    
    # Shall we query for its ip address right away?
    if {$jprefs(preGetIP)} {
	if {1} {
	    ::Jabber::WB::GetIPnumber $jid
	} else {
	    
	    # New through <iq> element.
	    # Switch to this with version 0.94.9 or later!
	    ::Jabber::WB::GetCoccinellaServers $jid
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
    variable jidToIP
    variable jwbstate
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::WB::PutFileOrScheduleHook: \
      wtop=$wtop, fileName=$fileName, opts='$opts'"
    
    # Before doing anything check that the Send checkbutton is on. ???
    if {!$jwbstate($wtop,send)} {
	::Jabber::Debug 2 "    doSend=0 => return"
	return
    }
    
    # Verify that jid is well formed.
    if {![::Jabber::WB::VerifyJIDWhiteboard $wtop]} {
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
    set isRoom 0
    
    if {[regexp {^(.+)@([^/]+)/([^/]*)} $tojid match name host res]} {
	
	# The 'tojid' is already complete with resource.
	set allJid3 $tojid
	lappend opts -from $jstate(mejidres)
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
	    lappend opts -from $jstate(mejidres)
	}
    }
    
    ::Jabber::Debug 2 "   allJid3=$allJid3"
    
    # We shall put to all resources. Treat each in turn.
    foreach jid3 $allJid3 {
	
	# If we are in a room all must be available, else check.
	if {$isRoom} {
	    set avail 1
	} else {
	    set avail [$jstate(roster) isavailable $jid3]
	}
	
	# Each jid must get its own -to attribute.
	set optjidList [concat $opts -to $jid3]
	
	::Jabber::Debug 2 "   jid3=$jid3, avail=$avail"
	
	if {$avail} {
	    if {[info exists jidToIP($jid3)]} {
		
		# This one had already told us its ip number, good!
		::Jabber::WB::PutFile $wtop $fileName $mime $optjidList $jid3
	    } else {
		
		# This jid is online but has not told us its ip number.
		# We need to get this jid's ip number and register the
		# PutFile as a callback when receiving this ip.
		if {1} {
		    ::Jabber::WB::GetIPnumber $jid3 \
		      [list ::Jabber::WB::PutFile $wtop $fileName $mime $optjidList]
		} else {
		    
		    # New through <iq> element.
		    # Switch to this with version 0.94.8 or later!
		    ::Jabber::WB::GetCoccinellaServers $jid3  \
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
    variable jidToIP
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::WB::PutFile: fileName=$fileName, opts='$opts', jid=$jid"
 
    if {![info exists jidToIP($jid)]} {
	puts "::Jabber::WB::PutFile: Houston, we have a problem. \
	  jidToIP($jid) not there"
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

    ::PutFileIface::PutFile $wtop $fileName $jidToIP($jid) $optList
}

# Jabber::WB::HandlePutRequest --
# 
#       Takes care of a PUT command from the server.

proc ::Jabber::WB::HandlePutRequest {channel fileName opts} {
	
    ::Jabber::Debug 2 "::Jabber::WB::HandlePutRequest"
    
    # The whiteboard must exist!
    set wtop [::Jabber::WB::MakeWhiteboardExist $opts]
    ::GetFileIface::GetFile $wtop $channel $fileName $opts
}

# ::Jabber::WB::ChatMsg, GroupChatMsg --
# 
#       Handles incoming chat/groupchat message aimed for a whiteboard.
#       It may not exist, for instance, if we receive a new chat thread.
#       Then create a specific whiteboard for this chat/groupchat.
#       The commands shall only be CANVAS: types.
#       
# Arguments:
#       args        -from, -to, -type, -thread, -x,...

proc ::Jabber::WB::ChatMsg {rawList args} {    
    upvar ::Jabber::jstate jstate

    array set argsArr $args
    ::Jabber::Debug 2 "::Jabber::WB::ChatMsg args='$args'"
    
    jlib::splitjid $argsArr(-from) jid2 res

    # This one returns empty if not exists.
    set wtop [::Jabber::WB::GetWtopFromMessage "chat" $argsArr(-from)  \
      $argsArr(-thread)]
    if {$wtop == ""} {
	set wtop [eval {::Jabber::WB::NewWhiteboardTo $argsArr(-from)} $args]
    }
    set rawList [::Jabber::WB::HandleAnyResizeImage $wtop $rawList]
    foreach line $rawList {
	::CanvasUtils::HandleCanvasDraw $wtop [lrange $line 1 end]
    }     
}

proc ::Jabber::WB::GroupChatMsg {rawList args} {    
    upvar ::Jabber::jstate jstate

    array set argsArr $args
    ::Jabber::Debug 2 "::Jabber::WB::GroupChatMsg args='$args'"
    
    # The -from argument is either the room itself, or usually a user in
    # the room.
    jlib::splitjid $argsArr(-from) roomjid resource
    set wtop [::Jabber::WB::GetWtopFromMessage "groupchat" $roomjid]
    if {$wtop == ""} {
	set wtop [eval {::Jabber::WB::NewWhiteboardTo $roomjid} $args]
    }
    set rawList [::Jabber::WB::HandleAnyResizeImage $wtop $rawList]
    foreach line $rawList {
	::CanvasUtils::HandleCanvasDraw $wtop [lrange $line 1 end]
    } 
}

# Jabber::WB::HandleAnyResizeImage --
# 
#       Until we have a better protocol for this handle it here.
#       This really SUCKS!!!

proc ::Jabber::WB::HandleAnyResizeImage {wtop cmdList} {
    
    set canCmdList {}
    foreach cmd $cmdList {
	if {[regexp {^RESIZE IMAGE: +([^ ]+) +([^ ]+) +([-0-9]+)$}  \
	  $cmd match utag utagNew zoom]} {
	    ::Import::ResizeImage $wtop $zoom $utag $utagNew "local"
	} else {
	    lappend canCmdList $cmd
	}
    }
    return $canCmdList
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
    
    ::Jabber::Debug 2 "::Jabber::WB::MakeWhiteboardExist"

    switch -- $optArr(-type) {
	chat {
	    set wtop [::Jabber::WB::GetWtopFromMessage chat $optArr(-from) \
	      $optArr(-thread)]
	    if {$wtop == ""} {
		set wtop [::Jabber::WB::NewWhiteboardTo $optArr(-from)  \
		  -thread $optArr(-thread)]
	    }
	}
	groupchat {
	    if {![regexp {(^[^@]+@[^/]+)(/.*)?} $optArr(-from) match roomjid]} {
		return -code error  \
		  "The jid we got \"$optArr(-from)\" was not well-formed!"
	    }
	    set wtop [::Jabber::WB::GetWtopFromMessage groupchat $optArr(-from)]
	    if {$wtop == ""} {
		set wtop [::Jabber::WB::NewWhiteboardTo $roomjid]
	    }
	}
	default {
	    # Normal message. Shall go in inbox ???????????
	    set wtop [::Jabber::WB::GetWtopFromMessage normal $optArr(-from)]
	}
    }
    return $wtop
}

# ::Jabber::WB::GetWtopFromMessage --
# 
#       Figures out if we've got an existing whiteboard for an incoming
#       message. Need to map 'type', 'jid', and 'thread'. 

proc ::Jabber::WB::GetWtopFromMessage {type jid {thread {}}} {
    variable jwbstate
    
    set wtop ""
    
    switch -- $type {
	 chat {
	     if {[info exists jwbstate($thread,wtop)]} {
		 set wtop $jwbstate($thread,wtop)
	     }	    
	 }
	 groupchat {
	 
	     # The jid is typically the 'roomjid/nickorhash' but can be the room itself.
	     jlib::splitjid $jid jid2 resource
	     if {[info exists jwbstate($jid2,wtop)]} {
		 set wtop $jwbstate($jid2,wtop)
	     }	    
	 }
	 normal {
	     # Mailbox!!!
	     set wtop ""
	 }
     }
     
     # Verify that toplevel actually exists.
     if {[string length $wtop] > 0} {
	 if {[string equal $wtop "."]} {
	     set w .
	 } else {
	     set w [string trimright $wtop "."]
	 }
	 if {![winfo exists $w]} {
	     set wtop ""
	 }
     }
     ::Jabber::Debug 2 "\twtop=$wtop"
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
	
    ::Jabber::Debug 2 "::Jabber::WB::DispatchToImporter"

    array set optArr $opts

    # Creates WB if not exists.
    set wtop [::Jabber::WB::MakeWhiteboardExist $opts]

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
		tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
		  -message "Failed importing: $errMsg" \
		  -parent [winfo toplevel $wCan]
	    }
	} else {
	    tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	      -message [::msgcat::mc messfailmimeimp $mime] \
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
	if {![::Jabber::IsWellFormedJID $jwbstate($wtop,jid)]} {
	    tk_messageBox -icon warning -type ok -parent $w -message  \
	      [FormatTextForMessageBox [::msgcat::mc jamessinvalidjid]]
	    return 0
	}
    }
    return 1
}

#-------------------------------------------------------------------------------
