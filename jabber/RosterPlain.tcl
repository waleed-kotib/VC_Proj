#  RosterPlain.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements a plain style roster tree using treectrl.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: RosterPlain.tcl,v 1.10 2005-12-17 09:48:41 matben Exp $

#   This file also acts as a template for other style implementations.
#   Requirements:
#       1) there must be a cTree column which makes up the tree part;
#          the first text element in cTree is used for sorting
#       2) there must be an invisible cTag column    
#       3) the tags must be consistent, see RosterTree
#       
#   A "roster style" handles all item creation and deletion, and is responsible
#   for handling groups, pending, and transport folders.
#   It is also responsible for setting icons for foreign im systems, identifying
#   coccinellas etc.

package require RosterTree

package provide RosterPlain 1.0

namespace eval ::RosterPlain {
        
    variable rosterStyle "plain"

    # Register this style.
    ::RosterTree::RegisterStyle plain Plain   \
      ::RosterPlain::Configure   \
      ::RosterPlain::Init        \
      ::RosterPlain::Delete      \
      ::RosterPlain::CreateItem  \
      ::RosterPlain::DeleteItem  \
      ::RosterPlain::SetItemAlternative
    
    # This is the basic style used as fallback.
    ::RosterTree::SetStyle plain
    
    # Only if this style is in use!!!
    # These are needed to handle foreign IM systems.
    ::hooks::register  browseSetHook        ::RosterPlain::BrowseSetHook
    ::hooks::register  discoInfoHook        ::RosterPlain::DiscoInfoHook
    ::hooks::register  rosterTreeConfigure  ::RosterPlain::TreeConfigureHook

    variable initedDB 0
}

proc ::RosterPlain::InitDB { } {
    global this
    variable initedDB

    # Use option database for customization. 
    # We use a specific format: 
    #   element options:    rosterStyle:elementName-option
    #   style options:      rosterStyle:styleName:elementName-option

    set fillT {white {selected focus} black {selected !focus}}
    set fillB [list $this(sysHighlight) {selected focus} gray {selected !focus}]

    # Element options:
    option add *Roster.plain:eText-fill               $fillT            widgetDefault
    option add *Roster.plain:eNumText-fill            blue              widgetDefault
    option add *Roster.plain:eBorder-outline          white             widgetDefault
    option add *Roster.plain:eBorder-outlinewidth     1                 widgetDefault
    option add *Roster.plain:eBorder-fill             $fillB            widgetDefault

    # If no background image:
    option add *Roster.plain:eBorder-outline:nbg      gray              widgetDefault
    option add *Roster.plain:eBorder-outlinewidth:nbg 0                 widgetDefault
    
    # Style layout options:
    option add *Roster.plain:styHead:eText-padx       2                 widgetDefault
    option add *Roster.plain:styHead:eNumText-padx    4                 widgetDefault
    option add *Roster.plain:styHead:eImage-padx      2                 widgetDefault
    option add *Roster.plain:styHead:eImage-pady      {1 2}             widgetDefault

    option add *Roster.plain:styFolder:eText-padx     2                 widgetDefault
    option add *Roster.plain:styFolder:eNumText-padx  4                 widgetDefault
    option add *Roster.plain:styFolder:eImage-padx    2                 widgetDefault
    option add *Roster.plain:styFolder:eImage-pady    {1 2}             widgetDefault
    
    option add *Roster.plain:styAvailable:eText-padx     2              widgetDefault
    option add *Roster.plain:styAvailable:eImage-pady    {1 2}          widgetDefault
    option add *Roster.plain:styAvailable:eAltImage-padx 2              widgetDefault

    option add *Roster.plain:styUnavailable:eText-padx     2            widgetDefault
    option add *Roster.plain:styUnavailable:eImage-pady    {1 2}        widgetDefault
    option add *Roster.plain:styUnavailable:eAltImage-padx 2            widgetDefault

    option add *Roster.plain:styTransport:eText-padx       4            widgetDefault
    option add *Roster.plain:styTransport:eImage-pady      {1 2}        widgetDefault

    set initedDB 1
}

# RosterPlain::Configure --
# 
#       Create columns, elements and styles for treectrl.

proc ::RosterPlain::Configure {_T} {
    global  this
    variable T
    variable initedDB
    variable rosterStyle
    
    set T $_T
    
    if {!$initedDB} {
	InitDB
    }

    # This is a dummy option.
    set stripeBackground [option get $T stripeBackground {}]
    set stripes [list $stripeBackground {}]
    set outline white
    if {[$T cget -backgroundimage] eq ""} {
	set outline gray
    }
    set minH 17
    
    # One pixel from the top border line and two pixels below since border
    # is drawn inside.
    set ipy {1 2}

    # Two columns: 
    #   0) the tree 
    #   1) hidden for tags
    $T column create -tag cTree -itembackground $stripes -resize 0 -expand 1
    $T column create -tag cTag -visible 0
    $T configure -treecolumn cTree -showheader 0

    # The elements.
    set fill [list $this(sysHighlight) {selected focus} gray {selected !focus}]
    $T element create eImage image
    $T element create eAltImage image
    $T element create eText text -lines 1
    $T element create eNumText text -lines 1
    $T element create eBorder rect -open new -showfocus 1
 
    # Styles collecting the elements.
    set S [$T style create styHead]
    $T style elements $S {eBorder eImage eText eNumText}
    $T style layout $S eText    -squeeze x -expand ns
    $T style layout $S eNumText -expand ns
    $T style layout $S eImage   -expand ns -minheight $minH
    $T style layout $S eBorder  -detach 1 -iexpand xy -indent 0

    set S [$T style create styFolder]
    $T style elements $S {eBorder eImage eText eNumText}
    $T style layout $S eText    -squeeze x -expand ns
    $T style layout $S eNumText -expand ns
    $T style layout $S eImage   -expand ns -minheight $minH
    $T style layout $S eBorder  -detach 1 -iexpand xy -indent 0

    set S [$T style create styAvailable]
    $T style elements $S {eBorder eImage eAltImage eText}
    $T style layout $S eText     -squeeze x -expand ns
    $T style layout $S eImage    -expand ns -minheight $minH
    $T style layout $S eAltImage -expand ns
    $T style layout $S eBorder   -detach 1 -iexpand xy -indent 0

    set S [$T style create styUnavailable]
    $T style elements $S {eBorder eImage eAltImage eText}
    $T style layout $S eText     -squeeze x -expand ns
    $T style layout $S eImage    -expand ns -minheight $minH
    $T style layout $S eAltImage -expand ns
    $T style layout $S eBorder   -detach 1 -iexpand xy -indent 0

    set S [$T style create styTransport]
    $T style elements $S {eBorder eImage eText}
    $T style layout $S eText  -squeeze x -expand ns
    $T style layout $S eImage -expand ns -minheight $minH
    $T style layout $S eBorder -detach 1 -iexpand xy -indent 0

    set S [$T style create styTag]
    $T style elements $S {eText}

    $T notify bind $T <Selection>      { ::RosterTree::Selection }
    $T notify bind $T <Expand-after>   { ::RosterTree::OpenTreeCmd %I }
    $T notify bind $T <Collapse-after> { ::RosterTree::CloseTreeCmd %I }

    ::RosterTree::DBOptions $rosterStyle
}

# RosterPlain::Init --
# 
#       Creates the items for the initial logged out state.
#       It starts by removing all content.

proc ::RosterPlain::Init { } {
    variable T
    upvar ::Jabber::jprefs jprefs
    
    $T item delete all
    ::RosterTree::FreeTags
    
    set onlineImage  [::Rosticons::Get application/online]
    set offlineImage [::Rosticons::Get application/offline]
    
    # Available:
    set tag [list head available]
    set text [::RosterTree::MCHead available]
    set item [CreateWithTag $tag styHead $text $onlineImage root]
    if {$jprefs(rost,showOffline)} {
	$T item configure $item -button 1
    }
    if {[lsearch $jprefs(rost,closedItems) $tag] >= 0} {
	$T item collapse $item
    }
    
    # Unavailable:
    if {$jprefs(rost,showOffline)} {
	set tag [list head unavailable]
	set text [::RosterTree::MCHead unavailable]
	set item [CreateWithTag $tag styHead $text $offlineImage root]
	$T item configure $item -button 1
	if {[lsearch $jprefs(rost,closedItems) $tag] >= 0} {
	    $T item collapse $item
	}
    }
}

proc ::RosterPlain::Delete { } { }

# RosterPlain::CreateItem --
#
#       Uses 'CreateItemBase' to get a list of items with tags and then 
#       configures each of them according to our style.
#
# Arguments:
#       jid         as reported by the presence
#                   if from roster element any nonempty resource is appended
#       presence    "available" or "unavailable"
#       args        list of '-key value' pairs of presence and roster
#                   attributes.
#       
# Results:
#       treectrl item.

proc ::RosterPlain::CreateItem {jid presence args} {    
    variable T

    array set styleMap {
	available    styAvailable 
	unavailable  styUnavailable
    }

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
    
    # Defaults:
    set jtext  [eval {MakeDisplayText $jid $presence} $args]
    set jimage [eval {GetPresenceIcon $jidx $presence} $args]
    set items  {}
    set jitems {}
    
    # Creates a list {item tag ?item tag? ...} for items.
    set itemTagList [eval {::RosterTree::CreateItemBase $jid $presence} $args]

    foreach {item tag} $itemTagList {
	set tag0 [lindex $tag 0]
	set tag1 [lindex $tag 1]
	set text $jtext
	set image $jimage
	lappend items $item
	
	switch -- $tag0 {
	    jid {
		set style $styleMap($presence)
		lappend jitems $item
	    }
	    group {
		set style styFolder
		set text  $tag1
		set image [::Rosticons::Get application/group-$presence]
	    }
	    head {
		set style styHead
		set text  [::RosterTree::MCHead $tag1]
		set image [::Rosticons::Get application/$tag1]
	    }
	    pending {
		set style styUnavailable
	    }
	    transport {
		set style styTransport
	    }
	}
	ConfigureItem $item $style $text $image
    }
    
    # Configure number of available/unavailable users.
    foreach type {
	available unavailable transport pending
    } itype {
	jid jid transport pending
    } {
	set tag [list head $type]
	set item [FindWithTag $tag]
	if {$item ne ""} {
	    set all [::RosterTree::FindAllWithTagInItem $item $itype]
	    set n [llength $all]
	    $T item element configure $item cTree eNumText -text "($n)"
	}
    }
    
    # Update any groups.
    foreach item [::RosterTree::FindWithFirstTag group] {
	set n [llength [$T item children $item]]
	$T item element configure $item cTree eNumText -text "($n)"
    }

    # Design the balloon help window message.
    foreach item $jitems {
	eval {Balloon $jidx $presence $item} $args
    }
    return $items
}

proc ::RosterPlain::ConfigureItem {item style text image} {
    variable T
    
    $T item style set $item cTree $style
    $T item element configure $item  \
      cTree eText -text $text + eImage -image $image    
}

# RosterPlain::DeleteItem --
# 
#       Deletes all items associated with jid.
#       It is also responsible for cleaning up empty dirs etc.

proc ::RosterPlain::DeleteItem {jid} {
 
    ::Debug 5 "::RosterPlain::DeleteItem, jid=$jid"
    
    # Sibling of '::RosterTree::CreateItemBase'.
    ::RosterTree::DeleteItemBase $jid
    
    # Delete any empty leftovers.
    ::RosterTree::DeleteEmptyGroups
    ::RosterTree::DeleteEmptyPendTrpt
}

proc ::RosterPlain::CreateItemFromJID {jid} {    
    upvar ::Jabber::jstate jstate
    
    jlib::splitjid $jid jid2 res
    set pres [$jstate(roster) getpresence $jid2 -resource $res]
    set rost [$jstate(roster) getrosteritem $jid2]
    array set opts $pres
    array set opts $rost

    return [eval {CreateItem $jid $opts(-type)} [array get opts]]
}

proc ::RosterPlain::SetItemAlternative {jid key type value} {

    switch -- $type {
	image {
	    return [SetAltImage $jid $key $value]
	}
	text {
	    # @@@ TODO
	    return -code error "not implemented"
	}
    }
}

# @@@ multiple keys TODO
proc ::RosterPlain::SetAltImage {jid key image} {
    variable T
    variable altKeyElemArr
    
    # altKeyElemArr maps ($key,image|text) -> element name
    
    set mjid [jlib::jidmap $jid]
    set tag [list jid $mjid]
    set item [FindWithTag $tag]
    
    if {[info exists altKeyElemArr($key,image)]} {
	set elem $altKeyElemArr($key,image)
    } else {
	set elem eAltImage
	set altKeyElemArr($key,image) eAltImage
    }    
    $T item element configure $item cTree $elem -image $image  

    return [list $T $item cTree eAltImage]
}

#
# In OO we handle these with inheritance from a base class.
#

proc ::RosterPlain::CreateWithTag {tag style text image parent} {
    variable T
    
    # Base class constructor. Handles the cTag column and tag.
    set item [::RosterTree::CreateWithTag $tag $parent]
    
    $T item style set $item cTree $style
    $T item element configure $item  \
      cTree eText -text $text + eImage -image $image

    return $item
}

proc ::RosterPlain::DeleteWithTag {tag} {
    return [::RosterTree::DeleteWithTag $tag]
}

proc ::RosterPlain::FindWithTag {tag} {    
    return [::RosterTree::FindWithTag $tag]
}

proc ::RosterPlain::MakeDisplayText {jid presence args} {
    return [eval {::RosterTree::MakeDisplayText $jid $presence} $args]
}

proc ::RosterPlain::GetPresenceIcon {jid presence args} {
    return [eval {::Roster::GetPresenceIcon $jid $presence} $args]
}

proc ::RosterPlain::GetPresenceIconFromJid {jid} {
    return [::Roster::GetPresenceIconFromJid $jid]
}

proc ::RosterPlain::Balloon {jid presence item args} {    
    eval {::RosterTree::Balloon $jid $presence $item} $args
}

proc ::RosterPlain::TreeConfigureHook {args} {
    variable T
    variable rosterStyle
    
    if {[::RosterTree::GetStyle] ne $rosterStyle} {
	return
    }
    set wclass [::Roster::GetRosterWindow]
    set ename eBorder
    set eopts {}
    if {[$T cget -backgroundimage] eq ""} {
	set postfix ":nbg"
    } else {
	set postfix ""
    }
    foreach oname {-outline -outlinewidth} {
	set dbname ${rosterStyle}:${ename}${oname}${postfix}	    
	set dbvalue [option get $wclass $dbname {}]
	lappend eopts $oname $dbvalue
    }

    eval {$T element configure eBorder} $eopts
}

#
# Handle foreign IM system icons.
#

# RosterPlain::BrowseSetHook, DiscoInfoHook --
# 
#       It is first when we have obtained either browse or disco info it is
#       possible to set icons of foreign IM users.

proc ::RosterPlain::BrowseSetHook {from subiq} {
    variable rosterStyle
    upvar ::Jabber::jserver jserver
    
    if {[::RosterTree::GetStyle] ne $rosterStyle} {
	return
    }
    
    # Fix icons of foreign IM systems.
    if {![jlib::jidequal $from $jserver(this)]} {
	PostProcess browse $from
    }
}

proc ::RosterPlain::DiscoInfoHook {type from subiq args} {
    variable rosterStyle
    upvar ::Jabber::jstate jstate
    
    if {[::RosterTree::GetStyle] ne $rosterStyle} {
	return
    }

    if {$type ne "error"} {
	set types [$jstate(jlib) disco types $from]
	
	# Only the gateways have custom icons.
	if {[lsearch -glob $types gateway/*] >= 0} {
	    PostProcess disco $from
	}
    }
}

# RosterPlain::PostProcess --
# 
#       This is necessary to get icons for foreign IM systems set correctly.
#       Usually we get the roster before we've got browse/agents/disco 
#       info, so we cannot know if an item is an ICQ etc. when putting it
#       into the roster.
#       
#       Browse and disco return this information differently:
#         browse:  from=login server
#         disco:   from=each specific component
#         
# Arguments:
#       method      "browse" or "disco"
#       
# Results:
#       none.

proc ::RosterPlain::PostProcess {method from} {
    
    ::Debug 5 "::RosterPlain::PostProcess $from"

    if {[string equal $method "browse"]} {
	set matchHost 0
	PostProcessItem $from $matchHost root
    } elseif {[string equal $method "disco"]} {
	PostProcessDiscoInfo $from
    }    
}

proc ::RosterPlain::PostProcessDiscoInfo {from} {
    variable T
        
    set jids [::Roster::GetUsersWithSameHost $from]
    foreach jid $jids {
	set tag [list jid $jid]
	foreach item [FindWithTag $tag] {
	    
	    # Need to identify any associated transport and place it
	    # in the transport if not there.
	    set icon [GetPresenceIconFromJid $jid]
	    set istrpt [::Roster::IsTransportHeuristics $jid]
	    if {$istrpt} {
		$T item delete $item
		CreateItemFromJID $jid
	    } else {
		if {$icon ne ""} {
		    $T item image $item cTree $icon
		}
	    }
	}
    }
}

proc ::RosterPlain::PostProcessItem {from matchHost item} {
    variable T    
    
    if {[$T item numchildren $item]} {
	foreach citem [$T item children $item] {
	    PostProcessItem $from $matchHost $citem
	}
    } else {
	set tags [$T item element cget $item cTag eText -text]
	set tag0 [lindex $tags 0]
	if {($tag0 eq "transport") || ($tag0 eq "jid")} {
	    set jid [lindex $tags 1]
	    jlib::splitjidex $jid username host res
	    
	    # Consider only relevant jid's:
	    # Browse always, disco only if from == host.
	    if {!$matchHost || [string equal $from $host]} {
		set icon [GetPresenceIconFromJid $jid]
		if {$icon ne ""} {
		    $T item image $item cTree $icon
		}
	    }
	}
    }
}
