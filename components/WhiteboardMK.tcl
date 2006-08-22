# WhiteboardMK.tcl --
# 
#       Registers a metakit file format for whiteboards.
#       
# $Id: WhiteboardMK.tcl,v 1.1 2006-08-22 14:25:18 matben Exp $

namespace eval ::WhiteboardMK {}

proc ::WhiteboardMK::Init { } {
    
    if {[catch {
	package require vfs
	package require vfs::mk4
    }]} {
	return
    }
    component::register WhiteboardMK  \
      "Provides a metakit database to save complete whiteboards in a single file."
    
    ::CanvasFile::RegisterSaveFormat WhiteboardMK Metakit .cmk  \
      ::WhiteboardMK::Save
    ::CanvasFile::RegisterOpenFormat WhiteboardMK Metakit .cmk  \
      ::WhiteboardMK::Open
}

proc ::WhiteboardMK::Save {wcan fileName} {
    global  this
    
    # Work on a temporary file.
    set tmp [::tfileutils::tempfile $this(tmpPath) ""]
    set origfd [open $tmp {CREAT RDWR }]
    fconfigure $origfd -encoding utf-8
    ::CanvasFile::CanvasToFile $wcan $origfd $tmp
    seek $origfd 0
    
    set new [::tfileutils::tempfile $this(tmpPath) ""]
    set newfd [open $new {CREAT WRONLY}]
    fconfigure $newfd -encoding utf-8

    # Must process all -file options to point to the ones in vfs.
    # @@@ Perhaps a generic API?
    while {[gets $origfd line] >= 0} { 
	if {[regexp {(^ *#|^[ \n\t]*$)} $line]} {
	    puts $newfd $line
	    continue
	}
	set cmd [lindex $line 0]
	if {$cmd ne "import"} {
	    puts $newfd $line
	    continue
	}
	set idx [lsearch -exact $line -file]
	if {$idx >= 0} {
	    set src [lindex $line [incr idx]]

	    # Protect for duplicate tails.
	    set tail [file tail $src]
	    if {[info exists tailA($tail)]} {
		set suff [file extension $src]
		set root [file rootname $tail]
		set n 0
		set newTail ${root}-[incr n]$suff
		while {[info exists tailA($newTail)]} {
		    set newTail ${root}-[incr n]$suff
		}
		set dstTail $newTail
	    } else {
		set dstTail $tail
	    }
	    set tailA($dstTail) 1
	    set dst [file join $fileName $dstTail]

	    # Map from original file name to vfs file name.
	    set map($src) $dst

	    lset line $idx $dstTail
	    puts $newfd $line
	}
    }
    close $origfd
    close $newfd    

    file delete -force $fileName

    set compress $mk4vfs::compress
    set mk4vfs::compress 0
    vfs::mk4::Mount $fileName $fileName

    # Save as an ordinary can file inside vfs.
    set canFile [file rootname [file tail $fileName]].can
    
    # Copy all files.
    file copy $new [file join $fileName $canFile]
    foreach {src dst} [array get map] {
	file copy $src $dst
    }
    
    set mk4vfs::compress $compress
    vfs::unmount $fileName
}

proc ::WhiteboardMK::Open {wcan fileName} {

    # Pick the ordinary canvas file inside vfs.
    # QuickTime can't read vfs files :-(
    vfs::mk4::Mount $fileName $fileName
    set can [file rootname [file tail $fileName]].can
    ::CanvasFile::OpenCanvas $wcan [file join $fileName $can]
    vfs::unmount $fileName
}

