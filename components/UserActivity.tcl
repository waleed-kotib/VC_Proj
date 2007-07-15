# UserActivity.tcl --
# 
#       User Activity using PEP recommendations over PubSub library code.
#       Implements XEP-0108: User Activity
#
#  Copyright (c) 2007 Mats Bengtsson
#  
#  $Id: UserActivity.tcl,v 1.1 2007-07-15 13:36:06 matben Exp $

package require jlib::pep
package require ui::optionmenu

namespace eval ::UserActivity {}

proc ::UserActivity::Init {} {
    
    return

    component::register UserActivity "This is User Activity (XEP-0108)."

    ::Debug 2 "::UserActivity::Init"

    # Add event hooks.
    ::hooks::register jabberInitHook        ::UserActivity::JabberInitHook
    ::hooks::register loginHook             ::UserActivity::LoginHook
    ::hooks::register logoutHook            ::UserActivity::LogoutHook

    variable moodNode
    set moodNode "http://jabber.org/protocol/activity "

    variable xmlns
    set xmlns(activity)        "http://jabber.org/protocol/activity "
    set xmlns(activity+notify) "http://jabber.org/protocol/activity+notify"
    set xmlns(node_config)     "http://jabber.org/protocol/pubsub#node_config"

    variable menuDef
    set menuDef [list command "User Activity..." ::UserActivity::Dlg {} {}]
}

# UserActivity::JabberInitHook --
# 
#       Here we announce that we have user activity support and is interested in
#       getting notifications.

proc ::UserActivity::JabberInitHook {jlibname} {
    variable xmlns
    
    set E [list]
    lappend E [wrapper::createtag "identity"  \
      -attrlist [list category hierarchy type leaf name "User Activity"]]
    lappend E [wrapper::createtag "feature" \
      -attrlist [list var $xmlns(activity)]]    
    lappend E [wrapper::createtag "feature" \
      -attrlist [list var $xmlns(activity+notify)]]
    
    $jlibname caps register activity $E [list $xmlns(activity) $xmlns(activity+notify)]
}

# Setting own activity ---------------------------------------------------------
#
#       Disco server for PEP, disco own bare JID, create pubsub node.
#       
#       1) Disco server for pubsub/pep support
#       2) Publish activity

proc ::UserActivity::LoginHook {} {
    variable xmlns
   
    # Disco server for pubsub/pep support.
    set server [::Jabber::JlibCmd getserver]
    ::Jabber::JlibCmd pep have $server [namespace code HavePEP]
    ::Jabber::JlibCmd pubsub register_event [namespace code Event] \
      -node $xmlns(activity)
}

proc ::UserActivity::HavePEP {jlibname have} {
    variable menuDef

    if {$have} {
	::JUI::RegisterMenuEntry jabber $menuDef
    }
}

proc ::UserActivity::LogoutHook {} {
    
    ::JUI::DeRegisterMenuEntry jabber "User Activity..."
}

proc ::UserActivity::Dlg {} {
    
    
    set str "Set your activity that will be shown to other users."
    set dtl "Enter the information you have available below. A minimal list contains only latitude and longitude."
    set w [ui::dialog -message $str -detail $dtl -icon internet \
      -buttons {ok cancel remove} -modal 1 \
      -geovariable ::prefs(winGeom,activity) \
      -title "User Activity" -command [namespace code DlgCmd]]
    set fr [$w clientframe]
    
    # State array variable.
    variable $w
    upvar 0 $w state
    set token [namespace current]::$w

    
    
    
}

proc ::UserActivity::DlgCmd {w bt} {
    variable $w
    upvar 0 $w state
    variable xmlns
    
    if {$bt eq "ok"} {
	Publish $w
    } elseif {$bt eq "remove"} {
	Retract $w
    }
    unset -nocomplain state
}

proc ::UserActivity::Publish {w} {
    variable $w
    upvar 0 $w state
    variable xmlns
    
    # Create gelocation stanza before publish.
    set childL [list]
    foreach {key value} [array get state] {
	if {[string length $value]} {
	    lappend childL [wrapper::createtag $key -chdata $value]
	}
    }
    set activityE [wrapper::createtag "activity" \
      -attrlist [list xml:lang [jlib::getlang]] -subtags $childL]
    set itemE [wrapper::createtag item -subtags [list $activityE]]

    ::Jabber::JlibCmd pep publish $xmlns(activity) $itemE
}

# UserActivity::Event --
# 
#       User activity event handler for incoming activity messages.

proc ::UserActivity::Event {jlibname xmldata} {
    variable state
    variable xmlns
	
    # The server MUST set the 'from' address on the notification to the 
    # bare JID (<node@domain.tld>) of the account owner.
    set from [wrapper::getattribute $xmldata from]
    set eventE [wrapper::getfirstchildwithtag $xmldata event]
    if {[llength $eventE]} {
	set itemsE [wrapper::getfirstchildwithtag $eventE items]
	if {[llength $itemsE]} {

	    set node [wrapper::getattribute $itemsE node]    
	    if {$node ne $xmlns(activity)} {
		return
	    }

	    set mjid [jlib::jidmap $from]
	    set text ""
	    set mood ""

	    set retractE [wrapper::getfirstchildwithtag $itemsE retract]
	    if {[llength $retractE]} {
		set msg ""
		set state($mjid,mood) ""
		set state($mjid,text) ""
	    } else {
		set itemE [wrapper::getfirstchildwithtag $itemsE item]
		set moodE [wrapper::getfirstchildwithtag $itemE mood]
		if {![llength $moodE]} {
		    return
		}
		foreach E [wrapper::getchildren $moodE] {
		    set tag [wrapper::gettag $E]
		    switch -- $tag {
			text {
			    set text [wrapper::getcdata $E]
			}
			default {
			    set mood $tag
			}
		    }
		}
	    
		# Cache the result.
		set state($mjid,mood) $mood
		set state($mjid,text) $text
	    
		if {$mood eq ""} {
		    set msg ""
		} else {
		    set msg "[mc mMood]: [mc $mood] $text"
		}
	    }
	    ::RosterTree::BalloonRegister mood $from $msg
	    
	    ::hooks::run activityEvent $xmldata $mood $text
	}
    }
}
