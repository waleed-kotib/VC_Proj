#  MacintoshUtils.tcl ---
#  
#      This file is part of the whiteboard application. It implements things
#      that are mac only, like a glue to mac only packages.
#      
#  Copyright (c) 2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: MacintoshUtils.tcl,v 1.1.1.1 2002-12-08 11:03:26 matben Exp $

namespace eval ::Mac:: {

}

namespace eval ::Mac::Printer:: {

}

proc ::Mac::Printer::PageSetup { } {
        

}

# Synthetic Speech .............................................................

namespace eval ::Mac::Speech:: {

}

proc ::Mac::Speech::Init { } {
        
}

proc ::Mac::Speech::Speak {msg {theVoice {}}} {
        
    if {[string length $theVoice] == 0} {
	speak $msg
    } else {
	speak -voice $theVoice $msg
    }
}

proc ::Mac::Speech::GetVoices { } {

    return [speak -list]
}



