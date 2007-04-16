#  ITree.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements a simple generic treectrl interface.
#      
#  Copyright (c) 2005-2007  Mats Bengtsson
#  
# $Id: ITree.tcl,v 1.16 2007-04-16 09:15:00 matben Exp $
#       
#  Each item is associated with a list reflecting the tree hierarchy:
#       
#       v = {v0 v1 ...}
#       
#  We MUST keep the complete tree structure for an item in order to uniquely 
#  identify it in the tree.
#  

package provide ITree 1.0

namespace eval ::ITree {

    variable buttonPressMillis 1000
    variable options
}

proc ::ITree::New {T wxsc wysc args} {
    global  this
    variable options

    set options($T,-backgroundimage) ""
    foreach {key value} $args {
	set options($T,$key) $value
    }
    set fillT {white {selected focus} black {selected !focus}}
    set fill [list $this(sysHighlight) {selected focus} gray {selected !focus}]

    treectrl $T -usetheme 1 -selectmode extended  \
      -showroot 0 -showrootbutton 0 -showbuttons 1 -showheader 0  \
      -xscrollcommand [list ::UI::ScrollSet $wxsc     \
      [list grid $wxsc -row 1 -column 0 -sticky ew]]  \
      -yscrollcommand [list ::UI::ScrollSet $wysc     \
      [list grid $wysc -row 0 -column 1 -sticky ns]]  \
      -backgroundimage $options($T,-backgroundimage)  \
      -borderwidth 0 -highlightthickness 0            \
      -height 0 -width 0
    
    # This is a dummy option.
    set stripeBackground [option get $T stripeBackground {}]
    set stripes [list $stripeBackground {}]

    $T column create -tags cTree  \
      -itembackground $stripes -resize 0 -expand 1
    $T configure -treecolumn cTree

    $T element create eImage image
    $T element create eText text -lines 1 -fill $fillT
    $T element create eBorder rect -open new -outline white -outlinewidth 1 \
      -fill $fill -showfocus 1
 
    set S [$T style create styStd]
    $T style elements $S {eBorder eImage eText}
    $T style layout $S eText -padx 4 -squeeze x -expand ns -ipady 2 -minheight 16
    $T style layout $S eImage -expand ns -ipady 2 -minheight 16
    $T style layout $S eBorder -detach yes -iexpand xy -indent 0

    $T column configure cTree -itemstyle styStd

    $T notify bind $T <Selection>      { ::ITree::Selection %T }
    $T notify bind $T <Expand-after>   { ::ITree::OpenTreeCmd %T %I }
    $T notify bind $T <Collapse-after> { ::ITree::CloseTreeCmd %T %I }
    bind $T <Button-1>        { ::ITree::ButtonPress %W %x %y }        
    bind $T <ButtonRelease-1> { ::ITree::ButtonRelease %W %x %y }        
    bind $T <Double-1>        { ::ITree::DoubleClick %W %x %y }        
    bind $T <<ButtonPopup>>   { ::ITree::Popup %W %x %y }
    bind $T <Destroy>         { ::ITree::OnDestroy %W }
}

# ITree::PrepTags --
# 
#       Always add two tags:
#       1) v-$v
#       2) e-$vend
#       
#       where v = {v0 v1 v2 ... vend}.
#       Since we need to find items bu their end tags (v).

proc ::ITree::PrepTags {v} {
    return [treeutil::protect [list v-$v e-[lindex $v end]]]
}

proc ::ITree::VTag {v} {
    return [treeutil::protect v-$v]
}

proc ::ITree::GetV {T item} {
    set vtag [treeutil::deprotect [lindex [$T item tag names $item] 0]]
    return [string range $vtag 2 end]
}

proc ::ITree::GetStyle {T} {
    return styStd
}

proc ::ITree::ElementLayout {T type args} {
    array set type2elem {
	image eImage
	text  eText
    }
    return [eval {$T style layout styStd $type2elem($type)} $args]
}

proc ::ITree::Selection {T} {
    variable options

    if {[info exists options($T,-selection)]} {
	set n [$T selection count]
	if {$n == 1} {
	    set item [$T selection get]
	    set v [GetV $T $item]
	    $options($T,-selection) $T $v
	}
    }
}

proc ::ITree::OpenTreeCmd {T item} {
    variable options

    if {[info exists options($T,-open)]} {
	set v [GetV $T $item]
	$options($T,-open) $T $v
    }
}

proc ::ITree::CloseTreeCmd {T item} {
    variable options

    if {[info exists options($T,-close)]} {
	set v [GetV $T $item]
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
    set id [$T identify $x $y]
    if {$id eq ""} {
	$T selection clear all
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
	    set v [GetV $T $item]
	} elseif {$id eq ""} {
	    set v [list]
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
	    set v [GetV $T $item]
	} elseif {$id eq ""} {
	    set v [list]
	}
	$command $T $v $x $y
    }
}

proc ::ITree::Item {T v args} {
        
    set isopen 0
    if {[set idx [lsearch $args -open]] >= 0} {
	set isopen [lindex $args [incr idx]]
    }
    set parent root
    if {[llength $v] > 1} {
	set parentv [lrange $v 0 end-1]
	set parent [$T item id [list tag [treeutil::protect v-$parentv]]]
    }
    set item [$T item create -open $isopen -parent $parent -tags [PrepTags $v]]]
    eval {ItemConfigure $T $v} $args       
    return $item
}

proc ::ITree::IsItem {T v} {
    return [llength [$T item id [list tag [treeutil::protect v-$v]]]]
}

proc ::ITree::GetItem {T v} {
    return [$T item id [list tag [treeutil::protect v-$v]]]
}

proc ::ITree::ItemConfigure {T v args} {
    
    set item [$T item id [list tag [treeutil::protect v-$v]]]
	
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
    return $item
}

proc ::ITree::Children {T v} {

    set vchilds [list]
    set citems [$T item children [list tag [treeutil::protect v-$v]]]
    foreach item $citems {
	set v [GetV $T $item]
	lappend vchilds $v
    }
    return $vchilds
}

proc ::ITree::Sort {T v args} {
    eval {$T item sort [list tag [treeutil::protect v-$v]] -column cTree} $args
}

# ITree::FindEndItems--
# 
#       This is equivalent of getting all parents of this item.

proc ::ITree::FindEndItems {T vend} {

    set items [$T item id [list tag [treeutil::protect e-$vend]]]
    set vlist [list]
    foreach item $items {
	lappend vlist [GetV $T $item]
    }
    return $vlist
}

proc ::ITree::DeleteItem {T v} {
    set item [$T item id [list tag [treeutil::protect v-$v]]]
    if {[llength $item]} {
	$T item delete $item
    }
}

proc ::ITree::DeleteChildren {T v} {
    
    # This must be failsafe if item not exists.
    set items [$T item children [list tag [treeutil::protect v-$v]]]
    foreach item $items {
	$T item delete $item
    }
}

proc ::ITree::OnDestroy {T} {
    variable options    
    array unset options $T,*
}

