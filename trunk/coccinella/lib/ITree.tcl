#  ITree.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements a simple generic treectrl interface.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: ITree.tcl,v 1.6 2005-11-05 11:37:25 matben Exp $
#       
#  Each item is associated with a list reflecting the tree hierarchy:
#       
#       v = {tag tag ...}
#       
#  We MUST keep the complete tree structure for an item in order to uniquely 
#  identify it in the tree.

package provide ITree 1.0

namespace eval ::ITree {

    variable buttonPressMillis 1000
    variable tag2Item
    variable options
}

proc ::ITree::New {T wxsc wysc args} {
    global  this
    variable options

    set options($T,-backgroundimage) ""
    foreach {key value} $args {
	set options($T,$key) $value
    }
    
    treectrl $T -usetheme 1 -selectmode extended  \
      -showroot 0 -showrootbutton 0 -showbuttons 1 -showheader 0  \
      -xscrollcommand [list ::UI::ScrollSet $wxsc     \
      [list grid $wxsc -row 1 -column 0 -sticky ew]]  \
      -yscrollcommand [list ::UI::ScrollSet $wysc     \
      [list grid $wysc -row 0 -column 1 -sticky ns]]  \
      -backgroundimage $options($T,-backgroundimage)  \
      -borderwidth 0 -highlightthickness 0
    
    # This is a dummy option.
    set stripeBackground [option get $T stripeBackground {}]
    set stripes [list $stripeBackground {}]

    $T column create -tag cTree  \
      -itembackground $stripes -resize 0 -expand 1
    $T column create -tag cTag -visible 0
    $T configure -treecolumn cTree

    set fill [list $this(sysHighlight) {selected focus} gray {selected !focus}]
    $T element create eImage image
    $T element create eText text -lines 1
    $T element create eBorder rect -open new -outline white -outlinewidth 1 \
      -fill $fill -showfocus 1
 
    set S [$T style create styStd]
    $T style elements $S {eBorder eImage eText}
    $T style layout $S eText -padx 4 -squeeze x -expand ns -ipady 2 -minheight 16
    $T style layout $S eImage -expand ns -ipady 2 -minheight 16
    $T style layout $S eBorder -detach yes -iexpand xy -indent 0

    set S [$T style create styTag]
    $T style elements $S {eText}

    $T configure -defaultstyle {styStd styTag}

    $T notify bind $T <Selection>      { ::ITree::Selection %T }
    $T notify bind $T <Expand-after>   { ::ITree::OpenTreeCmd %T %I }
    $T notify bind $T <Collapse-after> { ::ITree::CloseTreeCmd %T %I }
    bind $T <Button-1>        { ::ITree::ButtonPress %W %x %y }        
    bind $T <ButtonRelease-1> { ::ITree::ButtonRelease %W %x %y }        
    bind $T <Double-1>        { ::ITree::DoubleClick %W %x %y }        
    bind $T <<ButtonPopup>>   { ::ITree::Popup %W %x %y }
    bind $T <Destroy>         {+::ITree::OnDestroy %W }
}

proc ::ITree::Selection {T} {
    variable options

    if {[info exists options($T,-selection)]} {
	set n [$T selection count]
	if {$n == 1} {
	    set item [$T selection get]
	    set v [$T item element cget $item cTag eText -text]
	    $options($T,-selection) $T $v
	}
    }
}

proc ::ITree::OpenTreeCmd {T item} {
    variable options

    if {[info exists options($T,-open)]} {
	set v [$T item element cget $item cTag eText -text]
	$options($T,-open) $T $v
    }
}

proc ::ITree::CloseTreeCmd {T item} {
    variable options

    if {[info exists options($T,-close)]} {
	set v [$T item element cget $item cTag eText -text]
	$options($T,-close) $T $v
    }
}

proc ::ITree::ButtonPress {T x y} {
    variable buttonAfterId
    variable buttonPressMillis
    variable options

    if {[info exists options($T,-buttonpress)]} {    
	if {[tk windowingsystem] eq "aqua"} {
	    if {[info exists buttonAfterId]} {
		catch {after cancel $buttonAfterId}
	    }
	    set cmd [list ::ITree::ButtonPressCmd $T $x $y]
	    set buttonAfterId [after $buttonPressMillis $cmd]
	}
    }
}

proc ::ITree::ButtonRelease {T x y} {
    variable buttonAfterId
    
    if {[info exists buttonAfterId]} {
	catch {after cancel $buttonAfterId}
	unset buttonAfterId
    }
}

proc ::ITree::ButtonPressCmd {T x y} {
    variable options
    
    # Perhaps we should check that mouse is still in widget before posting?
    if {[info exists options($T,-buttonpress)]} {
	DoPopup $T $x $y $options($T,-buttonpress)
    }
}

proc ::ITree::DoubleClick {T x y} {
    variable options

    if {[info exists options($T,-doublebutton)]} {
	set id [$T identify $x $y]
	if {[lindex $id 0] eq "item"} {
	    set item [lindex $id 1]
	    set v [$T item element cget $item cTag eText -text]
	} elseif {$id eq ""} {
	    set v {}
	}
	$options($T,-doublebutton) $T $v
    }
}

proc ::ITree::Popup {T x y} {    
    variable options

    if {[info exists options($T,-buttonpopup)]} {
	DoPopup $T $x $y $options($T,-buttonpopup)
    }
}

proc ::ITree::DoPopup {T x y command} {
    variable options

    if {[info exists options($T,-buttonpopup)]} {    
	set id [$T identify $x $y]
	if {[lindex $id 0] eq "item"} {
	    set item [lindex $id 1]
	    set v [$T item element cget $item cTag eText -text]
	} elseif {$id eq ""} {
	    set v {}
	}
	$command $T $v $x $y
    }
}

proc ::ITree::Item {T v args} {
    variable tag2Item
        
    set isopen 0
    if {[set idx [lsearch $args -open]] >= 0} {
	set isopen [lindex $args [incr idx]]
    }
    set parent root
    if {[llength $v] > 1} {
	set parentv [lrange $v 0 end-1]
	set parent $tag2Item($T,$parentv)
	
    }
    set item [$T item create -open $isopen -parent $parent]
    set tag2Item($T,$v) $item

    $T item element configure $item cTag eText -text $v
    eval {ItemConfigure $T $v} $args
            
    return $item
}

proc ::ITree::IsItem {T v} {
    variable tag2Item
    
    set ans 0
    if {[info exists tag2Item($T,$v)]} {
	if {[$T item id $tag2Item($T,$v)] ne ""} {
	    set ans 1
	}
    }
    return $ans
}

proc ::ITree::GetItem {T v} {
    variable tag2Item
    
    set item ""
    if {[info exists tag2Item($T,$v)]} {
	if {[$T item id $tag2Item($T,$v)] ne ""} {
	    set item $tag2Item($T,$v)
	}
    }
    return $item
}

proc ::ITree::ItemConfigure {T v args} {
    variable tag2Item
    
    if {[info exists tag2Item($T,$v)]} {
	set item $tag2Item($T,$v)
	
	# Dispatch to the right element.
	foreach {key value} $args {
	    switch -- $key {
		-text - -font - -lines - -justify - -textvariable {
		    $T item element configure $item cTree eText $key $value
		}
		-image {
		    $T item element configure $item cTree eImage $key $value
		}
		-button {
		    $T item configure $item $key $value
		}
	    }
	}
    }
    return $item
}

proc ::ITree::Children {T v} {
    variable tag2Item
    
    set vchilds {}
    if {[info exists tag2Item($T,$v)]} {
	set citems [$T item children $tag2Item($T,$v)]
	foreach item $citems {
	    lappend vchilds [$T item element cget $item cTag eText -text]
	}
    }
    return $vchilds
}

proc ::ITree::Sort {T v args} {
    variable tag2Item
    
    if {[info exists tag2Item($T,$v)]} {
	set item $tag2Item($T,$v)
	eval {$T item sort $item -column cTree} $args
    }    
}

proc ::ITree::FindEndItems {T vend} {
    variable tag2Item

    set vlist {}
    foreach {key item} [array get tag2Item $T,*] {
	set v [string map [list "$T," ""] $key]
	if {[lindex $v end] eq $vend} {
	    lappend vlist $v
	}
    }
    return $vlist
}

proc ::ITree::DeleteItem {T v} {
    variable tag2Item
    
    if {[info exists tag2Item($T,$v)]} {
	set item $tag2Item($T,$v)
	UnsetTags $T $item	
	$T item delete $item
    }    
}

proc ::ITree::UnsetTags {T item} {
    variable tag2Item
    
    # Must do this recursively.
    set children [$T item children $item]
    foreach citem $children {
	UnsetTags $T $citem
    }
    set v [$T item element cget $item cTag eText -text]
    unset -nocomplain tag2Item($T,$v)    
}

proc ::ITree::DeleteChildren {T v} {
    
    foreach vchild [Children $T $v] {
	DeleteItem $T $vchild
    }
}

proc ::ITree::OnDestroy {T} {
    variable options
    variable tag2Item
    
    array unset options $T,*
    array unset tag2Item $T,*
}

