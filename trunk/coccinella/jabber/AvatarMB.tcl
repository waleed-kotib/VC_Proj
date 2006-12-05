#  AvatarMB.tcl --
#
#      This file is part of The Coccinella application. 
#      It implements a megawidget menubutton for setting avatar.
#      
#  Copyright (c) 2006  Mats Bengtsson
#  
# $Id: AvatarMB.tcl,v 1.1 2006-12-05 13:54:33 matben Exp $

package provide AvatarMB 1.0

namespace eval ::AvatarMB {
    
    
    
}

proc ::AvatarMB::Button {w args} {
    
    ttk::button $w -style Plain  \
      -compound image -image [::Rosticons::Get status/available]  \
      -command [list ::AvatarMB::Command $w]

    return $w
}

proc ::AvatarMB::Command {w} {
    
    set menu $w.menu
    Menu $menu
    wm geometry $menu +[winfo rootx $w]+[winfo rooty $w]
    grab -global $menu
}

proc ::AvatarMB::Menu {m args} {
    
    toplevel $m -class AvatarMBMenu -bd 0 -relief flat -takefocus 0
    
    wm overrideredirect $m 1
    wm transient $m
    wm resizable $m 0 0 
    
    if {[tk windowingsystem] eq "aqua"} {
	#tk::unsupported::MacWindowStyle style $m help none
	#tk::unsupported::MacWindowStyle style $m toolbar none
	tk::unsupported::MacWindowStyle style $m floating none
    }
    ttk::frame $m.f
    pack $m.f -fill both -expand 1
    set f $m.f
    
    ttk::label $f.l -text "Recent Avatars:"
    pack $f.l -side top -anchor w
    
    ttk::frame $f.box
    pack $f.box -side top -anchor w -padx 8 -pady 4
    set box $f.box
    
    for {set i 0} {$i < 4} {incr i} {
	for {set j 0} {$j < 4} {incr j} {
	    set label $box.l${i}${j}
	    label $label -relief flat -background gray80 -bd 2  \
	      -compound center -activebackground blue
	    grid  $label  -column $j -row $i -sticky news -padx 1 -pady 1
	    if {$i == 0} {
		grid columnconfigure $box $j -minsize 32
	    }
	    bind $label <Button-1> [list ::AvatarMB::MenuPickAvatar $m $i $j]
	}
	grid rowconfigure $box $i -minsize 32
    }
    bind $m <Button-1> {::AvatarMB::MenuRelease %W}

    array set wmA [wm attributes $m]
    if {[info exists wmA(-alpha)]} {
	wm attributes $m -alpha 0.8
    }

    return $m
}

proc ::AvatarMB::MenuPickAvatar {m i j} {
    puts "::AvatarMB::MenuPickAvatar"
    MenuRelease $m
}

proc ::AvatarMB::MenuRelease {m} {
    puts "::AvatarMB::MenuRelease"
    grab release $m
    destroy $m
}







