# register.tcl --
#
#       Simple script that uses jabberlib to register an account.
#
# Copyright (c) 2007  Mats Bengtsson
# 
# This file is distributed under BSD style license.
#  
# $Id: register.tcl,v 1.2 2007-08-04 08:35:54 matben Exp $

package require jlib
package require jlib::connect

package provide jlibs::register 0.1

namespace eval jlibs::register {}

interp alias {} jlibs::register {} jlibs::register::register

# jlibs::register --
# 
#       Make a complete new session and register an account.
#       The options are passed on to 'connect'.

proc jlibs::register::register {jid password cmd args} {
    
    set jlib [jlib::new [namespace code noop]]

    variable $jlib
    upvar 0 $jlib state

    set state(jid)      $jid
    set state(password) $password
    set state(cmd)      $cmd
    set state(args)     $args
    set state(jlib)     $jlib
    
    jlib::util::from args -command
    jlib::util::from args -noauth    
    jlib::splitjidex $jid node server -
    
    eval {$jlib connect connect $server {} \
      -noauth 1 -command [namespace code cmdC]} $args
    return $jlib
}

proc jlibs::register::cmdC {jlib status {errcode ""} {errmsg ""}} {
    variable $jlib
    upvar 0 $jlib state
    
    if {![info exists state]} {
	return
    }
    if {$status eq "ok"} {
	$jlib register_get [namespace code cmdG] 
    } elseif {$status eq "error"} {
	finish $jlib error $errcode
    }    
}

proc jlibs::register::cmdG {jlib type iqchild} {
    variable $jlib
    upvar 0 $jlib state

    if {![info exists state]} {
	return
    }
    if {$type eq "result"} {
	jlib::splitjidex $state(jid) node server -

	# Assuming minimal registration fileds.
	$jlib register_set $node $state(password) [namespace code cmdS]
    } else {
	finish $jlib error $iqchild
    }
}

proc jlibs::register::cmdS {jlib type iqchild args} {
    variable $jlib
    upvar 0 $jlib state
    
    if {![info exists state]} {
	return
    }
    if {$type eq "result"} {
	finish $jlib ok
    } else {
	finish $jlib error $iqchild
    }
}

proc jlibs::register::reset {jlib} {
    finish $jlib reset
}

proc jlibs::register::finish {jlib status {err ""}} {
    variable $jlib
    upvar 0 $jlib state
    
    $jlib closestream
    
    uplevel #0 $state(cmd) [list $jlib $status] 
    unset -nocomplain state
}

proc jlibs::register::noop {args} {}

if {0} {
    # Test:
    proc cmd {args} {puts "---> $args"}
    jlibs::register xyz@localhost xxx cmd
}


