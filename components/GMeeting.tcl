# GMeeting.tcl --
# 
#       Interface for launching Gnome Meeting.
#
# $Id: GMeeting.tcl,v 1.1 2004-12-09 08:28:41 matben Exp $

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
    
    component::register GnomeMeeting  \
      "Provides a method to launch Gnome Meeting"
}

proc ::GMeeting::MenuCmd {args} {
    
    puts "::GMeeting::MenuCmd args=$args"
}

proc ::GMeeting::RosterCmd {jid} {

    puts "::GMeeting::RosterCmd jid=$jid"
    set cmd [lindex [auto_execok gnomemeeting] 0]

    if {[catch {exec $cmd}]} {

	
    }
}

#-------------------------------------------------------------------------------
