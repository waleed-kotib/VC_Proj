#  ftrans.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for the file-transfer profile (JEP-0096).
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: ftrans.tcl,v 1.1 2005-09-01 14:01:09 matben Exp $
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
#      jlibName filetransfer ...
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
    
    namespace eval ${jlibname}::ftrans {
	variable state
    }
    upvar ${jlibname}::ftrans::state state
    
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
    upvar ${jlibname}::ftrans::state state
 
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

    set state($sid,jid)    $jid
    set state($sid,cmd)    $cmd
    set state($sid,dtype)  $dtype
    set state($sid,size)   $size
    set state($sid,name)   $name
    set state($sid,status) ""
    set state($sid,bytes)  0
    foreach {key value} [array get opts] {
	set state($sid,$key) $value
    }
    switch -- $dtype {
	file {
	    set state($sid,fd) $fd
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
    jlib::si::send_set $jlibname $jid $sid $opts(mime) $xmlns(ftrans)  \
      $fileElem $cmd -block-size $opts(-block-size)
      
    return $sid
}

proc jlib::ftrans::filetransfer_cb {jlibname type sid subiq} {
    
    puts "jlib::ftrans::filetransfer_cb"
    
    variable xmlns
    upvar ${jlibname}::ftrans::state state
    
    if {[string equal $type "error"]} {
	set state($sid,status) "error"
	uplevel #0 $state($sid,cmd) [list $jlibname error $sid $subiq]
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
    
    upvar ${jlibname}::ftrans::state state
    
    # If we have reached eof we receive empty.
    if {[catch {
	set data [read $state($sid,fd) $state($sid,-block-size)]
    }]} {
	set state($sid,status) "error"
	uplevel #0 $state($sid,cmd) [list $jlibname error $sid {}]
	return
    }
    set len [string length $data]
    incr state($sid,bytes) $len
    if {!$len} {
	
	# Empty -> eof.
	catch {close $state($sid,fd)}
	set state($sid,status) "ok"
	
	# Close stream.
	jlib::si::close $jlibname $sid
	uplevel #0 $state($sid,cmd) [list $jlibname ok $sid {}]
    } else {

	# Invoke the si's method which calls the right stream handler to do the job.
	jlib::si::send_data $jlibname $sid $data
	
	if {[string length $state($sid,-progress)]} {
	    uplevel #0 $state($sid,-progress)  \
	      [list $jlibname $sid $state($sid,size) $state($sid,bytes)]
	}

	# Do like this to avoid blocking.
	set state($sid,aid) [after idle  \
	  [list [namespace current]::SendFileChunk $jlibname $sid]]
    }
}

proc jlib::ftrans::reset {jlibname sid} {

    upvar ${jlibname}::ftrans::state state
    
    if {[info exists state($sid,aid)]} {
	after cancel $state($sid,aid)
    }
    set state($sid,status) "reset"
    uplevel #0 $state($sid,cmd) [list $jlibname reset $sid {}]
}

proc jlib::ftrans::free {jlibname sid} {

    upvar ${jlibname}::ftrans::state state

    array unset state $sid,*    
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# These are all functions to use by a receiver of a stream.

proc jlib::ftrans::profile_handler {jlibname ...} {
    
    puts "jlib::ftrans::profile_handler"
    
    
    
    
    
    
    
    
    
}



