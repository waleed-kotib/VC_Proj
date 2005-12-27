#  tileutils.tcl ---
#  
#      This file contains handy support code for the tile package.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: tileutils.tcl,v 1.11 2005-12-27 14:53:55 matben Exp $
#

package provide tileutils 0.1


if {[tk windowingsystem] eq "aqua"} {
    interp alias {} ttk::scrollbar {} scrollbar
}

namespace eval ::tileutils {
    
    # See below for more init code.
    
    # Since menus are not yet themed we use this code to detect when a new theme
    # is selected, and recolors them. Non themed widgets only.

    if {[lsearch [bindtags .] ThemeChanged] < 0} {
	bindtags . [linsert [bindtags .] 1 ThemeChanged]
    }
    bind ThemeChanged <<ThemeChanged>> { tileutils::ThemeChanged }
    if {[tk windowingsystem] eq "x11"} {
	bind TreeCtrl <<ThemeChanged>> { tileutils::TreeCtrlThemeChanged %W }
    }
    if {[tk windowingsystem] ne "aqua"} {
	bind Menu <<ThemeChanged>> { tileutils::MenuThemeChanged %W }
    }
}

proc tileutils::ThemeChanged {} {
    
    array set style [style configure .]    
    if {[info exists style(-background)]} {
	set color $style(-background)
	option add *Menu.background $color startupFile
	option add *TreeCtrl.columnBackground $color startupFile
    }
}

proc tileutils::MenuThemeChanged {win} {

    array set style [style configure .]    
    if {[info exists style(-background)]} {
	if {[winfo class $win] eq "Menu"} {
	    set color $style(-background)
	    $win configure -bg $color
	}
    }
}

proc tileutils::TreeCtrlThemeChanged {win} {
    
    array set style [style configure .]    
    if {[info exists style(-background)]} {
	if {[winfo class $win] eq "TreeCtrl"} {
	    treeutil::configurecolumns $win -background $style(-background)
	}
    }
}
   
# These should be collected in a separate theme specific file.

proc tileutils::configstyles {name} {
    variable tiles
    variable fonts

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
	
	# My custom styles.
	# 
	# Sunken label:
	style layout Sunken.TLabel {
	    Sunken.background -children {
		Sunken.padding -children {
		    Sunken.label
		}
	    }
	}	    
	style element create Sunken.background image $tiles(sunken) \
	  -border {4 4 4 4} -padding {6 3} -sticky news	    
	
	style configure Sunken.TLabel -foregeound white
	style map       Sunken.TLabel  \
	  -foreground {{background} "#dedede" {!background} white}
	style configure Small.Sunken.TLabel -font CociSmallFont
	
	# Sunken entry:
	style element create SunkenWhite.background image $tiles(sunkenWhite) \
	  -border {4 4 4 4} -padding {6 3} -sticky news	    
	
	style layout Sunken.TEntry {
	    SunkenWhite.background -sticky news -children {
		Entry.padding -sticky news -children {
		    Entry.textarea -sticky news
		}
	    }
	}
	style map Sunken.TEntry  \
	  -foreground {{background} "#363636" {} black}
	style configure Small.Sunken.TEntry -font CociSmallFont
	
	# Url clickable link:
	style layout Url {
	    Url.background -children {
		Url.padding -children {
		    Url.label
		}
	    }
	}	    
	style configure Url  \
	  -padding 2 -relief flat -font $fonts(underlineDefault) -foreground blue
	style map Url -foreground [list active red]
	style configure Small.Url -font $fonts(underlineSmall)
    }    
}

# tileutils::LoadImages --
# 
#       Create all images in a directory of the specified patterns.

proc tileutils::LoadImages {imgdir {patterns {*.gif}}} {
    variable tiles
    
    foreach file [eval {glob -nocomplain -directory $imgdir} $patterns] {
	set name [file tail [file rootname $file]]
	if {![info exists tiles($name)]} {
	    set tiles($name) [image create photo -file $file]
	}
    }
}

# tileutils::MakeFonts --
# 
#       Create fonts useful in certain styles from the named ones.

proc tileutils::MakeFonts {} {
    variable fonts
    
    # Underline default font.
    set underlineDefault [font create]
    array set opts [font configure CociDefaultFont]
    set opts(-underline) 1
    eval {font configure $underlineDefault} [array get opts]
    set fonts(underlineDefault) $underlineDefault

    # Underline small font.
    set underlineSmall [font create]
    array set opts [font configure CociSmallFont]
    set opts(-underline) 1
    eval {font configure $underlineSmall} [array get opts]
    set fonts(underlineSmall) $underlineSmall    
    
}

if {0} {
    toplevel .t
    set w .t.f
    if {1} {
	pack [ttk::frame .t.f] -expand 1 -fill both
    } else {
	pack [frame .t.f -bg gray80] -expand 1 -fill both
    }    
    set f "/Users/matben/Graphics/Crystal Clear/16x16/apps/clock.png"
    set name [image create photo -file $f]
    ttk::label $w.l1 -style Sunken.TLabel  \
      -text "Mats Bengtsson" -image $name -compound right

    set f "/Users/matben/Graphics/Crystal Clear/16x16/apps/mac.png"
    set name [image create photo -file $f]
    ttk::label $w.l2 -style Small.Sunken.TLabel  \
      -text "I love my Macintosh" -image $name -compound left

    set f "/Users/matben/Graphics/Crystal Clear/16x16/apps/bell.png"
    set name [image create photo -file $f]
    ttk::label $w.l3 -style Sunken.TLabel  \
      -text "Mats Bengtsson" -image $name -compound right -font CociLargeFont
    
    ttk::label $w.l4 -style Sunken.TLabel  \
      -text "Plain no padding: glMXq"

    ttk::label $w.l5 -style Sunken.TLabel  \
      -text "With -padding {20 6}" -padding {20 6}
    
    ttk::entry $w.e1 -style Sunken.TEntry
    ttk::entry $w.e2 -style Small.Sunken.TEntry -font CociSmallFont
    
    proc cmd {args} {puts xxxxxxxx}
    ttk::button $w.b1 -style Url -text www.home.se -command cmd
    ttk::button $w.b2 -style Small.Url -text www.smallhome.se -class TUrl \
      -command cmd
    
    frame $w.f
    ttk::label $w.f.l -style Sunken.TLabel -compound image -image $name
    grid  $w.f.l  -sticky news
    grid columnconfigure $w.f 0 -minsize [expr {2*4 + 2*4 + 64}]
    grid rowconfigure    $w.f 0 -minsize [expr {2*4 + 2*4 + 64}]

    pack $w.l1 $w.l2 $w.l3 $w.l4 $w.l5 $w.e1 $w.e2 $w.b1 $w.b2 $w.f \
      -padx 20 -pady 10
    
}

    
foreach name [tile::availableThemes] {
    
    set dir [file join [file dirname [info script]] tiles]
    tileutils::LoadImages $dir {*.gif *.png}
    tileutils::MakeFonts
    
    # @@@ We could be more economical here and load theme only when needed.
    if {[catch {package require tile::theme::$name}]} {
	continue
    }
    tileutils::configstyles $name
    
    # Tiles button bindings must be duplicated.
    tile::CopyBindings TButton TUrl
    bind TUrl <Enter>	   {+%W configure -cursor hand2 }
    bind TUrl <Leave>	   {+%W configure -cursor arrow }
    
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
