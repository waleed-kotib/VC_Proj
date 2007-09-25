#  si.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for the stream initiation protocol (XEP-0095).
#      
#  Copyright (c) 2005-2007  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: si.tcl,v 1.22 2007-09-25 12:46:27 matben Exp $
# 
#      There are several layers involved when sending/receiving a file for 
#      instance. Each layer reports only to the nearest layer above using
#      callbacks. From top to bottom:
#      
#      1) application
#      2) profiles, file-transfer etc.
#      3) stream initiation (si)
#      4) the streams, bytestreams (socks5), ibb, etc.
#      5) jabberlib
#      
#      Each layer divides into two parts, the initiator and target.
#      Keep different state arrays for initiator (i) and target (t).
#      The si layer acts as a mediator between the profiles and the streams.
#      Each profile registers with si, and each stream registers with si.
#      
#            profiles ...
#                 \   |   /
#                  \  |  /
#                   \ | /
#                     si (stream initiation)
#                   / | \
#                  /  |  \
#                 /   |   \
#             streams ...
#      
#       INITIATOR: each transport (stream) registers for open, send & close 
#           using 'registertransport'. The profiles call these indirectly
#           through si. The profile gets feedback from streams using direct
#           callbacks.
#           
#       TARGET: each profile (file-transfer) registers for open, read & close
#           using 'registerprofile'. The transports register for element
#           handlers for their specific protocol. When activated, the transport
#           calls si which in turn calls the profile using its registered 
#           handlers.
# 
#                 Initiator:                Target:
# 
#       profiles   |    :    :               /|\   :    :
#                  |    :    :                |    :    :
#                 \|/   :    :                |    :    :
#       si        =============  <-------->  =============
#                  :    |    :                :   /|\   :
#                  :    |    :                :    |    :
#       streams    :   \|/   :                :    |    :
#                       o .......................> o
# 
# 
############################# USAGE ############################################
#
#   NAME
#      si - convenience command library for stream initiation.
#      
#   SYNOPSIS
#      
#
#   OPTIONS
#
#	
#   INSTANCE COMMANDS
#      jlibName si registertransport ...
#      jlibName si registerprofile ...
#      jlibName si send_set ...
#      jlibName si send_data ...
#      jlibName si send_close ...
#      jlibName si getstate sid
#      
############################# CHANGES ##########################################
#
#       0.1         first version

package require jlib			   
package require jlib::disco
			  
package provide jlib::si 0.1

#--- generic si ----------------------------------------------------------------

namespace eval jlib::si {

    variable xmlns
    set xmlns(si)      "http://jabber.org/protocol/si"
    set xmlns(neg)     "http://jabber.org/protocol/feature-neg"
    set xmlns(xdata)   "jabber:x:data"
    set xmlns(streams) "urn:ietf:params:xml:ns:xmpp-streams"
    
    # Storage for registered transports.
    variable trpt
    set trpt(list) [list]
        
    jlib::disco::registerfeature $xmlns(si)

    # Note: jlib::ensamble_register is last in this file!
}

# jlib::si::registertransport --
# 
#       Register transports on the initiator (sender) side. 
#       This is used by the streams that do the actual job.
#       Typically 'name' and 'ns' are xml namespaces and identical.

proc jlib::si::registertransport {name ns priority openProc sendProc closeProc} {

    variable trpt    
    #puts "jlib::si::registertransport (i)"
    
    lappend trpt(list) [list $name $priority]
    set trpt(list) [lsort -unique -index 1 $trpt(list)]
    set trpt($name,ns)    $ns
    set trpt($name,open)  $openProc
    set trpt($name,send)  $sendProc
    set trpt($name,close) $closeProc

    # Keep these in sync.
    set trpt(names)   [list]
    set trpt(streams) [list]
    foreach spec $trpt(list) {
	set nm [lindex $spec 0]
	lappend trpt(names)   $nm
	lappend trpt(streams) $trpt($nm,ns)
    }
}

# jlib::si::registerprofile --
# 
#       This is used by profiles to register handler when receiving a si set
#       with the specified profile. It contains handlers for 'set', 'read',
#       and 'close' streams. These belong to the target side.

proc jlib::si::registerprofile {profile openProc readProc closeProc} {
    
    variable prof
    #puts "jlib::si::registerprofile (t)"
    
    set prof($profile,open)  $openProc
    set prof($profile,read)  $readProc
    set prof($profile,close) $closeProc
}

# jlib::si::init --
# 
#       Instance init procedure.
  
proc jlib::si::init {jlibname args} {

    variable xmlns
    #puts "jlib::si::init"

    # Keep different state arrays for initiator (i) and receiver (r).
    namespace eval ${jlibname}::si {
	variable istate
	variable tstate
    } 
    $jlibname iq_register set $xmlns(si) [namespace current]::handle_set
    $jlibname iq_register get $xmlns(si) [namespace current]::handle_get
}

proc jlib::si::cmdproc {jlibname cmd args} {
    
    #puts "jlib::si::cmdproc jlibname=$jlibname, cmd='$cmd', args='$args'"

    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# These are all functions to use by a initiator (sender).

# jlib::si::send_set --
# 
#       Makes a stream initiation (open).
#       It will eventually, if negotiation went ok, invoke the stream
#       'open' method. 
#       The 'args' ar transparently delivered to the streams 'open' method.

proc jlib::si::send_set {jlibname jid sid mime profile profileE cmd args} {
    
    #puts "jlib::si::send_set (i)"
    
    set siE [i_constructor $jlibname $sid $jid $mime $profile $profileE $cmd]
    jlib::send_iq $jlibname set [list $siE] -to $jid  \
      -command [list [namespace current]::send_set_cb $jlibname $sid]
    return
}

# jlib::si::i_constructor --
# 
#       Makes a new si instance. Does everything except deleivering it.
#       Returns the si element.

proc jlib::si::i_constructor {jlibname sid jid mime profile profileE cmd args} {
    upvar ${jlibname}::si::istate istate
    
    set istate($sid,jid)      $jid
    set istate($sid,mime)     $mime
    set istate($sid,profile)  $profile
    set istate($sid,openCmd)  $cmd
    set istate($sid,args)     $args
    foreach {key val} $args {
	set istate($sid,$key) $val
    }
    return [element $sid $mime $profile $profileE]
}

# jlib::si::element --
# 
#       Just create the si element. Nothing cached.

proc jlib::si::element {sid mime profile profileE} {
    variable xmlns
    variable trpt
    
    set optionEs [list]
    foreach name $trpt(names) {
	set valueE [wrapper::createtag "value" -chdata $trpt($name,ns)]
	lappend optionEs [wrapper::createtag "option" -subtags [list $valueE]]
    }
    set fieldE [wrapper::createtag "field"      \
      -attrlist {var stream-method type list-single} -subtags $optionEs]
    set xE [wrapper::createtag "x"              \
      -attrlist {xmlns jabber:x:data type form} -subtags [list $fieldE]]
    set featureE [wrapper::createtag "feature"  \
      -attrlist [list xmlns $xmlns(neg)] -subtags [list $xE]]
    set siE [wrapper::createtag "si"  \
      -attrlist [list xmlns $xmlns(si) id $sid mime-type $mime profile $profile] \
      -subtags [list $profileE $featureE]]

    return $siE
}

# jlib::si::send_set_cb --
# 
#       Our internal callback handler when offered stream initiation.

proc jlib::si::send_set_cb {jlibname sid type iqChild args} {
    
    #puts "jlib::si::send_set_cb (i)"
    
    variable xmlns
    variable trpt
    upvar ${jlibname}::si::istate istate

    if {[string equal $type "error"]} {
	eval $istate($sid,openCmd) [list $jlibname $type $sid $iqChild]
	ifree $jlibname $sid
	return
    }
    eval {i_handler $jlibname $sid $iqChild} $args
}

# jlib::si::handle_get --
# 
#       This handles incoming iq-get/si elements. The 'sid' must already exist
#       since this belongs to the initiator side! We obtain this call as a
#       response to an si element sent. It should behave as 'send_set_cb'. 

proc jlib::si::handle_get {jlibname from iqChild args} {

    upvar ${jlibname}::si::istate istate    
    #puts "jlib::si::handle_get (i)"
    
    array set argsA $args
    array set attr [wrapper::getattrlist $iqChild]
    if {![info exists attr(id)]} {
	return 0
    }
    set sid $attr(id)    
    if {![info exists argsA(-id)]} {
	return 0
    }
    set id $argsA(-id)
    
    # Verify that we have actually initiated this stream.
    if {![info exists istate($sid,jid)]} {
	jlib::send_iq_error $jlibname $from $id 403 cancel forbidden
	return 1
    }
    eval {i_handler $jlibname $sid $iqChild} $args
    
    # We must respond ourselves.
    $jlibname send_iq result {} -to $from -id $id
    
    return 1
}

# jlib::si::i_handler --
# 
#       Handles both responses to an iq-set call and an incoming iq-get.

proc jlib::si::i_handler {jlibname sid iqChild args} {
    
    variable xmlns
    variable trpt
    upvar ${jlibname}::si::istate istate
    #puts "jlib::si::i_handler (i)"

    # Verify that it is consistent.
    if {![string equal [wrapper::gettag $iqChild] "si"]} {
	
	# @@@ errors ?
	eval $istate($sid,openCmd) [list $jlibname error $sid {}]
	ifree $jlibname $sid
	return
    }

    set value ""
    set valueE [wrapper::getchilddeep $iqChild [list  \
      [list "feature" $xmlns(neg)] [list "x" $xmlns(xdata)] "field" "value"]]
    if {[llength $valueE]} {
	set value [wrapper::getcdata $valueE]
    }
    
    # Find if matching transport.
    if {[lsearch -exact $trpt(streams) $value] >= 0} {
	
	# Open transport. 
	# We provide a callback for the transport when open is finished.
	set istate($sid,stream) $value
	set jid $istate($sid,jid)
	set cmd [namespace current]::transport_open_cb
	eval $trpt($value,open) [list $jlibname $jid $sid]  \
	  $istate($sid,args)
    } else {
	eval $istate($sid,openCmd) [list $jlibname error $sid {}]
	ifree $jlibname $sid
    }
}

# jlib::si::transport_open_cb --
# 
#       This is a transports way of reporting result from it's 'open' method.

proc jlib::si::transport_open_cb {jlibname sid type iqChild} {
    
    upvar ${jlibname}::si::istate istate    
    #puts "jlib::si::transport_open_cb (i)"
    	
    # Just report this to the relevant profile.
    eval $istate($sid,openCmd) [list $jlibname $type $sid $iqChild]
}

# jlib::si::send_close --
# 
#       Used by profile to close down the stream.

proc jlib::si::send_close {jlibname sid cmd} {

    variable trpt
    upvar ${jlibname}::si::istate istate
    #puts "jlib::si::send_close (i)"
    
    set istate($sid,closeCmd) $cmd
    set stream $istate($sid,stream)
    eval $trpt($stream,close) [list $jlibname $sid]    
}

proc jlib::si::transport_close_cb {jlibname sid type iqChild} {
    
    upvar ${jlibname}::si::istate istate
    #puts "jlib::si::transport_close_cb (i)"
    
    # Just report this to the relevant profile.
    eval $istate($sid,closeCmd) [list $jlibname $type $sid $iqChild]
    
    ifree $jlibname $sid
}

# jlib::si::getstate --
# 
#       Just an access function to the internal state variables.

proc jlib::si::getstate {jlibname sid} {
    
    upvar ${jlibname}::si::istate istate
    
    set arr {}
    foreach {key value} [array get istate $sid,*] {
	set name [string map [list "$sid," ""] $key]
	lappend arr $name $value
    }
    return $arr
}

# jlib::si::send_data --
# 
#       Opaque calls to send a chunk.

proc jlib::si::send_data {jlibname sid data cmd} {
    
    variable trpt
    upvar ${jlibname}::si::istate istate
    #puts "jlib::si::send_data (i)"
    
    set istate($sid,sendCmd) $cmd
    set stream $istate($sid,stream)
    eval $trpt($stream,send) [list $jlibname $sid $data]    
}

# jlib::si::transport_send_data_error_cb --
# 
#       This is a transports way of reporting errors when sending data.
#       ONLY ERRORS HERE!

proc jlib::si::transport_send_data_error_cb {jlibname sid} {
    
    upvar ${jlibname}::si::istate istate
    #puts "jlib::si::transport_send_data_error_cb (i)"
        
    eval $istate($sid,sendCmd) [list $jlibname $sid]
}

proc jlib::si::ifree {jlibname sid} {
    
    upvar ${jlibname}::si::istate istate
    #puts "jlib::si::ifree (i) sid=$sid"

    array unset istate $sid,*
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# These are all functions to use by a target (receiver) of a stream.

# jlib::si::handle_set --
# 
#       Parse incoming si set element. Invokes registered callback for the
#       profile in question. It is the responsibility of this callback to
#       deliver the result via the command in its argument.

proc jlib::si::handle_set {jlibname from siE args} {
    
    variable xmlns
    variable trpt
    variable prof
    upvar ${jlibname}::si::tstate tstate
    
    #puts "jlib::si::handle_set (t)"
    
    array set iqattr $args
    if {![info exists iqattr(-id)]} {
	return 0
    }
    set id $iqattr(-id)
    
    # Note: there are two different 'id'!
    # These are the attributes of the si element.
    array set attr {
	id          ""
	mime-type   ""
	profile     ""
    }
    array set attr [wrapper::getattrlist $siE]
    set sid     $attr(id)
    set profile $attr(profile)
    
    # This is a profile we don't understand.
    if {![info exists prof($profile,open)]} {
	set errE [wrapper::createtag "bad-profile"  \
	  -attrlist [list xmlns $xmlns(si)]]
	send_error $jlibname $from $id $sid 400 cancel "bad-request" $errE
	return 1
    }

    # Extract all streams and pick one with highest priority.
    set stream [pick_stream $siE]
    
    # No valid stream :-(
    if {![string length $stream]} {
	set errE [wrapper::createtag "no-valid-streams"  \
	  -attrlist [list xmlns $xmlns(si)]]
	send_error $jlibname $from $id $sid 400 cancel "bad-request" $errE
	return 1
    }
        
    # Get profile element. Can have any tag but xmlns must be $profile.
    set profileE [wrapper::getfirstchildwithxmlns $siE $profile]
    if {![llength $profileE]} {
	send_error $jlibname $from $id $sid 400 cancel "bad-request"
	return 1
    }

    set tstate($sid,profile)   $profile
    set tstate($sid,stream)    $stream
    set tstate($sid,mime-type) $attr(mime-type)
    foreach {key val} $args {
	set tstate($sid,$key)  $val
    }
    set jid $tstate($sid,-from)
    
    # Invoke registered handler for this profile.
    set respCmd [list [namespace current]::profile_response $jlibname $sid]
    set rc [catch {
	eval $prof($profile,open) [list $jlibname $sid $jid $siE $respCmd]
    }]
    if {$rc == 1} {
	# error
	return 0
    } elseif {$rc == 3 || $rc == 4} {
	# break or continue
	return 0
    }     
    return 1
}

# jlib::si::t_handler --
# 
#       This shall only be used when we get an embedded si-element which we
#       respond by an iq-get/si call.
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#       args:       -channel
#                   -command
#                   -progress
#
# Results:
#       empty if OK else an error token.

proc jlib::si::t_handler {jlibname from siE cmd args} {
    
    variable xmlns
    variable trpt
    variable prof
    upvar ${jlibname}::si::tstate tstate
    
    #puts "jlib::si::t_handler (t)"
    
    # These are the attributes of the si element.
    array set attr {
	id          ""
	mime-type   ""
	profile     ""
    }
    array set attr [wrapper::getattrlist $siE]
    set sid     $attr(id)
    set profile $attr(profile)
    
    if {![info exists prof($profile,open)]} {
	return "bad-profile"
    }
    set stream [pick_stream $siE]
    if {![string length $stream]} {
	return "no-valid-streams"
    }
    set profileE [wrapper::getfirstchildwithxmlns $siE $profile]
    if {![llength $profileE]} {
	return "bad-request"
    }
    set tstate($sid,profile)   $profile
    set tstate($sid,stream)    $stream
    set tstate($sid,mime-type) $attr(mime-type)
    set tstate($sid,-from)     $from
    foreach {key val} $args {
	set tstate($sid,$key)  $val
    }
    set jid $from
    
    # We invoke the target handler without requesting any response.
    eval $prof($profile,open) [list $jlibname $sid $jid $siE {}] $args

    # Instead we must make an iq-get/si call which is otherwise identical to a
    # iq-result/si.
    set siE [t_element $jlibname $sid $profileE]
    jlib::send_iq $jlibname get [list $siE] -to $jid -command $cmd
    
    return
}

# jlib::si::pick_stream --
# 
#       Extracts the highest priority stream from an si element. Empty if error.

proc jlib::si::pick_stream {siE} {
    
    variable xmlns
    variable trpt
    
    # Extract all streams and pick one with highest priority.
    set values [list]
    set fieldE [wrapper::getchilddeep $siE [list  \
      [list "feature" $xmlns(neg)] [list "x" $xmlns(xdata)] "field"]]
    if {[llength $fieldE]} {
	set optionEs [wrapper::getchildswithtag $fieldE "option"]
	foreach c $optionEs {
	    set firstE [lindex [wrapper::getchildren $c] 0]
	    lappend values [wrapper::getcdata $firstE]
	}
    }
    
    # Pick first matching since priority ordered.
    set stream ""
    foreach name $values {
	if {[lsearch -exact $trpt(streams) $name] >= 0} {
	    set stream $name
	    break
	}
    }
    return $stream
}

# jlib::si::profile_response --
# 
#       Invoked by the registered profile callback.
#       
# Arguments:
#       type        'result' or 'error' if user accepts the stream or not.
#       profileE    any extra profile element; can be empty.

proc jlib::si::profile_response {jlibname sid type profileE args} {
    
    #puts "jlib::si::profile_response (t) type=$type"
    
    variable xmlns
    upvar ${jlibname}::si::tstate tstate
    
    set jid $tstate($sid,-from)
    set id  $tstate($sid,-id)

    # Rejected stream initiation.
    if {[string equal $type "error"]} {
	# @@@ We could have a text element here...
	send_error $jlibname $jid $id $sid 403 cancel forbidden
    } else {

	# Accepted stream initiation.
	# Construct si element from selected profile.
	set siE [t_element $jlibname $sid $profileE]
	jlib::send_iq $jlibname result [list $siE] -to $jid -id $id
    }
    return
}

# jlib::si::t_element --
# 
#       Construct si element from selected profile.

proc jlib::si::t_element {jlibname sid profileE} {
    
    variable xmlns
    upvar ${jlibname}::si::tstate tstate

    set valueE [wrapper::createtag "value" -chdata $tstate($sid,stream)]
    set fieldE [wrapper::createtag "field" \
      -attrlist {var stream-method} -subtags [list $valueE]]
    set xE [wrapper::createtag "x"          \
      -attrlist [list xmlns $xmlns(xdata) type submit] -subtags [list $fieldE]]
    set featureE [wrapper::createtag "feature"  \
      -attrlist [list xmlns $xmlns(neg)] -subtags [list $xE]]

    # Include 'profileE' if nonempty.
    set siChilds [list $featureE]
    if {[llength $profileE]} {
	lappend siChilds $profileE
    }
    set siE [wrapper::createtag "si"  \
      -attrlist [list xmlns $xmlns(si) id $sid] -subtags $siChilds]
    return $siE
}

# jlib::si::reset --
# 
#       Used by profile when doing reset.

proc jlib::si::reset {jlibname sid} {
    
    upvar ${jlibname}::si::tstate tstate
    #puts "jlib::si::reset (t)"
    
    # @@@ Tell transport we are resetting???
    # Brute force.
    
    tfree $jlibname $sid
}

# jlib::si::havesi --
# 
#       The streams may need to know if we have got a si request (set).
#       @@@ Perhaps we should have timeout for incoming si requests that
#           cancels it all.

proc jlib::si::havesi {jlibname sid} {
    
    upvar ${jlibname}::si::tstate tstate
    upvar ${jlibname}::si::istate istate

    if {[info exists tstate($sid,profile)] || [info exists istate($sid,profile)]} {
	return 1
    } else {
	return 0
    }
}

# jlib::si::stream_recv --
# 
#       Used by transports (streams) to deliver the actual data.

proc jlib::si::stream_recv {jlibname sid data} {
    
    variable prof
    upvar ${jlibname}::si::tstate tstate
    #puts "jlib::si::stream_recv (t)"
    
    # Each stream should check that we exist before calling us!
    set profile $tstate($sid,profile)
    eval $prof($profile,read) [list $jlibname $sid $data]    
}

# jlib::si::stream_closed --
# 
#       This should be the final stage for a succesful transfer.
#       Called by transports (streams).

proc jlib::si::stream_closed {jlibname sid} {
    
    variable prof
    upvar ${jlibname}::si::tstate tstate
    #puts "jlib::si::stream_closed (t)"
    
    # Each stream should check that we exist before calling us!
    set profile $tstate($sid,profile)
    eval $prof($profile,close) [list $jlibname $sid]
    tfree $jlibname $sid
}

# jlib::si::stream_error --
# 
#       Called by transports to report an error.

proc jlib::si::stream_error {jlibname sid errmsg} {
    
    variable prof
    upvar ${jlibname}::si::tstate tstate
    #puts "jlib::si::stream_error (t)"
    
    set profile $tstate($sid,profile)
    eval $prof($profile,close) [list $jlibname $sid $errmsg]
    tfree $jlibname $sid
}

# jlib::si::send_error --
# 
#       Reply with iq error element.

proc jlib::si::send_error {jlibname jid id sid errcode errtype stanza {extraElem {}}} {
    
    #puts "jlib::si::send_error"

    jlib::send_iq_error $jlibname $jid $id $errcode $errtype $stanza $extraElem
    tfree $jlibname $sid
}

proc jlib::si::tfree {jlibname sid} {
    
    upvar ${jlibname}::si::tstate tstate
    #puts "jlib::si::tfree (t)"

    array unset tstate $sid,*
}

# We have to do it here since need the initProc before doing this.

namespace eval jlib::si {
    
    jlib::ensamble_register si   \
      [namespace current]::init  \
      [namespace current]::cmdproc
}

#-------------------------------------------------------------------------------
