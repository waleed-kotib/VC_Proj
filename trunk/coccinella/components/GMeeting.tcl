# GMeeting.tcl --
# 
#       Interface for launching Gnome Meeting.
#
# $Id: GMeeting.tcl,v 1.6 2005-02-04 07:05:30 matben Exp $

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
    
    set menuspec [list  \
      command {Gnome Meeting...} [namespace current]::MenuCmd normal {} {} {}]
    set popMenuSpec [list "Gnome Meeting..." user {::GMeeting::RosterCmd $jid3}]
        
    #::Jabber::UI::RegisterMenuEntry jabber $menuspec
    ::Jabber::UI::RegisterPopupEntry roster $popMenuSpec
    ::Jabber::RegisterCapsExtKey voip_h323
    ::Jabber::RegisterCapsExtKey voip_sip
    ::Jabber::RegisterCapsExtKey voipgm2

    ::Jabber::AddClientXmlns "http://jabber.org/protocol/voip/h323"
    ::Jabber::AddClientXmlns "http://jabber.org/protocol/voip/sip"
    ::Jabber::AddClientXmlns "http://jabber.org/protocol/voip/callto"
    
    component::register GnomeMeeting  \
      "Provides a method to launch Gnome Meeting"
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
    if {$ip == ""} {
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
