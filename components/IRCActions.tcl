#  IRCActions.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements IRC style actions for groupchats.
#      Nick name completion and nick alerts are also included.
#      
#  Copyright (c) 2007  Mats Bengtsson
#  
#  @@@ TODO: 1) Not sure how to handle /msg
#            2) Configurable nick alert
#            3) Implement -command for error notice
#  
# $Id: IRCActions.tcl,v 1.3 2007-05-22 09:18:17 matben Exp $

namespace eval ::IRCActions:: {
    
    option add *parseMeCDataOpts      {-foreground blue}     widgetDefault
    option add *parseNickCDataOpts    {-foreground blue}     widgetDefault
}

proc ::IRCActions::Init { } {
    
    component::register IRCActions "Implements IRC style actions for groupchats, /join. /topic, /invite, /nick, /me etc."

    # Add event hooks.
    ::hooks::register sendTextGroupChatHook [namespace current]::TextGroupChatHook
    ::hooks::register buildGroupChatWidget  [namespace current]::BuildGroupChatHook
    ::hooks::register textParseWordHook     [namespace current]::ParseWordHook
    ::hooks::register displayGroupChatMessageHook [namespace current]::DisplayHook
    
    # /join #channel -> Enter into a room called channel, if it not exists
    #     then creates a new one.
    #Ê/me text -> The /me command (implemented)
    #Ê/msg nick Message -> Start a private chat with nick and sending the Message
    #Ê/nick newNick -> Changes our nick (for all rooms)
    #Ê/topic String -> Changes the topic of the channel
    #Ê/invite nick #channel -> Sends an invitation to nick for enter into channel
    # /kick #channel nickname -> Kicks nickname off a given channel.
    # /leave -> exit room
    # /part  -> exit room

    variable RE
    set RE(join) {
	{^ */join ([^ ]+)}  
	{::IRCActions::Join}
    }
    set RE(nick) {
	{^ */nick (.+)$}  
	{::IRCActions::Nick}
    }
    set RE(msg) {
	{^ */msg (.+)$}  
	{::IRCActions::Msg}
    }
    set RE(topic) {
	{^ */topic (.+)$}  
	{::IRCActions::Topic}
    }
    set RE(subject) {
	{^ */subject (.+)$}  
	{::IRCActions::Topic}
    }
    set RE(invite) {
	{^ */invite (.+)$}  
	{::IRCActions::Invite}
    }
    set RE(kick) {
	{^ */kick (.+)$}  
	{::IRCActions::Kick}
    }
    set RE(leave) {
	{^ */leave}  
	{::IRCActions::Leave}
    }
    set RE(part) {
	{^ */part}  
	{::IRCActions::Leave}
    }

    variable lastWord ""
}

proc ::IRCActions::TextGroupChatHook {roomjid str} {
    variable RE
    	
    # Avoid expensive regexp's.
    if {[string first "/" $str] < 0} {
	return
    }
    if {![regexp {^ */[a-z]+} $str]} {
	return
    }
    set handled ""
    foreach {name spec} [array get RE] {
	lassign $spec re cmd
	if {[regexp $re $str - value]} {
	    $cmd $roomjid $value
	    set handled stop
	    break
	}
    }
    return $handled
}

proc ::IRCActions::Join {roomjid room} {
    
    # Skip any IRC style channel name.
    set room [string trimleft $room "#"]
    jlib::splitjidex $roomjid node domain res
    set joinJID $room
    if {[string first "@" $room] < 0} {
	set joinJID ${room}@${domain}
    }
    set nick [::Jabber::JlibCmd muc mynick $roomjid]
    ::Enter::EnterRoom $joinJID $nick -command [namespace code ErrorJoin]
}

proc ::IRCActions::ErrorJoin {type args} {
    # TODO
}

proc ::IRCActions::Nick {roomjid nick} {
    
    # Do this for all rooms we participate?
    ::Jabber::JlibCmd muc setnick $roomjid $nick \
      -command [namespace code ErrorNick]
}

proc ::IRCActions::ErrorNick {jlibname xmldata} {
    # TODO
}

proc ::IRCActions::Msg {roomjid value} {

    if {$value eq ""} {
	return
    }
    set nick [lindex $value 0]
    set msg [lrange $value 1 end]
    set jid $roomjid/$nick
    ::Chat::StartThread $jid -message $msg
}

proc ::IRCActions::Topic {roomjid subject} {
    ::Jabber::JlibCmd send_message $roomjid -type groupchat -subject $subject
}

proc ::IRCActions::Invite {roomjid value} {
    
    set nick [lindex $value 0]
    set room [lindex $value 1]
    jlib::splitjidex $roomjid node domain res
    if {[string first "@" $room] < 0} {
	set room ${room}@${domain}
    }    
    set jid $room/$nick
    ::Jabber::JlibCmd muc invite $roomjid $jid
}

proc ::IRCActions::Kick {roomjid value} {
    
    set room [lindex $value 0]
    set nick [lindex $value 1]
    jlib::splitjidex $roomjid node domain res
    if {[string first "@" $room] < 0} {
	set room ${room}@${domain}
    }    
    
    # Must be this room and no other.
    ::Jabber::JlibCmd muc setrole $roomjid $nick "none" 
}

proc ::IRCActions::Leave {roomjid value} {
    ::GroupChat::ExitRoomJID $roomjid
}

proc ::IRCActions::BuildGroupChatHook {roomjid} {
    set wtextsend [::GroupChat::GetWidget $roomjid wtextsend]
    bind $wtextsend <Tab> +[namespace code [list Complete $roomjid]]
}

proc ::IRCActions::Complete {roomjid} {
    
    set wtext [::GroupChat::GetWidget $roomjid wtextsend]
    set start [$wtext index "insert -1 c wordstart"]
    set stop  [$wtext index "insert -1 c wordend"]
    set str   [$wtext get $start $stop]

    set participants [::Jabber::JlibCmd muc participants $roomjid]
    set nicks [list]
    set matched 0
    foreach jid $participants {
	jlib::splitjid $jid - nick
	if {[string match $str* $nick]} {
	    lappend nicks $nick
	    set matched 1
	}
    }
    set len [llength $nicks]
    if {$len == 1} {
	$wtext delete $start $stop
	$wtext mark set insert $start
	$wtext insert insert $nicks
	return -code break
    } elseif {$len > 1} {
	bell
	return -code break
    } else {
	return
    }
}

proc ::IRCActions::ParseWordHook {type jid w word tagList} {
    variable lastWord
    
    set handled ""
    if {$word eq "/me"} {

	switch -- $type {
	    groupchat {
		jlib::splitjid $jid roomjid nick
	    }
	    chat {
		set jid2 [jlib::barejid $jid]
		if {[::Jabber::JlibCmd service isroom $jid2]} {
		    set nick $jid
		} else {
		    set nick [::Roster::GetDisplayName $jid2]
		}
	    }
	    default {
		set nick [jlib::barejid $jid]
	    }
	}
	set wd [string map [list "/me" "* $nick"] $word]
	set meopts [option get . parseMeCDataOpts {}]
	eval {$w tag configure tmecdata} $meopts
	$w insert insert $wd [concat $tagList tmecdata]
	set handled stop
    } elseif {$word eq "/msg"} {
	if {$type eq "groupchat"} {
	    
	    # Just Ignore it but lastWord id Cached.
	    set handled stop
	}
    }
    
    if {($type eq "groupchat") && ($lastWord eq "/msg")} {
	set wd "*$word*"
	set opts [option get . parseNickCDataOpts {}]
	eval {$w tag configure tnickmsg} $opts
	$w insert insert $wd [concat $tagList tnickmsg]
	set handled stop
    }
    set lastWord $word
    return $handled
}

# IRCActions::DisplayHook --
# 
#       Make some alert when my nick is displayed.

proc ::IRCActions::DisplayHook {text args} {
    
    array set argsA $args
    set xmldata $argsA(-xmldata)
    set from [wrapper::getattribute $xmldata from]
    set roomjid [jlib::barejid $from]
    set nick [::Jabber::JlibCmd muc mynick $roomjid]
    if {[string match -nocase *$nick* $text]} {    
	::Sounds::PlayWhenIdle newmsg
    }
}





