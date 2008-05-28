#  Rosticons.tcl --
#  
#      This file is part of The Coccinella application. 
#      It implements handling and parsing of roster icons.
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
# $Id: Rosticons.tcl,v 1.50 2008-05-28 09:51:08 matben Exp $

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

namespace eval ::Rosticons {

    # Define all hooks for inits and preference settings.
    ::hooks::register prefsInitHook          ::Rosticons::InitPrefsHook
    ::hooks::register prefsBuildHook         ::Rosticons::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::Rosticons::SavePrefsHook
    ::hooks::register prefsCancelHook        ::Rosticons::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::Rosticons::UserDefaultsHook
    
    ::hooks::register themeChangedHook       ::Rosticons::ThemeChangedHook
    
    # The presence/show states.
    variable pstates
    set pstates(pres) {online offline invisible away chat dnd xa}

    # Application tree icon name.
    set pstates(app) {
	group-root-online group-root-offline 
	group-transport   group-pending 
	group-online      group-offline 
	folder-open       folder-closed  folder
    }
    set pstates(phone) {online ring talk}
    
    # 'imagesD' contains all available mappings from 'type' and 'status'
    # to images, even if they aren't used.
    variable imagesD [dict create]
    
    # 'tmpImagesD' is for temporary storage only (preferences) and maps
    # from 'themeName', 'type', and 'status' to images.
    variable tmpImagesD [dict create]
    
    # Define which iconsets that shall be active by default.
    set ::config(rost,theme,use,application) 1
    set ::config(rost,theme,use,phone)       1
    set ::config(rost,theme,use,user)        1
    
    # Define which icons must always be displayed.
    set ::config(rost,theme,must,application) 1
    set ::config(rost,theme,must,phone)       1
    set ::config(rost,theme,must,user)        1

    variable inited 0
}

proc ::Rosticons::Init {} {
    variable inited
    
    if {$inited} { return }
     
    # Investigates all sets available per 'type' and 'name' but doesn't
    # process anything.
    set types [ThemeGetAllTypes]
    set inited 1
}

proc ::Rosticons::ThemeExists {key} {
    variable imagesD
    lassign [split $key /] type sub
    return [dict exists imagesD $type $sub]
}

proc ::Rosticons::ThemeGetTypes {} {
    variable stateD   
    return [dict keys [dict get $stateD types]]
}

proc ::Rosticons::ThemeGetAllTypes {} {
    variable stateD
    
    # This should reset these states?
    dict set stateD types [list]
    dict set stateD paths [list]
    set typeD [dict create]
    
    foreach path [::Theme::GetAllThemePaths] {
	set name [file tail $path]
	set infoL [::Theme::GetInfo $path]
	set anyRoster 0
	foreach info $infoL {
	    if {[string match roster-* $info]} {
		lassign [split $info -] - type
		dict lappend typeD $type $name
		set anyRoster 1
	    }
	}
	if {$anyRoster} {
	    dict set stateD paths $name $path		
	}
    }
    dict set stateD types $typeD
      
    # Compile info.
    # 1) get all types:
    set types [dict keys [dict get $stateD types]]

    # 2) get all names for each type:
#     foreach type $types {
# 	set names [dict get $stateD types $type]
#     }
    return $types
}

# Rosticons::ThemeGet --
# 
#       Returns the image to use for this key.
#       
# Arguments:
#       typekey         type/subtype, ex: user/online, icq/xa, 
#                       application/* and phone/* are special
#       
# Results:
#       a valid image or empty.

proc ::Rosticons::ThemeGet {typekey} {
    variable stateD
    variable imagesD
    upvar ::Jabber::jprefs jprefs
        
    set typekey [string tolower $typekey]
    lassign [split $typekey /] type sub
    set sub [string map {available online unavailable offline} $sub]
    set suborig $sub
    
    if {$type eq "application"} {
	if {$jprefs(rost,theme,use,$type)} {
	    if {[dict exists $imagesD $type $sub]} {
		return [dict get $imagesD $type $sub]
	    }
	}
    } elseif {$type eq "phone"} {
	if {$jprefs(rost,theme,use,$type)} {
	    set sub [string map {dialed talk} $sub]
	    set sub [string map {on_phone talk} $sub]
	    set sub [string map {hang_up talk} $sub]
	    if {[dict exists $imagesD $type $sub]} {
		return [dict get $imagesD $type $sub]
	    }
	}
    } else {
	
	# Check if this type is active. Use 'user' as fallback.
	if {![info exists jprefs(rost,theme,use,$type)]} {
	    set type "user"
	}
	if {!$jprefs(rost,theme,use,$type)} {
	    set type "user"
	}	
	set key $type/$sub
	if {[dict exists $imagesD $type $sub]} {
	    return [dict get $imagesD $type $sub]
	}
	
	# See if we can match the 'type'. Use 'user' as fallback.
	set types [dict keys [dict get $stateD types]]
	if {$type ni $types} {
	    set type "user"
	}
	
	# First try to find a fallback for the sub part.
	set sub [string map {invisible offline} $sub]
	set sub [string map {ask offline} $sub]
	set sub [string map {chat online} $sub]
	if {[dict exists $imagesD $type $sub]} {
	    return [dict get $imagesD $type $sub]
	}
	set sub [string map {xa away} $sub]
	set sub [string map {dnd away} $sub]
	if {[dict exists $imagesD $type $sub]} {
	    return [dict get $imagesD $type $sub]
	}
	set sub [string map {away online} $sub]
	if {[dict exists $imagesD $type $sub]} {
	    return [dict get $imagesD $type $sub]
	}
	
	# If still not matched select type=user which must be there.
	set sub $suborig
	if {[dict exists $imagesD user $sub]} {
	    return [dict get $imagesD user $sub]
	}
	set sub [string map {invisible offline} $sub]
	set sub [string map {ask offline} $sub]
	set sub [string map {chat online} $sub]
	if {[dict exists $imagesD user $sub]} {
	    return [dict get $imagesD user $sub]
	}
	set sub [string map {xa away} $sub]
	set sub [string map {dnd away} $sub]
	if {[dict exists $imagesD user $sub]} {
	    return [dict get $imagesD user $sub]
	}
    }
    return
}

proc ::Rosticons::ThemeLoadSetTmp {type name} {
    if {$type eq "application"} {
	ThemeLoadApplicationTmp $name
    } elseif {$type eq "phone"} {
	ThemeLoadPhoneTmp $name
    } else {
	ThemeLoadTypeTmp $type $name
    }
}

# Rosticons::ThemeLoadApplicationTmp --
#
#       Loads all 'application' type roster icons from a set.
#       It uses fallbacks to ordinary themes.

proc ::Rosticons::ThemeLoadApplicationTmp {name} {
    variable stateD
    variable tmpImagesD
    variable pstates

    set type "application"
    dict set tmpImagesD $name $type [list]
    
    # Here we start searching the roster theme 'name' and use fallbacks.
    set path [list [::Theme::GetPath $name]]
    set paths [concat $path [::Theme::GetPresentSearchPaths]]
    foreach app $pstates(app) {
	set spec icons/16x16/$app
	set image [::Theme::MakeIconFromPaths $spec "" $paths]
	if {$image ne ""} {
	    dict set tmpImagesD $name $type $app $image 
	}
    }
    return
}

proc ::Rosticons::ThemeLoadPhoneTmp {name} {
    variable stateD
    variable tmpImagesD
    variable pstates

    set type "phone"
    dict set tmpImagesD $name $type [list]
     
    set paths [list [::Theme::GetPath $name]]
    foreach key $pstates(phone) {
	set spec icons/16x16/phone-$key
	set image [::Theme::MakeIconFromPaths $spec "" $paths]
	if {$image ne ""} {
	    dict set tmpImagesD $name $type $key $image 
	}
    }
    return
}

# Rosticons::ThemeLoadTypeTmp --
#
#       Creates all relevant images from an iconset.

proc ::Rosticons::ThemeLoadTypeTmp {type name} {
    variable stateD
    variable tmpImagesD
    variable pstates
    
    dict set tmpImagesD $name $type [list]
    if {$type eq "user"} {
	set isUser 1
    } else {
	set isUser 0
    }
    
    # If an iconset is missing an icon for one of the states,
    # do the fallback within the theme and not to any other theme.
    set paths [list [::Theme::GetPath $name]]
    foreach key $pstates(pres) {
	# We keep an alternative lookup mechanism here.
	# set spec icons/16x16/$type-$key
	if {$isUser} {
	    set spec icons/16x16/user-$key
	} else {
	    set spec icons/16x16/user-$key-$type
	}
	set image [::Theme::MakeIconFromPaths $spec "" $paths]
	if {$image ne ""} {
	    dict set tmpImagesD $name $type $key $image 
	}
    }
    return
}

# Rosticons::ThemeSetFromTmp --
# 
#       Sets the specified iconset. It just copies the relevant dict elements
#       from 'tmpImagesD' to 'imagesD'.
#       The corresponding entries of 'tmpImagesD' are unset since images copied.

proc ::Rosticons::ThemeSetFromTmp {type name} {
    variable imagesD
    variable tmpImagesD

    dict for {key image} [dict get $tmpImagesD $name $type] {
	dict set imagesD $type $key $image
    }
    dict unset tmpImagesD $name $type
}

# Preference hooks -------------------------------------------------------------

proc ::Rosticons::InitPrefsHook {} {
    global config this
    variable stateD
    upvar ::Jabber::jprefs jprefs

    set jprefs(rost,haveWBicons) 1
    
    # We need to do this here since we depend on it.
    Init
    
    # Find all types dynamically...
    set types [dict keys [dict get $stateD types]]
    
    # Define all our prefs settings.
    set plist [list]
    foreach type $types {
	set names [dict get $stateD types $type]
	set key "rost,theme,name,$type"
	set jprefs($key) [lindex $names 0]
	set name  ::Jabber::jprefs($key)
	set rsrc  jprefs_rost_theme_name_$type
	set value [set $name]
	lappend plist [list $name $rsrc $value]

	set key "rost,theme,use,$type"
	if {[info exists config($key)] && $config($key)} {
	    set jprefs($key) $config($key)
	} else {
	    set jprefs($key) 0	    
	}
	
	# Add only the ones that can be optional.
	set must 0
	set key "rost,theme,must,$type"
	if {[info exists config($key)] && $config($key)} {
	    set must 1
	}
	if {!$must} {
	    set name  ::Jabber::jprefs(rost,theme,use,$type)
	    set rsrc  jprefs_rost_theme_use_$type
	    set value [set $name]
	    lappend plist [list $name $rsrc $value]
	}
    }    
    ::PrefUtils::Add $plist
    
    VerifyAndLoad
}

proc ::Rosticons::VerifyAndLoad {} {
    global this
    variable stateD
    upvar ::Jabber::jprefs jprefs
    
    set types [dict keys [dict get $stateD types]]
    
    # Treat each 'type' in turn. Verify that exists.
    # This must be done after we have read and set our preferences.
    foreach type $types {
 	set key "rost,theme,name,$type"
 	set name $jprefs($key)
 	if {[::Theme::GetPath $name] eq ""} {
	    
	    # Theme doesn't exist. Try to find a fallback theme.
	    set names [dict get $stateD types $type]
	    set jprefs($key) [lindex $names 0]
	    set jprefs(rost,theme,use,$type) 0
 	}
	ThemeLoadSetTmp $type $name
	ThemeSetFromTmp $type $name
    }
}

proc ::Rosticons::BuildPrefsHook {wtree nbframe} {
    
    ::Preferences::NewTableItem {Jabber "Theme Rosticons"} [mc "Contact Icons"]
    
    set wpage [$nbframe page "Theme Rosticons"]    
    TBuildPrefsPage $wpage
}

proc ::Rosticons::TBuildPrefsPage {wpage} {
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
    TPTreeSelect $wselect $wysc

    grid  $wselect  -row 0 -column 0 -sticky news
    grid  $wysc     -row 0 -column 1 -sticky ns
    grid columnconfigure $lbox 0 -weight 1   
     
    TPFillTree $wselect

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
    ttk::label $msg -text [mc jaseliconset2]

    grid  $lbox  x  $rbox  -sticky ew
    grid  $msg   -  -      -sticky w -pady 4
    grid columnconfigure $box 1 -minsize 12
    
    $wselect selection add user
    
    bind $wpage <Destroy> [namespace current]::PFree
}

proc ::Rosticons::TPTreeSelect {T wysc} {
    global  this
    
    treectrl $T -selectmode single  \
      -showroot 0 -showrootbutton 0 -showbuttons 1 -showheader 0  \
      -borderwidth 0 -highlightthickness 0 -indent 10 \
      -yscrollcommand [list $wysc set]
       
    # This is a dummy option.
    set itemBackground [option get $T itemBackground {}]
    set fill [list $this(sysHighlight) {selected focus} gray {selected !focus}]
    set bd [option get $T columnBorderWidth {}]
    set bg [option get $T columnBackground {}]
    set fg [option get $T textColor {}]
    
    $T column create -tags cButton -resize 0 -borderwidth $bd  \
      -background $bg -textcolor $fg -squeeze 1
    $T column create -tags cTree   -resize 0 -borderwidth $bd  \
      -background $bg -textcolor $fg -expand 1
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

    $T notify bind $T <Selection>  { ::Rosticons::TPOnSelect %T }
}

proc ::Rosticons::TPOnSelect {T} {
    variable ptmp
    
    set item [$T selection get]
    if {[llength $item] == 1} {
	set tag [lindex [$T item tag names $item] 0]
	if {[llength $tag] == 1} {
	    set type $tag
	    set name $ptmp(name,$type)
	    TPFillKeyImageTree $type $name   
	} elseif {[llength $tag] == 2} {
	    lassign $tag type name
	    TPFillKeyImageTree $type $name   
	}
    }
}

proc ::Rosticons::TPFillTree {T} {
    global config
    variable stateD
    variable ptmp
    upvar ::Jabber::jprefs jprefs
    
    set types [dict keys [dict get $stateD types]]

    foreach type $types {
	set ptmp(use,$type)  $jprefs(rost,theme,use,$type)
	set ptmp(name,$type) $jprefs(rost,theme,name,$type)
    }
   
    set i 0

    foreach type $types {
	set wcheck $T.[incr i]
	checkbutton $wcheck -bg white -highlightthickness 0 \
	  -variable [namespace current]::ptmp(use,$type)

	set key "rost,theme,must,$type"
	if {[info exists config($key)] && $config($key)} {
	    $wcheck configure -state disabled
	}

	if {$type eq "user"} {
	    set typeName [mc normal]
	} elseif {$type eq "application"} {
	    set typeName [mc program-Application]
	} elseif {$type eq "phone"} {
	    set typeName [mc Phone]
	} elseif {$type eq "smtp"} {
	    set typeName [mc Email]
	} else {
	    set typeName [::Roster::GetNameFromTrpt $type]
	}
	set pitem [$T item create -open 1 -button 1 -parent root -tags $type]
	$T item element configure $pitem cButton eButton -window $wcheck
	$T item element configure $pitem cTree eText -text $typeName \
	  -font CociSmallBoldFont

	set names [dict get $stateD types $type]
    
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
    
    treectrl $T -showroot 0 -showrootbutton 0 -showbuttons 1 -showheader 1 \
      -borderwidth 0 -highlightthickness 0 -indent 10  \
      -yscrollcommand [list $wysc set]
 
    set bd [option get $T columnBorderWidth {}]
    set bg [option get $T columnBackground {}]
    set fg [option get $T textColor {}]
   
    $T column create -tags cKey   -text [mc Key] -expand 1 -squeeze 1  \
      -borderwidth $bd -background $bg -textcolor $fg
    $T column create -tags cImage -text [mc Icon] -expand 1 -justify center  \
      -borderwidth $bd -background $bg -textcolor $fg

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

proc ::Rosticons::TPFillKeyImageTree {type name} {
    variable wselect
    variable wshow
    variable tmpImagesD
    variable stateD
    
    # All images used here are created new. Never share any imagesD.
    if {![dict exists $tmpImagesD $name $type]} {
	ThemeLoadSetTmp $type $name
    }
    set T $wshow
    $T item delete all
    
    dict for {key image} [dict get $tmpImagesD $name $type] {
	set item [$T item create -parent root]
	$T item element configure $item cKey eText -text $key
	$T item element configure $item cImage eImage -image $image
    }
}

proc ::Rosticons::SavePrefsHook {} {
    variable ptmp
    variable stateD
    variable tmpImagesD
    variable imagesD
    upvar ::Jabber::jprefs jprefs
    
    set changed [PChanged]
    set types [dict keys [dict get $stateD types]]
    
    set prevImagesD $imagesD

    foreach type $types {
	if {$jprefs(rost,theme,name,$type) ne $ptmp(name,$type)} {
	    set name $ptmp(name,$type)
	    if {![dict exists $tmpImagesD $name $type]} {
		ThemeLoadSetTmp $type $name
	    }
	    ThemeSetFromTmp $type $name
	}
	set jprefs(rost,theme,use,$type)  $ptmp(use,$type)
	set jprefs(rost,theme,name,$type) $ptmp(name,$type)
    }
    if {$changed} {
	# @@@ Move this to hook???
	::Roster::RepopulateTree
	::hooks::run rosterIconsChangedHook
    
	# Garbage collect old images. Be sure that all users of roster icons
	# use the 'rosterIconsChangedHook' to refresh new icons.
	GarbageCollect $prevImagesD $imagesD
    }
}

proc ::Rosticons::GarbageCollect {prevImagesD imagesD} {
       
    # Garbage collect old images. Be sure that all users of roster icons
    # use the 'rosterIconsChangedHook' to refresh new icons.
    dict for {type typeD} $imagesD {
	dict for {pres image} $typeD {
	    set prevImage [dict get $prevImagesD $type $pres]
	    if {$prevImage ne $image} {
		
		# There is no danger with this since if inuse
		# it wont get deleted until widget is.
		image delete $prevImage
	    }
	}
    }
}

proc ::Rosticons::CancelPrefsHook {} {
    if {[PChanged]} {
	::Preferences::HasChanged
    }
}

proc ::Rosticons::PChanged {} {
    variable ptmp
    variable stateD
    upvar ::Jabber::jprefs jprefs
    
    set changed 0
    set types [dict keys [dict get $stateD types]]
    foreach type $types {
	if {$jprefs(rost,theme,use,$type) ne $ptmp(use,$type)} {
	    set changed 1
	    break
	}
	if {$jprefs(rost,theme,name,$type) ne $ptmp(name,$type)} {
	    set changed 1
	    break
	}
    }
    return $changed
}

proc ::Rosticons::UserDefaultsHook {} {
    # @@@ TODO
}

proc ::Rosticons::PFree {} {
    variable ptmp
    variable tmpImagesD

    dict for {name typeD} $tmpImagesD {
	dict for {type imagesD} $typeD {
	    dict for {key image} $imagesD {
		image delete $image
	    }
	}
    }
    unset tmpImagesD
    unset -nocomplain ptmp
    set tmpImagesD [dict create]
}

proc ::Rosticons::ThemeChangedHook {} {
    global prefs
    variable stateD
    variable imagesD
    upvar ::Jabber::jprefs jprefs

    set prevImagesD $imagesD

    # Loop through each type and switch roster icon theme if new theme
    # supports it.
    set name $prefs(themeName)
    set path [::Theme::GetPath $name]
    set infoL [::Theme::GetInfo $path]
    dict for {type nameL} [dict get $stateD types] {
	if {$jprefs(rost,theme,name,$type) eq $name} { 
	    continue 
	}
	if {"roster-$type" in $infoL} {
	    ThemeLoadSetTmp $type $name
	    ThemeSetFromTmp $type $name	
	}
    }    
    GarbageCollect $prevImagesD $imagesD
}

#-------------------------------------------------------------------------------
