# jlibhttp.tcl ---
#  
#      Provides a http transport mechanism for jabberlib. 
#      
# Copyright (c) 2002-2005  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#
# $Id: jlibhttp.tcl,v 1.15 2007-07-19 06:28:17 matben Exp $
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
#                 "wait"      http post made, waiting for response
#                 "error"     error status

# TODO: more flexible posting (from Response?) that dynamically schedules
#       the timing interval.

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
	proxyheader             ""
	url                     ""
	pollupfactor           0.8
	polldownfactor         1.2
    }
    if {![regexp -nocase {^(([^:]*)://)?([^/:]+)(:([0-9]+))?(/.*)?$} $url \
      - prefix proto host - port filepath]} {
	return -code error "the url \"$url\" is not valid"
    }
    set opts(url)  $url
    set opts(host) $host
    set opts(port) $port
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

    set priv(state)      ""
    set priv(status)     ""
    
    set priv(afterid)    ""
    set priv(xml)        ""
    set priv(id)         0
    set priv(first)      1
    set priv(postms)    -1
    set priv(ip)         ""
    set priv(lastpostms) [clock clicks -milliseconds]
    set priv(keys)       {}
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
    
    # Stop polling and resends.
    if {[string length $priv(afterid)]} {
	catch {after cancel $priv(afterid)}
    }
    set priv(afterid) ""
    set priv(state)   "reset"
    
    # If we have got cached xml to send must post it now and ignore response.
    if {[string length $priv(xml)] > 2} {
	Post $jlibname
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
    
    # If no post scheduled we shall post right away.
    if {![string length $priv(afterid)]} {
	Post $jlibname
    } else {
	
	# Else post as soon as possible.
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
    set priv(afterms)    $afterms
    set priv(nextpostms) [expr {$nowms + $afterms}]
    set priv(postms)     [expr {$priv(nextpostms) - $priv(lastpostms)}]

    if {[string length $priv(afterid)]} {
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
    
    # If this is the first post do a dummy parallell connection to find out ip.
    if {$priv(first)} {
	if {[catch {Connect $jlibname} msg]} {
	    Debug 2 "\t Connect failed: $msg"
	    Error $jlibname networkerror $msg
	    return
	}
    }
    set priv(status) "wait"
    if {[string equal $priv(state) "reset"]} {
	set cmdProc [namespace current]::NoopResponse
    } else {
	set cmdProc [list [namespace current]::Response $jlibname]
    }
    
    Debug 2 "POST: $query"
    
    # -query forces a POST request.
    # Make sure we send it as text dispite the application/* type.???
    if {[catch {
	set token [::http::geturl $opts(url)  \
	  -timeout $opts(-timeout)            \
	  -headers $opts(header)              \
	  -query   $query                     \
	  -command $cmdProc]
    } msg]} {
	Debug 2 "\t post failed: $msg"
	Error $jlibname networkerror $msg
    } else {
	set priv(lastpostms) [clock clicks -milliseconds]
	set priv(token) $token

	# Reschedule next post unless 'reset'.
	# Always keep a scheduled post at 'maxpollms' (or something else),
	# and let any subsequent events reschedule if at an earlier time.
	if {[string equal $priv(state) "instream"]} {
	    #SchedulePost $jlibname $opts(-maxpollms)
	    SchedulePost $jlibname maxpollms
	}
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
    
    # Either we've already made the connection to the server and have ip,
    # or we have to wait here which doesn't create any harm since already
    # a callback.
    if {$priv(first)} {
	set priv(first) 0
	if {$priv(dum,wait)} {
	    vwait ${jlibname}::http::priv(dum,wait)
	}
	if {[string length $priv(dum,err)]} {
	    Error $jlibname error $priv(dum,err)
	    return
	}
    }
    set status [::http::status $token]
    
    Debug 2 "\t status=$status, ::http::ncode=[::http::ncode $token]"

    switch -- $status {
	ok {	    
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
		    if {![string match -nocase "*text/xml*" $value]} {
			# This is an invalid response.
			set errmsg "Content-Type in HTTP header is "
			append "\"$value\" expected \"text/xml\""
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
	    
	    set body [::http::data $token]
	    Debug 2 "POLL: $body"
	    
	    # Send away to jabberlib for parsing and processing.
	    if {[string length $body] > 2} {
		[namespace parent]::recv $jlibname $body
	    }
	    
	    # Reschedule at minpollms.
	    if {[string length $body] > 2} {
		PostASAP $jlibname
	    }	    
	}
	default {
	    Error $jlibname $status [::http::error $token]
	    return
	}
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

# jlib::http::Connect --
# 
#       Initiates a dummy server connection.
#       One way to get our real ip number since we can't get it from 
#       the http package. Timout if any is handled by the http package.
#       May throw error!

proc jlib::http::Connect {jlibname} {
    
    upvar ${jlibname}::http::opts opts
    upvar ${jlibname}::http::priv priv
    
    if {[string length $opts(-proxyhost)] && [string length $opts(-proxyport)]} {
	set host $opts(-proxyhost)
	set port $opts(-proxyport)
    } else {
	set host $opts(host)
	set port $opts(port)
    }
    set priv(dum,err)  ""
    set priv(dum,wait) 1
    set s [socket -async $host $port]
    set priv(dum,sock) $s
    fileevent $s writable [list [namespace current]::Writable $jlibname]
}

proc jlib::http::Writable {jlibname} {
    
    upvar ${jlibname}::http::priv priv
        
    set s $priv(dum,sock)
    if {[catch {eof $s} iseof] || $iseof} {
	set priv(dum,err) "eof"	
    } elseif {[catch {
	set priv(ip) [lindex [fconfigure $s -sockname] 0]
	close $s
    }]} {
	set priv(dum,err) "eof"
    }
    unset priv(dum,sock)
    set priv(dum,wait) 0    
}

# jlib::http::Error --
# 
#       Only network errors and server errors are reported here.

proc jlib::http::Error {jlibname status {errmsg ""}} {
    
    upvar ${jlibname}::http::priv priv

    Debug 2 "jlib::http::Error status=$status, errmsg=$errmsg"
    
    set priv(status) "error"
    if {[info exists priv(dum,sock)]} {
	catch {close $priv(dum,sock)}
    }
    if {[info exists priv(token)]} {
	::http::cleanup $priv(token)
	unset priv(token)
    }
    
    # @@@ We should perhaps be more specific here.
    jlib::reporterror $jlibname networkerror $errmsg
}

proc jlib::http::Debug {num str} {
    variable debug
    if {$num <= $debug} {
	puts $str
    }
}

#-------------------------------------------------------------------------------

