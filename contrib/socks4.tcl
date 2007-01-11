#  socks4.tcl ---
#  
#      Package for using the SOCKS4a method for connecting TCP sockets.
#      Only client side.
#
#  (c) 2007  Mats Bengtsson
#
#  This source file is distributed under the BSD license.
#  
#  @@@ TODO: merge with socks5?
#  
# $Id: socks4.tcl,v 1.1 2007-01-11 14:25:45 matben Exp $

package provide socks4 0.1

namespace eval socks4 {

    variable const
    array set const {
	ver                 \x04
	cmd_connect         \x01
	cmd_bind            \x02
	rsp_granted         \x5a
	rsp_failure         \x5b
	rsp_errconnect      \x5c
	rsp_erruserid       \x5d
    }
}

proc socks4::init {sock addr port userid args} {  
    variable const

    set token [namespace current]::$sock
    variable $token
    upvar 0 $token state
    
    array set state {
	-command          ""
	-timeout          60000
	async             0
	trigger           0
    }
    array set state [list     \
      addr          $addr     \
      port          $port     \
      userid        $userid   \
      sock          $sock]
    array set state $args

    if {[string length $state(-command)]} {
	set state(async) 1
    }

    # Network byte-ordered port (2 binary-bytes, short)    
    set bport [binary format S $port]
    
    # This corresponds to IP address 0.0.0.x, with x nonzero.
    set bip \x00\x00\x00\x01
    
    set bdata "$const(ver)$const(cmd_connect)$bport$bip$userid\x00$addr\x00"
    fconfigure $sock -translation {binary binary} -blocking 0
    fileevent $sock writable {}
    if {[catch {
	puts -nonewline $sock $bdata
	flush $sock
    } err]} {
	return -code error $err
    }

    # Setup timeout timer. !async remains!
    set state(timeoutid)  \
      [after $state(-timeout) [namespace current]::timeout $token]
    
    if {$state(async)} {
	fileevent $sock readable  \
	  [list [namespace current]::response $token]
	return $token
    } else {
	
	# We should not return from this proc until finished!
	fileevent $sock readable  \
	  [list [namespace current]::readable $token]
	vwait $token\(trigger)
	return [response $token]
    }
}

proc socks4::response {token} {
    variable $token
    upvar 0 $token state  
    variable const
    
    puts "socks4::response"
    
    set sock $state(sock)
    fileevent $sock readable {}
    
    # Read and parse status.
    if {[catch {read $sock 2} data] || [eof $sock]} {
	finish $token eof
	return
    }    
    binary scan $data cc null status
    if {![string equal $null \x00]} {
	finish $token errversion
	return
    }
    if {![string equal $status $const(rsp_granted)]} {
	finish $token failure
	return
    }
    
    # Read and parse port (2 bytes) and ip (4 bytes).
    if {[catch {read $sock 6} data] || [eof $sock]} {
	finish $token failure
	return
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
    # Translate to unsigned!
    set port [expr ( $port + 0x10000 ) % 0x10000]
    set state(dstport) $port
    set state(dstaddr) $addr
    
    return [finish $token]
}

proc socks4::readable {token} {
    variable $token
    upvar 0 $token state   
    puts "socks4::readable"
    incr state(trigger)
}

proc socks4::timeout {token} {
    finish $token timeout
}

proc socks4::finish {token {errormsg ""}} {
    global errorInfo errorCode    
    variable $token
    upvar 0 $token state
    
    puts "socks4::finish token=$token, errormsg=$errormsg"
    parray state
    
    catch {after cancel $state(timeoutid)}

    if {$state(async)} {
	if {[string length $errormsg]} {
	    catch {close $state(sock)}
	    uplevel #0 $state(-command) [list $token error $errormsg]
	} else {
	    uplevel #0 $state(-command) [list $token ok]
	}
	unset -nocomplain state
    } else {
	# ???
    }
}

# Test
if {0} {
    set s [socket 127.0.0.1 3000]
    socks4::init $s google.com 80 mats
    
}

