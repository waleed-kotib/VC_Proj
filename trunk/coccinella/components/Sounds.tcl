#  Sounds.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements alert sounds.
#      
#  Copyright (c) 2002-2008  Mats Bengtsson
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
# $Id: Sounds.tcl,v 1.48 2008-05-30 07:25:04 matben Exp $

namespace eval ::Sounds {
	    
    # We undefine ourselves if we have no audio support.
    component::define Sounds \
      "Provides alert sounds through QuickTime or the Snack audio package."
}

proc ::Sounds::Init {} {

    # We are doing all inits late since loading audio can be slow.
    ::hooks::register afterFinalHook ::Sounds::AfterFinalHook
}

# Sounds::AfterFinalHook --
# 
#       Tries to load the sounds component.

proc ::Sounds::AfterFinalHook {} {
    variable priv
    
    ::Debug 2 "::Sounds::AfterFinalHook"
    
    set priv(canPlay)      0
    set priv(inited)       0
    set priv(QuickTimeTcl) [expr ![catch {package require QuickTimeTcl}]]
    set priv(snack)        [expr ![catch {package require snack}]]

    # Skip if both 0.
    if {!$priv(QuickTimeTcl) && !$priv(snack)} {
	component::undefine Sounds
	return
    }
    set priv(canPlay) 1
    Mappings
    
    # This one is needed since we have missed it during the launch process.
    InitPrefsHook
   
    # We should register ourselves.
    component::register Sounds

    # Make sure we get called when certain events happen.
    InitEventHooks
    InitHook
}

proc ::Sounds::Mappings {} {
    
    ::Debug 2 "::Sounds::Mappings"
    
    variable nameToText 
    set nameToText [dict create]
	# TRANSLATORS; Sound settings in preferences
	dict set nameToText online          [mc "Contact is online"]
	dict set nameToText offline         [mc "Contact is offline"]
	dict set nameToText newmsg          [mc "Incoming message"]
	dict set nameToText newchatmsg      [mc "Incoming chat"]
	dict set nameToText newchatthread   [mc "New chat thread"]
	dict set nameToText statchange      [mc "Contact presence change"]
	dict set nameToText connected       [mc "Logged in"]
	dict set nameToText groupchatpres   [mc "Chatroom presence change"]

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
	groupchatpres   clicked.wav
    }
    
    variable wqtframe .quicktime::audio

    variable allSounds
    set allSounds [array names soundIndex]
}

proc ::Sounds::GetTextForName {name} {
    variable nameToText 
    return [dict get $nameToText $name]
}

proc  ::Sounds::InitPrefsHook {} {
    global prefs
    variable sprefs
    variable allSounds
    variable priv
    
    set names [::Theme::GetAllWithFilter sound]
    if {$prefs(rootTheme) in $names} {
	set defaultSet $prefs(rootTheme)
    } else {
	set defaultSet [lindex $names 0]
    }
    set priv(defaultSet) $defaultSet
    
    set sprefs(soundSet) $defaultSet
    set sprefs(volume)   100
    set sprefs(midiCmd)  ""
    set sprefs(outputDevice)  ""

    ::PrefUtils::Add [list  \
      [list ::Sounds::sprefs(soundSet) sound_set     $sprefs(soundSet)] \
      [list ::Sounds::sprefs(volume)   sound_volume  $sprefs(volume)]   \
      [list ::Sounds::sprefs(midiCmd)  sound_midiCmd $sprefs(midiCmd)]  \
      [list ::Sounds::sprefs(outputDevice)  sound_outputDevice $sprefs(outputDevice)]  \
      ]
    
    set optL [list]
    foreach name $allSounds {
	set sprefs($name) 1
	lappend optL [list ::Sounds::sprefs($name) sound_${name} $sprefs($name)]
    }
    ::PrefUtils::Add $optL
    
    if {$priv(snack)} {
       # Volume seems to be set globally on snack.
	set sprefs(volume) [snack::audio play_gain]
	# initialize snack audio device
        if {![string equal $sprefs(outputDevice) ""]} {
            snack::audio selectOutput $sprefs(outputDevice)
	}
    }
}

proc ::Sounds::InitEventHooks {} {
    
    # Add all event hooks.
    ::hooks::register quitAppHook             ::Sounds::Free 80
    ::hooks::register newMessageHook          [list ::Sounds::Msg normal newmsg]
    ::hooks::register newChatMessageHook      [list ::Sounds::Msg chat newchatmsg]
    ::hooks::register newGroupChatMessageHook [list ::Sounds::Msg groupchat newchatmsg]
    ::hooks::register newChatThreadHook       [list ::Sounds::Event newchatthread]
    ::hooks::register loginHook               [list ::Sounds::Event connected]
    ::hooks::register presenceNewHook         ::Sounds::Presence

    # Define all hooks for preference settings.
    ::hooks::register prefsBuildHook         ::Sounds::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::Sounds::SavePrefsHook
    ::hooks::register prefsCancelHook        ::Sounds::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::Sounds::UserDefaultsHook
}

# Sounds::InitHook --
#
#       Make all the necessary initializations, create audio objects.
#       
# Arguments:
#       
# Results:
#       none.

proc ::Sounds::InitHook {} {
    global  this    
    variable allSounds
    variable priv
    variable sprefs
	
    ::Debug 2 "::Sounds::InitHook"

    if {$priv(inited)} {
	return
    }
    
    # Create all sounds from current sound set (which is "" as default).
    if {$priv(canPlay)} {
	
	# Verify that sound set exists.
	if {$sprefs(soundSet) in [GetAllSets]} {
	    set sprefs(soundSet) $priv(defaultSet)
	}
	LoadSoundSet $sprefs(soundSet)
    }
    set priv(inited) 1
}

proc ::Sounds::GetAllSets {} {
    set names [list]
    foreach path [GetAllSoundSetPaths] {
	lappend names [lindex [file split $path] end-1]
    }
    return $names
}

proc ::Sounds::GetAllSoundSetPaths {} {
    
    set soundPaths [list]
    set paths [::Theme::GetAllPathsWithFilter sound]
    foreach path $paths {
	foreach dir [glob -nocomplain -types d -directory $path *] {
	    set indFile [file join $dir soundIndex.tcl]
	    if {[file exists $indFile]} {
		lappend soundPaths $dir
	    }
	}
    }
    return $soundPaths
}

proc ::Sounds::GetAllSoundsPresentSet {} {
    variable allSounds
    return $allSounds
}

proc ::Sounds::LoadSoundSet {soundSet} {
    global  this
    variable allSounds
    variable soundIndex
    variable priv
    variable wqtframe

    ::Debug 2 "::Sounds::LoadSoundSet: soundSet=$soundSet"
    
    Free
    unset -nocomplain nameToPath	
    array set sound [array get soundIndex]
    if {$soundSet ni [GetAllSets]} {
	return
    }
    if {$priv(QuickTimeTcl)} {
	frame $wqtframe
    }
    set dir [GetPathForSet $soundSet]
    foreach s $allSounds {
	Create $s [file join $dir $sound($s)]
    }
}

proc ::Sounds::GetPathForSet {soundSet} {
    global this
    return [file join [::Theme::GetPath $soundSet] $this(sounds)]
}

proc ::Sounds::Create {name path} {
    global  this    
    variable priv
    variable nameToPath
    variable wqtframe
    
    # QuickTime doesn't understand vfs; need to copy out to tmp dir.
    if {$priv(QuickTimeTcl)} {
	if {[info exists ::starkit::topdir]} {
	    set path [CopyToTemp $path]
	}
	if {[catch {
	    movie $wqtframe.$name -file $path -controller 0
	}]} {
	    # ?
	}
    } elseif {[file extension $path] eq ".mid"} {
	if {[info exists ::starkit::topdir]} {
	    set path [CopyToTemp $path]
	}
    } elseif {$priv(snack)} {
	
	# Snack seems not to complain about midi files; just no sound.
	if {[catch {
	    snack::sound $name -load $path
	}]} {
	    # ?
	}
    }
    set nameToPath($name) $path
    return $path
}

proc ::Sounds::Play {snd} {
    variable sprefs
    variable priv
    variable afterid

    if {!$priv(inited)} {
	Init
    }
    
    # Check the jabber prefs if sound should be played.
    if {[info exists sprefs($snd)] && !$sprefs($snd)} {
	return
    }
    
    unset -nocomplain afterid($snd)
    DoPlay $snd
}

proc ::Sounds::DoPlay {snd} {
    variable priv
    variable wqtframe
    variable nameToPath
    
    if {$priv(QuickTimeTcl)} {
	if {[catch {$wqtframe.$snd play}]} {
	    # ?
	}
    } elseif {[file extension $nameToPath($snd)] eq ".mid"} {
	PlayMIDI $nameToPath($snd)
    } elseif {$priv(snack)} {
	if {[catch {$snd play}]} {
	    # ?
	}
    }
}

proc ::Sounds::PlayWhenIdle {snd} {
    variable afterid
    variable sprefs
	
    if {![info exists sprefs($snd)] || !$sprefs($snd)} {
	return
    }
    if {![info exists afterid($snd)]} {
	set afterid($snd) 1
	after idle [list ::Sounds::Play $snd]
    }    
}

proc ::Sounds::DoPlayWhenIdle {snd} {
    variable afterid
	
    if {![info exists afterid($snd)]} {
	set afterid($snd) 1
	after idle [list ::Sounds::Play $snd]
    }    
}

proc ::Sounds::PlaySoundTmp {path} {
    global  this
    variable priv
    variable wqtframe
    
    if {$priv(QuickTimeTcl)} {
	if {[info exists ::starkit::topdir]} {
	    set path [CopyToTemp $path]
	}
	destroy $wqtframe._tmp
	catch {
	    movie $wqtframe._tmp -file $path -controller 0
	    $wqtframe._tmp play
	}
    } elseif {[file extension $path] eq ".mid"} {
	if {[info exists ::starkit::topdir]} {
	    set path [CopyToTemp $path]
	}
	PlayMIDI $path 
    } elseif {$priv(snack)} {
	catch {_tmp destroy}
	catch {snack::sound _tmp -load $path}
	catch {_tmp play}
    }
}

proc ::Sounds::CopyToTemp {path} {
    global  this
    
    set tmp [::tfileutils::tempfile $this(tmpPath) sound]
    append tmp [file extension $path]
    file copy -force $path $tmp
    return $tmp
}

proc ::Sounds::PlayMIDI {fileName} {
    variable sprefs
    
    # This is unix only.
    set cmd  [lindex $sprefs(midiCmd) 0]
    set opts [lrange $sprefs(midiCmd) 1 end]
    set mcmd [auto_execok $cmd]
    if {$mcmd ne ""} {
	catch {exec $mcmd $opts $fileName &}
    }
}

proc ::Sounds::Msg {type snd xmldata {uuid ""}} {

    set body [wrapper::getcdata [wrapper::getfirstchildwithtag $xmldata body]]

    # We sometimes get non text stuff messages, like jabber:x:event etc.
    if {![string length $body]} {
	return
    }
    set from [wrapper::getattribute $xmldata from]

    # We shouldn't make noise for our own messages.
    switch -- $type {
	normal {

	}
	chat {
	    set myjid [::Jabber::GetMyJid]
	    set jid2 [jlib::barejid $myjid]
	    if {[string match ${jid2}* $from]} {
		return
	    }
	}
	groupchat {
	    set roomjid [jlib::barejid $from]
	    set myjid [::Jabber::GetMyJid $roomjid]
	    if {[jlib::jidequal $myjid $from]} {
		return
	    }
	}
    }
    PlayWhenIdle $snd
    return
}

proc ::Sounds::Event {snd args} {    
    PlayWhenIdle $snd
}

# Sounds::Presence --
#
#       Makes an alert sound corresponding to the jid's presence status.
#
# Arguments:
#       jid         bare JID
#       presence    "available", "unavailable", or "unsubscribed"
#       args        list of '-key value' pairs of presence attributes.
#       
# Results:
#       roster tree updated.

proc ::Sounds::Presence {jid presence args} {
    
    array set argsA $args
    
    set xmldata $argsA(-xmldata)
    set from [wrapper::getattribute $xmldata from]
    set jid2 [jlib::barejid $from]
    
    set wasAvail [::Jabber::Jlib roster wasavailable $jid]
    
    # Alert sounds.
    if {[::Jabber::Jlib service isroom $jid2]} {
	PlayWhenIdle groupchatpres
    } elseif {[string equal $presence "unavailable"]} {
	PlayWhenIdle offline
    } elseif {$wasAvail} {
	
	# Pling only when also show changed.
	set show ""
	if {[info exists argsA(-show)]} {
	    set show $argsA(-show)
	}
	set oldShow ""
	array set oldPresA [::Jabber::Jlib roster getoldpresence $from]
	if {[info exists oldPresA(-show)]} {
	    set oldShow $oldPresA(-show)
	}
	if {$show ne $oldShow} {
	    PlayWhenIdle statchange
	}
    } elseif {[string equal $presence "available"]} {
	PlayWhenIdle online
    }  
}

proc ::Sounds::Free {} {
    variable priv
    variable allSounds
    variable wqtframe
    
    if {$priv(QuickTimeTcl)} {
	catch {destroy $wqtframe}
    } elseif {$priv(snack)} {
	foreach name $allSounds {
	    catch {$name destroy}
	}
    }
}

# Preference page --------------------------------------------------------------

proc ::Sounds::BuildPrefsHook {wtree nbframe} {
    variable priv
    
    if {$priv(canPlay)} {
	::Preferences::NewTableItem {General Sounds} [mc "Sounds"]
	set wpage [$nbframe page {Sounds}]    
	BuildPrefsPage $wpage
    }
}

proc ::Sounds::BuildPrefsPage {wpage} {
    variable nameToText 
    variable sprefs
    variable tmpPrefs
    variable allSounds
    variable priv

    # System gain can have been changed.
    if {$priv(snack)} {
	set sprefs(volume) [snack::audio play_gain]
        set outputDevices [snack::audio outputDevices]
    }
    
    foreach name $allSounds {
	set tmpPrefs($name) $sprefs($name)
    }
    set tmpPrefs(soundSet)     $sprefs(soundSet)
    set tmpPrefs(volume)       $sprefs(volume)
    set tmpPrefs(midiCmd)      $sprefs(midiCmd)
    set tmpPrefs(outputDevice)  $sprefs(outputDevice)
    set soundSets [GetAllSets]
    
    set wc $wpage.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    ttk::frame $wc.alrt -padding {0 0 0 6}
    ttk::label $wc.alrt.l -text [mc "Alert sounds"]
    ttk::separator $wc.alrt.s -orient horizontal
    
    grid  $wc.alrt.l  $wc.alrt.s  -sticky w
    grid $wc.alrt.s -sticky ew
    grid columnconfigure $wc.alrt 1 -weight 1
    
    pack  $wc.alrt  -side top -anchor w -fill x
   
    set fss $wc.fss
    ttk::frame $fss
    ttk::label $fss.l -text [mc "Sound set"]:
    ui::combobutton $fss.p -variable [namespace current]::tmpPrefs(soundSet) \
      -menulist [ui::optionmenu::menuList $soundSets]
        
    grid  $fss.l  $fss.p  -sticky w -padx 2
    grid  $fss.p  -sticky ew
    grid columnconfigure $fss 1 -minsize [$fss.p maxwidth]

    ttk::label $wc.lbl -text [mc "Enable or disable sounds below"]:

    set wmid $wc.m
    ttk::frame $wmid

    pack  $wc.fss  -side top -anchor w
    pack  $wc.lbl  -side top -anchor w -pady 8
    pack  $wc.m    -side top
    
    foreach name $allSounds {
	ttk::checkbutton $wmid.c$name -text [dict get $nameToText $name]  \
	  -variable [namespace current]::tmpPrefs($name)
	ttk::button $wmid.b$name -text [mc "Play"] \
	  -command [list [namespace current]::PlayTmpPrefSound $name]
	grid  $wmid.c$name  $wmid.b$name  -sticky w -padx 4 -pady 1
	grid  $wmid.b$name  -sticky ew
    }

    set fvol $wc.fvol
    ttk::frame $fvol
    ttk::label $fvol.l -text [mc "Volume"]:
    ttk::scale $fvol.v -orient horizontal -from 0 -to 100 \
      -variable [namespace current]::tmpPrefs(volume) -value $tmpPrefs(volume)

    pack  $fvol.l  -side left -padx 4
    pack  $fvol.v  -side left -padx 4
    pack  $fvol  -side top -pady 4 -anchor [option get . dialogAnchor {}]

    if {$priv(snack)} {
        set odev $wc.odev
        ttk::frame $odev
        ttk::label $odev.l -text [mc "Sound device"]:
        ui::combobutton $odev.p -variable [namespace current]::tmpPrefs(outputDevice) \
          -menulist [ui::optionmenu::menuList $outputDevices]
        grid $odev.l $odev.p -sticky w -padx 2
        grid $odev.p -sticky ew
        grid columnconfigure $odev 1 -minsize [$odev.p maxwidth]
        pack  $wc.odev  -side top -anchor w
    }

    ttk::button $wc.midi -text [mc "MIDI Player"] -command ::Sounds::MidiPlayer
    pack  $wc.midi -pady 2
    
    bind $wpage <Destroy> {+::Sounds::PrefsFree}
}

proc ::Sounds::MidiPlayer {} {
    variable tmpPrefs
    
    set title [mc "External Midi Player"]
    set ans [ui::megaentry -title $title -message [mc "Set command to use for playing MIDI sounds. This option is only relevant if you use a sound set with MIDI files."] \
      -label [mc "MIDI command"]: -value $tmpPrefs(midiCmd)]
    if {$ans ne ""} {
	set tmpPrefs(midiCmd) [ui::megaentrytext $ans]
    }
}

proc ::Sounds::PlayTmpPrefSound {name} {
    global  this
    variable priv
    variable soundIndex
    variable tmpPrefs
    variable wqtframe
    
    array set sound [array get soundIndex]
    set path [GetPathForSet $tmpPrefs(soundSet)]
    source [file join $path soundIndex.tcl]
    set f [file join $path $sound($name)]

    if {$priv(QuickTimeTcl)} {
	if {[info exists ::starkit::topdir]} {
	    set tmp [::tfileutils::tempfile $this(tmpPath) sound]
	    append tmp [file extension $f]
	    file copy -force $f $tmp
	    set f $tmp
	}
	destroy $wqtframe._tmp
	catch {
	    movie $wqtframe._tmp -file $f -controller 0 \
	      -volume [expr {int($tmpPrefs(volume) * 2.55)}]
	    $wqtframe._tmp play
	}
    } elseif {$priv(snack)} {
	catch {_tmp destroy}
	catch {snack::sound _tmp -load $f}
	catch {_tmp play}
    }
}

proc ::Sounds::SavePrefsHook {} {
    variable sprefs
    variable tmpPrefs
    variable allSounds
    variable priv
    variable wqtframe
    
    if {!$priv(canPlay)} {
	return
    }
    if {[string equal $tmpPrefs(soundSet) [mc "Default"]]} {
	set tmpPrefs(soundSet) ""
    }
    if {![string equal $tmpPrefs(soundSet) $sprefs(soundSet)]} {
	LoadSoundSet $tmpPrefs(soundSet)
    }
    set sprefs(soundSet)     $tmpPrefs(soundSet)
    set sprefs(volume)       $tmpPrefs(volume)
    set sprefs(outputDevice) $tmpPrefs(outputDevice)
    foreach name $allSounds {
	set sprefs($name) $tmpPrefs($name)
    }
    if {$priv(QuickTimeTcl)} {
	foreach wmovie [winfo children $wqtframe] {
	    if {[winfo class $wmovie] eq "Movie"} {
		$wmovie configure -volume [expr {int($sprefs(volume) * 2.55)}]
	    }
	}
    }
    
    # The snack play_gain seems to be set globally on the machine which is BAD!
    if {$priv(snack)} {
	snack::audio play_gain [expr int($sprefs(volume))]
	snack::audio selectOutput $sprefs(outputDevice)
    }
    set sprefs(midiCmd) $tmpPrefs(midiCmd)

}

proc ::Sounds::CancelPrefsHook {} {
    variable sprefs
    variable tmpPrefs
    variable allSounds
    variable priv
    
    if {!$priv(canPlay)} {
	return
    }    
    
    foreach name $allSounds {
	if {$sprefs($name) ne $tmpPrefs($name)} {
	    ::Preferences::HasChanged
	}
    }
    if {[string equal $tmpPrefs(soundSet) [mc "Default"]]} {
	set tmpPrefs(soundSet) ""
    }
    if {![string equal $sprefs(soundSet) $tmpPrefs(soundSet)]} {
	::Preferences::HasChanged
    }
    if {![string equal $sprefs(volume) $tmpPrefs(volume)]} {
	::Preferences::HasChanged
    }
    if {![string equal $sprefs(midiCmd) $tmpPrefs(midiCmd)]} {
	::Preferences::HasChanged
    }
    if {![string equal $sprefs(outputDevice) $tmpPrefs(outputDevice)]} {
	::Preferences::HasChanged
    }
}

proc ::Sounds::UserDefaultsHook {} {
    variable sprefs
    variable tmpPrefs
    variable allSounds

    foreach name $allSounds {
	set tmpPrefs($name) $sprefs($name)
    }
    if {[string equal $sprefs(soundSet) ""]} {
	set tmpPrefs(soundSet) [mc "Default"]
    } else {
	set tmpPrefs(soundSet) $sprefs(soundSet)
    }
}

proc ::Sounds::PrefsFree {} {
    variable tmpPrefs
    
    unset -nocomplain tmpPrefs
}

#-------------------------------------------------------------------------------
