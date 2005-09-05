#  bytestreams.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for the bytestreams protocol (JEP-0065).
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: bytestreams.tcl,v 1.6 2005-09-05 14:01:39 matben Exp $
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

package require jlib
package require sha1      ;# tcllib                           
                          
package provide jlib::bytestreams 0.1

#--- generic bytestreams -------------------------------------------------------

namespace eval jlib::bytestreams {

    variable xmlns
    set xmlns(bs)  "http://jabber.org/protocol/bytestreams"
    
    jlib::ensamble_register bytestreams  \
      [namespace current]::init          \
      [namespace current]::cmdproc

    jlib::si::registertransport $xmlns(bs) $xmlns(bs) 40  \
      [namespace current]::si_open   \
      [namespace current]::si_send   \
      [namespace current]::si_close    
}

# jlib::bytestreams::init --
# 
#       Instance init procedure.
#       Note: this proc name is by convention, do not change!
  
proc jlib::bytestreams::init {jlibname args} {
    variable xmlns
    
    Debug 4 "jlib::bytestreams::init"
    
    # Keep different state arrays for initiator (i) and receiver (t).
    namespace eval ${jlibname}::bytestreams {
	variable istate
	variable tstate
    }

    # Register some standard iq handlers that is handled internally.
    $jlibname iq_register set $xmlns(bs) [namespace current]::handle_set

    return
}

proc jlib::bytestreams::cmdproc {jlibname cmd args} {
    
    Debug 4 "jlib::bytestreams::cmdproc jlibname=$jlibname, cmd='$cmd', args='$args'"

    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# These are all functions to use by a sender (initiator).

# jlib::bytestreams::si_open, si_send, si_close --
# 
#       Bindings for si.

proc jlib::bytestreams::si_open {jlibname jid sid args} {
    
    upvar ${jlibname}::bytestreams::istate istate
    puts "jlib::bytestreams::si_open (i)"
    
    set istate($sid,jid) $jid
    
    s5i_server $jlibname $sid $jid
    
    set myjid [jlib::myjid $jlibname]
    set ip    $istate($sid,ip)
    set port  $istate($sid,sport)
    set host  [list $myjid -host $ip -port $port]
    
    set si_open_cb [list [namespace current]::si_open_cb $jlibname $sid]
    initiate $jlibname $jid $sid $si_open_cb -streamhost $host

    return
}

proc jlib::bytestreams::si_open_cb {jlibname sid type subiq args} {
    
    upvar ${jlibname}::bytestreams::istate istate
    puts "jlib::bytestreams::si_open_cb (i)"
    
    jlib::si::transport_open_callback $jlibname $sid $type $subiq
}

proc jlib::bytestreams::si_send {jlibname sid data} {
    
    upvar ${jlibname}::bytestreams::istate istate
    puts "jlib::bytestreams::si_send (i)"
    
    set s $istate($sid,sock)
    if {[catch {puts -nonewline $s $data}]} {
	
    }
}

proc jlib::bytestreams::si_close {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::istate istate
    puts "jlib::bytestreams::si_close (i)"
    
    
    ifree $jlibname $sid
}

#--- Generic initiator code ----------------------------------------------------

proc jlib::bytestreams::s5i_server {jlibname sid jid} {
    
    upvar ${jlibname}::bytestreams::istate istate
    puts "jlib::bytestreams::s5i_server (i)"
    
    set sock [socket -server [list [namespace current]::s5i_accept $jlibname $sid] 0]
    lassign [fconfigure $sock -sockname] addr hostname port
    set ip    [jlib::getip $jlibname]
    set myjid [jlib::myjid $jlibname]
    set hash  [::sha1::sha1 ${sid}${myjid}${jid}]
    
    set istate($sid,ip)    $ip
    set istate($sid,sport) $port
    set istate($sid,hash)  $hash
    set istate($sid,ssock) $sock
}

# jlib::bytestreams::initiate --
# 
#       -streamhost {jid (-host -port | -zeroconf)}

proc jlib::bytestreams::initiate {jlibname to sid cmd args} {
    variable xmlns
    
    puts "jlib::bytestreams::initiate (i)"
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

# The initiator socks5 functions -----------------------------------------------

# jlib::bytestreams::s5i_accept --
# 
#       The server socket callback when connected.

proc jlib::bytestreams::s5i_accept {jlibname sid sock addr port} {

    upvar ${jlibname}::bytestreams::istate istate
    puts "jlib::bytestreams::s5_accept (i)"
    
    set istate($sid,sock) $sock
    fconfigure $sock -translation binary -blocking 0

    fileevent $sock readable \
      [list [namespace current]::s5i_wait_for_methods $jlibname $sid]
}

proc jlib::bytestreams::s5i_wait_for_methods {jlibname sid} {
   
    upvar ${jlibname}::bytestreams::istate istate
    puts "jlib::bytestreams::s5i_wait_for_methods (i)"   
    
    set sock $istate($sid,sock)
    fileevent $sock readable {}
    if {[catch {read $sock} data] || [eof $sock]} {
	catch {close $sock}
	return
    }  
    
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
    }]} {
	return
    }
    fileevent $sock readable \
      [list [namespace current]::s5i_wait_for_request $jlibname $sid]
}

proc jlib::bytestreams::s5i_wait_for_request {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::istate istate
    puts "jlib::bytestreams::s5i_wait_for_request (i)"

    set sock $istate($sid,sock)
    fileevent $sock readable {}
    if {[catch {read $sock} data] || [eof $sock]} {
	catch {close $sock}
	return
    }    
    
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

    if {[string equal $istate($sid,hash) $hash]} {
	set reply [string replace $data 1 1 \x00]
	puts -nonewline $sock $reply
	flush $sock
    } else {
	set reply [string replace $data 1 1 \x02]
	catch {
	    puts -nonewline $sock $reply
	    close $sock
	}	
	return
    }
}

proc jlib::bytestreams::ifree {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::istate istate
    puts "jlib::bytestreams::ifree (i)"

    array unset istate $sid,*
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# These are all functions to use by a receiver (target) of a stream.

# jlib::bytestreams::handle_set --
# 
#       Handler for incoming iq-set element with xmlns 
#       "http://jabber.org/protocol/bytestreams".
#       
#       Initiator sends IQ-set to Target specifying the full JID and network 
#       address of StreamHost/Initiator as well as the StreamID (SID) of the 
#       proposed bytestream. 
#    

proc jlib::bytestreams::handle_set {jlibname from queryElem args} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    puts "jlib::bytestreams::handle_set (t) $args"
    
    array set argsArr $args
    array set attr [wrapper::getattrlist $queryElem]
    if {![info exists argsArr(-id)]} {
	# We cannot handle this since missing id-attribute.
	return 0
    }
    if {![info exists attr(sid)]} {
	eval {return_bad_request $jlibname $queryElem} $args
	return 1
    }
    set id  $argsArr(-id)
    set sid $attr(sid)

    # We make sure that we have already got a si with this sid.
    if {![jlib::si::havesi $jlibname $sid]} {
	return_error $jlibname $from $id $sid 404 cancel item-not-found
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
    puts "\t hosts=$hosts"
    if {![llength $hosts]} {
	eval {return_bad_request $jlibname $queryElem} $args
	return 1
    }
    set tstate($sid,id)     $id
    set tstate($sid,jid)    $from
    set tstate($sid,hosts)  $hosts
    set tstate($sid,rhosts) $hosts

    # Try the host(s) in turn.
    connect_host $jlibname $sid
    return 1
}

# jlib::bytestreams::connect_host --
# 
# 

proc jlib::bytestreams::connect_host {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    puts "jlib::bytestreams::connect_host (t)"
    
    set rhosts $tstate($sid,rhosts)
    if {![llength $rhosts]} {
	# error
	return
    }

    # Pick first host in rhost list.
    set host    [lindex $rhosts 0]
    set hostjid [lindex $host 0]
    set addr    [lindex $host 1]
    set port    [lindex $host 2]
    
    # Pop this host from list of hosts.
    set tstate($sid,rhosts)  [lrange $rhosts 1 end]
    set tstate($sid,host)    $host
    set tstate($sid,hostjid) $hostjid
    
    set cmd [list [namespace current]::connect_host_cb $jlibname $sid]
    if {[catch {
	set tstate($sid,sock) [socks5 $jlibname $sid $addr $port $cmd]
    } err]} {
	puts "\t err=$err"
	connect_host $jlibname $sid
    }
}

proc jlib::bytestreams::connect_host_cb {jlibname sid {errmsg ""}} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    puts "jlib::bytestreams::connect_host_cb (t) errmsg=$errmsg"
    
    if {[string length $errmsg]} {
	connect_host $jlibname $sid
    } else {
	set jid     $tstate($sid,jid)
	set id      $tstate($sid,id)
	set hostjid $tstate($sid,hostjid)
	set sock    $tstate($sid,sock)
	send_used $jlibname $jid $id $hostjid
	fileevent $sock readable  \
	  [list [namespace current]::readable $jlibname $sid]
    }
}

proc  jlib::bytestreams::readable {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    puts "jlib::bytestreams::readable (t)"
    
    set sock $tstate($sid,sock)
    if {[catch {eof $sock} iseof] || $iseof} {
	fileevent readable $sock {}
	
	
    } else {
	set data [read $sock]
    
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

# jlib::bytestreams::socks5 --
# 
#       Open a client socket to the specified host and port and announce method.

proc jlib::bytestreams::socks5 {jlibname sid addr port cmd} {

    puts "jlib::bytestreams::target::socks5 (t)"
    
    if {[catch {
	set sock [socket -async $addr $port]
    } err]} {
	return -code error $err
    }
    fconfigure $sock -translation binary -blocking 0
    
    # Announce method (\x00).
    if {[catch {
	puts -nonewline $sock "\x05\x01\x00"
	flush $sock
    } err]} {
	return -code error $err
    }
    fileevent $sock readable  \
      [list [namespace current]::s5t_wait_for_method $jlibname $sid $sock $cmd]
    return $sock
}

proc jlib::bytestreams::s5t_wait_for_method {jlibname sid sock cmd} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    puts "jlib::bytestreams::s5t_wait_for_method (t)"
    
    fileevent $sock readable {}
    if {[catch {read $sock 2} data] || [eof $sock]} {
	catch {close $sock}
	eval $cmd error-network-read
	return
    }    
    binary scan $data cc ver method
    if {($ver != 5) || ($method != 0)} {
	catch {close $sock}
	eval $cmd error-socks5
	return
    }
    set myjid [$jlibname myjid]
    set jid $tstate($sid,jid)
    set hash [::sha1::sha1 ${sid}${jid}${myjid}]    
    set len [binary format c [string length $hash]]
    if {[catch {
	puts -nonewline $sock "\x05\x01\x00\x03$len$hash\x00\x00"
	flush $sock
    } err]} {
	catch {close $sock}
	eval $cmd error-network-write
	return
    }
    fileevent $sock readable \
      [list [namespace current]::s5t_wait_for_reply $jlibname $sid $sock $cmd]
}

proc jlib::bytestreams::s5t_wait_for_reply {jlibname sid sock cmd} {
    
    fileevent $sock readable {}
    puts "jlib::bytestreams::s5t_wait_for_reply (t)"
    
    fileevent $sock readable {}
    if {[catch {read $sock 2} data] || [eof $sock]} {
	catch {close $sock}
	eval $cmd error-network-read
	return
    }    
    binary scan $data cc ver method
    if {($ver != 5) || ($method != 0)} {
	catch {close $sock}
	eval $cmd error-socks5
	return
    }

    # Here we should be finished.
    uplevel #0 $cmd
}

# @@@ missing id attribute!!!!!!!!!!!!!!!!!
proc jlib::bytestreams::return_bad_request {jlibname queryElem args} {
    
    return_error $jlibname $queryElem 400 modify "bad-request"
}

proc jlib::bytestreams::return_item_not_found {jlibname queryElem args} {
    
    return_error $jlibname $queryElem 404 cancel "item-not-found"
}

proc jlib::bytestreams::return_error {jlibname queryElem errcode errtype errtag} {

    foreach {key value} $args {
	set name [string trimleft $key -]
	set attr($name) $value
    }
    set xmldata [wrapper::createtag "iq" \
      -subtags [list $queryElem] -attrlist [array get attr]]
    $jlibname return_error $xmldata $errcode $errtype $errtag
}

proc jlib::bytestreams::tfree {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    puts "jlib::bytestreams::ifree (t)"

    array unset tstate $sid,*
}





#--- initiator section ---------------------------------------------------------

namespace eval jlib::bytestreams::initiator { }


proc jlib::bytestreams::initiator::connect {jlibname jid sid} {
    variable state
    
    set sock [socket -server [list [namespace current]::accept $sid] 0]
    lassign [fconfigure $sock -sockname] addr hostname port
    set ip    [jlib::getip $jlibname]
    set myjid [jlib::myjid $jlibname]
    set hash  [::sha1::sha1 ${sid}${myjid}${jid}]
    
    set state($sid,jid)   $jid
    set state($sid,ip)    $ip
    set state($sid,sport) $port
    set state($sid,hash)  $hash
    set state($sid,ssock) $sock
    
    set host [list $myjid -host $ip -port $port]
    
    jlib::bytestreams::initiate $jlibname $jid $sid -streamhost $host \
      -command [list [namespace current]::connect_cb $jlibname $sid]
    
    
}

proc jlib::bytestreams::initiator::connect_cb {jlibname sid type queryElem args} {
    variable state

    if {$type eq "error"} {
	
	
    } else {
	
    }
}

proc jlib::bytestreams::initiator::accept {sid sock addr port} {
    variable state

    set state($sid,sock) $sock
    fconfigure $sock -translation binary -blocking 0

    fileevent $sock readable \
      [list [namespace current]::wait_for_methods $sid]
}

proc jlib::bytestreams::initiator::wait_for_methods {sid} {
    variable state

    set sock $state($sid,sock)
    fileevent $sock readable {}
    if {[catch {read $sock} data] || [eof $sock]} {
	catch {close $sock}

	return
    }  
    
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
    }]} {
	
	return
    }
    fileevent $sock readable \
      [list [namespace current]::wait_for_request $sid]
}

proc jlib::bytestreams::initiator::wait_for_request {sid} {
    variable state

    set sock $state($sid,sock)
    fileevent $sock readable {}
    if {[catch {read $sock} data] || [eof $sock]} {
	catch {close $sock}

	return
    }    
    
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

    if {[string equal $state($sid,hash) $hash]} {
	set reply [string replace $data 1 1 \x00]
	puts -nonewline $sock $reply
	flush $sock
    } else {
	set reply [string replace $data 1 1 \x02]
	catch {
	    puts -nonewline $sock $reply
	    close $sock
	}
	
	return
    }
}

#--- target section ------------------------------------------------------------

namespace eval jlib::bytestreams::target { }

# jlib::bytestreams::target::connect --
# 
#       Try to do a socks5 connection on any of the indicated hosts in turn.
#       
# Arguments:
#       jid
#       sid
#       hosts   {{jid ip port} ...}
#       
# Results:
#       none.

proc jlib::bytestreams::target::init {jlibname jid queryElem sid hosts args} {
    variable state

    puts "jlib::bytestreams::target::init (t)"
    set state($sid,jid)       $jid
    set state($sid,hosts)     $hosts
    set state($sid,queryElem) $queryElem
    set state($sid,args)      $args
    
    connect $jlibname $jid $sid $rhosts
}

proc jlib::bytestreams::target::connect {jlibname sid rhosts} {
    variable state
    puts "jlib::bytestreams::target::connect (t)"
    
    # Pick first host in rhost list.
    set host [lindex $rhosts 0]
    set rhosts [lrange 1 end]
    
    socks5 $jlibname $jid $sid $host \
      [list [namespace current]::connect_cb $jlibname $sid $rhosts]    
}

proc jlib::bytestreams::target::connect_cb {jlibname sid rhosts err} {
    variable state
    puts "jlib::bytestreams::target::connect_cb (t)"
    
    set jid     $state($sid,jid)
    set jidhost $state($sid,jidhost)
    
    if {$err eq ""} {
	
	# socks5 connection ok. 
	# Answer with 'result' and keep id attribute.
	array set argsArr $state($sid,args)
	set id $argsArr(-id)
	jlib::bytestreams::used $jlibname $jid $id $jidhost

	free $sid
    } else {
	if {$remhosts == {}} {
	    
	    # item-not-found
	    set queryElem $state($sid,queryElem)
	    set aargs     $state($sid,args)
	    eval {jlib::bytestreams::return_item_not_found $jlibname \
	      $queryElem} $aargs

	    free $sid 
	} else {
	    
	    # Try next host.
	    connect $jlibname $jid $sid $rhosts
	}
    }
}

proc jlib::bytestreams::target::free {sid} {
    variable state
    
    array unset state $sid,*
}

proc jlib::bytestreams::target::socks5 {jlibname jid sid host cmd} {
    variable state
    puts "jlib::bytestreams::target::socks5 (t)"
    
    lassign $host jidhost addr port
    if {[catch {
	set sock [socket -async $addr $port]
    } err]} {
	uplevel #0 $cmd error-socket
	return
    }
    fconfigure $sock -translation binary -blocking 0

    set state($sid,sock)    $sock
    set state($sid,host)    $host
    set state($sid,addr)    $addr
    set state($sid,jidhost) $jidhost
    set state($sid,cmd)     $cmd
    set state($sid,status)  0
    
    # Announce method (\x00).
    if {[catch {
	puts -nonewline $sock "\x05\x01\x00"
	flush $sock
    } err]} {
	uplevel #0 $cmd error-socket
	return
    }
    fileevent $sock readable \
      [list [namespace current]::wait_for_method $jlibname $sid]    
}

proc jlib::bytestreams::target::wait_for_method {jlibname sid} {
    variable state

    set sock $state($sid,sock)
    set cmd  $state($sid,cmd)
    fileevent $sock readable {}
    if {[catch {read $sock 2} data] || [eof $sock]} {
	catch {close $sock}
	uplevel #0 $cmd error-network-read
	return
    }    
    binary scan $data cc ver method
    if {($ver != 5) || ($method != 0)} {
	catch {close $sock}
	uplevel #0 $cmd error-socks5
	return
    }
    set myjid [$jlibname myjid]
    set jid $state($sid,jid)
    set hash [::sha1::sha1 ${sid}${jid}${mylid}]    
    set len [binary format c [string length $hash]]
    if {[catch {
	puts -nonewline $sock "\x05\x01\x00\x03$len$hash\x00\x00"
	flush $sock
    } err]} {
	catch {close $sock}
	uplevel #0 $cmd error-network-read
	return
    }
    fileevent $sock readable \
      [list [namespace current]::wait_for_reply $jlibname $sid]
}

proc jlib::bytestreams::target::wait_for_reply {jlibname sid} {
    variable state

    set sock $state($sid,sock)
    set cmd  $state($sid,cmd)
    fileevent $sock readable {}
    if {[catch {read $sock 2} data] || [eof $sock]} {
	catch {close $sock}
	uplevel #0 $cmd error-network-read
	return
    }    
    binary scan $data cc ver method
    if {($ver != 5) || ($method != 0)} {
	catch {close $sock}
	uplevel #0 $cmd error-socks5
	return
    }

    # Here we should be finished.


    uplevel #0 $cmd ""
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

proc jlib::bytestreams::streamhosts {jid} {    
    variable streamhosts
    
    # The jid attribute is a MUST.
    if {[info exists streamhosts($jid,jid)]} {
	set ans {}
	foreach {key value} [array get streamhosts [jlib::ESC $jid]] {
	    # @@@ 'dict' will rescue from these things.
	    set name [string map [list $jid, ""]]
	    lappend opts -$name $value
	}
	return $ans
    } else {
	return
    }
}

# jlib::bytestreams::get --
# 
#       Initiator discovers network address of streamhost.
#
# Arguments:
#       to
#       cmd     tclProc 
#       
# Results:
#       None

proc jlib::bytestreams::get {jlibname to cmd} {
    variable xmlns
    
    $jlibname iq_get $xmlns(bs) -to $to \
      -command [list [namespace current]::get_cb $to $cmd]
}

proc jlib::bytestreams::get_cb {from cmd jlibname type queryElem} {
    variable streamhosts
    
    # Cache any result.
    if {$type eq "result"} {
	set streamhostElems [wrapper::getfromchilds $queryElem streamhost]
	array unset streamhosts [jlib::ESC $jid]
	foreach elem $streamhostElems {
	    foreach {name value} [wrapper::getattrlist $elem] {
		set streamhosts($from,$name) $value
	    }
	}
    }
    uplevel #0 $cmd [list $jlibname $type $queryElem]
}

# jlib::bytestreams::initiate --
# 
#       -command tclProc
#       -streamhost {jid (-host -port | -zeroconf)}

proc jlib::bytestreams::initiateXXX {jlibname to sid args} {
    variable xmlns
    
    puts "jlib::bytestreams::initiate (i)"
    set attrlist [list xmlns $xmlns(bs) sid $sid mode tcp]
    set sublist {}
    set opts {}
    foreach {key value} $args {
	
	switch -- $key {
	    -command {
		set opts [list -command $value]
	    }
	    -streamhost {
		set jid [lindex $value 0]
		set hostattr [list jid $jid]
		foreach {hkey hvalue} [lrange $value 1 end] {
		    lappend hostattr [string trimleft $hkey -] $hvalue
		}
		lappend sublist \
		  [wrapper::createtag "streamhost" -attrlist $hostattr]
	    }
	    default {
		return -code error "unknown option \"$key\""
	    }
	}
    }
    set xmllist [wrapper::createtag "query" -attrlist $attrlist \
      -subtags $sublist]
    eval {$jlibname send_iq "set" [list $xmllist] -to $to} $opts

    return $sid
}

# jlib::bytestreams::error --
# 
#       Return an error to initiator.

proc jlib::bytestreams::error {jlibname to type args} {
    variable xmlns
    upvar jlib::xmppxmlns xmppxmlns
       
    switch -- $type {
	auth {
	    set errCode 403
	    set errName "forbidden"
	}
	cancel {
	    set errCode 405
	    set errName "not-allowed"
	}
	default {
	    return -code error "unknown type \"$type\""
	}
    }   
    set queryElem [wrapper::createtag "query" -attrlist [list xmlns $xmlns(bs)]]
    set subElem   [wrapper::createtag $errName \
      -attrlist [list xmlns $xmppxmlns(stanzas)]]
    set errorElem [wrapper::createtag "error" \
      -attrlist [list code $errCode type $type] \
      -subtags [list $subElem]]

    $jlibname send_iq "error" [list $queryElem $errorElem] -to $to
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

#-------------------------------------------------------------------------------

