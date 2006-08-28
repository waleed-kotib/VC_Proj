#  History.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements various methods to handle history info.
#      
#      UPDATE: switching to xml format.
#      
#  Copyright (c) 2004-2006  Mats Bengtsson
#  
# $Id: History.tcl,v 1.19 2006-08-28 13:55:30 matben Exp $

package require uriencode
package require UI::WSearch

package provide History 1.0

namespace eval ::History:: {
    
    # Add all event hooks.

    variable uiddlg 1000
}

# New xml based format ---------------------------------------------------------

proc ::History::XPutItem {jid xmldata} {
    
    set time [clock format [clock seconds] -format "%Y%m%dT%H:%M:%S"]
    set attr [list time $time]
    set itemE [wrapper::createtag item  \
      -attrlist $attr -subtags [list $xmldata]]
    set xml [wrapper::formatxml $itemE -tab "\t"]

    set mjid [jlib::jidmap $jid]
    set fileName [file join $this(historyPath) [uriencode::quote $mjid].nxml] 
    set fd [open $fileName a]
    fconfigure $fd -encoding utf-8
    puts $fd $xml
    close $fd
}

# History::XImportOld --
# 
#       Takes any old history file and creates a xml based with the extension
#       .nxml; not xml. This is since it is missing the root element in
#       order for each messages to be just appended to an existing file.

proc ::History::XImportOld {jid} {
    global  this
    
    if {![HaveMessageFile $jid]} {
	return
    }
    array set msgA [ReadMessageFromFile [GetMessageFile $jid] $jid]
    
    set mjid [jlib::jidmap $jid]
    set fileName [file join $this(historyPath) [uriencode::quote $mjid].nxml] 
    set fd [open $fileName w]
    fconfigure $fd -encoding utf-8
        
    foreach uid [lsort -integer [array names msgA]] {
	array unset rowA
	array set rowA $msgA($uid)
	set itemAttr {}
	set msgAttr {}
	set childEs {}
	if {[info exists rowA(-type)]} {
	    set type $rowA(-type)
	} else {
	    set type chat
	}
	
	foreach {key value} [array get rowA] {
	    switch -- $key {
		-time {
		    lappend itemAttr time $value
		}
		-body {
		    lappend childEs [wrapper::createtag body -chdata $value]
		}
		-thread {
		    lappend msgAttr thread $value
		}
		-name {
		    if {$type eq "groupchat"} {
			set from $jid/$value
			lappend msgAttr from $from
		    } elseif {$type eq "chat"} {
			lappend msgAttr from $jid
		    }
		}
		-tag {
		    # me, you, sys, they ?
		}
	    }
	}
	set messageE [wrapper::createtag message  \
	  -attrlist $msgAttr -subtags $childEs]
	set itemE [wrapper::createtag item  \
	  -attrlist $itemAttr -subtags [list $messageE]]
	
	set xml [wrapper::formatxml $itemE]
	puts $fd $xml	
    }
    close $fd
}

proc ::History::XInsertText {w} {
    global  this
    
    variable $w
    upvar 0 $w state

    set jid        $state(jid)
    set dlgtype    $state(dlgtype)
    set wtext      $state(wtext)
    set wchatframe $state(wchatframe)

    set mjid [jlib::jidmap $jid]
    set fileName [file join $this(historyPath) [uriencode::quote $mjid].nxml] 
    if {![file readable $fileName]} {
	return
    }
    set fd [open $fileName r]
    fconfigure $fd -encoding utf-8
    set xml [read $fd]
    close $fd
    set prefix "<?xml version='1.0' encoding='UTF-8'?>"
    append prefix \n
    append prefix "<root>"
    append prefix \n

    $wtext configure -state normal
    
    $wtext mark set insert end

    $wtext insert insert $xml
    
    $wtext configure -state disabled
    
    return
    
    set token [tinydom::parse $xml]
    set xmllist [tinydom::documentElement $token]

    
    
    tinydom::cleanup $token
}

proc ::History::HandleInsertText {w} {
    global  this
    
    variable $w
    upvar 0 $w state

    set jid $state(jid)

    # First, if any old import to new format and discard.
    set fileName [file join $this(historyPath) [uriencode::quote $jid]]    
    if {[file readable $fileName]} {
	XImportOld $jid
	# file delete $fileName
    }
    XInsertText $w
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
    
    array set argsA [list  \
      -class        History  \
      -headtitle    "[mc Date]:" \
      -tagscommand  ""       \
      -title        "[mc History]: $jid"  \
      ]
    array set argsA $args
    
    set w $wDlgs(jhist)[incr uiddlg]
    ::UI::Toplevel $w \
      -usemacmainmenu 1 -macstyle documentProc \
      -closecommand ::History::CloseHook
    wm title $w $argsA(-title)

    variable $w
    upvar 0 $w state

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    set wchatframe $wbox.fr
    set wtext      $wchatframe.t
    set wysc       $wchatframe.ysc
    
    set state(jid)        $jid
    set state(dlgtype)    $dlgtype
    set state(wtext)      $wtext
    set state(wchatframe) $wchatframe
    set state(wfind)      $wchatframe.find
    set state(argsA)      [array get argsA]

    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btcancel -text [mc Close] \
      -command [list destroy $w]
    ttk::button $frbot.btclear -text [mc Clear]  \
      -command [list [namespace current]::ClearHistory $jid $wtext]
    ttk::button $frbot.btprint -text [mc Print]  \
      -command [list [namespace current]::PrintHistory $wtext]
    ttk::button $frbot.btsave -text [mc Save]  \
      -command [list [namespace current]::SaveHistory $jid $wtext]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btcancel -side right
	pack $frbot.btclear  -side right -padx $padx
	pack $frbot.btprint  -side right
	pack $frbot.btsave   -side right -padx $padx
    } else {
	pack $frbot.btsave   -side right
	pack $frbot.btprint  -side right -padx $padx
	pack $frbot.btclear  -side right
	pack $frbot.btcancel -side right -padx $padx
    }
    pack $frbot -side bottom -fill x
    
    # Text.
    ttk::frame $wchatframe -class $argsA(-class)
    pack  $wchatframe -fill both -expand 1
    text $wtext -height 20 -width 72 -cursor {} -wrap word \
      -highlightthickness 0 -borderwidth 1 -relief sunken \
      -yscrollcommand [list ::UI::ScrollSet $wysc \
      [list grid $wysc -column 1 -row 0 -sticky ns]]
    ttk::scrollbar $wysc -orient vertical -command [list $wtext yview]
    bindtags $wtext [linsert [bindtags $wtext] 0 ReadOnlyText]

    grid  $wtext  -column 0 -row 0 -sticky news
    grid  $wysc   -column 1 -row 0 -sticky ns
    grid columnconfigure $wchatframe 0 -weight 1
    grid rowconfigure $wchatframe 0 -weight 1    
	
    # The tags if any.
    if {[string length $argsA(-tagscommand)]} {
	$argsA(-tagscommand) $wchatframe $wtext    
    }

    InsertText $w
        
    ::UI::SetWindowGeometry $w $wDlgs(jhist)

    bind $w <$this(modkey)-Key-f> [list [namespace code Find] $w]
    bind $w <$this(modkey)-Key-g> [list [namespace code FindNext] $w]
    bind $w <Destroy> +[list [namespace code OnDestroy] $w]

    set script [format {
	update idletasks
	set min [winfo reqwidth %s]
	wm minsize %s [expr {$min+20}] 200
    } $frbot $w]    
    after idle $script
}

proc ::History::InsertText {w} {
    global  this
    
    variable $w
    upvar 0 $w state

    set jid        $state(jid)
    set dlgtype    $state(dlgtype)
    set wtext      $state(wtext)
    set wchatframe $state(wchatframe)
    
    array set argsA $state(argsA)

    set mjid [jlib::jidmap $jid]
    set path [file join $this(historyPath) [uriencode::quote $mjid]] 

    set clockFormat         [option get $wchatframe clockFormat {}]
    set clockFormatNotToday [option get $wchatframe clockFormatNotToday {}]

    $wtext configure -state normal
    $wtext mark set insert end

    if {[file readable $path]} {
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
		$wtext insert end "$argsA(-headtitle) $when\n" histhead
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
	$wtext insert end [mc {No registered history for} $jid] histhead
	$wtext insert end "\n" histhead
    }
    $wtext configure -state disabled
}

proc ::History::Find {w} {
    variable $w
    upvar 0 $w state
    
    set wfind $state(wfind)
    if {![winfo exists $wfind]} {
	UI::WSearch $wfind $state(wtext) -padding {2}
	grid  $wfind  -column 0 -row 2 -columnspan 2 -sticky ew
    }
}

proc ::History::FindNext {w} {
    variable $w
    upvar 0 $w state

    set wfind $state(wfind)
    if {[winfo exists $wfind]} {
	$wfind Next
    }
}

proc ::History::ReadMessageFile {jid} {
    global  this
    
    set fileName [file join $this(historyPath) [uriencode::quote $jid]] 
    return [ReadMessageFromFile $fileName $jid]
}

proc ::History::ReadMessageFromFile {fileName jid} {
    
    set uidstart 1000
    set uid $uidstart
    incr uidstart
    
    # Read.
    source $fileName

    set uidstop $uid
    for {set i $uidstart} {$i <= $uidstop} {incr i} {
	set msg($i) [NormalizeMessage $jid $message($i)]
    }    
    return [array get msg]
}

proc ::History::HaveMessageFile {jid} {
    global  this
    
    set mjid [jlib::jidmap $jid]
    set fileName [file join $this(historyPath) [uriencode::quote $mjid]] 
    if {[file exists $fileName]} {
	return 1
    } else {
	return 0
    }
}

proc ::History::GetMessageFile {jid} {
    global  this
    
    set mjid [jlib::jidmap $jid]
    set fileName [file join $this(historyPath) [uriencode::quote $mjid]] 
    if {[file exists $fileName]} {
	return $fileName
    } else {
	return ""
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

proc ::History::OnDestroy {w} {
    unset -nocomplain $w
}


#-------------------------------------------------------------------------------
