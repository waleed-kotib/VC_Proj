#  Httpd.tcl ---
#  
#       This file is part of The Coccinella application. 
#       It is a wrapper for tinyhttpd.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: Httpd.tcl,v 1.4 2005-08-14 07:17:55 matben Exp $
    
package provide Httpd 1.0

namespace eval ::Httpd:: { 

    ::hooks::register initHook  ::Httpd::InitHook
}

proc ::Httpd::InitHook { } {
    global  prefs this auto_path
    
    # Start httpd thread. It enters its event loop if created without a sript.
    if {$this(package,Thread)} {
	set this(httpdthreadid) [thread::create]
	thread::send $this(httpdthreadid) [list set auto_path $auto_path]
    }
    
    # The 'tinyhttpd' package must be loaded in its threads interpreter if exists.
    if {$this(package,Thread)} {
	thread::send $this(httpdthreadid) {package require tinyhttpd}
    } else {
	package require tinyhttpd
    }
    
    # And start server.
    Httpd
}

proc ::Httpd::Httpd { } {
    global  prefs this
    
    ::Debug 2 "::Httpd::Httpd"
    
    # Start the tinyhttpd server, in its own thread if available.
    
    if {($prefs(protocol) ne "client") && $prefs(haveHttpd)} {
	set script [list ::tinyhttpd::start -port $prefs(httpdPort)  \
	  -rootdirectory $this(httpdRootPath)]
	
	# For security we don't allow directory listings by default.
	if {$::debugLevel > 0} {
	    lappend script -directorylisting 1
	}
	
	if {[catch {
	    if {$this(package,Thread)} {
		thread::send $this(httpdthreadid) $script
		
		# Add more Mime types than the standard built in ones.
		thread::send $this(httpdthreadid)  \
		  [list ::tinyhttpd::addmimemappings [::Types::GetSuffMimeArr]]
	    } else {
		eval $script
		::tinyhttpd::addmimemappings [::Types::GetSuffMimeArr]
	    }
	} msg]} {
	    ::UI::MessageBox -icon error -type ok \
	      -message [mc messfailedhttp $msg]
	} else {
	    
	    # Stop before quitting.
	    ::hooks::register quitAppHook ::tinyhttpd::stop
	}
    }
}
    
#-------------------------------------------------------------------------------
