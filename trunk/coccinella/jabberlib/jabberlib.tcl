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
# $Id: jabberlib.tcl,v 1.34 2004-02-03 10:14:52 matben Exp $
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
#
#       lib(clientcmd)             : Callback proc up to the client
#       
#       lib(rostername)            : the name of the roster object
#       
#       lib(browsename)            : (optional) the name of any browse object
#       
#       lib(server)                : The server domain name or ip number
#       
#	lib(sock)                  : socket name
#
#	lib(streamcmd)             : Callback command to run when the <stream>
#	                             tag is received from the server.
#
# iqcmd:	                             
#	iqcmd(uid)                 : Next iq id-number. Sent in 
#                                    "id" attributes of <iq> packets.
#
#	iqcmd($id)                 : Callback command to run when iq result 
#	                             packet of $id is received.
#
# locals:	                             
#	locals(gcProtoPriority)    : The groupchat protocol priority list.                             
#	                             
#       locals(gcprot,$jid)        : Map a groupchat service jid to protocol:
#       	                     (gc-1.0|conference|muc)
#
#       locals(prefgcprot,$jid)    : Stores preferred groupchat protocol that
#                                    overrides the priority list.
#	                               
############################# SCHEMA ###########################################
#
#                                        --> browse >--
#                                       /              \
#                                      /  -> roster >-  \
#                                      | /            \  |
#                                      |/              \ |
#   TclXML <---> wrapper <---> jabberlib <-----------> client
#                                       \             /
#                                        <--- muc <---
#   
#   Note the one-way communication with the 'roster' object since it may only
#   be set by the server, that is, from 'jabberlib'. 
#   The client only "gets" the roster.
#   The 'browse' object works similarly.
#
############################# USAGE ############################################
#
#   NAME
#      jabberlib - an interface between Jabber clients and the wrapper
#      
#   SYNOPSIS
#      jlib::new rosterName clientCmd ?-opt value ...?
#      
#   OPTIONS
#	-iqcommand            callback for <iq> elements not handled explicitly
#	-messagecommand       callback for <message> elements
#	-presencecommand      callback for <presence> elements
#	-streamnamespace      initialization namespace (D = "jabber:client")
#	-keepalivesecs        send a newline character with this interval
#	-autoaway             boolean 0/1 if to send away message after inactivity
#	-xautoaway            boolean 0/1 if to send xaway message after inactivity
#	-awaymin              if -away send away message after this many minutes
#	-xawaymin             if -xaway send xaway message after this many minutes
#	-awaymsg              the away message 
#	-xawaymsg             the xaway message
#	
#   INSTANCE COMMANDS
#      jlibName agent_get to cmd
#      jlibName agents_get to cmd
#      jlibName browse_get to ?-command, -errorcommand?
#      jlibName config ?args?
#      jlibName connect server ?args?
#      jlibName disconnect
#      jlibName get_last to cmd
#      jlibName get_time to cmd
#      jlibName get_version to cmd
#      jlibName getagent jid
#      jlibName getrecipientjid jid
#      jlibName haveagent jid
#      jlibName iq_get xmlns to ?args?
#      jlibName iq_set xmlns to ?args?
#      jlibName iq_register type xmlns cmd
#      jlibName myjid
#      jlibName mystatus
#      jlibName oob_set to cmd url ?args?
#      jlibName private_get to ns subtags cmd
#      jlibName private_set ns cmd ?args?
#      jlibName register_set username password cmd ?args?
#      jlibName register_get cmd ?args?
#      jlibName register_remove to cmd ?args?
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
#      jlibName send_autoupdate to cmd
#      jlibName vcard_get to cmd
#      jlibName vcard_set cmd ?args?
#      jlibName setgroupchatpriority priorityList
#      jlibName setgroupchatprotocol jid protocol
#      jlibName setroomprotocol jid protocol
#      
#  o protocol independent methods for groupchats/conference/muc,
#    agents/browse/disco(?):
#      jlibName service parent jid
#      jlibName service childs jid
#      jlibName service isroom jid
#      jlibName service nick jid
#      jlibName service hashandnick jid
#      jlibName service getjidsfor aservice
#      jlibName service gettransportjids aservice
#      jlibName service gettype jid
#      jlibName service allroomsin
#      jlibName service roomparticipants room
#      jlibName service exitroom room
#      
#  o using the experimental 'conference' protocol:
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
#  o using the old 'groupchat-1.0' protocol:
#      jlibName groupchat enter room nick
#      jlibName groupchat exit room
#      jlibName groupchat mynick room ?nick?
#      jlibName groupchat status room
#      jlibName groupchat participants room
#      jlibName groupchat allroomsin
#      
#  o utility functions:   
#      jlib::invokefrombrowser browsename cmd
#      
#  o the 'muc' command: see muc.tcl
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
############################# CHANGES ##########################################
#
#       0.*      by Kerem HADIMLI and Todd Bradley
#       1.0a1    complete rewrite, and first release by Mats Bengtsson
#       1.0a2    minor additions and fixes
#       1.0a3    added vCard, '-cmd' to 'connect', private_get/set
#       1.0b1    few bugfixes, added browse_get, agent_get
#       1.0b2    type attribute in send_message wrong
#       1.0b3    added support for conferencing, many rewrites
#       1.0b4    added time, last, version
#       1.0b5    added better error catching
#       1.0b6    added config and auto away support
#       1.0b7    fixed bug in send_message for x elements
#       1.0b8    fixed bug in send_iq if xmldata empty
#	1.0b9    added configurable transport layer, incompatible change
#		     of 'connect' command
#                placed debug printouts in one proc; access function for debug
#                added caching of agent(s) stuff
#                added a 'service' subcommand
#                added the old groupchat interface
#                added a 'conference' subcommand, removed conf_* methods
#                added -streamnamespace option
#                completely reworked client callback structure
#                'register_remove' is now an iq-set command, new 'to' argument
#       1.0b10   fixed a number of problems with groupchat-conference compatibility,
#                added presence callback
#       1.0b11   changed 'browse_get' command 
#                added 'mystatus' command, added 'setgroupchatpriority',
#                'setgroupchatprotocol' and reworked all groupchat protocol
#                dispatching.
#       030523   added 'getagent' and 'haveagent' commands.
#       030611   added 'setroomprotocol' command and modified service dispatching
#       030705   jlib::new generates self token
#       030726   made browse object optional, jlib::new api changed!
#       031022   added iq_get and iq_set methods
#       031101   added 'service gettransportjids' and 'gettype'
#       031107   added 'getrecipientjid' command
#       040111   new iq callback mechanism 'iq_register'

package require wrapper
package require roster
package require browse
package require muc

package provide jlib 1.0

namespace eval jlib {
    
    # Globals same for all instances of this jlib.
    #    > 1 prints raw xml I/O
    #    > 2 prints a lot more
    variable debug 0
    if {[info exists ::debugLevel] && ($::debugLevel > 1) && ($debug == 0)} {
	set debug 2
    }
    
    variable statics
    set statics(presenceTypeExp)  \
      {(available|unavailable|subscribe|unsubscribe|subscribed|unsubscribed|invisible)}

    # Maintain a priority list of groupchat protocols in decreasing priority.
    # Entries must match: ( gc-1.0 | conference | muc )
    set statics(groupchatTypeExp) {(gc-1.0|conference|muc)}
    
    variable version 1.0
    
    # Running number.
    variable uid 0
}

namespace eval jlib::service {
    
    # This is an abstraction layer for two things; the agent/browse/(disco?)
    # protocols, and for the groupchat protocols gc-1.0/conference/muc.
    
    # Cache the following services in particular.
    variable services {search register groupchat conference muc}    
}

# Collects the 'conference' subcommand.
namespace eval jlib::conference { }

# Collects the 'groupchat' subcommand.
namespace eval jlib::groupchat { }


# Bindings to the muc package.
proc jlib::muc {jlibname args} {

    eval {[namespace current]::muc::CommandProc $jlibname} $args
}

# jlib::new --
#
#       This creates a new instance jlib interpreter.
#       
# Arguments:
#       rostername: the name of the roster object
#       clientcmd:  callback procedure for the client
#       args:       
#       -browsename           the name of the browse object
#	-iqcommand            
#	-messagecommand       
#	-presencecommand      
#	-streamnamespace      
#	-keepalivesecs        
#	-autoaway             
#	-xautoaway            
#	-awaymin              
#	-xawaymin             
#	-awaymsg              
#	-xawaymsg             
#	-transportinit
#	-transportsend
#	-transportreset
#       
# Results:
#       jlibname which is the namespaced instance command
  
proc jlib::new {rostername clientcmd args} {    

    variable objectmap
    variable uid
    
    # Generate unique command token for this jlib instance.
    set jlibname jabberlib[incr uid]
      
    # Instance specific namespace.
    namespace eval [namespace current]::${jlibname} {
	variable lib
	variable locals
	variable iqcmd
	variable iqhook
	variable opts
	variable agent
	# Cache for the 'conference' subcommand.
	variable conf
	# Cache for the 'groupchat' subcommand.
	variable gchat	
    }
    
    # Cache for the MUC subcommand.
    namespace eval [namespace current]::muc::${jlibname} {
       	variable cache
    }
        
    # Set simpler variable names.
    upvar [namespace current]::${jlibname}::lib    lib
    upvar [namespace current]::${jlibname}::iqcmd  iqcmd
    upvar [namespace current]::${jlibname}::prescmd prescmd
    upvar [namespace current]::${jlibname}::opts   opts
    upvar [namespace current]::${jlibname}::conf   conf
    upvar [namespace current]::${jlibname}::gchat  gchat
    upvar [namespace current]::${jlibname}::locals locals
    
    array set opts {
	-iqcommand            ""
	-messagecommand       ""
	-presencecommand      ""
	-streamnamespace      "jabber:client"
	-keepalivesecs        30
	-autoaway             0
	-xautoaway            0
	-awaymin              0
	-xawaymin             0
	-awaymsg              ""
	-xawaymsg             ""
	-browsename           ""
    }
    
    # Defaults for the raw socket transport layer.
    set opts(-transportinit)  [list jlib::initsocket $jlibname]
    set opts(-transportsend)  [list jlib::putssocket $jlibname]
    set opts(-transportreset) [list jlib::resetsocket $jlibname]
    
    # Verify options.
    if {[catch {eval jlib::verify_options $jlibname $args} msg]} {
	return -code error $msg
    }    

    set wrapper [wrapper::new [list [namespace current]::got_stream $jlibname] \
      [list [namespace current]::end_of_parse $jlibname]  \
      [list [namespace current]::dispatcher $jlibname]    \
      [list [namespace current]::xmlerror $jlibname]]
    
    set iqcmd(uid) 1001
    set prescmd(uid) 1001
    set lib(fulljlibname) [namespace current]::${jlibname}
    set lib(rostername)   $rostername
    set lib(browsename)   $opts(-browsename)
    set lib(clientcmd)    $clientcmd
    set lib(wrap)         $wrapper
    
    set lib(isinstream) 0
    set lib(server) ""
    
    # Register some standard iq handlers that is handled internally.
    iq_register $jlibname get jabber:iq:last    \
      [namespace current]::handle_get_last
    iq_register $jlibname get jabber:iq:time    \
      [namespace current]::handle_get_time
    iq_register $jlibname get jabber:iq:version \
      [namespace current]::handle_get_version
    
    
    # Mapper between objects.
    if {$opts(-browsename) != ""} {
	set objectmap(browsename,$jlibname) $opts(-browsename)
	set objectmap(jlibname,$opts(-browsename)) $jlibname
	set opts(havebrowse) 1
    } else {
	set opts(havebrowse) 0
    }
        
    # Maintain a priority list of groupchat protocols in decreasing priority.
    # Entries must match: ( gc-1.0 | conference | muc )
    set locals(gcProtoPriority) {muc conference gc-1.0}
    
    # Any of {available away dnd invisible unavailable}
    set locals(status) "unavailable"
    set locals(myjid) ""
    
    # Init conference and groupchat state.
    set conf(allroomsin) {}    
    set gchat(allroomsin) {}

    # Create the actual jlib instance procedure.
    proc [namespace current]::${jlibname} {cmd args}   \
      "eval jlib::cmdproc {$jlibname} \$cmd \$args"
    
    return [namespace current]::${jlibname}
}

# jlib::cmdproc --
#
#       Just dispatches the command to the right procedure.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       cmd:        connect - disconnect - send_iq - send_message ... etc.
#       args:       all args to the cmd procedure.
#       
# Results:
#       none.

proc jlib::cmdproc {jlibname cmd args} {
    
    Debug 5 "jlib::cmdproc: jlibname=$jlibname, cmd='$cmd', args='$args'"

    # Which command? Just dispatch the command to the right procedure.
    return [eval $cmd $jlibname $args]
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

    upvar [namespace current]::${jlibname}::opts opts
    
    array set argsArr $args
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
	foreach {flag value} $args {
	    if {[regexp -- $pat $flag]} {
		set opts($flag) $value		
	    } else {
		return -code error "Unknown option $flag, must be: $usage"
	    }
	}
    }
    
    # Reschedule auto away if changed.
    if {[info exists argsArr(-autoaway)] || \
      [info exists argsArr(-xautoaway)] || \
      [info exists argsArr(-awaymin)] || \
      [info exists argsArr(-xawaymin)]} {
	schedule_auto_away $jlibname
    }
    return ""
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

    upvar [namespace current]::${jlibname}::opts opts
    
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

# jlib::invokefrombrowser --
# 
#       This is a helper utility to allow the browse object call a method in
#       the jabberlib. 
#       This is the sole deviation of the rule that the browse object is
#       never makes any calls to jlib.

proc jlib::invokefrombrowser {browsename cmd} {

    variable objectmap

    if {![info exists objectmap(jlibname,$browsename)]} {
	return -code error "Unrecognized browse object \"$browsename\""
    }
    set jlibname $objectmap(jlibname,$browsename)
    eval {[lindex $cmd 0] $jlibname} [lrange $cmd 1 end]
}

# The procedures for the standard socket transport layer -----------------------

# jlib::initsocket
#
#	Default transport mechanism; init socket.
#
# Arguments:
# 
# Side Effects:
#	none

proc jlib::initsocket {jlibname} {

    upvar [namespace current]::${jlibname}::lib lib
    upvar [namespace current]::${jlibname}::opts opts

    set sock $lib(sock)
    if {[catch {
	fconfigure $sock -blocking 0 -buffering none -encoding utf-8
    } err]} {
	return -code error {The connection failed or dropped later}
    }
     
    # Set up callback on incoming socket.
    fileevent $sock readable [list [namespace current]::recvsocket $jlibname]

    # Schedule keep-alives to keep socket open in case anyone want's to close it.
    # Be sure to not send any keep-alives before the stream is inited.
    if {$opts(-keepalivesecs)} {
	after $opts(-keepalivesecs)  \
	  [namespace current]::schedule_keepalive $jlibname
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

    upvar [namespace current]::${jlibname}::lib lib

    Debug 2 "SEND: $xml"
    if {[catch {puts $lib(sock) $xml} err]} {
	return -code error "Network connection dropped: $err"
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

    upvar [namespace current]::${jlibname}::lib lib
    upvar [namespace current]::${jlibname}::locals locals

    catch {close $lib(sock)}
    catch {after cancel $locals(aliveid)}
}

# jlib::recvsocket --
#
#	  Default transport mechanism; fileevent on socket socket.
#       Callback on incoming socket xml data. Feeds our wrapper and XML parser.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       
# Results:
#       none.

proc jlib::recvsocket {jlibname} {

    upvar [namespace current]::${jlibname}::lib lib

    if {[catch {eof $lib(sock)} iseof] || $iseof} {
	end_of_parse $jlibname
	return
    }
    
    # Read what we've got.
    if {[catch {read $lib(sock)} temp]} {
	disconnect $jlibname
	uplevel #0 $lib(clientcmd) $jlibname "networkerror" -body \
	  "Network error when reading from network"
	return
    }
    Debug 2 "RECV: $temp"
    
    # Feed the XML parser. When the end of a command element tag is reached,
    # we get a callback to 'jlib::dispatcher'.
    wrapper::parse $lib(wrap) $temp
}

# jlib::recv --
#
# 	Feed the XML parser. When the end of a command element tag is reached,
# 	we get a callback to 'jlib::dispatcher'.

proc jlib::recv {jlibname xml} {

    upvar [namespace current]::${jlibname}::lib lib

    wrapper::parse $lib(wrap) $xml
}

# standard socket transport layer end ------------------------------------------

# jlib::connect --
#
#       Initializes a stream to a jabber server. The socket must already 
#       be opened. Sets up fileevent on incoming xml stream.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       server:     the domain name or ip number of the server.
#       args:
#	    -socket an open socket; compulsory for socket transport!
#           -cmd    callback when we receive the <stream> tag from the server.
#           -to     the receipients jabber id.
#           -id
#       
# Results:
#       none.

proc jlib::connect {jlibname server args} {    

    upvar [namespace current]::${jlibname}::lib lib
    upvar [namespace current]::${jlibname}::locals locals
    upvar [namespace current]::${jlibname}::opts opts

    array set argsArr $args
    set lib(server) $server
    set locals(last) [clock seconds]
    if {[info exists argsArr(-socket)]} {
    	set lib(sock) $argsArr(-socket)
    }	

    # Register a <stream> callback proc.
    if {[info exists argsArr(-cmd)] && [llength $argsArr(-cmd)]} {
	set lib(streamcmd) $argsArr(-cmd)
    }
    set optattr {}
    foreach {key value} $args {
	if {[string equal $key "-cmd"] || [string equal $key "-socket"]} {
	    continue
	}
	set attr [string trimleft $key "-"]
	append optattr " $attr='$value'"
    }

    if {[catch {

	# This call to the transport layer shall set up fileevent callbacks etc.
   	# to handle all incoming xml.
	eval $opts(-transportinit)
        
    	# Network errors if failed to open connection properly are likely to show here.
	set xml "<?xml version='1.0' encoding='UTF-8' ?><stream:stream\
	  xmlns='$opts(-streamnamespace)'\
	  xmlns:stream='http://etherx.jabber.org/streams'\
	  to='$server'$optattr>"
   	eval $opts(-transportsend) {$xml}
    } err]} {
	
	# The socket probably was never connected,
	# or the connection dropped later.
	disconnect $jlibname
	return -code error "The connection failed or dropped later: $err"
    }
    return ""
}

# jlib::disconnect --
#
#       Closes the stream down, closes socket, and resets internal variables.
#       There is a potential problem if called from within a xml parser 
#       callback which makes the subsequent parsing to fail. (after idle?)
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       
# Results:
#       none.

proc jlib::disconnect {jlibname} {    

    upvar [namespace current]::${jlibname}::lib lib
    upvar [namespace current]::${jlibname}::opts opts

    Debug 3 "jlib::disconnect"
    set xml "</stream:stream>"
    catch {eval $opts(-transportsend) {$xml}}
    eval $opts(-transportreset)
    reset $jlibname
    
    # Be sure to reset the wrapper, which implicitly resets the XML parser.
    wrapper::reset $lib(wrap)
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
    
    Debug 5 "jlib::dispatcher jlibname=$jlibname, xmldata=$xmldata"
    
    # Which method?
    switch -- [wrapper::gettag $xmldata] {
	iq {
	    iq_handler $jlibname $xmldata
	}
	message {
	    message_handler $jlibname $xmldata	    
	}
	presence {
	    presence_handler $jlibname $xmldata	
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

    upvar [namespace current]::${jlibname}::lib lib
    upvar [namespace current]::${jlibname}::iqcmd iqcmd
    upvar [namespace current]::${jlibname}::opts opts    
    
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
    
    # The 'type' attribute must exist! Else we return silently.
    if {![info exists type]} {	
	return
    }
    if {![info exists from]} {
	set afrom ""
    } else {
	set afrom $from
    }
    
    # The child must be a single <query> element (or any namespaced element).
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
	    }
	    jabber:iq:browse {
		
		# Shouldn't be here much longer...
		# This is the same as the one we get from a 'browse_get'.
		# This contains no error element so skip callback.
		if {$opts(havebrowse)} {
		    parse_browse_get $jlibname $from {} {} ok $subiq
		}
	    }
	}
    }
    
    # (2) Handle all preregistered callbacks via id attributes.
    #     Must be type 'result' or 'error'.

    switch -- $type {
	result {

	    # A request for the entire roster is coming this way, 
	    # and calls 'parse_roster_set'.
	    # $iqcmd($id) contains the 'parse_...' call as 1st element.
	    if {[info exists id] && [info exists iqcmd($id)]} {
		
		# TODO: add attrArr to callback.
		uplevel #0 $iqcmd($id) [list ok $subiq]
		
		# We need a catch here since the callback my in turn 
		# call 'disconnect' which unsets all iq before returning.
		catch {unset iqcmd($id)}
		set ishandled 1
	    }
	}
	error {
	    
	    # We should have a single error element here.
	    # There is an open question here if <error/> elements can sit
	    # in other branches of the xml tree.
	    set errcode {}
	    set errmsg {}
	    foreach errorchild $childlist {
		if {[string equal [wrapper::gettag $errorchild] "error"]} {
		    
		    # Found it!
		    set cchdata [wrapper::getcdata $errorchild]
		    set errcode [wrapper::getattribute $errorchild "code"]
		    set errmsg $cchdata
		    break
		}
	    }
	    if {[info exists id] && [info exists iqcmd($id)]} {
		uplevel #0 $iqcmd($id) [list error [list $errcode $errmsg]]
		catch {unset iqcmd($id)}
		set ishandled 1
	    }	    
	}
    }
	        
    # (3) Handle callbacks specific for 'type' and 'xmlns' that have been
    #     registered with 'iq_register'

    if {[string equal $ishandled "0"]} {
	set ishandled [eval {
	    iq_invoke_hook $jlibname $type $xmlns $afrom $subiq} $arglist]
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

	# (6) If type='get' and still unhandled, return an error element.

	if {[string equal $type "get"] && [string equal $ishandled "0"]} {
	    
	    # Return a "Not Implemented" to the sender. Just switch to/from,
	    # type='result', and add an <error> element.
	    set attrArr(to) $attrArr(from)
	    unset attrArr(from)
	    set attrArr(type) "result"
	    set xmldata [wrapper::setattrlist $xmldata [array get attrArr]]
	    set errtag [wrapper::createtag "error" -chdata "Not Implemented"  \
	      -attrlist {code 501}]
	    lappend childlist $errtag
	    set xmldata [wrapper::setchildlist $xmldata $childlist]
	    
	    # Be careful to trap network errors and report.
	    set xml [wrapper::createxml $xmldata]
	    if {[catch {eval $opts(-transportsend) {$xml}} err]} {
		disconnect $jlibname
		uplevel #0 $lib(clientcmd) $jlibname "networkerror" -body \
		  {Network error when responding}
	    }
	}
    }
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

    upvar [namespace current]::${jlibname}::opts opts    
    upvar [namespace current]::${jlibname}::lib lib
    
    # Extract the command level XML data items.
    set attrlist [wrapper::getattrlist $xmldata]
    set childlist [wrapper::getchildren $xmldata]
    set attrArr(type) "normal"
    array set attrArr $attrlist
    set type $attrArr(type)
    
    # Make an argument list ('-key value' pairs) suitable for callbacks.
    # Make variables of the attributes.
    set arglist {}
    foreach attrkey [array names attrArr] {
	lappend arglist -$attrkey $attrArr($attrkey)
    }
    
    # Extract the message sub-elements.
    set x {}
    foreach child $childlist {
	
	# Extract the message sub-elements XML data items.
	set ctag [wrapper::gettag $child]
	set cchdata [wrapper::getcdata $child]
	
	switch -- $ctag {
	    body - subject - thread {
		lappend arglist -$ctag $cchdata
	    }
	    error {
		set errcode [wrapper::getattribute $child "code"]
		lappend arglist -error [list $errcode $cchdata]
	    }
	    x {
		lappend x $child
	    }
	}
    }
    if {[string length $x]} {
	lappend arglist -x $x
    }
    
    # Invoke callback to client.
    if {[string length $opts(-messagecommand)]} {
	uplevel #0 $opts(-messagecommand) [list $jlibname $type] $arglist
    } else {
	uplevel #0 $lib(clientcmd) [list $jlibname message] $arglist
    }
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

    upvar [namespace current]::${jlibname}::lib lib
    upvar [namespace current]::${jlibname}::prescmd prescmd
    upvar [namespace current]::${jlibname}::opts opts
    
    # Extract the command level XML data items.
    set attrlist [wrapper::getattrlist $xmldata]
    set childlist [wrapper::getchildren $xmldata]
    array set attrArr $attrlist
    
    # Make an argument list ('-key value' pairs) suitable for callbacks.
    # Make variables of the attributes.
    set arglist {}
    set type "available"
    foreach {attrkey attrval} $attrlist {
	set $attrkey $attrval
	lappend arglist -$attrkey $attrval
    }
    
    # Check first if this is an error element (from conferencing?).
    if {[string equal $type "error"]} {
	
	# We should have a single error element here.
	set errcode {}
	set errmsg {}
	foreach errorchild $childlist {
	    if {[string equal [wrapper::gettag $errorchild] "error"]} {
		set cchdata [wrapper::getcdata $errorchild]
		set errcode [wrapper::getattribute $errorchild "code"]
		set errmsg $cchdata
		break
	    }
	}
	lappend arglist -error [list $errcode $errmsg]
    } else {
	
	# Extract the presence sub-elements. Separate the x element.
	set x {}
	foreach child $childlist {
	    
	    # Extract the presence sub-elements XML data items.
	    set ctag [wrapper::gettag $child]
	    set cchdata [wrapper::getcdata $child]
	    
	    switch -- $ctag {
		status - priority - show {
		    lappend params $ctag $cchdata
		    lappend arglist -$ctag $cchdata
		}
		x {
		    lappend x $child
		}
		default {
		    lappend arglist -$ctag $cchdata
		}
	    }
	}	    
	if {[llength $x] > 0} {
	    lappend arglist -x $x
	}
	
	# Do different things depending on the 'type' attribute.
	if {[string equal $type "available"] ||  \
	  [string equal $type "unavailable"]} {
	    
	    # Set presence in our roster object
	    eval {$lib(rostername) setpresence $from $type} $arglist
	    
	    # If unavailable be sure to clear browse object for this jid.
	    if {$opts(havebrowse) && [string equal $type "unavailable"]} {
		$lib(browsename) clear $from
	    }
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
    
    # Invoke any callback.
    if {[info exists id] && [info exists prescmd($id)]} {
	uplevel #0 $prescmd($id) [list $jlibname $type] $arglist
	catch {unset prescmd($id)}
    } elseif {[string length $opts(-presencecommand)]} {
	#uplevel #0 $opts(-presencecommand) [list $jlibname $type] $arglist
    } else {
	#uplevel #0 $lib(clientcmd) [list $jlibname presence] $arglist
    }	
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

    upvar [namespace current]::${jlibname}::lib lib

    Debug 3 "jlib::got_stream jlibname=$jlibname, args='$args'"
    
    uplevel #0 $lib(clientcmd) [list $jlibname connect]
    schedule_auto_away $jlibname
    set lib(isinstream) 1
    
    # If we use    we should have a callback command here.
    if {[info exists lib(streamcmd)] && [llength $lib(streamcmd)]} {
	uplevel #0 $lib(streamcmd) $jlibname $args
	unset lib(streamcmd)
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

    upvar [namespace current]::${jlibname}::lib lib
    upvar [namespace current]::${jlibname}::opts opts

    Debug 3 "jlib::end_of_parse jlibname=$jlibname"
    
    eval $opts(-transportreset)
    uplevel #0 $lib(clientcmd) [list $jlibname disconnect]
    reset $jlibname
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

    upvar [namespace current]::${jlibname}::lib lib
    upvar [namespace current]::${jlibname}::opts opts

    Debug 3 "jlib::xmlerror jlibname=$jlibname, args='$args'"
    
    eval $opts(-transportreset)
    uplevel #0 $lib(clientcmd) [list $jlibname xmlerror -errormsg $args]
    reset $jlibname
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

    upvar [namespace current]::${jlibname}::lib lib
    upvar [namespace current]::${jlibname}::iqcmd iqcmd
    upvar [namespace current]::${jlibname}::prescmd prescmd
    upvar [namespace current]::${jlibname}::agent agent
    upvar [namespace current]::${jlibname}::locals locals
    
    Debug 3 "jlib::reset"

    # Be silent about this.
    catch {
	set num $iqcmd(uid)
	unset iqcmd
	set iqcmd(uid) $num
	set num $prescmd(uid)
	unset prescmd
	set prescmd(uid) $num
	unset agent
    }
    cancel_auto_away $jlibname
    set lib(isinstream) 0
    set locals(status) "unavailable"
    set locals(myjid) ""
}
   
# jlib::parse_iq_response --
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

proc jlib::parse_iq_response {jlibname cmd type subiq} {

    Debug 3 "jlib::parse_iq_response cmd=$cmd, type=$type, subiq=$subiq"
    
    if {[string equal $type "error"]} {
	uplevel #0 $cmd [list $jlibname error $subiq]
    } else {
	uplevel #0 $cmd [list $jlibname ok $subiq]
    }	
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

    upvar [namespace current]::${jlibname}::lib lib

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
		    if {[string equal $key {subscription}]} {
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

    upvar [namespace current]::${jlibname}::lib lib

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

# jlib::parse_browse_get --
#
#       This can be a callback from a 'browse_get' call, but can also be
#       called when getting a server push.
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        the jid we browsed.
#       cmd:        see 'browse_get', may be empty.
#       errcmd:     see 'browse_get', may be empty.
#       type:       "ok" or "error"
#       subiq:

proc jlib::parse_browse_get {jlibname jid cmd errcmd type subiq} {    

    upvar [namespace current]::${jlibname}::lib lib
    upvar [namespace current]::${jlibname}::opts opts    

    Debug 3 "jlib::parse_browse_get jid=$jid, cmd='$cmd', type=$type, subiq='$subiq'"

    if {!$opts(havebrowse)} {
	return
    }    
    set browseopts {}
    
    # A server push should not be able to send an error element.
    if {[string equal $type "error"]} {
	if {[string length $errcmd]} {
	    lappend browseopts -errorcommand $errcmd
	}
	eval {$lib(browsename) errorcallback $jid $subiq} $browseopts
    } else {
    
	# Fill in our browse object with this. Client callback is executed from
	# within this procedure.
	if {[string length $cmd]} {
	    lappend browseopts -command $cmd
	}
	eval {$lib(browsename) setjid $jid $subiq} $browseopts
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

    upvar [namespace current]::${jlibname}::lib lib

    uplevel #0 $cmd [list $type $subiq]
}


proc jlib::iq_register {jlibname type xmlns func} {
    
    upvar [namespace current]::${jlibname}::iqhook iqhook
    
    set iqhook($type,$xmlns) $func
}

proc jlib::iq_invoke_hook {jlibname type xmlns from subiq args} {
    
    upvar [namespace current]::${jlibname}::iqhook iqhook

    set ishandled 0
    
    if {[info exists iqhook($type,$xmlns)]} {
	set func $iqhook($type,$xmlns)
    } elseif {[info exists iqhook(,$xmlns)]} {
	set func $iqhook(,$xmlns)
    }
    if {[info exists func]} {
	set code [catch {
	    uplevel #0 $func [list $jlibname $from $subiq] $args} ans]
	if {$code} {
	    bgerror "iqhook $func failed: $code\n$::errorInfo"
	}
	if {[string equal $ans 1]} {
	    set ishandled 1
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
#       xmldata:    must be valid xml_data of the child-tag of <iq> packet. 
#                   If $type is "get", "set", or "result", its tagname will be 
#                   set to "query". If $type is "error", its tagname will be 
#                   set to "error".
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

    upvar [namespace current]::${jlibname}::lib lib
    upvar [namespace current]::${jlibname}::iqcmd iqcmd
    upvar [namespace current]::${jlibname}::locals locals
    upvar [namespace current]::${jlibname}::opts opts
        
    Debug 3 "jlib::send_iq type='$type', xmldata='$xmldata', args='$args'"
    
    set locals(last) [clock seconds]
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
	  -subtags [list $xmldata]]
    } else {
	set xmllist [wrapper::createtag "iq" -attrlist $attrlist]
    }
	
    # Build raw xml data from list.
    set iqxml [wrapper::createxml $xmllist]
    
    # Trap network errors here.
    if {[catch {eval $opts(-transportsend) {$iqxml}} err]} {
	disconnect $jlibname
	return -code error "Network connection dropped: $err"
    }
}

# jlib::iq_get, iq_set --
#
#       Wrapper for 'send_iq' for set/getting namespaced elements.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       xmlns:
#       to:         recepient jid
#       
# Results:
#       none.

proc jlib::iq_get {jlibname xmlns to args} {

    set opts {}
    set attrlist [list xmlns $xmlns]
    foreach {key value} $args {
	switch -- $key {
	    -command {
		lappend opts -command  \
		  [list [namespace current]::parse_iq_response $jlibname $value]
	    }
	    default {
		lappend attrlist [string trimleft $key "-"] $value
	    }
	}
    }
    set xmllist [wrapper::createtag "query" -attrlist $attrlist]
    eval {send_iq $jlibname "get" $xmllist -to $to} $opts
}

proc jlib::iq_set {jlibname xmlns to args} {

    set opts {}
    set subelements {}
    foreach {key value} $args {
	switch -- $key {
	    -command {
		lappend opts -command  \
		  [list [namespace current]::parse_iq_response $jlibname $value]
	    }
	    default {
		lappend subelements [wrapper::createtag  \
		  [string trimleft $key -] -chdata $value]		
	    }
	}
    }
    if {[llength $subelements]} {
	set xmllist [wrapper::createtag "query" -attrlist [list xmlns $xmlns] \
	  -subtags $subelements]
    } else {
	set xmllist [wrapper::createtag "query" -attrlist [list xmlns $xmlns]]
    }
    eval {send_iq $jlibname "set" $xmllist -to $to} $opts
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

    upvar [namespace current]::${jlibname}::lib lib
    upvar [namespace current]::${jlibname}::locals locals

    set subelements [list  \
      [wrapper::createtag "username" -chdata $username]  \
      [wrapper::createtag "resource" -chdata $resource]]
    set toopt ""

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

    set xmllist [wrapper::createtag "query" -attrlist {xmlns jabber:iq:auth} \
      -subtags $subelements]
    eval {send_iq $jlibname "set" $xmllist -command        \
      [list [namespace current]::parse_iq_response $jlibname $cmd]} $toopt
    
    # Cache our login jid.
    set locals(myjid) ${username}@$lib(server)/${resource}
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
    eval {send_iq $jlibname "get" $xmllist -command  \
      [list [namespace current]::parse_iq_response $jlibname $cmd]} $toopt
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
    eval {send_iq $jlibname "set" $xmllist -command  \
      [list [namespace current]::parse_iq_response $jlibname $cmd]} $toopt
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

    eval {send_iq $jlibname "set" $xmllist -command   \
      [list [namespace current]::parse_iq_response $jlibname $cmd]} -to $to
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
    send_iq $jlibname "get" $xmllist -to $to -command        \
      [list [namespace current]::parse_iq_response $jlibname $cmd]
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

    array set argsarr $args

    if {[info exists argsarr(-subtags)]} {
	set xmllist [wrapper::createtag "query"  \
	  -attrlist {xmlns jabber:iq:search}   \
	  -subtags $argsarr(-subtags)]
    } else {
	set xmllist [wrapper::createtag "query"  \
	  -attrlist {xmlns jabber:iq:search}]
    }
    send_iq $jlibname "set" $xmllist -to $to -command  \
      [list [namespace current]::parse_search_set $jlibname $cmd]
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
# Results:
#       none.

proc jlib::send_message {jlibname to args} {

    upvar [namespace current]::${jlibname}::lib lib
    upvar [namespace current]::${jlibname}::locals locals
    upvar [namespace current]::${jlibname}::opts opts

    Debug 3 "jlib::send_message to=$to, args=$args"
    
    array set argsArr $args
    set locals(last) [clock seconds]
    set attrlist [list to $to]
    set children {}
    
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
    
    # For the auto away function.
    schedule_auto_away $jlibname
    
    # Trap network errors.
    set xml [wrapper::createxml $xmllist]
    if {[catch {eval $opts(-transportsend) {$xml}} err]} {
	disconnect $jlibname
	return -code error {Network error when sending message}
    }
}

# jlib::send_presence --
#
#       To send your presence.
#
# Arguments:
# 
#       jlibname:   the instance of this jlib.
#       args:
#           -to     the jabber id of the recepient.
#           -from   should never be set by client!
#           -type   one of 'available', 'unavailable', 'subscribe', 
#                   'unsubscribe', 'subscribed', 'unsubscribed', 'invisible'.
#           -status
#           -priority
#           -show
#           -xlist
#           -command   Specify a callback to call if we may expect any reply
#                   package, as entering a room with 'gc-1.0'.
#     
# Results:
#       none.

proc jlib::send_presence {jlibname args} {

    variable statics
    upvar [namespace current]::${jlibname}::lib lib
    upvar [namespace current]::${jlibname}::locals locals
    upvar [namespace current]::${jlibname}::opts opts
    upvar [namespace current]::${jlibname}::prescmd prescmd
    
    Debug 3 "jlib::send_presence args='$args'"
    
    set locals(last) [clock seconds]
    set attrlist {}
    set children {}
    set type "available"
    array set argsArr $args
    
    foreach {key value} $args {
	set par [string trimleft $key -]
	switch -- $par {
	    type {
		set type $value
		if {[regexp $statics(presenceTypeExp) $type]} {
		    lappend attrlist $par $type
		} else {
		    return -code error "Is not valid presence type: \"$type\""
		}
	    }
	    from - to {
		lappend attrlist $par $value
	    }
	    xlist {
		foreach xchild $value {
		    lappend children $xchild
		}
	    }
	    command {
		
		# Use iq things for this; needs to be renamed.
		lappend attrlist "id" $prescmd(uid)
		set prescmd($prescmd(uid)) $value
		incr prescmd(uid)
	    }
	    default {
		lappend children [wrapper::createtag $par -chdata $value]
	    }
	}
    }
    set xmllist [wrapper::createtag "presence" -attrlist $attrlist  \
      -subtags $children]
    
    # Be sure to cancel auto away scheduling if necessary.
    if {[info exists argsArr(-type)]} {
	if {[string equal $argsArr(-type) "available"]} {
	    if {[info exists argsArr(-show)] && \
	      ![string equal $argsArr(-show) "chat"]} {
		cancel_auto_away $jlibname
	    }
	} else {
	    cancel_auto_away $jlibname
	}
    }
    
    # Any of {available away dnd invisible unavailable}
    # Must be destined to login server (by default).
    if {![info exists argsArr(-to)] || \
      [string equal $argsArr(-to) $lib(server)]} {
	set locals(status) $type
	if {[info exists argsArr(-show)]} {
	    set locals(status) $argsArr(-show)
	}
    }
    
    # Trap network errors.
    set xml [wrapper::createxml $xmllist]
    if {[catch {eval $opts(-transportsend) {$xml}} err]} {
	disconnect $jlibname
	return -code error $err	
    }
}

# jlib::mystatus --
# 
#       Returns any of {available away dnd invisible unavailable}
#       for our status with the login server.

proc jlib::mystatus {jlibname} {

    upvar [namespace current]::${jlibname}::locals locals
    
    return $locals(status)
}

# jlib::myjid --
# 
#       Returns our 3-tier jid as authorized with the login server.

proc jlib::myjid {jlibname} {

    upvar [namespace current]::${jlibname}::locals locals
    
    return $locals(myjid)
}

# jlib::send_autoupdate --
#
#       Sent with a blank query to retrieve autoupdate information.
#       It implements the 'jabber:iq:autoupdate' get method.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       to:         something like '123456789@update.jabber.org'
#       cmd:        client command to be executed at the iq "result" element.
#       
# Results:
#       none.

proc jlib::send_autoupdate {jlibname to cmd} {

    set xmllist [wrapper::createtag "query"   \
      -attrlist {xmlns jabber:iq:autoupdate}]
    send_iq $jlibname "get" $xmllist -to $to -command   \
      [list [namespace current]::parse_iq_response $jlibname $cmd]
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
    send_iq $jlibname set $xmllist -to $to -command  \
      [list [namespace current]::parse_iq_response $jlibname $cmd]
}

# jlib::browse_get --
#
#       It implements the 'jabber:iq:browse' get method.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       to:         the jid to browse ('conference.jabber.org', for instance)
#       args:       -command cmdProc:   replaces the client callback command
#                        in the browse object
#                   -errorcommand errPproc:    in case of error, this is called
#                        instead of the browse objects callback proc.
#       
# Results:
#       none.

proc jlib::browse_get {jlibname to args} {

    upvar [namespace current]::${jlibname}::opts opts    

    if {!$opts(havebrowse)} {
	return -code error "there is no browse object associated with this jlib"
    }    
    array set argsArr {
	-command        ""
	-errorcommand   ""
    }
    array set argsArr $args
    set xmllist [wrapper::createtag query -attrlist {xmlns jabber:iq:browse}]
    send_iq $jlibname get $xmllist -to $to -command   \
      [list [namespace current]::parse_browse_get $jlibname $to  \
      $argsArr(-command) $argsArr(-errorcommand)]
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
    send_iq $jlibname "get" $xmllist -to $to -command   \
      [list [namespace current]::parse_agent_get $jlibname $to $cmd]
}

proc jlib::agents_get {jlibname to cmd} {

    set xmllist [wrapper::createtag "query" -attrlist {xmlns jabber:iq:agents}]
    send_iq $jlibname "get" $xmllist -to $to -command   \
      [list [namespace current]::parse_agents_get $jlibname $to $cmd]
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

    upvar [namespace current]::${jlibname}::lib lib
    upvar [namespace current]::${jlibname}::agent agent
    upvar [namespace current]::service::services services

    Debug 3 "jlib::parse_agent_get jid=$jid, cmd=$cmd, type=$type, subiq=$subiq"

    if {[string equal $type "error"]} {
	uplevel #0 $cmd [list $jlibname error $subiq]
	return
    } 
     
    # Loop through the subelement to see what we've got.
    foreach elem [wrapper::getchildren $subiq] {
	set tag [wrapper::gettag $elem]
	set agent($jid,$tag) [wrapper::getcdata $elem]
	if {[lsearch $services $tag] >= 0} {
	    lappend agent($tag) $jid
	}
	if {[string equal $tag "groupchat"]} {
	    [namespace current]::registergcprotocol $jlibname $jid "gc-1.0"
	}
    }    
    uplevel #0 $cmd [list $jlibname ok $subiq]
}

proc jlib::parse_agents_get {jlibname jid cmd type subiq} {

    upvar [namespace current]::${jlibname}::lib lib
    upvar [namespace current]::${jlibname}::agent agent
    upvar [namespace current]::service::services services

    Debug 3 "jlib::parse_agents_get jid=$jid, cmd=$cmd, type=$type, subiq=$subiq"

    if {[string equal $type "error"]} {
	uplevel #0 $cmd [list $jlibname error $subiq]
	return
    } 

    # Be sure that the login jabber server is the root.
    if {[string equal $lib(server) $jid]} {
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
		[namespace current]::registergcprotocol $jlibname $jid "gc-1.0"
	    }
	}
	set agent($jidAgent,parent) $jid
	lappend agent($jid,childs) $jidAgent	
    }
    uplevel #0 $cmd [list $jlibname ok $subiq]
}

# jlib::getagent --
# 
#       Accessor function for the agent stuff.

proc jlib::getagent {jlibname jid} {

    upvar [namespace current]::${jlibname}::agent agent

    if {[info exists agent($jid,parent)]} {
	return [array get agent "$jid,*"]
    } else {
	return ""
    }
}

proc jlib::have_agent {jlibname jid} {

    upvar [namespace current]::${jlibname}::agent agent

    if {[info exists agent($jid,parent)]} {
	return 1
    } else {
	return 0
    }
}

# jlib::vcard_get --
#
#       It implements the 'jabber:iq:vcard-temp' get method.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       to:
#       cmd:        client command to be executed at the iq "result" element.
#       
# Results:
#       none.

proc jlib::vcard_get {jlibname to cmd} {

    set attrlist [list xmlns vcard-temp]    
    set xmllist [wrapper::createtag {vCard} -attrlist $attrlist]
    send_iq $jlibname "get" $xmllist -to $to -command   \
      [list [namespace current]::parse_iq_response $jlibname $cmd]
}

# jlib::vcard_set --
#
#       Sends our vCard to the server.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       cmd:        client command to be executed at the iq "result" element.
#       args:       All keys are named so that the element hierarchy becomes
#                   vcardElement_subElement_subsubElement ... and so on;
#                   all lower case.
#                   
# Results:
#       none.

proc jlib::vcard_set {jlibname cmd args} {

    set attrlist [list xmlns vcard-temp]    
    
    # Form all the sub elements by inspecting the -key.
    array set arr $args
    set subelem {}
    set subsubelem {}
    
    # All "sub" elements with no children.
    foreach tag {fn nickname bday url title role desc} {
	if {[info exists arr(-$tag)]} {
	    lappend subelem [wrapper::createtag $tag -chdata $arr(-$tag)]
	}
    }
    if {[info exists arr(-email_internet_pref)]} {
	set elem {}
	lappend elem [wrapper::createtag internet]
	lappend elem [wrapper::createtag pref]
	lappend subelem [wrapper::createtag "email" \
	  -chdata $arr(-email_internet_pref) -subtags $elem]
    }
    if {[info exists arr(-email_internet)]} {
	foreach email $arr(-email_internet) {
	    set elem {}
	    lappend elem [wrapper::createtag internet]
	    lappend subelem [wrapper::createtag "email" \
	      -chdata $email -subtags $elem]
	}
    }
    
    # All "subsub" elements.
    foreach tag {n org} {
	set elem {}
	foreach key [array names arr "-${tag}_*"] {
	    regexp -- "-${tag}_(.+)" $key match sub
	    lappend elem [wrapper::createtag $sub -chdata $arr($key)]
	}
    
	# Insert subsub elements where they belong.
	if {[llength $elem]} {
	    lappend subelem [wrapper::createtag $tag -subtags $elem]
	}
    }
    
    # The <adr><home/>, <adr><work/> sub elements.
    foreach tag {adr_home adr_work} {
	regexp -- {([^_]+)_(.+)} $tag match head sub
	set elem [list [wrapper::createtag $sub]]
	set haveThisTag 0
	foreach key [array names arr "-${tag}_*"] {
	    set haveThisTag 1
	    regexp -- "-${tag}_(.+)" $key match sub
	    lappend elem [wrapper::createtag $sub -chdata $arr($key)]
	}		
	if {$haveThisTag} {
	    lappend subelem [wrapper::createtag $head -subtags $elem]
	}
    }	
    
    # The <tel> sub elements.
    foreach tag [array names arr "-tel_*"] {
	if {[regexp -- {-tel_([^_]+)_([^_]+)} $tag match second third]} {
	    set elem {}
	    lappend elem [wrapper::createtag $second]
	    lappend elem [wrapper::createtag $third]
	    lappend subelem [wrapper::createtag "tel" -chdata $arr($tag) \
	      -subtags $elem]
	}
    }

    set xmllist [wrapper::createtag {vCard} -attrlist $attrlist \
      -subtags $subelem]
    send_iq $jlibname "set" $xmllist -command \
      [list [namespace current]::parse_iq_response $jlibname $cmd]    
}

# jlib::private_get --
#
#       It implements the private and public store data get method.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       to:
#       ns:         namespace for the public/private data storage.
#       subtags:    list of the tags we query.
#       cmd:        client command to be executed at the iq "result" element.
#       
# Results:
#       none.

proc jlib::private_get {jlibname to ns subtags cmd} {

    set attrlist [list xmlns $ns]    
    foreach tag $subtags {
	lappend subelements [wrapper::createtag $tag]
    }
    set xmllist [wrapper::createtag "query" -attrlist $attrlist  \
      -subtags $subelements]
    send_iq $jlibname "get" $xmllist -to $to -command   \
      [list [namespace current]::parse_iq_response $jlibname $cmd]
}

# jlib::private_set --
#
#       It implements the private and public store data set method.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       ns:         namespace for the public/private data storage.
#       cmd:        client command to be executed at the iq "result" element.
#       args:       '-tagName {chdata ?{attr1 val1 ?attr2 val2 ...?}?}' pairs.
#       
# Results:
#       none.

proc jlib::private_set {jlibname ns cmd args} {
    
    set attrlist [list {xmlns} $ns]    
    
    # Form all the sub elements.
    set subelem {}
    foreach {mtag val} $args {
	set tag [string trimleft $mtag {-}]
	set chdata [lindex $val 0]
	
	# Any attributes?
	if {[llength $val] > 1} {
	    lappend subelem [wrapper::createtag $tag -chdata $chdata   \
	      -attrlist [lindex $val 1]]
	} else {
	    lappend subelem [wrapper::createtag $tag -chdata $chdata]
	}
    }
    set xmllist [wrapper::createtag "query" -attrlist [list {xmlns} $ns]  \
      -subtags $subelem]
    send_iq $jlibname "set" $xmllist -command        \
      [list [namespace current]::parse_iq_response $jlibname $cmd]    
}

# jlib::get_last --
#
#       Query the 'last' of 'to' using 'jabber:iq:last' get.

proc jlib::get_last {jlibname to cmd} {
    
    set xmllist [wrapper::createtag "query"  \
      -attrlist {xmlns jabber:iq:last}]
    send_iq $jlibname "get" $xmllist -to $to -command        \
      [list [namespace current]::parse_iq_response $jlibname $cmd]
}

# jlib::handle_get_last --
#
#       Seconds since last activity. Response to 'jabber:iq:last' get.

proc jlib::handle_get_last {jlibname from subiq args} {    

    upvar [namespace current]::${jlibname}::locals locals
    
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
    eval {send_iq $jlibname "result" $xmllist} $opts

    # Tell jlib's iq-handler that we handled the event.
    return 1
}

# jlib::get_time --
#
#       Query the 'time' of 'to' using 'jabber:iq:time' get.

proc jlib::get_time {jlibname to cmd} {
    
    set xmllist [wrapper::createtag "query"  \
      -attrlist {xmlns jabber:iq:time}]
    send_iq $jlibname "get" $xmllist -to $to -command        \
      [list [namespace current]::parse_iq_response $jlibname $cmd]
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
    eval {send_iq $jlibname "result" $xmllist} $opts

    # Tell jlib's iq-handler that we handled the event.
    return 1
}
    
# jlib::get_version --
#
#       Query the 'version' of 'to' using 'jabber:iq:version' get.

proc jlib::get_version {jlibname to cmd} {
        
    set xmllist [wrapper::createtag "query"  \
      -attrlist {xmlns jabber:iq:version}]
    send_iq $jlibname "get" $xmllist -to $to -command        \
      [list [namespace current]::parse_iq_response $jlibname $cmd]
}

# jlib::handle_get_time --
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
	append os " $tcl_platform(osVersion)"
    }
    lappend opts -to $from
    set subtags [list  \
      [wrapper::createtag name    -chdata "JabberLib"]  \
      [wrapper::createtag version -chdata $version]  \
      [wrapper::createtag os      -chdata $os] ]
    set xmllist [wrapper::createtag query -subtags $subtags  \
      -attrlist {xmlns jabber:iq:version}]
    eval {send_iq $jlibname "result" $xmllist} $opts

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
    
    # Perhaps we should clear our roster object here?
    
    set xmllist [wrapper::createtag "query"  \
      -attrlist {xmlns jabber:iq:roster}]
    send_iq $jlibname "get" $xmllist -command   \
      [list [namespace current]::parse_roster_get $jlibname 0 $cmd]
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

    upvar [namespace current]::${jlibname}::lib lib

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
    	if {$group != ""} {
	    lappend subdata [wrapper::createtag "group" -chdata $group]
	}
    }
    
    set xmllist [wrapper::createtag "query"   \
      -attrlist {xmlns jabber:iq:roster}      \
      -subtags [list [wrapper::createtag {item} -attrlist $attrlist  \
      -subtags $subdata]]]
    send_iq $jlibname "set" $xmllist -command   \
      [list [namespace current]::parse_roster_set $jlibname $jid $cmd  \
      $groups $name]
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
    
    array set argsArr $args  
    set xmllist [wrapper::createtag "query"   \
      -attrlist {xmlns jabber:iq:roster}      \
      -subtags [list  \
      [wrapper::createtag "item"   \
      -attrlist [list jid $jid subscription remove]]]]
    send_iq $jlibname "set" $xmllist -command   \
      [list [namespace current]::parse_roster_remove $jlibname $jid $cmd]
}

proc jlib::schedule_keepalive {jlibname} {   

    upvar [namespace current]::${jlibname}::locals locals
    upvar [namespace current]::${jlibname}::opts opts
    upvar [namespace current]::${jlibname}::lib lib

    if {$opts(-keepalivesecs) && $lib(isinstream)} {
	if {[catch {puts $lib(sock) "\n"} err]} {
	    disconnect $jlibname
	    uplevel #0 $lib(clientcmd) $jlibname networkerror -body \
	      "Network was disconnected"
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

    upvar [namespace current]::${jlibname}::locals locals
    upvar [namespace current]::${jlibname}::opts opts
    
    cancel_auto_away $jlibname
    if {$opts(-autoaway) && $opts(-awaymin) > 0} {
	set locals(afterawayid) [after [expr 60000 * $opts(-awaymin)] \
	  [list [namespace current]::auto_away_cmd $jlibname away]]
    }
    if {$opts(-xautoaway) && $opts(-xawaymin) > 0} {
	set locals(afterxawayid) [after [expr 60000 * $opts(-xawaymin)] \
	  [list [namespace current]::auto_away_cmd $jlibname xaway]]
    }    
}

proc jlib::cancel_auto_away {jlibname} {

    upvar [namespace current]::${jlibname}::locals locals

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

    upvar [namespace current]::${jlibname}::locals locals
    upvar [namespace current]::${jlibname}::lib lib
    upvar [namespace current]::${jlibname}::opts opts

    Debug 3 "jlib::auto_away_cmd what=$what"
    
    switch -- $what {
	away {
	    send_presence $jlibname -type "available" -show "away"  \
	      -status $opts(-awaymsg)
	}
	xaway {
	    send_presence $jlibname -type "available" -show "xa"  \
	      -status $opts(-xawaymsg)
	}
    }        
    uplevel #0 $lib(clientcmd) [list $jlibname $what]
}

# jlib::getrecipientjid --
# 
#       Tries to obtain the correct form of jid to send message to.
#       Follows the XMPP spec, section 4.1.

proc jlib::getrecipientjid {jlibname jid} {

    upvar [namespace current]::${jlibname}::lib lib
    
    jlib::splitjid $jid jid2 resource 
    set isroom [[namespace current]::service::isroom $jlibname $jid2]
    if {$isroom} {
	return $jid
    } elseif {[$lib(rostername) isavailable $jid]} {
	return $jid
    } else {
	return $jid2
    }
}

# jlib::splitjid --
# 
#       Splits a general jid into a jid-2-tier and resource

proc jlib::splitjid {jid jid2Var resourceVar} {
    
    set ind [string last / $jid]
    if {$ind == -1} {
	uplevel 1 [list set $jid2Var $jid]
	uplevel 1 [list set $resourceVar {}]
    } else {
	set jid2 [string range $jid 0 [expr $ind - 1]]
	set res [string range $jid [expr $ind + 1] end]
	uplevel 1 [list set $jid2Var $jid2]
	uplevel 1 [list set $resourceVar $res]
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

proc jlib::Debug {num str} {
    variable debug
    if {$num <= $debug} {
	puts $str
    }
}

#-------------------------------------------------------------------------------
#
# A couple of routines that handle the selection of groupchat protocol for
# each groupchat service.
# A groupchat service may support more than a single protocol. For instance,
# the MUC component supports both gc-1.0 and MUC.

# Needs some more verification before using it for a dispatcher.

# jlib::setgroupchatpriority --
# 
#       Sets the list if groupchat protocols in decreasing priority.
#       The list contains elements 'gc-1.0', 'conference', 'muc',
#       describing which to pick if multiple options.

proc jlib::setgroupchatpriority {jlibname priorityList} {

    variable statics
    upvar [namespace current]::${jlibname}::locals locals

    foreach prot $priorityList {
	if {![regexp $statics(groupchatTypeExp) $prot]} {
	    return -code error "Unrecognized groupchat type \"$prot\""
	}
    }
    set locals(gcProtoPriority) $priorityList
}

# jlib::setgroupchatprotocol --
# 
#       Explicitly picks a groupchat protocol to use for a groupchat service.
#       
# Arguments:
#       jlibname
#       jid
#       prot        any of 'gc-1.0', 'conference', 'muc'.
#
# Results:
#       None.

proc jlib::setgroupchatprotocol {jlibname jid prot} {

    variable statics
    upvar [namespace current]::${jlibname}::locals locals
    upvar [namespace current]::${jlibname}::agent agent
    upvar [namespace parent]::${jlibname}::lib lib
    upvar [namespace parent]::${jlibname}::opts opts

    if {![regexp $statics(groupchatTypeExp) $prot]} {
	return -code error "Unrecognized groupchat type \"$prot\""
    }
    switch -- $prot {
	gc-1.0 {
	    if {![info exists agent($jid,groupchat)]} {
		return -code error  \
		  "No groupchat agent registered for \"$jid\""
	    }
	}
	conference {
	    if {!$opts(havebrowse)} {
		return -code error \
		  "there is no browse object associated with this jlib"
	    }    
	    set confServicesJids [$lib(browsename) getconferenceservers]
	    if {[lsearch -exact $confServicesJids $jid] < 0} {
		return -code error \
		  "The jid $jid does not know of any \"conference\" service"
	    }
	}
	muc {
	    if {!$opts(havebrowse)} {
		# This must be changed when disco is coming...
		return -code error \
		  "there is no browse object associated with this jlib"
	    }    
	    if {![$lib(browsename) havenamespace $jid  \
	      "http://jabber.org/protocol/muc"]} {
		return -code error \
		  "The jid \"$jid\" does not know of any \"muc\" service"
	    }
	}
    }
    set locals(prefgcprot,$jid) $prot
}

# jlib::registergcprotocol --
# 
#       Register (sets) a groupchat service jid according to the priorities
#       presently set. Only called internally!

proc jlib::registergcprotocol {jlibname jid gcprot} {

    upvar [namespace current]::${jlibname}::locals locals
    
    Debug 2 "jlib::registergcprotocol jid=$jid, gcprot=$gcprot"
    
    # If we already told jlib to use a groupchat protocol then...
    if {[info exist locals(prefgcprot,$jid)]} {
	return
    }
    
    # Set 'locals(gcprot,$jid)' according to the priority list.
    foreach prot $locals(gcProtoPriority) {
	
	# Do we have registered a groupchat protocol with higher priority?
	if {[info exists locals(gcprot,$jid)] && \
		[string equal $locals(gcprot,$jid) $prot]} {
	    return
	}
	if {[string equal $prot $gcprot]} {
	    set locals(gcprot,$jid) $prot
	    return
	}	
    }
}

# jlib::setroomprotocol --
# 
#       Set the groupchat protocol in use for room. This acts only as a
#       dispatcher for 'service' commands.  
#       Only called internally when entering a room!

proc jlib::setroomprotocol {jlibname roomjid protocol} {

    variable statics
    upvar [namespace current]::${jlibname}::locals locals
    
    if {![regexp $statics(groupchatTypeExp) $protocol]} {
	return -code error "Unrecognized groupchat protocol \"$protocol\""
    }
    set locals(roomprot,$roomjid) $protocol
}

#--- namespace jlib::service ---------------------------------------------------

# jlib::service --
#
#       This is an abstraction layer for two things; the agent/browse/(disco?)
#       protocols, and for the groupchat protocols gc-1.0/conference/muc.

proc jlib::service {jlibname cmd args} {
    
    # Which command? Just dispatch the command to the right procedure.
    set ans [eval {[namespace current]::service::${cmd} $jlibname} $args]
    return $ans
}
    
proc jlib::service::parent {jlibname jid} {    

    upvar [namespace parent]::${jlibname}::agent agent
    upvar [namespace parent]::${jlibname}::lib lib
    upvar [namespace parent]::${jlibname}::opts opts

    if {$opts(havebrowse) && [$lib(browsename) isbrowsed $jid]} {
	return [$lib(browsename) getparentjid $jid]
    } else {
	if {[info exists agent($jid,parent)]} {
	    return $agent($jid,parent)
	} else {
	    return -code error "Parent of \"$jid\" cannot be found"
	}
    }
}

proc jlib::service::childs {jlibname jid} {    

    upvar [namespace parent]::${jlibname}::agent agent
    upvar [namespace parent]::${jlibname}::lib lib
    upvar [namespace parent]::${jlibname}::opts opts

    if {$opts(havebrowse) && [$lib(browsename) isbrowsed $jid]} {
	return [$lib(browsename) getchilds $jid]
    } else {
	if {[info exists agent($jid,childs)]} {
	    set agent($jid,childs) [lsort -unique $agent($jid,childs)]
	    return $agent($jid,childs)
	} else {
	    return -code error "Childs of \"$jid\" cannot be found"
	}
    }
}

# jlib::service::getjidsfor --
#
#       Return a list of jid's that support any of "search", "register",
#       "groupchat". Queries sent to both browser and agent.
#       
#       Problems with groupchat <--> conference Howto?
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       what:       "groupchat", "conference", "muc", "register", "search".
#       
# Results:
#       list of jids supporting this service, possibly empty.

proc jlib::service::getjidsfor {jlibname what} {

    variable services
    upvar [namespace parent]::${jlibname}::agent agent
    upvar [namespace parent]::${jlibname}::lib lib
    upvar [namespace parent]::${jlibname}::opts opts
    
    if {[lsearch $services $what] < 0} {
	return -code error "\"$what\" is not a recognized service"
    }
    set jids {}
    
    # Browse service if any.
    if {$opts(havebrowse)} {
	set browseNS [$lib(browsename) getservicesforns jabber:iq:${what}]
	if {[llength $browseNS]} {
	    set jids $browseNS
	}
	
	switch -- $what {
	    groupchat {
		
		# These server components support 'groupchat 1.0' as well.
		# The 'jabber:iq:conference' seems to be lacking in many jabber.xml.
		# Use 'getconferenceservers' as fallback.
		set jids [concat $jids \
		  [$lib(browsename) getservicesforns jabber:iq:conference]]	    
		set jids [concat $jids [$lib(browsename) getconferenceservers]]
		set jids [concat $jids [$lib(browsename) getservicesforns  \
		  "http://jabber.org/protocol/muc"]]
	    }
	    muc {
		set jids [concat $jids [$lib(browsename) getservicesforns  \
		  "http://jabber.org/protocol/muc"]]
	    }
	}
    }
       
    # Agent service if any.
    if {[info exists agent($what)] && [llength $agent($what)]} {
	set agent($what) [lsort -unique $agent($what)]
	set jids [concat $agent($what) $jids]
    }
    return [lsort -unique $jids]
}

# jlib::service::gettransportjids --
#
#       Return a list of jid's that support a specific transport.
#       Queries sent to both browser and agent.
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#       what:       "*", "jabber", "icq", "msn", "yahoo", "aim",...
#       
# Results:
#       list of jids supporting this service, possibly empty.

proc jlib::service::gettransportjids {jlibname what} {

    upvar [namespace parent]::${jlibname}::agent agent
    upvar [namespace parent]::${jlibname}::lib lib
    upvar [namespace parent]::${jlibname}::opts opts

    set jids {}
    
    # Browse service if any.
    if {$opts(havebrowse)} {
	set subtype $what
	set jids [$lib(browsename) getalljidfortypes "service/$subtype"]
    }

    # Agent service if any.
    foreach key [array names agent "*,service"] {
	if {[string equal $agent($key) $what] || ($what == "*")} {
	    lappend jids [string map {,service ""} $key]
	}
    }
    return [lsort -unique $jids]
}

# jlib::service::gettype --
# 
#       Returns the 'type/subtype' for this jid if any.
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:
#       
# Results:
#       type/subtype, possibly empty.

proc jlib::service::gettype {jlibname jid} {

    upvar [namespace parent]::${jlibname}::agent agent
    upvar [namespace parent]::${jlibname}::lib lib
    upvar [namespace parent]::${jlibname}::opts opts

    set type ""
    
    # Browse service if any. Returns 'service/icq' etc.
    if {$opts(havebrowse)} {
	set type [$lib(browsename) gettype $jid]
    }
    if {[info exists agent($jid,service)]} {
	set type "service/$agent($jid,service)"
    }
    return $type
}

# jlib::service::isroom --
# 
#       Try to figure out if the jid is a room.
#       If we've browsed it it's been registered in our browse object.
#       If using agent(s) method, check the agent for this jid

proc jlib::service::isroom {jlibname jid} {    

    upvar [namespace parent]::${jlibname}::agent agent
    upvar [namespace parent]::${jlibname}::lib lib
    upvar [namespace parent]::${jlibname}::opts opts
    
    # Check if domain name supports the 'groupchat' service.
    set isroom 0
    if {$opts(havebrowse) && [$lib(browsename) isbrowsed $lib(server)]} {
	if {[$lib(browsename) isroom $jid]} {
	    set isroom 1
	}
    } elseif {[regexp {^[^@]+@([^@ ]+)$} $jid match domain]} {
	if {[info exists agent($domain,groupchat)]} {
	    set isroom 1
	}
    }
    return $isroom
}

# jlib::service::nick --
#
#       Return nick name for ANY room participant, or the rooms name
#       if jid is a room.
#       For the browser we return the <name> chdata, but for the
#       groupchat-1.0 protocol we use a scheme to find nick.
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        'roomname@conference.jabber.org/nickOrHex' typically,
#                   or just room jid.

proc jlib::service::nick {jlibname jid} {   

    upvar [namespace parent]::${jlibname}::lib lib
    upvar [namespace parent]::${jlibname}::locals locals

    # All kind of conference components seem to support the old 'gc-1.0'
    # protocol, and we therefore must query our method for entering the room.
    if {![regexp {^([^/]+)/.+} $jid match room]} {
	set room $jid
    } 
    if {![info exists locals(roomprot,$room)]} {
	return -code error "Does not know which protocol to use in $room"
    }
    set nick ""
    
    switch -- $locals(roomprot,$room) {
	gc-1.0 {
	    
	    # Old-style groupchat just has /nick.
	    if {[regexp {^[^@]+@[^@/]+/(.+)$} $jid match nick]} {
		
		# Else we just use the username. (If room for instance)
	    } elseif {![regexp {^([^@]+)@[^@/]+$} $jid match nick]} {
		set nick $jid
	    }
	}
	muc {
	    
	    # The MUC conference method: nick is always the resource part. 
	    # Rooms lack the */res.
	    if {![regexp {^[^@]+@[^@/]+/(.+)$} $jid match nick]} {
		if {![regexp {^([^@]+)@.+} $jid match nick]} {
		    set nick $jid
		}
	    }
	}	
	conference {
	    if {[$lib(browsename) isbrowsed $lib(server)]} {
		
		# Assume that if the login server is browsed we also should query
		# the browse object.
		set nick [$lib(browsename) getname $jid]
	    }
	}
    }
    return $nick
}

# jlib::service::hashandnick --
#
#       A way to get our OWN three-tier jid and nickname for a given room
#       independent on if 'conference' or 'groupchat' is used.
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#       room:       'roomname@conference.jabber.org' typically.
#       
# Results:
#       list {kitchen@conf.athlon.se/63264ba6724.. mynickname}

proc jlib::service::hashandnick {jlibname room} {    

    upvar [namespace parent]::${jlibname}::lib lib
    upvar [namespace parent]::${jlibname}::locals locals

    # All kind of conference components seem to support the old 'gc-1.0'
    # protocol, and we therefore must query our method for entering the room.
    if {![info exists locals(roomprot,$room)]} {
	return -code error "Does not know which protocol to use in $room"
    }
    set hashandnick [list ${room}/ ""]
    
    switch -- $locals(roomprot,$room) {
	gc-1.0 {
	
	    # Old-style groupchat just has /nick.
	    set nick [[namespace parent]::groupchat::mynick $jlibname $room]
	    set hashandnick [list ${room}/${nick} $nick]   
	} 
	muc {
	    set nick [[namespace parent]::muc::mynick $jlibname $room]
	    set hashandnick [list ${room}/${nick} $nick]   
	} 
	conference {
	    if {[$lib(browsename) isbrowsed $lib(server)]} {
		set hashandnick  \
		  [[namespace parent]::conference::hashandnick $jlibname $room]
	    }
	}
    }
    
    return $hashandnick
}

# jlib::service::allroomsin --
# 
# 

proc jlib::service::allroomsin {jlibname} {    

    upvar [namespace parent]::${jlibname}::lib lib
    upvar [namespace parent]::${jlibname}::gchat gchat

    set roomList [concat $gchat(allroomsin) \
      [[namespace parent]::muc::allroomsin $jlibname] \
      [[namespace parent]::conference::allroomsin $jlibname]]
    return [lsort -unique $roomList]
}

proc jlib::service::roomparticipants {jlibname room} {

    upvar [namespace parent]::${jlibname}::lib lib
    upvar [namespace parent]::${jlibname}::locals locals
    
    if {![info exists locals(roomprot,$room)]} {
	return -code error "Does not know which protocol to use in $room"
    }

    set everyone {}
    if {![[namespace current]::isroom $jlibname $room]} {
	return -code error "The jid \"$room\" is not a room"
    }

    switch -- $locals(roomprot,$room) {
	gc-1.0 {
	    set everyone [[namespace parent]::groupchat::participants $jlibname $room]
	} 
	muc {
	    set everyone [[namespace parent]::muc::participants $jlibname $room]
	}
	conference {
	    if {[$lib(browsename) isbrowsed $lib(server)]} {
		set everyone [$lib(browsename) getchilds $room]
	    }
	}
    }
    return $everyone
}

proc jlib::service::exitroom {jlibname room} {    

    upvar [namespace parent]::${jlibname}::lib lib
    upvar [namespace parent]::${jlibname}::locals locals

    if {![info exists locals(roomprot,$room)]} {
	return -code error "Does not know which protocol to use in $room"
    }

    switch -- $locals(roomprot,$room) {
	gc-1.0 {
	    [namespace parent]::groupchat::exit $jlibname $room
	}
	muc {
	    [namespace parent]::muc::exit $jlibname $room
	}
	conference {
	    if {[$lib(browsename) isbrowsed $lib(server)]} {
		[namespace parent]::conference::exit $jlibname $room
	    }
	}
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
    [namespace parent]::send_iq $jlibname "get" $xmllist -to $room -command  \
      [list [namespace parent]::parse_iq_response $jlibname $cmd]
    [namespace parent]::setroomprotocol $jlibname $room "conference"
    return ""
}

proc jlib::conference::set_enter {jlibname room subelements cmd} {

    [namespace parent]::send_presence $jlibname -to $room
    [namespace parent]::send_iq $jlibname "set"  \
      [wrapper::createtag "enter" -attrlist {xmlns jabber:iq:conference} \
      -subtags $subelements] -to $room -command  \
      [list [namespace current]::parse_set_enter $jlibname $room $cmd]
    return ""
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

    upvar [namespace parent]::${jlibname}::conf conf

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
	uplevel #0 $cmd [list $jlibname ok $subiq]
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
    [namespace parent]::send_iq $jlibname "get" $xmllist -to $to -command   \
      [list [namespace parent]::parse_iq_response $jlibname $cmd]
}

proc jlib::conference::set_create {jlibname room subelements cmd} {

    # We use the same callback as 'set_enter'.
    [namespace parent]::send_presence $jlibname -to $room
    [namespace parent]::send_iq $jlibname "set"  \
      [wrapper::createtag "create" -attrlist {xmlns jabber:iq:conference} \
      -subtags $subelements] -to $room -command  \
      [list [namespace current]::parse_set_enter $jlibname $room $cmd]
    [namespace parent]::setroomprotocol $jlibname $room "conference"
    return ""
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
    [namespace parent]::send_iq $jlibname "set" $xmllist -to $room -command  \
      [list [namespace parent]::parse_iq_response $jlibname $cmd]
    return ""
}

proc jlib::conference::exit {jlibname room} {

    upvar [namespace parent]::${jlibname}::conf conf
    upvar [namespace parent]::${jlibname}::lib lib

    [namespace parent]::send_presence $jlibname -to $room -type unavailable
    set ind [lsearch -exact $conf(allroomsin) $room]
    if {$ind >= 0} {
	set conf(allroomsin) [lreplace $conf(allroomsin) $ind $ind]
    }
    $lib(rostername) clearpresence "${room}*"
    return ""
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
    [namespace parent]::send_iq $jlibname "set" $xmllist -to $room -command  \
      [list [namespace parent]::parse_iq_response $jlibname $cmd]
}

# jlib::conference::hashandnick --
#
#       Returns list {kitchen@conf.athlon.se/63264ba6724.. mynickname}

proc jlib::conference::hashandnick {jlibname room} {

    upvar [namespace parent]::${jlibname}::conf conf

    if {[info exists conf($room,hashandnick)]} {
	return $conf($room,hashandnick)
    } else {
	return -code error "Unknown room \"$room\""
    }
}

proc jlib::conference::roomname {jlibname room} {

    upvar [namespace parent]::${jlibname}::conf conf

    if {[info exists conf($room,roomname)]} {
	return $conf($room,roomname)
    } else {
	return -code error "Unknown room \"$room\""
    }
}

proc jlib::conference::allroomsin {jlibname} {

    upvar [namespace parent]::${jlibname}::conf conf
    
    set conf(allroomsin) [lsort -unique $conf(allroomsin)]
    return $conf(allroomsin)
}

#--- namespace jlib::groupchat -------------------------------------------------

# jlib::groupchat --
#
#       Provides API's for the old-style groupchat protocol, 'groupchat 1.0'.

proc jlib::groupchat {jlibname cmd args} {
    
    # Which command? Just dispatch the command to the right procedure.
    set ans [eval {[namespace current]::groupchat::${cmd} $jlibname} $args]
    return $ans
}

# jlib::groupchat::enter --
#
#       Enter room using the 'gc-1.0' protocol by sending <presence>.
#
#       args:  -command callback

proc jlib::groupchat::enter {jlibname room nick args} {

    upvar [namespace parent]::${jlibname}::gchat gchat
    
    set room [string tolower $room]
    set jid ${room}/${nick}
    eval {[namespace parent]::send_presence $jlibname -to $jid} $args
    set gchat($room,mynick) $nick
    
    # This is not foolproof since it may not always success.
    lappend gchat(allroomsin) $room
    [namespace parent]::setroomprotocol $jlibname $room "gc-1.0"
    set gchat(allroomsin) [lsort -unique $gchat(allroomsin)]
    return ""
}

proc jlib::groupchat::exit {jlibname room} {

    upvar [namespace parent]::${jlibname}::gchat gchat
    upvar [namespace parent]::${jlibname}::lib lib
    
    set room [string tolower $room]
    if {[info exists gchat($room,mynick)]} {
	set nick $gchat($room,mynick)
    } else {
	return -code error "Unknown nick name for room \"$room\""
    }
    set jid ${room}/${nick}
    [namespace parent]::send_presence $jlibname -to $jid -type "unavailable"
    unset gchat($room,mynick)
    set ind [lsearch -exact $gchat(allroomsin) $room]
    if {$ind >= 0} {
	set gchat(allroomsin) [lreplace $gchat(allroomsin) $ind $ind]
    }
    $lib(rostername) clearpresence "${room}*"
    return ""
}

proc jlib::groupchat::mynick {jlibname room args} {

    upvar [namespace parent]::${jlibname}::gchat gchat

    set room [string tolower $room]
    if {[llength $args] == 0} {
	if {[info exists gchat($room,mynick)]} {
	    return $gchat($room,mynick)
	} else {
	    return -code error "Unknown nick name for room \"$room\""
	}
    } elseif {[llength $args] == 1} {
	
	# This should work automatically.
	enter $jlibname $room $args
    } else {
	return -code error "Wrong number of arguments"
    }
}

proc jlib::groupchat::status {jlibname room args} {

    upvar [namespace parent]::${jlibname}::gchat gchat

    set room [string tolower $room]
    if {[info exists gchat($room,mynick)]} {
	set nick $gchat($room,mynick)
    } else {
	return -code error "Unknown nick name for room \"$room\""
    }
    set jid ${room}/${nick}
    eval {[namespace parent]::send_presence $jlibname -to $jid} $args
}

proc jlib::groupchat::participants {jlibname room} {

    upvar [namespace parent]::${jlibname}::agent agent
    upvar [namespace parent]::${jlibname}::gchat gchat
    upvar [namespace parent]::${jlibname}::lib lib

    set room [string tolower $room]
    set isroom 0
    if {[regexp {^[^@]+@([^@ ]+)$} $room match domain]} {
	if {[info exists agent($domain,groupchat)]} {
	    set isroom 1
	}
    }    
    if {!$isroom} {
	return -code error "Not recognized \"$room\" as a groupchat room"
    }
    
    # The rosters presence elements should give us all info we need.
    set everyone {}
    foreach userAttr [$lib(rostername) getpresence $room -type available] {
	catch {unset attrArr}
	array set attrArr $userAttr
	lappend everyone ${room}/$attrArr(-resource)
    }
    return $everyone
}

proc jlib::groupchat::allroomsin {jlibname} {

    upvar [namespace parent]::${jlibname}::gchat gchat

    set gchat(allroomsin) [lsort -unique $gchat(allroomsin)]
    return $gchat(allroomsin)
}

#-------------------------------------------------------------------------------
