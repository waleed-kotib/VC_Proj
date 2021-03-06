# black.tcl - 
#
#   Experimental!
#
#  Copyright (c) 2007-2008 Mats Bengtsson
#
# $Id: black.tcl,v 1.13 2008-06-07 06:50:38 matben Exp $

package require Tk 8.5;                 # minimum version for Tile

namespace eval ttk {
    namespace eval theme {
        namespace eval black {
            variable version 0.0.1
        }
    }
}

namespace eval ttk::theme::black {
    
    #variable imgdir [file join [file dirname [info script]] black]
    #variable I
    #array set I [tile::LoadImages $imgdir *.png]

    variable dir [file dirname [info script]]
    
    # NB: These colors must be in sync with the ones in black.rdb
    variable colors
    array set colors {
	-disabledfg	"#999999"
	-frame  	"#424242"
	-dark		"#222222"
	-darker 	"#121212"
	-darkest	"black"
	-lighter	"#626262"
	-lightest 	"#ffffff"
	-selectbg	"#4a6984"
	-selectfg	"#ffffff"
    }
    
    ttk::style theme create black -parent clam -settings {

        # -----------------------------------------------------------------
        # Theme defaults
        #
	ttk::style configure "." \
	    -background $colors(-frame) \
	    -foreground white \
	    -bordercolor $colors(-darkest) \
	    -darkcolor $colors(-dark) \
	    -lightcolor $colors(-lighter) \
	    -troughcolor $colors(-darker) \
	    -selectbackground $colors(-selectbg) \
	    -selectforeground $colors(-selectfg) \
	    -selectborderwidth 0 \
	    -font TkDefaultFont \
	    ;

	  ttk::style map "." \
	      -background [list disabled $colors(-frame) \
			       active $colors(-lighter)] \
	      -foreground [list disabled $colors(-disabledfg)] \
	      -selectbackground [list  !focus $colors(-darkest)] \
	      -selectforeground [list  !focus white] \
	      ;
                
	  # ttk widgets.
	  ttk::style configure TButton \
	    -width -8 -padding {5 1} -relief raised
	  ttk::style configure TMenubutton \
	    -width -11 -padding {5 1} -relief raised
	  ttk::style configure TCheckbutton \
	    -indicatorbackground "#ffffff" -indicatormargin {1 1 4 1}
	  ttk::style configure TRadiobutton \
	    -indicatorbackground "#ffffff" -indicatormargin {1 1 4 1}
	  
	  ttk::style configure TEntry \
	    -fieldbackground white -foreground black \
	    -padding {2 0}
	  ttk::style configure TCombobox \
	    -fieldbackground white -foreground black \
	    -padding {2 0}
	  
	  ttk::style configure TNotebook.Tab \
	    -padding {6 2 6 2}
	  
	  # tk widgets.
	  ttk::style map Menu \
	    -background [list active $colors(-lighter)] \
	    -foreground [list disabled $colors(-disabledfg)]

	  ttk::style configure TreeCtrl \
	    -background gray30 -itembackground {gray60 gray50} \
	    -itemfill black -itemaccentfill darkblue
    }
}

# A few tricks for Tablelist.

namespace eval tablelist {}

proc tablelist::blackTheme {} {
    variable themeDefaults
    array set colors [array get ttk::theme::black::colors]
    array set themeDefaults [list \
	-background		white \
	-foreground		black \
	-disabledforeground	"#999999" \
	-stripebackground	"" \
	-selectbackground	$colors(-selectbg) \
	-selectforeground	$colors(-selectfg) \
	-selectborderwidth	0 \
	-font			TkTextFont \
	-labelbackground	$colors(-frame) \
	-labeldisabledBg	"#dcdad5" \
	-labelactiveBg		"#eeebe7" \
	-labelpressedBg		"#eeebe7" \
	-labelforeground	white \
	-labeldisabledFg	"#999999" \
	-labelactiveFg		white \
	-labelpressedFg		white \
	-labelfont		TkDefaultFont \
	-labelborderwidth	2 \
	-labelpady		1 \
	-arrowcolor		"" \
	-arrowstyle		sunken10x9 \
    ]
}

package provide ttk::theme::black $::ttk::theme::black::version
