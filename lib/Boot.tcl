#  Boot.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It sets up the global 'this' array for useful things.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: Boot.tcl,v 1.1 2004-11-23 14:47:56 matben Exp $

namespace eval ::Boot:: { }

proc ::Boot::SetThis {thisScript} {
    global  this auto_path tcl_platform
    
    # Path where preferences etc are stored.
    switch -- $this(platform) {
	macintosh {
	    if {[info exists ::env(PREF_FOLDER)]} {
		set this(prefsPath) [file join $::env(PREF_FOLDER) Coccinella]
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
	    if {[info exists ::env(USERPROFILE)]} {
		set winPrefsDir $::env(USERPROFILE)
	    } elseif {[info exists ::env(APPDATA)]} {
		set winPrefsDir $::env(APPDATA)
	    } elseif {[info exists ::env(HOME)]} {
		set winPrefsDir $::env(HOME)
	    } elseif {[info exists ::env(HOMEDRIVE)]} {
		set winPrefsDir $::env(HOMEDRIVE)
	    } else {
		set vols [lsort [file volumes]]
		set vols [lsearch -all -inline -glob -not $vols A:*]
		set vols [lsearch -all -inline -glob -not $vols B:*]
		set winPrefsDir [lindex $vols 0]
	    }
	    set this(prefsPath) [file join $winPrefsDir Coccinella]
	}
    }
    
    # Collect paths in 'this' array.
    set this(script)            $thisScript
    set this(path)              [file dirname $thisScript]
    set this(appPath)           $this(path)
    if {[info exists starkit::topdir]} {
	set this(appPath) [file dirname [info nameofexecutable]]
    }
    set this(imagePath)         [file join $this(path) images]
    set this(altImagePath)      [file join $this(prefsPath) images]
    set this(resourcePath)      [file join $this(path) resources]
    set this(altResourcePath)   [file join $this(prefsPath) resources]
    set this(postPrefsPath)     [file join $this(resourcePath) post]
    set this(postPrefsFile)     [file join $this(postPrefsPath) prefs]
    set this(soundsPath)        [file join $this(path) sounds]
    set this(altSoundsPath)     [file join $this(prefsPath) sounds]  
    set this(basThemePrefsFile) [file join $this(resourcePath) post theme.rdb]
    set this(themePrefsFile)    [file join $this(prefsPath) theme]
    set this(msgcatPath)        [file join $this(path) msgs]
    set this(msgcatPostPath)    [file join $this(path) msgs post]
    set this(docsPath)          [file join $this(path) docs]
    set this(itemPath)          [file join $this(path) items]
    set this(altItemPath)       [file join $this(prefsPath) items]
    set this(pluginsPath)       [file join $this(path) plugins]
    set this(appletsPath)       [file join $this(path) plugins applets]
    set this(componentPath)     [file join $this(path) components]
    set this(emoticonsPath)     [file join $this(path) iconsets emoticons]
    set this(altEmoticonsPath)  [file join $this(prefsPath) iconsets emoticons]
    set this(rosticonsPath)     [file join $this(path) iconsets roster]
    set this(altRosticonsPath)  [file join $this(prefsPath) iconsets roster]
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
    if {[info exists ::env(TMP)] && [file exists $::env(TMP)]} {
	set this(tmpPath) [file join $::env(TMP) tmpcoccinella]
    } elseif {[info exists ::env(TEMP)] && [file exists $::env(TEMP)]} {
	set this(tmpPath) [file join $::env(TEMP) tmpcoccinella]
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
}

proc ::Boot::SetAutoPath { } {
    global  auto_path this prefs
    
    # Add our lib and whiteboard directory to our search path.
    lappend auto_path [file join $this(path) lib]
    lappend auto_path [file join $this(path) whiteboard]

    # Add the contrib directory which has things like widgets etc. 
    lappend auto_path [file join $this(path) contrib]

    set prefs(stripJabber) 0

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
}

proc ::Boot::InitMsgcat { } {
    global  prefs this
    
    package require msgcat

    # The message catalog for language customization. Use 'en' as fallback.
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

    # Test here if you want a particular message catalog (en, nl, de, fr, sv,...).
    #::msgcat::mclocale en
    ::msgcat::mcload $this(msgcatPath)

    # This is a method to override default messages with custom ones for each
    # language.
    if {[file isdirectory $this(msgcatPostPath)]} {
	::msgcat::mcload $this(msgcatPostPath)
    }
    uplevel #0 namespace import ::msgcat::mc
}

#-------------------------------------------------------------------------------
