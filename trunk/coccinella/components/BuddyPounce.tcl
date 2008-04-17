# BuddyPounce.tcl --
# 
#       Buddy pouncing...
#       This is just a first sketch.
#       TODO: all message translations.
#
#  Copyright (c) 2007 Mats Bengtsson
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
# $Id: BuddyPounce.tcl,v 1.30 2008-04-17 15:00:28 matben Exp $

# Key phrases are: 
#     event:    something happens, presence change, incoming message etc.
#     target:   is either a jid, a roster group, or 'any'  
#     action:   how to respond, popup, sound, reply etc.

namespace eval ::BuddyPounce {
    
    component::define BuddyPounce "Set actions for contact events"
}

proc ::BuddyPounce::Init {} {
    global  this
    
    ::Debug 2 "::BuddyPounce::Init"
    
    # Add all hooks we need.
    ::hooks::register quitAppHook              ::BuddyPounce::QuitHook
    ::hooks::register newMessageHook           ::BuddyPounce::NewMsgHook
    ::hooks::register newChatMessageHook       ::BuddyPounce::NewChatMsgHook
    ::hooks::register presenceHook             ::BuddyPounce::PresenceHook    
    ::hooks::register prefsInitHook            ::BuddyPounce::InitPrefsHook
    
    # Register popmenu entry.
    set menuDef {
	command mContactActions... {::BuddyPounce::Build $clicked $jidL $group}
    }
    set menuType {
	mContactActions... {group user}
    }
    set menuType {
	mContactActions... {}
    }
    ::Roster::RegisterPopupEntry $menuDef $menuType
    
    component::register BuddyPounce
        
    # Unique id needed to create instance tokens.
    variable uid 0
    variable wdlg .budpounce
    
    # These define which the events are.
    variable events
    set events(keys) {available unavailable msg     chat}
    set events(str)  {Online    Offline     Message Chat}
    
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
        
    variable alertTitle 
    array set alertTitle {
	available   Online
	unavailable Offline
	msg         Message
	chat        Chat
    }
}

proc ::BuddyPounce::InitPrefsHook {} {
    
    variable budprefsany
        
    ::PrefUtils::Add [list  \
      [list ::BuddyPounce::budprefs      budprefs_array      [GetJidPrefsArr]] \
      [list ::BuddyPounce::budprefsgroup budprefsgroup_array [GetGroupPrefsArr]]\
      [list ::BuddyPounce::budprefsany   budprefsany         $budprefsany]   \
      ]    
}

proc ::BuddyPounce::GetJidPrefsArr {} {    
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

proc ::BuddyPounce::Build {typeselected item groupL} {    
    global  this prefs
    
    variable uid
    variable wdlg
    variable events
    
    ::Debug 2 "::BuddyPounce::Build typeselected=$typeselected, item=$item, groupL=$groupL"

    # Initialize the state variable, an array, that keeps is the storage.
    
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
    
    set w $wdlg$uid
    set state(w) $w
    
    if {[lsearch $typeselected group] >= 0} {
	set clicked group
    } elseif {[lsearch $typeselected user] >= 0} {
	set clicked user
    } else {
	set clicked $typeselected
    }
    
    switch -- $clicked {
	user {    
	    set jid [jlib::jidmap $item]
	    jlib::splitjid $jid jid2 res
	    set state(jid)  $jid
	    set state(jid2) $jid2
	    set state(type) jid
	    set msg [mc budpounce-user $jid]
	    set title "[mc {Contact Actions}]: $jid"
	}
	group {
	    set group [lindex $groupL 0]
	    set state(group) $group
	    set state(type)  group
	    set msg [mc budpounce-group $group]
	    set title "[mc {Contact Actions}]: $group"
	}
	"" {
	    set state(type) any
	    set msg [mc budpounce-any]
	    set title "[mc {Contact Actions}]: [mc Any]"
	}
	default {
	    unset state
	    return
	}
    }
    
    # Get all sounds.
    set allSounds [GetAllSounds]
    set contrastBg [option get . backgroundLightContrast {}]
    set menuDef [list]
    foreach s $allSounds {
	lappend menuDef [list [::Sounds::GetTextForName $s] -value $s]
    }
    
    # Toplevel with class BuddyPounce.
    ::UI::Toplevel $w -class BuddyPounce \
      -usemacmainmenu 1 -macstyle documentProc -command ::BuddyPounce::CloseHook
    wm title $w $title

    set nwin [llength [::UI::GetPrefixedToplevels $wdlg]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wdlg
    }

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    ttk::label $w.frall.head -style Headlabel \
      -text [mc "Contact Actions"] -compound left
    pack $w.frall.head -side top -fill both -expand 1

    ttk::separator $w.frall.s -orient horizontal
    pack $w.frall.s -side top -fill x

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 300 -justify left -text $msg
    pack $wbox.msg -side top -anchor w
        
    set wnb $wbox.nb
    ttk::notebook $wnb -padding {4}
    pack $wnb
        
    set i 0
    foreach estr $events(str) ekey $events(keys) {

	$wnb add [ttk::frame $wnb.$ekey] -text [mc $estr] -sticky news
		
	# Action
	set wact $wnb.$ekey.f
	ttk::frame $wact -padding [option get . notebookPagePadding {}]
	pack  $wact  -side top -anchor [option get . dialogAnchor {}]
	
	ttk::checkbutton $wact.alrt -text [mc "Show popup"] \
	  -variable $token\($ekey,msgbox)
	
	ttk::checkbutton $wact.lsound -text "[mc {Play sound}]:" \
	  -variable $token\($ekey,sound)
	ui::combobutton $wact.msound -variable $token\($ekey,soundfile) \
	  -menulist $menuDef
	
	ttk::checkbutton $wact.chat -text [mc "Start chat"] \
	  -variable $token\($ekey,chat)

	set wmsg $wact.fmsg
	ttk::frame $wmsg
	
	ttk::frame $wmsg.f1
	pack  $wmsg.f1 -side top -anchor w
	ttk::checkbutton $wmsg.f1.c -text "[mc budpounce-sendmsg]:" \
	  -variable $token\($ekey,msg)
	ttk::entry $wmsg.f1.e -width 12 -textvariable $token\($ekey,msg,subject)
	pack  $wmsg.f1.c $wmsg.f1.e -side left
	
	ttk::frame $wmsg.f2 -padding {0 2}
	pack  $wmsg.f2 -side top -anchor w -fill x
	ttk::label $wmsg.f2.l -text "[mc Message]:"
	text  $wmsg.f2.t -height 2 -width 24 -wrap word -bd 1 -relief sunken
	pack  $wmsg.f2.l -side left -anchor n
	pack  $wmsg.f2.t -side top -fill x
	
	set state($ekey,msg,wtext) $wmsg.f2.t
	
	grid  $wact.alrt  $wact.lsound  $wact.msound  -sticky w  -padx 4 -pady 1
	grid  $wact.chat  $wact.fmsg    -             -sticky nw -padx 4 -pady 1
	grid columnconfigure $wact 2 -minsize 40	
	
	if {![component::exists Sounds]} {
	    $wact.lsound configure -state disabled
	    $wact.msound configure -state disabled
	}
    }
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc OK] -default active \
      -command [list [namespace current]::OK $token]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::Cancel $token]
    ttk::button $frbot.btoff -text [mc "Disable All"]  \
      -command [list [namespace current]::AllOff $token]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
	pack $frbot.btoff -side right
    } else {
	pack $frbot.btoff -side right
	pack $frbot.btcancel -side right -padx $padx
	pack $frbot.btok -side right
    }
    pack $frbot -side bottom -fill x

    wm resizable $w 0 0
    
    AllOff $token
    PrefsToState $token

    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 12]
    } $wbox.msg $w]    
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
			if {$state($ekey,msg,subject) ne ""} {
			    lappend actlist subject:$state($ekey,msg,subject)
			}
			set body [$state($ekey,msg,wtext) get 1.0 "end -1 char"]
			regsub -all "\n" $body {\\n} body
			if {$body ne ""} {
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
    variable alertTitle
    
    ::Debug 4 "::BuddyPounce::Event from = $from, eventkey=$eventkey"
    array set argsA $args
    set xmldata $argsA(-xmldata)
    
    # We must check 'jid', 'group' and 'any' in that order.
    # A list of actions to perform if any.
    set actions [list]
    
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
		ui::dialog -message [mc budpounce-$eventkey $from] \
		  -title [mc $alertTitle($eventkey)]
	    }
	    sound {
		set soundfile [lsearch -inline -glob $actions soundfile:*]
		set name [string map {soundfile: ""} $soundfile]
		if {$name ne ""} {
		    PlaySound $name
		}
	    }
	    chat {			
		# If already have chat.
		set w [::Chat::GetWindow $jid]
		if {$w ne ""} {
		    raise $w
		} else {
		    ::Chat::StartThread $from
		}
	    }
	    msg {
		set subject [mc "Auto Reply"]
		set body "Insert your message!"
		set subjectopt [lsearch -inline -glob $actions subject:*]
		if {$subjectopt ne ""} {
		    set subject [string map {subject: ""} $subjectopt]
		}
		set bodyopt [lsearch -inline -glob $actions body:*]
		if {$bodyopt ne ""} {
		    set body [string map {body: ""} $bodyopt]
		    set body [subst -nocommands -novariables $body]
		}
		set opts [list]
		set msgbody [wrapper::getcdata [wrapper::getfirstchildwithtag $xmldata body]]
		if {$msgbody ne ""} {
		    lappend opts -quotemessage $msgbody
		}
		eval {::NewMsg::Build -to $from  \
		  -subject $subject -message $body} $opts
	    }
	}
    }
}

proc ::BuddyPounce::GetAllSounds {} {
    
    set all [list]
    if {[component::exists Sounds]} {
	set all [::Sounds::GetAllSoundsPresentSet]
    }
    if {[llength $all] == 0} {
	set all [msgcat::mc None]
    }
    return $all
}

proc ::BuddyPounce::PlaySound {name} {    
    if {[component::exists Sounds]} {
	::Sounds::DoPlayWhenIdle $name
    }
}

proc ::BuddyPounce::QuitHook {} {
    variable wdlg
    
    ::UI::SaveWinPrefixGeom $wdlg
}

proc ::BuddyPounce::CloseHook {wclose} {
    variable wdlg

    ::UI::SaveWinGeom $wdlg $wclose
    return ""
}

proc ::BuddyPounce::NewChatMsgHook {xmldata} {

    set from [wrapper::getattribute $xmldata from]
    set jid2 [jlib::barejid $from]
    Event $jid2 chat -xmldata $xmldata
}

proc ::BuddyPounce::NewMsgHook {xmldata uuid} {
    
    set from [wrapper::getattribute $xmldata from]
    set jid2 [jlib::barejid $from]
    Event $jid2 msg -xmldata $xmldata
}

proc ::BuddyPounce::PresenceHook {jid type args} {
    
    ::Debug 4 "::BuddyPounce::PresenceHook jid=$jid, type=$type"
    
    # The 'wasavailable' roster command returns any previous available status.
    
    switch -- $type {
	available {
	    if {![::Jabber::RosterCmd wasavailable $jid]} {
		eval {Event $jid $type} $args
	    }
	}
	unavailable {
	    if {[::Jabber::RosterCmd wasavailable $jid]} {
		eval {Event $jid $type} $args
	    }
	}
    }
}

proc ::BuddyPounce::PresenceUnavailableHook  {jid type args} {   
    Event $jid unavailable
}

#-------------------------------------------------------------------------------
