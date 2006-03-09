#  jingle.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for the jingle stuff JEP-0166,
#      and provides pluggable "slots" for media description formats and 
#      transport methods, which are implemented separately. 
#      
#  Copyright (c) 2006  Mats Bengtsson
#  
# $Id: jingle.tcl,v 1.1 2006-03-09 10:40:32 matben Exp $
# 
############################# USAGE ############################################
#
#   NAME
#      jingle - library for Jingle
#      
#   SYNOPSIS
#      jlib::jingle::init jlibname
#      jlib::jingle::register name priority mediaElems transportElems tclProc
#      
#   The 'tclProc' is invoked for all jingle 'set' we get as:
#   
#      tclProc {jlibname jingleElem args}
#      
#   where the args are as usual the iq attributes, and the jingleElem is
#   guranteed to be a valid jingle element with the required attributes.
#      
#   OPTIONS
#   
#	
#   INSTANCE COMMANDS
#      jlibName jingle initiate name jid mediaElems trptElems cmd
#      jlibName jingle getstate session|media|transport sid
#      jlibName jingle getvalue session|media|transport sid key
#      jlibName jingle send_set sid action cmd ?elems?
#      jlibName jingle free sid
#      
#   The 'cmd' here are invoked just as ordinary send_iq callbacks:
#   
#      cmd {type subiq args}
#     
#   o You MUST use either 'initiate' or 'send_set' for anything not a *-info
#     call in order to keep the internal state machines inn sync.
#     
#   o In your registered tclProc you must handle all calls and start by 
#     acknowledging the receipt by sending a result for session-* actions (?). 
#     
#   o When a session is ended you are required to 'free' it yourself.
#   
#   o While debugging you may switch off 'verifyState' below.
#   
#   Each component registers a callback proc which gets called when there is
#   a 'set' (async) call aimed for it. 
#   
#                jlib::jingle
#                ------------
#               /  |       | \
#              /   |       |  \
#             /    |       |   \
#            /     |       |    \
#         iax  libjingle  sip  file-transfer
#        
#   TODO
#      Use responder attribute        
#      
#   UNCLEAR
#   o When are the state changed, after sending an action or when the response
#     is received?
#   o Does the media and transport require a result set for every state change?
#   
################################################################################

package require jlib
package require jlib::disco

package provide jlib::jingle 0.1

namespace eval jlib::jingle {

    variable inited 0
    variable inited_reg 0
    variable jxmlns
    set jxmlns(jingle)    "http://jabber.org/protocol/jingle"
    set jxmlns(media)     "http://jabber.org/protocol/jingle/media"
    set jxmlns(transport) "http://jabber.org/protocol/jingle/transport"
    set jxmlns(errors)    "http://jabber.org/protocol/jingle#errors"
    
    # Storage for registered media and transport.
    variable jingle
    
    # Cache some of our capabilities.
    variable have
    set have(jingle) 0
    
    # By default we verify all state changes.
    variable verifyState 1
    
    # For each session/media/transport state, make a map of allowed 
    # state changes:  state + action -> new state
    # State changes not listed here are not allowed.
    # @@@ It is presently unclear if these are independent.
    #     At least session-initiate and session-terminate control
    #     the media and transport states.
    
    # Session state maps:
    variable sessionMap
    array set sessionMap {
	pending,session-accept      active
	pending,session-redirect    ended
	pending,session-info        pending
	pending,session-terminate   ended
	active,session-redirect     ended
	active,session-info         active
	active,session-terminate    ended
    }    
        
    # Media state maps:
    variable mediaMap
    array set mediaMap {
	pending,media-info          pending
	pending,media-accept        active
	active,media-info           active
	active,media-modify         modifying
	modifying,media-info        modifying
	modifying,media-accept      active
	modifying,media-decline     active
    }
    
    # Transport state maps:
    variable transportMap
    array set transportMap {
	pending,transport-info      pending
	pending,transport-accept    active
	active,transport-info       active
	active,transport-modify     modifying
	modifying,transport-info    modifying
	modifying,transport-accept  active
	modifying,transport-decline active
    }
    
    jlib::register_reset [namespace current]::reset
    
    # Note: jlib::ensamble_register is last in this file!
}

# jlib::jingle::first_register --
# 
#       This is called for the first component that registers.

proc jlib::jingle::first_register {} {
    variable jxmlns
    variable inited_reg
    variable have
    
    # Now we know we have at least one component supporting this.
    jlib::disco::registerfeature $jxmlns(jingle)
    set have(jingle) 1
    set inited_reg 1
}

# jlib::jingle::register --
# 
#       A jingle component registers for a number of media and transport
#       elements. These are used together with its registered command to
#       dispatch incoming requests.
#       The 'name' is for internal use only and is not related to the
#       Jabber Registrar.
#       Disco features are automatically registered but caps are not.
#       
# Arguments:
#       name:       unique name 
#       priority:   number between 0-100
#       mediaElems:   list of the media elements. Only the xmlns is necessary.
#                     The complete elements is supplied when doing an initiate.
#       transportElems:  same for transport
#       cmd:        tclProc for callbacks
# 
# Result:
#       name

proc jlib::jingle::register {name priority mediaElems transportElems cmd} {
    variable jingle
    variable inited_reg
    
    set jingle($name,name)       $name
    set jingle($name,prio)       $priority
    set jingle($name,cmd)        $cmd
    set jingle($name,lmedia)     $mediaElems
    set jingle($name,ltransport) $transportElems
    
    # Extract the xmlns for media and transport.
    set jingle($name,media,lxmlns) {}
    foreach elem $mediaElems {
	set xmlns [wrapper::getattribute $elem xmlns]
	lappend jingle($name,media,lxmlns) $xmlns
    }
    set jingle($name,transport,lxmlns) {}
    foreach elem $transportElems {
	set xmlns [wrapper::getattribute $elem xmlns]
	lappend jingle($name,transport,lxmlns) $xmlns
    }
    
    # Register disco xmlns.
    if {!$inited_reg} {
	first_register
    }
    foreach xmlns $jingle($name,media,lxmlns) {
	jlib::disco::registerfeature $xmlns
    }
    foreach xmlns $jingle($name,transport,lxmlns) {
	jlib::disco::registerfeature $xmlns
    }
    return $name
}

# jlib::jingle::init --
# 
#       Sets up jabberlib handlers and makes a new instance if an jingle object.
  
proc jlib::jingle::init {jlibname args} {
    variable inited
    variable jxmlns
    
    puts "jlib::jingle::init"
    
    if {!$inited} {
	InitOnce
    }    

    # Keep state array for each session as session(sid,...).
    namespace eval ${jlibname}::jingle {
	variable session
    }
    upvar ${jlibname}::jingle::session  session
                
    # Register some standard iq handlers that is handled internally.
    $jlibname iq_register  set  $jxmlns(jingle) [namespace current]::set_handler

    return
}

proc jlib::jingle::InitOnce { } {
    
    variable inited

    
    set inited 1
}

proc jlib::jingle::have {what} {
    variable have
    
    # ???
}

# jlib::jingle::cmdproc --
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

proc jlib::jingle::cmdproc {jlibname cmd args} {
    
    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

# jlib::jingle::send_set --
# 
#       Utility function for sending jingle set stanzas.
#       This MUST be used instead of send_iq since the internal state
#       machines must be updated as well. The exception is *-info actions
#       which don't affect the state.
#       
# Arguments:
# 
# Results:
#       None.

proc jlib::jingle::send_set {jlibname sid action cmd {elems {}}} {
    variable verifyState
    
    # Be sure to set the internal state as well.
    set state [set_state $jlibname $sid $action]
    if {$verifyState && $state eq ""} {
	return -code error "the proposed action $action is not allowed"
    }
    do_send_set $jlibname $sid $action $cmd $elems
    return
}

# jlib::jingle::do_send_set --
# 
#       Makes the actual sending. State must be fixed prior to call.
#       Internal use only.

proc jlib::jingle::do_send_set {jlibname sid action cmd {elems {}}} {
    variable jxmlns
    upvar ${jlibname}::jingle::session  session
    
    set jid       $session($sid,jid)
    set initiator $session($sid,initiator)
    set attr [list xmlns $jxmlns(jingle) action $action  \
      initiator $initiator sid $sid]
    set jelem [wrapper::createtag jingle -attrlist $attr -subtags $elems]
    
    jlib::send_iq $jlibname set [list $jelem] -to $jid -command $cmd
}

# @@@ If the state changes shall only take place *after* received a response,
#     we need to intersect all calls here.
proc jlib::jingle::send_set_cb {} {
    
}

# @@@ Same thing here!
proc jlib::jingle::send_result {} {
    
}

# jlib::jingle::set_state --
# 
#       Checks to see if the requested action is a valid one.
#       Sets the new state if ok.
#       
# Arguments:
# 
# Results:
#       empty if inconsistent, else the new state.

proc jlib::jingle::set_state {jlibname sid action} {    
    variable sessionMap
    variable mediaMap
    variable transportMap
    upvar ${jlibname}::jingle::session  session

    # Since we are a state machine we must check that the requested state
    # change is consistent.
    if {$action eq "session-initiate"} {

	# No error checking here!
	set session($sid,state,session)   "pending"
	set session($sid,state,media)     "pending"
	set session($sid,state,transport) "pending"
	puts "\t action=$action, state=pending"
	return "pending"
    } elseif {$action eq "session-terminate"} {

	# No error checking here!
	set session($sid,state,session)   "ended"
	set session($sid,state,media)     "ended"
	set session($sid,state,transport) "ended"
	puts "\t action=$action, state=ended"
	return "ended"

    } else {
	set actionType [lindex [split $action -] 0]
	set state $session($sid,state,$actionType)
    
	puts "\t action=$action, state=$state,   actionType=$actionType"
	if {[info exists ${actionType}Map\($state,$action)]} {
	    set state [set ${actionType}Map\($state,$action)]
	    puts "\t new state=$state"
	    set session($sid,state,$actionType) $state
	    return $state
	} else {
	    puts "\t out-of-sync"
	    return ""
	}
    }    
}

# jlib::jingle::initiate --
# 
#       A jingle component makes a session-initiate request.
#       This must be used instead of send_set for the initiate call.
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#       name:
#       jid:
#       mediaElems:
#       trptElems:
#       cmd:
#       
# Results:
#       sid.

proc jlib::jingle::initiate {jlibname name jid mediaElems trptElems cmd args} {
    variable jingle
    upvar ${jlibname}::jingle::session  session
    
    puts "jlib::jingle::initiate"
      
    # SIP may want to generate its own sid.
    set opts(-sid) [jlib::generateuuid]
    set opts(-initiator) [jlib::myjid $jlibname]
    array set opts $args
    set sid $opts(-sid)

    # We keep the internal jingle states for this sid.
    set session($sid,sid)       $sid
    set session($sid,jid)       $jid
    set session($sid,name)      $name
    set session($sid,initiator) $opts(-initiator)
    set session($sid,cmd)       $jingle($name,cmd)

    set subElems [concat $mediaElems $trptElems]
    set_state $jlibname $sid "session-initiate"
    
    do_send_set $jlibname $sid "session-initiate" $cmd $subElems
    
    return $sid
}

# jlib::jingle::set_handler --
# 
#       Parse incoming jingle set element.

proc jlib::jingle::set_handler {jlibname from subiq args} {
    variable have
    variable verifyState
    upvar ${jlibname}::jingle::session  session
    
    puts "jlib::jingle::set_handler"
    
    array set argsArr $args
    if {![info exists argsArr(-id)]} {
	return
    }
    set id $argsArr(-id)
    
    # There are several reasons why the target entity might return an error 
    # instead of acknowledging receipt of the initiation request: 
    # o The initiating entity is unknown to the target entity (e.g., via 
    #   presence subscription). 
    # o The target entity does not support Jingle. 
    # o The target entity does not support any of the specified media 
    #   description formats. 
    # o The target entity does not support any of the specified transport 
    #   methods.
    # o The initiation request was malformed. 

    set jelem [wrapper::getfirstchildwithtag $argsArr(-xmldata) "jingle"]
    if {$jelem eq {}} {
	jlib::send_iq_error $jlibname $from $id 404 cancel service-unavailable
	return 1
    }
    if {!$have(jingle)} {
	jlib::send_iq_error $jlibname $from $id 404 cancel service-unavailable
	return 1
    }
    
    # Check required attributes: sid, action, initiator.
    foreach aname {sid action initiator} {
	set $aname [wrapper::getattribute $jelem $aname]
	if {$aname eq ""} {
	    puts "\t missing $aname"
	    jlib::send_iq_error $jlibname $from $id 404 cancel bad-request
	    return 1
	}
    }
    puts "\t $sid $action $initiator"
    
    # We already have a session for this sid.
    if {[info exists session($sid,sid)]} {
	if {$verifyState && $session($sid,state,session) eq "ended"} {
	    send_error $jlibname $from $id unknown-session
	    return 1
	}

	# The action must not be an initiate.
	if {$verifyState && $action eq "session-initiate"} {
	    send_error $jlibname $from $id out-of-order
	    return 1
	}	
	
	# Since we are a state machine we must check that the requested state
	# change is consistent.
	set state [set_state $jlibname $sid $action]
	if {$verifyState && $state eq ""} {
	    puts "\t $action out-of-order"
	    send_error $jlibname $from $id out-of-order
	    return 1
	}
    } else {
	
	# The first action must be an initiate.
	if {$verifyState && $action ne "session-initiate"} {
	    send_error $jlibname $from $id out-of-order
	    return 1
	}	
    }
    
    switch -- $action {
	"session-initiate" {
	    set session($sid,sid)       $sid
	    set session($sid,jid)       $from
	    set session($sid,initiator) $initiator
	    set session($sid,jelem)     $jelem
	    eval {initiate_handler $jlibname $sid $id $jelem} $args
	}
	default {
	    uplevel #0 $session($sid,cmd) $jlibname [list $jelem] $args
	}
    }
    
    # Is handled here.
    return 1
}

# jlib::jingle::initiate_handler --
# 
#       We must find the jingle component that matches this initiate.

proc jlib::jingle::initiate_handler {jlibname sid id jelem args} {
    variable jingle
    upvar ${jlibname}::jingle::session  session
    
    puts "jlib::jingle::initiate_handler"
    
    # Use the 'sid' as the identifier for the state array.
    set session($sid,state,session)   "pending"
    set session($sid,state,media)     "pending"
    set session($sid,state,transport) "pending"
    
    set jid $session($sid,jid)
    
    # Match the media and transport with the ones we have registered,
    # and use the best matched registered component.
    set nsmedia {}
    foreach elem [wrapper::getchildswithtag $jelem "description"] {
	lappend nsmedia [wrapper::getattribute $elem xmlns]
    }
    set nstrpt {}
    foreach elem [wrapper::getchildswithtag $jelem "transport"] {
	lappend nstrpt [wrapper::getattribute $elem xmlns]
    }
    
    # @@@ This matches only the xmlns which is not enough.
    #     The details is up to each component to negotiate?
    #     
    # Make a list of candidates that support both media and transport xmlns:
    #    {{name prio} ...} and order them in decreasing priorities.
    set lbest {}
    set anymedia 0
    set anytransport 0
    foreach {- name} [array get jingle *,name] {
	set mns [jlib::util::lintersect $jingle($name,media,lxmlns) $nsmedia]
	set tns [jlib::util::lintersect $jingle($name,transport,lxmlns) $nstrpt]
	
	# A component must support both media and transport.
	if {[llength $mns] && [llength $tns]} {
	    lappend lbest [list $name $jingle($name,prio)]
	}
	if {[llength $mns]} {
	    set anymedia 1
	}
	if {[llength $tns]} {
	    set anytransport 1
	}
    }
    if {$lbest eq {}} {
	if {!$anymedia} {
	    send_error $jlibname $jid $id unsupported-media
	} elseif {!$anytransport} {
	    send_error $jlibname $jid $id unsupported-transport
	} else {
	    # It is the actual combination media/transport that is unsupported.
	    send_error $jlibname $jid $id unsupported-media
	}
    } else {
	set lbest [lsort -integer -index 1 -decreasing $lbest]
	puts "\t lbest=$lbest"
    
	# Delegate to the component.
	# It is then up to the component to take the initiatives:
	#     transport-accept etc.
	# @@@ We make a crude shortcut here and pick only the best.
	set name [lindex $lbest 0 0]
	set cmd $jingle($name,cmd)
	set session($sid,name) $name
	set session($sid,cmd)  $cmd
	uplevel #0 $cmd $jlibname [list $jelem] $args
    }
}

proc jlib::jingle::send_error {jlibname jid id stanza} {
    variable jxmlns
    
    # @@@ Not sure about the details here.
    set elem [wrapper::createtag $stanza  \
      -attrlist [list xmlns $jxmlns(errors)]]
    jlib::send_iq_error $jlibname $jid $id 404 cancel bad-request $elem
}

# A few accessor functions.

# jlib::jingle::getstate --
# 
#       Return the current state for session, media, or transport.

proc jlib::jingle::getstate {jlibname type sid} {
    upvar ${jlibname}::jingle::session  session

    return $session($sid,state,$type)
}

proc jlib::jingle::getvalue {jlibname type sid key} {
    upvar ${jlibname}::jingle::session  session

    return $session($sid,$key)
}

proc jlib::jingle::reset {jlibname} {
    
    # Shall we clear out all sessions here?
}

proc jlib::jingle::free {jlibname sid} {
    upvar ${jlibname}::jingle::session  session

    puts "jlib::jingle::free"
    
    array unset session   $sid,*
}

# We have to do it here since need the initProc befor doing this.

namespace eval jlib::jingle {

    jlib::ensamble_register jingle  \
      [namespace current]::init     \
      [namespace current]::cmdproc
}

# Primitive test code.
if {0} {
    package require jlib::jingle
    
    set jlibname jlib::jlib1
    set myjid [jlib::myjid $jlibname]
    set jid $myjid
    set xmlnsTransportIAX     "http://jabber.org/protocol/jingle/transport/iax"
    set xmlnsMediaAudio       "http://jabber.org/protocol/jingle/media/audio"

    # Register:
    set transportElem [wrapper::createtag "transport" \
      -attrlist [list xmlns $xmlnsTransportIAX version 2] ]
    set mediaElemAudio [wrapper::createtag "description" \
      -attrlist [list xmlns $xmlnsMediaAudio] ]
    
    proc cmdIAX {jlibname _jelem args} {
	puts "IAX: $args"
	array set argsArr $args
	set sid    [wrapper::getattribute $_jelem sid]
	set action [wrapper::getattribute $_jelem action]
	puts "\t action=$action, sid=$sid"
	
	# Only session actions are acknowledged?
	if {[string match "session-*" $action]} {
	    $jlibname send_iq result {} -to $argsArr(-from) -id $argsArr(-id)
	}
	
	switch -- $action {
	    "session-initiate" {
		set ::jelem $_jelem
		
		
	    }
	}
    }
    jlib::jingle::register iax 50  \
      [list $mediaElemAudio] [list $transportElem] cmdIAX
    
    # Disco:
    proc cb {args} {puts "cb: $args"}
    $jlibname disco send_get info $jid cb
    
    # Initiate:
    set sid [$jlibname jingle initiate iax $jid  \
      [list $mediaElemAudio] [list $transportElem] cb]
    
    # IAX callbacks:
    set media [wrapper::getfirstchildwithtag $jelem "description"]
    $jlibname jingle send_set $sid "media-accept" cb [list $media]

    set trpt  [wrapper::getfirstchildwithtag $jelem "transport"]
    $jlibname jingle send_set $sid "transport-accept" cb [list $trpt]

    $jlibname jingle send_set $sid "session-accept" cb

    # Talk here!
    
    parray ${jlibname}::jingle::session
    
    # Shut up!
    $jlibname jingle send_set $sid "session-terminate" cb
}

#-------------------------------------------------------------------------------
