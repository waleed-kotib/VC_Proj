#  PrefGeneral.tcl ---
#  
#       This file is part of The Coccinella application. 
#       It implements a prefs dialog. So far very limited.
#      
#  Copyright (c) 2006  Mats Bengtsson
#  
# $Id: PrefGeneral.tcl,v 1.1 2006-03-28 08:12:12 matben Exp $
 
package provide PrefGeneral 1.0

namespace eval ::PrefGeneral:: {

    ::hooks::register prefsInitHook          ::PrefGeneral::InitPrefsHook
    ::hooks::register prefsBuildHook         ::PrefGeneral::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::PrefGeneral::SavePrefsHook
    ::hooks::register prefsCancelHook        ::PrefGeneral::CancelPrefsHook
}

proc ::PrefGeneral::InitPrefsHook { } {
    global  prefs
    
    set prefs(prefsSameDrive) 0
    
    ::PrefUtils::Add [list  \
      [list prefs(prefsSameDrive)  prefs_prefsSameDrive  $prefs(prefsSameDrive)] \
      ]
}

proc ::PrefGeneral::BuildPrefsHook {wtree nbframe} {
    global prefs
    variable tmpPrefs
    
    set tmpPrefs(prefsSameDrive) $prefs(prefsSameDrive)
    
    set wpage [$nbframe page {General}]
    set wc $wpage.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]
    
    ttk::checkbutton $wc.cpre -text [mc prefdrivesame] \
      -variable [namespace current]::tmpPrefs(prefsSameDrive)
    
    grid  $wc.cpre  -sticky w -pady 1
    
    # If the app not lives on another drive.
    set removable [::PrefUtils::IsAppOnRemovableDrive]
    if {!$removable} {
	set prefs(prefsSameDrive) 0
	$wc.cpre state {disabled}
    }
    bind $wpage <Destroy> {+::PrefGeneral::Free }
}

proc ::PrefGeneral::SavePrefsHook {} {
    global prefs
    variable tmpPrefs
    
    set prefFile [::PrefUtils::GetAppDrivePrefsFile]

    if {$tmpPrefs(prefsSameDrive) && !$prefs(prefsSameDrive)} {
	set ans [tk_messageBox -icon question -type yesno  \
	  -message [mc prefdriwsame]]
	if {$ans eq "yes"} {
	    set prefs(prefsSameDrive) $tmpPrefs(prefsSameDrive)
	}
    } elseif {!$tmpPrefs(prefsSameDrive) && $prefs(prefsSameDrive)} {
	set ans [tk_messageBox -icon question -type yesno  \
	  -message [mc prefdriwdef $prefFile]]
	if {$ans eq "yes"} {
	    file delete $prefFile
	}	
	set prefs(prefsSameDrive) $tmpPrefs(prefsSameDrive)
    }
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
