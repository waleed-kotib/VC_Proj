# SetupAss.tcl
#
#       Uses the wizard package to build a setup assistant for the
#       Coccinella. 
#
#  Copyright (c) 2001-2002  Mats Bengtsson
#  
# $Id: SetupAss.tcl,v 1.19 2004-01-27 08:48:06 matben Exp $

package require wizard
package require chasearrows
package require http 2.3
package require tinydom
package require tablelist

package provide SetupAss 1.0

namespace eval ::Jabber::SetupAss::  {

    variable server
    variable haveRegistered 0
    variable finished 0
    
    # Make the selected (first) server the default one.
    set profile [::Profiles::GetSelectedName]
    set spec [::Profiles::GetProfile $profile]
    set server [lindex $spec 0]
}

proc ::Jabber::SetupAss::SetupAss { } {
    global  this prefs wDlgs
    
    variable finished

    set w $wDlgs(setupass)
    if {[winfo exists $w]} {
	return
    }
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm title $w [::msgcat::mc {Setup Assistant}]
    
    set fontSB [option get . fontSmallBold {}]
    
    set ns [namespace current]
    set su $w.su
    wizard::wizard $su  \
      -closecommand [list [namespace current]::DoClose $w]   \
      -finishcommand [list [namespace current]::DoFinish $w]  \
      -nextpagecommand [list [namespace current]::NextPage $w]
    pack $su -expand 1 -fill both
    
    # Front page.
    set p1 [$su newpage "intro"   \
      -headtext [::msgcat::mc suheadtxt]]
    pack [frame $p1.fr] -padx 10 -pady 8 -side top -anchor w
    message $p1.fr.msg1 -width 260 -anchor w -text   \
      [::msgcat::mc suintro1]
    message $p1.fr.msg2 -width 260 -anchor w -text   \
      [::msgcat::mc suintro2]
    message $p1.fr.msg3 -width 260 -anchor w -text   \
      [::msgcat::mc suintro3]
    pack $p1.fr.msg1 $p1.fr.msg2 $p1.fr.msg3 -side top -anchor w -fill x -pady 4
    
    # Server.
    set p2 [$su newpage "server" -headtext [::msgcat::mc {Jabber Server}]]
    pack [frame $p2.fr] -padx 10 -pady 8 -side top -anchor w
    message $p2.fr.msg1 -width 260 -text   \
      [::msgcat::mc suservmsg]
    button $p2.fr.bt -text [::msgcat::mc Get] \
      -command [list [namespace current]::ServersDlg .jsuserv]
    message $p2.fr.msg2 -width 200 -text   \
      "Get list of public and open Jabber servers"
    label $p2.fr.la -font $fontSB -text "[::msgcat::mc Server]:"
    entry $p2.fr.serv -width 28 -textvariable ${ns}::server \
       -validate key -validatecommand {::Jabber::ValidateJIDChars %S}
    grid $p2.fr.msg1 -sticky n -columnspan 2 -row 0
    grid $p2.fr.bt -sticky ew -column 0 -row 1 -pady 4
    grid $p2.fr.msg2 -sticky w -column 1 -row 1
    grid $p2.fr.la -sticky e -column 0 -row 2
    grid $p2.fr.serv -sticky w -column 1 -row 2 -pady 4
    
    # Username & Password.
    set p3 [$su newpage "username" -headtext [::msgcat::mc {Username & Password}]]
    pack [frame $p3.fr] -padx 10 -pady 8 -side top -anchor w
    message $p3.fr.msg1 -width 260 -text   \
      [::msgcat::mc suusermsg]
    label $p3.fr.lan -font $fontSB -text "[::msgcat::mc Username]:"
    label $p3.fr.lap -font $fontSB -text "[::msgcat::mc Password]:"
    entry $p3.fr.name -width 28 -textvariable ${ns}::username \
       -validate key -validatecommand {::Jabber::ValidateJIDChars %S}
    entry $p3.fr.pass -width 28 -textvariable ${ns}::password \
       -validate key -validatecommand {::Jabber::ValidatePasswdChars %S}
    grid $p3.fr.msg1 -sticky n -columnspan 2
    grid $p3.fr.lan -sticky e -column 0 -row 1
    grid $p3.fr.name -sticky w -column 1 -row 1 -pady 4
    grid $p3.fr.lap -sticky e -column 0 -row 2
    grid $p3.fr.pass -sticky w -column 1 -row 2 -pady 4

    # Register?
    set p4 [$su newpage "register" -headtext [::msgcat::mc Register]]
    pack [frame $p4.fr] -padx 10 -pady 8 -side top -anchor w
    message $p4.fr.msg1 -width 260 -text   \
      [::msgcat::mc suregmsg]
    button $p4.fr.btreg -text "  [::msgcat::mc {Register Now}]... "  \
      -command [namespace current]::DoRegister
    grid $p4.fr.msg1 -sticky n
    grid $p4.fr.btreg -sticky e -pady 8

    # Finish.
    set p5 [$su newpage "fin" -headtext [::msgcat::mc Finished]]
    pack [frame $p5.fr] -padx 10 -pady 8 -side top -anchor w
    message $p5.fr.msg1 -width 260 -text   \
      [::msgcat::mc sufinmsg]
    label $p5.fr.piga -image [::Theme::GetImage ladybug]
    grid $p5.fr.msg1 -sticky n
    grid $p5.fr.piga -sticky w
    
    wm resizable $w 0 0
}

proc ::Jabber::SetupAss::NextPage {w page} {
    variable username
    variable password
    
    # Verify that it is ok before showing the next page.
    if {[string equal $page "username"]} {
	if {([string length $username] == 0) || ([string length $password] == 0)} {
	    tk_messageBox -icon error -title [::msgcat::mc {Empty Fields}] \
	      -message [::msgcat::mc messsuassfillin] -parent $w
	    return -code 3
	}
    }
}
    
proc ::Jabber::SetupAss::DoClose {w} {
    
    set ans [tk_messageBox -type yesno -parent $w -icon info \
      -message [FormatTextForMessageBox [::msgcat::mc messsuassclose]]]
    if {$ans == "yes"} {
	destroy $w
    }
}

proc ::Jabber::SetupAss::DoRegister { } {    
    variable server
    variable username
    variable password
    variable haveRegistered

    ::Jabber::Register::Register -server $server  \
      -username $username -password $password
    set haveRegistered 1
}

proc ::Jabber::SetupAss::DoFinish {w} {
    variable server
    variable username
    variable password
    variable finished
    variable haveRegistered
    
    if {!$haveRegistered} {
	
	# Save as a shortcut and default server only if not called 
	# ::Jabber::Register::Register which already done this
	::Profiles::Set {} $server $username $password home
    }
    set finished 1
    destroy $w
}

proc ::Jabber::SetupAss::ServersDlg {w} {
    global  this prefs

    variable server
    variable finishedServ 0
    variable warrows
    variable servStatVar
    variable wbservbt
    variable wtbl
    variable rowcurrent ""

    ::Jabber::Debug 2 "::Jabber::SetupAss::ServersDlg w=$w"
    
    if {[winfo exists $w]} {
	raise $w
	return
    }
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1
    wm title $w {Public Jabber Servers}
    
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
       
    # Button part.
    set wbservbt $w.frall.frbot.btok
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $wbservbt -text [::msgcat::mc Set] -default active \
      -state disabled -command [list [namespace current]::ServSet $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel]  \
      -command [list [namespace current]::ServCancel $w]] \
      -side right -padx 5 -pady 5
    pack $frbot -side bottom -fill both -padx 8 -pady 6
    
    # List of servers.
    pack [label $w.frall.topl -text "List of open Jabber servers:" -font $fontSB] \
      -side top -anchor w -padx 4 -pady 4
    set wtbfr $w.frall.wtbfr
    pack [frame $wtbfr -borderwidth 1 -relief sunken] -side top -fill both \
      -expand 1 -padx 4 -pady 4
    set wysc $wtbfr.ysc
    set wtbl $wtbfr.wtbl
    tablelist::tablelist $wtbl \
      -columns [list 16 Address 30 Name]  \
      -yscrollcommand [list $wysc set] -stretch all \
      -width 70 -height 16
    scrollbar $wysc -orient vertical -command [list $wtbl yview]
    grid $wtbl $wysc -sticky news
    grid columnconfigure $wtbfr 0 -weight 1
    grid rowconfigure $wtbfr 0 -weight 1

    # Chasing arrows and status message.
    pack [frame $w.frall.frarr] -side top -anchor w -padx 4 -pady 0
    set warrows $w.frall.frarr.arr
    pack [::chasearrows::chasearrows $warrows -size 16] \
      -side left -padx 5 -pady 5
    pack [label $w.frall.frarr.msg  \
      -textvariable [namespace current]::servStatVar] -side left -padx 4
    set servStatVar ""

    bind $w <Return> {}
    bind $wtbl <<ListboxSelect>> [list [namespace current]::ServSelect]
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    catch {grab $w}
    
    # HTTP get xml list of servers.
    set url $::Jabber::jprefs(urlServersList)
    if {0 && [string equal $this(platform) "macintosh"]} {
	set tmopts ""
    } else {
	set tmopts [list -timeout $prefs(timeoutMillis)]
    }
    if {[catch {eval {
	::httpex::get $url -progress [namespace current]::ServProgress  \
	  -command [list [namespace current]::ServCommand $w]
    } $tmopts} token]} {
	destroy $w
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok  \
	  -message "Failed to obtain list of open Jabber servers from\
	  \"$url\": $token"
	return
    } else {
	set servStatVar "Getting server list from $url"
	$warrows start
    }
    upvar #0 $token state
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {grab release $w}
    catch {focus $oldFocus}
    if {$finishedServ} {
	if {$rowcurrent != ""} {
	    set server [lindex $rowcurrent 0]
	}
    }
}

proc ::Jabber::SetupAss::ServSet {w} {
    variable finishedServ

    set finishedServ 1
    destroy $w
}

proc ::Jabber::SetupAss::ServCancel {w} {
    variable finishedServ

    set finishedServ 0
    destroy $w
}

proc ::Jabber::SetupAss::ServSelect { } {
    variable wbservbt
    variable rowcurrent
    variable wtbl

    $wbservbt configure -state normal
    set ind [$wtbl curselection]
    if {$ind != ""} {
	set rowcurrent [$wtbl get $ind]
    }
}

proc ::Jabber::SetupAss::ServProgress {token total current} {
       
    # Empty.
}

proc ::Jabber::SetupAss::ServCommand {w token} {
    upvar #0 $token state
    upvar ::Jabber::jstate jstate
    variable warrows
    variable servStatVar
    variable publicServerList
    variable wtbl

    ::Jabber::Debug 2 "::Jabber::SetupAss::ServCommand [::httpex::state $token]"
    
    if {![winfo exists $w]} {
	return
    }
    if {[::httpex::state $token] != "final"} {
	return
    }
    set servStatVar ""
    $warrows stop
    
    # Investigate 'state' for any exceptions.
    set status [::httpex::status $token]
    
    ::Jabber::Debug 2 "\ttoken=$token status=$status"
    
    switch -- $status {
	timeout {
	    tk_messageBox -title [::msgcat::mc Timeout] -icon info -type ok \
	      -message "Timeout while waiting for response."
	}
	error {
	    tk_messageBox -title "File transport error" -icon error -type ok \
	      -message "File transport error when getting server list:\
	      [::httpex::error $token]"
	}
	eof {
	    tk_messageBox -title "File transport error" -icon error -type ok \
	      -message "The server closed the socket without replying."	   
	}
	reset {
	    # Did this ourself?
	}
	ok {
	    
	    # Get and parse xml.
	    set xml [::httpex::data $token]    
	    set token [tinydom::parse $xml]
	    set xmllist [tinydom::documentElement $token]
	    set publicServerList {}
	    
	    foreach elem [tinydom::children $xmllist] {
		switch -- [tinydom::tagname $elem] {
		    item {
			catch {unset attrArr}
			array set attrArr [tinydom::attrlist $elem]
			lappend publicServerList  \
			  [list $attrArr(jid) $attrArr(name)]
		    }
		}
	    }

	    $wtbl insertlist end $publicServerList
	}
    }
    ::httpex::cleanup $token
    if {$status != "ok"} {
	catch {destroy $w}
    }
}

# This is for the standard http package.
# 
# ABONDENED !!!!!!!!!

proc ::Jabber::SetupAss::ServCommandStdHttp {w token} {
    upvar #0 $token state
    upvar ::Jabber::jstate jstate
    variable warrows
    variable servStatVar
    variable publicServerList
    variable wtbl

    ::Jabber::Debug 2 "::Jabber::SetupAss::ServCommand"
    
    if {![winfo exists $w]} {
	return
    }
    set servStatVar ""
    $warrows stop
    
    # Investigate 'state' for any exceptions.
    set status [::http::status $token]
    
    ::Jabber::Debug 2 "\ttoken=$token status=$status"
    
    switch -- $status {
	timeout {
	    tk_messageBox -title [::msgcat::mc Timeout] -icon info -type ok \
	      -message "Timeout while waiting for response."
	}
	error {
	    tk_messageBox -title "File transport error" -icon error -type ok \
	      -message "File transport error when getting server list:\
	      [::httpex::error $token]"
	}
	eof {
	    tk_messageBox -title "File transport error" -icon error -type ok \
	      -message "The server closed the socket without replying."	   
	}
	reset {
	    # Did this ourself?
	}
	ok {
	    
	    # Get and parse xml.
	    set xml [::http::data $token]    
	    set token [tinydom::parse $xml]
	    set xmllist [tinydom::documentElement $token]
	    set publicServerList {}
	    
	    foreach elem [tinydom::children $xmllist] {
		switch -- [tinydom::tagname $elem] {
		    item {
			catch {unset attrArr}
			array set attrArr [tinydom::attrlist $elem]
			lappend publicServerList  \
			  [list $attrArr(jid) $attrArr(name)]
		    }
		}
	    }

	    $wtbl insertlist end $publicServerList
	}
    }
    ::http::cleanup $token
    if {$status != "ok"} {
	catch {destroy $w}
    }
}

#-------------------------------------------------------------------------------
