#  MUC.tcl ---
#  
#      This file is part of the whiteboard application. 
#      It implements parts of the UI for the Multi User Chat protocol.
#      
#  Copyright (c) 2003  Mats Bengtsson
#  
# $Id: MUC.tcl,v 1.3 2003-05-25 15:03:27 matben Exp $

package provide MUC 1.0

namespace eval ::Jabber::MUC:: {
      
    # Local stuff
    variable dlguid 0
    variable editcalluid 0
    
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

    variable server
    variable roomname
    variable wcomboroom
    variable nickname
    variable password
    variable finishedEnter -1
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
    set server ""
    set roomname ""
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
    message $w.frall.msg -width 260 -font $sysFont(s)  \
    	-text "Enter your nick name and press Enter to go into the room.\
	Members only room may require a password."
    pack $w.frall.msg -side top -fill x -anchor w -padx 2 -pady 4
    set frtop $w.frall.top
    pack [frame $frtop] -side top -fill x -padx 4
    label $frtop.lserv -text "[::msgcat::mc {Conference server}]:" \
      -font $sysFont(sb) 

    set confServers [$jstate(browse) getservicesforns  \
      "http://jabber.org/protocol/muc"]
    
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
      -textvariable [namespace current]::roomname -editable 0
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
    
    label $frtop.lnick -text "[::msgcat::mc {Nick name}]:" -font $sysFont(sb)
    entry $frtop.enick -textvariable [namespace current]::nickname
    label $frtop.lpass -text "[::msgcat::mc Password]:" -font $sysFont(sb)
    entry $frtop.epass -textvariable [namespace current]::password
    
    grid $frtop.lserv -column 0 -row 0 -sticky e
    grid $frtop.eserv -column 1 -row 0 -sticky w
    grid $frtop.lroom -column 0 -row 1 -sticky e
    grid $frtop.eroom -column 1 -row 1 -sticky w
    grid $frtop.lnick -column 0 -row 2 -sticky e
    grid $frtop.enick -column 1 -row 2 -sticky w
    grid $frtop.lpass -column 0 -row 3 -sticky e
    grid $frtop.epass -column 1 -row 3 -sticky w
       
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set wsearrows $frbot.arr
    set wbtenter $frbot.btenter
    pack [button $wbtenter -text [::msgcat::mc Enter] -width 8 \
      -default active -command [list [namespace current]::DoEnter $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command [list [namespace current]::CancelEnter $w]]  \
      -side right -padx 5 -pady 5
    pack [::chasearrows::chasearrows $wsearrows -background gray87 -size 16] \
      -side left -padx 5 -pady 5
    pack $frbot -side bottom -fill x -expand 0 -padx 8 -pady 6

    wm resizable $w 0 0

    bind $w <Return> [list $wbtenter invoke]
    
    # Grab and focus.
    set oldFocus [focus]
    if {[info exists argsArr(-roomjid)]} {
    	focus $frtop.enick
    } elseif {[info exists argsArr(-server)]} {
    	focus $frtop.eroom
    } else {
    	focus $frtop.eserv
    }
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed. BAD?
    tkwait window $w
    
    catch {grab release $w}
    focus $oldFocus
    return [expr {($finishedEnter <= 0) ? "cancel" : "create"}]
}

proc ::Jabber::MUC::ConfigRoomList {wcombo pickedServ} {    
    variable wcomboroom
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

proc ::Jabber::MUC::DoEnter {w} {
    variable server
    variable roomname
    variable nickname
    variable finishedEnter
    upvar ::Jabber::jstate jstate
    
    if {($roomname == "") || ($nickname == "")} {
	tk_messageBox -type ok -icon error  \
	  -message "We require that all fields are nonempty"
	return
    }
    set roomJid ${roomname}@${server}
    
    $jstate(jlib) muc enter $roomJid $nickname -command \
      [list [namespace current]::EnterCallback $w]
    set finishedEnter 1
    catch {destroy $w}
   
    # Cache groupchat protocol type (muc|conference|gc-1.0).
    ::Jabber::GroupChat::SetProtocol $roomJid "muc"
}

proc ::Jabber::MUC::CancelEnter {w} {
    variable finishedEnter
    
    set finishedEnter 0
    catch {destroy $w}
}

# Jabber::MUC::EnterCallback --
#
#       Presence callabck from the 'muc enter' command.
#       Just to catch errors and check if any additional info (password)
#       is needed for entering room.
#
# Arguments:
#       jlibName 
#       type    presence typ attribute, 'available' etc.
#       args    -from, -id, -to, -x ...
#       
# Results:
#       None.

proc ::Jabber::MUC::EnterCallback {w jlibName type args} {
    
    Debug 3 "::Jabber::MUC::EnterCallback type=$type, args='$args'"
    array set argsArr $args
    
    if {$type == "error"} {
    	set errcode ???
    	set errmsg ""
    	if {[info exists argsArr(-error)]} {
    	    set errcode [lindex $argsArr(-error) 0]
	    
	    switch -- $errcode {
		401 {
		    
		    # Password required.
		    set roomName ""
		    regexp {^([^@]+)@} $argsArr(-from) m roomName
		    set msg "Error when entering room \"$roomName\":\
		      [lindex $argsArr(-error) 1] Do you want to retry?"
		    set ans [tk_messageBox -type yesno -icon error  \
		      -message $msg]
		    if {$ans == "yes"} {
			::Jabber::MUC::BuildEnter $w -roomjid $argsArr(-from)
		    }
		}
		default {
		    set errmsg [lindex $argsArr(-error) 1]
		    tk_messageBox -type ok -icon error  \
		      -message [FormatTextForMessageBox \
		      [::msgcat::mc jamesserrconfgetcre $errcode $errmsg]]
		}
	    }
	}
	return
    }   
}

# Jabber::MUC::Invite --
# 
#       Make an invitation to a room.

proc ::Jabber::MUC::Invite {roomjid} {
    global this sysFont
    
    upvar ::Jabber::jstate jstate
    variable fininvite
    variable dlguid
    
    set w .dlgmuc[incr dlguid]
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	
    }
    wm title $w {Invite User}
    set fininvite -1
    wm protocol $w WM_DELETE_WINDOW "set [namespace current]::fininvite 0"
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] \
      -fill both -expand 1 -ipadx 4
    regexp {^([^@]+)@.*} $roomjid match roomName
    set msg "Invite a user for groupchat in room $roomName"
    pack [message $w.frall.msg -width 220 -font $sysFont(s) -text $msg] \
      -side top -fill both -padx 4 -pady 2
    
    set wmid $w.frall.fr
    pack [frame $wmid] -side top -fill x -expand 1 -padx 6
    label $wmid.la -font $sysFont(sb) -text "Invite Jid:"
    entry $wmid.ejid
    label $wmid.lre -font $sysFont(sb) -text "Reason:"
    entry $wmid.ere
    
    grid $wmid.la -column 0 -row 0 -sticky e -padx 2 
    grid $wmid.ejid -column 1 -row 0 -sticky ew -padx 2 
    grid $wmid.lre -column 0 -row 1 -sticky e -padx 2 
    grid $wmid.ere -column 1 -row 1 -sticky ew -padx 2 
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack $frbot  -side bottom -fill x -padx 10 -pady 8
    pack [button $frbot.btok -text [::msgcat::mc OK] -width 8  \
      -default active -command "set [namespace current]::fininvite 1"] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcan -text [::msgcat::mc Cancel] -width 8  \
      -command "set [namespace current]::fininvite 0"]  \
      -side right -padx 5 -pady 5  
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    bind $w <Escape> [list $frbot.btcan invoke]
    
    # Grab and focus.
    set oldFocus [focus]
    focus $wmid.ejid
    catch {grab $w}
    
    # Wait here for a button press.
    tkwait variable [namespace current]::fininvite
    
    set jid [$wmid.ejid get]
    set reason [$wmid.ere get]

    catch {grab release $w}
    destroy $w
    focus $oldFocus
    
    set opts {}
    if {$reason != ""} {
	set opts [list -reason $reason]
    }

    if {$fininvite > 0} {
	if {[catch {
	    eval {$jstate(jlib) muc invite $roomjid $jid} $opts
	} err]} {
	    tk_messageBox -type ok -icon error -title "Network Error" \
	      -message "Network error ocurred: $err"
	}
    }
    return [expr {($fininvite <= 0) ? "cancel" : "ok"}]
}

#--- The Info Dialog -----------------------------------------------------------

# Jabber::MUC::BuildInfo --
# 
#       Displays an info dialog for MUC room configuration.

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
    set roomName [$jstate(browse) getname $roomjid]
    if {$roomName == ""} {
	regexp {([^@]+)@.+} $roomjid match roomName
    }
    wm title $w "Info Room: $roomName"
    wm protocol $w WM_DELETE_WINDOW  \
      [list [namespace current]::Close $roomjid]

    # Instance specific namespace.
    namespace eval [namespace current]::${roomjid} {
	variable locals
    }
    upvar [namespace current]::${roomjid}::locals locals
    set locals($roomjid,w) $w
    set locals($w,roomjid) $roomjid
    set locals($roomjid,mynick) [$jstate(jlib) muc mynick $roomjid]
    set locals($roomjid,myrole) none
    set locals($roomjid,myaff) none
    set pady 2
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btsnd -text [::msgcat::mc Close] -width 8  \
      -command [list [namespace current]::Close $roomjid]] \
      -side right -padx 5 -pady 5
    pack $frbot -side bottom -fill x -padx 10 -pady 8
    
    # A frame.
    set frtop $w.frall.top
    pack [frame $frtop] -side top
    
    # Tablelist with scrollbar ---
    set frtab $frtop.frtab    
    set wysc $frtab.ysc
    set wtbl $frtab.tb
    pack [frame $frtab] -padx 0 -pady 0 -side left
    label $frtab.l -text "Participants:" -font $sysFont(sb)
    set columns [list 0 Nickname 0 Role 0 Affiliation]
    tablelist::tablelist $wtbl  \
      -columns $columns -stretch all \
      -font $sysFont(s) -labelfont $sysFont(s) -background white  \
      -yscrollcommand [list $wysc set]  \
      -labelbackground #cecece -stripebackground #dedeff -width 36 -height 8
    scrollbar $wysc -orient vertical -command [list $wtbl yview]
    button $frtab.ref -text Refresh -font $sysFont(s) -command  \
      [list [namespace current]::Refresh $roomjid]
    grid $frtab.l -sticky w
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
    ::Jabber::MUC::FillTable $roomjid
    
    # A frame.
    set frgrantrevoke $frtop.grrev
    pack [frame $frgrantrevoke] -side right -anchor n
        
    # Grant buttons ---
    set frgrant $frgrantrevoke.grant
    set wgrant [LabeledFrame2 $frgrant "Grant:"]
    pack $frgrant -side left
    foreach txt {Voice Member Moderator Admin Owner} {
	set stxt [string tolower $txt]
	button $wgrant.bt${stxt} -text $txt  \
	  -command [list [namespace current]::GrantRevoke $roomjid grant $stxt]
	grid $wgrant.bt${stxt} -sticky ew -padx 8 -pady $pady 
    }
    
    # Revoke buttons ---
    set frrevoke $frgrantrevoke.rev
    set wrevoke [LabeledFrame2 $frrevoke "Revoke:"]
    pack $frrevoke -side left
    foreach txt {Voice Member Moderator Admin Owner} {
	set stxt [string tolower $txt]
	button $wrevoke.bt${stxt} -text $txt  \
	  -command [list [namespace current]::GrantRevoke $roomjid revoke $stxt]
	grid $wrevoke.bt${stxt} -sticky ew -padx 8 -pady $pady 
    }    
    
    # A frame.
    set frmid $w.frall.mid
    pack [frame $frmid] -side top
    
    # Edit lists ---
    set fredit $frmid.lists
    set wlist [LabeledFrame2 $fredit "Edit Lists:"]
    pack $fredit -side right
    foreach txt {Voice Ban Member Moderator Admin Owner} {
	set stxt [string tolower $txt]	
	button $wlist.bt${stxt} -text "$txt..."  \
	  -command [list [namespace current]::EditList $roomjid $stxt]
	grid $wlist.bt${stxt} -sticky ew -padx 8 -pady $pady
    }
    
    # Other buttons ---
    set wother $frmid.fraff
    pack [frame $wother] -side left
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

    # Collect various widget paths.
    set locals(wtbl) $wtbl
    set locals(wlist) $wlist
    set locals(wgrant) $wgrant
    set locals(wrevoke) $wrevoke
    set locals(wother) $wother
    
    ::Jabber::MUC::SetButtonsState $roomjid  \
      $locals($roomjid,myrole) $locals($roomjid,myaff) 
    
    wm resizable $w 0 0    
    
}

proc ::Jabber::MUC::FillTable {roomjid} {
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
		catch {unset attrArr}
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
	    set locals($roomjid,myaff) $aff
	    set locals($roomjid,myrole) $role
	    $wtbl rowconfigure $irow -bg red
	}
	incr irow
    }
}

proc ::Jabber::MUC::Refresh {roomjid} {

    ::Jabber::MUC::FillTable $roomjid
}

proc ::Jabber::MUC::DoubleClickPart {roomjid} {
    upvar [namespace current]::${roomjid}::locals locals

    
}

proc ::Jabber::MUC::SelectPart {roomjid} {
    upvar ::Jabber::jstate jstate
    upvar [namespace current]::${roomjid}::locals locals

    set wtbl $locals(wtbl)
    set item [$wtbl curselection]
    return 
    if {[string length $item] == 0} {
	::Jabber::MUC::DisableAll $roomjid
    } else {
    	::Jabber::MUC::SetButtonsState $roomjid  \
    	  $locals($roomjid,myrole) $locals($roomjid,myaff) 
    }  
}

proc ::Jabber::MUC::SetButtonsState {roomjid role affiliation} {
    variable enabledBtAffList 
    variable enabledBtRoleList
    upvar [namespace current]::${roomjid}::locals locals
    
    set wtbl $locals(wtbl)
    set wlist $locals(wlist)
    set wgrant $locals(wgrant)
    set wrevoke $locals(wrevoke)
    set wother $locals(wother)
    
    ::Jabber::MUC::DisableAll $roomjid

    foreach wbt $enabledBtRoleList($role) {
	set wbt [subst -nobackslashes -nocommands $wbt]
	$wbt configure -state normal
    }
    foreach wbt $enabledBtAffList($affiliation) {
	set wbt [subst -nobackslashes -nocommands $wbt]
	$wbt configure -state normal
    }
}

proc ::Jabber::MUC::DisableAll {roomjid} {
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

proc ::Jabber::MUC::GrantRevoke {roomjid which type} {
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
    foreach {nick role aff} $row { break }
    regexp {^([^@]+)@.+} $roomjid match roomName
    
    set ans [eval {
      ::UI::MegaDlgMsgAndEntry} [subst $dlgDefs($which,$type)] \
      {"Reason:" reason [::msgcat::mc Cancel] [::msgcat::mc OK]}]
    set opts {}
    if {$reason != ""} {
	set opts [list -reason $reason]
    }

    if {$ans == "ok"} {
	if {[catch {
	    eval {$jstate(jlib) muc $actionDefs($which,$type,cmd) $roomjid  \
	      $nick $actionDefs($which,$type,what)  \
	      -command [list [namespace current]::IQCallback $roomjid]} $opts
	} err]} {
	    tk_messageBox -type ok -icon error -title "Network Error" \
	      -message "Network error ocurred: $err"
	}
    }
}

proc ::Jabber::MUC::Kick {roomjid} {
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate
    
    # Need selected line here. $item = numerical index.
    set wtbl $locals(wtbl)
    set item [$wtbl curselection]
    if {[string length $item] == 0} {
	return
    }
    set row [$wtbl get $item]
    foreach {nick role aff} $row { break }
    regexp {^([^@]+)@.+} $roomjid match roomName
    
    set ans [::UI::MegaDlgMsgAndEntry  \
      {Kick Participant}  \
      "Kick the participant \"$nick\" from the room \"$roomName\""  \
      "Reason:"  \
      reason [::msgcat::mc Cancel] [::msgcat::mc OK]]
    set opts {}
    if {$reason != ""} {
	set opts [list -reason $reason]
    }
    
    if {$ans == "ok"} {
	if {[catch {
	    eval {$jstate(jlib) muc setrole $roomjid $nick "none" \
	      -command [list [namespace current]::IQCallback $roomjid]} $opts
	} err]} {
	    tk_messageBox -type ok -icon error -title "Network Error" \
	      -message "Network error ocurred: $err"
	}
    }
}

proc ::Jabber::MUC::Ban {roomjid} {
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate

    # Need selected line here. $item = numerical index.
    set wtbl $locals(wtbl)
    set item [$wtbl curselection]
    if {[string length $item] == 0} {
	return
    }
    set row [$wtbl get $item]
    foreach {nick role aff} $row { break }
    regexp {^([^@]+)@.+} $roomjid match roomName
    
    set ans [::UI::MegaDlgMsgAndEntry  \
      {Ban User}  \
      "Ban the user \"$nick\" from the room \"$roomName\""  \
      "Reason:"  \
      reason [::msgcat::mc Cancel] [::msgcat::mc OK]]
    set opts {}
    if {$reason != ""} {
	set opts [list -reason $reason]
    }
    
    if {$ans == "ok"} {
	if {[catch {
	    eval {$jstate(jlib) muc setaffiliation $roomjid $nick "outcast" \
	      -command [list [namespace current]::IQCallback $roomjid]} $opts
	} err]} {
	    tk_messageBox -type ok -icon error -title "Network Error" \
	      -message "Network error ocurred: $err"
	}
    }
}

# Jabber::MUC::EditList --
#
#       Shows and handles a dialog for edit various lists of room content.
#       
# Arguments:
#       roomjid
#       type        voice, ban, member, moderator, admin, owner
#       
# Results:
#       "cancel" or "ok".

proc ::Jabber::MUC::EditList {roomjid type} {
    global this sysFont
    
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
    array set columns {
	voice     {0 Nickname 0 Affiliation 0 Jid 0 Reason}
	ban       {0 Jid 0 Reason}
	member    {0 Nickname 0 Role 0 Jid 0 Reason}
	moderator {0 Nickname 0 Jid 0 Reason}
	admin     {0 Jid 0 Reason}
	owner     {0 Jid 0 Reason}
    }
    array set setListDefs {
	voice     {nick affiliation jid reason}
	ban       {jid reason}
	member    {nick role jid reason}
	moderator {nick jid reason}
	admin     {jid reason}
	owner     {jid reason}
    }
    
    set titleType [string totitle $type]
    set tblwidth [expr 10 + 12 * [llength $setListDefs($type)]]
    set editlocals(listvar) {}
    
    set w .dlgmuc[incr dlguid]
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	
    }
    set roomName [$jstate(browse) getname $roomjid]
    if {$roomName == ""} {
	regexp {([^@]+)@.+} $roomjid match roomName
    }
    wm title $w "Edit List $titleType: $roomName"
    wm protocol $w WM_DELETE_WINDOW "set [namespace current]::fineditlist 0"
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] \
      -fill both -expand 1 -ipadx 4
    regexp {^([^@]+)@.*} $roomjid match roomName
    pack [message $w.frall.msg -width 300 -font $sysFont(s)  \
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
      -columns $columns($type) -stretch all  \
      -font $sysFont(s) -labelfont $sysFont(s) -background white  \
      -yscrollcommand [list $wysc set]  \
      -labelbackground #cecece -stripebackground #dedeff \
      -editendcommand [namespace current]::VerifyEditEntry \
      -listvariable [namespace current]::${roomjid}::editlocals(listvar)
    scrollbar $wysc -orient vertical -command [list $wtbl yview]
    grid $wtbl $wysc -sticky news
    grid columnconfigure $frtab 0 -weight 1

    option add $wtbl*Entry.background		LightYellow
    option add $wtbl*selectBackground		navy
    option add $wtbl*selectForeground		white

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
    bind $wtbl <<ListboxSelect>> [list [namespace current]::SelectEditList $roomjid]
    
    # Action buttons.
    set wbts $wmid.fr
    set wbtadd $wbts.add
    set wbtedit $wbts.edit
    set wbtrm $wbts.rm
    pack [frame $wbts] -side right -anchor n -padx 4 -pady 4
    button $wbtadd -text "Add" -font $sysFont(s) -state disabled -command \
      [list [namespace current]::DoEditAddList $roomjid]
    button $wbtedit -text "Edit" -font $sysFont(s) -state disabled -command \
      [list [namespace current]::DoEditList $roomjid]
    button $wbtrm -text "Remove" -font $sysFont(s) -state disabled -command \
      [list [namespace current]::DoEditRemoveList $roomjid]
    
    grid $wbtadd -pady 2 -sticky ew
    grid $wbtedit -pady 2 -sticky ew
    grid $wbtrm -pady 2 -sticky ew
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set wsearrows $frbot.arr
    set wbtok $frbot.btok
    pack $frbot  -side bottom -fill x -padx 10 -pady 8
    pack [button $wbtok -text [::msgcat::mc OK] -width 8 -state disabled \
      -default active -command "set [namespace current]::fineditlist 1"] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcan -text [::msgcat::mc Cancel] -width 8  \
      -command "set [namespace current]::fineditlist 0"]  \
      -side right -padx 5 -pady 5  
    pack [::chasearrows::chasearrows $wsearrows -background gray87 -size 16] \
      -side left -padx 5 -pady 5
    pack [button $frbot.btres -text [::msgcat::mc Reset] -width 8  \
      -command [list [namespace current]::ResetEditList]]  \
      -side left -padx 5 -pady 5  
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    bind $w <Escape> [list $frbot.btcan invoke]
    
    # Grab and focus.
    set oldFocus [focus]
    catch {grab $w}
    
    # How and what to get.
    switch -- $type {
	voice {
	   set getact getrole
	   set what participant
	}
	ban {
	   set getact getaffiliation
	   set what outcast
	}
	member {
	   set getact getaffiliation
	   set what member
	}
	moderator {
	   set getact getrole
	   set what moderator
	}
	admin {
	   set getact getaffiliation
	   set what admin
	}
	owner {    
	   set getact getaffiliation
	   set what owner
	} 
	default {
	    return -code error "Unrecognized type \"$type\""
	}
    }
    
    # Cache local variables.
    set editlocals(wtbl) $wtbl
    set editlocals(wsearrows) $wsearrows
    set editlocals(wbtok) $wbtok  
    set editlocals(type) $type
    set editlocals(wbtadd) $wbtadd
    set editlocals(wbtedit) $wbtedit
    set editlocals(wbtrm) $wbtrm
    
    # Now, go and get it!
    $wsearrows start
    set editlocals(editcallid) [incr editcalluid]
    if {[catch {
	$jstate(jlib) muc $getact $roomjid $what \
	  [list [namespace current]::EditListGetCB $roomjid $locals(editcallid)]
    }]} {
	$wsearrows stop
	tk_messageBox
    }      
    
    # Wait here for a button press.
    tkwait variable [namespace current]::fineditlist
    

    catch {grab release $w}
    destroy $w
    focus $oldFocus

    set opts {}

    if {$fineditlist > 0} {
	if {[catch {eval {
	    $jstate(jlib) muc setrole $roomjid  \
	      -command [list [namespace current]::IQCallback $roomjid]} $opts
	} err]} {
	    tk_messageBox -type ok -icon error -title "Network Error" \
	      -message "Network error ocurred: $err"
	}
    }
    return [expr {($fineditlist <= 0) ? "cancel" : "ok"}]
}

proc ::Jabber::MUC::EditListGetCB {roomjid callid jlibname type subiq} {
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
    if {$callid != $editlocals(editcallid)} {
	return
    }
    if {![winfo exists $wsearrows]} {
	return
    }
    
    $wsearrows stop
    if {$type == "error"} {
	tk_messageBox 
	return
    }
    
    set editlocals(subiq) $subiq

    # Fill tablelist.
    ::Jabber::MUC::FillEditList $roomjid
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
	} 
    }
}

proc ::Jabber::MUC::FillEditList {roomjid} {
    upvar [namespace current]::${roomjid}::editlocals editlocals

    variable setListDefs

    set wtbl $editlocals(wtbl)
    set wsearrows $editlocals(wsearrows)
    set wbtok $editlocals(wbtok)
    set type $editlocals(type)
    
    $editlocals(subiq)
    set childList [wrapper::getchildren $editlocals(subiq)]
    set tmplist {}

    # Fill in tablelist.
    switch -- $type {
	voice {
	    lappend tmplist 
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
    set editlocals(listvar) $tmplist
}

proc ::Jabber::MUC::VerifyEditEntry {wtbl row col text} {


    if {![::Jabber::IsWellFormedJID $text]} {
	bell
	tk_messageBox -icon error -message "Kass" \
	  -parent [winfo toplevel $wtbl] -type ok
	$wtbl rejectinput
	return ""
    }
}

proc ::Jabber::MUC::SelectEditList {roomjid} {
    upvar [namespace current]::${roomjid}::editlocals editlocals
    
    set wtbl $editlocals(wtbl)
    set wsearrows $editlocals(wsearrows)

    
}

proc ::Jabber::MUC::DoEditAddList {roomjid} {
    upvar [namespace current]::${roomjid}::editlocals editlocals

    set wtbl $editlocals(wtbl)

    
}

proc ::Jabber::MUC::DoEditList {roomjid} {
    upvar [namespace current]::${roomjid}::editlocals editlocals

    set wtbl $editlocals(wtbl)

    
}

proc ::Jabber::MUC::DoEditRemoveList {roomjid} {
    upvar [namespace current]::${roomjid}::editlocals editlocals

    set wtbl $editlocals(wtbl)

    
}

proc ::Jabber::MUC::ResetEditList {roomjid} {
    upvar [namespace current]::${roomjid}::editlocals editlocals

    set wtbl $editlocals(wtbl)

    
}

# End edit lists ---

proc ::Jabber::MUC::RoomConfig {roomjid} {
    global  this sysFont
    
    variable wbox
    variable wsearrows
    variable wbtok
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate
    
    set w .qwerty65
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w "Configure Room"
    wm protocol $w WM_DELETE_WINDOW  \
      [list [namespace current]::CancelConfig $roomjid $w]
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 4
            
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set wsearrows $frbot.arr
    set wbtok $frbot.btok
    set wbtcancel $frbot.btcancel
    pack [button $wbtok -text [::msgcat::mc OK] -width 8 -default active \
      -state disabled -command  \
        [list [namespace current]::DoRoomConfig $roomjid $w]]  \
      -side right -padx 5 -pady 5
    pack [button $wbtcancel -text [::msgcat::mc Cancel] -width 8  \
      -command [list [namespace current]::CancelConfig $roomjid $w]]  \
      -side right -padx 5 -pady 5
    pack [::chasearrows::chasearrows $wsearrows -background gray87 -size 16] \
      -side left -padx 5 -pady 5
    pack $frbot -side bottom -fill x -expand 0 -padx 8 -pady 6
    
    # The form part.
    set wbox $w.frall.frmid
    ::Jabber::Forms::BuildScrollForm $wbox -height 200 -width 320
    pack $wbox -side top -fill both -expand 1 -padx 8 -pady 4
    
    # Now, go and get it!
    $wsearrows start
    if {[catch {
	$jstate(jlib) muc getroom $roomjid  \
	  [list [namespace current]::ConfigGetCB $roomjid]
    }]} {
	$wsearrows stop
	tk_messageBox
    }   
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed. BAD?
    tkwait window $w
    
    catch {grab release $w}
    focus $oldFocus
    return
}

proc ::Jabber::MUC::CancelConfig {roomjid w} {
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate

    catch {$jstate(jlib) muc setroom $roomJid cancel}
    destroy $w
}

proc ::Jabber::MUC::ConfigGetCB {roomjid jlibName type subiq} {
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

proc ::Jabber::MUC::DoRoomConfig {roomjid w} {
    variable wbox
    upvar [namespace current]::${roomjid}::locals locals
    upvar ::Jabber::jstate jstate

    set subelements [::Jabber::Forms::GetScrollForm $wbox]
    
    if {[catch {
	$jstate(jlib) muc setroom $roomjid form -form $subelements \
	  -command [list [namespace current]::RoomConfigResult $roomjid]
    }]} {
	tk_messageBox -type ok -icon error -title "Network Error" \
	  -message "Network error ocurred: $err"
	return
    }
    destroy $w
}

proc ::Jabber::MUC::RoomConfigResult {roomjid jlibName type subiq} {

    if {$type == "error"} {
	regexp {^([^@]+)@.*} $roomjid match roomName
	tk_messageBox -type ok -icon error  \
	  -message "We failed trying to configurate room \"$roomName\".\
	  [lindex $subiq 0] [lindex $subiq 1]"
    }
}

# Jabber::MUC::SetNick --
# 
# 

proc ::Jabber::MUC::SetNick {roomjid} {
    variable locals
    upvar ::Jabber::jstate jstate
    
    set topic ""
    set ans [::UI::MegaDlgMsgAndEntry  \
      {Set New Nickname}  \
      "Select a new nick name."  \
      "New Nick:"  \
      nickname [::msgcat::mc Cancel] [::msgcat::mc OK]]
    
    # Perhaps check that characters are valid?

    if {($ans == "ok") && ($nickname != "")} {
	if {[catch {
	    $jstate(jlib) muc setnick $roomjid $nickname \
	      -command [list [namespace current]::PresCallback $roomjid]
	} err]} {
	    tk_messageBox -type ok -icon error -title "Network Error" \
	      -message "Network error ocurred: $err"
	}
    }
    return $ans
}

proc ::Jabber::MUC::Destroy {roomjid} {
    global this sysFont
    
    upvar ::Jabber::jstate jstate
    variable findestroy
    variable dlguid
    
    set w .dlgmuc[incr dlguid]
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	
    }
    set roomName [$jstate(browse) getname $roomjid]
    if {$roomName == ""} {
	regexp {([^@]+)@.+} $roomjid match roomName
    }
    wm title $w "Destroy Room: $roomName"
    set findestroy -1
    wm protocol $w WM_DELETE_WINDOW "set [namespace current]::findestroy 0"
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] \
      -fill both -expand 1 -ipadx 4
    regexp {^([^@]+)@.*} $roomjid match roomName
    set msg "You are about to destroy the room \"$roomName\".\
      Optionally you may give any present room particpants an\
      alternative room jid and a reason."
    pack [message $w.frall.msg -width 220 -font $sysFont(s) -text $msg] \
      -side top -fill both -padx 4 -pady 2
    
    set wmid $w.frall.fr
    pack [frame $wmid] -side top -fill x -expand 1 -padx 6
    label $wmid.la -font $sysFont(sb) -text "Alternative Room Jid:"
    entry $wmid.ejid
    label $wmid.lre -font $sysFont(sb) -text "Reason:"
    entry $wmid.ere
    
    grid $wmid.la -column 0 -row 0 -sticky e -padx 2 
    grid $wmid.ejid -column 1 -row 0 -sticky ew -padx 2 
    grid $wmid.lre -column 0 -row 1 -sticky e -padx 2 
    grid $wmid.ere -column 1 -row 1 -sticky ew -padx 2 
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack $frbot  -side bottom -fill x -padx 10 -pady 8
    pack [button $frbot.btok -text [::msgcat::mc OK] -width 8  \
      -default active -command "set [namespace current]::findestroy 1"] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcan -text [::msgcat::mc Cancel] -width 8  \
      -command "set [namespace current]::findestroy 0"]  \
      -side right -padx 5 -pady 5  
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    bind $w <Escape> [list $frbot.btcan invoke]
    
    # Grab and focus.
    set oldFocus [focus]
    focus $wmid.ejid
    catch {grab $w}
    
    # Wait here for a button press.
    tkwait variable [namespace current]::findestroy
    
    set jid [$wmid.ejid get]
    set reason [$wmid.ere get]

    catch {grab release $w}
    destroy $w
    focus $oldFocus

    set opts {}
    if {$reason != ""} {
	set opts [list -reason $reason]
    }
    if {$jid != ""} {
	set opts [list -alternativejid $jid]
    }

    if {$findestroy > 0} {
	if {[catch {eval {
	    $jstate(jlib) muc destroy $roomjid  \
	      -command [list [namespace current]::IQCallback $roomjid]} $opts
	} err]} {
	    tk_messageBox -type ok -icon error -title "Network Error" \
	      -message "Network error ocurred: $err"
	}
    }
    return [expr {($findestroy <= 0) ? "cancel" : "ok"}]
}

proc ::Jabber::MUC::IQCallback {roomjid jlibname type subiq} {
    
    puts "::Jabber::MUC::IQCallback roomjid=$roomjid, type=$type,subiq=$subiq"
    if {$type == "error"} {
    	regexp {^([^@]+)@.*} $roomjid match roomName
    	set msg "We received an error when interaction with the room\
    	\"$roomName\": "
	tk_messageBox -type ok -icon error -title "Error" -message $msg
    }
}


proc ::Jabber::MUC::PresCallback {roomjid jlibname type args} {
    
    puts "::Jabber::MUC::PresCallback roomjid=$roomjid, type=$type, args=$args"
    if {$type == "error"} {
    	set errcode ???
    	set errmsg ""
    	if {[info exists argsArr(-error)]} {
	    foreach {errcode errmsg} $argsArr(-error) { break }
	}	
    	regexp {^([^@]+)@.*} $roomjid match roomName
    	set msg "We received an error when interaction with the room\
    	\"$roomName\": $errmsg"
	tk_messageBox -type ok -icon error -title "Error" -message $msg
    }
}
proc ::Jabber::MUC::Close {roomjid} {
    upvar [namespace current]::${roomjid}::locals locals

    catch {destroy $locals($roomjid,w)}
    namespace delete [namespace current]::${roomjid}
}

#-------------------------------------------------------------------------------
