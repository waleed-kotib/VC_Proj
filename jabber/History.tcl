#  History.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements various methods to handle history info.
#      
#  Copyright (c) 2004-2007  Mats Bengtsson
#  
# $Id: History.tcl,v 1.27 2007-02-03 06:42:06 matben Exp $

package require uriencode
package require UI::WSearch

package provide History 1.0

namespace eval ::History:: {
    
    ::hooks::register menuHistoryDlgEditPostHook    ::History::MenuEditPostHook

    variable uiddlg 1000
    
    # History file size limit of 50k
    variable sizeLimit 50000
    
    variable xmlPrefix
    set xmlPrefix ""
    append xmlPrefix "<?xml version='1.0' encoding='UTF-8'?>"
    append xmlPrefix "\n" 
    append xmlPrefix "<?xml-stylesheet type='text/xsl' href='log.xsl'?>"
    append xmlPrefix "\n"
    append xmlPrefix "<!DOCTYPE log>" 
    append xmlPrefix "\n" 
    append xmlPrefix "<log jid='%s'>"
    
    variable xmlPostfix
    set xmlPostfix "</log>"
    
    # For the pseudo xml parser:

    # Convenience routine
    proc cl x {
	return "\[$x\]"
    }

    # white space
    variable Wsp " \t\r\n"
    
    variable bodyRE     ^[cl $Wsp]*<body>
    variable sendrecvRE ^[cl $Wsp]*<(send|recv)
    variable timeRE     time='([cl ^']+)'
    variable endlogRE   ^[cl $Wsp]*</log>
}

# Test code:
if {0} {
    set f /Users/matben/Library/Preferences/Coccinella/History/mari@localhost-0.nxml
    set f /Users/matben/Desktop/mariShort.xml
    set f /Users/matben/Desktop/mari.xml
    set age [expr [clock seconds] - [clock scan 20070124T14:17:54]]
    ::History::XFastSelection $f 10 $age  
    
    ::History::XFastParseFiles mari@localhost 2 0
}

# New xml based format ---------------------------------------------------------
#
#       o Always store history per JID
#       o File names must have the JID uri encoded
#       o Split the complete history for a JID in multiple files of certain
#         min size
#       OLD:
#       o Use file names JID-#.nxml where # is a running integer (nxml format)
#       o The extension is .nxml since we store without root elements
#       NEW (070131):
#       o Use file names JID-#.xml where # is a running integer (xml format)
#       o The files are proper xml and no fake
#       
# @@@ TODO:
#       + Maybe we should allow history file splits during sessions


proc ::History::XExportOldAndXToFile {jid fileName} {
    global  this
    variable xmlPrefix
    variable xmlPostfix
    
    set prefix [format $xmlPrefix [wrapper::xmlcrypt $jid]]
    set postfix $xmlPostfix

    set fd [open $fileName w]
    fconfigure $fd -encoding utf-8
    puts $fd $prefix

    # Old format.
    if {[HaveMessageFile $jid]} {
	set tmp [::tfileutils::tempfile $this(tmpPath) ""]
	XImportOldToFile $jid $tmp
	set tmpfd [open $tmp r]
	fconfigure $tmpfd -encoding utf-8
	fcopy $tmpfd $fd
	close $tmpfd
	file delete $tmp
    }
    
    # The nxml format.
    foreach f [XGetAllNXMLFileNames $jid] {
	if {[file readable $f]} {
	    set srcfd [open $f r]
	    fconfigure $srcfd -encoding utf-8
	    fcopy $srcfd $fd
	    close $srcfd
	}
    }    
    
    # True xml format.
    puts $fd [XReadAllXMLToFlat $jid]
    
    puts $fd $postfix
    close $fd
}

proc ::History::XGetPutFileName {jid} {
    global  this
    variable jidToFile
    variable sizeLimit
    
    # Cache put file per JID since it costs to find it each time. ???
    set mjid [jlib::jidmap $jid]
    if {[info exists jidToFile($mjid)] && [file exists $jidToFile($mjid)]} {
	return $jidToFile($mjid)
    }
    set rootTail [uriencode::quote $mjid]
    set files [XGetAllXMLFileNames $mjid]
    if {[llength $files] == 0} {
	
	# First history file.
	set hfile [file join $this(historyPath) ${rootTail}-0.xml]
    } else {
	set hfile [lindex $files end]
	if {[file size $hfile] > $sizeLimit} {
	    
	    # Create a new one.
	    if {[regexp $hfile {-([0-9]{1,})\.xml$} - n]} {
		incr n
		set hfile [file join $this(historyPath) ${rootTail}-$n.xml]
	    } else {
		# Should never happen.
		set hfile [file join $this(historyPath) ${rootTail}-0.xml]
	    }
	}
    }
    set jidToFile($mjid) $hfile
    return $hfile
}

# History::XGetAllFileNames --
# 
#       Gets history files for JID in an ordered manner from old to new.
#       Note the naming conventions for the nxml and xml formats.

proc ::History::XGetAllFileNames {jid} {
    return [concat [XGetAllNXMLFileNames $jid] [XGetAllXMLFileNames $jid]]
}

proc ::History::XGetAllNXMLFileNames {jid} {
    global  this
    
    set mjid [jlib::jidmap $jid]
    set rootTail [uriencode::quote $mjid]
    set nfiles [glob -nocomplain -directory $this(historyPath) ${rootTail}-*.nxml]
    return [lsort -dictionary $nfiles]
}

proc ::History::XGetAllXMLFileNames {jid} {
    global  this
    
    set mjid [jlib::jidmap $jid]
    set rootTail [uriencode::quote $mjid]
    set xfiles [glob -nocomplain -directory $this(historyPath) ${rootTail}-*.xml]
    return [lsort -dictionary $xfiles]
}

proc ::History::XHaveHistory {jid} {
    return [llength [XGetAllFileNames $jid]]
}

proc ::History::XHaveNXMLHistory {jid} {
    return [llength [XGetAllNXMLFileNames $jid]]
}

proc ::History::XHaveXMLHistory {jid} {
    return [llength [XGetAllXMLFileNames $jid]]
}

# History::XParseNXMLFiles --
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

# SLOOOOOOOOOOOOOWWWWW!!!!!!
# Only for the nxml format!
proc ::History::XParseNXMLFiles {jid args} {
    if {[XHaveNXMLHistory $jid]} {
	set xml [XReadAllNXMLToXML $jid]
	return [eval {XParseXMLAndSelect $xml} $args]
    } else {
	return {}
    }
}

# Works for both nxml and xml formats.
proc ::History::XFastParseFiles {jid nlast maxage} {
    variable xmlPrefix
    variable xmlPostfix

    if {[XHaveHistory $jid]} {
	
	set t [clock clicks -milliseconds]
	
	set files [XGetAllFileNames $jid]
	set nleft $nlast
	set elemL ""
	
	# Process history files from newest to oldest until we run out of files
	# or have aquired 'nlast' messages.
	while {[llength $files]} {
	    set fileName [lindex $files end]
	    set files [lrange $files 0 end-1]
	    lassign [XFastSelection $fileName $nlast $maxage] n xml
	    incr nleft -$n
	    set elemL $xml$elemL
	    if {$nleft <= 0} {
		break
	    }	    
	}
	puts "XFastSelection: [expr [clock clicks -milliseconds]-$t]"
	set t [clock clicks -milliseconds]

	# Parse into xmllists to fit tcl.
	set token [tinydom::parse $xmlPrefix$elemL$xmlPostfix]
	set xmllist [tinydom::documentElement $token]
	tinydom::cleanup $token
	puts "tinydom::parse [expr [clock clicks -milliseconds]-$t]"
	return [wrapper::getchildren $xmllist]
    } else {
	return {}
    }
}

# Only for the nxml format!
proc ::History::XReadAllNXMLToXML {jid} {
    variable xmlPrefix
    variable xmlPostfix
    
    set prefix [format $xmlPrefix [wrapper::xmlcrypt $jid]]
    set postfix $xmlPostfix
    set xml [XReadAllNXMLToFlat $jid]
    
    # Add root tags to make true xml.
    return $prefix$xml$postfix
}

proc ::History::XReadAllNXMLToFlat {jid} {
    
    # Start by reading all xml from all nxml files.
    set xml ""
    set files [XGetAllNXMLFileNames $jid]
    foreach f $files {
	if {[file readable $f]} {
	    set fd [open $f r]
	    fconfigure $fd -encoding utf-8
	    append xml [read $fd]
	    close $fd
	}
    }
    return $xml
}

proc ::History::XParseNXMLToItemList {jid} {

    set xml [XReadAllNXMLToXML $jid]
    set token [tinydom::parse $xml]
    set xmllist [tinydom::documentElement $token]
    tinydom::cleanup $token
    return [wrapper::getchildren $xmllist]
}

proc ::History::XReadAllXMLToFlat {jid} {
    
    set flatxml ""
    set files [XGetAllXMLFileNames $jid]
    foreach f $files {
	if {[file readable $f]} {
	    set fd [open $f r]
	    fconfigure $fd -encoding utf-8
	    set xml [read $fd]
	    close $fd
	    
	    # Extract the stuff between <log ..> and </log>
	    regexp -indices "<log +[cl ^>]+>" $xml idxL
	    set idx0 [expr {[lindex $idxL 1] + 1}]
	    regexp -indices "</log>" $xml idxL
	    set idx1 [expr {[lindex $idxL 0] - 1}]
	    append flatxml [string range $xml $idx0 $idx1]
	}
    }
    return $flatxml
}

proc ::History::XParseXMLToItemList {jid} {
    variable xmlPrefix
    variable xmlPostfix

    # First need to join all xml files.
    set xmlflat [XReadAllXMLToFlat $jid]
    set token [tinydom::parse $xmlPrefix$xmlflat$xmlPostfix]
    set xmllist [tinydom::documentElement $token]
    tinydom::cleanup $token
    return [wrapper::getchildren $xmllist]
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
    if {![file exists $fileName]} {
	XPutHeader $fileName $jid
    }
    XAppendTag $fileName $xml
}

proc ::History::XPutHeader {fileName jid} {
    variable xmlPrefix
    
    # Only if not exists!
    set fd [open $fileName {WRONLY CREAT}]
    fconfigure $fd -encoding utf-8
    set xml [format $xmlPrefix [wrapper::xmlcrypt $jid]]
    puts $fd $xml
    close $fd
}

proc ::History::XAppendTag {fileName xml} {
    variable xmlPostfix
    
    set fd [open $fileName {RDWR}]
    fconfigure $fd -encoding utf-8
    set endTag $xmlPostfix
    
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

# History::XFastSelection --
# 
#       Selects the last <send/> or <recv/> tags which contain nlast 'body' 
#       element.
#       Hardcoded and dedicated brute xml parsing.
#       It does several assumptions about the format of the xml.
#       In particular it assumes that xml is pretty formatted with tags on 
#       separate lines.
#       
# Arguments:
#       fileName
#       nlast       pick these many elements from the end which contain
#                   a body element. If -1 accept all.
#       maxage      maximum age in terms of seconds from now. If 0 accept
#                   independent of age.
#       
# Results:
#       a list {ntotal xml} :
#           ntotal is the number of elements that matched
#           xml is a list of the recv and send tags only

proc ::History::XFastSelection {fileName nlast maxage} {
    variable bodyRE
    variable sendrecvRE
    variable timeRE
    variable endlogRE
    
    if {$nlast == 0} {
	return [list 0 ""]
    }
    
    # NB: We can't count in bytes since 'read' counts characters:
    # Both seek and tell operate in terms of bytes, not characters, unlike read.
    # Count lines instead.    
    set skip 0
    set anyskip 0
    set nbody 0
    set nlines 0
    set everyone 0
    set now [clock seconds]

    set fd [open $fileName r]
    fconfigure $fd -encoding utf-8

    while {[gets $fd line] != -1} {
	incr nlines
	set content($nlines) $line
			
	# send/recv tags always come before body
	if {[regexp $sendrecvRE $line]} {
	    set nsendrecv $nlines
	    if {![info exists nfirstline]} {
		set nfirstline $nlines
	    }
	    
	    # Skip if older than maxage.
	    if {$maxage} {
		if {[regexp $timeRE $line - time]} {
		    set secs [clock scan $time]
		    if {[expr {$now - $secs > $maxage}]} {
			set skip 1
			set anyskip 1
			continue
		    }		
		}
		set skip 0
	    }
	} elseif {!$skip && [regexp $bodyRE $line]} {
	    
	    # Only the ones that pass any 'maxage' constraint.
	    incr nbody
	    set elemStart($nbody) $nsendrecv
	}
    }    
    close $fd
    
    if {$nlast == -1} {
	# Accept all.
	set nstart 1
	set ntotal $nbody
    } else {
	# Select the 'nlast' ones.
	set nstart [expr {$nbody - $nlast + 1}]
	set ntotal $nlast
	if {$nstart <= 0} {
	    set nstart 1
	    set ntotal $nbody
	}
    }
    
    # If all matched be sure to collect from the beginning.
    if {!$anyskip && ($nlast >= $nbody)} {
	set everyone 1
    }
    
    # Strip off any end tag.
    if {[regexp $endlogRE $content($nlines)]} {
	incr nlines -1
    }    
    
    # Collect the xml. Only if any matches.
    set xml ""
    if {[array exists elemStart]} {
	if {$everyone} {
	    set nfirst $nfirstline
	} else {
	    set nfirst $elemStart($nstart)
	}
	for {set n $nfirst} {$n <= $nlines} {incr n} {
	    append xml $content($n)
	    if {$n < $nlines} {
		append xml "\n"
	    }
	}
    }
    return [list $ntotal $xml]
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

# SLOOOOOOOOOOOOOWWWWW!!!!!!
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
#       Takes nxml and xml formatted history files and inserts content into 
#       dialog text widget.
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

    # Start with the nxml format since oldest.
    set item1L [XParseNXMLToItemList $jid]
    
    # Then the true xml format.
    set item2L [XParseXMLToItemList $jid]
    
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
    
    set itemL [concat $item1L $item2L]
    
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
#       Must work for all formats, old, nxml and xml.
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
    
    # nxml and xml based formats.
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
