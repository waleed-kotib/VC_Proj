#  Login.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the Roster GUI part.
#      
#  Copyright (c) 2001-2004  Mats Bengtsson
#  
# $Id: Login.tcl,v 1.39 2004-07-09 06:26:05 matben Exp $

package provide Login 1.0

namespace eval ::Jabber::Login:: {
    global  wDlgs
    
    variable server
    variable username
    variable password
    variable uid

    set uid 0
    
    # Add all event hooks.
    ::hooks::add quitAppHook     [list ::UI::SaveWinGeom $wDlgs(jlogin)]
    ::hooks::add closeWindowHook ::Jabber::Login::CloseHook
}

# Jabber::Login::Login --
#
#       Log in to a server with an existing user account.
#
# Arguments:
#       
# Results:
#       none

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
    variable wtri
    variable wtrilab
    variable wfrmore
    variable wpopupMenu
    variable tmpProfArr
    upvar ::Jabber::jprefs jprefs
    
    set w $wDlgs(jlogin)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    set wtoplevel $w
    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w [mc Login]
    
    set fontSB     [option get . fontSmallBold {}]
    set contrastBg [option get . backgroundLightContrast {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1
                                 
    ::headlabel::headlabel $w.frall.head -text [mc Login]    
    pack $w.frall.head -side top -fill both -expand 1
    label $w.frall.msg -wraplength 280 -justify left -text [mc jalogin]
    pack $w.frall.msg -side top -fill both -expand 1 -padx 10
    
    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    pack $frmid -side top -fill both -expand 1
	
    # Option menu for selecting user profile.
    label $frmid.lpop -text "[mc Profile]:" -font $fontSB -anchor e
    set wpopup $frmid.popup
    
    set wpopupMenu [tk_optionMenu $wpopup [namespace current]::menuVar {}]
    $wpopup configure -highlightthickness 0 -foreground black
    grid $frmid.lpop -column 0 -row 0 -sticky e
    grid $wpopup -column 1 -row 0 -sticky e
    
    ::Jabber::Login::LoadProfiles

    label $frmid.lserv -text "[mc {Jabber server}]:" -font $fontSB -anchor e
    entry $frmid.eserv -width 22    \
      -textvariable [namespace current]::server -validate key  \
      -validatecommand {::Jabber::ValidateDomainStr %S}
    label $frmid.luser -text "[mc Username]:" -font $fontSB -anchor e
    entry $frmid.euser -width 22   \
      -textvariable [namespace current]::username -validate key  \
      -validatecommand {::Jabber::ValidateUsernameStr %S}
    label $frmid.lpass -text "[mc Password]:" -font $fontSB -anchor e
    entry $frmid.epass -width 22   \
      -textvariable [namespace current]::password -show {*} -validate key \
      -validatecommand {::Jabber::ValidatePasswdChars %S}
    label $frmid.lres -text "[mc Resource]:" -font $fontSB -anchor e
    entry $frmid.eres -width 22   \
      -textvariable [namespace current]::resource -validate key  \
      -validatecommand {::Jabber::ValidateResourceStr %S}
    
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
    label $wtrilab -text "[mc More]..."
    pack $wtri $wtrilab -side left -padx 2
    bind $wtri <Button-1> [list [namespace current]::MoreOpts $w]
    
    # More options.
    set wfrmore [frame $w.frall.frmore -borderwidth 0]
    set wfrmfr  [frame $wfrmore.fr -bd 1 -relief flat -bg $contrastBg]
    pack $wfrmfr -padx 4 -pady 6 -side bottom -fill x -expand 1
    
    # Tabbed notebook for more options.
    # Tabbed notebook for more options.
    set token [namespace current]::moreOpts
    variable $token
    upvar 0 $token options
    set wtabnb $wfrmfr.nb
    ::Profiles::OptionsTabNotebook $wtabnb $token
    pack $wtabnb -fill x -expand 1
            
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [mc Login] \
      -default active -command [namespace current]::DoLogin]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::DoCancel $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btprof -text [mc Profiles]  \
      -command [namespace current]::Profiles]  \
      -side left -padx 5 -pady 5
    pack $frbot -side bottom -fill both -expand 1 -padx 8 -pady 6
    
    # Necessary to trace the popup menu variable.
    trace variable [namespace current]::menuVar w  \
      [namespace current]::TraceMenuVar
    set menuVar $profile
	
    ::UI::SetWindowPosition $w
    wm resizable $w 0 0
    bind $w <Return>  [list $frbot.btok invoke]
    bind $w <Escape>  [list ::Jabber::Login::DoCancel $w]
    bind $w <Destroy> [list ::Jabber::Login::DoCancel $w]
}

proc ::Jabber::Login::LoadProfiles { } {
    global  wDlgs
    variable tmpProfArr
    variable menuVar
    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable wpopupMenu
    
    if {![winfo exists $wDlgs(jlogin)]} {
	return
    }
    $wpopupMenu delete 0 end
    set profileList [::Profiles::GetAllNames]
    foreach name $profileList {
	$wpopupMenu add command -label $name \
	  -command [list set [namespace current]::menuVar $name]
    }
    set profile [::Profiles::GetSelectedName]
    
    # Make temp array for servers. Handy for filling in the entries.
    array unset tmpProfArr
    foreach {name spec} [::Profiles::Get] {
	set tmpProfArr($name,server)    [lindex $spec 0]
	set tmpProfArr($name,username)  [lindex $spec 1]
	set tmpProfArr($name,password)  [lindex $spec 2]
	set tmpProfArr($name,-resource) ""
	foreach {key value} [lrange $spec 3 end] {
	    set tmpProfArr($name,$key) $value
	}
    }
    set menuVar $profile
}

proc ::Jabber::Login::TraceMenuVar {name key op} {
    global  prefs
    
    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable menuVar
    variable tmpProfArr
    variable moreOpts
    
    ::Profiles::DefaultOptionsTabNotebook [namespace current]::moreOpts
    
    set profile  [set $name]
    set server   $tmpProfArr($profile,server)
    set username $tmpProfArr($profile,username)
    set password $tmpProfArr($profile,password)
    foreach {key value} [array get tmpProfArr $profile,-*] {
	set optname [string map [list $profile,- ""] $key]
	set moreOpts($optname) $value
	#puts "optname=$optname, value=$value"
    }
    set resource $tmpProfArr($profile,-resource)
    if {!$prefs(tls)} {
	set moreOpts(ssl) 0
    }
}

proc ::Jabber::Login::CloseHook {wclose} {
    global  wDlgs
    variable finished
    
    if {[string equal $wclose $wDlgs(jlogin)]} {
	set finished 0
	::Jabber::Login::Close $wclose
    }
}

proc ::Jabber::Login::MoreOpts {w} {
    variable wtri
    variable wtrilab
    variable wfrmore
      
    pack $wfrmore -side top -fill x -padx 10
    $wtri configure -image [::UI::GetIcon mactriangleopen]
    $wtrilab configure -text "[mc Less]..."
    bind $wtri <Button-1> [list [namespace current]::LessOpts $w]
}

proc ::Jabber::Login::LessOpts {w} {
    variable wtri
    variable wtrilab
    variable wfrmore
    
    pack forget $wfrmore
    $wtri configure -image [::UI::GetIcon mactriangleclosed]
    $wtrilab configure -text "[mc More]..."
    bind $wtri <Button-1> [list [namespace current]::MoreOpts $w]
}

proc ::Jabber::Login::DoCancel {w} {
    variable finished

    set finished 0
    ::Jabber::Login::Close $w
}

proc ::Jabber::Login::Profiles { } {
    
    ::Profiles::BuildDialog
}

proc ::Jabber::Login::Close {w} {
    variable menuVar
    
    # Clean up.
    ::UI::SaveWinGeom $w
    ::Profiles::SetSelectedName $menuVar
    trace vdelete [namespace current]::menuVar w  \
      [namespace current]::TraceMenuVar
    catch {grab release $w}
    catch {destroy $w}    
}

# Jabber::Login::DoLogin --
# 
#       Starts the login process.

proc ::Jabber::Login::DoLogin {} {
    global  prefs

    variable wtoplevel
    variable finished
    variable server
    variable username
    variable password
    variable resource
    variable moreOpts
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::Login::DoLogin"
    
    # Kill any pending open states.
    ::Network::KillAll
    ::Jabber::UI::SetStatusMessage ""
    ::Jabber::UI::StartStopAnimatedWave 0
    
    # Check 'server', 'username' and 'password' if acceptable.
    foreach name {server username password} {
	upvar 0 $name var
	if {[string length $var] <= 1} {
	    tk_messageBox -icon error -type ok -message  \
	      [FormatTextForMessageBox [mc jamessnamemissing $name]]	      
	    return
	}
	if {$name == "password"} {
	    continue
	}
	
	# This is just to check the validity!
	if {[catch {
	    switch -- $name {
		server {
		    jlib::nameprep $var
		}
		username {
		    jlib::nodeprep $var
		}
	    }
	} err]} {
	    tk_messageBox -icon error -type ok -message  \
	      [FormatTextForMessageBox [mc jamessillegalchar $name $var]]
	    return
	}
    }    
    set finished 1
    ::Jabber::Login::Close $wtoplevel
    
    set opts {}
    if {$moreOpts(httpproxy)} {
	lappend opts -httpproxy 1
    }
    eval {::Jabber::Login::Connect $server [namespace current]::DoLoginCB \
      -ssl $moreOpts(ssl) -ip $moreOpts(ip) -port $moreOpts(port)} $opts
}

proc ::Jabber::Login::DoLoginCB {status msg} {
    variable server
    variable moreOpts

    ::Debug 2 "::Jabber::Login::DoLoginCB status=$status"
    
    switch $status {
	error {
	    tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	      [mc jamessnosocket $moreOpts(ip) $msg]]
	}
	timeout {
	    tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	      [mc jamesstimeoutserver $server]]
	}
	default {
	    # Go ahead...
	    if {[catch {
		::Jabber::Login::InitStream $server \
		  [namespace current]::DoAuthorize
	    } err]} {
		tk_messageBox -icon error -title [mc {Open Failed}] \
		  -type ok -message [FormatTextForMessageBox $err]
	    }
	}
    }
}

proc ::Jabber::Login::DoAuthorize {args} {
    variable server
    variable username
    variable password
    variable resource
    variable moreOpts
    
    ::Debug 2 "::Jabber::Login::DoAuthorize args=$args"
    array set argsArr $args
    if {![info exists argsArr(id)]} {
	tk_messageBox -icon error -type ok -message \
	  "no id for digest in receiving <stream>"
    } else {
	if {$resource == ""} {
	    set resource "coccinella"
	}
	::Jabber::Login::Authorize $server $username $resource $password \
	  [namespace current]::Finish -streamid $argsArr(id)  \
	  -digest $moreOpts(digest)
    }
}

proc ::Jabber::Login::Finish {type msg} {
    variable profile
    variable moreOpts
    
    ::Debug 2 "::Jabber::Login::Finish type=$type, msg=$msg"

    if {[string equal $type "error"]} {
	tk_messageBox -icon error -type ok -title [mc Error]  \
	  -message [FormatTextForMessageBox $msg]
    } else {
	::Profiles::SetSelectedName $profile
	
	# Login was succesful, set presence.
	::Jabber::Login::SetStatus -priority $moreOpts(priority)  \
	  -invisible $moreOpts(invisible)
    }
}

proc ::Jabber::Login::SetStatus {args} {
    upvar ::Jabber::jstate jstate
    
    array set argsArr {
	-invisible    0
	-priority     0
    }
    array set argsArr $args
    set presArgs {}
    if {$argsArr(-priority) != 0} {
	lappend presArgs -priority $priority
    }
    if {$argsArr(-invisible)} {
	set jstate(status) "invisible"
	eval {::Jabber::SetStatus invisible} $presArgs
    } else {
	set jstate(status) "available"
	eval {::Jabber::SetStatus available -notype 1} $presArgs
    }    
}

#-------------------------------------------------------------------------------

# A few functions to handle each stage in the login process as a separate
# component:
#       o connect socket
#       o initialize the stream
#       o authorize
#       
# They get and set jstate and other state variables. User interface elements
# are set, but no message boxes are shown. That is up to the caller.


# Jabber::Login::Connect --
#
#       Initiates a login to a server with an existing user account.
#
# Arguments:
#       server
#       cmd         callback command when socket connected
#       args  -ip
#             -port
#             -ssl 0|1
#             -httpproxy 0|1
#       
# Results:
#       Callback scheduled.

proc ::Jabber::Login::Connect {server cmd args} {
    global  prefs

    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::Login::Connect args=$args"
    array set argsArr {
	-ip         ""
	-ssl        0
	-httpproxy  0
    }
    array set argsArr $args
    
    # Kill any pending open states.
    ::Network::KillAll
        
    ::Jabber::UI::SetStatusMessage [mc jawaitresp $server]
    ::Jabber::UI::StartStopAnimatedWave 1
    ::Jabber::UI::FixUIWhen "connectinit"
    update idletasks

    # Async socket open with callback.
    if {$argsArr(-ssl)} {
	set port $jprefs(sslport)
    } elseif {[info exists argsArr(-port)]} {
	set port $argsArr(-port)
    } else {
	set port $jprefs(port)
    }
    if {$argsArr(-ip) == ""} {
	set host $server
    } else {
	set host $argsArr(-ip)
    }
    
    # Open socket unless we are using a http proxy.
    if {!$argsArr(-httpproxy)} {
	::Network::Open $host $port [list [namespace current]::ConnectCB $cmd] \
	  -timeout $prefs(timeoutSecs) -tls $argsArr(-ssl)
    } else {
	
	# Perhaps it gives a better structure to have this elsewhere?
	package require jlibhttp
	
	# Configure our jlib http transport.
	set opts {}
	if {[string length $prefs(httpproxyserver)]} {
	    lappend opts -proxyhost $prefs(httpproxyserver)
	}
	if {[string length $prefs(httpproxyport)]} {
	    lappend opts -proxyport $prefs(httpproxyport)
	}
	if {$prefs(httpproxyauth)} {
	    lappend opts -proxyusername $prefs(httpproxyusername)
	    lappend opts -proxypasswd $prefs(httpproxypassword)
	}
	eval {jlib::http::new $jstate(jlib) $host \
	  -command [namespace current]::HttpProxyCmd} $opts

	uplevel #0 $cmd [list ok ""]
    }
}

proc ::Jabber::Login::HttpProxyCmd {status msg} {
    
    ::Debug 2 "::Jabber::Login::HttpProxyCmd status=$status, msg=$msg"
    
    switch -- $status {
	ok {
	    
	}
	default {
	    ::Jabber::DoCloseClientConnection
	    tk_messageBox -title [mc Error] -icon error \
	      -message "The HTTP jabber service replied with a status\
	      $status and message: $msg"
	}
    }
}

# Jabber::Login::ConnectCB --
#
#       Callback when socket has been opened. Logins.
#       
# Arguments:
#       cmd         callback command
#       status      "error", "timeout", or "ok".
#       
# Results:
#       Callback initiated.

proc ::Jabber::Login::ConnectCB {cmd sock ip port status {msg {}}} {    
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::Login::ConnectCB"
    
    switch $status {
	error - timeout {
	    ::Jabber::UI::SetStatusMessage ""
	    ::Jabber::UI::StartStopAnimatedWave 0
	    ::Jabber::UI::FixUIWhen "disconnect"
	}
	default {
	    set jstate(sock) $sock
	    
	    $jstate(jlib) setsockettransport $jstate(sock)
	}
    }    
    uplevel #0 $cmd [list $status $msg]
}

# Jabber::Login::InitStream --
# 
#       Sends the init stream xml command. When received servers stream,
#       invokes the cmd callback.
#       
# Arguments:
#       server      host
#       cmd         callback command
#       
# Results:
#       Callback initiated.

proc ::Jabber::Login::InitStream {server cmd} {
    upvar ::Jabber::jstate jstate
    
    ::Jabber::UI::SetStatusMessage [mc jawaitxml $server]
    
    # Initiate a new stream. We should wait for the server <stream>.
    if {[catch {
	$jstate(jlib) openstream $server  \
	  -cmd [list [namespace current]::InitStreamCB $cmd]
    } err]} {
	::Jabber::UI::SetStatusMessage ""
	::Jabber::UI::StartStopAnimatedWave 0
	::Jabber::UI::FixUIWhen "disconnect"
	return -code error $err
    }
}

proc ::Jabber::Login::InitStreamCB {cmd jlibName args} {

    # One of args shall be -id hexnumber
    uplevel #0 $cmd $args
}

# Jabber::Login::Authorize --
# 
#       A fairly general method for authentication. Handles UI stuff, but
#       does not show any message boxes.
#       
# Arguments:
#       server
#       username
#       resource
#       password
#       cmd         callback command
#       args:
#           -digest  0|1
#           -streamid 
#       
# Results:
#       Callback initiated.

proc ::Jabber::Login::Authorize {server username resource password cmd args} {
    variable uid
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::Login::Authorize"
    array set argsArr {
	-digest     1
	-streamid   ""
    }
    array set argsArr $args

    # Initialize the state variable, an array, that keeps is the storage.
    
    set token [namespace current]::auth[incr uid]
    variable $token
    upvar 0 $token state

    set state(server)     $server
    set state(username)   $username
    set state(resource)   $resource
    set state(password)   $password
    set state(streamid)   $argsArr(-streamid)
    set state(cmd)        $cmd
    
    if {$argsArr(-digest)} {
	if {$argsArr(-streamid) == ""} {
	    return -code error "missing -streamid for -digest"
	}
	set digestedPw [::sha1pure::sha1 $state(streamid)${password}]
	$jstate(jlib) send_auth $username $resource   \
	  [list [namespace current]::AuthorizeCB $token] -digest $digestedPw
    } else {
	$jstate(jlib) send_auth $username $resource   \
	  [list [namespace current]::AuthorizeCB $token] -password $password
    }
}

proc ::Jabber::Login::AuthorizeCB {token jlibName type theQuery} {
    global  this

    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver

    ::Debug 2 "::Jabber::Login::AuthorizeCB type=$type, theQuery='$theQuery'"
    
    set server   $state(server)
    set username $state(username)
    set resource $state(resource)
    set password $state(password)
    set cmd      $state(cmd)
    set msg      ""

    ::Jabber::UI::StartStopAnimatedWave 0
    
    if {[string equal $type "error"]} {	
	set errcode [lindex $theQuery 0]
	set errmsg [lindex $theQuery 1]
	::Jabber::UI::SetStatusMessage [mc jaerrlogin $server $errmsg]
	::Jabber::UI::FixUIWhen "disconnect"
	if {$errcode == 409} {
	    set msg [mc jamesslogin409 $errcode]
	} else {
	    set msg [mc jamessloginerr $errcode $errmsg]
	}

	# There is a potential problem if called from within a xml parser 
	# callback which makes the subsequent parsing to fail. (after idle?)
	after idle $jstate(jlib) closestream
    } else {    
	foreach {ip addr port} [fconfigure $jstate(sock) -sockname] break
	set jstate(ipNum) $ip
	if {$ip != "0.0.0.0"} {
	    set this(ipnum) $ip
	}
	
	# Ourself. Do JIDPREP? So far only on the domain name.
	set server               [jlib::jidmap $server]
	set jstate(mejid)        ${username}@${server}
	set jstate(meres)        $resource
	set jstate(mejidres)     "$jstate(mejid)/${resource}"
	set jstate(mejidmap)     [jlib::jidmap $jstate(mejid)]
	set jstate(mejidresmap)  [jlib::jidmap $jstate(mejidres)]
	set jserver(this)        $server
	
	# Run all login hooks. We do this to get our roster before we get presence.
	::hooks::run loginHook
    }
    uplevel #0 $cmd [list $type $msg]
    
    # Cleanup
    unset state
}

#-------------------------------------------------------------------------------
