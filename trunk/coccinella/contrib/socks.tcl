##############################################################################
# Socks5 Client Library v1.1
#     (C) 2000 Kerem 'Waster_' HADIMLI 
#     (C) 2002 Mats Bengtsson, complete rewrite
#
# $Id: socks.tcl,v 1.1.1.1 2002-12-08 10:56:24 matben Exp $
# 
# How to use:
#   1) Create your socket connected to the Socks server.
#   2) Call socks:init procedure with these 6 parameters:
#        1- Socket ID : The socket identifier that's connected to the socks5 server.
#        2- Server hostname : The main (not socks) server you want to connect
#        3- Server port : The port you want to connect on the main server
#        4- Authentication : If you want username/password authenticaton enabled, set this to 1, otherwise 0.
#        5- Username : Username to use on Socks Server if authenticaton is enabled. NULL if authentication is not enabled.
#        6- Password : Password to use on Socks Server if authenticaton is enabled. NULL if authentication is not enabled.
#
# Notes:
#   - This library enters vwait loop (see Tcl man pages), and returns only
#     when SOCKS initialization is complete.
#   - NEVER use file IDs instead of socket IDs!
#   - NEVER bind the socket (fileevent) before calling socks:init procedure.
#   - Be sure '-buffering none'
##############################################################################
#
# Author contact information:
#   E-mail :  waster@iname.com
#   ICQ#   :  27216346
#   Jabber :  waster@jabber.org   (New IM System - http://www.jabber.org)
#   
# Mats Bengtsson
#   E-mail :  matben@privat.utfors.se
#   Jabber :  matben@jabber.org
#
################################################################################

package provide socks 1.2

namespace eval socks {
    
    # vwait variable
    variable trigger
    
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
	atyp                \x03
	authver             \x01
    }
    
    variable msg
    array set msg {
	1 {Socks server responded: General SOCKS server failure}
	2 {Socks server responded: Connection not allowed by ruleset}
	3 {Socks server responded: Network unreachable}
	4 {Socks server responded: Host unreachable}
	5 {Socks server responded: Connection refused}
	6 {Socks server responded: TTL expired}
	7 {Socks server responded: Command not supported}
	8 {Socks server responded: Address type not supported}
    }
}

# socks::init --
#
#       Negotiates with a SOCKS server, and returns when complete.
#       Any problems are returned as an error (catch it!).
#
# Arguments:
#       sock:       an open socket token to the SOCKS server
#       addr:       the peer address, not SOCKS server
#       port:       the peer's port number
#       args:   -user   username
#               -pass   password
#       
# Results:
#       none.

proc socks::init {sock addr port args} {
    
    variable msg
    variable const
    variable trigger
    
    array set opts {
	-user ""
	-pass ""
    }
    array set opts $args    
    
    set auth 0
    if {[string length $opts(-user)] || [string length $opts(-pass)]} {
	set auth 1
    }
    if {$auth == 0} {
	set method   \x00
	set nmethods \x01
    } elseif {$auth == 1} {
	set method   \x00\x02
	set nmethods \x02
    } else {
	return -code error {syntax error}
    }
        
    # Domain length (binary 1 byte)
    set dlen [binary format c [string length $addr]]
    
    # Network byte-ordered port (2 binary-bytes, short)    
    set port [binary format S $port]
        
    fconfigure $sock -translation {binary binary} -blocking 0
    fileevent $sock readable [list [namespace current]::readable $sock]
    
    puts -nonewline $sock "$const(ver)$nmethods$method"
    flush $sock
    
    vwait [namespace current]::trigger($sock)
    if {[catch {read $sock} a]} {
	catch {close $sock}
	return -code error {Connection closed with Socks Server!}
    } elseif {[eof $sock]} {
	catch {close $sock}
	return -code error {Connection closed with Socks Server!}
    }
    
    set serv_ver ""
    set method $const(nomatchingmethod)
    binary scan $a cc serv_ver smethod
    
    if {![string equal $serv_ver 5]} {
	catch {close $sock}
	return -code error {Socks Server isn't version 5!}
    }
    
    if {[string equal $smethod 0]} {
	# Do nothin
    } elseif {[string equal $smethod 2]} {
	
	# User/Pass authorization required
	if {$auth == 0} {
	    catch {close $sock}
	    return -code error {User/Pass authorization required by Socks Server!}
	}
    
	# Username & Password length (binary 1 byte)
	set ulen [binary format c [string length $opts(-user)]]
	set plen [binary format c [string length $opts(-pass)]]
	
	puts -nonewline $sock "$const(authver)$ulen$opts(-user)$plen$opts(-pass)"
	flush $sock
	
	vwait [namespace current]::trigger($sock)
	if {[catch {read $sock} a]} {
	    catch {close $sock}
	    return -code error {Connection closed with Socks Server!}
	} elseif {[eof $sock]} {
	    catch {close $sock}
	    return -code error {Connection closed with Socks Server!}
	}
	
	set auth_ver ""
	set status \x00
	binary scan $a cc auth_ver status
	
	if {![string equal $auth_ver 1]} {
	    catch {close $sock}
	    return -code error {Socks Server's authentication isn't supported!}
	}
	if {![string equal $status 0]} {
	    catch {close $sock}
	    return -code error {Wrong username or password!}
	}	
    } else {
	fileevent $sock readable {}
	unset trigger($sock)
	catch {close $sock}
	return -code error {Method not supported by Socks Server!}
    }
    
    # We send request4connect
    set aconst "$const(ver)$const(cmd_connect)$const(rsv)$const(atyp)"
    puts -nonewline $sock "$aconst$dlen$addr$port"
    flush $sock
    
    # Wait here for server to respond.
    vwait [namespace current]::trigger($sock)   
    if {[catch {read $sock} a]} {
	catch {close $sock}
	return -code error {Connection closed with Socks Server!}
    } elseif {[eof $sock]} {
	catch {close $sock}
	return -code error {Connection closed with Socks Server!}
    }    
    fileevent $sock readable {}
    unset trigger($sock)
    
    set serv_ver ""
    set rep ""
    binary scan $a cc serv_ver rep
    if {![string equal $serv_ver 5]} {
	catch {close $sock}
	return -code error {Socks server isn't version 5!}
    }
    switch -- $rep {
	0 {
	    fconfigure $sock -translation {auto auto}
	}
	1 - 2 - 3 - 4 - 5 - 6 - 7 - 8 {
	    catch {close $sock}
	    return -code error $msg($rep)
	}
	default {
	    catch {close $sock}
	    return -code error {Socks server responded: Unknown Error}
	}    
    }
}

#
# Change the variable value, so 'vwait' loop will end in socks::init procedure.
#
proc socks::readable {sock} {
    variable trigger
    incr trigger($sock)
}

#-------------------------------------------------------------------------------
