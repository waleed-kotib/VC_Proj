# SetupAss.tcl
#
#       Uses the wizard package to build a setup assistant for the
#       Coccinella. 
#
#  Copyright (c) 2001-2006  Mats Bengtsson
#  
# $Id: SetupAss.tcl,v 1.38 2006-01-11 13:24:54 matben Exp $

package require wizard
package require chasearrows
package require http 2.3
package require tinydom
package require JPubServers

package provide SetupAss 1.0

namespace eval ::Jabber::SetupAss::  {

    variable server
    variable haveRegistered 0
    variable finished 0
    variable inited 0

    # Icons
    option add *SetupAss*assistantImage       assistant        widgetDefault
    option add *SetupAss*assistantDisImage    assistantDis     widgetDefault
    
    # We could be much more general here...
    set ::config(setupass,page,server) 1
}

proc ::Jabber::SetupAss::SetupAss { } {
    global  this prefs wDlgs config
    
    variable finished
    variable inited
    variable locale
    variable localeStr
    variable server    ""
    variable username  ""
    variable password  ""
    variable password2 ""
    variable langCode2Str

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
    wm title $w [::msgcat::mc {Setup Assistant}]
    
    set im  [::Theme::GetImage [option get $w assistantImage {}]]
    set imd [::Theme::GetImage [option get $w assistantDisImage {}]]

    set ns [namespace current]
    set su $w.su
    wizard::wizard $su  \
      -image [list $im background $imd]  \
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

    # Add entries here for new message catalogs.
    array set code2Name {
	da {Danish} 
	nl {Dutch} 
	en {English} 
	fr {French} 
	de {German} 
	pl {Polish} 
	ru {Russian} 
	es {Spanish} 
	sv {Swedish} 
    }
    set langs {}
    foreach f [glob -nocomplain -tails -directory $this(msgcatPath) *.msg] {
	set code [file rootname $f]
	if {[info exists code2Name($code)]} {
	    set name $code2Name($code)
	    set key native${name}
	    set str [mc $key]
	    if {$str eq $key} {
		# Fallback.
		set str $name
	    }
	} else {
	    set str $code
	}
	lappend langs $str
	set langCode2Str($code) $str
    }
    set wmb $plang.fr.pop
    ttk::menubutton $wmb -textvariable [namespace current]::localeStr  \
      -menu $wmb.menu -direction flush
    menu $wmb.menu -tearoff 0
    foreach {code str} [array get langCode2Str] {
	$wmb.menu add radiobutton -label $str -value $code  \
	  -variable [namespace current]::locale  \
	  -command [namespace current]::LangCmd
    }
    
    if {$prefs(messageLocale) eq ""} {
	set locale [lindex [split [::msgcat::mclocale] _] 0]
    } else {
	set locale $prefs(messageLocale)
    }
    set localeStr $langCode2Str($locale)
    ttk::button $plang.fr.def -text [mc Default]  \
      -command [namespace current]::DefaultLang
    
    pack  $plang.fr.msg1  -side top -anchor w -pady $pady
    pack  $plang.fr.pop   -side top -anchor w -pady $pady
    pack  $plang.fr.def   -side top -anchor w -pady $pady
    pack  $plang.fr       -side top -fill x
    
    lappend wrapthese $plang.fr.msg1
    
    # Server.
    if {$config(setupass,page,server)} {
	set p2 [$su newpage "server" -headtext [mc {Jabber Server}]]
	set fr2 $p2.fr
	ttk::frame $fr2 -padding [option get . notebookPagePadding {}]
	ttk::label $fr2.msg1 -style Small.TLabel \
	  -wraplength 260 -justify left -text [mc suservmsg]
	ttk::button $fr2.bt -text [mc Get] \
	  -command [list [namespace current]::ServersDlg .jsuserv]
	ttk::label $fr2.msg2 -style Small.TLabel \
	  -wraplength 260 -justify left -text [mc supubserv]
	ttk::label $fr2.la -text "[mc Server]:"
	ttk::entry $fr2.serv -width 28 -textvariable ${ns}::server \
	  -validate key -validatecommand {::Jabber::ValidateDomainStr %S}
	
	grid  $fr2.msg1  -          -sticky nw -pady $pady
	grid  $fr2.bt    $fr2.msg2  -sticky ew -pady $pady
	grid  $fr2.la    $fr2.serv  -sticky e  -pady $pady
	grid  $fr2.serv  -sticky ew
	pack  $fr2 -side top -fill x
	
	lappend wrapthese $fr2.msg1
    }
    
    # Username & Password.
    set p3 [$su newpage "username" -headtext [mc {Username & Password}]]
    set fr3 $p3.fr
    ttk::frame $p3.fr -padding [option get . notebookPagePadding {}]
    ttk::label $fr3.msg1 -style Small.TLabel \
      -wraplength 260 -justify left -text [mc suusermsg]
    ttk::label $fr3.srv  -text "[mc Server]:"
    ttk::label $fr3.srv2 -textvariable ${ns}::server
    ttk::label $fr3.lan  -text "[mc Username]:"
    ttk::label $fr3.lap  -text "[mc Password]:"
    ttk::label $fr3.lap2 -text "[mc {Retype password}]:"
    ttk::entry $fr3.name -textvariable ${ns}::username \
       -validate key -validatecommand {::Jabber::ValidateUsernameStr %S}
    ttk::entry $fr3.pass -textvariable ${ns}::password -show {*} \
      -validate key -validatecommand {::Jabber::ValidatePasswordStr %S}
    ttk::entry $fr3.pass2 -textvariable ${ns}::password2 -show {*} \
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
    set p4 [$su newpage "register" -headtext [mc Register]]
    ttk::frame $p4.fr -padding [option get . notebookPagePadding {}]
    ttk::label $p4.fr.msg1 -style Small.TLabel \
      -wraplength 260 -justify left -text [mc suregmsg]
    ttk::button $p4.fr.btreg -text "[mc {Register Now}]... "  \
      -command [namespace current]::DoRegister

    grid  $p4.fr.msg1   -pady $pady -sticky w
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

proc ::Jabber::SetupAss::LangCmd { } {
    variable locale
    variable localeStr
    variable langCode2Str
        
    set localeStr $langCode2Str($locale)
}

proc ::Jabber::SetupAss::NextPage {w page} {
    variable server
    variable username
    variable password
    variable password2
    
    # Verify that it is ok before showing the next page.
    switch -- $page {
	username {
	    if {($username eq "") || ($password eq "")} {
		::UI::MessageBox -icon error -title [mc {Empty Fields}] \
		  -message [mc messsuassfillin] -parent $w
		return -code 3
	    } elseif {$password ne $password2} {
		::UI::MessageBox -icon error -title [mc {Different Passwords}] \
		  -message [mc messpasswddifferent] -parent $w
		set password ""
		set password2 ""
		return -code 3
	    }
	}
	server {
	    if {$server eq ""} {
		::UI::MessageBox -icon error -title [mc Error] \
		  -message [mc suservmsg] -parent $w
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

    ::RegisterEx::New -autoget 1 -server $server  \
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
	::Profiles::Set {} $server $username $password
    }
    
    # Load any new message catalog.
    set prefs(messageLocale) $locale
    ::msgcat::mclocale $locale
    ::msgcat::mcload $this(msgcatPath)
    set finished 1
    destroy $w
}

proc ::Jabber::SetupAss::ServersDlg {w} {

    ::JPubServers::New [namespace current]::ServersCmd
}

proc ::Jabber::SetupAss::ServersCmd {_server} {
    variable server
    
    set server $_server
}

#-------------------------------------------------------------------------------
