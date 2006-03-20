#  Network.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements some network utilities.
#      
#  Copyright (c) 2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Network.tcl,v 1.19 2006-03-20 14:37:18 matben Exp $

package provide Network 1.0

namespace eval ::Network:: {
    
    variable debug 0
}

# Network::Open --
#
#       This is supposed to be a fairly general method of opening sockets
#       async.
#       
# Arguments:
#       nameOrIP
#       port
#       cmd         Specific callback proc for this open operation.
#                   'cmd {sock ip port status {msg {}}}'
#       args        -timeout secs,
#                   -ssl     boolean 
#                            Must not be mixed up with -tls which has a special
#                            meaning in XMPP
#       
# Results:
#       only via the callback cmd.

proc ::Network::Open {nameOrIP port cmd args} {
    global  errorCode
    
    variable debug
    variable opts
    
    if {$debug > 1} {
	puts "::Network::Open, nameOrIP=$nameOrIP, port=$port"
    }
    array set opts {
	-timeout 0
	-ssl     0
    }
    array set opts $args
    if {$opts(-ssl)} {
	set socketCmd {::tls::socket -request 0 -require 0}
    } else {
	set socketCmd socket
    }
    
    # Try opening socket async.
    if {[catch {eval $socketCmd {-async $nameOrIP $port}} sock]} {
	uplevel #0 $cmd [list {} $nameOrIP $port error $sock]
	return
    }
    
    # Write/read line by line.
    fconfigure $sock -buffering line
    
    # When socket writable the connection is opened.
    # Needs to be in nonblocking mode.
    fconfigure $sock -blocking 0
    
    # For nonlatin characters to work be sure to use Unicode/UTF-8.
    if {[info tclversion] >= 8.1} {
	catch {fconfigure $sock -encoding utf-8}
    }
    
    # If open socket in async mode, need to wait for fileevent.
    fileevent $sock writable   \
      [list [namespace current]::WhenSocketOpensInits $sock $nameOrIP  \
      $port $cmd $opts(-ssl)]
    
    # Set up timer event for timeouts.
    if {$opts(-timeout) > 0} {
	::Network::ScheduleKiller $sock $cmd
    }
    
    return
}

# Network::WhenSocketOpensInits --
#
#       Callback when socket is open; becomes writable.
#       
# Arguments:
#       sock
#       nameOrIP
#       port
#       cmd         Specific callback proc for this open operation.
# Results:
#       only via the callback cmd.

proc ::Network::WhenSocketOpensInits {sock nameOrIP port cmd tls} {
    variable killerId    
    variable debug    
    
    if {$debug > 1} {
	puts "::Network::WhenSocketOpensInits, nameOrIP=$nameOrIP, port=$port"
    }
    
    # No more event handlers here. See also below...
    fileevent $sock writable {}
    
    #  Cancel timeout killer.
    if {[info exists killerId($sock)]} {
	after cancel $killerId($sock)
	unset -nocomplain killerId($sock)
    }

    if {[catch {eof $sock} iseof] || $iseof} {
	catch {close $sock}
	set msg "Failed to open network socket to $nameOrIP."
	uplevel #0 $cmd [list $sock $nameOrIP $port error $msg]
	return
    }
    
    # Detecting failure to connect, at least needed on linux.
    # The jabber server gives: <stream:error>Invalid XML</stream:error>
    if {0 && [catch {puts -nonewline $sock { }} msg]} {
	set msg "Failed to open network socket to $nameOrIP."
	uplevel #0 $cmd [list $sock $nameOrIP $port error $msg]
	return
    }
    
    # Check if something went wrong first.
    if {[catch {fconfigure $sock -sockname} sockname]} {
	uplevel #0 $cmd [list $sock $nameOrIP $port error $sockname]
	return
    }
    
    # Do SSL handshake.
    if {$tls} {
	fconfigure $sock -blocking 1
	if {[catch {::tls::handshake $sock} msg]} {
	    catch {close $sock}
	    uplevel #0 $cmd [list $sock $nameOrIP $port error $msg]
	    return
	}
	fconfigure $sock -blocking 0
    }
    
    # Evaluate our callback procedure.
    uplevel #0 $cmd [list $sock $nameOrIP $port ok]
}

# ScheduleKiller, Kill --
#
#       Cancel 'OpenConnection' process if timeout.
#
# Arguments:
#       sock
#       cmd         Specific callback proc for this open operation if we get
#                   a timeout.
#       
# Results:

proc ::Network::ScheduleKiller {sock cmd} {  
    variable killerId    
    variable opts

    if {[info exists killerId($sock)]} {
	after cancel $killerId($sock)
    }
    set killerId($sock) [after [expr 1000 * $opts(-timeout)]   \
      [list [namespace current]::Kill $sock $cmd]]
}

proc ::Network::Kill {sock cmd} {    
    variable killerId    

    catch {close $sock}
    if {[info exists killerId($sock)]} {
	after cancel $killerId($sock)
	unset -nocomplain killerId($sock)
    }
    
    # Evaluate our callback procedure.
    uplevel #0 $cmd [list $sock {} {} timeout]
}

# Network::KillAll --
#
#       Kills all pending open states.

proc ::Network::KillAll { } {
    variable killerId

    foreach sock [array names killerId] {
	catch {close $sock}
	after cancel $killerId($sock)
    }
    unset -nocomplain killerId
}

# Network::GetThisPublicIP --
#
#       Returns our own ip number unless set own NAT address.

proc ::Network::GetThisPublicIP { } {
    global  this prefs
    
    if {$prefs(setNATip) && ($prefs(NATip) ne "")} {
	return $prefs(NATip)
    } else {
	return $this(ipnum)
    }
}

#-------------------------------------------------------------------------------
