#  muc.tcl --
#  
#      This file is part of the whiteboard application and jabberlib.
#      It implements the Multi User Chat (MUC) protocol part of the XMPP
#      protocol as defined by the 'http://jabber.org/protocol/muc*'
#      namespace.
#      
#  Copyright (c) 2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#
# $Id: muc.tcl,v 1.1 2003-01-30 17:22:37 matben Exp $
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
#      jlibName muc enter roomjid nick ?-command?
#      jlibName muc exit roomjid nick
#      jlibName muc setnick roomjid nick ?-command?
#      jlibName muc invite roomjid jid ?-reason?
#      jlibName muc setrole roomjid nick role ?-command, -reason?
#      jlibName muc setaffilation roomjid nick affilation ?-command, -reason?
#      jlibName muc getrole roomjid role callback
#      jlibName muc getaffilation roomjid affilation callback
#      jlibName muc create roomjid nick callback
#      jlibName muc setroom roomjid type ?-command, -form?
#      jlibName muc getroom roomjid callback
#      jlibName muc mynick roomjid
#      jlibName muc allroomsin
#      
############################# CHANGES ##########################################
#
#       0.1         first version

package provide muc 0.1

namespace eval jlib::muc {
    
    # Globals same for all instances of this jlib.
    #    > 1 prints raw xml I/O
    #    > 2 prints a lot more
    variable debug 2
    
    variable muc
    set muc(affilationExp) {(owner|admin|member|outcast|none)}
    set muc(roleExp) {(moderator|participant|visitor|none)}
}

proc jlib::muc::Debug {num str} {
    variable debug
    if {$num <= $debug} {
	puts $str
    }
}
  
# jlib::muc::CommandProc --
#
#       Just dispatches the command to the right procedure.
#
# Arguments:
#       jlibName    name of jabberlib instance.
#       cmd         the method.
#       args        all args to the cmd method.
#       
# Results:
#       from the individual command if any.

proc jlib::muc::CommandProc {jlibName cmd args} {
    
    # Which sub command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibName} $args]
}

# jlib::muc::enter --
# 
# 
# Arguments:
#       jlibName    name of jabberlib instance.
#       roomjiid
#       nick        nick name
#       args        ?-command callbackProc?
#       
# Results:
#       none.

proc jlib::muc::enter {jlibName roomjid nick args} {
    upvar [namespace current]::${jlibName}::cache cache    
    
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
    set jid "${roomjid}/${nick}"
    set xelem [wrapper::createtag "x"  \
      -attrlist {xmlns "http://jabber.org/protocol/muc"}]
    eval {[namespace parent]::send_presence $jlibName -to $jid  \
      -xlist [list $xelem]} $opts
    set cache($roomjid,mynick) $nick
}

# jlib::muc::exit --
# 
# 

proc jlib::muc::exit {jlibName roomjid nick} {
    
    set jid "${roomjid}/${nick}"
    [namespace parent]::send_presence $jlibName -to $jid -type "unavailable"
    catch {unset muc($roomjid,mynick)}
}

# jlib::muc::setnick --
# 
# 

proc jlib::muc::setnick {jlibName roomjid nick args} {
    
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
    set jid "${roomjid}/${nick}"
    eval {[namespace parent]::send_presence $jlibName -to $jid} $opts
}

# jlib::muc::invite --
# 
# 

proc jlib::muc::invite {jlibName roomjid jid args} {
    
    set children {}
    foreach {name value} $args {
	switch -- $name {
	    -reason {
		lappend children [wrapper::createtag  \
		  [string trimleft $name "-"] -chdata $value]
	    }
	    default {
		return -code error "Unrecognized option \"$name\""
	    }
	}
    }    
    set invite [list \
      [wrapper::createtag "invite" -attrlist [list to $jid] -subtags $children]]
    
    set xelem [wrapper::createtag "x" -subtags $invite  \
      -attrlist {xmlns "http://jabber.org/protocol/muc#user"}]
    [namespace parent]::send_message $jlibName $roomjid  \
      -xlist [list $xelem]
}

# jlib::muc::setrole --
# 
# 

proc jlib::muc::setrole {jlibName roomjid nick role args} {
    variable muc
    
    if {![regexp $muc(roleExp) $role]} {
	return -code error "Unrecognized role \"$role\""
    }
    set opts {}
    set subitem {}
    foreach {name value} $args {
	switch -- $name {
	    -command {
		lappend opts $name $value
	    }
	    -reason {
		set subitem [list [wrapper::createtag "reason" -chdata $value]]
	    }
	    default {
		return -code error "Unrecognized option \"$name\""
	    }
	}
    }
    
    set subelements [list [wrapper::createtag "item" -subtags $subitem \
      -attrlist [list nick $nick role $role]]]
    
    set xmllist [wrapper::createtag "query" \
      -attrlist {xmlns "http://jabber.org/protocol/muc#admin"} \
      -subtags $subelements]
    eval {[namespace parent]::send_iq $jlibName "set" $xmllist -to $roomjid} \
      $opts
}

# jlib::muc::setaffilation --
# 
# 

proc jlib::muc::setaffilation {jlibName roomjid nick affilation args} {
    variable muc
    
    if {![regexp $muc(affilationExp) $affilation]} {
	return -code error "Unrecognized affilation \"$affilation\""
    }
    set opts {}
    set subitem {}
    foreach {name value} $args {
	switch -- $name {
	    -command {
		lappend opts $name $value
	    }
	    -reason {
		set subitem [list [wrapper::createtag "reason" -chdata $value]]
	    }
	    default {
		return -code error "Unrecognized option \"$name\""
	    }
	}
    }
    
    set subelements [list [wrapper::createtag "item" -subtags $subitem \
      -attrlist [list nick $nick affilation $affilation]]]
    
    set xmllist [wrapper::createtag "query" \
      -attrlist {xmlns "http://jabber.org/protocol/muc#admin"} \
      -subtags $subelements]
    eval {[namespace parent]::send_iq $jlibName "set" $xmllist -to $roomjid} \
      $opts
}

# jlib::muc::getrole --
# 
# 

proc jlib::muc::getrole {jlibName roomjid role callback} {
    variable muc
    
    if {![regexp $muc(roleExp) $role]} {
	return -code error "Unrecognized role \"$role\""
    }
    set subelements [list [wrapper::createtag "item" \
      -attrlist [list role $role]]]
    
    set xmllist [wrapper::createtag "query" -subtags $subelements \
      -attrlist {xmlns "http://jabber.org/protocol/muc#admin"}]
    [namespace parent]::send_iq $jlibName "get" $xmllist -to $roomjid \
      -command $callback
}

# jlib::muc::getaffilation --
# 
# 

proc jlib::muc::getaffilation {jlibName roomjid affilation callback} {
    variable muc
    
    if {![regexp $muc(affilationExp) $affilation]} {
	return -code error "Unrecognized role \"$affilation\""
    }
    set subelements [list [wrapper::createtag "item" \
      -attrlist [list affilation $affilation]]]
    
    set xmllist [wrapper::createtag "query" -subtags $subelements \
      -attrlist {xmlns "http://jabber.org/protocol/muc#admin"}]
    [namespace parent]::send_iq $jlibName "get" $xmllist -to $roomjid \
      -command $callback
}

# jlib::muc::create --
# 
# 

proc jlib::muc::create {jlibName roomjid nick callback} {

    set jid "${roomjid}/${nick}"
    set xelem [wrapper::createtag "x"  \
      -attrlist {xmlns "http://jabber.org/protocol/muc"}]
    [namespace parent]::send_presence $jlibName -to $jid  \
      -xlist [list $xelem] -command $callback
}

# jlib::muc::setroom --
# 
# 

proc jlib::muc::setroom {jlibName roomjid type args} {

    set opts {}
    set subelements {}
    foreach {name value} $args {
	switch -- $name {
	    -command {
		lappend opts $name $value
	    }
	    -form {
		set subelements $value
	    }
	    default {
		return -code error "Unrecognized option \"$name\""
	    }
	}
    }
    set xelem [list [wrapper::createtag "x"  \
      -attrlist [list xmlns "jabber:x:data" type $type]  \
      -subtags $subelements]]
    set xmllist [wrapper::createtag "query" -subtags $xelem \
      -attrlist {xmlns "http://jabber.org/protocol/muc#owner"}]
    eval {[namespace parent]::send_iq $jlibName "set" $xmllist -to $roomjid} \
      $opts
}

# jlib::muc::getroom --
# 
# 

proc jlib::muc::getroom {jlibName roomjid callback} {

    set xmllist [wrapper::createtag "query"  \
      -attrlist {xmlns "http://jabber.org/protocol/muc#owner"}]
    [namespace parent]::send_iq $jlibName "set" $xmllist -to $roomjid  \
      -command $callback
}

# jlib::muc::mynick --
# 
#       Returns own nick name for room, or empty if not there.

proc jlib::muc::mynick {jlibName roomjid} {
    upvar [namespace current]::${jlibName}::cache cache    
    
    if {[info exists cache($roomjid,mynick)]} {
	return $cache($roomjid,mynick)
    } else {
	return ""
    }
}

# jlib::muc::allroomsin --
# 
#       Returns a list of all room jid's we are inside.

proc jlib::muc::allroomsin {jlibName} {
    upvar [namespace current]::${jlibName}::cache cache    
    
    set keyList [array names cache "*,mynick"]
    set roomList {}
    foreach key $keyList {
	regexp {(.+),mynick} $key match room
	lappend roomList $room
    }
    return $roomList
}

#-------------------------------------------------------------------------------

