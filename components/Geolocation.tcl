# Geolocation.tcl --
# 
#       User geolocation using PEP recommendations over PubSub library code.
#
#  Copyright (c) 2007 Mats Bengtsson
#  
#  $Id: Geolocation.tcl,v 1.1 2007-04-06 14:02:55 matben Exp $

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
    variable gearth 0
    
    set str "Set your geographic location that will be shown to other users."
    set dtl "Enter the information you have available below. A minimal list contains only latitude and longitude."
    set w [ui::dialog -message $str -detail $dtl -icon info \
      -type okcancel -modal 1 -geovariable ::prefs(winGeom,geoloc) \
      -title "User Geolocation" -command [namespace code DlgCmd]]
    set fr [$w clientframe]
    
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
	ttk::entry $fr.e$name -textvariable $w\($name)
	
	grid  $fr.l$name  $fr.e$name  -sticky e -pady 2
	grid $fr.e$name -sticky ew
    }

    ttk::checkbutton $fr.gearth -style Small.TCheckbutton \
      -variable [namespace current]::gearth \
      -text "Synchronize your geographic data with Google Earth"
    
    $fr.gearth state {disabled}
    
    grid  $fr.gearth  -  -sticky w
    grid columnconfigure $fr 1 -weight 1
    
    
    set mbar [::UI::GetMainMenu]
    ui::dialog defaultmenu $mbar
    ::UI::MenubarDisableBut $mbar edit
    $w grab    
    ::UI::MenubarEnableAll $mbar
}

proc ::Geolocation::DlgCmd {w bt} {

    if {$bt eq "ok"} {
	
	
	
	
    }
}

