#  Register.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the registration UI parts for jabber.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#
# $Id: Register.tcl,v 1.31 2004-12-02 08:22:34 matben Exp $

package provide Register 1.0

namespace eval ::Register:: {

    variable server
    variable username
    variable password
}

# Register::NewDlg --
#
#       Registers new user with a server.
#
# Arguments:
#       args   -server, -username, -password
#       
# Results:
#       "cancel" or "new".

proc ::Register::NewDlg {args} {
    global  this wDlgs
    
    upvar ::Jabber::jprefs jprefs
    variable finished  -1
    variable server    ""
    variable username  ""
    variable password  ""
    variable password2 ""
    variable ssl       0
    variable port      $jprefs(port)
    
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
      -variable [namespace current]::ssl \
      -command [namespace current]::SSLCmd
    label $frmid.lport -text "[mc {Port number}]:" -font $fontSB  \
      -anchor e
    entry $frmid.eport -width 6   \
      -textvariable [namespace current]::port -validate key  \
      -validatecommand {::Register::ValidatePortNumber %S}
    
    grid $frmid.lserv  -column 0 -row 0 -sticky e
    grid $frmid.eserv  -column 1 -row 0 -sticky w
    grid $frmid.luser  -column 0 -row 1 -sticky e
    grid $frmid.euser  -column 1 -row 1 -sticky w
    grid $frmid.lpass  -column 0 -row 2 -sticky e
    grid $frmid.epass  -column 1 -row 2 -sticky w
    grid $frmid.lpass2 -column 0 -row 3 -sticky e
    grid $frmid.epass2 -column 1 -row 3 -sticky w
    grid $frmid.cssl   -column 1 -row 4 -sticky w
    grid $frmid.lport  -column 0 -row 5 -sticky e
    grid $frmid.eport  -column 1 -row 5 -sticky w

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

proc ::Register::ValidatePortNumber {str} {
    
    if {[string is integer $str]} {
	return 1
    } else {
	bell
	return 0
    }
}

proc ::Register::SSLCmd { } {
    variable ssl
    variable port
    upvar ::Jabber::jprefs jprefs
    
    if {$ssl} {
	set port $jprefs(sslport)
    } else {
	set port $jprefs(port)
    }
}

proc ::Register::Cancel {w} {
    variable finished

    set finished 0
    destroy $w
}

proc ::Register::OK {w} {
    variable password
    variable password2
    
    if {$password != $password2} {
	::UI::MessageBox -icon error -title [mc {Different Passwords}] \
	  -message [mc messpasswddifferent] -parent $w
	set password  ""
	set password2 ""
    } else {
	[namespace current]::DoRegister $w
    }
}

# Register::DoRegister --
#
#       Initiates a register operation.
# Arguments:
#       w
#       
# Results:
#       None, dialog closed.

proc ::Register::DoRegister {w} {
    global  errorCode prefs

    variable finished
    variable server
    variable username
    variable password
    variable ssl
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Register::DoRegister"
    
    # Kill any pending open states.
    ::Network::KillAll
    ::Jabber::UI::SetStatusMessage ""
    ::Jabber::UI::StartStopAnimatedWave 0
    
    # Check 'server', 'username' if acceptable.
    foreach name {server username} {
	upvar 0 $name what
	if {[string length $what] <= 1} {
	    ::UI::MessageBox -icon error -type ok -parent [winfo toplevel $w] \
	      -message [mc jamessnamemissing $name]
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
	    ::UI::MessageBox -icon error -type ok \
	      -message [mc jamessillegalchar $name $what]
	    return
	}
    }    
    destroy $w
    
    # Asks for a socket to the server.
    ::Login::Connect $server [namespace current]::ConnectCB -ssl $ssl
}

proc ::Register::ConnectCB {status msg} {
    variable server

    ::Debug 2 "::Register::ConnectCB status=$status"
    
    switch $status {
	error {
	    ::UI::MessageBox -icon error -type ok \
	      -message [mc jamessnosocket $server $msg]
	}
	timeout {
	    ::UI::MessageBox -icon error -type ok \
	      -message [mc jamesstimeoutserver $server]
	}
	default {
	    # Go ahead...
	    if {[catch {
		::Login::InitStream $server \
		  [namespace current]::SendRegister
	    } err]} {
		::UI::MessageBox -icon error -title [mc {Open Failed}] \
		  -type ok -message $err
	    }
	}
    }
}

proc ::Register::SendRegister {args} {
    variable username
    variable password
    variable streamid
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Register::SendRegister args=$args"
    
    array set argsArr $args
    if {![info exists argsArr(id)]} {
	::UI::MessageBox -icon error -type ok -message \
	  "no id for digest in receiving <stream>"
    } else {
	set streamid $argsArr(id)

	# Make a new account. Perhaps necessary to get additional variables
	# from some user preferences.
	$jstate(jlib) register_set $username $password   \
	  [namespace current]::SendRegisterCB
    }
}

proc ::Register::SendRegisterCB {jlibName type theQuery} {    
    variable finished
    variable server
    variable username
    variable resource
    variable password
    variable streamid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Register::SendRegisterCB jlibName=$jlibName,\
      type=$type, theQuery=$theQuery"
    
    if {[string equal $type "error"]} {
	set errcode [lindex $theQuery 0]
	set errmsg [lindex $theQuery 1]
	if {$errcode == 409} {
	    set msg [mc jamessregerrinuse $errmsg]
	} else {
	    set msg [mc jamessregerr $errmsg]
	}
	::UI::MessageBox -title [mc Error] -icon error -type ok \
	  -message $msg
    } else {

	# Save to our jserver variable. Create a new profile.
	::Profiles::Set "" $server $username $password
    }
    if {$jprefs(logonWhenRegister)} {
	
	# Go on and authenticate.
	set resource "coccinella"
	::Login::Authorize $server $username $resource $password \
	  [namespace current]::AuthorizeCB -streamid $streamid -digest 1
    } else {
	::UI::MessageBox -icon info -type ok \
	  -message [mc jamessregisterok $server]
    
	# Disconnect. This should reset both wrapper and XML parser!
	# Beware: we are in the middle of a callback from the xml parser,
	# and need to be sure to exit from it before resetting!
	after idle $jstate(jlib) closestream
    }
    set finished 1
}

proc ::Register::AuthorizeCB {type msg} {
    variable server
    variable username
    variable resource
    
    ::Debug 2 "::Register::AuthorizeCB type=$type"
    
    if {[string equal $type "error"]} {
	::UI::MessageBox -icon error -type ok -title [mc Error]  \
	  -message $msg
    } else {
	
	# Login was succesful, set presence.
	::Login::SetStatus
	set jid [jlib::joinjid $username $server $resource]
	::UI::MessageBox -icon info -type ok \
	  -message [mc jamessregloginok $jid]
    }
}

# Register::Remove --
#
#       Removes an existing user account from your login server.
#
# Arguments:
#       jid:        Optional, defaults to login server
#       
# Results:
#       Remote callback from server scheduled.

proc ::Register::Remove {{jid {}}} {
    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver

    ::Debug 2 "::Register::Remove jid=$jid"
    
    set ans "yes"
    if {$jid == ""} {
	set jid $jserver(this)
	set ans [::UI::MessageBox -icon warning -title [mc Unregister] \
	  -type yesno -default no -message [mc jamessremoveaccount]]
    }
    if {$ans == "yes"} {
	
	# Do we need to obtain a key for this???
	$jstate(jlib) register_remove $jid  \
	  [list ::Register::RemoveCallback $jid]
	
	# Remove also from our profile if our login account.
	if {$jid == $jserver(this)} {
	    set profile [::Profiles::FindProfileNameFromJID $jstate(mejid)]
	    if {$profile != ""} {
		::Profiles::Remove $profile
	    }
	}
    }
}

proc ::Register::RemoveCallback {jid jlibName type theQuery} {
    
    if {[string equal $type "error"]} {
	foreach {errcode errmsg} $theQuery break
	::UI::MessageBox -icon error -title [mc Unregister] -type ok  \
	  -message [mc jamesserrunreg $jid $errcode $errmsg]
    } else {
	::UI::MessageBox -icon info -title [mc Unregister] -type ok  \
	  -message [mc jamessokunreg $jid]
    }
}

# The ::GenRegister:: namespace -----------------------------------------

namespace eval ::GenRegister:: {

    variable uid 0
    variable UItype 2
}

# GenRegister::NewDlg --
#
#       Initiates the process of registering with a service. 
#       Uses iq get-set method.
#       
# Arguments:
#       args   -server, -autoget 0/1
#       
# Results:
#       "cancel" or "register".
     
proc ::GenRegister::NewDlg {args} {
    global  this wDlgs

    variable uid
    variable UItype
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::GenRegister::NewDlg args=$args"
    
    # Initialize the state variable, an array.    
    set token [namespace current]::dlg[incr uid]
    variable $token
    upvar 0 $token state

    array set argsArr $args

    set w $wDlgs(jreg)${uid}
    set state(w) $w
    set state(finished) -1
    set state(args) $args
    
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -closecommand [list [namespace current]::CloseCmd $token]
    wm title $w [mc {Register Service}]
    set wtop $w
        
    # Global frame.
    set wall $w.fr
    frame $wall -borderwidth 1 -relief raised
    pack  $wall -fill both -expand 1 -ipadx 12 -ipady 4
    
    ::headlabel::headlabel $wall.head -text [mc {Register Service}]
    pack $wall.head -side top -fill both

    label $wall.msg -wraplength 280 -justify left -text [mc jaregmsg]
    pack  $wall.msg -side top -anchor w -padx 4 -pady 4
    
    set frtop $wall.top
    pack [frame $frtop] -side top -anchor w -padx 4
    label $frtop.lserv -text "[mc {Service server}]:"
    
    # Get all (browsed) services that support registration.
    set regServers [$jstate(jlib) service getjidsfor "register"]
    set wcomboserver $frtop.eserv
    ::combobox::combobox $wcomboserver -width 18   \
      -textvariable $token\(server) -editable 0
    eval {$frtop.eserv list insert end} $regServers
    
    # Find the default registration server.
    if {[llength $regServers]} {
	set state(server) [lindex $regServers 0]
    }
    if {[info exists argsArr(-server)]} {
	set state(server) $argsArr(-server)
	$wcomboserver configure -state disabled
    }

    grid $frtop.lserv $wcomboserver -sticky e
    grid $wcomboserver -sticky ew
    
    # Button part.
    pack [frame $wall.pady -height 8] -side bottom
    set frbot [frame $wall.frbot -borderwidth 0]
    set wbtregister $frbot.btenter
    set wbtget      $frbot.btget
    pack [button $wbtget -text [mc Get] -default active \
      -command [list [namespace current]::Get $token]] \
      -side right -padx 5
    pack [button $wbtregister -text [mc Register] -state disabled \
      -command [list [namespace current]::DoRegister $token]]  \
      -side right -padx 5
    pack [button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::Cancel $token]]  \
      -side right -padx 5
    pack $frbot -side bottom -fill both -padx 8
    
    # Running arrows and status message.
    set wstat $wall.fs
    pack [frame $wstat] -side bottom -anchor w -fill x -padx 16 -pady 0
    set wsearrows $wstat.arr
    pack [::chasearrows::chasearrows $wsearrows -size 16] -side left
    pack [label $wstat.lstat -textvariable $token\(stattxt)] -side left -padx 8

    # This part must be built dynamically from the 'get' xml data.
    # May be different for each conference server.

    if {$UItype == 0} {
	set wfr $wall.frlab
	labelframe $wfr -text [mc Specifications]
	pack $wfr -side top -fill both -padx 2 -pady 2
	
	set wbox $wfr.box
	frame $wbox
	pack $wbox -side top -fill x -padx 4 -pady 10
	pack [label $wbox.la -textvariable $token\(stattxt)] -padx 0 -pady 10
    }
    if {$UItype == 2} {
	
	# Not same wbox as above!!!
	set wbox $wall.frmid
	::Jabber::Forms::BuildScrollForm $wbox -height 100 -width 180
	pack $wbox -side top -fill both -expand 1 -padx 8 -pady 4
    }
    
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jreg)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jreg)
    }
    
    set state(stattxt)      [mc jasearchwait]
    set state(wcomboserver) $wcomboserver
    set state(wbox)         $wbox
    set state(wsearrows)    $wsearrows
    set state(wbtregister)  $wbtregister
    set state(wbtget)       $wbtget

    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 10]
	wm minsize %s [winfo reqwidth %s] 300
    } $wall.msg $w $w $w]    
    after idle $script

    if {[info exists argsArr(-autoget)] && $argsArr(-autoget)} {
	after idle [list [namespace current]::Get $token]
    }
    
    return ""
}

proc ::GenRegister::Get {token} {    
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    # Verify.
    if {[string length $state(server)] == 0} {
	::UI::MessageBox -type ok -icon error  \
	  -message [mc jamessregnoserver]
	return
    }	
    $state(wcomboserver) configure -state disabled
    $state(wbtget)       configure -state disabled
    set state(stattxt) [mc jawaitserver]
    
    # Send get register.
    $jstate(jlib) register_get [list ::GenRegister::GetCB $token] \
      -to $state(server)
    $state(wsearrows) start
}

proc ::GenRegister::GetCB {token jlibName type subiq} {    
    variable $token
    upvar 0 $token state
    variable UItype
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::GenRegister::GetCB type=$type"

    if {!([info exists state(w)] && [winfo exists $state(w)])} {
	return
    }
    $state(wsearrows) stop
    
    if {[string equal $type "error"]} {
	::UI::MessageBox -type ok -icon error  \
	  -message [mc jamesserrregget [lindex $subiq 0] [lindex $subiq 1]]
	return
    }
    set wbox $state(wbox)
    set childs [wrapper::getchildren $subiq]
    if {$UItype == 0} {
	catch {destroy $wbox}
	::Jabber::Forms::Build $wbox $childs -template "register"
	pack $wbox -side top -fill x -anchor w -padx 2 -pady 10
    }
    if {$UItype == 2} {
	set state(stattxt) ""
	::Jabber::Forms::FillScrollForm $wbox $childs -template "register"
    }
    
    $state(wbtregister) configure -state normal -default active
    $state(wbtget)      configure -state normal -default disabled    
}

proc ::GenRegister::DoRegister {token} {   
    variable $token
    upvar 0 $token state
    variable UItype
    upvar ::Jabber::jstate jstate
    
    if {!([info exists state(w)] && [winfo exists $state(w)])} {
	return
    }
    $state(wsearrows) start
    set wbox $state(wbox)
    if {$UItype != 2} {
	set subelements [::Jabber::Forms::GetXML $wbox]
    } else {
	set subelements [::Jabber::Forms::GetScrollForm $wbox]
    }
    
    # We need to do it the crude way.
    $jstate(jlib) send_iq "set"  \
      [wrapper::createtag "query" -attrlist {xmlns jabber:iq:register}   \
      -subtags $subelements] -to $state(server)   \
      -command [list [namespace current]::ResultCallback $token]

    # Keep state array until callback.
    set state(finished) 1
    destroy $state(w)
}

# GenRegister::ResultCallback --
#
#       This is our callback procedure from 'jabber:iq:register' stuffs.

proc ::GenRegister::ResultCallback {token type subiq args} {
    variable $token
    upvar 0 $token state

    ::Debug 2 "::GenRegister::ResultCallback type=$type, subiq='$subiq'"

    if {[string equal $type "error"]} {
	::UI::MessageBox -type ok -icon error -message \
	  [mc jamesserrregset $state(server) [lindex $subiq 0] [lindex $subiq 1]]
    } else {
	::UI::MessageBox -type ok -icon info \
	  -message [mc jamessokreg $state(server)]
    }
    
    # Time to clean up.
    unset state
}

proc ::GenRegister::Cancel {token} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    
    set state(finished) 0
    ::UI::SaveWinPrefixGeom $wDlgs(jreg)
    destroy $state(w)
    unset state
}

proc ::GenRegister::CloseCmd {token wclose} {
    global  wDlgs
    variable $token
    upvar 0 $token state

    ::UI::SaveWinPrefixGeom $wDlgs(jreg)
    unset state
}

#--- Simple --------------------------------------------------------------------

# GenRegister::Simple --
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
     
proc ::GenRegister::Simple {w args} {
    global  this

    variable wtop
    variable wbtregister
    variable server
    variable finished -1
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::GenRegister::Simple"
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
      -command [list [namespace current]::CancelSimple $w]]  \
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

proc ::GenRegister::CancelSimple {w} {
    variable finished
    
    set finished 0
    destroy $w
}

proc ::GenRegister::DoSimple { } {    
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

proc ::GenRegister::SimpleCallback {server jlibName type subiq} {

    ::Debug 2 "::GenRegister::ResultCallback server=$server, type=$type, subiq='$subiq'"

    if {[string equal $type "error"]} {
	::UI::MessageBox -type ok -icon error -message \
	  [mc jamesserrregset $server [lindex $subiq 0] [lindex $subiq 1]]
    } else {
	::UI::MessageBox -type ok -icon info -message [mc jamessokreg $server]
    }
}

#-------------------------------------------------------------------------------
