#!/bin/sh
# the next line restarts using wish \
	exec wish "$0" -visual best "$@"
      
#  Whiteboard.tcl ---
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
# $Id: Whiteboard.tcl,v 1.7 2003-04-28 13:32:25 matben Exp $

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
      
# TclKit requires this, can't harm.
if {[catch {package require Tk}]} {
    error {We need Tk here. Run Wish!}
}

### Command-line option "-privaria" indicates whether we're
### part of Ed Suominen's PRIVARIA distribution
set privariaFlag 0
if { [set k [lsearch $argv -privaria]] >= 0 } {
    set privariaFlag 1
    set argv [concat [lrange $argv 0 [expr {$k-1}]] [lrange $argv [expr {$k+1}] end]]
    incr argc -1
}

if {[package vcompare [info tclversion] 8.3] == -1} {
    tk_messageBox -message  \
      {This application requires Tcl/Tk version 8.3 or later.}  \
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
# Contributed by Raymond Tang.

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
	return $infile
    }
}

# The application major and minor version numbers; should only be written to
# default file, never read.
set prefs(majorVers) 0
set prefs(minorVers) 94
set prefs(releaseVers) 4
set prefs(fullVers) $prefs(majorVers).$prefs(minorVers).$prefs(releaseVers)

# We may be embedded in another application, say an ActiveX component.
if {[llength [namespace children :: "::browser*"]] > 0} {
    set prefs(embedded) 1
} else {
    set prefs(embedded) 0
}

# Level of detail for printouts. >= 2 for my outputs.
set debugLevel 4
# Level of detail for printouts for server. >= 2 for my outputs.
set debugServerLevel 3
# Macintosh only: if no debug printouts, no console. Also for windows?
if {[string match "mac*" $this(platform)] &&   \
  $debugLevel == 0 && $debugServerLevel == 0} {
    catch {console hide}
}
proc Debug {num str} {
    global  debugLevel
    if {$num <= $debugLevel} {
	puts $str
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
    set thisScript [file join $thisPath Whiteboard.tcl]
} elseif {[string equal $this(platform) "unix"]} {
    set thisPath [file dirname [resolve_cmd_realpath [info script]]]
    set thisScript [file join $thisPath Whiteboard.tcl]
} else {
    set thisScript [info script]
    if {$thisScript == ""} {
	set thisScript [tk_getOpenFile -title "Pick Whiteboard.tcl"]
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
	rename menubutton ""
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

# Hide the main window during launch.
wm withdraw .

# Fonts needed in the splash screen and elsewhere.
# These should work allright for latin character sets.
if {1} {
    switch -- $this(platform) {
	unix {
	    set sysFont(s) {Helvetica 10 normal}
	    set sysFont(sb) {Helvetica 10 bold}
	    set sysFont(m) $sysFont(s)
	    set sysFont(l) {Helvetica 18 normal}
	}
	macintosh {
	    set sysFont(s) {Geneva 9 normal}
	    set sysFont(sb) {Geneva 9 bold}
	    set sysFont(m) application
	    set sysFont(l) {Helvetica 18 normal}
	}
	macosx {
	    set sysFont(s) {Geneva 9 normal}
	    set sysFont(sb) {Geneva 9 bold}
	    set sysFont(s) {{Lucida Grande} 11 normal}
	    set sysFont(sb) {{Lucida Grande} 11 bold}
	    set sysFont(m) application
	    set sysFont(l) {Helvetica 18 normal}
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
update

# Need to set a trace on variable containing the splash start message.
proc TraceStartMessage {varName junk op} {
    global  wDlgs
    
    # Update needed to force display (bad?).
    if {[winfo exists $wDlgs(splash)]} {
	${wDlgs(splash)}.can itemconfigure tsplash  \
	  -text $::SplashScreen::startMsg
	update idletasks
    }
}

trace variable ::SplashScreen::startMsg w TraceStartMessage
set ::SplashScreen::startMsg [::msgcat::mc splashsource]

# These are auxilary procedures that we need to source, rest is found in packages.
set allLibSourceFiles {
  Base64Icons.tcl        \
  CanvasCutCopyPaste.tcl \
  EditDialogs.tcl        \
  FileUtils.tcl          \
  ItemInspector.tcl      \
  ImageAndMovie.tcl      \
  GetFile.tcl            \
  Network.tcl            \
  PutFileIface.tcl       \
  Utils.tcl              \
  SequenceGrabber.tcl    \
  TheServer.tcl          \
  UI.tcl                 \
  UserActions.tcl        \
}

foreach sourceName $allLibSourceFiles {
    if {0 && [catch {source [file join $this(path) lib $sourceName]} msg]} {
	after idle {tk_messageBox -message "Error sourcing $sourceName:  $msg"  \
	  -icon error -type ok; exit}
    }    
    source [file join $this(path) lib $sourceName]
}

# The http package can be useful?
if {![catch {package require http} msg]} {
    set prefs(http) 1
} else {
    set prefs(http) 0
}

# Other utility packages.
set prefs(applescript) 0
set prefs(printer) 0
set prefs(tls) 0
set prefs(optcl) 0
set prefs(tcom) 0
switch -- $this(platform) {
    macintosh - macosx {
	if {[catch {source [file join $this(path) lib MacintoshUtils.tcl]} msg]} {
	    after idle {tk_messageBox -message "Error sourcing MacintoshUtils.tcl  $msg"  \
	      -icon error -type ok; exit}
	}    
	if {![catch {package require Tclapplescript} msg]} {
	    set prefs(applescript) 1
	}
    }
    windows {
	if {[catch {source [file join $this(path) lib WindowsUtils.tcl]} msg]} {
	    after idle {tk_messageBox -message "Error sourcing WindowsUtils.tcl  $msg"  \
	      -icon error -type ok; exit}
	}    
	if {![catch {package require printer} msg] &&  \
	  ![catch {package require gdi} msg]} {
	    set prefs(printer) 1
	}
	if {![catch {package require tls} msg]} {
	    set prefs(tls) 1
	}
	if {![catch {package require optcl} msg]} {
	    set prefs(optcl) 1
	}
	if {![catch {package require tcom} msg]} {
	    set prefs(tcom) 1
	}
    }
    unix {
	if {![catch {package require tls} msg]} {
	    set prefs(tls) 1
	}
    }
}

# As an alternative to sourcing tcl code directly, use the package mechanism.

set ::SplashScreen::startMsg [::msgcat::mc splashload]

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
set ::SplashScreen::startMsg [::msgcat::mc splashloadsha1]
package require sha1pure

# Provides support for the jabber system.
# With the ActiveState distro of Tcl/Tk not "our" tclxml is loaded which crash.

if {!$prefs(stripJabber)} {
    set ::SplashScreen::startMsg [::msgcat::mc splashsourcejabb]
    package require Jabber
    package require VCard
    package require Sounds
}

# Import routines that get exported from various namespaces in the lib files.
# This is a bit inconsistent since I sometimes use import namespace and 
# sometimes the fully qulified name; need to sort out this later.
# Note that the lib routines above need fully qualified names!

namespace import ::CanvasDraw::*
namespace import ::CanvasCCP::*
namespace import ::GetFile::*
namespace import ::OpenConnection::*
namespace import ::OpenMulticast::*
namespace import ::PreferencesUtils::*
namespace import ::TinyHttpd::*
namespace import ::UserActions::*

# Define MIME types etc., and get packages.
if {[catch {source [file join $this(path) lib MimeTypesAndPlugins.tcl]} msg]} {
    tk_messageBox -message "Error sourcing MimeTypesAndPlugins.tcl  $msg"  \
      -icon error -type ok
    exit
}    

set internalIPnum 127.0.0.1
set internalIPname "localhost"

# Set our IP number temporarily.
set thisIPnum $internalIPnum 

# Beware! [info hostname] can be very slow on Macs first time it is called.
set ::SplashScreen::startMsg [::msgcat::mc splashhost]
set this(hostname) [info hostname]

# Try to get own ip number from a temporary server socket.
# This can be a bit complicated as different OS sometimes give 0.0.0.0 or
# 127.0.0.1 instead of the real number.

if {![catch {socket -server puts 0} s]} {
    set thisIPnum [lindex [fconfigure $s -sockname] 0]
    catch {close $s}
    Debug 2 "1st: thisIPnum=$thisIPnum"
}

# If localhost or zero, try once again with '-myaddr'. 
# My Linux box is not helped by this either!!!
if {[string equal $thisIPnum "0.0.0.0"] ||  \
  [string equal $thisIPnum "127.0.0.1"]} {
    if {![catch {socket -server xxx -myaddr $this(hostname) 0} s]} {
	set thisIPnum [lindex [fconfigure $s -sockname] 0]
	catch {close $s}
	Debug 2 "2nd: thisIPnum=$thisIPnum"
    }
}
set this(ipnum) $thisIPnum

set ::SplashScreen::startMsg [::msgcat::mc splashinit]

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
    set this(username) {Unknown}
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

set ::SplashScreen::startMsg [::msgcat::mc splashprefs]

# Set defaults in the option database for widget classes.
::PreferencesUtils::SetWidgetDefaultOptions

# Manage the user preferences. Start by reading the preferences file.
::PreferencesUtils::PreferencesInit

# Set the user preferences from the preferences file if they are there,
# else take the hardcoded defaults.
::PreferencesUtils::SetUserPreferences

# Parse any command line options.
if {$argc > 0} {
    ::PreferencesUtils::ParseCommandLineOptions $argc $argv
}

# Goes through all the logic of verifying the 'mimeTypeDoWhat' 
# and the actual packages available on our system.
VerifyPackagesForMimeTypes

# Init the file cache settings.
::FileCache::SetBasedir $this(path)
::FileCache::SetBestBefore $prefs(checkCache) $prefs(incomingFilePath)

#--- User Interface ------------------------------------------------------------

# Various initializations for canvas stuff and UI.
::CanvasUtils::Init
::UI::Init
::UI::InitMenuDefs

# Create the mapping between Html sizes and font point sizes dynamically.
::CanvasUtils::CreateFontSizeMapping

# Make the actual whiteboard with canvas, tool buttons etc...
# Jabber has the roster window as "main" window.
if {![string equal $prefs(protocol) "jabber"]} {
    ::UI::BuildMain . -serverentrystate disabled
}
if {$prefs(firstLaunch) && !$prefs(stripJabber)} {
    wm withdraw .
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

# At this point we should be finished with the launch and delete the splash 
# screen.
set ::SplashScreen::startMsg {}
after 500 {catch {destroy $wDlgs(splash)}}

# Do we need all the jabber stuff? Is this the right place? Need it for setup!
if {!$prefs(stripJabber)} {
    ::Jabber::Init
    after 1200 {::Sounds::Init}
} else {
    
    # The most convinient solution is to create the namespaces at least.
    namespace eval ::Jabber:: {}
}

# Setup assistant. Must be called after initing the jabber stuff.
if {$displaySetup} {
    package require SetupAss

    catch {destroy $wDlgs(splash)}
    update
    ::SetupAss::SetupAss .setupass
    ::UI::CenterWindow .setupass
    raise .setupass
    tkwait window .setupass
}

# Is it the first time it is launched, then show the welcome canvas.
if {$prefs(firstLaunch)} {
    if {[wm state .] != "normal"} {
	if {[string equal $prefs(protocol) "jabber"]} {
	    ::UI::BuildMain . -serverentrystate disabled -sendcheckstate disabled
	} else {    
	    ::UI::BuildMain . -serverentrystate disabled
	}
    }
    ::CanvasFile::DoOpenCanvasFile . $prefs(welcomeFile)
    raise .
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
      ::TinyHttpd::StartHttpServer $prefs(httpdPort) $prefs(httpdBaseDir)} msg]} {
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

#-------------------------------------------------------------------------------
