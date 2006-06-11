#  Utils.tcl ---
#  
#      This file is part of The Coccinella application. We collect some handy 
#      small utility procedures here.
#      
#  Copyright (c) 1999-2005  Mats Bengtsson
#  
# $Id: Utils.tcl,v 1.57 2006-06-11 10:32:18 matben Exp $

package provide Utils 1.0

namespace eval ::Utils:: {

}

# SecondCoccinella --
# 
#       This gets called if a second instance of this app is launched,
#       before it kills itself.

proc SecondCoccinella {args} {
    
    set w [::UI::GetMainWindow]
    wm deiconify $w
    raise $w
    eval {::hooks::run relaunchHook} $args
}

#--- Utilities for general usage -----------------------------------------------

# ::Utils::FontEqual --
# 
#       Compares two fonts to see if identical.

proc ::Utils::FontEqual {font1 font2} {
    
    set ans 1
    array set font1Arr [font actual $font1]
    foreach {key value} [font actual $font2] {
	if {![string equal $font1Arr($key) $value]} {
	    set ans 0
	    break
	}
    }
    return $ans
}

proc ::Utils::FontBold {fontName} {
    
    array set fontArr [font actual $fontName]
    return [list $fontArr(-family) $fontArr(-size) bold]
}

# ::Utils::GetMaxMsgcatWidth --
# 
#       Returns the max string length for the current catalog of the
#       given source strings.

proc ::Utils::GetMaxMsgcatWidth {args} {
    
    set width 0
    foreach str $args {
	set len [string length [mc $str]]
	if {$len > $width} {
	    set width $len
	}
    }
    return $width
}

proc ::Utils::GetMaxMsgcatString {args} {
    
    set width 0
    foreach str $args {
	set mcstr [mc $str]
	set len [string length $mcstr]
	if {$len > $width} {
	    set width $len
	    set maxstr $mcstr
	}
    }
    return $maxstr
}

# ::Utils::IsIPNumber --
#
#       Tests if the arguments is a ip number, that is, 200.54.2.0
#       Not foolproof! Should be able to tell the difference between
#       a ip name and a ip number.

proc ::Utils::IsIPNumber {thing} {
    
    set sub_ {([0-2][0-9][0-9]|[0-9][0-9]|[0-9])}
    set d_ {\.}
    return [regexp "^${sub_}${d_}${sub_}${d_}${sub_}${d_}${sub_}$" $thing]
}

# ::Utils::IsWellformedUrl --
#
#       Returns boolean depending on if argument is a well formed URL.
#       Not foolproof!

proc ::Utils::IsWellformedUrl {url} {
    
    return [regexp {[^:]+://[^:/]+(:[0-9]+)?[^ ]*} $url]
}

# ::Utils::GetFilePathFromUrl --
#
#       Returns the file path part from a well formed url, or empty if
#       didn't recognize it as a valid url.

proc ::Utils::GetFilePathFromUrl {url} {
    
    if {[regexp {[^:]+://[^:/]+(:[0-9]+)?/(.*)} $url match port path]} {
	return $path
    } else {
	return
    }
}

proc ::Utils::GetDomainNameFromUrl {url} {
    
    if {[regexp {[^:]+://([^:/]+)(:[0-9]+)?/.*} $url match domain port]} {
	return $domain
    } else {
	return
    }
}

# ::Utils::SmartClockFormat --
#
#       Pretty formatted time & date.
#
# Arguments:
#       secs        Number of seconds since system defined time.
#                   This must be local time.
#       args:   -detail
#               -weekdays
#               -showsecs
#       
# Results:
#       nice time string that still can be used by 'clock scan'

proc ::Utils::SmartClockFormat {secs args} {
    
    array set opts {
	-weekdays 0
	-detail   0
	-showsecs 1
	-today    0
    }
    array set opts $args
    if {$secs eq ""} {
	return
    }
    
    # 'days': 0=today, -1=yesterday etc.
    set secs00 [clock scan "today 00:00"]
    set days [expr ($secs - $secs00)/(60*60*24)]
    
    switch -regexp -- $days {
	^1$ {
	    set date "tomorrow"
	}
	^0$ {
	    if {$opts(-today)} {
		set date "today"
	    } else {
		set date ""
	    }
	}
	^-1$ {
	    set date "yesterday"
	}
	^-[2-5]$ {
	    if {$opts(-weekdays)} {
		set date [string tolower  \
		  [clock format [clock scan "$days days ago"] -format "%A"]]
	    } else {
		set date [clock format $secs -format "%y-%m-%d"]
	    }
	}
	default {
	    set date [clock format $secs -format "%y-%m-%d"]
	}
    }
    if {$opts(-showsecs)} {
	set fmt "%H:%M:%S"
    } else {
	set fmt "%H:%M"
    }

    if {$opts(-detail) && ($days == 0)} {
	set now [clock seconds]
	set minutes [expr ($now - $secs)/60]
	if {$minutes == 0} {
	    set time [clock format $secs -format $fmt]
	} elseif {$minutes == 1} {
	    set time "one minute ago"
	} elseif {$minutes == 2} {
	    set time "two minutes ago"
	} elseif {$minutes == 3} {
	    set time "three minutes ago"
	} elseif {$minutes < 60} {
	    set time "$minutes minutes ago"
	} else {
	    set time [clock format $secs -format $fmt]
	}
    } else {	
	set time [clock format $secs -format $fmt]
    }
    return [string trim "$date $time"]
}

proc ::Utils::IsToday {secs} {
    return [expr ($secs - [clock scan "today 00:00"])/(60*60*24) >= 0 ? 1 : 0]
}

proc ::Utils::FormatBytes {bytes} {
    
    if {$bytes < 1000} {
	set str "$bytes bytes"
    } elseif {$bytes < 1000000} {
	set str "[format %.1f [expr $bytes/1000.0] ]Kb"
    } else {
	set str "[format %.1f [expr $bytes/1000000.0] ]Mb"
    }

    return $str
}

proc ::Utils::UnixGetWebBrowser { } {
    global  this prefs env
    
    set browser ""
    if {$this(platform) eq "unix"} {
	if {[info exists env(BROWSER)]} {
	    if {[llength [auto_execok $env(BROWSER)]] > 0} {
		set browser $env(BROWSER)
	    }
	}
	set cmd [auto_execok $prefs(webBrowser)]
	if {$cmd == {}} {
	    foreach name {firefox galeon konqueror mozilla-firefox \
	      mozilla-firebird mozilla netscape iexplorer opera} {
		if {[llength [set e [auto_execok $name]]] > 0} {
		    set browser [lindex $e 0]
		    break
		}
	    }
	}
	set prefs(webBrowser) $browser
    }
    return $browser
}

proc ::Utils::UnixOpenUrl {url} {
    global  prefs

    if {$prefs(webBrowser) eq ""} {
	set browser [UnixGetWebBrowser]
    } else {
	set browser $prefs(webBrowser)
    }
    if {$browser ne ""} {
	if {[catch {eval exec $browser -remote \"openURL($url, new-tab)\"}]} {
	    if {[catch {exec $browser -remote $url}]} {
		if {[catch {exec $browser $url &}]} {
		    set browser ""
		}
	    }
	}
    } 
    if {$browser eq ""} {
	::UI::MessageBox -icon error -type ok -message \
	  "Couldn't localize a web browser on this system.\
	  Define a shell variable env(BROWSER) to point to a web browser."
    }
}

proc ::Utils::OpenURLInBrowser {url} {
    global  tcl_platform prefs
    
    ::Debug 2 "::Utils::OpenURLInBrowser url=$url"
    
    switch -glob -- $tcl_platform(platform),$tcl_platform(os) {
	unix,Darwin {
	    exec open $url
	}
	unix,* {
	    UnixOpenUrl $url
	}
	windows,* {	    
	    ::Windows::OpenUrl $url
	}
	macintosh,* {    
	    ::Mac::OpenUrl $url
	}
    }
}


proc ::Utils::ValidMinutes {str} {
    if {[regexp {[0-9]*} $str match]} {
	return 1
    } else {
	bell
	return 0
    }
}

# Utils::GetDirIfExist --
#
#       Returns $dir only if actually exists, else returns $this(path).

proc ::Utils::GetDirIfExist {dir} {
    global  this
    
    if {[file isdirectory $dir]} {
	return $dir
    } else {
	return $this(path)
    }
}

proc ::Utils::GetFontListFromName {fontSpec} {
    
    if {[llength $fontSpec] == 1} {
	array set fontArr [font actual $fontSpec]
	return [list $fontArr(-family) $fontArr(-size) $fontArr(-weight)] 
    } elseif {[llength $fontSpec] == 3} {
	return $fontSpec
    } else {
	return -code error "unknown font specification $fontSpec"
    }
}
    
# Utils::GetHttpFromFile --
# 
#       Translates an absolute file path to an uri encoded http address
#       for our built in http server.

proc ::Utils::GetHttpFromFile {filePath} {
    global  prefs this
    
    set relPath [::tfileutils::relative $this(httpdRootPath) $filePath]
    set relPath [uriencode::quotepath $relPath]
    set ip [::Network::GetThisPublicIP]
    return "http://${ip}:$prefs(httpdPort)/$relPath"
}

proc ::Utils::IsAnimatedGif {fileName} {
    
    # If we can read -index 1 then this is likely an animated gif. CRUDE!
    set code [catch {
	image create photo -file $fileName -format {gif89 -index 1}
    } name]
    catch {image delete $name}
    return [expr {$code == 0 ? 1 : 0}]
}

proc ::Utils::CreateGif {fileName {imageName ""}} {
    
    if {[IsAnimatedGif $fileName]} {
	return [::anigif::anigif $fileName $imageName]
    } else {
	if {$imageName eq ""} {
	    return [image create photo -file $fileName -format gif]
	} else {
	    return [image create photo $imageName -file $fileName -format gif]
	}
    }
}

proc ::Utils::ImageFromData {data {mime ""}} {
    global  this
    
    set type ""
    lassign [split $mime /] x type
    if {$type eq "gif"} {
	return [image create photo -data $data -format gif]
    } else {
	if {![catch {image create photo -data $data} name]} {
	    return $name
	} 
	set tmpfile [::tfileutils::tempfile $this(tmpPath) vcard]
	if {$type ne ""} {
	    append tmpfile .$type
	}
	#puts "tmpfile=$tmpfile"
	set fd [open $tmpfile {CREAT WRONLY}]
	fconfigure $fd -translation binary
	puts -nonewline $fd [::base64::decode $data]
	close $fd
	if {![catch {image create photo -file $tmpfile} name]} {
	    return $name
	} else {
	    return
	}
    }
}

# Utils::LanguageMenubutton --
# 
#       Make a language menubutton selector.

proc ::Utils::LanguageMenubutton {w varName args} {
    global  this prefs
    
    # Add entries here for new message catalogs.
    array set code2Name {
	da {Danish} 
	nl {Dutch} 
	en {English} 
	fr {French} 
	de {German} 
	it {Italian}
	pl {Polish} 
	ru {Russian} 
	es {Spanish} 
	sv {Swedish} 
    }
    set langs {}
    foreach f [glob -nocomplain -tails -directory $this(msgcatPath) *.msg] {
	set code [file rootname $f]
	if {[info exists code2Name($code)]} {
	    set name $code2Name($code)
	    set key native${name}
	    set str [mc $key]
	    if {$str eq $key} {
		# Fallback.
		set str $name
	    }
	} else {
	    set str $code
	}
	lappend langs $str
	set langCode2Str($code) $str
    }
    if {$prefs(messageLocale) eq ""} {
	set $varName [lindex [split [::msgcat::mclocale] _] 0]
    } else {
	set $varName $prefs(messageLocale)
    }
    set menuDef {}
    foreach {code str} [array get langCode2Str] {
	lappend menuDef [list $str -value $code]
    }
    ui::optionmenu $w -menulist $menuDef -direction flush -variable $varName

    return $w
}

#--- Animation -----------------------------------------------------------------

namespace eval ::Utils:: {
    variable anim
    set anim(uid) 0
}

proc ::Utils::AnimateStart {delay vlist command} {
    variable anim
    
    set uid [incr anim(uid)]
    set anim($uid,delay) $delay
    set anim($uid,vlist) $vlist
    set anim($uid,command) $command
    set anim($uid,pos) 0
    set anim($uid,pending) [after $delay [namespace current]::AnimateHandle $uid]
 
    return $uid
}

proc ::Utils::AnimateHandle {uid} {
    variable anim

    if {[info exists anim($uid,pending)]} {
	set pos $anim($uid,pos)
	set cmd $anim($uid,command)
	set val [lindex $anim($uid,vlist) $pos]
	regsub -all {\\|&} $val {\\\0} val
	regsub -all {%v} $cmd $val cmd
	if {[catch {uplevel #0 $cmd}]} {
	    AnimateStop $uid
	    return
	}
	if {[incr pos] >= [llength $anim($uid,vlist)]} {
	    set pos 0
	}
	set anim($uid,pos) $pos
	set anim($uid,pending) \
	  [after $anim($uid,delay) [namespace current]::AnimateHandle $uid]
    }
}

proc ::Utils::AnimateStop {uid} {
    variable anim

    if {[info exists anim($uid,pending)]} {
	after cancel $anim($uid,pending)
    }
    array unset anim $uid,*
}

#--- Utilities for the Text widget ---------------------------------------------

namespace eval ::Text:: {

    # Unique counter to produce specified link tags.
    variable idurl 1000
        
    variable urlRegexp {^(http://|https://|www\.|ftp://|ftp\.)([^ \t\r\n]+)}
    variable urlColor
    array set urlColor {fg blue activefg red}
}

# Text::ParseMsg --
# 
#       Parses message text (body).

proc ::Text::ParseMsg {type jid w str tagList} {
    
    # Split string into words and whitespaces.
    set wsp {[ \t\r\n]+}
    set len [string length $str]
    if {$len == 0} {
	return
    }
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
	if {[hooks::run textParseWordHook $type $jid $w $word $tagList] ne "stop"} {	    
	    ParseWord $w $word $tagList
	}
	
	# Insert the whitespace after word.
	#$w insert end $space $tagList
	$w insert insert $space $tagList
    }
    
    # And the final word.
    set word [string range $str $start end]
    if {[hooks::run textParseWordHook $type $jid $w $word $tagList] ne "stop"} {	    
	ParseWord $w $word $tagList
    }
}

# Text::Parse, ... --
# 
#       It takes a text widget, the text, and a default tag, and parses
#       smileys and urls.

proc ::Text::Parse {w str tagList} {

    ParseMsg {} {} $w $str $tagList
}

proc ::Text::ParseWord {w word tagList} {
    
    if {[::Emoticons::Exists $word]} {
	::Emoticons::Make $w $word
    } elseif {![ParseUrl $w $word]} {
	$w insert insert $word $tagList
    }
}

proc ::Text::ParseUrl {w word} {
    variable urlRegexp
    variable idurl
    variable urlColor
    
    if {[regexp $urlRegexp $word]} {
	set urltag url${idurl}
	set urlfg       [option get $w urlForeground       Text]
	set urlactivefg [option get $w urlActiveForeground Text]
	if {$urlfg eq ""} {
	    set urlfg $urlColor(fg)
	}
	if {$urlactivefg eq ""} {
	    set activefg $urlColor(activefg)
	}
	$w tag configure $urltag -foreground $urlfg -underline 1
	$w tag bind $urltag <Button-1>  \
	  [list ::Text::UrlButton [string map {% %%} $word]]
	$w tag bind $urltag <Any-Enter>  \
	  [list ::Text::UrlEnter $w $urltag $activefg]
	$w tag bind $urltag <Any-Leave>  \
	  [list ::Text::UrlLeave $w $urltag $urlfg]
	$w insert insert $word $urltag
	incr idurl
	return 1
    } else {
	return 0
    }
}

proc ::Text::UrlButton {url} {
    if {![regexp {^http://.+} $url]} {
	set url "http://$url"
    }
    if {[::Utils::IsWellformedUrl $url]} {
	::Utils::OpenURLInBrowser $url
    }
}

proc ::Text::UrlEnter {w tag fgcol} {
    $w configure -cursor hand2
    $w tag configure $tag -foreground $fgcol -underline 1
}

proc ::Text::UrlLeave {w tag fgcol} {
    $w configure -cursor arrow
    $w tag configure $tag -foreground $fgcol -underline 1
}

# Text::InsertURL --
#
#       Insert a link where the text string and url may differ.

proc ::Text::InsertURL {w str url tag} {    
    variable idurl
    variable urlColor
    
    set urltag url${idurl}
    set urlfg       [option get $w urlForeground       Text]
    set urlactivefg [option get $w urlActiveForeground Text]
    if {$urlfg eq ""} {
	set urlfg $urlColor(fg)
    }
    if {$urlactivefg eq ""} {
	set activefg $urlColor(activefg)
    }
    $w tag configure $urltag -foreground $urlfg -underline 1
    $w tag bind $urltag <Button-1>  \
      [list ::Text::UrlButton [string map {% %%} $url]]
    $w tag bind $urltag <Any-Enter>  \
      [list ::Text::UrlEnter $w $urltag $activefg]
    $w tag bind $urltag <Any-Leave>  \
      [list ::Text::UrlLeave $w $urltag $urlfg]
    #$w insert end $str [list $tag $urltag]
    $w insert insert $str [list $tag $urltag]
    incr idurl
}

proc ::Text::TransformToPureText {w args} {    
    variable puretext
    
    if {[winfo class $w] ne "Text"} {
	error {TransformToPureText needs a text widget here}
    }
    unset -nocomplain puretext($w)
    set puretext($w) ""
    foreach {key value index} [$w dump 1.0 end] {
	::Text::TransformToPureTextCallback $w $key $value $index
    }
    return $puretext($w)
}

proc ::Text::TransformToPureTextCallback {w key value index} {    
    variable puretext

    switch -- $key {
	tagon {
	    
	}
	tagoff {
	    
	}
	text {
	    append puretext($w) $value
	}
	image {
	    
	    # Treat smileys specially.
	    set name [$w image cget $index -name]	    
	    if {[string length $name] > 0} {
		append puretext($w) $name
	    } else {
		set imname [$w image cget $index -image]	    
		append puretext($w) {[Image:}
		set tail [file tail [$imname cget -file]]
		if {[string length $tail]} {
		    append puretext($w) " [file tail $tail]"
		}
		append puretext($w) {]}
	    }
	}
    }
}

#-------------------------------------------------------------------------------
