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
# $Id: PutFileIface.tcl,v 1.2 2003-01-11 16:16:09 matben Exp $

package require putfile
package require uriencode

namespace eval ::PutFileIface:: {
    
    # Internal vars only.
    variable putTokenList {}
}

# PutFileIface::PutFileDlg --
#
#       Opens a file in a dialog and lets 'PutFile' do the job of transferring
#       the file to all other clients.

proc ::PutFileIface::PutFileDlg {wtop} {
    global  allIPnumsToSend typelistImageMovie typelistText
    
    if {[llength $allIPnumsToSend] == 0} {
	return
    }
    
    # In the dialog we need all entries from 'typelistImageMovie', but also
    # the standard text files.
    
    set typelist [concat $typelistText $typelistImageMovie]
    set ans [tk_getOpenFile -title [::msgcat::mc {Put Image/Movie}] -filetypes $typelist]
    if {$ans == ""} {
	return
    }
    set fileName $ans
    
    # Do the actual putting once the file is chosen. 
    PutFile $wtop $fileName "all"
}

# PutFileIface::PutFile --
#   
#       Transfers a file to all remote servers. It needs some negotiation to 
#       work.
#       
# Arguments:
#       wtop
#       fileName   the path to the file to be put.
#       where = "remote" or "all": put only to remote clients.
#       where = ip number: put only to this remote client.
#   
#       'optList'  a list of 'key: value' pairs, resembling the html 
#                  protocol for getting files, but where most keys correspond
#                  to a valid "canvas create" option.

proc ::PutFileIface::PutFile {wtop fileName where {optList {}}} {
    global  allIPnumsToSend prefs this
    
    variable putTokenList
    
    Debug 2 "+PutFile:: fileName=$fileName, optList=$optList"
    
    if {[llength $allIPnumsToSend] == 0} {
	return
    }
    
    # Add an alternative way of getting this file via an URL.
    set relPath [filerelative $prefs(httpdBaseDir) $fileName]
    set relPath [uriencode::quotepath $relPath]
    lappend optList  \
      "Get-Url:" "http://$this(ipnum):$prefs(httpdPort)/$relPath"
        
    # If we are a server in a client-server we need to ask the client
    # to get the file by sending a PUT NEW instruction to it on our
    # primary connection.
    switch -- $prefs(protocol) {
	server {
	    set relFilePath [filerelative $this(path) $fileName]
	    set putCmd "PUT NEW: [list $relFilePath] $optList"
	    if {$where == "remote" || $where == "all"} {
		SendClientCommand $wtop $putCmd
	    } else {
		SendClientCommand $wtop $putCmd -ips $where
	    }
	}
	jabber {
	    
	    # Jabber is special and handled internally.
	    ::Jabber::PutFileAndSchedule $wtop $fileName $optList
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
    
	    # This must never fail (application/octet-stream as fallback).
	    set mime [GetMimeTypeFromFileName $fileName]
	
	    # Get the remote (network) file name (no path, no uri encoding).
	    set dstFile [NativeToNetworkFileName $fileName]
	    
	    # Loop over all connected servers or only the specified one.
	    foreach ip $allPutIP {
		if {[catch {::putfile::put $fileName $ip $prefs(remotePort)  \
		  -mimetype $mime -timeout [expr 1000 * $prefs(timeout)]  \
		  -optlist $optList -filetail $dstFile  \
		  -progress ::PutFileIface::PutProgress  \
		  -command ::PutFileIface::PutCommand} tok]} {
		    tk_messageBox -title [::msgcat::mc {File Transfer Error}]  \
		      -type ok -message $tok
		} else {
		    lappend putTokenList $tok
		}
	    }
	}
    }
}

# PutFileIface::PutProgress, ::PutFileIface::PutCommand
#
#	Callbacks for the putfile command.

proc ::PutFileIface::PutProgress {token total current} {
 
    # Be silent... except for a necessary update command to not block.
    if {[string equal $::tcl_platform(platform) "windows"]} {
	update
    } else {
	update idletasks
    }
}

proc ::PutFileIface::PutCommand {token what msg} {
    global  prefs
    
    Debug 2 "+      PutCommand:: token=$token, what=$what msg=$msg"

    if {[string equal $what "error"]} {
	set ncode [::putfile::ncode $token]
	set codetxt [putfile::ncodetotext $ncode]

	# Depending on the flavour of the return code do different things.
	if {$prefs(talkative) >= 1} {
	    tk_messageBox -title [::msgcat::mc {Put File Error}]  \
	      -type ok -message "$msg. $codetxt"
	} else {
	    ::UI::SetStatusMessage . "$msg $codetxt"
	    switch -- $ncode {
		320 - 323 {
		    # empty
		} 
		default {
		    tk_messageBox -title [::msgcat::mc {Put File Error}] \
		      -type ok -message "$msg. $codetxt"
		}		
	    }
	}
    } elseif {[string equal $what "ok"]} {
	::UI::SetStatusMessage . $msg
	if {[::putfile::status $token] == "ok"} {
	    ::putfile::cleanup $token
	}
    }
    update
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
#       
# Results:
#    none.

proc ::PutFileIface::PutFileToClient {s ip relativeFilePath optList} {
    global  tclwbProtMsg this chunkSize mimeTypeIsText
    
    variable putTokenList
    
    Debug 2 "+      PutFileToClient:: s=$s, ip=$ip,\
      relativeFilePath=$relativeFilePath"
    
    # Need to find the absolute path to 'relativeFilePath' with respect to
    # our base directory 'this(path)'.
    set filePath [addabsolutepathwithrelative $this(path) $relativeFilePath]
    
    # This must never fail (application/octet-stream as fallback).
    set mime [GetMimeTypeFromFileName $filePath]
    
    # And finally...    
    if {[catch {::putfile::puttoclient $s $filePath  \
      -mimetype $mime -optlist $optList  \
      -progress ::PutFileIface::PutProgress  \
      -command ::PutFileIface::PutCommand} tok]} {
	tk_messageBox -title [::msgcat::mc {File Transfer Error}] \
	  -type ok -message $tok
    } else {
	lappend putTokenList $tok
    }
}

#   CancelAll ---
#
#   It is supposed to stop every put operation taking place.
#   This may happen when the user presses a stop button or something.
#   

proc ::PutFileIface::CancelAll { } {
    variable putTokenList

    Debug 2 "+::PutFileIface::CancelAll"
    
    # Close and clean up.

}

#-------------------------------------------------------------------------------
