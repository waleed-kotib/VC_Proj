# GMeeting.tcl --
# 
#       Interface for launching Gnome Meeting.
#
# $Id: GMeeting.tcl,v 1.9 2005-11-04 15:14:55 matben Exp $

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
   
    set xmlnsdiscoinfo "http://jabber.org/protocol/disco#info"
    
    # Need to create all elements when responding to a disco info
    # request to the specified node.
    foreach uri {h323 sip callto} name {"VoIP H323" "VoIP SIP" "VoIP callto"} {
	set subtags($uri) [list [wrapper::createtag "identity" -attrlist  \
	  [list category hierarchy type leaf name $name]]]
	lappend subtags($uri) [wrapper::createtag "feature" \
	  -attrlist [list var $xmlnsdiscoinfo]]
	lappend subtags($uri) [wrapper::createtag "feature" \
	  -attrlist [list var "http://jabber.org/protocol/voip/$uri"]]
    }
    
    set menuspec [list  \
      command {Gnome Meeting...} [namespace current]::MenuCmd normal {} {} {}]
    set menuSpec \
      [list command "Gnome Meeting..." user {::GMeeting::RosterCmd $jid3} {}]
        
    #::Jabber::UI::RegisterMenuEntry jabber $menuspec
    ::Jabber::UI::RegisterPopupEntry roster $menuSpec
    ::Jabber::RegisterCapsExtKey voip_h323  $subtags(h323)
    ::Jabber::RegisterCapsExtKey voip_sip   $subtags(sip)
    ::Jabber::RegisterCapsExtKey voipgm2    $subtags(callto)

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
