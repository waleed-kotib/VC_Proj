# GMeeting.tcl --
# 
#       Interface for launching Gnome Meeting.
#
# $Id: GMeeting.tcl,v 1.2 2004-12-09 15:20:27 matben Exp $

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
    set popMenuSpec [list "Gnome Meeting..." user {::GMeeting::RosterCmd $jid}]
        
    ::Jabber::UI::RegisterMenuEntry jabber $menuspec
    ::Jabber::UI::RegisterPopupEntry roster $popMenuSpec
    ::Jabber::RegisterCapsExtKey voip_h323
    ::Jabber::RegisterCapsExtKey voip_sip
    
    component::register GnomeMeeting  \
      "Provides a method to launch Gnome Meeting"
}

proc ::GMeeting::MenuCmd {args} {
    
    puts "::GMeeting::MenuCmd args=$args"
}

proc ::GMeeting::RosterCmd {jid} {

    puts "::GMeeting::RosterCmd jid=$jid"
    
    if {![HasSupport $jid]} {
	tk_messageBox -type ok -icon error -title Error \
	  -message "The user \"$jid\" has no support for H323 or SIP"
	return
    }
    set cmd [lindex [auto_execok gnomemeeting] 0]

    if {[catch {exec $cmd}]} {

	
    }
}

proc ::GMeeting::HasSupport {jid} {
    upvar ::Jabber::coccixmlns coccixmlns
    
    set capsxmlns "http://jabber.org/protocol/caps"
    set ans 0
    set cElem [::Jabber::RosterCmd getextras $jid $capsxmlns]
    if {$cElem != {}} {
	set extList [wrapper::getattribute $cElem ext]
	if {$extList != {}} {
	    if {[lsearch $extList voip_h323] >= 0} {
		set ans 1
	    } elseif {[lsearch $extList voip_sip] >= 0} {
		set ans 1
	    }
	}
    }
    return $ans
}

#-------------------------------------------------------------------------------
