# black.tcl - 
#
#   Experimental!
#
#  Copyright (c) 2007 Mats Bengtsson
#
# $Id: black.tcl,v 1.6 2007-08-27 15:15:25 matben Exp $

namespace eval tile {
    namespace eval theme {
        namespace eval black {
            variable version 0.0.1
        }
    }
}

namespace eval tile::theme::black {

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

    style theme create black -parent clam -settings {


        # -----------------------------------------------------------------
        # Theme defaults
        #
	style configure "." \
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

	  style map "." \
	      -background [list disabled $colors(-frame) \
			       active $colors(-lighter)] \
	      -foreground [list disabled $colors(-disabledfg)] \
	      -selectbackground [list  !focus $colors(-darkest)] \
	      -selectforeground [list  !focus white] \
	      ;
                
	  # ttk widgets.
	  style configure TButton \
	    -width -8 -padding {5 1} -relief raised
	  style configure TMenubutton \
	    -width -11 -padding {5 1} -relief raised
	  style configure TCheckbutton \
	    -indicatorbackground "#ffffff" -indicatormargin {1 1 4 1}
	  style configure TRadiobutton \
	    -indicatorbackground "#ffffff" -indicatormargin {1 1 4 1}
	  
	  style configure TEntry \
	    -fieldbackground white -foreground black \
	    -padding {2 0}
	  style configure TCombobox \
	    -fieldbackground white -foreground black \
	    -padding {2 0}
	  
	  style configure TNotebook.Tab \
	    -padding {6 2 6 2}
	  
	  # Standard tk widgets.
	  style map Menu \
	    -background [list active $colors(-lighter)] \
	    -foreground [list disabled $colors(-disabledfg)]

	  
    }
    
    # It could be important that we first read black.rdb and then invoke
    # the specific handlers.
    #bind ThemeChanged <<ThemeChanged>> {+tile::theme::black::ThemeChanged }

    proc ThemeChanged {} {
	variable dir
	
	if {$tile::currentTheme eq "black"} {

	    # Seems X11 has some system option db that must be overridden.
	    if {[tk windowingsystem] eq "x11"} {
		set priority 60
	    } else {
		set priority startupFile
	    }
	    option readfile [file join $dir black.rdb] $priority
	}
    }
}

package provide tile::theme::black $::tile::theme::black::version
