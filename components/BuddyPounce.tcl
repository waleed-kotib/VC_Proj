# BuddyPounce.tcl --
# 
#       Buddy pouncing...
#       This is just a first sketch.
#       TODO: all message translations.
#       
# $Id: BuddyPounce.tcl,v 1.7 2004-11-27 14:52:52 matben Exp $

# Key phrases are: 
#     event:    something happens, presence change, incoming message etc.
#     target:   is either a jid, a roster group, or 'any'  
#     action:   how to respond, popup, sound, reply etc.

namespace eval ::BuddyPounce:: {
    
}

proc ::BuddyPounce::Init { } {
    global  this
    
    ::Debug 2 "::BuddyPounce::Init"
    
    # Add all hooks we need.
    ::hooks::register quitAppHook              ::BuddyPounce::QuitHook
    ::hooks::register newMessageHook           ::BuddyPounce::NewMsgHook
    ::hooks::register newChatMessageHook       ::BuddyPounce::NewChatMsgHook
    ::hooks::register presenceHook             ::BuddyPounce::PresenceHook    
    ::hooks::register prefsInitHook            ::BuddyPounce::InitPrefsHook
    ::hooks::register closeWindowHook          ::BuddyPounce::CloseHook
    
    # Register popmenu entry.
    set popMenuSpec \
      [list {Buddy Pouncing} any {::BuddyPounce::Build $typesel $jid $group}]
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
    
    # Unique id needed to create instance tokens.
    variable uid 0
    variable wdlg .budpounce
    
    # These define which the events are.
    variable events
    set events(keys) {available unavailable msg                chat}
    set events(str)  {Online    Offline     {Incoming Message} {New Chat}}
    
    variable actionlist
    set actionlist(keys) {msgbox sound chat msg}
    
    # Keep prefs. jid must be mapped and with no resource!
    # The action keys correspond to option being on.
    #   budprefs(jid2) {event {list-of-action-keys} event {...} ...}
    variable budprefs
    
    # And the same for roster groups.
    variable budprefsgroup
    
    # And for 'any' which is not an array.
    variable budprefsany {}
    
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
    
    variable budprefsany
        
    ::PreferencesUtils::Add [list  \
      [list ::BuddyPounce::budprefs      budprefs_array      [GetJidPrefsArr]] \
      [list ::BuddyPounce::budprefsgroup budprefsgroup_array [GetGroupPrefsArr]]\
      [list ::BuddyPounce::budprefsany   budprefsany         $budprefsany]   \
      ]    
}

proc ::BuddyPounce::GetJidPrefsArr { } {    
    variable budprefs
    return [array get budprefs]
}

proc ::BuddyPounce::GetGroupPrefsArr { } {
    variable budprefsgroup
    return [array get budprefsgroup]
}

# BuddyPounce::Build --
# 
#       Builds the preference dialog.
#       
#       typeselected:   user, wb, group, ""

proc ::BuddyPounce::Build {typeselected item group} {    
    global  this prefs
    
    variable uid
    variable wdlg
    variable events
    variable audioSuffixes
    
    ::Debug 2 "::BuddyPounce::Build typeselected=$typeselected, item=$item"

    # Initialize the state variable, an array, that keeps is the storage.
    
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
    
    set w ${wdlg}${uid}
    set state(w) $w
    
    switch -- $typeselected {
	user - wb {    
	    set jid [jlib::jidmap $item]
	    jlib::splitjid $jid jid2 res
	    set state(jid)  $jid
	    set state(jid2) $jid2
	    set state(type) jid
	    set msg "Set a specific action when something happens with \"$jid\",\
	      which can be a changed status, or if you receive a message etc.\
	      Pick events using the tabs below."
	    set title "[mc {Buddy Pouncing}]: $jid"
	}
	group {
	    set state(group) $group
	    set state(type)  group
	    set msg "Set a specific action when something happens with\
	      any contact belonging to the group \"$group\",\
	      which can be a changed status, or if you receive a message etc.\
	      Pick events using the tabs below."
	    set title "[mc {Buddy Pouncing}]: $group"
	}
	"" {
	    set state(type) any
	    set msg "Set a specific action when something happens with\
	      any contact in your contact list,\
	      which can be a changed status, or if you receive a message etc.\
	      Pick events using the tabs below."
	    set title "[mc {Buddy Pouncing}]: Any"
	}
	default {
	    unset state
	    return
	}
    }
    
    # Get all sounds.
    set allSounds [GetAllSounds]
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
    wm title $w $title

    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 4

    ::headlabel::headlabel $w.frall.head -text [mc {Buddy Pouncing}]
    pack $w.frall.head -side top -fill both -expand 1
    label $w.frall.msg -wraplength 300 -justify left -padx 10 -pady 2 \
      -text $msg
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
    foreach eventStr $events(str) ekey $events(keys) {

	set wpage [$wnb newpage $eventStr -text [mc $eventStr]]	
		
	# Action
	set wact $wpage.f$ekey
	frame $wact
	pack  $wact -padx 6 -pady 2
	checkbutton $wact.alrt -text " [mc {Show Popup}]" \
	  -variable $token\($ekey,msgbox)
	
	checkbutton $wact.lsound -text " [mc {Play Sound}]:" \
	  -variable $token\($ekey,sound)
	set wmenu [eval {
	    tk_optionMenu $wact.msound $token\($ekey,soundfile)
	} $allSounds]
	$wmenu configure -font $fontS

	set wpad $wact.pad[incr i]
	frame $wpad -width [expr $soundMaxWidth + 40] -height 1

	checkbutton $wact.chat -text " [mc {Start Chat}]" \
	  -variable $token\($ekey,chat)
	set wmsg $wact.fmsg
	frame $wmsg
	
	frame $wmsg.f1
	pack  $wmsg.f1 -side top -anchor w
	checkbutton $wmsg.f1.c -text " [mc {Send Message with subject}]:" \
	  -variable $token\($ekey,msg)
	entry $wmsg.f1.e -width 12 -textvariable $token\($ekey,msg,subject)
	pack  $wmsg.f1.c $wmsg.f1.e -side left
	
	frame $wmsg.f2
	pack  $wmsg.f2 -side top -anchor w -fill x
	label $wmsg.f2.l -text "[mc Message]:"
	text  $wmsg.f2.t -height 2 -width 24 -wrap word
	pack  $wmsg.f2.l -side left -anchor n
	pack  $wmsg.f2.t -side top -fill x
	
	set state($ekey,msg,wtext) $wmsg.f2.t
	
	grid x          x            $wpad
	grid $wact.alrt $wact.lsound $wact.msound -sticky w  -padx 4 -pady 1
	grid $wact.chat $wact.fmsg   -            -sticky nw -padx 4 -pady 1
		
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
    wm resizable $w 0 0
    
    AllOff $token
    PrefsToState $token

    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 12]
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
    variable budprefsgroup
    variable budprefsany
    
    set eventActions {}
    
    switch -- $state(type) {
	jid {
	    set jid $state(jid2)
	    if {[info exists budprefs($jid)]} {
		set eventActions $budprefs($jid)
	    }
	}
	group {
	    set group $state(group)
	    if {[info exists budprefsgroup($group)]} {
		set eventActions $budprefsgroup($group)
	    }
	}
	any {
	    set eventActions $budprefsany
	}
    }
    foreach {ekey actlist} $eventActions {
	foreach akey $actlist {
	    
	    switch -glob -- $akey {
		soundfile:* {
		    # The sound file is treated specially.
		    set state($ekey,soundfile)  \
		      [string map {soundfile: ""} $akey]
		}
		subject:* {
		    set state($ekey,msg,subject) \
		      [string map {subject: ""} $akey]
		}
		body:* {
		    set body [string map {body: ""} $akey]
		    set body [subst -nocommands -novariables $body]
		    $state($ekey,msg,wtext) insert end $body
		}
		default {
		    set state($ekey,$akey) 1
		}
	    }
	}
    }
}

# BuddyPounce::StateToPrefs --
# 
#       Build the internal prefs array from the dialogs state variable.

proc ::BuddyPounce::StateToPrefs {token} {
    variable $token
    upvar 0 $token state
    variable budprefs
    variable budprefsgroup
    variable budprefsany
    variable events
    variable actionlist

    set eventActions {}
    
    # Build event-action list from state.
    foreach ekey $events(keys) {
	set actlist {}
	foreach akey $actionlist(keys) {
	    if {$state($ekey,$akey) == 1} {
		lappend actlist $akey
		
		switch -- $akey {
		    sound {
			# If sound we also need the soundfile.
			lappend actlist soundfile:$state($ekey,soundfile)
		    }
		    msg {
			if {$state($ekey,msg,subject) != ""} {
			    lappend actlist subject:$state($ekey,msg,subject)
			}
			set body [$state($ekey,msg,wtext) get 1.0 "end -1 char"]
			regsub -all "\n" $body {\\n} body
			if {$body != ""} {
			    lappend actlist body:$body
			}
		    }
		}
	    }
	}
	if {[llength $actlist]} {
	    lappend eventActions $ekey $actlist
	}
    }
    if {[llength $eventActions]} {    
	switch -- $state(type) {
	    jid {
		set jid $state(jid2)
		set budprefs($jid) $eventActions
	    }
	    group {
		set group $state(group)
		set budprefsgroup($group) $eventActions
	    }
	    any {
		set budprefsany $eventActions
	    }
	}
    } else {
	switch -- $state(type) {
	    jid {
		set jid $state(jid2)
		unset -nocomplain budprefs($jid)
	    }
	    group {
		set group $state(group)
		unset -nocomplain budprefsgroup($group)
	    }
	    any {
		set budprefsany {}
	    }
	}
    }
}

proc ::BuddyPounce::AllOff {token} {
    variable $token
    upvar 0 $token state
    variable events
    variable actionlist
    set actionlist(keys) {msgbox sound chat msg}

    foreach ekey $events(keys) {
	foreach mkey $actionlist(keys) {
	    set state($ekey,$mkey) 0
	}
	set state($ekey,msg,subject) ""
	$state($ekey,msg,wtext) delete 1.0 end
    }
}

proc ::BuddyPounce::OK {token} {
    variable $token
    upvar 0 $token state
    variable budprefs
    variable wdlg
    
    StateToPrefs $token
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

# BuddyPounce::Event --
# 
#       Handler for any event.
# 
# Arguments:
#       from        2-tier jid.
#       eventkey    available, unavailable, chat, msg.
#       
# Results:
#       none.

proc ::BuddyPounce::Event {from eventkey args} {
    
    variable budprefs
    variable budprefsgroup
    variable budprefsany
    variable alertStr
    variable alertTitle
    
    ::Debug 4 "::BuddyPounce::Event from = $from, eventkey=$eventkey"
    array set argsArr $args
    
    # We must check 'jid', 'group' and 'any' in that order.
    # A list of actions to perform if any.
    set actions {}
    
    # First this specific JID.
    set jid [jlib::jidmap $from]
    if {[info exists budprefs($jid)]} {
	array set eventArr $budprefs($jid)
	if {[info exists eventArr($eventkey)]} {
	    set actions $eventArr($eventkey)
	}
    }

    # Groups.
    if {[llength $actions] == 0} {
	set groups [::Jabber::RosterCmd getgroups $jid]
	foreach group $groups {
	    if {[info exists budprefsgroup($group)]} {
		array unset eventArr
		array set eventArr $budprefsgroup($group)
		if {[info exists eventArr($eventkey)]} {
		    set actions $eventArr($eventkey)
		}
	    }
	}
    }

    # Any.
    if {[llength $actions] == 0} {
	array unset eventArr
	array set eventArr $budprefsany
	if {[info exists eventArr($eventkey)]} {
	    set actions $eventArr($eventkey)
	}
    }
    
    foreach action $actions {
	
	switch -- $action {
	    msgbox {
		::UI::AlertBox [format $alertStr($eventkey) $from] \
		  -title $alertTitle($eventkey)
	    }
	    sound {
		set soundfile [lsearch -inline -glob $actions soundfile:*]
		set tail [string map {soundfile: ""} $soundfile]
		if {$tail != ""} {
		    PlaySound $tail
		}
	    }
	    chat {			
		# If already have chat.
		set w [::Chat::HaveChat $jid]
		if {$w != ""} {
		    raise $w
		} else {
		    ::Chat::StartThread $from
		}
	    }
	    msg {
		set subject [mc {Auto Reply}]
		set body "Insert your message!"
		set subjectopt [lsearch -inline -glob $actions subject:*]
		if {$subjectopt != ""} {
		    set subject [string map {subject: ""} $subjectopt]
		}
		set bodyopt [lsearch -inline -glob $actions body:*]
		if {$bodyopt != ""} {
		    set body [string map {body: ""} $bodyopt]
		    set body [subst -nocommands -novariables $body]
		}
		set opts {}
		if {[info exists argsArr(-body)]} {
		    lappend opts -quotemessage $argsArr(-body)
		}
		eval {::NewMsg::Build -to $from  \
		  -subject $subject -message $body} $opts
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
	jlib::splitjid $argsArr(-from) jid2 res
	eval {Event $jid2 chat} $args
    }
}

proc ::BuddyPounce::NewMsgHook {body args} {
    
    array set argsArr $args
    if {[info exists argsArr(-from)]} {
	jlib::splitjid $argsArr(-from) jid2 res
	eval {Event $jid2 msg} $args
    }
}

proc ::BuddyPounce::PresenceHook {jid type args} {
    
    ::Debug 4 "::BuddyPounce::PresenceHook jid=$jid, type=$type"
    
    # The 'wasavailable' roster command returns any previous available status.
    
    switch -- $type {
	available {
	    if {![::Jabber::RosterCmd wasavailable $jid]} {
		Event $jid $type
	    }
	}
	unavailable {
	    if {[::Jabber::RosterCmd wasavailable $jid]} {
		Event $jid $type
	    }
	}
    }
}

proc ::BuddyPounce::PresenceUnavailableHook  {jid type args} {
    
    Event $jid unavailable
}

#-------------------------------------------------------------------------------
