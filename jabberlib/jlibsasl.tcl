#  jlibsasl.tcl --
#  
#      This file is part of the jabberlib. It provides support for the
#      sasl authentication layer via the tclsasl package or the saslmd5
#      pure tcl package.
#      It also makes the resource binding and session initiation.
#      
#        o sasl authentication
#        o bind resource
#        o establish session
#      
#  Copyright (c) 2004-2006  Mats Bengtsson
#  
# $Id: jlibsasl.tcl,v 1.24 2006-09-12 10:19:23 matben Exp $

package require jlib
package require saslmd5
set ::_saslpack saslmd5

package provide jlibsasl 1.0


namespace eval jlib {
    variable cyrussasl 
    
    if {$::_saslpack eq "cyrussasl"} {
	set cyrussasl 1
    } else {
	set cyrussasl 0
    }
    unset ::_saslpack
}

proc jlib::sasl_init {} {
    variable cyrussasl 
    
    if {$cyrussasl} {
	sasl::client_init -callbacks \
	  [list [list log [namespace current]::sasl_log]]
    } else {
	# empty
    }
}

proc jlib::decode64 {str} {
    variable cyrussasl 

    if {$cyrussasl} {
	return [sasl::decode64 $str]
    } else {
	return [saslmd5::decode64 $str]
    }
}

proc jlib::encode64 {str} {
    variable cyrussasl 

    if {$cyrussasl} {
	return [sasl::encode64 $str]
    } else {
	return [saslmd5::encode64 $str]
    }
}

# jlib::auth_sasl --
# 
#       Create a new SASL object.

proc jlib::auth_sasl {jlibname username resource password cmd} {
    
    upvar ${jlibname}::locals locals
    variable xmppxmlns
    
    Debug 2 "jlib::auth_sasl"
        
    # Cache our login jid.
    set locals(username) $username
    set locals(resource) $resource
    set locals(password) $password
    set locals(myjid2)   ${username}@$locals(server)
    set locals(myjid)    ${username}@$locals(server)/${resource}
    set locals(sasl,cmd) $cmd
    
    # Set up callbacks for elements that are of interest to us.
    element_register $jlibname $xmppxmlns(sasl) [namespace current]::sasl_parse

    if {[have_feature $jlibname mechanisms]} {
	auth_sasl_continue $jlibname
    } else {
	trace_stream_features $jlibname [namespace current]::sasl_features
    }
}

proc jlib::sasl_features {jlibname} {

    upvar ${jlibname}::locals locals

    Debug 2 "jlib::sasl_features"
    
    # Verify that sasl is supported before going on.
    set features [get_feature $jlibname "mechanisms"]
    if {$features eq ""} {
	set msg "no sasl mechanisms announced by the server"
	sasl_final $jlibname error [list sasl-no-mechanisms $msg]
    } else {
	auth_sasl_continue $jlibname
    }
}

proc jlib::sasl_parse {jlibname xmldata} {
    
    set tag [wrapper::gettag $xmldata]
    
    switch -- $tag {
	challenge {
	    sasl_challenge $jlibname $tag $xmldata
	}
	failure {
	    sasl_failure $jlibname $tag $xmldata
	}
	success {
	    sasl_success $jlibname $tag $xmldata	    
	}
	default {
	    sasl_final $jlibname error [list sasl-protocol-error {}]
	}
    }
    return
}

# jlib::auth_sasl_continue --
# 
#       We respond to the 
#       <stream:features>
#           <mechanisms ...>
#               <mechanism>DIGEST-MD5</mechanism>
#               <mechanism>PLAIN</mechanism>
#            ...

proc jlib::auth_sasl_continue {jlibname} {
    
    upvar ${jlibname}::lib lib
    upvar ${jlibname}::locals locals
    variable xmppxmlns
    variable cyrussasl 

    Debug 2 "jlib::auth_sasl_continue"
    
    if {$cyrussasl} {

	# TclSASL's callback id's seem to be a bit mixed up.
	foreach id {authname user pass getrealm} {
	    lappend callbacks [list $id [list [namespace current]::sasl_callback \
	      $jlibname]]
	}
	set sasltoken [sasl::client_new \
	  -service xmpp -serverFQDN $locals(server) -callbacks $callbacks \
	  -flags success_data]
    } else {
	
	# The saslmd5 package follow the naming convention in RFC 2831
	foreach id {username authzid pass realm} {
	    lappend callbacks [list $id [list [namespace current]::saslmd5_callback \
	      $jlibname]]
	}
	set sasltoken [saslmd5::client_new \
	  -service xmpp -serverFQDN $locals(server) -callbacks $callbacks \
	  -flags success_data]
    }
    set lib(sasl,token) $sasltoken
    
    if {$cyrussasl} {
	$sasltoken -operation setprop -property sec_props \
	  -value {min_ssf 0 max_ssf 0 flags {noplaintext}}
    } else {
	$sasltoken setprop sec_props {min_ssf 0 max_ssf 0 flags {noplaintext}}
    }
    
    # Returns a serialized array if succesful.
    set mechanisms [get_feature $jlibname mechanisms]
    if {$cyrussasl} {
	set code [catch {
	    $sasltoken -operation start -mechanisms $mechanisms \
	      -interact [list [namespace current]::sasl_interact $jlibname]
	} out]
    } else {
	set ans [$sasltoken start -mechanisms $mechanisms]
	set code [lindex $ans 0]
	set out  [lindex $ans 1]
    }
    Debug 2 "\t -operation start: code=$code, out=$out"
    
    switch -- $code {
	0 {	    
	    # ok
	    array set outArr $out
	    set xmllist [wrapper::createtag auth \
	      -attrlist [list xmlns $xmppxmlns(sasl) mechanism $outArr(mechanism)] \
	      -chdata [encode64 $outArr(output)]]
	    send $jlibname $xmllist
	}
	4 {	    
	    # continue
	    array set outArr $out
	    set xmllist [wrapper::createtag auth \
	      -attrlist [list xmlns $xmppxmlns(sasl) mechanism $outArr(mechanism)] \
	      -chdata [encode64 $outArr(output)]]
	    send $jlibname $xmllist
	}
	default {
	    # This is an error
	    # We should perhaps send an abort element here.
	    sasl_final $jlibname error [list sasl-error $out]
	}
    }
}

proc jlib::sasl_interact {jlibname data} {
    
    # empty
}

# jlib::sasl_callback --
# 
#       TclSASL's callback id's seem to be a bit mixed up.

proc jlib::sasl_callback {jlibname data} {
    
    upvar ${jlibname}::locals locals

    array set arr $data
    
    # @@@ Is 'convertto utf-8' really necessary?
    
    switch -- $arr(id) {
	authname {
	    # username
	    set value [encoding convertto utf-8 $locals(username)]
	}
	user {
	    # authzid
	    set value [encoding convertto utf-8 $locals(myjid2)]
	}
	pass {
	    set value [encoding convertto utf-8 $locals(password)]
	}
	getrealm {
	    set value [encoding convertto utf-8 $locals(server)]
	}
	default {
	    set value ""
	}
    }
    return $value
}

# jlib::saslmd5_callback --
# 
#       The saslmd5 package follow the naming convention in RFC 2831.

proc jlib::saslmd5_callback {jlibname data} {
    
    upvar ${jlibname}::locals locals

    array set arr $data
    
    switch -- $arr(id) {
	username {
	    set value [encoding convertto utf-8 $locals(username)]
	}
	pass {
	    set value [encoding convertto utf-8 $locals(password)]
	}
	authzid {
	    
	    # xmpp-core sect. 6.1:
	    # As specified in [SASL], the initiating entity MUST NOT provide an
	    # authorization identity unless the authorization identity is
	    # different from the default authorization identity derived from
	    # the authentication identity as described in [SASL].
	    
	    #set value [encoding convertto utf-8 $locals(myjid2)]
	    set value ""
	}
	realm {
	    set value [encoding convertto utf-8 $locals(server)]
	}
	default {
	    set value ""
	}
    }
    Debug 2 "jlib::saslmd5_callback id=$arr(id), value=$value"
    
    return $value
}

proc jlib::sasl_challenge {jlibname tag xmllist} {
    
    Debug 2 "jlib::sasl_challenge"
    
    sasl_step $jlibname [wrapper::getcdata $xmllist]
    return
}

proc jlib::sasl_step {jlibname serverin64} {
    
    upvar ${jlibname}::lib lib
    upvar ${jlibname}::locals locals
    variable xmppxmlns
    variable cyrussasl

    set serverin [decode64 $serverin64]
    Debug 2 "jlib::sasl_step, serverin=$serverin"
    
    # Note that 'step' returns the output if succesful, not a serialized array!
    if {$cyrussasl} {
	set code [catch {
	    $lib(sasl,token) -operation step -input $serverin \
	      -interact [list [namespace current]::sasl_interact $jlibname]
	} output]
    } else {
	foreach {code output} [$lib(sasl,token) step -input $serverin] {break}
    }
    Debug 2 "\t code=$code \n\t output=$output"
    
    switch -- $code {
	0 {	    
	    # ok
	    set xmllist [wrapper::createtag response \
	      -attrlist [list xmlns $xmppxmlns(sasl)] \
	      -chdata [encode64 $output]]
	    send $jlibname $xmllist
	}
	4 {	    
	    # continue
	    set xmllist [wrapper::createtag response \
	      -attrlist [list xmlns $xmppxmlns(sasl)] \
	      -chdata [encode64 $output]]
	    send $jlibname $xmllist
	}
	default {
	    #puts "\t errdetail: [$lib(sasl,token) -operation errdetail]"
	    sasl_final $jlibname error [list sasl-error $output]
	}
    }
}

proc jlib::sasl_failure {jlibname tag xmllist} {
    
    upvar ${jlibname}::locals locals
    variable xmppxmlns

    Debug 2 "jlib::sasl_failure"
    
    if {[wrapper::getattribute $xmllist xmlns] eq $xmppxmlns(sasl)} {
	set errelem [lindex [wrapper::getchildren $xmllist] 0]
	if {$errelem eq ""} {
	    set errmsg "not-authorized"
	} else {
	    set errtag [wrapper::gettag $errelem]
	    set errmsg [sasl_getmsg $errtag]
	}
	sasl_final $jlibname error [list $errtag $errmsg]
    }
    return
}

proc jlib::sasl_success {jlibname tag xmllist} {
    
    upvar ${jlibname}::lib lib

    Debug 2 "jlib::sasl_success"
    
    # Upon receiving a success indication within the SASL negotiation, the
    # client MUST send a new stream header to the server, to which the
    # server MUST respond with a stream header as well as a list of
    # available stream features.  Specifically, if the server requires the
    # client to bind a resource to the stream after successful SASL
    # negotiation, it MUST include an empty <bind/> element qualified by
    # the 'urn:ietf:params:xml:ns:xmpp-bind' namespace in the stream
    # features list it presents to the client upon sending the header for
    # the response stream sent after successful SASL negotiation (but not
    # before):
    
    wrapper::reset $lib(wrap)
    
    # We must clear out any server info we've received so far.
    stream_reset $jlibname
    
    if {[catch {
	sendstream $jlibname -version 1.0
    } err]} {
	sasl_final $jlibname error [list network-failure $err]
	return
    }
	
    # Wait for the resource binding feature (optional) or session (mandantory):
    trace_stream_features $jlibname  \
      [namespace current]::auth_sasl_features_write
    return {}
}

proc jlib::auth_sasl_features_write {jlibname} {
    
    upvar ${jlibname}::locals locals

    if {[have_feature $jlibname bind]} {
	bind_resource $jlibname $locals(resource) \
	  [namespace current]::resource_bind_cb
    } else {
	establish_session $jlibname
    }
}

proc jlib::resource_bind_cb {jlibname type subiq} {
    
    if {$type eq "error"} {
	sasl_final $jlibname error $subiq
    } else {
	establish_session $jlibname
    }
}

proc jlib::establish_session {jlibname} {
    
    variable xmppxmlns
    
    # Establish the session.
    set xmllist [wrapper::createtag session \
      -attrlist [list xmlns $xmppxmlns(session)]]
    send_iq $jlibname set [list $xmllist] -command \
      [list [namespace current]::send_session_cb $jlibname]
}

proc jlib::send_session_cb {jlibname type subiq args} {

    upvar ${jlibname}::locals locals
    
    sasl_final $jlibname $type $subiq
}

proc jlib::sasl_final {jlibname type subiq} {
    
    upvar ${jlibname}::locals locals
    variable xmppxmlns
    
    Debug 2 "jlib::sasl_final"

    # We are no longer interested in these.
    element_deregister $jlibname $xmppxmlns(sasl) [namespace current]::sasl_parse

    uplevel #0 $locals(sasl,cmd) [list $jlibname $type $subiq]
}

proc jlib::sasl_log {args} {
    
    Debug 2 "SASL: $args"
}

proc jlib::sasl_reset {jlibname} {
    
    variable xmppxmlns

    set cmd [trace_stream_features $jlibname]
    if {$cmd eq "[namespace current]::sasl_features"} {
	trace_stream_features $jlibname {}
    }
    element_deregister $jlibname $xmppxmlns(sasl) [namespace current]::sasl_parse
}

namespace eval jlib {
    
    # This maps Defined Conditions to clear text messages.
    # RFC 3920 (XMPP core); 6.4 Defined Conditions
    # Added 'bad-auth' which seems to be a ejabberd anachronism.
    
    variable saslmsg
    array set saslmsg {
    aborted             {The receiving entity acknowledges an abort element sent by the initiating entity.}
    incorrect-encoding  {The data provided by the initiating entity could not be processed because the [BASE64] encoding is incorrect.}
    invalid-authzid     {The authzid provided by the initiating entity is invalid, either because it is incorrectly formatted or because the initiating entity does not have permissions to authorize that ID.}
    invalid-mechanism   {The initiating entity did not provide a mechanism or requested a mechanism that is not supported by the receiving entity.}
    mechanism-too-weak  {The mechanism requested by the initiating entity is weaker than server policy permits for that initiating entity.}
    not-authorized      {The authentication failed because the initiating entity did not provide valid credentials (this includes but is not limited to the case of an unknown username).}
    temporary-auth-failure {The authentication failed because of a temporary error condition within the receiving entity.}
    bad-auth            {The authentication failed because the initiating entity did not provide valid credentials (this includes but is not limited to the case of an unknown username).}
   }
}

proc jlib::sasl_getmsg {condition} {
    variable saslmsg
    
    if {[info exists saslmsg($condition)]} {
	return $saslmsg($condition)
    } else {
	return $condition
    }
}

#-------------------------------------------------------------------------------
