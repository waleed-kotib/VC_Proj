#  Register.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the registration UI parts for jabber.
#      
#  Copyright (c) 2001-2007  Mats Bengtsson
#
# $Id: Register.tcl,v 1.68 2007-07-09 12:55:45 matben Exp $

package provide Register 1.0

namespace eval ::Register:: {

    option add *JRegister.registerImage         register         widgetDefault
    option add *JRegister.registerDisImage      registerDis      widgetDefault
}

proc ::Register::ValidatePortNumber {str} {    
    if {[string is integer $str]} {
	return 1
    } else {
	bell
	return 0
    }
}

proc ::Register::OnMenuRemove {} {
    if {[llength [grab current]]} { return }
    if {[::JUI::GetConnectState] eq "connectfin"} {
	::Register::Remove
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

    ::Debug 2 "::Register::Remove jid=$jid"
    
    set ans "yes"
    if {$jid eq ""} {
	set jid $jstate(server)
	set ans [::UI::MessageBox -icon warning -title [mc Unregister] \
	  -type yesno -default no -message [mc jamessremoveaccount]]
    } else {
	set jidlist [::Roster::GetUsersWithSameHost $jid]
	if {[llength $jidlist]} {
	    set ans [::UI::MessageBox -icon warning -title [mc Unregister] \
	      -type yesnocancel -default no -message [mc register-trpt-unreg]]
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
	if {[jlib::jidequal $jid $jstate(server)]} {
	    set profile [::Profiles::FindProfileNameFromJID $jstate(mejid)]
	    if {$profile ne ""} {
		::Profiles::Remove $profile
	    }
	}
    }
}

proc ::Register::RemoveCallback {jid jlibName type theQuery} {
    
    upvar ::Jabber::jstate jstate

    if {[string equal $type "error"]} {
	lassign $theQuery errcode errmsg
	ui::dialog -icon error -title [mc Unregister] -type ok  \
	  -message [mc jamesserrunreg $jid $errcode $errmsg]
    } else {
	
	# If we don't do this the server may shut us down instead.
	if {[jlib::jidequal $jid $jstate(server)]} {
	    ::Jabber::DoCloseClientConnection
	}
	ui::dialog -icon info -title [mc Unregister] -type ok  \
	  -message [mc jamessokunreg $jid]
    }
}

#--- Using iq-get --------------------------------------------------------------

namespace eval ::RegisterEx:: {

    variable uid 0
        
    set ::config(registerex,server)           ""
    set ::config(registerex,autoget)          0
    set ::config(registerex,autologin)        1
    set ::config(registerex,savepassword)     1
    
    # Allow only a single instance of this dialog.
    variable win $::wDlgs(jreg)_ibr
}

# This section is actually support for XEP-0077: In-Band Registration 

proc ::RegisterEx::OnMenu {} {
    if {[llength [grab current]]} { return }
    if {[::JUI::GetConnectState] eq "disconnect"} {
	New
    }    
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
#               -publicservers
#       
# Results:
#       w

proc ::RegisterEx::New {args} {
    global  this wDlgs config
    
    variable uid
    variable win
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::RegisterEx::New args=$args"
    
    # Singleton. IMPORTANT! SInce we cannot have multiple connections.
    if {[winfo exists $win]} {
	raise $win
	return
    }
        
    # State variable to collect instance specific variables.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
	
    set w $win
    set state(w) $w
    array set state {
	finished  -1
	-autoget   0
	-server    ""
	-publicservers 1
    }
    array set state $args
    
    set state(savepassword) $config(registerex,savepassword)
    
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
    #ttk::entry $frmid.eserv -width 22    \
    #  -textvariable $token\(-server) -validate key  \
    #  -validatecommand {::Jabber::ValidateDomainStr %S}
    ttk::combobox $frmid.eserv -width 22    \
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
    if {0} {
	ttk::button $wmore.tri -style Small.Toolbutton \
	  -compound left -image [::UI::GetIcon mactriangleclosed] \
	  -text "[mc More]..." -command [list [namespace current]::MoreOpts $token]
    } elseif {1} {
	ttk::button $wmore.tri -style Small.Plain -padding {6 1} \
	  -compound left -image [::UI::GetIcon closeAqua] \
	  -text "[mc More]..." -command [list [namespace current]::MoreOpts $token]
    } else {
	ttk::checkbutton $wmore.tri -style Arrow.TCheckbutton \
	    -command [list [namespace current]::MoreOpts $token]
    }
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
    if {$state(-publicservers)} {
	catch {
	    ::httpex::get $jprefs(urlServersList) \
	      -command  [list [namespace current]::HttpCommand $token]
	} state(httptoken)
    }
    
    ::Jabber::JlibCmd connect configure \
      -defaultresource [::Profiles::MachineResource]
    
    # Wait here for a button press and window to be destroyed.
    tkwait variable $token\(finished)
    
    ::JUI::SetStatusMessage ""
    ::JUI::StartStopAnimatedWave 0

    ::UI::SaveWinPrefixGeom $wDlgs(jreg)
    ::UI::GrabRelease $w
    catch {focus $oldFocus}
    catch {destroy $state(w)}
    Free $token
    
    return $w
}

proc ::RegisterEx::HttpCommand {token htoken} {
    variable $token
    upvar 0 $token state
    
    if {[::httpex::state $htoken] ne "final"} {
	return
    }
    if {[::httpex::status $htoken] eq "ok"} {
	
	# Get and parse xml.
	set xml [::httpex::data $htoken]    
	set xtoken [tinydom::parse $xml -package qdxml]
	set xmllist [tinydom::documentElement $xtoken]
	set jidL [list]
	
	foreach elem [tinydom::children $xmllist] {
	    switch -- [tinydom::tagname $elem] {
		item {
		    unset -nocomplain attrArr
		    array set attrArr [tinydom::attrlist $elem]
		    if {[info exists attrArr(jid)]} {
			lappend jidL [list $attrArr(jid)]
		    }
		}
	    }
	}
	if {[winfo exists $state(wserv)]} {
	    $state(wserv) configure -values $jidL
	}
	tinydom::cleanup $xtoken
    }
    ::httpex::cleanup $htoken
    unset -nocomplain state(httptoken)
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
    variable $token
    upvar 0 $token state
 
    if {[info exists state(httptoken)]} {
	catch {::httpex::reset $state(httptoken)}
    }
    unset -nocomplain $token
}

proc ::RegisterEx::MoreOpts {token} {
    variable $token
    upvar 0 $token state
      
    grid  $state(wfmore)  -  -  -sticky ew
    $state(wtri) configure -image [::UI::GetIcon openAqua] \
      -text "[mc Less]..." -command [list [namespace current]::LessOpts $token]
}

proc ::RegisterEx::LessOpts {token} {
    variable $token
    upvar 0 $token state
    
    grid remove $state(wfmore)
    $state(wtri) configure -image [::UI::GetIcon closeAqua] \
      -text "[mc More]..." -command [list [namespace current]::MoreOpts $token]
}

proc ::RegisterEx::NotBusy {token} {
    variable $token
    upvar 0 $token state
    
    SetState $token !disabled
    $state(wprog) stop
    set state(status) ""
    ::JUI::SetStatusMessage ""
    ::JUI::StartStopAnimatedWave 0
}

proc ::RegisterEx::SetState {token theState} {
    variable $token
    upvar 0 $token state
    
    if {[winfo exists $state(wserv)]} {
	$state(wserv)  state $theState
	$state(wbtok)  state $theState
	::Profiles::NotebookSetAllState $state(wtabnb) $theState
    }
}

proc ::RegisterEx::Get {token} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::RegisterEx::Get"
    
    # Kill any pending open states.
    ::Login::Reset
    
    # Verify.
    if {$state(-server) eq ""} {
	::UI::MessageBox -type ok -icon error -message [mc jamessregnoserver]
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

    set opts [list -noauth 1]
    set tokenOpts $state(tokenOpts)
    foreach {key value} [array get $tokenOpts] {
	# ssl vs. tls naming conflict.
	if {$key eq "ssl"} {
	    set key "tls"
	}
	lappend opts -$key $value
    }

    # Asks for a socket to the server.
    set cb [list ::RegisterEx::ConnectCB $token]
    eval {$jstate(jlib) connect connect $state(-server) {} -command $cb} $opts
}

proc ::RegisterEx::ConnectCB {token jlibname status {errcode ""} {errmsg ""}} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::RegisterEx::ConnectCB status=$status, errcode=$errcode, errmsg=$errmsg"
    
    if {![info exists state]} {
	return
    }
    if {$status eq "ok"} {
	$jstate(jlib) register_get [list [namespace current]::GetCB $token] \
	  -to $state(-server)
    } elseif {$status eq "error"} {
	NotBusy $token
	set str [::Login::GetErrorStr $errcode $errmsg]
	::UI::MessageBox -icon error -type ok -message $str
	$jstate(jlib) connect free
    }
}

proc ::RegisterEx::GetCB {token jlibName type iqchild} {    
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate

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
	  -message [mc jamesserrregget [lindex $iqchild 0] [lindex $iqchild 1]]
	return
    } 
    
    $state(wbtok) state {!disabled}
    $state(wbtok) configure -text [mc Register] \
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
		set str "[mc {Retype Password}]:"
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
	    set help [mc registration-$tag]
	    if {$help ne "registration-$tag"} {
		::balloonhelp::balloonforwindow $wfr.l$tag $help
		::balloonhelp::balloonforwindow $wfr.e$tag $help
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

	set help [mc registration-$tag]
	if {$help ne "registration-$tag"} {
	    ::balloonhelp::balloonforwindow $wfr.l$tag $help
	    ::balloonhelp::balloonforwindow $wfr.e$tag $help
	}
    }

    ttk::checkbutton $wfr.csavepw -style Small.TCheckbutton  \
      -text [mc {Save password}] -variable $token\(savepassword)
    grid  x  $wfr.csavepw  -sticky w

    if {$isRegistered} {
	ttk::label $wfr.lregistered -text [mc registration-is-registered]  \
	  -anchor w -wraplength 260 -justify left
	grid  $wfr.lregistered  -  -sticky ew
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
    global  config
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
    set resource [::Profiles::MachineResource]

    if {[string equal $type "error"]} {
	set errcode [lindex $theQuery 0]
	set errmsg [lindex $theQuery 1]
	if {$errcode == 409} {
	    set msg [mc jamessregerrinuse $errmsg]
	} else {
	    set msg [mc jamessregerr $errmsg]
	}
	::UI::MessageBox -title [mc Error] -icon error -type ok -message $msg
	NotBusy $token
    } else {
	
	# Create a new profile.
	if {$state(savepassword)} {
	    ::Profiles::Set {} $server $username $password	    
	} else {
	    ::Profiles::Set {} $server $username {}
	}
	if {$config(registerex,autologin)} {
	    
	    # Go on and authenticate.
	    set jid [jlib::joinjid $username $server $resource]
	    $jstate(jlib) connect register $jid $password
	    $jstate(jlib) connect auth -command [namespace code AuthCB]
	} else {
	    ui::dialog -icon info -type ok \
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

proc ::RegisterEx::AuthCB {jlibname status {errcode ""} {errmsg ""}} {
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::RegisterEx::AuthCB status=$status, errcode=$errcode, errmsg=$errmsg"
    
    switch -- $status {
	ok {
	
	    # Login was succesful.
	    ::Login::SetLoginStateRunHook
	    ::JUI::FixUIWhen "connectfin"
	    ::JUI::SetConnectState "connectfin"

	    # Important to send presence *after* we request the roster (loginHook)!
	    ::Login::SetStatus

	    set jid [::Jabber::GetMyJid]
	    ui::dialog -icon info -type ok -message [mc jamessregloginok $jid]
	    $jlibname connect free
	}
	error {
	    set str [mc xmpp-stanzas-short-$errcode]
	    ui::dialog -icon error -type ok -title [mc Error] -message $str
	    $jlibname connect free
	}
	default {
	    # empty since there are intermediate callbacks!
	}
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
#       args   -server
#              -autoget 0/1
#              -serverstate (combobox -state)
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

    set argsA(-serverstate) readonly
    array set argsA $args

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
    ttk::combobox $wcomboserver -state $argsA(-serverstate)  \
      -textvariable $token\(server) -values $regServers
    
    # Find the default registration server.
    if {$regServers != {}} {
	set state(server) [lindex $regServers 0]
    }
    if {[info exists argsA(-server)]} {
	set state(server) $argsA(-server)
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

    if {[info exists argsA(-autoget)] && $argsA(-autoget)} {
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
      -to $state(server) -command [list [namespace current]::ResultCallback $token]

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
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::GenRegister::ResultCallback type=$type, subiq='$subiq'"

    set jid $state(server)

    if {[string equal $type "error"]} {
	::UI::MessageBox -type ok -icon error -message \
	  [mc jamesserrregset $jid [lindex $subiq 0] [lindex $subiq 1]]
    } else {
	::UI::MessageBox -type ok -icon info -message [mc jamessokreg $jid]
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
    array set argsA $args
    
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
    if {[info exists argsA(-server)]} {
	set server $argsA(-server)
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
