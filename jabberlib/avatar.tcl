#  avatar.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for avatars (JEP-0008: IQ-Based Avatars).
#      Note that this JEP is "historical" only but is easy to adapt to
#      a future pub-sub method.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: avatar.tcl,v 1.5 2005-12-09 13:24:21 matben Exp $
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
#      jlibName avatar get_mime jid2
#      jlibName avatar have_data jid2
#      
#   Note that all internal storage refers to bare (2-tier) jids!
#   No automatic presence or server storage is made when reconfiguring or
#   changing own avatar. This is up to the client layer to do.
#      
################################################################################

package require base64     ; # tcllib
package require sha1       ; # tcllib                           
package require jlib
package require jlib::disco

package provide jlib::avatar 0.1

namespace eval jlib::avatar {

    variable inited 0
    variable xmlns
    set xmlns(x-avatar)  "jabber:x:avatar"
    set xmlns(iq-avatar) "jabber:iq:avatar"
    set xmlns(storage)   "storage:client:avatar"

    jlib::ensamble_register avatar \
      [namespace current]::init    \
      [namespace current]::cmdproc
        
    jlib::register_reset [namespace current]::reset
    jlib::disco::registerfeature $xmlns(iq-avatar)
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
	-command    ""
    }
    eval {configure $jlibname} $args
    
    # Register some standard iq handlers that are handled internally.
    $jlibname iq_register get $xmlns(iq-avatar) [namespace current]::iq_handler
    $jlibname presence_register_ex [namespace current]::presence_handler  \
      -tag x -xmlns $xmlns(x-avatar)
    
    return
}

proc jlib::avatar::reset {jlibname} {
    upvar ${jlibname}::avatar::state state
    
    # Do not unset our own avatar.
    unset -nocomplain state
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
		$jlibname unregister_presence_stanza x $xmlns(x-avatar)
	    }
	}
    }
}

#+++ Two sections: First part deals with our own avatar ------------------------

# jlib::avatar::set_data --
# 
#       Sets our own avatar data and shares it by default.
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

    $jlibname unregister_presence_stanza x $xmlns(x-avatar)
    $jlibname register_presence_stanza $xElem

    return
}

# jlib::avatar::unset_data --
# 
#       Unsets our avatar and does not share it anymore

proc jlib::avatar::unset_data {jlibname} {
    variable xmlns
    upvar ${jlibname}::avatar::avatar  avatar
    upvar ${jlibname}::avatar::options options

    unset -nocomplain avatar
    set options(-announce) 0
    set options(-share)    0
    
    $jlibname unregister_presence_stanza x $xmlns(x-avatar)
    
    return
}

# jlib::avatar::store --
# 
#       Stores our avatar at the server.
#       Must store as bare jid.

proc jlib::avatar::store {jlibname cmd} {
    variable xmlns
    upvar ${jlibname}::avatar::avatar avatar
    
    puts "jlib::avatar::store"

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

    puts "jlib::avatar::iq_handler from=$from, queryElem=$queryElem, args=$args"

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

proc jlib::avatar::presence_handler {jlibname xmldata} {
    variable xmlns
    upvar ${jlibname}::avatar::state   state
    upvar ${jlibname}::avatar::options options
    
    set elems [wrapper::getchildswithtagandxmlns $xmldata x $xmlns(x-avatar)]
    if {[llength $elems]} {
	set hashElem [wrapper::getfirstchildwithtag [lindex $elems 0] hash]
	set hash [wrapper::getcdata $hashElem]
	set from [wrapper::getattribute $xmldata from]
	jlib::splitjid $from jid2 -
	
	if {![info exists state($jid2,hash)] || ($hash ne $state($jid2,hash))} {
	    set state($jid2,hash) $hash
	    set state($jid2,uptodate) 0
	    if {[string length $options(-command)]} {
		uplevel #0 $options(-command) $from
	    }
	}
    }
}

proc jlib::avatar::uptodate {jlibname jid2} {
    upvar ${jlibname}::avatar::state state

    if {[info exists state($jid2,uptodate)]} {
	return $state($jid2,uptodate)
    } else {
	return 0
    }
}

proc jlib::avatar::get_async {jlibname jid cmd} {
    upvar ${jlibname}::avatar::state state
    
    # @@@ TODO
}

# jlib::avatar::send_get --
# 
#       Initiates a request for avatar to the full jid.
#       If fails we try to get avatar from server storage of the bare jid.

proc jlib::avatar::send_get {jlibname jid cmd} {
    variable xmlns
    upvar ${jlibname}::avatar::state state
    
    $jlibname iq_get $xmlns(iq-avatar) -to $jid  \
      -command [list [namespace current]::send_get_cb $jid $cmd]    
}

proc jlib::avatar::send_get_cb {jid cmd jlibname type subiq args} {
    variable xmlns
    upvar ${jlibname}::avatar::state state
    
    puts "jlib::avatar::send_get_cb type=$type, subiq=$subiq, args=$args"
    
    jlib::splitjid $jid jid2 -
    if {$type eq "error"} {
	
	# JEP-0008: "If the first method fails, the second method that should
	# be attempted by sending a request to the server..."
	send_get_storage $jlibname $jid2 $cmd
    } elseif {$type eq "result"} {
	SetDataFromQueryElem $jlibname $jid2 $subiq $xmlns(iq-avatar)
	uplevel #0 $cmd [list $type $subiq] $args
    }
}

# jlib::avatar::SetDataFromQueryElem --
# 
#       Extracts and sets internal avtar storage for the BARE jid
#       from a query element.

proc jlib::avatar::SetDataFromQueryElem {jlibname jid2 queryElem ns} {
    upvar ${jlibname}::avatar::state state
    
    if {[wrapper::getattribute $queryElem xmlns] eq $ns} {
	set dataElem [wrapper::getfirstchildwithtag $queryElem data]
	if {$dataElem ne ""} {
	    
	    # Mime type can be empty.
	    set state($jid2,mime) [wrapper::getattribute $dataElem mimetype]

	    # @@@ catch to be failsafe!
	    set data [wrapper::getcdata $dataElem]
	    set state($jid2,data) [::base64::decode $data]
	    set state($jid2,uptodate) 1
	}
    }    
}

proc jlib::avatar::send_get_storage {jlibname jid2 cmd} {
    variable xmlns
    
    puts "jlib::avatar::send_get_storage jid2=$jid2"
    
    $jlibname iq_get $xmlns(storage) -to $jid2  \
      -command [list [namespace current]::send_get_storage_cb $jid2 $cmd]    
}

proc jlib::avatar::send_get_storage_cb {jid2 cmd jlibname type subiq args} {
    variable xmlns
    upvar ${jlibname}::avatar::state state

    puts "jlib::avatar::send_get_storage_cb type=$type"
    
    if {$type eq "result"} {
	SetDataFromQueryElem $jlibname $jid2 $subiq $xmlns(storage)
    }
    uplevel #0 $cmd [list $type $subiq] $args
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
    proc cb {args} {puts "--- cb: $args"}
    $jlib avatar set_data $data image/png
    $jlib avatar store cb
    $jlib avatar send_get [$jlib getthis myjid] cb
    $jlib avatar send_get_storage [$jlib getthis myjid2] cb
    

}

#-------------------------------------------------------------------------------
