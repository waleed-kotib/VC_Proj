# LiveRosterImage.tcl --
# 
#       Makes a custom overlay to any roster background image.
#
#  Copyright (c) 2007 Mats Bengtsson
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
#  $Id: LiveRosterImage.tcl,v 1.1 2007-08-25 07:36:52 matben Exp $

namespace eval ::LiveRosterImage {}

proc ::LiveRosterImage::Init {} {
    
    if {[catch {package require tkpath 0.2.6}]} {
	return
    }
    component::register LiveRosterImage "Draw an overlay to the roster background image"

    # Add event hooks.
    ::hooks::register setPresenceHook       [namespace code PresenceHook]
}

proc ::LiveRosterImage::PresenceHook {type args} {
    Draw
}

proc ::LiveRosterImage::Draw {} {

    set orig [::RosterTree::BackgroundImageGet]
    if {$orig eq ""} {
	return
    }
    set width  [image width $orig]
    set height [image height $orig]
    if {($width < 100) || ($height < 100)} {
	return
    }

    set show [::Jabber::JlibCmd mypresence]
    set status [::Jabber::JlibCmd mypresencestatus]
    set showStr [::Roster::MapShowToText $show]

    # Find size for each line and adjust the font size.
    set family {Lucida Grande}
    set size 24
    set font [list $family $size]
    
    # Scale font size to fit.
    set len [font measure $font $showStr]
    set size1 [expr {$size*($width - 40)/$len}]
    set font1 [list $family $size1]
    set linespace [font metrics $font1 -linespace]
    set descent [font metrics $font1 -descent]
    set y1 [expr {$linespace + 20}]
    
    if {$status ne ""} {
	set len [font measure $font $status]
	set size2 [expr {$size*($width - 20)/$len}]
	set font2 [list $family $size2]
	set linespace [font metrics $font2 -linespace]
	set y2 [expr {$y1 + $descent + $linespace}]
    }
    
    set S [::tkpath::surface new $width $height]
    $S create pimage 0 0 -image $orig
    
    if {0} {
	set avatar [::Avatar::GetMyPhoto]
	if {$avatar ne ""} {
	    $S create pimage 10 10 -image $avatar -matrix {{3 0} {0 3} {0 0}}
	}
    }
    
    # Get from resources.
    set opacity 0.7
    set fill white
    set width2 [expr {$width/2}]
    $S create ptext $width2 $y1 -text $showStr -textanchor middle \
      -fontfamily $family -fontsize $size1 -fill $fill -fillopacity $opacity
    if {$status ne ""} {
	$S create ptext $width2 $y2 -text $status -textanchor middle \
	  -fontfamily $family -fontsize $size2 -fill $fill -fillopacity $opacity
    }
    set new [$S copy [image create photo]]
    $S destroy
    image delete $orig
    
    ::RosterTree::BackgroundImageConfig $new
}




