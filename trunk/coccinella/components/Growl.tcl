# Growl.tcl --
# 
#       Growl notifier bindings for MacOSX.
#       This is just a first sketch.
#
#  Copyright (c) 2007 Mats Bengtsson and Antonio Camas
#  
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#       
# $Id: Growl.tcl,v 1.32 2008-06-06 13:10:10 matben Exp $

namespace eval ::Growl { 

    if {[tk windowingsystem] ne "aqua"} {
	return
    }
    if {[catch {package require growl}]} {
	return
    }
    component::define Growl  \
      "Provides support for Growl notifier on Mac OS X."

    # TODO
    #option add *growlImage            send     widgetDefault
}

proc ::Growl::Init {} {
    global  this    
    variable cociFile
    
    component::register Growl
    
    # There are some nice 64x64 error & info icons as well.
    set cociFile [::Theme::FindExactIconFile icons/128x128/coccinella.png]
    
    # Use translated strings as keys, else Growls settings wont be translatable.
    set all {"Message" "Status" "File" "Phone" "Mood"}
    growl register Coccinella [lapply mc $all] $cociFile
    
    # Add event hooks.
    ::hooks::register newMessageHook      ::Growl::MessageHook
    ::hooks::register newChatMessageHook  ::Growl::ChatMessageHook
    ::hooks::register presenceNewHook     ::Growl::PresenceHook
    ::hooks::register jivePhoneEvent      ::Growl::JivePhoneEventHook
    ::hooks::register fileTransferReceiveHook  ::Growl::FileTransferRecvHook
    ::hooks::register moodEvent           ::Growl::MoodEventHook

}

proc ::Growl::MessageHook {xmldata uuid} { 
    variable cociFile
    
    set body [wrapper::getcdata [wrapper::getfirstchildwithtag $xmldata body]]
    if {$body eq ""} {
	return
    }
    set jid [wrapper::getattribute $xmldata from]
    set jid2 [jlib::barejid $jid]
    set ujid [jlib::unescapejid $jid2]
    set title [mc "Message"]
    append title ": $ujid"
    set subject [wrapper::getcdata [wrapper::getfirstchildwithtag $xmldata subject]]
    growl post [mc "Message"] $title $subject $cociFile
}

proc ::Growl::ChatMessageHook {xmldata} {    
    variable cociFile
    
    set body [wrapper::getcdata [wrapper::getfirstchildwithtag $xmldata body]]
    if {$body eq ""} {
	return
    }

    # -from is a 3-tier jid /resource included.
    set jid [wrapper::getattribute $xmldata from]
    set jid2 [jlib::barejid $jid]
    set ujid [jlib::unescapejid $jid2]
    
    if {[::Chat::HaveChat $jid]} {
	return
    }
    set title [mc "Message"]
    append title ": $ujid"
    
    # Not sure if only new subjects should be added.
    # If we've got a threadid we can always geta a handle on to
    # the internal chat state with:
    # 	set chattoken [::Chat::GetTokenFrom chat threadid $threadID]
    # 	parray chattoken

    set subject [wrapper::getcdata [wrapper::getfirstchildwithtag $xmldata subject]]
    if {$subject ne ""} {
	append title "\n$subject"
    }
    growl post [mc "Message"] $title $body $cociFile
}

proc ::Growl::PresenceHook {jid type args} {
    variable cociFile
    
    # Notify only if in background.
    if {![::UI::IsAppInFront]} {
	array set argsA $args
	set xmldata $argsA(-xmldata)
	set from [wrapper::getattribute $xmldata from]
	set jid $from
	 
	# Skip transports since they are us.
	if {[::Roster::IsTransportHeuristics $jid]} {
	    return
	}
	
	# Skip myself.
	set myjid2 [::Jabber::Jlib myjid2]
	if {[jlib::jidequal $myjid2 [jlib::barejid $jid]]} {
	    return
	}
	
	# If we have a 'delay' this is presence sent when we login.
	set delay [::Jabber::RosterCmd getx $jid "jabber:x:delay"]
	if {$delay ne ""} {
	    return
	}
	if {![::Jabber::Jlib roster anychange $jid {type show status}]} {
	    return
	}
	
	set show $type
	if {[info exists argsA(-show)]} {
	    set show $argsA(-show)
	}
	set status ""
	if {[info exists argsA(-status)]} {
	    set status $argsA(-status)
	}
	
	# This just translates the show code into a readable text.
	set showMsg [::Roster::MapShowToText $show]
	set djid [::Roster::GetDisplayName $jid]
	if {[::Jabber::Jlib service isroom $jid]} {
	    if {[info exists argsA(-from)]} {
		set djid $argsA(-from)
	    } 
	}

	set title $djid
	set msg $showMsg
	if {$status ne ""} {
	    append msg "\n$status"
	}
	growl post [mc "Status"] $title $msg $cociFile
    }
}

proc ::Growl::FileTransferRecvHook {jid name size} {
    variable cociFile
    
    if {![::UI::IsAppInFront]} {
	set title [mc "Receive File"]
	set str "\n"
	append str [mc "File"]
	append str ": $name\n"
	append str [mc "Size"]
	append str ": [::Utils::FormatBytes $size]\n\n"
	set ujid [jlib::unescapejid $jid]
	set msg [mc "%s wants to send you this file: %s Do you want to receive this file?" $ujid $str]
	growl post [mc "File"] $title $msg $cociFile
    }
}

proc ::Growl::JivePhoneEventHook {type cid callID {xmldata {}}} {
    variable cociFile
    
    if {$type eq "RING"} {
	set title [mc "Ring, ring"]...
	set msg [mc "Phone is ringing from %s" $cid]
	growl post [mc "Phone"] $title $msg $cociFile
    }
}

proc ::Growl::MoodEventHook {xmldata mood text} {
    variable cociFile
    variable moodTextSmall

    set moodTextSmall [dict create]
    dict set moodTextSmall afraid [mc "afraid"]
    dict set moodTextSmall amazed [mc "amazed"]
    dict set moodTextSmall angry [mc "angry"]
    dict set moodTextSmall annoyed [mc "annoyed"]
    dict set moodTextSmall anxious [mc "anxious"]
    dict set moodTextSmall aroused [mc "aroused"]
    dict set moodTextSmall ashamed [mc "ashamed"]
    dict set moodTextSmall bored [mc "bored"]
    dict set moodTextSmall brave [mc "brave"]
    dict set moodTextSmall calm [mc "calm"]
    dict set moodTextSmall cold [mc "cold"]
    dict set moodTextSmall confused [mc "confused"]
    dict set moodTextSmall contented [mc "contented"]
    dict set moodTextSmall cranky [mc "cranky"]
    dict set moodTextSmall curious [mc "curious"]
    dict set moodTextSmall depressed [mc "depressed"]
    dict set moodTextSmall disappointed [mc "disappointed"]
    dict set moodTextSmall disgusted [mc "disgusted"]
    dict set moodTextSmall distracted [mc "distracted"]
    dict set moodTextSmall embarrassed [mc "embarrassed"]
    dict set moodTextSmall excited [mc "excited"]
    dict set moodTextSmall flirtatious [mc "flirtatious"]
    dict set moodTextSmall frustrated [mc "frustrated"]
    dict set moodTextSmall grumpy [mc "grumpy"]
    dict set moodTextSmall guilty [mc "guilty"]
    dict set moodTextSmall happy [mc "happy"]
    dict set moodTextSmall hot [mc "hot"]
    dict set moodTextSmall humbled [mc "humbled"]
    dict set moodTextSmall humiliated [mc "humiliated"]
    dict set moodTextSmall hungry [mc "hungry"]
    dict set moodTextSmall hurt [mc "hurt"]
    dict set moodTextSmall impressed [mc "impressed"]
    dict set moodTextSmall in_awe [mc "in awe"]
    dict set moodTextSmall in_love [mc "in love"]
    dict set moodTextSmall indignant [mc "indignant"]
    dict set moodTextSmall interested [mc "interested"]
    dict set moodTextSmall intoxicated [mc "intoxicated"]
    dict set moodTextSmall invincible [mc "invincible"]
    dict set moodTextSmall jealous [mc "jealous"]
    dict set moodTextSmall lonely [mc "lonely"]
    dict set moodTextSmall mean [mc "mean"]
    dict set moodTextSmall moody [mc "moody"]
    dict set moodTextSmall nervous [mc "nervous"]
    dict set moodTextSmall neutral [mc "neutral"]
    dict set moodTextSmall offended [mc "offended"]
    dict set moodTextSmall playful [mc "playful"]
    dict set moodTextSmall proud [mc "proud"]
    dict set moodTextSmall relieved [mc "relieved"]
    dict set moodTextSmall remorseful [mc "remorseful"]
    dict set moodTextSmall restless [mc "restless"]
    dict set moodTextSmall sad [mc "sad"]
    dict set moodTextSmall sarcastic [mc "sarcastic"]
    dict set moodTextSmall serious [mc "serious"]
    dict set moodTextSmall shocked [mc "shocked"]
    dict set moodTextSmall shy [mc "shy"]
    dict set moodTextSmall sick [mc "sick"]
    dict set moodTextSmall sleepy [mc "sleepy"]
    dict set moodTextSmall stressed [mc "stressed"]
    dict set moodTextSmall surprised [mc "surprised"]
    dict set moodTextSmall thirsty [mc "thirsty"]
    dict set moodTextSmall worried [mc "worried"]

    set title [mc "Mood change"]
    set from [wrapper::getattribute $xmldata from]
    set ujid [jlib::unescapejid $from]
    if {$mood ne ""} {
	set msg "$ujid "
	append msg [mc "is"]
	append msg " "
	append msg [dict get $moodTextSmall $mood]
	if {$text ne ""} {
	    append msg " " [mc "because"] " " $text
	}
    } else {
	set msg "$ujid " [mc "retracted mood"]
    }
    growl post [mc "Mood"] $title $msg $cociFile
} 

#-------------------------------------------------------------------------------

