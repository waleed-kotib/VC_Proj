#  History.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements various methods to handle history info.
#      
#  Copyright (c) 2004-2005  Mats Bengtsson
#  
# $Id: History.tcl,v 1.10 2005-08-26 15:02:34 matben Exp $

package require uriencode

package provide History 1.0

namespace eval ::History:: {
    
    # Add all event hooks.

    variable uiddlg 1000
}

#-------------------------------------------------------------------------------
# The old groupchat format is:
# 
#       set message(uid) {name dateISO body tag ?-thread threadID ...?}
#       
# The old chat format is:
# 
#       set message(uid) {jid2 threadID dateISO body}
#       
# The Ex format is:
# 
#       set message(uid) {-key value ...}
#       
#       with keys: -type -name -thread -time -body -tag
#-------------------------------------------------------------------------------

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

# DO NOT USE. OLD!!!!!!!!!!!!!!!!!!
proc ::History::PutToFile {jid msg} {
    global  this
    
    set path [file join $this(historyPath) [uriencode::quote $jid]]    
    if {![catch {open $path a} fd]} {
	#fconfigure $fd -encoding utf-8
	puts $fd "set message(\[incr uid]) {$msg}"
	close $fd
    }
}

# History::PutToFileEx --
#
#       Writes chat event send/received to history file.
#       
# Arguments:
#       jid       jid
#       msg       {-key value ...}
#       
# Results:
#       none.

proc ::History::PutToFileEx {jid args} {
    global  this
    
    set path [file join $this(historyPath) [uriencode::quote $jid]]    
    if {![catch {open $path a} fd]} {
	#fconfigure $fd -encoding utf-8
	puts $fd "set message(\[incr uid]) {$args}"
	close $fd
    }
}

# History::BuildHistory --
#
#       Builds history dialog for jid.
#       
# Arguments:
#       jid       2-tier jid
#       dlgtype   chat or groupchat
#       args
#             -class
#             -headtitle
#             -tagscommand
#             -title
#       
# Results:
#       dialog displayed.

proc ::History::BuildHistory {jid dlgtype args} {
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
    ::UI::Toplevel $w \
      -usemacmainmenu 1 -macstyle documentProc \
      -closecommand ::History::CloseHook
    wm title $w $argsArr(-title)
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    set wchatframe $wbox.fr
    set wtext      $wchatframe.t
    set wysc       $wchatframe.ysc

    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btclose -text [mc Close] \
      -command [list destroy $w]
    ttk::button $frbot.btclear -text [mc Clear]  \
      -command [list [namespace current]::ClearHistory $jid $wtext]
    ttk::button $frbot.btprint -text [mc Print]  \
      -command [list [namespace current]::PrintHistory $wtext]
    ttk::button $frbot.btsave -text [mc Save]  \
      -command [list [namespace current]::SaveHistory $jid $wtext]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btclose -side right
	pack $frbot.btclear -side right -padx $padx
	pack $frbot.btprint -side right
	pack $frbot.btsave  -side right -padx $padx
    } else {
	pack $frbot.btsave  -side right
	pack $frbot.btprint -side right -padx $padx
	pack $frbot.btclear -side right
	pack $frbot.btclose -side right -padx $padx
    }
    pack $frbot -side bottom -fill x
    
    # Text.
    frame $wchatframe -class $argsArr(-class)
    pack  $wchatframe -fill both -expand 1
    text $wtext -height 20 -width 72 -cursor {} \
      -highlightthickness 0 -borderwidth 1 -relief sunken \
      -yscrollcommand [list $wysc set] -wrap word
    tuscrollbar $wysc -orient vertical -command [list $wtext yview]

    grid  $wtext  -column 0 -row 0 -sticky news
    grid  $wysc   -column 1 -row 0 -sticky ns
    grid columnconfigure $wchatframe 0 -weight 1
    grid rowconfigure $wchatframe 0 -weight 1    
	
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
	if {[catch {source $path} err]} {
	    return
	}
	set uidstop $uid
		    
	set day 0
	set prevday -1
	set prevthread 0
	
	for {set i $uidstart} {$i <= $uidstop} {incr i} {
	    array unset msg
	    foreach key {body name tag type thread} {
		set msg(-$key) ""
	    }
	    array set msg [NormalizeMessage $jid $message($i)]

	    if {$dlgtype ne $msg(-type)} {
		continue
	    }
	    if {$msg(-time) != ""} {
		set secs [clock scan $msg(-time)]
		set day [clock format $secs -format "%j"]
	    } else {
		set secs ""
		set day 0
	    }
	    
	    # Insert a 'histhead' line for each new day.
	    set havehisthead 0
	    if {$day != $prevday} {
		set when [clock format $secs -format "%A %B %e, %Y"]
		$wtext insert end "$argsArr(-headtitle) $when\n" histhead
		set havehisthead 1
	    }
	    set prevday $day
	    
	    # Insert new thread if chat.
	    if {!$havehisthead && ($msg(-type) eq "chat")} {
		if {$msg(-thread) ne $prevthread} {
		    set when [clock format $secs -format "%A %B %e, %Y"]
		    $wtext insert end "[mc {Thread started}] $when\n" histhead
		}
	    }
	    set prevthread $msg(-thread)
	    
	    set prefix [GetTimeStr $secs $clockFormat $clockFormatNotToday]
	    append prefix "<$msg(-name)>"

	    $wtext insert end $prefix $msg(-tag)pre
	    $wtext insert end "   "   $msg(-tag)text
	    
	    ::Text::ParseMsg $dlgtype $jid $wtext $msg(-body) $msg(-tag)text
	    $wtext insert end \n
	}
    } else {
	$wtext insert end "No registered history for $jid\n" histhead
    }
    $wtext configure -state disabled
    ::UI::SetWindowGeometry $w $wDlgs(jhist)
    wm minsize $w 200 320
}

proc ::History::ReadMessageFile {jid} {
    global  this
    
    set path [file join $this(historyPath) [uriencode::quote $jid]] 
    set uidstart 1000
    set uid $uidstart
    incr uidstart
    
    # Read.
    source $path

    set uidstop $uid
    for {set i $uidstart} {$i <= $uidstop} {incr i} {
	set msg($i) [NormalizeMessage $jid $message($i)]
    }    
    return [array get msg]
}

proc ::History::HaveMessageFile {jid} {
    global  this
    
    set path [file join $this(historyPath) [uriencode::quote $jid]] 
    if {[file exists $path]} {
	return 1
    } else {
	return 0
    }
}

# History::NormalizeMessage --
# 
#       Return as a -key value list.

proc ::History::NormalizeMessage {jid msg} {
    
    # Try identify old format first:
    set fmt [GetMsgFormat $msg]
    
    switch -- $fmt {
	groupchat {
	    lassign $msg name dateISO body tag
	    set norm [list \
	      -type groupchat -name $name -time $dateISO -body $body -tag $tag]
	}
	chat {
	    lassign $msg jid2 thread dateISO body
	    if {$jid eq $jid2} {
		set tag you
	    } else {
		set tag me
	    }
	    set norm [list \
	      -type chat -name $jid2 -time $dateISO -body $body -tag $tag]
	}
	ex {
	    set norm $msg
	}
	"" {
	    return
	}
    }
    return $norm
}

proc ::History::GetTimeStr {secs clockFormat clockFormatNotToday} {
    
    if {![string is integer -strict $secs]} {
	return
    } elseif {[::Utils::IsToday $secs]} {
	set theTime [clock format $secs -format $clockFormat]
    } else {
	set theTime [clock format $secs -format $clockFormatNotToday]
    }
    if {$theTime != ""} {
	return "\[$theTime\] "
    } else {
	return
    }
}

proc ::History::GetMsgFormat {msg} {
    
    # Old 'groupchat' format is identified by an iso time at index 1.
    # Old 'chat' format has an iso time at index 2
    if {![catch {clock scan [lindex $msg 1]}] && \
      ([lindex $msg 0] ne "-time")} {
	return groupchat
    } elseif {![catch {clock scan [lindex $msg 2]}]} {
	return chat
    } else {
	foreach {key val} $msg {
	    if {![string match {-[a-z]*} $key]} {
		# This is inconsistent.
		return
	    }
	}
	return ex
    }
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

    ::UI::SaveWinPrefixGeom $wDlgs(jhist)
}

proc ::History::PrintHistory {wtext} {
	
    ::UserActions::DoPrintText $wtext
}

proc ::History::SaveHistory {jid wtext} {
    global  this
	
    set ans [tk_getSaveFile -title [mc Save] \
      -initialfile "Chat [uriencode::quote $jid].txt"]

    if {$ans != ""} {
	set allText [::Text::TransformToPureText $wtext]
	set fd [open $ans w]
	#fconfigure $fd -encoding utf-8
	puts $fd $allText	
	close $fd
    }
}

#-------------------------------------------------------------------------------
