#  xmpp.tcl --
#  
#      This is a skeleton to create a xmpp library from scratch.
#      The intention is to pick relevant parts from jabberlib and rewrite.
#      Dicts will be used extensively instead of arrays why we require Tcl 8.5.
#      
#  Copyright (c) 2008  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: xmpp.tcl,v 1.2 2008-09-20 02:32:55 sdevrieze Exp $

package require Tcl 8.5
package require sha1
package require autosocks       ;# wrapper for the 'socket' command.
package require xmpp::xmlns

package provide xmpp 0.1

namespace eval xmpp {

    # Running integer to number xmpp instances.
    variable uid
    
    # Dictionary that keeps track of instance specific things.
    variable state
    
    # Dictionary for registered transports.
    variable transport

    namespace import xmpp::xmlns::ns
}

#--- Static commands ---
#...


# xmpp::create --
#
#       Makes a new xmpp instance object.
#
# Arguments:
#
# Result:
#       A token for this instance which is the objects command.

proc xmpp::create {args} {
    variable state
    variable uid

    set this [namespace current]::[incr uid]
    
    # Just a dummy.
    dict set state $this this $this
    
    # Not sure we need all this. One enough?
    dict set state $this uid iq       1001
    dict set state $this uid presence 1001
    dict set state $this uid message  1001
    
    dict set state $this instream 0

    init_inst $this

    # Create the actual xmpp instance procedure.
    proc $this {cmd args}   \
      "eval xmpp::dispatch {$this} \$cmd \$args"
    
    return $this
}

# xmpp::init_inst --
#
#       This shall be called typically after logging out to reset some
#       state variables that are no longer valid.

proc xmpp::init_inst {this} {
    variable state
    
    dict set state $this my jid      ""
    dict set state $this my jidmap   ""
    dict set state $this my presence "unavailable"
    dict set state $this my status   ""
    dict set state $this my show     ""
    
    
    
}

proc xmpp::dispatch {this cmd args} {
    # Ensable commands???
    return [eval {$cmd $this} $args]   
}

proc xmpp::set_transport {this name initProc sendProc resetProc ipProc} {
    variable transport
    
    dict set transport $this name  $name
    dict set transport $this init  $initProc
    dict set transport $this send  $sendProc
    dict set transport $this reset $resetProc
    dict set transport $this ip    $ipProc
}

proc xmpp::transport {this} {
    variable transport
    return [dict get $transport $this name]
}

proc xmpp::delete {this} {
    variable state
    
    # Free all loaded sub packages.
    
    dict unset state $this
}





