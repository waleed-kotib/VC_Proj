#  ibb.tcl --
#  
#      This file is part of the jabberlib. It provides support for the
#      ibb stuff (In Band Bytestreams).
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: ibb.tcl,v 1.2 2004-07-02 14:08:02 matben Exp $
# 
############################# USAGE ############################################
#
#   NAME
#      ibb - convenience command library for the ibb part of XMPP.
#      
#   SYNOPSIS
#      jlib::ibb::new jlibname tclProc ?-opt value ...?
#
#   OPTIONS
#	-command tclProc
#	
#   INSTANCE COMMANDS
#      ibbName send jid command ?-key value?
#      
############################# CHANGES ##########################################
#
#       0.1         first version

package require jlib
package require base64

package provide ibb 0.1

namespace eval jlib::ibb {

    variable uid  0
    variable usid 0
    variable ibbxmlns "http://jabber.org/protocol/ibb"
    variable inited 0
}

# jlib::ibb::new --
# 
#       Sets up jabberlib handlers and makes a new instance if an ibb object.
  
proc jlib::ibb::new {jlibname cmd args} {

    variable uid
    variable ibbxmlns
    variable jlib2ibbname
    variable inited
        
    if {!$inited} {
	Init
    }
    set ibbname [namespace current]::ibb[incr uid]
    
    upvar ${ibbname}::priv priv
    upvar ${ibbname}::opts opts
    
    array set opts {
	-block-size     4096
    }
    array set opts $args
    set priv(jlibname) $jlibname
    set priv(cmd)      $cmd
    set jlib2ibbname($jlibname) $ibbname
    
    # Register some standard iq handlers that is handled internally.
    $jlibname iq_register set $ibbxmlns    \
      [namespace current]::handle_set

    # Create the actual instance procedure.
    proc $ibbname {cmd args}   \
      "eval [namespace current]::cmdproc {$ibbname} \$cmd \$args"

    return $ibbname
}

proc jlib::ibb::Init { } {
    
    variable ampElem
    variable inited
    
    set rule1 [wrapper::createtag "rule"  \
      -attrlist {condition deliver-at value stored action error}]
    set rule2 [wrapper::createtag "rule"  \
      -attrlist {condition match-resource value exact action error}]
    set ampElem [wrapper::createtag "amp" -attrlist \
      {xmlns http://jabber.org/protocol/amp} -subtags [list $rule1 $rule2]]
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

proc jlib::ibb::cmdproc {ibbname cmd args} {
    
    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $ibbname} $args]
}

# jlib::ibb::send --
# 
#       Initiates a transport
#
# Arguments:
#       to
#       cmd
#       args:   -data
#               -file
#       
# Results:
#       sid (Session IDentifier).

proc jlib::ibb::send {ibbname to cmd args} {

    variable usid
    variable ibbxmlns
    upvar ${ibbname}::priv priv
    upvar ${ibbname}::opts opts

    array set argsArr $opts
    array set argsArr $args
    if {![info exists argsArr(-data)] && ![info exists argsArr(-file)]} {
	return -code error "ibb must have any of -data or -file"
    }
    set sid [incr usid]
    set openElem [wrapper::createtag "open" -attrlist \
      [list sid $sid block-size $argsArr(-block-size) xmlns $ibbxmlns]
    
    # Keep internal storage for this request.
    foreach {key value} $args {
	set priv(sid,$sid,$key) $value
    }
    set priv(sid,$sid,to)  $to
    set priv(sid,$sid,cmd) $cmd

    $priv(jlibname) send_iq set $openElem -to $to  \
      -command [namespace current]::OpenCB

    return $sid
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
