#  Httpd.tcl ---
#  
#       This file is part of The Coccinella application. 
#       It is a wrapper for tinyhttpd.
#      
#  Copyright (c) 2004  Mats Bengtsson
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
# $Id: Httpd.tcl,v 1.7 2007-09-14 08:11:46 matben Exp $
    
package provide Httpd 1.0

namespace eval ::Httpd:: { 

    ::hooks::register initHook  ::Httpd::InitHook
}

proc ::Httpd::InitHook {} {
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

proc ::Httpd::Httpd {} {
    global  prefs this
    
    ::Debug 2 "::Httpd::Httpd"
    
    # Start the tinyhttpd server, in its own thread if available.
    
    if {$prefs(haveHttpd)} {
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
	    ::UI::MessageBox -icon error -title [mc Error] -type ok \
	      -message [mc messfailedhttp2 $msg]
	} else {
	    
	    # Stop before quitting.
	    ::hooks::register quitAppHook ::tinyhttpd::stop
	}
    }
}
    
#-------------------------------------------------------------------------------
