# FileCache.tcl --
#
#	Simple data base for caching files that has or don't need be transported.
#	It maps 'key' (see below) to the local absolute native file path.
#	Directories may also be time stamped with "best before date".
#
#  Copyright (c) 2002-2003  Mats Bengtsson
#
# $Id: FileCache.tcl,v 1.4 2003-10-05 13:36:20 matben Exp $
# 
#       The input key can be: 
#               1) a full url, must be uri encoded 
#               2) an absolute native form path, not uri encoded
#               3) or a relative path, which may include ../ etc.
#
#	The key in the database (denoted nkey for normalized key), 
#	the array index, can be:
#		1) complete url without the protocol part (http) and no port 
#		   spec "://server.com/../dir1/file.mov"
#		   the "://" is mandatory for defining an url
#		2) a relative file path, which means local file
#		3) in any case it is always uri encoded
#		4) it's always using unix dir separators "/"
#		5) all lower case on windows (mac?)
#
#	This way files are uniquely identified.
#	Note: all relative paths are relative the installation dir (basedir), 
#	and therefore a path without any ../ is always local.
#
# USAGE ########################################################################
# 
# ::FileCache::SetBasedir dir
# 
# ::FileCache::Set key ?locabspath?
# 
# ::FileCache::Get key
# 
# ::FileCache::IsCached key
# 
# ::FileCache::SetDirFiles dir ?pattern?
#
# ::FileCache::Dump

package require tinyfileutils
package require uriencode

package provide FileCache 1.0

namespace eval ::FileCache:: {

    # Main storage in array
    variable cache
    variable basedir [pwd]
    variable launchtime [clock seconds]
    
    # Time stamps for directories.
    variable bestbeforedir
    
    # Any of "never" or "always".
    variable usecache "always"
}

proc ::FileCache::SetBasedir {dir} {

    variable basedir
    if {![string equal [file pathtype $dir] "absolute"]} {
	return -code error "The path \"$dir\" is not of type absolute"
    }
    set basedir $dir
}

# FileCache::Set --
#
#       Sets an entry in the file data base. If no 'locabspath' then the key
#       is assumed to be a local absolute file path.

proc ::FileCache::Set {key {locabspath {}}} {

    variable cache
    if {[string length $locabspath] == 0} {
	set locabspath $key
    }
    if {![string equal [file pathtype $locabspath] "absolute"]} {
	return -code error "The path \"$locabspath\" is not of type absolute"
    }
    return [set cache([Normalize $key]) $locabspath]
}

proc ::FileCache::Get {key} {

    variable cache
    set nkey [Normalize $key]
    if {[info exists cache($nkey)]} {
	set ans $cache($nkey)
    } elseif {[IsLocal $key]} {
	set ans $cache($nkey)
    } else {
    	return -code error "The cache does not contain an entry with key \"$key\""
    }
    return $ans
}

# FileCache::IsCached --
# 
#       Checks if this key is stored in cache and acceptable.

proc ::FileCache::IsCached {key} {
    
    variable cache
    variable usecache

    if {[string equal $usecache "never"]} {
	set iscached 0
    } else {
	set iscached 0
	set nkey [Normalize $key]
	if {[info exists cache($nkey)]} {
	    set iscached 1
	} elseif {[IsLocal $key]} {
	    set iscached 1
	}
	if {$iscached} {
	    set iscached [::FileCache::Accept $cache($nkey)]
	}
    }
    return $iscached
}

# FileCache::SetDirFiles --
# 
#       Caches all files in this directory that match 'pattern'. 

proc ::FileCache::SetDirFiles {dir {pattern *}} {

    if {![string equal [file pathtype $dir] "absolute"]} {
	return -code error "The path \"$dir\" is not of type absolute"
    }

    # glob returns absolute paths but we must store them relative 'basedir'
    # and the key must be uri encoded!
    foreach f [glob -nocomplain -directory $dir $pattern] {
	::FileCache::Set $f
    }
}

# FileCache::Normalize --
# 
#	The key can be a full url, an absolute path, or a relative path.

proc ::FileCache::Normalize {key} {
    
    variable basedir
    set host ""
    
    # Split off any protocol part.
    if {[regexp {[^:]*(://[^:/]+)(:[0-9]+)?(/.*$)} $key  \
      match host port path]} {
    } elseif {[string equal [file pathtype $key] "absolute"]} {
	set path [filerelative $basedir $key]
	set path [uriencode::quotepath $path]
    } elseif {[string equal [file pathtype $key] "relative"]} {
	set path [uriencode::quotepath $key]
    } else {
	return -code error "The key \"$key\" has not a valid form"
    }
    set nkey ${host}${path}
    # Not sure this is a good idea...
    if {[string equal $::tcl_platform(platform) "windows"]} {
	set nkey [string tolower $nkey]
    }
    return $nkey
}

# FileCache::IsLocal --
#
#       If key not an uri it is always local, then cache it.
#       If an uri, then if path local to installation dir, and if the file
#       exists, then it is local, and is cached.

proc ::FileCache::IsLocal {key} {
    
    variable basedir
    variable cache

    set islocal 0
    if {[regexp {[^:]*://[^/]+/(.*)} $key match path]} {
	if {![string match "../*" $path]} {
	    set path [file nativename [uriencode::decodefile $path]]
	    set abspath [file join $basedir $path]
	    if {[file exists $abspath] && [file isfile $abspath]} {
		set islocal 1
		::FileCache::Set $key $abspath
	    }
	}
    } else {
	set islocal 1
	if {[string match "../*" $key]} {
	    set abspath [addabsolutepathwithrelative $basedir $key]
	    set abspath [file nativename $abspath]
	} else {
	    set abspath [file nativename $key]
	}
	::FileCache::Set $key $abspath
    }
    return $islocal
}

# --- Some functions for handling "best before" things -------------------------

# FileCache::SetBestBefore --
# 
#       Sets a time limit on cached files in the specified directory.
#       A cached file in this directory is not accepted if its modify time
#       is older than as specified by 'timetoken'.
#       
#       timetoken:  any of "never", "always", "launch", "min", "hour", "day", "month"

proc ::FileCache::SetBestBefore {timetoken {dir {}}} {
 
    variable launchtime
    variable bestbeforedir
    variable usecache
    
    switch -- $timetoken {
	never - always {
	    set usecache $timetoken
	    catch {unset bestbeforedir}
	}
	launch - min - hour - day - month {
	    if {![string equal [file pathtype $dir] "absolute"]} {
		return -code error "The path \"$dir\" is not of type absolute"
	    }
	    set usecache "always"
	    set bestbeforedir($dir) $timetoken
	}
	default {
	    return -code error "Unrecognized timetoken \"$timetoken\""
	}
    }
}

# FileCache::Accept --
# 
#
#       locabspath:   local native not uri encoded abslute path.

proc ::FileCache::Accept {locabspath} {
 
    variable launchtime
    variable bestbeforedir
    
    if {![string equal [file pathtype $locabspath] "absolute"]} {
	return -code error "The path \"$locabspath\" is not of type absolute"
    }
    
    # Need to loop through all directorys with "best before date" and see if
    # any matches the file path in question.
    set accept 1
    foreach dir [array names bestbeforedir] {
	if {[string match ${dir}* $locabspath]} {
	    set timetoken $bestbeforedir($dir)
	    set filemtime [file mtime $locabspath]	    
	    switch -- $timetoken {
		launch {
		    set timelimit $launchtime
		}
		default {
		    set timelimit [clock scan "-1 $timetoken"]
		}
	    }
	    if {$filemtime < $timelimit} {
		set accept 0
	    }
	    break
	}
    }
    return $accept
}

proc ::FileCache::Dump { } {
    variable cache
    
    puts "::FileCache::Dump:\n"
    if {[info exists cache]} {
	parray cache
    }
}

#-------------------------------------------------------------------------------

