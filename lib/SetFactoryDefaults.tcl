#  SetFactoryDefaults.tcl ---
#  
#      This file is part of the whiteboard application. 
#      Standard (factory) preferences are set here.
#      These are the hardcoded, application default, values, and can be
#      overridden by the ones in user default file.
#      
#      prefs:       preferences, application global
#      state:       state variables, specific to toplevel whiteboard
#      
#  Copyright (c) 2002-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: SetFactoryDefaults.tcl,v 1.19 2003-12-20 14:27:16 matben Exp $

# SetWhiteboardFactoryState --
# 
#       There is a global 'state' array which contains a generic state
#       that is inherited by instance specific 'state' array '::${wtop}::state'

proc SetWhiteboardFactoryState { } {
    global  state
    
    # The tool buttons.
    set state(btState) 00
    set state(btStateOld) 00

    # Is the toolbar visible?
    set state(visToolbar) 1
    
    # Bg color for canvas.
    set state(bgColCan) #dedede
    
    # fg and bg colors set in color selector; bgCol always white.
    set state(fgCol) black
    set state(bgCol) white
    
    # Grid on or off.
    set state(canGridOn) 0                  
    
    # Line thickness.
    set state(penThick) 1	
    
    # Brush thickness.
    set state(brushThick) 8	
    
    # Fill color for circles, polygons etc.
    set state(fill) 0
    
    # If polygons should be smoothed.
    set state(smooth) 0
    
    # Arc styles.
    set state(arcstyle) "arc"
    
    # Dash style.
    set state(dash) { }
    
    # Font prefs set in menus. Sizes according to html.
    set state(fontSize) 2
    set state(font) Helvetica
    set state(fontWeight) normal
}

# Generic state variables for the whiteboard.
SetWhiteboardFactoryState

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
set prefs(httpdRootDir) $this(path)

# NAT stuff.
set prefs(setNATip) 0
set prefs(NATip) ""

# EAS: Privaria only starts server after tunnel is established,
# so no server delay is needed
set prefs(afterStartServer) 0   
# EAS: Need to give server a chance to start, as occasionally
# it isn't done when client connects
set prefs(afterConnect) 1000

# Side of selecting box .
set prefs(aBBox) 2

# Offset when duplicating canvas items and when opening images and movies.
# Needed in ::CanvasUtils::NewImportAnchor
set prefs(offsetCopy) 16

# Should text inserts be batched?
set prefs(batchText) 1

# Delay time in ms for batched text.
set prefs(batchTextms) 2000

# Want to fit all movies within canvas?
set prefs(autoFitMovies) 1

set prefs(canvasFonts) [list Times Helvetica Courier]
set prefs(haveScrollbars) 1
set prefs(canScrollWidth) 1800
set prefs(canScrollHeight) 1200

# Html sizes or point sizes when transferring text items?
set prefs(useHtmlSizes) 1

# Offset when duplicating canvas items and when opening images and movies.
# Needed in ::CanvasUtils::NewImportAnchor
set prefs(offsetCopy) 16

# Grid spacing.
set prefs(gridDist) 40                 

# Only manipulate own items?
set prefs(privacy) 0

# How expressive shall we be with message boxes?
set prefs(talkative) 0

# Should we check that server commands do not contain any potentially harmful
# instructions?
set prefs(checkSafety) 1

# Mark bounding box (1) or each coords (0).
set prefs(bboxOrCoords) 0

# Wraplength of text in message box for windows.
set prefs(msgWrapLength) 60

# Scale factor used when scaling canvas items.
set prefs(scaleFactor) 1.2
set prefs(invScaleFac) [expr 1.0/$prefs(scaleFactor)]

# Use common CG when scaling more than one item?
set prefs(scaleCommonCG) 0

# Constrain movements to 45 degrees, else 90 degree intervals.
set prefs(45) 1

# Fraction of points to strip when straighten.
set prefs(straightenFrac) 0.3

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

# Safe server interpretator? (not working)
set prefs(makeSafeServ) 1

# Maximum time to wait for any network action to respond. (secs and millisecs)
set prefs(timeoutSecs) 30
#set prefs(timeoutSecs) 10
set prefs(timeoutMillis) [expr 1000 * $prefs(timeoutSecs)]

# How many milliseconds shall we wait before showing the progress window?
set prefs(millisToProgWin) 0

# How frequently shall the progress window be updated, in milliseconds.
set prefs(progUpdateMillis) 500
set prefs(progUpdateMillis) 1000

# When and how old is a cached file allowed to be before downloading a new?
# Options. "never", "always", "launch", "hour", "day", "week", "month"
set prefs(checkCache) "launch"

# Switch to make the jabber comm entry already at build.
# 0 means that it is built first when connected.
set prefs(jabberCommFrame) 1

# If we have got TclSpeech the default is to have it enabled.
set prefs(SpeechOn) 1

# Default in/out voices. They will be set to actual values in 
# ::Plugins::VerifySpeech  
set prefs(voiceUs) ""
set prefs(voiceOther) ""
    
# Installation directories.
set prefs(itemDir) [file join $this(path) items]
set prefs(addonsDir) [file join $this(path) addons]

# Plugin ban list. Do not load these packages.
set prefs(pluginBanList) {}

# File open/save initialdirs.
set prefs(userDir) $this(path)

# If it is the first time the application is launched, then welcome.
set prefs(firstLaunch) 1

# Auto update mechanism: if lastAutoUpdateVersion < run version => autoupdate
set prefs(lastAutoUpdateVersion) 0.0
set prefs(doneAutoUpdate) 0
set prefs(urlAutoUpdate) "http://coccinella.sourceforge.net/updates/update_en.xml"
#set prefs(urlAutoUpdate) "http://coccinella.sourceforge.net/updates/update_test.xml"

# The file name of the welcoming canvas.
set prefs(welcomeFile) [file join $this(path) welcome.can]

# Shell print command in unix.
if {[info exists env(PRINTER)]} {
    set prefs(unixPrintCmd) "lpr -P$env(PRINTER)"
} else {
    set prefs(unixPrintCmd) "lpr"
}

set prefs(clearCacheOnQuit) 0

# Postscript options. A4 paper minus some margin (297m 210m).
set prefs(postscriptOpts) {-pageheight 280m -pagewidth 190m -pageanchor c}

# Useful time constants in seconds. Not used.
set tmsec(min) 60
set tmsec(hour) [expr 60*$tmsec(min)]
set tmsec(day) [expr 24*$tmsec(hour)]
set tmsec(week) [expr 7*$tmsec(day)]
set tmsec(30days) [expr 30*$tmsec(day)]

# Various constants.
set kPI 3.14159265359
set kRad2Grad [expr 180.0/$kPI]
set kGrad2Rad [expr $kPI/180.0]
set kTan225 [expr tan($kPI/8.0)]
set kTan675 [expr tan(3.0 * $kPI/8.0)]

#---- The state variables: 'state' ------------------------------------------

# Is the internal server started?
set state(isServerUp) 0

# The reflector server?
set state(reflectorStarted) 0

# Any connections yet?
set state(connectedOnce) 0

# Are there a working canvas dash option?
set prefs(haveDash) 0
if {![string match "mac*" $this(platform)]} {
    set prefs(haveDash) 1
}

# Dashed options. Used both for the Preference menu and ItemInspector.
# Need to be careful not to use empty string for menu value in -variable
# because this gives the 'value' value.
array set dashFull2Short {
    none " " dotted . dash-dotted -. dashed -
}
array set dashShort2Full {
    " " none . dotted -. dash-dotted - dashed
}
set dashShort2Full() none

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

#----   url's for streaming live movies ----------------------------------------
set prefs(shortsMulticastQT) {{   \
  {user specified}   \
  {Bloomberg}          \
  {Hard Radio}       \
  {NPR}  \
  {BBC World TV} } {  \
  {}  \
  www.apple.com/quicktime/showcase/radio/bloomberg/bloombergradio.mov  \
  www.apple.com/quicktime/showcase/radio/hardradio/hardradio.mov  \
  www.apple.com/quicktime/showcase/radio/npr/npr.mov  \
  www.apple.com/quicktime/favorites/bbc_world1/bbc_world1.mov}}

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
if {[info exists env(USER)]} {
    set this(username) $env(USER)
} elseif {[info exists env(LOGIN)]} {
    set this(username) $env(LOGIN)
} elseif {[info exists env(USERNAME)]} {
    set this(username) $env(USERNAME)
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
	set prefs(incomingPath)  \
	  [file nativename [file join $this(prefsPath) incoming]]
	set prefs(inboxCanvasPath)  \
	  [file nativename [file join $this(prefsPath) canvases]]
	set prefs(historyPath)  \
	  [file nativename [file join $this(prefsPath) history]]
	set prefs(webBrowser) mozilla
    }
    macintosh {
	set osprefs(mod) Command
	set prefs(userPrefsFilePath)  \
	  [file join $this(prefsPath) "Whiteboard Prefs"]
	set prefs(oldPrefsFilePath) [file join $env(PREF_FOLDER) "Whiteboard Prefs"]
	set prefs(incomingPath) [file join $this(prefsPath) Incoming]
	set prefs(inboxCanvasPath) [file join $this(prefsPath) Canvases]
	set prefs(historyPath) [file join $this(prefsPath) History]
	set prefs(webBrowser) {Internet Explorer}
    }
    macosx {
	set osprefs(mod) Command
	set prefs(userPrefsFilePath)  \
	  [file join $this(prefsPath) "Whiteboard Prefs"]
	set prefs(oldPrefsFilePath) $prefs(userPrefsFilePath)
	set prefs(incomingPath) [file join $this(prefsPath) Incoming]
	set prefs(inboxCanvasPath) [file join $this(prefsPath) Canvases]
	set prefs(historyPath) [file join $this(prefsPath) History]
	set prefs(webBrowser) {Safari}
    }
    windows {
	set osprefs(mod) Control
	set prefs(userPrefsFilePath) [file join $this(prefsPath) "WBPREFS.TXT"]
	set prefs(oldPrefsFilePath) [file join C: "WBPREFS.TXT"]
	set prefs(incomingPath) [file join $this(prefsPath) Incoming]
	set prefs(inboxCanvasPath) [file join $this(prefsPath) Canvases]
	set prefs(historyPath) [file join $this(prefsPath) History]
	
	# Not used anymore. Uses the registry instead.
	set prefs(webBrowser) {C:/Program/Internet Explorer/IEXPLORE.EXE}
    }
}

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
    
# Find out how many clicks or milliseconds there are on each second.
set timingClicksToSecs 1000
set timingClicksToMilliSecs 1.0

# The jabber defaults.

if {!$prefs(stripJabber)} {
    ::Jabber::FactoryDefaults
}

#-------------------------------------------------------------------------------
