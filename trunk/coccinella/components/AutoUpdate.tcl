#  AutoUpdate.tcl ---
#  
#      This file is part of The Coccinella application. It implements 
#      methods to query for new versions.
#
#  Copyright (c) 2003-2007  Mats Bengtsson
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
# $Id: AutoUpdate.tcl,v 1.20 2007-08-10 08:07:51 matben Exp $

package require tinydom
package require http 2.3

namespace eval ::AutoUpdate:: {
    
    # Allow the update url to be set via the option database.
    set url "http://coccinella.sourceforge.net/updates/update_en.xml"
    #set url "http://coccinella.sourceforge.net/updates/update_test.xml"

    set ::config(autoupdate,do)       1
    set ::config(autoupdate,url)      $url
    set ::config(autoupdate,interval) "1 day ago"

    variable newVersion 1.0
}

proc ::AutoUpdate::Init {} {

    ::Debug 2 "::AutoUpdate::Init"
        
    ::hooks::register prefsInitHook   ::AutoUpdate::InitPrefsHook
    ::hooks::register launchFinalHook ::AutoUpdate::LaunchHook

    set menuDef {command  mUpdateCheck  {::AutoUpdate::Get -silent 0}  {}}
    ::JUI::RegisterMenuEntry info $menuDef

    component::register AutoUpdate  \
      "Automatically checks for new version of this application."
}

proc ::AutoUpdate::InitPrefsHook {} {
    global  prefs

    # Auto update mechanism: if lastVersion < run version => autoupdate
    set prefs(autoupdate,lastVersion) 0.0
    set prefs(autoupdate,lastTime)    [clock scan "1 year ago"]
    
    ::PrefUtils::Add [list  \
      [list prefs(autoupdate,lastVersion) prefs_autoupdate_lastVersion $prefs(autoupdate,lastVersion)] \
      [list prefs(autoupdate,lastTime)    prefs_autoupdate_lastTime    $prefs(autoupdate,lastTime)] \
      ]
}

proc ::AutoUpdate::LaunchHook {} {
    global  prefs this config
    
    if {$config(autoupdate,do)} {
	
	# The 'notLater' gives seconds for now minus interval.
	set notLater [clock scan $config(autoupdate,interval)]
	if {$prefs(autoupdate,lastTime) < $notLater} {
	    if {[package vcompare $this(vers,full) $prefs(autoupdate,lastVersion)] > 0} {
		after 10000 ::AutoUpdate::Get 
	    }
	}
    }
}

proc ::AutoUpdate::Get {args} {
    global  this prefs config
    variable opts
    
    ::Debug 2 "::AutoUpdate::Get"
    
    set url $config(autoupdate,url)
    array set opts {
	-silent 1
    }
    array set opts $args
    set tmopts [list -timeout $prefs(timeoutMillis)]
    if {[catch {eval {
	::http::geturl $url -command [namespace code Command]
    } $tmopts} token]} {
	if {!$opts(-silent)} {
	    ::UI::MessageBox -icon error -type ok -message \
	      "Failed connecting server \"$url\" to get update info: $token"
	}
    }
}

proc ::AutoUpdate::Command {token} {
    global  prefs this
    upvar #0 $token state
    variable opts
    variable newVersion

    set prefs(autoupdate,lastTime) [clock seconds]

    # Investigate 'state' for any exceptions.
    set status [::http::status $token]
    
    ::Debug 2 "::AutoUpdate::Command status=$status"
    
    if {$status eq "ok"} {
	    
	# Get and parse xml.
	set xml [::http::data $token]   
	set token [tinydom::parse $xml]
	set xmllist [tinydom::documentElement $token]
	set releaseElem [lindex [tinydom::children $xmllist] 0]
	set releaseAttr [tinydom::attrlist $releaseElem]
	array set releaseA $releaseAttr
	set message ""
	set changesL [list]
	
	foreach elem [tinydom::children $releaseElem] {
	    switch -- [tinydom::tagname $elem] {
		message {
		    set message [tinydom::chdata $elem]
		}
		changes {
		    foreach item [tinydom::children $elem] {
			lappend changesL [tinydom::chdata $item]
		    }
		}
	    }
	}
	set newVersion $releaseA(version)
	
	# Show dialog if newer version available.
	if {[package vcompare $this(vers,full) $releaseA(version)] == -1} {
	    ::AutoUpdate::Dialog $releaseAttr $message $changesL
	} elseif {!$opts(-silent)} {
	    ::UI::MessageBox -icon info -type ok -message \
	      [mc messaupdatelatest $this(vers,full)]
	}
	tinydom::cleanup $token
    }
    ::http::cleanup $token    
}


proc ::AutoUpdate::Dialog {releaseAttr message changesL} {
    global  this prefs
    variable noautocheck
    variable newVersion
    
    set w .aupdate
    if {[winfo exists $w]} {
	return
    }
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -closecommand [namespace current]::Destroy
    wm title $w [mc {New Version}]
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    # Text.
    set wtext $wbox.text
    text $wtext -width 60 -height 16 -wrap word \
      -borderwidth 1 -relief sunken -background white
    pack $wtext
    
    $wtext tag configure msgtag -lmargin1 10 -spacing1 4 -spacing3 4 \
      -font CociSmallBoldFont
    $wtext tag configure attrtag -lmargin1 10 -spacing1 2 -spacing3 2
    $wtext tag configure changestag -lmargin1 10 -spacing1 4 -spacing3 4 \
      -font CociSmallBoldFont
    $wtext tag configure itemtag -lmargin1 20 -lmargin2 30 \
      -spacing1 2 -spacing3 2
    $wtext configure -tabs {100 right 110 left}
        
    $wtext mark set insert end
    $wtext configure -state normal
    $wtext insert end $message msgtag
    $wtext insert end "\n"
    
    foreach {name value} $releaseAttr {
	$wtext insert end "\t[string totitle $name]:" attrtag
	
	switch -- $name {
	    url {
		$wtext insert end "\t"
		::Text::ParseURI $wtext $value
	    }
	    date {
		set date [clock format [clock scan $value]  \
		  -format "%A %d %B %Y"]
		$wtext insert end "\t$date" attrtag
	    }
	    default {
		$wtext insert end "\t$value" attrtag
	    }
	}
	$wtext insert end "\n"
    }
    $wtext insert end "Changes since previous release:\n" changestag
    foreach item $changesL {
	$wtext insert end "o $item\n" itemtag
    }    
    $wtext configure -state disabled
    
    # Configure text widget height to fit all.
    tkwait visibility $wtext
    foreach {ystart yfrac} [$wtext yview] break
    $wtext configure -height [expr int([$wtext cget -height]/$yfrac) + 0]
    
    set noautocheck 0
    if {[package vcompare $this(vers,full) $prefs(autoupdate,lastVersion)] <= 0} {
    	set noautocheck 1
    }
    ttk::checkbutton $wbox.ch -text [mc autoupdatenot] \
      -variable [namespace current]::noautocheck
    pack $wbox.ch -side top -anchor w -pady 8
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot
    ttk::button $frbot.btok -text [mc Close] \
      -command [list destroy $w]
    pack $frbot.btok -side right
    pack $frbot -side top -fill x
    
    wm resizable $w 0 0
}

proc ::AutoUpdate::Destroy {w} {
    global  prefs
    variable noautocheck
    variable newVersion
    
    if {$noautocheck} {
	set prefs(autoupdate,lastVersion) $newVersion
    } else {
	set prefs(autoupdate,lastVersion) 0.0
    }
}
    
#-------------------------------------------------------------------------------
