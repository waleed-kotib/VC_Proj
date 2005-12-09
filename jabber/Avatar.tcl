#  Avatar.tcl --
#  
#       This is part of The Coccinella application.
#       It provides an application interface to the jlib avatar package.
#       
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: Avatar.tcl,v 1.2 2005-12-09 13:24:21 matben Exp $

package require jlib::avatar

package provide Avatar 1.0

namespace eval ::Avatar:: {
    
    ::hooks::register jabberInitHook ::Avatar::InitHook
    
    # Array 'photo' contains our internal sorage for all images.
    variable photo
}

proc ::Avatar::InitHook {jlibname} {
    

    $jlibname avatar configure -command ::Avatar::UpdateHash
}

proc ::Avatar::Load {fileName} {
    upvar ::Jabber::jstate jstate

    set mime [::Types::GetMimeTypeForFileName $fileName]
    
    switch -- $mime {
	image/gif - image/png {
	    # ok
	}
	default {
	    set msg "Our avatar shall be either a PNG or a GIF file."
	    ::UI::MessageBox -message $msg -icon error
	    return
	}
    }
    
    # Store the avatar file in prefs folder to protect it from being removed.
    
    
    
    set fd [open $fileName]
    fconfigure $fd -translation binary
    set data [read $fd]
    close $fd

    set jlib $jstate(jlib)
    $jlib avatar set_data $data $mime

    # If we configure while online need to update our presence info and
    # store the data with the server.
    if {[$jlib isinstream]} {
	$jlib send_presence -keep 1
	$jlib avatar store ::Avatar::Callback
    }
}

# Avatar::Remove --
# 
#       Remove our avatar for public usage.

proc ::Avatar::Remove { } {
    upvar ::Jabber::jstate jstate
    
    set jlib $jstate(jlib)
    $jlib avatar unset_data
    
    if {[$jlib isinstream]} {
	set xElem [wrapper::createtag x  \
	  -attrlist [list xmlns "jabber:x:avatar"]]
	$jlib send_presence -xlist [list $xElem] -keep 1
	$jlib avatar store_remove ::Avatar::Callback
    }    
}

proc ::Avatar::Callback {jlibname type queryElem} {
    
    if {$type eq "error"} {
	::Jabber::AddErrorLog {} $queryElem
    }
}

proc ::Avatar::UpdateHash {jid} {
    upvar ::Jabber::jstate jstate
    
    set jlib $jstate(jlib)
    
    
    
}


