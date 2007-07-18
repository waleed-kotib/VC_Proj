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
# $Id: Growl.tcl,v 1.21 2007-07-18 09:40:09 matben Exp $

namespace eval ::Growl:: { }

proc ::Growl::Init { } {
    global  this    
    variable cociFile
    
    if {[tk windowingsystem] ne "aqua"} {
	return
    }
    if {[catch {package require growl}]} {
	return
    }
    component::register Growl  \
      "Provides support for Growl notifier on Mac OS X."
    
    # There are some nice 64x64 error & info icons as well.
    set cociFile [file join $this(imagePath) Coccinella.png]
    
    growl register Coccinella  \
      {newMessage changeStatus fileTransfer phoneRings moodEvent} $cociFile
    
    # Add event hooks.
    ::hooks::register newMessageHook      ::Growl::MessageHook
    ::hooks::register newChatMessageHook  ::Growl::ChatMessageHook
    ::hooks::register presenceNewHook     ::Growl::PresenceHook
    ::hooks::register jivePhoneEvent      ::Growl::JivePhoneEventHook
    ::hooks::register fileTransferReceiveHook  ::Growl::FileTransferRecvHook
    ::hooks::register moodEvent           ::Growl::MoodEventHook

}

proc ::Growl::MessageHook {body args} { 
    variable cociFile
    
    if {$body eq ""} {
	return
    }
    array set argsA $args
    set xmldata $argsA(-xmldata)
    set jid [wrapper::getattribute $xmldata from]
    set jid2 [jlib::barejid $jid]
    set title "Message From: $jid2"
    if {[info exists argsA(-subject)]} {
	set subject $argsA(-subject)
    } else {
	set subject ""
    }
    growl post newMessage $title $subject $cociFile
}

proc ::Growl::ChatMessageHook {body args} {    
    variable cociFile
    
    if {$body eq ""} {
	return
    }
    array set argsA $args
    set xmldata $argsA(-xmldata)

    # -from is a 3-tier jid /resource included.
    set jid [wrapper::getattribute $xmldata from]
    set jid2 [jlib::barejid $jid]
    
    if {[::Chat::HaveChat $jid]} {
	return
    }
    set title "Message From: $jid2"
    
    # Not sure if only new subjects should be added.
    # If we've got a threadid we can always geta a handle on to
    # the internal chat state with:
    # 	set chattoken [::Chat::GetTokenFrom chat threadid $threadID]
    # 	parray chattoken

    if {[info exists argsA(-subject)]} {
	append title "\n$argsA(-subject)"
    }
    growl post newMessage $title $body $cociFile
}

proc ::Growl::PresenceHook {jid type args} {
    variable cociFile
    
    # Notify only if in background.
    if {![::UI::IsAppInFront]} {
	
	if {[::Roster::IsTransportHeuristics $jid]} {
	    return
	}
	
	# If we have a 'delay' this is presence sent when we login.
	set delay [::Jabber::RosterCmd getx $jid "jabber:x:delay"]
	if {$delay ne ""} {
	    return
	}
	array set argsA $args
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
	if {[::Jabber::JlibCmd service isroom $jid]} {
	    if {[info exists argsA(-from)]} {
		set djid $argsA(-from)
	    } 
	}

	set title "$djid $show"
	set msg "$djid $showMsg"
	if {$status ne ""} {
	    append msg "\n$status"
	}
	growl post changeStatus $title $msg $cociFile
    }
}

proc ::Growl::FileTransferRecvHook {jid name size} {
    variable cociFile
    
    if {![::UI::IsAppInFront]} {
	set title [mc {Get File}]
	set str "[mc Size]: [::Utils::FormatBytes $size]"
	set msg [mc jamessoobask $jid $name $str]
	growl post fileTransfer $title $msg $cociFile
    }
}

proc ::Growl::JivePhoneEventHook {type cid callID args} {
    variable cociFile
    
    if {$type eq "RING"} {
	set title [mc phoneRing]
	set msg [mc phoneRingFrom $cid]
	growl post phoneRings $title $msg $cociFile
    }
}

proc ::Growl::MoodEventHook {xmldata mood text} {
    variable cociFile

    set title [mc moodEvent]
    set from [wrapper::getattribute $xmldata from]
    if {$mood ne ""} {
	set msg "$from [mc heIs] [mc $mood]"
	if {$text ne ""} {
	    append msg " " [mc because] " " $text
	}
    } else {
	set msg "$from [mc moodRetracted]"
    }
    growl post moodEvent $title $msg $cociFile
} 

#-------------------------------------------------------------------------------

