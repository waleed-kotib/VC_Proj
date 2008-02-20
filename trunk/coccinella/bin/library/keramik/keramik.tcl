# keramik.tcl - 
#
# A sample pixmap theme for the tile package.
#
#  Copyright (c) 2004 Googie
#  Copyright (c) 2004 Pat Thoyts <patthoyts@users.sourceforge.net>
#
# $Id: keramik.tcl,v 1.3 2008-02-20 15:14:37 matben Exp $

package require Tk 8.5;                 # minimum version for Tile

namespace eval ttk {
    namespace eval theme {
        namespace eval keramik {
            variable version 0.3.2
        }
    }
}

namespace eval ttk::theme::keramik {
    
    variable imgdir [file join [file dirname [info script]] keramik]
    variable I

    variable colors
    array set colors {
        -frame      "#cccccc"
        -lighter    "#cccccc"
        -window     "#ffffff"
        -selectbg   "#eeeeee"
        -selectfg   "#000000"
        -disabledfg "#aaaaaa"
    }
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

    array set I [LoadImages $imgdir *.gif]
    
    $styleCmd theme create keramik -parent alt -settings {


        # -----------------------------------------------------------------
        # Theme defaults
        #
        $styleCmd configure . \
            -borderwidth 1 \
            -background $colors(-frame) \
            -troughcolor $colors(-lighter) \
            -font TkDefaultFont \
            ;

        $styleCmd map . -foreground [list disabled $colors(-disabledfg)]
                
        # -----------------------------------------------------------------
        # Button elements
        #  - the button has a large rounded border and needs a bit of
        #    horizontal padding.
        #  - the checkbutton and radiobutton have the focus drawn around 
        #    the whole widget - hence the new layouts.
        #
        $styleCmd layout TButton {
            Button.background
            Button.button -children {
                Button.focus -children {
                    Button.label
                }
            }
        }
        $styleCmd layout Toolbutton {
            Toolbutton.background
            Toolbutton.button -children {
                Toolbutton.focus -children {
                    Toolbutton.label
                }
            }
        }
        $styleCmd element create button image \
	    [list $I(button-n) \
	              {pressed !disabled} $I(button-p) \
                      {active !selected}  $I(button-h) \
                      selected $I(button-s) \
                      disabled $I(button-d)] \
            -border {8 6 8 16} -padding {6 6} -sticky news
		      
        $styleCmd configure TButton -padding {10 6}

        $styleCmd element create Toolbutton.button image \
            [list $I(tbar-n) \
	              {pressed !disabled} $I(tbar-p) \
                      {active !selected}   $I(tbar-a) \
                      selected             $I(tbar-p)] \
            -border {2 8 2 16} -padding {2 2} -sticky news

        $styleCmd element create Checkbutton.indicator image \
            [list $I(check-u) selected $I(check-c)] \
            -width 20 -sticky w

        $styleCmd element create Radiobutton.indicator image \
            [list  $I(radio-u) selected $I(radio-c)] \
            -width 20 -sticky w

        # The layout for the menubutton is modified to have a button element
        # drawn on top of the background. This means we can have transparent
        # pixels in the button element. Also, the pixmap has a special
        # region on the right for the arrow. So we draw the indicator as a
        # sibling element to the button, and draw it after (ie on top of) the
        # button image.
        $styleCmd layout TMenubutton {
            Menubutton.background
            Menubutton.button -children {
                Menubutton.focus -children {
                    Menubutton.padding -children {
                        Menubutton.label -side left -expand true
                    }
                }
            }
            Menubutton.indicator -side right
        }
        $styleCmd element create Menubutton.button image \
            [list $I(mbut-n) {active !disabled} $I(mbut-a) \
                      {pressed !disabled} $I(mbut-a) \
                      {disabled}          $I(mbut-d)] \
            -border {7 10 29 15} -padding {7 4 29 4} -sticky news
        $styleCmd element create Menubutton.indicator image $I(mbut-arrow-n) \
            -width 11 -sticky w -padding {0 0 18 0}

        # -----------------------------------------------------------------
        # Scrollbars, scale and progress elements
        #  - the scrollbar has three arrow buttons, two at the bottom and
        #    one at the top.
        #
        $styleCmd layout Vertical.TScrollbar {
            Scrollbar.background 
            Scrollbar.trough -children {
                Scrollbar.uparrow -side top
                Scrollbar.downarrow -side bottom
                Scrollbar.uparrow -side bottom
                Vertical.Scrollbar.thumb -side top -expand true -sticky ns
            }
        }
        
        $styleCmd layout Horizontal.TScrollbar {
            Scrollbar.background 
            Scrollbar.trough -children {
                Scrollbar.leftarrow -side left
                Scrollbar.rightarrow -side right
                Scrollbar.leftarrow -side right
                Horizontal.Scrollbar.thumb -side left -expand true -sticky we
            }
        }

        $styleCmd configure TScrollbar -width 16

        $styleCmd element create Horizontal.Scrollbar.thumb image \
            [list $I(hsb-n) {pressed !disabled} $I(hsb-p)] \
            -border {6 4} -width 15 -height 16 -sticky news
        
        $styleCmd element create Vertical.Scrollbar.thumb image \
            [list $I(vsb-n) {pressed !disabled} $I(vsb-p)] \
            -border {4 6} -width 16 -height 15 -sticky news
        
        $styleCmd element create Scale.slider image $I(hslider-n) \
            -border 3
        
        $styleCmd element create Vertical.Scale.slider image $I(vslider-n) \
            -border 3
        
        $styleCmd element create Horizontal.Progress.bar image $I(hsb-n) \
            -border {6 4}
        
        $styleCmd element create Vertical.Progress.bar image $I(vsb-n) \
            -border {4 6}
        
        $styleCmd element create uparrow image \
            [list $I(arrowup-n) {pressed !disabled} $I(arrowup-p)]
                  
        $styleCmd element create downarrow image \
            [list $I(arrowdown-n) {pressed !disabled} $I(arrowdown-p)]

        $styleCmd element create rightarrow image \
            [list $I(arrowright-n) {pressed !disabled} $I(arrowright-p)]

        $styleCmd element create leftarrow image \
            [list $I(arrowleft-n) {pressed !disabled} $I(arrowleft-p)]
        
        # -----------------------------------------------------------------
        # Notebook elements
        #
        $styleCmd element create tab image \
            [list $I(tab-n) selected $I(tab-p) active $I(tab-p)] \
            -border {6 6 6 2} -height 12

	## Labelframes.
	#
	$styleCmd configure TLabelframe -borderwidth 2 -relief groove
    }
}

package provide ttk::theme::keramik $::ttk::theme::keramik::version
