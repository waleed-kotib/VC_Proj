# Media.tcl --
#
#       This file is part of The Coccinella application.
#       Handles image/audio/video supporting packages.
#       No specific whiteboard code.
#       
#  Copyright (c) 2007-2008  Mats Bengtsson
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
# $Id: Media.tcl,v 1.7 2008-05-14 14:05:35 matben Exp $

package provide Media 1.0

namespace eval ::Media {
        
    # Map the mime types for each package.
    variable package2Mime
    
    # Inverse mapping: mime to list of packages.
    variable mime2PackageL
    variable loaded
    variable inited
    set inited(base)  0
    set inited(audio) 0
    set inited(image) 0
    set inited(video) 0
    
    # Search only for packages on platforms they can live on.
    variable packages2Platform
    array set packages2Platform {
	QuickTimeTcl       {macosx      windows} 
	snack              {windows     unix}
	Img                {windows     unix}
    }

    # @@@ TODO
    variable helpers2Platform
    array set helpers2Platform {xanim unix} 

    # Collect the supported mime types for each mime base.
    variable supportedMime
    
    set supportedMime(text)        [list]
    set supportedMime(image)       [list]
    set supportedMime(audio)       [list]
    set supportedMime(video)       [list]
    set supportedMime(application) [list]
    set supportedMime(all)         $supportedMime(text)
}

proc ::Media::GetPlatformsForPackage {name} {
    variable packages2Platform
    if {[info exists packages2Platform($name)]} {
	return $packages2Platform($name)
    } else {
	return [list]
    }
}

proc ::Media::Init {} {
    variable inited
        
    # We should be able to get called anytime.
    if {$inited(base)} { return }

    # Init the standard media packages.
    Tk
    TkPNG
    Img
    QuickTimeTcl
    Snack
    Xanim
    
    # We should do this as an afterFinalHook since loading package can be slow.
    LoadPackages
    MakeMime2Package
    CompileMimes

    # Possibly delay loading of certain packages...
    set inited(base)  1
    set inited(audio) 1
    set inited(image) 1
    set inited(video) 1
}

proc ::Media::Tk {} {
    variable package2Mime    
    variable loaded
    set loaded(tk) 1
    set package2Mime(tk) {
	text/plain
	image/gif  image/x-portable-pixmap
    }
}

proc ::Media::QuickTimeTcl {} {
    variable package2Mime
    variable loaded
    set loaded(QuickTimeTcl) 0
    set package2Mime(QuickTimeTcl) {
	video/quicktime     video/x-dv          video/mpeg
	video/mpeg4         video/flc
	video/x-mpeg        audio/mpeg          audio/x-mpeg
	video/x-msvideo     application/sdp     audio/aiff
	audio/x-aiff        audio/basic         audio/x-sd2
	audio/wav           audio/x-wav         image/x-bmp
	image/vnd.fpx       image/gif           image/jpeg
	image/x-macpaint    image/x-photoshop   image/png
	image/x-png         image/pict          image/x-sgi
	image/x-targa       image/tiff          image/x-tiff
	application/x-world 
	application/x-3dmf  
	application/x-shockwave-flash           audio/midi
	audio/x-midi        audio/vnd.qcelp     video/avi
    }
}
    
proc ::Media::Snack {} {
    variable package2Mime
    variable loaded
    set loaded(snack) 0
    set package2Mime(snack) {
	audio/wav           audio/x-wav         audio/basic
	audio/aiff          audio/x-aiff        audio/mpeg
	audio/x-mpeg
    }
}

proc ::Media::Img {} {
    variable package2Mime
    variable loaded
    set loaded(Img) 0
    set package2Mime(Img) {
	image/x-bmp         image/gif           image/jpeg
	image/png           image/x-png         image/tiff
	image/x-tiff
    }
}
    
proc ::Media::TkPNG {} {
    variable package2Mime
    variable loaded
    set loaded(tkpng) 1
    set package2Mime(tkpng) {
	image/png           image/x-png
    }
}    

proc ::Media::Xanim {} {
    variable package2Mime
    variable loaded
    set loaded(xanim) 0
    set package2Mime(xanim) {
	audio/wav           audio/x-wav         video/mpeg
	video/x-mpeg        audio/mpeg          audio/x-mpeg
	audio/basic         video/quicktime
    }
}
    
proc ::Media::LoadPackages {} {
    global  this
    variable packages2Platform
    variable loaded
    
    foreach name [array names packages2Platform] {
	if {[lsearch $packages2Platform($name) $this(platform)] >= 0} {
	    ::Splash::SetMsg [mc "Looking for %s" $name]...
	    if {![catch {
		package require $name
	    }]} {
		set loaded($name) 1
	    }
	}
    } 
}
    
proc ::Media::MakeMime2Package {} {
    variable package2Mime
    variable mime2PackageL
    variable loaded

    unset -nocomplain mime2PackageL
    foreach {name mimeL} [array get package2Mime] {
	if {$loaded($name)} {
	    foreach mime $mimeL {
		lappend mime2PackageL($mime) $name
	    }
	}
    }
}

proc ::Media::GetMimesForPackage {name} {
    variable package2Mime
    if {[info exists package2Mime($name)]} {
	return $package2Mime($name)
    } else {
	return [list]
    }
}

proc ::Media::HaveImporterForMime {mime} {
    variable mime2PackageL
    Init
    if {[info exists mime2PackageL($mime)] && [llength $mime2PackageL($mime)]} {
	return 1
    } else {
	return 0
    }
}

proc ::Media::GetPackageListForMime {mime} {
    variable mime2PackageL
    if {[info exists mime2PackageL($mime)]} {
	return $mime2PackageL($mime)
    } else {
	return [list]
    }
}

proc ::Media::CompileMimes {} {
    variable package2Mime
    variable supportedMime
    variable loaded

    unset -nocomplain supportedMime
    foreach {name isloaded} [array get loaded] {
	if {!$isloaded} { continue }
	foreach mime $package2Mime($name) {
	    set base [lindex [split $mime /] 0]
	    lappend supportedMime($base) $mime
	}
    }
    set all [list]
    foreach base [array names supportedMime] {
	set supportedMime($base) [lsort -unique $supportedMime($base)]
	set all [concat $all $supportedMime($base)]
    }
    set supportedMime(all) [lsort -unique $all]
}

proc ::Media::GetSupportedMimesForMimeBase {base} {
    variable supportedMime
    if {[info exists supportedMime($base)]} {
	return $supportedMime($base)
    } else {
	return [list]
    }
}

proc ::Media::GetSupportedSuffixesForMimeBase {base} {
    Init
    set suffL [list]
    foreach mime [GetSupportedMimesForMimeBase $base] {
	set suffL [concat $suffL [::Types::GetSuffixListForMime $mime]]
    }
    return [lsort -unique $suffL]
}

proc ::Media::GetSupportedSuffixesForMimeList {mimeL} {
    variable supportedMime
    set suffL [list]
    foreach mime $mimeL {
	if {[HaveImporterForMime $mime]} {
	    set suffL [concat $suffL [::Types::GetSuffixListForMime $mime]]
	}
    }
    return [lsort -unique $suffL]
}

proc ::Media::GetSupportedMimesForMimeList {mimeL} {
    variable supportedMime
    Init
    set mimeSuppL [list]
    foreach mime $mimeL {
	if {[HaveImporterForMime $mime]} {
	    lappend mimeSuppL $mime
	}
    }
    return [lsort -unique $mimeSuppL]
}

proc ::Media::GetSupportedTypesForMimeList {mimeL} {
    variable supportedMime
    Init
    set typeL [list]
    foreach mime $mimeL {
	if {[HaveImporterForMime $mime]} {
	    lappend typeL [string toupper [lindex [split $mime /] 1]]
	}
    }
    return [lsort -unique $typeL]
}

proc ::Media::GetDlgFileTypesForMimeList {mimeL} {    
    Init
    set fileTypes [list]
    foreach mime $mimeL {
	if {[HaveImporterForMime $mime]} {
	    lappend fileTypes [list \
	      [::Types::GetDescriptionForMime $mime] \
	      [::Types::GetSuffixListForMime $mime]]
	}	
    }
    return $fileTypes
}

proc ::Media::GetDlgFileTypesForMimeBase {base} {    
    Init
    set fileTypes [list]
    set suffL [GetSupportedSuffixesForMimeBase $base]
    if {[llength $suffL]} {
	set fileTypes [list [string totitle $base] $suffL]
    }
    return [list $fileTypes]
}


