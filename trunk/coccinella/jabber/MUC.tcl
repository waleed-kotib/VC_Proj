#  MUC.tcl ---
#  
#      This file is part of the whiteboard application. 
#      It implements parts of the UI for the Multi User Chat protocol.
#      
#  Copyright (c) 2003  Mats Bengtsson
#  
# $Id: MUC.tcl,v 1.1 2003-05-18 13:11:28 matben Exp $

package provide MUC 1.0

namespace eval ::Jabber::MUC:: {
      
    # Local stuff
    variable locals
    
    # Define the 'role' privileges.
    # The first array index is the action, the secons is the role.
    variable rolePrivileges
    array set rolePrivileges {
	setroomnick,visitor         1
	setroomnick,participant     1
	setroomnick,moderator       1
	sendprivmsg,visitor         1
	sendprivmsg,participant     1
	sendprivmsg,moderator       1
	kick,visitor                0
	kick,participant            0
	kick,moderator              1
	grant,visitor               0
	grant,participant           0
	grant,moderator             1
	revoke,visitor              0
	revoke,participant          0
	revoke,moderator            1
    }
 
    # Define the 'affilation' privileges.
    variable affPrivileges 
    array set affPrivileges {
	entermemberonly,member      1
	entermemberonly,admin       1
	entermemberonly,owner       1
	ban,member                  0
	ban,admin                   1
	ban,owner                   1
	editmembers,member          0
	editmembers,admin           1
	editmembers,owner           1
	editmod,member              0
	editmod,admin               1
	editmod,owner               1
	editadmin,member            0
	editadmin,admin             0
	editadmin,owner             1
	editowner,member            0
	editowner,admin             0
	editowner,owner             1
	roomdef,member              0
	roomdef,admin               0
	roomdef,owner               1
	configure,member            0
	configure,admin             0
	configure,owner             1
	destroy,member              0
	destroy,admin               0
	destroy,owner               1
    }
    
    variable mapRoleAct2bt
    array set mapRoleAct2bt {
	kick            $frrole.bt1
	grant           $frrole.bt2
	revoke          $frrole.bt3
    }
    
    variable mapAffAct2bt
    array set mapAffAct2bt {
	editmembers     $fredit.bt1
	editmod         $fredit.bt2
	editadmin       $fredit.bt3
	editowner       $fredit.bt4
	ban             $fraff.bt1
	roomdef         $fraff.bt2
	configure       $fraff.bt3
	destroy         $fraff.bt4
    }
    
}

# Jabber::MUC::BuildEnter --
#
#       Initiates the process of entering a MUC room.
#       
# Arguments:
#       w           toplevel widget
#       args        -server, -roomjid
#       
# Results:
#       "cancel" or "enter".

proc ::Jabber::MUC::BuildEnter {w args} {
    global  this sysFont

    upvar ::Jabber::jstate jstate
    
    if {[winfo exists $w]} {
	raise $w
	return
    }
    array set argsArr $args
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w {Enter Room}
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
    message $w.frall.msg -width 260 -font $sysFont(s)  \
    	-text "Enter the room and set your nick name"
    pack $w.frall.msg -side top -fill x -anchor w -padx 2 -pady 4
    set frtop $w.frall.top
    pack [frame $frtop] -side top -fill x
    label $frtop.lserv -text "[::msgcat::mc {Conference server}]:" \
      -font $sysFont(sb) 

    set confServers [$jstate(browse) getconferenceservers]
    
    ::Jabber::Debug 2 "BuildEnterRoom: confServers='$confServers'"

    set wcomboserver $frtop.eserv
    ::combobox::combobox $wcomboserver -width 20 -font $sysFont(s)  \
      -textvariable [namespace current]::server  \
      -command [namespace current]::ConfigRoomList -editable 0
    eval {$frtop.eserv list insert end} $confServers
    label $frtop.lroom -text "[::msgcat::mc {Room name}]:" -font $sysFont(sb)
    
    # Find the default conferencing server.
    if {[info exists argsArr(-server)]} {
	set server $argsArr(-server)
    } elseif {[llength $confServers]} {
	set server [lindex $confServers 0]
    }

    set roomList {}
    if {[string length $server] > 0} {
	set allRooms [$jstate(browse) getchilds $server]
	foreach roomJid $allRooms {
	    regexp {([^@]+)@.+} $roomJid match room
	    lappend roomList $room
	}
    }
    set wcomboroom $frtop.eroom
    ::combobox::combobox $wcomboroom -width 20 -font $sysFont(s)   \
      -textvariable "[namespace current]::roomname" -editable 0
    eval {$frtop.eroom list insert end} $roomList

    if {[info exists argsArr(-roomjid)]} {
	regexp {^([^@]+)@([^/]+)} $argsArr(-roomjid) match roomname server	
	$wcomboserver configure -state disabled
	$wcomboroom configure -state disabled
    }
    if {[info exists argsArr(-server)]} {
	set server $argsArr(-server)
	$wcomboserver configure -state disabled
    }
    grid $frtop.lserv -column 0 -row 0 -sticky e
    grid $frtop.eserv -column 1 -row 0 -sticky w
    grid $frtop.lroom -column 0 -row 1 -sticky e
    grid $frtop.eroom -column 1 -row 1 -sticky w
    
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set wsearrows $frbot.arr
    set wbtenter $frbot.btenter
    pack [button $wbtenter -text [::msgcat::mc Enter] -width 8 -state disabled \
      -command [list [namespace current]::DoEnter $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command [list [namespace current]::CancelEnter $w]]  \
      -side right -padx 5 -pady 5
    pack [::chasearrows::chasearrows $wsearrows -background gray87 -size 16] \
      -side left -padx 5 -pady 5
    pack $frbot -side bottom -fill x -expand 0 -padx 8 -pady 6


}

proc ::Jabber::MUC::DoEnter {} {
    
    
    
}

proc ::Jabber::MUC::CancelEnter {} {
    
    
    
}

proc ::Jabber::MUC::BuildInfo {w roomjid} {
    global this sysFont
    
    upvar ::Jabber::jstate jstate
    
    if {[winfo exists $w]} {
	raise $w
	return
    }
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w {Info Room}

    # Instance specific namespace.
    namespace eval [namespace current]::${roomjid} {
	variable locals
    }
    upvar [namespace current]::${roomjid}::locals locals
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
    
    
    # Tablelist with scrollbar ---
    set frtab $w.frall.frtab    
    set wysc $frtab.ysc
    set wtbl $frtab.tb
    pack [frame $frtab]
    label $frtab.l -text "Participants:" -font $sysFont(sb)
    set columns [list 0 Nickname 0 Role 0 Affilation]
    tablelist::tablelist $wtbl  \
      -columns $columns  \
      -font $sysFont(s) -labelfont $sysFont(s) -background white  \
      -yscrollcommand [list $wysc set]  \
      -labelbackground #cecece -stripebackground #dedeff -width 30 -height 10
    scrollbar $wysc -orient vertical -command [list $wtbl yview]
    grid $frtab.l -sticky w
    grid $wtbl $wysc -sticky news
    grid columnconfigure $frtab 0 -weight 1
    
    # Special bindings for the tablelist.
    set body [$wtbl bodypath]
    bind $body <Button-1> {+ focus %W}
    bind $body <Double-1> [list [namespace current]::DoubleClickPart]
    bind $wtbl <<ListboxSelect>> [list [namespace current]::SelectPart]
    
    # Fill in tablelist.
    set presList [$jstate(roster) getpresence $roomjid]
    set resourceList [$jstate(roster) getresources $roomjid]
    puts "presList=$presList,\nresourceList=$resourceList"
    
    foreach res $resourceList {
	set xelem [$jstate(roster) getx $roomjid/$res "muc#user"]
	puts "res=$res, xelem=$xelem"
	set aff unknown
	set role unknown
	$wtbl insert end [list $res $role $aff]
    }

    # Edit lists ---
    set fredit $w.frall.fed
    pack [frame $fredit]
    label $fredit.l -text "Edit Lists:" -font $sysFont(sb)
    button $fredit.bt1 -text "Member List..."  \
      -command [list [namespace current]::EditList $roomjid member]
    button $fredit.bt2 -text "Moderator List..."  \
      -command [list [namespace current]::EditList $roomjid moderator]
    button $fredit.bt3 -text "Admin List..."  \
      -command [list [namespace current]::EditList $roomjid admin]
    button $fredit.bt4 -text "Owner List..."  \
      -command [list [namespace current]::EditList $roomjid owner]
    grid $fredit.l -sticky w -pady 2
    grid $fredit.bt1 -sticky ew -pady 2
    grid $fredit.bt2 -sticky ew -pady 2
    grid $fredit.bt3 -sticky ew -pady 2
    grid $fredit.bt4 -sticky ew -pady 2

    # Role buttons ---
    set frrole $w.frall.frole
    pack [frame $frrole]
    button $frrole.bt1 -text "Kick"  \
      -command [list [namespace current]::Kick $roomjid]
    button $frrole.bt2 -text "Grant Voice"  \
      -command [list [namespace current]::GrantVoice $roomjid]
    button $frrole.bt3 -text "Revoke Voice"  \
      -command [list [namespace current]::RevokeVoice $roomjid]
    grid $frrole.bt1 -sticky ew -pady 2
    grid $frrole.bt2 -sticky ew -pady 2
    grid $frrole.bt3 -sticky ew -pady 2

    # Affilation buttons ---
    set fraff $w.frall.fraff
    pack [frame $fraff]
    button $fraff.bt1 -text "Ban Participant"  \
      -command [list [namespace current]::Ban $roomjid]
    button $fraff.bt2 -text "Change Room Definition"  \
      -command [list [namespace current]::RoomDefinition $roomjid]
    button $fraff.bt3 -text "Configure Room"  \
      -command [list [namespace current]::RoomConfig $roomjid]
    button $fraff.bt4 -text "Destroy Room"  \
      -command [list [namespace current]::Destroy $roomjid]
    grid $fraff.bt1 -sticky ew -pady 2
    grid $fraff.bt2 -sticky ew -pady 2
    grid $fraff.bt3 -sticky ew -pady 2
    grid $fraff.bt4 -sticky ew -pady 2

    # Collect various widget paths.
    set locals(wtbl) $wtbl
    set locals(fredit) $fredit
    set locals(frrole) $frrole
    set locals(fraff) $fraff
    
    wm resizable $w 0 0
    
    
}

proc ::Jabber::MUC::EditList {roomjid type} {

    
}

proc ::Jabber::MUC::DoubleClickPart {} {

    
}

proc ::Jabber::MUC::SelectPart {} {

    
}

proc ::Jabber::MUC::SetButtonsState {roomjid role affilation} {

    variable mapRoleAct2bt
    variable mapAffAct2bt
    variable rolePrivileges
    variable affPrivileges
    upvar [namespace current]::${roomjid}::locals locals
    
    set wtbl $locals(wtbl)
    set fredit $locals(fredit)
    set frrole $locals(frrole)
    set fraff $locals(fraff)

    foreach {act wbt} [array get mapRoleAct2bt] {
	set wbt [subst -nobackslashes -nocommands $wbt]
	if {$rolePrivileges($act,$role)} {
	    $wbt configure -state normal
	} else {
	    $wbt configure -state disabled
	}
    }
    
    foreach {act wbt} [array get mapAffAct2bt] {
	set wbt [subst -nobackslashes -nocommands $wbt]
	if {$affPrivileges($act,$affilation)} {
	    $wbt configure -state normal
	} else {
	    $wbt configure -state disabled
	}
    }
    
    
}

proc ::Jabber::MUC::Kick {roomjid} {

    
}

proc ::Jabber::MUC::GrantVoice {roomjid} {

    
}

proc ::Jabber::MUC::RevokeVoice {roomjid} {

    
}

proc ::Jabber::MUC::Ban {roomjid} {

    
}

proc ::Jabber::MUC::RoomDefinition {roomjid} {

    
}

proc ::Jabber::MUC::RoomConfig {roomjid} {
    
    
}

proc ::Jabber::MUC::Destroy {roomjid} {

    
}


#-------------------------------------------------------------------------------
