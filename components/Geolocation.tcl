# Geolocation.tcl --
# 
#       User geolocation using PEP recommendations over PubSub library code.
#
#  Copyright (c) 2007 Mats Bengtsson
#  
#  $Id: Geolocation.tcl,v 1.2 2007-04-07 13:52:44 matben Exp $

package require jlib::pep

namespace eval ::Geolocation:: { }

proc ::Geolocation::Init { } {

    component::register Geolocation "This is Geo Location (XEP-010?)."

    # Add event hooks.
    ::hooks::register jabberInitHook        ::Geolocation::JabberInitHook
    ::hooks::register loginHook             ::Geolocation::LoginHook
    ::hooks::register logoutHook            ::Geolocation::LogoutHook

    variable xmlns
    set xmlns(geoloc)        "http://jabber.org/protocol/geoloc"
    set xmlns(geoloc+notify) "http://jabber.org/protocol/geoloc+notify"
    set xmlns(node_config)   "http://jabber.org/protocol/pubsub#node_config"

    variable menuDef
    set menuDef [list command Geolocation ::Geolocation::Dlg {} {}]
    
    variable help
    set help(alt)       "Altitude in meters above or below sea level"
    set help(country)   "The nation where the user is located"
    set help(lat)       "Latitude in decimal degrees North"
    set help(lon)       "Longitude in decimal degrees East"
    
    # This is our cache for other users geoloc.
    variable geoloc
    
    ui::dialog button remove -text [mc Remove]
}

# Geolocation::JabberInitHook --
# 
#       Here we announce that we have Geolocation support and is interested in
#       getting notifications.

proc ::Geolocation::JabberInitHook {jlibname} {
    variable xmlns
    
    set E [list]
    lappend E [wrapper::createtag "identity"  \
      -attrlist [list category hierarchy type leaf name "Geolocation"]]
    lappend E [wrapper::createtag "feature" \
      -attrlist [list var $xmlns(geoloc)]]    
    lappend E [wrapper::createtag "feature" \
      -attrlist [list var $xmlns(geoloc+notify)]]
    
    $jlibname caps register geoloc $E [list $xmlns(geoloc) $xmlns(geoloc+notify)]
}

proc ::Geolocation::LoginHook {} {
    variable xmlns
   
    # Disco server for pubsub/pep support.
    set server [::Jabber::JlibCmd getserver]
    ::Jabber::JlibCmd pep have $server [namespace code HavePEP]
    ::Jabber::JlibCmd pubsub register_event [namespace code Event] \
      -node $xmlns(geoloc)
}

proc ::Geolocation::HavePEP {jlibname have} {
    variable menuDef

    if {$have} {
	::JUI::RegisterMenuEntry jabber $menuDef
    }
}

proc ::Geolocation::LogoutHook {} {
    variable state
    
    ::JUI::DeRegisterMenuEntry jabber Geolocation
    unset -nocomplain state
}

proc ::Geolocation::Dlg {} {
    variable xmlns
    variable gearth 0
    variable help
    
    set str "Set your geographic location that will be shown to other users."
    set dtl "Enter the information you have available below. A minimal list contains only latitude and longitude."
    set w [ui::dialog -message $str -detail $dtl -icon internet \
      -buttons {ok cancel remove} -modal 1 \
      -geovariable ::prefs(winGeom,geoloc) \
      -title "User Geolocation" -command [namespace code DlgCmd]]
    set fr [$w clientframe]
    
    # State array variable.
    variable $w
    upvar 0 $w state
    set token [namespace current]::$w

    set state(lat) ""
    set state(lon) ""

    foreach name {
	alt
	country
	lat
	lon
    } str {
	Altitude
	Country
	Latitude
	Longitude
    } {
	ttk::label $fr.l$name -text [mc $str]:
	ttk::entry $fr.e$name -textvariable $token\($name)
	
	grid  $fr.l$name  $fr.e$name  -sticky e -pady 2
	grid $fr.e$name -sticky ew
	
	::balloonhelp::balloonforwindow $fr.l$name $help($name)
	::balloonhelp::balloonforwindow $fr.e$name $help($name)
    }
    
    ttk::button $fr.www -style Url -text www.mapquest.com \
      -command [namespace code [list LaunchUrl $w]]
    
    grid  x  $fr.www  -sticky w

    ttk::checkbutton $fr.gearth -style Small.TCheckbutton \
      -variable [namespace current]::gearth \
      -text "Synchronize your data with Google Earth"
    
    $fr.gearth state {disabled}
    
    grid  $fr.gearth  -  -sticky w
    grid columnconfigure $fr 1 -weight 1
    
    # Have some validation.
    foreach name [list alt lat lon] {
	$fr.e$name configure -validate key \
	  -validatecommand [namespace code [list ValidateF %d %P]]    
    }
    
    # Get our own published geolocation and fill in.
    set myjid2 [::Jabber::JlibCmd  myjid2]
    set cb [namespace code [list DiscoCB $w]]
    ::Jabber::JlibCmd disco get_async info $myjid2 $cb -node $xmlns(geoloc)
        
    set mbar [::UI::GetMainMenu]
    ui::dialog defaultmenu $mbar
    ::UI::MenubarDisableBut $mbar edit
    $w grab    
    ::UI::MenubarEnableAll $mbar
}

proc ::Geolocation::LaunchUrl {w} {
    variable $w
    upvar 0 $w state
    
    parray state
 
    set lat $state(lat)
    set lon $state(lon)
    set url "http://www.mapquest.com/maps/map.adp?latlongtype=decimal&latitude=${lat}&longitude=${lon}"
    ::Utils::OpenURLInBrowser $url    
}

proc ::Geolocation::ValidateF {insert P} {
    if {$insert} {
	set valid [string is double -strict $P]
	if {!$valid} {
	    bell
	}
	return $valid
    } else {
	return 1
    }
}

proc ::Geolocation::DiscoCB {w jlibname type from queryE args} {
    variable $w
    upvar 0 $w state
    
    puts "::Geolocation::DiscoCB $queryE"
    
    # Fill in the form.
    if {[winfo exists $w]} {
	
	
    }
}

proc ::Geolocation::DlgCmd {w bt} {
    variable $w
    upvar 0 $w state
    variable xmlns
    
    puts "::Geolocation::DlgCmd $bt"
    
    if {$bt eq "ok"} {
	Publish $w
    } elseif {$bt eq "remove"} {
	Retract $w
    }
    unset -nocomplain state
}

proc ::Geolocation::Publish {w} {
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
    set geolocE [list [wrapper::createtag "geoloc" \
      -attrlist [list xml:lang [jlib::getlang]] -subtags $childL]]
    set itemE [wrapper::createtag item -subtags [list $geolocE]]

    ::Jabber::JlibCmd pep publish $xmlns(geoloc) $itemE
}

proc ::Geolocation::Retract {w} {
    variable xmlns

    ::Jabber::JlibCmd pep retract $xmlns(geoloc)
}

# Geolocation::Event --
# 
#       Mood event handler for incoming geoloc messages.

proc ::Geolocation::Event {jlibname xmldata} {
    variable geoloc
    
    # The server MUST set the 'from' address on the notification to the 
    # bare JID (<node@domain.tld>) of the account owner.
    set from [wrapper::getattribute $xmldata from]
    set from [jlib::jidmap $from]
    set geoloc($from) $xmldata

    ::hooks::run geolocEvent $xmldata

    return

    # Use this code for discoCB instead!
    
    set eventE [wrapper::getfirstchildwithtag $xmldata event]
    if {[llength $eventE]} {
	set itemsE [wrapper::getfirstchildwithtag $eventE items]
	if {[llength $itemsE]} {
	    set itemE [wrapper::getfirstchildwithtag $itemsE item]
	    set geolocE [wrapper::getfirstchildwithtag $itemE geoloc]
	    if {![llength $geolocE]} {
		return
	    }
	    foreach E [wrapper::getchildren $geolocE] {
		set tag  [wrapper::gettag $E]
		set data [wrapper::getcdata $E]
		set
	    
	    
	    }
	}
    }
}



