#  RosterAvatar.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements an avatar style roster tree using treectrl.
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
# $Id: RosterAvatar.tcl,v 1.47 2007-12-20 14:01:26 matben Exp $

#   This file also acts as a template for other style implementations.
#   Requirements:
#       1) there must be a cTree column which makes up the tree part;
#          the first text element in cTree is used for sorting
#       2) the tags must be consistent, see RosterTree
#       
#   A "roster style" handles all item creation and deletion, and is responsible
#   for handling groups, pending, and transport folders.
#   It is also responsible for setting icons for foreign im systems, identifying
#   coccinellas etc.

package require RosterTree
package require Avatar

package provide RosterAvatar 1.0

namespace eval ::RosterAvatar {
    
    # The generic style name is 'avatar' which is also used in db names.
    variable rosterBaseStyle "avatar"
    variable thisRosterStyles {avatar avatarlarge flat flatsmall}
        
    # Register this style.
    ::RosterTree::RegisterStyle avatar "Avatar"  \
      ::RosterAvatar::Configure   \
      ::RosterAvatar::Init        \
      ::RosterAvatar::Delete      \
      ::RosterAvatar::CreateItem  \
      ::RosterAvatar::DeleteItem  \
      ::RosterAvatar::SetItemAlternative

    ::RosterTree::RegisterStyle avatarlarge "Avatar Large"  \
      ::RosterAvatar::Configure   \
      ::RosterAvatar::Init        \
      ::RosterAvatar::Delete      \
      ::RosterAvatar::CreateItem  \
      ::RosterAvatar::DeleteItem  \
      ::RosterAvatar::SetItemAlternative

    ::RosterTree::RegisterStyle flat "Flat"  \
      ::RosterAvatar::Configure   \
      ::RosterAvatar::Init        \
      ::RosterAvatar::Delete      \
      ::RosterAvatar::CreateItem  \
      ::RosterAvatar::DeleteItem  \
      ::RosterAvatar::SetItemAlternative

    ::RosterTree::RegisterStyle flatsmall "Flat Small"  \
      ::RosterAvatar::Configure   \
      ::RosterAvatar::Init        \
      ::RosterAvatar::Delete      \
      ::RosterAvatar::CreateItem  \
      ::RosterAvatar::DeleteItem  \
      ::RosterAvatar::SetItemAlternative

    ::RosterTree::RegisterStyleFindColumn avatar       cTree
    ::RosterTree::RegisterStyleFindColumn avatarlarge  cTree
    ::RosterTree::RegisterStyleFindColumn flat         cTree
    ::RosterTree::RegisterStyleFindColumn flatsmall    cTree

    ::RosterTree::RegisterStyleSort avatar      ::RosterAvatar::Sort
    ::RosterTree::RegisterStyleSort avatarlarge ::RosterAvatar::Sort
    ::RosterTree::RegisterStyleSort flat        ::RosterAvatar::Sort
    ::RosterTree::RegisterStyleSort flatsmall   ::RosterAvatar::Sort

    # Event hooks.
    ::hooks::register  discoInfoHook        ::RosterAvatar::DiscoInfoHook
    ::hooks::register  rosterTreeConfigure  ::RosterAvatar::TreeConfigureHook
    ::hooks::register  prefsInitHook        ::RosterAvatar::InitPrefsHook
    
    ::hooks::register  avatarNewPhotoHook   [namespace code NewPhotoHook]

    # We should have a set of sizes to choose from: 32, 48 and 64
    variable avatarSize 32
    variable avatarSizes {32 48 64}
    
    variable avatarDefault defaultBoy
    variable initedDB 0
    variable initedDefaultAvatars 0
    
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

proc ::RosterAvatar::InitPrefsHook {} {
    upvar ::Jabber::jprefs jprefs

    set jprefs(rost,avatar-sortColumn) cTree
    
    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(rost,avatar-sortColumn)   jprefs_rost_avatar-sortColumn $jprefs(rost,avatar-sortColumn)]  \
      ]
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
    #   element options:    rosterBaseStyle:elementName-option
    #   style options:      rosterBaseStyle:styleName:elementName-option

    array set uFont [font actual CociDefaultFont]
    set uFont(-underline) 1
    set underlineFont [eval font create [array get uFont]]

    array set uFontS [font actual CociSmallFont]
    set uFontS(-underline) 1
    set underlineFontS [eval font create [array get uFontS]]

    set fillT   {white {selected focus} black {selected !focus}}
    set fillZ   {white {selected focus} "#535353"  {}}
    set fillM   {blue {mouseover}} 
    set fontU   [list $underlineFont {mouseover}]
    set fontUS  [list $underlineFontS {mouseover}]
    set fillF   [concat $fillT $fillM]
    set fontF   [list $underlineFont {mouseover} CociDefaultFont {}]
    set fontFS  [list $underlineFontS {mouseover} CociSmallFont {}]
    set imop [::Rosticons::Get application/folder-open]
    set imcl [::Rosticons::Get application/folder-closed]
    set imageF [list $imop {open} $imcl {!open}]
    set fillB [list $this(sysHighlight) {selected focus} gray {selected !focus}]
    
    # Get default avatar.
    #set f [file join $this(avatarPath) $avatarSize $avatarDefault.png]
    #set avimage [image create photo -file $f]
    #set avatar(default) $avimage
    set avimage [MakeDefaultAvatar]
    
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

    option add *Roster.avatar:eNotify-fill            "#ffd6d6"         widgetDefault
    option add *Roster.avatar:eNotify-outline         "#e2a19d"         widgetDefault
    option add *Roster.avatar:eNotify-outlinewidth    1                 widgetDefault

    # If no background image:
    option add *Roster.avatar:eBorder-outline:nbg      gray              widgetDefault
    option add *Roster.avatar:eBorder-outlinewidth:nbg 0                 widgetDefault

    # Style layout options:
    option add *Roster.avatar:styStatus:eImage-padx             {4 2}   widgetDefault
    option add *Roster.avatar:styStatus:eImage-pady             2       widgetDefault

    option add *Roster.avatar:styAvailable:eOnText-padx         4       widgetDefault
    option add *Roster.avatar:styAvailable:eOnText-pady         4       widgetDefault
    option add *Roster.avatar:styAvailable:eAltImage0-padx      2       widgetDefault
    option add *Roster.avatar:styAvailable:eAltImage1-padx      2       widgetDefault
    option add *Roster.avatar:styAvailable:eAvBorder-padx       {2 4}   widgetDefault
    option add *Roster.avatar:styAvailable:eAvBorder-pady       {1 2}   widgetDefault
    option add *Roster.avatar:styAvailable:eNotify-draw         {1 notify 0 {}}   widgetDefault

    option add *Roster.avatar:styUnavailable:eOffText-padx      4       widgetDefault
    option add *Roster.avatar:styUnavailable:eOffText-pady      4       widgetDefault
    option add *Roster.avatar:styUnavailable:eAltImage0-padx    2       widgetDefault
    option add *Roster.avatar:styUnavailable:eAltImage1-padx    2       widgetDefault
    option add *Roster.avatar:styUnavailable:eAvBorder-padx     {2 4}   widgetDefault
    option add *Roster.avatar:styUnavailable:eAvBorder-pady     {1 2}   widgetDefault
    option add *Roster.avatar:styUnavailable:eNotify-draw       {1 notify 0 {}}   widgetDefault

    option add *Roster.avatar:styEntry:eAvBorder-padx           {2 4}   widgetDefault
    option add *Roster.avatar:styEntry:eAvBorder-pady           {1 2}   widgetDefault

    option add *Roster.avatar:styFolder:eImage-padx             2       widgetDefault
    option add *Roster.avatar:styFolder:eImage-pady             {1 2}   widgetDefault
    option add *Roster.avatar:styFolder:eFolderImage-padx       {4 0}   widgetDefault
    option add *Roster.avatar:styFolder:eFolderText-padx        4       widgetDefault
    option add *Roster.avatar:styFolder:eNumText-padx           4       widgetDefault

    option add *Roster.avatar:styHead:eImage-padx               2       widgetDefault
    option add *Roster.avatar:styHead:eFolderText-padx          4       widgetDefault
    option add *Roster.avatar:styHead:eNumText-padx             4       widgetDefault
    
    # Specific roster style db options.
    option add *Roster.flatsmall:eText-font           CociSmallFont     widgetDefault
    option add *Roster.flatsmall:eNumText-font        CociSmallFont     widgetDefault
    option add *Roster.flatsmall:eOnText-font         CociSmallFont     widgetDefault
    option add *Roster.flatsmall:eOffText-font        CociSmallFont     widgetDefault
    option add *Roster.flatsmall:eFolderText-font     $fontFS           widgetDefault    

    option add *Roster.flat:styFolder:eFolderImage-padx         {4 0}   widgetDefault
    option add *Roster.flat:styFolder:eFolderImage-pady         {1 2}   widgetDefault
    option add *Roster.flat:styFolder:eFolderText-padx          4       widgetDefault
    option add *Roster.flat:styFolder:eFolderText-pady          4       widgetDefault

    option add *Roster.flatsmall:styFolder:eFolderImage-padx    {4 0}   widgetDefault
    option add *Roster.flatsmall:styFolder:eFolderImage-pady    {1 2}   widgetDefault
    option add *Roster.flatsmall:styFolder:eFolderText-padx     4       widgetDefault
    option add *Roster.flatsmall:styFolder:eFolderText-pady     4       widgetDefault

    set initedDB 1
}

proc ::RosterAvatar::InitDBStyle {} {
    
    set avimage [MakeDefaultAvatar]   
    option add *Roster.avatar:eAvatarImage-image  $avimage  widgetDefault
}

proc ::RosterAvatar::MakeDefaultAvatar {} {
    global  this
    variable avatar
    variable avatarSize
    variable avatarDefault 
    
    if {[info exists avatar(default)]} {
	image delete $avatar(default)
    }
    
    # Get default avatar.
    set f [file join $this(avatarPath) $avatarSize $avatarDefault.png]
    set avimage [image create photo -file $f]
    set avatar(default) $avimage
    return $avimage
}

proc ::RosterAvatar::InitDefaultAvatars {} {
    global  this
    variable avatar
    variable avatarSizes
    variable avatarDefault 
    variable initedDefaultAvatars
    
    if {$initedDefaultAvatars} {
	return
    }
    foreach size $avatarSizes {
	set f [file join $this(avatarPath) $size $avatarDefault.png]
	set avatar(default,$size) [image create photo -file $f]
    }
    set initedDefaultAvatars 1
}

proc ::RosterAvatar::GetDefaultAvatarOfSize {size} {
    variable avatarSizes
    variable avatar

    if {[lsearch $avatarSizes $size] < 0} {
	return -code error "Unsupported size \"$size\""
    }
    InitDefaultAvatars
    return $avatar(default,$size)
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
    variable rosterBaseStyle
    variable initedDB
    
    set T $_T
    
    if {!$initedDB} {
	InitDB
    }   
    set styleName [::RosterTree::GetStyle]
    if {$styleName eq "avatar"} {
	set avatarSize 32
    } elseif {$styleName eq "avatarlarge"} {
	set avatarSize 48
    }
    switch -- $styleName {
	avatar - avatarlarge {
	    set styleClass avatar
	    set optionClass avatar
	}
	default {
	    set styleClass flat
	    set optionClass $styleName
	}
    }
    ::Debug 4 "\t styleName=$styleName, styleClass=$styleClass, optionClass=$optionClass"
    
    # After 'avatarSize'.
    InitDBStyle
    
    # This is a dummy option.
    set itemBackground [option get $T itemBackground {}]
    if {$styleClass eq "avatar"} {
	set minW $avatarSize
	set minH $avatarSize
    } else {
	set minW 0
	set minH 0
    }
    set bd [option get $T columnBorderWidth {}]
    set bg [option get $T columnBackground {}]
    set fg [option get $T textColor {}]
    set simage [::Rosticons::Get status/available]

    # Define a new item state
    if {[lsearch [$T state names] notify] < 0} {
	$T state define notify
    }

    # Three columns: 
    #   0) status
    #   1) the tree 
    #   2) hidden for tags
    #   
    # minwidth 24 = 16 + {4 2}

    $T column create -tags cStatus  \
      -itembackground $itemBackground -resize 0 -minwidth 24 -button 1  \
      -borderwidth $bd -background $bg -image $simage -textcolor $fg \
      -imagepadx {6 14}
    $T column create -tags cTree    \
      -itembackground $itemBackground -resize 0 -expand 1 -squeeze 1  \
      -text [mc "Contact Name"] -button 1 -arrow up -borderwidth $bd \
      -background $bg -textcolor $fg
    $T column create -tags cTag     \
      -visible 0
    $T configure -showheader 1

    # Define a new item state
    if {[lsearch [$T state names] mouseover] < 0} {
	$T state define mouseover
    }
    
    # The elements. eIndent is used for indentions.
    $T element create eImage       image
    $T element create eAvBorder    rect
    $T element create eAvatarImage image
    $T element create eAltImage0   image
    $T element create eAltImage1   image
    $T element create eOnText      text -lines 1
    $T element create eOffText     text -lines 1
    $T element create eText        text
    $T element create eFolderText  text
    $T element create eFolderImage image
    $T element create eBorder      rect -open new -showfocus 1
    $T element create eNumText     text -lines 1
    $T element create eIndent      rect -fill ""
    $T element create eNotify      rect
    $T element create eWindow      window

    $T element create eDebug       rect -fill red -width 10 -height 10
    
    # @@@ Have available/unavailable as states instead of separate styles?
    
    # Styles collecting the elements ---
    # Status:
    set S [$T style create styStatus]
    $T style elements $S {eBorder eImage}
    $T style layout $S eImage  -expand news
    $T style layout $S eBorder -detach 1 -iexpand xy

    # Available:
    set S [$T style create styAvailable]
    if {$styleClass eq "avatar"} {
	set elements {eBorder eNotify eIndent eOnText eAltImage1 eAltImage0 eAvBorder eAvatarImage}
    } elseif {$styleClass eq "flat"} {
	set elements {eBorder eNotify eIndent eOnText eAltImage1 eAltImage0}
    }
    $T style elements $S $elements
    $T style layout $S eBorder      -detach 1 -iexpand xy
    $T style layout $S eOnText      -squeeze x -iexpand xy -sticky w
    $T style layout $S eAltImage0   -expand ns
    $T style layout $S eAltImage1   -expand ns
    if {$styleClass eq "avatar"} {
	$T style layout $S eAvBorder    -union {eAvatarImage}
	$T style layout $S eAvatarImage -expand ns -minheight $minH -minwidth $minW
    }
    $T style layout $S eNotify   -detach 1 -iexpand xy -indent 0 -padx 2 -pady 2
    
    # Unavailable:
    set S [$T style create styUnavailable]
    if {$styleClass eq "avatar"} {
	set elements {eBorder eNotify eIndent eOffText eAltImage1 eAltImage0 eAvBorder eAvatarImage}
    } elseif {$styleClass eq "flat"} {
	set elements {eBorder eNotify eIndent eOffText eAltImage1 eAltImage0}
    }
    $T style elements $S $elements
    $T style layout $S eBorder      -detach 1 -iexpand xy
    $T style layout $S eOffText     -squeeze x -iexpand xy -sticky w
    $T style layout $S eAltImage0   -expand ns
    $T style layout $S eAltImage1   -expand ns
    if {$styleClass eq "avatar"} {
	$T style layout $S eAvBorder    -union {eAvatarImage} -sticky e
	$T style layout $S eAvatarImage -expand ns -minheight $minH -minwidth $minW
    }
    $T style layout $S eNotify   -detach 1 -iexpand xy -indent 0 -padx 2 -pady 2
  
    # Edit:
    set S [$T style create styEntry]
    if {$styleClass eq "avatar"} {
	set elements {eBorder eNotify eIndent eWindow eAvBorder eAvatarImage}
    } elseif {$styleClass eq "flat"} {
	set elements {eBorder eNotify eIndent eWindow}
    }
    $T style elements $S $elements
    $T style layout $S eBorder  -detach 1 -iexpand xy
    $T style layout $S eWindow  -iexpand x -expand ns
    if {$styleClass eq "avatar"} {
	$T style layout $S eAvBorder    -union {eAvatarImage}
	$T style layout $S eAvatarImage -expand ns -minheight $minH -minwidth $minW
    }
    
    # Folder:
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
    
    $T column configure cStatus -itemstyle styStatus
    $T column configure cTag    -itemstyle styTag
    
    $T notify install <Header-invoke>
    $T notify bind $T <Selection>      { ::RosterTree::Selection }
    $T notify bind $T <Expand-after>   { ::RosterTree::OpenTreeCmd %I }
    $T notify bind $T <Collapse-after> { ::RosterTree::CloseTreeCmd %I }
    $T notify bind $T <Header-invoke>  { ::RosterAvatar::HeaderCmd %T %C }

    bind $T <ButtonPress-1>  { ::RosterAvatar::FullSize %W %x %y }
    
    # Have movable columns.
    $T column dragconfigure -enable yes
    $T notify install <ColumnDrag-receive>
    $T notify bind $T <ColumnDrag-receive> {
	%T column move %C %b
    }
        
    ::TreeCtrl::DnDSetDragSources $T {}
    ::TreeCtrl::DnDSetDropTargets $T {}

    ::RosterTree::DBOptions $rosterBaseStyle
    ::RosterTree::DBOptions $optionClass
    ::RosterTree::EditSetBinds [namespace code EditCmd]

    if {$styleClass eq "avatar"} {
	::Avatar::Configure -autoget 1
	::Avatar::RegisterHash [namespace code OnAvatarHash]
	
	# We shall get avatars for all users.
	::Avatar::GetAll
    }
}

proc ::RosterAvatar::EditCmd {id} {
    variable T
    variable tmpEdit
    
    # Protect for second entries.
    if {[info exists tmpEdit]} {
	return
    }
    if {!(([lindex $id 0] eq "item") && ([llength $id] == 6))} {
	return
    }
    
    # item+column+elem
    array set what $id
    
    # Sort out clicks that aren't in the right place.
    if {![info exists what(elem)]} {
	return
    }
    if {!(($what(elem) eq "eOnText") || ($what(elem) eq "eOffText"))} {
	return
    }
    set item [lindex $id 1]
    if {[$T item style set $item cTree] eq "styEntry"} {
	return
    }
    set tags [::RosterTree::GetTagOfItem $item]
    if {[lindex $tags 0] eq "jid"} {
	set jid [lindex $tags 1]
	set text [$T item text $item cTree]
	
	# @@@ I'd like a way to get the style from item but found none :-(
	set font [$T item element cget $item cTree $what(elem) -font]
	if {[::RosterTree::GetStyle] eq "flatsmall"} {
	    set font CociSmallFont
	} else {
	    set font CociDefaultFont
	}
	set wentry $T.entry
	set tmpEdit(entry) $wentry
	set tmpEdit(text)  $text
	set tmpEdit(font)  $font
	set tmpEdit(jid)   $jid
	destroy $wentry
	ttk::entry $wentry -font $font \
	  -textvariable [namespace current]::tmpEdit(text) -width 1
	$T item style set $item cTree styEntry
	$T item element configure $item cTree eWindow -window $wentry
	focus $wentry
	
	bind $wentry <Return>   [namespace code [list EditOnReturn $item]]
	bind $wentry <KP_Enter> [namespace code [list EditOnReturn $item]]
	bind $wentry <FocusOut> [namespace code [list EditEnd $item]]
	bind $wentry <Escape>   [namespace code [list EditEnd $item]]
    }
}

proc ::RosterAvatar::EditOnReturn {item} {
    variable tmpEdit
    
    ::RosterTree::EditOnReturn $tmpEdit(jid) $tmpEdit(text)
}

proc ::RosterAvatar::EditEnd {item} {
    variable tmpEdit
    
    ::RosterTree::EditEnd $tmpEdit(jid)
    destroy $tmpEdit(entry) 
    unset tmpEdit
}

proc ::RosterAvatar::Sort {item order} {
    variable T
    upvar ::Jabber::jprefs jprefs

    set sortColumn $jprefs(rost,avatar-sortColumn)

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
    upvar ::Jabber::jprefs jprefs
    
    set sortColumn $jprefs(rost,avatar-sortColumn)
    set ctag [$T column cget $C -tags]
    
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
	set jprefs(rost,avatar-sortColumn) $ctag
    }
    $T column configure $C -arrow $arrow
    
    SortColumn $C $order
}

proc ::RosterAvatar::SortColumn {C order} {
    variable T

    # Keep transports and pending always at the end.
    set opts [list]
    
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
    
    switch -- [$T column cget $C -tags] {
	cTree {
	    lappend opts -dictionary
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

proc ::RosterAvatar::FullSize {T x y} {
    variable avatarSize
    
    set id [$T identify $x $y]
     if {$id eq ""} {
	return
    }
    if {([lindex $id 0] eq "item") && ([llength $id] == 6)} {
	if {[lindex $id 5] eq "eAvatarImage"} {
	    set item [lindex $id 1]
	    set tags [::RosterTree::GetTagOfItem $item]
	    if {[lindex $tags 0] eq "jid"} {
		set jid [lindex $tags 1]
		set image [::Avatar::GetPhoto [jlib::barejid $jid]]
		if {$image ne ""} {
		    if {([image width $image] < $avatarSize) && \
		      ([image height $image] < $avatarSize)} {
			return
		    }
		    set win [ui::autoname]
		    toplevel $win -bd 0 -relief flat
		    wm overrideredirect $win 1
		    wm transient $win
		    wm resizable $win 0 0
		    
		    if {[tk windowingsystem] eq "aqua"} {
			tk::unsupported::MacWindowStyle style $win help none
		    }
		    label $win.l -bd 0 -bg white -compound none -image $image
		    pack $win.l
		    bind $win.l <Leave> [list destroy $win]
		    set x [expr {[winfo rootx $T] + $x - 20}]
		    set y [expr {[winfo rooty $T] + $y - 20}]
		    wm geometry $win +$x+$y
		}
	    }
	}
    }    
}

# RosterAvatar::Init --
# 
#       Creates the items for the initial logged out state.
#       It starts by removing all content.

proc ::RosterAvatar::Init { } {
    variable T
	
    $T item delete all
    ::RosterTree::FreeTags
}

proc ::RosterAvatar::OnAvatarHash {jid2} {
    
    # If removed (empty hash) we do this right away, else the -autoget and
    # hooks fixes it.
    set hash [::Jabber::Jlib avatar get_hash $jid2]
    if {$hash eq ""} {
	OnAvatarPhoto $jid2
    }
}

proc ::RosterAvatar::NewPhotoHook {jid2} {
    OnAvatarPhoto $jid2
}

# RosterAvatar::OnAvatarPhoto --
# 
#       Callback from Avatar when there is a new image or the image has been
#       removed.

proc ::RosterAvatar::OnAvatarPhoto {jid2} {
    
    ::Debug 4 "::RosterAvatar::OnAvatarPhoto jid2=$jid2"
    
    # We get this callback async. Beware!
    set styleName [::RosterTree::GetStyle]
    if {($styleName ne "avatar") && ($styleName ne "avatarlarge")} {
	return
    }
    set hash [::Jabber::Jlib avatar get_hash $jid2]
    if {$hash eq ""} {
	set type remove
    } else {
	set type put
    }

    # Avatars are defined per BARE JID, jid2.
    # For online users we shall set avatar for all resources.
    set resources [::Jabber::RosterCmd getresources $jid2]
    if {$resources eq ""} {
	SetAvatarImage $type $jid2
    } else {
	foreach res $resources {
	    SetAvatarImage $type $jid2/$res  
	}
    }
}

# RosterAvatar::SetAvatarImage --
# 
#       Sets, updates or removes an avatar for the specified jid.
#
# Arguments:
#       jid     is as jid3 if available else jid2, identical to how items 
#               are tagged

proc ::RosterAvatar::SetAvatarImage {type jid} {
    variable T
    variable avatar
    variable avatarSize
    
    ::Debug 4 "::RosterAvatar::SetAvatarImage $type, jid=$jid"
        
    jlib::splitjid $jid jid2 -
    set tag [list jid $jid]
    set item [FindWithTag $tag]
    if {$item ne ""} {
	
	switch -- $type {
	    create - put {
		set image [::Avatar::GetPhotoOfSize $jid2 $avatarSize]
		$T item element configure $item cTree eAvatarImage -image $image

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

proc ::RosterAvatar::Delete {} {
    
    ::Avatar::Configure -autoget 0 ;# -command ""
    ::Avatar::DeregisterHash [namespace code OnAvatarHash]
    FreeAltCache
}

# RosterAvatar::CreateItem --
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

proc ::RosterAvatar::CreateItem {jid presence args} {    
    variable T
    variable jidStatus
    variable rosterBaseStyle
    upvar ::Jabber::jstate  jstate
    upvar ::Jabber::jprefs jprefs

    if {($presence ne "available") && ($presence ne "unavailable")} {
	return
    }
    
    # Filter out those we don't want to see.
    set istrpt [::Roster::IsTransportHeuristics $jid]
    if {$istrpt} {
	if {!$jprefs(rost,showTrpts)} {
	    return
	}	
    } else {
	if {$presence eq "available"} {
	    set show [$jstate(jlib) roster getshow $jid]
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
    array set argsArr $args

    array set styleMap {
	available    styAvailable 
	unavailable  styUnavailable
    }
    array set tElemMap {
	available   eOnText
	unavailable eOffText
    }
    set styleName [::RosterTree::GetStyle]
    switch -- $styleName {
	avatar - avatarlarge {
	    set styleClass avatar
	}
	default {
	    set styleClass flat
	}
    }

    # Always try to show avatar.
    set avatarForOffline 1
    
    set mjid  [jlib::jidmap $jid]
    set mjid2 [jlib::barejid $mjid]

    # Defaults:
    set jtext  [eval {MakeDisplayText $jid $presence} $args]
    set jimage [eval {GetPresenceIcon $jid $presence} $args]
    set items  [list]
        
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
    set tag  [list jid $mjid]
    set style $styleMap($presence)
    set elem $tElemMap($presence)
    set jidStatus($mjid) $status
    set item [CreateWithTag $tag $style $elem $jtext $jimage root]
    lappend items $item
    
    if {$styleClass eq "avatar"} {
	if {$avatarForOffline || ($presence eq "available")} {
	    if {[::Avatar::HavePhoto $mjid2]} {
		SetAvatarImage put $mjid
	    }
	}
    }

    if {($type eq "transport") || ($type eq "pending")} {
	set ptag [list head $type]
	set ptext  [::RosterTree::MCHead $type]
	set pimage [::Rosticons::Get application/$type]
	set pitem [PutItemInHead $item $ptag $ptext $pimage]
	set n [llength [$T item children $pitem]]
	$T item element configure $pitem cTree eNumText -text "($n)"
	
	# Always put pending last, after any transport.
	if {$type eq "transport"} {
	    set pending [FindWithTag [list head pending]]
	    if {$pending ne ""} {
		$T item prevsibling $pending $pitem
	    }
	}
    } elseif {[info exists argsArr(-groups)] && ($argsArr(-groups) ne "")} {
	
	# Group(s):
	#set image [::Rosticons::Get application/group-online]
	set w [::Roster::GetRosterWindow]
	set indent [option get $w ${rosterBaseStyle}:indent {}]

	foreach group $argsArr(-groups) {
	    set ptag [list group $group]
	    set pitem [FindWithTag $ptag]
	    if {$pitem eq ""} {
		set pitem [CreateWithTag $ptag styFolder eFolderText $group "" root]
		SetMouseOverBinds $pitem
	    }
	    $T item lastchild $pitem $item
	    $T item element configure $item cTree eIndent -width $indent
	}
    } else {
	# empty
    }

    ConfigureChildNumbersAtIdle

    # Design the balloon help window message.
    foreach item $items {
	eval {Balloon $jid $presence $item} $args
    }
    return $items
}

proc ::RosterAvatar::ConfigureChildNumbersAtIdle {} {
    variable pendingChildNumbers    
    
    # Configure number of available/unavailable users.
    if {![info exists pendingChildNumbers]} {
	set pendingChildNumbers 1
	after idle [namespace code ConfigureChildNumbers]
    }
}

proc ::RosterAvatar::ConfigureChildNumbers {} {
    variable T
    variable pendingChildNumbers

    unset -nocomplain pendingChildNumbers

    # Update any groups.
    foreach item [::RosterTree::FindWithFirstTag group] {
	set n [llength [$T item children $item]]
	$T item element configure $item cTree eNumText -text "($n)"
    }
}

proc ::RosterAvatar::PutItemInHead {item ptag ptext pimage} {
    variable T
    variable rosterBaseStyle
    
    set w [::Roster::GetRosterWindow]
    set indent [option get $w ${rosterBaseStyle}:indent {}]

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
    
    # Sibling of '::RosterTree::CreateItemBase'.
    ::RosterTree::DeleteItemBase $jid
    
    # Delete any empty leftovers.
    ::RosterTree::DeleteEmptyGroups
    ::RosterTree::DeleteEmptyPendTrpt
    ConfigureChildNumbersAtIdle
    
    unset -nocomplain jidStatus($jid)
}

proc ::RosterAvatar::CreateItemFromJID {jid} {    
    upvar ::Jabber::jstate jstate

    set jlib $jstate(jlib)
    jlib::splitjid $jid jid2 res
    set pres [$jlib roster getpresence $jid2 -resource $res]
    set rost [$jlib roster getrosteritem $jid2]
    array set opts $pres
    array set opts $rost

    return [eval {CreateItem $jid $opts(-type)} [array get opts]]
}

# RosterAvatar::SetItemAlternative --
# 
#       Sets additional icons. Empty removes.

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

# This proc is duplicated for all styles BAD!
# Since it makes assumptions about the elements: 'eAltImage*'.
proc ::RosterAvatar::SetAltImage {jid key image} {
    variable T
    variable altImageKeyToElem
            
    # altImageKeyToElem maps: key -> element name
    # 
    # We use a static mapping: BAD?
    
    set mjid [jlib::jidmap $jid]
    set tag [list jid $mjid]
    set item [FindWithTag $tag]
    
    if {[info exists altImageKeyToElem($key)]} {
	set elem $altImageKeyToElem($key)
    } else {
	
	# Find element name to use.
	set size [array size altImageKeyToElem]
	set maxSize 2
	if {$size >= $maxSize} {
	   return
	}
	set elem eAltImage${size}
	set altImageKeyToElem($key) $elem
    }  
    $T item element configure $item cTree $elem -image $image

    return [list $T $item cTree $elem]
}

proc ::RosterAvatar::FreeAltCache {} {
    variable altImageKeyToElem
    
    unset -nocomplain altImageKeyToElem
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
      cStatus eImage -image $image , \
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
    variable thisRosterStyles
    variable rosterBaseStyle
    
    # We must verify we are displayed. Better?
    if {[lsearch $thisRosterStyles [::RosterTree::GetStyle]] < 0} {
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
	set dbname ${rosterBaseStyle}:${ename}${oname}${postfix}	    
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
    variable thisRosterStyles
    upvar ::Jabber::jstate jstate
    
    # We must verify we are displayed. Better?
    if {[lsearch $thisRosterStyles [::RosterTree::GetStyle]] < 0} {
	return
    }
    if {$type ne "error"} {
	set types [$jstate(jlib) disco types $from]
	
	# Only the gateways have custom icons.
	if {[lsearch -glob $types gateway/*] >= 0} {
	    ::RosterTree::BasePostProcessDiscoInfo $from cStatus eImage
	}
    }
}

