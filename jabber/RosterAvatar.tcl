#  RosterAvatar.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements an avatar style roster tree using treectrl.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: RosterAvatar.tcl,v 1.7 2006-04-27 07:48:49 matben Exp $

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
package require Avatar

package provide RosterAvatar 1.0

namespace eval ::RosterAvatar {
    
    variable rosterStyle "avatar"
        
    # Register this style.
    ::RosterTree::RegisterStyle avatar Avatar  \
      ::RosterAvatar::Configure   \
      ::RosterAvatar::Init        \
      ::RosterAvatar::Delete      \
      ::RosterAvatar::CreateItem  \
      ::RosterAvatar::DeleteItem  \
      ::RosterAvatar::SetItemAlternative
    
    ::RosterTree::RegisterStyleSort avatar ::RosterAvatar::Sort

    # Event hooks.
    ::hooks::register  discoInfoHook        ::RosterAvatar::DiscoInfoHook
    ::hooks::register  rosterTreeConfigure  ::RosterAvatar::TreeConfigureHook

    # We should have a set of sizes to choose from: 32, 48 and 64
    variable avatarSize 32
    
    variable avatarDefault defaultBoy
    variable initedDB 0
    
    variable statusOrder
    array set statusOrder {
	chat          0
	available     1
	away          2
	xa            3
	dnd           4
	invisible     5
	unavailable   6
    }
}

proc ::RosterAvatar::InitDB { } {
    global this
    variable initedDB
    variable avatar
    variable avatarSize
    variable avatarDefault 
        
    # Style specific db options:
    option add *Roster.avatar:indent   16  widgetDefault

    # Use option database for customization. 
    # We use a specific format: 
    #   element options:    rosterStyle:elementName-option
    #   style options:      rosterStyle:styleName:elementName-option

    array set uFont [font actual CociDefaultFont]
    set uFont(-underline) 1
    set underlineFont [eval font create [array get uFont]]

    set fillT {white {selected focus} black {selected !focus}}
    set fillZ {white {selected focus} "#535353"  {}}
    set fillM {blue {mouseover}} 
    set fontU [list $underlineFont {mouseover}]
    set fillF [concat $fillT $fillM]
    set fontF [list $underlineFont {mouseover} CociDefaultFont {}]
    set imop [::Rosticons::Get application/folder-open]
    set imcl [::Rosticons::Get application/folder-closed]
    set imageF [list $imop {open} $imcl {!open}]
    set fillB [list $this(sysHighlight) {selected focus} gray {selected !focus}]
    
    # Get default avatar.
    set f [file join $this(avatarPath) $avatarSize $avatarDefault.png]
    set avimage [image create photo -file $f]
    set avatar(default) $avimage
    
    # Element options:
    option add *Roster.avatar:eAvatarImage-image      $avimage          widgetDefault
    option add *Roster.avatar:eAvBorder-outline       "#bebebe"         widgetDefault
    option add *Roster.avatar:eAvBorder-outlinewidth  1                 widgetDefault
    option add *Roster.avatar:eAvBorder-fill          ""                widgetDefault
    option add *Roster.avatar:eText-font              CociDefaultFont   widgetDefault
    option add *Roster.avatar:eText-fill              $fillT            widgetDefault
    option add *Roster.avatar:eFolderText-font        $fontF            widgetDefault
    option add *Roster.avatar:eFolderText-fill        $fillF            widgetDefault
    option add *Roster.avatar:eFolderImage-image      $imageF           widgetDefault
    option add *Roster.avatar:eNumText-font           CociDefaultFont   widgetDefault
    option add *Roster.avatar:eNumText-fill           blue              widgetDefault
    option add *Roster.avatar:eOnText-font            CociDefaultFont   widgetDefault
    option add *Roster.avatar:eOnText-fill            $fillT            widgetDefault
    option add *Roster.avatar:eOffText-font           CociDefaultFont   widgetDefault
    option add *Roster.avatar:eOffText-fill           $fillZ            widgetDefault
    option add *Roster.avatar:eBorder-outline         white             widgetDefault
    option add *Roster.avatar:eBorder-outlinewidth    1                 widgetDefault
    option add *Roster.avatar:eBorder-fill            $fillB            widgetDefault

    # If no background image:
    option add *Roster.avatar:eBorder-outline:nbg      gray              widgetDefault
    option add *Roster.avatar:eBorder-outlinewidth:nbg 0                 widgetDefault

    # Style layout options:
    option add *Roster.avatar:styAvailable:eOnText-padx         4       widgetDefault
    option add *Roster.avatar:styAvailable:eAltImage-padx       2       widgetDefault
    option add *Roster.avatar:styAvailable:eAvBorder-padx       1       widgetDefault
    option add *Roster.avatar:styAvailable:eAvBorder-pady       {1 2}   widgetDefault

    option add *Roster.avatar:styUnavailable:eOffText-padx      4       widgetDefault
    option add *Roster.avatar:styUnavailable:eAltImage-padx     2       widgetDefault
    option add *Roster.avatar:styUnavailable:eAvBorder-padx     1       widgetDefault
    option add *Roster.avatar:styUnavailable:eAvBorder-pady     {1 2}   widgetDefault

    option add *Roster.avatar:styFolder:eImage-padx             2       widgetDefault
    option add *Roster.avatar:styFolder:eFolderText-padx        4       widgetDefault
    option add *Roster.avatar:styFolder:eNumText-padx           4       widgetDefault

    option add *Roster.avatar:styHead:eImage-padx               2       widgetDefault
    option add *Roster.avatar:styHead:eFolderText-padx          4       widgetDefault
    option add *Roster.avatar:styHead:eNumText-padx             4       widgetDefault

    set initedDB 1
}

# RosterAvatar::Configure --
# 
#       Create columns, elements and styles for treectrl.

proc ::RosterAvatar::Configure {_T} {
    global  this
    variable T
    variable avatar
    variable avatarSize
    variable avatarDefault 
    variable rosterStyle
    variable sortColumn
    variable initedDB
    
    set T $_T
    
    if {!$initedDB} {
	InitDB
    }
    
    # This is a dummy option.
    set stripeBackground [option get $T stripeBackground {}]
    set stripes [list $stripeBackground {}]
    set minW $avatarSize
    set minH $avatarSize
    set bd [option get $T columnBorderWidth {}]
    set bg [option get $T columnBackground {}]

    # Three columns: 
    #   0) status
    #   1) the tree 
    #   2) hidden for tags
    $T column create -tag cStatus  \
      -itembackground $stripes -resize 0 -minwidth 32 -button 1  \
      -borderwidth $bd -background $bg
    $T column create -tag cTree    \
      -itembackground $stripes -resize 0 -expand 1 \
      -text [mc {Contact Name}] -button 1 -arrow up -borderwidth $bd \
      -background $bg
    $T column create -tag cTag     \
      -visible 0
    $T configure -showheader 1

    # Define a new item state
    if {[lsearch [$T state names] mouseover] < 0} {
	$T state define mouseover
    }
    
    # The elements.
    $T element create eImage       image
    $T element create eAvBorder    rect
    $T element create eAvatarImage image
    $T element create eAltImage    image
    $T element create eOnText      text -lines 1
    $T element create eOffText     text -lines 1
    $T element create eText        text
    $T element create eFolderText  text
    $T element create eFolderImage image
    $T element create eBorder      rect -open new -showfocus 1
    $T element create eNumText     text -lines 1
    $T element create eIndent      rect -fill ""
    
    # Styles collecting the elements.
    set S [$T style create styStatus]
    $T style elements $S {eBorder eImage}
    $T style layout $S eImage  -expand news
    $T style layout $S eBorder -detach 1 -iexpand xy

    set S [$T style create styAvailable]
    $T style elements $S {eBorder eIndent eAvBorder eAvatarImage eAltImage eOnText}
    $T style layout $S eBorder      -detach 1 -iexpand xy
    $T style layout $S eAvBorder    -union {eAvatarImage}
    $T style layout $S eAvatarImage -expand ns -minheight $minH -minwidth $minW
    $T style layout $S eAltImage    -expand ns
    $T style layout $S eOnText      -squeeze x -expand ns

    set S [$T style create styUnavailable]
    $T style elements $S {eBorder eIndent eAvBorder eAvatarImage eAltImage eOffText}
    $T style layout $S eBorder      -detach 1 -iexpand xy
    $T style layout $S eAvBorder    -union {eAvatarImage}
    $T style layout $S eAvatarImage -expand ns -minheight $minH -minwidth $minW
    $T style layout $S eAltImage    -expand ns
    $T style layout $S eOffText     -squeeze x -expand ns

    set S [$T style create styFolder]
    $T style elements $S {eBorder eFolderImage eFolderText eNumText}
    $T style layout $S eFolderText -squeeze x -expand ns
    $T style layout $S eNumText -squeeze x -expand ns
    $T style layout $S eFolderImage -expand ns -minheight $minH
    $T style layout $S eBorder -detach 1 -iexpand xy -indent 0

    # Use this for transport and pending folders.
    set S [$T style create styHead]
    $T style elements $S {eBorder eImage eFolderText eNumText}
    $T style layout $S eBorder -detach 1 -iexpand xy -indent 0
    $T style layout $S eImage -expand ns -minheight $minH
    $T style layout $S eFolderText -squeeze x -expand ns
    $T style layout $S eNumText -squeeze x -expand ns

    set S [$T style create styTag]
    $T style elements $S {eText}
    
    $T configure -defaultstyle {styStatus {}}
    
    $T notify install <Header-invoke>
    $T notify bind $T <Selection>      { ::RosterTree::Selection }
    $T notify bind $T <Expand-after>   { ::RosterTree::OpenTreeCmd %I }
    $T notify bind $T <Collapse-after> { ::RosterTree::CloseTreeCmd %I }
    $T notify bind $T <Header-invoke>  { ::RosterAvatar::HeaderCmd %T %C }
    
    set sortColumn cTree

    ::RosterTree::DBOptions $rosterStyle

 
    ::Avatar::Configure -autoget 1 -command ::RosterAvatar::OnAvatarPhoto
    
    # We shall get avatars for all users.
    ::Avatar::GetAll
}

proc ::RosterAvatar::Sort {item order} {
    variable T
    variable sortColumn
    
    array set arrowMap {
	-increasing   up
	-decreasing   down
    }
    
    if {[$T item compare $item == "root"]} {
	$T column configure $sortColumn -arrow $arrowMap($order)
	SortColumn $sortColumn $order
    }
}

proc ::RosterAvatar::HeaderCmd {T C} {
    variable sortColumn
	    
    if {[$T column compare $C == $sortColumn]} {
	if {[$T column cget $sortColumn -arrow] eq "down"} {
	    set order -increasing
	    set arrow up
	} else {
	    set order -decreasing
	    set arrow down
	}
    } else {
	if {[$T column cget $sortColumn -arrow] eq "down"} {
	    set order -decreasing
	    set arrow down
	} else {
	    set order -increasing
	    set arrow up
	}
	$T column configure $sortColumn -arrow none
	set sortColumn $C
    }
    $T column configure $C -arrow $arrow
    
    SortColumn $C $order
}

proc ::RosterAvatar::SortColumn {C order} {
    variable T

    # Keep transports and pending always at the end.
    set opts {}
    
    # Be sure to have transport & pending last.
    # Shall only test this if not alone.
    if {[$T item numchildren root] > 1} {
	foreach type {transport pending} {
	    set tag [list head $type]
	    set item [FindWithTag $tag]
	    if {$item ne ""} {		
		$T item lastchild root $item
		set last [list $item above]
		set ancestors [$T item ancestors [list $item above]]
		if {[llength $ancestors] > 1} {
		    set last [lindex $ancestors end-1]
		}
		set opts [list -last $last]
	    }
	}
    }
    
    switch -- [$T column cget $C -tag] {
	cTree {
	    eval {$T item sort root $order -column $C} $opts
	}
	cStatus {
	    set cmd [namespace current]::SortStatus
	    eval {$T item sort root $order -column $C -command $cmd} $opts
	}
    }
    return
}

# RosterAvatar::SortStatus --
# 
#       Sort command:
#           Folders before users
#           Users ordered after their 'statusOrder'
#           If otherwise identical sort after names

proc ::RosterAvatar::SortStatus {item1 item2} {
    variable T
    variable statusOrder
    variable jidStatus

    set n1 [$T item numchildren $item1]
    set n2 [$T item numchildren $item2]

    if {$n1 && !$n2} {
	set ans -1
    } elseif {!$n1 && $n2} {
	set ans 1
    } elseif {$n1 > 0 && $n2 > 0} {
	set text1 [$T item text $item1 cTree]
	set text2 [$T item text $item2 cTree]
	set ans [string compare $text1 $text2]
    } else {
	set tag1 [::RosterTree::GetTagOfItem $item1]
	set tag2 [::RosterTree::GetTagOfItem $item2]
	set 0tag1 [lindex $tag1 0]
	set 0tag2 [lindex $tag2 0]
	
	if {($0tag1 eq "jid") && ($0tag2 eq "jid")} {
	    set jid1 [lindex $tag1 1]
	    set jid2 [lindex $tag2 1]
	    set so1 $statusOrder($jidStatus($jid1))
	    set so2 $statusOrder($jidStatus($jid2))
	    if {$so1 == $so2} {
		set text1 [$T item text $item1 cTree]
		set text2 [$T item text $item2 cTree]
		set ans [string compare $text1 $text2]
	    } elseif {$so1 > $so2} {
		set ans 1
	    } else {
		set ans -1
	    }
	} elseif {$0tag1 eq "jid"} {
	    set ans 1
	} elseif {$0tag2 eq "jid"} {
	    set ans -1
	} else {
	    set ans 0
	}
    }
    return $ans
}

# RosterAvatar::Init --
# 
#       Creates the items for the initial logged out state.
#       It starts by removing all content.

proc ::RosterAvatar::Init { } {
    variable T
    upvar ::Jabber::jprefs jprefs
        
    $T item delete all
    ::RosterTree::FreeTags
}

# RosterAvatar::OnAvatarPhoto --
# 
#       Callback from Avatar when there is a new image or the image has been
#       removed.

proc ::RosterAvatar::OnAvatarPhoto {type jid2} {
    
    ::Debug 4 "::RosterAvatar::OnAvatarPhoto type=$type, jid2=$jid2"

    SetAvatarImage $type $jid2
}

proc ::RosterAvatar::SetAvatarImage {type jid2} {
    variable T
    variable avatar
    variable avatarSize
    
    ::Debug 4 "::RosterAvatar::SetAvatarImage jid2=$jid2"
	
    # @@@ Not the best solution...
    # The problem is with JEP-0008 mixing jid2 with jid3.
    # FAILS for vcard avatars!
    set jid [::Jabber::JlibCmd avatar get_full_jid $jid2]
    set tag [list jid $jid]
    set item [FindWithTag $tag]
    if {$item ne ""} {
	
	switch -- $type {
	    create - put {
		set image [::Avatar::GetPhotoOfSize $jid2 $avatarSize]
		$T item element configure $item cTree eAvatarImage  \
		  -image $image

		# @@@ We get problems with this since only the _element_ is
		#     configured with an image to start with.
		#     
		#set im [$T item element cget $item cTree eAvatarImage -image]
		#if {$im ne $image} {
		#    $T item element configure $item cTree eAvatarImage  \
		#      -image $image
		#}
	    }
	    remove {
		$T item element configure $item cTree eAvatarImage  \
		  -image $avatar(default)
	    }
	}
    }
}

proc ::RosterAvatar::Delete { } {
    
    ::Avatar::Configure -autoget 0 -command ""
}

# RosterAvatar::CreateItem --
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

proc ::RosterAvatar::CreateItem {jid presence args} {    
    variable T
    variable jidStatus
    variable rosterStyle
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 4 "::RosterAvatar::CreateItem jid=$jid, presence=$presence"

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

    array set styleMap {
	available    styAvailable 
	unavailable  styUnavailable
    }
    array set tElemMap {
	available   eOnText
	unavailable eOffText
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
    set mjid [jlib::jidmap $jidx]
    
    # Defaults:
    set jtext  [eval {MakeDisplayText $jid $presence} $args]
    set jimage [eval {GetPresenceIcon $jidx $presence} $args]
    set items  {}
    set jitems {}
        
    set status $presence
    if {[info exists argsArr(-show)]} {
	set status $argsArr(-show)
    }
    if {$istrpt} {
	set type transport
    } elseif {[info exists argsArr(-ask)] && ($argsArr(-ask) eq "subscribe")} {
	set type pending
    } else {
	set type jid
    }
    set tag  [list $type $mjid]
    set style $styleMap($presence)
    set elem $tElemMap($presence)
    set jidStatus($mjid) $status
    set item [CreateWithTag $tag $style $elem $jtext $jimage root]
    lappend items $item
    
    if {$presence eq "available"} {
	if {[::Avatar::HavePhoto $jid2]} {
	    SetAvatarImage put $jid2
	}
    }

    if {($type eq "transport") || ($type eq "pending")} {
	set ptag [list head $type]
	set ptext  [::RosterTree::MCHead $type]
	set pimage [::Rosticons::Get application/$type]
	set pitem [PutItemInHead $item $ptag $ptext $pimage]
	set n [llength [$T item children $pitem]]
	$T item element configure $pitem cTree eNumText -text "($n)"
    } elseif {[info exists argsArr(-groups)] && ($argsArr(-groups) ne "")} {
	
	# Group(s):
	#set image [::Rosticons::Get application/group-online]
	set w [::Roster::GetRosterWindow]
	set indent [option get $w ${rosterStyle}:indent {}]

	foreach group $argsArr(-groups) {
	    set ptag [list group $group]
	    set pitem [FindWithTag $ptag]
	    if {$pitem eq ""} {
		set pitem [CreateWithTag $ptag styFolder eFolderText $group "" root]
		#$T item element configure $pitem cTree eImage -image $image 
		SetMouseOverBinds $pitem
	    }
	    $T item lastchild $pitem $item
	    $T item element configure $item cTree eIndent -width $indent
	}
    } else {
	# empty
    }

    # Update any groups.
    foreach item [::RosterTree::FindWithFirstTag group] {
	set n [llength [$T item children $item]]
	$T item element configure $item cTree eNumText -text "($n)"
    }

    return $items
}

proc ::RosterAvatar::PutItemInHead {item ptag ptext pimage} {
    variable T
    variable rosterStyle
    
    set w [::Roster::GetRosterWindow]
    set indent [option get $w ${rosterStyle}:indent {}]

    set pitem [FindWithTag $ptag]
    if {$pitem eq ""} {
	set pitem [CreateWithTag $ptag styHead eFolderText $ptext "" root]
	$T item element configure $pitem cTree eImage -image $pimage 
	SetMouseOverBinds $pitem
    }
    $T item lastchild $pitem $item
    $T item element configure $item cTree eIndent -width $indent

    return $pitem
}

proc ::RosterAvatar::SetMouseOverBinds {pitem} {
    variable T

    set cmd { ::RosterAvatar::OnButton1 %I }
    ::treeutil::bind $T $pitem <ButtonPress-1> $cmd
    ::treeutil::bind $T $pitem <Enter> { 
	%T item state set %I  mouseover
	%T configure -cursor hand2
    }
    ::treeutil::bind $T $pitem <Leave> { 
	%T item state set %I !mouseover 
	%T configure -cursor ""
    }
}

proc ::RosterAvatar::OnButton1 {item} {
    variable T
    
    $T item toggle $item
}

# RosterAvatar::DeleteItem --
# 
#       Deletes all items associated with jid.
#       It is also responsible for cleaning up empty dirs etc.

proc ::RosterAvatar::DeleteItem {jid} {
    variable jidStatus
 
    ::Debug 2 "::RosterAvatar::DeleteItem, jid=$jid"
    
    # Sibling of '::RosterTree::CreateItemBase'.
    ::RosterTree::DeleteItemBase $jid
    
    # Delete any empty leftovers.
    ::RosterTree::DeleteEmptyGroups
    ::RosterTree::DeleteEmptyPendTrpt
    
    unset -nocomplain jidStatus($jid)
}

proc ::RosterAvatar::CreateItemFromJID {jid} {    
    upvar ::Jabber::jstate jstate
    
    jlib::splitjid $jid jid2 res
    set pres [$jstate(roster) getpresence $jid2 -resource $res]
    set rost [$jstate(roster) getrosteritem $jid2]
    array set opts $pres
    array set opts $rost

    return [eval {CreateItem $jid $opts(-type)} [array get opts]]
}

proc ::RosterAvatar::SetItemAlternative {jid key type value} {

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
proc ::RosterAvatar::SetAltImage {jid key image} {
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

proc ::RosterAvatar::CreateWithTag {tag style tElem text image parent} {
    variable T
    
    # Base class constructor. Handles the cTag column and tag.
    set item [::RosterTree::CreateWithTag $tag $parent]
    
    $T item style set $item cTree $style
    $T item element configure $item  \
      cStatus eImage -image $image ,  \
      cTree   $tElem -text  $text

    return $item
}

proc ::RosterAvatar::DeleteWithTag {tag} {
    return [::RosterTree::DeleteWithTag $tag]
}

proc ::RosterAvatar::FindWithTag {tag} {    
    return [::RosterTree::FindWithTag $tag]
}

proc ::RosterAvatar::MakeDisplayText {jid presence args} {
    return [eval {::RosterTree::MakeDisplayText $jid $presence} $args]
}

proc ::RosterAvatar::GetPresenceIcon {jid presence args} {
    return [eval {::Roster::GetPresenceIcon $jid $presence} $args]
}

proc ::RosterAvatar::GetPresenceIconFromJid {jid} {
    return [::Roster::GetPresenceIconFromJid $jid]
}

proc ::RosterAvatar::Balloon {jid presence item args} {    
    eval {::RosterTree::Balloon $jid $presence $item} $args
}

proc ::RosterAvatar::TreeConfigureHook {args} {
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

# RosterAvatar::DiscoInfoHook --
# 
#       It is first when we have obtained either browse or disco info it is
#       possible to set icons of foreign IM users.

proc ::RosterAvatar::DiscoInfoHook {type from subiq args} {
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

# RosterAvatar::PostProcess --
# 
#       This is necessary to get icons for foreign IM systems set correctly.
#       Usually we get the roster before we've got disco 
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

proc ::RosterAvatar::PostProcess {method from} {
    
    ::Debug 4 "::RosterAvatar::PostProcess $from"

    if {[string equal $method "browse"]} {
	set matchHost 0
	PostProcessItem $from $matchHost root
    } elseif {[string equal $method "disco"]} {
	PostProcessDiscoInfo $from
    }    
}

proc ::RosterAvatar::PostProcessDiscoInfo {from} {
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
		    $T item image $item cStatus $icon
		}
	    }
	}
    }
}

proc ::RosterAvatar::PostProcessItem {from matchHost item} {
    variable T    
    
    if {[$T item numchildren $item]} {
	foreach citem [$T item children $item] {
	    PostProcessItem $from $matchHost $citem
	}
    } else {
	set tags [$T item element cget $item cTag eOnText -text]
	set tag0 [lindex $tags 0]
	if {($tag0 eq "transport") || ($tag0 eq "jid")} {
	    set jid [lindex $tags 1]
	    jlib::splitjidex $jid username host res
	    
	    # Consider only relevant jid's:
	    # Browse always, disco only if from == host.
	    if {!$matchHost || [string equal $from $host]} {
		set icon [GetPresenceIconFromJid $jid]
		if {$icon ne ""} {
		    $T item image $item cStatus $icon
		}
	    }
	}
    }
}
