#  PrefGeneral.tcl ---
#  
#       This file is part of The Coccinella application. 
#       It implements a prefs dialog. So far very limited.
#      
#  Copyright (c) 2006  Mats Bengtsson
#  
# $Id: PrefGeneral.tcl,v 1.2 2006-04-17 13:23:38 matben Exp $
 
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
    
    # Settings drive.
    set wd $wc.d
    ttk::frame $wc.d
    ttk::label $wd.l -text [mc Settings]
    ttk::separator $wd.s -orient horizontal
    ttk::checkbutton $wd.c -text [mc prefdrivesame] \
      -variable [namespace current]::tmpPrefs(prefsSameDrive)
    
    grid  $wd.l  $wd.s  -sticky w
    grid  $wd.c  -      -sticky w -pady 1
    grid $wd.s -sticky ew
    grid columnconfigure $wd 1 -weight 1
    
    pack $wd -side top -fill x -anchor w
    
    # If the app not lives on another drive.
    set removable [::PrefUtils::IsAppOnRemovableDrive]
    if {!$removable} {
	set prefs(prefsSameDrive) 0
	$wd.c state {disabled}
    }
        
    # Language.
    set wl $wc.l
    ttk::frame $wc.l -padding {0 6 0 0}
    ttk::label $wl.l -text [mc Language]
    ttk::separator $wl.s -orient horizontal
    ttk::label $wl.m -style Small.TLabel \
      -wraplength 360 -justify left -text [mc sulang]
    ::Utils::LanguageMenubutton $wl.mb [namespace current]::tmpPrefs(locale)

    grid  $wl.l   $wl.s  -sticky w
    grid  $wl.m   -      -sticky w -pady 1
    grid  $wl.mb  -      -sticky w
    grid $wl.s -sticky ew    
    grid columnconfigure $wl 1 -weight 1

    pack $wl -side top -fill x -anchor w
    
    bind $wpage <Destroy> {+::PrefGeneral::Free }
}

proc ::PrefGeneral::SavePrefsHook {} {
    global prefs this
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
