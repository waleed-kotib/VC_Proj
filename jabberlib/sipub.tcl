#  sipub.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for the sipub prootocol (XEP-0135).
#      
#  Copyright (c) 2007  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: sipub.tcl,v 1.2 2007-10-02 06:39:13 matben Exp $
# 

package require jlib		
package require jlib::si
package require jlib::disco
			  
package provide jlib::sipub 0.1

namespace eval jlib::sipub {

    variable xmlns
    set xmlns(sipub) "http://jabber.org/protocol/si/profile/sipub"
	        
    jlib::disco::registerfeature $xmlns(sipub)
    $jlibname iq_register get $xmlns(sipub) [namespace current]::handle_get

    # We use a static cache array that maps sipub id (spid) to file name and mime.
    variable cache
    
    # Note: jlib::ensamble_register is last in this file!
}

proc jlib::sipub::init {jlibname args} {
    variable cache

    
}

proc jlib::sipub::cmdproc {jlibname cmd args} {
    return [eval {$cmd $jlibname} $args]
}

# jlib::sipub::set_cache, get_cache --
# 
#       Set or get the complete cache. Useful if we store the cache in a file
#       between sessions.

proc jlib::sipub::set_cache {cacheL} {
    variable cache
    array set cache cacheL
}

proc jlib::sipub::get_cache {} {
    variable cache
    return [array get cache]
}

# jlib::sipub::element --
# 
#       Makes a sipub element for a local file and adds the reference to cache.

proc jlib::sipub::element {jlibname fileName mime} {
    variable xmlns
    variable cache

    set spid [jlib::generateuuid]
    set cache($spid,file) $fileName
    set cache($spid,mime) $mime
    
    # FIX!
    set xE [wrapper::createtag "x"              \
      -attrlist {xmlns jabber:x:data type form} -subtags [list $fieldE]]
    set featureE [wrapper::createtag "feature"  \
      -attrlist [list xmlns $xmlns(neg)] -subtags [list $xE]]
    set sipubE [wrapper::createtag "sipub"  \
      -attrlist [list xmlns $xmlns(sipib) id $spid mime-type $mime profile $profile] \
      -subtags [list $profileE $featureE]]

    return $sipubE
}

proc jlib::sipub::send_get {jlibname } {

    
}

# jlib::sipub::handle_get --
# 
#       Handles incoming iq-get/sipub stanzas.

proc jlib::sipub::handle_get {jlibname from iqChild args} {
    variable cache

    array set argsA $args
    array set attr [wrapper::getattrlist $iqChild]
    if {![info exists argsA(-id)]} {
	return 0
    }
    set id $argsA(-id)
    if {![info exists attr(id)]} {
	return 0
    }
    set spid $attr(id)    
    if {[info exists cache($spid.file)]} {
	
	# ???
	$jlibname filetransfer send $from $send_cb -file $cache($spid,file) \
	  -mime $cache($spid,mime) -progress
    } else {
	jlib::send_iq_error $jlibname $from $id 403 cancel forbidden
    }
    return 1
}

# We have to do it here since need the initProc before doing this.

namespace eval jlib::sipub {
	
    jlib::ensamble_register sipub  \
      [namespace current]::init           \
      [namespace current]::cmdproc
}

#-------------------------------------------------------------------------------
