#  tileutils.tcl ---
#  
#      This file contains handy support code for the tile package.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: tileutils.tcl,v 1.7 2005-12-17 12:15:50 matben Exp $
#

package provide tileutils 0.1


if {[tk windowingsystem] eq "aqua"} {
    interp alias {} ttk::scrollbar {} scrollbar
}

namespace eval ::tileutils {
    # See below for init code.
}

proc tileutils::configstyles {name} {

    style theme settings $name {
	
	style layout Headlabel {
	    Headlabel.border -children {
		Headlabel.padding -children {
		    Headlabel.label -side left
		}
	    }
	}
	style configure Headlabel \
	  -font CociLargeFont -padding {20 6 20 6} -anchor w -space 12
	
	style layout Popupbutton {
	    Popupbutton.border -children {
		Popupbutton.padding -children {
		    Popupbutton.Combobox.downarrow
		}
	    }
	}
	style configure Popupbutton -padding 6
	
	style configure Small.TCheckbutton -font CociSmallFont
	style configure Small.TRadiobutton -font CociSmallFont
	style configure Small.TMenubutton  -font CociSmallFont
	style configure Small.TLabel       -font CociSmallFont
	style configure Small.TLabelframe  -font CociSmallFont
	style configure Small.TButton      -font CociSmallFont
	style configure Small.TEntry       -font CociSmallFont
	style configure Small.TNotebook    -font CociSmallFont
	style configure Small.TCombobox    -font CociSmallFont
	style configure Small.TScale       -font CociSmallFont
	style configure Small.Horizontal.TScale  -font CociSmallFont
	style configure Small.Vertical.TScale    -font CociSmallFont
	
	style configure Small.Toolbutton   -font CociSmallFont
	style configure Small.TNotebook.Tab  -font CociSmallFont
	style configure Small.Tab          -font CociSmallFont
	
	if {$name eq "clam"} {
	    style configure TButton           \
	      -width -9 -padding {5 3}
	    style configure TMenubutton       \
	      -width -9 -padding {5 3}
	    style configure Small.TButton     \
	      -font CociSmallFont             \
	      -padding {5 1}                  \
	      -width -9
	    style configure Small.TMenubutton \
	      -font CociSmallFont             \
	      -padding {5 1}                  \
	      -width -9
	}
	
	if {0 && $name eq "aqua"} {
	    set image [image create photo -file /Users/matben/Desktop/sunken.png]
	    
	    # This looks fine if placed in a gray background gray70 to gray80
	    style layout Sunken.TLabel {
		Sunken.background -children {
		    Sunken.padding -children {
			Sunken.label
		    }
		}
	    }	    
	    style element create Sunken.background image $image \
	      -border {4 4 4 4} -padding {6 3} -sticky news
	    style configure Sunken.TLabel -foregeound white
	    style map       Sunken.TLabel  \
	      -foreground {{background} "#dedede" {!background} white}
	    style configure Small.Sunken.TLabel -font CociSmallFont
	    
	    style layout Sunken.TEntry {
		Sunken.background -sticky news -children {
		    Entry.padding -sticky news -children {
			Entry.textarea -sticky news
		    }
		}
	    }
	    style map Sunken.TEntry  \
	      -foreground {{background} "#dedede" {!background} white}
	    style configure Small.Sunken.TEntry -font CociSmallFont

	}
    }    
}

if {0} {
    toplevel .t -bg gray78
    
    set f "/Users/matben/Graphics/Crystal Clear/16x16/apps/clock.png"
    set name [image create photo -file $f]
    ttk::label .t.l1 -style Sunken.TLabel  \
      -text "Mats Bengtsson" -image $name -compound right

    set f "/Users/matben/Graphics/Crystal Clear/16x16/apps/mac.png"
    set name [image create photo -file $f]
    ttk::label .t.l2 -style Small.Sunken.TLabel  \
      -text "I love my Macintosh" -image $name -compound left

    set f "/Users/matben/Graphics/Crystal Clear/16x16/apps/bell.png"
    set name [image create photo -file $f]
    ttk::label .t.l3 -style Sunken.TLabel  \
      -text "Mats Bengtsson" -image $name -compound right -font CociLargeFont
    
    ttk::label .t.l4 -style Sunken.TLabel  \
      -text "Plain no padding: glMXq"

    ttk::label .t.l5 -style Sunken.TLabel  \
      -text "With -padding {20 6}" -padding {20 6}
    
    ttk::entry .t.e1 -style Sunken.TEntry
    ttk::entry .t.e2 -style Small.Sunken.TEntry -font CociSmallFont

    pack .t.l1 .t.l2 .t.l3 .t.l4 .t.l5 .t.e1 .t.e2 -padx 20 -pady 10
}

	    
# These should be collected in a separate theme specific file.
    
foreach name [tile::availableThemes] {
    
    # @@@ We could be more economical here and load theme only when needed.
    if {[catch {package require tile::theme::$name}]} {
	continue
    }
    tileutils::configstyles $name
}

# Since menus are not yet themed we use this code to detect when a new theme
# is selected, and recolors them. X11 only.

if {[tk windowingsystem] eq "x11"} {
    bind Menu     <<ThemeChanged>> { tileutils::MenuThemeChanged %W }
    bind TreeCtrl <<ThemeChanged>> { tileutils::TreeCtrlThemeChanged %W }
}

proc tileutils::MenuThemeChanged {win} {

    array set style [style configure .]    
    if {[info exists style(-background)]} {
	if {[winfo class $win] eq "Menu"} {
	    set color $style(-background)
	    $win configure -bg $color
	    option add *Menu.background $color widgetDefault
	}
    }
}

proc tileutils::TreeCtrlThemeChanged {win} {
    
    array set style [style configure .]    
    if {[info exists style(-background)]} {
	if {[winfo class $win] eq "TreeCtrl"} {
	    set color $style(-background)
	    foreach C [$win column list -visible] {
		$win column configure $C -background $color
		option add *TreeCtrl.columnBackground $color widgetDefault
	    }
	}
    }
}

# ttk::optionmenu --
# 
# This procedure creates an option button named $w and an associated
# menu.  Together they provide the functionality of Motif option menus:
# they can be used to select one of many values, and the current value
# appears in the global variable varName, as well as in the text of
# the option menubutton.  The name of the menu is returned as the
# procedure's result, so that the caller can use it to change configuration
# options on the menu or otherwise manipulate it.
#
# Arguments:
# w -			The name to use for the menubutton.
# varName -		Global variable to hold the currently selected value.
# firstValue -		First of legal values for option (must be >= 1).
# args -		Any number of additional values.

proc ttk::optionmenu {w varName firstValue args} {
    upvar #0 $varName var
    
    if {![info exists var]} {
	set var $firstValue
    }
    ttk::menubutton $w -textvariable $varName -menu $w.menu -direction flush
    menu $w.menu -tearoff 0
    $w.menu add radiobutton -label $firstValue -variable $varName
    foreach i $args {
	$w.menu add radiobutton -label $i -variable $varName
    }
    return $w.menu
}

# @@@ Not yet working since methods are different.

proc tuoptionmenu {w varName firstValue args} {
    if {[tk windowingsystem] eq "win32"} {
	set values [concat [list $firstValue] $args]
	return [ttk::combobox $w -textvariable $varName -values $values \
	  -state readonly]
    } else {
	return [eval {ttk::optionmenu $w $varName $firstValue} $args]
    }
}

#-------------------------------------------------------------------------------
