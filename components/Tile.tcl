# Tile.tcl --
# 
#       Experimental!
# 
# $Id: Tile.tcl,v 1.2 2004-12-06 15:26:56 matben Exp $

namespace eval ::TileComp:: { }

proc ::TileComp::Init { } {
    global  this

    if {[catch {package require tile}]} {
	return
    }
    return
    
    ::Debug 2 "::TileComp::Init"
    
    # Just experimenting with the 'tile' extension...
    set widgets {button radiobutton checkbutton menubutton scale scrollbar \
      frame label labelframe}
    set widgets {button checkbutton label radiobutton scrollbar}
    foreach name $widgets {
	uplevel #0 [list rename $name ""]
	uplevel #0 [list rename t${name} $name]
    }
    switch -- $this(platform) {
	macosx {
	    set theme aqua
	}
	default {
	    set theme clam
	    package require tile::theme::$theme
	}
    }
    style theme use $theme
    
    component::register Tile  \
      "The Tile package for truly native user interface controls."
}

#-------------------------------------------------------------------------------
