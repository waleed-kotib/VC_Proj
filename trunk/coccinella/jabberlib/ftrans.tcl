#  ftrans.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for the file-transfer profile (JEP-0096).
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: ftrans.tcl,v 1.3 2005-09-04 16:58:56 matben Exp $
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
      [namespace current]::open_handler       \
      [namespace current]::recv               \
      [namespace current]::closed
}

# jlib::ftrans::registerhandler --
# 
#       An application using file-transfer must register here to get a call
#       when we receive a file-transfer query.

proc jlib::ftrans::registerhandler {clientProc} {
    
    variable handler
    
    set handler $clientProc
}

proc jlib::ftrans::init {jlibname args} {
    
    # Keep different state arrays for initiator (i) and receiver (r).
    namespace eval ${jlibname}::ftrans {
	variable istate
	variable tstate
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
# These are all functions used by the sender (initiator).


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

    puts "jlib::ftrans::send (i)"
    
    variable xmlns
    upvar ${jlibname}::ftrans::istate istate
 
    # 4096 is recommended block-size
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
    set cmd [namespace current]::open_cb
    jlib::si::send_set $jlibname $jid $sid $opts(-mime) $xmlns(ftrans)  \
      $fileElem $cmd -block-size $opts(-block-size)
      
    return $sid
}

proc jlib::ftrans::open_cb {jlibname type sid subiq} {
    
    puts "jlib::ftrans::open_cb (i)"
    
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
    puts "jlib::ftrans::SendFileChunk (i) sid=$sid"
    
    # If we have reached eof we receive empty.
    if {[catch {
	set data [read $istate($sid,fd) $istate($sid,-block-size)]
    } err]} {
	puts "\t err=$err"
	set istate($sid,status) "error"
	uplevel #0 $istate($sid,cmd) [list $jlibname error $sid {}]
	ifree $jlibname $sid
	return
    }
    set len [string bytelength $data]
    incr istate($sid,bytes) $len
    if {!$len} {
	puts "\t eof"
	
	# Empty -> eof.
	catch {close $istate($sid,fd)}
	set istate($sid,status) "ok"
	
	# Close stream. 
	# Shall we wait for a result from this query before reporting?
	set cmd [namespace current]::close_cb
	jlib::si::send_close $jlibname $sid $cmd
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

proc jlib::ftrans::close_cb {jlibname type sid subiq} {
        
    upvar ${jlibname}::ftrans::istate istate
    puts "jlib::ftrans::close_cb (i)"

    uplevel #0 $istate($sid,cmd) [list $jlibname $type $sid $subiq]
    ifree $jlibname $sid
}

proc jlib::ftrans::ireset {jlibname sid} {

    upvar ${jlibname}::ftrans::istate istate
    
    if {[info exists istate($sid,aid)]} {
	after cancel $istate($sid,aid)
    }
    set istate($sid,status) "reset"
    uplevel #0 $istate($sid,cmd) [list $jlibname reset $sid {}]
    # ifree $jlibname $sid
}

proc jlib::ftrans::ifree {jlibname sid} {

    upvar ${jlibname}::ftrans::istate istate
    puts "jlib::ftrans::ifree sid=$sid"

    array unset istate $sid,*    
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# These are all functions to use by a target (receiver) of a stream.

# jlib::ftrans::open_handler --
# 
#       Callback when si receives this specific profile (file-transfer).

proc jlib::ftrans::open_handler {jlibname sid iqChild respCmd} {
    
    variable handler
    variable xmlns
    upvar ${jlibname}::ftrans::tstate tstate
    puts "jlib::ftrans::open_handler (t)"
    
    set siElem $iqChild
    set fileElem [wrapper::getfirstchild $siElem "file" $xmlns(ftrans)]
    if {![llength $fileElem]} {
	# Exception
	return
    }
    set tstate($sid,mime) [wrapper::getattribute $siElem "mime-type"]
    
    # File element attributes 'name' and 'size' are required!
    array set attr {
	name        ""
	size        0
	date        ""
	hash        ""
    }
    array set attr [wrapper::getattrlist $fileElem]
    foreach {name value} [array get attr] {
	set tstate($sid,$name) $value
    }
    set tstate($sid,desc) ""
    set descElem [wrapper::getfirstchildwithtag $fileElem "desc"]
    if {[llength $descElem]} {
	set tstate($sid,desc) [wrapper::getcdata $descElem]
    }
    set tstate($sid,cmd)   $respCmd
    set tstate($sid,bytes) 0
    set opts {}
    foreach key {mime desc hash date} {
	if {[string length $tstate($sid,$key)]} {
	    lappend opts -$key $tstate($sid,$key)
	}
    }
    
    # Make a call up to application level to pick destination file.
    # This is an idle call in order to not block.
    set cmd [list [namespace current]::accept $jlibname $sid]
    after idle [list eval $handler [list $jlibname $attr(name) $attr(size) $cmd] $opts]
    return
}

# jlib::ftrans::accept --
# 
#       Used by profile handler to accept/reject file transfer.

proc jlib::ftrans::accept {jlibname sid accepted args} {
    
    upvar ${jlibname}::ftrans::tstate tstate
    
    array set opts {
	-progress     ""
	-command      ""
    }
    array set opts $args
    foreach {key value} [array get opts] {
	set tstate($sid,$key) $value
    }
    if {$accepted} {
	set type ok
    } else {
	set type error
    }

    set respCmd $tstate($sid,cmd)
    eval $respCmd [list $type {}]
    if {!$accepted} {
	tfree $jlibname $sid
    }
}

proc jlib::ftrans::recv {jlibname sid data} {
    
    upvar ${jlibname}::ftrans::tstate tstate
    puts "jlib::ftrans::recv (t)"
    
    set len [string bytelength $data]
    incr tstate($sid,bytes) $len
    if {[llength $tstate($sid,-progress)]} {
	uplevel #0 $tstate($sid,-progress) [list $jlibname $sid  \
	  $tstate($sid,size) $tstate($sid,bytes)]
    }
    
}

proc jlib::ftrans::closed {jlibname sid} {
    
    upvar ${jlibname}::ftrans::tstate tstate
    puts "jlib::ftrans::closed (t)"
    
    if {[llength $tstate($sid,-command)]} {
	uplevel #0 $tstate($sid,-command) [list $jlibname $sid ok]
    }
    tfree $jlibname $sid
}

proc jlib::ftrans::treset {jlibname sid} {

    upvar ${jlibname}::ftrans::tstate tstate
    
    set tstate($sid,status) "reset"
    if {[llength $tstate($sid,-command)]} {
	uplevel #0 $tstate($sid,-command) [list $jlibname $sid reset]
    }
}

proc jlib::ftrans::tfree {jlibname sid} {

    upvar ${jlibname}::ftrans::tstate tstate
    puts "jlib::ftrans::tfree (t) sid=$sid"

    array unset tstate $sid,*    
}

#-------------------------------------------------------------------------------
