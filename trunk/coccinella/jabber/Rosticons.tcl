#  Rosticons.tcl --
#  
#      This file is part of The Coccinella application. 
#      It implements handling and parsing of roster icons.
#      
#  Copyright (c) 2005-2007  Mats Bengtsson
#  
# $Id: Rosticons.tcl,v 1.30 2007-03-18 08:01:06 matben Exp $

#  Directory structure: Each key that defines an icon is 'type/subtype'.
#  Each iconset must contain only one type and be placed in the directory
#  roster/'type'/. 
#
#   roster/        aim/
#          application/
#            gadu-gadu/
#                  icq/
#                  msn/
#                 smtp/
#               status/
#           whiteboard/
#                yahoo/
#                
#  The 'status' type is the usual jabber icons. The 'application' type is 
#  special since it sets the other icons used in the roster tree.
#  Each group must have a default dir or default.jisp archive.
#  The set named 'default' is a fallback set. The actual default set is
#  defined in the 'defaultSet' array.
#
#  From disco-categories:
#
#  The "gateway" category consists of translators between Jabber/XMPP services 
#  and non-Jabber services. 
#
#   aim         Gateway to AOL IM               <identity category='gateway' type='aim'/> 
#   gadu-gadu   Gateway to the Gadu-Gadu        <identity category='gateway' type='gadu-gadu'/> 
#   http-ws     Gateway that provides HTTP Web Services access  <identity category='gateway' type='http-ws'/> 
#   icq         Gateway to ICQ                  <identity category='gateway' type='icq'/> 
#   msn         Gateway to MSN Messenger        <identity category='gateway' type='msn'/> 
#   qq          Gateway to the QQ IM service    <identity category='gateway' type='qq'/> 
#   sms         Gateway to Short Message Service  <identity category='gateway' type='sms'/> 
#   smtp        Gateway to the SMTP (email) network  <identity category='gateway' type='smtp'/> 
#   tlen        Gateway to the Tlen IM service  <identity category='gateway' type='tlen'/> 
#   yahoo       Gateway to Yahoo! Instant Messenger  <identity category='gateway' type='yahoo'/> 

package require Icondef

package provide Rosticons 1.0

namespace eval ::Rosticons:: {

    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          ::Rosticons::InitPrefsHook
    ::hooks::register prefsBuildHook         ::Rosticons::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::Rosticons::SavePrefsHook
    ::hooks::register prefsCancelHook        ::Rosticons::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::Rosticons::UserDefaultsHook

    # Other init hooks depend on us!
    ::hooks::register initHook               ::Rosticons::Init    20
    
    # The sets made default (not the named default) MUST always exist!
    variable defaultSet
    array set defaultSet {
	aim             "Crystal"
	application     "Crystal"
	gadu-gadu       "default"
	gadugadu        "default"
	icq             "Crystal"
	msn             "Crystal"
	phone           "plain"
	smtp            "default"
	status          "Crystal"
	whiteboard      "default"
	yahoo           "Crystal"
    }

    variable priv
    set priv(types) [array names defaultSet]
}

proc ::Rosticons::Init { } {
    global  this
    
    variable priv
    variable state
    variable defaultSet
    upvar ::Jabber::jprefs jprefs

    # 'tmpicons(name,key)' map from status/offline (key) and iconset name
    # to an image name.
    variable tmpicons
    
    # 'tmpiconsInv(name,image)' which is the inverse of the above.
    variable tmpiconsInv

    ::Debug 2 "::Rosticons::Init"
    
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
    
    # Investigates all sets available per 'type' and 'name' but doesn't
    # process anything.
    GetAllTypeSets
    
    # Treat each 'type' in turn. Verify that exists. defaultSet as fallback.
    foreach type $state(types) {
	set name $jprefs(rost,icons,$type)
	if {![info exists state(path,$type,$name)]} {
	    set name $defaultSet($type)
	}
	LoadTmpIconSet $type $name
	SetFromTmp $type $name
    }

}

proc ::Rosticons::Exists {key} {
    variable icons
    
    if {[info exists icons($key)]} {
	return 1
    } else {
	return 0
    }
}

proc ::Rosticons::GetTypes { } {
    variable state
   
    return $state(types)
}

# Rosticons::GetAllTypeSets --
# 
#       Info stored in 'state' array as:
#       
#       state(name,$type,$name) name
#       state(type,$type,$name) type
#       state(path,$type,$name) path
#       
#       state(names,$type) listOfNames
#       state(types)       listOfTypes
#       
#       type is typically:
#       aim application gadu-gadu icq msn status whiteboard yahoo

proc ::Rosticons::GetAllTypeSets { } {
    global  this
    variable priv
    variable state
    
    array unset state name,*
    array unset state path,*
    array unset state type,*
    array unset state names,*
    array unset state types
    
    foreach path [list $this(rosticonsPath) $this(altRosticonsPath)] {
	foreach tdir [glob -nocomplain -type d -directory $path *] {
	    set type [file tail $tdir]
	    if {$type eq "CVS"} {
		continue
	    }
	    
	    # For each type dir find all sets for this type.
	    foreach f [glob -nocomplain -directory $tdir *] {
		set name [file tail $f]
		set name [file rootname $name]
		if {[string equal [file extension $f] ".jisp"] && $priv(havezip)} {
		    set state(name,$type,$name) $name
		    set state(type,$type,$name) $type
		    set state(path,$type,$name) $f
		} elseif {[file isdirectory $f]} {
		    if {[file exists [file join $f icondef.xml]]} {
			set state(name,$type,$name) $name
			set state(type,$type,$name) $type
			set state(path,$type,$name) $f
		    }
		}
	    }
	}
    }
    
    # Compile info.
    # 1) get all types:
    set state(types) {}
    foreach {key type} [array get state type,*] {
	lappend state(types) $type
    }
    set state(types) [lsort -unique $state(types)]

    # 2) get all names for each type:
    foreach type $state(types) {
	foreach {key name} [array get state name,$type,*] {
	    lappend state(names,$type) $name
	}
    }
    return $state(types)
}

# Rosticons::Get --
# 
#       Returns the image to use for this key.
#       
# Arguments:
#       statuskey       type/subtype, ex: status/online, icq/xa, whiteboard/dnd
#                       application/* and phone/* are special
#       
# Results:
#       a valid image.

proc ::Rosticons::Get {statuskey} {
    variable icons
    variable state
    upvar ::Jabber::jprefs jprefs
        
    set statuskey [string tolower $statuskey]
    lassign [split $statuskey /] type sub
    set sub [string map {available online unavailable offline} $sub]
    set suborig $sub
    
    if {$type eq "application"} {
	if {$jprefs(rost,icons,use,$type)} {
	    set key $type/$sub
	    if {[info exists icons($key)]} {
		return $icons($key)
	    } else {
		set sub [string map {group-online group} $sub]
		set sub [string map {group-offline group} $sub]
		set sub [string map {folder-open folder} $sub]
		set sub [string map {folder-closed folder} $sub]
		set key $type/$sub
		if {[info exists icons($key)]} {
		    return $icons($key)
		} else {
		    return ""
		}
	    }
	} else {
	    return ""
	}
    } elseif {$type eq "phone"} {
	if {$jprefs(rost,icons,use,$type)} {
	    if {[info exists icons($statuskey)]} {
		return $icons($statuskey)
	    } else {
		return ""
	    }
	} else {
	    return ""
	}
    } else {
	if {![info exists jprefs(rost,icons,use,$type)]} {
	    set type status
	}

	# Check if this type is active. Use 'status' as fallback.
	if {!$jprefs(rost,icons,use,$type)} {
	    set type status
	}
	
	set key $type/$sub
	if {[info exists icons($key)]} {
	    return $icons($key)
	}
	
	# See if we can match the 'type'. Use 'status' as fallback.
	if {[lsearch -exact $state(types) $type] == -1} {
	    set type status
	}
	
	# First try to find a fallback for the sub part.
	set sub [string map {invisible offline} $sub]
	set sub [string map {ask offline} $sub]
	set sub [string map {chat online} $sub]
	set key $type/$sub
	if {[info exists icons($key)]} {
	    return $icons($key)
	}
	set sub [string map {xa away} $sub]
	set sub [string map {dnd away} $sub]
	set key $type/$sub
	if {[info exists icons($key)]} {
	    return $icons($key)
	}
	set sub [string map {away online} $sub]
	set key $type/$sub
	if {[info exists icons($key)]} {
	    return $icons($key)
	}
	
	# If still not matched select type=status which must be there.
	return $icons(status/$suborig)
    }
}
    
# Rosticons::LoadTmpIconSet --
# 
#       Loads an iconset with specified 'type' and 'name' and creates all images.

proc ::Rosticons::LoadTmpIconSet {type name} {
    variable state
    variable meta
    variable tmpicons
    variable tmpiconsInv
    variable mdata
    variable idata
    
    set path $state(path,$type,$name)
        
    set name [::Icondef::Load $path  \
      [namespace current]::idata     \
      [namespace current]::mdata]
    
    array unset meta $name,*
    foreach {key value} [array get mdata] {
	set meta($name,$key) $value
    }
    
    array unset tmpicons    $name,$type/*
    array unset tmpiconsInv $name,$type/*

    foreach {typesubtype image} [array get idata] {
	set tmpicons($name,$typesubtype) $image
	set tmpiconsInv($name,$image)    $typesubtype
    }
    set state(loaded,$type,$name) 1

    unset -nocomplain mdata
    unset -nocomplain idata
}

# Rosticons::SetFromTmp --
# 
#       Sets the specified iconset. It just copies the relevant array elements
#       from 'tmpicons' to 'icons'.

proc ::Rosticons::SetFromTmp {type name} {
    variable tmpicons
    variable icons
    variable iconsInv
    variable priv
        
    foreach {key image} [array get tmpicons "$name,$type/*"] {
	set typesubtype [lindex [split $key ,] 1]
	set icons($typesubtype) $image
	set iconsInv($image)    $typesubtype
    }
}

# Preference hooks -------------------------------------------------------------

proc ::Rosticons::InitPrefsHook { } {
    
    variable priv
    variable defaultSet
    upvar ::Jabber::jprefs jprefs

    set jprefs(rost,haveWBicons) 1
    
    # @@@ Find all types dynamically...
    # Do NOT store the complete path!
    set plist {}
    foreach type $priv(types) {
	set jprefs(rost,icons,$type) $defaultSet($type)
	set name  ::Jabber::jprefs(rost,icons,$type)
	set rsrc  jprefs_rost_icons_$type
	set value [set $name]
	lappend plist [list $name $rsrc $value]

	set jprefs(rost,icons,use,$type) 1
	set name  ::Jabber::jprefs(rost,icons,use,$type)
	set rsrc  jprefs_rost_icons_use_$type
	set value [set $name]
	lappend plist [list $name $rsrc $value]
    }
    
    ::PrefUtils::Add $plist
}

proc ::Rosticons::BuildPrefsHook {wtree nbframe} {
    
    ::Preferences::NewTableItem {Jabber Rosticons} [mc {Rosticons}]
    
    set wpage [$nbframe page {Rosticons}]    
    BuildPrefsPage $wpage
}

proc ::Rosticons::BuildPrefsPage {wpage} {
    variable wselect
    variable wshow

    set wc $wpage.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -fill both -expand 1 \
      -anchor [option get . dialogAnchor {}]
    
    set box $wc.b
    ttk::frame $wc.b
    pack $box -side top
    
    # Style selection tree:
    set lbox $box.l
    set wysc    $lbox.ysc
    set wselect $lbox.t    

    frame $lbox -relief sunken -bd 1    
    
    ttk::scrollbar $wysc -orient vertical -command [list $wselect yview]
    PTreeSelect $wselect $wysc

    grid  $wselect  -row 0 -column 0 -sticky news
    grid  $wysc     -row 0 -column 1 -sticky ns
    grid columnconfigure $lbox 0 -weight 1   
    
    PFillTree $wselect

    # Show iconset tree:
    set rbox $box.r
    set wysc  $rbox.ysc
    set wshow $rbox.t    

    frame $rbox -relief sunken -bd 1    
    
    ttk::scrollbar $wysc -orient vertical -command [list $wselect yview]
    PTreeShow $wshow $wysc

    grid  $wshow  -row 0 -column 0 -sticky news
    grid  $wysc   -row 0 -column 1 -sticky ns
    grid columnconfigure $rbox 0 -weight 1   
        
    set msg $box.msg
    ttk::label $msg -text [mc jaseliconset]

    grid  $lbox  x  $rbox  -sticky ew
    grid  $msg   -  -      -sticky w -pady 4
    grid columnconfigure $box 1 -minsize 12
    
    # @@@ treectrl2.2.3
    $wselect selection add status
    
    bind $wpage <Destroy> [namespace current]::PFree
}

proc ::Rosticons::PTreeSelect {T wysc} {
    global  this
    
    treectrl $T -usetheme 1 -selectmode single  \
      -showroot 0 -showrootbutton 0 -showbuttons 1 -showheader 0  \
      -borderwidth 0 -highlightthickness 0 -indent 10 \
      -yscrollcommand [list $wysc set]
    
    #  -yscrollcommand [list ::UI::ScrollSet $wysc     \
    #  [list grid $wysc -row 0 -column 1 -sticky ns]]
   
    # This is a dummy option.
    set stripeBackground [option get $T stripeBackground {}]
    set stripes [list $stripeBackground {}]
    set fill [list $this(sysHighlight) {selected focus} gray {selected !focus}]
    set bd [option get $T columnBorderWidth {}]
    set bg [option get $T columnBackground {}]

    $T column create -tags cButton -resize 0 -borderwidth $bd  \
      -background $bg -squeeze 1
    $T column create -tags cTree   -resize 0 -borderwidth $bd  \
      -background $bg -expand 1
    $T configure -treecolumn cTree

    $T element create eText text -lines 1
    $T element create eButton window
    $T element create eBorder rect -open new -outline white -outlinewidth 1 \
      -fill $fill -showfocus 1

    set S [$T style create styButton]
    $T style elements $S {eBorder eButton}
    $T style layout $S eButton
    $T style layout $S eBorder -detach yes -iexpand xy -indent 0

    set S [$T style create styStd]
    $T style elements $S {eBorder eText}
    $T style layout $S eText -padx 4 -squeeze x -expand ns -ipady 2
    $T style layout $S eBorder -detach yes -iexpand xy -indent 0

    set S [$T style create styTag]
    $T style elements $S {eText}

    $T column configure cButton -itemstyle styButton
    $T column configure cTree -itemstyle styStd

    $T notify bind $T <Selection>      { ::Rosticons::POnSelect %T }
}

proc ::Rosticons::POnSelect {T} {
    variable ptmp
    
    set item [$T selection get]
    if {[llength $item] == 1} {
	set tag [lindex [$T item tag names $item] 0]
	if {[llength $tag] == 1} {
	    set type $tag
	    set name $ptmp(name,$type)
	    PFillKeyImageTree $type $name   
	} elseif {[llength $tag] == 2} {
	    lassign $tag type name
	    PFillKeyImageTree $type $name   
	}
    }
}

proc ::Rosticons::PFillTree {T} {    
    variable state
    variable ptmp
    upvar ::Jabber::jprefs jprefs
    
    foreach type $state(types) {
	set ptmp(use,$type)  $jprefs(rost,icons,use,$type)
	set ptmp(name,$type) $jprefs(rost,icons,$type)
    }
    
    set i 0
    set types [lsearch -all -inline -not $state(types) "status"]
    set types [linsert $types 0 "status"]
    
    foreach type $types {
	set wcheck $T.[incr i]
	checkbutton $wcheck -bg white -highlightthickness 0 \
	  -variable [namespace current]::ptmp(use,$type)
	if {($type eq "status" ) || ($type eq "XXXapplication")} {
	    $wcheck configure -state disabled
	}
	if {$type eq "status"} {
	    set typeName "Jabber"
	} elseif {$type eq "application"} {
	    set typeName [mc program-Application]
	} elseif {$type eq "phone"} {
	    set typeName [mc Phone]
	} elseif {$type eq "smtp"} {
	    set typeName [mc Email]
	} elseif {$type eq "whiteboard"} {
	    set typeName [mc Whiteboard]
	} else {
	    set typeName [::Roster::GetNameFromTrpt $type]
	}
	set pitem [$T item create -open 1 -button 1 -parent root -tags $type]
	$T item element configure $pitem cButton eButton -window $wcheck
	$T item element configure $pitem cTree eText -text $typeName \
	  -font CociSmallBoldFont
	
	set names $state(names,$type)
	
	foreach name $names {
	    set wradio $T.[incr i]
	    radiobutton $wradio -bg white -highlightthickness 0 \
	      -variable [namespace current]::ptmp(name,$type)  \
	      -value $name
	    
	    if {$name eq "default"} {
		set str [mc Default]
	    } else {
		set str $name
	    }
	    
	    set tag [list $type $name]
	    set item [$T item create -parent $pitem -tags [list $tag]]
	    $T item element configure $item cButton eButton -window $wradio
	    $T item element configure $item cTree eText -text $str
	}
	if {[llength $names] == 1} {
	    $wradio configure -state disabled
	}
    }    
}

proc ::Rosticons::PTreeShow {T wysc} {
    
    treectrl $T -usetheme 1  \
      -showroot 0 -showrootbutton 0 -showbuttons 1 -showheader 1  \
      -borderwidth 0 -highlightthickness 0 -indent 10  \
      -yscrollcommand [list $wysc set]
      #-yscrollcommand [list ::UI::ScrollSet $wysc     \
      #[list grid $wysc -row 0 -column 1 -sticky ns]]  \
 
    set bd [option get $T columnBorderWidth {}]
    set bg [option get $T columnBackground {}]
   
    $T column create -tags cKey   -text [mc Key] -expand 1 -squeeze 1  \
      -borderwidth $bd -background $bg
    $T column create -tags cImage -text [mc Icon] -expand 1 -justify center  \
      -borderwidth $bd -background $bg

    $T element create eText text -lines 1
    $T element create eImage image

    set S [$T style create styText]
    $T style elements $S {eText}
    $T style layout $S eText -padx 6 -pady 2

    set S [$T style create styImage]
    $T style elements $S {eImage}
    $T style layout $S eImage -padx 6 -pady 2 -expand ew

    $T column configure cKey -itemstyle styText
    $T column configure cImage -itemstyle styImage
}

proc ::Rosticons::PFillKeyImageTree {type name} {
    variable wselect
    variable wshow
    variable tmpicons
    variable state
    
    if {![info exists state(loaded,$type,$name)]} {
	LoadTmpIconSet $type $name
    }
    set T $wshow
    $T item delete all
    
    foreach {key image} [array get tmpicons $name,$type/*] {
	set item [$T item create -parent root]
	set typesubtype [lindex [split $key ,] 1]
	$T item element configure $item cKey eText -text $typesubtype
	$T item element configure $item cImage eImage -image $image
    }
    
}

proc ::Rosticons::SavePrefsHook {} {
    variable ptmp
    variable state
    upvar ::Jabber::jprefs jprefs
    
    set changed [PChanged]

    foreach type $state(types) {
	if {$jprefs(rost,icons,$type) ne $ptmp(name,$type)} {
	    set name $ptmp(name,$type)
	    if {![info exists state(loaded,$type,$name)]} {
		LoadTmpIconSet $type $name
	    }
	    SetFromTmp $type $name
	}
	set jprefs(rost,icons,use,$type) $ptmp(use,$type)
	set jprefs(rost,icons,$type)     $ptmp(name,$type)
    }
    if {$changed} {
	::Roster::RepopulateTree
	::hooks::run rosterIconsChangedHook
    }
}

proc ::Rosticons::CancelPrefsHook {} {
    variable ptmp
    variable state
    upvar ::Jabber::jprefs jprefs
    
    if {[PChanged]} {
	::Preferences::HasChanged
    }
}

proc ::Rosticons::PChanged {} {
    variable ptmp
    variable state
    upvar ::Jabber::jprefs jprefs
    
    set changed 0
    foreach type $state(types) {
	if {$jprefs(rost,icons,use,$type) != $ptmp(use,$type)} {
	    set changed 1
	    break
	}
	if {$jprefs(rost,icons,$type) ne $ptmp(name,$type)} {
	    set changed 1
	    break
	}
    }
    return $changed
}

proc ::Rosticons::UserDefaultsHook {} {
    variable ptmp
    upvar ::Jabber::jprefs jprefs

    # @@@ TODO
}

proc ::Rosticons::PFree {} {
    variable ptmp
    
    unset -nocomplain ptmp
}

#-------------------------------------------------------------------------------
