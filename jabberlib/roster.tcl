# roster.tcl --
#
#       An object for storing the roster and presence information for a 
#       jabber client. Is used together with jabberlib.
#
# Copyright (c) 2001-2003  Mats Bengtsson
#  
# $Id: roster.tcl,v 1.16 2003-11-14 09:57:22 matben Exp $
# 
# Note that every jid in the rosterArr is usually (always) without any resource,
# but the jid's in the presArr are identical to the 'from' attribute, except
# the presArr($jid-2,res) which have any resource stripped off. The 'from' 
# attribute sre (always) with /resource.
# 
# Variables used in roster:
# 
#	rosterArr(users)              : The JID's of users currently in roster
#	                                (without the /resource).
#
#       rosterArr(groups)             : List of all groups the exist in roster.
#
#	rosterArr($jid,name)          : Name of $jid.
#	
#	rosterArr($jid,groups)        : Groups $jid is in. Note: PLURAL!
#
#	rosterArr($jid,subscription)  : Subscription of $jid (to|from|both|"")
#
#	rosterArr($jid,ask)           : "Ask" of $jid 
#                                       (subscribe|unsubscribe|"")
#                                       
#	presArr($jid-2,res)           : List of resources for this $jid.
#
#       presArr($from,type)           : One of 'available' or 'unavailable.
#
#       presArr($from,status)         : The presence status element.
#
#       presArr($from,priority)       : The presence priority element.
#
#       presArr($from,show)           : The presence show element.
#
#       presArr($from,x,xmlns)        : Storage for x elements.
#                                       xmlns is a namespace but where any
#                                       http://jabber.org/protocol/ stripped off
#                                      
############################# USAGE ############################################
#
#       Changes to the state of this object should only be made from jabberlib,
#       and never directly by the client!
#
#   NAME
#      roster - an object for roster and presence information.
#      
#   SYNOPSIS
#      roster::roster clientCommand
#      
#   OPTIONS
#      none
#      
#   INSTANCE COMMANDS
#      rostName clearpresence ?jidpattern?
#      rostName enterroster
#      rostName exitroster
#      rostName getgroups ?jid?
#      rostName getask jid
#      rostName getname jid
#      rostName getpresence jid ?-resource, -type?
#      rostName getresources jid
#      rostName gethighestresource jid
#      rostName getrosteritem jid
#      rostName getsubscription jid
#      rostName getusers ?-type available|unavailable?
#      rostName getx jid xmlns
#      rostName isavailable jid
#      rostName removeitem jid
#      rostName reset
#      rostName setpresence jid type ?-option value -option ...?
#      rostName setrosteritem jid ?-option value -option ...?
#      
#   The 'clientCommand' procedure must have the following form:
#   
#      clientCommand {rostName what {jid {}} args}
#      
#   where 'what' can be any of: enterroster, exitroster, presence, remove, set.
#   The args is a list of '-key value' pairs with the following keys for each
#   'what':
#       enterroster:   no keys
#       exitroster:    no keys
#       presence:    -resource      (required)
#                    -type          (required)
#                    -status        (optional)
#                    -priority      (optional)
#                    -show          (optional)
#                    -x             (optional)
#       remove:      no keys
#       set:         -name          (optional)
#                    -subscription  (optional)
#                    -groups        (optional)
#                    -ask           (optional)
#      
############################# CHANGES ##########################################
#
#       1.0a1    first release by Mats Bengtsson
#       1.0a2    clear roster and presence array before receiving such elements
#       1.0a3    added reset, isavailable, getresources, and getsubscription 
#       1.0b1    added gethighestresource command
#                changed setpresence arguments
#       1.0b2    changed storage of x elements, added getx command.
#       030602   added clearpresence command.
#       030702   added -type option to getusers command.
#       030703   removed rostName from roster::roster

package provide roster 1.0

namespace eval roster {
    
    variable rostGlobals
    
    # Globals same for all instances of this roster.
    set rostGlobals(debug) 0
    set rostGlobals(uid) 0
    
    # List of all rosterArr element sub entries. First the actual roster,
    # with 'rosterArr($jid,...)'
    set rostGlobals(tags) {name groups ask subscription} 
    
    # ...and the presence arrays: 'presArr($jid/$resource,...)'
    # The list of resources is treated separately (presArr($jid,res))
    set rostGlobals(presTags) {type status priority show x} 
}

# roster::roster --
#
#       This creates a new instance of a roster.
#       
# Arguments:
#       clientCmd:  callback procedure when internals of roster or
#                   presence changes.
#       args:            
#       
# Results:
#       rostName which is the command for this instance of the roster
  
proc roster::roster {clientCmd args} {
    variable rostGlobals

    # Generate unique command token for this roster instance.
    set rostName rost[incr rostGlobals(uid)]
      
    # Instance specific namespace.
    namespace eval [namespace current]::${rostName} {
	variable rosterArr
	variable presArr
	variable options
    }
    
    # Set simpler variable names.
    upvar [namespace current]::${rostName}::rosterArr rosterArr
    upvar [namespace current]::${rostName}::options options
        
    set rosterArr(users) {}
    set rosterArr(groups) {}
    set options(cmd) $clientCmd
    
    # Create the actual roster instance procedure.
    proc [namespace current]::${rostName} {cmd args}   \
      "eval roster::CommandProc {$rostName} \$cmd \$args"

    return [namespace current]::${rostName}
}

# roster::CommandProc --
#
#       Just dispatches the command to the right procedure.
#
# Arguments:
#       rostName:   the instance of this roster.
#       cmd:        .
#       args:       all args to the cmd procedure.
#       
# Results:
#       none.

proc roster::CommandProc {rostName cmd args} {
    
    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $rostName} $args]
}

# roster::setrosteritem --
#
#       Adds or modifies an existing roster item.
#       Features not set are left as they are; features not set will give
#       nonexisting array entries, just to differentiate between an empty
#       element and a nonexisting one.
#
# Arguments:
#       rostName:   the instance of this roster.
#       jid:        2-tier jid, with no /resource, usually.
#                   Some transports keep a resource part in jid.
#       args:       a list of '-key value' pairs, where '-key' is any of:
#                       -name value
#                       -subscription value
#                       -groups list        Note: GROUPS in plural!
#                       -ask value
#       
# Results:
#       none.

proc roster::setrosteritem {rostName jid args} {    
    variable rostGlobals
    upvar [namespace current]::${rostName}::rosterArr rosterArr
    upvar [namespace current]::${rostName}::options options
    
    Debug 2 "roster::setrosteritem rostName=$rostName, jid='$jid', args='$args'"
        
    # Add user if not there already.
    if {[lsearch -exact $rosterArr(users) $jid] < 0} {
	lappend rosterArr(users) $jid
    }
    
    # Clear out the old state since an 'ask' element may still be lurking.
    foreach key $rostGlobals(tags) {
	catch {unset rosterArr($jid,$key)}
    }
    
    # Old values will be overwritten, nonexisting options will result in
    # nonexisting array entries.
    foreach {name value} $args {
	set par [string trimleft $name "-"]
	set rosterArr($jid,$par) $value
	if {[string equal $par "groups"]} {
	    foreach gr $value {
		if {[lsearch $rosterArr(groups) $gr] < 0} {
		    lappend rosterArr(groups) $gr
		}
	    }
	}
    }
    
    # Be sure to evaluate the registered command procedure.
    if {[string length $options(cmd)]} {
	uplevel #0 $options(cmd) [list $rostName set $jid] $args
    }
    return {}
}

# roster::removeitem --
#
#       Removes an existing roster item and all its presence info.
#
# Arguments:
#       rostName:   the instance of this roster.
#       jid:        2-tier jid with no /resource.
#       
# Results:
#       none.

proc roster::removeitem {rostName jid} {    
    variable rostGlobals
    upvar [namespace current]::${rostName}::rosterArr rosterArr
    upvar [namespace current]::${rostName}::options options
    
    Debug 2 "roster::removeitem rostName=$rostName, jid='$jid'"
    
    set ind [lsearch -exact $rosterArr(users) $jid]
    
    # Return if not there.
    if {$ind < 0} {
	return
    } else {
	set rosterArr(users) [lreplace $rosterArr(users) $ind $ind]
    }
    
    # First the roster, then presence...
    foreach name $rostGlobals(tags) {
	catch {unset rosterArr($jid,$name)}
    }
    array unset presArr "$jid,*"
    
    # Be sure to evaluate the registered command procedure.
    if {[string length $options(cmd)]} {
	uplevel #0 $options(cmd) [list $rostName remove $jid]
    }
    return {}
}

# roster::ClearRoster --
#
#       Removes all existing roster items but keeps all presence info.(?)
#       and list of resources.
#
# Arguments:
#       rostName:   the instance of this roster.
#       
# Results:
#       none. Callback evaluated.

proc roster::ClearRoster {rostName} {    
    variable rostGlobals
    upvar [namespace current]::${rostName}::rosterArr rosterArr
    upvar [namespace current]::${rostName}::options options
    
    Debug 2 "roster::ClearRoster rostName=$rostName"
        
    # Remove the roster.
    foreach jid $rosterArr(users) {
	foreach key $rostGlobals(tags) {
	    catch {unset rosterArr($jid,$key)}
	}
    }
    set rosterArr(users) {}
    
    # Be sure to evaluate the registered command procedure.
    if {[string length $options(cmd)]} {
	uplevel #0 $options(cmd) [list $rostName enterroster]
    }
    return {}
}

# roster::enterroster --
#
#       Is called when new roster coming.
#
# Arguments:
#       rostName:   the instance of this roster.
#       
# Results:
#       none.

proc roster::enterroster {rostName} {

    ClearRoster $rostName
}

# roster::exitroster --
#
#       Is called when finished receiving a roster get command.
#
# Arguments:
#       rostName:   the instance of this roster.
#       
# Results:
#       none. Callback evaluated.

proc roster::exitroster {rostName} {    
    upvar [namespace current]::${rostName}::options options

    # Be sure to evaluate the registered command procedure.
    if {[string length $options(cmd)]} {
	uplevel #0 $options(cmd) [list $rostName exitroster]
    }
}

# roster::reset --
#
#       Removes everything stored in the roster object, including all roster
#       items and any presence information.

proc roster::reset {rostName} {
    upvar [namespace current]::${rostName}::rosterArr rosterArr
    upvar [namespace current]::${rostName}::presArr presArr
    
    catch {unset rosterArr}
    catch {unset presArr}
    set rosterArr(users) {}
    set rosterArr(groups) {}
}

# roster::clearpresence --
# 
#       Removes all presence cached internally for jid glob pattern.
#       Helpful when exiting a room.
#       
# Arguments:
#       rostName:   the instance of this roster.
#       jidpattern: glob pattern for items to remove.
#       
# Results:
#       none.

proc roster::clearpresence {rostName {jidpattern ""}} {
    upvar [namespace current]::${rostName}::presArr presArr

    if {$jidpattern == ""} {
	catch {unset presArr}
    } else {
	array unset presArr $jidpattern
    }
}

# roster::setpresence --
#
#       Sets the presence of a roster item. Adds the corresponding resource
#       to the list of resources for this jid.
#
# Arguments:
#       rostName:   the instance of this roster.
#       jid:        the from attribute. Usually 3-tier jid with /resource part.
#       type:       one of 'available', 'unavailable', or 'unsubscribed'.
#       args:       a list of '-key value' pairs, where '-key' is any of:
#                     -status value
#                     -priority value
#                     -show value
#                     -x list of xml lists
#       
# Results:
#       none.

proc roster::setpresence {rostName jid type args} { 
    variable rostGlobals
    upvar [namespace current]::${rostName}::rosterArr rosterArr
    upvar [namespace current]::${rostName}::presArr presArr
    upvar [namespace current]::${rostName}::options options
    
    Debug 2 "roster::setpresence rostName=$rostName, jid='$jid', \
      type='$type', args='$args'"
    
    jlib::splitjid $jid jid2 resource
    
    if {[string equal $type "unsubscribed"]} {
	
	# We need to remove item from all resources.
	array unset presArr "${jid2}*"
	set argList [list -type $type]
    } else {
	
	# Clear out the old presence state since elements may still be lurking.
	array unset presArr "${jid},*"
	
	# Should we add something more to our roster, such as subscription,
	# if we haven't got our roster before this?
	
	# Add to list of resources.
	set presArr($jid2,res) [lsort -unique [lappend presArr($jid2,res) \
	  $resource]]
	
	set presArr($jid,type) $type
	foreach {name value} $args {
	    set par [string trimleft $name "-"]
	    switch -- $par {
		x {
		    
		    # This is a list of <x> lists.
		    foreach xelem $value {
			set ns [wrapper::getattribute $xelem xmlns]
			regexp {http://jabber.org/protocol/(.*)$} $ns \
			  match ns
			set presArr($jid,x,$ns) $xelem
		    }
		}
		default {
		    set presArr($jid,$par) $value
		}
	    }
	}
	set argList [concat [list -resource $resource -type $type] $args]
    }
    
    # Be sure to evaluate the registered command procedure.
    if {[string length $options(cmd)]} {
	uplevel #0 $options(cmd) [list $rostName presence $jid2] $argList
    }
    return {}
}

# roster::getrosteritem --
#
#       Returns the state of an existing roster item.
#
# Arguments:
#       rostName:   the instance of this roster.
#       jid:        .
#       
# Results:
#       a list of '-key value' pairs where key is any of: 
#       name, groups, subscription, ask. Note GROUPS in plural!

proc roster::getrosteritem {rostName jid} {    
    variable rostGlobals
    upvar [namespace current]::${rostName}::rosterArr rosterArr
    upvar [namespace current]::${rostName}::options options
    
    Debug 2 "roster::getrosteritem rostName=$rostName, jid='$jid'"
    
    if {[lsearch -exact $rosterArr(users) $jid] < 0} {
	#error "nonexisting jid \"$jid\" in roster"
	# Or should we be silent?
	return {}
    }
    set result {}
    foreach key $rostGlobals(tags) {
	if {[info exists rosterArr($jid,$key)]} {
	    lappend result -$key $rosterArr($jid,$key)
	}
    }
    return $result
}

# roster::getusers --
#
#       Returns a list of jid's of all existing roster items.
#
# Arguments:
#       rostName:   the instance of this roster.
#       args:       -type available|unavailable
#       
# Results:
#       list of all 2-tier jid's in roster

proc roster::getusers {rostName args} {
    upvar [namespace current]::${rostName}::rosterArr rosterArr
    upvar [namespace current]::${rostName}::presArr presArr    
    
    set jidlist $rosterArr(users)
    
    foreach {key value} $args {
	
	switch -- $key {
	    -type {
		
		# Loop through all jid2 in roster and see if any available
		set jidlist {}
		foreach jid2 $rosterArr(users) {
		    set isavailable 0

		    # Be sure to handle empty resources as well: '1234@icq.host'
		    foreach key [array names presArr "${jid2}*,type"] {
			if {[string equal $presArr($key) "available"]} {
			    set isavailable 1
			    break
			}
		    }
		    
		    switch -- $value {
			available {
			    if {$isavailable} {
				lappend jidlist $jid2
			    }
			}
			unavailable {
			    if {!$isavailable} {
				lappend jidlist $jid2
			    }
			}
		    }
		}
	    }
	    default {
		# empty
	    }
	}
    }
    return $jidlist
}

proc roster::getusersBU {rostName args} {
    upvar [namespace current]::${rostName}::rosterArr rosterArr
    upvar [namespace current]::${rostName}::presArr presArr
	
    set jidlist $rosterArr(users)
    foreach {key value} $args {
	
	switch -- $key {
	    -type {
		
		# Loop through all jid2 in roster and see if any available
		set jidlist {}
		foreach jid2 $rosterArr(users) {
		    set isavailable 0
		    if {[info exists presArr($jid2,res)]} {
			foreach res $presArr($jid2,res) {
			    set jid3 $jid2/$res
			    if {[info exists presArr($jid3,type)] && \
			      [string equal $presArr($jid3,type) "available"]} {
				set isavailable 1
				break
			    }
			}
		    }
		    
		    switch -- $value {
			available {
			    if {$isavailable} {
				lappend jidlist $jid2
			    }
			}
			unavailable {
			    if {!$isavailable} {
				lappend jidlist $jid2
			    }
			}
		    }
		}
	    }
	    default {
		# empty
	    }
	}
    }
    return $jidlist
}

# roster::getpresence --
#
#       Returns the presence state of an existing roster item.
#
# Arguments:
#       rostName:   the instance of this roster.
#       jid:        username@server, without /resource.
#       args        ?-resource, -type?
#                   -resource: return presence for this alone,
#                       else a list for each resource.
#                       Allow empty resources!!??
#                   -type: return presence for (un)available only.
#       
# Results:
#       a list of '-key value' pairs where key is any of: 
#       resource, type, status, priority, show, x.
#       If the 'resource' in argument is not given,
#       the result contains a sublist for each resource. IMPORTANT! Bad?

proc roster::getpresence {rostName jid args} {    
    variable rostGlobals
    upvar [namespace current]::${rostName}::rosterArr rosterArr
    upvar [namespace current]::${rostName}::presArr presArr
    upvar [namespace current]::${rostName}::options options
    
    Debug 2 "roster::getpresence rostName=$rostName, jid=$jid, args='$args'"
    
    array set argsArr $args
    set haveRes 0
    if {[info exists argsArr(-resource)]} {
	set haveRes 1
	set resource $argsArr(-resource)
    }
    
    # It may happen that there is no roster item for this jid (groupchat).
    if {![info exists presArr($jid,res)] ||   \
      ([string length $presArr($jid,res)] == 0)} {
	if {[info exists argsArr(-type)] &&  \
	  [string equal $argsArr(-type) "available"]} {
	    return {}
	} else {
	    if {$haveRes} {
		return [list -resource $resource -type unavailable]
	    } else {      
		return [list [list -resource "" -type unavailable]]
	    }
	}
    }
    
    set result {}
    if {$haveRes} {

	# Return presence only from the specified resource.
	# Be sure to handle empty resources as well: '1234@icq.host'
	if {[lsearch -exact $presArr($jid,res) $resource] < 0} {
	    return [list -resource $resource -type unavailable]
	}
	set result [list -resource $resource]
	if {$resource == ""} {
	    set jid3 $jid
	} else {
	    set jid3 $jid/$resource
	}
	if {[info exists argsArr(-type)] &&  \
	  ![string equal $argsArr(-type) $presArr($jid3,type)]} {
	    return {}
	}
	foreach key $rostGlobals(presTags) {
	    if {[info exists presArr($jid3,$key)]} {
		lappend result -$key $presArr($jid3,$key)
	    }
	}
    } else {
	
	# Get presence for all resources.
	# Be sure to handle empty resources as well: '1234@icq.host'
	foreach res $presArr($jid,res) {
	    set thisRes [list -resource $res]
	    if {$res == ""} {
		set jid3 $jid
	    } else {
		set jid3 $jid/$res
	    }
	    if {[info exists argsArr(-type)] &&  \
	      ![string equal $argsArr(-type) $presArr($jid3,type)]} {
		# Empty.
	    } else {
		foreach key $rostGlobals(presTags) {
		    if {[info exists presArr($jid3,$key)]} {
			lappend thisRes -$key $presArr($jid3,$key)
		    }
		}
		lappend result $thisRes
	    }
	}
    }
    return $result
}

# roster::getgroups --
#
#       Returns the list of groups for this jid, or an empty list if not 
#       exists. If no jid, return a list of all groups existing in this roster.
#
# Arguments:
#       rostName:   the instance of this roster.
#       jid:        (optional).
#       
# Results:
#       a list of groups or empty.

proc roster::getgroups {rostName {jid {}}} {    
    upvar [namespace current]::${rostName}::rosterArr rosterArr
   
    Debug 2 "roster::getgroups rostName=$rostName, jid='$jid'"
    
    if {[string length $jid]} {
	if {[info exists rosterArr($jid,groups)]} {
	    return $rosterArr($jid,groups)
	} else {
	    return {}
	}
    } else {
	set rosterArr(groups) [lsort -unique $rosterArr(groups)]
	return $rosterArr(groups)
    }
}

# roster::getname --
#
#       Returns the nick name of this jid.
#
# Arguments:
#       rostName:   the instance of this roster.
#       jid:        
#       
# Results:
#       the nick name or empty.

proc roster::getname {rostName jid} {
    upvar [namespace current]::${rostName}::rosterArr rosterArr
   
    Debug 2 "roster::getname rostName=$rostName, jid='$jid'"
    
    if {[info exists rosterArr($jid,name)]} {
	return $rosterArr($jid,name)
    } else {
	return {}
    }
}

# roster::getsubscription --
#
#       Returns the 'subscription' state of this jid.
#
# Arguments:
#       rostName:   the instance of this roster.
#       jid:        
#       
# Results:
#       the 'subscription' state or "none" if no 'subscription' state.

proc roster::getsubscription {rostName jid} {
    upvar [namespace current]::${rostName}::rosterArr rosterArr
   
    Debug 2 "roster::getsubscription rostName=$rostName, jid='$jid'"
    
    if {[info exists rosterArr($jid,subscription)]} {
	return $rosterArr($jid,subscription)
    } else {
	return none
    }
}

# roster::getask --
#
#       Returns the 'ask' state of this jid.
#
# Arguments:
#       rostName:   the instance of this roster.
#       jid:        
#       
# Results:
#       the 'ask' state or empty if no 'ask' state.

proc roster::getask {rostName jid} {
    upvar [namespace current]::${rostName}::rosterArr rosterArr
   
    Debug 2 "roster::getask rostName=$rostName, jid='$jid'"
    
    if {[info exists rosterArr($jid,ask)]} {
	return $rosterArr($jid,ask)
    } else {
	return {}
    }
}

# roster::getresources --
#
#       Returns a list of all resources for this jid or empty.
#
# Arguments:
#       rostName:   the instance of this roster.
#       jid:        a jid without any resource (jid2).
#       args        ?-type?
#                   -type: return presence for (un)available only.
#       
# Results:
#       a list of all resources for this jid or empty.

proc roster::getresources {rostName jid args} {
    upvar [namespace current]::${rostName}::presArr presArr
   
    Debug 2 "roster::getresources rostName=$rostName, jid='$jid'"
    array set argsArr $args
    
    if {[info exists presArr($jid,res)]} {
	if {[info exists argsArr(-type)]} {
	    
	    # Need to loop through all resources for this jid.
	    set resList {}
	    set type $argsArr(-type)
	    foreach res $presArr($jid,res) {

		# Be sure to handle empty resources as well: '1234@icq.host'
		if {$res== ""} {
		    set jid3 $jid
		} else {
		    set jid3 $jid/$res
		}
		if {[string equal $argsArr(-type) $presArr($jid3,type)]} {
		    lappend resList $res
		}
	    }
	    return $resList
	} else {
	    return $presArr($jid,res)
	}
    } else {
	return {}
    }
}

# roster::gethighestresource --
#
#       Returns the resource with highest priority for this jid or empty.
#
# Arguments:
#       rostName:   the instance of this roster.
#       jid:        a jid without any resource (jid2).
#       
# Results:
#       a resource for this jid or empty.

proc roster::gethighestresource {rostName jid} {
    upvar [namespace current]::${rostName}::presArr presArr
   
    Debug 2 "roster::gethighestresource rostName=$rostName, jid='$jid'"
    
    set maxres ""
    if {[info exists presArr($jid,res)]} {
	
	# Find the resource corresponding to the highest priority (D=0).
	set maxpri 0
	set maxres [lindex $presArr($jid,res) 0]
	foreach res $presArr($jid,res) {

	    # Be sure to handle empty resources as well: '1234@icq.host'
	    if {$res== ""} {
		set jid3 $jid
	    } else {
		set jid3 $jid/$res
	    }
	    if {[info exists presArr($jid3,priority)]} {
		if {$presArr($jid3,priority) > $maxpri} {
		    set maxres $res
		    set maxpri $presArr($jid3,priority)
		}
	    }
	}
    }
    return $maxres
}

# roster::isavailable --
#
#       Returns boolean 0/1. Returns 1 only if presence is equal to available.
#       If 'jid' without resource, return 1 if any is available.
#
# Arguments:
#       rostName:   the instance of this roster.
#       jid:        either 'username$hostname', or 'username$hostname/resource'.
#       
# Results:
#       0/1.

proc roster::isavailable {rostName jid} {
    upvar [namespace current]::${rostName}::presArr presArr
   
    Debug 2 "roster::isavailable rostName=$rostName, jid='$jid'"
        
    # If any resource in jid, we get it here.
    jlib::splitjid $jid jid2 resource

    if {[string length $resource] > 0} {
	if {[info exists presArr($jid2/$resource,type)]} {
	    if {[string equal $presArr($jid2/$resource,type) "available"]} {
		return 1
	    } else {
		return 0
	    }
	} else {
	    return 0
	}
    } else {
	
	# Be sure to allow for 'user@domain' with empty resource.
	foreach key [array names presArr "${jid2}*,type"] {
	    if {[string equal $presArr($key) "available"]} {
		return 1
	    }
	}
	return 0
    }
}

# roster::getx --
#
#       Returns the xml list for this jid's x element with given xml namespace.
#       Returns empty if no matching info.
#
# Arguments:
#       rostName:   the instance of this roster.
#       jid:        any jid
#       xmlns:      the (mandatory) xmlns specifier. Any prefix
#                   http://jabber.org/protocol/ must be stripped off.
#       
# Results:
#       xml list or empty.

proc roster::getx {rostName jid xmlns} {
    upvar [namespace current]::${rostName}::presArr presArr
   
    Debug 2 "roster::getx rostName=$rostName, jid='$jid', xmlns=$xmlns"

    if {[info exists presArr($jid,x,$xmlns)]} {
	return $presArr($jid,x,$xmlns)
    } else {
	return ""
    }
}

proc roster::Debug {num str} {
    variable rostGlobals
    if {$num <= $rostGlobals(debug)} {
	puts $str
    }
}

#-------------------------------------------------------------------------------
