#  Login.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements functions for logging in at different application levels.
#      
#  Copyright (c) 2001-2005  Mats Bengtsson
#  
# $Id: Login.tcl,v 1.60 2005-02-24 13:58:08 matben Exp $

package provide Login 1.0

namespace eval ::Login:: {
    
    variable server
    variable username
    variable password
    variable uid

    set uid 0
    
    # Add all event hooks.
    ::hooks::register quitAppHook     ::Login::QuitAppHook
    ::hooks::register closeWindowHook ::Login::CloseHook
    ::hooks::register launchFinalHook ::Login::LaunchHook
}

# Login::Dlg --
#
#       Log in to a server with an existing user account.
#
# Arguments:
#       
# Results:
#       none

proc ::Login::Dlg { } {
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
    
    LoadProfiles

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
    set token [namespace current]::moreOpts
    variable $token
    upvar 0 $token options
    set wtabnb $wfrmfr.nb
    ::Profiles::NotebookOptionWidget $wtabnb $token
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
    bind $w <Escape>  [list ::Login::DoCancel $w]
    bind $w <Destroy> [list ::Login::DoCancel $w]
    if {$password == ""} {
	focus $frmid.epass
    }
}

proc ::Login::LoadProfiles { } {
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
    foreach {name spec} [::Profiles::GetList] {
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

proc ::Login::TraceMenuVar {name key op} {
    global  prefs
    
    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable menuVar
    variable tmpProfArr
    variable moreOpts
    
    ::Profiles::NotebookSetDefaults [namespace current]::moreOpts
    
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

proc ::Login::CloseHook {wclose} {
    global  wDlgs
    variable finished
    
    if {[string equal $wclose $wDlgs(jlogin)]} {
	set finished 0
	Close $wclose
    }
}

proc ::Login::MoreOpts {w} {
    variable wtri
    variable wtrilab
    variable wfrmore
      
    pack $wfrmore -side top -fill x -padx 10
    $wtri configure -image [::UI::GetIcon mactriangleopen]
    $wtrilab configure -text "[mc Less]..."
    bind $wtri <Button-1> [list [namespace current]::LessOpts $w]
}

proc ::Login::LessOpts {w} {
    variable wtri
    variable wtrilab
    variable wfrmore
    
    pack forget $wfrmore
    $wtri configure -image [::UI::GetIcon mactriangleclosed]
    $wtrilab configure -text "[mc More]..."
    bind $wtri <Button-1> [list [namespace current]::MoreOpts $w]
}

proc ::Login::DoCancel {w} {
    variable finished

    set finished 0
    Close $w
}

proc ::Login::Profiles { } {
    
    ::Profiles::BuildDialog
}

proc ::Login::Close {w} {
    variable menuVar
    
    # Clean up.
    ::UI::SaveWinGeom $w
    ::Profiles::SetSelectedName $menuVar
    trace vdelete [namespace current]::menuVar w  \
      [namespace current]::TraceMenuVar
    catch {grab release $w}
    catch {destroy $w}    
}

# Login::DoLogin --
# 
#       Starts the login process.

proc ::Login::DoLogin {} {
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
    
    ::Debug 2 "::Login::DoLogin"
    
    # Kill any pending open states.
    ::Network::KillAll
    ::Jabber::UI::SetStatusMessage ""
    ::Jabber::UI::StartStopAnimatedWave 0
    
    # Check 'server', 'username' and 'password' if acceptable.
    foreach name {server username password} {
	upvar 0 $name var
	if {[string length $var] <= 1} {
	    ::UI::MessageBox -icon error -type ok \
	      -message [mc jamessnamemissing $name]
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
	    ::UI::MessageBox -icon error -type ok \
	      -message [mc jamessillegalchar $name $var]
	    return
	}
    }    
    set finished 1
    Close $wtoplevel
    
    set opts {}
    foreach {key value} [array get moreOpts] {
	lappend opts -$key $value
    }
    # ssl vs. tls naming conflict.
    if {$moreOpts(ssl)} {
	lappend opts -tls 1
    }
    eval {HighLogin $server $username $resource $password \
      [namespace current]::LoginCallback} $opts
}

proc ::Login::LoginCallback {token status {errmsg ""}} {
    variable $token
    upvar 0 $token state
    
    ::Debug 2 "::Login::LoginCallback"
    
    ShowAnyMessageBox $token $status $errmsg
}

#       Show message box if necessary.

proc ::Login::ShowAnyMessageBox {token status {errmsg ""}} {
    variable $token
    upvar 0 $token state
    
    ::Debug 2 "::Login::DoLoginHighCB status=$status errmsg=$errmsg"
    
    set str ""
    
    switch -- $status {
	ok {
	    # empty
	}
	connect-failed {
	    set str [mc jamessnosocket $state(server) $errmsg]
	}
	timeout {
	    set str [mc jamesstimeoutserver $state(server)]
	}
	authfail {
	    set str $errmsg
	}
	starttls-nofeature {
	    set str [mc jamessstarttls-nofeature $state(server)]
	}
	startls-failure {
	    set str [mc jamessstarttls-failure $state(server)]
	}
	default {
	    set str $errmsg
	}
    }
    if {$str != ""} {
	::UI::MessageBox -icon error -type ok -message $str
    }
}

proc ::Login::SetStatus {args} {
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
	eval {::Jabber::SetStatus invisible} $presArgs
    } else {
	eval {::Jabber::SetStatus available -notype 1} $presArgs
    }    
}

# Login::LaunchHook --
# 
#       Method to automatically login after launch.

proc ::Login::LaunchHook { } {
    upvar ::Jabber::jprefs jprefs
    
    if {!$jprefs(autoLogin)} {
	return ""
    }
    
    # Use our selected profile.
    set profname [::Profiles::GetSelectedName]
    set password [::Profiles::Get $profname password]
    set ans "ok"
    if {$password == ""} {
	set ans [::UI::MegaDlgMsgAndEntry  \
	  [mc {Password}] [mc enterpassword $state(jid)] "[mc Password]:" \
	  password [mc Cancel] [mc OK] -show {*}]
    }
    if {$ans == "ok"} {
	set domain [::Profiles::Get $profname domain]
	set node   [::Profiles::Get $profname node]
	set opts   [::Profiles::Get $profname options]
	array set optsArr $opts
	if {[info exists optsArr(-resource)] && ($optsArr(-resource) != "")} {
	    set res $optsArr(-resource)
	} else {
	    set res "coccinella"
	}
	eval {::Login::HighLogin $domain $node $res $password \
	  [namespace current]::AutoLoginCB} $opts
    }
}

proc ::Login::QuitAppHook { } {
    global  wDlgs
    
    ::UI::SaveWinGeom $wDlgs(jlogin)    
}

proc ::Login::AutoLoginCB {logtoken status {errmsg ""}} {

    ::Login::ShowAnyMessageBox $logtoken $status $errmsg
}

#-------------------------------------------------------------------------------

# Initialize the complete login processs and receive callback when finished.
# Sort of high level call at application level. Handles all UI except
# any message boxes.

# Login::HighLogin --
# 
#       Initializes the login procedure. Callback when finished with status.
#       
# Arguments:
#       server
#       username
#       resource
#       password
#       cmd         callback command
#       args:
#           -digest  0|1
#           -httpproxy
#           -invisible  0|1
#           -ip
#           -priority
#           -sasl
#           -ssl        0|1 (synonym for -tls)
#           -tls
#       
# Results:
#       Callback initiated.

proc ::Login::HighLogin {server username resource password cmd args} {
    global  prefs
    variable uid
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Login::HighLogin args=$args"
    
    array set argsArr {
	-digest         1
	-httpproxy      0
	-invisible      0
	-ip             ""
	-priority       0
	-sasl           0
	-ssl            0
	-tls            0
    }
    set argsArr(-port) $jprefs(port)
    array set argsArr $args
    if {$resource == ""} {
	set resource "coccinella"
    }

    # Initialize the state variable, an array, that keeps is the storage.
    
    set token [namespace current]::high[incr uid]
    variable $token
    upvar 0 $token state

    set state(server)     $server
    set state(username)   $username
    set state(resource)   $resource
    set state(password)   $password
    set state(cmd)        $cmd
    foreach {key value} [array get argsArr] {
	set state($key) $value
    }
    
    # -ssl synonym for -tls.
    if {$state(-ssl)} {
	set state(-tls) 1
    }
    
    # The "old" jabber protocol uses a designated port number for ssl
    # connections. 
    # In xmpp tls negotiating is made in stream using the standard port.
    set opts {}
    if {!$state(-sasl) && $state(-tls)} {
	lappend opts -tls 1
    }
    if {$state(-httpproxy)} {
	lappend opts -httpproxy 1
    }
    if {$state(-ip) != ""} {
	lappend opts -ip $argsArr(-ip)
    }
    
    # Make a network connection.
    eval {Connect $server [list [namespace current]::HighConnectCB $token] \
      -port $state(-port)} $opts
}

proc ::Login::HighConnectCB {token status msg} {
    variable $token
    upvar 0 $token state
    
    ::Debug 2 "::Login::HighConnectCB status=$status"
    
    switch $status {
	error {
	    HighFinish $token connect-failed $msg
	}
	timeout {
	    HighFinish $token timeout $msg
	}
	default {
	    set opts {}
	    if {$state(-sasl)} {
		lappend opts -sasl 1
	    }
	    if {[catch {
		eval {InitStream $state(server) \
		  [list [namespace current]::HighInitStreamCB $token]} $opts
	    } err]} {
		HighFinish $token connect-failed $err
	    }
	}
    }
}

proc ::Login::HighInitStreamCB {token args} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Login::HighInitStreamCB"
    
    array set argsArr $args

    if {![info exists argsArr(id)]} {
	HighFinish $token missingid "no id for digest in receiving <stream>"
    } else {

	# If we are trying to use sasl indicated by version='1.0' we must also
	# be sure to receive a version attribute larger or equal to 1.0.
	set trysasl $state(-sasl)
	if {$state(-sasl)} {
	    if {[info exists argsArr(version)]} {
		if {[package vcompare $argsArr(version) 1.0] == -1} {
		    set state(-sasl) 0
		}
	    } else {
		set state(-sasl) 0
	    }
	}
	if {$trysasl && !$state(-sasl)} {
	    ::Jabber::AddErrorLog $state(server)  \
	      "SASL authentization failed since server does not support version=1.0"
	}
	set starttls 0
	if {$state(-sasl) && $state(-tls)} {
	    set starttls 1
	}
	
	# We cannot verify that server supports tls since we have not yet
	# received the 'features' element. Done inside jlib.
		
	# We either start tls or authorize.
	if {$starttls} {
	    StartTls [list [namespace current]::HighStartTlsCB $token]
	} else {
	    Authorize $state(server) $state(username) $state(resource) \
	      $state(password) \
	      [list [namespace current]::HighAuthorizeCB $token] \
	      -streamid $argsArr(id) -digest $state(-digest) -sasl $state(-sasl)
	}    
    }    
}

proc ::Login::HighStartTlsCB {token type args} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Login::HighStartTlsCB type=$type args=$args"
    
    if {[string equal $type "error"]} {
	foreach {errcode errmsg} [lindex $args 0] break
	HighFinish $token $errcode $errmsg
    } else {
	set id [$jstate(jlib) getstreamattr id]
	if {$id == ""} {
	    HighFinish $token missingid \
	      "no id for digest in receiving <stream>"
	} else {
	    Authorize $state(server) $state(username) $state(resource) \
	      $state(password) \
	      [list [namespace current]::HighAuthorizeCB $token] \
	      -streamid $id -digest $state(-digest) -sasl $state(-sasl)
	}
    }
}

proc ::Login::HighAuthorizeCB {token type msg} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Login::HighAuthorizeCB type=$type"

    switch -- $type {
	error {
	    HighFinish $token authfail $msg
	}
	default {

	    # Login was succesful, set presence.
	    set opts {}
	    if {$state(-priority) != 0} {
		lappend opts -priority $state(-priority)
	    }
	    if {$state(-invisible)} {
		eval {::Jabber::SetStatus invisible} $opts
	    } else {
		eval {::Jabber::SetStatus available -notype 1} $opts
	    }    
	    HighFinish $token
	}
    }
}

proc ::Login::HighFinish {token {err ""} {msg ""}} {
    variable $token
    upvar 0 $token state
   
    ::Jabber::UI::SetStatusMessage ""
    ::Jabber::UI::StartStopAnimatedWave 0
    if {$err == ""} {
	uplevel #0 $state(cmd) $token ok
    } else {
	::Jabber::UI::FixUIWhen "disconnect"
	uplevel #0 $state(cmd) [list $token $err $msg]
    }
    unset state
}

#-------------------------------------------------------------------------------

# A few functions to handle each stage in the login process as a separate
# component:
#       o connect socket
#       o initialize the stream
#       o start tls
#       o authorize
#       
# They get and set jstate and other state variables. User interface elements
# are set, but no message boxes are shown. That is up to the caller.


# Login::Connect --
#
#       Initiates a login to a server with an existing user account.
#
# Arguments:
#       server
#       cmd         callback command when socket connected
#       args  -ip
#             -port
#             -tls 0|1
#             -httpproxy 0|1
#       
# Results:
#       Callback scheduled.

proc ::Login::Connect {server cmd args} {
    global  prefs

    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Login::Connect args=$args"
    
    array set argsArr {
	-ip         ""
	-tls        0
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
    if {$argsArr(-tls)} {
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
    
    # The "old" jabber protocol uses a designated port number for ssl
    # connections. 
    # In xmpp tls negotiating is made in stream using the standard port.
    
    # Open socket unless we are using a http proxy.
    if {!$argsArr(-httpproxy)} {
	::Network::Open $host $port [list [namespace current]::ConnectCB $cmd] \
	  -timeout $prefs(timeoutSecs) -tls $argsArr(-tls)
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

proc ::Login::HttpProxyCmd {status msg} {
    
    ::Debug 2 "::Login::HttpProxyCmd status=$status, msg=$msg"
    
    switch -- $status {
	ok {
	    # only errors are handled via callback
	}
	default {
	    ::Jabber::DoCloseClientConnection
	    ::UI::MessageBox -title [mc Error] -icon error \
	      -message "The HTTP jabber service replied with a status\
	      $status and message: $msg"
	}
    }
}

# Login::ConnectCB --
#
#       Callback when socket has been opened. Logins.
#       
# Arguments:
#       cmd         callback command
#       status      "error", "timeout", or "ok".
#       
# Results:
#       Callback initiated.

proc ::Login::ConnectCB {cmd sock ip port status {msg {}}} {    
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Login::ConnectCB"
    
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

# Login::InitStream --
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

proc ::Login::InitStream {server cmd args} {
    upvar ::Jabber::jstate jstate
    
    ::Jabber::UI::SetStatusMessage [mc jawaitxml $server]
    set opts {}
    foreach {key value} $args {
	switch -- $key {
	    -sasl {
		lappend opts -version 1.0
	    }
	}
    }
    
    # Initiate a new stream. We should wait for the server <stream>.
    if {[catch {
	eval {$jstate(jlib) openstream $server  \
	  -cmd [list [namespace current]::InitStreamCB $cmd]} $opts
    } err]} {
	::Jabber::UI::SetStatusMessage ""
	::Jabber::UI::StartStopAnimatedWave 0
	::Jabber::UI::FixUIWhen "disconnect"
	return -code error $err
    }
}

proc ::Login::InitStreamCB {cmd jlibName args} {
    
    # One of args shall be -id hexnumber
    uplevel #0 $cmd $args
}

# Login::StartTls --
# 
# 

proc ::Login::StartTls {cmd} {
    upvar ::Jabber::jstate jstate
    
    ::Jabber::UI::SetStatusMessage [mc jatlsnegot]
    $jstate(jlib) starttls [list [namespace current]::StartTlsCB $cmd]    
}

proc ::Login::StartTlsCB {cmd jlibName type args} {
    upvar ::Jabber::jstate jstate

    if {[string equal $type "error"]} {	
	::Jabber::UI::FixUIWhen "disconnect"
	after idle $jstate(jlib) closestream
    }    
    uplevel #0 $cmd $type $args
}

# Login::Authorize --
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
#           -sasl
#       
# Results:
#       Callback initiated.

proc ::Login::Authorize {server username resource password cmd args} {
    variable uid
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Login::Authorize"
    
    array set argsArr {
	-digest     1
	-streamid   ""
	-sasl       0
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
    
    if {$argsArr(-sasl)} {
	$jstate(jlib) auth_sasl $username $resource $password  \
	  [list [namespace current]::AuthorizeCB $token]
    } elseif {$argsArr(-digest)} {
	if {$argsArr(-streamid) == ""} {
	    return -code error "missing -streamid for -digest"
	}
	set digestedPw [::sha1pure::sha1 $state(streamid)${password}]
	$jstate(jlib) send_auth $username $resource   \
	  [list [namespace current]::AuthorizeCB $token] -digest $digestedPw
    } else {
	
	# Plain password authentization.
	$jstate(jlib) send_auth $username $resource   \
	  [list [namespace current]::AuthorizeCB $token] -password $password
    }
}

proc ::Login::AuthorizeCB {token jlibName type theQuery} {
    global  this

    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver

    ::Debug 2 "::Login::AuthorizeCB type=$type, theQuery='$theQuery'"
    
    set server   $state(server)
    set username $state(username)
    set resource $state(resource)
    set password $state(password)
    set cmd      $state(cmd)
    set msg      ""

    ::Jabber::UI::StartStopAnimatedWave 0
    
    if {[string equal $type "error"]} {	
	foreach {errcode errmsg} $theQuery break
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
	set this(ipnum)   $ip
	::Debug 4 "\t this(ipnum)=$ip"
	
	# Ourself. Do JIDPREP? So far only on the domain name.
	set server               [jlib::jidmap $server]
	set jstate(mejid)        [jlib::joinjid $username $server ""]
	set jstate(meres)        $resource
	set jstate(mejidres)     [jlib::joinjid $username $server $resource]
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
