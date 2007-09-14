# PutFileIface.tcl --
#  
#       This file is part of The Coccinella application. It contains a number
#       of procedures for performing a put operation over the network from
#       a disk file.
#      
#  Copyright (c) 2002-2005  Mats Bengtsson
#  
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#  
# $Id: PutFileIface.tcl,v 1.9 2007-09-14 13:17:09 matben Exp $

package require putfile
package require uriencode

package provide PutFileIface 1.0

namespace eval ::PutFileIface:: {
    
    # Internal vars only.
    variable uid 0
}

# PutFileIface::PutFile --
# 
#       Puts the given fileName to the specified ip address.

proc ::PutFileIface::PutFile {w fileName ip optList} {
    global  prefs
    variable uid
    
    ::Debug 2 "::PutFileIface::PutFile fileName=$fileName, optList='$optList'"
    
    # This must never fail (application/octet-stream as fallback).
    set mime [::Types::GetMimeTypeForFileName $fileName]
    
    # Get the remote (network) file name (no path, no uri encoding).
    set dstFile [::Types::GetFileTailAddSuffix $fileName]
    
    # Make local state array for convenient storage. 
    # Use 'variable' for permanent storage.
    set puttoken [namespace current]::[incr uid]
    variable $puttoken
    upvar 0 $puttoken putstate

    set putstate(w)        $w
    set putstate(file)     $fileName
    set putstate(filetail) [file tail $fileName]
    set putstate(mime)     $mime
    set putstate(ip)       $ip
    set putstate(optlist)  $optList
    array set optArr $optList
    if {[info exists optArr(from:)]} {	
	set putstate(fromname) $optArr(from:)
    } else {
	set putstate(fromname) $ip
    }
    
    if {[catch {
	::putfile::put $fileName $ip $prefs(remotePort)  \
	  -mimetype $mime -timeout $prefs(timeoutMillis) \
	  -optlist $optList -filetail $dstFile  \
	  -progress [list [namespace current]::PutProgress $puttoken] \
	  -command [list [namespace current]::PutCommand $puttoken]
    } tok]} {
	::UI::MessageBox -title [mc Error] -type ok -message $tok
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
    upvar #0 $puttoken putstate          
    
    Debug 2 "+\t\tPutCommand:: token=$token, what=$what msg=$msg"

    set w $putstate(w)
    set str [::PutFileIface::FormatMessage $puttoken $msg]
    
    if {[string equal $what "error"]} {
	set ncode   [::putfile::ncode $token]
	set codetxt [::putfile::ncodetotext $ncode]
	
	# Depending on the flavour of the return code do different things.
	if {$::config(talkative) >= 1} {
	    ::UI::MessageBox -title [mc Error] -type ok -message $str
	} else {
	    
	    # The 'msg' is typically a low level error msg.
	    switch -- $ncode {
		320 - 321 - 323 {
		    ::WB::SetStatusMessage $w $str
		} 
		default {
		    set errmsg "Failed while putting file \"$putstate(filetail)\""
		    if {$::config(talkative) >= 1} {
			::UI::MessageBox -title [mc Error] \
			  -type ok -message $errmsg
		    }
		    ::WB::SetStatusMessage $w $errmsg
		}		
	    }
	}
	unset putstate
    } elseif {[string equal $what "ok"]} {
	::WB::SetStatusMessage $w $str
	if {[::putfile::status $token] eq "ok"} {
	    ::putfile::cleanup $token
	    unset putstate
	}
    }
}

# PutFileIface::FormatMessage --
# 
#       Translate to readable message.

proc ::PutFileIface::FormatMessage {puttoken msg} {
    upvar #0 $puttoken putstate          
    
    set pars {}
    set doformat 1
    
    # There are basically only two parameters to the strings: file and from.
    # This makes total four possible combinations.
    
    switch -regexp -- $msg {
	contacting - eoferr - negotiate - readerr - unknownprot - ended - \
	  neterr - connerr {
	    lappend pars $putstate(fromname)
	}
	finished {
	    lappend pars $putstate(filetail) $putstate(fromname)
	}
	starts {
	    lappend pars $putstate(fromname) $putstate(filetail)
	}
	[0-9]* {
	    set codetxt [::putfile::ncodetotext $msg]
	    set msg [mc putnot200 $putstate(fromname) $msg $codetxt]
	    set doformat 0
	}
	default {
	    set doformat 0
	}
    }    
    if {$doformat} {
	set str [eval {mc put${msg}} $pars]
    } else {
	set str $msg
    }
    return $str
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

proc ::PutFileIface::PutFileToClient {w s ip relativeFilePath opts} {
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

    set putstate(w)        $w
    set putstate(file)     $fileName
    set putstate(filetail) [file tail $fileName]
    set putstate(mime)     $mime
    set putstate(ip)       $ip
    set putstate(optlist)  $optList
    
    # And finally...
    if {[catch {
	::putfile::puttoclient $s $fileName        \
	  -mimetype $mime -optlist $optList        \
	  -progress ::PutFileIface::PutProgress    \
	  -command [list ::PutFileIface::PutCommand $w]
    } tok]} {
	::UI::MessageBox -title [mc {File Transfer Error}] \
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

proc ::PutFileIface::CancelAllWtop {w} {

    Debug 2 "+::PutFileIface::CancelAllWtop w=$w"
    
    # Close and clean up.
    set puttokenList [concat  \
      [info vars ::PutFileIface::\[0-9\]] \
      [info vars ::PutFileIface::\[0-9\]\[0-9\]] \
      [info vars ::PutFileIface::\[0-9\]\[0-9\]\[0-9\]]]
    
    foreach puttoken $puttokenList {
	upvar #0 $puttoken putstate          

	if {[info exists putstate(w)] &&  \
	  [string equal $putstate(w) $w]} {
	    set tok $putstate(token)
	    putfile::reset $tok
	    putfile::cleanup $tok
	    unset putstate
	}
    }
}

#-------------------------------------------------------------------------------
