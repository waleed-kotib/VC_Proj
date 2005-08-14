# SetupAss.tcl
#
#       Uses the wizard package to build a setup assistant for the
#       Coccinella. 
#
#  Copyright (c) 2001-2005  Mats Bengtsson
#  
# $Id: SetupAss.tcl,v 1.30 2005-08-14 07:10:51 matben Exp $

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
    variable locale
    variable username  ""
    variable password  ""
    variable password2 ""

    set w $wDlgs(setupass)
    if {[winfo exists $w]} {
	return
    }
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm title $w [::msgcat::mc {Setup Assistant}]
    
    set ns [namespace current]
    set su $w.su
    wizard::wizard $su  \
      -closecommand [list [namespace current]::DoClose $w]   \
      -finishcommand [list [namespace current]::DoFinish $w]  \
      -nextpagecommand [list [namespace current]::NextPage $w]
    pack $su -expand 1 -fill both
    
    set wrapthese {}
    
    # Front page.
    set p1 [$su newpage "intro" -headtext [mc suheadtxt]]
    ttk::frame $p1.fr -padding [option get . notebookPagePadding {}]
    ttk::label $p1.fr.msg1 -style Small.TLabel \
      -wraplength 260 -justify left -anchor w -text [mc suintro1]
    ttk::label $p1.fr.msg2 -style Small.TLabel \
      -wraplength 260 -justify left -anchor w -text [mc suintro2]
    ttk::label $p1.fr.msg3 -style Small.TLabel \
      -wraplength 260 -justify left -anchor w -text [mc suintro3]
    
    pack $p1.fr.msg1 $p1.fr.msg2 $p1.fr.msg3 -side top -anchor w -fill x -pady 4
    pack $p1.fr -side top -fill x
    
    lappend wrapthese $p1.fr.msg1 $p1.fr.msg2 $p1.fr.msg3
    
    # Language catalog.
    set plang [$su newpage "language" -headtext [mc Language]]
    ttk::frame $plang.fr -padding [option get . notebookPagePadding {}]
    ttk::label $plang.fr.msg1 -style Small.TLabel \
      -wraplength 260 -justify left -text [mc sulang]

    set langs {}
    foreach f [glob -nocomplain -tails -directory $this(msgcatPath) *.msg] {
	lappend langs [file rootname $f]
    }
    eval {ttk::optionmenu $plang.fr.pop [namespace current]::locale} $langs
    if {$prefs(messageLocale) == ""} {
	set locale [lindex [split [::msgcat::mclocale] _] 0]
    } else {
	set locale $prefs(messageLocale)
    }
    ttk::button $plang.fr.def -text [mc Default] -command \
      [namespace current]::DefaultLang
    
    pack  $plang.fr.msg1  -side top -anchor w -pady 4
    pack  $plang.fr.pop   -side top -anchor w -pady 4
    pack  $plang.fr.def   -side top -anchor w -pady 4
    pack  $plang.fr       -side top -fill x
    
    lappend wrapthese $plang.fr.msg1
    
    # Server.
    set p2 [$su newpage "server" -headtext [mc {Jabber Server}]]
    ttk::frame $p2.fr -padding [option get . notebookPagePadding {}]
    ttk::label $p2.fr.msg1 -style Small.TLabel \
      -wraplength 260 -justify left -text [mc suservmsg]
    ttk::button $p2.fr.bt -text [mc Get] \
      -command [list [namespace current]::ServersDlg .jsuserv]
    ttk::label $p2.fr.msg2 -style Small.TLabel \
      -wraplength 260 -justify left -text "Get list of public and open Jabber servers"
    ttk::label $p2.fr.la -text "[mc Server]:"
    ttk::entry $p2.fr.serv -width 28 -textvariable ${ns}::server \
      -validate key -validatecommand {::Jabber::ValidateDomainStr %S}
    
    grid  $p2.fr.msg1  -            -sticky nw -pady 4
    grid  $p2.fr.bt    $p2.fr.msg2  -sticky ew -pady 4
    grid  $p2.fr.la    $p2.fr.serv  -sticky e -pady 4
    pack  $p2.fr -side top -fill x

    lappend wrapthese $p2.fr.msg1

    # Username & Password.
    set p3 [$su newpage "username" -headtext [mc {Username & Password}]]
    ttk::frame $p3.fr -padding [option get . notebookPagePadding {}]
    ttk::label $p3.fr.msg1 -style Small.TLabel \
      -wraplength 260 -justify left -text [mc suusermsg]
    ttk::label $p3.fr.lan  -text "[mc Username]:"
    ttk::label $p3.fr.lap  -text "[mc Password]:"
    ttk::label $p3.fr.lap2 -text "[mc {Retype password}]:"
    ttk::entry $p3.fr.name -textvariable ${ns}::username \
       -validate key -validatecommand {::Jabber::ValidateUsernameStr %S}
    ttk::entry $p3.fr.pass -textvariable ${ns}::password -show {*} \
      -validate key -validatecommand {::Jabber::ValidatePasswordStr %S}
    ttk::entry $p3.fr.pass2 -textvariable ${ns}::password2 -show {*} \
      -validate key -validatecommand {::Jabber::ValidatePasswordStr %S} 
     
    grid  $p3.fr.msg1  -             -pady 4 -sticky w
    grid  $p3.fr.lan   $p3.fr.name   -pady 4 -sticky e
    grid  $p3.fr.lap   $p3.fr.pass   -pady 4 -sticky e
    grid  $p3.fr.lap2  $p3.fr.pass2  -pady 4 -sticky e
    grid  $p3.fr.name  $p3.fr.pass  $p3.fr.pass2  -sticky ew
    pack  $p3.fr -side top -fill x

    lappend wrapthese $p3.fr.msg1

    # Register?
    set p4 [$su newpage "register" -headtext [mc Register]]
    ttk::frame $p4.fr -padding [option get . notebookPagePadding {}]
    ttk::label $p4.fr.msg1 -style Small.TLabel \
      -wraplength 260 -justify left -text [mc suregmsg]
    ttk::button $p4.fr.btreg -text "[mc {Register Now}]... "  \
      -command [namespace current]::DoRegister

    grid  $p4.fr.msg1   -pady 4 -sticky w
    grid  $p4.fr.btreg  -pady 8
    pack  $p4.fr -side top -fill x

    lappend wrapthese $p4.fr.msg1

    # Finish.
    set p5 [$su newpage "fin" -headtext [mc Finished]]
    ttk::frame $p5.fr -padding [option get . notebookPagePadding {}]
    ttk::label $p5.fr.msg1 -style Small.TLabel \
      -wraplength 260 -justify left -text [mc sufinmsg]
    ttk::label $p5.fr.piga -image [::Theme::GetImage ladybug]
    
    grid  $p5.fr.msg1  -sticky n
    grid  $p5.fr.piga  -pady 8
    pack  $p5.fr -side top -fill x
    
    lappend wrapthese $p5.fr.msg1

    wm resizable $w 0 0

    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	set wrapthese [list %s]
	set width [expr [winfo reqwidth %s] - 20]
	foreach wl $wrapthese {
	    $wl configure -wraplength $width
	}
    } $wrapthese $w]    
    after idle $script
}

proc ::Jabber::SetupAss::NextPage {w page} {
    variable username
    variable password
    variable password2
    
    # Verify that it is ok before showing the next page.
    switch -- $page {
	username {
	    if {($username == "") || ($password == "")} {
		::UI::MessageBox -icon error -title [mc {Empty Fields}] \
		  -message [mc messsuassfillin] -parent $w
		return -code 3
	    } elseif {$password != $password2} {
		::UI::MessageBox -icon error -title [mc {Different Passwords}] \
		  -message [mc messpasswddifferent] -parent $w
		set password ""
		set password2 ""
		return -code 3
	    }
	}
	language {
	    	    
	}
    }
}
    
proc ::Jabber::SetupAss::DefaultLang { } {
    global  prefs
    variable locale
    
    set prefs(messageLocale) ""
    set locale [lindex [split [::msgcat::mclocale] _] 0]
}

proc ::Jabber::SetupAss::DoClose {w} {
    
    set ans [::UI::MessageBox -type yesno -parent $w -icon info \
      -message [mc messsuassclose]]
    if {$ans == "yes"} {
	destroy $w
    }
}

proc ::Jabber::SetupAss::DoRegister { } {    
    variable server
    variable username
    variable password
    variable haveRegistered

    ::RegisterEx::New -server $server  \
      -username $username -password $password
    set haveRegistered 1
}

proc ::Jabber::SetupAss::DoFinish {w} {
    global  this prefs
    variable server
    variable username
    variable password
    variable locale
    variable finished
    variable haveRegistered
    
    if {!$haveRegistered} {
	
	# Save as a shortcut and default server only if not called 
	# ::RegisterEx::New which already done this
	::Profiles::Set {} $server $username $password home
    }
    
    # Load any new message catalog.
    set prefs(messageLocale) $locale
    ::msgcat::mclocale $locale
    ::msgcat::mcload $this(msgcatPath)
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

    ::Debug 2 "::Jabber::SetupAss::ServersDlg w=$w"
    
    if {[winfo exists $w]} {
	raise $w
	return
    }
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1
    wm title $w {Public Jabber Servers}
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    # Button part.
    set frbot    $wbox.b
    set wbservbt $frbot.btok
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Set] -default active \
      -state disabled -command [list [namespace current]::ServSet $w]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::ServCancel $w]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side bottom -fill x
    
    # List of servers.
    ttk::label $wbox.msg  \
      -padding {0 0 0 6} -wraplength 300 -justify left \
      -text "List of open Jabber servers:"
    pack $wbox.msg -side top -anchor w

    set wtbfr $wbox.wtbfr
    set wysc  $wtbfr.ysc
    set wtbl  $wtbfr.wtbl
    frame $wtbfr -borderwidth 1 -relief sunken
    pack $wtbfr -side top -fill both -expand 1
    tablelist::tablelist $wtbl \
      -columns [list 16 Address 30 Name]  \
      -yscrollcommand [list $wysc set] -stretch all \
      -width 70 -height 16
    tuscrollbar $wysc -orient vertical -command [list $wtbl yview]

    grid  $wtbl  $wysc  -sticky news
    grid columnconfigure $wtbfr 0 -weight 1
    grid rowconfigure $wtbfr 0 -weight 1

    # Chasing arrows and status message.
    ttk::frame $wbox.frarr
    pack $wbox.frarr -side top -anchor w
    set warrows $wbox.frarr.arr
    ::chasearrows::chasearrows $warrows -size 16
    pack $warrows -side left -padx 5 -pady 5
    ttk::label $wbox.frarr.msg  \
      -textvariable [namespace current]::servStatVar
    pack $wbox.frarr.msg -side left
    set servStatVar ""

    bind $w <Return> {}
    bind $wtbl <<ListboxSelect>> [list [namespace current]::ServSelect]
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    catch {grab $w}
    
    # HTTP get xml list of servers.
    set url $::Jabber::jprefs(urlServersList)
    if {[catch {
	::httpex::get $url -progress [namespace current]::ServProgress  \
	  -command [list [namespace current]::ServCommand $w] \
	  -timeout $prefs(timeoutMillis)
    } token]} {
	destroy $w
	::UI::MessageBox -title [mc Error] -icon error -type ok  \
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

    $wbservbt state {!disabled}
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

    ::Debug 2 "::Jabber::SetupAss::ServCommand [::httpex::state $token]"
    
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
    
    ::Debug 2 "\ttoken=$token status=$status"
    
    switch -- $status {
	timeout {
	    ::UI::MessageBox -title [mc Timeout] -icon info -type ok \
	      -message "Timeout while waiting for response."
	}
	error {
	    ::UI::MessageBox -title "File transport error" -icon error -type ok \
	      -message "File transport error when getting server list:\
	      [::httpex::error $token]"
	}
	eof {
	    ::UI::MessageBox -title "File transport error" -icon error -type ok \
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
			unset -nocomplain attrArr
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

#-------------------------------------------------------------------------------
