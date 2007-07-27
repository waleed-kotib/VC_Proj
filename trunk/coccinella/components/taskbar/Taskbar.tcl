#  Taskbar.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the taskbar on Windows and the tray on X11.
#      
#  Copyright (c) 2004-2007  Mats Bengtsson
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
# $Id: Taskbar.tcl,v 1.30 2007-07-27 12:16:20 matben Exp $

package require balloonhelp

namespace eval ::Taskbar:: {}

proc ::Taskbar::Load { } {
    global  tcl_platform this
    variable wtray .tskbar
    variable wtearoff ""
    
    ::Debug 2 "::Taskbar::Load"
    
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
    global  this prefs
    variable icon
    variable iconFile
    variable wtray
    variable wmenu
    
    if {[catch {package require Winico}]} {
	return 0
    }
    set wmenu .tskbrpop
    set icon ""

    option add *taskbarIconWin   coccinella.ico   widgetDefault
    
    # The Winico is pretty buggy! Need to cd to avoid path troubles!
    set iconf [option get . taskbarIconWin {}]
    set iconFile [::Theme::FindExactImageFile $iconf]
    set oldDir [pwd]
    set dir [file dirname $iconFile]

    # Winico doesn't understand vfs!
    if {[info exists starkit::topdir]} {
	set tmp [file join $this(tmpPath) $iconf]
	file copy -force $iconFile $tmp
	cd $this(tmpPath)
    } else {
	cd $dir
    }
    if {[catch {set icon [winico create $iconf]} err]} {
	::Debug 2 "\t winico create $iconFile failed"
	cd $oldDir
	return 0
    }
    cd $oldDir

    set statusStr [::Roster::MapShowToText [::Jabber::GetMyStatus]]
    set str "$prefs(theAppName) - $statusStr"

    winico taskbar add $icon \
      -callback [list [namespace current]::WinCmd %m %X %Y] -text $str
    
    return 1
}

proc ::Taskbar::X11Init { } {
    global  prefs
    variable wtray
    variable wmenu
    
    if {[catch {package require tktray}]} {
	return 0
    }
    set wmenu $wtray.pop

    option add *taskbarIcon   coccinella32   widgetDefault

    set image [::Theme::GetImage [option get . taskbarIcon {}]]
    ::tktray::icon $wtray -image $image

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
	{cascade  mStatus           {}                      {-image @STAT -compound left}}
	{command  mMinimize         ::Taskbar::HideMain                  }
	{command  mSendMessage      ::NewMsg::Build         {-image @MSG -compound left}}
	{command  mPreferences...   ::Preferences::Build    {-image @SET -compound left}}
	{command  mAddContact       ::JUser::NewDlg  {-image @ADD -compound left}}
	{cascade  mInfo  {
	    {command  mAboutCoccinella  ::Splash::SplashScreen  {-image @COCI -compound left}}
	    {command  mCoccinellaHome   ::JUI::OpenCoccinellaURL}
	    {command  mBugReport        ::JUI::OpenBugURL       }
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
    variable wtray

    # Try to figure out if top or bottom.
    set bbox [$wtray bbox]
    set ybot [expr {[lindex $bbox 3] + [winfo reqheight $wmenu]}]
    set H [$wmenu yposition 1]
    if {$ybot > [winfo screenheight $wtray]} {
	tk_popup $wmenu $x [expr {[lindex $bbox 1] - $H}] [$wmenu index end]
    } else {
	tk_popup $wmenu $x [expr {[lindex $bbox 3] + 4}]
    }
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
    global  config
    variable menuIndex

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
    $m entryconfigure $menuIndex(mSendMessage) -state $state0 
    $m entryconfigure $menuIndex(mAddContact) -state $state0
    
    set mstatus [$m entrycget $menuIndex(mStatus) -menu]
    $mstatus delete 0 end
    if {$config(ui,status,menu) eq "plain"} {
	::Status::BuildMainMenu $mstatus
    } elseif {$config(ui,status,menu) eq "dynamic"} {
	::Status::ExBuildMainMenu $mstatus
    }
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
    variable menuIndex
    
    if {[winfo exists $wtearoff] && [winfo ismapped $wtearoff]} {
	set m $wtearoff
	$m entryconfigure $menuIndex(mSendMessage) -state normal
	$m entryconfigure $menuIndex(mAddContact) -state normal
    }
}

proc ::Taskbar::LogoutHook { } {
    variable wtearoff
    variable menuIndex

    if {[winfo exists $wtearoff] && [winfo ismapped $wtearoff]} {
	set m $wtearoff
	$m entryconfigure $menuIndex(mSendMessage) -state disabled 
	$m entryconfigure $menuIndex(mAddContact) -state disabled
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
	    $m entryconfigure $menuIndex(mMinimize)  \
	      -label [mc mMinimize] -command ::Taskbar::HideMain
	}
	default {
	    set state1 normal
	    set state2 disabled
	    $m entryconfigure $menuIndex(mMinimize)  \
	      -label [mc mRestore] -command ::Taskbar::ShowMain
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
	    if {$icon ne ""} {
		set statusStr [::Roster::MapShowToText [::Jabber::GetMyStatus]]
		set str "$prefs(theAppName) - $statusStr"
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
