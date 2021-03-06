#  ftrans.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for the file-transfer profile (XEP-0096).
#      
#  Copyright (c) 2005-2007  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: ftrans.tcl,v 1.31 2008-02-10 09:43:22 matben Exp $
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
#      jlibName filetransfer send jid tclProc  \
#                 -progress, -description, -date, -hash, -block-size, -mime
#      jlibName filetransfer reset sid
#      jlibName filetransfer ifree sid
#      
############################# CHANGES ##########################################

package require jlib		
package require jlib::si
package require jlib::disco
			  
package provide jlib::ftrans 0.1

namespace eval jlib::ftrans {

    variable xmlns
    set xmlns(ftrans) "http://jabber.org/protocol/si/profile/file-transfer"
            
    # Our target handlers.
    jlib::si::registerprofile $xmlns(ftrans)  \
      [namespace current]::open_handler       \
      [namespace current]::recv               \
      [namespace current]::close_handler
    	
    # This is our reader commands when the transport sends off data
    # on the network.
    jlib::si::registerreader $xmlns(ftrans)  \
      [namespace current]::open_data         \
      [namespace current]::read_data         \
      [namespace current]::close_data
    
    jlib::disco::registerfeature $xmlns(ftrans)

    # Note: jlib::ensamble_register is last in this file!
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
#       jlibname:   the instance of this jlib.
#       cmd:        
#       args:       all args to the cmd procedure.
#       
# Results:
#       none.

proc jlib::ftrans::cmdproc {jlibname cmd args} {
    return [eval {$cmd $jlibname} $args]
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# These are all functions used by the initiator (sender).

# jlib::ftrans::send --
# 
#       High level interface to the file-transfer profile for si.
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:
#       args:       
#       
# Results:
#       sid to identify this transaction.

proc jlib::ftrans::send {jlibname jid cmd args} {
    variable xmlns
    upvar ${jlibname}::ftrans::istate istate
    #puts "jlib::ftrans::send $args"

    set sid [jlib::util::from args -sid [jlib::generateuuid]]
    set fileE [eval {i_constructor $jlibname $sid $jid $cmd} $args]

    # The 'block-size' is crucial here; must tell the stream in question.
    set cmd [namespace current]::open_cb
    jlib::si::send_set $jlibname $jid $sid $istate($sid,-mime) $xmlns(ftrans) \
      $fileE $cmd -block-size $istate($sid,-block-size)
    
    return $sid
}

# jlib::ftrans::i_constructor --
# 
#       This is the initiator constructor of a file transfer object.
#       Makes a new ftrans instance but doesn't do any networking.
#       
# Results:
#       The file element.

proc jlib::ftrans::i_constructor {jlibname sid jid cmd args} {
    variable xmlns
    upvar ${jlibname}::ftrans::istate istate
    
    # 4096 is the recommended block-size
    array set opts {
	-progress     ""
	-block-size   4096 
	-mime         application/octet-stream
    }
    array set opts $args
    if {![info exists opts(-data)]   \
      && ![info exists opts(-file)]  \
      && ![info exists opts(-base64)]} {
	return -code error "must have any of -data, -file, or -base64"
    }
    #puts "jlib::ftrans::i_constructor (i) $args"
    
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
	    if {![file readable $fileName]} {
		return -code error "file \"$fileName\" is not readable"
	    }
	    
	    # File open is not done until we get the 'open_cb'.
	    set size [file size $fileName]
	    set name [file tail $fileName]
	}
	default {
	    return -code error "must have exactly one of -data, -file, or -base64"
	}
    }
    set istate($sid,sid)    $sid
    set istate($sid,jid)    $jid
    set istate($sid,cmd)    $cmd
    set istate($sid,dtype)  $dtype
    set istate($sid,size)   $size
    set istate($sid,status) ""
    set istate($sid,bytes)  0
    foreach {key value} [array get opts] {
	set istate($sid,$key) $value
    }
    switch -- $dtype {
	file {
	    set istate($sid,name)     $name
	    set istate($sid,fileName) $fileName
	}
    }
    
    return [eval {element $name $size} $args]
}

# jlib::ftrans::uri --
# 
#       Create a sipub uri that references a local file.
#       XEP-0096 File Transfer, sect. 6.2.2 recvfile:
#       xmpp:romeo@montague.net/orchard?recvfile;sid=pub234;mime-type=text%2Fplain&name=reply.txt&size=2048 

proc jlib::ftrans::uri {jid fileName mime} {
   
    # NB: The JID must be uri encoded as a path to preserver the "/"
    #     while the query part must be encoded as is.
    set spid [jlib::sipub::newcache $fileName $mime]
    set tail [file tail $fileName]
    set size [file size $fileName]
    set jid [uriencode::quotepath $jid]
    set uri "xmpp:$jid?recvfile"
    set uri2 ""
    append uri2 ";" "sid=$spid"
    append uri2 ";" "mime-type=$mime"
    append uri2 ";" "name=$tail"
    append uri2 ";" "size=$size"
    set uri2 [::uri::urn::quote $uri2]
    
    return $uri$uri2
}

# jlib::ftrans::element --
# 
#       Just create the file element. Nothing cached. Stateless.
#       
#       <file xmlns='http://jabber.org/protocol/si/profile/file-transfer'
#           name='NDA.pdf'
#           size='138819'
#           date='2004-01-28T10:07Z'>
#         <desc>All Shakespearean characters must sign and return this NDA ASAP</desc>
#       </file> 
#       
# Arguments:
#       name
#       size
#       args: -description -date -hash
#       
# Result:
#       The file element.

proc jlib::ftrans::element {name size args} {
    variable xmlns
    
    array set argsA $args
    
    set subEL [list]
    if {[info exists argsA(-description)]} {
	set descE [wrapper::createtag "desc" -chdata $argsA(-description)]
	set subEL [list $descE]
    }
    set attrs [list xmlns $xmlns(ftrans) name $name size $size]
    if {[info exists argsA(-date)]} {
	lappend attrs date $argsA(-date)
    }
    if {[info exists argsA(-hash)]} {
	lappend attrs hash $argsA(-hash)
    }    
    set fileE [wrapper::createtag "file" -attrlist $attrs -subtags $subEL]
    
    return $fileE
}

# jlib::ftrans::sipub_element --
# 
#       This creates a new sipub instance. Typically only used for normal
#       messages. For groupchats, pubsub etc. you must not use this one.

proc jlib::ftrans::sipub_element {jlibname name size fileName mime args} {
    variable xmlns
    
    set fileE [element $name $size]
    set sipubE [jlib::sipub::element [$jlibname myjid] $xmlns(ftrans) \
      $fileE $fileName $mime]

    return $sipubE
}

# jlib::ftrans::open_cb --
# 
#       This is a transports way of reporting result from it's 'open' method.

proc jlib::ftrans::open_cb {jlibname type sid subiq} {
    variable xmlns
    upvar ${jlibname}::ftrans::istate istate
    
    #puts "jlib::ftrans::open_cb (i)"
        
    if {[string equal $type "error"]} {
	set istate($sid,status) "error"
	uplevel #0 $istate($sid,cmd) [list $jlibname error $sid $subiq]
	ifree $jlibname $sid
    }
}

# jlib::ftrans::open_data, read_data, close_data --
# 
#       These are all used by the streams (transports) to handle the data
#       stream it needs when transmitting.

proc jlib::ftrans::open_data {jlibname sid} {
    upvar ${jlibname}::ftrans::istate istate
    #puts "jlib::ftrans::open_data (i) sid=$sid"
    
    # @@@ assuming -file type
    # This must never fail since tested if 'readable' before.
    set fd [open $istate($sid,fileName) r]
    fconfigure $fd -translation binary
    set istate($sid,fd) $fd
    return
}

proc jlib::ftrans::read_data {jlibname sid} {    
    upvar ${jlibname}::ftrans::istate istate
    #puts "jlib::ftrans::read_data (i) sid=$sid"

    # If we have reached eof we receive empty.
    set data [read $istate($sid,fd) $istate($sid,-block-size)]
    set len [string length $data]
    #puts "\t len=$len"
    incr istate($sid,bytes) $len

    if {[string length $istate($sid,-progress)]} {
	uplevel #0 $istate($sid,-progress)  \
	  [list $jlibname $sid $istate($sid,size) $istate($sid,bytes)]
    }
    return $data
}

# This is called by the stream when either all data have been sent or if
# there is any network error.

proc jlib::ftrans::close_data {jlibname sid {err ""}} {    
    upvar ${jlibname}::ftrans::istate istate
    #puts "jlib::ftrans::close_data (i) sid=$sid, err=$err"

    # Empty -> eof.
    catch {close $istate($sid,fd)}
    
    if {$err eq ""} {
	set istate($sid,status) "ok"
    } else {
	set istate($sid,status) "error"
	set istate($sid,error) "networkerror"
    }
    
    # Close stream. 
    # Shall we wait for a result from this query before reporting?
    set cmd [namespace current]::close_cb
    jlib::si::send_close $jlibname $sid $cmd
}

# jlib::ftrans::close_cb --
# 
#       This is the callback to 'jlib::si::send_close'.
#       It is our destructor.

proc jlib::ftrans::close_cb {jlibname type sid subiq} {        
    upvar ${jlibname}::ftrans::istate istate
    #puts "jlib::ftrans::close_cb (i)"

    # We may have an error status.
    set status $istate($sid,status)
    if {$status eq "error"} {
	set err $istate($sid,error)
	uplevel #0 $istate($sid,cmd) [list $jlibname error $sid [list $err ""]]
    } elseif {$status eq "reset"} {
	uplevel #0 $istate($sid,cmd) [list $jlibname reset $sid {}]
    } else {
	uplevel #0 $istate($sid,cmd) [list $jlibname $type $sid $subiq]
    }
    
    # There could be situations, a transfer manager, where we want to keep
    # this information.
    ifree $jlibname $sid
}

# jlib::ftrans::ireset --
# 
#       Reset an initiated transaction.

proc jlib::ftrans::ireset {jlibname sid} {
    upvar ${jlibname}::ftrans::istate istate
    
    if {[info exists istate($sid,aid)]} {
	after cancel $istate($sid,aid)
    }
    set istate($sid,status) "reset"
    set cmd [namespace current]::close_cb
    jlib::si::send_close $jlibname $sid $cmd
}

proc jlib::ftrans::iresetall {jlibname} {
    
    foreach spec [initiatorinfo $jlibname] {
	set sid [lindex $spec 0]
	ireset $jlibname $sid
    }
}

# jlib::ftrans::initiatorinfo --
# 
#       Returns current open transfers we have initiated.

proc jlib::ftrans::initiatorinfo {jlibname} {   
    upvar ${jlibname}::ftrans::istate istate

    set iList [list]
    foreach skey [array names istate *,sid] {
	set sid $istate($skey)
	set opts $sid
	foreach {key value} [array get istate $sid,*] {
	    set name [string map [list $sid, ""] $key]
	    lappend opts $name $value
	}
	lappend iList $opts
    }
    return $iList
}

proc jlib::ftrans::getinitiatorstate {jlibname sid} {    
    upvar ${jlibname}::ftrans::istate istate
    
    set opts [list]
    foreach {key value} [array get istate $sid,*] {
	set name [string map [list $sid, ""] $key]
	lappend opts $name $value
    }
    return $opts
}

proc jlib::ftrans::ifree {jlibname sid} {
    upvar ${jlibname}::ftrans::istate istate
    #puts "jlib::ftrans::ifree (i) sid=$sid"

    array unset istate $sid,*    
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# These are all functions to use by a target (receiver) of a stream.

# jlib::ftrans::open_handler --
# 
#       Callback when si receives this specific profile (file-transfer).
#       It is called as an iq-set/si handler.
#       
#       There are two ways this can work:
#       1) Using the global handler registered by 'registerhandler'
#       2) Or the for a specific sid, 'register_sid_handler', which is typically
#          used for sipub.

proc jlib::ftrans::open_handler {jlibname sid jid siE respCmd args} {    
    variable handler
    variable xmlns
    upvar ${jlibname}::ftrans::tstate tstate
    upvar ${jlibname}::ftrans::sid_handler sid_handler
    #puts "jlib::ftrans::open_handler (t)"
    
    if {![info exists handler]} {
	return -code break
    }
    eval {t_constructor $jlibname $sid $jid $siE} $args
    
    set tstate($sid,cmd) $respCmd
    
    set opts [list]
    foreach key {mime desc hash date} {
	if {[string length $tstate($sid,$key)]} {
	    lappend opts -$key $tstate($sid,$key)
	}
    }
    lappend opts -queryE $siE
    
    # Make a call up to application level to pick destination file.
    # This is an idle call in order not to block.
    set cb [list [namespace current]::accept $jlibname $sid]
    
    # For sipub we have a registered handler for this sid.
    if {[info exists sid_handler($sid)]} {
	set cmd $sid_handler($sid)
	unset sid_handler($sid)
    } else {
	set cmd $handler
    }
    after idle [list eval $cmd \
      [list $jlibname $jid $tstate($sid,name) $tstate($sid,size) $cb] $opts]

    return
}

proc jlib::ftrans::t_constructor {jlibname sid jid siE args} {    
    variable handler
    variable xmlns
    upvar ${jlibname}::ftrans::tstate tstate
    #puts "jlib::ftrans::t_constructor (t)"

    array set opts {
	-channel    ""
	-command    ""
	-progress   ""
    }
    array set opts $args
    set fileE [wrapper::getfirstchild $siE "file" $xmlns(ftrans)]
    if {![llength $fileE]} {
	# Exception
	return
    }
    set tstate($sid,sid)  $sid
    set tstate($sid,jid)  $jid
    set tstate($sid,mime) [wrapper::getattribute $siE "mime-type"]
    foreach {key value} [array get opts] {
	set tstate($sid,$key) $value
    }
    if {[string length $opts(-channel)]} {
	fconfigure $opts(-channel) -translation binary
    }
    
    # File element attributes 'name' and 'size' are required!
    array set attr {
	name        ""
	size        0
	date        ""
	hash        ""
    }
    array set attr [wrapper::getattrlist $fileE]
    foreach {name value} [array get attr] {
	set tstate($sid,$name) $value
    }
    set tstate($sid,desc) ""
    set descE [wrapper::getfirstchildwithtag $fileE "desc"]
    if {[llength $descE]} {
	set tstate($sid,desc) [wrapper::getcdata $descE]
    }
    set tstate($sid,bytes) 0
    set tstate($sid,data)  ""

    return
}

# jlib::ftrans::register_sid_handler --
# 
#       Used by sipub to take over from the client handler for this sid.

proc jlib::ftrans::register_sid_handler {jlibname sid cmd} {
    upvar ${jlibname}::ftrans::sid_handler sid_handler
    #puts "jlib::ftrans::register_sid_handler (t)"
    set sid_handler($sid) $cmd
}

# jlib::ftrans::accept --
# 
#       Used by profile handler to accept/reject file transfer.
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#       args:       -channel
#                   -command
#                   -progress

proc jlib::ftrans::accept {jlibname sid accepted args} {    
    upvar ${jlibname}::ftrans::tstate tstate
    
    array set opts {
	-channel    ""
	-command    ""
	-progress   ""
    }
    array set opts $args
    foreach {key value} [array get opts] {
	set tstate($sid,$key) $value
    }
    if {$accepted} {
	set type ok
	if {[string length $opts(-channel)]} {
	    fconfigure $opts(-channel) -translation binary
	    # -buffersize 4096
	}
    } else {
	set type error
    }
    set respCmd $tstate($sid,cmd)
    eval $respCmd [list $type {}]
    if {!$accepted} {
	tfree $jlibname $sid
    }
}

# jlib::ftrans::recv --
# 
#       Registered handler when receiving data. Called indirectly from stream.

proc jlib::ftrans::recv {jlibname sid data} {    
    upvar ${jlibname}::ftrans::tstate tstate
    #puts "jlib::ftrans::recv (t)"
    
    set len [string length $data]
    #puts "\t len=$len"
    incr tstate($sid,bytes) $len
    if {[string length $tstate($sid,-channel)]} {
	if {[catch {puts -nonewline $tstate($sid,-channel) $data} err]} {
	    terror $jlibname $sid $err
	    return
	}
    } else {
	#puts "\t append"
	append tstate($sid,data) $data
    }
    if {$len && [string length $tstate($sid,-progress)]} {
	uplevel #0 $tstate($sid,-progress) [list $jlibname $sid  \
	  $tstate($sid,size) $tstate($sid,bytes)]
    }   
}

# jlib::ftrans::close_handler --
# 
#       Registered handler when closing the stream.
#       This is called both for normal close and when an error occured
#       in the stream to close prematurely.

proc jlib::ftrans::close_handler {jlibname sid {errmsg ""}} {    
    upvar ${jlibname}::ftrans::tstate tstate
    #puts "jlib::ftrans::close_handler (t)"
    
    # Be sure to close the file before doing the callback, else md5 bail out!
    if {[string length $tstate($sid,-channel)]} {
	close $tstate($sid,-channel)
    }
    if {[string length $tstate($sid,-command)]} {
	if {[string length $errmsg]} {
	    uplevel #0 $tstate($sid,-command) [list $jlibname $sid error $errmsg]	    
	} else {
	    uplevel #0 $tstate($sid,-command) [list $jlibname $sid ok]
	}
    }
    tfree $jlibname $sid
}

proc jlib::ftrans::data {jlibname sid} {    
    return $tstate($sid,data)
}

# jlib::ftrans::treset --
# 
#       Resets are closes down target side file-transfer during transport.

proc jlib::ftrans::treset {jlibname sid} {
    upvar ${jlibname}::ftrans::tstate tstate
    #puts "jlib::ftrans::treset (t)"
    
    # Tell transport we are resetting.
    jlib::si::reset $jlibname $sid
    
    set tstate($sid,status) "reset"
    if {[string length $tstate($sid,-channel)]} {
	close $tstate($sid,-channel)
    }
    if {[string length $tstate($sid,-command)]} {
	uplevel #0 $tstate($sid,-command) [list $jlibname $sid reset]
    }
    tfree $jlibname $sid
}

# jlib::ftrans::targetinfo --
# 
#       Returns current target transfers.

proc jlib::ftrans::targetinfo {jlibname} {    
    upvar ${jlibname}::ftrans::tstate tstate

    set tList [list]
    foreach skey [array names tstate *,sid] {
	set sid $tstate($skey)
	set opts [list]
	foreach {key value} [array get tstate $sid,*] {
	    set name [string map [list $sid, ""] $key]
	    lappend opts $name $value
	}
	lappend tList $opts
    }
    return $tList
}

proc jlib::ftrans::gettargetstate {jlibname sid} {
    upvar ${jlibname}::ftrans::tstate tstate
    
    set opts [list]
    foreach {key value} [array get tstate $sid,*] {
	set name [string map [list $sid, ""] $key]
	lappend opts $name $value
    }
    return $opts
}

proc jlib::ftrans::terror {jlibname sid {errormsg ""}} {
    upvar ${jlibname}::ftrans::tstate tstate
    #puts "jlib::ftrans::terror (t) errormsg=$errormsg"
    
    if {[string length $tstate($sid,-channel)]} {
	close $tstate($sid,-channel)
    }
    if {[string length $tstate($sid,-command)]} {
	uplevel #0 $tstate($sid,-command) [list $jlibname $sid error $errormsg]
    }
    tfree $jlibname $sid
}

proc jlib::ftrans::tfree {jlibname sid} {
    upvar ${jlibname}::ftrans::tstate tstate
    #puts "jlib::ftrans::tfree (t) sid=$sid"

    array unset tstate $sid,*    
}

# We have to do it here since need the initProc before doing this.

namespace eval jlib::ftrans {
	
    jlib::ensamble_register filetransfer  \
      [namespace current]::init           \
      [namespace current]::cmdproc
}

#-------------------------------------------------------------------------------
