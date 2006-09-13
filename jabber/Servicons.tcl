#  Servicons.tcl --
#  
#      This file is part of The Coccinella application. 
#      It implements handling and parsing of service (disco) icons.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: Servicons.tcl,v 1.3 2005-11-16 08:52:03 matben Exp $

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
    set priv(havepng)      [::Plugins::HaveImporterForMime image/png]
    set priv(QuickTimeTcl) [::Plugins::HavePackage QuickTimeTcl]
    set priv(Img)          [::Plugins::HavePackage Img]
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
#       a valid image.

proc ::Servicons::Get {key} {
    variable icons
    variable priv
    variable alias

    # @@@ For gateways we could use a rosticon instead to get the sets match
    
    if {[info exists alias($key)]} {
	set key $alias($key)
    }
    lassign $key category type
    if {[info exists icons($key)]} {
	return $icons($key)
    } else {
	return
    }
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