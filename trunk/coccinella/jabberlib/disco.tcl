#  disco.tcl --
#  
#      This file is part of the jabberlib.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: disco.tcl,v 1.10 2004-04-30 12:58:46 matben Exp $
# 
############################# USAGE ############################################
#
#   NAME
#      disco - convenience command library for the disco part of XMPP.
#      
#   SYNOPSIS
#      disco::new jlibName ?-opt value ...?
#
#   OPTIONS
#	-command tclProc
#	
#   INSTANCE COMMANDS
#      discoName children jid ?node?
#      discoName send_get discotype jid callbackProc ?-opt value ...?
#      discoName isdiscoed discotype jid ?node?
#      discoName get discotype jid key ?node?
#      discoName getallcategories pattern
#      discoName getconferences
#      discoName getjidsforcategory pattern
#      discoName getjidsforfeature feature
#      discoName features jid ?node?
#      discoName hasfeature feature jid ?node?
#      discoName isroom jid
#      discoName name jid ?node?
#      discoName parent jid ?node?
#      discoName parents jid ?node?
#      discoName types jid ?node?
#      discoName reset ?jid?
#      
#      where discotype = (items|info)
#      
############################# CHANGES ##########################################
#
#       0.1         first version

package require jlib

package provide disco 0.1

namespace eval disco {
    
    # Globals same for all instances of this jlib.
    variable debug 0
    if {[info exists ::debugLevel] && ($::debugLevel > 1) && ($debug == 0)} {
	set debug 2
    }
        
    variable version 0.1
    
    # Running number.
    variable uid 0
    
    # Common xml namespaces.
    variable xmlns
    array set xmlns {
	disco           http://jabber.org/protocol/disco 
	items           http://jabber.org/protocol/disco#items 
	info            http://jabber.org/protocol/disco#info
    }
}

# disco::new --
# 
#       Creates a new instance of the disco object.
#       
# Arguments:
#       jlibname:     name of existing jabberlib instance
#       args:         -command procName
# 
# Results:
#       namespaced instance command

proc disco::new {jlibname args} {
    
    variable uid
    variable xmlns
    variable disco2jlib
    
    # Generate unique command token for this disco instance.
    # Fully qualified!
    set disconame [namespace current]::[incr uid]
    
    # Instance specific arrays.
    namespace eval $disconame {
	variable items
	variable info
	variable priv
    }
    upvar ${disconame}::items items
    upvar ${disconame}::info  info
    upvar ${disconame}::priv  priv

    foreach {key value} $args {
	switch -- $key {
	    -command {
		set priv(cmd) $value
	    }
	    default {
		return -code error "unrecognized option \"$key\" for disco::new"
	    }
	}
    }
    set disco2jlib($disconame) $jlibname
    
    # Register service.
    $jlibname service register disco $disconame
    
    # Register some standard iq handlers that is handled internally.
    $jlibname iq_register get $xmlns(items)  \
      [list [namespace current]::handle_get $disconame items]
    $jlibname iq_register get $xmlns(info)   \
      [list [namespace current]::handle_get $disconame info]
    
    # Create the actual disco instance procedure.
    proc $disconame {cmd args}  \
      "eval disco::cmdproc {$disconame} \$cmd \$args"
    
    set info(conferences) {}
    
    return $disconame
}

# disco::cmdproc --
#
#       Just dispatches the command to the right procedure.
#
# Arguments:
#       disconame:  the instance of this disco.
#       cmd:        
#       args:       all args to the cmd procedure.
#       
# Results:
#       none.

proc disco::cmdproc {disconame cmd args} {
    
    # Which command? Just dispatch the command to the right procedure.
    return [eval $cmd $disconame $args]
}

# disco::send_get --
#
#       Sends a get request within the disco namespace.
#
# Arguments:
#       disconame:  the instance of this disco.
#       type:       items|info
#       jid:        to jid
#       cmd:        callback tcl proc        
#       args:       -node chdata
#       
# Results:
#       none.

proc disco::send_get {disconame type jid cmd args} {
    
    variable xmlns
    variable disco2jlib
    
    array set argsArr $args
    set opts {}
    if {[info exists argsArr(-node)]} {
	lappend opts -node $argsArr(-node)
    }
    
    eval {$disco2jlib($disconame) iq_get $xmlns($type) -to $jid  \
      -command [list [namespace current]::parse_get $disconame $type $jid $cmd]} \
      $opts
}

# disco::parse_get --
# 
#       Fills in the internal state arrays, and invokes any callback.

proc disco::parse_get {disconame discotype from cmd jlibname type subiq args} {
    
    variable disco2jlib
    upvar ${disconame}::items items
    upvar ${disconame}::info  info

    # We need to use both jid and any node for addressing since
    # each item may have identical jid's but different node's.

    # Parents node if any.
    array set pattr [wrapper::getattrlist $subiq]
    set pnode ""
    if {[info exists pattr(node)]} {
	set pnode $pattr(node)
    }
    
    if {[string equal $type "error"]} {

	# Empty.
    } else {
	if {[string equal $discotype "items"]} {
	    set items($from,$pnode,xml) $subiq
	    catch {unset items($from,$pnode,children) items($from,$pnode,nodes)}
	    
	    # testing...
	    # This is perhaps not a robust way.
	    if {![info exists items($from,$pnode,parent)]} {
		set items($from,$pnode,parent) {}
		set items($from,$pnode,parents) {}
	    }
	    
	    foreach c [wrapper::getchildren $subiq] {
		if {![string equal [wrapper::gettag $c] "item"]} {
		    continue
		}
		catch {unset attr}
		array set attr [wrapper::getattrlist $c]

		# jid is a required attribute!
		set jid $attr(jid)
		set node ""
		if {[info exists attr(node)]} {
		    set node $attr(node)
		    lappend items($from,$pnode,nodes) $node
		}
		lappend items($from,$node,children) $jid
		set items($jid,$node,parent) $from
		if {[info exists items($from,$pnode,parents)]} {
		    set items($jid,$pnode,parents)  \
		      [concat $items($from,$pnode,parents) $from]
		}
		
		foreach {key value} [array get attr] { 
		    if {![string equal $key jid]} {
			# Typically only the name attribute.
			set items($jid,$node,$key) $value
		    }
		}
	    }	
	} elseif {[string equal $discotype "info"]} {
	    array unset info "$from,$pnode,*"
	    set info($from,$pnode,xml) $subiq
	    
	    foreach c [wrapper::getchildren $subiq] {
		catch {unset attr}
		array set attr [wrapper::getattrlist $c]
		
		# There can be one or many of each 'identity' and 'feature'.
		switch -- [wrapper::gettag $c] {
		    identity {
			
			# Each <identity/> element MUST possess 'category' and 
			# 'type' attributes. (category/type)
			# Each identity element SHOULD have the same name value.
			set category $attr(category)
			set ctype    $attr(type)
			set name     ""
			if {[info exists attr(name)]} {
			    set name $attr(name)
			}			
			set info($from,$pnode,name) $name
			set cattype $category/$ctype
			lappend info($from,$pnode,cattypes) $cattype
			lappend info($cattype,typelist) $from
			set info($cattype,typelist) \
			  [lsort -unique $info($cattype,typelist)]
			
			if {![string match *@* $from]} {

			    switch -- $category {
				conference {
				    lappend info(conferences) $from
				}
			    }
			}
		    }
		    feature {
			set feature $attr(var)
			lappend info($from,$pnode,features) $feature
			lappend info($feature,featurelist) $from
			
			# Register any groupchat protocol with jlib.
			# Note that each room also returns gc features; skip!
			if {![string match *@* $from]} {
			    
			    switch -- $feature {
				"http://jabber.org/protocol/muc" {
				    $disco2jlib($disconame) service \
				      registergcprotocol $from "muc"
				}
				"jabber:iq:conference" {
				    $disco2jlib($disconame) service \
				      registergcprotocol $from "conference"
				}
				"gc-1.0" {
				    $disco2jlib($disconame) service \
				      registergcprotocol $from "gc-1.0"
				}
			    }
			}
		    }
		}
	    }
	}
    }
    
    # Invoke callback for this get.
    uplevel #0 $cmd [list $disconame $type $from $subiq] $args
    #uplevel #0 $cmd [list $type $from $subiq] $args
}

proc disco::isdiscoed {disconame discotype jid {node ""}} {
    
    upvar ${disconame}::items items
    upvar ${disconame}::info  info
    
    switch -- $discotype {
	items {
	    return [info exists items($jid,$node,xml)]
	}
	info {
	    return [info exists info($jid,$node,xml)]
	}
    }
}

proc disco::get {disconame discotype jid key {node ""}} {
    
    upvar ${disconame}::items items
    upvar ${disconame}::info  info
    
    switch -- $discotype {
	items {
	    if {[info exists items($jid,$node,$key)]} {
		return $items($jid,$node,$key)
	    }
	}
	info {
	    if {[info exists info($jid,$node,$key)]} {
		return $info($jid,$node,$key)
	    }
	}
    }
    return ""
}

# Both the items and the info elements may have name attributes! Related???

proc disco::nameINFO {disconame jid {node ""}} {
    
    upvar ${disconame}::info  info
    
    if {[info exists info($jid,$node,name)]} {
	return $info($jid,$node,name)
    } else {
	return {}
    }
}

#       The login servers jid name attribute is not returned via any items
#       element; only via info/identity element. 
#       

proc disco::name {disconame jid {node ""}} {
    
    upvar ${disconame}::items items
    upvar ${disconame}::info  info
    
    if {[info exists items($jid,$node,name)]} {
	return $items($jid,$node,name)
    } elseif {[info exists info($jid,$node,name)]} {
	return $info($jid,$node,name)
    } else {
	return {}
    }
}

proc disco::features {disconame jid {node ""}} {
    
    upvar ${disconame}::info info
    
    if {[info exists info($jid,$node,features)]} {
	return $info($jid,$node,features)
    } else {
	return {}
    }
}

proc disco::hasfeature {disconame feature jid  {node ""}} {
    
    upvar ${disconame}::info info

    if {[info exists info($jid,$node,features)]} {
	return [expr [lsearch $info($jid,$node,features) $feature] < 0 ? 0 : 1]
    } else {
	return 0
    }
}

proc disco::types {disconame jid {node ""}} {
    
    upvar ${disconame}::info info
    
    if {[info exists info($jid,$node,cattypes)]} {
	return $info($jid,$node,cattypes)
    } else {
	return {}
    }
}


proc disco::getjidsforfeature {disconame feature} {
    
    upvar ${disconame}::info info
    
    if {[info exists info($feature,featurelist)]} {
	set info($feature,featurelist) [lsort -unique $info($feature,featurelist)]
	return $info($feature,featurelist)
    } else {
	return {}
    }
}

# disco::getjidsforcategory --
#
#       Returns all jids that match the glob pattern category/type.
#       
# Arguments:
#       disconame:    the instance of this disco instance.
#       catpattern:   a global pattern of jid type/subtype (service/*).
#
# Results:
#       List of jid's matching the type pattern. nodes???

proc disco::getjidsforcategory {disconame catpattern} {
    
    upvar ${disconame}::info info
    
    set jidlist {}    
    foreach {key jid} [array get info "${catpattern},typelist"] {
	lappend jidlist $jid
    }
    return $jidlist
}    

# disco::getallcategories --
#
#       Returns all categories that match the glob pattern catpattern.
#       
# Arguments:
#       disconame:    the instance of this disco instance.
#       catpattern:   a global pattern of jid type/subtype (service/*).
#
# Results:
#       List of types matching the category/type pattern.

proc disco::getallcategories {disconame catpattern} {    
    
    upvar ${disconame}::info info
    
    set ans {}
    foreach {key catlist} [array get info *,cattypes] {
	lappend ans $catlist
    }
    return [lsort -unique $ans]
}    

proc disco::getconferences {disconame} {
    
    upvar ${disconame}::info info

    return $info(conferences)
}

proc disco::isroom {disconame jid} {
    
    upvar ${disconame}::info  info
    
    # Use the form of the jid to get the service.
    if {[regexp {^[^@/]+@([^@/]+)$} $jid match service]} {
	return [expr ([lsearch -exact $info(conferences) $service] < 0) ? 0 : 1]
    } else {
	return 0
    }
}

proc disco::children {disconame jid {node ""}} {
    
    upvar ${disconame}::items items

    if {[info exists items($jid,$node,children)]} {
	return $items($jid,$node,children)
    } else {
	return {}
    }
}

# How to return nodes???

proc disco::parent {disconame jid {node ""}} {
    
    upvar ${disconame}::items items

    if {[info exists items($jid,$node,parent)]} {
	return $items($jid,$node,parent)
    } else {
	return {}
    }
}

proc disco::parents {disconame jid {node ""}} {
    
    upvar ${disconame}::items items

    if {[info exists items($jid,$node,parents)]} {
	return $items($jid,$node,parents)
    } else {
	return {}
    }
}

proc disco::handle_get {disconame discotype jlibname from subiq args} {
    
    upvar ${disconame}::priv priv

    set ishandled 0
    if {[info exists priv(cmd)]} {
	set ishandled [uplevel #0 $priv(cmd)  \
	  [list $disconame $discotype $from $subiq] $args]
    }
    return $ishandled
}

# disco::reset --
# 
#       Clear this particular jid and all its children.

proc disco::reset {disconame {jid ""} {node ""}} {
    
    upvar ${disconame}::items items

    # Can be problems with this (ICQ) ???
    if {[info exists items($jid,$node,children)]} {
	foreach child $items($jid,$node,children) {
	    reset $disconame $child
	}
    }
    resetjid $disconame $jid
}

# disco::resetjid --
# 
#       Clear only this particular jid.

proc disco::resetjid {disconame {jid ""} {node ""}} {
    
    upvar ${disconame}::items items
    upvar ${disconame}::info  info

    if {$jid == ""} {
	catch {unset items info}
	set info(conferences) {}
    } else {
	
	# Keep parents!
	if {[info exists items($jid,$node,parent)]} {
	    set parent $items($jid,$node,parent)
	}
	if {[info exists items($jid,$node,parents)]} {
	    set parents $items($jid,$node,parents)
	}
	
	array unset items $jid,$node,*
	array unset info $jid,$node,*
	
	# Add back parent(s).
	if {[info exists parent]} {
	    set items($jid,$node,parent) $parent
	}
	if {[info exists parents]} {
	    set items($jid,$node,parents) $parents
	}
	
	# Rest.
	foreach {key value} [array get info "*,typelist"] {
	    set info($key) [lsearch -all -not -inline -exact $value $jid]
	}
	foreach {key value} [array get info "*,featurelist"] {
	    set info($key) [lsearch -all -not -inline -exact $value $jid]
	}
    }
}

proc disco::Debug {num str} {
    variable debug
    if {$num <= $debug} {
	puts $str
    }
}

#-------------------------------------------------------------------------------
