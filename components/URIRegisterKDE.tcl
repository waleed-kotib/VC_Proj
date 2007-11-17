# URIRegisterKDE.tcl --
#
#       At least Konqurer on my SUSE box understands this.
#       There is a dependency on ParseURI.
#       
#  Copyright (c) 2007 Mats Bengtsson
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
# $Id: URIRegisterKDE.tcl,v 1.5 2007-11-17 07:40:52 matben Exp $

namespace eval URIRegisterKDE { 
    
    if {![string equal $::this(platform) "unix"]} {
	return
    }
    
    # Try to see if we've got KDE.
    set dir ~/.kde/share/services/
    if {![file isdirectory $dir]} {
	return
    }

    component::define URIRegisterKDE "Adds XMPP uri parsing support in KDE"
}

proc URIRegisterKDE::Init {} {

    Register
    
    component::register URIRegisterKDE
}

# ParseURI::RegisterKDE --
# 
#       At least Konqurer on my SUSE box understands this.

proc ::URIRegisterKDE::Register {} {
    global  this

    set prefsPath  [file nativename ~/.coccinella]
    set scriptFile [file join $prefsPath scripts handle_uri.tcl]

    # Not sure how any spaces should be handled; uri parsed?
    set protocolSpec {\
[Protocol]
exec=@T %u
protocol=xmpp
input=none
output=none
helper=true
listing=false
reading=false
writing=false
makedir=false
deleting=false
Icon="" 
}

    set protocolSpec [string map [list @T $scriptFile] $protocolSpec]

    # Write protocol file only if dir exists.
    set dst ~/.kde/share/services/xmpp.protocol
    if {[file isdirectory [file dirname $dst]]} {
	set fd [open $dst w]
	puts $fd $protocolSpec
	close $fd
    }

    # This is a script that either sends off a command to open the uri or
    # launches the app with -uri.

    # --- Begin script ---

    set script {#!/bin/sh
# the next line restarts using wish @B
	exec wish "$0" -visual best "$@"

    wm withdraw .
    set prefsPath [file nativename ~/.coccinella]
    set pidFile   [file join $prefsPath coccinella.pid]
    set execFile  [file join $prefsPath launchCmd]

    set runs 0
    if {[file exists $pidFile]} {
	set fd [open $pidFile r]
	set pid [read $fd]
	close $fd
	# BSD style:
	# set pids [exec ps -xa -o pid]
	# On unix BSD switches must not have dashes.
	set pids [exec ps xa o pid]
	set runs [expr {[lsearch $pids $pid] >= 0 ? 1 : 0}]
    }
    set uri [lindex $argv 0]
    
    if {$runs} {
	send -async coccinella [list ::ParseURI::TextCmd $uri]
    } else {
	set fd [open $execFile r]
	set exe [read $fd]
	close $fd
	eval exec $exe [list -uri $uri] &
    }
    exit
}
    # --- End script ---
        
    # Trick to get the ending \ in place.
    set script [string map {@B \\} $script]

    # Write the launch script  to our prefs dir.
    if {![file exists $scriptFile]} {
	set fd [open $scriptFile w]
	puts $fd $script
	close $fd
	file attributes $scriptFile -permissions "u+x"
    }     
}

