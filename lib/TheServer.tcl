#  TheServer.tcl ---
#  
#       This file is part of The Coccinella application. It implements the
#       server part and contains procedures for creating new server side sockets,
#       handling canvas operations and file transfer.
#      
#  Copyright (c) 1999-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: TheServer.tcl,v 1.22 2004-05-06 13:41:11 matben Exp $
    
# DoStartServer ---
#
#       This belongs to the server part, but is necessary for autoStartServer.
#       Some operations can be critical since the app is not yet completely 
#       launched.
#       Therefore 'after idle'.(?)

proc DoStartServer {thisServPort} {
    global  prefs state this
    
    if {[catch {socket -server SetupChannel $thisServPort} sock]} {
	after 500 {tk_messageBox -message [FormatTextForMessageBox \
	  [::msgcat::mc messfailserver]]  \
	  -icon error -type ok}
    } else {
	set state(serverSocket) $sock
	set state(isServerUp) 1
	
	# Sometimes this gives 0.0.0.0, why I don't know.
	set sockname [fconfigure $sock -sockname]
	if {[lindex $sockname 0] != "0.0.0.0"} {
	    set this(ipnum) [lindex $sockname 0]
	}
    }
}

# DoStopServer --
#   
#       Closes the server socket, prevents new connections, but existing ones
#       are kept alive.
#       
# Arguments:
#       
# Results:
#       none

proc DoStopServer { } {
    global  state
    
    catch {close $state(serverSocket)}
    set state(isServerUp) 0
}

# SetupChannel --
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

proc SetupChannel {channel ip port} {
    
    # This is the important code that sets up the server event handler.
    fileevent $channel readable [list HandleClientRequest $channel $ip $port]

    # Everything should be done with 'fileevent'.
    fconfigure $channel -blocking 0

    # Everything is lineoriented except binary transfer operations.
    fconfigure $channel -buffering line
    
    # For nonlatin characters to work be sure to use Unicode/UTF-8.
    catch {fconfigure $channel -encoding utf-8}

    Debug 2 "---> Connection made to $ip:${port} on channel $channel."
    
    ::hooks::run serverNewConnectionHook $channel $ip $port
}

# HandleClientRequest --
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

proc HandleClientRequest {channel ip port} {
    global  fileTransportChannel prefs
        
    # If client closes socket to this server.
        
    if {[catch {eof $channel} iseof] || $iseof} {

	::Debug 2 "HandleClientRequest:: eof channel=$channel"
	fileevent $channel readable {}
	
	# Update entry only for nontemporary channels.
	if {[info exists fileTransportChannel($channel)]} {
	    unset fileTransportChannel($channel)
	} else {
	    ::hooks::run serverEofHook $channel $ip $port
	}
		
    } elseif {[gets $channel line] != -1} {
	
	# Check that line does not contain any embedded command.
	if {$prefs(checkSafety)} {

	    # If any "[" that is not backslashed or embraced, then skip it.
	    # Security is not treated well, must do better!!!!!!!!!!!
	    
	    set ans [IsServerCommandSafe $line]
	    if {[string equal $ans "0"]} {
		puts "Warning: the following command to the server was considered\
		  potentially harmful:\n\t$line"
		return
	    } else {
		set line $ans
	    }
	}
	
	# Interpret the command we just read. 
	# Non Jabber only supports a single whiteboard instance.
	ExecuteClientRequest $channel $ip $port $line
    }
}

proc ExecuteClientRequest {channel ip port line args} {
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

# IsServerCommandSafe --
#
#       Look for any "[" that are not backslashed "\[" and not embraced {...[...}
#     
# Arguments:
#       cmd        Typically a canvas command, but can be any string.
#
# Returns:
#       0          If not safe
#       cmd        If safe; see comments above.

proc IsServerCommandSafe { cmd } {
    
    # Patterns:
    # Verbatim [ that is not backslashed.
    set lbr_ {[^\\]\[}
    set lbr2_ {\[}
    set nolbr_ {[^\{]*}
    set norbr_ {[^\}]*}
    set noanybr_ {[^\}\{]*}
    set any_ {.*}

    if {[regexp "^(${any_})${lbr_}(${any_})$" $cmd match leftStr rightStr]} {
	
	# We have got one "[" that is not backslashed. Check if it's embraced.
	# Works only for one level of braces.
	
	if {[regexp "\{${noanybr_}${lbr2_}${noanybr_}\}" $cmd]} {
	    return $cmd
	} else {
	    return 0
	}
    } else {
	return $cmd
    }
}

#-------------------------------------------------------------------------------
