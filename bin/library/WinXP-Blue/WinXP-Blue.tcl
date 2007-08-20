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
# $Id: WinXP-Blue.tcl,v 1.1 2007-08-20 14:07:52 matben Exp $

package require Img

namespace eval tile::theme::winxpblue {

package provide tile::theme::winxpblue 0.5

set imgdir [file join [file dirname [info script]] WinXP-Blue gtk-2.0]
array set I [tile::LoadImages $imgdir *.png]

style theme create winxpblue -settings {

    style default "." -background #ece9d8 -font TkDefaultFont \
	-selectbackground "#4a6984" \
	-selectforeground "#ffffff" ;

    # gtkrc has #ece9d8 for background, notebook_active looks like #efebde

    style map "." -foreground {
	disabled	#565248
    } -background {
        disabled	#e3e1dd
	pressed		#bab5ab
	active		#c1d2ee
    }

    ## Buttons, checkbuttons, radiobuttons, menubuttons:
    #
    style layout TButton {
	Button.button -children { Button.focus -children { Button.label } }
    }
    style default TButton -padding 3 -width -11

    style element create Button.button \
    	image $I(buttonNorm) -border {4 9} -padding 3 -sticky nsew \
	-map [list pressed $I(buttonPressed) active $I(button)]
    style element create Checkbutton.indicator \
	image $I(checkbox_unchecked) -width 20 -sticky w \
	-map [list selected $I(checkbox_checked)] 
    style element create Radiobutton.indicator \
    	image $I(option_out) -width 20 -sticky w \
	-map [list selected $I(option_in)]
    style element create Menubutton.indicator image $I(menubar_option_arrow)

    ## Scrollbars, scale, progress bars:
    #
    style element create Horizontal.Scrollbar.thumb \
    	image $I(scroll_horizontal) -border 3 -width 15 -height 0 -sticky nsew
    style element create Vertical.Scrollbar.thumb \
    	image $I(scroll_vertical) -border 3 -width 0 -height 15 -sticky nsew
    style element create trough \
    	image $I(horizontal_trough) -sticky ew -border {0 2}
    style element create Vertical.Scrollbar.trough \
    	image $I(vertical_trough) -sticky ns -border {2 0}
    style element create Vertical.Scale.trough \
    	image $I(vertical_trough) -sticky ns -border {2 0}
    style element create Progress.bar image $I(progressbar)
    style element create Progress.trough image $I(through) -border 4

    ## Notebook parts:
    #
    style element create tab image $I(notebook_inactive) \
    	-map [list selected $I(notebook_active)] -border {2 2 2 1} -width 8
    style default TNotebook.Tab -padding {4 2}
    style default TNotebook -expandtab {2 1}

    ## Arrows:
    #
    style element create uparrow image $I(arrow_up_normal) -sticky {}
    style element create downarrow image $I(arrow_down_normal) -sticky {}
    style element create leftarrow image $I(arrow_left_normal) -sticky {}
    style element create rightarrow image $I(arrow_right_normal) -sticky {}
}
}

# -------------------------------------------------------------------------
