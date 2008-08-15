#  MicroBlog.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements micro blogging.
#      
#  Copyright (c) 2008  Mats Bengtsson
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
# $Id: MicroBlog.tcl,v 1.5 2008-08-15 13:17:24 matben Exp $

package provide MicroBlog 1.0


namespace eval ::MicroBlog {

    option add *MicroBlogSlot.padding       {4 2 2 2}     50
    option add *MicroBlogSlot.box.padding   {4 2 8 2}     50
    option add *MicroBlogSlot*TLabel.style  Small.TLabel  widgetDefault
    option add *MicroBlogSlot*TEntry.font   CociSmallFont widgetDefault

    ::JUI::SlotRegister microblog [namespace code SlotBuild]
    
    ::hooks::register loginHook     ::MicroBlog::SlotLoginHook
    ::hooks::register logoutHook    ::MicroBlog::SlotLogoutHook
    
    variable slot
}

proc ::MicroBlog::SlotBuild {w} {
    variable slot
    
    ttk::frame $w -class MicroBlogSlot

    if {1} {
	set slot(collapse) 0
	ttk::checkbutton $w.arrow -style Arrow.TCheckbutton \
	  -command [list [namespace current]::SlotCollapse $w] \
	  -variable [namespace current]::slot(collapse)
	pack $w.arrow -side left -anchor n	
	bind $w       <<ButtonPopup>> [list [namespace current]::SlotPopup $w %x %y]
	bind $w.arrow <<ButtonPopup>> [list [namespace current]::SlotPopup $w %x %y]

	set im  [::Theme::FindIconSize 16 close-aqua]
	set ima [::Theme::FindIconSize 16 close-aqua-active]
	ttk::button $w.close -style Plain  \
	  -image [list $im active $ima] -compound image  \
	  -command [namespace code [list SlotClose $w]]
	pack $w.close -side right -anchor n	

	::balloonhelp::balloonforwindow $w.close [mc "Close Slot"]
    }    
    set box $w.box
    ttk::frame $box
    pack $box -fill x -expand 1

    ttk::label $box.l -text [mc "Micro Blog"]:
    ttk::entry $box.e -textvariable [namespace current]::slot(text)
    
    grid  $box.l  $box.e
    grid $box.e -sticky ew
    grid columnconfigure $box 1 -weight 1
    
    $box.e state {disabled}
    
    bind $box.e <Return>   [namespace code SlotSend]
    bind $box.e <KP_Enter> [namespace code SlotSend]
    
    bind $box   <<ButtonPopup>> [list [namespace current]::SlotPopup $w %x %y]
    bind $box.l <<ButtonPopup>> [list [namespace current]::SlotPopup $w %x %y]
    bind $box.e <<ButtonPopup>> [list [namespace current]::SlotPopup $w %x %y]
    ::balloonhelp::balloonforwindow $box  [mc "Enter your blog post here and press Return"]

    set slot(w)     $w
    set slot(box)   $w.box
    set slot(entry) $box.e
    set slot(text)  "Not implemented"
    set slot(show)  0

    # Add menu.    
    # This isn't the right way!
    foreach m [::JUI::SlotGetAllMenus] {
	$m add checkbutton -label [mc "Micro Blog"] \
	  -variable [namespace current]::slot(show) \
	  -command [namespace code SlotCmd]
    }
    if {[::JUI::SlotPrefsMapped microblog]} {
	::JUI::SlotShow microblog
	set slot(show) 1
    }
    return $w
}

proc ::MicroBlog::SlotCmd {} {
    if {[::JUI::SlotShowed microblog]} {
	::JUI::SlotClose microblog
    } else {
	::JUI::SlotShow microblog
    }
}

proc ::MicroBlog::SlotLoginHook {} {
    variable slot
    
    $slot(entry) state {!disabled}
}

proc ::MicroBlog::SlotLogoutHook {} {
    variable slot
    
    $slot(entry) state {disabled}
}

proc ::MicroBlog::SlotSend {} {
    variable slot
    
    # ???
}

proc ::MicroBlog::SlotPopup {w x y} {
    
}

proc ::MicroBlog::SlotCollapse {w} {
    variable slot

    if {$slot(collapse)} {
	pack forget $slot(box)
    } else {
	pack $slot(box) -fill both -expand 1
    }
    #event generate $w <<Xxx>>
}

proc ::MicroBlog::SlotClose {w} {
    variable slot
    set slot(show) 0
    ::JUI::SlotClose microblog
}
