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
# $Id: ChatTheme.tcl,v 1.5 2007-10-31 15:46:47 matben Exp $

# @@@ Open issues:
#   o switching theme while open dialogs
#   o toggle history (<div id='history'/> ; DIV#history { display: none }
#   o switching font sizes through menu, custom style:
#     $w style -id user { td { font-size: 120% } }
#   o images (avatars) are cached, when new avatar set all changes,
#     also old messages


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
    variable wall [list]
}

proc ::ChatTheme::Init {} {
    variable inited
    variable path
    variable theme
    
    if {$inited} {
	return
    }
    puts "-----------::ChatTheme::Init"
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
    puts "        inited"
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
    variable wall
    
    puts "---------------::ChatTheme::Set $name"

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
    
    # Should we change theme for all existing widget? How?
    foreach w $wall {
	
    }
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
    variable wall
    
    eval {html $w -mode {almost standards}} $args

    $w configure -imagecmd [namespace code [list ImageCmd $token]]
    $w style $content(mainCss)
    $w parse $html(header)
    
    lappend wall $w
    
    bind $w <Destroy> +[namespace code { Free %W }]
    
    return $w
}

proc ::ChatTheme::Free {w} {
    variable wall
    lprune wall $w
}

# ChatTheme::Parse --
# 
#       Parse inline emoticons and uri's into relevant html code.

proc ::ChatTheme::Parse {jid str} {
    
    # Split string into words and whitespaces.
    set wsp {[ \t\r\n]+}
    set len [string length $str]
    if {$len == 0} {
	return
    }

    # Have hook for complete text.
    if {[hooks::run htmlPreParseHook chat $jid $str] eq "stop"} {	    
	return
    }

    set html ""
    set start 0
    while {[regexp -start $start -indices -- $wsp $str match]} {
	lassign $match matchStart matchEnd
	
	# The "space" part.
	set space [string range $str $matchStart $matchEnd]
	incr matchStart -1
	incr matchEnd
	
	# The word preceeding the space.
	set word [string range $str $start $matchStart]
	set start $matchEnd
	
	# Process the actual word:
	# Run first the hook to see if anyone else wants to parse it.
	if {[hooks::run htmlParseWordHook chat $jid $word] ne "stop"} {	    
	    append html [ParseWord $word]
	}
    
	# Insert the whitespace after word.
	append html $space
    }
    
    # And the final word.
    set word [string range $str $start end]
    if {[hooks::run htmlParseWordHook chat $jid $word] ne "stop"} {	    
	append html [ParseWord $word]
    }

    return $html
}

proc ::ChatTheme::ParseWord {word} {
    
    if {[::Emoticons::Exists $word]} {
	return "<img src=\"[uriencode::quote $word]\"/>"
    } elseif {![ParseURI $word]} {
	return $word
    } else {
	return $word
    }
}

proc ::ChatTheme::ParseURI {word} {
    
    
    return 0
}

proc ::ChatTheme::ImageCmd {token url} {
    variable theme
    
    #puts "::ChatTheme::ImageCmd url=$url"
       
    set durl [uriencode::decodeurl $url]
    if {$url eq "myAvatar"} {
	
	# Scale to size...
	set avatar [::Avatar::GetMyPhoto]
	if {$avatar eq ""} {
	    set avatar [::RosterAvatar::GetDefaultAvatarOfSize 32]
	}
	return $avatar
    } elseif {$url eq "otherAvatar"} {
	set jid2 [::Chat::GetChatTokenValue $token jid2]
	set avatar [::Avatar::GetPhotoOfSize $jid2 32]
	if {$avatar eq ""} {
	    set avatar [::RosterAvatar::GetDefaultAvatarOfSize 32]
	}
	return $avatar
    } elseif {[::Emoticons::Exists $durl]} {
	return [::Emoticons::Get $durl]
    } else {
	set f [file join $theme(resources) $url]
	if {[file exists $f]} {
	    return [image create photo -file $f]
	} else {
	    return 
	}
    }
}

proc ::ChatTheme::Incoming {token xmldata secs} {
    variable content
    
    set w [::Chat::GetChatTokenValue $token wtext]
    set jid [::Chat::GetChatTokenValue $token jid]
    set name [::Chat::MessageGetYouName $token $jid]
    set time [::Chat::MessageGetTime $token $secs]
    
    set bodyE [wrapper::getfirstchildwithtag $xmldata "body"]
    if {[llength $bodyE]} {
	set msg [wrapper::getcdata $bodyE]
	set msg [Parse $jid $msg]
	set nextstr "$name wrote at $time:"
	$w parse [string map [list %message% $nextstr] $content(inNext)]
	$w parse [string map \
	  [list %message% $msg %sender% $name %userIconPath% otherAvatar] $content(in)]
	after idle [list $w yview moveto 1.0]
    }
}

proc ::ChatTheme::Outgoing {token xmldata secs} {
    variable content
    
    set w [::Chat::GetChatTokenValue $token wtext]
    set jid [wrapper::getattribute $xmldata from]
    set name [::Chat::MessageGetMyName $token $jid]
    set time [::Chat::MessageGetTime $token $secs]

    set bodyE [wrapper::getfirstchildwithtag $xmldata "body"]
    if {[llength $bodyE]} {
	set msg [wrapper::getcdata $bodyE]
	set msg [Parse $jid $msg]
	set nextstr "$name wrote at $time:"
	$w parse [string map [list %message% $nextstr] $content(outNext)]
	$w parse [string map \
	  [list %message% $msg %sender% $name %userIconPath% myAvatar] $content(out)]
	after idle [list $w yview moveto 1.0]
    }
}

proc ::ChatTheme::Status {token xmldata secs} {
    variable content
    
    set w [::Chat::GetChatTokenValue $token wtext]
    set jid [::Chat::GetChatTokenValue $token jid]
    set name [::Chat::MessageGetYouName $token $jid]

    set color red
    set str [::Chat::PresenceGetString $token $xmldata]
    $w parse [string map [list %message% $name %color% $color] $content(statusNext)]
    $w parse [string map [list %message% $str %color% $color] $content(status)]
    after idle [list $w yview moveto 1.0]
}

