#  bytestreams.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for the bytestreams protocol (JEP-0065).
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: bytestreams.tcl,v 1.12 2005-09-27 13:31:35 matben Exp $
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
package require jlib::disco
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
    
    jlib::disco::registerfeature $xmlns(bs)
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

	# Mapper from SOCKS5 hash to sid.
	variable hash2sid
	
	# Independent of sid variables.
	variable static
	
	# Server port 0 says that arbitrary port can be chosen.
	set static(-port) 0
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

proc jlib::bytestreams::configure {jlibname args} {
    
    upvar ${jlibname}::bytestreams::static static

    foreach {key value} $args {
	
	switch -- $key {
	    -port {
		if {![string is integer -strict $value]} {
		    return -code error "port must be integer number"
		}
		set static(-port) $value
	    }
	    default {
		return -code error "unknown option \"$key\""
	    }
	}
    }
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# These are all functions to use by a initiator (sender).

# jlib::bytestreams::si_open, si_send, si_close --
# 
#       Bindings for si.

proc jlib::bytestreams::si_open {jlibname jid sid args} {
    
    upvar ${jlibname}::bytestreams::istate istate
    upvar ${jlibname}::bytestreams::static static
    upvar ${jlibname}::bytestreams::hash2sid hash2sid
    #puts "jlib::bytestreams::si_open (i)"
    
    set istate($sid,jid) $jid
    
    if {![info exists static(sock)]} {
	s5i_server $jlibname
    }
    
    set ip    [jlib::getip $jlibname]
    set myjid [jlib::myjid $jlibname]
    set hash  [::sha1::sha1 ${sid}${myjid}${jid}]
    
    set istate($sid,ip)    $ip
    set istate($sid,hash)  $hash
    set hash2sid($hash)    $sid
    set host [list $myjid -host $ip -port $static(port)]
    
    set si_open_cb [list [namespace current]::si_open_cb $jlibname $sid]
    initiate $jlibname $jid $sid $si_open_cb -streamhost $host

    return
}

proc jlib::bytestreams::si_open_cb {jlibname sid type subiq args} {
    
    upvar ${jlibname}::bytestreams::istate istate
    #puts "jlib::bytestreams::si_open_cb (i)"
    
    jlib::si::transport_open_cb $jlibname $sid $type $subiq
}

proc jlib::bytestreams::si_send {jlibname sid data} {
    
    upvar ${jlibname}::bytestreams::istate istate
    #puts "jlib::bytestreams::si_send (i)"
    #puts "\t len=[string length $data]"
    
    set s $istate($sid,sock)
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

proc jlib::bytestreams::ifinish {jlibname sid} {

    upvar ${jlibname}::bytestreams::istate istate
    #puts "jlib::bytestreams::ifinish (i)"
    
    # Close socket.
    catch {close $istate($sid,sock)}
    ifree $jlibname $sid
}

#--- Generic initiator code ----------------------------------------------------

proc jlib::bytestreams::s5i_server {jlibname} {
    
    upvar ${jlibname}::bytestreams::static static
    #puts "jlib::bytestreams::s5i_server (i)"
    
    # Note the difference between static(-port) and static(port) !
    set connectProc [list [namespace current]::s5i_accept $jlibname]
    set sock [socket -server $connectProc $static(-port)]
    set static(sock) $sock
    set static(port) [lindex [fconfigure $sock -sockname] 2]
}

# jlib::bytestreams::initiate --
# 
#       -streamhost {jid (-host -port | -zeroconf)}

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
#       We keep a single server socket for all transfers and distinguish
#       them when they do the SOCKS5 authentication using the mapping
#       hash (sha1 sid+jid+myjid)  -> sid

proc jlib::bytestreams::s5i_accept {jlibname sock addr port} {

    #puts "jlib::bytestreams::s5_accept (i)"
    
    #set istate($sid,sock) $sock
    fconfigure $sock -translation binary -blocking 0

    fileevent $sock readable \
      [list [namespace current]::s5i_read_methods $jlibname $sock]
}

proc jlib::bytestreams::s5i_read_methods {jlibname sock} {
   
    #puts "jlib::bytestreams::s5i_read_methods (i)"   
    
    #set sock $istate($sid,sock)
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
    
    upvar ${jlibname}::bytestreams::istate istate
    upvar ${jlibname}::bytestreams::hash2sid hash2sid
    #puts "jlib::bytestreams::s5i_read_auth (i)"

    #set sock $istate($sid,sock)
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
	set istate($sid,sock) $sock
	set reply [string replace $data 1 1 \x00]
	puts -nonewline $sock $reply
	flush $sock
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

proc jlib::bytestreams::ifree {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::istate istate
    #puts "jlib::bytestreams::ifree (i)"

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

proc jlib::bytestreams::handle_set {jlibname from queryElem args} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    #puts "jlib::bytestreams::handle_set (t) $args"
    
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
    set tstate($sid,id)     $id
    set tstate($sid,jid)    $from
    set tstate($sid,hosts)  $hosts
    set tstate($sid,rhosts) $hosts
    set tstate($sid,queryElem) $queryElem

    # Try the host(s) in turn.
    connect_host $jlibname $sid
    return 1
}

# jlib::bytestreams::connect_host --
# 
#       Is called recursively for each host until socks5 connection established.

proc jlib::bytestreams::connect_host {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    #puts "jlib::bytestreams::connect_host (t)"
    
    set rhosts $tstate($sid,rhosts)
    if {![llength $rhosts]} {
	
	# Deliver error to initiator.
	send_error $jlibname $sid 404 cancel item-not-found

	# Deliver error to target profile.
	jlib::si::stream_error $jlibname $sid item-not-found
	tfree $jlibname $sid
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
	set jid     $tstate($sid,jid)
	set id      $tstate($sid,id)
	set hostjid $tstate($sid,hostjid)
	set sock    $tstate($sid,sock)
	send_used $jlibname $jid $id $hostjid
	fileevent $sock readable  \
	  [list [namespace current]::readable $jlibname $sid]
    }
}

# jlib::bytestreams::readable --
# 
#       Reads channel and delivers data up to si.

proc  jlib::bytestreams::readable {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    #puts "jlib::bytestreams::readable (t)"

    # We may have been reset or something.
    if {![jlib::si::havesi $jlibname $sid]} {
	catch {close $tstate($sid,sock)}
	tfree $jlibname $sid
	return
    }
    
    set sock $tstate($sid,sock)
    if {[catch {eof $sock} iseof] || $iseof} {
	#puts "\t eof"
	catch {close $sock}
	# @@@ Perhaps we should check number of bytes reveived or something???
	jlib::si::stream_closed $jlibname $sid
	tfree $jlibname $sid
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

# jlib::bytestreams::socks5 --
# 
#       Open a client socket to the specified host and port and announce method.

proc jlib::bytestreams::socks5 {jlibname sid addr port cmd} {

    #puts "jlib::bytestreams::socks5 (t)"
    
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
	#puts "\t wrote 3: 'x05x01x00'"
    } err]} {
	return -code error $err
    }
    fileevent $sock readable  \
      [list [namespace current]::s5t_method_result $jlibname $sid $sock $cmd]
    return $sock
}

proc jlib::bytestreams::s5t_method_result {jlibname sid sock cmd} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
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
    set myjid [$jlibname myjid]
    set jid $tstate($sid,jid)
    set hash [::sha1::sha1 ${sid}${jid}${myjid}]    
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
      [list [namespace current]::s5t_auth_result $jlibname $sid $sock $cmd]
}

proc jlib::bytestreams::s5t_auth_result {jlibname sid sock cmd} {
    
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
    uplevel #0 $cmd
}

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

    #puts "jlib::bytestreams::send_error (t)"
    
    set id  $tstate($sid,id)
    set jid $tstate($sid,jid)
    set qel $tstate($sid,queryElem)
    jlib::send_iq_error $jlibname $jid $id $errcode $errtype $stanza $qel 
    tfree $jlibname $sid
}

proc jlib::bytestreams::tfree {jlibname sid} {
    
    upvar ${jlibname}::bytestreams::tstate tstate
    #puts "jlib::bytestreams::tfree (t)"

    array unset tstate $sid,*
}


# SURPLUS CODE ------------------------------------
# 
# 
# -------------------------


#--- target section ------------------------------------------------------------

namespace eval jlib::bytestreams::target { }



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

