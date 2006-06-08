#  timing.tcl ---
#  
#      A collection of procedures to measure bytes per seconds during network
#      operations.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: timing.tcl,v 1.3 2006-06-08 13:55:05 matben Exp $

package provide timing 1.0

namespace eval ::timing:: {

    variable priv
}

# timing::setbytes --
# 
#       A number of utils that handle timing objects. Mainly to get bytes
#       per second during file transfer.
#       
# Arguments:
#       key         a unique key to identify a particular timing object,
#                   typically use the socket token or a running namespaced 
#                   number.
#       bytes       number of bytes transported so far
#       totalbytes  total file size in bytes
#       
# Results:
#       none

proc ::timing::setbytes {key bytes} {
    variable priv
    
    set ms [clock clicks -milliseconds]
    lappend priv($key) [list [expr double($ms)] $bytes]
    return
}

proc ::timing::getrate {key} {
    variable priv
    
    set len [llength $priv($key)]
    if {$len <= 1} {
	return 0.0
    }
    set n 12
    set tm $priv($key)
    set millis [expr {[lindex $tm end 0] - [lindex $tm 0 0]}]
    set bytes  [expr {[lindex $tm end 1] - [lindex $tm 0 1]}]
    
    # Treat the case with wrap around. (Guess)
    if {$millis <= 0} {
	set millis 1000000
    }
    
    # Keep only a small part.
    set priv($key) [lrange $priv($key) end-${n} end]
    
    # Returns average bytes per second.
    set rate [expr {1000.0 * $bytes / ($millis + 1.0)}]
    set priv($key,lastrate) $rate
    return $rate
}

proc ::timing::getlinearinterp {key} {
    variable priv
    
    set len [llength $priv($key)]
    if {$len <= 1} {
	return 0.0
    }
    set n 12
    
    # Keep only the part we are interested in.
    set priv($key) [lrange $priv($key) end-{n} end]
    set sumx  0.0
    set sumy  0.0
    set sumxy 0.0
    set sumx2 0.0
    
    # Need to move origin to get numerical stability!
    set x0 [lindex $priv($key) 0 0]
    set y0 [lindex $priv($key) 0 1]
    foreach co $priv($key) {
	set x [expr {[lindex $co 0] - $x0}]
	set y [expr {[lindex $co 1] - $y0}]
	set sumx  [expr {$sumx + $x}]
	set sumy  [expr {$sumy + $y}]
	set sumxy [expr {$sumxy + $x * $y}]
	set sumx2 [expr {$sumx2 + $x * $x}]
    }
    
    # This is bytes per millisecond.
    set k [expr {($n * $sumxy - $sumx * $sumy) /  \
      ($n * $sumx2 - $sumx * $sumx)}]
    return [expr {1000.0 * $k}]
}

proc ::timing::getpercent {key totalbytes} {
    variable priv

    if {[llength $priv($key)] > 1} {
	set bytes [lindex $priv($key) end 1]
    } else {
	set bytes 0
    }
    set percent [format %3.0f [expr {100.0 * $bytes/($totalbytes + 1.0)}]]
    set percent [expr {$percent < 0 ? 0 : $percent}]
    set percent [expr {$percent > 100 ? 100 : $percent}]
    return $percent
}

proc ::timing::getmessage {key totalbytes} {
    variable priv
    
    set bpersec [getrate $key]

    # Find format: bytes or k.
    if {$bpersec < 1000} {
	set txtRate "[expr {int($bpersec)}] bytes/sec"
    } elseif {$bpersec < 1000000} {
	set txtRate "[format %.1f [expr {$bpersec/1000.0}] ]Kb/sec"
    } else {
	set txtRate "[format %.1f [expr {$bpersec/1000000.0}] ]Mb/sec"
    }

    # Remaining time.
    if {[llength $priv($key)] > 1} {
	set bytes [lindex $priv($key) end 1]
    } else {
	set bytes 0
    }
    set percent [format %3.0f [expr {100.0 * $bytes/($totalbytes + 1.0)}]]
    set secsLeft [expr {int(ceil(($totalbytes - $bytes)/($bpersec + 1.0)))}]
    if {$secsLeft < 60} {
	set txtTimeLeft ", $secsLeft secs remaining"
    } elseif {$secsLeft < 120} {
	set txtTimeLeft ", one minute and [expr {$secsLeft - 60}] secs remaining"
    } else {
	set txtTimeLeft ", [expr {$secsLeft/60}] minutes remaining"
    }
    return "${txtRate}${txtTimeLeft}"
}

proc ::timing::free {key} {
    variable priv
    
    unset -nocomplain priv($key)
}

#-------------------------------------------------------------------------------

