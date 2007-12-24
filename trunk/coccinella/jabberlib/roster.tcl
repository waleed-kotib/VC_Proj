# roster.tcl --
#
#       An object for storing the roster and presence information for a 
#       jabber client. Is used together with jabberlib.
#
# Copyright (c) 2001-2006  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: roster.tcl,v 1.63 2007-12-24 09:31:14 matben Exp $
# 
# Note that every jid in the rostA is usually (always) without any resource,
# but the jid's in the presA are identical to the 'from' attribute, except
# the presA($jid-2,res) which have any resource stripped off. The 'from' 
# attribute are (always) with /resource.
# 
# All jid's in internal arrays are STRINGPREPed!
# 
# Variables used in roster:
# 
#       rostA(groups)             : List of all groups the exist in roster.
#
#	rostA($jid,item)          : $jid.
#	
#	rostA($jid,name)          : Name of $jid.
#	
#	rostA($jid,groups)        : Groups $jid is in. Note: PLURAL!
#
#	rostA($jid,subscription)  : Subscription of $jid (to|from|both|"")
#
#	rostA($jid,ask)           : "Ask" of $jid 
#                                     (subscribe|unsubscribe|"")
#                                       
#	presA($jid-2,res)         : List of resources for this $jid.
#
#       presA($from,type)         : One of 'available' or 'unavailable.
#
#       presA($from,status)       : The presence status element.
#
#       presA($from,priority)     : The presence priority element.
#
#       presA($from,show)         : The presence show element.
#
#       presA($from,x,xmlns)      : Storage for x elements.
#                                     xmlns is a namespace but where any
#                                     http://jabber.org/protocol/ stripped off
#                  
#       oldpresA                  : As presA but any previous state.
#       
#       state($jid,*)             : Keeps other info not directly related
#                                   to roster or presence elements.
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
#      jlibname roster cmd ??
#      
#   INSTANCE COMMANDS
#      jlibname roster availablesince jid
#      jlibname roster clearpresence ?jidpattern?
#      jlibname roster getgroups ?jid?
#      jlibname roster getask jid
#      jlibname roster getcapsattr jid name
#      jlibname roster getname jid
#      jlibname roster getpresence jid ?-resource, -type?
#      jlibname roster getresources jid
#      jlibname roster gethighestresource jid
#      jlibname roster getrosteritem jid
#      jlibname roster getstatus jid
#      jlibname roster getsubscription jid
#      jlibname roster getusers ?-type available|unavailable?
#      jlibname roster getx jid xmlns
#      jlibname roster getextras jid xmlns
#      jlibname roster isavailable jid
#      jlibname roster isitem jid
#      jlibname roster haveroster
#      jlibname roster reset
#      jlibname roster send_get ?-command tclProc?
#      jlibname roster send_remove ?-command tclProc?
#      jlibname roster send_set ?-command tclProc, -name, -groups?
#      jlibname roster wasavailable jid
#      
#   The 'clientCommand' procedure must have the following form:
#   
#      clientCommand {jlibname what {jid {}} args}
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
#                    -extras        (optional)
#       remove:      no keys
#       set:         -name          (optional)
#                    -subscription  (optional)
#                    -groups        (optional)
#                    -ask           (optional)
#      
################################################################################

package require jlib

package provide jlib::roster 1.0

namespace eval jlib::roster {
    
    variable rostGlobals
    
    # Globals same for all instances of this roster.
    set rostGlobals(debug) 0
    
    # List of all rostA element sub entries. First the actual roster,
    # with 'rostA($jid,...)'
    set rostGlobals(tags) {name groups ask subscription} 
    
    # ...and the presence arrays: 'presA($jid/$resource,...)'
    # The list of resources is treated separately (presA($jid,res))
    set rostGlobals(presTags) {type status priority show x}

    # Note: jlib::ensamble_register is last in this file!
}

# jlib::roster::roster --
#
#       This creates a new instance of a roster.
#       
# Arguments:
#       clientCmd:  callback procedure when internals of roster or
#                   presence changes.
#       args:            
#       
# Results:
#       
  
proc jlib::roster::init {jlibname args} {
      
    # Instance specific namespace.
    namespace eval ${jlibname}::roster {
	variable rostA
	variable presA
	variable options
	variable priv
	
	set priv(haveroster) 0
    }
    
    # Set simpler variable names.
    upvar ${jlibname}::roster::rostA rostA
    upvar ${jlibname}::roster::options options
    
    # Register for roster pushes.
    $jlibname iq_register set "jabber:iq:roster" [namespace code set_handler]
        
    # Register for presence. Be sure they are first in order.
    $jlibname presence_register_int available   \
      [namespace code presence_handler] 10
    $jlibname presence_register_int unavailable \
      [namespace code presence_handler] 10
    
    set rostA(groups) [list]
    set options(cmd) ""
    
    jlib::register_package roster
}

# jlib::roster::cmdproc --
#
#       Just dispatches the command to the right procedure.
#
# Arguments:
#       jlibname:   name of existing jabberlib instance
#       cmd:        
#       args:       all args to the cmd procedure.
#       
# Results:
#       none.

proc jlib::roster::cmdproc {jlibname cmd args} {
    
    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

# jlib::roster::register_cmd --
# 
#       This sets a client callback command.

proc jlib::roster::register_cmd {jlibname cmd} {
    upvar ${jlibname}::roster::options options
        
    set options(cmd) $cmd
}

proc jlib::roster::haveroster {jlibname} {
    upvar ${jlibname}::roster::priv priv
    
    return $priv(haveroster)
}

# jlib::roster::send_get --
# 
#       Request our complete roster.
#       
# Arguments:
#       jlibname:   name of existing jabberlib instance
#       args:       -command tclProc
#       
# Results:
#       none.

proc jlib::roster::send_get {jlibname args} {

    array set argsA {-command {}}
    array set argsA $args  
    
    set queryE [wrapper::createtag "query"  \
      -attrlist [list xmlns jabber:iq:roster]]
    jlib::send_iq $jlibname "get" [list $queryE]  \
      -command [list [namespace current]::send_get_cb $jlibname $argsA(-command)]
    return
}

proc jlib::roster::send_get_cb {jlibname cmd type queryE} {
    
    if {![string equal $type "error"]} {
	enterroster $jlibname
	handle_roster $jlibname $queryE
	exitroster $jlibname
    }
    if {$cmd ne {}} {
	uplevel #0 $cmd [list $type $queryE]
    }
}

# jlib::roster::set_handler --
# 
#       This gets called for roster pushes.

proc jlib::roster::set_handler {jlibname from queryE args} {
    
    handle_roster $jlibname $queryE
    
    # RFC 3921, sect 8.1:
    # The 'from' and 'to' addresses are OPTIONAL in roster pushes; ...
    # A client MUST acknowledge each roster push with an IQ stanza of 
    # type "result"...
    array set argsA $args
    if {[info exists argsA(-id)]} {
	$jlibname send_iq "result" {} -id $argsA(-id)
    }
    return 1
}

proc jlib::roster::handle_roster {jlibname queryE} {

    upvar ${jlibname}::roster::itemA itemA

    foreach itemE [wrapper::getchildren $queryE] {	
	if {[wrapper::gettag $itemE] ne "item"} {
	    continue
	}
	set subscription "none"
	set opts [list]
	set havejid 0
	foreach {aname avalue} [wrapper::getattrlist $itemE] {
	    set $aname $avalue
	    if {$aname eq "jid"} {
		set havejid 1
	    } else {
		lappend opts -$aname $avalue
	    }
	}
	
	# This shall NEVER happen!
	if {!$havejid} {
	    continue
	}
	set mjid [jlib::jidmap $jid]
	if {$subscription eq "remove"} {
	    unset -nocomplain itemA($mjid)
	    removeitem $jlibname $jid
	} else {
	    set itemA($mjid) $itemE
	    set groups [list]
	    foreach groupE [wrapper::getchildswithtag $itemE group] {
		lappend groups [wrapper::getcdata $groupE]
	    }
	    if {[llength $groups]} {
		lappend opts -groups $groups
	    }
	    eval {setitem $jlibname $jid} $opts
	}
    }
}

# jlib::roster::send_set --
#
#       To set/add an jid in/to your roster.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        jabber user id to add/set.
#       args:
#           -command tclProc
#           -name $name:     A name to show the user-id as on roster to the user.
#           -groups $group_list: Groups of user. If you omit this, then the user's
#                            groups will be set according to the user's options
#                            stored in the roster object. If user doesn't exist,
#                            or you haven't got your roster, user's groups will be
#                            set to "", which means no groups.
#       
# Results:
#       none.
 
proc jlib::roster::send_set {jlibname jid args} {

    upvar ${jlibname}::roster::rostA rostA
    
    array set argsA {-command {}}
    array set argsA $args  

    set mjid [jlib::jidmap $jid]

    # Find group(s).
    if {[info exists argsA(-groups)]} {
	set groups $argsA(-groups)
    } elseif {[info exists rostA($mjid,groups)]} {
	set groups $rostA($mjid,groups)
    } else {
	set groups [list]
    }
    
    set attr [list jid $jid]
    set name ""
    if {[info exists argsA(-name)] && [string length $argsA(-name)]} {
	set name $argsA(-name)
	lappend attr name $name
    }
    set groupEs [list]
    foreach group $groups {
	if {$group ne ""} {
	    lappend groupEs [wrapper::createtag "group" -chdata $group]
	}
    }
    
    # Roster items get pushed to us. Only any errors need to be taken care of.
    set itemE [wrapper::createtag "item" -attrlist $attr -subtags $groupEs]
    set queryE [wrapper::createtag "query"   \
      -attrlist [list xmlns jabber:iq:roster] -subtags [list $itemE]]
    jlib::send_iq $jlibname "set" [list $queryE] -command $argsA(-command)
    return
}

proc jlib::roster::send_remove {jlibname jid args} {

    array set argsA {-command {}}
    array set argsA $args  
    
    # Roster items get pushed to us. Only any errors need to be taken care of.
    set itemE [wrapper::createtag "item"  \
      -attrlist [list jid $jid subscription remove]]
    set queryE [wrapper::createtag "query"   \
      -attrlist [list xmlns jabber:iq:roster] -subtags [list $itemE]]
    jlib::send_iq $jlibname "set" [list $queryE] -command $argsA(-command)
    return
}

# jlib::roster::setitem --
#
#       Adds or modifies an existing roster item.
#       Features not set are left as they are; features not set will give
#       nonexisting array entries, just to differentiate between an empty
#       element and a nonexisting one.
#
# Arguments:
#       jlibname:   the instance of this jlib.
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

proc jlib::roster::setitem {jlibname jid args} {        
    variable rostGlobals
    upvar ${jlibname}::roster::rostA rostA
    upvar ${jlibname}::roster::options options
    
    Debug 2 "roster::setitem jid='$jid', args='$args'"
        
    set mjid [jlib::jidmap $jid]
    
    # Clear out the old state since an 'ask' element may still be lurking.
    foreach key $rostGlobals(tags) {
	unset -nocomplain rostA($mjid,$key)
    }
    
    # This array is better than list to keep track of users.
    set rostA($mjid,item) $mjid
    
    # Old values will be overwritten, nonexisting options will result in
    # nonexisting array entries.
    foreach {name value} $args {
	set par [string trimleft $name "-"]
	set rostA($mjid,$par) $value
	if {[string equal $par "groups"]} {
	    foreach gr $value {
		if {[lsearch -exact $rostA(groups) $gr] < 0} {
		    lappend rostA(groups) $gr
		}
	    }
	}
    }
    
    # Be sure to evaluate the registered command procedure.
    if {[string length $options(cmd)]} {
	uplevel #0 $options(cmd) [list $jlibname set $jid] $args
    }
    return
}

# jlib::roster::removeitem --
#
#       Removes an existing roster item and all its presence info.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        2-tier jid with no /resource.
#       
# Results:
#       none.

proc jlib::roster::removeitem {jlibname jid} {       
    variable rostGlobals

    upvar ${jlibname}::roster::rostA rostA
    upvar ${jlibname}::roster::presA presA
    upvar ${jlibname}::roster::oldpresA oldpresA
    upvar ${jlibname}::roster::options options
    
    Debug 2 "roster::removeitem jid='$jid'"
    
    set mjid [jlib::jidmap $jid]
    
    # Be sure to evaluate the registered command procedure.
    # Do this BEFORE unsetting the internal state!
    if {[string length $options(cmd)]} {
	uplevel #0 $options(cmd) [list $jlibname remove $jid]
    }
    
    # First the roster, then presence...
    foreach name $rostGlobals(tags) {
	unset -nocomplain rostA($mjid,$name)
    }
    unset -nocomplain rostA($mjid,item)
    
    # Be sure to unset all, also jid3 entries!
    array unset presA [jlib::ESC $mjid]*
    array unset oldpresA [jlib::ESC $mjid]*
    return
}

# jlib::roster::ClearRoster --
#
#       Removes all existing roster items but keeps all presence info.(?)
#       and list of resources.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       
# Results:
#       none. Callback evaluated.

proc jlib::roster::ClearRoster {jlibname} {    

    variable rostGlobals
    upvar ${jlibname}::roster::rostA rostA
    upvar ${jlibname}::roster::itemA itemA
    upvar ${jlibname}::roster::options options
    
    Debug 2 "roster::ClearRoster"
        
    # Remove the roster.
    foreach {x mjid} [array get rostA *,item] {
	foreach key $rostGlobals(tags) {
	    unset -nocomplain rostA($mjid,$key)
	}
    }
    array unset rostA *,item
    unset -nocomplain itemA
    
    # Be sure to evaluate the registered command procedure.
    if {[string length $options(cmd)]} {
	uplevel #0 $options(cmd) [list $jlibname enterroster]
    }
    return
}

# jlib::roster::enterroster --
#
#       Is called when new roster coming.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       
# Results:
#       none.

proc jlib::roster::enterroster {jlibname} {

    ClearRoster $jlibname
}

# jlib::roster::exitroster --
#
#       Is called when finished receiving a roster get command.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       
# Results:
#       none. Callback evaluated.

proc jlib::roster::exitroster {jlibname} {    

    upvar ${jlibname}::roster::options options
    upvar ${jlibname}::roster::priv    priv

    set priv(haveroster) 1
    
    # Be sure to evaluate the registered command procedure.
    if {[string length $options(cmd)]} {
	uplevel #0 $options(cmd) [list $jlibname exitroster]
    }
}

# jlib::roster::reset --
#
#       Removes everything stored in the roster object, including all roster
#       items and any presence information.

proc jlib::roster::reset {jlibname} {

    upvar ${jlibname}::roster::rostA rostA
    upvar ${jlibname}::roster::presA presA
    upvar ${jlibname}::roster::priv    priv
    
    unset -nocomplain rostA presA
    set rostA(groups) {}
    set priv(haveroster) 0
}

# jlib::roster::clearpresence --
# 
#       Removes all presence cached internally for jid glob pattern.
#       Helpful when exiting a room.
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#       jidpattern: glob pattern for items to remove.
#       
# Results:
#       none.

proc jlib::roster::clearpresence {jlibname {jidpattern ""}} {

    upvar ${jlibname}::roster::presA presA
    upvar ${jlibname}::roster::oldpresA oldpresA

    Debug 2 "roster::clearpresence '$jidpattern'"

    if {$jidpattern eq ""} {
	unset -nocomplain presA
    } else {
	array unset presA $jidpattern
	array unset oldpresA $jidpattern
    }
}

proc jlib::roster::presence_handler {jlibname xmldata} {    
    presence $jlibname $xmldata
    return 0
}

# jlib::roster::presence --
# 
#       Registered internal presence handler for 'available' and 'unavailable'
#       that caches all presence info.

proc jlib::roster::presence {jlibname xmldata} {
    
    variable rostGlobals
    upvar ${jlibname}::roster::rostA rostA
    upvar ${jlibname}::roster::presA presA
    upvar ${jlibname}::roster::oldpresA oldpresA
    upvar ${jlibname}::roster::state state

    Debug 2 "jlib::roster::presence"

    set from [wrapper::getattribute $xmldata from]
    set type [wrapper::getattribute $xmldata type]
    if {$type eq ""} {
	set type "available"
    }

    # We don't handle subscription types (remove?).
    if {$type ne "available" && $type ne "unavailable"} {
	return
    }

    set mjid [jlib::jidmap $from]
    jlib::splitjid $mjid mjid2 res

    # Set secs only if unavailable before.
    if {![info exists presA($mjid,type)]  \
      || ($presA($mjid,type) eq "unavailable")} {
	set state($mjid,secs) [clock seconds]
    }
    
    # Keep cache of any old state.
    # Note special handling of * for array unset - prefix with \\ to quote.
    array unset oldpresA [jlib::ESC $mjid],*
    array set oldpresA [array get presA [jlib::ESC $mjid],*]
    
    # Clear out the old presence state since elements may still be lurking.
    array unset presA [jlib::ESC $mjid],*

    # Add to list of resources.
    set presA($mjid2,res) [lsort -unique [lappend presA($mjid2,res) $res]]

    set presA($mjid,type) $type

    foreach E [wrapper::getchildren $xmldata] {
	set tag [wrapper::gettag $E]
	set chdata [wrapper::getcdata $E]
	
	switch -- $tag {
	    status - priority {
		set presA($mjid,$tag) $chdata
	    }
	    show {
		set presA($mjid,$tag) [string tolower $chdata]
	    }
	    x {
		set ns [wrapper::getattribute $E xmlns]
		regexp {http://jabber.org/protocol/(.*)$} $ns - ns
		set presA($mjid,x,$ns) $E
	    }
	    default {

		# This can be anything properly namespaced.
		set ns [wrapper::getattribute $E xmlns]
		set presA($mjid,extras,$ns) $E
	    }
	}
    }    
}


# Firts attempt to keep the jid's as they are reported, with no separate
# resource part.

proc jlib::roster::setpresence2 {jlibname xmldata} { 


}

# jlib::roster::getrosteritem --
#
#       Returns the state of an existing roster item.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        .
#       
# Results:
#       a list of '-key value' pairs where key is any of: 
#       name, groups, subscription, ask. Note GROUPS in plural!

proc jlib::roster::getrosteritem {jlibname jid} {    

    variable rostGlobals
    upvar ${jlibname}::roster::rostA rostA
    upvar ${jlibname}::roster::options options
    
    Debug 2 "roster::getrosteritem jid='$jid'"
    
    set mjid [jlib::jidmap $jid]
    if {![info exists rostA($mjid,item)]} {
	return {}
    }
    set result [list]
    foreach key $rostGlobals(tags) {
	if {[info exists rostA($mjid,$key)]} {
	    lappend result -$key $rostA($mjid,$key)
	}
    }
    return $result
}

proc jlib::roster::getitem {jlibname jid} {
 
    upvar ${jlibname}::roster::itemA itemA

    set mjid [jlib::jidmap $jid]
    if {[info exists itemA($mjid)]} {
	return $itemA($mjid)
    } else {
	return {}
    }
}

# jlib::roster::isitem --
# 
#       Does the jid exist in the roster?

proc jlib::roster::isitem {jlibname jid} {
    
    upvar ${jlibname}::roster::rostA rostA
    
    set mjid [jlib::jidmap $jid]
    return [expr {[info exists rostA($mjid,item)] ? 1 : 0}]
}

# jlib::roster::getrosterjid --
# 
#       Returns the matching jid as reported by a roster item.
#       If given a full JID try match this, else bare JID.
#       If given a bare JID try match this.
#       It cannot find a full JID from a bare JID.
#       For ordinary users this is a jid2.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        
#       
# Results:
#       a jid or empty if no matching roster item.

proc jlib::roster::getrosterjid {jlibname jid} {
    
    upvar ${jlibname}::roster::rostA rostA

    set mjid [jlib::jidmap $jid]
    if {[info exists rostA($mjid,item)]} {
	return $jid
    } else {
	set mjid2 [jlib::barejid $mjid]
	if {[info exists rostA($mjid2,item)]} {
	    return [jlib::barejid $jid]
	} else {
	    return ""
	}
    }
}

# jlib::roster::getusers --
#
#       Returns a list of jid's of all existing roster items.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       args:       -type available|unavailable
#       
# Results:
#       list of all 2-tier jid's in roster

proc jlib::roster::getusers {jlibname args} {

    upvar ${jlibname}::roster::rostA rostA
    upvar ${jlibname}::roster::presA presA    
    
    set all {}
    foreach {x jid} [array get rostA *,item] {
	lappend all $jid
    }
    array set argsA $args
    set jidlist {}
    if {$args == {}} {
	set jidlist $all
    } elseif {[info exists argsA(-type)]} {
	set type $argsA(-type)
	set jidlist {}
	foreach jid2 $all {
	    set isavailable 0

	    # Be sure to handle empty resources as well: '1234@icq.host'
	    foreach key [array names presA "[jlib::ESC $jid2]*,type"] {
		if {[string equal $presA($key) "available"]} {
		    set isavailable 1
		    break
		}
	    }
	    if {$isavailable && [string equal $type "available"]} {
		lappend jidlist $jid2
	    } elseif {!$isavailable && [string equal $type "unavailable"]} {
		lappend jidlist $jid2
	    }
	}	
    }
    return $jidlist
}

# jlib::roster::getpresence --
#
#       Returns the presence state of an existing roster item.
#       This is as reported in presence element.
#
# Arguments:
#       jlibname:   the instance of this jlib.
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
#       BAD!!!!!!!!!!!!!!!!!!!!!!!!

proc jlib::roster::getpresence {jlibname jid args} {    

    variable rostGlobals
    upvar ${jlibname}::roster::rostA rostA
    upvar ${jlibname}::roster::presA presA
    upvar ${jlibname}::roster::options options
    
    Debug 2 "roster::getpresence jid=$jid, args='$args'"
    
    set jid [jlib::jidmap $jid]
    array set argsA $args
    set haveRes 0
    if {[info exists argsA(-resource)]} {
	set haveRes 1
	set resource $argsA(-resource)
    }
    
    # It may happen that there is no roster item for this jid (groupchat).
    if {![info exists presA($jid,res)] || ($presA($jid,res) eq "")} {
	if {[info exists argsA(-type)] &&  \
	  [string equal $argsA(-type) "available"]} {
	    return
	} else {
	    if {$haveRes} {
		return [list -resource $resource -type unavailable]
	    } else {      
		return [list [list -resource "" -type unavailable]]
	    }
	}
    }
    
    set result [list]
    if {$haveRes} {

	# Return presence only from the specified resource.
	# Be sure to handle empty resources as well: '1234@icq.host'
	if {[lsearch -exact $presA($jid,res) $resource] < 0} {
	    return [list -resource $resource -type unavailable]
	}
	set result [list -resource $resource]
	if {$resource eq ""} {
	    set jid3 $jid
	} else {
	    set jid3 $jid/$resource
	}
	if {[info exists argsA(-type)] &&  \
	  ![string equal $argsA(-type) $presA($jid3,type)]} {
	    return
	}
	foreach key $rostGlobals(presTags) {
	    if {[info exists presA($jid3,$key)]} {
		lappend result -$key $presA($jid3,$key)
	    }
	}
    } else {
	
	# Get presence for all resources.
	# Be sure to handle empty resources as well: '1234@icq.host'
	foreach res $presA($jid,res) {
	    set thisRes [list -resource $res]
	    if {$res eq ""} {
		set jid3 $jid
	    } else {
		set jid3 $jid/$res
	    }
	    if {[info exists argsA(-type)] &&  \
	      ![string equal $argsA(-type) $presA($jid3,type)]} {
		# Empty.
	    } else {
		foreach key $rostGlobals(presTags) {
		    if {[info exists presA($jid3,$key)]} {
			lappend thisRes -$key $presA($jid3,$key)
		    }
		}
		lappend result $thisRes
	    }
	}
    }
    return $result
}

# UNFINISHED!!!!!!!!!!
# Return empty list or -type unavailable ???
# '-key value' or 'key value' ???
# Returns a list of flat arrays

proc jlib::roster::getpresence2 {jlibname jid args} {    

    variable rostGlobals
    upvar ${jlibname}::roster::rostA rostA
    upvar ${jlibname}::roster::presA2 presA2
    upvar ${jlibname}::roster::options options
    
    Debug 2 "roster::getpresence2 jid=$jid, args='$args'"
    
    array set argsA {
	-type *
    }
    array set argsA $args

    set mjid [jlib::jidmap $jid]
    jlib::splitjid $mjid jid2 resource
    set result {}
    
    if {$resource eq ""} {
	
	# 2-tier jid. Match any resource.
	set arrlist [concat [array get presA2 [jlib::ESC $mjid],jid] \
                         [array get presA2 [jlib::ESC $mjid]/*,jid]]
	foreach {key value} $arrlist {
	    set thejid $value
	    set jidresult {}
	    foreach {akey avalue} [array get presA2 [jlib::ESC $thejid],*] {
		set thekey [string map [list $thejid, ""] $akey]
		lappend jidresult -$thekey $avalue
	    }
	    if {[llength $jidresult]} {
		lappend result $jidresult
	    }
	}
    } else {
	
	# 3-tier jid. Only exact match.
	if {[info exists presA2($mjid,type)]} {
	    if {[string match $argsA(-type) $presA2($mjid,type)]} {
		set result [list [list -jid $jid -type $presA2($mjid,type)]]
	    }
	} else {
	    set result [list [list -jid $jid -type unavailable]]
	}
    }
    return $result
}

# jlib::roster::getoldpresence --
# 
#       This makes a simplified assumption and uses the full JID.

proc jlib::roster::getoldpresence {jlibname jid} {    

    variable rostGlobals
    upvar ${jlibname}::roster::rostA rostA
    upvar ${jlibname}::roster::oldpresA oldpresA

    set jid [jlib::jidmap $jid]
    
    if {[info exists oldpresA($jid,type)]} {
	set result [list]
	foreach key $rostGlobals(presTags) {
	    if {[info exists oldpresA($jid,$key)]} {
		lappend result -$key $oldpresA($jid,$key)
	    }
	}	
    } else {
	set result [list -type unavailable]
    }
    return $result
}

# jlib::roster::getgroups --
#
#       Returns the list of groups for this jid, or an empty list if not 
#       exists. If no jid, return a list of all groups existing in this roster.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        (optional).
#       
# Results:
#       a list of groups or empty.

proc jlib::roster::getgroups {jlibname {jid {}}} {    

    upvar ${jlibname}::roster::rostA rostA
   
    Debug 2 "roster::getgroups jid='$jid'"
    
    set jid [jlib::jidmap $jid]
    if {[string length $jid]} {
	if {[info exists rostA($jid,groups)]} {
	    return $rostA($jid,groups)
	} else {
	    return
	}
    } else {
	set rostA(groups) [lsort -unique $rostA(groups)]
	return $rostA(groups)
    }
}

# jlib::roster::getname --
#
#       Returns the roster name of this jid.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        
#       
# Results:
#       the roster name or empty.

proc jlib::roster::getname {jlibname jid} {

    upvar ${jlibname}::roster::rostA rostA
       
    set jid [jlib::jidmap $jid]
    if {[info exists rostA($jid,name)]} {
	return $rostA($jid,name)
    } else {
	return ""
    }
}

# jlib::roster::getsubscription --
#
#       Returns the 'subscription' state of this jid.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        
#       
# Results:
#       the 'subscription' state or "none" if no 'subscription' state.

proc jlib::roster::getsubscription {jlibname jid} {

    upvar ${jlibname}::roster::rostA rostA
       
    set jid [jlib::jidmap $jid]
    if {[info exists rostA($jid,subscription)]} {
	return $rostA($jid,subscription)
    } else {
	return none
    }
}

# jlib::roster::getask --
#
#       Returns the 'ask' state of this jid.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        
#       
# Results:
#       the 'ask' state or empty if no 'ask' state.

proc jlib::roster::getask {jlibname jid} {

    upvar ${jlibname}::roster::rostA rostA
   
    Debug 2 "roster::getask jid='$jid'"
    
    if {[info exists rostA($jid,ask)]} {
	return $rostA($jid,ask)
    } else {
	return ""
    }
}

# jlib::roster::getresources --
#
#       Returns a list of all resources for this jid or empty.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        a jid without any resource (jid2).
#       args        ?-type?
#                   -type: return presence for (un)available only.
#       
# Results:
#       a list of all resources for this jid or empty.

proc jlib::roster::getresources {jlibname jid args} {

    upvar ${jlibname}::roster::presA presA
   
    Debug 2 "roster::getresources jid='$jid'"
    array set argsA $args
    
    set jid [jlib::jidmap $jid]
    if {[info exists presA($jid,res)]} {
	if {[info exists argsA(-type)]} {
	    
	    # Need to loop through all resources for this jid.
	    set resL [list]
	    set type $argsA(-type)
	    foreach res $presA($jid,res) {

		# Be sure to handle empty resources as well: '1234@icq.host'
		if {$res eq ""} {
		    set jid3 $jid
		} else {
		    set jid3 $jid/$res
		}
		if {[string equal $argsA(-type) $presA($jid3,type)]} {
		    lappend resL $res
		}
	    }
	    return $resL
	} else {
	    return $presA($jid,res)
	}
    } else {
	return ""
    }
}

proc jlib::roster::getmatchingjids2 {jlibname jid args} {
    
    upvar ${jlibname}::roster::presA2 presA2
    
    set jidlist {}
    set arrlist [concat [array get presA2 [jlib::ESC $mjid],jid] \
      [array get presA2 [jlib::ESC $mjid]/*,jid]]
    foreach {key value} $arrlist {
	lappend jidlist $value
    }
    return $jidlist
}

# jlib::roster::gethighestresource --
#
#       Returns the resource with highest priority for this jid or empty.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        a jid without any resource (jid2).
#       
# Results:
#       a resource for this jid or empty if unavailable.

proc jlib::roster::gethighestresource {jlibname jid} {

    upvar ${jlibname}::roster::presA presA
   
    Debug 2 "roster::gethighestresource jid='$jid'"
    
    set jid [jlib::jidmap $jid]
    set maxres ""
    if {[info exists presA($jid,res)]} {
	
	# Find the resource corresponding to the highest priority (D=0).
	set maxpri 0
	set maxres [lindex $presA($jid,res) 0]
	foreach res $presA($jid,res) {

	    # Be sure to handle empty resources as well: '1234@icq.host'
	    if {$res eq ""} {
		set jid3 $jid
	    } else {
		set jid3 $jid/$res
	    }
	    if {[info exists presA($jid3,type)]} {
		if {$presA($jid3,type) eq "available"} {
		    if {[info exists presA($jid3,priority)]} {
			if {$presA($jid3,priority) > $maxpri} {
			    set maxres $res
			    set maxpri $presA($jid3,priority)
			}
		    }
		}
	    }
	}
    }
    return $maxres
}

proc jlib::roster::getmaxpriorityjid2 {jlibname jid} {

    upvar ${jlibname}::roster::presA2 presA2
   
    Debug 2 "roster::getmaxpriorityjid2 jid='$jid'"
    
    # Find the resource corresponding to the highest priority (D=0).
    set maxjid ""
    set maxpri 0
    foreach jid3 [getmatchingjids2 $jlibname $jid] {
	if {[info exists presA2($jid3,priority)]} {
	    if {$presA2($jid3,priority) > $maxpri} {
		set maxjid $jid3
		set maxpri $presA2($jid3,priority)
	    }
	}
    }
    return $jid3
}

# jlib::roster::isavailable --
#
#       Returns boolean 0/1. Returns 1 only if presence is equal to available.
#       If 'jid' without resource, return 1 if any is available.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        either 'username$hostname', or 'username$hostname/resource'.
#       
# Results:
#       0/1.

proc jlib::roster::isavailable {jlibname jid} {

    upvar ${jlibname}::roster::presA presA
   
    Debug 2 "roster::isavailable jid='$jid'"
        
    set jid [jlib::jidmap $jid]

    # If any resource in jid, we get it here.
    jlib::splitjid $jid jid2 resource

    if {[string length $resource] > 0} {
	if {[info exists presA($jid2/$resource,type)]} {
	    if {[string equal $presA($jid2/$resource,type) "available"]} {
		return 1
	    } else {
		return 0
	    }
	} else {
	    return 0
	}
    } else {
	
	# Be sure to allow for 'user@domain' with empty resource.
	foreach key [array names presA "[jlib::ESC $jid2]*,type"] {
	    if {[string equal $presA($key) "available"]} {
		return 1
	    }
	}
	return 0
    }
}

proc jlib::roster::isavailable2 {jlibname jid} {

    upvar ${jlibname}::roster::presA2 presA2
   
    Debug 2 "roster::isavailable jid='$jid'"
	
    set jid [jlib::jidmap $jid]

    # If any resource in jid, we get it here.
    jlib::splitjid $jid jid2 resource

    if {[string length $resource] > 0} {
	if {[info exists presA($jid2/$resource,type)]} {
	    if {[string equal $presA($jid2/$resource,type) "available"]} {
		return 1
	    } else {
		return 0
	    }
	} else {
	    return 0
	}
    } else {
	
	# Be sure to allow for 'user@domain' with empty resource.
	foreach key [array names presA "[jlib::ESC $jid2]*,type"] {
	    if {[string equal $presA($key) "available"]} {
		return 1
	    }
	}
	return 0
    }
}

# jlib::roster::wasavailable --
#
#       As 'isavailable' but for any "old" former presence state.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        either 'username$hostname', or 'username$hostname/resource'.
#       
# Results:
#       0/1.

proc jlib::roster::wasavailable {jlibname jid} {

    upvar ${jlibname}::roster::oldpresA oldpresA
   
    Debug 2 "roster::wasavailable jid='$jid'"
	
    set jid [jlib::jidmap $jid]

    # If any resource in jid, we get it here.
    jlib::splitjid $jid jid2 resource

    if {[string length $resource] > 0} {
	if {[info exists oldpresA($jid2/$resource,type)]} {
	    if {[string equal $oldpresA($jid2/$resource,type) "available"]} {
		return 1
	    } else {
		return 0
	    }
	} else {
	    return 0
	}
    } else {
	
	# Be sure to allow for 'user@domain' with empty resource.
	foreach key [array names oldpresA "[jlib::ESC $jid2]*,type"] {
	    if {[string equal $oldpresA($key) "available"]} {
		return 1
	    }
	}
	return 0
    }
}

# jlib::roster::gettype --
# 
#       Returns "available" or "unavailable".

proc jlib::roster::gettype {jlibname jid} {
    
    upvar ${jlibname}::roster::presA presA
       
    set jid [jlib::jidmap $jid]    
    if {[info exists presA($jid,type)]} {
	return $presA($jid,type)
    } else {
	return "unavailable"
    }
}

proc jlib::roster::getshow {jlibname jid} {
      
    upvar ${jlibname}::roster::presA presA
       
    set jid [jlib::jidmap $jid]    
    if {[info exists presA($jid,show)]} {
	return $presA($jid,show)
    } else {
	return ""
    }
}
proc jlib::roster::getstatus {jlibname jid} {
      
    upvar ${jlibname}::roster::presA presA
       
    set jid [jlib::jidmap $jid]    
    if {[info exists presA($jid,status)]} {
	return $presA($jid,status)
    } else {
	return ""
    }
}

# jlib::roster::getx --
#
#       Returns the xml list for this jid's x element with given xml namespace.
#       Returns empty if no matching info.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        any jid
#       xmlns:      the (mandatory) xmlns specifier. Any prefix
#                   http://jabber.org/protocol/ must be stripped off.
#                   @@@ BAD!!!!
#       
# Results:
#       xml list or empty.

proc jlib::roster::getx {jlibname jid xmlns} {

    upvar ${jlibname}::roster::presA presA
   
    set jid [jlib::jidmap $jid]
    if {[info exists presA($jid,x,$xmlns)]} {
	return $presA($jid,x,$xmlns)
    } else {
	return
    }
}

# jlib::roster::getextras --
#
#       Returns the xml list for this jid's extras element with given xml namespace.
#       Returns empty if no matching info.
#
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        any jid
#       xmlns:      the (mandatory) full xmlns specifier.
#       
# Results:
#       xml list or empty.

proc jlib::roster::getextras {jlibname jid xmlns} {

    upvar ${jlibname}::roster::presA presA
   
    set jid [jlib::jidmap $jid]
    if {[info exists presA($jid,extras,$xmlns)]} {
	return $presA($jid,extras,$xmlns)
    } else {
	return
    }
}

# jlib::roster::getcapsattr --
# 
#       Access function for the <c/> caps elements attributes:
#       
#       <presence>
#           <c 
#               xmlns='http://jabber.org/protocol/caps' 
#               node='http://coccinella.sourceforge.net/protocol/caps'
#               ver='0.95.2'
#               ext='ftrans voip_h323 voip_sip'/>
#       </presence>
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#       jid:        any jid
#       attrname:   
#       
# Results:
#       the value of the attribute or empty

proc jlib::roster::getcapsattr {jlibname jid attrname} {
    
    upvar jlib::jxmlns jxmlns
    upvar ${jlibname}::roster::presA presA

    set attr ""
    set jid [jlib::jidmap $jid]
    set xmlnscaps $jxmlns(caps)
    if {[info exists presA($jid,extras,$xmlnscaps)]} {
	set cElem $presA($jid,extras,$xmlnscaps)
	set attr [wrapper::getattribute $cElem $attrname]
    }
    return $attr
}

proc jlib::roster::havecaps {jlibname jid} {
    
    upvar jlib::jxmlns jxmlns
    upvar ${jlibname}::roster::presA presA

    set xmlnscaps $jxmlns(caps)
    return [info exists presA($jid,extras,$xmlnscaps)]
}

# jlib::roster::availablesince --
# 
#       Not sure exactly how delay elements are updated when new status set.

proc jlib::roster::availablesince {jlibname jid} {
    
    upvar ${jlibname}::roster::presA presA
    upvar ${jlibname}::roster::state state

    set jid [jlib::jidmap $jid]
    set xmlns "jabber:x:delay"
    if {[info exists presA($jid,x,$xmlns)]} {
	 
	 # An ISO 8601 point-in-time specification. clock works!
	 set stamp [wrapper::getattribute $presA($jid,x,$xmlns) stamp]
	 set time [clock scan $stamp -gmt 1]
     } elseif {[info exists state($jid,secs)]} {
	 set time $state($jid,secs)
     } else {
	 set time ""
     }
     return $time
}

proc jlib::roster::getpresencesecs {jlibname jid} {
    
    upvar ${jlibname}::roster::state state

    set jid [jlib::jidmap $jid]
    if {[info exists state($jid,secs)]} {
	return $state($jid,secs)
    } else {
	return ""
    }
}

proc jlib::roster::Debug {num str} {
    variable rostGlobals
    if {$num <= $rostGlobals(debug)} {
	puts "===========$str"
    }
}

# We have to do it here since need the initProc before doing this.

namespace eval jlib::roster {
    
    jlib::ensamble_register roster  \
      [namespace current]::init    \
      [namespace current]::cmdproc
}

#-------------------------------------------------------------------------------
