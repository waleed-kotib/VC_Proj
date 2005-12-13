#  Avatar.tcl --
#  
#       This is part of The Coccinella application.
#       It provides an application interface to the jlib avatar package.
#       
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: Avatar.tcl,v 1.3 2005-12-13 13:57:52 matben Exp $

# @@@ Issues:
#     1) shall we keep cache of users avatars between sessions to save bandwidth?
#     2) shall we compare users hash to see if they are the same?
#     3) shall we keep a hash of our own avatar and store only if new?

package require jlib::avatar

package provide Avatar 1.0

namespace eval ::Avatar:: {
    
    ::hooks::register  initHook        ::Avatar::InitHook
    ::hooks::register  prefsInitHook   ::Avatar::InitPrefsHook
    ::hooks::register  jabberInitHook  ::Avatar::JabberInitHook
    ::hooks::register  loginHook       ::Avatar::LoginHook
        
    # Array 'photo' contains our internal storage for users images.
    variable photo
    
    # Our own avatar stuff.
    variable myphoto
    
    # Allowed sizes of my avatar.
    variable sizes {32 48 64}
        
    # This package must be controllable from other components.
    # Typically from the roster style code.
    variable options
    array set options {
	-active     0
	-autoget    0
	-command    ""
    }
    
    # There are two sets of prefs:
    #   1) our own avatar which must be controllable directly from UI
    #   2) getting others which is controlled by other packages
    
    variable aprefs
    
    # There shall only be at most one image file in myAvatarPath and this is
    # by default also my avatar.
    set aprefs(myavatarhash) ""
    set aprefs(share)        0
    set aprefs(fileName)     ""
}

proc ::Avatar::Configure {args} {
    variable options
    upvar ::Jabber::jstate jstate
    
    Debug "::Avatar::Configure"
    
    set jlib $jstate(jlib)
    
    if {[llength $args] == 0} {
	return [array get options]
    } elseif {[llength $args] == 1} {
	return $options($args)
    } else {
	foreach {key value} $args {
	    switch -- $key {
		-command {
		    if {$value ne ""} {
			$jlib avatar configure -command ::Avatar::UpdateHash
		    } else {
			$jlib avatar configure -command ""
		    }
		}
	    }
	    set options($key) $value
	}
    }
}

proc ::Avatar::InitHook { } {
    variable aprefs
    
    Debug "::Avatar::InitHook"
    
    set fileName [GetMyAvatarFile]
    if {[file isfile $fileName]} {
	set aprefs(fileName) $fileName
	if {[CreatePhoto $fileName name]} {
	    SetMyPhoto $name
	}   
    }
}

proc ::Avatar::InitPrefsHook { } {
    variable aprefs
    
    ::PrefUtils::Add [list  \
      [list ::Avatar::aprefs(share)  avatar_share  $aprefs(share)]]
}

proc ::Avatar::JabberInitHook {jlibname} {
    global  this
    variable aprefs
    
    Debug "::Avatar::JabberInitHook"
    
    if {$aprefs(share) && [file isfile $aprefs(fileName)]} {
	ShareImage $aprefs(fileName)
    }
}

proc ::Avatar::LoginHook { } {
    variable aprefs
    upvar ::Jabber::jstate jstate
    
    Debug "::Avatar::LoginHook"
    
    set jlib $jstate(jlib)
    
    # @@@ Perhaps this shall be done from 'avatar' instead ?
    if {$aprefs(share) && [file isfile $aprefs(fileName)]} {
	$jlib avatar store ::Avatar::SetCB
    }
}

#--- First section deals with our own avatar -----------------------------------

proc ::Avatar::Load {fileName} {
    
    Debug "::Avatar::Load"
    
    if {[CreatePhoto $fileName name]} {
	SetMyPhoto $name
	SaveFile $fileName
	ShareImage $fileName
    }
}

# Avatar::CreatePhoto --
# 
# 

proc ::Avatar::CreatePhoto {fileName nameVar} {
    upvar $nameVar name
    variable sizes
    
    Debug "::Avatar::CreatePhoto"
    
    # Some error handling:
    set mime [::Types::GetMimeTypeForFileName $fileName]
    if {[lsearch {image/gif image/png} $mime] < 0} {
	set msg "Our avatar shall be either a PNG or a GIF file."
	::UI::MessageBox -message $msg -icon error -title [mc Error]
	return 0
    }
	
    # Make sure it is an image.
    if {[catch {set name [image create photo -file $fileName]}]} {
	set msg "Failed to create an image from [file tail $fileName]"
	::UI::MessageBox -message $msg -icon error -title [mc Error]
	return 0
    }
    
    # For the time being we limit sizes to 32, 48, or 64.
    set width  [image width $name]
    set height [image height $name]
    if {($width != $height) || ([lsearch $sizes $width] < 0)} {
	set msg "We require that the avatar be square of size [join $sizes {, }]"
	::UI::MessageBox -message $msg -icon error -title [mc Error]
	image delete $name
	return 0
    }
    return 1
}

proc ::Avatar::SetMyPhoto {name} {
    variable myphoto
    
    Debug "::Avatar::SetMyPhoto"
    
    if {![info exists myphoto(image)]} {
	set myphoto(image) [image create photo]
    }
    $myphoto(image) copy $name    
}

proc ::Avatar::GetMyPhoto { } {
    variable myphoto
    
    Debug "::Avatar::GetMyPhoto"
    
    if {[info exists myphoto(image)]} {
	return $myphoto(image)
    } else {
	return ""
    }
}

proc ::Avatar::UnsetMyPhoto { } {
    global  this
    variable myphoto
    variable aprefs
    upvar ::Jabber::jstate jstate
    
    Debug "::Avatar::UnsetMyPhoto"
        
    if {[info exists myphoto(image)]} {
	image delete $myphoto(image)
	unset -nocomplain myphoto(image)
    }
    set aprefs(fileName) ""
    set dir $this(myAvatarPath)
    foreach f [glob -nocomplain -directory $dir *] {
	file delete $f
    }
}

# Avatar::SaveFile --
# 
#       Store the avatar file in prefs folder to protect it from being removed.
#       Returns cached file name.

proc ::Avatar::SaveFile {fileName} {
    global  this
    variable aprefs
    
    Debug "::Avatar::SaveFile"
    
    set dir [file normalize $this(myAvatarPath)]

    # We must deal with the situation that fileName already is in cache dir.
    if {[string equal $dir [file normalize [file dirname $fileName]]]} {
	set aprefs(fileName) $fileName
    } else {
	
	# Store the avatar file in prefs folder to protect it from being removed.
	foreach f [glob -nocomplain -directory $dir *] {
	    file delete $f
	}
	file copy $fileName $dir
	set aprefs(fileName) [file join $dir [file tail $fileName]]
    }
    return $aprefs(fileName)
}

proc ::Avatar::GetMyAvatarFile { } {
    global  this
    
    Debug "::Avatar::GetMyAvatarFile"
    
    set fileNames [glob -nocomplain -types f  \
      -directory $this(myAvatarPath) *.gif *.png]
    set fileName [lindex $fileNames 0]
    if {[file isfile $fileName]} {
	return $fileName
    } else {
	return ""
    }
}

proc ::Avatar::ShareImage {fileName} {
    upvar ::Jabber::jstate jstate
    
    Debug "::Avatar::ShareImage"
    
    # @@@ We could try to be economical by not storing the same image twice

    set fd [open $fileName]
    fconfigure $fd -translation binary
    set data [read $fd]
    close $fd

    set mime [::Types::GetMimeTypeForFileName $fileName]

    set jlib $jstate(jlib)
    $jlib avatar set_data $data $mime
    
    # If we configure while online need to update our presence info and
    # store the data with the server.
    if {[$jlib isinstream]} {
	$jlib send_presence -keep 1
	$jlib avatar store ::Avatar::SetCB
    }
}

# Avatar::UnshareImage --
# 
#       Remove our avatar for public usage.

proc ::Avatar::UnshareImage { } {
    upvar ::Jabber::jstate jstate
    
    Debug "::Avatar::UnshareImage"
    
    set jlib $jstate(jlib)
    $jlib avatar unset_data
    
    if {[$jlib isinstream]} {
	set xElem [wrapper::createtag x  \
	  -attrlist [list xmlns "jabber:x:avatar"]]
	$jlib send_presence -xlist [list $xElem] -keep 1
	$jlib avatar store_remove ::Avatar::SetCB
    }    
}

proc ::Avatar::SetCB {jlibname type queryElem} {
    
    if {$type eq "error"} {
	::Jabber::AddErrorLog {} $queryElem
    }
}

#--- Second section deals with others avatars ----------------------------------

# We reuse images for a jid to get them automatically displayed wherever they
# are being used.

proc ::Avatar::UpdateHash {jid} {
    variable options
    upvar ::Jabber::jstate jstate
    
    Debug "::Avatar::UpdateHash jid=$jid"
    
    set jlib $jstate(jlib)    
    if {$options(-autoget)} {
	$jlib avatar get_async $jid ::Avatar::GetAsyncCB
    }
}

proc ::Avatar::GetAsyncCB {type jid2} {
    variable options
    variable photo
    upvar ::Jabber::jstate jstate
    
    Debug "::Avatar::GetAsyncCB jid2=$jid2, type=$type"
    
    set jlib $jstate(jlib)
    
    if {$type eq "error"} {
	::Jabber::AddErrorLog $jid $queryElem
	return
    }
    
    # Data may be empty from xmlns='storage:client:avatar' !
    set data [$jlib avatar get_data $jid2]
    if {[string bytelength $data]} {
	SetPhoto $jid2 $data
    } else {
	
	# Alternatives? vCard?
	
    }
}

# Avatar::SetPhoto --
# 
#       Create new photo if not exists and updates the image with the data.
#       Only if we create a new image the command is invoked.

proc ::Avatar::SetPhoto {jid2 data} {
    variable photo
    variable options

    set isnew 0
    set isnew 1
    if {![info exists photo(image,$jid2)]} {
	set photo(image,$jid2) [image create photo]
	set isnew 1
    }
    
    # Be silent? Do we need to decode?
    if {![catch {
	$photo(image,$jid2) put [::base64::decode $data]
    } err]} {
	if {$isnew && $options(-command) ne ""} {
	    $options(-command) $jid2
	}
    } else {
	Debug $err
    }
}

proc ::Avatar::GetPhoto {jid2} {
    variable photo
    
    if {[info exists photo(image,$jid2)]} {
	return $photo(image,$jid2)
    } else {
	return ""
    }
}

proc ::Avatar::HavePhoto {jid2} {
    variable photo
    
    return [info exists photo(image,$jid2)]
}

#--- Utilities -----------------------------------------------------------------

proc ::Avatar::ScalePhoto2->1 {name} {
    
    set new [image create photo]
    $new copy $name -subsample 2
    return $new
}

proc ::Avatar::ScalePhoto4->3 {name} {
    
    set tmp [image create photo]
    set new [image create photo]
    $tmp copy $name -zoom 3
    $new copy $tmp -subsample 4
    image delete $tmp
    return $new
}

#--- Preference UI -------------------------------------------------------------

proc ::Avatar::PrefsFrame {win} {
    variable aprefs
    variable tmpprefs
    variable wphoto
    variable wshare
    
    set tmpprefs(share) $aprefs(share)
    set tmpprefs(fileName) [GetMyAvatarFile]
    set tmpprefs(editedPhoto) 0
    
    ttk::frame $win
    ttk::label $win.title -text [mc {My Avatar}]
    ttk::separator $win.sep -orient horizontal
    ttk::checkbutton $win.share -text "Share this avatar with other users"  \
      -variable [namespace current]::tmpprefs(share)
    # ttk::checkbutton $win.vcard -text "Use this image also for the vCard photo"
    
    set wfr $win.fr
    ttk::frame $win.fr
    
    set wava $wfr.ava
    frame $wava -bd 1 -relief sunken -bg white \
      -padx 2 -pady 2 -height 64 -width 64
    ttk::label $wava.l -compound image
    
    grid  $wava.l  -sticky news
    grid columnconfigure $wava 0 -minsize [expr {2*4 + 2*4 + 64}]
    grid rowconfigure    $wava 0 -minsize [expr {2*4 + 2*4 + 64}]
    
    set wbts $wfr.bts
    ttk::frame $wbts
    ttk::button $wbts.file -text [mc {File...}] -command ::Avatar::PrefsFile
    ttk::button $wbts.remove -text [mc Remove] -command ::Avatar::PrefsRemove
    
    grid  $wbts.file    -sticky ew -pady 4
    grid  $wbts.remove  -sticky ew -pady 4

    grid  $wfr.bts  $wfr.ava
    grid $wfr.bts -padx 6

    grid  $win.title  $win.sep
    grid  $win.share  -         -sticky w
    grid  $win.fr     -         -sticky e
    
    grid $win.sep -sticky ew
    grid columnconfigure $win 1 -weight 1

    set wphoto $wava.l
    set wshare $win.share
    
    # Work on tmp images to ease garbage collecting.
    set me [GetMyPhoto]
    if {$me ne ""} {
	set tmpphoto [image create photo]
	$tmpphoto copy $me
	$wphoto configure -image $tmpphoto
    } else {
	$wshare state {disabled}
    }
    bind $win <Destroy> ::Avatar::PrefsFree
    
    return $win
}

proc ::Avatar::PrefsFile { } {
    variable wphoto
    variable wshare
    variable tmpphoto
    variable tmpprefs
    
    set suffs {.gif}
    set types {
	{{Image Files}  {.gif}}
	{{GIF Files}    {.gif}}
    }
    if {[::Plugins::HaveImporterForMime image/png]} {
	lappend suffs .png
	lappend types {{PNG Files}    {.png}}
    }
    lset types 0 1 $suffs
    set fileName [tk_getOpenFile -title "Pick image file" -filetypes $types]
    if {$fileName ne ""} {
	if {[CreatePhoto $fileName me]} {
	    $wphoto configure -image $me
	    if {![info exists tmpphoto]} {
		set tmpphoto [image create photo]
	    }
	    $tmpphoto copy $me
	    set tmpprefs(fileName) $fileName
	    set tmpprefs(editedPhoto) 1
	    $wshare state {!disabled}
	}
    }
}

proc ::Avatar::PrefsRemove { } {
    variable wphoto
    variable wshare
    variable tmpprefs
    variable tmpphoto

    Debug "::Avatar::PrefsRemove"
    
    $wphoto configure -image ""
    set tmpprefs(editedPhoto) 1
    set tmpprefs(fileName)    ""
    set tmpprefs(share)       0
    $wshare state {disabled}
    unset -nocomplain tmpphoto
}

proc ::Avatar::PrefsSave { } {
    variable tmpprefs
    variable tmpphoto
    variable aprefs
    
    set editedShare [expr {$aprefs(share) != $tmpprefs(share)}]
    set aprefs(share) $tmpprefs(share)

    Debug "::Avatar::PrefsSave editedShare=$editedShare"
    #parray tmpprefs

    # Two things: my photo and share.
    # My photo:
    if {$tmpprefs(editedPhoto)} {
	if {[info exists tmpphoto]} {
	    SetMyPhoto $tmpphoto
	} else {
	    UnsetMyPhoto
	}
	if {[file exists $tmpprefs(fileName)]} {
	    set fileName [SaveFile $tmpprefs(fileName)]
	}
    }
    set fileName [GetMyAvatarFile]
    
    # Share:
    if {$aprefs(share)} {
	if {$editedShare || $tmpprefs(editedPhoto)} {
	    if {[file exists $tmpprefs(fileName)]} {
		ShareImage $fileName
	    } else {
		UnshareImage
	    }
	}
    } else {
	if {$editedShare} {
	    UnshareImage	
	}
    }
}

proc ::Avatar::PrefsCancel { } {
    variable tmpprefs
    
    if {$tmpprefs(editedPhoto)} {
	::Preferences::HasChanged
    }
}

proc ::Avatar::PrefsFree { } {
    variable tmpphoto
    variable tmpprefs

    if {[info exists tmpphoto]} {
	image delete $tmpphoto
	unset tmpphoto
    }
    array unset tmpprefs
}

# DnD support:   @@@ TODO

proc ::Avatar::PrefsInitDnD { } {
    
    
    dnd bindtarget $win text/uri-list <Drop>      \
      [list [namespace current]::DnDDrop %W %D %T]   
    dnd bindtarget $win text/uri-list <DragEnter> \
      [list [namespace current]::DnDEnter %W %A %D %T]   
    dnd bindtarget $win text/uri-list <DragLeave> \
      [list [namespace current]::DnDLeave %W %D %T]       
}

proc ::Avatar::PrefsDnDDrop {w data type} {

    # Take only first file.
    set f [lindex $data 0]
	
    # Strip off any file:// prefix.
    set f [string map {file:// ""} $f]
    set f [uriencode::decodefile $f]


}

proc ::Avatar::PrefsDnDEnter {w action data type} {
    
    set act "none"
    set f [lindex $data 0]
    if {[VerifyPhotoFile $f]} {
	$w configure -bg gray50
	set act $action
    }
    return $act
}

proc ::Avatar::PrefsDnDLeave {w data type} {
    
    $w configure -bg white
}

proc ::Avatar::Debug {text} {
    if {0} {
	puts $text
    }
}

#--- Testing:

if {0} {
    set f "/Users/matben/Graphics/Crystal Clear/32x32/apps/bug.png"
    proc ::Avatar::TestCmd {jid2} {
	puts "---> ::Avatar::TestCmd $jid2"
	::Avatar::GetPhoto $jid2
    }
    ::Avatar::Load $f
    ::Avatar::Configure -autoget 1 -command ::Avatar::TestCmd
    
}


