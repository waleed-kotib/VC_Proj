#  ftrans.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for the file-transfer profile (JEP-0096).
#      
#      There are several layers involved when sending/receiving a file for 
#      instance. Each layer reports only to the nearest layer above using
#      callbacks. From top to bottom:
#      
#      1) application
#      2) file-transfer profile (this)
#      3) stream initiation (si)
#      4) the streams, bytestreams (socks5), ibb, etc.
#      5) jabberlib
#      
#      Each layer divides into two parts, the initiator and receiver.
#      Keep different state arrays for initiator (i) and receiver (r).
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: ftrans.tcl,v 1.2 2005-09-02 17:05:50 matben Exp $
# 
############################# USAGE ############################################
#
#   NAME
#      filetransfer - convenience library for the file-transfer profile of si.
#      
#   SYNOPSIS
#
#
#   OPTIONS
#
#	
#   INSTANCE COMMANDS
#      jlibName filetransfer send ...
#      jlibName filetransfer reset sid
#      jlibName filetransfer ifree sid
#      
############################# CHANGES ##########################################
#
#       0.1         first version

package require jlib		
package require jlib::si
			  
package provide jlib::ftrans 0.1

namespace eval jlib::ftrans {

    variable xmlns
    set xmlns(ftrans) "http://jabber.org/protocol/si/profile/file-transfer"
        
    jlib::ensamble_register filetransfer  \
      [namespace current]::init           \
      [namespace current]::cmdproc
    
    jlib::si::registerprofile $xmlns(ftrans)  \
      [namespace current]::profile_handler
}

proc jlib::ftrans::init {jlibname args} {
    
    # Keep different state arrays for initiator (i) and receiver (r).
    namespace eval ${jlibname}::ftrans {
	variable istate
	variable rstate
    }
    
    # Register this feature with disco.
    
    
}

# jlib::ftrans::cmdproc --
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

proc jlib::ftrans::cmdproc {jlibname cmd args} {
    
    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# These are all functions to use by a sender.


# jlib::ftrans::send --
# 
#       High level interface to the file-transfer profile for si.
#       
# Arguments:
#       jlibname:   the instance of this ibb.
#       jid:
#       args:       
#       
# Results:
#       sid to identify this transaction.

proc jlib::ftrans::send {jlibname jid cmd args} {

    puts "jlib::ftrans::send"
    
    variable xmlns
    upvar ${jlibname}::ftrans::istate istate
 
    array set opts {
	-progress     ""
	-description  ""
	-date         ""
	-hash         ""
	-block-size   4096
	-mime         application/octet-stream
    }
    array set opts $args
    if {![info exists opts(-data)]   \
      && ![info exists opts(-file)]  \
      && ![info exists opts(-base64)]} {
	return -code error "must have any of -data, -file, or -base64"
    }

    # @@@ TODO
    if {![info exists opts(-file)]} {return -code error "todo"}    
    
    switch -- [info exists opts(-base64)],[info exists opts(-data)],[info exists opts(-file)] {
	1,0,0 {
	    set dtype base64
	    set size [string length $opts(-base64)]
	}
	0,1,0 {
	    set dtype data
	    set size [string length $opts(-data)]
	}
	0,0,1 {
	    set dtype file
	    set fileName $opts(-file)
	    if {[catch {open $fileName {RDONLY}} fd]} {
		return -code error "failed open file \"$fileName\""
	    }
	    fconfigure $fd -translation binary
	    set size [file size $fileName]
	    set name [file tail $fileName]
	}
	default {
	    return -code error "must have exactly one of -data, -file, or -base64"
	}
    }
    
    set sid [jlib::generateuuid]

    set istate($sid,jid)    $jid
    set istate($sid,cmd)    $cmd
    set istate($sid,dtype)  $dtype
    set istate($sid,size)   $size
    set istate($sid,name)   $name
    set istate($sid,status) ""
    set istate($sid,bytes)  0
    foreach {key value} [array get opts] {
	set istate($sid,$key) $value
    }
    switch -- $dtype {
	file {
	    set istate($sid,fd) $fd
	}
    }
    set subElems {}
    if {[string length $opts(-description)]} {
	set descElem [wrapper::createtag "desc" -chdata $opts(-description)]
	set subElems [list $descElem]
    }
    set attrs [list xmlns $xmlns(ftrans) name $name size $size]
    if {[string length $opts(-date)]} {
	lappend attrs date $opts(-date)
    }
    if {[string length $opts(-hash)]} {
	lappend attrs date $opts(-hash)
    }    
    set fileElem [wrapper::createtag "file" -attrlist $attrs -subtags $subElems]
    
    # The 'block-size' is crucial here; must tell the stream in question.
    set cmd [namespace current]::filetransfer_cb
    jlib::si::send_set $jlibname $jid $sid $opts(-mime) $xmlns(ftrans)  \
      $fileElem $cmd -block-size $opts(-block-size)
      
    return $sid
}

proc jlib::ftrans::filetransfer_cb {jlibname type sid subiq} {
    
    puts "jlib::ftrans::filetransfer_cb"
    
    variable xmlns
    upvar ${jlibname}::ftrans::istate istate
    
    if {[string equal $type "error"]} {
	set istate($sid,status) "error"
	uplevel #0 $istate($sid,cmd) [list $jlibname error $sid $subiq]
	return
    }
    
    # @@@ assuming -file type
    SendFileChunk $jlibname $sid
}

# jlib::ftrans::SendFileChunk --
# 
#       Invokes the si's 'send_data' method which in turn calls the right
#       stream handler for this.

proc jlib::ftrans::SendFileChunk {jlibname sid} {
    
    upvar ${jlibname}::ftrans::istate istate
    
    # If we have reached eof we receive empty.
    if {[catch {
	set data [read $istate($sid,fd) $istate($sid,-block-size)]
    }]} {
	set istate($sid,status) "error"
	uplevel #0 $istate($sid,cmd) [list $jlibname error $sid {}]
	return
    }
    set len [string length $data]
    incr istate($sid,bytes) $len
    if {!$len} {
	
	# Empty -> eof.
	catch {close $istate($sid,fd)}
	set istate($sid,status) "ok"
	
	# Close stream.
	jlib::si::send_close $jlibname $sid
	uplevel #0 $istate($sid,cmd) [list $jlibname ok $sid {}]
    } else {

	# Invoke the si's method which calls the right stream handler to do the job.
	jlib::si::send_data $jlibname $sid $data
	
	if {[string length $istate($sid,-progress)]} {
	    uplevel #0 $istate($sid,-progress)  \
	      [list $jlibname $sid $istate($sid,size) $istate($sid,bytes)]
	}

	# Do like this to avoid blocking.
	set istate($sid,aid) [after idle  \
	  [list [namespace current]::SendFileChunk $jlibname $sid]]
    }
}

proc jlib::ftrans::reset {jlibname sid} {

    upvar ${jlibname}::ftrans::istate istate
    
    if {[info exists istate($sid,aid)]} {
	after cancel $istate($sid,aid)
    }
    set istate($sid,status) "reset"
    uplevel #0 $istate($sid,cmd) [list $jlibname reset $sid {}]
}

proc jlib::ftrans::ifree {jlibname sid} {

    upvar ${jlibname}::ftrans::istate istate

    array unset istate $sid,*    
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# These are all functions to use by a receiver of a stream.

proc jlib::ftrans::profile_handler {jlibname sid respCmd} {
    
    puts "jlib::ftrans::profile_handler"
    
    
    
    
    
    
    
    
    
}



