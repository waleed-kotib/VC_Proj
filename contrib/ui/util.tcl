# util.tcl --
# 
#       Various utility functions internal to ui*
# 
# Copyright (c) 2005 Mats Bengtsson
#  
# This file is distributed under BSD style license.
#       
# $Id: util.tcl,v 1.21 2008-02-20 15:14:37 matben Exp $

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

# max, min ---
#
#    Finds max and min of numerical values. From the WikiWiki page.

proc ui::max {args} {
    lindex [lsort -real $args] end
}

proc ui::min {args} {
    lindex [lsort -real $args] 0
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

# ui::findallwithclass --
# 
#       Find all widgets starting from . or given of a certain class.

proc ui::findallwithclass {class {parent .}} {    
    set widgets [list]
    set Q $parent
    while {[llength $Q]} {
	set QN [list]
	foreach w $Q {
	    if {[winfo class $w] eq $class} {
		lappend widgets $w
	    }
	    foreach child [winfo children $w] {
		lappend QN $child
	    }
	}
	set Q $QN
    }    
    return $widgets
}

# ui::findalltoplevelwithclass --
# 
#       Find all toplevel widgets starting from . or given of a certain class.

proc ui::findalltoplevelwithclass {class} {    
    set widgets [list]
    foreach w [winfo children .] {
	if {[winfo class $w] eq $class} {
	    lappend widgets $w
	}
    }
    return $widgets
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
	if {[llength [findalltoplevelwithclass $wclass]] != 1} {
	    set act 0
	}
    }
    if {$act} {
	upvar #0 $geoVar var
	
	# Signs of x and y included!
	if {[regexp $geoRE $var m wdth hght x - y -]} {
	    KeepOnScreen $win x y $wdth $hght
	    
	    # Protect from corruption.
	    set wdth [max $wdth 10]
	    set hght [max $hght 10]
	    
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

## Grab utilities. From tile. To be replaced with tiles when stable.
#
# Rules:
#	Each call to [grabWindow $w] or [globalGrab $w] must be
#	matched with a call to [releaseGrab $w] in LIFO order.
#
#	Do not call [grabWindow $w] for a window that currently
#	appears on the grab stack.
#
#	See #1239190 for more discussion.
#
namespace eval ui {
    variable Grab 		;# map: window name -> grab token

    # grab token details:
    #	Two-element list containing:
    #	1) a script to evaluate to restore the previous grab (if any);
    #	2) a script to evaluate to restore the focus (if any)
}

# SaveGrab --
#	Record current grab and focus windows.
#
proc ui::SaveGrab {w} {
    variable Grab

    set restoreGrab [set restoreFocus ""]

    set grabbed [grab current]
    if {$grabbed ne ""} {
	switch [grab status $grabbed] {
	    global { set restoreGrab [list grab -global $grabbed] }
	    local  { set restoreGrab [list grab $grabbed] }
	}
    }

    set focus [focus]
    if {$focus ne ""} {
	set restoreFocus [list focus -force $focus]
    }

    set Grab($w) [list $restoreGrab $restoreFocus]
}

# RestoreGrab --
#	Restore previous grab and focus windows.
#	If called more than once without an intervening [SaveGrab $w],
#	does nothing.
#
proc ui::RestoreGrab {w} {
    variable Grab

    if {![info exists Grab($w)]} {	# Ignore
	return;
    }

    # The previous grab/focus window may have been destroyed,
    # unmapped, or some other abnormal condition; ignore any errors.
    #
    foreach script $Grab($w) {
	catch $script
    }

    unset Grab($w)
}

# ui::grabWindow $w --
#	Records the current focus and grab windows, sets an application-modal 
#	grab on window $w.
#
proc ui::grabWindow {w} {
    SaveGrab $w
    grab $w
}

# ui::globalGrab $w --
#	Same as grabWindow, but sets a global grab on $w.
#
proc ui::globalGrab {w} {
    SaveGrab $w
    grab -global $w
}

# ui::releaseGrab --
#	Release the grab previously set by [ui::grabWindow] 
#	or [ui::globalGrab].
#
proc ui::releaseGrab {w} {
    grab release $w
    RestoreGrab $w
}

proc ui::Grab {win} {
    grabWindow $win
    tkwait window $win
    releaseGrab $win
}

proc ui::TabTo {win} {
    keynav::traverseTo $win
    return -code break
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
    } elseif {[info commands ::ttk::style] ne ""} {
	ttk::entry::See $win insert
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
	foreach {M N} [GetScaleMN $max $size] { break }
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
