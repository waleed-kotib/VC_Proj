#  GetFile.tcl ---
#  
#      This file is part of the whiteboard application. It contains a number
#      of procedures for performing a get operation from the network to disk.
#      
#  Copyright (c) 1999-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#
# $Id: GetFile.tcl,v 1.3 2003-01-30 17:33:57 matben Exp $
# 
#### LEGEND ####################################################################
#
#  locals(all)          lists of all sockets in work (open)
#  locals($s,ip)        ip number
#  locals($s,dest)      our file descriptor to the disk file
#  locals($s,filePathRem) the file name to get. It must be a pathname relative 
#                       the servers base directory including any ../ if up dir. 
#                       Keep it a unix path style.
#  locals($s,fileTail)  the tail of the file name
#  locals($s,dstPath)   the file path on our local disk
#  locals($s,optList)   list of 'key: value' pairs
#  locals($s,totBytes)  the total size of the file
#  locals($s,sumBytes)  the size transferred so far
#  locals($s,timing)    store timing data in a list with each element a 
#                       list {clicks sumBytes}.
#  locals($s,lastProg)  the clock clicks when the progress was last updated
#  locals($s,killId)    kill id for our timeout schedule event
#  locals($s,cmd)       the registered callback procedure
#  locals($s,mime)      the files MIME type
#  locals($s,cancel)    boolean, true of user pressed cancel button
#
#  CallbackProc {sock ip fileTail totBytes sumBytes msg {error {}}} 
#
#### USAGE #####################################################################
#
#
#
# Note: be sure to call ShutDown before doing callback since callback may call
#       update that triggers a large number of fileevents.

namespace eval ::GetFile:: {
    
    # Exported routines.
    namespace export GetFileFromServer GetFileFromClient
    
    # Internal vars only.
    variable locals
    set locals(all) {}
}

# GetFile::GetFileFromServer --
#
#       Initializes a get operation to get a file from a remote server.
#       Thus, we open a fresh socket to a server. The initiative for this
#       get operation is solely ours.
#       Open new temporary socket only for this get operation.
#       
# Arguments:
#       ip        the ip number of the remote server.
#       port
#       filePathRemote  the file name to get. It must be a pathname relative the
#                 servers base directory including any ../ if up dir. 
#                 Keep it a unix path style.
#       cmd       callback command procedure
#       optList   (optional) is a list of key-value pairs that contains 
#                 additional information, typically if called as a response to
#                 a PUT NEW request.
#                 
# Results:
#       socket opened async.

proc ::GetFile::GetFileFromServer {ip port filePathRemote cmd {optList {}}} {
    global  ipNumTo
    
    variable locals
    
    Debug 2 "+  ::GetFile::GetFileFromServer: ip=$ip, filePathRemote=$filePathRemote"
    
    # We should already here figure out if we actually need to open a fresh
    # connection: http transport, mime type not supported...

    array set arrayOpts $optList
    
    #  CallbackProc {ip fileTail totBytes sumBytes msg {error {}}} 
    set msg "Contacting client $ipNumTo(name,$ip). Waiting for response..."
    $cmd {} $ip [file tail $filePathRemote] 10000000 0 $msg
    Debug 2 "+  msg=$msg"
    
    # The actual socket is opened.
    # In case something went wrong during socket open.
    if {[catch {socket -async $ip $port} s]} {
	ShutDown $s
	set msg "Failed when trying to connect to $ipNumTo(name,$ip). $s"
	$cmd {} $ip [file tail $filePathRemote] 10000000 0 $msg $msg
	Cleanup $s
	return
    }    
    
    # Save to our locals so far.
    lappend locals(all) $s
    set locals($s,ip) $ip
    set locals($s,filePathRem) $filePathRemote
    set locals($s,fileTail) [file tail $filePathRemote]
    set locals($s,optList) $optList
    set locals($s,cmd) $cmd
    set locals($s,sumBytes) 0
    set locals($s,cancel) 0
    
    if {[info exists arrayOpts(Content-Type:)]} {
	set locals($s,mime) $arrayOpts(Content-Type:)
    } else {
	set locals($s,mime) "application/octet-stream"
    }
	
    # Set in nonblocking mode and register the next event handler.
    fconfigure $s -blocking 0
    fconfigure $s -buffering line
            
    # Schedule timeout event.
    ScheduleKiller $s
    
    # If open socket in async mode, need to wait for fileevent.
    fileevent $s writable [list [namespace current]::SocketOpen $s]
}

# GetFile::SocketOpen --
#
#       Is called from previous procedure when the socket opens. Respond to
#       server and schedule reading server's response.
#       
# Arguments:
#       s         the channel socket.
#                 
# Results:
#       sends "GET: fileName optList" to remote server, waits for response.

proc ::GetFile::SocketOpen {s} {
    global  ipNumTo noErr tclwbProtMsg
    
    variable locals

    Debug 2 "+    SocketOpen::  s=$s"

    # Be sure to switch off any fileevents from previous procedures async open.
    fileevent $s writable {}
    
    # Save short names.
    set filePathRemote $locals($s,filePathRem)
    set ip $locals($s,ip)
    set optList $locals($s,optList)
    set fileTail $locals($s,fileTail)
    if {[eof $s]} {
	ShutDown $s
	set msg "Failed open socket for $fileTail" 
	$locals($s,cmd) $s $ip $fileTail 10000000 0 $msg $msg
	Cleanup $s
	return
    }
    
    # In some situations we open a new socket to the server just to say that for
    # one reason or the other, we don't want to receive this file.
    # Using the 'ReflectorServer', this is the way to reject a file transfer.
    # Check receiving status, if OK returns file descriptor.
    
    set stat [::GetFile::Prepare $s]
    if {$stat != $noErr} {
	puts  $s "GET: $filePathRemote Error-Code: $stat $optList"
 	ShutDown $s
	set msg "We respond to $ipNumTo(name,$ip): $tclwbProtMsg($stat) ($stat)" 
	$locals($s,cmd) $s $ip $fileTail 10000000 0 $msg
	Cleanup $s
	return
    } 
    
    # We are sure it is a valid (open) file.
    set dest $locals($s,dest)
    
    # Schedule timeout event.
    ScheduleKiller $s
    
    # Set up event handler to wait for server response.
    fileevent $s readable [list [namespace current]::ServerResponse $s]
    set msg "Client contacted: $ipNumTo(name,$ip); negotiating..."
    $locals($s,cmd) $s $ip $locals($s,fileTail) 10000000 0 $msg

    # This is the actual instruction to the remote server what to expect
    
    puts  $s "GET: $filePathRemote $optList"
    flush $s    

    Debug 2  "+    GET: $filePathRemote"
}

# GetFile::ServerResponse --
#
#       Read the first line of the servers response and prepare to get the next
#       one if this was OK.
#       The protocol is typically:
#           TCLWB/1.0 200 OK
#           key1: value1 key2: value2 ...
#           and the data comes here...
#
# Arguments:
#       s         the channel socket.
#                 
# Results:
#       New filevent to read optList.

proc ::GetFile::ServerResponse {s} {
    global  tclwbProtMsg ipNumTo
    
    variable locals

    Debug 2 "+      ServerResponse::"
    set int_ {[0-9]+}
    set any_ {.+}

    # Save short names.
    set ip $locals($s,ip)
    
    if {[eof $s]} {
	ShutDown $s
	set msg {Socket closed before reading server response}
	$locals($s,cmd) $s $ip $locals($s,fileTail) 10000000 0 $msg $msg
	Cleanup $s
	return
    } elseif {[gets $s line] == -1} {

	# Get server response.
 	ShutDown $s
	set msg "Error reading server response from $ipNumTo(name,$ip)"
	$locals($s,cmd) $s $ip $locals($s,fileTail) 10000000 0 $msg $msg
	Cleanup $s
	return
    }
    Debug 2 "+      ::GetFile::ServerResponse line=$line"
	
    # Parse the servers repsonse. Catch problems.
    
    if {![regexp "^TCLWB/(${int_}\.${int_}) +($int_) +($any_)"  $line match  \
      version respCode msg]} {
 	ShutDown $s
	set msg "The server at $ipNumTo(name,$ip) didn't respond with a\
	  well formed protocol"
	$locals($s,cmd) $s $ip $locals($s,fileTail) 10000000 0 $msg $msg
	Cleanup $s
	return
    } elseif {![info exists tclwbProtMsg($respCode)]} {
 	ShutDown $s
	set msg "The server at $ipNumTo(name,$ip) responded with an unkown code."
	$locals($s,cmd) $s $ip $locals($s,fileTail) 10000000 0 $msg $msg
	Cleanup $s
	return
    } elseif {$respCode != 200} {
 	ShutDown $s
	set msg "$tclwbProtMsg($respCode)"
	$locals($s,cmd) $s $ip $locals($s,fileTail) 10000000 0 $msg $msg
	Cleanup $s
	return
    } 
    
    set msg "Client at $ipNumTo(name,$ip) responded."
    $locals($s,cmd) $s $ip $locals($s,fileTail) 10000000 0 $msg
    Debug 2 "+      ServerResponse:: msg=$msg"
    
    # Schedule timeout event.
    ScheduleKiller $s
    
    # Set up event handler to wait for servers next line.
    fileevent $s readable [list [namespace current]::ReadOptLine $s]
}

# GetFile::ReadOptLine --
#
#       Read the first line of the servers response and prepare to get the next
#       one if this was OK.
#       The protocol is typically:
#           TCLWB/1.0 200 OK
#           key1: value1 key2: value2 ...
#           and the data comes here...
#
# Arguments:
#       s         the channel socket.
#                 
# Results:
#       none.

proc ::GetFile::ReadOptLine {s} {
    global  chunkSize tclwbProtMsg ipNumTo

    variable locals
    
    Debug 2 "+      ReadOptLine::"
    
    # Save short names.
    set ip $locals($s,ip)
    set dest $locals($s,dest)
    set optList $locals($s,optList)
    set fileTail $locals($s,fileTail)
    
    catch {after cancel $locals($s,killId)}
    if {[eof $s]} {
	ShutDown $s
	set msg {Socket closed before reading server response}
	$locals($s,cmd) $s $ip $fileTail 10000000 0 $msg $msg
	Cleanup $s
	return
    } elseif {[gets $s readOptList] == -1} {

	# Get next line that contains the 'optList'.
	# If given an 'optList' as an argument...
 	ShutDown $s
	set msg "Error reading server response from $ipNumTo(name,$ip)"
	$locals($s,cmd) $s $ip $fileTail 10000000 0 $msg $msg
	Cleanup $s
	return
    }
    
    # Parse the 'optList', translate to an array first.
    array set arrayOfOpts $optList
    
    # Overwrite 'optList' with an updated 'readOptList'.
    array set arrayOfOpts $readOptList
    set locals($s,optList) [array get arrayOfOpts]
    
    # Need better error handling here.....................
    
    if {[info exists arrayOfOpts(size:)]} {
	set totBytes $arrayOfOpts(size:)
	set locals($s,totBytes) $arrayOfOpts(size:)
    } else {
	puts "Error:: size not given."
	return
    }
    set locals($s,lastProg) [clock clicks -milliseconds]
                
    # Be sure to switch off any fileevent before fcopy.
    fileevent $s readable {}
    fileevent $s writable {}
    Debug 2 "+      ReadOptLine:: start transfer"

    # ...and finally, start transfer.
    if {[catch {
	fcopy $s $dest -size $chunkSize -command  \
	  [list [namespace current]::Callback $s]
    }]} {	
	ShutDown $s
	set msg {We recieved a network error while trying to transfer file} 
	$locals($s,cmd) $s $ip $fileTail 10000000 0 $msg $msg	
	Cleanup $s
    }
}

# GetFile::GetFileFromClient --
#
#       When a client makes a put request to a server.
#       Typically called after a "PUT" line has been received by 'TheServer'
#       on a newly opened socket for this purpose.
#       So the socket is already open for us. The initiative for this get
#       operation is solely the remote client's.
#       
# Arguments:
#       ip        the ip number of the remote client.
#       s         the channel socket.
#       fileTail  the file name to get. 
#       cmd       callback procedure
#       optList   is a list of 'key: value' pairs that contains additional 
#                 information.
#                 
# Results:
#       none.

proc ::GetFile::GetFileFromClient {ip s fileTail cmd optList} {
    global  chunkSize tclwbProtMsg noErr
    
    variable locals

    Debug 2 ">  GetFileFromClient:: fileTail=$fileTail, optList='$optList'"
        
    # Parse the string 'optList' as key value pairs.
    # Here we could use, for instance, the MIME type, but we
    # only extract the file size for convenience in fcopy callbacks.
    array set putArrOpts $optList
    
    # Save to our locals so far.
    lappend locals(all) $s
    set locals($s,ip) $ip
    set locals($s,fileTail) $fileTail
    set locals($s,optList) $optList
    set locals($s,cmd) $cmd
    set locals($s,sumBytes) 0
    set locals($s,cancel) 0
    set locals($s,lastProg) [clock clicks -milliseconds]

    if {[info exists putArrOpts(size:)]} {
	set totBytes $putArrOpts(size:)
	set locals($s,totBytes) $putArrOpts(size:)
    }
    if {[info exists putArrOpts(Content-Type:)]} {
	set locals($s,mime) $putArrOpts(Content-Type:)
    } else {
	set locals($s,mime) "application/octet-stream"
    }    
    
    # Check how/if to be received.
    set stat [::GetFile::Prepare $s]
    Debug 2 ">  GetFileFromClient:: Prepare=$stat"

    if {$stat != $noErr} {
	puts $s "TCLWB/1.0 $stat $tclwbProtMsg($stat)"
	flush $s
	catch {close $s}
	return
    } 
    
    # We are sure it is a valid (open) file.
    set dest $locals($s,dest)
    
    # Here we answer that it's ok to get on with the file transfer.
    puts $s "TCLWB/1.0 200 $tclwbProtMsg(200)"
    flush $s
    fconfigure $s -blocking 0    
    
    # Do the actual transfer through fcopy. 'optList's list
    # structure must be respected.
    Debug 2 ">  GetFileFromClient:: fcopy, registered handler"
    
    if {[catch {
	fcopy $s $dest -size $chunkSize -command  \
	  [list [namespace current]::Callback $s]
    }]} {	
	ShutDown $s
	set msg {We recieved a network error while trying to transfer file} 
	$locals($s,cmd) $s $ip $fileTail 10000000 0 $msg $msg	
	Cleanup $s
    }
}

# GetFile::Prepare --
#
#       Checks if the file 'fileTail' should be received. 
#       Rejects if: 
#            1): mime type not supported, 
#            2): user rejects it
#            3): if cached, 
#            4): is supported via 'url' instead.
#            5): local disk file cannot be opened.
#       Configures channel according to file's MIME type.
#
# Arguments:
#       s           the channel socket.
#                 
# Results:
#       a three number error code indicating the type of error, or noErr (0). 
#       Diskfile opened.

proc ::GetFile::Prepare {s} {
    global  prefs noErr plugin mimeTypeDoWhat this mimeTypeIsText
    
    variable locals

    Debug 2 ">   Prepare::"
    
    # Use short names.
    set optList $locals($s,optList)
    array set optArr $optList
    set fileTail $locals($s,fileTail)

    # Unquote the disallowed characters according to the RFC for URN scheme.
    # ref: RFC2141 sec2.2
    set dstPath [file join $prefs(incomingFilePath)  \
      [::uriencode::decodefile $fileTail]]
    set locals($s,dstPath) $dstPath
    
    # Get the MIME type.    
    if {[info exists locals($s,mime)]} {
	set mime $locals($s,mime)
    } else {
	set mime "application/octet-stream"
    }
    regexp {^([^/]+)/.*} $mime match mimeBase
	
    if {![info exists mimeTypeDoWhat($mime)]} {
	return 321
    }
    
    switch -- $mimeTypeDoWhat($mime) {
	reject - unavailable {

	    # 1: Check if the MIME type is supported or if it should be rejected.
	    return 321
	}
	ask {
	    
	    # 2: Ask user what to do with it.
	    set ans [tk_messageBox -title [::msgcat::mc {Request To User}] \
	      -type yesno -default yes -message  \
	      [FormatTextForMessageBox [::msgcat::mc messaskreceive $fileTail]]]
	    if {[string equal $ans "no"]} {
		return 321
	    } else {
		set ans [tk_chooseDirectory -initialdir $prefs(incomingFilePath) \
		  -title [::msgcat::mc {Pick Directory}]]
		if {[string length $ans] == 0} {
		    return 321
		} else {
		    set dstPath [file join $ans $fileTail]
		    set locals($s,dstPath) $dstPath
		}
	    }
	} 
	save {
	    # Do nothin.
	}
    }
    
    # PROBLEM: we shall not require that an import package exists in all cases!
     
    # 3: Check if the file is cached, and not too old.
    
    if {[info exists optArr(Get-Url:)] && \
      [::FileCache::IsCached $optArr(Get-Url:)]} {
	set cachedFile [::FileCache::Get $optArr(Get-Url:)]
	
	# Get the correct import procedure for this MIME type.
	::GetFile::DoImport $mime $optList -file $cachedFile -where "local"
	return 320
    }

    # Get the correct import procedure for this MIME type. Empty if nothing.
    set importPackage [GetPreferredPackage $mime]
    if {$importPackage == ""} {
	return 321
    }
    
    # 4:
    # Check if the import package wants to get it via an URL instead.
    # But only if we have an option 'preferred-transport: http'!!!
    
    set doHttpTransport 0    
    if {[info exists optArr(preferred-transport:)] && \
      [string equal $optArr(preferred-transport:) "http"]} {
	
	if {[info exists plugin($importPackage,trpt,$mime)] && \
	  [string equal $plugin($importPackage,trpt,$mime) "http"]} {
	    set doHttpTransport 1      
	} elseif {[info exists plugin($importPackage,trpt,$mimeBase)] && \
	  [string equal $plugin($importPackage,trpt,$mimeBase) "http"]} {
	    set doHttpTransport 1
	}
    }
    
    if {$doHttpTransport} {
	
	# Need to get the "Get-Url:" key from the optList.
	if {[info exists optArr(Get-Url:)]} {
	    
	    # Should we have an 'after idle' here to let us reject before
	    # connecting via URL?
	    ::GetFile::DoImport $mime $optList -url $optArr(Get-Url:)  \
	      -where "local"
	    return 323	    
	} else {
	    return 499
	}
    }

    # 5:
    # Check that the destination file opens correctly.
    
    if {[catch {open $dstPath w} dest]} {
	tk_messageBox -icon error -type ok -message   \
	  [FormatTextForMessageBox \
	  "Server failed when trying to open $dstPath: $dest"]
	return 500
    }    
    set locals($s,dest) $dest
    
    # It's ok to get on with the file transfer.
    fconfigure $s -blocking 0
    
    # Disable callback for this channel. Important for fcopy!
    fileevent $s readable {}
	    
    # Use MIME type to hint transfer mode.
    if {$mimeTypeIsText($mime)} {
	fconfigure $s -translation auto
	fconfigure $dest -translation auto
    } else {
	fconfigure $s -translation {binary binary}
	fconfigure $s -buffering full
	fconfigure $dest -translation {binary binary}
    }
    
    # Everything is prepared to recieve the file.
    return $noErr
}
    
# GetFile::Callback --
#
#       Callback function to handle the server part of putting a file.
#
# Arguments:
#       s         the socket to get from.
#       bytes     appended by fcopy; number of bytes for this chunk.
#       error     (optional) appended by fcopy; possible error.
#       
# Results:
#       Schedules new fcopy if not finished, or calls 'Finalize' if 
#       finished.

proc ::GetFile::Callback {s bytes {error {}}} {
    global  chunkSize ipNumTo
    
    variable locals
    
    Debug 5 ">     Callback:: (entry) error=$error, bytes=$bytes"
    
    # Save short names.
    set ip $locals($s,ip)
    set dest $locals($s,dest)
    set optList $locals($s,optList)
    set fileTail $locals($s,fileTail)
    set totBytes $locals($s,totBytes)

    # Check if shall cancel this transfer.
    if {$locals($s,cancel)} {
	ShutDown $s
	set msg "File transfer of file $fileTail cancelled by user"
	$locals($s,cmd) $s $ip $fileTail $totBytes 0 $msg

	# Cleanup ???
	catch {file delete $locals($s,dstPath)}
	Cleanup $s
	return
    }
    if {[string length $error]} {
	
	# Close socket and file.
	ShutDown $s
	set msg "File transfer of file $fileTail failed with error: $error"
	$locals($s,cmd) $s $ip $fileTail $totBytes 0 $msg $msg
	Cleanup $s
	return
    }
    
    # Check if socket already closed, perhaps the user pushed the cancel bt.
    if {[catch {eof $s}]} {
	puts "Callback:: catch eof in"
	return
    }
    incr locals($s,sumBytes) $bytes
    set sumBytes $locals($s,sumBytes)

    # Store timing data in a list with each element a list {clicks sumBytes}.
    lappend locals($s,timing) [list [clock clicks -milliseconds] $sumBytes]
    set msg [FormProgressMessage $s]
    
    # Take care of any progress window and progress messages.
    $locals($s,cmd) $s $ip $fileTail $totBytes $sumBytes $msg
    
    # testing... IMPORTANT on Windows, else this blocks!!!!!!!!
    update
    
    if {[eof $s]} {
	
	# Check if empty transfer.
	if {$sumBytes == 0} {
	    ShutDown $s
	    set msg "Received file \"$fileTail\" contained no data"
	    $locals($s,cmd) $s $ip $fileTail $totBytes $sumBytes $msg $msg
	    Cleanup $s
	    return
	}
	$locals($s,cmd) $s $ip $fileTail $totBytes $sumBytes {}
	
	# Consistency checking: totBytes must be equal to the actual bytes
	# received.
	if {$totBytes != $sumBytes} {
	    puts ">     Callback:: eof in: totBytes=$totBytes, sumBytes=$sumBytes"
	}
	Finalize $s $bytes
	
    } else {
	
	# Not finished; rebind this callback.
	if {[catch {
	    fcopy $s $dest -size $chunkSize -command  \
	      [list [namespace current]::Callback $s]
	}]} {	
	    ShutDown $s
	    set msg {We recieved a network error while trying to transfer file} 
	    $locals($s,cmd) $s $ip $fileTail 10000000 0 $msg $msg	
	    Cleanup $s
	}
    }
}

# GetFile::FormProgressMessage --
#
#       Makes a text string that describes the status of the current transfer. 
#       
# Arguments:
#       s          the socket to get from.
#       
# Results:
#       a text string suitable for UI: "108kB/sec, 33 secs remaining".

proc ::GetFile::FormProgressMessage {s} {
    global  ipNumTo
    
    variable locals
        
    set totBytes $locals($s,totBytes)
    set sumBytes $locals($s,sumBytes)

    # Get transfer statistics.
    set bytesPerSec [::FileUtils::GetTransferRateFromTiming $locals($s,timing)]
    set txtBytesPerSec [::FileUtils::BytesPerSecFormatted $bytesPerSec]
    set percent [format "%3.0f" [expr 100*$sumBytes/($totBytes + 1.0)]]
    set secsLeft  \
      [expr int(ceil(($totBytes - $sumBytes)/($bytesPerSec + 1.0)))]
    set txtTimeLeft ", $secsLeft secs remaining"
    
    # Status message.
    return "${txtBytesPerSec}${txtTimeLeft}"
}

# GetFile::Finalize --
#
#       Closes sockets and files. 
#       Put file to receive file; handles via temporary socket.
#       
# Arguments:
#       s        the socket to get from.
#       error     any error.
#       
# Results:
#       none.

proc ::GetFile::Finalize {s bytes {error {}}} {
    global  plugin mimeTypeDoWhat this
    
    variable locals

    Debug 2 ">       Finalize:: (entry) bytes=$bytes"
    
    # Save short names.
    set fileTail $locals($s,fileTail)
    set ip $locals($s,ip)
    set optList $locals($s,optList)
    set dstPath $locals($s,dstPath)
    array set optArr $optList
    
    # Evaluate the callback command.
    $locals($s,cmd) $s $ip $fileTail $locals($s,totBytes) $locals($s,sumBytes) {}

    if {[string length $error] != 0} {
	puts "error during file copy: $error"
	return
    }    
    
    # Do the actual work of showing the image/movie.
    # The 'optList' is just passed on.
    # Get the correct import procedure for this MIME type.    
    if {[info exists locals($s,mime)]} {
	set mime $locals($s,mime)
    } else {
	set mime [GetMimeTypeFromFileName $fileTail]
    }
    
    # Close socket and file.
    ShutDown $s
    Cleanup $s
    
    # Cache it in our database using the url as key.
    # A file obtained this way gets two database entries:
    #   1) the remote url-based one
    #   2) the local one in the incoming dir
    if {[info exists optArr(Get-Url:)]} {
	::FileCache::Set $optArr(Get-Url:) $dstPath
    }
    ::GetFile::DoImport $mime $optList -file $dstPath -where "local"
}

# GetFile::DoImport --
# 
#       Abstraction for importing an image etc. Non jabber just imports
#       into the main whiteboard, else let a dispatcher send entity to
#       the correct whiteboard.
#       

proc ::GetFile::DoImport {mime optList args} {
    global  prefs
    
    if {[string equal $prefs(protocol) "jabber"]} {
	eval {::Jabber::WB::DispatchToImporter $mime $optList} $args
    } else {
	upvar ::.::wapp wapp

	set impPackage [GetPreferredPackage $mime]
	eval {$plugin($impPackage,importProc) $wapp(servCan) $optList} $args
    }
}

# GetFile::ScheduleKiller --
#
#       Cancels any old schedules, and reschedules a call to 'Kill'.
#       
# Arguments:
#       s      the socket to get from.
#       
# Results:
#       none.

proc ::GetFile::ScheduleKiller {s} {
    global  prefs
    
    variable locals

    if {[info exists locals($s,killId)]} {
	after cancel $locals($s,killId)
    }
    set locals($s,killId) [after [expr 1000*$prefs(timeout)]   \
      [list [namespace current]::Kill $s]]
}

# GetFile::Kill --
#
#       If any scheduled get file killers, inform user, call 'ShutDown'.
#       
# Arguments:
#       s      the socket to get from.
#       
# Results:
#       none.

proc ::GetFile::Kill {s} {
    global  prefs ipNumTo
    
    variable locals

    if {![info exists locals($s,killId)]} {
	return
    }
    ShutDown $s      
    set msg "Timout when waiting for data for file $locals($s,fileTail)\
      from $ipNumTo(name,$locals($s,ip))"
    $locals($s,cmd) $s $ip $locals($s,fileTail) 10000000 0 $msg $msg
    Cleanup $s
}

# GetFile::ShutDown --
#
#       Shuts down a file transfer from the "get" side.
#       
# Arguments:
#       s      the socket to get from.
#       
# Results:
#       socket and file closed.

proc ::GetFile::ShutDown {s} {   
    variable locals
    
    # Close.
    catch {close $s}
    catch {close $locals($s,dest)}

    # Cleanup.
    if {[info exists locals($s,killId)]} {
	after cancel $locals($s,killId)
    }
}

# GetFile::Cleanup
#
#       Any UI shall be done before this call since 'locals' are removed.

proc ::GetFile::Cleanup {s} {
    variable locals

    # Cleanup the 'locals' array.
    foreach key [array names locals "$s,*"] {
	unset locals($key)
    }
    set ind [lsearch $locals(all) $s]
    if {$ind >= 0} {
	set locals(all) [lreplace $locals(all) $ind $ind]
    }
}


# GetFile::CancelCmd --
#
#       This is the command when pressing the cancel button in the progress
#       window. Just set a variable so that no rebinding occurs in the fcopy
#       callback procedure.

proc ::GetFile::CancelCmd {s} {
    variable locals

    Debug 2 "+::GetFile::CancelCmd::"
    set locals($s,cancel) 1
}

# GetFile::CancelAll ---
#
#       It is supposed to stop every get operation taking place.
#       This may happen when the user presses a stop button or something.
#       Not sure this works ok.
#   

proc ::GetFile::CancelAll { } {
    variable locals

    Debug 2 "+::GetFile::CancelAll"

    foreach s $locals(all) {
	
	# Perhaps the files themselves should also be deleted?
	catch {file delete $locals($s,dstPath)}
	ShutDown $s
	Cleanup $s
    }
    set locals(all) {}
}

# GetFile::DefaultCallbackProc
#
#       This is our standard callback proc to handle UI things during
#       file transfers. 
#
# Arguments:
#       s         the channel socket.
#       ip        the ip number of the remote client.
#       fileTail  the file name to get. 
#       totBytes  size of the file.
#       sumBytes  number of bytes transferred so far.
#       msg       message to display in UI: "108kB/sec, 33 secs remaining".
#                 
# Results:
#       none.

proc ::GetFile::DefaultCallbackProc {s ip fileTail totBytes sumBytes msg {error {}}} {
    global  wDlgs prefs ipNumTo timingClicksToMilliSecs
    
    variable locals

    if {[string length $error]} {
	catch {destroy $wDlgs(prog)$s}
	::UI::SetStatusMessage . $msg
	tk_messageBox -message [FormatTextForMessageBox $error] -icon error -type ok
	return
    }
    if {$totBytes == $sumBytes} {
	
	# Finished.
	::UI::SetStatusMessage .  \
	  "Getting file: $fileTail from $ipNumTo(name,$ip), Finished!"
	catch {destroy $wDlgs(prog)$s}
    } elseif {$sumBytes > 0} {
	
	# Ongoing transfer.
	set msSinceUpdate [expr $timingClicksToMilliSecs *   \
	  ([lindex [lindex $locals($s,timing) end] 0] - $locals($s,lastProg))]
	if {$msSinceUpdate > $prefs(msecsProgUpdate)} {
	    
	    # Only update at the specified rate; helps to read numbers,
	    # and saves cpu cycles.
	    ::UI::SetStatusMessage .  \
	      "Getting file: $fileTail from $ipNumTo(name,$ip) (at $msg)"
	    ::GetFile::UpdateAnyProgress $s $ip $fileTail $totBytes $sumBytes $msg
	    set locals($s,lastProg) [lindex [lindex $locals($s,timing) end] 0]
	    
	    # A full blown update seems necessary here???
	    update idletasks
	}
    } else {
	
	# Negotiating...
	::UI::SetStatusMessage . $msg
	update idletasks
    }
}

# GetFile::UpdateAnyProgress
#
#       Typically called from the get callback procedure to handle the
#       progress window.
#
# Arguments:
#       s         the channel socket.
#       ip        the ip number of the remote client.
#       fileTail  the file name to get. 
#       totBytes  size of the file.
#       sumBytes  number of bytes transferred so far.
#       msg       message to display in UI.
#                 
# Results:
#       none.

proc ::GetFile::UpdateAnyProgress {s ip fileTail totBytes sumBytes msg} {
    global  wDlgs timingClicksToSecs prefs chunkSize ipNumTo
    
    variable locals

    # Handle the progress window; small files don't need one.
    set wantProgWin 0
    set wProg $wDlgs(prog)$s
    set progWinExists [winfo exists $wProg]
    set timingListLen [llength $locals($s,timing)]
    
    if {!$progWinExists && ($timingListLen > 3)} {
	set totTimeInSecs [expr  $timingClicksToSecs * \
	  ([lindex [lindex $locals($s,timing) end] 0] -  \
	  [lindex [lindex $locals($s,timing) 0] 0])]
	if {$totTimeInSecs > $prefs(secsToProgWin)} {
	    set wantProgWin 1
	}
    }
    if {$wantProgWin && !$progWinExists} {
	
	# Create the progress window.
	Debug 2 "::GetFile::UpdateAnyProgress  create ProgWin"

	::ProgressWindow::ProgressWindow $wProg -name {Get File} \
	  -filename $fileTail -text2 "From: $ipNumTo(name,$ip)\nRate: $msg" \
	  -cancelcmd [list [namespace current]::CancelCmd $s]
    }
    if {$progWinExists} {

	# Update the progress window.
	set percent [expr 100.0 * $sumBytes/($totBytes + 1.0)]
	$wProg configure -percent $percent   \
	  -text2 "From: $ipNumTo(name,$ip)\nRate: $msg"
    }    
}

#-------------------------------------------------------------------------------
