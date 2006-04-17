#  muc.tcl --
#  
#      This file is part of the whiteboard application and jabberlib.
#      It implements the Multi User Chat (MUC) protocol part of the XMPP
#      protocol as defined by the 'http://jabber.org/protocol/muc*'
#      namespace.
#      
#  Copyright (c) 2003-2005  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#
# $Id: muc.tcl,v 1.29 2006-04-17 13:23:38 matben Exp $
# 
############################# USAGE ############################################
#
#   NAME
#      muc - convenience command library for MUC
#      
#   OPTIONS
#	see below for instance command options
#	
#   INSTANCE COMMANDS
#      jlibname muc allroomsin
#      jlibname muc create roomjid nick callback ?-extras?
#      jlibname muc destroy roomjid ?-command, -reason, alternativejid?
#      jlibname muc enter roomjid nick ?-command, -extras, -password?
#      jlibname muc exit roomjid
#      jlibname muc getaffiliation roomjid affiliation callback
#      jlibname muc getrole roomjid role callback
#      jlibname muc getroom roomjid callback
#      jlibname muc invite roomjid jid ?-reason?
#      jlibname muc isroom jid
#      jlibname muc mynick roomjid
#      jlibname muc participants roomjid
#      jlibname muc setaffiliation roomjid nick affiliation ?-command, -reason?
#      jlibname muc setnick roomjid nick ?-command?
#      jlibname muc setrole roomjid nick role ?-command, -reason?
#      jlibname muc setroom roomjid type ?-command, -form?
#      
############################# CHANGES ##########################################
#
#       0.1         first version
#       0.2         rewritten as a standalone component
#       0.3         ensamble command
#       
# 050913 INCOMPATIBLE CHANGE! complete reorganization using ensamble command.

package require jlib
package require jlib::disco

package provide jlib::muc 0.3

namespace eval jlib::muc {
    
    # Globals same for all instances of this jlib.
    variable debug 0
    
    variable xmlns 
    array set xmlns {
	"muc"           "http://jabber.org/protocol/muc"
	"admin"         "http://jabber.org/protocol/muc#admin"
	"owner"         "http://jabber.org/protocol/muc#owner"
	"user"          "http://jabber.org/protocol/muc#user"
    }

    variable muc
    set muc(affiliationExp) {(owner|admin|member|outcast|none)}
    set muc(roleExp)        {(moderator|participant|visitor|none)}
    
    jlib::disco::registerfeature $xmlns(muc)
    
    # Note: jlib::ensamble_register is last in this file!
}

# jlib::muc::init --
# 
#       Creates a new instance of a muc object.
#       
# Arguments:
#       jlibname:     name of existing jabberlib instance; fully qualified!
#       args:        
# 
# Results:
#       namespaced instance command

proc jlib::muc::init {jlibname args} {
    
    Debug 2 "jlib::muc::init jlibname=$jlibname"
      
    # Instance specific namespace.
    namespace eval ${jlibname}::muc {
	variable cache
	variable rooms
    }
    upvar ${jlibname}::muc::cache cache
    upvar ${jlibname}::muc::rooms rooms
    
    # Register service.
    $jlibname service register muc muc
            
    return
}

# jlib::muc::cmdproc --
#
#       Just dispatches the command to the right procedure.
#
# Arguments:
#       jlibname    name of jabberlib instance.
#       cmd         the method.
#       args        all args to the cmd method.
#       
# Results:
#       from the individual command if any.

proc jlib::muc::cmdproc {jlibname cmd args} {
    
    # Which sub command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

# jlib::muc::invoke_callback --    ?????????????
# 
# 

proc jlib::muc::invoke_callback {mucname cmd type subiq} {

    uplevel #0 $cmd [list $mucname $type $subiq]
}

# jlib::muc::enter --
# 
#       Enter room.
#       
# Arguments:
#       jlibname    name of jabberlib instance.
#       roomjiid
#       nick        nick name
#       args        ?-command callbackProc?
#                   ?-extras list of xmllist?
#                   ?-password str?
#       
# Results:
#       none.

proc jlib::muc::enter {jlibname roomjid nick args} {

    variable xmlns
    upvar ${jlibname}::muc::cache cache
    upvar ${jlibname}::muc::rooms rooms
    
    set xsub {}
    set extras {}
    set cmd {}
    foreach {name value} $args {
	
	switch -- $name {
	    -command {
		set cmd $value
	    }
	    -extras {
		set extras $value
	    }
	    -password {
		set xsub [list [wrapper::createtag "password" \
		  -chdata $value]]
	    }
	    default {
		return -code error "Unrecognized option \"$name\""
	    }
	}
    }
    set jid $roomjid/$nick
    set xelem [wrapper::createtag "x" -subtags $xsub \
      -attrlist [list xmlns $xmlns(muc)]]
    $jlibname send_presence -to $jid -xlist [list $xelem] -extras $extras \
      -command [list [namespace current]::parse_enter $roomjid $cmd]
    set cache($roomjid,mynick) $nick
    set rooms($roomjid) 1
    $jlibname service setroomprotocol $roomjid "muc"
}

# jlib::muc::parse_enter --
# 
#       Callback when entering room to make sure there are no error.
# 
# Arguments:
#       jlibname 
#       type    presence typ attribute, 'available', 'error', etc.
#       args    -from, -id, -to, -x ...

proc jlib::muc::parse_enter {roomjid cmd jlibname type args} {

    upvar ${jlibname}::muc::cache cache

    if {[string equal $type "error"]} {
	unset -nocomplain cache($roomjid,mynick)
    } else {
	set cache($roomjid,inside) 1
    }
    if {$cmd ne ""} {
	uplevel #0 $cmd $jlibname $type $args
    }
}

# jlib::muc::exit --
# 
#       Exit room.

proc jlib::muc::exit {jlibname roomjid} {

    upvar ${jlibname}::muc::cache cache

    set rostername [$jlibname getrostername]
    if {[info exists cache($roomjid,mynick)]} {
	set jid $roomjid/$cache($roomjid,mynick)
	$jlibname send_presence -to $jid -type "unavailable"
	unset -nocomplain cache($roomjid,mynick)
    }
    unset -nocomplain cache($roomjid,inside)
    $rostername clearpresence "${roomjid}*"
}

# jlib::muc::setnick --
# 
#       Set new nick name for room.

proc jlib::muc::setnick {jlibname roomjid nick args} {

    upvar ${jlibname}::muc::cache cache
    
    set opts {}
    foreach {name value} $args {
	switch -- $name {
	    -command {
		lappend opts $name $value
	    }
	    default {
		return -code error "Unrecognized option \"$name\""
	    }
	}
    }
    set jid $roomjid/$nick
    eval {$jlibname send_presence -to $jid} $opts
    set cache($roomjid,mynick) $nick
}

# jlib::muc::invite --
# 
# 

proc jlib::muc::invite {jlibname roomjid jid args} {
    
    variable xmlns

    set opts {}
    set children {}
    foreach {name value} $args {
	switch -- $name {
	    -command {
		lappend opts $name $value
	    }
	    -reason {
		lappend children [wrapper::createtag  \
		  [string trimleft $name "-"] -chdata $value]
	    }
	    default {
		return -code error "Unrecognized option \"$name\""
	    }
	}
    }    
    set invite [list [wrapper::createtag "invite"  \
      -attrlist [list to $jid] -subtags $children]]
    
    set xelem [wrapper::createtag "x"     \
      -attrlist [list xmlns $xmlns(user)] \
      -subtags $invite]
    eval {$jlibname send_message $roomjid -xlist [list $xelem]} $opts
}

# jlib::muc::setrole --
# 
# 

proc jlib::muc::setrole {jlibname roomjid nick role args} {

    variable muc
    variable xmlns
    
    if {![regexp $muc(roleExp) $role]} {
	return -code error "Unrecognized role \"$role\""
    }
    set opts {}
    set subitem {}
    foreach {name value} $args {
	switch -- $name {
	    -command {
		lappend opts -command [concat $value $jlibname]
	    }
	    -reason {
		set subitem [list [wrapper::createtag "reason" -chdata $value]]
	    }
	    default {
		return -code error "Unrecognized option \"$name\""
	    }
	}
    }
    
    set subelements [list [wrapper::createtag "item"  \
      -attrlist [list nick $nick role $role]  \
      -subtags $subitem]]
    
    set xmllist [wrapper::createtag "query" \
      -attrlist [list xmlns $xmlns(admin)]  \
      -subtags $subelements]
    eval {$jlibname send_iq "set" [list $xmllist] -to $roomjid} $opts
}

# jlib::muc::setaffiliation --
# 
# 

proc jlib::muc::setaffiliation {jlibname roomjid nick affiliation args} {

    variable muc
    variable xmlns
    
    if {![regexp $muc(affiliationExp) $affiliation]} {
	return -code error "Unrecognized affiliation \"$affiliation\""
    }
    set opts {}
    set subitem {}
    foreach {name value} $args {
	switch -- $name {
	    -command {
		lappend opts -command [concat $value $jlibname]
	    }
	    -reason {
		set subitem [list [wrapper::createtag "reason" -chdata $value]]
	    }
	    default {
		return -code error "Unrecognized option \"$name\""
	    }
	}
    }

    switch -- $affiliation {
    	owner {
    	    set ns $xmlns(owner)
    	}
    	default {
    	    set ns $xmlns(admin)
    	}
    }
    
    set subelements [list [wrapper::createtag "item"  \
      -attrlist [list nick $nick affiliation $affiliation] \
      -subtags $subitem]]
    
    set xmllist [wrapper::createtag "query" \
      -attrlist [list xmlns $ns] -subtags $subelements]
    eval {$jlibname send_iq "set" [list $xmllist] -to $roomjid} $opts
}

# jlib::muc::getrole --
# 
# 

proc jlib::muc::getrole {jlibname roomjid role callback} {

    variable muc
    variable xmlns
    
    if {![regexp $muc(roleExp) $role]} {
	return -code error "Unrecognized role \"$role\""
    }
    set subelements [list [wrapper::createtag "item" \
      -attrlist [list role $role]]]
    
    set xmllist [wrapper::createtag "query" \
      -attrlist [list xmlns $xmlns(admin)]  \
      -subtags $subelements]
    $jlibname send_iq "get" [list $xmllist] -to $roomjid \
      -command [concat $callback $jlibname]
}

# jlib::muc::getaffiliation --
# 
# 

proc jlib::muc::getaffiliation {jlibname roomjid affiliation callback} {

    variable muc
    variable xmlns
    
    if {![regexp $muc(affiliationExp) $affiliation]} {
	return -code error "Unrecognized role \"$affiliation\""
    }
    set subelements [list [wrapper::createtag "item" \
      -attrlist [list affiliation $affiliation]]]

    switch -- $affiliation {
    	owner - admin {
    	    set ns $xmlns(owner)
    	}
    	default {
    	    set ns $xmlns(admin)
    	}
    }
    
    set xmllist [wrapper::createtag "query" \
      -attrlist [list xmlns $ns] -subtags $subelements]
    $jlibname send_iq "get" [list $xmllist] -to $roomjid \
      -command [concat $callback $jlibname]
}

# jlib::muc::create --
# 
#       The first thing to do when creating a room.
#       
# Arguments:
#       jlibname    name of jabberlib instance.
#       roomjiid
#       nick        nick name
#       command     callbackProc
#       args        ?-extras list of xmllist?
#       
# Results:
#       none.

proc jlib::muc::create {jlibname roomjid nick command args} {

    variable xmlns
    upvar ${jlibname}::muc::cache cache
    upvar ${jlibname}::muc::rooms rooms

    set extras {}
    foreach {name value} $args {
	
	switch -- $name {
	    -extras {
		set extras $value
	    }
	    default {
		return -code error "Unrecognized option \"$name\""
	    }
	}
    }
    set jid $roomjid/$nick
    set xelem [wrapper::createtag "x" -attrlist [list xmlns $xmlns(muc)]]
    $jlibname send_presence  \
      -to $jid  -xlist [list $xelem]  -extras $extras  \
      -command [list [namespace current]::parse_create $roomjid $command]
    set cache($roomjid,mynick) $nick
    set rooms($roomjid) 1
    $jlibname service setroomprotocol $roomjid "muc"
}

proc jlib::muc::parse_create {roomjid cmd jlibname type args} {

    upvar ${jlibname}::muc::cache cache

    if {[string equal $type "error"]} {
	unset -nocomplain cache($roomjid,mynick)
    } else {
	set cache($roomjid,inside) 1
    }
    if {$cmd ne ""} {
	uplevel #0 $cmd $jlibname $type $args
    }
}

# jlib::muc::setroom --
# 
#       Sends an iq set element to room. If -form the 'type' argument is
#       omitted.
#       
# Arguments:
#       jlibname     name of muc instance.
#       roomjid     the rooms jid.
#       type        typically 'submit' or 'cancel'.
#       args:        
#           -command 
#           -form   xmllist starting with the x-element
#       
# Results:
#       None.

proc jlib::muc::setroom {jlibname roomjid type args} {

    variable xmlns

    set opts {}
    set subelements {}
    foreach {name value} $args {
	switch -- $name {
	    -command {
		lappend opts -command [concat $value $jlibname]
	    }
	    -form {
		set xelem $value
	    }
	    default {
		return -code error "Unrecognized option \"$name\""
	    }
	}
    }
    if {[llength $xelem] == 0} {
	set xelem [list [wrapper::createtag "x"  \
	  -attrlist [list xmlns "jabber:x:data" type $type]]]
    }
    set xmllist [wrapper::createtag "query" -subtags $xelem \
      -attrlist [list xmlns $xmlns(owner)]]
    eval {$jlibname send_iq "set" [list $xmllist] -to $roomjid} $opts
}

# jlib::muc::destroy --
# 
# 
# Arguments:
#       jlibname     name of muc instance.
#       roomjid     the rooms jid.
#       args        -command, -reason, alternativejid.
#       
# Results:
#       None.

proc jlib::muc::destroy {jlibname roomjid args} {

    variable xmlns

    set opts {}
    set subelements {}
    foreach {name value} $args {
	
	switch -- $name {
	    -command {
		lappend opts -command [concat $value $jlibname]
	    }
	    -reason {
		lappend subelements [wrapper::createtag "reason" \
		  -chdata $value]
	    }
	    -alternativejid {
		lappend subelements [wrapper::createtag "alt" \
		  -attrlist [list jid $value]]
	    }
	    default {
		return -code error "Unrecognized option \"$name\""
	    }
	}
    }
      
    set destroyelem [wrapper::createtag "destroy" -subtags $subelements \
      -attrlist [list jid $roomjid]]

    set xmllist [wrapper::createtag "query" -subtags [list $destroyelem] \
      -attrlist [list xmlns $xmlns(owner)]]
    eval {$jlibname send_iq "set" [list $xmllist] -to $roomjid} $opts
}

# jlib::muc::getroom --
# 
# 

proc jlib::muc::getroom {jlibname roomjid callback} {

    variable xmlns

    set xmllist [wrapper::createtag "query" \
      -attrlist [list xmlns $xmlns(owner)]]
    $jlibname send_iq "get" [list $xmllist] -to $roomjid  \
      -command [concat $callback $jlibname]
}

# jlib::muc::mynick --
# 
#       Returns own nick name for room, or empty if not there.

proc jlib::muc::mynick {jlibname roomjid} {

    upvar ${jlibname}::muc::cache cache
    
    if {[info exists cache($roomjid,mynick)]} {
	return $cache($roomjid,mynick)
    } else {
	return
    }
}

# jlib::muc::allroomsin --
# 
#       Returns a list of all room jid's we are inside.

proc jlib::muc::allroomsin {jlibname} {

    upvar ${jlibname}::muc::cache cache
    
    set roomList {}
    foreach key [array names cache "*,inside"] {
	regexp {(.+),inside} $key match room
	lappend roomList $room
    }
    return $roomList
}

proc jlib::muc::isroom {jlibname jid} {
    
    upvar ${jlibname}::muc::rooms rooms
    
    if {[info exists rooms($jid)]} {
	return 1
    } else {
	return 0
    }
}

# jlib::muc::participants --
#
#

proc jlib::muc::participants {jlibname roomjid} {

    upvar ${jlibname}::muc::cache cache
    
    set rostername [[namespace parent]::getrostername $jlibname]
    set everyone {}

    # The rosters presence elements should give us all info we need.
    foreach userAttr [$rostername getpresence $roomjid -type available] {
	unset -nocomplain attr
	array set attr $userAttr
	lappend everyone $roomjid/$attr(-resource)
    }
    return $everyone
}

proc jlib::muc::Debug {num str} {
    variable debug
    if {$num <= $debug} {
	puts $str
    }
}

# We have to do it here since need the initProc before doing this.

namespace eval jlib::muc {
    
    jlib::ensamble_register muc    \
      [namespace current]::init    \
      [namespace current]::cmdproc
}

#-------------------------------------------------------------------------------

