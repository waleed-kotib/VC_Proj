#!/bin/sh
# the next line restarts using tclsh \
	exec tclsh "$0" "$@"
      
#  ReflectorServer.tcl --
#  
#      This file is part of The Coccinella application. It implements a
#      reflector server that accepts connections from clients.
#      In short, incoming stuff from one client is written to all other
#      clients, see note below.
#      
#      IMPORTANT: It should be run in a separate tclsh process!
#                 It must not be sourced in in the main interpreter.
#      
#  Copyright (c) 2000  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#
# $Id: ReflectorServer.tcl,v 1.4 2004-07-30 12:55:55 matben Exp $
# 
#  Since this is a pretty complex piece of code we describe the principles in
#  some detail here.
#  
#      Sockets are divided into groups, where each client may only have one
#  socket in each group. There is one _primary_ group which is line oriented,
#  and deals with the communication between clients that involves everything
#  except file transfer. A client identifies itself as belonging in this
#  group if its first command is an IDENTITY command. Each incoming line
#  on a socket in this group is just reflected to every other client.
#  
#      There may be zero or many _secondary_ groups. Each group is involved
#  in the transfer of one particular file (image, movie etc.). If this server
#  receives a PUT request as its first request on a new socket, we initiate
#  the file transfer (put/get operation) by sending a PUT NEW command to every
#  other client on its primary socket. The clients should then open a new
#  socket, and give a GET command as its first command. Each group is 
#  assigned a unique group identification number which is used to identify
#  each sockets GET command. 
#  
#      Since we are the server we cannot initiate any new sockets, and 
#  therefore this procedure. Several of the commands contain a list of
#  'key: value' pairs, similar to the http protocol, but augmented with
#  stuff particular for us, for instance, the group id.
#  
#      As data is received in a PUT operation, each chunk of data is put in a
#  variable, and a reference count equal to the number of clients to write to
#  is kept in a variabel. For each client we write this particular chunk to,
#  we decrement the reference count by one. When the reference count is equal
#  to zero, unset this chunk.
#  
#      The principle for file transfer in a secondary group is as follows:
#  Once a PUT operation is detected, it puts a "PUT NEW" request on all the
#  primary sockets to ask these clients to open a new socket to this server,
#  and issue a GET operation for this specific group. Then it schedules
#  'ReadChunk' to read its first chunk, which reschedules itself automatically 
#  to read all chunks until eof.
#  
#      Once a GET operation on this group is detected, a write operation of the
#  newly read first chunk is scheduled, or if it doesn't exist yet, a trace
#  is put on this first chunk to schedule writing. 'WriteChunk' reschedules
#  itself automatically provided the next chunk of data exists. If not, it
#  is stopped using a 'semaphore'. 'ReadChunk' checks automatically when each
#  chunk is read if any 'semaphores' signal that a write operation has stopped,
#  and reschedules the stopped ones from where they stopped. Simple dear Watson.
#
#  We need to collect information about the various sockets: use the 
#  ip number as the first key into this database, and the unique group
#  identification number for the second key.
#
#  Variables:
#
#       semaphore(ip,group)      0 if no write operation is scheduled,
#                                1 if there is a write operation scheduled.
#       gidRun                   running transfer group identification number.
#       recordGroup(group,fd)    the file descriptor of the file to cache on 
#                                disk,
#       recordGroup(group,fn)    and its original name (not the cached file 
#                                name).
#       allIps                   list of the ip numbers in the primary group at
#                                each instance of time...
#       allIpsThisGroup(group)   ...and for a secondary group.
#       chunk(group,chunkNo)     contains the actual data for this group and 
#                                chunk identification number.
#       chunkRef(group,chunkNo)  the reference count for this group and chunk.
#       lastChunkWritten(ip,group)  the latest chunk number written to this ip
#                                in this group.
#       lastChunkRead(group)     the latest chunk number read in this group.
#       endChunkNo(group)        the very last chunk for this group; it is
#                                actually only an eof for technical reasons.      

# The only argument must be the port number.
      
if {$argc != 1}  {
    set thisPortNumber 8144
} else {
    set thisPortNumber [lindex $argv 0]
}
      
# Initializations.
# The tcl buffer size; must be the same for all put/get sockets.
set chunkSize 1024
# Should we save transfered files on disk?
set prefs(saveCopyOnDisk) 1
# Reject if no other clients to put to.
set prefs(rejectIfNoClients) 0
# A log file?
set prefs(log) 1
set prefs(logFileName) reflectorLog.txt
# Empty cache on exit?
set prefs(emptyCache) 1
# Debug stuff, put your own at 1, ours at >= 2.
set prefs(debug) 0
# Any connections yet?
set state(connectedOnce) 0

# console?
if {([string compare $tcl_platform(platform) "windows"] == 0) &&   \
  ($prefs(debug) == 0)}  {
    #console hide
}

# Mapping from error code to error message; 320+ own, rest HTTP codes.

set tclwbProtMsg(200) [mc OK]
set tclwbProtMsg(201) "Created"
set tclwbProtMsg(202) "Accepted"
set tclwbProtMsg(204) "No Content"
set tclwbProtMsg(301) "Moved Permanently"
set tclwbProtMsg(302) "Moved Temporarily"
set tclwbProtMsg(304) "Not Modified"
set tclwbProtMsg(320) "File already cached"
set tclwbProtMsg(321) "MIME type unsupported"
set tclwbProtMsg(322) "MIME type not given"
set tclwbProtMsg(323) "Group id not given"
set tclwbProtMsg(324) "Client request close"
set tclwbProtMsg(340) "No other clients connected"
set tclwbProtMsg(400) "Bad Request"
set tclwbProtMsg(401) "Unauthorized"
set tclwbProtMsg(403) "Not Found"
set tclwbProtMsg(404) "Not Found"
set tclwbProtMsg(500) "Internal Server Error"
set tclwbProtMsg(501) "Not Implemented"
set tclwbProtMsg(502) "Bad Gateway"
set tclwbProtMsg(503) "Service Unavailable"

# StartReflectorServer --
#
#       Creates a listening socket that sets up a callback procedure on new
#       incoming connections.
#       
# Arguments:
#       port    the port number to listen to.
# Results:
#       none.

proc StartReflectorServer { port } {
    global  gidRun prefs this
    
    if {[catch {socket -server SetupChannel $port} sock]}  {
	
	# removed...
	# -myaddr [info hostname]
	# since picks localhost on Linux
	
	error   \
	  "Couldn't start server socket. Perhaps you are not connected."
    } else { 
	set gidRun 0
	set prefs(thisIPnum) [lindex [fconfigure $sock -sockname] 0]

	# Try to get own ip number from a temporary server socket.
	# This can be a bit complicated as different OS sometimes give 0.0.0.0 or
	# 127.0.0.1 instead of the real number.
	
	if {![catch {socket -server puts 0} s]} {
	    set thisIPnum [lindex [fconfigure $s -sockname] 0]
	    catch {close $s}
	    if {$prefs(debug) >= 2} {
		puts "1st: thisIPnum=$thisIPnum"
	    }
	}
	
	# If localhost or zero, try once again with '-myaddr'.
	# Linux/Unix may still fail!!!
	if {([string compare $thisIPnum "0.0.0.0"] == 0) ||  \
	  ([string compare $thisIPnum "127.0.0.1"] == 0)}  {
	    if {![catch {socket -server puts -myaddr [info hostname] 0} s]} {
		set thisIPnum [lindex [fconfigure $s -sockname] 0]
		catch {close $s}
		if {$prefs(debug) >= 2} {
		    puts "2nd: thisIPnum=$thisIPnum"
		}
	    }
	}
	set prefs(thisIPnum) $thisIPnum
	
	# Make sure we have a cache directory in the present directory.
	set prefs(cachePath) [file join $this(path) cache]
	if {![file exists $prefs(cachePath)]} {
	    file mkdir $prefs(cachePath)
	}
	
	# Open the log file if any.
	if {$prefs(log)} {
	    if {[catch {open [file join $this(path) $prefs(logFileName)] a} fd]} {
		error "Couldn't open the log file $prefs(logFileName)"
	    } else {
		set prefs(logFd) $fd
		
		# Print a header.
		set clk [clock format [clock seconds] -format "%H:%M:%S, %a %b %Y"]
		puts $fd "\n#\n#\tReflector Server started at: $clk\n#"
		puts $fd "#\tOur ip number: $prefs(thisIPnum)\n"
	    }
	}
    }
}

# SetupChannel --
#
#       Sets up a file event to handle the first line received from a newly
#       opened socket.
#       
# Arguments:
#       s       the newly created socket.
#       ip      the remote ip number.
#       port    the remote port?.
# Results:
#       none.

proc SetupChannel { s ip port } {
    global  prefs state
    
    if {$prefs(debug) >= 2} {
	puts "SetupChannel: s=$s, ip=$ip, port=$port"
    }
    fileevent $s readable [list HandleClientRequest $s $ip $port]
    fconfigure $s -blocking 0 -buffering line
    set sockname [fconfigure $s -sockname]
    
    # Sometimes the StartReflectorServer just gives thisIPnum=0.0.0.0,
    # or 127.0.0.1; fix this here.
    
    if {!$state(connectedOnce)} {
	set prefs(thisIPnum) [lindex $sockname 0]
	set state(connectedOnce) 1
    }
}

# HandleClientRequest --
#
#       It reads the first line of each newly opened socket to this server,
#       and sets up new event handlers for primary or secondary sockets.
#       
# Arguments:
#       s       the newly created socket.
#       ip      the remote ip number.
#       port    the remote port?.
# Results:
#       none.

proc HandleClientRequest { s ip port } {
    global  gidRun allIps isPrimarySock ip2PrimarySock ip2UserName ip2UserId  \
      chunkSize allIpsThisGroup tclwbProtMsg isOpen prefs ip2Sock   \
      lastChunkRead chunkRef ip2ConnectTime chunk thisPortNumber
    
    if {$prefs(debug) >= 2} {
	puts "HandleClientRequest: s=$s, ip=$ip, port=$port"
    }
    set portwrd_ {[0-9]+}
    set pre_ {[^/ ]+}
    # Matches list with braces.  
    # ($llist_|$wrd_)  :should match single item list or multi item list.
    set llist_ {\{[^\}]+\}}
    set wrd_ {[^ ]+}
    set anyornone_ {.*}
    
    
    
    if {[eof $s]} {
	if {$prefs(debug) >= 2} {
	    puts "  HandleClientRequest: eof"
	}
	
	# Tell all other clients that this ip is disconnected.
	ClientDisconnected $s $ip
	
    } elseif {[gets $s line] != -1} {

	# This is the first line of a newly opened socket.
	# Find out if we have a primary socket or a secondary one.
	
	if {[regexp "^IDENTITY: +($portwrd_) +($pre_) +($llist_|$wrd_)$" \
	  $line junk remPort id user]}  {

	    if {$prefs(debug) >= 2} {
		puts "  HandleClientRequest: IDENTITY id=$id, user=$user"
	    }
	    if {$prefs(log)} {
		set clk [clock format [clock seconds] -format "%H:%M:%S"]
		puts $prefs(logFd)   \
		  "$clk \t$ip, IDENTITY, user=$user"
		flush $prefs(logFd)
	    }
	   
	    # This is a primary socket. Collect some useful information.
	    # A client tells which server port number it has (irrelevant here), 
	    # its item prefix and its user name.
	    
	    set isPrimarySock($s) 1
	    set ip2PrimarySock($ip) $s
	    set ip2UserName($ip) [lindex $user 0]
	    set ip2UserId($ip) $id
	    set ip2ConnectTime($ip) [clock seconds]
	    set allIps [array names ip2PrimarySock]
	    
	    # Tell the connecting client who we are.
	    
	    puts $s "IDENTITY: $thisPortNumber donald_duck Reflector"
	    
	    # Set up new event handlers that reflects each incoming line to
	    # all other primary sockets.
	    
	    fileevent $s readable [list ReflectPrimaryCmdLine $s $ip]
	    
	    foreach ipc $allIps {
		if {$ip == $ipc} {
		    continue
		}
	    
		# Let all other clients know that a new client is connected.
		puts $ip2PrimarySock($ipc)  \
		  [list CLIENT: ip: $ip User-Name: $ip2UserName($ip) \
		  User-Id: $id \
		  Connected-Since: [clock format $ip2ConnectTime($ip)]]
		
		# Tell the new client who the present clients are.
		puts $s [list CLIENT: ip: $ipc User-Name: $ip2UserName($ipc) \
		  User-Id: $ip2UserId($ipc)  \
		  Connected-Since: [clock format $ip2ConnectTime($ipc)]]
		
	    }	    
	    
	} elseif {[regexp "^PUT: +($llist_|$wrd_) *($anyornone_)$" \
	  $line junk fileName optList]} {
	    
	    # One of our clients initiates a put operation.
	    
	    if {$prefs(debug) >= 2} {
		puts "  HandleClientRequest: PUT fileName=$fileName, optList=$optList"
	    }
	    
	    if {$prefs(rejectIfNoClients) && ([llength $allIps] <= 1)} {
		puts $s "TCLWB/1.0 340 $tclwbProtMsg(340)"
		flush $s
		catch {close $s}
		return
	    }
	    
	    # The clients need the group id so we may identify them when they 
	    # connect with a new socket and make a GET operation.
	    
	    incr gidRun
	    if {$prefs(log)} {
		set clk [clock format [clock seconds] -format "%H:%M:%S"]
		puts $prefs(logFd) "$clk \t$ip, PUT, fileName=$fileName\
		  options: $optList"
		flush $prefs(logFd)
	    }
	    lappend optList {Group-Id:} $gidRun
	    array set putArrOpts $optList
	    if {[info exists putArrOpts(Content-Type:)]} {
		set theMime $putArrOpts(Content-Type:)
	    } else {
		puts "Error:: MIME type not given."
		puts $s "TCLWB/1.0 322 $tclwbProtMsg(322)"
		flush $s
		catch {close $s}
		return
	    }
	    
	    # Here we answer that it's ok to get on with the file transfer.
	    
	    puts $s "TCLWB/1.0 200 $tclwbProtMsg(200)"
	    flush $s
	        
	    # Make a new secondary group, and prepare for a file transfer.
	    # Tell all other clients to prepare for a GET file operation
	    # on a new socket.
	    # Perhaps we only need the group id and Mime type in 'optList'.
	    
	    foreach ipClient $allIps {
		if {$ip == $ipClient} {
		    continue
		}
		puts $ip2PrimarySock($ipClient) "PUT NEW: $fileName $optList"
	    }
	    set isPrimarySock($s) 0
	    set allIpsThisGroup($gidRun) $allIps
	    
	    # From the Mime type, set translation mode on socket *read*.
	    
	    if {[string match "text/*" $theMime]}  {
		fconfigure $s -translation auto
	    } else {
		fconfigure $s -translation {binary binary}
	    }
	    fconfigure $s -blocking 0 -buffersize $chunkSize -buffering full
	    	    
	    # Prepare for a new group to be created.
	    
	    InitNewSecondaryGroup $s $ip $gidRun $fileName
	    
	} elseif {[regexp "^GET: +($llist_|$wrd_) *($anyornone_)$" \
	  $line junk fileName optList]} {

	    if {$prefs(debug) >= 2} {
		puts "  HandleClientRequest: GET fileName=$fileName, optList=$optList"
	    }
	    
	    # Schedule write operations to this client on the secondary
	    # socket if OK.
	    
	    array set arrOpts $optList
	    
	    # Find secondary group which is necessary for the identification.

	    if {[info exists arrOpts(Group-Id:)]} {
		set gid $arrOpts(Group-Id:)
	    } else {
		puts $s "TCLWB/1.0 323 $tclwbProtMsg(323)"
		flush $s
		catch {close $s}
		return
	    }

	    # Check that we don't have an error code from the client.
	    # Could be MIME unsupported, file cached, internal error etc.
	    
	    if {[info exists arrOpts(Error-Code:)]} {
		if {$prefs(debug) >= 2} {
		    puts "    HandleClientRequest: Error-Code: $arrOpts(Error-Code:)"
		}
		catch {close $s}
		
		# Cleanup. Remove from the group.
		set ind [lsearch $allIpsThisGroup($gid) $ip]
		if {$ind >= 0} {
		    set allIpsThisGroup($gid)   \
		      [lreplace $allIpsThisGroup($gid) $ind $ind]
		}
		
		# Decrement all the reference counts for the chunks read but 
		# that never gets written to this client.
		
		for {set i 0} {$i <= $lastChunkRead($gid)} {incr i} {
		    incr chunkRef($gid,$i) -1
		    
		    # If we are the last to write this chunk, discard it.
		    if {$chunkRef($gid,$i) == 0} {
			unset chunk($gid,$i)
		    }
		}
		return
 	    }
	    
	    if {[info exists arrOpts(Content-Type:)]} {
		set theMime $arrOpts(Content-Type:)
	    } else {
		puts $s "TCLWB/1.0 340 $tclwbProtMsg(340)"
		flush $s
		catch {close $s}
		return
	    }
	    
	    # Respond to the client according to the GET protocol.
	    
	    puts $s "TCLWB/1.0 200 $tclwbProtMsg(200)"
	    puts $s $optList
	    flush $s

	    fconfigure $s -blocking 0 -buffersize $chunkSize -buffering full
	    
	    # From the Mime type, set translation mode on socket *write*.
	    
	    if {[string match "text/*" $theMime]}  {
		fconfigure $s -translation auto
	    } else {
		fconfigure $s -translation {binary binary}
	    }
	    
	    set isOpen($ip,$gid) 1
	    set isPrimarySock($s) 0
	    set ip2Sock($ip,$gid) $s
    
	    # If we have already got the first chunk of data, then schedule 
	    # write operations to this client on the secondary socket.
	    
	    if {[info exists chunk($gid,0)]} {
		fileevent $s writable [list WriteChunk $ip $s $gid 0]
	    } else {
		
		# When the first chunk is written, the trace will schedule
		# the write operation for this client.
		
		trace variable chunk($gid,0) w  \
		  [list TraceProcFirstChunk $ip $s $gid]
	    }
	    
	} elseif {[regexp "^KILL:" $line match]} {

	    if {$prefs(debug) >= 2} {
		puts "  HandleClientRequest: KILL"
	    }
	    if {$prefs(log)} {
		set clk [clock format [clock seconds] -format "%H:%M:%S"]
		puts $prefs(logFd) "$clk \t$ip, KILL"
		flush $prefs(logFd)
	    }
	    if {$prefs(thisIPnum) == $ip} {
		if {$prefs(log)} {
		    puts $prefs(logFd) "\n$clk \tReflector Server stopped!"
		    catch {close $prefs(logFd)}
		}
		if {$prefs(emptyCache)} {
		    
		    # Delete all files in the cache dir.
		    cd $prefs(cachePath)
		    set allFiles [glob -nocomplain *]
		    if {[llength $allFiles] > 0} {
			eval file delete $allFiles
		    }
		}
		exit
	    } else {
		if {$prefs(log)} {
		    puts $prefs(logFd) "$clk \t$ip, Evil attack!"
		    flush $prefs(logFd)
		}
		if {$prefs(debug) >= 2} {
		    puts "Only the client that started us can kill us"
		}
	    }
	} else {
	    if {$prefs(debug) >= 2} {
		puts "Unknown instruction to the reflector server: $line"
	    }
	}
    }    
}

# ReflectPrimaryCmdLine --
#
#       It reads the incoming line and writes them to all other clients.
#       Blocking mode write since the lines written are usually much
#       smaller than the OS internal buffers (~64k).
#       
# Arguments:
#       s       socket for incoming line...
#       ip      ... and its ip number.
# Results:
#       none.

proc ReflectPrimaryCmdLine { s ip } {
    global  allIps isPrimarySock ip2PrimarySock prefs
    
    if {$prefs(debug) >= 2} {
	puts "ReflectPrimaryCmdLine s=$s, ip=$ip"
    }
    if {[eof $s]} {
	
	# Tell all other clients that this ip is disconnected.
	
	ClientDisconnected $s $ip
	
    } elseif {[gets $s line] != -1} {
	
	if {$prefs(debug) >= 2} {
	    puts "  ReflectPrimaryCmdLine line=$line"
	}
	
	# Loop over all clients except the incoming.

	foreach ipClient $allIps {
	    if {$ip == $ipClient} {
		continue
	    }
	    puts $ip2PrimarySock($ipClient) $line
	}
    }
}

# ClientDisconnected --
#
#       This is called when one client disconnects. Let all other connected
#       clients know, and cleanup.
#       
# Arguments:
#       s       socket that did the eof.
#       ip      and its ip number.
# Results:
#       none.

proc ClientDisconnected { s ip } {
    global  allIps isPrimarySock ip2PrimarySock prefs
    
    if {$prefs(debug) >= 2} {
	puts "ClientDisconnected s=$s, ip=$ip"
    }
    if {$prefs(log)} {
	set clk [clock format [clock seconds] -format "%H:%M:%S"]
	puts $prefs(logFd)   \
	  "$clk \t$ip, DISCONNECTED:"
	flush $prefs(logFd)
    }
    
    # Close the server side socket.
    
    catch {close $s}
    
    # Tell all other clients that this ip is disconnected.
    
    foreach ipClient $allIps {
	if {$ip == $ipClient} {
	    continue
	}
	puts $ip2PrimarySock($ipClient) "DISCONNECTED: $ip"
    }
    
    # ...and remove it from the send list.
    
    if {$isPrimarySock($s)} {
	unset -nocomplain ip2PrimarySock($ip)
	set ind [lsearch $allIps $ip]
	if {$ind >= 0} {
	    set allIps [lreplace $allIps $ind $ind]
	}
    }
}


#--- Stuff for secondary sockets -----------------------------------------------

# InitNewSecondaryGroup --
#
#       Takes care of various initializations for this transfer group,
#       and schedules reding the first data chunk.
#       
# Arguments:
#       s       socket that did the put operation.
#       ip      and its ip number.
#       gid     the group identification number for the group to be initiated.
#       fileName   the original file name (path???).
# Results:
#       Schedules reading the first chunk of data.

proc InitNewSecondaryGroup { s ip gid fileName } {
    global  semaphore allIpsThisGroup lastChunkWritten isOpen recordGroup   \
      prefs lastChunkRead
    
    if {$prefs(debug) >= 2} {
	puts "InitNewSecondaryGroup s=$s, ip=$ip, gid=$gid, fileName=$fileName"
    }
    set lastChunkRead($gid) -1
    set recordGroup($gid,fn) $fileName
    foreach ipc $allIpsThisGroup($gid) {
	set isOpen($ipc,$gid) 0
	set semaphore($ipc,$gid) 0
	set lastChunkWritten($ipc,$gid) -1
    }
    
    # Schedule reading the first chunk of data.
    
    fileevent $s readable [list ReadChunk $ip $s $gid 0]
}

# TraceProcFirstChunk --
#
#       Gets called when the first chunk gets read in if the write socket
#       was open before chunk(...,0) existed.
#       
# Arguments:
#       ip      the remote ip number that made a GET request.
#       s       the socket.
#       groupId the unique group identifier that is identical for all sockets
#               that are involved on the transfer of one specific file
#       varName is "chunk"
#       ind     is "gid,0"
#       op      operation, r, w, u
# Results:
#       none.

proc TraceProcFirstChunk { ip s groupId varName ind op } {
    global  prefs
    
    if {$prefs(debug) >= 2} {
	puts "TraceProcFirstChunk: ip=$ip, s=$s, groupId=$groupId,  \
	  varName=$varName, ind=$ind, op=$op"
    }
    
    if {$op == "w"} {
	fileevent $s writable [list WriteChunk $ip $s $groupId 0]
	
	# There may be a remaining trace that needs to be removed. 
	# Note: remove only this specific trace.
	
	catch {trace vdelete chunk($groupId,0) w   \
	  [list TraceProcFirstChunk $ip $s $groupId]}
    }
}

# ReadChunk --
#
#       Read one chunk of data, and reschedule reading the next chunk.
#       Reschedule writing to clients if stopped.
#       
# Arguments:
#       ip      the remote ip number.
#       s       the socket to read from.
#       groupId the unique group identifier that is identical for all sockets
#               that are involved on the transfer of one specific file
#       chunkNo all chunks within the same group have a unique number that
#               starts at 0 for the first chunk.
# Results:
#       Reschedules a new read and restarts any stopped write.

proc ReadChunk { ip s groupId chunkNo } {
    global  chunk chunkSize chunkRef allIpsThisGroup lastChunkWritten isOpen \
      semaphore endChunkNo recordGroup prefs ip2Sock lastChunkRead
    
    if {$prefs(debug) >= 3} {
	puts "ReadChunk ip=$ip, s=$s, groupId=$groupId, chunkNo=$chunkNo"
    }
    
    # Check first if input socket still open.
    
    if {[eof $s]} {
	catch {close $s}
	set endChunkNo($groupId) $chunkNo
	
	# Set junk value so that this variable exists and doesn't make
	# WriteChunk hang.
	
	set chunk($groupId,$chunkNo) {}
	if {$prefs(debug) >= 2} {
	    puts "  ReadChunk eof; endChunkNo($groupId)=$endChunkNo($groupId)"
	}
	if {$prefs(saveCopyOnDisk)} {
	    catch {close $recordGroup($groupId,fd)}
	}
	if {$prefs(log)} {
	    set clk [clock format [clock seconds] -format "%H:%M:%S"]
	    puts $prefs(logFd) "$clk \t$ip,\
	      Last chunk read of file: $recordGroup($groupId,fn)"
	    flush $prefs(logFd)
	}
	
    } else {
	
	# There are more chunks to read, go ahead.
	
	set chunk($groupId,$chunkNo) [read $s $chunkSize]
	
	if {$prefs(saveCopyOnDisk)} {
	    if {$chunkNo == 0} {
		set fileName cache${groupId}_$recordGroup($groupId,fn)
		set fd [open [file join cache $fileName] w]
		set recordGroup($groupId,fd) $fd
		
		# Set translation mode for the disk file *write*.
		fconfigure $fd -translation [fconfigure $s -translation]
	    }
	    puts -nonewline $recordGroup($groupId,fd) $chunk($groupId,$chunkNo)
	}
	
	# Keep a reference count for each chunk in each group, and decrement it
	# with one each time it is written to a client.
	# Init it to the total number of clients minus the putting one.
	
	set chunkRef($groupId,$chunkNo)  \
	  [expr [llength $allIpsThisGroup($groupId)] - 1]
	
	# Schedule the next read operation.
	
	set nextChunkNo [expr $chunkNo + 1]
	fileevent $s readable [list ReadChunk $ip $s $groupId $nextChunkNo]
    }

    set lastChunkRead($groupId) $chunkNo
    
    # Check if any of the write events have been stopped on an already open
    # get socket, and reschedule them at the point where they stopped.
    
    foreach ipClient $allIpsThisGroup($groupId) {
	if {$isOpen($ipClient,$groupId) &&  \
	  ($semaphore($ipClient,$groupId) == 0)} {
	    
	    # Reschedule write operation.
	    
	    set semaphore($ipClient,$groupId) 1
	    
	    fileevent $ip2Sock($ipClient,$groupId) writable  \
	      [list WriteChunk $ipClient $ip2Sock($ipClient,$groupId) $groupId \
	      [expr $lastChunkWritten($ipClient,$groupId) + 1]]
	}
    }
}

# WriteChunk --
#
#       Is called as a consequence to a fileevent writable on this socket.
#       The chunk is written, and a new read operation is rescheduled if
#       next chunk exists, else stop temporarily.
#       
# Arguments:
#       ip      the remote ip number.
#       s       the socket to write to.
#       groupId the unique group identifier that is identical for all sockets
#               that are involved on the transfer of one specific file.
#       chunkNo all chunks within the same group have a unique number that
#               starts at 0 for the first chunk.
# Results:
#       none.

proc WriteChunk { ip s groupId chunkNo } {
    global  chunk chunkSize chunkRef allIpsThisGroup lastChunkWritten  \
      endChunkNo semaphore prefs lastChunkRead recordGroup

    if {$prefs(debug) >= 3} {
	puts "WriteChunk ip=$ip, s=$s, groupId=$groupId, chunkNo=$chunkNo"
    }
    
    # Check first if socket closed down before file transfer is complete 
    # (premature close).
    
    if {[eof $s]} {
	catch {close $s}
	
	# Remove from the group.
	set ind [lsearch $allIpsThisGroup($groupId) $ip]
	if {$ind >= 0} {
	    set allIpsThisGroup($groupId)   \
	      [lreplace $allIpsThisGroup($groupId) $ind $ind]
	}
	
	# Decrement all the reference counts for chunks read but that'll
	# never gets written to this client.
	
	for {set i $chunkNo} {$i <= $lastChunkRead($groupId)} {incr i} {
	    incr chunkRef($groupId,$i) -1
	    
	    # If we are the last to write this chunk, discard it.
	    if {$chunkRef($groupId,$i) == 0} {
		unset chunk($groupId,$i)
	    }
	}
	return
    }
    
    # If this was the end chunk read (actually only eof), close down, 
    # and clean up.
    
    if {[info exists endChunkNo($groupId)]} {
	if {$chunkNo == $endChunkNo($groupId)} {
	    catch {close $s}
	    if {$prefs(debug) >= 3} {
		puts "  WriteChunk: endChunkNo($groupId)=$endChunkNo($groupId)"
	    }
	    if {$prefs(log)} {
		set clk [clock format [clock seconds] -format "%H:%M:%S"]
		puts $prefs(logFd) "$clk \t$ip,\
		  Last chunk written of file: $recordGroup($groupId,fn)"
		flush $prefs(logFd)
	    }
	    return
	}
    }
    
    puts -nonewline $s $chunk($groupId,$chunkNo)
    incr chunkRef($groupId,$chunkNo) -1
    if {$chunkRef($groupId,$chunkNo) == 0} {
	unset chunk($groupId,$chunkNo)
    }
    set lastChunkWritten($ip,$groupId) $chunkNo
    set nextChunkNo [expr $chunkNo + 1]
    
    # If the next chunk has been read in, schedule the next write operation.
    
    if {[info exists chunk($groupId,$nextChunkNo)]} {
	fileevent $s writable [list WriteChunk $ip $s $groupId $nextChunkNo]
    } else {
	
	# No more chunks have been read in at this moment. We must stop here
	# and let 'ReadChunk' start us from where we are.
	# Save some info about where we have stopped.
	
	fileevent $s writable {}
	set semaphore($ip,$groupId) 0
	if {$prefs(debug) >= 3} {
	    puts "  WriteChunk: paused while waiting for the next chunk to be read"
	}
    }
}
    
#-------------------------------------------------------------------------------

#  Make sure that we are in the directory of the application itself.

set this(path) [file dirname [info script]]
if {$this(path) != ""}  {
    cd $this(path)
}
StartReflectorServer $thisPortNumber
vwait forever

#-------------------------------------------------------------------------------

