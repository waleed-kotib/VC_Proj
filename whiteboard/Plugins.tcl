# Plugins.tcl --
#  
#       This file is part of The Coccinella application.
#       It registers the standard "built in" packages:
#           QuickTimeTcl
#           snack
#           Img
#           
#       It also contains support functions for adding external plugins.
#      
#  Copyright (c) 2003-2004  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Plugins.tcl,v 1.14 2004-12-04 15:01:10 matben Exp $
#
# We need to be very systematic here to handle all possible MIME types
# and extensions supported by each package or helper application.
#
# mimeType2Packages: array that maps a MIME type to a list of one or many 
#                    packages.
# 
# supSuff:           maps package name to supported suffixes for that package,
#                    and maps from MIME type (image, audio, video) to suffixes.
#                    It contains a bin (binary) element as well which is the
#                    the union of all MIME types except text.
#                    This should only be used internally to compile the
#                    dialog -typelist values.
#                    
# supportedMimeTypes: maps package name to supported MIME types for that package,
#                    and maps from MIME type (image, audio, video) to MIME type.
#                    It contains a bin (binary) element as well which is the
#                    the union of all MIME types except text.
#                    
# prefMimeType2Package:  The preferred package to handle a file with this MIME 
#                    type. Empty if no packages support MIME.
#
# mimeTypeDoWhat:    is one of (unavailable|reject|save|ask|$packageName).
#                    The default is "unavailable". Only "reject" if package
#                    is there but actively picked reject in dialog.
#                    Both "unavailable" and "reject" map to "Reject" in dialog.
#                    The "unavailable" says that there is no package for MIME.
#
# 
# The 'plugin' array defines various aspects of each plugin package:
#
#  plugin(packageName,pack)        Thing to use for 'package require' 
#                                  including possibly version number.
#  plugin(packageName,ver)         The version actually used, if loaded.
#  
#  plugin(packageName,type)        Type of plugin. Any of:
#                                    'internal'    one of the hardcoded ones
#                                    'external'    loaded through our plugin method
#                                    'application' a helper application
#  plugin(packageName,desc)        A longer description of the package.
#  plugin(packageName,platform)    list if platforms
#  plugin(packageName,loaded)      0/1 if loaded or not.
#  plugin(packageName,importProc)  which tcl procedure to call when importing...
#  plugin(packageName,mimes)       List of all MIME types supported.
#  plugin(packageName,winClass)    (optional) 
#  plugin(packageName,saveProc)    (optional) 
#  plugin(packageName,importHttpProc)  (optional) which tcl procedure to call 
#                                  when importing using http.
#  plugin(packageName,trpt,MIME)   (optional) the transport method used,
#                                  which defaults to the built in PUT/GET,
#                                  but can be "http" for certain Mime types
#                                  for the QuickTime package. In that case
#                                  the 'importProc' procedure gets it internally.
#                                  Here MIME can be the mimetype, or the
#                                  mimetype/subtype to be flexible.
#  plugin(packageName,icon,12)     (optional) Tk image to show in various places
#  plugin(packageName,icon,16)     (optional) Tk image to show in various places
#  
#-------------------------------------------------------------------------------

package provide Plugins 1.0

package require Types

namespace eval ::Plugins:: {
    global tcl_platform
    
    # Define all hooks for preference settings. Be early!
    ::hooks::register prefsInitHook          ::Plugins::InitPrefsHook     10
    ::hooks::register prefsBuildHook         ::Plugins::BuildPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::Plugins::UserDefaultsHook
    ::hooks::register prefsSaveHook          ::Plugins::SaveHook
    ::hooks::register prefsCancelHook        ::Plugins::CancelHook
    ::hooks::register initHook               ::Plugins::InitHook

    variable inited 0
    variable packages2Platform
    variable helpers2Platform
    variable supSuff
    variable supportedMimeTypes
    variable supMacTypes
    variable plugType2DescArr
    
    # Supported binary files, that is, images movies etc.
    # Start with the core Tk supported formats. Mac 'TYPE'.
    set plugin(tk,loaded) 1
    set supSuff(text) {.txt}
    set supSuff(image) {}
    set supSuff(audio) {}
    set supSuff(video) {}
    set supSuff(application) {}

    set supMacTypes(text) {TEXT}
    set supMacTypes(image) {}
    set supMacTypes(audio) {}
    set supMacTypes(video) {}
    set supMacTypes(application) {}

    # Map keywords and package names to the supported MIME types.
    # Start by initing, MIME types added below.
    set supportedMimeTypes(text) text/plain
    set supportedMimeTypes(image) {}
    set supportedMimeTypes(audio) {}
    set supportedMimeTypes(video) {}
    set supportedMimeTypes(application) {}
    set supportedMimeTypes(all) $supportedMimeTypes(text)
    
    # Search only for packages on platforms they can live on.
    array set packages2Platform {
	QuickTimeTcl       {            macosx    windows} 
	snack              {windows     unix}
	Img                {windows     unix}
    }
    array set helpers2Platform {xanim unix} 
    
    # Snack buggy on NT4.
    if {($tcl_platform(os) == "Windows NT") &&  \
      ($tcl_platform(osVersion) == 4.0)} {
	set packages2Platform(snack)  \
	  [lsearch -inline -not -all $packages2Platform(snack) "windows"]
    }
    
    array set plugType2DescArr {
	internal    "Internal Plugin"
	external    "External Plugin"
	application "Helper Application"
    }
    
    # Plugin ban list. Do not load these packages.
    variable pluginBanList {}
}

# Plugins::Init --
# 
#       The initialization function which loads all plugins available.
#       

proc ::Plugins::Init { } {
    global this
    variable mimeTypeDoWhat
    variable packages2Platform
    variable supportedMimeTypes
    variable prefMimeType2Package
    variable supSuff
    variable supMacTypes
    variable plugin
    variable inited
    
    ::Debug 2 "::Plugins::Init"
    
    foreach mime [::Types::GetAllMime] {
	set mimeTypeDoWhat($mime) "unavailable"
	set prefMimeType2Package($mime) ""
    }
    
    # Init the "standard" (internal and application) plugins.
    ::Plugins::InitTk
    ::Plugins::InitQuickTimeTcl
    ::Plugins::InitSnack
    ::Plugins::InitImg
    ::Plugins::InitXanim
    
    # Load all "external" plugins.
    set pluginDir [file join $this(path) plugins]
    ::Plugins::LoadPluginDirectory $pluginDir
    
    # Load all packages and plugins we can.
    ::Plugins::CompileAndLoadPackages
    
    # Set up various arrays used internally.
    ::Plugins::PostProcessInfo
    
    # This must be done after all plugins identified and loaded.
    ::Plugins::MakeTypeListDialogOption
    
    set inited 1
}

proc ::Plugins::InitTk { } {
    global this
    variable plugin
    variable supportedMimeTypes
    variable packages2Platform
    variable supSuff

    set plugin(tk,type) "internal"
    set plugin(tk,desc) "Supported by the core"
    set plugin(tk,ver) [info tclversion]
    set plugin(tk,importProc) ::Import::DrawImage
    set plugin(tk,icon,12) [image create photo -format gif -file \
      [file join $this(imagePath) tklogo12.gif]]
    #set supSuff(tk) {.gif}
    set supportedMimeTypes(tk) {image/gif image/x-portable-pixmap}
    set plugin(tk,mimes) $supportedMimeTypes(tk)
}

proc ::Plugins::InitQuickTimeTcl { } {
    global this
    variable plugin
    variable supportedMimeTypes
    variable packages2Platform
    variable supSuff
    
    set plugin(QuickTimeTcl,pack) "QuickTimeTcl 3.1"
    set plugin(QuickTimeTcl,type) "internal"
    set plugin(QuickTimeTcl,desc) \
      {Displays multimedia content such as video, sound, mp3 etc.\
      It also supports a large number of still image formats.}
    set plugin(QuickTimeTcl,platform) $packages2Platform(QuickTimeTcl)
    set plugin(QuickTimeTcl,importProc) ::Import::DrawQuickTimeTcl
    
    # We should get files via its -url option, i.e. http if possible.
    set plugin(QuickTimeTcl,trpt,audio) http
    set plugin(QuickTimeTcl,trpt,video) http
    
    # Define any 16x16 icon to spice up the UI.
    set plugin(QuickTimeTcl,icon,16) [image create photo -format gif -file \
      [file join $this(imagePath) qtlogo16.gif]]
    set plugin(QuickTimeTcl,icon,12) [image create photo -format gif -file \
      [file join $this(imagePath) qtlogo12.gif]]
    
    # We must list supported MIME types for each package.
    # For QuickTime:
    set supportedMimeTypes(QuickTimeTcl) {\
      video/quicktime     video/x-dv          video/mpeg\
      video/mpeg4\
      video/x-mpeg        audio/mpeg          audio/x-mpeg\
      video/x-msvideo     application/sdp     audio/aiff\
      audio/x-aiff        audio/basic         audio/x-sd2\
      audio/wav           audio/x-wav         image/x-bmp\
      image/vnd.fpx       image/gif           image/jpeg\
      image/x-macpaint    image/x-photoshop   image/png\
      image/x-png         image/pict          image/x-sgi\
      image/x-targa       image/tiff          image/x-tiff\
      application/x-world application/x-3dmf  video/flc\
      application/x-shockwave-flash           audio/midi\
      audio/x-midi        audio/vnd.qcelp     video/avi\
    }
    set plugin(QuickTimeTcl,mimes) $supportedMimeTypes(QuickTimeTcl)
}

#--- snack ---------------------------------------------------------------------
# On Unix/Linux and Windows we try to find the Snack Sound extension.
# Only the "sound" part of the extension is actually needed.

proc ::Plugins::InitSnack { } {
    variable plugin
    variable supportedMimeTypes
    variable packages2Platform
    
    set plugin(snack,pack) "snack"
    set plugin(snack,type) "internal"
    set plugin(snack,desc) "The Snack Sound extension adds audio capabilities\
      to the application. Presently supported formats include wav, au, aiff and mp3."
    set plugin(snack,platform) $packages2Platform(snack)
    set plugin(snack,importProc) ::Import::DrawSnack
    set supportedMimeTypes(snack) {\
      audio/wav           audio/x-wav         audio/basic\
      audio/aiff          audio/x-aiff        audio/mpeg\
      audio/x-mpeg\
    }
    set plugin(snack,mimes) $supportedMimeTypes(snack)
}

#--- Img -----------------------------------------------------------------------
# The Img extension for reading more image formats than the standard one (gif).

proc ::Plugins::InitImg { } {
    variable plugin
    variable supportedMimeTypes
    variable packages2Platform
    
    set plugin(Img,pack) "Img"
    set plugin(Img,type) "internal"
    set plugin(Img,desc) "Adds more image formats than the standard one (gif)."
    set plugin(Img,platform) $packages2Platform(Img)
    set plugin(Img,importProc) ::Import::DrawImage
    set supportedMimeTypes(Img) {\
      image/x-bmp         image/gif           image/jpeg\
      image/png           image/x-png         image/tiff\
      image/x-tiff\
    }
    set plugin(Img,mimes) $supportedMimeTypes(Img)
}

#--- xanim ---------------------------------------------------------------------
# Test the 'xanim' app on Unix/Linux for multimedia.
  
proc ::Plugins::InitXanim { } {
    variable plugin
    variable supportedMimeTypes
    variable packages2Platform

    set plugin(xanim,type) "application"
    set plugin(xanim,desc) "A unix/Linux only application that is used\
      for displaying multimedia content in the canvas."
    set plugin(xanim,platform) unix
    set plugin(xanim,importProc) ::Import::DrawXanim
    
    # There are many more...
    set supportedMimeTypes(xanim) {\
      audio/wav           audio/x-wav         video/mpeg\
      video/x-mpeg        audio/mpeg          audio/x-mpeg\
      audio/basic         video/quicktime\
    }
    set plugin(xanim,mimes) $supportedMimeTypes(xanim)
}


proc ::Plugins::SetBanList {banList} {
    variable pluginBanList
    
    set pluginBanList $banList
}

# Plugins::CompileAndLoadPackages --
#
#       Compile information of all packages and helper apps to search for.
#       Do 'package require' and record any success.

proc ::Plugins::CompileAndLoadPackages { } {
    global this
    variable plugin
    variable pluginBanList
    
    set plugin(all) {}
    set plugin(allPacks) {}
    set plugin(allHelpers) {}

    set plugin(all) {}
    set plugin(allPacks) {}
    set plugin(allInternalPacks) {}
    set plugin(allExternalPacks) {}
    set plugin(allApps) {}
    
    foreach packAndPlat [array names plugin "*,platform"] {
	
	if {[regexp {^([^,]+),platform$} $packAndPlat match packName]} {
	    
	    # Find type, "internal" or "application".
	    switch -- $plugin($packName,type) {
		internal {
		    lappend plugin(allInternalPacks) $packName
		}
		external {
		    lappend plugin(allExternalPacks) $packName
		}
		application {
		    lappend plugin(allApps) $packName
		}
	    }
	}
    }
    set plugin(allPacks)  \
      [concat $plugin(allInternalPacks) $plugin(allExternalPacks)]
    set plugin(all) [concat $plugin(allPacks) $plugin(allApps)]
    
    # Search for the wanted packages in a systematic way.    
    foreach name $plugin(allPacks) {
	
	# Check first if this package can live on this platform.
	if {[lsearch $plugin($name,platform) $this(platform)] >= 0} {
	    
	    # Make sure that not on the ban list.
	    if {[lsearch $pluginBanList $name] >= 0} {
		set plugin($name,loaded) 0
	    } else {
	    
		# Search for it! Be silent.
		if {[string equal $plugin($name,type) "internal"]} {
		    ::SplashScreen::SetMsg "[mc splashlook] $name..."
		    if {![catch {
			eval {package require} $plugin($name,pack)
		    } msg]} {
			set plugin($name,loaded) 1
			set plugin($name,ver) $msg
		    } else {
			set plugin($name,loaded) 0
		    }	    
		} else {
		    set plugin($name,loaded) 1
		}
	    }
	    set plugin($name,ishost) 1
	} else {
	    set plugin($name,ishost) 0
	    set plugin($name,loaded) 0
	}
    }
    
    # And all helper applications... only apps on Unix/Linux.
    foreach helperApp $plugin(allApps) {
	if {[string equal $this(platform) "unix"]} {
	    set apath [lindex [auto_execok $helperApp] 0]
	    if {[llength $apath]} {
		set plugin($helperApp,loaded) 1
	    } else  {
		set plugin($helperApp,loaded) 0
	    }
	    set plugin($helperApp,ishost) 1
	} else  {
	    set plugin($helperApp,ishost) 0
	    set plugin($helperApp,loaded) 0
	}
    }
}

# Plugins::PostProcessInfo
#
#       Systematically make the 'supSuff', 'supMacTypes', 
#       'supportedMimeTypes', 'mimeType2Packages'.

proc ::Plugins::PostProcessInfo { } {
    variable plugin
    variable supportedMimeTypes
    variable supSuff
    variable supMacTypes
    variable mimeType2Packages
    variable prefMimeType2Package
    variable mimeTypeDoWhat
    
    # We add the tk library to the other ones.
    foreach name [concat tk $plugin(all)] {
	if {$plugin($name,loaded)}  {
	    
	    # Loop over all file MIME types supported by this specific package.
	    foreach mimeType $plugin($name,mimes) {
		
		# Collect all suffixes for this package.
		set suffList [::Types::GetSuffixListForMime $mimeType]
		eval lappend supSuff($name) $suffList
		
		# Get the MIME base: text, image, audio...
		if {[regexp {([^/]+)/} $mimeType match mimeBase]}  {
		    
		    eval lappend supSuff($mimeBase) $suffList
		    
		    # Add upp all "binary" files.
		    if {![string equal $mimeBase "text"]}  {
			eval lappend supSuff(bin) $suffList
		    }
		    
		    # Collect the mac types.
		    eval lappend supMacTypes($mimeBase)  \
		      [::Types::GetMacTypeListForMime $mimeType]
		    lappend supportedMimeTypes($mimeBase) $mimeType
		    lappend mimeType2Packages($mimeType) $name
		    
		    # Add upp all "binary" files.
		    if {![string equal $mimeBase "text"]}  {
			lappend supportedMimeTypes(bin) $mimeType
		    }
		}
	    }
	    eval lappend supSuff(all) $supSuff($name)
	    eval lappend supportedMimeTypes(all) $plugin($name,mimes)
	}
    }
    
    # Remove duplicates in lists.
    foreach name [concat tk $plugin(all)] {
	if {[info exists supSuff($name)]} {
	    set supSuff($name) [lsort -unique $supSuff($name)]
	}
    }
    foreach mimeBase {text image audio video application} {
	if {[info exists supSuff($mimeBase)]} {
	    set supSuff($mimeBase) [lsort -unique $supSuff($mimeBase)]
	}
	if {[info exists supportedMimeTypes($mimeBase)]} {
	    set supportedMimeTypes($mimeBase) [lsort -unique $supportedMimeTypes($mimeBase)]
	}
    }
    foreach key [array names supMacTypes] {
	set supMacTypes($key) [lsort -unique $supMacTypes($key)]
    }
    set supSuff(all) [lsort -unique $supSuff(all)]
    set supSuff(bin) [lsort -unique $supSuff(bin)]
    set supportedMimeTypes(all) [lsort -unique $supportedMimeTypes(all)]
    set supportedMimeTypes(bin) [lsort -unique $supportedMimeTypes(bin)]
    
    # Some kind of mechanism needed to select which package to choose when
    # more than one package can support a suffix.
    # Here we just takes the first one. Should find a better way!
    # QuickTimeTcl is preferred.
    
    foreach mime [array names mimeType2Packages] {
	if {[lsearch -exact $mimeType2Packages($mime) "QuickTimeTcl"] > 0} {
	    set prefMimeType2Package($mime) QuickTimeTcl
	} else {
	    set prefMimeType2Package($mime) [lindex $mimeType2Packages($mime) 0]
	}
	set mimeTypeDoWhat($mime) $prefMimeType2Package($mime)
    }
    set prefMimeType2Package(image/gif) tk

    # By default, no importing takes place, thus {}. WRONG!!!
    #set prefMimeType2Package(text/plain) {}
}

# Plugins::GetAllPackages --
# 
#       Returns the name of packages depending on the 'which' option.

proc ::Plugins::GetAllPackages {{which all}} {
    variable plugin
    
    switch -- $which {
	all {
	    return $plugin(allPacks)
	}
	internal {
	    return $plugin(allInternalPacks)
	}
	external {
	    return $plugin(allExternalPacks)
	}
	platform {
	    set packList {}
	    foreach name $plugin(all) {
		if {$plugin($name,ishost)} {
		    lappend packList $name
		}
	    }
	    return $packList	    
	}
	loaded {
	    set packList {}
	    foreach name $plugin(all) {
		if {$plugin($name,loaded)} {
		    lappend packList $name
		}
	    }
	    return $packList	    
	}
    }
}

# Plugins::MakeTypeListDialogOption --
#  
#       Create the 'typelist' option for the Open Image/Movie dialog and 
#       standard text files.

proc ::Plugins::MakeTypeListDialogOption { } {
    global this
    variable supSuff
    variable supMacTypes
    variable supportedMimeTypes
    variable typelist
    
    array set typelist {
	text        {}
	audio       {}
	video       {}
	application {}
    }
    
    if {$this(platform) == "macintosh"}  {
	
	# On Mac either file extension or 'type' must match.
	set typelist(text) [list  \
	  [list Text $supSuff(text)]  \
	  [list Text {} $supMacTypes(text)] ]
    } else {
	set typelist(text) [list  \
	  [list Text $supSuff(text)]]
    }
    
    switch -- $this(platform) {
	
	macintosh - macosx - windows - unix {    
	    set typelist(image) [list   \
	      [list Image $supSuff(image)]  \
	      [list Image {} $supMacTypes(image)] ]
	    if {[llength $supSuff(audio)] > 0}  {
		set typelist(audio) [list  \
		  [list Audio $supSuff(audio)]  \
		  [list Audio {} $supMacTypes(audio)]]
	    }
	    if {[llength $supSuff(video)] > 0}  {
		set typelist(video) [list  \
		  [list Video $supSuff(video)]  \
		  [list Video {} $supMacTypes(video)]]
	    }	
	    if {[llength $supSuff(application)] > 0}  {
		set typelist(application) [list  \
		  [list Application $supSuff(application)]  \
		  [list Application {} $supMacTypes(application)]]
	    }	
	    if {[llength $supSuff(text)] > 0}  {
		set typelist(text) [list  \
		  [list Text $supSuff(text)]  \
		  [list Text {} $supMacTypes(text)]]
	    }	
	    
	    # Use mime description as entries.
	    set mimeTypeList {}
	    foreach mime $supportedMimeTypes(all) {
		lappend mimeTypeList   \
		  [list [::Types::GetDescriptionForMime $mime]  \
		  [::Types::GetSuffixListForMime $mime]  \
		  [::Types::GetMacTypeListForMime $mime]]
	    }
	    set mimeTypeList [lsort -index 0 $mimeTypeList]
	    set typelist(binary) [concat $typelist(image) $typelist(audio) \
	      $typelist(video) $typelist(application)]
	    set typelist(binary) [concat $typelist(binary) $mimeTypeList]
	    lappend typelist(binary) [list "Any File" *]
	    
	} 
	
	default {
	    # Make a separate entry for each file extension. Sort.
	    foreach mimeBase {text image audio video application} {
		foreach ext $supSuff($mimeBase) {
		    lappend typelist($mimeBase)  \
		      [list [string toupper [string trim $ext .]] $ext]
		}
	    }
	    set sortlist [lsort -index 0 [concat $typelist(image) $typelist(audio) \
	      $typelist(video) $typelist(application)]]
	    set typelist(binary) $sortlist
	    set typelist(binary) "$sortlist {{Any File} *}"	    
	}  
    }
    
    # Complete -typelist option.
    set typelist(all) [concat $typelist(text) $typelist(binary)]
}

proc ::Plugins::InitHook { } {
    
    ::Plugins::VerifyPackagesForMimeTypes
    if {[::Plugins::HavePackage QuickTimeTcl]} {
	::Plugins::QuickTimeTclInitHook
    }
}

proc ::Plugins::QuickTimeTclInitHook { } {
    
    ::WB::RegisterHandler QUICKTIME ::Import::QuickTimeHandler    
}

# Plugins::VerifyPackagesForMimeTypes --
#
#       Goes through all the logic of verifying the 'mimeTypeDoWhat' 
#       and the actual packages available on our system.
#       The 'mimeTypeDoWhat' is stored in our preference file, but the
#       'prefMimeType2Package' is partly determined at runtime, and depends
#       on which packages found at launch.
#       
# Arguments:
#       none.
#   
# Results:
#       updates the 'mimeTypeDoWhat' and 'prefMimeType2Package' arrays.

proc ::Plugins::VerifyPackagesForMimeTypes { } {
    global prefs
    variable plugin
    variable prefMimeType2Package
    variable mimeTypeDoWhat
    variable mimeType2Packages
    
    ::Debug 2 "::Plugins::VerifyPackagesForMimeTypes"
    
    foreach mime [::Types::GetAllMime] {
	if {![info exists mimeTypeDoWhat($mime)]} {
	    set mimeTypeDoWhat($mime) unavailable
	}
	if {![info exists prefMimeType2Package($mime)]} {
	    set prefMimeType2Package($mime) ""
	}
	
	switch -- $mimeTypeDoWhat($mime) {
	    unavailable {
		if {[llength $prefMimeType2Package($mime)]} {
		    
		    # In case there was a new package(s) added, pick that one.
		    set mimeTypeDoWhat($mime) $prefMimeType2Package($mime)
		}
	    }
	    reject {
		if {[llength $prefMimeType2Package($mime)] == 0} {
		    
		    # In case a package was removed.
		    set mimeTypeDoWhat($mime) unavailable
		}
	    }    
	    save - ask {
		# Do nothing.
	    }
	    default {
		
		# This should be a package name. 
		if {![info exists mimeType2Packages($mime)] ||  \
		  ([lsearch -exact $mimeType2Packages($mime)   \
		  $mimeTypeDoWhat($mime)] < 0)} {
		    
		    # There are either no package that supports this mime,
		    # or the selected package is not there.
		    if {[llength $prefMimeType2Package($mime)]} {
			set mimeTypeDoWhat($mime) $prefMimeType2Package($mime)
		    } else {
			set mimeTypeDoWhat($mime) unavailable
		    }
		} else {		
		    set prefMimeType2Package($mime) $mimeTypeDoWhat($mime)
		}
	    }
	}
    }
}

# Plugins::GetPreferredPackageForMime, ... --
#
#       Various accesor functions.

proc ::Plugins::GetPreferredPackageForMime {mime} {
    variable prefMimeType2Package

    if {[info exists prefMimeType2Package($mime)]} {
	return $prefMimeType2Package($mime)
    } else {
	return ""
    }
}

proc ::Plugins::SetPreferredPackageForMime {mime packName} {
    variable prefMimeType2Package

    set prefMimeType2Package($mime) $packName
}

proc ::Plugins::GetPackageListForMime {mime} {
    variable mimeType2Packages
    
    if {[info exists mimeType2Packages($mime)]} {
	return $mimeType2Packages($mime)
    } else {
	return ""
    }
}

proc ::Plugins::GetPreferredPackageArr { } {
    variable prefMimeType2Package

    return [array get prefMimeType2Package]
}

proc ::Plugins::SetPreferredPackageArr {prefMime2PackArrName} {
    variable prefMimeType2Package
    upvar $prefMime2PackArrName locArrName

    unset -nocomplain prefMimeType2Package
    array set prefMimeType2Package [array get locArrName]
}

proc ::Plugins::GetDoWhatForMime {mime} {
    variable mimeTypeDoWhat

    if {[info exists mimeTypeDoWhat($mime)]} {
	return $mimeTypeDoWhat($mime)
    } else {
	return ""
    }
}

proc ::Plugins::HavePackage {name} {
    variable plugin
    
    if {[info exists plugin($name,loaded)]} {
	return $plugin($name,loaded)
    } else {
	return 0
    }
}

proc ::Plugins::HaveImporterForMime {mime} {
    variable plugin
    variable prefMimeType2Package
    
    set ans 0
    if {[info exists prefMimeType2Package($mime)]} {
	set name $prefMimeType2Package($mime)
	if {[string length $name] &&  \
	  [string length $plugin($name,importProc)]} {
	    set ans 1
	}
    }
    return $ans
}

proc ::Plugins::GetImportProcForMime {mime} {
    variable plugin
    variable prefMimeType2Package
    
    if {[info exists prefMimeType2Package($mime)]} {
	set name $prefMimeType2Package($mime)
	if {[string length $name] &&  \
	  [string length $plugin($name,importProc)]} {
	    return $plugin($name,importProc)
	}
    }
    return -code error "No importer found for mime \"$mime\""
}

proc ::Plugins::GetImportProcForPlugin {name} {
    variable plugin
    variable prefMimeType2Package
    
    if {[string length $plugin($name,importProc)]} {
	return $plugin($name,importProc)
    } else {
	return -code error "No importer procedure found for plugin \"$name\""
    }
}

proc ::Plugins::GetImportProcForWinClass {winClass} {
    variable plugin
    
    if {[info exists plugin($winClass,importProc)] &&  \
      [string length $plugin($winClass,importProc)]} {
	return $plugin($winClass,importProc)
    } else {
	return -code error "No import procedure found for window class \"$winClass\""
    }
}

proc ::Plugins::SetDoWhatForMime {mime action} {
    variable mimeTypeDoWhat
    
    set mimeTypeDoWhat($mime) $action
}

proc ::Plugins::GetDoWhatForMimeArr { } {
    variable mimeTypeDoWhat

    return [array get mimeTypeDoWhat]
}

proc ::Plugins::SetDoWhatForMimeArr {doWhatArrName} {
    variable mimeTypeDoWhat
    upvar $doWhatArrName locArrName

    unset -nocomplain mimeTypeDoWhat
    array set mimeTypeDoWhat [array get locArrName]
}

proc ::Plugins::GetTypeListDialogOption {{what all}} {
    variable typelist
    
    return $typelist($what)
}

proc ::Plugins::IsHost {name} {    
    variable plugin

    if {[info exists plugin($name,ishost)]} {
	return $plugin($name,ishost)
    } else {
	return 0
    }
}

proc ::Plugins::IsLoaded {name} {    
    variable plugin

    if {[info exists plugin($name,loaded)]} {
	return $plugin($name,loaded)
    } else {
	return 0
    }
}

proc ::Plugins::GetType {name} {
    variable plugin

    if {[info exists plugin($name,type)]} {
	return $plugin($name,type)
    } else {
	return ""
    }
}

proc ::Plugins::GetTypeDesc {name} {
    variable plugin

    if {[info exists plugin($name,type)]} {
	return [::Plugins::GetDescForPlugType $plugin($name,type)]
    } else {
	return ""
    }
}

#       key         this can be any of the array keys.

proc ::Plugins::GetSuffixes {key} {
    variable supSuff

    if {[info exists supSuff($key)]} {
	return $supSuff($key)
    } else {
	return ""
    }
}

proc ::Plugins::GetDescForPlugin {name} {
    variable plugin

    if {[info exists plugin($name,desc)]} {
	return $plugin($name,desc)
    } else {
	return ""
    }
}

proc ::Plugins::GetDescForPlugType {plugtype} {
    variable plugType2DescArr

    if {[info exists plugType2DescArr($plugtype)]} {
	return $plugType2DescArr($plugtype)
    } else {
	return ""
    }
}

proc ::Plugins::HaveHTTPTransportForPlugin {name} {
    variable plugin

    if {[info exists plugin($name,importHttpProc)] &&  \
      [string length $plugin($name,importHttpProc)]} {
	return 1
    } else {
	return 0
    }
}

proc ::Plugins::GetHTTPImportProcForPlugin {name} {
    variable plugin
    
    if {[info exists plugin($name,importHttpProc)] &&  \
      [string length $plugin($name,importHttpProc)]} {
	return $plugin($name,importHttpProc)
    } else {
	return -code error "No HTTP importer procedure found for plugin \"$name\""
    }
}

proc ::Plugins::HaveHTTPTransportForMimeAndPlugin {name mime} {
    variable plugin

    set httpTrpt 0
    regexp {^([^/]+)/.*} $mime match mimeBase
    if {[info exists plugin($name,trpt,$mime)] && \
      [string equal $plugin($name,trpt,$mime) "http"]} {
	set httpTrpt 1      
    } elseif {[info exists plugin($name,trpt,$mimeBase)] && \
      [string equal $plugin($name,trpt,$mimeBase) "http"]} {
	set httpTrpt 1
    }
    return $httpTrpt
}

proc ::Plugins::HaveSaveProcForWinClass {winClass} {
    variable plugin

    if {[info exists plugin($winClass,saveProc)] &&  \
      [string length $plugin($winClass,saveProc)]} {
	return 1
    } else {
	return 0
    }
}

proc ::Plugins::GetSaveProcForWinClass {winClass} {
    variable plugin
    
    if {[info exists plugin($winClass,saveProc)] &&  \
      [string length $plugin($winClass,saveProc)]} {
	return $plugin($winClass,saveProc)
    } else {
	return -code error "No save procedure found for window class \"$winClass\""
    }
}

proc ::Plugins::GetVersionForPackage {name} {
    variable plugin

    if {[info exists plugin($name,ver)]} {
	return $plugin($name,ver)
    } else {
	return ""
    }
}

proc ::Plugins::GetIconForPackage {doWhat size} {
    variable plugin

    if {[info exists plugin($doWhat,icon,$size)]} {
	return $plugin($doWhat,icon,$size)
    } else {
	return ""
    }
}

# Plugins::NewMimeType, DeleteMimeType --
# 
#       Some consistency checks necassary after using these functions...

proc ::Plugins::NewMimeType {mime packList prefPack doWhat} {
    variable plugin
    variable mimeType2Packages 
    variable prefMimeType2Package
    variable mimeTypeDoWhat
    
    set mimeType2Packages($mime) $packList
    set prefMimeType2Package($mime) $prefPack
    set mimeTypeDoWhat($mime) $doWhat
}

proc ::Plugins::DeleteMimeType {mime} {
    variable plugin
    variable mimeType2Packages 
    variable prefMimeType2Package
    variable mimeTypeDoWhat

    unset -nocomplain mimeType2Packages($mime) \
      prefMimeType2Package($mime) \
      mimeTypeDoWhat($mime)
}

#--- Support Functions ---------------------------------------------------------
#
#       Provide functions for external plugins and packages to call to register
#       themselves with the applications plugin architecture.
#
# canvasBindList:
#       {buttonName bindCommand ?buttonName bindCommand ...?}
#       ex: { point {{bind MyFrame <Button-1>} {::My::Clicked %W %X %Y}} }
#       ex: { point {{%W bind card <Button-1>} {::My::Clicked %W %X %Y}} }

proc ::Plugins::LoadPluginDirectory {dir} {
    
    ::Debug 2 "::Plugins::LoadPluginDirectory"
    
    # The 'pluginDefs' file is sourced in own namespace. 
    # It needs the 'dir' to be there.
    set indexFile [file join $dir pluginDefs.tcl]
    if {[file exists $indexFile]} {
	source $indexFile
    }
}

proc ::Plugins::Load {fileName initProc} {
    
    uplevel #0 [list source $fileName]
    uplevel #0 $initProc
}

# Plugins::Register --
# 
#       Invoked to register an "external" plugin for whiteboard.

proc ::Plugins::Register {name defList canvasBindList} {
    variable plugin
    variable canvasClassBinds
    
    ::Debug 2 "::Plugins::Register name=$name"
    
    set defListDefaults {\
      type          external          \
      desc          ""                \
      platform      ""                \
      importProc    ""                \
      mimes         ""                \
    }    
    
    # Set default values that may be overwritten.
    foreach {key value} $defListDefaults {
	set plugin($name,$key) $value
    }
    
    # Cache various info.
    foreach {key value} $defList {
	set plugin($name,$key) $value
    }
    if {[info exists plugin($name,winClass)]} {
	set winClass $plugin($name,winClass)
	set plugin($winClass,importProc) $plugin($name,importProc)
	set plugin($winClass,saveProc)   $plugin($name,saveProc)
    }
    
    # Cache canvas binds for each whiteboard tool.
    foreach {btname bindDef} $canvasBindList {
	lappend canvasClassBinds($name,$btname) $bindDef
    }
    set canvasClassBinds($name,name) $name
    set plugin($name,loaded) 1
}

# Plugins::DeRegister --
# 
#       Invoked to deregister an "external" plugin.

proc ::Plugins::DeRegister {name} {
    variable plugin
    variable canvasClassBinds
    
    set plugin(allExternalPacks) \
      [lsearch -all -inline -not $plugin(allExternalPacks) $name]
    set plugin(allPacks)  \
      [concat $plugin(allInternalPacks) $plugin(allExternalPacks)]
    set plugin(all) [concat $plugin(allPacks) $plugin(allApps)]
    array unset plugin "${name},*"
    array unset canvasClassBinds "${name},*"
}

# Plugins::RegisterCanvasClassBinds --
# 
#       Register canvas bindings directly. These are applied to all whiteboards.
#       
#       bindList: {{move    {bindDef     tclProc}} {...} ...}
#       We do %W -> canvas substitution on bindDef, and $wcan substitution
#       on the tclProc. % substitution is done as usal in tclProc.

proc ::Plugins::RegisterCanvasClassBinds {name bindList} {
    variable plugin
    variable canvasClassBinds
    
    # Cache canvas binds for each whiteboard tool.
    foreach {btname bindDef} $bindList {
	lappend canvasClassBinds($name,$btname) $bindDef
    }
    set canvasClassBinds($name,name) $name
}

proc ::Plugins::DeregisterCanvasClassBinds {{name {}}} {
    variable canvasClassBinds

    if {$name == ""} {
	array unset canvasClassBinds
    } else {
	array unset canvasClassBinds "${name},*"
    }
}

# Plugins::RegisterCanvasInstBinds --
# 
#       Register canvas bindings directly for the specific canvas instance.

proc ::Plugins::RegisterCanvasInstBinds {w name bindList} {
    variable plugin
    variable canvasInstBinds
    
    # Cache canvas binds for each whiteboard tool.
    foreach {btname bindDef} $bindList {
	lappend canvasInstBinds($w,$name,$btname) $bindDef
    }
    set canvasInstBinds($w,$name,name) $name
}

proc ::Plugins::DeregisterCanvasInstBinds {w {name {}}} {
    variable canvasInstBinds

    if {$name == ""} {
	array unset canvasInstBinds "${w},*"
    } else {
	array unset canvasInstBinds "${w},${name},*"
    }
}

# Plugins::SetCanvasBinds --
# 
#       Invoked when tool button in whiteboard clicked to update and set
#       canvas bindings.

proc ::Plugins::SetCanvasBinds {wcan oldTool newTool} {
    variable plugin
    variable canvasClassBinds
    variable canvasInstBinds
    
    ::Debug 3 "::Plugins::SetCanvasBinds oldTool=$oldTool, newTool=$newTool"

    # Canvas class bindings.
    foreach key [array names canvasClassBinds *,name] {
	set name $canvasClassBinds($key)
    
	# Remove any previous binds.
	if {($oldTool != "") && [info exists canvasClassBinds($name,$oldTool)]} {
	    foreach binds $canvasClassBinds($name,$oldTool) {
		foreach {bindDef cmd} $binds {
		    regsub -all {\\|&} $bindDef {\\\0} bindDef
		    regsub -all {%W} $bindDef $wcan bindDef
		    eval $bindDef {{}}
		}
	    }
	}
	
	# Add registered binds.
	set bindList {}
	if {[info exists canvasClassBinds($name,$newTool)]} {
	    set bindList [concat $bindList $canvasClassBinds($name,$newTool)]
	}
	if {[info exists canvasClassBinds($name,*)]} {
	    set bindList [concat $bindList $canvasClassBinds($name,*)]
	} 
	foreach binds $bindList {
	    foreach {bindDef cmd} $binds {
		regsub -all {\\|&} $bindDef {\\\0} bindDef
		regsub -all {%W} $bindDef $wcan bindDef
		set cmd [subst -nocommands -nobackslashes $cmd]
		eval $bindDef [list $cmd]
	    }
	}
    }
    
    # Instance specific bindings.
    # Beware: 'bind itemID' fails if not exists. Catch.
    foreach key [array names canvasInstBinds $wcan,*,name] {
	set name $canvasInstBinds($key)
    
	# Remove any previous binds.
	if {($oldTool != "") && [info exists canvasInstBinds($wcan,$name,$oldTool)]} {
	    foreach binds $canvasInstBinds($wcan,$name,$oldTool) {
		foreach {bindDef cmd} $binds {
		    regsub -all {\\|&} $bindDef {\\\0} bindDef
		    regsub -all {%W} $bindDef $wcan bindDef
		    catch {eval $bindDef {{}}}
		}
	    }
	}
	
	# Add registered binds.
	set bindList {}
	if {[info exists canvasInstBinds($wcan,$name,$newTool)]} {
	    set bindList [concat $bindList  \
	      $canvasInstBinds($wcan,$name,$newTool)]
	}
	if {[info exists canvasInstBinds($wcan,$name,*)]} {
	    set bindList [concat $bindList $canvasInstBinds($wcan,$name,*)]
	} 
	foreach binds $bindList {
	    foreach {bindDef cmd} $binds {
		regsub -all {\\|&} $bindDef {\\\0} bindDef
		regsub -all {%W} $bindDef $wcan bindDef
		set cmd [subst -nocommands -nobackslashes $cmd]
		catch {eval $bindDef [list $cmd]}
	    }
	}
    }    
}

# Preference pages -------------------------------------------------------------

proc ::Plugins::InitPrefsHook { } {
    global  prefs
    
    # Plugin ban list. Do not load these packages.
    set prefs(pluginBanList) {}
    ::Debug 2 "::Plugins::InitPrefsHook"
    
    ::PreferencesUtils::Add [list  \
      [list prefs(pluginBanList)   prefs_pluginBanList   $prefs(pluginBanList)]]
    
    # Load all plugins available.
    ::Plugins::SetBanList $prefs(pluginBanList)
    ::Plugins::Init
}

proc ::Plugins::BuildPrefsHook {wtree nbframe} {
    
    if {![$wtree isitem Whiteboard]} {
	$wtree newitem {Whiteboard} -text [mc Whiteboard]
    }
    $wtree newitem {Whiteboard Plugins2} -text [mc Plugins]

    set wpage [$nbframe page Plugins2]
    ::Plugins::BuildPrefsPage $wpage
}

proc ::Plugins::BuildPrefsPage {page} {
    global  prefs
    
    variable prefplugins
    variable tmpPrefPlugins

    # Conference (groupchat) stuff.
    set labfr $page.fr
    labelframe $labfr -text [mc {Plugin Control}]
    pack $labfr -side top -anchor w -padx 8 -pady 4
    set pbl [frame $labfr.frin]
    pack $pbl -padx 10 -pady 6 -side left
    
    label ${pbl}.lhead -wraplength 300 -anchor w -justify left \
      -text [mc prefplugctrl]
    pack ${pbl}.lhead -padx 0 -pady 2 -side top -anchor w
        
    set pfr [frame ${pbl}.frpl]
    pack $pfr -side top -anchor w
    set i 0
    foreach plug [::Plugins::GetAllPackages platform] {
	set icon [::Plugins::GetIconForPackage $plug 12]
	if {$icon != ""} {
	    label ${pfr}.i${i} -image $icon
	    grid ${pfr}.i${i} -row $i -column 0 -sticky w
	}
	set tmpPrefPlugins($plug) [::Plugins::IsLoaded $plug]
	checkbutton ${pfr}.c${i} -anchor w -text " $plug"  \
	  -variable [namespace current]::tmpPrefPlugins($plug)
	grid ${pfr}.c${i} -row $i -column 1 -padx 2 -sticky ew
	incr i
    }
    foreach plug $prefs(pluginBanList) {
	set tmpPrefPlugins($plug) 0
	set prefplugins($plug) $tmpPrefPlugins($plug)
    }
}

proc ::Plugins::SaveHook { } {
    global prefs
    variable prefplugins
    variable tmpPrefPlugins
    
    # To be correct we should also have loaded the pack here. TODO.
    set banList {}
    foreach name [array names tmpPrefPlugins] {
	if {$tmpPrefPlugins($name) == 0} {
	    lappend banList $name
	}
	if {$tmpPrefPlugins($name) != $prefplugins($name)} {
	    ::Preferences::NeedRestart
	}
    }
    set prefs(pluginBanList) [lsort -unique $banList]
    unset -nocomplain tmpPrefPlugins
}

proc ::Plugins::CancelHook { } {
    variable prefplugins
    variable tmpPrefPlugins
    
    # Detect any changes.
    foreach p [array names tmpPrefPlugins] {
	if {$tmpPrefPlugins($p) != $prefplugins($p)} {
	    ::Preferences::HasChanged
	    return
	}
    }    
}

proc ::Plugins::UserDefaultsHook { } {
    variable prefplugins
    variable tmpPrefPlugins
    
    foreach plug [::Plugins::GetAllPackages platform] {
	set tmpPrefPlugins($plug) [::Plugins::IsLoaded $plug]
	set prefplugins($plug) $tmpPrefPlugins($plug)
    }    
}

#-------------------------------------------------------------------------------
