#  Register.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the registration UI parts for jabber.
#      
#  Copyright (c) 2001-2008  Mats Bengtsson
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
# $Id: Register.tcl,v 1.111 2008-08-04 13:05:28 matben Exp $

package provide Register 1.0

namespace eval ::Register {

    option add *JRegister.registerImage         services         widgetDefault
    option add *JRegister.registerDisImage      services-Dis     widgetDefault
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
    
    ::Debug 2 "::Register::Remove jid=$jid"
    
    set ans "yes"
    set login 0
    set remove 0
    set server [::Jabber::Jlib getserver]
    
    if {$jid eq ""} {
	set jid $server
	set login 1
    } else {
	if {[jlib::jidequal $server $jid]} {
	    set login 1
	}
    }
    if {$login} {
	# TRANSLATORS: See File in the main window, and then Remove Account...
	set ans [::UI::MessageBox -icon warning -title [mc "Remove Account"] \
	  -type yesno -default no -message [mc "Do you really want to remove your account? This process cannot be undone."]]
	if {$ans eq "yes"} {
	    set remove 1
	}
    } else {
	set jidL [::Roster::GetUsersWithSameHost $jid]
	if {[llength $jidL]} {
	    set ans [::UI::MessageBox -icon warning -title [mc "Warning"] \
	      -type yesnocancel -default no -message [mc "You are about to unregister a transport with a number of dependent contacts. Do you want to remove these contacts as well (Yes), keep them (No), or cancel everything (Cancel)?"]]
	    if {$ans eq "cancel"} {
		return
	    } elseif {$ans eq "yes"} {
		::Roster::RemoveUsers $jidL
	    }
	    set remove 1
	} else {
	    # Can be conference room etc.
	    set remove 1
	}
    }
    
    if {$remove} {
	
	# Do we need to obtain a key for this???
	::Jabber::Jlib register_remove $jid [list ::Register::RemoveCallback $jid]
	
	# Remove also from our profile if our login account.
	if {$login} {
	    set myjid2 [::Jabber::Jlib myjid2]
	    set profile [::Profiles::FindProfileNameFromJID $myjid2]
	    if {$profile ne ""} {
		::Profiles::Remove $profile
	    }
	}
    }
}

proc ::Register::RemoveCallback {jid jlibName type theQuery} {
    
    if {[string equal $type "error"]} {
	lassign $theQuery errcode errmsg
	set str [mc "Cannot unregister from %s." [jlib::unescapejid $jid]]
	append str "\n"
	append str [mc "Error code"]
	append str ": $errcode\n"
	append str [mc "Message"]
	append str ": $errmsg"
	ui::dialog -icon error -title [mc "Error"] -type ok -message $str
    } else {
	
	# If we don't do this the server may shut us down instead.
	set server [::Jabber::Jlib getserver]
	if {[jlib::jidequal $jid $server]} {
	    ::Jabber::DoCloseClientConnection
	}
	set name [::Roster::GetDisplayName $jid]
	ui::dialog -icon info -title [mc "Unregister"] -type ok  \
	  -message [mc "You are unregistered from %s." $name]
    }
}

#--- Using iq-get --------------------------------------------------------------

namespace eval ::RegisterEx {

    variable uid 0
        
    set ::config(registerex,server)           ""
    set ::config(registerex,autoget)          0
    set ::config(registerex,autologin)        1
    set ::config(registerex,savepassword)     1
    set ::config(registerex,show-head)        1
    
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
#               -profile
#       
# Results:
#       w

proc ::RegisterEx::New {args} {
    global  this wDlgs config jprefs
    
    variable uid
    variable win
    
    ::Debug 2 "::RegisterEx::New args=$args"
    
    # Singleton. IMPORTANT! SInce we cannot have multiple connections.
    if {[winfo exists $win]} {
	raise $win
	return
    }
    
    # Avoid any inconsistent UI state by closing any login dialog.
    # This shouldn't happen.
    foreach wlogin [ui::findalltoplevelwithclass JLogin] {
	::Login::Close $wlogin
    }
    
    # State variable to collect instance specific variables.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
	
    set w $win
    set state(w) $w
    array set state {
	finished  -1
	cuid       0
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
    wm title $w [mc "New Account"]
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jreg)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jreg)
    }

    # Global frame.
    ttk::frame $w.frall
    pack  $w.frall  -fill x
    
    if {$config(registerex,show-head)} {
	set im   [::Theme::Find32Icon $w registerImage]
	set imd  [::Theme::Find32Icon $w registerDisImage]
	    
	ttk::label $w.frall.head -style Headlabel \
	  -text [mc "New Account"] -compound left \
	  -image [list $im background $imd]
	pack  $w.frall.head  -side top -fill both -expand 1
	
	ttk::separator $w.frall.s -orient horizontal
	pack  $w.frall.s  -side top -fill x
    }
    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack  $wbox  -fill both -expand 1

    if {$state(-server) ne ""} {
	set str [mc "Register with the service %s. You may need to press the Next button to retrieve the registration instructions." $state(-server)]
    } else {
	set str [mc "Select a server from the list or manually enter one. Then press Next to retrieve the registration instructions. Follow the instructions and hit Register."]
    }
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 320 -justify left -anchor w -text $str
    pack  $wbox.msg  -side top -fill x
    
    # Entries etc.
    set frmid $wbox.frmid
    ttk::frame $frmid
    pack  $frmid  -side top -fill both -expand 1

    set wserv $frmid.eserv
    ttk::label $frmid.lserv -text [mc "Server"]: -anchor e
    ttk::combobox $frmid.eserv -width 22 \
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
	  -text [mc "More"]... -command [list [namespace current]::MoreOpts $token]
    } elseif {0} {
	ttk::button $wmore.tri -style Small.Plain -padding {6 1} \
	  -compound left -image [::UI::GetIcon closeAqua] \
	  -text [mc "More"]... -command [list [namespace current]::MoreOpts $token]
    } else {
	set state(morevar) 0
	set msg "  "
	append msg [mc "More"]...
	ttk::checkbutton $wmore.tri -style ArrowText.TCheckbutton \
	  -onvalue 0 -offvalue 1 -variable $token\(morevar) \
	  -text $msg \
	  -command [list [namespace current]::MoreOpts $token]
    }
    ::UI::ChaseArrows $wmore.arr
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
    ttk::button $frbot.btok -text [mc "Next"] -default active \
      -command [list [namespace current]::Get $token]
    ttk::button $frbot.btcancel -text [mc "Cancel"]  \
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
    
    bind $wserv <Return>  [namespace code [list OnGet $token]]
    bind $w     <Return>  [namespace code [list OnGet $token]]
    
    set state(wbtok)   $frbot.btok
    set state(wprog)   $wmore.arr
    set state(wfriq)   $wbox.fiq
    set state(wserv)   $wserv
    set state(wtri)    $wmore.tri
    set state(wfmore)  $wmore.fmore
    set state(wtabnb)  $wtabnb
    
    # Grab and focus.
    bind $frmid.eserv <Map> { focus %W }
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
    
    jlib::connect::configure -defaultresource [::Profiles::MachineResource]
    
    # Wait here for a button press and window to be destroyed.
    tkwait variable $token\(finished)
    
    ::JUI::SetAppMessage ""

    ::UI::SaveWinPrefixGeom $wDlgs(jreg)
    ::UI::GrabRelease $w
    catch {destroy $state(w)}
    Free $token
    
    return $w
}

proc ::RegisterEx::OnGet {token} {
    Get $token
    
    # Stop tophandler from executing.
    return -code break
}

proc ::RegisterEx::GetTokenFrom {key} {
    
    set ns [namespace current]::
    foreach token [concat  \
      [info vars ${ns}\[0-9\]] \
      [info vars ${ns}\[0-9\]\[0-9\]] \
      [info vars ${ns}\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${ns}\[0-9\]\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${ns}\[0-9\]\[0-9\]\[0-9\]\[0-9\]\[0-9\]]] {
	if {[array exists $token]} {
	    variable $token
	    upvar 0 $token state    
	    if {[info exists state($key)]} {
		return $token   
	    }
	}
    }   
    return
}

proc ::RegisterEx::HttpCommand {token htoken} {
    variable $token
    upvar 0 $token state
        
    if {[::httpex::state $htoken] ne "final"} {
	return
    }
    if {[::httpex::status $htoken] eq "ok"} {
	set ncode [httpex::ncode $htoken]	
	if {$ncode == 200} {
	
	    # Get and parse xml.
	    set xml [::httpex::data $htoken]    
	    set xtoken [tinydom::parse $xml -package xml]
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
	} elseif {$ncode == 301} {
	    
	    # Permanent redirect.
	    array set metaA [set $htoken\(meta)]
	    if {[info exists metaA(Location)]} {
		set location $metaA(Location)
	    }
	}
    }
    ::httpex::cleanup $htoken
    unset -nocomplain state(httptoken)
    
    if {[info exists location]} {
	catch {
	    ::httpex::get $location \
	      -command  [list [namespace current]::HttpCommand $token]
	} state(httptoken)
    }
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
    Reset
}

proc ::RegisterEx::CloseAny {} {
    Cancel [GetTokenFrom w]
}

proc ::RegisterEx::CloseCmd {token w} {
    global  wDlgs
    variable $token
    upvar 0 $token state
    
    ::Debug 2 "::RegisterEx::CloseCmd"
    
    ::UI::SaveWinPrefixGeom $wDlgs(jreg)
    set state(finished) 0
    Reset
    return stop
}

proc ::RegisterEx::Reset {} {
    
    ::Debug 2 "\t ::RegisterEx::Reset"
    ::Jabber::Jlib connect reset
    ::Jabber::Jlib connect free
    ::Jabber::DoCloseClientConnection
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
    set msg "  "
    append msg [mc "Less"]...
    $state(wtri) configure -text $msg \
      -command [list [namespace current]::LessOpts $token]
}

proc ::RegisterEx::LessOpts {token} {
    variable $token
    upvar 0 $token state
    
    grid remove $state(wfmore)
    set msg "  "
    append msg [mc "More"]...
    $state(wtri) configure -text $msg \
      -command [list [namespace current]::MoreOpts $token]
}

proc ::RegisterEx::NotBusy {token} {
    variable $token
    upvar 0 $token state
    
    $state(wprog) stop
    set state(status) ""
    ::JUI::SetAppMessage ""
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
    
    ::Debug 2 "::RegisterEx::Get"
    
    focus $state(w)
    DestroyForm $token
    
    # This is a counter to verify we only treat the last query.
    incr state(cuid)
    
    # Kill any pending open states.
    #::Login::Reset
    
    # Verify.
    if {$state(-server) eq ""} {
	::UI::MessageBox -type ok -icon error -title [mc "Error"] \
	  -message [mc "Please first enter or select a server."]
	return
    }	
    # This is just to check the validity!
    if {[catch {jlib::nameprep $state(-server)} err]} {
	::UI::MessageBox -icon error -title [mc "Error"] -type ok \
	  -message [mc "Illegal character(s) in %s: %s!" "server" $state(-server)]
	return
    }
    #SetState $token {disabled}
    set state(status) [mc "Waiting for server response"]...
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
    ::JUI::SetConnectState "connectinit"

    # Asks for a socket to the server.
    set cb [namespace code [list ConnectCB $token $state(cuid)]]
    eval {::Jabber::Jlib connect connect $state(-server) {} -command $cb} $opts
}

proc ::RegisterEx::ConnectCB {token cuid jlibname status {errcode ""} {errmsg ""}} {
    variable $token
    upvar 0 $token state

    ::Debug 2 "::RegisterEx::ConnectCB status=$status, errcode=$errcode, errmsg=$errmsg"
    
    if {![info exists state]} {
	return
    }
    if {$status eq "ok"} {
	::Jabber::Jlib register_get [namespace code [list GetCB $token $cuid]]
    } elseif {$status eq "error"} {
	SetState $token {!disabled}
	NotBusy $token
	::JUI::SetConnectState "disconnect"
	if {$errcode ne "reset"} {
	    set str [::Login::GetErrorStr $errcode $errmsg]
	    ::UI::MessageBox -icon error -type ok -message $str
	}
	::Jabber::Jlib connect free
    }
}

proc ::RegisterEx::GetCB {token cuid jlibName type iqchild} {    
    variable $token
    upvar 0 $token state

    ::Debug 2 "::RegisterEx::GetCB type=$type, iqchild=$iqchild"

    if {![info exists state]} {
	return
    }
    if {!([info exists state(w)] && [winfo exists $state(w)])} {
	return
    }
    
    # Must match last query.
    if {$state(cuid) != $cuid} {
	return
    }
    NotBusy $token
    #SetState $token {disabled}
    DestroyForm $token
    
    if {[string equal $type "error"]} {
	set str [mc "Cannot obtain registration information."]
	append str "\n"
	append str  [mc "Error code"]
	append str ": [lindex $iqchild 0]\n"
	append str [mc "Message"]
	append str ": [lindex $iqchild 1]"
	::UI::MessageBox -type ok -icon error -title [mc "Error"] -message $str
	return
    } 
    bind $state(w) <Return> [namespace code [list SendRegister $token]]
    
    $state(wbtok) state {!disabled}
    $state(wbtok) configure -text [mc "Register"] \
      -command [list [namespace current]::SendRegister $token]
    
    # XEP-0077:
    # ...an entity could receive any combination of iq:register, x:data, 
    # and x:oob namespaces from a service in response to a request for 
    # information. The precedence order is as follows: 
    #   x:data 
    #   iq:register 
    #   x:oob 

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
    
    # Be sure to handle a situation where there was no 'password' field.
    # Not sure how this happens.
    set state(elem,password) ""
    
    set registration [dict create]
    dict set registration address [mc "Street portion of a physical or mailing address"]
    dict set registration city [mc "Locality portion of a physical or mailing address"]
    dict set registration date [mc "Some date (e.g., birth date, hire date, sign-up date)"]
    dict set registration email [mc "Email address"]
    dict set registration first [mc "First name or given name"]
    dict set registration is-registered [mc "You are already registered with this service. These are your current login settings."]
    dict set registration last [mc "Last name, surname, or family name"]
    dict set registration name [mc "Full name"]
    dict set registration nick [mc "Familiar name"]
    dict set registration password [mc "Password or secret"]
    dict set registration phone [mc "Telephone number"]
    dict set registration state [mc "An administrative region of the nation, such as a state or province"]
    dict set registration url [mc "URL to personal website"]
    dict set registration username [mc "Account name associated with the user"]
    dict set registration zip [mc "Postal code portion of a physical or mailing address"]

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
		  -validate key -validatecommand {::Jabber::ValidateUsernameStrEsc %S}
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
		set str [mc "Retype password"]:
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

	    set help [dict get $registration $tag]
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

	set help [dict get $registration $tag]
	if {$help ne "registration-$tag"} {
	    ::balloonhelp::balloonforwindow $wfr.l$tag $help
	    ::balloonhelp::balloonforwindow $wfr.e$tag $help
	}
    }

    ttk::checkbutton $wfr.csavepw -style Small.TCheckbutton  \
      -text [mc "Save password"] -variable $token\(savepassword)
    grid  x  $wfr.csavepw  -sticky w

    if {$isRegistered} {
	ttk::label $wfr.lregistered -text [mc "You are already registered with this service. These are your current login settings."]  \
	  -anchor w -wraplength 260 -justify left
	grid  $wfr.lregistered  -  -sticky ew
    }
    
    set oobE [wrapper::getfirstchildwithxmlns $iqchild "jabber:x:oob"]
    if {[llength $oobE]} {
	set urlE [wrapper::getfirstchildwithtag $oobE "url"]
	if {[llength $urlE]} {
	    set url [wrapper::getcdata $urlE]
	    ttk::button $wfr.oob -style Url \
	      -text $url -command [list ::Utils::OpenURLInBrowser $url]
	    grid  $wfr.oob  -  -sticky w
	}
    }
    
    grid columnconfigure $wfr 1 -weight 1
    bind $wfr.eusername <Map> { catch {focus %W} }
}

proc ::RegisterEx::DestroyForm {token} {
    variable $token
    upvar 0 $token state
   
    eval destroy [winfo children $state(wfriq)]
    array unset state elem,*
}

proc ::RegisterEx::SendRegister {token} {
    variable $token
    upvar 0 $token state
    
    ::Debug 2 "::RegisterEx::SendRegister"

    # Error checking.
    if {[info exists state(elem,password)] && [info exists state(elem,password2)]} {
	if {$state(elem,password) ne $state(elem,password2)} {
	    ::UI::MessageBox -icon error -title [mc "Error"] \
	      -message [mc "Passwords do not match. Please try again."] -parent $state(w)
	    set state(elem,password)  ""
	    set state(elem,password2) ""
	    return
	}
    }
    
    # Collect relevant elements.
    set subL [list]
    foreach {key value} [array get state elem,*] {
	set value [string trim $value]
	if {$value eq ""} {
	    continue
	}
	set tag [string map {elem, ""} $key]
	
	switch -- $tag {
	    instructions - registered - password2 {
		# empty.
	    }
	    username {
		set name [jlib::escapestr $value]
		lappend subL [wrapper::createtag $tag -chdata $name]
	    }
	    default {
		lappend subL [wrapper::createtag $tag -chdata $value]
	    }
	}
    }
    
    # We need to do it the crude way.
    set queryElem [wrapper::createtag "query" \
      -attrlist {xmlns jabber:iq:register} -subtags $subL]
    ::Jabber::Jlib send_iq "set" [list $queryElem] \
      -command [list [namespace current]::SendRegisterCB $token]
}

proc ::RegisterEx::SendRegisterCB {token type theQuery} {    
    global  config jprefs
    variable $token
    upvar 0 $token state

    ::Debug 2 "::RegisterEx::SendRegisterCB type=$type, theQuery=$theQuery"
    
    if {![info exists state]} {
	return
    }
    set server   $state(-server)
    set username [string trim $state(elem,username)]
    set username [jlib::escapestr $username]
    set password [string trim $state(elem,password)]
    set resource [::Profiles::MachineResource]

    if {[string equal $type "error"]} {
	set errcode [lindex $theQuery 0]
	set errmsg [lindex $theQuery 1]
	if {$errcode == 409} {
	    set msg [mc "The registration failed because this username is already in use by someone else."]
	    append msg "\n"
	append str [mc "Error"]
	append str ": $errmsg"
	} else {
	    set msg [mc "The registration failed."]
	    append msg "\n"
	    append msg [mc "Error"]
	    append msg ": $errmsg"
	}
	::UI::MessageBox -title [mc "Error"] -icon error -type ok -message $msg
	NotBusy $token
    } else {
	
	# Create a new profile or use a given one.
	if {[info exists state(-profile)]} {
	    set pname $state(-profile)
	} else {
	    set pname ""
	}
	if {$state(savepassword)} {
	    ::Profiles::Set $pname $server $username $password	    
	} else {
	    ::Profiles::Set $pname $server $username {}
	}
	if {$config(registerex,autologin) && ($password ne "")} {
	    
	    # Go on and authenticate.
	    set jid [jlib::joinjid $username $server $resource]
	    ::Jabber::Jlib connect register $jid $password
	    ::Jabber::Jlib connect auth -command [namespace code AuthCB]
	} else {
	    ui::dialog -icon info -type ok \
	      -message [mc "The registration with %s was successful. Now you just need to Login using the same username and password." $server]
	
	    # Disconnect. This should reset both wrapper and XML parser!
	    # Beware: we are in the middle of a callback from the xml parser,
	    # and need to be sure to exit from it before resetting!
	    after idle ::Jabber::Jlib closestream
	}
	
	# Kill dialog.
	set state(finished) 1
    }
}

proc ::RegisterEx::AuthCB {jlibname status {errcode ""} {errmsg ""}} {

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
	    ui::dialog -icon info -type ok \
	      -message [mc "You are now registered and automatically logged in as %s" [jlib::unescapejid $jid]]
	    $jlibname connect free
	}
	error {

	    # RFC 3929 (XMPP Core): 6.4 SASL Errors (short version)
	    set xmppShort [dict create]
	    dict set xmppShort aborted [mc "The login process was aborted."]
	    dict set xmppShort incorrect-encoding [mc "Protocol error during the login process."]
	    dict set xmppShort invalid-authzid [mc "Protocol error during the login process."]
	    dict set xmppShort invalid-mechanism [mc "Protocol error during the login process."]
	    dict set xmppShort mechanism-too-weak [mc "Protocol error during the login process."]
	    dict set xmppShort not-authorized [mc "Login failed because of unknown account or wrong password."]
	    dict set xmppShort temporary-auth-failure [mc "Protocol error during the login process."]

	    set str [dict get $xmppShort $errcode]
	    ui::dialog -icon error -type ok -title [mc "Error"] -message $str
	    ::JUI::SetConnectState "disconnect"
	    $jlibname connect free
	}
	default {
	    # empty since there are intermediate callbacks!
	}
    }
}

# The ::GenRegister:: namespace ------------------------------------------------

namespace eval ::GenRegister:: {

    variable uid 0
    
    # Show head label.
    set ::config(genregister,show-head) 1
    
    # Use simplified dialog layout if server given.
    set ::config(genregister,server-simple) 1
}

# GenRegister::NewDlg --
#
#       Initiates the process of registering with a service. 
#       Uses iq get-set method.
#       
# Arguments:
#       args   -server
#              -serverlist  list of JIDs of the same gateway type
#              -autoget 0/1
#              -serverstate (combobox -state)
#       
# Results:
#       token that identifies this dialog
     
proc ::GenRegister::NewDlg {args} {
    global  this wDlgs config

    variable uid
    
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
    if {[info exists argsA(-server)]} {
	set state(server) $argsA(-server)
    }
    set state(-autoget) 0
    if {[info exists argsA(-autoget)] && $argsA(-autoget)} {
	set state(-autoget) 1
    }
    
    ::UI::Toplevel $w -class JRegister -macstyle documentProc -usemacmainmenu 1 \
      -closecommand [list [namespace current]::CloseCmd $token] \
      -macclass {document closeBox}
    wm title $w [mc "Register"]
    set wtop $w
    
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jreg)]]
    if {$nwin == 1} {
	::UI::SetWindowPosition $w $wDlgs(jreg)
    }

    # Global frame.
    set minwidth [expr {$state(wraplength) + \
      [::UI::GetPaddingWidth [option get . dialogPadding {}]]}]
    set wall $w.fr
    ttk::frame $wall
    grid $wall -sticky news
    grid columnconfigure $w 0 -minsize $minwidth
        
    # Define the dialog type.
    set dialogType generic
    if {$config(genregister,server-simple)} {
	if {[info exists argsA(-server)]} {
	    set dialogType server
	} elseif {[info exists argsA(-serverlist)]} {
	    set dialogType serverlist
	}
    }
    if {$dialogType eq "server"} {
	set server $argsA(-server)
    } elseif {$dialogType eq "serverlist"} {
	set server [lindex $argsA(-serverlist) 0]
    } else {
	set server ""
    }
    if {$server ne ""} {
	set types [::Jabber::Jlib disco types $server]
	set gateway [lsearch -glob -inline $types gateway/*]
	set type [lindex [split $gateway /] 1]
    }
    set label [mc "Register"]
    
    if {$config(genregister,show-head)} {
	if {($dialogType eq "server") || ($dialogType eq "serverlist")} {
	    set conference [lsearch -glob -inline $types conference/*]
	    set im ""
	    set imd ""
	    if {$gateway ne ""} {
		set type [lindex [split $gateway /] 1]
		set spec protocol-$type
		set im   [::Theme::FindIconSize 32 $spec]
		set imd  [::Theme::FindIconSize 32 $spec-Dis]
		set label [mc "Register"]
		append label " [::Gateway::GetShort $type]"
	    } elseif {$conference ne ""} {
		set type [lindex [split $conference /] 1]
		set spec protocol-$type
		set im   [::Theme::FindIconSize 32 $spec]
		set imd  [::Theme::FindIconSize 32 $spec-Dis]
	    }
	    if {$im eq ""} {
		set im   [::Theme::Find32Icon $w registerImage]
		set imd  [::Theme::Find32Icon $w registerDisImage]
	    }
	    wm title $w $label
	} else {
	    set im   [::Theme::Find32Icon $w registerImage]
	    set imd  [::Theme::Find32Icon $w registerDisImage]
	}
	ttk::label $wall.head -style Headlabel \
	  -text $label -compound left -image [list $im background $imd]
	pack $wall.head -side top -fill both
	
	ttk::separator $wall.s -orient horizontal
	pack $wall.s -side top -fill x
    }
    set wbox $wall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    if {$dialogType ne "server"} {
	ttk::label $wbox.msg -style Small.TLabel \
	  -padding {0 0 0 6} -wraplength $state(wraplength) \
	  -text [mc "Select a service and press Next"] -justify left
	pack $wbox.msg -side top -anchor w
    }    
    set frserv $wbox.serv
    ttk::frame $frserv
    ttk::label $frserv.lserv -text [mc "Service"]:

    set wcomboserver $frserv.eserv

    # Get all (browsed) services that support registration.
    if {$dialogType eq "generic"} {
	set regServers [::Jabber::Jlib disco getjidsforfeature "jabber:iq:register"]
	ttk::combobox $wcomboserver -state $argsA(-serverstate)  \
	  -textvariable $token\(server) -values $regServers
	bind $wcomboserver <Map> { focus %W }
    
	# Find the default registration server.
	if {[llength $regServers]} {
	    set state(server) [lindex $regServers 0]
	}
	if {[info exists argsA(-server)]} {
	    $wcomboserver state {disabled}
	}
	pack $frserv -side top -anchor w -fill x
	pack $frserv.lserv -side left
	pack $wcomboserver -fill x -expand 1
    } elseif {$dialogType eq "serverlist"} {
	set menuDef [list]
	set imtrpt [::Theme::FindIconSize 16 protocol-$type]
	set name [::Gateway::GetShort $type]
	foreach j $argsA(-serverlist) {
	    set xname "$name ($j)"
	    lappend menuDef [list $xname -value $j -image $imtrpt]
	}
	set state(server) $server
	ui::optionmenu $wcomboserver -menulist $menuDef -direction flush  \
	  -variable $token\(server)
	bind $wcomboserver <Map> { focus %W }
	pack $frserv -side top -anchor w -fill x
	pack $frserv.lserv -side left
	pack $wcomboserver -fill x -expand 1
    }
    
    # Button part.
    set frbot       $wbox.b
    set wbtregister $frbot.btreg
    set wbtget      $frbot.btget
    set wbtcancel   $frbot.btcancel
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $wbtget -text [mc "Next"] \
      -command [list [namespace current]::Get $token]
    ttk::button $wbtregister -text [mc "Register"] \
      -command [list [namespace current]::DoRegister $token]
    ttk::button $wbtcancel -text [mc "Cancel"]  \
      -command [list [namespace current]::Cancel $token]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	if {!$state(-autoget)} {
	    pack $wbtget -side right
	}
	pack $wbtregister -side right -padx $padx
	pack $wbtcancel -side right
    } else {
	pack $wbtcancel -side right
	if {!$state(-autoget)} {
	    pack $wbtget -side right -padx $padx
	    pack $wbtregister -side right
	} else {
	    pack $wbtregister -side right -padx $padx
	}
    }
    pack $frbot -side bottom -fill x

    if {!$state(-autoget)} {
	bind $w <Return> [list $wbtget invoke]
	#$wbtget configure -default active
	$wbtregister state disabled
    } else {
	bind $w <Return> [list $wbtregister invoke]
	#$wbtregister configure -default active
    }
    
    # Running arrows and status message.
    set wstat $wbox.fs
    ttk::frame $wstat
    set wsearrows $wstat.arr
    ::UI::ChaseArrows $wsearrows
    ttk::label $wstat.lstat -style Small.TLabel \
      -textvariable $token\(stattxt)
    
    pack  $wstat        -side bottom -anchor w -fill x
    pack  $wsearrows    -side left
    pack  $wstat.lstat  -side left -padx 12
    
    # This part must be built dynamically from the 'get' xml data.
    # May be different for each conference server.

    # Not same wbox as above!!!
    set wform $wbox.form
    
    if {$config(genregister,server-simple)} {
	set state(stattxt) ""
    } else {
	# String wrong or obsolete?
	set state(stattxt) [mc "Waiting for Get to be pressed"]
    }
    set state(wcomboserver) $wcomboserver
    set state(wform)        $wform
    set state(wsearrows)    $wsearrows
    set state(wbtregister)  $wbtregister
    set state(wbtget)       $wbtget

    # Trick to resize the labels wraplength.
    if {[winfo exists $wbox.msg]} {
	set script [format {
	    update idletasks
	    %s configure -wraplength [expr {[winfo reqwidth %s] - 30}]
	    wm minsize %s [winfo reqwidth %s] 300
	} $wbox.msg $w $w $w]    
	#after idle $script
    }
    
    if {$state(-autoget)} {
	after idle [list [namespace current]::Get $token]
    }
    wm resizable $w 0 0
    
    return $token
}

proc ::GenRegister::Get {token} {    
    variable $token
    upvar 0 $token state
    
    # Verify.
    if {[string length $state(server)] == 0} {
	::UI::MessageBox -title [mc "Error"] -type ok -icon error  \
	  -message [mc "Please first enter or select a server."]
	return
    }	
    if {[winfo exists $state(wcomboserver)]} {
	$state(wcomboserver) state disabled
    }
    $state(wbtget) state disabled
    set state(stattxt) [mc "Waiting for server response"]...
    
    # Send get register.
    ::Jabber::Jlib register_get [list ::GenRegister::GetCB $token] \
      -to $state(server)
    $state(wsearrows) start
}

proc ::GenRegister::GetCB {token jlibName type subiq} {    
    variable $token
    upvar 0 $token state
    
    ::Debug 2 "::GenRegister::GetCB type=$type"

    if {!([info exists state(w)] && [winfo exists $state(w)])} {
	return
    }
    $state(wsearrows) stop
    set state(stattxt) ""
    $state(wbtget) state !disabled
    if {[winfo exists $state(wcomboserver)]} {
	$state(wcomboserver) state !disabled
    }    
    if {[string equal $type "error"]} {
	set str [mc "Cannot obtain registration information."]
	append str "\n"
	append str  [mc "Error code"]
	append str ": [lindex $subiq 0]\n"
	append str [mc "Message"]
	append str ": [lindex $subiq 1]"
	::ui::dialog -type ok -title [mc "Error"] -icon error -message $str
	return
    }
    set wform $state(wform)
    set childs [wrapper::getchildren $subiq]

    if {[winfo exists $wform]} {
	destroy $wform
    }
    set formtoken [::JForms::Build $wform $subiq -tilestyle Mixed \
      -width $state(wraplength)]
    pack $wform -fill x -expand 1
    set state(formtoken) $formtoken
    
    #$state(wbtregister) configure -default active
    $state(wbtregister) state !disabled
    
    set wfocus [::UI::FindFirstClassChild $wform TEntry]
    if {[winfo exists $wfocus]} {
	bind $wfocus <Map> { focus %W }
    }
    bind $state(w) <Return> [list $state(wbtregister) invoke]
}

proc ::GenRegister::DoRegister {token} {   
    variable $token
    upvar 0 $token state
    
    if {!([info exists state(w)] && [winfo exists $state(w)])} {
	return
    }
    $state(wsearrows) start
    
    set subelements [::JForms::GetXML $state(formtoken)]
 
    # We need to do it the crude way.
    ::Jabber::Jlib send_iq "set"  \
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

    ::Debug 2 "::GenRegister::ResultCallback type=$type, subiq='$subiq'"

    set jid $state(server)

    if {[string equal $type "error"]} {
	set str [mc "Cannot register with service %s." $jid]
	append str "\n"
	append str [mc "Error code"]
	append str ": [lindex $subiq 0]\n"
	append str [mc "Message"]
	append str ": [lindex $subiq 1]"
	::UI::MessageBox -type ok -icon error -title [mc "Error"] -message $str
    } else {
	::UI::MessageBox -type ok -icon info \
	  -message [mc "Registration with service %s was successful." [jlib::unescapejid $jid]]
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
    
    ::Debug 2 "::GenRegister::Simple"
    if {[winfo exists $w]} {
	return
    }
    array set argsA $args
    
    ::UI::Toplevel $w -class JRegister -macstyle documentProc \
      -usemacmainmenu 1 -macclass {document closeBox}
    wm title $w [mc "Register"]
    set wtop $w
 
    set im   [::Theme::Find32Icon $w registerImage]
    set imd  [::Theme::Find32Icon $w registerDisImage]

    # Global frame.
    set wall $w.fr
    ttk::frame $wall
    pack $wall -fill x

    ttk::label $wall.head -style Headlabel \
      -text [mc "Register"] -compound left \
      -image [list $im background $imd]
    pack $wall.head -side top -fill both

    ttk::separator $wall.s -orient horizontal
    pack $wall.s -side top -fill x
    
    set wbox $wall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 300 -justify left -text [mc "Select a service and press Next"]
    pack $wbox.msg -side top -anchor w

    set wmid $wbox.m
    ttk::frame $wmid
    pack $wmid -side top -fill both -expand 1
    
    set regServers [::Jabber::Jlib disco getjidsforfeature "jabber:iq:register"]

    ttk::label $wmid.lserv -text [mc "Service"]:
    ttk::combobox $wmid.combo -state readonly  \
      -textvariable [namespace current]::server -values $regServers    
    ttk::label $wmid.luser -text [mc "Username"]: -anchor e
    ttk::entry $wmid.euser  \
      -textvariable [namespace current]::username -validate key  \
      -validatecommand {::Jabber::ValidateUsernameStr %S}
    ttk::label $wmid.lpass -text [mc "Password"]: -anchor e
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
    set wbtregister $frbot.btreg
    set wbtcancel   $frbot.btcancel
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $wbtregister -text [mc "Register"] \
      -default active -command [namespace current]::DoSimple
    ttk::button $wbtcancel -text [mc "Cancel"]  \
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
    
    ::Jabber::Jlib register_set $username $password  \
      [list [namespace current]::SimpleCallback $server] -to $server
    set finished 1
    destroy $wtop
}

proc ::GenRegister::SimpleCallback {server jlibName type subiq} {

    ::Debug 2 "::GenRegister::ResultCallback server=$server, type=$type, subiq='$subiq'"

    if {[string equal $type "error"]} {
	set str [mc "Cannot register with service %s." $server]
	append str "\n"
	append str [mc "Error code"]
	append str ": [lindex $subiq 0]\n"
	append str [mc "Message"]
	append str ": [lindex $subiq 1]"
	::UI::MessageBox -type ok -icon error -title [mc "Error"] -message $str
    } else {
	::UI::MessageBox -type ok -icon info -message [mc "Registration with service %s was successful." $server]
    }
}

#-------------------------------------------------------------------------------
