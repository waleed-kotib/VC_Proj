#  Register.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the registration UI parts for jabber.
#      
#  Copyright (c) 2001-2005  Mats Bengtsson
#
# $Id: Register.tcl,v 1.44 2006-04-07 14:08:28 matben Exp $

package provide Register 1.0

namespace eval ::Register:: {

    option add *JRegister.registerImage         register         widgetDefault
    option add *JRegister.registerDisImage      registerDis      widgetDefault

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
      -macclass {document closeBox} -class JRegister
    wm title $w [mc {Register New Account}]

    set im   [::Theme::GetImage [option get $w registerImage {}]]
    set imd  [::Theme::GetImage [option get $w registerDisImage {}]]

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    ttk::label $w.frall.head -style Headlabel \
      -text [mc {New Account}] -compound left \
      -image [list $im background $imd]
    pack $w.frall.head -side top -anchor w

    ttk::separator $w.frall.s -orient horizontal
    pack $w.frall.s -side top -fill x

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 300 -justify left -text [mc janewaccount]
    pack $wbox.msg -side top -anchor w
    
    # Entries etc.
    
    set frmid $wbox.frmid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1

    ttk::label $frmid.lserv -text "[mc {Jabber Server}]:" -anchor e
    ttk::entry $frmid.eserv  \
      -textvariable [namespace current]::server -validate key  \
      -validatecommand {::Jabber::ValidateDomainStr %S}
    ttk::label $frmid.luser -text "[mc Username]:" -anchor e
    ttk::entry $frmid.euser  \
      -textvariable [namespace current]::username -validate key  \
      -validatecommand {::Jabber::ValidateUsernameStr %S}
    ttk::label $frmid.lpass -text "[mc Password]:" -anchor e
    ttk::entry $frmid.epass   \
      -textvariable [namespace current]::password -validate key  \
      -validatecommand {::Jabber::ValidatePasswordStr %S} -show {*}
    ttk::label $frmid.lpass2 -text "[mc {Retype password}]:"  \
      -anchor e
    ttk::entry $frmid.epass2  \
      -textvariable [namespace current]::password2 -validate key  \
      -validatecommand {::Jabber::ValidatePasswordStr %S} -show {*}
    ttk::checkbutton $frmid.cssl -style Small.TCheckbutton \
      -text [mc {Use SSL for security}]  \
      -variable [namespace current]::ssl \
      -command [namespace current]::SSLCmd
    ttk::label $frmid.lport -style Small.TLabel \
      -text "[mc {Port}]:" -anchor e
    ttk::entry $frmid.eport -style Small.TEntry -width 6   \
      -textvariable [namespace current]::port -validate key  \
      -validatecommand {::Register::ValidatePortNumber %S}  \
      -font CociSmallFont
    
    grid  $frmid.lserv   $frmid.eserv  -pady 2
    grid  $frmid.luser   $frmid.euser  -pady 2
    grid  $frmid.lpass   $frmid.epass  -pady 2
    grid  $frmid.lpass2  $frmid.epass2 -pady 2
    grid  x              $frmid.cssl   -pady 2
    grid  $frmid.lport   $frmid.eport  -pady 2
    
    grid $frmid.lserv $frmid.luser $frmid.lpass $frmid.lpass2 $frmid.lport \
      -sticky e
    grid $frmid.eserv $frmid.euser $frmid.epass $frmid.epass2 -sticky ew
    grid $frmid.cssl $frmid.eport -sticky w
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Register] -default active \
      -command [list [namespace current]::OK $w]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::Cancel $w]
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
	::Profiles::Set {} $server $username $password
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
#       Removes an existing user account from your login server or any jid.
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
    if {$jid eq ""} {
	set jid $jserver(this)
	set ans [::UI::MessageBox -icon warning -title [mc Unregister] \
	  -type yesno -default no -message [mc jamessremoveaccount]]
    } else {
	set jidlist [::Roster::GetUsersWithSameHost $jid]
	if {[llength $jidlist]} {
	    set msg "You are about to unregister a transport with a number\
	      of dependent users. Do you want to remove these users as well (Yes),\
	      keep them (No), or cancel the whole thing (Cancel)."
	    set ans [::UI::MessageBox -icon warning -title [mc Unregister] \
	      -type yesnocancel -default no -message $msg]
	    if {$ans eq "cancel"} {
		return
	    } elseif {$ans eq "yes"} {
		::Roster::RemoveUsers $jidlist
	    }
	}
    }
    
    if {$ans eq "yes"} {
	
	# Do we need to obtain a key for this???
	$jstate(jlib) register_remove $jid  \
	  [list ::Register::RemoveCallback $jid]
	
	# Remove also from our profile if our login account.
	if {$jid eq $jserver(this)} {
	    set profile [::Profiles::FindProfileNameFromJID $jstate(mejid)]
	    if {$profile ne ""} {
		::Profiles::Remove $profile
	    }
	}
    }
}

proc ::Register::Noop {args} {
    # empty
}

proc ::Register::RemoveCallback {jid jlibName type theQuery} {
    
    if {[string equal $type "error"]} {
	lassign $theQuery errcode errmsg
	::UI::MessageBox -icon error -title [mc Unregister] -type ok  \
	  -message [mc jamesserrunreg $jid $errcode $errmsg]
    } else {
	::UI::MessageBox -icon info -title [mc Unregister] -type ok  \
	  -message [mc jamessokunreg $jid]
    }
}

#--- Using iq-get --------------------------------------------------------------

namespace eval ::RegisterEx:: {

    variable uid 0
    
    variable help
    array set help {
	username        "Account name associated with the user"
	nick            "Familiar name of the user"
	password        "Password or secret for the user"
	name            "Full name of the user"
	first           "First name or given name of the user"
	last            "Last name, surname, or family name of the user"
	email           "Email address of the user"
	address         "Street portion of a physical or mailing address"
	city            "Locality portion of a physical or mailing address"
	state           "Region portion of a physical or mailing address"
	zip             "Postal code portion of a physical or mailing address"
	phone           "Telephone number of the user"
	url             "URL to web page describing the user"
	date            "Some date (e.g., birth date, hire date, sign-up date)"
    }
    
    set ::config(registerex,server)  ""
    set ::config(registerex,autoget) 0
    
    # Allow only a single instance of this dialog.
    variable win $::wDlgs(jreg)_ibr
}

# RegisterEx::New --
# 
#       Register with server using iq-get.
#       It shall ONLY be used to do in-band registration of new accounts,
#       NOT for general service registration! 
#       
# Arguments:
#       args:   -server
#               -username
#               -password
#               -autoget
#       
# Results:
#       none

proc ::RegisterEx::New {args} {
    global  this wDlgs config
    
    variable uid
    variable win
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::RegisterEx::New args=$args"
    
    if {[winfo exists $win]} {
	raise $win
	return
    }
        
    # State variable to collect instance specific variables.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
	
    #set w $wDlgs(jreg)[incr uid]
    set w $win
    set state(w) $w
    array set state {
	finished  -1
	-autoget   0
	-server    ""
    }
    array set state $args
    
    # Let any config override any options.
    if {$config(registerex,server) ne ""} {
	set state(-server) $config(registerex,server)
    }
    if {$config(registerex,autoget)} {
	set state(-autoget) $config(registerex,autoget)
    }
    if {[info exists state(-password)]} {
	set state(-password2) $state(-password)
    }

    ::UI::Toplevel $w -class JRegister \
      -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox} \
      -closecommand [list [namespace current]::CloseCmd $token]
    wm title $w [mc {Register New Account}]
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jreg)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jreg)
    }

    set im   [::Theme::GetImage [option get $w registerImage {}]]
    set imd  [::Theme::GetImage [option get $w registerDisImage {}]]
	
    # Global frame.
    ttk::frame $w.frall
    pack  $w.frall  -fill x
    
    ttk::label $w.frall.head -style Headlabel \
      -text [mc {New Account}] -compound left \
      -image [list $im background $imd]
    pack  $w.frall.head  -side top -fill both -expand 1

    ttk::separator $w.frall.s -orient horizontal
    pack  $w.frall.s  -side top -fill x

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack  $wbox  -fill both -expand 1

    if {$state(-server) ne ""} {
	set str [mc jaregisterexserv $state(-server)]
    } else {
	set str [mc jaregisterex]
    }
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 320 -justify left -anchor w -text $str
    pack  $wbox.msg  -side top -fill x
    
    # Entries etc.
    set frmid $wbox.frmid
    ttk::frame $frmid
    pack  $frmid  -side top -fill both -expand 1

    ttk::label $frmid.lserv -text "[mc {Jabber Server}]:" -anchor e
    ttk::entry $frmid.eserv -width 22    \
      -textvariable $token\(-server) -validate key  \
      -validatecommand {::Jabber::ValidateDomainStr %S}
	
    grid  $frmid.lserv  $frmid.eserv  -sticky e -pady 0
    grid  $frmid.eserv  -sticky ew
    grid columnconfigure $frmid 1 -weight 1

    # Frame to put entries in.
    ttk::frame $wbox.fiq
    pack $wbox.fiq -side top -fill both -expand 1 -pady 1
    
    # More options and chasing arrows.
    set wmore $wbox.more
    ttk::frame $wmore
    ttk::button $wmore.tri -style Small.Toolbutton \
      -compound left -image [::UI::GetIcon mactriangleclosed] \
      -text "[mc More]..." -command [list [namespace current]::MoreOpts $token]
    ::chasearrows::chasearrows $wmore.arr -size 16
    ttk::label $wmore.ls -style Small.TLabel \
      -textvariable $token\(status)
    ttk::frame $wmore.fmore

    grid  $wmore.tri  $wmore.arr  $wmore.ls  -sticky w
    grid columnconfigure $wmore 2 -weight 1
    pack  $wmore  -side top -anchor w -fill x -padx 0 -pady 0

    # Tabbed notebook for more options.
    set tokenOpts ${token}opts
    set wtabnb $wmore.fmore.nb
    ::Profiles::NotebookOptionWidget $wtabnb $tokenOpts
    pack $wtabnb
    
    set state(tokenOpts) $tokenOpts

    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Get] -default active \
      -command [list [namespace current]::Get $token]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::Cancel $token]
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
    
    set state(wbtok)   $frbot.btok
    set state(wprog)   $wmore.arr
    set state(wfriq)   $wbox.fiq
    set state(wserv)   $frmid.eserv
    set state(wtri)    $wmore.tri
    set state(wfmore)  $wmore.fmore
    set state(wtabnb)  $wtabnb
    
    # Grab and focus.
    set oldFocus [focus]
    focus $frmid.eserv
    ::UI::Grab $w
    
    if {$state(-server) ne ""} {
	$state(wserv) state {disabled}
    }
    if {$state(-autoget)} {
	$state(wbtok) invoke
    }
    
    # Wait here for a button press and window to be destroyed.
    tkwait variable $token\(finished)
    
    ::Jabber::UI::SetStatusMessage ""
    ::Jabber::UI::StartStopAnimatedWave 0

    ::UI::SaveWinPrefixGeom $wDlgs(jreg)
    ::UI::GrabRelease $w
    catch {focus $oldFocus}
    catch {destroy $state(w)}
    Free $token
}

# Not used for the moment due to the grab stuff.

proc ::RegisterEx::BrowseServers {token} {
    
    ::JPubServers::New [list [namespace current]::ServersCmd $token]
}

proc ::RegisterEx::ServersCmd {token _server} {
    variable $token
    upvar 0 $token state
    
    set state(-server) $_server
}

#---

proc ::RegisterEx::Cancel {token} {
    variable $token
    upvar 0 $token state
    
    set state(finished) 0
    ::Jabber::DoCloseClientConnection
}

proc ::RegisterEx::CloseCmd {token w} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    
    ::Debug 2 "::RegisterEx::CloseCmd"
    
    ::UI::SaveWinPrefixGeom $wDlgs(jreg)
    set state(finished) 0
    ::Jabber::DoCloseClientConnection
    return stop
}

proc ::RegisterEx::Free {token} {
    
    unset -nocomplain $token
}

proc ::RegisterEx::MoreOpts {token} {
    variable $token
    upvar 0 $token state
      
    grid  $state(wfmore)  -  -  -sticky ew
    $state(wtri) configure -image [::UI::GetIcon mactriangleopen] \
      -text "[mc Less]..." -command [list [namespace current]::LessOpts $token]
}

proc ::RegisterEx::LessOpts {token} {
    variable $token
    upvar 0 $token state
    
    grid remove $state(wfmore)
    $state(wtri) configure -image [::UI::GetIcon mactriangleclosed] \
      -text "[mc More]..." -command [list [namespace current]::MoreOpts $token]
}

proc ::RegisterEx::NotBusy {token} {
    variable $token
    upvar 0 $token state
    
    SetState $token !disabled
    $state(wprog) stop
    set state(status) ""
    ::Jabber::UI::SetStatusMessage ""
    ::Jabber::UI::StartStopAnimatedWave 0
}

proc ::RegisterEx::SetState {token theState} {
    variable $token
    upvar 0 $token state
    
    if {[winfo exists $state(wserv)]} {
	$state(wserv)  state $theState
	$state(wbtok)  state $theState
	# @@@ Triangle ?
    }
}

proc ::RegisterEx::Get {token} {
    variable $token
    upvar 0 $token state
    
    ::Debug 2 "::RegisterEx::Get"
    
    # Kill any pending open states.
    ::Network::KillAll
    ::Jabber::UI::SetStatusMessage ""
    ::Jabber::UI::StartStopAnimatedWave 0
    
    # Verify.
    if {$state(-server) eq ""} {
	::UI::MessageBox -type ok -icon error  \
	  -message [mc jamessregnoserver]
	return
    }	
    # This is just to check the validity!
    if {[catch {jlib::nameprep $state(-server)} err]} {
	::UI::MessageBox -icon error -type ok \
	  -message [mc jamessillegalchar "server" $state(-server)]
	return
    }
    SetState $token disabled
    set state(status) [mc jawaitserver]
    $state(wprog) start

    set opts {}
    set tokenOpts $state(tokenOpts)
    foreach {key value} [array get $tokenOpts] {
	# ssl vs. tls naming conflict.
	if {$key eq "ssl"} {
	    set key "tls"
	}
	lappend opts -$key $value
    }

    # Asks for a socket to the server.
    eval {::Login::Connect $state(-server) \
      [list [namespace current]::ConnectCB $token]} $opts

}

proc ::RegisterEx::ConnectCB {token status msg} {
    variable $token
    upvar 0 $token state

    ::Debug 2 "::RegisterEx::ConnectCB status=$status"
    
    if {![info exists state]} {
	return
    }
    switch $status {
	error {
	    NotBusy $token
	    ::UI::MessageBox -icon error -type ok \
	      -message [mc jamessnosocket $state(-server) $msg]
	}
	timeout {
	    NotBusy $token
	    ::UI::MessageBox -icon error -type ok \
	      -message [mc jamesstimeoutserver $state(-server)]
	}
	default {
	    # Go ahead...
	    if {[catch {
		::Login::InitStream $state(-server) \
		  [list [namespace current]::StreamCB $token]
	    } err]} {
		NotBusy $token
		::UI::MessageBox -icon error -title [mc {Open Failed}] \
		  -type ok -message $err
	    }
	}
    }
}

proc ::RegisterEx::StreamCB {token args} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::RegisterEx::StreamCB args=$args"

    if {![info exists state]} {
	return
    }

    # The stream attributes. id is needed if trying to logon.
    foreach {name value} $args {
	set state(stream,$name) $value
    }

    # Send get register.
    $jstate(jlib) register_get [list [namespace current]::GetCB $token] \
      -to $state(-server)
}

proc ::RegisterEx::GetCB {token jlibName type iqchild} {    
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate

    variable help

    ::Debug 2 "::RegisterEx::GetCB type=$type, iqchild=$iqchild"

    if {![info exists state]} {
	return
    }
    NotBusy $token
    SetState $token disabled
    if {!([info exists state(w)] && [winfo exists $state(w)])} {
	return
    }
    
    if {[string equal $type "error"]} {
	::UI::MessageBox -type ok -icon error  \
	  -message [mc jamesserrregget [lindex $subiq 0] [lindex $subiq 1]]
	return
    } 
    
    $state(wbtok) configure -state normal -text [mc Register] \
      -command [list [namespace current]::SendRegister $token]
    
    # Extract registration tags.
    foreach elem [wrapper::getchildren $iqchild] {
	set tag [wrapper::gettag $elem]
	if {$tag ne "x"} {
	    set data($tag) [wrapper::getcdata $elem]
	}
    }
    set wfr $state(wfriq)

    # Build UI. Try to put them in a reasonable order.
    set isRegistered 0
    if {[info exists data(registered)]} {
	unset data(registered)
	set isRegistered 1
    }
    if {[info exists data(instructions)]} {
	ttk::label $wfr.instr -style Small.TLabel \
	  -wraplength 260 -text $data(instructions) \
	  -justify left -anchor w
	grid  $wfr.instr  -  -sticky ew
    }

    foreach tag {username password} {
	if {[info exists data($tag)]} {
	    set str "[mc [string totitle $tag]]:"
	    if {[info exists state(-$tag)]} {
		set state(elem,$tag) $state(-$tag)		
	    } else {
		set state(elem,$tag) ""
	    }
	    ttk::label $wfr.l$tag -text $str -anchor e
	    if {$tag eq "username"} {
		ttk::entry $wfr.e$tag  -textvariable $token\(elem,$tag) \
		  -validate key -validatecommand {::Jabber::ValidateUsernameStr %S}
	    } elseif {$tag eq "password"} {
		ttk::entry $wfr.e$tag -textvariable $token\(elem,$tag) \
		  -show {*} -validate key  \
		  -validatecommand {::Jabber::ValidatePasswordStr %S}
	    } else {
		ttk::entry $wfr.e$tag -textvariable $token\(elem,$tag)
	    }
	    grid  $wfr.l$tag  $wfr.e$tag  -sticky e -pady 2
	    grid  $wfr.e$tag  -sticky ew
	    if {$tag eq "password"} {
		set str "[mc {Retype password}]:"
		if {[info exists state(-password)]} {
		    set state(elem,${tag}2) $state(-password)
		} else {
		    set state(elem,${tag}2) ""
		}
		ttk::label $wfr.l2$tag -text $str -anchor e
		ttk::entry $wfr.e2$tag -textvariable $token\(elem,${tag}2) \
		  -show {*} -validate key  \
		  -validatecommand {::Jabber::ValidatePasswordStr %S}
		grid  $wfr.l2$tag  $wfr.e2$tag  -sticky e -pady 2
		grid  $wfr.e2$tag  -sticky ew
		if {[info exists state(-password)]} {
		    $wfr.e2$tag state {disabled}
		}
	    }
	    if {[info exists state(-$tag)]} {
		$wfr.e$tag state {disabled}
	    }
	    if {[info exists help($tag)]} {
		::balloonhelp::balloonforwindow $wfr.l$tag $help($tag)
		::balloonhelp::balloonforwindow $wfr.e$tag $help($tag)
	    }
	}
    }
    
    unset -nocomplain data(username) data(instructions) data(password)
    
    foreach {tag chdata} [array get data] {
	set str "[mc [string totitle $tag]]:"
	set state(elem,$tag) ""
	ttk::label $wfr.l$tag -text $str -anchor e
	ttk::entry $wfr.e$tag -textvariable $token\(elem,$tag)
	grid  $wfr.l$tag  $wfr.e$tag  -sticky e -pady 2
	grid  $wfr.e$tag  -sticky ew
	if {[info exists help($tag)]} {
	    ::balloonhelp::balloonforwindow $wfr.l$tag $help($tag)
	    ::balloonhelp::balloonforwindow $wfr.e$tag $help($tag)
	}
    }
    if {$isRegistered} {
	set str "You are already registered with this service.\
	  These are your current settings of your login parameters."
	ttk::label $wfr.lregistered -text $str -anchor w \
	  -wraplength 260 -justify left
	grid  $wfr.lregistered  -sticky ew
    }
    grid columnconfigure $wfr 1 -weight 1
    
    catch {focus $wfr.eusername}
}

proc ::RegisterEx::SendRegister {token} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate

    # Error checking.
    if {[info exists state(elem,password)]} {
	if {$state(elem,password) ne $state(elem,password2)} {
	    ::UI::MessageBox -icon error -title [mc {Different Passwords}] \
	      -message [mc messpasswddifferent] -parent $state(w)
	    set state(elem,password)  ""
	    set state(elem,password2) ""
	    return
	}
    }
    
    # Collect relevant elements.
    set sub {}
    foreach {key value} [array get state elem,*] {
	if {$value eq ""} {
	    continue
	}
	set tag [string map {elem, ""} $key]
	
	switch -- $tag {
	    instructions - registered - password2 {
		# empty.
	    }
	    default {
		lappend sub [wrapper::createtag $tag -chdata $value]
	    }
	}
    }
    
    # We need to do it the crude way.
    set queryElem [wrapper::createtag "query" \
      -attrlist {xmlns jabber:iq:register} -subtags $sub]
    $jstate(jlib) send_iq "set" [list $queryElem] \
      -to $state(-server) \
      -command [list [namespace current]::SendRegisterCB $token]
}

proc ::RegisterEx::SendRegisterCB {token type theQuery} {    
    variable $token
    upvar 0 $token state

    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::RegisterEx::SendRegisterCB type=$type, theQuery=$theQuery"
    
    if {![info exists state]} {
	return
    }
    set server   $state(-server)
    set username $state(elem,username)
    set password $state(elem,password)

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
	NotBusy $token
    } else {
	
	# Save to our jserver variable. Create a new profile.
	::Profiles::Set {} $server $username $password

	if {$jprefs(logonWhenRegister)} {
	    
	    if {![info exists state(stream,id)]} {
		::UI::MessageBox -icon error -type ok -message \
		  "no id for digest in receiving <stream>"
		return
	    }
	    
	    # Go on and authenticate.
	    # @@@ extra options?
	    set resource "coccinella"
	    ::Login::Authorize $server $username $resource $password \
	      [namespace current]::AuthorizeCB \
	      -streamid $state(stream,id) \
	      -digest 1
	} else {
	    ::UI::MessageBox -icon info -type ok \
	      -message [mc jamessregisterok $server]
	
	    # Disconnect. This should reset both wrapper and XML parser!
	    # Beware: we are in the middle of a callback from the xml parser,
	    # and need to be sure to exit from it before resetting!
	    after idle $jstate(jlib) closestream
	}
	
	# Kill dialog.
	set state(finished) 1
    }
}

proc ::RegisterEx::AuthorizeCB {type msg} {
    
    ::Debug 2 "::RegisterEx::AuthorizeCB type=$type"
    
    if {[string equal $type "error"]} {
	::UI::MessageBox -icon error -type ok -title [mc Error]  \
	  -message $msg
    } else {
	
	# Login was succesful, set presence.
	::Login::SetStatus
	set jid [::Jabber::GetMyJid]
	::UI::MessageBox -icon info -type ok -message [mc jamessregloginok $jid]
    }
}

# The ::GenRegister:: namespace -----------------------------------------

namespace eval ::GenRegister:: {

    variable uid 0
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
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::GenRegister::NewDlg args=$args"
    
    # Initialize the state variable, an array.    
    set token [namespace current]::dlg[incr uid]
    variable $token
    upvar 0 $token state

    array set argsArr $args

    set w $wDlgs(jreg)${uid}
    set state(w)          $w
    set state(finished)   -1
    set state(args)       $args
    set state(server)     ""
    set state(wraplength) 300
    
    ::UI::Toplevel $w -class JRegister -macstyle documentProc -usemacmainmenu 1 \
      -closecommand [list [namespace current]::CloseCmd $token] \
      -macclass {document closeBox}
    wm title $w [mc {Register Service}]
    set wtop $w
    
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jreg)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jreg)
    }

    set im   [::Theme::GetImage [option get $w registerImage {}]]
    set imd  [::Theme::GetImage [option get $w registerDisImage {}]]

    # Global frame.
    set wall $w.fr
    ttk::frame $wall
    pack $wall -fill x
    
    ttk::label $wall.head -style Headlabel \
      -text [mc {Register Service}] -compound left \
      -image [list $im background $imd]
    pack $wall.head -side top -fill both

    ttk::separator $wall.s -orient horizontal
    pack $wall.s -side top -fill x

    set wbox $wall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength $state(wraplength) \
      -text [mc jaregmsg] -justify left
    pack $wbox.msg -side top -anchor w
    
    set frserv $wbox.serv
    ttk::frame $frserv
    ttk::label $frserv.lserv -text "[mc {Service server}]:"
    
    # Get all (browsed) services that support registration.
    set regServers [$jstate(jlib) disco getjidsforfeature "jabber:iq:register"]
    set wcomboserver $frserv.eserv
    ttk::combobox $wcomboserver -state readonly  \
      -textvariable $token\(server) -values $regServers
    
    # Find the default registration server.
    if {$regServers != {}} {
	set state(server) [lindex $regServers 0]
    }
    if {[info exists argsArr(-server)]} {
	set state(server) $argsArr(-server)
	$wcomboserver state {disabled}
    }
    pack $frserv -side top -anchor w -fill x
    pack $frserv.lserv -side left
    pack $wcomboserver -fill x -expand 1
    
    # Button part.
    set frbot       $wbox.b
    set wbtregister $frbot.btenter
    set wbtget      $frbot.btget
    set wbtcancel   $frbot.btcancel
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $wbtget -text [mc Get] -default active \
      -command [list [namespace current]::Get $token]
    ttk::button $wbtregister -text [mc Register] -state disabled \
      -command [list [namespace current]::DoRegister $token]
    ttk::button $wbtcancel -text [mc Cancel]  \
      -command [list [namespace current]::Cancel $token]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $wbtget -side right
	pack $wbtregister -side right -padx $padx
	pack $wbtcancel -side right
    } else {
	pack $wbtcancel -side right
	pack $wbtget -side right -padx $padx
	pack $wbtregister -side right
    }
    pack $frbot -side bottom -fill x
    
    # Running arrows and status message.
    set wstat $wbox.fs
    ttk::frame $wstat
    set wsearrows $wstat.arr
    ::chasearrows::chasearrows $wsearrows -size 16
    ttk::label $wstat.lstat -style Small.TLabel \
      -textvariable $token\(stattxt)
    
    pack  $wstat        -side bottom -anchor w -fill x
    pack  $wsearrows    -side left
    pack  $wstat.lstat  -side left -padx 12
    
    # This part must be built dynamically from the 'get' xml data.
    # May be different for each conference server.

    # Not same wbox as above!!!
    set wform $wbox.form
    
    set state(stattxt)      [mc jasearchwait]
    set state(wcomboserver) $wcomboserver
    set state(wform)        $wform
    set state(wsearrows)    $wsearrows
    set state(wbtregister)  $wbtregister
    set state(wbtget)       $wbtget

    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 30]
	wm minsize %s [winfo reqwidth %s] 300
    } $wbox.msg $w $w $w]    
    #after idle $script

    if {[info exists argsArr(-autoget)] && $argsArr(-autoget)} {
	after idle [list [namespace current]::Get $token]
    }
    wm resizable $w 0 0
    
    return
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
    $state(wcomboserver) state disabled
    $state(wbtget)       state disabled
    set state(stattxt) [mc jawaitserver]
    
    # Send get register.
    $jstate(jlib) register_get [list ::GenRegister::GetCB $token] \
      -to $state(server)
    $state(wsearrows) start
}

proc ::GenRegister::GetCB {token jlibName type subiq} {    
    variable $token
    upvar 0 $token state
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
    set wform $state(wform)
    set childs [wrapper::getchildren $subiq]

    set state(stattxt) ""
    if {[winfo exists $wform]} {
	destroy $wform
    }
    set formtoken [::JForms::Build $wform $subiq -tilestyle Mixed \
      -width $state(wraplength)]
    pack $wform -fill x -expand 1
    set state(formtoken) $formtoken
    
    $state(wbtregister) configure -default active
    $state(wbtget)      configure -default disabled    
    $state(wbtregister) state !disabled
    $state(wbtget)      state !disabled
}

proc ::GenRegister::DoRegister {token} {   
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    if {!([info exists state(w)] && [winfo exists $state(w)])} {
	return
    }
    $state(wsearrows) start
    
    set subelements [::JForms::GetXML $state(formtoken)]
    
    # We need to do it the crude way.
    $jstate(jlib) send_iq "set"  \
      [list [wrapper::createtag "query" \
      -attrlist {xmlns jabber:iq:register} -subtags $subelements]] \
      -to $state(server) \
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
    variable server ""
    variable finished -1
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::GenRegister::Simple"
    if {[winfo exists $w]} {
	return
    }
    array set argsArr $args
    
    ::UI::Toplevel $w -class JRegister -macstyle documentProc \
      -usemacmainmenu 1 -macclass {document closeBox}
    wm title $w [mc {Register Service}]
    set wtop $w
 
    set im   [::Theme::GetImage [option get $w registerImage {}]]
    set imd  [::Theme::GetImage [option get $w registerDisImage {}]]

    # Global frame.
    set wall $w.fr
    ttk::frame $wall
    pack $wall -fill x

    ttk::label $wall.head -style Headlabel \
      -text [mc {Register Service}] -compound left \
      -image [list $im background $imd]
    pack $wall.head -side top -fill both

    ttk::separator $wall.s -orient horizontal
    pack $wall.s -side top -fill x
    
    set wbox $wall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 300 -justify left -text [mc jaregmsg]
    pack $wbox.msg -side top -anchor w

    set wmid $wbox.m
    ttk::frame $wmid
    pack $wmid -side top -fill both -expand 1
    
    set regServers [::Jabber::JlibCmd disco getjidsforfeature "jabber:iq:register"]

    ttk::label $wmid.lserv -text "[mc {Service server}]:"
    ttk::combobox $wmid.combo -state readonly  \
      -textvariable [namespace current]::server -values $regServers    
    ttk::label $wmid.luser -text "[mc Username]:" -anchor e
    ttk::entry $wmid.euser  \
      -textvariable [namespace current]::username -validate key  \
      -validatecommand {::Jabber::ValidateUsernameStr %S}
    ttk::label $wmid.lpass -text "[mc Password]:" -anchor e
    ttk::entry $wmid.epass  \
      -textvariable [namespace current]::password -validate key \
      -validatecommand {::Jabber::ValidatePasswordStr %S}
    
    grid  $wmid.lserv  $wmid.combo  -pady 2
    grid  $wmid.luser  $wmid.euser  -pady 2
    grid  $wmid.lpass  $wmid.epass  -pady 2
    grid  $wmid.luser  $wmid.lpass  -pady 2
    
    grid  $wmid.combo  $wmid.euser  $wmid.epass  $wmid.lpass  -sticky ew

    if {$regServers != {}} {
	set server [lindex $regServers 0]
    }
    if {[info exists argsArr(-server)]} {
	set server $argsArr(-server)
	$wmid.combo state disabled
    }

    # Button part.
    set frbot       $wbox.b
    set wbtregister $frbot.btenter
    set wbtcancel   $frbot.btcancel
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $wbtregister -text [mc Register] \
      -default active -command [namespace current]::DoSimple
    ttk::button $wbtcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelSimple $w]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $wbtregister -side right
	pack $wbtcancel -side right -padx $padx
    } else {
	pack $wbtcancel -side right
	pack $wbtregister -side right -padx $padx
    }
    pack $frbot -side top -fill x

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
