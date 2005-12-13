#  tileutils.tcl ---
#  
#      This file contains handy support code for the tile package.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: tileutils.tcl,v 1.5 2005-12-13 13:57:52 matben Exp $
#

package provide tileutils 0.1


if {[tk windowingsystem] eq "aqua"} {
    interp alias {} ttk::scrollbar {} scrollbar
}

# These should be collected in a separate theme specific file.
    
foreach name [tile::availableThemes] {
    
    if {[catch {package require tile::theme::$name}]} {
	continue
    }
    
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
