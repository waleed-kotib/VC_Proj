#!/bin/sh
# the next line restarts using wish \
	exec wish "$0" -visual best "$@"
      
#  Coccinella.tcl ---
#  
#       This file is the main of the jabber/whiteboard application. 
#       It controls the startup sequence and therefore needs a number
#       of code files/images to be succesful.
#      
#  Copyright (c) 1999-2007  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#
# $Id: Coccinella.tcl,v 1.165 2007-10-16 12:10:16 matben Exp $	

# Level of detail for printouts; >= 2 for my outputs; >= 6 to logfile.
set debugLevel 0

# TclKit loading mechanism.
package provide app-Coccinella 1.0

# We want 8.4 at least.
if {[catch {package require Tk 8.4}]} {
    return -code error "We need Tk 8.4 or later here. Run Wish!"
}

# The main window "." shall never be displayed. Use it for QT sounds etc.
wm withdraw .
tk appname coccinella

# Keep 'launchStatus' around for the complete launch process to help components.
set state(launchStatus) start
set state(launchSecs) [clock seconds]

# MacOSX adds a -psn_* switch.
set argv [lsearch -all -not -inline -regexp $argv {-psn_\d*}]
set argc [llength $argv]
array set argvArr $argv

# We use a variable 'this(platform)' that is more convenient for MacOSX.
switch -- $::tcl_platform(platform) {
    unix {
	if {[string equal [tk windowingsystem] "aqua"]} {
	    set this(platform) "macosx"
	} else {
	    set this(platform) $::tcl_platform(platform)
	}
    }
    default {
	set this(platform) $::tcl_platform(platform)
    }
}

# Early platform dependent stuff.
switch -- $this(platform) {
    windows {
	
	# We should only allow a single instance of this application.
	# A COM interface would be better... (safer)
	package require dde
	
	# If any services available for coccinella then provide the argv.
	set services [dde services TclEval coccinella]
	if {$services != {}} {
	    dde execute TclEval coccinella [concat SecondCoccinella $argv]
	    exit
	}
	dde servername coccinella
    }
    macosx {
	
	# CoreGraphics don't align to pixel boundaries by default!
	set tk::mac::useCGDrawing 0
    }
}

# Find program real pathname, resolve all links in between. Unix only.
#
# Contributed by Raymond Tang. Starkit fix by David Zolli.

proc resolve_cmd_realpath {infile} {
    
    if {[file exists $infile]} {
	if {[file type $infile] == "link"} {
	    set olddir [pwd]
	    set dirname [file dirname $infile]
	    set filename [file tail $infile]
	    cd $dirname
	    if {[file type $filename] == "link"} {
		set filename [file readlink $filename]
		if {[file pathtype $filename] == "absolute"} {
		    set realname [resolve_cmd_realpath $filename]
		} else {
		    set realname [file join [pwd] $filename]
		}
	    } else {
		# found the destination
		set realname $infile
	    }
	    cd $olddir
	    return [resolve_cmd_realpath $realname]
	} else {
	    # found the desintation
	    return $infile
	}
    } else {
	foreach name [split $::env(PATH) :] {
	    set filename [file join $name $infile]
	    if {[file exists $filename] && [file executable $filename]} {
		return [resolve_cmd_realpath $filename]
	    }
	}

	# Kroc : for tclkit support :
        if {[info exists ::starkit::topdir]} {
            return $::starkit::topdir
        } else {
            return $infile
        }
    }
}

# Identify our own position in the file system.
if {[string equal $this(platform) "unix"]} {
    set thisScript [file normalize [resolve_cmd_realpath [info script]]]
} else {
    set thisScript [file normalize [info script]]
}
set thisPath [file normalize [file dirname $thisScript]]

# Debug support.
source [file join $thisPath lib Debug.tcl]

::Debug 2 "Installation rootdir:  [file dirname $thisScript]"

# Set up 'this' array which contains search paths admin stuff.
source [file join $thisPath lib Init.tcl]
::Init::SetThis $thisScript
::Init::SetThisVersion
::Init::SetThisEmbedded
::Init::SetAutoPath

set prefs(appName)    "Coccinella"
set prefs(theAppName) "Coccinella"

# Read our prefs file containing the theme name and locale needed before splash.
package require PrefUtils
package require Theme
::PrefUtils::Init
::Theme::Init

# Find our language and load message catalog.
::Init::Msgcat

switch [tk windowingsystem] {
    windows - win32 {
	wm iconbitmap . -default [file join $this(imagePath) coccinella.ico]
    }
    x11 {
	if {[package vcompare [info patchlevel] 8.4.8] >= 0} {
	    wm iconphoto . -default [::Theme::GetImage coccinella22]
	}
    }
}

# Splash! Need a full update here, at least on Windows.
package require Splash
::Splash::SplashScreen
::Splash::SetMsg "[mc splashsource]..."
set state(launchStatus) splash
update

# Make sure we have the extra packages necessary and some optional.
::Splash::SetMsg "[mc splashhost]..."
::Init::SetHostname
::Init::LoadPackages

set state(launchStatus) tile
set prefs(tileTheme) [option get . prefs_tileTheme {}]
if {[lsearch -exact [tile::availableThemes] $prefs(tileTheme)] >= 0} {
    tile::setTheme $prefs(tileTheme)
} elseif {[tk windowingsystem] eq "x11"} {
    
    # We use the 'clam' theme as a fallback (and default in resources).
    catch {tile::setTheme clam}
}
# To help the transition from tile pre 0.8.0
proc GetCurrentTheme {} {
    if {[info exists ttk::currentTheme]} {
	return $ttk::currentTheme
    } else {
	return $tile::currentTheme
    }
}

::Theme::ReadTileResources

# The packages are divided into categories depending on their degree
# of generality.
::Splash::SetMsg "[mc splashload]..."
set state(launchStatus) packages

set packages(generic) {
    component
    hooks
    tileutils
    undo
    utils
}
set packages(uibase) {
    balloonhelp
    Tablelist_tile
    ttoolbar
    ui::util
    ui::dialog
}
set packages(application) {
    AMenu
    Dialogs
    EditDialogs
    FactoryDefaults
    Httpd
    HttpTrpt
    Media
    Network
    Preferences
    PrefGeneral
    PrefHelpers
    PrefNet
    Proxy
    SetupAss
    TheServer
    Types
    UI
    UserActions
    Utils
}
foreach class {generic uibase application} {
    foreach name $packages($class) {
	package require $name
    }
}
tileutils::configure -themechanged ::Theme::TileThemeChanged

# Platform dependent packages.
switch -- $this(platform) {
    macosx {
	package require MacintoshUtils
    }
    windows {
	package require WindowsUtils
    }
}
::UI::InitDlgs

# The Jabber stuff. 
::Splash::SetMsg "[mc splashsourcejabb]..."
set state(launchStatus) jabber
package require Jabber

# Define MIME types etc.
::Types::Init

# Standard (factory) preferences are set here.
# These are the hardcoded, application default, values, and can be
# overridden by the ones in user default file.
::Splash::SetMsg "[mc splashinit]..."
FactoryDefaults
::Jabber::FactoryDefaults
::Jabber::LoadWhiteboard

# To provide code to be run before loading componenets.
::Debug 2 "--> earlyInitHook"
::hooks::run earlyInitHook

# Components.
::Debug 2 "++> component::load"
component::lappend_auto_path $this(componentPath)
component::load

# Set the user preferences from the preferences file.
::Splash::SetMsg "[mc splashprefs]..."
set state(launchStatus) preferences
::Preferences::SetMiscPrefs

# Override any 'config's. 
# Must be after all sources and components loaded but before any init hooks.
::Init::Config

# Components that need to add their own preferences need to be registered here.
::Debug 2 "--> prefsInitHook"
::hooks::run prefsInitHook

# Parse any command line options. Can set protocol!
# @@@ There is a conflict here if some prefs settings depend on, say protocol.
::PrefUtils::ParseCommandLineOptions $argv

# Check that the mime type preference settings are consistent.
::Types::VerifyInternal

# Various initializations for canvas stuff and UI.
# In initHook UI before hooks BAD!
::UI::Init
::UI::InitMenuDefs
::UI::InitCommonBinds
::UI::InitVirtualEvents

# All components that requires some kind of initialization should register here.
# Beware, order may be important!
::Debug 2 "--> initHook"
::hooks::run initHook

# Code that requires stuff done in initHook registers for this one.
::Debug 2 "--> postInitHook"
::hooks::run postInitHook

# At this point we should be finished with the launch and delete the splash 
# screen.
::Splash::SetMsg ""
after 500 {catch {destroy $::wDlgs(splash)}}

::Jabber::Init

::Debug 2 "--> initFinalHook"
::hooks::run initFinalHook

if {$prefs(firstLaunch)} {
    ::hooks::run firstLaunchHook
}

update idletasks

::Debug 2 "--> launchFinalHook"
::hooks::run launchFinalHook
unset -nocomplain state(launchStatus)
set prefs(firstLaunch) 0

#-------------------------------------------------------------------------------
