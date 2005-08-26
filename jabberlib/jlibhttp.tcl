#  jlibhttp.tcl ---
#  
#      Provides a http transport mechanism for jabberlib. 
#      
#  Copyright (c) 2002-2005  Mats Bengtsson
#
# $Id: jlibhttp.tcl,v 1.3 2005-08-26 15:02:34 matben Exp $
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
#	-resendinterval ms	if sending fails, try again after this interval
#	-timeout ms		timeout for connecting the server
#	-usekeys 0|1            if keys should be used
#
# Callbacks for the JabberLib:
#	jlib::http::transportinit, jlib::http::transportreset, 
#	jlib::http::send,          jlib::http::transportip
#

package require jlib
package require http 2.4
package require base64
package require sha1pure

package provide jlib::http 0.1

namespace eval jlib::http {

    # Inherit jlib's debug level.
    variable debug 4
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
	-keylength              16
	-maxpollms           10000
	-minpollms            4000
	-proxyhost              ""
	-proxyport            8080
	-proxyusername          ""
	-proxypasswd            ""
	-resendinterval      20000
	-timeout                 0
	-usekeys                 0
	header                  ""
	proxyheader             ""
	url                     ""
    }
    if {![regexp -nocase {^(([^:]*)://)?([^/:]+)(:([0-9]+))?(/.*)?$} $url \
      x prefix proto host y port filepath]} {
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
    transportreset $jlibname

    set seed [expr {abs([pid]+[clock clicks]%100000)}]
    expr {srand(int($seed))}

    $jlibname registertransport "http"    \
      [namespace current]::transportinit  \
      [namespace current]::send           \
      [namespace current]::transportreset \
      [namespace current]::transportip
    
    return
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
	
	# It seems that it is expected to have sha1 in binary format;
	# get from hex
	set hex [::sha1pure::sha1 $prevkey]
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
    
    puts "jlib::http::transportinit"

    transportreset $jlibname

    if {$opts(-usekeys)} {
	
	# Use keys from the end.
	set priv(keys) [NewKeySequence [NewSeed] $opts(-keylength)]
    }
}

# jlib::http::transportreset --
#
#	For the -transportreset command.

proc jlib::http::transportreset {jlibname} {

    upvar ${jlibname}::http::priv priv
    
    puts "jlib::http::transportreset"

    # Stop polling and resends.
    # catch {after cancel $priv(resendid)}
    if {[string length $priv(afterid)]} {
	catch {after cancel $priv(afterid)}
    }
    if {[info exists priv(token)]} {
	::http::reset $priv(token)
    }
    set priv(afterid)   ""
    set priv(xml)       ""
    set priv(id)        0
    set priv(first)     1
    set priv(postms)   -1
    set priv(ip)        ""
    set priv(lastpostms) [clock clicks -milliseconds]
    set priv(keys)      {}
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
    
    Debug 2 "jlib::http::send $xml"
    
    append priv(xml) $xml
    
    # If no post scheduled we shall post right away.
    if {![string length $priv(afterid)]} {
	puts "\t post right away"
	Post $jlibname
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
	    
	    puts "\t case A"
	    
	    # Case A:
	    # If next post is scheduled after min, then repost at min instead.
	    if {$priv(nextpostms) > $minms} {
		puts "\t reschedule post"
		set afterms [expr {$minms - $nowms}]
		SchedulePost $jlibname $afterms
	    }
	} else {
	    puts "\t case B"
	    
	    # Case B:
	    # We have already waited longer than '-minpollms'.
	    after cancel $priv(afterid)
	    set priv(afterid) ""
	    Post $jlibname
	}
    }
}

# jlib::http::SchedulePost --
# 
#       Schedule a post as a timer event.

proc jlib::http::SchedulePost {jlibname afterms} {
    
    upvar ${jlibname}::http::priv priv

    Debug 2 "jlib::http::SchedulePost afterms=$afterms"

    set nowms [clock clicks -milliseconds]
    set priv(afterms)    $afterms
    set priv(nextpostms) [expr {$nowms + $afterms}]
    set priv(postms)     [expr {$priv(nextpostms) - $priv(lastpostms)}]

    if {[string length $priv(afterid)]} {
	after cancel $priv(afterid)
    }
    set priv(afterid) [after $priv(afterms)  \
      [list [namespace current]::Post $jlibname]]
}

# jlib::http::Post --
# 
#       Just a wrapper for PostXML when sending xml.
       
proc jlib::http::Post {jlibname} {
    
    upvar ${jlibname}::http::priv priv

    Debug 2 "jlib::http::Post"
    
    set xml $priv(xml)
    set priv(xml)     ""
    set priv(afterid) ""
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

    if {$opts(-usekeys)} {
	
	# Administrate the keys. Pick from end until one left.
	set key [lindex $priv(keys) end]
	set priv(keys) [lrange $priv(keys) 0 end-1]

	# Need new key sequence?
	if {[llength $priv(keys)] == 0} {
	    set priv(keys) [NewKeySequence [NewSeed] $opts(-keylength)]
	    set newkey     [lindex $priv(keys) end]
	    set priv(keys) [lrange $priv(keys) 0 end-1]
	    set query "$priv(id);$key;$newkey,$xml"
	    puts "---------------------key change"
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
	    Finish $jlibname networkerror $msg
	    return
	}
    }
    
    Debug 2 "POST: $query"
    
    # -query forces a POST request.
    # Make sure we send it as text dispite the application/* type.???
    if {[catch {
	set token [::http::geturl $opts(url)  \
	  -binary  1                          \
	  -timeout $opts(-timeout)            \
	  -headers $opts(header)              \
	  -query   $query                     \
	  -command [list [namespace current]::Response $jlibname]]
    } msg]} {
	Debug 2 "\t post failed: $msg"
	Finish $jlibname networkerror $msg
    } else {
	set priv(lastpostms) [clock clicks -milliseconds]
	set priv(token) $token

	# Reschedule next post.	
	SchedulePost $jlibname $opts(-maxpollms)
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
    
    puts "jlib::http::Response entry"
    
    unset priv(token)
    
    # Trap any errors first.
    set status [::http::status $token]
    if {[string equal $status "reset"]} {
	return
    }
    
    # Either we've already made the connection to the server and have ip,
    # or we have to wait here which doesn't create any harm since already
    # a callback.
    if {$priv(first)} {
	set priv(first) 0
	if {$priv(wait)} {
	    vwait ${jlibname}::http::priv(wait)
	}
	if {[string length $priv(err)]} {
	    Finish $jlibname error $priv(err)
	    return
	}
    }
    
    Debug 2 "jlib::http::Response status=$status, [::http::ncode $token]"

    switch -- $status {
	ok {	    
	    if {[::http::ncode $token] != 200} {
		Finish $jlibname error [::http::ncode $token]
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
			Finish $jlibname error \
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
			    Finish $jlibname error $errmsg
			    return
			}
		    }
		    set haveCookie 1
		} elseif {[string equal -nocase $key "content-type"]} {
		    if {![string match -nocase "*text/xml*" $value]} {
			# This is an invalid response.
			set errmsg "Content-Type in HTTP header is "
			append "\"$value\" expected \"text/xml\""
			Finish $jlibname error $errmsg
			return
		    }
		    set haveContentType 1
		}
	    }
	    if {!$haveCookie} {
		Finish $jlibname error "missing Set-Cookie in HTTP header"
		return
	    }
	    if {!$haveContentType} {
		Finish $jlibname error "missing Content-Type in HTTP header"
		return
	    }
	    set priv(id) $id
	    
	    set body [::http::data $token]
	    Debug 2 "POLL: $body"
	    
	    # Send away to jabberlib for parsing and processing.
	    if {[string length $body]} {
		[namespace parent]::recv $jlibname $body
	    }
	}
	default {
	    Finish $jlibname $status [::http::error $token]
	}
    }
    
    # And cleanup after each post.
    ::http::cleanup $token
}

# jlib::http::Connect --
# 
#       One way to get our real ip number since we can't get it from 
#       the http package. Timout if any is handled by the http package.
#       May throw error!

proc jlib::http::Connect {jlibname} {
    
    upvar ${jlibname}::http::opts opts
    upvar ${jlibname}::http::priv priv
    
    puts "--->jlib::http::Connect"

    if {[string length $opts(-proxyhost)] && [string length $opts(-proxyport)]} {
	set host $opts(-proxyhost)
	set port $opts(-proxyport)
    } else {
	set host $opts(host)
	set port $opts(port)
    }
    set priv(err)  ""
    set priv(wait) 1
    set priv(sock) [socket -async $host $port]
    fileevent $priv(sock) writable [list [namespace current]::Writable $jlibname]
}

proc jlib::http::Writable {jlibname} {
    
    upvar ${jlibname}::http::priv priv
    
    puts "--->jlib::http::Writable"
    
    set s $priv(sock)
    if {[catch {eof $s} iseof] || $iseof} {
	set priv(err) "eof"	
    } elseif {[catch {
	set priv(ip) [lindex [fconfigure $s -sockname] 0]
	close $s
    }]} {
	set priv(err) "eof"
    }
    unset priv(sock)
    set priv(wait) 0    
}

# jlib::http::Finish --
# 
#       Only network errors and server errors are reported here.

proc jlib::http::Finish {jlibname status {errmsg ""}} {
    
    upvar ${jlibname}::http::priv priv

    Debug 2 "jlib::http::Finish status=$status, errmsg=$errmsg"
    
    if {[info exists priv(sock)]} {
	catch {close $priv(sock)}
    }
    
    # @@@ We should be more specific here.
    jlib::reporterror $jlibname networkerror $errmsg
}

proc jlib::http::Debug {num str} {
    variable debug
    if {$num <= $debug} {
	puts $str
    }
}

#-------------------------------------------------------------------------------

