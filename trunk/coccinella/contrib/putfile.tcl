# putfile.tcl --
#
#	Client-side put file to remote peer for whiteboard.
#
#  Copyright (c) 2002  Mats Bengtsson
#
# $Id: putfile.tcl,v 1.3 2003-02-24 17:52:04 matben Exp $
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
#
# Callback interface:
#	-command:	PutCommand {token what msg}
#			what is "ok" or "error"
#	-progress:	PutProgress {token total current}
#			total is file size in bytes, and current is bytes so far

package require Tcl 8.3
package require uriencode
package provide putfile 1.0

namespace eval putfile {
    variable put

    variable debug 0
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

    namespace export put
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
    
    variable $token
    upvar 0 $token state
    variable debug 
    global errorInfo errorCode
    set what ok
    if {[string length $errormsg] != 0} {
	set state(error) [list $errormsg $errorInfo $errorCode]
	set state(status) error
	set what error
    }
    catch {close $state(fd)}
    catch {close $state(sock)}
    catch {after cancel $state(after)}
    if {$debug} {
	puts "putfile::Finish skipCB=$skipCB, errormsg=$errormsg"
    }
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
#	See documentaion for details.
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
    variable debug 
    set state(status) $why
    catch {fileevent $state(sock) readable {}}
    catch {fileevent $state(sock) writable {}}
    Finish $token
    if {[info exists state(error)]} {
	set errorlist $state(error)
	unset state
	eval error $errorlist
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
#	  port            peer's port number.
#       args		Option value pairs. Valid options include:
#				-blocksize, -mimetype, -progress, -timeout, 
#				-optlist, -filetail
# Results:
#	Returns a token for this connection.
#	This token is the name of an array that the caller should
#	unset to garbage collect the state.

proc putfile::put {fileName ip port args} {
    
    variable put
    variable debug 
    global errorInfo errorCode
    
    # Initialize the state variable, an array.  We'll return the
    # name of this array as the token for the transaction.
    
    if {![info exists put(uid)]} {
	set put(uid) 0
    }
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
    set options {-blocksize -command -filetail -optlist \
      -progress -timeout -mimetype}
    set state(-filetail) [file tail $fileName]
    if {[catch {eval {putfile::VerifyOptions $token $options} $args} msg]} {
	return -code error $msg
    }
    
    # Open the file.
    if {[catch {open $fileName r} fd]} {
	
	# Handle error.
	Finish $token "" 1
	cleanup $token
	return -code error $fd
    }
    set state(file) $fileName
    set state(fd) $fd
    set state(ip) $ip
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
    set defCmd socket
    
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
	set msg "Contacting $ip. Waiting for response..."
	if {[catch {eval $state(-command) {$token ok $msg}} err]} {
	    set state(error) [list $err $errorInfo $errorCode]
	    set state(status) error
	}
    }
    
    # Wait for the connection to complete
    
    if {$state(-timeout) > 0} {
	fileevent $s writable [list putfile::Connect $token]
    } else {
	putfile::Connect $token
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
    
    variable $token
    upvar 0 $token state
    variable debug 
    global errorInfo errorCode
    
    if {$debug} {
	puts "putfile::Connect"
    }
    set s $state(sock)
    set state(status) ""
    
    # Be sure to switch off any fileevents from previous procedures async open.
    fileevent $s writable {}
    if {[eof $s]} {
	Finish $token "Connection to $state(ip) failed. Received an eof."
	cleanup $token
	return
    }
    
    # Set in nonblocking mode.
    fconfigure $s -blocking 0
    
    # Send data in cr-lf format, but accept any line terminators
    fconfigure $s -buffering line -translation {auto crlf}
    
    # Manufacture the optList.
    catch {unset optArr}
    set fileSize [file size $state(file)]
    set optArr(size:) $state(totalsize)
    set optArr(Content-Type:) $state(-mimetype)
    
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
	Finish $token "Connection to $state(ip) failed."
	cleanup $token
	return
    }
    if {[info exists state(-command)]} {
	set msg "Client contacted: $state(ip); negotiating..."
	if {[catch {eval $state(-command) {$token ok $msg}} err]} {
	    set state(error) [list $err $errorInfo $errorCode]
	    set state(status) error
	}
    }
    
    # Set up event handler to wait for server response.
    
    fileevent $s readable [list [namespace current]::Response $token]
}

# putfile::Response --
#
#	Callback when socket opens.
#
# Arguments:
#	token	The token returned from putfile::put
#
# Results:
#	initiates file copy to remote peer.

proc putfile::Response {token} {
    
    variable $token
    upvar 0 $token state
    variable debug 
    
    set int_ {[0-9]+}
    set any_ {.+}
    
    set s $state(sock)
    
    # Be sure to switch off any fileevent.
    fileevent $s readable {}
    fileevent $s writable {}
    if {$debug} {
	puts "putfile::Response"
    }
    if {[eof $s]} {
	Finish $token "Connection to $state(ip) failed. Received an eof."
	cleanup $token
	return
    } elseif {[gets $s line] == -1} {
	
	# Get server response.
	Finish $token "Error reading server response from $state(ip)."
	cleanup $token
	return
    }
    if {$debug} {
	puts "    line='$line'"
    }
    
    # Catch problems.
    
    if {![regexp "^TCLWB/(${int_}\.${int_}) +($int_) +($any_)" $line match  \
      version ncode msg]} {
	Finish $token "The server at $state(ip) didn't respond with a\
	  well formed protocol"
	cleanup $token
	return
    } 
    set state(ncode) $ncode
    if {![string equal $ncode "200"]} {
	Finish $token "The server at $state(ip) responded with a code: $ncode."
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
	set msg "Client at $state(ip) accepted file $state(-filetail).\
	  Starts transfer..."
	if {[catch {eval $state(-command) {$token ok $msg}} err]} {
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
	  [list putfile::CopyDone $token]
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
    
    variable $token
    upvar 0 $token state
    variable debug 
    set s $state(sock)
    set fd $state(fd)
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
	    set msg "Transfer to $state(ip) ended prematurely"
	}
	Eof $token
	Finish $token $msg
    } elseif {[eof $fd]} {
	Finish $token "" 1
	set state(status) ok
	if {[info exists state(-command)]} {
	    set msg "Finished putting file $state(-filetail) to $state(ip)"
	    if {[catch {eval $state(-command) {$token ok $msg}} err]} {
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
#	Initiates a put file process to a client on add already open channel.
#	Enclose this call in a 'catch'.
#
# Arguments:
#	  sock
#       fileName		The complete file path on local disk to put.
#       args		Option value pairs. Valid options include:
#				-blocksize, -mimetype, -progress, -optlist
# Results:
#	Returns a token for this connection.
#	This token is the name of an array that the caller should
#	unset to garbage collect the state.

proc putfile::puttoclient {sock fileName args} {
    
    variable put
    variable debug 
    variable codeToText
    if {$debug} {
	puts "putfile::puttoclient fileName=$fileName, args='$args'"
    }
    
    # Initialize the state variable, an array.  We'll return the
    # name of this array as the token for the transaction.
    
    if {![info exists put(uid)]} {
	set put(uid) 0
    }
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
    set options {-blocksize -command -filetail -mimetype -optlist -progress}
    set state(-filetail) [file tail $fileName]
    if {[catch {eval {putfile::VerifyOptions $token $options} $args} msg]} {
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
    
    # If we have come so far it's ok.
    puts $sock "TCLWB/1.0 200 $codeToText(200)"
    flush $sock
    
    set state(file) $fileName
    set state(fd) $fd
    set state(sock) $sock
    set state(ip) [lindex [fconfigure $sock -peername] 1]
    set state(totalsize) [file size $fileName]
    
    # Manufacture the optList.
    catch {unset optArr}
    set optArr(size:) $state(totalsize)
    set optArr(Content-Type:) $state(-mimetype)
    
    # Overwrite our settings with any given in command line.
    array set optArr [array get state(-optlist)]
    set optList [array get optArr]
    
    puts $sock $optList
    flush $sock
    
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
    
    # Be sure to switch off any fileevent before fcopy.
    fileevent $sock readable {}
    fileevent $sock writable {}
    
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
#	token	The token returned from httpex::get etc.
#	validopts a list of the valid options.
#	args    The argument list given on the call.
#
# Side Effects
#	Sets error

proc putfile::VerifyOptions {token validopts args} {
    
    variable $token
    upvar 0 $token state
    
    set usage [join $validopts ", "]
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
	    unset $token
	    return -code error "Unknown option $flag, can be: $usage"
	}
    }
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

#---------------------------------------------------------------------------
