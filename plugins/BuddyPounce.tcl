# BuddyPounce.tcl --
# 
#       Buddy pouncing...
#       This is just a first sketch.
#       TODO: all message translations.
#       
# $Id: BuddyPounce.tcl,v 1.7 2004-07-09 06:26:06 matben Exp $

namespace eval ::BuddyPounce:: {
    
}

proc ::BuddyPounce::Init { } {
    global  this
    
    ::Debug 2 "::BuddyPounce::Init"

    set popMenuSpec \
      [list {Buddy Pouncing} user {::BuddyPounce::Build $jid}]
    
    # Add all hooks we need.
    ::hooks::add quitAppHook              ::BuddyPounce::QuitHook
    ::hooks::add newMessageHook           ::BuddyPounce::NewMsgHook
    ::hooks::add newChatMessageHook       ::BuddyPounce::NewChatMsgHook
    ::hooks::add presenceUnavailableHook  ::BuddyPounce::PresenceUnavailableHook    
    ::hooks::add presenceDelayHook        ::BuddyPounce::PresenceHook    
    ::hooks::add prefsInitHook            ::BuddyPounce::InitPrefsHook
    ::hooks::add closeWindowHook          ::BuddyPounce::CloseHook
    
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
    # This doesn't work due to the order of which things are loaded.
    if {0} {
	foreach subtype {aiff aiff wav mpeg} suff {.aif .aiff .wav .mp3} {
	    if {[::Plugins::HaveImporterForMime audio/$subtype]} {
		lappend audioSuffixes $suff
	    }
	}
    }
    
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
    
    variable alertStr
    array set alertStr {
	available   {The user "%s" just went online!}
	unavailable {The user "%s" just went offline!}
	msg         {The user "%s" just sent you a message!}
	chat        {The user "%s" just started a chat!}
    }
    
    variable alertTitle 
    array set alertTitle {
	available   {Online!}
	unavailable {Offline!}
	msg         {New message!}
	chat        {New chat!}
    }
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
    set fontS      [option get . fontSmall {}]
    set contrastBg [option get . backgroundLightContrast {}]
    set maxlen 0
    set maxstr ""
    foreach f $allSounds {
	set len [string length $f]
	if {$len > $maxlen} {
	    set maxlen $len
	    set maxstr $f
	}
    }
    
    # Toplevel with class BuddyPounce.
    ::UI::Toplevel $w -class BuddyPounce -usemacmainmenu 1 -macstyle documentProc

    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 4

    ::headlabel::headlabel $w.frall.head -text [mc {Buddy Pouncing}]
    pack $w.frall.head -side top -fill both -expand 1
    label $w.frall.msg -wraplength 300 -justify left -padx 10 -pady 2 \
      -text "Set a specific action when something happens with \"$jid\",\
      which can be a changed status, or if you receive a message etc.\
      Pick events using the tabs."
    pack $w.frall.msg -side top -anchor w
    
    frame $w.frall.fr -bg $contrastBg -bd 0
    pack  $w.frall.fr -padx 6 -pady 4
    
    set wnb $w.frall.fr.nb
    ::mactabnotebook::mactabnotebook $wnb
    pack $wnb -padx 1 -pady 1
        
    # Fake menubutton to compute max width.
    set wtmp $w.frall._tmp
    menubutton $wtmp -text $maxstr
    set soundMaxWidth [winfo reqwidth $wtmp]
    destroy $wtmp
    
    set i 0
    foreach eventStr $events(str) key $events(keys) {

	set wpage [$wnb newpage $eventStr -text [mc $eventStr]]	
		
	# Action
	set wact $wpage.f${key}
	frame $wact
	pack  $wact -padx 6 -pady 2
	checkbutton $wact.alrt -text " [mc {Show Popup}]" \
	  -variable $token\($key,msgbox)
	
	checkbutton $wact.lsound -text " [mc {Play Sound}]:" \
	  -variable $token\($key,sound)
	set wmenu [eval {
	    tk_optionMenu $wact.msound $token\($key,soundfile)
	} $allSounds]
	$wmenu configure -font $fontS

	set wpad $wact.pad[incr i]
	frame $wpad -width [expr $soundMaxWidth + 40] -height 1

	checkbutton $wact.chat -text " [mc {Start Chat}]" \
	  -variable $token\($key,chat)
	checkbutton $wact.msg -text " [mc {Send Message}]" \
	  -variable $token\($key,msg)
	
	grid x          x            $wpad
	grid $wact.alrt $wact.lsound $wact.msound -sticky w -padx 4 -pady 1
	grid $wact.chat $wact.msg    -            -sticky w -padx 4 -pady 1
		
	if {([llength audioSuffixes] == 0) || ![component::exists Sounds]} {
	    $wact.lsound configure -state disabled
	    $wact.msound configure -state disabled
	}
    }
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [mc OK] \
      -default active -command [list [namespace current]::OK $token]] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::Cancel $token]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btoff -text [mc {All Off}]  \
      -command [list [namespace current]::AllOff $token]]  \
      -side left -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6


    set nwin [llength [::UI::GetPrefixedToplevels $wdlg]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wdlg
    }
    wm title $w "[mc {Buddy Pouncing}]: $jid"
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

# BuddyPounce::PrefsToState, StateToPrefs --
# 
#       Translate to/from the budprefs array and the state array of
#       a particular token.

proc ::BuddyPounce::PrefsToState {token} {
    variable $token
    upvar 0 $token state
    variable budprefs
    
    set jid $state(jid2)
    if {[info exists budprefs($jid)]} {
	foreach {ekey actlist} $budprefs($jid) {
	    foreach akey $actlist {
		set state($ekey,$akey) 1
		
		# The sound file is treated specially.
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
    set budprefs($jid) {}
    foreach ekey $events(keys) {
	set actlist {}
	foreach akey $actions(keys) {
	    if {$state($ekey,$akey) == 1} {
		lappend actlist $akey
		
		# If sound we also need the soundfile.
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
    variable wdlg
    
    ::BuddyPounce::StateToPrefs $token
    ::UI::SaveWinGeom $wdlg $state(w)
    destroy $state(w)
    unset state
}


proc ::BuddyPounce::Cancel {token} {
    variable $token
    upvar 0 $token state
    variable wdlg

    ::UI::SaveWinGeom $wdlg $state(w)
    destroy $state(w)
    unset state
}

proc ::BuddyPounce::Event {from eventkey} {
    variable budprefs
    variable alertStr
    variable alertTitle 

    set jid [jlib::jidmap $from]
    if {[info exists budprefs($jid)]} {
	array set prefsArr $budprefs($jid)
	if {[info exists prefsArr($eventkey)]} {
	    foreach action $prefsArr($eventkey) {
		
		switch -- $action {
		    msgbox {
			::UI::AlertBox [format $alertStr($eventkey) $from] \
			  -title $alertTitle($eventkey)
		    }
		    sound {
			set soundfile [lsearch -inline -glob \
			  $prefsArr($eventkey) soundfile:*]
			set tail [string map {soundfile: ""} $soundfile]
			if {$tail != ""} {
			    ::BuddyPounce::PlaySound $tail
			}
		    }
		    chat {			
			# If already have chat
			set w [::Jabber::Chat::HaveChat $jid]
			if {$w != ""} {
			    raise $w
			} else {
			    ::Jabber::Chat::StartThread $from
			}
		    }
		    msg {
			::Jabber::NewMsg::Build -to $from  \
			  -subject "Auto Reply" -message "Insert your message!"
		    }
		}
	    }
	}
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
    if {[llength $all] == 0} {
	set all [msgcat::mc None]
    }
    return $all
}

proc ::BuddyPounce::PlaySound {tail} {
    global  this
    
    if {[component::exists Sounds]} {
	
	# We have no good way of avoiding playing sounds simultaneously!
	after 1200 [list ::Sounds::PlaySoundTmp \
	  [file join $this(soundsPath) $tail]]
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
    
    switch -- $type {
	available - unavailable {
	    ::BuddyPounce::Event $jid $type
	}
    }
}

proc ::BuddyPounce::PresenceUnavailableHook  {jid type args} {
    
    ::BuddyPounce::Event $jid unavailable
}

#-------------------------------------------------------------------------------
