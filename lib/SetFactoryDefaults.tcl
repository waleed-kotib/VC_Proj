#  SetFactoryDefaults.tcl ---
#  
#      This file is part of The Coccinella application. 
#      Standard (factory) preferences are set here.
#      These are the hardcoded, application default, values, and can be
#      overridden by the ones in user default file.
#      
#      prefs:       preferences, application global
#      state:       state variables, specific to toplevel whiteboard
#      
#  Copyright (c) 2002-2004  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: SetFactoryDefaults.tcl,v 1.42 2004-11-23 12:57:05 matben Exp $


set noErr 0

# If embedded in web browser we have no menubar.
if {$prefs(embedded)} {
    set prefs(haveMenus) 0
} else {
    set prefs(haveMenus) 1
}

# If we have -compound left -image ... -label ... working.
set prefs(haveMenuImage) 0
if {([package vcompare [info tclversion] 8.4] >= 0) &&  \
  ![string equal $this(platform) "macosx"]} {
    set prefs(haveMenuImage) 1
}

# Shall we run the httpd?
set prefs(haveHttpd) 1
if {[string equal $this(platform) "macintosh"]} {
    set prefs(haveHttpd) 0
}

# Dialog window custom geometries: {pathName wxh+x+y ...}
set prefs(winGeom) {}

# Same for panes.
set prefs(paneGeom) {}

# ip numbers, port numbers, and names.
set prefs(thisServPort) 8235
set prefs(remotePort) 8235
set prefs(reflectPort) 8144

# The tinyhttpd server port number and base directory.
set prefs(httpdPort) 8077

# File transport method: put/get or http.
set prefs(trptMethod) putget
#set prefs(trptMethod) http

# NAT stuff.
set prefs(setNATip) 0
set prefs(NATip) ""

# so no server delay is needed
set prefs(afterStartServer) 0   

# it isn't done when client connects
set prefs(afterConnect) 1000

# How expressive shall we be with message boxes?
set prefs(talkative) 0

# Wraplength of text in message box for windows.
set prefs(msgWrapLength) 60

# Network options: symmetric network, or a central server?
# Jabber server or our own (standard) protocol?
# Options: 
#    jabber:        default
#    symmetric:     client and server in one
#    central:       abondoned
#    client:        client only; may only use client sockets. Special!
#    server:        server only; may only use server sockets. Special!
set prefs(protocol) jabber

# Connect automatically to connecting clients if 'symmetricNet'.
set prefs(autoConnect) 1                

# Disconnect automatically to disconnecting clients.
set prefs(autoDisconnect) $prefs(autoConnect)	

# When connecting to other client, connect automatically to all *its* clients.
set prefs(multiConnect) 1

# Start server when launching application, if not client only?
set prefs(autoStartServer) 1

# Open connection in async mode.
set prefs(asyncOpen) 1

# Safe server interpretator.
set prefs(makeSafeServ) 1

# Maximum time to wait for any network action to respond. (secs and millisecs)
set prefs(timeoutSecs) 30
#set prefs(timeoutSecs) 4
set prefs(timeoutMillis) [expr 1000 * $prefs(timeoutSecs)]

# How many milliseconds shall we wait before showing the progress window?
set prefs(millisToProgWin) 0

# How frequently shall the progress window be updated, in milliseconds.
set prefs(progUpdateMillis) 500
set prefs(progUpdateMillis) 1000

set prefs(userPath) $this(appPath)

# If it is the first time the application is launched, then welcome.
set prefs(firstLaunch) 1

# Shell print command in unix.
if {[string equal $this(platform) "unix"]} {
    if {![catch {exec which kprinter}]} {
	set prefs(unixPrintCmd) "kprinter"
    } elseif {[info exists ::env(PRINTER)]} {
	set prefs(unixPrintCmd) "lpr -P$::env(PRINTER)"
    } else {
	set prefs(unixPrintCmd) "lpr"
    }
} else {
    set prefs(unixPrintCmd) "lpr"
}

set prefs(clearCacheOnQuit) 0

# Postscript options. A4 paper minus some margin (297m 210m).
set prefs(postscriptOpts) {-pageheight 280m -pagewidth 190m -pageanchor c}

# Useful time constants in seconds. Not used.
set tmsec(min) 60
set tmsec(hour)   [expr 60*$tmsec(min)]
set tmsec(day)    [expr 24*$tmsec(hour)]
set tmsec(week)   [expr 7*$tmsec(day)]
set tmsec(30days) [expr 30*$tmsec(day)]

# Various constants.
set kPI 3.14159265359
set kRad2Grad [expr 180.0/$kPI]
set kGrad2Rad [expr $kPI/180.0]
set kTan225   [expr tan($kPI/8.0)]
set kTan675   [expr tan(3.0 * $kPI/8.0)]

#---- The state variables: 'state' ------------------------------------------

# Is the internal server started?
set state(isServerUp) 0

# The reflector server?
set state(reflectorStarted) 0

# Any connections yet?
set state(connectedOnce) 0

# No -filetypes option in 'tk_getSaveFile' on latest MacTk.
# Need to check the Mac Tk patchlevel also (>= 8.3.1).
set prefs(haveSaveFiletypes) 1
if {$this(platform) == "macintosh"} {
    set prefs(haveSaveFiletypes) 0
}

#---- Shortcuts ----------------------------------------------------------------
#----   domain names for open connection ---------------------------------------
set prefs(shortcuts) { \
  {{user specified} remote.computer.name} \
  {{My Mac} 192.168.0.2} \
  {{Home PC} 192.168.0.4} \
  {other other.computer.name}}

#-------------------------------------------------------------------------------

# Mapping from error code to error message; 320+ own, rest HTTP codes.
array set tclwbProtMsg {
    100 Continue
    101 {Switching Protocols}
    200 OK
    201 Created
    202 Accepted
    203 {Non-Authoritative Information}
    204 {No Content}
    205 {Reset Content}
    206 {Partial Content}
    300 {Multiple Choices}
    301 {Moved Permanently}
    302 Found
    303 {See Other}
    304 {Not Modified}
    305 {Use Proxy}
    307 {Temporary Redirect}
    320 {File already cached}
    321 {MIME type unsupported}
    322 {MIME type not given}
    323 {File obtained via url instead}
    340 {No other clients connected}
    400 {Bad Request}
    401 Unauthorized
    402 {Payment Required}
    403 Forbidden
    404 {Not Found}
    405 {Method Not Allowed}
    406 {Not Acceptable}
    407 {Proxy Authentication Required}
    408 {Request Time-out}
    409 Conflict
    410 Gone
    411 {Length Required}
    412 {Precondition Failed}
    413 {Request Entity Too Large}
    414 {Request-URI Too Large}
    415 {Unsupported Media Type}
    416 {Requested Range Not Satisfiable}
    417 {Expectation Failed}
    500 {Internal Server Error}	
    501 {Not Implemented}
    502 {Bad Gateway}
    503 {Service Unavailable}
    504 {Gateway Time-out}
    505 {HTTP Version not supported}
}

# Find user name.
if {[info exists ::env(USER)]} {
    set this(username) $::env(USER)
} elseif {[info exists ::env(LOGIN)]} {
    set this(username) $::env(LOGIN)
} elseif {[info exists ::env(USERNAME)]} {
    set this(username) $::env(USERNAME)
} elseif {[llength $this(hostname)]} {
    set this(username) $this(hostname)
} else {
    set this(username) "Unknown"
}

# Try to get own ip number from a temporary server socket.
# This can be a bit complicated as different OS sometimes give 0.0.0.0 or
# 127.0.0.1 instead of the real number.

if {![catch {socket -server puts 0} s]} {
    set this(ipnum) [lindex [fconfigure $s -sockname] 0]
    catch {close $s}
    Debug 2 "1st: this(ipnum)=$this(ipnum)"
}

# If localhost or zero, try once again with '-myaddr'. 
# My Linux box is not helped by this either!!!
# Multiple ip interfaces are not recognized!
if {[string equal $this(ipnum) "0.0.0.0"] ||  \
  [string equal $this(ipnum) "127.0.0.1"]} {
    if {![catch {socket -server xxx -myaddr $this(hostname) 0} s]} {
	set this(ipnum) [lindex [fconfigure $s -sockname] 0]
	catch {close $s}
	Debug 2 "2nd: this(ipnum)=$this(ipnum)"
    }
}
if {[regexp {[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+} $this(ipnum)]} {
    set this(ipver) 4
} else {
    set this(ipver) 6
}

# Modifier keys and meny height (guess); add canvas border as well.
# System fonts used. Other system dependent stuff.
switch -- $this(platform) {
    unix {
	set osprefs(mod) Control
	
	# On a central installation need to have local dirs for write access.
	set prefs(userPrefsFilePath)  \
	  [file nativename [file join $this(prefsPath) whiteboard]]
	set prefs(oldPrefsFilePath) [file nativename ~/.whiteboard]
	set prefs(inboxCanvasPath)  \
	  [file nativename [file join $this(prefsPath) canvases]]
	set prefs(historyPath)  \
	  [file nativename [file join $this(prefsPath) history]]
	if {[info exists ::env(BROWSER)]} {
	    if {[llength [auto_execok $::env(BROWSER)]] > 0} {
		set prefs(webBrowser) $::env(BROWSER)
	    } else {	    
		set prefs(webBrowser) ""
	    }
	} else {
	    set prefs(webBrowser) ""
	}
    }
    macintosh {
	set osprefs(mod) Command
	set prefs(userPrefsFilePath)  \
	  [file join $this(prefsPath) "Whiteboard Prefs"]
	set prefs(oldPrefsFilePath) [file join $::env(PREF_FOLDER) "Whiteboard Prefs"]
	set prefs(inboxCanvasPath) [file join $this(prefsPath) Canvases]
	set prefs(historyPath) [file join $this(prefsPath) History]
	set prefs(webBrowser) {Internet Explorer}
    }
    macosx {
	set osprefs(mod) Command
	set prefs(userPrefsFilePath)  \
	  [file join $this(prefsPath) "Whiteboard Prefs"]
	set prefs(oldPrefsFilePath) $prefs(userPrefsFilePath)
	set prefs(inboxCanvasPath) [file join $this(prefsPath) Canvases]
	set prefs(historyPath) [file join $this(prefsPath) History]
	set prefs(webBrowser) {Safari}
    }
    windows {
	set osprefs(mod) Control
	set prefs(userPrefsFilePath) [file join $this(prefsPath) "WBPREFS.TXT"]
	set prefs(oldPrefsFilePath) [file join C: "WBPREFS.TXT"]
	set prefs(inboxCanvasPath) [file join $this(prefsPath) Canvases]
	set prefs(historyPath) [file join $this(prefsPath) History]
	
	# Not used anymore. Uses the registry instead.
	set prefs(webBrowser) {C:/Program/Internet Explorer/IEXPLORE.EXE}
    }
}
set prefs(incomingPath) [file join $this(prefsPath) Incoming]

# Make sure we've got the necessary directories.
if {![file isdirectory $this(prefsPath)]} {
    file mkdir $this(prefsPath)
}
if {![file isdirectory $prefs(incomingPath)]} {
    file mkdir $prefs(incomingPath)
}
if {![file isdirectory $prefs(inboxCanvasPath)]} {
    file mkdir $prefs(inboxCanvasPath)
}
if {![file isdirectory $prefs(historyPath)]} {
    file mkdir $prefs(historyPath)
}
if {![file isdirectory $this(altItemPath)]} {
    file mkdir $this(altItemPath)
}

# Privacy!
switch -- $tcl_platform(platform) {
    unix {
	# Make sure other have absolutely no access to our prefs.
	file attributes $this(prefsPath) -permissions o-rwx
    }
}

# Find out how many clicks or milliseconds there are on each second.
set timingClicksToSecs 1000
set timingClicksToMilliSecs 1.0

# The jabber defaults.

if {!$prefs(stripJabber)} {
    ::Jabber::FactoryDefaults
}

#-------------------------------------------------------------------------------
