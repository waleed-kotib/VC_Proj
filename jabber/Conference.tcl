#  Conference.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements conference parts for jabber.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
# $Id: Conference.tcl,v 1.10 2004-01-30 15:33:50 matben Exp $

package provide Conference 1.0

# This uses the 'jabber:iq:conference' namespace and therefore requires
# that we use the 'jabber:iq:browse' for this to work.
# We only handle the enter/create dialogs here since the rest is handled
# in ::GroupChat::
# The 'jabber:iq:conference' is in a transition to be replaced by MUC.
# 
# Added MUC stuff...

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
#       args        -server, -roomjid, -roomname, -autoget 0/1
#       
# Results:
#       "cancel" or "enter".
     
proc ::Jabber::Conference::BuildEnter {args} {
    global  this wDlgs

    variable uid
    variable UItype 2
    variable canHeight 120
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Conference::BuildEnter"
    array set argsArr $args
    
    # State variable to collect instance specific variables.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
    
    set w $wDlgs(jenterroom)$uid    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w [::msgcat::mc {Enter Room}]
    set state(w) $w
    array set state {
	finished    -1
	statuscount 0
	server      ""
	roomname    ""
    }
    set fontS [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    message $w.frall.msg -width 280  -justify left  \
    	-text [::msgcat::mc jamessconfmsg]
    pack $w.frall.msg -side top -anchor w -padx 2 -pady 4
    set frtop $w.frall.top
    pack [frame $frtop] -side top -fill x
    label $frtop.lserv -text "[::msgcat::mc {Conference server}]:" 
    
    set confServers [$jstate(browse) getconferenceservers]
    
    ::Jabber::Debug 2 "BuildEnterRoom: confServers='$confServers'"

    set wcomboserver $frtop.eserv
    set wcomboroom   $frtop.eroom

    # First combobox: servers.
    ::combobox::combobox $wcomboserver -width 20  \
      -textvariable $token\(server) -editable 0  \
      -command [list [namespace current]::ConfigRoomList $token]
    eval {$frtop.eserv list insert end} $confServers
    label $frtop.lroom -text "[::msgcat::mc {Room name}]:"
    
    # Find the default conferencing server.
    if {[info exists argsArr(-server)]} {
	set state(server) $argsArr(-server)
    } elseif {[llength $confServers]} {
	set state(server) [lindex $confServers 0]
    }

    # Second combobox: rooms for above server. Fill in below.
    ::combobox::combobox $wcomboroom -width 20  \
      -textvariable $token\(roomname) -editable 0

    if {[info exists argsArr(-roomjid)]} {
	regexp {^([^@]+)@([^/]+)} $argsArr(-roomjid) match state(roomname)  \
	  state(server)	
	$wcomboserver configure -state disabled
	$wcomboroom configure -state disabled
    }
    if {[info exists argsArr(-server)]} {
	set state(server) $argsArr(-server)
	$wcomboserver configure -state disabled
    }
    if {[info exists argsArr(-roomname)]} {
	set state(roomname) $argsArr(-roomname)
	$wcomboroom configure -state disabled
    }

    grid $frtop.lserv -column 0 -row 0 -sticky e
    grid $frtop.eserv -column 1 -row 0 -sticky w
    grid $frtop.lroom -column 0 -row 1 -sticky e
    grid $frtop.eroom -column 1 -row 1 -sticky w

    # This part must be built dynamically from the 'get' xml data.
    # May be different for each conference server.
        
    if {$UItype == 0} {
	set wfr $w.frall.frlab
	set wcont [::mylabelframe::mylabelframe $wfr [::msgcat::mc Specifications]]
	pack $wfr -side top -fill both -padx 2 -pady 2
	
	set wbox $wcont.box
	frame $wbox
	pack $wbox -side top -fill x -padx 4 -pady 10
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
    pack [button $wbtget -text [::msgcat::mc Get] -width 8 -default active \
      -command [list [namespace current]::EnterGet $token]]  \
      -side right -padx 5 -pady 0
    pack [button $wbtenter -text [::msgcat::mc Enter] -width 8 -state disabled \
      -command [list [namespace current]::DoEnter $token]]  \
      -side right -padx 5 -pady 0
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel]  \
      -command [list [namespace current]::CancelEnter $token]]  \
      -side right -padx 5 -pady 0
    pack [frame $w.frall.pad -height 8 -width 1] -side bottom -pady 0
    pack $frbot -side bottom -fill both -expand 1 -padx 8 -pady 0
    
    # Busy arrows and status message.
    pack [frame $w.frall.st]  -side bottom -fill x -padx 8 -pady 0
    set wsearrows $w.frall.st.arr
    set wstatus   $w.frall.st.stat
    pack [::chasearrows::chasearrows $wsearrows -size 16] \
      -side left -padx 5 -pady 5
    pack [label $wstatus -textvariable $token\(status)] \
      -side left -padx 5 -pady 5

    set state(wsearrows)    $wsearrows
    set state(wcomboserver) $wcomboserver
    set state(wcomboroom)   $wcomboroom
    set state(wbtget)       $wbtget
    set state(wbtenter)     $wbtenter
    set state(wbox)         $wbox
    set state(stattxt) "-- [::msgcat::mc jasearchwait] --"    
            
    if {[info exists argsArr(-autoget)] && $argsArr(-autoget)} {
	::Jabber::Conference::EnterGet $token
    }

    # Fill in room list if exist else browse.
    if {[$jstate(browse) isbrowsed $state(server)]} {
	::Jabber::Conference::FillRoomList $token
    } else {
	::Jabber::Conference::BusyEnterDlgIncr $token
	::Jabber::InvokeJlibCmd browse_get $state(server)  \
	  -command [list [namespace current]::BrowseServiceCB $token]
    }
	
    wm resizable $w 0 0
    set oldFocus [focus]
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w

    catch {focus $oldFocus}
    set finished $state(finished)
    unset state
    return [expr {($finished <= 0) ? "cancel" : "enter"}]
}

proc ::Jabber::Conference::ConfigRoomList {token wcombo confserver} {    
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate

    # Fill in room list if exist else browse.
    if {[$jstate(browse) isbrowsed $state(server)]} {
	::Jabber::MUC::FillRoomList $token
    } else {
	::Jabber::MUC::BusyEnterDlgIncr $token
	::Jabber::InvokeJlibCmd browse_get $state(server)  \
	  -command [list [namespace current]::BrowseServiceCB $token]
    }
}

proc ::Jabber::Conference::FillRoomList {token} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    set roomList {}
    if {[string length $state(server)] > 0} {
	set allRooms [$jstate(browse) getchilds $state(server)]
	foreach roomJid $allRooms {
	    regexp {([^@]+)@.+} $roomJid match room
	    lappend roomList $room
	}
    }
    $state(wcomboroom) list delete 0 end
    eval {$state(wcomboroom) list insert end} $roomList
    set state(roomname) [lindex $roomList 0]
}

proc ::Jabber::Conference::BusyEnterDlgIncr {token {num 1}} {
    variable $token
    upvar 0 $token state
    
    incr state(statuscount) $num
    
    if {$state(statuscount) > 0} {
	set state(status) "Getting rooms..." 
	$state(wsearrows) start
	$state(wcomboserver) configure -state disabled
	$state(wcomboroom)   configure -state disabled
	$state(wbtenter)     configure -state disabled
    } else {
	set state(statuscount) 0
	set state(status) ""
	$state(wsearrows) stop
	$state(wcomboserver) configure -state normal
	$state(wcomboroom)   configure -state normal
	$state(wbtenter)     configure -state normal
    }
}

proc ::Jabber::Conference::BrowseServiceCB {token browsename type jid subiq} {
    
    ::Jabber::Conference::FillRoomList $token
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
	  [::msgcat::mc jamessenterroomempty]]
	return
    }	
    $state(wcomboserver) configure -state disabled
    $state(wcomboroom) configure -state disabled
    $state(wbtget) configure -state disabled
    set state(stattxt) "-- [::msgcat::mc jawaitserver] --"
    
    # Send get enter room.
    set roomJid [string tolower $state(roomname)@$state(server)]
    
    ::Jabber::InvokeJlibCmd conference get_enter $roomJid  \
      [list [namespace current]::EnterGetCB $token]

    $state(wsearrows) start
}

proc ::Jabber::Conference::EnterGetCB {token jlibName type subiq} {   
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    variable UItype
    
    ::Jabber::Debug 2 "::Jabber::Conference::EnterGetCB type=$type, subiq='$subiq'"
    
    if {![info exists state(w)]} {
	return
    }
    $state(wsearrows) stop
    
    if {$type == "error"} {
	tk_messageBox -type ok -icon error -parent $state(w) \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrconfget [lindex $subiq 0] [lindex $subiq 1]]]
	return
    }
    $state(wbtenter) configure -state normal -default active
    $state(wbtget) configure -state normal -default disabled

    set childList [wrapper::getchildren $subiq]

    if {$UItype == 0} {
	catch {destroy $state(wbox)}
	::Jabber::Forms::Build $state(wbox) $childList -template "room"  \
	-width 260
	pack $state(wbox) -side top -fill x -padx 2 -pady 10
    }
    if {$UItype == 2} {
	::Jabber::Forms::FillScrollForm $state(wbox) $childList -template "room"
    }
}

proc ::Jabber::Conference::DoEnter {token} {   
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    variable UItype
    
    $state(wsearrows) start

    if {$UItype != 2} {
    	set subelements [::Jabber::Forms::GetXML $state(wbox)]
    } else {
    	set subelements [::Jabber::Forms::GetScrollForm $state(wbox)]
    }
    set roomJid [string tolower $state(roomname)@$state(server)]
    ::Jabber::InvokeJlibCmd conference set_enter $roomJid $subelements  \
      [list [namespace current]::ResultCallback $roomJid]
    
    # This triggers the tkwait, and destroys the enter dialog.
    set state(finished) 1
    catch {destroy $state(w)}
}

# Jabber::Conference::ResultCallback --
#
#       This is our callback procedure from 'jabber:iq:conference' and muc stuffs.

proc ::Jabber::Conference::ResultCallback {roomJid jlibName type subiq} {
    variable locals
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Conference::ResultCallback roomJid=$roomJid, type=$type, subiq='$subiq'"
    
    if {$type == "error"} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessconffailed $roomJid [lindex $subiq 0] [lindex $subiq 1]]]
    } else {
	
	# Handle the wb UI. Could be the room's name.
	#set jstate(.,tojid) $roomJid
    
	# This should be something like:
	# <query><id>myroom@server/7y3jy7f03</id><nick/>snuffie<nick><query/>
	# Use it to cache own room jid.
	
	#  OUTDATED!!!!!!!!!!!!!
	
	foreach child [wrapper::getchildren $subiq] {
	    set tagName [lindex $child 0]
	    set value [lindex $child 3]
	    set $tagName $value
	}
	if {[info exists id] && [info exists nick]} {
	    set locals($roomJid,own) [list $id $nick]
	}
	if {[info exists name]} {
	    set locals($roomJid,roomname) $name
	}
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
    
    ::Jabber::Debug 2 "::Jabber::Conference::BuildCreate args='$args'"
    array set argsArr $args
    
    # State variable to collect instance specific variables.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
    
    set w $wDlgs(jcreateroom)$uid    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
    wm title $w [::msgcat::mc {Create Room}]
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
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    message $w.frall.msg -anchor w -justify left  \
      -text [::msgcat::mc jacreateroom] -width 300
    pack $w.frall.msg -side top -fill x -anchor w -padx 10 -pady 4
    set frtop $w.frall.top
    pack [frame $frtop] -side top -expand 0 -anchor w -padx 10
    label $frtop.lserv -text "[::msgcat::mc {Conference server}]:"  \
      -font $fontSB
    
    set confServers [$jstate(browse) getconferenceservers]
    set wcomboserver $frtop.eserv
    ::combobox::combobox $wcomboserver -width 20  \
      -textvariable $token\(server) -editable 0
    eval {$frtop.eserv list insert end} $confServers
    
    # Find the default conferencing server.
    if {[llength $confServers]} {
	set state(server) [lindex $confServers 0]
    }
    if {[info exists argsArr(-server)]} {
	set state(server) $argsArr(-server)
	$frtop.eserv configure -state disabled
    }
    
    label $frtop.lroom -text "[::msgcat::mc {Room name}]:" \
      -font $fontSB    
    entry $frtop.eroom -textvariable $token\(roomname)  \
      -validate key -validatecommand {::Jabber::ValidateJIDChars %S}
    label $frtop.lnick -text "[::msgcat::mc {Nick name}]:"  \
      -font $fontSB    
    entry $frtop.enick -textvariable $token\(nickname)  \
      -validate key -validatecommand {::Jabber::ValidateJIDChars %S}
    label $frtop.ldesc -text "[::msgcat::mc Specifications]:" -font $fontSB
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
    pack [button $wbtget -text [::msgcat::mc Get] -width 8 -default active \
      -command [list [namespace current]::CreateGet $token]]  \
      -side right -padx 5 -pady 5
    pack [button $wbtenter -text [::msgcat::mc Create] -width 8 -state disabled \
      -command [list [namespace current]::DoCreate $token]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel]  \
      -command [list [namespace current]::CancelCreate $token]]  \
      -side right -padx 5 -pady 5
    pack [::chasearrows::chasearrows $wsearrows -size 16] \
      -side left -padx 5 -pady 5
    pack $frbot -side bottom -fill x -expand 0 -padx 8 -pady 6
	
    # This part must be built dynamically from the 'get' xml data.
    # May be different for each conference server.
    
    if {$UItype == 0} {
	set wfr $w.frall.frlab
	set wcont [::mylabelframe::mylabelframe $wfr [::msgcat::mc Specifications]]
	pack $wfr -side top -fill both -padx 2 -pady 2
	
	set wbox $wcont.box
	frame $wbox
	pack $wbox -side top -fill x -padx 4 -pady 10
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
    set state(wcomboserver) $wcomboserver
    set state(wbtget) $wbtget
    set state(wbtenter) $wbtenter
    set state(wbox) $wbox
    set state(stattxt) "-- [::msgcat::mc jasearchwait] --"
    
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
    
    set roomJid [string tolower $state(roomname)@$state(server)]
    if {$state(usemuc) && ($roomJid != "")} {
	catch {::Jabber::InvokeJlibCmd muc setroom $roomJid cancel}
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
	set state(usemuc) [$jstate(browse) havenamespace $state(server)  \
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
    $state(wcomboserver) configure -state disabled
    $state(wbtget) configure -state disabled
    set state(stattxt) "-- [::msgcat::mc jawaitserver] --"
    
    # Send get create room. NOT the server!
    set roomJid [string tolower $state(roomname)@$state(server)]
    set state(roomjid) $roomJid

    ::Jabber::Debug 2 "::Jabber::Conference::CreateGet usemuc=$state(usemuc)"

    if {$state(usemuc)} {
	::Jabber::InvokeJlibCmd muc create $roomJid $state(nickname) \
	  [list [namespace current]::CreateMUCCB $token]
    } else {
	::Jabber::InvokeJlibCmd conference get_create $roomJid  \
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
    
    ::Jabber::Debug 2 "::Jabber::Conference::CreateMUCCB type=$type, args='$args'"
    
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
	  [::msgcat::mc jamesserrconfgetcre $errcode $errmsg]]
        set state(stattxt) "-- [::msgcat::mc jasearchwait] --"
        $state(wcomboserver) configure -state normal
        $state(wbtget) configure -state normal
	return
    }
    
    # We should check that we've got an 
    # <created xmlns='http://jabber.org/protocol/muc#owner'/> element.
    if {![info exists argsArr(-created)]} {
    
    }
    ::Jabber::InvokeJlibCmd muc getroom $state(roomjid)  \
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
    
    ::Jabber::Debug 2 "::Jabber::Conference::CreateGetGetCB type=$type"
    
    if {![info exists state(w)]} {
	return
    }
    $state(wsearrows) stop
    set state(stattxt) ""
    
    if {$type == "error"} {
	tk_messageBox -type ok -icon error -parent $state(w) \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrconfgetcre [lindex $subiq 0] [lindex $subiq 1]]]
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
    
    ::Jabber::Debug 2 "::Jabber::Conference::DoCreate"

    $state(wsearrows) stop
    
    set roomJid [string tolower $state(roomname)@$state(server)]
    if {$UItype != 2} {
    	set subelements [::Jabber::Forms::GetXML $state(wbox)]
    } else {
    	set subelements [::Jabber::Forms::GetScrollForm $state(wbox)]
    }
    
    # Ask jabberlib to create the room for us.
    if {$state(usemuc)} {
	::Jabber::InvokeJlibCmd muc setroom $roomJid form -form $subelements \
	  -command [list [namespace current]::ResultCallback $roomJid]
    } else {
	::Jabber::InvokeJlibCmd conference set_create $roomJid $subelements  \
	  [list [namespace current]::ResultCallback $roomJid]
    }
	
    # Cache groupchat protocol type (muc|conference|gc-1.0).
    if {$state(usemuc)} {
	::Jabber::GroupChat::SetProtocol $roomJid "muc"
    } else {
	::Jabber::GroupChat::SetProtocol $roomJid "conference"
    }
    
    # This triggers the tkwait, and destroys the create dialog.
    set state(finished) 1
    catch {destroy $state(w)}
}

#-------------------------------------------------------------------------------
