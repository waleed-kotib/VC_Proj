################################################################################
#
# This is JabberLib (abbreviated jlib), the Tcl library for 
# use in making Jabber clients.
# Is originally written by Kerem HADIMLI, with additions
# from Todd Bradley. 
# Completely rewritten from scratch by Mats Bengtsson.
# The algorithm for building parse trees has been completely redesigned.
# Only some structures and API names are kept essentially unchanged.
#
# $Id: jabberlib.tcl,v 1.130 2005-12-27 14:53:55 matben Exp $
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
#       lib(rostername)            : the name of the roster object
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
#                                         -> roster >-  
#                                        /            \ 
#                                       /              \
#   TclXML <---> wrapper <---> jabberlib <-----------> client
#                                       
#                                       
#   
#   Note the one-way communication with the 'roster' object since it may only
#   be set by the server, that is, from 'jabberlib'. 
#   The client only "gets" the roster.
#
############################# USAGE ############################################
#
#   NAME
#      jabberlib - an interface between Jabber clients and the wrapper
#      
#   SYNOPSIS
#      jlib::new rosterName clientCmd ?-opt value ...?
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
#      jlibName agent_get to cmd
#      jlibName agents_get to cmd
#      jlibName config ?args?
#      jlibName openstream server ?args?
#      jlibName closestream
#      jlibName element_deregister tag func
#      jlibName element_register tag func ?seq?
#      jlibName getstreamattr name
#      jlibName get_features name
#      jlibName get_last to cmd
#      jlibName get_time to cmd
#      jlibName getserver
#      jlibName get_version to cmd
#      jlibName getagent jid
#      jlibName getrecipientjid jid
#      jlibName get_registered_presence_stanzas ?tag? ?xmlns?
#      jlibName haveagent jid
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
#      jlibName roster_get cmd
#      jlibName roster_set item cmd ?args?
#      jlibName roster_remove item cmd
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
#      jlibName unregister_presence_stanza tag xmlns
#      
#  o using the experimental 'conference' protocol:  OUTDATED!
#      jlibName conference get_enter room cmd
#      jlibName conference set_enter room subelements cmd
#      jlibName conference get_create server cmd
#      jlibName conference set_create room subelements cmd
#      jlibName conference delete room cmd
#      jlibName conference exit room
#      jlibName conference set_user room name jid cmd
#      jlibName conference hashandnick room
#      jlibName conference roomname room
#      jlibName conference allroomsin
#      
#      
#   The callbacks given for any of the '-iqcommand', '-messagecommand', 
#   or '-presencecommand' must have the following form:
#   
#      Callback {jlibName type args}
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
#   where 'what' can be any of: connect, disconnect, iqreply, message, xmlerror,
#   version, presence, networkerror, oob, away, xaway, .... Iq elements have
#   the what equal to the last namespace specifier.
#   'args' is a list of '-key value' pairs.
#      
#   @@@ TODO:
#      1) Rewrite from scratch and deliver complete iq, message, and presence
#      elements to callbacks. Callbacks then get attributes like 'from' etc
#      using accessor functions.
#      2) Roster as an ensamble command, just like disco, muc etc.
#      
#-------------------------------------------------------------------------------

package require wrapper
package require roster
package require service
package require stanzaerror
package require streamerror
package require groupchat

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
      {(available|unavailable|subscribe|unsubscribe|subscribed|unsubscribed|invisible)}
    set statics(resetCmds) {}
    
    variable version 1.0
    
    # Running number.
    variable uid 0
    
    # Let jlib components register themselves for subcommands, ensamble,
    # so that they can be invoked by: jlibname subcommand ...
    variable ensamble
    set ensamble(names) {}
    
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
	disco           http://jabber.org/protocol/disco 
	disco,items     http://jabber.org/protocol/disco#items 
	disco,info      http://jabber.org/protocol/disco#info
	caps            http://jabber.org/protocol/caps
	ibb             http://jabber.org/protocol/ibb
	amp             http://jabber.org/protocol/amp
	muc             http://jabber.org/protocol/muc
	muc,user        http://jabber.org/protocol/muc#user
	muc,admin       http://jabber.org/protocol/muc#admin
	muc,owner       http://jabber.org/protocol/muc#owner
	pubsub          http://jabber.org/protocol/pubsub
    }
    
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
    
    if {![llength [info commands lassign]]} {
	proc lassign {vals args} {uplevel 1 [list foreach $args $vals break] }
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

# Collects the 'conference' subcommand.
namespace eval jlib::conference { }

# jlib::new --
#
#       This creates a new instance jlib interpreter.
#       
# Arguments:
#       rostername: the name of the roster object
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
  
proc jlib::new {rostername clientcmd args} {    

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
	variable opts
	variable agent
	# Cache for the 'conference' subcommand.
	variable conf
	variable pres
    }
            
    # Set simpler variable names.
    upvar ${jlibname}::lib      lib
    upvar ${jlibname}::iqcmd    iqcmd
    upvar ${jlibname}::prescmd  prescmd
    upvar ${jlibname}::msgcmd   msgcmd
    upvar ${jlibname}::opts     opts
    upvar ${jlibname}::conf     conf
    upvar ${jlibname}::locals   locals
    
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
    set lib(rostername)   $rostername
    set lib(clientcmd)    $clientcmd
    set lib(wrap)         $wrapper
    
    set lib(isinstream) 0
    set lib(state)      ""
    set lib(transport,name) ""
    
    init_inst $jlibname
            
    # Init conference and groupchat state.
    set conf(allroomsin) {}
    groupchat::init $jlibname
        
    # Register some standard iq handlers that are handled internally.
    iq_register $jlibname get jabber:iq:last    \
      [namespace current]::handle_get_last
    iq_register $jlibname get jabber:iq:time    \
      [namespace current]::handle_get_time
    iq_register $jlibname get jabber:iq:version \
      [namespace current]::handle_get_version
    
    # Create the actual jlib instance procedure.
    proc $jlibname {cmd args}   \
      "eval jlib::cmdproc {$jlibname} \$cmd \$args"
    
    # Init the service layer for this jlib instance.
    service::init $jlibname
    
    # Init ensamble commands.
    foreach name $ensamble(names) {
	uplevel #0 $ensamble($name,init) $jlibname
	#uplevel #0 $ensamble($name,init) $jlibname $args
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
    
    # Any of {available chat away xa dnd invisible unavailable}
    set locals(status)        "unavailable"
    set locals(pres,type)     "unavailable"
    set locals(myjid)         ""
    set locals(trigAutoAway)  1
    set locals(server)        ""
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

# jlib::ensamble_register --
# 
#       Register a sub command.
#       This is then used as: 'jlibName subCmd ...'

proc jlib::ensamble_register {name initProc cmdProc} {
    variable ensamble
    
    set ensamble(names) [lsort -unique [concat $ensamble(names) $name]]
    set ensamble($name,init) $initProc
    set ensamble($name,cmd)  $cmdProc
}

proc jlib::ensamble_deregister {name} {
    variable ensamble
    
    set ensamble(names) [lsearch -all -not -inline $ensamble(names) $name]
    array unset ensamble ${name},*
}

proc jlib::register_reset {cmd} {
    variable statics
    
    lappend statics(resetCmds) $cmd
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

# jlib::getrostername --
# 
#       Just returns the roster instance for this jlib instance.

proc jlib::getrostername {jlibname} {
    
    upvar ${jlibname}::lib lib
    
    return $lib(rostername)
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
	set result {}
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
	array set argsArr $args
	
	# Reschedule auto away only if changed. Before setting new opts!
	if {[info exists argsArr(-autoawaymins)] &&  \
	  ($argsArr(-autoawaymins) != $opts(-autoawaymins))} {
	    schedule_auto_away $jlibname
	}
	if {[info exists argsArr(-xautoawaymins)] &&  \
	  ($argsArr(-xautoawaymins) != $opts(-xautoawaymins))} {
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
    if {[catch {puts -nonewline $lib(sock) $xml} err]} {
	# Error propagated to the caller that calls clientcmd.
	return -code error
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
	uplevel #0 $lib(clientcmd) [list $jlibname networkerror]	  
	return
    }
    
    # Read what we've got.
    if {[catch {read $lib(sock)} data]} {
	kill $jlibname

	# We need to call clientcmd here since async event.
	uplevel #0 $lib(clientcmd) [list $jlibname networkerror]	  
	return
    }
    Debug 2 "RECV: $data"
    
    # Feed the XML parser. When the end of a command element tag is reached,
    # we get a callback to 'jlib::dispatcher'.
    wrapper::parse $lib(wrap) $data
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

    array set argsArr $args
    
    # The server 'to' attribute is only temporary until we have either a 
    # confirmation or a redirection (alias) in received streams 'from' attribute.
    set locals(server) $server
    set locals(last) [clock seconds]
    
    # Make sure we start with a clean state.
    wrapper::reset $lib(wrap)

    # Register a <stream> callback proc.
    if {[info exists argsArr(-cmd)] && [llength $argsArr(-cmd)]} {
	set lib(streamcmd) $argsArr(-cmd)
    }
    set optattr ""
    foreach {key value} $args {
	
	switch -- $key {
	    -cmd - -socket {
		# empty
	    }
	    default {
		set attr [string trimleft $key "-"]
		append optattr " $attr='$value'"
	    }
	}
    }
    set lib(isinstream) 1
    set lib(state)      "instream"

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
	sendraw $jlibname $xml
	set lib(isinstream) 0
    }
    kill $jlibname
}

# jlib::reporterror --
# 
#       Used for transports to report async, fatal and nonrecoverable errors.

proc jlib::reporterror {jlibname err {msg ""}} {
    
    upvar ${jlibname}::lib lib
    
    Debug 4 "jlib::reporterror"

    kill $jlibname
    uplevel #0 $lib(clientcmd) [list $jlibname $err -errormsg $msg]
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
	    element_run_hook $jlibname $tag $xmldata
	}
	error {
	    error_handler $jlibname $xmldata
	}
	default {
	    element_run_hook $jlibname $tag $xmldata
	}
    }
}

# jlib::iq_handler --
#
#       Callback for incoming <iq> elements.
#       The handling sequence is the following:
#       1) handle all roster pushes (set) internally
#       2) handle all preregistered callbacks via id attributes
#       3) handle callbacks specific for 'type' and 'xmlns' that have been
#          registered with 'iq_register'
#       4) if unhandled by 3, use any -iqcommand callback
#       5) if still, use the client command callback
#       6) if type='get' and still unhandled, return an error element
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

    Debug 5 "jlib::iq_handler: ------------"

    # Extract the command level XML data items.    
    set tag [wrapper::gettag $xmldata]
    array set attrArr [wrapper::getattrlist $xmldata]
    
    # Make an argument list ('-key value' pairs) suitable for callbacks.
    # Make variables of the attributes.
    set arglist {}
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
    
    # @@@ The child must be a single <query> element (or any namespaced element).
    # WRONG WRONG !!!!!!!!!!!!!!!
    set childlist [wrapper::getchildren $xmldata]
    set subiq [lindex $childlist 0]
    set xmlns [wrapper::getattribute $subiq xmlns]
    
    if {[string equal $type "error"]} {
	set callbackType "error"
    } elseif {[regexp {.*:([^ :]+)$} $xmlns match callbackType]} {
	# empty
    } else {
	set callbackType "iqreply"
    }
    set ishandled 0

    # (1) This is a server push! Handle internally.

    if {[string equal $type "set"]} {
	
	switch -- $xmlns {
	    jabber:iq:roster {
		
		# Found a roster-push, typically after a subscription event.
		# First, we reply to the server, saying that, we 
		# got the data, and accepted it. ???		    
		# We call the 'parse_roster_get', because this
		# data is the same as the one we get from a 'roster_get'.
		
		parse_roster_get $jlibname 1 {} ok $subiq
		# @@@
		#parse_roster_get $jlibname 1 {} set $subiq
		set ishandled 1
	    }
	}
    }
    
    # (2) Handle all preregistered callbacks via id attributes.
    #     Must be type 'result' or 'error'.
    #     Some components use type='set' instead of 'result'.

    # @@@ It would be better not to have separate calls for errors.
    
    switch -- $type {
	result - set {
	    
	    # Protect us from our own 'set' calls when we are awaiting 
	    # 'result' or 'error'.
	    set setus 0
	    if {[string equal $type "set"]  \
	      && [string equal $afrom $locals(myjid)]} {
		set setus 1
	    }

	    # A request for the entire roster is coming this way, 
	    # and calls 'parse_roster_set'.
	    # $iqcmd($id) contains the 'parse_...' call as 1st element.
	    if {!$setus && [info exists id] && [info exists iqcmd($id)]} {
		
		# @@@ TODO: add attrArr to callback.
		# BETTER: deliver complete xml!
		uplevel #0 $iqcmd($id) [list result $subiq]
		        
		#uplevel #0 $iqcmd($id) [list result $subiq] $arglist
		
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
		
		#uplevel #0 $iqcmd($id) [list error $xmldata]
		
		unset -nocomplain iqcmd($id)
		set ishandled 1
	    }	    
	}
    }
	        
    # (3) Handle callbacks specific for 'type' and 'xmlns' that have been
    #     registered with 'iq_register'

    if {[string equal $ishandled "0"]} {
	set ishandled [eval {
	    iq_run_hook $jlibname $type $xmlns $afrom $subiq} $arglist]
    }
    
    # (4) If unhandled by 3, use any -iqcommand callback.

    if {[string equal $ishandled "0"]} {	
	if {[string length $opts(-iqcommand)]} {
	    set iqcallback [concat  \
	      [list $jlibname $type -query $subiq] $arglist]
	    set ishandled [uplevel #0 $opts(-iqcommand) $iqcallback]
	} 
	    
	# (5) If unhandled by 3 and 4, use the client command callback.

	if {[string equal $ishandled "0"]} {
	    set clientcallback [concat  \
	      [list $jlibname $callbackType -query $subiq] $arglist]
	    set ishandled [uplevel #0 $lib(clientcmd) $clientcallback]
	}

	# (6) If type='get' or 'set', and still unhandled, return an error element.

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
      -attrlist [list type error to $jid id $id]  \
      -subtags [list $errElem]]

    jlib::send $jlibname $iqElem
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
    set xmlnsList  {}
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
	    uplevel #0 $opts(-messagecommand) [list $jlibname $type] $arglist
	} else {
	    uplevel #0 $lib(clientcmd) [list $jlibname message] $arglist
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

    jlib::send $jlibname $msgElem
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

    upvar ${jlibname}::lib lib
    upvar ${jlibname}::prescmd prescmd
    upvar ${jlibname}::opts opts
    upvar ${jlibname}::locals locals
    
    # Extract the command level XML data items.
    set attrlist  [wrapper::getattrlist $xmldata]
    set childlist [wrapper::getchildren $xmldata]
    array set attrArr $attrlist
    
    # Make an argument list ('-key value' pairs) suitable for callbacks.
    # Make variables of the attributes.
    set arglist {}
    set type "available"
    set from $locals(server)
    foreach {attrkey attrval} $attrlist {
	set $attrkey $attrval
	lappend arglist -$attrkey $attrval
    }

    # This helps callbacks to adapt to using full element as argument.
    lappend arglist -xmldata $xmldata

    # Check first if this is an error element (from conferencing?).
    if {[string equal $type "error"]} {
	set errspec [getstanzaerrorspec $xmldata]
	lappend arglist -error $errspec
    } else {
	
	# Extract the presence sub-elements. Separate the x element.
	set x {}
	set extras {}
	foreach child $childlist {
	    
	    # Extract the presence sub-elements XML data items.
	    set ctag [wrapper::gettag $child]
	    set cchdata [wrapper::getcdata $child]
	    
	    switch -- $ctag {
		status - priority - show {
		    if {$ctag eq "show"} {
			set cchdata [string tolower $cchdata]
		    }
		    lappend params $ctag $cchdata
		    lappend arglist -$ctag $cchdata
		}
		x {
		    lappend x $child
		}
		default {
		    
		    # This can be anything properly namespaced.
		    lappend extras $child
		}
	    }
	}	    
	if {[llength $x] > 0} {
	    lappend arglist -x $x
	}
	if {[llength $extras] > 0} {
	    lappend arglist -extras $extras
	}
	
	# Do different things depending on the 'type' attribute.
	if {[string equal $type "available"] ||  \
	  [string equal $type "unavailable"]} {
	    
	    # Not sure if we should exclude roster here since this
	    # is not pushed to us but requested.
	    # It must be set for presence sent to groupchat rooms!
	    
	    # Set presence in our roster object
	    eval {$lib(rostername) setpresence $from $type} $arglist
	} else {
	    
	    # We probably need to respond to the 'presence' element;
	    # 'subscribed'?. ????????????????? via lib(rostername)
	    # If we have 'unsubscribe'd another users presence it cannot be
	    # anything else than 'unavailable' anymore.
	    if {[string equal $type "unsubscribed"]} {
		$lib(rostername) setpresence $from "unsubscribed"
	    }
	    if {[string length $opts(-presencecommand)]} {
		uplevel #0 $opts(-presencecommand) [list $jlibname $type] $arglist
	    } else {
		uplevel #0 $lib(clientcmd) [list $jlibname presence] $arglist
	    }	
	}
    }
    
    # Invoke any callback before the rosters callback.
    if {[info exists id] && [info exists prescmd($id)]} {
	uplevel #0 $prescmd($id) [list $jlibname $type] $arglist
	unset -nocomplain prescmd($id)
    }	
    if {![string equal $type "error"]} {
	eval {$lib(rostername) invokecommand $from $type} $arglist
    }
    
    #     Handle callbacks specific for 'type' that have been
    #     registered with 'presence_register'

    eval {presence_run_hook $jlibname $from $type} $arglist
    presence_ex_run_hook $jlibname $xmldata
}

# jlib::features_handler --
# 
#       Callback for the <stream:features> element.

proc jlib::features_handler {jlibname xmllist} {

    upvar ${jlibname}::locals locals
    variable xmppxmlns
    
    Debug 4 "jlib::features_handler"
    
    foreach child [wrapper::getchildren $xmllist] {
	wrapper::splitxml $child tag attr chdata children
	
	switch -- $tag {
	    mechanisms {
		set mechanisms {}
		if {[wrapper::getattr $attr xmlns] eq $xmppxmlns(sasl)} {
		    foreach mechelem $children {
			wrapper::splitxml $mechelem mtag mattr mchdata mchild
			if {$mtag eq "mechanism"} {
			    lappend mechanisms $mchdata
			}
		    }
		}

		# Variable that may trigger a trace event.
		set locals(features,mechanisms) $mechanisms
	    }
	    starttls {
		if {[wrapper::getattr $attr xmlns] eq $xmppxmlns(tls)} {
		    set locals(features,starttls) 1
		    set childs [wrapper::getchildswithtag $xmllist required]
		    if {$childs ne ""} {
			set locals(features,starttls,required) 1
		    }
		}
	    }
	    default {
		set locals(features,$tag) 1
	    }
	}
    }
    
    # Variable that may trigger a trace event.
    set locals(features) 1
}

# jlib::get_features --
# 
#       Just to get access of the stream features.

proc jlib::get_features {jlibname name {name2 ""}} {
    
    upvar ${jlibname}::locals locals

    set ans ""
    if {$name2 ne ""} {
	if {[info exists locals(features,$name,$name2)]} {
	    set ans $locals(features,$name,$name2)
	}
    } else {
	if {[info exists locals(features,$name)]} {
	    set ans $locals(features,$name)
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

    uplevel #0 $lib(clientcmd) [list $jlibname connect]
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
    uplevel #0 $lib(clientcmd) [list $jlibname disconnect]
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

    upvar ${jlibname}::lib lib
    variable xmppxmlns
    
    Debug 4 "jlib::error_handler"
    
    # This should handle all internal stuff.
    closestream $jlibname
    
    if {[llength [wrapper::getchildren $xmllist]]} {
	set errspec [getstreamerrorspec $xmllist]
    } else {
	set errspec [list unknown [wrapper::getcdata $xmllist]]
    }
    set errmsg [lindex $errspec 1]
    uplevel #0 $lib(clientcmd) [list $jlibname streamerror -errormsg $errmsg]
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

    upvar ${jlibname}::lib lib

    Debug 4 "jlib::xmlerror jlibname=$jlibname, args='$args'"
    
    # This should handle all internal stuff.
    closestream $jlibname

    uplevel #0 $lib(clientcmd) [list $jlibname xmlerror -errormsg $args]
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
    upvar ${jlibname}::agent agent
    upvar ${jlibname}::locals locals
    variable statics
    
    Debug 4 "jlib::reset"
    
    cancel_auto_away $jlibname
    
    set num $iqcmd(uid)
    unset -nocomplain iqcmd
    set iqcmd(uid) $num
    
    set num $prescmd(uid)
    unset -nocomplain prescmd
    set prescmd(uid) $num
    
    unset -nocomplain agent    
    unset -nocomplain locals
    
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
    foreach cmd $statics(resetCmds) {
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
    
    array unset locals features*
    array unset locals streamattr,*
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
#       none.

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
	if {$errmsg ne ""} {
	    append errmsg ". "
	}
	append errmsg $errstr
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

    set xmllist [wrapper::createtag bind       \
      -attrlist [list xmlns $xmppxmlns(bind)]  \
      -subtags [list [wrapper::createtag resource -chdata $resource]]]
    send_iq $jlibname set [list $xmllist]  \
      -command [list [namespace current]::parse_bind_resource $jlibname $cmd]
}

proc jlib::parse_bind_resource {jlibname cmd type subiq args} {
    
    upvar ${jlibname}::locals locals
    variable xmppxmlns
    
    # The server MAY change the 'resource' why we need to check this here.
    if {[string equal [wrapper::gettag $subiq] bind] &&  \
      [string equal [wrapper::getattribute $subiq xmlns] $xmppxmlns(bind)]} {
	set jidElem [wrapper::getchildswithtag $subiq jid]
	if {[llength $jidElem]} {
	    set sjid [wrapper::getcdata $jidElem]
	    splitjid $sjid sjid2 sresource
	    if {![string equal [resourcemap $locals(resource)] $sresource]} {
		set locals(resource) $sresource
		set locals(myjid) "$locals(myjid2)/$sresource"
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

# jlib::parse_roster_get --
#
#       Callback command from the 'roster_get' call.
#       Could also be a roster push from the server.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       ispush:     is this the result of a roster push or from our 
#                   'roster_set' call?
#       cmd:        callback command for an error element.
#       type:       "error" or "ok"
#       thequery:       
#       
# Results:
#       the roster object is populated.

proc jlib::parse_roster_get {jlibname ispush cmd type thequery} {

    upvar ${jlibname}::lib lib

    Debug 3 "jlib::parse_roster_get ispush=$ispush, cmd=$cmd, type=$type,"
    Debug 3 "   thequery=$thequery"
    if {[string equal $type "error"]} {
	
	# We've got an error reply. Roster pushes should never be an error!
	if {[string length $cmd] > 0} {
	    uplevel #0 $cmd [list $jlibname error]
	}
	return
    }
    if {!$ispush} {
	
	# Clear the roster and presence.
	$lib(rostername) enterroster
    }
    
    # Extract the XML data items.
    if {![string equal [wrapper::getattribute $thequery xmlns] "jabber:iq:roster"]} {
    
	# Here we should issue a warning:
	# attribute of query tag doesn't match 'jabber:iq:roster'
	
    }    
    if {$ispush} {
	set what "roster_push"
    } else {
	set what "roster_item"
    }
    foreach child [wrapper::getchildren $thequery] {
	
	# Extract the message sub-elements XML data items.
	set ctag [wrapper::gettag $child]
	set cattrlist [wrapper::getattrlist $child]
	set cchdata [wrapper::getcdata $child]
	
	if {[string equal $ctag "item"]} {
	    
	    # Add each item to our roster object.
	    # Build the argument list of '-key value' pairs. Extract the jid.
	    set arglist {}
	    set subscription {}
	    foreach {key value} $cattrlist {
		if {[string equal $key "jid"]} {
		    set jid $value
		} else {
		    lappend arglist -$key $value
		    if {[string equal $key "subscription"]} {
			set subscription $value
		    }
		}
	    }
	    
	    # Check if item should be romoved (subscription='remove').
	    if {[string equal $subscription "remove"]} {
		$lib(rostername) removeitem $jid
	    } else {
	    
		# Collect the group elements.
		set groups {}
		foreach subchild [wrapper::getchildren $child] {
		    set subtag [wrapper::gettag $subchild]
		    if {[string equal $subtag "group"]} {
			lappend groups [wrapper::getcdata $subchild]
		    }
		}
		if {[string length $groups]} {
		    lappend arglist -groups $groups
		}
		
		# Fill in our roster with this.
		eval {$lib(rostername) setrosteritem $jid} $arglist
	    }
	}
    }
    
    # Tell our roster object that we leave...
    if {!$ispush} {
	$lib(rostername) exitroster
    }
}

# jlib::parse_roster_set --
#
#       Callback command from the 'roster_set' call.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        the jabber id (without resource).
#       cmd:        callback command for an error query element.
#       groups:     
#       name:       
#       type:       "error" or "ok"
#       thequery:
#       
# Results:
#       none.

proc jlib::parse_roster_set {jlibname jid cmd groups name type thequery} {

    upvar ${jlibname}::lib lib

    Debug 3 "jlib::parse_roster_set jid=$jid"
    if {[string equal $type "error"]} {
	
	# We've got an error reply.
	uplevel #0 $cmd [list $jlibname error]
	return
    }
}

# jlib::parse_roster_remove --
#
#       Callback command from the 'roster_remove' command.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        the jabber id (without resource).
#       cmd:        callback command for an error query element.
#       type:
#       thequery:
#       
# Results:
#       none.

proc jlib::parse_roster_remove {jlibname jid cmd type thequery} {

    Debug 3 "jlib::parse_roster_remove jid=$jid, cmd=$cmd, type=$type,"
    Debug 3 "   thequery=$thequery"
    if {[string equal $type "error"]} {
	uplevel #0 $cmd [list $jlibname error]
    }
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

proc jlib::message_run_hook {jlibname type xmlns msgElem args} {
    
    upvar ${jlibname}::msghook msghook

    set ishandled 0
    
    foreach key [list $type,$xmlns *,$xmlns $type,*] {
	if {[info exists msghook($key)]} {
	    foreach spec $msghook($key) {
		set func [lindex $spec 0]
		set code [catch {
		    uplevel #0 $func [list $jlibname $xmlns $msgElem] $args
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

# jlib::presence_register --
# 
#       Handler for registered presence callbacks.
#       
#       @@@ We should be able to register for certain jid's
#           such as rooms and members using wildcards.

proc jlib::presence_register {jlibname type func {seq 50}} {
    
    upvar ${jlibname}::preshook preshook
    
    lappend preshook($type) [list $func $seq]
    set preshook($type)  \
      [lsort -integer -index 1 [lsort -unique $preshook($type)]]
}

proc jlib::presence_run_hook {jlibname from type args} {
    
    upvar ${jlibname}::preshook preshook

    set ishandled 0
    
    if {[info exists preshook($type)]} {
	foreach spec $preshook($type) {
	    set func [lindex $spec 0]
	    set code [catch {
		uplevel #0 $func [list $jlibname $from $type] $args
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

proc jlib::presence_deregister {jlibname type func} {
    
    upvar ${jlibname}::preshook preshook
    
    if {[info exists preshook($type)]} {
	set idx [lsearch -glob $preshook($type) "$func *"]
	if {$idx >= 0} {
	    set preshook($type) [lreplace $preshook($type) $idx $idx]
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

proc jlib::presence_register_ex {jlibname func args} {
    
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
	}
    }
    set pat "$type,$from,$from2"
    
    # The 'opts' must be ordered.
    set opts {}
    foreach key [array names aopts] {
	lappend opts $key $aopts($key)
    }
    lappend expreshook($pat) [list $opts $func $seq]
    set expreshook($pat)  \
      [lsort -integer -index 2 [lsort -unique $expreshook($pat)]]  
}

proc jlib::presence_ex_run_hook {jlibname xmldata} {

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
    jlib::splitjid $from from2 -
    set pkey "$type,$from,$from2"
    
    #puts "\t pkey=$pkey"
    
    # Make matching in two steps, attributes and elements.
    # First the attributes.
    set matched {}
    foreach {pat value} [array get expreshook] {
	#puts "\t pat=$pat"
	if {[string match $pat $pkey]} {
	    
	    foreach spec $value {
		#puts "\t\t spec=$spec"
    
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
	set tagxmlns {}
	foreach c [wrapper::getchildren $xmldata] {
	    set xmlns [wrapper::getattribute $c xmlns]
	    lappend tagxmlns [list [wrapper::gettag $c] $xmlns]	    
	}
	#puts "\t matched=$matched"
	#puts "\t tagxmlns=$tagxmlns"

	foreach spec $matched {
	    #puts "\t spec=$spec"
	    array set opts {-tag * -xmlns *}
	    array set opts [lindex $spec 0]

	    # The 'olist' must be ordered.
	    set olist [list $opts(-tag) $opts(-xmlns)]
	    #puts "\t olist=$olist"	
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

proc jlib::presence_deregister_ex {jlibname func args} {
    
    upvar ${jlibname}::expreshook expreshook
    
    set type  "*"
    set from  "*"
    set from2 "*"
    set seq   50
    set spec  {}

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
		lappend spec $key $value
	    }
	}
    }
    set pat "$type,$from,$from2"
    if {[info exists expreshook($pat)]} {
	# @@@ TODO
	set idx [lsearch -glob $expreshook($pat) "$func *"]
	if {$idx >= 0} {
	    set expreshook($type) [lreplace $expreshook($type) $idx $idx]
	}
	
	
    }
}

if {0} {
    proc cb {args} {puts "-+-+-+-+ $args"}
    proc cx {args} {puts "xxxxxxxx $args"}
    jlib::jlib1 presence_register_ex cb -type available
    jlib::jlib1 presence_register_ex cb -type available -from2 matben2@localhost
    jlib::jlib1 presence_register_ex cx -type available -tag x
    jlib::jlib1 presence_register_ex cx -type available -tag x -xmlns jabber:x:avatar
    parray ::jlib::jlib1::expreshook
}

# jlib::element_register --
# 
#       Used to get callbacks from non stanza elements, like sasl etc.

proc jlib::element_register {jlibname tag func {seq 50}} {
    
    upvar ${jlibname}::elementhook elementhook
    
    lappend elementhook($tag) [list $func $seq]
    set elementhook($tag)  \
      [lsort -integer -index 1 [lsort -unique $elementhook($tag)]]
}

proc jlib::element_deregister {jlibname tag func} {
    
    upvar ${jlibname}::elementhook elementhook
    
    if {![info exists elementhook($tag)]} {
	return
    }
    set ind -1
    set found 0
    foreach spec $elementhook($tag) {
	incr ind
	if {[string equal $func [lindex $spec 0]]} {
	    set found 1
	    break
	}
    }
    if {$found} {
	set elementhook($tag) [lreplace $elementhook($tag) $ind $ind]
    }
}

proc jlib::element_run_hook {jlibname tag xmldata} {
    
    upvar ${jlibname}::elementhook elementhook

    set ishandled 0
    
    if {[info exists elementhook($tag)]} {
	foreach spec $elementhook($tag) {
	    set func [lindex $spec 0]
	    set code [catch {
		uplevel #0 $func [list $jlibname $tag $xmldata]
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
    
    array set argsArr $args
    set attrlist [list "type" $type]
    
    # Need to generate a unique identifier (id) for this packet.
    if {[string equal $type "get"] || [string equal $type "set"]} {
	lappend attrlist "id" $iqcmd(uid)
	
	# Record any callback procedure.
	if {[info exists argsArr(-command)]} {
	    set iqcmd($iqcmd(uid)) $argsArr(-command)
	}
	incr iqcmd(uid)
    } elseif {[info exists argsArr(-id)]} {
	lappend attrlist "id" $argsArr(-id)
    }
    if {[info exists argsArr(-to)]} {
	lappend attrlist "to" $argsArr(-to)
    }
    if {[llength $xmldata]} {
	set xmllist [wrapper::createtag "iq" -attrlist $attrlist \
	  -subtags $xmldata]
    } else {
	set xmllist [wrapper::createtag "iq" -attrlist $attrlist]
    }
    
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

    set opts {}
    set sublists {}
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

    set opts {}
    set sublists {}
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
    set toopt {}

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

    array set argsArr $args
    set xmllist [wrapper::createtag "query" -attrlist {xmlns jabber:iq:register}]
    if {[info exists argsArr(-to)]} {
	set toopt [list -to $argsArr(-to)]
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
    array set argsArr $args
    foreach argsswitch [array names argsArr] {
	if {[string equal $argsswitch "-to"]} {
	    continue
	}
	set par [string trimleft $argsswitch {-}]
	lappend subelements [wrapper::createtag $par  \
	  -chdata $argsArr($argsswitch)]
    }
    set xmllist [wrapper::createtag "query"  \
      -attrlist {xmlns jabber:iq:register}   \
      -subtags $subelements]
    
    if {[info exists argsArr(-to)]} {
	set toopt [list -to $argsArr(-to)]
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
    array set argsArr $args
    if {[info exists argsArr(-key)]} {
	lappend subelements [wrapper::createtag "key" -chdata $argsArr(-key)]
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

    set argsarr(-subtags) {}
    array set argsarr $args

    set xmllist [wrapper::createtag "query"  \
      -attrlist {xmlns jabber:iq:search}   \
      -subtags $argsarr(-subtags)]
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
    
    array set argsArr $args
    set attrlist [list to $to]
    set children {}
    
    foreach {name value} $args {
	set par [string trimleft $name "-"]
	
	switch -- $name {
	    -command {
		set uid $msgcmd(uid)
		lappend attrlist "id" $uid
		set msgcmd($uid) $value
		incr msgcmd(uid)
		
		# There exist a weird situation if we send to ourself.
		# Skip this registered command the 1st time we get this,
		# and let any handlers take over. Trigger this 2nd time.
		if {[string equal $to $locals(myjid)]} {
		    set msgcmd($uid,self) 1
		}
	    }
	    -xlist {
		foreach xchild $value {
		    lappend children $xchild
		}
	    }
	    -type {
		if {![string equal $value "normal"]} {
		    lappend attrlist "type" $value
		}
	    }
	    -id {
		lappend attrlist $par $value
	    }
	    default {
		lappend children [wrapper::createtag $par -chdata $value]
	    }
	}
    }
    set xmllist [wrapper::createtag "message" -attrlist $attrlist  \
      -subtags $children]
    
    send $jlibname $xmllist
    return
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
    
    set attrlist {}
    set children {}
    set directed 0
    set keep     0
    set type "available"
    array set argsArr $args
    
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
	    if {[info exists argsArr(-$name)]} {
		set locals(pres,$name) $argsArr(-$name)
	    } elseif {[info exists locals(pres,$name)]} {
		if {$keep} {
		    lappend children [wrapper::createtag $name  \
		      -chdata $locals(pres,$name)]
		} else {
		    unset -nocomplain locals(pres,$name)
		}
	    }
	}
	if {[info exists argsArr(-priority)]} {
	    set locals(pres,priority) $argsArr(-priority)
	} elseif {[info exists locals(pres,priority)]} {
	    lappend children [wrapper::createtag "priority"  \
	      -chdata $locals(pres,priority)]
	}

	set locals(pres,type) $type

	set locals(status) $type
	if {[info exists argsArr(-show)]} {
	    set locals(status) $argsArr(-show)
	    set locals(pres,show) $argsArr(-show)
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
#       
# Arguments:
#       jlibname:   the instance of this jlib
#       elem:       xml element
#       args        -type  available | unavailable | ...

proc jlib::register_presence_stanza {jlibname elem args} {

    upvar ${jlibname}::pres pres

    set aargs(-type) ""
    array set aargs $args
    set type $aargs(-type)
    
    set tag   [wrapper::gettag $elem]
    set xmlns [wrapper::getattribute $elem xmlns]
    set pres(stanza,$tag,$xmlns,$type) $elem
}

proc jlib::unregister_presence_stanza {jlibname tag xmlns} {
    
    upvar ${jlibname}::pres pres
    
    array unset pres "stanza,$tag,$xmlns,*"
}

proc jlib::get_registered_presence_stanzas {jlibname {tag *} {xmlns *}} {
    
    upvar ${jlibname}::pres pres
    
    set stanzas {}
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
	    uplevel #0 $lib(clientcmd) [list $jlibname networkerror]
	}
    }
    return
}

proc jlib::sendraw {jlibname xml} {
    
    upvar ${jlibname}::lib lib

    $lib(transport,send) $jlibname $xml
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
    array set argsarr $args
    if {[info exists argsarr(-desc)] && [string length $argsarr(-desc)]} {
	lappend children [wrapper::createtag {desc} -chdata $argsarr(-desc)]
    }
    set xmllist [wrapper::createtag query -attrlist $attrlist  \
      -subtags $children]
    send_iq $jlibname set [list $xmllist] -to $to -command  \
      [list [namespace current]::invoke_iq_callback $jlibname $cmd]
    return
}

# jlib::agent_get --
#
#       It implements the 'jabber:iq:agent' get method.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       to:         the *server's* name! (users.jabber.org, for instance)
#       cmd:        client command to be executed at the iq "result" element.
#       
# Results:
#       none.

proc jlib::agent_get {jlibname to cmd} {

    set xmllist [wrapper::createtag "query" -attrlist {xmlns jabber:iq:agent}]
    send_iq $jlibname "get" [list $xmllist] -to $to -command   \
      [list [namespace current]::parse_agent_get $jlibname $to $cmd]
    return
}

proc jlib::agents_get {jlibname to cmd} {

    set xmllist [wrapper::createtag "query" -attrlist {xmlns jabber:iq:agents}]
    send_iq $jlibname "get" [list $xmllist] -to $to -command   \
      [list [namespace current]::parse_agents_get $jlibname $to $cmd]
    return
}

# parse_agent_get, parse_agents_get --
#
#       Callbacks for the agent(s) methods. Caches agent information,
#       and makes registered client callback.
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        the 'to' attribute of our agent(s) request.
#       cmd:        client command to be executed.
#       
# Results:
#       none.

proc jlib::parse_agent_get {jlibname jid cmd type subiq} {

    upvar ${jlibname}::lib lib
    upvar ${jlibname}::agent agent
    upvar [namespace current]::service::services services

    Debug 3 "jlib::parse_agent_get jid=$jid, cmd=$cmd, type=$type, subiq=$subiq"

    switch -- $type {
	error {
	    uplevel #0 $cmd [list $jlibname error $subiq]
	} 
	default {
     
	    # Loop through the subelement to see what we've got.
	    foreach elem [wrapper::getchildren $subiq] {
		set tag [wrapper::gettag $elem]
		set agent($jid,$tag) [wrapper::getcdata $elem]
		if {[lsearch $services $tag] >= 0} {
		    lappend agent($tag) $jid
		}
		if {[string equal $tag "groupchat"]} {
		    [namespace current]::service::registergcprotocol  \
		      $jlibname $jid "gc-1.0"
		}
	    }    
	    uplevel #0 $cmd [list $jlibname $type $subiq]
	}
    }
}

proc jlib::parse_agents_get {jlibname jid cmd type subiq} {

    upvar ${jlibname}::locals locals
    upvar ${jlibname}::agent agent
    upvar [namespace current]::service::services services

    Debug 3 "jlib::parse_agents_get jid=$jid, cmd=$cmd, type=$type, subiq=$subiq"

    switch -- $type {
	error {
	    uplevel #0 $cmd [list $jlibname error $subiq]
	} 
	default {
	    
	    # Be sure that the login jabber server is the root.
	    if {[string equal $locals(server) $jid]} {
		set agent($jid,parent) {}
	    }
	    # ???
	    set agent($jid,parent) {}
	    
	    # Cache the agents info we've got.
	    foreach agentElem [wrapper::getchildren $subiq] {
		if {![string equal [wrapper::gettag $agentElem] "agent"]} {
		    continue
		}
		set jidAgent [wrapper::getattribute $agentElem jid]
		set subAgent [wrapper::getchildren $agentElem]
		
		# Loop through the subelement to see what we've got.
		foreach elem $subAgent {
		    set tag [wrapper::gettag $elem]
		    set agent($jidAgent,$tag) [wrapper::getcdata $elem]
		    if {[lsearch $services $tag] >= 0} {
			lappend agent($tag) $jidAgent
		    }
		    if {[string equal $tag "groupchat"]} {
			[namespace current]::service::registergcprotocol  \
			  $jlibname $jid "gc-1.0"
		    }
		}
		set agent($jidAgent,parent) $jid
		lappend agent($jid,childs) $jidAgent	
	    }
	    uplevel #0 $cmd [list $jlibname $type $subiq]
	}
    }
}

# jlib::getagent --
# 
#       Accessor function for the agent stuff.

proc jlib::getagent {jlibname jid} {

    upvar ${jlibname}::agent agent

    if {[info exists agent($jid,parent)]} {
	return [array get agent [jlib::ESC $jid],*]
    } else {
	return
    }
}

proc jlib::have_agent {jlibname jid} {

    upvar ${jlibname}::agent agent

    if {[info exists agent($jid,parent)]} {
	return 1
    } else {
	return 0
    }
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
    
    array set argsarr $args

    set secs [expr [clock seconds] - $locals(last)]
    set xmllist [wrapper::createtag "query"  \
      -attrlist [list xmlns jabber:iq:last seconds $secs]]
    
    set opts {}
    if {[info exists argsarr(-from)]} {
	lappend opts -to $argsarr(-from)
    }
    if {[info exists argsarr(-id)]} {
	lappend opts -id $argsarr(-id)
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
    
    array set argsarr $args
    
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

    set opts {}
    if {[info exists argsarr(-from)]} {
	lappend opts -to $argsarr(-from)
    }
    if {[info exists argsarr(-id)]} {
	lappend opts -id $argsarr(-id)
    }
    eval {send_iq $jlibname "result" [list $xmllist]} $opts

    # Tell jlib's iq-handler that we handled the event.
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
    
    array set argsArr $args
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
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

# jlib::roster_get --
#
#       To get your roster from server.
#       All roster info is propagated to the client via the callback in the
#       roster object. The 'cmd' is only called as a response to an iq-result
#       element.
#
# Arguments:
#       
#       jlibname:   the instance of this jlib.
#       args:       ?
#       cmd:        callback command for an error query element.
#     
# Results:
#       none.
  
proc jlib::roster_get {jlibname cmd args} {

    array set argsArr $args  
    
    set xmllist [wrapper::createtag "query"  \
      -attrlist {xmlns jabber:iq:roster}]
    send_iq $jlibname "get" [list $xmllist] -command   \
      [list [namespace current]::parse_roster_get $jlibname 0 $cmd]
    return
}

# jlib::roster_set --
#
#       To set/add an jid in/to your roster.
#       All roster info is propagated to the client via the callback in the
#       roster object. The 'cmd' is only called as a response to an iq-result
#       element.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        jabber user id to add/set.
#       cmd:        callback command for an error query element.
#       args:
#           -name $name:     A name to show the user-id as on roster to the user.
#           -groups $group_list: Groups of user. If you omit this, then the user's
#                            groups will be set according to the user's options
#                            stored in the roster object. If user doesn't exist,
#                            or you haven't got your roster, user's groups will be
#                            set to "", which means no groups.
#       
# Results:
#       none.
 
proc jlib::roster_set {jlibname jid cmd args} {

    upvar ${jlibname}::lib lib

    Debug 3 "jlib::roster_set jid=$jid, cmd=$cmd, args='$args'"
    array set argsArr $args  

    # Find group(s).
    if {![info exists argsArr(-groups)]} {
	set groups [$lib(rostername) getgroups $jid]
    } else {
	set groups $argsArr(-groups)
    }
    
    set attrlist [list {jid} $jid]
    set name {}
    if {[info exists argsArr(-name)]} {
	set name $argsArr(-name)
	lappend attrlist {name} $name
    }
    set subdata {}
    foreach group $groups {
    	if {$group ne ""} {
	    lappend subdata [wrapper::createtag "group" -chdata $group]
	}
    }
    
    set xmllist [wrapper::createtag "query"   \
      -attrlist {xmlns jabber:iq:roster}      \
      -subtags [list [wrapper::createtag {item} -attrlist $attrlist  \
      -subtags $subdata]]]
    send_iq $jlibname "set" [list $xmllist] -command   \
      [list [namespace current]::parse_roster_set $jlibname $jid $cmd  \
      $groups $name]
    return
}

# jlib::roster_remove --
#
#       To remove an item in your roster.
#       All roster info is propagated to the client via the callback in the
#       roster object. The 'cmd' is only called as a response to an iq-result
#       element.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        jabber user id.
#       cmd:        callback command for an error query element.
#       args:       ?
#       
# Results:
#       none.

proc jlib::roster_remove {jlibname jid cmd args} {

    Debug 3 "jlib::roster_remove jid=$jid, cmd=$cmd, args=$args"
    
    set xmllist [wrapper::createtag "query"   \
      -attrlist {xmlns jabber:iq:roster}      \
      -subtags [list  \
      [wrapper::createtag "item"  \
      -attrlist [list jid $jid subscription remove]]]]
    send_iq $jlibname "set" [list $xmllist] -command   \
      [list [namespace current]::parse_roster_remove $jlibname $jid $cmd]
    return
}

# jlib::schedule_keepalive --
# 
#       Supposed to detect network failures but seems not to work like that.

proc jlib::schedule_keepalive {jlibname} {   

    upvar ${jlibname}::locals locals
    upvar ${jlibname}::opts opts
    upvar ${jlibname}::lib lib

    if {$opts(-keepalivesecs) && $lib(isinstream)} {
	Debug 2 "SEND:"
	if {[catch {
	    puts -nonewline $lib(sock) "\n"
	    flush $lib(sock)
	} err]} {
	    closestream $jlibname
	    set errmsg "Network was disconnected"
	    uplevel #0 $lib(clientcmd) [list $jlibname networkerror -errormsg $errmsg]   
	    return
	}
	set locals(aliveid) [after [expr 1000 * $opts(-keepalivesecs)] \
	  [list [namespace current]::schedule_keepalive $jlibname]]
    }
}

# jlib::schedule_auto_away, cancel_auto_away, auto_away_cmd
#
#       Procedures for auto away things.

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

proc jlib::getrecipientjid {jlibname jid} {

    upvar ${jlibname}::lib lib
    
    splitjid $jid jid2 resource 
    set isroom [[namespace current]::service::isroom $jlibname $jid2]
    if {$isroom} {
	return $jid
    } elseif {[$lib(rostername) isavailable $jid]} {
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

proc jlib::ESC {s} {
    return [string map {* \\* ? \\? [ \\[ ] \\] \\ \\\\} $s]
}

# STRINGPREPs for the differnt parts of jids.

proc jlib::UnicodeListToRE {ulist} {
    
    set str [string map {- -\\u} $ulist]
    set str "\\u[join $str \\u]"
    return [subst $str]
}

namespace eval jlib {
    
    # Characters that need to be escaped since non valid.
    #       JEP-0106 EXPERIMENTAL!  Think OUTDATED???
    variable jidesc { "#\&'/:<>@}
    
    # Prohibited ASCII characters.
    set asciiC12C22 {\x00-\x1f\x80-\x9f\x7f\xa0}
    set asciiC11 {\x20}
    
    # C.1.1 is actually allowed (RFC3491), weird!
    set    asciiProhibit(domain) $asciiC11
    append asciiProhibit(domain) $asciiC12C22
    append asciiProhibit(domain) /@   

    # The nodeprep prohibits these characters in addition.
    #x22 (") 
    #x26 (&) 
    #x27 (') 
    #x2F (/) 
    #x3A (:) 
    #x3C (<) 
    #x3E (>) 
    #x40 (@) 
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

proc jlib::splitjidexBU {jid nodeVar domainVar resourceVar} {
    
    set node   ""
    set domain ""
    set res    ""
    if {[regexp {^(([^@]+)@)?([^ /@]+)(/(.*))?$} $jid m x node domain y res]} {
	uplevel 1 [list set $nodeVar $node]
	uplevel 1 [list set $domainVar $domain]
	uplevel 1 [list set $resourceVar $res]
    } elseif {$jid eq ""} {
	uplevel 1 [list set $nodeVar $node]
	uplevel 1 [list set $domainVar $domain]
	uplevel 1 [list set $resourceVar $res]
    } else {
	return -code error "not valid jid form"
    }
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
	return -code error "username contains illegal character(s)"
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

# jlib::encodeusername, decodeusername, decodejid --
# 
#       Jid escaping.
#       JEP-0106 EXPERIMENTAL!

proc jlib::encodeusername {username} {    
    variable jidesc
    
    set str $username
    set ndx 0
    while {[regexp -start $ndx -indices -- "\[$jidesc\]" $str r]} {
	set ndx [lindex $r 0]
	scan [string index $str $ndx] %c chr
	set rep "#[format %.2x $chr];"
	set str [string replace $str $ndx $ndx $rep]
	incr ndx 3
    }
    return $str
}

proc jlib::decodeusername {username} {
    
    # Be sure that only the specific characters are being decoded.
    foreach sub {{#(20);} {#(22);} {#(23);} {#(26);} {#(27);} {#(2f);}  \
      {#(3a);} {#(3c);} {#(3e);} {#(40);}} {
	regsub -all $sub $username {[format %c 0x\1]} username
    }	
    return [subst $username]
}

proc jlib::decodejid {jid} {
    
    set jidlist [split $jid @]
    if {[llength $jidlist] == 2} {
	return "[decodeusername [lindex $jidlist 0]]@[lindex $jidlist 1]"
    } else {
	return $jid
    }
}

proc jlib::getdisplayusername {jid} {

    set jidlist [split $jid @]
    if {[llength $jidlist] == 2} {
	return [decodeusername [lindex $jidlist 0]]
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
        
    set hex1 [format {%x} [clock clicks]]
    set hex2 [format {%x} [expr int(100000000*rand())]]
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

#--- namespace jlib::conference ------------------------------------------------

# jlib::conference --
#
#       Provides API's for the conference protocol using jabber:iq:conference.

proc jlib::conference {jlibname cmd args} {
    
    # Which command? Just dispatch the command to the right procedure.
    if {[catch {
	eval {[namespace current]::conference::$cmd $jlibname} $args
    } ans]} {
	return -code error $ans
    }
    return $ans
}

# jlib::conference::get_enter, set_enter --
#
#       Request conference enter room, and do enter room.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       to:         'roomname@conference.jabber.org' typically.
#       subelements xml list
#       cmd:        callback command for iq result element.
#       
# Results:
#       none.

proc jlib::conference::get_enter {jlibname room cmd} {

    [namespace parent]::Debug 3 "jlib::conference::get_enter room=$room, cmd=$cmd"
    
    set xmllist [wrapper::createtag "enter"  \
      -attrlist {xmlns jabber:iq:conference}]
    [namespace parent]::send_iq $jlibname "get" [list $xmllist] -to $room -command  \
      [list [namespace parent]::invoke_iq_callback $jlibname $cmd]
    [namespace parent]::service::setroomprotocol $jlibname $room "conference"
    return
}

proc jlib::conference::set_enter {jlibname room subelements cmd} {

    [namespace parent]::send_presence $jlibname -to $room
    [namespace parent]::send_iq $jlibname "set"  \
      [list [wrapper::createtag "enter" -attrlist {xmlns jabber:iq:conference} \
      -subtags $subelements]] -to $room -command  \
      [list [namespace current]::parse_set_enter $jlibname $room $cmd]
    return
}

# jlib::conference::parse_set_enter --
#
#       Callback for 'set_enter' and 'set_create'. 
#       Cache useful info to unburden client.
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        the jid we browsed.
#       cmd:        for callback to client.
#       type:       "ok" or "error"
#       subiq:

proc jlib::conference::parse_set_enter {jlibname room cmd type subiq} {    

    upvar ${jlibname}::conf conf

    [namespace parent]::Debug 3 "jlib::conference::parse_set_enter room=$room, cmd='$cmd', type=$type, subiq='$subiq'"
    
    if {[string equal $type "error"]} {
	uplevel #0 $cmd [list $jlibname error $subiq]
    } else {
	
	# Cache useful info:    
	# This should be something like:
	# <query><id>myroom@server/7y3jy7f03</id><nick/>snuffie<nick><query/>
	# Use it to cache own room jid.
	foreach child [wrapper::getchildren $subiq] {
	    set tagName [wrapper::gettag $child]
	    set value [wrapper::getcdata $child]
	    set $tagName $value
	}
	if {[info exists id] && [info exists nick]} {
	    set conf($room,hashandnick) [list $id $nick]
	}
	if {[info exists name]} {
	    set conf($room,roomname) $name
	}
	lappend conf(allroomsin) $room
	
	# And finally let client know.
	uplevel #0 $cmd [list $jlibname $type $subiq]
    }
}

# jlib::conference::get_create, set_create --
#
#       Request conference creation of room.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       to:        'conference.jabber.org' typically.
#       cmd:        callback command for iq result element.
#       
# Results:
#       none.

proc jlib::conference::get_create {jlibname to cmd} {

    [namespace parent]::Debug 3 "jlib::conference::get_create cmd=$cmd, to=$to"
    
    [namespace parent]::send_presence $jlibname -to $to
    set xmllist [wrapper::createtag "create"   \
      -attrlist {xmlns jabber:iq:conference}]
    [namespace parent]::send_iq $jlibname "get" [list $xmllist] -to $to -command   \
      [list [namespace parent]::invoke_iq_callback $jlibname $cmd]
}

proc jlib::conference::set_create {jlibname room subelements cmd} {

    # We use the same callback as 'set_enter'.
    [namespace parent]::send_presence $jlibname -to $room
    [namespace parent]::send_iq $jlibname "set"  \
      [list [wrapper::createtag "create" -attrlist {xmlns jabber:iq:conference} \
      -subtags $subelements]] -to $room -command  \
      [list [namespace current]::parse_set_enter $jlibname $room $cmd]
    [namespace parent]::service::setroomprotocol $jlibname $room "conference"
    return
}

# jlib::conference::delete --
#
#       Delete conference room.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       room:       'roomname@conference.jabber.org' typically.
#       cmd:        callback command for iq result element.
#       
# Results:
#       none.

proc jlib::conference::delete {jlibname room cmd} {

    set xmllist [wrapper::createtag {delete}  \
      -attrlist {xmlns jabber:iq:conference}]
    [namespace parent]::send_iq $jlibname "set" [list $xmllist] -to $room -command  \
      [list [namespace parent]::invoke_iq_callback $jlibname $cmd]
    return
}

proc jlib::conference::exit {jlibname room} {

    upvar ${jlibname}::conf conf
    upvar ${jlibname}::lib lib

    [namespace parent]::send_presence $jlibname -to $room -type unavailable
    set ind [lsearch -exact $conf(allroomsin) $room]
    if {$ind >= 0} {
	set conf(allroomsin) [lreplace $conf(allroomsin) $ind $ind]
    }
    $lib(rostername) clearpresence "${room}*"
    return
}

# jlib::conference::set_user --
#
#       Set user's nick name in conference room.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       room:       'roomname@conference.jabber.org' typically.
#       name:       nick name.
#       jid:        'roomname@conference.jabber.org/key' typically.
#       cmd:        callback command for iq result element.
#       
# Results:
#       none.

proc jlib::conference::set_user {jlibname room name jid cmd} {

    [namespace parent]::Debug 3 "jlib::conference::set_user cmd=$cmd, room=$room"
    
    set subelem [wrapper::createtag "user"  \
      -attrlist [list name $name jid $jid]]
    set xmllist [wrapper::createtag "conference"  \
      -attrlist {xmlns jabber:iq:browse} -subtags $subelem]
    [namespace parent]::send_iq $jlibname "set" [list $xmllist] -to $room -command  \
      [list [namespace parent]::invoke_iq_callback $jlibname $cmd]
}

# jlib::conference::hashandnick --
#
#       Returns list {kitchen@conf.athlon.se/63264ba6724.. mynickname}

proc jlib::conference::hashandnick {jlibname room} {

    upvar ${jlibname}::conf conf

    if {[info exists conf($room,hashandnick)]} {
	return $conf($room,hashandnick)
    } else {
	return -code error "Unknown room \"$room\""
    }
}

proc jlib::conference::roomname {jlibname room} {

    upvar ${jlibname}::conf conf

    if {[info exists conf($room,roomname)]} {
	return $conf($room,roomname)
    } else {
	return -code error "Unknown room \"$room\""
    }
}

proc jlib::conference::allroomsin {jlibname} {

    upvar ${jlibname}::conf conf
    
    set conf(allroomsin) [lsort -unique $conf(allroomsin)]
    return $conf(allroomsin)
}

#-------------------------------------------------------------------------------
