#  HttpTrpt.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It is a wrapper for httpex, timing, and ui::progress to isolate
#      the application from the details.
#      
#  Copyright (c) 2004-2005  Mats Bengtsson
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
# $Id: HttpTrpt.tcl,v 1.11 2007-09-15 13:16:12 matben Exp $

package require httpex
package require timing
package require uriencode
package require ui::progress

package provide HttpTrpt 1.0

namespace eval ::HttpTrpt:: {

    variable uid 0
    variable wbase .htrpt[clock clicks]
}

# HttpTrpt::Get --
# 
#       Initiates a http get operation. 
#       Returns a token if succesful, else empty.
#       All errors reported through -command.
#       
# Arguments:
#       url
#       fileName
#       opts:       ?-command, -dialog, -progressmessage, silent?
#       
# Results:
#       token if succesful so far, else empty.

proc ::HttpTrpt::Get {url fileName args} {
    global  prefs
    variable uid
    variable wbase
    
    ::Debug 2 "::HttpTrpt::Get url=$url, fileName=$fileName"
    
    array set opts {
	-command          ""
	-dialog           1
	-progressmessage  ""
	-silent           0
    }
    array set opts $args
    if {[catch {open $fileName w} fd]} {
	set errstr [mc jamessoobfailopen2 $fileName]
	if {$state(-command) != {}} {
	    uplevel #0 $state(-command) [list $token error $errstr]
	}
	if {!$state(-silent)} {
	    ::UI::MessageBox -title [mc Error] -icon error -type ok \
	      -message $errstr
	}
	return
    }

    # Create an array that holds the instance specific state.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state

    set w ${wbase}${uid}
    set state(fd)           $fd
    set state(w)            $w
    set state(timetok)      $fd
    set state(url)          $url
    set state(fileName)     $fileName
    set state(fileTailEnc)  [file tail [::Utils::GetFilePathFromUrl $url]]
    set state(fileTail)     [uriencode::decodefile $state(fileTailEnc)]
    set state(first)        1
    foreach {key value} [array get opts] {
	set state($key) $value
    }

    if {[catch {
	::httpex::get $url -channel $fd -timeout $prefs(timeoutMillis) \
	  -progress [list [namespace current]::Progress $token] \
	  -command  [list [namespace current]::Cmd $token]
    } httptoken]} {
	set errmsg [mc httptrpterror2 $state(fileTail) $httptoken]
	if {$state(-command) != {}} {
 	    uplevel #0 $state(-command) [list $token error $errmsg]
	}
	if {!$state(-silent)} {
	    ::UI::MessageBox -title [mc Error] -icon error -type ok \
	      -message $errmsg
	}
	return
    }
    set state(httptoken) $httptoken
    return $token
}

proc ::HttpTrpt::Progress {token httptoken total current} {
    upvar #0 $httptoken httpstate
    
    set state(httptoken) $httptoken

    # Investigate 'state' for any exceptions.
    set status [::httpex::status $httptoken]
    
    if {[string equal $status "error"]} {
	set errmsg [httpex::error $token]
	if {$state(-command) != {}} {
	    uplevel #0 $state(-command) [list $token error $errmsg]
	}
	if {$state(-progressmessage) != {}} {
	    uplevel #0 $state(-progressmessage) [list $errmsg]
	}
	if {!$state(-silent)} {
	    set str [mc httptrpterror2 $state(fileTail) $errmsg]
	    ::UI::MessageBox -title [mc Error] -icon error -type ok \
	      -message $str
	}
	Free $token
    } else {
	ProgressWindow $token $total $current
    }
}

proc ::HttpTrpt::ProgressWindow {token total current} {
    global  prefs tcl_platform
    variable $token
    upvar 0 $token state
   
    #puts "::HttpTrpt::ProgressWindow current=$current"

    # Cache timing info.
    ::timing::setbytes $state(timetok) $current

    # Update only when minimum time has passed, and only at certain interval.
    set ms [clock clicks -milliseconds]
    set needupdate 0
    set w $state(w)

    # Create progress dialog if not exists.
    if {$state(first)} {
	if {$state(-dialog) && ![winfo exists $w]} {
	    set str "[mc {Writing file}]: $state(fileTail)"
	    ui::progress::toplevel $w -text $str \
	      -menu [::UI::GetMainMenu]          \
	      -cancelcommand [list [namespace current]::CancelBt $token]
	    set needupdate 1
	}
	if {$state(-progressmessage) != {}} {
	    set msg "[mc Downloading] \"$state(fileTail)\""
	    uplevel #0 $state(-progressmessage) [list $msg]
	}
	set state(startmillis) $ms
	set state(lastmillis)  $ms
	set state(first) 0
    } elseif {[expr $ms - $state(lastmillis)] > $prefs(progUpdateMillis)} {

	# Update the progress window.
	set timsg [::timing::getmessage $state(timetok) $total]
	if {$state(-dialog)} {
	    set msg3 "[mc Rate]: $timsg"	
	    set percent [expr 100.0 * $current/($total + 0.001)]
	    $w configuredelayed -percent $percent -text2 $msg3
	    set needupdate 1
	}
	if {$state(-progressmessage) != {}} {
	    set msg "[mc Getting] \"$state(fileTail)\", $timsg"
	    uplevel #0 $state(-progressmessage) [list $msg]
	}
	set state(lastmillis) $ms
    }

    # Be silent... except for a necessary update command to not block.
    if {$needupdate} {
	if {[string equal $tcl_platform(platform) "windows"]} {
	    update
	} else {
	    update idletasks
	}
    }
}

# HttpTrpt::Cmd --
# 
#       Callback for the httpex package. Only when we are final.

proc ::HttpTrpt::Cmd {token httptoken} {
    variable $token
    upvar 0 $token state

    set state(httptoken) $httptoken

    # Don't bother with intermediate callbacks.
    if {![string equal [::httpex::state $httptoken] "final"]} {
	return
    } 
    
    # We are final here.
    set status  [::httpex::status $httptoken]
    set ncode   [::httpex::ncode $httptoken]
    set httperr [::httpex::error $httptoken]
    set retstatus $status
    set msg ""
    set show 1

    switch -- $status {
	timeout {
	    set etitle [mc Timeout]
	    set msg [mc jamessoobtimeout2]
	    set eicon info
	}
	error {
	    set etitle [mc Error]
	    set msg [mc httptrpterror2 $state(fileTail) $httperr]
	    set eicon error
	}
	eof {
	    set etitle [mc Error]
	    set msg [mc httptrpteof]
	    set eicon error
	}
	ok {
	    if {$ncode != 200} {
		set etitle [mc Error]
		set txt [httpex::ncodetotext $ncode]
		set msg [mc httptrptnon200a $state(fileTail)]
		append msg "\n[mc {Error code}]: $ncode"
		append msg "\n[mc Message]: $txt"
		set eicon error
		set retstatus error
	    } else {
		set show 0
		set msg [mc httptrptok2 $state(fileTail)]
	    }
	}
	reset {
	    # Did this ourself?
	    set show 0
	    set msg [mc httptrptreset $state(fileTail)]
	}
    }
    if {$state(-command) != {}} {
	uplevel #0 $state(-command) [list $token $retstatus $msg]
    }

    # Any error?
    if {!$state(-silent) && $show} {
	::UI::MessageBox -title $etitle -icon $eicon -type ok -message $msg
    }
    Free $token
}

proc ::HttpTrpt::Reset {token} {
    variable $token
    upvar 0 $token state
    
    #if {$state(-command) != {}} {
#	uplevel #0 $state(-command) [list $token reset]
    #}
    
    
    # Beware, this triggers the callback command!
    # The only thing we need to do here is to delete the file.
    set fileName $state(fileName)
    ::httpex::reset $state(httptoken)
    catch {file delete $fileName}
    #Free $token
}

proc ::HttpTrpt::CancelBt {token} {

    Reset $token
}

proc ::HttpTrpt::Free {token} {
    variable $token
    upvar 0 $token state
    
    #puts "::HttpTrpt::Free"
    if {$state(-dialog)} {
	catch {destroy $state(w)}
    }
    ::timing::free $state(timetok)
    ::httpex::cleanup $state(httptoken)
    catch {close $state(fd)}
    unset $token
}

#-------------------------------------------------------------------------------
