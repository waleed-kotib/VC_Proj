#  OOB.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the UI of the jabber:iq:oob part of the jabber.
#      
#  Copyright (c) 2001-2005  Mats Bengtsson
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
# $Id: OOB.tcl,v 1.64 2008-02-06 13:57:25 matben Exp $

# NOTE: Parts if this code is obsolete (the send part) but the receiving
#       part is still retained for backwards compatibility.

package require uriencode

package provide OOB 1.0

namespace eval ::OOB:: {

    ::hooks::register jabberInitHook      ::OOB::InitJabberHook

    # Running number for token.
    variable uid 0
    
}

proc ::OOB::InitJabberHook {jlibname} {
    upvar ::Jabber::jstate jstate
    
    # Be sure to handle incoming requestes (iq set elements).
    $jstate(jlib) iq_register set jabber:iq:oob     ::OOB::ParseSet
}

# OOB::ParseSet --
#
#       Gets called when we get a 'jabber:iq:oob' 'set' element, that is,
#       another user sends us an url to fetch a file from.

proc ::OOB::ParseSet {jlibname from subiq args} {
    global  prefs
    variable locals
    
    eval {::hooks::run oobSetRequestHook $from $subiq} $args
    
    array set argsA $args
    
    # Be sure to trace any 'id' attribute for confirmation.
    if {[info exists argsA(-id)]} {
	set id $argsA(-id)
    } else {
	return 0
    }
    foreach child [wrapper::getchildren $subiq] {
	set tag  [wrapper::gettag $child]
	set $tag [wrapper::getcdata $child]
    }
    if {![info exists url]} {
	#::UI::MessageBox -title [mc Error] -icon error -type ok \
	#  -message [mc jamessoobnourl2 $from]
	return 0
    }
    
    # Validate URL, determine the server host and port.
    if {![regexp -nocase {^(([^:]*)://)?([^/:]+)(:([0-9]+))?(/.*)?$} $url \
      x prefix proto host y port path]} {
	#::UI::MessageBox -title [mc Error] -icon error -type ok \
	#  -message [mc jamessoobbad2 $from $url]
	return 0
    }
    if {[string length $proto] == 0} {
	set proto http
    }
    if {$proto ne "http"} {
	#::UI::MessageBox -title [mc Error] -icon error -type ok \
	#  -message [mc jamessoonnohttp2 $from $proto]
	return 0
    }
    set tail [file tail $url]
    set tailDec [::uri::urn::unquote $tail]
    
    set str "[mc File]: $tailDec"
    if {[info exists desc]} {
	append str "\n" "[mc Description]: $desc"
    }
    
    set w [ui::autoname]
    
    # Keep instance specific state array.
    variable $w
    upvar 0 $w state    
    
    set state(w)      $w
    set state(id)     $id
    set state(url)    $url
    set state(from)   $from
    set state(queryE) $subiq
    set state(args)   $args
    
    set msg [mc jamessoobask2 $from $str]
    ui::dialog $w -title [mc "Receive File"] -icon info \
      -type yesno -default yes -message $msg \
      -command [namespace code ParseSetCmd]
    
    return 1
}

proc ::OOB::ParseSetCmd {w bt} {
    global  prefs
    variable $w
    upvar 0 $w state    
    
    if {$bt eq "no"} {
	ReturnError $state(from) $state(id) $state(queryE) 406
    } else {
	set url $state(url)
	set tail [file tail $url]
	set tailDec [::uri::urn::unquote $tail]
	set userDir [::Utils::GetDirIfExist $prefs(userPath)]
	set localPath [tk_getSaveFile -title [mc "Save File"] \
	  -initialfile $tailDec -initialdir $userDir]
	if {$localPath eq ""} {
	    ReturnError $state(from) $state(id) $state(queryE) 406
	} else {
	    set prefs(userPath) [file dirname $localPath]
	
	    # And get it.
	    Get $state(from) $url $localPath $state(id) $state(queryE)
	}
    }
    unset -nocomplain state
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
	    ::Jabber::Jlib send_iq "result" {} -to $jid -id $id
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
      [list code $ncode type $type] -subtags [list $subElem]]
    
    ::Jabber::Jlib send_iq "error" [list $subiq $errElem] -to $jid -id $id
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
    array set argsA {
	-width     30
    }
    array set argsA $args
    set nlines 1
    foreach c [wrapper::getchildren $xml] {
	switch -- [wrapper::gettag $c] {
	    desc {
		set desc [wrapper::getcdata $c]
		set nlines [expr [string length $desc]/$argsA(-width) + 1]
	    }
	    url {
		set url [wrapper::getcdata $c]
	    }
	}
    }
    
    set bg [option get . backgroundGeneral {}]
    
    text $w -bd 0 -wrap word -width $argsA(-width)  \
      -background $bg -height $nlines  \
      -highlightthickness 0
    if {[info exists desc] && [info exists url]} {
	::Text::InsertURL $w $desc $url {}
    }
    return $w
}

#-------------------------------------------------------------------------------
