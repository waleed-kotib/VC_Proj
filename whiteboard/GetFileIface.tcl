# GetFileIface.tcl --
#  
#       This file is part of The Coccinella application. It contains a number
#       of procedures for performing a get operation over the network.
#       They are mainly interfaces to the 'getfile' package to provide GUI.
#      
#  Copyright (c) 2003  Mats Bengtsson
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
# $Id: GetFileIface.tcl,v 1.17 2008-06-11 08:12:05 matben Exp $

package require getfile
package require uriencode

package provide GetFileIface 1.0

namespace eval ::GetFileIface:: {
    
    # Internal vars only.
    variable uid 0
    variable noErr 0
}

# GetFileIface::GetFile --
# 
#       Used by server for getting a file from client to our disk.
#       Wrapper around 'getfile::get' for handling UI etc.
#       
# Arguments:
#       w          toplevel widget path
#       sock
#       fileName   the file name (tail), uri encoded.
#       opts       is a list of '-key value' pairs that contains additional 
#                  information.

proc ::GetFileIface::GetFile {w sock fileName opts} {
    global prefs wDlgs
    variable uid
    variable noErr
        
    ::Debug 2 "::GetFileIface::GetFile w=$w, fileName=$fileName"
    
    array set optArr $opts    
    if {[info exists optArr(-mime)]} {
	set mime $optArr(-mime)
    } else {
	set mime [::Types::GetMimeTypeForFileName $fileName]
    }
    if {[info exists optArr(-size)]} {
	set size $optArr(-size)
    } else {
	set size 0
    }
    
    # Unquote the disallowed characters according to the RFC for URN scheme.
    # ref: RFC2141 sec2.2
    set fileTail [::uri::urn::unquote $fileName]

    # We store file names with cached names to avoid name clashes.
    set dstpath [::FileCache::MakeCacheFileName $fileTail]
        
    # Make local state array for convenient storage. 
    # Use 'variable' for permanent storage.
    set gettoken [namespace current]::[incr uid]
    variable $gettoken
    upvar 0 $gettoken getstate
    
    set getstate(w)           $w
    set getstate(can)         [::WB::GetCanvasFromWtop $w]
    set getstate(sock)        $sock
    set getstate(filetail)    $fileTail
    set getstate(dstpath)     $dstpath
    set getstate(optlist)     $opts
    set getstate(mime)        $mime
    set getstate(file)        $fileName
    set getstate(firstmillis) [clock clicks -milliseconds]
    set getstate(lastmillis)  $getstate(firstmillis)
    set getstate(wprog)       $wDlgs(prog)${uid}
    set getstate(timingtok)   $gettoken
    if {[info exists optArr(-url)]} {
	set getstate(url) $optArr(-url)
    }
    
    # Check if this file is cached already, http transported instead,
    # or if you user wants something different. May modify 'getstate(dstpath)'!
    set code [::GetFileIface::Prepare $gettoken $fileTail $mime $opts]
    
    ::Debug 2 "\t code=$code"
        
    if {$code != $noErr} {
	
	switch -- $code {
	    320 - 323 {
		# Empty; 320: cached; 323: via url
	    }
	    default {
		::GetFileIface::NewBrokenImage $code $gettoken
	    }
	}
	catch {
	    puts $sock "TCLWB/1.0 $code [getfile::ncodetotext $code]"
	    flush $sock
	    close $sock
	}
	unset getstate
	return
    } 

    # Do get the file.
    if {[catch {
	::getfile::get $sock $getstate(dstpath)  \
	  -mimetype $mime -size $size -displayname $fileTail  \
	  -progress [list [namespace current]::Progress $gettoken] \
	  -command  [list [namespace current]::Command $gettoken]
    } token]} {
	::Debug 2 "\t ::getfile::get failed: $token"
	set str [::GetFileIface::FormatMessage $gettoken $token]
	::UI::MessageBox -title [mc "File Transfer Error"]  \
	  -type ok -message $str
	unset getstate
	return
    }
    set getstate(token)    $token
    if {[info exists optArr(-from)]} {	
	set getstate(fromname) $optArr(-from)
    } else {
	set getstate(peername) [fconfigure $sock -peername]
	set getstate(fromname) [lindex $getstate(peername) 1]
    }
}

# GetFileIface::GetFileFromServer --
#
#       Initializes a get operation to get a file from a remote server.
#       Thus, we open a fresh socket to a server. The initiative for this
#       get operation is solely ours.
#       Open new temporary socket only for this get operation.
#       
# Arguments:
#       w          toplevel widget path
#       ip         the ip number of the remote server.
#       port
#       path       It must be a pathname relative the servers base 
#                  directory including any ../ if up dir. 
#                  Keep it a unix path style. uri encoded!
#       opts       is a list of '-key value' pairs that contains additional 
#                  information.

proc ::GetFileIface::GetFileFromServer {w ip port path opts} {
    global prefs wDlgs
    variable uid
    variable noErr
    
    ::Debug 2 "::GetFileIface::GetFileFromServer w=$w, path=$path"
    
    array set optArr $opts
    
    if {[info exists optArr(-mime)]} {
	set mime $optArr(-mime)
    } else {
	set mime [::Types::GetMimeTypeForFileName $path]
    }
    if {[info exists optArr(-size)]} {
	set size $optArr(-size)
    } else {
	set size 0
    }
    
    # Unquote the disallowed characters according to the RFC for URN scheme.
    # ref: RFC2141 sec2.2
    set fileTail [::uri::urn::unquote [file tail $path]]

    # We store file names with cached names to avoid name clashes.
    set dstpath [::FileCache::MakeCacheFileName $fileTail]

    # Make local state array for convenient storage. 
    # Use 'variable' for permanent storage.
    set gettoken [namespace current]::[incr uid]
    variable $gettoken
    upvar 0 $gettoken getstate
    
    set getstate(w)          $w
    set getstate(can)        [::WB::GetCanvasFromWtop $w]
    set getstate(filetail)   $fileTail
    set getstate(dstpath)    $dstpath
    set getstate(optlist)    $opts
    set getstate(mime)       $mime
    set getstate(file)       $path
    set getstate(firstmillis) [clock clicks -milliseconds]
    set getstate(lastmillis) $getstate(firstmillis)
    set getstate(wprog)      $wDlgs(prog)${uid}
    set getstate(timingtok)  $gettoken
    
    # Check if this file is cached already, http transported instead,
    # or if you user wants something different. May modify 'getstate(dstpath)'!
    set code [::GetFileIface::Prepare $gettoken $fileTail $mime $opts]
    ::Debug 2 "     code=$code"

    
    if {$code != $noErr} {
	switch -- $code {
	    320 - 323 {
		# Empty; 320: cached; 323: via url
	    }
	    default {
		::GetFileIface::NewBrokenImage $code $gettoken
	    }
	}
	unset getstate
	return
    } 

    # Do get the file.
    if {[catch {
	getfile::getfromserver $path $dstpath $ip $port  \
	  -mimetype $mime -size $size -displayname $fileTail  \
	  -progress [list [namespace current]::Progress $gettoken] \
	  -command [list [namespace current]::Command $gettoken]
    } token]} {
	set msg [mc "File Transfer Error"]
	::UI::MessageBox -title [mc "File Transfer Error"]  \
	  -type ok -message $token
	unset getstate
	return
    }
    set getstate(token) $token
    if {[info exists optArr(-from)]} {	
	set getstate(fromname) $optArr(-from)
    } else {
	set getstate(fromname) $ip
    }
}

# GetFileIface::Prepare --
#
#       Checks if the file 'fileTail' should be received. 
#       Rejects if: 
#            1): mime type not supported, 
#            2): user rejects it
#            3): if cached, 
#            4): is supported via 'url' instead.
#            
# Arguments:
#       gettoken
#       fileTail   the uri decoded file tail
#       mime
#       opts
#                 
# Results:
#       a three number error code indicating the type of error, or noErr (0). 
#       May modify 'gettoken(dstpath)'!

proc ::GetFileIface::Prepare {gettoken fileTail mime opts} {
    global  prefs  this
    variable noErr
    upvar #0 $gettoken getstate          

    array set optArr $opts
   	
    set doWhat [::Plugins::GetDoWhatForMime $mime]
    if {$doWhat eq ""} {
	return 321
    }
    
    switch -- $doWhat {
	reject - unavailable {

	    # 1: Check if the MIME type is supported or if it should be rejected.
	    return 321
	}
	ask {
	    
	    # 2: Ask user what to do with it.
	    set ans [::UI::MessageBox -title [mc "Request To User"] \
	      -type yesno -default yes -message [mc "We are about to receive the file %s. Do you want to receive it?" $fileTail]]
	    if {[string equal $ans "no"]} {
		return 321
	    } else {
		set ans [tk_chooseDirectory -initialdir $prefs(incomingPath) \
		  -title [mc "Open Folder"]]]
		if {$ans eq ""} {
		    return 321
		} else {
		    set getstate(dstpath) [file join $ans $fileTail]
		}
	    }
	} 
	save {
	    # Do nothin.
	}
    }
    
    # 3: Check if the file is cached, and not too old.
    
    if {[info exists optArr(-url)]} {
	set url $optArr(-url)
	if {[::FileCache::IsCached $url]} {
	    set cachedFile [::FileCache::Get $url]
	    
	    # Get the correct import procedure for this MIME type.
	    ::GetFileIface::DoImport $mime $opts -file $cachedFile -where local
	    return 320
	}
    }

    # Get the correct import procedure for this MIME type. Empty if nothing.
    if {![::Plugins::HaveImporterForMime $mime]} {
	return 321
    }
    
    # 4:
    # Check if the import package wants to get it via an URL instead.
    # But only if we have an option '-preferred-transport http'!!!
    
    set doHttpTransport 0    
    if {[info exists optArr(-preferred-transport)] && \
      [string equal $optArr(-preferred-transport) "http"]} {
	set packName [::Plugins::GetPreferredPackageForMime $mime]
      
	if {[::Plugins::HaveHTTPTransportForMimeAndPlugin $packName $mime]} {
	    set doHttpTransport 1
	}
    }
    
    if {$doHttpTransport} {
	
	# Need to get the "-url" key from the 'opts'.
	if {[info exists optArr(-url)]} {
	    ::GetFileIface::DoImport $mime $opts -url $optArr(-url)  \
	      -where "local"
	    return 323	    
	} else {
	    return 499
	}
    }
    return $noErr
}

# GetFileIface::Progress, Command --
#
#	Callbacks for the getfile command.

proc ::GetFileIface::Progress {gettoken token total current} {
    global  tcl_platform prefs
    
    upvar #0 $gettoken getstate          

    ::Debug 6 "::GetFileIface::Progress total=$total, current=$current"

    # Be silent... except for a necessary update command to not block.
    if {[string equal $tcl_platform(platform) "windows"]} {
	update
    } else {
	update idletasks
    }
    
    # Cache timing info.
    ::timing::setbytes $getstate(timingtok) $current

    # Update only when minimum time has passed, and only at certain interval.
    # Perhaps we should set a timer for 'millisToProgWin' instead?
    set ms [clock clicks -milliseconds]
    set wantProgWin [expr  \
      {$ms - $getstate(firstmillis) >= $prefs(millisToProgWin)} ? 1 : 0]
    if {$wantProgWin && ![winfo exists $getstate(wprog)]} {
	::GetFileIface::UpdateProgress $gettoken $total $current
    } elseif {[expr {$ms - $getstate(lastmillis)}] > $prefs(progUpdateMillis)} {
	set getstate(lastmillis) $ms	    
	::GetFileIface::UpdateProgress $gettoken $total $current
    }
}

# GetFileIface::Command --
# 
#       Command callback for the getfile package.

proc ::GetFileIface::Command {gettoken token what msg} {
    upvar #0 $gettoken getstate          
    
    ::Debug 2 "+\t\t::GetFileIface::Command token=$token, what=$what msg=$msg"

    set w $getstate(w)
    
    set str [::GetFileIface::FormatMessage $gettoken $msg]
    
    if {[string equal $what "error"]} {
	::WB::SetStatusMessage $w $str
	if {$::config(talkative) >= 1} {
	    ::UI::MessageBox -title [mc "Error"] -type ok -message $msg
	}
	
	# Perhaps we should show a broken image here???
	
	# Cleanup...
	catch {destroy $getstate(wprog)}
	catch {file delete $getstate(dstpath)}
	::timing::free $getstate(timingtok)
	unset getstate
	getfile::cleanup $token
    } elseif {[string equal $what "ok"]} {
	::WB::SetStatusMessage $w $str

	::Debug 3 "+        status=[::getfile::status $token]"
	if {[::getfile::status $token] eq "ok"} {
	    
	    # Finished and ok!
	    ::GetFileIface::DoImport $getstate(mime) $getstate(optlist)  \
	      -file $getstate(dstpath) -where "local"

	    # Add to the lists of known files.
	    if {[info exists getstate(url)]} {
		::FileCache::Set $getstate(url) $getstate(dstpath)
	    }	    
	    catch {destroy $getstate(wprog)}
	    ::timing::free $getstate(timingtok)
	    unset getstate
	    getfile::cleanup $token
	}
    }    
}

# GetFileIface::FormatMessage --
# 
#       Translate to readable message.

proc ::GetFileIface::FormatMessage {gettoken msg} {
    upvar #0 $gettoken getstate          
    
    set pars {}
    set doformat 1
    
    # There are basically only two parameters to the strings: file and from.
    # This makes total four possible combinations.
    
    switch -regexp -- $msg {
	contacting - eoferr - negotiate - readerr - unknownprot - ended - \
	  neterr - connerr {
	    lappend pars $getstate(fromname)
	}
	finished {
	    lappend pars $getstate(filetail) $getstate(fromname)
	} starts {
	    lappend pars $getstate(fromname) $getstate(filetail)
	}
	[0-9]* {
	    set codetext [getfile::ncodetotext $msg]
	    set msg [mc "Received response of the server %s.\n Error code %s\nMessage: %s" $getstate(fromname) $msg $codetext]
	    set doformat 0
	}
	default {
	    set doformat 0
	}
    }    
    if {$doformat} {
	switch -- $msg {
	    contacting	{set str [eval {mc "Contacting %s. Waiting for response"} $pars]...}
	    eoferr	{set str [eval {mc "Connection to %s failed: received an eof."} $pars]}
	    connerr	{set str [eval {mc "Connection to %s failed."} $pars]}
	    negotiate	{set str [eval {mc "Contacted %s. Negotiating"} $pars]...}
	    readerr	{set str [eval {mc "Cannot read server response from %s."} $pars]}
	    unknownprot	{set str [eval {mc "The server at %s did not respond with a well formed protocol."} $pars]}
	    starts	{set str [eval {mc "%s accepted file %s. Initiating file transfer"} $pars]...}
	    ended	{set str [eval {mc "Transfer from %s ended prematurely."} $pars]}
	    finished	{set str [eval {mc "Finished downloading file %s from %s."} $pars]...}
	    neterr	{set str [eval {mc "Cannot download from %s: network error."} $pars]}
	}
    } else {
	set str $msg
    }
    return $str
}

# GetFileIface::UpdateProgress
#
#       Typically called from the get callback procedure to handle the
#       progress window.
#
# Arguments:
#
#                 
# Results:
#       None.

proc ::GetFileIface::UpdateProgress {gettoken total current} {
    upvar #0 $gettoken getstate          
    
    set msg2 "From: $getstate(fromname)"
    append msg3 "Rate: [::timing::getmessage $getstate(timingtok) $total]"
    
    if {[winfo exists $getstate(wprog)]} {

	# Update the progress window.
	set percent [expr {100.0 * $current/($total + 1.0)}]
	$getstate(wprog) configuredelayed -percent $percent   \
	  -text2 $msg2 -text3 $msg3
    } else {
	
	# Create the progress window.
	::Debug 2 "::GetFileIface::UpdateProgress  create ProgWin"

	set str [mc "Writing file"]
	append str ": $getstate(filetail)"
	ui::progress::toplevel $getstate(wprog)  \
	  -text $str -text2 $msg2 -text3 $msg3   \
	  -menu [::JUI::GetMainMenu]              \
	  -cancelcommand [list [namespace current]::CancelCmd $gettoken]
    }
}

# GetFileIface::DoImport --
# 
#       Abstraction for importing an image etc. Non jabber just imports
#       into the main whiteboard, else let a dispatcher send entity to
#       the correct whiteboard.
#       

proc ::GetFileIface::DoImport {mime opts args} {
    eval {::JWB::DispatchToImporter $mime $opts} $args
}

# GetFileIface::NewBrokenImage --
# 
#       Wrapper for the NewBrokenImage call.

proc ::GetFileIface::NewBrokenImage {code gettoken} {
    upvar #0 $gettoken getstate     
          
    ::Debug 3 "::GetFileIface::NewBrokenImage"
    
    set msg "Failed importing $getstate(filetail): "
    append msg [getfile::ncodetotext $code]
    ::WB::SetStatusMessage $getstate(w) $msg

    set opts $getstate(optlist)
    array set optArr $getstate(optlist)
    if {![info exists optArr(-coords)]} {
	# Should never happen!
	return
    }

    eval {::Import::NewBrokenImage $getstate(can) $optArr(-coords)} $opts
}

# GetFileIface::CancelCmd, CancelAll, CancelAllWtop --
#
#   Are supposed to stop every put operation taking place.
#   This may happen when the user presses a stop button or something.

proc ::GetFileIface::CancelCmd {gettoken} {
    upvar #0 $gettoken getstate          

    ::Debug 2 "+::GetFileIface::CancelCmd"
    set tok $getstate(token)
    getfile::reset $tok
    getfile::cleanup $tok
    
    # Destroy any progress window.
    catch {destroy $getstate(wprog)}
    unset getstate
}

proc ::GetFileIface::CancelAll { } {

    ::Debug 2 "+::GetFileIface::CancelAll"
    
    # Close and clean up.
    set gettokenList [concat  \
      [info vars ::GetFileIface::\[0-9\]] \
      [info vars ::GetFileIface::\[0-9\]\[0-9\]] \
      [info vars ::GetFileIface::\[0-9\]\[0-9\]\[0-9\]]]
    
    foreach gettoken $gettokenList {
	upvar #0 $gettoken getstate          

	set tok $getstate(token)
	getfile::reset $tok
	getfile::cleanup $tok
	
	# Destroy any progress window.
	catch {destroy $getstate(wprog)}
	unset getstate
    }
}

proc ::GetFileIface::CancelAllWtop {w} {

    ::Debug 2 "+::GetFileIface::CancelAllWtop w=$w"
    
    # Close and clean up.
    set gettokenList [concat  \
      [info vars ::GetFileIface::\[0-9\]] \
      [info vars ::GetFileIface::\[0-9\]\[0-9\]] \
      [info vars ::GetFileIface::\[0-9\]\[0-9\]\[0-9\]]]
    
    foreach gettoken $gettokenList {
	upvar #0 $gettoken getstate          

	if {[info exists getstate(w)] &&  \
	  [string equal $getstate(w) $w]} {
	    set tok $getstate(token)
	    getfile::reset $tok
	    getfile::cleanup $tok

	    # Destroy any progress window.
	    catch {destroy $getstate(wprog)}
	    unset getstate
	}
    }
}

#-------------------------------------------------------------------------------
