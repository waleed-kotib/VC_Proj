# idletime.tcl ---
#
#       Set global idle time callbacks.
#       
#  Copyright (c) 2007
#  
#  This file is distributed under BSD style license.
#  
#  $Id: idletime.tcl,v 1.4 2007-07-19 06:28:11 matben Exp $

package provide idletime 1.0

namespace eval ::idletime {

    variable lastmouse [winfo pointerxy .]
    variable state
    
    # Keep a 2 secs resolution which should be enough for autoaway.
    variable pollms 2000
    variable tclidlems 0
    variable inactiveProc
    
    # Fallback pure tcl method.
    set inactiveProc [namespace code tclinactive]

    if {[catch {tk inactive}] || ([tk inactive] < 0)} {

	switch -- $::tcl_platform(platform) {
	    unix {
		if {$::tcl_platform(os) eq "Darwin"} {
		    if {[catch {package require carbon 0.2}]} {
			set inactiveProc [namespace code AquaIdleTime]
		    } else {
			set inactiveProc {carbon::inactive}			
		    }
		} else {
		    if {![catch {package require tkinactive}]} {
			set inactiveProc tkinactive
		    }
		}
	    }
	    windows {
		if {![catch {package require tkinactive}]} {
		    set inactiveProc tkinactive
		}
	    }
	}
    } else {
	set inactiveProc {tk inactive}
    }
}

proc ::idletime::init {} {
    variable inactiveProc
 
    if {$inactiveProc eq [namespace code tclinactive]} {
	tcltimer
    }
    poll
}

proc ::idletime::stop {} {
    variable afterID

    foreach key {poll tcl} {
	if {[info exists afterID($key)]} {
	    after cancel $afterID($key)
	    unset afterID($key)
	}
    }
}

proc ::idletime::add {procName secs} {
    variable state
    variable shot
    
    set state($procName) $secs
    set shot($procName) 0
}

proc ::idletime::remove {procName} {
    variable state
    variable shot
    
    unset -nocomplain state($procName)
    unset -nocomplain shot($procName)    
}

proc ::idletime::poll {} {
    variable state
    variable shot
    variable pollms
    variable inactiveProc
    variable afterID
    
    set idlesecs [expr {[eval $inactiveProc]/1000}]
    
    foreach {name secs} [array get state] {
	if {$idlesecs >= $secs} {
	    
	    # Fire!
	    if {!$shot($name)} {
		set shot($name) 1
		uplevel #0 $name idle
	    }
	} else {
	    if {$shot($name)} {
		set shot($name) 0
		uplevel #0 $name active
	    }
	}
    }    
    set afterID(poll) [after $pollms [namespace code poll]]
}

# Pure tcl implementation that handles mouse moves only.

proc ::idletime::tclinactive {} {
    variable tclidlems
    return [expr {$tclidlems/1000}]
}

proc ::idletime::tcltimer {} {
    variable lastmouse
    variable pollms
    variable tclidlems
    variable afterID
    
    set mouse [winfo pointerxy .]
    if {$mouse eq $lastmouse} {
	incr tclidlems $pollms
    } else {
	set tclidlems 0
    }
    set lastmouse $mouse
    set afterID(tcl) [after $pollms [namespace code tcltimer]]
}

# idletime::AquaIdleTime --
# 
#       Returns the idle time in seconds. Better to use carbon::inactive.

proc ::idletime::AquaIdleTime {} {
    
    if {[catch { 
	set fd [open {|ioreg -x -c IOHIDSystem}]
	set line [read $fd] 
	close $fd
    }]} {
	return 0
    }
    set minms 1000000
    set match [regexp -all -inline {"HIDIdleTime" = (?:0x|<)([[:xdigit:]]+)} $line]
    foreach {m nsecs} $match {
	set ms [expr {"0x$nsecs"/1000000}]
	if {$ms < $minms} {
	    set minms $ms
	}
    }
    return $minms
}


