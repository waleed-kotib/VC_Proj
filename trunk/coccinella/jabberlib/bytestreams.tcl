#  bytestreams.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for the bytestreams protocol (XEP-0065).
#      
#  Copyright (c) 2005-2007  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: bytestreams.tcl,v 1.33 2007-11-30 14:38:34 matben Exp $
# 
############################# USAGE ############################################
#
#   NAME
#       bytestreams - implements the socks5 bytestream stream protocol.
#      
#   SYNOPSIS
#
#
#   OPTIONS
#
#	
#   INSTANCE COMMANDS
#   
#       jlibName bytestream configure ?-address -port -timeout ms -proxyhost?
#       jlibName bytestream send_initiate to sid cmd ?-streamhosts -fastmode?
#       
#      
############################# CHANGES ##########################################
#
#       0.1         first version
#       0.2         timeouts + fast mode
#       0.3         connector object
#       0.4         proxy support
#
# FAST MODE:
#   Some details:
#       "This is done by sending an additional [CR] character across the 
#       bytestream to indicate its selection."
#       The character is sent after socks5 authorization, and even after 
#       iq-streamhost-used, since the initiator must pick only a working stream.
#       If the desired stream is offered by the initiator, it would send the 
#       character only after receiving iq-streamhost-used from the target.  
#       If the desired stream is offered by the target, then the initiator 
#       would send the character after it sends iq-streamhost-used to the target.
#
#       When do we know to use the fast mode protocol?
#       (initiator):  received streamhost with sid we have initiated
#       (target):     receiving streamhost+fast and sent streamhost
#       
#       initiator                               target
#       ---------                               ------
#       
#                      streamhosts + fast
#                 --------------------------->
#                 
#                     streamhosts (fastmode)
#                 <---------------------------
#                 
#                        connector (s5)
#                 <---------------------------
#                 
#                     connector (s5) (fastmode)
#                 --------------------------->
#                 
#                       streamhost-used
#          sock   <---------------------------
#                 
#                  streamhost-used (fastmode)
#       sock_fast --------------------------->
#                 
#       Initiator picks one of 0-2 sockets and fastmode sends a CR.
#       
# HASH:
#       SHA1(SID + Initiator JID + Target JID)
#       The JIDs provided MUST be the JIDs used for the IQ exchange; 
#       furthermore, in order to ensure proper results, the appropriate 
#       stringprep profiles.
#       
# INITIATOR FLOW:
#       There are two different flows:
#           (1) iq query/response
#           (2) socks5 connections and negotiations, denoted s5 here
#       They interact and depend on each other. (f) means fast mode only.
#       As seen from the initiator:
# 
#           (a) iq-stream initiate (send)
#       (f) (b) iq-stream target provides streamhosts to initiator (recv)
#           (1) s5 socket to initiators server
#       (f) (2) s5 fast socket to targets streamhost
#           (3) s5 socket initiator to proxy
#           
#       iq-stream (a) controls (1) and (3)
#       iq-stream (b) controls (2)
#       
#       There are three possible s5 streams:
#           
#           (A) s5 (server) initiator <---  s5 (client) target
#       (f) (B) s5 (client) initiator  ---> s5 (server) target
#           (C) s5 (client) initiator  ---> s5 (server) proxy
#           
#       The first succesful stream wins and kills the other.
#       
# TARGET:
#       The target handles the (intiators) proxy like any other streamhost
#       and proxies are therefore transparent to the target.
#       
#       
# NOTES:
#       o If yoy are trying to follow this code, focus on one side alone,
#         initiator or target, else you are likely to get insane.

package require sha1
package require jlib
package require jlib::disco
package require jlib::si
                          
package provide jlib::bytestreams 0.4

#--- generic bytestreams -------------------------------------------------------

namespace eval jlib::bytestreams {

    variable xmlns
    set xmlns(bs)   "http://jabber.org/protocol/bytestreams"
    set xmlns(fast) "http://affinix.com/jabber/stream"
        
    jlib::si::registertransport $xmlns(bs) $xmlns(bs) 40  \
      [namespace current]::si_open   \
      [namespace current]::si_close    
    
    jlib::disco::registerfeature $xmlns(bs)
    
    # Support for http://affinix.com/jabber/stream.
    variable fastmode 1
    
    # Note: jlib::ensamble_register is last in this file!
}

# jlib::bytestreams::init --
# 
#       Instance init procedure.
  
proc jlib::bytestreams::init {jlibname args} {
    variable xmlns
        
    # Keep different state arrays for initiator (i) and receiver (t).
    namespace eval ${jlibname}::bytestreams {
	variable istate
	variable tstate

	# Mapper from SOCKS5 hash to sid.
	variable hash2sid
	
	# Independent of sid variables.
	variable static
	
	# Server port 0 says that arbitrary port can be chosen.
	set static(-address)        ""
	set static(-block-size)     4096
	set static(-port)           0
	set static(-s5timeoutms)    8000  ;# TODO
	set static(-timeoutms)      30000
	set static(-proxyhost)      [list]
	set static(-targetproxy)    0     ;# Not implemented
    }

    # Register standard iq handler that is handled internally.
    $jlibname iq_register set $xmlns(bs) [namespace current]::handle_set
    eval {configure $jlibname} $args
    
    return
}

proc jlib::bytestreams::cmdproc {jlibname cmd args} {

    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

proc jlib::bytestreams::configure {jlibname args} {
    
    upvar ${jlibname}::bytestreams::static static
    
    if {![llength $args]} {
	return [array get static -*]
    } else {
	foreach {key value} $args {
	    
	    switch -- $key {
		-address {
		    set static($key) $value
		}
		-port - -timeoutms {
		    if {![string is integer -strict $value]} {
			return -code error "$key must be integer number"
		    }
		    set static($key) $value
		}
		-proxyhost {
		    if {[llength $value]} {
			if {[llength $value] != 3} {
			    return -code error "$key must be a list {jid ip port}"
			}
			if {![string is integer -strict [lindex $value 2]]} {
			    return -code error "port must be an integer number"
			}
		    }
		    set static($key) $value
		}
		-targetproxy {
		    if {![string is boolean -strict $value]} {
			return -code error "$key must be integer number"
		    }
		    set static($key) $value
		}
		default {
		    return -code error "unknown option \"$key\""
		}
	    }
	}
    }
    return
}

# Common code for both initiator and target.

# jlib::bytestreams::i_or_t --
# 
#       In some situations we must know if we are the initiator or target
#       using just the sid.

proc jlib::bytestreams::i_or_t {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::istate istate
    upvar ${jlibname}::bytestreams::tstate tstate
    debug "jlib::bytestreams::i_or_t"
    
    if {[info exists istate($sid,state)]} {
	return "i"
    } elseif {[info exists tstate($sid,state)]} {
	return "t"
    } else {
	return ""
    }
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# These are all functions to use by a initiator (sender).

# si_open, si_close --
# 
#       Bindings for si.

# jlib::bytestreams::si_open --
# 
#       Constructor for an initiator object.

proc jlib::bytestreams::si_open {jlibname jid sid args} {
    
    variable fastmode
    upvar ${jlibname}::bytestreams::istate istate
    upvar ${jlibname}::bytestreams::static static
    upvar ${jlibname}::bytestreams::hash2sid hash2sid
    debug "jlib::bytestreams::si_open (i)"
    
    set jid [jlib::jidmap $jid]
    set istate($sid,jid) $jid
    
    if {![info exists static(sock)]} {
	
	# Protect against server failure.
	if {[catch {s5i_server $jlibname}]} {
	    si_open_report $jlibname $sid error  \
	      {error "Failed starting our streamhost"}
	    return
	}
    }
    
    # Provide our streamhosts. 
    # First, the local one.
    if {$static(-address) ne ""} {
	set ip $static(-address)
    } else {
	set ip [jlib::getip $jlibname]
    }
    set myjid [jlib::myjid $jlibname]
    set hash  [::sha1::sha1 $sid$myjid$jid]
    
    set istate($sid,ip)           $ip
    set istate($sid,state)        open
    set istate($sid,fast)         0
    set istate($sid,hash)         $hash
    set istate($sid,used-proxy)   0      ;# Set if target picks our proxy host
    set istate($sid,proxy,state)  ""
    
    set hash2sid($hash) $sid
    set host [list $myjid -host $ip -port $static(port)]
    set streamhosts [list $host]
    set opts [list]
    lappend opts -fastmode $fastmode
    
    # Second, the proxy host if any.
    if {[llength $static(-proxyhost)]} {
	lassign $static(-proxyhost) pjid pip pport
	set proxyhost [list $pjid -host $pip -port $pport]
	lappend streamhosts $proxyhost
	lappend opts -proxyjid $pjid
    }
    lappend opts -streamhosts $streamhosts
    
    # Schedule a timeout until we get a streamhost-used returned.
    set istate($sid,timeoutid) [after $static(-timeoutms)  \
      [list [namespace current]::si_timeout_cb $jlibname $sid]]
    
    # Initiate the stream to the target.
    set si_open_cb [list [namespace current]::si_open_cb $jlibname $sid]
    eval {send_initiate $jlibname $jid $sid $si_open_cb} $opts

    return
}

proc jlib::bytestreams::si_timeout_cb {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::istate istate
    debug "jlib::bytestreams::si_timeout_cb (i)"
    
    si_open_report $jlibname $sid "error" {timeout "Timeout"}
    ifinish $jlibname $sid
}

# jlib::bytestreams::si_open_cb --
# 
#       This is the iq-response we get as an initiator when sent our streamhosts
#       to the target. We expect that it either returns a 'streamhost-used'
#       or an error. 
#       We shall not return any iq as a response to this response.
# 
#       The target either returns an error if it failed to connect any
#       streamhost, else it replies eith a 'streamhost-used' element.
#       
#       This is the main event handler for the initiator where it manages
#       both open iq-streams as well as all sockets.
#       
#       See also 'i_connect_cb' for the fastmode side.

proc jlib::bytestreams::si_open_cb {jlibname sid type subiq args} {
    
    variable xmlns
    upvar ${jlibname}::bytestreams::istate istate
    upvar ${jlibname}::bytestreams::static static
    debug "jlib::bytestreams::si_open_cb (i) type=$type"
    
    # In fast mode we may get this callback after we have finished.
    # Or after a timeout or something.
    if {![info exists istate($sid,state)]} {
	return
    }

    # 'result' is normally the iq type but we add more error checking.
    # Try to catch possible error situations.
    set result $type
    set istate($sid,type)  $type
    set istate($sid,subiq) $subiq
    
    # Collect streamhost used. If this fails we need to catch it below.
    if {$type eq "result"} {
	if {[wrapper::gettag $subiq] eq "query"  \
	  && [wrapper::getattribute $subiq xmlns] eq $xmlns(bs)} {
	    set usedE [wrapper::getfirstchildwithtag $subiq "streamhost-used"]
	    if {[llength $usedE]} {
		set jidused [wrapper::getattribute $usedE "jid"]
		set istate($sid,streamhost-used) $jidused
		
		# Need to know if target picked our proxy streamhost.
		set jidproxy [lindex $static(-proxyhost) 0]
		if {[jlib::jidequal $jidused $jidproxy]} {
		    set istate($sid,used-proxy) 1
		}
	    }
	}
    }
    debug "\t used-proxy=$istate($sid,used-proxy)"
    
    # Must end the normal path if the target sent us weird response.
    if {![info exists istate($sid,streamhost-used)]} {
	set istate($sid,state) error    
	set istate($sid,subiq) {error "missing streamhost-used"}
    }
    if {$result eq "error"} {
	set istate($sid,state) error    
    }
    
    # NB1: We may already have picked fast mode and istate($sid,state) = error
    #      Even if the normal path succeded!
    # NB2: We can never pick fast mode from this proc!
    
    # Fastmode only:
    if {$istate($sid,fast)} {	
	if {$istate($sid,state) eq "error"} {
	    ifast_error_normal $jlibname $sid
	} else {
	    if {$istate($sid,used-proxy)} {
		
		# Now its time to start up and activate our proxy host.
		iproxy_connect $jlibname $sid
	    } else {
		ifast_select_normal $jlibname $sid
		ifast_end_fast $jlibname $sid
	    }
	}
    } else {	
	
	# Normal non-fastmode execution path.
	if {$result eq "error"} {
	    if {[info exists istate($sid,sock)]} {
		debug_sock "close $istate($sid,sock)"
		catch {close $istate($sid,sock)}
		unset istate($sid,sock)
	    }
	    si_open_report $jlibname $sid $type $istate($sid,subiq)
	} else {
	    
	    if {$istate($sid,used-proxy)} {
		
		# Now its time to start up and activate our proxy host.
		iproxy_connect $jlibname $sid
	    } else {
		
		# One last check that we actually got a socket connection.
		# Try to catch possible error situations.
		if {![info exists istate($sid,sock)]} {
		    set istate($sid,state) error
		    si_open_report $jlibname $sid error {error "Network Error"}
		} else {

		    # Everything is fine.
		    set istate($sid,state) streamhost-used    
		    set istate($sid,active,sock) $istate($sid,sock)
		    si_open_report $jlibname $sid $type $subiq
		}
	    }
	}
    }
}

# jlib::bytestreams::ifast_* --
# 
#       A number of methods to handle execution paths for the fast mode.
#       They are normally called for iq-responses, but for the proxy they are
#       called after activate response.
#       Selects the first succesful stream and kills the others. 
#       If all streams have failed we report the error to si.
#       
#       NB1: ifast_* means that we are in fast mode; the suffix normally 
#            indicates which stream we are dealing with.
#       NB2: we do not send any iq response here, which should only be done when
#            calling 'ifast_select_fast'.

proc jlib::bytestreams::ifast_error_normal {jlibname sid} {

    upvar ${jlibname}::bytestreams::istate istate
    debug "jlib::bytestreams::ifast_error_normal (i)"
    
    # The target failed the 'normal' s5 connection.
    # Be sure to close normal and proxy sockets, (1) and (3) above.
    set istate($sid,state) error
    if {[info exists istate($sid,sock)]} {
	debug_sock "close $istate($sid,sock)"
	catch {close $istate($sid,sock)}
	unset istate($sid,sock)
    }
    if {$istate($sid,used-proxy)} {
	connector_reset $jlibname $sid p
	if {[info exists istate($sid,proxy,sock)]} {
	    debug_sock "close $istate($sid,proxy,sock)"
	    catch {close $istate($sid,proxy,sock)}
	    unset istate($sid,proxy,sock)
	}
    }
    
    # If also the 'fast' way failed we are done.
    if {$istate($sid,fast,state) eq "error"} {
	si_open_report $jlibname $sid error $istate($sid,subiq)
    }
    
    # At this stage we may already have activated the fast stream.
}

proc jlib::bytestreams::ifast_select_normal {jlibname sid} {

    upvar ${jlibname}::bytestreams::istate istate
    debug "jlib::bytestreams::ifast_select_normal (i)"
    
    # Activate the 'normal' stream:
    # Protect us from failed socks5 connections.
    # This can be our own streamhost or the proxy host. Handle both here!
    # Normally the target picks the one it wants.

    debug "\t used-proxy=$istate($sid,used-proxy), proxy,state=$istate($sid,proxy,state)"
    set have_s5 0
    if {$istate($sid,used-proxy) && $istate($sid,proxy,state) eq "result"} {
	set sock $istate($sid,proxy,sock)
	set have_s5 1
    } elseif {[info exists istate($sid,sock)]} {
	set sock $istate($sid,sock)
	set have_s5 1
    }    
    if {$have_s5} {
	set istate($sid,state) activated
	debug "\t select normal, send CR"
	if {[catch {
	    puts -nonewline $sock "\r"
	    flush $sock
	}]} {
	    set have_s5 0
	}
    }
    if {$have_s5} {
	set istate($sid,active,sock) $sock
	si_open_report $jlibname $sid result $istate($sid,subiq)	
    } else {
	debug "\t error missing s5 stream or failed send CR"
	set istate($sid,state) error    
	si_open_report $jlibname $sid error {error "Network Error"}
    }
}

proc jlib::bytestreams::ifast_end_fast {jlibname sid} {

    upvar ${jlibname}::bytestreams::istate istate
    debug "jlib::bytestreams::ifast_end_fast (i)"
		
    # Put an end to any 'fast' stream. Both socket and iq-stream.
    set istate($sid,fast,state) error    
    connector_reset $jlibname $sid f
    if {[info exists istate($sid,fast,sock)]} {
	debug_sock "close $istate($sid,fast,sock)"
	catch {close $istate($sid,fast,sock)}
	unset istate($sid,fast,sock)
    }
    
    # This just informs the target that our 'fast' stream is shut down.
    if {[info exists istate($sid,fast,id)]} {
	isend_error $jlibname $sid 404 cancel item-not-found
    }      
}

proc jlib::bytestreams::ifast_select_fast {jlibname sid} {

    upvar ${jlibname}::bytestreams::istate istate
    debug "jlib::bytestreams::ifast_select_fast (i)"
    

    # Activate the fast stream. Set normal stream to error so we wont use it.
    debug "\t select fast, send CR"
    set sock $istate($sid,fast,sock)
    set istate($sid,active,sock) $sock
    set istate($sid,fast,state) activated
    if {[catch {
	puts -nonewline $sock "\r"
	flush $sock
    }]} {
	debug "\t failed sending CR"
	si_open_report $jlibname $sid error {error "Network Failure"}
    } else {
    
	# Shut down the 'normal' stream:
	# Must close down any connections to our own streamhost.
	set istate($sid,state) error   
	if {[info exists istate($sid,sock)]} {
	    debug_sock "close $istate($sid,sock)"
	    catch {close $istate($sid,sock)}
	    unset istate($sid,sock)
	}
	si_open_report $jlibname $sid result {ok OK}
    }
}

#...............................................................................

# jlib::bytestreams::si_open_report --
# 
#       This prepares the callback to 'si' as a response to 'si_open.

proc jlib::bytestreams::si_open_report {jlibname sid type subiq} {
    
    upvar ${jlibname}::bytestreams::istate istate
    upvar ${jlibname}::bytestreams::static static
    debug "jlib::bytestreams::si_open_report (i)"
   
    if {[info exists istate($sid,timeoutid)]} {
	after cancel $istate($sid,timeoutid)
	unset istate($sid,timeoutid)
    }
    jlib::si::transport_open_cb $jlibname $sid $type $subiq
    
    # If all went well this far we initiate the read/write data process.
    if {$type eq "result"} {
	
	# Tell the profile to prepare to read data (open file).
	jlib::si::open_data $jlibname $sid
	
	# Initiate the transport when socket is ready for writing.
	set sock $istate($sid,active,sock)
	setwritable $jlibname $sid $sock
    }
}

# jlib::bytestreams::si_read --
# 
#       Read data from the profile via 'si' using its registered reader.

proc jlib::bytestreams::si_read {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::istate istate
    debug "jlib::bytestreams::si_read (i)"

    # NB: This should be safe to do since if we have been reset also
    #     the fileevent handler is removed when socket is closed.
    set s $istate($sid,active,sock)
    
    fileevent $s writable {}    
    if {[catch {eof $s} iseof] || $iseof} {
	jlib::si::close_data $jlibname $sid error
	return
    }
    set data [jlib::si::read_data $jlibname $sid]
    set len [string length $data]

    if {$len > 0} {
	if {[catch {puts -nonewline $s $data}]} {
	    debug "\t failed"
	    jlib::si::close_data $jlibname $sid error
	    return
	}
	
	# Trick to avoid UI blocking.
	after idle [list after 0 [list \
	  [namespace current]::setwritable $jlibname $sid $s]]
    } else {
	
	# Empty data from the reader means that we are done.
	jlib::si::close_data $jlibname $sid
    }
}

proc jlib::bytestreams::setwritable {jlibname sid sock} {
    
    # We could have been closed since this event comes async.
    if {[lsearch [file channels] $sock] >= 0} {
	fileevent $sock writable  \
	  [list [namespace current]::si_read $jlibname $sid]
    }
}

# jlib::bytestreams::si_close --
# 
#       Destroys an initiator object.

proc jlib::bytestreams::si_close {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::istate istate
    debug "jlib::bytestreams::si_close (i)"
    
    # We don't have any particular to do here as 'ibb' has.
    jlib::si::transport_close_cb $jlibname $sid result {}
    ifinish $jlibname $sid
}

proc jlib::bytestreams::is_initiator {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::istate istate
    debug "jlib::bytestreams::is_initiator [info exists istate($sid,state)]"
    
    return [info exists istate($sid,state)]
}

#--- Generic initiator code ----------------------------------------------------

# jlib::bytestreams::send_initiate --
# 
#       -streamhosts {{jid (-host -port | -zeroconf)} {...} ...}
#       -fastmode
#       
#       Stateless code that never access the istate array.

proc jlib::bytestreams::send_initiate {jlibname to sid cmd args} {
    variable xmlns    
    debug "jlib::bytestreams::initiate"

    set attrlist [list xmlns $xmlns(bs) sid $sid mode tcp]
    set sublist [list]
    set opts [list]
    set proxyjid ""
    foreach {key value} $args {
	
	switch -- $key {
	    -streamhosts {
		set streamhosts $value
	    }
	    -fastmode {
		if {$value} {

		    # <fast xmlns="http://affinix.com/jabber/stream"/> 
		    lappend sublist [wrapper::createtag "fast"  \
		      -attrlist [list xmlns $xmlns(fast)]]
		}
	    }
	    -proxyjid {
		# Mark proxy: <proxy xmlns="http://affinix.com/jabber/stream"/> 
		set proxyjid $value
	    }
	    default {
		return -code error "unknown option \"$key\""
	    }
	}
    }
    
    # Need to do it here in order to handle any proxy element.
    if {[info exists streamhosts]} {
	foreach hostspec $streamhosts {
	    set jid [lindex $hostspec 0]
	    set hostattr [list jid $jid]
	    foreach {hkey hvalue} [lrange $hostspec 1 end] {
		lappend hostattr [string trimleft $hkey -] $hvalue
	    }
	    set ssub [list]
	    if {[jlib::jidequal $proxyjid $jid]} {
		set ssub [list [wrapper::createtag proxy \
		  -attrlist [list xmlns $xmlns(fast)]]]
	    }
	    lappend sublist [wrapper::createtag "streamhost" \
	      -attrlist $hostattr -subtags $ssub]
	}
    }
    
    set xmllist [wrapper::createtag "query" \
      -attrlist $attrlist -subtags $sublist]
    eval {$jlibname send_iq "set" [list $xmllist] -to $to -command $cmd} $opts
    return
}

proc jlib::bytestreams::get_proxy {jlibname to cmd} {
    variable xmlns
    debug "jlib::bytestreams::get_proxy (i)"

    $jlibname iq_get $xmlns(bs) -to $to -command $cmd
}

# jlib::bytestreams::activate --
# 
#       Initiator requests activation of bytestream.
#       This is only necessary for proxy streamhosts.

proc jlib::bytestreams::activate {jlibname sid to targetjid args} {
    variable xmlns
    debug "jlib::bytestreams::activate (i)"
    
    set opts [list]
    foreach {key value} $args {
	switch -- $key {
	    -command {
		set opts [list -command $value]
	    }
	    default {
		return -code error "unknown option \"$key\""
	    }
	}
    }
    set activateE [wrapper::createtag "activate" -chdata $targetjid]
    set xmllist [wrapper::createtag "query" \
      -attrlist [list xmlns $xmlns(bs) sid $sid] \
      -subtags [list $activateE]]

    eval {$jlibname send_iq "set" [list $xmllist] -to $to} $opts
}

#--- Fastmode: handle targets streamhosts --------------------------------------

# jlib::bytestreams::i_handle_set --
# 
#       This is the initiators handler when provided streamhosts by the
#       target which only happens in fastmode.
#       Fastmode only!

proc jlib::bytestreams::i_handle_set {jlibname sid id jid hosts queryE} {

    upvar ${jlibname}::bytestreams::istate istate
    debug "jlib::bytestreams::i_handle_set (i)"
    
    # We have already initiated this sid and must have fastmode.
    # At this stage we run in the fast mode!
    set istate($sid,fast)        1
    set istate($sid,fast,id)     $id
    set istate($sid,fast,jid)    $jid
    set istate($sid,fast,state)  inited
    set istate($sid,fast,hosts)  $hosts
    set istate($sid,fast,queryE) $queryE

    set myjid [$jlibname myjid]
    set hash [::sha1::sha1 $sid$jid$myjid]    

    # Try connecting the host(s) in turn.
    set cb [list [namespace current]::i_connect_cb $jlibname $sid]
    connector $jlibname $sid f $hash $hosts $cb
}

# jlib::bytestreams::i_connect_cb --
# 
#       The 'connector' callback when tried to connect to the targets streamhosts. 
#       We shall return an iq response to the targets iq streamhost offer.
#       Fastmode only!

proc jlib::bytestreams::i_connect_cb {jlibname sid result args} {
    
    upvar ${jlibname}::bytestreams::istate istate
    debug "jlib::bytestreams::i_connect_cb $result (i)"
    
    array set argsA $args
    
    if {$result eq "error"} {
	set istate($sid,fast,state) error
	
	# Deliver error to target.
	isend_error $jlibname $sid 404 cancel item-not-found
	
	# In fastmode we are not done until the target also fails connecting.
	if {!$istate($sid,fast) || ($istate($sid,state) eq "error")} {

	    # Deliver error to target profile.
	    si_open_report $jlibname $sid error {error "Network Failure"}
	}
    } elseif {$istate($sid,fast,state) ne "error"} {
	
	# Must be sure that the normal stream hasn't already put a stop at fast.
	# Shouldn't be needed since it should do connector_reset.
	set sock $argsA(-socket)
	set host $argsA(-streamhost)
	set hostjid [lindex $host 0]
	
	# Deliver 'streamhost-used' to the target.
	set id  $istate($sid,fast,id)
	set jid $istate($sid,fast,jid)
	send_used $jlibname $jid $id $hostjid
	
	set istate($sid,fast,sock)    $sock
	set istate($sid,fast,host)    $host
	set istate($sid,fast,hostjid) $hostjid
	
	ifast_select_fast $jlibname $sid
    }
}

# Proxy handling ---------------------------------------------------------------

# This is done as a response that the target has selected the proxy streamhost.
# There are two steps here:
#   1) initiator make a complete socks5 connection to the proxy
#   2) the stream is activated by the initiator

proc jlib::bytestreams::iproxy_connect {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::istate istate
    upvar ${jlibname}::bytestreams::static static
    debug "jlib::bytestreams::iproxy_connect (i)"
    
    set istate($sid,state) connecting    
    set myjid [$jlibname myjid]
    set jid $istate($sid,jid)
    set hash [::sha1::sha1 $sid$myjid$jid] 
    set hosts [list $static(-proxyhost)]

    set cb [list [namespace current]::iproxy_s5_cb $jlibname $sid]
    connector $jlibname $sid p $hash $hosts $cb    
}

proc jlib::bytestreams::iproxy_s5_cb {jlibname sid result args} {

    upvar ${jlibname}::bytestreams::istate istate
    upvar ${jlibname}::bytestreams::static static
    debug "jlib::bytestreams::iproxy_s5_cb (i) $result $args"
    
    array set argsA $args
    
    if {$result eq "error"} {	
	if {$istate($sid,fast)} {
 	    ifast_error_normal $jlibname $sid
	} else {

	    # If not fastmode we are finito.
 	    set istate($sid,state) error
	    if {[info exists istate($sid,sock)]} {
		debug_sock "close $istate($sid,sock)"
		catch {close $istate($sid,sock)}
		unset istate($sid,sock)
	    }
	    si_open_report $jlibname $sid error {error "Network Error"}
	}
    } else {
	
	# Allright so far, cache socket.
	# Note that we need a specific variable for this since the target can
	# connect our server: istate($sid,sock).
	set istate($sid,proxy,sock) $argsA(-socket)
	set proxyjid [lindex $static(-proxyhost) 0]
	set jid $istate($sid,jid)
	set cb [list [namespace current]::iproxy_activate_cb $jlibname $sid]
	activate $jlibname $sid $proxyjid $jid -command $cb
    }
}

proc jlib::bytestreams::iproxy_activate_cb {jlibname sid type subiq args} {

    upvar ${jlibname}::bytestreams::istate istate
    debug "jlib::bytestreams::iproxy_activate_cb (i) type=$type"
    
    set istate($sid,proxy,state) $type
    set istate($sid,type) $type
    set istate($sid,subiq) $subiq
    
    if {$istate($sid,fast)} {	
	
	# When we get this response the fast mode may already have succeded.
	if {$istate($sid,state) eq "error"} {
	    ifast_error_normal $jlibname $sid
	} else {
	    ifast_select_normal $jlibname $sid
	    ifast_end_fast $jlibname $sid
	}
    } else {	
	if {$type eq "error"} {

	    # If not fastmode we are finito.
	    set istate($sid,state) error
	} else {
	
	    # Everything is fine.
	    set istate($sid,state) streamhost-used    
	    set istate($sid,active,sock) $istate($sid,proxy,sock)
	}
	si_open_report $jlibname $sid $type $subiq
    }
}    

# Server side socks5 functions -------------------------------------------------
# 
# Normally used by the initiator except in fastmode where it is also used by
# the target.
# This is stateless code that never directly access the istate array.
# Think of it like an object:
#       [in]:  sock, addr, port
#       [out]: sid, sock
#       
# NB: We don't return any errors on the server side; this is up to the client.

# jlib::bytestreams::s5i_server --
# 
#       Start socks5 server. We use the server for the streams and keep it
#       running for the lifetime of the application.

proc jlib::bytestreams::s5i_server {jlibname} {
    
    upvar ${jlibname}::bytestreams::static static
    debug "jlib::bytestreams::s5i_server (i)"
    
    # Note the difference between static(-port) and static(port) !
    set connectProc [list [namespace current]::s5i_accept $jlibname]
    set sock [socket -server $connectProc $static(-port)]
    set static(sock) $sock
    set static(port) [lindex [fconfigure $sock -sockname] 2]
    
    # Test fast mode or proxy host...
    #close $sock
    return $static(port)
}

# jlib::bytestreams::s5i_accept --
# 
#       The server socket callback when connected.
#       We keep a single server socket for all transfers and distinguish
#       them when they do the SOCKS5 authentication using the mapping
#       hash (sha1 sid+jid+myjid)  -> sid

proc jlib::bytestreams::s5i_accept {jlibname sock addr port} {

    debug "jlib::bytestreams::s5i_accept (i)"
    debug_sock "open $sock"
    
    fconfigure $sock -translation binary -blocking 0
    fileevent $sock readable \
      [list [namespace current]::s5i_read_methods $jlibname $sock]
}

proc jlib::bytestreams::s5i_read_methods {jlibname sock} {
   
    debug "jlib::bytestreams::s5i_read_methods (i)" 
    # For testing...
    #after 50
    
    fileevent $sock readable {}
    if {[catch {read $sock} data] || [eof $sock]} {
	debug_sock "close $sock"
	catch {close $sock}
	return
    }
    debug "\t read [string length $data]"
    
    # Pick method. Must be \x00
    binary scan $data ccc* ver nmethods methods
    if {($ver != 5) || ([lsearch -exact $methods 0] < 0)} {
	catch {
	    debug_sock "close $sock"
	    puts -nonewline $sock "\x05\xff"
	    close $sock
	}
	return
    }
    if {[catch {
	puts -nonewline $sock "\x05\x00"
	flush $sock
	debug "\t wrote 2: 'x05x00'"
    }]} {
	return
    }
    fileevent $sock readable \
      [list [namespace current]::s5i_read_auth $jlibname $sock]
}

proc jlib::bytestreams::s5i_read_auth {jlibname sock} {
    
    upvar ${jlibname}::bytestreams::hash2sid hash2sid
    debug "jlib::bytestreams::s5i_read_auth (i)"

    fileevent $sock readable {}
    if {[catch {read $sock} data] || [eof $sock]} {
	debug_sock "close $sock"
	catch {close $sock}
	return
    }    
    debug "\t read [string length $data]"
    
    binary scan $data ccccc ver cmd rsv atyp len
    if {$ver != 5 || $cmd != 1 || $atyp != 3} {
	set reply [string replace $data 1 1 \x07]
	catch {
	    debug_sock "close $sock"
	    puts -nonewline $sock $reply
	    close $sock
	}	
	return
    }
    
    binary scan $data @5a${len} hash
    
    # At this stage we are in a position to find the sid.
    if {[info exists hash2sid($hash)]} {
	set sid $hash2sid($hash)
	
	# This is the way the initiator knows the socket.
	s5i_register_socket $jlibname $sid $sock

	set reply [string replace $data 1 1 \x00]
	catch {
	    puts -nonewline $sock $reply
	    flush $sock
	}
	debug "\t wrote [string length $reply]"
    } else {
	debug "\t missing sid"
	set reply [string replace $data 1 1 \x02]
	catch {
	    debug_sock "close $sock"
	    puts -nonewline $sock $reply
	    close $sock
	}	
	return
    }
}

# jlib::bytestreams::s5i_register_socket --
# 
#       This is a callback when a client has connected and authentized
#       with our server. Normally we are the initiator but in fastmode
#       we may also be the target.
#       Since the server handles connections async it needs this method to
#       communicate.

proc jlib::bytestreams::s5i_register_socket {jlibname sid sock} {
    
    variable fastmode
    upvar ${jlibname}::bytestreams::istate istate
    upvar ${jlibname}::bytestreams::tstate tstate
    debug "jlib::bytestreams::s5i_register_socket"
    
    if {$fastmode && [info exists tstate($sid,fast,state)]} {
	debug "\t (t)"
	if {$tstate($sid,fast,state) ne "error"} {
	    set tstate($sid,fast,sock)  $sock
	    set tstate($sid,fast,state) connected
	}
    } elseif {[info exists istate($sid,state)]} {
	debug "\t (i)"
	if {$istate($sid,state) ne "error"} {
	    set istate($sid,sock)  $sock
	    set istate($sid,state) connected
	}
    } else {
	debug "\t empty"
	# We may have been reset (timeout) or something.
    }
}

# End s5i ----------------------------------------------------------------------

# jlib::bytestreams::isend_error --
# 
#       Deliver iq error to target as a response to the targets streamhosts.
#       Fastmode only!

proc jlib::bytestreams::isend_error {jlibname sid errcode errtype stanza} {

    upvar ${jlibname}::bytestreams::istate istate
    debug "jlib::bytestreams::isend_error (i)"
    
    set id  $istate($sid,fast,id)
    set jid $istate($sid,fast,jid)
    set qE  $istate($sid,fast,queryE)
    jlib::send_iq_error $jlibname $jid $id $errcode $errtype $stanza $qE 
}

# jlib::bytestreams::ifinish --
# 
#       Close all sockets and make sure to free all memory.

proc jlib::bytestreams::ifinish {jlibname sid} {

    upvar ${jlibname}::bytestreams::istate istate
    debug "jlib::bytestreams::ifinish (i)"

    # Skip any ongoing socks5 connections.
    if {$istate($sid,used-proxy)} {
	connector_reset $jlibname $sid p
    }
    if {$istate($sid,fast)} {
	connector_reset $jlibname $sid f
    }
    
    # Close socket.
    if {[info exists istate($sid,sock)]} {
	debug_sock "close $istate($sid,sock)"
	catch {close $istate($sid,sock)}
    }
    if {[info exists istate($sid,fast,sock)]} {
	debug_sock "close $istate($sid,fast,sock)"
	catch {close $istate($sid,fast,sock)}
    }
    if {[info exists istate($sid,proxy,sock)]} {
	debug_sock "close $istate($sid,proxy,sock)"
	catch {close $istate($sid,proxy,sock)}
    }
    ifree $jlibname $sid
}

# jlib::bytestreams::ifree --
# 
#       Releases all memory for an initiator object.

proc jlib::bytestreams::ifree {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::istate istate
    upvar ${jlibname}::bytestreams::hash2sid hash2sid
    debug "jlib::bytestreams::ifree (i)"

    if {[info exists istate($sid,hash)]} {
	set hash $istate($sid,hash)
	unset -nocomplain hash2sid($hash)
    }
    array unset istate $sid,*
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# These are all functions to use by a target (receiver) of a stream.

# jlib::bytestreams::handle_set --
# 
#       Handler for incoming iq-set element with xmlns 
#       "http://jabber.org/protocol/bytestreams".
#       
#       Initiator sends IQ-set to Target specifying the full JID and network 
#       address of StreamHost/Initiator as well as the StreamID (SID) of the 
#       proposed bytestream. 
#    
#       For fastmode this can be either initiator or target.
#       It is stateless and only dispatches the iq to the target normally,
#       but can also be the initiator in case of fastmode.
#       
# Result:
#       MUST return 0 or 1!

proc jlib::bytestreams::handle_set {jlibname from queryE args} {
    variable xmlns    
    variable fastmode
    
    debug "jlib::bytestreams::handle_set (t+i)"
    
    array set argsA $args
    array set attr [wrapper::getattrlist $queryE]
    if {![info exists argsA(-id)]} {
	# We cannot handle this since missing id-attribute.
	return 0
    }
    if {![info exists attr(sid)]} {
	eval {return_error $jlibname $queryE 400 modify bad-request} $args
	return 1
    }
    set id  $argsA(-id)
    set sid $attr(sid)
    set jid $from

    # We make sure that we have already got a si with this sid.
    if {![jlib::si::havesi $jlibname $sid]} {
	eval {return_error $jlibname $queryE 406 cancel not-acceptable} $args
	return 1
    }

    # Get streamhosts keeping their order.
    set hosts [list]
    foreach elem [wrapper::getchildswithtag $queryE "streamhost"] {
	array unset sattr
	array set sattr [wrapper::getattrlist $elem]
	if {[info exists sattr(jid)]    \
	  && [info exists sattr(host)]  \
	  && [info exists sattr(port)]} {
	    lappend hosts [list $sattr(jid) $sattr(host) $sattr(port)]
	}
    }
    debug "\t hosts=$hosts"
    if {![llength $hosts]} {
	eval {return_error $jlibname $queryE 400 modify bad-request} $args
	return 1
    }
    
    # In fastmode we may get a streamhosts offer for reversed socks5 connections.
    if {[is_initiator $jlibname $sid]} {
	if {$fastmode} {
	    i_handle_set $jlibname $sid $id $jid $hosts $queryE
	} else {
	    # @@@ inconsistency!
	    return 0
	}
    } else {
	
	# This is the normal execution path.
	t_handle_set $jlibname $sid $id $jid $hosts $queryE
    }
    return 1
}

# jlib::bytestreams::t_handle_set --
# 
#       This is like the constructor of a target sid object.

proc jlib::bytestreams::t_handle_set {jlibname sid id jid hosts queryE} {
    variable fastmode
    variable xmlns
    
    upvar ${jlibname}::bytestreams::tstate tstate
    upvar ${jlibname}::bytestreams::static static
    upvar ${jlibname}::bytestreams::hash2sid hash2sid
    debug "jlib::bytestreams::t_handle_set (t)"
    
    set tstate($sid,id)     $id
    set tstate($sid,jid)    $jid
    set tstate($sid,fast)   0
    set tstate($sid,state)  open
    set tstate($sid,hosts)  $hosts
    set tstate($sid,queryE) $queryE
    
    if {$fastmode} {
	set fastE [wrapper::getchildswithtagandxmlns $queryE "fast" $xmlns(fast)]
	if {[llength $fastE]} {
	    
	    set haveserver 1
	    if {![info exists static(sock)]} {

		# Protect against server failure.
		if {[catch {s5i_server $jlibname}]} {
		    set haveserver 0
		}
	    }
	    
	    # At this stage we switch to use the fast mode protocol.
	    if {$haveserver} {
		set tstate($sid,fast) 1
		set tstate($sid,fast,state) initiate
		
		# Provide our streamhosts. 
		# First, the local one.
		if {$static(-address) ne ""} {
		    set ip $static(-address)
		} else {
		    set ip [jlib::getip $jlibname]
		}
		set myjid [jlib::myjid $jlibname]
		set hash  [::sha1::sha1 $sid$myjid$jid]
		set tstate($sid,hash) $hash
		set hash2sid($hash) $sid
		
		# @@@ Is there a point that also the target provides a
		#     proxy streamhost?
		# If the clients are using different servers, one may have a 
		# proxy while the other has not.
		# Keep it optional (-targetproxy).
		set host [list $myjid -host $ip -port $static(port)]
		set streamhosts [list $host]
		
		# Second, the proxy host if any.
		if {$static(-targetproxy) && [llength $static(-proxyhost)]} {
		    lassign $static(-proxyhost) pjid pip pport
		    set proxyhost [list $pjid -host $pip -port $pport]
		    lappend streamhosts $proxyhost
		}
		
		set t_initiate_cb  \
		  [list [namespace current]::t_initiate_cb $jlibname $sid]
		send_initiate $jlibname $jid $sid $t_initiate_cb \
		  -streamhosts $streamhosts
	    }
	}
    }

    # Try connecting the host(s) in turn.
    set tstate($sid,state) connecting    
    set myjid [$jlibname myjid]
    set hash [::sha1::sha1 $sid$jid$myjid]    

    set cb [list [namespace current]::connect_cb $jlibname $sid]
    connector $jlibname $sid t $hash $hosts $cb
}

# jlib::bytestreams::connect_cb --
# 
#       Callback command from 'connector' object when tried socks5 connections
#       to initiators streamhosts.

proc jlib::bytestreams::connect_cb {jlibname sid result args} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    debug "jlib::bytestreams::connect_cb (t)"

    array set argsA $args
    
    if {$result eq "error"} {
	set tstate($sid,state) error
	
	# Deliver error to initiator.
	tsend_error $jlibname $sid 404 cancel item-not-found
	
	# In fastmode we are not done until the fast mode also fails.
	if {!$tstate($sid,fast) || ($tstate($sid,fast,state) eq "error")} {

	    # Deliver error to target profile.
	    jlib::si::stream_error $jlibname $sid item-not-found
	    tfinish $jlibname $sid
	}
    } else {
	set sock $argsA(-socket)
	set host $argsA(-streamhost)
	set hostjid [lindex $host 0]

	set tstate($sid,sock)    $sock
	set tstate($sid,host)    $host
	set tstate($sid,hostjid) $hostjid

	set jid $tstate($sid,jid)
	set id  $tstate($sid,id)
	send_used $jlibname $jid $id $hostjid
	
	# If fast mode we must wait for a CR before start reading.
	if {$tstate($sid,fast)} {

	    # Wait for initiator send a CR for selection or just close it.
	    set tstate($sid,state) waiting-cr
	    set cmd_cr [list [namespace current]::read_CR_cb $jlibname $sid]
	    fileevent $sock readable  \
	      [list [namespace current]::read_CR $sock $cmd_cr]

	} else {
	    start_read_data $jlibname $sid $sock
	}
    }
}

proc jlib::bytestreams::t_initiate_cb {jlibname sid type subiq args} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    debug "jlib::bytestreams::t_initiate_cb (t) type=$type"

    # In fast mode we may get this callback after we have finished.
    # Or after a timeout or something.
    if {![info exists tstate($sid,state)]} {
	return
    }

    if {$type eq "error"} {
	
	# Cleanup and close any fast socks5 connection.
	set tstate($sid,fast,state) error
	if {[info exists tstate($sid,fast,sock)]} {
	    debug_sock "close $tstate($sid,fast,sock)"
	    catch {close $tstate($sid,fast,sock)}
	    unset tstate($sid,fast,sock)
	}
	
	# If also the standard way failed we are done.
	if {$tstate($sid,state) eq "error"} {
	    jlib::si::stream_error $jlibname $sid item-not-found
	    tfinish $jlibname $sid
	}
    } else {
    
	# Wait for initiator send a CR for selction or just close it.
	debug "\t waiting CR"
	set tstate($sid,fast,state) waiting-cr
	set sock $tstate($sid,fast,sock)
	set cmd_cr [list [namespace current]::fast_read_CR_cb $jlibname $sid]
	fileevent $sock readable  \
	  [list [namespace current]::read_CR $sock $cmd_cr]
    }
}

proc jlib::bytestreams::read_CR {sock cmd} {

    debug "jlib::bytestreams::read_CR (t)"

    fileevent $sock readable {}
    if {[catch {read $sock 1} data] || [eof $sock]} {
	debug "\t eof"
	catch {close $sock}
	eval $cmd error
    } elseif {$data ne "\r"} {
	debug "\t not CR"
	catch {close $sock}
	eval $cmd error
    } else {
	debug "\t got CR"
	eval $cmd
    }
}

proc jlib::bytestreams::fast_read_CR_cb {jlibname sid {error ""}} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    debug "jlib::bytestreams::fast_read_CR_cb (t) error=$error"
    
    if {$error ne ""} {
	set tstate($sid,fast,state) error
	unset -nocomplain tstate($sid,fast,sock)		

	# If also the standard way failed we are done.
	if {$tstate($sid,state) eq "error"} {
	    jlib::si::stream_error $jlibname $sid item-not-found
	    tfinish $jlibname $sid
	}
    } else {
    
	# At this stage we are using reversed transport (fast mode).
	# We are using the targets (our own) streamhost.
	connector_reset $jlibname $sid t
	if {[info exists tstate($sid,sock)]} {
	    debug_sock "close $tstate($sid,sock)"
	    catch {close $tstate($sid,sock)}
	    unset tstate($sid,sock)
	}
	
	# Deliver error to initiator unless not done so.
	if {$tstate($sid,state) ne "error"} {
	    tsend_error $jlibname $sid 404 cancel item-not-found
	}
	set tstate($sid,state)         error
	set tstate($sid,fast,selected) fast
	set tstate($sid,fast,state)    read

	start_read_data $jlibname $sid $tstate($sid,fast,sock)
    }
}

#...............................................................................

proc jlib::bytestreams::read_CR_cb {jlibname sid {error ""}} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    debug "jlib::bytestreams::read_CR_cb (t) error=$error"
    
    if {$error ne ""} {	
	set tstate($sid,state) error
	unset -nocomplain tstate($sid,sock)

	# If also the fast mode failed this is The End.
	if {$tstate($sid,fast) && ($tstate($sid,fast,state) eq "error")} {
	    jlib::si::stream_error $jlibname $sid item-not-found
	    tfinish $jlibname $sid
	}
    } else {
	if {[info exists tstate($sid,fast,sock)]} {
	    debug_sock "close $tstate($sid,fast,sock)"
	    catch {close $tstate($sid,fast,sock)}
	    unset tstate($sid,fast,sock)
	}
	set sock $tstate($sid,sock)

	set tstate($sid,fast,selected) normal
	set tstate($sid,state)  read
	
	start_read_data $jlibname $sid $sock
    }
}

proc jlib::bytestreams::start_read_data {jlibname sid sock} {
    
    upvar ${jlibname}::bytestreams::static static

    fconfigure $sock -buffersize $static(-block-size) -buffering full
    fileevent $sock readable  \
      [list [namespace current]::readable $jlibname $sid $sock]
}

# End connect_socks ------------------------------------------------------------

# jlib::bytestreams::readable --
# 
#       Reads channel and delivers data up to si.

proc  jlib::bytestreams::readable {jlibname sid sock} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    upvar ${jlibname}::bytestreams::static static
    debug "jlib::bytestreams::readable (t)"

    fileevent $sock readable {}

    # We may have been reset or something.
    if {![jlib::si::havesi $jlibname $sid]} {
	tfinish $jlibname $sid
	return
    }
    
    if {[catch {eof $sock} iseof] || $iseof} {
	debug "\t eof"
	# @@@ Perhaps we should check number of bytes reveived or something???
	#     If the initiator closes socket before transfer is complete
	#     we wont notice this otherwise.
	jlib::si::stream_closed $jlibname $sid
	tfinish $jlibname $sid
    } else {
	
	# @@@ Keep tranck of number bytes read?
	set data [read $sock $static(-block-size)]
	set len [string length $data]
	debug "\t len=$len"
    
	# Deliver to si for further processing.
	jlib::si::stream_recv $jlibname $sid $data
	
	# This is a trick to put this event at the back of the queue to
	# avoid using any 'update'.
	after idle [list after 0 [list \
	  [namespace current]::setreadable $jlibname $sid $sock]]
    }
}

proc jlib::bytestreams::setreadable {jlibname sid sock} {
    
    # We could have been closed since this event comes async.
    if {[lsearch [file channels] $sock] >= 0} {
	fileevent $sock readable  \
	  [list [namespace current]::readable $jlibname $sid $sock]
    }
}

# jlib::bytestreams::send_used --
# 
#       Target (also initiator in fast mode) notifies initiator of connection.

proc jlib::bytestreams::send_used {jlibname to id hostjid} {
    variable xmlns
    
    set usedE [wrapper::createtag "streamhost-used" \
      -attrlist [list jid $hostjid]]
    set xmllist [wrapper::createtag "query" \
      -attrlist [list xmlns $xmlns(bs)] \
      -subtags [list $usedE]]

    $jlibname send_iq "result" [list $xmllist] -to $to -id $id
}

# The client socks5 functions --------------------------------------------------
# 
# Normally used by the target but in fastmode also used by the initiator.
#
# This object handles everything to make a single socks5 connection + 
# authentication.
#       [in]:  addr, port, hash, cmd
#       [out]: sock, result

# jlib::bytestreams::socks5 --
# 
#       Open a client socket to the specified host and port and announce method.
#       This must be kept stateless.

proc jlib::bytestreams::socks5 {addr port hash cmd} {

    debug "jlib::bytestreams::socks5 (t)"
    
    if {[catch {
	set sock [socket -async $addr $port]
    } err]} {
	return -code error $err
    }
    debug_sock "open $sock"
    fconfigure $sock -translation binary -blocking 0
    fileevent $sock writable  \
      [list [namespace current]::s5t_write_method $hash $sock $cmd]
    return $sock
}

proc jlib::bytestreams::s5t_write_method {hash sock cmd} {
    
    debug "jlib::bytestreams::s5t_write_method (t)"
    fileevent $sock writable {}
    
    # Announce method (\x00).
    if {[catch {
	puts -nonewline $sock "\x05\x01\x00"
	flush $sock
	debug "\t wrote 3: 'x05x01x00'"
    } err]} {
	catch {close $sock}
	eval $cmd error-network-write
	return
    }
    fileevent $sock readable  \
      [list [namespace current]::s5t_method_result $hash $sock $cmd]
}

proc jlib::bytestreams::s5t_method_result {hash sock cmd} {
    
    debug "jlib::bytestreams::s5t_method_result (t)"
    
    fileevent $sock readable {}
    if {[catch {read $sock} data] || [eof $sock]} {
	catch {close $sock}
	eval $cmd error-network-read
	return
    }    
    debug "\t read [string length $data]"
    binary scan $data cc ver method
    if {($ver != 5) || ($method != 0)} {
	catch {close $sock}
	eval $cmd error-socks5
	return
    }
    set len [binary format c [string length $hash]]
    if {[catch {
	puts -nonewline $sock "\x05\x01\x00\x03$len$hash\x00\x00"
	flush $sock
	debug "\t wrote [string length "\x05\x01\x00\x03$len$hash\x00\x00"]: 'x05x01x00x03${len}${hash}x00x00'"
    } err]} {
	catch {close $sock}
	eval $cmd error-network-write
	return
    }
    fileevent $sock readable \
      [list [namespace current]::s5t_auth_result $sock $cmd]
}

proc jlib::bytestreams::s5t_auth_result {sock cmd} {
    
    debug "jlib::bytestreams::s5t_auth_result (t)"
    
    fileevent $sock readable {}
    if {[catch {read $sock} data] || [eof $sock]} {
	catch {close $sock}
	eval $cmd error-network-read
	return
    }
    debug "\t read [string length $data]"
    binary scan $data cc ver method
    if {($ver != 5) || ($method != 0)} {
	catch {close $sock}
	eval $cmd error-socks5
	return
    }

    # Here we should be finished.
    eval $cmd
}

# End s5t ----------------------------------------------------------------------

# jlib::bytestreams::return_error, tsend_error --
# 
#       Various helper functions to return errors.

proc jlib::bytestreams::return_error {jlibname qElem errcode errtype stanza args} {
    
    array set attr $args
    set id  $attr(-id)
    set jid $attr(-from)
    jlib::send_iq_error $jlibname $jid $id $errcode $errtype $stanza $qElem
}

proc jlib::bytestreams::tsend_error {jlibname sid errcode errtype stanza} {

    upvar ${jlibname}::bytestreams::tstate tstate
    debug "jlib::bytestreams::tsend_error (t)"
    
    set id  $tstate($sid,id)
    set jid $tstate($sid,jid)
    set qE  $tstate($sid,queryE)
    jlib::send_iq_error $jlibname $jid $id $errcode $errtype $stanza $qE 
}

proc jlib::bytestreams::tfinish {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    debug "jlib::bytestreams::tfinish (t)"
    
    # Close socket.
    if {[info exists tstate($sid,sock)]} {
	debug_sock "close $tstate($sid,sock)"
	catch {close $tstate($sid,sock)}
    }
    if {[info exists tstate($sid,fast,sock)]} {
	debug_sock "close $tstate($sid,fast,sock)"
	catch {close $tstate($sid,fast,sock)}
    }
    if {[info exists tstate($sid,timeoutid)]} {
	after cancel $tstate($sid,timeoutid)
    }
    tfree $jlibname $sid
}

proc jlib::bytestreams::tfree {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    upvar ${jlibname}::bytestreams::hash2sid hash2sid
    debug "jlib::bytestreams::tfree (t)"

    if {[info exists tstate($sid,hash)]} {
	set hash $tstate($sid,hash)
	unset -nocomplain hash2sid($hash)
    }
    array unset tstate $sid,*
}

# We have to do it here since need the initProc before doing this.

namespace eval jlib::bytestreams {
	
    jlib::ensamble_register bytestreams  \
      [namespace current]::init          \
      [namespace current]::cmdproc
}

# connector --------------------------------------------------------------------

# jlib::bytestreams::connector --
# 
#       Standalone object which is target and initiator agnostic that tries
#       to make socks5 connections to the hosts in turn. Invokes the callback
#       for the first succesful connection or an error if none worked.
#       The 'sid' is the characteristic identifier of an object.
#       It sets its own timeouts. Needs also a unique 'key' if using multiple
#       connectors for one sid.
#       
#       NB1: SHA1(SID + Initiator JID + Target JID)
#       NB2: the initiator may have two connector objects if fast + proxy.
#       
#       [in]:  sid, key, hash, hosts, cmd
#       [out]: result (-error | -host -socket)

proc jlib::bytestreams::connector {jlibname sid key hash hosts cmd} {
    
    upvar ${jlibname}::bytestreams::conn conn
    debug "jlib::bytestreams::connector $key"
    
    set x $sid,$key
    set conn($x,hosts) $hosts
    set conn($x,cmd)   $cmd
    set conn($x,hash)  $hash
    set conn($x,idx)   [expr {[llength $hosts]-1}]
    
    connector_sock $jlibname $sid $key
    return
}

# jlib::bytestreams::connector_sock --
# 
#       Tries to make a socks5 connection to streamhost with 'idx' index.
#       If 'idx' goes negative we report an error.

proc jlib::bytestreams::connector_sock {jlibname sid key} {
    
    upvar ${jlibname}::bytestreams::conn conn
    upvar ${jlibname}::bytestreams::static static
    debug "jlib::bytestreams::connector_sock $key"
    
    set x $sid,$key
    if {[info exists conn($x,timeoutid)]} {
	after cancel $conn($x,timeoutid)
	unset conn($x,timeoutid)
    }
    if {$conn($x,idx) < 0} {
	connector_final $jlibname $sid $key "error"
	return
    }
    set conn($x,timeoutid) [after $static(-s5timeoutms)  \
      [list [namespace current]::connector_timeout_cb $jlibname $sid $key]]
    
    set host [lindex $conn($x,hosts) $conn($x,idx)]
    lassign $host hostjid addr port
    debug "\t host=$host"
    set s5_cb [list [namespace current]::connector_s5_cb $jlibname $sid $key]
    if {[catch {
	set conn($x,sock) [socks5 $addr $port $conn($x,hash) $s5_cb]
    }]} {
	
	# Retry with next streamhost if any.
	incr conn($x,idx) -1
	connector_sock $jlibname $sid $key
    }
}

proc jlib::bytestreams::connector_s5_cb {jlibname sid key {err ""}} {
        
    upvar ${jlibname}::bytestreams::conn conn
    debug "jlib::bytestreams::connector_s5_cb $key err=$err"
    
    set x $sid,$key
    if {$err eq ""} {
	connector_final $jlibname $sid $key
    } else {
	incr conn($x,idx) -1
	connector_sock $jlibname $sid $key
    }
}

proc jlib::bytestreams::connector_timeout_cb {jlibname sid key} {
	
    upvar ${jlibname}::bytestreams::conn conn
    debug "jlib::bytestreams::connector_timeout_cb $key"

    # On timeouts we are responsible for closing the socket.
    set x $sid,$key
    unset conn($x,timeoutid)
    if {[info exists conn($x,sock)]} {
	debug_sock "close $conn($x,sock)"
	catch {close $conn($x,sock)}
	unset conn($x,sock)
    }
    incr conn($x,idx) -1
    connector_sock $jlibname $sid $key
}

proc jlib::bytestreams::connector_reset {jlibname sid key} {
	
    upvar ${jlibname}::bytestreams::conn conn
    debug "jlib::bytestreams::connector_reset $key"
    
    # Protect for nonexisting connector object.
    set x $sid,$key
    if {![info exists conn($x,cmd)]} {
	return
    }
    if {[info exists conn($x,timeoutid)]} {
	after cancel $conn($x,timeoutid)
	unset conn($x,timeoutid)
    }
    if {[info exists conn($x,sock)]} {
	debug_sock "close $conn($x,sock)"
	catch {close $conn($x,sock)}
	unset conn($x,sock)
    }
    connector_final $jlibname $sid $key "reset"
}

proc jlib::bytestreams::connector_final {jlibname sid key {err ""}} {
    
    upvar ${jlibname}::bytestreams::conn conn
    debug "jlib::bytestreams::connector_final err=$err"

    set x $sid,$key
    if {[info exists conn($x,timeoutid)]} {
	after cancel $conn($x,timeoutid)
	unset conn($x,timeoutid)
    }
    set cmd $conn($x,cmd)
    if {$err eq ""} {
	set host [lindex $conn($x,hosts) $conn($x,idx)]
	eval $cmd ok -streamhost $host -socket $conn($x,sock)
    } else {
	
	# Skip callback when we have reset. ?
	if {$err ne "reset"} {
	    eval $cmd error -error $err
	}
    }
    array unset conn $x,*
}

proc jlib::bytestreams::debug {msg} {if {0} {puts $msg}}

proc jlib::bytestreams::debug_sock {msg} {if {0} {puts $msg}}

#-------------------------------------------------------------------------------

if {0} {
    # Testing the 'connector'
    set jlib ::jlib::jlib1
    set port [$jlib bytestreams s5i_server]
    set hosts [list \
      [list proxy.localhost junk.se 8237] \
      [list matben@localhost 127.0.0.1 $port]]
    proc cb {args} {puts "---> $args"}
    set sid [jlib::generateuuid]
    set myjid [$jlib myjid]
    set jid killer@localhost/coccinella
    set hash [::sha1::sha1 $sid$myjid$jid]    
    $jlib bytestreams connector $sid $hash $hosts cb
 
    # Testing proxy:
    # 1) get proxy
    set jlib ::jlib::jlib1
    proc pcb {jlib type queryE} {
	puts "---> $jlib $type $queryE"
	set hostE [wrapper::getfirstchildwithtag $queryE "streamhost"]
	array set attr [wrapper::getattrlist $hostE]
	set ::proxyHost $attr(host)
	set ::proxyPort $attr(port)
    }
    set proxy proxy.jabber.se
    $jlib bytestreams get_proxy $proxy pcb
    $jlib bytestreams configure -proxyhost [list $proxy $proxyHost $proxyPort]

    # 2) socks5 connection
    set sid [jlib::generateuuid]
    set myjid [$jlib myjid]
    set jid killer@jabber.se/coccinella
    set hash [::sha1::sha1 $sid$myjid$jid]  
    set hosts [list [list $proxy $proxyHost $proxyPort]]
    $jlib bytestreams connector $sid $hash $hosts cb

    # 3) activate
    $jlib bytestreams activate $sid $proxy $jid
    
}


