# jlibhttp.tcl ---
#  
#      Provides a http transport mechanism for jabberlib. 
#      Implements the deprecated XEP-0025: Jabber HTTP Polling protocol.
#      
# Copyright (c) 2002-2008  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#
# $Id: jlibhttp.tcl,v 1.21 2008-02-29 12:55:36 matben Exp $
# 
# USAGE ########################################################################
#
# jlib::http::new jlibname url ?-key value ...?
#	url 	A valid url for the POST method of HTTP.
#	
#       -keylength              sets the length of the key sequence
#	-maxpollms ms	        max interval in ms for post requests
#	-minpollms ms	        min interval in ms for post requests
#       -proxyhost domain	name of proxu host if any
#       -proxyport integer	and its port number
#	-proxyusername name	your username for the proxy
#	-proxypasswd secret	and your password
#	(-resendinterval ms	if sending fails, try again after this interval)
#	-timeout ms		timeout for connecting the server
#	-usekeys 0|1            if keys should be used
#
# Although you can use the -proxy* switches here, it is much simpler to let
# the autoproxy package configure them.
#
# Callbacks for the JabberLib:
#	jlib::http::transportinit, jlib::http::transportreset, 
#	jlib::http::send,          jlib::http::transportip
#
# STATES #######################################################################
# 
# priv(state):    ""          inactive and not reset
#                 "instream"  active connection
#                 "reset"     reset by callback
# 
# priv(status):   ""          inactive
#                 "scheduled" http post is scheduled as timer event
#                 "pending"   http post made, waiting for response
#                 "error"     error status

package require jlib
package require http 2.4
package require base64
package require sha1

package provide jlib::http 0.1

namespace eval jlib::http {
    
    # Check for the TLS package so we can use https.
    if {![catch {package require tls}]} {
	http::register https 443 ::tls::socket
    }

    # Inherit jlib's debug level.
    variable debug 0
    if {!$debug} {
	set debug [namespace parent]::debug
    }
    variable errcode
    array set errcode {
	0       "unknown error"
       -1       "server error"
       -2       "bad request"
       -3       "key sequence error"
    }
}

# jlib::http::new --
#
#	Configures the state of this thing.

proc jlib::http::new {jlibname url args} {

    namespace eval ${jlibname}::http {
	variable priv
	variable opts
    }
    upvar ${jlibname}::http::priv priv
    upvar ${jlibname}::http::opts opts
    
    Debug 2 "jlib::http::new url=$url, args=$args"

    array set opts {
	-keylength              64
	-maxpollms           16000
	-minpollms            4000
	-proxyhost              ""
	-proxyport              80
	-proxyusername          ""
	-proxypasswd            ""
	-resendinterval      20000
	-timeout             30000
	-usekeys                 1
	header                  ""
	port                    80
	proxyheader             ""
	url                     ""
	pollupfactor           0.8
	polldownfactor         1.2
    }
    set RE {^(([^:]*)://)?([^/:]+)(:([0-9]+))?(/.*)?$}
    if {![regexp -nocase $RE $url - prefix proto host - port filepath]} {
	return -code error "the url \"$url\" is not valid"
    }
    set opts(url)  $url
    set opts(host) $host
    if {$port ne ""} {
	set opts(port) $port
    }
    array set opts $args

    set priv(id)      0
    set priv(afterid) ""

    # Perhaps the autoproxy package can be used here?
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
    InitState $jlibname

    $jlibname registertransport "http"    \
      [namespace current]::transportinit  \
      [namespace current]::send           \
      [namespace current]::transportreset \
      [namespace current]::transportip
    
    return
}

# jlib::http::InitState --
# 
#       Sets initial state of 'priv' array.

proc jlib::http::InitState {jlibname} {
    
    upvar ${jlibname}::http::priv priv
    upvar ${jlibname}::http::opts opts

    set ms [clock clicks -milliseconds]
    
    set priv(state)       ""
    set priv(status)      ""
    
    set priv(afterid)     ""
    set priv(xml)         ""
    set priv(lastxml)     ""     ; # Last posted xml.
    set priv(id)          0
    set priv(first)       1
    set priv(first)       0
    set priv(postms)     -1
    set priv(ip)          ""
    set priv(lastpostms)  $ms
    set priv(2lastpostms) $ms
    set priv(keys)        {}
    if {$opts(-usekeys)} {
	set priv(keys) [NewKeySequence [NewSeed] $opts(-keylength)]
    }
}

# jlib::http::BuildProxyHeader --
#
#	Builds list for the "Proxy-Authorization" header line.

proc jlib::http::BuildProxyHeader {proxyusername proxypasswd} {
    
    set str $proxyusername:$proxypasswd
    set auth [list "Proxy-Authorization" "Basic [base64::encode $str]"]
    return $auth
}

proc jlib::http::NewSeed { } {
    set MAX_INT 0x7FFFFFFF    
    set num [expr {int($MAX_INT*rand())}]
    return [format %0x $num]
}

proc jlib::http::NewKeySequence {seed len} {

    set keys    $seed
    set prevkey $seed
    
    for {set i 1} {$i < $len} {incr i} {
	
	# It seems that it is expected to have sha1 in binary format;
	# get from hex
	set hex [::sha1::sha1 $prevkey]
	set key [::base64::encode [binary format H* $hex]]
	lappend keys $key
	set prevkey $key
    }
    return $keys
}

# jlib::http::transportinit --
#
#	For the -transportinit command.

proc jlib::http::transportinit {jlibname} {

    upvar ${jlibname}::http::priv priv
    upvar ${jlibname}::http::opts opts
    
    InitState $jlibname
}

# jlib::http::transportreset --
#
#	For the -transportreset command.

proc jlib::http::transportreset {jlibname} {

    upvar ${jlibname}::http::priv priv
  
    Debug 2 "jlib::http::transportreset"

    # Stop polling and resends.
    if {$priv(afterid) ne ""} {
	catch {after cancel $priv(afterid)}
    }
    set priv(afterid) ""
    set priv(state)   "reset"
    set priv(ip)      ""
    
    # If we have got cached xml to send must post it now and ignore response.
    if {[string length $priv(xml)] > 2} {
	Post $jlibname
    }
    if {[info exists priv(token)]} {
	::http::reset $priv(token)
	::http::cleanup $priv(token)
	unset priv(token)
    }
}

# jlib::http::transportip --
# 
#       Get our own ip address.
#       @@@ If proxy we have the usual firewall problem!

proc jlib::http::transportip {jlibname} {
    
    upvar ${jlibname}::http::priv priv

    return $priv(ip)
}

# jlib::http::send --
#
#	For the -transportsend command.

proc jlib::http::send {jlibname xml} {
    
    upvar ${jlibname}::http::priv priv
    upvar ${jlibname}::http::opts opts
    
    Debug 2 "jlib::http::send state='$priv(state)' $xml"

    # Cancel if already 'reset'.
    if {[string equal $priv(state) "reset"]} {
	return
    }
    set priv(state) "instream"
    
    append priv(xml) $xml
    
    # If this is our first post we shall post right away.
    if {$priv(status) eq ""} {
	Post $jlibname

	# Unless we already have a pending event, post as soon as possible.
    } elseif {$priv(status) ne "pending"} {
	PostASAP $jlibname
    }
}

# jlib::http::PostASAP --
# 
#       Make a post as soon as possible without taking 'minpollms' as the
#       constraint. If we have waited longer than 'minpollms' post right away,
#       else reschedule if necessary to post at 'minpollms'.

proc jlib::http::PostASAP {jlibname} {
    
    upvar ${jlibname}::http::priv priv
    upvar ${jlibname}::http::opts opts
    
    Debug 2 "jlib::http::PostASAP"
    
    if {$priv(afterid) eq ""} {
	SchedulePost $jlibname minpollms
    } else {
	
	#        now (case A)         now (case B)
	#           |                    |
	#  ---------------------------------------------------> time
	#   |                 ->|                       ->|
	# last post            min                       max
	
	# We shall always use '-minpollms' when there is something to send.
	set nowms [clock clicks -milliseconds]
	set minms [expr {$priv(lastpostms) + $opts(-minpollms)}]
	if {$nowms < $minms} {
	    
	    # Case A:
	    # If next post is scheduled after min, then repost at min instead.
	    if {$priv(nextpostms) > $minms} {
		SchedulePost $jlibname minpollms
	    }
	} else {
	    
	    # Case B:
	    # We have already waited longer than '-minpollms'.
	    after cancel $priv(afterid)
	    set priv(afterid) ""
	    Post $jlibname
	}
    }
}

# jlib::http::Schedule --
#
#       Computes the time for the next post and calls SchedulePost.

proc jlib::http::Schedule {jlibname} {
    
    upvar ${jlibname}::http::priv priv
    upvar ${jlibname}::http::opts opts
    
    Debug 2 "jlib::http::Schedule len priv(lastxml)=[string length $priv(lastxml)]"
    
    # Compute time for next post.
    set ms [clock clicks -milliseconds]
    if {$priv(lastxml) eq ""} {
	set when [expr {$opts(polldownfactor) * ($ms - $priv(2lastpostms))}]
	set when [Min $when $opts(-maxpollms)]
	set when [Max $when $opts(-minpollms)]
    } else {
	set when minpollms
    }
    
    # Reschedule next post unless 'reset'.
    # Always keep a scheduled post at 'maxpollms' (or something else),
    # and let any subsequent events reschedule if at an earlier time.
    if {[string equal $priv(state) "instream"]} {
	SchedulePost $jlibname $when
    }
}

# jlib::http::SchedulePost --
# 
#       Schedule a post as a timer event.

proc jlib::http::SchedulePost {jlibname when} {
    
    upvar ${jlibname}::http::priv priv
    upvar ${jlibname}::http::opts opts

    Debug 2 "jlib::http::SchedulePost when=$when"

    set nowms [clock clicks -milliseconds]

    switch -- $when {
	minpollms {
	    set minms [expr {$priv(lastpostms) + $opts(-minpollms)}]
	    set afterms [expr {$minms - $nowms}]
	}
	maxpollms {
	    set maxms [expr {$priv(lastpostms) + $opts(-maxpollms)}]
	    set afterms [expr {$maxms - $nowms}]
	}
	default {
	    set afterms $when
	}
    }
    if {$afterms < 0} {
	set afterms 0
    }
    set priv(afterms)    [expr int($afterms)]
    set priv(nextpostms) [expr {$nowms + $afterms}]
    set priv(postms)     [expr {$priv(nextpostms) - $priv(lastpostms)}]

    if {$priv(afterid) ne ""} {
	after cancel $priv(afterid)
    }
    set priv(status) "scheduled"
    set priv(afterid) [after $priv(afterms)  \
      [list [namespace current]::Post $jlibname]]
}

# jlib::http::Post --
# 
#       Just a wrapper for PostXML when sending xml.
       
proc jlib::http::Post {jlibname} {
    
    upvar ${jlibname}::http::priv priv

    Debug 2 "jlib::http::Post"
    
    # If called directly any timers must have been cancelled before this.
    set priv(afterid) ""
    set xml $priv(xml)
    set priv(xml) ""
    PostXML $jlibname $xml
}

# jlib::http::PostXML --
# 
#       Do actual posting with (any) xml to send.
#       Always called from 'Post'.
       
proc jlib::http::PostXML {jlibname xml} {
    
    upvar ${jlibname}::http::priv priv
    upvar ${jlibname}::http::opts opts
    
    Debug 2 "jlib::http::PostXML"
    
    set xml [encoding convertto utf-8 $xml]

    if {$opts(-usekeys)} {
	
	# Administrate the keys. Pick from end until no left.
	set key [lindex $priv(keys) end]
	set priv(keys) [lrange $priv(keys) 0 end-1]

	# Need new key sequence?
	if {[llength $priv(keys)] == 0} {
	    set priv(keys) [NewKeySequence [NewSeed] $opts(-keylength)]
	    set newkey     [lindex $priv(keys) end]
	    set priv(keys) [lrange $priv(keys) 0 end-1]
	    set query "$priv(id);$key;$newkey,$xml"
	    Debug 4 "\t key change"
	} else {
	    set query "$priv(id);$key,$xml"
	}
    } else {
	set query "$priv(id),$xml"
    }
    set priv(status) "pending"
    if {[string equal $priv(state) "reset"]} {
	set cmdProc [namespace current]::NoopResponse
    } else {
	set cmdProc [list [namespace current]::Response $jlibname]
    }
    set progProc [list [namespace current]::Progress $jlibname]
    
    Debug 2 "POST: $query"
    
    # -query forces a POST request.
    # Make sure we send it as text dispite the application/* type.???
    if {[catch {
	set token [::http::geturl $opts(url)   \
	  -timeout  $opts(-timeout)            \
	  -headers  $opts(header)              \
	  -query    $query                     \
	  -queryprogress $progProc             \
	  -command  $cmdProc]
    } msg]} {
	# @@@ We could have a method here to retry a number of times before
	#     giving up.
	Debug 2 "\t post failed: $msg"
	Error $jlibname networkerror $msg
    } else {
	set priv(token) $token
	set priv(lastxml) $xml
	set priv(2lastpostms) $priv(lastpostms)
	set priv(lastpostms) [clock clicks -milliseconds]
    }
}

# jlib::http::Progress --
# 
#       Only useful the first post to get socket and our own IP.

proc jlib::http::Progress {jlibname token args} {
    
    upvar ${jlibname}::http::priv priv

    if {$priv(ip) eq ""} {
	# @@@ When we switch to httpex we will add a method for this.
	set s [set $token\(sock)]
	set priv(ip) [lindex [fconfigure $s -sockname] 0]
    }
}

# jlib::http::Response --
#
#	The response to our POST request. Parse any indata that should
#	be of mime type text/xml

proc jlib::http::Response {jlibname token} {
    
    upvar #0 $token state
    upvar ${jlibname}::http::priv priv
    upvar ${jlibname}::http::opts opts
    variable errcode
    
    Debug 2 "jlib::http::Response priv(state)=$priv(state)"
    
    # We may have been 'reset' after this post was sent!
    if {[string equal $priv(state) "reset"]} {
	return
    }
    set status [::http::status $token]
    
    Debug 2 "\t status=$status, ::http::ncode=[::http::ncode $token]"
    
    if {$status eq "ok"} {
	if {[::http::ncode $token] != 200} {
	    Error $jlibname error [::http::ncode $token]
	    return
	}	    
	set haveCookie 0
	set haveContentType 0
	
	foreach {key value} $state(meta) {
	    
	    if {[string equal -nocase $key "set-cookie"]} {
		
		# Extract the 'ID' from the Set-Cookie key.
		foreach pair [split $value ";"] {
		    set pair [string trim $pair]
		    if {[string equal -nocase -length 3 "ID=" $pair]} {
			set id [string range $pair 3 end]
			break
		    }
		}
		
		if {![info exists id]} {
		    Error $jlibname error \
		      "Set-Cookie in HTTP header \"$value\" invalid"
		    return
		}
		
		# Invesitigate the ID:
		set ids [split $id :]
		if {[llength $ids] == 2} {
		    
		    # Any identifier that ends in ':0' indicates an error.
		    if {[string equal [lindex $ids 1] "0"]} {
			
			#   ID=0:0  Unknown Error. The response body can 
			#           contain a textual error message. 
			#   ID=-1:0 Server Error.
			#   ID=-2:0 Bad Request.
			#   ID=-3:0 Key Sequence Error .
			set code [lindex $ids 0]
			if {[info exists errcode($code)]} {
			    set errmsg $errcode($code)
			} else {
			    set errmsg "Server error $id"
			}
			Error $jlibname error $errmsg
			return
		    }
		}
		set haveCookie 1
	    } elseif {[string equal -nocase $key "content-type"]} {
		
		# Responses from the server have Content-Type: text/xml. 
		# Both the request and response bodies are UTF-8       
		# encoded text, even if an HTTP header to the contrary 
		# exists. 
		# ejabberd: Content-Type {text/plain; charset=utf-8}
		
		set typeOK 0
		if {[string match -nocase "*text/xml*" $value]} {
		    set typeOK 1
		} elseif {[regexp -nocase { *text/plain; *charset=utf-8} $value]} {
		    set typeOK 1
		}
		
		if {!$typeOK} {
		    # This is an invalid response.
		    set errmsg "Content-Type in HTTP header is "
		    append errmsg $value
		    append errmsg " expected \"text/xml\" or \"text/plain\""
		    Error $jlibname error $errmsg
		    return
		}
		set haveContentType 1
	    }
	}
	if {!$haveCookie} {
	    Error $jlibname error "missing Set-Cookie in HTTP header"
	    return
	}
	if {!$haveContentType} {
	    Error $jlibname error "missing Content-Type in HTTP header"
	    return
	}
	set priv(id) $id
	set priv(lastxml) ""	
	set body [::http::data $token]
	Debug 2 "POLL: $body"
	
	# Send away to jabberlib for parsing and processing.
	if {[string length $body] > 2} {
	    [namespace parent]::recv $jlibname $body
	}
	
	# Reschedule new POST.
	# NB: We always rescedule from the POST callback to avoid queuing
	#     up requests which can distort the order and make a 
	#     'key sequence error'
	if {[string length $body] > 2} {
	    SchedulePost $jlibname minpollms
	} else {
	    Schedule $jlibname
	}
    } else {
	
	# @@@ We could have a method here to retry a number of times before
	#     giving up.
	Error $jlibname $status [::http::error $token]
	return
    }
    
    # And cleanup after each post.
    ::http::cleanup $token
    unset priv(token)
}

# jlib::http::NoopResponse --
# 
#       This shall be used when we flush out any xml after a 'reset' and
#       don't expect any further actions to be taken.

proc jlib::http::NoopResponse {token} {

    Debug 2 "jlib::http::NoopResponse"

    # Only thing we shall do here.
    ::http::cleanup $token
}

# jlib::http::Error --
# 
#       Only network errors and server errors are reported here.

proc jlib::http::Error {jlibname status {errmsg ""}} {
    
    upvar ${jlibname}::http::priv priv

    Debug 2 "jlib::http::Error status=$status, errmsg=$errmsg"
    
    set priv(status) "error"
    if {[info exists priv(token)]} {
	::http::cleanup $priv(token)
	unset priv(token)
    }
    
    # @@@ We should perhaps be more specific here.
    jlib::reporterror $jlibname networkerror $errmsg
}

proc jlib::http::Min {x y} {
    return [expr {$x <= $y ? $x : $y}]
}

proc jlib::http::Max {x y} {
    return [expr {$x >= $y ? $x : $y}]
}

proc jlib::http::Debug {num str} {
    variable debug
    if {$num <= $debug} {
	puts $str
    }
}

#-------------------------------------------------------------------------------

