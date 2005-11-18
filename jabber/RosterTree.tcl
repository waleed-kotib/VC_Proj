#  RosterTree.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the roster tree using treectrl.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: RosterTree.tcl,v 1.8 2005-11-18 07:52:32 matben Exp $

#-INTERNALS---------------------------------------------------------------------
#
#   We keep an invisible column cTag for tag storage, and an array 'tag2items'
#   that maps a tag to a set of items. 
#   One jid can belong to several groups (bad) which doesn't make {jid $jid}
#   unique!
# 
#   tags:
#     {head available/unavailable/transport/pending}
#     {jid $jid}                      <- not unique if belongs to many groups!
#     {group $group $presence}        <- note
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

    # Head titles.
    variable mcHead
    array set mcHead [list \
      available     [mc Online]         \
      unavailable   [mc Offline]        \
      transport     [mc Transports]     \
      pending       [mc {Subscription Pending}]]
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
    return [eval {$plugin($name,createItem) $jid $presence} $args]
}

proc ::RosterTree::StyleDeleteItem {jid} {
    variable plugin
    
    set name $plugin(selected)
    $plugin($name,deleteItem) $jid
}
    
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

# RosterTree::LoadStyle --
# 
#       Organizes everything to change roster style on the fly.

proc ::RosterTree::LoadStyle {name} {
    variable T
    
    Free
    SetStyle $name
    StyleConfigure $T
    ::Roster::RepopulateTree    
}


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
      -borderwidth 0 -highlightthickness 0            \
      -height 0 -width 0
    
    $T configure -backgroundimage [BackgroundImage]

    bind $T <Button-1>        { ::RosterTree::ButtonPress %x %y }        
    bind $T <ButtonRelease-1> { ::RosterTree::ButtonRelease %x %y }        
    bind $T <Double-1>        { ::RosterTree::DoubleClick %x %y }        
    bind $T <<ButtonPopup>>   { ::RosterTree::Popup %x %y }
    bind $T <Destroy>         {+::RosterTree::OnDestroy }
    
    # This automatically cleans up the tag array.
    $T notify bind RosterTreeTag <ItemDelete> {
	foreach item %i {
	    ::RosterTree::RemoveTags $item
	} 
    }
    bindtags $T [concat RosterTreeTag [bindtags $T]]
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

    #empty
}

proc ::RosterTree::OpenTreeCmd {item} {
    variable T
    
    #empty
}

proc ::RosterTree::CloseTreeCmd {item} {
    variable T
    
    #empty
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

    return [FindAllWithTagInItem $item jid]
}

# RosterTree::FindAllWithTagInItem --
#
#       Gets a list of all jids in item.
#
# Arguments:
#       item        tree item
#       type        jid, transport, pending
#       
# Results:
#       list of jids

proc ::RosterTree::FindAllWithTagInItem {item type} {
    variable T
    
    set jids {}
    foreach citem [$T item children $item] {
	if {[$T item numchildren $citem]} {
	    set jids [concat $jids [FindAllWithTagInItem $citem $type]]
	}
	set tag [$T item element cget $citem cTag eText -text]
	if {[lindex $tag 0] eq $type} {
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
    
    # Handle the hidden cTag column.
    $T item style set $item cTag styTag
    $T item element configure $item cTag eText -text $tag
    
    lappend tag2items($tag) $item

    return $item
}

proc ::RosterTree::DeleteWithTag {tag} {
    variable T
    variable tag2items
    
    if {[info exists tag2items($tag)]} {
	foreach item $tag2items($tag) {
	    $T item delete $item
	}    
    }
}

# RosterTree::RemoveTags --
# 
#       Callback for <ItemDelete> events used to cleanup the tag2items array.

proc ::RosterTree::RemoveTags {item} {
    variable T
    variable tag2items
    
    # We must delete all 'tag2items' that may point to us.
    set tag [$T item element cget $item cTag eText -text]
    set items $tag2items($tag)
    set idx [lsearch $items $item]
    if {$idx >= 0} {
	set tag2items($tag) [lreplace $items $idx $idx]
    }
    if {$tag2items($tag) == {}} {
	unset tag2items($tag)
    }
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

# Support code for roster styles ...

# RosterTree::CreateItemBase --
# 
#       Helper function for roster styles for creating items.
#       It creates the necessary items in the right places but doesn't
#       configure them with styles and elements (except for tag).
#       Online users shall be put with full 3-tier jid.
#       Offline and other are stored with 2-tier jid with no resource.
#       
# Arguments:
#       jid         as reported by the presence
#                   if from roster element any nonempty resource is appended
#       presence    "available" or "unavailable"
#       args        list of '-key value' pairs of presence and roster
#                   attributes.
#       
# Results:
#       a list {item tag ?item tag? ...}

proc ::RosterTree::CreateItemBase {jid presence args} {    
    variable T
    upvar ::Jabber::jstate  jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs  jprefs
    
    ::Debug 4 "::RosterTree::CreateItemBase jid=$jid, presence=$presence, args='$args'"

    if {![regexp $presence {(available|unavailable)}]} {
	return
    }
    if {!$jprefs(rost,showOffline) && ($presence eq "unavailable")} {
	return
    }
    set istrpt [::Roster::IsTransportHeuristics $jid]
    if {$istrpt && !$jprefs(rost,showTrpts)} {
	return
    }
    array set argsArr $args
    set itemTagList {}

    # For Online users, the tree item must be a 3-tier jid with resource 
    # since a user may be logged in from more than one resource.
    # Note that some (icq) transports have 3-tier items that are unavailable!
    
    # jid2 is always without a resource
    # jid3 is as reported
    # jidx is as jid3 if available else jid2
    
    jlib::splitjid $jid jid2 res
    
    set jid3 $jid
    set jidx $jid
    if {$presence eq "available"} {
	set jidx $jid
    } else {
	set jidx $jid2
    }    
    set mjid [jlib::jidmap $jidx]
    
    # Keep track of any dirs created.
    set dirtags {}
	
    if {$istrpt} {
	
	# Transports:
	set itemTagList [CreateItemWithParent $jid3 transport]
	if {[llength $itemTagList] == 4} {
	    lappend dirtags [lindex $itemTagList 1]
	}
    } elseif {[info exists argsArr(-ask)] && ($argsArr(-ask) eq "subscribe")} {
	
	# Pending:
	set itemTagList [CreateItemWithParent $mjid pending]
	if {[llength $itemTagList] == 4} {
	    lappend dirtags [lindex $itemTagList 1]
	}
    } elseif {[info exists argsArr(-groups)] && ($argsArr(-groups) ne "")} {
	
	# Group(s):
	foreach group $argsArr(-groups) {
	    
	    # Make group if not exists already.
	    set ptag [list group $group $presence]
	    set pitem [FindWithTag $ptag]
	    if {$pitem eq ""} {
		set pptag [list head $presence]
		set ppitem [FindWithTag $pptag]
		set pitem [CreateWithTag $ptag $ppitem]
		$T item configure $pitem -button 1
		lappend dirtags $ptag
		lappend itemTagList $pitem $ptag
	    }
	    set tag [list jid $mjid]
	    set item [CreateWithTag $tag $pitem]
	}
	lappend itemTagList $item $tag 
    } else {
	
	# No groups associated with this item.
	set tag  [list jid $mjid]
	set ptag [list head $presence]
	set pitem [FindWithTag $ptag]
	set item [CreateWithTag $tag $pitem]
	lappend itemTagList $item $tag 
    }
    
    # If we created a directory and that is on the closed item list.
    # Default is to have -open.
    foreach dtag $dirtags {
	if {[lsearch $jprefs(rost,closedItems) $dtag] >= 0} {	    
	    set citem [FindWithTag $dtag]
	    $T item collapse $citem
	}
    }
        
    # @@@ wrong if several groups.
    return $itemTagList
}

# RosterTree::CreateItemWithParent --
# 
#       Helper to create items including any missing parent.

proc ::RosterTree::CreateItemWithParent {jid type} {
    variable T
    
    set itemTagList {}
    set ptag [list head $type]
    set pitem [FindWithTag $ptag]
    if {$pitem eq ""} {
	set pitem [CreateWithTag $ptag root]
	$T item configure $pitem -button 1
	lappend itemTagList $pitem $ptag
    }
    set tag [list $type $jid]
    set item [CreateWithTag $tag $pitem]
    lappend itemTagList $item $tag
    
    return $itemTagList
}

# RosterTree::DeleteItemBase --
# 
#       Complement to 'CreateItemBase' above when deleting an item associated
#       with a jid.

proc ::RosterTree::DeleteItemBase {jid} {
    
    ::Debug 2 "::RosterTree::DeleteItemBase, jid=$jid"
    
    # If have 3-tier jid:
    #    presence = 'available'   => remove jid2 + jid3
    #    presence = 'unavailable' => remove jid2 + jid3
    # Else if 2-tier jid:  => remove jid2

    jlib::splitjid $jid jid2 res
    set mjid2 [jlib::jidmap $jid2]
    
    set tag [list jid $mjid2]
    DeleteWithTag $tag
    if {$res ne ""} {
	set mjid3 [jlib::jidmap $jid]
	DeleteWithTag [list jid $mjid3]
    }
    
    # Pending and transports.
    DeleteWithTag [list pending $jid]
    DeleteWithTag [list transport $jid]
}

proc ::RosterTree::MCHead {str} {
    variable mcHead

    return $mcHead($str)
}

# RosterTree::MakeDisplayText --
# 
#       Make a standard display text.

proc ::RosterTree::MakeDisplayText {jid presence args} {
    upvar ::Jabber::jserver jserver

    array set argsArr $args
    
    # Format item:
    #  - If 'name' attribute, use this, else
    #  - if user belongs to login server, use only prefix, else
    #  - show complete 2-tier jid
    # If resource add it within parenthesis '(presence)' but only if Online.
    # 
    # For Online users, the tree item must be a 3-tier jid with resource 
    # since a user may be logged in from more than one resource.
    # Note that some (icq) transports have 3-tier items that are unavailable!

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
	if {$delay ne ""} {
	    
	    # An ISO 8601 point-in-time specification. clock works!
	    set stamp [wrapper::getattribute $delay stamp]
	    set tstr [::Utils::SmartClockFormat [clock scan $stamp -gmt 1]]
	    append msg "\n" "Online since: $tstr"
	}
    }
    if {[info exists argsArr(-status)] && ($argsArr(-status) ne "")} {
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
	    $T item delete $item

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
		$T item delete $item
	    }
	}
    }
}

