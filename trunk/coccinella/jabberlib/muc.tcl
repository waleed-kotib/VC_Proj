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
# $Id: muc.tcl,v 1.7 2003-06-07 12:46:36 matben Exp $
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
#      jlibName muc allroomsin
#      jlibName muc create roomjid nick callback
#      jlibName muc destroy roomjid ?-command, -reason, alternativejid?
#      jlibName muc enter roomjid nick ?-command?
#      jlibName muc exit roomjid
#      jlibName muc getaffiliation roomjid affiliation callback
#      jlibName muc getrole roomjid role callback
#      jlibName muc getroom roomjid callback
#      jlibName muc invite roomjid jid ?-reason?
#      jlibName muc mynick roomjid
#      jlibName muc participants roomjid
#      jlibName muc setaffiliation roomjid nick affiliation ?-command, -reason?
#      jlibName muc setnick roomjid nick ?-command?
#      jlibName muc setrole roomjid nick role ?-command, -reason?
#      jlibName muc setroom roomjid type ?-command, -form?
#      
############################# CHANGES ##########################################
#
#       0.1         first version

package provide muc 0.1

namespace eval jlib::muc {
    
    # Globals same for all instances of this jlib.
    variable debug 0
    
    variable muc
    set muc(affiliationExp) {(owner|admin|member|outcast|none)}
    set muc(roleExp) {(moderator|participant|visitor|none)}
}
  
# jlib::muc::CommandProc --
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

proc jlib::muc::CommandProc {jlibname cmd args} {
    
    # Which sub command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

# jlib::muc::enter --
# 
# 
# Arguments:
#       jlibname    name of jabberlib instance.
#       roomjiid
#       nick        nick name
#       args        ?-command callbackProc?
#       
# Results:
#       none.

proc jlib::muc::enter {jlibname roomjid nick args} {
    upvar [namespace current]::${jlibname}::cache cache    
    
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
    set jid ${roomjid}/${nick}
    set xelem [wrapper::createtag "x"  \
      -attrlist {xmlns "http://jabber.org/protocol/muc"}]
    eval {[namespace parent]::send_presence $jlibname -to $jid  \
      -xlist [list $xelem]} $opts
    set cache($roomjid,mynick) $nick
}

# jlib::muc::exit --
# 
# 

proc jlib::muc::exit {jlibname roomjid} {
    upvar [namespace current]::${jlibname}::cache cache    
    upvar [namespace parent]::${jlibname}::lib lib
    
    if {[info exists cache($roomjid,mynick)]} {
	set jid ${roomjid}/$cache($roomjid,mynick)
	[namespace parent]::send_presence $jlibname -to $jid -type "unavailable"
	catch {unset cache($roomjid,mynick)}
    }
    $lib(rostername) clearpresence "${roomjid}*"
}

# jlib::muc::setnick --
# 
# 

proc jlib::muc::setnick {jlibname roomjid nick args} {
    upvar [namespace current]::${jlibname}::cache cache    
    
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
    set jid ${roomjid}/${nick}
    eval {[namespace parent]::send_presence $jlibname -to $jid} $opts
    set cache($roomjid,mynick) $nick
}

# jlib::muc::invite --
# 
# 

proc jlib::muc::invite {jlibname roomjid jid args} {
    
    set opts {}
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
    [namespace parent]::send_message $jlibname $roomjid  \
      -xlist [list $xelem]
}

# jlib::muc::setrole --
# 
# 

proc jlib::muc::setrole {jlibname roomjid nick role args} {
    variable muc
    
    if {![regexp $muc(roleExp) $role]} {
	return -code error "Unrecognized role \"$role\""
    }
    set opts {}
    set subitem {}
    foreach {name value} $args {
	switch -- $name {
	    -command {
		lappend opts -command  \
		  [list [namespace parent]::parse_iq_response $jlibname $value]
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
    eval {[namespace parent]::send_iq $jlibname "set" $xmllist -to $roomjid} \
      $opts
}

# jlib::muc::setaffiliation --
# 
# 

proc jlib::muc::setaffiliation {jlibname roomjid nick affiliation args} {
    variable muc
    
    if {![regexp $muc(affiliationExp) $affiliation]} {
	return -code error "Unrecognized affiliation \"$affiliation\""
    }
    set opts {}
    set subitem {}
    foreach {name value} $args {
	switch -- $name {
	    -command {
		lappend opts -command  \
		  [list [namespace parent]::parse_iq_response $jlibname $value]
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
    	    set xmlns "http://jabber.org/protocol/muc#owner"
    	}
    	default {
    	    set xmlns "http://jabber.org/protocol/muc#admin"
    	}
    }
    
    set subelements [list [wrapper::createtag "item" -subtags $subitem \
      -attrlist [list nick $nick affiliation $affiliation]]]
    
    set xmllist [wrapper::createtag "query" \
      -attrlist [list xmlns $xmlns] -subtags $subelements]
    eval {[namespace parent]::send_iq $jlibname "set" $xmllist -to $roomjid} \
      $opts
}

# jlib::muc::getrole --
# 
# 

proc jlib::muc::getrole {jlibname roomjid role callback} {
    variable muc
    
    if {![regexp $muc(roleExp) $role]} {
	return -code error "Unrecognized role \"$role\""
    }
    set subelements [list [wrapper::createtag "item" \
      -attrlist [list role $role]]]
    
    set xmllist [wrapper::createtag "query" -subtags $subelements \
      -attrlist {xmlns "http://jabber.org/protocol/muc#admin"}]
    [namespace parent]::send_iq $jlibname "get" $xmllist -to $roomjid \
      -command [list [namespace parent]::parse_iq_response $jlibname $callback]
}

# jlib::muc::getaffiliation --
# 
# 

proc jlib::muc::getaffiliation {jlibname roomjid affiliation callback} {
    variable muc
    
    if {![regexp $muc(affiliationExp) $affiliation]} {
	return -code error "Unrecognized role \"$affiliation\""
    }
    set subelements [list [wrapper::createtag "item" \
      -attrlist [list affiliation $affiliation]]]
    switch -- $affiliation {
    	owner - admin {
    	    set xmlns "http://jabber.org/protocol/muc#owner"
    	}
    	default {
    	    set xmlns "http://jabber.org/protocol/muc#admin"
    	}
    }
    
    set xmllist [wrapper::createtag "query" -subtags $subelements \
      -attrlist [list xmlns $xmlns]]
    [namespace parent]::send_iq $jlibname "get" $xmllist -to $roomjid \
      -command [list [namespace parent]::parse_iq_response $jlibname $callback]
}

# jlib::muc::create --
# 
#       The first thing to do when creating a room.

proc jlib::muc::create {jlibname roomjid nick callback} {
    upvar [namespace current]::${jlibname}::cache cache    

    set jid ${roomjid}/${nick}
    set xelem [wrapper::createtag "x"  \
      -attrlist {xmlns "http://jabber.org/protocol/muc"}]
    [namespace parent]::send_presence $jlibname -to $jid  \
      -xlist [list $xelem] -command $callback
    set cache($roomjid,mynick) $nick
}

# jlib::muc::setroom --
# 
# 
# Arguments:
#       jlibname    name of jabberlib instance.
#       roomjid     the rooms jid.
#       type        typically 'form'.
#       args        -command, -form.
#       
# Results:
#       None.

proc jlib::muc::setroom {jlibname roomjid type args} {

    set opts {}
    set subelements {}
    foreach {name value} $args {
	switch -- $name {
	    -command {
		lappend opts -command  \
		  [list [namespace parent]::parse_iq_response $jlibname $value]
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
    eval {[namespace parent]::send_iq $jlibname "set" $xmllist -to $roomjid} \
      $opts
}

# jlib::muc::destroy --
# 
# 
# Arguments:
#       jlibname    name of jabberlib instance.
#       roomjid     the rooms jid.
#       args        -command, -reason, alternativejid.
#       
# Results:
#       None.

proc jlib::muc::destroy {jlibname roomjid args} {

    set opts {}
    set subelements {}
    foreach {name value} $args {
	switch -- $name {
	    -command {
		lappend opts -command  \
		  [list [namespace parent]::parse_iq_response $jlibname $value]
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
      -attrlist {xmlns "http://jabber.org/protocol/muc#owner"}]
    eval {[namespace parent]::send_iq $jlibname "set" $xmllist -to $roomjid} \
      $opts
}

#<iq
#    type='set'
#    from='crone1@shakespeare.lit/desktop'
#    to='heath@macbeth.shakespeare.lit'
#    id='begone'>
#  <query xmlns='http://jabber.org/protocol/muc#owner'>
#    <destroy jid='darkcave@macbeth.shakespeare.lit'>
#      <reason>Macbeth doth come.</reason>
#    </destroy>
#  </query>
#</iq>


# jlib::muc::getroom --
# 
# 

proc jlib::muc::getroom {jlibname roomjid callback} {

    set xmllist [wrapper::createtag "query"  \
      -attrlist {xmlns "http://jabber.org/protocol/muc#owner"}]
    [namespace parent]::send_iq $jlibname "get" $xmllist -to $roomjid  \
      -command [list [namespace parent]::parse_iq_response $jlibname $callback]
}

# jlib::muc::mynick --
# 
#       Returns own nick name for room, or empty if not there.

proc jlib::muc::mynick {jlibname roomjid} {
    upvar [namespace current]::${jlibname}::cache cache    
    
    if {[info exists cache($roomjid,mynick)]} {
	return $cache($roomjid,mynick)
    } else {
	return ""
    }
}

# jlib::muc::allroomsin --
# 
#       Returns a list of all room jid's we are inside.

proc jlib::muc::allroomsin {jlibname} {
    upvar [namespace current]::${jlibname}::cache cache    
    
    set keyList [array names cache "*,mynick"]
    set roomList {}
    foreach key $keyList {
	regexp {(.+),mynick} $key match room
	lappend roomList $room
    }
    return $roomList
}

# jlib::muc::participants --
#
#

proc jlib::muc::participants {jlibname roomjid} {
    upvar [namespace parent]::${jlibname}::lib lib
    
    set everyone {}

    # The rosters presence elements should give us all info we need.
    foreach userAttr [$lib(rostername) getpresence $roomjid -type available] {
	catch {unset attrArr}
	array set attrArr $userAttr
	lappend everyone ${roomjid}/$attrArr(-resource)
    }
    return $everyone
}

proc jlib::muc::Debug {num str} {
    variable debug
    if {$num <= $debug} {
	puts $str
    }
}

#-------------------------------------------------------------------------------

