#  Sounds.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements alert sounds.
#      
#  Copyright (c) 2002-2005  Mats Bengtsson
#  
# $Id: Sounds.tcl,v 1.30 2007-03-12 13:19:56 matben Exp $

namespace eval ::Sounds:: {
	
    variable nameToText 
    array set nameToText {
	online          "User is online"
	offline         "User is offline"
	newmsg          "New incoming message"
	newchatmsg      "New chat message"
	newchatthread   "New chat thread"
	statchange      "User's status changed"
	connected       "Is connected"
	groupchatpres   "Groupchat presence change"
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
	groupchatpres   clicked.wav
    }
    
    variable wqtframe .quicktime::audio

    variable allSounds
    set allSounds [array names soundIndex]
}

# Sounds::Load --
# 
#       Tries to load the sounds component.

proc ::Sounds::Load { } {
    variable priv
    
    ::Debug 2 "::Sounds::Load"

    set priv(canPlay)      0
    set priv(inited)       0
    set priv(QuickTimeTcl) [::Media::HavePackage QuickTimeTcl]
    set priv(snack)        [::Media::HavePackage snack]

    # Skip if both 0.
    if {!$priv(QuickTimeTcl) && !$priv(snack)} {
	return
    }
    set priv(canPlay) 1
   
    # We should register ourselves.
    component::register Sounds "Provides alert sounds through QuickTime\
      or the Snack audio package."

    # Make sure we get called when certain events happen.
    InitEventHooks
}

proc ::Sounds::InitEventHooks { } {
    
    # Add all event hooks.
    ::hooks::register quitAppHook             ::Sounds::Free 80
    ::hooks::register newMessageHook          [list ::Sounds::Msg normal newmsg]
    ::hooks::register newChatMessageHook      [list ::Sounds::Msg chat newchatmsg]
    ::hooks::register newGroupChatMessageHook [list ::Sounds::Msg groupchat newchatmsg]
    ::hooks::register newChatThreadHook       [list ::Sounds::Event newchatthread]
    ::hooks::register loginHook               [list ::Sounds::Event connected]
    ::hooks::register presenceNewHook         ::Sounds::Presence

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
    
    # We do this after a delay to avoid locking the UI.
    # Be sure to force an Init if needed before this.
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

    if {$priv(inited)} {
	return
    }
    
    # Create all sounds from current sound set (which is "" as default).
    if {$priv(canPlay)} {
	
	# Verify that sound set exists.
	if {[lsearch -exact [GetAllSets] $sprefs(soundSet)] < 0} {
	    set sprefs(soundSet) ""
	}
	LoadSoundSet $sprefs(soundSet)
    }
    set priv(inited) 1
}

proc ::Sounds::LoadSoundSet {soundSet} {
    global  this
    variable allSounds
    variable soundIndex
    variable priv
    variable wqtframe

    ::Debug 2 "::Sounds::LoadSoundSet: soundSet=$soundSet"
    
    Free
	
    array set sound [array get soundIndex]
    
    # Search for given sound set.
    if {$soundSet eq ""} {
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
	frame $wqtframe
    }
    foreach s $allSounds {
	Create $s [file join $path $sound($s)]
    }
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
}

proc ::Sounds::Play {snd} {
    variable sprefs
    variable priv
    variable afterid
    variable nameToPath
    variable soundIndex
    variable wqtframe

    if {!$priv(inited)} {
	Init
    }
    
    # Check the jabber prefs if sound should be played.
    if {[info exists sprefs($snd)] && !$sprefs($snd)} {
	return
    }
    
    unset -nocomplain afterid($snd)
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

proc ::Sounds::PlaySoundTmp {path} {
    global  this
    variable priv
    variable wqtframe
    
    if {$priv(QuickTimeTcl)} {
	if {[info exists ::starkit::topdir]} {
	    set path [CopyToTemp $path]
	}
	catch {destroy $wqtframe._tmp}
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

proc ::Sounds::Msg {type snd body args} {
        
    # We sometimes get non text stuff messages, like jabber:x:event etc.
    if {![string length $body]} {
	return
    }
    array set argsA $args
    set xmldata $argsA(-xmldata)
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
}

proc ::Sounds::Event {snd args} {
    
    PlayWhenIdle $snd
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
    jlib::splitjid $jid jid2 res
	
    # Alert sounds.
    if {[::Jabber::JlibCmd service isroom $jid2]} {
	PlayWhenIdle groupchatpres
    } elseif {[info exists argsArr(-show)] && [string equal $argsArr(-show) "chat"]} {
	PlayWhenIdle statchange
    } elseif {[string equal $presence "available"]} {
	PlayWhenIdle online
    } elseif {[string equal $presence "unavailable"]} {
	PlayWhenIdle offline
    }    
}


proc ::Sounds::Free { } {
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

proc  ::Sounds::InitPrefsHook { } {
    variable sprefs
    variable allSounds
    variable priv
    
    set sprefs(soundSet) ""
    set sprefs(volume)   100
    set sprefs(midiCmd)  ""

    ::PrefUtils::Add [list  \
      [list ::Sounds::sprefs(soundSet) sound_set     $sprefs(soundSet)] \
      [list ::Sounds::sprefs(volume)   sound_volume  $sprefs(volume)]   \
      [list ::Sounds::sprefs(midiCmd)  sound_midiCmd $sprefs(midiCmd)]  \
      ]
    
    set optList {}
    foreach name $allSounds {
	set sprefs($name) 1
	lappend optList [list ::Sounds::sprefs($name) sound_${name} $sprefs($name)]
    }
    ::PrefUtils::Add $optList    
    
    # Volume seems to be set globally on snack.
    if {$priv(snack)} {
	set sprefs(volume) [snack::audio play_gain]
    }
}

proc ::Sounds::BuildPrefsHook {wtree nbframe} {
    variable priv
    
    if {$priv(canPlay)} {
	::Preferences::NewTableItem {General Sounds} [mc {Sounds}]
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
    }
    
    foreach name $allSounds {
	set tmpPrefs($name) $sprefs($name)
    }
    if {$sprefs(soundSet) eq ""} {
	set tmpPrefs(soundSet) [mc Default]
    } else {
	set tmpPrefs(soundSet) $sprefs(soundSet)
    }
    set tmpPrefs(volume) $sprefs(volume)
    set soundSets [concat [list [mc Default]] [GetAllSets]]
    
    set wc $wpage.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    set walrt $wc.fr
    ttk::labelframe $walrt -text [mc {Alert sounds}] \
      -padding [option get . groupSmallPadding {}]
    pack  $walrt  -side top -fill x
   
    set fss $walrt.fss
    ttk::frame $fss
    ttk::label $fss.l -text "[mc {Sound Set}]:"
    eval {ttk::optionmenu $fss.p [namespace current]::tmpPrefs(soundSet)} \
      $soundSets

    grid  $fss.l  $fss.p  -sticky w -padx 2
    grid  $fss.p  -sticky ew
    
    ttk::label $walrt.lbl -text [mc prefsounpick]

    set wmid $walrt.m
    ttk::frame $wmid

    pack  $walrt.fss  -side top -anchor w
    pack  $walrt.lbl  -side top -anchor w -pady 8
    pack  $walrt.m    -side top
    
    foreach name $allSounds {
	set txt $nameToText($name)
	ttk::checkbutton $wmid.c$name -text [mc $txt]  \
	  -variable [namespace current]::tmpPrefs($name)
	ttk::button $wmid.b$name -text [mc Play] \
	  -command [list [namespace current]::PlayTmpPrefSound $name]
	grid  $wmid.c$name  $wmid.b$name  -sticky w -padx 4 -pady 1
	grid  $wmid.b$name  -sticky ew
    }

    set fvol $walrt.fvol
    ttk::frame $fvol
    ttk::label $fvol.l -text "[mc Volume]:"
    ttk::scale $fvol.v -orient horizontal -from 0 -to 100 \
      -variable [namespace current]::tmpPrefs(volume) -value $tmpPrefs(volume)

    pack  $fvol.l  -side left -padx 4
    pack  $fvol.v  -side left -padx 4
    pack  $fvol  -side top -pady 4 -anchor [option get . dialogAnchor {}]

    ttk::button $walrt.midi -text [mc {MIDI Player}] -command ::Sounds::MidiPlayer
    pack  $walrt.midi -pady 4
    
    bind $wpage <Destroy> {+::Sounds::PrefsFree}
}

proc ::Sounds::MidiPlayer { } {
    variable tmpPrefs
    
    set title "External Midi Player"
    set msg "Set midi command to use for playing MIDI sounds.\
      This option is only relevant if you have a sound set with MIDI files.\
      Your system midi player command must have the \"command fileName\"\
      syntax."
    set label "MIDI command:"
    set varName [namespace current]::midiCmd

    set ans [::UI::MegaDlgMsgAndEntry $title $msg $label $varName \
     [mc Cancel] [mc OK]]
    if {$ans eq "ok"} {
	set tmpPrefs(midiCmd) [set $varName]
    }
}

proc ::Sounds::PlayTmpPrefSound {name} {
    global  this
    variable priv
    variable soundIndex
    variable tmpPrefs
    variable wqtframe
    
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
	if {[info exists ::starkit::topdir]} {
	    set tmp [::tfileutils::tempfile $this(tmpPath) sound]
	    append tmp [file extension $f]
	    file copy -force $f $tmp
	    set f $tmp
	}
	catch {destroy $wqtframe._tmp}
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

proc ::Sounds::SavePrefsHook { } {
    variable sprefs
    variable tmpPrefs
    variable allSounds
    variable priv
    variable wqtframe
    
    if {!$priv(canPlay)} {
	return
    }
    if {[string equal $tmpPrefs(soundSet) [mc Default]]} {
	set tmpPrefs(soundSet) ""
    }
    if {![string equal $tmpPrefs(soundSet) $sprefs(soundSet)]} {
	LoadSoundSet $tmpPrefs(soundSet)
    }
    set sprefs(soundSet) $tmpPrefs(soundSet)
    set sprefs(volume)   $tmpPrefs(volume)
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
    if {$priv(snack)} {
	snack::audio play_gain [expr int($sprefs(volume))]
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
    if {![string equal $sprefs(volume) $tmpPrefs(volume)]} {
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

proc ::Sounds::PrefsFree { } {
    variable tmpPrefs
    
    unset -nocomplain tmpPrefs
}

#-------------------------------------------------------------------------------
