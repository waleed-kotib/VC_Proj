#  bind.tcl --
#  
#      This file is part of the jabberlib. 
#      It implements the bind resource mechanism and establish a session.
#      
#  Copyright (c) 2007  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: bind.tcl,v 1.1 2007-07-23 15:11:43 matben Exp $

package require jlib

package provide jlib::bind 0.1

namespace eval jlib::bind {}

proc jlib::bind::resource {jlibname resource cmd} {
    upvar ${jlibname}::state state
    
    set state(resource) $resource
    set state(cmd)      $cmd
    
    if {[$jlibname have_feature bind]} {
	$jlibname bind_resource $state(resource) [namespace code resource_bind_cb]
    } else {
	$jlibname trace_stream_features [namespace code features]
    }
}

proc jlib::bind::features {jlibname} {
    upvar ${jlibname}::state state
    
    if {[$jlibname have_feature bind]} {
	$jlibname bind_resource $state(resource) [namespace code resource_bind_cb]
    } else {
	establish_session $jlibname
    }
}

proc jlib::bind::resource_bind_cb {jlibname type subiq} {
    
    if {$type eq "error"} {
	final $jlibname error $subiq
    } else {
	establish_session $jlibname
    }
}

proc jlib::bind::establish_session {jlibname} {
    upvar jlib::xmppxmlns xmppxmlns
    
    # Establish the session.
    set xmllist [wrapper::createtag session \
      -attrlist [list xmlns $xmppxmlns(session)]]
    $jlibname send_iq set [list $xmllist] \
      -command [namespace code [list send_session_cb $jlibname]]
}

proc jlib::bind::send_session_cb {jlibname type subiq args} {
    final $jlibname $type $subiq
}

proc jlib::bind::final {jlibname type subiq} {
    upvar ${jlibname}::state state
    
    uplevel #0 $state(cmd) [list $jlibname $type $subiq]
    unset -nocomplain state
}



