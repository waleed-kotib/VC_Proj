#  si.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for the stream initiation protocol (JEP-0095).
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: si.tcl,v 1.3 2005-09-02 17:05:50 matben Exp $
# 
############################# USAGE ############################################
#
#   NAME
#      si - convenience command library for stream initiation.
#      
#   SYNOPSIS
#      jlib::si::init jlibName
#
#   OPTIONS
#
#	
#   INSTANCE COMMANDS
#      jlibName si send_set ...
#      jlibName si send_data ...
#      jlibName si send_close ...
#      jlibName si getstate sid
#      
############################# CHANGES ##########################################
#
#       0.1         first version

package require jlib			   
			  
package provide jlib::si 0.1

#--- generic si ----------------------------------------------------------------

namespace eval jlib::si {

    variable xmlns
    set xmlns(si)      "http://jabber.org/protocol/si"
    set xmlns(neg)     "http://jabber.org/protocol/feature-neg"
    set xmlns(xdata)   "jabber:x:data"
    set xmlns(streams) "urn:ietf:params:xml:ns:xmpp-streams"
    set xmlns(stanzas) "urn:ietf:params:xml:ns:xmpp-stanzas"
    
    # Storage for registered transports.
    variable trpt
    set trpt(list) {}
    
    jlib::ensamble_register si   \
      [namespace current]::init  \
      [namespace current]::cmdproc
}

# jlib::si::registertransport --
# 
#       Register transports. This is used by the streams that do the actual job.
#       Typically 'name' and 'ns' are xml namespaces and identical.

proc jlib::si::registertransport {name ns priority openProc sendProc closeProc} {

    variable trpt
    
    puts "jlib::si::registertransport"
    
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
#       with the specified profile.

proc jlib::si::registerprofile {profile handler} {
    
    variable prof
    puts "jlib::si::registerprofile"
    
    set prof($profile) $handler
}

# jlib::si::init --
# 
#       Instance init procedure.
  
proc jlib::si::init {jlibname args} {

    variable xmlns
    
    Debug 4 "jlib::si::init"

    # Keep different state arrays for initiator (i) and receiver (r).
    namespace eval ${jlibname}::si {
	variable istate
	variable rstate
    } 
    $jlibname iq_register set $xmlns(si) [namespace current]::handle_set
}

proc jlib::si::cmdproc {jlibname cmd args} {
    
    Debug 4 "jlib::si::cmdproc jlibname=$jlibname, cmd='$cmd', args='$args'"

    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# These are all functions to use by a sender.

# jlib::si::send_set --
# 
#       Makes a stream initiation.
#       It will eventually, if negotiation went ok, invoke the stream
#       'open' method. 
#       The 'args' ar transparently delivered to the streams 'open' method.

proc jlib::si::send_set {jlibname jid sid mime profile profileElem cmd args} {
    
    puts "jlib::si::send_set"
    
    variable xmlns
    variable trpt
    upvar ${jlibname}::si::istate istate
    
    set istate($sid,jid)     $jid
    set istate($sid,mime)    $mime
    set istate($sid,profile) $profile
    set istate($sid,cmd)     $cmd
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
    
    puts "jlib::si::send_set_cb"
    
    variable xmlns
    variable trpt
    upvar ${jlibname}::si::istate istate

    if {[string equal $type "error"]} {
	uplevel #0 $istate($sid,cmd) [list $jlibname $type $sid $iqChild]
	ifree $jlibname $sid
	return
    }
 
    # Verify that it is consistent.
    if {![string equal [wrapper::gettag $iqChild] "si"]} {
	
	# @@@ errors ?
	uplevel #0 $istate($sid,cmd) [list $jlibname error $sid {}]
	ifree $jlibname $sid
	return
    }

    set value {}
    set valueElem [wrapper::getdhilddeep $iqChild [list  \
      [list "feature" $xmlns(neg)] [list "x" $xmlns(xdata)] "field" "value"]]
    if {[llength $valueElem]} {
	set value [wrapper::getcdata $valueElem]
    }
    
    # Find if matching transport.
    if {[lsearch $trpt(streams) $value] >= 0} {
	
	# Open transport. 
	# We provide a callback for the transport when open is finished.
	set istate($sid,name) $value
	set jid $istate($sid,jid)
	set cmd [namespace current]::transport_open_response
	uplevel #0 $trpt($value,open) [list $jlibname $jid $sid $cmd]  \
	  $istate($sid,args)
    } else {
	uplevel #0 $istate($sid,cmd) [list $jlibname error $sid {}]
	ifree $jlibname $sid
    }
}

# jlib::si::transport_open_response --
# 
#       This is a transports way of reporting result from it's 'open' method.
#       It is also the end of the sequence of callbacks generated by 
#       'jlib::si::send_set'.

proc jlib::si::transport_open_response {jlibname sid type iqChild} {
    
    upvar ${jlibname}::si::istate istate
    
    puts "jlib::si::transport_open_response"
    
    uplevel #0 $istate(cmd) [list $jlibname $type $sid $iqChild]
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

#--- wrappers for send & close operations ---

# jlib::si::send_data, send_close --
# 
#       Opaque calls to send a chunk or to close a stream.

proc jlib::si::send_data {jlibname sid data} {
    
    variable trpt
    upvar ${jlibname}::si::istate istate
    
    set stream $istate($sid,name)
    uplevel #0 $trpt($stream,send) [list $jlibname $sid $data]    
}

proc jlib::si::send_close {jlibname sid} {

    variable trpt
    upvar ${jlibname}::si::istate istate
    
    set stream $istate($sid,name)
    uplevel #0 $trpt($stream,close) [list $jlibname $sid]    
}

proc jlib::si::ifree {jlibname sid} {
    
    upvar ${jlibname}::si::istate istate

    array unset istate $sid,*
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# These are all functions to use by a receiver of a stream.

# jlib::si::handle_set --
# 
#       Parse incoming si set element. Invokes registered callback for the
#       profile in question. It is the responsibility of this callback to
#       deliver the result via the command in its argument.

proc jlib::si::handle_set {jlibname from iqChild args} {
    
    variable xmlns
    variable trpt
    variable prof
    upvar ${jlibname}::si::rstate rstate
    
    puts "jlib::si::handle_set"
    puts "\t iqChild=$iqChild"
    
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
    if {![info exists prof($profile)]} {
	set errElem [wrapper::createtag "bad-profile"  \
	  -attrlist [list xmlns $xmlns(si)]]
	send_error $jlibname $from $iqattr(-id) $sid 400 cancel bad-request  \
	  $errElem
	return 1
    }

    # Extract all streams and pick one with highest priority.
    set values {}
    set fieldElem [wrapper::getdhilddeep $iqChild [list  \
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

    set rstate($sid,profile)   $profile
    set rstate($sid,stream)    $stream
    set rstate($sid,mime-type) $attr(mime-type)
    foreach {key val} $args {
	set rstate($sid,$key)  $val
    }
    
    # Invoke registered handler.
    set respCmd [list [namespace current]::profile_response $jlibname $sid]
    uplevel #0 $prof($profile) [list $jlibname $sid $respCmd]

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
    
    puts "jlib::si::profile_response"
    
    variable xmlns
    upvar ${jlibname}::si::rstate rstate
    
    set jid $rstate($sid,-from)
    set id  $rstate($sid,-id)

    # Rejected stream initiation.
    if {[string equal $type "error"]} {
	# @@@ We could have a text element here...
	send_error $jlibname $jid $id $sid 403 cancel forbidden
	return
    }

    # Accepted stream initiation.

    # Construct si element from selected profile.
    set valueElem [wrapper::createtag "value"  \
      -chdata $rstate($sid,stream)]
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
      -subtags $siChilds
    
    jlib::send_iq $jlibname result [list $siElem] -to $jid -id $id

    return
}

# jlib::si::havesi --
# 
#       The streams may need to know if we have got a si request (set).
#       @@@ Perhaps we should have timeout for incoming si requests that
#           cancels it all.

proc jlib::si::havesi {jlibname sid} {
    
    upvar ${jlibname}::si::rstate rstate

    if {[info exists rstate($sid,profile)]} {
	return 1
    } else {
	return 0
    }
}

# jlib::si::stream_closed --
# 
#       This should be the final stage for a succesful transfer.

proc jlib::si::stream_closed {jlibname sid} {
    
    upvar ${jlibname}::si::rstate rstate
    
    # @@@ callback!!??

    rfree $jlibname $sid
}

# jlib::si::send_error --
# 
#       Reply with iq error element.

proc jlib::si::send_error {jlibname jid id sid errcode errtype stanza {extraElem {}}} {
    
    puts "jlib::si::send_error"
    variable xmlns

    set stanzaElem [wrapper::createtag $stanza  \
      -attrlist [list xmlns $xmlns(stanzas)]]
    set errChilds [list $stanzaElem]
    if {[llength $extraElem]} {
	lappend errChilds $extraElem
    }
    set errElem [wrapper::createtag "error"         \
      -attrlist [list code $errcode type $errtype]  \
      -subtags $errChilds]
    set iqElem [wrapper::createtag "iq"  \
      -attrlist [list type error to $jid id $id]  \
      -subtags [list $errElem]]

    jlib::send $jlibname $iqElem

    rfree $jlibname $sid
}

proc jlib::si::rfree {jlibname sid} {
    
    upvar ${jlibname}::si::rstate rstate

    array unset rstate $sid,*
}

