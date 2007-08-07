# password.tcl --
#
#       Simple script that uses jabberlib to change password.
#
# Copyright (c) 2007  Mats Bengtsson
# 
# This file is distributed under BSD style license.
#  
# $Id: password.tcl,v 1.1 2007-08-07 07:51:27 matben Exp $

package require jlib
package require jlib::connect

package provide jlibs::password 0.1

namespace eval jlibs::password {}

interp alias {} jlibs::password {} jlibs::password::password

# jlibs::password --
# 
#       Make a complete new session and change password.
#       The options are passed on to 'connect' except:
#       

proc jlibs::password::password {jid password newpassword cmd args} {
    
    set jlib [jlib::new [namespace code noop]]

    variable $jlib
    upvar 0 $jlib state

    set state(jid)         $jid
    set state(password)    $password
    set state(newpassword) $newpassword
    set state(cmd)         $cmd
    set state(args)        $args
    set state(jlib)        $jlib
    
    jlib::util::from args -command
    jlib::util::from args -noauth  
    
    eval {$jlib connect connect $jid $password \
      -command [namespace code cmdC]} $args
    return $jlib
}

proc jlibs::password::cmdC {jlib status {errcode ""} {errmsg ""}} {
    variable sendOpts
    variable $jlib
    upvar 0 $jlib state
    
    if {![info exists state]} {
	return
    }
    if {$status eq "ok"} {
	jlib::splitjidex $state(jid) node server -
	$jlib register_set $node $state(password) [namespace code cmdS] \
	  -to $server
    } elseif {$status eq "error"} {
	finish $jlib $errcode
    }    
}

proc jlibs::password::cmdS {jlib type iqchild args} {
    variable $jlib
    upvar 0 $jlib state
    
    if {![info exists state]} {
	return
    }
    if {$type eq "result"} {
	finish $jlib
    } else {
	finish $jlib $iqchild
    }
}

proc jlibs::password::reset {jlib} {
    finish $jlib reset
}

proc jlibs::password::finish {jlib {err ""}} {
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

proc jlibs::password::noop {args} {}

if {0} {
    # Test:
    proc cmd {args} {puts "---> $args"}
    jlibs::password xyz@localhost xxx yyy cmd
}


