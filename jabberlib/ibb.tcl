#  ibb.tcl --
#  
#      This file is part of the jabberlib. It provides support for the
#      ibb stuff (In Band Bytestreams).
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: ibb.tcl,v 1.8 2005-08-31 09:51:59 matben Exp $
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
#       
#       NEVER TESTED!!!!!!!

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
      [namespace current]::open   \
      [namespace current]::send   \
      [namespace current]::close    
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
    namespace eval ${jlibname}::ibb {
	variable priv
	variable opts
    }
    upvar ${jlibname}::ibb::priv priv
    upvar ${jlibname}::ibb::opts opts
    
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
    
    set rule1 [wrapper::createtag "rule"  \
      -attrlist {condition deliver-at value stored action error}]
    set rule2 [wrapper::createtag "rule"  \
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

# jlib::ibb::open, send, close --
# 
#       Bindings for si.

proc jlib::ibb::open {jlibname jid sid cmd} {
    
    puts "jlib::ibb::open"
    
    set open_cb [list [namespace current]::open_cb $jid $sid $cmd]
    send_set $jlibname to $cmd   
    return
}

proc jlib::ibb::open_cb {jid sid cmd } {
    
    
    
}

proc jlib::ibb::send {jlibname } {
    
    puts "jlib::ibb::send"
    
    
}

proc jlib::ibb::close {jlibname } {
    
    puts "jlib::ibb::close"
    
    
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# jlib::ibb::send_set --
# 
#       Initiates a transport
#
# Arguments:
#       to
#       cmd
#       args:   -data   binary data
#               -file   file path
#               -base64 
#       
# Results:
#       sid (Session IDentifier).

proc jlib::ibb::send_set {jlibname to sid cmd args} {

    variable xmlns
    upvar ${jlibname}::ibb::priv priv
    upvar ${jlibname}::ibb::opts opts

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
	set priv(sid,$sid,$key) $value
    }
    set priv(sid,$sid,to)  $to
    set priv(sid,$sid,cmd) $cmd

    jlib::send_iq $jlibname set [list $openElem] -to $to  \
      -command [list [namespace current]::OpenCB $jlibname]

    return $sid
}

proc jlib::ibb::OpenCB {jlibname } {
    
    upvar ${jlibname}::ibb::priv priv
    upvar ${jlibname}::ibb::opts opts

    
    set priv(sid,$sid,offset) 0
    
}

proc jlib::ibb::SendDataChunk {jlibname } {
    
    upvar ${jlibname}::ibb::priv priv
    upvar ${jlibname}::ibb::opts opts

    set bindata [string range $opts(-data) $offset \
      [expr $offset + $priv(binblock) -1]]
    if {[string length $bindata] == $priv(binblock)]} {
	set bindata [string trimright $bindata =]
    }
    incr offset $priv(binblock)
    set data [::base64::encode $bindata]
    SendData $ibbname $sid $data
}

proc jlib::ibb::InitFile {jlibname sid} {
    
    upvar ${jlibname}::ibb::priv priv
    upvar ${jlibname}::ibb::opts opts

    if {[catch {open $opts(-file) r} fd]} {
	return -code error $fd
    }
    set priv(sid,$sid,fd) $fd
    fconfigure $fd -translation binary
    
    
}

proc jlib::ibb::SendFileChunk {jlibname } {
    
    upvar ${jlibname}::ibb::priv priv
    upvar ${jlibname}::ibb::opts opts
    
    set fd $priv(sid,$sid,fd)
    set bindata [read $fd $priv(binblock)]
    if {![eof $fd]} {
	set bindata [string trimright $bindata =]
    }
    incr offset $priv(binblock)
    set data [::base64::encode $bindata]
    SendData $ibbname $sid $data
}

proc jlib::ibb::SendData {jlibname sid data} {
    
    upvar ${jlibname}::ibb::priv priv
    upvar ${jlibname}::ibb::opts opts
    
    
    $priv(jlibname) send_message   
}

proc jlib::ibb::handle_set {jlibname from subiq args} {

    array set argsArr $args
    
    switch -- $argsArr(-type) {
	error {
	    
	}
	default {
	    
	}    
    }
}


proc jlib::ibb::receive {jlibname subiq args} {

    
    
    
    return $sid
}

#-------------------------------------------------------------------------------
