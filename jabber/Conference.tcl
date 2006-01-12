#  Conference.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements enter and create dialogs for groupchat using
#      the 'jabber:iq:conference' and 'muc' protocols.
#      
#  Copyright (c) 2001-2005  Mats Bengtsson
#  
# $Id: Conference.tcl,v 1.44 2006-01-12 11:03:17 matben Exp $

package provide Conference 1.0

# This uses the 'jabber:iq:conference' namespace and therefore requires
# that we use the 'jabber:iq:browse' for this to work.
# The 'jabber:iq:conference' is in a transition to be replaced by MUC.

namespace eval ::Conference:: {

    # Keep track of me for each room.
    # locals($roomJid,own) {room@server/hash nickname}
    variable locals
    variable uid 0
}

# Conference::BuildEnter --
#
#       Initiates the process of entering a room using the
#       'jabber:iq:conference' method.
#       
# Arguments:
#       args        -server, -roomjid, -autoget 0/1
#       
# Results:
#       "cancel" or "enter".
     
proc ::Conference::BuildEnter {args} {
    global  this wDlgs

    variable uid
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Conference::BuildEnter args='$args'"
    
    array set argsArr $args
    
    # State variable to collect instance specific variables.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
    
    set w $wDlgs(jenterroom)$uid    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox} \
      -closecommand [list [namespace current]::CloseEnter $token]
    wm title $w [mc {Enter Room}]
    
    ::UI::SetWindowPosition $w $wDlgs(jenterroom)

    array set state {
	finished    -1
	statuscount 0
	server      ""
	roomname    ""
    }    
    set state(w) $w
    set state(wraplength)     300

    set confServers [$jstate(jlib) service getconferences]
    if {$confServers == {}} {
	set serviceList [list [mc {No Available}]]
    } else {
	set serviceList $confServers
    }
    ::Debug 2 "\t confServers='$confServers'"
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength $state(wraplength) -justify left \
      -text [mc jamessconfmsg]
    pack $wbox.msg -side top -anchor w

    set frtop        $wbox.top
    set wpopupserver $frtop.eserv
    set wpopuproom   $frtop.eroom
    ttk::frame $frtop
    pack $frtop -side top -fill x
    ttk::label $frtop.lserv -text "[mc {Conference server}]:" 

    # First menubutton: servers. (trace below)
    eval {ttk::optionmenu $wpopupserver $token\(server)} $serviceList
    ttk::label $frtop.lroom -text "[mc {Room name}]:"
    
    # Find the default conferencing server.
    if {[info exists argsArr(-server)]} {
	set state(server) $argsArr(-server)
    } else {
	set state(server) [lindex $serviceList 0]
    }
    set state(server-state) normal
    set state(room-state)   normal

    # Second menubutton: rooms for above server. Fill in below.
    set state(wroommenu) $wpopuproom
    ttk::optionmenu $wpopuproom $token\(roomname) ""

    if {[info exists argsArr(-roomjid)]} {
	jlib::splitjidex $argsArr(-roomjid) state(roomname) state(server) x
	set state(server-state) disabled
	set state(room-state)   disabled
	$wpopupserver state {disabled}
	$wpopuproom   state {disabled}
    }
    if {[info exists argsArr(-server)]} {
	set state(server) $argsArr(-server)
	set state(server-state) disabled
	$wpopupserver state {disabled}
    }
    if {$confServers == {}} {
	set state(server-state) disabled
	set state(room-state)   disabled
	$wpopupserver state {disabled}
	$wpopuproom   state {disabled}
    }
    
    grid  $frtop.lserv  $wpopupserver  -sticky e -pady 2
    grid  $frtop.lroom  $wpopuproom    -sticky e -pady 2
    grid  $wpopupserver  $wpopuproom  -sticky ew
    grid columnconfigure $frtop 1 -weight 1
    
    # Button part.
    set frbot    $wbox.b
    set wbtenter $frbot.btenter
    set wbtget   $frbot.btget
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $wbtget -text [mc Get] -default active \
      -command [list [namespace current]::EnterGet $token]
    ttk::button $wbtenter -text [mc Enter] -state disabled \
      -command [list [namespace current]::DoEnter $token]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelEnter $token]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $wbtget -side right
	pack $wbtenter -side right -padx $padx
	pack $frbot.btcancel -side right
    } else {
	pack $frbot.btcancel -side right
	pack $wbtenter -side right -padx $padx
	pack $wbtget -side right
    }
    pack $frbot -side bottom -fill x
    
    if {$confServers == {}} {
	$wbtget state {disabled}
    }

    # This part must be built dynamically from the 'get' xml data.
    # May be different for each conference server.
    set wfrform $wbox.frmid
    ttk::frame $wfrform
    pack  $wfrform   -fill both -expand 1
    
    # Busy arrows and status message.
    set wsearrows $wbox.st.arr
    set wstatus   $wbox.st.stat
    ttk::frame $wbox.st
    ::chasearrows::chasearrows $wsearrows -size 16
    ttk::label $wstatus -style Small.TLabel -textvariable $token\(status)
    pack  $wbox.st  -side bottom -fill x
    pack  $wsearrows  $wstatus  -side left

    set state(wsearrows)    $wsearrows
    set state(wpopupserver) $wpopupserver
    set state(wpopuproom)   $wpopuproom
    set state(wbtget)       $wbtget
    set state(wbtenter)     $wbtenter
    set state(wfrform)      $wfrform
    set state(status)       ""
    
    wm resizable $w 0 0
    set oldFocus [focus]
    
    if {($state(room-state) eq "normal") && ($confServers != {})} {
	ConfigRoomList $token x x x
	trace variable $token\(server) w  \
	  [list [namespace current]::ConfigRoomList $token]
    }
	    
    if {[info exists argsArr(-autoget)] && $argsArr(-autoget)} {
	
	# We seem to get 1x1 windows on Gnome if not have after idle here???
	after idle ::Conference::EnterGet $token
    }
        
    # Wait here for a button press and window to be destroyed.
    tkwait window $w

    ::Debug 3 "\t after tkwait window"
    catch {focus $oldFocus}
    trace vdelete $token\(server) w  \
      [list [namespace current]::ConfigRoomList $token]
    set finished $state(finished)
    unset state
    return [expr {($finished <= 0) ? "cancel" : "enter"}]
}

proc ::Conference::CloseEnter {token w} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    
    ::UI::SaveWinGeom $wDlgs(jenterroom) $w
    return
}

proc ::Conference::ConfigRoomList {token name junk1 junk2} {    
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    ::Debug 4 "::Conference::ConfigRoomList"

    # Fill in room list if exist else browse or disco.    
    if {[$jstate(jlib) service isinvestigated $state(server)]} {
	FillRoomList $token
    } else {
	BusyEnterDlgIncr $token
	$jstate(jlib) service send_getchildren $state(server)  \
	  [list [namespace current]::GetRoomsCB $token]
    }
}

proc ::Conference::FillRoomList {token} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    ::Debug 4 "::Conference::FillRoomList"
    
    set roomList {}
    if {[string length $state(server)] > 0} {
	set allRooms [$jstate(jlib) service childs $state(server)]
	foreach roomjid $allRooms {
	    jlib::splitjidex $roomjid room x x
	    lappend roomList $room
	}
    }
    set roomList [lsort $roomList]
    $state(wroommenu) delete 0 end
    foreach room $roomList {
	$state(wroommenu) add radiobutton -label $room  \
	  -variable $token\(roomname)
    }
    set state(roomname) [lindex $roomList 0]
}

proc ::Conference::BusyEnterDlgIncr {token {num 1}} {
    variable $token
    upvar 0 $token state
    
    incr state(statuscount) $num
    ::Debug 4 "::Conference::BusyEnterDlgIncr num=$num, statuscount=$state(statuscount)"
    
    if {$state(statuscount) > 0} {
	set state(status) [mc {Getting available rooms...}]
	$state(wsearrows) start
	$state(wpopupserver) state {disabled}
	$state(wpopuproom)   state {disabled}
	$state(wbtenter)     state {disabled}
	$state(wbtget)       state {disabled}
    } else {
	set state(statuscount) 0
	set state(status) ""
	$state(wsearrows) stop
	if {[string equal $state(server-state) "normal"]} {
	    $state(wpopupserver) state {!disabled}
	}
	if {[string equal $state(room-state) "normal"]} {
	    $state(wpopuproom)   state {!disabled}
	}
	$state(wbtenter)   state {!disabled}
	$state(wbtget)     state {!disabled}
    }
}

proc ::Conference::GetRoomsCB {token browsename type jid subiq args} {
    
    ::Debug 4 "::Conference::GetRoomsCB type=$type, jid=$jid"
    
    switch -- $type {
	error {
	    # ???
	}
	ok - result {
	    FillRoomList $token
	}
    }
    BusyEnterDlgIncr $token -1
}

proc ::Conference::CancelEnter {token} {
    variable $token
    upvar 0 $token state

    set state(finished) 0
    catch {destroy $state(w)}
}

proc ::Conference::EnterGet {token} {    
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    # Verify.
    if {($state(roomname) == "") || ($state(server) == "")} {
	::UI::MessageBox -type ok -icon error -parent $state(w) \
	  -message [mc jamessenterroomempty]
	return
    }	
    BusyEnterDlgIncr $token
    
    # Send get enter room.
    set roomjid [jlib::joinjid $state(roomname) $state(server) ""]
    if {![jlib::jidvalidate $roomjid]} {
	::UI::MessageBox -type ok -icon error -parent $state(w) \
	  -message "Not a valid roomname"
	return
    }
    $jstate(jlib) conference get_enter $roomjid  \
      [list [namespace current]::EnterGetCB $token]
}

proc ::Conference::EnterGetCB {token jlibName type subiq} {   
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Conference::EnterGetCB type=$type, subiq='$subiq'"
    
    if {![info exists state(w)]} {
	return
    }
    BusyEnterDlgIncr $token -1
    
    if {$type == "error"} {
	::UI::MessageBox -type ok -icon error -parent $state(w) \
	  -message [mc jamesserrconfget [lindex $subiq 0] [lindex $subiq 1]]
	return
    }

    # The form part.
    set wscrollframe $state(wfrform).scform
    if {[winfo exists $wscrollframe]} {
	destroy $wscrollframe
    }
    ::UI::ScrollFrame $wscrollframe -padding {8 12} -bd 1 -relief sunken \
      -propagate 0 -width $state(wraplength)
    pack $wscrollframe -fill both -expand 1 -pady 6

    # Compute form width using typical wraplength.
    set width [expr {$state(wraplength) - 24}]
    
    set frint [::UI::ScrollFrameInterior $wscrollframe]
    set wform $frint.f
    set formtoken [::JForms::Build $wform $subiq -tilestyle Small -width $width]
    pack $wform -fill both -expand 1
    set state(formtoken) $formtoken
    
    $state(wbtenter) configure -default active
    $state(wbtget)   configure -default disabled
    $state(wbtenter) state {!disabled}
    $state(wbtget)   state {!disabled}
}

proc ::Conference::DoEnter {token} {   
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    set subelements [::JForms::GetXML $state(formtoken)]
    set roomjid [jlib::joinjid $state(roomname) $state(server) ""]
    $jstate(jlib) conference set_enter $roomjid $subelements  \
      [list [namespace current]::ResultCallback $roomjid]
    
    # This triggers the tkwait, and destroys the enter dialog.
    set state(finished) 1
    catch {destroy $state(w)}
}

# Conference::ResultCallback --
#
#       This is our callback procedure from 'jabber:iq:conference'.

proc ::Conference::ResultCallback {roomJid jlibName type subiq} {
    variable locals
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Conference::ResultCallback roomJid=$roomJid, type=$type, subiq='$subiq'"
    
    if {$type == "error"} {
	::UI::MessageBox -type ok -icon error -message  \
	  [mc jamessconffailed $roomJid [lindex $subiq 0] [lindex $subiq 1]]
    } else {
	::hooks::run groupchatEnterRoomHook $roomJid "conference"
    }
}

#... Create Room ...............................................................

# Conference::BuildCreate --
#
#       Initiates the process of creating a room.
#       
# Arguments:
#       args    -server, -roomname
#       
# Results:
#       "cancel" or "create".
     
proc ::Conference::BuildCreate {args} {
    global  this wDlgs
    
    variable uid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Conference::BuildCreate args='$args'"
    array set argsArr $args
    
    # State variable to collect instance specific variables.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
    
    set w $wDlgs(jcreateroom)$uid    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document {closeBox resizable}} \
      -closecommand [list [namespace current]::CloseCreate $token]
    wm title $w [mc {Create Room}]

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jcreateroom)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jenterroom)
    }

    array set state {
	finished    -1
	server      ""
	roomname    ""
	nickname    ""
    }
    set state(w)              $w
    set state(wraplength)     300
    
    set confServers [$jstate(jlib) service getconferences]
    if {$confServers == {}} {
	set serviceList [list [mc {No Available}]]
    } else {
	set serviceList $confServers
    }

    # Only temporary setting of 'usemuc'.
    if {$jprefs(prefgchatproto) == "muc"} {
	set state(usemuc) 1
    } else {
	set state(usemuc) 0
    }
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength $state(wraplength) -justify left \
      -text [mc jacreateroom]
    pack $wbox.msg -side top -anchor w
    
    set frtop        $wbox.top
    set wpopupserver $frtop.eserv

    ttk::frame $frtop
    pack $frtop -side top -fill x
        
    ttk::label $frtop.lserv -text "[mc {Conference server}]:"
    eval {ttk::optionmenu $frtop.eserv $token\(server)} $serviceList
    ttk::label $frtop.lroom -text "[mc {Room name}]:"    
    ttk::entry $frtop.eroom -textvariable $token\(roomname)  \
      -validate key -validatecommand {::Jabber::ValidateUsernameStr %S}
    ttk::label $frtop.lnick -text "[mc {Nick name}]:"    
    ttk::entry $frtop.enick -textvariable $token\(nickname)  \
      -validate key -validatecommand {::Jabber::ValidateResourceStr %S}
    
    grid  $frtop.lserv  $frtop.eserv  -sticky e -pady 2
    grid  $frtop.lroom  $frtop.eroom  -sticky e -pady 2
    grid  $frtop.lnick  $frtop.enick  -sticky e -pady 2
    
    grid  $frtop.eserv  $frtop.eroom  $frtop.enick  -sticky ew
    grid columnconfigure $frtop 1 -weight 1
    
    # Find the default conferencing server.
    if {[info exists argsArr(-server)]} {
	
	# Bes ure to get domain part only!
	jlib::splitjidex $argsArr(-server) - domain -
	set state(server) $domain
	$frtop.eserv state {disabled}
    } else {
	set state(server) [lindex $serviceList 0]
    }
    if {$confServers == {}} {
	$frtop.eserv state {disabled}
	$frtop.eroom state {disabled}
	$frtop.enick state {disabled}
    }
            
    # Button part.
    set frbot     $wbox.b
    set wbtcreate $frbot.btok
    set wbtget    $frbot.btget
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $wbtget -text [mc Get] -default active \
      -command [list [namespace current]::CreateGet $token]
    ttk::button $wbtcreate -text [mc Create] \
      -command [list [namespace current]::CreateSetRoom $token]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelCreate $token]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $wbtget -side right
	pack $wbtcreate -side right -padx $padx
	pack $frbot.btcancel -side right
    } else {
	pack $frbot.btcancel -side right
	pack $wbtcreate -side right -padx $padx
	pack $wbtget -side right
    }
    pack $frbot -side bottom -fill x

    if {$confServers == {}} {
	$wbtget    state {disabled}
	$wbtcreate state {disabled}
    }

    # This part must be built dynamically from the 'get' xml data.
    # May be different for each conference server.
    
    set wfrform $wbox.frmid
    ttk::frame $wfrform
    pack  $wfrform   -fill both -expand 1

    # Busy arrows and status message.
    set wsearrows $wbox.st.arr
    set wstatus   $wbox.st.stat
    ttk::frame $wbox.st
    ::chasearrows::chasearrows $wsearrows -size 16
    ttk::label $wstatus -style Small.TLabel -textvariable $token\(status)
    pack  $wbox.st  -side bottom -fill x
    pack  $wsearrows  $wstatus  -side left

    set state(wsearrows)      $wsearrows
    set state(wpopupserver)   $wpopupserver
    set state(wbtget)         $wbtget
    set state(wbtcreate)      $wbtcreate
    set state(wfrform)        $wfrform
    
    bind $w <Return> [list $wbtget invoke]
    
    if {$confServers != {}} {
	trace variable $token\(server) w  \
	  [list [namespace current]::CreateTraceServer $token]
	CreateSetState $token
    }
    
    # Grab and focus.
    set oldFocus [focus]
    if {[$frtop.eroom instate !disabled]} {
	focus $frtop.eroom
    }
    set minWidth [expr {$state(wraplength) + \
      [::UI::GetPaddingWidth [option get . dialogPadding {}]] - 2}]
    wm minsize $w $minWidth 200
    
    # Wait here for a button press and window to be destroyed. BAD? JWB!!!
    tkwait window $w
    
    catch {focus $oldFocus}
    set finished $state(finished)
    unset state
    return [expr {($finished <= 0) ? "cancel" : "create"}]
}

#       MUC rooms can be created directly (instant) without getting the form.
#       jabber:iq:conference needs form first.

proc ::Conference::CreateTraceServer {token name junk1 junk2} {    
    
    CreateSetState $token
}

proc ::Conference::CreateSetState {token} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::xmppxmlns xmppxmlns
     
    if {$jprefs(prefgchatproto) == "muc"} {
	set muc [$jstate(jlib) service hasfeature $state(server) $xmppxmlns(muc)]
	set state(usemuc) $muc
	if {$muc} {
	    $state(wbtcreate) state {!disabled}
	} else {
	    $state(wbtcreate) state {disabled}
	}
    }    
}

proc ::Conference::CloseCreate {token w} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    
    ::UI::SaveWinGeom $wDlgs(jcreateroom) $state(w)
    return
}

proc ::Conference::CancelCreate {token} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    # No jidmap since may not be valid.
    # Is this according to MUC?
    set roomjid $state(roomname)@$state(server)
    if {$state(usemuc) && ($roomjid != "")} {
	catch {$jstate(jlib) muc setroom $roomjid cancel}
    }
    ::UI::SaveWinGeom $wDlgs(jcreateroom) $state(w)
    set state(finished) 0
    catch {destroy $state(w)}
}

# Conference::CreateGet --
# 
#       Requests the form to create room. The Get button.

proc ::Conference::CreateGet {token} {    
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::xmppxmlns xmppxmlns

    # Figure out if 'conference' or 'muc' protocol.
    if {$jprefs(prefgchatproto) eq "muc"} {
	set state(usemuc)  \
	  [$jstate(jlib) service hasfeature $state(server) $xmppxmlns(muc)]
    } else {
	set state(usemuc) 0
    }
    
    # Verify:
    if {$state(server) == ""} {
	::UI::MessageBox -type ok -icon error -parent $state(w) \
	  -message [mc jamessnogroupchat]
	return
    }
    if {$state(roomname) == ""} {
	::UI::MessageBox -type ok -icon error -parent $state(w) \
	  -message [mc jamessgcnoroomname]
	return
    }
    if {($state(usemuc) && ($state(nickname) == ""))} {
	::UI::MessageBox -type ok -icon error -parent $state(w) \
	  -message [mc jamessgcnoroomnick]
	return
    }

    set roomjid [jlib::joinjid $state(roomname) $state(server) ""]
    if {![jlib::jidvalidate $roomjid]} {
	::UI::MessageBox -type ok -icon error -parent $state(w) \
	  -message "Not a valid roomname"
	return
    }
    $state(wpopupserver) state {disabled}
    $state(wbtget)       state {disabled}
    set state(status) [mc jawaitserver]
    
    # Send get create room. NOT the server!
    set state(roomjid) [jlib::jidmap $roomjid]

    $state(wsearrows) start
    SendCreateGet $token
}

proc ::Conference::SendCreateGet {token} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Conference::SendCreateGet usemuc=$state(usemuc)"

    set roomjid $state(roomjid)
    
    if {$state(usemuc)} {

	# We announce that we are a Coccinella here and let others know ip etc.
	# MUC:
	#   1) <presence .../>
	#   for an instant room:
	#     2) <iq type='set' .../>     with no form
	#   for a configurable room
	#     3) <iq type='get' .../>     to get form
	#     4) <iq type='set' .../>     submit form
	#     
	# Thus the "Get" operation takes two steps.

	$jstate(jlib) muc create $roomjid $state(nickname)  \
	  [list [namespace current]::CreateMUCCB $token]
    } else {
	
	# Conference:
	#   We need to get a form the first thing we do.

	$jstate(jlib) conference get_create $roomjid  \
	  [list [namespace current]::CreateGetFormCB $token]
    }
}

# Conference::CreateMUCCB --
#
#       Presence callabck from the 'muc create' command.
#
# Arguments:
#       jlibName 
#       type    presence typ attribute, 'available' etc.
#       args    -from, -id, -to, -x ...
#       
# Results:
#       None.

proc ::Conference::CreateMUCCB {token jlibName type args} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Conference::CreateMUCCB type=$type, args='$args'"
    
    if {![info exists state(w)]} {
	return
    }
    $state(wsearrows) stop
    array set argsArr $args
    
    if {$type == "error"} {
    	set errcode ???
    	set errmsg ""
    	if {[info exists argsArr(-error)]} {
    	    set errcode [lindex $argsArr(-error) 0]
    	    set errmsg [lindex $argsArr(-error) 1]
	}
	::UI::MessageBox -type ok -icon error \
	  -message [mc jamesserrconfgetcre $errcode $errmsg]
	set state(status) [mc jasearchwait]
	$state(wpopupserver) configure -state normal
	$state(wbtget) configure -state normal
	return
    }
    
    # We should check that we've got an 
    # <created xmlns='http://jabber.org/protocol/muc#owner'/> element.
    if {![info exists argsArr(-created)]} {
    
    }
    $jstate(jlib) muc getroom $state(roomjid)  \
      [list [namespace current]::CreateGetFormCB $token]
}

# Conference::CreateGetFormCB --
#
#

proc ::Conference::CreateGetFormCB {token jlibName type subiq} {    
    variable $token
    upvar 0 $token state
    
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Conference::CreateGetFormCB type=$type"
    
    if {![info exists state(w)]} {
	return
    }
    $state(wsearrows) stop
    set state(status) ""
    
    if {$type == "error"} {
	::UI::MessageBox -type ok -icon error -parent $state(w) \
	  -message [mc jamesserrconfgetcre [lindex $subiq 0] [lindex $subiq 1]]
	return
    }
    
    # The form part.
    set wscrollframe $state(wfrform).scform
    if {[winfo exists $wscrollframe]} {
	destroy $wscrollframe
    }
    ::UI::ScrollFrame $wscrollframe -padding {8 12} -bd 1 -relief sunken \
      -propagate 0
    pack $wscrollframe -fill both -expand 1 -pady 6

    # Compute form width using typical wraplength.
    set width [expr {$state(wraplength) - 24}]
    
    set frint [::UI::ScrollFrameInterior $wscrollframe]
    set wform $frint.f
    set formtoken [::JForms::Build $wform $subiq -tilestyle Small -width $width]
    pack $wform -fill both -expand 1
    set state(formtoken) $formtoken
    
    $state(wbtcreate) configure -default active
    $state(wbtget)    configure -default disabled
    $state(wbtcreate) state {!disabled}
    $state(wbtget)    state {!disabled}
    bind $state(w) <Return> {}
}

proc ::Conference::CreateSetRoom {token} {
    global  wDlgs
    variable $token
    upvar 0 $token state

    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Conference::CreateSetRoom"

    $state(wsearrows) stop
    
    set roomjid [jlib::joinjid $state(roomname) $state(server) ""]
    if {![jlib::jidvalidate $roomjid]} {
	::UI::MessageBox -type ok -icon error -parent $state(w) \
	  -message "Not a valid roomname"
	return
    }
    set state(roomjid) $roomjid
    
    # Submit either with or without form.
    if {[info exists state(formtoken)]} {
	set subelements [::JForms::GetXML $state(formtoken)]
    } else {
	SendCreateGet $token
	set subelements {}
    }
    
    # Ask jabberlib to create the room for us.
    if {$state(usemuc)} {
	$jstate(jlib) muc setroom $roomjid submit -form $subelements \
	  -command [list [namespace current]::CreateSetRoomCB $state(usemuc) $roomjid]
    } else {
	$jstate(jlib) conference set_create $roomjid $subelements  \
	  [list [namespace current]::CreateSetRoomCB $state(usemuc) $roomjid]
    }
    
    # This triggers the tkwait, and destroys the create dialog.
    ::UI::SaveWinGeom $wDlgs(jcreateroom) $state(w)
    set state(finished) 1
    catch {destroy $state(w)}
}

proc ::Conference::CreateSetRoomCB {usemuc roomjid jlibName type subiq} { 
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Conference::CreateSetRoomCB"
    
    if {$type == "error"} {
	::UI::MessageBox -type ok -icon error -message  \
	  [mc jamessconffailed $roomjid [lindex $subiq 0] [lindex $subiq 1]]
    } elseif {[regexp {.+@([^@]+)$} $roomjid match service]} {
		    
	# Cache groupchat protocol type (muc|conference|gc-1.0).
	if {$usemuc} {
	    ::hooks::run groupchatEnterRoomHook $roomjid "muc"
	} else {
	    ::hooks::run groupchatEnterRoomHook $roomjid "conference"
	}
    }
}

#-------------------------------------------------------------------------------
