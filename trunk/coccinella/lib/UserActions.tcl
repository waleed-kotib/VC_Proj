#  UserActions.tcl ---
#  
#      This file is part of the whiteboard application. It implements typical
#      user actions, such as callbacks from buttons and menus.
#      
#  Copyright (c) 2000-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: UserActions.tcl,v 1.27 2003-12-22 15:04:58 matben Exp $

namespace eval ::UserActions:: {
    
}
    
# UserActions::DoPrintCanvas --
#
#       Platform independent printing of canvas.

proc ::UserActions::DoPrintCanvas {wtop} {
    global  this prefs wDlgs
        
    set wCan [::UI::GetCanvasFromWtop $wtop]
    
    switch -- $this(platform) {
	macintosh - macosx {
	    ::Mac::Printer::Print $wtop
	}
	windows {
	    if {!$prefs(printer)} {
		tk_messageBox -icon error -title [::msgcat::mc {No Printing}] \
		  -message [::msgcat::mc messprintnoextension]
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
	    tk_messageBox -icon error -title [::msgcat::mc {No Printing}] \
	      -message [::msgcat::mc messprintnoextension]
	}
	macosx {
	    ::Mac::MacCarbonPrint::PrintText $wtext
	}
	windows {
	    if {!$prefs(printer)} {
		tk_messageBox -icon error -title [::msgcat::mc {No Printing}] \
		  -message [::msgcat::mc messprintnoextension]
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
		tk_messageBox -icon error -title [::msgcat::mc {No Printing}] \
		  -message [::msgcat::mc messprintnoextension]
	    } else {
		::Windows::Printer::PageSetup
	    }
	}
	unix {
	    ::PSPageSetup::PSPageSetup .page
	}
    }
}

proc ::UserActions::Speak {msg {voice {}}} {
    global  this prefs
    
    switch -- $this(platform) {
	macintosh - macosx {
	    ::Mac::Speech::Speak $msg $voice
	}
	windows {
	    ::MSSpeech::Speak $msg $voice
	}
	unix - macosx {
	    # empty.
	}
    }
}

proc ::UserActions::SpeakGetVoices { } {
    global  this prefs
    
    switch -- $this(platform) {
	macintosh - macosx {
	    return [::Mac::Speech::GetVoices]
	}
	windows {
	    return [::MSSpeech::GetVoices]
	}
	unix - macosx {
	    return {}
	}
    }
}

# UserActions::DoConnect --
#
#       Protocol independent open connection to server.

proc ::UserActions::DoConnect { } {
    global  prefs
    
    if {[string equal $prefs(protocol) jabber]} {
	::Jabber::Login::Login
    } elseif {![string equal $prefs(protocol) server]} {
	::OpenConnection::OpenConnection $wDlgs(openConn)
    }
}

# UserActions::DoCloseWindow --
#
#       Typically called from the menu.
#       Take special actions before a window is closed.

proc ::UserActions::DoCloseWindow {{wevent {}}} {
    global  wDlgs
    
    set w [winfo toplevel [focus]]
    
    # If we bind to toplevel descriminate events coming from childrens.
    if {($wevent != "") && ($wevent != $w)} {
	return
    }
    if {$w == "."} {
	set wtop $w
    } else {
	set wtop ${w}.
    }
    Debug 2 "::UserActions::DoCloseWindow winfo class $w=[winfo class $w]"
    
    switch -- $w \
      $wDlgs(mainwb) {
	::WB::CloseWhiteboard $wtop
	return
    } \
      $wDlgs(jrostbro) {
	::UserActions::DoQuit -warning 1
	return
    }
    
    # Do different things depending on type of toplevel.
    switch -glob -- [winfo class $w] {
	Wish* - Whiteboard* - Coccinella* - Tclkit* {
	
	    # NOT ALWAYS CORRECT!!!!!!!
	    # Whiteboard window.
	    ::WB::CloseWhiteboard $wtop
	}
	Preferences {
	    ::Preferences::CancelPushBt
	}
	Chat {
	    ::Jabber::Chat::Close -toplevel $w
	}
	GroupChat {
	    ::Jabber::GroupChat::CloseToplevel $w
	}
	MailBox {
	    ::Jabber::MailBox::Show -visible 0
	}
	JMain {
	    ::UserActions::DoQuit -warning 1
	}
	default {
	    destroy $w
	}
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
	set ans [tk_messageBox -title [::msgcat::mc Quit?] -type yesno  \
	  -default yes -message [::msgcat::mc messdoquit?]]
	if {$ans == "no"} {
	    return $ans
	}
    }
    
    # Run all quit hooks.
    hooks::run quitAppHook
    
    # If we used 'Edit/Revert To/Application Defaults' be sure to reset...
    set prefs(firstLaunch) 0
            
    # Delete widgets with sounds.
    ::Sounds::Free
    ::Dialogs::Free
    
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
    ::Theme::SavePrefsFile
    
    # Should we clean up our 'incoming' directory?
    if {$prefs(clearCacheOnQuit)} {
	file delete -force -- $prefs(incomingPath)
	file mkdir $prefs(incomingPath)
    }
    
    # Cleanup. Beware, no windows with open movies must exist here!
    file delete -force $this(tmpPath)
    exit
}

#-------------------------------------------------------------------------------
