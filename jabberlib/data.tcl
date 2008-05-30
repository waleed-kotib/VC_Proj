#  data.tcl --
#
#      This file is part of the jabberlib. It contains support code
#      for XEP-0231: Data Element 
#
#  Copyright (c) 2008 Mats Bengtsson
#  
# This file is distributed under BSD style license.
#
# $Id: data.tcl,v 1.1 2008-05-30 14:21:02 matben Exp $
#
############################# USAGE ############################################
#
#   INSTANCE COMMANDS
#      jlibName data create 
#
################################################################################

package require jlib
package require base64     ; # tcllib

package provide jlib::data 0.1

namespace eval jlib::data {

    # Common xml namespaces.
    variable xmlns
    array set xmlns {
        data "urn:xmpp:tmp:data-element"
    }
}

# jlib::data::init --
#
#       Creates a new instance of the data object.

proc jlib::data::init {jlibname} {
    variable xmlns
    
    # Instance specifics arrays.
    namespace eval ${jlibname}::data {
	variable cache
    }

    # Register some standard iq handlers that are handled internally.
    $jlibname iq_register get $xmlns(data) [namespace code iq_handler]
}

proc jlib::data::cmdproc {jlibname cmd args} {
    return [eval {$cmd $jlibname} $args]
}

proc jlib::data::element {type data args} {
    variable xmlns
    upvar ${jlibname}::data::cache cache
    
    set attrL [list xmlns $xmlns(data)]
    foreach {key value} $args {
	-alt - -cid {
	    set name [string trimleft $key -]
	    set $name $value
	    lappend attrL $name $value
	}
    }
    set dataE [wrapper::createtag data \
      -attrlist $attrL -chdata [::base64::encode $data]]
    if {[info exists cid]} {
	set cache($cid) $dataE
    }
    return $dataE
}

proc jlib::data::iq_handler {jlibname from dataE args} {
    upvar ${jlibname}::data::cache cache

    array set argsA $args
    if {![info exists argsA(id)]} {
	return 0
    }
    set cid [wrapper::getattribute $dataE cid]
    if {![info exists cache($cid)]} {
	# Should be <item-not-found/>
	return 0
    }
    
    $jlibname send_iq result $cache($cid) -to $from -id $id
    return 1
}

# We have to do it here since need the initProc before doing this.
namespace eval jlib::data {

    jlib::ensamble_register data  \
      [namespace current]::init    \
      [namespace current]::cmdproc
}

# Test:
if {0} {
    package require jlib::data
    set jlibname ::jlib::jlib1

    
}

