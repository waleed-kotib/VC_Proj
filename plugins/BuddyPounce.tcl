# BuddyPounce.tcl --
# 
#       Buddy pouncing...
#       This is just a first sketch.
#       
# $Id: BuddyPounce.tcl,v 1.1 2004-06-14 14:31:24 matben Exp $

namespace eval ::BuddyPounce:: {
    
}

proc ::BuddyPounce::Init { } {
    global  this

    set popMenuSpec \
      [list {Buddy Pouncing} user {::BuddyPounce::Build $jid}]
    
    # Add all hooks we need.
    ::hooks::add presenceHook       ::BuddyPounce::PresenceHook
    
    
    # Register popmenu entry.
    ::Jabber::UI::RegisterPopupEntry roster $popMenuSpec
    
    component::register BuddyPounce  \
      "Buddy pouncing enables you to make various things happen when\
      a particular user becomes online, offline etc."
    
    # Audio formats.
    variable audioSuffixes {}
    
    switch -- $this(platform) {
	macosx - macintosh {
	    if {![catch {package require QuickTimeTcl}]} {
		lappend audioSuffixes .aif .aiff .wav .mp3
	    }
	}
	windows {
	    if {![catch {package require QuickTimeTcl}]} {
		lappend audioSuffixes .aif .aiff .wav .mp3
	    }
	    if {![catch {package require snack}]} {
		lappend audioSuffixes .aif .aiff .wav .mp3
	    }	    
	}
	default {
	    if {![catch {package require snack}]} {
		lappend audioSuffixes .aif .aiff .wav .mp3
	    }	    
	}
    }
    set audioSuffixes [lsort -unique $audioSuffixes]
    
    variable uid 0
    variable wdlg .budpounce
    
    # Keep prefs.
    variable budprefs
}

proc ::BuddyPounce::Build {jid} {    
    global  this prefs
    
    variable uid
    variable wdlg
    
    ::Debug 2 "::BuddyPounce::Build jid=$jid"

    # Initialize the state variable, an array, that keeps is the storage.
    
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
    
    set w ${wdlg}${uid}
    
    set state(w)   $w
    set state(jid) $jid
    
    # Get all sounds.
    set allSounds [::BuddyPounce::GetAllSounds]
    set fontS  [option get . fontSmall {}]
    
    # Toplevel with class BuddyPounce.
    ::UI::Toplevel $w -class BuddyPounce -usemacmainmenu 1 -macstyle documentProc

    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 4

    ::headlabel::headlabel $w.frall.head -text [::msgcat::mc {Buddy Pouncing}]
    pack $w.frall.head -side top -fill both -expand 1
    label $w.frall.msg -wraplength 300 -justify left -padx 10 -pady 2 \
      -text "Set a specific action something happens with \"$jid\",\
      which can be when it changes its status, or if you receive a message etc."
    pack $w.frall.msg -side top -anchor w
    

    set wfr $w.frall.fr
    frame $wfr -bg gray50
    pack  $wfr -padx 4 -pady 2
    
    # Header labels.
    label $wfr.lonline -text [::msgcat::mc {Event Type}]
    label $wfr.lact    -text [::msgcat::mc {Perform Action}]
    grid  $wfr.lonline -column 0 -row 0 -sticky w -padx 6 -pady 2
    grid  $wfr.lact    -column 1 -row 0 -sticky w -padx 6 -pady 2
    
    set row 1
    foreach eventStr {Online Offline {Incoming Message} {New Chat}} \
      key {online offline msg chat} {
    
	# Event.
	label $wfr.$key -text " [::msgcat::mc $eventStr]"
	
	# Action
	set wact $wfr.fact${key}
	frame $wact -bg gray70
	checkbutton $wact.alrt -text " [::msgcat::mc {Show Popup}]" \
	  -variable $token\($key,msgbox)
	
	frame $wact.sound
	checkbutton $wact.sound.l -text " [::msgcat::mc {Play Sound}]:" \
	  -variable $token\($key,sound)
	set wmenu [eval {
	    tk_optionMenu $wact.sound.m $token\($key,soundfile)
	} $allSounds]
	$wmenu configure -font $fontS
	grid $wact.sound.l $wact.sound.m
	
	checkbutton $wact.chat -text " [::msgcat::mc {Start Chat}]" \
	  -variable $token\($key,chat)
	checkbutton $wact.msg -text " [::msgcat::mc {Send Message}]" \
	  -variable $token\($key,msg)
	
	grid $wact.alrt $wact.sound -sticky w -padx 4 -pady 1
	grid $wact.chat $wact.msg   -sticky w -padx 4 -pady 1
	
	grid $wfr.$key -column 0 -row $row -padx 1 -pady 2 -sticky nw
	grid $wact     -column 1 -row $row -padx 1 -pady 2 -sticky w
	incr row
    }
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [::msgcat::mc OK] \
      -default active -command [list [namespace current]::OK $token]] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel]  \
      -command [list [namespace current]::Cancel $token]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btoff -text [::msgcat::mc {All Off}]  \
      -command [list [namespace current]::AllOff $token]]  \
      -side left -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6


    wm title $w [::msgcat::mc {Buddy Pouncing}]
    wm resizable $w 0 0

    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $w.frall.msg $w]    
    after idle $script

    return $token
}

proc ::BuddyPounce::PrefsToState {token} {
    variable $token
    upvar 0 $token state
    
    set jid $state(jid)
    
    
}

proc ::BuddyPounce::GetAllSounds {} {
    global  this
    variable audioSuffixes
    
    set all {}
    foreach f [glob -nocomplain -directory $this(soundsPath) *] {
	if {[lsearch $audioSuffixes [file extension $f]] >= 0} {
	    lappend all [file tail $f]
	}
    }     
    return $all
}

proc ::BuddyPounce::AllOff {token} {
    variable $token
    upvar 0 $token state

    
}

proc ::BuddyPounce::OK {token} {
    variable $token
    upvar 0 $token state
    variable budprefs
    
    
    destroy $state(w)
    unset state
}


proc ::BuddyPounce::Cancel {token} {
    variable $token
    upvar 0 $token state

    destroy $state(w)
    unset state
}

proc ::BuddyPounce::PresenceHook {jid type args} {
    
    ::Debug 4 "::BuddyPounce::PresenceHook"
    
    
}

#-------------------------------------------------------------------------------
