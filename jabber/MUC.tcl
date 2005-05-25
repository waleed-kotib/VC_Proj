#  MUC.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements parts of the UI for the Multi User Chat protocol.
#      
#      This code is not completed!!!!!!!
#      
#  Copyright (c) 2003-2005  Mats Bengtsson
#  
# $Id: MUC.tcl,v 1.60 2005-05-25 13:44:14 matben Exp $

package require entrycomp
package require muc

package provide MUC 1.0

namespace eval ::MUC:: {
      
    ::hooks::register jabberInitHook     ::MUC::Init
    ::hooks::register closeWindowHook    ::MUC::EnterCloseHook
    
    # Local stuff
    variable dlguid 0
    variable editcalluid 0
    variable enteruid  0
    
    # Map action to button widget.
    variable mapAction2Bt
    array set mapAction2Bt {
	grant,voice             $wgrant.btvoice 
	grant,member            $wgrant.btmember
	grant,moderator         $wgrant.btmoderator
	grant,admin             $wgrant.btadmin
	grant,owner             $wgrant.btowner
	revoke,voice            $wrevoke.btvoice
	revoke,member           $wrevoke.btmember
	revoke,moderator        $wrevoke.btmoderator
	revoke,admin            $wrevoke.btadmin
	revoke,owner            $wrevoke.btowner
	list,voice              $wlist.btvoice
	list,ban                $wlist.btban
	list,member             $wlist.btmember
	list,moderator          $wlist.btmoderator
	list,admin              $wlist.btadmin
	list,owner              $wlist.btowner
	other,kick              $wother.btkick
	other,ban               $wother.btban
	other,conf              $wother.btconf
	other,dest              $wother.btdest
    }
    
    # List enabled buttons for each role/affiliation privileges.
    variable enabledBtAffList 
    array set enabledBtAffList {
	none        {}
	outcast     {}
	member      {}
	admin       {
	    $wother.btban        $wlist.btban 
	    $wgrant.btmember     $wrevoke.btmember     $wlist.btmember
	    $wgrant.btmoderator  $wrevoke.btmoderator  $wlist.btmoderator}
	owner       {
	    $wother.btban        $wlist.btban 
	    $wgrant.btmember     $wrevoke.btmember     $wlist.btmember
	    $wgrant.btmoderator  $wrevoke.btmoderator  $wlist.btmoderator
	    $wgrant.btowner      $wrevoke.btowner      $wlist.btowner
	    $wgrant.btadmin      $wrevoke.btadmin      $wlist.btadmin
	    $wother.btconf       $wother.btdest}
    }
    
    variable enabledBtRoleList
    array set enabledBtRoleList {
	none        {}
	visitor     {}
	participant {}
	moderator   {
	    $wgrant.btvoice      $wrevoke.btvoice      $wlist.btvoice
	    $wother.btkick}
    }
}


proc ::MUC::Init {jlibName} {
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::xmppxmlns xmppxmlns
   
    set jstate(muc) [jlib::muc::new $jlibName]

    $jstate(jlib) message_register * $xmppxmlns(muc,user) ::MUC::MUCMessage
    
    ::Jabber::AddClientXmlns [list $xmppxmlns(muc)]
}

# MUC::BuildEnter --
#
#       Initiates the process of entering a MUC room. Multi instance.
#       
# Arguments:
#       args        -server, -roomjid, -nickname, -password, -autobrowse,
#                   -command
#       
# Results:
#       "cancel" or "enter".

proc ::MUC::BuildEnter {args} {
    global  this wDlgs

    variable enteruid
    variable dlguid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::xmppxmlns xmppxmlns
    upvar ::Jabber::jprefs jprefs

    array set argsArr {
	-autobrowse     0
    }
    array set argsArr $args

    #set confServers [$jstate(browse) getservicesforns  \
    #  "http://jabber.org/protocol/muc"]
    # We should only get services that provides muc!
    set confServers {}
    set allConfServ [$jstate(jlib) service getconferences]
    foreach serv $allConfServ {
	if {[$jstate(jlib) service hasfeature $serv $xmppxmlns(muc)]} {
	    lappend confServers $serv
	}
    }

    ::Debug 2 "::MUC::BuildEnter confServers='$confServers'; allConfServ=$allConfServ"

    if {[llength $confServers] == 0} {
	::UI::MessageBox -type ok -icon error -title "No Conference"  \
	  -message "Failed to find any multi user chat service component"
	return
    }

    # State variable to collect instance specific variables.
    set token [namespace current]::enter[incr enteruid]
    variable $token
    upvar 0 $token enter
    
    set w $wDlgs(jmucenter)[incr dlguid]
    ::UI::Toplevel $w -macstyle documentProc -macclass {document closeBox} \
      -usemacmainmenu 1
    wm title $w [mc {Enter Room}]
    set enter(w) $w
    set enter(args) $args
    array set enter {
	finished    -1
	statuscount 0
	server      ""
	roomname    ""
	nickname    ""
	password    ""
    }
    set enter(nickname) $jprefs(defnick)
    
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1
    label $w.frall.msg -wraplength 260 -justify left -text [mc jamucentermsg]
    pack  $w.frall.msg -side top -fill x -anchor w -padx 8 -pady 4

    set frtop $w.frall.top
    pack [frame $frtop] -side top -anchor w -padx 12
    label $frtop.lserv -text "[mc {Conference server}]:" 
    
    # First menubutton: servers. (trace below)
    set wpopupserver $frtop.eserv
     eval {tk_optionMenu $wpopupserver $token\(server)} $confServers
    label $frtop.lroom -text "[mc {Room name}]:"
    
    # Find the default conferencing server.
    if {[info exists argsArr(-server)]} {
	set enter(server) $argsArr(-server)
    } elseif {[llength $confServers]} {
	set enter(server) [lindex $confServers 0]
    }
    set enter(server-state) normal
    set enter(room-state)   normal
    set enter(-autobrowse)  $argsArr(-autobrowse)

    # Second menubutton: rooms for above server. Fill in below.
    # Combobox since we sometimes want to enter room manually.
    set wpopuproom     $frtop.eroom
    set enter(wbrowse) $frtop.browse
    
    ::combobox::combobox $wpopuproom -width 8 -textvariable $token\(roomname)
    button $enter(wbrowse) -text [mc Browse] \
      -command [list [namespace current]::Browse $token]
    if {[info exists argsArr(-roomjid)]} {
	jlib::splitjidex $argsArr(-roomjid) enter(roomname) enter(server) z
	set enter(server-state) disabled
	set enter(room-state)   disabled
	$wpopupserver configure -state disabled
	$wpopuproom   configure -state disabled
    }
    if {[info exists argsArr(-server)]} {
	set enter(server) $argsArr(-server)
	set enter(server-state) disabled
	$wpopupserver configure -state disabled
    }
    if {[info exists argsArr(-command)]} {
	set enter(-command) $argsArr(-command)
    }
    
    label $frtop.lnick -text "[mc {Nick name}]:"
    entry $frtop.enick -textvariable $token\(nickname) -width 30
    label $frtop.lpass -text "[mc Password]:"
    entry $frtop.epass -textvariable $token\(password) -show {*} -validate key \
      -validatecommand {::Jabber::ValidatePasswdChars %S}
   
    # Busy arrows and status message.
    set wsearrows $frtop.st.arr
    set wstatus   $frtop.st.stat
    frame $frtop.st
    pack [::chasearrows::chasearrows $wsearrows -size 16] \
      -side left -padx 5 -pady 0
    pack [label $wstatus -textvariable $token\(status) -pady 0 -bd 0] \
      -side left -padx 5 -pady 0
    
    grid $frtop.lserv   $wpopupserver -  -sticky e
    grid $frtop.lroom   $wpopuproom   $enter(wbrowse)  -sticky e
    grid $frtop.lnick   $frtop.enick  -  -sticky e
    grid $frtop.lpass   $frtop.epass  -  -sticky e
    grid $frtop.st      -             -  -sticky w
    grid $wpopupserver  $wpopuproom  $frtop.enick  $frtop.epass  -sticky ew

    if {[info exists argsArr(-nickname)]} {
	set enter(nickname) $argsArr(-nickname)
	$frtop.enick configure -state disabled
    }
    if {[info exists argsArr(-password)]} {
	set enter(password) $argsArr(-password)
	$frtop.epass configure -state disabled
    }
       
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack $frbot -side bottom -fill x -expand 0 -padx 8 -pady 0
    set wbtenter  $frbot.btok
    pack [button $wbtenter -text [mc Enter] \
      -default active -command [list [namespace current]::DoEnter $token]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelEnter $token]]  \
      -side right -padx 5 -pady 5
    pack [frame $w.frall.pad -height 8 -width 1] -side bottom -pady 0

    set enter(status)       "  "
    set enter(wpopupserver) $wpopupserver
    set enter(wpopuproom)   $wpopuproom
    set enter(wsearrows)    $wsearrows
    set enter(wbtenter)     $wbtenter
    
    if {$enter(-autobrowse) && [string equal $enter(room-state) "normal"]} {

	# Get a freash list each time.
	BusyEnterDlgIncr $token
	update idletasks
	$jstate(jlib) service send_getchildren $enter(server)  \
	  [list [namespace current]::GetRoomsCB $token]
    }
    if {[string equal $enter(room-state) "normal"]} {
	trace variable $token\(server) w  \
	  [list [namespace current]::ConfigRoomList $token]
    }

    wm resizable $w 0 0

    bind $w <Return> [list $wbtenter invoke]
    
    set oldFocus [focus]
    if {[info exists argsArr(-roomjid)]} {
    	focus $frtop.enick
    } elseif {[info exists argsArr(-server)]} {
    	focus $frtop.eroom
    } else {
    	focus $frtop.eserv
    }

    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $w.frall.msg $w]    
    after idle $script

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jmucenter)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jmucenter)
    }
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {focus $oldFocus}
    trace vdelete $token\(server) w  \
      [list [namespace current]::ConfigRoomList $token]
    set finished $enter(finished)
    
    # Unless cancelled we keep 'enter' until got callback.
    if {$finished <= 0} {
	unset enter
    }
    return [expr {($finished <= 0) ? "cancel" : "enter"}]
}

proc ::MUC::CancelEnter {token} {
    variable $token
    upvar 0 $token enter

    EnterCloseHook $enter(w)
    set enter(finished) 0
    catch {destroy $enter(w)}
}

proc ::MUC::EnterCloseHook {wclose} {
    global  wDlgs

    if {[string match $wDlgs(jmucenter)* $wclose]} {
	::UI::SaveWinGeom $wDlgs(jmucenter) $wclose
    }
}

proc ::MUC::Browse {token} {
    variable $token
    upvar 0 $token enter
    upvar ::Jabber::jstate jstate
       
    BusyEnterDlgIncr $token
    $jstate(jlib) service send_getchildren $enter(server)  \
      [list [namespace current]::GetRoomsCB $token]
}

# MUC::ConfigRoomList --
# 
#       When a conference server is picked in the server combobox, the 
#       room combobox must get the available rooms for this particular server.

proc ::MUC::ConfigRoomList {token name junk1 junk2} {    
    variable $token
    upvar 0 $token enter
    upvar ::Jabber::jstate jstate
    
    ::Debug 4 "::MUC::ConfigRoomList"

    # Fill in room list if exist else get.    
    if {[$jstate(jlib) service isinvestigated $enter(server)]} {
	FillRoomList $token
    } else {
	if {$enter(-autobrowse)} {
	    Browse $token
	} else {
	    $enter(wpopuproom) list delete 0 end
	    set enter(roomname) ""
	}
    }
}

proc ::MUC::FillRoomList {token} {
    variable $token
    upvar 0 $token enter
    upvar ::Jabber::jstate jstate
    
    ::Debug 4 "::MUC::FillRoomList"
    
    set roomList {}
    if {[string length $enter(server)] > 0} {
	set allRooms [$jstate(jlib) service childs $enter(server)]
	foreach roomJid $allRooms {
	    regexp {([^@]+)@.+} $roomJid match room
	    lappend roomList $room
	}
    }
    if {[llength $roomList] == 0} {
	::UI::MessageBox -type ok -icon error -title "No Rooms"  \
	  -message "Failed to find any rooms at $enter(server)"
	return
    }
    
    set roomList [lsort $roomList]
    $enter(wpopuproom) list delete 0 end
    eval {$enter(wpopuproom) list insert end} $roomList
    set enter(roomname) [lindex $roomList 0]
}

proc ::MUC::BusyEnterDlgIncr {token {num 1}} {
    variable $token
    upvar 0 $token enter
    
    incr enter(statuscount) $num
    
    if {$enter(statuscount) > 0} {
	set enter(status) "Getting available rooms..."
	$enter(wsearrows) start
	$enter(wpopupserver) configure -state disabled
	$enter(wpopuproom)   configure -state disabled
	$enter(wbtenter)     configure -state disabled
    } else {
	set enter(statuscount) 0
	set enter(status) ""
	$enter(wsearrows) stop
	if {[string equal $enter(server-state) "normal"]} {
	    $enter(wpopupserver) configure -state normal
	}
	if {[string equal $enter(room-state) "normal"]} {
	    $enter(wpopuproom)   configure -state normal
	}
	$enter(wbtenter)     configure -state normal
    }
}

proc ::MUC::GetRoomsCB {token browsename type jid subiq args} {
    
    ::Debug 4 "::MUC::GetRoomsCB type=$type, jid=$jid"
    
    # Make sure the dialog still exists.
    if {![info exists $token]} {
	return
    }
    
    switch -- $type {
	error {
	    # ???
	}
	result - ok {
	    FillRoomList $token
	}
    }
    BusyEnterDlgIncr $token -1
}

proc ::MUC::DoEnter {token} {
    variable $token
    upvar 0 $token enter
    upvar ::Jabber::jstate jstate
    
    if {($enter(roomname) == "") || ($enter(nickname) == "")} {
	::UI::MessageBox -type ok -icon error  \
	  -message "We require that all fields are nonempty"
	return
    }
    set roomJid [jlib::jidmap $enter(roomname)@$enter(server)]
    set opts {}
    if {$enter(password) != ""} {
	lappend opts -password $enter(password)
    }
    
    # We announce that we are a Coccinella here and let others know ip etc.
    set cocciElem [::Jabber::CreateCoccinellaPresElement]
    set capsElem  [::Jabber::CreateCapsPresElement]
    lappend opts -extras [list $cocciElem $capsElem]
    
    eval {$jstate(muc) enter $roomJid $enter(nickname) -command \
      [list [namespace current]::EnterCallback $token]} $opts
    set enter(finished) 1
    EnterCloseHook $enter(w)
    catch {destroy $enter(w)}
}

# MUC::EnterCallback --
#
#       Presence callabck from the 'muc enter' command.
#       Just to catch errors and check if any additional info (password)
#       is needed for entering room.
#
# Arguments:
#       mucname 
#       type    presence typ attribute, 'available' etc.
#       args    -from, -id, -to, -x ...
#       
# Results:
#       None.

proc ::MUC::EnterCallback {token mucname type args} {
    variable $token
    upvar 0 $token enter
    
    Debug 3 "::MUC::EnterCallback type=$type, args='$args'"

    array set argsArr $args
    jlib::splitjid $argsArr(-from) roomjid res
    set retry 0
    
    if {$type == "error"} {
	set errcode ???
	set errmsg ""
	if {[info exists argsArr(-error)]} {
	    set errcode [lindex $argsArr(-error) 0]
	    set errmsg  [lindex $argsArr(-error) 1]
	    
	    switch -- $errcode {
		401 {
		    
		    # Password required.
		    set msg "Error when entering room \"$roomjid\":\
		      $errmsg Do you want to retry?"
		    set ans [::UI::MessageBox -type yesno -icon error  \
		      -message $msg]
		    if {$ans == "yes"} {
			set retry 1
			eval {BuildEnter} $enter(args)
		    }
		}
		default {
		    set errmsg [lindex $argsArr(-error) 1]
		    ::UI::MessageBox -type ok -icon error  \
		      -message [mc jamesserrconfgetcre $errcode $errmsg]
		}
	    }
	}
    } else {
	
	# Cache groupchat protocol type (muc|conference|gc-1.0) etc.
	::Debug 2 "--> groupchatEnterRoomHook $roomjid"
	::hooks::run groupchatEnterRoomHook $roomjid "muc"
    }
    if {!$retry && [info exists enter(-command)]} {
	uplevel #0 $enter(-command) $type $args
    }
    unset -nocomplain enter
}

# MUC::EnterRoom --
# 
#       Programmatic way to enter a room.

proc ::MUC::EnterRoom {roomjid nick args} {
    variable enteruid
    upvar ::Jabber::jstate jstate
    
    # State variable to collect instance specific variables.
    set token [namespace current]::enter[incr enteruid]
    variable $token
    upvar 0 $token enter

    set enter(nickname) $nick
    set enter(args) [concat $args -roomjid $roomjid -nickname $nick]
    jlib::splitjidex $roomjid enter(roomname) enter(server) z

    set opts {}
    foreach {key value} $args {
	switch -- $key {
	    -command {
		set enter(-command) $value
	    }
	    -password {
		lappend opts $key $value
	    }
	}
    }
    eval {$jstate(muc) enter $roomjid $nick -command \
      [list [namespace current]::EnterCallback $token]} $opts
}

namespace eval ::MUC:: {
    
    variable inviteuid 0

    ::hooks::register closeWindowHook    ::MUC::InviteCloseHook
}

# MUC::Invite --
# 
#       Make an invitation to a room.

proc ::MUC::Invite {roomjid} {
    global this wDlgs
    
    variable inviteuid
    variable dlguid
    upvar ::Jabber::jstate jstate

    # State variable to collect instance specific variables.
    set token [namespace current]::invite[incr inviteuid]
    variable $token
    upvar 0 $token invite
    
    set w $wDlgs(jmucinvite)[incr dlguid]
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w {Invite User}
    set invite(w)        $w
    set invite(reason)   ""
    set invite(finished) -1
    set invite(roomjid)  $roomjid
    
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 4
    regexp {^([^@]+)@.*} $roomjid match roomName
    set msg "Invite a user for groupchat in room $roomName"
    pack [message $w.frall.msg -width 220 -text $msg] \
      -side top -fill both -padx 4 -pady 2
    
    set jidlist [$jstate(roster) getusers -type available]
    set wmid $w.frall.fr
    pack [frame $wmid] -side top -fill x -expand 1 -padx 6
    label $wmid.la -font $fontSB -text "Invite Jid:"
    ::entrycomp::entrycomp $wmid.ejid $jidlist -textvariable $token\(jid)
    label $wmid.lre -font $fontSB -text "Reason:"
    entry $wmid.ere -textvariable $token\(reason)
    
    grid $wmid.la -column 0 -row 0 -sticky e -padx 2 
    grid $wmid.ejid -column 1 -row 0 -sticky ew -padx 2 
    grid $wmid.lre -column 0 -row 1 -sticky e -padx 2 
    grid $wmid.ere -column 1 -row 1 -sticky ew -padx 2 
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack $frbot  -side bottom -fill x -padx 10 -pady 8
    pack [button $frbot.btok -text [mc OK]  \
      -default active -command [list [namespace current]::DoInvite $token]] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelInvite $token]]  \
      -side right -padx 5 -pady 5  
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    bind $w <Escape> [list $frbot.btcancel invoke]

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jmucinvite)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jmucinvite)
    }
    
    # Grab and focus.
    set oldFocus [focus]
    focus $wmid.ejid
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w

    catch {focus $oldFocus}
    
}

proc ::MUC::CancelInvite {token} {
    variable $token
    upvar 0 $token invite

    InviteCloseHook $invite(w)
    set invite(finished) 0
    catch {destroy $invite(w)}
    unset invite
}

proc ::MUC::DoInvite {token} {
    variable $token
    upvar 0 $token invite
    upvar ::Jabber::jstate jstate

    set jid     $invite(jid)
    set reason  $invite(reason)
    set roomjid $invite(roomjid)
    InviteCloseHook $invite(w)
    
    set opts [list -command [list [namespace current]::InviteCB $token]]
    if {$reason != ""} {
	set opts [list -reason $reason]
    }
    eval {$jstate(muc) invite $roomjid $jid} $opts
    set invite(finished) 1
    catch {destroy $invite(w)}
}

proc ::MUC::InviteCB {token jlibname type args} {
    variable $token
    upvar 0 $token invite
    
    array set argsArr $args
    
    if {$type == "error"} {
	set msg "Invitation to $invite(jid) to join room $invite(roomjid) failed."
	if {[info exists argsArr(-error)]} {
	    set errcode [lindex $argsArr(-error) 0]
	    set errmsg [lindex $argsArr(-error) 1]
	    append msg " " "Error message: $errmsg"
	}
	::UI::MessageBox -icon error -title [mc Error] -type ok -message $msg
    }
    unset invite
}

proc ::MUC::InviteCloseHook {wclose} {
    global  wDlgs
        
    if {[string match $wDlgs(jmucinvite)* $wclose]} {
	::UI::SaveWinGeom $wDlgs(jmucinvite) $wclose
    }   
}

# MUC::MUCMessage --
# 
#       Handle incoming message tagged with muc namespaced x-element.
#       Invitation?

proc ::MUC::MUCMessage {jlibname xmlns args} {
   
    # This seems handled by the muc component by sending a message.
    return
   
    array set argsArr $args
    set from $argsArr(-from)
    set xlist $argsArr(-x)
    
    set invite 0
    foreach c [wrapper::getchildren $xlist] {
	
	switch -- [lindex $c 0] {
	    invite {
		set invite 1
		set inviter [wrapper::getattribute $c "from"]
		foreach cc [wrapper::getchildren $c] {
		    if {[string equal [lindex $cc 0] "reason"]} {
			set reason [lindex $cc 3]
		    }
		}		
	    }
	    password {
		set password [lindex $c 3]
	    }	    
	}
    }
    
    if {$invite} {
	set msg "You have received an invitation from $inviter to join\
	  a groupchat in the room $from."
	set opts {}
	if {[info exists reason]} {
	    append msg " The reason: $reason"
	}
	if {[info exists password]} {
	    append msg " The password \"$password\" is needed for entry."
	    lappend opts -password $password
	}
	append msg " Do you want to join right away?"
	set ans [::UI::MessageBox -icon info -type yesno -title "Invitation" \
	  -message $msg]
	if {$ans == "yes"} {
	    eval {BuildEnter -roomjid $from} $opts
	}
    }
}

#--- The Info Dialog -----------------------------------------------------------

namespace eval ::MUC:: {
    
    ::hooks::register closeWindowHook    ::MUC::InfoCloseHook
}

# MUC::BuildInfo --
# 
#       Displays an info dialog for MUC room configuration.

proc ::MUC::BuildInfo {roomjid} {
    global this wDlgs
    
    variable dlguid
    upvar ::Jabber::jstate jstate

    # Instance specific namespace.
    namespace eval [namespace current]::${roomjid} {
	variable locals
    }
    upvar [namespace current]::${roomjid}::locals locals
    
    if {[info exists locals($roomjid,w)] && [winfo exists $locals($roomjid,w)]} {
	raise $locals($roomjid,w)
	return
    }    
    set w $wDlgs(jmucinfo)[incr dlguid]

    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    set roomName [$jstate(jlib) service name $roomjid]
    if {$roomName == ""} {
	regexp {([^@]+)@.+} $roomjid match roomName
    }
    wm title $w "Info Room: $roomName"
    set locals($roomjid,w) $w
    set locals($w,roomjid) $roomjid
    set locals($roomjid,mynick) [$jstate(muc) mynick $roomjid]
    set locals($roomjid,myrole) none
    set locals($roomjid,myaff) none
    switch -- $this(platform) {
	macintosh {
	    set pady 4
	}
	macosx {
	    set pady 2
	}
	default {
	    set pady 4
	}
    }
    set fontS [option get . fontSmall {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1
    
    # 
    pack [message $w.frall.msg -width 400 -text \
      "This dialog makes available a number of options and actions for a\
      room. Your role and affiliation determines your privilege to act.\
      Further restrictions may exist depending on specific room\
      configuration."]  \
      -side top -anchor w -padx 4 -pady 4
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btcancel -text [mc Close]  \
      -command [list [namespace current]::Close $roomjid]] \
      -side right -padx 5 -pady 5
    pack $frbot -side bottom -fill x -padx 10 -pady 8
    
    # A frame.
    set froom $w.frall.room
    pack [frame $froom] -side left -padx 4 -pady 4
    
    # Tablelist with scrollbar ---
    set frtab $froom.frtab    
    set wysc $frtab.ysc
    set wtbl $frtab.tb
    pack [frame $frtab] -padx 0 -pady 0 -side top
    #label $frtab.l -text "Participants:" -font $fontSB
    set columns [list 0 Nickname 0 Role 0 Affiliation]
    
    tablelist::tablelist $wtbl  \
      -columns $columns -stretch all -selectmode single  \
      -yscrollcommand [list $wysc set] -width 36 -height 8
    scrollbar $wysc -orient vertical -command [list $wtbl yview]
    button $frtab.ref -text Refresh -font $fontS -command  \
      [list [namespace current]::Refresh $roomjid]
    #grid $frtab.l -sticky w
    grid $wtbl $wysc -sticky news
    grid columnconfigure $frtab 0 -weight 1
    grid $frtab.ref -sticky e -pady 2
    
    # Special bindings for the tablelist.
    set body [$wtbl bodypath]
    bind $body <Button-1> {+ focus %W}
    bind $body <Double-1> [list [namespace current]::DoubleClickPart $roomjid]
    bind $wtbl <<ListboxSelect>> [list [namespace current]::SelectPart $roomjid]
    
    # Fill in tablelist.
    set locals(wtbl) $wtbl
    FillTable $roomjid
    
    # A frame.
    set frgrantrevoke $froom.grrev
    pack [frame $frgrantrevoke] -side top
        
    # Grant buttons ---
    set wgrant $frgrantrevoke.grant
    labelframe $wgrant -text "Grant:"
    pack $wgrant -side left -padx 8 -pady 4
    foreach txt {Voice Member Moderator Admin Owner} {
	set stxt [string tolower $txt]
	button $wgrant.bt${stxt} -text $txt  \
	  -command [list [namespace current]::GrantRevoke $roomjid grant $stxt]
	grid $wgrant.bt${stxt} -sticky ew -padx 8 -pady $pady 
    }
    
    # Revoke buttons ---
    set wrevoke $frgrantrevoke.rev
    labelframe $wrevoke -text "Revoke:"
    pack $wrevoke -side left -padx 8 -pady 4
    foreach txt {Voice Member Moderator Admin Owner} {
	set stxt [string tolower $txt]
	button $wrevoke.bt${stxt} -text $txt  \
	  -command [list [namespace current]::GrantRevoke $roomjid revoke $stxt]
	grid $wrevoke.bt${stxt} -sticky ew -padx 8 -pady $pady 
    }    
    
    # A frame.
    set frmid $w.frall.mid
    pack [frame $frmid] -side top
    
    # Other buttons ---
    set wother $frmid.fraff
    pack [frame $wother] -side top -padx 2 -pady 2
    button $wother.btkick -text "Kick Participant"  \
      -command [list [namespace current]::Kick $roomjid]
    button $wother.btban -text "Ban Participant"  \
      -command [list [namespace current]::Ban $roomjid]
    button $wother.btconf -text "Configure Room"  \
      -command [list [namespace current]::RoomConfig $roomjid]
    button $wother.btdest -text "Destroy Room"  \
      -command [list [namespace current]::Destroy $roomjid]
    grid $wother.btkick -sticky ew -pady $pady
    grid $wother.btban -sticky ew -pady $pady
    grid $wother.btconf -sticky ew -pady $pady
    grid $wother.btdest -sticky ew -pady $pady
    
    # Edit lists ---
    set wlist $frmid.lists
    labelframe $wlist -text "Edit Lists:"
    pack $wlist -side top -padx 8 -pady 4
    foreach txt {Voice Ban Member Moderator Admin Owner} {
	set stxt [string tolower $txt]	
	button $wlist.bt${stxt} -text "$txt..."  \
	  -command [list [namespace current]::EditListBuild $roomjid $stxt]
	grid $wlist.bt${stxt} -sticky ew -padx 8 -pady $pady
    }

    # Collect various widget paths.
    set locals(wtbl) $wtbl
    set locals(wlist) $wlist
    set locals(wgrant) $wgrant
    set locals(wrevoke) $wrevoke
    set locals(wother) $wother
    
    SetButtonsState $roomjid  \
      $locals($roomjid,myrole) $locals($roomjid,myaff) 
    
    wm resizable $w 0 0    
    
    set idleScript [format {
	%s.frall.msg configure -width [winfo reqwidth %s]} $w $w]
    #after idle $idleScript
    return ""
}

proc ::MUC::FillTable {roomjid} {
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate
    
    set mynick $locals($roomjid,mynick)
    set wtbl $locals(wtbl)
    $wtbl delete 0 end
    
    # Fill in tablelist.
    set presList [$jstate(roster) getpresence $roomjid -type available]
    set resourceList [$jstate(roster) getresources $roomjid -type available]
    set irow 0
    
    foreach res $resourceList {
	set xelem [$jstate(roster) getx $roomjid/$res "muc#user"]
	set aff none
	set role none
	foreach elem [wrapper::getchildren $xelem] {
	    if {[string equal [lindex $elem 0] "item"]} {
		unset -nocomplain attrArr
		array set attrArr [lindex $elem 1]
		if {[info exists attrArr(affiliation)]} {
		    set aff $attrArr(affiliation)
		}
		if {[info exists attrArr(role)]} {
		    set role $attrArr(role)
		}
		break
	    }
	}
	$wtbl insert end [list $res $role $aff]
	if {[string equal $res $mynick]} {
	    set locals($roomjid,myaff)  $aff
	    set locals($roomjid,myrole) $role
	    $wtbl rowconfigure $irow -bg #ffa090
	}
	incr irow
    }
}

proc ::MUC::Refresh {roomjid} {

    FillTable $roomjid
}

proc ::MUC::DoubleClickPart {roomjid} {
    upvar [namespace current]::${roomjid}::locals locals

    
}

proc ::MUC::SelectPart {roomjid} {
    upvar ::Jabber::jstate jstate
    upvar [namespace current]::${roomjid}::locals locals

    set wtbl $locals(wtbl)
    set item [$wtbl curselection]
    return 
    if {[string length $item] == 0} {
	DisableAll $roomjid
    } else {
    	SetButtonsState $roomjid  \
    	  $locals($roomjid,myrole) $locals($roomjid,myaff) 
    }  
}

proc ::MUC::SetButtonsState {roomjid role affiliation} {
    variable enabledBtAffList 
    variable enabledBtRoleList
    upvar [namespace current]::${roomjid}::locals locals
    
    set wtbl $locals(wtbl)
    set wlist $locals(wlist)
    set wgrant $locals(wgrant)
    set wrevoke $locals(wrevoke)
    set wother $locals(wother)
    
    DisableAll $roomjid

    foreach wbt $enabledBtRoleList($role) {
	set wbt [subst -nobackslashes -nocommands $wbt]
	$wbt configure -state normal
    }
    foreach wbt $enabledBtAffList($affiliation) {
	set wbt [subst -nobackslashes -nocommands $wbt]
	$wbt configure -state normal
    }
}

proc ::MUC::DisableAll {roomjid} {
    variable mapAction2Bt
    upvar [namespace current]::${roomjid}::locals locals

    set wlist $locals(wlist)
    set wgrant $locals(wgrant)
    set wrevoke $locals(wrevoke)
    set wother $locals(wother)

    foreach {action wbt} [array get mapAction2Bt] {
	set wbt [subst -nobackslashes -nocommands $wbt]
    	$wbt configure -state disabled
    }
}

proc ::MUC::GrantRevoke {roomjid which type} {
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate
    
    set dlgDefs(grant,voice) {
	{Grant Voice}  \
	{Grant voice to the participant "$nick" in the room "$roomName"}  \
    }
    set dlgDefs(grant,member) {
	{Grant Membership}  \
	{Grant membership to "$nick" in the room "$roomName"}  \
    }
    set dlgDefs(grant,moderator) {
	{Grant Moderator}  \
	{Grant moderator privileges to "$nick" for the room "$roomName"}  \
    }
    set dlgDefs(grant,admin) {
	{Grant Administrator}  \
	{Grant administrator privileges to "$nick" for the room "$roomName"}  \
    }
    set dlgDefs(grant,owner) {
	{Grant Owner}  \
	{Grant "$nick" to be the owner of the room "$roomName"}  \
    }
    set dlgDefs(revoke,voice) {
	{Revoke Voice}  \
	{Revoke voice from the participant "$nick" in the room "$roomName"}  \
    }
    set dlgDefs(revoke,member) {
	{Revoke Membership}  \
	{Revoke membership from "$nick" in the room "$roomName"}  \
    }
    set dlgDefs(revoke,moderator) {
	{Revoke Moderator}  \
	{Revoke moderator privileges from "$nick" for the room "$roomName"}  \
    }
    set dlgDefs(revoke,admin) {
	{Revoke Administrator}  \
	{Revoke administrator privileges from "$nick" for the room "$roomName"}  \
    }
    set dlgDefs(revoke,owner) {
	{Revoke Owner}  \
	{Revoke owner privileges from "$nick" in the room "$roomName"}  \
    }
    array set actionDefs {
	grant,voice,cmd         setrole 
	grant,voice,what        participant 
	grant,member,cmd        setaffiliation 
	grant,member,what       member 
	grant,moderator,cmd     setrole 
	grant,moderator,what    moderator 
	grant,admin,cmd         setaffiliation 
	grant,admin,what        admin 
	grant,owner,cmd         setaffiliation 
	grant,owner,what        owner 
	revoke,voice,cmd        setrole
	revoke,voice,what       visitor
	revoke,member,cmd       setaffiliation 
	revoke,member,what      none 
	revoke,moderator,cmd    setrole 
	revoke,moderator,what   participant 
	revoke,admin,cmd        setaffiliation 
	revoke,admin,what       member 
	revoke,owner,cmd        setaffiliation 
	revoke,owner,what       admin 
    }
    
    # Need selected line here. $item = numerical index.
    set wtbl $locals(wtbl)
    set item [$wtbl curselection]
    if {[string length $item] == 0} {
	return
    }
    set row [$wtbl get $item]
    foreach {nick role aff} $row break
    regexp {^([^@]+)@.+} $roomjid match roomName
    
    set ans [eval {
      ::UI::MegaDlgMsgAndEntry} [subst $dlgDefs($which,$type)] \
      {"Reason:" reason [mc Cancel] [mc OK]}]
    set opts {}
    if {$reason != ""} {
	set opts [list -reason $reason]
    }

    if {$ans == "ok"} {
	if {[catch {
	    eval {$jstate(muc) $actionDefs($which,$type,cmd) $roomjid  \
	      $nick $actionDefs($which,$type,what)  \
	      -command [list [namespace current]::IQCallback $roomjid]} $opts
	} err]} {
	    ::UI::MessageBox -type ok -icon error -title "Network Error" \
	      -message "Network error ocurred: $err"
	}
    }
}

proc ::MUC::Kick {roomjid} {
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate
    
    # Need selected line here. $item = numerical index.
    set wtbl $locals(wtbl)
    set item [$wtbl curselection]
    if {[string length $item] == 0} {
	return
    }
    set row [$wtbl get $item]
    foreach {nick role aff} $row break
    regexp {^([^@]+)@.+} $roomjid match roomName
    
    set ans [::UI::MegaDlgMsgAndEntry  \
      {Kick Participant}  \
      "Kick the participant \"$nick\" from the room \"$roomName\""  \
      "Reason:"  \
      reason [mc Cancel] [mc OK]]
    set opts {}
    if {$reason != ""} {
	set opts [list -reason $reason]
    }
    
    if {$ans == "ok"} {
	if {[catch {
	    eval {$jstate(muc) setrole $roomjid $nick "none" \
	      -command [list [namespace current]::IQCallback $roomjid]} $opts
	} err]} {
	    ::UI::MessageBox -type ok -icon error -title "Network Error" \
	      -message "Network error ocurred: $err"
	}
    }
}

proc ::MUC::Ban {roomjid} {
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate

    # Need selected line here. $item = numerical index.
    set wtbl $locals(wtbl)
    set item [$wtbl curselection]
    if {[string length $item] == 0} {
	return
    }
    set row [$wtbl get $item]
    foreach {nick role aff} $row break
    regexp {^([^@]+)@.+} $roomjid match roomName
    
    set ans [::UI::MegaDlgMsgAndEntry  \
      {Ban User}  \
      "Ban the user \"$nick\" from the room \"$roomName\""  \
      "Reason:"  \
      reason [mc Cancel] [mc OK]]
    set opts {}
    if {$reason != ""} {
	set opts [list -reason $reason]
    }
    
    if {$ans == "ok"} {
	if {[catch {
	    eval {$jstate(muc) setaffiliation $roomjid $nick "outcast" \
	      -command [list [namespace current]::IQCallback $roomjid]} $opts
	} err]} {
	    ::UI::MessageBox -type ok -icon error -title "Network Error" \
	      -message "Network error ocurred: $err"
	}
    }
}

namespace eval ::MUC:: {
    
    ::hooks::register closeWindowHook    ::MUC::EditListCloseHook
}

# MUC::EditListBuild --
#
#       Shows and handles a dialog for edit various lists of room content.
#       
# Arguments:
#       roomjid
#       type        voice, ban, member, moderator, admin, owner
#       
# Results:
#       "cancel" or "result".

proc ::MUC::EditListBuild {roomjid type} {
    global this wDlgs
    
    upvar [namespace current]::${roomjid}::editlocals editlocals
    upvar ::Jabber::jstate jstate
    variable fineditlist -1
    variable dlguid
    variable editcalluid
    variable setListDefs
    
    # Customize according to the $type.
    array set editmsg {
	voice     {Edit the privilege to speak in the room, the voice.}
	ban       {Edit the ban list}
	member    {Edit the member list}
	moderator {Edit the moderator list}
	admin     {Edit the admin list}
	owner     {Edit the owner list}
    }
    array set setListDefs {
	voice     {nick affiliation role jid reason}
	ban       {jid reason}
	member    {nick affiliation role jid reason}
	moderator {nick role jid reason}
	admin     {jid affiliation reason}
	owner     {jid reason}
    }
    foreach what {voice ban member moderator admin owner} {
	foreach txt $setListDefs($what) {
	    lappend columns($what) 0 [string totitle $txt]
	}
    }
    
    set titleType [string totitle $type]
    set tblwidth [expr 10 + 12 * [llength $setListDefs($type)]]
    set editlocals(listvar) {}
    
    set w $wDlgs(jmucedit)[incr dlguid]
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    set roomName [$jstate(jlib) service name $roomjid]
    if {$roomName == ""} {
	regexp {([^@]+)@.+} $roomjid match roomName
    }
    wm title $w "Edit List $titleType: $roomName"
    
    set fontS [option get . fontSmall {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 4
    regexp {^([^@]+)@.*} $roomjid match roomName
    pack [message $w.frall.msg -width 300  \
      -text $editmsg($type)] -side top -anchor w -padx 4 -pady 2
    
    #
    set wmid $w.frall.fr
    pack [frame $wmid] -side top -fill x -expand 1 -padx 6
    
    # Tablelist with scrollbar ---
    set frtab $wmid.tab    
    set wysc $frtab.ysc
    set wtbl $frtab.tb
    pack [frame $frtab] -padx 0 -pady 0 -side left
    tablelist::tablelist $wtbl -width $tblwidth -height 8 \
      -columns $columns($type) -stretch all -selectmode single  \
      -yscrollcommand [list $wysc set]  \
      -editendcommand [list [namespace current]::VerifyEditEntry $roomjid] \
      -listvariable [namespace current]::${roomjid}::editlocals(listvar)
    scrollbar $wysc -orient vertical -command [list $wtbl yview]
    grid $wtbl $wysc -sticky news
    grid columnconfigure $frtab 0 -weight 1

    option add *$wtbl*selectBackground		navy      widgetDefault
    option add *$wtbl*selectForeground		white     widgetDefault

    $wtbl columnconfigure end -editable yes

    switch -- $type {
	voice {
	}
	ban {
	    $wtbl columnconfigure 0 -editable yes
	}
	member {
	}
	moderator {
	}
	admin {
	    $wtbl columnconfigure end -editable yes
	}
	owner {    
	    $wtbl columnconfigure 0 -editable yes
	} 
    }
    
    # Special bindings for the tablelist.
    set body [$wtbl bodypath]
    bind $body <Button-1> {+ focus %W}
    #bind $body <Double-1> [list [namespace current]::XXX $roomjid]
    bind $wtbl <<ListboxSelect>> [list [namespace current]::EditListSelect $roomjid]
    
    # Action buttons.
    set wbts $wmid.fr
    set wbtadd $wbts.add
    set wbtedit $wbts.edit
    set wbtrm $wbts.rm
    pack [frame $wbts] -side right -anchor n -padx 4 -pady 4
    button $wbtadd -text "Add" -font $fontS -state disabled -command \
      [list [namespace current]::EditListDoAdd $roomjid]
    button $wbtedit -text "Edit" -font $fontS -state disabled -command \
      [list [namespace current]::EditListDoEdit $roomjid]
    button $wbtrm -text "Remove" -font $fontS -state disabled -command \
      [list [namespace current]::EditListDoRemove $roomjid]
    
    grid $wbtadd -pady 2 -sticky ew
    grid $wbtedit -pady 2 -sticky ew
    grid $wbtrm -pady 2 -sticky ew
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set wsearrows $frbot.arr
    set wbtok $frbot.btok
    pack $frbot  -side bottom -fill x -padx 10 -pady 8
    pack [button $wbtok -text [mc OK] -state disabled \
      -default active -command "set [namespace current]::fineditlist 1"] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel]  \
      -command "set [namespace current]::fineditlist 0"]  \
      -side right -padx 5 -pady 5  
    pack [::chasearrows::chasearrows $wsearrows -size 16] \
      -side left -padx 5 -pady 5
    pack [button $frbot.btres -text [mc Reset]  \
      -command [list [namespace current]::EditListReset $roomjid]]  \
      -side left -padx 5 -pady 5  
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    bind $w <Escape> [list $frbot.btcancel invoke]
    
    # Grab and focus.
    set oldFocus [focus]
    
    # Cache local variables.
    set editlocals(wtbl) $wtbl
    set editlocals(wsearrows) $wsearrows
    set editlocals(wbtok) $wbtok  
    set editlocals(type) $type
    set editlocals(wbtadd) $wbtadd
    set editlocals(wbtedit) $wbtedit
    set editlocals(wbtrm) $wbtrm
    set editlocals(origlistvar) {}
    set editlocals(listvar) {}
    
    # How and what to get.
    switch -- $type {
	voice {
	   set getact getrole
	   set setact setrole
	   set what participant
	}
	ban {
	   set getact getaffiliation
	   set setact setaffiliation
	   set what outcast
	}
	member {
	   set getact getaffiliation
	   set setact setaffiliation
	   set what member
	}
	moderator {
	   set getact getrole
	   set setact setrole
	   set what moderator
	}
	admin {
	   set getact getaffiliation
	   set setact setaffiliation
	   set what admin
	}
	owner {    
	   set getact getaffiliation
	   set setact setaffiliation
	   set what owner
	} 
	default {
	    return -code error "Unrecognized type \"$type\""
	}
    }
    set editlocals(getact) $getact
    set editlocals(setact) $setact
    
    # Now, go and get it!
    $wsearrows start
    set editlocals(callid) [incr editcalluid]
    if {[catch {
	$jstate(muc) $getact $roomjid $what \
	  [list [namespace current]::EditListGetCB $roomjid $editlocals(callid)]
    } err]} {
	$wsearrows stop
	::UI::MessageBox -type ok -icon error -title "Network Error" \
	  -message "Network error ocurred: $err"
    }      
    
    # Wait here for a button press.
    tkwait variable [namespace current]::fineditlist
    
    ::UI::SaveWinGeom $w
    catch {destroy $w}
    catch {focus $oldFocus}

    set opts {}

    if {$fineditlist > 0} {
	EditListSet $roomjid
    }
    return [expr {($fineditlist <= 0) ? "cancel" : "ok"}]
}

proc ::MUC::EditListCloseHook {wclose} {
    global  wDlgs
    variable fineditlist
	
    if {[string equal $wDlgs(jmucedit) $wclose]} {
	set fineditlist 0
    }   
}

proc ::MUC::EditListGetCB {roomjid callid mucname type subiq} {

    upvar [namespace current]::${roomjid}::editlocals editlocals
    upvar ::Jabber::jstate jstate

    set type $editlocals(type)
    set wtbl $editlocals(wtbl)
    set wsearrows $editlocals(wsearrows)
    set wbtok $editlocals(wbtok)
    set wbtadd $editlocals(wbtadd)
    set wbtedit $editlocals(wbtedit)
    set wbtrm $editlocals(wbtrm)

    # Verify that this callback does indeed be the most recent.
    if {$callid != $editlocals(callid)} {
	return
    }
    if {![winfo exists $wsearrows]} {
	return
    }
    
    $wsearrows stop
    if {$type == "error"} {
	::UI::MessageBox -type ok -icon error -message $subiq
	return
    }
    
    set editlocals(subiq) $subiq

    # Fill tablelist.
    FillEditList $roomjid
    $wbtok configure -state normal -default active

    switch -- $type {
	voice {
	    $wbtrm configure -state normal
	}
	ban {
	    $wbtadd configure -state normal
	    $wbtrm configure -state normal
	}
	member {
	    $wbtrm configure -state normal
	}
	moderator {
	    $wbtrm configure -state normal
	}
	admin {
	    $wbtadd configure -state normal
	    $wbtrm configure -state normal
	}
	owner {    
	    $wbtedit configure -state normal
	} 
    }
}

proc ::MUC::FillEditList {roomjid} {
    upvar [namespace current]::${roomjid}::editlocals editlocals

    variable setListDefs

    set wtbl $editlocals(wtbl)
    set wsearrows $editlocals(wsearrows)
    set wbtok $editlocals(wbtok)
    set type $editlocals(type)
    
    set queryElem [wrapper::getchildren $editlocals(subiq)]
    set tmplist {}
    
    foreach item [wrapper::getchildren $queryElem] {
	set row {}
	array set val {nick "" role none affiliation none jid "" reason ""}
	array set val [lindex $item 1]
	foreach c [wrapper::getchildren $item] {
	    if {[string equal [lindex $c 0] "reason"]} {
		set val(reason) [lindex $c 3]
		break
	    }
	}
	foreach key $setListDefs($type) {
	    lappend row $val($key)
	}
	lappend $tmplist $row
    }
    
    # Fill table. Cache orig result.
    set editlocals(origlistvar) $tmplist
    set editlocals(listvar) $tmplist
}

proc ::MUC::VerifyEditEntry {roomjid wtbl row col text} {
    upvar [namespace current]::${roomjid}::editlocals editlocals
    variable setListDefs

    set type $editlocals(type)

    # Is this a jid entry?
    if {[lsearch $setListDefs($type) jid] != $col} {
	return
    }
    
    if {![jlib::jidvalidate $text]} {
	bell
	::UI::MessageBox -icon error -message "Illegal jid \"$text\"" \
	  -parent [winfo toplevel $wtbl] -type ok
	$wtbl rejectinput
	return ""
    }
}

proc ::MUC::EditListSelect {roomjid} {
    upvar [namespace current]::${roomjid}::editlocals editlocals
    
    set wtbl $editlocals(wtbl)
    
}

proc ::MUC::EditListDoAdd {roomjid} {
    upvar [namespace current]::${roomjid}::editlocals editlocals
    variable setListDefs

    set wtbl $editlocals(wtbl)
    set type $editlocals(type)
    set len [llength $setListDefs($type)]
    for {set i 0} {$i < $len} {incr i} {
	lappend empty {}
    }
    lappend editlocals(listvar) $empty
    set indjid [lsearch $setListDefs($type) jid]
    array set indColumnFocus [list  \
	voice      end      \
	ban        $indjid  \
	member     end      \
	moderator  end      \
	admin      $indjid  \
	owner      end      \
    ]
    
    # Set focus.
    $wtbl editcell end,$indColumnFocus($type)
    focus [$wtbl entrypath]
}

proc ::MUC::EditListDoEdit {roomjid} {
    upvar [namespace current]::${roomjid}::editlocals editlocals

    set wtbl $editlocals(wtbl)
    set type $editlocals(type)

    switch -- $type {
	owner {
	    $wtbl editcell end,0
	}
    }
}

proc ::MUC::EditListDoRemove {roomjid} {
    upvar [namespace current]::${roomjid}::editlocals editlocals
    variable setListDefs

    set wtbl $editlocals(wtbl)
    set type $editlocals(type)
    set item [$wtbl curselection]
    if {[string length $item] == 0} {
	return 
    }
    
    switch -- $type {
	voice {
	    set ind [lsearch $setListDefs($type) "role"]
	    $wtbl cellconfigure $item,$ind -text "visitor"
	}
	ban {
	}
	member {
	    set ind [lsearch $setListDefs($type) "affiliation"]
	    $wtbl cellconfigure $item,$ind -text "none"
	}
	moderator {
	    set ind [lsearch $setListDefs($type) "role"]
	    $wtbl cellconfigure $item,$ind -text "participant"
	}
	admin {
	    set ind [lsearch $setListDefs($type) "affiliation"]
	    $wtbl cellconfigure $item,$ind -text "none"
	}
	owner {
	}
    }
}

proc ::MUC::EditListReset {roomjid} {
    upvar [namespace current]::${roomjid}::editlocals editlocals

    set editlocals(listvar) $editlocals(origlistvar)
}

# MUC::EditListSet --
# 
#       Set (send) the dited list to the muc service.

proc ::MUC::EditListSet {roomjid} {
    upvar [namespace current]::${roomjid}::editlocals editlocals
    variable setListDefs
    upvar ::Jabber::jstate jstate

    # Original and present content of tablelist.
    set origlist $editlocals(origlistvar)
    set thislist $editlocals(listvar)
    set type $editlocals(type)
    set setact $editlocals(setact)
    
    # Only the 'diff' is necessary to send.
    # Loop through each row in the tablelist.
    foreach row $thislist {
	
	
	
	
    }
    
    switch -- $type {
	voice {

	}
	ban {

	}
	member {

	}
	moderator {

	}
	admin {

	}
	owner {

	}
    }

    
    
    if {[catch {eval {
	$jstate(muc) $setact $roomjid xxx \
	  -command [list [namespace current]::IQCallback $roomjid]} $opts
    } err]} {
	::UI::MessageBox -type ok -icon error -title "Network Error" \
	  -message "Network error ocurred: $err"
    }    
}
    
# End edit lists ---------------------------------------------------------------

# Unfinished...

namespace eval ::MUC:: {
    
    ::hooks::register closeWindowHook    ::MUC::RoomConfigCloseHook
}

proc ::MUC::RoomConfig {roomjid} {
    global  this wDlgs
    
    variable wbox
    variable wsearrows
    variable wbtok
    variable dlguid
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate
    
    set w $wDlgs(jmuccfg)[incr dlguid]
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
    wm title $w "Configure Room"
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 4
            
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set wsearrows $frbot.arr
    set wbtok $frbot.btok
    set wbtcancel $frbot.btcancel
    pack [button $wbtok -text [mc OK] -default active \
      -state disabled -command  \
        [list [namespace current]::DoRoomConfig $roomjid $w]]  \
      -side right -padx 5 -pady 5
    pack [button $wbtcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelConfig $roomjid $w]]  \
      -side right -padx 5 -pady 5
    pack [::chasearrows::chasearrows $wsearrows -size 16] \
      -side left -padx 5 -pady 5
    pack $frbot -side bottom -fill x -expand 0 -padx 8 -pady 6
    
    # The form part.
    set wbox $w.frall.frmid
    ::Jabber::Forms::BuildScrollForm $wbox -height 200 -width 320
    pack $wbox -side top -fill both -expand 1 -padx 8 -pady 4
    
    # Now, go and get it!
    $wsearrows start
    if {[catch {
	$jstate(muc) getroom $roomjid  \
	  [list [namespace current]::ConfigGetCB $roomjid]
    }]} {
	$wsearrows stop
	::UI::MessageBox
    }   
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    
    # Wait here for a button press and window to be destroyed. BAD?
    tkwait window $w
    
    ::UI::SaveWinGeom $w
    catch {focus $oldFocus}
    return
}

proc ::MUC::RoomConfigCloseHook {wclose} {
    global  wDlgs

    #wm protocol $w WM_DELETE_WINDOW  \
    #  [list [namespace current]::CancelConfig $roomjid $w]

    if {[string match $wDlgs(jmuccfg)* $wclose]} {

	
    }   
}

proc ::MUC::CancelConfig {roomjid w} {
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate

    catch {$jstate(muc) setroom $roomjid cancel}
    destroy $w
}

proc ::MUC::ConfigGetCB {roomjid mucname type subiq} {
    variable wbox
    variable wsearrows
    variable wbtok
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate

    $wsearrows stop
    set childList [wrapper::getchildren $subiq]    
    ::Jabber::Forms::FillScrollForm $wbox $childList -template "room"
    $wbtok configure -state normal -default active
}

proc ::MUC::DoRoomConfig {roomjid w} {
    variable wbox
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate

    set subelements [::Jabber::Forms::GetScrollForm $wbox]
    
    if {[catch {
	$jstate(muc) setroom $roomjid submit -form $subelements \
	  -command [list [namespace current]::RoomConfigResult $roomjid]
    }]} {
	::UI::MessageBox -type ok -icon error -title "Network Error" \
	  -message "Network error ocurred: $err"
	return
    }
    destroy $w
}

proc ::MUC::RoomConfigResult {roomjid mucname type subiq} {

    if {$type == "error"} {
	regexp {^([^@]+)@.*} $roomjid match roomName
	::UI::MessageBox -type ok -icon error  \
	  -message "We failed trying to configurate room \"$roomName\".\
	  [lindex $subiq 0] [lindex $subiq 1]"
    }
}

# MUC::SetNick --
# 
# 

proc ::MUC::SetNick {roomjid} {
    variable locals
    upvar ::Jabber::jstate jstate
    
    set topic ""
    set ans [::UI::MegaDlgMsgAndEntry  \
      [mc "Set New Nickname"]  \
      [mc "Select a new nickname"]  \
      "[mc {New Nickname}]:"  \
      nickname [mc Cancel] [mc OK]]
    
    # Perhaps check that characters are valid?

    if {($ans == "ok") && ($nickname != "")} {
	if {[catch {
	    $jstate(muc) setnick $roomjid $nickname \
	      -command [list [namespace current]::PresCallback $roomjid]
	} err]} {
	    ::UI::MessageBox -type ok -icon error -title "Network Error" \
	      -message "Network error ocurred: $err"
	}
    }
    return $ans
}

namespace eval ::MUC:: {
    
    ::hooks::register closeWindowHook    ::MUC::DestroyCloseHook
}

proc ::MUC::Destroy {roomjid} {
    global this wDlgs
    
    upvar ::Jabber::jstate jstate
    variable findestroy
    variable dlguid
    
    set w $wDlgs(jmucdestroy)[incr dlguid]
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    set roomName [$jstate(jlib) service name $roomjid]
    if {$roomName == ""} {
	regexp {([^@]+)@.+} $roomjid match roomName
    }
    wm title $w "Destroy Room: $roomName"
    set findestroy -1
    
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall  -fill both -expand 1 -ipadx 4
    regexp {^([^@]+)@.*} $roomjid match roomName
    set msg "You are about to destroy the room \"$roomName\".\
      Optionally you may give any present room particpants an\
      alternative room jid and a reason."
    pack [message $w.frall.msg -width 280 -text $msg] \
      -side top -anchor w -padx 4 -pady 2
    
    set wmid $w.frall.fr
    pack [frame $wmid] -side top -fill x -expand 1 -padx 6
    label $wmid.la -font $fontSB -text "Alternative Room Jid:"
    entry $wmid.ejid
    label $wmid.lre -font $fontSB -text "Reason:"
    entry $wmid.ere
    
    grid $wmid.la -column 0 -row 0 -sticky e -padx 2 
    grid $wmid.ejid -column 1 -row 0 -sticky ew -padx 2 
    grid $wmid.lre -column 0 -row 1 -sticky e -padx 2 
    grid $wmid.ere -column 1 -row 1 -sticky ew -padx 2 
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack $frbot  -side bottom -fill x -padx 10 -pady 8
    pack [button $frbot.btok -text [mc OK]  \
      -default active -command "set [namespace current]::findestroy 1"] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel]  \
      -command "set [namespace current]::findestroy 0"]  \
      -side right -padx 5 -pady 5  
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    bind $w <Escape> [list $frbot.btcancel invoke]
    
    # Grab and focus.
    set oldFocus [focus]
    focus $wmid.ejid
    catch {grab $w}
    
    # Wait here for a button press.
    tkwait variable [namespace current]::findestroy
    
    set jid [$wmid.ejid get]
    set reason [$wmid.ere get]
    ::UI::SaveWinGeom $w

    catch {grab release $w}
    catch {destroy $w}
    catch {focus $oldFocus}

    set opts {}
    if {$reason != ""} {
	set opts [list -reason $reason]
    }
    if {$jid != ""} {
	set opts [list -alternativejid $jid]
    }

    if {$findestroy > 0} {
	if {[catch {eval {
	    $jstate(muc) destroy $roomjid  \
	      -command [list [namespace current]::IQCallback $roomjid]} $opts
	} err]} {
	    ::UI::MessageBox -type ok -icon error -title "Network Error" \
	      -message "Network error ocurred: $err"
	}
    }
    return [expr {($findestroy <= 0) ? "cancel" : "ok"}]
}

proc ::MUC::DestroyCloseHook {wclose} {
    global  wDlgs
    variable findestroy
	
    if {[string equal $wDlgs(jmucdestroy) $wclose]} {
	set findestroy 0
    }   
}

# MUC::IQCallback, PresCallback --
# 
#       Generic callbacks when setting things via <iq/> or <presence/>

proc ::MUC::IQCallback {roomjid mucname type subiq} {
    
    if {$type == "error"} {
    	regexp {^([^@]+)@.*} $roomjid match roomName
    	set msg "We received an error when interaction with the room\
    	\"$roomName\": $subiq"
	::UI::MessageBox -type ok -icon error -title "Error" -message $msg
    }
}


proc ::MUC::PresCallback {roomjid mucname type args} {
    
    if {$type == "error"} {
    	set errcode ???
    	set errmsg ""
    	if {[info exists argsArr(-error)]} {
	    foreach {errcode errmsg} $argsArr(-error) break
	}	
    	regexp {^([^@]+)@.*} $roomjid match roomName
    	set msg "We received an error when interaction with the room\
    	\"$roomName\": $errmsg"
	::UI::MessageBox -type ok -icon error -title "Error" -message $msg
    }
}

proc ::MUC::InfoCloseHook {wclose} {
    global  wDlgs
	
    if {[string match $wDlgs(jmucinfo)* $wclose]} {

	# Need to find roomjid from toplevel widget.
	foreach ns [namespace children [namespace current]] {
	    set roomjid [namespace tail $ns]
	    if {[string equal [set ${ns}::locals($roomjid,w)] $wclose]} {
		Close $roomjid
	    }
	}
    }   
}

proc ::MUC::Close {roomjid} {
    upvar [namespace current]::${roomjid}::locals locals

    catch {destroy $locals($roomjid,w)}
    namespace delete [namespace current]::${roomjid}
}

#-------------------------------------------------------------------------------
