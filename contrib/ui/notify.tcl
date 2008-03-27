# notify.tcl
# 
#       A pure Tcl Growl like x-platform notification window.
#       Do not mixup with the outdated notebox package.
#
#  Copyright (c) 2008
#  
#  This source file is distributed under the BSD license.
#  
#  $Id: notify.tcl,v 1.3 2008-03-27 15:15:26 matben Exp $

package require Tk 8.5
package require tkpath 0.2.8 ;# switch to 0.3 later on
package require snit 1.0
package require msgcat
package require ui::util

package provide ui::notify 0.1

namespace eval ui::notify {

    option add *Growl*takeFocus 0
}

interp alias {} ui::notify {} ui::notify::widget

snit::widget ui::notify::widget {

    hulltype toplevel
    widgetclass Growl
    delegate option * to hull except {
	-image -message -title
    }    
    delegate method * to hull
    
    option -image   -configuremethod OnImage
    option -message -configuremethod OnMessage
    option -title   -configuremethod OnTitle
    
    typevariable ttl 6000
    typevariable width 300
    typevariable height 60
    typevariable margin 10
    typevariable opacity 0.5	
    
    typevariable occupied
    typevariable nx
    typevariable ny
    
    variable fadeinID
    variable fadeoutID
    variable ttlID
    variable canvas
    variable position
    variable prevFocus
    
    typeconstructor {
	
	# Make grid of complete screen area and keep track of occupied and free.
	set sw [winfo screenwidth .]
	set sh [winfo screenheight .]
	set topmargin $margin
 	if {[tk windowingsystem] eq "aqua"} {
	    set topmargin 24
	}
	set nx [expr {$sw/($width + $margin)}]
	set ny [expr {($sh - $topmargin)/($height + $margin)}]
    }
    
    typemethod GetXYFromIndices {ix iy} {
	set topmargin $margin
 	if {[tk windowingsystem] eq "aqua"} {
	    set topmargin 24
	}
	set x [expr {[winfo screenwidth .] - ($ix + 1) * ($width + $margin)}]
	set y [expr {$topmargin + $iy * ($height + $margin)}]
	return [list $x $y]
    }
    
    typemethod NewIndices {} {
	for {set i 0} {$i < $nx} {incr i} {
	    for {set j 0} {$j < $ny} {incr j} {
		if {![info exists occupied($i,$j)]} {
		    return [list $i $j]
		}
	    }
	}
    }
    
    typemethod reset {} {
	unset -nocomplain occupied
    }
    
    constructor {args} {
	
	array set fontA [font actual TkDefaultFont]
	set family1 $fontA(-family)
	set fsize1 $fontA(-size)
	array set fontA [font actual TkTooltipFont]
	set family2 $fontA(-family)
	set fsize2 $fontA(-size)
	
	set prevFocus [focus]
	puts "prevFocus=$prevFocus"
	
 	set opts [list]
 	switch -- [tk windowingsystem] {
 	    aqua {
 		lappend opts -transparent 1 -topmost 1
 	    }
 	    win32 {
 		lappend opts -alpha 0.8 -transparentcolor purple -topmost 1
 	    }
 	}
	wm overrideredirect $win 1
	switch -- [tk windowingsystem] {
	    aqua {
		#tk::unsupported::MacWindowStyle style $win help {}
 		$win configure -bg systemTransparent
	    }
	    win32 {
		$win configure -bg purple
	    }
	}
	wm attributes $win {*}$opts

	# NB: If we do this before 'unsupported' it takes focus !?
	wm resizable $win 0 0 
	
	set canvas $win.c
	canvas $canvas -width $width -height $height -bd 0 -highlightthickness 0
	switch -- [tk windowingsystem] {
	    aqua {
		$canvas configure -bg systemTransparent
	    }
	    win32 {
		$canvas configure -bg purple
	    }
	}
	pack $canvas
 	$canvas create prect 0 0 $width $height -rx 12 -stroke "" -fill black \
 	  -fillopacity $opacity
	$canvas create pimage 10 10 -tags image -width 32 -height 32
	$canvas create ptext 60 22 -tags title \
	  -fontfamily $family1 -fontsize $fsize1 -fill white	  
	$canvas create ptext 60 48 -tags message \
	  -fontfamily $family2 -fontsize $fsize2 -fill white
	
	$self configurelist $args

# 	wm geometry $win +400+400
# 	wm geometry $win +800+400
	
	$self Position
        bind $win <FocusIn> [list $self FocusIn]
	
	$self FadeIn {0.1 0.2 0.3 0.4 0.5 0.6 0.8 0.9 1.0}
    }
    
    destructor {
	if {[info exists fadeinID]} {
	    after cancel $fadeinID
	}
	if {[info exists fadeoutID]} {
	    after cancel $fadeoutID
	}
	if {[info exists ttlID]} {
	    after cancel $ttlID
	}
    }
    
    method FocusIn {} {
	
	puts "FocusIn focus=[focus]"
	if {[winfo exists $prevFocus]} {
	    focus $prevFocus
	}
    }
    
    method Position {} {
	lassign [ui::notify NewIndices] i j	
	lassign [ui::notify GetXYFromIndices $i $j] x y
	wm geometry $win +$x+$y
	set occupied($i,$j) 1
	set position [list $i $j]
    }
    
    method OnImage {option value} {
	set options($option) $value
	$canvas itemconfigure image -image $value
    }
    
    method OnTitle {option value} {
	set options($option) $value
	$canvas itemconfigure title -text $value
    }
    
    method OnMessage {option value} {
	set options($option) $value
	$canvas itemconfigure message -text $value
    }

    method FadeIn {fades} {
	if {[llength $fades]} {
	    wm attributes $win -alpha [lindex $fades 0]
	    set fadeinID [after 80 [list $self FadeIn [lrange $fades 1 end]]]
	} else {
	    set ttlID [after $ttl [list $self FadeOut {0.95 0.9 0.85 0.8 0.75 0.7 0.65 0.6 0.55 0.5 0.4 0.3 0.2}]]
	}
    }

    method FadeOut {fades} {
	if {[llength $fades]} {
	    wm attributes $win -alpha [lindex $fades 0]
	    set fadeoutID [after 80 [list $self FadeOut [lrange $fades 1 end]]]
	} else {
	    $self Dismiss
	}
    }

    method Dismiss {} {
	lassign $position i j
	unset -nocomplain occupied($i,$j)
	destroy $win
    }
    
    # Public methods:
    
}

if {0} {
    set tkpath::antialias 1
    package require ui::notify
    set cociFile [file join $this(imagePath) bug-128.png]
    set image [image create photo -file $cociFile]
    destroy .ntfy
    ui::notify .ntfy -title "Kilroy was here" \
      -message "Hej svejs i lingonskogen" \
      -image $image
    
    
}

#-------------------------------------------------------------------------------








