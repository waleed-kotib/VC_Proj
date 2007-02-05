# URIRegisterKDE.tcl --
#
#       At least Konqurer on my SUSE box understands this.
#       There is a dependency on ParseURI.
#       
#  Copyright (c) 2007  Mats Bengtsson
#  
# $Id: URIRegisterKDE.tcl,v 1.1 2007-02-05 14:54:17 matben Exp $

proc URIRegisterKDE::Init { } {
    global  this
    
    if {![string equal $this(platform) "unix"]} {
	return
    }
    
    # Try to see if we've got KDE.
    set dir ~/.kde/share/services/
    if {![file isdirectory $dir]} {
	return
    }
    RegisterKDE
    
    component::register URIRegisterKDE  \
      {Uses KDE's service file for XMPP to handle uri parsing.}
}

# ParseURI::RegisterKDE --
# 
#       At least Konqurer on my SUSE box understands this.

proc ::ParseURI::RegisterKDE {} {
    global  this

    set prefsPath  [file nativename ~/.coccinella]
    set scriptFile [file join $prefsPath handle_uri.tcl]

    # Not sure how any spaces should be handled; uri parsed?
    set protocolSpec {[Protocol]
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
# the next line restarts using wish \
    exec wish "$0" -visual best "$@"
    wm withdraw .
    set prefsPath [file nativename ~/.coccinella]
    set pidFile   [file join $prefsPath coccinella.pid]
    set execFile  [file join $prefsPath launchCmd]
    set uri [lindex $argv 0]
    if {[file exists $pidFile]} {
	send -async coccinella [list ::ParseURI::TextCmd $uri]
    } else {
	set fd [open $execFile r]
	set exe [read $fd]
	close $fd
	eval exec $exe &
    }
    exit
}
    # --- End script ---
    
    # Write the launch script in to our prefs dir.
    if {![file exists $scriptFile]} {
	set fd [open $scriptFile w]
	puts $fd $script
	close $fd
	file attributes $scriptFile -permissions "u+x"
    }     
}

