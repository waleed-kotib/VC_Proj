#  bytestreams.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for the bytestreams protocol (XEP-0065).
#      
#  Copyright (c) 2005-2006  Mats Bengtsson
#  
# $Id: bytestreams.tcl,v 1.23 2006-12-13 15:14:28 matben Exp $
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
#       jlibName bytestream ...
#      
############################# CHANGES ##########################################
#
#       0.1         first version
#       0.2         timeouts + fast mode
#       

# TODO: 
#   o The fast mode is a terrible mess. Try to rewrite it in a more OO way,
#     likely using separate objects for all socket connections which are
#     also initiator/target agnostic.
#   o Self contained connector object that does all socks5 connections,
#     see the end of this file.
#   o Try to use i/t specific managers which get events for iq, s5 etc.

# Preliminary support for the so called fast mode.
# Some details:
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
#                     streamhosts + fast
#                 --------------------------->
#                 
#                         streamhosts
#                 <---------------------------
#                 
#                      connect_host (s5)
#                 <---------------------------
#                 
#                     i_connect_host (s5)
#                 --------------------------->
#                 
#                       streamhost-used
#          sock   <---------------------------
#                 
#                       streamhost-used
#       sock_fast --------------------------->
#                 
#       Initiator picks one of 0-2 sockets and sends a CR.

package require sha1
package require jlib
package require jlib::disco
package require jlib::si
                          
package provide jlib::bytestreams 0.1

#--- generic bytestreams -------------------------------------------------------

namespace eval jlib::bytestreams {

    variable xmlns
    set xmlns(bs)   "http://jabber.org/protocol/bytestreams"
    set xmlns(fast) "http://affinix.com/jabber/stream"
        
    jlib::si::registertransport $xmlns(bs) $xmlns(bs) 40  \
      [namespace current]::si_open   \
      [namespace current]::si_send   \
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
	set static(-port)      0
	set static(-address)   ""
	set static(-timeoutms) 30000
    }

    # Register some standard iq handlers that is handled internally.
    $jlibname iq_register set $xmlns(bs) [namespace current]::handle_set

    return
}

proc jlib::bytestreams::cmdproc {jlibname cmd args} {

    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

proc jlib::bytestreams::configure {jlibname args} {
    
    upvar ${jlibname}::bytestreams::static static

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
	    default {
		return -code error "unknown option \"$key\""
	    }
	}
    }
}

# Common code for both initiator and target.

# jlib::bytestreams::i_or_t --
# 
#       In some situations we must know if we are the initiator or target
#       using just the sid.

proc jlib::bytestreams::i_or_t {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::istate istate
    upvar ${jlibname}::bytestreams::tstate tstate
    #puts "jlib::bytestreams::i_or_t"
    
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

# jlib::bytestreams::si_open, si_send, si_close --
# 
#       Bindings for si.

proc jlib::bytestreams::si_open {jlibname jid sid args} {
    
    variable fastmode
    upvar ${jlibname}::bytestreams::istate istate
    upvar ${jlibname}::bytestreams::static static
    upvar ${jlibname}::bytestreams::hash2sid hash2sid
    #puts "jlib::bytestreams::si_open (i)"
    
    set istate($sid,jid) $jid
    
    if {![info exists static(sock)]} {
	
	# Protect against server failure.
	if {[catch {s5i_server $jlibname}]} {
	    si_open_report $jlibname $sid error  \
	      {error "Failed starting our streamhost"}
	    return
	}
    }
    
    if {$static(-address) ne ""} {
	set ip $static(-address)
    } else {
	set ip [jlib::getip $jlibname]
    }
    set myjid [jlib::myjid $jlibname]
    set hash  [::sha1::sha1 ${sid}${myjid}${jid}]
    
    set istate($sid,ip)    $ip
    set istate($sid,state) open
    set istate($sid,fast)  0
    set istate($sid,hash)  $hash
    set hash2sid($hash)    $sid
    set host [list $myjid -host $ip -port $static(port)]

    # Schedule a timeout until we get a streamhost-used returned.
    set istate($sid,timeoutid) [after $static(-timeoutms)  \
      [list [namespace current]::si_timeout_cb $jlibname $sid]]
    
    set si_open_cb [list [namespace current]::si_open_cb $jlibname $sid]
    initiate $jlibname $jid $sid $si_open_cb -streamhost $host  \
      -fastmode $fastmode

    return
}

proc jlib::bytestreams::si_timeout_cb {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::istate istate
    #puts "jlib::bytestreams::si_timeout_cb (i)"
    
    si_open_report $jlibname $sid "error" {timeout "Timeout"}
    ifinish $jlibname $sid
}

proc jlib::bytestreams::si_open_cb {jlibname sid type subiq args} {
    
    variable xmlns
    upvar ${jlibname}::bytestreams::istate istate
    #puts "jlib::bytestreams::si_open_cb (i) type=$type"
    
    # In fast mode we may get this callback after we have finished.
    # Or after a timeout or something.
    if {![info exists istate($sid,state)]} {
	return
    }
        
    # Collect streamhost used.
    if {$type eq "result"} {
	if {[wrapper::gettag $subiq] eq "query"  \
	  && [wrapper::getattribute $subiq xmlns] eq $xmlns(bs)} {
	    set usedElem [wrapper::getfirstchildwithtag $subiq "streamhost-used"]
	    if {$usedElem ne {}} {
		set istate($sid,streamhost-used)  \
		  [wrapper::getattribute $usedElem "jid"]
	    }
	}
    }
    
    if {$istate($sid,fast)} {
	if {$type eq "error"} {
	    set istate($sid,state) error    
	    if {[info exists istate($sid,sock)]} {
		catch {close $istate($sid,sock)}
		unset istate($sid,sock)
	    }

	    # If also the fast way failed we are done.
	    if {$istate($sid,fast,state) eq "error"} {
		si_open_report $jlibname $sid $type $subiq
		ifinish $jlibname $sid
	    }

	    # At this stage we may already have activated the fast stream.
	} elseif {$istate($sid,state) ne "error"} {
	    
	    # Activate the stream:

	    # Protect us from failed socks5 connections.
	    set have_s5 0
	    if {[info exists istate($sid,sock)]} {
		set have_s5 1
		set sock $istate($sid,sock)
		set istate($sid,active,sock) $sock
		set istate($sid,state) activated
		#puts "\t send CR"
		if {[catch {
		    puts -nonewline $sock "\r"
		    flush $sock
		}]} {
		    set have_s5 0
		}
	    }
	    if {!$have_s5} {
		#puts "\t error missing istate(sid,sock) or failed send CR"
		set istate($sid,state) error    
		si_open_report $jlibname $sid error {error "Network Error"}
	    }
	    
	    # Put an end to any fast stream. Both socket and iq-stream.
	    set istate($sid,fast,state) error    
	    if {[info exists istate($sid,fast,sock)]} {
		catch {close $istate($sid,fast,sock)}
		unset istate($sid,fast,sock)
	    }
	    
	    # Must also send an error to the targets iq-stream.
	    if {[info exists istate($sid,fast,id)]} {
		set id  $istate($sid,fast,id)
		set jid $istate($sid,fast,jid)
		set qel $istate($sid,fast,queryElem)
		$jlibname send_iq_error $jid $id 404 cancel item-not-found $qel 		
	    }
	    si_open_report $jlibname $sid $type $subiq
	}
    } else {	
	if {$type eq "error"} {
	    set istate($sid,state) error    
	    si_open_report $jlibname $sid $type $subiq
	} else {
	    
	    # Protect us from failed socks5 connections.
	    if {[info exists istate($sid,sock)]} {
		set istate($sid,state) streamhost-used    
		set istate($sid,active,sock) $istate($sid,sock)
		si_open_report $jlibname $sid $type $subiq
	    } else {
		set istate($sid,state) error    
		si_open_report $jlibname $sid error {error "Network Error"}
	    }
	}
    }
}

proc jlib::bytestreams::si_open_report {jlibname sid type subiq} {
    
    upvar ${jlibname}::bytestreams::istate istate
    #puts "jlib::bytestreams::si_open_report (i)"
   
    if {[info exists istate($sid,timeoutid)]} {
	after cancel $istate($sid,timeoutid)
	unset istate($sid,timeoutid)
    }
    jlib::si::transport_open_cb $jlibname $sid $type $subiq
}

proc jlib::bytestreams::si_send {jlibname sid data} {
    
    upvar ${jlibname}::bytestreams::istate istate
    #puts "jlib::bytestreams::si_send (i)"
    #puts "\t len=[string length $data]"
    
    set s $istate($sid,active,sock)
    if {[catch {puts -nonewline $s $data}]} {
	jlib::si::transport_send_data_error_cb $jlibname $sid
	ifinish $jlibname $sid
    }
}

proc jlib::bytestreams::si_close {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::istate istate
    #puts "jlib::bytestreams::si_close (i)"
    
    jlib::si::transport_close_cb $jlibname $sid result {}
    ifinish $jlibname $sid
}

proc jlib::bytestreams::is_initiator {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::istate istate
    #puts "jlib::bytestreams::is_initiator [info exists istate($sid,state)]"
    
    return [info exists istate($sid,state)]
}

#--- Generic initiator code ----------------------------------------------------

# jlib::bytestreams::s5i_server --
# 
#       Start socks5 server.

proc jlib::bytestreams::s5i_server {jlibname} {
    
    upvar ${jlibname}::bytestreams::static static
    #puts "jlib::bytestreams::s5i_server (i)"
    
    # Note the difference between static(-port) and static(port) !
    set connectProc [list [namespace current]::s5i_accept $jlibname]
    set sock [socket -server $connectProc $static(-port)]
    set static(sock) $sock
    set static(port) [lindex [fconfigure $sock -sockname] 2]
    
    # Test fast mode...
    #close $sock
}

# jlib::bytestreams::initiate --
# 
#       -streamhost {jid (-host -port | -zeroconf)}
#       -fastmode
#       
#       Stateless code that never access the istate array.

proc jlib::bytestreams::initiate {jlibname to sid cmd args} {
    variable xmlns    
    #puts "jlib::bytestreams::initiate (i)"

    set attrlist [list xmlns $xmlns(bs) sid $sid mode tcp]
    set sublist {}
    set opts {}
    foreach {key value} $args {
	
	switch -- $key {
	    -streamhost {
		set jid [lindex $value 0]
		set hostattr [list jid $jid]
		foreach {hkey hvalue} [lrange $value 1 end] {
		    lappend hostattr [string trimleft $hkey -] $hvalue
		}
		lappend sublist \
		  [wrapper::createtag "streamhost" -attrlist $hostattr]
	    }
	    -fastmode {
		if {$value} {

		    # <fast xmlns="http://affinix.com/jabber/stream"/> 
		    lappend sublist [wrapper::createtag "fast"  \
		      -attrlist [list xmlns $xmlns(fast)]]
		}
	    }
	    default {
		return -code error "unknown option \"$key\""
	    }
	}
    }
    
    set xmllist [wrapper::createtag "query" -attrlist $attrlist \
      -subtags $sublist]
    eval {$jlibname send_iq "set" [list $xmllist] -to $to -command $cmd} $opts

    return
}

# jlib::bytestreams::i_handle_set --
# 
#       This is the initiators handler when provided streamhosts by the
#       target which only happens in fastmode.

proc jlib::bytestreams::i_handle_set {jlibname sid id jid hosts queryElem} {

    upvar ${jlibname}::bytestreams::istate istate
    #puts "jlib::bytestreams::i_handle_set (i)"
    
    # We have already initiated this sid and must have fastmode.
    # At this stage we run in the fast mode!
    set istate($sid,fast)        1
    set istate($sid,fast,id)     $id
    set istate($sid,fast,jid)    $jid
    set istate($sid,fast,state)  inited
    set istate($sid,fast,hosts)  $hosts
    set istate($sid,fast,rhosts) $hosts
    set istate($sid,fast,queryElem) $queryElem
     
    # Try connecting the host(s) in turn.
    i_connect_host $jlibname $sid
}

#...............................................................................

# jlib::bytestreams::i_connect_host --
# 
#       Is called recursively for each host until socks5 connection established.
#       This is only for fast mode where the initiator connects the targets
#       streamhosts.

proc jlib::bytestreams::i_connect_host {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::istate istate
    #puts "jlib::bytestreams::i_connect_host (i)"
    
    set rhosts $istate($sid,fast,rhosts)
    if {![llength $rhosts]} {
	i_connect_host_final $jlibname $sid error
	return
    }

    # Pick first host in rhost list.
    set host [lindex $rhosts 0]
    lassign $host hostjid addr port
    
    # Pop this host from list of hosts.
    set istate($sid,fast,rhosts)  [lrange $rhosts 1 end]
    set istate($sid,fast,host)    $host
    set istate($sid,fast,hostjid) $hostjid
    
    set jid $istate($sid,fast,jid)
    set myjid [$jlibname myjid]
    set hash [::sha1::sha1 ${sid}${jid}${myjid}]    
    
    set cmd [list [namespace current]::i_connect_host_cb $jlibname $sid]
    if {[catch {
	set istate($sid,fast,sock) [socks5 $addr $port $hash $cmd]
    } err]} {
	
	# Try next one if any.
	#puts "\t err=$err"
	i_connect_host $jlibname $sid
    }
}

proc jlib::bytestreams::i_connect_host_cb {jlibname sid {errmsg ""}} {
    
    upvar ${jlibname}::bytestreams::istate istate
    #puts "jlib::bytestreams::i_connect_host_cb (i) errmsg=$errmsg"
    
    if {[string length $errmsg]} {
	i_connect_host $jlibname $sid
    } else {
	i_connect_host_final $jlibname $sid
    }
}

proc jlib::bytestreams::i_connect_host_final {jlibname sid {error ""}} {
    
    upvar ${jlibname}::bytestreams::istate istate
    #puts "jlib::bytestreams::i_connect_host_final (i) error=$error"

    if {$error ne ""} {
	set istate($sid,fast,state) error
	
	# Deliver error to target.
	send_error $jlibname $sid 404 cancel item-not-found
	
	# In fastmode we are not done until the target also fails connecting.
	# if {$istate($sid,state) eq "error"}
	if {!$istate($sid,fast) || ($istate($sid,state) eq "error")} {

	    # Deliver error to target profile.
	    si_open_report $jlibname $sid error {error "Network Failure"}
	    ifinish $jlibname $sid
	}
    } else {
	set id      $istate($sid,fast,id)
	set jid     $istate($sid,fast,jid)
	set hostjid $istate($sid,fast,hostjid)
	set sock    $istate($sid,fast,sock)
	send_used $jlibname $jid $id $hostjid

	# Activate the stream.
	#puts "\t send CR"
	set istate($sid,active,sock) $sock
	set istate($sid,fast,state) activated
	set istate($sid,state) error   
	if {[catch {
	    puts -nonewline $sock "\r"
	    flush $sock
	}]} {
	    #puts "\t failed sending CR"
	    si_open_report $jlibname $sid error {error "Network Failure"}
	    ifinish $jlibname $sid
	} else {
	
	    # Must close down any connections to our own streamhost.
	    if {[info exists istate($sid,sock)]} {
		catch {close $istate($sid,sock)}
		unset istate($sid,sock)
	    }
	    si_open_report $jlibname $sid result {ok OK}
	}
    }
}

#...............................................................................

# The initiator socks5 functions -----------------------------------------------
# 
# This is stateless code that never directly access the istate array.
# Think of it like an object:
#       [in]:  sock, addr, port
#       [out]: sid, sock

# jlib::bytestreams::s5i_accept --
# 
#       The server socket callback when connected.
#       We keep a single server socket for all transfers and distinguish
#       them when they do the SOCKS5 authentication using the mapping
#       hash (sha1 sid+jid+myjid)  -> sid

proc jlib::bytestreams::s5i_accept {jlibname sock addr port} {

    #puts "jlib::bytestreams::s5i_accept (i)"
    
    fconfigure $sock -translation binary -blocking 0

    fileevent $sock readable \
      [list [namespace current]::s5i_read_methods $jlibname $sock]
}

proc jlib::bytestreams::s5i_read_methods {jlibname sock} {
   
    #puts "jlib::bytestreams::s5i_read_methods (i)"   
    
    fileevent $sock readable {}
    if {[catch {read $sock} data] || [eof $sock]} {
	catch {close $sock}
	return
    }
    #puts "\t read [string length $data]"
    
    # Pick method. Must be \x00
    binary scan $data ccc* ver nmethods methods
    if {($ver != 5) || ([lsearch -exact $methods 0] < 0)} {
	catch {
	    puts -nonewline $sock "\x05\xff"
	    close $sock
	}
	return
    }
    if {[catch {
	puts -nonewline $sock "\x05\x00"
	flush $sock
	#puts "\t wrote 2: 'x05x00'"
    }]} {
	return
    }
    fileevent $sock readable \
      [list [namespace current]::s5i_read_auth $jlibname $sock]
}

proc jlib::bytestreams::s5i_read_auth {jlibname sock} {
    
    upvar ${jlibname}::bytestreams::hash2sid hash2sid
    #puts "jlib::bytestreams::s5i_read_auth (i)"

    fileevent $sock readable {}
    if {[catch {read $sock} data] || [eof $sock]} {
	catch {close $sock}
	return
    }    
    #puts "\t read [string length $data]"
    
    binary scan $data ccccc ver cmd rsv atyp len
    if {$ver != 5 || $cmd != 1 || $atyp != 3} {
	set reply [string replace $data 1 1 \x07]
	catch {
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
	#puts "\t wrote [string length $reply]"
    } else {
	set reply [string replace $data 1 1 \x02]
	catch {
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

proc jlib::bytestreams::s5i_register_socket {jlibname sid sock} {
    
    variable fastmode
    upvar ${jlibname}::bytestreams::istate istate
    upvar ${jlibname}::bytestreams::tstate tstate
    #puts "jlib::bytestreams::s5i_register_socket"
    
    if {$fastmode && [info exists tstate($sid,fast,state)]} {
	#puts "\t (t)"
	if {$tstate($sid,fast,state) ne "error"} {
	    set tstate($sid,fast,sock)  $sock
	    set tstate($sid,fast,state) connected
	}
    } elseif {[info exists istate($sid,state)]} {
	#puts "\t (i)"
	if {$istate($sid,state) ne "error"} {
	    set istate($sid,sock)  $sock
	    set istate($sid,state) connected
	}
    } else {
	#puts "\t empty"
	# We may have been reset (timeout) or something.
    }
}

# End s5i ----------------------------------------------------------------------

proc jlib::bytestreams::ifinish {jlibname sid} {

    upvar ${jlibname}::bytestreams::istate istate
    #puts "jlib::bytestreams::ifinish (i)"
    
    # Close socket.
    if {[info exists istate($sid,sock)]} {
	catch {close $istate($sid,sock)}
    }
    if {[info exists istate($sid,fast,sock)]} {
	catch {close $istate($sid,fast,sock)}
    }
    ifree $jlibname $sid
}

proc jlib::bytestreams::ifree {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::istate istate
    upvar ${jlibname}::bytestreams::hash2sid hash2sid
    #puts "jlib::bytestreams::ifree (i)"

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
#       
# Result:
#       MUST return 0 or 1!

proc jlib::bytestreams::handle_set {jlibname from queryElem args} {
    variable xmlns    
    variable fastmode
    
    #puts "jlib::bytestreams::handle_set (t+i)"
    
    array set argsArr $args
    array set attr [wrapper::getattrlist $queryElem]
    if {![info exists argsArr(-id)]} {
	# We cannot handle this since missing id-attribute.
	return 0
    }
    if {![info exists attr(sid)]} {
	eval {return_error $jlibname $queryElem 400 modify bad-request} $args
	return 1
    }
    set id  $argsArr(-id)
    set sid $attr(sid)
    set jid $from

    # We make sure that we have already got a si with this sid.
    if {![jlib::si::havesi $jlibname $sid]} {
	eval {return_error $jlibname $queryElem 406 cancel not-acceptable} $args
	return 1
    }

    set hosts {}
    foreach elem [wrapper::getchildren $queryElem] {
	if {[wrapper::gettag $elem] eq "streamhost"} {
	    array unset sattr
	    array set sattr [wrapper::getattrlist $elem]
	    if {[info exists sattr(jid)]    \
	      && [info exists sattr(host)]  \
	      && [info exists sattr(port)]} {
		lappend hosts [list $sattr(jid) $sattr(host) $sattr(port)]
	    }
	}
    }
    #puts "\t hosts=$hosts"
    if {![llength $hosts]} {
	eval {return_error $jlibname $queryElem 400 modify bad-request} $args
	return 1
    }
    
    # In fastmode we may get a streamhosts offer for reversed socks5 connections.
    if {[is_initiator $jlibname $sid]} {
	if {$fastmode} {
	    i_handle_set $jlibname $sid $id $jid $hosts $queryElem
	} else {
	    # @@@ inconsistency!
	    return 0
	}
    } else {
	
	# This is the normal execution path.
	t_handle_set $jlibname $sid $id $jid $hosts $queryElem
    }
    return 1
}

# jlib::bytestreams::t_handle_set --
# 
#       This is like the constructor of a target sid object.

proc jlib::bytestreams::t_handle_set {jlibname sid id jid hosts queryElem} {
    variable fastmode
    variable xmlns
    
    upvar ${jlibname}::bytestreams::tstate tstate
    upvar ${jlibname}::bytestreams::static static
    upvar ${jlibname}::bytestreams::hash2sid hash2sid
    #puts "jlib::bytestreams::t_handle_set (t)"
    
    set tstate($sid,id)     $id
    set tstate($sid,jid)    $jid
    set tstate($sid,fast)   0
    set tstate($sid,state)  open
    set tstate($sid,hosts)  $hosts
    set tstate($sid,rhosts) $hosts
    set tstate($sid,queryElem) $queryElem
    
    if {$fastmode} {
	set fastElem [wrapper::getchildswithtagandxmlns $queryElem "fast"  \
	  $xmlns(fast)]
	if {[llength $fastElem]} {
	    
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
		
		# Provide a streamhost to the initiator.
		if {$static(-address) ne ""} {
		    set ip $static(-address)
		} else {
		    set ip [jlib::getip $jlibname]
		}
		set myjid [jlib::myjid $jlibname]
		set hash  [::sha1::sha1 ${sid}${myjid}${jid}]
		set tstate($sid,hash) $hash
		set hash2sid($hash) $sid
		
		set host [list $myjid -host $ip -port $static(port)]
		
		set t_initiate_cb  \
		  [list [namespace current]::t_initiate_cb $jlibname $sid]
		initiate $jlibname $jid $sid $t_initiate_cb -streamhost $host
	    }
	}
    }
    
    # Schedule a timeout.
    set tstate($sid,timeoutid) [after $static(-timeoutms)  \
      [list [namespace current]::handle_set_timeout_cb $jlibname $sid]]

    # Try connecting the host(s) in turn.
    set tstate($sid,state) connecting    
    connect_host $jlibname $sid
}

proc jlib::bytestreams::handle_set_timeout_cb {jlibname sid} {

    upvar ${jlibname}::bytestreams::istate istate
    #puts "jlib::bytestreams::handle_set_timeout_cb (t)"
    
    send_error $jlibname $sid 404 cancel item-not-found
    jlib::si::stream_error $jlibname $sid timeout
    tfinish $jlibname $sid    
}

proc jlib::bytestreams::t_initiate_cb {jlibname sid type subiq args} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    #puts "jlib::bytestreams::t_initiate_cb (t) type=$type"

    # In fast mode we may get this callback after we have finished.
    # Or after a timeout or something.
    if {![info exists tstate($sid,state)]} {
	return
    }

    if {$type eq "error"} {
	
	# Cleanup and close any fast socks5 connection.
	set tstate($sid,fast,state) error
	if {[info exists tstate($sid,fast,sock)]} {
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
	#puts "\t waiting CR"
	set tstate($sid,fast,state) waiting-cr
	set sock $tstate($sid,fast,sock)
	set cmd_cr [list [namespace current]::fast_read_CR_cb $jlibname $sid]
	fileevent $sock readable  \
	  [list [namespace current]::read_CR $sock $cmd_cr]
    }
}

proc jlib::bytestreams::read_CR {sock cmd} {

    #puts "jlib::bytestreams::read_CR (t)"
    fileevent $sock readable {}
    if {[catch {read $sock 1} data] || [eof $sock]} {
	#puts "\t eof"
	catch {close $sock}
	eval $cmd error
    } elseif {$data ne "\r"} {
	#puts "\t not CR"
	catch {close $sock}
	eval $cmd error
    } else {
	#puts "\t got CR"
	eval $cmd
    }
}

proc jlib::bytestreams::fast_read_CR_cb {jlibname sid {error ""}} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    #puts "jlib::bytestreams::fast_read_CR_cb (t) error=$error"
    
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
	if {[info exists tstate($sid,sock)]} {
	    catch {close $tstate($sid,sock)}
	    unset tstate($sid,sock)
	}
	
	# Deliver error to initiator unless not done so.
	if {$tstate($sid,state) ne "error"} {
	    send_error $jlibname $sid 404 cancel item-not-found
	}
	set tstate($sid,state)         error
	set tstate($sid,fast,selected) fast
	set tstate($sid,fast,state)    read

	set sock $tstate($sid,fast,sock)
	
	fileevent $sock readable  \
	  [list [namespace current]::readable $jlibname $sid $sock]
    }
}

#...............................................................................

# jlib::bytestreams::connect_host --
# 
#       Is called recursively for each host until socks5 connection established.

proc jlib::bytestreams::connect_host {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    #puts "jlib::bytestreams::connect_host (t)"
    
    set rhosts $tstate($sid,rhosts)
    if {![llength $rhosts]} {
	connect_host_final $jlibname $sid error
	return
    }

    # Pick first host in rhost list.
    set host [lindex $rhosts 0]
    lassign $host hostjid addr port
    
    # Pop this host from list of hosts.
    set tstate($sid,rhosts)  [lrange $rhosts 1 end]
    set tstate($sid,host)    $host
    set tstate($sid,hostjid) $hostjid
    
    set jid $tstate($sid,jid)
    set myjid [$jlibname myjid]
    set hash [::sha1::sha1 ${sid}${jid}${myjid}]    
    
    set cmd [list [namespace current]::connect_host_cb $jlibname $sid]
    if {[catch {
	set tstate($sid,sock) [socks5 $addr $port $hash $cmd]
    } err]} {
	
	# Try next one if any.
	#puts "\t err=$err"
	connect_host $jlibname $sid
    }
}

proc jlib::bytestreams::connect_host_cb {jlibname sid {errmsg ""}} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    #puts "jlib::bytestreams::connect_host_cb (t) errmsg=$errmsg"
    
    if {[string length $errmsg]} {
	connect_host $jlibname $sid
    } else {
	connect_host_final $jlibname $sid
    }
}

proc jlib::bytestreams::connect_host_final {jlibname sid {error ""}} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    #puts "jlib::bytestreams::connect_host_final (t) error=$error"

    if {[info exists tstate($sid,timeoutid)]} {
	after cancel $tstate($sid,timeoutid)
	unset tstate($sid,timeoutid)
    }    
    if {$error ne ""} {
	set tstate($sid,state) error
	
	# Deliver error to initiator.
	send_error $jlibname $sid 404 cancel item-not-found
	
	# In fastmode we are not done until the fast mode also fails.
	if {!$tstate($sid,fast) || ($tstate($sid,fast,state) eq "error")} {

	    # Deliver error to target profile.
	    jlib::si::stream_error $jlibname $sid item-not-found
	    tfinish $jlibname $sid
	}
    } else {
	set jid     $tstate($sid,jid)
	set id      $tstate($sid,id)
	set hostjid $tstate($sid,hostjid)
	set sock    $tstate($sid,sock)
	send_used $jlibname $jid $id $hostjid
	
	# If fast mode we must wait for a CR before start reading.
	if {$tstate($sid,fast)} {

	    # Wait for initiator send a CR for selection or just close it.
	    set tstate($sid,state) waiting-cr
	    set cmd_cr [list [namespace current]::read_CR_cb $jlibname $sid]
	    fileevent $sock readable  \
	      [list [namespace current]::read_CR $sock $cmd_cr]

	} else {
	    fileevent $sock readable  \
	      [list [namespace current]::readable $jlibname $sid $sock]
	}
    }
}

#...............................................................................

proc jlib::bytestreams::read_CR_cb {jlibname sid {error ""}} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    #puts "jlib::bytestreams::read_CR_cb (t) error=$error"
    
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
	    catch {close $tstate($sid,fast,sock)}
	    unset tstate($sid,fast,sock)
	}
	set sock $tstate($sid,sock)

	set tstate($sid,fast,selected) normal
	set tstate($sid,state)  read
	
	fileevent $sock readable  \
	  [list [namespace current]::readable $jlibname $sid $sock]
    }
}

# End connect_socks ------------------------------------------------------------

# jlib::bytestreams::readable --
# 
#       Reads channel and delivers data up to si.

proc  jlib::bytestreams::readable {jlibname sid sock} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    #puts "jlib::bytestreams::readable (t)"

    # We may have been reset or something.
    if {![jlib::si::havesi $jlibname $sid]} {
	tfinish $jlibname $sid
	return
    }
    
    if {[catch {eof $sock} iseof] || $iseof} {
	#puts "\t eof"
	# @@@ Perhaps we should check number of bytes reveived or something???
	jlib::si::stream_closed $jlibname $sid
	tfinish $jlibname $sid
    } else {
	
	# @@@ not sure about 4096, should size be specified?
	set data [read $sock 4096]
	set len [string length $data]
	#puts "\t len=$len"
    
	# Deliver to si for further processing.
	jlib::si::stream_recv $jlibname $sid $data
    }
}

# jlib::bytestreams::send_used --
# 
#       Target notifies initiator of connection.

proc jlib::bytestreams::send_used {jlibname to id hostjid} {
    variable xmlns
    
    set usedElem [wrapper::createtag "streamhost-used" \
      -attrlist [list jid $hostjid]]
    set xmllist [wrapper::createtag "query" \
      -attrlist [list xmlns $xmlns(bs)] \
      -subtags [list $usedElem]]

    $jlibname send_iq "result" [list $xmllist] -to $to -id $id
}

# The target socks5 functions --------------------------------------------------
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

    #puts "jlib::bytestreams::socks5 (t)"
    
    if {[catch {
	set sock [socket -async $addr $port]
    } err]} {
	return -code error $err
    }
    fconfigure $sock -translation binary -blocking 0
    fileevent $sock writable  \
      [list [namespace current]::s5t_write_method $hash $sock $cmd]
    return $sock
}

proc jlib::bytestreams::s5t_write_method {hash sock cmd} {
    
    #puts "jlib::bytestreams::s5t_write_method (t)"
    fileevent $sock writable {}
    
    # Announce method (\x00).
    if {[catch {
	puts -nonewline $sock "\x05\x01\x00"
	flush $sock
	#puts "\t wrote 3: 'x05x01x00'"
    } err]} {
	eval $cmd error-network-write
	return
    }
    fileevent $sock readable  \
      [list [namespace current]::s5t_method_result $hash $sock $cmd]
}

proc jlib::bytestreams::s5t_method_result {hash sock cmd} {
    
    #puts "jlib::bytestreams::s5t_method_result (t)"
    
    fileevent $sock readable {}
    if {[catch {read $sock} data] || [eof $sock]} {
	catch {close $sock}
	eval $cmd error-network-read
	return
    }    
    #puts "\t read [string length $data]"
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
	#puts "\t wrote [string length "\x05\x01\x00\x03$len$hash\x00\x00"]: 'x05x01x00x03${len}${hash}x00x00'"
    } err]} {
	catch {close $sock}
	eval $cmd error-network-write
	return
    }
    fileevent $sock readable \
      [list [namespace current]::s5t_auth_result $sock $cmd]
}

proc jlib::bytestreams::s5t_auth_result {sock cmd} {
    
    #puts "jlib::bytestreams::s5t_auth_result (t)"
    
    fileevent $sock readable {}
    if {[catch {read $sock} data] || [eof $sock]} {
	catch {close $sock}
	eval $cmd error-network-read
	return
    }
    #puts "\t read [string length $data]"
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

# jlib::bytestreams::return_error, send_error --
# 
#       Various helper functions to return errors.

proc jlib::bytestreams::return_error {jlibname qElem errcode errtype stanza args} {
    
    array set attr $args
    set id  $attr(-id)
    set jid $attr(-from)
    jlib::send_iq_error $jlibname $jid $id $errcode $errtype $stanza $qElem
}

proc jlib::bytestreams::send_error {jlibname sid errcode errtype stanza} {

    upvar ${jlibname}::bytestreams::tstate tstate
    #puts "jlib::bytestreams::send_error (t)"
    
    set id  $tstate($sid,id)
    set jid $tstate($sid,jid)
    set qel $tstate($sid,queryElem)
    jlib::send_iq_error $jlibname $jid $id $errcode $errtype $stanza $qel 
}

proc jlib::bytestreams::tfinish {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    #puts "jlib::bytestreams::tfinish (t)"

    # Close socket.
    if {[info exists tstate($sid,sock)]} {
	catch {close $tstate($sid,sock)}
    }
    if {[info exists tstate($sid,fast,sock)]} {
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
    #puts "jlib::bytestreams::tfree (t)"

    if {[info exists tstate($sid,hash)]} {
	set hash $tstate($sid,hash)
	unset -nocomplain hash2sid($hash)
    }
    array unset tstate $sid,*
}

# jlib::bytestreams::activate --
# 
#       Initiator requests activation of bytestream.

proc jlib::bytestreams::activate {jlibname to sid targetjid args} {
    variable xmlns
    
    set opts {}
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
    set activateElem [wrapper::createtag "activate" \
      -attrlist [list jid $targetjid]]
    set xmllist [wrapper::createtag "query" \
      -attrlist [list xmlns $xmlns(bs) sid $sid] \
      -subtags [list $activateElem]]

    eval {$jlibname send_iq "set" [list $xmllist] -to $to} $opts
}

# We have to do it here since need the initProc before doing this.

namespace eval jlib::bytestreams {
	
    jlib::ensamble_register bytestreams  \
      [namespace current]::init          \
      [namespace current]::cmdproc
}

#-------------------------------------------------------------------------------

# TODO...

proc jlib::bytestreams::connector {jlibname sid jid hosts cmd} {
    
    upvar ${jlibname}::bytestreams::conn conn
    upvar ${jlibname}::bytestreams::static static
    
    set conn($sid,jid)   $jid
    set conn($sid,hosts) $hosts
    set conn($sid,cmd)   $cmd
    set conn($sid,timeoutid) [after $static(-timeoutms)  \
      [list [namespace current]::connector_timeout_cb $jlibname $sid]]
    
    set myjid [jlib::myjid $jlibname]
    set hash  [::sha1::sha1 ${sid}${myjid}${jid}]

    foreach host $hosts {
	lassign $host hostjid addr port
	set s5_cb [list [namespace current]::connector_s5_cb $jlibname $sid ...]
	if {![catch {
	    set sock [socks5 $addr $port $hash $s5_cb]
	}]} {
	    set conn($sid,sock,) $sock
	}
    }
}

proc jlib::bytestreams::connector_s5_cb {jlibname sid } {
        
    upvar ${jlibname}::bytestreams::conn conn
    
}

proc jlib::bytestreams::connector_timeout_cb {jlibname sid } {
	
    upvar ${jlibname}::bytestreams::conn conn
    
    set cmd $conn($sid,cmd)
    eval $cmd timeout
}

proc jlib::bytestreams::connector_reset {jlibname sid} {
	
    upvar ${jlibname}::bytestreams::conn conn
    
}

