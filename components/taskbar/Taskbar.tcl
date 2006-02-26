#  Taskbar.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the taskbar on Windows.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: Taskbar.tcl,v 1.17 2006-02-26 10:35:33 matben Exp $

package require balloonhelp

namespace eval ::Taskbar:: {
    
    variable icon ""
    variable wmenu
    variable wtray .tskbar
    variable wtearoff ""
    variable iconFile coccinella.ico
    
    switch -- [tk windowingsystem] {
	win32 {
	    set wmenu .tskbrpop
	}
	x11 {
	    set wmenu .tskbar.pop
	}
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

    set statusStr [::Roster::MapShowToText [::Jabber::GetMyStatus]]
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
    ::tktray::icon $wtray -image [::Theme::GetImage coccinella32]

    bind $wtray <ButtonRelease-1> { ::Taskbar::X11Cmd %X %Y }
    bind $wtray <Button-3>        { ::Taskbar::X11Popup %X %Y }
    bind $wtray <Configure>       { ::Taskbar::X11Configure %w %h }

    set statusStr [::Roster::MapShowToText [::Jabber::GetMyStatus]]
    set str "$prefs(theAppName) - $statusStr"
    ::balloonhelp::balloonforwindow $wtray $str

    return 1
}

proc ::Taskbar::BuildMainHook { } {
    
    bind [::UI::GetMainWindow] <Map> [list [namespace current]::Update %W]
}

proc ::Taskbar::InitHook { } {
    global  prefs this
    variable wmenu
    variable menuIndex
     
    # Build popup menu.
    set m $wmenu
    menu $m -tearoff 1 -postcommand [list [namespace current]::Post $m] \
      -tearoffcommand [namespace current]::TearOff -title $prefs(theAppName)
    
    set subPath [file join $this(images) 16]
    set COCI [::Theme::GetImage coccinella $subPath]
    set INFO [::Theme::GetImage info $subPath]
    set SET  [::Theme::GetImage settings $subPath]
    set MSG  [::Theme::GetImage newmsg $subPath]
    set ADD  [::Theme::GetImage adduser $subPath]
    set EXIT [::Theme::GetImage exit $subPath]
    set STAT [::Roster::GetMyPresenceIcon]
    
    set menuDef {
	{cascade  mStatus           @::Jabber::Status::BuildMenu  {-image @STAT -compound left}}
	{command  mHideMain         ::Taskbar::HideMain                  }
	{command  mSendMessage      ::NewMsg::Build         {-image @MSG -compound left}}
	{command  mPreferences      ::Preferences::Build    {-image @SET -compound left}}
	{command  mAddNewUser       ::Jabber::User::NewDlg  {-image @ADD -compound left}}
	{cascade  mInfo  {
	    {command  mAboutCoccinella  ::Splash::SplashScreen  {-image @COCI -compound left}}
	    {command  mCoccinellaHome   ::Jabber::UI::OpenCoccinellaURL}
	    {command  mBugReport        ::Jabber::UI::OpenBugURL       }
	    } {-image @INFO -compound left}
	}
	{separator}
	{command  mQuit             ::UserActions::DoQuit  {-image @EXIT -compound left}}
    }
    set menuDef [string map [list  \
      @STAT $STAT  @COCI $COCI  @ADD $ADD  @INFO $INFO  @SET $SET  \
      @MSG  $MSG   @EXIT $EXIT] $menuDef]
    
    ::AMenu::Build $m $menuDef
    array set menuIndex [::AMenu::GetMenuIndexArray $m]
}

proc ::Taskbar::WinCmd {event x y} {
    variable wmenu
    
    switch -- $event {
	WM_LBUTTONUP {
	    ToggleVisibility
	}
	WM_RBUTTONUP {
	    tk_popup $wmenu [expr {$x - 40}] [expr $y] [$wmenu index end]
	}
    }
}
proc ::Taskbar::X11Configure {width height} {
    variable wtray
        
    if {$width < 32 || $height < 32} {
	$wtray configure -image [::Theme::GetImage coccinella22]
    }
}

proc ::Taskbar::X11Cmd {x y} {
    ToggleVisibility
}

proc ::Taskbar::X11Popup {x y} {
    variable wmenu
    
    tk_popup $wmenu [expr $x] [expr {$y - 20}] [$wmenu index end]
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
    $m entryconfigure [$m index [mc mSendMessage]] -state $state0 
    $m entryconfigure [$m index [mc mAddNewUser]] -state $state0
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
	$m entryconfigure [$m index [mc mSendMessage]] -state normal
	$m entryconfigure [$m index [mc mAddNewUser]] -state normal
    }
}

proc ::Taskbar::LogoutHook { } {
    variable wtearoff

    if {[winfo exists $wtearoff] && [winfo ismapped $wtearoff]} {
	set m $wtearoff
	$m entryconfigure [$m index [mc mSendMessage]] -state disabled 
	$m entryconfigure [$m index [mc mAddNewUser]] -state disabled
    }
}

proc ::Taskbar::Update {w} {
    variable wtearoff
    variable wmenu
    variable menuIndex

    if {[winfo toplevel $w] ne $w} {
	return
    }
    set m $wmenu
	
    switch -- [wm state [::UI::GetMainWindow]] {
	zoomed - normal {
	    set state1 disabled
	    set state2 normal
	    $m entryconfigure $menuIndex(mHideMain)  \
	      -label [mc mHideMain] -command ::Taskbar::HideMain
	}
	default {
	    set state1 normal
	    set state2 disabled
	    $m entryconfigure $menuIndex(mHideMain)  \
	      -label [mc mShowMain] -command ::Taskbar::ShowMain
	}
    }
}

proc ::Taskbar::SetPresenceHook {type args} {
    global  prefs
    variable icon
    variable wtray
    variable wmenu
     
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
	    ::balloonhelp::balloonforwindow $wtray $str
	}
    }
    set m $wmenu
    set opts [list -compound left -image [::Roster::GetMyPresenceIcon]]
    eval {::AMenu::EntryConfigure $m mStatus} $opts
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
	if {$icon ne ""} {
	    winico taskbar delete $icon
	}
    }
}

#-------------------------------------------------------------------------------
