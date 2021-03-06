#  RosterTree.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the roster tree using treectrl.
#      
#  Copyright (c) 2005-2008  Mats Bengtsson
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
# $Id: RosterTree.tcl,v 1.110 2008-08-07 14:57:20 matben Exp $

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

package require TreeCtrlDnD

package provide RosterTree 1.0

namespace eval ::RosterTree {

    ::hooks::register initHook               ::RosterTree::InitHook
    ::hooks::register logoutHook             ::RosterTree::LogoutHook
    ::hooks::register quitAppHook            ::RosterTree::QuitHook
    ::hooks::register menuJMainFilePostHook  ::RosterTree::FileMenuPostHook
    ::hooks::register menuJMainEditPostHook  ::RosterTree::EditMenuPostHook
    ::hooks::register onMenuVCardExport      ::RosterTree::OnMenuExportVCardHook
    ::hooks::register nicknameEventHook      ::RosterTree::NicknameEventHook

    # Actual:
    option add *RosterTree.borderWidth        0               50
    option add *RosterTree.relief             flat            50
    #option add *Roster*TreeCtrl.indent          18              widgetDefault

    # Fake:
#     option add *Roster*TreeCtrl.rosterImage     cociexec    widgetDefault
    option add *Roster*TreeCtrl.rosterImage    roster-default   widgetDefault

    # This is tuned with the control slots so that the close buttons line up.
    option add *Roster*TSearch.padding    {6 2 2 2}          50

    # @@@ Should get this from a global reaource.
    variable buttonPressMillis 1000

    # Head titles.
    variable mcHead
    array set mcHead [list \
      available     [mc "Online"]         \
      unavailable   [mc "Offline"]        \
      transport     [mc "Transports"]     \
      pending       [mc "Subscription Pending"]]
    
    # How should JIDs be formatted before export to DnD?
    # Alternative "xmpp:%s?message"
    set ::config(rost,dnd-xmpp-uri-format) "xmpp:%s"
}

namespace eval ::RosterTree {
    
    variable dndSrc
    array set dndSrc {
	suffix,win32    .URL
	suffix,x11      .desktop
	content,win32   "\[InternetShortcut\]\nURL=%s"
	content,x11     "\[Desktop Entry\]\nEncoding=UTF-8\nIcon=xmpp\nType=Link\nURL=%s"
	suffix,aqua     .xxx
	content,aqua    ""
    }    
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
#       The roster item may not be displayed, for instance, there can be
#       a higher resource set.
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
	    
    treectrl $T -selectmode extended  \
      -showroot 0 -showrootbutton 0 -showbuttons 1 -showheader 0  \
      -xscrollcommand [list ::UI::ScrollSetStdGrid $wxsc     \
      [list grid $wxsc -row 1 -column 0 -sticky ew]]         \
      -yscrollcommand [list ::UI::ScrollSetStdGrid $wysc     \
      [list grid $wysc -row 0 -column 1 -sticky ns]]         \
      -borderwidth 0 -highlightthickness 0 -height 0 -width 0
    
    SetBinds
    $T configure -backgroundimage [BackgroundImageGet]
    $T notify bind $T <Selection> {+::RosterTree::Selection }
    
    # RosterTreeTag will be first.
    bindtags $T [concat RosterTreeTag [bindtags $T]]
    
    # This automatically cleans up the tag array.
    $T notify bind RosterTreeTag <ItemDelete> {
	foreach item %i {
	    ::RosterTree::RemoveTags $item
	} 
    }
    
    # Need a post TreeCtrl bind tag for ThemeChanged.
    set idx [lsearch [bindtags $T] TreeCtrl]
    bindtags $T [linsert [bindtags $T] [incr idx] TreeCtrlPost]
    
    StyleConfigure $wtree
    StyleInit

    ttk::scrollbar $wxsc -command [list $wtree xview] -orient horizontal
    ttk::scrollbar $wysc -command [list $wtree yview] -orient vertical

    grid  $wtree  -row 0 -column 0 -sticky news
    grid  $wysc   -row 0 -column 1 -sticky ns
    grid  $wxsc   -row 1 -column 0 -sticky ew
    grid columnconfigure $w 0 -weight 1
    grid rowconfigure    $w 0 -weight 1
    
    # DnD:
    set idx [lsearch [bindtags $T] TreeCtrl]
    bindtags $T [linsert [bindtags $T] $idx TreeCtrlDnD]
    
    $T notify install <Drag-begin>
    $T notify install <Drag-end>
    $T notify install <Drag-receive>
    $T notify install <Drag-enter>
    $T notify install <Drag-leave>
    
    $T notify bind $T <Drag-receive> {
	::RosterTree::NotifyDragReceive %W %l %I
    }    
    if {[tk windowingsystem] ne "aqua"} {
	if {![catch {package require tkdnd}]} {
	    InitDnD $T
	}
    }

    return $T
}

# DnD files to roster items.

proc ::RosterTree::InitDnD {win} {
    
    # Targets:
    dnd bindtarget $win text/uri-list <Drop> {
	::RosterTree::DnDDrop %W %D %T %x %y
    }
    dnd bindtarget $win text/uri-list <Drag> {
	::RosterTree::DnDDrag %W %A %a %D %T %x %y
    }
    dnd bindtarget $win text/uri-list <DragEnter> {
	::RosterTree::DnDEnter %W %A %D %T
    }
    dnd bindtarget $win text/uri-list <DragLeave> {
	::RosterTree::DnDLeave %W %D %T
    }

    # Sources, export both xmpp:JID as text and as a file:
    dnd bindsource $win {text/plain;charset=UTF-8} { 
	::RosterTree::DnDTextSource %W
    }
    dnd bindsource $win text/uri-list { 
	::RosterTree::DnDFileSource %W
    }
    
    # Need to bind on Leave else we destroy the TreeCtrl DnD bindings.
    bind $win <Button1-Leave> { dnd drag %W }
}

# RosterTree::DnDTextSource --
# 
#       Defines what to "export" from roster when dragging to the desktop.

proc ::RosterTree::DnDTextSource {win} {
    global  config
        
    # We shall export a format other applications have a chance to understand.
    # Our own targets must also understand this format.
    set fmt $config(rost,dnd-xmpp-uri-format)
    set jidL [lapply [list format $fmt] [lapply jlib::barejid [GetExtSelectedJID]]]
    set data [join $jidL ", "]
    return $data
}

# RosterTree::DnDFileSource --
# 
#       Defines what to "export" from roster when dragging to the desktop.

proc ::RosterTree::DnDFileSource {win} {
    global  this
    variable dndSrc

    set os [tk windowingsystem]
    set jidL [lapply jlib::jidmap [lapply jlib::barejid [GetExtSelectedJID]]]
    set fileL [list]
    foreach jid $jidL {
	set fileName [file join $this(tmpPath) [::uri::urn::quote $jid]]$dndSrc(suffix,$os)
	set fd [open $fileName w]
	puts $fd [format $dndSrc(content,$os) "xmpp:$jid?message"]
 	close $fd
	# @@@ Do I need a "file://" prefix?
	#lappend fileL $fileName
	lappend fileL "file://$fileName"
    }

    return $fileL
}

proc ::RosterTree::DnDDrop {win data dndtype x y} {

    set T $win
    set f [lindex $data 0]
    set f [string map {"file://" ""} $f]
    set f [::uri::urn::unquote $f]
    set id [$T identify $x $y]
    if {[lindex $id 0] eq "item"} {
	lassign $id where item arg1 arg2 arg3 arg4
	if {($arg1 eq "column") && ($arg3 eq "elem")} {
	    set tag [GetTagOfItem $item]
	    if {[lindex $tag 0] eq "jid"} {
		set jid [lindex $tag 1]
		if {[::Jabber::Jlib roster isavailable $jid]} {
		    ::FTrans::Send $jid -filename $f
		}
	    }
	}
    }
}

proc ::RosterTree::DnDDrag {win action actions data dndtype x y} {
    
    set T $win
    set id [$T identify $x $y]
    set act "none"
    $T selection clear

    if {[lindex $id 0] eq "item"} {
	lassign $id where item arg1 arg2 arg3 arg4
	if {($arg1 eq "column") && ($arg3 eq "elem")} {
	    set tag [GetTagOfItem $item]
	    if {[lindex $tag 0] eq "jid"} {
		set jid [lindex $tag 1]
		if {[::Jabber::Jlib roster isavailable $jid]} {
		    $T selection add $item
		    set act "copy"
		}
	    }
	}
    }
    return $act
}

proc ::RosterTree::DnDEnter {win action data dndtype} {
    focus $win
    set act "none"
    return $act
}

proc ::RosterTree::DnDLeave {win data dndtype} {	
    focus [winfo toplevel $win] 
}

# copy or move a contacts between roster groups
# a contact can be a member of multiple groups
proc ::RosterTree::NotifyDragReceive {T dragged target} {
    global  wDlgs
    variable popMenuDefs

    set jlib [::Jabber::GetJlib]
        
    # Protect for a situation where items have disapperared.
    if {[$T item id $target] eq ""} {
	return
    }

    # Find target group or empty.
    set tag [GetTagOfItem $target]
    set tag0 [lindex $tag 0]
    if {$tag0 eq "jid"} {
	set parent [$T item parent $target]
	# some styles, like the avatar, do not have a "head"
	if {$parent eq 0} {
	    set tgroup ""
	} else {
	    set ptag [GetTagOfItem $parent]
	    set ptag0 [lindex $ptag 0]
	    if {$ptag0 eq "group"} {
	        set tgroup [list [lindex $ptag 1]]
	    } elseif {$ptag0 eq "head"} {
	        set tgroup ""
	    } else {
	        return
	    }
	}
    } elseif {$tag0 eq "group"} {
	set tgroup [list [lindex $tag 1]]
    } elseif {$tag0 eq "head"} {
	set tgroup ""	
    } else {
	return
    }
    # due to the fact that a contact can belong to
    # multiple groups, we need to ask the user whether
    # he wants to copy or move the contact to the new group
    # using a small popup menu
    set m $wDlgs(jpopuproster)
    destroy $m
    menu $m -tearoff 0
    set mDef $popMenuDefs(rostertree,dnd,def)
    set mType $popMenuDefs(rostertree,dnd,type)

    ::AMenu::Build $m $mDef -varlist [list T $T dragged $dragged tgroup $tgroup]
    # put the popup menu below the mouse pointer
    set X [winfo pointerx $T]
    set Y [winfo pointery $T]
    tk_popup $m [expr {int($X) - 10}] [expr {int($Y) - 10}]
}

proc ::RosterTree::DnDCopyOrMoveContact {T action dragged targetgroup} {
    set jlib [::Jabber::GetJlib]
    if {$action eq "cancel"} {
	return
    }
    foreach item $dragged {
        set jid ""
        set origgroups ""
        set sparent ""
        set sptag ""
        set tag ""
        if {[$T item id $item] eq ""} {
            continue
        }
        set tag [GetTagOfItem $item]
        if {[lindex $tag 0] eq "jid" } {
            set jid [lindex $tag 1]
            set jid [$jlib roster getrosterjid $jid]
            # because the user can be a member of multiple groups, we need to figure
            # out to which groups the user actually belongs to
            set origgroups [::Jabber::Jlib roster getgroups $jid]
            if { $action eq "copy" } {
                set groups [lsearch -all -inline -not -exact $origgroups $targetgroup]
                lappend groups $targetgroup
                set groups [lsort -unique $groups]
            } else {
                # when we move the contact, we also need to know the group from which
                # the contact needs to be removed
                set sparent [$T item parent $item]
		# some styles do not have a "head" in the tree
		if {$sparent eq 0} {
                    set groups [lappend origgroups $targetgroup]
                    set groups [lsort -unique $groups]
		} else {
                    set sptag [GetTagOfItem $sparent]
                    if {[lindex $sptag 0] eq "group" } {
                        set sgroup [lindex $sptag 1]
                        set groups [lsearch -all -inline -not -exact $origgroups $sgroup]
                        lappend groups $targetgroup
                        set groups [lsort -unique $groups]
                    } elseif {[lindex $sptag 0] eq "head" } {
                        set groups [lappend origgroups $targetgroup]
                        set groups [lsort -unique $groups]
                   }
               }
	    }
            array unset rostA
            set rostA(-groups) [list]
            array set rostA [$jlib roster getrosteritem $jid]
            if {[lsort $rostA(-groups)] ne $groups} {
                unset -nocomplain rostA(-subscription)
                set rostA(-groups) $groups
                eval {$jlib roster send_set $jid} [array get rostA]
            }

        }
    }
}

proc ::RosterTree::SetBinds {} {
    variable T

    # @@@ perhaps a new bindtag instead?
    # We need to do this each time a new style is loaded since all binds
    # have been removed to allow for 'EditSetBinds'.
    bind $T <Button-1>        {+::RosterTree::OnButtonPress %x %y }        
    bind $T <ButtonRelease-1> {+::RosterTree::OnButtonRelease %x %y }        
    bind $T <Double-1>        {+::RosterTree::OnDoubleClick %x %y }        
    bind $T <<ButtonPopup>>   {+::RosterTree::OnPopup %x %y }
    bind $T <Destroy>         {+::RosterTree::OnDestroy }
    bind $T <Key-Return>      {+::RosterTree::OnReturn }
    bind $T <KP_Enter>        {+::RosterTree::OnReturn }
    bind $T <Key-BackSpace>   {+::RosterTree::OnBackSpace }
    bind $T <Button1-Motion>  {+::RosterTree::OnButtonMotion %x %y }
    bind $T <FocusOut>        {+::RosterTree::OnFocusOut }
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
	    UI::TSearch $wfind $T $column \
	      -closecommand [namespace code FindDestroy]
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
    set wmaster [winfo parent $wfind]
    destroy $wfind
    
    # Workaround for the grid bug.
    after idle [list grid rowconfigure $wmaster 2 -minsize 0]
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
	if {[$T selection count] == 1} {
	    set id [$T identify $x $y]
	    if {$id eq $editTimer(id)} {
		
		# The balloonhelp window on Mac takes focus. Stop it.
		::balloonhelp::cancel
		uplevel #0 $editBind(cmd) [list $id]
	    }
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
        
    set jid [::Jabber::Jlib roster getrosterjid $jid]
    set groups [::Jabber::Jlib roster getgroups $jid]
    ::Jabber::Jlib roster send_set $jid -name $name -groups $groups
    focus $T
}

proc ::RosterTree::EditEnd {jid} {
    variable T
    
    # Restore item with its original style.
    set jid [::Jabber::Jlib roster getrosterjid $jid]
    eval {::Roster::SetItem $jid} [::Jabber::Jlib roster getrosteritem $jid]
}

proc ::RosterTree::EditTimerCancel {} {
    variable editTimer

    if {[info exists editTimer(after)]} {
	after cancel $editTimer(after)
    }
    unset -nocomplain editTimer
}

# BackgroundImage... Try to make as generic as possible!

# RosterTree::BackgroundImageCmd --
# 
#       There are two separate ways the current background image may be selected:
#         1) as defined by the theme
#         2) a user picked one which is cached in this(backgroundsPath)

proc ::RosterTree::BackgroundImageCmd {} {
    global  this jprefs
    variable T
    
    set mimes [list image/gif image/png image/jpeg]
    set suffL [::Media::GetSupportedSuffixesForMimeList $mimes]
    set typeL [::Media::GetSupportedTypesForMimeList $mimes]
    set types [concat [list [list {Image Files} $suffL]] \
      [::Media::GetDlgFileTypesForMimeList $mimes]]
    
    # Default file (as defined by the theme):
    set defaultFile [BackgroundImageGetThemedFile $suffL]
    
    # Current file:
    set currentFile [BackgroundImageGetFile $suffL $defaultFile]

    # Dialog:
    set typeText [join $typeL ", "]
    # TRANSLATORS: to set background image in services or contacts tab
    set str [mc "Select an image file for the background. To remove a background image press Remove and Save."]
    set dtl [mc "The supported image formats are"]
    append dtl " " $typeText
    append dtl "."
    set mbar [::JUI::GetMainMenu]
    ::UI::MenubarDisableBut $mbar edit
    set fileName [ui::openimage::modal -message $str -detail $dtl -menu $mbar \
      -filetypes $types -initialfile $currentFile -defaultfile $defaultFile \
      -geovariable prefs(winGeom,jbackgroundimage) -title [mc "Background Image"]]
    ::UI::MenubarEnableAll $mbar

    set image ""
    if {$fileName eq ""} {
	return
    } elseif {$fileName eq "-"} {
	set jprefs(rost,useBgImage) 0
    } elseif {[file exists $fileName]} {
	set fileName [file normalize $fileName]
	set jprefs(rost,useBgImage) 1
	if {$fileName eq $defaultFile} {
	    set jprefs(rost,defaultBgImage) 1
	} else {
	    set jprefs(rost,defaultBgImage) 0
	}
	
	# Don't copy file if it is already there.
	set suff [file extension $fileName]
	set dst [file normalize [file join $this(backgroundsPath) roster$suff]]
	
	# Cache file. There shall only be one roster.* file there.
	if {$fileName ne $dst} {
	    
	    # Clear roster.* cache.
	    ::tfileutils::deleteallfiles $this(backgroundsPath) roster.*
	    set suff [file extension $fileName]
	    file copy -force $fileName $dst
	}	
	if {[catch {
	    set image [image create photo -file $fileName]
	}]} {
	    set image ""
	}
    }    
    BackgroundImageConfig $image
}

proc ::RosterTree::BackgroundImageGetThemedFile {suffL} {
    variable T
    
    set name [option get $T rosterImage {}]
    set fileName [::Theme::FindIconFileWithSuffixes backgrounds/$name $suffL]
    return [file normalize $fileName]
}

# RosterTree::BackgroundImageGetFile --
#
#       Return empty if not configured with background image.

proc ::RosterTree::BackgroundImageGetFile {suffL defaultFile} {
    global  this jprefs
    
    set fileName ""
    if {$jprefs(rost,useBgImage)} {
	if {$jprefs(rost,defaultBgImage)} {
	    set fileName $defaultFile
	} else {
	    set pattern [list]
	    foreach suff $suffL {
		lappend pattern "roster$suff"
	    }    
	    set files [eval {glob -nocomplain -directory $this(backgroundsPath)} -- $pattern]
	    set fileName [lindex $files 0]
	}
    }    
    return $fileName
}

proc ::RosterTree::BackgroundImageGet {} {
        
    # This gets called only during creation and we make a shortcut
    # to avoid loading slow packages (QuickTimeTcl etc.)
    set image ""
    set mimes [list image/gif image/png image/jpeg]
    set suffL [::Types::GetSuffixListForMimeList $mimes]   
    set fileName [BackgroundImageGetFile $suffL \
      [BackgroundImageGetThemedFile $suffL]]
    if {[file exists $fileName]} {
	if {[catch {
	    set image [image create photo -file $fileName]
	}]} {
	    # If any custom image has been removed we just ignore it.
	    set image ""
	}
    }
    return $image
}

proc ::RosterTree::BackgroundImageConfig {image} {
    variable T
    
    # Garbage collection.
    set old [$T cget -backgroundimage]
    $T configure -backgroundimage $image
    if {$old ne ""} {
	image delete $old
    }    
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
    
    foreach jid [GetSelectedJID] {
	ActionDoubleClick $jid
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

proc ::RosterTree::OnButtonPress {x y} {
    variable T
    variable buttonAfterId
    variable buttonPressMillis

    if {[tk windowingsystem] eq "aqua"} {
	if {[info exists buttonAfterId]} {
	    catch {after cancel $buttonAfterId}
	}
	set cmd [list ::RosterTree::OnPopup $x $y]
	set buttonAfterId [after $buttonPressMillis $cmd]
    }
    set id [$T identify $x $y]
    if {$id eq ""} {
	$T selection clear all
    }
}

proc ::RosterTree::OnButtonRelease {x y} {
    variable T
    variable buttonAfterId
    
    if {[info exists buttonAfterId]} {
	catch {after cancel $buttonAfterId}
	unset buttonAfterId
    }    
}

proc ::RosterTree::OnDoubleClick {x y} {
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
    global jprefs
    
    set jid2 [jlib::barejid $jid]
	    
    if {[string equal $jprefs(rost,dblClk) "normal"]} {
	::NewMsg::Build -to $jid2
    } elseif {[string equal $jprefs(rost,dblClk) "chat"]} {
	if {[::Jabber::Jlib roster isavailable $jid]} {
	    
	    # We let Chat handle this internally.
	    ::Chat::StartThread $jid2
	} else {
	    ::NewMsg::Build -to $jid2
	}
    }
}

proc ::RosterTree::OnButtonMotion {x y} {
    variable buttonAfterId
    
    if {[info exists buttonAfterId]} {
	catch {after cancel $buttonAfterId}
	unset buttonAfterId
    }    
}

proc ::RosterTree::OnFocusOut {} {
    variable buttonAfterId
    
    if {[info exists buttonAfterId]} {
	catch {after cancel $buttonAfterId}
	unset buttonAfterId
    }    
}

# RosterTree::GetSelected --
# 
#       Returns a list of tags of selected items.

proc ::RosterTree::GetSelected {} {
    variable T
    
    set selected [list]
    foreach item [$T selection get] {
	lappend selected [GetTagOfItem $item]
    }
    return $selected
}

# RosterTree::GetSelectedJID --
# 
#       Returns a list of JIDs of selected contacts.

proc ::RosterTree::GetSelectedJID {} {
    
    set jidL [list]
    set tags [GetSelected]
    foreach tag $tags {
	if {[lindex $tag 0] eq "jid"} {
	    lappend jidL [lindex $tag 1]
	}
    }
    return $jidL
}

# RosterTree::GetExtSelectedJID --
# 
#       As 'GetSelectedJID' but searches recursively selected parents as well.

proc ::RosterTree::GetExtSelectedJID {} {
    variable T
    
    set jidL [list]
    foreach item [$T selection get] {
	set tag [GetTagOfItem $item]
	if {[lindex $tag 0] eq "jid"} {
	    lappend jidL [lindex $tag 1]
	} else {
	    set all [$T item descendants $item]
	    foreach aitem $all {
		set tag [GetTagOfItem $aitem]
		if {[lindex $tag 0] eq "jid"} {
		    lappend jidL [lindex $tag 1]
		}
	    }
	}
    }
    return [lsort -unique $jidL]
}

# RosterTree::OnPopup --
# 
#       Treectrl binding for popup event.

proc ::RosterTree::OnPopup {x y} {
    variable T
    
    ::Debug 2 "::RosterTree::OnPopup"

    ::balloonhelp::cancel
    
    set jidL    [list]
    set itemL   [list]
    set groupL  [list]
    
    # 1: Assemble itemL
    set id [$T identify $x $y]    
    if {[lindex $id 0] eq "item"} {
	set selected [$T selection get]
	set item [lindex $id 1]

	# If clicked an unselected item, pick this.
	# If clicked any selected, pick the complete selection.
	if {[lsearch $selected $item] >= 0} {
	    set itemL $selected
	} else {
	    set itemL [list $item]
	}
    }
    
    # 2: From itemL, collect jidL    
    foreach item $itemL {
     	set tags [GetTagOfItem $item]
	set mtag [lindex $tags 0]
	
	switch -- $mtag {
	    jid {
		set jid [lindex $tags 1]
		lappend jidL $jid
	    }
	    group {
		lappend groupL [lindex $tags 1]
		set jidL [concat $jidL [FindAllJIDInItem $item]]
	    }
	    head {
		if {[regexp {(available|unavailable)} [lindex $tags 1]]} {
		    lappend groupL [lindex $tags 1]
		    set jidL [concat $jidL [FindAllJIDInItem $item]]
		}
	    }
	}
    }
    ::Roster::DoPopup $jidL $groupL $x $y
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
    global  jprefs
    variable T

    if {($presence ne "available") && ($presence ne "unavailable")} {
	return
    }
    
    # Filter out those we don't want to see.
    set istrpt [::Roster::IsTransportEx $jid]
    if {$istrpt} {
	if {!$jprefs(rost,showTrpts)} {
	    return
	}	
    } else {
	if {$presence eq "available"} {
	    set show [::Jabber::Jlib roster getshow $jid]
	    if {$show ne ""} {
		if {[info exists jprefs(rost,show-$show)]} {
		    if {!$jprefs(rost,show-$show)} {
			return
		    }
		}
	    }
	} else {
	    if {!$jprefs(rost,showOffline)} {
		return
	    }	    
	}
    }
    array set argsA $args
    set itemTagL [list]

    set mjid [jlib::jidmap $jid]
    
    # Keep track of any dirs created.
    set dirtags [list]
	
    if {$istrpt} {
	
	# Transports:
	set itemTagL [CreateJIDItemWithParent $mjid transport]
	if {[llength $itemTagL] == 4} {
	    lappend dirtags [lindex $itemTagL 1]
	    
	    # Always put pending last, after any transport.
	    set pending [FindWithTag [list head pending]]
	    if {$pending ne ""} {
		$T item prevsibling $pending [lindex $itemTagL 0]
	    }
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
	    lappend itemTagL $item $tag 
	}
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
	
    # Investigate all roster items that are in any way related to the discoe'd
    # item. We'll get the roster JIDs, usually bare JID.
    set jidL [::Roster::GetUsersWithSameHost $from]
    
    set jlib [::Jabber::GetJlib]

    foreach jid $jidL {
	
	# Ordinary users and so far unrecognized transports.
	set istrpt [::Roster::IsTransportEx $jid]
	set icon [::Roster::GetPresenceIconFromJid $jid]
	set tag [list jid $jid]	
	
	if {$istrpt} {
	    	    
	    # If we find a transport not in {head transport} move it.
	    # Delete it and put it back using generic method to get all set.
	    foreach item [FindWithTag $tag] {
		#if {[GetItemsHeadClass $item] ne "transport"}
		if {![HasItemAncestorWithTag $item [list head transport]]} {
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

    array set argsA $args
    
    # Format item:
    #  - If 'name' attribute, use this, else
    #  - If nickname
    #  - if user belongs to login server, use only prefix, else
    #  - show complete 2-tier jid
    # If resource add it within parenthesis '(presence)' but only if Online.
    # 
    # For Online users, the tree item must be a 3-tier jid with resource 
    # since a user may be logged in from more than one resource.
    # Note that some (icq) transports have 3-tier items that are unavailable!

    set istrpt [::Roster::IsTransportEx $jid]
    set server [::Jabber::Jlib getserver]

    if {[info exists argsA(-name)] && ($argsA(-name) ne "")} {
	set str $argsA(-name)
    } else {
	set str [::Nickname::Get [jlib::barejid $jid]]
	if {$str eq ""} {	
	    jlib::splitjidex $jid node domain res
	    if {$domain eq $server} {
		set str [jlib::unescapestr $node]
	    } else {
		set ujid [jlib::unescapejid $jid]
		set str [jlib::barejid $ujid]
	    }
	}
    }
    if {$istrpt} {
	# @@@ A bit ad hoc...
	if {[info exists argsA(-show)]} {
	    set sstr [::Roster::MapShowToText $argsA(-show)]
	    append str " ($sstr)" 
	} elseif {[info exists argsA(-status)] && ($argsA(-status) ne "")} {
	    append str " ($argsA(-status))"
	}
    }
    if {$presence eq "available"} {
	if {[info exists argsA(-resource)] && ($argsA(-resource) ne "")} {
	    
	    # Configurable?
	    #append str " ($argsA(-resource))"
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

    array set argsA $args
    
    set mjid [jlib::jidmap $jid]

    # Design the balloon help window message.
    set msg [jlib::unescapejid $jid]
    if {[info exists argsA(-show)]} {
	set show $argsA(-show)
    } else {
	set show $presence
    }
    append msg "\n" [::Roster::MapShowToText $show]

    if {[string equal $presence "available"]} {
	set delay [::Jabber::Jlib roster getx $jid "jabber:x:delay"]
	if {$delay ne ""} {
	    
	    # An ISO 8601 point-in-time specification. clock works!
	    set stamp [wrapper::getattribute $delay stamp]
	    set tstr [::Utils::SmartClockFormat [clock scan $stamp -timezone :UTC]]
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
    
    set mjid [jlib::jidmap $jid]
    if {$msg eq ""} {
	puts "\t unset -nocomplain balloon($key,$mjid)"
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
    
    jlib::splitjid $jid jid2 res
    if {[jlib::isfulljid $jid]} {
	array set presA [::Jabber::Jlib roster getpresence $jid2 -resource $res]
	
	set tag [list jid $jid]
	foreach item [FindWithTag $tag] {
	    #puts "\t item=$item"
	    eval {Balloon $jid $presA(-type) $item} [array get presA]
	}
    } else {
	set presL [::Jabber::Jlib roster getpresence $jid2]
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

proc ::RosterTree::InitHook {} {
    InitMenus
}

proc ::RosterTree::InitMenus {} {
    # Template for the DnD popup menu.
    variable popMenuDefs
    set mDefs {
        {command        mCopy   {[mc "&Copy"]} {::RosterTree::DnDCopyOrMoveContact $T "copy" $dragged $tgroup}}
        {command        mMove   {[mc "&Move"]} {::RosterTree::DnDCopyOrMoveContact $T "move" $dragged $tgroup}}
        {command        mCancel {[mc "Canc&el"]} {::RosterTree::DnDCopyOrMoveContact $T "cancel" $dragged $tgroup}}
    }
    set mTypes {
        {mCopy          {normal}                }
        {mMove          {normal}                }
        {mCancel        {normal}                }
    }
    set popMenuDefs(rostertree,dnd,def)  $mDefs
    set popMenuDefs(rostertree,dnd,type) $mTypes
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

proc ::RosterTree::NicknameEventHook {xmldata jid nickname} {
    
    # Some servers seem to push out my own nickname.
    if {[jlib::jidequal $jid [::Jabber::Jlib myjid2]]} {
	return
    }
    
    # Just repopulate item.
    set jid [::Jabber::Jlib roster getrosterjid $jid]
    eval {::Roster::SetItem $jid} [::Jabber::Jlib roster getrosteritem $jid]    
}

# RosterTree::GetClosed --
# 
#       Keep track of all closed tree items. Default is all open.

proc ::RosterTree::GetClosed {} {
    global jprefs
    
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

proc ::RosterTree::FileMenuPostHook {wmenu} {
    variable T
    
    if {[winfo ismapped $T]} {
	set jidL [GetSelectedJID]
	if {[llength $jidL] == 1} {
	    set m [::UI::MenuMethod $wmenu entrycget mExport -menu]
	    ::UI::MenuMethod $m entryconfigure mBC... -state normal -label [mc "&Business Card"]...
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
	::UI::MenuMethod $wmenu entryconfigure mFind -state normal -label [mc "Find"]
	if {[winfo exists $wfind]} {
	    ::UI::MenuMethod $wmenu entryconfigure mFindNext -state normal -label [mc "Find Next"]
	    ::UI::MenuMethod $wmenu entryconfigure mFindPrevious -state normal -label [mc "Find Previous"]
	}
    }
}

proc ::RosterTree::OnMenuExportVCardHook {} {
    variable T
    
    if {[winfo ismapped $T]} {
	set jidL [GetSelectedJID]
	if {[llength $jidL] == 1} {
	    ::VCard::ExportXMLFromJID [lindex $jidL 0]
	}
    }
}

