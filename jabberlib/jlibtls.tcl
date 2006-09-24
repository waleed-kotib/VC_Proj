#  jlibtls.tcl --
#  
#      This file is part of the jabberlib. It provides support for the
#      tls network socket security layer.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: jlibtls.tcl,v 1.14 2006-09-24 06:38:15 matben Exp $

package require tls
package require jlib

package provide jlibtls 1.0


proc jlib::starttls {jlibname cmd args} {
    
    upvar ${jlibname}::locals locals
    variable xmppxmlns
    
    Debug 2 "jlib::starttls"

    set locals(tls,cmd) $cmd
    
    # Set up callbacks for the xmlns that is of interest to us.
    element_register $jlibname $xmppxmlns(tls) [namespace current]::tls_parse

    if {[have_feature $jlibname]} {
	tls_continue $jlibname
    } else {
	trace_stream_features $jlibname [namespace current]::tls_features_write
    }
}

proc jlib::tls_features_write {jlibname} {
    
    Debug 2 "jlib::tls_features_write"
    
    trace_stream_features $jlibname {}
    tls_continue $jlibname
}

proc jlib::tls_continue {jlibname} {
    
    variable xmppxmlns

    Debug 2 "jlib::tls_continue"
    
    # Must verify that the server provides a 'starttls' feature.
    if {![have_feature $jlibname starttls]} {
	tls_finish $jlibname starttls-nofeature
    }
    set xmllist [wrapper::createtag starttls -attrlist [list xmlns $xmppxmlns(tls)]]
    send $jlibname $xmllist
    
    # Wait for 'failure' or 'proceed' element.
}

proc jlib::tls_parse {jlibname xmldata} {
    
    set tag [wrapper::gettag $xmldata]
    
    switch -- $tag {
	proceed {
	    tls_proceed $jlibname $tag $xmldata
	}
	failure {
	    tls_failure $jlibname $tag $xmldata
	}
	default {
	    tls_finish $jlibname starttls-protocol-error "unrecognized element"
	}
    }
    return
}

proc jlib::tls_proceed {jlibname tag xmllist} {    

    upvar ${jlibname}::lib lib
    
    Debug 2 "jlib::tls_proceed"
    
    set sock $lib(sock)

    # Make it a SSL connection.
    tls::import $sock -cafile "" -certfile "" -keyfile "" \
      -request 1 -server 0 -require 0 -ssl2 no -ssl3 yes -tls1 yes
    set retry 0
    
    # Do SSL handshake.
    while {1} {
	if {$retry > 20} { 
	    close $sock
	    set err "too long retry to setup SSL connection"
	    tls_finish $jlibname starttls-failure $err
	    return
	}
	if {[catch {tls::handshake $sock} err]} {
	    if {[string match "*resource temporarily unavailable*" $err]} {
		after 50  
		incr retry
	    } else {
		close $sock
		tls_finish $jlibname starttls-failure $err
		return
	    }
	} else {
	    break
	}
    }
    
    wrapper::reset $lib(wrap)
    
    # We must clear out any server info we've received so far.
    stream_reset $jlibname
    
    # The tls package resets the encoding to: -encoding binary
    if {[catch {
	fconfigure $sock -encoding utf-8
	sendstream $jlibname -version 1.0
    } err]} {
	tls_finish $jlibname network-failure $err
	return
    }

    # Wait for the SASL features. Seems to be the only way to detect success.
    trace_stream_features $jlibname [namespace current]::tls_features_write_2nd
    return
}

proc jlib::tls_features_write_2nd {jlibname} {
    
    Debug 2 "jlib::tls_features_write_2nd"
        
    tls_finish $jlibname
}

proc jlib::tls_failure {jlibname tag xmllist} {

    Debug 2 "jlib::tls_failure"
    
    # Seems we don't get any additional error info here.
    tls_finish $jlibname starttls-failure "tls failed"
}

proc jlib::tls_finish {jlibname {errcode ""} {msg ""}} {

    upvar ${jlibname}::locals locals
    variable xmppxmlns
    
    Debug 2 "jlib::tls_finish errcode=$errcode, msg=$msg"

    trace_stream_features $jlibname {}
    element_deregister $jlibname $xmppxmlns(tls) [namespace current]::tls_parse

    if {$errcode ne ""} {
	uplevel #0 $locals(tls,cmd) $jlibname [list error [list $errcode $msg]]
    } else {
	uplevel #0 $locals(tls,cmd) $jlibname [list result {}]
    }
}

# jlib::tls_reset --
# 
# 

proc jlib::tls_reset {jlibname} {
    
    variable xmppxmlns

    element_deregister $jlibname $xmppxmlns(tls) [namespace current]::tls_parse

    set cmd [trace_stream_features $jlibname]
    if {$cmd eq "[namespace current]::tls_features_write"} {
	trace_stream_features $jlibname {}
    } elseif {$cmd eq "[namespace current]::tls_features_write_2nd"} {
	trace_stream_features $jlibname {}
    }	
}

#-------------------------------------------------------------------------------
