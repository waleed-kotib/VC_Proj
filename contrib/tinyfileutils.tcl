#  tinyfileutils.tcl ---
#  
#      A collection of some small file utility procedures.
#      
#  Copyright (c) 2002  Mats Bengtsson
#  
# $Id: tinyfileutils.tcl,v 1.1.1.1 2002-12-08 10:56:27 matben Exp $

package provide tinyfileutils 1.0

# filenormalize --
#
#	Takes an absolute path containing any "../" and returns the
#	normalized path without any "../". Same with "::" on the mac.
#
# Arguments:
#       path        typically [file join abspath relativepath]
#       
# Results:
#       The normalized absolute path, always returns native paths.

proc filenormalize {path} {
    
    if {![string equal [file pathtype $path] "absolute"]} {
	return -code error "The path \"$path\" is not of type absolute"
    }
    
    # Mac needs special treatment.
    if {[string equal $::tcl_platform(platform) "macintosh"]} {
	return [filenormalizemac $path]
    } else {
	set up_ {..}
	set tmp {}
	foreach part [file split $path] {
	    if {[string equal $part $up_]} {
		set tmp [lreplace $tmp end end]
	    } else {
		lappend tmp $part
	    }
	}
	return [eval {file join} $tmp]
    }
}

# filenormalizemac --
#
#       Takes an absolute path containing any "::" (or :::) and returns the
#	normalized path without any "::". Mac only!
#	 
# Arguments:
#       path        an absolute path mac style
#       
# Results:
#       The normalized absolute path, always returns native paths.

proc filenormalizemac {path} {
    
    if {![string equal [file pathtype $path] "absolute"]} {
	return -code error "The path \"$path\" is not of type absolute"
    }
    
    # Example: 'file split aaa:bbb:ccc::xxx' -> 'aaa: bbb ccc :: xxx'
    set splitList [file split $path]
    set tmp [lindex $splitList 0]
    set splitList [lrange $splitList 1 end]
    foreach part $splitList {
	set nup [expr [regsub -all : $part "" x] - 1]
	if {$nup > 0} {
	    incr nup -1
	    set tmp [lreplace $tmp end-${nup} end]
	} else {
	    lappend tmp $part
	}
    }
    return [eval {file join} $tmp]
}

# filerelative --
#
#       Constructs the relative file path from one absolute path to
#       another absolute path.
#
# Arguments:
#       srcpath        An absolute file path.
#	dstpath        An absolute file path.
#       
# Results:
#       The relative (unix-style) path from 'srcpath' to 'dstpath'.

proc filerelative {srcpath dstpath} {

    if {![string equal [file pathtype $srcpath] "absolute"]} {
	return -code error "filerelative: the path \"$srcpath\" is not of type absolute"
    }
    if {![string equal [file pathtype $dstpath] "absolute"]} {
	return -code error "filerelative: the path \"$dstpath\" is not of type absolute"
    }

    # Need real path without any file for the source path.
    set srcpath [getdirname $srcpath]
    set up {../}
    set srclist [file split $srcpath]
    set dstlist [file split $dstpath]
    # not sure this is a good idea...
    if {0 && [string equal $::tcl_platform(platform) "windows"]} {
	set srclist [string tolower $srclist]
	set dstlist [string tolower $dstlist]
    }
    set lensrc [llength $srclist]
    set lendst [llength $dstlist]
    set minlen [expr ($lensrc < $lendst) ? $lensrc : $lendst]

    # Find first nonidentical dir; n = the number of common dirs
    # If there are no common dirs we are left with n = 0???    
    set n 0
    while {[string equal [lindex $srclist $n] [lindex $dstlist $n]] && \
      ($n < $minlen)} {
	incr n
    }
    set numUp [expr $lensrc - $n]
    set tmp {}
    for {set i 1} {$i <=$numUp} {incr i} {
	append tmp $up
    }
    return "$tmp[join [lrange $dstlist $n end] /]"
}

# unixpathtype --
#
#       Translatates a native path type to a unix style.
#
# Arguments:
#       path        
#       
# Results:
#       The unix-style path of path.

proc unixpathtype {path} {
    
    set isabs [string equal [file pathtype $path] "absolute"]
    set plist [file split $path]
	
    # The volume specifier always leaves a ":"; {Macintosh HD:}
    if {$isabs && [string equal $::tcl_platform(platform) "macintosh"]} {
	set volume [string trimright [lindex $plist 0] ":"]
	set plist [lreplace $plist 0 0 $volume]
    }
    set upath [join $plist /]
    if {$isabs} {
	set upath "/$upath"
    }
    return $upath
}

# addabsolutepathwithrelative ---
#
#       Adds the second, relative path, to the first, absolute path.
#       Always returns unix style absolute path.
#           
# Arguments:
#       absPath        an absolute path which is the "original" path.
#       toPath         a relative path which should be added.
#       
# Results:
#       The absolute unix style path by adding 'absPath' with 'relPath'.

proc addabsolutepathwithrelative {absPath relPath} {
    global  tcl_platform
    
    set state(debug) 0
    if {$state(debug) >= 3} {
	puts "addabsolutepathwithrelative:: absPath=$absPath, relPath=$relPath"
    }

    # Be sure to strip off any filename of the absPath.
    set absPath [getdirname $absPath]
    if {[file pathtype $absPath] != "absolute"} {
	error "first path must be an absolute path"
    } elseif {[file pathtype $relPath] != "relative"} {
	error "second path must be a relative path"
    }

    # This is the method to reach platform independence.
    # We must be sure that there are no path separators left.    
    set absP {}
    foreach elem [file split $absPath] {
	lappend absP [string trim $elem "/:\\"]
    }
    
    # If any up dir (../ ::  ), find how many. Only unix style.
    set nup [regsub -all {\.\./} $relPath {} newRelPath]
    # Mac???
    #set nup [expr [regsub -all : $part "" x] - 1]
   
    # Delete the same number of elements from the end of the absolute path
    # as there are up dirs in the relative path.    
    if {$nup > 0} {
	set iend [expr [llength $absP] - 1]
	set upAbsP [lreplace $absP [expr $iend - $nup + 1] $iend]
    } else {
	set upAbsP $absP
    }
    set relP {}
    foreach elem [file split $newRelPath] {
	lappend relP [string trim $elem "/:\\"]
    }
    set completePath "$upAbsP $relP"

    # On Windows we need special treatment of the "C:/" type drivers.
    if {[string equal $tcl_platform(platform) "windows"]} {
    	set finalAbsPath   \
	    "[lindex $completePath 0]:/[join [lrange $completePath 1 end] "/"]"
    } else {
        set finalAbsPath "/[join $completePath "/"]"
    }
    return $finalAbsPath
}

#------------------------------------------------------------------------------
