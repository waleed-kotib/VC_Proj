# FileCache.tcl --
#
#	Simple data base for caching files that has or don't need be transported.
#	It maps 'key' (see below) to the local absolute native file path.
#	Directories may also be time stamped with "best before date".
#
#  Copyright (c) 2002-2003  Mats Bengtsson
#
# $Id: FileCache.tcl,v 1.13 2004-09-28 13:50:19 matben Exp $
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

    # Define all hooks that are needed.
    ::hooks::register initHook               ::FileCache::InitHook
    ::hooks::register quitAppHook            ::FileCache::QuitHook
    ::hooks::register prefsInitHook          ::FileCache::InitPrefsHook
    ::hooks::register prefsBuildHook         ::FileCache::BuildPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::FileCache::UserDefaultsHook
    ::hooks::register prefsSaveHook          ::FileCache::SaveHook
    ::hooks::register prefsCancelHook        ::FileCache::CancelHook
    ::hooks::register prefsUserDefaultsHook  ::FileCache::UserDefaultsHook

    # Main storage in array
    variable cache
    variable basedir [pwd]
    variable launchtime [clock seconds]
    
    # Time stamps for directories.
    variable bestbeforedir
    
    # Any of "never" or "always".
    variable usecache "always"
    
    # Keep track of total size of cache in bytes (double).
    variable totbytes 0.0
    variable maxbytes [expr 200e6]
    
    # Keep a time ordered list of keys.
    variable keylist {}
}

proc ::FileCache::InitHook { } {
    global  prefs this
        
    # Init the file cache settings.
    SetBasedir $this(path)
    SetBestBefore $prefs(checkCache) $prefs(incomingPath)

}

proc ::FileCache::QuitHook { } {
    global  prefs
    
    # Should we clean up our 'incoming' directory?
    if {$prefs(clearCacheOnQuit)} {
	catch {file delete -force -- $prefs(incomingPath)}
	file mkdir $prefs(incomingPath)
    }
}

proc ::FileCache::SetBasedir {dir} {
    variable basedir
    
    if {![string equal [file pathtype $dir] "absolute"]} {
	return -code error "The path \"$dir\" is not of type absolute"
    }
    set basedir $dir
}

proc ::FileCache::Init { } {    
    variable basedir
    variable totbytes 0
    
    if {[file isdirectory $basedir]} {
	foreach f [glob -nocomplain -directory $basedir *] {
	    set totbytes [expr $totbytes + double([file size $f])]
	}
    }
}

# FileCache::Set --
#
#       Sets an entry in the file data base. If no 'locabspath' then the key
#       is assumed to be a local absolute file path.

proc ::FileCache::Set {key {locabspath {}}} { 
    variable totbytes
    variable maxbytes
    variable keylist
    variable cache
    
    if {[string length $locabspath] == 0} {
	set locabspath $key
    }
    if {![string equal [file pathtype $locabspath] "absolute"]} {
	return -code error "The path \"$locabspath\" is not of type absolute"
    }
    set nkey [Normalize $key]
    lappend keylist $nkey
    set totbytes [expr $totbytes + double([file size $locabspath])]
    set rmkey [lindex $keylist 0]
    while {[expr $totbytes > $maxbytes] && ([llength $keylist] > 2)} {	
	Remove $rmkey
	set rmkey [lindex $keylist 0]
    }
    return [set cache($nkey) $locabspath]
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

# FileCache::Remove --
# 
#       Removes file cache corresponding to 'key' and deletes the cached file.

proc ::FileCache::Remove {key} {
    variable totbytes
    variable keylist
    variable cache
    
    set nkey [Normalize $key]
    if {[info exists cache($nkey)]} {
	set f $cache($nkey)
	set totbytes [expr $totbytes - double([file size $f])]
	set ind [lsearch -exact $keylist $nkey]
	set keylist [lreplace $keylist $ind $ind]
	catch {file delete $f}
	unset cache($nkey)
    }    
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
	    set iscached [Accept $cache($nkey)]
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
	    unset -nocomplain bestbeforedir
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

proc ::FileCache::ClearCache { } {
    global  prefs
    variable cache
    
    foreach nkey [array names cache] {
	catch {file delete $chache($nkey)}
    }
    unset -nocomplain cache

    catch {file delete -force -- $prefs(incomingPath)}
    file mkdir $prefs(incomingPath)
}

proc ::FileCache::Dump { } {
    variable cache
    
    puts "::FileCache::Dump:\n"
    if {[info exists cache]} {
	parray cache
    }
}

#--- UI part etc ---------------------------------------------------------------

proc ::FileCache::InitPrefsHook { } {
    global  prefs
    variable maxbytes
    
    # When and how old is a cached file allowed to be before downloading a new?
    # Options. "never", "always", "launch", "hour", "day", "week", "month"
    set prefs(checkCache) "launch"
    set prefs(cacheSize)  $maxbytes

    ::PreferencesUtils::Add [list  \
      [list prefs(checkCache)      prefs_checkCache      $prefs(checkCache)] \
      [list prefs(incomingPath)    prefs_incomingPath    $prefs(incomingPath)] \
      [list prefs(cacheSize)       prefs_cacheSize       $prefs(cacheSize)]]

    if {[lsearch {always launch never} $prefs(checkCache)] < 0} {
	set prefs(checkCache) launch
    }
}

proc ::FileCache::BuildPrefsHook {wtree nbframe} {
    
    $wtree newitem {Whiteboard {File Cache}} -text [mc {File Cache}]

    set wpage [$nbframe page {File Cache}]    
    ::FileCache::BuildPage $wpage
}

proc ::FileCache::BuildPage {page} {
    global  prefs
    variable tmpPrefs
        
    set fontS [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]

    set tmpPrefs(checkCache) $prefs(checkCache)
    set tmpPrefs(mbsize)     [expr wide($prefs(cacheSize)/1e6)]
    
    set pca $page.fr
    labelframe $pca -text [mc {File Cache}]
    pack $pca -side top -anchor w -padx 8 -pady 4
    message $pca.msg -width 300 -text [mc preffilecache]
    pack $pca.msg -side top -anchor w -pady 2

    set frca $pca.cas
    pack [frame $frca] -fill x -padx 10
    pack [label $frca.dsk -text "[mc {Disk Cache}]:"] -side left
    pack [entry $frca.emb -width 6  \
      -textvariable [namespace current]::tmpPrefs(mbsize)] -side left
    pack [label $frca.mb -text [mc {MBytes}]] -side left
    pack [button $frca.bt -padx 12 -text [mc {Clear Disk Cache Now}] \
      -command [namespace current]::ClearCache -font $fontS]  \
      -side right 

    set frfo $pca.fo
    pack [frame $frfo] -fill x -padx 10
    pack [label $frfo.fo -text "[mc {Cache folder}]:"] -side left
    pack [button $frfo.bt -padx 6 -text "[mc {Choose}]..." \
      -command [namespace current]::SetCachePath -padx 12 -font $fontS]  \
      -side right 
    
    
    set pwhen $page.frw
    labelframe $pwhen -text [mc prefcachecmp]
    pack $pwhen -side top -anchor w -padx 8 -pady 4
    set frw $pwhen.cas
    pack [frame $frw] -side left -padx 16 -pady 2
    foreach  \
      val {always       launch             never}   \
      txt {{Every time} {Once per session} {Never}} {
	radiobutton $frw.$val -text [mc $txt]   \
	  -variable [namespace current]::tmpPrefs(checkCache) -value $val
	grid $frw.$val -sticky w
    }
}

proc ::FileCache::SetCachePath { } {
    global  this prefs
    
    set dir [tk_chooseDirectory -title [mc {Pick Cache Folder}] \
      -initialdir $prefs(incomingPath) -mustexist 1]
    if {$dir != ""} {
	set prefs(incomingPath) $dir
    }
}

proc ::FileCache::UserDefaultsHook { } {
    global  prefs
    variable tmpPrefs
    
    
}

proc ::FileCache::SaveHook { } {
    global  prefs
    variable tmpPrefs
    variable maxbytes

    set maxbytes [expr 1e6 * double( $tmpPrefs(mbsize) )]
    set prefs(checkCache) $tmpPrefs(checkCache)
    set prefs(cacheSize) $maxbytes
    
    # Reset file cache doesn't hurt.
    SetBestBefore $prefs(checkCache) $prefs(incomingPath)
}

proc ::FileCache::CancelHook { } {
    global  prefs
    variable tmpPrefs
    
    # Detect any changes.
    if {![string equal $prefs(checkCache) $tmpPrefs(checkCache)]} {
	::Preferences::HasChanged
	return
    }
}

proc ::FileCache::UserDefaultsHook { } {
    global  prefs
    variable tmpPrefs
    
    set tmpPrefs(checkCache) $prefs(checkCache)
    set tmpPrefs(mbsize)     [expr wide($prefs(cacheSize)/1e6)]
}

#-------------------------------------------------------------------------------

