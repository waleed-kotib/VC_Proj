# UTile.tcl --
# 
#       Methods to make a smooth transition to the tile package.
#       
#       Experimental!
# 
# $Id: UTile.tcl,v 1.1 2005-03-07 07:22:36 matben Exp $

package provide UTile 0.1

namespace eval ::UTile:: { }

proc ::UTile::Init { } {
    variable priv

    if {[catch {package require tile 0.6}]} {
	set priv(tile) 0
    } else {
	set priv(tile) 1
    }
    return $priv(tile)
}

proc ::UTile::Have { } {
    variable priv
    
    return $priv(tile)
}

# ::UTile::Use --
# 
#       Use this when initing a package using tile.
#       It redifines the usual control commands to ttk ones in current
#       namespace.

proc ::UTile::Use {{widgets {}}} {
    variable priv
    
    if {!$priv(tile)} {
	return 0
    }
    if {$widgets == {}} {
	set wset {
	    frame labelframe label entry
	    button radiobutton checkbutton menubutton 
	    scale scrollbar
	}
    } else {
	set wset $widgets
    }
    set ns [uplevel 1 {namespace current}]
    foreach widget $wset {
	interp alias {} ${ns}::${widget} {} ::ttk::$widget
    }
    return 1
}
