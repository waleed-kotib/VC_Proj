#  socks5.tcl ---
#  
#      Package for using the SOCKS5 method for connecting TCP sockets.
#      Some code plus idee from Kerem 'Waster_' HADIMLI.
#
#  (C) 2000 Kerem 'Waster_' HADIMLI (minor parts)
#  (c) 2003  Mats Bengtsson
#  
# $Id: socks5.tcl,v 1.2 2003-12-04 14:19:13 matben Exp $

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
	auth_no             \x00
	auth_gssapi         \x01
	auth_userpass       \x02
	nomatchingmethod    \xFF
	cmd_connect         \x01
	cmd_bind            \x02
	rsv                 \x00
	atyp_ipv4           \x01
	atyp_domainname     \x03
	atyp_ipv6           \x04
	authver             \x02
	rsp_succeeded       \x00
	rsp_failure         \x01
	rsp_notallowed      \x02
	rsp_netunreachable  \x03
	rsp_hostunreachable \x04
	rsp_refused         \x05
	rsp_expired         \x06
	rsp_cmdunsupported  \x07
	rsp_addrunsupported \x08
    }
    variable ipv4_num_re {([0-9]{1,3}\.){3}[0-9]{1,3}}
    variable ipv6_num_re {([0-9a-fA-F]{4}:){7}[0-9a-fA-F]{4}}
    
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
    
    variable debug 2
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
    
    debug 2 "socks5::init"

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
	set methods  "$const(auth_no)$const(auth_userpass)"
    } else {
	set methods  "$const(auth_no)"
    }
    set nmethods [binary format c [string length $methods]]
        
    fconfigure $sock -translation {binary binary} -blocking 0
    fileevent $sock writable {}
    debug 2 "\tsend: ver nmethods methods"
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
    variable const
    upvar 0 $token state    
    
    debug 2 "socks5::response_method"
    
    set sock $state(sock)
    
    if {[catch {read $sock 2} data] || [eof $sock]} {
	finish $token eof
	return
    }    
    set serv_ver ""
    set method $const(nomatchingmethod)
    binary scan $data cc serv_ver smethod
    debug 2 "\tserv_ver=$serv_ver, smethod=$smethod"
    
    if {![string equal $serv_ver 5]} {
	finish $token "Socks server isn't version 5!"
	return
    }
    
    if {[string equal $smethod 0]} {	
	
	# Now, request address and port.
	request $token
    } elseif {[string equal $smethod 2]} {
	
	# User/Pass authorization required
	if {$state(auth) == 0} {
	    finish $token "User/Pass authorization required by Socks Server!"
	    return
	}
    
	# Username & Password length (binary 1 byte)
	set ulen [binary format c [string length $state(-username)]]
	set plen [binary format c [string length $state(-password)]]
	
	debug 2 "\tsend: authver ulen -username plen -password"
	if {[catch {
	    puts -nonewline $sock  \
	      "$const(authver)$ulen$state(-username)$plen$state(-password)"
	    flush $sock
	} err]} {
	    finish $token $err
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
	finish $token "Method not supported by Socks Server!"
	return
    }
}


proc socks5::response_auth {token} {
    variable $token
    upvar 0 $token state    
    
    debug 2 "socks5::response_auth"
    
    set sock $state(sock)

    if {[catch {read $sock 2} data] || [eof $sock]} {
	finish $token eof
	return
    }    
    set auth_ver ""
    set status \x00
    binary scan $data cc auth_ver status
    debug 2 "\tauth_ver=$auth_ver, status=$status"
    
    if {![string equal $auth_ver 1]} {
	finish $token "Socks Server's authentication isn't supported!"
	return
    }
    if {![string equal $status 0]} {
	finish $token "Wrong username or password!"
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
    
    debug 2 "socks5::request"
    
    set sock $state(sock)
    
    # Network byte-ordered port (2 binary-bytes, short)    
    set port [binary format S $state(port)]
    
    # Figure out type of address given to us.
    if {[regexp $ipv4_num_re $state(addr)]} {
	debug 2 "\tipv4"
	
	# IPv4 numerical address.
	set atyp_addr_port $const(atyp_ipv4)
    	foreach i [split $state(addr) .] {
	    append atyp_addr_port [binary format c $i]
	}
	append atyp_addr_port $port
    } elseif {[regexp $ipv6_num_re $state(addr)]} {
	# todo
    } else {
	debug 2 "\tdomainname"
	
	# Domain name.
	# Domain length (binary 1 byte)
	set dlen [binary format c [string length $state(addr)]]
	set atyp_addr_port \
	  "$const(atyp_domainname)$dlen$state(addr)$port"
    }
    
    # We send request for connect
    debug 2 "\tsend: ver cmd_connect rsv atyp_domainname dlen addr port"
    set aconst "$const(ver)$const(cmd_connect)$const(rsv)"
    if {[catch {
	puts -nonewline $sock "$aconst$atyp_addr_port"
	flush $sock
    } err]} {
	finish $token $err
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
    
    debug 2 "socks5::response"
    
    set sock $state(sock)
    
    # Start by reading ver+cmd+rsv.
    if {[catch {read $sock 3} data] || [eof $sock]} {
	finish $token eof
	return
    }        
    set serv_ver ""
    set rep ""
    binary scan $data cc serv_ver rep rsv
    
    if {![string equal $serv_ver 5]} {
	finish $token "Socks server isn't version 5!"
	return
    }

    switch -- $rep {
	0 {
	    fconfigure $sock -translation {auto auto}
	}
	1 - 2 - 3 - 4 - 5 - 6 - 7 - 8 {
	    finish $token $msg($rep)
	    return
	}
	default {
	    finish $token "Socks server responded: Unknown Error"
	    return
	}    
    }

    # Now parse the variable length atyp+addr+host.
    if {[catch {parse_atyp_addr $token addr port} err]} {
	finish $token $err
	return
    }
    
    # Store in our state array.
    set state(bnd_addr) $addr
    set state(bnd_port) $port

    # And finally return result (bnd_add and bnd_port)
    if {$state(async)} {
	finish $token
    } else {
	
	# This should propagate to the socks5::init proc.
	return [list $state(bnd_addr) $state(bnd_port)]
    }
}


proc socks5::parse_atyp_addr {token addrVar portVar} {
    variable $token
    variable const
    upvar 0 $token state
    upvar $addrVar addr
    upvar $portVar port
    
    debug 2 "socks5::parse_atyp_addr"
    
    set sock $state(sock)

    # Start by reading atyp.
    if {[catch {read $sock 1} data] || [eof $sock]} {
	return -code error eof
    }        
    set atyp ""
    binary scan $data c atyp
    debug 2 "\tatyp=$atyp"
    
    # Treat the three address types in order.
    switch -- $atyp {
	1 {
	    if {[catch {read $sock 6} data] || [eof $sock]} {
		return -code error eof
	    }        
	    binary scan $data ccccS i0 i1 i2 i3 port
	    set addr ""
	    foreach n [list $i0 $i1 $i2 $i3] {
		# Translate to unsigned!
		append addr [expr ( $n + 0x100 ) % 0x100]
		if {$n <= 2} {
		    append addr .
		}
	    }
	}
	3 {
	    if {[catch {read $sock 1} data] || [eof $sock]} {
		return -code error eof
	    }        
	    binary scan $data c len
	    debug 2 "\tlen=$len"
	    set len [expr ( $len + 0x100 ) % 0x100]
	    if {[catch {read $sock $len} data] || [eof $sock]} {
		return -code error eof
	    }        
	    #binary scan $data c* addr
	    set addr $data
	    debug 2 "\taddr=$addr"
	    if {[catch {read $sock 2} data] || [eof $sock]} {
		return -code error eof
	    }        
	    binary scan $data S port
	    debug 2 "\tport=$port"
	}
	4 {
	    # todo
	}
	default {
	    return -code error "Unknown address type"
	}
    }
}


proc socks5::finish {token {errormsg ""}} {
    global errorInfo errorCode    
    variable $token
    upvar 0 $token state
    
    debug 2 "socks5::finish"
    
    catch {close $state(sock)}
    
    if {$state(async)} {
	if {[string length $errormsg]} {
	    uplevel #0 $state(-command) [list $token error $errormsg]
	} else {
	    uplevel #0 $state(-command) [list $token ok \
	      [list $state(bnd_addr) $state(bnd_port)]]
	}
	unset state
    } else {
	unset state
	if {[string length $errormsg]} {
	    return -code error $errormsg
	} else {
	    return ""
	}
    }
}

# The server side.
# 
# The SOCKS5 code as above but for the server side.

proc socks5::serverinit {sock ip port command args} {
    variable msg
    variable const
    variable uid
    
    debug 2 "socks5::serverinit"

    # Initialize the state variable, an array.  We'll return the
    # name of this array as the token for the transaction.
    
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
	
    array set state {
	auth              0
	state             ""
	status            ""
    }
    array set state [list        \
      command       $command     \
      sock          $sock]
    array set state $args
    
    fconfigure $sock -translation {binary binary} -blocking 0
    fileevent $sock writable {}

    # Start by reading the method stuff.
    if {[catch {read $sock 2} data] || [eof $sock]} {
	servfinish $token eof
	return
    }    
    set ver ""
    set method $const(nomatchingmethod)
    binary scan $data cc ver nmethods
    set nmethods [expr ( $nmethods + 0x100 ) % 0x100]
    debug 2 "\tver=$ver, nmethods=$nmethods"
    
    # Error checking. Must have either noauth or userpasswdauth.
    if {![string equal $ver 5]} {
	servfinish $token "Socks server isn't version 5!"
	return
    }
    for {set i 0} {$i < $nmethods} {incr i} {
	if {[catch {read $sock 1} data] || [eof $sock]} {
	    servfinish $token eof
	    return
	}    
	binary scan $data c method
	debug 2 "\tmethod=$method"
	set method [expr ( $method + 0x100 ) % 0x100]
	if {[string equal $method 0]} {
	    set noauthmethod 1
	} elseif {[string equal $method 2]} {
	    set userpasswdmethod 1
	}
    }
    set isok 1
    if {[info exists userpasswdmethod]} {
	set ans "$const(ver)$const(auth_userpass)"
	set state(auth) 1
    } elseif {[info exists noauthmethod]} {
	set ans "$const(ver)$const(auth_no)"
    } else {
	set ans "$const(ver)$const(nomatchingmethod)"
	set isok 0
    }
    
    debug 2 "\tsend: ver method"
    if {[catch {
	puts -nonewline $sock $ans
	flush $sock
    } err]} {
	servfinish $token $err
	return
    }
    if {!$isok} {
	servfinish $token "Unrecognized method requested by client"
	return
    }

    if {$state(auth)} {
	fileevent $sock readable  \
	  [list [namespace current]::serv_auth $token]
    } else {
	fileevent $sock readable  \
	  [list [namespace current]::serv_request $token]
    }
}


proc socks5::serv_auth {token} {
    variable $token
    variable const
    upvar 0 $token state
    
    debug 2 "socks5::serv_auth"

    set sock $state(sock)
    fileevent $sock readable {}
    
    if {[catch {read $sock 2} data] || [eof $sock]} {
	servfinish $token eof
	return
    }    
    set auth_ver ""
    set method $const(nomatchingmethod)
    binary scan $data cc auth_ver ulen
    set ulen [expr ( $ulen + 0x100 ) % 0x100]
    debug 2 "\tauth_ver=$auth_ver, ulen=$ulen"
    if {![string equal $auth_ver 2]} {
	servfinish $token "Wrong authorization method"
	return
    }    
    if {[catch {read $sock $ulen} data] || [eof $sock]} {
	return -code error eof
    }        
    #binary scan $data c* username
    set username $data
    debug 2 "\tusername=$username"
    if {[catch {read $sock 1} data] || [eof $sock]} {
	servfinish $token eof
	return
    }        
    binary scan $data c plen
    set plen [expr ( $plen + 0x100 ) % 0x100]
    debug 2 "\tplen=$plen"
    if {[catch {read $sock $plen} data] || [eof $sock]} {
	servfinish $token eof
	return
    }        
    #binary scan $data c* password
    set password $data
    debug 2 "\tpassword=$password"
    set state(username) $username
    set state(password) $password
    
    set ans [uplevel #0 $state(command) [list $token authorize \
      -username $username -password $password]]
    if {!$ans} {
	catch {
	    puts -nonewline $state(sock) "\x00\x01"
	}
	servfinish $token notauthorized
	return
    }    
    
    # Write auth response.
    if {[catch {
	puts -nonewline $sock "\x01\x00"
	flush $sock
    } err]} {
	servfinish $token $err
	return
    }
    fileevent $sock readable  \
      [list [namespace current]::serv_request $token]
}


proc socks5::serv_request {token} {
    variable $token
    variable const
    variable msg
    variable ipv4_num_re
    variable ipv6_num_re
    upvar 0 $token state
    
    debug 2 "socks5::serv_request"

    set sock $state(sock)

    # Start by reading ver+cmd+rsv.
    if {[catch {read $sock 3} data] || [eof $sock]} {
	servfinish $token eof
	return
    }        
    set ver ""
    set cmd ""
    set rsv ""
    binary scan $data cc ver cmd rsv
    debug 2 "\tver=$ver, cmd=$cmd, rsv=$rsv"
    
    if {![string equal $ver 5]} {
	servfinish $token "Socks server isn't version 5!"
	return
    }
    if {![string equal $cmd 1]} {
	servfinish $token "Unsuported CMD, must be CONNECT"
	return
    }

    # Now parse the variable length atyp+addr+host.
    if {[catch {parse_atyp_addr $token addr port} err]} {
	servfinish $token $err
	return
    }
   
    # Store in our state array.
    set state(dst_addr) $addr
    set state(dst_port) $port
    
    # Network byte-ordered port (2 binary-bytes, short)    
    set bport [binary format S $port]
    
    # Form and send the reply.
    set ans [uplevel #0 $state(command) [list $token reply $addr $port]]
    foreach {rep bnd_addr bnd_port} $ans break
    set bin_rep [binary format c $rep]
    set aconst "$const(ver)$bin_rep$const(rsv)"
    
    # Figure out type of address given to us.
    if {[regexp $ipv4_num_re $bnd_addr]} {
	debug 2 "\tipv4"
	
	# IPv4 numerical address.
	set atyp_addr_port $const(atyp_ipv4)
	foreach i [split $bnd_addr .] {
	    append atyp_addr_port [binary format c $i]
	}
	append atyp_addr_port $bport
    } elseif {[regexp $ipv6_num_re $bnd_addr]} {
	# todo
    } else {
	debug 2 "\tdomainname"
	
	# Domain name.
	# Domain length (binary 1 byte)
	set dlen [binary format c [string length $bnd_addr]]
	set atyp_addr_port \
	  "$const(atyp_domainname)$dlen$bnd_addr$bport"
    }
    
    # We send request for connect
    debug 2 "\tsend: ver rep rsv atyp_domainname dlen addr port"
    if {[catch {
	puts -nonewline $sock "$aconst$atyp_addr_port"
	flush $sock
    } err]} {
	servfinish $token $err
	return
    }
    servfinish $token
    
}


proc socks5::servfinish {token {errormsg ""}} {
    variable $token
    upvar 0 $token state
    
    debug 2 "socks5::servfinish"
    
    catch {close $state(sock)}
    
    if {[string length $errormsg]} {
	uplevel #0 $state(command) [list $token error -error $errormsg]
    } else {
	uplevel #0 $state(command) [list $token ok]
    }
    unset state
}

#       Just a trigger for vwait.

proc socks5::readable {token} {
    variable $token
    upvar 0 $token state    

    incr state(trigger)
}

proc socks5::debug {num str} {
    variable debug
    if {$num <= $debug} {
	puts $str
    }
}

# Test code...

if {0} {
    
    # Server
    proc serv_cmd {token type args} {
	puts "server: token=$token, type=$type, args=$args"
	
	switch -- $type {
	    error {
		
	    }
	    ok {
		
	    }
	    authorize {
		return 1
	    }
	    reply {
		return [list 0 rainbow.se 3344]
	    }
	}	    
    }
    proc server_connect {sock ip port} {
	fileevent $sock readable  \
	  [list socks5::serverinit $sock $ip $port serv_cmd]
    }
    socket -server server_connect 1080
    
    # Client
    proc cb {token type args} {
	puts "client: token=$token, type=$type, args=$args"
    }
    set s [socket 127.0.0.1 1080]
    socks5::init $s myaddr.se 8899 -command cb
    socks5::init $s myaddr.se 8899 -command cb -username xxx -password yyy
}

#-------------------------------------------------------------------------------
