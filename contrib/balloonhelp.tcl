#  balloonhelp.tcl --
#
#  By  Mats Bengtsson
#
#  Code idee from Harrison & McLennan
#  
# $Id: balloonhelp.tcl,v 1.9 2004-05-29 13:20:58 matben Exp $

package provide balloonhelp 1.0

namespace eval ::balloonhelp:: {
    
    variable locals
    variable debug 0
    
    set locals(active) 1
    set locals(millisecs) 1200
    
    option add *Balloonhelp*background            white     widgetDefault
    option add *Balloonhelp*foreground            black     widgetDefault
    option add *Balloonhelp.info.wrapLength       180       widgetDefault
    option add *Balloonhelp.info.justify          left      widgetDefault
    option add *Balloonhelp.millisecs             1200      widgetDefault
    
    # We use a variable 'locals(platform)' that is more convenient for Mac OS X.
    switch -- $::tcl_platform(platform) {
	unix {
	    set locals(platform) $::tcl_platform(platform)
	    if {[package vcompare [info tclversion] 8.3] == 1} {	
		if {[string equal [tk windowingsystem] "aqua"]} {
		    set locals(platform) "macosx"
		}
	    }
	}
	windows - macintosh {
	    set locals(platform) $::tcl_platform(platform)
	}
    }
    switch -- $locals(platform) {
	unix {
	    option add *Balloonhelp.info.font {Helvetica 10} widgetDefault
	}
	windows {
	    option add *Balloonhelp.info.font {Arial 8} widgetDefault
	}
	macintosh {
	    option add *Balloonhelp.info.font {Geneva 9} widgetDefault
	}
	macosx {
	    option add *Balloonhelp.info.font {Geneva 9} widgetDefault
	}
    }
}

proc ::balloonhelp::Build { } {
    
    variable locals

    # Java style popup: light blue schemata: bg=#D8E1F4, bd=#4A6EBC
    # Standard: light yellow: bg=#FFFF9F
    
    toplevel .balloonhelp -class Balloonhelp -background #FFFF9F \
      -bd 0 -relief flat
    pack [label .balloonhelp.info -bg #FFFF9F] -side left -fill y
    if {[string equal $locals(platform) "macintosh"]} {
	pack [frame .balloonhelp.pad -bg #FFFF9F -width 12] -side right
    }
    wm overrideredirect .balloonhelp 1
    wm transient .balloonhelp
    wm withdraw .balloonhelp
    wm resizable .balloonhelp 0 0 
    
    switch -- $locals(platform) {
	macintosh {
	    #documentProc, dBoxProc, plainDBox, altDBoxProc, movableDBoxProc, 
	    #zoomDocProc, rDocProc, floatProc, floatZoomProc, ->floatSideProc, 
	    #or floatSideZoomProc
	    if {[package vcompare [info tclversion] 8.3] == 1} {
		::tk::unsupported::MacWindowStyle style .balloonhelp floatSideProc
	    } else {
		unsupported1 style .balloonhelp floatSideProc
	    }
	}
	macosx {
	    tk::unsupported::MacWindowStyle style .balloonhelp help none
	}
    }
}

proc ::balloonhelp::configure {args} {
    
    variable locals
    
    array set opts [list -active $locals(active) -millisecs $locals(millisecs)]
    if {[llength $args] == 0} {
	return $opts
    } elseif {[llength $args] == 1} {
	return $locals($args)
    }
    foreach {key value} $args {
	switch -regexp -- $key {
	    -act* {
		set locals(active) [regexp -nocase {^(1|yes|true|on)$} $value]
	    }
	    -mil* {
		set locals(millisecs) $value
	    }
	}
    }
}

proc ::balloonhelp::balloonforwindow {win msg args} {

    variable locals
    
    set locals($win) $msg
    set locals($win,args) $args
    # Perhaps we shall have "+" for all bindings to not interfere...
    bind $win <Enter> [list ::balloonhelp::Pending %W "window"]
    bind $win <Leave> [list ::balloonhelp::Cancel %W]
    bind $win <Button-1> {+ ::balloonhelp::Cancel %W}
}

proc ::balloonhelp::balloonforcanvas {win itemid msg args} {

    variable locals  
    
    Debug 2 "::balloonhelp::balloonforcanvas win=$win, itemid=$itemid"
    set locals($win,$itemid) $msg
    set locals($win,args) $args
    regsub -all {%} $itemid {%%} subItemId

    $win bind $itemid <Enter>  \
      [list ::balloonhelp::Pending %W "canvas" -x %X -y %Y -itemid $subItemId]
    $win bind $itemid <Leave> [list ::balloonhelp::Cancel %W]
    $win bind $itemid <Button-1> {+ ::balloonhelp::Cancel %W}
}

proc ::balloonhelp::balloonfortree {win itemid msg args} {

    variable locals    

    set wcanvas [$win getcanvas]
    eval {balloonforcanvas $wcanvas $itemid $msg} $args
}

proc ::balloonhelp::balloonfortext {win tag msg args} {

    variable locals    
    Debug 2 "::balloonhelp::balloonfortext win=$win, tag=$tag"
    set locals($win,$tag) $msg
    set locals($win,args) $args
    regsub -all {%} $tag {%%} subTag

    $win tag bind $tag <Enter>  \
      [list ::balloonhelp::Pending %W "text" -x %X -y %Y -tag $subTag]
    $win tag bind $tag <Leave> [list ::balloonhelp::Cancel %W]
    $win tag bind $tag <Button-1> {+ ::balloonhelp::Cancel %W}
}

#       args:  ?-key value ...?
#                   -x        root x coordinate
#                   -y        root y coordinate
#                   -tag      tag for text windows
#                   -itemid   item id for canvas item

proc ::balloonhelp::Pending {win type args} {

    variable locals
    Debug 2 "::balloonhelp::Pending win=$win, args='$args'"
    foreach {key value} $args {
	set locals($win,[string trimleft $key -]) $value
    }
    ::balloonhelp::Cancel $win
    set locals(pending)  \
      [after $locals(millisecs) [list ::balloonhelp::Show $win $type]]
}

proc ::balloonhelp::Cancel {win} {
    
    variable locals    
    Debug 2 "::balloonhelp::Cancel"
    if {[info exists locals(pending)]} {
	after cancel $locals(pending)
	unset locals(pending)
    }
    if {[winfo exists .balloonhelp]} {
	catch {
	    #puts "[focus -lastfor .balloonhelp]"
	    #focus [focus -lastfor .balloonhelp]
	    wm withdraw .balloonhelp
	}
	#focus .
    }
}

proc ::balloonhelp::Show {win type} {
    
    variable locals    

    if {![winfo exists .balloonhelp]} {
	::balloonhelp::Build
	update idletasks
    }
    set exists 0
    
    if {$locals(active)} {
	switch -- $type {
	    canvas {
		
		# Be sure to take any scrolling into account.
		set xoff 0
		set yoff 0
		set scrollregion [$win cget -scrollregion]
		if {[llength $scrollregion] > 0} {
		    foreach {sx sy swidth sheight} $scrollregion break
		    set xoff [expr int($swidth * [lindex [$win xview] 0])]
		    set yoff [expr int($sheight * [lindex [$win yview] 0])]
		}
		set itemid $locals($win,itemid)
		set msg $locals($win,$itemid)
		set bbox [$win bbox $itemid]
		
		# If no bounding box the item has been deleted.
		if {[llength $bbox] == 4} {
		    set exists 1
		    foreach {x0 y0 x1 y1} $bbox break
		    set x $locals($win,x)
		    set y [expr [winfo rooty $win] - $yoff + $y1 + 2]
		}
	    }
	    text {
		set tag $locals($win,tag)
		set msg $locals($win,$tag) 
		set range [$win tag nextrange $tag 1.0]
		set bbox [$win bbox [lindex $range 1]]

		# If no bounding box the item has been deleted.
		if {[llength $bbox] == 4} {
		    set exists 1
		    foreach {x0 y0 w0 h0} $bbox break
		    set ymax [expr $y0+$h0]
		    set x $locals($win,x)
		    set y [expr [winfo rooty $win] + $ymax + 2]
		}
	    }
	    window {
		if {[winfo exists $win]} {
		    set exists 1
		    set msg $locals($win)
		    set x [expr [winfo rootx $win] + 10]
		    set y [expr [winfo rooty $win] + [winfo height $win]]
		}
	    }
	}
	if {$exists} {
	    eval {.balloonhelp.info configure -text $msg} $locals($win,args)
	    wm geometry .balloonhelp +$x+$y
	    update idletasks
	    wm deiconify .balloonhelp
	    raise .balloonhelp
	}
    }
    unset locals(pending)
}

proc ::balloonhelp::Debug {num str} {
    variable debug
    if {$num <= $debug} {
	puts $str
    }
}

#-------------------------------------------------------------------------------
