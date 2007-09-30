# colorutils.tcl ---
#
#       Collection of various utility procedures to deal with colors.
#       Algorithm from Tcl/Tk: tkUnix3d.c
#       
#  Copyright (c) 2004  Mats Bengtsson
#  
#  This file is distributed under BSD style license.
#  
#  $Id: colorutils.tcl,v 1.6 2007-09-30 08:00:55 matben Exp $

package provide colorutils 1.0

namespace eval ::colorutils:: {

    variable maxintensity 65535
}


proc ::colorutils::getdarker {color} {
    variable maxintensity
    
    foreach {r g b} [winfo rgb . $color] break
    if {[expr {$r*0.5*$r + $g*1.0*$g + $b*0.28*$b}] < \
      [expr {$maxintensity*0.05*$maxintensity}]} {
	set darkred   [expr {(($maxintensity + 3*$r)/4) >> 8}]
	set darkgreen [expr {(($maxintensity + 3*$g)/4) >> 8}]
	set darkblue  [expr {(($maxintensity + 3*$b)/4) >> 8}]
    } else {
	set darkred   [expr {((60 * $r)/100) >> 8}]
	set darkgreen [expr {((60 * $g)/100) >> 8}]
	set darkblue  [expr {((60 * $b)/100) >> 8}]
    }
    return [format "#%02x%02x%02x" $darkred $darkgreen $darkblue]
}

proc ::colorutils::getlighter {color} {
    variable maxintensity
    
    foreach {r g b} [winfo rgb . $color] break
    if {$g > [expr {$maxintensity*0.95}]} {
	set lightred   [expr {((90 * $r)/100) >> 8}]
	set lightgreen [expr {((90 * $g)/100) >> 8}]
	set lightblue  [expr {((90 * $b)/100) >> 8}]
    } else {
	set tmp1 [expr {(14 * $r)/10}]
	if {$tmp1 > $maxintensity} {
	    set tmp1 $maxintensity
	}
	set tmp2 [expr {($maxintensity + $r)/2}]
	set lightred [expr {($tmp1 > $tmp2) ? $tmp1 : $tmp2}]
	set tmp1 [expr {(14 * $g)/10}]
	if {$tmp1 > $maxintensity} {
	    set tmp1 $maxintensity
	}
	set tmp2 [expr {($maxintensity + $g)/2}]
	set lightgreen [expr {($tmp1 > $tmp2) ? $tmp1 : $tmp2}]
	set tmp1 [expr {(14 * $b)/10}]
	if {$tmp1 > $maxintensity} {
	    set tmp1 $maxintensity
	}
	set tmp2 [expr {($maxintensity + $b)/2}]
	set lightblue [expr {($tmp1 > $tmp2) ? $tmp1 : $tmp2}]
	set lightred   [expr {$lightred >> 8}]
	set lightgreen [expr {$lightgreen >> 8}]
	set lightblue  [expr {$lightblue >> 8}]
    }
    
    return [format "#%02x%02x%02x" $lightred $lightgreen $lightblue]
}

#-------------------------------------------------------------------------------

