#  Speech.tcl ---
#  
#      Implements platform independent synthetic speech.
#      
#  Copyright (c) 2003  Mats Bengtsson
#  
# $Id

package provide Speech 1.0

namespace eval ::Speech:: {
    
    
    hooks::add displayMessageHook        [list ::Speech::SpeakMessage normal]
    hooks::add displayChatMessageHook    [list ::Speech::SpeakMessage chat]
    
}

proc ::Speech::SpeakMessage {type body args} {
    global  prefs
    # BAD!!!!!!!
    upvar ::Jabber::jprefs jprefs
    
    array set argsArr $args
    set from ""
    if {[info exists argsArr(-from)]} {
	set from $argsArr(-from)
    }
    
    switch -- $type {
	normal {
	    if {$jprefs(speakMsg)} {
		::Speech::Speak $body $prefs(voiceOther)
	    }
	}
	chat {
	    if {$jprefs(speakChat)} {
		set myjid [::Jabber::GetMyJid]
		jlib::splitjid $myjid jid2 res
		if {[string match ${jid2}* $from]} {
		    set voice $prefs(voiceUs)
		} else {
		    set voice $prefs(voiceOther)
		}
		::Speech::Speak $body $voice
	    }
	}
	groupchat {
	    
	}
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

#-------------------------------------------------------------------------------
