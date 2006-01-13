#  UserActions.tcl ---
#  
#      This file is part of The Coccinella application. It implements typical
#      user actions, such as callbacks from buttons and menus.
#      
#  Copyright (c) 2000-2005  Mats Bengtsson
#  
# $Id: UserActions.tcl,v 1.45 2006-01-13 13:23:12 matben Exp $

package provide UserActions 1.0

namespace eval ::UserActions:: {
    
}
    
# UserActions::DoPrintCanvas --
#
#       Platform independent printing of canvas.

proc ::UserActions::DoPrintCanvas {w} {
    global  this prefs wDlgs
        
    set wcan [::WB::GetCanvasFromWtop $w]
    
    switch -- $this(platform) {
	macosx {
	    ::Mac::Printer::Print $w
	}
	windows {
	    if {!$this(package,printer)} {
		::UI::MessageBox -icon error -title [mc {No Printing}] \
		  -message [mc messprintnoextension]
	    } else {
		::Windows::Printer::Print $wcan
	    }
	}
	unix {
	    ::Dialogs::UnixPrintPS $wDlgs(print) $wcan
	}
    }
}

# UserActions::DoPrintText --
#
#

proc ::UserActions::DoPrintText {wtext args} {
    global  this prefs wDlgs
        
    if {[winfo class $wtext] ne "Text"} {
	error "::UserActions::DoPrintText: $wtext not a text widget!"
    }
    switch -- $this(platform) {
	macosx {
	    ::Mac::MacCarbonPrint::PrintText $wtext
	}
	windows {
	    if {!$this(package,printer)} {
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

proc ::UserActions::PageSetup {w} {
    global  this prefs wDlgs
    
    switch -- $this(platform) {
	macosx {
	    ::Mac::MacCarbonPrint::PageSetup $w
	}
	windows {
	    if {!$this(package,printer)} {
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
#       0 if not quited, else exitted

proc ::UserActions::DoQuit {args} {
    global  prefs this
    
    array set argsArr {
	-warning      0
    }
    array set argsArr $args
    if {$argsArr(-warning)} {
	set ans [::UI::MessageBox -title [mc Quit?] -type yesno -icon warning \
	  -default yes -message [mc messdoquit?]]
	if {$ans eq "no"} {
	    return 0
	}
    }
    
    # Run all quit hooks. 
    # Give components a chance to act before session ends.
    ::hooks::run preQuitAppHook
    
    # Here we end the session if any.
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
    set prefs(sashPos) {}
    foreach {key value} [array get prefs sashPos,*] {
	regexp {sashPos,(.*)$} $key match winkey
	lappend prefs(sashPos) $winkey $value
    }
         
    # Save to the preference file and quit...
    ::PrefUtils::SaveToFile
        
    # Cleanup. Beware, no windows with open movies must exist here!
    catch {file delete -force $this(tmpPath)}
    exit
}

#-------------------------------------------------------------------------------
