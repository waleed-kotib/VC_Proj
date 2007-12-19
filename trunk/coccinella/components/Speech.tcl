#  Speech.tcl ---
#  
#      Implements platform independent synthetic speech.
#      
#  Copyright (c) 2003-2007  Mats Bengtsson
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
# $Id: Speech.tcl,v 1.18 2007-12-19 07:52:55 matben Exp $

namespace eval ::Speech {
    variable sprefs

    set sprefs(package) ""
    set sprefs(haveSpeech) 0
    
    switch -- $::this(platform) {
	macosx {
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

    component::define Speech \
      "Text-to-speech on Macs using TclSpeech and on Windows using MSSpeech"
}

# Speech::Load --
# 
#       Tries to load the speech component.

proc ::Speech::Load {} {
    
    ::Debug 2 "::Speech::Load"    
    
    # Set up all hooks.
    Init
    
    # We should register ourselves.
    component::register Speech
}

proc ::Speech::Init {} {
        
    ::Debug 2 "::Speech::Init"

    # Hooks to run when message displayed to user.
    ::hooks::register displayMessageHook          [list ::Speech::SpeakMessage normal]
    ::hooks::register displayChatMessageHook      ::Speech::SpeakMessage2
    ::hooks::register displayGroupChatMessageHook ::Speech::SpeakMessage2
    ::hooks::register whiteboardTextInsertHook    ::Speech::SpeakWBText

    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          ::Speech::InitPrefsHook
    ::hooks::register prefsBuildHook         ::Speech::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::Speech::SavePrefsHook
    ::hooks::register prefsCancelHook        ::Speech::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::Speech::UserDefaultsPrefsHook
}

# Speech::Verify --
# 
#       Verifies that we actually have a speech package.
#       Also checks voices available.

proc ::Speech::Verify {} {
    global  this
    variable sprefs
  
    set plat $this(platform)
    set voices [SpeakGetVoices]

    # Voices consistency check.
    if {([lsearch $voices $sprefs(voiceUs-$plat)] < 0) || \
      ($sprefs(voiceUs-$plat) eq "")} {
	set sprefs(voiceUs-$plat) [lindex $voices 0]
    }
    if {([lsearch $voices $sprefs(voiceOther-$plat)] < 0) || \
      ($sprefs(voiceOther-$plat) eq "")} {
	set sprefs(voiceOther-$plat) [lindex $voices 1]
    }
    
    # Always keep shortcut names.
    set sprefs(voiceUs)    $sprefs(voiceUs-$plat)
    set sprefs(voiceOther) $sprefs(voiceOther-$plat)
}

proc ::Speech::SpeakMessage2 {xmldata} {
    variable sprefs

    set from [wrapper::getattribute $xmldata from]
    set type [wrapper::getattribute $xmldata type]
    set subject [wrapper::getcdata [wrapper::getfirstchildwithtag $xmldata subject]]
    set body    [wrapper::getcdata [wrapper::getfirstchildwithtag $xmldata body]]

    switch -- $type {
	chat {
	    if {$sprefs(speakChat)} {
		set myjid [::Jabber::GetMyJid]
		set jid2 [jlib::barejid $myjid]
		if {[string match ${jid2}* $from]} {
		    set voice $sprefs(voiceUs)
		    set txt "I say, "
		} else {
		    set voice $sprefs(voiceOther)
		    set txt " , "
		}
		append txt $body
		Speak $txt $voice
	    }
	}
	groupchat {
	    if {$sprefs(speakChat)} {
		jlib::splitjid $from roomjid res
		set myjid [::Jabber::GetMyJid $roomjid]
		if {[string equal $myjid $from]} {
		    Speak $body $sprefs(voiceUs)
		} else {
		    Speak $body $sprefs(voiceOther)
		}
	    }
	}
    }
    return
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
		Speak $txt $sprefs(voiceOther)
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
		Speak $txt $voice
	    }
	}
	groupchat {
	    if {$sprefs(speakChat)} {
		jlib::splitjid $from roomjid res
		set myjid [::Jabber::GetMyJid $roomjid]
		if {[string equal $myjid $from]} {
		    Speak $body $sprefs(voiceUs)
		} else {
		    Speak $body $sprefs(voiceOther)
		}
	    }
	}
    }
}

proc ::Speech::SpeakWBText {who str} {
    variable sprefs
        
    set punct {[.,;?!]}
    if {$sprefs(speakWBText) && [string match *${punct}* $str] && ($str ne "")} {
	set key [string map {me Us other Other} $who]
	set voice $sprefs(voice$key)
	Speak $str $voice
    }
}

proc ::Speech::Speak {msg {voice {}}} {
    global  this
    
    switch -- $this(platform) {
	macosx {
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

proc ::Speech::SpeakGetVoices {} {
    global  this
    
    switch -- $this(platform) {
	macosx {
	    return [speech::speakers]
	}
	windows {
	    return [::MSSpeech::GetVoices]
	}
	unix {
	    return
	}
    }
}

# Preference page --------------------------------------------------------------

proc ::Speech::InitPrefsHook {} {
    
    variable sprefs
       
    ::Debug 2 "::Speech::InitPrefsHook sprefs(haveSpeech)=$sprefs(haveSpeech)"
    
    # Default in/out voices.
    set sprefs(voiceUs-macosx)     ""
    set sprefs(voiceOther-macosx)  ""
    set sprefs(voiceUs-windows)    ""
    set sprefs(voiceOther-windows) ""

    set sprefs(speakMsg)      0
    set sprefs(speakChat)     0
    set sprefs(speakWBText)   0

    ::PrefUtils::Add [list  \
      [list ::Speech::sprefs(speakMsg)    speakMsg        $sprefs(speakMsg)]    \
      [list ::Speech::sprefs(speakChat)   speakChat       $sprefs(speakChat)]   \
      [list ::Speech::sprefs(speakWBText) speakWBText     $sprefs(speakWBText)] \
      [list ::Speech::sprefs(voiceUs-macosx)     speakVoiceUs-macosx    $sprefs(voiceUs-macosx)]     \
      [list ::Speech::sprefs(voiceOther-macosx)  speakVoiceOther-macosx $sprefs(voiceOther-macosx)] \
      [list ::Speech::sprefs(voiceUs-windows)     speakVoiceUs-windows    $sprefs(voiceUs-windows)]     \
      [list ::Speech::sprefs(voiceOther-windows)  speakVoiceOther-windows $sprefs(voiceOther-windows)] \
      ]

    #
    Verify
}

proc ::Speech::BuildPrefsHook {wtree nbframe} {
    variable sprefs
    
    if {$sprefs(haveSpeech)} {
	::Preferences::NewTableItem {General {Speech}} [mc "Text-to-Speech"]

	set wpage [$nbframe page {Speech}]    
	BuildPrefsPage $wpage
    }
}

proc ::Speech::SavePrefsHook {} {
    variable sprefs
    variable tmpPrefs

    if {$sprefs(haveSpeech)} {
	array set sprefs [array get tmpPrefs]
	foreach {key value} [array get tmpPrefs] {
	    set sprefs($key) $tmpPrefs($key)
	}
	Verify
    }
}

proc ::Speech::CancelPrefsHook {} {
    variable sprefs
    variable tmpPrefs
    
    if {$sprefs(haveSpeech)} {

	# Detect any changes.
	foreach {key value} [array get tmpPrefs] {
	    if {![string equal $sprefs($key) $tmpPrefs($key)]} {
		::Preferences::HasChanged
		return
	    }
	}
    }
}

proc ::Speech::UserDefaultsPrefsHook {} {
    variable sprefs
    variable tmpPrefs
    
    array set tmpPrefs [array get sprefs]
}

proc ::Speech::BuildPrefsPage {page} {
    global  this
    variable sprefs
    variable tmpPrefs
        
    array set tmpPrefs [array get sprefs]
    set plat $this(platform)
    
    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    ttk::frame $wc.head -padding {0 0 0 6}
    ttk::label $wc.head.l -text [mc "Text-to-Speech"]
    ttk::separator $wc.head.s -orient horizontal

    grid  $wc.head.l  $wc.head.s
    grid $wc.head.s -sticky ew
    grid columnconfigure $wc.head 1 -weight 1
    pack  $wc.head  -side top -fill x

    set wfr $wc.f
    ttk::frame $wfr
    pack  $wfr  -side top
    
    ttk::checkbutton $wfr.speak     -text [mc prefsounsynwb2]  \
      -variable [namespace current]::tmpPrefs(speakWBText)
    ttk::checkbutton $wfr.speakmsg  -text [mc prefsounsynno2]  \
      -variable [namespace current]::tmpPrefs(speakMsg)
    ttk::checkbutton $wfr.speakchat -text [mc prefsounsynch2]  \
      -variable [namespace current]::tmpPrefs(speakChat)

    grid $wfr.speak      -sticky w
    grid $wfr.speakmsg   -sticky w
    grid $wfr.speakchat  -sticky w
    
    if {$sprefs(haveSpeech)} {
	
	# Get a list of voices
	set voicelist [concat None [SpeakGetVoices]]
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
    
    ttk::label $wfvo.in  -text "[mc prefsounvoin2]:"
    ttk::label $wfvo.out -text "[mc prefsounvoou2]:" 
    eval {ttk::optionmenu $wfvo.pin \
      [namespace current]::tmpPrefs(voiceOther-$plat)} $voicelist
    eval {ttk::optionmenu $wfvo.pout   \
      [namespace current]::tmpPrefs(voiceUs-$plat)} $voicelist
    
    grid  $wfvo.in   $wfvo.pin   -sticky e -padx 2 -pady 1
    grid  $wfvo.out  $wfvo.pout  -sticky e -padx 2 -pady 1
    grid  $wfvo.pin  $wfvo.pout  -sticky ew

    if {!$sprefs(haveSpeech)} {
	$wfvo.pin  state {disabled}
	$wfvo.pout state {disabled}
    }    
    
    bind $page <Destroy> +::Speech::Free
}

proc ::Speech::Free {} {
    variable tmpPrefs
    unset -nocomplain tmpPrefs
}

#-------------------------------------------------------------------------------
