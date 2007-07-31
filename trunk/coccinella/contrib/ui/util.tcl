# util.tcl --
# 
#       Various utility functions internal to ui*
# 
# Copyright (c) 2005 Mats Bengtsson
#  
# This file is distributed under BSD style license.
#       
# $Id: util.tcl,v 1.12 2007-07-31 07:28:32 matben Exp $

# TODO:
#   new: wizard, ttoolbar, mnotebook?
#   q:   toplevel, canvasex, -menu on mac


package require snit 1.0

package provide ui::util 0.1

namespace eval ui {

    variable geoRE {([0-9]+)x([0-9]+)\+?((\+|-)[0-9]+)((\+|-)[0-9]+)}    
    variable dlg ._ui_dlg
    
    catch {font create DlgDefaultFont}
    catch {font create DlgBoldFont}
    catch {font create DlgSmallFont}
    
    switch -- [tk windowingsystem] {
	aqua {
	    set family "Lucida Grande"
	    set size 13
	    set small 11

	    font configure DlgDefaultFont -family $family -size $size
	    font configure DlgBoldFont    -family $family -size $size -weight bold
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
	    font configure DlgBoldFont    -family $family -size $size -weight bold
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

	    font configure DlgDefaultFont -family $family -size $size
	    font configure DlgBoldFont    -family $family -size $size -weight bold
	    font configure DlgSmallFont   -family $family -size $small
	}
    }    
}

# ui::from --
# 
#       The from command plucks an option value from a list of options and their 
#       values. If it is found, it and its value are removed from the list, 
#       and the value is returned. 

proc ui::from {argvName option {defvalue ""}} {
    upvar $argvName argv

    set ioption [lsearch -exact $argv $option]
    if {$ioption == -1} {
	return $defvalue
    } else {
	set ivalue [expr {$ioption + 1}]
	set value [lindex $argv $ivalue]
	set argv [lreplace $argv $ioption $ivalue] 
	return $value
    }
}

# ui::autoname --
# 
#       Generates an unique nonexisting toplevel window name.

proc ui::autoname {} {
    variable dlg
    set max 0x0FFFFFFF
    set w $dlg[format %08x [expr {int($max*rand())}]]
    while {[winfo exists $w]} {
	set w $dlg[format %08x [expr {int($max*rand())}]]
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
    tkwait window $win
}

proc ui::GrabAndWait {win} {
    grab $win
    MenubarDisable $win
    tkwait window $win
    MenubarNormal $win
}

proc ui::MenubarDisable {win} {

    # Accelerators must be handled from OnMenu* commands.
    # @@@ Must allow cut/copy/paste from edit menu.
    set mbar [$win cget -menu]
    if {$mbar ne ""} {
	set iend [$mbar index end]
	for {set idx 0} {$idx <= $iend} {incr idx} {
	    $mbar entryconfigure $idx -state disabled
	}
    }
}

proc ui::MenubarNormal {win} {
    set mbar [$win cget -menu]
    if {$mbar ne ""} {
	set iend [$mbar index end]
	for {set ind 0} {$ind <= $iend} {incr ind} {
	    $mbar entryconfigure $ind -state normal
	}    
    }
}

# ui::EntryInsert --
# 
#       Private method to ui::entryex and ui::comboboxex. 
#       Needed since 'break' is not propagated internally in snit!

proc ui::EntryInsert {win s} {
    if {![string length $s]} {
	return
    }
    catch {$win delete sel.first sel.last}
    set str [$win get]
    set insert [expr {[$win index insert] + 1}]
    set white [string range $str 0 $insert]
    append white $s
    $win insert insert $s
    
    set library [$win cget -library]
    set type    [$win cget -type]
    
    # Find matches in 'library'. Protect glob characters.
    set white [string map {* \\* ? \\? [ \\[ ] \\] \\ \\\\} $white]
    set mlist [lsearch -glob -inline -all $library ${white}*]
    if {[llength $mlist]} {
	set mstr [lindex $mlist 0]
	$win delete 0 end
	$win insert insert $mstr
	$win selection range $insert end
	$win icursor $insert
    } else {
	#$win delete $insert end
    }    
    if {$type eq "tk"} {
	::tk::EntrySeeInsert $win
    } else {
	tile::entry::See $win insert
    }
    
    # Stop class handler from executing, else we get double characters.
    # @@@ Problem: this also stops handlers bound to the toplevel bindtag!!!!!
    return -code break
}

# ::ui::image::scale --
# 
#       Always scales down an image.
#
#       Scales a photo using tk's primitive methods while waiting for tkpath!
#       Note that always a new image is produced for each call!
#       If image with 'name' is smaller or equal 'size' then just return 
#       a copy of 'name', else create a new scaled one that is smaller or 
#       equal to 'size'.

namespace eval ::ui::image {}

proc ::ui::image::scale {name size} {
    
    set width  [image width $name]
    set height [image height $name]
    set max [expr {$width > $height ? $width : $height}]
    
    # We never scale up an image, only scale down.
    if {$size >= $max} {
	set new [image create photo]
	$new copy $name
	return $new
    } else {
	lassign [GetScaleMN $max $size] M N
	return [ScalePhotoM->N $name $M $N]
    }
}

proc ::ui::image::ScalePhotoM->N {name M N} {
    
    set new [image create photo]
    if {$N == 1} {
	$new copy $name -subsample $M
    } else {
	set tmp [image create photo]
	$tmp copy $name -zoom $M
	$new copy $tmp -subsample $N
	image delete $tmp
    }
    return $new
}

# ui::image::GetScaleMN --
# 
#       Get scale rational number that scales from 'from' pixels to smaller or 
#       equal to 'to' pixels.

proc ::ui::image::GetScaleMN {from to} {
    variable scaleTable

    if {![info exists scaleTable]} {
	MakeScaleTable
    }
    
    # If requires smaller scale factor than min (1/8):
    set M [lindex $scaleTable {end 0}]
    set N [lindex $scaleTable {end 1}]
    if {[expr {$M*$from > $N*$to}]} {
	set M 1
	set N [expr {int(double($from)/double($to) + 1)}]
    } elseif {$from == $to} {
	set M 1
	set N 1
    } else {
	foreach r $scaleTable {
	    set N [lindex $r 0]
	    set M [lindex $r 1]
	    if {[expr {$N*$from <= $M*$to}]} {
		break
	    }
	}
    }
    return [list $N $M]
}

proc ::ui::image::MakeScaleTable { } {
    variable scaleTable
    
    # {{numerator denominator} ...}
    set r \
      {{1 2} {1 3} {1 4} {1 5} {1 6} {1 7} {1 8}
	     {2 3}       {2 5}       {2 7}
		   {3 4} {3 5}       {3 7} {3 8}
			 {4 5}       {4 7}  
			       {5 6} {5 7} {5 8}
				     {6 7}
					   {7 8}}

    # Sort in decreasing order!
    set scaleTable [lsort -decreasing -command ::ui::image::MakeScaleTableCmd $r]
}

proc ::ui::image::MakeScaleTableCmd {f1 f2} {
    
    set r1 [expr {double([lindex $f1 0])/double([lindex $f1 1])}]
    set r2 [expr {double([lindex $f2 0])/double([lindex $f2 1])}]
    return [expr {$r1 > $r2 ? 1 : -1}]
}

#-------------------------------------------------------------------------------
