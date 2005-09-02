#  bytestreams.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for the bytestreams protocol (JEP-0065).
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: bytestreams.tcl,v 1.5 2005-09-02 17:05:50 matben Exp $
# 
############################# USAGE ############################################
#
#   NAME
#
#      
#   SYNOPSIS
#
#
#   OPTIONS
#
#	
#   INSTANCE COMMANDS
#
#      
############################# CHANGES ##########################################
#
#       0.1         first version
#       
#       NEVER TESTED!!!!!!!

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
    
    $jlibname iq_register set $xmlns(bs) [namespace current]::handle_set
}

proc jlib::bytestreams::cmdproc {jlibname cmd args} {
    
    Debug 4 "jlib::bytestreams::cmdproc jlibname=$jlibname, cmd='$cmd', args='$args'"

    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# jlib::bytestreams::si_open, si_send, si_close --
# 
#       Bindings for si.

proc jlib::bytestreams::si_open {jlibname jid sid cmd} {
    
    puts "jlib::bytestreams::si_open"
    
    set si_open_cb [list [namespace current]::si_open_cb $cmd]
    #send_set $jlibname $jid $sid $si_open_cb
    return
}

proc jlib::bytestreams::si_open_cb {jlibname jid sid cmd type subiq args} {
    
    puts "jlib::bytestreams::si_open_cb"
    
    uplevel #0 $cmd [list $jlibname $sid $type $subiq]
}

proc jlib::bytestreams::si_send {jlibname } {
    
    puts "jlib::bytestreams::si_send"
    
    
}

proc jlib::bytestreams::si_close {jlibname } {
    
    puts "jlib::bytestreams::si_close"
    
    
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

proc jlib::bytestreams::initiate {jlibname to sid args} {
    variable xmlns
    
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

# jlib::bytestreams::used --
# 
#       Target notifies initiator of connection.

proc jlib::bytestreams::used {jlibname to id hostjid} {
    variable xmlns
    
    set usedElem [wrapper::createtag "streamhost-used" \
      -attrlist [list jid $hostjid]]
    set xmllist [wrapper::createtag "query" \
      -attrlist [list xmlns $xmlns(bs)] \
      -subtags [list $usedElem]]

    $jlibname send_iq "result" [list $xmllist] -to $to -id $id
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
    
    array set argsArr $args
    array set attr [wrapper::getattrlist $queryElem]
    if {![info exists attr(sid)]} {
	eval {return_bad_request $jlibname $queryElem} $args
	return 1
    }
    if {![info exists argsArr(id)]} {

	# We cannot handle this since missing id-attribute.
	return 1
    }
    set hosts {}
    foreach elem [wrapper::getchildren $queryElem] {
	if {[wrapper::gettag $elem] eq "streamhost"} {
	    array unset attr
	    array set attr [wrapper::getattrlist $elem]
	    if {[info exists attr(jid)] && \
	      [info exists attr(host)] && \
	      [info exists attr(port)]} {
		lappend hosts [list $attr(jid) $attr(host) $attr(port)]
	    }
	}
    }
    if {$hosts == {}} {
	eval {return_bad_request $jlibname $queryElem} $args
	return 1
    }

    # Try the host(s).
    eval {target::init $jlibname $from $queryElem $attr(sid) $hosts} $args
    return 1
}

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

    set state($sid,jid)       $jid
    set state($sid,hosts)     $hosts
    set state($sid,queryElem) $queryElem
    set state($sid,args)      $args
    
    connect $jlibname $jid $sid $rhosts
}

proc jlib::bytestreams::target::connect {jlibname sid rhosts} {
    variable state

    # Pick first host in rhost list.
    set host [lindex $rhosts 0]
    set rhosts [lrange 1 end]
    
    socks5 $jlibname $jid $sid $host \
      [list [namespace current]::connect_cb $jlibname $sid $rhosts]    
}

proc jlib::bytestreams::target::connect_cb {jlibname sid rhosts err} {
    variable state
    
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





#--- initiator section ---------------------------------------------------------

namespace eval jlib::bytestreams::initiator { }


proc jlib::bytestreams::initiator::connect {jlibname jid sid} {
    variable state
    
    set sock [socket -server [list [namespace current]::accept $sid] 0]
    lassign [fconfigure $sock -sockname] addr hostname port
    # @@@ fails for nonsocket transports
    set ip    [jlib::ipsocket $jlibname]
    set myjid [jlib::myjid $jlibname]
    set hash [::sha1::sha1 ${sid}${myjid}${jid}]
    
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



#-------------------------------------------------------------------------------

