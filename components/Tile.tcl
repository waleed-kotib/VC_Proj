# Tile.tcl --
# 
#       Experimental!
# 
# $Id: Tile.tcl,v 1.6 2005-03-05 09:00:31 matben Exp $

namespace eval ::TileComp:: { }

proc ::TileComp::Init { } {
    global  this

    if {[catch {package require tile 0.6}]} {
	return
    }
    return
    
    ::Debug 2 "::TileComp::Init"
    
    # Just experimenting with the 'tile' extension...
    set widgets {button radiobutton checkbutton menubutton scale scrollbar \
      frame label labelframe entry}
    #set widgets {button checkbutton label radiobutton scrollbar}
    #set widgets {entry}
    foreach name $widgets {
	uplevel #0 [list rename $name ""]
	uplevel #0 [list rename t${name} $name]
    }
    switch -- $this(platform) {
	macosx {
	    set theme aqua
	    
	    # hack!
	    namespace eval ::tile {
		style theme settings aqua {
		    style default background -background "#dedede"
		    style default "."  \
		      -font {{Lucida Grande} 11}
		    style default TEntry  \
		      -font {{Lucida Grande} 11}
		}
	    }
	}
	default {
	    set theme clam
	    package require tile::theme::$theme
	}
    }
    #style theme use $theme
    
    component::register Tile  \
      "The Tile package for truly native user interface controls."
}

#-------------------------------------------------------------------------------
