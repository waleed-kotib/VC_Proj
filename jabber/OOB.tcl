#  OOB.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the UI of the jabber:iq:oob part of the jabber.
#      
#  Copyright (c) 2001-2004  Mats Bengtsson
#  
# $Id: OOB.tcl,v 1.46 2004-12-13 13:39:18 matben Exp $

package require uriencode

package provide OOB 1.0

namespace eval ::OOB:: {

    ::hooks::register initHook            ::OOB::InitHook    
    ::hooks::register jabberInitHook      ::OOB::InitJabberHook

    variable locals
    set locals(initialLocalDir) [pwd]
    set locals(id) 1000

    # Running number for token.
    variable uid 0
}

proc ::OOB::InitHook { } {
    variable locals
    
    ::Debug 2 "::OOB::InitHook"
    
    # Drag and Drop support...
    set locals(haveTkDnD) 0
    if {![catch {package require tkdnd}]} {
	set locals(haveTkDnD) 1
    }       
}

proc ::OOB::InitJabberHook {jlibname} {
    upvar ::Jabber::jstate jstate
    
    # Be sure to handle incoming requestes (iq set elements).
    $jstate(jlib) iq_register set jabber:iq:oob     ::OOB::ParseSet
}

# OOB::BuildSet --
#
#       Dialog for sending a 'jabber:iq:oob' 'set' element.
#       
# Arguments:
#       jid         a full 3-tier jid

proc ::OOB::BuildSet {jid} {
    global  this wDlgs
    
    variable finished
    variable localpath ""
    variable desc ""
    variable locals
    
    set localpath [FileOpen]
    if {$localpath == ""} {
	return
    }
    
    set w $wDlgs(joobs)
    if {[winfo exists $w]} {
	return
    }
    set finished -1
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm title $w [mc {Send File}]
    set locals(jid) $jid
    set fontS [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 12 -ipady 4
    
    message $w.frall.msg -width 300 -text [mc oobmsg $jid]
    pack $w.frall.msg -side top -fill both -expand 1
    
    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    label $frmid.lfile -text "[mc {File}]:" -font $fontSB -anchor e
    entry $frmid.efile    \
      -textvariable [namespace current]::localpath
    button $frmid.btfile -text "[mc {File}]..." -width 6 -font $fontS  \
      -command [namespace current]::FileOpenCmd
    label $frmid.ldesc -text "[mc {Description}]:" -font $fontSB -anchor e
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
    pack [button $frbot.btok -text [mc Send] -default active \
      -command [namespace current]::DoSend]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel]  \
      -command "set [namespace current]::finished 2"]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> ::OOB::DoSend
    if {$locals(haveTkDnD)} {
	update
	::OOB::InitDnD $frmid.efile
    }
    
    # Grab and focus.
    focus $w
    catch {grab $w}
    
    # Wait here for a button press.
    tkwait variable [namespace current]::finished
    
    catch {grab release $w}
    catch {destroy $w}    
}

proc ::OOB::InitDnD {win} {
    
    dnd bindtarget $win text/uri-list <Drop>      \
      [list [namespace current]::DnDDrop %W %D %T]   
    dnd bindtarget $win text/uri-list <DragEnter> \
      [list [namespace current]::DnDEnter %W %A %D %T]   
    dnd bindtarget $win text/uri-list <DragLeave> \
      [list [namespace current]::DnDLeave %W %D %T]       
}

proc ::OOB::DnDDrop {w data type} {
    global  prefs
    
    variable localpath
    ::Debug 2 "::OOB::DnDDrop data=$data, type=$type"

    # Take only first file.
    set f [lindex $data 0]
	
    # Strip off any file:// prefix.
    set f [string map {file:// ""} $f]
    set f [uriencode::decodefile $f]
    set localpath $f
}

proc ::OOB::DnDEnter {w action data type} {
    
    ::Debug 2 "::OOB::DnDEnter action=$action, data=$data, type=$type"

    focus $w
    set act "none"
    return $act
}

proc ::OOB::DnDLeave {w data type} {
    
    focus [winfo toplevel $w] 
}

proc ::OOB::FileOpenCmd { } {
    
    variable localpath
    
    set ans [FileOpen]
    if {$ans != ""} {
	set localpath $ans
    }
}

proc ::OOB::FileOpen { } {
    
    variable locals

    set opts {}
    if {[file isdirectory $locals(initialLocalDir)]} {
	set opts [list -initialdir $locals(initialLocalDir)]
    }
    set ans [eval {tk_getOpenFile -title [mc {Pick File}]} $opts]
    if {[string length $ans]} {
	set locals(initialLocalDir) [file dirname $ans]
    }
    return $ans
}

proc ::OOB::DoSend { } {
    global  prefs wDlgs this
    
    variable finished
    variable localpath
    variable desc
    variable locals
    variable uid
    upvar ::Jabber::jstate jstate
    
    if {$localpath == ""} {
	::UI::MessageBox -type ok -title [mc {Pick File}] -message \
	  "You must provide a file to send" -parent $wDlgs(joobs)
	return
    }
    if {![file exists $localpath]} {
	::UI::MessageBox -type ok -title [mc {Pick File}]  \
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

# OOB::SetCallback --
#
#       Callback for oob_set.
#
# Arguments:
#       jlibName:   the instance of this jlib.
#       type:       "error" or "result".
#       thequery:   if type="error", this is a list {errcode errmsg},
#                   else it is the query element as a xml list structure.

proc ::OOB::SetCallback {token jlibName type theQuery} {
    variable $token
    upvar 0 $token state
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::OOB::SetCallback, type=$type,theQuery='$theQuery'"
    
    if {$type == "error"} {
	foreach {errcode errmsg} $theQuery break
	set msg "Got an error when trying to send a file: code was $errcode,\
	  and error message: $errmsg"
	::UI::MessageBox -icon error -type ok -title [mc Error] \
	  -message $msg
    } else {
	::UI::MessageBox -icon info -type ok -title [mc {File Transfer}] \
	  -message [mc jamessoobok2 $state(tail) $state(jid)]
    }
    unset state
}

# OOB::ParseSet --
#
#       Gets called when we get a 'jabber:iq:oob' 'set' element, that is,
#       another user sends us an url to fetch a file from.

proc ::OOB::ParseSet {jlibname from subiq args} {
    global  prefs
    variable locals
    
    eval {::hooks::run oobSetRequestHook $from $subiq} $args
    
    array set argsArr $args
    set ishandled 0
    
    # Be sure to trace any 'id' attribute for confirmation.
    if {[info exists argsArr(-id)]} {
	set id $argsArr(-id)
    } else {
	set id $locals(id)
	incr locals(id)
    }
    set desc [mc None]
    foreach child [wrapper::getchildren $subiq] {
	set tag  [wrapper::gettag $child]
	set $tag [wrapper::getcdata $child]
    }
    if {![info exists url]} {
	::UI::MessageBox -title [mc Error] -icon error -type ok \
	  -message [mc jamessoobnourl $from]
	return $ishandled
    }
    set tail [file tail [::Utils::GetFilePathFromUrl $url]]
    set tailDec [uriencode::decodefile $tail]
    set ans [::UI::MessageBox -title [mc {Get File}] -icon info  \
      -type yesno -default yes -message [mc jamessoobask $from $tailDec $desc]]
    if {$ans == "no"} {	
	ReturnError $from $id $subiq 406
	return $ishandled
    }
    
    # Validate URL, determine the server host and port.
    if {![regexp -nocase {^(([^:]*)://)?([^/:]+)(:([0-9]+))?(/.*)?$} $url \
      x prefix proto host y port path]} {
	::UI::MessageBox -title [mc Error] -icon error -type ok \
	  -message [mc jamessoobbad $from $url]
	return $ishandled
    }
    if {[string length $proto] == 0} {
	set proto http
    }
    if {$proto != "http"} {
	::UI::MessageBox -title [mc Error] -icon error -type ok \
	  -message [mc jamessoonnohttp $from $proto]
	return $ishandled
    }
    set userDir [::Utils::GetDirIfExist $prefs(userPath)]
    set localPath [tk_getSaveFile -title [mc {Save File}] \
      -initialfile $tailDec -initialdir $userDir]
    if {$localPath == ""} {
	return $ishandled
    }
    set prefs(userPath) [file dirname $localPath]

    # And get it.
    Get $from $url $localPath $id $subiq
    set ishandled 1
    return $ishandled
}

proc ::OOB::Get {jid url file id subiq} {
    
    set token [::HttpTrpt::Get $url $file -command \
      [list ::OOB::HttpCmd $jid $id $subiq]]
}

proc ::OOB::HttpCmd {jid id subiq token status {errmsg ""}} {
    variable $token
    upvar 0 $token state
    
    ::Debug 2 "::OOB::HttpCmd status=$status, errmsg=$errmsg"
    
    # We shall send an <iq result> element here using the same 'id' to notify
    # the sender we are done.

    switch -- $status {
	ok {
	    ::Jabber::JlibCmd send_iq "result" {} -to $jid -id $id
	}
	reset {
	    ReturnError $jid $id $subiq 406
	}
	default {
	    set httptoken $state(httptoken)
	    set ncode [::httpex::ncode $httptoken]
	    ReturnError $jid $id $subiq $ncode
	}
    }   
}

proc ::OOB::ReturnError {jid id subiq ncode} {
    
    switch -- $ncode {
	406 {
	    set type modify
	    set tag  "not-acceptable"
	}
	default {
	    set type cancel
	    set tag  "not-found"
	}
    }
    
    set subElem [wrapper::createtag $tag -attrlist \
      [list xmlns "urn:ietf:params:xml:ns:xmpp-stanzas"]]
    set errElem [wrapper::createtag "error" -attrlist \
      [list code $ncode type modify] -subtags [list $subElem]]
    
    ::Jabber::JlibCmd send_iq "error" [list $subiq $errElem] -to $jid -id $id
}

# OOB::BuildText --
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

proc ::OOB::BuildText {w xml args} {
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
	switch -- [wrapper::gettag $c] {
	    desc {
		set desc [wrapper::getcdata $c]
		set nlines [expr [string length $desc]/$argsArr(-width) + 1]
	    }
	    url {
		set url [wrapper::getcdata $c]
	    }
	}
    }
    
    set bg [option get . backgroundGeneral {}]
    
    text $w -bd 0 -wrap word -width $argsArr(-width)  \
      -background $bg -height $nlines  \
      -highlightthickness 0
    if {[info exists desc] && [info exists url]} {
	::Text::InsertURL $w $desc $url {}
    }
    return $w
}

#-------------------------------------------------------------------------------
