#  Avatar.tcl --
#  
#       This is part of The Coccinella application.
#       It provides an application interface to the jlib avatar package.
#       While the 'avatar' package handles the actual image data, this package
#       keeps an image in sync with avatar image data.
#       
#  Copyright (c) 2005-2006  Mats Bengtsson
#  
# $Id: Avatar.tcl,v 1.18 2006-05-28 15:30:30 matben Exp $

# @@@ Issues:
# 
# Features:
#       1) We don't request avatar for offline users, only if already cached.

package require jlib::avatar

package provide Avatar 1.0

namespace eval ::Avatar:: {
    
    ::hooks::register  initHook        ::Avatar::InitHook
    ::hooks::register  prefsInitHook   ::Avatar::InitPrefsHook
    ::hooks::register  jabberInitHook  ::Avatar::JabberInitHook
    ::hooks::register  loginHook       ::Avatar::LoginHook
    ::hooks::register  logoutHook      ::Avatar::LogoutHook
    ::hooks::register   quitAppHook    ::Avatar::QuitHook
        
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
    variable aprefs
    
    Debug "::Avatar::InitHook"
    
    set fileName [GetMyAvatarFile]
    if {[file isfile $fileName]} {
	set aprefs(fileName) $fileName
	if {[CreateAndVerifyPhoto $fileName name]} {
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

proc ::Avatar::Load {fileName} {
    
    Debug "::Avatar::Load"
    
    if {[CreateAndVerifyPhoto $fileName name]} {
	SetMyPhoto $name
	SaveFile $fileName
	ShareImage $fileName
    }
}

proc ::Avatar::SetMyAvatarFromBase64 {data mime} {
    
    Debug "::Avatar::SetMyAvatarFromBase64"
    
    if {![catch {image create photo -data $data} tmpname]} {
	SetMyPhoto $tmpname
	WriteBase64ToFile $data $mime
	image delete $tmpname
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
    
    set mime [::Types::GetMimeTypeForFileName $fileName]
    if {[lsearch {image/gif image/png} $mime] < 0} {
	set msg "Our avatar shall be either a PNG or a GIF file."
	return [list 0 $msg]
    }
	
    # Make sure it is an image.
    if {[catch {set tmp [image create photo -file $fileName]}]} {
	set msg "Failed to create an image from [file tail $fileName]"
	return [list 0 $msg]
    }
    
    # For the time being we limit sizes to 32, 48, or 64.
    set width  [image width $tmp]
    set height [image height $tmp]
    if {($width != $height) || ([lsearch $sizes $width] < 0)} {
	set msg "We require that the avatar be square of size [join $sizes {, }]"
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
    
    if {![info exists myphoto(image)]} {
	set myphoto(image) [image create photo]
    }
    $myphoto(image) blank
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

proc ::Avatar::UnshareImage { } {
    upvar ::Jabber::jstate jstate
    
    Debug "::Avatar::UnshareImage"
    
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
    
    jlib::splitjid $jid jid2 -
    set jlib $jstate(jlib)
    set hash [$jlib avatar get_hash $jid2]
    if {$hash eq ""} {
	if {$options(-command) ne ""} {
	    $options(-command) remove $jid2
	}
	FreePhotos $jid
    } else {

	# Try first to get the Avatar from Cache.
	set data [ReadCacheAvatar $hash]
	if {$data ne ""} {
	    SetPhoto $jid2 $data
	} elseif {$options(-autoget)} {
	    GetPrioAvatar $jid
	}
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
	    
	    SetPhoto $jid2 $data
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
	    
	    SetPhoto $jid2 $data
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
	set data [ReadCacheAvatar $hash]
	if { $data ne "" } {
	    SetPhoto $jid2 $data
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
    
    set jlib   $jstate(jlib)
    set roster $jstate(roster)

    # @@@ Not sure here...
    foreach jid2 [$roster getusers] {
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

# Avatar::SetPhoto --
# 
#       Create new photo if not exists and updates the image with the data.
#       Any -command is invoked notifying the event.
#       
#       photo(jid,orig) is always the original photo. The size can change if
#                       user updates the avatar with a different size.
#       photo(jid,32)   are photos with respective max size.
#       photo(jid,48)
#       photo(jid,64)   

proc ::Avatar::SetPhoto {jid2 data} {
    variable photo
    variable options

    Debug "::Avatar::SetPhoto jid2=$jid2"
    
    set type put
    if {![info exists photo($jid2,orig)]} {
	set photo($jid2,orig) [image create photo]
	set type create
    }
    
    # Be silent!
    if {![catch {
	PutPhoto $jid2 $data
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

# Avatar::PutPhoto --
# 
#       Assumes a blank photo is already created and creates all images
#       of interested sizes.

proc ::Avatar::PutPhoto {jid2 data} {
    variable photo
    variable sizes
    
    set orig $photo($jid2,orig)
    $orig put $data
    
    # We must update all photos of all sizes for this jid.
    foreach size $sizes {
	if {[info exists photo($jid2,$size)]} {
	    set name $photo($jid2,$size)
	    if {[image inuse $name]} {
		set tmp [CreateScaledPhoto $orig $size]
		$name copy $tmp
		image delete $tmp
	    } else {
		
		# @@@ Not sure if this is smart.
		image delete $name
		unset photo($jid2,$size)
	    }
	}
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
    
    if {[info exists photo($jid2,orig)]} {
	return $photo($jid2,orig)
    } elseif {[HaveCachedJID $jid2]} {
	CreatePhotoFromCache $jid2
	return $photo($jid2,orig)
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

    if {[info exists photo($jid2,$size)]} {
	return $photo($jid2,$size)
    } elseif {[info exists photo($jid2,orig)]} {

	# Is not there, create!
	set name $photo($jid2,orig)
	set new [CreateScaledPhoto $name $size]
	set photo($jid2,$size) $new
	return $new
    } elseif {[HaveCachedJID $jid2]} {
	CreatePhotoFromCache $jid2
	
	# If succesful; Note that only orig created.
	if {[info exists photo($jid2,orig)]} {
	    set name $photo($jid2,orig)
	    set new [CreateScaledPhoto $name $size]
	    set photo($jid2,$size) $new
	    return $new
	}
    }
    return ""
}

proc ::Avatar::HavePhoto {jid2} {
    variable photo
    upvar ::Jabber::jstate jstate
	
    set jlib $jstate(jlib)    
    if {[$jlib avatar have_data $jid2] && [info exists photo($jid2,orig)]} {
	return 1
    } else {
	return [HaveCachedJID $jid2]
    }
}

#-------------------------------------------------------------------------------

proc ::Avatar::CreatePhotoFromCache {jid2} {
    variable photo
    
    set hash [GetHash $jid2]
    if {$hash ne ""} {
	set data [ReadCacheAvatar $hash]
	set photo($jid2,orig) [image create photo]
	catch {
	    PutPhoto $jid2 $data
	}
    }    
}

proc ::Avatar::FreePhotos {jid} {
    variable photo
    variable sizes
    
    set images {}
    foreach size [concat orig $sizes] {
	if {[info exists photo($jid,$size)]} {
	    lappend images $photo($jid,$size)
	}
    }
    
    # The original image name is duplicated.
    if {[llength $images]} {
	eval {image delete} [lsort -unique $images]
    }
    array unset photo "[jlib::ESC $jid],*"
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

# These always scale down an image.

# Avatar::CreateScaledPhoto --
# 
#       If image with 'name' is smaller or equal 'size' then just return 'name',
#       else create a new scaled one that is smaller or equal to 'size'.

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
	return [ScalePhotoN->M $name $N $M]
    }
}

proc ::Avatar::ScalePhotoN->M {name N M} {
    
    set new [image create photo]
    if {$M == 1} {
	$new copy $name -subsample $N
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
    set hash [$jlib avatar get_hash $jid2]

    # Use the hashmap as a fallback.
    if {($hash eq "") && [info exists hashmap($jid2)]} {
	set hash $hashmap($jid2)
    }
    return $hash
}

# Avatar::WriteHashmap --
# 
#       Writes an array to file that maps jid2 to hash.
#       Just source this file to read it.

proc ::Avatar::WriteHashmap {fileName} {
    variable hashmap
    upvar ::Jabber::jstate jstate
    
    Debug "::Avatar::WriteHashmap"
    
    # Start from the hashmap that may have been read earlier and update it.
    set jlib $jstate(jlib)
    foreach jid2 [$jlib avatar get_all_avatar_jids] {
	set hash [$jlib avatar get_hash $jid2]
	set hashmap($jid2) $hash
    }
    
    set fd [open $fileName w]
    puts $fd "# This file defines an array that maps jid2 -> avatar hash"
    puts $fd "array set hashmap {"
    foreach {jid2 hash} [array get hashmap] {
	if {$hash ne ""} {
	    puts $fd "\t$jid2 \t$hash"
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
	foreach {jid2 hash} [array get hashmap] {
	    if {[GetCacheFileName $hash] eq ""} {
		unset hashmap($jid2)
	    }
	}
    }
}

#--- Preference UI -------------------------------------------------------------

proc ::Avatar::PrefsFrame {win} {
    variable aprefs
    variable tmpprefs
    #variable tmpphoto
    variable wphoto
    variable wshare
    variable haveDND
    
    Debug "::Avatar::PrefsFrame"
    
    if {![info exists haveDND]} {
	set haveDND 0
	if {![catch {package require tkdnd}]} {
	    set haveDND 1
	}
    }

    set tmpprefs(share) $aprefs(share)
    set tmpprefs(fileName) [GetMyAvatarFile]
    set tmpprefs(editedPhoto) 0
    
    ttk::frame $win
    ttk::label $win.title -text [mc {My Avatar}]
    ttk::separator $win.sep -orient horizontal
    ttk::checkbutton $win.share -text [mc prefavashare]  \
      -variable [namespace current]::tmpprefs(share)
    
    set wfr $win.fr
    ttk::frame $win.fr
    
    set wava $wfr.ava
    frame $wava
    # Bug in 8.4.1 but ok in 8.4.9
    if {[regexp {^8\.4\.[0-5]$} [info patchlevel]]} {
	label $wava.l -relief sunken -bd 1 -bg white
    } else {
	ttk::label $wava.l -style Sunken.TLabel -compound image
    }
    
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

    if {$haveDND} {
	PrefsInitDnD $wava
    }       

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
    set fileName [tk_getOpenFile -title [mc {Pick Image File}]  \
      -filetypes $types]
    if {$fileName ne ""} {
	if {[CreateAndVerifyPhoto $fileName me]} {
	    $wphoto configure -image $me
	    if {![info exists tmpphoto]} {
		set tmpphoto [image create photo]
	    }
	    $tmpphoto blank
	    $tmpphoto copy $me -compositingrule set
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

proc ::Avatar::PrefsInitDnD {win} {
    
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
	set act $action
    }
    return $act
}

proc ::Avatar::PrefsDnDLeave {w data type} {
    
    # empty
}

proc ::Avatar::Debug {text} {
    if {0} {
	puts "\t $text"
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


