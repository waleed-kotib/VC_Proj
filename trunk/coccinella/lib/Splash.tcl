#  Dialogs.tcl ---
#  
#       Handles the splash screen.
#      
#  Copyright (c) 1999-2005  Mats Bengtsson
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
# $Id: Splash.tcl,v 1.15 2007-10-04 14:01:07 matben Exp $
   
package provide Splash 1.0

namespace eval ::Splash:: {
    
    set text1 "Written by Mats Bengtsson (C) 1999-2006"
    set text2 "Distributed under the Gnu General Public License"
	
    # Use option database for customization.
    option add *Splash.image               splash           widgetDefault
    option add *Splash.showMinor           1                widgetDefault
    option add *Splash.showCopyright       0                widgetDefault
    option add *Splash.copyrightX          ""               widgetDefault
    option add *Splash.copyrightY          ""               widgetDefault
    option add *Splash.copyrightText1      $text1           widgetDefault
    option add *Splash.copyrightText2      $text2           widgetDefault

    # Name of variable for message displat.
    variable startMsg ""
    variable topwin ""
    variable splashCount 0
}

array set wDlgs {
    splash          .splash
}


# Splash::SplashScreen --
#
#       Shows the splash screen.
#       
# Arguments:
#       w      the toplevel window.
#       
# Results:
#       none

proc ::Splash::SplashScreen {} {
    global  this prefs wDlgs this
    variable topwin
    variable canwin
    variable startMsg
    
    
    set w $wDlgs(splash)
    set topwin $w
    if {[winfo exists $w]} {
	return
    }
    toplevel $w -class Splash
    if {[tk windowingsystem] eq "aqua"} {
	::tk::unsupported::MacWindowStyle style $w floating {closeBox}
    } else {
	wm transient $w
    }
    wm title $w [mc {About %s} $prefs(theAppName)]
    wm resizable $w 0 0
    set screenW [winfo vrootwidth .]
    set screenH [winfo vrootheight .]

    wm geometry $w +[expr ($screenW - 450)/2]+[expr ($screenH - 300)/2]
    set showMinor     [option get $w showMinor {}]
    set showCopyright [option get $w showCopyright {}]
    set copyrightX    [option get $w copyrightX {}]
    set copyrightY    [option get $w copyrightY {}]
    
    # If image not already there, get it.
    set imsplash [::Theme::GetImage [option get $w image {}]]
    set imHeight [image height $imsplash]
    set imWidth [image width $imsplash]
    if {$copyrightX eq ""} {
	set copyrightX 50
    }
    if {$copyrightY eq ""} {
	set copyrightY [expr $imHeight - 70]
    }
    foreach {r g b} [$imsplash get 50 [expr $imHeight - 20]] break
    if {[expr $r + $g + $b] > [expr 2*255]} {
	set textcol black
    } else {
	set textcol white
    }
    set canwin $w.can
    canvas $w.can -width $imWidth -height $imHeight -bd 0 -highlightthickness 0
    $w.can create image 0 0 -anchor nw -image $imsplash
    $w.can create text 50 [expr $imHeight - 20] -anchor nw -tags tsplash  \
      -font CociTinyFont -text $startMsg -fill $textcol
    
    # Print patch level for dev versions.
    if {$showMinor && ($this(vers,release) ne "")} {
	$w.can create text 418 [expr $imHeight - 42] -anchor nw  \
	  -font {Helvetica -18} -text ".$this(vers,release)" -fill #ef2910
    }
    if {$showCopyright} {
	set text1 [option get $w copyrightText1 {}]
	set text2 [option get $w copyrightText2 {}]
	$w.can create text $copyrightX $copyrightY -anchor nw \
	  -font CociSmallFont -text $text1 -fill $textcol
	$w.can create text $copyrightX [expr $copyrightY - 15] -anchor nw \
	  -font CociSmallFont -text $text2 -fill $textcol
    }
    
    pack $w.can
    bind $w <Return> [list destroy $w]
    bind $w <Button-1> [list destroy $w]
}

proc ::Splash::SetMsg {msg} {
    global this
    variable topwin
    variable canwin
    variable startMsg
    variable splashCount
    
    set startMsg $msg
    incr splashCount
    
    # Update needed to force display (bad?).
    if {[winfo exists $topwin]} {
	$canwin itemconfigure tsplash -text $startMsg
	if {[string equal $this(platform) "macosx"]} {
	    update
	} else {
	    update idletasks
	}
    }
}

#-------------------------------------------------------------------------------
