#!/bin/sh
# the next line restarts using wish \
	exec wish "$0" -visual best "$@"
      
#  Coccinella.tcl ---
#  
#       This file is the main of the jabber/whiteboard application. 
#       It controls the startup sequence and therefore needs a number
#       of code files/images to be succesful.
#      
#  Copyright (c) 1999-2004  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#
# $Id: Coccinella.tcl,v 1.76 2004-08-18 12:08:58 matben Exp $

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

### Command-line option "-privaria" indicates whether we're
### part of Ed Suominen's PRIVARIA distribution
set privariaFlag 0
if {[lsearch $argv -privaria] >= 0 } {
    set privariaFlag 1
    set argv [lsearch -all -not -inline $argv -privaria]
}
set argc [llength $argv]

# We use a variable 'this(platform)' that is more convenient for MacOS X.
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
	    dde execute TclEval coccinella [list SecondCoccinella $argv]
	    exit
	}
	dde servername coccinella
    }
}

# Find program real pathname, resolve all links in between. Unix only.
#
# Contributed by Raymond Tang. Starkit fix by David Zolli.

proc resolve_cmd_realpath {infile} {
    global env
    
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
	foreach name [split $env(PATH) :] {
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
set prefs(majorVers) 0
set prefs(minorVers) 95
set prefs(releaseVers) 0
set prefs(fullVers) $prefs(majorVers).$prefs(minorVers).$prefs(releaseVers)

# We may be embedded in another application, say an ActiveX component.
# Need a way to detect if we are run in the Tcl plugin.
if {[llength [namespace children :: "::browser*"]] > 0} {
    set prefs(embedded) 1
} else {
    set prefs(embedded) 0
}

# Level of detail for printouts. >= 2 for my outputs.
set debugLevel 0

# Macintosh only: if no debug printouts, no console. Also for windows?
if {[string match "mac*" $this(platform)] && $debugLevel == 0} {
    catch {console hide}
}

# For debug purposes.
proc Debug {num str} {
    global  debugLevel
    if {$num <= $debugLevel} {
	puts $str
    }
}

proc CallTrace {num} {
    global  debugLevel
    if {$num <= $debugLevel} {
	puts "Tcl call trace:"
	for {set i [expr [info level] - 1]} {$i > 0} {incr i -1} {
	    puts "\t$i: [info level $i]"
	}
    }
}
if {0} {
    proc TraceVar {name1 name2 op} {
	puts "$name1 $name2 $op"
	CallTrace 4
    }
    namespace eval ::WB:: {}
    trace add variable ::WB::menuDefs(main,file) write TraceVar
}

#  Make sure that we are in the directory of the application itself.     
if {[string equal $this(platform) "unix"]} {
    set thisPath   [file dirname [resolve_cmd_realpath [info script]]]
    set thisTail   [file tail [info script]]
    set thisScript [file join $thisPath $thisTail]
} else {
    set thisScript [info script]
    set thisTail   [file tail $thisScript]
    set thisPath   [file dirname $thisScript]
}

::Debug 2 "Installation rootdir thisPath = $thisPath"

if {$thisPath != ""} {
    cd $thisPath
}
if {[string equal $this(platform) "macintosh"] && [string equal $thisPath ":"]} {
    set thisPath [pwd]
} elseif {[string equal $thisPath "."]} {
    set thisPath [pwd]
}

# Path where preferences etc are stored.
switch -- $this(platform) {
    macintosh {
	if {[info exists env(PREF_FOLDER)]} {
	    set this(prefsPath) [file join $env(PREF_FOLDER) Coccinella]
	} else {
	    set this(prefsPath) $this(path)
	}
    }
    macosx {
	set this(prefsPath)  \
	  [file join [file nativename ~/Library/Preferences] Coccinella]
    }    
    unix {
	set this(prefsPath) [file nativename ~/.coccinella]
    }
    windows {
	if {[info exists env(USERPROFILE)]} {
	    set winPrefsDir $env(USERPROFILE)
	} elseif {[info exists env(APPDATA)]} {
	    set winPrefsDir $env(APPDATA)
	} elseif {[info exists env(HOME)]} {
	    set winPrefsDir $env(HOME)
	} elseif {[info exists env(HOMEDRIVE)]} {
	    set winPrefsDir $env(HOMEDRIVE)
	} else {
	    set vols [lsort [file volumes]]
	    set vols [lsearch -all -inline -glob -not $vols A:*]
	    set vols [lsearch -all -inline -glob -not $vols B:*]
	    set winPrefsDir [lindex $vols 0]
	}
	set this(prefsPath) [file join $winPrefsDir Coccinella]
    }
}

# Collect paths in this array.
set this(path)              $thisPath
set this(script)            $thisScript
set this(imagePath)         [file join $this(path) images]
set this(altImagePath)      [file join $this(prefsPath) images]
set this(resourcedbPath)    [file join $this(path) resources]
set this(altResourcedbPath) [file join $this(prefsPath) resources]
set this(soundsPath)        [file join $this(path) sounds]
set this(altSoundsPath)     [file join $this(prefsPath) sounds]
set this(themePrefsPath)    [file join $this(prefsPath) theme]
set this(msgcatPath)        [file join $this(path) msgs]
set this(docsPath)          [file join $this(path) docs]
set this(itemPath)          [file join $this(path) items]
set this(altItemPath)       [file join $this(prefsPath) items]
set this(pluginsPath)       [file join $this(path) plugins]
set this(appletsPath)       [file join $this(path) plugins applets]
set this(componentPath)     [file join $this(path) components]
set this(emoticonsPath)     [file join $this(path) iconsets emoticons]
set this(altEmoticonsPath)  [file join $this(prefsPath) iconsets emoticons]
set this(httpdRootPath)     $this(path)
# Need to rework this...
if {0 && [info exists starkit::topdir]} {
    set this(httpdRootPath)     $starkit::topdir
    set this(httpdRelPath)      \
      [file join $::starkit::topdir lib app-Coccinella httpd]
}
set this(internalIPnum)     127.0.0.1
set this(internalIPname)    "localhost"

# Set our IP number temporarily.
set this(ipnum) $this(internalIPnum) 

# Need a tmp directory, typically in a StarKit when QuickTime movies are opened.
if {[info exists env(TMP)] && [file exists $env(TMP)]} {
    set this(tmpPath) [file join $env(TMP) tmpcoccinella]
} elseif {[info exists env(TEMP)] && [file exists $env(TEMP)]} {
    set this(tmpPath) [file join $env(TEMP) tmpcoccinella]
} else {
    switch -- $this(platform) {
	unix {
	    set this(tmpPath) [file join /tmp tmpcoccinella]
	}
	macintosh {
	    set this(tmpPath) [file join [lindex [file volumes] 0] tmpcoccinella]
	}
	macosx {
	    set this(tmpPath) [file join /tmp tmpcoccinella]
	}
	windows {
	    set this(tmpPath) [file join C:/ tmpcoccinella]
	}
    }
}
if {![file isdirectory $this(tmpPath)]} {
    file mkdir $this(tmpPath)
}

# Privaria-specific stuff
if {$privariaFlag} {
    set prefs(stripJabber) 1
    switch $this(platform) {
        unix { 
	    set x [file join privaria lib] 
	}
	windows { 
	    set x opt.privaria.lib 
        }
    }
    if {[file isdirectory [set x [file join [file dirname $this(path)] $x]]]} {
        # Append Privaria library directory to auto_path because some packages
        # are there instead of being duplicated in Coccinella distro
        lappend auto_path $x
    }

} else {
    set prefs(stripJabber) 0
}

# Add our lib and whiteboard directory to our search path.
lappend auto_path [file join $this(path) lib]
lappend auto_path [file join $this(path) whiteboard]

# Add the contrib directory which has things like widgets etc. 
lappend auto_path [file join $this(path) contrib]

# If part of Ed Suominen's PRIVARIA distribution, add its lib directory
if {$privariaFlag} {
    lappend auto_path [file join [file dirname $this(path)] lib tcl8.4]
}

if {!$prefs(stripJabber)} {
    
    # Add the jabberlib directory which provides jabber support. 
    lappend auto_path [file join $this(path) jabberlib]
    
    # Add the jabber directory which provides client specific jabber stuffs. 
    lappend auto_path [file join $this(path) jabber]
    
    # Do we need TclXML. This is in its own app specific dir.
    # Perhaps there can be a conflict if there is already an TclXML
    # package installed in the standard 'auto_path'. Be sure to have it first!
    set auto_path [concat [list [file join $this(path) TclXML]] $auto_path]
}

# This is where the "Batteries Included" binaries go. Empty if non.
if {$this(platform) == "unix"} {
    set machine $tcl_platform(machine)
    if {[regexp {[2-9]86} $tcl_platform(machine) match]} {
	set machine "i686"
    }
    set machineSpecPath [file join $tcl_platform(os) $machine]
} else {
    set machineSpecPath $tcl_platform(machine)
}

# Make cvs happy.
regsub -all " " $machineSpecPath "" machineSpecPath

# TclKits on macintosh can't load sharedlibs. Placed side-by-side with tclkit.
if {($this(platform) == "macintosh") &&  \
  ([info exists tclkit::topdir] ||  \
  [string match -nocase tclkit* [file tail [info nameofexecutable]]])} {
    set this(binPath) [file dirname [info nameofexecutable]]
} else {
    set this(binPath) [file join $this(path) bin $this(platform) $machineSpecPath]
}
if {[file exists $this(binPath)]} {
    set auto_path [concat [list $this(binPath)] $auto_path]
} else {
    set this(binPath) {}
}

# See if we have Itcl avialable already here; import namespace.
set prefs(haveItcl) 0
if {![catch {package require Itcl 3.2}]} {
    namespace import ::itcl::*
    set prefs(haveItcl) 1
}

# Read our theme prefs file, if any, containing the theme name and locale.
package require Theme
::Theme::Init

# The message catalog for language customization. Use 'en' as fallback.
package require msgcat
if {$prefs(messageLocale) == ""} {
    if {[string match -nocase "c" [::msgcat::mclocale]]} {
	::msgcat::mclocale en
    }
    set locale [::msgcat::mclocale]
} else {
    set locale $prefs(messageLocale)
    ::msgcat::mclocale $locale
}
set this(systemLocale) $locale
set langs [glob -nocomplain -tails -directory $this(msgcatPath) *.msg]
set havecat 0
foreach f $langs {
    set langcode [lindex [split [file rootname $f] _] 0]
    if {[string match -nocase ${langcode}* $locale]} {
	set havecat 1
	break
    }
}
if {!$havecat} {
    ::msgcat::mclocale en
}

# Test here if you wabt a prticular message catalog.
#::msgcat::mclocale de
::msgcat::mcload $this(msgcatPath)
namespace import ::msgcat::mc

# Show it! Need a full update here, at least on Windows.
package require Splash
::SplashScreen::SplashScreen
::SplashScreen::SetMsg [mc splashsource]
update

# These are auxilary procedures that we need to source, rest is found in packages.
set allLibSourceFiles {
  Base64Icons.tcl        \
  EditDialogs.tcl        \
  FileUtils.tcl          \
  Network.tcl            \
  TheServer.tcl          \
  UI.tcl                 \
  UserActions.tcl        \
  Utils.tcl              \
}

foreach sourceName $allLibSourceFiles {
    source [file join $this(path) lib $sourceName]
}

# On the mac we have some extras.
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

# Other utility packages that can be platform specific.
# The 'Thread' package requires that the Tcl core has been built with support.
array set extraPacksArr {
    macintosh   {http Tclapplescript MacPrint}
    macosx      {http Tclapplescript tls Thread MacCarbonPrint}
    windows     {http printer gdi tls Thread optcl tcom}
    unix        {http tls Thread}
}
foreach {platform packList} [array get extraPacksArr] {
    foreach name $packList {
	set prefs($name) 0
    }
}
foreach name $extraPacksArr($this(platform)) {
    if {![catch {package require $name} msg]} {
	set prefs($name) 1
    }
}
if {!($prefs(printer) && $prefs(gdi))} {
    set prefs(printer) 0
}

# Not ready for this yet.
set prefs(Thread) 0

# Start httpd thread. It enters its event loop if created without a sript.
if {$prefs(Thread)} {
    set this(httpdthreadid) [thread::create]
    thread::send $this(httpdthreadid) [list set auto_path $auto_path]
}

# As an alternative to sourcing tcl code directly, use the package mechanism.

::SplashScreen::SetMsg [mc splashload]

set listOfPackages {
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
    Preferences
    PreferencesUtils
    Types
    Plugins
    Pane
    ProgressWindow
    Whiteboard
}
foreach packName $listOfPackages {
    package require $packName
}

# The 'tinyhttpd' package must be loaded in its threads interpreter if exists.
if {$prefs(Thread)} {
    thread::send $this(httpdthreadid) {package require tinyhttpd}
} else {
    package require tinyhttpd
}

# The Jabber stuff.
if {!$prefs(stripJabber)} {
    ::SplashScreen::SetMsg [mc splashsourcejabb]
    package require Jabber
}

# Beware! [info hostname] can be very slow on Macs first time it is called.
::SplashScreen::SetMsg [mc splashhost]
set this(hostname) [info hostname]

::SplashScreen::SetMsg [mc splashinit]
    
# Standard (factory) preferences are set here.
# These are the hardcoded, application default, values, and can be
# overridden by the ones in user default file.
source [file join $this(path) lib SetFactoryDefaults.tcl]
::SplashScreen::SetMsg [mc splashprefs]

# Manage the user preferences. Start by reading the preferences file.
::PreferencesUtils::Init

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

# A mechanism to set -state of cut/copy/paste. Not robust!!!
# All selections are not detected (shift <- -> etc).
# Entry copy/paste.
bind Entry <FocusIn>         "+ ::UI::FixMenusWhenSelection %W"
bind Entry <ButtonRelease-1> "+ ::UI::FixMenusWhenSelection %W"
bind Entry <<Cut>>           "+ ::UI::FixMenusWhenSelection %W"
bind Entry <<Copy>>          "+ ::UI::FixMenusWhenSelection %W"
    
# Text copy/paste.
bind Text <FocusIn>         "+ ::UI::FixMenusWhenSelection %W"
bind Text <ButtonRelease-1> "+ ::UI::FixMenusWhenSelection %W"
bind Text <<Cut>>           "+ ::UI::FixMenusWhenSelection %W"
bind Text <<Copy>>          "+ ::UI::FixMenusWhenSelection %W"

# Linux has a strange binding by default. Handled by <<Paste>>.
if {[string equal $this(platform) "unix"]} {
    bind Text <Control-Key-v> {}
}
if {[string equal $this(platform) "windows"]} {
    wm iconbitmap . -default [file join $this(imagePath) coccinella.ico]
}
wm protocol . WM_DELETE_WINDOW {::UI::DoCloseWindow .}

# Just experimenting with the 'tile' extension...
if {0} {
    package require tile
    foreach name {button radiobutton checkbutton menubutton scrollbar \
      labelframe} {
	rename $name ""
	rename t${name} $name
    }
}

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

### The server part ############################################################

if {$prefs(makeSafeServ)} {
    set canvasSafeInterp [interp create -safe]
    
    # Make an alias in the safe interpreter to enable drawing in the canvas.
    $canvasSafeInterp alias SafeCanvasDraw ::CanvasUtils::CanvasDrawSafe
}
    
# Start the server. It was necessary to have an 'update idletasks' command here
# because when starting the script directly, and not from within wish, somehow
# there was a timing problem in 'DoStartServer'.
# Don't start the server if we are a client only.

if {($prefs(protocol) != "client") && $prefs(autoStartServer)} {
    after $prefs(afterStartServer) [list DoStartServer $prefs(thisServPort)]
}

# Start the tinyhttpd server, in its own thread if available.

if {($prefs(protocol) != "client") && $prefs(haveHttpd)} {
    set httpdScript [list ::tinyhttpd::start -port $prefs(httpdPort)  \
      -rootdirectory $this(httpdRootPath)]
    if {$debugLevel > 0} {
	lappend httpdScript -directorylisting 1
    }
    
    if {[catch {
	if {$prefs(Thread)} {
	    thread::send $this(httpdthreadid) $httpdScript
	
	    # Add more Mime types than the standard built in ones.
	    thread::send $this(httpdthreadid)  \
	      [list ::tinyhttpd::addmimemappings [::Types::GetSuffMimeArr]]
	} else {
	    eval $httpdScript
	    ::tinyhttpd::addmimemappings [::Types::GetSuffMimeArr]
	}
    } msg]} {
	tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	  [mc messfailedhttp $msg]]	  
    } else {
	
	# Stop before quitting.
	::hooks::add quitAppHook ::tinyhttpd::stop
    }
}

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
