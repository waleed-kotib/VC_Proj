#  Login.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements functions for logging in at different application levels.
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
# $Id: Login.tcl,v 1.148 2008-06-07 06:50:38 matben Exp $

package provide Login 1.0

namespace eval ::Login:: {
    
    # Use option database for customization.
    option add *JLogin.connectImage         network-disconnect      widgetDefault
    option add *JLogin.connectDisImage      network-disconnect-Dis  widgetDefault

    variable server
    variable username
    variable password
    variable uid 0
    variable pending 0
    
    # Add all event hooks.
    ::hooks::register quitAppHook     ::Login::QuitAppHook
    ::hooks::register launchFinalHook ::Login::LaunchHook
    
    # Config settings.
    # Controls which fields in login dialog to use.
    set ::config(login,style) "jid"  ;# jid | username | parts | jidpure
    
    # Shall we allow 'more' options?
    set ::config(login,more)         1
    set ::config(login,profiles)     0 ;# this leads to an inconsistent state!
    
    # Shall dialog options be saved to profile automatically?
    set ::config(login,autosave)     0
    set ::config(login,autoregister) 0
    
    # Shall we use DNS SRV/TXT lookups?
    set ::config(login,dnssrv)       1
    set ::config(login,dnstxthttp)   1
    set ::config(login,show-head)    1

    # Shall we ask the user to save the current options as default for this
    # profile if different?
    set ::config(login,ask-save-profile) 1
}

# Login::Dlg --
#
#       Log in to a server with an existing user account.
#
# Arguments:
#       
# Results:
#       none

proc ::Login::Dlg {} {
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
    variable wpopup
    variable tmpProfArr
    variable morevar
    
    # @@@ TODO: move widget names to 'widgets' array.
    variable widgets
    upvar ::Jabber::jprefs jprefs
    
    # Singleton.
    set w $wDlgs(jlogin)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    
    # Avoid any inconsistent UI state by closing any register dialog.
    # NB: Shall never happen since grab on Register dialog!
    #::RegisterEx::CloseAny

    set wtoplevel $w
    
    ::UI::Toplevel $w -class JLogin \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand [namespace current]::Close
    wm title $w [mc Login]

    ::UI::SetWindowPosition $w
        
    # Global frame.
    ttk::frame $w.frall
    pack  $w.frall  -fill x
                                 
    if {$config(login,show-head)} {
	set connectim   [::Theme::Find32Icon $w connectImage]
	set connectimd  [::Theme::Find32Icon $w connectDisImage]

	ttk::label $w.frall.head -style Headlabel \
	  -text [mc Login] -compound left \
	  -image [list $connectim background $connectimd]
	pack  $w.frall.head  -side top -fill both -expand 1
	
	ttk::separator $w.frall.s -orient horizontal
	pack  $w.frall.s  -side top -fill x
    }
    
    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack  $wbox  -fill both -expand 1

    if {$config(login,style) eq "jid"} {
	set str [mc jaloginjid3]
    } elseif {$config(login,style) eq "jidpure"} {
	set str [mc jaloginjidpure]
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
    set profile $menuVar
    ui::combobutton $wpopup -variable [namespace current]::menuVar \
       -command [namespace code ProfileCmd]
    
    # Depending on 'config(login,style)' not all get mapped.
    ttk::label $frmid.ljid -text "[mc {Contact ID}]:" -anchor e
    ttk::entry $frmid.ejid -width 22    \
      -textvariable [namespace current]::jid
    ttk::label $frmid.lserv -text "[mc Server]:" -anchor e
    ttk::entry $frmid.eserv -width 22    \
      -textvariable [namespace current]::server -validate key  \
      -validatecommand {::Jabber::ValidateDomainStr %S}
    ttk::label $frmid.luser -text "[mc Username]:" -anchor e
    ttk::entry $frmid.euser -width 22   \
      -textvariable [namespace current]::username -validate key  \
      -validatecommand {::Jabber::ValidateUsernameStrEsc %S}
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
    } elseif {$config(login,style) eq "jidpure"} {
	grid  $frmid.ljid   $frmid.ejid   -sticky e -pady 2
	grid  $frmid.lpass  $frmid.epass  -sticky e -pady 2
	
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
    
    set widgets(jid)       $frmid.ejid
    set widgets(server)    $frmid.eserv
    set widgets(username)  $frmid.euser
    set widgets(password)  $frmid.epass
    set widgets(resource)  $frmid.eres
    
    ::balloonhelp::balloonforwindow $frmid.ejid [mc tooltip-contactid]
    ::balloonhelp::balloonforwindow $frmid.epass [mc registration-password]
    
    ::JUI::DnDXmppBindTarget $frmid.ejid

    # Triangle switch for more options.
    if {$config(login,more)} {
	set wtri $wbox.tri
	# @@@ Experiment! Try Arrow.TCheckbutton with extra text padding.
	if {0} {
	    ttk::button $wtri -style Small.Toolbutton -padding {6 1} \
	      -compound left -image [::UI::GetIcon mactriangleclosed] \
	      -text "[mc More]..." -command [list [namespace current]::MoreOpts $w]
	} elseif {0} {
	    ttk::button $wtri -style Small.Plain -padding {6 1} \
	      -compound left -image [::UI::GetIcon closeAqua] \
	      -text "[mc More]..." -command [list [namespace current]::MoreOpts $w]
	} else {
	    set morevar 0
	    ttk::checkbutton $wtri -style ArrowText.TCheckbutton \
	      -onvalue 0 -offvalue 1 -variable [namespace current]::morevar \
	      -text "  [mc More]..." -command [list [namespace current]::MoreOpts $w]
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
    ttk::button $frbot.btprof -text "[mc {Edit Profiles}]..." \
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
    ProfileCmd $profile
    	
    wm resizable $w 0 0
    
    bind $w <<ReturnEnter>> [list $frbot.btok invoke]
    
    if {$password eq ""} {
	bind $frmid.epass <Map> { focus %W }
    } else {
	bind $frmid.popup <Map> { focus %W }
    }
    after 100 [list [namespace current]::GetNormalSize $w]
}

proc ::Login::LoadProfiles {} {
    global  wDlgs
    variable tmpProfArr
    variable menuVar
    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable wpopup
    
    if {![winfo exists $wDlgs(jlogin)]} {
	return
    }
    $wpopup configure \
      -menulist [ui::optionmenu::menuList [::Profiles::GetAllNames]]
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

proc ::Login::ProfileCmd {value} {
    global  config
    
    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable jid
    variable tmpProfArr
    variable moreOpts
    variable wtabnb
    
    set profile  $value
    set server   $tmpProfArr($profile,server)
    set username $tmpProfArr($profile,username)
    set password $tmpProfArr($profile,password)
    
    set username [jlib::unescapestr $username]
    
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
	::Profiles::NotebookVerifyValid [namespace current]::moreOpts
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
    variable morevar

    pack $wfrmore -side top -fill x -padx 2
    $wtri configure -command [list [namespace current]::LessOpts $w] \
      -text "  [mc Less]..."   
}

proc ::Login::LessOpts {w} {
    variable wtri
    variable wfrmore
    variable morevar

    SetNormalSize $w
    update idletasks
    
    pack forget $wfrmore
    $wtri configure -command [list [namespace current]::MoreOpts $w] \
      -text "  [mc More]..."   
    after 100 [list wm geometry $w {}]
}

proc ::Login::DoCancel {w} {
    variable finished

    set finished 0
    Close $w
}

proc ::Login::Profiles {} {
    
    ::Profiles::BuildDialog
}

proc ::Login::Close {w} {
    variable tmpProfArr
    variable profile
    
    # Clean up.
    ::UI::SaveWinGeom $w
    ::Profiles::SetSelectedName $profile
    array unset tmpProfArr
    destroy $w
}

# Login::Reset --
# 
#       This resets the complete login process.
#       Must take care of everything.

proc ::Login::Reset {} {
    variable pending
    upvar ::Jabber::jstate jstate

    set pending 0
    $jstate(jlib) connect reset

    ::JUI::SetStatusMessage ""
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
    variable widgets
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Login::DoLogin"
    
    # Reset any pending open states.
    Reset

    if {($config(login,style) eq "jid") || ($config(login,style) eq "jidpure")} {
	jlib::splitjidex $jid username server resource
	set username [jlib::escapestr $username]
    } else {
	set username [jlib::escapestr $username]
	set jid [jlib::joinjid $username $server $resource]
    }	
    
    # Check 'server', 'username' and 'password' if acceptable.
    foreach name {server username password} {
	upvar 0 $name var
	if {![string length $var]} {
	    set mcname [mc [string totitle $name]]
	    ::UI::MessageBox -icon error -title [mc Error] -type ok \
	      -message [mc jamessnamemissing $mcname]
	    if {$name eq "password"} {
		focus $widgets(password)
	    } else {
		if {$config(login,style) eq "jid"} {
		    focus $widgets(jid)
		} else {
		    focus $widgets($name)
		}
	    }
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
	    ::UI::MessageBox -icon error -title [mc Error] -type ok \
	      -message [mc jamessillegalchar $name $var]
	    return
	}
    }

    # Verify http url if any.
    if {0 && [info exists moreOpts(http)] && $moreOpts(http)} {
	if {![::Utils::IsWellformedUrl $moreOpts(httpurl)]} {
	    ::UI::MessageBox -icon error -title [mc Error] -type ok \
	      -message "The url \"$moreOpts(httpurl)\" is invalid."
	    return
	}
    }
    
    set opts [list]
    foreach {key value} [array get moreOpts] {
	lappend opts -$key $value
    }
    
    # Should login settings be automatically saved to profile.
    if {$config(login,autosave)} {
	eval {::Profiles::Set $profile $server $username $password} $opts
    }
    
    # Shall we ask the user to save the current options as default for this
    # profile if different?
    if {$config(login,ask-save-profile)} {
	set diffs 0
	set prof [::Profiles::GetProfile $profile]
# 	puts "prof=$prof"
	lassign [lrange $prof 0 2] h u p
	array set tmp1A $opts
	array set tmp2A [::Profiles::GetDefaultOpts $server]
	array set tmp2A [lrange $prof 3 end]
	array unset tmp1A -nickname
# 	parray tmp1A
# 	parray tmp2A
	set r ""
	if {[info exists tmp2A(-resource)]} {
	    set r $tmp2A(-resource)
	}
# 	puts "jid=$jid, barejid=[jlib::barejid $jid]"
# 	puts "u=$u, h=$h, j=[jlib::joinjid $u $h ""]"
	
	if {![jlib::jidequal [jlib::barejid $jid] [jlib::joinjid $u $h ""]]} {

	    # If we have a new bare JID we ask the user to make a new profile.
	    set msg "The Jabber ID differs from your profile. Do you want to save a new profile?"
	    set ans [tk_messageBox -title "" -type yesno -icon question \
	      -message $msg]
	    if {$ans eq "yes"} {
		set mbar [::UI::GetMainMenu]
		::UI::MenubarDisableBut $mbar edit
		
		set ans [ui::megaentry -label "[mc {Profile Name}]:" -icon "" \
		  -geovariable prefs(winGeom,jprofname) \
		  -title [mc "Add Profile"] -message [mc prefprofname2]]
		::UI::MenubarEnableAll $mbar

		if {$ans ne ""} {
		    set newName [ui::megaentrytext $ans]
		    if {$ans eq "yes"} {
			set uname [MakeUniqueProfileName $newName]
			eval {::Profiles::Set $uname $server $username $password} $opts
		    }	
		}
	    }
	} else {
	
	    # Check if other profile options changed.
	    if {![jlib::jidequal $jid [jlib::joinjid $u $h $r]]} {
		set diffs 1
	    } else {
		if {![arraysequal tmp1A tmp2A]} {
		    set diffs 1
		}
	    }
	    if {$diffs} {
		set msg "Your current login settings differ from your profile settings. Do you want to save them to your profile?"
		set ans [tk_messageBox -title "" -type yesno -icon question \
		  -message $msg]
		if {$ans eq "yes"} {
		    eval {::Profiles::Set $profile $server $username $password} $opts
		}	
	    }
	}
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
#       Command line options have higher priority than user settings.

proc ::Login::LaunchHook {} {
    upvar ::Jabber::jprefs jprefs
    
    if {![ParseCommandLine]} {
	if {$jprefs(autoLogin)} {
	    LoginCmd
	}
    }
}

# Login::LoginCmd --
# 
#       A way to login using the currently selected profile without using dialog.

proc ::Login::LoginCmd {} {
    
    # Do not try to login if we already have a pending login or is in stream.
    if {![Pending] && ![::Jabber::Jlib isinstream]} {
	
	# Use our selected profile.
	LoginWithProfile [::Profiles::GetSelectedName]
    }
}

proc ::Login::LoginWithProfile {profname} {
    
    set domain   [::Profiles::Get $profname domain]
    set node     [::Profiles::Get $profname node]
    set password [::Profiles::Get $profname password]
    set jid [jlib::joinjid $node $domain ""]

    if {$password eq ""} {
	set ujid [jlib::unescapejid $jid]
	set ans [ui::megaentry -label "[mc Password]:" -icon question \
	  -geovariable prefs(winGeom,jautologin) -show {*} \
	  -title [mc Password] -message [mc enterpassword $ujid]]
	if {$ans eq ""} {
	    return
	}
	set password [ui::megaentrytext $ans]
    }
    set opts [::Profiles::Get $profname options]
    array set optsA $opts
    if {[info exists optsA(-resource)] && ($optsA(-resource) ne "")} {
	set res $optsA(-resource)
    } else {
	set res [::Profiles::MachineResource]
    }
    eval {::Login::HighLogin $domain $node $res $password \
      [namespace current]::AutoLoginCB} $opts
}

# Login::ParseCommandLine --
# 
#       Processes the command line options to see if we shall login and with
#       which parameters.

proc ::Login::ParseCommandLine {} {
    global  argv
    
    Debug 4 "::Login::ParseCommandLine argv='$argv'"
    
    if {[expr {[llength $argv] % 2 == 1}]} {
	return
    }
    array set argvA $argv
    
    set login 0
    if {[info exists argvA(-jid)]} {
	set jid $argvA(-jid)
	jlib::splitjidex $jid node domain res
	if {$res eq ""} {
	    set res [::Profiles::MachineResource]
	}
	if {[info exists argvA(-password)]} {
	    set password $argvA(-password)
	    set login 1
	} else {
	    set ujid [jlib::unescapejid $jid]
	    set ans [ui::megaentry -label "[mc Password]:" -icon question \
	      -geovariable prefs(winGeom,jautologin) -show {*} \
	      -title [mc Password] -message [mc enterpassword $ujid]]
	    if {$ans ne ""} {
		set password [ui::megaentrytext $ans]
		set login 1
	    }
	}
	if {$login} {
	    set opts [eval {jlib::connect::filteroptions} $argv]
	    eval {::Login::HighLogin $domain $node $res $password \
	      [namespace current]::AutoLoginCB} $opts
	}
    } elseif {[info exists argvA(-profile)]} {
	if {[::Profiles::Exists $argvA(-profile)]} {
	    LoginWithProfile $argvA(-profile)
	    set login 1
	} else {
	    puts stderr "profile \"$argvA(-profile)\" does not exist"
	}
    }
    return $login
}

proc ::Login::QuitAppHook {} {
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

    ::JUI::SetStatusMessage "[mc jawaitresp $server]..."
    ::JUI::FixUIWhen "connectinit"
    ::JUI::SetConnectState "connectinit"
        
    set pending 1
    set defResource [::Profiles::MachineResource]

    jlib::connect::configure              \
      -defaultresource $defResource       \
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
	    ::JUI::SetStatusMessage "[mc jawaitxml $state(server)]..."
	}
	starttls {
	    ::JUI::SetStatusMessage "[mc jatlsnegot2]..."
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
	    set msg [mc jaauthok2 $server] 
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

    uplevel #0 $highstate(cmd) [list $token $errcode $errmsg]

    # Free all.
    unset highstate
    $jstate(jlib) connect free
}

proc ::Login::Pending {} {
    variable pending
    return $pending
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
	    set str [mc jamessnosocket3 $state(server)]
	    append str "\n" "[mc Error]: $errmsg"
	}
	timeout {
	    set str [mc jamesstimeoutserver2 $state(server)]
	}
	409 {
	    set msg "[mc {Error code}]: $errcode"
	    set str [mc jamesslogin409b $msg]
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
	    set str [mc jamessproxy-failure2]
	    append str "\n" "[mc {Error code}]: $errmsg"
	}
	default {
	    
	    # Identify the xmpp-stanzas.
	    if {$state(state) eq "authenticate"} {
		
		# Added 'bad-auth' which seems to be a ejabberd anachronism.
		set errcode [string map {bad-auth not-authorized} $errcode]
		set key xmpp-stanzas-short-$errcode
		set str [mc $key]
		if {$str eq $key} {
		    set str [mc xmpp-stanzas-$errcode]
		}
		append str " " "($errcode)"
		if {$errmsg ne ""} {
		    append str " " $errmsg
		}
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
    set ans [::UI::MessageBox -icon error -title [mc Error] -type $type \
      -default $default -message $str]
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
