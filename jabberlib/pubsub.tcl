#  pubsub.tcl --
#  
#      This file is part of the jabberlib. It contains support code
#      for the pub-sub (xmlns='http://jabber.org/protocol/pubsub') JEP-0060.
#      
#  Copyright (c) 2005-2006  Mats Bengtsson
#  
# $Id: pubsub.tcl,v 1.9 2006-07-29 10:15:44 matben Exp $
# 
############################# USAGE ############################################
#
#   INSTANCE COMMANDS
#      jlibName pubsub affiliations
#      jlibName pubsub create 
#      jlibName pubsub delete
#      jlibName pubsub items
#      jlibName pubsub options
#      jlibName pubsub publish
#      jlibName pubsub purge
#      jlibName pubsub retract
#      jlibName pubsub subscribe
#      jlibName pubsub unsubscribe
#
################################################################################


package provide jlib::pubsub 0.2

namespace eval jlib::pubsub {
    
    variable debug 0
    
    # Common xml namespaces.
    variable xmlns
    array set xmlns {
	pubsub   "http://jabber.org/protocol/pubsub"
	errors   "http://jabber.org/protocol/pubsub#errors"
	event    "http://jabber.org/protocol/pubsub#event"
	owner    "http://jabber.org/protocol/pubsub#owner"
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
	variable events
    }
	
    # Register event notifier.
    $jlibname message_register normal $xmlns(event)  \
      [namespace current]::event

}

proc jlib::pubsub::cmdproc {jlibname cmd args} {
    
    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

# jlib::pubsub::create --
# 
#       Create a new pubsub node.
#       
# Arguments:
#       to            JID
#       args: -command    tclProc
#             -configure  0 no configure element
#                         1 new node with default configuration
#                         xmldata jabber:x:data element
#             -node       the nodeID (else we get an instant node)
# 
# Results:
#       none

proc jlib::pubsub::create {jlibname to args} {
    
    variable xmlns
    
    set attr {}
    set opts [list -to $to]
    set configure 0
    foreach {key value} $args {
	set name [string trimleft $key -]
	
	switch -- $key {
	    -command {
		lappend opts -command $value
	    }
	    -configure {
		set configure $value
	    }
	    -node {
		lappend attr $name $value
	    }
	}
    }
    set subtags [list [wrapper::createtag create -attrlist $attr]]
    if {$configure eq "1"} {
	lappend subtags [wrapper::createtag configure]
    } elseif {[wrapper::validxmllist $configure]} {
	lappend subtags [wrapper::createtag configure -subtags [list $configure]]
    }
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(pubsub)] -subtags $subtags]]
    eval {jlib::send_iq $jlibname set $xmllist} $opts
}

# jlib::pubsub::configure --
# 
#       Get or set configuration options for a node.
#       
# Arguments:
#           type:   get|set
#           to:     JID
#           
# Results:
#       none

proc jlib::pubsub::configure {jlibname type to node args} {
    
    variable xmlns

    set opts [list -to $to]
    set xE {}
    foreach {key value} $args {
	switch -- $key {
	    -command {
		lappend opts -command $value
	    }
	    -x {
		set xE $value
	    }
	}
    }
    set subtags [list [wrapper::createtag configure  \
      -attrlist [list node $node] -subtags [list $xE]]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(owner)] -subtags $subtags]]
    eval {jlib::send_iq $jlibname $type $xmllist} $opts
}

# jlib::pubsub::default --
# 
#       Request default configuration options for new nodes.

proc jlib::pubsub::default {jlibname to args} {
    
    variable xmlns

    set opts [list -to $to]
    foreach {key value} $args {
	switch -- $key {
	    -command {
		lappend opts -command $value
	    }
	}
    }
    set subtags [list [wrapper::createtag default]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(owner)] -subtags $subtags]]
    eval {jlib::send_iq $jlibname get $xmllist} $opts
}

# jlib::pubsub::delete --
# 
#       Delete a node.

proc jlib::pubsub::delete {jlibname to node args} {
    
    variable xmlns

    set opts [list -to $to]
    foreach {key value} $args {
	switch -- $key {
	    -command {
		lappend opts -command $value
	    }
	}
    }
    set subtags [list [wrapper::createtag delete -attrlist [list node $node]]]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(owner)] -subtags $subtags]]
    eval {jlib::send_iq $jlibname set $xmllist} $opts
}

# jlib::pubsub::purge --
# 
#       Purge all node items.

proc jlib::pubsub::purge {jlibname to node args} {
    
    variable xmlns

    set opts [list -to $to]
    foreach {key value} $args {
	switch -- $key {
	    -command {
		lappend opts -command $value
	    }
	}
    }
    set subtags [list [wrapper::createtag purge -attrlist [list node $node]]]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(owner)] -subtags $subtags]]
    eval {jlib::send_iq $jlibname set $xmllist} $opts
}

# jlib::pubsub::subscriptions --
# 
#       Gets or sets subscriptions.
#       
# Arguments:
#       type:   get|set
#       to:     JID
#       node:   pubsub nodeID
#       args:
#           -command    tclProc
#           -subscriptions  list of subscription elements
# Results:
#       none

proc jlib::pubsub::subscriptions {jlibname type to node args} {
    
    variable xmlns

    set opts [list -to $to]
    set subsEs {}
    foreach {key value} $args {
	switch -- $key {
	    -command {
		lappend opts -command $value
	    }
	    -subscriptions {
		set subsEs $value
	    }
	}
    }
    set subtags [list [wrapper::createtag subscriptions  \
      -attrlist [list node $node] -subtags $subsEs]]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(owner)] -subtags $subtags]]
    eval {jlib::send_iq $jlibname $type $xmllist} $opts
}

# jlib::pubsub::affiliations --
# 
#       Gets or sets affiliations.
#       
# Arguments:
#       type:   get|set
#       to:     JID
#       node:   pubsub nodeID
#       args:
#           -command    tclProc
#           -affiliations  list of affiliation elements
# Results:
#       none

proc jlib::pubsub::affiliations {jlibname type to node args} {
    
    variable xmlns
    
    set opts [list -to $to]
    set affEs {}
    foreach {key value} $args {
	switch -- $key {
	    -command {
		lappend opts -command $value
	    }
	    -affiliations {
		set affEs $value
	    }
	}
    }
    set subtags [list [wrapper::createtag affiliations]  \
      -attrlist [list node $node] -subtags $affEs]]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(pubsub)] -subtags $subtags]]
    eval {jlib::send_iq $jlibname $type $xmllist} $opts
}

# jlib::pubsub::items --
# 
#       Retrieve items from a node.

proc jlib::pubsub::items {jlibname to node args} {
    
    variable xmlns

    set opts [list -to $to]
    set attr [list node $node]
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
#       Gets or sets options for a JID+node
# 
# Arguments:
#       type:       set or get
#       to:         JID for pubsub service
#       jid:        the subscribed JID 
#       args:
#           -command    tclProc
#           -subid      subscription ID
#           -xdata
# 
# Results:
#       none

proc jlib::pubsub::options {jlibname type to jid node args} {
    
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
    set optE [list [wrapper::createtag options  \
      -attrlist $attr -subtags [list $xdata]]]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(pubsub)] -subtags $optE]]
    eval {jlib::send_iq $jlibname $type $xmllist} $opts
}

# jlib::pubsub::publish --
# 
#       Publish an item to a node.

proc jlib::pubsub::publish {jlibname to node args} {

    variable xmlns
    
    set opts [list -to $to]
    set itemEs {}
    foreach {key value} $args {	
	switch -- $key {
	    -command {
		lappend opts -command $value
	    }
	    -items {
		set itemEs $value
	    }
	}
    }
    set subtags [list [wrapper::createtag publish \
      -attrlist [list node $node] -subtags $itemEs]]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(pubsub)] -subtags $subtags]]
    eval {jlib::send_iq $jlibname set $xmllist} $opts
}

# jlib::pubsub::retract --
# 
#       Delete an item from a node.

proc jlib::pubsub::retract {jlibname to node itemids args} {
    
    variable xmlns

    set opts [list -to $to]
    foreach {key value} $args {
	switch -- $key {
	    -command {
		lappend opts $name $value
	    }
	}
    }
    set items {}
    foreach id $itemids {
	lappend items [wrapper::createtag item -attrlist [list id $id]]
    }
    set subtags [list [wrapper::createtag retract \
      -attrlist [list node $node] -subtags $items]]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(pubsub)] -subtags $subtags]]
    eval {jlib::send_iq $jlibname set $xmllist} $opts
}

# jlib::pubsub::subscribe --
# 
#       Subscribe to a JID+nodeID.
#       
# Arguments:
#       to:         JID for pubsub service
#       jid:        the subscribed JID 
#       args:
#           -command    tclProc
#           -node       pubsub nodeID; MUST be there except for root collection
#                       node
# 
# Results:
#       

proc jlib::pubsub::subscribe {jlibname to jid args} {
    
    variable xmlns
    
    set opts [list -to $to]
    set attr [list jid $jid]
    foreach {key value} $args {
	switch -- $key {
	    -command {
		lappend opts -command $value
	    }
	    -node {
		lappend attr node $value
	    }
	}
    }
    set subEs [list [wrapper::createtag subscribe -attrlist $attr]]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(pubsub)] -subtags $subEs]]
    eval {jlib::send_iq $jlibname set $xmllist} $opts
}

# jlib::pubsub::unsubscribe --
# 
#       Unsubscribe to a JID+nodeID.

proc jlib::pubsub::unsubscribe {jlibname to jid node args} {
    
    variable xmlns
    
    set opts [list -to $to]
    set attr [list node $node jid $jid]
    foreach {key value} $args {
	switch -- $key {
	    -command {
		lappend opts -command $value
	    }
	    -subid {
		lappend attr subid $value
	    }
	}
    }
    set unsubE [list [wrapper::createtag unsubscribe -attrlist $attr]]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $xmlns(pubsub)] -subtags $unsubE]]
    eval {jlib::send_iq $jlibname set $xmllist} $opts
}

# jlib::pubsub::register_event --
# 
#       Register for specific pubsub events.
#       
# Arguments:
#       jlibname:   the instance of this jlib.
#       func:       tclProc        
#       args:       -from
#                   -node
#                   -seq      priority 0-100 (D=50)
#       
# Results:
#       none.

# @@@ TODO:
# <event xmlns='http://jabber.org/protocol/pubsub#event'>
#    <collection>
#      <node id='new-node-id'>
#    </collection>
# </event> 
  
proc jlib::pubsub::register_event {jlibname func args} {
    
    upvar ${jlibname}::events events
    
    # args: -from, -node
    set from "*"
    set node "*"
    set seq 50
    
    foreach {key value} $args {
	switch -- $key {
	    -from {
		set from [jlib::ESC $value]
	    }
	    -node {
		
		# The pubsub service MUST ensure that the NodeID conforms to 
		# the Resourceprep profile of Stringprep as described in 
		# RFC 3920.
		# @@@ ???
		set node [jlib::resourceprep $value]
	    }
	    -seq {
		set seq $value
	    }
	}
    }
    set pattern "$from,$node"
    lappend events($pattern) [list $func $seq]
    set events($pattern)  \
      [lsort -integer -index 1 [lsort -unique $events($pattern)]]
}

proc jlib::pubsub::deregister_event {jlibname func args} {
    
    upvar ${jlibname}::events events
    
    set from "*"
    set node "*"

    foreach {key value} $args {
	switch -- $key {
	    -from {
		set from [jlib::ESC $value]
	    }
	    -node {
		set node [jlib::resourceprep $value]
	    }
	}
    }
    set pattern "$from,$node"
    if {[info exists events($pattern)]} {
	set idx [lsearch -glob $events($pattern) [list $func *]]
	if {$idx >= 0} {
	    set events($pattern) [lreplace $events($pattern) $idx $idx]
	}
    }
}

# jlib::pubsub::event --
# 
#       The event notifier. Dispatches events to the relevant registered
#       event handlers.
#       
#       Normal events:
#         <event xmlns='http://jabber.org/protocol/pubsub#event'>
#           <items node='princely_musings'>
#             <item id='ae890ac52d0df67ed7cfdf51b644e901'>
#               ... ENTRY ...
#             </item>
#           </items>
#         </event> 

proc jlib::pubsub::event {jlibname ns msgE args} {
    
    variable xmlns
    upvar ${jlibname}::events events

    array set aargs $args
    set xmldata $aargs(-xmldata)
    
    set from [wrapper::getattribute $xmldata from]
    set nodes {}
    
    set eventEs [wrapper::getchildswithtagandxmlns $xmldata event $xmlns(event)]
    foreach eventE $eventEs {
	set itemsEs [wrapper::getchildswithtag $eventE items]
	foreach itemsE $itemsEs {
	    lappend nodes [wrapper::getattribute $itemsE node]
	}
    }
    foreach node $nodes {
	set key "$from,$node"
	foreach {pattern value} [array get events] {
	    if {[string match $pattern $key]} {
		foreach spec $value {
		    set func [lindex $spec 0]
		    set code [catch {
			uplevel #0 $func [list $jlibname $xmldata]
		    } ans]
		    if {$code} {
			bgerror "jlib::pubsub::event $func failed: $code\n$::errorInfo"
		    }
		}
	    }
	}
    }
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
    set psjid pubsub.devrieze.dyndns.org
    set myjid [$jlib myjid2]
    set server [$jlib getserver]
    set itemE [wrapper::createtag item -attrlist [list id 123456789]]
    proc cb {args} {puts "---> $args"}
    set node mats
    set node home/$server/matben/xyz
    
    $jlib pubsub create $psjid -node $node -command cb
    $jlib pubsub register_event cb -from $psjid -node $node
    $jlib pubsub subscribe $psjid $myjid -node $node -command cb
    $jlib pubsub subscriptions get $psjid $node -command cb
    $jlib pubsub publish $psjid $node -items [list $itemE]



}

#-------------------------------------------------------------------------------

