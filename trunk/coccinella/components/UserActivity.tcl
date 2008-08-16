# UserActivity.tcl --
# 
#       User Activity using PEP recommendations over PubSub library code.
#       Implements XEP-0108: User Activity
#
#  Copyright (c) 2007-2008 Mats Bengtsson
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
#  $Id: UserActivity.tcl,v 1.19 2008-08-16 06:51:22 matben Exp $

package require jlib::pep
package require ui::optionmenu

namespace eval ::UserActivity {

    component::define UserActivity \
      "Communicate information about user activities"
}

proc ::UserActivity::Init {} {

    component::register UserActivity

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
    set menuDef [list command mActivity... ::UserActivity::Dlg {} {}]
    
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
    
    variable allSpecific
    set allSpecific [list]
    foreach {key value} [array get subActivities] {
	set allSpecific [concat $allSpecific $value]
    }
    set allSpecific [lsort -unique $allSpecific]
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
    set server [::Jabber::Jlib getserver]
    ::Jabber::Jlib pep have $server [namespace code HavePEP]
    ::Jabber::Jlib pubsub register_event [namespace code Event] \
      -node $xmlns(activity)
}

proc ::UserActivity::HavePEP {jlibname have} {
    variable menuDef
    variable xmlns

    if {$have} {

	# Get our own published activity and fill in.
	# NB: I thought that this should work automatically but seems not.
	set myjid2 [::Jabber::Jlib myjid2]
	::Jabber::Jlib pubsub items $myjid2 $xmlns(activity) \
	  -command [namespace code ItemsCB]

	::JUI::RegisterMenuEntry action $menuDef
	if {[MPExists]} {
	    [MPWin] state {!disabled}
	}
    }
}

proc ::UserActivity::LogoutHook {} {
    
    ::JUI::DeRegisterMenuEntry action mActivity...
    if {[MPExists]} {
	[MPWin] state {disabled}
    }
}

namespace eval ::UserActivity {
    variable dialogL [list]
}

proc ::UserActivity::Dlg {} {
    variable allActivities    
    variable subActivities
    variable xmlns
    variable dialogL
    
    set w [ui::dialog -message [mc activityPickMsg] \
      -detail [mc activityPickDtl] -icon info \
      -buttons {ok cancel remove} \
      -geovariable ::prefs(winGeom,activity) \
      -title [mc "User Activity"] -command [namespace code DlgCmd]]
    set fr [$w clientframe]
    
    # State array variable.
    variable $w
    upvar 0 $w state
    set token [namespace current]::$w
    
    set state(activity) [lindex $allActivities 0]
    set state(specific) -
    set state(text) ""
    set state(all) 0
    
    lappend dialogL $w

    set mDef [list]
    foreach name $allActivities {
	set dname [string totitle [string map {_ " "} $name]]
	lappend mDef [list [mc $dname] -value $name \
	  -image [::Theme::FindIconSize 16 activity-$name]]
    }
    ttk::label $fr.la -text "[mc General]:"
    ui::optionmenu $fr.activity -menulist $mDef -direction flush \
      -variable $token\(activity)
    ttk::label $fr.ls -text "[mc Specific]:"
    ui::optionmenu $fr.specific -direction flush \
      -variable $token\(specific)
    ttk::label $fr.lt -text "[mc Message]:"
    ttk::entry $fr.text -textvariable $token\(text)
    ttk::checkbutton $fr.all -text [mc "Show all specific activities"] \
      -variable $token\(all) -command [namespace code [list DlgAll $w]]
        
    set maxw [$fr.activity maxwidth]

    grid  $fr.la  $fr.activity  -sticky e -pady 1
    grid  $fr.ls  $fr.specific  -sticky e -pady 1
    grid  $fr.lt  $fr.text      -sticky e -pady 1
    grid  x       $fr.all       -sticky e -pady 1
    grid $fr.activity  $fr.specific  $fr.text  -sticky ew
    grid columnconfigure $fr 1 -minsize $maxw

    trace add variable $token\(activity) write [namespace code [list Trace $w]]
    ConfigSpecificMenu $w $state(activity)
    
    bind $fr.activity <Map> { focus %W }
            
    # Get our own published activity and fill in.
    set myjid2 [::Jabber::Jlib  myjid2]
    ::Jabber::Jlib pubsub items $myjid2 $xmlns(activity) \
      -command [namespace code ItemsCB]

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

proc ::UserActivity::DlgAll {w} {
    variable $w
    upvar 0 $w state
 
    ConfigSpecificMenu $w $state(activity)
}

proc ::UserActivity::ConfigSpecificMenu {w activity} {
    variable $w
    upvar 0 $w state
    variable subActivities
    variable allSpecific
        
    set fr [$w clientframe]
    
    set mDef [list]
    lappend mDef [list [mc None] -value "-"]
    lappend mDef [list separator]
    if {$state(all)} {
	foreach name $allSpecific {
	    set dname [string totitle [string map {_ " "} $name]]
	    lappend mDef [list [mc $dname] -value $name \
	      -image [::Theme::FindIconSize 16 activity-$name]]
	}
    } else {
	foreach name $subActivities($activity) {
	    set dname [string totitle [string map {_ " "} $name]]
	    lappend mDef [list [mc $dname] -value $name \
	      -image [::Theme::FindIconSize 16 activity-$name]]
	}
    }
    $fr.specific configure -menulist $mDef
}

proc ::UserActivity::DlgCmd {w bt} {
    variable $w
    upvar 0 $w state
    variable xmlns
    variable dialogL
    
    if {$bt eq "ok"} {
	Publish $state(activity) $state(specific) $state(text)
    } elseif {$bt eq "remove"} {
	Retract
    }
    if {[MPExists]} {
	MPSetActivity $state(activity)
    }
    unset -nocomplain state
    set dialogL [lsearch -inline -all -not $dialogL $w]
}

proc ::UserActivity::ItemsCB {type subiq args} {
    variable xmlns
    variable subActivities
    variable dialogL
    
    if {$type eq "error"} {
	return
    }   
    
    set activity -
    set specific -
    set activityText ""
    
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
			set activityText [wrapper::getcdata $E]
		    }
		    default {
			if {![info exists subActivities($tag)]} {
			    return
			}
			set activity $tag
			set specificE [lindex [wrapper::getchildren $E] 0]
			if {[llength $specificE]} {
			    set specific [wrapper::gettag $specificE]
			    if {[lsearch $subActivities($activity) $specific] < 0} {
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
    if {[MPExists]} {
	MPDisplayActivity $activity
    }
    
    foreach w $dialogL {
	if {[winfo exists $w]} {
	    SetDlg $w $activity $specific $activityText
	}
    }
}

proc ::UserActivity::SetDlg {w activity specific text} {
    variable $w
    upvar 0 $w state
    
    set state(activity) $activity
    set state(specific) $specific
    set state(text) $text
}

proc ::UserActivity::Publish {activity specific text} {
    variable xmlns
    
    set specificE [list]
    if {($specific ne "-") && ($specific ne "")} {
	set specificE [list [wrapper::createtag $specific]]
    }
    set childL [list [wrapper::createtag $activity -subtags $specificE]]
    if {[string trim $text] ne ""} {
	lappend childL [wrapper::createtag "text" \
	  -attrlist [list xml:lang [jlib::getlang]] -chdata $text]
    }
    set activityE [wrapper::createtag "activity" -subtags $childL]

    #   NB:  It is currently unclear there should be an id attribute in the item
    #        element since PEP doesn't use it but pubsub do, and the experimental
    #        OpenFire PEP implementation.
    #set itemE [wrapper::createtag item -subtags [list $activityE]]
    set itemE [wrapper::createtag item \
      -attrlist [list id current] -subtags [list $activityE]]

    ::Jabber::Jlib pep publish $xmlns(activity) $itemE
}

proc ::UserActivity::Retract {} {
    variable xmlns

    ::Jabber::Jlib pep retract $xmlns(activity) -notify 1
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

#--- Mega Presence Hook --------------------------------------------------------

namespace eval ::UserActivity {
    
    ::MegaPresence::Register activity [mc Activity] [namespace code MPBuild]
    
    variable mpwin "-"
    variable imblank
    set imblank [image create photo -height 16 -width 16]
    $imblank blank
}

proc ::UserActivity::MPBuild {win} {
    variable imblank
    variable mpwin
    variable allActivities    
    variable mpActivity

    set mpwin $win
    ttk::menubutton $win -style SunkenMenubutton \
      -image $imblank -compound image

    set m $win.m
    menu $m -tearoff 0
    $win configure -menu $m
    $win state {disabled}
    
    $m add radiobutton -label [mc None] -value "-" \
      -variable [namespace current]::mpActivity \
      -command [namespace code MPCmd]
    $m add separator
      
    foreach activity $allActivities {
	set dname [string totitle [string map {_ " "} $activity]]
	$m add radiobutton -label [mc $dname] -value $activity \
	  -image [::Theme::FindIconSize 16 activity-$activity] \
	  -variable [namespace current]::mpActivity \
	  -command [namespace code MPCmd] -compound left
    }    
    $m add separator
    $m add command -label [mc Dialog]... -command [namespace code Dlg]
    
    set mpActivity "-"
    return
}

proc ::UserActivity::MPCmd {} {
    variable mpwin
    variable mpActivity
    variable imblank
    
    if {$mpActivity eq "-"} {
	Retract
    } else {
	Publish $mpActivity "" ""
    }
    MPDisplayActivity $mpActivity
}

proc ::UserActivity::MPDisplayActivity {activity} {
    variable mpwin
    variable mpActivity
    variable imblank

    set mpActivity $activity
    
    if {$activity eq "-"} {
	$mpwin configure -image $imblank
	::balloonhelp::balloonforwindow $mpwin "[mc Activity]: [mc None]"
    } else {
	set dname [string totitle [string map {_ " "} $activity]]
	$mpwin configure -image [::Theme::FindIconSize 16 activity-$activity]	
	::balloonhelp::balloonforwindow $mpwin "[mc Activity]: [mc $dname]"
    }
}

proc ::UserActivity::MPSetActivity {activity} {
    variable mpActivity
    set mpActivity $activity
    MPCmd
}

proc ::UserActivity::MPExists {} {
    variable mpwin
    return [winfo exists $mpwin]
}

proc ::UserActivity::MPWin {} {
    variable mpwin
    return $mpwin
}

