#  Login.tcl ---
#  
#      This file is part of the whiteboard application. 
#      It implements the Roster GUI part.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
# $Id: Login.tcl,v 1.19 2004-01-02 11:41:16 matben Exp $

package provide Login 1.0

namespace eval ::Jabber::Login:: {
    global  wDlgs
    
    variable server
    variable username
    variable password

    # Add all event hooks.
    hooks::add quitAppHook     [list ::UI::SaveWinGeom $wDlgs(jlogin)]
    hooks::add closeWindowHook ::Jabber::Login::CloseHook
}

# Jabber::Login::Login --
#
#       Log in to a server with an existing user account.
#
# Arguments:
#       
# Results:
#       name of button pressed; "cancel" or "login".

proc ::Jabber::Login::Login { } {
    global  this prefs wDlgs
    
    variable wtoplevel
    variable finished -1
    variable menuVar
    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable digest
    variable ssl 0
    variable invisible 0
    variable ip ""
    variable wtri
    variable wtrilab
    variable wfrmore
    variable tmpJServArr
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    
    set w $wDlgs(jlogin)
    if {[winfo exists $w]} {
	return
    }
    set wtoplevel $w
    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
    wm title $w [::msgcat::mc Login]
    set digest 1
    set ssl $jprefs(usessl)
    
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
                                 
    ::headlabel::headlabel $w.frall.head -text [::msgcat::mc Login]    
    pack $w.frall.head -side top -fill both -expand 1
    message $w.frall.msg -width 280 -text [::msgcat::mc jalogin]
    pack $w.frall.msg -side top -fill both -expand 1 -padx 2
    
    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    pack $frmid -side top -fill both -expand 1
	
    # Option menu for selecting user profile.
    label $frmid.lpop -text "[::msgcat::mc Profile]:" -font $fontSB -anchor e
    set wpopup $frmid.popup
    set profileList [::Jabber::GetAllProfileNames]
    eval {tk_optionMenu $wpopup [namespace current]::menuVar} $profileList
    $wpopup configure -highlightthickness 0 -foreground black
    grid $frmid.lpop -column 0 -row 0 -sticky e
    grid $wpopup -column 1 -row 0 -sticky e

    # Verify that the selected also in array.
    if {[lsearch -exact $jserver(profile) $jserver(profile,selected)] < 0} {
	set jserver(profile,selected) [lindex $jserver(profile) 0]
    }
    set profile $jserver(profile,selected)
    set menuVar $jserver(profile,selected)
    
    # Make temp array for servers. Handy fo filling in the entries.
    foreach {name spec} $jserver(profile) {
	foreach [list  \
	  tmpJServArr($name,server)     \
	  tmpJServArr($name,username)   \
	  tmpJServArr($name,password)   \
	  tmpJServArr($name,resource)] $spec break
    }
    set server $tmpJServArr($menuVar,server)
    set username $tmpJServArr($menuVar,username)
    set password $tmpJServArr($menuVar,password)
    set resource $tmpJServArr($menuVar,resource)
    
    label $frmid.lserv -text "[::msgcat::mc {Jabber server}]:" -font $fontSB -anchor e
    entry $frmid.eserv -width 22    \
      -textvariable [namespace current]::server -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    label $frmid.luser -text "[::msgcat::mc Username]:" -font $fontSB -anchor e
    entry $frmid.euser -width 22   \
      -textvariable [namespace current]::username -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    label $frmid.lpass -text "[::msgcat::mc Password]:" -font $fontSB -anchor e
    entry $frmid.epass -width 22   \
      -textvariable [namespace current]::password -show {*} -validate key \
      -validatecommand {::Jabber::ValidatePasswdChars %S}
    label $frmid.lres -text "[::msgcat::mc Resource]:" -font $fontSB -anchor e
    entry $frmid.eres -width 22   \
      -textvariable [namespace current]::resource -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    
    grid $frmid.lserv -column 0 -row 1 -sticky e
    grid $frmid.eserv -column 1 -row 1 -sticky w
    grid $frmid.luser -column 0 -row 2 -sticky e
    grid $frmid.euser -column 1 -row 2 -sticky w
    grid $frmid.lpass -column 0 -row 3 -sticky e
    grid $frmid.epass -column 1 -row 3 -sticky w
    grid $frmid.lres -column 0 -row 4 -sticky e
    grid $frmid.eres -column 1 -row 4 -sticky w
    
    # Triangle switch for more options.
    set frtri [frame $w.frall.tri -borderwidth 0]
    pack $frtri -side top -fill both -expand 1 -padx 6
    set wtri $frtri.tri
    set wtrilab $frtri.l
    label $wtri -image [::UI::GetIcon mactriangleclosed]
    label $wtrilab -text "[::msgcat::mc More]..."
    pack $wtri $wtrilab -side left -padx 2
    bind $wtri <Button-1> [list [namespace current]::MoreOpts $w]
    
    # More options.
    set wfrmore [frame $w.frall.frmore -borderwidth 0]    
    checkbutton $wfrmore.cdig -text "  [::msgcat::mc {Scramble password}]"  \
      -variable [namespace current]::digest
    checkbutton $wfrmore.cssl -text "  [::msgcat::mc {Use SSL for security}]"  \
      -variable [namespace current]::ssl
    checkbutton $wfrmore.cinv  \
      -text "  [::msgcat::mc {Login as invisible}]"  \
      -variable [namespace current]::invisible
    frame $wfrmore.fr
    pack [label $wfrmore.fr.l -text "[::msgcat::mc {IP address}]:"] -side left
    pack [entry $wfrmore.fr.e -textvariable [namespace current]::ip] -side left

    grid $wfrmore.cdig -sticky w -pady 2
    grid $wfrmore.cssl -sticky w -pady 2
    grid $wfrmore.cinv -sticky w -pady 2
    grid $wfrmore.fr -sticky w -pady 2

    if {!$prefs(tls)} {
	set ssl 0
	$wfrmore.cssl configure -state disabled
    }
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btconn -text [::msgcat::mc Login] -width 8 \
      -default active -command [namespace current]::Doit]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command [list [namespace current]::DoCancel $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side bottom -fill both -expand 1 -padx 8 -pady 6
    
    # Necessary to trace the popup menu variable.
    trace variable [namespace current]::menuVar w  \
      [namespace current]::TraceMenuVar
	
    ::UI::SetWindowPosition $w
    wm resizable $w 0 0
    bind $w <Return>  ::Jabber::Login::Doit
    bind $w <Escape>  [list ::Jabber::Login::DoCancel $w]
    bind $w <Destroy> [list ::Jabber::Login::DoCancel $w]
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    # Clean up.
    catch {grab release $w}
    ::Jabber::Login::Close $w
    catch {focus $oldFocus}
    return [expr {($finished <= 0) ? "cancel" : "login"}]
}


proc ::Jabber::Login::CloseHook {wclose} {
    global  wDlgs
    
    if {[string equal $wclose $wDlgs(jlogin)]} {
	puts ::Jabber::Login::CloseHook
    }
}

proc ::Jabber::Login::MoreOpts {w} {
    variable wtri
    variable wtrilab
    variable wfrmore
      
    pack $wfrmore -side left -fill x -padx 16
    $wtri configure -image [::UI::GetIcon mactriangleopen]
    $wtrilab configure -text "[::msgcat::mc Less]..."
    bind $wtri <Button-1> [list [namespace current]::LessOpts $w]
}

proc ::Jabber::Login::LessOpts {w} {
    variable wtri
    variable wtrilab
    variable wfrmore
    
    pack forget $wfrmore
    $wtri configure -image [::UI::GetIcon mactriangleclosed]
    $wtrilab configure -text "[::msgcat::mc More]..."
    bind $wtri <Button-1> [list [namespace current]::MoreOpts $w]
}

proc ::Jabber::Login::DoCancel {w} {
    variable finished
    
    ::UI::SaveWinGeom $w
    set finished 0
    catch {destroy $w}
}

proc ::Jabber::Login::Close {w} {
    variable menuVar
    upvar ::Jabber::jserver jserver
    
    # Clean up.
    set jserver(profile,selected) $menuVar
    trace vdelete [namespace current]::menuVar w  \
      [namespace current]::TraceMenuVar
    catch {grab release $w}
    catch {destroy $w}    
}

proc ::Jabber::Login::TraceMenuVar {name key op} {
    
    # Call by name.
    upvar #0 $name locName

    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable menuVar
    variable tmpJServArr
    
    set profile $locName
    set server $tmpJServArr($locName,server)
    set username $tmpJServArr($locName,username)
    set password $tmpJServArr($locName,password)
    set resource $tmpJServArr($locName,resource)
}

# Jabber::Login::Doit --
#
#       Initiates a login to a server with an existing user account.
#
# Arguments:
#       
# Results:
#       .

proc ::Jabber::Login::Doit { } {
    global  errorCode prefs

    variable wtoplevel
    variable finished
    variable server
    variable username
    variable password
    variable resource
    variable ssl
    variable ip
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Login::Doit"
    
    # Kill any pending open states.
    ::Network::KillAll
    ::Jabber::UI::SetStatusMessage ""
    ::Jabber::UI::StartStopAnimatedWave 0
    
    # Check 'server', 'username' and 'password' if acceptable.
    foreach name {server username password} {
	upvar 0 $name var
	if {[string length $var] <= 1} {
	    tk_messageBox -icon error -type ok -message  \
	      [FormatTextForMessageBox [::msgcat::mc jamessnamemissing $name]]	      
	    return
	}
	if {$name == "password"} {
	    continue
	}
	if {[regexp $jprefs(invalsExp) $var match junk]} {
	    tk_messageBox -icon error -type ok -message  \
	      [FormatTextForMessageBox [::msgcat::mc jamessillegalchar $name $var]]
	    return
	}
    }    
    set finished 1
    ::UI::SaveWinGeom $wtoplevel
    catch {destroy $wtoplevel}
    
    ::Jabber::UI::SetStatusMessage [::msgcat::mc jawaitresp $server]
    ::Jabber::UI::StartStopAnimatedWave 1
    ::Jabber::UI::FixUIWhen "connectinit"
    update idletasks

    # Async socket open with callback.
    if {$ssl} {
	set port $jprefs(sslport)
    } else {
	set port $jprefs(port)
    }
    if {$ip == ""} {
	set host $server
    } else {
	set host $ip
    }
    ::Network::OpenConnection $host $port [namespace current]::SocketIsOpen  \
      -timeout $prefs(timeoutSecs) -tls $ssl
}

# Jabber::Login::SocketIsOpen --
#
#       Callback when socket has been opened. Logins.
#       
# Arguments:
#       
#       status      "error", "timeout", or "ok".
# Results:
#       Callback initiated.

proc ::Jabber::Login::SocketIsOpen {sock ip port status {msg {}}} {    
    variable server
    variable username
    variable password
    variable resource
    variable digest
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Login::SocketIsOpen"
    
    switch $status {
	error - timeout {
	    ::Jabber::UI::SetStatusMessage ""
	    ::Jabber::UI::StartStopAnimatedWave 0
	    ::Jabber::UI::FixUIWhen "disconnect"
	    if {$status == "error"} {
		tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
		  [::msgcat::mc jamessnosocket $ip $msg]]
	    } elseif {$status == "timeout"} {
		tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
		  [::msgcat::mc jamesstimeoutserver $server]]
	    }
	    return ""
	}
	default {
	    # Just go ahead
	}
    }    
    set jstate(sock) $sock
    ::Jabber::UI::SetStatusMessage [::msgcat::mc jawaitxml $server]
    
    # Initiate a new stream. Perhaps we should wait for the server <stream>?
    if {[catch {
	$jstate(jlib) connect $server -socket $sock  \
	  -cmd [namespace current]::ConnectProc
    } err]} {
	::Jabber::UI::SetStatusMessage ""
	::Jabber::UI::StartStopAnimatedWave 0
	::Jabber::UI::FixUIWhen "disconnect"
	tk_messageBox -icon error -title [::msgcat::mc {Open Failed}] -type ok \
	  -message [FormatTextForMessageBox $err]
	return
    }

    # Just wait for a callback to the procedure.
}

# Jabber::Login::ConnectProc --
#
#       Callback procedure for the 'connect' command of jabberlib.
#       
# Arguments:
#       jlibName    name of jabber lib instance
#       args        attribute list
#       
# Results:
#       Callback initiated.

proc ::Jabber::Login::ConnectProc {jlibName args} {    
    variable server
    variable username
    variable password
    variable resource
    variable digest
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Login::ConnectProc jlibName=$jlibName, args='$args'"

    array set argsArray $args
    ::Jabber::UI::SetStatusMessage [::msgcat::mc jasendauth $server]
    
    # Send authorization info for an existing account.
    # Perhaps necessary to get additional variables
    # from some user preferences.
    if {$resource == ""} {
	set resource coccinella
    }
    if {$digest} {
	if {![info exists argsArray(id)]} {
	    error "no id for digest in receiving <stream>"
	}
	
	::Jabber::Debug 3 "argsArray(id)=$argsArray(id), password=$password"
	
	set digestedPw [::sha1pure::sha1 $argsArray(id)$password]
	$jstate(jlib) send_auth $username $resource   \
	  ::Jabber::Login::ResponseProc -digest $digestedPw
    } else {
	$jstate(jlib) send_auth $username $resource   \
	  ::Jabber::Login::ResponseProc -password $password
    }
    
    # Just wait for a callback to the procedure.
}

# Jabber::Login::ResponseProc --
#
#       Callback for Login iq element.
#       
# Arguments:
#       
# Results:
#       .

proc ::Jabber::Login::ResponseProc {jlibName type theQuery} {
    global  ipName2Num prefs wDlgs
    
    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable invisible
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    ::Jabber::Debug 2 "::Jabber::Login::ResponseProc  theQuery=$theQuery"

    ::Jabber::UI::StartStopAnimatedWave 0
    
    if {[string equal $type "error"]} {	
	set errcode [lindex $theQuery 0]
	set errmsg [lindex $theQuery 1]
	::Jabber::UI::SetStatusMessage [::msgcat::mc jaerrlogin $server $errmsg]
	::Jabber::UI::FixUIWhen "disconnect"
	if {$errcode == 409} {
	    set msg [::msgcat::mc jamesslogin409 $errcode]
	} else {
	    set msg [::msgcat::mc jamessloginerr $errcode $errmsg]
	}
	tk_messageBox -icon error -type ok -title [::msgcat::mc Error]  \
	  -message [FormatTextForMessageBox $msg]

	#       There is a potential problem if called from within a xml parser 
	#       callback which makes the subsequent parsing to fail. (after idle?)
	after idle $jstate(jlib) disconnect
	return
    } 
    
    # Collect ip num name etc. in arrays.
    if {![::OpenConnection::SetIpArrays $server $jstate(sock)  \
      $jstate(servPort)]} {
	::Jabber::UI::SetStatusMessage ""
	return
    }
    if {[::Utils::IsIPNumber $server]} {
	set ipNum $server
    } else {
	set ipNum $ipName2Num($server)
    }
    set jstate(ipNum) $ipNum
    
    # Ourself.
    set jstate(mejid) "${username}@${server}"
    set jstate(meres) $resource
    set jstate(mejidres) "${username}@${server}/${resource}"
    set jserver(profile,selected) $profile
    set jserver(this) $server

    ::Network::RegisterIP $ipNum "to"
    
    # Login was succesful, set presence.
    if {$invisible} {
	set jstate(status) "invisible"
	::Jabber::SetStatus invisible
    } else {
	set jstate(status) "available"
	::Jabber::SetStatus available -notype 1
    }
    
    # Store our own ip number in a public storage at the server.
    ::Jabber::SetPrivateData
        
    # Run all login hooks.
    hooks::run loginHook
}

#-------------------------------------------------------------------------------
