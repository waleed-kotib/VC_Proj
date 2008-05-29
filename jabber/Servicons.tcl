#  Servicons.tcl --
#  
#      This file is part of The Coccinella application. 
#      It implements handling and parsing of service (disco) icons.
#      Icons are specified as in 
#      http://www.xmpp.org/registrar/disco-categories.html
#      where elements like <identity category='client' type='web'/>
#      are mapped to a lookup key client/web and so on.
#      
#  Copyright (c) 2005-2008  Mats Bengtsson
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
# $Id: Servicons.tcl,v 1.18 2008-05-29 08:04:10 matben Exp $

# @@@ TODO: Make servicon sets configurable. See Rosticons.

package require Icondef

package provide Servicons 1.0

namespace eval ::Servicons {

    # Other init hooks depend on us!
    ::hooks::register initHook          ::Servicons::ThemeInitHook    20
    ::hooks::register themeChangedHook  ::Servicons::ThemeChangedHook

    # 'imagesD' contains all available mappings from 'category' and 'type'
    # to images, even if they aren't used.
    variable imagesD [dict create]
    
    # 'tmpImagesD' is for temporary storage only (preferences) and maps
    # from 'themeName', 'category', and 'type' to images.
    variable tmpImagesD [dict create]

    variable stateD [dict create]
        
    variable alias
    array set alias {
	services/jabber       server/im
	headline/rss          headline/newmail
	conference/irc        conference/text
	pubsub/generic        pubsub/service
	search/text           directory/user
    }
}

proc ::Servicons::ThemeInitHook {} {
    variable priv
    variable stateD
    upvar ::Jabber::jprefs jprefs

    set jprefs(disco,themeName) ""
    set names [::Theme::GetAllWithFilter service]
    
    
}

proc ::Servicons::ThemeGet {key} {
    variable imagesD
    variable priv
    variable alias
    
    set key [string map [array get alias] $key]
    lassign [split $key /] category type

    # gadu-gadu shall map to gadugadu but only for image lookup.
    set mtype [string map {"-" ""} $type]
    
    if {$category eq "gateway"} {
	set spec icons/16x16/protocol-$mtype
    } else {
	set spec icons/16x16/service-$category-$mtype
    }
    
    # This is a fast lookup mechanism.
    if {[dict exists $imagesD $category $type]} {
	return [dict get $imagesD $category $type]
    }
    set image [::Theme::FindIcon $spec]
    if {$image ne ""} {
	dict set imagesD $category $type $image 
    }
    return $image
}

proc ::Servicons::ThemeGetFromTypeList {typeL} {

    set len [llength $typeL]
    if {$len == 0} {
	return 
    } elseif {$len == 1} {
	return [ThemeGet [lindex $typeL 0]]
    } else {
	
	# Do a priority lookup.
	foreach cat {server gateway} {
	    set service [lsearch -glob -inline $typeL $cat/*]
	    if {$service ne ""} {
		return [ThemeGet $service]
	    }
	}
	foreach type $typeL {
	    set image [ThemeGet $type]
	    if {$image ne ""} {
		return $image
	    }
	}
    }
    return
}

proc ::Servicons::ThemeChangedHook {} {
    variable imagesD
    
    # We must clear out our cached info since that is outdated.
    unset imagesD
    set imagesD [dict create]
}

#-------------------------------------------------------------------------------
