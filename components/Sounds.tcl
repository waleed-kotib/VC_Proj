#  Sounds.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements alert sounds.
#      
#  Copyright (c) 2002-2004  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Sounds.tcl,v 1.4 2004-10-30 14:44:52 matben Exp $

namespace eval ::Sounds:: {
        
    variable nameToText 
    array set nameToText {
	online          {User is online}
	offline         {User is offline}
	newmsg          {New incoming message}
	newchatmsg      {New chat message}
	newchatthread   {New chat thread}
	statchange      {User's status changed}
	connected       {Is connected}
    }

    # Map between sound name and file name for default sound set.
    variable soundIndex
    array set soundIndex {
	online          online.wav
	offline         offline.wav
	newmsg          newmsg.wav
	newchatmsg      newchatmsg.wav
	newchatthread   newchatthread.wav
	statchange      statchange.wav
	connected       connected.wav
    }

    variable allSounds
    set allSounds [array names soundIndex]
}

# Sounds::Load --
# 
#       Tries to load the sounds component.

proc ::Sounds::Load { } {
    global  this
    variable priv
    
    ::Debug 2 "::Sounds::Load"

    set priv(canPlay)      0
    set priv(QuickTimeTcl) 0
    set priv(snack)        0

    switch -- $this(platform) {
	macosx - macintosh - windows {
	    if {[catch {package require QuickTimeTcl}]} {
		return
	    }
	    set priv(QuickTimeTcl) 1
	}
	default {
	    if {[catch {package require snack}]} {
		return
	    }
	    set priv(snack) 1
	}
    }    
    set priv(canPlay) 1
   
    # We should register ourselves.
    component::register Sounds "Provides alert sounds through QuickTimeTcl\
      or the Snack audio package."

    # Make sure we get called when certain events happen.
    ::Sounds::InitEventHooks
}

proc ::Sounds::InitEventHooks { } {
    
    # Add all event hooks.
    ::hooks::register quitAppHook             ::Sounds::Free 80
    ::hooks::register newMessageHook          [list ::Sounds::Msg normal newmsg]
    ::hooks::register newChatMessageHook      [list ::Sounds::Msg chat newchatmsg]
    ::hooks::register newGroupChatMessageHook [list ::Sounds::Msg groupchat newmsg]
    ::hooks::register newChatThreadHook       [list ::Sounds::Event newchatthread]
    ::hooks::register loginHook               [list ::Sounds::Event connected]
    ::hooks::register presenceHook            ::Sounds::Presence

    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          ::Sounds::InitPrefsHook
    ::hooks::register prefsBuildHook         ::Sounds::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::Sounds::SavePrefsHook
    ::hooks::register prefsCancelHook        ::Sounds::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::Sounds::UserDefaultsHook

    ::hooks::register launchFinalHook        ::Sounds::InitHook
}

proc ::Sounds::InitHook { } {
    
    ::Debug 2 "::Sounds::InitHook"
    
    after 200 ::Sounds::Init
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
    global  this    
    variable allSounds
    variable priv
    variable sprefs
        
    ::Debug 2 "::Sounds::Init"
    
    # Create all sounds from current sound set (which is "" as default).
    if {$priv(canPlay)} {
	
	# Verify that sound set exists.
	if {[lsearch -exact [::Sounds::GetAllSets] $sprefs(soundSet)] < 0} {
	    set sprefs(soundSet) ""
	}
	::Sounds::LoadSoundSet $sprefs(soundSet)
    }
}

proc ::Sounds::LoadSoundSet {soundSet} {
    global  this
    variable allSounds
    variable soundIndex
    variable priv

    ::Debug 2 "::Sounds::LoadSoundSet: soundSet=$soundSet"
    ::Sounds::Free
        
    array set sound [array get soundIndex]
    
    # Search for given sound set.
    if {$soundSet == ""} {
	set path $this(soundsPath)
    } else {
	set path [file join $this(soundsPath) $soundSet]
	set indFile [file join $path soundIndex.tcl]
	if {[file exists $indFile]} {
	    source $indFile
	} else {
	    set path [file join $this(altSoundsPath) $soundSet]
	    set indFile [file join $path soundIndex.tcl]
	    if {[file exists $indFile]} {
		source $indFile
	    } else {
		
		# Fallback.
		set path $this(soundsPath)
	    }
	}
    }
    if {$priv(QuickTimeTcl)} {
	frame .fake
    }
    foreach s $allSounds {
	::Sounds::Create $s [file join $path $sound($s)]
    }
}

proc ::Sounds::Create {name path} {
    global  this    
    variable priv
    
    # QuickTime doesn't understand vfs; need to copy out to tmp dir.
    if {$priv(QuickTimeTcl) && [namespace exists ::vfs]} {
	set tmp [file join $this(tmpPath) [file tail $path]]
	file copy -force $path $tmp
	set path $tmp
    }
    if {$priv(QuickTimeTcl)} {
	if {[catch {
	    movie .fake.$name -file $path -controller 0
	}]} {
	    # ?
	}
    } elseif {$priv(snack)} {
	if {[catch {
	    snack::sound $name -load $path
	}]} {
	    # ?
	}
    }
}

proc ::Sounds::Play {snd} {
    variable sprefs
    variable priv
    variable afterid

    # Check the jabber prefs if sound should be played.
    if {[info exists sprefs($snd)] && !$sprefs($snd)} {
	return
    }
    unset -nocomplain afterid($snd)
    if {$priv(QuickTimeTcl)} {
	if {[catch {.fake.${snd} play}]} {
	    # ?
	}
    } elseif {$priv(snack)} {
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

proc ::Sounds::PlaySoundTmp {path} {
    global  this
    variable priv
    
    if {$priv(QuickTimeTcl)} {
	if {[namespace exists ::vfs]} {
	    set tmp [file join $this(tmpPath) [file tail $path]]
	    file copy -force $path $tmp
	    set path $tmp
	}
	catch {destroy .fake._tmp}
	catch {
	    movie .fake._tmp -file $path -controller 0
	    .fake._tmp play
	}
    } elseif {$priv(snack)} {
	catch {_tmp destroy}
	catch {snack::sound _tmp -load $path}
	catch {_tmp play}
    }
}

proc ::Sounds::Msg {type snd body args} {
    
    array set argsArr $args
    
    # We sometimes get non text stuff messages, like jabber:x:event etc.
    if {[string length $body] == 0} {
	return
    }
    set from ""
    if {[info exists argsArr(-from)]} {
	set from $argsArr(-from)
    }
    
    # We shouldn't make noise for our own messages.
    switch -- $type {
	normal {

	}
	chat {
	    set myjid [::Jabber::GetMyJid]
	    jlib::splitjid $myjid jid2 res
	    if {[string match ${jid2}* $from]} {
		return
	    }
	}
	groupchat {
	    jlib::splitjid $from roomjid res
	    set myjid [::Jabber::GetMyJid $roomjid]
	    if {[string equal $myjid $from]} {
		return
	    }
	}
    }

    ::Sounds::PlayWhenIdle $snd
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
    variable priv
    variable allSounds
    
    if {$priv(QuickTimeTcl)} {
	catch {destroy .fake}
    } elseif {$priv(snack)} {
	foreach name $allSounds {
	    catch {$name destroy}
	}
    }
}

# Preference page --------------------------------------------------------------

proc  ::Sounds::InitPrefsHook { } {
    variable sprefs
    variable allSounds
    
    set sprefs(soundSet) ""
    ::PreferencesUtils::Add [list  \
      [list ::Sounds::sprefs(soundSet) sound_set $sprefs(soundSet)]]
    
    set optList {}
    foreach name $allSounds {
	set sprefs($name) 1
	lappend optList [list ::Sounds::sprefs($name) sound_${name} $sprefs($name)]
    }
    ::PreferencesUtils::Add $optList    
}

proc ::Sounds::BuildPrefsHook {wtree nbframe} {
    variable priv
    
    if {$priv(canPlay)} {
	$wtree newitem {General Sounds}  \
	  -text [mc {Sounds}]

	set wpage [$nbframe page {Sounds}]    
	::Sounds::BuildPrefsPage $wpage
    }
}

proc ::Sounds::BuildPrefsPage {wpage} {
    variable nameToText 
    variable sprefs
    variable tmpPrefs
    variable allSounds
    
    set fontS  [option get . fontSmall {}]    
    set fontSB [option get . fontSmallBold {}]    

    foreach name $allSounds {
	set tmpPrefs($name) $sprefs($name)
    }
    if {[string equal $sprefs(soundSet) ""]} {
	set tmpPrefs(soundSet) [mc Default]
    } else {
	set tmpPrefs(soundSet) $sprefs(soundSet)
    }
    
    set labpalrt $wpage.alrt
    labelframe $labpalrt -text [mc {Alert sounds}]
    pack $labpalrt -side top -anchor w -padx 8 -pady 4
    
    set frs $labpalrt.frs
    pack [frame $frs] -side top -anchor w -padx 8 -pady 2
    
    set soundSets [concat [list [mc Default]] [::Sounds::GetAllSets]]
    label $frs.lsets -text "[mc {Sound Set}]:"
    set wpopsets $frs.popsets
    set wpopupmenu [eval {tk_optionMenu $wpopsets   \
      [namespace current]::tmpPrefs(soundSet)} $soundSets]
    $wpopsets configure -highlightthickness 0 -font $fontSB
    grid $frs.lsets $wpopsets -sticky w
    
    set fr $labpalrt.fr
    pack [frame $fr] -side left
    label $fr.lbl -text [mc prefsounpick]
    grid $fr.lbl -columnspan 2 -sticky w -padx 10

    set row 1
    foreach name $allSounds {
	set txt $nameToText($name)
	checkbutton $fr.$name -text "  [mc $txt]"  \
	  -variable [namespace current]::tmpPrefs($name)
	button $fr.b${name} -text [mc Play] \
	  -font $fontS \
	  -command [list [namespace current]::PlayTmpPrefSound $name]
	grid $fr.$name    -column 0 -row $row -sticky w  -padx 8
	grid $fr.b${name} -column 1 -row $row -sticky ew -padx 8
	incr row
    }
    scale $fr.vol -showvalue 1 -command [namespace current]::VolumeCmd \
      -from 0 -to 100 -label [mc Volume] -orient horizontal -bd 1
    grid $fr.vol
    
}

proc ::Sounds::VolumeCmd {volume} {
    
 
    
}

proc ::Sounds::PlayTmpPrefSound {name} {
    global  this
    variable priv
    variable soundIndex
    variable tmpPrefs
    
    array set sound [array get soundIndex]
    
    if {[string equal $tmpPrefs(soundSet) [mc Default]]} {
	set path $this(soundsPath)
    } else {
	set path [file join $this(soundsPath) $tmpPrefs(soundSet)]
	set indFile [file join $path soundIndex.tcl]
	if {[file exists $indFile]} {
	    source $indFile
	} else {
	    set path [file join $this(altSoundsPath) $tmpPrefs(soundSet)]
	    set indFile [file join $path soundIndex.tcl]
	    if {[file exists $indFile]} {
		source $indFile
	    } else {
		
		# Fallback.
		set path $this(soundsPath)
	    }
	}
    }
    set f [file join $path $sound($name)]

    if {$priv(QuickTimeTcl)} {
	if {[namespace exists ::vfs]} {
	    set tmp [file join $this(tmpPath) [file tail $f]]
	    file copy -force $f $tmp
	    set f $tmp
	}
	catch {destroy .fake._tmp}
	catch {
	    movie .fake._tmp -file $f -controller 0
	    .fake._tmp play
	}
    } elseif {$priv(snack)} {
	catch {_tmp destroy}
	catch {snack::sound _tmp -load $f}
	catch {_tmp play}
    }
}

proc ::Sounds::SavePrefsHook { } {
    variable sprefs
    variable tmpPrefs
    variable allSounds
    variable priv
    
    if {!$priv(canPlay)} {
	return
    }
    if {[string equal $tmpPrefs(soundSet) [mc Default]]} {
	set tmpPrefs(soundSet) ""
    }
    if {![string equal $tmpPrefs(soundSet) $sprefs(soundSet)]} {
	::Sounds::LoadSoundSet $tmpPrefs(soundSet)
    }
    set sprefs(soundSet) $tmpPrefs(soundSet)
    foreach name $allSounds {
	set sprefs($name) $tmpPrefs($name)
    }
}

proc ::Sounds::CancelPrefsHook { } {
    variable sprefs
    variable tmpPrefs
    variable allSounds
    variable priv
    
    if {!$priv(canPlay)} {
	return
    }    
    foreach name $allSounds {
	if {$sprefs($name) != $tmpPrefs($name)} {
	    ::Preferences::HasChanged
	}
    }
    if {[string equal $tmpPrefs(soundSet) [mc Default]]} {
	set tmpPrefs(soundSet) ""
    }
    if {![string equal $sprefs(soundSet) $tmpPrefs(soundSet)]} {
	::Preferences::HasChanged
    }
}

proc ::Sounds::UserDefaultsHook { } {
    variable sprefs
    variable tmpPrefs
    variable allSounds

    foreach name $allSounds {
	set tmpPrefs($name) $sprefs($name)
    }
    if {[string equal $sprefs(soundSet) ""]} {
	set tmpPrefs(soundSet) [mc Default]
    } else {
	set tmpPrefs(soundSet) $sprefs(soundSet)
    }
}

proc ::Sounds::GetAllSets { } {
    global  this
    
    set allsets {}
    foreach f [glob -nocomplain -directory $this(soundsPath) *] {
	if {[file isdirectory $f]  \
	  && [file exists [file join $f soundIndex.tcl]]} {
	    lappend allsets [file tail $f]
	}
    }  
    
    # Alternative additional sounds directory.
    foreach f [glob -nocomplain -directory $this(altSoundsPath) *] {
	if {[file isdirectory $f]  \
	  && [file exists [file join $f soundIndex.tcl]]} {
	    lappend allsets [file tail $f]
	}
    }  
    return $allsets
}

proc ::Sounds::SetVolume {volume} {
    
    
    
    
}

#-------------------------------------------------------------------------------
