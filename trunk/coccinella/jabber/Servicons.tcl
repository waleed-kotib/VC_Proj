#  Servicons.tcl --
#  
#      This file is part of The Coccinella application. 
#      It implements handling and parsing of service (disco) icons.
#      
#      @@@ There is a lot of duplicated code Servicons/Rosticons/Emoticons.
#          Find better way!
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: Servicons.tcl,v 1.1 2005-08-14 07:11:36 matben Exp $

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
    
    variable priv
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

    if {[info exists alias($key)]} {
	set key $alias($key)
    }
    lassign $key category type
    if {[info exists icons($key)]} {
	return $icons($key)
    } else {
	return ""
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

# Servicons::GetPrefSetPathExists --
# 
#       Gets the full path to our servicons file/folder.
#       Verifies that it exists and that can be mounted if zip archive.

proc ::Servicons::GetPrefSetPathExists { } {
    global  this
    variable priv
    upvar ::Jabber::jprefs jprefs

    # Start with the failsafe set.
    set path [file join $this(serviconsPath) $priv(defaultSet)]
    
    foreach dir [list $this(serviconsPath) $this(altServiconsPath)] {
	set f [file join $dir $jprefs(serv,iconSet)]
	set fjisp ${f}.jisp
	if {[file exists $f]} {
	    set path $f
	    break
	} elseif {[file exists $fjisp] && $priv(havezip)} {
	    set path $fjisp
	    break
	}
    }
    set jprefs(serv,iconSet) [file rootname [file tail $path]]
    return $path
}
    
proc ::Servicons::LoadTmpIconSet {path} {
    
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

proc ::Servicons::ParseIconDef {name dir xmldata} {

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

proc ::Servicons::ParseMeta {name dir xmllist} {
    variable meta
    
    array unset meta $name,*
    foreach elem [tinydom::children $xmllist] {
	set tag [tinydom::tagname $elem]
	lappend meta($name,$tag) [tinydom::chdata $elem]
    }
}

proc ::Servicons::ParseIcon {name dir xmllist} {
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
		array set attr [tinydom::attrlist $elem]
		set mime $attr(mime)
	    }
	    object {
		set object [tinydom::chdata $elem]
		array set attr [tinydom::attrlist $elem]
		set mime $attr(mime)
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
