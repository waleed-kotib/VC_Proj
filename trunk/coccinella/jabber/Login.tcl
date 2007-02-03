#  Login.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements functions for logging in at different application levels.
#      
#  Copyright (c) 2001-2006  Mats Bengtsson
#  
# $Id: Login.tcl,v 1.111 2007-02-03 06:42:06 matben Exp $

package provide Login 1.0

namespace eval ::Login:: {
    
    # Use option database for customization.
    option add *JLogin.connectImage             connect         widgetDefault
    option add *JLogin.connectDisImage          connectDis      widgetDefault

    variable server
    variable username
    variable password
    variable uid 0
    variable pending 0
    
    # Add all event hooks.
    ::hooks::register quitAppHook     ::Login::QuitAppHook
    ::hooks::register launchFinalHook ::Login::LaunchHook
    
    # Config settings.
    set ::config(login,style) "jid"  ;# jid | username | parts
    set ::config(login,more)         1
    set ::config(login,profiles)     1
    set ::config(login,autosave)     0
    set ::config(login,autoregister) 0
    set ::config(login,dnssrv)       1
    set ::config(login,dnstxthttp)   1
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
    global  this prefs config wDlgs
    
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
    variable wtabnb
    variable wpopupMenu
    variable tmpProfArr
    upvar ::Jabber::jprefs jprefs
    
    set w $wDlgs(jlogin)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    set wtoplevel $w
    
    ::UI::Toplevel $w -class JLogin \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand [namespace current]::Close
    wm title $w [mc Login]

    ::UI::SetWindowPosition $w
    
    set connectim   [::Theme::GetImage [option get $w connectImage {}]]
    set connectimd  [::Theme::GetImage [option get $w connectDisImage {}]]
    
    # Global frame.
    ttk::frame $w.frall
    pack  $w.frall  -fill x
                                 
    ttk::label $w.frall.head -style Headlabel \
      -text [mc Login] -compound left \
      -image [list $connectim background $connectimd]
    pack  $w.frall.head  -side top -fill both -expand 1

    ttk::separator $w.frall.s -orient horizontal
    pack  $w.frall.s  -side top -fill x

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack  $wbox  -fill both -expand 1

    if {$config(login,style) eq "jid"} {
	set str [mc jaloginjid]
    } elseif {$config(login,style) eq "parts"} {
	set str [mc jalogin]
    } elseif {$config(login,style) eq "username"} {
	set domain [::Profiles::Get [::Profiles::GetSelectedName] domain]
	set str [mc jaloginuser $domain]
    }
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 300 -justify left -text $str
    pack  $wbox.msg  -side top -fill x
    
    set frmid $wbox.frmid
    ttk::frame $frmid
    pack  $frmid  -side top -fill both -expand 1
	
    # Option menu for selecting user profile.
    ttk::label $frmid.lpop -text "[mc Profile]:" -anchor e
    set wpopup $frmid.popup

    set menuVar [::Profiles::GetSelectedName]
    set wpopupMenu [ttk::optionmenu $wpopup [namespace current]::menuVar {}]
    
    # Depending on 'config(login,style)' not all get mapped.
    ttk::label $frmid.ljid -text "[mc {Jabber ID}]:" -anchor e
    ttk::entry $frmid.ejid -width 22    \
      -textvariable [namespace current]::jid
    ttk::label $frmid.lserv -text "[mc {Jabber Server}]:" -anchor e
    ttk::entry $frmid.eserv -width 22    \
      -textvariable [namespace current]::server -validate key  \
      -validatecommand {::Jabber::ValidateDomainStr %S}
    ttk::label $frmid.luser -text "[mc Username]:" -anchor e
    ttk::entry $frmid.euser -width 22   \
      -textvariable [namespace current]::username -validate key  \
      -validatecommand {::Jabber::ValidateUsernameStr %S}
    ttk::label $frmid.lpass -text "[mc Password]:" -anchor e
    ttk::entry $frmid.epass -width 22   \
      -textvariable [namespace current]::password -show {*} -validate key \
      -validatecommand {::Jabber::ValidatePasswordStr %S}
    ttk::label $frmid.lres -text "[mc Resource]:" -anchor e
    ttk::entry $frmid.eres -width 22   \
      -textvariable [namespace current]::resource -validate key  \
      -validatecommand {::Jabber::ValidateResourceStr %S}
    
    if {$config(login,style) eq "jid"} {
	grid  $frmid.lpop   $frmid.popup  -sticky e -pady 2
	grid  $frmid.ljid   $frmid.ejid   -sticky e -pady 2
	grid  $frmid.lpass  $frmid.epass  -sticky e -pady 2
	
	grid  $frmid.popup  -sticky ew
	grid  $frmid.ejid   $frmid.epass  -sticky ew
    } elseif {$config(login,style) eq "parts"} {
	grid  $frmid.lpop   $frmid.popup  -sticky e -pady 2
	grid  $frmid.lserv  $frmid.eserv  -sticky e -pady 2
	grid  $frmid.luser  $frmid.euser  -sticky e -pady 2
	grid  $frmid.lpass  $frmid.epass  -sticky e -pady 2
	grid  $frmid.lres   $frmid.eres   -sticky e -pady 2
	
	grid  $frmid.popup  -sticky ew
	grid  $frmid.eserv  $frmid.euser  $frmid.epass  $frmid.eres  -sticky ew
    } elseif {$config(login,style) eq "username"} {
	grid  $frmid.luser  $frmid.euser  -sticky e -pady 2
	grid  $frmid.lpass  $frmid.epass  -sticky e -pady 2

	grid  $frmid.euser  $frmid.epass  -sticky ew
    }
    grid columnconfigure $frmid 1 -weight 1
    
    # Triangle switch for more options.
    if {$config(login,more)} {
	set wtri $wbox.tri
	# @@@ Experiment! Try Arrow.TCheckbutton with extra text padding.
	if {0} {
	    ttk::button $wtri -style Small.Toolbutton -padding {6 1} \
	      -compound left -image [::UI::GetIcon mactriangleclosed] \
	      -text "[mc More]..." -command [list [namespace current]::MoreOpts $w]
	} elseif {1} {
	    ttk::button $wtri -style Small.Plain -padding {6 1} \
	      -compound left -image [::UI::GetIcon closeAqua] \
	      -text "[mc More]..." -command [list [namespace current]::MoreOpts $w]
	} else {
	    ttk::checkbutton $wtri -style ArrowText.TCheckbutton \
	      -text "[mc More]..." -command [list [namespace current]::MoreOpts $w]
	}
	pack $wtri -side top -anchor w
	
	# More options.
	set wfrmore $wbox.frmore
	ttk::frame $wfrmore
	
	# Tabbed notebook for more options.
	set token [namespace current]::moreOpts
	variable $token
	upvar 0 $token options
	
	set wtabnb $wfrmore.nb
	::Profiles::NotebookOptionWidget $wtabnb $token
	pack  $wtabnb  -fill x -expand 1
    }
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Login] \
      -default active -command [namespace current]::DoLogin
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::DoCancel $w]
    ttk::button $frbot.btprof -text [mc Profiles]  \
      -command [namespace current]::Profiles
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
	if {$config(login,profiles)} {
	    pack $frbot.btprof -side left
	}
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
	if {$config(login,profiles)} {
	    pack $frbot.btprof -side left
	}
    }
    pack $frbot -side bottom -fill x
    
    LoadProfiles
    
    # Necessary to trace the popup menu variable.
    trace variable [namespace current]::menuVar w  \
      [namespace current]::TraceMenuVar
    set menuVar $profile
	
    wm resizable $w 0 0
    
    bind $w <<ReturnEnter>> [list $frbot.btok invoke]
    
    if {$password eq ""} {
	focus $frmid.epass
    }
    after 100 [list [namespace current]::GetNormalSize $w]
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
    global  prefs this config
    
    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable jid
    variable menuVar
    variable tmpProfArr
    variable moreOpts
    variable wtabnb
    
    set profile  [set $name]
    set server   $tmpProfArr($profile,server)
    set username $tmpProfArr($profile,username)
    set password $tmpProfArr($profile,password)
    
    if {$config(login,more)} {
	::Profiles::NotebookSetDefaults [namespace current]::moreOpts $server
	
	foreach {key value} [array get tmpProfArr $profile,-*] {
	    set optname [string map [list $profile,- ""] $key]
	    if {$optname ne "resource"} {
		set moreOpts($optname) $value
	    }
	}
	set resource $tmpProfArr($profile,-resource)
	set jid [jlib::joinjid $username $server $resource]
	::Profiles::NotebookSetAnyConfigState $wtabnb $profile
	::Profiles::NotebookDefaultWidgetStates $wtabnb
    }
}

proc ::Login::GetNormalSize {w} {
    variable size
    
    set geom [::UI::ParseWMGeometry [wm geometry $w]]
    set size(width)  [lindex $geom 0]
    set size(height) [lindex $geom 1]
}

proc ::Login::SetNormalSize {w} {
    variable size

    wm geometry $w $size(width)x$size(height)
}

proc ::Login::MoreOpts {w} {
    variable wtri
    variable wfrmore

    pack $wfrmore -side top -fill x -padx 2
    $wtri configure -command [list [namespace current]::LessOpts $w] \
      -image [::UI::GetIcon openAqua] -text "[mc Less]..."   
}

proc ::Login::LessOpts {w} {
    variable wtri
    variable wfrmore

    SetNormalSize $w
    update idletasks
    
    pack forget $wfrmore
    $wtri configure -command [list [namespace current]::MoreOpts $w] \
      -image [::UI::GetIcon closeAqua] -text "[mc More]..."   
    after 100 [list wm geometry $w {}]
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
    variable tmpProfArr
    
    # Clean up.
    ::UI::SaveWinGeom $w
    ::Profiles::SetSelectedName $menuVar
    trace vdelete [namespace current]::menuVar w  \
      [namespace current]::TraceMenuVar
    array unset tmpProfArr
    catch {grab release $w}
    catch {destroy $w}    
}

# Login::Reset --
# 
#       This resets the complete login process.
#       Must take care of everything.

proc ::Login::Reset { } {
    variable pending
    upvar ::Jabber::jstate jstate

    set pending 0
    $jstate(jlib) connect reset

    ::JUI::SetStatusMessage ""
    ::JUI::StartStopAnimatedWave 0
    ::JUI::FixUIWhen "disconnect"
    ::JUI::SetConnectState "disconnect"
}

# Login::DoLogin --
# 
#       Starts the login process.

proc ::Login::DoLogin {} {
    global  prefs config

    variable wtoplevel
    variable finished
    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable jid
    variable moreOpts
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Login::DoLogin"
    
    # Reset any pending open states.
    Reset

    if {$config(login,style) eq "jid"} {
	jlib::splitjidex $jid username server resource
    }
    
    # Check 'server', 'username' and 'password' if acceptable.
    foreach name {server username password} {
	upvar 0 $name var
	if {[string length $var] <= 1} {
	    ::UI::MessageBox -icon error -type ok \
	      -message [mc jamessnamemissing $name]
	    return
	}
	if {$name eq "password"} {
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

    # Verify http url if any.
    if {0 && [info exists moreOpts(http)] && $moreOpts(http)} {
	if {![::Utils::IsWellformedUrl $moreOpts(httpurl)]} {
	    ::UI::MessageBox -icon error -type ok \
	      -message "The url \"$moreOpts(httpurl)\" is invalid."
	    return
	}
    }
    
    set opts {}
    foreach {key value} [array get moreOpts] {
	lappend opts -$key $value
    }
    
    # Should login settings be automatically saved to profile.
    if {$config(login,autosave)} {
	eval {::Profiles::Set $profile $server $username $password} $opts
    }
    
    set finished 1
    Close $wtoplevel

    eval {HighLogin $server $username $resource $password \
      [namespace current]::LoginCallback} $opts
}

proc ::Login::LoginCallback {token {errcode ""} {errmsg ""}} {
    
    ::Debug 2 "::Login::LoginCallback"
    # empty
}

# Login::LaunchHook --
# 
#       Method to automatically login after launch.

proc ::Login::LaunchHook { } {
    upvar ::Jabber::jprefs jprefs
    
    if {!$jprefs(autoLogin)} {
	return
    }
    
    # Use our selected profile.
    set profname [::Profiles::GetSelectedName]
    set domain   [::Profiles::Get $profname domain]
    set node     [::Profiles::Get $profname node]
    set password [::Profiles::Get $profname password]
    set jid [jlib::joinjid $node $domain ""]
    set ans "ok"
    if {$password eq ""} {
	set ans [::UI::MegaDlgMsgAndEntry  \
	  [mc {Password}] [mc enterpassword $jid] "[mc Password]:" \
	  password [mc Cancel] [mc OK] -show {*}]
    }
    if {$ans eq "ok"} {
	set opts   [::Profiles::Get $profname options]
	array set optsArr $opts
	if {[info exists optsArr(-resource)] && ($optsArr(-resource) ne "")} {
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

proc ::Login::AutoLoginCB {token {errcode ""} {errmsg ""}} {
    # empty
}

#-------------------------------------------------------------------------------

# Initialize the complete login processs and receive callback when finished.
# Sort of high level call at application level. Handles all UI.

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
#           -digest     0|1
#           -http       0|1
#           -httpurl
#           -invisible  0|1
#           -ip
#           -priority
#           -secure     0|1
#           -method     ssl|tlssasl|sasl
#           
#           Note the naming convention for -method!
#            ssl        using direct tls socket connection
#                       it corresponds to the original jabber method
#            tlssasl    in stream tls negotiation + sasl, xmpp compliant
#                       XMPP requires sasl after starttls!
#            sasl       only sasl authentication
#       
# Results:
#       token

proc ::Login::HighLogin {server username resource password cmd args} {
    global  config
    variable pending
    variable uid
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
        
    ::Debug 2 "::Login::HighLogin args=$args"
        
    # Initialize the state variable, an array, that keeps some storage. 
    # The rest is stored in the jlib::connect object. Do not duplicate this!   
    set token [namespace current]::high[incr uid]
    variable $token
    upvar 0 $token highstate

    set highstate(cmd)     $cmd
    set highstate(args)    $args
    set highstate(pending) 1

    ::JUI::SetStatusMessage [mc jawaitresp $server]
    ::JUI::StartStopAnimatedWave 1
    ::JUI::FixUIWhen "connectinit"
    ::JUI::SetConnectState "connectinit"
    
    set pending 1

    jlib::connect::configure              \
      -defaultresource "coccinella"       \
      -defaultport $jprefs(port)          \
      -defaultsslport $jprefs(sslport)    \
      -dnssrv $config(login,dnssrv)       \
      -dnstxthttp $config(login,dnstxthttp)
    
    set jid [jlib::joinjid $username $server $resource]
    set cb [list ::Login::HighLoginCB $token]
    eval {$jstate(jlib) connect connect $jid $password -command $cb} $args
    
    return $token
}

proc ::Login::HighLoginCB {token jlibname status {errcode ""} {errmsg ""}} {

    ::Debug 2 "::Login::HighLoginCB +++ status=$status, errcode=$errcode, errmsg=$errmsg"
    
    array set state [$jlibname connect get_state]
    
    switch -- $status {
	ok - error {
	    HighFinal $token $jlibname $status $errcode $errmsg
	}
	dnsresolve - initnetwork - authenticate {
	    # empty
	}
	initstream {
	    ::JUI::SetStatusMessage [mc jawaitxml $state(server)]
	}
	starttls {
	    ::JUI::SetStatusMessage [mc jatlsnegot]
	}
    }
}

proc ::Login::HighFinal {token jlibname status {errcode ""} {errmsg ""}} {
    
    variable $token
    upvar 0 $token highstate
    upvar ::Jabber::jstate jstate    
    variable pending
    
    set pending 0

    switch -- $status {
	ok {
	    set server [$jstate(jlib) getserver]
	    set msg [mc jaauthok $server] 
	    ::JUI::FixUIWhen "connectfin"
	    ::JUI::SetConnectState "connectfin"
	    SetLoginStateRunHook
	    
	    # Important to send presence *after* we request the roster (loginHook)!
	    eval {SetStatus} $highstate(args)
	}
	error {
	    set msg ""
	    ::JUI::FixUIWhen "disconnect"
	    ::JUI::SetConnectState "disconnect"
	    HandleErrorCode $errcode $errmsg
	}
    }        
    ::JUI::SetStatusMessage $msg
    ::JUI::StartStopAnimatedWave 0

    uplevel #0 $highstate(cmd) [list $token $errcode $errmsg]

    # Free all.
    unset highstate
    $jstate(jlib) connect free
}

proc ::Login::SetStatus {args} {
    
    array set argsA {
	-invisible    0
	-priority     0
    }
    array set argsA $args
    set presArgs {}
    if {$argsA(-priority) != 0} {
	lappend presArgs -priority $argsA(-priority)
    }    
    if {$argsA(-invisible)} {
	eval {::Jabber::SetStatus invisible} $presArgs
    } else {
	eval {::Jabber::SetStatus available -notype 1} $presArgs
    }    
}

proc ::Login::GetErrorStr {errcode {errmsg ""}} {
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Login::GetErrorStr errcode=$errcode, errmsg=$errmsg"

    array set state [jlib::connect::get_state $jstate(jlib)]
    set str ""
	
    switch -glob -- $errcode {
	connect-failed - network-failure - networkerror {
	    set str [mc jamessnosocket $state(server) $errmsg]
	}
	timeout {
	    set str [mc jamesstimeoutserver $state(server)]
	}
	409 {
	    set str [mc jamesslogin409 $errcode]
	}
	starttls-nofeature {
	    set str [mc starttls-nofeature $state(server)]
	}
	startls-failure - tls-failure {
	    set str [mc starttls-failure $state(server)]
	}
	sasl-no-mechanisms {
	    set str [mc sasl-no-mechanisms]
	}
	sasl-protocol-error {
	    set str [mc sasl-protocol-error]
	}
	xmpp-streams-error* {
	    set streamstag ""
	    regexp {xmpp-streams-error-(.+)$} $errcode - streamstag
	    set str [mc xmpp-streams-error $streamstag]
	}
	proxy-failure {
	    set str [mc jamessproxy-failure $errmsg]
	}
	default {
	    
	    # Identify the xmpp-stanzas.
	    if {$state(state) eq "authenticate"} {
		
		# Added 'bad-auth' which seems to be a ejabberd anachronism.
		set errcode [string map {bad-auth not-authorized} $errcode]		
		set str [mc xmpp-stanzas-short-$errcode]
	    } else {
		set str $errmsg
	    }
	}
    }
    return $str
}

# Login::HandleErrorCode --
# 
#       Show error message box.

proc ::Login::HandleErrorCode {errcode {errmsg ""}} {
    global  config
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Login::HandleErrorCode errcode=$errcode, errmsg=$errmsg"
    
    if {$errcode eq "reset"} {
	return
    }

    array set state [$jstate(jlib) connect get_state]
    set str [GetErrorStr $errcode $errmsg]
    set type ok
    set default ok
    
    # Do only try register new account if authorization failed.
    if {($state(state) eq "authenticate") && $config(login,autoregister)} {
	append str " " [mc jaregnewwith $state(server)]
	set type yesno
	set default no
    }
    set ans [::UI::MessageBox -icon error -type $type -default $default \
      -message $str]
    if {$ans eq "yes"} {
	::RegisterEx::New -server $state(server) -autoget 1
    }
}

proc ::Login::SetLoginStateRunHook {} {
    global  this
    upvar ::Jabber::jstate jstate
   
    ::Debug 2 "::Login::SetLoginStateRunHook"
    
    set jlib $jstate(jlib)

    # @@@ There is a lot of duplicates here. Remove! Keep in jabberlib only!
    set ip [$jlib getip]
    set jstate(ipNum) $ip
    set this(ipnum)   $ip
    
    # Ourself. Do JIDPREP? So far only on the domain name.
    # MUST handle situations with redirection (server alias)!

    set jid [$jlib myjid]
    jlib::splitjidex $jid username server resource

    set server               [jlib::jidmap [$jlib getserver]]
    set jstate(mejid)        [jlib::joinjid $username $server ""]
    set jstate(meres)        $resource
    set jstate(mejidres)     [jlib::joinjid $username $server $resource]
    set jstate(mejidmap)     [jlib::jidmap $jstate(mejid)]
    set jstate(mejidresmap)  [jlib::jidmap $jstate(mejidres)]
    set jstate(server)       $server
    
    # Run all login hooks. We do this to get our roster before we get presence.
    ::hooks::run loginHook
}

#-------------------------------------------------------------------------------
