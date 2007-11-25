#  sipub.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for the sipub prootocol:
#      XEP-0137: Publishing Stream Initiation Requests 
#      
#  Copyright (c) 2007  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: sipub.tcl,v 1.7 2007-11-25 15:48:54 matben Exp $
# 
# NB: There are three different id's floating around:
#     1) iq-get/result related
#     2) sipub id (spid)
#     3) si id (stream id, sid) 
#     
# @@@ TODO: Move some code to the profile instead since we have hardcoded
#           the 'filetransfer' profile.

package require jlib		
package require jlib::si
package require jlib::disco
			  
package provide jlib::sipub 0.2

namespace eval jlib::sipub {

    variable xmlns
    set xmlns(sipub) "http://jabber.org/protocol/si-pub"
	        
    jlib::disco::registerfeature $xmlns(sipub)

    # We use a static cache array that maps sipub id (spid) to file name and mime.
    # This seems more practical since the jlib instances may vary between the
    # sessions.
    variable cache
    
    # Note: jlib::ensamble_register is last in this file!
}

proc jlib::sipub::init {jlibname args} {
    variable xmlns

    $jlibname iq_register get $xmlns(sipub) [namespace current]::handle_get
}

proc jlib::sipub::cmdproc {jlibname cmd args} {
    return [eval {$cmd $jlibname} $args]
}

#--- Initiator side ------------------------------------------------------------
#
# Initiator and target are dubious names here. With initiator we mean the part
# that has a file to offer, and target the one who gets it.

# jlib::sipub::set_cache, get_cache --
# 
#       Set or get the complete cache. Useful if we store the cache in a file
#       between sessions.

proc jlib::sipub::set_cache {cacheL} {
    variable cache
    array set cache $cacheL
}

proc jlib::sipub::get_cache {} {
    variable cache
    return [array get cache]
}

# jlib::sipub::newcache --
# 
#       This just adds a reference to our cache. Used to construct xmpp uri
#       for 'recvfile'.

proc jlib::sipub::newcache {fileName mime} {
    variable cache

    set spid [jlib::generateuuid]
    set cache($spid,file) $fileName
    set cache($spid,mime) $mime
    
    return $spid
}

# jlib::sipub::element --
# 
#       Makes a sipub element for a local file and adds the reference to cache.
#       This is the constructor for a sipub object. Each object may generate
#       any number of file transfers instances, each with its unique 'sid'.
#       Once a sipub instance is created it can be made to live as long as
#       the cache is kept.
#       This shall be called from the profile or application layer.
#       
# Results:
#       sipub element.

# @@@ Shall it have jlibname?

proc jlib::sipub::element {from profile profileE fileName mime} {
    variable xmlns
    variable cache

    set spid [jlib::generateuuid]
    set cache($spid,file) $fileName
    set cache($spid,mime) $mime
    
    set attr [list xmlns $xmlns(sipub) from $from id $spid mime-type $mime \
      profile $profile]
    set sipubE [wrapper::createtag "sipub" -attrlist $attr \
      -subtags [list $profileE]]

    return $sipubE
}

# jlib::sipub::handle_get --
# 
#       Handles incoming iq-get/start sipub stanzas. 
#       There must be a sipub object with matching id (spid).
#       This has the corresponding role of the HTTP server side GET request.
#       
#       NB: We have hardcoded the 'filetransfer' profile.

proc jlib::sipub::handle_get {jlibname from startE args} {
    variable xmlns
    variable cache

    array set argsA $args
    if {![info exists argsA(-id)]} {
	return 0
    }
    set id $argsA(-id)
    if {[wrapper::gettag $startE] ne "start"} {
	return 0
    }
    array set attr [wrapper::getattrlist $startE]
    if {![info exists attr(id)]} {
	return 0
    }
    set spid $attr(id)    
    if {[info exists cache($spid,file)]} {
	
	# We must pick the 'sid' here since it is also used in 'starting'.
	set sid [jlib::generateuuid]
	set startingE [wrapper::createtag "starting" \
	  -attrlist [list xmlns $xmlns(sipub) sid $sid]]
	$jlibname send_iq result [list $startingE] -id $id -to $from

	# This is the constructor of a file stream.
	$jlibname filetransfer send $from [namespace code send_cb] -sid $sid \
	  -file $cache($spid,file) \
	  -mime $cache($spid,mime)
    } else {
	jlib::send_iq_error $jlibname $from $id 405 modify not-acceptable
    }
    return 1
}

proc jlib::sipub::send_cb {jlibname status sid {subiq ""}} {
    
    # empty.
}

#--- Target side ---------------------------------------------------------------

# jlib::sipub::have_sipub --
# 
#       Searches an element recursively to see if there is a sipub element.

proc jlib::sipub::have_sipub {xmldata} {
    variable xmlns
    
    return [llength [wrapper::getchilddeep $xmldata \
      [list [list sipub $xmlns(sipub)]]]]
}

proc jlib::sipub::get_element {xmldata} {
    variable xmlns
    
    return [wrapper::getchilddeep $xmldata [list [list sipub $xmlns(sipub)]]]
}

# NB: We have a separate 'start' command in order to catch the response and
#     obtain the 'sid' which is typically needed to control the file transfer.

# Typical usage:
# 
#       jlib sipub start ... cb
#       proc cb {type startingE} {
#            set sid [wrapper::getattribute $startingE sid]
#            jlib sipub set_accept_handler $sid \
#                -channel ... -command ... -progress ...
#       }

# jlib::sipub::start --
# 
#       Sends a start element. A iq-result/error is expected.
#       This 'id' must be a matching spid.

proc jlib::sipub::start {jlibname jid id cmd} {
    variable xmlns

    set startE [wrapper::createtag "start" \
      -attrlist [list xmlns $xmlns(sipub) id $id]]
    $jlibname send_iq get [list $startE] -to $jid -command $cmd
}

# jlib::sipub::set_accept_handler --
# 
#       This is normally called as a response to the 'start' command's
#       callback when we get a sipub 'starting' element.
#       We shall typically provide -command, -progress, and -channel.
#       
# Arguments:
#       xmldata     complete message element or whatever.
#       args:       -channel
#                   -command
#                   -progress
#                   
# Result:
#       none

proc jlib::sipub::set_accept_handler {jlibname sid args} {
    variable state

    # This is just kept until we get the si-callback.
    set state($sid,args) $args

    # We shall be prepared to get the si-set request.
    $jlibname filetransfer register_sid_handler $sid \
      [namespace code [list si_handler $sid]]
    return
}

proc jlib::sipub::si_handler {sid jlibname jid name size cmd args} {
    variable state
    
    #puts "jlib::sipub::si_handler sid=$sid"

    # We requested this file using 'sipub::get' in the first place so
    # therefore accept the stream.
    # We also provide all the arguments -channel etc.
    uplevel #0 $cmd 1 $state($sid,args)
    unset state($sid,args)
}

# We have to do it here since need the initProc before doing this.

namespace eval jlib::sipub {
	
    jlib::ensamble_register sipub  \
      [namespace current]::init    \
      [namespace current]::cmdproc
}

# Test:
if {0} {
    package require jlib::sipub
    set jlib ::jlib::jlib1
    
    # Initiator side:
    set jid matben@localhost
    set fileName /Users/matben/Desktop/splash.svg
    set name [file tail $fileName]
    set size [file size $fileName]
    set fileE [jlib::ftrans::element $name $size]
    set sipubE [jlib::sipub::element [$jlib myjid] $jlib::ftrans::xmlns(ftrans) \
      $fileE $fileName image/svg]
    
    $jlib send_message $jid -xlist [list $sipubE]
    
    # Target side:
    package require jlib::sipub
    set jlib ::jlib::jlib1
    proc progress {args} {puts "progress: $args"}
    proc command  {args} {puts "command: $args"}
    proc msg {jlib xmlns xmldata args} {
	puts "message: $xmldata"
	set ::messageE $xmldata
	return 0
    }
    $jlib message_register normal * msg
    
    set fileName /Users/matben/Desktop/splash.svg
    set fd [open $fileName.tmp w]
    
    proc start_cb {type startingE} {
	puts "start_cb type=$type"
	if {$type eq "result"} {
	    set sid [wrapper::getattribute $startingE sid]
	    $::jlib sipub set_accept_handler $sid \
	      -channel $::fd -command command -progress progress
	}
    }
    set sipubE [wrapper::getchilddeep $messageE \
      [list [list sipub $jlib::sipub::xmlns(sipub)]]]
    set from [wrapper::getattribute $sipubE from]
    if {$from eq ""} {
	set from [wrapper::getattribute $messageE from]
    }
    set spid [wrapper::getattribute $sipubE id]
    $jlib sipub start $from $spid start_cb
    
}

#-------------------------------------------------------------------------------
