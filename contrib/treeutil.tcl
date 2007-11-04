# treeutil.tcl ---
#
#       Collection of various utility procedures for treectrl.
#       
#  Copyright (c) 2005
#  
#  This source file is distributed under BSD-style license.
#  
#  $Id: treeutil.tcl,v 1.18 2007-11-04 13:54:50 matben Exp $

# USAGE:
# 
#       ::treeutil::bind widgetPath item ?type? ?script?
#       
#       where 'type' is <Enter> , <Leave> or <ButtonPress-1>.
#       Substitutions in script:
#         %T    treectrl widget path
#         %C    column index
#         %I    item id
#         %x    widget x coordinate
#         %y    widget y coordinate
#         %E    element name
#         
#       ::treeutil::setdboptions widgetPath classWidget prefix

package provide treeutil 1.0

namespace eval ::treeutil {

    variable events {<Enter> <Leave> <ButtonPress-1>}
}

# treeutil::bind --
# 
#       Public interface.

proc treeutil::bind {w item args} {
    variable state
    variable events
        
    if {[winfo class $w] ne "TreeCtrl"} {
	return -code error "window must be a treectrl"
    }
    set len [llength $args]
    if {$len > 2} {
	return -code error "usage: ::treeutil::bind w item ?type? ?script?"
    }
    set ans [list]
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

proc treeutil::Init {w} {
    variable state
    
    set btags [bindtags $w]
    if {[lsearch $btags TreeUtil] < 0} {
	bindtags $w [linsert $btags 1 TreeUtil]
    }
    ::bind TreeUtil <Motion>         { ::treeutil::Track %W %x %y }
    ::bind TreeUtil <Enter>          { ::treeutil::Track %W %x %y }
    ::bind TreeUtil <Leave>          { ::treeutil::Track %W %x %y }
    ::bind TreeUtil <ButtonPress-1>  { ::treeutil::OnButtonPress1 %W %x %y }
    ::bind TreeUtil <Destroy>        { ::treeutil::OnDestroy %W }
    
    # We could think of a <FocusOut> event also but the macs floating window
    # takes focus which makes this useless for tooltip windows.
    
    # Scrolling may move items without moving the mouse.
    # @@@ Many more things affect this!
    $w notify bind $w <Scroll-x>        {+::treeutil::Generic %T }
    $w notify bind $w <Scroll-y>        {+::treeutil::Generic %T }
    $w notify bind $w <Expand-after>    {+::treeutil::Generic %T }
    $w notify bind $w <Collapse-after>  {+::treeutil::Generic %T }
    $w notify bind $w <ItemDelete>      {+::treeutil::Generic %T }
    
    $w notify bind $w <ItemDelete>      {+::treeutil::OnItemDelete %T %i }
    
    set state($w,item) -1
    set state($w,x)    -1
    set state($w,y)    -1
}    
    
proc treeutil::Track {w x y} {
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
    } elseif {([lindex $id 0] eq "header") || ($id eq "")} {
	if {$prev != -1} {
	    Generate $w $x $y $prev <Leave>
	}
	set state($w,item) -1
    }
    set state($w,x) $x
    set state($w,y) $y
}

proc treeutil::Generic {w} {
    variable state
    
    Track $w $state($w,x) $state($w,y)
}

proc treeutil::Generate {w x y item type {id ""}} {
    variable state
        
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

proc treeutil::OnButtonPress1 {w x y} {
    variable state
    
    set id [$w identify $x $y]
    if {[lindex $id 0] eq "item"} {
	set item [lindex $id 1]
	if {[llength $id] == 6} {
	    Generate $w $x $y $item <ButtonPress-1>
	}
    }
}

proc treeutil::OnItemDelete {w items} {
    variable state
    
    foreach item $items {
	array unset state $w,$item,*
    }
}

proc treeutil::OnDestroy {w} {
    variable state
    
    array unset state $w,*
}

# treeutil::setdboptions --
# 
#       Configure elements and styles from option database.
#       We use a specific format for the database resource names:
#       
#         element options:    prefix:elementName-option
#         style options:      prefix:styleName:elementName-option
#         
# Arguments:
#       w           treectrl widgetPath
#       wclass      widgetPath
#       prefix
#       
# Results:
#       configures treectrl elements and layouts


proc treeutil::setdboptions {w wclass prefix} {
    
    # Element options:
    foreach ename [$w element names] {
	set eopts [list]
	foreach ospec [$w element configure $ename] {
	    set oname  [lindex $ospec 0]
	    set dvalue [lindex $ospec 3]
	    set value  [lindex $ospec 4]
	    set dbname ${prefix}:${ename}${oname}	    
	    set dbvalue [option get $wclass $dbname {}]
	    if {($dbvalue ne "") && ($value ne $dbvalue)} {
		lappend eopts $oname $dbvalue
	    }
	}
	eval {$w element configure $ename} $eopts
    }
    
    # Style layout options:
    foreach style [$w style names] {
	foreach ename [$w style elements $style] {
	    set sopts [list]
	    foreach {key value} [$w style layout $style $ename] {
		set dbname ${prefix}:${style}:${ename}${key}
		set dbvalue [option get $wclass $dbname {}]
		if {($dbvalue ne "") && ($value ne $dbvalue)} {
		    lappend sopts $key $dbvalue
		}
	    }
	    eval {$w style layout $style $ename} $sopts
	}
    }
}

# treeutil::configurecolumns --
# 
#       Configure all columns.

proc treeutil::configurecolumns {w args} {
    foreach C [$w column list -visible] {
	eval {$w column configure $C} $args
    }
}

# treeutil::configureelements --
# 
#       Configure all elements.
#           -elementName-option value ...

proc treeutil::configureelements {w args} {
    foreach {key value} $args {
	set idx [string first "-" $key 1]
	set E [string range $key 1 [expr {$idx-1}]]
	set option [string range $key $idx end]
	$w element configure $E $option $value
    }
}

# treeutil::configurestyles --
# 
#       Configure all styles.
#           -styleName:elementName-option value

proc treeutil::configurestyles {w args} {
    foreach {key value} $args {
	set idx1 [string first ":" $key 1]
	set idx2 [string first "-" $key 2]
	set S [string range $key 1 [expr {$idx1-1}]]
	set E [string range $key [expr {$idx1+1}] [expr {$idx2-1}]]
	set option [string range $key $idx2 end]
	$w style layout $S $E $option $value
    }
}

# treeutil::configureelementtype --
#  
#       Simplified way of configuring a certain element type.

proc treeutil::configureelementtype {w type args} {
    foreach E [$w element names] {
	if {[$w element type $E] eq $type} {
	    eval {$w element configure $E} $args
	}
    }
}

proc treeutil::copycolumns {src dst} {
    
    foreach C [$src column list] {
	set opts [list]
	foreach spec [$src column configure $C] {
	    lappend opts [lindex $spec 4]
	}
	eval {$dst column create} $opts
    }
}

proc treeutil::copyelements {src dst} {
	
    foreach E [$src element names] {
	set opts [list]
	foreach spec [$src element configure $E] {
	    lappend opts [lindex $spec 4]
	}
	set type [$src element type $E]
	eval {$dst element create $E $type} $opts
    }
}

proc treeutil::copystyles {src dst} {
	
    foreach S [$src style names] {
	foreach E [$src style elements $S] {
	    set opts [$src style layout $S $E]
	    $dst style create $S
	    eval {$dst style layout $S $W} $opts
	}
    }
}

# treeutil::protect, deprotect --
# 
#       A tag is just a string of characters, and it may take any form, 
#       including that of an integer, although the characters 
#       '(', ')', '&', '|', '^' and '!' should be avoided. 
#       Tags must therefore be protected if they contain any of these specials.

# BUG: this wont work for "!"

proc treeutil::protect {tags} {
    regsub -all {([()&|^!])} $tags {\\\1} tags
    return $tags
}
proc treeutil::protect {tags} {
    # Not foolproof!!!
    set tags [string map {_ ___ ! _} $tags]
    regsub -all {([()&|^])} $tags {\\\1} tags
    return $tags
}

proc treeutil::deprotect {tags} {
    # Inverse of protect. 
    regsub -all {\\([()&|^!])} $tags {\1} tags
    return $tags
}
proc treeutil::deprotect {tags} {
    # Inverse of protect. 
    regsub -all {\\([()&|^])} $tags {\1} tags
    set tags [string map {! _ ___ _} $tags]
    return $tags
}


