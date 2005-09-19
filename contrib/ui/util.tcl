# util.tcl --
# 
#       Various utility functions internal to ui*
# 
# Copyright (c) 2005 Mats Bengtsson
#       
# $Id: util.tcl,v 1.1 2005-09-19 06:37:20 matben Exp $

# TODO:
#   new: wizard, ttoolbar, mnotebook?
#   q:   toplevel, canvasex, -menu on mac


package require snit 1.0

package provide ui::util 0.1

namespace eval ui {

    variable geoRE {([0-9]+)x([0-9]+)\+?((\+|-)[0-9]+)((\+|-)[0-9]+)}    
    variable dlg ._ui_dlg
    
    catch {font create DlgDefaultFont}
    catch {font create DlgSmallFont}
    
    switch -- [tk windowingsystem] {
	aqua {
	    set family "Lucida Grande"
	    set size 13
	    set small 11

	    font configure DlgDefaultFont -family $family -size $size
	    font configure DlgSmallFont   -family $family -size $small
	}
	win32 {
	    if {$::tcl_platform(osVersion) >= 5.0} {
		variable family "Tahoma"
	    } else {
		variable family "MS Sans Serif"
	    }
	    set size 8
	    set small 8

	    font configure DlgDefaultFont -family $family -size $size
	    font configure DlgSmallFont   -family $family -size $small
	}
	x11 {
	    if {![catch {tk::pkgconfig get fontsystem} fs] && $fs eq "xft"} {
		variable family "sans-serif"
	    } else {
		variable family "Helvetica"
	    }
	    set size -12
	    set small -10
	}
    }    

}

proc ui::autoname {} {
    variable dlg
    set w $dlg[expr {int(1000000*rand())}]
    while {[winfo exists $w]} {
	set w $dlg[expr {int(1000000*rand())}]
    }
    return $w
}

# ui::PositionClassWindow --
# 
#       Sets windows position from its class and variable with geometry.

proc ui::PositionClassWindow {win geoVar wclass} {    
    SetGeometryEx $win $geoVar $wclass "pos"
}

proc ui::SizeClassWindow {win geoVar wclass} {    
    SetGeometryEx $win $geoVar $wclass "size"
}

proc ui::SetClassGeometry {win geoVar wclass} {
    SetGeometryEx $win $geoVar $wclass "geo"
}

proc ui::PositionWindow {win geoVar} {    
    SetGeometryEx $win $geoVar "" "pos"
}

proc ui::SizeWindow {win geoVar} {    
    SetGeometryEx $win $geoVar "" "size"
}

proc ui::SetGeometry {win geoVar} {
    SetGeometryEx $win $geoVar "" "geo"
}

proc ui::SetGeometryEx {win geoVar wclass {part "geo"}} {
    variable geoRE

    # Create variable if not exists.
    if {![uplevel #0 [list info exists $geoVar]]} {
	uplevel #0 [list set $geoVar ""]
    }
    
    # Only first window of this class is positioned if wclass.
    set act 1
    if {[string length $wclass]} {
	if {[llength [GetToplevels $wclass]] != 1} {
	    set act 0
	}
    }
    if {$act} {
	upvar #0 $geoVar var
	
	# Signs of x and y included!
	if {[regexp $geoRE $var m wdth hght x - y -]} {
	    KeepOnScreen $win x y $wdth $hght
	    if {($x > 0) && [string index $x 0] ne "+"} {
		set x +$x
	    }
	    if {($y > 0) && [string index $y 0] ne "+"} {
		set y +$y
	    } 
	    switch -- $part {
		pos {
		    set geo ${x}${y}
		}
		size {
		    set geo ${wdth}x${hght}
		}
		geo {
		    set geo ${wdth}x${hght}${x}${y}
		}
	    }
	    wm geometry $win $geo
	}
    }
}

proc ui::KeepOnScreen {win xVar yVar width height} {
    upvar $xVar x
    upvar $yVar y
    
    set margin    20
    set topmargin 0
    set botmargin 40
    if {[tk windowingsystem] eq "aqua"} {
	set topmargin 20
    }
    set screenW [winfo vrootwidth $win]
    set screenH [winfo vrootheight $win]
    set x2 [expr {$x + $width}]
    set y2 [expr {$y + $height}]
    if {$x < 0} {
	set x $margin
    }
    if {$x > [expr {$screenW - $margin}]} {
	set x [expr {$screenW - $width - $margin}]
    }
    if {$y < $topmargin} {
	set y $topmargin
    }
    if {$y > [expr {$screenH - $botmargin}]} {
	set y [expr {$screenH - $height - $botmargin}]
    }
}

proc ui::SaveGeometry {win geoVar} {
    uplevel #0 [list set $geoVar [wm geometry $win]]
}

proc ui::GetPaddingWidth {padding} {
    
    switch -- [llength $padding] {
	1 {
	    return [expr {2*$padding}]
	}
	2 {
	    return [expr {2*[lindex $padding 0]}]
	}
	4 {
	    return [expr {[lindex $padding 0] + [lindex $padding 2]}]
	}
    }
}

proc ui::GetPaddingHeight {padding} {
    
    switch -- [llength $padding] {
	1 {
	    return [expr {2*$padding}]
	}
	2 {
	    return [expr {2*[lindex $padding 1]}]
	}
	4 {
	    return [expr {[lindex $padding 1] + [lindex $padding 3]}]
	}
    }
}


proc ui::GetToplevels {wclass} {
    set wtops {}
    foreach w [winfo children .] {
	if {[winfo class $w] eq "$wclass"} {
	    lappend wtops $w
	}
    }
    return $wtops
}

proc ui::Grab {win} {
    grab $win
    set idxlist [MenubarDisable $win]
    set mb [$win cget -menu]
    tkwait window $win
    MenubarNormal $mb $idxlist
}

proc ui::MenubarDisable {win} {

    # @@@ This doesn't handle accelerators!
    set idxlist {}
    if {[tk windowingsystem] eq "aqua"} {
	set mb [$win cget -menu]
	if {$mb != ""} {
	    set iend [$mbar index end]
	    for {set idx 0} {$idx <= $iend} {incr idx} {
		if {[$mb entrycget $idx -state] eq "normal"} {
		    $mb entryconfigure $idx -state disabled
		    lappend idxlist $idx
		}
	    }
	}
    }
    return $idxlist
}

proc ui::MenubarNormal {mb idxlist} {
    if {[tk windowingsystem] eq "aqua"} {
	if {$mb != ""} {
	    foreach idx $idxlist {
		$mb entryconfigure $idx -state normal
	    }
	}	
    }
}

#-------------------------------------------------------------------------------
