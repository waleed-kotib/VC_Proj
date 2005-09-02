#  ibb.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for the ibb stuff (In Band Bytestreams).
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: ibb.tcl,v 1.10 2005-09-02 17:05:50 matben Exp $
# 
############################# USAGE ############################################
#
#   NAME
#      ibb - convenience command library for the ibb part of XMPP.
#      
#   SYNOPSIS
#      jlib::ibb::init jlibname
#
#   OPTIONS
#   
#	
#   INSTANCE COMMANDS
#      jlibName ib send_set jid command ?-key value?
#      
############################# CHANGES ##########################################
#
#       0.1         first version

package require jlib
package require base64     ; # tcllib
package require jlib::si

package provide jlib::ibb 0.1

namespace eval jlib::ibb {

    variable inited 0
    variable xmlns
    set xmlns(ibb) "http://jabber.org/protocol/ibb"

    jlib::ensamble_register ibb   \
      [namespace current]::init   \
      [namespace current]::cmdproc
    
    jlib::si::registertransport $xmlns(ibb) $xmlns(ibb) 80  \
      [namespace current]::si_open   \
      [namespace current]::si_send   \
      [namespace current]::si_close
}

# jlib::ibb::init --
# 
#       Sets up jabberlib handlers and makes a new instance if an ibb object.
  
proc jlib::ibb::init {jlibname args} {

    puts "jlib::ibb::init"
    
    variable inited
    variable xmlns
    
    if {!$inited} {
	InitOnce
    }    

    # Keep different state arrays for initiator (i) and receiver (r).
    namespace eval ${jlibname}::ibb {
	variable priv
	variable opts
	variable istate
	variable rstate
    }
    upvar ${jlibname}::ibb::priv  priv
    upvar ${jlibname}::ibb::opts  opts
    
    array set opts {
	-block-size     4096
    }
    array set opts $args
    
    # Each base64 byte takes 6 bits; need to translate to binary bytes.
    set priv(binblock) [expr {(6 * $opts(-block-size))/8}]
    set priv(binblock) [expr {6 * ($priv(binblock)/6)}]
    
    # Register some standard iq handlers that is handled internally.
    $jlibname iq_register set $xmlns(ibb) [namespace current]::handle_set

    return
}

proc jlib::ibb::InitOnce { } {
    
    variable ampElem
    variable inited
    variable xmlns
    
    set rule1 [wrapper::createtag "rule"   \
      -attrlist {condition deliver-at value stored action error}]
    set rule2 [wrapper::createtag "rule"   \
      -attrlist {condition match-resource value exact action error}]
    set ampElem [wrapper::createtag "amp"  \
      -attrlist [list xmlns $xmlns(ibb)]   \
      -subtags [list $rule1 $rule2]]

    set inited 1
}

# jlib::ibb::cmdproc --
#
#       Just dispatches the command to the right procedure.
#
# Arguments:
#       jlibname:   the instance of this ibb.
#       cmd:        
#       args:       all args to the cmd procedure.
#       
# Results:
#       none.

proc jlib::ibb::cmdproc {jlibname cmd args} {
    
    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# These are all functions to use by a sender.

# jlib::ibb::si_open, si_send, si_close --
# 
#       Bindings for si.

proc jlib::ibb::si_open {jlibname jid sid cmd args} {
    
    puts "jlib::ibb::si_open"
    upvar ${jlibname}::ibb::istate istate
    
    set istate($sid,jid) $jid
    set istate($sid,cmd) $cmd
    set istate($sid,seq) 0
    set si_open_cb [namespace current]::si_open_cb
    eval {send_open $jlibname $sid $si_open_cb} $args
    return
}

proc jlib::ibb::si_open_cb {jlibname sid type subiq args} {
    
    puts "jlib::ibb::si_open_cb"    
    upvar ${jlibname}::ibb::istate istate
    
    set cmd $istate($sid,cmd)
    set jid $istate($sid,jid)

    uplevel #0 $cmd [list $jlibname $jid $sid $type $subiq]
}

proc jlib::ibb::si_send {jlibname sid data} {
    
    puts "jlib::ibb::si_send"
    upvar ${jlibname}::ibb::istate istate
    
    set jid $istate($sid,jid)
    send_data $jlibname $jid $sid $data [namespace current]::si_send_cb
}

# jlib::ibb::si_send_cb --
# 
#       JEP says that we SHOULD track each mesage, in case of error.

proc jlib::ibb::si_send_cb {jlibname sid type subiq args} {

    puts "jlib::ibb::si_send_cb"
    upvar ${jlibname}::ibb::istate istate

    if {[string equal $type "error"]} {
	set cmd $istate($sid,cmd)
	set jid $istate($sid,jid)
	uplevel #0 $cmd [list $jlibname $jid $sid $type $subiq]
    }
}

proc jlib::ibb::si_close {jlibname sid} {
    
    puts "jlib::ibb::si_close"
    upvar ${jlibname}::ibb::istate istate

    set jid $istate($sid,jid)

    send_close $jlibname $jid $sid [namespace current]::si_close_cb
}

proc jlib::ibb::si_close_cb {jlibname sid type subiq args} {
    
    puts "jlib::ibb::si_close_cb"
    upvar ${jlibname}::ibb::istate istate

    set cmd $istate($sid,cmd)
    set jid $istate($sid,jid)
    
    uplevel #0 $cmd [list $jlibname $jid $sid $type $subiq]
    # @@@ ???
    ifree $jlibname $sid
}

proc jlib::ibb::ifree {jlibname sid} {
    
    puts "jlib::ibb::ifree"   
    upvar ${jlibname}::ibb::istate istate

    array unset istate $sid,*
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

proc jlib::ibb::configure {jlibname args} {
    
    upvar ${jlibname}::ibb::opts opts

    # @@@ TODO
    
}

# jlib::ibb::send_open --
# 
#       Initiates a file transport. We must be able to configure 'block-size'
#       from the file-transfer profile.
#
# Arguments:
# 

proc jlib::ibb::send_open {jlibname jid sid cmd args} {
    
    variable xmlns
    upvar ${jlibname}::ibb::opts opts
    
    array set arr [list -block-size $opts(-block-size)]
    array set arr $args
        
    set openElem [wrapper::createtag "open"  \
      -attrlist [list sid $sid block-size $arr(-block-size) xmlns $xmlns(ibb)]
    jlib::send_iq $jlibname set [list $openElem] -to $jid  \
      -command [concat $cmd [list $jlibname $sid]]
    return
}

# jlib::ibb::send_data --
# 
# 

proc jlib::ibb::send_data {jlibname jid sid data cmd} {
    
    variable xmlns
    variable ampElem
    upvar ${jlibname}::ibb::istate istate

    set jid $istate($sid,jid)
    set seq $istate($sid,seq)
    # @@@ What abot the extra = appended??? [string trimright $bindata =]
    set edata [base64::encode $data]
    set dataElem [wrapper::createtag "data"  \
      -attrlist [list xmlns $xmlns(ibb) sid $sid seq $seq]  \
      -chdata $edata]
    set istate($sid,seq) [expr {($seq + 1) % 65536}]

    jlib::send_message $jlibname $jid -xlist [list $dataElem $ampElem]  \
      -command [concat $cmd [list $jlibname $sid]]
}

# jlib::ibb::send_close --
# 
#       Sends the close tag.
#
# Arguments:
# 

proc jlib::ibb::send_close {jlibname jid sid cmd} {
    
    variable xmlns

    set closeElem [wrapper::createtag "close"  \
      -attrlist [list sid $sid xmlns $xmlns(ibb)]
    jlib::send_iq $jlibname set [list $closeElem] -to $jid  \
      -command [concat $cmd [list $jlibname $sid]]
    return
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# These are all functions to use by a receiver of a stream.

# jlib::ibb::handle_set --
# 
#       Parse incoming ibb iq-set open/close element.
#       It is being assumed that we already have accepted a stream initiation.

proc jlib::ibb::handle_set {jlibname from subiq args} {

    variable xmlns
    upvar ${jlibname}::ibb::rstate rstate
    
    
    
    set tag [wrapper::gettag $subiq]
    array set attr [wrapper::getattrlist $subiq]
    array set argsArr $args
    if {![info exists argsArr(-id)] || ![info exists attr(sid)]} {
	# We can't do more here.
	return
    }
    set sid $attr(sid)
    
    # We make sure that we have already got a si with this sid.
    if {[jlib::si::havesi $jlibname $sid]} {
	send error
	return
    }

    switch -- $tag {
	open {
	    if {![info exists attr(block-size)]} {
		send error
		return
	    }
	    set rstate($sid,jid)        $from
	    set rstate($sid,block-size) $attr(block-size)
	    
	    # Make a success response on open.
	    jlib::send_iq $jlibname "result" {} -to $from -id $argsArr(-id)
	}
	close {
	    
	    # Make a success response on close.
	    jlib::send_iq $jlibname "result" {} -to $from -id $argsArr(-id)
	    jlib::si::stream_closed $jlibname $sid
	    rfree $jlibname $sid
	}
	default {
	    send error
	    return
	}
    }
    return 1
}




proc jlib::ibb::rfree {jlibname sid} {
    
    puts "jlib::ibb::rfree"   
    upvar ${jlibname}::ibb::rstate rstate

    array unset rstate $sid,*
}

# UNTESTED ........... !!!  DO NOT USE !!!--------------------------------------
# 
# ------------------------------------------------------------------------------

# jlib::ibb::send_file --
# 
#       Supposed to be a high level send interface. Not used by si.
#
# Arguments:
#       jid
#       cmd
#       args:   -data   binary data
#               -file   file path
#               -base64 
#       
# Results:
#       sid (Session IDentifier).

proc jlib::ibb::send_fileXXX {jlibname jid sid cmd args} {

    variable xmlns
    upvar ${jlibname}::ibb::priv priv
    upvar ${jlibname}::ibb::opts opts
    upvar ${jlibname}::ibb::state state

    array set argsArr $opts
    array set argsArr $args
    if {![info exists argsArr(-data)]   \
      && ![info exists argsArr(-file)]  \
      && ![info exists argsArr(-base64)]} {
	return -code error "ibb must have any of -data, -file, or -base64"
    }
    set openElem [wrapper::createtag "open" -attrlist \
      [list sid $sid block-size $argsArr(-block-size) xmlns $xmlns(ibb)]
    
    # Keep internal storage for this request.
    foreach {key value} $args {
	set state($sid,$key) $value
    }
    set state($sid,jid) $jid
    set state($sid,cmd) $cmd

    jlib::send_iq $jlibname set [list $openElem] -to $jid  \
      -command [list [namespace current]::OpenCB $jlibname]

    return $sid
}

proc jlib::ibb::OpenCBXXX {jlibname } {
    
    upvar ${jlibname}::ibb::state state

    
    set state($sid,offset) 0
    
}

proc jlib::ibb::SendDataChunkXXX {jlibname } {
    
    upvar ${jlibname}::ibb::priv priv
    upvar ${jlibname}::ibb::opts opts
    upvar ${jlibname}::ibb::state state

    set bindata [string range $opts(-data) $offset \
      [expr $offset + $priv(binblock) -1]]
    if {[string length $bindata] == $priv(binblock)]} {
	set bindata [string trimright $bindata =]
    }
    incr offset $priv(binblock)
    set data [::base64::encode $bindata]
    SendData $ibbname $sid $data
}

proc jlib::ibb::InitFileXXX {jlibname sid} {
    
    upvar ${jlibname}::ibb::priv priv
    upvar ${jlibname}::ibb::opts opts
    upvar ${jlibname}::ibb::state state

    if {[catch {open $opts(-file) r} fd]} {
	return -code error $fd
    }
    set state($sid,fd) $fd
    fconfigure $fd -translation binary
    
    
}

proc jlib::ibb::SendFileChunkXXX {jlibname } {
    
    upvar ${jlibname}::ibb::priv priv
    upvar ${jlibname}::ibb::opts opts
    upvar ${jlibname}::ibb::state state
    
    set fd $state($sid,fd)
    set bindata [read $fd $priv(binblock)]
    if {![eof $fd]} {
	set bindata [string trimright $bindata =]
    }
    incr offset $priv(binblock)
    set data [::base64::encode $bindata]
    SendData $ibbname $sid $data
}

proc jlib::ibb::SendDataXXX {jlibname sid data} {
    
    upvar ${jlibname}::ibb::priv priv
    upvar ${jlibname}::ibb::opts opts
    
    
    $jlibname send_message   
}

proc jlib::ibb::handle_setXXX {jlibname from subiq args} {

    array set argsArr $args
    
    switch -- $argsArr(-type) {
	error {
	    
	}
	default {
	    
	}    
    }
}


proc jlib::ibb::receiveXXX {jlibname subiq args} {

    
    
    
    return $sid
}

#-------------------------------------------------------------------------------
