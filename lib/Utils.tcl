#  Utils.tcl ---
#  
#      This file is part of The Coccinella application. We collect some handy 
#      small utility procedures here.
#      
#  Copyright (c) 1999-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Utils.tcl,v 1.38 2004-12-06 15:26:56 matben Exp $

namespace eval ::Utils:: {

}
    
# InvertArray ---
#
#    Inverts an array so that ...
#    No spaces allowed; no error checking made that the inverse is unique.

proc InvertArray {arrName invArrName} {
    
    # Pretty tricky to make it work. Perhaps the new array should be unset?
    upvar $arrName locArr
    upvar $invArrName locInvArr
    foreach name [array names locArr] {
        set locInvArr($locArr($name)) $name
    }
}

# max, min ---
#
#    Finds max and min of numerical values. From the WikiWiki page.

proc max {args} {
    lindex [lsort -real $args] end
}

proc min {args} {
    lindex [lsort -real $args] 0
}

# lprune --
# 
#       Removes element from list, silently.

proc lprune {listName elem} {
    upvar $listName listValue
    
    set idx [lsearch $listValue $elem]
    if {$idx >= 0} {
	uplevel set $listName [list [lreplace $listValue $idx $idx]]
    }
    return ""
}

# lrevert --
# 
#       Revert the order of the list elements.

proc lrevert {args} {
    set tmp {}
    set args [lindex $args 0]
    for {set i [expr [llength $args] - 1]} {$i >= 0} {incr i -1} {
	lappend tmp [lindex $args $i]
    }
    return $tmp
}
    
# getdirname ---
#
#       Returns the path from 'filePath' thus stripping of any file name.
#       This is a workaround for the strange [file dirname ...] which strips
#       off "the last thing."
#       We need actual files here, not fake ones.
#    
# Arguments:
#       filePath       the path.

proc getdirname {filePath} {
    
    if {[file isfile $filePath]} {
	return [file dirname $filePath]
    } else {
	return $filePath
    }
}

# SecondCoccinella --
# 
#       This gets called if a second instance of this app is launched,
#       before it kills itself

proc SecondCoccinella {args} {
    
    wm deiconify .
    raise .
    
    ::Debug 2 "--> relaunchHook $args"
    eval {::hooks::run relaunchHook} $args
}

#--- Utilities for general usage -----------------------------------------------

namespace eval ::Utils:: {
    
    # Running counter for GenerateHexUID.
    variable uid 0
    variable maxuidpersec 10000
}

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
	return ""
    }
}

proc ::Utils::GetDomainNameFromUrl {url} {
    
    if {[regexp {[^:]+://([^:/]+)(:[0-9]+)?/.*} $url match domain port]} {
	return $domain
    } else {
	return ""
    }
}

# ::Utils::SmartClockFormat --
#
#       Pretty formatted time & date.
#
# Arguments:
#       secs        Number of seconds since system defined time.
#                   This must be local time.
#       
# Results:
#       nice time string that still can be used by 'clock scan'

proc ::Utils::SmartClockFormat {secs args} {
    
    array set opts {
	-weekdays 0
	-detail   0
    }
    array set opts $args
    
    # 'days': 0=today, -1=yesterday etc.
    set secs00 [clock scan "today 00:00"]
    set days [expr ($secs - $secs00)/(60*60*24)]
    
    switch -regexp -- $days {
	^1$ {
	    set date "tomorrow"
	}
	^0$ {
	    set date "today"
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
    if {$opts(-detail) && ($days == 0)} {
	set now [clock seconds]
	set minutes [expr ($now - $secs)/60]
	if {$minutes == 0} {
	    set time [clock format $secs -format "%H:%M:%S"]
	} elseif {$minutes == 1} {
	    set time "one minute ago"
	} elseif {$minutes == 2} {
	    set time "two minutes ago"
	} elseif {$minutes == 3} {
	    set time "three minutes ago"
	} elseif {$minutes < 60} {
	    set time "$minutes minutes ago"
	} else {
	    set time [clock format $secs -format "%H:%M:%S"]
	}
    } else {	
	set time [clock format $secs -format "%H:%M:%S"]
    }
    return "$date $time"
}

proc ::Utils::IsToday {secs} {
    return [expr ($secs - [clock scan "today 00:00"])/(60*60*24) >= 0 ? 1 : 0]
}

proc ::Utils::UnixGetWebBrowser { } {
    global  this prefs env
    
    set browser ""
    if {$this(platform) == "unix"} {
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

    if {$prefs(webBrowser) == ""} {
	set browser [UnixGetWebBrowser]
    } else {
	set browser $prefs(webBrowser)
    }
    if {$browser != ""} {
	if {[catch {eval exec $browser -remote \"openURL($url, new-tab)\"}]} {
	    if {[catch {exec $browser -remote $url}]} {
		if {[catch {exec $browser $url &}]} {
		    set browser ""
		}
	    }
	}
    } 
    if {$browser == ""} {
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

# Utils::GenerateHexUID --
#
#       Makes a unique hex string stamped by time.
#       Can generate max 'maxuidpersec' (uniques) uid's per second.
#       
#       See also ::tfileutils::newuid !!!

proc ::Utils::GenerateHexUID { } {
    variable uid
    variable maxuidpersec
    
    set rem [expr [incr uid] % $maxuidpersec]
    set secs [clock seconds]
    
    # Remove any leading 0 to avoid octal interpretation.
    set hex1 [format %x [string trimleft \
      [clock format $secs -format "%y%j%H"] 0]]
    set hex2 [format %x [string trimleft \
      [clock format $secs -format "%M%S${rem}"] 0]]
    return ${hex1}${hex2}
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
    set ip [::Network::GetThisPublicIPAddress]
    return "http://${ip}:$prefs(httpdPort)/$relPath"
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
	uplevel #0 $cmd
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

# Text::Parse, ... --
# 
#       It takes a text widget, the text, and a default tag, and parses
#       smileys and urls.

proc ::Text::Parse {w str tag} {
    
    # Split string into words and whitespaces.
    set wsp {[ \t\r\n]+}
    set len [string length $str]
    if {$len == 0} {
	return
    }
    set start 0
    while {[regexp -start $start -indices -- $wsp $str match]} {
	foreach {matchStart matchEnd} $match break
	
	# The "space" part.
	set space [string range $str $matchStart $matchEnd]
	incr matchStart -1
	incr matchEnd
	
	# The word preceeding the space.
	set word [string range $str $start $matchStart]
	set start $matchEnd
	
	# Process the actual word.
	ParseWord $w $word $tag
	
	# Insert the whitespace after word.
	$w insert end $space $tag
    }
    
    # And the final word.
    set word [string range $str $start end]
    ParseWord $w $word $tag
}

proc ::Text::ParseWord {w word tag} {
    
    if {[::Emoticons::Exists $word]} {
	::Emoticons::Make $w $word
    } elseif {![ParseUrl $w $word]} {
	$w insert end $word $tag
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
	if {$urlfg == ""} {
	    set urlfg $urlColor(fg)
	}
	if {$urlactivefg == ""} {
	    set activefg $urlColor(activefg)
	}
	$w tag configure $urltag -foreground $urlfg -underline 1
	$w tag bind $urltag <Button-1>  \
	  [list ::Text::UrlButton [string map {% %%} $word]]
	$w tag bind $urltag <Any-Enter>  \
	  [list ::Text::UrlEnter $w $urltag $activefg]
	$w tag bind $urltag <Any-Leave>  \
	  [list ::Text::UrlLeave $w $urltag $urlfg]
	$w insert end $word $urltag
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

# Text::URLLabel --
#
#       An url widget.

proc ::Text::URLLabel {w url args} {
    
    array set opts [list -height 1 -width [string length $url] -bd 0   \
      -wrap word -highlightthickness 0]
    array set opts $args
    eval {text $w} [array get opts]
    ParseUrl $w $url 
    
    return $w
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
    if {$urlfg == ""} {
	set urlfg $urlColor(fg)
    }
    if {$urlactivefg == ""} {
	set activefg $urlColor(activefg)
    }
    $w tag configure $urltag -foreground $urlfg -underline 1
    $w tag bind $urltag <Button-1>  \
      [list ::Text::UrlButton [string map {% %%} $url]]
    $w tag bind $urltag <Any-Enter>  \
      [list ::Text::UrlEnter $w $urltag $activefg]
    $w tag bind $urltag <Any-Leave>  \
      [list ::Text::UrlLeave $w $urltag $urlfg]
    $w insert end $str [list $tag $urltag]
    incr idurl
}

proc ::Text::TransformToPureText {w args} {    
    variable puretext
    
    if {[winfo class $w] != "Text"} {
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
