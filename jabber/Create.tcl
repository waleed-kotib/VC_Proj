#  Create.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements a create dialog for groupchat using the 'muc' protocol.
#      
#  Copyright (c) 2006  Mats Bengtsson
#  
# $Id: Create.tcl,v 1.3 2006-05-17 06:35:02 matben Exp $

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
    array set argsArr $args
    
    # State variable to collect instance specific variables.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
    
    set w $wDlgs(jcreateroom)$uid    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document {closeBox resizable}} \
      -closecommand [list [namespace current]::Close $token]
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
    if {[info exists argsArr(-roomname)]} {
	set state(roomname) $argsArr(-roomname)
    }
    if {[info exists argsArr(-nickname)]} {
	set state(nickname) $argsArr(-nickname)
    }
    set state(w)              $w
    set state(wraplength)     300
        
    set confServers [$jstate(jlib) disco getconferences]
    if {$confServers eq {}} {
	set serviceList [list [mc {No Available}]]
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
    if {$confServers eq {}} {
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

    if {$confServers eq {}} {
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
	  [list [namespace current]::TraceServer $token]
	SetState $token
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

proc ::Create::TraceServer {token name junk1 junk2} {    
    
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
	$state(wbtcreate) state {!disabled}
    } else {
	$state(wbtcreate) state {disabled}
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
    set roomjid $state(roomname)@$state(server)
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
	  -message [mc jamessnogroupchat]
	return
    }
    if {$state(roomname) eq ""} {
	::UI::MessageBox -type ok -icon error -parent $state(w) \
	  -message [mc jamessgcnoroomname]
	return
    }
    if {($state(usemuc) && ($state(nickname) eq ""))} {
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
    SendGet $token
}

proc ::Create::SendGet {token} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
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
    } else {
	
	# Error
    }
}

# Create::CreateMUCCB --
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

proc ::Create::CreateMUCCB {token jlibName type args} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Create::CreateMUCCB type=$type, args='$args'"
    
    if {![info exists state(w)]} {
	return
    }
    $state(wsearrows) stop
    array set argsArr $args
    
    if {$type eq "error"} {
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

proc ::Create::SetRoom {token} {
    global  wDlgs
    variable $token
    upvar 0 $token state

    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Create::SetRoom"

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
	::UI::MessageBox -type ok -icon error -message  \
	  [mc jamessconffailed $roomjid [lindex $subiq 0] [lindex $subiq 1]]
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
	::UI::MessageBox -icon error -message [mc jamessnogroupchat]
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
    wm title $w [mc {Enter/Create Room}]
    
    set enter(w) $w
    array set enter {
	finished    -1
	server      ""
	roomname    ""
	nickname    ""
    }
    set enter(nickname) $jprefs(defnick)
    array set argsArr $args
    
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
    ttk::label $frmid.lserv -text "[mc Servers]:" -anchor e

    set wcomboserver $frmid.eserv
    ttk::combobox $wcomboserver -width 18  \
      -textvariable $token\(server) -values $chatservers
    ttk::label $frmid.lroom -text "[mc Room]:" -anchor e
    ttk::entry $frmid.eroom -width 24    \
      -textvariable $token\(roomname) -validate key  \
      -validatecommand {::Jabber::ValidateUsernameStr %S}
    ttk::label $frmid.lnick -text "[mc {Nick name}]:" \
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
    
    if {[info exists argsArr(-roomjid)]} {
	jlib::splitjidex $argsArr(-roomjid) node service res
	set enter(roomname) $node
	set enter(server)   $service
	$wcomboserver state {disabled}
	$frmid.eroom  state {disabled}
    }
    if {[info exists argsArr(-server)]} {
	set server $argsArr(-server)
	set enter(server) $argsArr(-server)
	$wcomboserver state {disabled}
    }
    if {[info exists argsArr(-nickname)]} {
	set enter(nickname) $argsArr(-nickname)
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
	  [mc jamessgchatfields] -parent $enter(w)
	return
    }

    set roomjid [jlib::jidmap [jlib::joinjid $enter(roomname) $enter(server) ""]]
    $jstate(jlib) groupchat enter $roomjid $enter(nickname) \
      -command [namespace current]::EnterCallback

    set enter(finished) 1
    destroy $enter(w)
}

proc ::Create::EnterCallback {jlibName type args} {
    
    array set argsArr $args
    if {[string equal $type "error"]} {
	set msg [mc mucErrEnter $argsArr(-from)]
	if {[info exists argsArr(-error)]} {
	    foreach {errcode errmsg} $argsArr(-error) break
	    append msg [mc mucErrCode $errcode $errmsg]
	}
	::UI::MessageBox -title [mc mucErrEnterTitle] -message $msg -icon error
	return
    }
    
    # Cache groupchat protocol type (muc|conference|gc-1.0).
    ::hooks::run groupchatEnterRoomHook $argsArr(-from) "gc-1.0"
}

#-------------------------------------------------------------------------------
