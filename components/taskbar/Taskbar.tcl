#  Taskbar.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the taskbar on Windows.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: Taskbar.tcl,v 1.13 2006-02-20 10:39:52 matben Exp $

package require balloonhelp

namespace eval ::Taskbar:: {
    
    variable icon ""
    variable wmenu
    variable wtray .tskbar
    variable wtearoff ""
    variable iconFile coccinella.ico
    
    array set wmenu {
	win32   .tskbrpop
	x11     .tskbar.pop
    }
}

proc ::Taskbar::Load { } {
    global  tcl_platform prefs this
    
    ::Debug 2 "::Taskbar::Load"
    
    if {![string equal $prefs(protocol) "jabber"]} {
	return 0
    }

    switch -- [tk windowingsystem] {
	win32 {
	    if {![WinInit]} {
		return 0
	    }
	}
	x11 {
	    if {![X11Init]} {
		return 0
	    }
	}
	default {
	    return 0
	}
    }
        
    component::register Taskbar  \
      "Makes the taskbar icon on Windows and X11 which is handy as a shortcut."
    
    # Add all event hooks.
    ::hooks::register initHook           ::Taskbar::InitHook
    ::hooks::register quitAppHook        ::Taskbar::QuitAppHook
    ::hooks::register setPresenceHook    ::Taskbar::SetPresenceHook
    ::hooks::register loginHook          ::Taskbar::LoginHook
    ::hooks::register logoutHook         ::Taskbar::LogoutHook
    ::hooks::register preCloseWindowHook ::Taskbar::CloseHook        20
    ::hooks::register jabberBuildMain    ::Taskbar::BuildMainHook
    
    return 1
}

proc ::Taskbar::WinInit { } {
    global  this
    variable icon
    variable iconFile
    
    if {[catch {package require Winico}]} {
	return 0
    }

    # We have a hardcoded file path for the ico file. (option database?)
    # The Winico is pretty buggy! Need to cd to avoid path troubles!
    set oldDir [pwd]
    set dir  [file dirname [info script]]
    set path [file join $dir $iconFile]

    # Winico doesn't understand vfs!
    if {[info exists starkit::topdir]} {
	set tmp [file join $this(tmpPath) $iconFile]
	file copy -force $path $tmp
	cd $this(tmpPath)
    } else {
	cd $dir
    }
    if {[catch {set icon [winico create $iconFile]} err]} {
	::Debug 2 "\t winico create $iconFile failed"
	cd $oldDir
	return 0
    }
    cd $oldDir

    set status    [::Jabber::GetMyStatus]
    set statusStr [::Roster::MapShowToText $status]
    set str [encoding convertto "$prefs(theAppName) - $statusStr"]

    winico taskbar add $icon \
      -callback [list [namespace current]::WinCmd %m %X %Y] -text $str
    
    return 1
}

proc ::Taskbar::X11Init { } {
    global  prefs
    variable wtray
    
    if {[catch {package require tktray}]} {
	return 0
    }
    ::tktray::icon $wtray -image [::Theme::GetImage coccinella22]

    bind $wtray <ButtonRelease-1> { ::Taskbar::X11Cmd %X %Y }
    bind $wtray <Button-3>        { ::Taskbar::X11Popup %X %Y }

    set status    [::Jabber::GetMyStatus]
    set statusStr [::Roster::MapShowToText $status]
    set str "$prefs(theAppName) - $statusStr"
    ::balloonhelp::balloonforwindow $wtray $str

    return 1
}

proc ::Taskbar::BuildMainHook { } {
    
    bind [::UI::GetMainWindow] <Map> [list [namespace current]::Update %W]
}

proc ::Taskbar::InitHook { } {
    global  prefs
    variable wmenu
     
    # Build popup menu.
    set m $wmenu([tk windowingsystem])
    menu $m -tearoff 1 -postcommand [list [namespace current]::Post $m] \
      -tearoffcommand [namespace current]::TearOff -title $prefs(theAppName)
    
    set menuDef {
	mAboutCoccinella     {::Splash::SplashScreen}
	separator            {}
	mStatus              @::Jabber::Status::BuildMenu
	mLogin               ::Login::Dlg
	mLogout              ::Jabber::DoCloseClientConnection
	mLogoutWith          ::Jabber::Logout::WithStatus
	mHideMain            ::Taskbar::HideMain
	mShowMain            ::Taskbar::ShowMain
	mSendMessage         ::NewMsg::Build
	separator            {}
	mQuit                ::UserActions::DoQuit
    }
    
    set i 0
    foreach {item cmd} $menuDef {
	if {[string index $cmd 0] eq "@"} {
	    set mt [menu $m.sub$i -tearoff 0]
	    $m add cascade -label [mc $item] -menu $mt
	    eval [string range $cmd 1 end] $mt
	    incr i
	} elseif {[string equal $item "separator"]} {
	    $m add separator
	} else {
	    $m add command -label [mc $item] -command $cmd
	}
    }
}

proc ::Taskbar::WinCmd {event x y} {
    variable wmenu
    
    switch -- $event {
	WM_LBUTTONUP {
	    ToggleVisibility
	}
	WM_RBUTTONUP {
	    tk_popup $wmenu(win32) [expr {$x - 40}] [expr $y] [$wmenu(win32) index end]
	}
    }
}

proc ::Taskbar::X11Cmd {x y} {
    ToggleVisibility
}

proc ::Taskbar::X11Popup {x y} {
    variable wmenu
    
    tk_popup $wmenu(x11) [expr $x] [expr {$y - 20}] [$wmenu(x11) index end]
}

proc ::Taskbar::ToggleVisibility {} {
    
    switch -- [wm state [::UI::GetMainWindow]] {
	zoomed - normal  {
	    ::UI::WithdrawAllToplevels
	}
	default {
	    ::UI::ShowAllToplevels
	}
    }
}

proc ::Taskbar::Post {m} {

    switch -- [wm state [::UI::GetMainWindow]] {
	zoomed - normal {
	    set state1 disabled
	    set state2 normal
	}
	default {
	    set state1 normal
	    set state2 disabled
	}
    }
    
    # {available away chat dnd xa invisible unavailable}
    set status [::Jabber::GetMyStatus]
    if {$status eq "unavailable"} {
	set state0 disabled
	set state3 normal
    } else {
	set state0 normal
	set state3 disabled
    }
    $m entryconfigure [$m index [mc mStatus]] -state $state0
    $m entryconfigure [$m index [mc mLogin]] -state $state3
    $m entryconfigure [$m index [mc mLogout]] -state $state0
    $m entryconfigure [$m index [mc mLogoutWith]] -state $state0
    $m entryconfigure [$m index [mc mShowMain]] -state $state1
    $m entryconfigure [$m index [mc mHideMain]] -state $state2  
    $m entryconfigure [$m index [mc mSendMessage]] -state $state0 
}

proc ::Taskbar::TearOff {wm wt} {
    variable wtearoff
    
    set wtearoff $wt
}

proc ::Taskbar::HideMain { } {
    
    ::UI::WithdrawAllToplevels
    Update [::UI::GetMainWindow]
}

proc ::Taskbar::ShowMain { } {
    
    ::UI::ShowAllToplevels
}

proc ::Taskbar::LoginHook { } {
    variable wtearoff
    
    if {[winfo exists $wtearoff] && [winfo ismapped $wtearoff]} {
	set m $wtearoff
	$m entryconfigure [$m index [mc mStatus]] -state normal
	$m entryconfigure [$m index [mc mLogin]] -state disabled
	$m entryconfigure [$m index [mc mLogout]] -state normal
	$m entryconfigure [$m index [mc mLogoutWith]] -state normal
	$m entryconfigure [$m index [mc mSendMessage]] -state normal 
    }
}

proc ::Taskbar::LogoutHook { } {
    variable wtearoff

    if {[winfo exists $wtearoff] && [winfo ismapped $wtearoff]} {
	set m $wtearoff
	$m entryconfigure [$m index [mc mStatus]] -state disabled
	$m entryconfigure [$m index [mc mLogin]] -state normal
	$m entryconfigure [$m index [mc mLogout]] -state disabled
	$m entryconfigure [$m index [mc mLogoutWith]] -state disabled
	$m entryconfigure [$m index [mc mSendMessage]] -state disabled 
    }
}

proc ::Taskbar::Update {w} {
    variable wtearoff

    if {[winfo toplevel $w] != $w} {
	return
    }
    if {[winfo exists $wtearoff] && [winfo ismapped $wtearoff]} {
	
	switch -- [wm state [::UI::GetMainWindow]] {
	    zoomed - normal {
		set state1 disabled
		set state2 normal
	    }
	    default {
		set state1 normal
		set state2 disabled
	    }
	}
	set m $wtearoff
	$m entryconfigure [$m index [mc mShowMain]] -state $state1
	$m entryconfigure [$m index [mc mHideMain]] -state $state2  
    }    
}

proc ::Taskbar::SetPresenceHook {type args} {
    global  prefs
    variable icon
       
    # This can be used to update any specific icon in taskbar.
    switch -- [tk windowingsystem] {
	win32 {
	    if {$icon != ""} {
		set statusStr [::Roster::MapShowToText [::Jabber::GetMyStatus]]
		set str [encoding convertto "$prefs(theAppName) - $statusStr"]
		winico taskbar modify $icon -text $str
	    }
	}
	x11 {
	    set statusStr [::Roster::MapShowToText [::Jabber::GetMyStatus]]
	    set str "$prefs(theAppName) - $statusStr"
	}
    }
}

proc ::Taskbar::CloseHook {wclose} {
    
    set result ""
    if {[string equal $wclose [::UI::GetMainWindow]]} {
	HideMain
	set result stop
    }
    return $result
}

proc ::Taskbar::QuitAppHook { } {
    variable icon
    
    if {[tk windowingsystem] eq "win32"} {
	if {$icon != ""} {
	    winico taskbar delete $icon
	}
    }
}

#-------------------------------------------------------------------------------
