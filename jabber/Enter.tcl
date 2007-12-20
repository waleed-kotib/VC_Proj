#  Enter.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements groupchat enter UI independent of protocol used.
#      
#  Copyright (c) 2005-2007  Mats Bengtsson
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
# $Id: Enter.tcl,v 1.19 2007-12-20 14:01:25 matben Exp $

package provide Enter 1.0

namespace eval ::Enter:: {

    variable uid  0
}

# Enter::Build --
#
#       Initiates the process of entering a groupchat room in a protocol
#       independent way.
#       
# Arguments:
#       protocol    (gc-1.0 | muc) Protocol to use. If muc and it fails
#                   we use gc-1.0 as a fallback.
#       args        -server, -roomjid, -nickname, -password, -autobrowse,
#                   -command
#       
# Results:
#       "cancel" or "enter".

proc ::Enter::Build {protocol args} {
    global  this wDlgs

    variable uid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::xmppxmlns xmppxmlns
    upvar ::Jabber::jprefs jprefs

    array set argsA {
	-autobrowse     0
    }
    array set argsA $args

    set service ""
    if {[info exists argsA(-roomjid)]} {
	set roomjid $argsA(-roomjid)
	jlib::splitjidex $roomjid node service -
    } elseif {[info exists argsA(-server)]} {
	set service $argsA(-server)
    }
    set services [$jstate(jlib) disco getconferences]

    ::Debug 2 "::Enter::Build services='$services'"

    # State variable to collect instance specific variables.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
    
    set w $wDlgs(jmucenter)$uid
    ::UI::Toplevel $w \
      -macstyle documentProc -macclass {document closeBox} -usemacmainmenu 1 \
      -closecommand [list [namespace current]::CloseCmd $token]
    wm title $w [mc "Enter Chatroom"]

    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jmucenter)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jmucenter)
    }

    set state(w) $w
    set state(args) $args
    array set state {
	finished    -1
	statuscount 0
	server      ""
	roomname    ""
	nickname    ""
	password    ""
    }
    set state(protocol) $protocol
    if {$jprefs(defnick) eq ""} {
	set nickname [::Profiles::GetSelected -nickname]
	if {$nickname ne ""} {
	    set state(nickname) $nickname
	} else {
	    jlib::splitjidex [Jabber::Jlib myjid] node - -
	    set state(nickname) [jlib::unescapestr $node]
	}
    } else {
	set state(nickname) $jprefs(defnick)
    }
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 260 -justify left -text [mc jamucentermsg2]
    pack $wbox.msg -side top -anchor w

    set frmid $wbox.frmid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1

    set wserver $frmid.eserv
    set wbrowse $frmid.browse
    set wbmark  $frmid.bmark
    
    ttk::label $frmid.lserv -text "[mc Service]:" 
    ttk::::combobox $wserver -width 16 -textvariable $token\(server) \
      -values $services
    ttk::button $wbrowse -text [mc Discover] \
      -command [list [namespace current]::Browse $token]
    ttk::button $wbmark -style Popupbutton  \
      -command [list [namespace current]::BmarkPopup $token]
    
    # Find the default conferencing server.
    if {[info exists argsA(-server)]} {
	set state(server) $argsA(-server)
    } elseif {[llength $services]} {
	set state(server) [lindex $services 0]
    }
    set state(state-server)   normal
    set state(state-room)     normal
    set state(state-nickname) normal
    set state(state-password) normal
    set state(-autobrowse)    $argsA(-autobrowse)

    # Second menubutton: rooms for above server. Fill in below.
    # Combobox since we sometimes want to enter room manually.
    set wroom     $frmid.eroom
    set warrows   $frmid.st.arr
    set wstatus   $frmid.st.stat
    
    ttk::label $frmid.lroom -text "[mc Chatroom]:"
    ttk::::combobox $wroom -textvariable $token\(roomname)
    ttk::label $frmid.lnick -text "[mc Nickname]:"
    ttk::entry $frmid.enick -textvariable $token\(nickname)
    ttk::label $frmid.lpass -text "[mc Password]:"
    ttk::entry $frmid.epass -textvariable $token\(password)  \
      -show {*} -validate key -validatecommand {::Jabber::ValidatePasswordStr %S}
   
    # Busy arrows and status message.
    ttk::frame $frmid.st
    ::chasearrows::chasearrows $warrows -size 16
    ttk::label $wstatus -textvariable $token\(status)
    pack $warrows -side left -padx 5 -pady 0
    pack $wstatus -side left -padx 5
    
    grid  $frmid.lserv    $wserver       $wbrowse  $wbmark  -sticky e -pady 2
    grid  $frmid.lroom    $wroom         -  -sticky e -pady 2
    grid  $frmid.lnick    $frmid.enick   -  -sticky e -pady 2
    grid  $frmid.lpass    $frmid.epass   -  -sticky e -pady 2
    grid  $frmid.st       -              -  -sticky w -pady 2
    grid  $wserver   $wroom    $frmid.enick  $frmid.epass  -sticky ew
    grid  $wbrowse  -padx 10
    grid columnconfigure $frmid 1 -weight 1

    ::balloonhelp::balloonforwindow $wserver [mc tooltip-chatroomservice]
    ::balloonhelp::balloonforwindow $wbmark [mc Bookmarks]
    ::balloonhelp::balloonforwindow $wroom [mc tooltip-chatroomselect]
    ::balloonhelp::balloonforwindow $frmid.enick [mc registration-nick]
    ::balloonhelp::balloonforwindow $frmid.epass [mc registration-password]

    if {[info exists argsA(-roomjid)]} {
	jlib::splitjidex $argsA(-roomjid) r state(server) -
	set state(roomname) [jlib::unescapestr $r]
	set state(state-server) disabled
	set state(state-room)   disabled
    }
    if {[info exists argsA(-server)]} {
	set state(server) $argsA(-server)
	set state(state-server) disabled
    }
    if {[info exists argsA(-command)]} {
	set state(-command) $argsA(-command)
    }
    if {[info exists argsA(-nickname)]} {
	set state(nickname) $argsA(-nickname)
	set state(state-nickname) disabled
	$frmid.enick state {disabled}
    }
    if {[info exists argsA(-password)]} {
	set state(password) $argsA(-password)
	set state(state-password) disabled
	$frmid.epass state {disabled}
    }
       
    # Button part.
    set frbot $wbox.b
    set wenter  $frbot.btok
    ttk::frame $frbot
    ttk::button $wenter -text [mc Enter] \
      -default active -command [list [namespace current]::PrepPrepDoEnter $token]
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

    set state(status)  ""
    set state(wserver) $wserver
    set state(wroom)   $wroom
    set state(warrows) $warrows
    set state(wenter)  $wenter
    set state(wbrowse) $wbrowse
    set state(wbmark)  $wbmark
    set state(wnick)   $frmid.enick
    set state(wpass)   $frmid.epass
    
    SetState $token normal
    
    if {$state(-autobrowse) && ($state(state-room) eq "normal")} {

	# Get a freash list each time.
	BusyEnterDlgIncr $token
	update idletasks
	$jstate(jlib) disco send_get items $state(server)  \
	  [list [namespace current]::GetRoomsCB $token]
    }

    wm resizable $w 0 0

    bind $w <Return> [list $wenter invoke]
    bind $wserver <<ComboboxSelected>>  \
      [list [namespace current]::ConfigRoomList $token]

    ::balloonhelp::balloonforwindow $wbmark [mc Bookmarks]

    set oldFocus [focus]
    if {[info exists argsA(-roomjid)]} {
    	focus $frmid.enick
    } elseif {[info exists argsA(-server)]} {
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

    set finished $state(finished)
    ::UI::SaveWinGeom $wDlgs(jmucenter) $w
    catch {destroy $state(w)}
    
    # Unless cancelled we keep 'state' until got callback.
    if {$finished <= 0} {
	Free $token
    }
    return [expr {($finished <= 0) ? "cancel" : "enter"}]
}

proc ::Enter::SetState {token _state} {
    variable $token
    upvar 0 $token state
    
    if {($_state eq "disabled") || ($state(state-server) eq "disabled")} {
	$state(wserver) state {disabled}
	$state(wbmark)  state {disabled}
    } else {
	$state(wserver) state {!disabled}
	$state(wbmark)  state {!disabled}
    }
    if {($_state eq "disabled") || ($state(state-room) eq "disabled")} {
	$state(wbrowse) state {disabled}
	$state(wroom)   state {disabled}
    } else {
	$state(wbrowse) state {!disabled}
	$state(wroom)   state {!disabled}
    }    
    if {($_state eq "disabled") || ($state(state-nickname) eq "disabled")} {
	$state(wnick) state {disabled}
    } else {
	$state(wnick) state {!disabled}
    }
    if {($_state eq "disabled") || ($state(state-password) eq "disabled")} {
	$state(wpass) state {disabled}
    } else {
	$state(wpass) state {!disabled}
    }
    
    if {$_state eq "disabled"} {
	$state(wenter)  state {disabled}
    } else {	
	$state(wenter)  state {!disabled}
    } 
}

proc ::Enter::CancelEnter {token} {
    variable $token
    upvar 0 $token state

    set state(finished) 0
}

proc ::Enter::CloseCmd {token wclose} {
    global  wDlgs
    variable $token
    upvar 0 $token state

    ::UI::SaveWinGeom $wDlgs(jmucenter) $wclose
    set state(finished) 0
}

proc ::Enter::BmarkPopup {token} {
    variable $token
    upvar 0 $token state
    
    set w $state(wbmark)
    set m $w.menu
    if {![winfo exists $m]} {
	::GroupChat::BookmarkBuildMenu $m  \
	  [list [namespace current]::BmarkCmd $token]
    }
    set x [winfo rootx $w]
    set y [expr {[winfo rooty $w] + [winfo height $w]}]
    tk_popup $m $x $y
}

proc ::Enter::BmarkCmd {token name jid opts} {
    variable $token
    upvar 0 $token state
    
    array set optsArr $opts
    jlib::splitjidex $jid node domain -
    set state(server)   $domain
    set state(roomname) [jlib::unescapestr $node]
    if {[info exists optsArr(-nick)]} {
	set state(nickname) $optsArr(-nick)
    }
    if {[info exists optsArr(-password)]} {
	set state(password) $optsArr(-password)
    }
}

proc ::Enter::Browse {token} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
       
    BusyEnterDlgIncr $token
    $jstate(jlib) disco send_get items $state(server)  \
      [list [namespace current]::GetRoomsCB $token]
}

proc ::Enter::GetRoomsCB {token browsename type jid subiq args} {
    
    ::Debug 4 "::Enter::GetRoomsCB type=$type, jid=$jid"
    
    # Make sure the dialog still exists.
    if {![DialogExists $token]} {
	return
    }
    variable $token
    upvar 0 $token state

    BusyEnterDlgIncr $token -1
    
    switch -- $type {
	error {
	    ::ui::dialog -type ok -icon error -title [mc Error]  \
	      -message [mc jamessnorooms2 $state(server)]  \
	      -detail [lindex $subiq 1]
	}
	result - ok {
	    FillRoomList $token
	}
    }
}

# Enter::ConfigRoomList --
# 
#       When a conference server is picked in the server combobox, the 
#       room combobox must get the available rooms for this particular server.

proc ::Enter::ConfigRoomList {token} {    
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    ::Debug 4 "::Enter::ConfigRoomList"

    # Fill in room list if exist else get.    
    # @@@ Replace with 'disco get_async'
    if {[$jstate(jlib) disco isdiscoed items $state(server)]} {
	FillRoomList $token
    } else {
	if {$state(-autobrowse)} {
	    Browse $token
	} else {
	    $state(wroom) configure -values {}
	    set state(roomname) ""
	}
    }
}

proc ::Enter::FillRoomList {token} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    ::Debug 4 "::Enter::FillRoomList"
    
    set roomL [list]
    if {[string length $state(server)]} {
	set allRooms [$jstate(jlib) disco children $state(server)]
	foreach roomjid $allRooms {
	    jlib::splitjidex $roomjid node - -
	    lappend roomL [jlib::unescapestr $node]
	}
    }
    if {![llength $roomL]} {
	::ui::dialog -type ok -icon error  -title [mc Error] \
	  -message [mc jamessnorooms2 $state(server)]
	return
    }
    
    set roomL [lsort $roomL]
    $state(wroom) configure -values $roomL
    set state(roomname) [lindex $roomL 0]
}

proc ::Enter::BusyEnterDlgIncr {token {num 1}} {
    variable $token
    upvar 0 $token state
    
    incr state(statuscount) $num
    
    if {$state(statuscount) > 0} {
	set state(status) "[mc {Loading available chatrooms}]..."
	$state(warrows) start
	SetState $token disabled
    } else {
	set state(statuscount) 0
	set state(status) ""
	$state(warrows) stop
	SetState $token normal
    }
}

# Enter::PrepPrepDoEnter --
# 
#       Just checks that we have got nick & room name, and then calls PrepDoEnter.

proc ::Enter::PrepPrepDoEnter {token} {
    variable $token
    upvar 0 $token state
    
    ::Debug 4 "::Enter::PrepPrepDoEnter"

    if {($state(roomname) eq "") || ($state(nickname) eq "")} {
	::UI::MessageBox -type ok -icon error -title [mc Error] \
	  -message [mc jamessgchatfields2]
    } else {
	PrepDoEnter $token
    }
}

# Enter::PrepDoEnter --
# 
#       Prepare entering a room. We may need to check if disco is supported
#       before trying entering via "muc".

proc ::Enter::PrepDoEnter {token} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::xmppxmlns xmppxmlns
    
    ::Debug 4 ""

    set node [jlib::escapestr $state(roomname)]
    set roomjid [jlib::jidmap $node@$state(server)]
    set service $state(server)
    set state(roomjid) $roomjid
    
    if {$state(protocol) eq "muc"} {
	set hasmuc [$jstate(jlib) disco hasfeature $xmppxmlns(muc) $service]
	if {$hasmuc} {
	    DoEnter $token
	} else {
	    set callback [list [namespace current]::DiscoCallback $token]
	    $jstate(jlib) disco send_get info $service $callback
	}
    } else {
	DoEnter $token
    }
    
    # This closes the dialog.
    set state(finished) 1
}

proc ::Enter::DiscoCallback {token jlibname type from subiq args} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::xmppxmlns xmppxmlns

    ::Debug 4 "::Enter::DiscoCallback"

    set service $state(server)

    switch -- $type {
	error {
	    
	    # gc-1.0 as fallback.
	    set state(protocol) "gc-1.0"
	    DoEnter $token
	}
	default {
	    set hasmuc [$jstate(jlib) disco hasfeature $xmppxmlns(muc) $service]
	    if {!$hasmuc} {
		set state(protocol) "gc-1.0"
	    }	    
	    DoEnter $token
	}
    }
}

proc ::Enter::DoEnter {token} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::xmppxmlns xmppxmlns
    
    ::Debug 4 "::Enter::DoEnter"
 
    set roomjid $state(roomjid)
    set opts [list]
    if {$state(password) ne ""} {
	lappend opts -password $state(password)
    }
    #set nickname [jlib::escapestr $state(nickname)]
    set nickname $state(nickname)
    
    # We must figure out which protocol to use, muc or gc-1.0?
    switch -- $state(protocol) {
	"muc" {
	    set callback [list [namespace current]::MUCCallback $token]
	    eval {$jstate(jlib) muc enter $roomjid $nickname \
		  -command $callback} $opts
	}
	"gc-1.0" {
	    set callback [list [namespace current]::GCCallback $token]
	    $jstate(jlib) groupchat enter $roomjid $nickname \
	      -command $callback
	}
    }

    if {$state(protocol) eq "muc"} {
	set xE [list [wrapper::createtag "x" -attrlist [list xmlns $xmppxmlns(muc)]]]
    } else {
	set xE [list]
    }

    set from $roomjid/$nickname
    set attr [list from $from to $roomjid]
    set xmldata [wrapper::createtag "presence" -attrlist $attr -subtags $xE]
    ::History::XPutItem send $roomjid $xmldata
}

# Enter::MUCCallback --
#
#       Presence callabck from the 'muc enter' command.
#       Just to catch errors and check if any additional info (password)
#       is needed for entering room.
#
# Arguments:
#       token
#       jlibname 
#       
# Results:
#       None.

proc ::Enter::MUCCallback {token jlibname xmldata} {
    variable $token
    upvar 0 $token state
    
    set from [wrapper::getattribute $xmldata from]
    set type [wrapper::getattribute $xmldata type]
    if {$type eq ""} {
	set type "available"
    }    
    set roomjid [jlib::jidmap [jlib::barejid $from]]
    set retry 0

    ::History::XPutItem recv $roomjid $xmldata

    if {[string equal $type "error"]} {
	set errspec [jlib::getstanzaerrorspec $xmldata]
	if {[llength $errspec]} {
	    set errcode [lindex $errspec 0]
	    set errmsg  [lindex $errspec 1]
	    
	    switch -- $errcode {
		401 - not-authorized {
		    
		    # Password required.
		    set ans [::UI::MessageBox -type yesno -icon error \
		      -title [mc Error]  \
		      -message [mc jamessenterroomretry2 $roomjid $errmsg]]
		    if {$ans eq "yes"} {
			set retry 1
			Build "muc" -roomjid $state(roomjid)  \
			  -nickname $state(nickname)
		    }
		}
		default {
		    set str [mc jamesserrconfgetcre2]
		    append str "\n" "[mc {Error code}]: $errcode\n"
		    append str "[mc Message]: $errmsg"
		    ::UI::MessageBox -type ok -icon error -title [mc Error]  \
		      -message $str
		}
	    }
	}
    } else {
	
	# Cache groupchat protocol type (muc|conference|gc-1.0) etc.
	::Debug 2 "--> groupchatEnterRoomHook $roomjid"
	
	::hooks::run groupchatEnterRoomHook $roomjid "muc"
    }
    if {!$retry && [info exists state(-command)]} {
	uplevel #0 $state(-command) [list $xmldata]
    }
    Free $token
}

proc ::Enter::GCCallback {token jlibname xmldata} {
    variable $token
    upvar 0 $token state
    
    set from [wrapper::getattribute $xmldata from]
    set type [wrapper::getattribute $xmldata type]
    if {$type eq ""} {
	set type "available"
    }    
    set roomjid [jlib::jidmap [jlib::barejid $from]]

    ::History::XPutItem recv $roomjid $xmldata

    if {[string equal $type "error"]} {
	set ujid [jlib::unescapejid $from]
	set msg [mc mucErrEnter2 $from]
	set errspec [jlib::getstanzaerrorspec $xmldata]
	if {[llength $errspec]} {
	    set errcode [lindex $errspec 0]
	    set errmsg  [lindex $errspec 1]
	    append msg "\n[mc {Error code}]: $errcode"
	    append msg "\n[mc Message]: $errmsg"
	}
	::UI::MessageBox -title [mc Error] -message $msg -icon error
    } else {
    
	# Cache groupchat protocol type (muc|conference|gc-1.0).
	::hooks::run groupchatEnterRoomHook $roomjid "gc-1.0"
    }
    if {[info exists state(-command)]} {
	uplevel #0 $state(-command) [list $xmldata]
    }
    Free $token
}

# Enter::EnterRoom --
# 
#       Programmatic way to enter a room.
#       
# Arguments:
#       roomjid
#       nick
#       args:
#           -protocol    (gc-1.0 | muc) Protocol to use. If muc and it fails
#                        we use gc-1.0 as a fallback.
#           -command     tclProc
#           -password
#       
# Results:
#       "cancel" or "enter".

proc ::Enter::EnterRoom {roomjid nick args} {
    variable uid
    
    # State variable to collect instance specific variables.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state

    set state(roomjid)  $roomjid
    set state(nickname) $nick
    set state(password) ""
    set state(protocol) "muc"
    set state(args)     $args
    jlib::splitjidex $roomjid state(roomname) state(server) -

    foreach {key value} $args {
	
	switch -- $key {
	    -password {
		set state(password) $value
	    }
	    default {
		set state($key) $value
	    }
	}
    }
    PrepDoEnter $token
}

proc ::Enter::DialogExists {token} {    
    if {[array exists $token]} {
	variable $token
	upvar 0 $token state
	return [winfo exists $state(w)]
    } else {
	return 0
    }
}

proc ::Enter::Free {token} {
    variable $token
    upvar 0 $token state
    
    unset -nocomplain state
}

#-------------------------------------------------------------------------------
