#  Avatar.tcl --
#  
#       This is part of The Coccinella application.
#       It provides an application interface to the jlib avatar package.
#       While the 'avatar' package handles the actual image data, this package
#       keeps an image in sync with avatar image data.
#       
#  Copyright (c) 2005-2007  Mats Bengtsson
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
# $Id: Avatar.tcl,v 1.36 2007-09-13 08:25:37 matben Exp $

# @@@ Issues:
# 
# Features:
#       1) We don't request avatar for offline users, only if already cached.

package require sha1       ; # tcllib                           
package require jlib::avatar
package require ui::util

package provide Avatar 1.0

namespace eval ::Avatar:: {
    
    ::hooks::register  initHook        ::Avatar::InitHook
    ::hooks::register  prefsInitHook   ::Avatar::InitPrefsHook
    ::hooks::register  jabberInitHook  ::Avatar::JabberInitHook
    ::hooks::register  loginHook       ::Avatar::LoginHook
    ::hooks::register  logoutHook      ::Avatar::LogoutHook
    ::hooks::register  quitAppHook     ::Avatar::QuitHook
    ::hooks::register  presenceAvailableHook   ::Avatar::PresenceHook  20
        
    # Array 'photo' contains our internal storage for users images.
    variable photo

    # Our own avatar stuff.
    variable myphoto
    set myphoto(hash) ""
    
    # Allowed sizes of my avatar.
    variable sizes {32 48 64}
        
    # This package must be controllable from other components.
    # Typically from the roster style code.
    variable options
    array set options {
	-active     0
	-autoget    0
	-cache      1
	-command    ""
    }
    set options(-cachedir) $::this(cacheAvatarPath)

    # Use a priority order if we have hash from both.
    variable protocolPrio {vcard avatar}

    # There are two sets of prefs:
    #   1) our own avatar which must be controllable directly from UI
    #   2) getting others which is controlled by other packages
    
    variable aprefs
    
    # There shall only be at most one image file in myAvatarPath and this is
    # by default also my avatar.
    set aprefs(myavatarhash) ""
    set aprefs(share)        0
    set aprefs(fileName)     ""
    set aprefs(hashmapFile)  [file join $options(-cachedir) hashmap]

    set aprefs(recent)       {}
    set aprefs(recentLen)    16

    variable uid 0

    # We only need a limited set.
    variable suff2Mime
    array set suff2Mime {
	.gif      image/gif
	.png      image/png
	.jpg      image/jpeg
	.jpeg     image/jpeg
    }
    
    variable mime2Suff
    array set mime2Suff {
	image/gif     .gif
	image/png     .png
	image/jpeg    .jpg
    }
}

proc ::Avatar::Configure {args} {
    global  this
    variable options
    upvar ::Jabber::jstate jstate
    
    Debug "::Avatar::Configure $args"
    
    set jlib $jstate(jlib)
    
    if {[llength $args] == 0} {
	return [array get options]
    } elseif {[llength $args] == 1} {
	return $options($args)
    } else {
	set aopts {}
	foreach {key value} $args {
	    switch -- $key {
		-cache {
		    lappend aopts -cache $value
		}
		-command {
		    if {$value ne ""} {
			lappend aopts -command ::Avatar::OnNewHash
		    } else {
			lappend aopts -command ""
		    }
		}
	    }
	    set options($key) $value
	}
	eval {$jlib avatar configure} $aopts
    }
}

# These hooks deal with sharing (announcing) our own avatar.

proc ::Avatar::InitHook { } {
    variable myphoto
    variable aprefs
    
    Debug "::Avatar::InitHook"
    
    set fileName [GetMyAvatarFile]
    if {[file isfile $fileName]} {
	set myphoto(hash) [GetHashForFile $fileName]
	set aprefs(fileName) $fileName
	if {[CreateAndVerifyPhoto $fileName name]} {
	    SetMyPhoto $name
	}   
    }
}

proc ::Avatar::InitPrefsHook { } {
    variable aprefs
    
    ::PrefUtils::Add [list  \
      [list ::Avatar::aprefs(share)   avatar_share   $aprefs(share)] \
      [list ::Avatar::aprefs(recent)  avatar_recent  $aprefs(recent)]]
}

proc ::Avatar::JabberInitHook {jlibname} {
    variable aprefs
    
    Debug "::Avatar::JabberInitHook"
    
    if {$aprefs(share) && [file isfile $aprefs(fileName)]} {
	ShareImage $aprefs(fileName)
    }
    ReadHashmap $aprefs(hashmapFile)
}

proc ::Avatar::LoginHook { } {
    variable aprefs
    upvar ::Jabber::jstate jstate
    
    Debug "::Avatar::LoginHook"
    
    set jlib $jstate(jlib)
    
    # @@@ Do we need to do this each time we login?
    if {$aprefs(share) && [file isfile $aprefs(fileName)]} {
	set base64 [$jlib avatar get_my_data base64]
	set mime   [$jlib avatar get_my_data mime]
	
	# ejabberd has no support for 'storage:client:avatar'
	# $jlib avatar store [list ::Avatar::SetCB 0]
	
	# The vCard we first get and set only if photo is different.
	$jlib vcard set_my_photo $base64 $mime [list ::Avatar::SetCB 0]
    }
}

proc ::Avatar::LogoutHook { } {
    variable options
    
    if {!$options(-cache)} {
	FreeAllPhotos
    }
}

proc ::Avatar::QuitHook { } {
    variable aprefs
    upvar ::Jabber::jstate jstate
    
    WriteHashmap $aprefs(hashmapFile)
}

#--- First section deals with our own avatar -----------------------------------
#
# There are three parts to it:
#   1) the actual photo
#   2) and the corresponding file
#   3) share or not share option
#   
#   o 1 & 2 must be synced together
#   o if share then photo and file must be there

# Avatar::SetAndShareMyAvatarFromFile, UnsetAndUnshareMyAvatar --
# 
#       Mega functions to handle everything when setting and sharing own avatar.

proc ::Avatar::SetAndShareMyAvatarFromFile {fileName} {
    
    Debug "::Avatar::SetAndShareMyAvatarFromFile"

    set ok 0
    if {[CreateAndVerifyPhoto $fileName name]} {
	SetMyPhoto $name
	SaveMyImageFile $fileName
	SetShareOption 1
	ShareImage $fileName
	image delete $name
	set ok 1
	
	::hooks::run avatarMyNewPhotoHook
    }
    return $ok
}

proc ::Avatar::UnsetAndUnshareMyAvatar { } {

    ::Avatar::UnsetMyPhotoAndFile
    ::Avatar::UnshareImage
    ::Avatar::SetShareOption 0  
    
    ::hooks::run avatarMyNewPhotoHook
}

proc ::Avatar::SetMyAvatarFromBase64 {data mime} {
    
    Debug "::Avatar::SetMyAvatarFromBase64"
    
    if {![catch {image create photo -data $data} tmpname]} {
	SetMyPhoto $tmpname
	WriteBase64ToFile $data $mime
	image delete $tmpname

	::hooks::run avatarMyNewPhotoHook
    }
}

# Avatar::WriteBase64ToFile --
# 
#       If we get a server stored vcard photo we need this to sync storage.

proc ::Avatar::WriteBase64ToFile {data mime} {
    global  this
    variable aprefs
    
    Debug "::Avatar::WriteBase64ToFile"
    
    set dir [file normalize $this(myAvatarPath)]

    # Store the avatar file in prefs folder to protect it from being removed.
    foreach f [glob -nocomplain -directory $dir *] {
	file delete $f
    }
    set suff [GetSuffForMime $mime]
    set fileName [file join $dir myavatar$suff]
    set fd [open $fileName w]
    fconfigure $fd -translation binary
    puts -nonewline $fd [::base64::decode $data]
    close $fd
    
    set aprefs(fileName) $fileName
}

# Avatar::CreateAndVerifyPhoto --
# 
# 

proc ::Avatar::CreateAndVerifyPhoto {fileName nameVar} {
    upvar $nameVar name
    
    Debug "::Avatar::CreateAndVerifyPhoto"
    
    set ans [VerifyPhotoFile $fileName]
    if {![lindex $ans 0]} {
	set msg [lindex $ans 1]
	::UI::MessageBox -message $msg -icon error -title [mc Error]
	return 0
    } else {
	if {[catch {set name [image create photo -file $fileName]}]} {
	    return 0
	} else {
	    return 1
	}
    }
}

proc ::Avatar::CreatePhoto {fileName nameVar} {
    upvar $nameVar name
    
    return [catch {set name [image create photo -file $fileName]}]
}

proc ::Avatar::VerifyPhotoFile {fileName} {
    variable sizes

    Debug "::Avatar::VerifyPhotoFile"
    
    set mimes {image/gif image/png image/jpeg}
    set mimeL [::Media::GetSupportedMimesForMimeList $mimes]
    set mime [::Types::GetMimeTypeForFileName $fileName]
    if {[lsearch $mimeL $mime] < 0} {
	set typeL [::Media::GetSupportedTypesForMimeList $mimes]
	set typeText [join $typeL ", "]
	set msg [mc jasuppimagefmts]
	append msg " " $typeText
	append msg "."	
	return [list 0 $msg]
    }
	
    # Make sure it is an image.
    if {[catch {set tmp [image create photo -file $fileName]}]} {
	return [list 0 [mc jamessimagecreateerr [file tail $fileName]]]
    }
    
    # For the time being we limit sizes to 32, 48, or 64.
    set width  [image width $tmp]
    set height [image height $tmp]
    if {($width != $height) || ([lsearch $sizes $width] < 0)} {
	set msg [mc jamessavaerrsize [join $sizes {, }]]
	set ans [list 0 $msg]
    } else {
	set ans 1
    }
    image delete $tmp
    return $ans
}

proc ::Avatar::SetMyPhoto {name} {
    variable myphoto
    
    Debug "::Avatar::SetMyPhoto"
    
    # Keep one and the same image for my photo to get automatic widget updates.
    if {![info exists myphoto(image)]} {
	set myphoto(image) [image create photo]
    }
    $myphoto(image) blank
    $myphoto(image) copy $name -shrink
}

proc ::Avatar::GetMyPhoto { } {
    variable myphoto
    
    if {[info exists myphoto(image)]} {
	return $myphoto(image)
    } else {
	return ""
    }
}

proc ::Avatar::IsMyPhotoFromFile {fileName} {
    variable myphoto
    return [expr {$myphoto(hash) eq [GetHashForFile $fileName]}]
}

proc ::Avatar::IsMyPhotoSharedFromFile {fileName} {
    variable aprefs
    return [expr {$aprefs(share) && [IsMyPhotoFromFile $fileName]}]
}

proc ::Avatar::GetMyPhotoHash { } {
    variable myphoto

    # Note that 'jlib avatar get_my_data hash' only works if online.
    return $myphoto(hash)
}

proc ::Avatar::UnsetMyPhotoAndFile { } {
    global  this
    variable myphoto
    variable aprefs
    upvar ::Jabber::jstate jstate
    
    Debug "::Avatar::UnsetMyPhotoAndFile"
        
    if {[info exists myphoto(image)]} {
	image delete $myphoto(image)
	unset myphoto(image)
    }
    set myphoto(hash) ""
    set aprefs(fileName) ""
    set dir $this(myAvatarPath)
    foreach f [glob -nocomplain -directory $dir *] {
	file delete $f
    }
}

# Avatar::SetShareOption --
# 
#       Just sets the share option. Necessary to sync vCard photo.

proc ::Avatar::SetShareOption {bool} {
    variable aprefs    
    set aprefs(share) $bool
}

proc ::Avatar::GetShareOption { } {
    variable aprefs
    return $aprefs(share)
}

# Avatar::SaveMyImageFile --
# 
#       Store my avatar file in prefs folder to protect it from being removed.
#       Returns cached file name.

proc ::Avatar::SaveMyImageFile {fileName} {
    global  this
    variable aprefs
    variable myphoto
    
    Debug "::Avatar::SaveMyImageFile"
    
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
    set myphoto(hash) [GetHashForFile $fileName]
    return $aprefs(fileName)
}

proc ::Avatar::GetMyAvatarFile { } {
    global  this
    
    Debug "::Avatar::GetMyAvatarFile"
    
    set fileNames [glob -nocomplain -types f  \
      -directory $this(myAvatarPath) *.gif *.png *.jpg *.jpeg]
    set fileName [lindex $fileNames 0]
    if {[file isfile $fileName]} {
	return $fileName
    } else {
	return ""
    }
}

# Avatar::ShareImage --
# 
#       Does everything to share the image file 'fileName'.
#       It sets both internal avatar cache, and if online, also sets our
#       vCard avatar and sends updated presence when stored.
#       It does not handle our application file cache.

proc ::Avatar::ShareImage {fileName} {
    upvar ::Jabber::jstate jstate
    
    Debug "::Avatar::ShareImage --->"
    
    # @@@ We could try to be economical by not storing the same image twice.

    set fd [open $fileName]
    fconfigure $fd -translation binary
    set data [read $fd]
    close $fd

    set mime [::Types::GetMimeTypeForFileName $fileName]

    set jlib $jstate(jlib)
    $jlib avatar set_data $data $mime
    set base64 [$jlib avatar get_my_data base64]
    
    # If we configure while online need to update our presence info and
    # store the data with the server.
    # Saves Avatar into vCard.
    # @@@ Sync issue if not online while storing.
    #     We should have a loginHook here to store any updated avatar.
    if {[$jlib isinstream]} {
	
	# Disabled.
	# $jlib avatar store [list ::Avatar::SetCB 0]
	
	# vCard avatar. 
	# @@@ These are not completely in sync. Send presence from CB?
	$jlib vcard set_my_photo $base64 $mime [list ::Avatar::SetCB 1]
	
	# Do not update presence hashes until we the callback to avoid sync issues.
	#$jlib send_presence -keep 1
    }
}

# Avatar::UnshareImage --
# 
#       Remove our avatar for public usage.
#       It sends new presence with empty hashes.

proc ::Avatar::UnshareImage { } {
    upvar ::Jabber::jstate jstate
    
    Debug "::Avatar::UnshareImage --->"
    
    set jlib $jstate(jlib)
    $jlib avatar unset_data
    
    if {[$jlib isinstream]} {
	$jlib avatar store_remove [list ::Avatar::SetCB 0]
	$jlib vcard set_my_photo {} {} [list ::Avatar::SetCB 0]

	set xElem [wrapper::createtag x  \
	  -attrlist [list xmlns "jabber:x:avatar"]]
	set xVCardElem [wrapper::createtag x  \
	  -attrlist [list xmlns "vcard-temp:x:update"]]
	$jlib send_presence -xlist [list $xElem $xVCardElem] -keep 1
    }    
}

proc ::Avatar::SetCB {sync jlibname type queryElem} {
    upvar ::Jabber::jstate jstate
    
    if {$type eq "error"} {
	::Jabber::AddErrorLog {} $queryElem
    } else {
	
	# Now we are sure avatar is stored and can announce it.
	if {$sync} {
	    set jlib $jstate(jlib)
	    $jlib send_presence -keep 1
	}
    }
}

#--- Handle the "recent" avatar cache ------------------------------------------
#
#   o Always store recent files as hash.suffix
#   o the 'recentAvatarPath' lists the order of the recent file cache;
#     must be kept in sync!

proc ::Avatar::GetRecentFiles {} {
    global  this
    variable aprefs
    
    set recentL {}
    foreach f $aprefs(recent) {
	set fname [file join $this(recentAvatarPath) $f]
	if {[file exists $fname]} {
	    lappend recentL $f
	}
    }
    return $recentL
}

proc ::Avatar::AddRecentFile {fileName} {
    global  this
    variable aprefs
    
    set hash [GetHashForFile $fileName]
    set newTail $hash[file extension $fileName]
    
    set recentL [GetRecentFiles]
    set idx [lsearch $recentL $newTail]

    # If it is already there then just reorder the recent list.
    if {$idx >= 0} {
	set recentL [lreplace $recentL $idx $idx]
	set recentL [linsert $recentL 0 $newTail]
    } else {

	# Put first in list. Guard if already there.
	set recentL [linsert $recentL 0 $newTail]
	set dstFile [file join $this(recentAvatarPath) $newTail]
	if {![file exists $dstFile]} {
	    file copy $fileName $dstFile
	}
	
	# Truncate to max list length.
	foreach f [lrange $recentL $aprefs(recentLen) end] {
	    file delete [file join $this(recentAvatarPath) $f]
	}
	set recentL [lrange $recentL 0 [expr {$aprefs(recentLen) - 1}]]
    }
    set aprefs(recent) $recentL
}

proc ::Avatar::ClearRecent {} {
    global  this
    variable aprefs
    
    set dir $this(recentAvatarPath)
    foreach f [glob -nocomplain -directory $dir *] {
	file delete $f
    }
    set aprefs(recent) {}
}

#--- Second section deals with others avatars ----------------------------------

# We reuse images for a jid to get them automatically displayed wherever they
# are being used.

# Avatar::OnNewHash --
# 
#       Callback when we get a new or updated hash. 
#       If user disables avatar hash is empty.

proc ::Avatar::OnNewHash {jid} {
    variable photo
    variable options
    upvar ::Jabber::jstate jstate
    
    Debug "::Avatar::OnNewHash jid=$jid"
    
    set jid2 [jlib::barejid $jid]
    set jlib $jstate(jlib)

    # For the moment we disable all avatars for room members.
    if {[$jlib service isroom $jid2]} {
	return
    }
    set hash [$jlib avatar get_hash $jid2]
    if {$hash eq ""} {
	if {$options(-command) ne ""} {
	    $options(-command) remove $jid2
	}
	FreePhotos $jid
	FreeHashCache $jid2
    } else {

	# Try first to get the Avatar from Cache.
	if {[HaveCachedHash $hash]} {
	    SetPhotoFromCache $jid2
	} elseif {$options(-autoget)} {
	    GetPrioAvatar $jid
	}
	
	# Try first to get the Avatar from Cache.
	#set data [ReadCacheAvatar $hash]
	#if {$data ne ""} {
	#    SetPhotoFromData $jid2 $data
	#} elseif {$options(-autoget)} {
	#    GetPrioAvatar $jid
	#}
    }
}

# Avatar::GetPrioAvatar --
# 
#       Get either of 'avatar' or 'vcard' avatars.
#       If we have hash from both then get highest prio.

proc ::Avatar::GetPrioAvatar {jid} {
    variable protocolPrio
    upvar ::Jabber::jstate jstate
    
    Debug "::Avatar::GetPrioAvatar jid=$jid"
    
    set jlib $jstate(jlib)
    set jid2 [jlib::barejid $jid]
        
    # We need to know if 'avatar' or 'vcard' style to get.
    # Use a priority order if we have hash from both.    
    # Note that all vCards are defined per jid2, bare JID.
    foreach prot $protocolPrio {
	if {[$jlib avatar have_hash_protocol $jid2 $prot]} {    
	    switch -- $prot {
		avatar {
		    $jlib avatar get_async $jid ::Avatar::GetAvatarAsyncCB
		}
		vcard {
		    $jlib avatar get_vcard_async $jid2 ::Avatar::GetVCardPhotoCB 
		}
	    }
	    break
	}
    }
}

# @@@ Combine these two into one!

proc ::Avatar::GetAvatarAsyncCB {type jid2} {
    variable options
    variable photo
    upvar ::Jabber::jstate jstate
    
    Debug "::Avatar::GetAvatarAsyncCB jid2=$jid2, type=$type"
        
    if {$type eq "error"} {
	InvokeAnyFallbackFrom $jid2 "avatar"
    } else {
	# Data may be empty from xmlns='storage:client:avatar' !
	set jlib $jstate(jlib)
	set data [$jlib avatar get_data $jid2]
	if {[string bytelength $data]} {
	    
	    # It is our responsibility to cache the photo.
	    set hash [$jlib avatar get_hash $jid2]
	    set mime [$jlib avatar get_mime $jid2]
	    WriteCacheAvatar $mime $hash $data
	    
	    SetPhotoFromCache $jid2
	    #SetPhotoFromData $jid2 $data
	} else {
	    InvokeAnyFallbackFrom $jid2 "avatar"
	}
    }
}
    
proc ::Avatar::GetVCardPhotoCB {type jid2} {
    upvar ::Jabber::jstate jstate
    variable xmlns

    Debug "::Avatar::GetVCardPhotoCB jid2=$jid2, type=$type"
    
    if {$type eq "error"} {
	InvokeAnyFallbackFrom $jid2 "vcard"
    } else {
	set jlib $jstate(jlib)
	set data [$jlib avatar get_data $jid2]
	if {[string bytelength $data]} {
	    
	    # It is our responsibility to cache the photo.
	    set hash [$jlib avatar get_hash $jid2]
	    set mime [$jlib avatar get_mime $jid2]
	    WriteCacheAvatar $mime $hash $data
	    
	    SetPhotoFromCache $jid2
	    #SetPhotoFromData $jid2 $data
	} else {
	    InvokeAnyFallbackFrom $jid2 "vcard"
	}
    }
}

# Avatar::InvokeAnyFallbackFrom --
# 
#       Handles any fallback from 'protocol'.

proc ::Avatar::InvokeAnyFallbackFrom {jid2 protocol} {
    variable protocolPrio
    upvar ::Jabber::jstate jstate
    
    Debug "::Avatar::InvokeAnyFallbackFrom jid2=$jid2, protocol=$protocol"
    
    set jlib $jstate(jlib)
    
    # Get next protocol in the priority. If empty we are done.
    set idx [lsearch $protocolPrio $protocol]
    set next [lindex $protocolPrio [incr idx]]
    if {$next ne ""} {
	switch -- $next {
	    avatar {
		set jid [$jlib avatar get_full_jid $jid2]
		$jlib avatar get_async $jid ::Avatar::GetAvatarAsyncCB
	    }
	    vcard {
		$jlib avatar get_vcard_async $jid2 ::Avatar::GetVCardPhotoCB 
	    }
	}
    }
}

# Avatar::GetAsyncIfExists --
# 
#       Can be called to get a specific avatar. Notified via hook. Bad?
#       
#       jid:    jid2 or jid3

proc ::Avatar::GetAsyncIfExists {jid} {
    
    Debug "::Avatar::GetAsyncIfExists jid=$jid"
    
    set jid2 [jlib::barejid $jid]
    set hash [GetHash $jid2]
    if {$hash ne ""} {
	
	# First try to load the avatar from Cache directory.
	if {[HaveCachedHash $hash]} {
	    SetPhotoFromCache $jid2
	    #SetPhotoFromData $jid2 $data
	} else {
	    GetPrioAvatar $jid
	}
    }
}

# Avatar::GetAll --
# 
#       Requests all avatars in our roster.

proc ::Avatar::GetAll { } {
    upvar ::Jabber::jstate jstate
    
    Debug "::Avatar::GetAll"
    
    set jlib $jstate(jlib)

    # @@@ Not sure here...
    foreach jid2 [$jlib roster getusers] {
	set jid [$jlib avatar get_full_jid $jid2]
	GetAsyncIfExists $jid
    }
    return
   
    # BU
    set jlib $jstate(jlib)
    foreach jid2 [$jlib avatar get_all_avatar_jids] {
	
	# This can be a jid2 if vcard.
	set jid [$jlib avatar get_full_jid $jid2]
	GetAsyncIfExists $jid
    }
}

# Avatar::SetPhotoFromData --
# 
#       Create new photo if not exists and updates the image with the data.
#       Any -command is invoked notifying the event.
#       
#       photo(jid,orig) is always the original photo. The size can change if
#                       user updates the avatar with a different size.
#       photo(jid,32)   are photos with respective max size.
#       photo(jid,48)
#       photo(jid,64)   

proc ::Avatar::SetPhotoFromData {jid2 data} {
    variable photo
    variable options

    Debug "::Avatar::SetPhotoFromData jid2=$jid2"
    
    set type put
    set mjid2 [jlib::jidmap $jid2]
    if {![info exists photo($mjid2,orig)]} {
	set photo($mjid2,orig) [image create photo]
	set type create
    }
    
    # Be silent!
    if {![catch {
	PutPhotoFromData $jid2 $data
    } err]} {
	if {$options(-command) ne ""} {
	    $options(-command) $type $jid2
	}
    } else {
	Debug $err
    }
    
    # Notification using hooks since there may be more than one interested.
    ::hooks::run avatarNewPhotoHook $jid2
}

proc ::Avatar::SetPhotoFromCache {jid2} {
    variable photo
    variable options

    Debug "::Avatar::SetPhotoFromCache jid2=$jid2"
    
    set type put
    set mjid2 [jlib::jidmap $jid2]
    if {![info exists photo($mjid2,orig)]} {
	set photo($mjid2,orig) [image create photo]
	set type create
    }

    # Be silent!
    if {![catch {
	PutPhotoFromCache $jid2
    } err]} {
	if {$options(-command) ne ""} {
	    $options(-command) $type $jid2
	}
    } else {
	Debug $err
    }
    
    # Notification using hooks since there may be more than one interested.
    ::hooks::run avatarNewPhotoHook $jid2
}

# Avatar::PutPhotoFromCache --
# 
#       Assumes a blank photo is already created and creates all images
#       of interested sizes.
#       May throw error!

proc ::Avatar::PutPhotoFromCache {jid2} {
    variable photo
    
    Debug "::Avatar::PutPhotoFromCache jid2=$jid2"
    
    set hash [GetHash $jid2]
    if {$hash ne ""} {
	set fileName [GetCacheFileName $hash]
	if {[file exists $fileName]} {
	    set mjid2 [jlib::jidmap $jid2]
	    set orig $photo($mjid2,orig)
	    if {![catch {
		set tmp [image create photo -file $fileName]
	    }]} {
		$orig copy $tmp -compositingrule set -shrink
		image delete $tmp
	    }
	}
    }    
    
    # We must update all photos of all sizes for this jid.
    PutPhotoCreateSizes $jid2    
}

# Avatar::PutPhotoFromData --
# 
#       Assumes a blank photo is already created and creates all images
#       of interested sizes.
#       May throw error!

proc ::Avatar::PutPhotoFromData {jid2 data} {
    variable photo
    variable sizes
    
    # Write new image data on existing image.
    set mjid2 [jlib::jidmap $jid2]
    set orig $photo($mjid2,orig)
    $orig put $data
    
    # We must update all photos of all sizes for this jid.
    PutPhotoCreateSizes $jid2
}

# Avatar::PutPhotoCreateSizes --
# 
#       Creates all the scaled photos that are in use when putting a new
#       avatar.

proc ::Avatar::PutPhotoCreateSizes {jid2} {
    variable photo
    variable sizes
    
    set mjid2 [jlib::jidmap $jid2]
    set orig $photo($mjid2,orig)

    # We must update all photos of all sizes for this jid.
    foreach size $sizes {
	if {[info exists photo($mjid2,$size)]} {
	    set name $photo($mjid2,$size)
	    if {[image inuse $name]} {
		#set tmp [CreateScaledPhoto $orig $size]
		set tmp [::ui::image::scale $orig $size]
		$name copy $tmp -compositingrule set -shrink
		image delete $tmp
	    } else {
		
		# @@@ Not sure if this is smart.
		image delete $name
		unset -nocomplain photo($mjid2,$size)
	    }
	}
    }
}

# Avatar::PresenceHook --
# 
#       Available presence hook.
#       We may get presence without any hashes and need therefore clear the cache.

proc ::Avatar::PresenceHook {jid type args} {
    
    if {$type ne "available"} {
	return
    }
    set jid2 [jlib::barejid $jid]
    set hash [::Jabber::JlibCmd avatar get_hash $jid2]
    if {$hash eq ""} {
	
	# Clear any cached hash map we may have. Not the image though.
	FreeHashCache $jid2
    }
}

#--- Public Interfaces ---------------------------------------------------------
#
# The idea is that everything shall work transparently:
#  o cache or from 'avatar'
#  o photo rescaling
#  o etc.

# Avatar::GetPhoto --
# 
#       Gets the original photo, not rescaled.

proc ::Avatar::GetPhoto {jid2} {
    variable photo
    
    set mjid2 [jlib::jidmap $jid2]
    if {[info exists photo($mjid2,orig)]} {
	return $photo($mjid2,orig)
    } elseif {[HaveCachedJID $jid2]} {
	CreatePhotoFromCache $jid2
	if {[info exists photo($mjid2,orig)]} {
	    return $photo($mjid2,orig)
	} else {
	    return ""
	}
    } else {
	return ""
    }
}

# Avatar::GetPhotoOfSize --
# 
#       Return a photo with max size 'size'. 'size' must be one of the
#       supported sizes: 32, 48, or 64.
#       @@@ We may duplicate the original image if it happens to be of
#       the requested size.

proc ::Avatar::GetPhotoOfSize {jid2 size} {
    variable photo

    set mjid2 [jlib::jidmap $jid2]
    if {[info exists photo($mjid2,$size)]} {
	return $photo($mjid2,$size)
    } elseif {[info exists photo($mjid2,orig)]} {

	# Is not there, create!
	set name $photo($mjid2,orig)
	#set new [CreateScaledPhoto $name $size]
	set new [::ui::image::scale $name $size]
	set photo($mjid2,$size) $new
	return $new
    } elseif {[HaveCachedJID $jid2]} {
	CreatePhotoFromCache $jid2
	
	# If succesful; Note that only orig created.
	if {[info exists photo($mjid2,orig)]} {
	    set name $photo($mjid2,orig)
	    #set new [CreateScaledPhoto $name $size]
	    set new [::ui::image::scale $name $size]
	    set photo($mjid2,$size) $new
	    return $new
	}
    }
    return ""
}

# Avatar::HavePhoto --
# 
#       Return 1 if we have an avatar ready to use and 0 else.
#       For online users we don't get cache unless they have sent us a
#       nonempty presence hash.

proc ::Avatar::HavePhoto {jid2} {
    variable photo
    upvar ::Jabber::jstate jstate
    
    set jlib $jstate(jlib)    
    set mjid2 [jlib::jidmap $jid2]
    if {[$jlib avatar have_data $jid2] && [info exists photo($mjid2,orig)]} {
	return 1
    } else {
	if {[$jlib roster isavailable $jid2]} {
	    if {[$jlib avatar get_hash $jid2] ne ""} {
		return [HaveCachedJID $jid2]
	    } else {
		return 0
	    }
	} else {
	    return [HaveCachedJID $jid2]
	}
    }
}

#-------------------------------------------------------------------------------

proc ::Avatar::CreatePhotoFromCache {jid2} {
    variable photo

    set hash [GetHash $jid2]
    if {$hash ne ""} {
	set fileName [GetCacheFileName $hash]
	if {[file exists $fileName]} {
	    set mjid2 [jlib::jidmap $jid2]
	    catch {
		set photo($mjid2,orig) [image create photo -file $fileName]
	    }
	}
	# BU
	#set data [ReadCacheAvatar $hash]
	#set photo($mjid2,orig) [image create photo]
	#catch {
	#    PutPhotoFromData $jid2 $data
	#}
    }    
}

proc ::Avatar::FreePhotos {jid} {
    variable photo
    variable sizes
    
    set mjid [jlib::jidmap $jid]
    set images {}
    foreach size [concat orig $sizes] {
	if {[info exists photo($mjid,$size)]} {
	    lappend images $photo($mjid,$size)
	}
    }
    
    # The original image name is duplicated.
    if {[llength $images]} {
	eval {image delete} [lsort -unique $images]
    }
    array unset photo "[jlib::ESC $mjid],*"
}

proc ::Avatar::FreeAllPhotos { } {
    variable photo

    set images {}
    foreach {key image} [array get photo] {
	lappend images $image
    }
    if {[llength $images]} {
	eval {image delete} $images
    }
    unset -nocomplain photo
}

#--- Utilities -----------------------------------------------------------------

# OBSOLETE !!!   Moved to ui::util !!!

# These always scale down an image.

# Avatar::CreateScaledPhoto --
# 
#       If image with 'name' is smaller or equal 'size' then just return 
#       a copy of 'name', else create a new scaled one that is smaller or 
#       equal to 'size'.

proc ::Avatar::CreateScaledPhoto {name size} {
    
    set width  [image width $name]
    set height [image height $name]
    set max [expr {$width > $height ? $width : $height}]
    
    # We never scale up an image, only scale down.
    if {$size >= $max} {
	set new [image create photo]
	$new copy $name
	return $new
    } else {
	lassign [GetScaleMN $max $size] M N
	return [ScalePhotoM->N $name $M $N]
    }
}

proc ::Avatar::ScalePhotoM->N {name M N} {
    
    set new [image create photo]
    if {$N == 1} {
	$new copy $name -subsample $M
    } else {
	set tmp [image create photo]
	$tmp copy $name -zoom $M
	$new copy $tmp -subsample $N
	image delete $tmp
    }
    return $new
}

# Avatar::GetScaleMN --
# 
#       Get scale rational number that scales from 'from' pixels to smaller or 
#       equal to 'to' pixels.

proc ::Avatar::GetScaleMN {from to} {
    variable scaleTable

    if {![info exists scaleTable]} {
	MakeScaleTable
    }
    
    # If requires smaller scale factor than min (1/8):
    set M [lindex $scaleTable {end 0}]
    set N [lindex $scaleTable {end 1}]
    if {[expr {$M*$from > $N*$to}]} {
	set M 1
	set N [expr {int(double($from)/double($to) + 1)}]
    } elseif {$from == $to} {
	set M 1
	set N 1
    } else {
	foreach r $scaleTable {
	    set N [lindex $r 0]
	    set M [lindex $r 1]
	    if {[expr {$N*$from <= $M*$to}]} {
		break
	    }
	}
    }
    return [list $N $M]
}

proc ::Avatar::MakeScaleTable { } {
    variable scaleTable
    
    # {{numerator denominator} ...}
    set r \
      {{1 2} {1 3} {1 4} {1 5} {1 6} {1 7} {1 8}
             {2 3}       {2 5}       {2 7}
	           {3 4} {3 5}       {3 7} {3 8}
		         {4 5}       {4 7}  
			       {5 6} {5 7} {5 8}
			             {6 7}
				           {7 8}}

    # Sort in decreasing order!
    set scaleTable [lsort -decreasing -command ::Avatar::MakeScaleTableCmd $r]
}

proc ::Avatar::MakeScaleTableCmd {f1 f2} {
    
    set r1 [expr {double([lindex $f1 0])/double([lindex $f1 1])}]
    set r2 [expr {double([lindex $f2 0])/double([lindex $f2 1])}]
    return [expr {$r1 > $r2 ? 1 : -1}]
}

#--- Other Utilities -----------------------------------------------------------

proc ::Avatar::GetHashForFile {fileName} {

    set fd [open $fileName r]
    fconfigure $fd -translation binary
    set hash [::sha1::sha1 [read $fd]]
    close $fd
    return $hash
}

#--- Avatar File Cache ---------------------------------------------------------

# A few functions for handling the avatar file cache:
#   o files stored as hash.png etc.
#   o binary content, not base64 encoded

proc ::Avatar::HaveCachedJID {jid2} {

    Debug "::Avatar::HaveCachedJID jid2=$jid2"
    
    set hash [GetHash $jid2]
    if {$hash ne ""} {
	set fileName [GetCacheFileName $hash]
	if {$fileName ne ""} {
	    return 1
	}
    }
    return 0
}

# Avatar::MakeCacheFileName --
# 
#       Gets the file name which may not exist.

proc ::Avatar::MakeCacheFileName {hash mime} {
    variable options

    set base [file join $options(-cachedir) [string trim $hash]]
    return ${base}[GetSuffForMime $mime]
}

# Avatar::GetCacheFileName --
# 
#       Gets a file and returns empty if not exists.

proc ::Avatar::GetCacheFileName {hash} {
    variable options
    variable suff2Mime

    # Search for the recognized image mime types.
    set base [file join $options(-cachedir) [string trim $hash]]
    foreach {suff mime} [array get suff2Mime] {
	if {[file exists $base$suff]} {
	    return $base$suff
	}
    }
    return ""
}

proc ::Avatar::HaveCachedHash {hash} {    
    return [expr {[GetCacheFileName $hash] eq "" ? 0 : 1}]
}

# Avatar::ReadCacheAvatar --
# 
#       Reads a cache file and returns its content; empty if not exists.

proc ::Avatar::ReadCacheAvatar {hash} {

    Debug "::Avatar::ReadCacheAvatar"
    
    set fileName [GetCacheFileName $hash]
    if {[file exists $fileName]} {
	set fd [open $fileName r]
	fconfigure $fd -translation binary
	set data [::base64::encode [read $fd]]
	close $fd
    } else {
	set data ""
    }
    return $data
}

# Avatar::WriteCacheAvatar --
# 
#       Writes the image to file with associated name.

proc ::Avatar::WriteCacheAvatar {mime hash photo} {

    set fileName [MakeCacheFileName $hash $mime]
    set fd [open $fileName w]
    fconfigure $fd -translation binary
    puts -nonewline $fd [::base64::decode $photo]
    close $fd
}

proc ::Avatar::GetCacheAvatarMime {hash} {

    set fileName [GetCacheFileName $hash]
    if {$fileName ne ""} {
	return [GetMimeForFile $fileName]
    } else {
	return ""
    }
}

proc ::Avatar::GetMimeForFile {fileName} {
    variable suff2Mime

    set suff [string tolower [file extension $fileName]]
    if {[info exists suff2Mime($suff)]} {
	return $suff2Mime($suff)
    } else {
	return ""
    }
}

proc ::Avatar::GetSuffForMime {mime} {
    variable mime2Suff
    
    if {[info exists mime2Suff($mime)]} {
	return $mime2Suff($mime)
    } else {
	return ""
    }
}

# Avatar::GetHash --
# 
#       Tries to get hash first from 'avatar' then from hashmap.

proc ::Avatar::GetHash {jid2} {
    variable hashmap
    upvar ::Jabber::jstate jstate
    
    # Get the most current if it exists.
    set jlib $jstate(jlib)    
    set mjid2 [jlib::jidmap $jid2]
    set hash [$jlib avatar get_hash $jid2]

    # Use the hashmap as a fallback.
    if {($hash eq "") && [info exists hashmap($mjid2)]} {
	set hash $hashmap($mjid2)
    }
    return $hash
}

proc ::Avatar::FreeHashCache {jid2} {
    variable hashmap

    set mjid2 [jlib::jidmap $jid2]
    unset -nocomplain hashmap($mjid2)    
}

# Avatar::WriteHashmap --
# 
#       Writes an array to file that maps jid2 to hash.
#       Just source this file to read it.

proc ::Avatar::WriteHashmap {fileName} {
    variable hashmap
    upvar ::Jabber::jstate jstate
    
    Debug "::Avatar::WriteHashmap"
    
    # @@@ Bad workaround for p2p.
    if {![info exists jstate(jlib)]} {
	return
    }
    
    # Start from the hashmap that may have been read earlier and update it.
    set jlib $jstate(jlib)
    foreach jid2 [$jlib avatar get_all_avatar_jids] {
	set mjid2 [jlib::jidmap $jid2]
	set hash [$jlib avatar get_hash $jid2]
	set hashmap($mjid2) $hash
    }
    
    set fd [open $fileName w]
    puts $fd "# This file defines an array that maps jid2 -> avatar hash"
    puts $fd "array set hashmap {"
    foreach {mjid2 hash} [array get hashmap] {
	if {$hash ne ""} {
	    puts $fd "\t$mjid2 \t$hash"
	}
    }
    puts $fd "}"
    close $fd
}

proc ::Avatar::ReadHashmap {fileName} {
    variable hashmap
    
    Debug "::Avatar::ReadHashmap"
    
    if {[file exists $fileName]} {
	source $fileName
	
	# Files may have been deleted. Cleanup hashmap.
	foreach {mjid2 hash} [array get hashmap] {
	    if {[GetCacheFileName $hash] eq ""} {
		unset hashmap($mjid2)
	    }
	}
    }
}

#-------------------------------------------------------------------------------

# Avatar::Widget --
# 
#       Display only avatar widget. Allows any size avatar.

proc ::Avatar::Widget {w} {
    
    # @@@ An alternative is to have a blank image as a spacer.
    frame $w
    
    # Bug in 8.4.1 but ok in 8.4.9
    if {[regexp {^8\.4\.[0-5]$} [info patchlevel]]} {
	label $w.l -relief sunken -bd 1 -bg white
    } else {
	ttk::label $w.l -style Sunken.TLabel -compound image
    }
    grid  $w.l  -sticky news
    grid columnconfigure $w 0 -minsize [expr {2*4 + 2*4 + 64}]
    grid rowconfigure    $w 0 -minsize [expr {2*4 + 2*4 + 64}]
     
    return $w
}

proc ::Avatar::WidgetSetPhoto {w image {size 64}} {
    
    if {$image ne ""} {
	set W [image width $image]
	set H [image height $image]
	set max [expr {$W > $H ? $W : $H}]
	if {$max > $size} {
	    lassign [GetScaleMN $max $size] M N	
	    set display [ScalePhotoM->N $image $M $N]
	    bind $w <Destroy> +[list image delete $display]
	} else {
	    set display $image
	}
	$w.l configure -image $display
    } else {
	$w.l configure -image ""
    }
    if {$image ne "" && $max > $size} {
	bind $w <Enter> [list [namespace code WidgetBalloon] 1 $w $image]
	bind $w <Leave> [list [namespace code WidgetBalloon] 0 $w $image]
    } else {
	bind $w <Enter> {}
	bind $w <Leave> {}
    }
}

proc ::Avatar::WidgetBalloon {show w image} {
    
    set win $w.ball
    if {![winfo exists $win]} {
	toplevel $win -bd 0 -relief flat
	wm overrideredirect $win 1
	wm transient $win
	wm withdraw  $win
	wm resizable $win 0 0 
	
	if {[tk windowingsystem] eq "aqua"} {
	    tk::unsupported::MacWindowStyle style $win help none
	}
	pack [label $win.l -bd 0 -bg white -compound none -image $image]
    }
    if {$show} {
	set x [expr {[winfo rootx $w] + 10}]
	set y [expr {[winfo rooty $w] + [winfo height $w]}]
	wm geometry $win +${x}+${y}
	wm deiconify $win
    } else {
	wm withdraw $win
    }
}

proc ::Avatar::Debug {text} {
    if {0} {
	puts "\t $text"
    }
}



