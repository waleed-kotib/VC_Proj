# SetupAss.tcl
#
#       Uses the wizard package to build a setup assistant for the
#       Coccinella. 
#
#  Copyright (c) 2001-2007  Mats Bengtsson
#  
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#  
# $Id: SetupAss.tcl,v 1.54 2008-05-15 14:14:57 matben Exp $

package require wizard
package require chasearrows
package require http 2.3
package require tinydom
package require JPubServers

package provide SetupAss 1.0

namespace eval ::SetupAss::  {

    variable server
    variable haveRegistered 0
    variable finished 0
    variable inited 0

    # Icons
    option add *SetupAss*assistantImage       tools-wizard        widgetDefault
    option add *SetupAss*assistantDisImage    tools-wizard-Dis    widgetDefault
    
    # Event hooks:
    ::hooks::register  connectState  ::SetupAss::ConnectStateHook
    
    # We could be much more general here...
    set ::config(setupass,page,server)    1
    set ::config(setupass,public-servers) 1
}

proc ::SetupAss::SetupAss {} {
    global  this prefs wDlgs config
    upvar ::Jabber::jprefs jprefs
    
    variable finished
    variable inited
    variable locale
    variable server    ""
    variable username  ""
    variable password  ""
    variable password2 ""
    variable wserver   ""
    variable wregister ""
    variable wwizard

    if {!$inited} {
    
	# Make the selected (first) server the default one.
	set profile [::Profiles::GetSelectedName]
	set spec [::Profiles::GetProfile $profile]
	set server [lindex $spec 0]
	set inited 1
    }
    set pady 2
    set w $wDlgs(setupass)
    if {[winfo exists $w]} {
	return
    }
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox} -class SetupAss
    wm title $w [::msgcat::mc "Setup Assistant"]
    
    set im  [::Theme::Find32Icon $w assistantImage]
    set imd [::Theme::Find32Icon $w assistantDisImage]

    set su $w.su
    wizard::wizard $su  \
      -image [list $im background $imd]  \
      -closecommand [list [namespace current]::DoClose $w]   \
      -finishcommand [list [namespace current]::DoFinish $w]  \
      -nextpagecommand [list [namespace current]::NextPage $w]
    pack $su -expand 1 -fill both
    
    set wwizard $su
    set wrapthese [list]
    
    # Front page.
    set p1 [$su newpage "intro" -headtext [mc "Setup Assistant"]]
    ttk::frame $p1.fr -padding [option get . notebookPagePadding {}]
    ttk::label $p1.fr.msg1 -style Small.TLabel \
      -wraplength 260 -justify left -anchor w -text [mc suintro1a $prefs(appName)]
    ttk::label $p1.fr.msg3 -style Small.TLabel \
      -wraplength 260 -justify left -anchor w -text [mc suintro3a]
    
    pack $p1.fr.msg1 $p1.fr.msg3 -side top -anchor w -fill x -pady 4
    pack $p1.fr -side top -fill x
    
    lappend wrapthese $p1.fr.msg1 $p1.fr.msg3
    
    # Language catalog.
    set plang [$su newpage "language" -headtext [mc Language]]
    ttk::frame $plang.fr -padding [option get . notebookPagePadding {}]
    ttk::label $plang.fr.msg1 -style Small.TLabel \
      -wraplength 260 -justify left -text [mc sulang2]
    ::Utils::LanguageMenubutton $plang.fr.pop [namespace current]::locale
    ttk::button $plang.fr.def -text [mc Default]  \
      -command [namespace current]::DefaultLang
    
    pack  $plang.fr.msg1  -side top -anchor w -pady $pady
    pack  $plang.fr.pop   -side top -anchor w -pady $pady
    pack  $plang.fr.def   -side top -anchor w -pady $pady
    pack  $plang.fr       -side top -fill x
    
    lappend wrapthese $plang.fr.msg1
    
    ::balloonhelp::balloonforwindow $plang.fr.pop \
      [mc "Requires a restart of" $prefs(appName)]
    
    # Server.
    if {$config(setupass,page,server)} {
	set p2 [$su newpage "server" -headtext [mc "Select Server"]]
	set fr2 $p2.fr
	ttk::frame $fr2 -padding [option get . notebookPagePadding {}]
	ttk::label $fr2.msg1 -style Small.TLabel \
	  -wraplength 260 -justify left -text [mc suservmsg2]
	
	ttk::label $fr2.la -text "[mc Server]:"
	ttk::combobox $fr2.serv -textvariable [namespace current]::server \
	  -validate key -validatecommand {::Jabber::ValidateDomainStr %S}
	
	grid  $fr2.msg1  -        -sticky nw -pady $pady
	grid  $fr2.la  $fr2.serv  -sticky e  -pady $pady
	grid $fr2.serv -sticky ew
	grid columnconfigure $fr2 1 -weight 1

	pack  $fr2 -side top -fill x
	
	set wserver $fr2.serv
	lappend wrapthese $fr2.msg1
	
	if {$config(setupass,public-servers)} {
	    catch {
		::httpex::get $jprefs(urlServersList) \
		  -command [namespace current]::HttpCommand
	    } httptoken	    
	}
    }
    
    # Username & Password.
    set p3 [$su newpage "username" -headtext [mc {Username & Password}]]
    set fr3 $p3.fr
    ttk::frame $p3.fr -padding [option get . notebookPagePadding {}]
    ttk::label $fr3.msg1 -style Small.TLabel \
      -wraplength 260 -justify left -text [mc suusermsg2]
    ttk::label $fr3.srv  -text "[mc Server]:"
    ttk::label $fr3.srv2 -textvariable [namespace current]::server
    ttk::label $fr3.lan  -text "[mc Username]:"
    ttk::label $fr3.lap  -text "[mc Password]:"
    ttk::label $fr3.lap2 -text "[mc {Retype password}]:"
    ttk::entry $fr3.name -textvariable [namespace current]::username \
       -validate key -validatecommand {::Jabber::ValidateUsernameStr %S}
    ttk::entry $fr3.pass -textvariable [namespace current]::password -show {*} \
      -validate key -validatecommand {::Jabber::ValidatePasswordStr %S}
    ttk::entry $fr3.pass2 -textvariable [namespace current]::password2 -show {*} \
      -validate key -validatecommand {::Jabber::ValidatePasswordStr %S} 
     
    grid  $fr3.msg1  -           -pady $pady -sticky w
    grid  $fr3.srv   $fr3.srv2   -pady $pady -sticky e
    grid  $fr3.lan   $fr3.name   -pady $pady -sticky e
    grid  $fr3.lap   $fr3.pass   -pady $pady -sticky e
    grid  $fr3.lap2  $fr3.pass2  -pady $pady -sticky e
    grid  $fr3.name  $fr3.pass  $fr3.pass2  -sticky ew
    grid  $fr3.srv2  -sticky w
    pack  $p3.fr -side top -fill x

    lappend wrapthese $fr3.msg1

    # Register?
    set p4 [$su newpage "register" -headtext [mc "New Account"]]
    ttk::frame $p4.fr -padding [option get . notebookPagePadding {}]
    ttk::label $p4.fr.msg1 -style Small.TLabel \
      -wraplength 260 -justify left -text [mc suregmsg2]
    ttk::button $p4.fr.btreg -text "[mc {New Account}]... "  \
      -command [namespace current]::DoRegister

    grid  $p4.fr.msg1   -pady $pady -sticky w
    grid  $p4.fr.btreg  -pady 8
    pack  $p4.fr -side top -fill x

    set wregister $p4.fr.btreg
    lappend wrapthese $p4.fr.msg1

    # Finish.
    set p5 [$su newpage "fin" -headtext [mc Finished]]
    ttk::frame $p5.fr -padding [option get . notebookPagePadding {}]
    ttk::label $p5.fr.msg1 -style Small.TLabel \
      -wraplength 260 -justify left -text [mc sufinmsg2]
    ttk::label $p5.fr.piga -image [::Theme::FindIconSize 128 coccinella]
    
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
    
    ::UI::CenterWindow $w
}

proc ::SetupAss::HttpCommand {htoken} {
    variable wserver
    
    if {[::httpex::state $htoken] ne "final"} {
	return
    }
    if {[::httpex::status $htoken] eq "ok"} {
	set ncode [httpex::ncode $htoken]	
	if {$ncode == 200} {
	
	    # Get and parse xml.
	    set xml [::httpex::data $htoken]    
	    set xtoken [tinydom::parse $xml -package qdxml]
	    set xmllist [tinydom::documentElement $xtoken]
	    set jidL [list]
	    
	    foreach elem [tinydom::children $xmllist] {
		switch -- [tinydom::tagname $elem] {
		    item {
			unset -nocomplain attrArr
			array set attrArr [tinydom::attrlist $elem]
			if {[info exists attrArr(jid)]} {
			    lappend jidL [list $attrArr(jid)]
			}
		    }
		}
	    }
	    if {[winfo exists $wserver]} {
		$wserver configure -values $jidL
		$wserver set ""
	    }
	    tinydom::cleanup $xtoken
	} elseif {$ncode == 301} {
	    
	    # Permanent redirect.
	    array set metaA [set $htoken\(meta)]
	    if {[info exists metaA(Location)]} {
		set location $metaA(Location)
	    }
	}
    }
    ::httpex::cleanup $htoken

    if {[info exists location]} {
	catch {
	    ::httpex::get $location \
	      -command [namespace current]::HttpCommand
	}	    
    }
}

proc ::SetupAss::NextPage {w page} {
    variable server
    variable username
    variable password
    variable password2
    variable wserver
    variable wregister
    variable wwizard
        
    # Verify that it is ok before showing the next page.
    switch -- $page {
	username {
	    if {($username eq "") || ($password eq "")} {
		::UI::MessageBox -icon error -title [mc Error] \
		  -message [mc messsuassfillin] -parent $w
		return -code 3
	    } elseif {$password ne $password2} {
		::UI::MessageBox -icon error -title [mc Error] \
		  -message [mc messpasswddifferent2] -parent $w
		set password ""
		set password2 ""
		return -code 3
	    }
	}
	server {
	    if {$server eq ""} {
		::UI::MessageBox -icon error -title [mc Error] \
		  -message [mc suservmsg2] -parent $w
		focus $wserver
		return -code 3
	    }
	}
	language {
	    	    
	}
    }
}
    
proc ::SetupAss::DefaultLang { } {
    global  prefs
    variable locale
    
    set prefs(messageLocale) ""
    set locale [lindex [split [::msgcat::mclocale] _] 0]
}

proc ::SetupAss::DoClose {w} {
    
    set ans [::UI::MessageBox -type yesno -parent $w -icon info \
      -title [mc "Setup Assistant"] -message [mc messsuassclose]]
    if {$ans eq "yes"} {
	destroy $w
    }
}

proc ::SetupAss::DoRegister { } {    
    variable server
    variable username
    variable password
    variable haveRegistered
    variable wregister

    # This dialog grabs.
    ::RegisterEx::New -autoget 1 -server $server  \
      -username $username -password $password
    set haveRegistered 1
    if {[::Jabber::IsConnected]} {
	$wregister state {disabled}
    }
}

proc ::SetupAss::ConnectStateHook {state} {
    global  wDlgs
    variable wregister

    if {![winfo exists $wDlgs(setupass)]} {
	return
    }
    
    # Avoid inconsistent state.
    switch $state {
	connectinit - connectfin - connect {
	    $wregister state {disabled}
	}
	disconnect {
	    $wregister state {!disabled}
	}
    }   
}

proc ::SetupAss::DoFinish {w} {
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
	::Profiles::Set {} $server $username $password
    }
    
    # Load any new message catalog.
    set prefs(messageLocale) $locale
    ::msgcat::mclocale $locale
    ::msgcat::mcload $this(msgcatPath)
    set finished 1
    destroy $w
}

proc ::SetupAss::ServersDlg {w} {

    ::JPubServers::New [namespace current]::ServersCmd
}

proc ::SetupAss::ServersCmd {_server} {
    variable server
    
    set server $_server
}

#-------------------------------------------------------------------------------
