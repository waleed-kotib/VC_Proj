#!/bin/sh
# the next line restarts using wish \
	exec wish "$0" -visual best "$@"
      
#  Coccinella.tcl ---
#  
#      This file is the main of the whiteboard application. It depends on
#      a number of other files. The 'lib' directory contains the other tcl
#      code that gets sourced here. The 'images' directory contains icons
#      and other images needed by this script. The 'items' directory
#      contains a library of canvas items that are accesable directly from
#      a menu.
#      
#  Copyright (c) 1999-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#
# $Id: Coccinella.tcl,v 1.2 2003-08-23 07:19:16 matben Exp $

#--Descriptions of some central variables and their usage-----------------------
#            
#  The ip number is central to all administration of connections.
#  Each connection has a unique ip number from which all other necessary
#  variables are looked up using arrays:
#  
#  ipNumTo(name,$ip):    maps ip number to the specific domain name.
#  
#  ipName2Num:       inverse of above.
#  
#  ipNumTo(socket,$ip):  maps ip number to the specific socket that is used for 
#                    sending canvas commands and other commands. It is the 
#                    socket opened by the client, except in the case this is 
#                    the central server in a centralized network.
#                    
#  ipNumTo(servSocket,$ip): maps ip number to the server side socket opened from
#                    a remote client.
#                                      
#  ipNumTo(servPort,$ip): maps ip number to the specific remote server port number.
#  
#  ipNumTo(user,$ip):    maps ip number to the user name.
#  
#  ipNumTo(connectTime,$ip):    maps ip number to time when connected.
#  
#-------------------------------------------------------------------------------

# TclKit loading mechanism.
package provide app-Coccinella 1.0

# TclKit requires this, can't harm.
if {[catch {package require Tk}]} {
    return -code error "We need Tk here. Run Wish!"
}

# Hide the main window during launch.
wm withdraw .

### Command-line option "-privaria" indicates whether we're
### part of Ed Suominen's PRIVARIA distribution
set privariaFlag 0
if { [set k [lsearch $argv -privaria]] >= 0 } {
    set privariaFlag 1
    set argv [concat [lrange $argv 0 [expr {$k-1}]] [lrange $argv [expr {$k+1}] end]]
    incr argc -1
}

if {[package vcompare [info tclversion] 8.4] == -1} {
    tk_messageBox -message  \
      "This application requires Tcl/Tk version 8.4 or later."  \
      -icon error -type ok
    exit
}

# We use a variable 'this(platform)' that is more convenient for MacOS X.
switch -- $tcl_platform(platform) {
    unix {
	set this(platform) $tcl_platform(platform)
	if {[package vcompare [info tclversion] 8.3] == 1} {	
	    if {[string equal [tk windowingsystem] "aqua"]} {
		set this(platform) "macosx"
	    }
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
set prefs(releaseVers) 5
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
set debugServerLevel 0
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
      
if {[string equal $this(platform) "macintosh"] && ([info tclversion] < 8.4)} {
    
    # The first launch the path must be specified, else we store it in a
    # special prefs file.
    set haveMacSpecialPrefs 0
    set specialMacPrefPath [file join $env(PREF_FOLDER) CoccinellaInstallPath]
    if {[file exists $specialMacPrefPath]} {
	if {![catch {option readfile $specialMacPrefPath} err]} {
	    set thisPath [option get . thisPath {}]
	    set installDirName "Whiteboard-$prefs(fullVers)"
	    if {[file exists $thisPath] &&  \
	      [string equal [lindex [file split $thisPath] end] $installDirName]} {
		set haveMacSpecialPrefs 1
	    }
	}
    }
    if {!$haveMacSpecialPrefs} {
	tk_messageBox -icon info -type ok -message  \
	  "Due to the 'info script' bug on Mac you\
	  need to explicitly pick the 'Whiteboard-$prefs(fullVers)'\
	  folder in the following dialog."
	set thisPath [tk_chooseDirectory -title "Pick Whiteboard-$prefs(fullVers)"]
    }
    set thisScript [file join $thisPath Coccinella.tcl]
} elseif {[string equal $this(platform) "unix"]} {
    set thisPath [file dirname [resolve_cmd_realpath [info script]]]
    set thisTail [file tail [info script]]
    set thisScript [file join $thisPath $thisTail]
} else {
    set thisScript [info script]
    set thisTail [file tail $thisScript]
    if {$thisScript == ""} {
	set thisScript [tk_getOpenFile -title "Pick Coccinella.tcl"]
	if {$thisScript == ""} {
	    exit
	}
    }
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
set this(path) $thisPath
set this(script) $thisScript

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
set prefs(binDir) [file join $this(path) bin $this(platform) $machineSpecPath]
if {[file exists $prefs(binDir)]} {
    set auto_path [concat [list $prefs(binDir)] $auto_path]
} else {
    set prefs(binDir) {}
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
if {[string match "mac*" $this(platform)]} {
    if {[info tclversion] <= 8.3} {
	set macWindowStyle "unsupported1 style"
    } else {
	set macWindowStyle "::tk::unsupported::MacWindowStyle style"
    }
}

set state(launchSecs) [clock seconds]

# Fonts needed in the splash screen and elsewhere.
# These should work allright for latin character sets.
if {1} {
    switch -- $this(platform) {
	unix {
	    set sysFont(s) {Helvetica -10 normal}
	    set sysFont(sb) {Helvetica -10 bold}
	    set sysFont(m) $sysFont(s)
	    set sysFont(l) {Helvetica -18 normal}
	}
	macintosh {
	    set sysFont(s) [font create -family Geneva -size 9]
	    set sysFont(sb) [font create -family Geneva -size 9 -weight bold]
	    set sysFont(m) application
	    set sysFont(l) [font create -family Helvetica -size 18]
	}
	macosx {
	    #set sysFont(s) {{Lucida Grande} 11 normal}
	    #set sysFont(sb) {{Lucida Grande} 11 bold}
	    #set sysFont(m) application
	    #set sysFont(l) {Helvetica 18 normal}
	    set sysFont(s) [font create -family {Lucida Grande} -size 11]
	    set sysFont(sb) [font create -family {Lucida Grande} -size 11 -weight bold]
	    set sysFont(m) application
	    set sysFont(l) [font create -family Helvetica -size 18]
	}
	windows {
	    set sysFont(s) {Arial 8 normal}
	    set sysFont(sb) {Arial 8 bold}
	    set sysFont(m) $sysFont(s)
	    set sysFont(l) {Helvetica 18 normal}
	}
    }
} else {
    
    # Fill in nonlatin character sets here appropriate for your system.
}

# The message catalog for language customization.
if {![info exists env(LANG)]} {
    set env(LANG) en
}
package require msgcat
::msgcat::mclocale en
#::msgcat::mclocale sv
::msgcat::mcload [file join $this(path) msgs]

# The splash screen is needed from the start. This also defines $wDlgs.
package require Dialogs

# Needed in splash screen.
proc GetScreenSize { } {
    return [list [winfo vrootwidth .] [winfo vrootheight .]]
}

# Show it! Need a full update here, at least on Windows.
::SplashScreen::SplashScreen $wDlgs(splash)
::SplashScreen::SetMsg [::msgcat::mc splashsource]
update

# These are auxilary procedures that we need to source, rest is found in packages.
set allLibSourceFiles {
  Base64Icons.tcl        \
  CanvasCutCopyPaste.tcl \
  EditDialogs.tcl        \
  FileUtils.tcl          \
  ItemInspector.tcl      \
  ImageAndMovie.tcl      \
  GetFileIface.tcl       \
  Network.tcl            \
  PutFileIface.tcl       \
  Utils.tcl              \
  SequenceGrabber.tcl    \
  TheServer.tcl          \
  UI.tcl                 \
  UserActions.tcl        \
}

foreach sourceName $allLibSourceFiles {
    if {$debugLevel == 0} {
	if {[catch {source [file join $this(path) lib $sourceName]} msg]} {
	    after idle {tk_messageBox -message "Error sourcing $sourceName:  $msg"  \
	      -icon error -type ok; exit}
	}    
    } else {
	source [file join $this(path) lib $sourceName]
    }
}

# The http package can be useful?
if {![catch {package require http} msg]} {
    set prefs(http) 1
} else {
    set prefs(http) 0
}

# Other utility packages.
foreach name {Tclapplescript printer gdi tls optcl tcom} {
    set prefs($name) 0
}
array set extraPacksArr {
    macintosh   {Tclapplescript}
    macosx      {Tclapplescript tls}
    windows     {printer gdi tls optcl tcom}
    unix        {tls}
}

foreach name $extraPacksArr($this(platform)) {
    if {![catch {package require $name} msg]} {
	set prefs($name) 1
    }
}
if {!($prefs(printer) && $prefs(gdi))} {
    set prefs(printer) 0
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
	    after idle {tk_messageBox -message "Error sourcing WindowsUtils.tcl  $msg"  \
	      -icon error -type ok; exit}
	}    
    }
}

# As an alternative to sourcing tcl code directly, use the package mechanism.

::SplashScreen::SetMsg [::msgcat::mc splashload]

set listOfPackages {
    CanvasDraw
    CanvasText
    CanvasUtils
    Connections
    FilesAndCanvas
    FileCache
    Preferences
    PreferencesUtils
    TinyHttpd
    Types
    Plugins
    AutoUpdate
    combobox
    Pane
    moviecontroller
    fontselection
    tablelist
    balloonhelp
    undo
    can2svg            
}
foreach packName $listOfPackages {
    package require $packName
}
if {[catch {package require progressbar} msg]} {
    set prefs(Progressbar) 0
} else {
    set prefs(Progressbar) 1
}

# Note: progressbar before ProgressWindow
package require ProgressWindow
::SplashScreen::SetMsg [::msgcat::mc splashloadsha1]
package require sha1pure

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

# Try to get own ip number from a temporary server socket.
# This can be a bit complicated as different OS sometimes give 0.0.0.0 or
# 127.0.0.1 instead of the real number.

if {![catch {socket -server puts 0} s]} {
    set this(ipnum) [lindex [fconfigure $s -sockname] 0]
    catch {close $s}
    Debug 2 "1st: this(ipnum)=$this(ipnum)"
}

# If localhost or zero, try once again with '-myaddr'. 
# My Linux box is not helped by this either!!!
# Multiple ip interfaces are not recognized!
if {[string equal $this(ipnum) "0.0.0.0"] ||  \
  [string equal $this(ipnum) "127.0.0.1"]} {
    if {![catch {socket -server xxx -myaddr $this(hostname) 0} s]} {
	set this(ipnum) [lindex [fconfigure $s -sockname] 0]
	catch {close $s}
	Debug 2 "2nd: this(ipnum)=$this(ipnum)"
    }
}
if {[regexp {[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+} $this(ipnum)]} {
    set this(ipver) 4
} else {
    set this(ipver) 6
}

::SplashScreen::SetMsg [::msgcat::mc splashinit]

# Find user name.
if {[info exists env(USER)]} {
    set this(username) $env(USER)
} elseif {[info exists env(LOGIN)]} {
    set this(username) $env(LOGIN)
} elseif {[info exists env(USERNAME)]} {
    set this(username) $env(USERNAME)
} elseif {[llength $this(hostname)]} {
    set this(username) $this(hostname)
} else {
    set this(username) "Unknown"
}

# Keep lists of ip numbers for connected clients and servers.
# For the jabber configuration, 'allIPnums', 'allIPnumsTo', and 
# 'allIPnumsToSend', all just contain the IP number of the jabber server.
# 'allIPnums' contains all ip nums that are either connected to, or from.
# It is the union of 'allIPnumsTo' and 'allIPnumsFrom'.
set allIPnums {}

# 'allIPnumsTo' contains all ip nums that we have made a client side connect to.
set allIPnumsTo {}

# 'allIPnumsFrom' contains all ip nums that are connected to our server.
set allIPnumsFrom {}

# 'allIPnumsToSend' is identical to 'allIPnumsTo' except when this is
# the server in a centralized network because then we do not make
# any connections, but all connections are connected 'from'.
set allIPnumsToSend {}
    
# Standard (factory) preferences are set here.
# These are the hardcoded, application default, values, and can be
# overridden by the ones in user default file.
if {[catch {source [file join $this(path) lib SetFactoryDefaults.tcl]} msg]} {
    tk_messageBox -message "Error sourcing SetFactoryDefaults.tcl  $msg"  \
      -icon error -type ok
    exit
}

::SplashScreen::SetMsg [::msgcat::mc splashprefs]

# Set defaults in the option database for widget classes.
::PreferencesUtils::SetWidgetDefaultOptions

# Manage the user preferences. Start by reading the preferences file.
::PreferencesUtils::Init

# Set the user preferences from the preferences file if they are there,
# else take the hardcoded defaults.
::PreferencesUtils::SetUserPreferences

# Parse any command line options.
if {$argc > 0} {
    ::PreferencesUtils::ParseCommandLineOptions $argc $argv
}

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

#--- User Interface ------------------------------------------------------------

# Various initializations for canvas stuff and UI.
::CanvasUtils::Init
::UI::Init
::UI::InitMenuDefs

# Create the mapping between Html sizes and font point sizes dynamically.
::CanvasUtils::CreateFontSizeMapping

# Let main window "." be roster in jabber and whiteboard else.
if {[string equal $prefs(protocol) "jabber"]} {
    set wDlgs(jrostbro) .jrostbro
    set wDlgs(mainwb) .
    #set wDlgs(jrostbro) .
    #set wDlgs(mainwb) .jrostbro
} else {
    set wDlgs(mainwb) .
}

# Make the actual whiteboard with canvas, tool buttons etc...
# Jabber has the roster window as "main" window.
if {![string equal $prefs(protocol) "jabber"]} {
    ::SplashScreen::SetMsg [::msgcat::mc splashbuild]
    ::UI::BuildMain $wDlgs(mainwb) -serverentrystate disabled
}
if {$prefs(firstLaunch) && !$prefs(stripJabber)} {
    wm withdraw $wDlgs(mainwb)
    set displaySetup 1
} else {
    set displaySetup 0
}

# A mechanism to set -state of cut/copy/paste. Not robust!!!
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
	
# Mac OS X have the Quit menu on the Apple menu instead. Catch it!
if {[string equal $this(platform) "macosx"]} {
    if {![catch {package require tclAE}]} {
	tclAE::installEventHandler aevt quit ::UI::AEQuitHandler
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

# Start the TinyHttpd server. Perhaps this should go in its own thread...?

if {($prefs(protocol) != "client") && $prefs(haveHttpd)} {
    if {[catch {  \
      ::TinyHttpd::Start -port $prefs(httpdPort) -rootdirectory $prefs(httpdRootDir)} msg]} {
	tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	  [::msgcat::mc messfailedhttp $msg]]	  
    } else {
	
	# Add more Mime types than the standard built in ones.
	::TinyHttpd::AddMimeMappings prefSuffix2MimeType
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
