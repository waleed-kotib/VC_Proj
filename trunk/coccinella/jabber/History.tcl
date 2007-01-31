#  History.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements various methods to handle history info.
#      
#      UPDATE: switching to xml format.
#      
#  Copyright (c) 2004-2006  Mats Bengtsson
#  
# $Id: History.tcl,v 1.25 2007-01-31 07:33:11 matben Exp $

package require uriencode
package require UI::WSearch

package provide History 1.0

namespace eval ::History:: {
    
    ::hooks::register menuHistoryDlgEditPostHook    ::History::MenuEditPostHook

    variable uiddlg 1000
    
    # History file size limit of 100k
    variable sizeLimit 100000
    
    variable xmlPrefix
    set xmlPrefix "<?xml version='1.0' encoding='UTF-8'?>"
    append xmlPrefix "\n" 
    append xmlPrefix "<!DOCTYPE log>" 
    append xmlPrefix "\n" 
    append xmlPrefix "<?xml-stylesheet type='text/xsl' href='log.xsl'?>"
    append xmlPrefix "\n"
    append xmlPrefix "<log jid='%s'>"
}

# New xml based format ---------------------------------------------------------
#
#       o Always store history per JID
#       o File names must have the JID uri encoded
#       o Split the complete history for a JID in multiple files of certain
#         min size
#       o Use file names JID-#.nxml where # is a running integer
#       o The extension is .nxml since we store without root elements
#       
# @@@ TODO:
#       + Maybe we should allow history file splits during sessions


proc ::History::XExportOldAndXToFile {jid fileName} {
    global  this
    
    set prefix "<?xml version='1.0' encoding='UTF-8'?>"
    append prefix "\n" 
    append prefix "<!DOCTYPE log>" 
    append prefix "\n" 
    append prefix "<?xml-stylesheet type='text/xsl' href='log.xsl'?>"
    append prefix "\n"
    append prefix "<log jid='$jid'>"
    set postfix "</log>"

    set fd [open $fileName w]
    fconfigure $fd -encoding utf-8
    puts $fd $prefix

    if {[HaveMessageFile $jid]} {
	set tmp [::tfileutils::tempfile $this(tmpPath) ""]
	XImportOldToFile $jid $tmp
	set tmpfd [open $tmp r]
	fconfigure $tmpfd -encoding utf-8
	fcopy $tmpfd $fd
	close $tmpfd
	file delete $tmp
    }
    foreach f [XGetAllFileNames $jid] {
	if {[file readable $f]} {
	    set srcfd [open $f r]
	    fconfigure $srcfd -encoding utf-8
	    fcopy $srcfd $fd
	    close $srcfd
	}
    }    
    puts $fd $postfix
    close $fd
}

proc ::History::XGetPutFileName {jid} {
    global  this
    variable jidToFile
    variable sizeLimit
    
    # Cache put file per JID since it costs to find it each time.
    set mjid [jlib::jidmap $jid]
    if {[info exists jidToFile($mjid)] && [file exists $jidToFile($mjid)]} {
	return $jidToFile($mjid)
    }
    set rootTail [uriencode::quote $mjid]
    set files [XGetAllFileNames $mjid]
    if {[llength $files] == 0} {
	
	# First history file.
	set hfile [file join $this(historyPath) ${rootTail}-0.nxml]
    } else {
	set hfile [lindex $files end]
	if {[file size $hfile] > $sizeLimit} {
	    
	    # Create a new one.
	    if {[regexp $hfile {-([0-9]{1,})\.nxml$} - n]} {
		incr n
		set hfile [file join $this(historyPath) ${rootTail}-$n.nxml]
	    } else {
		# Should never happen.
		set hfile [file join $this(historyPath) ${rootTail}-0.nxml]
	    }
	}
    }
    set jidToFile($mjid) $hfile
    return $hfile
}

proc ::History::XGetAllFileNames {jid} {
    global  this
    
    set mjid [jlib::jidmap $jid]
    set rootTail [uriencode::quote $mjid]
    set files [glob -nocomplain -directory $this(historyPath) ${rootTail}-*.nxml]
    return [lsort -dictionary $files]
}

proc ::History::XHaveHistory {jid} {
    return [llength [XGetAllFileNames $jid]]
}

# History::XParseFiles --
# 
#       Reads all relevant history files for JID, parses them and does a
#       selection process based on the arguments.
#       Public interface.
# 
# Arguments:
#       jid
#       args: -last     integer
#             -maxage   seconds
#             -thread   thread ID

proc ::History::XParseFiles {jid args} {
    if {[XHaveHistory $jid]} {
	set xml [XReadAllToXML $jid]
	return [eval {XParseXMLAndSelect $xml} $args]
    } else {
	return {}
    }
}

# History::XPutItem --
# 
#       Appends xml to history file.
#       
# Arguments:
#       tag         "send" or "recv"
#       jid
#       xmldata

proc ::History::XPutItem {tag jid xmldata} {
            
    set time [clock format [clock seconds] -format "%Y%m%dT%H:%M:%S"]
    set attr [list time $time]
    set itemE [wrapper::createtag $tag  \
      -attrlist $attr -subtags [list $xmldata]]
    set xml [wrapper::formatxml $itemE -prefix "\t"]

    set fileName [XGetPutFileName $jid] 
    set fd [open $fileName a]
    fconfigure $fd -encoding utf-8
    puts $fd $xml
    close $fd
}

proc ::History::XAppendTag {fileName xml} {
    
    set fd [open $fileName {RDWR CREAT}]
    fconfigure $fd -encoding utf-8
    set endTag </log>
    
    # Write over the end tag and add it back after.
    seek $fd -10 end
    set data [read $fd]
    if {[regexp -indices $endTag $data idxL]} {
	set offset [expr {10 - [lindex $idxL 0]}]
	seek $fd -$offset end
    }
    puts $fd $xml
    puts $fd $endTag
    close $fd
}

# History::XImportOldToFile --
# 
#       Takes any old history file and writes it to fileName.
#       This is since it is missing the root element in
#       order for each messages to be just appended to an existing file.

proc ::History::XImportOldToFile {jid fileName} {
    
    if {![HaveMessageFile $jid]} {
	return
    }
    array set msgA [ReadMessageFromFile [GetMessageFile $jid] $jid]
    
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
	set tag me
	
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
		    set tag $value
		}
	    }
	}
	if {$tag eq "me"} {
	    set tagname send
	} else {
	    set tagname recv
	}
	set messageE [wrapper::createtag message  \
	  -attrlist $msgAttr -subtags $childEs]
	set itemE [wrapper::createtag $tagname  \
	  -attrlist $itemAttr -subtags [list $messageE]]
	
	set xml [wrapper::formatxml $itemE -prefix "\t"]
	puts $fd $xml	
    }
    close $fd
}

proc ::History::XReadAllToXML {jid} {
   
    # Start by reading all xml from all files.
    set xml ""
    set files [XGetAllFileNames $jid]
    foreach f $files {
	if {[file readable $f]} {
	    set fd [open $f r]
	    fconfigure $fd -encoding utf-8
	    append xml [read $fd]
	    close $fd
	}
    }
    
    # Add root tags to make true xml.
    set prefix "<?xml version='1.0' encoding='UTF-8'?>\n<log jid='$jid'>"
    set postfix "</log>"    
    return $prefix$xml$postfix
}

proc ::History::XParseXMLAndSelect {xml args} {
    
    array set argsA {
	-last      -1
	-maxage     0
	-thread     0
    }
    array set argsA $args

    set now [clock seconds]
    set maxage $argsA(-maxage)

    # Parse into xmllists to fit tcl.
    set token [tinydom::parse $xml]
    set xmllist [tinydom::documentElement $token]

    # Investigate the whole document tree and store into structures for analysis.
    # Start with the complete message history and limit using the options.
    # Keep track of new threads.
    
    set itemL {}
    set haveMessages 0
   
    foreach itemE [tinydom::children $xmllist] {	
	set tag [tinydom::tagname $itemE]

	if {$tag eq "send" || $tag eq "recv"} {
		
	    # Sort by age.
	    set time [tinydom::getattribute $itemE time]
	    set secs [clock scan $time]
	    if {$maxage && [expr {$now - $secs > $maxage}]} {
		continue
	    }		
	    set xmppE [lindex [tinydom::children $itemE] 0]
	    
	    switch -- [tinydom::tagname $xmppE] {
		message {
		    
		    # Sort by thread.
		    if {$argsA(-thread) ne "0"} {
			set threadE [tinydom::getfirstchildwithtag $xmppE thread]
			if {$threadE ne {}} {
			    set thread [tinydom::chdata $threadE]
			    if {$thread ne ""} {
				if {$argsA(-thread) ne $thread} {
				    continue
				}
			    }
			}
		    }
		    set haveMessages 1
		    
		    # Keep track of first and last message.
		    if {![info exists firstSecs]} {
			set firstSecs $secs
		    }
		    set lastSecs $secs
		    lappend itemL $itemE
		}
		presence {
		    lappend itemL $itemE
		}
	    }
	}
    }
    tinydom::cleanup $token
    
    # Since presence elements have no thread attribute we pick only those
    # between first and last threaded message.
    if {$argsA(-thread) ne "0"} {
	if {$haveMessages} {
	    set sortItemL {}
	    foreach itemE $itemL {
		set xmppE [lindex [tinydom::children $itemE] 0]
		if {[tinydom::tagname $xmppE] eq "presence"} {
		    set time [tinydom::getattribute $itemE time]
		    set secs [clock scan $time]
		    if {($secs < $firstSecs) || ($secs > $lastSecs)} {
			continue
		    }
		}
		lappend sortItemL $itemE
	    }
	    set itemL $sortItemL
	} else {
	    set itemL {}
	}
    }

    # Sort by last.
    if {$argsA(-last) != -1} {
	set last [expr {$argsA(-last) - 1}]
	set itemL [lrange $itemL end-$last end]
    }
    return $itemL
}

# History::XInsertText --
# 
#       Takes a xml formatted history files and inserts content into dialog
#       text widget.
# 
# Arguments:

proc ::History::XInsertText {w} {
    
    variable $w
    upvar 0 $w state

    set jid        $state(jid)
    set dlgtype    $state(dlgtype)
    set wtext      $state(wtext)
    set wchatframe $state(wchatframe)

    array set argsA $state(argsA)
    
    set mjid  [jlib::jidmap $jid]
    set mjid2 [jlib::barejid $mjid]
    
    set clockFormat         [option get $wchatframe clockFormat {}]
    set clockFormatNotToday [option get $wchatframe clockFormatNotToday {}]

    set itemL [XParseFiles $jid]

    #$wtext insert end "------------XML Based------------\n"
    
    $wtext configure -state normal    
    $wtext mark set insert end

    set day 0
    set prevday -1
    set prevthread 0
    set myRoomJid ""
    set myShow "unavailable"
    set myPrevShow "unavailable"
    
    # Keep track of own presence in the room of groupchat.
    set presence "unavailable"
    
    foreach itemE $itemL {
	set itemTag [tinydom::tagname $itemE]
	
	if {$itemTag ne "send" && $itemTag ne "recv"} {
	    continue
	}
	set xmppE [lindex [tinydom::children $itemE] 0]
	set stamp [::Jabber::GetDelayStamp $xmppE]
	if {$stamp ne ""} {
	    set secs [clock scan $stamp -gmt 1]
	} else {
	    set time [tinydom::getattribute $itemE time]
	    set secs [clock scan $time]
	    set day [clock format $secs -format "%j"]
	}
	set body ""
	set thread ""

	set from [tinydom::getattribute $xmppE from]
	set to   [tinydom::getattribute $xmppE to]
	jlib::splitjid $from from2 nick
	
	# Display name.
	if {$dlgtype eq "chat"} {
	    # Room participants?
	    set name [jlib::barejid $from]
	} else {
	    if {$nick ne ""} {
		set name $nick
	    } else {
		set name $from
	    }
	}
	
	# Display text tag.
	if {$itemTag eq "send"} {
	    set tag me
	} elseif {$itemTag eq "recv"} {
	    if {$dlgtype eq "chat"} {
		set tag you
	    } elseif {$dlgtype eq "groupchat"} {
		if {$nick ne ""} {
		    set tag they
		} else {
		    set tag sys
		}
	    }
	}
	set xmppTag [tinydom::tagname $xmppE]
	
	switch -- $xmppTag {
	    message {
		set threadE [tinydom::getfirstchildwithtag $xmppE thread]
		if {$threadE ne {}} {
		    set thread [tinydom::chdata $threadE]
		}
		set bodyE [tinydom::getfirstchildwithtag $xmppE body]
		if {$bodyE ne {}} {
		    set body [tinydom::chdata $bodyE]
		}
	    }
	    presence {
		set show [tinydom::getattribute $xmppE type]
		if {$show eq ""} {
		    set show available
		}
		set showE [tinydom::getfirstchildwithtag $xmppE show]
		if {$showE ne {}} {
		    set show [tinydom::chdata $showE]
		}
		set showStr [::Roster::MapShowToText $show]
		set body $showStr
		set statusE [tinydom::getfirstchildwithtag $xmppE status]
		if {$statusE ne {}} {
		    append body ", " [tinydom::chdata $statusE]
		}
		set tag sys

		if {$itemTag eq "send"} {
		    if {$dlgtype eq "groupchat"} {
			set myRoomJid [tinydom::getattribute $xmppE from]
		    }
		    if {$show ne $myShow} {
			set myPrevShow $myShow
			set myShow $show
		    }
		}
	    }
	}	
	
	# Insert a 'histhead' for certain events.
	set havehisthead 0
	switch -- $dlgtype {
	    chat {
		if {($thread ne "") && ($thread ne $prevthread)} {
		    set when [clock format $secs -format "%A %B %e, %Y"]
		    $wtext insert end "[mc {Thread started}] $when\n" histhead
		    set prevthread $thread
		    set havehisthead 1
		}
	    }
	    groupchat {
		if {$itemTag eq "send"} {
		    if {$xmppTag eq "presence" && $myShow ne $myPrevShow} {
			if {$myShow eq "available"} {
			    set prefix [GetTimeStr $secs $clockFormat $clockFormatNotToday]
			    set str "$prefix [mc {Enter room}]"
			    $wtext insert end $str\n histhead
			    set havehisthead 1
			} elseif {$myShow eq "unavailable"} {
			    set prefix [GetTimeStr $secs $clockFormat $clockFormatNotToday]
			    set str "$prefix [mc {Exit room}]"
			    $wtext insert end $str\n histhead
			    set havehisthead 1
			}
		    }
		}
	    }
	}
	if {!$havehisthead && ($day != $prevday)} {
	    set when [clock format $secs -format "%A %B %e, %Y"]
	    $wtext insert end "$argsA(-headtitle) $when\n" histhead
	    set havehisthead 1
	}
	set prevday $day
	
	set prefix [GetTimeStr $secs $clockFormat $clockFormatNotToday]
	append prefix "<$name>"
	
	$wtext insert end $prefix ${tag}pre
	$wtext insert end "   "   ${tag}text
	
	::Text::ParseMsg $dlgtype $jid $wtext $body ${tag}text
	$wtext insert end \n
    }
    $wtext configure -state disabled   
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
      -closecommand ::History::CloseHook -class HistoryDlg
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

    # Always start by inserting any old style format first.
    InsertText $w
    
    # New xml based format.
    XInsertText $w
    
    if {[$wtext index end] eq "1.0"} {
	$wtext configure -state normal
	$wtext insert end [mc {No registered history for} $jid] histhead
	$wtext insert end "\n" histhead
	$wtext configure -state disabled
    }
        
    ::UI::SetWindowGeometry $w $wDlgs(jhist)

    bind $w <<Find>>         [namespace code [list Find $w]]
    bind $w <<FindAgain>>    [namespace code [list FindAgain $w]]
    bind $w <<FindPrevious>> [namespace code [list FindAgain $w -1]]
    bind $w <Destroy>       +[list [namespace code OnDestroy] $w]

    set script [format {
	update idletasks
	set min [winfo reqwidth %s]
	wm minsize %s [expr {$min+20}] 200
    } $frbot $w]    
    after idle $script
}

proc ::History::MenuEditPostHook {wmenu} {
    
    if {[winfo exists [focus]]} {
	set w [winfo toplevel [focus]]
	if {[winfo class $w] eq "HistoryDlg"} {
	
	    variable $w
	    upvar 0 $w state
	    
	    ::UI::MenuMethod $wmenu entryconfigure mFind -state normal
	    set wfind $state(wfind)
	    if {[winfo exists $wfind]} {
		::UI::MenuMethod $wmenu entryconfigure mFindAgain -state normal
		::UI::MenuMethod $wmenu entryconfigure mFindPrevious -state normal
	    }
	}
    }
}

# History::InsertText --
# 
#       Inserts text from an old style history file.

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

    if {![file readable $path]} {
	return
    }
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
	if {$msg(-time) ne ""} {
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
	if {$msg(-name) ne ""} {
	    append prefix "<$msg(-name)>"
	}
	
	$wtext insert end $prefix $msg(-tag)pre
	$wtext insert end "   "   $msg(-tag)text
	
	::Text::ParseMsg $dlgtype $jid $wtext $msg(-body) $msg(-tag)text
	$wtext insert end \n
    }
    $wtext configure -state disabled
    
    return
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

proc ::History::FindAgain {w {dir 1}} {
    variable $w
    upvar 0 $w state

    set wfind $state(wfind)
    if {[winfo exists $wfind]} {
	$wfind [expr {$dir == 1 ? "Next" : "Previous"}]
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
    foreach path [XGetAllFileNames $jid] {
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

    if {$ans ne ""} {
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
