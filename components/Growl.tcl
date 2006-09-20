# Growl.tcl --
# 
#       Growl notifier bindings for MacOSX.
#       This is just a first sketch.
#       
# $Id: Growl.tcl,v 1.14 2006-09-20 14:12:38 matben Exp $

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
    ::hooks::register newChatMessageHook  ::Growl::ChatMessageHook
    ::hooks::register presenceNewHook     ::Growl::PresenceHook
    ::hooks::register jivePhoneEvent      ::Growl::JivePhoneEventHook
    ::hooks::register fileTransferReceiveHook  ::Growl::FileTransferRecvHook
    ::hooks::register moodEvent           ::Growl::MoodEventHook

}

proc ::Growl::ChatMessageHook {body args} {    
    variable cociFile
    
    if {$body eq ""} {
	return
    }
    array set argsA $args

    # -from is a 3-tier jid /resource included.
    set jid $argsA(-from)
    jlib::splitjid $jid jid2 -
    
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
	set djid $jid
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
    set msg "$from [mc heIs] [mc $mood]"
    if {$text ne ""} {
        append msg " " [mc because] $text
    }

    growl post moodEvent $title $msg $cociFile
} 
#-------------------------------------------------------------------------------

