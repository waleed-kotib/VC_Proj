#  Sounds.tcl ---
#  
#      This file is part of the whiteboard application. 
#      It implements alert sounds.
#      
#  Copyright (c) 2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Sounds.tcl,v 1.4 2003-07-26 13:54:23 matben Exp $

package provide Sounds 1.0

namespace eval ::Sounds:: {
    
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
    
    foreach f $allSounds {
	if {$::privariaFlag} {
	    lappend allSoundFiles [file join c:/ PRIVARIA media]
	} else {
	    lappend allSoundFiles [file join $this(path) sounds ${f}.${suff}]
	}
    }
    if {[::Plugins::HavePackage QuickTimeTcl]} {
	
	# Should never be mapped.
	frame .fake
	if {[catch {
	    foreach f $allSoundFiles m $allSounds {
		movie .fake.$m -file $f -controller 0
	    }
	}]} {
	    # ?
	}
    } elseif {[::Plugins::HavePackage snack]} {
	if {[catch {
	    foreach f $allSoundFiles m $allSounds {
		snack::sound $m -load $f
	    }
	}]} {
	    # ?
	}
    }
}

proc ::Sounds::Play {snd} {
    global  prefs

    upvar ::Jabber::jprefs jprefs

    # Check the jabber prefs if sound should be played.
    if {!$jprefs(snd,$snd)} {
	return
    }
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

#-------------------------------------------------------------------------------
