#  balloonhelp.tcl --
#
#  By  Mats Bengtsson
#
#  Code idee from Harrison & McLennan
#  This source file is distributed under the BSD license.
#  
# $Id: balloonhelp.tcl,v 1.22 2006-08-02 07:03:34 matben Exp $

package require treeutil

package provide balloonhelp 1.0

namespace eval ::balloonhelp:: {
    
    variable locals
    variable debug 0
    variable w .balloonhelp
    
    set locals(active) 1
    set locals(initted) 0
    set locals(fadeout) {0.95 0.9 0.85 0.8 0.75 0.7 0.65 0.6 0.55 0.5 0.4 0.3 0.2}
    set locals(fadeout) {0.9 0.8 0.7 0.6 0.5 0.4 0.3 0.2}

    # Java style popup: light blue schemata: bg=#D8E1F4, bd=#4A6EBC
    # Standard: light yellow: bg=#FFFF9F
    
    option add *Balloonhelp.background            #FFFF9F   widgetDefault
    option add *Balloonhelp.foreground            black     widgetDefault
    option add *Balloonhelp.wrapLength            180       widgetDefault
    option add *Balloonhelp.justify               left      widgetDefault
    option add *Balloonhelp.millisecs             2000      widgetDefault
    option add *Balloonhelp.timeout               0         widgetDefault
    
    switch -- [tk windowingsystem] {
	x11 {
	    option add *Balloonhelp.font {Helvetica -10} widgetDefault
	}
	win32 {
	    option add *Balloonhelp.font {Arial 8} widgetDefault
	}
	aqua {
	    option add *Balloonhelp.font {Geneva 9} widgetDefault
	}
    }
}

proc ::balloonhelp::Init { } {
    
    variable w
    variable locals

    if {!$locals(initted)} {
	Build
	set locals(millisecs) [option get $w millisecs {}]
	set locals(timeout)   [option get $w timeout {}]
	set locals(initted) 1
    }
}

proc ::balloonhelp::Build { } {
    
    variable w
    variable locals
    
    toplevel $w -class Balloonhelp -bd 0 -relief flat
    set bg   [option get $w background {}]
    set fg   [option get $w foreground {}]
    set wrap [option get $w wrapLength {}]
    set just [option get $w justify {}]

    pack [label $w.info -bg $bg -fg $fg -wraplength $wrap -justify $just]  \
      -side left -fill y

    wm overrideredirect $w 1
    wm transient $w
    wm withdraw  $w
    wm resizable $w 0 0 
    
    if {[tk windowingsystem] eq "aqua"} {
	tk::unsupported::MacWindowStyle style $w help none
    }

    array set wmArr [wm attributes $w]
    if {[info exists wmArr(-alpha)]} {
	set locals(alpha) 1
    } else {
	set locals(alpha) 0
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
	    -time* {
		set locals(timeout) $value
	    }
	}
    }
}

proc ::balloonhelp::balloonforwindow {win msg args} {

    variable locals
    
    Init
    set locals($win) $msg
    set locals($win,args) $args
    # Perhaps we shall have "+" for all bindings to not interfere...
    bind $win <Enter>    {+::balloonhelp::Pending %W "window" }
    bind $win <Leave>    {+::balloonhelp::Cancel %W }
    bind $win <Button>   {+::balloonhelp::Cancel %W }
    bind $win <Destroy>  {+::balloonhelp::Free %W }
}

proc ::balloonhelp::balloonforcanvas {win itemid msg args} {

    variable locals  
    
    Debug 2 "::balloonhelp::balloonforcanvas win=$win, itemid=$itemid"

    Init
    set locals($win,$itemid) $msg
    set locals($win,args) $args
    regsub -all {%} $itemid {%%} subItemId

    $win bind $itemid <Enter>  \
      [list ::balloonhelp::Pending %W "canvas" -x %X -y %Y -itemid $subItemId]
    $win bind $itemid <Leave> [list ::balloonhelp::Cancel %W]
    $win bind $itemid <Button> {+ ::balloonhelp::Cancel %W}
    bind $win <Destroy>  {+::balloonhelp::Free %W }
}

proc ::balloonhelp::treectrl {win item msg args} {

    variable locals  

    Init
    set locals($win,$item) $msg
    set locals($win,args) $args

    ::treeutil::bind $win $item <Enter>  \
      {+::balloonhelp::Pending %T "treectrl" -x %x -y %y -item %I}
    ::treeutil::bind $win $item <Leave> {+::balloonhelp::Cancel %T }    
    bind $win <Button>   {+::balloonhelp::Cancel %W }
    bind $win <Destroy>  {+::balloonhelp::Free %W }
}

# ::balloonhelp::treectrl_set --
# 
#       Plugin model for adding extra messages.

proc ::balloonhelp::treectrl_set {win item name {msg ""}} {

    variable locals  

    if {$msg eq ""} {
	unset -nocomplain locals($win,$item,$name)
    } else {
	set locals($win,$item,$name) $msg
    }
}

proc ::balloonhelp::balloonfortree {win itemid msg args} {

    variable locals    

    Init
    set wcanvas [$win getcanvas]
    eval {balloonforcanvas $wcanvas $itemid $msg} $args
}

proc ::balloonhelp::balloonfortext {win tag msg args} {

    variable locals    
    Debug 2 "::balloonhelp::balloonfortext win=$win, tag=$tag"

    Init
    set locals($win,$tag) $msg
    set locals($win,args) $args
    regsub -all {%} $tag {%%} subTag

    $win tag bind $tag <Enter>  \
      [list ::balloonhelp::Pending %W "text" -x %X -y %Y -tag $subTag]
    $win tag bind $tag <Leave>  { ::balloonhelp::Cancel %W }
    $win tag bind $tag <Button> {+::balloonhelp::Cancel %W }
    bind $win <Destroy> {+::balloonhelp::Free %W }
}

#       args:  ?-key value ...?
#                   -x        root x coordinate
#                   -y        root y coordinate
#                   -tag      tag for text windows
#                   -itemid   item id for canvas item
#                   -item     item for treectrl

proc ::balloonhelp::Pending {win type args} {

    variable locals
    Debug 2 "::balloonhelp::Pending win=$win, args='$args'"
    foreach {key value} $args {
	set locals($win,[string trimleft $key -]) $value
    }
    Cancel $win
    set locals(pending)  \
      [after $locals(millisecs) [list ::balloonhelp::Show $win $type]]
}

proc ::balloonhelp::Cancel {win} {
    
    variable w
    variable locals    
    Debug 2 "::balloonhelp::Cancel"
    
    if {[info exists locals(pending)]} {
	after cancel $locals(pending)
	unset locals(pending)
    }
    if {[info exists locals(timeoutID)]} {
	after cancel $locals(timeoutID)
	unset locals(timeoutID)
    }
    if {[info exists locals(fadeoutID)]} {
	after cancel $locals(fadeoutID)
	unset locals(fadeoutID)
    }
    if {[winfo exists $w]} {
	wm withdraw $w
    }
    if {[info exists locals(focus)] && ($locals(focus) ne $w)} {
	# catch {focus $locals(focus)}
    }
}

proc ::balloonhelp::Timeout {win} {
    variable locals    
    
    Debug 2 "::balloonhelp::Timeout"
    
    if {$locals(alpha)} {
	Fadeout $win $locals(fadeout)
    } else {
	Cancel $win
    }
}

proc ::balloonhelp::Fadeout {win fades} {
    variable w
    variable locals    

    if {[llength $fades]} {
	wm attributes $w -alpha [lindex $fades 0]
	set locals(fadeoutID)  \
	  [after 80 [list ::balloonhelp::Fadeout $win [lrange $fades 1 end]]]
    } else {
	Cancel $win
    }
}

proc ::balloonhelp::Show {win type} {
    
    variable w
    variable locals
    
    Debug 2 "::balloonhelp::Show"

    if {![winfo exists $win]} {
	unset -nocomplain locals(pending)
	return
    }
    set wfocus [focus]
    if {$wfocus ne $w} {
	set locals(focus) $wfocus
    }
    set exists 0
    set msg ""
    set bbox {}
    
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
		    if {[winfo class $win] eq "TrayIcon"} {
			set bbox [$win bbox]
			if {$bbox ne ""} {
			    set x [expr {[lindex $bbox 0] - 10}]
			    set y [expr {[lindex $bbox 1] - 20}]
			} else {
			    set exists 0
			}
		    } else {
			set x [expr {[winfo rootx $win] + 10}]
			set y [expr {[winfo rooty $win] + [winfo height $win]}]
		    }
		}
	    }
	    treectrl {
		set item [$win item id $locals($win,item)]
		if {$item ne ""} {
		    set exists 1
		    set bbox [$win item bbox $item]
		    set x $locals($win,x)
		    set y [lindex $bbox 3]
		    set x [expr {[winfo rootx $win] + $x}]
		    set y [expr {[winfo rooty $win] + $y}]
		    set msg $locals($win,$item)
		    
		    foreach {key value} [array get locals $win,$item,*] {
			append msg $value
		    }
		}
	    }
	}
	if {$exists} {
	    eval {$w.info configure -text $msg} $locals($win,args)
	    update idletasks
	    SetPosition $x $y $bbox
	    wm deiconify $w
	    raise $w
	    if {$locals(alpha)} {
		wm attributes $w -alpha 1.0
	    }
	}
	if {$locals(timeout)} {
	    set locals(timeoutID)  \
	      [after $locals(timeout) [list ::balloonhelp::Timeout $win]]
	}
    }
    unset -nocomplain locals(pending)
}

# SetPosition --
# 
#       Be sure to position the help window outside the bbox but inside the screen.

proc ::balloonhelp::SetPosition {x y bbox} {
    
    variable w

    if {[winfo exists $w]} {
	set width  [winfo reqwidth $w]
	set height [winfo reqheight $w]
	set screenwidth  [winfo screenwidth $w]
	set screenheight [winfo screenheight $w]
	
	if {$bbox eq {}} {
	    if {$x + $width > $screenwidth} {
		set x [expr {$x - 10 - $width}]
	    }
	    if {$x < 0} { set x 0 }
	    if {$y + $height > $screenheight} {
		set y [expr {$y - 10 - $height}]
	    }
	    if {$y < 0} { set y 0 }
	} else {
	    #puts "SetPosition x=$x, y=$y, bbox=$bbox"
	    
	    # Deal with x and y independently.
	    if {$x < 0} {
		set x [expr {[lindex $bbox 2] + 4}]
	    } elseif {[expr {$x + $width}] > $screenwidth} {
		set x [expr {[lindex $bbox 0] - $width - 4}]
	    }
	    if {$y < 0} {
		set y [expr {[lindex $bbox 3] + 4}]
	    } elseif {[expr {$y + $height}] > $screenheight} {
		set y [expr {[lindex $bbox 1] - $height - 4}]
	    }
	    #puts "\t x=$x, y=$y"
	}
	wm geometry $w +${x}+${y}
	update idletasks
    }
}

proc ::balloonhelp::Free {win} {
    
    variable locals

    Cancel $win
    array unset locals ${win}*
}

proc ::balloonhelp::Debug {num str} {
    variable debug
    if {$num <= $debug} {
	puts $str
    }
}

#-------------------------------------------------------------------------------
