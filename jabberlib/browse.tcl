#  browse.tcl ---
#  
#      This file is part of the whiteboard application. 
#      It maintains the current state of all 'jid-types' for each server.
#      In other words, it manages the client's internal state corresponding
#      to 'iq' elements with namespace 'jabber:iq:browse'.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: browse.tcl,v 1.3 2003-01-30 17:33:47 matben Exp $
# 
#  locals($jid,parent):       the parent of $jid.
#  locals($jid,parents):      list of all parent jid's,
#                             {server conference.server myroom@conference.server}
#  locals($jid,childs):       list of all childs of this jid if any.                             
#  locals($jid,xmllist):      the hierarchical xml list of this $jid.
#  locals($jid,type):         the type/subtype of this $jid.
#  locals($type,typelist):    a list of jid's for this type/subtype.
#  locals(alltypes):          a list of all jid types.
#  locals($jid,allusers):     list of all users in room $jid.
#  locals($jid,isbrowsed):    1 if $jid browsed, 0 if not.
#
############################# USAGE ############################################
#
#       Changes to the state of this object should only be made from jabberlib,
#       and never directly by the client!
#       All jid's must be browsed hierarchically, that is, when browsing
#       'myroom@conference.server', 'conference.server' must have already been 
#       browsed, and browsing 'conference.server' requires 'server' to have
#       been browsed.
#
#   NAME
#      browse - an object for the ...
#   SYNOPSIS
#      browse::browse browseName clientCommand
#   OPTIONS
#      none
#   INSTANCE COMMANDS
#      browseName clear ?jid?
#      browseName delete
#      browseName errorcallback jid xmllist ?-errorcommand?
#      browseName get jid
#      browseName getchilds jid
#      browseName getconferenceservers
#      browseName getname jid
#      browseName getnamespaces jid
#      browseName getservicesforns ns
#      browseName getparentjid jid
#      browseName getparents jid
#      browseName gettype jid
#      browseName getalltypes globpattern
#      browseName getalljidfortypes globpattern
#      browseName getusers jid
#      browseName isbrowsed jid
#      browseName isroom jid
#      browseName remove jid
#      browseName setjid jid xmllist
#
#   The 'clientCommand' procedure must have the following form:
#   
#      clientCommand {browseName type jid xmllist}
#      
#   where 'type' can be 'set' or 'remove'.
#      
############################# CHANGES ##########################################
#

package require wrapper

package provide browse 1.0

namespace eval browse {
    
    # The internal storage.
    variable browseGlobals
    
    # Globals same for all instances of all rooms.
    set browseGlobals(debug) 0
    
    # Options only for internal use. EXPERIMENTAL!
    #     -setbrowsedjid:  default=1, store the browsed jid even if cached already
    variable options
    array set options {
	-setbrowsedjid 1
    }
}	

proc browse::Debug {num str} {
    variable browseGlobals
    if {$num <= $browseGlobals(debug)} {
	puts $str
    }
}

# browse::browse --
#
#       This creates a new instance of a browse object.
#       
# Arguments:
#       browseName:   the name of this jlib instance
#       clientCmd:  callback procedure when internals of browse changes.
#       args:            
#       
# Results:
#       browseName
  
proc browse::browse {browseName clientCmd args} {
    
    # Check that we may have a command [browseName].
    if {[llength [info commands $browseName]] > 0} {
	error commandinuse   \
	  "\"$browseName\" command is already in use"
    }
      
    # Instance specific namespace.
    namespace eval [namespace current]::${browseName} {
	variable locals
    }
    
    # Set simpler variable names.
    upvar [namespace current]::${browseName}::locals locals
        
    # Use the hashed jid as a key for user specific storage.
    set locals(cmd) $clientCmd
    set locals(confservers) {}
    
    # Create the actual browser instance procedure. 'browseName' is interpreted 
    # in the global namespace.
    # Perhaps need to check if 'browseName' is already a fully qualified name?
    proc ::${browseName} {cmd args}   \
      "eval browse::CommandProc {$browseName} \$cmd \$args"
    
    return $browseName
}

# browse::CommandProc --
#
#       Just dispatches the command to the right procedure.
#
# Arguments:
#       browseName:   the instance of this conference browse.
#       cmd:        the method.
#       args:       all args to the cmd method.
#       
# Results:
#       none.

proc browse::CommandProc {browseName cmd args} {
    
    Debug 5 "browse::CommandProc browseName=$browseName, cmd='$cmd', args='$args'"
    
    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $browseName} $args]
}

# browse::getparentjid --
#
#       Returns the logical parent of a jid. 
#       'matben@ayhkdws.se/home' => 'matben@ayhkdws.se' etc.
#       
# Arguments:
#       jid     the three-tier jid
#       
# Results:
#       another jid or empty if failed

proc browse::getparentjid {browseName jid} {
    
    upvar [namespace current]::${browseName}::locals locals

    if {[info exists locals($jid,parent)]} {
	set parJid $locals($jid,parent)
    } else {
	
	# Only to make it failsafe. DANGER!!!
	set parJid [GetParentJidFromJid $browseName $jid]
    }
    return $parJid
}

# This is not good...   DANGER!!!

proc browse::GetParentJidFromJid {browseName jid} {
    
    upvar [namespace current]::${browseName}::locals locals
    
    Debug 3 "GetParentJidFromJid BAD!!!  jid=$jid"

    set c {[^@/.<>:]+}
    if {[regexp "(${c}@(${c}\.)+${c})/${c}" $jid match parJid junk]} {	
    } elseif {[regexp "${c}@((${c}\.)+${c})" $jid match parJid junk]} {
    } elseif {[regexp "${c}\.((${c}\.)*${c})" $jid match parJid junk]} {
    } else {
	set parJid {}
    }
    return $parJid
}

# browse::get --
#
# Arguments:
#       browseName:   the instance of this conference browse.
#
# Results:
#       Hierarchical xmllist if already browsed or empty if not browsed.

proc browse::get {browseName jid} {
    upvar [namespace current]::${browseName}::locals locals
    
    Debug 3 "browse::get  jid=$jid"
    
    if {[info exists locals($jid,xmllist)]} {
	return $locals($jid,xmllist)
    } else {
	return {}
    }
}

proc browse::isbrowsed {browseName jid} {
    upvar [namespace current]::${browseName}::locals locals
    
    Debug 3 "browse::isbrowsed  jid=$jid"
    
    if {[info exists locals($jid,isbrowsed)] && ($locals($jid,isbrowsed) == 1)} {
	return 1
    } else {
	return 0
    }
}
    
# browse::remove --
#
#
# Arguments:
#       browseName:   the instance of this browse.
#       jid:          jid to remove.
#
# Results:
#       none.

proc browse::remove {browseName jid} {
    upvar [namespace current]::${browseName}::locals locals
    
    Debug 3 "browse::remove  jid=$jid"
    
    catch {unset locals($jid,parents)}
    catch {unset locals($jid,xmllist)}
    catch {unset locals($jid,isbrowsed)}

    # Evaluate the client callback.
    uplevel #0 "$locals(cmd) $browseName remove $jid"
}
    
# browse::getparents --
#
#
# Arguments:
#       browseName:   the instance of this browse.
#
# Results:
#       List of all parent jid's.

proc browse::getparents {browseName jid} {
    upvar [namespace current]::${browseName}::locals locals
    
    Debug 3 "browse::getparents  jid=$jid"
    
    if {[info exists locals($jid,parents)]} {
	return $locals($jid,parents)
    } else {
	return {}
    }
}
    
# browse::getchilds --
#
#
# Arguments:
#       browseName:   the instance of this browse.
#
# Results:
#       List of all parent jid's.

proc browse::getchilds {browseName jid} {
    upvar [namespace current]::${browseName}::locals locals
    
    Debug 3 "browse::getchilds  jid=$jid"
    
    if {[info exists locals($jid,childs)]} {
	return $locals($jid,childs)
    } else {
	return {}
    }
}
    
# browse::getname --
#
#       Returns the nickname of a jid in conferencing, or the rooms name
#       if jid is a room.
#
# Arguments:
#       browseName:   the instance of this conference browse.
#       
# Results:
#       The nick, room name or empty if undefined.

proc browse::getname {browseName jid} {
    upvar [namespace current]::${browseName}::locals locals
    
    Debug 3 "browse::getname  jid=$jid"
    
    if {[info exists locals($jid,name)]} {
	return $locals($jid,name)
    } else {
	return {}
    }
}
    
# browse::getusers --
#
#       Returns all users of a room jid in conferencing.
#
# Arguments:
#       browseName:   the instance of this conference browse.
#       jid:          must be a room jid: 'roomname@server'.
#       
# Results:
#       The nick name or empty if undefined.

proc browse::getusers {browseName jid} {
    upvar [namespace current]::${browseName}::locals locals
    
    Debug 3 "browse::getusers  jid=$jid"
    
    if {[info exists locals($jid,allusers)]} {
	return $locals($jid,allusers)
    } else {
	return {}
    }
}
    
# browse::getconferenceservers --
#
#

proc browse::getconferenceservers {browseName} {
    
    upvar [namespace current]::${browseName}::locals locals
    
    return $locals(confservers)
}    
    
# browse::getservicesforns --
#
#       Gets all jid's that support a certain namespace.
#       Only for the browsed services.

proc browse::getservicesforns {browseName ns} {
    
    upvar [namespace current]::${browseName}::locals locals
    
    if {[info exists locals(ns,$ns)]} {
	return $locals(ns,$ns)
    } else {
	return {}
    }
}

# browse::isroom --
#
#       If 'jid' is a child of a conference server, that is, a room.

proc browse::isroom {browseName jid} {
    
    upvar [namespace current]::${browseName}::locals locals
    
    #puts ">>>>>>>> browse::isroom jid=$jid"
    set parentJid [getparentjid $browseName $jid]

    # Check if this is in our list of conference servers.
    set ind [lsearch -exact $locals(confservers) $parentJid]
    return [expr ($ind < 0) ? 0 : 1]
}    
    
# browse::gettype --
#
#       Returns the jidType/subType if found.

proc browse::gettype {browseName jid} {
    
    upvar [namespace current]::${browseName}::locals locals
    
    if {[info exists locals($jid,type)]} {
	return $locals($jid,type)
    } else {
	return {}
    }
}    

# browse::getalljidfortypes --
#
#       Returns all jids that match the glob pattern typepattern.
#       
# Arguments:
#       browseName:   the instance of this conference browse.
#       typepattern:  a globa pattern of jid type/subtype (service/*).
#
# Results:
#       List of jid's matching the type pattern.

proc browse::getalljidfortypes {browseName typepattern} {
    
    upvar [namespace current]::${browseName}::locals locals
    
    set allkeys [array names locals "$typepattern,typelist"]
    set jidlist {}
    
    # Need eval here to flatten the jidlist.
    foreach key $allkeys {
	set locals($key) [lsort -unique $locals($key)]
	eval {lappend jidlist} $locals($key)
    }
    return $jidlist
}    

# browse::getalltypes --
#
#       Returns all types that match the glob pattern typepattern.
#       
# Arguments:
#       browseName:   the instance of this conference browse.
#       typepattern:  a globa pattern of jid type/subtype (service/*).
#
# Results:
#       List of types matching the type pattern.

proc browse::getalltypes {browseName typepattern} {
    
    upvar [namespace current]::${browseName}::locals locals
    
    set ans {}
    if {[info exists locals(alltypes)]} {
	set locals(alltypes) [lsort -unique $locals(alltypes)]
	foreach type $locals(alltypes) {
	    if {[string match $typepattern $type]} {
		lappend ans $type
	    }
	}
    }
    return $ans
}    

# browse::getnamespaces --
#
#       Returns all namespaces for this jid describing the services available.
#
# Arguments:
#       browseName:   the instance of this conference browse.
#       jid:          .
#       
# Results:
#       List of namespaces or empty if none.

proc browse::getnamespaces {browseName jid} {
    upvar [namespace current]::${browseName}::locals locals
    
    Debug 3 "browse::getnamespaces  jid=$jid"

    if {[info exists locals($jid,ns)]} {
	return $locals($jid,ns)
    } else {
	return {}
    }
}

# browse::setjid --
#
#       Called when receiving a 'set' or 'result' iq element in jabber:iq:browse
#       Shall only be called from jabberlib" 
#       Sets internal state, and makes callback to client proc. 
#       Could be called with type='remove' attribute.
#       For 'user' elements we need to build a table that maps the
#       'roomname@server/hexname' with the nick name.
#       It also keeps a list of all 'user'«s in a room.
#       
# Arguments:
#       browseName:   the instance of this conference browse.
#       fromJid:      the 'from' attribute which is also the parent of any
#                     childs.
#       subiq:      hierarchical xml list starting with element containing
#                     the xmlns='jabber:iq:browse' attribute.
#                     Any children defines a parent-child relation.
#       args:       -command cmdProc:   replaces the client callback command
#                        in the browse object
#       
# Results:
#       none.

proc browse::setjid {browseName fromJid subiq args} {
    upvar [namespace current]::${browseName}::locals locals
    
    Debug 3 "browse::setjid browseName=$browseName, fromJid=$fromJid\
      subiq='[string range $subiq 0 40]...', args='$args'"

    set theTag [lindex $subiq 0]
    array set attr [lindex $subiq 1]
    array set argsArr $args
    
    # Root parent empty. A bit unclear what to do with it.
    if {![info exists locals($fromJid,parent)]} {
	
	# This can be a completely new room not seen before.
	#if {[string match *@* $fromJid]}
	if {0} {
	    set parentJid [getparentjid $browseName $fromJid]
	    set locals($fromJid,parent) $parentJid
	    set locals($fromJid,parents)  \
	      [concat $locals($parentJid,parents) $parentJid]
	} else {
	
	    # Else we assume it is a root. Not correct!
	    set locals($fromJid,parent) {}
	    set locals($fromJid,parents) {}
	    set parentJid {}
	}
    }
    
    # Docs say that jid is required attribute but... 
    # <conference> and <service> seem to lack jid.
    # If no jid attribute it is probably(?) assumed to be 'fromJid.
    if {![info exists attr(jid)]} {
	set jid $fromJid
	set parentJid $locals($jid,parent)
    } else {
	set jid $attr(jid)
	if {$fromJid != $jid} {
	    set parentJid $fromJid
	} else {
	    set parentJid $locals($jid,parent)
	}
    }
    set locals($jid,isbrowsed) 1
    
    # Handle the top jid, and follow recursively for any childs.
    setsinglejid $browseName $parentJid $jid $subiq 1
    
    # Evaluate the client callback.
    if {[info exists argsArr(-command)] && [string length $argsArr(-command)]} {
	uplevel #0 $argsArr(-command) $browseName set [list $jid $subiq]
    } else {
	uplevel #0 $locals(cmd) $browseName set [list $jid $subiq]
    }
}

# browse::setsinglejid --
#
#       Gets called for each jid in the jabber:iq:browse callback.
#       The recursive helper proc for 'setjid'.
#       
# Arguments:
#       browseName:   the instance of this conference browse.
#       parentJid:    the logical parent of 'jid'
#       jid:          the 'jid' we are setting; if empty it is in attribute list.
#       xmllist:      hierarchical xml list.
#                     Any children defines a parent-child relation.
#       
# Results:
#       none.

proc browse::setsinglejid {browseName parentJid jid xmllist {browsedjid 0}} {
    variable options
    upvar [namespace current]::${browseName}::locals locals
    
    Debug 3 "browse::setsinglejid browseName=$browseName, parentJid=$parentJid\
      jid=$jid, xmllist='$xmllist'"
    
    set theTag [lindex $xmllist 0]
    array set attr [lindex $xmllist 1]
    
    # If the 'jid' is empty we get it from our attributes!
    if {[string length $jid] == 0} {
	set jid $attr(jid)
    }
    
    # First, is this a "set" or a "remove" type?
    if {[info exists attr(type)] && [string equal $attr(type) "remove"]} {
	if {[string equal $theTag "user"]} {
	    
	    # Be sure to update the room's list of participants.
	    set ind [lsearch $locals($parentJid,allusers) $jid]
	    if {$ind >= 0} {
		set locals($parentJid,allusers)   \
		  [lreplace $locals($parentJid,allusers) $ind $ind]
	    }
	}
    } elseif {$options(-setbrowsedjid) || !$browsedjid} {
	
	# Set type.
	set locals($jid,xmllist) $xmllist
	
	# Set up parents for this jid.
	# Root's parent is empty. When not root, store parent(s).
	if {[string length $parentJid] > 0} {
	    set locals($jid,parent) $parentJid
	    set locals($jid,parents)   \
	      [concat $locals($parentJid,parents) $parentJid]
	}
	
	# Add us to parentJid's child list if not there already.
	if {![info exists locals($parentJid,childs)]} {
	    set locals($parentJid,childs) {}
	}
	if {[lsearch -exact $locals($parentJid,childs) $jid] < 0} {
	    lappend locals($parentJid,childs) $jid
	}
	
	if {[info exists attr(type)]} {
	    
	    # Check for any 'category' attribute introduced in the 1.2 rev.
	    # of JEP-0011.
	    if {[info exists attr(category)]} {
		set jidtype "$attr(category)/$attr(type)"
	    } else {		
		set jidtype "$theTag/$attr(type)"
	    }
	    set locals($jid,type) $jidtype
	    lappend locals($jidtype,typelist) $jid
	    lappend locals(alltypes) $jidtype
	}
	
	# Cache additional info depending on the tag.
	switch -exact -- $theTag {
	    conference {
	    
		# This is either a conference server or one of its rooms.
		if {[string match *@* $jid]} {
		    
		    # This must be a room. Cache its name.
		    if {[info exists attr(name)]} {
			set locals($jid,name) $attr(name)
		    }
		} else {
		
		    # Cache all conference servers. Don't count the rooms.
		    if {![info exists locals(confservers)]} {
			set locals(confservers) {}
		    }
		    if {[lsearch -exact $locals(confservers) $jid] < 0} {		    
			lappend locals(confservers) $jid
		    }
		}
	    }
	    user {
	    
		# If with 'user' tag in conferencing, keep internal table that
		# maps the 'room@server/hexname' to nickname.
		if {[info exists attr(name)]} {
			set locals($jid,name) $attr(name)
		}
		
		# Keep list of all 'user'«s in a room. The 'parentJid' must
		# be the room's jid here.
		if {![info exists locals($parentJid,allusers)]} {
		    set locals($parentJid,allusers) {}
		}
		if {[lsearch -exact $locals($parentJid,allusers) $jid] < 0} {
		    lappend locals($parentJid,allusers) $jid
		}
	    }	    
	}
    }
    # End set type.
    
    # Loop through the children if any. Defines a parentship.
    # Only exception is a namespace definition <ns>.
    foreach child [wrapper::getchildren $xmllist] {
	if {[string equal [lindex $child 0] "ns"]} {
	    
	    # Cache any namespace declarations.
	    if {![info exists locals($jid,ns)]} {
		set locals($jid,ns) {}
	    }
	    set ns [lindex $child 3]
	    lappend locals($jid,ns) $ns
	    set locals($jid,ns) [lsort -unique $locals($jid,ns)]
	    if {![info exists locals(ns,$ns)]} {
		set locals(ns,$ns) {}
	    }
	    lappend locals(ns,$ns) $jid
	    set locals(ns,$ns) [lsort -unique $locals(ns,$ns)]
	} else {
	    
	    # Now jid is the parent, and the jid to set is an attribute.
	    setsinglejid $browseName $jid {} $child
	}
    }
}

# browse::errorcallback --
#
#       Called when receiving an 'error' iq element in jabber:iq:browse.
#       Shall only be called from jabberlib!
#       
# Arguments:
#       browseName:   the instance of this conference browse.
#       jid:          the 'from' attribute which is also the parent of any
#                     childs.
#       errlist:      {errorCode errorMsg}
#       args          -errorcommand errPproc:   in case of error, this is called
#                        instead of the browse objects callback proc.
#       
# Results:
#       none.

proc browse::errorcallback {browseName jid errlist args} {
    upvar [namespace current]::${browseName}::locals locals
    
    Debug 3 "browse::errorcallback browseName=$browseName, jid=$jid\
      errlist=$errlist, args='$args'"

    array set argsArr $args
    if {[info exists argsArr(-errorcommand)] &&  \
      [string length $argsArr(-errorcommand)]} {
	set cmd $argsArr(-errorcommand)
    } else {
	set cmd $locals(cmd)
    }
	
    # Evaluate the client callback.
    uplevel #0 $cmd $browseName error [list $jid $errlist]
}

# browse::clear --
#
#       Empties everything cached internally for the specified jid and all
#       its children.

proc browse::clear {browseName {jid {}}} {
    
    upvar [namespace current]::${browseName}::locals locals
    
    if {[string length $jid]} {
	ClearJid $browseName $jid
    } else {
	ClearAll $browseName
    }
}

proc browse::ClearJid {browseName jid} {

    upvar [namespace current]::${browseName}::locals locals

    if {[info exists locals($jid,childs)]} {
	foreach child $locals($jid,childs) {
	    ClearJid $browseName $child
	}
    }
    
    # Keep parents!
    set parent $locals($jid,parent)
    set parents $locals($jid,parents)

    # Remove this specific jid from our internal state.
    array unset locals "$jid,*"
    set locals($jid,parent) $parent
    set locals($jid,parents) $parents
    catch {unset locals($jid,isbrowsed)}
}
    
# browse::ClearAll --
#
#       Empties everything cached internally.

proc browse::ClearAll {browseName} {
    
    upvar [namespace current]::${browseName}::locals locals

    set clientCmd $locals(cmd)
    unset locals
    set locals(cmd) $clientCmd
    set locals(confservers) {}
}

# browse::delete --
#
#       Deletes the complete object.

proc browse::delete {browseName} {
    
    namespace delete [namespace current]::$browseName
}

#-------------------------------------------------------------------------------

