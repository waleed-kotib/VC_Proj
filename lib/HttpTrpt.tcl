#  HttpTrpt.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It is a wrapper for httpex and ProgressWindow to isolate
#      the application from the details.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: HttpTrpt.tcl,v 1.1 2004-12-04 15:01:06 matben Exp $

package require httpex
package require timing
package require ProgressWindow

package provide HttpTrpt 1.0

namespace eval ::HttpTrpt:: {

    variable uid 0
    variable wbase .htrpt[format %x [clock clicks]]
}

# HttpTrpt::Get --
# 
#       Initiates a http get operation. 
#       Returns a token if succesful, else empty.
#       

proc ::HttpTrpt::Get {url fileName from args} {
    global  prefs
    variable uid
    variable wbase
    
    ::Debug 2 "::HttpTrpt::Get url=$url, fileName=$fileName"
    
    array set opts {
	-command    ""
	-dialog     1
    }
    array set opts $args
    if {[catch {open $fileName w} fd]} {
	::UI::MessageBox -title [mc Error] -icon error -type ok \
	  -message [mc jamessoobfailopen $fileName]
	return ""
    }

    # Create an array that holds the instance specific state.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state

    set w ${wbase}${uid}
    set state(fd)        $fd
    set state(w)         $w
    set state(timetok)   $fd
    set state(url)       $url
    set state(fileName)  $fileName
    set state(fileTail)  [file tail $fileName]
    set state(from)      $from
    set state(first)     1
    foreach {key value} [array get opts] {
	set state($key) $value
    }

    if {[catch {
	::httpex::get $url -channel $fd -timeout $prefs(timeoutMillis) \
	  -progress [list [namespace current]::Progress $token] \
	  -command  [list [namespace current]::Cmd $token]
    } httptoken]} {
	::UI::MessageBox -title [mc Error] -icon error -type ok \
	  -message [mc jamessoobgetfail $url $httptoken]
	return ""
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
	    uplevel #0 $state(-command) $token error $errmsg
	}
	::UI::MessageBox -title [mc Error] -icon error -type ok \
	  -message "Failed getting url: $errmsg"
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
	    ::ProgressWindow::ProgressWindow $w -text $str \
	      -cancelcmd [list [namespace current]::Cancel $token]
	    set needupdate 1
	}
	set state(startmillis) $ms
	set state(lastmillis)  $ms
	set state(first) 0
    } elseif {[expr $ms - $state(lastmillis)] > $prefs(progUpdateMillis)} {

	# Update the progress window.
	set msg3 "[mc Rate]: [::timing::getmessage $state(timetok) $total]"	
	if {$state(-dialog)} {
	    set percent [expr 100.0 * $current/($total + 0.001)]
	    $w configure -percent $percent -text3 $msg3
	    set needupdate 1
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
#       Callback for the httpex package.

proc ::HttpTrpt::Cmd {token httptoken} {
    variable $token
    upvar 0 $token state

    #puts "::HttpTrpt::Cmd"
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
    set errmsg ""
    #puts "\t status=$status, ncode=$ncode, httperr=$httperr"

    switch -- $status {
	timeout {
	    set etitle [mc Timeout]
	    set errmsg [mc jamessoobtimeout]
	    set eicon info
	}
	error {
	    set etitle [mc "File transport error"]
	    set errmsg [mc httptrpterror $state(fileTail) $state(from) $httperr]
	    set eicon error
	}
	eof {
	    set etitle [mc "File transport error"]
	    set errmsg [mc httptrpteof $state(from)]
	    set eicon error
	}
	ok {
	    if {$ncode != 200} {
		set etitle [mc "File transport error"]
		set txt [httpex::ncodetotext $ncode]
		set errmsg [mc httptrptnon200 $state(fileTail) $state(from) $ncode $txt]
		set eicon error
		set retstatus error
	    }
	}
	reset {
	    # Did this ourself?
	}
    }
    if {$state(-command) != {}} {
	uplevel #0 $state(-command) $token $retstatus $errmsg
    }

    # Any error?
    if {$errmsg != ""} {
	::UI::MessageBox -title $etitle -icon $eicon -type ok -message $errmsg
    }
    Free $token
}

proc ::HttpTrpt::Cancel {token} {
    variable $token
    upvar 0 $token state
    
    if {$state(-command) != {}} {
	uplevel #0 $state(-command) $token reset
    }
    ::httpex::reset $state(httptoken)
    catch {file delete $state(fileName)}
    Free $token
}

proc ::HttpTrpt::Free {token} {
    variable $token
    upvar 0 $token state
    
    #puts "::HttpTrpt::Free"
    catch {destroy $state(w)}
    ::timing::free $state(timetok)
    ::httpex::cleanup $state(httptoken)
    unset $token
}

#-------------------------------------------------------------------------------
