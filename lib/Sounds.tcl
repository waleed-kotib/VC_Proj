#  Sounds.tcl ---
#  
#      This file is part of the whiteboard application. 
#      It implements alert sounds.
#      
#  Copyright (c) 2002-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Sounds.tcl,v 1.5 2003-08-30 09:41:00 matben Exp $

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
	    set tmp [file join $this(tmpDir) ${s}.${suff}]
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

proc ::Sounds::Free { } {
    
    if {[::Plugins::HavePackage QuickTimeTcl]} {
	catch {destroy .fake}
    }
}

#-------------------------------------------------------------------------------
