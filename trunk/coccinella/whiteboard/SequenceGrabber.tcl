# SequenceGrabber.tcl ---
#
#    Contains the tcl code to handle the sequence grabber.
#
#    Copyright (c) 2002   Mats Bengtsson
#    
# $Id: SequenceGrabber.tcl,v 1.2 2004-12-02 08:22:35 matben Exp $

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