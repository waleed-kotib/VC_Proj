# SetupAss.tcl
#
#       Uses the setupassistant package to build a setup assistant for the
#       Coccinella. 
#
#  Copyright (c) 2001-2002  Mats Bengtsson
#  
# $Id: SetupAss.tcl,v 1.1.1.1 2002-12-08 11:00:59 matben Exp $

package require setupassistant
package provide SetupAss 1.0

namespace eval ::SetupAss::  {

    variable server
    variable haveRegistered 0
    variable finished 0
    
    # Make the selected (first) server the default one.
    set profile $::Jabber::jserver(profile,selected)
    array set profArr $::Jabber::jserver(profile)
    set server [lindex $profArr($profile) 0]
}

proc ::SetupAss::SetupAss {w} {
    global  this sysFont prefs
    
    upvar ::UI::icons icons
    variable finished

    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {
	#
    }
    wm title $w [::msgcat::mc {Setup Assistant}]
    
    set ns [namespace current]
    set su $w.su
    setupassistant::setupassistant $su -background $prefs(bgColGeneral)  \
      -closecommand [list ::SetupAss::DoClose $w]   \
      -finishcommand [list ::SetupAss::DoFinish $w]  \
      -nextpagecommand [list ::SetupAss::NextPage $w]
    pack $su -expand 1 -fill both
    
    # First page.
    set p1 [$su newpage "intro" -background $prefs(bgColGeneral)   \
      -headtext [::msgcat::mc suheadtxt]]
    pack [frame $p1.fr] -padx 10 -pady 8 -side top -anchor w
    message $p1.fr.msg1 -width 260 -font $sysFont(s) -anchor w -text   \
      [::msgcat::mc suintro1]
    message $p1.fr.msg2 -width 260 -font $sysFont(s) -anchor w -text   \
      [::msgcat::mc suintro2]
    message $p1.fr.msg3 -width 260 -font $sysFont(s) -anchor w -text   \
      [::msgcat::mc suintro3]
    pack $p1.fr.msg1 $p1.fr.msg2 $p1.fr.msg3 -side top -anchor w -fill x -pady 4
    
    # Server.
    set p2 [$su newpage "server" -headtext [::msgcat::mc {Jabber Server}]]
    pack [frame $p2.fr] -padx 10 -pady 8 -side top -anchor w
    message $p2.fr.msg1 -width 260 -font $sysFont(s) -text   \
      [::msgcat::mc suservmsg]
    label $p2.fr.la -font $sysFont(sb) -text "[::msgcat::mc Server]:"
    entry $p2.fr.serv -width 28 -textvariable ${ns}::server \
       -validate key -validatecommand {::Jabber::ValidateJIDChars %S}
    grid $p2.fr.msg1 -sticky n -columnspan 2 -row 0
    grid $p2.fr.la -sticky e -column 0 -row 1
    grid $p2.fr.serv -sticky w -column 1 -row 1 -pady 4
    
    # Username & Password.
    set p3 [$su newpage "username" -headtext [::msgcat::mc {Username & Password}]]
    pack [frame $p3.fr] -padx 10 -pady 8 -side top -anchor w
    message $p3.fr.msg1 -width 260 -font $sysFont(s) -text   \
      [::msgcat::mc suusermsg]
    label $p3.fr.lan -font $sysFont(sb) -text "[::msgcat::mc Username]:"
    label $p3.fr.lap -font $sysFont(sb) -text "[::msgcat::mc Password]:"
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
    message $p4.fr.msg1 -width 260 -font $sysFont(s) -text   \
      [::msgcat::mc suregmsg]
    button $p4.fr.btreg -text "  [::msgcat::mc {Register Now}]... "  \
      -command ::SetupAss::DoRegister
    grid $p4.fr.msg1 -sticky n
    grid $p4.fr.btreg -sticky e -pady 8

    # Finish.
    set p5 [$su newpage "fin" -headtext [::msgcat::mc Finished]]
    pack [frame $p5.fr] -padx 10 -pady 8 -side top -anchor w
    message $p5.fr.msg1 -width 260 -font $sysFont(s) -text   \
      [::msgcat::mc sufinmsg]
    label $p5.fr.piga -image $icons(igelpiga)    
    grid $p5.fr.msg1 -sticky n
    grid $p5.fr.piga -sticky w
    
    wm resizable $w 0 0
}

proc ::SetupAss::NextPage {w page} {

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
    
proc ::SetupAss::DoClose {w} {
    
    set ans [tk_messageBox -type yesno -parent $w -icon info \
      -message [FormatTextForMessageBox [::msgcat::mc messsuassclose]]]
    if {$ans == "yes"} {
	destroy $w
    }
}

proc ::SetupAss::DoRegister { } {
    
    variable server
    variable username
    variable password
    variable haveRegistered

    ::Jabber::Register::Register .jreg -server $server  \
      -username $username -password $password
    set haveRegistered 1
}

proc ::SetupAss::DoFinish {w} {

    variable server
    variable username
    variable password
    variable finished
    variable haveRegistered
    
    if {!$haveRegistered} {
	
	# Save as a shortcut and default server only if not called 
	# ::Jabber::Register::Register which already done this
	::Jabber::SetServerShortcut {} $server $username $password home
    }
    set finished 1
    destroy $w
}

#-------------------------------------------------------------------------------
