#  Servicons.tcl --
#  
#      This file is part of The Coccinella application. 
#      It implements handling and parsing of service (disco) icons.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: Servicons.tcl,v 1.8 2007-05-19 14:37:24 matben Exp $

package require Icondef

package provide Servicons 1.0

namespace eval ::Servicons:: {

    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          ::Servicons::InitPrefsHook

    # Other init hooks depend on us!
    ::hooks::register initHook               ::Servicons::Init    20

    variable priv
    set priv(defaultSet) "default"
    set priv(alltypes)   {}
    
    variable alias
    array set alias {
	services/jabber       server/im
	headline/rss          headline/newmail
	conference/irc        conference/text
	pubsub/generic        pubsub/service
	search/text           directory/user
    }
}

proc ::Servicons::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs

    set jprefs(serv,iconSet)  "default"    
}

proc ::Servicons::Init { } {
    global  this
    
    variable priv
    variable state
    upvar ::Jabber::jprefs jprefs

    # 'tmpicons(name,key)' map from category/type (key) and iconset name
    # to an image name.
    variable tmpicons
    
    # 'tmpiconsInv(name,image)' which is the inverse of the above.
    variable tmpiconsInv

    ::Debug 2 "::Servicons::Init"
    
    # We need the 'vfs::zip' package and if not using starkit we also need
    # the 'Memchan' package which is not automatically checked for.
    # 'rechan' is the tclkits built in version of 'Memchan'.
    if {[catch {package require vfs::zip}]} {
	set priv(havezip) 0
    } elseif {![catch {package require rechan}]} {
	set priv(havezip) 1
    } elseif {![catch {package require Memchan}]} {
	set priv(havezip) 1
    } else {
	set priv(havezip) 0
    }

    # Cache stuff we need later.
    set priv(havepng)      [::Media::HaveImporterForMime image/png]
    set priv(QuickTimeTcl) [::Media::HavePackage QuickTimeTcl]
    set priv(Img)          [::Media::HavePackage Img]
    if {$priv(Img)} {
	set priv(needtmp)   0
	set priv(pngformat) [list -format png]
    } else {
	set priv(needtmp)   1
	set priv(pngformat) {}
    }

    set allSets [GetAllSets]
    ::Debug 4 "\t allSets=$allSets"
    
    # The default set.
    LoadTmpIconSet $state(default,path)
    SetFromTmp default

    # Any other set.
    if {![string equal $jprefs(serv,iconSet) $priv(defaultSet)]} {
	if {[lsearch -exact $allSets $jprefs(serv,iconSet)] >= 0} {
	    set name $jprefs(serv,iconSet)  
	    LoadTmpIconSet $state($name,path)
	    SetFromTmp $name
	}
    }
}

proc ::Servicons::Exists {key} {
    variable icons
    
    if {[info exists icons($key)]} {
	return 1
    } else {
	return 0
    }
}

# ::Servicons::Get --
# 
#       Returns the image to use for this key.
#       
# Arguments:
#       key       category/type, ex: conference/text, gateway/icq
#       
# Results:
#       a valid image or empty.

proc ::Servicons::Get {key} {
    variable icons
    variable priv
    variable alias

    # @@@ For gateways we could use a rosticon instead to get the sets match
    
    set key [string map [array get alias] $key]
    if {[string match gateway/* $key]} {
	set gtype [lindex [split $key /] 1]/available
	return [::Rosticons::Get $gtype]
    } elseif {[info exists icons($key)]} {
	return $icons($key)
    } else {
	return ""
    }
}

# Servicons::GetFromTypeList --
# 
#       As Get but takes a category/type list and searches this in priority.

proc ::Servicons::GetFromTypeList {typelist} {
    variable icons
    variable priv
    variable alias
    
    if {![llength $typelist]} {
	return ""
    }
    set typelist [string map [array get alias] $typelist]
    
    # Do a priority search: server, gateway, and the rest...
    set sorted [list]
    lappend sorted [lsearch -glob -inline $typelist server/*]
    lappend sorted [lsearch -glob -inline $typelist gateway/*]
    set typelist [lsearch -glob -inline -not -all $typelist server/*]
    set typelist [lsearch -glob -inline -not -all $typelist gateway/*]
    set sorted [concat $sorted $typelist]
    
    foreach type $sorted {
	if {[string match gateway/* $type]} {
	    set gtype [lindex [split $type /] 1]/available
	    return [::Rosticons::Get $gtype]
	} elseif {[info exists icons($type)]} {
	    return $icons($type)
	}
    }
    return ""
}

proc ::Servicons::GetTypes { } {
    variable priv
   
    return $priv(alltypes)
}

proc ::Servicons::GetAllSets { } {
    global  this
    variable priv
    variable state
    
    set setList {}
    foreach path [list $this(serviconsPath) $this(altServiconsPath)] {
	foreach f [glob -nocomplain -directory $path *] {
	    set name [file tail $f]
	    set name [file rootname $name]
	    if {[string equal [file extension $f] ".jisp"] && $priv(havezip)} {
		lappend setList $name
		set state($name,path) $f
	    } elseif {[file isdirectory $f]} {
		if {[file exists [file join $f icondef.xml]]} {
		    lappend setList $name
		    set state($name,path) $f
		}
	    }
	}
    }
    return $setList
}
    
proc ::Servicons::LoadTmpIconSet {path} {    
    variable state
    variable meta
    variable tmpicons
    variable tmpiconsInv
    variable priv
    variable mdata
    variable idata

    set name [::Icondef::Load $path  \
      [namespace current]::idata     \
      [namespace current]::mdata]

    array unset meta $name,*
    foreach {key value} [array get mdata] {
	set meta($name,$key) $value
    }
    
    array unset tmpicons    $name,*
    array unset tmpiconsInv $name,*

    foreach {typesubtype image} [array get idata] {
	set tmpicons($name,$typesubtype) $image
	set tmpiconsInv($name,$image)    $typesubtype
    }    
    set state($name,loaded) 1

    unset -nocomplain mdata
    unset -nocomplain idata
}

proc ::Servicons::SetFromTmp {name} {
    variable tmpicons
    variable tmpiconsInv
    variable icons
    variable iconsInv
    variable priv
    
    set types {}
    
    foreach ind [array names tmpiconsInv $name,*] {
	set im [string map [list "$name," ""] $ind]
	set key $tmpiconsInv($ind)
	set icons($key) $im
	set iconsInv($im) $tmpiconsInv($ind)
	foreach {type sub} [split $key /] break
	lappend types $type
    }
    set priv(alltypes) [lsort -unique [concat $priv(alltypes) $types]]
}

#-------------------------------------------------------------------------------
