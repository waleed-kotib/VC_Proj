#  OOB.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the UI of the jabber:iq:oob part of the jabber.
#      
#  Copyright (c) 2001-2002  Mats Bengtsson
#  
# $Id: OOB.tcl,v 1.30 2004-06-06 07:02:21 matben Exp $

package provide OOB 1.0

namespace eval ::Jabber::OOB:: {

    ::hooks::add initHook            ::Jabber::OOB::InitHook

    variable locals
    set locals(initialLocalDir) [pwd]
    set locals(id) 1000

    # Running number for token.
    variable uid 0
}

proc ::Jabber::OOB::InitHook { } {
    variable locals
    
    # Drag and Drop support...
    set locals(haveTkDnD) 0
    if {![catch {package require tkdnd}]} {
	set locals(haveTkDnD) 1
    }       
}

# Jabber::OOB::BuildSet --
#
#       Dialog for sending a 'jabber:iq:oob' 'set' element.
#       
# Arguments:
#       jid         a full 3-tier jid

proc ::Jabber::OOB::BuildSet {jid} {
    global  this wDlgs
    
    variable finished
    variable localpath ""
    variable desc ""
    variable locals
    
    set w $wDlgs(joobs)
    if {[winfo exists $w]} {
	return
    }
    set finished -1
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm title $w {Send File}
    set locals(jid) $jid
    set fontS [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 12 -ipady 4
    
    message $w.frall.msg -width 300 -text [::msgcat::mc oobmsg $jid]
    pack $w.frall.msg -side top -fill both -expand 1
    
    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    label $frmid.lfile -text "[::msgcat::mc {File}]:" -font $fontSB -anchor e
    entry $frmid.efile    \
      -textvariable [namespace current]::localpath
    button $frmid.btfile -text "[::msgcat::mc {File}]..." -width 6 -font $fontS  \
      -command [namespace current]::FileOpen
    label $frmid.ldesc -text "[::msgcat::mc {Description}]:" -font $fontSB -anchor e
    entry $frmid.edesc -width 36    \
      -textvariable [namespace current]::desc
    grid $frmid.lfile -column 0 -row 0 -sticky e
    grid $frmid.efile -column 1 -row 0 -sticky ew
    grid $frmid.btfile -column 2 -row 0 
    grid $frmid.ldesc -column 0 -row 1 -sticky e
    grid $frmid.edesc -column 1 -row 1 -sticky ew -columnspan 2
    pack $frmid -side top -fill both -expand 1

    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [::msgcat::mc Send] -default active \
      -command [namespace current]::DoSend]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel]  \
      -command "set [namespace current]::finished 2"]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> ::Jabber::OOB::DoSend
    if {$locals(haveTkDnD)} {
	update
	::Jabber::OOB::InitDnD $frmid.efile
    }
    
    # Grab and focus.
    focus $w
    catch {grab $w}
    
    # Wait here for a button press.
    tkwait variable [namespace current]::finished
    
    catch {grab release $w}
    catch {destroy $w}    
}

proc ::Jabber::OOB::InitDnD {win} {
    
    dnd bindtarget $win text/uri-list <Drop>      \
      [list [namespace current]::DnDDrop %W %D %T]   
    dnd bindtarget $win text/uri-list <DragEnter> \
      [list [namespace current]::DnDEnter %W %A %D %T]   
    dnd bindtarget $win text/uri-list <DragLeave> \
      [list [namespace current]::DnDLeave %W %D %T]       
}

proc ::Jabber::OOB::DnDDrop {w data type} {
    global  prefs
    
    variable localpath
    ::Debug 2 "::Jabber::OOB::DnDDrop data=$data, type=$type"

    # Take only first file.
    set f [lindex $data 0]
	
    # Strip off any file:// prefix.
    set f [string map {file:// ""} $f]
    set f [uriencode::decodefile $f]
    set localpath $f
}

proc ::Jabber::OOB::DnDEnter {w action data type} {
    
    ::Debug 2 "::Jabber::OOB::DnDEnter action=$action, data=$data, type=$type"

    focus $w
    set act "none"
    return $act
}

proc ::Jabber::OOB::DnDLeave {w data type} {
    
    focus [winfo toplevel $w] 
}

proc ::Jabber::OOB::FileOpen { } {
    
    variable localpath
    variable locals

    set opts {}
    if {[file isdirectory $locals(initialLocalDir)]} {
	set opts [list -initialdir $locals(initialLocalDir)]
    }
    set ans [eval {tk_getOpenFile -title [::msgcat::mc {Pick File}]} $opts]
    if {[string length $ans]} {
	set localpath $ans
	set locals(initialLocalDir) [file dirname $ans]
    }
}

proc ::Jabber::OOB::DoSend { } {
    global  prefs wDlgs this
    
    variable finished
    variable localpath
    variable desc
    variable locals
    variable uid
    upvar ::Jabber::jstate jstate
    
    if {$localpath == ""} {
	tk_messageBox -type ok -title [::msgcat::mc {Pick File}] -message \
	  "You must provide a file to send" -parent $wDlgs(joobs)
	return
    }
    if {![file exists $localpath]} {
	tk_messageBox -type ok -title [::msgcat::mc {Pick File}]  \
	  -message "The picked file does not exist. Pick a new one." \
	  -parent $wDlgs(joobs)
	return
    }

    # Initialize the state variable, an array, that keeps is the storage.
    set token [namespace current]::[incr uid]
    variable $token
    upvar 0 $token state

    set finished 1
    set url [::Utils::GetHttpFromFile $localpath]
    
    # If 'jid' is without a resource, we MUST add it!
    set jid $locals(jid)
    if {![regexp {^[^@]+@[^/]+/(.+)$} $jid match res]} {
	set res [lindex [$jstate(roster) getresources $jid] 0]
	set jid $jid/$res
    }
    set opts {}
    if {[string length $desc]} {
	set opts [list -desc $desc]
    }
    set state(path) $localpath
    set state(tail) [file tail $localpath]
    set state(jid)  $jid
    eval {$jstate(jlib) oob_set $jid \
      [list [namespace current]::SetCallback $token] $url} $opts
}

# Jabber::OOB::SetCallback --
#
#       Callback for oob_set.
#
# Arguments:
#       jlibName:   the instance of this jlib.
#       type:       "error" or "ok".
#       thequery:   if type="error", this is a list {errcode errmsg},
#                   else it is the query element as a xml list structure.

proc ::Jabber::OOB::SetCallback {token jlibName type theQuery} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::OOB::SetCallback, type=$type,theQuery='$theQuery'"
    
    if {$type == "error"} {
	foreach {errcode errmsg} $theQuery break
	set msg "Got an error when trying to send a file: code was $errcode,\
	  and error message: $errmsg"
	tk_messageBox -icon error -type ok -title [::msgcat::mc Error] \
	  -message [FormatTextForMessageBox $msg]
    } else {
	tk_messageBox -icon info -type ok -title [::msgcat::mc {File Transfer}] \
	  -message [::msgcat::mc jamessoobok2 $state(tail) $state(jid)]
    }
    unset state
}

# Jabber::OOB::ParseSet --
#
#       Gets called when we get a 'jabber:iq:oob' 'set' element, that is,
#       another user sends us an url to fetch a file from.

proc ::Jabber::OOB::ParseSet {jlibname from subiq args} {
    
    variable locals
    
    array set argsArr $args
    
    # Be sure to trace any 'id' attribute for confirmation.
    if {[info exists argsArr(-id)]} {
	set id $argsArr(-id)
    } else {
	set id $locals(id)
	incr locals(id)
    }
    set desc [::msgcat::mc None]
    foreach child [wrapper::getchildren $subiq] {
	set tag  [wrapper::gettag $child]
	set $tag [wrapper::getcdata $child]
    }
    if {![info exists url]} {
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessoobnourl $from]]
	return
    }
    set tail [file tail [::Utils::GetFilePathFromUrl $url]]
    set ans [tk_messageBox -title [::msgcat::mc {Get File}] -icon info  \
      -type yesno -default yes -message [FormatTextForMessageBox \
      [::msgcat::mc jamessoobask $from $tail $desc]]]
    if {$ans == "no"} {
	return
    }
    
    # Validate URL, determine the server host and port.
    if {![regexp -nocase {^(([^:]*)://)?([^/:]+)(:([0-9]+))?(/.*)?$} $url \
      x prefix proto host y port path]} {
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessoobbad $from $url]]
	return
    }
    if {[string length $proto] == 0} {
	set proto http
    }
    if {$proto != "http"} {
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessoonnohttp $from $proto]]
	return
    }
    set localPath [tk_getSaveFile -title [::msgcat::mc {Save File}] \
      -initialfile $tail]
    if {[string length $localPath] == 0} {
	return
    }
    
    # And get it.
    ::Jabber::OOB::Get $from $url $localPath $id
}

proc ::Jabber::OOB::Get {jid url file id} {
    global  this prefs
    
    variable locals

    if {[catch {open $file w} out]} {
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok -message \
	  [FormatTextForMessageBox [::msgcat::mc jamessoobfailopen $file]]
	return
    }
    set locals($out,local) $file
    
    # Be sure to set translation correctly for this MIME type.
    set tmopts [list -timeout $prefs(timeoutMillis)]
    
    if {[catch {eval {
	::httpex::get $url -channel $out  \
	  -progress [list [namespace current]::Progress $out] \
	  -command  [list [namespace current]::HttpCmd $jid $out $id]
    } $tmopts} token]} {
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok -message \
	  [FormatTextForMessageBox [::msgcat::mc jamessoobgetfail $url $token]]
	return
    }
    upvar #0 $token state

    set str "[::msgcat::mc {Writing file}]: [file tail $file]"
    ::Utils::ProgressWindow $token 1000000 0 -text $str \
      -cancelcmd [list [namespace current]::Cancel $out $token]
}

proc ::Jabber::OOB::Progress {out token total current} {
    global  tcl_platform
    variable locals
    upvar #0 $token state
    
    # Investigate 'state' for any exceptions.
    set status [::httpex::status $token]
    
    if {[string equal $status "error"]} {
	set errmsg "[httpex::error $token]"
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok -message \
	  [FormatTextForMessageBox "Failed getting url: $errmsg"]
	::httpex::cleanup $token
	catch {file delete $locals($out,local)}
	::Utils::ProgressFree $token
    } else {
	::Utils::ProgressWindow $token $total $current
    }
}

# Jabber::OOB::HttpCmd --
# 
#       Callback for the httpex package.

proc ::Jabber::OOB::HttpCmd {jid out id token} {
    
    upvar #0 $token state
    set httpstate  [::httpex::state $token]
    set status [::httpex::status $token]

    # Don't bother with intermediate callbacks.
    if {![string equal $httpstate "final"]} {
	return
    }

    switch -- $status {
	timeout {
	    tk_messageBox -title [::msgcat::mc Timeout] -icon info -type ok \
	      -message [::msgcat::mc jamessoobtimeout]
	}
	error {
	    tk_messageBox -title "File transport error" -icon error -type ok \
	      -message "File transport error when getting file from $jid:\
	      [::httpex::error $token]"
	}
	eof {
	    tk_messageBox -title "File transport error" -icon error -type ok \
	      -message "The server with $jid closed the socket without replying."	   
	}
	reset {
	    # Did this ourself?
	}
    }
    catch {close $out}
    ::httpex::cleanup $token
    ::Utils::ProgressFree $token
    
    # We shall send an <iq result> element here using the same 'id' to notify
    # the sender we are done.

    switch -- $status {
	ok {
	    ::Jabber::JlibCmd send_iq "result" {} -to $jid -id $id
	} 
	default {
	    ::Jabber::JlibCmd send_iq "error" {} -to $jid -id $id
	}
    }
}

proc ::Jabber::OOB::Cancel {out token} {
    
    variable locals
    
    ::httpex::reset $token
    ::Utils::ProgressFree $token
    catch {file delete $locals($out,local)}
}

# Jabber::OOB::BuildText --
#
#       Make a clickable text widget from a <x xmlns='jabber:x:oob'> element.
#
# Arguments:
#       w           widget to create
#       xml         a xml list element <x xmlns='jabber:x:oob'>
#       args        -width
#       
# Results:
#       w

proc ::Jabber::OOB::BuildText {w xml args} {
    global  prefs

    if {[wrapper::gettag $xml] != "x"} {
	error {Not proper xml data here}
    }
    array set attr [wrapper::getattrlist $xml]
    if {![info exists attr(xmlns)]} {
	error {Not proper xml data here}
    }
    if {![string equal $attr(xmlns) "jabber:x:oob"]} {
	error {Not proper xml data here}
    }
    array set argsArr {
	-width     30
    }
    array set argsArr $args
    set nlines 1
    foreach c [wrapper::getchildren $xml] {
	switch -- [lindex $c 0] {
	    desc {
		set desc [lindex $c 3]
		set nlines [expr [string length $desc]/$argsArr(-width) + 1]
	    }
	    url {
		set url [lindex $c 3]
	    }
	}
    }
    
    set bg [option get . backgroundGeneral {}]
    
    text $w -bd 0 -wrap word -width $argsArr(-width)  \
      -background $bg -height $nlines  \
      -highlightthickness 0
    if {[info exists desc] && [info exists url]} {
	$w tag configure normal -foreground blue -underline 1
	$w tag configure active -foreground red -underline 1
	
	$w tag bind normal <Enter> [list ::Text::EnterLink $w %x %y normal active]
	$w tag bind active <ButtonPress>  \
	  [list ::Text::ButtonPressOnLink $w %x %y active]
	$w insert end $desc normal
    }
    return $w
}

#-------------------------------------------------------------------------------
