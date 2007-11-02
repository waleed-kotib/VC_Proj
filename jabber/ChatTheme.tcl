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
# $Id: ChatTheme.tcl,v 1.7 2007-11-02 16:03:23 matben Exp $

# @@@ Open issues:
#   o switching theme while open dialogs
#   o toggle history (<div id='history'/> ; DIV#history { display: none }
#   o switching font sizes through menu, custom style:
#     $w style -id user { td { font-size: 120% } }
#   o images (avatars) are cached, when new avatar set all changes,
#     also old messages; default avatar wont change to user;
#     could perhaps use a new uri: "otherAvatar-[incr uid]" to trigger this
#   o handle links (<a href...>, see the hv3 code for this; messy!
#   o Missing: The central element is a div element named Chat
#   o find some simple default templates that can be used as a fallback


package require Tkhtml 3.0
package require pipes

package provide ChatTheme 1.0

namespace eval ::ChatTheme {
    
    ::hooks::register avatarMyNewPhotoHook [namespace code MyAvatarHook]
    ::hooks::register avatarNewPhotoHook   [namespace code OtherAvatarHook]
    
    # The paths to search for chat themes.
    variable path
    set path(default) [file join $::this(resourcePath) themes chat]
    set path(prefs)   [file join $::this(prefsPath) resources themes chat]
    
    variable theme
    set theme(current) ""
    set theme(variant) ""
    set theme(resources) ""
    
    variable html
    set html(Header) {
	<html><head></head><body>
    }
    set html(Footer) {
	</body></html>
    }
    set html(Status) {
	<div class="status">%message%</div><div id="insert"></div>
    }
    set html(HistoryDiv) {<div id="history"></div>}

    # Defaults as fallbacks.
    # @@@ Need to figure out a very simple one.
    variable hdefault
    set hdefault(Header) {}
    set hdefault(Footer) {}
    set hdefault(Status) {
	<div class="status">%message%</div><div id="insert"></div>
    }
    set hdefault(in) {
	<div class="incoming">
	<div class="incomingsender">%sender%</div> 
	<div class="incomingmessage">%message%</div> 
	</div>
	<div id="insert"></div> 
    }
    set hdefault(inNext) $hdefault(in)
    set hdefault(out) {
	<div class="outgoing">
	<div class="outgoingsender">%sender%</div> 
	<div class="outgoingmessage">%message%</div> 
	</div>
	<div id="insert"></div> 
    }
    set hdefault(outNext) $hdefault(out)
    
    variable style
    set style(HistoryDiv) { DIV#history { display: none; } }
    
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
    set inited 1
}

# ChatTheme::Reload --
# 
#       Force a new initialization.

proc ::ChatTheme::Reload {} {
    variable inited
    set inited 0
    Init
}

proc ::ChatTheme::AllThemes {} {
    variable theme
    Init
    return [concat $theme(default) $theme(prefs)]
}

proc ::ChatTheme::Variants {name} {
    variable theme
    variable path
    
    set res [GetResourceDir $name]
    if {$res eq ""} {
	return -code error "unknown theme \"$name\""
    }
    set varDir [file join $dir Variants]
    set all [glob -nocomplain -directory $varDir -types f -tails *.css]
    return [lapply {file rootname} $all]
}

proc ::ChatTheme::SetVariant {variant} {
    variable theme
    variable wall
    
    set res [GetResourceDir $theme(current)]
    set dir [file join $res Variants]
    set content(varCss) [Readfile [file join $dir $variant.css]]
    
    foreach w $wall {
	$w style -importcmd [namespace code [list ImportCmd $w $dir]] \
	  $content(varCss)
    }
}

proc ::ChatTheme::ImportCmd {w dir url} {
     
    # Resolve url.
    set data [Readfile [file normalize [file join $dir $url]]]
    $w style -importcmd [namespace code [list ImportCmd $w]] $data
    return
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
    variable html
    variable hdefault
    
    puts "---------------::ChatTheme::Set $name"

    Init
    set res [GetResourceDir $name]
    if {$res eq ""} {
	return -code error "unknown theme \"$name\""
    }
    unset -nocomplain content
    
    # Keep defaults as a fallback.
    foreach name {Header Footer Status} {
	set f [file join $res $name.html]
	if {[file exists $f]} {
	    set content($name) [Readfile $f]
	} else {
	    set content($name) $hdefault($name)
	}
    }
    
    set content(mainCss)    [Readfile [file join $res main.css]]
    set content(varCss)     ""
    set content(in)         [Readfile [file join $res Incoming Content.html]]
    set content(inNext)     [Readfile [file join $res Incoming NextContent.html]]
    set content(out)        [Readfile [file join $res Outgoing Content.html]]
    set content(outNext)    [Readfile [file join $res Outgoing NextContent.html]]
    # Seems optional...
    #set content(statusNext) [Readfile [file join $res NextStatus.html]]

    
    set theme(current) $name
    set theme(variant) ""
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

# @@@ TODO
# When we have updated our avatar we could have a hook that updates 
# a counter and use a new uri: "otherAvatar-[incr uid]" to trigger this

proc ::ChatTheme::MyAvatarHook {} {
    
    puts "::ChatTheme::MyAvatarHook"
    
}

proc ::ChatTheme::OtherAvatarHook {jid2} {
    
    puts "::ChatTheme::OtherAvatarHook jid2=$jid2"
    
}

proc ::ChatTheme::Widget {token w args} {
    variable content
    variable html
    variable style
    variable wall
    
    # Keep an instance specific state array.
    variable $w
    upvar 0 $w state
    
    # Keep track of last type: in | out |status
    set state(lastType) ""

    set jid [::Chat::GetChatTokenValue $token jid]
    set name [::Chat::MessageGetYouName $token $jid]
    set myname [::Chat::MessageGetMyName $token $jid]
    set time [::Chat::MessageGetTime $token [clock seconds]]

    #eval {html $w -mode {almost standards}} $args
    eval {html $w -mode quirks} $args

    $w handler node "div" [namespace code [list NodeHandler $token]]
    $w configure -imagecmd [namespace code [list ImageCmd $token]]
    $w style $content(mainCss)
    $w style $style(HistoryDiv)
    $w parse $html(Header)
    
    set map [list %chatName% $name %sourceName% $myname %destinationName% $name \
      %incomingIconPath% otherAvatar %outgoingIconPath% myAvatar \
      %timeOpened% $time]
    
    $w parse [string map $map $content(Header)]
    $w parse $html(HistoryDiv)
    
    if {[tk windowingsystem] eq "aqua"} {
	#$w style -id user-001 { font: "Lucida Grande"; }
    }
    
    lappend wall $w
    
    bind $w <Destroy> +[namespace code { Free %W }]
    
    return $w
}

proc ::ChatTheme::NodeHandler {token node} {
    
    set attr [$node attribute]
    puts "::ChatTheme::NodeHandler node=$node, attr=$attr"
    
}

proc ::ChatTheme::Free {w} {
    variable $w
    variable wall
    
    lprune wall $w
    unset -nocomplain $w
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
	set word [pipes::run htmlParseWordPipe chat jid $word]

	append html [ParseWord $word]
    
	# Insert the whitespace after word.
	append html $space
    }
    
    # And the final word.
    set word [string range $str $start end]
    set word [pipes::run htmlParseWordPipe chat jid $word]
    append html [ParseWord $word]

    return $html
}

proc ::ChatTheme::ParseWord {word} {
    
    if {[::Emoticons::Exists $word]} {
	return "<img src=\"[uriencode::quote $word]\"/>"
    } elseif {[ParseURI $word]} {
	return "<a href=\"$word\">$word</a>"
    } else {
	return $word
    }
}

proc ::ChatTheme::ParseURI {word} {
    
    foreach {re cmd} [::Text::GetREUriList] {
	if {[regexp $re $word]} {
	    return 1
	}
    }
    return 0
}

proc ::ChatTheme::CopyPhoto {name} {
    set new [image create photo]
    $new copy $name -compositingrule set -shrink
    return $new
}

proc ::ChatTheme::ImageCmd {token url} {
    variable theme
    
    puts "::ChatTheme::ImageCmd url=$url"
    
    # NB1: When tkhtml gets an image it is cached inside and destroyed
    #      together with the widget. We therefore MUST create images for
    #      explicit use by tkhtml and NEVER return a reference to an
    #      existing image since this will generate problems.
           
    # When we have updated our avatar we could have a hook that updates 
    # a counter and use a new uri: "otherAvatar-[incr uid]" to trigger this
    
    set name ""
    set durl [uriencode::decodeurl $url]
    if {$url eq "myAvatar"} {
	
	# Scale to size...
	set name [::Avatar::GetMyPhoto]
	if {$name eq ""} {
	    set f [file join $theme(resources) Outgoing buddy_icon.png]
	    if {[file exists $f]} {
		set name [image create photo -file $f]
	    } else {
		set name [CopyPhoto [::RosterAvatar::GetDefaultAvatarOfSize 32]]
	    }
	}
    } elseif {$url eq "otherAvatar"} {
	set jid2 [::Chat::GetChatTokenValue $token jid2]
	set name [::Avatar::GetPhotoOfSize $jid2 32]
	if {$name eq ""} {
	    set f [file join $theme(resources) Incoming buddy_icon.png]
	    if {[file exists $f]} {
		set name [image create photo -file $f]
	    } else {
		set name [CopyPhoto [::RosterAvatar::GetDefaultAvatarOfSize 32]]
	    }
	}
    } elseif {[::Emoticons::Exists $durl]} {
	set name [CopyPhoto [::Emoticons::Get $durl]]
    } else {
	set f [file join $theme(resources) $url]
	if {[file exists $f]} {
	    set name [image create photo -file $f]
	}
    }
    puts "     name=$name"
    return $name
}

#       The NextContent template is a message fragment for consecutive messages.
#       It will be inserted into the main message block. The HTML template 
#       should contain the bare minimum to display a message. 

proc ::ChatTheme::Incoming {token xmldata secs} {
    variable content

    set bodyE [wrapper::getfirstchildwithtag $xmldata "body"]
    if {[llength $bodyE]} {
	
	set w [::Chat::GetChatTokenValue $token wtext]
	set jid [::Chat::GetChatTokenValue $token jid]
	set name [::Chat::MessageGetYouName $token $jid]
	set time [::Chat::MessageGetTime $token $secs]

	variable $w
	upvar 0 $w state

	set msg [wrapper::getcdata $bodyE]
	#set msg [wrapper::xmlcrypt $msg]
	set msg [Parse $jid $msg]
	set map [list %message% $msg %sender% $name %userIconPath% otherAvatar \
	  %time% $time %service% Jabber %senderScreenName% $name]
	
	if {0 && $state(lastType) eq "in"} {
	    $w parse [string map $map $content(inNext)]
	} else {
	    $w parse [string map $map $content(in)]
	}
	set state(lastType) "in"
	after idle [list $w yview moveto 1.0]
    }
}

proc ::ChatTheme::Outgoing {token xmldata secs} {
    variable content
    
    set bodyE [wrapper::getfirstchildwithtag $xmldata "body"]
    if {[llength $bodyE]} {
	
	set w [::Chat::GetChatTokenValue $token wtext]
	set jid [wrapper::getattribute $xmldata from]
	set name [::Chat::MessageGetMyName $token $jid]
	set time [::Chat::MessageGetTime $token $secs]

	variable $w
	upvar 0 $w state

	set msg [wrapper::getcdata $bodyE]
	#set msg [wrapper::xmlcrypt $msg]
	set msg [Parse $jid $msg]
	set map [list %message% $msg %sender% $name %userIconPath% myAvatar \
	  %time% $time %service% Jabber %senderScreenName% $name]

	#puts "------------------msg=$msg"
	set node [$w search {div#insert}]
	
	#puts "================node=$node"
	
	if {0 && $state(lastType) eq "out"} {
	    $w parse [string map $map $content(outNext)]
	} else {
	    $w parse [string map $map $content(out)]
	}
	set state(lastType) "out"
	after idle [list $w yview moveto 1.0]
    }
}

proc ::ChatTheme::Status {token xmldata secs} {
    variable content
    
    set w [::Chat::GetChatTokenValue $token wtext]
    set jid [::Chat::GetChatTokenValue $token jid]
    set name [::Chat::MessageGetYouName $token $jid]

    variable $w
    upvar 0 $w state

    set time [::Chat::MessageGetTime $token $secs]

    # Maybe there should be a mapping show -> color

    set color red
    set msg [::Chat::PresenceGetString $token $xmldata]
    #set msg [wrapper::xmlcrypt $msg]
    set map [list %message% $str %color% $color %time% $time]

    if {0 && $state(lastType) eq "status"} {
	$w parse [string map $map $content(statusNext)]
    } else {
	$w parse [string map $map $content(status)]
    }
    set state(lastType) "status"
    after idle [list $w yview moveto 1.0]
}

