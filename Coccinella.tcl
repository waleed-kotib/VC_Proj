#!/bin/sh
# the next line restarts using wish \
	exec wish "$0" -visual best "$@"
      
#  Coccinella.tcl ---
#  
#       This file is the main of the jabber/whiteboard application. 
#       It controls the startup sequence and therefore needs a number
#       of code files/images to be succesful.
#      
#  Copyright (c) 1999-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#
# $Id: Coccinella.tcl,v 1.29 2003-12-29 15:44:19 matben Exp $

# TclKit loading mechanism.
package provide app-Coccinella 1.0

# We want 8.4 at least.
if {[catch {package require Tk 8.4}]} {
    return -code error "We need Tk 8.4 or later here. Run Wish!"
}

# Hide the main window during launch.
wm withdraw .

set state(launchSecs) [clock seconds]

### Command-line option "-privaria" indicates whether we're
### part of Ed Suominen's PRIVARIA distribution
set privariaFlag 0
if { [set k [lsearch $argv -privaria]] >= 0 } {
    set privariaFlag 1
    set argv [concat [lrange $argv 0 [expr {$k-1}]] [lrange $argv [expr {$k+1}] end]]
    incr argc -1
}

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
set prefs(minorVers) 94
set prefs(releaseVers) 7
set prefs(fullVers) $prefs(majorVers).$prefs(minorVers).$prefs(releaseVers)

# We may be embedded in another application, say an ActiveX component.
if {[llength [namespace children :: "::browser*"]] > 0} {
    set prefs(embedded) 1
} else {
    set prefs(embedded) 0
}

# Level of detail for printouts. >= 2 for my outputs.
set debugLevel 0
# Level of detail for printouts for server. >= 2 for my outputs.
set debugServerLevel $debugLevel
# Macintosh only: if no debug printouts, no console. Also for windows?
if {[string match "mac*" $this(platform)] &&   \
  $debugLevel == 0 && $debugServerLevel == 0} {
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

#  Make sure that we are in the directory of the application itself.     
if {[string equal $this(platform) "unix"]} {
    set thisPath [file dirname [resolve_cmd_realpath [info script]]]
    set thisTail [file tail [info script]]
    set thisScript [file join $thisPath $thisTail]
} else {
    set thisScript [info script]
    set thisTail [file tail $thisScript]
    set thisPath [file dirname $thisScript]
}

Debug 2 "Installation rootdir thisPath = $thisPath"

if {$thisPath != ""} {
    cd $thisPath
}
if {[string equal $this(platform) "macintosh"] && [string equal $thisPath ":"]} {
    set thisPath [pwd]
} elseif {[string equal $thisPath "."]} {
    set thisPath [pwd]
}

# Collect paths in this array.
set this(path) $thisPath
set this(script) $thisScript
set this(imagePath) [file join $this(path) images]
set this(resourcedbPath) [file join $this(path) resources]

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

# Add our lib directory to our search path.
lappend auto_path [file join $this(path) lib]

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
    set prefs(binPath) [file dirname [info nameofexecutable]]
} else {
    set prefs(binPath) [file join $this(path) bin $this(platform) $machineSpecPath]
}
if {[file exists $prefs(binPath)]} {
    set auto_path [concat [list $prefs(binPath)] $auto_path]
} else {
    set prefs(binPath) {}
}

# Path where preferences etc are stored.
switch -- $this(platform) {
    unix {
	set this(prefsPath) [file nativename ~/.coccinella]
    }
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
    windows {
	if {[info exists env(USERPROFILE)]} {
	    set winPrefsDir $env(USERPROFILE)
	} elseif {[info exists env(HOME)]} {
	    set winPrefsDir $env(HOME)
	} elseif {[lsearch -glob [file volumes] "c:*"]} {
	    set winPrefsDir c:/
	} elseif {[lsearch -glob [file volumes] "C:*"]} {
	    set winPrefsDir C:/
	} else {
	    set winPrefsDir $this(path)
	}
	set this(prefsPath) [file join $winPrefsDir Coccinella]
    }
}
set this(themePrefsPath) [file join $this(prefsPath) theme]

# Read our theme prefs file, if any, containing the theme name.
package require Theme
::Theme::ReadPrefsFile

# Read resource database files in a hierarchical order.
# 1) always read the default rdb file.
# 2) read rdb file for this specific platform, if exists.
# 3) read rdb file for any theme we have chosen.
option readfile [file join $this(resourcedbPath) default.rdb] startupFile
set f [file join $this(resourcedbPath) $this(platform).rdb]
if {[file exists $f]} {
    option readfile $f startupFile
}
set f [file join $this(resourcedbPath) $prefs(themeName).rdb]
if {[file exists $f]} {
    option readfile $f startupFile
}

# Search for image files in this order:
# 1) imagePath/themeImageDir
# 2) imagePath/platformName
# 3) imagePath
set this(imagePathList) {}
set themeDir [option get . themeImageDir {}]
if {$themeDir != ""} {
    lappend this(imagePathList) [file join $this(imagePath) $themeDir]
}
lappend this(imagePathList)  \
  [file join $this(imagePath) $this(platform)] $this(imagePath)

# Make all images used for widgets that doesn't use the Theme package.
::Theme::PreLoadImages

# The message catalog for language customization.
if {![info exists env(LANG)]} {
    set env(LANG) en
}
package require msgcat
::msgcat::mclocale en
#::msgcat::mclocale sv
::msgcat::mcload [file join $this(path) msgs]

if {[string match "mac*" $this(platform)]} {
    # documentProc, dBoxProc, plainDBox, altDBoxProc, movableDBoxProc, 
    # zoomDocProc, rDocProc, floatProc, floatZoomProc, floatSideProc, 
    # or floatSideZoomProc
    set macWindowStyle "::tk::unsupported::MacWindowStyle style"
}

# Show it! Need a full update here, at least on Windows.
package require Splash
::SplashScreen::SplashScreen
::SplashScreen::SetMsg [::msgcat::mc splashsource]
update

# These are auxilary procedures that we need to source, rest is found in packages.
set allLibSourceFiles {
  Base64Icons.tcl        \
  EditDialogs.tcl        \
  FileUtils.tcl          \
  ItemInspector.tcl      \
  Import.tcl             \
  GetFileIface.tcl       \
  Network.tcl            \
  PutFileIface.tcl       \
  TheServer.tcl          \
  UI.tcl                 \
  UserActions.tcl        \
  Utils.tcl              \
}

foreach sourceName $allLibSourceFiles {
    source [file join $this(path) lib $sourceName]
}

# On the mac we have some extras.
if {[string equal $this(platform) "macintosh"]} {
    if {![catch {package require MacMenuButton} msg]} {
	rename menubutton menubuttonOrig
	rename macmenubutton menubutton
    }
    if {![catch {package require MovableAlerts} msg]} {
	rename tk_messageBox ""
	rename tk_newMessageBox tk_messageBox
    }
}
if {[string equal $this(platform) "macosx"]} {
    if {![catch {package require MovableAlerts} msg]} {
	rename tk_messageBox ""
	rename tk_newMessageBox tk_messageBox
    }
}

switch -- $this(platform) {
    macintosh - macosx {
	if {[catch {source [file join $this(path) lib MacintoshUtils.tcl]} msg]} {
	    after idle {tk_messageBox -message "Error sourcing MacintoshUtils.tcl  $msg"  \
	      -icon error -type ok; exit}
	}    
    }
    windows {
	if {[catch {source [file join $this(path) lib WindowsUtils.tcl]} msg]} {
	    after idle {tk_messageBox -message "Error getting WindowsUtils  $msg"  \
	      -icon error -type ok; exit}
	}    
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

::SplashScreen::SetMsg [::msgcat::mc splashload]

set listOfPackages {
    balloonhelp
    buttontray
    can2svg       
    combobox
    fontselection
    headlabel
    hooks
    moviecontroller
    mylabelframe
    sha1pure
    tablelist
    undo
    Dialogs
    AutoUpdate
    Connections
    FilesAndCanvas
    FileCache
    Preferences
    PreferencesUtils
    Types
    Plugins
    Pane
    ProgressWindow
    Speech
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

# Provides support for the jabber system.
# With the ActiveState distro of Tcl/Tk not "our" tclxml is loaded which crash.

if {!$prefs(stripJabber)} {
    ::SplashScreen::SetMsg [::msgcat::mc splashsourcejabb]
    package require Jabber
    package require VCard
    package require Sounds
}

set this(internalIPnum) 127.0.0.1
set this(internalIPname) "localhost"

# Set our IP number temporarily.
set this(ipnum) $this(internalIPnum) 

# Beware! [info hostname] can be very slow on Macs first time it is called.
::SplashScreen::SetMsg [::msgcat::mc splashhost]
set this(hostname) [info hostname]

::SplashScreen::SetMsg [::msgcat::mc splashinit]
    
# Standard (factory) preferences are set here.
# These are the hardcoded, application default, values, and can be
# overridden by the ones in user default file.
if {[catch {source [file join $this(path) lib SetFactoryDefaults.tcl]} msg]} {
    tk_messageBox -message "Error sourcing SetFactoryDefaults.tcl  $msg"  \
      -icon error -type ok
    exit
}

::SplashScreen::SetMsg [::msgcat::mc splashprefs]

# Manage the user preferences. Start by reading the preferences file.
::PreferencesUtils::Init

# Set the user preferences from the preferences file if they are there,
# else take the hardcoded defaults.
::PreferencesUtils::SetUserPreferences
if {!$prefs(stripJabber)} {
    ::Jabber::SetUserPreferences
}

# Parse any command line options.
if {$argc > 0} {
    ::PreferencesUtils::ParseCommandLineOptions $argc $argv
}

#--- Initializations -----------------------------------------------------------
#
# Order important!

# Define MIME types etc.
::Types::Init

# Load all plugins available.
::Plugins::SetBanList $prefs(pluginBanList)
::Plugins::Init

# Addons.
::Plugins::InitAddons

# Check that the mime type preference settings are consistent.
::Types::VerifyInternal

# Goes through all the logic of verifying that the actual packages are 
# available on our system. Speech special.
::Plugins::VerifyPackagesForMimeTypes
::Plugins::VerifySpeech

# Init the file cache settings.
::FileCache::SetBasedir $this(path)
::FileCache::SetBestBefore $prefs(checkCache) $prefs(incomingPath)

# Various initializations for canvas stuff and UI.
::UI::Init
::UI::InitMenuDefs
::WB::Init
::WB::InitMenuDefs

# Let main window "." be roster in jabber and whiteboard else.
if {[string equal $prefs(protocol) "jabber"]} {
    set wDlgs(jrostbro) .
    set wDlgs(mainwb) .wb0
} else {
    set wDlgs(jrostbro) .jrostbro
    set wDlgs(mainwb) .
}

# Make the actual whiteboard with canvas, tool buttons etc...
# Jabber has the roster window as "main" window.
if {![string equal $prefs(protocol) "jabber"]} {
    ::SplashScreen::SetMsg [::msgcat::mc splashbuild]
    ::WB::BuildWhiteboard $wDlgs(mainwb) -serverentrystate disabled
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
bind Entry <FocusIn> "+ ::UI::FixMenusWhenSelection %W"
bind Entry <ButtonRelease-1> "+ ::UI::FixMenusWhenSelection %W"
bind Entry <<Cut>> "+ ::UI::FixMenusWhenSelection %W"
bind Entry <<Copy>> "+ ::UI::FixMenusWhenSelection %W"
    
# Text copy/paste.
bind Text <FocusIn> "+ ::UI::FixMenusWhenSelection %W"
bind Text <ButtonRelease-1> "+ ::UI::FixMenusWhenSelection %W"
bind Text <<Cut>> "+ ::UI::FixMenusWhenSelection %W"
bind Text <<Copy>> "+ ::UI::FixMenusWhenSelection %W"

# Linux has a strange binding by default. Handled by <<Paste>>.
if {[string equal $this(platform) "unix"]} {
    bind Text <Control-Key-v> {}
}

# On non macs we need to explicitly bind certain commands.
if {![string equal $this(platform) "macintosh"]} {
    foreach wclass {Toplevel} {
	bind $wclass <$osprefs(mod)-Key-w>  \
	  [list ::UserActions::DoCloseWindow %W]
    }
}

# At this point we should be finished with the launch and delete the splash 
# screen.
::SplashScreen::SetMsg ""
after 500 {catch {destroy $wDlgs(splash)}}

# Do we need all the jabber stuff? Is this the right place? Need it for setup!
if {!$prefs(stripJabber)} {
    ::Jabber::Init
    after 600 {::Sounds::Init}
} else {
    
    # The most convinient solution is to create the namespaces at least.
    namespace eval ::Jabber:: {}
}

# Setup assistant. Must be called after initing the jabber stuff.
if {$displaySetup} {
    package require SetupAss

    catch {destroy $wDlgs(splash)}
    update
    ::Jabber::SetupAss::SetupAss .setupass
    ::UI::CenterWindow .setupass
    raise .setupass
    tkwait window .setupass
}

# Is it the first time it is launched, then show the welcome canvas.
if {$prefs(firstLaunch)} {
    ::Dialogs::Canvas $prefs(welcomeFile) -title [::msgcat::mc {Welcome}]
}
set prefs(firstLaunch) 0

### The server part ############################################################

if {$prefs(makeSafeServ)} {
    set canvasSafeInterp [interp create -safe]
    
    # This is the drawing procedure that is necessary for the alias command.
    proc CanvasDraw {w args} {
	eval $w $args
    }
    
    # Make an alias in the safe interpreter to enable drawing in the canvas.
    $canvasSafeInterp alias SafeCanvasDraw CanvasDraw
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
      -rootdirectory $prefs(httpdRootDir)]
    
    if {[catch {
	if {$prefs(Thread)} {
	    thread::send $this(httpdthreadid) $httpdScript
	
	    # Add more Mime types than the standard built in ones.
	    thread::send $this(httpdthreadid)  \
	      [list ::tinyhttpd::addmimemappings [array get prefSuffix2MimeType]]
	} else {
	    eval $httpdScript
	    ::tinyhttpd::addmimemappings [array get prefSuffix2MimeType]
	}
    } msg]} {
	tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	  [::msgcat::mc messfailedhttp $msg]]	  
    } else {
	
	# Stop before quitting.
	hooks::add quitAppHook ::tinyhttpd::stop
    }
}

# Handle any actions we need to do (-connect) according to command line options.
if {$argc > 0} {
    if {[info exists argvArr(-connect)]} {
	update idletasks
	after $prefs(afterConnect) [list ::OpenConnection::DoConnect  \
	  $argvArr(-connect) $prefs(remotePort)]
    }
}

# Auto update mechanism.
if {!$prefs(doneAutoUpdate) &&  \
  ([package vcompare $prefs(fullVers) $prefs(lastAutoUpdateVersion)] > 0)} {
    after 10000 ::AutoUpdate::Get $prefs(urlAutoUpdate)  
}

#-------------------------------------------------------------------------------
