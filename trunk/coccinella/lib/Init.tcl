#  Init.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It sets up the global 'this' array for useful things.
#      
#  Copyright (c) 2004-2006  Mats Bengtsson
#  
# $Id: Init.tcl,v 1.56 2006-12-12 15:18:00 matben Exp $

namespace eval ::Init:: { }

proc ::Init::SetThis {mainScript} {
    global  this auto_path tcl_platform prefs
    
    # If we store the prefs file on a removable drive, use this folder name:
    #    F:\CoccinellaPrefs  etc.  
    set this(prefsDriverDir) "CoccinellaPrefs"
    
    # Collect paths in 'this' array.
    set path                    [file dirname $mainScript]
    set this(path)              $path
    set this(script)            $mainScript
    
    set this(images)            images
    set this(resources)         resources
    set this(componentPath)     [file join $path components]
    set this(docsPath)          [file join $path docs]
    set this(emoticonsPath)     [file join $path iconsets emoticons]
    set this(rosticonsPath)     [file join $path iconsets roster]
    set this(serviconsPath)     [file join $path iconsets service]
    set this(imagePath)         [file join $path images]
    set this(avatarPath)        [file join $path images avatar]
    set this(itemPath)          [file join $path items]
    set this(msgcatPath)        [file join $path msgs]
    set this(msgcatPostPath)    [file join $path msgs post]
    set this(pluginsPath)       [file join $path plugins]
    set this(appletsPath)       [file join $path plugins applets]
    set this(resourcePath)      [file join $path resources]
    set this(postPrefsPath)     [file join $path resources post]
    set this(postPrefsFile)     [file join $path resources post prefs.rdb]
    set this(basThemePrefsFile) [file join $path resources post theme.rdb]
    set this(prePrefsPath)      [file join $path resources pre]
    set this(prePrefsFile)      [file join $path resources pre prefs.rdb]
    set this(themesPath)        [file join $path themes]
    set this(soundsPath)        [file join $path sounds]
    set this(httpdRootPath)     $path
    set this(appPath)           $path
    if {[info exists starkit::topdir]} {
	set this(appPath) [file dirname [info nameofexecutable]]
    }
    
    # Path where preferences etc are stored.
    set this(prefsDefPath) [GetDefaultPrefsPath]
    set this(prefsPath)    $this(prefsDefPath)

    switch -- $this(platform) {
	macosx {
	    set this(prefsName) "Whiteboard Prefs"
	}
	unix {
	    set this(prefsName) "whiteboard"
	}
	windows {
	    set this(prefsName) "WBPREFS.TXT"
	}
    }

    # Handle the situation where the app lives on a removable drive (USB stick).
    # If it lives on a removable drive, and if we find an existing prefs 
    # file there, then we should relate all prefs related paths to it.
    set this(prefsPathRemovable) 0
    if {[IsAppOnRemovableDrive]} {
	set prefsPathDrive [GetAppDrivePrefsPath]
	set prefFile [file join $prefsPathDrive $this(prefsName)]
	if {[file exists $prefFile] && [file writable $prefFile]} {
	    set this(prefsPathRemovable) 1
	    set this(prefsPath) $prefsPathDrive
	}    
    }
    
    # Sets all paths that are dependent on this(prefsPath).
    SetPrefsPaths
    
    # Make sure all dirs exist.
    MakePrefsDirs

    # Need to rework this...
    if {0 && [info exists starkit::topdir]} {
	set this(httpdRootPath) $starkit::topdir
	set this(httpdRelPath)  \
	  [file join $::starkit::topdir lib app-Coccinella httpd]
    }
    set this(internalIPnum)  127.0.0.1
    set this(internalIPname) "localhost"
    
    # Set our IP number temporarily.
    set this(ipnum) $this(internalIPnum) 
    
    # Need a tmp directory, typically in a StarKit when QuickTime movies are opened.
    set MAX_INT 0x7FFFFFFF
    set hex [format {%x} [expr int($MAX_INT*rand())]]
    set tail coccinella[pid]-$hex
    set this(tmpPath) [file join [TempDir] $tail]
    if {![file isdirectory $this(tmpPath)]} {
	file mkdir $this(tmpPath)
    }
    
    # This is where the "Batteries Included" binaries go. Empty if non.
    if {$this(platform) eq "unix"} {
	set machine $tcl_platform(machine)
	if {[regexp {[2-9]86} $tcl_platform(machine)]} {
	    set machine "i686"
	} elseif {$tcl_platform(machine) eq "x86_64"} {
	    # x86_64
	    set machine "i686"
	}
	set machineSpecPath [file join $tcl_platform(os) $machine]
    } else {
	set machineSpecPath $tcl_platform(machine)
    }
    
    # Make cvs happy.
    regsub -all " " $machineSpecPath "" machineSpecPath
    
    set this(binLibPath) [file join $path bin library]
    set this(binPath)    [file join $path bin $this(platform) $machineSpecPath]
    if {[file exists $this(binPath)]} {
	set auto_path [concat [list $this(binPath)] $auto_path]
	set auto_path [concat [list $this(binLibPath)] $auto_path]
    } else {
	set this(binPath) {}
    }
    
    switch -- $this(platform) {
	macosx {
	    set this(modkey) Command
	}
	default {
	    set this(modkey) Control
	}
    }
    
    # Find user name.
    set this(username) [GetUserName]
}

# Init::GetDefaultPrefsPath --
# 
#       Finds the actual file path to our default prefs dir.

proc ::Init::GetDefaultPrefsPath { } {
    global  this
    
    # Path where preferences etc are stored.
    switch -- $this(platform) {
	macosx {
	    set prefsPath  \
	      [file join [file nativename ~/Library/Preferences] Coccinella]
	}    
	unix {
	    set prefsPath [file nativename ~/.coccinella]
	}
	windows {
	    foreach key {USERPROFILE APPDATA HOME HOMEPATH \
	      ALLUSERSPROFILE CommonProgramFiles HOMEDRIVE} {
		if {[info exists ::env($key)] && [file writable $::env($key)]} {
		    set winPrefsDir $::env($key)
		    break
		}
	    }
	    if {![info exists winPrefsDir]} {
		set vols [lsort [file volumes]]
		set vols [lsearch -all -inline -glob -not $vols A:*]
		set vols [lsearch -all -inline -glob -not $vols B:*]
		
		# If none of the above are writable this is unlikely.
		if {[file writable [lindex $vols 0]]} {
		    set winPrefsDir [lindex $vols 0]
		} else {
		    if {[info exists starkit::topdir]} {
			set dir [file dirname [info nameofexecutable]]
		    } else {
			set dir [file dirname [file dirname $this(script)]]
		    }
		    if {[file writable $dir]} {
			set winPrefsDir $dir
		    }
		}
	    }
	    if {[info exists winPrefsDir]} {
		set prefsPath [file join $winPrefsDir Coccinella]
	    } else {
		set prefsPath ""
	    }
	}
    }
    return $prefsPath
}

proc ::Init::IsAppOnRemovableDrive { } {
    global  this
    
    set ans 0

    if {$this(platform) eq "windows"} {
	set prefsDrive [string tolower [string index $this(prefsDefPath) 0]]
	set appDrive   [string tolower [string index $this(appPath) 0]]
	if {$prefsDrive ne $appDrive} {
	    set ans 1
	}
    } elseif {$this(platform) eq "macosx"} {
	
	# Try to see if different drives. Ad hoc.
	set lprefs [file split $this(prefsDefPath)]
	set lapp   [file split $this(appPath)]
	set prefs1 [lindex $lprefs 1]
	set app1   [lindex $lapp 1]
	if {($app1 ne $prefs1) && ($app1 eq "Volumes")} {
	    set ans 1
	}
    } elseif {$this(platform) eq "unix"} {
	# @@@ Don't know how to detect drives on unix in general.
    } 
    return $ans
}

# Init::GetAppDrivePrefsPath --
#
#       Gets the prefs path for nonstandard drive.
#       It doesn't check for its existence.
#       You MUST have 'IsAppOnRemovableDrive' for this to make sense.

proc ::Init::GetAppDrivePrefsPath { } {
    global  this
    
    set lapp   [file split $this(appPath)]

    if {$this(platform) eq "windows"} {
	set path [file join [lindex $lapp 0] $this(prefsDriverDir)]
    } elseif {$this(platform) eq "macosx"} {
	set drive [lindex $lapp 2]
	set path [file join [lindex $lapp 0] [lindex $lapp 1] [lindex $lapp 2]  \
	  $this(prefsDriverDir)]
    } elseif {$this(platform) eq "unix"} {
	# @@@ Don't know how to detect drives on unix in general.
	set path ""
    } 
    return $path
}

# Init::SetPrefsPaths --
# 
#       Is supposed to set all standard paths that are dependent on 
#       this(prefsPath).

proc ::Init::SetPrefsPaths { } {
    global  this
    
    set path $this(prefsPath)
    
    set this(altSoundsPath)     [file join $path sounds]  
    set this(themePrefsFile)    [file join $path theme]
    set this(altItemPath)       [file join $path items]
    set this(altEmoticonsPath)  [file join $path iconsets emoticons]
    set this(altRosticonsPath)  [file join $path iconsets roster]
    set this(altServiconsPath)  [file join $path iconsets service]
    set this(inboxFile)         [file join $path Inbox.tcl]
    set this(notesFile)         [file join $path Notes.tcl]
    set this(prefsAvatarPath)   [file join $path avatar]
    set this(myAvatarPath)      [file join $path avatar my]
    set this(cacheAvatarPath)   [file join $path avatar cache]
    set this(recentAvatarPath)  [file join $path avatar recent]
    set this(altThemesPath)     [file join $path themes]

    set pname $this(prefsName)

    switch -- $this(platform) {
	unix {
	    
	    # On a central installation need to have local dirs for write access.
	    set this(userPrefsFilePath) [file nativename [file join $path $pname]]
	    set this(oldPrefsFilePath) [file nativename ~/.whiteboard]
	    set this(inboxCanvasPath) [file nativename [file join $path canvases]]
	    set this(historyPath) [file nativename [file join $path history]]
	}
	macosx {
	    set this(userPrefsFilePath) [file join $path $pname]
	    set this(oldPrefsFilePath) $this(userPrefsFilePath)
	    set this(inboxCanvasPath) [file join $path Canvases]
	    set this(historyPath) [file join $path History]
	}
	windows {
	    set this(userPrefsFilePath) [file join $path $pname]
	    set this(oldPrefsFilePath) [file join C: "WBPREFS.TXT"]
	    set this(inboxCanvasPath) [file join $path Canvases]
	    set this(historyPath) [file join $path History]
	}
    }
}

# Init::SetPrefsPathToDefault, SetPrefsPathToRemovable --
# 
#       Helpers to allow switching prefs location.

proc ::Init::SetPrefsPathToDefault { } {
    global  this
    
    set this(prefsPath) [GetDefaultPrefsPath]
    set this(prefsPathRemovable) 0

    ::Init::SetPrefsPaths
    ::Init::MakePrefsDirs
}

proc ::Init::SetPrefsPathToRemovable { } {
    global  this
    
    set this(prefsPath) [GetAppDrivePrefsPath]
    set this(prefsPathRemovable) 1
    
    ::Init::SetPrefsPaths
    ::Init::MakePrefsDirs
}

proc ::Init::GetUserName { } {
    global  this
      
    # Find user name.
    if {[info exists ::env(USER)]} {
	set username $::env(USER)
    } elseif {[info exists ::env(LOGIN)]} {
	set username $::env(LOGIN)
    } elseif {[info exists ::env(USERNAME)]} {
	set username $::env(USERNAME)
    } elseif {[llength [set this(hostname) [info hostname]]]} {
	set username $this(hostname)
    } else {
	set username "Unknown"
    }
    return $username
}

proc ::Init::SetThisVersion { } {
    global  this
    
    # The application major and minor version numbers; should only be written to
    # default file, never read.
    set this(vers,major)    0
    set this(vers,minor)   95
    set this(vers,release) 16
    set this(vers,full) $this(vers,major).$this(vers,minor).$this(vers,release)

    # This is used only to track upgrades.
    set this(vers,previous) $this(vers,full)
}

proc ::Init::SetThisEmbedded { } {
    global  this
    
    # We may be embedded in another application, say an ActiveX component.
    # The TclControl ActiveX package defines the browser namespace.
    # So does the TclPlugin, at least version 2.0:
    # http://www.tcl.tk/man/plugin2.0/pluginDoc/plugin.htm
    if {[namespace exists ::browser]} {
	set this(embedded) 1
    } else {
	set this(embedded) 0
    }
}

proc ::Init::MakePrefsDirs { } {
    global  this tcl_platform
    
    foreach name {
	prefsPath
	inboxCanvasPath
	historyPath
	prefsAvatarPath
	myAvatarPath
	cacheAvatarPath
	recentAvatarPath
	altItemPath
	altEmoticonsPath
	altRosticonsPath
	altServiconsPath
	altThemesPath
    } {
	if {[file isfile $this($name)]} {
	    file delete -force $this($name)
	}
	if {![file isdirectory $this($name)]} {
	    file mkdir $this($name)
	}
    }	
    
    # Privacy!
    switch -- $tcl_platform(platform) {
	unix {
	    # Make sure other have absolutely no access to our prefs.
	    file attributes $this(prefsPath) -permissions o-rwx
	}
    }
}

proc ::Init::SetAutoPath { } {
    global  auto_path this prefs
    
    # Add our lib and whiteboard directory to our search path.
    lappend auto_path [file join $this(path) lib]
    lappend auto_path [file join $this(path) whiteboard]

    # Add the contrib directory which has things like widgets etc. 
    lappend auto_path [file join $this(path) contrib]

    # Add the jabberlib directory which provides jabber support. 
    lappend auto_path [file join $this(path) jabberlib]
    
    # Add the jabber directory which provides client specific jabber stuffs. 
    lappend auto_path [file join $this(path) jabber]
    
    # Add the components directory since we may have packages used by components.
    lappend auto_path [file join $this(path) components]
    
    # Do we need TclXML. This is in its own app specific dir.
    # Perhaps there can be a conflict if there is already an TclXML
    # package installed in the standard 'auto_path'. Be sure to have it first!
    set auto_path [concat [list [file join $this(path) TclXML]] $auto_path]
}

proc ::Init::Msgcat { } {
    global  prefs this
    
    package require msgcat

    # The message catalog for language customization. Use 'en' as fallback.
    if {$prefs(messageLocale) eq ""} {
	if {[string match -nocase "c" [::msgcat::mclocale]]} {
	    ::msgcat::mclocale en
	}
	set locale [::msgcat::mclocale]
	
	# Avoid the mac encoding problems by rejecting certain locales.
	if {[tk windowingsystem] eq "aqua"} {
	    if {[regexp {ru} $locale]} {
		set locale en
		::msgcat::mclocale en
	    }
	}
    } else {
	set locale $prefs(messageLocale)
	::msgcat::mclocale $locale
    }

    set this(systemLocale) $locale
    set lang [lindex [split [file rootname $locale] _] 0]
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
    
    # Seems to be needed for tclkits?
    if {$lang eq "ru"} {
	switch -- [tk windowingsystem] {
	    win32 {
		catch {encoding system cp1251}
	    }
	    x11 {
		catch {encoding system koi8-r}
	    }
	}
    }
    
    # Test here if you want a particular message catalog (en, nl, de, fr, sv,...).
    #::msgcat::mclocale pl
    uplevel #0 [list ::msgcat::mcload $this(msgcatPath)]

    # This is a method to override default messages with custom ones for each
    # language.
    if {[file isdirectory $this(msgcatPostPath)]} {
	uplevel #0 [list ::msgcat::mcload $this(msgcatPostPath)]
    }
    uplevel #0 namespace import ::msgcat::mc
}

# From tcllib (fileutil) + modifications:

# ::Init::TempDir --
#
#	Return the correct directory to use for temporary files.
#	Python attempts this sequence, which seems logical:
#
#       1. The directory named by the `TMPDIR' environment variable.
#
#       2. The directory named by the `TEMP' environment variable.
#
#       3. The directory named by the `TMP' environment variable.
#
#       4. A platform-specific location:
#            * On Macintosh, the `Temporary Items' folder.
#
#            * On Windows, the directories `C:\\TEMP', `C:\\TMP',
#              `\\TEMP', and `\\TMP', in that order.
#
#            * On all other platforms, the directories `/tmp',
#              `/var/tmp', and `/usr/tmp', in that order.
#
#        5. As a last resort, the current working directory.
#
# Arguments:
#	None.
#
# Side Effects:
#	None.
#
# Results:
#	The directory for temporary files.

proc ::Init::TempDir {} {
    global  tcl_platform env
    
    set attempdirs [list]

    foreach tmp {TMPDIR TEMP TMP} {
	if {[info exists env($tmp)]} {
	    lappend attempdirs $env($tmp)
	}
    }

    switch $tcl_platform(platform) {
	windows {
	    lappend attempdirs "C:\\TEMP" "C:\\TMP" "\\TEMP" "\\TMP"
	}
	default {
	    lappend attempdirs [file join / tmp] \
		[file join / var tmp] [file join / usr tmp]
	}
    }

    foreach tmp $attempdirs {
	if {[file isdirectory $tmp] && [file writable $tmp]} {
	    return [file normalize $tmp]
	}
    }

    # If nothing else worked...
    return [file normalize [pwd]]
}

proc ::Init::LoadPackages { } {
    global  this auto_path
    
    # Take precautions and load only our own tile, treectrl.
    # Side effects??? It fools statically linked tile in tclkits
    #set autoPath $auto_path
    #set auto_path [list $this(binLibPath) $this(binPath)]
        
    # tile may be statically linked (Windows).
    if {[lsearch -exact [info loaded] {{} tile}] >= 0} {
	package require tile 0.7
    } else {
    
	# We must be sure script libraries for tile come from us (tcl_findLibrary).
	::Splash::SetMsg "[mc splashlook] tile..."
	namespace eval ::tile {}
	set ::tile::library [file join $this(binLibPath) tile]
	
	# tileqt has its own library support.
	if {[tk windowingsystem] eq "x11"} {
	    namespace eval ::tileqt {}
	    set ::tileqt::library [file join $this(binLibPath) tileqt]
	}

	if {[catch {uplevel #0 [list package require tile 0.7]} msg]} {
	    tk_messageBox -icon error \
	      -message "This application requires the tile package to work! $::errorInfo"
	    exit
	}
    }
    
    # treectrl is required.
    ::Splash::SetMsg "[mc splashlook] treectrl..."
    set ::treectrl_library [file join $this(binLibPath) treectrl]
    if {[catch {package require treectrl 2.1} msg]} {
	tk_messageBox -icon error \
	  -message "This application requires the treectrl widget to work! $::errorInfo"
	exit
    }
    
    #set auto_path $autoPath
    
    # tkpng is required for the gui.
    ::Splash::SetMsg "[mc splashlook] tkpng..."
    if {[catch {package require tkpng 0.7}]} {
	tk_messageBox -icon error \
	  -message "The tkpng package is required for the GUI"
	exit
    }
    set this(package,tkpng) 1
    
    # Other utility packages that can be platform specific.
    # The 'Thread' package requires that the Tcl core has been built with support.
    array set extraPacksArr {
	macosx      {Itcl Tclapplescript tls Thread MacCarbonPrint carbon}
	windows     {Itcl printer gdi tls Thread optcl tcom}
	unix        {Itcl tls Thread}
    }
    foreach {platform packList} [array get extraPacksArr] {
	foreach name $packList {
	    set this(package,$name) 0
	}
    }
    foreach name $extraPacksArr($this(platform)) {
	::Splash::SetMsg "[mc splashlook] $name..."
	if {![catch {package require $name} msg]} {
	    set this(package,$name) 1
	}
    }
    if {$this(package,Itcl)} {
	uplevel #0 {namespace import ::itcl::*}
    }
    if {!($this(package,printer) && $this(package,gdi))} {
	set this(package,printer) 0
    }

    # Not ready for this yet.
    set this(package,Thread) 0
}

# Init::Config --
# 
#       Sets any 'config' array entries.
#       The config array shall be used for hardcoded configuration settings
#       that can be overriden only at build time by adding a config.tcl file
#       in resources/. 
#       array set config {-junk "The Junk" ...}

proc ::Init::Config { } {
    global  this config
    
    set f [file join $this(resourcePath) config.tcl]
    if {[file exists $f]} {
	source $f
    }
}

proc ::Init::SetHostname { } {
    global  this
    
    set this(hostname) [info hostname]
}

#-------------------------------------------------------------------------------
