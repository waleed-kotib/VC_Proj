#  jlibtls.tcl --
#  
#      This file is part of the jabberlib. It provides support for the
#      tls network socket security layer.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: jlibtls.tcl,v 1.1 2004-10-12 13:48:56 matben Exp $

package require tls

package provide jlibtls 1.0


namespace eval jlib { }

proc jlib::starttls {jlibname cmd args} {
    
    upvar ${jlibname}::locals locals
    
    Debug 2 "jlib::starttls"

    set locals(tls,cmd) $cmd
    
    # Set up callbacks for elements that are of interest to us.
    element_register $jlibname failure [namespace current]::tls_failure
    element_register $jlibname proceed [namespace current]::tls_proceed

    if {[info exists locals(features,mechanisms)]} {
	tls_continue $jlibname
    } else {
	
	# Must be careful so this is not triggered by a reset or something...
	trace add variable ${jlibname}::locals(features,mechanisms) write \
	  [list [namespace current]::tls_mechanisms_write $jlibname]
    }
}

proc jlib::tls_mechanisms_write {jlibname name1 name2 op} {
    
    Debug 2 "jlib::tls_mechanisms_write"
    
    trace remove variable ${jlibname}::locals(features,mechanisms) write \
      [list [namespace current]::tls_mechanisms_write $jlibname]
    tls_continue $jlibname
}

proc jlib::tls_continue {jlibname} {
    
    variable xmppns

    Debug 2 "jlib::tls_continue"
    
    set xmllist [wrapper::createtag starttls -attrlist [list xmlns $xmppns(tls)]]
    send $jlibname $xmllist
    
    # Wait for 'failure' or 'proceed' element.
}

proc jlib::tls_proceed {jlibname tag xmllist} {    

    upvar ${jlibname}::locals locals
    upvar ${jlibname}::opts opts
    upvar ${jlibname}::lib lib
    variable xmppns
    
    Debug 2 "jlib::tls_proceed"
    if {[wrapper::getattribute $xmllist xmlns] != $xmppns(tls)} {
	tls_finish $jlibname "received incorrectly namespaced proceed element"
    }

    set sock $lib(sock)

    # Make it a SSL connection.
    tls::import $sock -cafile "" -certfile "" -keyfile "" \
      -request 1 -server 0 -require 0 -ssl2 no -ssl3 yes -tls1 yes
    set retry 0
    
    while {1} {
	if {$retry > 20} { 
	    close $sock
	    set err "too long retry to setup SSL connection"
	    tls_finish $jlibname $err
	}
	if {[catch {tls::handshake $sock} err]} {
	    if {[string match "*resource temporarily unavailable*" $err]} {
		after 50  
		incr retry
	    } else {
		close $sock
		tls_finish $jlibname $err
	    }
	} else {
	    break
	}
    }
    
    wrapper::reset $lib(wrap)
    
    # We must clear out any server info we've received so far.
    # Seems the only info is from the <features/> element.
    # UGLY.
    array unset locals features*
    
    set xml "<stream:stream\
      xmlns='$opts(-streamnamespace)' xmlns:stream='$xmppns(stream)'\
      to='$locals(server)' xml:lang='[getlang]' version='1.0'>"

    eval $lib(transportsend) {$xml}

    tls_finish $jlibname
}

proc jlib::tls_failure {jlibname tag xmllist} {

    upvar ${jlibname}::locals locals
    variable xmppns

    Debug 2 "jlib::tls_failure"
    
    if {[wrapper::getattribute $xmllist xmlns] == $xmppns(tls)} {
	tls_finish $jlibname "tls failed"
    } else {
	tls_finish $jlibname "tls failed for an unknown reason"
    }
    return {}
}

proc jlib::tls_finish {jlibname {errmsg ""}} {

    upvar ${jlibname}::locals locals
    
    Debug 2 "jlib::tls_finish errmsg=$errmsg"

    element_deregister $jlibname failure [namespace current]::tls_failure
    element_deregister $jlibname proceed [namespace current]::tls_proceed
    
    if {$errmsg != ""} {
	uplevel #0 $locals(tls,cmd) $jlibname [list error [list "" $errmsg]]
    } else {
	uplevel #0 $locals(tls,cmd) $jlibname [list result {}]
    }
}

# jlib::tls_reset --
# 
# 

proc jlib::tls_reset {jlibname} {
    
    upvar ${jlibname}::locals locals

    trace remove variable ${jlibname}::locals(features,mechanisms) write \
      [list [namespace current]::tls_mechanisms_write $jlibname]
}

