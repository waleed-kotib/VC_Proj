#  RosterPlain.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements a plain style roster tree using treectrl.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: RosterPlain.tcl,v 1.1 2005-11-04 15:14:55 matben Exp $

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

namespace eval ::RosterTree {}

namespace eval ::RosterPlain {
    
    # Head titles.
    variable mcHead
    array set mcHead [list \
      available     [mc Online]         \
      unavailable   [mc Offline]        \
      transport     [mc Transports]     \
      pending       [mc {Subscription Pending}]]
    
    
    # Register this style.
    ::RosterTree::RegisterStyle plain Plain   \
      ::RosterPlain::Configure   \
      ::RosterPlain::Init        \
      ::RosterPlain::CreateItem  \
      ::RosterPlain::DeleteItem
    
    # This is the basic style used as fallback.
    ::RosterTree::SetStyle plain
    
    # Only if this style is in use!!!
    # These are needed to handle foreign IM systems.
    ::hooks::register  browseSetHook        ::RosterPlain::BrowseSetHook
    ::hooks::register  discoInfoHook        ::RosterPlain::DiscoInfoHook
    ::hooks::register  rosterTreeConfigure  ::RosterPlain::TreeConfigureHook
}

# RosterPlain::Configure --
# 
#       Create columns, elements and styles for treectrl.

proc ::RosterPlain::Configure {_T} {
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

    # Two columns: 
    #   0) the tree 
    #   1) hidden for tags
    $T column create -tag cTree -itembackground $stripes -resize 0 -expand 1
    $T column create -tag cTag -visible 0
    $T configure -treecolumn cTree

    # The elements.
    set fill [list $this(sysHighlight) {selected focus} gray {selected !focus}]
    $T element create eImage image
    $T element create eAltImage image
    $T element create eText text -lines 1
    $T element create eBorder rect -open new -outline $outline -outlinewidth 1 \
      -fill $fill -showfocus 1
 
    # Styles collecting the elements.
    set S [$T style create styHead]
    $T style elements $S {eBorder eImage eText}
    $T style layout $S eText -padx 4 -squeeze x -expand ns -ipady 1
    $T style layout $S eImage -expand ns -ipady 1
    $T style layout $S eBorder -detach 1 -iexpand xy -indent 0

    set S [$T style create styFolder]
    $T style elements $S {eBorder eImage eText}
    $T style layout $S eText -padx 4 -squeeze x -expand ns -ipady 1
    $T style layout $S eImage -expand ns -ipady 1
    $T style layout $S eBorder -detach 1 -iexpand xy -indent 0

    set S [$T style create styUnavailable]
    $T style elements $S {eBorder eImage eText}
    $T style layout $S eText -padx 4 -squeeze x -expand ns -ipady 1
    $T style layout $S eImage -expand ns -ipady 1
    $T style layout $S eBorder -detach 1 -iexpand xy -indent 0

    set S [$T style create styAvailable]
    $T style elements $S {eBorder eImage eAltImage eText}
    $T style layout $S eText -padx 4 -squeeze x -expand ns -ipady 1
    $T style layout $S eImage -expand ns -ipady 1
    $T style layout $S eAltImage -expand ns -ipady 2
    $T style layout $S eBorder -detach 1 -iexpand xy -indent 0

    set S [$T style create styTransport]
    $T style elements $S {eBorder eImage eText}
    $T style layout $S eText -padx 4 -squeeze x -expand ns -ipady 1
    $T style layout $S eImage -expand ns -ipady 1
    $T style layout $S eBorder -detach 1 -iexpand xy -indent 0

    set S [$T style create styTag]
    $T style elements $S {eText}

    $T notify bind $T <Selection>      { ::RosterTree::Selection }
    $T notify bind $T <Expand-after>   { ::RosterTree::OpenTreeCmd %I }
    $T notify bind $T <Collapse-after> { ::RosterTree::CloseTreeCmd %I }
}

# RosterPlain::Init --
# 
#       Creates the items for the initial logged out state.
#       It starts by removing all content.

proc ::RosterPlain::Init { } {
    variable T
    variable mcHead
    upvar ::Jabber::jprefs jprefs
	
    set onlineImage  [::Theme::GetImage [option get $T onlineImage {}]]
    set offlineImage [::Theme::GetImage [option get $T offlineImage {}]]

    $T item delete all
    ::RosterTree::FreeTags
    
    # Available:
    set tag [list head available]
    set item [CreateWithTag $tag styHead $mcHead(available) $onlineImage root]
    if {$jprefs(rost,showOffline)} {
	$T item configure $item -button 1
    }
    if {[lsearch $jprefs(rost,closedItems) $tag] >= 0} {
	$T item collapse $item
    }
    
    # Unavailable:
    if {$jprefs(rost,showOffline)} {
	set tag [list head unavailable]
	set item [CreateWithTag $tag styHead $mcHead(unavailable) $offlineImage root]
	$T item configure $item -button 1
	if {[lsearch $jprefs(rost,closedItems) $tag] >= 0} {
	    $T item collapse $item
	}
    }
}

# RosterPlain::CreateItem --
#
#       Sets the jid in the correct place in our roster tree.
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
#       treectrl item.

proc ::RosterPlain::CreateItem {jid presence args} {    
    variable T
    variable mcHead
    upvar ::Jabber::jstate  jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs  jprefs
    
    ::Debug 4 "::RosterPlain::CreateItem jid=$jid, presence=$presence, args='$args'"

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

    # Format item:
    #  - If 'name' attribute, use this, else
    #  - if user belongs to login server, use only prefix, else
    #  - show complete 2-tier jid
    # If resource add it within parenthesis '(presence)' but only if Online.
    # 
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

    # Make display text (itemstr).
    set itemstr [eval {MakeDisplayText $jid $presence} $args]
    set icon [eval {::Roster::GetPresenceIcon $jidx $presence} $args]
    array set styleMap [list available styAvailable unavailable styUnavailable]
    
    # Keep track of any dirs created.
    set dirtags {}
	
    if {$istrpt} {
	
	# Transports:
	set ptag [list head transport]
	set pitem [FindWithTag $ptag]
	if {$pitem eq ""} {
	    set im [::Theme::GetImage [option get $T trptImage {}]]
	    set pitem [CreateWithTag $ptag styHead $mcHead(transport) $im root]
	    $T item configure $pitem -button 1
	    lappend dirtags $ptag
	}
	set tag [list transport $jid3]
	set item [CreateWithTag $tag styTransport $itemstr $icon $pitem]
    } elseif {[info exists argsArr(-ask)] && ($argsArr(-ask) eq "subscribe")} {
	
	# Pending:
	set ptag [list head pending]
	set pitem [FindWithTag $ptag]
	if {$pitem eq ""} {
	    set im ""
	    set pitem [CreateWithTag $ptag styHead $mcHead(pending) $im root]
	    $T item configure $pitem -button 1
	    lappend dirtags $ptag
	}
	set tag [list pending $mjid]
	set item [CreateWithTag $tag styUnavailable $itemstr $icon $pitem]
    } elseif {[info exists argsArr(-groups)] && ($argsArr(-groups) ne "")} {
	
	# Group(s):
	foreach group $argsArr(-groups) {
	    
	    # Make group if not exists already.
	    set ptag [list group $group $presence]
	    set pitem [FindWithTag $ptag]
	    if {$pitem eq ""} {
		set groupImage [::Theme::GetImage [option get $T groupImage {}]]
		set pptag [list head $presence]
		set ppitem [FindWithTag $pptag]
		set pitem [CreateWithTag $ptag styFolder $group $groupImage $ppitem]
		$T item configure $pitem -button 1
		lappend dirtags $ptag
	    }
	    set tag [list jid $mjid]
	    set item [CreateWithTag $tag $styleMap($presence) $itemstr $icon $pitem]
	}
    } else {
	
	# No groups associated with this item.
	set tag  [list jid $mjid]
	set ptag [list head $presence]
	set pitem [FindWithTag $ptag]
	set item [CreateWithTag $tag $styleMap($presence) $itemstr $icon $pitem]
    }
    
    # If we created a directory and that is on the closed item list.
    # Default is to have -open.
    foreach dtag $dirtags {
	if {[lsearch $jprefs(rost,closedItems) $dtag] >= 0} {	    
	    set citem [FindWithTag $dtag]
	    $T item collapse $citem
	}
    }
    
    # Design the balloon help window message.
    eval {Balloon $jidx $presence $item} $args
    
    # @@@ wrong if several groups.
    return $item
}

# RosterPlain::DeleteItem --
# 
#       Deletes all items associated with jid.
#       It is also responsible for cleaning up empty dirs etc.

proc ::RosterPlain::DeleteItem {jid} {
 
    ::Debug 2 "::RosterPlain::DeleteItem, jid=$jid"
    
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

    # Delete any empty leftovers.
    ::RosterTree::DeleteEmptyGroups
    ::RosterTree::DeleteEmptyPendTrpt
}

#
# In OO we handle these with inheritance from a base class.
#

proc ::RosterPlain::CreateWithTag {tag style text image parent} {
    variable T
    
    # Base class constructor.
    set item [::RosterTree::CreateWithTag $tag $parent]
    
    $T item style set $item cTree $style cTag styTag
    $T item element configure $item  \
      cTree eText -text $text + eImage -image $image , \
      cTag  eText -text $tag
    
    return $item
}

proc ::RosterPlain::DeleteWithTag {tag} {
    
    # If we have anything to cleanup we place it here.
    # --> style specific cleanup
    # Base class destructor.
    return [::RosterTree::DeleteWithTag $tag]
}

proc ::RosterPlain::FindWithTag {tag} {    
    
    return [::RosterTree::FindWithTag $tag]
}

proc ::RosterPlain::MakeDisplayText {jid presence args} {
    
    return [eval {::RosterTree::MakeDisplayText $jid $presence} $args]
}

proc ::RosterPlain::Balloon {jid presence item args} {
    
    eval {::RosterTree::Balloon $jid $presence $item} $args
}

proc ::RosterPlain::TreeConfigureHook {args} {
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

# RosterPlain::BrowseSetHook, DiscoInfoHook --
# 
#       It is first when we have obtained either browse or disco info it is
#       possible to set icons of foreign IM users.

proc ::RosterPlain::BrowseSetHook {from subiq} {
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jserver jserver
    
    if {[::RosterTree::GetStyle] ne "plain"} {
	return
    }
    
    # Fix icons of foreign IM systems.
    if {$jprefs(rost,haveIMsysIcons)} {
	if {![jlib::jidequal $from $jserver(this)]} {
	    PostProcess browse $from
	}
    }
}

proc ::RosterPlain::DiscoInfoHook {type from subiq args} {
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    if {[::RosterTree::GetStyle] ne "plain"} {
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
    variable T    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    if {[string equal $method "browse"]} {
	set matchHost 0
    } elseif {[string equal $method "disco"]} {
	set matchHost 1	
    }
    ::Debug 4 "::RosterPlain::PostProcess $from"
    
    PostProcessItem $from $matchHost root
}

proc ::RosterPlain::PostProcessItem {from matchHost item} {
    variable T    
    upvar ::Jabber::jserver jserver
    
    set server $jserver(this)
    
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
		set icon [::Roster::GetPresenceIconFromJid $jid]
		if {$icon ne ""} {
		    $T item image $item cTree $icon
		}
	    }
	}
    }
}
