# Geolocation.tcl --
# 
#       User location using XEP recommendations over PubSub library code.
#       XEP-0080: User Location (formerly User Geolocation)
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
#  $Id: Geolocation.tcl,v 1.11 2007-09-02 13:39:38 matben Exp $

package require jlib::pep

namespace eval ::Geolocation:: { }

proc ::Geolocation::Init { } {

    component::register Geolocation "This is Geo Location (XEP-0080)."

    # Add event hooks.
    ::hooks::register jabberInitHook        ::Geolocation::JabberInitHook
    ::hooks::register loginHook             ::Geolocation::LoginHook
    ::hooks::register logoutHook            ::Geolocation::LogoutHook
    ::hooks::register buildUserInfoDlgHook  ::Geolocation::UserInfoHook

    variable xmlns
    set xmlns(geoloc)        "http://jabber.org/protocol/geoloc"
    set xmlns(geoloc+notify) "http://jabber.org/protocol/geoloc+notify"
    set xmlns(node_config)   "http://jabber.org/protocol/pubsub#node_config"

    variable menuDef
    set menuDef [list command Geolocation... ::Geolocation::Dlg {} {}]
    
    # These help strings are for the message catalogs.
    variable help
    set	help(alt)         "Altitude in meters above or below sea level"
    set	help(area)        "A named area such as a campus or neighborhood"
    set	help(bearing)     "GPS bearing (direction in which the entity is heading to reach its next waypoint), measured in decimal degrees relative to true north"
    set	help(building)    "A specific building on a street or in an area"
    set	help(country)     "The nation where the user is located"
    set	help(datum)       "GPS datum"
    set	help(description) "A natural-language name for or description of the location"
    set	help(error)       "Horizontal GPS error in arc minutes"
    set	help(floor)       "A particular floor in a building"
    set	help(lat)         "Latitude in decimal degrees North"
    set	help(locality)    "A locality within the administrative region, such as a town or city"
    set	help(lon)         "Longitude in decimal degrees East"
    set	help(postalcode)  "A code used for postal delivery"
    set	help(region)      "An administrative region of the nation, such as a state or province"
    set	help(room)        "A particular room in a building"
    set	help(street)      "A thoroughfare within the locality, or a crossing of two thoroughfares"
    set	help(text)        "A catch-all element that captures any other information about the location"
    set	help(timestamp)   "UTC timestamp specifying the moment when the reading was taken"
    
    variable taglabel
    set	taglabel(alt)         [mc {Altitude}]
    set	taglabel(area)        [mc {Named Area}]
    set	taglabel(bearing)     [mc {GPS Bearing}]
    set	taglabel(building)    [mc {Building}]
    set	taglabel(country)     [mc {Country}]
    set	taglabel(datum)       [mc {GPS Datum}]
    set	taglabel(description) [mc {Description}]
    set	taglabel(error)       [mc {GPS Error}]
    set	taglabel(floor)       [mc {Floor}]
    set	taglabel(lat)         [mc {Latitude}]
    set	taglabel(locality)    [mc {Locality}]
    set	taglabel(lon)         [mc {Longitude}]
    set	taglabel(postalcode)  [mc {Postalcode}]
    set	taglabel(region)      [mc {Region}]
    set	taglabel(room)        [mc {Room}]
    set	taglabel(street)      [mc {Street}]
    set	taglabel(text)        [mc {Text}]
    set	taglabel(timestamp)   [mc {Timestamp}]
    
    # string is the default if not defined.
    variable xs
    array set xs {
	alt         decimal
	bearing     decimal
	error       decimal
	lat         decimal
	lon         decimal
	timestamp   datetime
    }
    
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
	::JUI::RegisterMenuEntry action $menuDef
    }
}

proc ::Geolocation::LogoutHook {} {
    variable state
    
    ::JUI::DeRegisterMenuEntry action Geolocation...
    unset -nocomplain state
}

proc ::Geolocation::Dlg {} {
    variable xmlns
    variable gearth 0
    variable taglabel
    
    set w [ui::dialog -message [mc locationPickMsg] \
      -detail [mc locationPickDtl] -icon internet \
      -buttons {ok cancel remove} -modal 1 \
      -geovariable ::prefs(winGeom,geoloc) \
      -title [mc "User Location"] -command [namespace code DlgCmd]]
    set fr [$w clientframe]
    
    # State array variable.
    variable $w
    upvar 0 $w state
    set token [namespace current]::$w

    foreach name {
	alt
	country
	lat
	lon
    } {
	set str $taglabel($name)
	ttk::label $fr.l$name -text ${str}:
	ttk::entry $fr.e$name -textvariable $token\($name)
	
	grid  $fr.l$name  $fr.e$name  -sticky e -pady 2
	grid $fr.e$name -sticky ew
	
	set str [mc location[string totitle $name]]
	::balloonhelp::balloonforwindow $fr.l$name $str
	::balloonhelp::balloonforwindow $fr.e$name $str
    }
    
    ttk::button $fr.www -style Url -text www.mapquest.com \
      -command [namespace code [list LaunchUrl $w]]
    
    grid  x  $fr.www  -sticky w

    ttk::checkbutton $fr.gearth -style Small.TCheckbutton \
      -variable [namespace current]::gearth \
      -text [mc "Synchronize your data with Google Earth"]
    
    $fr.gearth state {disabled}
    
    grid  $fr.gearth  -  -sticky w
    grid columnconfigure $fr 1 -weight 1
    
    # Have some validation.
    foreach name [list alt lat lon] {
	$fr.e$name configure -validate key \
	  -validatecommand [namespace code [list ValidateF %d %P]]    
    }
    trace add variable $token\(lat) write [namespace code [list Trace $w]]
    trace add variable $token\(lon) write [namespace code [list Trace $w]]

    set state(lat) ""
    set state(lon) ""
    
    # Get our own published geolocation and fill in.
    set myjid2 [::Jabber::JlibCmd  myjid2]
    set cb [namespace code [list ItemsCB $w]]
    ::Jabber::JlibCmd pubsub items $myjid2 $xmlns(geoloc) -command $cb
        
    set mbar [::UI::GetMainMenu]
    ui::dialog defaultmenu $mbar
    ::UI::MenubarDisableBut $mbar edit
    $w grab    
    ::UI::MenubarEnableAll $mbar
}

proc ::Geolocation::Trace {w name1 name2 op} {
    variable $w
    upvar 0 $w state
        
    set fr [$w clientframe]
    if {($state(lat) ne "") && ($state(lon) ne "")} {
	$fr.www state {!disabled}
    } else {
	$fr.www state {disabled}    
    }
}

proc ::Geolocation::LaunchUrl {w} {
    variable $w
    upvar 0 $w state

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

proc ::Geolocation::ItemsCB {w type subiq args} {
    variable $w
    upvar 0 $w state
    variable xmlns
    
    if {$type eq "error"} {
	return
    }
    
    # Fill in the form.
    if {[winfo exists $w]} {
	foreach itemsE [wrapper::getchildren $subiq] {
	    set tag [wrapper::gettag $itemsE]
	    set node [wrapper::getattribute $itemsE "node"]
	    if {[string equal $tag "items"] && [string equal $node $xmlns(geoloc)]} {
		set itemE [wrapper::getfirstchildwithtag $itemsE item]
		set geolocE [wrapper::getfirstchildwithtag $itemE geoloc]
		if {![llength $geolocE]} {
		    return
		}
		foreach E [wrapper::getchildren $geolocE] {
		    set tag  [wrapper::gettag $E]
		    set data [wrapper::getcdata $E]
		    if {[string length $data]} {
			set state($tag) $data
		    }
		}
	    }
	}
    }
}

proc ::Geolocation::DlgCmd {w bt} {
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
    set geolocE [wrapper::createtag "geoloc" \
      -attrlist [list xml:lang [jlib::getlang]] -subtags $childL]

    #   NB:  It is currently unclear there should be an id attribute in the item
    #        element since PEP doesn't use it but pubsub do, and the experimental
    #        OpenFire PEP implementation.
    #set itemE [wrapper::createtag item -subtags [list $geolocE]]
    set itemE [wrapper::createtag item \
      -attrlist [list id current] -subtags [list $geolocE]]

    ::Jabber::JlibCmd pep publish $xmlns(geoloc) $itemE
}

proc ::Geolocation::Retract {w} {
    variable xmlns

    ::Jabber::JlibCmd pep retract $xmlns(geoloc) -notify 1
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
}

proc ::Geolocation::UserInfoHook {jid wnb} {
    variable xmlns
    variable geoloc
    variable help
    variable taglabel

    set mjid [jlib::jidmap [jlib::barejid $jid]]
    if {![info exists geoloc($mjid)]} {
	return
    }
    
    $wnb add [ttk::frame $wnb.geo] -text [mc {Geo}] -sticky news

    set wpage $wnb.geo.f
    ttk::frame $wpage -padding [option get . notebookPagePadding {}]
    pack  $wpage  -side top -anchor [option get . dialogAnchor {}]

    ttk::label $wpage._lbl -text [mc "This is location data for"]
    grid  $wpage._lbl  -  -pady 2
    
    ttk::button $wpage.mapquest -style Url -text www.mapquest.com
    grid  $wpage.mapquest  -  -pady 2
    $wpage.mapquest state {disabled}
    
    # Extract all geoloc data we have cached and write an entry for each.
    set xmldata $geoloc($mjid)
    set eventE [wrapper::getfirstchildwithtag $xmldata event]
    if {[llength $eventE]} {
	foreach itemsE [wrapper::getchildren $eventE] {
	    set tag [wrapper::gettag $itemsE]
	    set node [wrapper::getattribute $itemsE "node"]
	    if {[string equal $tag "items"] && [string equal $node $xmlns(geoloc)]} {
		set itemE [wrapper::getfirstchildwithtag $itemsE item]
		set geolocE [wrapper::getfirstchildwithtag $itemE geoloc]
		if {![llength $geolocE]} {
		    return
		}
		foreach E [wrapper::getchildren $geolocE] {
		    set tag  [wrapper::gettag $E]
		    set data [wrapper::getcdata $E]
		    set state($tag) $data
		    if {[string length $data]} {
			
			set str $taglabel($tag)
			ttk::label $wpage.l$tag -text ${str}:
			ttk::label $wpage.e$tag -text $data
			
			grid  $wpage.l$tag  $wpage.e$tag  -pady 2
			grid $wpage.l$tag -sticky e
			grid $wpage.e$tag -sticky w
			
			set bstr [mc location[string totitle $tag]]
			::balloonhelp::balloonforwindow $wpage.l$tag $bstr
			::balloonhelp::balloonforwindow $wpage.e$tag $bstr
		    }
		}
	    }
	}
    }    
    if {[info exists state(lat)] && [info exists state(lon)]} {
	$wpage.mapquest state {!disabled}
	set url "http://www.mapquest.com/maps/map.adp?latlongtype=decimal&latitude=$state(lat)&longitude=$state(lon)"
	$wpage.mapquest configure -command [list ::Utils::OpenURLInBrowser $url]
    }
}


