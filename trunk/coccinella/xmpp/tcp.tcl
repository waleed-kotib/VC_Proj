#  tcp.tcl --
#  
#      This is a skeleton to create a xmpp library from scratch.
#      The procedures for the standard socket transport layer.
#      
#  Copyright (c) 2008  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: tcp.tcl,v 1.1 2008-08-19 13:47:57 matben Exp $

package provide xmpp::tcp 0.1

namespace eval xmpp::tcp {

    
}

# xmpp::tcp::initsocket
#
#	Default transport mechanism; init already opened socket.
#
# Arguments:
# 
# Side Effects:
#	none

proc xmpp::tcp::initsocket {this} {

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

# xmpp::tcp::putssocket
#
#	Default transport mechanism; put directly to socket.
#
# Arguments:
# 
#	xml    The xml that is to be written.
#
# Side Effects:
#	none

proc xmpp::tcp::putssocket {this xml} {

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

# xmpp::tcp::resetsocket
#
#	Default transport mechanism; reset socket.
#
# Arguments:
# 
# Side Effects:
#	none

proc xmpp::tcp::resetsocket {jlibname} {

    upvar ${jlibname}::lib lib
    upvar ${jlibname}::locals locals

    catch {close $lib(sock)}
    catch {after cancel $locals(aliveid)}

    set lib(socketfilter,out) [list]
    set lib(socketfilter,in)  [list]
}

# xmpp::tcp::recvsocket --
#
#	Default transport mechanism; fileevent on socket socket.
#       Callback on incoming socket xml data. Feeds our wrapper and XML parser.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       
# Results:
#       none.

proc xmpp::tcp::recvsocket {this} {

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

proc xmpp::tcp::set_socket_filter {this outcmd incmd} {
    
    upvar ${jlibname}::lib lib

    set lib(socketfilter,out) $outcmd
    set lib(socketfilter,in)  $incmd

    fconfigure $lib(sock) -translation binary
}

# xmpp::tcp::ipsocket --
# 
#       Get our own ip address.

proc xmpp::tcp::ipsocket {this} {
    
    upvar ${jlibname}::lib lib
    
    if {[string length $lib(sock)]} {
	return [lindex [fconfigure $lib(sock) -sockname] 0]
    } else {
	return ""
    }
}
