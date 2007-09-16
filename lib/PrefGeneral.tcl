#  PrefGeneral.tcl ---
#  
#       This file is part of The Coccinella application. 
#       It implements a prefs dialog. So far very limited.
#      
#  Copyright (c) 2006  Mats Bengtsson
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
# $Id: PrefGeneral.tcl,v 1.10 2007-09-16 12:00:28 matben Exp $
 
package provide PrefGeneral 1.0

namespace eval ::PrefGeneral:: {

    ::hooks::register prefsInitHook          ::PrefGeneral::InitPrefsHook
    ::hooks::register prefsBuildHook         ::PrefGeneral::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::PrefGeneral::SavePrefsHook
    ::hooks::register prefsCancelHook        ::PrefGeneral::CancelPrefsHook
}

proc ::PrefGeneral::InitPrefsHook {} {
    global  prefs
    
    # These are actually never used from the prefs file.
    set prefs(prefsSameDrive) 0
    set prefs(prefsSameDir)   0
}

proc ::PrefGeneral::BuildPrefsHook {wtree nbframe} {
    global  this prefs config
    variable tmpPrefs
    
    # Seems to be duplicated.
    set prefs(prefsSameDir) $this(prefsPathAppDir)
    
    set tmpPrefs(prefsSameDrive) $prefs(prefsSameDrive)
    set tmpPrefs(prefsSameDir)   $prefs(prefsSameDir)
    
    set wpage [$nbframe page {General}]
    set wc $wpage.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]
    
    # Settings drive.
    set wd $wc.d
    ttk::frame $wc.d
    ttk::label $wd.l -text [mc Settings]
    ttk::separator $wd.s -orient horizontal
    if {$config(prefs,sameDrive)} {
	ttk::checkbutton $wd.c -text [mc prefdrivesame2] \
	  -variable [namespace current]::tmpPrefs(prefsSameDrive)
    } elseif {$config(prefs,sameDir)} {
	ttk::checkbutton $wd.c -text [mc prefdirsame] \
	  -variable [namespace current]::tmpPrefs(prefsSameDir)
    }
    
    grid  $wd.l  $wd.s  -sticky w
    grid  $wd.c  -      -sticky w -pady 1
    grid $wd.s -sticky ew
    grid columnconfigure $wd 1 -weight 1
    
    pack $wd -side top -fill x -anchor w
    
    if {$config(prefs,sameDrive)} {

	# If the app not lives on another drive.
	if { ![::Init::IsAppOnRemovableDrive] } {
	    set prefs(prefsSameDrive) 0
	    $wd.c state {disabled}
	}
	
	# Don't know how to detect removable drives here.
	if { $this(platform) eq "unix" } {
	    set prefs(prefsSameDrive) 0
	    $wd.c state {disabled}
	}
    } elseif {$config(prefs,sameDir)} {

	# Must verify that application folder writable.
	set psplit [file split $this(appPath)]
	if {![file writable [eval file join [lrange $psplit 0 end-1]]]} {
	    set prefs(prefsSameDir) 0
	    $wd.c state {disabled}
	}
    }
        
    # Language.
    set wl $wc.l
    ttk::frame $wc.l -padding {0 6 0 0}
    ttk::label $wl.l -text [mc Language]
    ttk::separator $wl.s -orient horizontal
    ttk::label $wl.lr -text [mc "Requires a restart of" $prefs(appName)]
    ::Utils::LanguageMenubutton $wl.mb [namespace current]::tmpPrefs(locale)

    grid  $wl.l   $wl.s  -sticky w
    grid  $wl.lr   -      -sticky w -pady 1
    grid  $wl.mb  -      -sticky w
    grid $wl.s -sticky ew    
    grid columnconfigure $wl 1 -weight 1

    pack $wl -side top -fill x -anchor w

    ::balloonhelp::balloonforwindow $wl.mb \
      [mc "Requires a restart of" $prefs(appName)]

    bind $wpage <Destroy> {+::PrefGeneral::Free }
}

proc ::PrefGeneral::SavePrefsHook {} {
    global prefs this config
    variable tmpPrefs
    
    if {$config(prefs,sameDrive)} {
	if {$tmpPrefs(prefsSameDrive) && !$prefs(prefsSameDrive)} {
	    set ans [tk_messageBox -icon question -type yesno  \
	      -message [mc prefdriwsame]]
	    if {$ans eq "yes"} {
		set prefs(prefsSameDrive) 1
		
		# Need to change all paths that depend on this(prefsPath) and make
		# sure dirs are there (removable drive).
		::Init::SetPrefsPathToRemovable
		::hooks::run prefsFilePathChangedHook
	    }
	} elseif {!$tmpPrefs(prefsSameDrive) && $prefs(prefsSameDrive)} {
	    
	    # Remove prefs file so we wont detect it next time we are launched.
	    set prefFile [file join [::Init::GetAppDrivePrefsPath] $this(prefsName)]
	    if {[file exists $prefFile]} {
		set ans [tk_messageBox -icon question -type yesno  \
		  -message [mc prefdriwdef2 $prefFile $prefs(appName)]]
		if {$ans eq "yes"} {
		    file delete $prefFile
		}	
	    }
	    ::Init::SetPrefsPathToDefault
	    set prefs(prefsSameDrive) 0
	    ::hooks::run prefsFilePathChangedHook
	}
    } elseif {$config(prefs,sameDir)} {
	if {$tmpPrefs(prefsSameDir) && !$prefs(prefsSameDir)} {
	    set prefs(prefsSameDir) 1
	    set this(prefsPathAppDir) 1
	    
	    # Need to change all paths that depend on this(prefsPath) and make
	    # sure dirs are there.
	    ::Init::SetPrefsPathToAppDir
	    ::hooks::run prefsFilePathChangedHook
	} elseif {!$tmpPrefs(prefsSameDir) && $prefs(prefsSameDir)} {

	    # Remove prefs file so we wont detect it next time we are launched.
	    set prefFile [file join [::Init::GetAppDirPrefsPath] $this(prefsName)]
	    if {[file exists $prefFile]} {
		set ans [tk_messageBox -icon question -type yesno  \
		  -message [mc prefdriwdef2 $prefFile $prefs(appName)]]
		if {$ans eq "yes"} {
		    file delete $prefFile
		}	
	    }
	    ::Init::SetPrefsPathToDefault
	    set prefs(prefsSameDir) 0
	    set this(prefsPathAppDir) 0
	    ::hooks::run prefsFilePathChangedHook
	}	
    }
    
    # Load any new message catalog.
    set prefs(messageLocale) $tmpPrefs(locale)
    ::msgcat::mclocale $tmpPrefs(locale)
    ::msgcat::mcload $this(msgcatPath)
}

proc ::PrefGeneral::CancelPrefsHook {} {
    global prefs
    variable tmpPrefs

    # @@@
}

proc ::PrefGeneral::Free {} {
    variable tmpPrefs
    
    unset -nocomplain tmpPrefs
}
