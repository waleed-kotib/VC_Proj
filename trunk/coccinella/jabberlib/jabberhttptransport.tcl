#  jabberhttptransport.tcl ---
#  
#      Provides a http transport mechanism for jabberlib. 
#      
#  Copyright (c) 2002  Mats Bengtsson
#
# $Id: jabberhttptransport.tcl,v 1.2 2003-10-18 07:43:56 matben Exp $
# 
# USAGE ########################################################################
#
# jlibhttp::init url ?-key value ...?
#	url 	A valid url for the POST method of HTTP.
#	-command callback	a tcl procedure of the form 'callback {status message}
#	-pollinterval ms	interval in ms for polling server
#       -proxyhost domain	name of proxu host if any
#       -proxyport integer	and its port number
#	-proxyusername name	your username for the proxy
#	-proxypasswd secret	and your password
#	-resendinterval ms	if sending fails, try again after this interval
#	-timeout ms		timeout for connecting the server
#
# Callbacks for the JabberLib:
#	jlibhttp::transportinit, jlibhttp::transportreset, jlibhttp::send
#
#

package require jabberlib
package require http 2.3
package require base64

package provide jlibhttp 0.1

namespace eval jlibhttp {

    # All non-options should be in this array.
    variable locals
}

# jlibhttp::init --
#
#	Configures the state of this thing.

proc jlibhttp::init {url args} {

    variable opts
    variable locals

    set locals(id) 0

    array set opts {
	-pollinterval 4000
	-proxyhost {} 
	-proxyport 8080
	-proxyusername {}
	-proxypasswd {}
	-resendinterval 20000
	-timeout 20000
	header
	proxyheader {}
	url {}
    }
    array set opts $args
    if {![regexp -nocase {^(([^:]*)://)?([^/:]+)(:([0-9]+))?(/.*)?$} $url \
      x prefix proto host y port filepath]} {
	return -code error "The url \"$url\" is not valid"
    }

    if {[string length $opts(-proxyhost)] && [string length $opts(-proxyport)]} {
   	::http::config -proxyhost $opts(-proxyhost) -proxyport $opts(-proxyport)
    }
    if {[string length $opts(-proxyusername)] || \
	[string length $opts(-proxypasswd)]} {
	set opts(proxyheader) [jlibhttp::buildproxyheader  \
		$opts(-proxyusername) $opts(-proxypasswd)]
    }
    set opts(header) $opts(proxyheader)
}

# jlibhttp::buildproxyheader --
#
#	Builds list for the "Proxy-Authorization" header line.

proc jlibhttp::buildproxyheader {proxyusername proxypasswd} {
    
    set auth [list "Proxy-Authorization" \
      [concat "Basic" [base64::encode \
      $proxyusername:$proxypasswd]]]

    return $auth
}

# jlibhttp::transportinit --
#
#	For the -transportinit command.

proc jlibhttp::transportinit {} {


    # Start polling.
    jlibhttp::poll
}

# jlibhttp::transportreset --
#
#	For the -transportreset command.

proc jlibhttp::transportreset {} {

    variable locals

    # Stop polling and resends.
    catch {after cancel $locals(resendid)}
    catch {after cancel $locals(pollid)}

    set locals(id) 0
}

# jlibhttp::send --
#
#	For the -transportsend command.

proc jlibhttp::send {xml} {
    
    variable opts
    variable locals
    
    set qry "$locals(id),$xml"
    
    # -query forces a POST request.
    # Make sure we send it as text dispite the application/* type.???
    if {[catch {
	set token [::http::geturl $opts(url)  \
	  -timeout $opts(-timeout)  \
	  -query $qry \
	  -headers $opts(header) \
	  -command jlibhttp::senddone]
    } msg]} {
	set locals(resendid) [after $opts(-resendinterval) jlibhttp::send $xml]]
    }
}

# jlibhttp::senddone --
#
#	The response to our POST request. Parse any indata that should
#	be of mime type text/xml

proc jlibhttp::senddone {token} {
    upvar #0 $token state
    variable locals
    variable opts
    
    # Trap any errors first.
    set status [::http::status $token]
    switch -- $status {
	error - timeout - reset {
	    if {[info exists opts(-command)]} {
		uplevel #0 $opts(-command) {$status [httpex::error $token]}
	    }
	}
	ok {
	    
	    # Extract the 'id' from the Set-Cookie key.
	    array set metaArr $state(meta)
	    set errmsg ""
	    if {![info exists metaArr(Set-Cookie)]} {
		# This is an invalid response.
		set errmsg "Missing Set-Cookie in HTTP header"
	    }
	    if {![regexp -nocase {ID=([0-9a-zA-Z:\-]+).*}  \
	      $metaArr(Set-Cookie) match id]} {
		# This is an invalid response.
		set errmsg "Set-Cookie in HTTP header \"$metaArr(Set-Cookie)\""
		append errmsg " is not ok"
	    }
	    set id [string trim $id]
	    regexp {.*:([0-9]+)$} $id match id2
	    if {[string equal $id2 "0"]} {
		# Server error
		set errmsg "Server error $id"
	    }
	    if {![info exists metaArr(Content-Type)]} {
		# This is an invalid response.
		set errmsg "Missing Content-Type in HTTP header"
	    }
	    if {![string equal $metaArr(Content-Type) "text/xml"]} {
		# This is an invalid response.
		set errmsg "Content-Type in HTTP header is "
		append "\"$metaArr(Content-Type)\" expected \"text/xml\""
	    }
	    if {[string length $errmsg]} {
		if {[info exists opts(-command)]} {
		    uplevel #0 "$opts(-command) {$status $errmsg}"
		}
	    } else {
		set locals(id) $id
		
		set body [::http::data $token]
		
		# Send away to jabberlib for parsing and processing.
		if {[string length $body]} {
		    jlib::recv $jlibname $body
		}
	    }
	}
    }
}

# jlibhttp::poll --
#
#	We need to poll the server at (regular?) intervals to see if it has
#	got something for us.

proc jlibhttp::poll {} {
    
    variable locals
    variable opts
    
    # Send an empty POST request. Verify that we've sent our stream start.
    if {![string equal $locals(id) "0"]} {
	jlibhttp::send ""
    }
    
    # Reschedule next poll.
    set locals(pollid) [after $opts(-pollinterval) jlibhttp::send ""]]
}

#-------------------------------------------------------------------------------

