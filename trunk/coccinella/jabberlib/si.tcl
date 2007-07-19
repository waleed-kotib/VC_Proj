#  si.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for the stream initiation protocol (XEP-0095).
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: si.tcl,v 1.17 2007-07-19 06:28:17 matben Exp $
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
    set trpt(list) {}
        
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
    set trpt(names)   {}
    set trpt(streams) {}
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

proc jlib::si::send_set {jlibname jid sid mime profile profileElem cmd args} {
    
    #puts "jlib::si::send_set (i)"
    
    variable xmlns
    variable trpt
    upvar ${jlibname}::si::istate istate
    
    set istate($sid,jid)     $jid
    set istate($sid,mime)    $mime
    set istate($sid,profile) $profile
    set istate($sid,openCmd) $cmd
    set istate($sid,args)    $args
    foreach {key val} $args {
	set istate($sid,$key) $val
    }
    
    set optionElems {}
    foreach name $trpt(names) {
	set valueElem [wrapper::createtag "value" -chdata $trpt($name,ns)]
	lappend optionElems [wrapper::createtag "option"  \
	  -subtags [list $valueElem]]
    }
    set fieldElem [wrapper::createtag "field"      \
      -attrlist {var stream-method type list-single} \
      -subtags $optionElems]
    set xElem [wrapper::createtag "x"              \
      -attrlist {xmlns jabber:x:data type form}    \
      -subtags [list $fieldElem]]
    set featureElem [wrapper::createtag "feature"  \
      -attrlist [list xmlns $xmlns(neg)]           \
      -subtags [list $xElem]]
        
    set siElem [wrapper::createtag "si"  \
      -attrlist [list xmlns $xmlns(si) id $sid mime-type $mime profile $profile] \
      -subtags [list $profileElem $featureElem]]
    
    jlib::send_iq $jlibname set [list $siElem] -to $jid  \
      -command [list [namespace current]::send_set_cb $jlibname $sid]

    return
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
 
    # Verify that it is consistent.
    if {![string equal [wrapper::gettag $iqChild] "si"]} {
	
	# @@@ errors ?
	eval $istate($sid,openCmd) [list $jlibname error $sid {}]
	ifree $jlibname $sid
	return
    }

    set value {}
    set valueElem [wrapper::getchilddeep $iqChild [list  \
      [list "feature" $xmlns(neg)] [list "x" $xmlns(xdata)] "field" "value"]]
    if {[llength $valueElem]} {
	set value [wrapper::getcdata $valueElem]
    }
    
    # Find if matching transport.
    if {[lsearch $trpt(streams) $value] >= 0} {
	
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

proc jlib::si::handle_set {jlibname from iqChild args} {
    
    variable xmlns
    variable trpt
    variable prof
    upvar ${jlibname}::si::tstate tstate
    
    #puts "jlib::si::handle_set (t)"
    
    array set iqattr $args
    
    # Note: there are two different 'id'!
    # These are the attributes of the si element.
    array set attr {
	id          ""
	mime-type   ""
	profile     ""
    }
    array set attr [wrapper::getattrlist $iqChild]
    set sid     $attr(id)
    set profile $attr(profile)
    
    # This is a profile we don't understand.
    if {![info exists prof($profile,open)]} {
	set errElem [wrapper::createtag "bad-profile"  \
	  -attrlist [list xmlns $xmlns(si)]]
	send_error $jlibname $from $iqattr(-id) $sid 400 cancel bad-request  \
	  $errElem
	return 1
    }

    # Extract all streams and pick one with highest priority.
    set values {}
    set fieldElem [wrapper::getchilddeep $iqChild [list  \
      [list "feature" $xmlns(neg)] [list "x" $xmlns(xdata)] "field"]]
    if {[llength $fieldElem]} {
	set optionElems [wrapper::getchildswithtag $fieldElem "option"]
	foreach c $optionElems {
	    lappend values [wrapper::getcdata  \
	      [lindex [wrapper::getchildren $c] 0]]
	}
    }
    
    # Pick first matching since priority ordered.
    set stream {}
    foreach name $values {
	if {[lsearch $trpt(streams) $name] >= 0} {
	    set stream $name
	    break
	}
    }
    
    # No valid stream :-(
    if {![string length $stream]} {
	set errElem [wrapper::createtag "no-valid-streams"  \
	  -attrlist [list xmlns $xmlns(si)]]
	send_error $jlibname $from $iqattr(-id) $sid 400 cancel bad-request  \
	  $errElem
	return 1
    }
        
    # Get profile element. Can have any tag but xmlns must be $profile.
    set profileElem [wrapper::getfirstchildwithxmlns $iqChild $profile]
    if {![llength $profileElem]} {
	send_error $jlibname $from $iqattr(-id) $sid 400 cancel bad-request  \
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
	eval $prof($profile,open) [list $jlibname $sid $jid $iqChild $respCmd]
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

# jlib::si::profile_response --
# 
#       Invoked by the registered profile callback.
#       
# Arguments:
#       type        'result' or 'error' if user accepts the stream or not.
#       profileElem any extra profile element; can be empty.

proc jlib::si::profile_response {jlibname sid type profileElem args} {
    
    #puts "jlib::si::profile_response (t) type=$type"
    
    variable xmlns
    upvar ${jlibname}::si::tstate tstate
    
    set jid $tstate($sid,-from)
    set id  $tstate($sid,-id)

    # Rejected stream initiation.
    if {[string equal $type "error"]} {
	# @@@ We could have a text element here...
	send_error $jlibname $jid $id $sid 403 cancel forbidden
	return
    }

    # Accepted stream initiation.

    # Construct si element from selected profile.
    set valueElem [wrapper::createtag "value"  \
      -chdata $tstate($sid,stream)]
    set fieldElem [wrapper::createtag "field"  \
      -attrlist {var stream-method}            \
      -subtags [list $valueElem]]
    set xElem [wrapper::createtag "x"          \
      -attrlist [list xmlns $xmlns(xdata) type submit]  \
      -subtags [list $fieldElem]]
    set featureElem [wrapper::createtag "feature"  \
      -attrlist [list xmlns $xmlns(neg)]           \
      -subtags [list $xElem]]

    # Include 'profileElem' if nonempty.
    set siChilds [list $featureElem]
    if {[llength $profileElem]} {
	lappend siChilds $profileElem
    }
    set siElem [wrapper::createtag "si"  \
      -attrlist [list xmlns $xmlns(si)]  \
      -subtags $siChilds]
    
    jlib::send_iq $jlibname result [list $siElem] -to $jid -id $id

    return
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
