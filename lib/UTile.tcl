# UTile.tcl --
# 
#       Methods to make a smooth transition to the tile package.
#       
#       Experimental!
# 
# $Id: UTile.tcl,v 1.2 2005-03-11 06:55:56 matben Exp $

package provide UTile 0.1

namespace eval ::UTile:: { }

proc ::UTile::Init { } {
    variable priv

    if {[catch {package require tile 0.6}]} {
	set priv(tile) 0
    } else {
	set priv(tile) 1
    }
    set priv(widgets) {
	frame labelframe label entry
	button radiobutton checkbutton menubutton 
	scale scrollbar
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
	set wset $priv(widgets)
    } else {
	set wset $widgets
    }
    set ns [uplevel 1 {namespace current}]
    foreach widget $wset {
	interp alias {} ${ns}::${widget} {} ::ttk::${widget}
    }
    return 1
}

# ::UTile::UseTk --
# 
#       Guard against using tile widgets when ::UTile::Use was invoked
#       in an outer namespace. Switches back to standard tk again.

proc ::UTile::UseTk { } {
    variable priv
    
    set ns [uplevel 1 {namespace current}]
    foreach widget $priv(widgets) {
	interp alias {} ${ns}::${widget} {} ::${widget}
    }
}


