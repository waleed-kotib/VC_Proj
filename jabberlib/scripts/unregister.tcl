# unregister.tcl --
#
#       Simple script that uses jabberlib to unregister an account.
#
# Copyright (c) 2007  Mats Bengtsson
# 
# This file is distributed under BSD style license.
#  
# $Id: unregister.tcl,v 1.3 2007-08-06 07:49:54 matben Exp $

package require jlib
package require jlib::connect

package provide jlibs::unregister 0.1

namespace eval jlibs::unregister {}

interp alias {} jlibs::unregister {} jlibs::unregister::unregister

# jlibs::unregister --
# 
#       Make a complete new session and unregister an account.
#       The options are passed on to 'connect'.

proc jlibs::unregister::unregister {jid password cmd args} {
    
    #puts "jlibs::unregister::unregister"
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
    
    eval {$jlib connect connect $jid $password \
      -command [namespace code cmdC]} $args
    return $jlib
}

proc jlibs::unregister::cmdC {jlib status {errcode ""} {errmsg ""}} {
    variable $jlib
    upvar 0 $jlib state
    
    if {![info exists state]} {
	return
    }
    if {$status eq "ok"} {
	jlib::splitjidex $state(jid) node server -
	$jlib register_remove $server [namespace code cmdR] 
    } elseif {$status eq "error"} {
	finish $jlib $errcode
    }    
}

proc jlibs::unregister::cmdR {jlib type subiq} {
    
    if {$type eq "result"} {
	finish $jlib    
    } else {
	finish $jlib $subiq
    }
}

proc jlibs::unregister::reset {jlib} {
    finish $jlib reset
}

proc jlibs::unregister::finish {jlib {err ""}} {
    variable $jlib
    upvar 0 $jlib state
    
    #puts "jlibs::unregister::finish"
    $jlib closestream
    
    if {$err ne ""} {
	uplevel #0 $state(cmd) [list $jlib error $err] 
    } else {
	uplevel #0 $state(cmd) [list $jlib ok] 
    }
    unset -nocomplain state
}

proc jlibs::unregister::noop {args} {}

if {0} {
    # Test:
    proc cmd {args} {puts "---> $args"}
    jlibs::unregister xyz@localhost xxx cmd
}


