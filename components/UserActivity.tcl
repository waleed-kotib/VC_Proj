# UserActivity.tcl --
# 
#       User Activity using PEP recommendations over PubSub library code.
#       Implements XEP-0108: User Activity
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
#  $Id: UserActivity.tcl,v 1.4 2007-07-17 12:56:31 matben Exp $

package require jlib::pep
package require ui::optionmenu

namespace eval ::UserActivity {}

proc ::UserActivity::Init {} {

    component::register UserActivity "This is User Activity (XEP-0108)."

    ::Debug 2 "::UserActivity::Init"

    # Add event hooks.
    ::hooks::register jabberInitHook        ::UserActivity::JabberInitHook
    ::hooks::register loginHook             ::UserActivity::LoginHook
    ::hooks::register logoutHook            ::UserActivity::LogoutHook

    variable moodNode
    set moodNode "http://jabber.org/protocol/activity "

    variable xmlns
    set xmlns(activity)        "http://jabber.org/protocol/activity"
    set xmlns(activity+notify) "http://jabber.org/protocol/activity+notify"
    set xmlns(node_config)     "http://jabber.org/protocol/pubsub#node_config"

    variable menuDef
    set menuDef [list command "User Activity..." ::UserActivity::Dlg {} {}]
    
    variable subActivities
    set subActivities(doing_chores) {
	buying_groceries 
	cleaning 
	cooking 
	doing_maintenance 
	doing_the_dishes 
	doing_the_laundry 
	gardening 
	running_an_errand 
	walking_the_dog 
    }
    set subActivities(drinking) {
	having_a_beer 
	having_coffee 
	having_tea 
    }
    set subActivities(eating) {
	having_a_snack 
	having_breakfast 
	having_dinner 
	having_lunch 
    }
    set subActivities(exercising) {
	cycling 
	hiking 
	jogging 
	playing_sports 
	running 
	skiing 
	swimming 
	working_out 
    }
    set subActivities(grooming) {
	at_the_spa 
	brushing_teeth 
	getting_a_haircut 
	shaving 
	taking_a_bath 
	taking_a_shower 
    }
    set subActivities(having_appointment) {}

    set subActivities(inactive) {
	day_off 
	hanging_out 
	on_vacation 
	scheduled_holiday 
	sleeping 
    }
    set subActivities(relaxing) {
	gaming 
	going_out 
	partying 
	reading 
	rehearsing 
	shopping 
	socializing 
	sunbathing 
	watching_tv 
	watching_a_movie 
    }
    set subActivities(talking) {
	in_real_life 
	on_the_phone 
	on_video_phone 
    }
    set subActivities(traveling) {
	commuting 
	cycling 
	driving 
	in_a_car 
	on_a_bus 
	on_a_plane 
	on_a_train 
	on_a_trip 
	walking 
    }
    set subActivities(working) {
	coding 
	in_a_meeting 
	studying 
	writing 
    }
    
    variable allActivities    
    set allActivities [lsort [array names subActivities]]
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
    variable allActivities    
    variable subActivities
    variable xmlns
    
    
    set str "Set your activity that will be shown to other users."
    set dtl "Select from the first button your general activity, and optionally, your specific actvity from the second button. You may also add an descriptive text"
    set w [ui::dialog -message $str -detail $dtl -icon info \
      -buttons {ok cancel remove} -modal 1 \
      -geovariable ::prefs(winGeom,activity) \
      -title "User Activity" -command [namespace code DlgCmd]]
    set fr [$w clientframe]
    
    # State array variable.
    variable $w
    upvar 0 $w state
    set token [namespace current]::$w
    
    set state(activity) [lindex $allActivities 0]
    set state(specific) -
    set state(text) ""

    set mDef [list]
    foreach name $allActivities {
	set dname [string totitle [string map {_ " "} $name]]
	lappend mDef [list [mc $dname] -value $name]
    }
    ttk::label $fr.la -text "[mc General]:"
    ui::optionmenu $fr.activity -menulist $mDef -direction flush \
      -variable $token\(activity)
    ttk::label $fr.ls -text "[mc Specific]:"
    ui::optionmenu $fr.specific -direction flush \
      -variable $token\(specific)
    ttk::label $fr.lt -text "[mc Message]:"
    ttk::entry $fr.text -textvariable $token\(text)
    
    set maxw [$fr.activity maxwidth]

    grid  $fr.la  $fr.activity  -sticky e -pady 1
    grid  $fr.ls  $fr.specific  -sticky e -pady 1
    grid  $fr.lt  $fr.text      -sticky e -pady 1
    grid $fr.activity  $fr.specific  $fr.text  -sticky ew
    grid columnconfigure $fr 1 -minsize $maxw

    trace add variable $token\(activity) write [namespace code [list Trace $w]]
    ConfigSpecificMenu $w $state(activity)
            
    # Get our own published activity and fill in.
    set myjid2 [::Jabber::JlibCmd  myjid2]
    set cb [namespace code [list ItemsCB $w]]
    ::Jabber::JlibCmd pubsub items $myjid2 $xmlns(activity) -command $cb

}

proc ::UserActivity::Trace {w name1 name2 op} {
    variable $w
    upvar 0 $w state
    upvar $name1 var
    
    if {0} {
	# Never managed to figure out this :-(
	if {$name2 eq ""} {
	    set val $var
	} else {
	    set val $var($name2)
	}
	ConfigSpecificMenu $w $val
    }
    ConfigSpecificMenu $w $state(activity)
}

proc ::UserActivity::ConfigSpecificMenu {w activity} {
    variable subActivities
        
    set fr [$w clientframe]
    
    set mDef [list]
    lappend mDef [list [mc None] -value "-"]
    lappend mDef [list separator]
    foreach name $subActivities($activity) {
	set dname [string totitle [string map {_ " "} $name]]
	lappend mDef [list [mc $dname] -value $name]
    }
    $fr.specific configure -menulist $mDef
}

proc ::UserActivity::ItemsCB {w type subiq args} {
    variable $w
    upvar 0 $w state
    variable xmlns
    variable subActivities
    
    if {$type eq "error"} {
	return
    }    
    if {[winfo exists $w]} {
	foreach itemsE [wrapper::getchildren $subiq] {
	    set tag [wrapper::gettag $itemsE]
	    set node [wrapper::getattribute $itemsE "node"]
	    if {[string equal $tag "items"] && [string equal $node $xmlns(activity)]} {
		set itemE [wrapper::getfirstchildwithtag $itemsE item]
		set activityE [wrapper::getfirstchildwithtag $itemE activity]
		if {![llength $activityE]} {
		    return
		}
		foreach E [wrapper::getchildren $activityE] {
		    set tag [wrapper::gettag $E]
		    switch -- $tag {
			text {
			    set state(text) [wrapper::getcdata $E]
			}
			default {
			    if {![info exists subActivities($tag)]} {
				return
			    }
			    set activity $tag
			    set state(activity) $activity
			    set specificE [lindex [wrapper::getchildren $E] 0]
			    if {[llength $specificE]} {
				set specific [wrapper::gettag $specificE]
				if {[lsearch $subActivities($activity) $specific] >= 0} {
				    set state(specific) $specific
				} else {
				    set state(specific) -
				}
			    } else {
				set state(specific) -
			    }
			}
		    }
		}
	    }
	}
    }
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
    
    set specificE [list]
    if {$state(specific) ne "-"} {
	set specificE [list [wrapper::createtag $state(specific)]]
    }
    set childL [list [wrapper::createtag $state(activity) -subtags $specificE]]
    if {[string trim $state(text)] ne ""} {
	lappend childL [wrapper::createtag "text" \
	  -attrlist [list xml:lang [jlib::getlang]] -chdata $state(text)]
    }
    set activityE [wrapper::createtag "activity" -subtags $childL]
    set itemE [wrapper::createtag item -subtags [list $activityE]]

    ::Jabber::JlibCmd pep publish $xmlns(activity) $itemE
}

proc ::UserActivity::Retract {w} {
    variable xmlns

    ::Jabber::JlibCmd pep retract $xmlns(activity) -notify 1
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
	    set activity ""
	    set specific ""
	    set text ""

	    set retractE [wrapper::getfirstchildwithtag $itemsE retract]
	    if {[llength $retractE]} {
		set msg ""
		set state($mjid,mood) ""
		set state($mjid,text) ""
	    } else {
		set itemE [wrapper::getfirstchildwithtag $itemsE item]
		set activityE [wrapper::getfirstchildwithtag $itemE activity]
		if {![llength $activityE]} {
		    return
		}
		foreach E [wrapper::getchildren $activityE] {
		    set tag [wrapper::gettag $E]
		    switch -- $tag {
			text {
			    set text [wrapper::getcdata $E]
			}
			default {
			    set activity $tag
			    set specificE [lindex [wrapper::getchildren $E] 0]
			    if {[llength $specificE]} {
				set specific [wrapper::gettag $specificE]
			    }
			}
		    }
		}
	    
		# Cache the result.
		set state($mjid,activity) $activity
		set state($mjid,specific) $specific
		set state($mjid,text) $text
	    
		if {$activity eq ""} {
		    set msg ""
		} else {
		    set dname [string totitle [string map {_ " "} $activity]]
		    set msg "[mc Activity]: [mc $dname]"
		    if {$specific ne ""} {
			set dname [string totitle [string map {_ " "} $specific]]
			append msg " - [mc $dname]"
		    }
		    if {$text ne ""} {
			append msg " - $text"
		    }
		}
	    }
	    ::RosterTree::BalloonRegister activity $from $msg
	    
	    ::hooks::run activityEvent $xmldata $activity $specific $text
	}
    }
}


