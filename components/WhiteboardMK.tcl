# WhiteboardMK.tcl --
# 
#       Registers a metakit file format for whiteboards.
#  
#  Copyright (c) 2007 Mats Bengtsson
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#       
# $Id: WhiteboardMK.tcl,v 1.4 2007-07-18 09:40:10 matben Exp $

namespace eval ::WhiteboardMK {}

proc ::WhiteboardMK::Init { } {
    
    if {![::Jabber::HaveWhiteboard]} {
	return
    }
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

