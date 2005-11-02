#  RosterTree.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the roster tree using treectrl.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: RosterTree.tcl,v 1.1 2005-11-02 12:54:09 matben Exp $

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

    # Mappings from <show> element to displayable text and vice versa.
    # chat away xa dnd
    variable mapShowTextToElem
    variable mapShowElemToText

    # Cache messages for efficiency.
    array set mapShowTextToElem [list \
      [mc mAvailable]       available  \
      [mc mAway]            away       \
      [mc mChat]            chat       \
      [mc mDoNotDisturb]    dnd        \
      [mc mExtendedAway]    xa         \
      [mc mInvisible]       invisible  \
      [mc mNotAvailable]    unavailable]
    array set mapShowElemToText [list \
      available       [mc mAvailable]     \
      away            [mc mAway]          \
      chat            [mc mChat]          \
      dnd             [mc mDoNotDisturb]  \
      xa              [mc mExtendedAway]  \
      invisible       [mc mInvisible]     \
      unavailable     [mc mNotAvailable]]

    variable mcHead
    array set mcHead [list \
      available     [mc Online]         \
      unavailable   [mc Offline]        \
      transport     [mc Transports]     \
      pending       [mc {Subscription Pending}]]

}

# @@@ TODO: a kind of plugin system for roster styles.

proc ::RosterTree::RegisterStyle {
    name label configProc createItemProc configItemProc deleteItemProc} {
	
    variable plugin
    
    set plugin($name,name)       $name
    set plugin($name,label)      $label
    set plugin($name,config)     $configProc
    set plugin($name,createItem) $createItemProc
    set plugin($name,configItem) $configItemProc
    set plugin($name,deleteItem) $deleteItemProc
}

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

    $T notify bind $T <Selection>      { ::RosterTree::Selection }
    $T notify bind $T <Expand-after>   { ::RosterTree::OpenTreeCmd %I }
    $T notify bind $T <Collapse-after> { ::RosterTree::CloseTreeCmd %I }
    bind $T <Button-1>        { ::RosterTree::ButtonPress %x %y }        
    bind $T <ButtonRelease-1> { ::RosterTree::ButtonRelease %x %y }        
    bind $T <Double-1>        { ::RosterTree::DoubleClick %x %y }        
    bind $T <<ButtonPopup>>   { ::RosterTree::Popup %x %y }
    bind $T <Destroy>         {+::RosterTree::OnDestroy }
}

proc ::RosterTree::Configure {_T} {
    global  this
    variable T
    
    set T $_T
    
    # This is a dummy option.
    set stripeBackground [option get $T stripeBackground {}]
    set stripes [list $stripeBackground {}]

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
    $T element create eBorder rect -open new -outline white -outlinewidth 1 \
      -fill $fill -showfocus 1
 
    # Styles collecting the elements.
    set S [$T style create styHead]
    $T style elements $S {eBorder eImage eText}
    $T style layout $S eText -padx 4 -squeeze x -expand ns -ipady 2
    $T style layout $S eImage -expand ns -ipady 2
    $T style layout $S eBorder -detach 1 -iexpand xy -indent 0

    set S [$T style create styFolder]
    $T style elements $S {eBorder eImage eText}
    $T style layout $S eText -padx 4 -squeeze x -expand ns -ipady 2
    $T style layout $S eImage -expand ns -ipady 2
    $T style layout $S eBorder -detach 1 -iexpand xy -indent 0

    set S [$T style create styUnavailable]
    $T style elements $S {eBorder eImage eText}
    $T style layout $S eText -padx 4 -squeeze x -expand ns -ipady 2
    $T style layout $S eImage -expand ns -ipady 2
    $T style layout $S eBorder -detach 1 -iexpand xy -indent 0

    set S [$T style create styAvailable]
    $T style elements $S {eBorder eImage eAltImage eText}
    $T style layout $S eText -padx 4 -squeeze x -expand ns -ipady 2
    $T style layout $S eImage -expand ns -ipady 2
    $T style layout $S eAltImage -expand ns -ipady 2
    $T style layout $S eBorder -detach 1 -iexpand xy -indent 0

    set S [$T style create styTransport]
    $T style elements $S {eBorder eImage eText}
    $T style layout $S eText -padx 4 -squeeze x -expand ns -ipady 2
    $T style layout $S eImage -expand ns -ipady 2
    $T style layout $S eBorder -detach 1 -iexpand xy -indent 0

    set S [$T style create styTag]
    $T style elements $S {eText}
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
	    set jid3 [FindAllUsersInItem $item]
	}
	head {
	    if {[regexp {(available|unavailable)} [lindex $tags 1]]} {
		lappend clicked head
		set jid3 [FindAllUsersInItem $item]
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

proc ::RosterTree::FindAllUsersInItem {item} {
    variable T
    
    set jids {}
    foreach citem [$T item children $item] {
	if {[$T item numchildren $citem]} {
	    set jids [concat $jids [FindAllUsersInItem $citem]]
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

proc ::RosterTree::CreateWithTag {tag style text image parent} {
    variable T
    variable tag2items
    
    set item [$T item create -parent $parent]
    $T item style set $item cTree $style cTag styTag
    $T item element configure $item  \
      cTree eText -text $text + eImage -image $image , \
      cTag  eText -text $tag
    lappend tag2items($tag) $item

    return $item
}

proc ::RosterTree::ConfigureWithTag {tag type spec} {
    variable T
    variable tag2items
    
    # 'type' is 'text' or 'image'.
    if {[info exists tag2items($tag)]} {
	foreach item $tag2items($tag) {
	    $T item $type $item cTree $spec
	}
    }    
}

proc ::RosterTree::DeleteWithTag {tag} {
    variable T
    variable tag2items
    
    if {[info exists tag2items($tag)]} {
	DeleteChildrenOfTag $tag
	foreach item $tag2items($tag) {
	    $T item delete $item
	}    
	unset tag2items($tag)
    }
}

proc ::RosterTree::DeleteItem {item} {
    variable T
    variable tag2items
    
    set tag [$T item element cget $item cTag eText -text]
    set items $tag2items($tag)
    set idx [lsearch $items $item]
    if {$idx >= 0} {
	set tag2items($tag) [lreplace $items $idx $idx]
    }
    $T item delete $item
}

proc ::RosterTree::DeleteChildrenOfTag {tag} {
    variable T
    variable tag2items

    if {[info exists tag2items($tag)]} {
	foreach item $tag2items($tag) {
	    if {[$T item numchildren $item]} {
		foreach child [$T item children $item] {
		    set ctag [$T item element cget $child cTag eText -text]
		    DeleteWithTag $ctag
		}	    
	    }
	}
    }
}

proc ::RosterTree::FindWithTag {tag} {
    variable T
    variable tag2items
    
    set items {}
    if {[info exists tag2items($tag)]} {
	set items $tag2items($tag)
    }
    return $items
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

proc ::RosterTree::ExistsWithTag {tag} {
    variable tag2items

    return [info exists tag2items($tag)]
}

proc ::RosterTree::FreeTags {} {
    variable tag2items
    
    unset -nocomplain tag2items
}

# ---------------------------------------------------------------------------- #

proc ::RosterTree::Init { } {
    variable T
    variable mcHead
    upvar ::Jabber::jprefs jprefs
    
    set onlineImage  [::Theme::GetImage [option get $T onlineImage {}]]
    set offlineImage [::Theme::GetImage [option get $T offlineImage {}]]

    $T item delete all
    FreeTags
    
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

# RosterTree::Item --
#
#       Sets the jid in the correct place in our roster tree.
#       Online users shall be put with full 3-tier jid.
#       Offline and other are stored with 2-tier jid with no resource.
#
# Arguments:
#       jid         2-tier jid, or 3-tier for icq etc.
#       presence    "available" or "unavailable"
#       args        list of '-key value' pairs of presence and roster
#                   attributes.
#       
# Results:
#       treectrl item.

proc ::RosterTree::Item {jid presence args} {    
    variable T
    variable mapShowElemToText
    variable mcHead
    upvar ::Jabber::jstate  jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs  jprefs
    
    ::Debug 3 "::RosterTree::Item jid=$jid, presence=$presence, args='$args'"

    if {![regexp $presence {(available|unavailable)}]} {
	return
    }
    if {!$jprefs(rost,showOffline) && ($presence eq "unavailable")} {
	return
    }
    array set argsArr $args
    
    jlib::splitjid $jid jid2 res

    # Format item:
    #  - If 'name' attribute, use this, else
    #  - if user belongs to login server, use only prefix, else
    #  - show complete 2-tier jid
    # If resource add it within parenthesis '(presence)' but only if Online.
    # 
    # For Online users, the tree item must be a 3-tier jid with resource 
    # since a user may be logged in from more than one resource.
    # Note that some (icq) transports have 3-tier items that are unavailable!
    
    set server $jserver(this)

    # jid2 is always without a resource
    # jid3 is with resource if reported with one else as jid2
    # jidx is as jid3 if available else jid2

    set jidx $jid
    set jid3 $jid
    if {[info exists argsArr(-resource)] && ($argsArr(-resource) ne "")} {
	set jid3 $jid2/$argsArr(-resource)
	if {$presence eq "available"} {
	    set jidx $jid2/$argsArr(-resource)
	}
    }
    set mjid [jlib::jidmap $jidx]
    set istrpt [::Roster::IsTransportHeuristics $jid3]
    if {$istrpt && !$jprefs(rost,showTrpts)} {
	return
    }

    # Make display text (itemstr).
    set itemstr [eval {MakeDisplayText $jid3 $presence} $args]
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

# RosterTree::MakeDisplayText --
# 
#       Make a standard display text.

proc ::RosterTree::MakeDisplayText {jid presence args} {
    variable mapShowElemToText
    upvar ::Jabber::jserver jserver

    array set argsArr $args
    
    # Make display text (itemstr).
    set istrpt [::Roster::IsTransportHeuristics $jid]
    set server $jserver(this)

    if {$istrpt} {
	set str $jid
	if {[info exists argsArr(-show)]} {
	    set show $argsArr(-show)
	    if {[info exists mapShowElemToText($show)]} {
		append str " ($mapShowElemToText($show))"
	    } else {
		append str " ($show)"
	    }
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
    variable mapShowElemToText
    upvar ::Jabber::jstate jstate

    array set argsArr $args
    
    # Design the balloon help window message.
    set msg $jid
    if {[info exists argsArr(-show)]} {
	set show $argsArr(-show)
    } else {
	set show $presence
    }
    if {[info exists mapShowElemToText($show)]} {
	append msg "\n" $mapShowElemToText($show)
    } else {
	append msg "\n" $show
    }

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

# RosterTree::PostProcess --
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

proc ::RosterTree::PostProcess {method from} {
    variable T    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    if {[string equal $method "browse"]} {
	set matchHost 0
    } elseif {[string equal $method "disco"]} {
	set matchHost 1	
    }
    ::Debug 4 "::RosterTree::PostProcess $from"
    
    PostProcessItem $from $matchHost root
}

proc ::RosterTree::PostProcessItem {from matchHost item} {
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
	    set mjid [jlib::jidmap $jid]
	    jlib::splitjidex $mjid username host res

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
	
	# This bugs out:
	#set sorted [lsort -dictionary [list $text1 $text2]]
	#if {[string equal $text1 [lindex $sorted 0]]} {
	#    set ans -1
	#} else {
	#    set ans 1
	#}

	set ans [string compare $text1 $text2]
    }
    return $ans
}

# RosterTree::ItemDelete --
#
#       Removes a jid item from all groups in the tree.
#
# Arguments:
#       jid         can be 2-tier or 3-tier jid!
#       
# Results:
#       updates tree.

proc ::RosterTree::ItemDelete {jid} {    
    variable T    
    
    ::Debug 2 "::RosterTree::ItemDelete, jid=$jid"
    
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
    
    # @@@ pending and transports ?????
    DeleteWithTag [list pending $jid]
    DeleteWithTag [list transport $jid]

    DeleteEmptyGroups
}

proc ::RosterTree::DeleteEmptyGroups {} {
    variable T
    
    foreach item [FindWithFirstTag group] {
	if {[$T item numchildren $item] == 0} {
	    DeleteItem $item
	}
    }
}

# RosterTree::DeleteEmpty --
# 
#       Cleanup empty pending and transport dirs.

proc ::RosterTree::DeleteEmpty {} {
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

# RosterTree::Clear --
#
#       Clears the complete tree from all jid's and all groups.
#
# Arguments:
#       
# Results:
#       clears tree.

proc ::RosterTree::Clear { } {    
    variable T

    ::Debug 2 "::RosterTree::Clear"
    
    DeleteChildrenOfTag [list head available]
    DeleteChildrenOfTag [list head unavailable]
    DeleteWithTag [list head transport]
    DeleteWithTag [list head pending]
}





proc ::RosterTree::OnDestroy {} {
    variable T
    variable tag2items
    
    unset -nocomplain tag2items
}

