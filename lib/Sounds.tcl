#  Sounds.tcl ---
#  
#      This file is part of the whiteboard application. 
#      It implements alert sounds.
#      
#  Copyright (c) 2002-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Sounds.tcl,v 1.8 2003-12-23 14:41:01 matben Exp $

package provide Sounds 1.0

namespace eval ::Sounds:: {
    
    # Add all event hooks.
    hooks::add quitAppHook ::Sounds::Free 80
    hooks::add newMessageHook          [list ::Sounds::Event newmsg]
    hooks::add newChatMessageHook      [list ::Sounds::Event newmsg]
    hooks::add newGroupChatMessageHook [list ::Sounds::Event newmsg]
    hooks::add loginHook               [list ::Sounds::Event connected]
    hooks::add presenceHook            ::Sounds::Presence
    
    variable allSounds
    variable allSoundFiles

    set allSounds {online offline newmsg statchange connected}
}

# Sounds::Init --
#
#       Make all the necessary initializations, create audio objects.
#       
# Arguments:
#       
# Results:
#       none.

proc ::Sounds::Init { } {
    global  prefs this    
    variable allSounds
    variable allSoundFiles
    
    set suff wav
    set allSoundFiles {}
    
    foreach s $allSounds {
	if {$::privariaFlag} {
	    set soundFileArr($s) [file join c:/ PRIVARIA media ${s}.${suff}]
	} else {
	    set soundFileArr($s) [file join $this(path) sounds ${s}.${suff}]
	}
	lappend allSoundFiles $soundFileArr($s)
    }
    
    # QuickTime doesn't understand vfs; need to copy out to tmp dir.
    if {[namespace exists ::vfs]} {
	set allSoundFiles {}
	foreach s $allSounds {
	    set tmp [file join $this(tmpPath) ${s}.${suff}]
	    file copy -force $soundFileArr($s) $tmp
	    lappend allSoundFiles $tmp
	}	
    }

    if {[::Plugins::HavePackage QuickTimeTcl]} {
	
	# Should never be mapped.
	frame .fake
	if {[catch {
	    foreach f $allSoundFiles s $allSounds {
		movie .fake.$s -file $f -controller 0
	    }
	}]} {
	    # ?
	}
    } elseif {[::Plugins::HavePackage snack]} {
	if {[catch {
	    foreach f $allSoundFiles s $allSounds {
		snack::sound $s -load $f
	    }
	}]} {
	    # ?
	}
    }
}

proc ::Sounds::Play {snd} {
    global  prefs
    upvar ::Jabber::jprefs jprefs
    variable afterid

    # Check the jabber prefs if sound should be played.
    if {!$jprefs(snd,$snd)} {
	return
    }
    catch {unset afterid($snd)}
    if {[::Plugins::HavePackage QuickTimeTcl]} {
	if {[catch {.fake.${snd} play}]} {
	    # ?
	}
    } elseif {[::Plugins::HavePackage snack]} {
	if {[catch {$snd play}]} {
	    # ?
	}
    }
}

proc ::Sounds::PlayWhenIdle {snd} {
    variable afterid
        
    if {![info exists afterid($snd)]} {
	set afterid($snd) 1
	after idle [list ::Sounds::Play $snd]
    }    
}

proc ::Sounds::Event {snd args} {
    
    ::Sounds::PlayWhenIdle $snd
}

# Sounds::Presence --
#
#       Makes an alert sound corresponding to the jid's presence status.
#
# Arguments:
#       jid  
#       presence    "available", "unavailable", or "unsubscribed"
#       args        list of '-key value' pairs of presence attributes.
#       
# Results:
#       roster tree updated.

proc ::Sounds::Presence {jid presence args} {
    
    array set argsArr $args
    
    # Alert sounds.
    if {[info exists argsArr(-show)] && [string equal $argsArr(-show) "chat"]} {
	::Sounds::PlayWhenIdle statchange
    } elseif {[string equal $presence "available"]} {
	::Sounds::PlayWhenIdle online
    } elseif {[string equal $presence "unavailable"]} {
	::Sounds::PlayWhenIdle offline
    }    
}


proc ::Sounds::Free { } {
    
    if {[::Plugins::HavePackage QuickTimeTcl]} {
	catch {destroy .fake}
    }
}

#-------------------------------------------------------------------------------
