#  tinyhttpd.tcl --
#  
#       This file is part of The Coccinella application. It implements a tiny
#       http server.
#      
#  Copyright (c) 2002-2005  Mats Bengtsson
#  This source file is distributed under the BSD license.
#  
#  See the README file for license, bugs etc.
#  
# $Id: tinyhttpd.tcl,v 1.25 2005-01-31 14:06:53 matben Exp $

# ########################### USAGE ############################################
#
#   NAME
#      tinyhttpd - a tiny http server
#      
#   COMMANDS
#      ::tinyhttpd::start ?-option value ...?
#      ::tinyhttpd::stop
#      ::tinyhttpd::addmimemappings mimeList
#      ::tinyhttpd::setmimemappings mimeList
#      ::tinyhttpd::anyactive
#      ::tinyhttpd::bytestransported
#      ::tinyhttpd::avergaebytespersec
#      ::tinyhttpd::cleanup
#      ::tinyhttpd::mount absPath name
#      ::tinyhttpd::unmount name
#      ::tinyhttpd::allmounted
#      ::tinyhttpd::registercgicommand path command
#      ::tinyhttpd::unregistercgicommand path
#      ::tinyhttpd::allcgibins
#      ::tinyhttpd::putheader token httpcode ?-headers list?
#      
# ##############################################################################

package require Tcl 8.4
package require uriencode

package provide tinyhttpd 1.0

namespace eval ::tinyhttpd:: {
        
    # Keep track of useful things.
    variable priv
    variable httpMsg
    variable html
    variable http
    variable options
    variable this
    variable timing
    variable mounts
    variable cgibin
    variable uid 0
        
    set this(path)          [file dirname [info script]]
    set this(httpvers)      1.1
    set this(accept-ranges) 1

    set this(debug) 0
    
    array set httpMsg {
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
	416 "Requested range not satisfiable"
	417 "Expectation Failed"
	500 "Internal Server Error"
	501 "Not Implemented"
	502 "Bad Gateway"
	503 "Service Unavailable"
	504 "Gateway Time-out"
	505 "HTTP Version not supported"
    }

    # Use variables to store typical html return messages instead of files.
    set html(404) {<HTML><HEAD>
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
    
    # Some standard responses. Use with 'format'. Careful with spaces!
    set http(responseheader) \
"HTTP/$this(httpvers) 200 $httpMsg(200)
Server: tinyhttpd/1.0
Last-Modified: %s
Content-Type: text/html"

    set http(200) \
"HTTP/$this(httpvers) 200 $httpMsg(200)
Server: tinyhttpd/1.0
Last-Modified: %s
Content-Type: %s
Content-Length: %s"

    set http(404) \
"HTTP/$this(httpvers) 404 $httpMsg(404)
Server: tinyhttpd/1.0
Last-Modified: %s
Content-Type: %s
Content-Length: %s"

    set http(404,plain) \
"HTTP/$this(httpvers) 404 $httpMsg(404)
Content-Type: text/html"

    set http(404GET,plain) \
"HTTP/$this(httpvers) 404 $httpMsg(404)
Content-Type: text/html
Content-Length: [string length $html(404)]\n\n$html(404)"

    set http(header) \
"HTTP/$this(httpvers) %s %s
Server: tinyhttpd/1.0
Last-Modified: %s
Content-Type: %s
Content-Length: %s"

    set http(headerNoContent) \
"HTTP/$this(httpvers) %s %s
Server: tinyhttpd/1.0"

    if {$this(accept-ranges)} {
	append http(responseheader) "\nAccept-Ranges: bytes"
	append http(200) "\nAccept-Ranges: bytes"
    }
    
    # These shall be used with 'format' to make html dir listings.
    set html(head,plain) {
<html><head><title> %s </title></head>
<body bgcolor="white">
<!-- HTML generated by tinyhttpd -->}

    set html(updir,css) {}

    set html(tabletop,css) {
	<table nowrap border=0 cellpadding="2">
	    <tr>
	        <td align=center nowrap height=19> %s objects </td>
		<td align=left nowrap><b>Name</b></td>
		<td align=right nowrap>Size</td>
		<td align=left nowrap></td>
		<td align=left nowrap>Type</td>
		<td align=left nowrap></td>
		<td align=left nowrap>Date</td>
	    </tr>
	    <tr>
	        <td colspan=7 height=10><hr></td>
	    </tr>
    }

    set html(updir,plain) {
	<a href="%s"><img border=0 src="%s">
	    Parent directory "%s"
	</a>
	<br>
    }
        
    set html(line,plain) {
    <tr>
	<td align=center nowrap height=17>
	    <a href="%s"><img border=0 width=16 height=16 src="%s"></a>
	</td>
	<td align=left nowrap><a href="%s"> %s </a></td>
	<td align=right nowrap> %s </td>
	<td align=left nowrap width="16">&nbsp;</td>
	<td align=left nowrap> %s </td>
	<td align=left nowrap width="16">&nbsp;</td>
	<td align=left nowrap> %s </td>
    </tr>}
    
    set html(dirbottom,plain) {
    </table>
    <br><br>
    </body>
    </html>}
    
    # Using CSS.
    set html(head,css) {
	<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN">
	<html>
	<head>
	    <title>The Coccinella: directory listing</title> 	
	    <style type="text/css" media="screen">
	        @import "/httpd/std.css";
	    </style>
	</head>
	<body bgcolor="white" leftmargin="0" topmargin="0" marginwidth="0" marginheight="0">
	<!-- HTML generated by tinyhttpd -->
	<center>
	<br>
	<table width="600" border="0" cellspacing="1" cellpadding="4" bgcolor="#A1A5A9">
	    <tr>
	        <td bgcolor="#F2F2F2"><b>The Coccinella: directory listing of "%s"</b></td>
	    </tr>
	</table>
	<br>
    }

    set html(updir,css) {
	<table width="600" border="0" cellspacing="1" cellpadding="4" bgcolor="white">
	    <tr>
		<td align=left nowrap bgcolor="white">
		<a href="%s"><img border=0 src="%s">
		    Parent directory "%s"
		</a>
		</td>
	    </tr>
	</table>
	<br>
    }

    set html(tabletop,css) {
	<table width="600" border="0" cellspacing="1" cellpadding="4" bgcolor="#A1A5A9">
	    <tr valign="middle" bgcolor="#E2EEFF">
	        <td align=center nowrap><b> %s objects </b></td>
		<td align=left nowrap><b>Name</b></td>
		<td align=right nowrap><b>Size</b></td>
		<td align=left nowrap><b>Type</b></td>
		<td align=left nowrap><b>Date</b></td>
	    </tr>
    }

    set html(line,css) {
	<tr bgcolor="%s">
	    <td align=center nowrap>
	        <a href="%s"><img border=0 width=16 height=16 src="%s"></a>
	    </td>
	    <td align=left nowrap><a href="%s"> %s </a></td>
	    <td align=right nowrap> %s </td>
	    <td align=left nowrap> %s </td>
	    <td align=left nowrap> %s </td>
	</tr>
    }
    
    # Pyjamas colors.
    set html(bgcolor,css,0) #FFFFFF
    set html(bgcolor,css,1) #F3F8FF
    
    set html(dirbottom,css) {
    </table>
    <br>
    <table width="600" border="0" cellspacing="0" cellpadding="4" class="tableborder">
        <tr>
	    <td bgcolor="#F2F2F2" align="left" class="G10G"><b>The Coccinella</b></td>
	    <td bgcolor="#F2F2F2" align="right"><img src="/httpd/images/download.gif" width="11" height="10" border="0" alt="" align="absmiddle"></a>
	        <a href="http://hem.fyristorg.com/matben/download/">Download</a>
	    </td>
	</tr>
    </table>
    <br>
    <table width="600" border="0" cellspacing="0" cellpadding="4">
        <tr>
	    <td class="G10G">This application is distributed under the General Public License (GPL). See the <a href="http://www.gnu.org/">Free Software Foundation</a> for further details.</td>
        </tr>
    </table>
    <br> 
    </center>
    </body>
    </html>}

    
    
    # Default mapping from file suffix to Mime type.
    variable suffToMimeType
    array set suffToMimeType {
      .txt      text/plain
      .html     text/html
      .htm      text/html
      .text     text/plain
      .gif      image/gif
      .jpeg     image/jpeg
      .jpg      image/jpeg
      .png      image/png
      .tif      image/tiff
      .tiff     image/tiff
      .mov      video/quicktime
      .mpg      video/mpeg
      .mpeg     video/mpeg
      .mp4      video/mpeg4
      .avi      video/x-msvideo
      .aif      audio/aiff
      .aiff     audio/aiff
      .au       audio/basic
      .wav      audio/wav
      .mid      audio/midi
      .mp3      audio/mpeg
      .sdp      application/sdp
      .ps       application/postscript
      .eps      application/postscript
      .pdf      application/pdf
      .rtf      application/rtf
      .rtp      application/x-rtsp
      .rtsp     application/x-rtsp
      .tcl      application/x-tcl
      .zip      application/x-zip
      .sit      application/x-stuffit
      .gz       application/x-zip
    }
}

# tinyhttpd::start --
#
#       Start the http server.
#
# Arguments:
#       args:
#           -cgibinrelativepath   httpd/cgibin
#           -chunk                8192
#           -defaultindexfile     index.html
#	    -directorylisting     0
#	    -httpdrelativepath    httpd
#	    -log                  0
#	    -logfile              httpdlog.txt
#	    -mountrelativepath    httpd/mnt
#	    -myaddr               ""
#	    -port                 80
#	    -rootdirectory        thisPath
#	    -style                css
#       
# Results:
#       server socket opened.

proc ::tinyhttpd::start {args} {
    variable options
    variable priv
    variable this
        
    # Any configuration options. Start with defaults, overwrite with args.
    array set options {
	-cgibinrelativepath   httpd/cgibin
	-chunk                8192
	-defaultindexfile     index.html
	-directorylisting     0
	-httpdrelativepath    httpd
	-imagesrelativepath   httpd/images
	-log                  0
	-logfile              httpdlog.txt
	-mountrelativepath    httpd/mnt
	-myaddr               ""
	-port                 80
	-style                css
    }
    set options(-rootdirectory) [file dirname [info script]]
    array set options $args
    if {[file pathtype $options(-rootdirectory)] != "absolute"} {
	return -code error "the path must be an absolute path"
    }

    set servopts ""
    if {$options(-myaddr) != ""} {
	set servopts [list -myaddr $options(-myaddr)]
    }
    if {[catch {
	eval {socket -server [namespace current]::NewChannel} $servopts \
	  $options(-port)} sock]} {
	return -code error "Couldn't start server socket: $sock."
    }	
    set priv(sock)  $sock

    # Log file
    if {$options(-log)} {
	if {[catch {open $options(-logfile) a} fd]} {
	    catch {close $priv(sock)}
	    return -code error "Failed open the log file: $options(-logfile): $fd"
	}
	set priv(logfd) $fd
	fconfigure $priv(logfd) -buffering none
    }
    
    # Normalize all relative paths to unix style paths.
    set priv(rpath,httpd) [unixpath $options(-httpdrelativepath)]
    set priv(rpath,imgs)  [unixpath $options(-imagesrelativepath)]
    set priv(rpath,mnt)   [unixpath $options(-mountrelativepath)]
    set priv(rpath,cgi)   [unixpath $options(-cgibinrelativepath)]
    
    # Native relative paths.
    set priv(npath,httpd) [file nativename $options(-httpdrelativepath)]
    set priv(npath,imgs)  [file nativename $options(-imagesrelativepath)]
    set priv(npath,mnt)   [file nativename $options(-mountrelativepath)]
    set priv(npath,cgi)   [file nativename $options(-cgibinrelativepath)]
    
    # Cache various paths: apath (absolute), rpath (relative).
    # Keep absolute paths native [file join ...].
    set priv(apath,root) $options(-rootdirectory)
    set priv(apath,httpd) [file join $options(-rootdirectory) $priv(npath,httpd)]
    set priv(apath,imgs)  [file join $options(-rootdirectory) $priv(npath,imgs)]
    set priv(apath,mnt)   [file join $options(-rootdirectory) $priv(npath,mnt)]
    set priv(apath,cgi)   [file join $options(-rootdirectory) $priv(npath,cgi)]

    set priv(rpath,imgs,folder) $priv(rpath,imgs)/folder.gif
    set priv(rpath,imgs,file)   $priv(rpath,imgs)/file.gif
    set priv(rpath,imgs,up)     $priv(rpath,imgs)/up.gif
    
    set priv(apath,imgs,folder) [file join $priv(apath,imgs) folder.gif]
    set priv(apath,imgs,file)   [file join $priv(apath,imgs) file.gif]
    set priv(apath,imgs,up)     [file join $priv(apath,imgs) up.gif]
    
    if {![file exists $priv(apath,imgs,folder)]} {
	return -code error "Failed localizing folder.gif"
    }
    foreach name {400 404} {
	set f [file join $priv(apath,httpd) $name.html]
	if {[file exists $f]} {
	    set priv(apath,html,$name) $f
	}
    }
        
    LogMsg "Tiny Httpd started"

    return ""
}

# tinyhttpd::NewChannel --
# 
#       Callback procedure for the server socket. Gets called whenever a new
#       client connects to the server socket.
#
# Arguments:
#	token	The token for the internal state array.
#       
# Results:
#       token

proc ::tinyhttpd::NewChannel {s ip port} {
    variable uid

    Debug 2 "NewChannel:: s=$s, ip=$ip, port=$port"

    # Initialize the state variable, an array.  We'll return the
    # name of this array as the token for the transaction.
    
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state
	
    array set state {
	currentsize       0
	state             "connected"
	status            ""
    }
    set state(s)    $s
    set state(ip)   $ip
    set state(port) $port
    
    # Everything should be done with 'fileevent'.
    fconfigure $s -blocking 0 -buffering line
    fileevent $s readable [list [namespace current]::HandleRequest $token]
    
    return $token
}

# tinyhttpd::HandleRequest --
#
#       Initiates a GET or HEAD request. A sequence of callbacks completes it.
#       
# Arguments:
#	token	The token for the internal state array.
#       
# Results:
#       new fileevent procedure registered.

proc ::tinyhttpd::HandleRequest {token} {    
    variable $token
    upvar 0 $token state
    variable options

    Debug 2 "HandleRequest:: $token"
    
    set s $state(s)
    set state(state) reading

    # If client closes socket.
    if {[catch {eof $s} iseof] || $iseof} {
	Finish $token eof
    } elseif {[fblocked $s]} {
	Debug 2 "\tblocked"
	return
    }
        
    # If end-of-file or because of insufficient data in nonblocking mode,
    # then gets returns -1.
    if {[catch {
	set nbytes [gets $s line]
    }]} {
	Finish $token eof
	return
    }
    
    # Ignore any leading empty lines (RFC 2616, 4.1).
    if {$nbytes == 0} {
	return
    } elseif {$nbytes != -1} {
	set state(line) $line
	Debug 2 "\tline=$line"

	# We only implement the GET and HEAD operations.
	if {[regexp -nocase {^(GET|HEAD) +([^ ]*) +HTTP/([0-9]+\.[0-9]+)} \
	  $line match cmd path reqvers]} {    
	    LogMsg "$cmd: $path"
	    set state(cmd) $cmd

	    # The unix style, uri encoded path relative -rootdirectory,
	    # starting with a "/".
	    set state(path)    $path
	    set state(reqvers) $reqvers

	    # Make local absolute path.
	    set relpath [string trimleft $path /]
	    set relpath [uriencode::decodefile $relpath]
	    set apath   [file join $options(-rootdirectory) $relpath]
	    set state(rpath) $relpath
	    set state(apath) [file nativename [file normalize $apath]]
	    set state(targetabspath) $state(apath)
	    
	    set state(chunk)     $options(-chunk)
	    set state(haverange) 0
	    
	    # Set fileevent to read the sequence of 'key: value' lines.
	    fileevent $s readable [list [namespace current]::Event $token]
	} else {
	    LogMsg "unknown request: $line"
	    Finish $token "unknown request: $line"
	}
    } else {

	# If end-of-file or because of insufficient data in nonblocking mode,
	# then gets returns -1.
	return
    }
}
	    
# tinyhttpd::Event --
#
#       Reads and processes a 'key: value' line, reschedules itself if not blank
#       line, else calls 'Respond' to initiate a file transfer.
#
# Arguments:
#	token	The token for the internal state array.
#       
# Results:

proc ::tinyhttpd::Event {token} {    
    variable $token
    upvar 0 $token state    
    
    set s $state(s)
    if {[catch {eof $s} iseof] || $iseof} {
	Debug 2 "Event:: eof s"
	Finish $token eof
	return
    } elseif {[fblocked $s]} {
	Debug 2 "Event:: blocked s"
	return
    }
    
    # If end-of-file or because of insufficient data in nonblocking mode,
    # then gets returns -1.
    if {[catch {
	set nbytes [gets $s line]
	Debug 3 "Event:: nbytes=$nbytes, line=$line"
    }]} {
	Finish $token eof
	return
    }
    if {$nbytes == -1} {
	return
    } elseif {$nbytes > 0} {
	
	# Keep track of request meta data.
	if {[regexp -nocase {^([^:]+):(.+)$} $line x key value]} {
	    lappend state(meta) $key [string trim $value]
	}
	if {[regexp -nocase {^content-type:(.+)$} $line x type]} {
	    set state(content-type) [string trim $type]
	} elseif {[regexp -nocase {^range:(.+)$} $line x range]} {
	    set range [string trim $range]
	    set rangelist [ParseRange $range]
	    set state(range)       $range
	    set state(rangelist)   $rangelist
	    set state(haverange) 1
	}
    } elseif {$nbytes == 0} {
	
	# First empty line, respond.
	fileevent $s readable {}
	Respond $token
    }
}

proc ::tinyhttpd::ParseRange {range} {
    
    set rlist {}
    foreach r [split $range ,] {
	if {[regexp {([0-9]*)-([0-9]*)} $r match n1 n2]} {
	    if {$n2 == ""} {
		set n2 end
	    } elseif {$n1 == ""} {
		set n1 end-$n2
		set n2 end
	    }
	    lappend rlist [list $n1 $n2]
	} else {
	    # illegal range request
	}
    }
    return $rlist
}

# tinyhttpd::Respond --
#
#       Responds the client with the HTTP protocol, and then a number of 
#       'key: value' lines. File transfer initiated.
#       
# Arguments:
#	token	The token for the internal state array.
#       
# Results:
#       fcopy called.

proc ::tinyhttpd::Respond {token} {    
    variable $token
    upvar 0 $token state    
    variable options
    variable priv
    variable mounts
    variable cgibin
    
    Debug 2 "Respond:: $token"
            
    set cmd     $state(cmd)
    set relpath $state(rpath)    
    set abspath $state(apath)

    set state(state) responding

    Debug 2 "\t relpath=$relpath"
    Debug 2 "\t abspath=$abspath"
    
    set httpcode 200
    set ismounted  0
    
    if {$state(haverange)} {
	# not correct!!!!!!
	if {[llength $state(rangelist)] != 1} {
	    PutIfError $token 416
	    return
	}	
    } elseif {[regexp ^$priv(rpath,cgi)/(.*)$ $relpath match subpath]} {	

	# See if cgi-bin. Handle over control.
	if {[info exists cgibin($subpath)]} {
	    
	    # Leave over the complete control to this script.
	    uplevel #0 $cgibin($subpath) $token
	} else {
	    Put404 $token
	}
	return
    } elseif {[regexp ^$priv(rpath,mnt)/(.*)$ $relpath match subpath]} {		
	
	# See first if this is a "mounted" directory.
	# Find name of mounted from subpath.
	set sublist [file split $subpath]
	set mname [lindex $sublist 0]
	if {[info exist mounts($mname)]} {
	    set ismounted 1
	    set rest [file join [lrange $sublist 1 end]]
	    set abspath [eval {file join $mounts($mname)} $rest]
	    set abspath [file normalize $abspath]
	    set state(targetabspath) $abspath
	} else {
	    Put404 $token
	    return
	}
	Debug 2 "\t abspath=$abspath"
    }
    
    if {[file isdirectory $abspath]} {

	# If directory given then search for the '-defaultindexfile',
	# or if no one, possibly return directory listing, else 404.

	set indexfile [file join $abspath $options(-defaultindexfile)]
	if {[file exists $indexfile]} {
	    set abspath $indexfile
	} elseif {$options(-directorylisting)} {
	    
	    # No default html file exists, return directory listing.
	    PutHtmlDirList $token $abspath
	    return
	} else {
	    Put404 $token
	    return
	}
    }

    # Go ahead and do the response.
    PutResponse $token $httpcode $abspath
}

# tinyhttpd::PutResponse --
# 
# 
# Arguments:
#	token	    The token for the internal state array.
#       httpcode
#       abspath
#       
# Results:
#       initiates a file copy if requested

proc ::tinyhttpd::PutResponse {token httpcode abspath} {
    variable $token
    upvar 0 $token state    
    variable suffToMimeType
    variable httpMsg
    variable http
    variable timing
    variable priv
    
    Debug 2 "::tinyhttpd::PutResponse httpcode=$httpcode, abspath=$abspath"
    
    set s   $state(s)
    set cmd $state(cmd)
    
    # Check that the file is there and opens correctly.
    if {![file exists $abspath] || [catch {open $abspath r} fd]} {
	if {[info exists priv(apath,html,404)]} {
	    set abspath $priv(apath,html,404)
	    if {[catch {open $abspath r} fd]} {
		PutPlain404 $token
		return
	    }
	    set httpcode 404
	} else {	
	    PutPlain404 $token
	    return
	}
    }
    set fext [string tolower [file extension $abspath]]
    if {[info exists suffToMimeType($fext)]} {
	set mime $suffToMimeType($fext)
    } else {
	set mime "application/octet-stream"
    }
    
    # Put stuff.
    set size [file size $abspath]
    set state(fd)         $fd
    set state(size)       $size
    set state(contentlen) $size
    set state(endbyte)    [expr {$size - 1}]
    set extraheader ""
    
    # Ignore ranges if not sending requested file.
    if {$state(haverange) && [string equal $httpcode "200"]} {
	set n1 [lindex $state(rangelist) 0 0]
	set n2 [lindex $state(rangelist) 0 1]
	if {[regexp {end-([0-9]+)} $n1 match n]} {
	    set n1 [expr {$size - $n}]
	}
	if {$n2 > $state(endbyte)} {
	    set n2 $state(endbyte)
	}
	
	# Range validation.
	if {$n1 > $n2} {
	    set httpcode 416
	} else {
	    set state(range,begin) $n1
	    set state(range,end)   $n2
	    set state(contentlen) [expr {$n2 - $n1 + 1}]
	    seek $fd $n1
	    set httpcode 206
	    set extraheader "\nContent-Range: bytes $n1-$n2/$size"
	}
    }

    # Prepare the header.
    set modTime [clock format [file mtime $abspath]  \
      -format "%a, %d %b %Y %H:%M:%S GMT" -gmt 1]
    set msg $httpMsg($httpcode)
    set header [format $http(header) $httpcode $msg $modTime $mime \
      $state(contentlen)]

    if {[catch {
	puts $s ${header}${extraheader}
	puts $s ""
	flush $s
    } err]} {
	Finish $token $err
	return
    }
    Debug 3 "\t header=...\n'$header'"

    if {[string equal $cmd "HEAD"]}  {
	Finish $token
    } else {

	# Do this always since line end translations may screw up the byte counts.
	fconfigure $fd -translation binary
	fconfigure $s  -translation binary
	flush $s
	
	# Seems necessary (?) to avoid blocking the UI. BAD!!!
	#update
	
	# Background copy. Be sure to switch off all fileevents on channel.
	fileevent  $s readable {}
	fileevent  $s writable {}
	fconfigure $s -buffering full
	set timing($token) [list [clock clicks -milliseconds] 0]
	
	# Initialize the stream copy.
	CopyStart $s $token
    }
}

# tinyhttpd::putheader --
# 
#       Utility for cgi scripts for putting the header.

proc ::tinyhttpd::putheader {token httpcode args} {
    variable $token
    upvar 0 $token state    
    variable httpMsg
    variable http
    
    array set argsArr {
	-headers    {}
    }
    array set argsArr $args
    set s   $state(s)

    # Prepare the header.
    set msg $httpMsg($httpcode)
    set header [format $http(headerNoContent) $httpcode $msg]
    set extraheader ""
    foreach {key value} $argsArr(-headers) {
	regsub -all \[\n\r\] $value {} value
	set key [string trim $key]
	if {[string length $key]} {
	    append extraheader "\n$key: $value"
	}
    }
    
    if {[catch {
	puts $s ${header}${extraheader}
	puts $s ""
	flush $s
    } err]} {
	Finish $token $err
	return
    }
}

# tinyhttpd::CopyStart --
# 
#       The callback procedure for fcopy when copying from a disk file
#       to the socket. 
#       
# Arguments:
#	s	The socket to copy to
#	token	The token for the internal state array.
#       bytes     number of bytes in this chunk.
#       error     any error.
#       
# Results:
#       possibly reschedules itself.

proc ::tinyhttpd::CopyStart {s token} {    
    variable $token
    upvar 0 $token state    
    variable priv
    
    Debug 6 "CopyStart::"
    if {$state(haverange) && [string is integer $state(range,end)]} {
	set offset [tell $state(fd)]
	if {[expr {$offset + $state(chunk)}] > $state(range,end)} {
	    set state(chunk) [expr {$state(range,end) - $offset + 1}]
	}
    }
    if {[catch {
	fcopy $state(fd) $s -size $state(chunk) -command  \
	  [list [namespace current]::CopyDone $token]
    } err]} {
	Finish $token $err
    } 
}

# tinyhttpd::CopyDone
#
#	fcopy completion callback
#
# Arguments
#	token	The token for the internal state array.
#	bytes	The amount transfered
#
# Side Effects
#	Invokes callbacks

proc ::tinyhttpd::CopyDone {token bytes {error {}}} {    
    variable $token
    variable timing
    upvar 0 $token state

    Debug 6 "CopyDone::"

    set s  $state(s)
    set fd $state(fd)
    incr state(currentsize) $bytes
    lappend timing($token) [clock clicks -milliseconds] $state(currentsize)
    
    # At this point the token may have been reset
    if {[string length $error] > 0} {
	Finish $token $error
    } elseif {[catch {eof $s} iseof] || $iseof} {
	Finish $token eof
    } elseif {[catch {eof $fd} iseof] || $iseof} {
	Finish $token
    } elseif {$state(haverange) && \
      ([tell $state(fd)] >= [expr $state(range,end) + 1])} {
	Finish $token
    } else {
	CopyStart $s $token
    }
}

# tinyhttpd::Finish
#
#	Ends a request/response transaction.
#
# Arguments
#	token	The token for the internal state array.
#	errmsg  Nonempty if any error.
#
# Side Effects
#	Frees memory, closes sockets and files.

proc ::tinyhttpd::Finish {token {errmsg ""}} {
    variable $token
    upvar 0 $token state    
    
    LogMsg "Finish errmsg=$errmsg"
    Debug 2 "Finish errmsg=$errmsg"
    
    if {[string length $errmsg]} {
	set state(status) $errmsg
    } else {
	set state(status) ok
    }
    set state(state) finished
    catch {close $state(s)}
    if {[info exists state(fd)]} {
	catch {close $state(fd)}
    }
    unset state
}

# tinyhttpd::PutHtmlDirList --
# 
# 
# Arguments:
#       token
#       
# Results:
#       Writes response using 'BuildHtmlForDir'.

proc ::tinyhttpd::PutHtmlDirList {token abspath} {
    variable $token
    upvar 0 $token state    
    variable http
    
    set s   $state(s)
    set cmd $state(cmd)

    # No default html file exists, return directory listing.
    set modTime [clock format [file mtime $abspath]  \
      -format "%a, %d %b %Y %H:%M:%S GMT" -gmt 1]
    if {[catch {
	puts $s [format $http(responseheader) $modTime]
	
	if {[string equal $cmd "GET"]} {
	    set html [BuildHtmlForDir $token]
	    puts $s "Content-Length: [string length $html]"
	    puts $s ""
	    puts $s $html
	} else {
	    puts $s ""
	}
    } err]} {
	Finish $token $err
	return
    }
    Finish $token
}   

# tinyhttpd::BuildHtmlForDir --
#
#       Returns the html code that describes the directory inPath.
#       
# Arguments:
#       token
#       
# Results:
#       A complete html page describing the directory.

proc ::tinyhttpd::BuildHtmlForDir {token} {    
    variable $token
    upvar 0 $token state    
    variable this
    variable html
    variable priv
    variable options
    
    Debug 2 "BuildHtmlForDir:"
    
    set style   $options(-style)
    set relpath [string trimright $state(rpath) /]
    set abspath $state(targetabspath)
    
    Debug 4 "\t relpath=$relpath"
    Debug 4 "\t abspath=$abspath"
    
    set imgfile   /$priv(rpath,imgs,file)
    set imgfolder /$priv(rpath,imgs,folder)
    set imgup     /$priv(rpath,imgs,up)
    
    # Start by finding the directory content. 
    set allFiles [glob -directory $abspath -nocomplain *]
    set num [llength $allFiles]
    if {$relpath != ""} {
	set rellist [file split $relpath]
	set uplist  [lrange $rellist 0 end-1]
	set upname  [lindex $uplist end]
	if {$upname == ""} {
	    set upname /
	}
	set uprpath ../
    }
    
    # Build the complete html page dynamically.    
    set dirname [string trim [lindex [file split $abspath] end] "\\/"]
    set htmlStuff    [format $html(head,$style) $dirname]
    if {$relpath != ""} {
	append htmlStuff [format $html(updir,$style) $uprpath $imgup $upname]
    }
    append htmlStuff [format $html(tabletop,$style) $num]
    
    # Loop over all files and directories in our directory.
    set i 0
    foreach f $allFiles {
	
	if {[catch {clock format [file mtime $f]  \
	  -format "%a %d %b %Y, %H.%M"} dateAndTime]} {
	    set dateAndTime --
	}
	
	# The link in html must be the encoded unix path.
	set name [file tail $f]
	set encodedname [uriencode::quotepath $name]
	if {1} {
	    if {$relpath == ""} {
		set link "/$encodedname"
	    } else {
		set link "/$relpath/$encodedname"
	    }
	} else {
	    set link $encodedname
	}
	#puts "\t link=$link"

	# Is file or directory?
	if {[file isdirectory $f]} {
	    append link /
	    set img $imgfolder
	    set size -
	    set type "Directory"
	} else {
	    set img $imgfile
	    if {[catch {file size $f} bytes]} {
		set bytes 0
	    }
	    set size [FormatBytesText $bytes]
	    set type $name
	}
	if {[string equal $style "css"]} {
	    set color $html(bgcolor,css,[expr $i%2])
	    append htmlStuff [format $html(line,css) \
	      $color $link $img $link $name $size $type $dateAndTime]
	} else {
	    append htmlStuff [format $html(line,plain) \
	      $link $img $link $name $size $type $dateAndTime]
	}
	incr i
    }
    
    # And the end.
    append htmlStuff $html(dirbottom,$style)
    
    return $htmlStuff
}

# tinyhttpd::PutIfError --
# 

proc ::tinyhttpd::PutIfError {token httpcode} {
    variable $token
    upvar 0 $token state    
    variable http
    variable httpMsg
    
    # Prepare the header.
    set msg $httpMsg($httpcode)
    set header [format $http(headerNoContent) $httpcode $msg]

    if {[catch {
	puts $s $header
	puts $s ""
	flush $s
    } err]} {
	Finish $token $err
	return
    }
    Finish $token
}

# tinyhttpd::Put404 --
# 

proc ::tinyhttpd::Put404 {token} {
    variable priv

    if {[info exists priv(apath,html,404)]} {
	PutResponse $token 404 $priv(apath,html,404)
    } else {	
	PutPlain404 $token
    }
}

# tinyhttpd::PutPlain404 --
# 

proc ::tinyhttpd::PutPlain404 {token} {
    variable $token
    upvar 0 $token state
    variable http
    
    set s   $state(s)
    set cmd $state(cmd)
    if {[catch {
	if {[string equal $cmd "GET"]} {
	    puts $s $http(404GET,plain)
	} else {
	    puts $s $http(404,plain)
	    puts $s "\n"
	}
    } err]} {
	Finish $token $err
	return
    }
    Finish $token ok
}

# tinyhttpd::stop --
# 
#       Closes the server socket. This stops new connections to take place,
#       but existing connections are kept alive.
#       
# Arguments:
#       
# Results:

proc ::tinyhttpd::stop { } {    
    variable priv
    variable options
    
    catch {close $priv(sock)}
    LogMsg "Tiny Httpd stopped"
    if {$options(-log)} {
	catch {close $priv(logfd)}
    }
}

# tinyhttpd::anyactive --
# 
# 

proc ::tinyhttpd::anyactive { } {

    return [expr {[llength [getTokenList]] > 1} ? 1 : 0]
}

proc tinyhttpd::getTokenList { } {
    
    set ns [namespace current]
    return [concat  \
      [info vars ${ns}::\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]\[0-9\]\[0-9\]] \
      [info vars ${ns}::\[0-9\]\[0-9\]\[0-9\]\[0-9\]\[0-9\]]]
}

# tinyhttpd::bytestransported --
# 
# 

proc ::tinyhttpd::bytestransported { } {
    variable timing
    
    set totbytes 0
    foreach key [array names timing "*"] {
	incr totbytes [lindex $timing($key) end]
    }
    return $totbytes
}

# tinyhttpd::avergaebytespersec --
# 
# 

proc ::tinyhttpd::avergaebytespersec { } {
    variable timing
    
    set totbytes 0
    set totms 0
    foreach key [array names timing "*"] {
	incr totbytes [lindex $timing($key) end]
	incr totms [expr [lindex $timing($key) end-1] - \
	  [lindex $timing($key) 0]]
    }
    return [expr 1000 * $totbytes / [expr $totms + 1]]
}

# tinyhttpd::cleanup --
# 
# 

proc ::tinyhttpd::cleanup { } {
    variable priv
    variable options
    variable timing
    
    # Not sure precisely what to do here.
    catch {close $priv(sock)}
    if {$options(-log)} {
	catch {close $priv(logfd)}
    }   
    unset -nocomplain timing

    foreach token [getTokenList] {
	Finish $token reset
    }
}

# tinyhttpd::setmimemappings --
#
#       Set the mapping from file suffix to Mime type.
#       Removes old ones.
#
# Arguments:
#       suff2MimeList
#       
# Results:
#       namespace variable 'suffToMimeType' set.

proc ::tinyhttpd::setmimemappings {suff2MimeList} {
    variable suffToMimeType
    
    # Clear out the old, set the new.
    unset -nocomplain suffToMimeType
    array set suffToMimeType $suff2MimeList
}

# tinyhttpd::addmimemappings --
#
#       Adds the mapping from file suffix to Mime type.
#       Keeps or replaces old ones.
#
# Arguments:
#       suff2MimeList
#       
# Results:
#       namespace variable 'suffToMimeType' set.

proc ::tinyhttpd::addmimemappings {suff2MimeList} {
    variable suffToMimeType
    
    array set suffToMimeType $suff2MimeList
}

# tinyhttpd::FormatBytesText --
#
#

proc ::tinyhttpd::FormatBytesText {bytes} {
    
    if {$bytes < 1} {
	return 0
    }
    set log10 [expr log10($bytes)]
    if {$log10 >= 6} {
	set text "[format "%3.1f" [expr $bytes/1000000.0]]M"
    } elseif {$log10>= 3} {
	set text "[format "%3.1f" [expr $bytes/1000.0]]k"
    } else {
	set text $bytes
    }
    return $text
}

# ::tinyhttpd::unixpath --
#
#       Translatates a native path type to a unix style.
#       Windows???
#
# Arguments:
#       path        
#       
# Results:
#       The unix-style path of path.

proc ::tinyhttpd::unixpath {path} {
    
    set isabs [string equal [file pathtype $path] "absolute"]
    set plist [file split $path]
    if {$isabs} {
	set upath /[join [lrange $plist 1 end] /]
    } else {
	set upath [join $plist /]
    }
    return $upath
}

proc ::tinyhttpd::mount {path name} {
    variable mounts
    
    if {![string equal [file pathtype $path] "absolute"]} {
	return -code error "the path must be an absolute path"
    }
    if {[info exists mounts($name)]} {
	return -code error "the mount point \"$name\" already exists"
    }
    set mounts($name) $path
}

proc ::tinyhttpd::unmount {name} {
    variable mounts
    
    unset -nocomplain mounts($name)
}

proc ::tinyhttpd::allmounted { } {
    variable mounts
    
    return [array names mounts]
}

proc ::tinyhttpd::registercgicommand {path cmd} {
    variable cgibin
    
    if {![string equal [file pathtype $path] "relative"]} {
	return -code error "the path must be a relative path"
    }
    if {[info exists cgibin($path)]} {
	return -code error "the cgibin \"$path\" already exists"
    }
    set cgibin($path) $cmd
}

proc ::tinyhttpd::unregistercgicommand {path} {
    variable cgibin
    
    unset -nocomplain cgibin($name)
}

proc ::tinyhttpd::allcgibins { } {
    variable cgibin
    
    return [array names cgibin]
}

proc ::tinyhttpd::Debug {num str} {
    variable this
    
    if {$num <= $this(debug)} {
	puts $str
    }
}

proc ::tinyhttpd::LogMsg {msg} {
    variable priv
    variable options
    
    if {$options(-log)} {
	catch {
	    puts $priv(logfd) "[clock format [clock clicks]]: $msg"
	}
    }
}

#-------------------------------------------------------------------------------

