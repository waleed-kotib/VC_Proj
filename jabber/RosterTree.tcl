#  RosterTree.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the roster tree using treectrl.
#      
#  Copyright (c) 2005-2006  Mats Bengtsson
#  
# $Id: RosterTree.tcl,v 1.26 2006-08-02 07:04:13 matben Exp $

#-INTERNALS---------------------------------------------------------------------
#
#   We keep an invisible column cTag for tag storage, and an array 'tag2items'
#   that maps a tag to a set of items. 
#   One jid can belong to several groups (bad) which doesn't make {jid $jid}
#   unique!
#   Always use mapped JIDs.
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

    # @@@ Should get this from a global reaource.
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

    set plugin(selected) "plain"
    set plugin(previous) ""

    ::PrefUtils::Add [list  \
      [list ::RosterTree::plugin(selected)  rosterTree_selected  $plugin(selected)]]
}

proc ::RosterTree::RegisterStyle {
    name label configProc initProc deleteProc
    createItemProc deleteItemProc setItemAltProc} {
	
    variable plugin
    
    set plugin($name,name)        $name
    set plugin($name,label)       $label
    set plugin($name,config)      $configProc
    set plugin($name,init)        $initProc
    set plugin($name,delete)      $deleteProc
    set plugin($name,createItem)  $createItemProc
    set plugin($name,deleteItem)  $deleteItemProc
    set plugin($name,setItemAlt)  $setItemAltProc
}

proc ::RosterTree::RegisterStyleSort {name sortProc} {    
    variable plugin
    
    set plugin($name,sortProc) $sortProc
}

proc ::RosterTree::SetStyle {name} {
    variable plugin

    set plugin(previous) $plugin(selected)
    set plugin(selected) $name
}

proc ::RosterTree::GetStyle {} {
    variable plugin
    
    return $plugin(selected)
}

proc ::RosterTree::GetPreviousStyle {} {
    variable plugin
    
    return $plugin(previous)
}

proc ::RosterTree::GetAllStyles {} {
    variable plugin
 
    set names {}
    foreach {key name} [array get plugin *,name] {
	lappend names $name
    }
    set styles {}
    foreach name [lsort $names] {
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

proc ::RosterTree::StyleDelete {name} {
    variable plugin
    
    $plugin($name,delete)
}

# RosterTree::StyleCreateItem --
# 
#       Dispatch tree item creation and configure any alternatives.
# 
# Arguments:
#       jid         for available JID always use the JID as reported in the
#                   presence 'from' attribute.
#                   for unavailable JID always us the roster item JID.
#       presence    "available" or "unavailable"
#       args        list of '-key value' pairs of presence and roster
#                   attributes.
#       
# Results:
#       treectrl item.

proc ::RosterTree::StyleCreateItem {jid presence args} {
    variable plugin
    
    set name $plugin(selected)
    set ans [eval {$plugin($name,createItem) $jid $presence} $args]
    StyleConfigureAltImages $jid
    return $ans
}

proc ::RosterTree::StyleDeleteItem {jid} {
    variable plugin
    
    set name $plugin(selected)
    $plugin($name,deleteItem) $jid
}

# RosterTree::StyleSetItemAlternative --
# 
#       Sets an alternative image or text for the specified jid.
#       An alternative attribute set here is only a hint to the roster style
#       which is free to ignore it.
#       
# Arguments:
#       jid
#       key         a unique token that specifies a set of images or texts
#       type        text or image
#       value       the text or the image to set, or empty if unset
#       
# Results:
#       list {treeCtrlWidget item columnTag elementName}

proc ::RosterTree::StyleSetItemAlternative {jid key type value} {
    variable plugin
    
    switch -- $type {
	image {
	    StyleCacheAltImage $jid $key $value
	}
    }
    set name $plugin(selected)
    return [$plugin($name,setItemAlt) $jid $key $type $value]
}

proc ::RosterTree::StyleCacheAltImage {jid key value} {
    variable altImageCache

    # We must cache this info: jid -> {key value ...}
    # @@@ When to free this cache? Logout? Unavailable?
    if {[info exists altImageCache($jid)]} {
	array set tmp $altImageCache($jid)
	if {$value eq ""} {
	    array unset tmp $key
	    if {[array size tmp]} {
		set altImageCache($jid) [array get tmp]
	    } else {
		unset altImageCache($jid)
	    }
	} else {
	    set tmp($key) $value
	    set altImageCache($jid) [array get tmp]
	}
    } else {
	set altImageCache($jid) [list $key $value]
    }
}

proc ::RosterTree::StyleConfigureAltImages {jid} {
    variable plugin
    variable altImageCache
    
    if {[info exists altImageCache($jid)]} {
	set name $plugin(selected)
	foreach {key value} $altImageCache($jid) {
	     $plugin($name,setItemAlt) $jid $key image $value
	}
    }
}

proc ::RosterTree::GetItemAlternatives {jid type} {
    variable altImageCache
    
    switch -- $type {
	image {
	    if {[info exists altImageCache($jid)]} {
		return $altImageCache($jid)
	    } else {
		return {}
	    }
	}
    }
}

# Assumes that alternatives only for online users.

proc ::RosterTree::FreeItemAlternatives {jid} {
    variable altImageCache

    unset -nocomplain altImageCache($jid)
}

proc ::RosterTree::FreeAllAltImagesCache {} {
    variable altImageCache
    
    unset -nocomplain altImageCache
}

# Debug stuff:
if {0} {
    ::RosterTree::StyleSetItemAlternative mari@localhost phone image [::Rosticons::Get phone/available]
    ::RosterTree::StyleSetItemAlternative mari@localhost xxxxx image [::Rosticons::Get phone/on_phone]
    ::RosterTree::StyleSetItemAlternative killer@localhost phone image [::Rosticons::Get phone/on_phone]
    parray ::RosterTree::altImageCache
    parray ::RosterPlain::altImageKeyToElem
    parray ::RosterAvatar::altImageKeyToElem
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

    set previous [GetPreviousStyle]
    if {$previous ne ""} {
	StyleDelete $previous
    }
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
    bind $T <Key-Return>      { ::RosterTree::OnReturn }
    bind $T <KP_Enter>        { ::RosterTree::OnReturn }
    bind $T <Key-BackSpace>   { ::RosterTree::OnBackSpace }
    bind $T <Button1-Motion>  { ::RosterTree::OnButtonMotion }

    $T notify bind $T <Selection> {+::RosterTree::Selection }
    
    # This automatically cleans up the tag array.
    $T notify bind RosterTreeTag <ItemDelete> {
	foreach item %i {
	    ::RosterTree::RemoveTags $item
	} 
    }
    bindtags $T [concat RosterTreeTag [bindtags $T]]
}

proc ::RosterTree::DBOptions {rosterStyle} {
    variable T
    
    ::treeutil::setdboptions $T [::Roster::GetRosterWindow] $rosterStyle
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

    ::hooks::run rosterTreeSelectionHook
}

proc ::RosterTree::OpenTreeCmd {item} {
    variable T
    
    #empty
}

proc ::RosterTree::CloseTreeCmd {item} {
    variable T
    
    #empty
}

proc ::RosterTree::OnReturn {} {
    variable T
    
    set id [$T selection get]
    if {[$T selection count] == 1} {
	set tags [$T item element cget $id cTag eText -text]
	if {[lindex $tags 0] eq "jid"} {
	    set jid [lindex $tags 1]
	    ActionDoubleClick $jid
	}
    }
}

proc ::RosterTree::OnBackSpace {} {
    variable T

    set id [$T selection get]
    if {[$T selection count] == 1} {
	set tags [$T item element cget $id cTag eText -text]
	if {[lindex $tags 0] eq "jid"} {
	    set jid [lindex $tags 1]
	    set jid2 [jlib::barejid $jid]
	    ::Roster::SendRemove $jid2
	}
    }
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
    set id [$T identify $x $y]
    if {$id eq ""} {
	$T selection clear all
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

    # According to XMPP def sect. 4.1, we should use user@domain when
    # initiating a new chat or sending a new message that is not a reply.
    set id [$T identify $x $y]
    if {([lindex $id 0] eq "item") && ([llength $id] == 6)} {
	set item [lindex $id 1]
	set tags [$T item element cget $item cTag eText -text]
	if {[lindex $tags 0] eq "jid"} {
	    set jid [lindex $tags 1]
	    ActionDoubleClick $jid
	}
    }
}

proc ::RosterTree::ActionDoubleClick {jid} {
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    set jid2 [jlib::barejid $jid]
	    
    if {[string equal $jprefs(rost,dblClk) "normal"]} {
	::NewMsg::Build -to $jid2
    } elseif {[string equal $jprefs(rost,dblClk) "chat"]} {
	if {[$jstate(roster) isavailable $jid]} {
	    
	    # We let Chat handle this internally.
	    ::Chat::StartThread $jid
	} else {
	    ::NewMsg::Build -to $jid2
	}
    }
}

proc ::RosterTree::OnButtonMotion { } {
    variable buttonAfterId
    
    if {[info exists buttonAfterId]} {
	catch {after cancel $buttonAfterId}
	unset buttonAfterId
    }    
}

proc ::RosterTree::GetSelected { } {
    variable T
    
    set selected {}
    foreach item [$T selection get] {
	set tag [$T item element cget $item cTag eText -text]
	lappend selected $tag
    }
    return $selected
}

# RosterTree::Popup --
# 
#       Treectrl binding for popup event.

proc ::RosterTree::Popup {x y} {
    variable T
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::RosterTree::Popup"
    
    set tags    {}
    set clicked {}
    set status  {}
    set jidlist {}
    set group   {}

    set id [$T identify $x $y]
    if {[lindex $id 0] eq "item"} {
	set item [lindex $id 1]
	set tags [$T item element cget $item cTag eText -text]
	set mtag [lindex $tags 0]

	switch -- $mtag {
	    pending - transport {
		set status $mtag
	    }
	    jid {
		set jid [lindex $tags 1]
		if {[$jstate(roster) isavailable $jid]} {
		    set status available
		} else {
		    set status unavailable
		}
	    }
	}
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
	    set jidlist [list $jid3]
	    if {[::Roster::IsCoccinella $jid3]} {
		lappend clicked wb
	    }
	}
	group {
	    lappend clicked group
	    set group [lindex $tags 1]
	    set jidlist [FindAllJIDInItem $item]
	}
	head {
	    if {[regexp {(available|unavailable)} [lindex $tags 1]]} {
		lappend clicked head
		set jidlist [FindAllJIDInItem $item]
	    }
	}
	pending {
	    # @@@ empty ???
	    set status unavailable
	    lappend clicked user
	    set jid3 [lindex $tags 1]
	    set jidlist [list $jid3]
	}
	transport {
	    lappend clicked trpt
	    set jid3 [lindex $tags 1]
	    set jidlist [list $jid3]
	    # Transports in own directory.
	    if {[$jstate(roster) isavailable $jid3]} {
		set status available
	    } else {
		set status unavailable
	    }
	}
    }
    
    ::Roster::DoPopup $jidlist $clicked $status $group $x $y
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
    if {$tag2items($tag) eq {}} {
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
#       jid         for available JID always use the JID as reported in the
#                   presence 'from' attribute.
#                   for unavailable JID always us the roster item JID.
#
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

    if {($presence ne "available") && ($presence ne "unavailable")} {
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

    set mjid [jlib::jidmap $jid]
    
    # Keep track of any dirs created.
    set dirtags {}
	
    if {$istrpt} {
	
	# Transports:
	set itemTagList [CreateItemWithParent $mjid transport]
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
        
    # If have 3-tier jid:
    #    presence = 'available'   => remove jid2 + jid3
    #    presence = 'unavailable' => remove jid2 + jid3
    # Else if 2-tier jid:  => remove jid2
    
    set mjid3 [jlib::jidmap $jid]
    jlib::splitjid $mjid3 mjid2 res
    
    set tag [list jid $mjid2]
    DeleteWithTag $tag
    if {$res ne ""} {
	DeleteWithTag [list jid $mjid3]
    }
    
    # Pending and transports.
    DeleteWithTag [list pending $mjid3]
    DeleteWithTag [list transport $mjid3]
}

# RosterTree::BasePostProcessDiscoInfo --
# 
#       Disco info post processing must handle two sets of JID:
#         1) transports: 
#             - move to transport folder if not there
#             - set associated icon
#         2) users from this transport:
#             - set associated icon
#       
#       Note that the 'from', disco item, may differ by a resource to the
#       roster item JID.

proc ::RosterTree::BasePostProcessDiscoInfo {from column elem} {
    variable T
	
    set jids [::Roster::GetUsersWithSameHost $from]

    foreach jid $jids {
	
	# Ordinary users and so far unrecognized transports.
	set istrpt [::Roster::IsTransportHeuristics $jid]
	set icon [::Roster::GetPresenceIconFromJid $jid]

	set tag [list jid $jid]
	foreach item [FindWithTag $tag] {
	    
	    # Need to identify any associated transport and place it
	    # in the transport if not there.
	    if {$istrpt} {
		
		# It was placed among the users, move to transports.
		$T item delete $item
		CreateItemFromJID $jid
	    } else {
		if {$icon ne ""} {
		    $T item element configure $item $column $elem -image $icon
		}
	    }
	}
	
	# Set icons for already recognized transports.
	set tag [list transport $jid]
	foreach item [FindWithTag $tag] {
	    if {$icon ne ""} {
		$T item element configure $item $column $elem -image $icon
	    }
	}
    }
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

		# Configurable?
		#append str " ($argsArr(-resource))"
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
    
    ::hooks::run rosterBalloonhelp $T $item $jid
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
	if {![$T item isopen $item] && [$T item compare root != $item]} {
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
    variable plugin

    set name $plugin(selected)
    if {[info exists plugin($name,sortProc)]} {
	$plugin($name,sortProc) $item $order
    } else {
	SortDefault $item $order
    }
}

proc ::RosterTree::SortDefault {item order} {
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

