#  Sounds.tcl ---
#  
#      This file is part of the whiteboard application. 
#      It implements alert sounds.
#      
#  Copyright (c) 2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Sounds.tcl,v 1.1.1.1 2002-12-08 11:04:28 matben Exp $

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
    if {$prefs(QuickTimeTcl)} {
	
	# Should never be mapped.
	frame .fake
	foreach f $allSoundFiles m $allSounds {
	    movie .fake.$m -file $f -controller 0
	}
    } elseif {$prefs(snack)} {
	foreach f $allSoundFiles m $allSounds {
	    snack::sound $m -load $f
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
    if {$prefs(QuickTimeTcl)} {
	.fake.${snd} play
    } elseif {$prefs(snack)} {
	$snd play
    }
}

#-------------------------------------------------------------------------------
