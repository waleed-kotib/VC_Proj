#  jlibtls.tcl --
#  
#      This file is part of the jabberlib. It provides support for the
#      tls network socket security layer.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: jlibtls.tcl,v 1.19 2007-07-23 15:11:43 matben Exp $

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
    upvar ${jlibname}::locals locals
    
    Debug 2 "jlib::tls_proceed"
    
    set sock $lib(sock)
    
    # Make it a SSL connection.
    if {[catch {
	tls::import $sock -cafile "" -certfile "" -keyfile "" \
	  -request 1 -server 0 -require 0 -ssl2 no -ssl3 yes -tls1 yes
    } err]} {
	close $sock
	tls_finish $jlibname starttls-failure $err
    }
    
    # We must initiate the handshake before getting any answers.
    set locals(tls,retry) 0
    set locals(tls,fevent) [fileevent $sock readable]
    tls_handshake $jlibname
}

# jlib::tls_handshake --
# 
#       Performs the TLS handshake using filevent readable until completed
#       or a nonrecoverable error.
#       This method of using fileevent readable seems independent of
#       speed of network connection (dialup/broadband) which a fixed
#       loop with 50ms delay isn't!

proc jlib::tls_handshake {jlibname} {
    global  errorCode
    upvar ${jlibname}::lib lib
    upvar ${jlibname}::locals locals
    
    set sock $lib(sock)
    
    # Do SSL handshake.
    if {$locals(tls,retry) > 100} { 
	close $sock
	set err "too long retry to setup SSL connection"
	tls_finish $jlibname starttls-failure $err
    } elseif {[catch {tls::handshake $sock} complete]} {
	if {[lindex $errorCode 1] eq "EAGAIN"} {
	    incr locals(tls,retry)
	    
	    # Temporarily hijack these events.
	    fileevent $sock readable  \
	      [namespace code [list tls_handshake $jlibname]]
	} else {
	    close $sock
	    tls_finish $jlibname starttls-failure $err
	}
    } elseif {$complete} {
	Debug 2 "\t number of TLS handshakes=$locals(tls,retry)"
	
	# Reset the event handler to what it was.
	fileevent $sock readable $locals(tls,fevent)
	tls_handshake_fin $jlibname
    }   
}

proc jlib::tls_handshake_fin {jlibname} {

    upvar ${jlibname}::lib lib

    wrapper::reset $lib(wrap)
    
    # We must clear out any server info we've received so far.
    stream_reset $jlibname
    set sock $lib(sock)
    
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
