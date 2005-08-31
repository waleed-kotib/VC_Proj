#  si.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for the stream initiation protocol (JEP-0095).
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: si.tcl,v 1.1 2005-08-31 09:51:59 matben Exp $
# 
############################# USAGE ############################################
#
#   NAME
#      ibb - convenience command library for the si part of XMPP.
#      
#   SYNOPSIS
#      jlib::si::init jlibName
#
#   OPTIONS
#
#	
#   INSTANCE COMMANDS
#      jlibName si send_set ...
#      
############################# CHANGES ##########################################
#
#       0.1         first version
#       
#       NEVER TESTED!!!!!!!

package require jlib			   
			  
package provide jlib::si 0.1

#--- generic si ----------------------------------------------------------------

namespace eval jlib::si {

    variable xmlns
    set xmlns(si)    "http://jabber.org/protocol/si"
    set xmlns(neg)   "http://jabber.org/protocol/feature-neg"
    set xmlns(xdata) "jabber:x:data"
    
    # Storage for registered transports.
    variable trpt
    set trpt(names) {}
    
    jlib::ensamble_register si   \
      [namespace current]::init  \
      [namespace current]::cmdproc
}

# jlib::si::registertransport --
# 
#       Register transports.

proc jlib::si::registertransport {name ns priority openProc sendProc closeProc} {

    variable trpt
    
    puts "jlib::si::registertransport"
    
    lappend trpt(names) [list $name $priority]
    set trpt(names) [lsort -unique -index 1 $trpt(names)]
    set trpt($name,ns)    $ns
    set trpt($name,open)  $openProc
    set trpt($name,send)  $sendProc
    set trpt($name,close) $closeProc
}

proc jlib::ibb::registerprofile {profile handler} {
    
    variable prof
    puts "jlib::ibb::registerprofile"
    
    set prof($profile) $handler
}

# jlib::si::init --
# 
#       Instance init procedure.
  
proc jlib::si::init {jlibname args} {

    variable xmlns
    
    Debug 4 "jlib::si::init"

    namespace eval ${jlibname}::si {
	variable state
    } 
    $jlibname iq_register set $xmlns(si) [namespace current]::handle_set
}

proc jlib::si::cmdproc {jlibname cmd args} {
    
    Debug 4 "jlib::si::cmdproc jlibname=$jlibname, cmd='$cmd', args='$args'"

    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# jlib::si::send_set --
# 
#       Makes a stream initiation.
#       It will eventually, if negotiation went ok, invoke the stream
#       'open' method.

proc jlib::si::send_set {jlibname jid sid mime profile profileElem cmd} {
    
    puts "jlib::si::send_set"
    
    variable xmlns
    variable trpt
    upvar ${jlibname}::si::state state
    
    set state($sid,jid)     $jid
    set state($sid,mime)    $mime
    set state($sid,profile) $profile
    set state($sid,cmd)     $cmd
    
    set optionElems {}
    foreach spec $trpt(names) {
	set name [lindex $spec 0]
	set valueElem [wrapper::createtag "value" -chdata $trpt($name,ns)]
	lappend optionElems [wrapper::createtag "option"  \
	  -subtags [list $valueElem]
    }
    set fieldElem [wrapper::createtag "field"      \
      -attrlist {var stream-method type list-single}]
    set xElem [wrapper::createtag "x"              \
      -attrlist {xmlns jabber:x:data type form}    \
      -subtags [list $fieldElem]]
    set featureElem [wrapper::createtag "feature"  \
      -attrlist [list xmlns $xmlns(neg)]           \
      -subtags [list $fieldElem]
    
    set siElem [wrapper::createtag "si"            \
      -attrlist [list xmlns $xmlns(si) id $sid mime-type $mime profile $profile] \
      -subtags [list $profileElem $featureElem]
    
    jlib::send_iq $jlibname set $siElem -to $jid  \
      -command [list [namespace current]::send_set_cb $jlibname $sid]

    return
}

# jlib::si::send_set_cb --
# 
#       Our internal callback handler when offered stream initiation.

proc jlib::si::send_set_cb {jlibname sid type subiq args} {
    
    puts "jlib::si::send_set_cb"
    
    variable xmlns
    variable trpt
    upvar ${jlibname}::si::state state

    if {[string equal $type "error"]} {
	uplevel #0 $state(cmd) [list $type ...]
	free $jlibname $sid
	return
    }
 
    # Verify that it is consistent.
    set values {}
    set value {}
    foreach name $trpt(names) {
	lappend values $trpt($name,ns)
    }
    if {![string equal [wrapper::gettag $subiq] "si"]} {
	uplevel #0 $state(cmd) [list error ...]
	free $jlibname $sid
	return
    }
    # @@@ wrapper::getdhildsdeep ?
    set featureElem [wrapper::getchildwithtaginnamespace $subiq "feature" $xmlns(neg)]
    if {[llength $featureElem]} {
	set xElem [wrapper::getchildwithtaginnamespace $featureElem "x" $xmlns(xdata)]
	if {[llength $xElem]} {
	    set fieldElem [wrapper::getfirstchildwithtag $xElem "field"]
	    if {[llength $fieldElem]} {
		set valueElem [wrapper::getfirstchildwithtag $fieldElem "value"]
		if {[llength $valueElem]} {
		    set value [wrapper::getcdata $valueElem]
		}
	    }
	}
    }
    
    # Find if matching transport.
    if {[lsearch $values $value] >= 0} {
	
	# Open transport. 
	# We provide a callback for the transport when open is finished.
	set state($sid,name) $value
	set jid $state($sid,jid)
	set cmd [list [namespace current]::transport_open_response $jlibname $sid]
	uplevel #0 $trpt($value,open) [list $jlibname $jid $sid $cmd]
    } else {
	uplevel #0 $state(cmd) [list error ...]
	free $jlibname $sid
    }
}

# jlib::si::transport_open_response --
# 
#       This is a transports way of reporting result from it's 'open' method.
#       It is also the end of the sequence of callbacks generated by 
#       'jlib::si::send_set'.

proc jlib::si::transport_open_response {jlibname sid type} {
    
    upvar ${jlibname}::si::state state
    
    puts "jlib::si::transport_open_response"
    
    # Rejected stream initiation.
    if {[string equal $type "error"]} {
	uplevel #0 $state(cmd) [list error ...]
    } else {
	uplevel #0 $state(cmd) [list result ...]
    }
    free $jlibname $sid
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# jlib::si::handle_set --
# 
#       Parse incoming si set element. Invokes registered callback for the
#       profile in question. It is the responsibility of this callback to
#       deliver the result via the command in its argument.

proc jlib::si::handle_set {jlibname from subiq args} {
    
    variable xmlns
    variable trpt
    variable prof
    upvar ${jlibname}::si::state state
    
    puts "jlib::si::handle_set"
    
    # Note: there are two different 'id'!
    # These are the attributes of the si element.
    array set attr {
	id          ""
	mime-type   ""
	profile     ""
    }
    array set attr [wrapper::getattrlist $subiq]
    set sid     $attr(id)
    set profile $attr(profile)
    
    if {![info exists prof($profile)]} {
	send_error $jlibname modify bad-request
	return 1
    }

    # Extract all streams and pick one with highest priority.
    # @@@ wrapper::getdhildsdeep ?
    set values {}
    set featureElem [wrapper::getchildwithtaginnamespace $subiq "feature" $xmlns(neg)]
    if {[llength $featureElem]} {
	set xElem [wrapper::getchildwithtaginnamespace $featureElem "x" $xmlns(xdata)]
	if {[llength $xElem]} {
	    set fieldElem [wrapper::getfirstchildwithtag $xElem "field"]
	    if {[llength $fieldElem]} {
		set optionElems [wrapper::getchildswithtag $fieldElem "option"]
		foreach c $optionElems {
		    lappend values [wrapper::getcdata  \
		      [lindex [wrapper::getchildren $c] 0]]
		}
	    }
	}
    }
    set myvalues {}
    foreach name $trpt(names) {
	lappend myvalues $trpt($name,ns)
    }
    
    # Pick first matching since priority ordered.
    set stream {}
    foreach name $values {
	if {[lsearch $myvalues $name] >= 0} {
	    set stream $name
	    break
	}
    }
    if {![string length $stream]} {
	send_error $jlibname bad-request no-valid-streams
	return
    }
        
    # Get profile element. Can have any tag but xmlns must be $profile.
    set profileElem [wrapper::getfirstchildwithxmlns $subiq $profile]
    if {![llength $profileElem]} {
	send_error $jlibname bad-request bad-profile
	return
    }

    set state($sid,profile)   $profile
    set state($sid,stream)    $stream
    set state($sid,mime-type) $attr(mime-type)
    foreach {key val} $args {
	set state($sid,$key)  $val
    }
    
    # Invoke registered handler.
    set cmd [list [namespace current]::profile_response $jlibname $sid]
    uplevel #0 $prof($profile) [list $cmd]

    return 1
}

# jlib::si::profile_response --
# 
#       Invoked by the registered profile callback.
#       
# Arguments:
#       type        'result' or 'error' if user accepts the stream or not.
#       profileElem any extra profile element; can be empty.

proc jlib::si::profile_response {jlibname sid type profileElem} {
    
    puts "jlib::si::profile_response"
    
    variable xmlns

    # Rejected stream initiation.
    if {[string equal $type "error"]} {
	send_error $jlibname cancel forbidden 
	return
    }

    # Accepted stream initiation.

    # Construct si element from selected profile.
    set valueElem [wrapper::createtag "value"  \
      -chdata $state($sid,stream)]
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
    
    set jid $state($sid,-from)
    set id  $state($sid,-id)
    
    jlib::send_iq $jlibname result $siElem -to $jid -id $id

    return
}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

proc jlib::si::send_error {jlibname sid code type stanza ...} {
    
    
    
    # ?
    free $jlibname $sid
}

proc jlib::si::free {jlibname sid} {
    
    upvar ${jlibname}::si::state state

    array unset state $sid,*
}

