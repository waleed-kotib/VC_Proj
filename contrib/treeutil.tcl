# treeutil.tcl ---
#
#       Collection of various utility procedures for treectrl.
#       
#  Copyright (c) 2005
#  
#  This source file is distributed under the BSD license.
#  
#  $Id: treeutil.tcl,v 1.4 2005-11-04 15:14:55 matben Exp $

# USAGE:
# 
#       ::treeutil::bind widgetPath item ?type? ?script?
#       
#       where 'type' is <Enter> or <Leave>.
#       Substitutions in script:
#         %T    treectrl widget path
#         %C    column index
#         %I    item id
#         %x    widget x coordinate
#         %y    widget y coordinate
#         %E    element name

package provide treeutil 1.0

namespace eval ::treeutil {

    variable events {<Enter> <Leave>}
}

# treeutil::bind --
# 
#       Public interface.

proc ::treeutil::bind {w item args} {
    variable state
    variable events
        
    if {[winfo class $w] ne "TreeCtrl"} {
	return -code error "window must be a treectrl"
    }
    set len [llength $args]
    if {$len > 2} {
	return -code error "usage: ::treeutil::bind w item ?type? ?script?"
    }
    set ans {}
    set item [$w item id $item]
    if {$len == 0} {
	foreach e $events {
	    if {[info exists state($w,$item,$e)]} {
		lappend ans $e
	    }
	}
    } elseif {$len == 1} {
	set type [lindex $args 0]
	if {[info exists state($w,$item,$type)]} {
	    set ans $state($w,$item,$type)
	}
    } else {
	set type [lindex $args 0]
	set cmd  [lindex $args 1]
	if {$cmd eq ""} {
	    unset -nocomplain state($w,$item,$type)
	} elseif {[string index $cmd 0] eq "+"} {
	    lappend state($w,$item,$type) [string trimleft $cmd "+"]
	} else {
	    set state($w,$item,$type) [list $cmd]
	}
	if {![info exists state($w,init)]} {
	    Init $w
	    set state($w,init) 1
	}
    }
    return $ans
}

proc ::treeutil::Init {w} {
    variable state
    
    ::bind $w <Motion>   {+::treeutil::Track %W %x %y }
    ::bind $w <Enter>    {+::treeutil::Track %W %x %y }
    ::bind $w <Leave>    {+::treeutil::Track %W %x %y }
    ::bind $w <Destroy>  {+::treeutil::OnDestroy %W }
    $w notify bind $w <ItemDelete> {+::treeutil::OnItemDelete %T %i }
    
    set state($w,item) -1
}    
    
proc ::treeutil::Track {w x y} {
    variable state

    set id [$w identify $x $y]
    set prev $state($w,item)
        
    if {[lindex $id 0] eq "item"} {
	set item [lindex $id 1]
	if {$item != $prev} {
	    if {$prev != -1} {
		Generate $w $x $y $prev <Leave> $id
	    }
	    Generate $w $x $y $item <Enter> $id
	    set state($w,item) $item
	}
    } elseif {$id eq ""} {
	if {$prev != -1} {
	    Generate $w $x $y $prev <Leave>
	}
	set state($w,item) -1
    }
}

proc ::treeutil::Generate {w x y item type {id ""}} {
    variable state
    
    #puts "Generate $item $type"
    
    if {[info exists state($w,$item,$type)]} {
	array set aid {column "" elem "" line "" button ""}
	if {[llength $id] == 6} {
	    array set aid $id
	}
	set map [list %T $w %x $x %y $y %I $item %C $aid(column) %E $aid(elem)]
	foreach cmd $state($w,$item,$type) {
	    uplevel #0 [string map $map $cmd]
	}
    }
}

proc ::treeutil::OnItemDelete {w items} {
    variable state
    
    foreach item $items {
	array unset state $w,$item,*
    }
}

proc ::treeutil::OnDestroy {w} {
    variable state
    
    array unset state $w,*
}

if {0} {
    # Test.
    set T .jmain.frall.fnb.di.box.tree
    set item 1
    ::treeutil::bind $T $item <Enter> {puts "Enter %I C=%C E=%E x=%x y=%y"}
    ::treeutil::bind $T $item <Leave> {puts "Leave %I"}    
}

