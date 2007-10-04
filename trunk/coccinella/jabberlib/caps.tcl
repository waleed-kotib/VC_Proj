#  caps.tcl --
#  
#   This file is part of the jabberlib. It handles the internal cache
#   for caps (xmlns='http://jabber.org/protocol/caps') XEP-0115.
#   It is updated to version 1.3 of XEP-0115.
#      
#   A typical caps element looks like:
#   
#   <presence>
#      <c xmlns='http://jabber.org/protocol/caps'
#          node='http://exodus.jabberstudio.org/caps'
#          ver='0.9'
#          ext='tins ftrans xhtml'/>
#   </presence> 
#      
#  The core function of caps is a mapping:
#     
#     jid -> node+ver -> disco info
#     jid -> node+ext -> disco info
#     
#  NB: The ext must be consistent over all versions (ver).
#  
#  UPDATE version 1.4: ---------------------------------------------------------
#  
#  <presence from='romeo@montague.lit/orchard'>
#      <c xmlns='http://jabber.org/protocol/caps' 
#         node='http://exodus.jabberstudio.org/#0.9.1'
#         ver='8RovUdtOmiAjzj+xI7SK5BCw3A8='/>
#  </presence> 
#  
#  The 'ver' map to a unique combination of disco identities+features.
#  
#  -----------------------------------------------------------------------------
#  
#  Copyright (c) 2005-2007  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: caps.tcl,v 1.25 2007-10-04 14:01:07 matben Exp $
# 
############################# USAGE ############################################
#
#   NAME
#      caps - convenience command library for caps: Entity Capabilities 
#      
#   INSTANCE COMMANDS
#      jlibname caps register name xmllist features
#      jlibname caps configure ?-autodisco 0|1? -command tclProc
#      jlibname caps getexts
#      jlibname caps getxmllist name
#      jlibname caps getallfeatures
#      jlibname caps getfeatures name
#           
#      The 'name' is here the ext token.

# TODO: make a static cache (variable cache) which maps the hashed ver attribute
#       to a list of disco identities and features.

package require base64     ; # tcllib
package require sha1       ; # tcllib                           
package require jlib::disco
package require jlib::roster

package provide jlib::caps 0.3

namespace eval jlib::caps {
    
    variable xmlns
    set xmlns(caps) "http://jabber.org/protocol/caps"    
    
    # Note: jlib::ensamble_register is last in this file!
}

proc jlib::caps::init {jlibname args} {
           
    # Instance specific arrays.
    namespace eval ${jlibname}::caps {
	variable ext
	variable options
    }
    
    upvar ${jlibname}::caps::options options
    array set options {
	-autodisco 0
	-command   {}
    }
    eval {configure $jlibname} $args
    
    # Since the caps element from a JID is globally defined there is no need
    # to keep its state instance specific (per jlibname).
    
    # The cache for disco results. Must not be instance specific.
    variable caps
    
    # This collects various mappings and states:
    #  o It keeps track of mapping jid -> node+ver+exts
    #  o
    variable state
    
    jlib::presence_register_int $jlibname available    \
      [namespace current]::avail_cb
    jlib::presence_register_int $jlibname unavailable  \
      [namespace current]::unavail_cb
    
    jlib::register_reset $jlibname [namespace current]::reset
}

proc jlib::caps::configure {jlibname args} {
    upvar ${jlibname}::caps::options options
    
    if {[llength $args]} {
	foreach {key value} $args {
	    switch -- $key {
		-autodisco {
		    if {[string is boolean -strict $value]} {
			set options(-autodisco) $value
		    } else {
			return -code error "expected boolean for -autodisco"
		    }
		}
		-command {
		    set options(-command) $value
		}
		default {
		    return -code error "unrecognized option \"$key\""
		}
	    }
	}
    } else {
	return [array get options]
    }
}

proc jlib::caps::cmdproc {jlibname cmd args} {
    
    # Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

#--- First, handle our own caps stuff ------------------------------------------

# jlib::caps::register --
# 
#       Register an 'ext' token and associated disco#info element.
#       The 'name' is the ext token.
#       The 'features' must be the 'var' attributes in 'xmllist'.
#       <feature var='http://jabber.org/protocol/disco#info'/> 

proc jlib::caps::register {jlibname name xmllist features} {
    upvar ${jlibname}::caps::ext ext
    
    set ext(name,$name)     $name
    set ext(xmllist,$name)  $xmllist
    set ext(features,$name) $features
}

proc jlib::caps::getallidentities {jlibname} {
    upvar ${jlibname}::caps::ext ext
    
    return $ext(identities)
}

proc jlib::caps::getexts {jlibname} {
    upvar ${jlibname}::caps::ext ext
    
    set exts [list]
    foreach {key name} [array get ext name,*] {
	lappend exts $name
    }
    return [lsort $exts]
}

proc jlib::caps::getxmllist {jlibname name} {
    upvar ${jlibname}::caps::ext ext
    
    if {[info exists ext(xmllist,$name)]} {
	return $ext(xmllist,$name)
    } else {
	return
    }
}

proc jlib::caps::getfeatures {jlibname name} {
    upvar ${jlibname}::caps::ext ext
    
    if {[info exists ext(features,$name)]} {
	return $ext(features,$name)
    } else {
	return
    }
}

proc jlib::caps::getallfeatures {jlibname} {
    upvar ${jlibname}::caps::ext ext
    
    set featureL [list]
    foreach {key features} [array get ext features,*] {
	set featureL [concat $featureL $features]
    }
    return [lsort -unique $featureL]
}

# jlib::caps::generate_ver --
# 
#       This just takes the internal identities and features into account.
#       NB: A client MUST synchronize the disco identity amd feature elements
#           here else we respond with a false ver attribute!

proc jlib::caps::generate_ver {jlibname} {
    
    set identities [jlib::disco::getidentities $jlibname]
    set features [concat [getallfeatures $jlibname] \
      [jlib::disco::getregisteredfeatures]]
    return [create_ver $identities $features]
}

proc jlib::caps::create_ver {identityL featureL} {

    set ver ""
    append ver [join [lsort -unique $identityL] <]
    append ver <
    append ver [join [lsort -unique $featureL] <]
    append ver <
    set hex [::sha1::sha1 $ver]
    
    # Inverse to: [format %0.8x%0.8x%0.8x%0.8x%0.8x $H0 $H1 $H2 $H3 $H4]
    set parts ""
    for {set i 0} {$i < 5} {incr i} {
	append parts "0x"
	append parts [string range $hex [expr {8*$i}] [expr {8*$i + 7}]]
	append parts " "
    }
    # Works independent on machine Endian order!
    set bin [eval binary format IIIII $parts]
    return [::base64::encode $bin]
}

# Test case:
if {0} {
    set S "client/pc<http://jabber.org/protocol/disco#info<http://jabber.org/protocol/disco#items<http://jabber.org/protocol/muc<"
    # 8RovUdtOmiAjzj+xI7SK5BCw3A8=

    set identityL {client/pc}
    set featureL {
	"http://jabber.org/protocol/disco#info"
	"http://jabber.org/protocol/disco#items"
	"http://jabber.org/protocol/muc"
    }
    jlib::caps::create_ver $identityL $featureL
}

#--- Second, handle all users caps stuff ---------------------------------------

# jlib::caps::disco_ver --
# 
#       Disco#info request for client#version 
#       
#       <iq type='get' to='randomuser1@capulet.com/resource'>
#           <query xmlns='http://jabber.org/protocol/disco#info'
#               node='http://exodus.jabberstudio.org/caps#0.9'/>
#       </iq> 
# 
#       We MUST have got a presence caps element for this user.
#       
#       The client that received the annotated presence sends a disco#info 
#       request to exactly one of the users that sent a particular presenece
#       element caps combination of node and ver.

proc jlib::caps::disco_ver {jlibname jid} {

    set ver [$jlibname roster getcapsattr $jid ver]
    disco $jlibname $jid ver $ver
}

# jlib::caps::disco_ext --
# 
#       Disco the 'ext' via the caps node+ext cache.
#       
#       We MUST have got a presence caps element for this user with the
#       corresponding 'ext' token.

proc jlib::caps::disco_ext {jlibname jid ext} {

    disco $jlibname $jid ext $ext
}

# jlib::caps::disco --
# 
#       Internal use only. See disco_ver and disco_ext.
#       
# Arguments:
#       what:       "ver" or "ext"
#       value:      value for 'ver' or the name of the 'ext'.

proc jlib::caps::disco {jlibname jid what value} {
    variable state
    variable caps
    
    set node [$jlibname roster getcapsattr $jid node]
    set key $what,$node,$value
    	
    # Mark that we have a pending node+ver or node+ext request.
    set state(pending,$key) 1
    
    # It should be safe to use 'disco get_async' here.
    # Need to provide node+ver for error recovery.
    set cb [list [namespace current]::disco_cb $node $what $value]
    $jlibname disco get_async info $jid $cb -node ${node}#${value}
}

# jlib::caps::disco_cb --
# 
#       Callback for 'disco get_async'.
#       We must take care of a situation where the jid went unavailable,
#       or otherwise returns an error, and try to use another jid.

proc jlib::caps::disco_cb {node what value jlibname type from queryE args} {
    upvar ${jlibname}::caps::options options
    variable state
    variable caps

    set key $what,$node,$value
    unset -nocomplain state(pending,$key)

    if {$type eq "error"} {
	
	# If one client with a certain 'key' fails it is likely all will
	# fail since they are assumed to be identical, unless it failed
	# because it went offline.
	# @@@ Risk for infinite loop?
	if {$options(-autodisco) && ![$jlibname roster isavailable $from]} {
	    set rjid [get_random_jid $what $node $value]
	    if {$rjid ne ""} {
		disco $jlibname $rjid $what $value
	    }
	}
    } else {
	set jid [jlib::jidmap $from]
	
	# Cache the returned element to be reused for all node+ver combinations.
	set caps(queryE,$key) $queryE
	if {[llength $options(-command)]} {
	    uplevel #0 $options(-command) [list $jlibname $from $queryE]
	}
    }
}

# OBSOLETE IN 1.4

# jlib::caps::avail_cb --
# 
#       Registered available presence callback.
#       Keeps track of all jid <-> node+ver combinations.
#       The exts may be different for identical node+ver and must be
#       obtained for individual jids using 'roster getcapsattr'.

proc jlib::caps::avail_cb {jlibname xmldata} {
    upvar ${jlibname}::caps::options options
    variable state
    variable caps
    
    set jid [wrapper::getattribute $xmldata from]
    set jid [jlib::jidmap $jid]

    set node [$jlibname roster getcapsattr $jid node]
	
    # Skip if the client doesn't have a caps presence element.
    if {$node eq ""} {
	return
    }
    set ver [$jlibname roster getcapsattr $jid ver]
    set ext [$jlibname roster getcapsattr $jid ext]
        	    
    # Map jid -> node+ver+ext. Note that 'ext' may be empty.
    set state(jid,node,$jid) $node
    set state(jid,ver,$jid)  $ver
    set state(jid,ext,$jid)  $ext
	    
    # For each combinations node+ver and node+ext we must be able to collect
    # a list of JIDs where we shall pick a random one to disco.    
    # Avoid a linear search. Better to use the array hash mechanism.
    
    set state(jids,ver,$ver,$node,$jid) $jid
    foreach e $ext {
	set state(jids,ext,$e,$node,$jid) $jid
    }
        
    # If auto disco then try to disco all node+ver and node+exts which we
    # don't have and aren't waiting for.
    if {$options(-autodisco)} {
	set key ver,$node,$ver
	if {![info exists caps(queryE,$key)]} {
	    if {![info exists state(pending,$key)]} {
		set rjid [get_random_jid ver $node $ver]
		if {$rjid ne ""} {
		    disco $jlibname $rjid ver $ver
		}
	    }
	}
	foreach e $ext {
	    set key ext,$node,$e
	    if {![info exists caps(queryE,$key)]} {
		if {![info exists state(pending,$key)]} {
		    set rjid [get_random_jid ext $node $e]
		    if {$rjid ne ""} {
			disco $jlibname $rjid ext $e
		    }
		}
	    }
	}
    }
    return 0
}

# OBSOLETE IN 1.4

# jlib::caps::get_random_jid_ver, get_random_jid_ext --
# 
#       Methods to pick a random JID from node+ver or node+ext.

proc jlib::caps::get_random_jid {what node value} {
    get_random_jid_$what $node $value
}

proc jlib::caps::get_random_jid_ver {node ver} {
    variable state
    
    set keys [array names state jids,ver,$ver,$node,*]
    if {[llength $keys]} {
	set idx [expr {int(rand()*[llength $keys])}]
	return $state([lindex $keys $idx])
    } else {
	return 
    }
}

proc jlib::caps::get_random_jid_ext {node ext} {
    variable state
    
    set keys [array names state jids,ext,$ext,$node,*]
    if {[llength $keys]} {
	set idx [expr {int(rand()*[llength $keys])}]
	return $state([lindex $keys $idx])
    } else {
	return 
    }
}

# OBSOLETE IN 1.4

# jlib::caps::unavail_cb --
# 
#       Registered unavailable presence callback.
#       Frees internal cache related to this jid.

proc jlib::caps::unavail_cb {jlibname xmldata} {
    variable state

    set jid [wrapper::getattribute $xmldata from]
    set jid [jlib::jidmap $jid]
    
    # JID may not have caps.
    if {![info exists state(jid,node,$jid)]} {
	return
    }
    set node $state(jid,node,$jid)
    set ver  $state(jid,ver,$jid)
    set ext  $state(jid,ext,$jid)
        
    set jidESC [jlib::ESC $jid]
    array unset state jid,node,$jidESC
    array unset state jid,ver,$jidESC
    array unset state jid,ext,$jidESC
    array unset state jids,*,$jidESC

    return 0
}

proc jlib::caps::reset {jlibname} {
    variable state
    
    unset -nocomplain state
}

# OBSOLETE IN 1.4

proc jlib::caps::writecache {fileName} {
    variable caps

    set fd [open $fileName w]
    fconfigure $fd -encoding utf-8
    foreach {key value} [array get caps] {
	puts $fd [list set caps($key) $value]
    }
    close $fd
}

proc jlib::caps::readcache {fileName} {
    variable caps

    source $fileName
}

proc jlib::caps::freecache {} {
    variable caps

    unset -nocomplain caps
}

# We have to do it here since need the initProc before doing this.

namespace eval jlib::caps {

    jlib::ensamble_register caps  \
      [namespace current]::init   \
      [namespace current]::cmdproc
}

# Tests
if {0} {
    
    proc cb {args} {}
    set jlib ::jlib::jlib1
    set jid matben@localhost/coccinella
    set caps "http://coccinella.sourceforge.net/protocol/caps"
    set ver 0.95.17
    $jlib disco send_get info $jid cb -node $caps#$ver
    $jlib disco send_get info $jid cb -node $caps#whiteboard
    $jlib disco send_get info $jid cb -node $caps#iax
}
