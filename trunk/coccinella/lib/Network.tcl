#  Network.tcl ---
#  
#      This file is part of the whiteboard application. 
#      It implements some network utilities.
#      
#  Copyright (c) 2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Network.tcl,v 1.3 2003-04-28 13:32:32 matben Exp $

namespace eval ::Network:: {
    
    variable debug 0
}

# Network::OpenConnection --
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
#                   -tls     boolean 
#       
# Results:
#       only via the callback cmd.

proc ::Network::OpenConnection {nameOrIP port cmd args} {
    global  errorCode
    
    variable debug
    variable opts
    
    if {$debug > 1} {
	puts "::Network::OpenConnection, nameOrIP=$nameOrIP, port=$port"
    }
    array set opts {
	-timeout 60
	-tls     0
    }
    array set opts $args
    if {$opts(-tls)} {
	set socketCmd {::tls::socket -request 0 -require 0}
    } else {
	set socketCmd socket
    }
    
    # Try opening socket async.
    if {[catch {eval $socketCmd {-async $nameOrIP $port}} sock]} {
	uplevel #0 "$cmd [list {} $nameOrIP $port error $sock]"
	return {}
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
      $port $cmd $opts(-tls)]
    
    # Set up timer event for timeouts.
    OpenConnectionScheduleKiller $sock $cmd
    return {}
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
	catch {unset killerId($sock)}
    }

    if {[eof $sock]} {
	catch {close $sock}
	set msg "Failed to open network socket to $nameOrIP."
	uplevel #0 "$cmd [list $sock $nameOrIP $port error $msg]"
	return
    }
    
    # Detecting failure to connect, at least needed on linux.
    # The jabber server gives: <stream:error>Invalid XML</stream:error>
    if {0 && [catch {puts -nonewline $sock { }} msg]} {
	set msg "Failed to open network socket to $nameOrIP."
	uplevel #0 "$cmd [list $sock $nameOrIP $port error $msg]"
	return
    }
    
    # Check if something went wrong first.
    if {[catch {fconfigure $sock -sockname} sockname]} {
	uplevel #0 "$cmd [list $sock $nameOrIP $port error $sockname]"
	return
    }
    
    # Do SSL handshake.
    if {$tls} {
	fconfigure $sock -blocking 1
	if {[catch {::tls::handshake $sock} msg]} {
	    catch {close $sock}
	    uplevel #0 "$cmd [list $sock $nameOrIP $port error $msg]"
	    return
	}
	fconfigure $sock -blocking 0
    }
    
    # Evaluate our callback procedure.
    uplevel #0 "$cmd [list $sock $nameOrIP $port ok]"
}

# OpenConnectionScheduleKiller, OpenConnectionKill --
#
#       Cancel 'OpenConnection' process if timeout.
#       Should probably go in ::OpenConnection:: in the future.
#
# Arguments:
#       sock
#       cmd         Specific callback proc for this open operation if we get
#                   a timeout.
#       
# Results:

proc ::Network::OpenConnectionScheduleKiller {sock cmd} {  
    variable killerId    
    variable opts

    if {[info exists killerId($sock)]} {
	after cancel $killerId($sock)
    }
    set killerId($sock) [after [expr 1000*$opts(-timeout)]   \
      [list [namespace current]::OpenConnectionKill $sock $cmd]]
}

proc ::Network::OpenConnectionKill {sock cmd} {    
    variable killerId    

    catch {close $sock}
    if {[info exists killerId($sock)]} {
	after cancel $killerId($sock)
	catch {unset killerId($sock)}
    }
    
    # Evaluate our callback procedure.
    uplevel #0 "$cmd [list $sock {} {} timeout]"
}

# Network::OpenConnectionKillAll --
#
#       Kills all pending open states.
#       Should probably go in ::OpenConnection:: in the future.

proc ::Network::OpenConnectionKillAll { } {
    variable killerId

    foreach sock [array names killerId] {
	after cancel $killerId($sock)
    }
    catch {unset killerId}
}

# Network::GetThisOutsideIPAddress --
#
#       Returns our own ip number unless set own NAT address.

proc ::Network::GetThisOutsideIPAddress { } {
    global  this prefs
    
    if {$prefs(setNATip) && ($prefs(NATip) != "")} {
	return $prefs(NATip)
    } else {
	return $this(ipnum)
    }
}

# Network::RegisterIP --
# 
#       Sets ip number for internal use.
#   
# Arguments:
#       ipNum       ip number to be de/registered
#       type        any of 'none', 'to', 'from', 'both'

proc ::Network::RegisterIP {ipNum {type "both"}} {
    global  prefs allIPnumsToSend allIPnums allIPnumsTo
    
    switch -- $prefs(protocol) {
	jabber {
	    switch -- $type {
		both - to {
		    set allIPnumsTo $ipNum
		    set allIPnumsToSend $ipNum
		    set allIPnums $ipNum
		}
		none {
		    set allIPnumsTo {}
		    set allIPnumsToSend {}
		    set allIPnums {}
		}
	    }
	}
	symmetric {
	    # To Do.
	}
	client {
	    # To Do.
	}
	server {
	    # To Do.
	}
    }
}

# These one need another home??? ...............................................

# SendClientCommand --
#
#       Sends to command to whoever we are connected to. If jabber, we send
#       XML code, else our own protocol.
#   
# Arguments:
#       wtop
#       cmd         the command (line) to send which must be protocol compliant.
#       args   ?-key value ...?
#       -ips         (D=$allIPnumsToSend) send to this list of ip numbers. 
#                    Not for jabber.
#       -force 0|1  (D=1) overrides the doSend checkbutton in jabber.
#       
# Results:
#       none

proc SendClientCommand {wtop cmd args} {
    global  allIPnumsToSend ipNumTo prefs
    
    array set opts [list -ips $allIPnumsToSend -force 0]
    array set opts $args
    
    if {[string equal $prefs(protocol) "jabber"]} {
	::Jabber::SendWhiteboardMessage $wtop $cmd -force $opts(-force)
    } else {
	foreach ip $opts(-ips) {
	    if {[catch {
		puts $ipNumTo(socket,$ip) $cmd
	    }]} {
		tk_messageBox -type ok -title [::msgcat::mc {Network Error}] \
		  -icon error -message  \
		  [FormatTextForMessageBox [::msgcat::mc messfailsend $ip]]
	    }
	}
    }
}

# SendClientCommandList --
#
#       As 'SendClientCommand' but accepts a list of commands.

proc SendClientCommandList {wtop cmdList args} {
    global  allIPnumsToSend ipNumTo prefs
    
    array set opts [list -ips $allIPnumsToSend -force 0]
    array set opts $args

    if {[string equal $prefs(protocol) "jabber"]} {
	::Jabber::SendWhiteboardMessageList $wtop $cmdList -force $opts(-force)
    } else {
	foreach ip $opts(-ips) {
	    if {[catch {
		foreach cmd $cmdList {
		    puts $ipNumTo(socket,$ip) $cmd
		}
	    }]} {
		tk_messageBox -type ok -title [::msgcat::mc {Network Error}] \
		  -icon error -message  \
		  [FormatTextForMessageBox [::msgcat::mc messfailsend $ip]]
	    }
	}
    }
}

#-------------------------------------------------------------------------------
