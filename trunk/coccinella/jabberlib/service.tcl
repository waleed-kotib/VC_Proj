# service.tcl --
#
#       This is an abstraction layer for groupchat protocols gc-1.0/muc.
#       All except disco/muc are EOL!
#       
#  Copyright (c) 2004-2006  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: service.tcl,v 1.27 2008-02-06 13:57:25 matben Exp $
# 
############################# USAGE ############################################
#
#   NAME
#      service - protocol independent methods for groupchats/muc
#                
#   SYNOPSIS
#      jlib::service::init jlibName
#      
#   INSTANCE COMMANDS
#      jlibName service allroomsin
#      jlibName service exitroom room
#      jlibName service isroom jid
#      jlibName service nick jid
#      jlibName service register type name
#      jlibName service roomparticipants room
#      jlibName service setroomprotocol jid protocol
#      jlibName service unregister type name
# 
# 
#   VARIABLES
#
# serv:	                             
#	serv(gcProtoPriority)      : The groupchat protocol priority list.                             
#	                             
#       serv(gcprot,$jid)          : Map a groupchat service jid to protocol:
#       	                     (gc-1.0|muc)
#
#       serv(prefgcprot,$jid)      : Stores preferred groupchat protocol that
#                                    overrides the priority list.
#     
############################# CHANGES ##########################################
#
#       0.1         first version

package provide service 1.0

namespace eval ::jlib {}

namespace eval jlib::service {
    
    # This is an abstraction layer for the groupchat protocols gc-1.0/muc.
    
    # Cache the following services in particular.
    variable services {search register groupchat conference muc}    

    # Maintain a priority list of groupchat protocols in decreasing priority.
    # Entries must match: ( gc-1.0 | muc )
    variable groupchatTypeExp {(gc-1.0|muc)}
}

proc jlib::service {jlibname cmd args} {
    set ans [eval {[namespace current]::service::${cmd} $jlibname} $args]
    return $ans
}

proc jlib::service::init {jlibname} {
    
    upvar ${jlibname}::serv serv

    # Init defaults.
    array set serv {
	disco    0
	muc      0
    }
	    
    # Maintain a priority list of groupchat protocols in decreasing priority.
    # Entries must match: ( gc-1.0 | muc )
    set serv(gcProtoPriority) {muc gc-1.0}
}

# jlib::service::register --
# 
#       Let components (browse/disco/muc etc.) register that their services
#       are available.

proc jlib::service::register {jlibname type name} {    
    upvar ${jlibname}::serv serv

    set serv($type) 1
    set serv($type,name) $name
}

proc jlib::service::unregister {jlibname type} {
    upvar ${jlibname}::serv serv

    set serv($type) 0
    array unset serv $type,*
}

proc jlib::service::get {jlibname type} {
    upvar ${jlibname}::serv serv
    
    if {$serv($type)} {
	return $serv($type,name)
    } else {
	return
    }
}

#-------------------------------------------------------------------------------
#
# A couple of routines that handle the selection of groupchat protocol for
# each groupchat service.
# A groupchat service may support more than a single protocol. For instance,
# the MUC component supports both gc-1.0 and MUC.

# Needs some more verification before using it for a dispatcher.


# jlib::service::registergcprotocol --
# 
#       Register (sets) a groupchat service jid according to the priorities
#       presently set. Only called internally!

proc jlib::service::registergcprotocol {jlibname jid gcprot} {
    upvar ${jlibname}::serv serv
    
    Debug 2 "jlib::registergcprotocol jid=$jid, gcprot=$gcprot"
    set jid [jlib::jidmap $jid]
    
    # If we already told jlib to use a groupchat protocol then...
    if {[info exist serv(prefgcprot,$jid)]} {
	return
    }
    
    # Set 'serv(gcprot,$jid)' according to the priority list.
    foreach prot $serv(gcProtoPriority) {
	
	# Do we have registered a groupchat protocol with higher priority?
	if {[info exists serv(gcprot,$jid)] && \
	  [string equal $serv(gcprot,$jid) $prot]} {
	    return
	}
	if {[string equal $prot $gcprot]} {
	    set serv(gcprot,$jid) $prot
	    return
	}	
    }
}

# jlib::service::setroomprotocol --
# 
#       Set the groupchat protocol in use for room. This acts only as a
#       dispatcher for 'service' commands.  
#       Only called internally when entering a room!

proc jlib::service::setroomprotocol {jlibname roomjid protocol} {
    variable groupchatTypeExp
    upvar ${jlibname}::serv serv
    
    set roomjid [jlib::jidmap $roomjid]
    if {![regexp $groupchatTypeExp $protocol]} {
	return -code error "Unrecognized groupchat protocol \"$protocol\""
    }
    set serv(roomprot,$roomjid) $protocol
}

# jlib::service::isroom --
# 
#       Try to figure out if the jid is a room.
#       If we've browsed it it's been registered in our browse object.
#       If using agent(s) method, check the agent for this jid

proc jlib::service::isroom {jlibname jid} {    
    upvar ${jlibname}::serv serv
    upvar ${jlibname}::locals locals
    
    # Check if domain name supports the 'groupchat' service.
    # disco uses explicit children of conference, and muc cache
    set isroom 0
    if {!$isroom && $serv(disco) && [$jlibname disco isdiscoed info $locals(server)]} {
	set isroom [$jlibname disco isroom $jid]
    }
    if {!$isroom && $serv(muc)} {
	set isroom [$jlibname muc isroom $jid]
    }
    if {!$isroom} {
	set isroom [jlib::groupchat::isroom $jlibname $jid]
    }
    return $isroom
}

# jlib::service::nick --
#
#       Return nick name for ANY room participant, or the rooms name
#       if jid is a room.
#       Not very useful since old 'conference' protocol has gone but keep
#       it as an abstraction anyway.
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        'roomname@conference.jabber.org/nick' typically,
#                   or just room jid.

proc jlib::service::nick {jlibname jid} {   
    return [jlib::resourcejid $jid]
}

# jlib::service::mynick --
#
#       A way to get our OWN nickname for a given room independent of protocol.
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#       room:       'roomname@conference.jabber.org' typically.
#       
# Results:
#       mynickname

proc jlib::service::mynick {jlibname room} {
    upvar ${jlibname}::serv serv
    
    set room [jlib::jidmap $room]
    
    # All kind of conference components seem to support the old 'gc-1.0'
    # protocol, and we therefore must query our method for entering the room.
    if {![info exists serv(roomprot,$room)]} {
	return -code error "Does not know which protocol to use in $room"
    }
    
    switch -- $serv(roomprot,$room) {
	gc-1.0 {
	    set nick [$jlibname groupchat mynick $room]
	} 
	muc {
	    set nick [$jlibname muc mynick $room]
	} 
    }
    return $nick
}

# jlib::service::setnick --

proc jlib::service::setnick {jlibname room nick args} {
    upvar ${jlibname}::serv serv
    
    set room [jlib::jidmap $room]
    if {![info exists serv(roomprot,$room)]} {
	return -code error "Does not know which protocol to use in $room"
    }

    switch -- $serv(roomprot,$room) {
	gc-1.0 {
	    eval {$jlibname groupchat setnick $room $nick} $args
	} 
	muc {
	    eval {$jlibname muc setnick $room $nick} $args
	} 
    }
}

# jlib::service::allroomsin --
# 
# 

proc jlib::service::allroomsin {jlibname} {    
    upvar ${jlibname}::lib lib
    upvar ${jlibname}::gchat gchat
    upvar ${jlibname}::serv serv

    set roomList [concat $gchat(allroomsin) \
      [[namespace parent]::muc::allroomsin $jlibname]]
    if {$serv(muc)} {
	set roomList [concat $roomList [$jlibname muc allroomsin]]
    }
    return [lsort -unique $roomList]
}

proc jlib::service::roomparticipants {jlibname room} {
    upvar ${jlibname}::locals locals
    upvar ${jlibname}::serv serv
    
    set room [jlib::jidmap $room]
    if {![info exists serv(roomprot,$room)]} {
	return -code error "Does not know which protocol to use in $room"
    }

    set everyone {}
    if {![[namespace current]::isroom $jlibname $room]} {
	return -code error "The jid \"$room\" is not a room"
    }

    switch -- $serv(roomprot,$room) {
	gc-1.0 {
	    set everyone [[namespace parent]::groupchat::participants $jlibname $room]
	} 
	muc {
	    set everyone [$jlibname muc participants $room]
	}
    }
    return $everyone
}

proc jlib::service::exitroom {jlibname room} {    
    upvar ${jlibname}::locals locals
    upvar ${jlibname}::serv serv

    set room [jlib::jidmap $room]
    if {![info exists serv(roomprot,$room)]} {
	#return -code error "Does not know which protocol to use in $room"
	# Not sure here???
	set serv(roomprot,$room) "gc-1.0"
    }

    switch -- $serv(roomprot,$room) {
	gc-1.0 {
	    [namespace parent]::groupchat::exit $jlibname $room
	}
	muc {
	    $jlibname muc exit $room
	}
    }
}

#-------------------------------------------------------------------------------
