#  AvatarMB.tcl --
#
#      This file is part of The Coccinella application. 
#      It implements a megawidget menubutton for setting avatar.
#      
#  Copyright (c) 2006  Mats Bengtsson
#  
# $Id: AvatarMB.tcl,v 1.4 2006-12-10 16:13:33 matben Exp $

package require colorutils

package provide AvatarMB 1.0

namespace eval ::AvatarMB {
    
    variable active "#3874d1"
    variable border "#cccccc"
    set background [style configure . -background]
    if {$background ne ""} {
	set border [::colorutils::getdarker $background]
    }

    # Try make a fake menu entry widget.
    set blue ::AvatarMB::blue
    image create photo $blue -width 2 -height 2
    $blue blank
    $blue put [list [list $active $active] [list $active $active]]

    set blank ::AvatarMB::blank
    image create photo $blank -width 4 -height 4
    $blank blank

    style element create FMenu.background image $blank  \
      -padding {0} -sticky news  \
      -map [list {active !disabled} $blue]
    
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
    
    array set foreground [style map . -foreground]
    unset -nocomplain foreground(active)
    unset -nocomplain foreground(selected)
    unset -nocomplain foreground(focus)
    set foreground([list active !disabled]) white

    style configure FMenu  \
      -padding {18 2 10 2} -borderwidth 0 -relief flat
    style map FMenu -foreground [array get foreground]
    
    #bind FMenu <Enter>		{ %W state active; puts Enter }
    #bind FMenu <Leave>		{ %W state !active; puts Leave }
    #bind FMenu <B1-Enter>	{ %W state active }
    #bind FMenu <B1-Leave>	{ %W state !active }

    bind AvatarMBMenu <FocusIn> {}

}

proc ::AvatarMB::Button {mb args} {
    variable $mb
    upvar 0 $mb state
    
    ttk::label $mb -style SunkenMenubutton -compound image
    set myphoto [::Avatar::GetMyPhoto]
    if {$myphoto ne ""} {
	set state(photo) [::Avatar::CreateScaledPhoto $myphoto 24]
    } else {
	set state(photo) ""
    }
    set state(blank) [image create photo -width 24 -height 24]
    $state(blank) blank    
    if {$myphoto ne ""} {
	$mb configure -image $state(photo)
    } else {
	$mb configure -image $state(blank)
    }
    bind $mb <Enter>            { %W state active }
    bind $mb <Leave>            { %W state !active }
    bind $mb <Key-space>        { ::AvatarMB::Popdown %W }
    bind $mb <<Invoke>>         { ::AvatarMB::Popdown %W }
    bind $mb <ButtonPress-1>    { %W state pressed ; AvatarMB::Popdown %W }
    bind $mb <ButtonRelease-1>  { %W state !pressed ; puts ButtonRelease }

    bind $mb <Button1-Leave> 	{ %W state !pressed }
    bind $mb <Button1-Enter> 	{ %W instate {active !disabled} { %W state pressed } }

    bind $mb <Destroy>          { ::AvatarMB::ButtonFree %W }
    
    ::hooks::register avatarMyNewPhotoHook [list ::AvatarMB::NewPhotoHook $mb]
    
    return $mb
}

proc ::AvatarMB::ButtonFree {mb} {
    variable $mb
    upvar 0 $mb state
    
    hooks::deregister avatarMyNewPhotoHook [list ::AvatarMB::NewPhotoHook $mb]
    
    image delete $state(blank)
    if {$state(photo) ne ""} {
	image delete $state(photo)	
    }
    unset -nocomplain state
}

proc ::AvatarMB::NewPhotoHook {mb} {
    variable $mb
    upvar 0 $mb state
    
    puts "::AvatarMB::NewPhotoHook mb=$mb"
    
    if {$state(photo) ne ""} {
	image delete $state(photo)	
    }
    set myphoto [::Avatar::GetMyPhoto]
    if {$myphoto ne ""} {
	set state(photo) [::Avatar::CreateScaledPhoto $myphoto 24]
	puts "\t size=[image width $state(photo)], [image height $state(photo)]"
    } else {
	set state(photo) ""
    }
    $mb configure -image $state(photo)
}

proc ::AvatarMB::Popdown {mb} {
    puts "::AvatarMB::Popdown $mb"
    if {[$mb instate disabled]} {
	return
    }
    PostMenu $mb
}

proc ::AvatarMB::PostMenu {mb} {
    set menu $mb.menu
    Menu $menu
    foreach {x y} [PostPosition $mb below] { break }
    wm geometry $menu +$x+$y
    
    set oldGrab [grab current $menu]
    if {$oldGrab ne ""} {
	set grabStatus [grab status $oldGrab]
    }

    # This will direct all events to the menu even if the mouse is outside!
    grab -global $menu
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

proc ::AvatarMB::Menu {m args} {
    variable border
    
    toplevel $m -class AvatarMBMenu -bd 0 -relief flat -takefocus 0
    
    wm overrideredirect $m 1
    wm transient $m
    wm resizable $m 0 0 
    
    if {[tk windowingsystem] eq "aqua"} {
	#tk::unsupported::MacWindowStyle style $m help none
	#tk::unsupported::MacWindowStyle style $m toolbar none
	#tk::unsupported::MacWindowStyle style $m floating none
	#tk::unsupported::MacWindowStyle style $m moveableModal none
    }
    ttk::frame $m.f
    pack $m.f -fill both -expand 1
    set f $m.f
    
    ttk::label $f.l -text "Recent Avatars:"
    pack $f.l -side top -anchor w -padx 18 -pady 2
    
    ttk::frame $f.box
    pack $f.box -side top -anchor w -padx 18 -pady 4
    set box $f.box
    
    set bd 2
    set pd 1
    set min [expr {32+2*($bd+$pd)}]
    
    for {set i 0} {$i < 4} {incr i} {
	for {set j 0} {$j < 4} {incr j} {
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
	    label $label -bd 0 -background white -compound center  \
	      -highlightthickness 0 -state disabled
	    pack $label -fill both -expand 1

	    bind $label <ButtonPress-1>   { ::AvatarMB::MenuPickAvatar %W }
	    bind $label <ButtonRelease-1> { ::AvatarMB::MenuPickAvatar %W }
	}
	grid rowconfigure $box $i -minsize $min
    }
    bind $m <ButtonPress-1>   [list ::AvatarMB::MenuUnpost $m]
    bind $m <ButtonRelease-1>  {puts \tButtonRelease-1}
    #bind $m <ButtonRelease-1> [list ::AvatarMB::MenuUnpost $m]
    #bind $m <ButtonRelease-1> [list ::AvatarMB::OnButtonRelease $m %x %y]
    
    bind $m <KeyPress> { puts "KeyPress %W %A"}
    
    ttk::button $f.n -style FMenu -text "Pick New..." \
      -command ::AvatarMB::MenuNew
    BindFMenu $f.n
    pack $f.n -side top -anchor w -fill x

    ttk::button $f.c -style FMenu -text "Clear Menu" \
      -command ::AvatarMB::MenuClear
    BindFMenu $f.c
    pack $f.c -side top -anchor w -fill x
    
    ttk::button $f.r -style FMenu  -text [mc Remove] \
      -command ::AvatarMB::MenuRemove
    BindFMenu $f.r
    pack $f.r -side top -anchor w -fill x
        
    FillInRecent $box
    
    array set wmA [wm attributes $m]
    if {[info exists wmA(-alpha)]} {
	wm attributes $m -alpha 0.92
    }
    focus $m

    return $m
}

# Generic FMenu code.

proc ::AvatarMB::BindFMenu {w} {
    bind $w <Enter>           { %W state active ; puts "m=%m s=%s" }
    bind $w <Leave>           { %W state !active }
    bind $w <B1-Enter>        { %W state pressed; %W state active }
    bind $w <B1-Leave>        { %W state !pressed; %W state !active }
    bind $w <ButtonPress-1>   { ::AvatarMB::MenuPress %W }
    bind $w <ButtonRelease-1> { ::AvatarMB::MenuRelease %W }
}

proc ::AvatarMB::AvatarEnter {w} {
    variable active
    if {[$w cget -state] eq "normal"} {
	$w configure -bg $active
    }
}

proc ::AvatarMB::AvatarLeave {w} {
    variable border
    if {[$w cget -state] eq "normal"} {
	$w configure -bg $border
    }
}

proc ::AvatarMB::MenuPress {w} {
    puts "::AvatarMB::MenuPress"
    MenuActivate $w
    return -code break
}

proc ::AvatarMB::MenuRelease {w} {
    puts "::AvatarMB::MenuRelease"
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
    puts "::AvatarMB::MenuUnpost m=$m"
    grab release $m
    destroy $m
}


proc ::AvatarMB::FillInRecent {box} {
    global  this
    variable priv
    
    puts "::AvatarMB::FillInRecent"
    set childs [winfo children $box]

    foreach f [::Avatar::GetRecentFiles] {
	set fpath [file join $this(recentAvatarPath) $f]
	set image [image create photo -file $fpath]
	set scaled [::Avatar::CreateScaledPhoto $image 32]
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
    bind $box <Destroy> +::AvatarMB::FreeImages
}

proc ::AvatarMB::FreeImages {} {
    variable priv
    eval {image delete} $priv(images)
    set priv(images) {}
}

proc ::AvatarMB::MenuPickAvatar {w} {
    variable priv
    variable active
    variable border
    
    puts "::AvatarMB::MenuPickAvatar w=$w"
    
    if {[$w cget -state] eq "normal"} {
	set parent [winfo parent $w]
	$parent configure -bg $border
	update idletasks; after 80
	$parent configure -bg $active
	update idletasks; after 80

	# Invoke the "command".
	set fileName $priv(win2file,$w)
	::Avatar::AddRecentFile $fileName
	::Avatar::SetAndShareMyAvatarFromFile $fileName
    }    
    MenuUnpost [MenuParent $w]
}

proc ::AvatarMB::MenuNew {} {
    
    set suffs {.gif}
    set types {
	{{Image Files}  {.gif}}
	{{GIF Image}    {.gif}}
    }
    if {[::Plugins::HaveImporterForMime image/png]} {
	lappend suffs .png
	lappend types {{PNG Image}    {.png}}
    }
    if {[::Plugins::HaveImporterForMime image/jpeg]} {
	lappend suffs .jpg .jpeg
	lappend types {{JPEG Image}    {.jpg .jpeg}}
    }
    lset types 0 1 $suffs
    set fileName [tk_getOpenFile -title [mc {Pick Image File}]  \
      -filetypes $types]
    if {$fileName ne ""} {
	::Avatar::AddRecentFile $fileName
	::Avatar::SetAndShareMyAvatarFromFile $fileName
    }
}

proc ::AvatarMB::MenuClear {} {
    puts "::AvatarMB::MenuClear ---"
    ::Avatar::ClearRecent
}

proc ::AvatarMB::MenuRemove {} {
    ::Avatar::UnsetMyPhoto
}

proc ::AvatarMB::OnButtonRelease {m x y} {
    puts "::AvatarMB::OnButtonRelease $x $y"
    MenuUnpost $m
    if {0} {
	set mw [winfo reqwidth $m]
	set mh [winfo reqheight $m]
	if {($x < 0) || ($x > $mw)} {MenuUnpost $m}
	if {($y < 0) || ($y > $mh)} {MenuUnpost $m}
    }
}


