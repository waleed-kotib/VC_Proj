#  disco.tcl --
#  
#      This file is part of the jabberlib.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: disco.tcl,v 1.2 2004-02-03 10:16:31 matben Exp $
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
#      discoName send_get discotype jid callbackProc ?-opt value ...?
#      discoName isdiscoed discotype jid
#      discoName get jid key
#      discoName reset ?jid?
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
    
    # Register some standard iq handlers that is handled internally.
    $jlibname iq_register get $xmlns(items)  \
      [list [namespace current]::handle_get $disconame items]
    $jlibname iq_register get $xmlns(info)   \
      [list [namespace current]::handle_get $disconame info]
    
    # Create the actual disco instance procedure.
    proc ${disconame} {cmd args}  \
      "eval disco::cmdproc {$disconame} \$cmd \$args"
    
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
    
    $disco2jlib($disconame) iq_get $xmlns($type) $jid  \
      -command [list [namespace current]::parse_get $disconame $type $jid $cmd]
}

proc disco::parse_get {disconame discotype jid cmd jlibname type subiq} {
    
    upvar ${disconame}::items items
    upvar ${disconame}::info  info

    if {[string equal $type "error"]} {
	# Empty.
    } else {
	if {[string equal $discotype "items"]} {
	    set items($jid,xml) $subiq
	    catch {unset items($jid,children)}
	    
	    foreach c [wrapper::getchildren $subiq] {
		if {![string equal [wrapper::gettag $c] "item"]} {
		    continue
		}
		catch {unset attr}
		array set attr [wrapper::getattrlist $c]
		set cjid $attr($jid)
		lappend items($jid,children) $cjid
		set items($cjid,parent) $jid
		
	    }	
	} elseif {[string equal $discotype "info"]} {
	    set info($jid,xml) $subiq
	    catch {unset info($jid,features)}
	    foreach c [wrapper::getchildren $subiq] {
		catch {unset attr}
		array set attr [wrapper::getattrlist $c]
		
		switch -- [wrapper::gettag $c] {
		    identity {
			foreach {key value} [array get attr] {
			    set info($jid,identity,$key) $value
			}
		    }
		    feature {
			lappend info($jid,features) $attr(var)
		    }
		}
	    }
	}
    }
    
    # Invoke callback for this get.
    $cmd $type $subiq
}

proc disco::isdiscoed {disconame jid discotype} {
    
    upvar ${disconame}::items items
    upvar ${disconame}::info  info
    
    return [info exists $discotype($jid,xml)]
}

proc disco::get {disconame jid key} {
    
    upvar ${disconame}::items items
    upvar ${disconame}::info  info
    
    if {[info exists items($jid,$key)]} {
	return $items($jid,$key)
    } elseif {[info exists info($jid,$key)]} {
	return $info($jid,$key)
    } else {
	return ""
    }
}

proc disco::handle_get {disconame discotype jlibname from subiq args} {
    
    upvar ${disconame}::priv priv

    set ishandled 0
    if {[info exists priv(cmd)]} {
	set ishandled [uplevel #0 $priv(cmd) [list $discotype $from $subiq] $args]
    }
    return $ishandled
}

proc disco::reset {disconame {jid ""}} {
    
    upvar ${disconame}::items items
    upvar ${disconame}::info  info

    if {$jid == ""} {
	catch {unset items($jid)}
	catch {unset info($jid)}
    } else {
	catch {unset items}
	catch {unset info}
    }
}

proc disco::Debug {num str} {
    variable debug
    if {$num <= $debug} {
	puts $str
    }
}

#-------------------------------------------------------------------------------
