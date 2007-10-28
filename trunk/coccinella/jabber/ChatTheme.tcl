#  ChatTheme.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements chat themeing using Tkhtml.
#      
#  Copyright (c) 2007  Mats Bengtsson
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
# $Id: ChatTheme.tcl,v 1.2 2007-10-28 15:34:15 matben Exp $

package require Tkhtml 3.0

package provide ChatTheme 1.0

namespace eval ::ChatTheme {

    # The paths to search for chat themes.
    variable path
    set path(default) [file join $::this(resourcePath) themes chat]
    set path(prefs)   [file join $::this(prefsPath) resources themes chat]
    
    variable theme
    set theme(current) ""
    set theme(resources) ""
    
    variable html
    set html(header) {<html><head></head><body>}
    set html(footer) {</body></html>}
    
    variable content
    variable inited 0
}

proc ::ChatTheme::Init {} {
    variable inited
    variable path
    variable theme
    
    if {$inited} {
	return
    }
    foreach which {default prefs} {
	set theme($which) [list]
	set dirs [glob -nocomplain -directory $path($which) -types d *]
	foreach dir $dirs {
	    
	    # Do some rudimentary checking.
	    set f [file join $dir Contents Resources main.css]
	    if {[file exists $f]} {
		lappend theme($which) [file tail $dir]
	    }
	}
    }
    set inited 1
}

proc ::ChatTheme::AllThemes {} {
    variable theme
    Init
    return [concat $theme(default) $theme(prefs)]
}

proc ::ChatTheme::Current {} {
    variable theme
    return $theme(current)
}

proc ::ChatTheme::Readfile {fileName} {
    set fd [open $fileName r]
    set data [read $fd]
    close $fd
    return $data
}

proc ::ChatTheme::Set {name} {
    variable theme
    variable content
    
    puts "::ChatTheme::Set $name"

    Init
    set res [GetResourceDir $name]
    if {$res eq ""} {
	return -code error "unknown theme \"$name\""
    }
    unset -nocomplain content
    
    set content(mainCss)    [Readfile [file join $res main.css]]
    set content(in)         [Readfile [file join $res Incoming Content.html]]
    set content(inNext)     [Readfile [file join $res Incoming NextContent.html]]
    set content(out)        [Readfile [file join $res Outgoing Content.html]]
    set content(outNext)    [Readfile [file join $res Outgoing NextContent.html]]
    set content(status)     [Readfile [file join $res Status.html]]
    set content(statusNext) [Readfile [file join $res NextStatus.html]]
    
    set theme(current) $name
    set theme(resources) $res
}

proc ::ChatTheme::GetResourceDir {name} {
    variable path
    variable theme
   
    foreach which {default prefs} {
	if {[lsearch $theme($which) $name] >= 0} {
	    return [file join $path($which) $name Contents Resources]
	}
    }
    return
}

proc ::ChatTheme::Widget {token w args} {
    variable content
    variable html
    
    eval {html $w -mode {almost standards}} $args

    $w configure -imagecmd [namespace code [list ImageCmd $token]]
    $w style $content(mainCss)
    $w parse $html(header)
    
    return $w
}

proc ::ChatTheme::ImageCmd {token url} {
    variable theme
    
    puts "::ChatTheme::ImageCmd url=$url"
       
    if {$url eq "myAvatar"} {
	
	# Scale to size...
	set avatar [::Avatar::GetMyPhoto]
	return $avatar
    } elseif {$url eq "otherAvatar"} {
	set jid2 [::Chat::GetChatTokenValue $token jid2]
	set avatar [::Avatar::GetPhotoOfSize $jid2 32]
	if {$avatar eq ""} {
	    # Get default avatar from RosterAvatar
	    set avatar ""
	}
	return $avatar
    } else {
	set f [file join $theme(resources) $url]
	if {[file exists $f]} {
	    return [image create photo -file $f]
	} else {
	    return 
	}
    }
}

proc ::ChatTheme::Incoming {token xmldata time} {
    variable content
    
    set w [::Chat::GetChatTokenValue $token wtext]
    set jid [::Chat::GetChatTokenValue $token jid]
    
    set nextstr "At some time last year I wrote: $time"
    $w parse [string map [list %message% $nextstr] $content(inNext)]
    $w parse [string map \
      [list %message% $msg %sender% $jid %userIconPath% otherAvatar] $content(in)]
}

proc ::ChatTheme::Outgoing {token xmldata time} {
    
    set w [::Chat::GetChatTokenValue $token wtext]
    set jid [::Chat::GetChatTokenValue $token jid]

    set nextstr "At some time last year I wrote: $time"
    $w parse [string map [list %message% $nextstr] $content(outNext)]
    $w parse [string map \
      [list %message% $msg %sender% $jid %userIconPath% myAvatar] $content(out)]
}

proc ::ChatTheme::Status {token } {
    
    
}







