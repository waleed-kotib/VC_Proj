#  Create.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements a create dialog for groupchat using the 'muc' protocol.
#      
#  Copyright (c) 2006-2007  Mats Bengtsson
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
# $Id: Create.tcl,v 1.19 2008-03-30 13:18:19 matben Exp $

package provide Create 1.0

namespace eval ::Create:: {

    variable uid 0
}

# Create::BuildCreate --
#
#       Initiates the process of creating a room.
#       
# Arguments:
#       args    -server, -roomname, -nickname
#       
# Results:
#       "cancel" or "create".
     
proc ::Create::Build {args} {
    global  this wDlgs
    
    variable uid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Create::Build args='$args'"
    array set argsA $args
    
    # State variable to collect instance specific variables.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
    
    set w $wDlgs(jcreateroom)$uid    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document {closeBox resizable}} \
      -closecommand [list [namespace current]::Close $token]
    wm title $w [mc {Create Chatroom}]

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
    if {[info exists argsA(-roomname)]} {
	set state(roomname) [jlib::unescapestr $argsA(-roomname)]
    }
    if {[info exists argsA(-nickname)]} {
	set state(nickname) $argsA(-nickname)
    }
    set state(w)              $w
    set state(wraplength)     330
        
    set confServers [$jstate(jlib) disco getconferences]
    if {$confServers eq {}} {
	set serviceList [list [mc "not available"]]
    } else {
	set serviceList $confServers
    }
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength $state(wraplength) -justify left \
      -text [mc jacreateroom2]
    pack $wbox.msg -side top -anchor w
    
    set frtop        $wbox.top
    set wpopupserver $frtop.eserv

    ttk::frame $frtop
    pack $frtop -side top -fill x
        
    ttk::label $frtop.lserv -text "[mc Service]:"
    ui::combobutton $frtop.eserv -variable $token\(server) \
      -menulist [ui::optionmenu::menuList $serviceList]
    ttk::label $frtop.lroom -text "[mc Chatroom]:"    
    ttk::entry $frtop.eroom -textvariable $token\(roomname)  \
      -validate key -validatecommand {::Jabber::ValidateUsernameStrEsc %S}
    ttk::label $frtop.lnick -text "[mc Nickname]:"    
    ttk::entry $frtop.enick -textvariable $token\(nickname)  \
      -validate key -validatecommand {::Jabber::ValidateResourceStr %S}
    
    grid  $frtop.lserv  $frtop.eserv  -sticky e -pady 2
    grid  $frtop.lroom  $frtop.eroom  -sticky e -pady 2
    grid  $frtop.lnick  $frtop.enick  -sticky e -pady 2
    
    grid  $frtop.eserv  $frtop.eroom  $frtop.enick  -sticky ew
    grid columnconfigure $frtop 1 -weight 1

    ::balloonhelp::balloonforwindow $frtop.eserv [mc tooltip-chatroomservice]
    ::balloonhelp::balloonforwindow $frtop.eroom [mc tooltip-chatroomselect]
    ::balloonhelp::balloonforwindow $frtop.enick [mc registration-nick]

    # Find the default conferencing server.
    if {[info exists argsA(-server)]} {
	
	# Bes ure to get domain part only!
	jlib::splitjidex $argsA(-server) - domain -
	set state(server) $domain
	$frtop.eserv state {disabled}
    } else {
	set state(server) [lindex $serviceList 0]
    }
    if {![llength $confServers]} {
	$frtop.eserv state {disabled}
	$frtop.eroom state {disabled}
	$frtop.enick state {disabled}
    }
            
    # Button part.
    set frbot     $wbox.b
    set wbtcreate $frbot.btok
    set wbtget    $frbot.btget
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $wbtget -text [mc Configure] -default active \
      -command [list [namespace current]::Get $token]
    ttk::button $wbtcreate -text [mc Create] \
      -command [list [namespace current]::SetRoom $token]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::Cancel $token]
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

    if {![llength $confServers]} {
	$wbtget    state {disabled}
	$wbtcreate state {disabled}
    }

    # MUC rooms can be created directly (instant) without getting the form.
    # But in this case we must have nonempty room name and nickname.
    if {($state(roomname) eq "") || ($state(nickname) eq "")} {
	$wbtcreate state {disabled}
    }
    if {$state(roomname) eq ""} {
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
    ::UI::ChaseArrows $wsearrows
    ttk::label $wstatus -style Small.TLabel -textvariable $token\(status)
    pack  $wbox.st  -side bottom -fill x
    pack  $wsearrows  $wstatus  -side left

    set state(wsearrows)      $wsearrows
    set state(wpopupserver)   $wpopupserver
    set state(wbtget)         $wbtget
    set state(wbtcreate)      $wbtcreate
    set state(wfrform)        $wfrform
    
    bind $w <Return> [list $wbtget invoke]
    
    if {[llength $confServers]} {
	trace add variable $token\(server) write \
	  [namespace code [list TraceCreateState $token]]
	SetState $token
    }
    trace add variable $token\(roomname) write \
      [namespace code [list TraceCreateState $token]]
    trace add variable $token\(nickname) write \
      [namespace code [list TraceCreateState $token]]

    trace add variable $token\(roomname) write \
      [namespace code [list TraceGetState $token]]
    trace add variable $token\(nickname) write \
      [namespace code [list TraceGetState $token]]
    
    # Grab and focus.
    set oldFocus [focus]
    if {[$frtop.eroom instate !disabled]} {
	bind $frtop.eroom <Map> { focus %W }
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

# MUC rooms can be created directly (instant) without getting the form.
# But in this case we must have nonempty room name and nickname.

proc ::Create::TraceCreateState {token name junk1 junk2} {        
    SetState $token
}

proc ::Create::SetState {token} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::xmppxmlns xmppxmlns
     
    # @@@ This SHALL be checked earlier!!!
    set muc [$jstate(jlib) disco hasfeature $xmppxmlns(muc) $state(server)]
    set state(usemuc) $muc
    if {$muc} {
	if {($state(roomname) eq "") || ($state(nickname) eq "")} {
	    $state(wbtcreate) state {disabled}
	} else {
	    $state(wbtcreate) state {!disabled}	
	}
    } else {
	$state(wbtcreate) state {disabled}
    }    
}

proc ::Create::TraceGetState {token name junk1 junk2} {        
    variable $token
    upvar 0 $token state

    if {($state(roomname) eq "") || ($state(nickname) eq "")} {
	$state(wbtget) state {disabled}
    } else {
	$state(wbtget) state {!disabled}
    }
}

proc ::Create::Close {token w} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    
    ::UI::SaveWinGeom $wDlgs(jcreateroom) $state(w)
    return
}

proc ::Create::Cancel {token} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    # No jidmap since may not be valid.
    # Is this according to MUC?
    set node [jlib::escapestr $state(roomname)]
    set roomjid [jlib::jidmap $node@$state(server)]
    if {$roomjid ne ""} {
	catch {$jstate(jlib) muc setroom $roomjid cancel}
    }
    ::UI::SaveWinGeom $wDlgs(jcreateroom) $state(w)
    set state(finished) 0
    catch {destroy $state(w)}
}

# Create::Get --
# 
#       Requests the form to create room. The Get button.

proc ::Create::Get {token} {    
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::xmppxmlns xmppxmlns

    set state(usemuc)  \
      [$jstate(jlib) disco hasfeature $xmppxmlns(muc) $state(server)]
    
    # Verify:
    if {$state(server) eq ""} {
	::UI::MessageBox -type ok -icon error -parent $state(w) \
	  -title [mc Error] -message [mc jamessnogroupchat2]
	return
    }
    if {$state(roomname) eq ""} {
	::UI::MessageBox -type ok -icon error -parent $state(w) \
	  -title [mc Error] -message [mc jamessgcnoroomname2]
	return
    }
    if {($state(usemuc) && ($state(nickname) eq ""))} {
	::UI::MessageBox -type ok -icon error -parent $state(w) \
	  -title [mc Error] -message [mc jamessgcnoroomnick]
	return
    }

    set node [jlib::escapestr $state(roomname)]
    set roomjid [jlib::joinjid $node $state(server) ""]
    if {![jlib::jidvalidate $roomjid]} {
	::UI::MessageBox -type ok -icon error -parent $state(w) \
	  -title [mc Error] -message [mc jamessjidinvalid2]
	return
    }
    $state(wpopupserver) state {disabled}
    $state(wbtget)       state {disabled}
    set state(status) "[mc jawaitform]..."
    
    # Send get create room. NOT the server!
    set state(roomjid) [jlib::jidmap $roomjid]

    $state(wsearrows) start
    SendGet $token
}

proc ::Create::SendGet {token} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::xmppxmlns xmppxmlns
    
    ::Debug 2 "::Create::SendGet usemuc=$state(usemuc)"

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

	# Design a simplified xmldata for the history.
	set from $roomjid/$state(nickname)
	set xE [wrapper::createtag "x" -attrlist [list xmlns $xmppxmlns(muc)]]
	set attr [list from $from to $roomjid]
	set xmldata [wrapper::createtag "presence"  \
	  -attrlist $attr -subtags [list $xE]]
	::History::XPutItem send $roomjid $xmldata
    } else {
	
	# Error
    }
}

# Create::CreateMUCCB --
#
#       Presence callabck from the 'muc create' command.
#
# Arguments:
#       token
#       jlibname 
#       
# Results:
#       None.

proc ::Create::CreateMUCCB {token jlibname xmldata} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Create::CreateMUCCB"
    
    if {![info exists state(w)]} {
	return
    }
    $state(wsearrows) stop

    set from [wrapper::getattribute $xmldata from]
    set type [wrapper::getattribute $xmldata type]
    if {$type eq ""} {
	set type "available"
    }    
    set roomjid [jlib::jidmap $from]

    ::History::XPutItem recv $roomjid $xmldata

    if {[string equal $type "error"]} {
    	set errcode ""
    	set errmsg ""
	set errspec [jlib::getstanzaerrorspec $xmldata]
	if {[llength $errspec]} {
	    set errcode [lindex $errspec 0]
	    set errmsg  [lindex $errspec 1]
	}
	set str [mc jamesserrconfgetcre2]
	append str "\n" "[mc {Error code}]: $errcode\n"
	append str "[mc Message]: $errmsg"
	::UI::MessageBox -type ok -icon error -title [mc Error] \
	  -message $str

      set state(status) [mc jasearchwait]
	$state(wpopupserver) configure -state normal
	$state(wbtget) configure -state normal
	return
    }
    
    # We should check that we've got an 
    # <created xmlns='http://jabber.org/protocol/muc#owner'/> element.
    if {![info exists argsA(-created)]} {
    
    }
    $jstate(jlib) muc getroom $state(roomjid)  \
      [list [namespace current]::GetFormCB $token]
}

# Create::GetFormCB --
#
#

proc ::Create::GetFormCB {token jlibName type subiq} {    
    variable $token
    upvar 0 $token state
    
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Create::GetFormCB type=$type"
    
    if {![info exists state(w)]} {
	return
    }
    $state(wsearrows) stop
    set state(status) ""
    
    if {$type eq "error"} {
	set str [mc jamesserrconfgetcre2]
	append str "\n" "[mc {Error code}]: [lindex $subiq 0]\n"
	append str "[mc Message]: [lindex $subiq 1]"
	::UI::MessageBox -type ok -icon error -title [mc Error] -parent $state(w) \
	  -message $str

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

proc ::Create::SetRoom {token} {
    global  wDlgs
    variable $token
    upvar 0 $token state

    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Create::SetRoom"

    $state(wsearrows) stop
    
    set node [jlib::escapestr $state(roomname)]
    set roomjid [jlib::joinjid $node $state(server) ""]
    if {![jlib::jidvalidate $roomjid]} {
	::UI::MessageBox -type ok -icon error -parent $state(w) \
	  -title [mc Error] -message [mc jamessjidinvalid2]
	return
    }
    set state(roomjid) [jlib::jidmap $roomjid]
    
    # Submit either with or without form.
    if {[info exists state(formtoken)]} {
	set subelements [::JForms::GetXML $state(formtoken)]
    } else {
	SendGet $token
	set subelements {}
    }
    
    # Ask jabberlib to create the room for us.
    $jstate(jlib) muc setroom $roomjid submit -form $subelements \
      -command [list [namespace current]::SetRoomCB $state(usemuc) $roomjid]
    
    # This triggers the tkwait, and destroys the create dialog.
    ::UI::SaveWinGeom $wDlgs(jcreateroom) $state(w)
    set state(finished) 1
    catch {destroy $state(w)}
}

proc ::Create::SetRoomCB {usemuc roomjid jlibName type subiq} { 
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Create::SetRoomCB"
    
    if {$type eq "error"} {
	set str [mc jamessconffailed2 $roomjid]
	append str "\n" "[mc {Error code}]: [lindex $subiq 0]\n"
	append str "[mc Message]: [lindex $subiq 1]"
	::UI::MessageBox -type ok -icon error -title [mc Error] -message $str

    } elseif {[regexp {.+@([^@]+)$} $roomjid match service]} {
		    
	# Cache groupchat protocol type (muc|conference|gc-1.0).
	::hooks::run groupchatEnterRoomHook $roomjid "muc"
    }
}

# Provides dialog for old-style gc-1.0 groupchat -------------------------------

# Create::GCBuild --
#
#       This is to provide support for the old-style 'groupchat 1.0' protocol
#       which shall be used when not server is being browsed.
#       
# Arguments:
#       args        -server, -roomjid, -nickname
#       
# Results:
#       "cancel" or "enter".
     
proc ::Create::GCBuild {args} {
    global  this wDlgs

    variable uid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs

    set chatservers [$jstate(jlib) disco getconferences]
    ::Debug 2 "::Create::GCBuild chatservers=$chatservers args='$args'"
    
    if {0 && $chatservers == {}} {
	::UI::MessageBox -icon error -title [mc Error] \
	  -message [mc jamessnogroupchat2]
	return
    }

    # State variable to collect instance specific variables.
    set token [namespace current]::enter[incr uid]
    variable $token
    upvar 0 $token enter
    
    set w $wDlgs(jgcenter)$uid
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox} \
      -closecommand [namespace current]::GCCloseEnterCB
    wm title $w [mc "Enter/Create Chatroom"]
    
    set enter(w) $w
    array set enter {
	finished    -1
	server      ""
	roomname    ""
	nickname    ""
    }
    if {$jprefs(defnick) eq ""} {
	jlib::splitjidex [Jabber::Jlib myjid] node - -
	set enter(nickname) $node
    } else {
	set enter(nickname) $jprefs(defnick)
    }
    array set argsA $args
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    set enter(server) [lindex $chatservers 0]
    set frmid $wbox.mid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1

    set msg [mc jagchatmsg]
    ttk::label $frmid.msg -style Small.TLabel \
      -padding {0 0 0 6} -anchor w -wraplength 300 -justify left -text $msg
    ttk::label $frmid.lserv -text "[mc Service]:" -anchor e

    set wcomboserver $frmid.eserv
    ttk::combobox $wcomboserver -width 18  \
      -textvariable $token\(server) -values $chatservers
    ttk::label $frmid.lroom -text "[mc Chatroom]:" -anchor e
    ttk::entry $frmid.eroom -width 24    \
      -textvariable $token\(roomname) -validate key  \
      -validatecommand {::Jabber::ValidateUsernameStrEsc %S}
    ttk::label $frmid.lnick -text "[mc Nickname]:" \
      -anchor e
    ttk::entry $frmid.enick -width 24    \
      -textvariable $token\(nickname) -validate key  \
      -validatecommand {::Jabber::ValidateResourceStr %S}
    
    grid  $frmid.msg    -             -pady 2 -sticky w
    grid  $frmid.lserv  $frmid.eserv  -pady 2
    grid  $frmid.lroom  $frmid.eroom  -pady 2
    grid  $frmid.lnick  $frmid.enick  -pady 2
    grid  $frmid.lserv  $frmid.lroom  $frmid.lnick -sticky e
    grid  $frmid.eserv  $frmid.eroom  $frmid.enick -sticky ew
    
    if {[info exists argsA(-roomjid)]} {
	jlib::splitjidex $argsA(-roomjid) node service res
	set enter(roomname) [jlib::unescapestr $node]
	set enter(server)   $service
	$wcomboserver state {disabled}
	$frmid.eroom  state {disabled}
    }
    if {[info exists argsA(-server)]} {
	set server $argsA(-server)
	set enter(server) $argsA(-server)
	$wcomboserver state {disabled}
    }
    if {[info exists argsA(-nickname)]} {
	set enter(nickname) $argsA(-nickname)
    }
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Enter] -default active \
      -command [list [namespace current]::GCDoEnter $token]
    ttk::button $frbot.btcancel -text [mc Cancel]   \
      -command [list [namespace current]::GCCancel $token]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side top -fill x
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    wm resizable $w 0 0
    ::UI::SetWindowPosition $w $wDlgs(jgcenter)
    bind $w <Return> [list $frbot.btok invoke]
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {focus $oldFocus}
    set finished $enter(finished)
    unset enter
    return [expr {($finished <= 0) ? "cancel" : "enter"}]
}

proc ::Create::GCCloseEnterCB {w} {
    global  wDlgs
    
    ::UI::SaveWinPrefixGeom $wDlgs(jgcenter)
    return
}

proc ::Create::GCCancel {token} {
    variable $token
    upvar 0 $token enter

    set enter(finished) 0
    catch {destroy $enter(w)}
}

proc ::Create::GCDoEnter {token} {
    variable $token
    upvar 0 $token enter

    upvar ::Jabber::jstate jstate
    
    # Verify the fields first.
    if {($enter(server) eq "") || ($enter(roomname) eq "") ||  \
      ($enter(nickname) eq "")} {
	::UI::MessageBox -icon error -title [mc Warning] -type ok -message \
	  [mc jamessgchatfields2] -parent $enter(w)
	return
    }

    set node [jlib::escapestr $enter(roomname)]
    set roomjid [jlib::jidmap [jlib::joinjid $node $enter(server) ""]]
    set roomjid [jlib::jidmap $roomjid]
    $jstate(jlib) groupchat enter $roomjid $enter(nickname) \
      -command [namespace current]::EnterCallback

    set enter(finished) 1
    destroy $enter(w)
}

proc ::Create::EnterCallback {jlibname xmldata} {
    
    set from [wrapper::getattribute $xmldata from]
    set type [wrapper::getattribute $xmldata type]
    if {$type eq ""} {
	set type "available"
    }    
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
	return
    }
    
    # Cache groupchat protocol type (muc|conference|gc-1.0).
    ::hooks::run groupchatEnterRoomHook $from "gc-1.0"
}

#-------------------------------------------------------------------------------
