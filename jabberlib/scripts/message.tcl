# message.tcl --
#
#       Simple script that uses jabberlib to send a message.
#
# Copyright (c) 2007  Mats Bengtsson
# 
# This file is distributed under BSD style license.
#  
# $Id: message.tcl,v 1.2 2007-08-06 07:49:54 matben Exp $

package require jlib
package require jlib::connect

package provide jlibs::message 0.1

namespace eval jlibs::message {
    
    variable sendOpts {-subject -thread -body -type -xlist}
}

interp alias {} jlibs::message {} jlibs::message::message

# jlibs::message --
# 
#       Make a complete new session and send a message.
#       The options are passed on to 'connect' except:
#       

proc jlibs::message::message {jid password to cmd args} {
    variable sendOpts
    
    set jlib [jlib::new [namespace code noop]]

    variable $jlib
    upvar 0 $jlib state

    set state(jid)      $jid
    set state(password) $password
    set state(to)       $to
    set state(cmd)      $cmd
    set state(args)     $args
    set state(jlib)     $jlib
    
    jlib::util::from args -command
    jlib::util::from args -noauth  
    
    # Extract the message options.
    foreach name $sendOpts {
	set state($name) [jlib::util::from args $name]
    }
    eval {$jlib connect connect $jid $password \
      -command [namespace code cmdC]} $args
    return $jlib
}

proc jlibs::message::cmdC {jlib status {errcode ""} {errmsg ""}} {
    variable sendOpts
    variable $jlib
    upvar 0 $jlib state
    
    if {![info exists state]} {
	return
    }
    if {$status eq "ok"} {
	set opts [list]
	foreach name $sendOpts {
	    if {$state($name) ne ""} {
		lappend opts $name $state($name)
	    }
	}
	eval {$jlib send_message $state(to)} $opts
	finish $jlib
    } elseif {$status eq "error"} {
	finish $jlib $errcode
    }    
}

proc jlibs::message::reset {jlib} {
    finish $jlib reset
}

proc jlibs::message::finish {jlib {err ""}} {
    variable $jlib
    upvar 0 $jlib state
    
    $jlib closestream
    
    if {$err ne ""} {
	uplevel #0 $state(cmd) [list $jlib error $err] 
    } else {
	uplevel #0 $state(cmd) [list $jlib ok] 
    }
    unset -nocomplain state
}

proc jlibs::message::noop {args} {}

if {0} {
    # Test:
    proc cmd {args} {puts "---> $args"}
    jlibs::message xyz@localhost xxx matben@localhost cmd -body Hej -subject Hej
}


