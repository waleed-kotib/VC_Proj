# jabberlib.tcl --
#
#       This is the main part of the jabber lib, a Tcl library for interacting
#       with jabber servers. The core parts are known under the name XMPP.
#
# Copyright (c) 2001-2007  Mats Bengtsson
# 
# This file is distributed under BSD style license.
#  
# $Id: jabberlib.tcl,v 1.187 2007-09-05 14:23:37 matben Exp $
# 
# Error checking is minimal, and we assume that all clients are to be trusted.
# 
# News: the transport mechanism shall be completely configurable, but where
#       the standard mechanism (put directly to socket) is included here.
#
# Variables used in JabberLib:
# 
# lib:
#	lib(wrap)                  : Wrap ID
#       lib(clientcmd)             : Callback proc up to the client
#	lib(sock)                  : socket name
#	lib(streamcmd)             : Callback command to run when the <stream>
#	                             tag is received from the server.
#
# iqcmd:	                             
#	iqcmd(uid)                 : Next iq id-number. Sent in 
#                                    "id" attributes of <iq> packets.
#	iqcmd($id)                 : Callback command to run when iq result 
#	                             packet of $id is received.
#
# locals:
#       locals(server)             : The servers logical name (streams 'from')
#       locals(username)
#       locals(myjid)
#       locals(myjid2)
#	                               
############################# SCHEMA ###########################################
#
#   TclXML <---> wrapper <---> jabberlib <---> client
#                                 | 
#                             jlib::roster
#                             jlib::disco
#                             jlib::muc
#                               ...
#                               
#   Most jlib-packages are self-registered and are invoked using ensamble (sub)
#   commands.
#
############################# USAGE ############################################
#
#   NAME
#      jabberlib - an interface between Jabber clients and the wrapper
#      
#   SYNOPSIS
#      jlib::new clientCmd ?-opt value ...?
#      jlib::havesasl
#      jlib::havetls
#      
#   OPTIONS
#	-iqcommand            callback for <iq> elements not handled explicitly
#	-messagecommand       callback for <message> elements
#	-presencecommand      callback for <presence> elements
#	-streamnamespace      initialization namespace (D = "jabber:client")
#	-keepalivesecs        send a newline character with this interval
#	-autoawaymins         if > 0 send away message after this many minutes
#	-xautoawaymins        if > 0 send xaway message after this many minutes
#	-awaymsg              the away message 
#	-xawaymsg             the xaway message
#	-autodiscocaps        0|1 should presence caps elements be auto discoed
#	
#   INSTANCE COMMANDS
#      jlibName config ?args?
#      jlibName openstream server ?args?
#      jlibName closestream
#      jlibName element_deregister xmlns func
#      jlibName element_register xmlns func ?seq?
#      jlibName getstreamattr name
#      jlibName get_feature name
#      jlibName get_last to cmd
#      jlibName get_time to cmd
#      jlibName getserver
#      jlibName get_version to cmd
#      jlibName getrecipientjid jid
#      jlibName get_registered_presence_stanzas ?tag? ?xmlns?
#      jlibName iq_get xmlns ?-to, -command, -sublists?
#      jlibName iq_set xmlns ?-to, -command, -sublists?
#      jlibName iq_register type xmlns cmd
#      jlibName message_register xmlns cmd
#      jlibName myjid
#      jlibName mypresence
#      jlibName oob_set to cmd url ?args?
#      jlibName presence_register type cmd
#      jlibName registertransport name initProc sendProc resetProc ipProc
#      jlibName register_set username password cmd ?args?
#      jlibName register_get cmd ?args?
#      jlibName register_presence_stanza elem
#      jlibName register_remove to cmd ?args?
#      jlibName resetstream
#      jlibName schedule_auto_away
#      jlibName search_get to cmd
#      jlibName search_set to cmd ?args?
#      jlibName send_iq type xmldata ?args?
#      jlibName send_message to ?args?
#      jlibName send_presence ?args?
#      jlibName send_auth username resource ?args?
#      jlibName send xmllist
#      jlibName setsockettransport socket
#      jlibName state
#      jlibName transport
#      jlibName deregister_presence_stanza tag xmlns
#      
#      
#   The callbacks given for any of the '-iqcommand', '-messagecommand', 
#   or '-presencecommand' must have the following form:
#   
#      tclProc {jlibname xmldata}
#      
#   where 'type' is the type attribute valid for each specific element, and
#   'args' is a list of '-key value' pairs. The '-iqcommand' returns a boolean
#   telling if any 'get' is handled or not. If not, then a "Not Implemented" is
#   returned automatically.
#                 
#   The clientCmd procedure must have the following form:
#   
#      clientCmd {jlibName what args}
#      
#   where 'what' can be any of: connect, disconnect, xmlerror,
#   version, networkerror, ....
#   'args' is a list of '-key value' pairs.
#      
#   @@@ TODO:
#   
#      1) Rewrite from scratch and deliver complete iq, message, and presence
#      elements to callbacks. Callbacks then get attributes like 'from' etc
#      using accessor functions.
#      
#      2) Cleanup all the presence code.
#      
#-------------------------------------------------------------------------------

# @@@ TODO: change package names to jlib::*

package require wrapper
package require service
package require stanzaerror
package require streamerror
package require groupchat
package require jlib::util

package provide jlib 2.0


namespace eval jlib {
    
    # Globals same for all instances of this jlib.
    #    > 1 prints raw xml I/O
    #    > 2 prints a lot more
    variable debug 0
    if {[info exists ::debugLevel] && ($::debugLevel > 1) && ($debug == 0)} {
	set debug 2
    }
    
    variable statics
    set statics(inited) 0
    set statics(presenceTypeExp)  \
      {(available|unavailable|subscribe|unsubscribe|subscribed|unsubscribed|invisible|probe)}
    set statics(instanceCmds) [list]
    
    variable version 1.0
    
    # Running number.
    variable uid 0
    
    # Let jlib components register themselves for subcommands, ensamble,
    # so that they can be invoked by: jlibname subcommand ...
    variable ensamble
    
    # Some common xmpp xml namespaces.
    variable xmppxmlns
    array set xmppxmlns {
	stream      http://etherx.jabber.org/streams
	streams     urn:ietf:params:xml:ns:xmpp-streams
	tls         urn:ietf:params:xml:ns:xmpp-tls
	sasl        urn:ietf:params:xml:ns:xmpp-sasl
	bind        urn:ietf:params:xml:ns:xmpp-bind
	stanzas     urn:ietf:params:xml:ns:xmpp-stanzas
	session     urn:ietf:params:xml:ns:xmpp-session
    }
    
    variable jxmlns
    array set jxmlns {
	amp             http://jabber.org/protocol/amp
	caps            http://jabber.org/protocol/caps
	compress        http://jabber.org/features/compress 
	disco           http://jabber.org/protocol/disco 
	disco,items     http://jabber.org/protocol/disco#items 
	disco,info      http://jabber.org/protocol/disco#info
	ibb             http://jabber.org/protocol/ibb
	muc             http://jabber.org/protocol/muc
	muc,user        http://jabber.org/protocol/muc#user
	muc,admin       http://jabber.org/protocol/muc#admin
	muc,owner       http://jabber.org/protocol/muc#owner
	pubsub          http://jabber.org/protocol/pubsub
    }
    
    # This is likely to change when XEP accepted.
    set jxmlns(entitytime) "http://www.xmpp.org/extensions/xep-0202.html#ns"
    
    # Auto away and extended away are only set when the
    # current status has a lower priority than away or xa respectively.
    # After an idea by Zbigniew Baniewski.
    variable statusPriority
    array set statusPriority {
	chat            1
	available       2
	away            3
	xa              4
	dnd             5
	invisible       6
	unavailable     7
    }
}

proc jlib::getxmlns {name} {
    variable xmppxmlns
    variable jxmlns
    
    if {[info exists xmppxmlns($name)]} {
	return $xmppxmlns($name)
    } elseif {[info exists xmppxmlns($name)]} {
	return $jxmlns($name)
    } else {
	return -code error "unknown xmlns for $name"
    }
}

# jlib::register_instance --
#     
#       Packages can register here to get notified when a new jlib instance is
#       created.

proc jlib::register_instance {cmd} {
    variable statics
    
    lappend statics(instanceCmds) $cmd
}

# jlib::new --
#
#       This creates a new instance jlib interpreter.
#       
# Arguments:
#       clientcmd:  callback procedure for the client
#       args:       
#	-iqcommand            
#	-messagecommand       
#	-presencecommand      
#	-streamnamespace      
#	-keepalivesecs        
#	-autoawaymins              
#	-xautoawaymins             
#	-awaymsg              
#	-xawaymsg         
#	-autodiscocaps    
#       
# Results:
#       jlibname which is the namespaced instance command
  
proc jlib::new {clientcmd args} {    

    variable jxmlns
    variable statics
    variable objectmap
    variable uid
    variable ensamble
    
    # Generate unique command token for this jlib instance.
    # Fully qualified!
    set jlibname [namespace current]::jlib[incr uid]
      
    # Instance specific namespace.
    namespace eval $jlibname {
	variable lib
	variable locals
	variable iqcmd
	variable iqhook
	variable msghook
	variable preshook
	variable genhook
	variable opts
	variable pres
	variable features
    }
            
    # Set simpler variable names.
    upvar ${jlibname}::lib      lib
    upvar ${jlibname}::iqcmd    iqcmd
    upvar ${jlibname}::prescmd  prescmd
    upvar ${jlibname}::msgcmd   msgcmd
    upvar ${jlibname}::opts     opts
    upvar ${jlibname}::locals   locals
    upvar ${jlibname}::features features
    
    array set opts {
	-iqcommand            ""
	-messagecommand       ""
	-presencecommand      ""
	-streamnamespace      "jabber:client"
	-keepalivesecs        60
	-autoawaymins         0
	-xautoawaymins        0
	-awaymsg              ""
	-xawaymsg             ""
	-autodiscocaps        0
    }
    
    # Verify options.
    eval verify_options $jlibname $args
    
    if {!$statics(inited)} {
	init
    }

    set wrapper [wrapper::new [list [namespace current]::got_stream $jlibname] \
      [list [namespace current]::end_of_parse $jlibname]  \
      [list [namespace current]::dispatcher $jlibname]    \
      [list [namespace current]::xmlerror $jlibname]]
    
    set iqcmd(uid)   1001
    set prescmd(uid) 1001
    set msgcmd(uid)  1001
    set lib(clientcmd)      $clientcmd
    set lib(async_handler)  ""
    set lib(wrap)           $wrapper
    set lib(resetCmds)      [list]
    
    set lib(isinstream) 0
    set lib(state)      ""
    set lib(transport,name) ""

    set lib(socketfilter,out) [list]
    set lib(socketfilter,in)  [list]

    init_inst $jlibname
            
    # Init groupchat state.
    groupchat::init $jlibname
        
    # Register some standard iq handlers that are handled internally.
    iq_register $jlibname get jabber:iq:last    \
      [namespace current]::handle_get_last
    iq_register $jlibname get jabber:iq:time    \
      [namespace current]::handle_get_time
    iq_register $jlibname get jabber:iq:version \
      [namespace current]::handle_get_version

    iq_register $jlibname get $jxmlns(entitytime) \
      [namespace current]::handle_entity_time

    # Create the actual jlib instance procedure.
    proc $jlibname {cmd args}   \
      "eval jlib::cmdproc {$jlibname} \$cmd \$args"
    
    # Init the service layer for this jlib instance.
    service::init $jlibname
    
    # Init ensamble commands.
    foreach {- name} [array get ensamble *,name] {
	uplevel #0 $ensamble($name,init) $jlibname
    }
    
    return $jlibname
}

# jlib::init --
# 
#       Static initializations.

proc jlib::init {} {
    variable statics
    
    if {[catch {package require jlibsasl}]} {
	set statics(sasl) 0
    } else {
	set statics(sasl) 1
	sasl_init
    }
    if {[catch {package require jlibtls}]} {
	set statics(tls) 0
    } else {
	set statics(tls) 1
    }
    
    set statics(inited) 1
}

# jlib::init_inst --
# 
#       Instance specific initializations.

proc jlib::init_inst {jlibname} {

    upvar ${jlibname}::locals   locals
    upvar ${jlibname}::features features
    
    # Any of {available chat away xa dnd invisible unavailable}
    set locals(status)        "unavailable"
    set locals(pres,type)     "unavailable"
    set locals(myjid)         ""
    set locals(myjid2)        ""
    set locals(trigAutoAway)  1
    set locals(server)        ""

    set features(trace) [list]
}

# jlib::havesasl --
# 
#       Cache this info for effectiveness. It is needed at application level.

proc jlib::havesasl { } {
    variable statics
    
    if {![info exists statics(sasl)]} {
	if {[catch {package require jlibsasl}]} {
	    set statics(sasl) 0
	} else {
	    set statics(sasl) 1
	}
    }
    return $statics(sasl)
}

# jlib::havetls --
# 
#       Cache this info for effectiveness. It is needed at application level.

proc jlib::havetls { } {
    variable statics
    
    if {![info exists statics(tls)]} {
	if {[catch {package require jlibtls}]} {
	    set statics(tls) 0
	} else {
	    set statics(tls) 1
	}
    }
    return $statics(tls)
}

# jlib::register_package --
# 
#       This is supposed to be a method for jlib::* packages to register
#       themself just so we know they are there. So far only for the 'roster'.

proc jlib::register_package {name} {
    variable statics
    
    set statics($name) 1
}

# jlib::ensamble_register --
# 
#       Register a sub command.
#       This is then used as: 'jlibName subCmd ...'

proc jlib::ensamble_register {name initProc cmdProc} {
    variable statics
    variable ensamble
    
    set ensamble($name,name) $name
    set ensamble($name,init) $initProc
    set ensamble($name,cmd)  $cmdProc
    
    # Must call the initProc for already existing jlib instances.
    if {$statics(inited)} {
	foreach jlibname [namespace children ::jlib jlib*] {
	    uplevel #0 $initProc $jlibname
	}
    }
}

proc jlib::ensamble_deregister {name} {
    variable ensamble
    
    array unset ensamble ${name},*
}

# jlib::cmdproc --
#
#       Just dispatches the command to the right procedure.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       cmd:        openstream - closestream - send_iq - send_message ... etc.
#       args:       all args to the cmd procedure.
#       
# Results:
#       none.

proc jlib::cmdproc {jlibname cmd args} {
    variable ensamble
    
    # Which command? Just dispatch the command to the right procedure.
    if {[info exists ensamble($cmd,cmd)]} {
	return [uplevel #0 $ensamble($cmd,cmd) $jlibname $args]
    } else {
	return [eval {$cmd $jlibname} $args]
    }
}

# jlib::config --
#
#	See documentaion for details.
#
# Arguments:
#	args		Options parsed by the procedure.
#	
# Results:
#       depending on args.

proc jlib::config {jlibname args} {    
    variable ensamble
    upvar ${jlibname}::opts opts
    
    set options [lsort [array names opts -*]]
    set usage [join $options ", "]
    if {[llength $args] == 0} {
	set result [list]
	foreach name $options {
	    lappend result $name $opts($name)
	}
	return $result
    }
    regsub -all -- - $options {} options
    set pat ^-([join $options |])$
    if {[llength $args] == 1} {
	set flag [lindex $args 0]
	if {[regexp -- $pat $flag]} {
	    return $opts($flag)
	} else {
	    return -code error "Unknown option $flag, must be: $usage"
	}
    } else {
	array set argsA $args
	
	# Reschedule auto away only if changed. Before setting new opts!
	# Better to use 'tk inactive' or 'tkinactive' and handle this on
	# application level.
	if {[info exists argsA(-autoawaymins)] &&  \
	  ($argsA(-autoawaymins) != $opts(-autoawaymins))} {
	    schedule_auto_away $jlibname
	}
	if {[info exists argsA(-xautoawaymins)] &&  \
	  ($argsA(-xautoawaymins) != $opts(-xautoawaymins))} {
	    schedule_auto_away $jlibname
	}
	foreach {flag value} $args {
	    if {[regexp -- $pat $flag]} {
		set opts($flag) $value		
	    } else {
		return -code error "Unknown option $flag, must be: $usage"
	    }
	}
    }
    
    # Let components configure themselves.
    # @@@ It is better to let components handle this???
    foreach ename [array names ensamble] {
	set ecmd ${ename}::configure
	if {[llength [info commands $ecmd]]} {
	    #uplevel #0 $ecmd $jlibname $args
	}
    }

    return
}

# jlib::verify_options
#
#	Check if valid options and set them.
#
# Arguments
# 
#	args    The argument list given on the call.
#
# Side Effects
#	Sets error

proc jlib::verify_options {jlibname args} {    

    upvar ${jlibname}::opts opts
    
    set validopts [array names opts]
    set usage [join $validopts ", "]
    regsub -all -- - $validopts {} theopts
    set pat ^-([join $theopts |])$
    foreach {flag value} $args {
	if {[regexp $pat $flag]} {
	    
	    # Validate numbers
	    if {[info exists opts($flag)] && \
	      [string is integer -strict $opts($flag)] && \
	      ![string is integer -strict $value]} {
		return -code error "Bad value for $flag ($value), must be integer"
	    }
	    set opts($flag) $value
	} else {
	    return -code error "Unknown option $flag, can be: $usage"
	}
    }
}

# jlib::state --
# 
#       Accesor for the internal 'state'.

proc jlib::state {jlibname} {
    
    upvar ${jlibname}::lib lib
    
    return $lib(state)
}

# jlib::register_reset --
# 
#       Packages can register here to get notified when the jlib stream is reset.

proc jlib::register_reset {jlibname cmd} {
    
    upvar ${jlibname}::lib lib
    
    lappend lib(resetCmds) $cmd
}

# jlib::registertransport --
# 
#       We must have a transport mechanism for our xml. Socket is standard but
#       http is also possible.

proc jlib::registertransport {jlibname name initProc sendProc resetProc ipProc} {
    
    upvar ${jlibname}::lib lib

    set lib(transport,name)  $name
    set lib(transport,init)  $initProc
    set lib(transport,send)  $sendProc
    set lib(transport,reset) $resetProc
    set lib(transport,ip)    $ipProc
}

proc jlib::transport {jlibname} {
    
    upvar ${jlibname}::lib lib

    return $lib(transport,name)
}

# jlib::setsockettransport --
# 
#       Sets the standard socket transport and the actual socket to use.

proc jlib::setsockettransport {jlibname sock} {
    
    upvar ${jlibname}::lib lib
    
    # Settings for the raw socket transport layer.
    set lib(sock) $sock
    set lib(transport,name)  "socket"
    set lib(transport,init)  [namespace current]::initsocket
    set lib(transport,send)  [namespace current]::putssocket
    set lib(transport,reset) [namespace current]::resetsocket
    set lib(transport,ip)    [namespace current]::ipsocket
}

# The procedures for the standard socket transport layer -----------------------

# jlib::initsocket
#
#	Default transport mechanism; init already opened socket.
#
# Arguments:
# 
# Side Effects:
#	none

proc jlib::initsocket {jlibname} {

    upvar ${jlibname}::lib lib
    upvar ${jlibname}::opts opts

    set sock $lib(sock)
    if {[catch {
	fconfigure $sock -blocking 0 -buffering none -encoding utf-8
    } err]} {
	return -code error "The connection failed or dropped later"
    }
     
    # Set up callback on incoming socket.
    fileevent $sock readable [list [namespace current]::recvsocket $jlibname]

    # Schedule keep-alives to keep socket open in case anyone want's to close it.
    # Be sure to not send any keep-alives before the stream is inited.
    if {$opts(-keepalivesecs)} {
	after [expr 1000 * $opts(-keepalivesecs)] \
	  [list [namespace current]::schedule_keepalive $jlibname]
    }
}

# jlib::putssocket
#
#	Default transport mechanism; put directly to socket.
#
# Arguments:
# 
#	xml    The xml that is to be written.
#
# Side Effects:
#	none

proc jlib::putssocket {jlibname xml} {

    upvar ${jlibname}::lib lib

    Debug 2 "SEND: $xml"

    if {$lib(socketfilter,out) ne {}} {
	set xml [$lib(socketfilter,out) $jlibname $xml]
    }
    if {[catch {puts -nonewline $lib(sock) $xml} err]} {
	# Error propagated to the caller that calls clientcmd.
	return -code error $err
    }
}

# jlib::resetsocket
#
#	Default transport mechanism; reset socket.
#
# Arguments:
# 
# Side Effects:
#	none

proc jlib::resetsocket {jlibname} {

    upvar ${jlibname}::lib lib
    upvar ${jlibname}::locals locals

    catch {close $lib(sock)}
    catch {after cancel $locals(aliveid)}

    set lib(socketfilter,out) [list]
    set lib(socketfilter,in)  [list]
}

# jlib::recvsocket --
#
#	Default transport mechanism; fileevent on socket socket.
#       Callback on incoming socket xml data. Feeds our wrapper and XML parser.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       
# Results:
#       none.

proc jlib::recvsocket {jlibname} {

    upvar ${jlibname}::lib lib
    
    if {[catch {eof $lib(sock)} iseof] || $iseof} {
	kill $jlibname
	invoke_async_error $jlibname networkerror
	return
    }
    
    # Read what we've got.
    if {[catch {read $lib(sock)} data]} {
	kill $jlibname
	invoke_async_error $jlibname networkerror
	return
    }
    if {$lib(socketfilter,in) ne {}} {
	set data [$lib(socketfilter,in) $jlibname $data]
    }
    Debug 2 "RECV: $data"
    
    # Feed the XML parser. When the end of a command element tag is reached,
    # we get a callback to 'jlib::dispatcher'.
    wrapper::parse $lib(wrap) $data
}

proc jlib::set_socket_filter {jlibname outcmd incmd} {
    
    upvar ${jlibname}::lib lib

    set lib(socketfilter,out) $outcmd
    set lib(socketfilter,in)  $incmd

    fconfigure $lib(sock) -translation binary
}

# jlib::ipsocket --
# 
#       Get our own ip address.

proc jlib::ipsocket {jlibname} {
    
    upvar ${jlibname}::lib lib
    
    if {[string length $lib(sock)]} {
	return [lindex [fconfigure $lib(sock) -sockname] 0]
    } else {
	return ""
    }
}

# standard socket transport layer end ------------------------------------------

# jlib::recv --
#
# 	Feed the XML parser. When the end of a command element tag is reached,
# 	we get a callback to 'jlib::dispatcher'.

proc jlib::recv {jlibname xml} {

    upvar ${jlibname}::lib lib

    wrapper::parse $lib(wrap) $xml
}

# jlib::openstream --
#
#       Initializes a stream to a jabber server. The socket must already 
#       be opened. Sets up fileevent on incoming xml stream.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       server:     the domain name or ip number of the server.
#       args:
#           -cmd    callback when we receive the <stream> tag from the server.
#           -to     the receipients jabber id.
#           -id
#           -version
#       
# Results:
#       none.

proc jlib::openstream {jlibname server args} {    

    upvar ${jlibname}::lib lib
    upvar ${jlibname}::locals locals
    upvar ${jlibname}::opts opts
    variable xmppxmlns

    array set argsA $args
    
    # The server 'to' attribute is only temporary until we have either a 
    # confirmation or a redirection (alias) in received streams 'from' attribute.
    set locals(server) $server
    set locals(last) [clock seconds]
    
    # Make sure we start with a clean state.
    wrapper::reset $lib(wrap)

    set optattr ""
    foreach {key value} $args {
	
	switch -- $key {
	    -cmd {
		if {$value ne ""} {
		    # Register a <stream> callback proc.
		    set lib(streamcmd) $value
		}
	    }
	    -socket {
		# empty
	    }
	    default {
		set attr [string trimleft $key "-"]
		append optattr " $attr='$value'"
	    }
	}
    }
    set lib(isinstream) 1
    set lib(state) "instream"

    if {[catch {

	# This call to the transport layer shall set up fileevent callbacks etc.
   	# to handle all incoming xml.
	uplevel #0 $lib(transport,init) $jlibname
        
    	# Network errors if failed to open connection properly are likely to show here.
	set xml "<?xml version='1.0' encoding='UTF-8'?><stream:stream\
	  xmlns='$opts(-streamnamespace)' xmlns:stream='$xmppxmlns(stream)'\
	  xml:lang='[getlang]' to='$server'$optattr>"

	sendraw $jlibname $xml
    } err]} {
	
	# The socket probably was never connected,
	# or the connection dropped later.
	#closestream $jlibname
	kill $jlibname
	return -code error "The connection failed or dropped later: $err"
    }
    return
}

# jlib::sendstream --
# 
#       Utility for SASL, TLS etc. Sends only the actual stream:stream tag.
#       May throw error!

proc jlib::sendstream {jlibname args} {
    
    upvar ${jlibname}::locals locals
    upvar ${jlibname}::opts opts
    variable xmppxmlns
    
    set attr ""
    foreach {key value} $args {
	set name [string trimleft $key "-"]
	append attr " $name='$value'"
    }
    set xml "<stream:stream\
      xmlns='$opts(-streamnamespace)' xmlns:stream='$xmppxmlns(stream)'\
      to='$locals(server)' xml:lang='[getlang]' $attr>"
   
    sendraw $jlibname $xml
}

# jlib::closestream --
#
#       Closes the stream down, closes socket, and resets internal variables.
#       It should handle the complete shutdown of our connection and state.
#       
#       There is a potential problem if called from within a xml parser 
#       callback which makes the subsequent parsing to fail. (after idle?)
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       
# Results:
#       none.

proc jlib::closestream {jlibname} {    

    upvar ${jlibname}::lib lib

    Debug 4 "jlib::closestream"
    
    if {$lib(isinstream)} {
	set xml "</stream:stream>"
	catch {sendraw $jlibname $xml}
	set lib(isinstream) 0
    }
    kill $jlibname
}

# jlib::invoke_async_error --
# 
#       Used for reporting async errors, typically network errors.

proc jlib::invoke_async_error {jlibname err {msg ""}} {
    
    upvar ${jlibname}::lib lib
    Debug 4 "jlib::invoke_async_error err=$err, msg=$msg"
    
    if {$lib(async_handler) eq ""} {
	uplevel #0 $lib(clientcmd) [list $jlibname $err -errormsg $msg]
    } else {
	uplevel #0 $lib(async_handler) [list $jlibname $err $msg]
    }
}

# jlib::set_async_error_handler --
# 
#       This is a way to get all async events directly to a registered handler
#       without delivering them to clientcmd. Used in jlib::connect.
proc jlib::set_async_error_handler {jlibname {cmd ""}} {
    
    upvar ${jlibname}::lib lib

    set lib(async_handler) $cmd
}

# jlib::reporterror --
# 
#       Used for transports to report async, fatal and nonrecoverable errors.

proc jlib::reporterror {jlibname err {msg ""}} {
    
    Debug 4 "jlib::reporterror"

    kill $jlibname
    invoke_async_error $jlibname $err $msg
}

# jlib::kill --
# 
#       Like closestream but without any network transactions.

proc jlib::kill {jlibname} {
    
    upvar ${jlibname}::lib lib
    
    Debug 4 "jlib::kill"

    # Close socket typically.
    catch {uplevel #0 $lib(transport,reset) $jlibname}
    reset $jlibname
    
    # Be sure to reset the wrapper, which implicitly resets the XML parser.
    wrapper::reset $lib(wrap)
    return
}

proc jlib::wrapper_reset {jlibname} {
    
    upvar ${jlibname}::lib lib

    wrapper::reset $lib(wrap)
}

# jlib::getip --
# 
#       Transport independent way of getting own ip address.

proc jlib::getip {jlibname} {
    
    upvar ${jlibname}::lib lib

    return [$lib(transport,ip) $jlibname]
}

# jlib::getserver --
# 
#       Is the received streams 'from' attribute which is the logical host.
#       This is normally identical to the 'to' attribute but not always.

proc jlib::getserver {jlibname} {
    
    upvar ${jlibname}::locals locals 

    return $locals(server)
}

# jlib::isinstream --
# 
#       Utility to help us closing down a stream.

proc jlib::isinstream {jlibname} {
    
    upvar ${jlibname}::lib lib

    return $lib(isinstream)
}

# jlib::dispatcher --
#
#       Just dispatches the xml to any of the iq, message, or presence handlers,
#       which in turn dispatches further and/or handles internally.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       xmldata:    the complete xml as a hierarchical list.
#       
# Results:
#       none.

proc jlib::dispatcher {jlibname xmldata} {

    # Which method?
    set tag [wrapper::gettag $xmldata]
    
    switch -- $tag {
	iq {
	    iq_handler $jlibname $xmldata
	}
	message {
	    message_handler $jlibname $xmldata	    
	}
	presence {
	    presence_handler $jlibname $xmldata	
	}
	features {
	    features_handler $jlibname $xmldata
	}
	error {
	    error_handler $jlibname $xmldata
	}
	default {
	    element_run_hook $jlibname $xmldata
	}
    }
    # Will have to wait...
    #general_run_hook $jlibname $xmldata
}

# jlib::iq_handler --
#
#       Callback for incoming <iq> elements.
#       The handling sequence is the following:
#       1) handle all preregistered callbacks via id attributes
#       2) handle callbacks specific for 'type' and 'xmlns' that have been
#          registered with 'iq_register'
#       3) if unhandled by 2, use any -iqcommand callback
#       4) if type='get' and still unhandled, return an error element
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#	xmldata     the xml element as a list structure.
#	
# Results:
#       roster object set, callbacks invoked.

proc jlib::iq_handler {jlibname xmldata} {    

    upvar ${jlibname}::lib    lib
    upvar ${jlibname}::iqcmd  iqcmd
    upvar ${jlibname}::opts   opts    
    upvar ${jlibname}::locals locals 
    variable xmppxmlns

    Debug 4 "jlib::iq_handler: ------------"

    # Extract the command level XML data items.    
    set tag [wrapper::gettag $xmldata]
    array set attrArr [wrapper::getattrlist $xmldata]
    
    # Make an argument list ('-key value' pairs) suitable for callbacks.
    # Make variables of the attributes.
    set arglist [list]
    foreach {key value} [array get attrArr] {
	set $key $value
	lappend arglist -$key $value
    }
    
    # This helps callbacks to adapt to using full element as argument.
    lappend arglist -xmldata $xmldata
    
    # The 'type' attribute must exist! Else we return silently.
    if {![info exists type]} {	
	return
    }
    if {[info exists from]} {
	set afrom $from
    } else {
	set afrom $locals(server)
    }
    
    # @@@ Section 9.2.3 of RFC 3920 states in part:
    # 6. An IQ stanza of type "result" MUST include zero or one child elements.
    # 7. An IQ stanza of type "error" SHOULD include the child element 
    # contained in the associated "get" or "set" and MUST include an <error/> 
    # child....
    
    set childlist [wrapper::getchildren $xmldata]
    set subiq [lindex $childlist 0]
    set xmlns [wrapper::getattribute $subiq xmlns]
    
    set ishandled 0
    
    # (1) Handle all preregistered callbacks via id attributes.
    #     Must be type 'result' or 'error'.
    #     Some components use type='set' instead of 'result'.
    #     BUT this creates logical errors since we may also receive iq with
    #     identical id!

    # @@@ It would be better NOT to have separate calls for errors.
    
    switch -- $type {
	result {
	    
	    # Protect us from our own 'set' calls when we are awaiting 
	    # 'result' or 'error'.
	    set setus 0
	    if {[string equal $type "set"]  \
	      && [string equal $afrom $locals(myjid)]} {
		set setus 1
	    }

	    if {!$setus && [info exists id] && [info exists iqcmd($id)]} {
		uplevel #0 $iqcmd($id) [list result $subiq]
		      
		# @@@ TODO:
		#uplevel #0 $iqcmd($id) [list $jlibname xmldata]
		
		# The callback my in turn call 'closestream' which unsets 
		# all iq before returning.
		unset -nocomplain iqcmd($id)
		set ishandled 1
	    }
	}
	error {
	    set errspec [getstanzaerrorspec $xmldata]
	    if {[info exists id] && [info exists iqcmd($id)]} {
		
		# @@@ Having a separate form of error callbacks is really BAD!!!
		uplevel #0 $iqcmd($id) [list error $errspec]
		
		#uplevel #0 $iqcmd($id) [list $jlibname $xmldata]
		
		unset -nocomplain iqcmd($id)
		set ishandled 1
	    }	    
	}
    }
	        
    # (2) Handle callbacks specific for 'type' and 'xmlns' that have been
    #     registered with 'iq_register'

    if {[string equal $ishandled "0"]} {
	set ishandled [eval {
	    iq_run_hook $jlibname $type $xmlns $afrom $subiq} $arglist]
    }
    
    # (3) If unhandled by 2, use any -iqcommand callback.

    if {[string equal $ishandled "0"]} {	
	if {[string length $opts(-iqcommand)]} {
	    set ishandled [uplevel #0 $opts(-iqcommand) [list $jlibname $xmldata]]
	} 
	    
	# (4) If type='get' or 'set', and still unhandled, return an error element.

	if {[string equal $ishandled "0"] && \
	  ([string equal $type "get"] || [string equal $type "set"])} {
	    
	    # Return a "Not Implemented" to the sender. Just switch to/from,
	    # type='result', and add an <error> element.
	    if {[info exists attrArr(from)]} {
		return_error $jlibname $xmldata 501 cancel "feature-not-implemented"
	    }
	}
    }
}

# jlib::return_error --
# 
#       Returns an iq-error response using complete iq-element.

proc jlib::return_error {jlibname iqElem errcode errtype errtag} {
    variable xmppxmlns
    
    array set attr [wrapper::getattrlist $iqElem]
    set childlist  [wrapper::getchildren $iqElem]
    
    # Switch from -> to, type='error', retain any id.
    set attr(to)   $attr(from)
    set attr(type) "error"
    unset attr(from)

    set iqElem [wrapper::setattrlist $iqElem [array get attr]]    
    set stanzaElem [wrapper::createtag $errtag \
      -attrlist [list xmlns $xmppxmlns(stanzas)]]
    set errElem [wrapper::createtag "error" -subtags [list $stanzaElem] \
      -attrlist [list code $errcode type $errtype]]
    
    lappend childlist $errElem
    set iqElem [wrapper::setchildlist $iqElem $childlist]

    send $jlibname $iqElem
}

# jlib::send_iq_error --
# 
#       Sends an iq error element as a response to a iq element.

proc jlib::send_iq_error {jlibname jid id errcode errtype stanza {extraElem {}}} {
    variable xmppxmlns
 
    set stanzaElem [wrapper::createtag $stanza  \
      -attrlist [list xmlns $xmppxmlns(stanzas)]]
    set errChilds [list $stanzaElem]
    if {[llength $extraElem]} {
	lappend errChilds $extraElem
    }
    set errElem [wrapper::createtag "error"         \
      -attrlist [list code $errcode type $errtype]  \
      -subtags $errChilds]
    set iqElem [wrapper::createtag "iq"  \
      -attrlist [list type error to $jid id $id] -subtags [list $errElem]]

    send $jlibname $iqElem
}

# jlib::message_handler --
#
#       Callback for incoming <message> elements. See 'jlib::dispatcher'.
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#	xmldata     the xml element as a list structure.
#	
# Results:
#       callbacks invoked.

proc jlib::message_handler {jlibname xmldata} {    

    upvar ${jlibname}::opts opts    
    upvar ${jlibname}::lib lib
    upvar ${jlibname}::msgcmd msgcmd
    
    # Extract the command level XML data items.
    set attrlist  [wrapper::getattrlist $xmldata]
    set childlist [wrapper::getchildren $xmldata]
    set attrArr(type) "normal"
    array set attrArr $attrlist
    set type $attrArr(type)
    
    # Make an argument list ('-key value' pairs) suitable for callbacks.
    # Make variables of the attributes.
    foreach {key value} [array get attrArr] {
	set vopts(-$key) $value
    }
    
    # This helps callbacks to adapt to using full element as argument.
    set vopts(-xmldata) $xmldata
    set ishandled 0
    
    switch -- $type {
	error {
	    set errspec [getstanzaerrorspec $xmldata]
	    set vopts(-error) $errspec
	}
    }
   
    # Extract the message sub-elements.
    # @@@ really bad solution... Deliver full element instead
    set xmlnsList  [list]
    foreach child $childlist {
	
	# Extract the message sub-elements XML data items.
	set ctag    [wrapper::gettag $child]
	set cchdata [wrapper::getcdata $child]
	
	switch -- $ctag {
	    body - subject - thread {
		set vopts(-$ctag) $cchdata
	    }
	    error {
		# handled above
	    }
	    default {
		lappend elem(-$ctag) $child
		lappend xmlnsList [wrapper::getattribute $child xmlns]
	    }
	}
    }
    set xmlnsList [lsort -unique $xmlnsList]	
    set arglist [array get vopts]
    
    # Invoke any registered handler for this particular message.
    set iscallback 0
    if {[info exists attrArr(id)]} {
	set id $attrArr(id)
	
	# Avoid the weird situation when we send to ourself.
	if {[info exists msgcmd($id)] && ![info exists msgcmd($id,self)]} {
	    uplevel #0 $msgcmd($id) [list $jlibname $type] $arglist
	    unset -nocomplain msgcmd($id)
	    set iscallback 1
	}
	unset -nocomplain msgcmd($id,self)
    }	

    # Invoke any registered message handlers for this type and xmlns.
    if {[array exists elem]} {
	set arglist [concat [array get vopts] [array get elem]]
	foreach xmlns $xmlnsList {
	    set ishandled [eval {
		message_run_hook $jlibname $type $xmlns $xmldata} $arglist]
	    if {$ishandled} {
		break
	    }
	}
    }
    if {!$iscallback && [string equal $ishandled "0"]} {
    
	# Invoke callback to client.
	if {[string length $opts(-messagecommand)]} {
	    uplevel #0 $opts(-messagecommand) [list $jlibname $xmldata]
	}
    }
}

# jlib::send_message_error --
# 
#       Sends a message error element as a response to another message.

proc jlib::send_message_error {jlibname jid id errcode errtype stanza {extraElem {}}} {
    variable xmppxmlns
 
    set stanzaElem [wrapper::createtag $stanza  \
      -attrlist [list xmlns $xmppxmlns(stanzas)]]
    set errChilds [list $stanzaElem]
    if {[llength $extraElem]} {
	lappend errChilds $extraElem
    }
    set errElem [wrapper::createtag "error"         \
      -attrlist [list code $errcode type $errtype]  \
      -subtags $errChilds]
    set msgElem [wrapper::createtag "iq"  \
      -attrlist [list type error to $jid id $id]  \
      -subtags [list $errElem]]

    send $jlibname $msgElem
}

# jlib::presence_handler --
#
#       Callback for incoming <presence> elements. See 'jlib::dispatcher'.
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#	xmldata     the xml element as a list structure.
#	
# Results:
#       roster object set, callbacks invoked.

proc jlib::presence_handler {jlibname xmldata} { 
    variable statics
    upvar ${jlibname}::lib lib
    upvar ${jlibname}::prescmd prescmd
    upvar ${jlibname}::opts opts
    upvar ${jlibname}::locals locals
    
    set id [wrapper::getattribute $xmldata id]
    
    # Handle callbacks specific for 'type' that have been registered with 
    # 'presence_register(_ex)'.
    
    # We keep two sets of registered handlers, jlib internal which are
    # called first, and then externals which are used by the client.

    # Internals:
    presence_run_hook $jlibname 1 $xmldata
    presence_ex_run_hook $jlibname 1 $xmldata
    
    # Externals:
    presence_run_hook $jlibname 0 $xmldata
    presence_ex_run_hook $jlibname 0 $xmldata

    # Invoke any callback before the rosters callback.
    # @@@ Right place ???
    if {[info exists prescmd($id)]} {
	uplevel #0 $prescmd($id) [list $jlibname $xmldata]
	unset -nocomplain prescmd($id)
    }	
    
    # This is the last station.
    if {[string length $opts(-presencecommand)]} {
	uplevel #0 $opts(-presencecommand) [list $jlibname $xmldata]
    }
}

# jlib::features_handler --
# 
#       Callback for the <stream:features> element.

proc jlib::features_handler {jlibname xmllist} {

    upvar ${jlibname}::features features
    variable xmppxmlns
    variable jxmlns
    
    Debug 4 "jlib::features_handler"

    set features(xmllist) $xmllist

    foreach child [wrapper::getchildren $xmllist] {
	wrapper::splitxml $child tag attr chdata children
	set xmlns [wrapper::getattribute $child xmlns]
	
	# All feature elements must be namespaced.
	if {$xmlns eq ""} {
	    continue
	}
	set features(elem,$xmlns) $child
		
	switch -- $tag {
	    starttls {
		
		# TLS
		if {$xmlns eq $xmppxmlns(tls)} {
		    set features(starttls) 1
		    set childs [wrapper::getchildswithtag $child required]
		    if {$childs ne ""} {
			set features(starttls,required) 1
		    }
		}
	    }
	    compression {
		
		# Compress
		if {$xmlns eq $jxmlns(compress)} {
		    set features(compression) 1
		    foreach c [wrapper::getchildswithtag $child method] {
			set method [wrapper::getcdata $c]
			set features(compression,$method) 1
		    }
		}
	    }
	    mechanisms {
		
		# SASL
		set mechanisms [list]
		if {$xmlns eq $xmppxmlns(sasl)} {
		    set features(sasl) 1
		    foreach mechelem $children {
			wrapper::splitxml $mechelem mtag mattr mchdata mchild
			if {$mtag eq "mechanism"} {
			    lappend mechanisms $mchdata
			}
			set features(mechanism,$mchdata) 1
		    }
		}

		# Variable that may trigger a trace event.
		set features(mechanisms) $mechanisms
	    }
	    bind {
		if {$xmlns eq $xmppxmlns(bind)} {
		    set features(bind) 1
		}
	    }
	    session {
		if {$xmlns eq $xmppxmlns(session)} {
		    set features(session) 1
		}
	    }
	    default {
		
		# Have no idea of what this could be.
		set features($xmlns) 1
	    }
	}
    }
        
    if {$features(trace) ne {}} {
	uplevel #0 $features(trace) [list $jlibname]
    }
}

# jlib::trace_stream_features --
# 
#       Register a callback when getting stream features.
#       Only one component at a time.
#       
#       args:     tclProc  set callback
#                 {}       unset callback
#                 empty    return callback

proc jlib::trace_stream_features {jlibname args} {
    
    upvar ${jlibname}::features features
    
    switch -- [llength $args] {
	0 {
	    return $features(trace)
	}
	1 {
	    set features(trace) [lindex $args 0]
	}
	default {
	    return -code error "Usage: trace_stream_features ?tclProc?"
	}
    }
}

# jlib::get_feature, have_feature --
# 
#       Just to get access of the stream features.

proc jlib::get_feature {jlibname name {name2 ""}} {
    
    upvar ${jlibname}::features features

    set ans ""
    if {$name2 ne ""} {
	if {[info exists features($name,$name2)]} {
	    set ans $features($name,$name2)
	}
    } else {
	if {[info exists features($name)]} {
	    set ans $features($name)
	}
    }
    return $ans
}

proc jlib::have_feature {jlibname {name ""} {name2 ""}} {
    
    upvar ${jlibname}::features features
    
    set ans 0
    if {$name2 ne ""} {
	if {[info exists features($name,$name2)]} {
	    set ans 1
	}
    } elseif {$name ne ""} {
	if {[info exists features($name)]} {
	    set ans 1
	}
    } else {
	if {[info exists features(xmllist)]} {
	    set ans 1
	}
    }
    return $ans
}

# jlib::got_stream --
#
#       Callback when we have parsed the initial root element.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       args:       attributes
#       
# Results:
#       none.

proc jlib::got_stream {jlibname args} {

    upvar ${jlibname}::lib lib
    upvar ${jlibname}::locals locals

    Debug 4 "jlib::got_stream jlibname=$jlibname, args='$args'"
    
    # Cache stream attributes.
    foreach {name value} $args {
	set locals(streamattr,$name) $value
    }
    
    # The streams 'from' attribute has the "last word" on the servers name.
    if {[info exists locals(streamattr,from)]} {
	set locals(server) $locals(streamattr,from)
    }
    schedule_auto_away $jlibname
    
    # If we use    we should have a callback command here.
    if {[info exists lib(streamcmd)] && [llength $lib(streamcmd)]} {
	uplevel #0 $lib(streamcmd) $jlibname $args
	unset lib(streamcmd)
    }
}

# jlib::getthis --
# 
#       Access function for: server, username, myjid, myjid2...

proc jlib::getthis {jlibname name} {
    
    upvar ${jlibname}::locals locals
    
    if {[info exists locals($name)]} {
	return $locals($name)
    } else {
	return
    }
}

# jlib::getstreamattr --
# 
#       Returns the value of any stream attribute, typically 'id'.

proc jlib::getstreamattr {jlibname name} {
    
    upvar ${jlibname}::locals locals
    
    if {[info exists locals(streamattr,$name)]} {
	return $locals(streamattr,$name)
    } else {
	return
    }
}

# jlib::end_of_parse --
#
#       Callback when the ending root element is parsed.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       
# Results:
#       none.

proc jlib::end_of_parse {jlibname} {

    upvar ${jlibname}::lib lib

    Debug 4 "jlib::end_of_parse jlibname=$jlibname"
    
    catch {eval $lib(transport,reset) $jlibname}
    invoke_async_error $jlibname disconnect
    reset $jlibname
}

# jlib::error_handler --
# 
#       Callback when receiving an stream:error element. According to xmpp-core
#       this is an unrecoverable error (4.7.1) and the stream MUST be closed
#       and the TCP connection also be closed.
#       
#       jabberd 1.4.3: <stream:error>Disconnected</stream:error>
#       jabberd 1.4.4: 
#       <stream:error>
#           <xml-not-well-formed xmlns='urn:ietf:params:xml:ns:xmpp-streams'/>
#       </stream:error>
#   </stream:stream>

proc jlib::error_handler {jlibname xmllist} {

    variable xmppxmlns
    
    Debug 4 "jlib::error_handler"
    
    # This should handle all internal stuff.
    closestream $jlibname
    
    if {[llength [wrapper::getchildren $xmllist]]} {
	set errspec [getstreamerrorspec $xmllist]
	set errcode "xmpp-streams-error-[lindex $errspec 0]"
	set errmsg [lindex $errspec 1]
    } else {
	set errcode xmpp-streams-error
	set errmsg [wrapper::getcdata $xmllist]
    }
    invoke_async_error $jlibname $errcode $errmsg
}

# jlib::xmlerror --
#
#       Callback when we receive an XML error from the wrapper (parser).
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       
# Results:
#       none.

proc jlib::xmlerror {jlibname args} {

    Debug 4 "jlib::xmlerror jlibname=$jlibname, args='$args'"
    
    # This should handle all internal stuff.
    closestream $jlibname
    invoke_async_error $jlibname xmlerror $args
}

# jlib::reset --
#
#       Unsets all iqcmd($id) callback procedures.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       
# Results:
#       none.

proc jlib::reset {jlibname} {

    upvar ${jlibname}::lib lib
    upvar ${jlibname}::iqcmd iqcmd
    upvar ${jlibname}::prescmd prescmd
    upvar ${jlibname}::locals locals
    upvar ${jlibname}::features features
    
    Debug 4 "jlib::reset"
    
    cancel_auto_away $jlibname
    
    set num $iqcmd(uid)
    unset -nocomplain iqcmd
    set iqcmd(uid) $num
    
    set num $prescmd(uid)
    unset -nocomplain prescmd
    set prescmd(uid) $num
    
    unset -nocomplain locals
    unset -nocomplain features
    
    init_inst $jlibname

    set lib(isinstream) 0
    set lib(state) "reset"

    stream_reset $jlibname
    if {[havesasl]} {
	sasl_reset $jlibname
    }
    if {[havetls]} {
	tls_reset $jlibname
    }
        
    # Execute any register reset commands.
    foreach cmd $lib(resetCmds) {
	uplevel #0 $cmd $jlibname
    }
}

# jlib::stream_reset --
# 
#       Clears out all variables that are cached for this stream.
#       The xmpp specifies that any information obtained during tls,sasl
#       must be discarded before opening a new stream.
#       Call this before opening a new stream

proc jlib::stream_reset {jlibname} {
    
    upvar ${jlibname}::locals locals
    upvar ${jlibname}::features features
    
    array unset locals streamattr,*
    
    set cmd $features(trace)
    unset -nocomplain features
    set features(trace) $cmd
}

# jlib::getstanzaerrorspec --
# 
#       Extracts the error code and an error message from an type='error'
#       element. We must handle both the original Jabber protocol and the
#       XMPP protocol:
#
#   The syntax for stanza-related errors is as follows (XMPP):
#
#   <stanza-kind to='sender' type='error'>
#     [RECOMMENDED to include sender XML here]
#     <error type='error-type'>
#       <defined-condition xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'/>
#       <text xmlns='urn:ietf:params:xml:ns:xmpp-stanzas'>
#         OPTIONAL descriptive text
#       </text>
#       [OPTIONAL application-specific condition element]
#     </error>
#   </stanza-kind>
#   
#   Jabber:
#   
#   <iq type='error'>
#     <query ...>
#       <error code='..'> ... </error>
#     </query>
#   </iq>
#   
#   or:
#   <iq type='error'>
#     <error code='401'/>
#     <query ...>...</query>
#   </iq>
#   
#   or:
#   <message type='error' ...>
#       ...
#       <error code='403'>Forbidden</error>
#   </message>

proc jlib::getstanzaerrorspec {stanza} {
    
    variable xmppxmlns

    set errcode ""
    set errmsg  ""
        
    # First search children of stanza (<iq> element) for error element.
    foreach child [wrapper::getchildren $stanza] {
	set tag [wrapper::gettag $child]
	if {[string equal $tag "error"]} {
	    set errelem $child
	}
	if {[string equal $tag "query"]} {
	    set queryelem $child
	}
    }
    if {![info exists errelem] && [info exists queryelem]} {
	
	# Search children if <query> element (Jabber).
	set errlist [wrapper::getchildswithtag $queryelem "error"]
	if {[llength $errlist]} {
	    set errelem [lindex $errlist 0]
	}
    }
	
    # Found it! XMPP contains an error stanza and not pure text.
    if {[info exists errelem]} {
	foreach {errcode errmsg} [geterrspecfromerror $errelem stanzas] {break}
    }
    return [list $errcode $errmsg]
}

# jlib::getstreamerrorspec --
# 
#       Extracts the error code and an error message from a stream:error
#       element. We must handle both the original Jabber protocol and the
#       XMPP protocol:
#
#   The syntax for stream errors is as follows:
#
#   <stream:error>
#      <defined-condition xmlns='urn:ietf:params:xml:ns:xmpp-streams'/>
#      <text xmlns='urn:ietf:params:xml:ns:xmpp-streams'>
#        OPTIONAL descriptive text
#      </text>
#      [OPTIONAL application-specific condition element]
#   </stream:error>
#
#   Jabber:
#   

proc jlib::getstreamerrorspec {errelem} {
    
    return [geterrspecfromerror $errelem streams]
}

# jlib::geterrspecfromerror --
# 
#       Get an error specification from an stanza error element.
#       
# Arguments:
#       errelem:    the <error/> element
#       kind.       'stanzas' or 'streams'
#       
# Results:
#       {errcode errmsg}

proc jlib::geterrspecfromerror {errelem kind} {
       
    variable xmppxmlns
    variable errCodeToText

    array set msgproc {
	stanzas  stanzaerror::getmsg
	streams  streamerror::getmsg
    }
    set cchdata [wrapper::getcdata $errelem]
    set errcode [wrapper::getattribute $errelem code]
    set errmsg  "Unknown"

    if {[string is integer -strict $errcode]} {
	if {$cchdata ne ""} {
	    set errmsg $cchdata
	} elseif {[info exists errCodeToText($errcode)]} {
	    set errmsg $errCodeToText($errcode)
	}
    } elseif {$cchdata ne ""} {
	
	# Old jabber way.
	set errmsg $cchdata
    }
	
    # xmpp way.
    foreach c [wrapper::getchildren $errelem] {
	set tag [wrapper::gettag $c]
	
	switch -- $tag {
	    text {
		# Use only as a complement iff our language. ???
		set xmlns [wrapper::getattribute $c xmlns]
		set lang  [wrapper::getattribute $c xml:lang]
		# [string equal $lang [getlang]]
		if {[string equal $xmlns $xmppxmlns($kind)]} {
		    set errstr [wrapper::getcdata $c]
		}
	    } 
	    default {
		set xmlns [wrapper::getattribute $c xmlns]
		if {[string equal $xmlns $xmppxmlns($kind)]} {
		    set errcode $tag
		    set errstr [$msgproc($kind) $tag]
		}
	    }
	}
    }
    if {[info exists errstr]} {
	set errmsg $errstr
    }
    if {$errmsg eq ""} {
	set errmsg "Unknown"
    }
    return [list $errcode $errmsg]
}

# jlib::bind_resource --
# 
#       xmpp requires us to bind a resource to the stream.

proc jlib::bind_resource {jlibname resource cmd} {
    
    variable xmppxmlns

    # If resource is an empty string request the server to create it.
    set subtags [list]
    if {$resource ne ""} {
	set subtags [list [wrapper::createtag resource -chdata $resource]]
    }
    set xmllist [wrapper::createtag bind       \
      -attrlist [list xmlns $xmppxmlns(bind)] -subtags $subtags]
    send_iq $jlibname set [list $xmllist]  \
      -command [list [namespace current]::parse_bind_resource $jlibname $cmd]
}

proc jlib::parse_bind_resource {jlibname cmd type subiq args} {
    
    upvar ${jlibname}::locals locals
    variable xmppxmlns
    
    # The server MAY change the 'resource' why we need to check this here.
    if {[string equal [wrapper::gettag $subiq] bind] &&  \
      [string equal [wrapper::getattribute $subiq xmlns] $xmppxmlns(bind)]} {
	set jidElem [wrapper::getfirstchildwithtag $subiq jid]
	if {[llength $jidElem]} {
	    
	    # Server replies with full JID.
	    set sjid [wrapper::getcdata $jidElem]
	    splitjid $sjid sjid2 sresource
	    if {![string equal [resourcemap $locals(resource)] $sresource]} {
		set locals(myjid)    $sjid
		set locals(myjid2)   $sjid2
		set locals(resource) $sresource
	    }
	}
    }    
    uplevel #0 $cmd [list $jlibname $type $subiq]
}
   
# jlib::invoke_iq_callback --
#
#       Callback when we get server response on iq set/get.
#       This is a generic callback procedure.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       cmd:        the 'cmd' argument in the calling procedure.
#       type:       "error" or "ok".
#       subiq:      if type="error", this is a list {errcode errmsg},
#                   else it is the query element as a xml list structure.
#       
# Results:
#       none.

proc jlib::invoke_iq_callback {jlibname cmd type subiq} {

    Debug 3 "jlib::invoke_iq_callback cmd=$cmd, type=$type, subiq=$subiq"
    
    uplevel #0 $cmd [list $jlibname $type $subiq]
}

# jlib::parse_search_set --
#
#       Callback for 'jabber:iq:search' 'result' and 'set' elements.
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#       cmd:        the callback to notify.
#       type:       "ok", "error", or "set"
#       subiq:

proc jlib::parse_search_set {jlibname cmd type subiq} {    

    upvar ${jlibname}::lib lib

    uplevel #0 $cmd [list $type $subiq]
}

# jlib::iq_register --
# 
#       Handler for registered iq callbacks.
#       
#       @@@ We could think of a more general mechanism here!!!!
#       1) Using -type, -xmlns, -from etc.

proc jlib::iq_register {jlibname type xmlns func {seq 50}} {
    
    upvar ${jlibname}::iqhook iqhook
    
    lappend iqhook($type,$xmlns) [list $func $seq]
    set iqhook($type,$xmlns) \
      [lsort -integer -index 1 [lsort -unique $iqhook($type,$xmlns)]]
}

proc jlib::iq_run_hook {jlibname type xmlns from subiq args} {
    
    upvar ${jlibname}::iqhook iqhook

    set ishandled 0    

    foreach key [list $type,$xmlns *,$xmlns $type,*] {
	if {[info exists iqhook($key)]} {
	    foreach spec $iqhook($key) {
		set func [lindex $spec 0]
		set code [catch {
		    uplevel #0 $func [list $jlibname $from $subiq] $args
		} ans]
		if {$code} {
		    bgerror "iqhook $func failed: $code\n$::errorInfo"
		}
		if {[string equal $ans "1"]} {
		    set ishandled 1
		    break
		}
	    }
	}	
	if {$ishandled} {
	    break
	}
    }
    return $ishandled
}

# jlib::message_register --
# 
#       Handler for registered message callbacks.
#       
#       We could think of a more general mechanism here!!!!

proc jlib::message_register {jlibname type xmlns func {seq 50}} {
    
    upvar ${jlibname}::msghook msghook
    
    lappend msghook($type,$xmlns) [list $func $seq]
    set msghook($type,$xmlns)  \
      [lsort -integer -index 1 [lsort -unique $msghook($type,$xmlns)]]
}

proc jlib::message_run_hook {jlibname type xmlns xmldata args} {
    
    upvar ${jlibname}::msghook msghook

    set ishandled 0
    
    foreach key [list $type,$xmlns *,$xmlns $type,*] {
	if {[info exists msghook($key)]} {
	    foreach spec $msghook($key) {
		set func [lindex $spec 0]
		set code [catch {
		    uplevel #0 $func [list $jlibname $xmlns $xmldata] $args
		} ans]
		if {$code} {
		    bgerror "msghook $func failed: $code\n$::errorInfo"
		}
		if {[string equal $ans "1"]} {
		    set ishandled 1
		    break
		}
	    }
	}	
	if {$ishandled} {
	    break
	}
    }
    return $ishandled
}

# @@@ We keep two versions, internal for jlib usage and external for apps.
#     Do this for all registered callbacks!

# jlib::presence_register --
# 
#       Handler for registered presence callbacks. Simple version.

proc jlib::presence_register_int {jlibname type func {seq 50}} {
    pres_reg $jlibname 1 $type $func $seq
}

proc jlib::presence_register {jlibname type func {seq 50}} {
    pres_reg $jlibname 0 $type $func $seq
}

proc jlib::pres_reg {jlibname int type func {seq 50}} {
    
    upvar ${jlibname}::preshook preshook
    
    lappend preshook($int,$type) [list $func $seq]
    set preshook($int,$type)  \
      [lsort -integer -index 1 [lsort -unique $preshook($int,$type)]]
}

proc jlib::presence_run_hook {jlibname int xmldata} {
    
    upvar ${jlibname}::preshook preshook
    upvar ${jlibname}::locals locals
    
    set type [wrapper::getattribute $xmldata type]
    set from [wrapper::getattribute $xmldata from]
    if {$type eq ""} {
	set type "available"
    }
    if {$from eq ""} {
	set from $locals(server)
    }
    set ishandled 0
    
    if {[info exists preshook($int,$type)]} {
	foreach spec $preshook($int,$type) {
	    set func [lindex $spec 0]
	    set code [catch {
		uplevel #0 $func [list $jlibname $xmldata]
	    } ans]
	    if {$code} {
		bgerror "preshook $func failed: $code\n$::errorInfo"
	    }
	    if {[string equal $ans "1"]} {
		set ishandled 1
		break
	    }
	}
    }
    return $ishandled
}

proc jlib::presence_deregister_int {jlibname type func} {
    pres_dereg $jlibname 1 $type $func
}

proc jlib::presence_deregister {jlibname type func} {
    pres_dereg $jlibname 0 $type $func
}

proc jlib::pres_dereg {jlibname int type func} {
    
    upvar ${jlibname}::preshook preshook
    
    if {[info exists preshook($int,$type)]} {
	set idx [lsearch -glob $preshook($int,$type) "$func *"]
	if {$idx >= 0} {
	    set preshook($int,$type) [lreplace $preshook($int,$type) $idx $idx]
	}
    }
}

# jlib::presence_register_ex --
# 
#       Set extended presence callbacks which can be triggered for
#       various attributes and elements.
#       
#       The internal storage consists of two parts:
#       1) attributes; stored as array keys using wildcards (*)
#       2) elements  : stored as a -tag .. -xmlns .. list
#       
#       expreshook($type,$from,$from2) {{{-key value ...} tclProc seq} {...} ...}
#       
#       These are matched separately but not independently.
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#       func:       tclProc        
#       args:       -type     type and from must match the presence element
#                   -from     attributes
#                   -from2    match the bare from jid
#                   -tag      tag and xmlns must coexist in the same element
#                   -xmlns    for a valid match
#                   -seq      priority 0-100 (D=50)
#       
# Results:
#       none.

proc jlib::presence_register_ex_int {jlibname func args} {
    eval {pres_reg_ex $jlibname 1 $func} $args
}

proc jlib::presence_register_ex {jlibname func args} {
    eval {pres_reg_ex $jlibname 0 $func} $args
}

proc jlib::pres_reg_ex {jlibname int func args} {
    
    upvar ${jlibname}::expreshook expreshook

    set type  "*"
    set from  "*"
    set from2 "*"
    set seq   50

    foreach {key value} $args {
	switch -- $key {
	    -from - -from2 {
		set name [string trimleft $key "-"]
		set $name [ESC $value]
	    }
	    -type {
		set type $value
	    }
	    -tag - -xmlns {
		set aopts($key) $value
	    }
	    -seq {
		set seq $value
	    }
	}
    }
    set pat "$type,$from,$from2"
    
    # The 'opts' must be ordered.
    set opts [list]
    foreach key [array names aopts] {
	lappend opts $key $aopts($key)
    }
    lappend expreshook($int,$pat) [list $opts $func $seq]
    set expreshook($int,$pat)  \
      [lsort -integer -index 2 [lsort -unique $expreshook($int,$pat)]]  
}

proc jlib::presence_ex_run_hook {jlibname int xmldata} {

    upvar ${jlibname}::expreshook expreshook
    upvar ${jlibname}::locals locals
    
    set type [wrapper::getattribute $xmldata type]
    set from [wrapper::getattribute $xmldata from]
    if {$type eq ""} {
	set type "available"
    }
    if {$from eq ""} {
	set from $locals(server)
    }
    set from2 [barejid $from]
    set pkey "$int,$type,$from,$from2"
            
    # Make matching in two steps, attributes and elements.
    # First the attributes.
    set matched [list]
    foreach {pat value} [array get expreshook $int,*] {

	if {[string match $pat $pkey]} {
	    
	    foreach spec $value {
    
		# Match attributes only if opts empty.
		if {[lindex $spec 0] eq {}} {
		    set func [lindex $spec 1]
		    set code [catch {
			uplevel #0 $func [list $jlibname $xmldata]
		    } ans]
		    if {$code} {
			bgerror "preshook $func failed: $code\n$::errorInfo"
		    }
		} else {
		    
		    # Collect all callbacks that match the attributes and have
		    # a nonempty element spec.
		    lappend matched $spec
		}
	    }
	}
    }
    
    # Now try match the elements with the ones that matched the attributes.
    if {[llength $matched]} {
	
	# Start by collecting all tags and xmlns we have in 'xmldata'.
	set tagxmlns [list]
	foreach c [wrapper::getchildren $xmldata] {
	    set xmlns [wrapper::getattribute $c xmlns]
	    lappend tagxmlns [list [wrapper::gettag $c] $xmlns]	    
	}

	foreach spec $matched {
	    array set opts {-tag * -xmlns *}
	    array set opts [lindex $spec 0]

	    # The 'olist' must be ordered.
	    set olist [list $opts(-tag) $opts(-xmlns)]
	    set idx [lsearch -glob $tagxmlns $olist]
	    if {$idx >= 0} {
		set func [lindex $spec 1]
		set code [catch {
		    uplevel #0 $func [list $jlibname $xmldata]
		} ans]
		if {$code} {
		    bgerror "preshook $func failed: $code\n$::errorInfo"
		}
	    }
	}
    }
}

proc jlib::presence_deregister_ex_int {jlibname func args} {
    eval {pres_dereg_ex $jlibname 1 $func} $args
}

proc jlib::presence_deregister_ex {jlibname func args} {
    eval {pres_dereg_ex $jlibname 0 $func} $args
}

proc jlib::pres_dereg_ex {jlibname int func args} {
    
    upvar ${jlibname}::expreshook expreshook
    
    set type  "*"
    set from  "*"
    set from2 "*"
    set seq   "*"

    foreach {key value} $args {
	switch -- $key {
	    -from - -from2 {
		set name [string trimleft $key "-"]
		set $name [jlib::ESC $value]
	    }
	    -type {
		set type $value
	    }
	    -tag - -xmlns {
		set aopts($key) $value
	    }
	    -seq {
		set seq $value
	    }
	}
    }
    set pat "$type,$from,$from2"
    if {[info exists expreshook($int,$pat)]} {

	# The 'opts' must be ordered.
	set opts [list]
	foreach key [array names aopts] {
	    lappend opts $key $aopts($key)
	}
	set idx [lsearch -glob $expreshook($int,$pat) [list $opts $func $seq]]
	if {$idx >= 0} {
	    set expreshook($int,$pat) [lreplace $expreshook($int,$pat) $idx $idx]
	    if {$expreshook($int,$pat) eq {}} {
		unset expreshook($int,$pat)
	    }
	}
    }
}

# jlib::element_register --
# 
#       Used to get callbacks from non stanza elements, like sasl etc.

proc jlib::element_register {jlibname xmlns func {seq 50}} {
    
    upvar ${jlibname}::elementhook elementhook
    
    lappend elementhook($xmlns) [list $func $seq]
    set elementhook($xmlns)  \
      [lsort -integer -index 1 [lsort -unique $elementhook($xmlns)]]
}

proc jlib::element_deregister {jlibname xmlns func} {
    
    upvar ${jlibname}::elementhook elementhook
    
    if {![info exists elementhook($xmlns)]} {
	return
    }
    set ind -1
    set found 0
    foreach spec $elementhook($xmlns) {
	incr ind
	if {[string equal $func [lindex $spec 0]]} {
	    set found 1
	    break
	}
    }
    if {$found} {
	set elementhook($xmlns) [lreplace $elementhook($xmlns) $ind $ind]
    }
}

proc jlib::element_run_hook {jlibname xmldata} {
    
    upvar ${jlibname}::elementhook elementhook

    set ishandled 0
    set xmlns [wrapper::getattribute $xmldata xmlns]
    
    if {[info exists elementhook($xmlns)]} {
	foreach spec $elementhook($xmlns) {
	    set func [lindex $spec 0]
	    set code [catch {
		uplevel #0 $func [list $jlibname $xmldata]
	    } ans]
	    if {$code} {
		bgerror "preshook $func failed: $code\n$::errorInfo"
	    }
	    if {[string equal $ans "1"]} {
		set ishandled 1
		break
	    }
	}
    }
    return $ishandled
}

# This part is supposed to be a maximal flexible event register mechanism.
# 
# Bind:  stanza  (presence, iq, message,...)
#        its attributes  (optional)
#        any child tag name  (optional)
#        its attributes  (optional)
#        
# genhook(stanza) = {{attrspec childspec func seq} ...}
# 
# with:  attrspec = {name1 value1 name2 value2 ...}
#        childspec = {tag attrspec}

# jlib::general_register --
# 
#       A mechanism to register for almost any kind of elements.

proc jlib::general_register {jlibname tag attrspec childspec func {seq 50}} {
    
    upvar ${jlibname}::genhook genhook
    
    lappend genhook($tag) [list $attrspec $childspec $func $seq]
    set genhook($tag)  \
      [lsort -integer -index 3 [lsort -unique $genhook($tag)]]
}

proc jlib::general_run_hook {jlibname xmldata} {

    upvar ${jlibname}::genhook genhook

    set ishandled 0
    set tag [wrapper::gettag $xmldata]
    if {[info exists genhook($tag)]} {
	foreach spec $genhook($tag) {
	    lassign $spec attrspec childspec func seq
	    lassign $childspec ctag cattrspec
	    if {![match_attr $attrspec [wrapper::getattrlist $xmldata]]} {
		continue
	    }
	    
	    # Search child elements for matches.
	    set match 0
	    foreach c [wrapper::getchildren $xmldata] {
		if {$ctag ne "" && $ctag ne [wrapper::gettag $c]} {
		    continue
		}
		if {![match_attr $cattrspec [wrapper::getattrlist $c]]} {
		    continue
		}
		set match 1
		break
	    }
	    if {!$match} {
		continue
	    }
	    
	    # If the spec survived here it matched.
	    set code [catch {
		uplevel #0 $func [list $jlibname $xmldata]
	    } ans]
	    if {$code} {
		bgerror "genhook $func failed: $code\n$::errorInfo"
	    }
	    if {[string equal $ans "1"]} {
		set ishandled 1
		break
	    }
	}
    }
    return $ishandled
}

proc jlib::match_attr {attrspec attr} {
    
    array set attrA $attr
    foreach {name value} $attrspec {
	if {![info exists attrA($name)]} {
	    return 0
	} elseif {$value ne $attrA($name)} {
	    return 0
	}
    }
    return 1
}

proc jlib::general_deregister {jlibname tag attrspec childspec func} {
    
    upvar ${jlibname}::genhook genhook

    if {[info exists genhook($tag)]} {
	set idx [lsearch -glob $genhook($tag) [list $attrspec $childspec $func *]]
	if {$idx >= 0} {
	    set genhook($tag) [lreplace $genhook($tag) $idx $idx]
	
	}
    }
}

# Test code...
if {0} {
    proc cb {args} {puts "************** $args"}
    set childspec [list query [list xmlns "http://jabber.org/protocol/disco#items"]]
    ::jlib::jlib1 general_register iq {} $childspec cb
    ::jlib::jlib1 general_deregister iq {} $childspec cb
    
    
}

# jlib::send_iq --
#
#       To send an iq (info/query) packet.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       type:       can be "get", "set", "result", or "error".
#                   "result" and "error" are used when replying an incoming iq.
#       xmldata:    list of elements as xmllists
#       args:
#                   -to $to       : Specify jid to send this packet to. If it 
#		    isn't specified, this part is set to sender's user-id by 
#		    the server.
#		    
#                   -id $id       : Specify an id to send with the <iq>. 
#                   If $type is "get", or "set", then the id will be generated 
#                   by jlib internally, and this switch will not work. 
#                   If $type is "result" or "error", then you may use this 
#                   switch.
#                   
#                   -command $cmd : Specify a callback to call when the 
#                   reply-packet is got. This switch will not work if $type 
#                   is "result" or "error".
#       
# Results:
#       none.

proc jlib::send_iq {jlibname type xmldata args} {

    upvar ${jlibname}::lib lib
    upvar ${jlibname}::iqcmd iqcmd
        
    Debug 3 "jlib::send_iq type='$type', xmldata='$xmldata', args='$args'"
    
    array set argsA $args
    set attrlist [list "type" $type]
    
    # Need to generate a unique identifier (id) for this packet.
    if {[string equal $type "get"] || [string equal $type "set"]} {
	lappend attrlist "id" $iqcmd(uid)
	
	# Record any callback procedure.
	if {[info exists argsA(-command)] && ($argsA(-command) ne "")} {
	    set iqcmd($iqcmd(uid)) $argsA(-command)
	}
	incr iqcmd(uid)
    } elseif {[info exists argsA(-id)]} {
	lappend attrlist "id" $argsA(-id)
    }
    unset -nocomplain argsA(-id) argsA(-command)
    foreach {key value} [array get argsA] {
	set name [string trimleft $key -]
	lappend attrlist $name $value
    }
    set xmllist [wrapper::createtag "iq" -attrlist $attrlist -subtags $xmldata]
    
    send $jlibname $xmllist
    return
}

# jlib::iq_get, iq_set --
#
#       Wrapper for 'send_iq' for set/getting namespaced elements.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       xmlns:
#       args:     -to recepient jid
#                 -command procName
#                 -sublists
#                 else as attributes
#       
# Results:
#       none.

proc jlib::iq_get {jlibname xmlns args} {

    set opts [list]
    set sublists [list]
    set attrlist [list xmlns $xmlns]
    foreach {key value} $args {
	
	switch -- $key {
	    -command {
		lappend opts -command  \
		  [list [namespace current]::invoke_iq_callback $jlibname $value]
	    }
	    -to {
		lappend opts -to $value
	    }
	    -sublists {
		set sublists $value
	    }
	    default {
		lappend attrlist [string trimleft $key "-"] $value
	    }
	}
    }
    set xmllist [wrapper::createtag "query" -attrlist $attrlist \
      -subtags $sublists]
    eval {send_iq $jlibname "get" [list $xmllist]} $opts
    return
}

proc jlib::iq_set {jlibname xmlns args} {

    set opts [list]
    set sublists [list]
    foreach {key value} $args {
	
	switch -- $key {
	    -command {
		lappend opts -command  \
		  [list [namespace current]::invoke_iq_callback $jlibname $value]
	    }
	    -to {
		lappend opts -to $value
	    }
	    -sublists {
		set sublists $value
	    }
	    default {
		#lappend subelements [wrapper::createtag  \
		#  [string trimleft $key -] -chdata $value]		
	    }
	}
    }
    set xmllist [wrapper::createtag "query" -attrlist [list xmlns $xmlns] \
      -subtags $sublists]
    eval {send_iq $jlibname "set" [list $xmllist]} $opts
    return
}

# jlib::send_auth --
#
#       Send simple client authentication.
#       It implements the 'jabber:iq:auth' set method.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       username:
#       resource:
#       cmd:        client command to be executed at the iq "result" element.
#       args:       Any of "-password" or "-digest" must be given.
#           -password
#           -digest
#           -to
#       
# Results:
#       none.

proc jlib::send_auth {jlibname username resource cmd args} {

    upvar ${jlibname}::locals locals

    set subelements [list  \
      [wrapper::createtag "username" -chdata $username]  \
      [wrapper::createtag "resource" -chdata $resource]]
    set toopt [list]

    foreach {key value} $args {
	switch -- $key {
	    -password - -digest {
		lappend subelements [wrapper::createtag  \
		  [string trimleft $key -] -chdata $value]
	    }
	    -to {
		set toopt [list -to $value]
	    }
	}
    }
    
    # Cache our login jid.
    set locals(username) $username
    set locals(resource) $resource
    set locals(myjid2)   ${username}@$locals(server)
    set locals(myjid)    ${username}@$locals(server)/${resource}

    set xmllist [wrapper::createtag "query" -attrlist {xmlns jabber:iq:auth} \
      -subtags $subelements]
    eval {send_iq $jlibname "set" [list $xmllist] -command  \
      [list [namespace current]::invoke_iq_callback $jlibname $cmd]} $toopt

    return
}

# jlib::register_get --
#
#       Sent with a blank query to retrieve registration information.
#       Retrieves a key for use on future registration pushes.
#       It implements the 'jabber:iq:register' get method.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       cmd:        client command to be executed at the iq "result" element.
#       args:       -to     : the jid for the service
#       
# Results:
#       none.

proc jlib::register_get {jlibname cmd args} {

    array set argsA $args
    set xmllist [wrapper::createtag "query" -attrlist {xmlns jabber:iq:register}]
    if {[info exists argsA(-to)]} {
	set toopt [list -to $argsA(-to)]
    } else {
	set toopt ""
    }
    eval {send_iq $jlibname "get" [list $xmllist] -command  \
      [list [namespace current]::invoke_iq_callback $jlibname $cmd]} $toopt
    return
}

# jlib::register_set --
#
#       Create a new account with the server, or to update user information.
#       It implements the 'jabber:iq:register' set method.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       username:
#       password:
#       cmd:        client command to be executed at the iq "result" element.
#       args:       -to       : the jid for the service
#                   -nick     :
#                   -name     :
#                   -first    :
#                   -last     :
#                   -email    :
#                   -address  :
#                   -city     :
#                   -state    :
#                   -zip      :
#                   -phone    :
#                   -url      :
#                   -date     :
#                   -misc     :
#                   -text     :
#                   -key      :
#       
# Results:
#       none.

proc jlib::register_set {jlibname username password cmd args} {
    
    set subelements [list  \
      [wrapper::createtag "username" -chdata $username]  \
      [wrapper::createtag "password" -chdata $password]]
    array set argsA $args
    foreach argsswitch [array names argsA] {
	if {[string equal $argsswitch "-to"]} {
	    continue
	}
	set par [string trimleft $argsswitch {-}]
	lappend subelements [wrapper::createtag $par  \
	  -chdata $argsA($argsswitch)]
    }
    set xmllist [wrapper::createtag "query"  \
      -attrlist {xmlns jabber:iq:register}   \
      -subtags $subelements]
    
    if {[info exists argsA(-to)]} {
	set toopt [list -to $argsA(-to)]
    } else {
	set toopt ""
    }
    eval {send_iq $jlibname "set" [list $xmllist] -command  \
      [list [namespace current]::invoke_iq_callback $jlibname $cmd]} $toopt
    return
}

# jlib::register_remove --
#
#       It implements the 'jabber:iq:register' set method with a <remove/> tag.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       to:
#       cmd:        client command to be executed at the iq "result" element.
#       args    -key
#       
# Results:
#       none.

proc jlib::register_remove {jlibname to cmd args} {

    set subelements [list [wrapper::createtag "remove"]]
    array set argsA $args
    if {[info exists argsA(-key)]} {
	lappend subelements [wrapper::createtag "key" -chdata $argsA(-key)]
    }
    set xmllist [wrapper::createtag "query"  \
      -attrlist {xmlns jabber:iq:register} -subtags $subelements]

    eval {send_iq $jlibname "set" [list $xmllist] -command   \
      [list [namespace current]::invoke_iq_callback $jlibname $cmd]} -to $to
    return
}

# jlib::search_get --
#
#       Sent with a blank query to retrieve search information.
#       Retrieves a key for use on future search pushes.
#       It implements the 'jabber:iq:search' get method.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       to:         this must be a searchable jud service, typically 
#                   'jud.jabber.org'.
#       cmd:        client command to be executed at the iq "result" element.
#       
# Results:
#       none.

proc jlib::search_get {jlibname to cmd} {
    
    set xmllist [wrapper::createtag "query" -attrlist {xmlns jabber:iq:search}]
    send_iq $jlibname "get" [list $xmllist] -to $to -command        \
      [list [namespace current]::invoke_iq_callback $jlibname $cmd]
    return
}

# jlib::search_set --
#
#       Makes an actual search in our roster at the server.
#       It implements the 'jabber:iq:search' set method.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       cmd:        client command to be executed at the iq "result" element.
#       to:         this must be a searchable jud service, typically 
#                   'jud.jabber.org'.
#       args:    -subtags list
#       
# Results:
#       none.

proc jlib::search_set {jlibname to cmd args} {

    set argsA(-subtags) [list]
    array set argsA $args

    set xmllist [wrapper::createtag "query"  \
      -attrlist {xmlns jabber:iq:search}   \
      -subtags $argsA(-subtags)]
    send_iq $jlibname "set" [list $xmllist] -to $to -command  \
      [list [namespace current]::parse_search_set $jlibname $cmd]

    return
}

# jlib::send_message --
#
#       Sends a message element.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       to:         the jabber id of the receiver.
#       args:
#                   -subject $subject     : Set subject of the message to 
#                   $subject.
#
#                   -thread $thread       : Set thread of the message to 
#                   $thread.
#                   
#                   -priority $priority   : Set priority of the message to 
#                   $priority.
#
#                   -body text            : 
#                   
#                   -type $type           : normal, chat or groupchat
#                   
#                   -id token
#                   
#                   -from                 : only for internal use, never send
#
#                   -xlist $xlist         : A list containing *X* xml_data. 
#                   Anything can be put inside an *X*. Please make sure you 
#                   created it with "wrapper::createtag" procedure, 
#                   and also, it has a "xmlns" attribute in its root tag. 
#
#                   -command
#                   
# Results:
#       none.

proc jlib::send_message {jlibname to args} {

    upvar ${jlibname}::msgcmd msgcmd
    upvar ${jlibname}::locals locals 

    Debug 3 "jlib::send_message to=$to, args=$args"
    
    array set argsA $args
    if {[info exists argsA(-command)]} {
	set uid $msgcmd(uid)
	set msgcmd($uid) $argsA(-command)
	incr msgcmd(uid)
	lappend args -id $uid
	unset argsA(-command)
	
	# There exist a weird situation if we send to ourself.
	# Skip this registered command the 1st time we get this,
	# and let any handlers take over. Trigger this 2nd time.
	if {[string equal $to $locals(myjid)]} {
	    set msgcmd($uid,self) 1
	}
	
    }
    set xmllist [eval {send_message_xmllist $to} [array get argsA]]
    send $jlibname $xmllist
    return
}

# jlib::send_message_xmllist --
# 
#       Create the xml list for send_message.

proc jlib::send_message_xmllist {to args} {
    
    array set argsA $args
    set attr [list to $to]
    set children [list]
    
    foreach {name value} $args {
	set par [string trimleft $name "-"]
	
	switch -- $name {
	    -xlist {
		foreach xchild $value {
		    lappend children $xchild
		}
	    }
	    -type {
		if {![string equal $value "normal"]} {
		    lappend attr "type" $value
		}
	    }
	    -id - -from {
		lappend attr $par $value
	    }
	    default {
		lappend children [wrapper::createtag $par -chdata $value]
	    }
	}
    }
    return [wrapper::createtag "message" -attrlist $attr -subtags $children]
}

# jlib::send_presence --
#
#       To send your presence.
#
# Arguments:
# 
#       jlibname:   the instance of this jlib.
#       args:
#           -keep   0|1 (D=0) we may keep the present 'status' and 'show'
#                   elements for undirected presence
#           -to     the JID of the recepient.
#           -from   should never be set by client!
#           -type   one of 'available', 'unavailable', 'subscribe', 
#                   'unsubscribe', 'subscribed', 'unsubscribed', 'invisible'.
#           -status
#           -priority  persistant option if undirected presence
#           -show
#           -xlist
#           -extras
#           -command   Specify a callback to call if we may expect any reply
#                   package, as entering a room with 'gc-1.0'.
#     
# Results:
#       none.

proc jlib::send_presence {jlibname args} {

    variable statics
    upvar ${jlibname}::locals locals
    upvar ${jlibname}::opts opts
    upvar ${jlibname}::prescmd prescmd
    upvar ${jlibname}::pres pres
    
    Debug 3 "jlib::send_presence args='$args'"
    
    set attrlist [list]
    set children [list]
    set directed 0
    set keep     0
    set type "available"
    array set argsA $args
    
    foreach {key value} $args {
	set par [string trimleft $key -]
	
	switch -- $key {
	    -command {
		lappend attrlist "id" $prescmd(uid)
		set prescmd($prescmd(uid)) $value
		incr prescmd(uid)
	    }
	    -extras - -xlist {
		foreach xchild $value {
		    lappend children $xchild
		}
	    }
	    -from {
		# Should never happen!
		lappend attrlist $par $value
	    }
	    -keep {
		set keep $value
	    }
	    -priority - -show {
		lappend children [wrapper::createtag $par -chdata $value]
	    }
	    -status {
		if {$value ne ""} {
		    lappend children [wrapper::createtag $par -chdata $value]
		}
	    }
	    -to {
		# Presence to server (undirected) shall not contain a to.
		if {$value ne $locals(server)} {
		    lappend attrlist $par $value
		    set directed 1
		}
	    }
	    -type {
		set type $value
		if {[regexp $statics(presenceTypeExp) $type]} {
		    lappend attrlist $par $type
		} else {
		    return -code error "Is not valid presence type: \"$type\""
		}
	    }
	    default {
		return -code error "unrecognized option \"$value\""
	    }
	}
    }
    
    # Must be destined to login server (by default).
    if {!$directed} {
	
	# Each and every presence stanza MUST contain the complete presence
	# state of the client. As a convinience we cache previous states and
	# may use them if not set explicitly:
	#    1.  <show/>
	#    2.  <status/>
	#    3.  <priority/>  Always reused if cached
	
	foreach name {show status} {
	    if {[info exists argsA(-$name)]} {
		set locals(pres,$name) $argsA(-$name)
	    } elseif {[info exists locals(pres,$name)]} {
		if {$keep} {
		    lappend children [wrapper::createtag $name  \
		      -chdata $locals(pres,$name)]
		} else {
		    unset -nocomplain locals(pres,$name)
		}
	    }
	}
	if {[info exists argsA(-priority)]} {
	    set locals(pres,priority) $argsA(-priority)
	} elseif {[info exists locals(pres,priority)]} {
	    lappend children [wrapper::createtag "priority"  \
	      -chdata $locals(pres,priority)]
	}

	set locals(pres,type) $type

	set locals(status) $type
	if {[info exists argsA(-show)]} {
	    set locals(status) $argsA(-show)
	    set locals(pres,show) $argsA(-show)
	}
    }
    
    # Assemble our registered presence stanzas. Only for undirected?
    foreach {key elem} [array get pres "stanza,*,"] {
	lappend children $elem
    }
    foreach {key elem} [array get pres "stanza,*,$type"] {
	lappend children $elem
    }
    
    set xmllist [wrapper::createtag "presence" -attrlist $attrlist \
      -subtags $children]
    send $jlibname $xmllist
    
    return
}

# jlib::register_presence_stanza, ... --
# 
#       Each presence element we send to the server (undirected) must contain
#       the complete state. This is a way to add custom presence stanzas
#       to our internal presence state to send each time we set our presence 
#       with the server (undirected presence).
#       They are stored by tag, xmlns, and an optional type attribute.
#       Any existing presence stanza with identical tag/xmlns/type will 
#       be replaced.
#       
# Arguments:
#       jlibname:   the instance of this jlib
#       elem:       xml element
#       args        -type  available | unavailable | ...

proc jlib::register_presence_stanza {jlibname elem args} {

    upvar ${jlibname}::pres pres

    set argsA(-type) ""
    array set argsA $args
    set type $argsA(-type)
    
    set tag   [wrapper::gettag $elem]
    set xmlns [wrapper::getattribute $elem xmlns]
    set pres(stanza,$tag,$xmlns,$type) $elem
}

proc jlib::deregister_presence_stanza {jlibname tag xmlns} {
    
    upvar ${jlibname}::pres pres
    
    array unset pres "stanza,$tag,$xmlns,*"
}

proc jlib::get_registered_presence_stanzas {jlibname {tag *} {xmlns *}} {
    
    upvar ${jlibname}::pres pres
    
    set stanzas [list]
    foreach key [array names pres -glob stanza,$tag,$xmlns,*] {
	lassign [split $key ,] - t x type
	set spec [list $t $x $pres($key)]
	if {$type ne ""} {
	    lappend spec -type $type
	}
	lappend stanzas $spec
    }
    return $stanzas
}

# jlib::send --
# 
#       Sends general xml using a xmllist.
#       Never throws error. Network errors reported via callback.

proc jlib::send {jlibname xmllist} {
    
    upvar ${jlibname}::lib lib
    upvar ${jlibname}::locals locals
    
    # For the auto away function.
    if {$locals(trigAutoAway)} {
	schedule_auto_away $jlibname
    }
    set locals(last) [clock seconds]
    set xml [wrapper::createxml $xmllist]
    
    # We fail only if already in stream.
    # The first failure reports the network error, closes the stream,
    # which stops multiple errors to be reported to the client.
    if {$lib(isinstream)} {
	if {[catch {
	    uplevel #0 $lib(transport,send) [list $jlibname $xml]
	} err]} {
	    kill $jlibname
	    invoke_async_error $jlibname networkerror
	}
    }
    return
}

# jlib::sendraw --
# 
#       Send raw xml. The caller is responsible for catching errors.

proc jlib::sendraw {jlibname xml} {
    
    upvar ${jlibname}::lib lib

    uplevel #0 $lib(transport,send) [list $jlibname $xml]
}

# jlib::mypresence --
# 
#       Returns any of {available away xa chat dnd invisible unavailable}
#       for our status with the login server.

proc jlib::mypresence {jlibname} {

    upvar ${jlibname}::locals locals
    
    if {[info exists locals(pres,show)]} {
	return $locals(pres,show)
    } else {
	return $locals(pres,type)
    }
}

proc jlib::mypresencestatus {jlibname} {

    upvar ${jlibname}::locals locals
    
    if {[info exists locals(pres,status)]} {
	return $locals(pres,status)
    } else {
	return ""
    }
}

# jlib::myjid --
# 
#       Returns our 3-tier jid as authorized with the login server.

proc jlib::myjid {jlibname} {

    upvar ${jlibname}::locals locals
    
    return $locals(myjid)
}

proc jlib::myjid2 {jlibname} {

    upvar ${jlibname}::locals locals
    
    return $locals(myjid2)
}

# jlib::oob_set --
#
#       It implements the 'jabber:iq:oob' set method.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       to:
#       cmd:        client command to be executed at the iq "result" element.
#       url:
#       args:
#                   -desc
#       
# Results:
#       none.

proc jlib::oob_set {jlibname to cmd url args} {

    set attrlist {xmlns jabber:iq:oob}
    set children [list [wrapper::createtag "url" -chdata $url]]
    array set argsA $args
    if {[info exists argsA(-desc)] && [string length $argsA(-desc)]} {
	lappend children [wrapper::createtag "desc" -chdata $argsA(-desc)]
    }
    set xmllist [wrapper::createtag query -attrlist $attrlist  \
      -subtags $children]
    send_iq $jlibname set [list $xmllist] -to $to -command  \
      [list [namespace current]::invoke_iq_callback $jlibname $cmd]
    return
}

# jlib::get_last --
#
#       Query the 'last' of 'to' using 'jabber:iq:last' get.

proc jlib::get_last {jlibname to cmd} {
    
    set xmllist [wrapper::createtag "query"  \
      -attrlist {xmlns jabber:iq:last}]
    send_iq $jlibname "get" [list $xmllist] -to $to -command   \
      [list [namespace current]::invoke_iq_callback $jlibname $cmd]
    return
}

# jlib::handle_get_last --
#
#       Seconds since last activity. Response to 'jabber:iq:last' get.

proc jlib::handle_get_last {jlibname from subiq args} {    

    upvar ${jlibname}::locals locals
    
    array set argsA $args

    set secs [expr [clock seconds] - $locals(last)]
    set xmllist [wrapper::createtag "query"  \
      -attrlist [list xmlns jabber:iq:last seconds $secs]]
    
    set opts [list]
    if {[info exists argsA(-from)]} {
	lappend opts -to $argsA(-from)
    }
    if {[info exists argsA(-id)]} {
	lappend opts -id $argsA(-id)
    }
    eval {send_iq $jlibname "result" [list $xmllist]} $opts

    # Tell jlib's iq-handler that we handled the event.
    return 1
}

# jlib::get_time --
#
#       Query the 'time' of 'to' using 'jabber:iq:time' get.

proc jlib::get_time {jlibname to cmd} {
    
    set xmllist [wrapper::createtag "query"  \
      -attrlist {xmlns jabber:iq:time}]
    send_iq $jlibname "get" [list $xmllist] -to $to -command        \
      [list [namespace current]::invoke_iq_callback $jlibname $cmd]
    return
}

# jlib::handle_get_time --
#
#       Send our time. Response to 'jabber:iq:time' get.

proc jlib::handle_get_time {jlibname from subiq args} {
    
    array set argsA $args
    
    # Applications using 'jabber:iq:time' SHOULD use the old format, 
    # not the format defined in XEP-0082.
    set secs [clock seconds]
    set utc [clock format $secs -format "%Y%m%dT%H:%M:%S" -gmt 1]
    set tz "GMT"
    set display [clock format $secs]
    set subtags [list  \
      [wrapper::createtag "utc" -chdata $utc]  \
      [wrapper::createtag "tz" -chdata $tz]  \
      [wrapper::createtag "display" -chdata $display] ]
    set xmllist [wrapper::createtag "query" -subtags $subtags  \
      -attrlist {xmlns jabber:iq:time}]

    set opts [list]
    if {[info exists argsA(-from)]} {
	lappend opts -to $argsA(-from)
    }
    if {[info exists argsA(-id)]} {
	lappend opts -id $argsA(-id)
    }
    eval {send_iq $jlibname "result" [list $xmllist]} $opts

    # Tell jlib's iq-handler that we handled the event.
    return 1
}

# Support for XEP-0202 Entity Time.

proc jlib::get_entity_time {jlibname to cmd} {
    variable jxmlns

    set xmllist [wrapper::createtag "time"  \
      -attrlist [list xmlns $jxmlns(entitytime)]]
    send_iq $jlibname "get" [list $xmllist] -to $to -command        \
      [list [namespace current]::invoke_iq_callback $jlibname $cmd]
    return
}

proc jlib::handle_entity_time {jlibname from subiq args} {    
    variable jxmlns

    array set argsA $args

    # Figure out our time zone in terms of HH:MM.
    # Compare with the GMT time and take the diff. Avoid year wrap around.
    set secs [clock seconds]
    set day [clock format $secs -format "%j"]
    if {$day eq "001"} {
	incr secs [expr {24*60*60}]
    } elseif {($day eq "365") || ($day eq "366")} {
	incr secs [expr {-2*24*60*60}]    
    }
    set format "%S + 60*(%M + 60*(%H + 24*%j))"
    set local [clock format $secs -format $format]
    set gmt   [clock format $secs -format $format -gmt 1]

    # Remove leading zeros since they will be interpreted as octals.
    regsub -all {0+([1-9]+)} $local {\1} local
    regsub -all {0+([1-9]+)} $gmt   {\1} gmt
    set local [expr $local]
    set gmt [expr $gmt]
    set mindiff [expr {($local - $gmt)/60}]
    set sign [expr {$mindiff >= 0 ? "" : "-"}]
    set zhour [expr {abs($mindiff)/60}]
    set zmin [expr {$mindiff % 60}]
    set tzo [format "$sign%.2d:%.2d" $zhour $zmin]
    
    # Time format according to XEP-0082 (XMPP Date and Time Profiles).
    # <utc>2006-12-19T17:58:35Z</utc> 
    set utc [clock format $secs -format "%Y-%m-%dT%H:%M:%SZ" -gmt 1]

    set subtags [list  \
      [wrapper::createtag "tzo" -chdata $tzo] \
      [wrapper::createtag "utc" -chdata $utc] ]
    set xmllist [wrapper::createtag "time" -subtags $subtags  \
      -attrlist [list xmlns $jxmlns(entitytime)]]

    set opts [list]
    if {[info exists argsA(-from)]} {
	lappend opts -to $argsA(-from)
    }
    if {[info exists argsA(-id)]} {
	lappend opts -id $argsA(-id)
    }
    eval {send_iq $jlibname "result" [list $xmllist]} $opts
    return 1
}
    
# jlib::get_version --
#
#       Query the 'version' of 'to' using 'jabber:iq:version' get.

proc jlib::get_version {jlibname to cmd} {
        
    set xmllist [wrapper::createtag "query"  \
      -attrlist {xmlns jabber:iq:version}]
    send_iq $jlibname "get" [list $xmllist] -to $to -command   \
      [list [namespace current]::invoke_iq_callback $jlibname $cmd]
    return
}

# jlib::handle_get_version --
#
#       Send our version. Response to 'jabber:iq:version' get.

proc jlib::handle_get_version {jlibname from subiq args} {
    global  prefs tcl_platform
    variable version
    
    array set argsA $args
    
    # Return any id!
    set opts [list]
    if {[info exists argsA(-id)]} {
	set opts [list -id $argsA(-id)]
    }
    set os $tcl_platform(os)
    if {[info exists tcl_platform(osVersion)]} {
	append os " " $tcl_platform(osVersion)
    }
    lappend opts -to $from
    set subtags [list  \
      [wrapper::createtag name    -chdata "JabberLib"]  \
      [wrapper::createtag version -chdata $version]  \
      [wrapper::createtag os      -chdata $os] ]
    set xmllist [wrapper::createtag query -subtags $subtags  \
      -attrlist {xmlns jabber:iq:version}]
    eval {send_iq $jlibname "result" [list $xmllist]} $opts

    # Tell jlib's iq-handler that we handled the event.
    return 1
}

# jlib::schedule_keepalive --
# 
#       Supposed to detect network failures but seems not to work like that.

proc jlib::schedule_keepalive {jlibname} {   

    upvar ${jlibname}::locals locals
    upvar ${jlibname}::opts opts
    upvar ${jlibname}::lib lib
    
    if {$opts(-keepalivesecs) && $lib(isinstream)} {
	if {[catch {
	    uplevel #0 $lib(transport,send) [list $jlibname "\n"]
	    flush $lib(sock)
	} err]} {
	    kill $jlibname
	    invoke_async_error $jlibname networkerror
	} else {
	    set locals(aliveid) [after [expr 1000 * $opts(-keepalivesecs)] \
	      [list [namespace current]::schedule_keepalive $jlibname]]
	}
    }
}

# jlib::schedule_auto_away, cancel_auto_away, auto_away_cmd
#
#       Procedures for auto away things.
#       Better to use 'tk inactive' or 'tkinactive' and handle this on
#       application level.

proc jlib::schedule_auto_away {jlibname} {       

    upvar ${jlibname}::locals locals
    upvar ${jlibname}::opts opts
    
    cancel_auto_away $jlibname
    if {$opts(-autoawaymins) > 0} {
	set locals(afterawayid) [after [expr 60000 * $opts(-autoawaymins)] \
	  [list [namespace current]::auto_away_cmd $jlibname away]]
    }
    if {$opts(-xautoawaymins) > 0} {
	set locals(afterxawayid) [after [expr 60000 * $opts(-xautoawaymins)] \
	  [list [namespace current]::auto_away_cmd $jlibname xaway]]
    }    
}

proc jlib::cancel_auto_away {jlibname} {

    upvar ${jlibname}::locals locals

    if {[info exists locals(afterawayid)]} {
	after cancel $locals(afterawayid)
	unset locals(afterawayid)
    }
    if {[info exists locals(afterxawayid)]} {
	after cancel $locals(afterxawayid)
	unset locals(afterxawayid)
    }
}

# jlib::auto_away_cmd --
# 
#       what:       "away", or "xaway"
#       
#       @@@ Replaced by idletime and AutoAway

proc jlib::auto_away_cmd {jlibname what} {      

    variable statusPriority
    upvar ${jlibname}::locals locals
    upvar ${jlibname}::lib lib
    upvar ${jlibname}::opts opts

    Debug 3 "jlib::auto_away_cmd what=$what"
    
    if {$what eq "xaway"} {
	set status xa
    } else {
	set status $what
    }

    # Auto away and extended away are only set when the
    # current status has a lower priority than away or xa respectively.
    if {$statusPriority($locals(status)) >= $statusPriority($status)} {
	return
    }
    
    # Be sure not to trig ourselves.
    set locals(trigAutoAway) 0

    switch -- $what {
	away {
	    send_presence $jlibname -show "away" -status $opts(-awaymsg)
	}
	xaway {
	    send_presence $jlibname -show "xa" -status $opts(-xawaymsg)
	}
    }
    set locals(trigAutoAway) 1
    uplevel #0 $lib(clientcmd) [list $jlibname $status]
}

# jlib::getrecipientjid --
# 
#       Tries to obtain the correct form of jid to send message to.
#       Follows the XMPP spec, section 4.1.
#       
#       @@@ Perhaps this should go in app code?

proc jlib::getrecipientjid {jlibname jid} {
    variable statics
    
    set jid2 [barejid $jid]
    set isroom [[namespace current]::service::isroom $jlibname $jid2]
    if {$isroom} {
	return $jid
    } elseif {[info exists statics(roster)] &&  \
      [$jlibname roster isavailable $jid]} {
	return $jid
    } else {
	return $jid2
    }
}

proc jlib::getlang {} {
    
    if {[catch {package require msgcat}]} {
	return en
    } else {
	set lang [lindex [::msgcat::mcpreferences] end]
    
	switch -- $lang {
	    "" - c - posix {
		return en
	    }
	    default {
		return $lang
	    }
	}
    }
}

namespace eval jlib {
    
    # We just the http error codes here since may be useful if we only
    # get the 'code' attribute in an error element.
    # @@@ Add to message catalogs.
    variable errCodeToText
    array set errCodeToText {
	100 "Continue"
	101 "Switching Protocols"
	200 "OK"
	201 "Created"
	202 "Accepted"
	203 "Non-Authoritative Information"
	204 "No Content"
	205 "Reset Content"
	206 "Partial Content"
	300 "Multiple Choices"
	301 "Moved Permanently"
	302 "Found"
	303 "See Other"
	304 "Not Modified"
	305 "Use Proxy"
	307 "Temporary Redirect"
	400 "Bad Request"
	401 "Unauthorized"
	402 "Payment Required"
	403 "Forbidden"
	404 "Not Found"
	405 "Method Not Allowed"
	406 "Not Acceptable"
	407 "Proxy Authentication Required"
	408 "Request Time-out"
	409 "Conflict"
	410 "Gone"
	411 "Length Required"
	412 "Precondition Failed"
	413 "Request Entity Too Large"
	414 "Request-URI Too Large"
	415 "Unsupported Media Type"
	416 "Requested Range Not Satisfiable"
	417 "Expectation Failed"
	500 "Internal Server Error"	
	501 "Not Implemented"
	502 "Bad Gateway"
	503 "Service Unavailable"
	504 "Gateway Time-out"
	505 "HTTP Version not supported"
    }
}

# Various utility procedures to handle jid's....................................

# jlib::ESC --
#
#	array get and array unset accepts glob characters. These need to be
#	escaped if they occur as part of a JID.
#	NB1: 'string match pattern str' MUST have pattern escaped!
#	NB2: This also applies to 'lsearch'!

proc jlib::ESC {s} {
    return [string map {* \\* ? \\? [ \\[ ] \\] \\ \\\\} $s]
}

# STRINGPREPs for the differnt parts of jids.

proc jlib::UnicodeListToRE {ulist} {
    
    set str [string map {- -\\u} $ulist]
    set str "\\u[join $str \\u]"
    return [subst $str]
}

# jlib::MakeHexHexEscList --
# 
#       Takes a list of characters and transforms them to their hexhex form.
#       Used by: XEP-0106: JID Escaping

proc jlib::MakeHexHexEscList {clist} {
    
    set hexlist [list]
    foreach c $clist {
	scan $c %c n
	lappend hexlist [format %x $n]
    }
    return $hexlist
}

proc jlib::MakeHexHexCharMap {clist} {
    
    set map [list]
    foreach c $clist h [MakeHexHexEscList $clist] {
	lappend map $c \\$h
    }
    return $map
}

proc jlib::MakeHexHexInvCharMap {clist} {
    
    set map [list]
    foreach c $clist h [MakeHexHexEscList $clist] {
	lappend map \\$h $c
    }
    return $map
}

namespace eval jlib {
    
    # Characters that need to be escaped since non valid.
    #       XEP-0106: JID Escaping
    variable jidEsc { "\&'/:<>@\\}
    variable jidEscMap [MakeHexHexCharMap [split $jidEsc ""]]
    variable jidEscInvMap [MakeHexHexInvCharMap [split $jidEsc ""]]
    
    # Prohibited ASCII characters.
    set asciiC12C22 {\x00-\x1f\x80-\x9f\x7f\xa0}
    set asciiC11 {\x20}
    
    # C.1.1 is actually allowed (RFC3491), weird!
    set    asciiProhibit(domain) $asciiC11
    append asciiProhibit(domain) $asciiC12C22
    append asciiProhibit(domain) /@   

    # The nodeprep prohibits these characters in addition:
    # All whitespace characters (which reduce to U+0020, also called SP) 
    # U+0022 (") 
    # U+0026 (&) 
    # U+0027 (') 
    # U+002F (/) 
    # U+003A (:) 
    # U+003C (<) 
    # U+003E (>) 
    # U+0040 (@) 
    set    asciiProhibit(node) {"&'/:<>@} 
    append asciiProhibit(node) $asciiC11 
    append asciiProhibit(node) $asciiC12C22
    
    set asciiProhibit(resource) $asciiC12C22
    
    # RFC 3454 (STRINGPREP); all unicode characters:
    # 
    # Maps to nothing (empty).
    set mapB1 {
	00ad	034f	1806	180b	180c	180d	200b	200c
	200d	2060	fe00	fe01	fe02	fe03	fe04	fe05
	fe06	fe07	fe08	fe09	fe0a	fe0b	fe0c	fe0d
	fe0e	fe0f	feff    
    }
    
    # ASCII space characters. Just a space.
    set prohibitC11 {0020}
    
    # Non-ASCII space characters
    set prohibitC12 {
	00a0	1680	2000	2001	2002	2003	2004	2005
	2006	2007	2008	2009	200a	200b	202f	205f
	3000
    }
    
    # C.2.1 ASCII control characters
    set prohibitC21 {
	0000-001F   007F
    }
    
    # C.2.2 Non-ASCII control characters
    set prohibitC22 {
	0080-009f	06dd	070f	180e	200c	200d	2028
	2029	2060	2061	2062	2063	206a-206f	feff
	fff9-fffc       1d173-1d17a
    }
    
    # C.3 Private use
    set prohibitC3 {
	e000-f8ff	f0000-ffffd	100000-10fffd
    }
    
    # C.4 Non-character code points
    set prohibitC4 {
	fdd0-fdef	fffe-ffff	1fffe-1ffff	2fffe-2ffff
	3fffe-3ffff	4fffe-4ffff	5fffe-5ffff	6fffe-6ffff
	7fffe-7ffff	8fffe-8ffff	9fffe-9ffff	afffe-affff
	bfffe-bffff	cfffe-cffff	dfffe-dffff	efffe-effff
	ffffe-fffff	10fffe-10ffff
    }
    
    # C.5 Surrogate codes
    set prohibitC5 {d800-dfff}
    
    # C.6 Inappropriate for plain text
    set prohibitC6 {
	fff9	fffa	fffb	fffc	fffd
    }
    
    # C.7 Inappropriate for canonical representation
    set prohibitC7 {2ff0-2ffb}
    
    # C.8 Change display properties or are deprecated
    set prohibitC8 {
	0340	0341	200e	200f	202a	202b	202c	202d
	202e	206a	206b	206c	206d	206e	206f
    }
    
    # Test: 0, 1, 2, A-Z
    set test {
	0030    0031   0032    0041-005a
    }
    
    # And many more...

    variable mapB1RE       [UnicodeListToRE $mapB1]
    variable prohibitC11RE [UnicodeListToRE $prohibitC11]
    variable prohibitC12RE [UnicodeListToRE $prohibitC12]

}

# jlib::splitjid --
# 
#       Splits a general jid into a jid-2-tier and resource

proc jlib::splitjid {jid jid2Var resourceVar} {
    
    set idx [string first / $jid]
    if {$idx == -1} {
	uplevel 1 [list set $jid2Var $jid]
	uplevel 1 [list set $resourceVar {}]
    } else {
	set jid2 [string range $jid 0 [expr {$idx - 1}]]
	set res [string range $jid [expr {$idx + 1}] end]
	uplevel 1 [list set $jid2Var $jid2]
	uplevel 1 [list set $resourceVar $res]
    }
}

# jlib::splitjidex --
# 
#       Split a jid into the parts: jid = [ node "@" ] domain [ "/" resource ]
#       Possibly empty. Doesn't check for valid content, only the form.
#       
#       RFC3920 3.1:
#            jid             = [ node "@" ] domain [ "/" resource ]

proc jlib::splitjidex {jid nodeVar domainVar resourceVar} {
    
    set node   ""
    set domain ""
    set res    ""
    
    # Node part:
    set idx [string first @ $jid]
    if {$idx > 0} {
	set node [string range $jid 0 [expr {$idx-1}]]
	set jid [string range $jid [expr {$idx+1}] end]
    }

    # Resource part:
    set idx [string first / $jid]
    if {$idx > 0} {
	set res [string range $jid [expr {$idx+1}] end]
	set jid [string range $jid 0 [expr {$idx-1}]]
    }
    
    # Domain part is what remains:
    set domain $jid
    
    uplevel 1 [list set $nodeVar $node]
    uplevel 1 [list set $domainVar $domain]
    uplevel 1 [list set $resourceVar $res]
}

proc jlib::barejid {jid} {
    
    set idx [string first / $jid]
    if {$idx == -1} {
	return $jid
    } else {
	return [string range $jid 0 [expr {$idx-1}]]
    }
}

proc jlib::resourcejid {jid} {
    set idx [string first / $jid]
    if {$idx > 0} {
	return [string range $jid [expr {$idx+1}] end]
    } else {
	return ""
    }
}

proc jlib::isbarejid {jid} {
    return [expr {([string first / $jid] == -1) ? 1 : 0}]
}

proc jlib::isfulljid {jid} {
    return [expr {([string first / $jid] == -1) ? 0 : 1}]
}

# jlib::joinjid --
# 
#       Joins the, optionally empty, parts into a jid.
#       domain must be nonempty though.

proc jlib::joinjid {node domain resource} {
    
    set jid $domain
    if {$node ne ""} {
	set jid ${node}@${jid}
    }
    if {$resource ne ""} {
	append jid "/$resource"
    }
    return $jid
}

# jlib::jidequal --
# 
#       Checks if two jids are actually equal after mapped. Does not check
#       for prohibited characters.

proc jlib::jidequal {jid1 jid2} {
    return [string equal [jidmap $jid1] [jidmap $jid2]]
}

# jlib::jidvalidate --
# 
#       Checks if this is a valid jid interms of form and characters.

proc jlib::jidvalidate {jid} {
    
    if {$jid eq ""} {
	return 0
    } elseif {[catch {splitjidex $jid node name resource} ans]} {
	return 0
    }
    foreach what {node name resource} {
	if {$what ne ""} {
	    if {[catch {${what}prep [set $what]} ans]} {
		return 0
	    }
	}
    }
    return 1
}

# String preparation (STRINGPREP) RFC3454:
# 
#    The steps for preparing strings are:
#
#  1) Map -- For each character in the input, check if it has a mapping
#     and, if so, replace it with its mapping.  This is described in
#     section 3.
#
#  2) Normalize -- Possibly normalize the result of step 1 using Unicode
#     normalization.  This is described in section 4.
#
#  3) Prohibit -- Check for any characters that are not allowed in the
#     output.  If any are found, return an error.  This is described in
#     section 5.
#
#  4) Check bidi -- Possibly check for right-to-left characters, and if
#     any are found, make sure that the whole string satisfies the
#     requirements for bidirectional strings.  If the string does not
#     satisfy the requirements for bidirectional strings, return an
#     error.  This is described in section 6.

# jlib::*map --
# 
#       Does the mapping part.

proc jlib::nodemap {node} {

    return [string tolower $node]
}

proc jlib::namemap {domain} { 
 
    return [string tolower $domain]
}

proc jlib::resourcemap {resource} {
    
    # Note that resources are case sensitive!
    return $resource
}

# jlib::*prep --
# 
#       Does the complete stringprep.

proc jlib::nodeprep {node} {
    variable asciiProhibit
    
    set node [nodemap $node]
    if {[regexp ".*\[${asciiProhibit(node)}\].*" $node]} {
	return -code error "node part contains illegal character(s)"
    }
    return $node
}

proc jlib::nameprep {domain} {   
    variable asciiProhibit
    
    set domain [namemap $domain]
    if {[regexp ".*\[${asciiProhibit(domain)}\].*" $domain]} {
	return -code error "domain contains illegal character(s)"
    }
    return $domain
}

proc jlib::resourceprep {resource} {
    variable asciiProhibit
    
    set resource [resourcemap $resource]
    
    # Orinary spaces are allowed!
    if {[regexp ".*\[${asciiProhibit(resource)}\].*" $resource]} {
	return -code error "resource contains illegal character(s)"
    }
    return $resource
}

# jlib::jidmap --
# 
#       Does the mapping part of STRINGPREP. Does not check for prohibited
#       characters.
#       
# Results:
#       throws an error if form unrecognized, else the mapped jid.

proc jlib::jidmap {jid} {
    
    if {$jid eq ""} {
	return
    }
    # Guard against spurious spaces.
    set jid [string trim $jid]
    splitjidex $jid node domain resource
    return [joinjid [nodemap $node] [namemap $domain] [resourcemap $resource]]
}

# jlib::jidprep --
# 
#       Applies STRINGPREP to the individiual and specific parts of the jid.
#       
# Results:
#       throws an error if prohibited, else the prepared jid.

proc jlib::jidprep {jid} {
    
    if {$jid eq ""} {
	return
    }
    splitjidex $jid node domain resource
    set node     [nodeprep $node]
    set domain   [nameprep $domain]
    set resource [resourceprep $resource]
    return [joinjid $node $domain $resource]
}

proc jlib::MapStr {str } {
    
    # TODO
}

# jlib::escapestr, unescapestr, escapejid, unescapejid --
# 
#       XEP-0106: JID Escaping 
#       NB1: 'escapstr' and 'unescapstr' must only be applied to the node 
#            part of a JID.
#       NB2: 'escapstr' must never be applied twice!
#       NB3: it is currently unclear if escaping should be allowed on "ordinary"
#            user JIDs

proc jlib::escapestr {str} {    
    variable jidEscMap
    return [string map $jidEscMap $str]
}

proc jlib::unescapestr {str} {
    variable jidEscInvMap    
    return [string map $jidEscInvMap $str]
}

proc jlib::escapejid {jid} {
  
    # Node part:
    # @@@ I think there is a protocol flaw here!!!
    set idx [string first @ $jid]
    if {$idx > 0} {
	set node [string range $jid 0 [expr {$idx-1}]]
	set rest [string range $jid [expr {$idx+1}] end]
	return [escapestr $node]@$rest
    } else {
	return $jid
    }
}

proc jlib::unescapejid {jid} {
  
    # Node part:
    # @@@ I think there is a protocol flaw here!!!
    set idx [string first @ $jid]
    if {$idx > 0} {
	set node [string range $jid 0 [expr {$idx-1}]]
	set rest [string range $jid [expr {$idx+1}] end]
	return [unescapestr $node]@$rest
    } else {
	return $jid
    }
}

proc jlib::setdebug {args} {
    variable debug
    
    if {[llength $args] == 0} {
	return $debug
    } elseif {[llength $args] == 1} {
	set debug $args
    } else {
	return -code error "Usage: jlib::setdebug ?integer?"
    }
}

# jlib::generateuuid --
# 
#       Simplified uuid generator. See the uuid package for a better one.

proc jlib::generateuuid {} {
    set MAX_INT 0x7FFFFFFF
    # Bugfix Eric Hassold from Evolane
    set hex1 [format {%x} [expr {[clock clicks] & $MAX_INT}]]
    set hex2 [format {%x} [expr {int($MAX_INT*rand())}]]
    return $hex1-$hex2
}

proc jlib::Debug {num str} {
    global  fdDebug
    variable debug
    if {$num <= $debug} {
	if {[info exists fdDebug]} {
	    puts $fdDebug $str
	    flush $fdDebug
	}
	puts $str
    }
}

#-------------------------------------------------------------------------------
