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
# $Id: ChatTheme.tcl,v 1.1 2007-10-28 08:49:47 matben Exp $

package require Tkhtml 3.0

package provide ChatTheme 1.0

namespace eval ::ChatTheme {

    # The paths to search for chat themes.
    variable path
    set path(default) [file join $::this(resourcePath) themes chat]
    set path(prefs)   [file join $::this(prefsPath) resources themes chat]
    
    variable theme
    set theme(current) ""
    
    variable html
    set html(header) {<html><head></head><body>}
    set html(footer) {</body></html>}
    
    variable content
}

proc ::ChatTheme::AllThemes {} {
    variable path
    variable theme
    
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

proc ::ChatTheme::Widget {w} {
    variable content
    
    html $w -mode {almost standards}]

    $w configure -imagecmd [namespace code [list ImageCmd $w]]
    $w style $content(mainCss)
    $w parse $html(header)
    
    return $w
}

proc ::ChatTheme::ImageCmd {w url} {
    variable theme
    
    $theme(current)
    
    
}

proc ::ChatTheme::Incoming {w msg jid} {
    variable content
    
    set nextstr "At some time last year I wrote:"
    set avatar ???
    
    $w parse [string map [list %message% $nextstr] $content(inNext)]
    $w parse [string map \
      [list %message% $msg %sender% $jid %userIconPath% ???] $content(in)]

}

proc ::ChatTheme::Outgoing {w msg jid} {
    
    
}

proc ::ChatTheme::Status {w jid} {
    
    
}







