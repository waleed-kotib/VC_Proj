#  jlibsasl.tcl --
#  
#      This file is part of the jabberlib. It provides support for the
#      sasl authentication layer vis the tclsasl package.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: jlibsasl.tcl,v 1.2 2004-09-11 14:21:51 matben Exp $

package require sasl 1.0

package provide jlibsasl 1.0


namespace eval jlib {}


proc jlib::sasl_new {jlibname} {
    
    # Set up callbacks for elements that are of interest to us.
    element_register $jlibname challenge [namespace current]::sasl_challenge
    element_register $jlibname failure   [namespace current]::sasl_failure
    element_register $jlibname success   [namespace current]::sasl_success
}

proc jlib::auth_sasl {jlibname username resource password cmd} {
    
    upvar ${jlibname}::locals locals
    
    puts "jlib::auth_sasl"
        
    # Cache our login jid.
    set locals(username) $username
    set locals(resource) $resource
    set locals(password) $password
    set locals(myjid2)   ${username}@$locals(server)
    set locals(myjid)    ${username}@$locals(server)/${resource}
    set locals(sasl,cmd) $cmd

    if {[info exists locals(features,mechanisms)]} {
	auth_sasl_continue $jlibname
    } else {
	
	# Must be careful so this is not triggered by a reset or something...
	trace add variable ${jlibname}::locals(features,mechanisms) write \
	  [list [namespace current]::auth_sasl_mechanisms_write $jlibname]
    }
}

proc jlib::auth_sasl_mechanisms_write {jlibname name1 name2 op} {
    
    puts "jlib::auth_sasl_mechanisms_write"
    trace remove variable ${jlibname}::locals(features,mechanisms) write \
      [list [namespace current]::auth_sasl_mechanisms_write $jlibname]
    auth_sasl_continue $jlibname
}

proc jlib::auth_sasl_continue {jlibname} {
    
    upvar ${jlibname}::lib lib
    upvar ${jlibname}::locals locals
    variable xmppns

    puts "jlib::auth_sasl_continue"
    
    foreach id {authname pass getrealm cnonce} {
	lappend callbacks [list $id [list [namespace current]::sasl_callback \
	  $jlibname]]
    }
    
    set sasltoken [sasl::client_new \
      -service xmpp -serverFQDN $locals(server) -callbacks $callbacks \
      -flags success_data]
    set lib(sasl,token) $sasltoken
    puts "\t sasl::client_new"
    
    $sasltoken -operation setprop -property sec_props \
      -value {min_ssf 0 max_ssf 0 flags noplaintext}
    puts "\t -operation setprop"
    puts "\t sasl::info sec_flags=[sasl::info sec_flags]"
    puts "\t sasl::mechanisms=[sasl::mechanisms]"
    
    # Returns a serialized array if succesful.
    set code [catch {
	$sasltoken -operation start -mechanisms $locals(features,mechanisms) \
	  -interact [list [namespace current]::sasl_interact $jlibname]
    } ans]
    puts "\t -operation start: code=$code, ans=$ans"
    
    switch -- $code {
	0 {	    
	    # ok
	    array set ansArr $ans
	    set xmllist [wrapper::createtag auth \
	      -attrlist [list xmlns $xmppns(sasl) mechanism $ansArr(mechanism)] \
	      -chdata [sasl::encode64 $ansArr(output)]]
	    send $jlibname $xmllist
	}
	4 {	    
	    # continue
	    array set ansArr $ans
	    set xmllist [wrapper::createtag auth \
	      -attrlist [list xmlns $xmppns(sasl) mechanism $ansArr(mechanism)] \
	      -chdata [sasl::encode64 $ansArr(output)]]
	    send $jlibname $xmllist
	}
	default {
	    # This is an error
	    puts "\t errdetail: [$sasltoken -operation errdetail]"
	    uplevel #0 $locals(sasl,cmd) $jlibname [list error [list unknown $::errorCode]]
	}
    }
}

proc jlib::sasl_interact {jlibname data} {
    
    puts "jlib::sasl_interact"
    # empty
}

proc jlib::sasl_callback {jlibname data} {
    
    upvar ${jlibname}::locals locals

    puts "jlib::sasl_callback data=$data"
    array set arr $data
    
    switch -- $arr(id) {
	authname {
	    set value [encoding convertto utf-8 $locals(username)]
	}
	user {
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

proc jlib::sasl_challenge {jlibname tag xmllist} {
    variable xmppns
    
    puts "jlib::sasl_challenge"
    if {[wrapper::getattribute $xmllist xmlns] == $xmppns(sasl)} {
	sasl_step $jlibname [wrapper::getcdata $xmllist]
    }
    return {}
}

proc jlib::sasl_step {jlibname serverin64} {
    
    upvar ${jlibname}::lib lib
    upvar ${jlibname}::locals locals
    variable xmppns

    puts "jlib::sasl_step"
    set serverin [sasl::decode64 $serverin64]
    puts "\t serverin=$serverin"
    
    # Note that 'step' returns the output if succesful, not a serialized array!
    set code [catch {
	$lib(sasl,token) -operation step -input $serverin \
	  -interact [list [namespace current]::sasl_interact $jlibname]
    } output]
    puts "\t code=$code"
    puts "\t output=$output"
    
    switch -- $code {
	0 {	    
	    # ok
	    set xmllist [wrapper::createtag response \
	      -attrlist [list xmlns $xmppns(sasl)] \
	      -chdata [sasl::encode64 $output]]
	    send $jlibname $xmllist
	}
	4 {	    
	    # continue
	    set xmllist [wrapper::createtag response \
	      -attrlist [list xmlns $xmppns(sasl)] \
	      -chdata [sasl::encode64 $output]]
	    send $jlibname $xmllist
	}
	default {
	    puts "\t errdetail: [$lib(sasl,token) -operation errdetail]"
	    uplevel #0 $locals(sasl,cmd) $jlibname [list error [list unknown $::errorCode]]
	}
    }
}

proc jlib::sasl_failure {jlibname tag xmllist} {
    
    upvar ${jlibname}::locals locals

    puts "jlib::sasl_failure"
    if {[wrapper::getattribute $xmllist xmlns] == $xmppns(sasl)} {
	set errtag [lindex [wrapper::getchildren $xmllist] 0]
	if {$errtag == ""} {
	    set errtag "not-authorized"
	}
	uplevel #0 $locals(sasl,cmd) $jlibname [list error $errtag]
    }
    return {}
}

proc jlib::sasl_success {jlibname tag xmllist} {
    
    upvar ${jlibname}::lib lib
    upvar ${jlibname}::locals locals
    upvar ${jlibname}::opts opts
    variable xmppns

    puts "jlib::sasl_success"
    if {[wrapper::getattribute $xmllist xmlns] != $xmppns(sasl)} {
	return
    }
    
    # xmpp-core sect 6.2:
    # Upon receiving the <success/> element,
    # the initiating entity MUST initiate a new stream by sending an
    # opening XML stream header to the receiving entity (it is not
    # necessary to send a closing </stream> tag first...
    
    wrapper::reset $lib(wrap)
    
    # We must clear out any server info we've received so far.
    # Seems the only info is from the <features/> element.
    # UGLY.
    array unset locals features*
    
    set xml "<stream:stream\
      xmlns='$opts(-streamnamespace)' xmlns:stream='$xmppns(stream)'\
      to='$locals(server)' xml:lang='[getlang]' version='1.0'>"

    eval $lib(transportsend) {$xml}
    
    # Must be careful so this is not triggered by a reset or something...
    trace add variable ${jlibname}::locals(features) write \
      [list [namespace current]::auth_sasl_features_write $jlibname]
    
    return {}
}

proc jlib::auth_sasl_features_write {jlibname name1 name2 op} {
    
    upvar ${jlibname}::locals locals

    puts "jlib::auth_sasl_features_write"
    trace remove variable ${jlibname}::locals(features) write \
      [list [namespace current]::auth_sasl_features_write $jlibname]

    bind_resource $jlibname $locals(resource) \
      [namespace current]::resource_bind_cb
}

proc jlib::resource_bind_cb {jlibname type subiq} {
    
    upvar ${jlibname}::locals locals
    variable xmppns

    puts "jlib::resource_bind_cb type=$type"
    
    switch -- $type {
	error {
	    uplevel #0 $locals(sasl,cmd) [list $jlibname error $subiq]
	}
	default {
	    
	    # Establish the session.
	    set xmllist [wrapper::createtag session \
	      -attrlist [list xmlns $xmppns(session)]]
	    send_iq $jlibname set $xmllist -command \
	      [list [namespace current]::send_session_cb $jlibname]
	}
    }
}

proc jlib::send_session_cb {jlibname type subiq args} {

    upvar ${jlibname}::locals locals

    puts "jlib::send_session_cb type=$type"
    
    switch -- $type {
	error {
	    uplevel #0 $locals(sasl,cmd) [list $jlibname error $subiq]
	}
	default {

	    # We should be finished with authorization, resource binding and
	    # session establishment here. 
	    # Now we are free to send any stanzas.
	    uplevel #0 $locals(sasl,cmd) [list $jlibname $type $subiq]
	}
    }
}

proc jlib::sasl_log {args} {
    
    puts "SASL: $args"
}

proc jlib::sasl_reset {jlibname} {
    
    upvar ${jlibname}::locals locals

    foreach tspec [trace info variable ${jlibname}::locals(features,mechanisms)] {
	foreach {op cmd} $tspec {break}
	trace remove variable ${jlibname}::locals(features,mechanisms) $op $cmd
    }
    foreach tspec [trace info variable ${jlibname}::locals(features)] {
	foreach {op cmd} $tspec {break}
	trace remove variable ${jlibname}::locals(features) $op $cmd
    }
}

#-------------------------------------------------------------------------------
