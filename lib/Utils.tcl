#  Utils.tcl ---
#  
#      This file is part of the whiteboard application. We collect some handy 
#      small utility procedures here.
#      
#  Copyright (c) 1999-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Utils.tcl,v 1.12 2003-12-12 13:46:44 matben Exp $

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
#    Finds max and min of two numerical values. From the WikiWiki page.

proc maxBU {a b} {
    return [expr ($a >= $b) ? $a : $b]
}

proc minBU {a b} {
    return [expr ($a <= $b) ? $a : $b]
}

proc max {a args} {
    foreach i $args {
        if {$i > $a} {
            set a $i
        }
    }
    return $a
}

proc min {a args} {
    foreach i $args {
        if {$i < $a} {
            set a $i
        }
    }
    return $a
}

# lset --
# 
#       Poor mans lset for pre 8.4. Not complete!

if {[info tclversion] < 8.4} {
    proc lset {listName args} {
	
	set usage {Usage: "lset listName index ?index? value"}
	set len [llength $args]
	if {($len < 2) || ($len > 3)} {
	    return -code error $usage
	}
	if {$len == 2} {
	    foreach {ind1 value} $args break
	} else {
	    foreach {ind1 ind2 value} $args break
	}
	
	upvar $listName listValue
	if {[string equal $ind1 "end"]} {
	    set ind1 [expr [llength $listValue] - 1]
	}
	if {($len == 3) && [string equal $ind2 "end"]} {
	    set ind2 [expr [llength [lindex $listValue $ind1]] - 1]
	}	
	if {![string is integer $ind1]} {
	    return -code error $usage
	}
	if {($len == 3) && ![string is integer $ind2]} {
	    return -code error $usage
	}
	
	# Do the job. Be sure to execute it in the callers stack (namespace),
	# else the variable is set in the wrong namespace. List structure!!!
	if {$len == 2} {
	    uplevel set $listName \
	      [list [lreplace $listValue $ind1 $ind1 $value]]
	} else {
	    set subList [lreplace [lindex $listValue $ind1] $ind2 $ind2 $value]
	    uplevel set $listName \
	      [list [lreplace $listValue $ind1 $ind1 $subList]]
	}
    }
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
#       secs        number of seconds since system defined time.
#       
# Results:
#       nice time string that still can be used by 'clock scan'

proc ::Utils::SmartClockFormat {secs args} {
    
    array set opts {
	-weekdays 0
    }
    array set opts $args
    
    # 'days': 0=today, -1=yesterday etc.
    set days [expr ($secs - [clock scan "today 00:00"])/(60*60*24)]
    
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
		# clock scan doesn't work on these
		set date [string tolower  \
		  [clock format [clock scan "today $days days"] -format "%A"]]
	    } else {
		set date [clock format $secs -format "%y-%m-%d"]
	    }
	}
	default {
	    set date [clock format $secs -format "%y-%m-%d"]
	}
    }
    
    set time [clock format $secs -format "%H:%M:%S"]
    return "$date $time"
}

proc ::Utils::UnixGetWebBrowser { } {
    global  this prefs
    
    set browser ""
    if {$this(platform) == "unix"} {

	# Try in order.
	set found 0
	set browsers [list $prefs(webBrowser) netscape mozilla konqueror]
	foreach app $browsers {
	    if {![catch {exec which $app}]} {
		set prefs(webBrowser) $app
		set browser $app
		break
	    }
	}
    }
    return $browser
}

proc ::Utils::OpenHtmlInBrowser {url} {
    global  this prefs
    
    ::Debug 2 "::Utils::OpenHtmlInBrowser url=$url"
    
    switch $this(platform) {
	unix {
	    set browser [::Utils::UnixGetWebBrowser]
	    if {$browser == ""} {
		tk_messageBox -icon error -type ok -message \
		  "Couldn't localize a web browser on this system"
	    } else {
		exec $browser $url &
	    }
	}
	windows {	    
	    ::Windows::OpenUrl $url
	}
	macintosh {    
	    ::Mac::OpenUrl $url
	}
	macosx {
	    exec open $url
	}
    }
}

# FormatTextForMessageBox --
#
#       The tk_messageBox needs explicit newlines to format the message text.

proc FormatTextForMessageBox {txt {width ""}} {
    global  prefs

    if {[string equal $::tcl_platform(platform) "windows"]} {

	# Insert newlines to force line breaks.
	if {[string length $width] == 0} {
	    set width $prefs(msgWrapLength)
	}
	set len [string length $txt]
	set start $width
	set first 0
	set newtxt {}
	while {([set ind [tcl_wordBreakBefore $txt $start]] > 0) &&  \
	  ($start < $len)} {	    
	    append newtxt [string trim [string range $txt $first [expr $ind-1]]]
	    append newtxt "\n"
	    set start [expr $ind + $width]
	    set first $ind
	}
	append newtxt [string trim [string range $txt $first end]]
	return $newtxt
    } else {
	return $txt
    }
}

#--- Utilities for general usage -----------------------------------------------

namespace eval ::Utils:: {
    
    # Running counter for GenerateHexUID.
    variable uid 0
    variable maxuidpersec 10000
}

# Utils::GenerateHexUID --
#
#       Makes a unique hex string stamped by time.
#       Can generate max 'maxuidpersec' (uniques) uid's per second.

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
    
#--- Utilities for the Text widget ---------------------------------------------

namespace eval ::Text:: {

    # Unique counter to produce http link tags.
    variable numLink 1000
    
    # Unique counter to produce specified link tags.
    variable idurl 1000
    
    # Storage for mapping idurl -> url
    variable idToUrlArr
}

# Text::URLLabel --
#
#       An url widget.

proc ::Text::URLLabel {w url args} {
    
    array set opts [list -height 1 -width [string length $url] -bd 0   \
      -wrap word -highlightthickness 0]
    array set opts $args
    eval {text $w} [array get opts]
    $w tag configure normal -foreground blue -underline 1
    $w tag configure active -foreground red -underline 1   
    $w tag bind normal <Enter> [list ::Text::EnterLink $w %x %y normal active]
    $w tag bind active <ButtonPress>  \
      [list ::Text::ButtonPressOnLink $w %x %y active]
    $w insert end $url normal
    return $w
}

# Text::ParseHttpLinks --
# 
#       Parses text translating elements that may be interpreted as an url
#       to a clickable thing.
#
# Arguments:
#       str         the text string, tcl special chars already protected
#       tag         the normal text tag
#       linktag     the tag for links
#       
# Results:
#       A list {textcmd textcmd ...} where textcmd is typically:
#       "insert end {Some text} $tag"

proc ::Text::ParseHttpLinks {str tag linktag} {
    
    # Protect all  *regexp*  special characters.
    #regsub -all {\\|&} $str {\\\0} str

    # regexp hell, welcome!
    set wsp_ "\[ \t\r\n]"
    set path_ "\[^ \t\r\n,]"
    set epath_ "\[^ \t\r\n,\.]"
    set start_ "(^|\"|$wsp_)"
    set end_ "(\$|\"|$wsp_)"

    # This is extremely tricky business!
    # Character data must not be embraced, but must be qoted in order for
    # the protected tcl special chars to be deprotected.
    set re "${start_}((http://|www\\.)${path_}+${epath_})"
    set sub "\\1\" $tag\} \{insert end \{\\2\} \{$tag $linktag\}\} \{insert end \""
    regsub -all -nocase -- $re $str $sub txtlist
    return "\{insert end \"$txtlist\" $tag\}"
}

proc ::Text::ConfigureLinkTagForTextWidget {w tag linkactive} {
    
    $w tag configure $tag -foreground blue -underline 1
    $w tag configure $linkactive -foreground red -underline 1
    
    $w tag bind $tag <Enter> [list ::Text::EnterLink $w %x %y $tag $linkactive]
    $w tag bind $linkactive <ButtonPress>  \
      [list ::Text::ButtonPressOnLink $w %x %y $linkactive]
}

proc ::Text::EnterLink {w x y linktag linkactive} {
    
    set range [$w tag prevrange $linktag "@$x,$y +1 char"]
    if {[llength $range]} {
	eval {$w tag add $linkactive} $range
	eval {$w tag remove $linktag} $range
	$w configure -cursor hand2
	$w tag bind $linkactive <Leave>  \
	  [list ::Text::LeaveLink $w $linktag $linkactive]
    }
}

proc ::Text::LeaveLink {w linktag linkactive} {
    
    set range [$w tag ranges $linkactive]
    if {[llength $range]} {
	eval {$w tag add $linktag} $range
	eval {$w tag remove $linkactive} $range
    }
    $w configure -cursor arrow
}

proc ::Text::ButtonPressOnLink {w x y linkactive} {
    
    ::Debug 2 "::Text::ButtonPressOnLink"

    set range [$w tag prevrange $linkactive "@$x,$y"]
    if {[llength $range]} {
	set url [string trim [eval $w get $range]]
	
	# Add "http://" if not there.
	if {![regexp {^http://.+} $url]} {
	    set url "http://$url"
	}
	if {[::Utils::IsWellformedUrl $url]} {
	    ::Utils::OpenHtmlInBrowser $url
	}
    }
}

# Text::InsertURL --
#
#       Insert a link where the text string and url may differ.

proc ::Text::InsertURL {w str url tag} {    
    variable idurl
    variable idToUrlArr

    set idToUrlArr($idurl) $url
    set urltag url${idurl}
    set linkactive ${urltag}active
    $w insert end $str [list $tag $urltag]

    $w tag configure $urltag -foreground blue -underline 1
    $w tag configure $linkactive -foreground red -underline 1
    
    $w tag bind $urltag <Enter>  \
      [list ::Text::EnterLink $w %x %y $urltag $linkactive]
    $w tag bind $linkactive <ButtonPress>  \
      [list ::Text::ButtonPressOnURL $w $idurl]

    incr idurl
}

proc ::Text::ButtonPressOnURL {w idurl} {    
    variable idToUrlArr

    set url $idToUrlArr($idurl)
    ::Debug 2 "::Text::ButtonPressOnURL url=$url"
    
    # Add "http://" if not there.
    if {![regexp {^http://.+} $url]} {
	set url "http://$url"
    }
    if {[::Utils::IsWellformedUrl $url]} {
	::Utils::OpenHtmlInBrowser $url
    }
}

# Text::ParseSmileys --
# 
#
# Arguments:
#       str         the text string, tcl special chars already protected
#       
# Results:
#       A list {str textimage ?str textimage ...?}

proc ::Text::ParseSmileys {str} {
    global  this
    
    upvar ::UI::smiley smiley
    upvar ::UI::smileyLongNames smileyLongNames
    upvar ::UI::smileyLongIm smileyLongIm
    
    # Since there are about 60 smileys we need to be economical here.    
    # Check first if there are any short smileys.
	
    # Protect all  *regexp*  special characters. Regexp hell!!!
    # Carefully embrace $smile since may contain ; etc.
    
    foreach smile [array names smiley] {
	set sub "\} \{image create end -image $smiley($smile) -name \{$smile\}\} \{"
	regsub -all {[);(|]} $smile {\\\0} smileExp
	regsub -all $smileExp $str $sub str
    }
	
    # Now check for any "long" names, such as :angry: :cool: etc.
    set candidates {}
    set ndx 0
    
    while {[regexp -start $ndx -indices -- {:[a-zA-Z]+:} $str ind]} {
        set ndx [lindex $ind 1]
	set candidate [string range $str [lindex $ind 0] [lindex $ind 1]]
	if {[lsearch $smileyLongNames $candidate] >= 0} {
	    lappend candidates $candidate
	    
	    # Load image if not done that.
	    if {![info exists smileyLongIm($candidate)]} {
		set fileName "smiley-[string trim $candidate :].gif"
		set smileyLongIm($candidate) [image create photo -format gif  \
		  -file [file join $this(path) images smileys $fileName]]	    
	    }
	}
    }
    if {[llength $candidates]} {
	regsub -all {\\|&} $str {\\\0} str
	foreach smile $candidates {
	    set sub "\} \{image create end -image $smileyLongIm($smile) -name $smile\} \{"
	    regsub -all $smile $str $sub str
	}
    }
    
    return "\{$str\}"
}

# Text::ParseAll --
# 
#       Combines 'ParseSmileys' and 'ParseHttpLinks'.
#
# Arguments:
#       str         the text string
#       
# Results:
#       A list {textcmd textcmd ...} where textcmd is typically:
#       "insert end {Some text} $tag"

proc ::Text::ParseAll {str tag linktag} {
        
    # Protect Tcl special characters, quotes included.
    regsub -all {([][$\\{}"])} $str {\\\1} str

    set strSmile [::Text::ParseSmileys $str]
    
    foreach {txt icmd} $strSmile {
	set httpCmd [::Text::ParseHttpLinks $txt $tag $linktag]
	if {$icmd == ""} {
	    eval lappend res $httpCmd
	} else {
	    eval lappend res $httpCmd [list $icmd]
	}
    }
    return $res
}

proc ::Text::ParseAndInsert {w str tag linktag} {
    
    foreach cmd [::Text::ParseAll $str $tag $linktag] {
	eval {$w} $cmd
    }
    $w insert end "\n"
}

proc ::Text::TransformToPureText {w args} {    
    variable puretext
    
    if {[winfo class $w] != "Text"} {
	error {TransformToPureText needs a text widget here}
    }
    catch {unset puretext($w)}
    set puretext($w) ""
    foreach {key value index} [$w dump 1.0 end $w] {
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

#--- Timing --------------------------------------------------------------------

namespace eval ::Timing:: {
    variable timing
}

# Timing::Set, Reset, GetRate, FormMessage --
# 
#       A number of utils that handle timing objects. Mainly to get bytes
#       per second during file transfer.
#       
# Arguments:
#       key         a unique key to identify a particular timing object,
#                   typically use the socket token or a running namespaced 
#                   number.
#       bytes       number of bytes transported so far
#       totalbytes  total file size in bytes

proc ::Timing::Set {key bytes} {
    variable timing
    
    lappend timing($key) [list [clock clicks -milliseconds] $bytes]
    return {}
}

proc ::Timing::Reset {key} {
    variable timing
    
    unset timing($key)
}

proc ::Timing::GetRate {key} {
    variable timing
	
    set timeList $timing($key)
    set n [llength $timeList]
    set nAve 6
    set istart [expr $n - $nAve]
    if {$istart < 0} {
	set istart 0
    }
    set iend [expr $n - 1]
    set sumBytes [expr [lindex [lindex $timeList $iend] 1] -  \
      [lindex [lindex $timeList $istart] 1]]
    set sumMillis [expr [lindex [lindex $timeList $iend] 0] -  \
      [lindex [lindex $timeList $istart] 0]]
    
    # Treat the case with wrap around. (Guess)
    if {$sumMillis <= 0} {
	set sumMillis 1000000
    }
    
    # Returns average bytes per second.
    return [expr 1000.0 * $sumBytes / ($sumMillis + 1.0)]
}

proc ::Timing::GetPercent {key totalbytes} {
    variable timing

    if {[llength $timing($key)] > 1} {
	set bytes [lindex [lindex $timing($key) end] 1]
    } else {
	set bytes 0
    }
    set percent [format "%3.0f" [expr 100.0 * $bytes/($totalbytes + 1.0)]]
    set percent [expr $percent < 0 ? 0 : $percent]
    set percent [expr $percent > 100 ? 100 : $percent]
    return $percent
}

proc ::Timing::FormMessage {key totalbytes} {
    variable timing
    
    set bytesPerSec [::Timing::GetRate $key]

    # Find format: bytes or k.
    if {$bytesPerSec < 1000} {
	set txtRate "[expr int($bytesPerSec)] bytes/sec"
    } elseif {$bytesPerSec < 1000000} {
	set txtRate [list [format "%.1f" [expr $bytesPerSec/1000.0] ]Kb/sec]
    } else {
	set txtRate [list [format "%.1f" [expr $bytesPerSec/1000000.0] ]Mb/sec]
    }

    # Remaining time.
    if {[llength $timing($key)] > 1} {
	set bytes [lindex [lindex $timing($key) end] 1]
    } else {
	set bytes 0
    }
    set percent [format "%3.0f" [expr 100.0 * $bytes/($totalbytes + 1.0)]]
    set secsLeft  \
      [expr int(ceil(($totalbytes - $bytes)/($bytesPerSec + 1.0)))]
    if {$secsLeft < 60} {
	set txtTimeLeft ", $secsLeft secs remaining"
    } elseif {$secsLeft < 120} {
	set txtTimeLeft ", one minute and [expr $secsLeft - 60] secs remaining"
    } else {
	set txtTimeLeft ", [expr $secsLeft/60] minutes remaining"
    }
    return "${txtRate}${txtTimeLeft}"
}

#-------------------------------------------------------------------------------
