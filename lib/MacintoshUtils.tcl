#  MacintoshUtils.tcl ---
#  
#      This file is part of the whiteboard application. It implements things
#      that are mac only, like a glue to mac only packages.
#      
#  Copyright (c) 2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: MacintoshUtils.tcl,v 1.5 2003-10-12 13:12:55 matben Exp $

#package require TclSpeech 2.0
#package require Tclapplescript

namespace eval ::Mac:: {

}

namespace eval ::Mac::Printer:: {

}

proc ::Mac::Printer::PageSetup {wtop} {
    global  prefs this
        
    switch -- $this(platform) {
	macintosh {
	    ::Mac::MacPrint::PageSetup $wtop
	}
	macosx {
	    ::Mac::MacCarbonPrint::PageSetup $wtop
	}
    }
}

proc ::Mac::Printer::Print {wtop} {
    global  prefs this

    switch -- $this(platform) {
	macintosh {
	    ::Mac::MacPrint::PrintCanvas $wtop
	}
	macosx {

	}
    }
}

#-- Mac Classic ----------------------------------------------------------------

namespace eval ::Mac::MacPrint:: {
    
}

proc ::Mac::MacPrint::PageSetup {wtop} {
    global  prefs
    variable cache
    
    if {$prefs(MacPrint)} {
	set printObj [::macprint::pagesetup]
	if {$printObj != ""} {
	    set cache($wtop,printObj) $printObj
	}
    } else {
	tk_messageBox -icon error -title [::msgcat::mc {No Printing}] \
	  -message [::msgcat::mc messprintnoextension]
    }	    
}
    
proc ::Mac::MacPrint::PrintCanvas {wtop} {
    global  prefs
    variable cache
    
    set wCan [::UI::GetCanvasFromWtop $wtop]

    if {$prefs(MacPrint)} {
	set ans [macprint::print]
	if {$ans != ""} {
	    foreach {type printObject} $ans break
	    set opts {}
	    if {[info exists cache($wtop,printObj)]} {
		lappend opts -printobject $cache($wtop,printObj)
	    }
	    eval {macprint::printcanvas $wCan $printObject} $opts
	}
    } else {
	tk_messageBox -icon error -title [::msgcat::mc {No Printing}] \
	  -message [::msgcat::mc messprintnoextension]
    }	    
}

#-- Mac OS X -------------------------------------------------------------------

namespace eval ::Mac::MacCarbonPrint:: {
    
}

proc ::Mac::MacCarbonPrint::PageSetup {wtop} {
    global  prefs
    variable cache
    
    if {$prefs(MacCarbonPrint)} {
	set pageFormat [maccarbonprint::pagesetup]
	if {$pageFormat != ""} {
	    set cache($wtop,pageFormat) $pageFormat
	}
    } else {
	tk_messageBox -icon error -title [::msgcat::mc {No Printing}] \
	  -message [::msgcat::mc messprintnoextension]
    }
}

proc ::Mac::MacCarbonPrint::PrintCanvas {wtop} {
    global  prefs
    variable cache

    set wCan [::UI::GetCanvasFromWtop $wtop]

    if {$prefs(MacCarbonPrint)} {
	set ans [maccarbonprint::print -parent [winfo toplevel $wCan]]
	if {$ans != ""} {
	    foreach {type printObject} $ans break
	    set opts {}
	    if {[info exists cache($wtop,pageFormat)]} {
		lappend opts -pageformat $cache($wtop,pageFormat)
	    }
	    eval {maccarbonprint::printcanvas $wCan $printObject} $opts
	}
    } else {
	tk_messageBox -icon error -title [::msgcat::mc {No Printing}] \
	  -message [::msgcat::mc messprintnoextension]
    }	    
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

#-------------------------------------------------------------------------------

