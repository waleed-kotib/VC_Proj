#!/bin/sh
# the next line restarts using wish \
	exec wish "$0" -visual best "$@"
      
#  Coccinella.tcl ---
#  
#       This file is the main of the jabber/whiteboard application. 
#       It controls the startup sequence and therefore needs a number
#       of code files/images to be succesful.
#      
#  Copyright (c) 1999-2005  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#
# $Id: Coccinella.tcl,v 1.109 2005-02-04 07:05:25 matben Exp $
	

# Level of detail for printouts. >= 2 for my outputs.
set debugLevel 0

# TclKit loading mechanism.
package provide app-Coccinella 1.0

# We want 8.4 at least.
if {[catch {package require Tk 8.4}]} {
    return -code error "We need Tk 8.4 or later here. Run Wish!"
}

# Hide the main window during launch.
wm withdraw .
tk appname coccinella

set state(launchSecs) [clock seconds]

# MacOSX adds a -psn_* switch.
set argv [lsearch -all -not -inline -regexp $argv {-psn_\d*}]
set argc [llength $argv]
array set argvArr $argv

# We use a variable 'this(platform)' that is more convenient for MacOSX.
switch -- $tcl_platform(platform) {
    unix {
	if {[string equal [tk windowingsystem] "aqua"]} {
	    set this(platform) "macosx"
	} else {
	    set this(platform) $tcl_platform(platform)
	}
    }
    windows - macintosh {
	set this(platform) $tcl_platform(platform)
    }
}

# We should only allow a single instance of this application.
switch -- $this(platform) {
    windows {
	
	# A COM interface would be better...
	package require dde
	
	# If any services available for coccinella then provide the argv.
	set services [dde services TclEval coccinella]
	if {$services != {}} {
	    dde execute TclEval coccinella [concat SecondCoccinella $argv]
	    exit
	}
	dde servername coccinella
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

# The application major and minor version numbers; should only be written to
# default file, never read.
set prefs(majorVers)    0
set prefs(minorVers)   95
set prefs(releaseVers)  5
set prefs(fullVers) $prefs(majorVers).$prefs(minorVers).$prefs(releaseVers)
set prefs(appName)    "Coccinella"
set prefs(theAppName) "The Coccinella"

# We may be embedded in another application, say an ActiveX component.
# Need a way to detect if we are run in the Tcl plugin.
if {[llength [namespace children :: "::browser*"]] > 0} {
    set prefs(embedded) 1
} else {
    set prefs(embedded) 0
}

# Identify our own position in the file system.
if {[string equal $this(platform) "unix"]} {
    set thisScript [file normalize [resolve_cmd_realpath [info script]]]
} else {
    set thisScript [file normalize [info script]]
}
set thisPath [file normalize [file dirname $thisScript]]
if {[info exists ::env(HOME)]} {
    cd $::env(HOME)
} else {
    catch {cd ~}
}

# Debug support.
source [file join $thisPath lib Debug.tcl]

::Debug 2 "Installation rootdir:  [file dirname $thisScript]"

# Set up 'this' array which contains admin stuff.
source [file join $thisPath lib Init.tcl]
::Init::SetThis $thisScript
::Init::SetAutoPath

# See if we have Itcl avialable already here; import namespace.
set prefs(haveItcl) 0
if {![catch {package require Itcl 3.2}]} {
    namespace import ::itcl::*
    set prefs(haveItcl) 1
}

# Read our prefs file containing the theme name and locale needed before splash.
package require PreferencesUtils
package require Theme
::PreferencesUtils::Init
::Theme::Init

# Find our language and load message catalog.
::Init::Msgcat

# Show it! Need a full update here, at least on Windows.
package require Splash
::SplashScreen::SplashScreen
::SplashScreen::SetMsg [mc splashsource]
update

# These are auxilary procedures that we need to source, rest is found in packages.
set allLibSourceFiles {
  Base64Icons.tcl        \
  EditDialogs.tcl        \
  Network.tcl            \
}

foreach sourceName $allLibSourceFiles {
    source [file join $this(path) lib $sourceName]
}

# On the mac we have some extras. Should go away in later versions of AquaTk.
if {[string equal $this(platform) "macosx"]} {
    if {![catch {package require MovableAlerts} msg]} {
	rename tk_messageBox ""
	rename tk_newMessageBox tk_messageBox
    }
}

switch -- $this(platform) {
    macintosh - macosx {
	source [file join $this(path) lib MacintoshUtils.tcl]
    }
    windows {
	source [file join $this(path) lib WindowsUtils.tcl]
    }
}

::Init::LoadPackages

# We should make this a little different!
# Separate packages into two levels, basic support and application specific.
::SplashScreen::SetMsg [mc splashload]

foreach packName {
    balloonhelp
    buttontray
    can2svg       
    combobox
    component
    fontselection
    headlabel
    hooks
    tablelist
    undo
    Dialogs
    FileCache
    Httpd
    HttpTrpt
    Preferences
    Types
    Plugins
    Pane
    ProgressWindow
    TheServer
    UI
    UserActions
    Utils
    Whiteboard
} {
    package require $packName
}

# The Jabber stuff.
if {!$prefs(stripJabber)} {
    ::SplashScreen::SetMsg [mc splashsourcejabb]
    package require Jabber
}

::UI::InitDlgs

# Beware! [info hostname] can be very slow on Macs first time it is called.
::SplashScreen::SetMsg [mc splashhost]
set this(hostname) [info hostname]

::SplashScreen::SetMsg [mc splashinit]
    
# Standard (factory) preferences are set here.
# These are the hardcoded, application default, values, and can be
# overridden by the ones in user default file.
source [file join $this(path) lib SetFactoryDefaults.tcl]
::SplashScreen::SetMsg [mc splashprefs]

# Set the user preferences from the preferences file if they are there,
# else take the hardcoded defaults.
::PreferencesUtils::SetUserPreferences
if {!$prefs(stripJabber)} {
    ::Jabber::SetUserPreferences
}

# Define MIME types etc.
::Types::Init

# To provide code to be run before loading componenets.
::Debug 2 "--> earlyInitHook"
::hooks::run earlyInitHook

# Components.
::Debug 2 "++> component::load"
component::lappend_auto_path $this(componentPath)
component::load

# Components that need to add their own preferences need to be registered here.
::Debug 2 "--> prefsInitHook"
::hooks::run prefsInitHook

# Parse any command line options.
if {$argc > 0} {
    ::Debug 2 "argv=$argv"
    ::PreferencesUtils::ParseCommandLineOptions $argc $argv
}

switch -- $prefs(protocol) {
    jabber {
	# empty
    }
    default {
	package require P2P
	package require P2PNet
    }
}

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

# Let main window "." be roster in jabber and whiteboard else.
if {[string equal $prefs(protocol) "jabber"]} {
    set wDlgs(jrostbro) .
    set wDlgs(mainwb)   .wb0
} else {
    set wDlgs(jrostbro) .jrostbro
    set wDlgs(mainwb)   .
}

# Make the actual whiteboard with canvas, tool buttons etc...
# Jabber has the roster window as "main" window.
if {![string equal $prefs(protocol) "jabber"]} {
    ::SplashScreen::SetMsg [mc splashbuild]
    ::WB::BuildWhiteboard $wDlgs(mainwb) -usewingeom 1
}
if {$prefs(firstLaunch) && !$prefs(stripJabber)} {
    if {[winfo exists $wDlgs(mainwb)]} {
	wm withdraw $wDlgs(mainwb)
    }
    set displaySetup 1
} else {
    set displaySetup 0
}

if {[string equal $this(platform) "windows"]} {
    wm iconbitmap . -default [file join $this(imagePath) coccinella.ico]
}
wm protocol . WM_DELETE_WINDOW {::UI::DoCloseWindow .}

# At this point we should be finished with the launch and delete the splash 
# screen.
::SplashScreen::SetMsg ""
after 500 {catch {destroy $wDlgs(splash)}}

# Do we need all the jabber stuff? Is this the right place? Need it for setup!
if {($prefs(protocol) == "jabber") && !$prefs(stripJabber)} {
    ::Jabber::Init
} else {
    
    # The most convinient solution is to create the namespaces at least.
    namespace eval ::Jabber:: {}
}

# Setup assistant. Must be called after initing the jabber stuff.
if {$displaySetup} {
    package require SetupAss

    catch {destroy $wDlgs(splash)}
    update
    ::Jabber::SetupAss::SetupAss
    ::UI::CenterWindow $wDlgs(setupass)
    raise $wDlgs(setupass)
    tkwait window $wDlgs(setupass)
}

# Is it the first time it is launched, then show the welcome canvas.
if {$prefs(firstLaunch)} {
    set systemLocale [lindex [split $this(systemLocale) _] 0]
    set floc [file join $this(docsPath) Welcome_${systemLocale}.can]
    if {[file exists $floc]} {
	set f $floc
    } else {
	set f [file join $this(docsPath) Welcome_en.can]
    }
    ::Dialogs::Canvas $f -title [mc {Welcome}]
}
set prefs(firstLaunch) 0

::Debug 7 "auto_path:\n[join $auto_path \n]"

# Handle any actions we need to do (-connect) according to command line options.
if {$argc > 0} {
    if {[info exists argvArr(-connect)]} {
	update idletasks
	after $prefs(afterConnect) [list ::P2PNet::DoConnect  \
	  $argvArr(-connect) $prefs(remotePort)]
    }
}

update idletasks
::Debug 2 "--> launchFinalHook"
::hooks::run launchFinalHook

#-------------------------------------------------------------------------------
