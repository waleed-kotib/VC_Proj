# Tile.tcl --
# 
#       Experimental!
# 
# $Id: Tile.tcl,v 1.1 2004-11-30 15:11:10 matben Exp $

namespace eval ::TileComp:: { }

proc ::TileComp::Init { } {
    global  this

    if {[catch {package require tile}]} {
	return
    }
    return
    
    ::Debug 2 "::TileComp::Init"
    
    # Just experimenting with the 'tile' extension...
    set widgets {button radiobutton checkbutton menubutton scrollbar \
      frame label labelframe}
    set widgets {button}
    foreach name $widgets {
	rename $name ""
	rename t${name} $name
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
