# getfile.tcl --
#
#	Server-side get file from remote peer for whiteboard.
#
#  Copyright (c) 2003-2004  Mats Bengtsson
#
# $Id: getfile.tcl,v 1.1 2004-03-15 11:18:59 matben Exp $
# 
# USAGE ########################################################################
#
# getfile::get sock fileName ?-key value ...?
#    	-blocksize size 
#	-command procname
#	-displayname name
#	-mimetype mime
#	-progress procname
#	-size fileSize
#
# getfile::getfromserver path fileName ip port ?-key value ...?
#    	-blocksize size 
#	-command procname
#	-displayname name
#	-mimetype mime
#	-optlist
#	-progress procname
#	-size fileSize
#	-timeout
#
# getfile::status token
# getfile::ncode token
# getfile::ncodetotext ncode
# getfile::size token
# getfile::error token
# getfile::cleanup token
# getfile::reset token
#
# Callback interface:
#	-command:	GetCommand {token what msg}
#			what is "ok" or "error"
#			It is called at certain events to provide the client
#			a message code that can be useful for msgcat.
#	-progress:	GetProgress {token total current}
#			total is file size in bytes, and current is bytes so far

package require Tcl 8.4
package require uriencode

package provide getfile 1.0

namespace eval getfile {
    variable get

    variable debug 0
    set get(uid) 0
    set get(opts) {-blocksize -command -displayname -mimetype -progress -size}
    set get(clientopts) {-blocksize -command -displayname -mimetype -optlist \
      -progress -size -timeout}

    variable urlTypes
    array set urlTypes {
	http	{80 ::socket}
    }

    variable codeToText
    array set codeToText {
	100 Continue
	101 {Switching Protocols}
	200 OK
	201 Created
	202 Accepted
	203 {Non-Authoritative Information}
	204 {No Content}
	205 {Reset Content}
	206 {Partial Content}
	300 {Multiple Choices}
	301 {Moved Permanently}
	302 Found
	303 {See Other}
	304 {Not Modified}
	305 {Use Proxy}
	307 {Temporary Redirect}
	320 {File already cached}
	321 {MIME type unsupported}
	322 {MIME type not given}
	323 {File obtained via url instead}
	340 {No other clients connected}
	400 {Bad Request}
	401 Unauthorized
	402 {Payment Required}
	403 Forbidden
	404 {Not Found}
	405 {Method Not Allowed}
	406 {Not Acceptable}
	407 {Proxy Authentication Required}
	408 {Request Time-out}
	409 Conflict
	410 Gone
	411 {Length Required}
	412 {Precondition Failed}
	413 {Request Entity Too Large}
	414 {Request-URI Too Large}
	415 {Unsupported Media Type}
	416 {Requested Range Not Satisfiable}
	417 {Expectation Failed}
	500 {Internal Server Error}	
	501 {Not Implemented}
	502 {Bad Gateway}
	503 {Service Unavailable}
	504 {Gateway Time-out}
	505 {HTTP Version not supported}
    }
}

# getfile::get --
#
#	Initiates a get file process from a client on an already open channel.
#	Enclose this call in a 'catch', since it may throw errors.
#
# Arguments:
#	sock            Open socket.
#       fileName	The complete file path on local disk to put.
#       args		Option value pairs. Valid options include:
#			-blocksize, -command, -mimetype, -progress, -size
# Results:
#	Returns a token for this connection.
#	This token is the name of an array that the caller should
#	unset to garbage collect the state.

proc getfile::get {sock fileName args} {
    
    variable get
    variable codeToText

    Debug 2 "getfile::get fileName=$fileName, args='$args'"
    
    # Be sure to switch off any fileevent before fcopy.
    fileevent $sock readable {}
    fileevent $sock writable {}
    
    # Initialize the state variable, an array.  We'll return the
    # name of this array as the token for the transaction.
    
    set token [namespace current]::get[incr get(uid)]
    variable $token
    upvar 0 $token state
    reset $token
    
    # Process command options.
    
    array set state {
	-blocksize 	8192
	-mimetype       application/octet-stream
	-size           0
	state		header
	currentsize	0
	totalsize	0
	status 	        ""
	ncode           ""
    }
    set state(filetail) [file tail $fileName]
    set state(-displayname) $state(filetail)
    if {[catch {
	eval {getfile::VerifyOptions $token $get(opts)} $args
    } msg]} {
	return -code error $msg
    }
    
    # Open the file for writing.
    if {[catch {open $fileName w} fd]} {
	Debug 4 "getfile::get catch {open $fileName w}"
	puts $sock "TCLWB/1.0 500 $codeToText(500)"
	close $sock
	
	# Handle error.
	Finish $token "" 1
	cleanup $token
	return -code error $codeToText(500)
    }    
    set state(file)      $fileName
    set state(fd)        $fd
    set state(sock)      $sock
    set state(ip)        [lindex [fconfigure $sock -peername] 1]
    set state(totalsize) $state(-size)
            
    # If we have come so far it's ok.
    if {[catch {
	puts $sock "TCLWB/1.0 200 $codeToText(200)"
	flush $sock
    } err]} {	
	Debug 4 "getfile::get TCLWB/1.0 200"
	Finish $token "" 1
	cleanup $token
	return -code error neterr
    }
    
    # Use the MIME type to hint transfer mode for *file write*.
    if {[string match -nocase text/* $state(-mimetype)]} {
	fconfigure $fd -translation auto
	fconfigure $sock -translation auto
	
	# For nonlatin characters to work be sure to use Unicode/UTF-8.
	catch {fconfigure $fd -encoding utf-8}
	catch {fconfigure $sock -encoding utf-8}
    } else {
	fconfigure $fd -translation {binary binary}
	fconfigure $sock -translation {binary binary}
    }
    
    # Initiate a sequence of background fcopies
    CopyStart $sock $fd $token 
    ::Debug 4 "getfile::get exit"
    
    return $token
}

# getfile::getfromserver --
#
#       Initializes a get operation to get a file from a remote server.
#       Thus, we open a fresh socket to a server. The initiative for this
#       get operation is solely ours.
#       Open new temporary socket only for this get operation.
#       
# Arguments:
#       path            It must be a pathname relative the servers base 
#                       directory including any ../ if up dir. 
#                       Keep it a unix path style. uri encoded!
#       fileName	The complete file path on local disk to put fetched.
#       ip              IP number or address name to remote peer.
#	port            peer's port number.
#       args		Option value pairs. Valid options include:
#				-blocksize, -mimetype, -progress, -timeout, 
#				-optlist, -size
# Results:
#	Returns a token for this connection.
#	This token is the name of an array that the caller should
#	unset to garbage collect the state.

proc getfile::getfromserver {path fileName ip port args} {
    global errorInfo errorCode    
    variable get
    variable urlTypes

    Debug 2  "getfile::getfromserver path=$path, fileName=$fileName, args='$args'"
    
    # Initialize the state variable, an array.  We'll return the
    # name of this array as the token for the transaction.
    set token [namespace current]::get[incr get(uid)]
    variable $token
    upvar 0 $token state
    reset $token

    # Process command options.    
    array set state {
	-blocksize 	8192
	-timeout 	0
	-mimetype       application/octet-stream 
	-optlist        {}
	-size           0
	state		header
	currentsize	0
	totalsize	0
	status 	        ""
	ncode           ""
    }
    if {[catch {
	eval {getfile::VerifyOptions $token $get(clientopts)} $args
    } msg]} {
	return -code error $msg
    }
    
    # Open the file.
    if {[catch {open $fileName w} fd]} {
	
	# Handle error.
	Debug 4 "getfile::getfromserver catch {open $fileName w}"
	Finish $token "" 1
	cleanup $token
	return -code error $fd
    }
    set state(path)         $path
    set state(filetail)     [file tail $fileName]
    set state(-displayname) $state(filetail)
    set state(file)         $fileName
    set state(fd)           $fd
    set state(ip)           $ip
    set state(totalsize)    $state(-size)
    
    # Use the MIME type to hint transfer mode for *file read*.
    if {[string match -nocase text/* $state(-mimetype)]} {
	fconfigure $fd -translation auto
	
	# For nonlatin characters to work be sure to use Unicode/UTF-8.
	catch {fconfigure $fd -encoding utf-8}
    } else {
	fconfigure $fd -translation {binary binary}
    }
    
    # If a timeout is specified we set up the after event
    # and arrange for an asynchronous socket connection.    
    if {$state(-timeout) > 0} {
	set state(after) [after $state(-timeout) \
	  [list putfile::reset $token timeout]]
	set async -async
    } else {
	set async ""
    }
    #set defCmd [lindex $urlTypes($proto) 1]
    set defCmd ::socket
    
    # Open socket to peer, blocked or async.
    
    set conStat [catch {eval $defCmd $async {$ip $port}} s]
    if {$conStat} {
	
	# something went wrong while trying to establish the connection
	# Clean up after events and such, but DON'T call the command callback
	# (if available) because we're going to throw an exception from here
	# instead.
	Debug 4 "getfile::getfromserver {eval $defCmd $async {$ip $port}}"
	Finish $token "" 1
	cleanup $token 
	return -code error $s
    }
    set state(sock) $s
    set state(status) connect
    if {[info exists state(-command)]} {
	if {[catch {eval $state(-command) {$token ok contacting $ip}} err]} {
	    set state(error) [list $err $errorInfo $errorCode]
	    set state(status) error
	}
    }

    # Wait for the connection to complete    
    if {$state(-timeout) > 0} {
	fileevent $s writable [list [namespace current]::Connect $token]
    } else {
	Connect $token
    }
    return $token
}

# getfile::Connect --
#
#	Callback when socket opens.
#
# Arguments:
#	token	The token returned from getfile::get
#
# Results:
#	negotiates remote peer.

proc getfile::Connect {token} {
    global errorInfo errorCode
    
    variable $token
    upvar 0 $token state
    
    Debug 2 "getfile::Connect"
    set s $state(sock)
    set state(status) ""
    
    # Be sure to switch off any fileevents from previous procedures async open.
    fileevent $s writable {}
    if {[catch {eof $s} iseof] || $iseof} {
	Finish $token eoferr
	cleanup $token
	return
    }
    
    # Set in nonblocking mode.
    fconfigure $s -blocking 0
    
    # Send data in cr-lf format, but accept any line terminators
    fconfigure $s -buffering line -translation {auto crlf}
    
    # This is the actual instruction to the remote server what to expect
    # Be sure to concat the 'optList'.
    
    if {[catch {
	puts  $s "GET: $state(path) $state(-optlist)"
	flush $s    
    } err]} {	
	Debug 4 "getfile::Connect $err"
	Finish $token connerr
	cleanup $token
	return
    }
    if {[info exists state(-command)]} {
	if {[catch {eval $state(-command) {$token ok negotiate}} err]} {
	    set state(error) [list $err $errorInfo $errorCode]
	    set state(status) error
	}
    }
    
    # Set up event handler to wait for server response.    
    fileevent $s readable [list [namespace current]::Response $token]
}

# getfile::Response --
#
#       Read the first line of the servers response and prepare to get the next
#       one if this was OK. The protocol is typically:
#           TCLWB/1.0 200 OK
#           key1: value1 key2: value2 ...
#           and the data comes here...
#
# Arguments:
#	token	The token returned from getfile::*
#
# Results:
#       None.

proc getfile::Response {token} {    
    variable codeToText
    variable $token
    upvar 0 $token state
    
    set int_ {[0-9]+}
    set any_ {.+}
    
    set s $state(sock)
    
    # Be sure to switch off any fileevent.
    fileevent $s readable {}
    fileevent $s writable {}
    
    Debug 2  "getfile::Response"
    
    if {[catch {eof $s} iseof] || $iseof} {
	Finish $token eoferr
	cleanup $token
	return
    } elseif {[gets $s line] == -1} {
	
	# Get server response.
	Finish $token readerr
	cleanup $token
	return
    }
    Debug 2  "    line='$line'"

    # Catch problems.
    
    if {![regexp "^TCLWB/(${int_}\.${int_}) +($int_) +($any_)" $line match  \
      version ncode msg]} {
	Finish $token unknownprot
	cleanup $token
	return
    } 
    set state(ncode) $ncode
    if {![string equal $ncode "200"]} {
	set codemsg ""
	if {[info exists codeToText($ncode)]} {
	    set codemsg $codeToText($ncode)
	}
	Finish $token $ncode
	cleanup $token
	return
    } 
    
    # Set up event handler to wait for servers next line.
    fileevent $s readable [list [namespace current]::ReadOptLine $token]
}

# getfile::ReadOptLine --
#
#       Read the second line of the servers response and prepare to get the next
#       one if this was OK. The protocol is typically:
#           TCLWB/1.0 200 OK
#           key1: value1 key2: value2 ...
#           and the data comes here...
#
# Arguments:
#	token	The token returned from getfile::*
#                 
# Results:
#	initiates file copy to remote peer.

proc getfile::ReadOptLine {token} {
    variable $token
    upvar 0 $token state
    
    set s $state(sock)
    
    # Be sure to switch off any fileevent.
    fileevent $s readable {}
    fileevent $s writable {}
    
    Debug 2  "getfile::ReadOptLine"
    
    if {[catch {eof $s} iseof] || $iseof} {
	Finish $token eoferr
	cleanup $token
	return
    } elseif {[gets $s line] == -1} {
	
	# Get server response.
	Finish $token readerr
	cleanup $token
	return
    }
    Debug 2  "    line='$line'"
    
    set state(state) body
    
    # Do the actual transfer. fcopy registers 'PutFileCallback'.
    # In order for the server to read a complete line, binary mode
    # must wait until the line oriented part is completed.
    # Use the MIME type to hint transfer mode for *socket write*.
    
    if {[string match -nocase text/* $state(-mimetype)]} {
	fconfigure $s -translation auto
	
	# For nonlatin characters to work be sure to use Unicode/UTF-8.
	catch {fconfigure $s -encoding utf-8}
    } else {
	fconfigure $s -translation {binary binary}
    }
    fconfigure $s -buffering full
    if {[info exists state(-command)]} {
	if {[catch {eval $state(-command) {$token ok starts}} err]} {
	    set state(error) [list $err $errorInfo $errorCode]
	    set state(status) error
	}
    }
    
    # Initiate a sequence of background fcopies
    CopyStart $s $state(fd) $token 
}

# getfile::CopyStart
#
#	Error handling wrapper around fcopy
#
# Arguments
#	s	The socket to copy from
#       fd      The file descriptor.
#	token	The token returned from getfile::get
#
# Side Effects
#	This closes the connection upon error

proc getfile::CopyStart {s fd token} {
    
    variable $token
    upvar 0 $token state
    
    Debug 4 "getfile::CopyStart"
    if {[catch {
	fcopy $s $fd -size $state(-blocksize) -command \
	  [list [namespace current]::CopyDone $token]
    } err]} {
	Finish $token $err
    }
}

# getfile::CopyDone
#
#	fcopy completion callback
#
# Arguments
#	token	The token returned from getfile::get
#	count	The amount transfered
#
# Side Effects
#	Invokes callbacks

proc getfile::CopyDone {token count {error {}}} {
    global errorInfo errorCode
    variable $token
    upvar 0 $token state
    
    Debug 4 "getfile::CopyDone count=$count, error=$error"
    set s $state(sock)
    set fd $state(fd)
    if {[string length $error] == 0} {
	incr state(currentsize) $count
	if {[info exists state(-progress)]} {
	    eval $state(-progress) {$token $state(totalsize) $state(currentsize)}
	}
    }
    
    # At this point the token may have been reset
    if {[string length $error]} {
	Finish $token $error
    } elseif {[catch {eof $s} iseof] || $iseof} {
	
	# It is the put side that takes action to close socket, and we are
	# likely to receive it here.
	# When transporting text files between different platforms
	# line ending translations screw up the total size which may change.
	if {0 && $state(totalsize) > $state(currentsize)} {
	    Finish $token ended
	} else {
	    Finish $token "" 1
	    set state(status) ok
	    if {[info exists state(-command)]} {
		if {[catch {eval $state(-command) {$token ok finished}} err]} {
		    set state(error) [list $err $errorInfo $errorCode]
		    set state(status) error
		}
	    }
	}
    } else {
	CopyStart $s $fd $token
    }
}

proc getfile::status {token} {
    variable $token
    upvar 0 $token state
    return $state(status)
}

proc getfile::ncode {token} {
    variable $token
    upvar 0 $token state
    if {[regexp {[0-9]{3}} $state(ncode) numeric_code]} {
	return $numeric_code
    } else {
	return $state(ncode)
    }
}

proc getfile::ncodetotext {ncode} {
    variable codeToText
    if {[regexp {[0-9]{3}} $ncode]} {
	if {[info exists codeToText($ncode)]} {
	    return $codeToText($ncode)
	} else {
	    return -code error "Unrecognized numeric code: $ncode"
	}
    } else {
	return -code error "Not a numeric code"
    }
}

proc getfile::size {token} {
    variable $token
    upvar 0 $token state
    return $state(currentsize)
}

proc getfile::error {token} {
    variable $token
    upvar 0 $token state
    if {[info exists state(error)]} {
	return $state(error)
    }
    return ""
}

# getfile::VerifyOptions
#
#	Check if valid options.
#
# Arguments
#	token	    The token returned from getfile::get etc.
#	validopts   A list of the valid options.
#	args        The argument list given on the call.
#
# Side Effects
#	Sets error

proc getfile::VerifyOptions {token validopts args} {
    
    variable $token
    upvar 0 $token state
    
    regsub -all -- - $validopts {} theopts
    set pat ^-([join $theopts |])$
    foreach {flag value} $args {
	if {[regexp $pat $flag]} {
	    
	    # Validate numbers
	    if {[info exists state($flag)] && \
	      [string is integer -strict $state($flag)] && \
	      ![string is integer -strict $value]} {
		unset $token
		return -code error "Bad value for $flag ($value), must be integer"
	    }
	    set state($flag) $value
	} else {
	    set usage [join $validopts ", "]
	    unset $token
	    return -code error "Unknown option $flag, can be: $usage"
	}
    }
}

# getfile::Finish --
#
#	Clean up the socket and eval close time callbacks
#
# Arguments:
#	token	    Connection token.
#	errormsg    (optional) If set, forces status to error.
#       skipCB      (optional) If set, don't call the -command callback.  This
#                   is useful when geturl wants to throw an exception instead
#                   of calling the callback.  That way, the same error isn't
#                   reported to two places.
#
# Side Effects:
#        Closes the socket and file.

proc getfile::Finish {token {errormsg ""} {skipCB 0}} {
    global errorInfo errorCode
    
    variable $token
    upvar 0 $token state
    
    set what ok
    if {[string length $errormsg] != 0} {
	set state(error) [list $errormsg $errorInfo $errorCode]
	set state(status) error
	set what error
    }
    catch {close $state(fd)}
    catch {close $state(sock)}
    if {[info exists state(after)]} {
	catch {after cancel $state(after)}
    }
    
    Debug 2 "getfile::Finish skipCB=$skipCB, errormsg=$errormsg"

    if {[info exists state(-command)] && !$skipCB} {
	if {[catch {eval $state(-command) {$token $what $errormsg}} err]} {
	    if {[string length $errormsg] == 0} {
		set state(error) [list $err $errorInfo $errorCode]
		set state(status) error
	    }
	}
	if {[info exist state(-command)]} {
	    # Command callback may already have unset our state
	    unset state(-command)
	}
    }
}

# getfile::reset --
#
#	Sets the state corresponding to the 'token' into its ground state;
#	closes sockets etc.
#
# Arguments:
#	token	Connection token.
#	why	Status info.
#
# Side Effects:
#       See Finish

proc getfile::reset {token {why reset}} {
    
    variable $token
    upvar 0 $token state
    set state(status) $why
    catch {fileevent $state(sock) readable {}}
    catch {fileevent $state(sock) writable {}}
    Finish $token
    if {[info exists state(error)]} {
	set errorlist $state(error)
	unset state
	#eval ::error $errorlist
    }
}

# getfile::cleanup
#
#	Garbage collect the state associated with a transaction
#
# Arguments
#	token	The token returned from getfile::get
#
# Side Effects
#	unsets the state array

proc getfile::cleanup {token} {
    
    variable $token
    upvar 0 $token state
    if {[info exist state]} {
	unset state
    }
}

proc getfile::Debug {num str} {
    variable debug
    
    if {$num <= $debug} {
	puts $str
    }
}

#---------------------------------------------------------------------------
