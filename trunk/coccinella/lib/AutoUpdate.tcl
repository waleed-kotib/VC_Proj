#  AutoUpdate.tcl ---
#  
#      This file is part of The Coccinella application. It implements 
#      methods to query for new versions.
#
#  Copyright (c) 2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: AutoUpdate.tcl,v 1.9 2004-07-09 06:26:06 matben Exp $

package require tinydom
package require http 2.3

package provide AutoUpdate 1.0

namespace eval ::AutoUpdate:: {
    
    variable newVersion 1.0
}

proc ::AutoUpdate::Get {url args} {
    global  this prefs
    variable opts
    
    ::Debug 2 "::AutoUpdate::Get url=$url"
    
    array set opts {
	-silent 1
    }
    array set opts $args
    if {0 && [string equal $this(platform) "macintosh"]} {
	set tmopts ""
    } else {
	set tmopts [list -timeout $prefs(timeoutMillis)]
    }
    if {[catch {eval {
	::http::geturl $url -command [namespace current]::Command
    } $tmopts} token]} {
	if {!$opts(-silent)} {
	    tk_messageBox -icon error -type ok -message \
	      "Failed connecting server \"$url\" to get update info: $token"
	}
    }
}

proc ::AutoUpdate::Command {token} {
    global  prefs
    upvar #0 $token state
    variable opts
    variable newVersion
    
    # Investigate 'state' for any exceptions.
    set status [::http::status $token]
    if {$status == "ok"} {
	    
	# Get and parse xml.
	set xml [::http::data $token]   
	set token [tinydom::parse $xml]
	set xmllist [tinydom::documentElement $token]
	set releaseElem [lindex [tinydom::children $xmllist] 0]
	set releaseAttr [tinydom::attrlist $releaseElem]
	array set releaseArr $releaseAttr
	set message ""
	set changesList {}
	
	foreach elem [tinydom::children $releaseElem] {
	    switch -- [tinydom::tagname $elem] {
		message {
		    set message [tinydom::chdata $elem]
		}
		changes {
		    foreach item [tinydom::children $elem] {
			lappend changesList [tinydom::chdata $item]
		    }
		}
	    }
	}
	set newVersion $releaseArr(version)
	
	# Show dialog if newer version available.
	if {[package vcompare $prefs(fullVers) $releaseArr(version)] == -1} {
	    ::AutoUpdate::Dialog $releaseAttr $message $changesList
	} elseif {!$opts(-silent)} {
	    tk_messageBox -icon info -type ok -message \
	      "You already have the latest version available ($prefs(fullVers))"
	}
	tinydom::cleanup $token
    }
    ::http::cleanup $token    
}


proc ::AutoUpdate::Dialog {releaseAttr message changesList} {
    global  this prefs
    variable noautocheck
    variable newVersion
    
    set w .aupdate
    if {[winfo exists $w]} {
	return
    }
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1
    wm title $w "New Version"
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1
    
    # Text.
    set wtext $w.frall.text
    text $wtext -width 60 -height 16 -wrap word \
      -borderwidth 1 -relief sunken -background white
    pack $wtext
    
    $wtext tag configure msgtag -lmargin1 10 -spacing1 4 -spacing3 4 \
      -font $fontSB
    $wtext tag configure attrtag -lmargin1 10 -spacing1 2 -spacing3 2
    $wtext tag configure changestag -lmargin1 10 -spacing1 4 -spacing3 4 \
      -font $fontSB
    $wtext tag configure itemtag -lmargin1 20 -lmargin2 30 \
      -spacing1 2 -spacing3 2
    ::Text::ConfigureLinkTagForTextWidget $wtext urltag activeurltag
    $wtext configure -tabs {100 right 110 left}
        
    $wtext configure -state normal
    $wtext insert end $message msgtag
    $wtext insert end "\n"
    
    foreach {name value} $releaseAttr {
	$wtext insert end "\t[string totitle $name]:" attrtag
	
	switch -- $name {
	    url {
		$wtext insert end "\t$value" urltag
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
    foreach item $changesList {
	$wtext insert end "o $item\n" itemtag
    }    
    $wtext configure -state disabled
    
    # Configure text widget height to fit all.
    tkwait visibility $wtext
    foreach {ystart yfrac} [$wtext yview] break
    $wtext configure -height [expr int([$wtext cget -height]/$yfrac) + 0]
    
    set noautocheck 0
    if {[package vcompare $prefs(fullVers) $prefs(lastAutoUpdateVersion)] <= 0} {
    	set noautocheck 1
    }
    checkbutton $w.frall.ch -text " [mc autoupdatenot]" \
      -variable [namespace current]::noautocheck
    pack $w.frall.ch -side top -anchor w -padx 10 -pady 4
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btset -text [mc Close] \
      -command "destroy $w"] -side right -padx 5 -pady 5
    pack $frbot -side top -fill x -padx 8 -pady 6
    
    bind $w <Destroy> [namespace current]::Destroy
}

proc ::AutoUpdate::Destroy { } {
    global  prefs
    variable noautocheck
    variable newVersion
    
    if {$noautocheck} {
	set prefs(lastAutoUpdateVersion) $newVersion
    } else {
	set prefs(lastAutoUpdateVersion) 0.0
    }
}
    
#-------------------------------------------------------------------------------
