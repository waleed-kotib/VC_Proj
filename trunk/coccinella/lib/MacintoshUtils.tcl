#  MacintoshUtils.tcl ---
#  
#      This file is part of The Coccinella application. It implements things
#      that are mac only, like a glue to mac only packages.
#      
#  Copyright (c) 2002  Mats Bengtsson
#  
# $Id: MacintoshUtils.tcl,v 1.12 2005-08-14 07:17:55 matben Exp $

package provide MacintoshUtils 1.0

namespace eval ::Mac:: {

}

namespace eval ::Mac::Printer:: {

}

proc ::Mac::Printer::PageSetup {w} {
    global  prefs this
        
    switch -- $this(platform) {
	macintosh {
	    ::Mac::MacPrint::PageSetup $w
	}
	macosx {
	    ::Mac::MacCarbonPrint::PageSetup $w
	}
    }
}

proc ::Mac::Printer::Print {w} {
    global  prefs this

    switch -- $this(platform) {
	macintosh {
	    ::Mac::MacPrint::PrintCanvas $w
	}
	macosx {
	    ::Mac::MacCarbonPrint::PrintCanvas $w
	}
    }
}

#-- Mac Classic ----------------------------------------------------------------

namespace eval ::Mac::MacPrint:: {
    
}

proc ::Mac::MacPrint::PageSetup {w} {
    global  prefs
    variable cache
    
    if {$prefs(MacPrint)} {
	set printObj [::macprint::pagesetup]
	if {$printObj ne ""} {
	    set cache($w,printObj) $printObj
	}
    } else {
	::UI::MessageBox -icon error -title [mc {No Printing}] \
	  -message [mc messprintnoextension]
    }	    
}
    
proc ::Mac::MacPrint::PrintCanvas {w} {
    global  prefs
    variable cache
    
    set wcan [::WB::GetCanvasFromWtop $w]

    if {$prefs(MacPrint)} {
	set ans [macprint::print]
	if {$ans ne ""} {
	    foreach {type printObject} $ans break
	    set opts {}
	    if {[info exists cache($w,printObj)]} {
		lappend opts -printobject $cache($w,printObj)
	    }
	    eval {macprint::printcanvas $wcan $printObject} $opts
	}
    } else {
	::UI::MessageBox -icon error -title [mc {No Printing}] \
	  -message [mc messprintnoextension]
    }	    
}

#-- Mac OS X -------------------------------------------------------------------

namespace eval ::Mac::MacCarbonPrint:: {
    
}

proc ::Mac::MacCarbonPrint::PageSetup {w} {
    global  prefs this
    variable cache
        
    if {$this(package,MacCarbonPrint)} {
	set pageFormat [maccarbonprint::pagesetup -parent $w]
	if {$pageFormat ne ""} {
	    set cache($w,pageFormat) $pageFormat
	}
    } else {
	::UI::MessageBox -icon error -title [mc {No Printing}] \
	  -message [mc messprintnoextension]
    }
}

proc ::Mac::MacCarbonPrint::PrintCanvas {w} {
    global  prefs this
    variable cache

    set wcan [::WB::GetCanvasFromWtop $w]

    if {$this(package,MacCarbonPrint)} {
	set opts [list -parent $w]
	if {[info exists cache($w,pageFormat)]} {
	    lappend opts -pageformat $cache($w,pageFormat)
	}
	set ans [eval {maccarbonprint::print} $opts]
	if {$ans ne ""} {
	    foreach {type printObject} $ans break
	    eval {maccarbonprint::printcanvas $wcan $printObject}
	}
    } else {
	::UI::MessageBox -icon error -title [mc {No Printing}] \
	  -message [mc messprintnoextension]
    }	    
}

proc ::Mac::MacCarbonPrint::PrintText {wtext args} {
    global  prefs this
    variable cache
    
    set w [winfo toplevel $wtext]

    if {$this(package,MacCarbonPrint)} {
	set opts [list -parent $w]
	if {[info exists cache($w,pageFormat)]} {
	    lappend opts -pageformat $cache($w,pageFormat)
	}
	set ans [eval {maccarbonprint::print} $opts]
	if {$ans ne ""} {
	    foreach {type printObject} $ans break
	    eval {maccarbonprint::printtext $wtext $printObject} $args
	}
    } else {
	::UI::MessageBox -icon error -title [mc {No Printing}] \
	  -message [mc messprintnoextension]
    }	    
}

proc ::Mac::OpenUrl {url} {
    global  this
    
    if {$this(package,Tclapplescript)} {
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
        
    if {$theVoice eq ""} {
	speech::speak $msg
    } else {
	speech::speak $msg -voice $theVoice
    }
}

proc ::Mac::Speech::GetVoices { } {

    return [speech::speakers]
}

#-------------------------------------------------------------------------------

