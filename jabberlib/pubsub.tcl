#  pubsub.tcl --
#  
#      This file is part of the jabberlib. It contains support code
#      for the pub-sub (xmlns='http://jabber.org/protocol/pubsub') JEP-0060.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: pubsub.tcl,v 1.1 2005-02-19 08:17:41 matben Exp $
# 
############################# USAGE ############################################
#
#   INSTANCE COMMANDS
#      jlibName pubsub affiliations
#      jlibName pubsub create ?-node name ?
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

#      UNFINISHED!!!
#      
# EXPERIMENTAL!!!

package provide pubsub 1.0

namespace eval jlib::pubsub {
    
    
}

proc jlib::pubsub {jlibname cmd args} {
    
    # Which command? Just dispatch the command to the right procedure.
    return [eval {[namespace current]::pubsub::${cmd} $jlibname} $args]
}

proc jlib::pubsub::affiliations {jlibname jid node args} {
    
    upvar jlib::jxmlns jxmlns

    
    
    
    
}

# jlib::pubsub::create --
# 
#       Create a new pubsub node.

proc jlib::pubsub::create {jlibname jid args} {
    
    upvar jlib::jxmlns jxmlns
    
    set attrlist {}
    set opts [list -to $jid]
    set configure 0
    foreach {key value} $args {
	set name [string trimleft $key -]
	
	switch -- $key {
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
      -attrlist [list xmlns $jxmlns(pubsub)] -subtags $subtags]]
    eval {jlib::send_iq $jlibname set $xmllist} $opts
}

proc jlib::pubsub::delete {jlibname jid node args} {
    
    upvar jlib::jxmlns jxmlns

    
    
    
    
}

proc jlib::pubsub::entities {jlibname jid node args} {
    
    upvar jlib::jxmlns jxmlns

    
    
    
    
}

proc jlib::pubsub::entity {jlibname jid node args} {
    
    upvar jlib::jxmlns jxmlns

    
    
    
    
}

proc jlib::pubsub::items {jlibname jid node args} {
    
    upvar jlib::jxmlns jxmlns

    
    
    
    
}

proc jlib::pubsub::options {jlibname jid node args} {
    
    upvar jlib::jxmlns jxmlns

    
    
    
    
}

# jlib::pubsub::publish --
# 
#       Publish an item to a node.

proc jlib::pubsub::publish {jlibname jid node args} {
    upvar jlib::jxmlns jxmlns
    
    set opts [list -to $jid]
    set items {}
    foreach {key value} $args {
	set name [string trimleft $key -]
	
	switch -- $key {
	    -items {
		set items $value
	    }
	    default {
		lappend opts $name $value
	    }
	}
    }
    set subtags [list [wrapper::createtag create \
      -attrlist [list node $node] -subtags $items]]
    set xmllist [list [wrapper::createtag pubsub \
      -attrlist [list xmlns $jxmlns(pubsub)] -subtags $subtags]]
    eval {jlib::send_iq $jlibname set $xmllist} $opts
}

proc jlib::pubsub::purge {jlibname jid node args} {
    
    upvar jlib::jxmlns jxmlns

    
    
    
    
}

proc jlib::pubsub::retract {jlibname jid node args} {
    
    upvar jlib::jxmlns jxmlns

    
    
    
    
}

proc jlib::pubsub::subscribe {jlibname jid node args} {
    
    upvar jlib::jxmlns jxmlns

    
    
    
    
}

proc jlib::pubsub::unsubscribe {jlibname jid node args} {
    
    upvar jlib::jxmlns jxmlns

    
    
    
    
}
