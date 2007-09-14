#  PrefHelpers.tcl ---
#  
#       This file is part of The Coccinella application. 
#       It implements helpers prefs dialogs and panel.
#      
#  Copyright (c) 2007  Mats Bengtsson
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
# $Id: PrefHelpers.tcl,v 1.5 2007-09-14 14:16:16 matben Exp $
 
package provide PrefHelpers 1.0

namespace eval ::PrefHelpers:: {
    
    # Had to do it early since plugins depends on us.
    ::hooks::register earlyInitHook          ::PrefHelpers::InitPrefsHook

    # Unix only. Not MacOSX.
    if {$::this(platform) eq "unix"} {
	::hooks::register prefsBuildHook         ::PrefHelpers::BuildPrefsHook
	::hooks::register prefsSaveHook          ::PrefHelpers::SavePrefsHook
	::hooks::register prefsCancelHook        ::PrefHelpers::CancelPrefsHook
	::hooks::register prefsUserDefaultsHook  ::PrefHelpers::UserDefaultsHook
    }
}

proc ::PrefHelpers::InitPrefsHook { } {
    global  prefs this
	
    # Note that thes are execution paths from 'auto_execok'. Not names.
    set prefs(mailClient) ""
    set prefs(webBrowser) ""

    switch -- $this(platform) {
	unix {
	    if {[info exists ::env(BROWSER)]} {
		if {[llength [auto_execok $::env(BROWSER)]] > 0} {
		    set prefs(webBrowser) $::env(BROWSER)
		}
	    }
	}
	macosx {
	    # Not used. The systems 'open' command takes care of this.
	    set prefs(webBrowser) {Safari}
	}
	windows {	    
	    # Not used anymore. Uses the registry instead.
	    set prefs(webBrowser) {C:/Program/Internet Explorer/IEXPLORE.EXE}
	}
    }

    ::PrefUtils::Add [list  \
      [list prefs(webBrowser)    prefs_webBrowser    $prefs(webBrowser)]   \
      [list prefs(mailClient)    prefs_mailClient    $prefs(mailClient)]   \
      ]    
}

proc ::PrefHelpers::BuildPrefsHook {wtree nbframe} {
    
    if {![::Preferences::HaveTableItem General]} {
	::Preferences::NewTableItem {General} [mc General]
    }
    ::Preferences::NewTableItem {General Helpers} [mc "Default Applications"]
    set wpage [$nbframe page {Helpers}]
    BuildPage $wpage
}

proc ::PrefHelpers::BuildPage {wpage} {
    global  prefs
    variable tmp
    
    set tmp(webBrowser) [::Utils::UnixGetWebBrowser]
    set tmp(mailClient) [::Utils::UnixGetEmailClient]

    set browsers [::Utils::UnixGetAllWebBrowsers]
    set mailapps [::Utils::UnixGetAllEmailClients]
    set menuBrowsers [list]
    foreach path $browsers {
	set name [string totitle [lindex [file split $path] end]]
	lappend menuBrowsers [list $name -value $path]
    }
    set menuMail [list]
    foreach path $mailapps {
	set name [string totitle [lindex [file split $path] end]]
	lappend menuMail [list $name -value $path]
    }

    set anchor [option get . dialogAnchor {}]
    set padding [option get . notebookPageSmallPadding {}]

    set wc $wpage.c
    ttk::frame $wc -padding $padding
    pack $wc -side top -anchor $anchor

    ttk::label $wc.l -text [mc "Default Applications"]
    ttk::separator $wc.s -orient horizontal
    ttk::frame $wc.f -padding {20 4 0 0}
    
    grid  $wc.l  $wc.s
    grid  $wc.f  -      -sticky ew
    grid configure $wc.s -sticky ew
    grid columnconfigure $wc 1 -weight 1
    
    set f $wc.f
    ttk::label $f.lbrowser -text "[mc Browser]:"
    ui::optionmenu $f.mbrowser -menulist $menuBrowsers \
      -variable [namespace current]::tmp(webBrowser)
    ttk::label $f.lmail -text "[mc {Email client}]:"
    ui::optionmenu $f.mmail -menulist $menuMail \
      -variable [namespace current]::tmp(mailClient)
    
    set maxw [max [$f.mbrowser maxwidth] [$f.mmail maxwidth]]

    grid  $f.lbrowser  $f.mbrowser  -padx 2 -pady 2 -sticky e
    grid  $f.lmail     $f.mmail     -padx 2 -pady 2 -sticky e
    grid $f.lbrowser $f.lmail -sticky e
    grid $f.mbrowser $f.mmail -sticky ew
    grid columnconfigure $f 1 -minsize [expr {$maxw + 10}]
   
    return $wpage
}

proc ::PrefHelpers::SavePrefsHook {} {
    global  prefs
    variable tmp
    
    foreach name [array names tmp] {
	set prefs($name) $tmp($name)
    }
}

proc ::PrefHelpers::CancelPrefsHook {} {
    global  prefs
    variable tmp
    
    foreach name [array names tmp] {
	if {$tmp($name) ne $prefs($name)} {
	    ::Preferences::HasChanged
	}
    }
}

proc ::PrefHelpers::UserDefaultsHook {} {
    global  prefs
    variable tmp
    
    foreach name [array names tmp] {
	set tmp($name) $prefs($name)
    }
}

