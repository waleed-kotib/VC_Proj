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
# $Id: PutFileIface.tcl,v 1.7 2003-08-23 07:19:16 matben Exp $

package require putfile
package require uriencode

namespace eval ::PutFileIface:: {
    
    # Internal vars only.
    variable putSessionArr
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
    
    # In the dialog we need all entries from 'typelistImageMovie', but also
    # the standard text files.
    
    set typelist [concat $typelistText $typelistImageMovie]
    set ans [tk_getOpenFile -title [::msgcat::mc {Put Image/Movie}] \
      -filetypes [::Plugins::GetTypeListDialogOption]]
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
#       fileName   the local path to the file to be put.
#       where = "remote" or "all": put only to remote clients.
#       where = ip number: put only to this remote client.
#   
#       'optList'  a list of 'key: value' pairs, resembling the html 
#                  protocol for getting files, but where most keys correspond
#                  to a valid "canvas create" option.

proc ::PutFileIface::PutFile {wtop fileName where {optList {}}} {
    global  allIPnumsToSend prefs this
    
    Debug 2 "+PutFile:: fileName=$fileName, optList=$optList"
    
    if {[llength $allIPnumsToSend] == 0} {
	return
    }
    
    # Add an alternative way of getting this file via an URL.
    set relPath [filerelative $prefs(httpdRootDir) $fileName]
    set relPath [uriencode::quotepath $relPath]
    set ip [::Network::GetThisOutsideIPAddress]
    lappend optList  \
      "Get-Url:" "http://${ip}:$prefs(httpdPort)/$relPath"
        
    # If we are a server in a client-server we need to ask the client
    # to get the file by sending a PUT NEW instruction to it on our
    # primary connection.
    switch -- $prefs(protocol) {
	server {
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
	    set mime [::Types::GetMimeTypeForFileName $fileName]
	
	    # Get the remote (network) file name (no path, no uri encoding).
	    set dstFile [::Types::GetFileTailAddSuffix $fileName]
	    
	    # Loop over all connected servers or only the specified one.
	    foreach ip $allPutIP {
		if {[catch {
		    ::putfile::put $fileName $ip $prefs(remotePort)  \
		      -mimetype $mime -timeout $prefs(timeoutMillis) \
		      -optlist $optList -filetail $dstFile  \
		      -progress [namespace current]::PutProgress  \
		      -command [list [namespace current]::PutCommand $wtop]
		} tok]} {
		    tk_messageBox -title [::msgcat::mc {File Transfer Error}]  \
		      -type ok -message $tok
		} else {
		    ::PutFileIface::RegisterPutSession $tok $wtop
		}
	    }
	}
    }
}

# PutFileIface::PutProgress, ::PutFileIface::PutCommand
#
#	Callbacks for the putfile command.

proc ::PutFileIface::PutProgress {token total current} {
    global  tcl_platform
 
    # Be silent... except for a necessary update command to not block.
    if {[string equal $tcl_platform(platform) "windows"]} {
	update
    } else {
	update idletasks
    }
}

proc ::PutFileIface::PutCommand {wtop token what msg} {
    global  prefs
    
    Debug 2 "+      PutCommand:: token=$token, what=$what msg=$msg"

    if {[string equal $what "error"]} {
	set ncode [::putfile::ncode $token]
	set codetxt [::putfile::ncodetotext $ncode]

	# Depending on the flavour of the return code do different things.
	if {$prefs(talkative) >= 1} {
	    tk_messageBox -title [::msgcat::mc {Put File Error}]  \
	      -type ok -message $msg
	} else {
	    ::UI::SetStatusMessage $wtop $msg
	    switch -- $ncode {
		320 - 323 {
		    # empty
		} 
		default {
		    if {$prefs(talkative) >= 1} {
			tk_messageBox -title [::msgcat::mc {Put File Error}] \
			  -type ok -message $msg
		    }
		}		
	    }
	}
    } elseif {[string equal $what "ok"]} {
	::UI::SetStatusMessage $wtop $msg
	if {[::putfile::status $token] == "ok"} {
	    ::putfile::cleanup $token
	    ::PutFileIface::DeRegisterPutSession $token
	}
    }
    #update
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

proc ::PutFileIface::PutFileToClient {wtop s ip relativeFilePath optList} {
    global  tclwbProtMsg this
    
    Debug 2 "+      PutFileToClient:: s=$s, ip=$ip,\
      relativeFilePath=$relativeFilePath"
    
    # Need to find the absolute path to 'relativeFilePath' with respect to
    # our base directory 'this(path)'.
    set filePath [addabsolutepathwithrelative $this(path) $relativeFilePath]
    
    # This must never fail (application/octet-stream as fallback).
    set mime [::Types::GetMimeTypeForFileName $filePath]
    
    # And finally...    
    if {[catch {
	::putfile::puttoclient $s $filePath        \
	  -mimetype $mime -optlist $optList        \
	  -progress ::PutFileIface::PutProgress    \
	  -command [list ::PutFileIface::PutCommand $wtop]
    } tok]} {
	tk_messageBox -title [::msgcat::mc {File Transfer Error}] \
	  -type ok -message $tok
    } else {
	::PutFileIface::RegisterPutSession $tok $wtop
    }
}

# PutFileIface::RegisterPutSession, DeRegisterPutSession --
# 
#       Keeps track of ongoing put sessions.

proc ::PutFileIface::RegisterPutSession {token wtop} {
    variable putSessionArr
    
    set putSessionArr($wtop,token) $token
    set putSessionArr($token,wtop) $wtop
}

proc ::PutFileIface::DeRegisterPutSession {token} {
    variable putSessionArr
    
    catch {
	set wtop $putSessionArr($token,wtop)
	unset putSessionArr($wtop,token)
	unset putSessionArr($token,wtop)
    }
}

# CancelAll --
#
#   It is supposed to stop every put operation taking place.
#   This may happen when the user presses a stop button or something.
#   

proc ::PutFileIface::CancelAll { } {
    variable putSessionArr

    Debug 2 "+::PutFileIface::CancelAll"
    
    # Close and clean up.
    foreach {key tok} [array get putSessionArr "*,token"] {
	putfile::reset $tok
	putfile::cleanup $tok
	::PutFileIface::DeRegisterPutSession $tok
    }
}

proc ::PutFileIface::CancelAllWtop {wtop} {
    variable putSessionArr

    Debug 2 "+::PutFileIface::CancelAllWtop wtop=$wtop"
    
    # Close and clean up.
    foreach {key tok} [array get putSessionArr "${wtop},token"] {
	putfile::reset $tok
	putfile::cleanup $tok
	::PutFileIface::DeRegisterPutSession $tok
    }
}

#-------------------------------------------------------------------------------
