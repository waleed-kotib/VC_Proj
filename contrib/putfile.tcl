# putfile.tcl --
#
#	Client-side put file to remote peer for whiteboard.
#
#  Copyright (c) 2002-2003  Mats Bengtsson
#
# $Id: putfile.tcl,v 1.5 2004-03-15 11:19:46 matben Exp $
# 
# USAGE ########################################################################
#
# putfile::put fileName ip port ?-key value ...?
# 
#       fileName: this must be the full path to the local file. It must not be
#                 uri encoded.
#    	-blocksize size 
#	-command procname
#	-filetail file		with the correct file extension if mac, not uri
#	                        encoded, used in 'PUT: ...'
#	-optlist list
#	-progress procname
#	-timeout millisecs
#	-mimetype mime
#
# putfile::puttoclient sock fileName ?-key value ...?
#    	-blocksize size 
#	-command procname
#	-filetail file
#	-optlist list
#	-progress procname
#	-mimetype mime
#
# putfile::status token
# putfile::ncode token
# putfile::ncodetotext ncode
# putfile::size token
# putfile::error token
# putfile::cleanup token
# putfile::reset token
#
# Callback interface:
#	-command:	PutCommand {token what msg}
#			what is "ok" or "error"
#			It is called at certain events to provide the client
#			with a status code that can be translated via msgcat.
#	-progress:	PutProgress {token total current}
#			total is file size in bytes, and current is bytes so far

package require Tcl 8.3
package require uriencode
package provide putfile 1.0

namespace eval putfile {
    variable put

    variable debug 0
    set put(uid) 0
    set put(opts) {-blocksize -command -filetail -optlist -progress -timeout  \
      -mimetype}
    set put(toClientOpts) {-blocksize -command -filetail -mimetype -optlist  \
      -progress}
    
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

# putfile::put --
#
#	Establishes a connection to a remote peer and initiates a put file 
#	process. Enclose this call in a 'catch'.
#
# Arguments:
#       fileName	The complete file path on local disk to put.
#       ip              IP number or address name to remote peer.
#	port            peer's port number.
#       args		Option value pairs. Valid options include:
#				-blocksize, -mimetype, -progress, -timeout, 
#				-optlist, -filetail
# Results:
#	Returns a token for this connection.
#	This token is the name of an array that the caller should
#	unset to garbage collect the state.

proc putfile::put {fileName ip port args} {
    global errorInfo errorCode    
    variable put
    variable urlTypes
    
    # Initialize the state variable, an array.  We'll return the
    # name of this array as the token for the transaction.
    set token [namespace current]::put[incr put(uid)]
    variable $token
    upvar 0 $token state
    reset $token
    
    # Process command options.    
    array set state {
	-blocksize 	8192
	-timeout 	0
	-mimetype       application/octet-stream 
	-optlist        {}
	state		header
	currentsize	0
	totalsize	0
	status 	        ""
	ncode           ""
    }
    if {[catch {
	eval {putfile::VerifyOptions $token $put(opts)} $args
    } msg]} {
	return -code error $msg
    }
    
    # Open the file.
    if {[catch {open $fileName r} fd]} {
	
	# Handle error.
	Finish $token "" 1
	cleanup $token
	return -code error $fd
    }
    set state(-filetail) [file tail $fileName]
    set state(file)      $fileName
    set state(fd)        $fd
    set state(ip)        $ip
    set state(totalsize) [file size $fileName]
    
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
	Finish $token "" 1
	cleanup $token 
	return -code error $s
    }
    set state(sock) $s
    set state(status) connect
    if {[info exists state(-command)]} {
	if {[catch {eval $state(-command) {$token ok contacting}} err]} {
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

# putfile::Connect --
#
#	Callback when socket opens.
#
# Arguments:
#	token	The token returned from putfile::put
#
# Results:
#	negotiates remote peer.

proc putfile::Connect {token} {
    global errorInfo errorCode
    
    variable $token
    upvar 0 $token state
    
    Debug 2 "putfile::Connect"
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
    
    # Manufacture the optList.
    array set optArr [list "size:" $state(totalsize)  \
      "Content-Type:" $state(-mimetype)]
    
    # Overwrite our settings with any given in command line.
    array set optArr $state(-optlist)
    set optList [array get optArr]
    
    # Need to encode the file tail to name that is network transparent:
    # URI encode. 
    set dstFile [uriencode::quotepath $state(-filetail)]
    
    # This is the actual instruction to the remote server what to expect
    # Be sure to concat the 'optList'.
    
    if {[catch {
	puts  $s "PUT: $dstFile $optList"
	flush $s    
    } err]} {	
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

# putfile::Response --
#
#	Callback for reading server's response.
#
# Arguments:
#	token	The token returned from putfile::put
#
# Results:
#	initiates file copy to remote peer.

proc putfile::Response {token} {    
    global errorInfo errorCode    
    variable codeToText
    variable $token
    upvar 0 $token state
    
    set int_ {[0-9]+}
    set any_ {.+}
    
    set s $state(sock)
    
    # Be sure to switch off any fileevent.
    fileevent $s readable {}
    fileevent $s writable {}
    Debug 2  "putfile::Response"
    
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
    if {[info exists state(-command)]} {
	if {[catch {eval $state(-command) {$token ok starts}} err]} {
	    set state(error) [list $err $errorInfo $errorCode]
	    set state(status) error
	}
    }
    
    # Initiate a sequence of background fcopies
    CopyStart $state(fd) $s $token 
}

# putfile::CopyStart
#
#	Error handling wrapper around fcopy
#
# Arguments
#     fd    The file descriptor.
#	s	The socket to copy from
#	token	The token returned from putfile::put
#
# Side Effects
#	This closes the connection upon error

proc putfile::CopyStart {fd s token} {
    
    variable $token
    upvar 0 $token state
    if {[catch {
	fcopy $fd $s -size $state(-blocksize) -command \
	  [list [namespace current]::CopyDone $token]
    } err]} {
	Finish $token $err
    }
}

# putfile::CopyDone
#
#	fcopy completion callback
#
# Arguments
#	token	The token returned from putfile::put
#	count	The amount transfered
#
# Side Effects
#	Invokes callbacks

proc putfile::CopyDone {token count {error {}}} {
    global errorInfo errorCode    
    
    variable $token
    upvar 0 $token state
    set  s  $state(sock)
    set  fd $state(fd)
    incr state(currentsize) $count
    if {[info exists state(-progress)]} {
	eval $state(-progress) {$token $state(totalsize) $state(currentsize)}
    }
    # At this point the token may have been reset
    if {[string length $error]} {
	Finish $token $error
    } elseif {[catch {eof $s} iseof] || $iseof} {
	set msg ""
	if {$state(totalsize) > $state(currentsize)} {
	    set msg ended
	}
	Eof $token
	Finish $token $msg
    } elseif {[eof $fd]} {
	Finish $token "" 1
	set state(status) ok
	if {[info exists state(-command)]} {
	    if {[catch {eval $state(-command) {$token ok finished}} err]} {
		set state(error) [list $err $errorInfo $errorCode]
		set state(status) error
	    }
	}
    } else {
	CopyStart $fd $s $token
    }
}

# putfile::Eof
#
#	Handle eof on the socket
#
# Arguments
#	token	The token returned from putfile::put
#
# Side Effects
#	Clean up the socket

proc putfile::Eof {token} {
    
    variable $token
    upvar 0 $token state
    if {[string equal $state(state) "header"]} {
	# Premature eof
	set state(status) eof
    } else {
	set state(status) ok
    }
    set state(state) eof
}

# putfile::puttoclient --
#
#	Initiates a put file process to a client on an already open channel.
#	Enclose this call in a 'catch', since it may throw errors.
#
# Arguments:
#	sock            Open socket.
#       fileName	The complete file path on local disk to put.
#       args		Option value pairs. Valid options include:
#			-blocksize, -command, -mimetype, -progress, -optlist
# Results:
#	Returns a token for this connection.
#	This token is the name of an array that the caller should
#	unset to garbage collect the state.

proc putfile::puttoclient {sock fileName args} {
    
    variable put
    variable codeToText
    Debug 2  "putfile::puttoclient fileName=$fileName, args='$args'"
    
    # Be sure to switch off any fileevent before fcopy.
    fileevent $sock readable {}
    fileevent $sock writable {}
    
    # Initialize the state variable, an array.  We'll return the
    # name of this array as the token for the transaction.
    
    set token [namespace current]::put[incr put(uid)]
    variable $token
    upvar 0 $token state
    reset $token
    
    # Process command options.
    
    array set state {
	-blocksize 	8192
	-mimetype       application/octet-stream 
	-optlist        {}
	state		header
	currentsize	0
	totalsize	0
	status 	        ""
	ncode           ""
    }
    set state(-filetail) [file tail $fileName]
    if {[catch {
	eval {putfile::VerifyOptions $token $put(toClientOpts)} $args
    } msg]} {
	return -code error $msg
    }
    
    if {![file isfile $fileName]} {
	puts $sock "TCLWB/1.0 404 $codeToText(404)"
	close $sock
	Finish $token "" 1
	cleanup $token
	return -code error $codeToText(404)
    }	
    
    # Open the file.
    if {[catch {open $fileName r} fd]} {
	puts $sock "TCLWB/1.0 500 $codeToText(500)"
	close $sock
	
	# Handle error.
	Finish $token "" 1
	cleanup $token
	return -code error $codeToText(500)
    }    
    set state(file) $fileName
    set state(fd) $fd
    set state(sock) $sock
    set state(ip) [lindex [fconfigure $sock -peername] 1]
    set state(totalsize) [file size $fileName]
    
    # Manufacture the optList.
    array set optArr [list "size:" $state(totalsize) \
      "Content-Type:" $state(-mimetype)]
    
    # Overwrite our settings with any given in command line.
    array set optArr [array get state(-optlist)]
    set optList [array get optArr]
        
    # If we have come so far it's ok.
    if {[catch {
	puts $sock "TCLWB/1.0 200 $codeToText(200)"
	puts $sock $optList
	flush $sock
    } err]} {	
	Finish $token "" 1
	cleanup $token
	return -code error neterr
    }
    
    # Use the MIME type to hint transfer mode for *file read*.
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
    CopyStart $fd $sock $token 
    
    return $token
}

proc putfile::status {token} {
    variable $token
    upvar 0 $token state
    return $state(status)
}

proc putfile::ncode {token} {
    variable $token
    upvar 0 $token state
    if {[regexp {[0-9]{3}} $state(ncode) numeric_code]} {
	return $numeric_code
    } else {
	return $state(ncode)
    }
}

proc putfile::ncodetotext {ncode} {
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

proc putfile::size {token} {
    variable $token
    upvar 0 $token state
    return $state(currentsize)
}

proc putfile::error {token} {
    variable $token
    upvar 0 $token state
    if {[info exists state(error)]} {
	return $state(error)
    }
    return ""
}

# putfile::VerifyOptions
#
#	Check if valid options.
#
# Arguments
#	token	    The token returned from putfile::put etc.
#	validopts   A list of the valid options.
#	args        The argument list given on the call.
#
# Side Effects
#	Sets error

proc putfile::VerifyOptions {token validopts args} {
    
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

# putfile::Finish --
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

proc putfile::Finish {token {errormsg ""} {skipCB 0}} {
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
    catch {after cancel $state(after)}
    
    Debug 2 "putfile::Finish skipCB=$skipCB, errormsg=$errormsg"

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

# putfile::reset --
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

proc putfile::reset {token {why reset}} {
    
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

# putfile::register --
#
#     See documentaion for details.
#
# Arguments:
#     proto           URL protocol prefix, e.g. https
#     port            Default port for protocol
#     command         Command to use to create socket
# Results:
#     list of port and command that was registered.

proc putfile::register {proto port command} {
    variable urlTypes
    set urlTypes($proto) [list $port $command]
}

# putfile::unregister --
#
#     Unregisters URL protocol handler
#
# Arguments:
#     proto           URL protocol prefix, e.g. https
# Results:
#     list of port and command that was unregistered.

proc putfile::unregister {proto} {
    variable urlTypes
    if {![info exists urlTypes($proto)]} {
	return -code error "unsupported url type \"$proto\""
    }
    set old $urlTypes($proto)
    unset urlTypes($proto)
    return $old
}

# putfile::cleanup
#
#	Garbage collect the state associated with a transaction
#
# Arguments
#	token	The token returned from putfile::put
#
# Side Effects
#	unsets the state array

proc putfile::cleanup {token} {
    
    variable $token
    upvar 0 $token state
    if {[info exist state]} {
	unset state
    }
}

proc putfile::Debug {num str} {
    variable debug
    if {$num <= $debug} {
	puts $str
    }
}


#---------------------------------------------------------------------------
