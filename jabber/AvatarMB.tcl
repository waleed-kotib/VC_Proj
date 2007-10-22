#  AvatarMB.tcl --
#
#      This file is part of The Coccinella application. 
#      It implements a megawidget menubutton for setting avatar.
#      
#  Copyright (c) 2006  Mats Bengtsson
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
# $Id: AvatarMB.tcl,v 1.24 2007-10-22 11:51:33 matben Exp $
# 
# @@@ TODO: Get options from option database instead

package require colorutils

package provide AvatarMB 1.0

namespace eval ::AvatarMB {

    ::hooks::register  prefsInitHook   ::AvatarMB::InitPrefsHook

    variable initted 0
}

proc ::AvatarMB::InitPrefsHook { } {
    global  prefs
    
    set prefs(dir,avatarPick) ""
    if {[tk windowingsystem] eq "aqua"} {
	# gif and 48x48 
	set iChatPath [file nativename "~/Pictures/iChat Icons/"]
	if {[file isdirectory $iChatPath]} {
	    set prefs(dir,avatarPick) $iChatPath
	}
    }
    ::PrefUtils::Add [list  \
      [list prefs(dir,avatarPick)  prefs_dir_avatarPick  $prefs(dir,avatarPick)]]
}

proc ::AvatarMB::Init {} {
    global  this
    
    # Static variables.
    variable widget
    variable initted
    
    set initted 1
        
    set widget(background)  white
    set widget(buttonsize)  24
    set widget(menusize)    32
    set widget(nboxside)    4
    
    variable state
    set state(pulldown) 0

    # Try make a fake menu (FMenu) entry widget.
    # Perhaps this should be moved to tileutils and be made more generic?

    set blank ::AvatarMB::blank
    image create photo $blank -width 4 -height 4
    $blank blank

    foreach name [tile::availableThemes] {
	
	# @@@ We could be more economical here and load theme only when needed.
	if {[catch {package require tile::theme::$name}]} {
	    continue
	}	

	style theme settings $name {
	 	    
	    set activeDef "#3874d1"
	    set active $activeDef
	    array unset style
	    array unset map
	    array set style [list -foreground black]
	    array set style [style configure .]    
	    array set map   [style map .]

	    if {[info exists map(-background)]} {
		foreach {mstate mcol} $map(-background) {
		    if {[lsearch $mstate active] >= 0} {
			set active $mcol
			break
		    }
		}
	    }
	    if {$active eq $activeDef} {
		set activeForeground white
	    } else {
		set activeForeground black
	    }
	    array unset foreground
	    set foreground([list active !disabled]) $activeForeground
	    if {[info exists map(-foreground)]} {
		foreach {mstate mcol} $map(-foreground) {
		    if {[lsearch $mstate active] >= 0} {
			set activeForeground $mcol
			break
		    }
		}
		array set foreground $map(-foreground)
	    }
	    set foreground([list active !disabled]) $activeForeground
	    unset -nocomplain foreground(active)
	    unset -nocomplain foreground(selected)
	    unset -nocomplain foreground(focus)

	    set activeim ::AvatarMB::active$name
	    image create photo $activeim -width 2 -height 2
	    $activeim blank
	    $activeim put [list [list $active $active] [list $active $active]]
	    
	    if {$this(tile08)} {
		style element create FMenu.background image \
		  [list $blank {active !disabled} $activeim] \
		  -padding {0} -sticky news
	    } else {
		style element create FMenu.background image $blank  \
		  -padding {0} -sticky news  \
		  -map [list {active !disabled} $activeim]
	    }
	    if {0} {
		# Tile BUG
		style layout FMenu {
		    FMenu.background -sticky news -border 1 -children {
			FMenu.padding -sticky news -border 1 -children {
			    FMenu.label -side left
			}
		    }
		}
	    }
	    style layout FMenu {
		FMenu.background -children {
		    FMenu.padding -children {
			FMenu.label -side left
		    }
		}
	    }	    
	    style configure FMenu  \
	      -padding {18 2 10 2} -borderwidth 0 -relief flat
	    style map FMenu -foreground [array get foreground]
	}
    }
    
    bind AvatarMBMenu <FocusIn> {}
    bind AvatarMBMenu <Destroy> {+::AvatarMB::MenuFree %W}
}

proc ::AvatarMB::Button {mb args} {
    variable widget
    variable state
    variable initted

    if {!$initted} {
	Init
    }
    
    # Keep instance specific state array.
    variable $mb
    upvar 0 $mb xstate    
    
    array set xstate {
	-postposition above
	-postalign    right
    }
    array set xstate $args

    # Bug in 8.4.1 but ok in 8.4.9
    if {[regexp {^8\.4\.[0-5]$} [info patchlevel]]} {
	label $mb -relief sunken -bd 1 -bg white
    } else {
	ttk::label $mb -style SunkenMenubutton -compound image
    }
    
    set size $widget(buttonsize)
    set myphoto [::Avatar::GetMyPhoto]
    if {($myphoto ne "") && [::Avatar::GetShareOption]} {
	set photo [::Avatar::CreateScaledPhoto $myphoto $size]
    } else {
	set photo ""
    }
    
    # Use a blank photo to give the button a consistent size.
    if {![info exists state(blank)]} {
	set state(blank) [image create photo -width $size -height $size]
    }
    if {$photo ne ""} {
	$mb configure -image $photo
    } else {
	$mb configure -image $state(blank)
    }
    if {[winfo class $mb] eq "TLabel"} {
	bind $mb <Enter>      { %W state active }
	bind $mb <Leave>      { %W state !active }
	bind $mb <Key-space>  { %W instate !disabled { AvatarMB::Popdown %W } }
	bind $mb <<Invoke>>   { %W instate !disabled { AvatarMB::Popdown %W } }

	if {[tk windowingsystem] eq "x11"} {
	    bind $mb <ButtonPress-1>    { 
		%W instate !disabled {%W state pressed ; AvatarMB::Pulldown %W } 
	    }
	    bind $mb <ButtonRelease-1>  { AvatarMB::TransferGrab %W }
	    bind $mb <B1-Leave>         { AvatarMB::TransferGrab %W }	    
	} else {
	    bind $mb <ButtonPress-1>    { 
		%W instate !disabled {%W state pressed ; AvatarMB::Popdown %W } 
	    }
	    bind $mb <ButtonRelease-1>  { %W state !pressed }	
	    bind $mb <B1-Leave>         { %W state !pressed }
	    bind $mb <B1-Enter>         { %W instate {active !disabled} { %W state pressed } }
	}
    } else {
	
	# Intended for Windows only why we skip x11.
	bind $mb <Key-space>        { AvatarMB::Popdown %W }
	bind $mb <<Invoke>>         { AvatarMB::Popdown %W }
	bind $mb <ButtonPress-1>    { AvatarMB::Popdown %W }
    }
    bind $mb <Destroy> { AvatarMB::ButtonFree %W }
    
    if {([tk windowingsystem] ne "aqua") && ![catch {package require tkdnd}]} {
	InitDnD $mb
    }
    
    ::hooks::register avatarMyNewPhotoHook [list ::AvatarMB::MyNewPhotoHook $mb]
    
    return $mb
}

proc ::AvatarMB::InitDnD {win} {
    
    dnd bindtarget $win text/uri-list <Drop>      \
       [list [namespace current]::DnDDrop %W %D %T]   
     dnd bindtarget $win text/uri-list <DragEnter> \
       [list [namespace current]::DnDEnter %W %A %D %T]   
}

proc ::AvatarMB::DnDDrop {w data type} {

    # Take only first file.
    set f [lindex $data 0]
	
    # Strip off any file:// prefix.
    set f [string map {file:// ""} $f]
    set f [uriencode::decodefile $f]
    if {[VerifyPhotoFile $f]} {
	SetFileToShare $f
    }
}

proc ::AvatarMB::DnDEnter {w action data type} {

    set act "none"
    set f [lindex $data 0]
    if {[VerifyPhotoFile $f]} {
	set act $action
    }
    return $act
}

proc ::AvatarMB::ButtonFree {mb} {
    variable state
    variable $mb
    upvar 0 $mb xstate    
    
    hooks::deregister avatarMyNewPhotoHook [list ::AvatarMB::MyNewPhotoHook $mb]
    
    set photo [$mb cget -image]
    if {$photo ne $state(blank)} {
	image delete $photo
    }
    unset -nocomplain xstate
}

proc ::AvatarMB::MyNewPhotoHook {mb} {
    variable widget
    variable state
    
    set photo [$mb cget -image]
    if {$photo ne $state(blank)} {
	image delete $photo
    }
    set size $widget(buttonsize)
    set myphoto [::Avatar::GetMyPhoto]
    if {($myphoto ne "") && [::Avatar::GetShareOption]} {
	set photo [::Avatar::CreateScaledPhoto $myphoto $size]
	$mb configure -image $photo
    } else {
	$mb configure -image $state(blank)
    }
}

proc ::AvatarMB::Pulldown {mb} {
    variable state

    set state(pulldown) 1
    PostMenu $mb    
}

proc ::AvatarMB::Popdown {mb} {
    set menu $mb.menu
    PostMenu $mb
    SaveGrabInfo $mb
    
    # This will direct all events to the menu even if the mouse is outside!
    # Buggy on mac.
    grab -global $menu
}

proc ::AvatarMB::TransferGrab {mb} {
    variable state

    if {$state(pulldown)} {
	set state(pulldown) 0
	set menu $mb.menu
	if {[winfo viewable $menu]} {
	    SaveGrabInfo $mb
	    grab -global $menu
	}
    }
}

proc ::AvatarMB::SaveGrabInfo {mb} {
    variable state
    set state(oldGrab) [grab current $mb]
    if {$state(oldGrab) ne ""} {
	set state(grabStatus) [grab status $state(oldGrab)]
    }    
}

proc ::AvatarMB::RestoreOldGrab {} {
    variable state
    if {$state(oldGrab) ne ""} {
	catch {
	  if {$state(grabStatus) eq "global"} {
		grab set -global $state(oldGrab)
	    } else {
		grab set $state(oldGrab)
	    }
	}
	set state(oldGrab) ""
    }    
}

proc ::AvatarMB::PostMenu {mb} {
    variable $mb
    upvar 0 $mb xstate    

    set menu $mb.menu
    Menu $menu
    wm withdraw $menu
    update idletasks
    
    # PositionAlign sould perhaps be an option.
    foreach {x y} [PostPosition $mb $xstate(-postposition)] { break }
    foreach {x y} [PositionAlign $mb $xstate(-postalign) $x $y] { break }
    foreach {x y} [PositionOnScreen $mb $x $y] { break }
    wm geometry $menu +$x+$y
    wm deiconify $menu
}

proc ::AvatarMB::PostPosition {mb dir} {
    set menu $mb.menu
    set x [winfo rootx $mb]
    set y [winfo rooty $mb]

    set bw [winfo width $mb]
    set bh [winfo height $mb]
    set mw [winfo reqwidth $menu]
    set mh [winfo reqheight $menu]
    set sw [expr {[winfo screenwidth  $menu] - $bw - $mw}]
    set sh [expr {[winfo screenheight $menu] - $bh - $mh}]

    switch -- $dir {
	above { if {$y >= $mh} { incr y -$mh } { incr y  $bh } }
	below { if {$y <= $sh} { incr y  $bh } { incr y -$mh } }
	left  { if {$x >= $mw} { incr x -$mw } { incr x  $bw } }
	right { if {$x <= $sw} { incr x  $bw } { incr x -$mw } }
    }

    return [list $x $y]
}

proc ::AvatarMB::PositionAlign {mb side x y} {
    set margin 8
    set menu $mb.menu
    set top [winfo toplevel $mb]

    set tx [winfo rootx $top]
    set ty [winfo rooty $top]
    set tw [winfo width $top]
    set th [winfo height $top]
    set mw [winfo reqwidth $menu]
    set mh [winfo reqheight $menu]
    
    switch -- $side {
	left   { set x [expr {$tx + $margin}] }
	right  { set x [expr {$tx + $tw - $mw - $margin}] }
	top    { set y [expr {$ty + $margin}] }
	bottom { set y [expr {$ty + $th - $mh - $margin}] }
    }
    
    return [list $x $y]
}

proc ::AvatarMB::PositionOnScreen {mb x y} {
    set margin 8
    set menu $mb.menu
    set mw [winfo reqwidth $menu]
    set mh [winfo reqheight $menu]
    set sw [winfo screenwidth $menu]
    set sh [winfo screenheight $menu]
    set x2 [expr {$x + $mw}]
    set y2 [expr {$y + $mh}]
    
    if {$x < $margin} {	set x $margin }
    if {$x2 > [expr {$sw - $margin}]} { set x [expr {$sw - $mw - $margin}] }
    if {$y < $margin} {	set y $margin }
    if {$y2 > [expr {$sh - $margin}]} { set y [expr {$sh - $mh - $margin}] }

    return [list $x $y]
}

proc ::AvatarMB::Menu {m args} {
    variable widget
    
    set active "#3874d1"
    array set style [list -foreground black -background gray80]
    array set style [style configure .]    
    array set map   [style map .]

    if {[info exists map(-background)]} {
	foreach {mstate mcol} $map(-background) {
	    if {[lsearch $mstate active] >= 0} {
		set active $mcol
		break
	    }
	}
    }
    set lightactive [::colorutils::getlighter $active]
    set border [::colorutils::getdarker $style(-background)]

    set widget(active)      $active
    set widget(lightactive) $lightactive
    set widget(border)      $border
        
    toplevel $m -class AvatarMBMenu -bd 0 -relief flat -takefocus 0
    
    wm overrideredirect $m 1
    wm transient $m
    wm resizable $m 0 0 
    
    ttk::frame $m.f -padding {0 4}
    pack $m.f -fill both -expand 1
    set f $m.f
    
    ttk::label $f.l -text "[mc {Recent Avatars}]:"
    pack $f.l -side top -anchor w -padx 18 -pady 2
    
    ttk::frame $f.box
    pack $f.box -side top -anchor w -padx 18 -pady 4
    set box $f.box
    
    set nbox   $widget(nboxside)
    set border $widget(border)
    set size   $widget(menusize)
    set bg     $widget(background)
    set bd 2
    set pd 1
    set min [expr {$size+2*($bd+$pd)}]
    
    for {set i 0} {$i < $nbox} {incr i} {
	for {set j 0} {$j < $nbox} {incr j} {
	    set label $box.l${i}${j}
	    label $label -relief flat -background $border -bd $bd \
	      -compound center -state disabled -highlightthickness 0
	    grid  $label  -column $j -row $i -sticky news -padx $pd -pady $pd
	    if {$i == 0} {
		grid columnconfigure $box $j -minsize $min
	    }
	    
	    bind $label <Enter>    { ::AvatarMB::AvatarEnter %W }
	    bind $label <Leave>    { ::AvatarMB::AvatarLeave %W }
	    bind $label <B1-Enter> { ::AvatarMB::AvatarEnter %W }
	    bind $label <B1-Leave> { ::AvatarMB::AvatarLeave %W }
	    	    
	    set label $label.l
	    label $label -bd 0 -background $bg -compound center  \
	      -highlightthickness 0 -state disabled
	    pack $label -fill both -expand 1

	    bind $label <ButtonPress-1>   { ::AvatarMB::MenuPickRecent %W }
	    bind $label <ButtonRelease-1> { ::AvatarMB::MenuPickRecent %W }
	}
	grid rowconfigure $box $i -minsize $min
    }
    bind $m <ButtonPress-1>   [list ::AvatarMB::MenuUnpost $m]
    
    bind $m <KeyPress> { }
    
    ttk::button $f.new -style FMenu -text "[mc Open]..." \
      -command ::AvatarMB::MenuNew
    BindFMenu $f.new
    pack $f.new -side top -anchor w -fill x

    if {0} {
	ttk::button $f.edit -style FMenu -text "[mc Edit]..." -state disabled
	BindFMenu $f.edit
	pack $f.edit -side top -anchor w -fill x
    }
    
    ttk::button $f.clear -style FMenu -text [mc mClearMenu] \
      -command ::AvatarMB::MenuClear
    BindFMenu $f.clear
    pack $f.clear -side top -anchor w -fill x
    
    ttk::button $f.remove -style FMenu  -text [mc Remove] \
      -command ::AvatarMB::MenuRemove
    BindFMenu $f.remove
    pack $f.remove -side top -anchor w -fill x
        
    FillInRecent $box
    
    array set wmA [wm attributes $m]
    if {[info exists wmA(-alpha)]} {
	wm attributes $m -alpha 0.92
    }
    return $m
}

proc ::AvatarMB::MenuFree {m} {
    variable priv
    
    array unset priv win2file,*
    eval {image delete} $priv(images)
    set priv(images) {}
}

# Generic FMenu code.

proc ::AvatarMB::BindFMenu {w} {
    bind $w <Enter>           { %W state active }
    bind $w <Leave>           { %W state !active }
    bind $w <B1-Enter>        { %W state pressed; %W state active }
    bind $w <B1-Leave>        { %W state !pressed; %W state !active }
    bind $w <ButtonPress-1>   { AvatarMB::MenuPress %W }
    bind $w <ButtonRelease-1> { AvatarMB::MenuRelease %W }
}

proc ::AvatarMB::AvatarEnter {w} {
    variable widget
    if {[$w cget -state] eq "normal"} {
	$w   configure -bg $widget(active)
	$w.l configure -bg $widget(lightactive)
    }
}

proc ::AvatarMB::AvatarLeave {w} {
    variable widget
    if {[$w cget -state] eq "normal"} {
	$w   configure -bg $widget(border)
	$w.l configure -bg $widget(background)
    }
}

proc ::AvatarMB::MenuPress {w} {
    MenuActivate $w
    return -code break
}

proc ::AvatarMB::MenuRelease {w} {
    MenuActivate $w
    return -code break
}

proc ::AvatarMB::MenuActivate {w} {
    set cmd [list]
    $w instate !disabled {
	set oldState [$w state !active]
	update idletasks; after 80
	$w state $oldState
	update idletasks; after 80
	set cmd [$w cget -command]
    } 
    MenuUnpost [MenuParent $w]
    if {[llength $cmd]} {
	uplevel #0 $cmd
    }
}

proc ::AvatarMB::MenuParent {w} {
    set wmenu $w
    while {($wmenu ne ".") && ([winfo class $wmenu] ne "AvatarMBMenu")} {
	set wmenu [winfo parent $wmenu]
    }
    return $wmenu
}

proc ::AvatarMB::MenuUnpost {m} {
    grab release $m
    RestoreOldGrab
    destroy $m
}

proc ::AvatarMB::FillInRecent {box} {
    global  this
    variable priv
    variable widget
    
    set childs [winfo children $box]
    set priv(images) {}
    set size $widget(menusize)

    foreach f [::Avatar::GetRecentFiles] {
	set fpath [file join $this(recentAvatarPath) $f]
	set image [image create photo -file $fpath]
	set scaled [::Avatar::CreateScaledPhoto $image $size]
	lappend priv(images) $image
	if {$scaled ne $image} {
	    lappend priv(images) $scaled
	}
	
	# Find label to put image in from the child list.
	set win [lindex $childs 0]
	set childs [lrange $childs 1 end]
	
	set label $win.l
	$win configure -state normal
	$label configure -image $scaled -state normal
	
	set priv(win2file,$label) $fpath
	
	if {![llength $childs]} {
	    break
	}
    }
}

proc ::AvatarMB::MenuPickRecent {w} {
    variable priv
    variable widget
    
    if {[$w cget -state] eq "normal"} {
	set parent [winfo parent $w]
	$parent configure -bg $widget(border)
	update idletasks; after 80
	$parent configure -bg $widget(active)
	update idletasks; after 80
	set fileName $priv(win2file,$w)
    }    
    MenuUnpost [MenuParent $w]

    # Invoke the "command".
    if {[info exists fileName]} {
	SetFileToShare $fileName
    }
}

proc ::AvatarMB::MenuNew {} {
    global  prefs
    
    set suffL [concat \
      [::Types::GetSuffixListForMime image/gif] \
      [::Types::GetSuffixListForMime image/png] \
      [::Types::GetSuffixListForMime image/jpeg]]
    set types [concat [list [list {Image Files} $suffL]] \
      [::Media::GetDlgFileTypesForMimeList {image/gif image/png image/jpeg}]]
    set opts [list]
    if {[file isdirectory $prefs(dir,avatarPick)]} {
	lappend opts -initialdir $prefs(dir,avatarPick)
    }
    set fileName [eval {tk_getOpenFile -title [mc "Select Avatar"]  \
      -filetypes $types} $opts]
    if {[file exists $fileName]} {
	set prefs(dir,avatarPick) [file dirname $fileName]
	SetFileToShare $fileName

    }
}

proc ::AvatarMB::VerifyPhotoFile {f} {
    
    set ok 0
    set suff [file extension $f]
    if {[regexp {(.gif|.jpg|.jpeg|.png)} $suff]} {
	set ok [::Media::HaveImporterForMime [::Types::GetMimeTypeForFileName $f]]
    }
    return $ok
}

proc ::AvatarMB::SetFileToShare {fileName} {
    
    # Share only if not identical to existing one.
    if {[::Avatar::IsMyPhotoSharedFromFile $fileName]} {
	::Avatar::SetShareOption 1
	::Avatar::AddRecentFile $fileName
    } else {
	if {[::Avatar::SetAndShareMyAvatarFromFile $fileName]} {
	    ::Avatar::AddRecentFile $fileName
	} else {
	}
    }
}

proc ::AvatarMB::MenuClear {} {
    ::Avatar::ClearRecent
}

proc ::AvatarMB::MenuRemove {} {
    ::Avatar::UnsetAndUnshareMyAvatar
}

proc ::AvatarMB::OnButtonRelease {m x y} {
    MenuUnpost $m
}


