#  pep.tcl --
#
#      This file is part of the jabberlib. It contains support code
#      for the Personal Eventing PubSub (xmlns='http://jabber.org/protocol/pubsub') JEP-0163.
#
#       The current code reflects the PEP JEP prior to the simplification
#       of version 0.15. NEW PEP means version 0.15+
#
#  Copyright (c) 2006 Mats Bengtsson
#  Copyright (c) 2006 Antonio Cano Damas
#
# $Id: pep.tcl,v 1.1 2006-11-22 08:02:32 matben Exp $
#
############################# USAGE ############################################
#
#   INSTANCE COMMANDS
#      jlibName pep register name xmlns discoProc eventProc
#      jlibName pep unregister 
#      jlibName pep disco
#      jlibName pep create 
#      jlibName pep publish
#      jlibName pep retract
#
################################################################################


package provide jlib::pep 0.1

namespace eval jlib::pep {

    # Common xml namespaces.
    variable xmlns
    array set xmlns {
        node_config "http://jabber.org/protocol/pubsub#node_config"
    }

    variable serverPepSupport
    array set serverPepSupport {
        support 0
        ondisco 0
    }
    variable pepVers1 0

    variable pep
    variable state
    variable debug 4
}

# jlib::pubsub::init --
#
#       Creates a new instance of the pep object.
#
# Arguments:
#       jlibname:     name of existing jabberlib instance
#
# Results:
#       namespaced instance command

proc jlib::pep::init {jlibname} {
    
    # Instance specific arrays.
    namespace eval ${jlibname}::pep {
        variable events
    }
}

proc jlib::pep::cmdproc {jlibname cmd args} {

    # Which command? Just dispatch the command to the right procedure.
    return [eval {$cmd $jlibname} $args]
}

#---------------------------
#    PEP Commands
#---------------------------

# jlib::pep::register --
#
#       Register a new pep node component.
#
# Arguments:
#       name          Name of the node (mood, tune, activity, ...) 
#       nodeXmlns     xmlns
#       discoCmd      Callback function that will be called when disco for server support 
#       eventCmd      Callback function that will be called when received a stanza for this pep node 
#
# Results:
#       none

proc jlib::pep::register {jlibname name nodeXmlns discoCmd eventCmd} {
    variable pep
    variable xmlns
    
    Debug 4 "jlib::pep::register name=$name"

    set xmlns($name) $nodeXmlns
    
    set pep($nodeXmlns,name)     $name
    set pep($nodeXmlns,xmlns)    $nodeXmlns
    set pep($nodeXmlns,discoCmd) $discoCmd
    set pep($nodeXmlns,eventCmd) $eventCmd
    return
}

# jlib::pep::unregister --
#
#       Unregister a new pep node component.
#
# Arguments:
#       node          Name of the node (mood, tune, activity, ...)
#
# Results:
#       none

proc jlib::pep::unregister {jlibname node} {
    Debug 4 "jlib::pep::unregister node=$node"
    $jlibname presence_deregister_int available [namespace code PresenceEvent]
    return
}

# Setting own PEP --------------------------------------------------------------
#
#       Disco server for PEP, disco own bare JID, create pubsub node.
#       
#       1) Disco server for pubsub/pep support
#       2) Create node if not there
#       3) Publish mood

# jlib::pep::disco --
#
#       Make disco for PEP node support: server, our contacts and ourself 
#
# Arguments:
#       args:
#             node          Name of the node (mood, tune, activity, ...)
#
# Results:
#       none

proc jlib::pep::disco {jlibname node} {
    variable serverPepSupport
    variable pep
    
    Debug 4 "jlib::pep::disco node=$node"

    #  The server should be discoed for PEP support only once time
#    if { $serverPepSupport(ondisco) eq 0} {
    set serverPepSupport(ondisco) 1
    set server [$jlibname getserver]
    $jlibname disco get_async info $server [namespace code [list OnDiscoServer $node]]
#    } else {
        #Perform actions for checking our contacts and ourself
#        DiscoRoster $jlibname $node
#        DiscoMe $jlibname $node

#        if {$serverPepSupport(support)} {
#            $jlibname pubsub register_event $pep($nodeIQ,eventCmd) -node $nodeIQ
#            eval {$pep($nodeIQ,discoCmd)}
#        }
#    }
}

# jlib::pep::publish --
#
#       Publish a stanza into the PEP node 
#
# Arguments:
#       node          Name of the node (mood, tune, activity, ...)
#       stanza        XML info for publishing
#
# Results:
#       none

proc jlib::pep::publish {jlibname node stanza} {
    variable xmlns
    
    Debug 4 "jlib::pep::publish node=$node"
    $jlibname pubsub publish $xmlns($node) -items [list $stanza]  \
      -command [namespace code PublishCB]
}

# jlib::pep::retract --
#
#       Retract a PEP node
#
# Arguments:
#       node          Name of the node (mood, tune, activity, ...)
#
# Results:
#       none

proc jlib::pep::retract {jlibname node} {
    variable xmlns
 
    set pepE [wrapper::createtag $node -attrlist [list xmlns $xmlns($node)]]
    set itemE [wrapper::createtag item -subtags [list $pepE]]
    $jlibname pubsub retract $xmlns($node) [list $itemE]
}

# jlib::pep::create --
#
#      Create a PEP node service 
#
# Arguments:
#      node          Name of the node (mood, tune, activity, ...)
#
# Results:
#       none

proc jlib::pep::create {jlibname node} {
    variable xmlns
    
    Debug 4 "jlib::pep::create node=$node"

    # Configure setup for PEP node
    set valueFormE [wrapper::createtag value -chdata $xmlns(node_config)]
    set fieldFormE [wrapper::createtag field  \
      -attrlist [list var "FORM_TYPE" type hidden] -subtags [list $valueFormE]]

    # PEP Values for access_model: roster / presence / open or authorize / whitelist
    # set valueModelE [wrapper::createtag value -chdata presence]
    set valueModelE [wrapper::createtag value -chdata open]
    set fieldModelE [wrapper::createtag field  \
      -attrlist [list var "pubsub#access_model"] -subtags [list $valueModelE]]

    set xattr [list xmlns "jabber:x:data" type submit]
    set xsubE [list $fieldFormE $fieldModelE]
    set xE [wrapper::createtag x -attrlist $xattr -subtags $xsubE]

    $jlibname pubsub create -node $xmlns($node) -configure $xE  \
      -command [namespace code CreateNodeCB]
}

proc  jlib::pep::OnDiscoServer {node jlibname type from subiq args} {
    variable serverPepSupport
    variable pep
    variable xmlns

    Debug 4 "jlib::pep::OnDiscoServer"

    if {$type eq "result"} {
        set nodeIQ [wrapper::getattribute $subiq node]

        # Check if disco returns <identity category='pubsub' type='pep'/>
        if {[$jlibname disco iscategorytype pubsub/pep $from $nodeIQ]} {
            set serverPepSupport(support) 1

            if { $nodeIQ eq "" } {
                set nodeIQ $xmlns($node)
            }
            $jlibname pubsub register_event $pep($nodeIQ,eventCmd) -node $nodeIQ

            DiscoMe $jlibname $node

            # Register presence for all that get available.
            $jlibname presence_register_int available  \
	      [namespace code [list PresenceEvent $node]]

            DiscoRoster $jlibname $node

            eval {$pep($nodeIQ,discoCmd)}
        }
    }
}

proc jlib::pep::DiscoMe {jlibname node} {
    variable menuMoodVar
    variable pepVers1

    set menuMoodVar "-"

    # Create Node.
    # 1. Get all the nodes that we've got created (DiscoMe items)
    # 2. If not exists the node then pubsub create (or publish an item)
    # This seems not necessary with NEW PEP.
    if {!$pepVers1} {
	set myjid2 [$jlibname  myjid2]
	$jlibname disco get_async items $myjid2  \
	    [list [namespace current]::OnDiscoMe $node]
    } else {
	
	# @@@ NEW PEP:
	# Publish node directly since PEP service automatically creates
	# a pubsub node with default configuration.
	if {$menuMoodVar ne "-"} {
	    Publish $menuMoodVar
	}
    }
}

proc jlib::pep::OnDiscoMe {node jlibname type from subiq args} {
    variable xmlns 
    variable pep

    # Create a mood node only if not there.
    if {$type eq "result"} {
	set nodes [$jlibname disco nodes $from]
	set nodeXmlns $xmlns($node)

	# Create the node if not exists.
	# NEW PEP: This is not necessary if we not want default configuration.
	if {[lsearch $nodes $nodeXmlns] < 0} {
	    create $jlibname $node 
	}
    }
}

# Others PEP -------------------------------------------------------------------
# 
#       1) Disco bare JID
#       2) subscribe to node
#       3) handle events

# Not necessary for NEW PEP.

proc jlib::pep::PresenceEvent {node jlibname xmldata} {
    variable state

    Debug 4 "jlib::pep::PresenceEvent"
    
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
        $jlibname disco get_async info $jid2  \
          [ list [namespace current]::OnDiscoInfoContact $node]
    }
}

proc jlib::pep::DiscoRoster {jlibname node} {
    
    # For those where we've already got presence.
    set jidL [$jlibname roster getusers -type available]
    foreach jid $jidL {
	
	# We may not yet have disco info for this.
	if {[$jlibname disco iscategorytype gateway/* $jid]} {
	    continue
	}
	$jlibname disco get_async info $jid  \
	  [list [namespace current]::OnDiscoInfoContact $node]
    }
}

proc jlib::pep::OnDiscoInfoContact {node jlibname type from subiq args} {
    variable state
    variable xmlns

    Debug 4 "::pep::OnDiscoInfoContact"

    # Check if contact supports pep node.
    if {$type eq "result"} {
        set nodeIQ [wrapper::getattribute $subiq node]

        # @@@ Actual implementation of ejabberd has a bug in stor.no-ip.org that doesn't returns identity
        # Check if disco returns <identity category='pubsub' type='pep'/>
        if {[$jlibname disco iscategorytype pubsub/pep $from $nodeIQ]} {
	    
            # We should be careful not to disco/publish for each presence change.
            # @@@ There is a small glitch here if user changes presence before we
            #     received its disco result.
            if {![$jlibname disco isdiscoed items $from]} {
                set jid2 [jlib::barejid $from]
                $jlibname disco get_async items $jid2  \
                    [list [namespace current]::OnDiscoItemsContact $node]
            }
        }
    }
}

proc jlib::pep::OnDiscoItemsContact {node jlibname type from subiq args} {
    variable state
    variable xmlns

    Debug 4 "::pep::OnDiscoItemsContact"

    # Get contact PEP  nodes
    if {$type eq "result"} {
        set nodes [$jlibname disco nodes $from]
        set state($from,$node,support) 1

        foreach node $nodes {
            set state($from,$node,support) 1
            set myjid2 [$jlibname myjid2]

            # NEW PEP: If we've got subscribed presence not needed to send the subscribe pubsub command
            set subscribe [$jlibname roster getsubscription $from]
#            if {$subscribe eq "none"} {
                $jlibname pubsub subscribe $from $myjid2 -node $node \
                   -command [namespace code PubSubscribeCB]
#            }
        }
    }
}

proc jlib::pep::PubSubscribeCB {args} {
    # empty
}

proc jlib::pep::PublishCB {args} {
    # empty
}

proc jlib::pep::CreateNodeCB {type args} {
    # empty
}

proc jlib::pep::Debug {num str} {
    variable debug
    if {$num <= $debug} {
	puts $str
    }
}

# We have to do it here since need the initProc before doing this.
namespace eval jlib::pep {

    jlib::ensamble_register pep  \
      [namespace current]::init    \
      [namespace current]::cmdproc
}

