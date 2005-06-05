#  History.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements various methods to handle history info.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: History.tcl,v 1.8 2005-06-05 14:54:12 matben Exp $

package require uriencode

package provide History 1.0

namespace eval ::History:: {
    
    # Add all event hooks.
    ::hooks::register closeWindowHook    ::History::CloseHook

    variable uiddlg 1000
}

# History::PutToFile --
#
#       Writes chat event send/received to history file.
#       
# Arguments:
#       jid       jid
#       msg       {name dateISO body tag ?-thread threadID ...?}
#       
# Results:
#       none.

proc ::History::PutToFile {jid msg} {
    global  this
    
    set path [file join $this(historyPath) [uriencode::quote $jid]]    
    if {![catch {open $path a} fd]} {
	fconfigure $fd -encoding utf-8
	puts $fd "set message(\[incr uid]) {$msg}"
	close $fd
    }
}

# History::BuildHistory --
#
#       Builds history dialog for jid.
#       
# Arguments:
#       jid       2-tier jid
#       args
#             -class
#             -headtitle
#             -tagscommand
#             -title
#       
# Results:
#       dialog displayed.

proc ::History::BuildHistory {jid args} {
    global  prefs this wDlgs
    variable uiddlg
    variable historyOptions
    
    array set argsArr [list  \
      -class        History  \
      -headtitle    "[mc Date]:" \
      -tagscommand  ""       \
      -title        "[mc History]: $jid"  \
      ]
    array set argsArr $args
    
    set w $wDlgs(jhist)[incr uiddlg]
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
    wm title $w $argsArr(-title)
    
    set wtxt  $w.frall.fr
    set wtext $wtxt.t
    set wysc  $wtxt.ysc
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btclose -text [mc Close] \
      -command [list destroy $w]] -side right -padx 5 -pady 5
    pack [button $frbot.btclear -text [mc Clear]  \
      -command [list [namespace current]::ClearHistory $jid $wtext]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btprint -text [mc Print]  \
      -command [list [namespace current]::PrintHistory $wtext]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side bottom -fill x -padx 8 -pady 6
    
    # Text.
    set wchatframe $w.frall.fr
    pack [frame $wchatframe -class $argsArr(-class)] -fill both -expand 1
    text $wtext -height 20 -width 72 -cursor {} \
      -borderwidth 1 -relief sunken -yscrollcommand [list $wysc set] -wrap word
    scrollbar $wysc -orient vertical -command [list $wtext yview]
    grid $wtext -column 0 -row 0 -sticky news
    grid $wysc -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxt 0 -weight 1
    grid rowconfigure $wtxt 0 -weight 1    
	
    # The tags if any.
    if {[string length $argsArr(-tagscommand)]} {
	$argsArr(-tagscommand) $wchatframe $wtext    
    }
    set path [file join $this(historyPath) [uriencode::quote $jid]] 

    set clockFormat         [option get $wchatframe clockFormat {}]
    set clockFormatNotToday [option get $wchatframe clockFormatNotToday {}]
    
    if {[file exists $path]} {
	set uidstart 1000
	set uid $uidstart
	incr uidstart
	catch {source $path}
	set uidstop $uid
		    
	set day 0
	set prevday -1
	
	for {set i $uidstart} {$i <= $uidstop} {incr i} {
	    foreach {name dateISO body tag} $message($i) break
	    
	    # Insert a 'histhead' line for each new day.
	    set secs [clock scan $dateISO]
	    set day [clock format $secs -format "%j"]
	    if {$day != $prevday} {
		set dayFormat [clock format $secs -format "%A %B %e, %Y"]
		$wtext insert end "$argsArr(-headtitle) $dayFormat\n" histhead
	    }
	    set prevday $day
	    if {[::Utils::IsToday $secs]} {
		set theTime [clock format $secs -format $clockFormat]
	    } else {
		set theTime [clock format $secs -format $clockFormatNotToday]
	    }
	    if {$theTime != ""} {
		set prefix "\[$theTime\] "
	    } else {
		set prefix ""
	    }
	    append prefix "<$name>"

	    $wtext insert end $prefix ${tag}pre
	    $wtext insert end "   "   ${tag}text
	    
	    ::Text::Parse $wtext $body ${tag}text
	    $wtext insert end \n
	}
    } else {
	$wtext insert end "No registered history for $jid\n" histhead
    }
    $wtext configure -state disabled
    ::UI::SetWindowGeometry $w $wDlgs(jhist)
    wm minsize $w 200 320
}

proc ::History::ClearHistory {jid wtext} {
    global  this
    
    $wtext configure -state normal
    $wtext delete 1.0 end
    $wtext configure -state disabled
    set path [file join $this(historyPath) [uriencode::quote $jid]] 
    if {[file exists $path]} {
	file delete $path
    }
}

proc ::History::CloseHook {wclose} {
    global  wDlgs
    
    if {[string match $wDlgs(jhist)* $wclose]} {
	::UI::SaveWinPrefixGeom $wDlgs(jhist)
    }   
}

proc ::History::PrintHistory {wtext} {
	
    ::UserActions::DoPrintText $wtext
}

#-------------------------------------------------------------------------------
