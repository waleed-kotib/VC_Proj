#  autosocks.tcl ---
#  
#      Interface to socks4/5 to make usage of 'socket' transparent.
#
#  (c) 2007  Mats Bengtsson
#
#  This source file is distributed under the BSD license.
#  
# $Id: autosocks.tcl,v 1.1 2007-01-14 15:33:32 matben Exp $

package provide autosocks 0.1

namespace eval autosocks {
    variable static
    array set static {
	-proxy          ""
	-proxyhost      ""
	-proxyport      ""
	-proxyfilter    ""
    }
    
    variable packs
    foreach name {socks4 socks5} {
	if {![catch {package require $name}]} {
	    set packs($name) 1
	}	
    }
}

proc autosocks::config {args} {
    variable static
    variable packs
    if {[llength $args] == 0} {
	return [array get static]
    } elseif {[llength $args] == 1} {
	return $static($args)
    } else {
	set idx [lsearch $args -proxy]
	if {$idx >= 0} {
	    set proxy [lindex $args [incr idx]]
	    if {![info exists packs($proxy)]} {
		return -code error "unsupported proxy \"$proxy\""
	    }
	}
	array set static $args	
    }
}

# autosocks::socket --
# 
#       Subclassing the 'socket' command. Only client side.
#       We use -command tclProc instead of -async + fileevent writable.

proc autosocks::socket {host port args} {
    variable static
    
    array set argsA $args
    array set optsA $args
    unset -nocomplain optsA(-command)
    set proxy $static(-proxy)
    
    if {[string length $proxy]} {
	set ahost $static(-proxyhost)
	set aport $static(-proxyport)
    } else {
	set ahost $host
	set aport $port
    }
    
    # Connect ahost + aport.
    if {[info exists argsA(-command)]} {
	set sock [eval ::socket -async [array get optsA] {$ahost $aport}]
	set token [namespace current]::$sock
	variable $token
	upvar 0 $token state

	set state(host) $host
	set state(port) $port
	set state(sock) $sock
	set state(cmd)  $argsA(-command)
	fconfigure $sock -blocking 0
	fileevent $sock writable [namespace code [list writable $token]]
    } else {
	set sock [eval {::socket $ahost $aport} [array get optsA]]
	if {[string length $static(-proxy)]} {
	    ${proxy}::init $sock $host $port
	}
    }
    return $sock
}

proc autosocks::writable {token} {
    variable $token
    upvar 0 $token state
    variable static
    
    set proxy $static(-proxy)
    set sock $state(sock)
    fileevent $sock writable {}
    
    if {[eof $sock]} {
	uplevel #0 $state(cmd) eof	        
	unset -nocomplain state
    } else {
	if {[string length $proxy]} {	    
	    if {[catch {
		$static(-proxy)::init $sock $state(host) $state(port) \
		  -command [namespace code [list socks_cb $token]]
	    } err]} {
		uplevel #0 $state(cmd) $err
		unset -nocomplain state
	    }
	} else {
	    uplevel #0 $state(cmd) ok
	    unset -nocomplain state
	}
    }
}

proc autosocks::socks_cb {token stok status} {
    variable $token
    upvar 0 $token state
    variable static

    uplevel #0 $state(cmd) $status
    $static(-proxy)::free $stok
    unset -nocomplain state
}

