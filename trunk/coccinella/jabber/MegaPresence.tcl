#  MegaPresence.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements a mega presence widget.
#      
#  Copyright (c) 2007-2008  Mats Bengtsson
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
# $Id: MegaPresence.tcl,v 1.21 2008-09-13 22:11:26 sdevrieze Exp $

package provide MegaPresence 1.0

namespace eval ::MegaPresence {

    option add *MegaPresence.padding       {4 2 2 2}     50
    option add *MegaPresence.box.padding   {4 2 8 2}     50
    option add *MegaPresence*TLabel.style  Small.TLabel  widgetDefault
    
    variable widgets
    set widgets(all) [list]
    
    ::JUI::SlotRegister megapresence [namespace code Build] -priority 20
    
    set ::config(megapresence,pack-side) right
    set ::config(megapresence,equal-size) 1
}

proc ::MegaPresence::Register {name label cmd} {
    variable widgets
    
    set widgets($name,name)  $name
    set widgets($name,label) $label
    set widgets($name,cmd)   $cmd
    lappend widgets(all) $name
    return $name
}

proc ::MegaPresence::Build {w args} {
    global  config
    variable widgets
    variable slot
        
    array set argsA {
	-collapse 1
    }
    set argsA(-close) [namespace code [list Close $w]]
    array set argsA $args
    
    ttk::frame $w -class MegaPresence
    
    if {$argsA(-collapse)} {
	set slot(collapse) 0
	ttk::checkbutton $w.arrow -style Arrow.TCheckbutton \
	  -command [namespace code [list CollapseCmd $w]] \
	  -variable [namespace current]::slot(collapse)
	pack $w.arrow -side left -anchor n	
	bind $w       <<ButtonPopup>> [namespace code [list Popup %W $w %x %y]]
	bind $w.arrow <<ButtonPopup>> [namespace code [list Popup %W $w %x %y]]

	set subPath [file join images 16]
	set im  [::Theme::FindIconSize 16 close-aqua]
	set ima [::Theme::FindIconSize 16 close-aqua-active]
	ttk::button $w.close -style Plain  \
	  -image [list $im active $ima] -compound image  \
	  -command $argsA(-close)
	pack $w.close -side right -anchor n	

        ::balloonhelp::balloonforwindow $w.arrow [mc "Right click to open menu"]
        ::balloonhelp::balloonforwindow $w.close [mc "Close Slot"]
    }    
    set box $w.box
    set widgets(box) $w.box
    ttk::frame $box
    pack $box -fill x -expand 1

    bind $box <<ButtonPopup>> [namespace code [list Popup %W $w %x %y]]

    if {$config(ui,status,menu) eq "plain"} {
	::Status::MainButton $box.pres ::Jabber::jstate(show)
    } elseif {$config(ui,status,menu) eq "dynamic"} {
	::Status::ExMainButton $box.pres ::Jabber::jstate(show+status)
	#	-style SunkenMenubutton
    }
    ttk::label $box.lpres -text [mc "Status"]
    
    grid  $box.pres   -column 0 -row 0
    grid  $box.lpres  -column 0 -row 1
    
    ::AvatarMB::Button $box.avatar
    ttk::label $box.lavatar -text [mc "Avatar"]
    
    grid  $box.avatar   -column 100 -row 0
    grid  $box.lavatar  -column 100 -row 1
    
    set avatarW [winfo reqwidth $box.avatar]
    set avatarH [winfo reqheight $box.avatar]
    #puts "      $avatarW, $avatarH"
    
    ::balloonhelp::balloonforwindow $box.avatar [mc "Avatar"]

    if {$config(megapresence,pack-side) eq "right"} {
	ttk::frame $box.pad
	grid  $box.pad  -column 1 -sticky ew
	grid columnconfigure $box 1 -weight 1
	set column 2	
    } else {
	ttk::frame $box.pad
	grid  $box.pad  -column 99 -sticky ew
	grid columnconfigure $box 99 -weight 1
	set column 1
    }
    foreach name $widgets(all) {
	set opts [uplevel #0 $widgets($name,cmd) $box.$column]
	eval {grid  $box.$column  -row 0 -column $column -padx 4} $opts
	ttk::label $box.l$column -text $widgets($name,label)
	grid  $box.l$column  -row 1 -column $column -padx 2 -pady 0

	#puts "    name=$name, [winfo reqwidth $box.$column], [winfo reqheight $box.$column]"
	
	set widgets($name,column) $column
	set widgets($name,win) $box.$column
	set widgets($name,lwin) $box.l$column
	set widgets($name,display) 1
	::balloonhelp::balloonforwindow $box.$column $widgets($name,label)

	if {$config(megapresence,equal-size)} {
	    grid  $box.$column  -sticky ns
	    grid columnconfigure $box $column -minsize $avatarW
	}
	
	incr column
    }    

    set slot(w)    $w
    set slot(show) 0
    
    foreach m [::JUI::SlotGetAllMenus] {
	$m add checkbutton -label [mc "Presence Control"] \
	  -variable [namespace current]::slot(show) \
	  -command [namespace code SlotCmd]
    }
    if {[::JUI::SlotPrefsMapped megapresence]} {
	::JUI::SlotShow megapresence
	set slot(show) 1
    }
    
    return $w
}

proc ::MegaPresence::SlotCmd {} {
    if {[::JUI::SlotShowed megapresence]} {
	::JUI::SlotClose megapresence
    } else {
	::JUI::SlotShow megapresence
    }
}

proc ::MegaPresence::CollapseCmd {w} {
    variable widgets
    variable slot

    if {$slot(collapse)} {
	pack forget $widgets(box)
    } else {
	pack $widgets(box) -fill both -expand 1
    }
    #event generate $w <<Xxx>>
}

proc ::MegaPresence::Popup {W w x y} {
    variable widgets

    set m $w.m
    destroy $m
    menu $m -tearoff 0
    
    foreach name $widgets(all) {
	$m add checkbutton -label $widgets($name,label) \
	  -command [namespace code [list MenuCmd $w $name]] \
	  -variable [namespace current]::widgets($name,display)
    }
    
    update idletasks
    
    set X [expr [winfo rootx $W] + $x]
    set Y [expr [winfo rooty $W] + $y]
    tk_popup $m [expr {int($X) - 0}] [expr {int($Y) - 0}]   
    
    return -code break
}

proc ::MegaPresence::MenuCmd {w name} {
    variable widgets
    
    if {$widgets($name,display)} {
	set column $widgets($name,column)
	grid  $widgets($name,win)   -row 0 -column $column
	grid  $widgets($name,lwin)  -row 1 -column $column -padx 2 -pady 2
    } else {
	grid forget $widgets($name,win) $widgets($name,lwin)
    }
}

proc ::MegaPresence::Close {w} {
    variable slot
    set slot(show) 0
    ::JUI::SlotClose megapresence
}



