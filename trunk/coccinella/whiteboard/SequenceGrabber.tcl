# SequenceGrabber.tcl ---
#
#    Contains the tcl code to handle the sequence grabber.
#
#    Copyright (c) 2002   Mats Bengtsson
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
# $Id: SequenceGrabber.tcl,v 1.3 2007-07-19 06:28:19 matben Exp $

#---------------------------------------------------------------------
#   DisplaySequenceGrabber ---
#
#   Start the sequence grabber in a window in the canvas.
#   The sequence grabber is given the status of a movie item.

proc DisplaySequenceGrabber  {wtop}  {
    global  allIPnumsToSend prefs seqGrabPath
    
    upvar ::${wtop}::wapp wapp

    Debug 2 "DisplaySequenceGrabber:: "

    set w $wapp(can)
    set utag [::CanvasUtils::NewUtag]
    set fr ${w}.fr_sg${utag}
    
    # Make a frame for the grabber; need special class to catch mouse events.
    frame $fr -height 1 -width 1 -bg gray40 -class SGFrame
    
    # Start the sequence grabber.
    if {[catch {seqgrabber ${fr}.sg} msg]}  {
	::UI::MessageBox -message "Error: couldn,t start the camera."  \
	  -icon error -type ok
	catch {destroy $fr}
	return
    }
    set seqGrabPath $msg	
    set anc [::CanvasUtils::NewImportAnchor $w]
    
    # We keep the item tag 'movie', and add a new tag 'grabber'.
    $w create window [lindex $anc 0] [lindex $anc 1] -anchor nw  \
      -window $fr -tags [list movie grabber $utag]
    place $seqGrabPath -in $fr -anchor nw -x 3 -y 3
    #pack $mpath -in $fr -padx 3 -pady 3
    update
    set height [winfo height $seqGrabPath]
    set width [winfo width $seqGrabPath]
    $fr configure -width [expr $width + 6] -height [expr $height + 6]
}

proc SetVideoConfig  { wtop what {opt {}} }  {
    global  allIPnumsToSend prefs seqGrabPath

    upvar ::${wtop}::wapp wapp

    if {![winfo exists $seqGrabPath]} {
	return
    }
    set w $wapp(can)
    
    switch -- $what {
	audiosettings {
	    if {[catch {$seqGrabPath audiosettings} res]} {
		::UI::MessageBox -message "Error:  $res" -icon error -type ok
		return
	    }
	}
	pause {
	    $seqGrabPath pause $opt
	}
	picture {
	    
	    # Open a file?
	    if {[catch {$seqGrabPath picture $opt } res]} {
		::UI::MessageBox -message "Error:  $res" -icon error -type ok
		return
	    }
	}
	size {
	    $seqGrabPath configure -size $prefs(videoSize)
	}
	videosettings {
	    if {[catch {$seqGrabPath videosettings} res]} {
		::UI::MessageBox -message "Error:  $res" -icon error -type ok
		return
	    }
	}
	zoom {
	    $seqGrabPath configure -zoom $prefs(videoZoom)
	}
	
    }
	
}