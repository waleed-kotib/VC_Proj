#  MacintoshUtils.tcl ---
#  
#      This file is part of the whiteboard application. It implements things
#      that are mac only, like a glue to mac only packages.
#      
#  Copyright (c) 2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: MacintoshUtils.tcl,v 1.3 2003-07-26 13:54:23 matben Exp $

namespace eval ::Mac:: {

}

namespace eval ::Mac::Printer:: {

}

proc ::Mac::Printer::PageSetup { } {
        

}

proc ::Mac::OpenUrl {url} {
    global  prefs
    
    if {$prefs(Tclapplescript)} {
	set script {
	    tell application "Netscape Communicatorª"
	    open(file "%s")
	    Activate -1
	    end tell
	}
	AppleScript execute [format $script $url]
    }
}

# Synthetic Speech .............................................................
# Important: version 2.0 only

namespace eval ::Mac::Speech:: {

}

proc ::Mac::Speech::Init { } {
        
}

proc ::Mac::Speech::Speak {msg {theVoice {}}} {
        
    if {$theVoice == ""} {
	speech::speak $msg
    } else {
	speech::speak $msg -voice $theVoice
    }
}

proc ::Mac::Speech::GetVoices { } {

    return [speech::speakers]
}



