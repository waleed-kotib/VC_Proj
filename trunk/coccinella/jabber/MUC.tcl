#  MUC.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements parts of the UI for the Multi User Chat protocol.
#      
#      This code is not completed!!!!!!!
#      
#  Copyright (c) 2003-2005  Mats Bengtsson
#  
# $Id: MUC.tcl,v 1.63 2005-08-26 15:02:34 matben Exp $

package require entrycomp
package require muc

package provide MUC 1.0

namespace eval ::MUC:: {
      
    ::hooks::register jabberInitHook     ::MUC::Init
    
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

    if {$confServers == {}} {
	::UI::MessageBox -type ok -icon error -title "No Conference"  \
	  -message "Failed to find any multi user chat service component"
	return
	set confServers junk
    }

    # State variable to collect instance specific variables.
    set token [namespace current]::enter[incr enteruid]
    variable $token
    upvar 0 $token enter
    
    set w $wDlgs(jmucenter)[incr dlguid]
    ::UI::Toplevel $w \
      -macstyle documentProc -macclass {document closeBox} -usemacmainmenu 1 \
      -closecommand [list ::MUC::EnterCloseCmd $token]
    wm title $w [mc {Enter Room}]

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jmucenter)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jmucenter)
    }

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
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 260 -justify left -text [mc jamucentermsg]
    pack $wbox.msg -side top -anchor w

    set frmid $wbox.frmid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1

    ttk::label $frmid.lserv -text "[mc {Conference server}]:" 
    
    # First menubutton: servers. (trace below)
    set wpopupserver $frmid.eserv
    eval {ttk::optionmenu $wpopupserver $token\(server)} $confServers
    ttk::label $frmid.lroom -text "[mc {Room name}]:"
    
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
    set wpopuproom     $frmid.eroom
    set wbrowse        $frmid.browse
    set wsearrows      $frmid.st.arr
    set wstatus        $frmid.st.stat
    
    ttk::::combobox $wpopuproom -width -20 -textvariable $token\(roomname)
    ttk::button $wbrowse -text [mc Browse] \
      -command [list [namespace current]::Browse $token]    
    ttk::label $frmid.lnick -text "[mc {Nick name}]:"
    ttk::entry $frmid.enick -textvariable $token\(nickname) -width 24
    ttk::label $frmid.lpass -text "[mc Password]:"
    ttk::entry $frmid.epass -textvariable $token\(password) -show {*} -validate key \
      -validatecommand {::Jabber::ValidatePasswordStr %S}
   
    # Busy arrows and status message.
    ttk::frame $frmid.st
    pack [::chasearrows::chasearrows $wsearrows -size 16] \
      -side left -padx 5 -pady 0
    ttk::label $wstatus -textvariable $token\(status)
    pack $wstatus -side left -padx 5
    
    grid  $frmid.lserv    $wpopupserver  $wbrowse  -sticky e -pady 2
    grid  $frmid.lroom    $wpopuproom    -  -sticky e -padx 2 -pady 2
    grid  $frmid.lnick    $frmid.enick   -  -sticky e -pady 2
    grid  $frmid.lpass    $frmid.epass   -  -sticky e -pady 2
    grid  $frmid.st       -              -  -sticky w -pady 2
    grid  $wpopupserver   $wpopuproom    $frmid.enick  $frmid.epass  -sticky ew
    grid  $wbrowse  -padx 10
    grid columnconfigure $frmid 1 -weight 1

    if {[info exists argsArr(-roomjid)]} {
	jlib::splitjidex $argsArr(-roomjid) enter(roomname) enter(server) z
	set enter(server-state) disabled
	set enter(room-state)   disabled
	$wpopupserver state {disabled}
	$wpopuproom   state {disabled}
    }
    if {[info exists argsArr(-server)]} {
	set enter(server) $argsArr(-server)
	set enter(server-state) disabled
	$wpopupserver state {disabled}
    }
    if {[info exists argsArr(-command)]} {
	set enter(-command) $argsArr(-command)
    }
    if {[info exists argsArr(-nickname)]} {
	set enter(nickname) $argsArr(-nickname)
	$frmid.enick state {disabled}
    }
    if {[info exists argsArr(-password)]} {
	set enter(password) $argsArr(-password)
	$frmid.epass state {disabled}
    }
       
    # Button part.
    set frbot $wbox.b
    set wbtenter  $frbot.btok
    ttk::frame $frbot
    ttk::button $wbtenter -text [mc Enter] \
      -default active -command [list [namespace current]::DoEnter $token]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelEnter $token]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side bottom -fill x

    set enter(status)       "  "
    set enter(wpopupserver) $wpopupserver
    set enter(wpopuproom)   $wpopuproom
    set enter(wsearrows)    $wsearrows
    set enter(wbtenter)     $wbtenter
    set enter(wbrowse) $wbrowse
    
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
    	focus $frmid.enick
    } elseif {[info exists argsArr(-server)]} {
    	focus $frmid.eroom
    } else {
    	focus $frmid.eserv
    }

    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $wbox.msg $w]    
    after idle $script
    
    # Wait here.
    tkwait variable $token\(finished)
    
    catch {focus $oldFocus}
    trace vdelete $token\(server) w  \
      [list [namespace current]::ConfigRoomList $token]
    set finished $enter(finished)
    ::UI::SaveWinGeom $wDlgs(jmucenter) $w
    catch {destroy $enter(w)}
    
    # Unless cancelled we keep 'enter' until got callback.
    if {$finished <= 0} {
	unset enter
    }
    return [expr {($finished <= 0) ? "cancel" : "enter"}]
}

proc ::MUC::CancelEnter {token} {
    variable $token
    upvar 0 $token enter

    set enter(finished) 0
}

proc ::MUC::EnterCloseCmd {token wclose} {
    global  wDlgs
    variable $token
    upvar 0 $token enter

    ::UI::SaveWinGeom $wDlgs(jmucenter) $wclose
    set enter(finished) 0
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
	    $enter(wpopuproom) configure -values {}
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
    $enter(wpopuproom) configure -values $roomList
    set enter(roomname) [lindex $roomList 0]
}

proc ::MUC::BusyEnterDlgIncr {token {num 1}} {
    variable $token
    upvar 0 $token enter
    
    incr enter(statuscount) $num
    
    if {$enter(statuscount) > 0} {
	set enter(status) [mc {Getting available rooms...}]
	$enter(wsearrows) start
	$enter(wpopupserver) state {disabled}
	$enter(wpopuproom)   state {disabled}
	$enter(wbtenter)     state {disabled}
    } else {
	set enter(statuscount) 0
	set enter(status) ""
	$enter(wsearrows) stop
	if {[string equal $enter(server-state) "normal"]} {
	    $enter(wpopupserver) state {!disabled}
	}
	if {[string equal $enter(room-state) "normal"]} {
	    $enter(wpopuproom)   state {!disabled}
	}
	$enter(wbtenter)     state {!disabled}
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

    option add *JMUCInvite.inviteImage         invite         widgetDefault
    option add *JMUCInvite.inviteDisImage      inviteDis      widgetDefault
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
    ::UI::Toplevel $w -class JMUCInvite \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand [list [namespace current]::InviteCloseCmd $token]
    wm title $w [mc {Invite User}]

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jmucinvite)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jmucinvite)
    }
    jlib::splitjidex $roomjid node domain res
    set jidlist [$jstate(roster) getusers -type available]

    set invite(w)        $w
    set invite(reason)   ""
    set invite(finished) -1
    set invite(roomjid)  $roomjid

    set im   [::Theme::GetImage [option get $w inviteImage {}]]
    set imd  [::Theme::GetImage [option get $w inviteDisImage {}]]

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    ttk::label $w.frall.head -style Headlabel \
      -text [mc {Invite User}] -compound left \
      -image [list $im background $imd]
    pack $w.frall.head -side top -anchor w

    ttk::separator $w.frall.s -orient horizontal
    pack $w.frall.s -side top -fill x

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    set msg [mc jainvitegchat $node]
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 300 -justify left -text $msg
    pack $wbox.msg -side top -anchor w

    set wmid $wbox.fr
    ttk::frame $wmid
    pack $wmid -side top -fill x -expand 1
    
    ttk::label $wmid.la -text "[mc Invite] JID:"
    ::entrycomp::entrycomp $wmid.ejid $jidlist -textvariable $token\(jid)
    ttk::label $wmid.lre -text "[mc Reason]:"
    ttk::entry $wmid.ere -textvariable $token\(reason)
    
    grid  $wmid.la   $wmid.ejid  -sticky e -padx 2 -pady 2
    grid  $wmid.lre  $wmid.ere   -sticky e -padx 2 -pady 2
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc OK]  \
      -default active -command [list [namespace current]::DoInvite $token]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelInvite $token]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side top -fill x
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    
    # Grab and focus.
    set oldFocus [focus]
    focus $wmid.ejid
    
    # Wait here for a button press and window to be destroyed.
    tkwait variable $token\(finished)

    catch {focus $oldFocus}
    ::UI::SaveWinGeom $wDlgs(jmucinvite) $w
    catch {destroy $invite(w)}
    set finished $invite(finished)
    unset invite
    return [expr {($finished <= 0) ? "cancel" : "ok"}]
}

proc ::MUC::InviteCloseCmd {token wclose} {
    global  wDlgs
    variable $token
    upvar 0 $token invite

    ::UI::SaveWinGeom $wDlgs(jmucinvite) $invite(w)
    set invite(finished) 0
    return
}

proc ::MUC::CancelInvite {token} {
    variable $token
    upvar 0 $token invite

    set invite(finished) 0
}

proc ::MUC::DoInvite {token} {
    variable $token
    upvar 0 $token invite
    upvar ::Jabber::jstate jstate

    set jid     $invite(jid)
    set reason  $invite(reason)
    set roomjid $invite(roomjid)
    InviteCloseCmd $token $invite(w)
    
    set opts [list -command [list [namespace current]::InviteCB $token]]
    if {$reason != ""} {
	set opts [list -reason $reason]
    }
    eval {$jstate(muc) invite $roomjid $jid} $opts
    set invite(finished) 1
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
    
    option add *JMUCInfo.infoImage         info         widgetDefault
    option add *JMUCInfo.infoDisImage      infoDis      widgetDefault

    option add *JMUCInfo*TButton.style     Small.TButton 50
    option add *JMUCInfo*TLabelframe.style  Small.TLabelframe 50
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

    set roomName [$jstate(jlib) service name $roomjid]
    if {$roomName == ""} {
	jlib::splitjidex $roomjid roomName x y
    }

    set locals($roomjid,w) $w
    set locals($w,roomjid) $roomjid
    set locals($roomjid,mynick) [$jstate(muc) mynick $roomjid]
    set locals($roomjid,myrole) none
    set locals($roomjid,myaff) none

    ::UI::Toplevel $w -class JMUCInfo \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand [namespace current]::InfoCloseHook
    wm title $w "Info Room: $roomName"
    
    set im   [::Theme::GetImage [option get $w infoImage {}]]
    set imd  [::Theme::GetImage [option get $w infoDisImage {}]]

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    ttk::label $w.frall.head -style Headlabel \
      -text "Info Room" -compound left \
      -image [list $im background $imd]
    pack $w.frall.head -side top -anchor w

    ttk::separator $w.frall.s -orient horizontal
    pack $w.frall.s -side top -fill x

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    set msg "This dialog makes available a number of options and actions for a\
      room. Your role and affiliation determines your privilege to act.\
      Further restrictions may exist depending on specific room\
      configuration."
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 12} -wraplength 300 -justify left -text $msg
    pack $wbox.msg -side top -anchor w
        
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btcancel -style TButton \
      -text [mc Close]  \
      -command [list [namespace current]::Close $roomjid]
    pack $frbot.btcancel -side right
    pack $frbot -side bottom -fill x
    
    # A frame.
    set frleft $wbox.fleft
    ttk::frame $frleft
    pack $frleft -side left
    
    # Tablelist with scrollbar ---
    set frtab $frleft.frtab    
    set wysc  $frtab.ysc
    set wtbl  $frtab.tb
    ttk::frame $frtab
    pack $frtab -side top
    set columns [list 0 Nickname 0 Role 0 Affiliation]
    
    tablelist::tablelist $wtbl  \
      -columns $columns -stretch all -selectmode single  \
      -yscrollcommand [list $wysc set] -width 36 -height 8
    tuscrollbar $wysc -orient vertical -command [list $wtbl yview]
    ttk::button $frtab.ref -text [mc Refresh] -font CociSmallFont -command  \
      [list [namespace current]::Refresh $roomjid]

    grid  $wtbl       $wysc  -sticky news
    grid  $frtab.ref  x      -sticky e -pady 2
    grid columnconfigure $frtab 0 -weight 1
    
    # Special bindings for the tablelist.
    set body [$wtbl bodypath]
    bind $body <Button-1> {+ focus %W}
    bind $body <Double-1> [list [namespace current]::DoubleClickPart $roomjid]
    bind $wtbl <<ListboxSelect>> [list [namespace current]::SelectPart $roomjid]
    
    # Fill in tablelist.
    set locals(wtbl) $wtbl
    FillTable $roomjid
    
    # A frame.
    set frgrantrevoke $frleft.grrev
    ttk::frame $frgrantrevoke -padding {0 8 0 0}
    pack $frgrantrevoke -side top
        
    # Grant buttons ---
    set wgrant $frgrantrevoke.grant
    ttk::labelframe $wgrant -text "Grant:" \
      -padding [option get . groupSmallPadding {}]
    
    foreach txt {Voice Member Moderator Admin Owner} {
	set stxt [string tolower $txt]
	ttk::button $wgrant.bt$stxt -text [mc $txt]  \
	  -command [list [namespace current]::GrantRevoke $roomjid grant $stxt]
	grid  $wgrant.bt$stxt  -sticky ew -pady 4
    }
    
    # Revoke buttons ---
    set wrevoke $frgrantrevoke.rev
    ttk::labelframe $wrevoke -text "Revoke:" \
      -padding [option get . groupSmallPadding {}]
    
    foreach txt {Voice Member Moderator Admin Owner} {
	set stxt [string tolower $txt]
	ttk::button $wrevoke.bt$stxt -text [mc $txt]  \
	  -command [list [namespace current]::GrantRevoke $roomjid revoke $stxt]
	grid $wrevoke.bt$stxt -sticky ew -pady 4
    }
    grid  $wgrant  $wrevoke  -padx 8  
    
    # A frame.
    set frmid $wbox.mid
    ttk::frame $frmid
    pack $frmid -side top
    
    # Other buttons ---
    set wother $frmid.fraff
    ttk::frame $wother
    pack $wother -side top

    ttk::button $wother.btkick -text "Kick Participant"  \
      -command [list [namespace current]::Kick $roomjid]
    ttk::button $wother.btban -text "Ban Participant"  \
      -command [list [namespace current]::Ban $roomjid]
    ttk::button $wother.btconf -text "Configure Room"  \
      -command [list [namespace current]::RoomConfig $roomjid]
    ttk::button $wother.btdest -text "Destroy Room"  \
      -command [list [namespace current]::Destroy $roomjid]

    grid  $wother.btkick  -sticky ew -pady 4
    grid  $wother.btban   -sticky ew -pady 4
    grid  $wother.btconf  -sticky ew -pady 4
    grid  $wother.btdest  -sticky ew -pady 4
    
    # Edit lists ---
    set wlist $frmid.lists
    ttk::labelframe $wlist -text "Edit Lists:" \
      -padding [option get . groupSmallPadding {}]
    pack $wlist -side top -pady 8

    foreach txt {Voice Ban Member Moderator Admin Owner} {
	set stxt [string tolower $txt]	
	ttk::button $wlist.bt$stxt -text "$txt..."  \
	  -command [list [namespace current]::EditListBuild $roomjid $stxt]
	grid  $wlist.bt$stxt  -sticky ew -pady 4
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
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $wbox.msg $w]
    after idle $idleScript
    return
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
	$wbt state {!disabled}
    }
    foreach wbt $enabledBtAffList($affiliation) {
	set wbt [subst -nobackslashes -nocommands $wbt]
	$wbt state {!disabled}
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
    	$wbt state {!disabled}
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
    
    upvar ::Jabber::jstate jstate
    variable dlguid
    variable editcalluid
    variable setListDefs
    
    # Customize according to the $type.
    array set editmsg {
	voice     "Edit the privilege to speak in the room, the voice."
	ban       "Edit the ban list"
	member    "Edit the member list"
	moderator "Edit the moderator list"
	admin     "Edit the admin list"
	owner     "Edit the owner list"
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

    # State variable to collect instance specific variables.
    set token [namespace current]::edtlst[incr dlguid]
    variable $token
    upvar 0 $token state

    set titleType [string totitle $type]
    set tblwidth [expr 10 + 12 * [llength $setListDefs($type)]]
    set roomName [$jstate(jlib) service name $roomjid]
    if {$roomName == ""} {
	jlib::splitjidex $roomjid roomName x y
    }
    
    set w $wDlgs(jmucedit)[incr dlguid]
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox} \
      -closecommand ::MUC::EditListCloseHook
    wm title $w "Edit List $titleType: $roomName"
        
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    ttk::label $wbox.msg  \
      -padding {0 0 0 6} -wraplength 300 -justify left -text $editmsg($type)
    pack $wbox.msg -side top -anchor w
    
    #
    set wmid $wbox.fr
    ttk::frame $wmid
    pack $wmid -side top -fill x -expand 1
    
    # Tablelist with scrollbar ---
    set frtab $wmid.tab    
    set wysc  $frtab.ysc
    set wtbl  $frtab.tb
    frame $frtab
    pack  $frtab -side left
    tablelist::tablelist $wtbl -width $tblwidth -height 8 \
      -columns $columns($type) -stretch all -selectmode single  \
      -yscrollcommand [list $wysc set]  \
      -editendcommand [list [namespace current]::VerifyEditEntry $token] \
      -listvariable $token\(listvar)
    tuscrollbar $wysc -orient vertical -command [list $wtbl yview]

    grid  $wtbl  $wysc  -sticky news
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
    bind $wtbl <<ListboxSelect>> \
      [list [namespace current]::EditListSelect $token]
    
    # Action buttons.
    set wbts    $wmid.fr
    set wbtadd  $wbts.add
    set wbtedit $wbts.edit
    set wbtrm   $wbts.rm
    ttk::frame $wbts
    pack $wbts -side right -anchor n -padx 4 -pady 4
    
    ttk::button $wbtadd -text [mc Add] \
      -command [list [namespace current]::EditListDoAdd $token]
    ttk::button $wbtedit -text [mc Edit] \
      -command [list [namespace current]::EditListDoEdit $token]
    ttk::button $wbtrm -text [mc Remove] \
      -command [list [namespace current]::EditListDoRemove $token]
    
    grid  $wbtadd   -pady 8 -sticky ew
    grid  $wbtedit  -pady 8 -sticky ew
    grid  $wbtrm    -pady 8 -sticky ew
    
    $wbtadd  state {disabled}
    $wbtedit state {disabled}
    $wbtrm   state {disabled}
    
    # Button part.
    set frbot     $wbox.b
    set wsearrows $frbot.arr
    set wbtok     $frbot.btok
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    pack $frbot  -side bottom -fill x -padx 10 -pady 8
    ttk::button $frbot.btok -text [mc OK] \
      -default active -command [list [namespace current]::EditListOK $token]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::EditListCancel $token]
    ::chasearrows::chasearrows $frbot.arr -size 16
    ttk::button $frbot.btres -text [mc Reset]  \
      -command [list [namespace current]::EditListReset $token]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot.arr -side left -padx 8
    pack $frbot.btres -side left
    pack $frbot -side bottom -fill x
    
    $frbot.btok state {disabled}
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    
    set oldFocus [focus]
    
    # Cache local variables.
    set state(wtbl)        $wtbl
    set state(wsearrows)   $wsearrows
    set state(wbtok)       $wbtok  
    set state(type)        $type
    set state(wbtadd)      $wbtadd
    set state(wbtedit)     $wbtedit
    set state(wbtrm)       $wbtrm
    set state(origlistvar) {}
    set state(listvar)     {}
    set state(finished)    -1
    
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
    set state(getact) $getact
    set state(setact) $setact
    
    # Now, go and get it!
    $wsearrows start
    set state(callid) [incr editcalluid]
    if {[catch {
	$jstate(muc) $getact $roomjid $what \
	  [list [namespace current]::EditListGetCB $token $state(callid)]
    } err]} {
	$wsearrows stop
    }      
    
    # Wait here for a button press.
    tkwait variable $token\(finished)

    ::UI::SaveWinPrefixGeom $wDlgs(jmucedit)
    catch {destroy $w}
    catch {focus $oldFocus}

    if {$state(finished) > 0} {
	EditListSet $token
    }
    set finished $state(finished)
    unset state
    return [expr {($finished <= 0) ? "cancel" : "ok"}]
}

proc ::MUC::EditListCloseHook {token wclose} {
    global  wDlgs
    variable $token
    upvar 0 $token state
	
    ::UI::SaveWinPrefixGeom $wDlgs(jmucedit)
    set state(finished) 0
}

proc ::MUC::EditListOK {token} {
    variable $token
    upvar 0 $token state
    
    set state(finished) 1
}

proc ::MUC::EditListCancel {token} {
    variable $token
    upvar 0 $token state
    
    set state(finished) 0
}

proc ::MUC::EditListGetCB {token callid mucname type subiq} {
    variable $token
    upvar 0 $token state

    upvar ::Jabber::jstate jstate

    set type      $state(type)
    set wtbl      $state(wtbl)
    set wsearrows $state(wsearrows)
    set wbtok     $state(wbtok)
    set wbtadd    $state(wbtadd)
    set wbtedit   $state(wbtedit)
    set wbtrm     $state(wbtrm)

    # Verify that this callback does indeed be the most recent.
    if {$callid != $state(callid)} {
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
    
    set state(subiq) $subiq

    # Fill tablelist.
    FillEditList $token
    $wbtok configure -default active
    $wbtok state {!disabled}

    switch -- $type {
	voice {
	    $wbtrm state {!disabled}
	}
	ban {
	    $wbtadd state {!disabled}
	    $wbtrm  state {!disabled}
	}
	member {
	    $wbtrm state {!disabled}
	}
	moderator {
	    $wbtrm state {!disabled}
	}
	admin {
	    $wbtadd state {!disabled}
	    $wbtrm  state {!disabled}
	}
	owner {    
	    $wbtedit state {!disabled}
	} 
    }
}

proc ::MUC::FillEditList {token} {
    variable $token
    upvar 0 $token state

    variable setListDefs

    set wtbl      $state(wtbl)
    set wsearrows $state(wsearrows)
    set wbtok     $state(wbtok)
    set type      $state(type)
    
    set queryElem [wrapper::getchildren $state(subiq)]
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
    set state(origlistvar) $tmplist
    set state(listvar) $tmplist
}

proc ::MUC::VerifyEditEntry {token wtbl row col text} {
    variable $token
    upvar 0 $token state
    variable setListDefs

    set type $state(type)

    # Is this a jid entry?
    if {[lsearch $setListDefs($type) jid] != $col} {
	return
    }
    
    if {![jlib::jidvalidate $text]} {
	bell
	::UI::MessageBox -icon error -message "Illegal jid \"$text\"" \
	  -parent [winfo toplevel $wtbl] -type ok
	$wtbl rejectinput
	return
    }
}

proc ::MUC::EditListSelect {token} {
    variable $token
    upvar 0 $token state
    
    set wtbl $state(wtbl)
    
}

proc ::MUC::EditListDoAdd {token} {
    variable $token
    upvar 0 $token state
    variable setListDefs

    set wtbl $state(wtbl)
    set type $state(type)
    set len [llength $setListDefs($type)]
    for {set i 0} {$i < $len} {incr i} {
	lappend empty {}
    }
    lappend state(listvar) $empty
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

proc ::MUC::EditListDoEdit {token} {
    variable $token
    upvar 0 $token state

    set wtbl $state(wtbl)
    set type $state(type)

    switch -- $type {
	owner {
	    $wtbl editcell end,0
	}
    }
}

proc ::MUC::EditListDoRemove {token} {
    variable $token
    upvar 0 $token state
    variable setListDefs

    set wtbl $state(wtbl)
    set type $state(type)
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

proc ::MUC::EditListReset {token} {
    variable $token
    upvar 0 $token state

    set state(listvar) $state(origlistvar)
}

# MUC::EditListSet --
# 
#       Set (send) the dited list to the muc service.

proc ::MUC::EditListSet {token} {
    variable $token
    upvar 0 $token state
    variable setListDefs
    upvar ::Jabber::jstate jstate

    # Original and present content of tablelist.
    set origlist $state(origlistvar)
    set thislist $state(listvar)
    set type     $state(type)
    set setact   $state(setact)
    
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

    
    
    eval {$jstate(muc) $setact $roomjid xxx \
	  -command [list [namespace current]::IQCallback $roomjid]} $opts
}
    
# End edit lists ---------------------------------------------------------------

# Unfinished...

namespace eval ::MUC:: {
    
    ::hooks::register closeWindowHook    ::MUC::RoomConfigCloseHook
}

proc ::MUC::RoomConfig {roomjid} {
    global  this wDlgs
    
    variable wscrollframe
    variable wsearrows
    variable wbtok
    variable dlguid
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate
    
    set w $wDlgs(jmuccfg)[incr dlguid]
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox} -class MUCConfig
    wm title $w "Configure Room"
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
            
    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    # Button part.
    set frbot     $wbox.b
    set wsearrows $frbot.arr
    set wbtok     $frbot.btok
    set wbtcancel $frbot.btcancel
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc OK] -default active \
      -command [list [namespace current]::DoRoomConfig $roomjid $w]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelConfig $roomjid $w]
    ::chasearrows::chasearrows $wsearrows -size 16
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $wsearrows -side left
    pack $frbot -side bottom -fill x
    
    $frbot.btok state {disabled}
    
    # The form part.
    set wscrollframe $wbox.scform
    ::UI::ScrollFrame $wscrollframe -padding {8 12} -bd 1 -relief sunken
    pack $wscrollframe
        
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
    variable wscrollframe
    variable wsearrows
    variable wbtok
    variable wform
    variable formtoken
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate

    puts "::MUC::ConfigGetCB---------------"
    puts $subiq
    
    $wsearrows stop
    
    if {$type eq "error"} {
	lassign $subiq errcode errmsg
	::UI::MessageBox -icon error -type ok -title [mc Error] -message $errmsg
    } else {
	set frint [::UI::ScrollFrameInterior $wscrollframe]
	set wform $frint.f
	set formtoken [::JForms::Build $wform $subiq -tilestyle Small -width 200]
	pack $wform
	$wbtok configure -default active
	$wbtok state {!disabled}
    }
}

proc ::MUC::DoRoomConfig {roomjid w} {
    variable wform
    variable formtoken
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate

    set subelements [::JForms::GetXML $formtoken]
    
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
    
    puts ::MUC::SetNick
    
    set nickname ""
    set ans [::UI::MegaDlgMsgAndEntry  \
      [mc "Set New Nickname"]  \
      [mc "Select a new nickname"]  \
      "[mc {New Nickname}]:"  \
      nickname [mc Cancel] [mc OK]]
    puts "ans=$ans, nickname=$nickname"
    
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
    

}

proc ::MUC::Destroy {roomjid} {
    global this wDlgs
    
    upvar ::Jabber::jstate jstate
    variable findestroy -1
    variable destroyjid    ""
    variable destroyreason ""
    variable dlguid
    
    set w $wDlgs(jmucdestroy)[incr dlguid]
    ::UI::Toplevel $w \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand ::MUC::DestroyCloseCmd
    set roomName [$jstate(jlib) service name $roomjid]
    if {$roomName == ""} {
	jlib::splitjidex $roomjid roomName x y
    }
    wm title $w "Destroy Room: $roomName"
    ::UI::SetWindowPosition $w $wDlgs(jmucdestroy)
    set findestroy -1
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    set msg "You are about to destroy the room \"$roomName\".\
      Optionally you may give any present room particpants an\
      alternative room jid and a reason."
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 300 -justify left -text $msg
    pack $wbox.msg -side top -anchor w
    
    set wmid $wbox.fr
    ttk::frame $wmid
    pack $wmid -side top -fill x -expand 1
    
    ttk::label $wmid.la -text "Alternative Room Jid:"
    ttk::entry $wmid.ejid -textvariable [namespace current]::destroyjid
    ttk::label $wmid.lre -text "Reason:"
    ttk::entry $wmid.ere -textvariable [namespace current]::destroyreason
    
    grid  $wmid.la   $wmid.ejid  -sticky e -padx 2 -pady 2
    grid  $wmid.lre  $wmid.ere   -sticky e -padx 2 -pady 2
        
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc OK]  \
      -default active -command [list set [namespace current]::findestroy 1]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list set [namespace current]::findestroy 0]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side bottom -fill x
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    
    # Grab and focus.
    set oldFocus [focus]
    focus $wmid.ejid
    catch {grab $w}
    
    # Wait here for a button press.
    tkwait variable [namespace current]::findestroy
    
    ::UI::SaveWinPrefixGeom $wDlgs(jmucdestroy)

    catch {grab release $w}
    catch {destroy $w}
    catch {focus $oldFocus}

    set opts {}
    if {$destroyreason != ""} {
	set opts [list -reason $destroyreason]
    }
    if {$destroyjid != ""} {
	set opts [list -alternativejid $destroyjid]
    }

    if {$findestroy > 0} {
	eval {$jstate(muc) destroy $roomjid  \
	  -command [list [namespace current]::IQCallback $roomjid]} $opts
    }
    return [expr {($findestroy <= 0) ? "cancel" : "ok"}]
}

proc ::MUC::DestroyCloseCmd {wclose} {
    global  wDlgs
    variable findestroy
	
    ::UI::SaveWinPrefixGeom $wDlgs(jmucdestroy)
    set findestroy 0
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
