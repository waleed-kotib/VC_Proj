#  Conference.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements enter and create dialogs for groupchat using
#      the 'jabber:iq:conference' and 'muc' protocols.
#      
#  Copyright (c) 2001-2004  Mats Bengtsson
#  
# $Id: Conference.tcl,v 1.29 2004-07-09 06:26:05 matben Exp $

package provide Conference 1.0

# This uses the 'jabber:iq:conference' namespace and therefore requires
# that we use the 'jabber:iq:browse' for this to work.
# The 'jabber:iq:conference' is in a transition to be replaced by MUC.

namespace eval ::Jabber::Conference:: {

    # Keep track of me for each room.
    # locals($roomJid,own) {room@server/hash nickname}
    variable locals
    variable uid 0
}

# Jabber::Conference::BuildEnter --
#
#       Initiates the process of entering a room using the
#       'jabber:iq:conference' method.
#       
# Arguments:
#       args        -server, -roomjid, -autoget 0/1
#       
# Results:
#       "cancel" or "enter".
     
proc ::Jabber::Conference::BuildEnter {args} {
    global  this wDlgs

    variable uid
    variable UItype 2
    variable canHeight 120
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::Conference::BuildEnter args='$args'"
    
    array set argsArr $args
    
    # State variable to collect instance specific variables.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
    
    set w $wDlgs(jenterroom)$uid    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w [mc {Enter Room}]
    set state(w) $w
    array set state {
	finished    -1
	statuscount 0
	server      ""
	roomname    ""
    }
    set fontS  [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall  -fill both -expand 1 -ipadx 12 -ipady 4
    message $w.frall.msg -width 280  -justify left  \
    	-text [mc jamessconfmsg]
    pack $w.frall.msg -side top -anchor w -padx 2 -pady 4
    set frtop $w.frall.top
    pack [frame $frtop] -side top -anchor w -padx 12
    label $frtop.lserv -text "[mc {Conference server}]:" 
    
    set confServers [$jstate(jlib) service getconferences]
    
    ::Debug 2 "\t confServers='$confServers'"

    set wpopupserver $frtop.eserv
    set wpopuproom   $frtop.eroom

    # First menubutton: servers. (trace below)
    eval {tk_optionMenu $wpopupserver $token\(server)} $confServers
    label $frtop.lroom -text "[mc {Room name}]:"
    
    # Find the default conferencing server.
    if {[info exists argsArr(-server)]} {
	set state(server) $argsArr(-server)
    } elseif {[llength $confServers]} {
	set state(server) [lindex $confServers 0]
    }
    set state(server-state) normal
    set state(room-state)   normal

    # Second menubutton: rooms for above server. Fill in below.
    set state(wroommenu) [tk_optionMenu $wpopuproom $token\(roomname) ""]

    if {[info exists argsArr(-roomjid)]} {
	regexp {^([^@]+)@([^/]+)} $argsArr(-roomjid) match state(roomname) \
	  state(server)
	set state(server-state) disabled
	set state(room-state)   disabled
	$wpopupserver configure -state disabled
	$wpopuproom   configure -state disabled
    }
    if {[info exists argsArr(-server)]} {
	set state(server) $argsArr(-server)
	set state(server-state) disabled
	$wpopupserver configure -state disabled
    }

    grid $frtop.lserv  -column 0 -row 0 -sticky e
    grid $wpopupserver -column 1 -row 0 -sticky w
    grid $frtop.lroom  -column 0 -row 1 -sticky e
    grid $wpopuproom   -column 1 -row 1 -sticky w

    # This part must be built dynamically from the 'get' xml data.
    # May be different for each conference server.
        
    if {$UItype == 0} {
	set wfr $w.frall.frlab
	labelframe $wfr -text [mc Specifications]
	pack $wfr -side top -fill both -padx 2 -pady 2
	
	set   wbox $wfr.box
	frame $wbox
	pack  $wbox -side top -fill x -padx 4 -pady 10
	pack [label $wbox.la -textvariable $token\(stattxt)]  \
	  -padx 0 -pady 10
    }
    
    if {$UItype == 2} {
	
	# Not same wbox as above!!!
	set wbox $w.frall.frmid
	::Jabber::Forms::BuildScrollForm $wbox -height $canHeight \
	  -width 240
	pack $wbox -side top -fill both -expand 1 -padx 8 -pady 4
    }
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set wbtenter  $frbot.btenter
    set wbtget    $frbot.btget
    pack [button $wbtget -text [mc Get] -default active \
      -command [list [namespace current]::EnterGet $token]]  \
      -side right -padx 5 -pady 0
    pack [button $wbtenter -text [mc Enter] -state disabled \
      -command [list [namespace current]::DoEnter $token]]  \
      -side right -padx 5 -pady 0
    pack [button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelEnter $token]]  \
      -side right -padx 5 -pady 0
    pack [frame $w.frall.pad -height 8 -width 1] -side bottom -pady 0
    pack $frbot -side bottom -fill both -expand 1 -padx 8 -pady 0
    
    # Busy arrows and status message.
    pack [frame $w.frall.st]  -side bottom -fill x -padx 8 -pady 0
    set wsearrows $w.frall.st.arr
    set wstatus   $w.frall.st.stat
    pack [::chasearrows::chasearrows $wsearrows -size 16] \
      -side left -padx 5 -pady 0
    pack [label $wstatus -textvariable $token\(status) -pady 0 -bd 0] \
      -side left -padx 5 -pady 0

    set state(wsearrows)    $wsearrows
    set state(wpopupserver) $wpopupserver
    set state(wpopuproom)   $wpopuproom
    set state(wbtget)       $wbtget
    set state(wbtenter)     $wbtenter
    set state(wbox)         $wbox
    set state(stattxt) "-- [mc jasearchwait] --"    
    
    wm resizable $w 0 0
    set oldFocus [focus]
    
    if {$state(room-state) == "normal"} {

	# Fill in room list if exist else browse.
	#if {[$jstate(browse) isbrowsed $state(server)]} {
	#	::Jabber::Conference::FillRoomList $token
	#} else {
	#	::Jabber::Conference::BusyEnterDlgIncr $token
	#	$jstate(browse) send_get $state(server)  \
	#	  [list [namespace current]::GetRoomsCB $token]
	#}

	::Jabber::Conference::ConfigRoomList $token x x x
	trace variable $token\(server) w  \
	  [list [namespace current]::ConfigRoomList $token]
    }
	    
    if {[info exists argsArr(-autoget)] && $argsArr(-autoget)} {
	
	# We seem to get 1x1 windows on Gnome if not have after idle here???
	after idle ::Jabber::Conference::EnterGet $token
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

proc ::Jabber::Conference::ConfigRoomList {token name junk1 junk2} {    
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    ::Debug 4 "::Jabber::Conference::ConfigRoomList"

    # Fill in room list if exist else browse or disco.
    #if {[$jstate(browse) isbrowsed $state(server)]} {
#	::Jabber::Conference::FillRoomList $token
    #} else {
#	::Jabber::Conference::BusyEnterDlgIncr $token
#	$jstate(browse) send_get $state(server)  \
#	  [list [namespace current]::GetRoomsCB $token]
    #}
    
    if {[$jstate(jlib) service isinvestigated $state(server)]} {
	::Jabber::Conference::FillRoomList $token
    } else {
	::Jabber::Conference::BusyEnterDlgIncr $token
	$jstate(jlib) service send_getchildren $state(server)  \
	  [list [namespace current]::GetRoomsCB $token]
    }
}

proc ::Jabber::Conference::FillRoomList {token} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    ::Debug 4 "::Jabber::Conference::FillRoomList"
    
    set roomList {}
    if {[string length $state(server)] > 0} {
	set allRooms [$jstate(jlib) service childs $state(server)]
	foreach roomJid $allRooms {
	    regexp {([^@]+)@.+} $roomJid match room
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

proc ::Jabber::Conference::BusyEnterDlgIncr {token {num 1}} {
    variable $token
    upvar 0 $token state
    
    incr state(statuscount) $num
    ::Debug 4 "::Jabber::Conference::BusyEnterDlgIncr num=$num, statuscount=$state(statuscount)"
    
    if {$state(statuscount) > 0} {
	set state(status) "Getting available rooms..." 
	$state(wsearrows) start
	$state(wpopupserver) configure -state disabled
	$state(wpopuproom)   configure -state disabled
	$state(wbtenter)     configure -state disabled
	$state(wbtget)       configure -state disabled
    } else {
	set state(statuscount) 0
	set state(status) ""
	$state(wsearrows) stop
	if {[string equal $state(server-state) "normal"]} {
	    $state(wpopupserver) configure -state normal
	}
	if {[string equal $state(room-state) "normal"]} {
	    $state(wpopuproom)   configure -state normal
	}
	$state(wbtenter)     configure -state normal
	$state(wbtget)       configure -state normal
    }
}

proc ::Jabber::Conference::GetRoomsCB {token browsename type jid subiq args} {
    
    ::Debug 4 "::Jabber::Conference::GetRoomsCB type=$type, jid=$jid"
    
    switch -- $type {
	error {
	    # ???
	}
	ok - result {
	    ::Jabber::Conference::FillRoomList $token
	}
    }
    ::Jabber::Conference::BusyEnterDlgIncr $token -1
}

proc ::Jabber::Conference::CancelEnter {token} {
    variable $token
    upvar 0 $token state

    set state(finished) 0
    catch {destroy $state(w)}
}

proc ::Jabber::Conference::EnterGet {token} {    
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    # Verify.
    if {($state(roomname) == "") || ($state(server) == "")} {
	tk_messageBox -type ok -icon error -parent $state(w) \
	  -message [FormatTextForMessageBox \
	  [mc jamessenterroomempty]]
	return
    }	
    ::Jabber::Conference::BusyEnterDlgIncr $token
    
    # Send get enter room.
    set roomJid [jlib::jidmap $state(roomname)@$state(server)]
    $jstate(jlib) conference get_enter $roomJid  \
      [list [namespace current]::EnterGetCB $token]
}

proc ::Jabber::Conference::EnterGetCB {token jlibName type subiq} {   
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    variable UItype
    
    ::Debug 2 "::Jabber::Conference::EnterGetCB type=$type, subiq='$subiq'"
    
    if {![info exists state(w)]} {
	return
    }
    ::Jabber::Conference::BusyEnterDlgIncr $token -1
    
    if {$type == "error"} {
	tk_messageBox -type ok -icon error -parent $state(w) \
	  -message [FormatTextForMessageBox \
	  [mc jamesserrconfget [lindex $subiq 0] [lindex $subiq 1]]]
	return
    }

    set childList [wrapper::getchildren $subiq]

    set wmgeom [wm geometry $state(w)]
    if {$UItype == 0} {
	catch {destroy $state(wbox)}
	::Jabber::Forms::Build $state(wbox) $childList -template "room"  \
	-width 260
	pack $state(wbox) -side top -fill x -padx 2 -pady 10
    }
    if {$UItype == 2} {
	::Jabber::Forms::FillScrollForm $state(wbox) $childList -template "room"
    }
    wm geometry $state(w) $wmgeom
}

proc ::Jabber::Conference::DoEnter {token} {   
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    variable UItype
    
    if {$UItype != 2} {
    	set subelements [::Jabber::Forms::GetXML $state(wbox)]
    } else {
    	set subelements [::Jabber::Forms::GetScrollForm $state(wbox)]
    }
    set roomJid [jlib::jidmap $state(roomname)@$state(server)]
    $jstate(jlib) conference set_enter $roomJid $subelements  \
      [list [namespace current]::ResultCallback $roomJid]
    
    # This triggers the tkwait, and destroys the enter dialog.
    set state(finished) 1
    catch {destroy $state(w)}
}

# Jabber::Conference::ResultCallback --
#
#       This is our callback procedure from 'jabber:iq:conference'.

proc ::Jabber::Conference::ResultCallback {roomJid jlibName type subiq} {
    variable locals
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::Conference::ResultCallback roomJid=$roomJid, type=$type, subiq='$subiq'"
    
    if {$type == "error"} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [mc jamessconffailed $roomJid [lindex $subiq 0] [lindex $subiq 1]]]
    } else {
	::hooks::run groupchatEnterRoomHook $roomJid "conference"
    }
}

#... Create Room ...............................................................

# Jabber::Conference::BuildCreate --
#
#       Initiates the process of creating a room.
#       
# Arguments:
#       args    -server, -roomname
#       
# Results:
#       "cancel" or "create".
     
proc ::Jabber::Conference::BuildCreate {args} {
    global  this wDlgs
    
    variable uid
    variable UItype 2
    variable canHeight 250
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Jabber::Conference::BuildCreate args='$args'"
    array set argsArr $args
    
    # State variable to collect instance specific variables.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
    
    set w $wDlgs(jcreateroom)$uid    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
    wm title $w [mc {Create Room}]
    set fontSB [option get . fontSmallBold {}]

    set state(w) $w
    array set state {
	finished    -1
	server      ""
	roomname    ""
    }
    
    # Only temporary setting of 'usemuc'.
    if {$jprefs(prefgchatproto) == "muc"} {
	set state(usemuc) 1
    } else {
	set state(usemuc) 0
    }
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 12 -ipady 4
    message $w.frall.msg -anchor w -justify left  \
      -text [mc jacreateroom] -width 300
    pack $w.frall.msg -side top -fill x -anchor w -padx 10 -pady 4
    set frtop $w.frall.top
    pack [frame $frtop] -side top -anchor w -padx 12
    label $frtop.lserv -text "[mc {Conference server}]:"
    
    set confServers [$jstate(jlib) service getconferences]

    set wpopupserver $frtop.eserv
    eval {tk_optionMenu $wpopupserver $token\(server)} $confServers
    
    # Find the default conferencing server.
    if {[llength $confServers]} {
	set state(server) [lindex $confServers 0]
    }
    if {[info exists argsArr(-server)]} {
	set state(server) $argsArr(-server)
	$frtop.eserv configure -state disabled
    }
    
    label $frtop.lroom -text "[mc {Room name}]:"    
    entry $frtop.eroom -textvariable $token\(roomname)  \
      -validate key -validatecommand {::Jabber::ValidateUsernameStr %S}
    label $frtop.lnick -text "[mc {Nick name}]:"    
    entry $frtop.enick -textvariable $token\(nickname)  \
      -validate key -validatecommand {::Jabber::ValidateResourceStr %S}
    label $frtop.ldesc -text "[mc Specifications]:"
    label $frtop.lstat -textvariable $token\(stattxt)
    
    grid $frtop.lserv -column 0 -row 0 -sticky e
    grid $frtop.eserv -column 1 -row 0 -sticky ew
    grid $frtop.lroom -column 0 -row 1 -sticky e
    grid $frtop.eroom -column 1 -row 1 -sticky ew
    grid $frtop.lnick -column 0 -row 2 -sticky e
    grid $frtop.enick -column 1 -row 2 -sticky ew
    grid $frtop.ldesc -column 0 -row 3 -sticky e -padx 4 -pady 2
    grid $frtop.lstat -column 1 -row 3 -sticky w
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set wsearrows $frbot.arr
    set wbtenter $frbot.btenter
    set wbtget $frbot.btget
    pack [button $wbtget -text [mc Get] -default active \
      -command [list [namespace current]::CreateGet $token]]  \
      -side right -padx 5 -pady 5
    pack [button $wbtenter -text [mc Create] -state disabled \
      -command [list [namespace current]::DoCreate $token]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelCreate $token]]  \
      -side right -padx 5 -pady 5
    pack [::chasearrows::chasearrows $wsearrows -size 16] \
      -side left -padx 5 -pady 5
    pack $frbot -side bottom -fill x -expand 0 -padx 8 -pady 6
	
    # This part must be built dynamically from the 'get' xml data.
    # May be different for each conference server.
    
    if {$UItype == 0} {
	set wfr $w.frall.frlab
	labelframe $wfr -text [mc Specifications]
	pack $wfr -side top -fill both -padx 2 -pady 2
	
	set   wbox $wfr.box
	frame $wbox
	pack  $wbox -side top -fill x -padx 4 -pady 10
	pack [label $wbox.la -textvariable $token\(stattxt)]  \
	  -padx 0 -pady 10
    }
    
    if {$UItype == 2} {
	
	# Not same wbox as above!!!
	set wbox $w.frall.frmid
	::Jabber::Forms::BuildScrollForm $wbox -height $canHeight \
	  -width 320
	pack $wbox -side top -fill both -expand 1 -padx 8 -pady 4
    }
    
    set state(wsearrows) $wsearrows
    set state(wpopupserver) $wpopupserver
    set state(wbtget) $wbtget
    set state(wbtenter) $wbtenter
    set state(wbox) $wbox
    set state(stattxt) "-- [mc jasearchwait] --"
    
    bind $w <Return> [list $wbtget invoke]
    
    # Grab and focus.
    focus $frtop.eroom
    
    # Wait here for a button press and window to be destroyed. BAD?
    tkwait window $w
    
    catch {focus $oldFocus}
    set finished $state(finished)
    unset state
    return [expr {($finished <= 0) ? "cancel" : "create"}]
}

proc ::Jabber::Conference::CancelCreate {token} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    set roomJid [jlib::jidmap $state(roomname)@$state(server)]
    if {$state(usemuc) && ($roomJid != "")} {
	catch {$jstate(muc) setroom $roomJid cancel}
    }
    set state(finished) 0
    catch {destroy $state(w)}
}

proc ::Jabber::Conference::CreateGet {token} {    
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs

    # Figure out if 'conference' or 'muc' protocol.
    if {$jprefs(prefgchatproto) == "muc"} {
	set state(usemuc) [$jstate(jlib) service hasfeature $state(server)  \
	  "http://jabber.org/protocol/muc"]
    } else {
	set state(usemuc) 0
    }
    
    # Verify.
    if {($state(server) == "") || ($state(roomname) == "") || \
    ($state(usemuc) && ($state(nickname) == ""))} {
	tk_messageBox -type ok -icon error -parent $state(w) \
	  -message "Must provide a nickname to use in the room"
	return
    }	
    $state(wpopupserver) configure -state disabled
    $state(wbtget) configure -state disabled
    set state(stattxt) "-- [mc jawaitserver] --"
    
    # Send get create room. NOT the server!
    set roomJid [jlib::jidmap $state(roomname)@$state(server)]
    set state(roomjid) $roomJid

    ::Debug 2 "::Jabber::Conference::CreateGet usemuc=$state(usemuc)"

    if {$state(usemuc)} {
	$jstate(muc) create $roomJid $state(nickname) \
	  [list [namespace current]::CreateMUCCB $token]
    } else {
	$jstate(jlib) conference get_create $roomJid  \
	  [list [namespace current]::CreateGetGetCB $token]
    }

    $state(wsearrows) start
}

# Jabber::Conference::CreateMUCCB --
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

proc ::Jabber::Conference::CreateMUCCB {token jlibName type args} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::Conference::CreateMUCCB type=$type, args='$args'"
    
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
	tk_messageBox -type ok -icon error -parent $state(w) \
	  -message [FormatTextForMessageBox \
	  [mc jamesserrconfgetcre $errcode $errmsg]]
        set state(stattxt) "-- [mc jasearchwait] --"
        $state(wpopupserver) configure -state normal
        $state(wbtget) configure -state normal
	return
    }
    
    # We should check that we've got an 
    # <created xmlns='http://jabber.org/protocol/muc#owner'/> element.
    if {![info exists argsArr(-created)]} {
    
    }
    $jstate(muc) getroom $state(roomjid)  \
      [list [namespace current]::CreateGetGetCB $token]
}

# Jabber::Conference::CreateGetGetCB --
#
#

proc ::Jabber::Conference::CreateGetGetCB {token jlibName type subiq} {    
    variable $token
    upvar 0 $token state
    
    variable UItype
    variable canHeight
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::Conference::CreateGetGetCB type=$type"
    
    if {![info exists state(w)]} {
	return
    }
    $state(wsearrows) stop
    set state(stattxt) ""
    
    if {$type == "error"} {
	tk_messageBox -type ok -icon error -parent $state(w) \
	  -message [FormatTextForMessageBox \
	  [mc jamesserrconfgetcre [lindex $subiq 0] [lindex $subiq 1]]]
	return
    }

    set childList [wrapper::getchildren $subiq]

    if {$UItype == 0} {
	catch {destroy $state(wbox)}
	::Jabber::Forms::Build $state(wbox) $childList -template "room" -width 320
	pack $state(wbox) -side top -fill x -padx 2 -pady 10
    }
    if {$UItype == 2} {
	::Jabber::Forms::FillScrollForm $state(wbox) $childList -template "room"
    }
    
    $state(wbtenter) configure -state normal -default active
    $state(wbtget) configure -state normal -default disabled
    bind $state(w) <Return> {}
}

proc ::Jabber::Conference::DoCreate {token} {   
    variable $token
    upvar 0 $token state

    variable UItype
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::Conference::DoCreate"

    $state(wsearrows) stop
    
    set roomJid [jlib::jidmap $state(roomname)@$state(server)]
    set state(roomjid) $roomJid
    if {$UItype != 2} {
    	set subelements [::Jabber::Forms::GetXML $state(wbox)]
    } else {
    	set subelements [::Jabber::Forms::GetScrollForm $state(wbox)]
    }
    
    # Ask jabberlib to create the room for us.
    if {$state(usemuc)} {
	$jstate(muc) setroom $roomJid submit -form $subelements \
	  -command [list [namespace current]::DoCreateCallback $state(usemuc) $roomJid]
    } else {
	$jstate(jlib) conference set_create $roomJid $subelements  \
	  [list [namespace current]::DoCreateCallback $state(usemuc) $roomJid]
    }
    
    # This triggers the tkwait, and destroys the create dialog.
    set state(finished) 1
    catch {destroy $state(w)}
}

proc ::Jabber::Conference::DoCreateCallback {usemuc roomJid jlibName type subiq} { 
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::Conference::DoCreateCallback"
    
    if {$type == "error"} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [mc jamessconffailed $roomJid [lindex $subiq 0] [lindex $subiq 1]]]
    } elseif {[regexp {.+@([^@]+)$} $roomJid match service]} {
		    
	# Cache groupchat protocol type (muc|conference|gc-1.0).
	if {$usemuc} {
	    ::hooks::run groupchatEnterRoomHook $roomJid "muc"
	} else {
	    ::hooks::run groupchatEnterRoomHook $roomJid "conference"
	}
    }
}

#-------------------------------------------------------------------------------
