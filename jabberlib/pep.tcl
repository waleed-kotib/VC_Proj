#  pep.tcl --
#
#      This file is part of the jabberlib. It contains support code
#      for the Personal Eventing PubSub 
#      (xmlns='http://jabber.org/protocol/pubsub') XEP-0163.
#
#  Copyright (c) 2007 Mats Bengtsson
#  Copyright (c) 2006 Antonio Cano Damas
#
# $Id: pep.tcl,v 1.5 2007-04-03 14:11:14 matben Exp $
#
############################# USAGE ############################################
#
#   INSTANCE COMMANDS
#      jlibName pep create 
#      jlibName pep have
#      jlibName pep publish
#      jlibName pep retract
#      jlibName pep subscribe
#
################################################################################
#
#   With PEP version 1.0 and mutual presence subscriptions we only need:
#   
#      jlibName pep have
#      jlibName pep publish
#      jlibName pep retract
#     
#   Typical names and nodes:
#           activity    'http://jabber.org/protocol/activity'
#           geoloc      'http://jabber.org/protocol/geoloc'
#           mood        'http://jabber.org/protocol/mood'
#           tune        'http://jabber.org/protocol/tune'
#     

package require jlib::disco
package require jlib::pubsub

package provide jlib::pep 0.3

namespace eval jlib::pep {

    # Common xml namespaces.
    variable xmlns
    array set xmlns {
        node_config "http://jabber.org/protocol/pubsub#node_config"
    }

    variable state
}

# jlib::pep::init --
#
#       Creates a new instance of the pep object.

proc jlib::pep::init {jlibname} {
    
    # Instance specifics arrays.
    namespace eval ${jlibname}::pep {
	variable autosub
	set autosub(presreg) 0
    }
}

proc jlib::pep::cmdproc {jlibname cmd args} {
    return [eval {$cmd $jlibname} $args]
}

# Setting own PEP --------------------------------------------------------------
#
#       Disco server for PEP, disco own bare JID, create pubsub node.
#       
#       1) Disco server for pubsub/pep support
#       2) Create node if not there             (optional)
#       3) Publish item

# jlib::pep::have --
# 
#       Simplified way to know if a JID supports PEP or not.
#       Typically only needed for the server JID.
#       The command just gets invoked with: jlibname boolean

proc jlib::pep::have {jlibname jid cmd} {    
    $jlibname disco get_async info $jid [namespace code [list OnPepDisco $cmd]]    
}

proc  jlib::pep::OnPepDisco {cmd jlibname type from subiq args} {

    set havepep 0
    if {$type eq "result"} {
	set node [wrapper::getattribute $subiq node]
	
	# Check if disco returns <identity category='pubsub' type='pep'/>
	if {[$jlibname disco iscategorytype pubsub/pep $from $node]} {
	    set havepep 1
	}
    }
    uplevel #0 $cmd [list $jlibname $havepep]
}

# jlib::pep::create --
#
#      Create a PEP node service. 
#      This shall not be necessary if we want just the default configuration.
#
# Arguments:
#       node    typically xmlns
#       args:   -access_model   "presence", "open", "roster", or "whitelist" 
#               -fields         additional list of field elements
#               -command        tclProc
#
# Results:
#       none

proc jlib::pep::create {jlibname node args} {
    variable xmlns
    
    array set argsA {
	-access_model presence
	-command      {}
	-fields       {}
    }
    array set argsA $args

    # Configure setup for PEP node
    set valueFormE [wrapper::createtag value -chdata $xmlns(node_config)]
    set fieldFormE [wrapper::createtag field  \
      -attrlist [list var "FORM_TYPE" type hidden] \
      -subtags [list $valueFormE]]

    # PEP Values for access_model: roster / presence / open or authorize / whitelist
    set valueModelE [wrapper::createtag value -chdata $argsA(-access_model)]
    set fieldModelE [wrapper::createtag field   \
      -attrlist [list var "pubsub#access_model"] \
      -subtags [list $valueModelE]]

    set xattr [list xmlns "jabber:x:data" type submit]
    set xsubE [list $fieldFormE $fieldModelE]
    set xsubE [concat $xsubE $argsA(-fields)]
    set xE [wrapper::createtag x -attrlist $xattr -subtags $xsubE]

    $jlibname pubsub create -node $node -configure $xE -command $argsA(-command)
}

# jlib::pep::publish --
#
#       Publish a stanza into the PEP node (create an item to a node)
#       Typically:
#       
#       <publish node='http://jabber.org/protocol/mood'> 
#           <item>
#               <mood xmlns='http://jabber.org/protocol/mood'>
#                   <annoyed/>
#                   <text>curse my nurse!</text>
#               </mood>
#           </item> 
#       </publish>
#
# Arguments:
#       node    typically xmlns
#       itemE   XML stanza to publishing
#       args    for the 'publish subscribe'
#
# Results:
#       none

proc jlib::pep::publish {jlibname node itemE args} {
    eval {$jlibname pubsub publish $node -items [list $itemE]} $args
}

# jlib::pep::retract --
#
#       Retract a PEP item (Delete an item from a node)
#
# Arguments:
#       node    typically xmlns
#
# Results:
#       none

proc jlib::pep::retract {jlibname node} {
    set itemE [wrapper::createtag item]
    $jlibname pubsub retract $node [list $itemE]
}

# Others PEP -------------------------------------------------------------------
# 
#       In normal circumstances with mutual presence subscriptions we don't
#       need to do pusub subscribe.
# 
#       1) disco bare JID      (not necessary for 1.0)
#       2) subscribe to node   (not necessary for 1.0)
#       3) handle events       (pubsub register_event tclProc -node)

# jlib::pep::subscribe --
# 
# Arguments:
#       jid     JID which we want to subscribe to.
#       node    typically xmlns
#       args:   anything for the pubsub command, like -command.
#
# Results:
#       none

proc jlib::pep::subscribe {jlibname jid node args} {
    
    # If an entity is not subscribed to the account owner's presence, 
    # it MUST subscribe to a node using....
    set myjid2 [$jlibname myjid2]
    eval {$jlibname pubsub subscribe $jid $myjid2 -node $node} $args
}

# @@@ OUTDATED; BACKUP !!!!!!!!!!!!!!!

# jlib::pep::set_auto_subscribe --
# 
#       Subscribe all available users automatically.

proc jlib::pep::set_auto_subscribe {jlibname node args} {    
    upvar ${jlibname}::pep::autosub  autosub

    array set argsA {
	-command    {}
    }
    array set argsA $args
    set autosub($node,node) $node
    set autosub($node,-command) $argsA(-command)
    
    # For those where we've already got presence.
    set jidL [$jlibname roster getusers -type available]
    foreach jid $jidL {
	
	# We may not yet have disco info for this.
	if {[$jlibname disco iscategorytype gateway/* $jid]} {
	    continue
	}
	
	# If Juliet's server supports PEP (thereby making juliet@capulet.com 
	# a virtual pubsub service), it MUST return an identity of "pubsub/pep"
	$jlibname disco get_async items $jid  \
	  [list [namespace current]::OnDiscoItems $node]
    }
    
    # And register an event handler for any presence.    
    if {!$autosub(presreg)} {
	set autosub(presreg) 1
	$jlibname presence_register_int available  \
	  [namespace code [list PresenceEvent $node]]
    }
}

proc jlib::pep::list_auto_subscribe {jlibname} {
    upvar ${jlibname}::pep::autosub  autosub
    
    set nodes {}
    foreach {key node} [array get autosub *,node] {
	lappend nodes $node
    }
    return $nodes
}

proc jlib::pep::have_auto_subscribe {jlibname node} {
    upvar ${jlibname}::pep::autosub  autosub
    
    return [info exists autosub($node,node)]
}

proc jlib::pep::unset_auto_subscribe {jlibname node} {
    upvar ${jlibname}::pep::autosub  autosub
    
    array unset autosub $node,*
    if {![llength [array names autosub *,node]]} {
	set autosub(presreg) 0
	$jlibname presence_deregister_int available \
	  [namespace code [list PresenceEvent $node]]
    }
}

proc jlib::pep::PresenceEvent {jlibname xmldata node} {
    upvar ${jlibname}::pep::autosub  autosub
    variable state
    
    set type [wrapper::getattribute $xmldata type]
    set from [wrapper::getattribute $xmldata from]
    if {$type eq ""} {
        set type "available"
    }
    set jid2 [jlib::barejid $from]
    if {![$jlibname roster isitem $jid2]} {
        return
    }
    if {[$jlibname disco iscategorytype gateway/* $from]} {
        return
    }
    
    # We should be careful not to disco/publish for each presence change.
    # @@@ There is a small glitch here if user changes presence before we
    #     received its disco result.
    if {![$jlibname disco isdiscoed info $from]} {
	foreach {key node} [array get autosub $node,*] {
	    $jlibname disco get_async items $jid2  \
	      [list [namespace current]::OnDiscoItems $node]
	}
    }
}

proc jlib::pep::OnDiscoItems {node jlibname type from subiq args} {
    
    # Get contact PEP nodes.
    if {$type eq "result"} {
	set nodes [$jlibname disco nodes $from]
	if {[lsearch $nodes $node] >= 0} {

	    # NEW PEP:
	    # If an entity is not subscribed to the account owner's presence, 
	    # it MUST subscribe to a node using....
	    set subscribe [$jlibname roster getsubscription $from]
	    set myjid2 [$jlibname myjid2]
	    $jlibname pubsub subscribe $from $myjid2 -node $node  \
	      -command $autosub($node,-command)
	}
    }
}

# We have to do it here since need the initProc before doing this.
namespace eval jlib::pep {

    jlib::ensamble_register pep  \
      [namespace current]::init    \
      [namespace current]::cmdproc
}

# Test:
if {0} {
    package require jlib::pep
    set jlibname ::jlib::jlib1
    set moodNode "http://jabber.org/protocol/mood"
    set mood "neutral"
    proc cb {args} {puts "---> $args"}
    set server [$jlibname getserver]
    set myjid2 [$jlibname  myjid2]
    $jlibname pubsub register_event cb -node $moodNode
    $jlibname disco send_get info $server cb

    # List items
    $jlibname disco send_get items $myjid2 cb
    $jlibname pubsub items $myjid2 $moodNode

    # Retract item from node
    set pepE [wrapper::createtag mood -attrlist [list xmlns $moodNode]]
    set itemE [wrapper::createtag item -subtags [list $pepE]]
    $jlibname pubsub retract $moodNode [list $itemE]
    
    # Delete node
    $jlibname pubsub delete $myjid2 $moodNode

    # Publish item to node
    set moodChildEs [list [wrapper::createtag mood]]
    set moodE [wrapper::createtag mood  \
      -attrlist [list xmlns $moodNode] -subtags $moodChildEs]
    set itemE [wrapper::createtag item -subtags [list $moodE]]
    $jlibname pubsub publish $moodNode -items [list $itemE] -command cb
        
    # User
    set jid matben2@stor.no-ip.org
    $jlibname disco send_get info $jid cb
    $jlibname disco send_get items $jid cb    
    $jlibname roster getsubscription $jid
    
    # PEP
    # Owner
    $jlibname pep have $server cb
    $jlibname pep create $moodNode
    $jlibname pep publish $moodNode $itemE
    
    # User
    $jlibname disco send_get items $jid cb    
    $jlibname pep subscribe $jid $moodNode
    
}

