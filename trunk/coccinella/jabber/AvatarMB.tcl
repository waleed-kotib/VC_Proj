#  AvatarMB.tcl --
#
#      This file is part of The Coccinella application. 
#      It implements a megawidget menubutton for setting avatar.
#      
#  Copyright (c) 2006  Mats Bengtsson
#  
# $Id: AvatarMB.tcl,v 1.3 2006-12-08 13:42:52 matben Exp $

package provide AvatarMB 1.0

namespace eval ::AvatarMB {
    
    variable active "#3874d1"

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
      -map [list active $blue]
    
    if {0} {
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
    style map FMenu -foreground {active white}
    
    #bind FMenu <Enter>		{ %W state active; puts Enter }
    #bind FMenu <Leave>		{ %W state !active; puts Leave }
    #bind FMenu <B1-Enter>		{ %W state active }
    #bind FMenu <B1-Leave>		{ %W state !active }

}

proc ::AvatarMB::Button {mb args} {
    
    ttk::label $mb -style Sunken.TLabel \
      -compound image -image [::Rosticons::Get status/available]

    bind $mb <Enter>            { %W state active }
    bind $mb <Leave>            { %W state !active }
    bind $mb <Key-space>        { AvatarMB::Popdown %W }
    bind $mb <<Invoke>>         { AvatarMB::Popdown %W }
    bind $mb <ButtonPress-1>    { %W state pressed ; AvatarMB::Popdown %W }
    bind $mb <ButtonRelease-1>  { %W state !pressed ; puts ButtonRelease }

    bind $mb <Button1-Leave> 	{ %W state !pressed }
    bind $mb <Button1-Enter> 	{ %W instate {active !disabled} { %W state pressed } }

    return $mb
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
    
    for {set i 0} {$i < 4} {incr i} {
	for {set j 0} {$j < 4} {incr j} {
	    set label $box.l${i}${j}
	    label $label -relief flat -background gray80 -bd 2 \
	      -compound center
	    grid  $label  -column $j -row $i -sticky news -padx 1 -pady 1
	    if {$i == 0} {
		grid columnconfigure $box $j -minsize 32
	    }
	    
	    bind $label <Enter>    { ::AvatarMB::AvatarEnter %W }
	    bind $label <Leave>    { ::AvatarMB::AvatarLeave %W }
	    bind $label <B1-Enter> { ::AvatarMB::AvatarEnter %W }
	    bind $label <B1-Leave> { ::AvatarMB::AvatarLeave %W }
	    	    
	    set label $label.l
	    label $label -bd 0 -background white -compound center	    
	    pack $label -fill both -expand 1

	    bind $label <ButtonPress-1>   [list ::AvatarMB::MenuPickAvatar $m $i $j]
	    bind $label <ButtonRelease-1> [list ::AvatarMB::MenuPickAvatar $m $i $j]
	}
	grid rowconfigure $box $i -minsize 32
    }
    bind $m <ButtonPress-1>   [list ::AvatarMB::MenuUnpost $m]
    #bind $m <ButtonRelease-1> [list ::AvatarMB::MenuUnpost $m]
    #bind $m <ButtonRelease-1> [list ::AvatarMB::OnButtonRelease $m %x %y]
    
    ttk::button $f.n -style FMenu -text "Pick New..." \
      -command ::AvatarMB::MenuNew
    BindFMenu $m $f.n
    pack $f.n -side top -anchor w -fill x

    ttk::button $f.r -style FMenu -text "Clear Menu" \
      -command ::AvatarMB::MenuClear
    BindFMenu $m $f.r
    pack $f.r -side top -anchor w -fill x
    
    array set wmA [wm attributes $m]
    if {[info exists wmA(-alpha)]} {
	wm attributes $m -alpha 0.92
    }

    return $m
}

proc ::AvatarMB::BindFMenu {m win} {
    bind $win <Enter>    { %W state active }
    bind $win <Leave>    { %W state !active }
    bind $win <B1-Enter> { %W state pressed; %W state active }
    bind $win <B1-Leave> { %W state !pressed; %W state !active }
    bind $win <ButtonPress-1> [list ::AvatarMB::MenuPress $m %W]
    #bind $win <ButtonPress-1> {
#	%W instate !disabled { puts ButtonPress; %W state pressed; %W invoke } 
    #}
    bind $win <ButtonRelease-1> [list ::AvatarMB::MenuRelease $m $win]
    #bind $win <ButtonRelease-1> {
	#%W instate !disabled { puts ButtonRelease; %W invoke } 
    #}
}

proc ::AvatarMB::AvatarEnter {win} {
    variable active
    if {[$win cget -state] eq "normal"} {
	$win configure -bg $active
    }
}

proc ::AvatarMB::AvatarLeave {win} {
    if {[$win cget -state] eq "normal"} {
	$win configure -bg gray80
    }
}

proc ::AvatarMB::MenuPress {m win} {
    puts "::AvatarMB::MenuPress"
    $win instate !disabled {
	puts ButtonPress
	$win state pressed
	$win invoke 
	MenuUnpost $m
    } 
    return -code break
}

proc ::AvatarMB::MenuRelease {m win} {
    puts "::AvatarMB::MenuRelease"
    $win instate !disabled { 
	puts ButtonRelease
	$win invoke
	MenuUnpost $m
    } 
    return -code break
}

proc ::AvatarMB::MenuPickAvatar {m i j} {
    puts "::AvatarMB::MenuPickAvatar m=$m, i=$i, j=$j"
    MenuUnpost $m
}

proc ::AvatarMB::MenuGetMenu {win} {
    set w $win
    while {($w ne ".") && ([winfo class $w] ne "AvatarMBMenu")} {
	set w [winfo parent $w]
    }
    return $w
}

proc ::AvatarMB::MenuNew {} {
    
}

proc ::AvatarMB::MenuClear {} {
    puts "::AvatarMB::MenuClear ---"
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

proc ::AvatarMB::MenuUnpost {m} {
    puts "::AvatarMB::MenuUnpost m=$m"
    grab release $m
    destroy $m
}


