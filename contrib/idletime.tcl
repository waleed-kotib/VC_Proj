# idletime.tcl ---
#
#       Set global idle time callbacks.
#       
#  Copyright (c) 2007
#  This source file is distributed under the BSD license.
#  
#  $Id: idletime.tcl,v 1.1 2007-07-11 12:58:38 matben Exp $

package provide idletime 1.0

namespace eval ::idletime {

    variable lastmouse [winfo pointerxy .]
    variable state
    variable pollms 5000
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
		    # TODO
		}
	    }
	    windows {
		# TODO
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
    
    set idlesecs [expr {[eval $inactiveProc]/1000}]
    
    #puts "::idletime::poll idlesecs=$idlesecs"
    
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
    after $pollms [namespace code poll]
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
    
    set mouse [winfo pointerxy .]
    #puts "mouse=$mouse, lastmouse=$lastmouse"
    if {$mouse eq $lastmouse} {
	incr tclidlems $pollms
    } else {
	set tclidlems 0
    }
    set lastmouse $mouse
    after $pollms [namespace code tcltimer]
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


