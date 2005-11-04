#  Speech.tcl ---
#  
#      Implements platform independent synthetic speech.
#      
#  Copyright (c) 2003-2004  Mats Bengtsson
#  
# $Id: Speech.tcl,v 1.9 2005-11-04 15:14:55 matben Exp $

namespace eval ::Speech:: { }

# Speech::Load --
# 
#       Tries to load the speech component.

proc ::Speech::Load { } {
    global  this
    variable sprefs
    
    ::Debug 2 "::Speech::Load"
    
    set sprefs(package) ""
    set sprefs(haveSpeech) 0
    
    switch -- $this(platform) {
	macosx - macintosh {
	    if {[catch {package require TclSpeech}]} {
		return
	    }
	    set sprefs(haveSpeech) 1
	    set sprefs(package) TclSpeech
	}
	windows {
	    if {[catch {package require MSSpeech}]} {
		return
	    }
	    set sprefs(haveSpeech) 1
	    set sprefs(package) MSSpeech
	}
	default {
	    return
	}
    }
    
    # Set up all hooks.
    ::Speech::Init
    
    # We should register ourselves.
    component::register Speech "Provides synthetic speech on Macs using\
      TclSpeech and on Windows using MSSpeech.\
      When enabled, a synthetic voice speaks out\
      text that is written in the canvas as well as text received\
      from remote clients. It is triggered by a punctation character (,.;)."
}

proc ::Speech::Init { } {
        
    ::Debug 2 "::Speech::Init"

    # Hooks to run when message displayed to user.
    ::hooks::register displayMessageHook          [list ::Speech::SpeakMessage normal]
    ::hooks::register displayChatMessageHook      [list ::Speech::SpeakMessage chat]
    ::hooks::register displayGroupChatMessageHook [list ::Speech::SpeakMessage groupchat]
    ::hooks::register whiteboardTextInsertHook    ::Speech::SpeakWBText

    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          ::Speech::InitPrefsHook
    ::hooks::register prefsBuildHook         ::Speech::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::Speech::SavePrefsHook
    ::hooks::register prefsCancelHook        ::Speech::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::Speech::UserDefaultsPrefsHook
    ::hooks::register prefsDestroyHook       ::Speech::DestroyPrefsHook
}

# Speech::Verify --
# 
#       Verifies that we actually have a speech package.
#       Also checks voices available.

proc ::Speech::Verify { } {
    variable sprefs
    
    # Voices consistency check.
    if {$sprefs(package) eq "TclSpeech"} {
	set voices [speech::speakers]
	if {([lsearch $voices $sprefs(voiceUs)] < 0) || \
	  ($sprefs(voiceUs) eq "")} {
	    set sprefs(voiceUs) Victoria
	}
	if {([lsearch $voices $sprefs(voiceOther)] < 0) || \
	  ($sprefs(voiceOther) eq "")} {
	    set sprefs(voiceOther) Zarvox
	}
    }
    if {$sprefs(package) eq "MSSpeech"} {
	set voices [::MSSpeech::GetVoices]
	if {([lsearch $voices $sprefs(voiceUs)] < 0) || \
	  ($sprefs(voiceUs) eq "")} {
	    set sprefs(voiceUs) [lindex $voices 0]
	}
	if {([lsearch $voices $sprefs(voiceOther)] < 0) || \
	  ($sprefs(voiceOther) eq "")} {
	    set sprefs(voiceOther) [lindex $voices 1]
	}
    }
}


proc ::Speech::SpeakMessage {type body args} {
    variable sprefs
    
    array set argsArr $args
    set from ""
    if {[info exists argsArr(-from)]} {
	set from $argsArr(-from)
    }
    
    switch -- $type {
	normal {
	    if {$sprefs(speakMsg)} {
		set txt " "
		if {[info exists argsArr(-subject)] && \
		  ($argsArr(-subject) ne "")} {
		    append txt "Subject is $argsArr(-subject). "
		}
		append txt $body
		::Speech::Speak $txt $sprefs(voiceOther)
	    }
	}
	chat {
	    if {$sprefs(speakChat)} {
		set myjid [::Jabber::GetMyJid]
		jlib::splitjid $myjid jid2 res
		if {[string match ${jid2}* $from]} {
		    set voice $sprefs(voiceUs)
		    set txt "I say, "
		} else {
		    set voice $sprefs(voiceOther)
		    set txt " , "
		}
		append txt $body
		::Speech::Speak $txt $voice
	    }
	}
	groupchat {
	    if {$sprefs(speakChat)} {
		jlib::splitjid $from roomjid res
		set myjid [::Jabber::GetMyJid $roomjid]
		if {[string equal $myjid $from]} {
		    ::Speech::Speak $body $sprefs(voiceUs)
		} else {
		    ::Speech::Speak $body $sprefs(voiceOther)
		}
	    }
	}
    }
}

proc ::Speech::SpeakWBText {who str} {
    variable sprefs
        
    set punct {[.,;?!]}
    set voice ""    

    switch -- $who {
	me {
	    set voice $sprefs(voiceUs)
	}
	other {
	    set voice $sprefs(voiceOther)
	}
    }
    if {$sprefs(speakWBText) && [string match *${punct}* $str] && ($str ne "")} {
	::Speech::Speak $str $voice
    }
}

proc ::Speech::Speak {msg {voice {}}} {
    global  this
    
    switch -- $this(platform) {
	macintosh - macosx {
	    ::Mac::Speech::Speak $msg $voice
	}
	windows {
	    ::MSSpeech::Speak $msg $voice
	}
	unix {
	    # empty.
	}
    }
}

proc ::Speech::SpeakGetVoices { } {
    global  this
    
    switch -- $this(platform) {
	macintosh - macosx {
	    return [::Mac::Speech::GetVoices]
	}
	windows {
	    return [::MSSpeech::GetVoices]
	}
	unix {
	    return {}
	}
    }
}

# Preference page --------------------------------------------------------------

proc ::Speech::InitPrefsHook { } {
    
    variable sprefs
    variable allprefskeys {speakWBText speakMsg speakChat voiceUs voiceOther}
       
    ::Debug 2 "::Speech::InitPrefsHook sprefs(haveSpeech)=$sprefs(haveSpeech)"
    
    # Default in/out voices. They will be set to actual values in 
    # ::Plugins::VerifySpeech  
    set sprefs(voiceUs)    ""
    set sprefs(voiceOther) ""

    set sprefs(speakMsg)      0
    set sprefs(speakChat)     0
    set sprefs(speakWBText)   0

    ::PrefUtils::Add [list  \
      [list ::Speech::sprefs(speakMsg)    speakMsg        $sprefs(speakMsg)]    \
      [list ::Speech::sprefs(speakChat)   speakChat       $sprefs(speakChat)]   \
      [list ::Speech::sprefs(speakWBText) speakWBText     $sprefs(speakWBText)] \
      [list ::Speech::sprefs(voiceUs)     speakVoiceUs    $sprefs(voiceUs)]     \
      [list ::Speech::sprefs(voiceOther)  speakVoiceOther $sprefs(voiceOther)]]

    #
    ::Speech::Verify
}

proc ::Speech::BuildPrefsHook {wtree nbframe} {
    variable sprefs
    
    if {$sprefs(haveSpeech)} {
	::Preferences::NewTableItem {General {Speech}} [mc {Speech}]

	set wpage [$nbframe page {Speech}]    
	::Speech::BuildPrefsPage $wpage
    }
}

proc ::Speech::SavePrefsHook { } {
    variable sprefs
    variable tmpPrefs
    variable allprefskeys

    if {$sprefs(haveSpeech)} {
	foreach key $allprefskeys {
	    set sprefs($key) $tmpPrefs($key)
	}
	unset -nocomplain tmpPrefs
    }
}

proc ::Speech::CancelPrefsHook { } {
    variable sprefs
    variable tmpPrefs
    variable allprefskeys
    
    if {$sprefs(haveSpeech)} {

	# Detect any changes.
	foreach key $allprefskeys {
	    if {![string equal $sprefs($key) $tmpPrefs($key)]} {
		::Preferences::HasChanged
		return
	    }
	}
    }
}

proc ::Speech::DestroyPrefsHook { } {
    variable tmpPrefs
    
    unset -nocomplain tmpPrefs
}

proc ::Speech::UserDefaultsPrefsHook { } {
    variable sprefs
    variable tmpPrefs
    
    array set tmpPrefs [array get sprefs]
}

proc ::Speech::BuildPrefsPage {page} {
    variable sprefs
    variable tmpPrefs
        
    array set tmpPrefs [array get sprefs]
    
    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    set wfr $wc.f
    ttk::labelframe $wfr -text [mc {Synthetic speech}] \
      -padding [option get . groupSmallPadding {}]
    pack  $wfr  -side top
    
    ttk::checkbutton $wfr.speak     -text [mc prefsounsynwb]  \
      -variable [namespace current]::tmpPrefs(speakWBText)
    ttk::checkbutton $wfr.speakmsg  -text [mc prefsounsynno]  \
      -variable [namespace current]::tmpPrefs(speakMsg)
    ttk::checkbutton $wfr.speakchat -text [mc prefsounsynch]  \
      -variable [namespace current]::tmpPrefs(speakChat)

    grid $wfr.speak      -sticky w
    grid $wfr.speakmsg   -sticky w
    grid $wfr.speakchat  -sticky w
    
    if {$sprefs(haveSpeech)} {
	
	# Get a list of voices
	set voicelist [concat None [::Speech::SpeakGetVoices]]
    } else {
	set voicelist {None}
	$wfr.speak     state {disabled}
	$wfr.speakmsg  state {disabled}
	$wfr.speakchat state {disabled}
	set tmpPrefs(SpeechOn) 0
    }
    
    set wfvo $wfr.fvo
    ttk::frame $wfvo
    grid  $wfvo  -pady 4
    
    ttk::label $wfvo.in  -text [mc prefsounvoin]
    ttk::label $wfvo.out -text [mc prefsounvoou]    
    eval {ttk::optionmenu $wfvo.pin \
      [namespace current]::tmpPrefs(voiceOther)} $voicelist
    eval {ttk::optionmenu $wfvo.pout   \
      [namespace current]::tmpPrefs(voiceUs)} $voicelist
    
    grid  $wfvo.in   $wfvo.pin   -sticky e -padx 2 -pady 1
    grid  $wfvo.out  $wfvo.pout  -sticky e -padx 2 -pady 1
    grid  $wfvo.pin  $wfvo.pout  -sticky ew

    if {!$sprefs(haveSpeech)} {
	$wfvo.pin  state {disabled}
	$wfvo.pout state {disabled}
    }    
}

#-------------------------------------------------------------------------------
