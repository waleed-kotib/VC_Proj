#  UserActions.tcl ---
#  
#      This file is part of The Coccinella application. It implements typical
#      user actions, such as callbacks from buttons and menus.
#      
#  Copyright (c) 2000-2005  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: UserActions.tcl,v 1.42 2005-02-02 15:21:22 matben Exp $

package provide UserActions 1.0

namespace eval ::UserActions:: {
    
}
    
# UserActions::DoPrintCanvas --
#
#       Platform independent printing of canvas.

proc ::UserActions::DoPrintCanvas {wtop} {
    global  this prefs wDlgs
        
    set wCan [::WB::GetCanvasFromWtop $wtop]
    
    switch -- $this(platform) {
	macintosh - macosx {
	    ::Mac::Printer::Print $wtop
	}
	windows {
	    if {!$prefs(printer)} {
		::UI::MessageBox -icon error -title [mc {No Printing}] \
		  -message [mc messprintnoextension]
	    } else {
		::Windows::Printer::Print $wCan
	    }
	}
	unix {
	    ::Dialogs::UnixPrintPS $wDlgs(print) $wCan
	}
    }
}

# UserActions::DoPrintText --
#
#

proc ::UserActions::DoPrintText {wtext args} {
    global  this prefs wDlgs
        
    if {[winfo class $wtext] != "Text"} {
	error "::UserActions::DoPrintText: $wtext not a text widget!"
    }
    switch -- $this(platform) {
	macintosh {
	    ::UI::MessageBox -icon error -title [mc {No Printing}] \
	      -message [mc messprintnoextension]
	}
	macosx {
	    ::Mac::MacCarbonPrint::PrintText $wtext
	}
	windows {
	    if {!$prefs(printer)} {
		::UI::MessageBox -icon error -title [mc {No Printing}] \
		  -message [mc messprintnoextension]
	    } else {
		::Windows::Printer::DoPrintText $wtext
	    }
	}
	unix {
	    ::Dialogs::UnixPrintPS $wDlgs(print) $wtext
	}
    }
}

proc ::UserActions::PageSetup {wtop} {
    global  this prefs wDlgs
    
    switch -- $this(platform) {
	macintosh {
	    ::Mac::MacPrint::PageSetup $wtop
	}
	macosx {
	    ::Mac::MacCarbonPrint::PageSetup $wtop
	}
	windows {
	    if {!$prefs(printer)} {
		::UI::MessageBox -icon error -title [mc {No Printing}] \
		  -message [mc messprintnoextension]
	    } else {
		::Windows::Printer::PageSetup
	    }
	}
	unix {
	    ::PSPageSetup::PSPageSetup .page
	}
    }
}

# UserActions::DoConnect --
#
#       Protocol independent open connection to server.

proc ::UserActions::DoConnect { } {
    global  prefs wDlgs
    
    if {[string equal $prefs(protocol) jabber]} {
	::Login::Dlg
    } elseif {![string equal $prefs(protocol) server]} {
	::P2PNet::OpenConnection $wDlgs(openConn)
    }
}

# UserActions::DoQuit ---
#
#       Is called just before quitting to be able to save various
#       preferences etc.
#       
# Arguments:
#       args        ?-warning boolean?
#       
# Results:
#       boolean, qid quit or not

proc ::UserActions::DoQuit {args} {
    global  prefs this
    
    array set argsArr {
	-warning      0
    }
    array set argsArr $args
    if {$argsArr(-warning)} {
	set ans [::UI::MessageBox -title [mc Quit?] -type yesno -icon warning \
	  -default yes -message [mc messdoquit?]]
	if {$ans == "no"} {
	    return $ans
	}
    }
    
    # Run all quit hooks.
    ::hooks::run quitAppHook
    
    # If we used 'Edit/Revert To/Application Defaults' be sure to reset...
    set prefs(firstLaunch) 0
    
    # Get dialog window geometries.
    set prefs(winGeom) {}
    foreach {key value} [array get prefs winGeom,*] {
	regexp {winGeom,(.*)$} $key match winkey
	lappend prefs(winGeom) $winkey $value
    }
    
    # Same for pane positions.
    set prefs(paneGeom) {}
    foreach {key value} [array get prefs paneGeom,*] {
	regexp {paneGeom,(.*)$} $key match winkey
	lappend prefs(paneGeom) $winkey $value
    }
         
    # Save to the preference file and quit...
    ::PreferencesUtils::SaveToFile
        
    # Cleanup. Beware, no windows with open movies must exist here!
    catch {file delete -force $this(tmpPath)}
    exit
}

#-------------------------------------------------------------------------------
