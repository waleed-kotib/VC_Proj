#  Speech.tcl ---
#  
#      Implements platform independent synthetic speech.
#      
#  Copyright (c) 2003  Mats Bengtsson
#  
# $Id

package provide Speech 1.0

namespace eval ::Speech:: {
    
    # Hooks to run when message displayed to user.
    hooks::add displayMessageHook          [list ::Speech::SpeakMessage normal]
    hooks::add displayChatMessageHook      [list ::Speech::SpeakMessage chat]
    hooks::add displayGroupChatMessageHook [list ::Speech::SpeakMessage groupchat]
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
		set txt " "
		if {[info exists argsArr(-subject)] && \
		  ($argsArr(-subject) != "")} {
		    append txt "Subject is $argsArr(-subject). "
		}
		append txt $body
		::Speech::Speak $txt $prefs(voiceOther)
	    }
	}
	chat {
	    if {$jprefs(speakChat)} {
		set myjid [::Jabber::GetMyJid]
		jlib::splitjid $myjid jid2 res
		if {[string match ${jid2}* $from]} {
		    set voice $prefs(voiceUs)
		    set txt "I say, "
		} else {
		    set voice $prefs(voiceOther)
		    set txt " , "
		}
		append txt $body
		::Speech::Speak $txt $voice
	    }
	}
	groupchat {
	    if {$jprefs(speakChat)} {
		jlib::splitjid $from roomjid res
		set myjid [::Jabber::GetMyJid $roomjid]
		if {[string equal $myjid $from]} {
		    ::Speech::Speak $body $prefs(voiceUs)
		} else {
		    ::Speech::Speak $body $prefs(voiceOther)
		}
	    }
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
