#  MacintoshUtils.tcl ---
#  
#      This file is part of the whiteboard application. It implements things
#      that are mac only, like a glue to mac only packages.
#      
#  Copyright (c) 2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: MacintoshUtils.tcl,v 1.2 2003-02-24 17:52:11 matben Exp $

namespace eval ::Mac:: {

}

namespace eval ::Mac::Printer:: {

}

proc ::Mac::Printer::PageSetup { } {
        

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



