#  socks5.tcl ---
#  
#      Package for using the SOCKS5 method for connecting TCP sockets.
#      Some code plus idee from Kerem 'Waster_' HADIMLI.
#
#  (C) 2000 Kerem 'Waster_' HADIMLI (minor parts)
#  (c) 2003  Mats Bengtsson
#  
# $Id: socks5.tcl,v 1.1 2003-12-03 08:35:11 matben Exp $

package provide socks5 0.1

namespace eval socks5 {

    # Constants:
    # ver:                Socks version
    # nomatchingmethod:   No matching methods
    # cmd_connect:        Connect command
    # rsv:                Reserved
    # atyp:               Address Type (domain)
    # authver:            User/Pass auth. version
    variable const
    array set const {
	ver                 \x05
	nomatchingmethod    \xFF
	cmd_connect         \x01
	rsv                 \x00
	atyp_ipv4           \x01
	atyp_domainname     \x03
	atyp_ipv6           \x04
	authver             \x01
    }
    variable ipv4_num_re {([0-9]{1,3}\.){3}[0-9]{1,3}}
    variable ipv6_num_re {([0-9a-f]{4}:){7}[0-9]{1,3}[0-9a-f]{4}}
    
    variable msg
    array set msg {
	1 "General SOCKS server failure"
	2 "Connection not allowed by ruleset"
	3 "Network unreachable"
	4 "Host unreachable"
	5 "Connection refused"
	6 "TTL expired"
	7 "Command not supported"
	8 "Address type not supported"
    }
    
    variable uid 0
}

# socks5::init --
#
#       Negotiates with a SOCKS server.
#
# Arguments:
#       sock:       an open socket token to the SOCKS server
#       addr:       the peer address, not SOCKS server
#       port:       the peer's port number
#       args:   
#               -command    tcl proc
#               -username   username
#               -password   password
#               -timeout    millisecs
#       
# Results:
#       none.

proc socks5::init {sock addr port args} {    
    variable msg
    variable const
    variable uid

    # Initialize the state variable, an array.  We'll return the
    # name of this array as the token for the transaction.
    
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
        
    array set state {
	-password         ""
	-timeout          60000
	-username         ""
	async             0
	auth              0
	bnd_addr          ""
	bnd_port          ""
	state             ""
	status            ""
	trigger           0
    }
    array set state [list     \
      addr          $addr     \
      port          $port     \
      sock          $sock]
    array set state $args
         
    if {[string length $state(-username)] ||  \
      [string length $state(-password)]} {
	set state(auth) 1
    }
    if {[info exists state(-command)] && [string length $state(-command)]} {
	set state(async) 1
    }
    if {$state(auth)} {
	set methods  \x00\x02
	set nmethods \x02
    } else {
	set methods  \x00
	set nmethods \x01
    }
        
    fconfigure $sock -translation {binary binary} -blocking 0 -buffering none
    fileevent $sock writable {}
    if {[catch {
	puts -nonewline $sock "$const(ver)$nmethods$methods"
	flush $sock
    } err]} {
	return -code error $err
    }
    if {$state(async)} {
	fileevent $sock readable  \
	  [list [namespace current]::response_method $token]
	return $token
    } else {
	
	# We should not return from this proc until finished!
	fileevent $sock readable  \
	  [list [namespace current]::readable $token]
	vwait $token\(trigger)
	return [response_method $token]
    }
}


proc socks5::response_method {token} {
    variable $token
    upvar 0 $token state    
    
    set sock $state(sock)
    
    if {[catch {read $sock 2} reply] || [eof $sock]} {
	Finish $token eof
	return
    }    
    set serv_ver ""
    set method $const(nomatchingmethod)
    binary scan $reply cc serv_ver smethod
    
    if {![string equal $serv_ver 5]} {
	Finish $token "Socks server isn't version 5!"
	return
    }
    
    if {[string equal $smethod 0]} {	
	
	# Now, request address and port.
	request $token
    } elseif {[string equal $smethod 2]} {
	
	# User/Pass authorization required
	if {$state(auth) == 0} {
	    Finish $token "User/Pass authorization required by Socks Server!"
	    return
	}
    
	# Username & Password length (binary 1 byte)
	set ulen [binary format c [string length $state(-username)]]
	set plen [binary format c [string length $state(-password)]]
	
	if {[catch {
	    puts -nonewline $sock  \
	      "$const(authver)$ulen$state(-username)$plen$state(-password)"
	    flush $sock
	} err]} {
	    Finish $token $err
	    return
	}

	if {$state(async)} {
	    fileevent $sock readable  \
	      [list [namespace current]::response_auth $token]
	    return
	} else {
	    
	    # We should not return from this proc until finished!
	    fileevent $sock readable  \
	      [list [namespace current]::readable $token]
	    vwait $token\(trigger)
	    return [response_auth $token]
	}
    } else {
	Finish $token "Method not supported by Socks Server!"
	return
    }
}


proc socks5::response_auth {token} {
    variable $token
    upvar 0 $token state    
    
    set sock $state(sock)

    if {[catch {read $sock 2} reply] || [eof $sock]} {
	Finish $token eof
	return
    }    
    set auth_ver ""
    set status \x00
    binary scan $reply cc auth_ver status
    
    if {![string equal $auth_ver 1]} {
	Finish $token "Socks Server's authentication isn't supported!"
	return
    }
    if {![string equal $status 0]} {
	Finish $token "Wrong username or password!"
	return
    }	
    
    # Now, request address and port.
    return [request $token]
}


proc socks5::request {token} {
    variable $token
    variable const
    variable ipv4_num_re
    variable ipv6_num_re
    upvar 0 $token state    
    
    set sock $state(sock)
    
    # Figure out type of address given to us.
    if {[regexp $ipv4_num_re $state(addr)]} {
	
	# IPv4 numerical address. Translate to unsigned!
	set atyp_addr_port $const(atyp_ipv4)
    	foreach i [split $state(addr) .] {
	    set csign [binary format c $i]
	    append atyp_addr_port [expr ( $csign + 0x100 ) % 0x100]
	}
	append atyp_addr_port $state(port)
    } else if {[regexp $ipv6_num_re $state(addr)]} {
	# todo
    } else {
	
	# Domain name.
	# Domain length (binary 1 byte)
	set dlen [binary format c [string length $state(addr)]]
	set atyp_addr_port \
	  "$const(atyp_domainname)$dlen$state(addr)$state(port)"
    }
    
    
    # Network byte-ordered port (2 binary-bytes, short)    
    set port [binary format S $state(port)]

    # We send request for connect
    set aconst "$const(ver)$const(cmd_connect)$const(rsv)"
    if {[catch {
	puts -nonewline $sock "$aconst$atyp_addr_port"
	flush $sock
    } err]} {
	Finish $token $err
	return
    }
    
    if {$state(async)} {
	fileevent $sock readable  \
	  [list [namespace current]::response $token]
	return
    } else {
	
	# We should not return from this proc until finished!
	fileevent $sock readable  \
	  [list [namespace current]::readable $token]
	vwait $token\(trigger)
	return [response $token]
    }
}


proc socks5::response {token} {
    variable $token
    variable msg
    upvar 0 $token state    
    
    set sock $state(sock)
    
    # Start by reading ver+cmd+rsv.
    if {[catch {read $sock 3} reply] || [eof $sock]} {
	Finish $token eof
	return
    }        
    set serv_ver ""
    set rep ""
    binary scan $reply cc serv_ver rep rsv
    
    if {![string equal $serv_ver 5]} {
	Finish $token "Socks server isn't version 5!"
	return
    }

    switch -- $rep {
	0 {
	    fconfigure $sock -translation {auto auto}
	}
	1 - 2 - 3 - 4 - 5 - 6 - 7 - 8 {
	    Finish $token $msg($rep)
	    return
	}
	default {
	    Finish $token "Socks server responded: Unknown Error"
	    return
	}    
    }

    # Now parse the variable length atyp+addr+host.
    if {[catch {parse_atyp_addr $token} err]} {
	Finish $token $err
	return
    }

    # And finally return result (bnd_add and bnd_port)
    if {$state(async)} {
	Finish $token
    } else {
	
	# This should propagate to the socks5::init proc.
	return [list $state(bnd_addr) $state(bnd_port)]
    }
}


proc socks5::parse_atyp_addr {token} {
    variable $token
    variable const
    upvar 0 $token state    
    
    set sock $state(sock)

    # Start by reading atyp.
    if {[catch {read $sock 1} reply] || [eof $sock]} {
	return -code error eof
    }        
    set atyp ""
    binary scan $reply c atyp
    
    # Treat the three address types in order.
    if {$atyp == $const(atyp_ipv4)} {
	if {[catch {read $sock 6} reply] || [eof $sock]} {
	    return -code error eof
	}        
	binary scan $reply ccccS i0 i1 i2 i3 port
	set addrtxt ""
	foreach n [list $i0 $i1 $i2 $i3] {
	    # Translate to unsigned!
	    append addrtxt [expr ( $n + 0x100 ) % 0x100]
	    if {$n <= 2} {
		append addrtxt .
	    }
	}
    } elseif {$atyp == $const(atyp_domainname)} {
	if {[catch {read $sock 1} reply] || [eof $sock]} {
	    return -code error eof
	}        
	binary scan $reply c len
	if {[catch {read $sock $len} reply] || [eof $sock]} {
	    return -code error eof
	}        
	binary scan $reply c* addrtxt
	if {[catch {read $sock 2} reply] || [eof $sock]} {
	    return -code error eof
	}        
	binary scan $reply S port
    } elseif {$atyp == $const(atyp_ipv6)} {
	# todo
    } else {
	return -code error "Socks server responded with an unknown address type"
    }
    
    # Store in our state array.
    set state(bnd_addr) $addrtxt
    set state(bnd_port) $port
}

# The server side.
# 
# The SOCKS5 code as above but for the server side.

proc socks5::serverinit {} {
    
    
}

proc socks5::Finish {token {errormsg ""}} {
    global errorInfo errorCode    
    variable $token
    upvar 0 $token state
    
    catch {close $state(sock)}
    if {$state(async)} {
	if {[string length $errormsg]} {
	    uplevel #0 $state(-command) $token error $errormsg
	} else {
	    uplevel #0 $state(-command) $token ok \
	      [list $state(bnd_addr) $state(bnd_port)]
	}
    }
    unset state
}

#       Just a trigger for vwait.

proc socks5::readable {token} {
    variable $token
    upvar 0 $token state    

    incr state(trigger)
}

#-------------------------------------------------------------------------------
