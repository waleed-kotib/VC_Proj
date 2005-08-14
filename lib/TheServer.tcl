#  TheServer.tcl ---
#  
#       This file is part of The Coccinella application. It implements the
#       server part and contains procedures for creating new server side sockets,
#       handling canvas operations and file transfer.
#      
#  Copyright (c) 1999-2005  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: TheServer.tcl,v 1.29 2005-08-14 07:17:55 matben Exp $
    
package provide TheServer 1.0

namespace eval ::TheServer:: { 

    ::hooks::register launchFinalHook       ::TheServer::LaunchHook
}

proc ::TheServer::LaunchHook { } {
    global  prefs canvasSafeInterp
    
    if {$prefs(makeSafeServ)} {
	set canvasSafeInterp [interp create -safe]
	
	# Make an alias in the safe interpreter to enable drawing in the canvas.
	$canvasSafeInterp alias SafeCanvasDraw ::CanvasUtils::CanvasDrawSafe
    }

    # Start the server. It was necessary to have an 'update idletasks' command here
    # because when starting the script directly, and not from within wish, somehow
    # there was a timing problem in '::TheServer::DoStartServer'.
    # Don't start the server if we are a client only.

    if {($prefs(protocol) ne "client") && $prefs(autoStartServer)} {
	after $prefs(afterStartServer) [list ::TheServer::DoStartServer $prefs(thisServPort)]
    }
}

# ::TheServer::DoStartServer ---
#
#       This belongs to the server part, but is necessary for autoStartServer.
#       Some operations can be critical since the app is not yet completely 
#       launched.
#       Therefore 'after idle'.(?)

proc ::TheServer::DoStartServer {thisServPort} {
    global  prefs state this
    
    if {[catch {
	socket -server [namespace current]::SetupChannel $thisServPort
    } sock]} {
	after 500 {::UI::MessageBox -message [mc messfailserver] \
	  -icon error -type ok}
    } else {
	set state(serverSocket) $sock
	set state(isServerUp) 1
	
	# Sometimes this gives 0.0.0.0, why I don't know.
	set sockname [fconfigure $sock -sockname]
	if {[lindex $sockname 0] ne "0.0.0.0"} {
	    set this(ipnum) [lindex $sockname 0]
	}

	# Stop before quitting.
	::hooks::register quitAppHook ::TheServer::DoStopServer
    }
}

# ::TheServer::DoStopServer --
#   
#       Closes the server socket, prevents new connections, but existing ones
#       are kept alive.
#       
# Arguments:
#       
# Results:
#       none

proc ::TheServer::DoStopServer { } {
    global  state
    
    catch {close $state(serverSocket)}
    set state(isServerUp) 0
}

# ::TheServer::SetupChannel --
#   
#       Handles remote connections to the server port. 
#       Sets up the callback routine.
#       
# Arguments:
#       channel     the socket
#       ip          ip number
#       port        port number
#       
# Results:
#       socket event handler set up.

proc ::TheServer::SetupChannel {channel ip port} {
    
    # This is the important code that sets up the server event handler.
    fileevent $channel readable [list ::TheServer::HandleClientRequest $channel $ip $port]

    # Everything should be done with 'fileevent'.
    fconfigure $channel -blocking 0

    # Everything is lineoriented except binary transfer operations.
    fconfigure $channel -buffering line
    
    # For nonlatin characters to work be sure to use Unicode/UTF-8.
    catch {fconfigure $channel -encoding utf-8}

    Debug 2 "---> Connection made to $ip:${port} on channel $channel."
    
    ::hooks::run serverNewConnectionHook $channel $ip $port
}

# ::TheServer::HandleClientRequest --
#
#       This is the actual server that reads client requests. 
#       The most important is the CANVAS command which is a complete
#       canvas command that is prefixed only by the widget path.
#
# Arguments:
#       channel
#       ip
#       port
#       
# Results:
#       one line read from socket.

proc ::TheServer::HandleClientRequest {channel ip port} {
    global  fileTransportChannel prefs
        
    # If client closes socket to this server.
        
    if {[catch {eof $channel} iseof] || $iseof} {

	::Debug 2 "::TheServer::HandleClientRequest:: eof channel=$channel"
	fileevent $channel readable {}
	
	# Update entry only for nontemporary channels.
	if {[info exists fileTransportChannel($channel)]} {
	    unset fileTransportChannel($channel)
	} else {
	    ::hooks::run serverEofHook $channel $ip $port
	}
		
    } elseif {[gets $channel line] != -1} {
		
	# Interpret the command we just read. 
	# Non Jabber only supports a single whiteboard instance.
	ExecuteClientRequest $channel $ip $port $line
    }
}

proc ::TheServer::ExecuteClientRequest {channel ip port line args} {
    global  fileTransportChannel
    
    if {![regexp {^([A-Z ]+): *(.*)$} $line x cmd instr]} {
	return
    }
    
    switch -exact -- $cmd {
	GET {

	    # Do not interfer with put/get operations.
	    fileevent $channel readable {}
	    set fileName [lindex $instr 0]
	    set optList [lrange $instr 1 end]
	    set opts [::Import::GetTclSyntaxOptsFromTransport $optList]
	    set fileTransportChannel($channel) 1
	    
	    ::hooks::run serverGetRequestHook $channel $ip $fileName $opts
	}
	PUT {
	    fileevent $channel readable {}
	    set fileName [file tail [lindex $instr 0]]
	    set optList [lrange $instr 1 end]
	    set opts [::Import::GetTclSyntaxOptsFromTransport $optList]
	    set fileTransportChannel($channel) 1
	    
	    ::hooks::run serverPutRequestHook $channel $fileName $opts
	}
	default {
	    ::hooks::run serverCmdHook $channel $ip $port $line
	}
    }    
}

#-------------------------------------------------------------------------------
