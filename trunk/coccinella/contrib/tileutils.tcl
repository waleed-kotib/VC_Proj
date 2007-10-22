#  tileutils.tcl ---
#  
#      This file contains handy support code for the tile package.
#      
#  Copyright (c) 2005-2007  Mats Bengtsson
#  
#  This file is BSD style licensed.
#  
# $Id: tileutils.tcl,v 1.73 2007-10-22 11:51:33 matben Exp $
#

package require treeutil

package provide tileutils 0.1

namespace eval ::tileutils {}

if {[tk windowingsystem] eq "aqua"} {
    interp alias {} ttk::scrollbar {} scrollbar
}

# Fixes by Eric Hassold from Evolane while waiting for tile 0.8...

proc ::ttk::deprecated'warning {old new} { } 

set ::tileutils::ns tile::theme

namespace eval ::tile {} 
if {![info exists ::tile::currentTheme]} { 
    if {[info exists ::ttk::currentTheme]} { 
	upvar \#0 ::ttk::currentTheme ::tile::currentTheme 
	set ::tileutils::ns ttk::theme
    } 
}


namespace eval tile {
    
    foreach name [tile::availableThemes] {
	
	# @@@ We could be more economical here and load theme only when needed.
	if {[catch {package require ${::tileutils::ns}::$name}]} {
	    continue
	}

	# Set only the switches that are not in [style configure .]
	# or [style map .].
	
	if {[tk windowingsystem] eq "aqua"} {
	    set highlightThickness 3
	    set showLines 0
	} else {
	    set highlightThickness 2
	    set showLines 1
	}
	
	style theme settings $name {

	    style configure . -highlightthickness $highlightThickness

	    # Avoid overwrite non-standard themes. Trick!
	    eval {
		style configure Listbox -background white
	    } [style configure Listbox]
	    eval {
		style configure Text -background white
	    } [style configure Text]
	    eval {
		style configure TreeCtrl \
		  -background white -itembackground {gray90 {}} \
		  -showlines $showLines -usetheme 0
	    } [style configure TreeCtrl]
	    
	    switch $name {
		alt {
		    array set colors [array get ${::tileutils::ns}::alt::colors]
		    style configure TreeCtrl \
		      -background gray75 -itembackground {gray92 gray84}
		}
		aqua {
		    style configure TreeCtrl \
		      -itembackground {"#dedeff" {}} -usetheme 1
		}
		clam {
		    array set colors [array get ${::tileutils::ns}::clam::colors]
		    style configure TreeCtrl \
		      -background gray75 -itembackground {gray92 gray84}
		}
		classic {
		    array set colors [array get ${::tileutils::ns}::classic::colors]
		    style configure TreeCtrl \
		      -background gray75 -itembackground {gray92 gray84}
		}
		default {
		    array set colors [array get ${::tileutils::ns}::default::colors]
		}
		keramik {
		    array set colors [array get ${::tileutils::ns}::keramik::colors]
		    style configure TreeCtrl \
		      -background gray75 -itembackground {gray92 gray84}
		}
		step {
		    array set colors [array get ${::tileutils::ns}::step::colors]
		    style configure TreeCtrl \
		      -background gray75 -itembackground {gray92 gray84}
		}
		winnative {
		    style map Menu \
		      -background {active SystemHighlight} \
		      -foreground {active SystemHighlightText disabled SystemGrayText}
		    style configure TreeCtrl \
		      -itembackground {"#dedeff" {}}
		}
		winxpblue {
		    style configure TreeCtrl \
		      -background white -itembackground {gray92 gray84}
		}
		xpnative {
		    style map Menu \
		      -background {active SystemHighlight} \
		      -foreground {active SystemHighlightText disabled SystemGrayText}
		    style configure TreeCtrl \
		      -itembackground {"#dedeff" {}}
		}
	    }
	}
    }
}

namespace eval ::tileutils {
    
    # Much of these comments are OUTDATED!!!
    
    # NB: We must have the standard <<ThemeChanged>> handlers first since
    #     other themes may want to set their own options and these must
    #     therfore come after the standard handlers.

    # NB: Order if ThemeChanged handlers important:
    # 
    # .    tileutils::ThemeChanged      <- read all rdb files for standard tile themes
    # .    theme specific handler       <- read theme specific rdb file
    # Menu tileutils::MenuThemeChanged  <- configure using resources
    # 
    # Menu can be any non ttk widget, typically TreeCtrl.
    # 
    # There are two things that need to be set for each class of widget:
    #   1) existing widgets need to be configured
    #   2) the resources must be set for new widgets
    
    # @@@ Could used a new bind tag instead?
    proc BindFirst {tag event cmd} {
	set script [bind $tag $event]
	bind $tag $event "$cmd\n$script"
    }
    
    # See below for more init code.
    
    # Since menus are not yet themed we use this code to detect when a new theme
    # is selected, and recolors them. Non themed widgets only.

    if {[lsearch [bindtags .] ThemeChanged] < 0} {
	bindtags . [linsert [bindtags .] 1 ThemeChanged]
    }
    BindFirst ThemeChanged <<ThemeChanged>> {tileutils::ThemeChanged }
    BindFirst ChaseArrows  <<ThemeChanged>> {tileutils::ChaseArrowsThemeChanged %W }
    BindFirst Listbox      <<ThemeChanged>> {tileutils::ListboxThemeChanged %W }
    BindFirst Spinbox      <<ThemeChanged>> {tileutils::SpinboxThemeChanged %W }
    BindFirst Text         <<ThemeChanged>> {tileutils::TextThemeChanged %W }
    BindFirst TreeCtrl     <<ThemeChanged>> {tileutils::TreeCtrlThemeChanged %W }
    if {[tk windowingsystem] ne "aqua"} {
	BindFirst Menu      <<ThemeChanged>> {tileutils::MenuThemeChanged %W }
	BindFirst WaveLabel <<ThemeChanged>> {tileutils::WaveLabelThemeChanged %W }
    }
    
    variable options
    array set options {
	-themechanged ""
    }
}

proc tileutils::configure {args} {
    variable options
    
    if {$args eq {}} {
	return [array get options]
    } else {
	array set options $args
    }
}

proc tileutils::ThemeChanged {} {
    variable options
    
    # Give interested parties a chance to read a new option database file etc.
    if {$options(-themechanged) ne {}} {
	uplevel #0 $options(-themechanged)
    }

    # @@@ I could think of an alternative here:
    # style theme settings default {
    #    array set style [style configure .]
    #    array set map   [style map .]
    # }
    # etc. and then cache all in style(name) and map(name).

    array set style [list -foreground black]
    array set style [style configure .]
    array set map   [style map .]
    
    # Override any class specific settings for some widgets.
    array set textStyle [array get style]
    array set textStyle [style configure Text]
    array set lbStyle [array get style]
    array set lbStyle [style configure Listbox]
    array set treeStyle [array get style]
    array set treeStyle [style configure TreeCtrl]

    array set menuMap [style map .]
    array set menuMap [style map Menu]

    # We configure the resource database here as well since it saves code.
    # Seems X11 has some system option db that must be overridden.
    if {[tk windowingsystem] eq "x11"} {
	set priority 60
    } else {
	set priority startupFile
    }
    
    if {[info exists style(-background)]} {
	set color $style(-background)
	option add *ChaseArrows.background      $color $priority
	option add *Entry.highlightBackground   $color $priority
	option add *Listbox.background          $lbStyle(-background) $priority
	option add *Listbox.highlightBackground $color $priority
	option add *Menu.background             $color $priority
	option add *Menu.activeBackground       $color $priority
	option add *Spinbox.buttonBackground    $color $priority
	option add *Spinbox.highlightBackground $color $priority
	#option add *Text.highlightBackground    $textStyle(-background) $priority
	option add *Text.highlightBackground    $color $priority
	option add *TreeCtrl.columnBackground   $color $priority
	option add *WaveLabel.columnBackground  $color $priority
	
	if {[info exists menuMap(-background)]} {
	    foreach {state col} $menuMap(-background) {
		if {[lsearch $state active] >= 0} {
		    option add *Menu.activeBackground $col $priority
		    break
		}
	    }
	}
    }
    if {[info exists style(-foreground)]} {
	set color $style(-foreground)
	option add *Menu.foreground             $color $priority
	option add *Menu.activeForeground       $color $priority
	option add *Menu.disabledForeground     $color $priority
	option add *TreeCtrl.textColor          $color $priority

	if {[info exists menuMap(-foreground)]} {
	    foreach {state col} $menuMap(-foreground) {
		if {[lsearch $state active] >= 0} {
		    option add *Menu.activeForeground $col $priority
		}
		if {[lsearch $state disabled] >= 0} {
		    option add *Menu.disabledForeground $col $priority
		}
	    }
	}
    }
    if {[info exists style(-selectbackground)]} {
	set color $style(-selectbackground)
	option add *Listbox.selectBackground    $color $priority
	option add *Spinbox.selectBackground    $color $priority
	option add *Text.selectBackground       $color $priority
    }
    if {[info exists style(-selectborderwidth)]} {
	set color $style(-selectborderwidth)
	option add *Listbox.selectBorderWidth   $color $priority
	option add *Text.selectBorderWidth      $color $priority
    }
    if {[info exists style(-selectforeground)]} {
	set color $style(-selectforeground)
	option add *Listbox.selectForeground    $color $priority
	option add *Spinbox.selectForeground    $color $priority
	option add *Text.selectForeground       $color $priority
    }

    set fill $treeStyle(-foreground)
    if {[info exists treeStyle(-itemfill)]} {
	set fill $treeStyle(-itemfill)
    }    
    option add *TreeCtrl.itemBackground   $treeStyle(-itembackground) $priority
    option add *TreeCtrl.showLines        $treeStyle(-showlines)      $priority
    option add *TreeCtrl.useTheme         $treeStyle(-usetheme)       $priority
    option add *TreeCtrl.itemFill         $fill                       $priority
}

#   Class bindings for ThemeChanged events.
#   They affect and configure existing widgets.
#   This is for pure tk widgets and not the ttk ones.

proc tileutils::ChaseArrowsThemeChanged {win} {
    
    array set style [style configure .]    
    if {[info exists style(-background)]} {
	set color $style(-background)
	$win configure -background $color
    }
}

proc tileutils::ListboxThemeChanged {win} {
    
    if {[winfo class $win] ne "Listbox"} {
	return
    }
	    
    # Some themes miss this one.
    array set style [list -foreground black]
    array set style [style configure .]    
    array set lbStyle [array get style]
    array set lbStyle [style configure Listbox]
    array set map   [style map .]
    array set map   [style map Listbox]

    if {[info exists style(-background)]} {
	# highlightBackground is drawn outside the border and must blend
	# with normal background.
	set color $style(-background)
	$win configure -highlightbackground $color
    }
    if {[info exists lbStyle(-selectbackground)]} {
	set color $lbStyle(-selectbackground)
	$win configure -selectbackground $color
    }
    if {[info exists lbStyle(-selectborderwidth)]} {
	set color $lbStyle(-selectborderwidth)
	$win configure -selectborderwidth $color
    }
    if {[info exists lbStyle(-selectforeground)]} {
	set color $lbStyle(-selectforeground)
	$win configure -selectforeground $color
    }
}

proc tileutils::MenuThemeChanged {win} {

    if {[winfo class $win] ne "Menu"} {
	return
    }
        
    # @@@ I could think of an alternative here:
    # style theme settings default {
    #    array set style [style configure .]
    #    array set map   [style map .]
    # }
    # etc. and then cache all in style(name) and map(name).
    
    # Some themes miss this one.
    array set style [list -foreground black]
    array set style [style configure .]    
    array set style [style configure Menu]    
    array set map   [style map .]
    array set map   [style map Menu]
    
    if {[info exists style(-background)]} {
	set color $style(-background)
	$win configure -background $color
	$win configure -activebackground $color
	if {[info exists map(-background)]} {
	    foreach {state col} $map(-background) {
		if {[lsearch $state active] >= 0} {
		    $win configure -activebackground  $col
		    break
		}
	    }
	}
    }
    if {[info exists style(-foreground)]} {
	set color $style(-foreground)
	$win configure -foreground $color
	$win configure -activeforeground $color
	$win configure -disabledforeground $color
	if {[info exists map(-foreground)]} {
	    foreach {state col} $map(-foreground) {
		if {[lsearch $state active] >= 0} {
		    $win configure -activeforeground  $col
		}
		if {[lsearch $state disabled] >= 0} {
		    $win configure -disabledforeground  $col
		}
	    }
	}
    }
}

proc tileutils::SpinboxThemeChanged {win} {
    
    if {[winfo class $win] ne "Spinbox"} {
	return
    }
    array set style [list -foreground black]
    array set style [style configure .]    
    array set style [style configure Spinbox]    
    
    if {[info exists style(-background)]} {
	set color $style(-background)
	$win configure -buttonbackground $color
	$win configure -highlightbackground $color
    }
    if {[info exists style(-selectbackground)]} {
	set color $style(-selectbackground)
	$win configure -selectbackground $color
    }
    if {[info exists style(-selectborderwidth)]} {
	set color $style(-selectborderwidth)
	$win configure -selectborderwidth $color
    }
    if {[info exists style(-selectforeground)]} {
	set color $style(-selectforeground)
	$win configure -selectforeground $color
    }
}

proc tileutils::TextThemeChanged {win} {
    
    if {[winfo class $win] ne "Text"} {
	return
    }
    array set style [list -foreground black]
    array set style [style configure .]    
    array set style [style configure Text]    
    array set styleB [style configure .]    
    
    if {[info exists styleB(-background)]} {
	# highlightBackground is drawn inside the border and must blend
	# with Text background. ???????? Wrong ?????
	set color $styleB(-background)
	$win configure -highlightbackground $color
    }
    if {[info exists style(-selectbackground)]} {
	set color $style(-selectbackground)
	$win configure -selectbackground $color
    }
    if {[info exists style(-selectborderwidth)]} {
	set color $style(-selectborderwidth)
	$win configure -selectborderwidth $color
    }
    if {[info exists style(-selectforeground)]} {
	set color $style(-selectforeground)
	$win configure -selectforeground $color
    }
}

# tileutils::TreeCtrlThemeChanged --
# 
#       TreeCtrl is a bit special.

proc tileutils::TreeCtrlThemeChanged {win} {
    
    if {[winfo class $win] ne "TreeCtrl"} {
	return
    }
    
    # Style options.
    array set style [list -foreground black]
    array set style [style configure .]    
    array set treeStyle [array get style]
    array set treeStyle [style configure TreeCtrl]
    $win configure -background $treeStyle(-background) \
      -usetheme $treeStyle(-usetheme) -showlines $treeStyle(-showlines)
    
    set fillT {white {selected focus} black {selected !focus}}
    
    # Column options:
    set columnOpts [list]
    if {[info exists style(-background)]} {
	lappend columnOpts -background $style(-background)
    }
    if {[info exists style(-foreground)]} {
	lappend columnOpts -textcolor $style(-foreground)
    }
    if {[info exists treeStyle(-itembackground)]} {
	lappend columnOpts -itembackground $treeStyle(-itembackground)
    }
    eval {treeutil::configurecolumns $win} $columnOpts
    
    # Item options (styles):
    # NB: More specialized settings must be made by widget specific handlers.
    #     This must be made using the bindtag 'TreeCtrlPost'.
    set fill $treeStyle(-foreground)
    if {[info exists treeStyle(-itemfill)]} {
	set fill $treeStyle(-itemfill)
    }    
    set stateFill [concat $fillT [list $fill {}]]
    treeutil::configureelementtype $win text -fill $stateFill
}

proc tileutils::WaveLabelThemeChanged {win} {

    if {[winfo class $win] eq "WaveLabel"} {
	array set style [list -foreground black]
	array set style [style configure .]    

	if {[info exists style(-background)]} {
	    set color $style(-background)
	    $win configure -background $color
	    $win configure -columnbackground $color
	}
    }
}
   
# These should be collected in a separate theme specific file.

proc tileutils::configstyles {name} {
    global  this
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
	if {[info exists ::tile::version]} {
	    if {[package vcompare $::tile::version 0.7.3] >= 0} {
		style configure TCheckbutton -padding {2}
		style configure TRadiobutton -padding {2}
	    }
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
	
	if {$this(tile08)} {
	    style element create Safari.background image \
	      [list $tiles(blank)                         \
	      {background}                 $tiles(blank)  \
	      {active !disabled !pressed}  $tiles(oval)   \
	      {pressed !disabled}          $tiles(ovalDark)] \
	      -border {6 6 6 6} -padding {0} -sticky news
	} else {
	    style element create Safari.background image $tiles(blank)  \
	      -border {6 6 6 6} -padding {0} -sticky news  \
	      -map [list  \
	      {background}                 $tiles(blank)  \
	      {active !disabled !pressed}  $tiles(oval)   \
	      {pressed !disabled}          $tiles(ovalDark)]
	}
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
	if {$this(tile08)} {
	    style element create arrowCheckIcon image \
	      [list $tiles(open) \
	      {!active !background  selected} $tiles(close)     \
	      { active !background !selected} $tiles(openDark)  \
	      { active !background  selected} $tiles(closeDark) \
	      {!active  background !selected} $tiles(openLight) \
	      {!active  background  selected} $tiles(closeLight)] \
	      -sticky w -border {0}
	} else {
	    style element create arrowCheckIcon image $tiles(open) \
	      -sticky w -border {0} \
	      -map [list \
	      {!active !background  selected} $tiles(close)     \
	      { active !background !selected} $tiles(openDark)  \
	      { active !background  selected} $tiles(closeDark) \
	      {!active  background !selected} $tiles(openLight) \
	      {!active  background  selected} $tiles(closeLight)]
	}
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
    array set opts [font actual CociDefaultFont]
    set opts(-underline) 1
    eval {font configure $underlineDefault} [array get opts]
    set fonts(underlineDefault) $underlineDefault

    # Underline small font.
    set underlineSmall [font create]
    array set opts [font actual CociSmallFont]
    set opts(-underline) 1
    eval {font configure $underlineSmall} [array get opts]
    set fonts(underlineSmall) $underlineSmall    
    
}

set dir [file join [file dirname [info script]] tiles]
tileutils::LoadImages $dir {*.gif *.png}
tileutils::MakeFonts
    
foreach name [tile::availableThemes] {
    
    # @@@ We could be more economical here and load theme only when needed.
    if {[catch {package require ${::tileutils::ns}::$name}]} {
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
    
    # Extra test:
    if {0} {
	package require tkpath

	set str "All MSN Messenger wannabies:\nDid you know how to make text widgets with rounded corners?"
	set size 32
	set tkpath::antialias 1
	set S [::tkpath::surface new $size $size]
	$S create prect 2 2 30 30 -rx 10 -fill white -stroke "#a19de2" \
	  -strokewidth 2
	set image [$S copy [image create photo]]
	$S destroy

	style element create RR.background image $image \
	  -border {12 12 12 12} -padding {0} -sticky news	    	
	style layout RR.TEntry {
	    RR.background -sticky news -children {
		Entry.padding -sticky news -children {
		    Entry.textarea -sticky news
		}
	    }
	}
	style map RR.TEntry  \
	  -foreground {{background} "#363636" {} black}

	toplevel .tt
	set f .tt.f
	ttk::frame $f -padding 20
	pack $f -fill x
	ttk::frame $f.cont -style RR.TEntry
	pack $f.cont 
	text $f.t -wrap word -borderwidth 0 -highlightthickness 0 \
	  -width 40 -height 6
	bind $f.t <FocusIn>  [list $f.cont state focus]
	bind $f.t <FocusOut> [list $f.cont state {!focus}]
	pack $f.t -in $f.cont -padx 6 -pady 6 -fill both -expand 1
	
	$f.t insert end $str
	
	# WIth Aqua style focus ring.
	set S [::tkpath::surface new $size $size]
	$S create prect 3 3 29 29 -rx 10 -fill white -stroke "#c3c3c3" \
	  -strokewidth 2
	set imborder [$S copy [image create photo]]
	$S destroy

	set S [::tkpath::surface new $size $size]
	$S create prect 3 3 29 29 -rx 10 -fill white -stroke "#c3c3c3" \
	  -strokewidth 2
	$S create prect 0.5 0.5 31.5 31.5 -rx 12 -stroke "#afc9e1"
	$S create prect 1.5 1.5 30.5 30.5 -rx 11 -stroke "#93b8d9"
	$S create prect 2.5 2.5 29.5 29.5 -rx 10 -stroke "#81a7ca"
	set imfocus [$S copy [image create photo]]
	$S destroy
	
	if {$this(tile08)} {
	    style element create RRAqua.background image \
	      [list $imborder {focus} $imfocus] \
	      -border {12 12 12 12} -padding {0} -sticky news
	} else {
	    style element create RRAqua.background image $imborder \
	      -border {12 12 12 12} -padding {0} -sticky news \
	      -map [list {focus} $imfocus]
	}
	style layout RRAqua.TEntry {
	    RRAqua.background -sticky news -children {
		Entry.padding -sticky news -children {
		    Entry.textarea -sticky news
		}
	    }
	}
	style map RRAqua.TEntry  \
	  -foreground {{background} "#363636" {} black}

	set f .tt.aqua
	ttk::frame $f -padding 20
	pack $f -fill x
	ttk::frame $f.cont -style RRAqua.TEntry
	pack $f.cont
	text $f.t -wrap word -borderwidth 0 -highlightthickness 0 \
	  -width 40 -height 6 -font {{Lucida Grande} 16}
	bind $f.t <FocusIn>  [list $f.cont state focus]
	bind $f.t <FocusOut> [list $f.cont state {!focus}]
	pack $f.t -in $f.cont -padx 7 -pady 7 -fill both -expand 1
	
	$f.t insert end $str
	
    }
}

#-------------------------------------------------------------------------------
