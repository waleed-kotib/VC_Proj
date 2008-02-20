# WinXP-Blue - Copyright (C) 2004 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# Import the WinXP-Blue Gtk2 Theme by Ativo
# Link:
# URL: http://art.gnome.org/download/themes/gtk2/474/GTK2-WinXP-Blue.tar.gz
#
# You will need to fetch the theme package and extract it under the
# demos/themes directory and maybe modify the demos/themes/pkgIndex.tcl
# file.
#
# $Id: WinXP-Blue.tcl,v 1.4 2008-02-20 15:14:37 matben Exp $

package require Tk 8.5;                 # minimum version for Tile
package require tkpng 0.7

namespace eval ttk::theme::winxpblue {
    
    set imgdir [file join [file dirname [info script]] WinXP-Blue gtk-2.0]

    if {[info commands ::ttk::style] ne ""} {
	set styleCmd ttk::style
    } else {
	set styleCmd style
    }
    
    proc LoadImages {imgdir {patterns {*.gif}}} {
	foreach pattern $patterns {
	    foreach file [glob -directory $imgdir $pattern] {
		set img [file tail [file rootname $file]]
		if {![info exists images($img)]} {
		    set images($img) [image create photo -file $file]
		}
	    }
	}
	return [array get images]
    }

    array set I [LoadImages $imgdir *.png]
    
    $styleCmd theme create winxpblue -settings {
	
	$styleCmd configure "." -background "#ece9d8" -font TkDefaultFont \
	  -selectbackground "#4a6984" \
	  -selectforeground "#ffffff" ;
	
	# gtkrc has #ece9d8 for background, notebook_active looks like #efebde

	# Mats: changed -background  disabled
	$styleCmd map "." -foreground {
	    disabled	"#565248"
	} -background {
	    disabled    "#ece9d8"
	    pressed	"#bab5ab"
	    active	"#c1d2ee"
	}
	
	## Buttons, checkbuttons, radiobuttons, menubuttons:
	 #
	$styleCmd layout TButton {
	    Button.button -children { Button.focus -children { Button.label } }
	}
	$styleCmd configure TButton -padding 3 -width -11
	
	$styleCmd element create Button.button image \
	  [list $I(buttonNorm) pressed $I(buttonPressed) active $I(button)] \
	  -border {4 9} -padding 3 -sticky nsew
	$styleCmd element create Checkbutton.indicator image \
	  [list $I(checkbox_unchecked) selected $I(checkbox_checked)] \
	  -width 20 -sticky w
	$styleCmd element create Radiobutton.indicator image \
	  [list $I(option_out) selected $I(option_in)] \
	  -width 20 -sticky w
	$styleCmd element create Menubutton.indicator image $I(menubar_option_arrow)
	
	## Scrollbars, scale, progress bars:
	 #
	$styleCmd element create Horizontal.Scrollbar.thumb \
	  image $I(scroll_horizontal) -border 3 -width 15 -height 0 -sticky nsew
	$styleCmd element create Vertical.Scrollbar.thumb \
	  image $I(scroll_vertical) -border 3 -width 0 -height 15 -sticky nsew
	$styleCmd element create trough \
	  image $I(horizontal_trough) -sticky ew -border {0 2}
	$styleCmd element create Vertical.Scrollbar.trough \
	  image $I(vertical_trough) -sticky ns -border {2 0}
	$styleCmd element create Vertical.Scale.trough \
	  image $I(vertical_trough) -sticky ns -border {2 0}
	$styleCmd element create Progress.bar image $I(progressbar)
	$styleCmd element create Progress.trough image $I(through) -border 4
	
	## Notebook parts:
	 #
	$styleCmd element create tab image \
	  [list $I(notebook_inactive) selected $I(notebook_active)] \
	  -border {2 2 2 1} -width 8
	$styleCmd configure TNotebook.Tab -padding {4 2}
	$styleCmd configure TNotebook -expandtab {2 1}
	
	## Arrows:
	 #
	$styleCmd element create uparrow image $I(arrow_up_normal) -sticky {}
	$styleCmd element create downarrow image $I(arrow_down_normal) -sticky {}
	$styleCmd element create leftarrow image $I(arrow_left_normal) -sticky {}
	$styleCmd element create rightarrow image $I(arrow_right_normal) -sticky {}
    }
}

package provide ttk::theme::winxpblue 0.5

# -------------------------------------------------------------------------
