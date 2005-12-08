# Growl.tcl --
# 
#       Growl notifier bindings for MacOSX.
#       This is just a first sketch.
#       
# $Id: Growl.tcl,v 1.8 2005-12-08 09:32:20 matben Exp $

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
    
    growl register Coccinella "newMessage changeStatus phoneRings" $cociFile
    
    # Add event hooks.
    ::hooks::register newChatMessageHook  ::Growl::ChatMessageHook
    ::hooks::register presenceHook        ::Growl::PresenceHook
    ::hooks::register jivePhoneEvent      ::Growl::JivePhoneEventHook
}

proc ::Growl::ChatMessageHook {body args} {    
    variable cociFile
    
    if {$body eq ""} {
	return
    }
    array set argsArr $args

    # -from is a 3-tier jid /resource included.
    set jid $argsArr(-from)
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

    if {[info exists argsArr(-subject)]} {
	append title "\n$argsArr(-subject)"
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
	array set argsArr $args
	set show $type
	if {[info exists argsArr(-show)]} {
	    set show $argsArr(-show)
	}
	set status ""
	if {[info exists argsArr(-status)]} {
	    set status $argsArr(-status)
	}
	
	# This just translates the show code into a readable text.
	set showMsg [::Roster::MapShowToText $show]
	set title "$jid $show"
	set msg "$jid $showMsg"
	if {$status ne ""} {
	    append msg "\n$status"
	}
	growl post changeStatus $title $msg $cociFile
    }
}

proc ::Growl::JivePhoneEventHook {type cid args} {
    variable cociFile
    
    if {$type eq "RING"} {
	set title [mc phoneRing]
	set msg [mc phoneRingFrom $cid]
	growl post phoneRings $title $msg $cociFile
    }
}

#-------------------------------------------------------------------------------

