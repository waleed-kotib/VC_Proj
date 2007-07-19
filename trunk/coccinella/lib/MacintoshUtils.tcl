#  MacintoshUtils.tcl ---
#  
#      This file is part of The Coccinella application. It implements things
#      that are mac only, like a glue to mac only packages.
#      
#  Copyright (c) 2002  Mats Bengtsson
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
# $Id: MacintoshUtils.tcl,v 1.13 2007-07-19 06:28:18 matben Exp $

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

