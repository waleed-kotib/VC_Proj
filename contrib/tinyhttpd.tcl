#  tinyhttpd.tcl --
#  
#       This file is part of the whiteboard application. It implements a tiny
#       http server.
#      
#  Copyright (c) 2002-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: tinyhttpd.tcl,v 1.3 2003-10-19 11:15:00 matben Exp $

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
#      
# ##############################################################################

package require Tcl 8.4
package require uriencode

package provide tinyhttpd 1.0

namespace eval ::tinyhttpd:: {
        
    # Keep track of useful things.
    variable state
    variable httpMsg
    variable html
    variable http
    variable opts
    variable this
    
    # Internal statistics and state for each request.
    variable logstate
    
    switch -- $::tcl_platform(platform) {
	macintosh {
	    set this(sep) :
	}
	windows {
	    set this(sep) {\\}
	}
	unix {
	    set this(sep) /
	}
	default {
	    set this(sep) /
	}
    }
    set this(path) [file dirname [info script]]

    set state(debug) 0
    
    array set httpMsg {
      200 OK
      404 "File not found on server."
    }

    # Use in variables to store typical html return messages instead of files.
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
    set http(headdirlist) \
"HTTP/1.0 200 OK
Server: tinyhttpd/1.0
Last-Modified: %s
Content-Type: text/html"

    set http(404) \
"HTTP/1.0 404 $httpMsg(404)
Content-Type: text/html\n"

    set http(404GET) \
"HTTP/1.0 404 $httpMsg(404)
Content-Type: text/html
Content-Length: [string length $html(404)]\n\n$html(404)"

    set http(200) \
"HTTP/1.0 200 OK
Server: tinyhttpd/1.0
Last-Modified: %s
Content-Type: %s
Content-Length: %s\n"
    
    # These shall be used with 'format' to make html dir listings.
    set html(dirhead) "<HTML><HEAD><TITLE> %s </TITLE></HEAD>\n\
      <BODY bgcolor=#FFFFFF>\n\n\
      <!-- HTML generated from Tcl code that was my\
      Saturday afternoon hack. By Mats Bengtsson -->\n\n\
      <TABLE nowrap border=0 cellpadding=2>\n\
      <TR>\n\
      \t<TD align=center nowrap height=19> %s objects </TD>\n\
      \t<TD align=left nowrap><B> Name </B></TD>\n\
      \t<TD align=right nowrap> Size </TD>\n\
      \t<TD align=left nowrap></TD>\n\
      \t<TD align=left nowrap> Type </TD>\n\
      \t<TD align=left nowrap> Date </TD>\n\
      </TR>\n\
      <TR>\n\
      \t<TD colspan=6 height=10><HR></TD>\n\
      </TR>\n"
    set html(dirline) "<TR>\n\
      \t<TD align=center nowrap height=17><a href=\"%s\">\
      <img border=0 width=16 height=16 src=\"%s\"></a></TD>\n\
      \t<TD align=left nowrap><a href=\"%s\"> %s </a></TD>\n\
      \t<TD align=right nowrap> - </TD>\n\
      \t<TD align=left nowrap></TD>\n\
      \t<TD align=left nowrap> Directory </TD>\n\
      \t<TD align=left nowrap> %s </TD>\n</TR>\n"
    set html(fileline) "<TR>\n\
      \t<TD align=center nowrap height=17><a href=\"%s\">\
      <img border=0 width=16 height=16 src=\"%s\"></a></TD>\n\
      \t<TD align=left nowrap><a href=\"%s\"> %s </a></TD>\n\
      \t<TD align=right nowrap> %s </TD>\n\
      \t<TD align=left nowrap></TD>\n\
      \t<TD align=left nowrap> %s </TD>\n\
      \t<TD align=left nowrap> %s </TD>\n</TR>\n"
    set html(dirbottom) "</TABLE>\n<BR>\n<BR>\n</BODY>\n</HTML>\n"
    
    # Default mapping from file suffix to Mime type.
    variable suffToMimeType
    array set suffToMimeType {
      .txt      text/plain
      .html     text/html
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
      .bin      application/x-stuffit
      .zip      application/x-zip
      .sit      application/x-stuffit
      .gz       application/x-zip
      .tcl      application/x-tcl
    }

    variable path_ {[^ ]*}    
    variable up_ {../}
    variable chunk 8192
}

# tinyhttpd::start --
#
#       Start the http server.
#
# Arguments:
#       args:
#           -defaultindexfile     index.html
#	    -directorylisting     1
#	    -log                  0
#	    -logfile              httpdlog.txt
#	    -myaddr               ""
#	    -port                 80
#       
# Results:
#       server socket opened.

proc ::tinyhttpd::start {args} {
    variable opts
    variable state
    variable this
        
    # Any configuration options. Start with defaults, overwrite with args.
    array set opts {
	-defaultindexfile     index.html
	-directorylisting     1
	-log                  0
	-logfile              httpdlog.txt
	-myaddr               ""
	-port                 80
    }
    set opts(-rootdirectory) $this(path)
    array set opts $args
    if {[file pathtype $opts(-rootdirectory)] != "absolute"} {
	return -code error "the path must be an absolute path"
    }
    set servopts ""
    if {$opts(-myaddr) != ""} {
	set servopts [list -myaddr $opts(-myaddr)]
    }
    if {[catch {
	eval {socket -server [namespace current]::NewChannel} $servopts \
	  $opts(-port)} msg]} {
	return -code error "Couldn't start server socket: $msg."
    }	
    set state(sock) $msg

    # Log file
    if {$opts(-log)} {
	if {[catch {open $opts(-logfile) a} fd]} {
	    return -code error "Failed open the log file: $opts(-logfile): $fd"
	}
	set state(logfd) $fd
	fconfigure $state(logfd) -buffering none
    }
        
    # Keep the absolute path as a list which is helpful when adding paths.
    # We typically get {{} root Tcl coccinella} on unix since first '/' is kept.
    set state(basePathL) {}
    foreach elem [file split $opts(-rootdirectory)] {
	lappend state(basePathL) [string trim $elem "/:\\"]
    }
    ::tinyhttpd::LogMsg "Tiny Httpd started"

    return ""
}

# tinyhttpd::NewChannel --
# 
#       Callback procedure for the server socket. Gets called whenever a new
#       client connects to the server socket.
#
# Arguments:
#       s    the newly opened server side socket.
#       ip         clients ip number.
#       port       clients port number.
#       
# Results:
#       Registers 'HandleRequest' as a callback for each new line.

proc ::tinyhttpd::NewChannel {s ip port} {
    variable logstate

    ::tinyhttpd::Debug 2 "NewChannel:: s=$s, ip=$ip, port=$port"
    ::tinyhttpd::Debug 3 "\tfconfigure=[fconfigure $s]"
    
    set logstate($s,ip) $ip
    set logstate($s,state) "connected"
    set logstate($s,status) ""
    
    # Everything should be done with 'fileevent'.
    fconfigure $s -blocking 0
    fconfigure $s -buffering line
    fileevent $s readable [list [namespace current]::HandleRequest $s $ip $port]
}

# tinyhttpd::HandleRequest --
#
#       Initiates a GET or HEAD request. A sequence of callbacks completes it.
#       
# Arguments:
#       s    the newly opened server side socket.
#       ip         clients ip number.
#       port       clients port number.
#       
# Results:
#       new fileevent procedure registered.

proc ::tinyhttpd::HandleRequest {s ip port} {    
    variable state
    variable path_
    variable logstate

    ::tinyhttpd::Debug 2 "HandleRequest:: [clock clicks], $s $ip $port"
    set logstate($s,state) "reading"

    # If client closes socket.
    if {[eof $s]} {
	Finish $s "eof"
	::tinyhttpd::Debug 2 "  HandleRequest:: eof s=$s"

    } elseif {[gets $s line] != -1} {
	::tinyhttpd::Debug 2 "  HandleRequest:: line=$line"

	# We only implement the GET and HEAD operations.
	if {[regexp -nocase "^(GET|HEAD) +($path_) +HTTP" $line junk cmd path]} {    
	    ::tinyhttpd::LogMsg "$cmd: $ip $path"
	    set logstate($s,cmd) $cmd
	    set logstate($s,path) $path
	    
	    # Set fileevent to read the sequence of 'key: value' lines.
	    fileevent $s readable   \
	      [list [namespace current]::ReadKeyValueLine $s $ip $cmd $path]
	} else {
	    ::tinyhttpd::LogMsg "$ip, unknown request: $line"
	}
    } else {
	::tinyhttpd::LogMsg "$ip, failed (eof? or blocked?)"
    }
}
	    
# tinyhttpd::ReadKeyValueLine --
#
#       Reads and processes a 'key: value' line, reschedules itself if not blank
#       line, else calls 'RespondToClient' to initiate a file transfer.
#
# Arguments:
#       s    the newly opened server side socket.
#       ip         clients ip number.
#       cmd        "GET" or "HEAD".
#       inPath     the file path relative the 'rootDir'. Unix style.
#       
# Results:

proc ::tinyhttpd::ReadKeyValueLine {s ip cmd inPath} {    
    variable state
    
    if {[eof $s]} {
	Finish $s "eof"
	::tinyhttpd::Debug 2 "ReadKeyValueLine:: eof s"
	return
    }
    if {[fblocked $s]} {
	::tinyhttpd::Debug 2 "ReadKeyValueLine:: blocked s"
	return
    }
    set nbytes [gets $s line]
    ::tinyhttpd::Debug 3 "ReadKeyValueLine:: inPath=$inPath, nbytes=$nbytes, line=$line"
    
    if {$nbytes < 0} {
	#close $s
	return
    }
    
    # Perhaps we should keep track of the clients key-value pairs?    
    if {($nbytes == 0) || [regexp {^[ \n]+$} $line]}  {
	
	# First empty line, set up file transfer.
	fileevent $s readable {}
	RespondToClient $s $ip $cmd $inPath
    }
}

# tinyhttpd::RespondToClient --
#
#       Responds the client with the HTTP protocol, and then a number of 
#       'key: value' lines. File transfer initiated.
#       
# Arguments:
#       s    the newly opened server side socket.
#       ip         clients ip number.
#       cmd        "GET" or "HEAD".
#       inPath     the file path relative the 'rootDir'. Unix style, uri encoded
#       
# Results:
#       fcopy called.

proc ::tinyhttpd::RespondToClient {s ip cmd inPath} {
    global  this tcl_platform
    
    variable opts
    variable state
    variable suffToMimeType
    variable httpMsg
    variable http
    variable chunk
    variable logstate
    
    ::tinyhttpd::Debug 2 "RespondToClient:: $s $ip $cmd $inPath"
            
    set basePathL $state(basePathL)
    
    # Here we should rely on our 'tinyfileutils' package instead!!!!
    # Or 'file normalize' from 8.4!

    # If any up dir (../), find how many. Skip leading / .
    set path [string trimleft $inPath /]
    set numUp [regsub -all {\.\./} $path {} stripPath]
    set stripPathL [file split $stripPath]
    
    # Delete the same number of elements from the end of the base path
    # as there are up dirs in the relative path.
    if {$numUp > 0} {
	set iend [expr [llength $basePathL] - 1]
	set newBasePathL [lreplace $basePathL [expr $iend - $numUp + 1] $iend]
    } else {
	set newBasePathL $basePathL
    }
    ::tinyhttpd::Debug 4 "\tpath=$path\n\tnumUp=$numUp\n\tstripPathL=$stripPathL\n\tnewBasePathL=$newBasePathL"
    
    # Add the new base path with the stripped incoming path.
    # On Windows we need special treatment of the "C:/" type drivers.
    if {[string equal $tcl_platform(platform) "windows"]} {
	set vol "[lindex $newBasePathL 0]:/"
    	set localPath   \
	  "${vol}[join [lrange [concat $newBasePathL $stripPathL] 1 end] "/"]"
    } elseif {[string equal $tcl_platform(platform) "macintosh"]} {
        set localPath "[join [concat $newBasePathL $stripPathL] ":"]"
    } else {
        set localPath [join [concat $newBasePathL $stripPathL] "/"]
    }
    
    # Decode file path.
    set localPath [uriencode::decodefile $localPath]
    
    ::tinyhttpd::Debug 2 "  RespondToClient:: localPath=$localPath"
    
    # If no actual file given then search for the '-defaultindexfile',
    # or if no one, possibly return directory listing.
    
    if {[file isdirectory $localPath]} {
	set defFile [file join $localPath $opts(-defaultindexfile)]
	if {[file exists $defFile]} {
	    set localPath $defFile
	} elseif {$opts(-directorylisting)} {
	    
	    # No default html file exists, return directory listing.
	    set modTime [clock format [file mtime $localPath]  \
	      -format "%a, %d %b %Y %H:%M:%S GMT" -gmt 1]
	    puts $s [format $http(headdirlist) $modTime]

	    if {[string equal $cmd "GET"]} {
		set html [BuildHtmlDirectoryListing $opts(-rootdirectory) \
		  $inPath httpd]
		puts $s "Content-Length: [string length $html]"
		puts $s "\n"
		puts $s $html
	    } else {
		puts $s "\n"
	    }
	    Finish $s ok
	    ::tinyhttpd::Debug 2 "  RespondToClient:: No default html file exists, return directory listing."
	    return
	} else {
	    if {[string equal $cmd "GET"]} {
		puts $s $http(404GET)
	    } else {
		puts $s $http(404)
	    }
	    Finish $s ok
	    return
	}
    }
    set fext [string tolower [file extension $localPath]]
    if {[info exists suffToMimeType($fext)]} {
	set mime $suffToMimeType($fext)
    } else {
	set mime "application/octet-stream"
    }
    
    # Check that the file is there and opens correctly.
    if {$localPath == "" || [catch {open $localPath r} fid]}  {
	if {[string equal $cmd "GET"]} {
	    puts $s $http(404GET)
	} else {
	    puts $s $http(404)
	}
	Finish $s ok
	::tinyhttpd::Debug 2 "  RespondToClient:: open $localPath failed"
	return
    } else  {
	
	# Put stuff.
	set size [file size $localPath]
	set logstate($s,size) $size
	set modTime [clock format [file mtime $localPath]  \
	  -format "%a, %d %b %Y %H:%M:%S GMT" -gmt 1]
	set data [format $http(200) $modTime $mime $size]
	puts $s $data
	flush $s

	::tinyhttpd::Debug 3 "  RespondToClient::\n'$data'"
    }
    if {[string equal $cmd "HEAD"]}  {
	Finish $s ok $fid
	return
    }
    
    # If binary data.
    if {![string match "text/*" $mime]} {
	fconfigure $fid -translation binary
	fconfigure $s -translation binary
    }
    flush $s
    
    # ??????????????
    update
    
    # Background copy. Be sure to switch off all fileevents on channel.
    fileevent $s readable {}
    fileevent $s writable {}
    fconfigure $s -buffering full
    set total 0
    set logstate($s,timing) [list [clock clicks -milliseconds] 0]
    fcopy $fid $s -size $chunk -command  \
      [list [namespace current]::CopyMore $fid $s $total]
}

# tinyhttpd::CopyMore --
# 
#       The callback procedure for fcopy when copying from a disk file
#       to the socket. 
#       
# Arguments:
#       in        the file id.
#       out       the socket.
#       total     total number of bytes transferred.
#       bytes     number of bytes in this chunk.
#       error     any error.
#       
# Results:
#       possibly reschedules itself.

proc ::tinyhttpd::CopyMore {in out total bytes {error {}}} {    
    variable state
    variable chunk
    variable logstate
    
    ::tinyhttpd::Debug 4 "CopyMore:: out=$out, total=$total, bytes=$bytes"
    
    if {[eof $out]} {
	::tinyhttpd::Debug 2 "  CopyMore:: ended prematurely because of eof on out"
	Finish $out eof $in
	return
    }
    incr total $bytes
    lappend logstate($out,timing) [clock clicks -milliseconds] $total

    if {([string length $error] > 0) || [eof $in]} {
	if {[string length $error] > 0} {
	    set status "error"
	} else {
	    set status "ok"
	}
	Finish $out $status $in
    } else {
	fcopy $in $out -size $chunk -command  \
	  [list [namespace current]::CopyMore $in $out $total]
    }
}


proc ::tinyhttpd::Finish {s status {fd ""}} {
    variable logstate
    
    set logstate($s,status) $status
    set logstate($s,state) "finished"
    catch {close $s}
    if {$fd != ""} {
	catch {close $fd}   
    }
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
    variable state
    variable opts
    
    catch {close $state(sock)}
    if {$opts(-log)} {
	::tinyhttpd::LogMsg "Tiny Httpd stopped"
	catch {close $state(logfd)}
    }
}

# tinyhttpd::anyactive --
# 
# 

proc ::tinyhttpd::anyactive { } {
    variable logstate
    
    set ans 0
    foreach key [array names logstate "*,state"] {
	if {![string equal $logstate($key) "finished"]} {
	    set ans 1
	    break
	}
    }
    return $ans
}

# tinyhttpd::bytestransported --
# 
# 

proc ::tinyhttpd::bytestransported { } {
    variable logstate
    
    set totbytes 0
    foreach key [array names logstate "*,timing"] {
	incr totbytes [lindex $logstate($key) end]
    }
    return $totbytes
}

# tinyhttpd::avergaebytespersec --
# 
# 

proc ::tinyhttpd::avergaebytespersec { } {
    variable logstate
    
    set totbytes 0
    set totms 0
    foreach key [array names logstate "*,timing"] {
	incr totbytes [lindex $logstate($key) end]
	incr totbytes [expr [lindex $logstate($key) end-1] \
	  - [lindex $logstate($key) 0]]
    }
    return [expr 1000 * $totbytes / [expr $totms + 1]]
}

# tinyhttpd::cleanup --
# 
# 

proc ::tinyhttpd::cleanup { } {
    variable logstate
    variable state
    variable suffToMimeType
    
    catch {unset state}
    catch {unset logstate}
    catch {unset suffToMimeType}
    return ""
}

# tinyhttpd::BuildHtmlDirectoryListing --
#
#
#       relPath        Unix style path relative 'rootDir'.
#       rootDir        The base or root directory of this http server.
#                      May be in a native style.
#       httpdRelPath
#       
# Results:
#       A complete html page describing the directory.

proc ::tinyhttpd::BuildHtmlDirectoryListing {rootDir relPath httpdRelPath} {    
    variable state
    variable this
    variable html
    
    ::tinyhttpd::Debug 2 "----BuildHtmlDirectoryListing: rootDir=$rootDir,\
      relPath=$relPath, httpdRelPath=$httpdRelPath"
    
    # Check paths?
    if {$httpdRelPath == "/"} {
	set httpdRelPath .
    }
    
    # Make unix style paths for the icon files.
    set httpdRelPathList [split $httpdRelPath $this(sep)]
    set httpdRelPath [join $httpdRelPathList /]
    set folderIconPath "/$httpdRelPath/macfoldericon.gif"
    set fileIconPath "/$httpdRelPath/textfileicon.gif"
    
    # Add the absolute 'rootDir' path with the relative 'relPath' to form the
    # absolute path of the directory.
    set relPath [string trimleft $relPath /]
    set fullPath [AddAbsolutePathWithRelative $rootDir $relPath]
    set nativePath [file nativename $fullPath]
    
    ::tinyhttpd::Debug 3 "fullPath=$fullPath\n\tnativePath=$nativePath"
    
    # Set the current directory to our path (good?).
    set oldPath [pwd]
    cd $fullPath
    
    # Start by finding the directory content. 
    # glob needs the ending directory separator.
    
    set thisDir [string trim [lindex [file split $fullPath] end] "/:\\"]
    set allFiles [glob -nocomplain *]
    set totN [llength $allFiles]
    
    # Build the complete html page dynamically.    
    set htmlStuff [format $html(dirhead) $thisDir $totN]
    
    # Loop over all files and directories in our directory.
    foreach fileOrDir $allFiles {
	
	if {[catch {clock format [file mtime $fileOrDir]   \
	  -format "%a %d %b %Y, %H.%M"} res]} {
	    set dateAndTime --
	} else {
	    set dateAndTime $res
	}
	if {$relPath == ""} {
	    set link "/${fileOrDir}"
	} else {
	    set link "/${relPath}${fileOrDir}"
	}
	set link [uriencode::quotepath $link]
	
	# Is file or directory?
	if {[file isdirectory $fileOrDir]} {
	    append link /
	    append htmlStuff [format $html(dirline) $link $folderIconPath \
	      $link $fileOrDir $dateAndTime]
	} else {
	    if {[catch {file size $fileOrDir} res]} {
		set bytes 0
	    } else {
		set bytes $res
	    }
	    set formBytes [FormatBytesText $bytes]
	    append htmlStuff [format $html(fileline) $link $fileIconPath \
	      $link $fileOrDir $formBytes $fileOrDir $dateAndTime]
	}
    }
    
    # And the end.
    append htmlStuff $html(dirbottom)
    
    # Reset original working dir.
    cd $oldPath
    return $htmlStuff
}    

# tinyhttpd::AddAbsolutePathWithRelativeUnix --
#
#       Adds a relative path to an absolute path. Must be unix style paths.
#       Any "../" prepending the relative path means up one dir level.
#       This is supposed to be a lightweight 'AddAbsolutePathWithRelative' 
#       for unix style paths only.
#
# Arguments:
#       absPath       the path to start with.. Unix style!
#       relPath       the relative path that should be added. Unix style!
#       
# Results:
#       The resulting absolute path in unix style.

proc ::tinyhttpd::AddAbsolutePathWithRelativeUnix {absPath relPath} {
    
    # Construct the absolute path to the file. We need to take care of any
    # up directories "../".
    
    set absPathL [split [string trim $absPath /] /]
    
    # If any up dir (../), find how many.
    set numUp [regsub -all {\.\./} $relPath {} stripPath]
    set stripPathL [split [string trim $stripPath /] /]
    
    # Delete the same number of elements from the end of the base path
    # as there are up dirs in the relative path.
    if {$numUp > 0} {
	set iend [expr [llength $absPathL] - 1]
	set newAbsPathL [lreplace $absPathL [expr $iend - $numUp + 1] $iend]
    } else {
	set newAbsPathL $absPathL
    }
    return "/[join [concat $newAbsPathL $stripPathL] "/"]"
}

# AddAbsolutePathWithRelative ---
#
#       Adds the second, relative path, to the first, absolute path.
#       IMPORTANT: this should be just a copy of the procedure
#       with the same name in the 'SomeUtils.tcl' file.
#    
# Arguments:
#       absPath        an absolute path which is the "original" path.
#       toPath         a relative path which should be added.
#       
# Results:
#       The absolute path by adding 'absPath' with 'relPath'.

proc ::tinyhttpd::AddAbsolutePathWithRelative {absPath relPath}  {
    global  this tcl_platform
    
    # For 'tinyhttpd.tcl'.
    variable state

    # Be sure to strip off any filename.
    set absPath [getdirname $absPath]
    if {[file pathtype $absPath] != "absolute"} {
	error "first path must be an absolute path"
    } elseif {[file pathtype $relPath] != "relative"} {
	error "second path must be a relative path"
    }

    # This is the method to reach platform independence.
    # We must be sure that there are no path separators left.
    
    set absP {}
    foreach elem [file split $absPath] {
	lappend absP [string trim $elem "/:\\"]
    }
    
    # If any up dir (../ ::  ), find how many. Only unix style.
    set numUp [regsub -all {\.\./} $relPath {} newRelPath]
   
    # Delete the same number of elements from the end of the absolute path
    # as there are up dirs in the relative path.
    
    if {$numUp > 0} {
	set iend [expr [llength $absP] - 1]
	set upAbsP [lreplace $absP [expr $iend - $numUp + 1] $iend]
    } else {
	set upAbsP $absP
    }
    set relP {}
    foreach elem [file split $newRelPath] {
	lappend relP [string trim $elem "/:\\"]
    }
    set completePath "$upAbsP $relP"

    # On Windows we need special treatment of the "C:/" type drivers.
    if {$tcl_platform(platform) == "windows"} {
    	set finalAbsPath   \
	    "[lindex $completePath 0]:/[join [lrange $completePath 1 end] "/"]"
    } else {
        set finalAbsPath "/[join $completePath "/"]"
    }
    return $finalAbsPath
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
    catch {unset suffToMimeType}
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

proc ::tinyhttpd::Debug {num str} {
    variable state
    
    if {$num <= $state(debug)} {
	puts $str
    }
}

proc ::tinyhttpd::LogMsg {msg} {
    variable opts
    
    if {$opts(-log)} {
	catch {
	    puts $state(logfd) "[clock format [clock clicks]]: $msg"
	}
    }
}

#-------------------------------------------------------------------------------

