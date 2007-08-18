# black.tcl - 
#
#   Experimental!
#
#  Copyright (c) 2007 Mats Bengtsson
#
# $Id: black.tcl,v 1.2 2007-08-18 14:10:59 matben Exp $

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
	  
	  style configure TNotebook.Tab \
	    -padding {6 2 6 2}
	  
	  
    }
    
    bind ThemeChanged <<ThemeChanged>> {+tile::theme::black::ThemeChanged }
    if {[tk windowingsystem] ne "aqua"} {
	bind Menu <<ThemeChanged>> {+tile::theme::black::MenuThemeChanged %W }
    }

    proc ThemeChanged {} {
	
	if {$tile::currentTheme ne "black"} {
	    return
	}
	array set style [style configure .]
	array set map   [style map .]
	
	# Seems X11 has some system option db that must be overridden.
	if {[tk windowingsystem] eq "x11"} {
	    set priority 60
	} else {
	    set priority startupFile
	}
	if {[info exists style(-foreground)]} {
	    set color $style(-foreground)
	    option add *Menu.foreground $color $priority
	    option add *Menu.activeForeground $color $priority
	}
    }

    proc MenuThemeChanged {win} {
	
	if {$tile::currentTheme ne "black"} {
	    return
	}
	array set style [style configure .]    
	if {[info exists style(-foreground)]} {
	    if {[winfo class $win] eq "Menu"} {
		set color $style(-foreground)
		$win configure -foreground $color
		$win configure -activeforeground $color
	    }
	}
    }
}

package provide tile::theme::black $::tile::theme::black::version
