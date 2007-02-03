#  connect.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides a high level method to handle all the things to establish
#      a connection with a jabber server and do TLS, SASL, and authentication.
#      
#  Copyright (c) 2006-2007  Mats Bengtsson
#  
# $Id: connect.tcl,v 1.22 2007-02-03 06:42:06 matben Exp $
# 
############################# USAGE ############################################
#
#   jlib::connect::configure ?options?
#   jlibname connect connect jid password ?options?     (constructor)
#   jlibname connect reset
#   jlibname connect register jid password
#   jlibname connect auth
#   jlibname connect free                               (destructor)
#
#### EXECUTION PATHS ###########################################################
# 
#  sections:                                      callback status:
# 
#       o dns lookup (optional)                         dnsresolve
#       o transport                                     initnetwork
#       o initialize xmpp stream                        initstream
#       o start tls (optional)                          starttls
#       o stream compression (untested)                 startcompress
#       o sasl authentication (or digest or plain)      authenticate
#       o final                                         ok | error 
# 
#   error tokens:
#   
#       no-stream-id
#       no-stream-version-1
#       network-failure
#       tls-failure
#       starttls-nofeature
#       starttls-failure
#       starttls-protocol-error
#       sasl-no-mechanisms
#       sasl-protocol-error
#       
#       All SASL error elements according to RFC 3920 (XMPP Core)
#       not-authorized    being the most common
#       
#       xmpp-streams-error
#       
#       And all stream error tags as defined in "4.7.3.  Defined Conditions"
#       in RFC 3920 (XMPP Core) as:
#       xmpp-streams-error-TheTagName
#       
### From: XEP-0170: Recommended Order of Stream Feature Negotiation ############
#
#   The XMPP RFCs define an ordering for the features defined therein, namely: 
#       0.  TLS 
#       1.  SASL 
#       2.  Resource binding 
#       3.  IM session establishment 
#       
#   Using Stream Compression:
#       0.  TLS 
#       1.  SASL 
#       2.  Stream compression
#       3.  Resource binding 
#       4.  IM session establishment 
#       

package require jlib
package require sha1
package require autosocks       ;# wrapper for the 'socket' command.

package provide jlib::connect 0.1

namespace eval jlib::connect {
    
    variable inited 0
    variable have
    variable debug 0
}

proc jlib::connect::init {jlibname} {
    variable inited

    if {!$inited} {
	init_static
    }
}

proc jlib::connect::cmdproc {jlibname cmd args} {
        
    # Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

proc jlib::connect::init_static {} {
    variable inited
    variable have
    
    debug "jlib::connect::init_static"
    
    # Loop through all packages we may need.
    foreach name {
	tls        jlibsasl        jlibtls  
	jlib::dns  jlib::compress  jlib::http
    } {
	set have($name) 0
	if {![catch {package require $name}]} {
	    set have($name) 1
	}	
    }
    
    # -method: ssl | tlssasl | sasl
    # -transport tcp | http  ???

    # Default options.
    variable options
    array set options {
	-command          ""
	-compress         0
	-defaulthttpurl   http://%h:5280/http-poll/
	-defaultport      5222
	-defaultresource  "default"
	-defaultsslport   5223
	-digest           1
	-dnsprotocol      udp
	-dnssrv           1
	-dnstxthttp       1
	-dnstimeout       3000
	-http             0
	-httpurl          ""
	-ip               ""
	-method           sasl
	-minpollsecs      4
	-noauth           0
	-port             ""
	-secure           0
	-timeout          30000
	-transport        tcp      
    }
    
    # todo:
    # -anonymous
    set inited 1
}

# jlib::connect::configure --
# 
# 

proc jlib::connect::configure {args} {    
    variable have
    variable options
    
    debug "jlib::connect::configure args=$args"
    
    if {[llength $args] == 0} {
	return [array get options]
    } else {
	foreach {key value} $args {
	    switch -- $key {
		-compress {
		    if {!$have(jlib::compress)} {
			return -code error "missing jlib::compress package"
		    }
		}
		-http {
		    if {!$have(jlib::http)} {
			return -code error "missing jlib::http package"
		    }
		}
		-method {
		    if {($value eq "ssl") && !$have(tls)} {
			return -code error "missing tls package"
		    } elseif {($value eq "tlssasl")  \
		      && (!$have(jlibtls) || !$have(jlibsasl))} {
			return -code error "missing jlibtls or jlibsasl package"
		    } elseif {($value eq "sasl") && !$have(jlibsasl)} {
			return -code error "missing jlibsasl package"
		    }
		}
	    }
	    set options($key) $value
	}
    }
}

proc jlib::connect::get_state {jlibname {name ""}} {    
    upvar ${jlibname}::connect::state state

    if {$name eq ""} {
	return [array get state]
    } else {
	if {[info exists state($name)]} {
	    return $state($name)
	} else {
	    return ""
	}
    }
}

# jlib::connect::connect --
# 
#       Initiate the login process.
# 
# Arguments:
#       jid
#       password
#       cmd         callback command
#       args:
#           -command          tclProc
#           -compress         0|1               (untested)
#           -defaulthttpurl   url
#           -defaultport      5222
#           -defaultresource  
#           -defaultsslport   5223
#           -digest           0|1
#           -dnsprotocol      tcp[udp
#           -dnssrv           0|1
#           -dnstxthttp       0|1
#           -dnstimeout       millisecs
#           -http             0|1
#           -httpurl          url
#           -ip
#           -secure           0|1
#           -method           ssl|tlssasl|sasl
#           -noauth           0|1
#           -port
#           -timeout          millisecs
#           -transport        tcp|http
#           
#         o Note the naming convention for -method!
#            ssl        using direct tls socket connection
#                       it corresponds to the original jabber method
#            tlssasl    in stream tls negotiation + sasl, xmpp compliant
#                       XMPP requires sasl after starttls!
#            sasl       only sasl authentication
#            
#         o The http proxy is configured from the http package.
#         o The SOCKS proxy is configured from the autosocks package.
#            
#       Port priorites:
#           1) -port
#           2) DNS SRV resource record
#           3) -defaultport
#       
# Results:
#       Callback initiated.

proc jlib::connect::connect {jlibname jid password args} {    
    variable have
    variable options
    
    debug "jlib::connect::connect jid=$jid, args=$args"
        
    # Instance specific namespace.
    namespace eval ${jlibname}::connect {
	variable state
    }
    upvar ${jlibname}::connect::state state
      
    jlib::splitjidex $jid username server resource
    
    # Notes:
    #   o use "coccinella" as default resource
    #   o state(host) is the DNS SRV record or server if DNS failed
    #   o set one timeout on the complete sequence

    set state(jid)      $jid
    set state(username) $username
    set state(server)   $server
    set state(host)     $server
    set state(resource) $resource
    set state(password) $password
    set state(args)     $args
    set state(error)    ""
    set state(state)    ""
    
    set state(usessl)   0
    set state(usetls)   0
    set state(usesasl)  0
    set state(usecompress) 0
    
    # Default options.
    array set state [array get options]
    array set state $args

    if {$resource eq ""} {
	set state(resource) $state(-defaultresource)
    }

    # Verify that we have the necessary packages.
    if {[catch {verify $jlibname} err]} {
	return -code error $err
    }

    if {$state(-http)} {
	set state(-transport) http
    }
    if {$state(-secure)} {
	switch -- $state(-method) {
	    sasl {
		set state(usesasl) 1
	    }
	    tlssasl {
		set state(usesasl) 1
		set state(usetls) 1
	    }
	    ssl {
		set state(usessl) 1
	    }
	}
    }
    if {$state(-compress) && ($state(usetls) || $state(usessl))} {
	#return -code error "connot have -compress and tls at the same time"
    }
    if {$state(-compress)} {
	set state(usecompress) 1
    }

    # Any stream version. XMPP requires 1.0.
    if {$state(usesasl) || $state(usetls) || $state(usecompress)} {
	set state(version) 1.0
    }
    
    if {$state(-ip) ne ""} {
	set state(host) $state(-ip)
    }
    
    # Actual port to connect to (tcp). 
    # May be changed by DNS lookup unless -port set.
    if {[string is integer -strict $state(-port)]} {
	set state(port) $state(-port)
    } else {
	if {$state(usessl)} {
	    set state(port) $state(-defaultsslport)
	} else {
	    set state(port) $state(-defaultport)
	}
    }
    
    # Schedule a timeout.
    if {$state(-timeout) > 0} {
	set state(after) [after $state(-timeout)  \
	  [list jlib::connect::timeout $jlibname]]
    }

    # Start by doing a DNS lookup.
    if {$state(-transport) eq "tcp"} {

	# Do not do a DNS SRV lookup if we have an explicit ip address.
	if {!$state(-dnssrv) || ($state(-ip) ne "")} {
	    tcp_connect $jlibname
	} else {
	    set state(state) dnsresolve
	    set cb [list jlib::connect::dns_srv_cb $jlibname]
	    if {$state(-command) ne {}} {
		uplevel #0 $state(-command) $jlibname dnsresolve
	    }
	    if {[catch {
		set state(dnstoken) [jlib::dns::get_addr_port $server $cb  \
		  -protocol $state(-dnsprotocol) -timeout $state(-dnstimeout)]
	    } err]} {
		# @@@ We should reset the jlib::dns here but it's buggy!
		unset -nocomplain state(dnstoken)
		tcp_connect $jlibname
	    }
	}
    } elseif {$state(-transport) eq "http"} {

	# Do not do a DNS TXT lookup if we have an explicit url address.
	if {!$state(-dnstxthttp) || ($state(-httpurl) ne "")} {
	    set state(httpurl) $state(-httpurl)
	    http_init $jlibname
	} else {
	    set state(state) dnsresolve
	    set cb [list jlib::connect::dns_http_cb $jlibname]
	    if {$state(-command) ne {}} {
		uplevel #0 $state(-command) $jlibname dnsresolve
	    }
	    if {[catch {
		set state(dnstoken) [jlib::dns::get_http_poll_url $server $cb]
	    } err]} {
		# @@@ We should reset the jlib::dns here but it's buggy!
		unset -nocomplain state(dnstoken)
		http_init $jlibname
	    }
	}
    }
    jlib::set_async_error_handler $jlibname [namespace code async_error]
}

proc jlib::connect::verify {jlibname} {    
    variable have
    upvar ${jlibname}::connect::state state

    if {$state(-secure)} {
	if {($state(-method) eq "sasl") && !$have(jlibsasl)} {
	    return -code error "missing jlibsasl package"
	}
	if {($state(-method) eq "ssl") && !$have(tls)} {
	    return -code error "missing tls package"
	}
	if {($state(-method) eq "tlssasl")  \
	  && (!$have(jlibtls) || !$have(jlibsasl))} {
	    return -code error "missing jlibtls or jlibsasl package"
	}
    }
    if {$state(-compress) && !$have(jlib::compress)} {
	return -code error "missing jlib::compress package"
    }
}

proc jlib::connect::async_error {jlibname err {msg ""}} {    
    upvar ${jlibname}::connect::state state
    
    finish $jlibname $err $msg
}

proc jlib::connect::dns_srv_cb {jlibname addrPort {err ""}} {
    upvar ${jlibname}::connect::state state
    
    debug "jlib::connect::dns_srv_cb addrPort=$addrPort, err=$err"
   
    # We never let a failure stop us here. Use host as fallback.
    if {$err eq ""} {
	set state(host) [lindex $addrPort 0 0]
	set state(port) [lindex $addrPort 0 1]
	
	# Try ad-hoc method for port number for ssl connections (5223).
	if {$state(usessl)} {
	    incr state(port)
	}
    }
    
    # If -port set this always takes precedence.
    if {[string is integer -strict $state(-port)]} {
	set state(port) $state(-port)
    }
    unset -nocomplain state(dnstoken)
    tcp_connect $jlibname
}

proc jlib::connect::dns_http_cb {jlibname url {err ""}} {    
    upvar ${jlibname}::connect::state state

    debug "jlib::connect::dns_http_cb url=$url, err=$err"
    
    unset -nocomplain state(dnstoken)
    if {$err eq ""} {
	set state(httpurl) $url
    }
    
    # If -httpurl set this always takes precedence.
    if {$state(-httpurl) ne ""} {
	set state(httpurl) $state(-httpurl)
    }
    http_init $jlibname
}

proc jlib::connect::http_init {jlibname} {    
    upvar ${jlibname}::connect::state state

    debug "jlib::connect::http_init"
    
    if {$state(httpurl) eq ""} {
	set state(httpurl)  \
	  [string map [list "%h" $state(server)] $state(-defaulthttpurl)]
    }
    jlib::http::new $jlibname $state(httpurl)
    init_stream $jlibname
}

proc jlib::connect::tcp_connect {jlibname} {    
    upvar ${jlibname}::connect::state state
    
    debug "jlib::connect::tcp_connect"

    set state(state) initnetwork
    if {$state(-command) ne {}} {
	uplevel #0 $state(-command) $jlibname initnetwork
    }    
    if {[catch {
	set state(sock) [autosocks::socket $state(host) $state(port) \
	  -command [list jlib::connect::socks_cb $jlibname]]
    } err]} {
	finish $jlibname network-failure
    }
}

proc jlib::connect::socks_cb {jlibname status} {

    debug "jlib::connect::socks_cb status=$status"

    if {$status eq "ok"} {
	tcp_writable $jlibname
    } else {
	finish $jlibname proxy-failure $status
    }
}

proc jlib::connect::tcp_writable {jlibname} {    
    upvar ${jlibname}::connect::state state
    
    debug "jlib::connect::tcp_writable"
    
    if {![info exists state(sock)]} {
	return
    }
    set sock $state(sock)
    fileevent $sock writable {}

    if {[catch {eof $sock} iseof] || $iseof} {
	finish $jlibname network-failure "connection eof"
	return
    }

    # Check if something went wrong first.
    if {[catch {fconfigure $sock -sockname} sockname]} {
	finish $jlibname network-failure $sockname
	return
    }

    # Configure socket.
    fconfigure $sock -buffering line -blocking 0
    catch {fconfigure $sock -encoding utf-8}

    $jlibname setsockettransport $sock
    
    # Do SSL handshake. See jlib::tls_handshake for a better way!
    if {$state(usessl)} {

	# Make it a SSL connection.
	if {[catch {
	    tls::import $sock -cafile "" -certfile "" -keyfile "" \
	      -request 1 -server 0 -require 0 -ssl2 no -ssl3 yes -tls1 yes
	} err]} {
	    close $sock
	    finish $jlibname tls-failure $err
	    return
	}
	set retry 0
	
	# Do SSL handshake.
	while {1} {
	    if {$retry > 100} { 
		close $sock
		set err "too long retry to setup SSL connection"
		finish $jlibname tls-failure $err
		return
	    }
	    if {[catch {tls::handshake $sock} err]} {
		if {[string match "*resource temporarily unavailable*" $err]} {
		    after 50  
		    incr retry
		} else {
		    close $sock
		    finish $jlibname tls-failure $err
		    return
		}
	    } else {
		break
	    }
	}
	fconfigure $sock -blocking 0 -encoding utf-8
    }
    
    # Send the init stream xml command.
    init_stream $jlibname
}

proc jlib::connect::init_stream {jlibname} {    
    upvar ${jlibname}::connect::state state
    
    debug "jlib::connect::init_stream"

    set state(state) initstream
    if {$state(-command) ne {}} {
	uplevel #0 $state(-command) $jlibname initstream
    }
    
    set opts {}
    if {[info exists state(version)]} {
	lappend opts -version $state(version)
    }
    
    # Initiate a new stream. We should wait for the server <stream>.
    # openstream may throw error.
    if {[catch {
	eval {$jlibname openstream $state(server)  \
	  -cmd [list jlib::connect::init_stream_cb]} $opts
    } err]} {
	finish $jlibname network-failure $err
	return
    }
}

proc jlib::connect::init_stream_cb {jlibname args} {
    upvar ${jlibname}::connect::state state
    
    if {![info exists state]} return
    
    debug "jlib::connect::init_stream_cb args=$args"
    
    array set argsA $args
        
    # We require an 'id' attribute.
    if {![info exists argsA(id)]} {
	finish $jlibname no-stream-id
	return
    }
    set state(streamid) $argsA(id)
    
    # If we are trying to use sasl or tls indicated by version='1.0' 
    # we must also be sure to receive a version attribute larger or 
    # equal to 1.0.
    set version1 0
    if {[info exists argsA(version)]} {
	set state(streamversion) $argsA(version)
	if {[package vcompare $argsA(version) 1.0] >= 0} {
	    set version1 1
	}
    }
    if {$state(usesasl) || $state(usetls)} {
	if {!$version1} {
	    finish $jlibname no-stream-version-1
	    return
	}
    }

    if {$state(usetls)} {
	set state(state) starttls
	if {$state(-command) ne {}} {
	    uplevel #0 $state(-command) $jlibname starttls
	}
	$jlibname starttls jlib::connect::starttls_cb
    } elseif {$state(usecompress)} {
	if {$state(-command) ne {}} {
	    uplevel #0 $state(-command) $jlibname startcompress
	}
	jlib::compress::start $jlibname jlib::connect::compress_cb
    } elseif {$state(-noauth)} {
	finish $jlibname
    } else {
	auth $jlibname
    }
}

proc jlib::connect::starttls_cb {jlibname type args} {
    upvar ${jlibname}::connect::state state
    
    if {![info exists state]} return
    
    debug "jlib::connect::starttls_cb type=$type, args=$args"

    if {$type eq "error"} {
	foreach {errcode errmsg} [lindex $args 0] break
	finish $jlibname $errcode $errmsg
    } else {
    
	# We have a new stream. XMPP Core:
	#    12. If the TLS negotiation is successful, the initiating entity
	#        MUST continue with SASL negotiation.
	set state(streamid) [$jlibname getstreamattr id]
	if {$state(-noauth)} {
	    finish $jlibname
	} else {
	    auth $jlibname
	}
    }
}

proc jlib::connect::compress_cb {jlibname {errcode ""} {errmsg ""}} {    
    upvar ${jlibname}::connect::state state
    
    if {![info exists state]} return
    
    debug "jlib::connect::compress_cb"
  
    # Note: Failure of compression setup SHOULD NOT be treated as an 
    # unrecoverable error and therefore SHOULD NOT result in a stream error. 
    if {$errcode ne ""} {
	finish $jlibname $errcode $errmsg
	return
    }
    if {$state(-noauth)} {
	finish $jlibname
    } else {
	auth $jlibname
    }
}

# jlib::connect::register --
# 
#       Typically used after registered a new account since JID and password
#       not known until registration succesful.

proc jlib::connect::register {jlibname jid password} {    
    upvar ${jlibname}::connect::state state
    
    jlib::splitjidex $jid username server resource

    set state(jid)      $jid
    set state(username) $username
    set state(password) $password
    if {$resource eq ""} {
	set state(resource) $state(-defaultresource)
    }
}

# jlib::connect::auth --
# 
#       Initiates the authentication process using an existing connect instance,
#       typically when started using -noauth.
#       The user can modify the options from the initial ones.

proc jlib::connect::auth {jlibname args} {        
    upvar ${jlibname}::connect::state state
    
    debug "jlib::connect::auth"

    array set state $args
    
    if {[catch {verify $jlibname} err]} {
	return -code error $err
    }
    set state(state) authenticate
    if {$state(-command) ne {}} {
	uplevel #0 $state(-command) $jlibname authenticate
    }
    
    set username $state(username)
    set password $state(password)
    set resource $state(resource)
    
    if {$state(usesasl)} {
	$jlibname auth_sasl $username $resource $password \
	  jlib::connect::auth_cb
    } elseif {$state(-digest)} {
	set digested [::sha1::sha1 $state(streamid)$password]
	$jlibname send_auth $username $resource   \
	  jlib::connect::auth_cb -digest $digested
    } else {

	# Plain password authentication.
	$jlibname send_auth $username $resource  \
	  jlib::connect::auth_cb -password $password
    }
}

proc jlib::connect::auth_cb {jlibname type queryE} {    
    upvar ${jlibname}::connect::state state
    
    if {![info exists state]} return
    
    debug "jlib::connect::auth_cb type=$type, queryE=$queryE"

    if {$type eq "error"} {
	lassign $queryE errcode errmsg
	finish $jlibname $errcode $errmsg
    } else {

	# We have a new stream.
	set state(streamid) [$jlibname getstreamattr id]
	finish $jlibname
    }
}

# jlib::connect::reset --
# 
#       This is kills any ongoing or nonexisting connect object.

proc jlib::connect::reset {jlibname} {
    
    debug "jlib::connect::reset"
    
    if {[jlib::havesasl]} {
	$jlibname sasl_reset
    }
    if {[jlib::havetls]} {
	$jlibname tls_reset
    }
    if {[namespace exists ${jlibname}::connect]} {
	finish $jlibname reset
    }
}

proc jlib::connect::timeout {jlibname} {

    if {[jlib::havesasl]} {
	$jlibname sasl_reset
    }
    if {[jlib::havetls]} {
	$jlibname tls_reset
    }
    finish $jlibname timeout
}

# jlib::connect::finish --
# 
#       Finalize the complete sequence, with or without any errors.
#       
# Arguments:
#       errcode:    one word error code, empty if ok
#       errmsg:     an additional arbitrary error message with details that
#                   typically gets reported by some component
#       
# Results:
#       Callback made.

proc jlib::connect::finish {jlibname {errcode ""} {errmsg ""}} {    
    upvar ${jlibname}::connect::state state
    
    debug "jlib::connect::finish errcode=$errcode, errmsg=$errmsg"

    jlib::set_async_error_handler $jlibname

    if {![info exists state(state)]} {
	# We do not exist.
	return
    }
    if {[info exists state(after)]} {
	after cancel $state(after)
    }
    if {[info exists state(dnstoken)]} {
	jlib::dns::reset $state(dnstoken)
    }
    if {$state(error) ne ""} {
	set errcode $state(error)
    }
    if {$errcode ne ""} {
	set status error

	# This 'kills' the connection. Needed for both tcp and http!
	# after idle seems necessary when resetting xml parser from callback
	#after idle [list $jlibname closestream]
	$jlibname kill
    } else {
	set status ok
    }
    
    # Here status must be either 'ok' or 'error'.
    if {$state(-command) ne {}} {
	if {$errcode eq ""} {
	    uplevel #0 $state(-command) [list $jlibname $status]
	} else {
	    uplevel #0 $state(-command) [list $jlibname $status $errcode $errmsg]
	}
    }
}

proc jlib::connect::free {jlibname} {
    upvar ${jlibname}::connect::state state

    debug  "jlib::connect::free"
    unset -nocomplain state
}

proc jlib::connect::debug {str} {
    variable debug
    
    if {$debug} {
	puts $str
    }
}

# We have to do it here since need the initProc before doing this.

namespace eval jlib::connect {

    jlib::ensamble_register connect  \
      [namespace current]::init      \
      [namespace current]::cmdproc
}

# Tests
if {0} {
    package require jlib::connect
    proc cb {args} {
	puts "---> $args"
	#puts [jlib::connect::get_state ::jlib::jlib1]
    }
    ::jlib::jlib1 connect connect matben@localhost xxx -command cb    
    ::jlib::jlib1 connect connect matben@devrieze.dyndns.org xxx \
      -command cb -secure 1 -method tlssasl
   
    ::jlib::jlib1 connect connect matben@sgi.se xxx -command cb  \
      -http 1 -httpurl http://sgi.se:5280/http-poll/

    ::jlib::jlib1 connect connect matben@jabber.ru xxx -command cb  \
      -compress 1 -secure 1 -method tls

    jlib::jlib1 closestream
}

#-------------------------------------------------------------------------------

