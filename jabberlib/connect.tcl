#  connect.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides a high level method to handle all the things to establish
#      a connection with a jabber server and do TLS, SASL, and authentication.
#      
#  Copyright (c) 2006  Mats Bengtsson
#  
# $Id: connect.tcl,v 1.2 2006-07-31 07:22:35 matben Exp $
# 
############################# USAGE ############################################
#
#   jlib::connect::configure ?options?
#   jlib::connect::connect jlibname jid password cmd ?options?
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
#       starttls-protoco-lerror
#       
#       All SASL error elements according to RFC 3920 (XMPP Core)
#       not-authorized    being the most common

package require jlib
package require sha1

package provide jlib::connect 0.1

namespace eval jlib::connect {
    
    variable inited 0
    variable debug 0
    variable have
}

# jlib::connect --
# 
#       Just a wrapper for the jlib::connect::connect function.

proc jlib::connect {jlibname jid password cmd args} {
    
    return [eval {jlib::connect::connect $jlibname $jid $password $cmd} $args]
}

proc jlib::connect::init {} {

    variable inited
    variable have
    
    debug "jlib::connect::init"
    
    set have(tls)           0
    set have(jlibsasl)      0
    set have(jlibtls)       0
    set have(jlibdns)       0
    set have(jlibcompress)  0
    set have(jlibhttp)      0

    if {![catch {package require tls}]} {
	set have(tls) 1
    }
    if {![catch {package require jlibsasl}]} {
	set have(jlibsasl) 1
    }
    if {![catch {package require jlibtls}]} {
	set have(jlibtls) 1
    }
    if {![catch {package require jlib::dns}]} {
	set have(jlibdns) 1
    }
    if {![catch {package require jlib::compress}]} {
	set have(jlibcompress) 1
    }
    if {![catch {package require jlib::http}]} {
	set have(jlibhttp) 1
    }
    
    # -method: ssl | tlssasl | sasl
    # -transport tcp | http  ???

    # Default options.
    variable options
    array set options {
	-compress         0
	-defaulthttpurl   http://%h:5280/http-poll/
	-defaultport      5222
	-defaultresource  "default"
	-defaultsslport   5223
	-digest           1
	-dnsprotocol      tcp
	-dnssrv           1
	-dnstxthttp       0
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
    
    variable inited
    variable have
    variable options
    
    debug "jlib::connect::configure args=$args"
    
    if {!$inited} {
	init
    }
    if {[llength $args] == 0} {
	return [array get options]
    } else {
	foreach {key value} $args {
	    switch -- $key {
		-http {
		    if {!$have(jlibhttp)} {
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
#           -compress         0|1
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
#           Note the naming convention for -method!
#            ssl        using direct tls socket connection
#                       it corresponds to the original jabber method
#            tlssasl    in stream tls negotiation + sasl, xmpp compliant
#                       XMPP requires sasl after starttls!
#            sasl       only sasl authentication
#            
#       Port priorites:
#           1) -port
#           2) DNS SRV resource record
#           3) -defaultport
#       
# Results:
#       Callback initiated.

proc jlib::connect::connect {jlibname jid password cmd args} {
    
    variable inited
    variable have
    variable options
    
    debug "jlib::connect::connect jid=$jid, cmd=$cmd, args=$args"
    
    if {!$inited} {
	init
    }
    
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
    set state(cmd)      $cmd
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
    if {$state(-compress) && !$have(jlibcompress)} {
	return -code error "missing jlibcompress package"
    }
    if {$state(-compress) && ($state(usetls) || $state(usessl))} {
	return -code error "connot have -compress and tls at the same time"
    }
    if {$state(-compress)} {
	set state(usecompress) 1
    }

    # Any stream version. XMPP requires 1.0.
    if {$state(usesasl) || $state(usetls) || $state(usecompress)} {
	set state(version) 1.0
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
	    uplevel #0 $state(cmd) $jlibname dnsresolve
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
	    uplevel #0 $state(cmd) $jlibname dnsresolve
	    if {[catch {
		set state(dnstoken) [jlib::dns::get_http_poll_url $server $cb]
	    } err]} {
		# @@@ We should reset the jlib::dns here but it's buggy!
		unset -nocomplain state(dnstoken)
		http_init $jlibname
	    }
	}
    }
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
    } else {
	set state(port) $state(-defaultport)
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
    uplevel #0 $state(cmd) $jlibname initnetwork
  
    if {$state(usessl)} {
	set socketCmd {::tls::socket -request 0 -require 0}
    } else {
	set socketCmd socket
    }

    if {[catch {eval $socketCmd {-async $state(host) $state(port)}} sock]} {
	finish $jlibname network-failure
	return
    }
    set state(sock) $sock
 
    # Configure socket.
    fconfigure $sock -buffering line -blocking 0
    catch {fconfigure $sock -encoding utf-8}
        
    # If open socket in async mode, need to wait for fileevent.
    fileevent $sock writable   \
      [list jlib::connect::tcp_writable $jlibname]
}

proc jlib::connect::tcp_writable {jlibname} {
    
    upvar ${jlibname}::connect::state state
    
    debug "jlib::connect::tcp_writable"

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
    $jlibname setsockettransport $sock
    
    # Do SSL handshake.
    if {$state(usessl)} {
	fconfigure $sock -blocking 1
	if {[catch {::tls::handshake $sock} err]} {
	    finish $jlibname tls-failure $err
	    return
	}
	fconfigure $sock -blocking 0
    }

    # Send the init stream xml command.
    init_stream $jlibname
}

proc jlib::connect::init_stream {jlibname} {
    
    upvar ${jlibname}::connect::state state
    
    debug "jlib::connect::init_stream"

    set state(state) initstream
    uplevel #0 $state(cmd) $jlibname initstream
    
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
    
    debug "jlib::connect::init_stream_cb args=$args"
    
    array set aargs $args
    
    # We require an 'id' attribute.
    if {![info exists aargs(id)]} {
	finish $jlibname no-stream-id
	return
    }
    set state(streamid) $aargs(id)
    
    # If we are trying to use sasl or tls indicated by version='1.0' 
    # we must also be sure to receive a version attribute larger or 
    # equal to 1.0.
    set version1 0
    if {[info exists aargs(version)]} {
	set state(streamversion) $aargs(version)
	if {[package vcompare $aargs(version) 1.0] >= 0} {
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
	uplevel #0 $state(cmd) $jlibname starttls
	$jlibname starttls jlib::connect::starttls_cb
    } elseif {$state(usecompress)} {
	uplevel #0 $state(cmd) $jlibname startcompress
	jlib::compress::start $jlibname jlib::connect::compress_cb
    } elseif {$state(-noauth)} {
	finish $jlibname
    } else {
	auth $jlibname
    }
}

proc jlib::connect::starttls_cb {jlibname type args} {

    upvar ${jlibname}::connect::state state
    
    debug "jlib::connect::starttls_cb type=$type, args=$args"

    if {$type eq "error"} {
	finish $jlibname tls-failed
    } else {
    
	# We have a new stream. XMPP Core:
	#    12. If the TLS negotiation is successful, the initiating entity
	#        MUST continue with SASL negotiation.
	set state(streamid) [$jlibname getstreamattr id]
	auth $jlibname
    }
}

proc jlib::connect::compress_cb {jlibname {errcode ""} {errmsg ""}} {
    
    upvar ${jlibname}::connect::state state
    
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

proc jlib::connect::auth {jlibname} {
        
    upvar ${jlibname}::connect::state state
    
    debug "jlib::connect::auth"

    set state(state) authenticate
    uplevel #0 $state(cmd) $jlibname authenticate
    
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
    
    debug "jlib::connect::auth_cb type=$type, queryE=$queryE"

    if {$type eq "error"} {
	foreach {errcode errmsg} $queryE break
	finish $jlibname $errcode $errmsg
    } else {

	# We have a new stream.
	set state(streamid) [$jlibname getstreamattr id]
	finish $jlibname
    }
}

proc jlib::connect::reset {jlibname} {

    $jlibname tls_reset
    $jlibname sasl_reset
    finish $jlibname reset
}

proc jlib::connect::timeout {jlibname} {

    $jlibname tls_reset
    $jlibname sasl_reset
    finish $jlibname timeout
}

# jlib::connect::finish --
# 
#       Finalize the complete sequence, with or without any errors.
#       
# Arguments:
#       errcode:    one word error code, empty of ok
#       errmsg:     an additional arbitrary error message with details that
#                   typically gets reported by some component
#       
# Results:
#       Callback made.

proc jlib::connect::finish {jlibname {errcode ""} {errmsg ""}} {
    
    upvar ${jlibname}::connect::state state
    
    debug "jlib::connect::finish errcode=$errcode, errmsg=$errmsg"

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
	if {[info exists state(sock)]} {
	    # after idle seems necessary when resetting xml parser from callback
	    after idle [list $jlibname closestream]
	}
    } else {
	set status ok
    }
    
    # Here status must be either 'ok' or 'error'.
    if {$errcode eq ""} {
	uplevel #0 $state(cmd) [list $jlibname $status]
    } else {
	uplevel #0 $state(cmd) [list $jlibname $status $errcode $errmsg]
    }
    unset state
}

proc jlib::connect::debug {str} {
    variable debug
    
    if {$debug} {
	puts $str
    }
}

# Tests
if {0} {
    package require jlib::connect
    proc cb {args} {
	puts "---> $args"
	#puts [jlib::connect::get_state ::jlib::jlib1]
    }
    jlib::connect::connect ::jlib::jlib1 matben@localhost xxx cb 
    jlib::connect::connect ::jlib::jlib1 matben@devrieze.dyndns.org 1amason cb \
      -secure 1 -method tlssasl
   
    jlib::connect::connect ::jlib::jlib1 matben@sgi.se 1amason cb  \
      -http 1 -httpurl http://sgi.se:5280/http-poll/

    jlib::connect::connect ::jlib::jlib1 matben@jabber.ru 1amason cb  \
      -compress 1 -secure 1 -method sasl

    jlib::jlib1 closestream
}

#-------------------------------------------------------------------------------

