#  MacintoshUtils.tcl ---
#  
#      This file is part of The Coccinella application. It implements things
#      that are mac only, like a glue to mac only packages.
#      
#  Copyright (c) 2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: MacintoshUtils.tcl,v 1.10 2004-07-09 06:26:06 matben Exp $

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
	    ::Mac::MacCarbonPrint::PrintCanvas $wtop
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
	tk_messageBox -icon error -title [mc {No Printing}] \
	  -message [mc messprintnoextension]
    }	    
}
    
proc ::Mac::MacPrint::PrintCanvas {wtop} {
    global  prefs
    variable cache
    
    set wCan [::WB::GetCanvasFromWtop $wtop]

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
	tk_messageBox -icon error -title [mc {No Printing}] \
	  -message [mc messprintnoextension]
    }	    
}

#-- Mac OS X -------------------------------------------------------------------

namespace eval ::Mac::MacCarbonPrint:: {
    
}

proc ::Mac::MacCarbonPrint::PageSetup {wtop} {
    global  prefs
    variable cache
    
    if {$wtop == "."} {
	set wparent .
    } else {
	set wparent [string trimright $wtop .]
    }
    
    if {$prefs(MacCarbonPrint)} {
	set pageFormat [maccarbonprint::pagesetup -parent $wparent]
	if {$pageFormat != ""} {
	    set cache($wtop,pageFormat) $pageFormat
	}
    } else {
	tk_messageBox -icon error -title [mc {No Printing}] \
	  -message [mc messprintnoextension]
    }
}

proc ::Mac::MacCarbonPrint::PrintCanvas {wtop} {
    global  prefs
    variable cache

    set wCan [::WB::GetCanvasFromWtop $wtop]

    if {$prefs(MacCarbonPrint)} {
	set opts [list -parent [winfo toplevel $wCan]]
	if {[info exists cache($wtop,pageFormat)]} {
	    lappend opts -pageformat $cache($wtop,pageFormat)
	}
	set ans [eval {maccarbonprint::print} $opts]
	if {$ans != ""} {
	    foreach {type printObject} $ans break
	    eval {maccarbonprint::printcanvas $wCan $printObject}
	}
    } else {
	tk_messageBox -icon error -title [mc {No Printing}] \
	  -message [mc messprintnoextension]
    }	    
}

proc ::Mac::MacCarbonPrint::PrintText {wtext args} {
    global  prefs
    variable cache
    
    set wintop [winfo toplevel $wtext]
    if {$wintop == "."} {
	set wtop .
    } else {
	set wtop ${wintop}.
    }

    if {$prefs(MacCarbonPrint)} {
	set opts [list -parent $wintop]
	if {[info exists cache($wtop,pageFormat)]} {
	    lappend opts -pageformat $cache($wtop,pageFormat)
	}
	set ans [eval {maccarbonprint::print} $opts]
	if {$ans != ""} {
	    foreach {type printObject} $ans break
	    eval {maccarbonprint::printtext $wtext $printObject} $args
	}
    } else {
	tk_messageBox -icon error -title [mc {No Printing}] \
	  -message [mc messprintnoextension]
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

