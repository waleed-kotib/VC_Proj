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
#  $Id: LiveRosterImage.tcl,v 1.6 2008-04-26 05:47:30 matben Exp $

namespace eval ::LiveRosterImage {

    if {[tk windowingsystem] ne "aqua"} {
	return
    }
    if {[catch {package require tkpath 0.3.0}]} {
	return
    }
    component::define LiveRosterImage "Draw an overlay to the roster background image"
}

proc ::LiveRosterImage::Init {} {
    
    component::register LiveRosterImage

    # Add event hooks.
    ::hooks::register setPresenceHook [namespace code PresenceHook]
    if {0 && [info tclversion] >= 8.5 && [tk windowingsystem] eq "aqua"} {
	::hooks::register connectInitHook [namespace code ConnectInitHook]
	::hooks::register connectHook     [namespace code ConnectHook]
	::hooks::register disconnectHook  [namespace code DisconnectHook]
    }
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

    set show [::Jabber::Jlib mypresence]
    set status [::Jabber::Jlib mypresencestatus]
    set showStr [::Roster::MapShowToText $show]

    # Find size for each line and adjust the font size.
    set family {Lucida Grande}
    set size 16
    set maxSize 52
    set font [list $family $size]
    
    # Scale font size to fit.
    set len [font measure $font $showStr]
    set size1 [min [expr {$size*($width - 40)/$len}] $maxSize]
    set font1 [list $family $size1]
    set linespace1 [font metrics $font1 -linespace]
    set descent1 [font metrics $font1 -descent]
    set y1 [expr {$linespace1 + 20}]
    
    set str2L [list]
    if {$status ne ""} {
	set str2L [list $status]
	set n [string length $status]
	set len [font measure $font $status]

	# Split status message into two lines if long.
	if {$len >= $width} {
	    set idx [string first " " $status [expr {$n/2}]]
	    if {$idx >= 0} {
		set str2L [list \
		  [string range $status 0 [expr {$idx-1}]] \
		  [string range $status [expr {$idx+1}] end]]
		set len [font measure $font [lindex $str2L 0]]
	    }
	}
	set size2 [min [expr {$size*($width - 20)/$len}] $maxSize]
	set font2 [list $family $size2]
	set linespace2 [font metrics $font2 -linespace]
	set y2 [expr {$y1 + $descent1 + $linespace2}]
    }
    
    set S [::tkp::surface new $width $height]
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
    foreach str $str2L {
	$S create ptext $width2 $y2 -text $str -textanchor middle \
	  -fontfamily $family -fontsize $size2 -fill $fill -fillopacity $opacity
	incr y2 $linespace2
    }
    set new [$S copy [image create photo]]
    $S destroy
    image delete $orig
    
    ::RosterTree::BackgroundImageConfig $new
}

# Experimental!

namespace eval ::LiveRosterImage {
    
    variable woverlay -
}

# This suffers from a BUG in tkpath!
# It seems it doesn't redraw background with systemTransparent?

proc ::LiveRosterImage::ConnectInitHook {} {
    variable woverlay
    
    set win [::JUI::GetRosterFrame]
    set width [winfo width $win]
    set height [winfo height $win]
    set w2 [expr {$width/2}]
    set h2 [expr {$height/2}]
    
    set woverlay $win.overlay
    tkp::canvas $woverlay -bg systemTransparent -highlightthickness 0 -bd 0
    place $woverlay -x 0 -y 0 -relwidth 1 -relheight 1
    
    $woverlay create prect 0 0 2000 2000 \
      -fill gray20 -fillopacity 0.2 -stroke ""
    $woverlay create ptext $w2 $h2 -textanchor middle -text "Connecting..." \
      -fontfamily {Lucida Grande} -fontsize 24 -fill gray50 \
      -fillopacity 0.6
}

proc ::LiveRosterImage::ConnectHook {} {
    variable woverlay
    destroy $woverlay
}

proc ::LiveRosterImage::DisconnectHook {} {
    variable woverlay
    destroy $woverlay
}


