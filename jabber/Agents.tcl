#  Agents.tcl ---
#  
#      This file is part of the whiteboard application. 
#      It implements the Agent(s) GUI part.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
# $Id: Agents.tcl,v 1.3 2003-11-08 08:54:44 matben Exp $

package provide Agents 1.0

namespace eval ::Jabber::Agents:: {

    # We keep an reference count that gets increased by one for each request
    # sent, and decremented by one for each response.
    variable arrowRefCount 0
    variable arrMsg ""
}

# Jabber::Agents::GetAll --
#
#       Queries the services available for all the servers
#       that are in 'jprefs(agentsServers)' plus the login server.
#
# Arguments:
#       
# Results:
#       none.

proc ::Jabber::Agents::GetAll { } {

    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jserver jserver
    
    set allServers [lsort -unique [concat $jserver(this) $jprefs(agentsServers)]]
    foreach server $allServers {
	::Jabber::Agents::Get $server
	::Jabber::Agents::GetAgent {} $server -silent 1
    }
}

# Jabber::Agents::Get --
#
#       Calls get jabber:iq:agents to investigate the services of server jid.
#
# Arguments:
#       jid         The jid server to investigate.
#       
# Results:
#       callback scheduled.

proc ::Jabber::Agents::Get {jid} {
    
    upvar ::Jabber::jstate jstate
    
    $jstate(jlib) agents_get $jid [list ::Jabber::Agents::AgentsCallback $jid]
}

# Jabber::Agents::GetAgent --
#
#       args    ?-silent 0/1? (D=0)
#       
# Results:
#       callback scheduled.

proc ::Jabber::Agents::GetAgent {parentJid jid args} {
    
    upvar ::Jabber::jstate jstate
    
    array set opts {
	-silent 0
    }
    array set opts $args        
    $jstate(jlib) agent_get $jid  \
      [list ::Jabber::Agents::GetAgentCallback $parentJid $jid $opts(-silent)]
}

# Jabber::Agents::AgentsCallback --
#
#       Fills in agent tree with the info from this response via calls
#       to 'AddAgentToTree'.
#       Makes a get jabber:iq:agent to all <agent> elements from agents get.
#       
# Arguments:
#       jid         The jid we query, the parent of all <agent> elements
#       what        "ok" or "error"
#       
# Results:
#       none.

proc ::Jabber::Agents::AgentsCallback {jid jlibName what subiq} {

    variable wagents
    variable wtree
    variable wtreecanvas
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    ::Jabber::Debug 2 "::Jabber::Agents::AgentsCallback jid=$jid, \
      what=$what\n\tsubiq=$subiq"
    
    if {[string equal $what "error"]} {
	    
	# Shall we be silent? 
	if {[winfo exists $wagents]} {
	    tk_messageBox -type ok -icon error \
	      -message [FormatTextForMessageBox  \
	      [::msgcat::mc jamesserragentget [lindex $subiq 1]]]
	}
    } elseif {[string equal $what "ok"]} {
    
	# It is at this stage we are confident that an Agents page is needed.
	::Jabber::UI::NewPage "Agents"

	$wtree newitem $jid -dir 1 -open 1 -tags $jid
	set bmsg "jid: $jid"
	::balloonhelp::balloonforcanvas $wtreecanvas $jid $bmsg	    

	# Loop through all <agent> elements and:
	# 1) fill in what we've got so far.
	# 2) send get jabber:iq:agent.
	foreach agent [wrapper::getchildren $subiq] {
	    if {![string equal [lindex $agent 0] "agent"]} {
		continue
	    }
	    set subAgent [wrapper::getchildren $agent]
	    set jidAgent [wrapper::getattribute $agent jid]
	    
	    # If any groupchat/conference service we need to query its
	    # version number to know which protocol to use.
	    foreach elem $subAgent {
		if {[string equal [wrapper::gettag $elem] "groupchat"]} {
		    $jstate(jlib) get_version $jidAgent   \
		      [list ::Jabber::CacheGroupchatType $jidAgent]
		    
		    # The old groupchat protocol is used as a fallback.
		    set jstate(conference,$jidAgent) 0
		    break
		}
	    }
		
	    # Fill in tree items.
	    ::Jabber::Agents::AddAgentToTree $jid $jidAgent $subAgent
	    ::Jabber::Agents::GetAgent $jid $jidAgent -silent 1
	}
    }
}
    
# Jabber::Agents::GetAgentCallback --
#
#       It receives reports from iq result elements with the
#       jabber:iq:agent namespace.
#
# Arguments:
#       jid:        the jid that we sent get jabber:iq:agent to (from attribute).
#       what:       can be 'ok', or 'error'.
#       
# Results:
#       none. UI maybe updated

proc ::Jabber::Agents::GetAgentCallback {parentJid jid silent jlibName what subiq} {
    
    variable wagents
    variable warrows
    variable wtree
    variable wtreecanvas
    variable arrMsg
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jerror jerror
    
    ::Jabber::Debug 2 "::Jabber::Agents::GetAgentCallback parentJid=$parentJid,\
      jid=$jid, what=$what"
    
    if {[winfo exists $wagents]} {
	::Jabber::Agents::ControlArrows -1
    }
    if {[string equal $what "error"]} {
	if {$silent} {
	    lappend jerror [list [clock format [clock seconds] -format "%H:%M:%S"]  \
	      $jid "Failed getting agent info. The error was: [lindex $subiq 1]"]	    
	} else {
	}
    } elseif {[string equal $what "ok"]} {
	
	# Fill in tree.
	::Jabber::Agents::AddAgentToTree $parentJid $jid  \
	  [wrapper::getchildren $subiq]
    }
}

# Jabber::Agents::AddAgentToTree --
#
#

proc ::Jabber::Agents::AddAgentToTree {parentJid jid subAgent} {
    
    variable wtree
    variable wtreecanvas
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 4 "::Jabber::Agents::AddAgentToTree parentJid=$parentJid,\
      jid=$jid, subAgent='$subAgent'"
    	
    # Loop through the subelement to see what we've got.
    foreach elem $subAgent {
	set tag [lindex $elem 0]
	set agentSubArr($tag) [lindex $elem 3]
    }
    if {[lsearch [concat $jserver(this) $jprefs(agentsServers)] $jid] < 0} {
	set isServer 0
    } else {
	set isServer 1
    }
    if {$isServer} {	
	if {[info exists agentSubArr(name)]} {
	    $wtree itemconfigure $jid -text $agentSubArr(name)
	}
    } else {
	if {[string length $parentJid] > 0} {
	    set v [list $parentJid $jid]
	} else {
	    set v $jid
	}
	set txt $jid
	if {[info exists agentSubArr(name)]} {
	    set txt $agentSubArr(name)
	}
	$wtree newitem $v -dir 1 -open 1 -text $txt -tags $jid
	set bmsg "jid: $jid"
	
	foreach tag [array names agentSubArr] {
	    switch -- $tag {
		register - search - groupchat {
		    $wtree newitem [concat $v $tag]
		}
		service {
		    $wtree newitem [concat $v $tag]  \
		      -text "service: $agentSubArr($tag)"
		}
		transport {
		    $wtree newitem [concat $v $tag]  \
		      -text $agentSubArr($tag)
		} 
		description {
		    append bmsg "\n$agentSubArr(description)"
		} 
		name {
		    # nothing
		} 
		default {
		    $wtree newitem [concat $v $tag]
		}
	    }
	}
	::balloonhelp::balloonforcanvas $wtreecanvas $jid $bmsg	    
    }
}

# Jabber::Agents::Build --
#
#       This is supposed to create a frame which is pretty object like,
#       and handles most stuff internally without intervention.
#       
# Arguments:
#       w           frame for everything
#       args   
#       
# Results:
#       w

proc ::Jabber::Agents::Build {w args} {
    global  sysFont prefs this

    variable wagents
    variable warrows
    variable wtree
    variable wtreecanvas
    variable arrMsg
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::Agents::Build w=$w"
        
    # The frame.
    frame $w -borderwidth 0 -relief flat
    set wagents $w

    # Start with running arrows and message.
    pack [frame $w.bot] -side bottom -fill x -anchor w -padx 8 -pady 6
    set warrows $w.bot.arr
    pack [::chasearrows::chasearrows $warrows -background gray87 -size 16] \
      -side left -padx 5 -pady 5
    pack [label $w.bot.la   \
      -textvariable [namespace current]::arrMsg] -side left -padx 8 -pady 6
    
    # Tree part
    set wbox $w.box
    pack [frame $wbox -border 1 -relief sunken]   \
      -side top -fill both -expand 1 -padx 6 -pady 6
    set wtree $wbox.tree
    set wxsc $wbox.xsc
    set wysc $wbox.ysc
    scrollbar $wxsc -orient horizontal -command [list $wtree xview]
    scrollbar $wysc -orient vertical -command [list $wtree yview]
    ::tree::tree $wtree -width 180 -height 200 -silent 1  \
      -openicons triangle -treecolor {} -scrollwidth 400 \
      -xscrollcommand [list $wxsc set]       \
      -yscrollcommand [list $wysc set]       \
      -selectcommand ::Jabber::Agents::SelectCmd   \
      -opencommand ::Jabber::Agents::OpenTreeCmd   \
      -highlightcolor #6363CE -highlightbackground $prefs(bgColGeneral)
    set wtreecanvas [$wtree getcanvas]
    if {[string match "mac*" $this(platform)]} {
	$wtree configure -buttonpresscommand [list ::Jabber::UI::Popup agents] \
	  -eventlist [list [list <Control-Button-1> [list ::Jabber::UI::Popup agents]]]
    } else {
	$wtree configure -rightclickcommand  \
	  [list ::Jabber::UI::Popup agents]
    }
    grid $wtree -row 0 -column 0 -sticky news
    grid $wysc -row 0 -column 1 -sticky ns
    grid $wxsc -row 1 -column 0 -sticky ew
    grid columnconfigure $wbox 0 -weight 1
    grid rowconfigure $wbox 0 -weight 1
    
    return $w
}

# Jabber::Agents::SelectCmd --
#
#
# Arguments:
#       w           tree widget
#       v           tree item path
#       
# Results:
#       .

proc ::Jabber::Agents::SelectCmd {w v} {
    
    
}

# Jabber::Agents::OpenTreeCmd --
#
#       Callback when open service item in tree.
#       It calls jabber:iq:agent of the server jid, typically
#       jud.jabber.org, aim.jabber.org etc.
#
# Arguments:
#       w           tree widget
#       v           tree item path (jidList: {jabber.org jud.jabber.org} etc.)
#       
# Results:
#       .

proc ::Jabber::Agents::OpenTreeCmd {w v} {
    
    
    
}

proc ::Jabber::Agents::ControlArrows {step} {
    
    variable warrows
    variable arrowRefCount
    
    if {$step == 1} {
	incr arrowRefCount
	if {$arrowRefCount == 1} {
	    $warrows start
	}
    } elseif {$step == -1} {
	incr arrowRefCount -1
	if {$arrowRefCount <= 0} {
	    set arrowRefCount 0
	    $warrows stop
	}
    } elseif {$step == 0} {
	set arrowRefCount 0
	$warrows stop
    }
}

#-------------------------------------------------------------------------------