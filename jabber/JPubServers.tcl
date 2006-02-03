# JPubServers.tcl --
# 
#       DIalog to get list of public jabber servers.
#       
#  Copyright (c) 2006  Mats Bengtsson
#  
# $Id: JPubServers.tcl,v 1.3 2006-02-03 07:17:17 matben Exp $

package require chasearrows
package require httpex
package require tinydom

package provide JPubServers 1.0

namespace eval ::JPubServers  {
    
    variable win .jpubservers
    
    # Bindtags instead of binding to toplevel.
    bind JPubServersToplevel <Destroy> {+::JPubServers::OnDestroyToplevel %W }
}

proc ::JPubServers::New {{command ""}} {
    variable win
    
    Build $win $command
}

proc ::JPubServers::Build {w {command ""}} {
    global  this prefs

    ::Debug 2 "::JPubServers::Build w=$w"
    
    if {[winfo exists $w]} {
	raise $w
	return
    }
    variable $w
    upvar #0 $w state

    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1
    wm title $w [mc {Public Jabber Servers}]
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    # Button part.
    set frbot $wbox.b
    set wset  $frbot.btok
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Set] -default active \
      -state disabled -command [list [namespace current]::Set $w]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::Cancel $w]
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
      -text "[mc suservlist]:"
    pack $wbox.msg -side top -anchor w

    set wtbfr $wbox.wtbfr
    set wysc  $wtbfr.ysc
    set wtbl  $wtbfr.wtbl
    frame $wtbfr -borderwidth 1 -relief sunken
    pack $wtbfr -side top -fill both -expand 1
    tablelist::tablelist $wtbl \
      -columns [list 16 [mc Address] 30 [mc Name]]  \
      -yscrollcommand [list $wysc set] -stretch all \
      -width 70 -height 16
    ttk::scrollbar $wysc -orient vertical -command [list $wtbl yview]

    grid  $wtbl  $wysc  -sticky news
    grid columnconfigure $wtbfr 0 -weight 1
    grid rowconfigure $wtbfr 0 -weight 1

    # Chasing arrows and status message.
    ttk::frame $wbox.frarr
    pack $wbox.frarr -side top -anchor w
    set warrows $wbox.frarr.arr
    ::chasearrows::chasearrows $warrows -size 16
    pack $warrows -side left -padx 5 -pady 5
    ttk::label $wbox.frarr.msg -textvariable $w\(statusmsg)
    pack $wbox.frarr.msg -side left

    bind $w <Return> {}
    bind $wtbl <<ListboxSelect>> [list [namespace current]::Select $w]
    
    set state(command)    $command
    set state(warrows)    $warrows
    set state(wtbl)       $wtbl
    set state(wset)       $wset
    set state(statusmsg)  ""
            
    # For toplevel binds.
    if {[lsearch [bindtags $w] JPubServersToplevel] < 0} {
	bindtags $w [linsert [bindtags $w] 0 JPubServersToplevel]
    }

    # HTTP get xml list of servers.
    set url $::Jabber::jprefs(urlServersList)
    if {[catch {
	::httpex::get $url  \
	  -progress [list [namespace current]::HttpProgress $w] \
	  -command  [list [namespace current]::HttpCommand $w]  \
	  -timeout $prefs(timeoutMillis)
    } token]} {
	destroy $w
	::UI::MessageBox -title [mc Error] -icon error -type ok  \
	  -message "Failed to obtain list of open Jabber servers from\
	  \"$url\": $token"
	return
    } else {
	set state(statusmsg) "Getting server list from $url"
	$warrows start
    }
    if {[winfo exists $w]} {
	set state(token) $token
    }
}

proc ::JPubServers::Set {w} {
    variable $w
    upvar #0 $w state

    set ind [$state(wtbl) curselection]
    if {$ind ne ""} {
	set rowcurrent [$state(wtbl) get $ind]
	set server [lindex $rowcurrent 0]
	if {$state(command) ne ""} {
	    uplevel #0 $state(command) $server
	}
    }
    destroy $w
}

proc ::JPubServers::Cancel {w} {

    destroy $w
}

proc ::JPubServers::Select {w} {
    variable $w
    upvar #0 $w state

    $state(wset) state {!disabled}
}

proc ::JPubServers::HttpProgress {w token total current} {       
    # Empty.
}

proc ::JPubServers::HttpCommand {w token} {
    variable $w
    upvar #0 $w state

    ::Debug 2 "::JPubServers::HttpCommand [::httpex::state $token]"
    
    if {![winfo exists $w]} {
	if {[::httpex::state $token] ne "reset"} {
	    httpex::reset $token
	}
	::httpex::cleanup $token
	return
    }
    if {[::httpex::state $token] ne "final"} {
	return
    }
    set state(statusmsg) ""
    $state(warrows) stop
    
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
	    set serverList {}
	    
	    foreach elem [tinydom::children $xmllist] {
		switch -- [tinydom::tagname $elem] {
		    item {
			unset -nocomplain attrArr
			array set attrArr [tinydom::attrlist $elem]
			lappend serverList  \
			  [list $attrArr(jid) $attrArr(name)]
		    }
		}
	    }

	    $state(wtbl) insertlist end $serverList
	}
    }
    ::httpex::cleanup $token
    if {$status ne "ok"} {
	catch {destroy $w}
    }
}

proc ::JPubServers::OnDestroyToplevel {w} {    
    variable $w
    upvar #0 $w state
    
    unset -nocomplain state
}

#-------------------------------------------------------------------------------
