#  Conference.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements conference parts for jabber.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
# $Id: Conference.tcl,v 1.6 2004-01-13 14:50:20 matben Exp $

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
    variable enteruid 0
    variable createuid 0

    variable dlguid 0
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

    variable enteruid
    variable dlguid
    variable UItype 2
    variable canHeight 120
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Conference::BuildEnter"
    array set argsArr $args
    
    # State variable to collect instance specific variables.
    set token [namespace current]::enter[incr enteruid]
    variable $token
    upvar 0 $token enter
    
    set w $wDlgs(jenterroom)[incr dlguid]    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
    wm title $w [::msgcat::mc {Enter Room}]
    set enter(w) $w
    array set enter {
	finished    -1
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
    label $frtop.lserv -text "[::msgcat::mc {Conference server}]:" \
      -font $fontSB 
    
    set confServers [$jstate(browse) getconferenceservers]
    
    ::Jabber::Debug 2 "BuildEnterRoom: confServers='$confServers'"

    set wcomboserver $frtop.eserv
    set wcomboroom $frtop.eroom

    ::combobox::combobox $wcomboserver -width 20  \
      -textvariable $token\(server) -editable 0  \
      -command [list [namespace current]::ConfigRoomList $wcomboroom]
    eval {$frtop.eserv list insert end} $confServers
    label $frtop.lroom -text "[::msgcat::mc {Room name}]:" -font $fontSB
    
    # Find the default conferencing server.
    if {[info exists argsArr(-server)]} {
	set enter(server) $argsArr(-server)
    } elseif {[llength $confServers]} {
	set enter(server) [lindex $confServers 0]
    }
    set roomList {}
    if {[string length $enter(server)] > 0} {
	set allRooms [$jstate(browse) getchilds $enter(server)]
	
	::Jabber::Debug 2 "BuildEnterRoom: allRooms='$allRooms'"
	
	foreach roomJid $allRooms {
	    regexp {([^@]+)@.+} $roomJid match room
	    lappend roomList $room
	}
    }
    ::combobox::combobox $wcomboroom -width 20  \
      -textvariable $token\(roomname) -editable 0
    eval {$frtop.eroom list insert end} $roomList
    if {[info exists argsArr(-roomjid)]} {
	regexp {^([^@]+)@([^/]+)} $argsArr(-roomjid) match enter(roomname)  \
	  enter(server)	
	$wcomboserver configure -state disabled
	$wcomboroom configure -state disabled
    }
    if {[info exists argsArr(-server)]} {
	set enter(server) $argsArr(-server)
	$wcomboserver configure -state disabled
    }
    if {[info exists argsArr(-roomname)]} {
	set enter(roomname) $argsArr(-roomname)
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
    set wsearrows $frbot.arr
    set wbtenter $frbot.btenter
    set wbtget $frbot.btget
    pack [button $wbtget -text [::msgcat::mc Get] -width 8 -default active \
      -command [list [namespace current]::EnterGet $token]]  \
      -side right -padx 5 -pady 5
    pack [button $wbtenter -text [::msgcat::mc Enter] -width 8 -state disabled \
      -command [list [namespace current]::DoEnter $token]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command [list [namespace current]::CancelEnter $token]]  \
      -side right -padx 5 -pady 5
    pack [::chasearrows::chasearrows $wsearrows -size 16] \
      -side left -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
        
    wm resizable $w 0 0

    set enter(wsearrows) $wsearrows
    set enter(wcomboserver) $wcomboserver
    set enter(wcomboroom) $wcomboroom
    set enter(wbtget) $wbtget
    set enter(wbtenter) $wbtenter
    set enter(wbox) $wbox
    set enter(stattxt) "-- [::msgcat::mc jasearchwait] --"    
        
    # Grab and focus.
    set oldFocus [focus]
    
    if {[info exists argsArr(-autoget)] && $argsArr(-autoget)} {
	::Jabber::Conference::EnterGet $token
    }
    #bind $w <Return> "$wbtget invoke"
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w

    catch {focus $oldFocus}
    set finished $enter(finished)
    unset enter
    return [expr {($finished <= 0) ? "cancel" : "enter"}]
}

proc ::Jabber::Conference::CancelEnter {token} {
    variable $token
    upvar 0 $token enter

    set enter(finished) 0
    catch {destroy $enter(w)}
}

proc ::Jabber::Conference::ConfigRoomList {wcomboroom wcombo pickedServ} {    
    upvar ::Jabber::jstate jstate

    set allRooms [$jstate(browse) getchilds $pickedServ]
    set roomList {}
    foreach roomJid $allRooms {
	regexp {([^@]+)@.+} $roomJid match room
	lappend roomList $room
    }
    $wcomboroom list delete 0 end
    eval {$wcomboroom list insert end} $roomList
}

proc ::Jabber::Conference::EnterGet {token} {    
    variable $token
    upvar 0 $token enter
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    # Verify.
    if {($enter(roomname) == "") || ($enter(server) == "")} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessenterroomempty]]
	return
    }	
    $enter(wcomboserver) configure -state disabled
    $enter(wcomboroom) configure -state disabled
    $enter(wbtget) configure -state disabled
    set enter(stattxt) "-- [::msgcat::mc jawaitserver] --"
    
    # Send get enter room.
    set roomJid [string tolower $enter(roomname)@$enter(server)]
    
    $jstate(jlib) conference get_enter $roomJid  \
      [list [namespace current]::EnterGetCB $token]

    $enter(wsearrows) start
}

proc ::Jabber::Conference::EnterGetCB {token jlibName type subiq} {   
    variable $token
    upvar 0 $token enter
    upvar ::Jabber::jstate jstate
    variable UItype
    
    ::Jabber::Debug 2 "::Jabber::Conference::EnterGetCB type=$type, subiq='$subiq'"
    
    if {![info exists enter(w)]} {
	return
    }
    $enter(wsearrows) stop
    
    if {$type == "error"} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrconfget [lindex $subiq 0] [lindex $subiq 1]]]
	return
    }
    $enter(wbtenter) configure -state normal -default active
    $enter(wbtget) configure -state normal -default disabled

    set childList [wrapper::getchildren $subiq]

    if {$UItype == 0} {
	catch {destroy $enter(wbox)}
	::Jabber::Forms::Build $enter(wbox) $childList -template "room"  \
	-width 260
	pack $enter(wbox) -side top -fill x -padx 2 -pady 10
    }
    if {$UItype == 2} {
	::Jabber::Forms::FillScrollForm $enter(wbox) $childList -template "room"
    }
}

proc ::Jabber::Conference::DoEnter {token} {   
    variable $token
    upvar 0 $token enter
    upvar ::Jabber::jstate jstate
    variable UItype
    
    $enter(wsearrows) start

    if {$UItype != 2} {
    	set subelements [::Jabber::Forms::GetXML $enter(wbox)]
    } else {
    	set subelements [::Jabber::Forms::GetScrollForm $enter(wbox)]
    }
    set roomJid [string tolower $enter(roomname)@$enter(server)]
    $jstate(jlib) conference set_enter $roomJid $subelements  \
      [list [namespace current]::ResultCallback $roomJid]
    
    # This triggers the tkwait, and destroys the enter dialog.
    set enter(finished) 1
    catch {destroy $enter(w)}
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
    
    variable createuid
    variable dlguid
    variable UItype 2
    variable canHeight 250
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    array set argsArr $args
    
    # State variable to collect instance specific variables.
    set token [namespace current]::create[incr createuid]
    variable $token
    upvar 0 $token create
    
    set w $wDlgs(jcreateroom)[incr dlguid]    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
    wm title $w [::msgcat::mc {Create Room}]
    set fontSB [option get . fontSmallBold {}]

    set create(w) $w
    array set create {
	finished    -1
	server      ""
	roomname    ""
    }
    
    # Only temporary setting of 'usemuc'.
    if {$jprefs(prefgchatproto) == "muc"} {
	set create(usemuc) 1
    } else {
	set create(usemuc) 0
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
	set create(server) [lindex $confServers 0]
    }
    if {[info exists argsArr(-server)]} {
	set create(server) $argsArr(-server)
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
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
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
    
    set create(wsearrows) $wsearrows
    set create(wcomboserver) $wcomboserver
    set create(wbtget) $wbtget
    set create(wbtenter) $wbtenter
    set create(wbox) $wbox
    set create(stattxt) "-- [::msgcat::mc jasearchwait] --"
    
    bind $w <Return> [list $wbtget invoke]
    
    # Grab and focus.
    focus $frtop.eroom
    
    # Wait here for a button press and window to be destroyed. BAD?
    tkwait window $w
    
    catch {focus $oldFocus}
    set finished $create(finished)
    unset create
    return [expr {($finished <= 0) ? "cancel" : "create"}]
}

proc ::Jabber::Conference::CancelCreate {token} {
    variable $token
    upvar 0 $token create
    upvar ::Jabber::jstate jstate
    
    set roomJid [string tolower $create(roomname)@$create(server)]
    if {$create(usemuc) && ($roomJid != "")} {
	catch {$jstate(jlib) muc setroom $roomJid cancel}
    }
    set create(finished) 0
    catch {destroy $create(w)}
}

proc ::Jabber::Conference::CreateGet {token} {    
    variable $token
    upvar 0 $token create
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs

    # Figure out if 'conference' or 'muc' protocol.
    if {$jprefs(prefgchatproto) == "muc"} {
	set create(usemuc) [$jstate(browse) havenamespace $create(server)  \
	  "http://jabber.org/protocol/muc"]
    } else {
	set create(usemuc) 0
    }
    
    # Verify.
    if {($create(server) == "") || ($create(roomname) == "") || \
    ($create(usemuc) && ($create(nickname) == ""))} {
	tk_messageBox -type ok -icon error  \
	  -message "Must provide a nickname to use in the room"
	return
    }	
    $create(wcomboserver) configure -state disabled
    $create(wbtget) configure -state disabled
    set create(stattxt) "-- [::msgcat::mc jawaitserver] --"
    
    # Send get create room. NOT the server!
    set roomJid [string tolower $create(roomname)@$create(server)]
    set create(roomjid) $roomJid

    ::Jabber::Debug 2 "::Jabber::Conference::CreateGet usemuc=$create(usemuc)"

    if {$create(usemuc)} {
	$jstate(jlib) muc create $roomJid $create(nickname) \
	  [list [namespace current]::CreateMUCCB $token]
    } else {
	$jstate(jlib) conference get_create $roomJid  \
	  [list [namespace current]::CreateGetGetCB $token]
    }

    $create(wsearrows) start
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
    upvar 0 $token create
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Conference::CreateMUCCB type=$type, args='$args'"
    
    if {![info exists create(w)]} {
	return
    }
    $create(wsearrows) stop
    array set argsArr $args
    
    if {$type == "error"} {
    	set errcode ???
    	set errmsg ""
    	if {[info exists argsArr(-error)]} {
    	    set errcode [lindex $argsArr(-error) 0]
    	    set errmsg [lindex $argsArr(-error) 1]
	}
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrconfgetcre $errcode $errmsg]]
        set create(stattxt) "-- [::msgcat::mc jasearchwait] --"
        $create(wcomboserver) configure -state normal
        $create(wbtget) configure -state normal
	return
    }
    
    # We should check that we've got an 
    # <created xmlns='http://jabber.org/protocol/muc#owner'/> element.
    if {![info exists argsArr(-created)]} {
    
    }
    $jstate(jlib) muc getroom $create(roomjid)  \
      [list [namespace current]::CreateGetGetCB $token]
}

# Jabber::Conference::CreateGetGetCB --
#
#

proc ::Jabber::Conference::CreateGetGetCB {token jlibName type subiq} {    
    variable $token
    upvar 0 $token create
    
    variable UItype
    variable canHeight
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Conference::CreateGetGetCB type=$type"
    
    if {![info exists create(w)]} {
	return
    }
    $create(wsearrows) stop
    set create(stattxt) ""
    
    if {$type == "error"} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrconfgetcre [lindex $subiq 0] [lindex $subiq 1]]]
	return
    }

    set childList [wrapper::getchildren $subiq]

    if {$UItype == 0} {
	catch {destroy $create(wbox)}
	::Jabber::Forms::Build $create(wbox) $childList -template "room" -width 320
	pack $create(wbox) -side top -fill x -padx 2 -pady 10
    }
    if {$UItype == 2} {
	::Jabber::Forms::FillScrollForm $create(wbox) $childList -template "room"
    }
    
    $create(wbtenter) configure -state normal -default active
    $create(wbtget) configure -state normal -default disabled
    bind $create(w) <Return> {}
}

proc ::Jabber::Conference::DoCreate {token} {   
    variable $token
    upvar 0 $token create

    variable UItype
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Conference::DoCreate"

    $create(wsearrows) stop
    
    set roomJid [string tolower $create(roomname)@$create(server)]
    if {$UItype != 2} {
    	set subelements [::Jabber::Forms::GetXML $create(wbox)]
    } else {
    	set subelements [::Jabber::Forms::GetScrollForm $create(wbox)]
    }
    
    # Ask jabberlib to create the room for us.
    if {$create(usemuc)} {
	$jstate(jlib) muc setroom $roomJid form -form $subelements \
	  -command [list [namespace current]::ResultCallback $roomJid]
    } else {
	$jstate(jlib) conference set_create $roomJid $subelements  \
	  [list [namespace current]::ResultCallback $roomJid]
    }
	
    # Cache groupchat protocol type (muc|conference|gc-1.0).
    if {$create(usemuc)} {
	::Jabber::GroupChat::SetProtocol $roomJid "muc"
    } else {
	::Jabber::GroupChat::SetProtocol $roomJid "conference"
    }
    
    # This triggers the tkwait, and destroys the create dialog.
    set create(finished) 1
    catch {destroy $create(w)}
}

#-------------------------------------------------------------------------------
