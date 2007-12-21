#  RosterTwo.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements a two line style roster tree using treectrl.
#      
#  Copyright (c) 2005-2007  Mats Bengtsson
#  
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#  
# $Id: RosterTwo.tcl,v 1.26 2007-12-21 08:39:13 matben Exp $

package require RosterTree

package provide RosterTwo 1.0

namespace eval ::RosterTwo {
	
    # Register this style.
    ::RosterTree::RegisterStyle two "Two Line"   \
      ::RosterTwo::Configure   \
      ::RosterTwo::Init        \
      ::RosterTwo::Delete      \
      ::RosterTwo::CreateItem  \
      ::RosterTwo::DeleteItem  \
      ::RosterTwo::SetItemAlternative
        
    ::RosterTree::RegisterStyleFindColumn two cTree

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
    set itemBackground [option get $T itemBackground {}]
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
    $T column create -tags cTree -itembackground $itemBackground -resize 0 \
      -expand 1 -squeeze 1
    $T column create -tags cTag -visible 0
    $T configure -treecolumn cTree -showheader 0

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
    $T style layout $S eText  -padx [list $dX 0] -pady [list $py $dY] -detach 1 -squeeze x
    $T style layout $S eText2 -padx [list $dX 0] -pady [list $dY $py] -detach 1 -squeeze x
    $T style layout $S eBorder -detach 1 -iexpand xy -indent 0

    $T style layout $S eBox1 -union {eText}
    $T style layout $S eBox2 -union {eText2}

    set S [$T style create styTag]
    $T style elements $S {eText}
    
    ::TreeCtrl::DnDSetDragSources $T {}
    ::TreeCtrl::DnDSetDropTargets $T {}
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
    if {$jprefs(rost,showOffline)} {
	$T item configure $item -button 1
    } else {
	# Requested that button still shown.
	$T item configure $item -button 1
    }
    
    # Unavailable:
    if {$jprefs(rost,showOffline)} {
	set item [CreateHeadItem unavailable]
    }
}

proc ::RosterTwo::Delete { } { }

proc ::RosterTwo::CreateHeadItem {type} {
    variable T
    upvar ::Jabber::jprefs jprefs
    
    set tag [list head $type]
    set text [::RosterTree::MCHead $type]
    set text2 "No users"
    set image [::Rosticons::Get application/$type]
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
#       jid         the jid that shall be used in roster, typically jid3 for
#                   online users and jid2 for offline.
#       presence    "available" or "unavailable"
#       args        list of '-key value' pairs of presence and roster
#                   attributes.
#       
# Results:
#       treectrl item.

proc ::RosterTwo::CreateItem {jid presence args} {    
    variable T
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs

    if {($presence ne "available") && ($presence ne "unavailable")} {
	return
    }
    if {!$jprefs(rost,showOffline) && ($presence eq "unavailable")} {
	return
    }
    set istrpt [::Roster::IsTransportEx $jid]
    if {$istrpt && !$jprefs(rost,showTrpts)} {
	return
    }
    array set argsArr $args

    set jid2 [jlib::barejid $jid]
    set mjid [jlib::jidmap $jid]
    
    set jlib $jstate(jlib)
    
    # Defaults:
    set name [$jlib roster getname $jid2]
    set ujid [jlib::unescapejid $jid]
    if {$name ne ""} {
	set jtext "$name ($ujid)"
    } else {
	set jtext $ujid
    }
    set status [$jlib roster getstatus $jid]
    set since  [$jlib roster availablesince $jid]
    set jimage [eval {GetPresenceIcon $jid $presence} $args]
    set items  [list]
    set jitems [list]
    
    # Creates a list {item tag ?item tag? ...} for items.
    set itemTagList [eval {::RosterTree::CreateItemBase $jid $presence} $args]

    foreach {item tag} $itemTagList {
	set tag0 [lindex $tag 0]
	set tag1 [lindex $tag 1]
	set text  $jtext
	set text2 "No status message"
	set image $jimage
	lappend items $item
	
	switch -- $tag0 {
	    jid {
		set style styStd
		if {$presence eq "available"} {
		    set time [::Utils::SmartClockFormat $since -showsecs 0]
		    set text2 "($time)"
		    if {$status ne ""} {
			append text2 " $status"
		    }
		} else {
		    if {$status ne ""} {
			set text2 "Status: $status"
		    }
		}
		lappend jitems $item
	    }
	    group {
		set style styStd
		set text  $tag1
		set image [::Rosticons::Get application/group-$presence]
	    }
	    head {
		set style styStd
		set text  [::RosterTree::MCHead $tag1]
		set image [::Rosticons::Get application/$tag1]
	    }
	}
	ConfigureItem $item $style $text $text2 $image
    }

    ConfigureChildNumbersAtIdle

    # Design the balloon help window message.
    foreach item $jitems {
	eval {Balloon $jid $presence $item} $args
    }
    return $items
}

proc ::RosterTwo::ConfigureChildNumbersAtIdle {} {
    variable pendingChildNumbers    
    
    # Configure number of available/unavailable users.
    if {![info exists pendingChildNumbers]} {
	set pendingChildNumbers 1
	after idle [namespace code ConfigureChildNumbers]
    }
}

# RosterPlain::ConfigureChildNumbers --
# 
#       Add an extra "(#)" to each directory that shows the content.

proc ::RosterTwo::ConfigureChildNumbers {} {
    variable T
    variable pendingChildNumbers

    unset -nocomplain pendingChildNumbers
    
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
    ConfigureChildNumbersAtIdle
}

proc ::RosterTwo::CreateItemFromJID {jid} {    
    upvar ::Jabber::jstate jstate
    
    set jlib $jstate(jlib)
    jlib::splitjid $jid jid2 res
    set pres [$jlib roster getpresence $jid2 -resource $res]
    set rost [$jlib roster getrosteritem $jid2]
    array set opts $pres
    array set opts $rost

    return [eval {CreateItem $jid $opts(-type)} [array get opts]]
}

proc ::RosterTwo::SetItemAlternative {jid key type image} {
    
    # @@@ TODO
    return
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
    
    if {[::RosterTree::GetStyle] ne "two"} {
	return
    }

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
    upvar ::Jabber::jstate jstate
    
    if {[::RosterTree::GetStyle] ne "two"} {
	return
    }
    if {$type ne "error"} {
	set types [$jstate(jlib) disco types $from]
	
	# Only the gateways have custom icons.
	if {[lsearch -glob $types gateway/*] >= 0} {
	    ::RosterTree::BasePostProcessDiscoInfo $from cTree eImage
	}
    }
}

