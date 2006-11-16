#  avatar.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for avatars (JEP-0008: IQ-Based Avatars)
#      and vCard based avatars as JEP-0153.
#      Note that this JEP is "historical" only but is easy to adapt to
#      a future pub-sub method.
#      
#  Copyright (c) 2005-2006  Mats Bengtsson
#  Copyright (c) 2006 Antonio Cano Damas
#  
# $Id: avatar.tcl,v 1.21 2006-11-16 14:28:55 matben Exp $
# 
############################# USAGE ############################################
#
#   NAME
#      avatar - convenience command library for avatars.
#      
#   SYNOPSIS
#      jlib::avatar::init jlibname
#
#   OPTIONS
#      -announce   0|1
#      -share      0|1
#      -command    tclProc
#      -cache      0|1
#	
#   INSTANCE COMMANDS
#      jlibName avatar configure ?-key value...?
#      jlibName avatar set_data data mime
#      jlibName avatar unset_data
#      jlibName avatar store command
#      jlibName avatar store_remove command
#      jlibName avatar get_async jid command
#      jlibName avatar send_get jid command
#      jlibName avatar send_get_storage jid command
#      jlibName avatar get_data jid2
#      jlibName avatar get_hash jid2
#      jlibName avatar get_mime jid2
#      jlibName avatar have_data jid2
#      jlibName avatar have_hash jid2
#      
#   Note that all internal storage refers to bare (2-tier) jids!
#   @@@ It is unclear if this is correct. Perhaps the full jids shall be used.
#   The problem is with JEP-0008 mixing jid2 with jid3.  
#   Note that all vCards are defined per jid2, bare JID.
#   
#   No automatic presence or server storage is made when reconfiguring or
#   changing own avatar. This is up to the client layer to do.
#   It is callback based which means that the -command is only invoked when
#   getting hashes and not else.
#      
################################################################################

package require base64     ; # tcllib
package require sha1       ; # tcllib                           
package require jlib
package require jlib::disco
package require jlib::vcard

package provide jlib::avatar 0.1

namespace eval jlib::avatar {
    variable inited 0
    variable xmlns
    set xmlns(x-avatar)   "jabber:x:avatar"
    set xmlns(iq-avatar)  "jabber:iq:avatar"
    set xmlns(storage)    "storage:client:avatar"
    set xmlns(vcard-temp) "vcard-temp:x:update"

    jlib::ensamble_register avatar \
      [namespace current]::init    \
      [namespace current]::cmdproc
        
    jlib::disco::registerfeature $xmlns(iq-avatar)
    
    # Note: jlib::ensamble_register is last in this file!
}

proc jlib::avatar::init {jlibname args} {

    variable xmlns
    
    # Instance specific arrays:
    #   avatar stores our own avatar
    #   state stores other avatars
    namespace eval ${jlibname}::avatar {
	variable avatar
	variable state
	variable options
    }
    upvar ${jlibname}::avatar::avatar  avatar
    upvar ${jlibname}::avatar::state   state
    upvar ${jlibname}::avatar::options options

    array set options {
	-announce   0
	-share      0
	-cache      1
	-command    ""
    }
    eval {configure $jlibname} $args
    
    # Register some standard iq handlers that are handled internally.
    $jlibname iq_register get $xmlns(iq-avatar) [namespace current]::iq_handler
    $jlibname presence_register_int available   \
      [namespace current]::presence_handler
    
    $jlibname register_reset [namespace current]::reset

    return
}

proc jlib::avatar::reset {jlibname} {
    upvar ${jlibname}::avatar::state state
    upvar ${jlibname}::avatar::options options

    # Do not unset our own avatar.
    if {!$options(-cache)} {
	unset -nocomplain state
    }
}

# jlib::avatar::cmdproc --
#
#       Just dispatches the command to the right procedure.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       cmd:        
#       args:       all args to the cmd procedure.
#       
# Results:
#       none.

proc jlib::avatar::cmdproc {jlibname cmd args} {
    
    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

proc jlib::avatar::configure {jlibname args} {
    
    upvar ${jlibname}::avatar::options options
    
    set opts [lsort [array names options -*]]
    set usage [join $opts ", "]
    if {[llength $args] == 0} {
	set result {}
	foreach name $opts {
	    lappend result $name $options($name)
	}
	return $result
    }
    regsub -all -- - $opts {} opts
    set pat ^-([join $opts |])$
    if {[llength $args] == 1} {
	set flag [lindex $args 0]
	if {[regexp -- $pat $flag]} {
	    return $options($flag)
	} else {
	    return -code error "Unknown option $flag, must be: $usage"
	}
    } else {
	array set oldopts [array get options]
	foreach {flag value} $args {
	    if {[regexp -- $pat $flag]} {
		set options($flag) $value		
	    } else {
		return -code error "Unknown option $flag, must be: $usage"
	    }
	}
	if {$options(-announce) != $oldopts(-announce)} {
	    if {$options(-announce)} {
		# @@@ ???
	    } else {
		$jlibname deregister_presence_stanza x $xmlns(x-avatar)
                $jlibname deregister_presence_stanza x $xmlns(vcard-temp)
	    }
	}
    }
}

#+++ Two sections: First part deals with our own avatar ------------------------

# jlib::avatar::set_data --
# 
#       Sets our own avatar data and shares it by default.
#       Registers new hashes but does not send updated presence.
#       You have to send presence yourself.
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#       data:       raw binary image data.
#       mime:       the mime type: image/gif or image/png
#       
# Results:
#       none.

proc jlib::avatar::set_data {jlibname data mime} {
    variable xmlns
    upvar ${jlibname}::avatar::avatar  avatar
    upvar ${jlibname}::avatar::options options

    set options(-announce) 1
    set options(-share)    1
    
    if {[info exists avatar(hash)]} {
	set oldHash $avatar(hash)
    } else {
	set oldHash ""
    }
    set avatar(data)   $data
    set avatar(mime)   $mime
    set avatar(hash)   [::sha1::sha1 $data]
    set avatar(base64) [::base64::encode $data]
    
    set hashElem [wrapper::createtag hash -chdata $avatar(hash)]
    set xElem [wrapper::createtag x           \
      -attrlist [list xmlns $xmlns(x-avatar)] \
      -subtags [list $hashElem]]

    $jlibname deregister_presence_stanza x $xmlns(x-avatar)
    $jlibname register_presence_stanza $xElem -type available

    #-- vCard-temp presence stanza --
    set photoElem [wrapper::createtag photo -chdata $avatar(hash)]
    set xVCardElem [wrapper::createtag x         \
      -attrlist [list xmlns $xmlns(vcard-temp)]  \
      -subtags [list $photoElem]]

    $jlibname deregister_presence_stanza x $xmlns(vcard-temp)
    $jlibname register_presence_stanza $xVCardElem -type available

    return
}

proc jlib::avatar::get_my_data {jlibname what} {
    upvar ${jlibname}::avatar::avatar avatar
    
    return $avatar($what)
}

# jlib::avatar::unset_data --
# 
#       Unsets our avatar and does not share it anymore.
#       You have to send presence yourself with empty hashes.

proc jlib::avatar::unset_data {jlibname} {
    variable xmlns
    upvar ${jlibname}::avatar::avatar  avatar
    upvar ${jlibname}::avatar::options options
    
    unset -nocomplain avatar
    set options(-announce) 0
    set options(-share)    0
    
    $jlibname deregister_presence_stanza x $xmlns(x-avatar)
    $jlibname deregister_presence_stanza x $xmlns(vcard-temp)

    return
}

# jlib::avatar::store --
# 
#       Stores our avatar at the server.
#       Must store as bare jid.

proc jlib::avatar::store {jlibname cmd} {
    variable xmlns
    upvar ${jlibname}::avatar::avatar avatar
    
    if {![array exists avatar]} {
	return -code error "no avatar set"
    }
    set dataElem [wrapper::createtag data        \
      -attrlist [list mimetype $avatar(mime)] \
      -chdata $avatar(base64)]

    set jid2 [$jlibname getthis myjid2]
    $jlibname iq_set $xmlns(storage)  \
      -to $jid2 -command $cmd -sublists [list $dataElem]
}

proc jlib::avatar::store_remove {jlibname cmd} {
    variable xmlns
    
    set jid2 [$jlibname getthis myjid2]
    $jlibname iq_set $xmlns(storage)  \
      -to $jid2 -command $cmd   
}

# jlib::avatar::iq_handler --
# 
#       Handles incoming iq requests for our avatar.

proc jlib::avatar::iq_handler {jlibname from queryElem args} {
    variable xmlns
    upvar ${jlibname}::avatar::options options
    upvar ${jlibname}::avatar::avatar  avatar

    array set argsArr $args
    if {[info exists argsArr(-xmldata)]} {
	set xmldata $argsArr(-xmldata)
	set from [wrapper::getattribute $xmldata from]
	set id   [wrapper::getattribute $xmldata id]
    } else {
	return 0
    }
    
    if {$options(-share)} {
	set dataElem [wrapper::createtag data    \
	  -attrlist [list mimetype $avatar(mime)] \
	  -chdata $avatar(base64)]
	set qElem [wrapper::createtag query  \
	  -attrlist [list xmlns $xmlns(iq-avatar)]  \
	  -subtags [list $dataElem]]
	$jlibname send_iq result [list $qElem] -to $from -id $id
	return 1
    } else {
	$jlibname send_iq_error $from $id 404 cancel service-unavailable
	return 1
    }
}

#+++ Second part deals with getting other avatars ------------------------------

proc jlib::avatar::get_data {jlibname jid2} {
    upvar ${jlibname}::avatar::state state
    
    if {[info exists state($jid2,data)]} {
	return $state($jid2,data)
    } else {
	return ""
    }
}

proc jlib::avatar::get_mime {jlibname jid2} {
    upvar ${jlibname}::avatar::state state
    
    if {[info exists state($jid2,mime)]} {
	return $state($jid2,mime)
    } else {
	return ""
    }
}

proc jlib::avatar::have_data {jlibname jid2} {
    upvar ${jlibname}::avatar::state state
    
    if {[info exists state($jid2,data)]} {
	return 1
    } else {
	return 0
    }
}

proc jlib::avatar::get_hash {jlibname jid2} {
    upvar ${jlibname}::avatar::state state
    
    if {[info exists state($jid2,hash)]} {
	return $state($jid2,hash)
    } else {
	return ""
    }
}

proc jlib::avatar::have_hash {jlibname jid2} {
    upvar ${jlibname}::avatar::state state
    
    return [info exists state($jid2,hash)]
}

proc jlib::avatar::have_hash_protocol {jlibname jid2 protocol} {
    upvar ${jlibname}::avatar::state state
    
    if {[info exists state($jid2,protocol,$protocol)]} {
	return 1
    } else {
	return 0
    }
}

proc jlib::avatar::get_protocols {jlibname jid2} {
    upvar ${jlibname}::avatar::state state
    
    set protocols {}
    foreach p {avatar vcard} {
	if {[info exists state($jid2,protocol,$p)]} {
	    lappend protocols $p
	}
    }
    return $protocols
}

# jlib::avatar::get_full_jid --
# 
#       This is the jid3 associated with 'avatar' or jid2 if 'vcard',
#       else we just return the jid2.

proc jlib::avatar::get_full_jid {jlibname jid2} {
    upvar ${jlibname}::avatar::state state

    if {[info exists state($jid2,jid3)]} {
	return $state($jid2,jid3)
    } else {
	return $jid2
    }
}

# jlib::avatar::get_all_avatar_jids --
# 
#       Gets a list of all jids with avatar support.
#       Actually, everyone that has sent us a presence jabber:x:avatar element.

proc jlib::avatar::get_all_avatar_jids {jlibname} {
    upvar ${jlibname}::avatar::state state
    
    debug "jlib::avatar::get_all_avatar_jids"
    
    set jids {}
    set len [string length ",hash"]
    foreach {key hash} [array get state *,hash] {
	if {$hash ne ""} {
	    set jid2 [string range $key 0 end-$len]
	    lappend jids $jid2
	}
    }
    return $jids
}

proc jlib::avatar::uptodate {jlibname jid2} {
    upvar ${jlibname}::avatar::state state

    if {[info exists state($jid2,uptodate)]} {
	return $state($jid2,uptodate)
    } else {
	return 0
    }
}

# jlib::avatar::presence_handler --
# 
#       We must handle both 'avatar' and 'vcard' from one place
#       since we don't want separate callbacks if both are supplied.
#       It is assumed that hash from any are identical.

proc jlib::avatar::presence_handler {jlibname xmldata} {
    upvar ${jlibname}::avatar::options options
    upvar ${jlibname}::avatar::state   state

    set from [wrapper::getattribute $xmldata from]
    set mjid [jlib::jidmap $from]
    set jid2 [jlib::barejid $mjid]

    if {[info exists state($jid2,hash)]} {
	set new 0
	set oldhash $state($jid2,hash)
    } else {
	set new 1
    }
    set gotAvaHash [PresenceAvatar $jlibname $xmldata]
    set gotVcardHash [PresenceVCard $jlibname $xmldata]
    
    #puts "\t jid2=$jid2"
    #puts "\t gotAvaHash=$gotAvaHash"
    #puts "\t gotVcardHash=$gotVcardHash"
        
    if {($gotAvaHash || $gotVcardHash)} {
    
	# 'uptodate' tells us if we need to request new avatar.
	# If new, or not identical to previous, unless empty.
	if {$new || ($state($jid2,hash) ne $oldhash)} {
	    set hash $state($jid2,hash)
	    
	    # hash can be empty.
	    if {$hash eq ""} {
		set state($jid2,uptodate) 1
		unset -nocomplain state($jid2,data)
	    } else {
		set state($jid2,uptodate) 0
	    }
	    if {[string length $options(-command)]} {
		uplevel #0 $options(-command) [list $from]
	    }
	}
    } else {
	
	# Must be sure that nothing there.
	if {[info exists state($jid2,hash)]} {
	    array unset state [jlib::ESC $jid2],*
	}
    }
}

# jlib::avatar::PresenceAvatar --
# 
#       Caches incoming <x xmlns='jabber:x:avatar'> presence elements.
#       "To disable the avatar, the avatar-generating user's client will send 
#        a presence packet with the jabber:x:avatar namespace but with no hash 
#        information"

proc jlib::avatar::PresenceAvatar {jlibname xmldata} {
    variable xmlns
    upvar ${jlibname}::avatar::state   state
    
    set gotHash 0
    set elems [wrapper::getchildswithtagandxmlns $xmldata x $xmlns(x-avatar)]
    if {[llength $elems]} {
	set hashElem [wrapper::getfirstchildwithtag [lindex $elems 0] hash]
	set hash [wrapper::getcdata $hashElem]
	set from [wrapper::getattribute $xmldata from]
	set jid2 [jlib::barejid $from]
	
	# hash can be empty.
	set state($jid2,hash) $hash
	set state($jid2,jid3) $from
	set state($jid2,protocol,avatar) 1
	set gotHash 1
    }
    return $gotHash
}

proc jlib::avatar::PresenceVCard {jlibname xmldata} {
    variable xmlns
    upvar ${jlibname}::avatar::state   state

    set gotHash 0
    set elems [wrapper::getchildswithtagandxmlns $xmldata x $xmlns(vcard-temp)]
    if {[llength $elems]} {
	set hashElem [wrapper::getfirstchildwithtag [lindex $elems 0] photo]
	set hash [wrapper::getcdata $hashElem]
	set from [wrapper::getattribute $xmldata from]
	set jid2 [jlib::barejid $from]

	# Note that all vCards are defined per jid2, bare JID.
	set state($jid2,hash) $hash
	set state($jid2,jid3) $from
	set state($jid2,protocol,vcard) 1
	set gotHash 1
    }
    return $gotHash
}

# jlib::avatar::get_async --
# 
#       The economical way of obtaining a users avatar.
#       If uptodate no query made, else it sends at most one query per user
#       to get the avatar.

proc jlib::avatar::get_async {jlibname jid cmd} {
    upvar ${jlibname}::avatar::state state
    
    jlib::splitjid $jid jid2 -
    if {[uptodate $jlibname $jid2]} {
	uplevel #0 $cmd [list result $jid2]
    } elseif {[info exists state($jid2,pending)]} {
	lappend state($jid2,invoke) $cmd
    } else {
	send_get $jlibname $jid  \
	  [list [namespace current]::get_async_cb $jlibname $jid2 $cmd]
    }
}

proc jlib::avatar::get_async_cb {jlibname jid2 cmd type subiq args} {
    upvar ${jlibname}::avatar::state state
        
    uplevel #0 $cmd [list $type $jid2]
}

# jlib::avatar::send_get --
# 
#       Initiates a request for avatar to the full jid.
#       If fails we try to get avatar from server storage of the bare jid.

proc jlib::avatar::send_get {jlibname jid cmd} {
    variable xmlns
    upvar ${jlibname}::avatar::state state
    
    debug "jlib::avatar::send_get jid=$jid"
    
    jlib::splitjid $jid jid2 -
    set state($jid2,pending) 1
    $jlibname iq_get $xmlns(iq-avatar) -to $jid  \
      -command [list [namespace current]::send_get_cb $jid $cmd]    
}

proc jlib::avatar::send_get_cb {jid cmd jlibname type subiq args} {
    variable xmlns
    upvar ${jlibname}::avatar::state state
        
    debug "jlib::avatar::send_get_cb jid=$jid"
    
    jlib::splitjid $jid jid2 -
    unset -nocomplain state($jid2,pending)

    if {$type eq "error"} {
	
	# JEP-0008: "If the first method fails, the second method that should
	# be attempted by sending a request to the server..."
	send_get_storage $jlibname $jid2 $cmd
    } elseif {$type eq "result"} {
	set ok [SetDataFromQueryElem $jlibname $jid2 $subiq $xmlns(iq-avatar)]
	invoke_stacked $jlibname $type $jid2
	uplevel #0 $cmd [list $type $subiq] $args
    }
}

# jlib::avatar::SetDataFromQueryElem --
# 
#       Extracts and sets internal avtar storage for the BARE jid
#       from a query element.
#       
# Results:
#       1 if there was data to store, 0 else.

proc jlib::avatar::SetDataFromQueryElem {jlibname jid2 queryElem ns} {
    upvar ${jlibname}::avatar::state state
    
    # Data may be empty from xmlns='storage:client:avatar' !

    set ans 0
    if {[wrapper::getattribute $queryElem xmlns] eq $ns} {
	set dataElem [wrapper::getfirstchildwithtag $queryElem data]
	if {$dataElem ne {}} {
	    
	    # Mime type can be empty.
	    set state($jid2,mime) [wrapper::getattribute $dataElem mimetype]

	    # We keep data in base64 format. This seems to be ok for image 
	    # handlers.
	    set data [wrapper::getcdata $dataElem]
	    if {[string length $data]} {
		set state($jid2,data) $data
		set state($jid2,uptodate) 1
		set ans 1
	    }
	}
    }
    return $ans
}

proc jlib::avatar::send_get_storage {jlibname jid2 cmd} {
    variable xmlns
    upvar ${jlibname}::avatar::state state
    
    debug "jlib::avatar::send_get_storage jid2=$jid2"
    
    set state($jid2,pending) 1
    $jlibname iq_get $xmlns(storage) -to $jid2  \
      -command [list [namespace current]::send_get_storage_cb $jid2 $cmd]    
}

proc jlib::avatar::send_get_storage_cb {jid2 cmd jlibname type subiq args} {
    variable xmlns
    upvar ${jlibname}::avatar::state state

    debug "jlib::avatar::send_get_storage_cb type=$type"

    unset -nocomplain state($jid2,pending)
    if {$type eq "result"} {
	set ok [SetDataFromQueryElem $jlibname $jid2 $subiq $xmlns(storage)]
    }
    invoke_stacked $jlibname $type $jid2
    uplevel #0 $cmd [list $type $subiq] $args
}

proc jlib::avatar::invoke_stacked {jlibname type jid2} {
    upvar ${jlibname}::avatar::state state
    
    if {[info exists state($jid2,invoke)]} {
	foreach cmd $state($jid2,invoke) {
	    uplevel #0 $cmd [list $jlibname $type $jid2]
	}
	unset -nocomplain state($jid2,invoke)
    }
}

#--- vCard support -------------------------------------------------------------

proc jlib::avatar::get_vcard_async {jlibname jid2 cmd} {
    upvar ${jlibname}::avatar::state state
    
    debug "jlib::avatar::get_vcard_async jid=$jid2"
    
    if {[uptodate $jlibname $jid2]} {
	uplevel #0 $cmd [list result $jid2]
    } else {
	
	# Need to clear vcard cache to trigger sending a request.
	# The photo is anyway not up-to-date.
	$jlibname vcard clear $jid2
	$jlibname vcard get_async $jid2  \
	  [list [namespace current]::get_vcard_async_cb $jid2 $cmd]
    }
}

proc jlib::avatar::get_vcard_async_cb {jid2 cmd jlibname type subiq args} {
	
    debug "jlib::avatar::get_vcard_async_cb jid=$jid2"
    
    if {$type eq "result"} {
	SetDataFromVCardElem $jlibname $jid2 $subiq
    }
    uplevel #0 $cmd [list $type $jid2]
}

# jlib::avatar::send_get_vcard --
# 
#       Support for vCard based avatars as JEP-0153.
#       We must get vcard avatars from here since the result shall be cached.
#       Note that all vCards are defined per jid2, bare JID.
#       This method is more sane compared to iq-based avatars since it is
#       based on bare jids and thus not client instance specific.
#       Therefore it also handles offline users.

proc jlib::avatar::send_get_vcard {jlibname jid2 cmd} {
    
    debug "jlib::avatar::send_get_vcard jid2=$jid2"
    
    $jlibname vcard send_get $jid2  \
      -command [list [namespace current]::send_get_vcard_cb $jid2 $cmd]
}

proc jlib::avatar::send_get_vcard_cb {jid2 cmd jlibname type subiq args} {
    
    debug "jlib::avatar::send_get_vcard_cb"

    if { $type eq "result" } {
	SetDataFromVCardElem $jlibname $jid2 $subiq
	uplevel #0 $cmd [list $type $subiq] $args
    }
}

# jlib::avatar::SetDataFromVCardElem --
# 
#       Extracts and sets internal avtar storage for the BARE jid
#       from a vcard element.
#       
# Results:
#       1 if there was data to store, 0 else.

proc jlib::avatar::SetDataFromVCardElem {jlibname jid2 subiq} {
    upvar ${jlibname}::avatar::state state
    
    set ans 0
    set photoElem [wrapper::getfirstchildwithtag $subiq PHOTO]
    if {$photoElem ne {}} {
	set dataElem [wrapper::getfirstchildwithtag $photoElem BINVAL]
	set mimeElem [wrapper::getfirstchildwithtag $photoElem TYPE]
	if {$dataElem ne {}} {
	    
	    # We keep data in base64 format. This seems to be ok for image 
	    # handlers.
	    set state($jid2,data) [wrapper::getcdata $dataElem]
	    set state($jid2,mime) [wrapper::getcdata $mimeElem] 
	    set state($jid2,uptodate) 1
	    set ans 1
	}
    }
    return $ans
}

proc jlib::avatar::debug {msg} {
    if {0} {
	puts "\t $msg"
    }
}

# We have to do it here since need the initProc before doing this.

namespace eval jlib::avatar {

    jlib::ensamble_register avatar \
      [namespace current]::init    \
      [namespace current]::cmdproc
}

if {0} {
    # Test.
    set f "/Users/matben/Desktop/glaze/32x32/apps/clanbomber.png"
    set fd [open $f]
    fconfigure $fd -translation binary
    set data [read $fd]
    close $fd
    
    set data "0123456789"
    
    set jlib jlib::jlib1
    proc cb {args} {puts "--- cb"}
    $jlib avatar set_data $data image/png
    $jlib avatar store cb
    $jlib avatar send_get [$jlib getthis myjid] cb
    $jlib avatar send_get_storage [$jlib getthis myjid2] cb
}

#-------------------------------------------------------------------------------
