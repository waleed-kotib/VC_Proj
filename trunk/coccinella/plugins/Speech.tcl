#  Speech.tcl ---
#  
#      Implements platform independent synthetic speech.
#      
#  Copyright (c) 2003-2004  Mats Bengtsson
#  
# $Id: Speech.tcl,v 1.2 2004-06-07 06:23:35 matben Exp $

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
	    set sprefs(package) MSSpeech
	    set sprefs(haveSpeech) 1
	}
	default {
	    return
	}
    }    
    ::Speech::Init
    
    # We should register ourselves.
    component::register Speech "Provides synthetic speech on Macs using\
      TclSpeech and on Windows using MSSpeech"
}

proc ::Speech::Init { } {
        
    ::Debug 2 "::Speech::Init"

    # Hooks to run when message displayed to user.
    ::hooks::add displayMessageHook          [list ::Speech::SpeakMessage normal]
    ::hooks::add displayChatMessageHook      [list ::Speech::SpeakMessage chat]
    ::hooks::add displayGroupChatMessageHook [list ::Speech::SpeakMessage groupchat]
    ::hooks::add whiteboardTextInsertHook    ::Speech::SpeakWBText

    # Define all hooks for preference settings.
    ::hooks::add prefsInitHook          ::Speech::InitPrefsHook
    ::hooks::add prefsBuildHook         ::Speech::BuildPrefsHook
    ::hooks::add prefsSaveHook          ::Speech::SavePrefsHook
    ::hooks::add prefsCancelHook        ::Speech::CancelPrefsHook
    ::hooks::add prefsUserDefaultsHook  ::Speech::UserDefaultsPrefsHook
}

# Speech::Verify --
# 
#       Verifies that we actually have a speech package.
#       Also checks voices available.

proc ::Speech::Verify { } {
    variable sprefs
    
    # Voices consistency check.
    if {$sprefs(package) == "TclSpeech"} {
	set voices [speech::speakers]
	if {([lsearch $voices $sprefs(voiceUs)] < 0) || \
	  ($sprefs(voiceUs) == "")} {
	    set sprefs(voiceUs) Victoria
	}
	if {([lsearch $voices $sprefs(voiceOther)] < 0) || \
	  ($sprefs(voiceOther) == "")} {
	    set sprefs(voiceOther) Zarvox
	}
    }
    if {$sprefs(package) == "MSSpeech"} {
	set voices [::MSSpeech::GetVoices]
	if {([lsearch $voices $sprefs(voiceUs)] < 0) || \
	  ($sprefs(voiceUs) == "")} {
	    set sprefs(voiceUs) [lindex $voices 0]
	}
	if {([lsearch $voices $sprefs(voiceOther)] < 0) || \
	  ($sprefs(voiceOther) == "")} {
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
		  ($argsArr(-subject) != "")} {
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
    if {$sprefs(speakWBText) && [string match *${punct}* $str] && ($str != "")} {
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

    ::PreferencesUtils::Add [list  \
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
	$wtree newitem {General {Speech}} -text [::msgcat::mc {Speech}]
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
	catch {unset tmpPrefs}
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
	catch {unset tmpPrefs}
    }
}

proc ::Speech::UserDefaultsPrefsHook { } {
    variable sprefs
    variable tmpPrefs
    
    array set tmpPrefs [array get sprefs]
}

proc ::Speech::BuildPrefsPage {page} {
    variable sprefs
    variable tmpPrefs
    
    set fontSB [option get . fontSmallBold {}]
    
    array set tmpPrefs [array get sprefs]
    
    set labpsp $page.sp
    labelframe $labpsp -text [::msgcat::mc {Synthetic speech}]
    pack $labpsp -side top -anchor w -padx 8 -pady 4
    
    checkbutton $labpsp.speak     -text "  [::msgcat::mc prefsounsynwb]"  \
      -variable [namespace current]::tmpPrefs(speakWBText)
    checkbutton $labpsp.speakmsg  -text "  [::msgcat::mc prefsounsynno]"  \
      -variable [namespace current]::tmpPrefs(speakMsg)
    checkbutton $labpsp.speakchat -text "  [::msgcat::mc prefsounsynch]"  \
      -variable [namespace current]::tmpPrefs(speakChat)
    pack $labpsp.speak     -side top -anchor w -padx 10
    pack $labpsp.speakmsg  -side top -anchor w -padx 10
    pack $labpsp.speakchat -side top -anchor w -padx 10
    
    if {$sprefs(haveSpeech)} {
	
	# Get a list of voices
	set voicelist "None [::Speech::SpeakGetVoices]"
    } else {
	set voicelist {None}
	$labpsp.speak configure -state disabled
	$labpsp.speakmsg configure -state disabled
	$labpsp.speakchat configure -state disabled
	set tmpPrefs(SpeechOn) 0
    }
    pack [frame $labpsp.fr] -side top -anchor w -padx 26 -pady 2
    label $labpsp.fr.in  -text [::msgcat::mc prefsounvoin]
    label $labpsp.fr.out -text [::msgcat::mc prefsounvoou]
    
    set wpopin $labpsp.fr.popin
    set wpopupmenuin [eval {tk_optionMenu $wpopin   \
      [namespace current]::tmpPrefs(voiceOther)} $voicelist]
    $wpopin configure -highlightthickness 0 -font $fontSB
    set wpopout $labpsp.fr.popout
    set wpopupmenuout [eval {tk_optionMenu $wpopout   \
      [namespace current]::tmpPrefs(voiceUs)} $voicelist]
    $wpopout configure -highlightthickness 0 -font $fontSB
    
    grid $labpsp.fr.in  -column 0 -row 0 -sticky e -pady 1
    grid $wpopout       -column 1 -row 0 -sticky w -pady 1
    grid $labpsp.fr.in  -column 0 -row 1 -sticky e -pady 1
    grid $wpopout       -column 1 -row 1 -sticky w -pady 1
    if {!$sprefs(haveSpeech)} {
	$wpopin configure -state disabled
	$wpopout configure -state disabled
    }    
}

#-------------------------------------------------------------------------------
