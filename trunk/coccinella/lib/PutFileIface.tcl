# PutFileIface.tcl --
#  
#       This file is part of the whiteboard application. It contains a number
#       of procedures for performing a put operation over the network from
#       a disk file.
#      
#  Copyright (c) 2002-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: PutFileIface.tcl,v 1.11 2003-11-09 15:07:32 matben Exp $

package require putfile
package require uriencode

namespace eval ::PutFileIface:: {
    
    # Internal vars only.
    variable uid 0
}

# PutFileIface::PutFileDlg --
#
#       Opens a file in a dialog and lets 'PutFile' do the job of transferring
#       the file to all other clients.

proc ::PutFileIface::PutFileDlg {wtop} {
    global  allIPnumsToSend
    
    if {[llength $allIPnumsToSend] == 0} {
	return
    }
    set ans [tk_getOpenFile -title [::msgcat::mc {Put Image/Movie}] \
      -filetypes [::Plugins::GetTypeListDialogOption]]
    if {$ans == ""} {
	return
    }
    set fileName $ans
    
    # Do the actual putting once the file is chosen. 
    ::PutFileIface::PutFileToAll $wtop $fileName "all"
}

# PutFileIface::PutFileToAll --
#   
#       Transfers a file to all remote servers. It needs some negotiation to 
#       work.
#       
# Arguments:
#       wtop
#       fileName   the local path to the file to be put.
#       where = "remote" or "all": put only to remote clients.
#       where = ip number: put only to this remote client.
#       opts      a list of '-key value' pairs, where most keys correspond 
#                 to a valid "canvas create" option, and everything is on 
#                 a single line.

proc ::PutFileIface::PutFileToAll {wtop fileName where {opts {}}} {
    global  allIPnumsToSend prefs this
    
    Debug 2 "+PutFile:: fileName=$fileName, opts=$opts"
    
    if {[llength $allIPnumsToSend] == 0} {
	return
    }
    
    # Add an alternative way of getting this file via an URL.
    set relPath [filerelative $prefs(httpdRootDir) $fileName]
    set relPath [uriencode::quotepath $relPath]
    set ip [::Network::GetThisOutsideIPAddress]
    array set optArr $opts
    array set optArr [list -url "http://${ip}:$prefs(httpdPort)/$relPath"]
    set opts [array get optArr]
        
    # If we are a server in a client-server we need to ask the client
    # to get the file by sending a PUT NEW instruction to it on our
    # primary connection.
    
    switch -- $prefs(protocol) {
	server {
    
	    # Translate tcl type '-key value' list to 'Key: value' option list.
	    set optList [::Import::GetTransportSyntaxOptsFromTcl $opts]
	    set relFilePath [filerelative $this(path) $fileName]
	    set relFilePath [uriencode::quotepath $relFilePath]
	    set putCmd "PUT NEW: [list $relFilePath] $optList"
	    if {$where == "remote" || $where == "all"} {
		SendClientCommand $wtop $putCmd
	    } else {
		SendClientCommand $wtop $putCmd -ips $where
	    }
	}
	jabber {
	    
	    # Jabber is special and handled internally.
	    ::Jabber::PutFileAndSchedule $wtop $fileName $opts
	}
	default {
	    
	    # Make a list with all ip numbers to put file to.
	    switch -- $where {
		remote - all {
		    set allPutIP $allIPnumsToSend
		}
		default {
		    set allPutIP $where
		}    
	    }
    
	    # Translate tcl type '-key value' list to 'Key: value' option list.
	    set optList [::Import::GetTransportSyntaxOptsFromTcl $opts]
	    
	    # Loop over all connected servers or only the specified one.
	    foreach ip $allPutIP {
		::PutFileIface::PutFile $wtop $fileName $ip $optList
	    }
	}
    }
}

# PutFileIface::PutFile --
# 
#       Puts the given fileName to the specified ip address.

proc ::PutFileIface::PutFile {wtop fileName ip optList} {
    global  prefs
    variable uid
    
    # This must never fail (application/octet-stream as fallback).
    set mime [::Types::GetMimeTypeForFileName $fileName]
    
    # Get the remote (network) file name (no path, no uri encoding).
    set dstFile [::Types::GetFileTailAddSuffix $fileName]
    
    # Make local state array for convenient storage. 
    # Use 'variable' for permanent storage.
    set puttoken [namespace current]::[incr uid]
    variable $puttoken
    upvar 0 $puttoken putstate

    set putstate(wtop) $wtop
    set putstate(file) $fileName
    set putstate(tail) [file tail $fileName]
    set putstate(mime) $mime
    set putstate(ip) $ip
    set putstate(optlist) $optList
    
    if {[catch {
	::putfile::put $fileName $ip $prefs(remotePort)  \
	  -mimetype $mime -timeout $prefs(timeoutMillis) \
	  -optlist $optList -filetail $dstFile  \
	  -progress [list [namespace current]::PutProgress $puttoken] \
	  -command [list [namespace current]::PutCommand $puttoken]
    } tok]} {
	tk_messageBox -title [::msgcat::mc {File Transfer Error}]  \
	  -type ok -message $tok
	unset putstate
    } else {
	set putstate(token) $tok
    }
}

# PutFileIface::PutProgress, ::PutFileIface::PutCommand
#
#	Callbacks for the putfile command.

proc ::PutFileIface::PutProgress {puttoken token total current} {
    global  tcl_platform
    upvar #0 $puttoken putstate          
 
    # Be silent... except for a necessary update command to not block.
    if {[string equal $tcl_platform(platform) "windows"]} {
	update
    } else {
	update idletasks
    }
}

proc ::PutFileIface::PutCommand {puttoken token what msg} {
    global  prefs
    upvar #0 $puttoken putstate          
    
    Debug 2 "+      PutCommand:: token=$token, what=$what msg=$msg"

    set wtop $putstate(wtop)

    if {[string equal $what "error"]} {
	set ncode [::putfile::ncode $token]
	set codetxt [::putfile::ncodetotext $ncode]
	
	# Depending on the flavour of the return code do different things.
	if {$prefs(talkative) >= 1} {
	    tk_messageBox -title [::msgcat::mc {Put File Error}]  \
	      -type ok -message $msg
	} else {
	    
	    # The 'msg' is typically a low level error msg.
	    switch -- $ncode {
		320 - 321 - 323 {
		    ::UI::SetStatusMessage $wtop $msg
		} 
		default {
		    set errmsg "Failed while putting file \"$putstate(tail)\""
		    if {$prefs(talkative) >= 1} {
			tk_messageBox -title [::msgcat::mc {Put File Error}] \
			  -type ok -message $errmsg
		    }
		    ::UI::SetStatusMessage $wtop $errmsg
		}		
	    }
	}
	unset putstate
    } elseif {[string equal $what "ok"]} {
	::UI::SetStatusMessage $wtop $msg
	if {[::putfile::status $token] == "ok"} {
	    ::putfile::cleanup $token
	    unset putstate
	}
    }
}

# PutFileIface::PutFileToClient --
# 
#       Inits a put operation on an already open socket as a response to a 
#       GET request received by the server.
#    
# Arguments:
#       s                 the socket.
#       ip                its ip number.
#       relativeFilePath  the optionally relative path pointing to the file.
#       opts      a list of '-key value' pairs, where most keys correspond 
#                 to a valid "canvas create" option, and everything is on 
#                 a single line.
#       
# Results:
#    none.

proc ::PutFileIface::PutFileToClient {wtop s ip relativeFilePath opts} {
    global  tclwbProtMsg this
    variable uid
    
    Debug 2 "+      PutFileToClient:: s=$s, ip=$ip,\
      relativeFilePath=$relativeFilePath"
    
    # Need to find the absolute path to 'relativeFilePath' with respect to
    # our base directory 'this(path)'.
    set fileName [addabsolutepathwithrelative $this(path) $relativeFilePath]
    
    # This must never fail (application/octet-stream as fallback).
    set mime [::Types::GetMimeTypeForFileName $fileName]
    
    # Translate tcl type '-key value' list to 'Key: value' option list.
    set optList [::Import::GetTransportSyntaxOptsFromTcl $opts]
    
    # Make local state array for convenient storage. 
    # Use 'variable' for permanent storage.
    set puttoken [namespace current]::[incr uid]
    variable $puttoken
    upvar 0 $puttoken putstate

    set putstate(wtop) $wtop
    set putstate(file) $fileName
    set putstate(tail) [file tail $fileName]
    set putstate(mime) $mime
    set putstate(ip) $ip
    set putstate(optlist) $optList
    
    # And finally...
    if {[catch {
	::putfile::puttoclient $s $fileName        \
	  -mimetype $mime -optlist $optList        \
	  -progress ::PutFileIface::PutProgress    \
	  -command [list ::PutFileIface::PutCommand $wtop]
    } tok]} {
	tk_messageBox -title [::msgcat::mc {File Transfer Error}] \
	  -type ok -message $tok
	unset putstate
    } else {
	set putstate(token) $tok
    }
}

# CancelAll --
#
#   It is supposed to stop every put operation taking place.
#   This may happen when the user presses a stop button or something.
#   

proc ::PutFileIface::CancelAll { } {

    Debug 2 "+::PutFileIface::CancelAll"
    
    # Close and clean up.
    set puttokenList [concat  \
      [info vars ::PutFileIface::\[0-9\]] \
      [info vars ::PutFileIface::\[0-9\]\[0-9\]] \
      [info vars ::PutFileIface::\[0-9\]\[0-9\]\[0-9\]]]
    
    foreach puttoken $puttokenList {
	upvar #0 $puttoken putstate          

	set tok $putstate(token)
	putfile::reset $tok
	putfile::cleanup $tok
	unset putstate
    }
}

proc ::PutFileIface::CancelAllWtop {wtop} {

    Debug 2 "+::PutFileIface::CancelAllWtop wtop=$wtop"
    
    # Close and clean up.
    set puttokenList [concat  \
      [info vars ::PutFileIface::\[0-9\]] \
      [info vars ::PutFileIface::\[0-9\]\[0-9\]] \
      [info vars ::PutFileIface::\[0-9\]\[0-9\]\[0-9\]]]
    
    foreach puttoken $puttokenList {
	upvar #0 $puttoken putstate          

	if {[info exists putstate(wtop)] &&  \
	  [string equal $putstate(wtop) $wtop]} {
	    set tok $putstate(token)
	    putfile::reset $tok
	    putfile::cleanup $tok
	    unset putstate
	}
    }
}

#-------------------------------------------------------------------------------
