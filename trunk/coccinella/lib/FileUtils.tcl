#  FileUtils.tcl ---
#  
#      This file is part of the whiteboard application. It implements procs
#      for handling specific file tasks etc.
#      
#  Copyright (c) 2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: FileUtils.tcl,v 1.2 2003-01-30 17:33:56 matben Exp $

namespace eval ::FileUtils:: {
    
    namespace export what

    # Our arrays that act as a data base.
    variable knownFiles {}
    variable knownPaths {}
}


# FileUtils::GetTransferRateFromTiming --
#
#       From 'listClicksBytes' which is a list of {clockClicks bytes}, 
#       the transfer rate is computed as bytes per seconds.
#       A moving average of the latest elements is used.
#       
# Arguments:
#
# Results:

proc ::FileUtils::GetTransferRateFromTiming {listClicksBytes} {
    global  timingClicksToSecs
    
    set n [llength $listClicksBytes]
    set nAve 3
    set istart [expr $n - $nAve]
    if {$istart < 0} {
	set istart 0
    }
    set iend [expr $n - 1]
    set sumBytes [expr [lindex [lindex $listClicksBytes $iend] 1] -  \
      [lindex [lindex $listClicksBytes $istart] 1]]
    set sumClicks [expr [lindex [lindex $listClicksBytes $iend] 0] -  \
      [lindex [lindex $listClicksBytes $istart] 0]]
    
    # Treat the case with wrap around. (Guess)
    if {$sumClicks <= 0} {
	set sumClicks $timingClicksToSecs
    }
    set aveBytesPerClick [expr $sumBytes / ($sumClicks + 1.0)]
    set aveBytesPerSec [expr $aveBytesPerClick * $timingClicksToSecs]
    return $aveBytesPerSec
}

# FileUtils::BytesPerSecFormatted --
#
#       Returns the transfer rate as a nicely formatted text string.
#       
# Arguments:
#
# Results:

proc ::FileUtils::BytesPerSecFormatted {bytesPerSec} {

    # Find format: bytes or k.
    if {$bytesPerSec < 1000} {
	set txtRate "$bytesPerSec bytes/sec"
    } elseif {$bytesPerSec < 1000000} {
	set txtRate [list [format "%.1f" [expr $bytesPerSec/1000.0] ]Kb/sec]
    } else {
	set txtRate [list [format "%.1f" [expr $bytesPerSec/1000000.0] ]Mb/sec]
    }
    return $txtRate
}

# FileUtils::AddToKnownFiles, GetKnownPathFromTail --
#
#       Keeps track of already opened or received images/movies files
#       through the synced lists 'knownFiles' and 'knownPaths'.
#       The 'fileTail' name is always the native file name which on the mac
#       my lack an extension.
#       
# Arguments:
#
# Results:

		
proc ::FileUtils::GetKnownPathFromTail {fileTail} {
    global  this
   
    variable knownFiles 
    variable knownPaths

    set dot_ {\.}
    set ind [lsearch -exact $knownFiles $fileTail]
    
    # On mac it is only necessary that the rootnames agree.
    if {[string match "mac*" $this(platform)]} {
	set fileRoot [file rootname $fileTail]
	set ind [lsearch -regexp $knownFiles "^${fileRoot}$dot_*|^${fileRoot}$"]	
    }
    
    # Return nothing if its not there.
    if {$ind < 0} {
	return {}
    } else {
	set path [lindex $knownPaths $ind]
	
	# Check if the file exists.
	if {[file exists $path]} {
	    return $path
	} else {
	    return {}
	}
    }
}

# NOT USED............................

# FileUtils::AcceptCached --
#
#       Is the cached file acceptable given our preference settings?
#       This assumes that we have verified that a cached file exists.
#       
# Arguments:
#      filePath
#       
# Results:
#       boolean

proc ::FileUtils::AcceptCached {filePath} {
    global  prefs
    
    switch -- $prefs(checkCache) {
	never {
	    set ans 0
	}
	always {
	    set ans 1
	}
	launch - min - hour - day - 30days {
	    if {[::FileUtils::FileOlderThan $filePath $prefs(checkCache)]} {
		set ans 0
	    } else {
		set ans 1
	    }
	}
	default {
	    set ans 0
	}
    }
    return $ans
}

# FileUtils::FileOlderThan --
#
#       Find out if file older than 'timespan'.
#       
# Arguments:
#      timespan     can be: "launch", "min", "hour", "day", "30days".
#       
# Results:
#       0 if file younger, 1 if older than 'timespan'

proc ::FileUtils::FileOlderThan {filePath timespan} {
    global  tmsec state
    
    set opts [list "launch" "min" "hour" "day" "30days"]
    if {[lsearch -exact $opts $timespan] < 0} {
	return 1
    }
    set fileTime [file mtime $filePath]
    set thisTime [clock seconds]
    set ans 1
    if {[string equal $timespan "always"]} {
	set ans 1
    } elseif {[string equal $timespan "launch"]} {
	if {$fileTime > $state(launchSecs)} {
	    set ans 0
	}
    } else {
	if {[expr $thisTime - $fileTime] < $tmsec($timespan)} {
	    set ans 0
	}
    }
    return $ans
}

#-------------------------------------------------------------------------------
