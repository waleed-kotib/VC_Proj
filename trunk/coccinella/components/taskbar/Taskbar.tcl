#  Taskbar.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the taskbar on Windows.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: Taskbar.tcl,v 1.10 2005-08-16 12:22:34 matben Exp $

namespace eval ::Taskbar:: {
    
    variable icon ""
    variable wmenu .tskbrpop
    variable wtearoff ""
    variable iconFile coccinella.ico
}

proc ::Taskbar::Load { } {
    global  tcl_platform prefs this
    variable icon
    variable iconFile
    
    ::Debug 2 "::Taskbar::Load"
    
    if {[tk windowingsystem] ne "win32"} {
	return 0
    }
    if {![string equal $prefs(protocol) "jabber"]} {
	return 0
    }
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
    component::register Taskbar  \
      "Makes the taskbar icon on Windows which is handy as a shortcut."
    
    # Add all event hooks.
    ::hooks::register initHook           ::Taskbar::InitHook
    ::hooks::register quitAppHook        ::Taskbar::QuitAppHook
    ::hooks::register setPresenceHook    ::Taskbar::SetPresenceHook
    ::hooks::register loginHook          ::Taskbar::LoginHook
    ::hooks::register logoutHook         ::Taskbar::LogoutHook
    ::hooks::register preCloseWindowHook ::Taskbar::CloseHook        20
    ::hooks::register jabberBuildMain    ::Taskbar::BuildMainHook
    
    set status    [::Jabber::GetMyStatus]
    set statusStr [::Roster::MapShowToText $status]
    set str [encoding convertto "$prefs(theAppName) - $statusStr"]

    winico taskbar add $icon \
      -callback [list [namespace current]::Cmd %m %X %Y] -text $str

    return 1
}

proc ::Taskbar::BuildMainHook { } {
    
    bind [::UI::GetMainWindow] <Map> [list [namespace current]::Update %W]
}

proc ::Taskbar::InitHook { } {
    global  prefs
    variable wmenu
     
    # Build popup menu.
    set m $wmenu
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
	if {[string index $cmd 0] == "@"} {
	    set mt [menu $m.sub${i} -tearoff 0]
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

proc ::Taskbar::Cmd {event x y} {
    variable wmenu
    
    switch -- $event {
	WM_LBUTTONUP {
	    
	    switch -- [wm state [::UI::GetMainWindow]] {
		zoomed - normal  {
		    ::UI::WithdrawAllToplevels
		}
		default {
		    ::UI::ShowAllToplevels
		}
	    }
	}
	WM_RBUTTONUP {
	    tk_popup $wmenu [expr $x - 40] [expr $y] [$wmenu index end]
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
    if {$status == "unavailable"} {
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
   if {$icon != ""} {
	set statusStr [::Roster::MapShowToText [::Jabber::GetMyStatus]]
	set str [encoding convertto "$prefs(theAppName) - $statusStr"]
	winico taskbar modify $icon -text $str
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
    
    if {$icon != ""} {
	winico taskbar delete $icon
    }
}

#-------------------------------------------------------------------------------
