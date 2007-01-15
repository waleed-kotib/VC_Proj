#  autosocks.tcl ---
#  
#      Interface to socks4/5 to make usage of 'socket' transparent.
#      Can also be used as a wrapper for the 'socket' command without any
#      proxy configured.
#
#  (c) 2007  Mats Bengtsson
#
#  This source file is distributed under the BSD license.
#  
# $Id: autosocks.tcl,v 1.2 2007-01-15 15:09:31 matben Exp $

package provide autosocks 0.1

namespace eval autosocks {
    variable options
    array set options {
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

# autosocks::config --
# 
#       Get or set configuration options for the SOCKS proxy.
#       
# Arguments:
#       args:
#           -proxy            ""|socks4|socks5
#           -proxyhost        hostname
#           -proxyport        port number
#           -proxyusername    ""
#           -proxypassword    ""
# 
# Results:
#       one or many option values depending on arguments.

proc autosocks::config {args} {
    variable options
    variable packs
    if {[llength $args] == 0} {
	return [array get options]
    } elseif {[llength $args] == 1} {
	return $options($args)
    } else {
	set idx [lsearch $args -proxy]
	if {$idx >= 0} {
	    set proxy [lindex $args [incr idx]]
	    if {![info exists packs($proxy)]} {
		return -code error "unsupported proxy \"$proxy\""
	    }
	}
	array set options $args	
    }
}

# autosocks::socket --
# 
#       Subclassing the 'socket' command. Only client side.
#       We use -command tclProc instead of -async + fileevent writable.

proc autosocks::socket {host port args} {
    variable options
    
    array set argsA $args
    array set optsA $args
    unset -nocomplain optsA(-command)
    set proxy $options(-proxy)
    
    if {[string length $proxy]} {
	set ahost $options(-proxyhost)
	set aport $options(-proxyport)
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
	
	# There is a potential problem if the socket becomes writable in
	# this call before we return! Therefore 'after idle'.
	after idle [list \
	  fileevent $sock writable [namespace code [list writable $token]]]
    } else {
	set sock [eval {::socket $ahost $aport} [array get optsA]]
	if {[string length $options(-proxy)]} {
	    ${proxy}::init $sock $host $port
	}
    }
    return $sock
}

proc autosocks::writable {token} {
    variable $token
    upvar 0 $token state
    variable options
    
    set proxy $options(-proxy)
    set sock $state(sock)
    fileevent $sock writable {}
    
    if {[catch {eof $sock} iseof] || $iseof} {
	uplevel #0 $state(cmd) eof	        
	unset -nocomplain state
    } else {
	if {[string length $proxy]} {	    
	    if {[catch {
		$options(-proxy)::init $sock $state(host) $state(port) \
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
    variable options

    uplevel #0 $state(cmd) $status
    $options(-proxy)::free $stok
    unset -nocomplain state
}

