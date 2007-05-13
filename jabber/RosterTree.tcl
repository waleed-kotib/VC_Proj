#  RosterTree.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the roster tree using treectrl.
#      
#  Copyright (c) 2005-2007  Mats Bengtsson
#  
# $Id: RosterTree.tcl,v 1.49 2007-05-13 13:36:03 matben Exp $

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

package provide RosterTree 1.0

namespace eval ::RosterTree {

    ::hooks::register logoutHook             ::RosterTree::LogoutHook
    ::hooks::register quitAppHook            ::RosterTree::QuitHook
    ::hooks::register menuJMainEditPostHook  ::RosterTree::EditMenuPostHook

    # Actual:
    option add *RosterTree.borderWidth      1               50
    option add *RosterTree.relief           sunken          50
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

# RosterTree::RegisterStyle --
# 
#       Basic registration function for styles.

proc ::RosterTree::RegisterStyle {
    name 
    label 
    configProc 
    initProc 
    deleteProc
    createItemProc 
    deleteItemProc 
    setItemAltProc
} {
	
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

# RosterTree::RegisterStyleSort --
# 
#       Optional registration of sort proc.

proc ::RosterTree::RegisterStyleSort {name sortProc} {    
    variable plugin
    
    set plugin($name,sortProc) $sortProc
}

# RosterTree::RegisterStyleFindColumn --
# 
#       The generic find megawidget needs to know which column to search.
#       If a style doesn't register it it means no find possible.

proc ::RosterTree::RegisterStyleFindColumn {name findColumn} {    
    variable plugin
    
    set plugin($name,findColumn) $findColumn
}

proc ::RosterTree::GetStyleFindColumn {} {
    variable plugin
    
    set name $plugin(selected)
    if {[info exists plugin($name,findColumn)]} {
	return $plugin($name,findColumn)
    } else {
	return 
    }
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
 
    set names [list]
    foreach {key name} [array get plugin *,name] {
	lappend names $name
    }
    set styles [list]
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
    set items [eval {$plugin($name,createItem) $jid $presence} $args]
    StyleConfigureAltImages $jid
    return $items
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
    SetBinds
    SetStyle $name
    StyleConfigure $T
    ::Roster::RepopulateTree    

    set previous [GetPreviousStyle]
    if {$previous ne ""} {
	StyleDelete $previous
    }
    
    # Guard against a situation where we have no search support.
    if {[GetStyleFindColumn] eq ""} {
	FindDestroy
    } else {
	FindReset
    }
}

# RosterTree::New --
# 
#       Create the treectrl widget and do common initializations.

proc ::RosterTree::New {w} {
    variable T
    variable wfind
    
    # D = -border 1 -relief sunken
    frame $w -class RosterTree

    set wxsc    $w.xsc
    set wysc    $w.ysc
    set wtree   $w.tree
    set wfind   $w.find
    
    set T $wtree
	    
    treectrl $T -usetheme 1 -selectmode extended  \
      -showroot 0 -showrootbutton 0 -showbuttons 1 -showheader 0  \
      -xscrollcommand [list ::UI::ScrollSet $wxsc     \
      [list grid $wxsc -row 1 -column 0 -sticky ew]]  \
      -yscrollcommand [list ::UI::ScrollSet $wysc     \
      [list grid $wysc -row 0 -column 1 -sticky ns]]  \
      -borderwidth 0 -highlightthickness 0            \
      -height 0 -width 0
    
    SetBinds
    $T configure -backgroundimage [BackgroundImage]
    $T notify bind $T <Selection> {+::RosterTree::Selection }
    
    # This automatically cleans up the tag array.
    $T notify bind RosterTreeTag <ItemDelete> {
	foreach item %i {
	    ::RosterTree::RemoveTags $item
	} 
    }
    bindtags $T [concat RosterTreeTag [bindtags $T]]
    
    ::RosterTree::StyleConfigure $wtree
    ::RosterTree::StyleInit

    ttk::scrollbar $wxsc -command [list $wtree xview] -orient horizontal
    ttk::scrollbar $wysc -command [list $wtree yview] -orient vertical

    grid  $wtree  -row 0 -column 0 -sticky news
    grid  $wysc   -row 0 -column 1 -sticky ns
    grid  $wxsc   -row 1 -column 0 -sticky ew
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure    $w 0 -weight 1

    return $T
}

proc ::RosterTree::SetBinds {} {
    variable T

    # We need to do this each time a new style is loaded since all binds
    # have been removed to allow for 'EditSetBinds'.
    bind $T <Button-1>        {+::RosterTree::ButtonPress %x %y }        
    bind $T <ButtonRelease-1> {+::RosterTree::ButtonRelease %x %y }        
    bind $T <Double-1>        {+::RosterTree::DoubleClick %x %y }        
    bind $T <<ButtonPopup>>   {+::RosterTree::Popup %x %y }
    bind $T <Destroy>         {+::RosterTree::OnDestroy }
    bind $T <Key-Return>      {+::RosterTree::OnReturn }
    bind $T <KP_Enter>        {+::RosterTree::OnReturn }
    bind $T <Key-BackSpace>   {+::RosterTree::OnBackSpace }
    bind $T <Button1-Motion>  {+::RosterTree::OnButtonMotion }
}

proc ::RosterTree::DBOptions {rosterStyle} {
    variable T
    
    ::treeutil::setdboptions $T [::Roster::GetRosterWindow] $rosterStyle
}

# RosterTree::Find, FindAgain --
# 
#       This is a generic mechanism for searching a TreeCtrl roster.
#       UI::TSearch shall work for any TreeCtrl widget.

proc ::RosterTree::Find {} {
    variable wfind
    variable T    
    
    if {![winfo exists $wfind]} {
	set column [GetStyleFindColumn]
	if {$column ne ""} {
	    UI::TSearch $wfind $T $column -padding {6 2}
	    grid  $wfind  -column 0 -row 2 -columnspan 2 -sticky ew
	}
    }
}

proc ::RosterTree::FindAgain {dir} {
    variable wfind

    if {[winfo exists $wfind]} {
	$wfind [expr {$dir == 1 ? "Next" : "Previous"}]
    }
}

proc ::RosterTree::FindDestroy {} {
    variable wfind
    destroy $wfind
}

proc ::RosterTree::FindReset {} {
    variable wfind
    if {[winfo exists $wfind]} {
	$wfind Reset
    }
}

# RosterTree::Free --
# 
#       Free all items, elements, styles, and columns. And binds.

proc ::RosterTree::Free {} {
    variable T
    
    $T item delete all
    $T column delete all
    eval {$T style delete} [$T style names]
    eval {$T element delete} [$T element names]
    foreach sequence [bind $T] {
	bind $T $sequence {}
    }
}

# Edit stuff --------------------------

namespace eval ::RosterTree:: {
    
    # @@@ Move to global resource.
    variable waitUntilEditMillis 2000
}

proc ::RosterTree::EditSetBinds {cmd} {
    variable T
    variable editBind
    
    set editBind(cmd) $cmd
    bind $T <Button-1>        {+::RosterTree::EditButtonPress %x %y }        
    bind $T <ButtonRelease-1> {+::RosterTree::EditButtonRelease %x %y }        
    bind $T <Double-1>        {+::RosterTree::EditTimerCancel }        
}

proc ::RosterTree::EditButtonPress {x y} {
    variable T
    variable editTimer
    variable editBind
    
    if {[info exists editTimer(after)]} {
	set id [$T identify $x $y]
	if {$id eq $editTimer(id)} {
	    
	    # The balloonhelp window on Mac takes focus. Stop it.
	    ::balloonhelp::cancel
	    uplevel #0 $editBind(cmd) [list $id]
	}
    }
}

proc ::RosterTree::EditButtonRelease {x y} {
    variable T
    variable editTimer
    variable waitUntilEditMillis

    set id [$T identify $x $y]
    if {([lindex $id 0] eq "item") && ([llength $id] == 6)} {
	set editTimer(id) $id
	set editTimer(after) \
	  [after $waitUntilEditMillis ::RosterTree::EditTimerCancel]
    }
}

proc ::RosterTree::EditOnReturn {jid name} {
    variable T
    upvar ::Jabber::jstate jstate
        
    set jid [$jstate(jlib) roster getrosterjid $jid]
    set groups [$jstate(jlib) roster getgroups $jid]
    $jstate(jlib) roster send_set $jid -name $name -groups $groups
    focus $T
}

proc ::RosterTree::EditEnd {jid} {
    variable T
    upvar ::Jabber::jstate jstate
    
    # Restore item with its original style.
    set jid [$jstate(jlib) roster getrosterjid $jid]
    eval {::Roster::SetItem $jid} [$jstate(jlib) roster getrosteritem $jid]
}

proc ::RosterTree::EditTimerCancel {} {
    variable editTimer

    if {[info exists editTimer(after)]} {
	after cancel $editTimer(after)
    }
    unset -nocomplain editTimer
}

# -------------------------------------

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
    
    set item [$T selection get]
    if {[$T selection count] == 1} {
	set tags [GetTagOfItem $item]
	if {[lindex $tags 0] eq "jid"} {
	    set jid [lindex $tags 1]
	    ActionDoubleClick $jid
	}
    }
}

proc ::RosterTree::OnBackSpace {} {
    variable T

    set item [$T selection get]
    if {[$T selection count] == 1} {
	set tags [GetTagOfItem $item]
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

    ::balloonhelp::cancel

    # According to XMPP def sect. 4.1, we should use user@domain when
    # initiating a new chat or sending a new message that is not a reply.
    set id [$T identify $x $y]
    if {([lindex $id 0] eq "item") && ([llength $id] == 6)} {
	set item [lindex $id 1]
	set tags [GetTagOfItem $item]
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
	if {[$jstate(jlib) roster isavailable $jid]} {
	    
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
	set tags [GetTagOfItem $item]
	lappend selected $tags
    }
    return $selected
}

proc ::RosterTree::GetSelectedJID { } {
    
    set jidL {}
    set tags [GetSelected]
    foreach tag $tags {
	lassign $tag mtag jid
	if {$mtag eq "jid"} {
	    lappend jidL $jid
	}
    }
    return $jidL
}

# RosterTree::Popup --
# 
#       Treectrl binding for popup event.

proc ::RosterTree::Popup {x y} {
    variable T
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::RosterTree::Popup"

    ::balloonhelp::cancel
    
    set tags    [list]
    set clicked [list]
    set status  [list]
    set jidL    [list]
    set group   [list]

    set id [$T identify $x $y]
    if {[lindex $id 0] eq "item"} {
	set item [lindex $id 1]
	set tags [GetTagOfItem $item]
	set mtag [lindex $tags 0]

	switch -- $mtag {
	    XXX-transport {
		set status $mtag
	    }
	    jid {
		set jid [lindex $tags 1]
		if {[$jstate(jlib) roster isavailable $jid]} {
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
	    set jid3 [lindex $tags 1]
	    set jidL [list $jid3]
	    set istrpt [::Roster::IsTransportHeuristics $jid3]
	    if {$istrpt} {
		lappend clicked trpt
	    } else {
		lappend clicked user
	    }
	    if {[::Roster::IsCoccinella $jid3]} {
		lappend clicked wb
	    }
	}
	group {
	    lappend clicked group
	    set group [lindex $tags 1]
	    set jidL [FindAllJIDInItem $item]
	}
	head {
	    if {[regexp {(available|unavailable)} [lindex $tags 1]]} {
		lappend clicked head
		set jidL [FindAllJIDInItem $item]
	    }
	}
	XXX-transport {
	    lappend clicked trpt
	    set jid3 [lindex $tags 1]
	    set jidL [list $jid3]
	    # Transports in own directory.
	    if {[$jstate(jlib) roster isavailable $jid3]} {
		set status available
	    } else {
		set status unavailable
	    }
	}
    }
    
    ::Roster::DoPopup $jidL $clicked $status $group $x $y
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
#       type        jid
#       
# Results:
#       list of jids

proc ::RosterTree::FindAllWithTagInItem {item type} {
    variable T
    
    set jidL [list]
    foreach citem [$T item children $item] {
	if {[$T item numchildren $citem]} {
	    set jidL [concat $jidL [FindAllWithTagInItem $citem $type]]
	}
	set tags [GetTagOfItem $citem]
	if {[lindex $tags 0] eq $type} {
	    lappend jidL [lindex $tags 1]
	}
    }
    return $jidL
}

# ---------------------------------------------------------------------------- #
#
# There are two methods to keep track of mapping tags to items:
#    o Keeping an external array (fastest): "array"
#    o Internal to TreeCtrl: "treectrl"

set rosterTreeTagMethod "array"

if {$rosterTreeTagMethod eq "array"} {
    
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
	    return
	}
    }
    
    proc ::RosterTree::FindWithFirstTag {tag0} {
	variable tag2items
	
	# Note that we don't need escaping here since tag0 is guranteed to be free
	# from any special chars.
	set items [list]
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
	set items [list]
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

# This was an attempt to use the built in tags of treectrl 2.2 but timings
# showed that this code was slower. We keep it here for backup storage.

} else {
    
    # A few generic functions to isolate the tags handlings in treectrl.
    # 
    #       Use tags as {0-tag0 1-tag1 2-tag2 ...} to resolve issues like:
    #       {group jid} and {jid group}. Although "group" isn't likely to be a 
    #       domain name we don't want to depend on it.
    #       In other words, tags are ordered.

    proc ::RosterTree::PrepTags {tags} {
	set n -1
	set tagL [list]
	set tags [treeutil::protect $tags]
	foreach tag $tags {
	    lappend tagL [incr n]-$tag
	}
	return $tagL
    }

    proc ::RosterTree::CreateWithTag {tag parent} {
	variable T
	return [$T item create -parent $parent -tags [PrepTags $tag]]
    }

    proc ::RosterTree::DeleteWithTag {tag} {
	variable T
	
	# This must be failsafe if item not exists.
	foreach item [FindWithTag $tag] {
	    $T item delete $item
	}
    }

    proc ::RosterTree::FindWithTag {tag} {
	variable T
	return [$T item id [list tag [join [PrepTags $tag] " && "]]]
    }

    proc ::RosterTree::FindWithFirstTag {tag0} {
	variable T
	return [$T item id [list tag [treeutil::protect 0-$tag0]]]
    }

    # RosterTree::FindChildrenOfTag --
    # 
    #       The caller MUST verify that the tag is actually unique.

    proc ::RosterTree::FindChildrenOfTag {tag} {
	variable T
	return [$T item children [list tag [join [PrepTags $tag] " && "]]]
    }

    proc ::RosterTree::GetTagOfItem {item} {
	variable T
	
	set tagL [list]
	foreach tag [treeutil::deprotect [$T item cget $item -tags]] {
	    lappend tagL [string range $tag 2 end]
	}
	return $tagL
    }

    proc ::RosterTree::ExistsWithTag {tag} {
	return [llength [FindWithTag $tag]]
    }

    proc ::RosterTree::DbgDumpRoster {} {
	variable T
	
	puts "::RosterTree::DbgDumpRoster:"
	foreach item [$T item id all] {
	    set tags [treeutil::deprotect [$T item cget $item -tags]]
	    puts "\t item=$item, tags=$tags"
	}
    }
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
    upvar ::Jabber::jprefs  jprefs
    
    ::Debug 6 "::RosterTree::CreateItemBase jid=$jid, presence=$presence"

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
    array set argsA $args
    set itemTagL [list]

    set mjid [jlib::jidmap $jid]
    
    # Keep track of any dirs created.
    set dirtags {}
	
    if {$istrpt} {
	
	# Transports:
	set itemTagL [CreateJIDItemWithParent $mjid transport]
	if {[llength $itemTagL] == 4} {
	    lappend dirtags [lindex $itemTagL 1]
	}
    } elseif {[info exists argsA(-ask)] && ($argsA(-ask) eq "subscribe")} {
	
	# Pending:
	set itemTagL [CreateJIDItemWithParent $mjid pending]
	if {[llength $itemTagL] == 4} {
	    lappend dirtags [lindex $itemTagL 1]
	}
    } elseif {[info exists argsA(-groups)] && [llength $argsA(-groups)]} {
	
	# Group(s):
	foreach group $argsA(-groups) {
	    
	    # Make group if not exists already.
	    set ptag [list group $group $presence]
	    set pitem [FindWithTag $ptag]
	    if {$pitem eq ""} {
		set pptag [list head $presence]
		set ppitem [FindWithTag $pptag]
		set pitem [CreateWithTag $ptag $ppitem]
		$T item configure $pitem -button 1
		lappend dirtags $ptag
		lappend itemTagL $pitem $ptag
	    }
	    set tag [list jid $mjid]
	    set item [CreateWithTag $tag $pitem]
	}
	lappend itemTagL $item $tag 
    } else {
	
	# No groups associated with this item.
	set tag  [list jid $mjid]
	set ptag [list head $presence]
	set pitem [FindWithTag $ptag]
	set item [CreateWithTag $tag $pitem]
	lappend itemTagL $item $tag 
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
    return $itemTagL
}

# RosterTree::CreateJIDItemWithParent --
# 
#       Helper to create a jid item including any missing parent.
#       No styles are associated with items. Do not use this alone.
#       
#       item tag list {item tag ?item tag?}

proc ::RosterTree::CreateJIDItemWithParent {jid type} {
    variable T
    
    set itemTagL [list]
    set ptag [list head $type]
    set pitem [FindWithTag $ptag]
    if {$pitem eq ""} {
	set pitem [CreateWithTag $ptag root]
	$T item configure $pitem -button 1
	lappend itemTagL $pitem $ptag
    }
    set tag [list jid $jid]
    set item [CreateWithTag $tag $pitem]
    lappend itemTagL $item $tag
    
    return $itemTagL
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
    upvar ::Jabber::jstate jstate
	
    # Investigate all roster items that are in any way related to the discoe'd
    # item. We'll get the roster JIDs, usually bare JID.
    set jidL [::Roster::GetUsersWithSameHost $from]
    
    foreach jid $jidL {
	
	# Ordinary users and so far unrecognized transports.
	set istrpt [::Roster::IsTransportHeuristics $jid]
	set icon [::Roster::GetPresenceIconFromJid $jid]
	set tag [list jid $jid]	
	
	if {$istrpt} {
	    	    
	    # If we find a transport not in {head transport} move it.
	    # Delete it and put it back using generic method to get all set.
	    foreach item [FindWithTag $tag] {
		#if {[GetItemsHeadClass $item] ne "transport"}
		if {![HasItemAncestorWithTag $item [list head transport]]} {
		    set jlib $jstate(jlib)
		    DeleteWithTag $tag
		    eval {::Roster::SetItem $jid} [$jlib roster getrosteritem $jid]
		    break
		}
	    }
	}
	
	# Set icons for transports and users from this transport.
	if {$icon ne ""} {
	    foreach item [FindWithTag $tag] {
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
    upvar ::Jabber::jstate jstate

    array set argsA $args
    
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
    set server $jstate(server)

    if {$istrpt} {
	set str $jid
	if {[info exists argsA(-show)]} {
	    set sstr [::Roster::MapShowToText $argsA(-show)]
	    append str " ($sstr)" 
	} elseif {[info exists argsA(-status)]} {
	    append str " ($argsA(-status))"
	}
    } else {
	if {[info exists argsA(-name)] && ($argsA(-name) ne "")} {
	    set str $argsA(-name)
	} else {
	    jlib::splitjidex $jid node domain res
	    if {$domain eq $jstate(server)} {
		set str $node
	    } else {
		set str [jlib::barejid $jid]
	    }
	}
	if {$presence eq "available"} {
	    if {[info exists argsA(-resource)] && ($argsA(-resource) ne "")} {

		# Configurable?
		#append str " ($argsA(-resource))"
	    }
	}
    }
    return $str
}

# RosterTree::Balloon --
# 
#       jid:        as reported in xml

proc ::RosterTree::Balloon {jid presence item args} {
    variable T    
    variable balloon
    upvar ::Jabber::jstate jstate

    array set argsA $args
    
    set mjid [jlib::jidmap $jid]

    # Design the balloon help window message.
    set msg $jid
    if {[info exists argsA(-show)]} {
	set show $argsA(-show)
    } else {
	set show $presence
    }
    append msg "\n" [::Roster::MapShowToText $show]

    if {[string equal $presence "available"]} {
	set delay [$jstate(jlib) roster getx $jid "jabber:x:delay"]
	if {$delay ne ""} {
	    
	    # An ISO 8601 point-in-time specification. clock works!
	    set stamp [wrapper::getattribute $delay stamp]
	    set tstr [::Utils::SmartClockFormat [clock scan $stamp -gmt 1]]
	    append msg "\n" "Online since: $tstr"
	}
    }
    if {[info exists argsA(-status)] && ($argsA(-status) ne "")} {
	append msg "\n" $argsA(-status)
    }
    
    # Append any registered balloon messages. Both bare and full JIDs.
    if {[array exists balloon]} {
	set bnames [array names balloon *,[jlib::ESC $mjid]]
	if {[jlib::isfulljid $mjid]} {
	    set xnames [array names balloon *,[jlib::ESC [jlib::barejid $mjid]]]
	    set bnames [concat $bnames $xnames]
	}
	foreach key [lsort $bnames] {
	    append msg "\n" $balloon($key)
	}
    }
    
    ::balloonhelp::treectrl $T $item $msg
    
    ::hooks::run rosterBalloonhelp $T $item $jid
}

# RosterTree::BalloonRegister --
# 
#       @@@ Better place is in ::Roster

proc ::RosterTree::BalloonRegister {key jid msg} {
    variable balloon
    upvar ::Jabber::jstate jstate
    
    set mjid [jlib::jidmap $jid]
    if {$msg eq ""} {
	unset -nocomplain balloon($key,$mjid)
    } else {
	set balloon($key,$mjid) $msg
    }
    BalloonSetForJID $jid
}

# RosterTree::BalloonSetForJID --
# 
#       jid:    bare or full JID; if bare set for all full JIDs

proc ::RosterTree::BalloonSetForJID {jid} {
    upvar ::Jabber::jstate jstate
    
    jlib::splitjid $jid jid2 res
    if {[jlib::isfulljid $jid]} {
	array set presA [$jstate(jlib) roster getpresence $jid2 -resource $res]
	
	set tag [list jid $jid]
	foreach item [FindWithTag $tag] {
	    #puts "\t item=$item"
	    eval {Balloon $jid $presA(-type) $item} [array get presA]
	}
    } else {
	set presL [$jstate(jlib) roster getpresence $jid2]
	#puts "presL=$presL"
	foreach p $presL {
	    array unset presA
	    array set presA $p
	    if {$presA(-type) eq "available" && $presA(-resource) ne ""} {
		set pjid $jid2/$presA(-resource)
	    } else {
		set pjid $jid	    
	    }
	    set tag [list jid $pjid]
	    foreach item [FindWithTag $tag] {
		#puts "\t item=$item"
		eval {Balloon $pjid $presA(-type) $item} [array get presA]
	    }
	}
    }
}

proc ::RosterTree::LogoutHook {} {
    variable balloon

    unset -nocomplain balloon 
}

proc ::RosterTree::QuitHook { } {
    variable T        
    
    if {[info exists T] && [winfo exists $T]} {
	GetClosed
    }
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
	    set tags [GetTagOfItem $item]
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

# RosterTree::GetItemsHeadClass --
# 
#       Method to get an items head tag or class.
#       This relies on that it exists a head item where transports etc. are put.

proc ::RosterTree::GetItemsHeadClass {item} {
    variable T
    
    set ancestors [$T item ancestors $item]
    if {[llength $ancestors] >= 2} {
	set head [lindex $ancestors end-1]
	return [lindex [GetTagOfItem $head] 1]
    } else {
	return ""
    }
}

# RosterTree::HasItemAncestorWithTag --
# 
#       Searches its ancestors for an item with given tag.
#       Smarter than 'GetItemsHeadClass'?

proc ::RosterTree::HasItemAncestorWithTag {item tag} {
    variable T
    
    set aitem [FindWithTag $tag]
    if {$aitem ne ""} {
	return [$T item isancestor $item $aitem]
    } else {
	return 0
    }
}

# RosterTree::SortAtIdle --
# 
#       Doing 'after idle' is not perfect since it is executed after the 
#       items have been drawn.

proc ::RosterTree::SortAtIdle {item {order -increasing}} {
    variable sortID
    
    if {![info exists sortID($item)]} {
	
	# If we get a request to sort 'root' then cancel all other idle sorts.
	if {($item eq "root") || ($item == 0)} {
	    foreach id [array names sortID] {
		after cancel $id
	    }
	}
	set sortID($item) [after idle [namespace current]::SortIdle $item $order]
    }
}

proc ::RosterTree::SortIdle {item order} {
    variable T    
    variable sortID
    
    unset -nocomplain sortID($item)
    if {[$T item id $item] ne ""} {
	Sort $item $order
    }
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
    
    # Sort recursively for each directory.
    foreach citem [$T item children $item] {
	if {[$T item numchildren $citem]} {
	    SortDefault $citem $order
	}
    }
    
    # Do not sort the first children of root!
    if {($item ne "root") && ($item != 0)} {
	
	# TreeCtrl 2.2.3 has a problem doing custom sorting (-command)
	# for large rosters, see:
	#   [ 1706359 ] custom sorting can be extremly slow
	#   at tktreectrl.sf.net
	set n [$T item numchildren $item]
	if {$n} {
	    if {$n > 50} {
		$T item sort $item $order -column cTree -dictionary
	    } else {
		$T item sort $item $order -column cTree  \
		  -command ::RosterTree::SortCommand
	    }
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
	set ans [string compare -nocase $text1 $text2]
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

# JUI::EditMenuPostHook --
# 
#       Menu post command hook for doing roster/disco searches.

proc ::RosterTree::EditMenuPostHook {wmenu} {
    variable T
    variable wfind
    
    if {[winfo ismapped $T] && [string length [GetStyleFindColumn]]} {
	::UI::MenuMethod $wmenu entryconfigure mFind -state normal
	if {[winfo exists $wfind]} {
	    ::UI::MenuMethod $wmenu entryconfigure mFindAgain -state normal
	    ::UI::MenuMethod $wmenu entryconfigure mFindPrevious -state normal
	}
    }
}

