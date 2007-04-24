#  Debug.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It provides a few routines to help debugging.
#      
#  Copyright (c) 2004-2007  Mats Bengtsson
#  
# $Id: Debug.tcl,v 1.6 2007-04-24 07:48:15 matben Exp $

# If no debug printouts, no console.
if {$debugLevel == 0} {
    switch -- $this(platform) windows - macintosh - macosx {
	catch {console hide}
    }
}
	
# For debug purposes. Writing to log file can be helpful to trace infinite loops.
if {$debugLevel >= 6} {
    set fdLog [open [file join [file dirname [info script]] debug.log] w]
}
proc ::Debug {num str} {
    global  debugLevel fdLog
    if {$num <= $debugLevel} {
	if {[info exists fdLog]} {
	    puts $fdLog $str
	    flush $fdLog
	}
	puts $str
    }
}

proc ::CallTrace {num} {
    global  debugLevel
    if {$num <= $debugLevel} {
	puts "Tcl call trace:"
	for {set i [expr [info level] - 1]} {$i > 0} {incr i -1} {
	    puts "\t$i: [string range [info level $i] 0 80] ..."
	}
    }
}

set ::dbgt 0

#       You must initiate by setting its start value:
#         set ::t [clock clicks -milliseconds]

proc ::Timer {str} {
    if {$::dbgt} {
	puts "milliseconds ($str): [expr [clock clicks -milliseconds]-$::t]"
	set ::t [clock clicks -milliseconds]
	flush stdout
    }   
}

# Optional and custom designed.
if {0} {
    proc ::TraceVar {name1 name2 op} {
	puts "$name1 $name2 $op"
	CallTrace 4
    }

    # Add variable to trace here.
    namespace eval ::Jabber {}
    trace add variable ::Jabber::jstate(show) write TraceVar
}
