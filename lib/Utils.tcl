#  Utils.tcl ---
#  
#      This file is part of The Coccinella application. We collect some handy 
#      small utility procedures here.
#      
#  Copyright (c) 1999-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Utils.tcl,v 1.19 2004-05-09 12:14:38 matben Exp $

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

# ::Utils::GetMaxMsgcatWidth --
# 
#       Returns the max string length for the current catalog of the
#       given source strings.

proc ::Utils::GetMaxMsgcatWidth {args} {
    
    set width 0
    foreach str $args {
	set len [string length [::msgcat::mc $str]]
	if {$len > $width} {
	    set width $len
	}
    }
    return $width
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
    
    set relPath [filerelative $this(httpdRootPath) $filePath]
    set relPath [uriencode::quotepath $relPath]
    set ip [::Network::GetThisOutsideIPAddress]
    return "http://${ip}:$prefs(httpdPort)/$relPath"
}

# Utils::ProgressWindow, ProgressFree --
# 
#       Useful when using progress window. It combines the ProgressWindow
#       with Timing.

namespace eval ::Utils:: {
    
    variable puid 0
}

proc ::Utils::ProgressWindow {token total current args} {
    global  prefs wDlgs tcl_platform
    variable progress
    variable puid
   
    # Cache timing info.
    ::Timing::Set $token $current

    # Update only when minimum time has passed, and only at certain interval.
    set ms [clock clicks -milliseconds]
    set needupdate 0

    # Create progress dialog if not exists.
    if {![info exists progress($token,w)]} {
	set progress($token,token) $token
	set w $wDlgs(prog)2[incr puid]
	set progress($token,w) $w
	eval {::ProgressWindow::ProgressWindow $w} $args
	set progress($token,startmillis) $ms
	set progress($token,lastmillis)  $ms
	set needupdate 1
    } elseif {[expr $ms - $progress($token,lastmillis)] > $prefs(progUpdateMillis)} {

	# Update the progress window.
	append msg3 "[::msgcat::mc Rate]: [::Timing::FormMessage $token $total]"	
	set percent [expr 100.0 * $current/($total + 0.001)]
	$progress($token,w) configure -percent $percent -text3 $msg3
	set progress($token,lastmillis) $ms
	set needupdate 1
    }

    # Be silent... except for a necessary update command to not block.
    if {$needupdate} {
	if {[string equal $tcl_platform(platform) "windows"]} {
	    update
	} else {
	    update idletasks
	}
    }
}

proc ::Utils::ProgressFree {token} {
    variable progress
    
    catch {destroy $progress($token,w)}
    ::Timing::Reset $token
    array unset progress $token,*
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
    
    lappend timing($key) \
      [list [expr double([clock clicks -milliseconds])] $bytes]
    return ""
}

proc ::Timing::Reset {key} {
    variable timing
    
    catch {unset timing($key)}
}

proc ::Timing::GetRate {key} {
    variable timing
	
    set len [llength $timing($key)]
    if {$len <= 1} {
	return 0.0
    }
    set nAve 12
    set istart [expr $len - $nAve]
    if {$istart < 0} {
	set istart 0
    }
    
    # Keep only the part we are interested in.
    set timing($key) [lrange $timing($key) $istart end]
    set timeList $timing($key)
    set sumMillis [expr [lindex $timeList end 0] - [lindex $timeList 0 0]]
    set sumBytes [expr [lindex $timeList end 1] - [lindex $timeList 0 1]]
    
    # Treat the case with wrap around. (Guess)
    if {$sumMillis <= 0} {
	set sumMillis 1000000
    }
    
    # Returns average bytes per second.
    return [expr 1000.0 * $sumBytes / ($sumMillis + 1.0)]
}

proc ::Timing::GetRateLinearInterp {key} {
    variable timing
    
    set len [llength $timing($key)]
    if {$len <= 1} {
	return 0.0
    }
    set n 12
    set istart [expr $len - $n]
    if {$n > $len} {
	set n $len
	set istart 0
    }
    
    # Keep only the part we are interested in.
    set timing($key) [lrange $timing($key) $istart end]
    set sumx  0.0
    set sumy  0.0
    set sumxy 0.0
    set sumx2 0.0
    
    # Need to move origin to get numerical stability!
    set x0 [lindex $timing($key) 0 0]
    set y0 [lindex $timing($key) 0 1]
    foreach co $timing($key) {
	set x [expr [lindex $co 0] - $x0]
	set y [expr [lindex $co 1] - $y0]
	set sumx  [expr $sumx + $x]
	set sumy  [expr $sumy + $y]
	set sumxy [expr $sumxy + $x * $y]
	set sumx2 [expr $sumx2 + $x * $x]
    }
    
    # This is bytes per millisecond.
    set k [expr ($n * $sumxy - $sumx * $sumy) /  \
      ($n * $sumx2 - $sumx * $sumx)]
    return [expr 1000.0 * $k]
}

proc ::Timing::GetPercent {key totalbytes} {
    variable timing

    if {[llength $timing($key)] > 1} {
	set bytes [lindex $timing($key) end 1]
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
    
    #set bytesPerSec [::Timing::GetRateLinearInterp $key]
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
	set bytes [lindex $timing($key) end 1]
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

#-------------------------------------------------------------------------------
