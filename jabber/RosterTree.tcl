#  RosterTree.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the roster tree using treectrl.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: RosterTree.tcl,v 1.2 2005-11-04 15:14:55 matben Exp $

#-INTERNALS---------------------------------------------------------------------
#
#   We keep an invisible column cTag for tag storage, and an array 'tag2items'
#   that maps a tag to a set of items. 
#   One jid can belong to several groups (bad) which doesn't make {jid $jid}
#   unique!
# 
#   tags:
#     {head available/unavailable/transport/pending}
#     {jid $jid}                                  <- not unique !
#     {group $group $presence}                    <- note
#     {transport $jid}
#     {pending $jid}

package provide RosterTree 1.0

namespace eval ::RosterTree {

    # Actual:
    #option add *Roster*TreeCtrl.indent          18              widgetDefault

    # Fake:
    option add *Roster*TreeCtrl.rosterImage     sky             widgetDefault
    option add *Roster*TreeCtrl.dirImage        ""              widgetDefault
    option add *Roster*TreeCtrl.onlineImage     lightbulbon     widgetDefault
    option add *Roster*TreeCtrl.offlineImage    lightbulboff    widgetDefault
    option add *Roster*TreeCtrl.trptImage       block           widgetDefault
    option add *Roster*TreeCtrl.groupImage      folder16        widgetDefault

    
    variable buttonPressMillis 1000

}

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#
# A plugin system for roster styles.

namespace eval ::RosterTree {
    variable plugin

    set plugin(selected) ""
}

proc ::RosterTree::RegisterStyle {
    name label configProc initProc createItemProc deleteItemProc} {
	
    variable plugin
    
    set plugin($name,name)       $name
    set plugin($name,label)      $label
    set plugin($name,config)     $configProc
    set plugin($name,init)       $initProc
    set plugin($name,createItem) $createItemProc
    set plugin($name,deleteItem) $deleteItemProc
}

proc ::RosterTree::SetStyle {name} {
    variable plugin
    
    set plugin(selected) $name
}

proc ::RosterTree::GetStyle {} {
    variable plugin
    
    return $plugin(selected)
}

proc ::RosterTree::GetAllStyles {} {
    variable plugin
 
    set styles {}
    foreach {key name} [array get plugin *,name] {
	lappend styles $name $plugin($name,label)
    }
    return $styles
}

proc ::RosterTree::StyleConfigure {w} {
    variable plugin
    
    set name $plugin(selected)
    $plugin($name,config) $w
}

proc ::RosterTree::StyleInit {} {
    variable plugin
    
    set name $plugin(selected)
    $plugin($name,init)
}

proc ::RosterTree::StyleCreateItem {jid presence args} {
    variable plugin
    
    set name $plugin(selected)
    eval {$plugin($name,createItem) $jid $presence} $args
}

proc ::RosterTree::StyleDeleteItem {jid} {
    variable plugin
    
    set name $plugin(selected)
    $plugin($name,deleteItem) $jid
}
    
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# RosterTree::New --
# 
#       Create the treectrl widget and do common initializations.

proc ::RosterTree::New {_T wxsc wysc} {
    variable T
    
    set T $_T
            
    treectrl $T -usetheme 1 -selectmode extended  \
      -showroot 0 -showrootbutton 0 -showbuttons 1 -showheader 0  \
      -xscrollcommand [list ::UI::ScrollSet $wxsc     \
      [list grid $wxsc -row 1 -column 0 -sticky ew]]  \
      -yscrollcommand [list ::UI::ScrollSet $wysc     \
      [list grid $wysc -row 0 -column 1 -sticky ns]]  \
      -borderwidth 0 -highlightthickness 0
    
    $T configure -backgroundimage [BackgroundImage]

    bind $T <Button-1>        { ::RosterTree::ButtonPress %x %y }        
    bind $T <ButtonRelease-1> { ::RosterTree::ButtonRelease %x %y }        
    bind $T <Double-1>        { ::RosterTree::DoubleClick %x %y }        
    bind $T <<ButtonPopup>>   { ::RosterTree::Popup %x %y }
    bind $T <Destroy>         {+::RosterTree::OnDestroy }
}

# RosterTree::Free --
# 
#       Free all items, elements, styles, and columns.

proc ::RosterTree::Free {} {
    variable T
    
    $T item delete all
    $T column delete all
    eval {$T style delete} [$T style names]
    eval {$T element delete} [$T element names]
}

proc ::RosterTree::SetBackgroundImage {} {
    
    ConfigBgImage [BackgroundImage]
}

proc ::RosterTree::BackgroundImage {} {
    variable T    
    upvar ::Jabber::jprefs jprefs
        
    set bgimage ""
    
    # Create background image if nonstandard.
    if {$jprefs(rost,useBgImage)} {
	if {[file exists $jprefs(rost,bgImagePath)]} {
	    # @@@ Free any old???
	    if {[catch {
		set bgimage [image create photo -file $jprefs(rost,bgImagePath)]
	    }]} {
		set bgimage ""
	    }
	}

	# Default and fallback..
	if {$bgimage eq ""} {
	    set bgimage [::Theme::GetImage [option get $T rosterImage {}]]
	}
    }
    return $bgimage
}

proc ::RosterTree::ConfigBgImage {image} {
    variable T
    
    $T configure -backgroundimage $image
    
    ::hooks::run rosterTreeConfigure -backgroundimage $image
}

proc ::RosterTree::Selection {} {
    variable T
    
}

proc ::RosterTree::OpenTreeCmd {item} {
    variable T
    
}

proc ::RosterTree::CloseTreeCmd {item} {
    variable T
    
}

proc ::RosterTree::ButtonPress {x y} {
    variable T
    variable buttonAfterId
    variable buttonPressMillis

    if {[tk windowingsystem] eq "aqua"} {
	if {[info exists buttonAfterId]} {
	    catch {after cancel $buttonAfterId}
	}
	set cmd [list ::RosterTree::Popup $x $y]
	set buttonAfterId [after $buttonPressMillis $cmd]
    }
}

proc ::RosterTree::ButtonRelease {x y} {
    variable T
    variable buttonAfterId
    
    if {[info exists buttonAfterId]} {
	catch {after cancel $buttonAfterId}
	unset buttonAfterId
    }    
}

proc ::RosterTree::DoubleClick {x y} {
    variable T
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    # According to XMPP def sect. 4.1, we should use user@domain when
    # initiating a new chat or sending a new message that is not a reply.
    set id [$T identify $x $y]
    if {([lindex $id 0] eq "item") && ([llength $id] == 6)} {
	set item [lindex $id 1]
	set tags [$T item element cget $item cTag eText -text]
	if {[lindex $tags 0] eq "jid"} {
	    set jid [lindex $tags 1]
	    jlib::splitjid $jid jid2 res
	    
	    
	    if {[string equal $jprefs(rost,dblClk) "normal"]} {
		::NewMsg::Build -to $jid2
	    } else {
		if {[$jstate(roster) isavailable $jid]} {
		    
		    # We let Chat handle this internally.
		    ::Chat::StartThread $jid
		} else {
		    ::NewMsg::Build -to $jid2
		}
	    }
	}
    }
}

# RosterTree::Popup --
# 
#       Treectrl binding for popup event.

proc ::RosterTree::Popup {x y} {
    variable T
    upvar ::Jabber::jstate jstate
    
    set tags    {}
    set clicked {}
    set status  {}
    set jid3    {}
    set group   {}

    set id [$T identify $x $y]
    if {[lindex $id 0] eq "item"} {
	set item [lindex $id 1]
	set tags [$T item element cget $item cTag eText -text]
	set ancestors [$T item ancestors $item]
	if {[llength $ancestors] == 1} {
	    set headItem $item
	} else {
	    set headItem [lindex $ancestors end-1]	    
	}
	set headTag [$T item element cget $headItem cTag eText -text]

	# status: 'available', 'unavailable', 'transport', or 'pending'
	set status [lindex $headTag 1]	
    }
    
    # The commands require a number of variables to be defined:
    #       jid, jid3, group, clicked...
    # 
    # These may be lists of jid's if not an individual user was clicked.
    # We use jid3 for the actual content even if only jid2, 
    # and strip off any resource parts for jid (jid2).
    set mtag [lindex $tags 0]
    
    switch -- $mtag {
	jid {
	    lappend clicked user
	    set jid3 [lindex $tags 1]
	    if {[::Roster::IsCoccinella $jid3]} {
		lappend clicked wb
	    }
	}
	group {
	    lappend clicked group
	    set group [lindex $tags 1]
	    set jid3 [FindAllJIDInItem $item]
	}
	head {
	    if {[regexp {(available|unavailable)} [lindex $tags 1]]} {
		lappend clicked head
		set jid3 [FindAllJIDInItem $item]
	    }
	}
	pending {
	    # @@@ empty ???
	    set status unavailable
	}
	transport {
	    lappend clicked trpt
	    set jid3 [lindex $tags 1]
	    # Transports in own directory.
	    if {[$jstate(roster) isavailable $jid3]} {
		set status available
	    } else {
		set status unavailable
	    }
	}
    }
    
    ::Roster::DoPopup $jid3 $clicked $status $group $x $y
}

proc ::RosterTree::FindAllJIDInItem {item} {
    variable T
    
    set jids {}
    foreach citem [$T item children $item] {
	if {[$T item numchildren $citem]} {
	    set jids [concat $jids [FindAllJIDInItem $citem]]
	}
	set tag [$T item element cget $citem cTag eText -text]
	if {[lindex $tag 0] eq "jid"} {
	    lappend jids [lindex $tag 1]
	}
    }
    return $jids
}

# ---------------------------------------------------------------------------- #

# A few more generic functions.
# They isolate the 'tag2items' array from the rest.

namespace eval ::RosterTree {
    
    # Internal array.
    variable tag2items
}

proc ::RosterTree::CreateWithTag {tag parent} {
    variable T
    variable tag2items
    
    set item [$T item create -parent $parent]
    lappend tag2items($tag) $item

    return $item
}

proc ::RosterTree::DeleteWithTag {tag} {
    variable T
    variable tag2items
    
    if {[info exists tag2items($tag)]} {
	foreach item $tag2items($tag) {
    
	    # Delete any actual children recursively using item.
	    foreach child [$T item children $item] {
		DeleteItemAndTag $child
	    }

	    # Delete the actual item(s).
	    $T item delete $item
	}    
	unset tag2items($tag)
    }
}

proc ::RosterTree::DeleteChildrenOfTag {tag} {
    variable T
    variable tag2items

    if {[info exists tag2items($tag)]} {
	foreach item $tag2items($tag) {
    
	    # Delete any actual children recursively using item.
	    foreach child [$T item children $item] {
		DeleteItemAndTag $child
	    }
	}    
    }
}

proc ::RosterTree::DeleteItemAndTag {item} {
    variable T
    variable tag2items
    
    # Call ourselves recursively to delete children as well.
    foreach child [$T item children $item] {
	DeleteItemAndTag $child
    }
    
    # We must delete all 'tag2items' that may point to us.
    set tag [$T item element cget $item cTag eText -text]
    set items $tag2items($tag)
    set idx [lsearch $items $item]
    if {$idx >= 0} {
	set tag2items($tag) [lreplace $items $idx $idx]
    }
    
    # And finally delete ourselves.
    $T item delete $item
}

proc ::RosterTree::FindWithTag {tag} {
    variable tag2items
    
    if {[info exists tag2items($tag)]} {
	return $tag2items($tag)
    } else {
	return {}
    }
}

proc ::RosterTree::FindWithFirstTag {tag0} {
    variable tag2items
    
    set items {}
    foreach {key value} [array get tag2items "$tag0 *"] {
	set items [concat $items $value]
    }
    return $items
}

# RosterTree::FindChildrenOfTag --
# 
#       The caller MUST verify that the tag is actually unique.

proc ::RosterTree::FindChildrenOfTag {tag} {
    variable T
    variable tag2items
    
    # NEVER use the non unique 'jid *' tag here!
    set items {}
    if {[info exists tag2items($tag)]} {
	set pitem [lindex $tag2items($tag) 0]
	set items [$T item children $pitem]
    }
    return $items
}

proc ::RosterTree::GetTagOfItem {item} {
    variable T
    
    return [$T item element cget $item cTag eText -text]
}

proc ::RosterTree::ExistsWithTag {tag} {
    variable tag2items

    return [info exists tag2items($tag)]
}

proc ::RosterTree::FreeTags {} {
    variable tag2items
    
    unset -nocomplain tag2items
}

proc ::RosterTree::OnDestroy {} {

    FreeTags
}

# ---------------------------------------------------------------------------- #

# RosterTree::MakeDisplayText --
# 
#       Make a standard display text.

proc ::RosterTree::MakeDisplayText {jid presence args} {
    upvar ::Jabber::jserver jserver

    array set argsArr $args
    
    # Make display text (itemstr).
    set istrpt [::Roster::IsTransportHeuristics $jid]
    set server $jserver(this)

    if {$istrpt} {
	set str $jid
	if {[info exists argsArr(-show)]} {
	    set sstr [::Roster::MapShowToText $argsArr(-show)]
	    append str " ($sstr)" 
	} elseif {[info exists argsArr(-status)]} {
	    append str " ($argsArr(-status))"
	}
    } else {
	if {[info exists argsArr(-name)] && ($argsArr(-name) ne "")} {
	    set str $argsArr(-name)
	} elseif {[regexp "^(\[^@\]+)@${server}" $jid match user]} {
	    set str $user
	} else {
	    set str $jid
	}
	if {$presence eq "available"} {
	    if {[info exists argsArr(-resource)] && ($argsArr(-resource) ne "")} {
		append str " ($argsArr(-resource))"
	    }
	}
    }
    return $str
}

proc ::RosterTree::Balloon {jid presence item args} {
    variable T    
    upvar ::Jabber::jstate jstate

    array set argsArr $args
    
    # Design the balloon help window message.
    set msg $jid
    if {[info exists argsArr(-show)]} {
	set show $argsArr(-show)
    } else {
	set show $presence
    }
    append msg "\n" [::Roster::MapShowToText $show]

    if {[string equal $presence "available"]} {
	set delay [$jstate(roster) getx $jid "jabber:x:delay"]
	if {$delay != ""} {
	    
	    # An ISO 8601 point-in-time specification. clock works!
	    set stamp [wrapper::getattribute $delay stamp]
	    set tstr [::Utils::SmartClockFormat [clock scan $stamp -gmt 1]]
	    append msg "\n" "Online since: $tstr"
	}
    }
    if {[info exists argsArr(-status)] && ($argsArr(-status) != "")} {
	append msg "\n" $argsArr(-status)
    }
    
    ::balloonhelp::treectrl $T $item $msg
}

# RosterTree::GetClosed --
# 
#       Keep track of all closed tree items. Default is all open.

proc ::RosterTree::GetClosed {} {
    upvar ::Jabber::jprefs jprefs
    
    set jprefs(rost,closedItems) [GetClosedItems root]
}

proc ::RosterTree::GetClosedItems {item} {
    variable T        
    
    set closed {}
    if {[$T item numchildren $item]} {
	if {![$T item isopen $item]} {
	    set tags [$T item element cget $item cTag eText -text]
	    lappend closed $tags
	}
	foreach citem [$T item children $item] {
	    set closed [concat $closed [GetClosedItems $citem]]
	}
    }
    return $closed
}

proc ::RosterTree::GetParent {item} {
    variable T
    
    return [$T item parent $item]
}

proc ::RosterTree::Sort {item {order -increasing}} {
    variable T    
        
    foreach citem [$T item children $item] {
	if {[$T item numchildren $citem]} {
	    Sort $citem $order
	}
    }
    if {$item ne "root"} {
	if {[$T item numchildren $item]} {
	    $T item sort $item $order -column cTree  \
	      -command ::RosterTree::SortCommand
	}
    }
}

proc ::RosterTree::SortCommand {item1 item2} {
    variable T
    
    if {$item1 == $item2} {
	return 0
    }
    set n1 [$T item numchildren $item1]
    set n2 [$T item numchildren $item2]
    if {$n1 && !$n2} {
	set ans -1
    } elseif {!$n1 && $n2} {
	set ans 1
    } else {
	set text1 [$T item text $item1 cTree]
	set text2 [$T item text $item2 cTree]
	set ans [string compare $text1 $text2]
    }
    return $ans
}

proc ::RosterTree::DeleteEmptyGroups {} {
    variable T
    
    foreach item [FindWithFirstTag group] {
	if {[$T item numchildren $item] == 0} {
	    DeleteItemAndTag $item
	}
    }
}

# RosterTree::DeleteEmptyPendTrpt --
# 
#       Cleanup empty pending and transport dirs.

proc ::RosterTree::DeleteEmptyPendTrpt {} {
    variable T

    foreach key {pending transport} {
	set tag [list head $key]
	set item [FindWithTag $tag]
	if {$item ne ""} {
	    if {[$T item numchildren $item] == 0} {
		DeleteWithTag $tag
	    }
	}
    }
}

