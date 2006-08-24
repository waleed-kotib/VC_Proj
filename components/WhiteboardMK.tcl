# WhiteboardMK.tcl --
# 
#       Registers a metakit file format for whiteboards.
#       
# $Id: WhiteboardMK.tcl,v 1.2 2006-08-24 07:01:36 matben Exp $

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
    set tmpCan [::tfileutils::tempfile $this(tmpPath) ""]
    append tmpCan .can
    set tmpfd [open $tmpCan {CREAT WRONLY}]
    fconfigure $tmpfd -encoding utf-8
    ::CanvasFile::CanvasToChannel $wcan $tmpfd $tmpCan -pathtype absolute
    close $tmpfd
    
    # Make a VFS. 'fileName' will be a dir in VFS sense.
    # Creating a file using 'open' and then writing wont work!
    set compress $mk4vfs::compress
    set mk4vfs::compress 0
    vfs::mk4::Mount $fileName $fileName

    ::CanvasFile::FlattenToDir $tmpCan $fileName
    
    # Must rename the tmp file to tail of 'fileName'.
    set vfstmpCan [file join $fileName [file tail $tmpCan]]
    set canTail [file rootname [file tail $fileName]].can
    set newCan [file join $fileName $canTail]
    file rename -force $vfstmpCan $newCan
        
    vfs::unmount $fileName
    set mk4vfs::compress $compress
}

proc ::WhiteboardMK::Open {wcan fileName} {

    # Pick the ordinary canvas file inside vfs.
    vfs::mk4::Mount $fileName $fileName
    set can [file rootname [file tail $fileName]].can
    ::CanvasFile::OpenCanvas $wcan [file join $fileName $can]
    vfs::unmount $fileName
}

