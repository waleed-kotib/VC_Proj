#  Register.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the registration UI parts for jabber.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#
# $Id: Register.tcl,v 1.24 2004-07-09 06:26:06 matben Exp $

package provide Register 1.0

namespace eval ::Jabber::Register:: {

    variable server
    variable username
    variable password
}

# Jabber::Register::Register --
#
#       Registers new user with a server.
#
# Arguments:
#       args   -server, -username, -password
#       
# Results:
#       "cancel" or "new".

proc ::Jabber::Register::Register {args} {
    global  this wDlgs
    
    upvar ::Jabber::jprefs jprefs
    variable finished  -1
    variable server    ""
    variable username  ""
    variable password  ""
    variable password2 ""
    variable ssl       0
    
    set w $wDlgs(jreg)
    if {[winfo exists $w]} {
	return
    }
    set finished -1
    array set argsArr $args
    foreach name {server username password} {
	if {[info exists argsArr(-$name)]} {
	    set $name $argsArr(-$name)
	}
    }
    if {[info exists password]} {
	set password2 $password
    }
    set ssl $jprefs(usessl)

    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm title $w [mc {Register New Account}]
    
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 12 -ipady 4
    
    ::headlabel::headlabel $w.frall.head -text [mc {New Account}]
    pack $w.frall.head -side top -fill both -expand 1
    message $w.frall.msg -width 260  \
      -text [mc janewaccount]
    pack $w.frall.msg -side top -fill both -expand 1
    
    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    label $frmid.lserv -text "[mc {Jabber server}]:"  \
      -font $fontSB -anchor e
    entry $frmid.eserv -width 22    \
      -textvariable [namespace current]::server -validate key  \
      -validatecommand {::Jabber::ValidateDomainStr %S}
    label $frmid.luser -text "[mc Username]:" -font $fontSB  \
      -anchor e
    entry $frmid.euser -width 22   \
      -textvariable [namespace current]::username -validate key  \
      -validatecommand {::Jabber::ValidateUsernameStr %S}
    label $frmid.lpass -text "[mc Password]:" -font $fontSB  \
      -anchor e
    entry $frmid.epass -width 22  -show {*}  \
      -textvariable [namespace current]::password -validate key  \
      -validatecommand {::Jabber::ValidatePasswdChars %S}
    label $frmid.lpass2 -text "[mc {Retype password}]:" -font $fontSB  \
      -anchor e
    entry $frmid.epass2 -width 22   \
      -textvariable [namespace current]::password2 -validate key  \
      -validatecommand {::Jabber::ValidatePasswdChars %S} -show {*}
    checkbutton $frmid.cssl -text "  [mc {Use SSL for security}]"  \
      -variable [namespace current]::ssl
    
    grid $frmid.lserv  -column 0 -row 0 -sticky e
    grid $frmid.eserv  -column 1 -row 0 -sticky w
    grid $frmid.luser  -column 0 -row 1 -sticky e
    grid $frmid.euser  -column 1 -row 1 -sticky w
    grid $frmid.lpass  -column 0 -row 2 -sticky e
    grid $frmid.epass  -column 1 -row 2 -sticky w
    grid $frmid.lpass2 -column 0 -row 3 -sticky e
    grid $frmid.epass2 -column 1 -row 3 -sticky w
    grid $frmid.cssl   -column 1 -row 4 -sticky w

    pack $frmid -side top -fill both -expand 1

    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [mc New] -default active \
      -command [list [namespace current]::OK $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::Cancel $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    #bind $w <Return> "$frbot.btok invoke"
    
    # Grab and focus.
    set oldFocus [focus]
    focus $frmid.eserv
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {grab release $w}
    catch {focus $oldFocus}
    return [expr {($finished <= 0) ? "cancel" : "new"}]
}

proc ::Jabber::Register::Cancel {w} {
    variable finished

    set finished 0
    destroy $w
}

proc ::Jabber::Register::OK {w} {
    variable password
    variable password2
    
    if {$password != $password2} {
	tk_messageBox -icon error -title [mc {Different Passwords}] \
	  -message [mc messpasswddifferent] -parent $w
	set password  ""
	set password2 ""
    } else {
	[namespace current]::DoRegister $w
    }
}

# Jabber::Register::DoRegister --
#
#       Initiates a register operation.
# Arguments:
#       w
#       
# Results:
#       None, dialog closed.

proc ::Jabber::Register::DoRegister {w} {
    global  errorCode prefs

    variable finished
    variable server
    variable username
    variable password
    variable ssl
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::Register::DoRegister"
    
    # Kill any pending open states.
    ::Network::KillAll
    ::Jabber::UI::SetStatusMessage ""
    ::Jabber::UI::StartStopAnimatedWave 0
    
    # Check 'server', 'username' if acceptable.
    foreach name {server username} {
	upvar 0 $name what
	if {[string length $what] <= 1} {
	    tk_messageBox -icon error -type ok -parent [winfo toplevel $w] \
	      -message [FormatTextForMessageBox \
	      [mc jamessnamemissing $name]]
	    return
	}
	
	# This is just to check the validity!
	if {[catch {
	    switch -- $name {
		server {
		    jlib::nameprep $what
		}
		username {
		    jlib::nodeprep $what
		}
	    }
	} err]} {
	    tk_messageBox -icon error -type ok -message [FormatTextForMessageBox  \
	      [mc jamessillegalchar $name $what]]
	    return
	}
    }    
    destroy $w
    
    # Asks for a socket to the server.
    ::Jabber::Login::Connect $server [namespace current]::ConnectCB -ssl $ssl
}

proc ::Jabber::Register::ConnectCB {status msg} {
    variable server

    ::Debug 2 "::Jabber::Register::ConnectCB status=$status"
    
    switch $status {
	error {
	    tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	      [mc jamessnosocket $ip $msg]]
	}
	timeout {
	    tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	      [mc jamesstimeoutserver $server]]
	}
	default {
	    # Go ahead...
	    if {[catch {
		::Jabber::Login::InitStream $server \
		  [namespace current]::SendRegister
	    } err]} {
		tk_messageBox -icon error -title [mc {Open Failed}] \
		  -type ok -message [FormatTextForMessageBox $err]
	    }
	}
    }
}

proc ::Jabber::Register::SendRegister {args} {
    variable username
    variable password
    variable streamid
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::Register::SendRegister args=$args"
    
    array set argsArr $args
    if {![info exists argsArr(id)]} {
	tk_messageBox -icon error -type ok -message \
	  "no id for digest in receiving <stream>"
    } else {
	set streamid $argsArr(id)

	# Make a new account. Perhaps necessary to get additional variables
	# from some user preferences.
	$jstate(jlib) register_set $username $password   \
	  [namespace current]::SendRegisterCB
    }
}

proc ::Jabber::Register::SendRegisterCB {jlibName type theQuery} {    
    variable finished
    variable server
    variable username
    variable resource
    variable password
    variable streamid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Jabber::Register::SendRegisterCB jlibName=$jlibName,\
      type=$type, theQuery=$theQuery"
    
    if {[string equal $type "error"]} {
	set errcode [lindex $theQuery 0]
	set errmsg [lindex $theQuery 1]
	if {$errcode == 409} {
	    set msg [mc jamessregerrinuse $errmsg]
	} else {
	    set msg [mc jamessregerr $errmsg]
	}
	tk_messageBox -title [mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox $msg]
    } else {

	# Save to our jserver variable. Create a new profile.
	::Profiles::Set "" $server $username $password
    }
    if {$jprefs(logonWhenRegister)} {
	
	# Go on and authenticate.
	set resource "coccinella"
	::Jabber::Login::Authorize $server $username $resource $password \
	  [namespace current]::AuthorizeCB -streamid $streamid -digest 1
    } else {
	tk_messageBox -icon info -type ok -message [FormatTextForMessageBox \
	  [mc jamessregisterok $server]]
    
	# Disconnect. This should reset both wrapper and XML parser!
	# Beware: we are in the middle of a callback from the xml parser,
	# and need to be sure to exit from it before resetting!
	after idle $jstate(jlib) closestream
    }
    set finished 1
}

proc ::Jabber::Register::AuthorizeCB {type msg} {
    variable server
    variable username
    variable resource
    
    ::Debug 2 "::Jabber::Register::AuthorizeCB type=$type"
    
    if {[string equal $type "error"]} {
	tk_messageBox -icon error -type ok -title [mc Error]  \
	  -message [FormatTextForMessageBox $msg]
    } else {
	
	# Login was succesful, set presence.
	::Jabber::Login::SetStatus
	set jid [jlib::joinjid $username $server $resource]
	tk_messageBox -icon info -type ok -message [FormatTextForMessageBox \
	  [mc jamessregloginok $jid]]
    }
}

# Jabber::Register::Remove --
#
#       Removes an existing user account from your login server.
#
# Arguments:
#       jid:        Optional, defaults to login server
#       
# Results:
#       Remote callback from server scheduled.

proc ::Jabber::Register::Remove {{jid {}}} {
    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver

    ::Debug 2 "::Jabber::Register::Remove jid=$jid"
    
    set ans "yes"
    if {$jid == ""} {
	set jid $jserver(this)
	set ans [tk_messageBox -icon warning -title [mc Unregister] \
	  -type yesno -default no -message [FormatTextForMessageBox \
	  [mc jamessremoveaccount]]]
    }
    if {$ans == "yes"} {
	
	# Do we need to obtain a key for this???
	::Jabber::JlibCmd register_remove $jid  \
	  [list ::Jabber::Register::RemoveCallback $jid]
	
	# Remove also from our profile.
	set profile [::Profiles::FindProfileNameFromJID $jstate(mejid)]
	if {$profile != ""} {
	    ::Profiles::Remove $profile
	}
    }
}

proc ::Jabber::Register::RemoveCallback {jid jlibName type theQuery} {
    
    if {[string equal $type "error"]} {
	foreach {errcode errmsg} $theQuery break
	tk_messageBox -icon error -title [mc Unregister] -type ok  \
	  -message [FormatTextForMessageBox \
	  [mc jamesserrunreg $jid $errcode $errmsg]]
    } else {
	tk_messageBox -icon info -title [mc Unregister] -type ok  \
	  -message [FormatTextForMessageBox \
	  [mc jamessokunreg $jid]]
    }
}

# The ::Jabber::GenRegister:: namespace -----------------------------------------

namespace eval ::Jabber::GenRegister:: {

}

# Jabber::GenRegister::BuildRegister --
#
#       Initiates the process of registering with a service. 
#       Uses iq get-set method.
#       
# Arguments:
#       args   -server, -autoget 0/1
#       
# Results:
#       "cancel" or "register".
     
proc ::Jabber::GenRegister::BuildRegister {args} {
    global  this wDlgs

    variable wtop
    variable wbox
    variable wbtregister
    variable wbtget
    variable wcomboserver
    variable server
    variable wsearrows
    variable stattxt
    variable UItype 2
    variable finished -1
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::GenRegister::BuildRegister"
    set w $wDlgs(jreg)
    if {[winfo exists $w]} {
	return
    }
    array set argsArr $args
    
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1
    wm title $w [mc {Register Service}]
    set wtop $w
    
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 12 -ipady 4
    message $w.frall.msg -width 280 -text  \
      [mc jaregmsg] -anchor w -justify left
    pack $w.frall.msg -side top -fill x -anchor w -padx 4 -pady 4
    set frtop $w.frall.top
    pack [frame $frtop] -side top -expand 0 -anchor w -padx 10
    label $frtop.lserv -text "[mc {Service server}]:" -font $fontSB
    
    # Get all (browsed) services that support registration.
    set regServers [::Jabber::JlibCmd service getjidsfor "register"]
    set wcomboserver $frtop.eserv
    ::combobox::combobox $wcomboserver -width 18   \
      -textvariable "[namespace current]::server" -editable 0
    eval {$frtop.eserv list insert end} $regServers
    
    # Find the default registration server.
    if {[llength $regServers]} {
	set server [lindex $regServers 0]
    }
    if {[info exists argsArr(-server)]} {
	set server $argsArr(-server)
	$wcomboserver configure -state disabled
    }
    label $frtop.ldesc -text "[mc Specifications]:" -font $fontSB
    label $frtop.lstat -textvariable [namespace current]::stattxt

    grid $frtop.lserv -column 0 -row 0 -sticky e
    grid $wcomboserver -column 1 -row 0 -sticky ew
    grid $frtop.ldesc -column 0 -row 1 -sticky e -padx 4 -pady 2
    grid $frtop.lstat -column 1 -row 1 -sticky w
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set wsearrows $frbot.arr
    set wbtregister $frbot.btenter
    set wbtget $frbot.btget
    pack [button $wbtget -text [mc Get] -default active \
      -command [namespace current]::Get]  \
      -side right -padx 5 -pady 5
    pack [button $wbtregister -text [mc Register] -state disabled \
      -command [namespace current]::DoRegister]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::Cancel $w]]  \
      -side right -padx 5 -pady 5
    pack [::chasearrows::chasearrows $wsearrows -size 16] \
      -side left -padx 5 -pady 5
    pack $frbot -side bottom -fill both -expand 1 -padx 8 -pady 6

    # This part must be built dynamically from the 'get' xml data.
    # May be different for each conference server.

    if {$UItype == 0} {
	set wfr $w.frall.frlab
	labelframe $wfr -text [mc Specifications]
	pack $wfr -side top -fill both -padx 2 -pady 2
	
	set wbox $wfr.box
	frame $wbox
	pack $wbox -side top -fill x -padx 4 -pady 10
	pack [label $wbox.la -textvariable "[namespace current]::stattxt"]  \
	  -padx 0 -pady 10
    }
    if {$UItype == 2} {
	
	# Not same wbox as above!!!
	set wbox $w.frall.frmid
	::Jabber::Forms::BuildScrollForm $wbox -height 160 \
	  -width 220
	pack $wbox -side top -fill both -expand 1 -padx 8 -pady 4
    }
    
    set stattxt "-- [mc jasearchwait] --"
    wm minsize $w 300 300
	
    # Grab and focus.
    set oldFocus [focus]
    catch {grab $w}
    
    if {[info exists argsArr(-autoget)] && $argsArr(-autoget)} {
	after idle ::Jabber::GenRegister::Get
    }
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {grab release $w}
    catch {focus $oldFocus}
    return [expr {($finished <= 0) ? "cancel" : "register"}]
}

# Jabber::GenRegister::Simple --
#
#       Initiates the process of registering with a service. 
#       Uses straight iq set method with fixed fields (username and password).
#       
# Arguments:
#       w           toplevel widget
#       args   -server
#       
# Results:
#       "cancel" or "register".
     
proc ::Jabber::GenRegister::Simple {w args} {
    global  this

    variable wtop
    variable wbtregister
    variable server
    variable finished -1
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::GenRegister::Simple"
    if {[winfo exists $w]} {
	return
    }
    array set argsArr $args
    
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm title $w [mc {Register Service}]
    set wtop $w
    
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 12 -ipady 4
    message $w.frall.msg -width 240 -text  \
      [mc jaregmsg]
    pack $w.frall.msg -side top -fill x -anchor w -padx 4 -pady 4
    set frtop $w.frall.top
    pack [frame $frtop] -side top -fill x
    label $frtop.lserv -text "[mc {Service server}]:" -font $fontSB
    
    # Get all (browsed) services that support registration.
    set regServers [::Jabber::JlibCmd service getjidsfor "register"]
    set wcomboserver $frtop.eserv
    ::combobox::combobox $wcomboserver -width 20   \
      -textvariable [namespace current]::server -editable 0
    eval {$frtop.eserv list insert end} $regServers
    
    # Find the default conferencing server.
    if {[llength $regServers]} {
	set server [lindex $regServers 0]
    }
    if {[info exists argsArr(-server)]} {
	set server $argsArr(-server)
	$wcomboserver configure -state disabled
    }
    grid $frtop.lserv -column 0 -row 0 -sticky e
    grid $wcomboserver -column 1 -row 0 -sticky ew
    
    label $frtop.luser -text "[mc Username]:" -font $fontSB \
      -anchor e
    entry $frtop.euser -width 26   \
      -textvariable [namespace current]::username -validate key  \
      -validatecommand {::Jabber::ValidateUsernameStr %S}
    label $frtop.lpass -text "[mc Password]:" -font $fontSB \
      -anchor e
    entry $frtop.epass -width 26   \
      -textvariable [namespace current]::password -validate key \
      -validatecommand {::Jabber::ValidatePasswdChars %S}
    
    grid $frtop.luser -column 0 -row 1 -sticky e
    grid $frtop.euser -column 1 -row 1 -sticky ew
    grid $frtop.lpass -column 0 -row 2 -sticky e
    grid $frtop.epass -column 1 -row 2 -sticky ew
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    set wbtregister $frbot.btenter
    pack [button $wbtregister -text [mc Register] \
      -default active -command [namespace current]::DoSimple]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::Cancel $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
	
    wm resizable $w 0 0
	
    # Grab and focus.
    set oldFocus [focus]
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w

    catch {grab release $w}
    catch {focus $oldFocus}
    return [expr {($finished <= 0) ? "cancel" : "register"}]
}

proc ::Jabber::GenRegister::Cancel {w} {
    variable finished
    
    set finished 0
    destroy $w
}

proc ::Jabber::GenRegister::Get { } {    
    variable server
    variable wsearrows
    variable wcomboserver
    variable wbtget
    variable stattxt
    upvar ::Jabber::jstate jstate
    
    # Verify.
    if {[string length $server] == 0} {
	tk_messageBox -type ok -icon error  \
	  -message [mc jamessregnoserver]
	return
    }	
    $wcomboserver configure -state disabled
    $wbtget configure -state disabled
    set stattxt "-- [mc jawaitserver] --"
    
    # Send get register.
    ::Jabber::JlibCmd register_get ::Jabber::GenRegister::GetCB -to $server    
    $wsearrows start
}

proc ::Jabber::GenRegister::GetCB {jlibName type subiq} {    
    variable wtop
    variable wbox
    variable wsearrows
    variable wbtregister
    variable wbtget
    variable UItype
    variable stattxt
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::GenRegister::GetCB type=$type, subiq='$subiq'"

    if {![winfo exists $wtop]} {
	return
    }
    $wsearrows stop
    
    if {[string equal $type "error"]} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [mc jamesserrregget [lindex $subiq 0] [lindex $subiq 1]]]
	return
    }

    set subiqChildList [wrapper::getchildren $subiq]
    if {$UItype == 0} {
	catch {destroy $wbox}
	::Jabber::Forms::Build $wbox $subiqChildList -template "register"
	pack $wbox -side top -fill x -anchor w -padx 2 -pady 10
    }
    if {$UItype == 2} {
	set stattxt ""
	::Jabber::Forms::FillScrollForm $wbox $subiqChildList \
	   -template "register"
    }
    
    $wbtregister configure -state normal -default active
    $wbtget configure -state normal -default disabled    
}

proc ::Jabber::GenRegister::DoRegister { } {   
    variable server
    variable wsearrows
    variable wtop
    variable wbox
    variable finished
    variable UItype
    upvar ::Jabber::jstate jstate
    
    if {[winfo exists $wsearrows]} {
	$wsearrows start
    }
    if {$UItype != 2} {
	set subelements [::Jabber::Forms::GetXML $wbox]
    } else {
	set subelements [::Jabber::Forms::GetScrollForm $wbox]
    }
    
    # We need to do it the crude way.
    $jstate(jlib) send_iq "set"  \
      [wrapper::createtag "query" -attrlist {xmlns jabber:iq:register}   \
      -subtags $subelements] -to $server   \
      -command [list [namespace current]::ResultCallback $server]
    set finished 1
    destroy $wtop
}

proc ::Jabber::GenRegister::DoSimple { } {    
    variable wtop
    variable server
    variable username
    variable password
    variable finished
    upvar ::Jabber::jstate jstate
    
    $jstate(jlib) register_set $username $password  \
      [list [namespace current]::SimpleCallback $server] -to $server
    set finished 1
    destroy $wtop
}

# Jabber::GenRegister::ResultCallback --
#
#       This is our callback procedure from 'jabber:iq:register' stuffs.

proc ::Jabber::GenRegister::ResultCallback {server type subiq} {

    ::Debug 2 "::Jabber::GenRegister::ResultCallback server=$server, type=$type, subiq='$subiq'"

    if {[string equal $type "error"]} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [mc jamesserrregset $server [lindex $subiq 0] [lindex $subiq 1]]]
    } else {
	tk_messageBox -type ok -icon info -message [FormatTextForMessageBox \
	  [mc jamessokreg $server]]
    }
}

proc ::Jabber::GenRegister::SimpleCallback {server jlibName type subiq} {

    ::Debug 2 "::Jabber::GenRegister::ResultCallback server=$server, type=$type, subiq='$subiq'"

    if {[string equal $type "error"]} {
	tk_messageBox -type ok -icon error  \
	  -message [FormatTextForMessageBox \
	  [mc jamesserrregset $server [lindex $subiq 0] [lindex $subiq 1]]]
    } else {
	tk_messageBox -type ok -icon info -message [FormatTextForMessageBox \
	  [mc jamessokreg $server]]
    }
}

#-------------------------------------------------------------------------------
