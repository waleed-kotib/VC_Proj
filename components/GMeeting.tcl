# GMeeting.tcl --
# 
#       Interface for launching Gnome Meeting.
#
#  Copyright (c) 2007 Mats Bengtsson
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
# $Id: GMeeting.tcl,v 1.16 2007-08-24 13:33:13 matben Exp $

namespace eval ::GMeeting:: {
    
}

proc ::GMeeting::Init { } {
    global  this

    ::Debug 2 "::GMeeting::Init"
    
    if {![string equal $this(platform) "unix"]} {
	return
    }
    set cmd [lindex [auto_execok gnomemeeting] 0]
    if {$cmd == {}} {
	return
    }	
    set mDef [list command "Gnome Meeting..." {::GMeeting::RosterCmd $jid3}]
    set mType {"Gnome Meeting..." user}
	
    ::Roster::RegisterPopupEntry $mDef $mType    

    ::hooks::register jabberInitHook  ::GMeeting::JabberInitHook
    
    component::register GnomeMeeting  \
      "Provides a method to launch Gnome Meeting"
}

proc ::GMeeting::JabberInitHook {jlibname} {

    array set xmlns {
	h323    "http://jabber.org/protocol/voip/h323"
	sip     "http://jabber.org/protocol/voip/sip"
	callto  "http://jabber.org/protocol/voip/callto"
    }
    
    # Need to create all elements when responding to a disco info
    # request to the specified node.
    foreach uri {h323 sip callto} name {"VoIP H323" "VoIP SIP" "VoIP callto"} {
	set subtags($uri) [list [wrapper::createtag "identity" -attrlist  \
	  [list category hierarchy type leaf name $name]]]
	lappend subtags($uri) [wrapper::createtag "feature" \
	  -attrlist [list var "http://jabber.org/protocol/voip/$uri"]]
    }

    $jlibname caps register voip_h323 $subtags(h323)   $xmlns(h323)
    $jlibname caps register voip_sip  $subtags(sip)    $xmlns(sip)
    $jlibname caps register voipgm2   $subtags(callto) $xmlns(callto)
}

proc ::GMeeting::MenuCmd {args} {
    
    puts "::GMeeting::MenuCmd args=$args"
}

proc ::GMeeting::RosterCmd {jid} {

    ::Debug 2 "::GMeeting::RosterCmd jid=$jid"
    
    if {![HasSupport $jid]} {
	tk_messageBox -type ok -icon error -title Error \
	  -message "The user \"$jid\" has no support for H323 or SIP"
	return
    }
    set cmd [lindex [auto_execok gnomemeeting] 0]
    set ip [::Disco::GetCoccinellaIP $jid]
    if {$ip eq ""} {
	tk_messageBox -type ok -icon error -title Error \
	  -message "We failed to identify any ip address for \"$jid\""
	return
    }
    set uri h323:${ip}
    if {[catch {exec $cmd -c $uri &} err]} {
	tk_messageBox -type ok -icon error -title Error \
	  -message "We failed to launch Gnome Meeting: $err"
    }
}

proc ::GMeeting::HasSupport {jid} {
    
    set ans 0
    set extList [::Jabber::RosterCmd getcapsattr $jid ext]
    if {$extList != {}} {
	if {[lsearch $extList voip_h323] >= 0} {
	    set ans 1
	} elseif {[lsearch $extList voip_sip] >= 0} {
	    set ans 1
	}
    }
    return $ans
}

#-------------------------------------------------------------------------------
