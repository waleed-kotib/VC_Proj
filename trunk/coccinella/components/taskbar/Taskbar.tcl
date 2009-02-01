#  Taskbar.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the taskbar on Windows and the tray on X11.
#      
#  Copyright (c) 2004-2008  Mats Bengtsson
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
# $Id: Taskbar.tcl,v 1.45 2008-07-25 13:46:54 matben Exp $

package require balloonhelp

namespace eval ::Taskbar {

    switch -- [tk windowingsystem] {
	win32 {
	    if {[catch {package require Winico}]} {
		return
	    }
	}
	x11 {
	    if {[catch {package require tktray}]} {
		return
	    }
	}
	default { return }
    }
    component::define Taskbar "Creates a system tray icon"
}

proc ::Taskbar::Load {} {
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
        
    component::register Taskbar
    
    # Add all event hooks.
    ::hooks::register initHook              ::Taskbar::InitHook
    ::hooks::register quitAppHook           ::Taskbar::QuitAppHook
    ::hooks::register setPresenceHook       ::Taskbar::SetPresenceHook
    ::hooks::register loginHook             ::Taskbar::LoginHook
    ::hooks::register logoutHook            ::Taskbar::LogoutHook
    ::hooks::register preCloseWindowHook    ::Taskbar::CloseHook        20    
    ::hooks::register jabberBuildMain       ::Taskbar::BuildMainHook
    
    ::hooks::register prefsInitHook         ::Taskbar::InitPrefsHook
    ::hooks::register prefsBuildCustomHook  ::Taskbar::BuildCustomPrefsHook
    ::hooks::register prefsSaveHook         ::Taskbar::SavePrefsHook
    ::hooks::register prefsCancelHook       ::Taskbar::CancelPrefsHook
    
    return 1
}

proc ::Taskbar::WinInit {} {
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
    set iconFile [::Theme::FindExactIconFile icons/others/$iconf]
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

proc ::Taskbar::X11Init {} {
    global  prefs
    variable wtray
    variable wmenu
    
    if {[catch {package require tktray}]} {
	return 0
    }
    set wmenu $wtray.pop

    option add *taskbarIcon   coccinella   widgetDefault

    set image [::Theme::Find32Icon . taskbarIcon]
    ::tktray::icon $wtray -image $image

    bind $wtray <ButtonRelease-1> { ::Taskbar::X11Cmd %X %Y }
    bind $wtray <Button-3>        { ::Taskbar::X11Popup %X %Y }
    bind $wtray <Configure>       { ::Taskbar::X11Configure %w %h }

    set statusStr [::Roster::MapShowToText [::Jabber::GetMyStatus]]
    set str "$prefs(theAppName) - $statusStr"
    ::balloonhelp::balloonforwindow $wtray $str

    return 1
}

proc ::Taskbar::BuildMainHook {} {
    variable tprefs
    
    # Not sure how this workd.
    if {$tprefs(quitMini) || $tprefs(startMini)} {
	::UI::WithdrawAllToplevels
    }
    bind [::JUI::GetMainWindow] <Map> [list [namespace current]::Update %W]
}

proc ::Taskbar::InitHook {} {
    global  prefs this
    variable wmenu
    variable menuIndex
     
    # Build popup menu.
    set m $wmenu
    menu $m -tearoff 1 -postcommand [list [namespace current]::Post $m] \
      -tearoffcommand [namespace current]::TearOff -title $prefs(theAppName)
    
    set COCI [::Theme::FindIconSize 16 coccinella]
    set INFO [::Theme::FindIconSize 16 dialog-information]
    set SET  [::Theme::FindIconSize 16 preferences]
    set MSG  [::Theme::FindIconSize 16 mail-message-new]
    set ADD  [::Theme::FindIconSize 16 list-add-user]
    set EXIT [::Theme::FindIconSize 16 application-exit]
    set STAT [::Roster::GetMyPresenceIcon]
    
    set menuDef {
	{cascade  mStatus           {[mc "Status"]} {}                      {-image @STAT -compound left}}
	{command  mMinimize         {[mc "Mi&nimize"]} ::Taskbar::HideMain                  }
	{command  mMessage...       {[mc "&Message"]...} ::NewMsg::Build         {-image @MSG -compound left}}
	{command  mPreferences...   {[mc "&Preferences"]...} ::Taskbar::Prefs        {-image @SET -compound left}}
	{command  mAddContact...    {[mc "&Add Contact"]...} ::JUser::NewDlg  {-image @ADD -compound left}}
	{cascade  mInfo  {[mc "&Info"]} {
	    {command  mAboutCoccinella    {[mc "&About Coccinella"]} ::Splash::SplashScreen  {-image @COCI -compound left}}
	    {command  mCoccinellaHome...  {[mc "&Home Page"]...} ::JUI::OpenCoccinellaURL}
	    {command  mBugReport...       {[mc "&Report Bug"]...} ::JUI::OpenBugURL       }
	    } {-image @INFO -compound left}
	}
	{separator}
	{command  mQuit             {[mc "&Quit"]} ::UserActions::DoQuit  {-image @EXIT -compound left}}
    }
    set menuDef [string map [list  \
      @STAT $STAT  @COCI $COCI  @ADD $ADD  @INFO $INFO  @SET $SET  \
      @MSG  $MSG   @EXIT $EXIT] $menuDef]
    
    ::AMenu::Build $m $menuDef
    array set menuIndex [::AMenu::GetMenuIndexArray $m]
}

proc ::Taskbar::Prefs {} {
    ::Preferences::Build
    ::Preferences::Show {Jabber Customization}
}

proc ::Taskbar::WinCmd {event x y} {
    variable wmenu
    
    # It can happen that during launch we exist before main window does.
    if {![winfo exists [::JUI::GetMainWindow]]} { return }
    
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
	$wtray configure -image [::Theme::FindIconSize 22 coccinella]
    }
}

proc ::Taskbar::X11Cmd {x y} {

    # It can happen that during launch we exist before main window does.
    if {![winfo exists [::JUI::GetMainWindow]]} { return }
    ToggleVisibility
}

proc ::Taskbar::X11Popup {x y} {
    variable wmenu
    variable wtray

    # It can happen that during launch we exist before main window does.
    if {![winfo exists [::JUI::GetMainWindow]]} { return }

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
    variable tprefs

    switch -- [wm state [::JUI::GetMainWindow]] {
	zoomed - normal  {
	    if {$tprefs(hideAll)} {
		::UI::WithdrawAllToplevels
	    } else {
		wm withdraw [::JUI::GetMainWindow]
	    }
	}
	default {
	    # This includes the iconic state.
	    if {$tprefs(hideAll)} {
		::UI::ShowAllToplevels
	    } else {
		wm deiconify [::JUI::GetMainWindow]
		foreach w [::UI::GetAllToplevels] {
		    if {[wm state $w] eq "withdrawn"} {
			wm deiconify $w
		    }
		}
	    }
	}
    }
}

proc ::Taskbar::Post {m} {
    global  config
    variable menuIndex

    switch -- [wm state [::JUI::GetMainWindow]] {
	zoomed - normal {
	    set state1 disabled
	    set state2 normal
	}
	default {
	    set state1 normal
	    set state2 disabled
	}
    }
    Update [::JUI::GetMainWindow]
    
    # {available away chat dnd xa invisible unavailable}
    set status [::Jabber::GetMyStatus]
    if {$status eq "unavailable"} {
	set state0 disabled
	set state3 normal
    } else {
	set state0 normal
	set state3 disabled
    }
    $m entryconfigure $menuIndex(mMessage...) -state $state0 
    $m entryconfigure $menuIndex(mAddContact...) -state $state0
    
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

proc ::Taskbar::HideMain {} {    
    ::UI::WithdrawAllToplevels
    Update [::JUI::GetMainWindow]
}

proc ::Taskbar::ShowMain {} {
    ::UI::ShowAllToplevels
}

proc ::Taskbar::LoginHook {} {
    variable wtearoff
    variable menuIndex
    
    if {[winfo exists $wtearoff] && [winfo ismapped $wtearoff]} {
	set m $wtearoff
	$m entryconfigure $menuIndex(mMessage...) -state normal
	$m entryconfigure $menuIndex(mAddContact...) -state normal
    }
}

proc ::Taskbar::LogoutHook {} {
    variable wtearoff
    variable menuIndex

    if {[winfo exists $wtearoff] && [winfo ismapped $wtearoff]} {
	set m $wtearoff
	$m entryconfigure $menuIndex(mMessage...) -state disabled 
	$m entryconfigure $menuIndex(mAddContact...) -state disabled
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
	
    switch -- [wm state [::JUI::GetMainWindow]] {
	zoomed - normal {
	    set state1 disabled
	    set state2 normal
	    ::AMenu::EntryConfigure $m mMinimize -label [mc "Mi&nimize"] \
	      -command ::Taskbar::HideMain
	}
	default {
	    set state1 normal
	    set state2 disabled
	    ::AMenu::EntryConfigure $m mMinimize -label [mc "&Restore"] \
	      -command ::Taskbar::ShowMain
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
    variable tprefs
    
    set result ""
    if {[string equal $wclose [::JUI::GetMainWindow]]} {
	#HideMain
	if {$tprefs(hideAll)} {
	    ::UI::WithdrawAllToplevels
	} else {
	    wm withdraw [::JUI::GetMainWindow]
	}
	set result stop
    }
    return $result
}

proc ::Taskbar::QuitAppHook {} {
    variable icon
    variable tprefs
    
    set tprefs(quitMini) 1
    set wmstate [wm state [::JUI::GetMainWindow]]
    if {($wmstate eq "normal") || ($wmstate eq "zoomed")} {
	set tprefs(quitMini) 0
    }
    if {[tk windowingsystem] eq "win32"} {
	if {$icon ne ""} {
	    winico taskbar delete $icon
	}
    }
}


# Taskbar::Debug --
#
#       Use this to bugtrack windows visibility issues.

proc ::Taskbar::Debug {} {
    
    puts "::UI::GetAllToplevels=[::UI::GetAllToplevels]"
    puts "::UI::topcache: state=$::UI::topcache(state)"
    parray ::UI::topcache *,prevstate
    foreach w [::UI::GetAllToplevels] {
	puts "w=$w, wm state=[wm state $w]"
    }
    
}

# Preference page --------------------------------------------------------------

proc ::Taskbar::InitPrefsHook {} {
    variable tprefs
    
    set tprefs(quitMini)  0
    set tprefs(startMini) 0
    set tprefs(hideAll)   1    
    
    ::PrefUtils::Add [list  \
      [list ::Taskbar::tprefs(quitMini)   taskbar_quitMini   $tprefs(quitMini)] \
      [list ::Taskbar::tprefs(startMini)  taskbar_startMini  $tprefs(startMini)] \
      [list ::Taskbar::tprefs(hideAll)    taskbar_hideAll    $tprefs(hideAll)]]
}

proc ::Taskbar::BuildCustomPrefsHook {win} {
    variable tprefs
    variable tmpPrefs
    
    set tmpPrefs(startMini) $tprefs(startMini)
    set tmpPrefs(hideAll)   $tprefs(hideAll)

    switch -- [tk windowingsystem] {
	win32 {
	    set str [mc "Start minimized in taskbar"]
	    set strHide [mc "Hide all on taskbar click"]
	}
	x11 {
	    set str [mc "Start minimized in system tray"]
	    set strHide [mc "Hide all on system tray click"]
	}
    }
    ttk::checkbutton $win.tskbmini -text $str \
      -variable [namespace current]::tmpPrefs(startMini)
    ttk::checkbutton $win.tskbhide -text $strHide \
      -variable [namespace current]::tmpPrefs(hideAll)

    grid  $win.tskbmini  -sticky w
    grid  $win.tskbhide  -sticky w
}

proc ::Taskbar::SavePrefsHook {} {
    variable tprefs
    variable tmpPrefs
    
    set tprefs(startMini) $tmpPrefs(startMini)
    set tprefs(hideAll)   $tmpPrefs(hideAll)
}

proc ::Taskbar::CancelPrefsHook {} {
    variable tprefs
    variable tmpPrefs
    
    if {$tprefs(startMini) ne $tmpPrefs(startMini)} {
	::Preferences::HasChanged
    }
    if {$tprefs(hideAll) ne $tmpPrefs(hideAll)} {
	::Preferences::HasChanged
    }
}

#-------------------------------------------------------------------------------
