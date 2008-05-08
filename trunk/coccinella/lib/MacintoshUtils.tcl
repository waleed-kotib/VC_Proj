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
# $Id: MacintoshUtils.tcl,v 1.15 2008-05-08 12:24:01 matben Exp $

package provide MacintoshUtils 1.0

namespace eval ::Mac:: {

}

namespace eval ::Mac::Printer:: {

}

proc ::Mac::Printer::PageSetup {w} {
    ::Mac::MacCarbonPrint::PageSetup $w
}

proc ::Mac::Printer::Print {w} {
    ::Mac::MacCarbonPrint::PrintCanvas $w
}

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
	::UI::MessageBox -icon error -title [mc Error] \
	  -message [mc messprintnoextension2]
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
	    lassign $ans type printObject
	    eval {maccarbonprint::printcanvas $wcan $printObject}
	}
    } else {
	::UI::MessageBox -icon error -title [mc Error] \
	  -message [mc messprintnoextension2]
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
	    lassign $ans type printObject
	    eval {maccarbonprint::easytextprint $wtext $printObject} $args
	}
    } else {
	::UI::MessageBox -icon error -title [mc Error] \
	  -message [mc messprintnoextension2]
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

