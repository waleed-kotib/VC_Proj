# FileCache.tcl --
#
#	Simple data base for caching files that has or don't need be transported.
#	It maps 'key' (see below) to the local absolute native file path.
#	Directories may also be time stamped with "best before date".
#
#  Copyright (c) 2002-2005  Mats Bengtsson
#
# $Id: FileCache.tcl,v 1.22 2005-08-14 07:17:55 matben Exp $
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
#	The value is one of two things:
#	        1) a local absolute file path
#	        2) a file tail which then refers to a file in cache directory
#
# USAGE ########################################################################
# 
# ::FileCache::
# 
#       SetBaseDir dir
#       SetCacheDir dir
#       Set key ?locabspath?
#       Get key
#       GetNameFromCache fileName
#       IsCached key
#       SetDirFiles dir ?pattern?
#       MakeCacheFileName fileName
#       Dump

package require uuid
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
    array set cache {}
    
    # Time stamps for directories.
    variable bestbeforedir
    
    # Any of "never" or "always".
    variable usecache "always"
    
    # Keep track of total size of cache in bytes (double).
    variable totbytes 0.0
    variable maxbytes [expr 200e6]
    
    # Keep a time ordered list of keys.
    variable keylist {}
    
    # Cache directory.
    variable cachedir ""
    variable readcache 0
    variable indexFileTail cacheIndex
    
}

proc ::FileCache::InitHook { } {
    global  prefs this
        
    # Init the file cache settings.
    SetBaseDir $this(path)
    SetBestBefore $prefs(checkCache) $prefs(incomingPath)
    SetCacheDir $prefs(incomingPath)
}

proc ::FileCache::QuitHook { } {
    global  prefs this
    
    # Should we clean up our 'incoming' directory?
    if {$prefs(clearCacheOnQuit)} {
	catch {file delete -force -- $prefs(incomingPath)}
	file mkdir $prefs(incomingPath)
    }
    WriteTable
}

proc ::FileCache::SetBaseDir {dir} {
    variable basedir
    
    if {![string equal [file pathtype $dir] "absolute"]} {
	return -code error "The path \"$dir\" is not of type absolute"
    }
    set basedir $dir
}

# FileCache::Set --
#
#       Sets an entry in the file data base. 
#       If 'fileName' is missing we use the 'key' instead.
#       Else it is one of two things:
#	        1) a local absolute file path
#	        2) a file tail which then refers to a file in cache directory

proc ::FileCache::Set {key {fileName ""}} { 
    variable totbytes
    variable maxbytes
    variable keylist
    variable cache
    variable cachedir
    variable readcache
    
    if {!$readcache} {
	ReadTable
    }
    if {$fileName eq ""} {
	set absFileName $key
    } else {
	if {[string equal [file dirname $fileName] "."]} {
	    set absFileName [file join $cachedir $fileName]
	} else {
	    set absFileName $fileName
	}
    }
    set nkey [Normalize $key]
    lappend keylist $nkey
    set totbytes [expr $totbytes + double([file size $absFileName])]
    set rmkey [lindex $keylist 0]
    
    while {[expr $totbytes > $maxbytes] && ([llength $keylist] > 2)} {	
	Remove $rmkey
	set rmkey [lindex $keylist 0]
    }
    
    # If 'locabspath' is in the cache dir strip off dirname.
    if {[IsFileCachePath $absFileName]} {
	set cacheName [file tail $absFileName]
    } else {
	set cacheName $absFileName
    }
    return [set cache($nkey) $cacheName]
}

# FileCache::Get --
# 
#       Get the stored absolute file path if any.

proc ::FileCache::Get {key} {
    variable cache
    variable cachedir
    variable readcache
    
    if {!$readcache} {
	ReadTable
    }    
    set nkey [Normalize $key]
    if {[info exists cache($nkey)]} {
	set name $cache($nkey)
    } elseif {[IsLocal $key]} {
	set name $cache($nkey)
    } else {
    	return -code error "the cache does not contain an entry with key \"$key\""
    }
    if {[string equal [file dirname $name] "."]} {
	set name [file join $cachedir $name]
    }
    return $name
}

# FileCache::IsCached --
# 
#       Checks if this key is stored in cache and acceptable.

proc ::FileCache::IsCached {key} {    
    variable cache
    variable usecache
    variable readcache
    
    if {!$readcache} {
	ReadTable
    }    
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

# FileCache::Remove --
# 
#       Removes file cache corresponding to 'key' and deletes the cached file.

proc ::FileCache::Remove {key} {
    variable totbytes
    variable keylist
    variable cache
    variable cacheToName
    
    set nkey [Normalize $key]
    if {[info exists cache($nkey)]} {
	set f $cache($nkey)
	set totbytes [expr $totbytes - double([file size $f])]
	set ind [lsearch -exact $keylist $nkey]
	set keylist [lreplace $keylist $ind $ind]
	catch {file delete $f}
	unset cache($nkey)
	#unset -nocomplain cacheToName(??)
    }    
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
	Set $f
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
	set path [::tfileutils::relative $basedir $key]
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

proc ::FileCache::IsFileCachePath {fileName} {
    variable cachedirnorm
    
    return [string equal [file normalize [file dirname $fileName]] $cachedirnorm]
}

proc ::FileCache::CompletePath {fileName} {
    variable cachedir
    
    if {[string equal [file dirname $fileName] "."]} {
	return [file join $cachedir $fileName]
    } else {
	return $fileName
    }
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
		Set $key $abspath
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
	Set $key $abspath
    }
    return $islocal
}

# A few functions to handle a cache dir where files get unique names in
# a special cache folder.
# 

proc ::FileCache::SetCacheDir {dir} {
    variable cachedir
    variable cachedirnorm
    variable indexFile
    variable indexFileTail
    
    if {![string equal [file pathtype $dir] "absolute"]} {
	return -code error "The path \"$dir\" is not of type absolute"
    }
    if {[file isfile $dir]} {
	return -code error "this is a regular file, not a directory"
    }
    if {![file exists $dir]} {
	file mkdir $dir
    }
    set cachedir $dir
    set cachedirnorm [file normalize $cachedir]
    set indexFile [file join $cachedir $indexFileTail]
}

proc ::FileCache::MakeCacheFileName {uri} {
    variable cachedir
    variable cacheToName
    
    if {![file isdirectory $cachedir]} {
	return -code error "the cache directory not set"
    }
    set name [uuid::uuid generate][file extension $uri]
    set cacheToName($name) [file tail $uri]
    set fileName [file join $cachedir $name]
    return $fileName
}

proc ::FileCache::GetNameFromCache {fileName} {
    variable cacheToName
    
    set tail [file tail $fileName]
    if {[info exists cacheToName($tail)]} {
	return $cacheToName($tail)
    } else {
	return -code error "the file is not cached with a name"
    }
}

proc ::FileCache::HasCacheName {fileName} {
    variable cacheToName
    
    set tail [file tail $fileName]
    if {[info exists cacheToName($tail)]} {
	return 1
    } else {
	return 0
    }
}

# FileCache::WriteTable --
# 
#       Writes the cache index file that maps url's to cache file names.

# An alternative would be to store 'Set $key $value' and
# then source the file when reading the table.

proc ::FileCache::WriteTable { } {
    variable indexFile
    variable cache
    variable readcache
    
    # Only if the cacheFile read we should save it, else we just
    # overwrite the existing file with an empty one.
    if {$readcache} {
    
	# Write only files in the cache directory.
	set tmp ${indexFile}_tmp
	if {![catch {open $tmp {WRONLY CREAT}} fd]} {
	    foreach {key value} [array get cache] {
		if {[string equal [file dirname $value] "."]} {
		    puts $fd [list $key $value]
		}
	    }
	    close $fd
	}
	catch {file rename -force $tmp $indexFile}
    }
}

# FileCache::ReadTable --
# 
#       Reads the cache table and sets our internal state variables.

proc ::FileCache::ReadTable { } {
    variable indexFile
    variable cache
    variable readcache
    variable totbytes
    variable keylist
        
    set readcache 1

    set oldcwd [pwd]
    cd [file dirname $indexFile]

    # Be sure to cache only existing files.
    if {[file exists $indexFile] && ![catch {open $indexFile RDONLY} fd]} {
	while {[gets $fd line] >= 0} { 
	    set key [lindex $line 0]
	    set f   [lindex $line 1]
	    if {[file exists $f]} {
		set cache($key) $f
		lappend keylist $key
		set totbytes [expr $totbytes + double([file size $f])]
	    }
	}	
	close $fd
    }
    cd $oldcwd
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
#       fileName:   1) local native not uri encoded abslute path.
#                   2) file tail if in cache directory.

proc ::FileCache::Accept {fileName} { 
    variable launchtime
    variable bestbeforedir
    variable cachedir
    
    # We must get the absolute path.
    set absFilePath [CompletePath $fileName]
    if {![string equal [file pathtype $absFilePath] "absolute"]} {
	return -code error "The path \"$absFilePath\" is not of type absolute"
    }
    
    # Need to loop through all directories with "best before date" and see if
    # any matches the file path in question.
    set accept 1
    foreach dir [array names bestbeforedir] {
	if {[string match ${dir}* $absFilePath]} {
	    set timetoken $bestbeforedir($dir)
	    set filemtime [file mtime $absFilePath]
	    
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
    variable totbytes
    variable keylist
    
    set oldcwd [pwd]
    cd $prefs(incomingPath)
    foreach f [glob -nocomplain *] {
	catch {file delete $f}
    }
    unset -nocomplain cache
    array set cache {}
    set keylist {}
    set totbytes 0.0

    cd $oldcwd
}

proc ::FileCache::Dump { } {
    variable cache
    
    puts "::FileCache::Dump:"
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

    ::PrefUtils::Add [list  \
      [list prefs(checkCache)      prefs_checkCache      $prefs(checkCache)] \
      [list prefs(incomingPath)    prefs_incomingPath    $prefs(incomingPath)] \
      [list prefs(cacheSize)       prefs_cacheSize       $prefs(cacheSize)]]

    if {[lsearch {always launch never} $prefs(checkCache)] < 0} {
	set prefs(checkCache) launch
    }
}

proc ::FileCache::BuildPrefsHook {wtree nbframe} {
    
    if {![$wtree isitem Whiteboard]} {
	$wtree newitem {Whiteboard} -text [mc Whiteboard]
    }
    $wtree newitem {Whiteboard {File Cache}} -text [mc {File Cache}]

    set wpage [$nbframe page {File Cache}]    
    ::FileCache::BuildPage $wpage
}

proc ::FileCache::BuildPage {page} {
    global  prefs
    variable tmpPrefs
        
    set tmpPrefs(checkCache) $prefs(checkCache)
    set tmpPrefs(mbsize)     [expr wide($prefs(cacheSize)/1e6)]
    
    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    set pca $wc.fr
    ttk::labelframe $pca -text [mc {File Cache}] \
      -padding [option get . groupSmallPadding {}]
    pack  $pca  -side top -anchor w
    
    ttk::label $pca.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 300 -justify left -text [mc preffilecache]
    pack $pca.msg -side top -anchor w

    set frca $pca.cas
    ttk::frame $frca
    pack $frca -fill x -pady 2
    
    ttk::label $frca.dsk -text "[mc {Disk Cache}]:"
    ttk::entry $frca.emb \
      -width 6 -textvariable [namespace current]::tmpPrefs(mbsize)
    ttk::label $frca.mb -text [mc {MBytes}]
    ttk::button $frca.bt -padx 12 -text [mc {Clear Disk Cache Now}] \
      -command [namespace current]::ClearCache
    
    pack  $frca.dsk  $frca.emb  $frca.mb  $frca.bt  -side left

    set frfo $pca.fo
    pack [ttk::frame $frfo] -pady 2
    pack [ttk::label $frfo.fo -text "[mc {Cache folder}]:"] -side left
    pack [ttk::button $frfo.bt -padx 6 -text "[mc {Choose}]..." \
      -command [namespace current]::SetCachePath]  \
      -side right 
        
    set pwhen $wc.frw
    ttk::labelframe $pwhen -text [mc prefcachecmp] \
      -padding [option get . groupSmallPadding {}]
    pack $pwhen -side top -fill x -pady 8
    foreach  \
      val { always       launch             never   } \
      txt { {Every time} {Once per session} {Never} } {
	ttk::radiobutton $pwhen.$val -text [mc $txt]   \
	  -variable [namespace current]::tmpPrefs(checkCache) -value $val
	grid $pwhen.$val -sticky w
    }
}

proc ::FileCache::SetCachePath { } {
    global  this prefs
    
    set dir [tk_chooseDirectory -title [mc {Pick Cache Folder}] \
      -initialdir $prefs(incomingPath) -mustexist 1]
    if {$dir ne ""} {
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

