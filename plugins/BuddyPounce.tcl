# BuddyPounce.tcl --
# 
#       Buddy pouncing...
#       This is just a first sketch.
#       
# $Id: BuddyPounce.tcl,v 1.2 2004-06-15 14:30:44 matben Exp $

namespace eval ::BuddyPounce:: {
    
}

proc ::BuddyPounce::Init { } {
    global  this

    set popMenuSpec \
      [list {Buddy Pouncing} user {::BuddyPounce::Build $jid}]
    
    # Add all hooks we need.
    ::hooks::add quitAppHook        ::BuddyPounce::QuitHook
    ::hooks::add newMessageHook     ::BuddyPounce::NewMsgHook
    ::hooks::add newChatMessageHook ::BuddyPounce::NewChatMsgHook
    ::hooks::add presenceHook       ::BuddyPounce::PresenceHook    
    ::hooks::add prefsInitHook      ::BuddyPounce::InitPrefsHook
    ::hooks::add closeWindowHook    ::BuddyPounce::CloseHook
    
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
    
    # These define which the events are.
    variable events
    set events(keys) {available unavailable msg                chat}
    set events(str)  {Online    Offline     {Incoming Message} {New Chat}}
    
    variable actions
    set actions(keys) {msgbox sound chat msg}
    
    # Keep prefs. jid must be mapped and with no resource!
    # The action keys correspond to option being on.
    #   budprefs(jid2) {event {list-of-action-keys} event {...} ...}
    variable budprefs
}

proc ::BuddyPounce::InitPrefsHook { } {
    
    variable budprefs
        
    ::PreferencesUtils::Add [list  \
      [list ::BuddyPounce::budprefs budprefs_array [::BuddyPounce::GetPrefsArr]]]    
}

proc ::BuddyPounce::GetPrefsArr { } {
    variable budprefs

    return [array get budprefs]
}

proc ::BuddyPounce::Build {jid} {    
    global  this prefs
    
    variable uid
    variable wdlg
    variable events
    variable audioSuffixes
    
    ::Debug 2 "::BuddyPounce::Build jid=$jid"

    # Initialize the state variable, an array, that keeps is the storage.
    
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
    
    set w ${wdlg}${uid}
    
    set jid [jlib::jidmap $jid]
    jlib::splitjid $jid jid2 res
    set state(w)    $w
    set state(jid)  $jid
    set state(jid2) $jid2
    
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
      -text "Set a specific action when something happens with \"$jid\",\
      which can be a changed status, or if you receive a message etc."
    pack $w.frall.msg -side top -anchor w
    
    pack [frame $w.frall.fr -bg red] -padx 4 -pady 2
    set wfr $w.frall.fr.f
    frame $wfr
    pack  $wfr -padx 1 -pady 1
    
    # Header labels.
    label $wfr.lonline -text [::msgcat::mc {Event Type}]
    label $wfr.lact    -text [::msgcat::mc {Perform Action}]
    grid  $wfr.lonline $wfr.lact -sticky w -padx 6 -pady 2
    
    set i 0
    foreach eventStr $events(str) key $events(keys) {
	set wdiv $wfr.div[incr i]
	frame $wdiv -height 1 -bg red
	
	# Event.
	label $wfr.$key -text " [::msgcat::mc $eventStr]"
	
	# Action
	set wact $wfr.fact${key}
	frame $wact -bg gray70
	checkbutton $wact.alrt -text " [::msgcat::mc {Show Popup}]" \
	  -variable $token\($key,msgbox)
	
	checkbutton $wact.lsound -text " [::msgcat::mc {Play Sound}]:" \
	  -variable $token\($key,sound)
	set wmenu [eval {
	    tk_optionMenu $wact.msound $token\($key,soundfile)
	} $allSounds]
	$wmenu configure -font $fontS
	
	checkbutton $wact.chat -text " [::msgcat::mc {Start Chat}]" \
	  -variable $token\($key,chat)
	checkbutton $wact.msg -text " [::msgcat::mc {Send Message}]" \
	  -variable $token\($key,msg)
	
	grid $wact.alrt $wact.lsound $wact.msound -sticky w -padx 4 -pady 1
	grid $wact.chat $wact.msg    -            -sticky w -padx 4 -pady 1
	
	grid $wdiv     -     -sticky ew
	grid $wfr.$key $wact -padx 1 -pady 2 -sticky nw
	grid $wact -sticky w
	
	if {[llength audioSuffixes] == 0} {
	    $wact.lsound configure -state disabled
	    $wact.msound configure -state disabled
	}
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


    set nwin [llength [::UI::GetPrefixedToplevels $wdlg]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wdlg
    }
    wm title $w "[::msgcat::mc {Buddy Pouncing}]: $jid"
    wm resizable $w 0 0
    
    ::BuddyPounce::AllOff $token
    ::BuddyPounce::PrefsToState $token

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
    variable budprefs
    
    set jid $state(jid2)
    if {[info exists budprefs($jid)]} {
	foreach {ekey actlist} $budprefs($jid) {
	    foreach akey $actlist {
		set state($ekey,$akey) 1
		if {[string match "soundfile:*" $akey]} {
		    set state($ekey,soundfile)  \
		      [string map {soundfile: ""} $akey]
		}
	    }
	}
    }
}

proc ::BuddyPounce::StateToPrefs {token} {
    variable $token
    upvar 0 $token state
    variable budprefs
    variable events
    variable actions
    
    set jid $state(jid2)
    set jidprefs {}
    foreach ekey $events(keys) {
	set actlist {}
	foreach akey $actions(keys) {
	    if {$state($ekey,$akey) == 1} {
		lappend actlist $akey
		if {[string equal $akey "sound"]} {
		    lappend actlist soundfile:$state($ekey,soundfile)
		}
	    }
	}
	if {[llength $actlist]} {
	    lappend jidprefs $ekey $actlist
	}
    }
    if {[llength $jidprefs]} {
	set budprefs($jid) $jidprefs
    }
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
    variable events

    foreach ekey $events(keys) {
	foreach name [array names state $ekey,*] {
	    if {![string equal $ekey,soundfile $name]} {
		set state($name) 0
	    }
	}
    }
}

proc ::BuddyPounce::OK {token} {
    variable $token
    upvar 0 $token state
    variable budprefs
    
    ::BuddyPounce::StateToPrefs $token
    destroy $state(w)
    unset state
}


proc ::BuddyPounce::Cancel {token} {
    variable $token
    upvar 0 $token state

    destroy $state(w)
    unset state
}

proc ::BuddyPounce::Event {from eventkey} {
    variable budprefs

    set jid [jlib::jidmap $from]
    if {[info exists budprefs($jid)]} {
	array set prefsArr $budprefs($jid)
	if {[info exists prefsArr($eventkey)]} {
	    foreach action $prefsArr($eventkey) {
		
		switch -- $action {
		    msgbox {
			tk_messageBox -icon info -message \
			  "The user \"$jid\" just went online!"
		    }
		    sound {
			
		    }
		    chat {
			::Jabber::Chat::StartThread $from
		    }
		    msg {
			::Jabber::NewMsg::Build -to $from
		    }
		}
	    }
	}
    }
}

proc ::BuddyPounce::QuitHook { } {
    variable wdlg
    
    ::UI::SaveWinPrefixGeom $wdlg
}

proc ::BuddyPounce::CloseHook {wclose} {
    variable wdlg
    
    if {[string match $wdlg* $wclose]} {
	::UI::SaveWinGeom $wdlg $wclose
    }   
    return ""
}

proc ::BuddyPounce::NewChatMsgHook {body args} {

    array set argsArr $args
    if {[info exists argsArr(-from)]} {
	::BuddyPounce::Event $argsArr(-from) chat
    }
}

proc ::BuddyPounce::NewMsgHook {body args} {
    
}

proc ::BuddyPounce::PresenceHook {jid type args} {
    
    ::Debug 4 "::BuddyPounce::PresenceHook jid=$jid, type=$type"
    
    ::BuddyPounce::Event $jid $type
}

proc ::GetOptionMenuMaxWidth {w} {
    
    set wmenu [lindex [winfo children $w] 0]
    
    set wtmp .__mbhy634
    menubutton $wtmp -text
    
}


#-------------------------------------------------------------------------------
