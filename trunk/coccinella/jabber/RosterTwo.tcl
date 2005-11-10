#  RosterTwo.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements a two line style roster tree using treectrl.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: RosterTwo.tcl,v 1.1 2005-11-10 12:57:03 matben Exp $

package require RosterTree

package provide RosterTwo 1.0

namespace eval ::RosterTwo {
	
    # Register this style.
    ::RosterTree::RegisterStyle two "Two Line"   \
      ::RosterTwo::Configure   \
      ::RosterTwo::Init        \
      ::RosterTwo::CreateItem  \
      ::RosterTwo::DeleteItem
        
    # Only if this style is in use!!!
    # These are needed to handle foreign IM systems.
    ::hooks::register  discoInfoHook        ::RosterTwo::DiscoInfoHook
    ::hooks::register  rosterTreeConfigure  ::RosterTwo::TreeConfigureHook
}

# RosterTwo::Configure --
# 
#       Create columns, elements and styles for treectrl.

proc ::RosterTwo::Configure {_T} {
    global  this
    variable T
    
    set T $_T
    
    # This is a dummy option.
    set stripeBackground [option get $T stripeBackground {}]
    set stripes [list $stripeBackground {}]
    set outline white
    if {[$T cget -backgroundimage] eq ""} {
	set outline gray
    }
    set px 1
    set py 1
    array set fm [font metrics [$T cget -font]]
    set ls $fm(-linespace)
    set dY [expr {$ls + 3*$py}]
    set imS 16
    set dX [expr {$imS + 3*$px}]

    # Two columns: 
    #   0) the tree 
    #   1) hidden for tags
    $T column create -tag cTree -itembackground $stripes -resize 0 -expand 1
    $T column create -tag cTag -visible 0
    $T configure -treecolumn cTree

    # The elements.
    set fill [list $this(sysHighlight) {selected focus} gray {selected !focus}]
    $T element create eBorder rect -open new -outline $outline -outlinewidth 1 \
      -fill $fill -showfocus 1
    $T element create eImage image
    $T element create eImage2 image
    $T element create eText text -lines 1
    $T element create eText2 text -lines 1 -fill gray30
    
    $T element create eBox1 rect ;# -fill green
    $T element create eBox2 rect ;# -fill red
 
    # Styles collecting the elements.
    set S [$T style create styStd]
    $T style elements $S {eBorder eBox1 eBox2 eImage eText eText2}
    $T style layout $S eImage -padx [list $px 0] -pady [list $py 0] -expand ns
    $T style layout $S eText  -padx [list $dX 0] -pady [list $py $dY] -detach 1
    $T style layout $S eText2 -padx [list $dX 0] -pady [list $dY $py] -detach 1
    $T style layout $S eBorder -detach 1 -iexpand xy -indent 0

    $T style layout $S eBox1 -union {eText}
    $T style layout $S eBox2 -union {eText2}

    set S [$T style create styTag]
    $T style elements $S {eText}
}

# RosterTwo::Init --
# 
#       Creates the items for the initial logged out state.
#       It starts by removing all content.

proc ::RosterTwo::Init { } {
    variable T
    upvar ::Jabber::jprefs jprefs
	
    $T item delete all
    ::RosterTree::FreeTags
    
    # Available:
    set item [CreateHeadItem available]
    if {!$jprefs(rost,showOffline)} {
	$T item configure $item -button 0
    }
    
    # Unavailable:
    if {$jprefs(rost,showOffline)} {
	set item [CreateHeadItem unavailable]
    }
}

proc ::RosterTwo::CreateHeadItem {type} {
    variable T
    upvar ::Jabber::jprefs jprefs
    
    array set headImageMap {
	available   onlineImage
	unavailable offlineImage
	transport   trptImage
	pending     ""
    }

    set tag [list head $type]
    set text [::RosterTree::MCHead $type]
    set text2 "No users"
    set rsrcName $headImageMap($type)
    set image [::Theme::GetImage [option get $T $rsrcName {}]]
    set item [CreateWithTag $tag styStd $text $text2 $image root]
    if {[lsearch $jprefs(rost,closedItems) $tag] >= 0} {
	$T item collapse $item
    }
    $T item element configure $item cTree eText -font CociSmallBoldFont
    $T item configure $item -button 1
    
    return $item
}

# RosterTwo::CreateItem --
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

proc ::RosterTwo::CreateItem {jid presence args} {    
    upvar ::Jabber::jstate jstate
    variable T

    array set headImageMap {
	available   onlineImage
	unavailable offlineImage
	transport   trptImage
	pending     ""
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
    set name [$jstate(roster) getname $jid2]
    if {$name ne ""} {
	set jtext "$name ($jidx)"
    } else {
	set jtext $jidx
    }
    set status [$jstate(roster) getstatus $jid]
    set since  [$jstate(roster) availablesince $jid]
    set jimage [eval {GetPresenceIcon $jidx $presence} $args]
    set items  {}
    set jitems {}
    
    # Creates a list {item tag ?item tag? ...} for items.
    set itemTagList [eval {::RosterTree::CreateItemBase $jid $presence} $args]

    foreach {item tag} $itemTagList {
	set tag0 [lindex $tag 0]
	set tag1 [lindex $tag 1]
	set text  $jtext
	set text2 ""
	set image $jimage
	lappend items $item
	
	switch -- $tag0 {
	    jid {
		set style styStd
		if {$presence eq "available"} {
		    set time [::Utils::SmartClockFormat $since -showsecs 0]
		    append text2 "($time) $status"
		} else {
		    set text2 "Status: $status"
		}
		lappend jitems $item
	    }
	    group {
		set style styStd
		set text  $tag1
		set image [::Theme::GetImage [option get $T groupImage {}]]
	    }
	    head {
		set style styStd
		set text  [::RosterTree::MCHead $tag1]
		set rsrcName $headImageMap($tag1)
		set image [::Theme::GetImage [option get $T $rsrcName {}]]
	    }
	    pending {
		set style styStd
	    }
	    transport {
		set style styStd
	    }
	}
	ConfigureItem $item $style $text $text2 $image
    }
    
    # Configure number of available/unavailable users.
    foreach type {available unavailable transport pending} {
	set tag [list head $type]
	set item [::RosterTree::FindWithTag $tag]
	if {$item ne ""} {
	    set all [::RosterTree::FindAllJIDInItem $item]
	    set n [llength $all]
	    set text2 "$n users"
	    $T item element configure $item cTree eText2 -text $text2
	}
    }
    
    # Update any groups.
    foreach item [::RosterTree::FindWithFirstTag group] {
	set n [llength [$T item children $item]]
	set htext "$n users"
	$T item element configure $item cTree eText2 -text $htext
    }
    
    # Design the balloon help window message.
    foreach item $jitems {
	eval {Balloon $jidx $presence $item} $args
    }
    return $items
}

proc ::RosterTwo::ConfigureItem {item style text text2 image} {
    variable T
    
    $T item style set $item cTree $style
    $T item element configure $item  \
      cTree eText -text $text + eText2 -text $text2 + eImage -image $image    
}

# RosterTwo::DeleteItem --
# 
#       Deletes all items associated with jid.
#       It is also responsible for cleaning up empty dirs etc.

proc ::RosterTwo::DeleteItem {jid} {
 
    ::Debug 2 "::RosterTwo::DeleteItem, jid=$jid"
    
    # Sibling of '::RosterTree::CreateItemBase'.
    ::RosterTree::DeleteItemBase $jid
    
    # Delete any empty leftovers.
    ::RosterTree::DeleteEmptyGroups
    ::RosterTree::DeleteEmptyPendTrpt
}

proc ::RosterTwo::CreateItemFromJID {jid} {    
    upvar ::Jabber::jstate jstate
    
    jlib::splitjid $jid jid2 res
    set pres [$jstate(roster) getpresence $jid2 -resource $res]
    set rost [$jstate(roster) getrosteritem $jid2]
    array set opts $pres
    array set opts $rost

    return [eval {CreateItem $jid $opts(-type)} [array get opts]]
}

#
# In OO we handle these with inheritance from a base class.
#

proc ::RosterTwo::CreateWithTag {tag style text text2 image parent} {
    variable T
    
    # Base class constructor. Handles the cTag column and tag.
    set item [::RosterTree::CreateWithTag $tag $parent]
    
    $T item style set $item cTree $style
    $T item element configure $item  \
      cTree eText -text $text + eText2 -text $text2 + eImage -image $image

    return $item
}

proc ::RosterTwo::FindWithTag {tag} {    
    return [::RosterTree::FindWithTag $tag]
}

proc ::RosterTwo::MakeDisplayText {jid presence args} {
    return [eval {::RosterTree::MakeDisplayText $jid $presence} $args]
}

proc ::RosterTwo::GetPresenceIcon {jid presence args} {
    return [eval {::Roster::GetPresenceIcon $jid $presence} $args]
}

proc ::RosterTwo::GetPresenceIconFromJid {jid} {
    return [::Roster::GetPresenceIconFromJid $jid]
}

proc ::RosterTwo::Balloon {jid presence item args} {    
    eval {::RosterTree::Balloon $jid $presence $item} $args
}

proc ::RosterTwo::TreeConfigureHook {args} {
    variable T
    
    set outline white
    if {[$T cget -backgroundimage] eq ""} {
	set outline gray
    }
    $T element configure eBorder -outline $outline    
}

#
# Handle foreign IM system icons.
#

proc ::RosterTwo::DiscoInfoHook {type from subiq args} {
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    if {[::RosterTree::GetStyle] ne "two"} {
	return
    }

    if {$type ne "error"} {
	if {$jprefs(rost,haveIMsysIcons)} {
	    set types [$jstate(jlib) disco types $from]
	    
	    # Only the gateways have custom icons.
	    if {[lsearch -glob $types gateway/*] >= 0} {
		PostProcess disco $from
	    }
	}
    }
}

# RosterTwo::PostProcess --
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

proc ::RosterTwo::PostProcess {method from} {
    
    ::Debug 4 "::RosterTwo::PostProcess $from"

    if {[string equal $method "browse"]} {
	# empty
    } elseif {[string equal $method "disco"]} {
	PostProcessDiscoInfo $from
    }    
}

proc ::RosterTwo::PostProcessDiscoInfo {from} {
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

