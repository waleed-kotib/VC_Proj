#  httpex.tcl ---
#  
#      It contains a number
#      of procedures for using the HTTP protocol, get and put, both client
#      side and server side.
#      Modelled after the http package with modifications.
#      
#  Copyright (c) 2002-2005  Mats Bengtsson only for the new and rewritten parts.
#  This source file is distributed under the BSD license.
#
# $Id: httpex.tcl,v 1.19 2005-01-31 14:06:53 matben Exp $
# 
# USAGE ########################################################################
#
# httpex::config ?-key value ...?
#       -accept mime 
#       -basedirectory path
#       -proxyhost url 
#       -proxyport port 
#       -proxyfilter proc
#       -server text
#       -useragent string
#
# httpex::get url ?-channel channame -key value ...?
#       Gets a remote url. The channame specifies a file descriptor where to store
#       the data. The keys may be any of the following:
# 
#       -blocksize size 
#	-channel name
#       -command callback
#	-handler callback
#       -headers {key value ?key value ...?} 
#       -httpvers 1.0|1.1
#       -persistent boolean     If socket shall be kept open when finished
#       -progress callback
#       -socket name		If wants to reuse socket in a persistent connection
#       -timeout millisecs	If >0 connects async
#       -type mime
#
#       The '-command' argument is a tcl procedure:  mycallback {token}
#       where 'token' is the name of the state array returned from 
#       httpex::get. It gets called when the state changes in some way.
#       
#       The 'status' is one of: ok, reset, eof, timeout, or error, and describes
#       the final stage. Empty before that.
#       The 'state' describes where in the process we are, and is normally: 
#
#          connect -> putheader -> waiting -> getheader -> body -> final
#       
#       The '-progress' argument is a tcl procedure: 
#       progressProc {token totalsize currentsize}
#       'totalsize' can be 0 if no Content-Length attribute.
#
# httpex::head url ?-key value ...?
#       Makes a HEAD request to url. The -channel key is not allowed.
#
# httpex::post url ?-key value ...?
#       Makes a POST request to url.
#
#	  -query data
#	  -querychannel name
#       
# httpex::put url ?-key value ...?
#       Puts local data to server. The channame is typically a file descriptor
#       where data shall be read if no -putdata option.
#       The -type key is required.
#       The keys may be any of the httpex::get keys, or:
#       
#       -putdata bytes
#       -putchannel name
#       -putprogress callback
#       
# httpex::readrequest socket callback ?-key value ...?
#       Callback when a new socket connected and became readable.
#       The 'callback' proc must have the form: 'myservcb {token}', and must 
#       return a list: {code headerlist}, where code is the HTTP return code, 
#       and headerlist a list of key value pairs to send.
#       If the method is PUT or GET, you MUST provide an open channel by
#       invoking httpex::setchannel, or do httpex::setdata, before returning.
#       
#       The state sequence is normally: 
#       
#          getheader -> putheader -> body -> final
#
# httpex::register protocol port socketcmd
#       Registers new transport layer.
#
#       protocol        URL protocol prefix, e.g. https
#       port            Default port for protocol
#       socketcmd       Command to use to create socket
#
# VARIABLES --------------------------------------------------------------------
# 
#	Clients only:
#
# locals($socket,$count,token) token
#       Since we support async requests on the same socket, but using unique
#       tokens, we need to keep track of when to set up readable events for
#       the responses/requests.
#
# locals($socket,count) integer
#       Is a counter that is incremented each time a new request is made
#       on this particular socket.
#
# locals($socket,nread) integer
#	  The number of server responses received and handled.
#
# Given a token, you may get its socket from httpex::socket, from the socket,
# you may get all other tokens associated with this socket...
#
#
# TODO --------------------------------------------------------------------------
#
# o  Support for Transfer-Encoding: chunked
# o  Support for Content-Range:

package provide httpex 0.2

namespace eval httpex {
    
    variable opts
    variable locals
    variable debug 0
    variable codeToText
    
    # Only for the config command.
    array set opts {
	-accept        */*
	-proxyhost     {}
	-proxyport     {}
	-proxyfilter   httpex::ProxyRequired
    }
    set opts(-basedirectory)     [pwd]
    set opts(-server)            "Tcl/Tk/[info patchlevel] httpex/0.2"
    set opts(-useragent)         "Tcl/Tk/[info patchlevel] httpex/0.2"
    
    set locals(uid) 0

    variable formMap
    variable alphanumeric a-zA-Z0-9
    variable c
    variable i 0
    for {} {$i <= 256} {incr i} {
	set c [format %c $i]
	if {![string match \[$alphanumeric\] $c]} {
	    set formMap($c) %[format %.2x $i]
	}
    }
    # These are handled specially
    array set formMap {
	" " +   \n %0d%0a
    }
   
    variable urlTypes
    array set urlTypes {
	http	{80 ::socket}
    }

    variable encodings [string tolower [encoding names]]
    # This can be changed, but iso8859-1 is the RFC standard.
    variable defaultCharset "iso8859-1"
    
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

    # Use in variables to store typical html return messages instead of files.
    variable htmlErrMsg
    set htmlErrMsg(404) {\
	<HTML><HEAD>
	<TITLE>File Not Found</TITLE>
	</HEAD><BODY BGCOLOR="#FFA6FF" TEXT=black>
	<FONT SIZE="5" COLOR="#CC0033" FACE="Arial,Helvetica,Verdana,sans-serif">
	<B> Error 404: The file was not found on the server. </B></FONT><P>
	<FONT SIZE="2" FACE="Arial,Helvetica,Verdana,sans-serif">
	But you can find shiny almost brand new cars at honest Mats
	used cars sales. 
	</FONT>
	</BODY></HTML>
    }

    # Client side options.
    set locals(opts,get) {-binary -blocksize -channel -command -headers \
      -httpvers -persistent -progress -socket -timeout -type}
    set locals(opts,head) {-binary -command -headers -httpvers -persistent \
      -socket -timeout -type}
    set locals(opts,post) {-binary -command -headers -httpvers -persistent \
	-query -querychannel -queryblocksize -queryprogress \
	-socket -timeout -type}
    set locals(opts,put) {-binary -blocksize -channel -command -headers \
      -httpvers -persistent -progress -putchannel -putdata -putprogress \
      -socket -timeout -type}

    # Server side options.
    set locals(opts,server) {-blocksize -channel -command -headers \
	-persistent -progress}

    namespace export get head post put config reset
}

# httpex::config --
#
#	See documentaion for details.
#
# Arguments:
#	args		Options parsed by the procedure.
# Results:
#        TODO

proc httpex::config {args} {
    variable opts
    
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
}

# httpex::get --
#
#	Initiates a GET HTTP request.
#
# Arguments:
#       url		The HTTP URL to goget.
#       args		Option value pairs. ?-key value ...?
# Results:
#	Returns a token for this request.

proc httpex::get {url args} {
    return [eval {Request get $url} $args]
}

# httpex::head --
#
#	Initiates a HEAD HTTP request.
#
# Arguments:
#       url		The HTTP URL to get head of.
#       args		Option value pairs. ?-key value ...?
# Results:
#	Returns a token for this request.

proc httpex::head {url args} {
    return [eval {Request head $url} $args]
}

# httpex::post --
#
#	Initiates a POST HTTP request.
#
# Arguments:
#       url		The HTTP URL to send post to.
#       args		Option value pairs. ?-key value ...?
# Results:
#	Returns a token for this request.

proc httpex::post {url args} {
    return [eval {Request post $url} $args]
}

# httpex::put --
#
#	Initiates a PUT HTTP request.
#
# Arguments:
#       url		The HTTP URL to put.
#       args		Option value pairs. ?-key value ...?
# Results:
#	Returns a token for this request.

proc httpex::put {url args} {
    return [eval {Request put $url} $args]
}

# httpex::Request --
#
#	Initiates a GET, HEAD, POST, or PUT HTTP request.
#	For clients only.
#
# Arguments:
#       method          "get", "head", "post", or "put".
#       url		The HTTP URL to goget.
#       args		Option value pairs. Valid options include:
#				-blocksize, -headers, -timeout
# Results:
#	Returns a token for this request.
#	This token is the name of an array that the caller should
#	unset to garbage collect the state.

proc httpex::Request {method url args} {    
    variable opts
    variable locals
    variable urlTypes
    variable defaultCharset
    variable debug
    
    Debug 1 "httpex::Request method=$method, url=$url, args='$args'"
    
    # Initialize the state variable, an array.  We'll return the
    # name of this array as the token for the transaction.
    
    set token [namespace current]::[incr locals(uid)]
    variable $token
    upvar 0 $token state
    
    # Process command options.
    # Note that totalsize can be 0 if missing Content-Length in header.
    # Switches, '-key' are set by the user while similar nonswitches are
    # obtained from the response.
    # Example: state(-httpvers) HTTP version to use
    #          state(httpvers) HTTP version in response
    
    array set state {
	-binary		false
	-blocksize 	8192
	-headers 	{}
	-httpvers       1.0
	-persistent     0
	-port           80
	-queryblocksize	8192
	-timeout 	0
	-type		application/x-www-form-urlencoded
	chunked         0
	coding		{}
	currentsize	0
	havecontentlength 0
	haveranges      0
	headclose       0
	http		""
	httpvers	1.0
	length	0
	meta		{}
	offset	0
	state		connect
	status		""
	totalsize	0
	type            text/html
    }
    set state(method) $method
    set state(charset) $defaultCharset
    
    if {[catch {eval {
	httpex::VerifyOptions $token $locals(opts,$method)
    } $args} msg]} {
	return -code error $msg
    }
    
    # Further error checking.
    if {[string equal $method "get"]} {
	
    } elseif {[string equal $method "head"]} {
	
    } elseif {[string equal $method "post"]} {
	if {[info exists state(-query)] && [info exists state(-querychannel)]} {
	    unset $token
	    return -code error {Not both -query and -querychannel may be used}
	}
	if {![info exists state(-query)] && ![info exists state(-querychannel)]} {
	    unset $token
	    return -code error {Any of -query or -querychannel must be used}
	}
    } elseif {[string equal $method "put"]} {
	if {[info exists state(-putchannel)] && [info exists state(-putdata)]} {
	    unset $token
	    return -code error {Can't combine -putdata and -putchannel options!}
	}
    }	
    
    # Validate URL, determine the server host and port, and check proxy case
    
    if {![regexp -nocase {^(([^:]*)://)?([^/:]+)(:([0-9]+))?(/.*)?$} $url \
      x prefix proto host y port filepath]} {
	unset $token
	return -code error "Unsupported URL: $url"
    }
    if {[string length $proto] == 0} {
	set proto http
	set url ${proto}://$url
    }
    if {![info exists urlTypes($proto)]} {
	unset $token
	return -code error "Unsupported URL type \"$proto\""
    }
    set defport [lindex $urlTypes($proto) 0]
    set defcmd [lindex $urlTypes($proto) 1]
    
    if {[string length $port] == 0} {
	set port $defport
    }
    if {[string length $proto] == 0} {
	set url http://$url
    }
    
    set state(host) $host
    set state(port) $port
    set state(srvurl) $filepath
    set state(filepath) $filepath
    set state(url) $url
    if {![catch {$opts(-proxyfilter) $host} proxy]} {
	set phost [lindex $proxy 0]
	set pport [lindex $proxy 1]
    }
    
    # We are trying to use a persistent connection here.
    if {[info exists state(-socket)]} {
	set s $state(-socket)
	
	# Verify that the host is the same if possible.
	if {[info exists locals($s,1,token)]} {
	    set oldtoken $locals($s,1,token)
	    if {[info exists $oldtoken]} {
		upvar 0 $oldtoken oldstate
		if {![string equal $state(host) $oldstate(host)]} {
		    set err "the hosts $state(host) $oldstate(host) nonidentical"
		    Finish $token $err 1
		    cleanup $token
		    return -code error $err
		}
	    }
	}
	
	# If there are no outstanding server responses to receive, continue
	# directly from here, else we must let us (Connect) be rescheduled from elsewhere.
	
	if {$locals($s,count) == $locals($s,nread)} {
	    set count [incr locals($s,count)]
	    set locals($s,$count,token) $token
	    Connect $token
	} else {
	    set count [incr locals($s,count)]
	    set locals($s,$count,token) $token
	}
    } else {
	
	# If a timeout is specified we set up the after event
	# and arrange for an asynchronous socket connection.
	
	if {$state(-timeout) > 0} {
	    set state(after) [after $state(-timeout) \
	      [list httpex::reset $token timeout]]
	}
	
	# If we are using the proxy, we must pass in the full URL that
	# includes the server name. state(srvurl) keeps track of this.
	
	if {[info exists phost] && [string length $phost]} {
	    set state(srvurl) $url
	    set conStat [catch {eval $defcmd -async {$phost $pport}} s]
	} else {
	    set conStat [catch {eval $defcmd -async {$host $port}} s]
	}
	if {$conStat} {
	    
	    # something went wrong while trying to establish the connection
	    # Clean up after events and such, but DON'T call the command callback
	    # (if available) because we're going to throw an exception from here
	    # instead.
	    set state(headclose) 1
	    catch {close $s}
	    catch {after cancel $state(after)}
	    cleanup $token
	    return -code error $s
	}
	set state(-socket) $s
	
	# Set our counters for async requests.
	set locals($s,count) 1
	set locals($s,nread) 0
	set locals($s,1,token) $token
	
	# Wait for the connection to complete
	fileevent $s writable [list httpex::Connect $token]
	set state(state) connect
	if {[info exists state(-command)]} {
	    uplevel #0 $state(-command) $token
	}
    }

    return $token
}

# httpex::Connect
#
#	This callback is made when an asyncronous connection completes.
#	Never called by the server side.
#
# Arguments
#	token	The token returned from httpex::get etc.
#
# Side Effects
#	Proceeds with the httpex protocol,

proc httpex::Connect {token} {    
    global  tcl_platform
    variable $token
    variable opts
    variable locals
    upvar 0 $token state    
    
    Debug 1 "httpex::Connect state(state)=$state(state)"
    
    set s $state(-socket)
    fileevent $s writable {}
    catch {after cancel $state(after)}
    
    if {[string equal $tcl_platform(platform) "macintosh"]} {
	if {[catch {eof $s} iseof] || $iseof} {
	    Eof $token $iseof
	    return
	}
    } else {
	if {[catch {eof $s} iseof] || $iseof ||  \
	  [string length [fconfigure $s -error]]} {
	    Eof $token $iseof
	    return
	}
    }
    
    # On track :-)
    set state(state) putheader
    if {[info exists state(-command)]} {
	uplevel #0 $state(-command) $token
    }
    
    # Send data in cr-lf format, but accept any line terminators
    
    fconfigure $s -translation {auto crlf} -buffersize $state(-blocksize)
    
    # The following is disallowed in safe interpreters, but the socket
    # is already in non-blocking mode in that case.
    
    catch {fconfigure $s -blocking off}
    
    # Handle post and put requests using these abstraction variables. (pp*)
    if {[string equal $state(method) "post"]} {	
	set ppdata -query
	set ppchannel -querychannel
    } elseif {[string equal $state(method) "put"]} {	
	set ppdata -putdata
	set ppchannel -putchannel
    }
    
    if {[string equal $state(method) "put"] || \
      [string equal $state(method) "post"]} {	
	if {[info exists state($ppdata)]} {
	    set state(length) [string length $state($ppdata)]
	} else {
	    
	    # The put channel must be blocking for the async Write to
	    # work properly.
	    fconfigure $state($ppchannel) -blocking 1 -translation binary
	}
    }
    
    if {[catch {
	set method [string toupper $state(method)]
	puts $s "$method $state(srvurl) HTTP/$state(-httpvers)"
	puts $s "Accept: $opts(-accept)"
	puts $s "Host: $state(host):$state(port)"
	puts $s "User-Agent: $opts(-useragent)"
	if {$state(-persistent)} {
	    puts $s "Connection: Keep-Alive"
	} else {
	    puts $s "Connection: close"
	}
	foreach {key value} $state(-headers) {
	    regsub -all \[\n\r\]  $value {} value
	    set key [string trim $key]
	    if {[string equal -nocase $key "content-length"]} {
		set state(length) $value
	    }
	    if {[string length $key]} {
		puts $s "$key: $value"
	    }
	}
	if {[string equal $state(method) "put"] || \
	  [string equal $state(method) "post"]} {
	    if {$state(length) == 0} {
		
		# Try to determine size of data in channel
		# If we cannot seek, the surrounding catch will trap us
		set state(length) [ChannelLength $state($ppchannel)]
	    }
	}
	
	# Flush the request header and set up the fileevent that will
	# either push the PUT data or read the response.
	#
	# fileevent note:
	#
	# It is possible to have both the read and write fileevents active
	# at this point.  The only scenario it seems to affect is a server
	# that closes the connection without reading the POST data.
	# (e.g., early versions Tclhttpd in various error cases).
	# Depending on the platform, the client may or may not be able to
	# get the response from the server because of the error it will
	# get trying to write the post data.  Having both fileevents active
	# changes the timing and the behavior, but no two platforms
	# (among Solaris, Linux, and NT)  behave the same, and none 
	# behave all that well in any case.  Servers should always read thier
	# POST data if they expect the client to read their response.
	
	if {[string equal $state(method) "put"] || \
	  [string equal $state(method) "post"]} {
	    
	    # Content-Type and Content-Length are compulsory!
	    puts $s "Content-Type: $state(-type)"
	    puts $s "Content-Length: $state(length)"
	    puts $s ""
	    set state(state) body
	    fconfigure $s -translation {auto binary}
	    fileevent $s writable [list httpex::Write $token]
	} else {
	    
	    # This ends our header for the GET method.
	    puts $s ""
	    flush $s
	    set state(state) waiting
	    FinishedRequest $token
	}
	
    } err]} {
	
	# The socket probably was never connected,
	# or the connection dropped later.
	Finish $token $err
	return
    }
    if {[info exists state(-command)]} {
	uplevel #0 $state(-command) $token
    }
}

# httpex::FinishedRequest
#
#	Responsible for rescheduling after a requst has been sent away.
#	Typically waiting for servers response to arrive.

proc httpex::FinishedRequest {token} {
    variable $token
    upvar 0 $token state    
    
    Debug 1 "httpex::FinishedRequest state(state)=$state(state)"

    fileevent $state(-socket) readable [list httpex::Event $token]
}

# httpex::readrequest
# 
#       Callback when a new socket connected and became readable.
#       Only errors from parsing args are returned.
#	Any network errors or protocol errors are delivered to -command.
#
# Arguments:
#
# Results:
#	Returns a token for this request.
#	This token is the name of an array that the caller should
#	unset to garbage collect the state.

proc httpex::readrequest {s callback args} {    
    variable locals
    variable opts
    variable defaultCharset
    
    Debug 1 "httpex::readrequest s=$s, callback=$callback, args='$args'"
    
    # Initialize the state variable, an array.  We'll return the
    # name of this array as the token for the transaction.
    
    set token [namespace current]::[incr locals(uid)]
    variable $token
    upvar 0 $token state
    
    # Process command options.
    
    array set state {
	-binary		false
	-blocksize 	8192
	-headers 	{}
	-persistent     0
	chunked         0
	coding		{}
	currentsize	0
	havecontentlength 0
	haveranges      0
	headclose       0
	http		""
	httpvers	1.0
	length	0
	meta		{}
	offset	0
	state		getheader
	status		""
	totalsize	0
	type            text/html
    }
    set state(-socket) $s
    set state(callback) $callback
    set state(args) $args
    
    if {[catch {eval {httpex::VerifyOptions $token $locals(opts,server)} $args} msg]} {
	return -code error $msg
    }
    
    # Temporary only until request processed correctly.
    set state(method) serverxxx 
    if {[catch {eof $s} iseof] || $iseof} {
	set state(headclose) 1
	Eof $token $iseof
    }
    fileevent $s writable {}
    fileevent $s readable {}
    fconfigure $s -translation {auto crlf} -buffersize $state(-blocksize)
    
    # Perhaps we should have this after a 'fileevent readable' '-buffering line'. 
    # May block if client opens socket and sends nothing.
    
    if {[catch {gets $s line} n]} {
	set state(headclose) 1
	Finish $token $n
	return
    } elseif {$n == 0} {
	Debug 2 "    n=$n"
	BadResponse $s $token 400
	return
    }
    set state(http) $line
    Debug 2 "    line='$line'"
    
    # Verify line.
    if {![regexp -nocase {^([^ ]+) +(/[^ ]+) +HTTP/([0-9]+\.[0-9]+)$} \
      $line match method filepath httpvers]} {
	
	# Bad Request.
	BadResponse $s $token 400
	return
    } elseif {![regexp (POST|PUT|GET|HEAD) $method match]} {
	
	# Not Implemented.
	BadResponse $s $token 502
	return
    }
    set method "server[string tolower $method]"
    
    set state(method) $method
    set state(httpvers) $httpvers
    set state(filepath) [string trimleft $filepath /]
    set state(abspath) [file join $opts(-basedirectory) $state(filepath)]
    set state(charset) $defaultCharset
    
    catch {fconfigure $s -blocking off}
    
    set state(state) connect
    if {[info exists state(-command)]} {
	uplevel #0 $state(-command) $token
    }
    
    # Go on and read the request header.
    fileevent $s readable [list httpex::Event $token]
    
    return $token
}

# httpex::Event
#
#	Handle input on the socket for reading the header.
#	Both client and server.
#
# Arguments
#	token	The token returned from httpex::Request
#
# Side Effects
#	Read the socket and handle callbacks.

proc httpex::Event {token} {    
    variable $token
    variable locals
    upvar 0 $token state
    
    Debug 1 "httpex::Event state(state)=$state(state)"
    
    set s $state(-socket)
    if {[catch {eof $s} iseof] || $iseof} {
	Eof $token $iseof
	return
    }
    
    if {![string equal $state(state) "getheader"]} {
	set state(state) getheader
	if {[info exists state(-command)]} {
	    uplevel #0 $state(-command) $token
	}
    }
    
    if {[catch {gets $s line} n]} {
	Finish $token $n
    } elseif {$n == 0} {
	variable encodings
	
	Debug 2 "\tn=$n"
	fileevent $s readable {}
	
	# If we have got a "Content-Length" header filed, and the method allows
	# a message-body, we also shall receive the message-body (RFC 2616, 4.3).
	set expectBody 0
	if {$state(havecontentlength) && ($state(totalsize) > 0)} {
	    set expectBody 1
	}
	
	# If we are a server and a message-body is expected, we MUST have
	# a 'Content-Length' header field. Else "Bad Request".
	if {[string equal $state(method) "serverpost"] ||
	[string equal $state(method) "serverput"]} {
	    if {!$state(havecontentlength)} {
		BadResponse $s $token 400
	    }
	}
	
	if {$state(-binary) || ![regexp -nocase ^text $state(type)] || \
	  [regexp gzip|compress $state(coding)]} {
	    Debug 2 "\tfconfigure $s -translation binary"
	    
	    # Turn off conversions for non-text data
	    fconfigure $s -translation binary
	    if {[info exists state(-channel)]} {
		fconfigure $state(-channel) -translation binary
	    }
	} else {
	    
	    # If we are getting text, set the incoming channel's
	    # encoding correctly.  iso8859-1 is the RFC default, but
	    # this could be any IANA charset.  However, we only know
	    # how to convert what we have encodings for.
	    set idx [lsearch -exact $encodings \
	      [string tolower $state(charset)]]
	    if {$idx >= 0} {
		fconfigure $s -encoding [lindex $encodings $idx]
		Debug 2 "\tfconfigure -encoding [lindex $encodings $idx]"
	    }
	}
	
	if {[string equal $state(method) "head"]} {
	    set state(status) ok
	    Finish $token
	} elseif {[string equal $state(method) "post"] && !$expectBody} {
	    set state(status) ok
	    Finish $token
	} elseif {[string equal $state(method) "serverhead"] || \
	  [string equal $state(method) "serverget"]} {
	    WriteResponse $token
	} elseif {[string equal $state(method) "get"] || \
	  [string equal $state(method) "serverput"] || \
	  [string equal $state(method) "serverpost"] || \
	  $expectBody} {

	    set state(state) body
	    if {[info exists state(-command)]} {
		uplevel #0 $state(-command) $token
	    }
	    if {[info exists state(-channel)]} {
		
		# Initiate a sequence of background fcopies
		CopyStart $s $token
	    } else {
		Debug 2 "\tfileevent readable httpex::Read"
		fileevent $s readable [list httpex::Read $s $token]
	    }
	}
    } elseif {$n > 0} {
	Debug 2 "\tline=$line"
	
	if {[regexp -nocase {^content-type:(.+)$} $line x type]} {
	    set state(type) [string trim $type]
	    
	    # grab the optional charset information
	    regexp -nocase {charset\s*=\s*(\S+)} $type x state(charset)
	} elseif {[regexp -nocase {^content-length:(.+)$} $line x length]} {
	    set state(totalsize) [string trim $length]
	    set state(havecontentlength) 1
	} elseif {[regexp -nocase {^content-encoding:(.+)$} $line x coding]} {
	    set state(coding) [string trim $coding]
	} elseif {[regexp -nocase {^connection: *close$} $line x]} {
	    set state(headclose) 1
	} elseif {[regexp -nocase {^transfer-encoding: *chunked} $line x]} {
	    set state(chunked) 1
	} elseif {[regexp -nocase {^range: *bytes=(.+)$} $line x byteSet]} {
	    set state(haveranges) 1
	    set ranges {}
	    foreach byteSpec [split $byteSet ,] {
		if {[regexp -- {^([0-9]+)-([0-9]+)$} $byteSpec x lower upper]} {
		    lappend ranges [list $lower $upper]
		} elseif {[regexp -- {-([0-9]+)$} $byteSpec x endoff]} {
		    lappend ranges [list [expr {$state(totalsize) - $endoff}] \
		      $state(totalsize)]
		} elseif {[regexp -- {^([0-9]+)-} $byteSpec x lower]} {
		    lappend ranges [list $lower $state(totalsize)]
		}
	    }
	    set state(ranges) $ranges
	}
	if {[regexp -nocase {^([^:]+):(.+)$} $line x key value]} {
	    lappend state(meta) $key [string trim $value]
	} elseif {[regexp {^HTTP/([0-9]+\.[0-9]+) +([0-9]{3})} $line  \
	  match httpvers ncode]} {
	    
	    # Only clients.
	    set state(http) $line
	    set state(httpvers) $httpvers
	    set state(ncode) $ncode
	}
    }
}

# httpex::WriteResponse
#
#       Write the servers response to the clients request.
#       
# Arguments
#	token	The token returned from httpex::get etc.
#
# Side Effects

proc httpex::WriteResponse {token} {    
    variable $token
    variable codeToText
    variable opts
    variable htmlErrMsg
    upvar 0 $token state
    
    Debug 1 "httpex::WriteResponse state(state)=$state(state)"
    
    if {![string equal $state(state) "putheader"]} {
	set state(state) putheader
	if {[info exists state(-command)]} {
	    uplevel #0 $state(-command) $token
	}
    }
    
    # Invoke the callback first.
    set ok 1
    set errmsg ""
    if {[catch {$state(callback) $token} resp]} {
	set ok 0
	set errmsg $resp
    }
    Debug 1 "   resp=$resp"
    foreach {code state(-headers)} $resp break
    if {![info exists codeToText($code)]} {
	set ok 0
	set errmsg "No text for code \"$code\""
    }
    
    # From RFC 2616, 4.4
    set messageBodyAllowed 1
    if {[string equal $state(method) "serverhead"] ||  \
      ([string match {1[0-9][0-9]} $code] || ($code == 204) || ($code == 304))} {
	set messageBodyAllowed 0
    }   
    set messageBodyRequired 0
    if {[string equal $state(method) "serverget"] && ($code == 200)} {
	set messageBodyRequired 1
    }
    set haveMessageBody 0
    if {[info exists state(-channel)] || [info exists state(senddata)]} {
	set haveMessageBody 1
    } elseif {[info exists htmlErrMsg($code)]} {
	set haveMessageBody 1
	set state(senddata) $htmlErrMsg($code)
    }
    
    # Make sure that if we MUST have a body to send it also can be found.
    if {$messageBodyRequired && !$haveMessageBody} {
	set ok 0
    }
    if {!$messageBodyAllowed && $haveMessageBody} {
	set haveMessageBody 0
    }
    if {$haveMessageBody &&  \
      ([lsearch -exact [string tolower $state(-headers)] "content-length"] < 0)} {
	if {[info exists state(-channel)]} {
	    lappend state(-headers) "Content-Length" [ChannelLength $state(-channel)]
	} elseif {[info exists state(senddata)]} {
	    lappend state(-headers) "Content-Length" [string length $state(senddata)]
	}
    }
    Debug 2 "   ok=$ok, haveBody=$haveMessageBody, BodyRequired=$messageBodyRequired"
    
    if {!$ok} {
	set code 500
	set state(-headers) {}
    }
    set s $state(-socket)
    
    if {[catch {
	puts $s "HTTP/1.1 $code $codeToText($code)"
	puts $s "Server: $opts(-server)"
	if {!$state(-persistent)} {
	    puts $s "Connection: close"
	}
	foreach {key value} $state(-headers) {
	    if {[string equal -nocase $key "content-length"]} {
		set state(totalsize) [string trim $value]
		set state(length) $state(totalsize)
	    } elseif {[string equal -nocase $key "content-type"]} {
		set state(type) [string trim $value]
	    }
	    puts $s "$key: $value"
	}
	puts $s ""
	flush $s
	
    } err]} {
	
	# The connection dropped.
	Finish $token $err 1
	return
    }
    
    if {![info exists state(type)]} {
	set state(type) application/octet-stream
    }
    
    # No message body to send here.
    if {!$haveMessageBody || !$ok} {
	Finish $token $errmsg
    } elseif {[info exists state(-channel)]} {
	
	# The put channel must be blocking for the async Write to
	# work properly.
	fconfigure $state(-channel) -blocking 1
	if {![regexp -nocase ^text $state(type)] || \
	  [regexp gzip|compress $state(coding)]} {
	    
	    # Turn off conversions for non-text data
	    fconfigure $s -translation binary
	    if {[info exists state(-channel)]} {
		fconfigure $state(-channel) -translation binary
	    }
	}
	set state(state) body
	if {[info exists state(-command)]} {
	    uplevel #0 $state(-command) $token
	}
	fileevent $s readable {}
	fileevent $s writable [list httpex::Write $token]	
    } elseif {[info exists state(senddata)]} {
	set state(state) body
	if {[info exists state(-command)]} {
	    uplevel #0 $state(-command) $token
	}
	fileevent $s readable {}
	fileevent $s writable [list httpex::Write $token]	
    }
}

# httpex::BadResponse 
#
#	A client made a bad request, and we tell it that.
#
# Arguments
#	s	The socket
#	token	The token 
#	code  The HTTP code to return.
#
# Side Effects
#	This closes connection

proc httpex::BadResponse {s token code} {
    variable $token
    variable codeToText
    variable opts
    upvar 0 $token state

    Debug 1 "httpex::BadResponse code=$code"

    # By default we close the socket after a bad request.
    set state(headclose) 1

    if {[catch {
	puts $s "HTTP/1.1 $code $codeToText($code)"
	puts $s "Server: $opts(-server)"
	puts $s "Connection: close"
	puts $s ""
	flush $s
    } err]} {
	
	# The connection dropped.
	Finish $token $err
	return
    }
    set state(status) ok
    Finish $token
}

# httpex::CopyStart
#
#	Error handling wrapper around fcopy. Copies from socket to channel.
#
# Arguments
#	s	The socket to copy from
#	token	The token returned from httpex::get etc.
#
# Side Effects
#	This closes the connection upon error

proc httpex::CopyStart {s token} {    
    variable $token
    upvar 0 $token state
    
    Debug 3 "httpex::CopyStart"
    
    set blocksize $state(-blocksize)
    if {$state(-persistent) && $state(havecontentlength) &&  \
      ([expr {$state(currentsize) + $blocksize}] >= $state(totalsize))} {
	set blocksize [expr {$state(totalsize) - $state(currentsize)}]
    }
    if {[catch {
	fcopy $s $state(-channel) -size $blocksize -command \
	    [list httpex::CopyDone $token]
    } err]} {
	Finish $token $err
    }
}

# httpex::CopyDone
#
#	fcopy completion callback. Copies from socket to channel.
#
# Arguments
#	token	The token returned from httpex::get etc.
#	count	The amount transfered
#
# Side Effects
#	Invokes callbacks

proc httpex::CopyDone {token count {error {}}} {    
    variable $token
    upvar 0 $token state
    
    Debug 3 "httpex::CopyDone state(state)=$state(state), count=$count"

    set s $state(-socket)
    incr state(currentsize) $count
    if {[info exists state(-progress)]} {
	eval $state(-progress) {$token $state(totalsize) $state(currentsize)}
    }
    
    # We shall not do this since text files have end of line translations
    # that do not preserve the total file size.
    set done 0
    if {0 && $state(havecontentlength) && ($state(currentsize) >= $state(totalsize))} {
	set done 1
    }
    
    # At this point the token may have been reset
    if {[string length $error]} {
	Finish $token $error
    } elseif {$done} {
	Eof $token
    } elseif {[catch {eof $s} iseof] || $iseof} {
	#Eof $token $iseof
	Eof $token
    } else {
	CopyStart $s $token
    }
}

# httpex::Eof
#
#	Handle eof on the socket
#
# Arguments
#	token	The token returned from httpex::get etc.
#	iseof   Boolean, 1 if a premature socket close.
#
# Side Effects
#	Clean up the socket. Invokes 'Finish'.

proc httpex::Eof {token {iseof 0}} {    
    variable $token
    upvar 0 $token state
    
    Debug 1 "httpex::Eof iseof=$iseof, state(state)=$state(state)"
    
    if {$iseof} {	
	# Premature eof
	set state(status) eof
    } else {
	set state(status) ok
    }
    
    # For chunked bodies we must dechunk it first.
    if {$state(chunked)} {
	if {[info exists state(-channel)]} {
	    DeChunkFile $token
	} else {
	    DeChunkBody $token
	}
    }
    
    # We should also verify that we have the entire body.
    if {$state(method) == "get"} {
	if {($state(totalsize) > 0) && \
	  ($state(totalsize) != $state(currentsize))} {
	   # set state(status) eof
	}
    }
    
    set state(state) final
    Finish $token
}

# httpex::Read
#
#	Reads from socket to internal variable.
#	Used by methods: get, serverpost, serverput.
#
# Arguments
#	s	socket
#	token	The token for the connection
#
# Side Effects
#	Read the socket and handle callbacks.

proc httpex::Read {s token} {    
    variable $token
    upvar 0 $token state
    
    Debug 1 "httpex::Read"
    
    if {[catch {eof $s} iseof] || $iseof} {
	Eof $token
	return
    }
    set done 0
    set blocksize $state(-blocksize)
    if {$state(-persistent) &&  \
      ([expr {$state(currentsize) + $blocksize}] >= $state(totalsize))} {
	set blocksize [expr {$state(totalsize) - $state(currentsize)}]
    }
    
    if {[catch {
	if {[info exists state(-handler)]} {
	    set n [eval $state(-handler) {$s $token}]
	} else {
	    set block [read $s $blocksize]
	    set n [string length $block]
	    if {$n >= 0} {
		append state(body) $block
	    }
	}
	if {$n >= 0} {
	    incr state(currentsize) $n
	}
    } err]} {
	Finish $token $err
	return
    } else {
	if {[info exists state(-progress)]} {
	    eval $state(-progress) {$token $state(totalsize) $state(currentsize)}
	}
    }
    if {$state(havecontentlength) && ($state(currentsize) >= $state(totalsize))} {
	set done 1
    }
    if {$done} {
	if {[string match "server*" $state(method)]} {
	    WriteResponse $token
	} else {
	    Eof $token
	}
    }
}

# httpex::Write
#
#	Write POST, PUT, or server side GET data to the socket from
#	variable or local channel. This is the message-body.
#
# Arguments
#	token	The token for the connection
#
# Side Effects
#	Write the socket and handle callbacks.

proc httpex::Write {token} {    
    variable $token
    upvar 0 $token state
    
    Debug 1 "httpex::Write"
    set s $state(-socket)

    if {[string equal $state(method) "post"]} {
	set ppdata -query
	set ppchannel -querychannel
	set ppblocksize -queryblocksize
	set ppprogress -queryprogress
    } elseif {[string equal $state(method) "put"]} {
	set ppdata -putdata
	set ppchannel -putchannel
	set ppblocksize -blocksize
	set ppprogress -putprogress
    } elseif {[string equal $state(method) "serverget"]} {
	set ppdata senddata
	set ppchannel -channel
	set ppblocksize -blocksize
	set ppprogress -progress
    }

    # Output a block.  Tcl will buffer this if the socket blocks    
    set done 0
    if {[catch {
	
	# Catch I/O errors on dead sockets

	if {[info exists state($ppdata)]} {
	    
	    # Chop up large put strings so progress callback
	    # can give smooth feedback

	    puts -nonewline $s \
	      [string range $state($ppdata) $state(offset) \
	      [expr {$state(offset) + $state($ppblocksize) - 1}]]
	    incr state(offset) $state($ppblocksize)
	    if {$state(offset) >= $state(length)} {
		set state(offset) $state(length)
		set done 1
	    }
	} else {
	    
	    # Copy blocks from the put channel or querychannel.

	    set outStr [read $state($ppchannel) $state($ppblocksize)]
	    puts -nonewline $s $outStr
	    incr state(offset) [string length $outStr]
	    if {[eof $state($ppchannel)]} {
		set done 1
	    }
	}
    } err]} {
	# Do not call Finish here, but instead let the read half of
	# the socket process whatever server reply there is to get.

	set state(posterror) $err
	set done 1
    }
    if {$done} {
    	Debug 2 "    done=$done"
	catch {flush $s}
	if {[string equal $state(method) "put"] || \
	  [string equal $state(method) "post"]} {
	    set state(state) waiting
    	    if {[info exists state(-command)]} {
		uplevel #0 $state(-command) $token
	    }

	    # Schedule reading servers response.
	    fileevent $s writable {}
	    FinishedRequest $token
	} elseif {[string equal $state(method) "serverget"]} {
	    set state(status) ok
	    Finish $token
	}
    }

    # Callback to the client after we've completely handled everything
    if {[info exists state($ppprogress)]} {
	eval $state($ppprogress) [list $token $state(length)\
	  $state(offset)]
    }
}

# httpex::VerifyOptions
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

proc httpex::VerifyOptions {token validopts args} {    
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

# httpex::reset --
#
#	See documentaion for details.
#
# Arguments:
#	token	Connection token.
#	why	Status info. 'reset' or 'timeout'.
#
# Side Effects:
#       See Finish

proc httpex::reset {token {why reset}} {   
    variable $token
    upvar 0 $token state
        
    Debug 1 "httpex::reset why=$why"
    
    catch {fileevent $state(-socket) readable {}}
    catch {fileevent $state(-socket) writable {}}
    set state(status) $why
    Finish $token
    if {[info exists state(error)]} {
	set errorlist $state(error)
	unset state
	eval ::error $errorlist
    }
}

# httpex::cleanup
#
#	Garbage collect the state associated with a transaction
#
# Arguments
#	token	The token returned from httpex::get etc.
#
# Side Effects
#	unsets the state array

proc httpex::cleanup {token} {    
    variable $token
    upvar 0 $token state

    Debug 1 "httpex::cleanup"
    
    if {[info exist state]} {
	unset state
    }
}

# httpex::Finish --
#
#	Invoke callback with "ok" or "error", clean up the socket or reschedule
#	fileevents on persistent connections.
#	Any state(status) except error status shall be set before.
#
# Arguments:
#	token	    Connection token.
#	errormsg    (optional) If set, forces status to error.
#       skipCB      (optional) If set, don't call the -command callback.  This
#                   is useful when getfile wants to throw an exception instead
#                   of calling the callback.  That way, the same error isn't
#                   reported to two places.
#
# Side Effects:
#        May close the socket, else reschedules fileevents

proc httpex::Finish {token {errormsg ""} {skipCB 0}} {
    global errorInfo errorCode
    
    variable $token
    variable locals
    upvar 0 $token state

    Debug 1 "httpex::Finish errormsg=$errormsg, skipCB=$skipCB"
    
    set s $state(-socket)
    set doClose 0
    if {[string length $errormsg] != 0} {
	set state(error) [list $errormsg $errorInfo $errorCode]
	set state(status) error
    	set doClose 1
    }
    if {[catch {eof $s} iseof] || $iseof} {
	set doClose 1
    }
    set state(state) final

    # If HTTP/1.0 we MUST always close the connection, else assume a
    # persistent connection, unless the request contained a
    # connection close line, or if we are configured with non-persistent
    # connections.
	    
    if {($state(httpvers) <= 1.0) || $state(headclose) || \
      !$state(-persistent)} {
    	set doClose 1
    }
    
    Debug 1 "\t state(status)=$state(status), doClose=$doClose"

    if {$doClose} {

	# What happens if we have more requests to send on a -persistent connection?
    	catch {close $s}
    } else {
	if {[string match "server*" $state(method)]} {

	    # Server only. Wait for new request on this socket. Use 'args' we have.
	    fileevent $s writable {}
	    fconfigure $s -translation {auto crlf}
	    fileevent $s readable  \
	      [concat [list httpex::readrequest $s $state(callback)] $state(args)]
    	    Debug 2 "\t fileevent httpex::readrequest"
	} else {

	    # Client only. Any queued up requests must be sent off.
	    fileevent $s readable {}
	    set nread [incr locals($s,nread)]
    	    Debug 2 "    nread=$nread, locals(s,count)=$locals($s,count)"
	    if {$nread < $locals($s,count)} {
		set next [incr nread]
		fileevent $s writable [list httpex::Connect $locals($s,$next,token)]
    	    	Debug 2 "    fileevent httpex::Connect, nread=$nread, next=$next"
	    }
	}
    }

    catch {after cancel $state(after)}
    if {[info exists state(-command)] && !$skipCB} {
	if {[catch {eval $state(-command) $token} err]} {
	    if {[string length $errormsg] == 0} {
		set state(error) [list $err $errorInfo $errorCode]
		set state(status) error
	    }
	}
	if {$doClose && [info exist state(-command)]} {
	    # Command callback may already have unset our state
	    unset state(-command)
	}
    }
}

# httpex::ChannelLength
#
#       Try to determine size of data in channel.

proc httpex::ChannelLength {channel} {

    set start [tell $channel]
    seek $channel 0 end
    set length [expr {[tell $channel] - $start}]
    seek $channel $start
    return $length
}

# Data access functions:
# Data - the url data.
# Status - the transaction status: ok, reset, eof, timeout
# Code - the httpex transaction code, e.g., 200
# Size - the size of the URL data

proc httpex::data {token} {
    variable $token
    upvar 0 $token state
    return $state(body)
}
proc httpex::status {token} {
    variable $token
    upvar 0 $token state
    return $state(status)
}
proc httpex::state {token} {
    variable $token
    upvar 0 $token state
    return $state(state)
}
proc httpex::size {token} {
    variable $token
    upvar 0 $token state
    return $state(currentsize)
}
proc httpex::code {token} {
    variable $token
    upvar 0 $token state
    return $state(http)
}
proc httpex::ncode {token} {
    variable $token
    upvar 0 $token state
    if {[info exists state(ncode)]} {
	return $state(ncode)
    } else {
	return ""
    }
}
proc httpex::ncodetotext {ncode} {
    variable codeToText
    if {[info exists codeToText($ncode)]} {
	return $codeToText($ncode)
    } else {
	return ""
    }
}
proc httpex::error {token} {
    variable $token
    upvar 0 $token state
    if {[info exists state(error)]} {
	return $state(error)
    }
    return {}
}
proc httpex::abspath {token} {
    variable $token
    upvar 0 $token state
    if {[info exists state(abspath)]} {
	return $state(abspath)
    }
    return {}
}
proc httpex::socket {token} {
    variable $token
    upvar 0 $token state
    return $state(-socket)
}
proc httpex::setchannel {token channel} {
    variable $token
    upvar 0 $token state
    set state(-channel) $channel
}
proc httpex::senddata {token body} {
    variable $token
    upvar 0 $token state
    
    set state(senddata) $body
}

# httpex::customcodes --
#
#     Add custom codes with messages.
#
# Arguments:
#     codelist      list: {320 New 321 {Too Old} ...}
# Results:
#     none.

proc httpex::customcodes {codelist} {
    variable codeToText
    
    array set codeToText $codelist
}

# httpex::register --
#
#     See documentaion for details.
#
# Arguments:
#     proto           URL protocol prefix, e.g. httpexs
#     port            Default port for protocol
#     command         Command to use to create socket
# Results:
#     list of port and command that was registered.

proc httpex::register {proto port command} {    
    variable urlTypes
    
    set urlTypes($proto) [list $port $command]
}

# httpex::unregister --
#
#     Unregisters URL protocol handler
#
# Arguments:
#     proto           URL protocol prefix, e.g. httpexs
# Results:
#     list of port and command that was unregistered.

proc httpex::unregister {proto} {    
    variable urlTypes
    
    if {![info exists urlTypes($proto)]} {
	return -code error "unsupported url type \"$proto\""
    }
    set old $urlTypes($proto)
    unset urlTypes($proto)
    return $old
}

# httpex::formatQuery --
#
#	See documentaion for details.
#	Call httpex::formatQuery with an even number of arguments, where 
#	the first is a name, the second is a value, the third is another 
#	name, and so on.
#
# Arguments:
#	args	A list of name-value pairs.
#
# Results:
#        TODO

proc httpex::formatQuery {args} {
    
    set result ""
    set sep ""
    foreach i $args {
	append result $sep [mapReply $i]
	if {![string equal $sep "="]} {
	    set sep =
	} else {
	    set sep &
	}
    }
    return $result
}

# httpex::mapReply --
#
#	Do x-www-urlencoded character mapping
#
# Arguments:
#	string	The string the needs to be encoded
#
# Results:
#       The encoded string

proc httpex::mapReply {string} {
    variable formMap

    # The spec says: "non-alphanumeric characters are replaced by '%HH'"
    # 1 leave alphanumerics characters alone
    # 2 Convert every other character to an array lookup
    # 3 Escape constructs that are "special" to the tcl parser
    # 4 "subst" the result, doing all the array substitutions

    set alphanumeric	a-zA-Z0-9
    regsub -all \[^$alphanumeric\] $string {$formMap(&)} string
    regsub -all {[][{})\\]\)} $string {\\&} string
    return [subst -nocommand $string]
}

# httpex::ProxyRequired --
#	Default proxy filter. 
#
# Arguments:
#	host	The destination host
#
# Results:
#       The current proxy settings

proc httpex::ProxyRequired {host} {    
    variable opts
    
    if {[info exists opts(-proxyhost)] && [string length $opts(-proxyhost)]} {
	if {![info exists opts(-proxyport)] || \
		![string length $opts(-proxyport)]} {
	    set opts(-proxyport) 8080
	}
	return [list $opts(-proxyhost) $opts(-proxyport)]
    }
}

# httpex::DeChunkBody --
# 
#       Removes all hex chunks into an ordinary body.
#       
# Arguments:
#	token	The token returned from httpex::get etc.
#
# Results:
#       None

proc httpex::DeChunkBody {token} {
    variable $token
    upvar 0 $token state
    
    Debug 1 "httpex::DeChunkBody"
    
    set body $state(body)
    set newbody ""
    set len 0
    set offset 0
    set ind [string first "\n" $body]
    
    # 'prefix' ends with "\n".
    set prefix [string range $body 0 $ind]    
    set hex [lindex [split $prefix ";\n"] 0]
    set chunkSize 0
    scan $hex %x chunkSize
    incr offset [expr {$ind + 1}]
    
    while {$chunkSize > 0} {
	
	# Process chunk body.
	append newbody [string range $body $offset [expr {$offset + $chunkSize - 1}]]
	incr offset [expr {$chunkSize + 1}]
	incr len $chunkSize
	
	# Process next chunk prefix.
	set ind [string first "\n" $body $offset]
	set prefix [string range $body $offset $ind]
	set hex [lindex [split $prefix ";\n"] 0]
	set chunkSize 0
	scan $hex %x chunkSize
	set offset [expr {$ind + 1}]
    }
    
    # Read entity header if any.
    
    
    # Set Content-Length and remove 'chunked'.
    array set metaArr $state(meta)
    set metaArr(Content-Length) $len
    unset -nocomplain metaArr(Transfer-Encoding)
    set state(meta) [array get metaArr]
    set state(body) $newbody
    set state(totalsize) $len
}

# httpex::DeChunkFile --
# 
#       Removes all hex chunks from the chunked body in file.
#       Same as DeChunkBody but for files.
#       
# Arguments:
#	token	The token returned from httpex::get etc.
#
# Results:
#       None

proc httpex::DeChunkFile {token} {
    variable $token
    upvar 0 $token state

    # Not there yet.....
    
}

proc httpex::Debug {num str} {
    variable debug
    if {$num <= $debug} {
	puts $str
    }
}

# For testing...................................................................
# Client side:
if {0} {
    set ip localhost
    set ip 192.168.0.12
    proc mycb {token} {
	upvar #0 $token state
	puts "--> state(state)=$state(state)"
	if {$state(status) == "ok"} {
	    puts "Code: [httpex::code $token]"
	    array set meta $state(meta)
	    parray meta
	}
	update idletasks
    }
    proc myprog {token total current} {
	puts -nonewline .
	update idletasks
    }
    # HEAD
    set tok [httpex::head $ip/httpex.tcl -timeout 8000 -command mycb]
    # GET
    set tok [httpex::get $ip/httpex.tcl -timeout 8000 -command mycb -progress myprog]
    # HEADs
    set first 1
    for {set i 1} {$i <= 3} {incr i} {
	if {$first} {
	    set tok [httpex::head $ip/httpex.tcl -command mycb -persistent 1]
	    set sock [httpex::socket $tok]
	    set first 0
	} else {
	    set tok [httpex::head $ip/httpex.tcl -command mycb -persistent 1 \
	      -socket $sock]
	}
    }
}

# Server side:
if {0} {
    set servSock [socket -server NewConnect 80]
    proc mycb {token} {
	upvar #0 $token state
	puts "--> state(state)=$state(state)"
	#parray state
	if {$state(status) == "ok"} {
	    puts "Code: [httpex::code $token]"
	    array set meta $state(meta)
	    parray meta
	}
	if {$state(status) == "ok" || $state(status) == "error"} {
	    if {[info exists state(-channel)]} {
		catch {close $state(-channel)}
	    }
	}
	update idletasks
    }
    proc servcb {token} {
	upvar #0 $token state
	
	puts "servcb: state(method)=$state(method)"
	set code 200
	set headlist {}
	
	switch -- $state(method)  {
	    serverget - serverhead {
		set abspath [httpex::abspath $token]
		if {[string length $abspath] == 0} {
		    return [list 500 $headlist]
		}
		if {[catch {clock format [file mtime $abspath]  \
		  -format "%a, %d %b %Y %H:%M:%S GMT" -gmt 1} modTime]} {
		    return [list 404 $headlist]
		} else {
		    set headlist [list Last-Modified $modTime]
		}
		if {$state(method) == "serverget"} {
		    if {[catch {open $abspath r} fd]} {
			return [list 404 $headlist]
		    } else {
			httpex::setchannel $token $fd
		    }
		} 
		if {[lsearch {.txt .html .text .c .cpp .h} \
		  [file extension $abspath]] >= 0} {
		    set type text/plain
		} else {
		    set type application/octet-stream
		}
		lappend headlist content-length [file size $abspath] content-type $type
	    } 
	    serverpost {
		
	    }
	}
	
	return [list $code $headlist]
    }
    
    proc NewConnect {sock ip port} {
	puts "New client at: sock=$sock, ip=$ip, port=$port"
	set tok [httpex::readrequest $sock servcb -command mycb -persistent 1]
	puts "    token=$tok"
    }
}

#-------------------------------------------------------------------------------
