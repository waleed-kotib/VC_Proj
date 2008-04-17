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
# $Id: Growl.tcl,v 1.31 2008-04-17 15:00:28 matben Exp $

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
    set title "[mc Message]: $ujid"
    set subject [wrapper::getcdata [wrapper::getfirstchildwithtag $xmldata subject]]
    growl post [mc Message] $title $subject $cociFile
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
    set title "[mc Message]: $ujid"
    
    # Not sure if only new subjects should be added.
    # If we've got a threadid we can always geta a handle on to
    # the internal chat state with:
    # 	set chattoken [::Chat::GetTokenFrom chat threadid $threadID]
    # 	parray chattoken

    set subject [wrapper::getcdata [wrapper::getfirstchildwithtag $xmldata subject]]
    if {$subject ne ""} {
	append title "\n$subject"
    }
    growl post [mc Message] $title $body $cociFile
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

	set title "$djid $show"
	set msg "$djid $showMsg"
	if {$status ne ""} {
	    append msg "\n$status"
	}
	growl post [mc Status] $title $msg $cociFile
    }
}

proc ::Growl::FileTransferRecvHook {jid name size} {
    variable cociFile
    
    if {![::UI::IsAppInFront]} {
	set title [mc "Receive File"]
	set str "\n[mc File]: $name\n[mc Size]: [::Utils::FormatBytes $size]\n\n"
	set ujid [jlib::unescapejid $jid]
	set msg [mc jamessoobask2 $ujid $str]
	growl post [mc File] $title $msg $cociFile
    }
}

proc ::Growl::JivePhoneEventHook {type cid callID {xmldata {}}} {
    variable cociFile
    
    if {$type eq "RING"} {
	set title [mc phoneRing]
	set msg [mc phoneRingFrom $cid]
	growl post [mc Phone] $title $msg $cociFile
    }
}

proc ::Growl::MoodEventHook {xmldata mood text} {
    variable cociFile

    set title [mc moodEvent]
    set from [wrapper::getattribute $xmldata from]
    set ujid [jlib::unescapejid $from]
    if {$mood ne ""} {
	set msg "$ujid [mc heIs] [mc $mood]"
	if {$text ne ""} {
	    append msg " " [mc because] " " $text
	}
    } else {
	set msg "$ujid [mc moodRetracted]"
    }
    growl post [mc Mood] $title $msg $cociFile
} 

#-------------------------------------------------------------------------------

