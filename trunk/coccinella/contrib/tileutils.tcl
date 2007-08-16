#  tileutils.tcl ---
#  
#      This file contains handy support code for the tile package.
#      
#  Copyright (c) 2005-2006  Mats Bengtsson
#  
#  This file is BSD style licensed.
#  
# $Id: tileutils.tcl,v 1.49 2007-08-16 13:29:00 matben Exp $
#

package provide tileutils 0.1


if {[tk windowingsystem] eq "aqua"} {
    interp alias {} ttk::scrollbar {} scrollbar
}

# Fixes by Eric Hassold from Evolane while waiting for tile 0.8...

proc ::ttk::deprecated'warning {old new} { } 

namespace eval ::tile {} 
if {![info exists ::tile::currentTheme]} { 
    if {[info exists ::ttk::currentTheme]} { 
	upvar \#0 ::ttk::currentTheme ::tile::currentTheme 
    } 
}

namespace eval ::tileutils {
    
    # See below for more init code.
    
    # Since menus are not yet themed we use this code to detect when a new theme
    # is selected, and recolors them. Non themed widgets only.

    if {[lsearch [bindtags .] ThemeChanged] < 0} {
	bindtags . [linsert [bindtags .] 1 ThemeChanged]
    }
    bind ThemeChanged <<ThemeChanged>> { tileutils::ThemeChanged }
    bind Listbox      <<ThemeChanged>> { tileutils::ListboxThemeChanged %W }
    bind Text         <<ThemeChanged>> { tileutils::TextThemeChanged %W }
    if {[tk windowingsystem] eq "x11"} {
	bind TreeCtrl <<ThemeChanged>> { tileutils::TreeCtrlThemeChanged %W }
    }
    if {[tk windowingsystem] ne "aqua"} {
	bind Menu      <<ThemeChanged>> { tileutils::MenuThemeChanged %W }
	bind WaveLabel <<ThemeChanged>> { tileutils::WaveLabelThemeChanged %W }
    }
}

proc tileutils::ThemeChanged {} {
    
    array set style [style configure .]
    array set map   [style map .]
    if {[info exists style(-background)]} {
	set color $style(-background)
	
	# Seems X11 has some system option db that must be overridden.
	if {[tk windowingsystem] eq "x11"} {
	    set priority 60
	} else {
	    set priority startupFile
	}
	# The highlightBackground needs a better solution.
	# text ._text; set textbg [._text cget -background]; destroy ._text
	option add *ChaseArrows.background        $color $priority
	option add *Listbox.highlightBackground   white  $priority
	option add *Menu.background               $color $priority
	option add *Text.highlightBackground      white  $priority
	option add *TreeCtrl.columnBackground     $color $priority
	option add *WaveLabel.columnBackground    $color $priority
	if {[info exists map(-background)]} {
	    foreach {state col} $map(-background) {
		if {[lsearch $state active] >= 0} {
		    option add *Menu.activeBackground $col $priority
		    break
		}
	    }
	}
    }
}

proc tileutils::ListboxThemeChanged {win} {
    
    array set style [style configure .]    
    if {[info exists style(-background)]} {
	if {[winfo class $win] eq "Listbox"} {
	    set color $style(-background)
	    $win configure -highlightbackground $color
	}
    }
}

proc tileutils::TextThemeChanged {win} {
    
    array set style [style configure .]    
    if {[info exists style(-background)]} {
	if {[winfo class $win] eq "Text"} {
	    set color $style(-background)
	    $win configure -highlightbackground $color
	}
    }
}

proc tileutils::MenuThemeChanged {win} {

    array set style [style configure .]    
    array set map   [style map .]
    if {[info exists style(-background)]} {
	if {[winfo class $win] eq "Menu"} {
	    set color $style(-background)
	    $win configure -bg $color
	    if {[info exists map(-background)]} {
		foreach {state col} $map(-background) {
		    if {[lsearch $state active] >= 0} {
			$win configure -activebackground $col
			break
		    }
		}
	    }
	}
    }
}

proc tileutils::WaveLabelThemeChanged {win} {

    array set style [style configure .]    
    if {[info exists style(-background)]} {
	if {[winfo class $win] eq "WaveLabel"} {
	    set color $style(-background)
	    $win configure -background $color
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
    
    # Joe English has said that it is not necessary to redefine the layout
    # and create elements in each theme but only in the "default" theme,
    # but that doesn't work for me.

    array set colors {
	invalidfg   "#ff0000"
	invalidbg   "#ffffb0"
    }
    
    style theme settings $name {
	
	# Set invalid state maps.
	style map TEntry  \
	  -fieldbackground [list invalid $colors(invalidbg)]  \
	  -foreground [list invalid $colors(invalidfg)]       \
	  -background [list invalid $colors(invalidbg)]
	style map TCombobox  \
	  -fieldbackground [list invalid $colors(invalidbg)]  \
	  -foreground [list invalid $colors(invalidfg)]       \
	  -background [list invalid $colors(invalidbg)]

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
	
	# @@@ These shall be removed when library/tile is updated!
	if {[package vcompare $::tile::version 0.7.3] >= 0} {
	    style configure TCheckbutton -padding {2}
	    style configure TRadiobutton -padding {2}
	}
	
	# My custom styles.
	# 
	# Sunken label:
	style layout Sunken.TLabel {
	    Sunken.background -sticky news -children {
		Sunken.padding -sticky news -children {
		    Sunken.label -sticky news
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
	
	# Sunken mini menubutton.
	style layout SunkenMenubutton {
	    Sunken.background -sticky news -children {
		Sunken.padding -sticky news -children {
		    Sunken.label -sticky news
		}
		SunkenMenubutton.indicator -sticky se
	    }
	}
	style element create SunkenMenubutton.indicator image $tiles(downArrowContrast) \
	  -sticky e -padding {0}
	style configure SunkenMenubutton -padding {0}

	# Search entry (from Michael Kirkham).
	set pad [style configure TEntry -padding]
	switch -- [llength $pad] {
	    0 { set pad [list 4 0 0 0] }
	    1 { set pad [list [expr {$pad+4}] $pad $pad $pad] }
	    2 {
		foreach {padx pady} $pad break
		set pad [list [expr {$padx+4}] $pady $padx $pady]
	    }
	    4 { lset pad 0 [expr {[lindex $pad 0]+4}] }
	}

	style element create searchEntryIcon image $tiles(search) \
	  -padding {8 0 0 0} -sticky {}

	style layout Search.TEntry {
	    Entry.field -children {
		searchEntryIcon -side left
		Entry.padding -children {
		    Entry.textarea
		}
	    }
	}
	style configure Search.TEntry -padding $pad
	style map Search.TEntry -image [list disabled $tiles(search)] \
	  -fieldbackground [list invalid $colors(invalidbg)]  \
	  -foreground [list invalid $colors(invalidfg)]       \
	  -background [list invalid $colors(invalidbg)]

	style configure Small.Search.TEntry -font CociSmallFont
	
	# Safari type button.
	unset -nocomplain foreground
	array set foreground [style map . -foreground]
	
	style element create Safari.background image $tiles(blank)  \
	  -border {6 6 6 6} -padding {0} -sticky news  \
	  -map [list  \
	  {background}                 $tiles(blank)  \
	  {active !disabled !pressed}  $tiles(oval)   \
	  {pressed !disabled}          $tiles(ovalDark)]
	
	style layout Safari {
	    Safari.background -children {
		Safari.padding -children {
		    Safari.label
		}
	    }
	}	    
	style configure Safari  \
	  -padding {6 0 6 1} -relief flat -font CociSmallFont
	unset -nocomplain foreground(active)
	unset -nocomplain foreground(selected)
	unset -nocomplain foreground(focus)
	set foreground([list active !disabled]) white
	style map Safari -foreground [array get foreground] -background {}
	
	# Safari type label.
	style element create LSafari.background image $tiles(oval)  \
	  -border {6 6 6 6} -padding {0} -sticky news
	style layout LSafari {
	    LSafari.background -children {
		LSafari.padding -children {
		    LSafari.label
		}
	    }
	}	    
	style configure LSafari  \
	  -padding {8 2 8 3} -relief flat -font CociSmallFont -foreground white	
	style map LSafari -foreground {background "#dedede"}
	
	# Aqua type plain arrow checkbutton.
	style element create arrowCheckIcon image $tiles(open) \
	  -sticky w -border {0} \
	  -map [list \
	 {!active !background  selected} $tiles(close)     \
	 { active !background !selected} $tiles(openDark)  \
	 { active !background  selected} $tiles(closeDark) \
	 {!active  background !selected} $tiles(openLight) \
	 {!active  background  selected} $tiles(closeLight)]
	style layout Arrow.TCheckbutton {
	    Arrow.border -sticky news -border 0 -children {
		Arrow.padding -sticky news -border 0 -children {
		    arrowCheckIcon -side left
		}
	    }
	}
	style configure Arrow.TCheckbutton  \
	  -padding {0} -borderwidth 0 -relief flat
	
	# Aqua type arrow checkbutton with text.
	style layout ArrowText.TCheckbutton {
	    ArrowText.border -sticky news -border 0 -children {
		ArrowText.padding -sticky news -border 0 -children {
		    arrowCheckIcon -side left
		    ArrowText.label -side left
		}
	    }
	}
	style configure ArrowText.TCheckbutton  \
	  -padding {0} -borderwidth 6 -relief flat
	style configure ArrowText.TCheckbutton -font CociSmallFont
	
	# Url clickable link:
	style layout Url {
	    Url.background -children {
		Url.padding -children {
		    Url.label
		}
	    }
	}	    
	array set mapA {
	    { active !background !disabled} red 
	    {!active !background !disabled} blue
	}
	if {[info exists foreground(background)]} {
	    set mapA(background) $foreground(background)
	}
	if {[info exists foreground(disabled)]} {
	    set mapA(disabled) $foreground(disabled)
	}
	style configure Url  \
	  -padding 2 -relief flat -font $fonts(underlineDefault) -foreground blue
	style map Url -foreground [array get mapA]
	style configure Small.Url -font $fonts(underlineSmall)
	
	# This is a toolbutton style menubutton with a small downarrow.
	style layout MiniMenubutton {
	    Toolbutton.border -sticky nswe -children {
		Toolbutton.padding -sticky nswe -children {
		    MiniMenubutton.indicator -side right
		    Toolbutton.label -sticky nswe
		}
	    }
	}
	style element create MiniMenubutton.indicator image $tiles(downArrow) \
	  -sticky e -padding {6 2}
	style configure MiniMenubutton -padding 6
	
	# Just a very basic button with image and/or text.
	style layout Plain {
	    Plain.border -sticky news -border 1 -children {
		Plain.padding -sticky news -border 1 -children {
		    Plain.label
		}
	    }
	}
	style configure Plain  \
	  -padding {0} -borderwidth 0 -relief flat

	style configure Small.Plain -font CociSmallFont

	
	# Test------------------
	if {0} {
	    # Plain border element.
	    style element create border from classic
	    style layout BorderFrame {
		BorderFrame.border -sticky nswe
	    }
	    style configure BorderFrame  \
	      -relief solid -borderwidth 1 -background gray50
	}
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
	    set ext [file extension $file]
	    
	    switch -- $ext {
		.gif - .png {
		    set format [string trimleft $ext "."]
		    set tiles($name) [image create photo -file $file \
		      -format $format]
		}
		default {
		    set tiles($name) [image create photo -file $file]
		}
	    }
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

set dir [file join [file dirname [info script]] tiles]
tileutils::LoadImages $dir {*.gif *.png}
tileutils::MakeFonts
    
foreach name [tile::availableThemes] {
    
    # @@@ We could be more economical here and load theme only when needed.
    if {[catch {package require tile::theme::$name}]} {
	continue
    }
    tileutils::configstyles $name    
}

# Tiles button bindings must be duplicated.
tile::CopyBindings TButton TUrl
bind TUrl <Enter>	   {+%W configure -cursor hand2 }
bind TUrl <Leave>	   {+%W configure -cursor arrow }

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

# ttk::optionmenuex --
# 
# As above but with values and labels separated as:
#       value label value label ...

proc ttk::optionmenuex {w varName args} {
    upvar #0 $varName var    

    variable $w
    upvar #0 $w state

    if {[expr [llength $args] % 2 == 1]} {
	return -code "args must have an even number of elements"
    }
    set state(varName) $varName
    if {![info exists var]} {
	set var [lindex $args 0]
    }
    ttk::menubutton $w -menu $w.menu -direction flush
    menu $w.menu -tearoff 0
    foreach {value lab} $args {
	set state(label,$value) $lab
	$w.menu add radiobutton -label $lab -value $value -variable $varName
    }
    set str [lindex $args 1]
    if {[info exists state(label,$var)]} {
	set str $state(label,$var)
    }
    $w configure -text $str
    trace add variable $varName write [list ttk::optionmenuexTrace $w]
    bind $w <Destroy> {+ttk::optionmenuexFree %W}
    return $w.menu
}

proc ttk::optionmenuexTrace {w varName index op} {
    upvar $varName var

    variable $w
    upvar #0 $w state
    
    if {$index eq ""} {
	set val $var
    } else {
	set val $var($index)
    }
    $w configure -text $state(label,$val)
}

proc ttk::optionmenuexFree {w} {
    variable $w
    upvar #0 $w state
    
    trace remove variable $state(varName) write [list ttk::optionmenuexTrace $w]
    unset -nocomplain state
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
    
    ttk::button $w.bp1 -style Plain -text "Plain Button" -command cmd
    
    ttk::entry $w.es -style Search.TEntry
    ttk::entry $w.ess -style Small.Search.TEntry -font CociSmallFont
    
    frame $w.f
    ttk::label $w.f.l -style Sunken.TLabel -compound image -image $name
    grid  $w.f.l  -sticky news
    grid columnconfigure $w.f 0 -minsize [expr {2*4 + 2*4 + 64}]
    grid rowconfigure    $w.f 0 -minsize [expr {2*4 + 2*4 + 64}]

    pack $w.l1 $w.l2 $w.l3 $w.l4 $w.l5 $w.e1 $w.e2 $w.b1 $w.b2  \
      $w.bp1 $w.es $w.ess $w.f \
      -padx 20 -pady 10
    
}

#-------------------------------------------------------------------------------
