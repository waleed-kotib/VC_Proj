#  Utils.tcl ---
#  
#      This file is part of the whiteboard application. We collect some handy 
#      small utility procedures here.
#      
#  Copyright (c) 1999-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Utils.tcl,v 1.2 2003-01-30 17:34:08 matben Exp $

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

# lsort -unique
#
#    Removes duplicate list items (from the Wiki page)

proc luniq {theList} {
    
    set t {}
    foreach i $theList {
	if {[lsearch -exact $t $i] == -1} {
	    lappend t $i
	}
    }
    return $t
}

# lset --
# 
#       Poor mans lset for pre 8.4. Not complete!

if {[info tclversion] < 8.4} {
    proc lset {listName args} {
	
	set usage {Usage: "lset listName ind1 ind2 value"}
	if {[llength $args] != 3} {
	    return -code error $usage
	}	
	foreach {ind1 ind2 value} $args { break }

	upvar $listName listValue
	if {[string equal $ind1 "end"]} {
	    set ind1 [expr [llength $listValue] - 1]
	}
	if {[string equal $ind2 "end"]} {
	    set ind2 [expr [llength [lindex $listValue $ind1]] - 1]
	}	
	if {![string is integer $ind1]} {
	    return -code error $usage
	}
	if {![string is integer $ind2]} {
	    return -code error $usage
	}
	
	# Do the job.
	set subList [lreplace [lindex $listValue $ind1] $ind2 $ind2 $value]
	set $listName [lreplace $listValue $ind2 $ind2 $subList]
    }
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

# GetRelativePath ---         OUTDATED!!!!!!!!!!!
#
#       Returns the relative path from fromPath to toPath. 
#       Both fromPath and toPath must be absolute paths.
#       
#       PROBLEM: different drives on Windows????
#    
# Arguments:
#       fromPath       an absolute path which is the "original" path.
#       toPath         an absolute path which is the "destination" path.
#                      It may contain a file name at end.
# Results:
#       The relative (unix-style) path from 'fromPath' to 'toPath'.

proc GetRelativePath {fromPath toPath} {
    global  this
    
    set debug 0
    if {$debug} {
	puts "GetRelativePath:: fromPath=$fromPath, toPath=$toPath"
    }
    switch -glob -- $this(platform) {
	mac* {
	    set sep {:/}
	}
	windows {
	    set sep {/\\}
	}
	unix {
	    set sep {/}
	}
    }
    
    # Need real paths, not fake, for getdirname.
    set fromPath [getdirname $fromPath]
    if {[file pathtype $fromPath] != "absolute"} {
	error "both paths must be absolute paths"
    } elseif {[file pathtype $toPath] != "absolute"} {
	error "both paths must be absolute paths"
    }
    set up {../}
    
    # This is the method to reach platform independence.
    # We must be sure that there are no path separators left.   
    # Mess with upper/lower on Windows.
    set fromP {}
    foreach elem [file split $fromPath] {
	if {[string equal $this(platform) "windows"]} {
	    lappend fromP [string tolower [string trim $elem $sep]]
	} else {
	    lappend fromP [string trim $elem $sep]
	}
    }
    set toP {}
    foreach elem [file split $toPath] {
	if {[string equal $this(platform) "windows"]} {
	    lappend toP [string tolower [string trim $elem $sep]]
	} else {
	    lappend toP [string trim $elem $sep]
	}
    }
    set lenFrom [llength $fromP]
    set lenTo [llength $toP]
    set lenMin [min $lenFrom $lenTo]
    if {$debug} {
	puts "  fromP=$fromP"
	puts "  toP=$toP"
	puts "  lenFrom=$lenFrom, lenTo=$lenTo"
    }
    
    # Find first nonidentical dir; iid = index of lowest common directory.
    # If there are no common dirs we are left with iid = -1.    
    set iid 0
    while {[string equal [lindex $fromP $iid] [lindex $toP $iid]] && \
      ($iid < $lenMin)} {
	incr iid
    }
    incr iid -1
    set numUp [expr $lenFrom - 1 - $iid]
    if {$debug} {
	puts "  iid=$iid, numUp=$numUp"
    }
    
    # Start building the relative path.
    set relPath {}
    if {$numUp > 0} {
	for {set i 1} {$i <= $numUp} {incr i} {
	    append relPath $up
	}
    }
    
    # Append the remaining unique path from 'toPath'.
    set relPath   \
      "$relPath[join [lrange $toP [expr $iid + 1] [expr $lenTo - 1]] /]"
    return $relPath
}

# AddAbsolutePathWithRelative ---       OUTDATED!!!!!!!!!!!!
#
#       Adds the second, relative path, to the first, absolute path.
#       IMPORTANT: any changes should be copied to 'TinyHttpd.tcl'.
#           
# Arguments:
#       absPath        an absolute path which is the "original" path.
#       toPath         a relative path which should be added.
#       
# Results:
#       The absolute path by adding 'absPath' with 'relPath'.

proc AddAbsolutePathWithRelative {absPath relPath} {
    global  this
    
    # For 'TinyHttpd.tcl'.
    #variable state
    set state(debug) 0
    if {$state(debug) >= 3} {
	puts "AddAbsolutePathWithRelative:: absPath=$absPath, relPath=$relPath"
    }

    # Be sure to strip off any filename.
    set absPath [getdirname $absPath]
    if {[file pathtype $absPath] != "absolute"} {
	error "first path must be an absolute path"
    } elseif {[file pathtype $relPath] != "relative"} {
	error "second path must be a relative path"
    }

    # This is the method to reach platform independence.
    # We must be sure that there are no path separators left.
    
    set absP {}
    foreach elem [file split $absPath] {
	lappend absP [string trim $elem "/:\\"]
    }
    
    # If any up dir (../ ::  ), find how many. Only unix style.
    set numUp [regsub -all {\.\./} $relPath {} newRelPath]
   
    # Delete the same number of elements from the end of the absolute path
    # as there are up dirs in the relative path.
    
    if {$numUp > 0} {
	set iend [expr [llength $absP] - 1]
	set upAbsP [lreplace $absP [expr $iend - $numUp + 1] $iend]
    } else {
	set upAbsP $absP
    }
    set relP {}
    foreach elem [file split $newRelPath] {
	lappend relP [string trim $elem "/:\\"]
    }
    set completePath "$upAbsP $relP"

    # On Windows we need special treatment of the "C:/" type drivers.
    if {$this(platform) == "windows"} {
    	set finalAbsPath   \
	    "[lindex $completePath 0]:/[join [lrange $completePath 1 end] "/"]"
    } else {
        set finalAbsPath "/[join $completePath "/"]"
    }
    return $finalAbsPath
}

# IsIPNumber --
#
#       Tests if the arguments is a ip number, that is, 200.54.2.0
#       Not foolproof! Should be able to tell the difference between
#       a ip name and a ip number.

proc IsIPNumber {thing} {
    
    set sub_ {([0-2][0-9][0-9]|[0-9][0-9]|[0-9])}
    set d_ {\.}
    return [regexp "^${sub_}${d_}${sub_}${d_}${sub_}${d_}${sub_}$" $thing]
}

# IsWellformedUrl --
#
#       Returns boolean depending on if argument is a well formed URL.
#       Not foolproof!

proc IsWellformedUrl {url} {
    
    return [regexp {[^:]+://[^:/]+(:[0-9]+)?[^ ]*} $url]
}

# GetFilePathFromUrl --
#
#       Returns the file path part from a well formed url, or 0 if
#       didn't recognize it as a valid url.

proc GetFilePathFromUrl {url} {
    
    if {[regexp {[^:]+://[^:/]+(:[0-9]+)?/(.*)} $url match port path]} {
	return $path
    } else {
	return 0
    }
}

# SmartClockFormat --
#
#       Pretty formatted time & date.
#
# Arguments:
#       secs        number of seconds since system defined time.
#       
# Results:
#       nice time string that still can be used by 'clock scan'

proc SmartClockFormat {secs} {
    
    # 'days': 0=today, -1=yesterday etc.
    set days [expr ($secs - [clock scan "today 00:00"])/(60*60*24)]
    switch -- $days {
	1 {
	    set date "tomorrow"
	}
	0 {
	    set date "today"
	}
	-1 {
	    set date "yesterday"
	}
	default {
	    set date [clock format [clock seconds] -format "%y-%m-%d"]
	}
    }
    
    set time [clock format $secs -format "%H:%M:%S"]
    return "$date $time"
}

proc OpenHtmlInBrowser {url} {
    global  this prefs
    
    switch $this(platform) {
	unix {
	    set cmd "exec netscape $url &"
	    if {[catch {eval $cmd}]} {
		exec netscape &
	    }
	}
	windows {	    
	    ::Windows::OpenUrl $url
	}
	macintosh {    
	    if {$prefs(applescript)} {
		set script {
		    tell application "Netscape Communicatorª"
		    open(file "%s")
		    Activate -1
		    end tell
		}
		AppleScript execute [format $script $url]
	    }
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
}

# Utils::GenerateHexUID --
#
#       Makes a unique hex string stamped by time.

proc ::Utils::GenerateHexUID { } {
    variable uid
    
    set rem [expr [incr uid] % 1000]
    set hex1 [format %x [clock format [clock seconds] -format "%Y%j%H"]]
    set hex2 [format %x [clock format [clock seconds] -format "1%M%S${rem}"]]
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

# Text::ParseHttpLinksForTextWidget --
# 
#       Parses text translating elements that may be interpreted as an url
#       to a clickable thing.
#
# Arguments:
#       str         the text string
#       tag         the normal text tag
#       linktag     the tag for links
#       
# Results:
#       A list {textcmd textcmd ...} where textcmd is typically:
#       "insert end {Some text} $tag"

proc ::Text::ParseHttpLinksForTextWidget {str tag linktag} {
    
    # Protect all special characters.
    regsub -all {\\|&} $str {\\\0} str

    # regexp hell, welcome!
    set wsp_ "\[ \t\r\n]"
    set path_ "\[^ \t\r\n,]"
    set epath_ "\[^ \t\r\n,\.]"
    set start_ "(^|\"|$wsp_)"
    set end_ "(\$|\"|$wsp_)"

    set re "${start_}((http://|www\\.)${path_}+${epath_})"
    set sub "\\1\} $tag\} \{insert end \{\\2\} \{$tag $linktag\}\} \{insert end \{"
    regsub -all -nocase -- $re $str $sub txtlist
    return "\{insert end \{$txtlist\} $tag\}"
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
    #puts "EnterLink: range=$range"
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
    #puts "LeaveLink range=$range"
    if {[llength $range]} {
	eval {$w tag add $linktag} $range
	eval {$w tag remove $linkactive} $range
    }
    $w configure -cursor arrow
}

proc ::Text::ButtonPressOnLink {w x y linkactive} {
    
    set range [$w tag prevrange $linkactive "@$x,$y"]
    if {[llength $range]} {
	set url [eval $w get $range]
	
	# Add "http://" if not there.
	if {![regexp {^http://.+} $url]} {
	    set url "http://$url"
	}
	#puts "ButtonPressOnLink $range $url"
	if {[IsWellformedUrl $url]} {
	    OpenHtmlInBrowser $url
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
    
    # Add "http://" if not there.
    if {![regexp {^http://.+} $url]} {
	set url "http://$url"
    }
    #puts "ButtonPressOnURL $url"
    if {[IsWellformedUrl $url]} {
	OpenHtmlInBrowser $url
    }
}

# Text::ParseSmileysForTextWidget --
# 
#
# Arguments:
#       str         the text string
#       
# Results:
#       A list {str textimage ?str textimage ...?}

proc ::Text::ParseSmileysForTextWidget {str} {
    global  this
    
    upvar ::UI::smiley smiley
    upvar ::UI::smileyLongNames smileyLongNames
    upvar ::UI::smileyLongIm smileyLongIm
    
    # Since there are about 60 smileys we need to be economical here.    
    # Check first if there is any short smiley.
	
    # Protect all special characters. Regexp hell!!!
    regsub -all {\\|&} $str {\\\0} str
    foreach smile [array names smiley] {
	set sub "\} \{image create end -image $smiley($smile)\} \{"
	regsub  {[)(|]} $smile {\\\0} smileExp
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
	    set sub "\} \{image create end -image $smileyLongIm($smile)\} \{"
	    regsub -all $smile $str $sub str
	}
    }
    
    return "\{$str\}"
}

# Text::ParseAllForTextWidget --
# 
#       Combines 'ParseSmileysForTextWidget' and 'ParseHttpLinksForTextWidget'.
#
# Arguments:
#       str         the text string
#       
# Results:
#       A list {textcmd textcmd ...} where textcmd is typically:
#       "insert end {Some text} $tag"

proc ::Text::ParseAllForTextWidget {str tag linktag} {
    
    set strSmile [ParseSmileysForTextWidget $str]
    #puts "strSmile=\t'$strSmile'"
    foreach {txt icmd} $strSmile {
	#puts "txt=\t\t'$txt'"
	#puts "icmd=\t\t'$icmd'"
	set httpCmd [ParseHttpLinksForTextWidget $txt $tag $linktag]
	#puts "httpCmd=\t'$httpCmd'"
	if {$icmd == ""} {
	    eval lappend res $httpCmd
	} else {
	    eval lappend res $httpCmd [list $icmd]
	}
    }
    return $res
}


proc ::Text::TransformToPureText {w args} {
    
    variable puretext
    
    if {[winfo class $w] != "Text"} {
	error {TransformToPureText needs a text widget here}
    }
    catch {unset puretext($w)}
    set puretext($w) {}
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
	    append puretext($w) {[Image:}
	    set filePath [$value cget -file]
	    if {[string length $filePath]} {
		append puretext($w) " [file tail $filePath]"
	    }
	    append puretext($w) {]}
	}
    }
}

#-------------------------------------------------------------------------------
