#  Sounds.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements alert sounds.
#      
#  Copyright (c) 2002-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Sounds.tcl,v 1.11 2004-01-16 15:01:10 matben Exp $

package provide Sounds 1.0

namespace eval ::Sounds:: {
    
    # Add all event hooks.
    ::hooks::add quitAppHook             ::Sounds::Free 80
    ::hooks::add newMessageHook          [list ::Sounds::Msg normal newmsg]
    ::hooks::add newChatMessageHook      [list ::Sounds::Msg chat newmsg]
    ::hooks::add newGroupChatMessageHook [list ::Sounds::Msg groupchat newmsg]
    ::hooks::add loginHook               [list ::Sounds::Event connected]
    ::hooks::add presenceHook            ::Sounds::Presence

    # Define all hooks for preference settings.
    ::hooks::add prefsInitHook          ::Sounds::InitPrefsHook
    ::hooks::add prefsBuildHook         ::Sounds::BuildPrefsHook
    ::hooks::add prefsSaveHook          ::Sounds::SavePrefsHook
    ::hooks::add prefsCancelHook        ::Sounds::CancelPrefsHook

    ::hooks::add initHook               ::Sounds::InitHook
    
    variable nameToText 
    array set nameToText {
	online          {User is online}
	offline         {User is offline}
	newmsg          {New incoming message}
	statchange      {User's status changed}
	connected       {Is connected}
    }

    # Map between sound name and file name for default sound set.
    variable soundIndex
    array set soundIndex {
	online      online.wav
	offline     offline.wav
	newmsg      newmsg.wav
	statchange  statchange.wav
	connected   connected.wav
    }

    variable allSounds
    variable allSoundFiles
    set allSounds [array names soundIndex]
}

proc ::Sounds::InitHook { } {
    
    after 600 ::Sounds::Init
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
    variable allSoundFiles
    variable priv
    variable sprefs
    
    set suff wav
    set allSoundFiles {}
    
    set priv(canPlay)      0
    set priv(QuickTimeTcl) [::Plugins::HavePackage QuickTimeTcl]
    set priv(snack)        [::Plugins::HavePackage snack]
    if {$priv(QuickTimeTcl) || $priv(snack)} {
	set priv(canPlay) 1
    }
    
    foreach s $allSounds {
	if {$::privariaFlag} {
	    set soundFileArr($s) [file join c:/ PRIVARIA media ${s}.${suff}]
	} else {
	    set soundFileArr($s) [file join $this(soundsPath) ${s}.${suff}]
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

    # Never map this frame!
    frame .fake
    foreach f $allSoundFiles s $allSounds {
	::Sounds::Create $s $f
    }
}


proc ::Sounds::Create {name path} {
    variable priv
    variable allSounds
    variable allSoundFiles
    
    if {$priv(QuickTimeTcl)} {
	if {[catch {
	    movie .fake.$s -file $path -controller 0
	}]} {
	    # ?
	}
    } elseif {$priv(snack)} {
	if {[catch {
	    snack::sound $s -load $path
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
    if {!$sprefs($snd)} {
	return
    }
    catch {unset afterid($snd)}
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

proc ::Sounds::Msg {type snd body args} {
    
    array set argsArr $args
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
    
    if {[::Plugins::HavePackage QuickTimeTcl]} {
	catch {destroy .fake}
    }
}

# Preference page --------------------------------------------------------------

proc  ::Sounds::InitPrefsHook { } {
    variable sprefs
    variable allSounds
    
    set sprefs(soundSet) ""
    ::PreferencesUtils::Add  \
      [list ::Sounds::sprefs(soundSet) sound_set $sprefs(soundSet)]
    
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
	  -text [::msgcat::mc {Sounds}]

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
	set tmpPrefs(soundSet) [::msgcat::mc Default]
    }
    
    set labpalrt [::mylabelframe::mylabelframe $wpage.alrt [::msgcat::mc {Alert sounds}]]
    pack $wpage.alrt -side top -anchor w -ipadx 10 -fill x
    
    set frs $labpalrt.frs
    pack [frame $frs] -side top -anchor w -padx 8 -pady 2
    
    set soundSets [concat [list [::msgcat::mc Default]] [::Sounds::GetAllSets]]
    label $frs.lsets -text "[::msgcat::mc {Sound Set}]:"
    set wpopsets $frs.popsets
    set wpopupmenu [eval {tk_optionMenu $wpopsets   \
      [namespace current]::tmpPrefs(soundSet)} $soundSets]
    $wpopsets configure -highlightthickness 0 -font $fontSB
    grid $frs.lsets $wpopsets -sticky w

    
    set fr $labpalrt.fr
    pack [frame $fr] -side left
    label $fr.lbl -text [::msgcat::mc prefsounpick]
    grid $fr.lbl -columnspan 2 -sticky w -padx 10

    set row 1
    foreach name {online offline newmsg statchange connected} {
	set txt $nameToText($name)
	checkbutton $fr.$name -text "  [::msgcat::mc $txt]"  \
	  -variable [namespace current]::tmpPrefs($name)
	button $fr.b${name}   -text [::msgcat::mc Play] -font $fontS \
	  -command [list [namespace current]::PlayPrefSound $name]
	grid $fr.$name    -column 0 -padx 8 -row $row -sticky w
	grid $fr.b${name} -column 1 -padx 8 -row $row -sticky ew 
	incr row
    }
}

proc ::Sounds::PlayPrefSound {name} {
    global  this
    variable priv
    variable soundIndex
    variable tmpPrefs
    
    array set sound [array get soundIndex]
    
    if {[string equal $tmpPrefs(soundSet) [::msgcat::mc Default]]} {
	set path $this(soundsPath)
    } else {
	set path [file join $this(soundsPath) $tmpPrefs(soundSet)]
	source [file join $path soundIndex.tcl]
    }
    set f [file join $path $sound($name)]
    
    if {$priv(QuickTimeTcl)} {
	catch {destroy .fake._tmp}
	catch {
	    movie .fake._tmp -file $f -controller 0
	    .fake._tmp play
	}
    } elseif {$priv(snack)} {
	catch {_tmp destroy}
	catch {snack::sound _tmp -load $f}
    }
}

proc ::Sounds::SavePrefsHook { } {
    variable sprefs
    variable tmpPrefs
    variable allSounds
    
    foreach name $allSounds {
	set sprefs($name) $tmpPrefs($name)
    }
    if {[string equal $tmpPrefs(soundSet) [::msgcat::mc Default]]} {
	set sprefs(soundSet) ""
    }
}

proc ::Sounds::CancelPrefsHook { } {
    variable sprefs
    variable tmpPrefs
    variable allSounds
    
    foreach name $allSounds {
	if {$sprefs($name) != $tmpPrefs($name)} {
	    ::Preferences::HasChanged
	}
    }
    if {![string equal $sprefs(soundSet) $tmpPrefs(soundSet)]} {
	::Preferences::HasChanged
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
    return $allsets
}

proc ::Sounds::LoadSoundSet {setName} {

    
    
}

#-------------------------------------------------------------------------------
