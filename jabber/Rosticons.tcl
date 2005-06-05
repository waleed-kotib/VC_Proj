#  Rosticons.tcl --
#  
#      This file is part of The Coccinella application. 
#      It implements handling and parsing of roster icons.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: Rosticons.tcl,v 1.12 2005-06-05 14:54:13 matben Exp $

package provide Rosticons 1.0

namespace eval ::Rosticons:: {

    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          ::Rosticons::InitPrefsHook

    # Other init hooks depend on us!
    ::hooks::register initHook               ::Rosticons::Init    20

    variable priv
    set priv(defaultSet) "default"
    set priv(alltypes)   {}
}

proc ::Rosticons::InitPrefsHook { } {
    
    variable priv
    upvar ::Jabber::jprefs jprefs

    set jprefs(rost,iconSet)     "default"
    set jprefs(rost,haveWBicons) 1
    
    # Do NOT store the complete path!
    ::PreferencesUtils::Add [list  \
      [list ::Jabber::jprefs(rost,haveWBicons) jprefs_rost_haveWBicons $jprefs(rost,haveWBicons)] \
      [list ::Jabber::jprefs(rost,iconSet) jprefs_rost_iconSet $jprefs(rost,iconSet)]]

    set jprefs(rost,iconSet)     "default"
    set jprefs(rost,haveWBicons) 1
}

proc ::Rosticons::Init { } {
    global  this
    
    variable priv
    variable state
    upvar ::Jabber::jprefs jprefs

    # 'tmpicons(name,key)' map from status/offline (key) and iconset name
    # to an image name.
    variable tmpicons
    
    # 'tmpiconsInv(name,image)' which is the inverse of the above.
    variable tmpiconsInv

    ::Debug 2 "::Rosticons::Init"
    
    # We need the 'vfs::zip' package and if not using starkit we also need
    # the 'Memchan' package which is not automatically checked for.
    if {[catch {package require vfs::zip}]} {
	set priv(havezip) 0
    } elseif {[info exists starkit::topdir]} {
	set priv(havezip) 1
    } elseif {[catch {package require Memchan}]} {
	set priv(havezip) 0
    } else {
	set priv(havezip) 1
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
    if {![string equal $jprefs(rost,iconSet) $priv(defaultSet)]} {
	if {[lsearch -exact $allSets $jprefs(rost,iconSet)] >= 0} {
	    set name $jprefs(rost,iconSet)  
	    LoadTmpIconSet $state($name,path)
	    SetFromTmp $name
	}
    }
}

proc ::Rosticons::Exists {key} {
    variable rosticons
    
    if {[info exists rosticons($key)]} {
	return 1
    } else {
	return 0
    }
}

# ::Rosticons::Get --
# 
#       Returns the image to use for this key.
#       
# Arguments:
#       statuskey       type/subtype, ex: status/online, icq/xa, whiteboard/dnd
#       
# Results:
#       a valid image.

proc ::Rosticons::Get {statuskey} {
    variable rosticons
    variable priv
    upvar ::Jabber::jprefs jprefs
    
    #::Debug 4 "::Rosticons::Get-------statuskey=$statuskey"
    
    foreach {type sub} [split $statuskey /] break
    set sub [string map {available online unavailable offline} $sub]
    set suborig $sub
    
    # Do we want foreign IM icons?
    if {!$jprefs(rost,haveIMsysIcons)} {
	if {![string equal $type "status"] && \
	  ![string equal $type "whiteboard"]} {
	    set type "status"
	}
    }
    if {!$jprefs(rost,haveWBicons)} {
	set type [string map {whiteboard status} $type]
    }
    set key $type/$sub
    if {[info exists rosticons($key)]} {
	return $rosticons($key)
    }
    
    # See if we can match the 'type'.
    if {[lsearch -exact $priv(alltypes) $type] == -1} {
	return $rosticons(status/$suborig)
    }
    
    # First try to find a fallback for the sub part.
    set sub [string map {invisible offline} $sub]
    set sub [string map {chat online} $sub]
    set key $type/$sub
    if {[info exists rosticons($key)]} {
	return $rosticons($key)
    }
    set sub [string map {xa away} $sub]
    set sub [string map {dnd away} $sub]
    set key $type/$sub
    if {[info exists rosticons($key)]} {
	return $rosticons($key)
    }
    set sub [string map {away online} $sub]
    set key $type/$sub
    if {[info exists rosticons($key)]} {
	return $rosticons($key)
    }
    
    # If still not matched select type=status which must be there.
    return $rosticons(status/$suborig)
}

proc ::Rosticons::GetTypes { } {
    variable priv
   
    return $priv(alltypes)
}

proc ::Rosticons::GetAllSets { } {
    global  this
    variable priv
    variable state
    
    set setList {}
    foreach path [list $this(rosticonsPath) $this(altRosticonsPath)] {
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

# Rosticons::GetPrefSetPathExists --
# 
#       Gets the full path to our rosticons file/folder.
#       Verifies that it exists and that can be mounted if zip archive.

proc ::Rosticons::GetPrefSetPathExists { } {
    global  this
    variable priv
    upvar ::Jabber::jprefs jprefs

    # Start with the failsafe set.
    set path [file join $this(rosticonsPath) $priv(defaultSet)]
    
    foreach dir [list $this(rosticonsPath) $this(altRosticonsPath)] {
	set f [file join $dir $jprefs(rost,iconSet)]
	set fjisp ${f}.jisp
	if {[file exists $f]} {
	    set path $f
	    break
	} elseif {[file exists $fjisp] && $priv(havezip)} {
	    set path $fjisp
	    break
	}
    }
    set jprefs(rost,iconSet) [file rootname [file tail $path]]
    return $path
}
    
proc ::Rosticons::LoadTmpIconSet {path} {
    
    variable state
    variable priv
    
    # The dir variable points to the (virtual) directory containing it all.
    set dir $path
    set name [file rootname [file tail $path]]
    
    if {[string equal [file extension $path] ".jisp"]} {
	if {$priv(havezip)} {
	    set mountpath [file join [file dirname $path] $name]
	    if {[catch {
		set fdzip [vfs::zip::Mount $path $mountpath]
	    } err]} {
		return -code error $err
	    }
	    
	    # We cannot be sure of that the name of the archive is identical 
	    # with the name of the original directory.
	    set zipdir [lindex [glob -nocomplain -directory $mountpath *] 0]
	    set dir $zipdir
	} else {
	    return -code error "cannot read jisp archive without vfs::zip"
	}
    }
    set icondefPath [file join $dir icondef.xml]
    if {![file isfile $icondefPath]} {
	return -code error "missing icondef.xml file in archive"
    }
    set fd [open $icondefPath]
    fconfigure $fd -encoding utf-8
    set xmldata [read $fd]
    close $fd
        
    # Parse data.
    ParseIconDef $name $dir $xmldata
    
    if {[info exists mountpath]} {
	vfs::zip::Unmount $fdzip $mountpath
    }
    set state($name,loaded) 1
}

proc ::Rosticons::ParseIconDef {name dir xmldata} {

    set token [tinydom::parse $xmldata]
    set xmllist [tinydom::documentElement $token]
    
    foreach elem [tinydom::children $xmllist] {
	
	switch -- [tinydom::tagname $elem] {
	    meta {
		ParseMeta $name $dir $elem
	    }
	    icon {
		ParseIcon $name $dir $elem
	    }
	}
    }
    tinydom::cleanup $token
}

proc ::Rosticons::ParseMeta {name dir xmllist} {
    variable meta
    
    array unset meta $name,*
    foreach elem [tinydom::children $xmllist] {
	set tag [tinydom::tagname $elem]
	lappend meta($name,$tag) [tinydom::chdata $elem]
    }
}

proc ::Rosticons::ParseIcon {name dir xmllist} {
    global  this
    
    variable tmpicons
    variable tmpiconsInv
    variable priv

    set mime ""
    
    foreach elem [tinydom::children $xmllist] {
	set tag [tinydom::tagname $elem]
	
	switch -- $tag {
	    x {
		set key [tinydom::chdata $elem]
	    }
	    data {
		# base64 coded image data
		set data [tinydom::chdata $elem]
		array set attrArr [tinydom::attrlist $elem]
		set mime $attrArr(mime)
	    }
	    object {
		set object [tinydom::chdata $elem]
		array set attrArr [tinydom::attrlist $elem]
		set mime $attrArr(mime)
	    }
	}
    }
    
    switch -- $mime {
	image/gif {
	    if {[info exists data]} {
		set im [image create photo -format gif -data $data]
	    } else {
		set im [image create photo -format gif  \
		  -file [file join $dir $object]]
	    }
	    set tmpicons($name,$key) $im
	}
	image/png {
	    # We should not rely on base64 data here since QuickTimeTcl 
	    # doesn't handle it.
	    if {[info exists object]} {
		
		# If we rely on QuickTimeTcl here we cannot be in vfs.
		set f [file join $dir $object]
		if {$priv(needtmp)} {
		    set tmp [::tfileutils::tempfile $this(tmpPath) [file rootname $object]]
		    append tmp [file extension $object]
		    file copy -force $f $tmp
		    set f $tmp
		}
		set im [eval {image create photo -file $f} $priv(pngformat)]
		set tmpicons($name,$key) $im
	    }
	}
    }
    if {[info exists im]} {
	set tmpiconsInv($name,$im) $key
    }
}

proc ::Rosticons::SetFromTmp {name} {
    variable tmpicons
    variable tmpiconsInv
    variable rosticons
    variable rosticonsInv
    variable priv
    
    set types {}
    
    foreach ind [array names tmpiconsInv $name,*] {
	set im [string map [list "$name," ""] $ind]
	set key $tmpiconsInv($ind)
	set rosticons($key) $im
	set rosticonsInv($im) $tmpiconsInv($ind)
	foreach {type sub} [split $key /] break
	lappend types $type
    }
    set priv(alltypes) [lsort -unique [concat $priv(alltypes) $types]]
}

#-------------------------------------------------------------------------------
