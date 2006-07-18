#  pubsub.tcl --
#  
#      This file is part of the jabberlib. It contains support code
#      for the pub-sub (xmlns='http://jabber.org/protocol/pubsub') JEP-0060.
#      
#  Copyright (c) 2005-2006  Mats Bengtsson
#  
# $Id: pubsub.tcl,v 1.7 2006-07-18 14:02:16 matben Exp $
# 
############################# USAGE ############################################
#
#   INSTANCE COMMANDS
#      jlibName pubsub affiliations
#      jlibName pubsub create 
#      jlibName pubsub delete
#      jlibName pubsub entities
#      jlibName pubsub entity
#      jlibName pubsub items
#      jlibName pubsub options
#      jlibName pubsub publish
#      jlibName pubsub purge
#      jlibName pubsub retract
#      jlibName pubsub subscribe
#      jlibName pubsub unsubscribe
#
################################################################################


package provide jlib::pubsub 0.1

namespace eval jlib::pubsub {
    
    variable debug 0
    
    # Common xml namespaces.
    variable xmlns
    array set xmlns {
	pubsub   "http://jabber.org/protocol/pubsub"
	event    "http://jabber.org/protocol/pubsub#event"
    }
}

# jlib::pubsub::init --
# 
#       Creates a new instance of the pubsub object.
#       
# Arguments:
#       jlibname:     name of existing jabberlib instance
# 
# Results:
#       namespaced instance command

proc jlib::pubsub::init {jlibname} {

    variable xmlns

    # Instance specific arrays.
    namespace eval ${jlibname}::pubsub {
	variable items
    }
	
    # Register event notifier.
    $jlibname message_register normal $xmlns(event)  \
      [namespace current]::event

}

proc jlib::pubsub::configure {jlibname args} {
    # empty.
}

proc jlib::caps::cmdproc {jlibname cmd args} {
    
    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

proc jlib::pubsub::affiliations {jlibname jid node args} {
    
    variable xmlns
    
    set opts [list -to $jid]
    set subtags [list [wrapper::createtag affiliations]]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(pubsub)] -subtags $subtags]]
    eval {jlib::send_iq $jlibname get $xmllist} $opts $args
}

# jlib::pubsub::create --
# 
#       Create a new pubsub node.
#       
# Arguments:
#       jlibname:     name of existing jabberlib instance
#       jid
#       args: -command    tclProc
#             -configure  new node with default configuration
#             -node       the node (else we get an instant node)
# 
# Results:
#       namespaced instance command

proc jlib::pubsub::create {jlibname jid args} {
    
    variable xmlns
    
    set attrlist {}
    set opts [list -to $jid]
    set configure 0
    foreach {key value} $args {
	set name [string trimleft $key -]
	
	switch -- $key {
	    -command {
		lappend opts $name $value
	    }
	    -configure {
		set configure $value
	    }
	    -node {
		lappend attrlist $name $value
	    }
	    default {
		lappend opts $name $value
	    }
	}
    }
    set subtags [list [wrapper::createtag create -attrlist $attrlist]]
    if {$configure} {
	lappend subtags [wrapper::createtag configure]
    }
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(pubsub)] -subtags $subtags]]
    eval {jlib::send_iq $jlibname set $xmllist  \
      -command [list [namespace current]::callback $cmd]} $opts
}

# jlib::pubsub::delete --
# 
#       Delete a pubsub node.

proc jlib::pubsub::delete {jlibname jid node args} {
    
    variable xmlns

    set opts [list -to $jid]
    set subtags [list [wrapper::createtag delete -attrlist [list node $node]]]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(pubsub)] -subtags $subtags]]
    eval {jlib::send_iq $jlibname set $xmllist} $opts $args
}

proc jlib::pubsub::entities {jlibname type jid node args} {
    
    variable xmlns

    set opts [list -to $jid]
    set entities {}
    foreach {key value} $args {
	set name [string trimleft $key -]
	
	switch -- $key {
	    -entities {
		set entities $value
	    }
	    default {
		lappend opts $name $value
	    }
	}
    }
    set subtags [list [wrapper::createtag entities \
      -attrlist [list node $node] -subtags $entities]]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(pubsub)] -subtags $subtags]]
    eval {jlib::send_iq $jlibname $type $xmllist} $opts $args
}

proc jlib::pubsub::entity {jlibname jid node args} {
    
    variable xmlns

    

}

# jlib::pubsub::items --
# 
#       Retrieve items from a node.

proc jlib::pubsub::items {jlibname to node args} {
    
    variable xmlns

    set opts [list -to $to]
    set attr [list node $node subid $subid]
    set itemids {}
    foreach {key value} $args {
	set name [string trimleft $key -]
	
	switch -- $key {
	    -command {
		lappend opts -command $value
	    }
	    -itemids {
		set itemids $value
	    }
	    -max_items - -subid {
		lappend attr $name $value
	    }
	}
    }
    set items {}
    foreach id $itemids {
	lappend items [wrapper::createtag item -attrlist [list id $id]]
    }
    set subtags [list [wrapper::createtag items  \
      -attrlist $attr -subtags $items]]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(pubsub)] -subtags $subtags]]
    eval {jlib::send_iq $jlibname get $xmllist} $opts
}

# jlib::pubsub::options --
# 
# 
# Arguments:
#       jlibname:     name of existing jabberlib instance
#       type:         set or get
#       to:           JID for pubsub service
# 
# Results:
#       

proc jlib::pubsub::options {jlibname type to node jid args} {
    
    variable xmlns

    set opts [list -to $to]
    set attr [list node $node jid $jid]
    set xdata {}

    foreach {key value} $args {
	switch -- $key {
	    -command {
		lappend opts -command $value
	    }
	    -subid {
		lappend attr subid $value
	    }
	    -xdata {
		set xdata $value
	    }
	}
    }
    set optElem [list [wrapper::createtag options  \
      -attrlist $attr -subtags [list $xdata]]]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(pubsub)] -subtags $optElem]]
    eval {jlib::send_iq $jlibname $type $xmllist} $opts
}

# jlib::pubsub::publish --
# 
#       Publish an item to a node.

proc jlib::pubsub::publish {jlibname to node args} {

    variable xmlns
    
    set opts [list -to $to]
    set items {}
    foreach {key value} $args {	
	switch -- $key {
	    -command {
		lappend opts -command $value
	    }
	    -items {
		set items $value
	    }
	}
    }
    set subtags [list [wrapper::createtag publish \
      -attrlist [list node $node] -subtags $items]]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(pubsub)] -subtags $subtags]]
    eval {jlib::send_iq $jlibname set $xmllist} $opts
}

proc jlib::pubsub::purge {jlibname jid node args} {
    
    variable xmlns

    set opts [list -to $jid]
    set subtags [list [wrapper::createtag purge -attrlist [list node $node]]]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(pubsub)] -subtags $subtags]]
    eval {jlib::send_iq $jlibname set $xmllist} $opts $args
}

# jlib::pubsub::retract --
# 
#       Delete an item from a node.

proc jlib::pubsub::retract {jlibname jid node itemids args} {
    
    variable xmlns

    set opts [list -to $jid]
    set items {}
    foreach id $itemids {
	lappend items [wrapper::createtag item -attrlist [list id $id]]
    }
    set subtags [list [wrapper::createtag retract \
      -attrlist [list node $node] -subtags $items]]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(pubsub)] -subtags $subtags]]
    eval {jlib::send_iq $jlibname set $xmllist} $opts $args
}

# jlib::pubsub::subscribe --
# 
#       Subscribe to a jid+node.

proc jlib::pubsub::subscribe {jlibname to node jid args} {
    
    variable xmlns
    
    set opts [list -to $to]
    foreach {key value} $args {
	switch -- $key {
	    -command {
		lappend opts $name $value
	    }
	}
    }
    set subElem [list [wrapper::createtag subscribe \
      -attrlist [list node $node jid $jid]]]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(pubsub)] -subtags $subElem]]
    eval {jlib::send_iq $jlibname set $xmllist} $opts
}

# jlib::pubsub::unsubscribe --
# 
#       Unsubscribe to a jid+node.

proc jlib::pubsub::unsubscribe {jlibname to node jid args} {
    
    variable xmlns
    
    set opts [list -to $to]
    set attr [list node $node jid $jid]
    foreach {key value} $args {
	switch -- $key {
	    -command {
		lappend opts $name $value
	    }
	    -subid {
		lappend attr subid $value
	    }
	}
    }
    set unsubElem [list [wrapper::createtag unsubscribe -attrlist $attr]]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(pubsub)] -subtags $unsubElem]]
    eval {jlib::send_iq $jlibname set $xmllist} $opts
}

# jlib::pubsub::event --
# 
#       The event notifier. Dispatches events to the relevant registered
#       event handlers.

proc jlib::pubsub::event {jlibname ns msgElem args} {
    
    array set aargs $args
    set xmldata $aargs(-xmldata)
    
    
    
}

# We have to do it here since need the initProc before doing this.

namespace eval jlib::pubsub {
    
    jlib::ensamble_register pubsub  \
      [namespace current]::init    \
      [namespace current]::cmdproc
}

if {0} {
    # Test code.
    set jlib jlib::jlib1
    set psjid pubsub.sgi.se
    proc cb {args} {puts "callback: $args"}
    
    $jlib pubsub create $psjid -node mats -command cb
    
}

#-------------------------------------------------------------------------------

