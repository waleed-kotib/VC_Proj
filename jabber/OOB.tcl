#  OOB.tcl ---
#  
#      This file is part of the whiteboard application. 
#      It implements the UI of the jabber:iq:oob part of the jabber.
#      
#  Copyright (c) 2001-2002  Mats Bengtsson
#  
# $Id: OOB.tcl,v 1.5 2003-07-26 13:54:23 matben Exp $

package provide OOB 1.0

namespace eval ::Jabber::OOB:: {

    variable locals
    set locals(initialLocalDir) [pwd]
    set locals(id) 1000
}

# Jabber::OOB::BuildSet --
#
#       Dialog for sending a 'jabber:iq:oob' 'set' element.

proc ::Jabber::OOB::BuildSet {w jid} {
    global  this sysFont
    
    variable finished
    variable localpath ""
    variable desc ""
    variable locals
    
    if {[winfo exists $w]} {
	return
    }
    set finished -1
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w {Send File}
    set locals(jid) $jid
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]  \
      -fill both -expand 1 -ipadx 12 -ipady 4
    
    message $w.frall.msg -width 260 -font $sysFont(s) -text  \
      "Let user \"$jid\" download a file from your built in server.\
      The description is optional."
    pack $w.frall.msg -side top -fill both -expand 1
    
    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    label $frmid.lfile -text {File:} -font $sysFont(sb) -anchor e
    entry $frmid.efile    \
      -textvariable "[namespace current]::localpath"
    button $frmid.btfile -text {File...} -width 6 -font $sysFont(s)  \
      -command ::Jabber::OOB::FileOpen
    label $frmid.ldesc -text {Description:} -font $sysFont(sb) -anchor e
    entry $frmid.edesc -width 36    \
      -textvariable "[namespace current]::desc"
    grid $frmid.lfile -column 0 -row 0 -sticky e
    grid $frmid.efile -column 1 -row 0 -sticky ew
    grid $frmid.btfile -column 2 -row 0 
    grid $frmid.ldesc -column 0 -row 1 -sticky e
    grid $frmid.edesc -column 1 -row 1 -sticky ew -columnspan 2
    pack $frmid -side top -fill both -expand 1

    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btsnd -text [::msgcat::mc Send] -width 8 -default active \
      -command "::Jabber::OOB::DoSend"]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8   \
      -command "set [namespace current]::finished 2"]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> ::Jabber::OOB::DoSend
    
    # Grab and focus.
    focus $w
    catch {grab $w}
    
    # Wait here for a button press.
    tkwait variable [namespace current]::finished
    
    catch {grab release $w}
    catch {destroy $w}    
}

proc ::Jabber::OOB::FileOpen { } {
    
    variable localpath
    variable locals

    set ans [tk_getOpenFile -title [::msgcat::mc {Pick File}]  \
      -initialdir $locals(initialLocalDir)]
    if {[string length $ans]} {
	set localpath $ans
	set locals(initialLocalDir) [file dirname $ans]
    }
}

proc ::Jabber::OOB::DoSend { } {
    global  prefs
    
    variable finished
    variable localpath
    variable desc
    variable locals
    upvar ::Jabber::jstate jstate

    set finished 1
    
    # For now we build a relative path for the url. uri encode it!
    #set relpath [GetRelativePath $prefs(httpdRootDir) $localpath]
    set relpath [filerelative $prefs(httpdRootDir) $localpath]
    set ip [::Network::GetThisOutsideIPAddress]
    set url "http://${ip}:$prefs(httpdPort)/$relpath"
    set url [uriencode::quoteurl $url]
    
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
    eval {$jstate(jlib) oob_set $jid ::Jabber::OOB::SetCallback $url} $opts
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

proc ::Jabber::OOB::SetCallback {jlibName type theQuery} {
    
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::OOB::SetCallback, type=$type,theQuery='$theQuery'"
    
    if {$type == "error"} {
	foreach {errcode errmsg} $theQuery {}
	set msg "Got an error when trying to send a file: code was $errcode,\
	  and error message: $errmsg"
	tk_messageBox -icon error -type ok -title [::msgcat::mc Error] \
	  -message [FormatTextForMessageBox $msg]
    } else {
	tk_messageBox -icon info -type ok -title [::msgcat::mc {File Transfer}] \
	  -message [::msgcat::mc jamessoobok]
    }
}

# Jabber::OOB::ParseSet --
#
#       Gets called when we get a 'jabber:iq:oob' 'set' element, that is,
#       another user sends us an url to fetch a file from.

proc ::Jabber::OOB::ParseSet {from subiq args} {
    
    variable locals
    
    array set argsArr $args
    
    # Be sure to trace any 'id' attribute for confirmation.
    if {[info exists argsArr(-id)]} {
	set id $argsArr(-id)
    } else {
	set id $locals(id)
	incr locals(id)
    }
    set desc {}
    foreach child [lindex $subiq 4] {
	set tag [lindex $child 0]
	set $tag [lindex $child 3]
    }
    if {![info exists url]} {
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessoobnourl $from]]
	return
    }
    set ans [tk_messageBox -title [::msgcat::mc {Get File}] -icon info  \
      -type yesno -default yes -message [FormatTextForMessageBox \
      [::msgcat::mc jamessoobask $from $url $desc]]]
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
    set tail [file tail [string trimleft $path /]]
    set localPath [tk_getSaveFile -title [::msgcat::mc {Save File}] -initialfile $tail]
    if {[string length $localPath] == 0} {
	return
    }
    
    # And get it.
    ::Jabber::OOB::Copy $from $url $localPath $id
}

proc ::Jabber::OOB::Copy {jid url file id} {
    global  this
    
    variable locals

    if {[catch {open $file w} out]} {
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok -message \
	  [FormatTextForMessageBox [::msgcat::mc jamessoobfailopen $file]]
	return
    }
    set locals($out,local) $file
    if {[string equal $this(platform) "macintosh"]} {
	set tmopts ""
    } else {
	set tmopts [list -timeout 40000]
    }
    
    # Be sure to set translation correctly for this MIME type.
    # Should be auto detected by ::http::geturl!
    set progCB [list ::Jabber::OOB::Progress $out]
    set commandCB [list ::Jabber::OOB::Finished $jid $out $id]
    
    if {[catch {eval {
	::http::geturl $url -channel $out -progress $progCB -command $commandCB
    } $tmopts} token]} {
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok -message \
	  [FormatTextForMessageBox [::msgcat::mc jamessoobgetfail $url $token]]
	return
    }
    upvar #0 $token state

    # Handle URL redirects
    foreach {name value} $state(meta) {
        if {[regexp -nocase ^location$ $name]} {
            return [::Jabber::OOB::Copy $jid [string trim $value] $file $id]
        }
    }
    set wprog .joob$out
    set cancelCB [list ::Jabber::OOB::Cancel $out $token]
    ::ProgressWindow::ProgressWindow $wprog -filename [file tail $file]  \
      -text2 "[::msgcat::mc From]: $url" -cancelcmd $cancelCB
    update idletasks
}

proc ::Jabber::OOB::Progress {out token total current} {
    
    variable locals
    upvar ::Jabber::jstate jstate
    upvar #0 $token state
    
    set wprog .joob$out
    if {$jstate(debug) > 1} {
	if {$current < 10000} {
	    foreach {name value} $state(meta) {
		puts [format "%-*s %s" 20 $name $value]
	    }
	}
    }
    $wprog configure -percent [expr 100.0 * $current/($total + 1.0)]

    # Investigate 'state' for any exceptions.
    if {[::http::status $token] == "error"} {
	# some 2.3 versions seem to lack ::http::error !
	if {[info exists state(error)]} {
	    set errmsg $state(error)
	} else {
	    set errmsg "File transfer error"
	}
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok -message \
	  [FormatTextForMessageBox "Failed getting url: $errmsg"]
	::http::reset $token
	catch {file delete $locals($out,local)}
    }
}

# Jabber::OOB::Finished --
# 
#       Callback for the http package. Gets called when finished,
#       timeout, or reset. 

proc ::Jabber::OOB::Finished {jid out id token} {
    
    upvar #0 $token state
    upvar ::Jabber::jstate jstate

    # Investigate 'state' for any exceptions.
    set status [::http::status $token]
    switch -- $status {
	timeout {
	    tk_messageBox -title [::msgcat::mc Timeout] -icon info -type ok \
	      -message [::msgcat::mc jamessoobtimeout]
	}
	error {
	    tk_messageBox -title "File transport error" -icon error -type ok \
	      -message "File transport error when getting file from $jid:\
	      [::http::error $token]"
	}
	eof {
	    tk_messageBox -title "File transport error" -icon error -type ok \
	      -message "The server with $jid closed the socket without replying."	   
	}
	reset {
	    # Did this ourself?
	}
    }
    set wprog .joob$out
    catch {destroy $wprog}
    catch {close $out}
    ::http::cleanup $token
    
    # We shall send an <iq result> element here using the same 'id' to notify
    # the sender we are done.
    $jstate(jlib) send_iq "result" {} -to $jid -id $id
}

proc ::Jabber::OOB::Cancel {out token} {
    
    variable locals
    ::http::reset $token
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
    global  sysFont prefs

    if {[lindex $xml 0] != "x"} {
	error {Not proper xml data here}
    }
    array set attr [lindex $xml 1]
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
    text $w -font $sysFont(s) -bd 0 -wrap word -width $argsArr(-width)  \
      -background $prefs(bgColGeneral) -height $nlines  \
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
