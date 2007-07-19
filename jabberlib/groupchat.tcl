# groupchat.tcl--
# 
#       Support for the old gc-1.0 groupchat protocol.
#       
#  Copyright (c) 2002-2005  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: groupchat.tcl,v 1.9 2007-07-19 06:28:17 matben Exp $
# 
############################# USAGE ############################################
#
#   INSTANCE COMMANDS
#      jlibName groupchat enter room nick
#      jlibName groupchat exit room
#      jlibName groupchat mynick room
#      jlibName groupchat setnick room nick ?-command tclProc?
#      jlibName groupchat status room
#      jlibName groupchat participants room
#      jlibName groupchat allroomsin
#
################################################################################

package provide groupchat 1.0
package provide jlib::groupchat 1.0

namespace eval jlib { }

namespace eval jlib::groupchat { }

# jlib::groupchat --
#
#       Provides API's for the old-style groupchat protocol, 'groupchat 1.0'.

proc jlib::groupchat {jlibname cmd args} {
    return [eval {[namespace current]::groupchat::${cmd} $jlibname} $args]
}

proc jlib::groupchat::init {jlibname} {
    upvar ${jlibname}::gchat gchat
    
    namespace eval ${jlibname}::groupchat {
	variable rooms
    }
    set gchat(allroomsin) {}
}

# jlib::groupchat::enter --
#
#       Enter room using the 'gc-1.0' protocol by sending <presence>.
#
#       args:  -command callback

proc jlib::groupchat::enter {jlibname room nick args} {
    upvar ${jlibname}::gchat gchat
    upvar ${jlibname}::groupchat::rooms rooms
    
    set room [jlib::jidmap $room]
    set jid $room/$nick
    eval {$jlibname send_presence -to $jid} $args
    set gchat($room,mynick) $nick
    
    # This is not foolproof since it may not always success.
    lappend gchat(allroomsin) $room
    set rooms($room) 1
    $jlibname service setroomprotocol $room "gc-1.0"
    set gchat(allroomsin) [lsort -unique $gchat(allroomsin)]
    return
}

proc jlib::groupchat::exit {jlibname room} {
    upvar ${jlibname}::gchat gchat
    
    set room [jlib::jidmap $room]
    if {[info exists gchat($room,mynick)]} {
	set nick $gchat($room,mynick)
	set jid $room/$nick
	$jlibname send_presence -to $jid -type "unavailable"
	unset -nocomplain gchat($room,mynick)
    }
    set ind [lsearch -exact $gchat(allroomsin) $room]
    if {$ind >= 0} {
	set gchat(allroomsin) [lreplace $gchat(allroomsin) $ind $ind]
    }
    $jlibname roster clearpresence "${room}*"
    return
}

proc jlib::groupchat::mynick {jlibname room} {
    upvar ${jlibname}::gchat gchat

    set room [jlib::jidmap $room]
    return $gchat($room,mynick)
}

proc jlib::groupchat::setnick {jlibname room nick args} {
    upvar ${jlibname}::gchat gchat
    
    set room [jlib::jidmap $room]
    set jid $room/$nick
    eval {$jlibname send_presence -to $jid} $args
    set gchat($room,mynick) $nick    
}

proc jlib::groupchat::status {jlibname room args} {
    upvar ${jlibname}::gchat gchat

    set room [jlib::jidmap $room]
    if {[info exists gchat($room,mynick)]} {
	set nick $gchat($room,mynick)
    } else {
	return -code error "Unknown nick name for room \"$room\""
    }
    set jid ${room}/${nick}
    eval {$jlibname send_presence -to $jid} $args
}

proc jlib::groupchat::participants {jlibname room} {

    upvar ${jlibname}::agent agent
    upvar ${jlibname}::gchat gchat

    set room [jlib::jidmap $room]
    set isroom 0
    if {[regexp {^[^@]+@([^@ ]+)$} $room match domain]} {
	if {[info exists agent($domain,groupchat)]} {
	    set isroom 1
	}
    }    
    if {!$isroom} {
	return -code error "Not recognized \"$room\" as a groupchat room"
    }
    
    # The rosters presence elements should give us all info we need.
    set everyone {}
    foreach userAttr [$jlibname roster getpresence $room -type available] {
	unset -nocomplain attrArr
	array set attrArr $userAttr
	lappend everyone ${room}/$attrArr(-resource)
    }
    return $everyone
}

proc jlib::groupchat::isroom {jlibname jid} {
    upvar ${jlibname}::groupchat::rooms rooms
    
    if {[info exists rooms($jid)]} {
	return 1
    } else {
	return 0
    }
}

proc jlib::groupchat::allroomsin {jlibname} {
    upvar ${jlibname}::gchat gchat

    set gchat(allroomsin) [lsort -unique $gchat(allroomsin)]
    return $gchat(allroomsin)
}

#-------------------------------------------------------------------------------
