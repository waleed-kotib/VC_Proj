#  jabberhttptransport.tcl ---
#  
#      Provides a http transport mechanism for jabberlib. 
#      
#  Copyright (c) 2002-2004  Mats Bengtsson
#
# $Id: jabberhttptransport.tcl,v 1.3 2004-06-30 08:52:40 matben Exp $
# 
# USAGE ########################################################################
#
# jlib::http::new jlibname url ?-key value ...?
#	url 	A valid url for the POST method of HTTP.
#	
#	-command callback	a tcl procedure of the form 'callback {status message}
#       -keylength              if > 0 use key sequence of this length
#	-maxpollms ms	        max interval in ms for post requests
#	-minpollms ms	        min interval in ms for post requests
#       -proxyhost domain	name of proxu host if any
#       -proxyport integer	and its port number
#	-proxyusername name	your username for the proxy
#	-proxypasswd secret	and your password
#	-resendinterval ms	if sending fails, try again after this interval
#	-timeout ms		timeout for connecting the server
#
# Callbacks for the JabberLib:
#	jlib::http::transportinit, jlib::http::transportreset, jlib::http::send
#
#

package require jlib
package require http 2.3
package require base64
package require sha1pure

package provide jlibhttp 0.1

namespace eval jlib::http {

    # All non-options should be in this array.
    variable priv

    variable debug 2
    variable errcode
    array set errcode {
	0       "unknown error"
	-1      "server error"
	-2      "bad request"
	-3      "key sequence error"
    }
}

# jlib::http::new --
#
#	Configures the state of this thing.

proc jlib::http::new {jlibname url args} {

    variable opts
    variable priv
    
    Debug 2 "jlib::http::new url=$url, args=$args"

    array set opts {
	-keylength               0
	-maxpollms           10000
	-minpollms            4000
	-proxyhost              ""
	-proxyport            8080
	-proxyusername          ""
	-proxypasswd            ""
	-resendinterval      20000
	-timeout                 0
	header                  ""
	proxyheader             ""
	url                     ""
    }
    if {![regexp -nocase {^(([^:]*)://)?([^/:]+)(:([0-9]+))?(/.*)?$} $url \
      x prefix proto host y port filepath]} {
	return -code error "The url \"$url\" is not valid"
    }
    set opts(jlibname)        $jlibname
    set opts(url)             $url
    array set opts $args

    set priv(id)              0
    set priv(afteridpost)     ""
    set priv(afteridpoll)     ""

    if {[string length $opts(-proxyhost)] && [string length $opts(-proxyport)]} {
   	::http::config -proxyhost $opts(-proxyhost) -proxyport $opts(-proxyport)
    }
    if {[string length $opts(-proxyusername)] || \
	[string length $opts(-proxypasswd)]} {
	set opts(proxyheader) [BuildProxyHeader  \
	  $opts(-proxyusername) $opts(-proxypasswd)]
    }
    set opts(header) $opts(proxyheader)
    
    # Initialize.
    transportreset
}

# jlib::http::BuildProxyHeader --
#
#	Builds list for the "Proxy-Authorization" header line.

proc jlib::http::BuildProxyHeader {proxyusername proxypasswd} {
    
    set str $proxyusername:$proxypasswd
    set auth [list "Proxy-Authorization" \
      "Basic [base64::encode [encoding convertto $str]]"]
    return $auth
}

proc jlib::http::NewSeed { } {
    
    set num [expr int(10000000 * rand())]
    return [format %0x $num]
}

proc jlib::http::NewKeySequence {seed len} {

    set keys    $seed
    set prevkey $seed
    
    for {set i 1} {$i < $len} {incr i} {
	set key [::base64::encode [::sha1pure::sha1 $prevkey]]
	lappend keys $key
	set prevkey $key
    }
    return $keys
}

# jlib::http::transportinit --
#
#	For the -transportinit command.

proc jlib::http::transportinit { } {

    set priv(afteridpost) ""
    set priv(afteridpoll) ""
    set priv(xml)         ""
    set priv(id)          0
    set priv(lastsecs)    [clock scan "1 hour ago"]
    transportreset
}

# jlib::http::transportreset --
#
#	For the -transportreset command.

proc jlib::http::transportreset { } {

    variable priv

    # Stop polling and resends.
    catch {after cancel $priv(resendid)}
    if {[string length $priv(afteridpost)]} {
	catch {after cancel $priv(afteridpost)}
    }
    if {[string length $priv(afteridpoll)]} {
	catch {after cancel $priv(afteridpoll)}
    }
}

# jlib::http::send --
#
#	For the -transportsend command.

proc jlib::http::send {xml} {
    
    variable opts
    variable priv
    
    Debug 2 "jlib::http::send"
    
    append priv(xml) $xml
    
    # Cancel any scheduled poll.
    if {[string length $priv(afteridpoll)]} {
	after cancel $priv(afteridpoll)
    }

    # If we don't have a scheduled post,
    # and time to previous post is larger than minumum, do post now.
    if {($priv(afteridpost) == "") && \
      [expr [clock seconds] - $priv(lastsecs) > 1000 * $opts(-minpollms)]} {
	PostScheduled
    }
}

# jlib::http::PostScheduled --
# 
#       Just a wrapper for Post when sending xml.
       
proc jlib::http::PostScheduled { } {
    
    variable priv

    Debug 2 "jlib::http::PostScheduled"
    
    Post $priv(xml)
    set priv(xml) ""
    set priv(afteridpost) ""
}

# jlib::http::Post --
# 
#       Do actual posting with (any) xml to send.
       
proc jlib::http::Post {xml} {
    
    variable opts
    variable priv

    Debug 2 "jlib::http::Post"

    set qry "$priv(id),$xml"
    
    # -query forces a POST request.
    # Make sure we send it as text dispite the application/* type.???
    if {[catch {
	set token [::http::geturl $opts(url)  \
	  -timeout $opts(-timeout)  \
	  -query $qry \
	  -headers $opts(header) \
	  -command [namespace current]::HttpResponse]
    } msg]} {
	#set priv(resendid) [after $opts(-resendinterval) \
	#  [namespace current]::send $xml]]
    } else {
	set priv(lastsecs) [clock seconds]
	
	# Reschedule next poll.
	set priv(afteridpoll) [after $opts(-maxpollms) \
	  [namespace current]::Poll
    }
}

# jlib::http::Poll --
#
#	We need to poll the server at (regular?) intervals to see if it has
#	got something for us.

proc jlib::http::Poll { } {
    
    variable priv
    variable opts
    
    # Send an empty POST request. Verify that we've sent our stream start.
    if {![string equal $priv(id) "0"]} {
	Post ""
    }
    
    # Reschedule next poll.
    set priv(afteridpoll) [after $opts(-maxpollms) [namespace current]::Poll]]
}

# jlib::http::HttpResponse --
#
#	The response to our POST request. Parse any indata that should
#	be of mime type text/xml

proc jlib::http::HttpResponse {token} {

    upvar #0 $token state
    variable priv
    variable opts
    variable errcode
    
    # Trap any errors first.
    set status [::http::status $token]
    Debug 2 "jlib::http::HttpResponse status=$status"
    
    switch -- $status {
	error - timeout - reset {
	    if {[info exists opts(-command)]} {
		uplevel #0 $opts(-command) {$status [httpex::error $token]}
	    }
	}
	ok {
	    
	    if {[::http::ncode $token] != 200} {
		
		
		return
	    }
	    
	    # Extract the 'id' from the Set-Cookie key.
	    array set metaArr $state(meta)
	    set errmsg ""
	    if {![info exists metaArr(Set-Cookie)]} {
		# This is an invalid response.
		append errmsg " Missing Set-Cookie in HTTP header."
	    }
	    
	    # Parse the cookie.
	    array set cookieArr [split $metaArr(Set-Cookie) ;=]
	    if {![info exists cookieArr(ID)]} {
		append errmsg " Missing ID in Set-Cookie"
	    }
	    if {![regexp -nocase {ID=([0-9a-zA-Z:\-]+).*}  \
	      $metaArr(Set-Cookie) match id]} {
		# This is an invalid response.
		set errmsg "Set-Cookie in HTTP header \"$metaArr(Set-Cookie)\""
		append errmsg " is not ok"
	    }
	    set id  [string trim $id]
	    set id2 [lindex [split $id :] end]
	    if {[string equal $id2 "0"]} {
		# Server error
		set code [lindex [split $id :] 0]
		if {[info exists errcode($code)]} {
		    set errmsg $errcode($code)
		} else {
		    set errmsg "Server error $id"
		}
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
		    uplevel #0 $opts(-command) [list $status $errmsg]
		}
	    } else {
		set priv(id) $id
		
		set body [::http::data $token]
		
		# Send away to jabberlib for parsing and processing.
		if {[string length $body]} {
		    [namespace parent]::recv $opts(jlibname) $body
		}
	    }
	}
    }
    ::http::cleanup $token
}

proc jlib::http::Debug {num str} {
    variable debug
    if {$num <= $debug} {
	puts $str
    }
}

#-------------------------------------------------------------------------------

