#  disco.tcl --
#  
#      This file is part of the jabberlib.
#      
#  Copyright (c) 2004-2007  Mats Bengtsson
#  
# $Id: disco.tcl,v 1.47 2007-05-07 07:09:27 matben Exp $
# 
############################# USAGE ############################################
#
#   NAME
#      disco - convenience command library for the disco part of XMPP.
#      
#   SYNOPSIS
#      jlib::disco::init jlibName ?-opt value ...?
#
#   OPTIONS
#	-command tclProc
#	
#   INSTANCE COMMANDS
#      jlibname disco children jid
#      jlibname disco childs jid ?node?
#      jlibname disco send_get discotype jid cmd ?-opt value ...?
#      jlibname disco isdiscoed discotype jid ?node?
#      jlibname disco get discotype key jid ?node?
#      jlibname disco getallcategories pattern
#      jlibname disco get_async discotype jid cmd ?-node node?
#      jlibname disco getconferences
#      jlibname disco getjidsforcategory pattern
#      jlibname disco getjidsforfeature feature
#      jlibname disco features jid ?node?
#      jlibname disco hasfeature feature jid ?node?
#      jlibname disco isroom jid
#      jlibname disco iscategorytype category/type jid ?node?
#      jlibname disco name jid ?node?
#      jlibname disco nodes jid ?node?
#      jlibname disco types jid ?node?
#      jlibname disco reset ?jid ?node??
#      
#      where discotype = (items|info)
#      
################################################################################
#
# Structures:
#       items(jid,node,children)  list of any children JIDs
#       items(jid,node,childs)    list of {JID node}
#       
#       jid must always be nonempty while node may be empty.
#       
#       rooms(jid,node)             exists if children of 'conference'

# NEW: In order to manage the complex jid/node structure it is best to
#      keep an internal structure always using a pair JID+node. 
#      As array index: ($jid,$node,..) or list of childs:
#      {{JID1 node1} {JID2 node2} ..} where any of JID or node can be
#      empty but not both.
#       
#      This reflects the disco xml structure (node can be empty):
#      
#      JID node
#            JID node
#            JID node
#            ...
#            
# @@@ While 'parent -> child' is uniquely defined 'parent <- child' is NOT!
#     A certain JID+node can appear in more than one place in the disco tree!
#     It is better to use another data structure to store this.

package require jlib

package provide jlib::disco 0.1

namespace eval jlib::disco {
    
    # Globals same for all instances of this jlib.
    variable debug 0
    if {[info exists ::debugLevel] && ($::debugLevel > 1) && ($debug == 0)} {
	set debug 2
    }
        
    variable version 0.1
        
    # Common xml namespaces.
    variable xmlns
    array set xmlns {
	disco   "http://jabber.org/protocol/disco"
	items   "http://jabber.org/protocol/disco#items"
	info    "http://jabber.org/protocol/disco#info"
    }
    
    # Components register their feature elements for disco/info.
    variable features [list]

    # Note: jlib::ensamble_register is last in this file!
}

# jlib::disco::init --
# 
#       Creates a new instance of the disco object.
#       
# Arguments:
#       jlibname:     name of existing jabberlib instance
#       args:
# 
# Results:
#       namespaced instance command

proc jlib::disco::init {jlibname args} {
    
    variable xmlns
        
    # Instance specific arrays.
    namespace eval ${jlibname}::disco {
	variable items
	variable info
	variable rooms
	variable handler
	variable state
    }
    upvar ${jlibname}::disco::items items
    upvar ${jlibname}::disco::info  info
    upvar ${jlibname}::disco::rooms rooms
    
    # Register service.
    $jlibname service register disco disco
    
    # Register some standard iq handlers that is handled internally.
    $jlibname iq_register get $xmlns(items)  \
      [list [namespace current]::handle_get items]
    $jlibname iq_register get $xmlns(info)   \
      [list [namespace current]::handle_get info]

    # Clear any cache info we may have collected since likely invalid offline.
    $jlibname presence_register_int unavailable [namespace current]::unavail_cb

    # Register our own features.
    registerfeature $xmlns(disco)
    registerfeature $xmlns(items)
    registerfeature $xmlns(info)
    
    set info(conferences) [list]
    
    return
}

# jlib::disco::cmdproc --
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

proc jlib::disco::cmdproc {jlibname cmd args} {
    
    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

# jlib::disco::registerfeature --
# 
# @@@ Make instance specific instead!
# 
#       Components register their feature elements for disco#info.
#       Clients must handle this using the disco handler.
#       NB: This is only for 'basic' features not associated with a caps ext
#           token. Those are handled by jlib::caps::register.
#       NB: We consider everything inside jlib to be 'basic' but also client
#           level features can be basic.
#       NB: Features registered here MUST NEVER change within a certain version.

proc jlib::disco::registerfeature {feature} { 
    variable features
  
    lappend features $feature
    set features [lsort -unique $features]
}

proc jlib::disco::getregisteredfeatures {} {
    variable features

    return $features
}

# jlib::disco::registerhandler --
# 
#       Register handler to deliver incoming disco queries.

proc jlib::disco::registerhandler {jlibname cmdProc} {
    
    upvar ${jlibname}::disco::handler handler
    
    set handler $cmdProc
}

# jlib::disco::send_get --
#
#       Sends a get request within the disco namespace.
#
# Arguments:
#       jlibname:   name of existing jabberlib instance
#       type:       items|info
#       jid:        to jid
#       cmd:        callback tcl proc        
#       args:       -node chdata
#       
# Results:
#       none.

proc jlib::disco::send_get {jlibname type jid cmd args} {
    
    variable xmlns
    upvar ${jlibname}::disco::state state
    
    set jid [jlib::jidmap $jid]
    set node ""
    set opts [list]
    if {[set idx [lsearch $args -node]] >= 0} {
	set node [lindex $args [incr idx]]
	set opts [list -node $node]
    }
    set state(pending,$type,$jid,$node) 1
    
    eval {$jlibname iq_get $xmlns($type) -to $jid  \
      -command [list [namespace current]::send_get_cb $type $jid $cmd]} $opts
}

# jlib::disco::get_async --
# 
#       Do disco async using 'cmd' callback. 
#       If cached it is returned directly using 'cmd', if pending the cmd
#       is invoked when getting result, else we do a send_get.

proc jlib::disco::get_async {jlibname type jid cmd args} {

    upvar ${jlibname}::disco::items items
    upvar ${jlibname}::disco::info  info
    upvar ${jlibname}::disco::state state

    set jid [jlib::jidmap $jid]
    set node ""
    set opts [list]
    if {[set idx [lsearch $args -node]] >= 0} {
	set node [lindex $args [incr idx]]
	set opts [list -node $node]
    }
    set var ${type}($jid,$node,xml)
    if {[info exists $var]} {
	set xml [set $var]
	set etype [wrapper::getattribute $xml type]

	# Errors are reported specially!
	# @@@ BAD!!!
	if {$etype eq "error"} {
	    set xml [lindex [wrapper::getchildren $xml] 0]
	}
	uplevel #0 $cmd [list $jlibname $etype $jid $xml]
    } elseif {[info exists state(pending,$type,$jid,$node)]} {
	lappend state(invoke,$type,$jid,$node) $cmd
    } else {
	eval {send_get $jlibname $type $jid $cmd} $opts
    }
    return
}

# jlib::disco::send_get_cb --
# 
#       Fills in the internal state arrays, and invokes any callback.

proc jlib::disco::send_get_cb {ditype from cmd jlibname type queryE args} {
    
    upvar ${jlibname}::disco::items items
    upvar ${jlibname}::disco::info  info
    upvar ${jlibname}::disco::state state
    
    # We need to use both jid and any node for addressing since
    # each item may have identical jid's but different node's.

    # Do STRINGPREP.
    set from [jlib::jidmap $from]
    set node [wrapper::getattribute $queryE "node"]

    unset -nocomplain state(pending,$ditype,$from,$node)
    
    if {[string equal $type "error"]} {

	# Cache xml for later retrieval.
	set var ${ditype}($from,$node,xml)
	set $var [eval {getfulliq $type $queryE} $args]
    } else {
	switch -- $ditype {
	    items {
		parse_get_items $jlibname $from $queryE
	    }
	    info {
		parse_get_info $jlibname $from $queryE
	    }
	}
    }
    invoke_stacked $jlibname $ditype $type $from $queryE
    
    # Invoke callback for this get.
    uplevel #0 $cmd [list $jlibname $type $from $queryE] $args
}

proc jlib::disco::invoke_stacked {jlibname ditype type jid queryE} {
    
    upvar ${jlibname}::disco::state state
    
    set node [wrapper::getattribute $queryE "node"]
    if {[info exists state(invoke,$ditype,$jid,$node)]} {
	foreach cmd $state(invoke,$ditype,$jid,$node) {
	    uplevel #0 $cmd [list $jlibname $type $jid $queryE]
	}
	unset -nocomplain state(invoke,$ditype,$jid,$node)
    }
}

proc jlib::disco::getfulliq {type queryE args} {
    
    # Errors are reported specially!
    # @@@ BAD!!!
    # If error queryE is just a two element list {errtag text}
    set attr [list type $type]
    foreach {key value} $args {
	lappend attr [string trimleft $key "-"] $value
    }
    return [wrapper::createtag iq -attrlist $attr -subtags [list $queryE]]
}

# jlib::disco::parse_get_items --
# 
#       Fills the internal records with this disco items query result.
#       There are four parent-childs combinations:
#       
#         (0)   JID1
#                   JID         JID1 != JID
#               
#         (1)   JID1
#                   JID1+node   JID equal
#               
#         (2)   JID1+node1
#                   JID         JID1 != JID
#               
#         (3)   JID1+node1
#                   JID+node    JID1 != JID
#        
#        Typical xml:
#        <iq type='result' ...>
#             <query xmlns='http://jabber.org/protocol/disco#items' 
#                    node='music'>
#                 <item jid='catalog.shakespeare.lit'
#                       node='music/A'/> 
#                 ...
#
#   Any of the following scenarios is perfectly acceptable: 
#
#   (0) Upon querying an entity (JID1) for items, one receives a list of items 
#       that can be addressed as JIDs; each associated item has its own JID, 
#       but no such JID equals JID1. 
#
#   (1) Upon querying an entity (JID1) for items, one receives a list of items 
#       that cannot be addressed as JIDs; each associated item has its own 
#       JID+node, where each JID equals JID1 and each NodeID is unique. 
#
#   (2) Upon querying an entity (JID1+NodeID1) for items, one receives a list 
#       of items that can be addressed as JIDs; each associated item has its 
#       own JID, but no such JID equals JID1. 
#
#   (3) Upon querying an entity (JID1+NodeID1) for items, one receives a list 
#       of items that cannot be addressed as JIDs; each associated item has 
#       its own JID+node, but no such JID equals JID1 and each NodeID is
#       unique in the context of the associated JID. 
#       
#   In addition, the results MAY also be mixed, so that a query to a JID or a 
#   JID+node could yield both (1) items that are addressed as JIDs and (2) 
#   items that are addressed as JID+node combinations. 

proc jlib::disco::parse_get_items {jlibname from queryE} {

    upvar ${jlibname}::disco::items items
    upvar ${jlibname}::disco::info  info
    upvar ${jlibname}::disco::rooms rooms

    # Parents node if any.
    set pnode [wrapper::getattribute $queryE "node"]
    set pitem [list $from $pnode]
    
    set items($from,$pnode,xml) [getfulliq result $queryE]
    unset -nocomplain items($from,$pnode,children) items($from,$pnode,nodes)
    unset -nocomplain items($from,$pnode,childs)
    
    # This is perhaps not a robust way.
    if {0} {
	if {![info exists items($from,parent)]} {
	    set items($from,parent)  [list]
	    set items($from,parents) [list]
	}
	if {![info exists items($from,$pnode,parent2)]} {
	    set items($from,$pnode,parent2)  [list]
	    set items($from,$pnode,parents2) [list]
	}
    }
    if {![info exists items($from,$pnode,paL)]} {
	set items($from,$pnode,paL)  [list]
    }
    
    # Cache children of category='conference' as rooms.
    if {[lsearch $info(conferences) $from] >= 0} {
	set isrooms 1
    } else {
	set isrooms 0
    }
    
    foreach c [wrapper::getchildren $queryE] {
	if {![string equal [wrapper::gettag $c] "item"]} {
	    continue
	}
	unset -nocomplain attr
	array set attr [wrapper::getattrlist $c]
	
	# jid is a required attribute!
	set jid [jlib::jidmap $attr(jid)]
	set node ""
	
	# Children--->
	# Only 'childs' gives the full picture.
	if {$jid ne $from} {
	    lappend items($from,$pnode,children) $jid
	}
	if {[info exists attr(node)]} {
	    
	    # Not two nodes of a jid may be identical. Beware for infinite loops!
	    # We only do some rudimentary check.
	    set node $attr(node)
	    if {[string equal $pnode $node]} {
		continue
	    }
	    lappend items($from,$pnode,nodes) $node	    
	}
	lappend items($from,$pnode,childs) [list $jid $node]
	
	# Parents--->
	
	# Keep list of parents since not unique.
	lappend items($jid,$node,paL) $pitem
	
	#--------------------------
	if {0} {
	    
	# Case (2) above is particularly problematic since an entity jid's
	# position in the disco tree is not unique.
	if {$node eq ""} {
	    
	    # This is a jid.
	    if {$pnode eq ""} {

		# case (0):
		set xcase 0
		set items($jid,parent) $from
		set items($jid,parents) [concat $items($from,parents) \
		  [list $from]]
	    } else {

		# case (2):
		# The owning entity is required to describe this item. BAD.
		set xcase 2
		set items(2,$from,$pnode,$jid,$node,parent) $from
		set items(2,$from,$pnode,$jid,$node,parents) $from
	    }
	} else {
	    
	    # This is a node. case (1) or (3):
	    # Init if the first one.
	    if {$pnode eq ""} {
		set xcase 3
		set items($jid,$node,pnode) [list]
		set items($jid,$node,pnodes) [list]
	    } else {
		set xcase 1
		set items($jid,$node,pnode) $pnode
		set items($jid,$node,pnodes)  \
		  [concat $items($from,$pnode,pnodes) [list $pnode]]
	    }
	}
	if {$xcase == 2} {

	    # The owning entity is required to describe this item. BAD.
	    set items(2,$from,$pnode,$jid,$node,parent2) $pitem
	    set items(2,$from,$pnode,$jid,$node,parents2) \
	      [concat $items($from,$pnode,parents2) [list $pitem]]
	} else {
	    set items($jid,$node,parent2) $pitem
	    set items($jid,$node,parents2) [concat $items($from,$pnode,parents2) \
	      [list $pitem]]
	}
	}
	#-----------------------------
	
	# Cache the optional attributes.
	# Any {jid node} must have identical attributes and childrens.
	foreach key {name action} {
	    if {[info exists attr($key)]} {
		set items($jid,$node,$key) $attr($key)
	    }
	}
	if {$isrooms} {
	    set rooms($jid,$node) 1
	}
    }	
}

# jlib::disco::parse_get_info --
# 
#       Fills the internal records with this disco info query result.

proc jlib::disco::parse_get_info {jlibname from queryE} {

    upvar ${jlibname}::disco::items items
    upvar ${jlibname}::disco::info  info
    upvar ${jlibname}::disco::rooms rooms

    set node [wrapper::getattribute $queryE "node"]

    array unset info [jlib::ESC $from],[jlib::ESC $node],*
    set info($from,$node,xml) [getfulliq result $queryE]
    set isconference 0
    
    foreach c [wrapper::getchildren $queryE] {
	unset -nocomplain attr
	array set attr [wrapper::getattrlist $c]
	
	# There can be one or many of each 'identity' and 'feature'.
	switch -- [wrapper::gettag $c] {
	    identity {
		
		# Each <identity/> element MUST possess 'category' and 
		# 'type' attributes. (category/type)
		# Each identity element SHOULD have the same name value.
		# 
		# XEP 0030:
		# If the hierarchy category is used, every node in the 
		# hierarchy MUST be identified as either a branch or a leaf; 
		# however, since a node MAY have multiple identities, any given 
		# node MAY also possess an identity other than 
		# "hierarchy/branch" or "hierarchy/leaf". 

		set category $attr(category)
		set ctype    $attr(type)
		set name     ""
		if {[info exists attr(name)]} {
		    set name $attr(name)
		}			
		set info($from,$node,name) $name
		set cattype $category/$ctype
		lappend info($from,$node,cattypes) $cattype
		lappend info($cattype,typelist) $from
		set info($cattype,typelist) \
		  [lsort -unique $info($cattype,typelist)]
		
		if {![string match *@* $from]} {
		    
		    switch -- $category {
			conference {
			    lappend info(conferences) $from
			    set isconference 1
			}
		    }
		}
	    }
	    feature {
		set feature $attr(var)
		lappend info($from,$node,features) $feature
		lappend info($feature,featurelist) $from
		
		# Register any groupchat protocol with jlib.
		# Note that each room also returns gc features; skip!
		if {![string match *@* $from]} {
		    
		    switch -- $feature {
			"http://jabber.org/protocol/muc" {
			    $jlibname service registergcprotocol $from "muc"
			}
			"gc-1.0" {
			    $jlibname service registergcprotocol $from "gc-1.0"
			}
		    }
		}
	    }
	}
    }
    
    # If this is a conference be sure to cache any children as rooms.
    if {$isconference && [info exists items($from,,children)]} {
	foreach c $items($from,,children) {
	    set rooms($c,) 1
	}
    }
}

proc jlib::disco::isdiscoed {jlibname discotype jid {node ""}} {
    
    upvar ${jlibname}::disco::items items
    upvar ${jlibname}::disco::info  info
    
    set jid [jlib::jidmap $jid]

    switch -- $discotype {
	items {
	    return [info exists items($jid,$node,xml)]
	}
	info {
	    return [info exists info($jid,$node,xml)]
	}
    }
}

proc jlib::disco::get {jlibname discotype key jid {node ""}} {
    
    upvar ${jlibname}::disco::items items
    upvar ${jlibname}::disco::info  info
    
    set jid [jlib::jidmap $jid]
 
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
    return
}

# Both the items and the info elements may have name attributes! Related???

#       The login servers jid name attribute is not returned via any items
#       element; only via info/identity element. 
#       

proc jlib::disco::name {jlibname jid {node ""}} {
    
    upvar ${jlibname}::disco::items items
    upvar ${jlibname}::disco::info  info
    
    set jid [jlib::jidmap $jid]
    if {[info exists items($jid,$node,name)]} {
	return $items($jid,$node,name)
    } elseif {[info exists info($jid,$node,name)]} {
	return $info($jid,$node,name)
    } else {
	return
    }
}

# jlib::disco::features --
# 
#       Returns the var attributes of all feature elements for this jid/node.

proc jlib::disco::features {jlibname jid {node ""}} {
    
    upvar ${jlibname}::disco::info info
    
    set jid [jlib::jidmap $jid]
    if {[info exists info($jid,$node,features)]} {
	return $info($jid,$node,features)
    } else {
	return
    }
}

# jlib::disco::hasfeature --
# 
#       Returns 1 if the jid/node has the specified feature var.

proc jlib::disco::hasfeature {jlibname feature jid {node ""}} {
    
    upvar ${jlibname}::disco::info info

    set jid [jlib::jidmap $jid]
    if {[info exists info($jid,$node,features)]} {
	return [expr [lsearch $info($jid,$node,features) $feature] < 0 ? 0 : 1]
    } else {
	return 0
    }
}

# jlib::disco::types --
# 
#       Returns a list of all category/types of this jid/node.

proc jlib::disco::types {jlibname jid {node ""}} {
    
    upvar ${jlibname}::disco::info info
    
    set jid [jlib::jidmap $jid]
    if {[info exists info($jid,$node,cattypes)]} {
	return $info($jid,$node,cattypes)
    } else {
	return
    }
}

# jlib::disco::iscategorytype --
# 
#       Search for any matching feature var glob pattern.

proc jlib::disco::iscategorytype {jlibname cattype jid {node ""}} {
    
    upvar ${jlibname}::disco::info info
    
    set jid [jlib::jidmap $jid]
    if {[info exists info($jid,$node,cattypes)]} {
	if {[lsearch -glob $info($jid,$node,cattypes) $cattype] >= 0} {
	    return 1
	} else {
	    return 0
	}
    } else {
	return 0
    }
}

# jlib::disco::getjidsforfeature --
# 
#       Returns a list of all jids that support the specified feature.

proc jlib::disco::getjidsforfeature {jlibname feature} {
    
    upvar ${jlibname}::disco::info info
    
    if {[info exists info($feature,featurelist)]} {
	set info($feature,featurelist) [lsort -unique $info($feature,featurelist)]
	return $info($feature,featurelist)
    } else {
	return
    }
}

# jlib::disco::getjidsforcategory --
#
#       Returns all jids that match the glob pattern category/type.
#       
# Arguments:
#       jlibname:     name of existing jabberlib instance
#       pattern:      a global pattern of jid type/subtype (gateway/*).
#
# Results:
#       List of jid's matching the type pattern. nodes???

proc jlib::disco::getjidsforcategory {jlibname pattern} {
    
    upvar ${jlibname}::disco::info info
    
    set jidL [list]   
    foreach {key jids} [array get info "$pattern,typelist"] {
	set jidL [concat $jidL $jids]
    }
    return $jidL
}    

# jlib::disco::getallcategories --
#
#       Returns all categories that match the glob pattern catpattern.
#       
# Arguments:
#       jlibname:     name of existing jabberlib instance
#       pattern:      a global pattern of jid type/subtype (gateway/*).
#
# Results:
#       List of types matching the category/type pattern.

proc jlib::disco::getallcategories {jlibname pattern} {    
    
    upvar ${jlibname}::disco::info info
    
    set cattypes [list]
    foreach {key jids} [array get info "$pattern,typelist"] {
	lappend cattypes [string map {,typelist ""} $key]
    }
    return [lsort -unique $cattypes]
}    

proc jlib::disco::getconferences {jlibname} {
    
    upvar ${jlibname}::disco::info info

    return [lsort -unique $info(conferences)]
}

# jlib::disco::isroom --
# 
#       Room or not? The problem is that some components, notably some
#       msn gateways, have multiple categories, gateway and conference. BAD!
#       We therefore use a specific 'rooms' array.

proc jlib::disco::isroom {jlibname jid} {

    upvar ${jlibname}::disco::rooms rooms
    
    if {[info exists rooms($jid,)]} {
	return 1
    } else {
	return 0
    }
}

# jlib::disco::children --
# 
#       Returns a list of all child jids of this jid.

proc jlib::disco::children {jlibname jid} {
    
    upvar ${jlibname}::disco::items items

    set jid [jlib::jidmap $jid]
    if {[info exists items($jid,,children)]} {
	return $items($jid,,children)
    } else {
	return
    }
}

proc jlib::disco::childs {jlibname jid {node ""}} {
    
    upvar ${jlibname}::disco::items items

    set jid [jlib::jidmap $jid]
    if {[info exists items($jid,$node,childs)]} {
	return $items($jid,$node,childs)
    } else {
	return
    }
}

# jlib::disco::nodes --
# 
#       Returns a list of child nodes of this jid|node.

proc jlib::disco::nodes {jlibname jid {node ""}} {
    
    upvar ${jlibname}::disco::items items

    set jid [jlib::jidmap $jid]
    if {[info exists items($jid,$node,nodes)]} {
	return $items($jid,$node,nodes)
    } else {
	return
    }
}

# Testing............

proc jlib::disco::parentlist {jlibname jid {node ""}} {
    
    upvar ${jlibname}::disco::items items

    set jid [jlib::jidmap $jid]
    if {[info exists items($jid,$node,paL)]} {
	set items($jid,$node,paL) [lsort -unique $items($jid,$node,paL)]
	return $items($jid,$node,paL)
    } else {
	return
    }
}

proc jlib::disco::getparentrecursive {jlibname jid {node ""}} {
    
    upvar ${jlibname}::disco::items items

    set jid [jlib::jidmap $jid]
    if {[info exists items($jid,$node,paL)]} {
	set plist [list]
	set pitem $items($jid,$node,paL)
	while {$pitem ne {}} {
	    
	
	}
	
    } else {
	return
    }
}

#....................

proc jlib::disco::handle_get {discotype jlibname from queryE args} {
    
    upvar ${jlibname}::disco::handler handler

    set ishandled 0
    if {[info exists handler]} {
	set ishandled [uplevel #0 $handler  \
	  [list $jlibname $discotype $from $queryE] $args]
    }
    return $ishandled
}

# jlib::disco::unavail_cb --
# 
#       Registered unavailable presence callback.
#       Frees internal cache related to this jid.

proc jlib::disco::unavail_cb {jlibname xmldata} {

    # This screws up gateway handling completely since a gateway is still
    # a gateway even if unavailable!
    # @@@ Perhaps we shall make a distinction here between ordinary users
    # and services?
    #set jid [wrapper::getattribute $xmldata from]
    #reset $jlibname $jid
}

# jlib::disco::reset --
# 
#       Clear this particular jid and all its children.

proc jlib::disco::reset {jlibname {jid ""} {node ""}} {

    upvar ${jlibname}::disco::items items
    upvar ${jlibname}::disco::info  info
    upvar ${jlibname}::disco::rooms rooms

    if {($jid eq "") && ($node eq "")} {
	array unset items
	array unset info
	array unset rooms

	set info(conferences) [list]
    } else {
	set jid [jlib::jidmap $jid]	
	
	# Can be problems with this (ICQ) ???
	if {[info exists items($jid,,children)]} {
	    foreach child $items($jid,,children) {
		ResetJid $jlibname $child
	    }
	}
	ResetJid $jlibname $jid
    }
}

# jlib::disco::ResetJid --
# 
#       Clear only this particular jid.

proc jlib::disco::ResetJid {jlibname jid} {
    
    upvar ${jlibname}::disco::items items
    upvar ${jlibname}::disco::info  info
    upvar ${jlibname}::disco::rooms rooms

    if {$jid eq ""} {
	unset -nocomplain items info rooms
	set info(conferences) [list]
    } else {
	
	if {0} {
	    
	# Keep parents!

	if {[info exists items($jid,parent)]} {
	    set parent $items($jid,parent)
	}
	if {[info exists items($jid,parents)]} {
	    set parents $items($jid,parents)
	}
	
	if {[info exists items($jid,,parent2)]} {
	    set parent2 $items($jid,,parent2)
	}
	if {[info exists items($jid,,parents2)]} {
	    set parents2 $items($jid,,parents2)
	}
	
	}

	array unset items [jlib::ESC $jid],*
	array unset info  [jlib::ESC $jid],*
	array unset rooms [jlib::ESC $jid],*
	
	if {0} {
	    
	# Add back parent(s).
	if {[info exists parent]} {
	    set items($jid,parent) $parent
	}
	if {[info exists parents]} {
	    set items($jid,parents) $parents
	}

	if {[info exists parent2]} {
	    set items($jid,,parent2) $parent2
	}
	if {[info exists parents2]} {
	    set items($jid,,parents2) $parents2
	}

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

proc jlib::disco::Debug {num str} {
    variable debug
    if {$num <= $debug} {
	puts $str
    }
}

# We have to do it here since need the initProc before doing this.

namespace eval jlib::disco {
    
    jlib::ensamble_register disco  \
      [namespace current]::init    \
      [namespace current]::cmdproc
}

#-------------------------------------------------------------------------------
