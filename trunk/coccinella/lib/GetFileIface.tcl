# GetFileIface.tcl --
#  
#       This file is part of the whiteboard application. It contains a number
#       of procedures for performing a get operation over the network.
#       They are mainly interfaces to the 'getfile' package to provide GUI.
#      
#  Copyright (c) 2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: GetFileIface.tcl,v 1.2 2003-06-07 12:46:36 matben Exp $

package require getfile
package require uriencode

namespace eval ::GetFileIface:: {
    
    # Internal vars only.
    variable uid 0
}

# GetFileIface::GetFile --
# 
#       Used by server for getting a file from client to our disk.
#       Wrapper around 'getfile::get' for handling UI etc.
#       
# Arguments:
#       wtop       toplevel for whiteboard
#       sock
#       fileName   the file name (tail), uri encoded.
#       optList    is a list of key-value pairs that contains additional 
#                  information.

proc ::GetFileIface::GetFile {wtop sock fileName optList} {
    global prefs noErr wDlgs
    variable uid
    
    Debug 2 "::GetFileIface::GetFile wtop=$wtop, fileName=$fileName"
    
    array set optArr $optList
    
    if {[info exists optArr(Content-Type:)]} {
	set mime $optArr(Content-Type:)
    } else {
	set mime [::Types::GetMimeTypeForFileName $fileName]
    }
    if {[info exists optArr(size:)]} {
	set size $optArr(size:)
    } else {
	set size 0
    }
    
    # Unquote the disallowed characters according to the RFC for URN scheme.
    # ref: RFC2141 sec2.2
    set fileTail [::uriencode::decodefile $fileName]
    set dstpath [file join $prefs(incomingPath) $fileTail]   
        
    # Make local state array for convenient storage. 
    # Use 'variable' for permanent storage.
    set gettoken [namespace current]::[incr uid]
    variable $gettoken
    upvar 0 $gettoken getstate
    
    set getstate(wtop) $wtop
    set getstate(sock) $sock
    set getstate(filetail) $fileTail
    set getstate(dstpath) $dstpath
    set getstate(optlist) $optList
    set getstate(mime) $mime
    set getstate(file) $fileName
    set getstate(firstmillis) [clock clicks -milliseconds]
    set getstate(lastmillis) $getstate(firstmillis)
    set getstate(wprog) $wDlgs(prog)${uid}
    set getstate(timingkey) $gettoken
    
    # Check if this file is cached already, http transported instead,
    # or if you user wants something different. May modify 'getstate(dstpath)'!
    set code [::GetFileIface::Prepare $gettoken $fileTail $mime $optList]
    Debug 2 "     code=$code"
    
    if {$code != $noErr} {
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
	  -mimetype $mime -size $size  \
	  -progress [list [namespace current]::Progress $gettoken] \
	  -command [list [namespace current]::Command $gettoken]
    } token]} {
	tk_messageBox -title [::msgcat::mc {File Transfer Error}]  \
	  -type ok -message $token
	unset getstate
	return
    }
    set getstate(token) $token
    set getstate(peername) [fconfigure $sock -peername]
    if {[info exists optArr(from:)]} {	
	set getstate(fromname) $optArr(from:)
    } else {
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
#       wtop       toplevel for whiteboard
#       ip         the ip number of the remote server.
#       port
#       path       It must be a pathname relative the servers base 
#                  directory including any ../ if up dir. 
#                  Keep it a unix path style. uri encoded!
#       optList    is a list of key-value pairs that contains additional 
#                  information.

proc ::GetFileIface::GetFileFromServer {wtop ip port path optList} {
    global prefs wDlgs noErr
    variable uid
    
    Debug 2 "::GetFileIface::GetFileFromServer wtop=$wtop, path=$path"
    
    array set optArr $optList
    
    if {[info exists optArr(Content-Type:)]} {
	set mime $optArr(Content-Type:)
    } else {
	set mime [::Types::GetMimeTypeForFileName $path]
    }
    if {[info exists optArr(size:)]} {
	set size $optArr(size:)
    } else {
	set size 0
    }
    
    # Unquote the disallowed characters according to the RFC for URN scheme.
    # ref: RFC2141 sec2.2
    set fileTail [::uriencode::decodefile [file tail $path]]
    set dstpath [file join $prefs(incomingPath) $fileTail]   
        
    # Make local state array for convenient storage. 
    # Use 'variable' for permanent storage.
    set gettoken [namespace current]::[incr uid]
    variable $gettoken
    upvar 0 $gettoken getstate
    
    set getstate(wtop) $wtop
    set getstate(filetail) $fileTail
    set getstate(dstpath) $dstpath
    set getstate(optlist) $optList
    set getstate(mime) $mime
    set getstate(file) $path
    set getstate(firstmillis) [clock clicks -milliseconds]
    set getstate(lastmillis) $getstate(firstmillis)
    set getstate(wprog) $wDlgs(prog)${uid}
    set getstate(timingkey) $gettoken
    
    # Check if this file is cached already, http transported instead,
    # or if you user wants something different. May modify 'getstate(dstpath)'!
    set code [::GetFileIface::Prepare $gettoken $fileTail $mime $optList]
    Debug 2 "     code=$code"
    if {$code != $noErr} {
	unset getstate
	return
    } 

    # Do get the file.
    if {[catch {
	getfile::getfromserver $path $dstpath $ip $port  \
	  -mimetype $mime -size $size  \
	  -progress [list [namespace current]::Progress $gettoken] \
	  -command [list [namespace current]::Command $gettoken]
    } token]} {
	tk_messageBox -title [::msgcat::mc {File Transfer Error}]  \
	  -type ok -message $token
	unset getstate
	return
    }
    set getstate(token) $token
    if {[info exists optArr(from:)]} {	
	set getstate(fromname) $optArr(from:)
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
#                 
# Results:
#       a three number error code indicating the type of error, or noErr (0). 
#       May modify 'gettoken(dstpath)'!

proc ::GetFileIface::Prepare {gettoken fileTail mime optList} {
    global  prefs noErr this
    
    upvar #0 $gettoken getstate          

    array set optArr $optList
   	
    set doWhat [::Plugins::GetDoWhatForMime $mime]
    if {$doWhat == ""} {
	return 321
    }
    
    switch -- $doWhat {
	reject - unavailable {

	    # 1: Check if the MIME type is supported or if it should be rejected.
	    return 321
	}
	ask {
	    
	    # 2: Ask user what to do with it.
	    set ans [tk_messageBox -title [::msgcat::mc {Request To User}] \
	      -type yesno -default yes -message \
	      [FormatTextForMessageBox [::msgcat::mc messaskreceive $fileTail]]]
	    if {[string equal $ans "no"]} {
		return 321
	    } else {
		set ans [tk_chooseDirectory -initialdir $prefs(incomingPath) \
		  -title [::msgcat::mc {Pick Directory}]]
		if {[string length $ans] == 0} {
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
    
    if {[info exists optArr(Get-Url:)]} {
	set url $optArr(Get-Url:)
	if {[::FileCache::IsCached $url]} {
	    set cachedFile [::FileCache::Get $url]
	    
	    # Get the correct import procedure for this MIME type.
	    ::GetFileIface::DoImport $mime $optList -file $cachedFile -where local
	    return 320
	}
    }

    # Get the correct import procedure for this MIME type. Empty if nothing.
    if {![::Plugins::HaveImporterForMime $mime]} {
	return 321
    }
    
    # 4:
    # Check if the import package wants to get it via an URL instead.
    # But only if we have an option 'preferred-transport: http'!!!
    
    set doHttpTransport 0    
    if {[info exists optArr(preferred-transport:)] && \
      [string equal $optArr(preferred-transport:) "http"]} {
	set packName [::Plugins::GetPreferredPackageForMime $mime]
      
	if {[::Plugins::HaveHTTPTransportForMimeAndPlugin $packName $mime]} {
	    set doHttpTransport 1
	}
    }
    
    if {$doHttpTransport} {
	
	# Need to get the "Get-Url:" key from the optList.
	if {[info exists optArr(Get-Url:)]} {
	    ::GetFileIface::DoImport $mime $optList -url $optArr(Get-Url:)  \
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

    Debug 4 "::GetFileIface::Progress total=$total, current=$current"

    # Be silent... except for a necessary update command to not block.
    if {[string equal $tcl_platform(platform) "windows"]} {
	update
    } else {
	update idletasks
    }
    
    # Cache timing info.
    ::Timing::Set $getstate(timingkey) $current

    # Update only when minimum time has passed, and only at certain interval.
    # Perhaps we should set a timer for 'millisToProgWin' instead?
    set ms [clock clicks -milliseconds]
    set wantProgWin [expr  \
      {$ms - $getstate(firstmillis) >= $prefs(millisToProgWin)} ? 1 : 0]
    if {$wantProgWin && ![winfo exists $getstate(wprog)]} {
	::GetFileIface::UpdateProgress $gettoken $total $current
    } elseif {[expr $ms - $getstate(lastmillis)] > $prefs(millisProgUpdate)} {
	set getstate(lastmillis) $ms	    
	::GetFileIface::UpdateProgress $gettoken $total $current
    }
}

# GetFileIface::Command --
# 
#       Command callback for the getfile package.

proc ::GetFileIface::Command {gettoken token what msg} {
    global  prefs
    upvar #0 $gettoken getstate          
    
    Debug 2 "+      Command:: token=$token, what=$what msg=$msg"

    set wtop $getstate(wtop)
    
    if {[string equal $what "error"]} {
	::UI::SetStatusMessage $wtop $msg
	if {$prefs(talkative) >= 1} {
	    tk_messageBox -title [::msgcat::mc {Get File Error}] \
	      -type ok -message $msg
	}
	
	# Perhaps we should show a broken image here???
	
	# Cleanup...
	catch {destroy $getstate(wprog)}
	catch {file delete $getstate(dstpath)}
	::Timing::Reset $getstate(timingkey)
	unset getstate
	getfile::cleanup $token
    } elseif {[string equal $what "ok"]} {
	::UI::SetStatusMessage $wtop $msg

	Debug 3 "+        status=[::getfile::status $token]"
	if {[::getfile::status $token] == "ok"} {
	    
	    # Finished and ok!
	    ::GetFileIface::DoImport $getstate(mime) $getstate(optlist)  \
	      -file $getstate(dstpath) -where "local"
	    catch {destroy $getstate(wprog)}
	    ::Timing::Reset $getstate(timingkey)
	    unset getstate
	    getfile::cleanup $token
	}
    }    
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
    
    set msg "From: $getstate(fromname)\n"
    append msg "Rate: [::Timing::FormMessage $getstate(timingkey) $total]"
    
    if {[winfo exists $getstate(wprog)]} {

	# Update the progress window.
	set percent [expr 100.0 * $current/($total + 1.0)]
	$getstate(wprog) configure -percent $percent   \
	  -text2 $msg
    } else {
	
	# Create the progress window.
	Debug 2 "::GetFileIface::UpdateProgress  create ProgWin"

	::ProgressWindow::ProgressWindow $getstate(wprog) -name {Get File} \
	  -filename $getstate(filetail) -text2 $msg \
	  -cancelcmd [list [namespace current]::CancelCmd $gettoken]
    }
}

# GetFileIface::DoImport --
# 
#       Abstraction for importing an image etc. Non jabber just imports
#       into the main whiteboard, else let a dispatcher send entity to
#       the correct whiteboard.
#       

proc ::GetFileIface::DoImport {mime optList args} {
    global  prefs
    
    Debug 3 "+        ::GetFileIface::DoImport"

    if {[string equal $prefs(protocol) "jabber"]} {
	eval {::Jabber::WB::DispatchToImporter $mime $optList} $args
    } else {
	upvar ::.::wapp wapp

	if {[::Plugins::HaveImporterForMime $mime]} {
	    set errMsg [eval {
		::ImageAndMovie::DoImport $wapp(servCan) $optList
	    } $args]
	} else {
	    set errMsg "No importer for mime \"$mime\""
	}
	if {$errMsg != ""} {
	    tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	      -message "Failed importing: $errMsg"
	}
    }
}

# GetFileIface::CancelCmd, CancelAll, CancelAllWtop --
#
#   Are supposed to stop every put operation taking place.
#   This may happen when the user presses a stop button or something.

proc ::GetFileIface::CancelCmd {gettoken} {
    upvar #0 $gettoken getstate          

    Debug 2 "+::GetFileIface::CancelCmd"
    set tok $getstate(token)
    getfile::reset $tok
    getfile::cleanup $tok
    
    # Destroy any progress window.
    catch {destroy $getstate(wprog)}
    unset getstate
}

proc ::GetFileIface::CancelAll { } {

    Debug 2 "+::GetFileIface::CancelAll"
    
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

proc ::GetFileIface::CancelAllWtop {wtop} {

    Debug 2 "+::GetFileIface::CancelAllWtop wtop=$wtop"
    
    # Close and clean up.
    set gettokenList [concat  \
      [info vars ::GetFileIface::\[0-9\]] \
      [info vars ::GetFileIface::\[0-9\]\[0-9\]] \
      [info vars ::GetFileIface::\[0-9\]\[0-9\]\[0-9\]]]
    
    foreach gettoken $gettokenList {
	upvar #0 $gettoken getstate          

	parray getstate
	if {[info exists getstate(wtop)] &&  \
	  [string equal $getstate(wtop) $wtop]} {
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
