#  caps.tcl --
#  
#   This file is part of the jabberlib. It handles the internal cache
#   for caps (xmlns='http://jabber.org/protocol/caps') XEP-0115.
#      
#   A typical caps element looks like:
#   
#   <presence>
#      <c xmlns='http://jabber.org/protocol/caps'
#          node='http://exodus.jabberstudio.org/caps'
#          ver='0.9'
#          ext='tins ftrans xhtml'/>
#   </presence> 
#      
#  The core function of caps is a mapping:
#     
#     jid -> node+ver -> disco info
#     jid -> node+ext -> disco info
#  
#  Copyright (c) 2005-2006  Mats Bengtsson
#  
# $Id: caps.tcl,v 1.17 2006-12-01 08:55:14 matben Exp $
# 
############################# USAGE ############################################
#
#   NAME
#      caps - convenience command library for caps: Entity Capabilities 
#      
#   INSTANCE COMMANDS
#      jlibname caps disco_ver jid cmd
#      jlibname caps disco_ext jid ext cmd
#      
#      The callbacks cmd must look like:
#      
#      	    tclProc {jlibname type from subiq args}
#      	    
#      and the 'from' argument must not be the jid from the original call.

package require jlib::disco
package require jlib::roster

package provide jlib::caps 0.1

namespace eval jlib::caps {
    
    variable xmlns
    set xmlns(caps) "http://jabber.org/protocol/caps"
    
    
    # Note: jlib::ensamble_register is last in this file!
}

proc jlib::caps::init {jlibname args} {
        
    namespace eval ${jlibname}::caps {
	variable state
    }
    jlib::presence_register_int $jlibname available    \
      [namespace current]::avail_cb
    jlib::presence_register_int $jlibname unavailable  \
      [namespace current]::unavail_cb
    
    jlib::register_reset $jlibname [namespace current]::reset
}

proc jlib::caps::configure {jlibname args} {
    
    # Empty so far...
    # Could think of some auto disco mechanism.
}

proc jlib::caps::cmdproc {jlibname cmd args} {
    
    # Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

# jlib::caps::disco_ver --
# 
#       Disco#info request for client#version 
#       
#       <iq type='get' to='randomuser1@capulet.com/resource'>
#           <query xmlns='http://jabber.org/protocol/disco#info'
#               node='http://exodus.jabberstudio.org/caps#0.9'/>
#       </iq> 
# 
#       We MUST have got a presence caps element for this user.
#       
#       The client that received the annotated presence sends a disco#info 
#       request to exactly one of the users that sent a particular presenece
#       element caps combination of node and ver.

proc jlib::caps::disco_ver {jlibname jid cmd} {

    set ver [$jlibname roster getcapsattr $jid ver]
    disco_what $jlibname $jid ver $ver $cmd
}

# jlib::caps::disco_ext --
# 
#       Disco the 'ext' via the caps node+ext cache.

proc jlib::caps::disco_ext {jlibname jid ext cmd} {

    disco_what $jlibname $jid ext $ext $cmd
}

# jlib::caps::disco_what --
# 
#       Internal use only. See 'disco_ver'.
#       
# Arguments:
#       what:       "ver" or "ext"
#       value:      value for 'ver' or the name of the 'ext'.

proc jlib::caps::disco_what {jlibname jid what value cmd} {
    upvar ${jlibname}::caps::state state
    
    set node [$jlibname roster getcapsattr $jid node]
        
    # There are three situations here:
    #   1) if we have cached this info just return it
    #   2) if pending disco for node+ver then just add to stack to be invoked
    #   3) else need to disco
    # This is all done per node+ver in contrast to 'disco get_async' jid+node

    set key $what,$node,$value
    
    if {[info exists state(subiq,$key)]} {
	uplevel #0 $cmd [list $jlibname result $jid $state(subiq,$key)]
    } elseif {[info exists state(pending,$key)]} {
	lappend state(invoke,$key) $cmd
    } else {
	
	# Mark that we have a pending node+ver request and add command to list.
	set state(pending,$key) 1
	lappend state(get,$key) $jid
	lappend state(invoke,$key) $cmd
	
	# It should be safe to use 'disco get_async' here.
	# Need to provide node+ver for error recovery.
	set cb [list [namespace current]::disco_cb $node $what $value]
	$jlibname disco get_async info $jid $cb -node ${node}#${value}
    }
}

# jlib::caps::disco_cb --
# 
#       Callback for 'disco get_async'.
#       We must take care of a situation where the jid went unavailable,
#       or otherwise returns an error, and try to use another jid.

proc jlib::caps::disco_cb {node what value jlibname type from subiq args} {
    upvar ${jlibname}::caps::state state

    set key $what,$node,$value

    if {$type eq "error"} {
    
	# Try to find another jid with this node+ver instead that has not
	# been previously tried.
	if {[info exists state(jids,$key)]} {
	    foreach nextjid $state(jids,$key) {
		if {[lsearch $state(get,$key) $nextjid] < 0} {
		    lappend state(get,$key) $nextjid
		    set cb [list [namespace current]::disco_cb $node $what $value]
		    $jlibname disco get_async info $nextjid $cb -node ${node}#${value}
		    return
		}
	    }
	}
	
	# We end up here when there are no more jids to ask.
    }
    set jid [jlib::jidmap $from]
    
    # Cache the returned element to be reused for all node+ver combinations.
    set state(subiq,$key) $subiq
    unset -nocomplain state(pending,$key)
    
    # Invoke all stacked requests including the the first one.
    if {[info exists state(invoke,$key)]} {
	foreach cmd $state(invoke,$key) {
	    uplevel #0 $cmd [list $jlibname $type $jid $subiq] $args
	}
	unset -nocomplain state(invoke,$key)
	unset -nocomplain state(get,$key)
    }
}

# jlib::caps::avail_cb --
# 
#       Registered available presence callback.
#       Keeps track of all jid <-> node+ver combinations.
#       The exts may be different for identical node+ver and must be
#       obtained for individual jids using 'roster getcapsattr'.

proc jlib::caps::avail_cb {jlibname xmldata} {
    upvar ${jlibname}::caps::state state
    
    set jid [wrapper::getattribute $xmldata from]
    set jid [jlib::jidmap $jid]

    set node [$jlibname roster getcapsattr $jid node]
    set ver  [$jlibname roster getcapsattr $jid ver]
    set ext  [$jlibname roster getcapsattr $jid ext]
        
    # Skip if client have not a caps presence element.
    if {$node eq ""} {
	return
    }
        	    
    # Map jid -> node+ver+ext
    set state(jid,$jid,node) $node
    set state(jid,$jid,ver)  $ver
    set state(jid,$jid,ext)  $ext
	    
    # Map node+ver -> jids    
    lappend state(jids,ver,$node,$ver) $jid
    set state(jids,ver,$node,$ver) [lsort -unique $state(jids,ver,$node,$ver)]
    
    # Map node+ext -> jids
    foreach e $ext {
	lappend state(jids,ext,$node,$e) $jid
	set state(jids,ext,$node,$e) [lsort -unique $state(jids,ext,$node,$e)]
    }

    return 0
}

# jlib::caps::unavail_cb --
# 
#       Registered unavailable presence callback.
#       Frees internal cache related to this jid.

proc jlib::caps::unavail_cb {jlibname xmldata} {
    upvar ${jlibname}::caps::state state

    set jid [wrapper::getattribute $xmldata from]
    set jid [jlib::jidmap $jid]
    
    # JID may not have caps.
    if {![info exists state(jid,$jid,node)]} {
	return
    }
    set node $state(jid,$jid,node)
    set ver  $state(jid,$jid,ver)
    set ext  $state(jid,$jid,ext)
        
    # Free node+ver -> jids mapping
    if {[info exists state(jids,ver,$node,$ver)]} {
	jlib::util::lprune state(jids,ver,$node,$ver) $jid
    }
    
    # Free node+ext -> jids mappings
    foreach e $ext {
	if {[info exists state(jids,ext,$node,$e)]} {
	    jlib::util::lprune state(jids,ext,$node,$e) $jid
	}    
    }
    array unset state jid,[jlib::ESC $jid],*

    return 0
}

proc jlib::caps::reset {jlibname} {
    upvar ${jlibname}::caps::state state
    
    unset -nocomplain state
}

# We have to do it here since need the initProc before doing this.

namespace eval jlib::caps {

    jlib::ensamble_register caps  \
      [namespace current]::init   \
      [namespace current]::cmdproc
}

# Test code:
if {0} {
    proc cb {args} {puts "------$args"}
    set jlib jlib::jlib1
    set jid sgi@sgi.se/coccinella
    $jlib caps disco_ver $jid cb
    $jlib caps disco_ext $jid ftrans cb
    
}
