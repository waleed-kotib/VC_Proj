#  tinyfileutils.tcl ---
#  
#      A collection of some small file utility procedures.
#      
#  Copyright (c) 2002-2003  Mats Bengtsson
#  
# $Id: tinyfileutils.tcl,v 1.4 2004-12-02 15:22:07 matben Exp $

package provide tinyfileutils 1.0


namespace eval ::tfileutils:: {}

# tfileutils::relative --
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

proc ::tfileutils::relative {srcpath dstpath} {
    global  tcl_platform

    if {![string equal [file pathtype $srcpath] "absolute"]} {
	return -code error "::tfileutils::relative: the path \"$srcpath\" is not of type absolute"
    }
    if {![string equal [file pathtype $dstpath] "absolute"]} {
	return -code error "::tfileutils::relative: the path \"$dstpath\" is not of type absolute"
    }

    # Need real path without any file for the source path.
    set srcpath [getdirname $srcpath]
    set up {../}
    set srclist [file split $srcpath]
    set dstlist [file split $dstpath]
    
    # Must get rid of the extra ":" volume specifier on mac.
    if {[string equal $tcl_platform(platform) "macintosh"]} {
	set srclist [lreplace $srclist 0 0  \
	  [string trimright [lindex $srclist 0] :]]
	set dstlist [lreplace $dstlist 0 0  \
	  [string trimright [lindex $dstlist 0] :]]
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
    return "${tmp}[join [lrange $dstlist $n end] /]"
}

# tfileutils::unixpath --
#
#       Translatates a native path type to a unix style.
#
# Arguments:
#       path        
#       
# Results:
#       The unix-style path of path.

proc ::tfileutils::unixpath {path} {
    global  tcl_platform
    
    set isabs [string equal [file pathtype $path] "absolute"]
    set plist [file split $path]
	
    # The volume specifier always leaves a ":"; {Macintosh HD:}
    if {$isabs && [string equal $tcl_platform(platform) "macintosh"]} {
	set volume [string trimright [lindex $plist 0] ":"]
	set plist [lreplace $plist 0 0 $volume]
    }
    set upath [join $plist /]
    if {$isabs} {
	set upath "/$upath"
    }
    return $upath
}

# Perhaps this could be replaced by [file normalize [file join ...]] ???

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

# tfileutils::appendfile --
#
#       Adds the second, relative path, to the first, absolute path.
#           
# Arguments:
#       dstFile     the destination file name
#       args        the files to append
#       
# Results:
#       none

proc ::tfileutils::appendfile {dstFile args} {
    
    set dst [open $dstFile {WRONLY APPEND}]
    fconfigure $dst -translation binary
    foreach f $args {
	set src [open $f RDONLY]
	fconfigure $src -translation binary
	fcopy $src $dst
	close $src
    }
    close $dst
}

# tfileutils::tempfile --
#
#   generate a temporary file name suitable for writing to
#   the file name will be unique, writable and will be in the 
#   appropriate system specific temp directory
#   Code taken from http://mini.net/tcl/772 attributed to
#    Igor Volobouev and anon.
#
# Arguments:
#   prefix     - a prefix for the filename, p
# Results:
#   returns a file name
#

proc ::tfileutils::tempfile {tmpdir prefix} {

    set chars "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    set nrand_chars 10
    set maxtries 10
    set access [list RDWR CREAT EXCL TRUNC]
    set permission 0600
    set channel ""
    set checked_dir_writable 0
    set mypid [pid]
    for {set i 0} {$i < $maxtries} {incr i} {
	set newname $prefix
	for {set j 0} {$j < $nrand_chars} {incr j} {
	    append newname [string index $chars \
	      [expr {([clock clicks] ^ $mypid) % 62}]]
	}
	set newname [file join $tmpdir $newname]
	if {[file exists $newname]} {
	    after 1
	} else {
	    if {[catch {open $newname $access $permission} channel]} {
		if {!$checked_dir_writable} {
		    set dirname [file dirname $newname]
		    if {![file writable $dirname]} {
			return -code error "Directory $dirname is not writable"
		    }
		    set checked_dir_writable 1
		}
	    } else {
		# Success
		close $channel
		return $newname
	    }
	}
    }
    if {[string compare $channel ""]} {
	return -code error "Failed to open a temporary file: $channel"
    } else {
	return -code error "Failed to find an unused temporary file name"
    }
}

#------------------------------------------------------------------------------
