#  Agents.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the Agent(s) GUI part.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
# $Id: Agents.tcl,v 1.16 2004-04-25 15:35:24 matben Exp $

package provide Agents 1.0

namespace eval ::Jabber::Agents:: {

    ::hooks::add loginHook      ::Jabber::Agents::LoginCmd
    ::hooks::add logoutHook     ::Jabber::Agents::LogoutHook

    # We keep an reference count that gets increased by one for each request
    # sent, and decremented by one for each response.
    variable arrowRefCount 0
    variable arrMsg ""
    
    # Template for the agent popup menu.
    variable popMenuDefs
    
    set popMenuDefs(agents,def) {
	mSearch        search    {
	    ::Jabber::Search::Build -server $jid -autoget 1
	}
	mRegister      register  {
	    ::Jabber::GenRegister::BuildRegister -server $jid -autoget 1
	}
	mUnregister    register  {::Jabber::Register::Remove $jid}
	separator      {}        {}
	mEnterRoom     groupchat {::Jabber::GroupChat::EnterOrCreate enter}
	mLastLogin/Activity jid  {::Jabber::GetLast $jid}
	mLocalTime     jid       {::Jabber::GetTime $jid}
	mVersion       jid       {::Jabber::GetVersion $jid}
    }    
}

proc ::Jabber::Agents::LoginCmd { } {
    upvar ::Jabber::jprefs jprefs

    # Get the services for all our servers on the list. Depends on our settings:
    # If browsing fails must use "agents" as a fallback.
    if {[string equal $jprefs(serviceMethod) "agents"]} {
	::Jabber::Agents::GetAll
    }
}

proc ::Jabber::Agents::LogoutHook { } {
    
    
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
    
    ::Jabber::InvokeJlibCmd agents_get $jid  \
      [list ::Jabber::Agents::AgentsCallback $jid]
}

# Jabber::Agents::GetAgent --
#
#       args    ?-silent 0/1? (D=0)
#       
# Results:
#       callback scheduled.

proc ::Jabber::Agents::GetAgent {parentJid jid args} {
    
    array set opts {
	-silent 0
    }
    array set opts $args        
    ::Jabber::InvokeJlibCmd agent_get $jid  \
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
#       type        "ok" or "error"
#       
# Results:
#       none.

proc ::Jabber::Agents::AgentsCallback {jid jlibName type subiq} {

    variable wagents
    variable wtree
    variable wtreecanvas
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    ::Debug 2 "::Jabber::Agents::AgentsCallback jid=$jid, \
      type=$type\n\tsubiq=$subiq"
    
    switch -- $type {
	error {
	    
	    # Shall we be silent? 
	    if {[winfo exists $wagents]} {
		tk_messageBox -type ok -icon error \
		  -message [FormatTextForMessageBox  \
		  [::msgcat::mc jamesserragentget [lindex $subiq 1]]]
	    }
	}
	ok - result {

	    # It is at this stage we are confident that an Agents page is needed.
	    ::Jabber::UI::NewPage "Agents"
	    
	    $wtree newitem $jid -dir 1 -open 1 -tags $jid
	    set bmsg "jid: $jid"
	    ::balloonhelp::balloonforcanvas $wtreecanvas $jid $bmsg	    
	    
	    # Loop through all <agent> elements and:
	    # 1) fill in what we've got so far.
	    # 2) send get jabber:iq:agent.
	    foreach agent [wrapper::getchildren $subiq] {
		if {![string equal [wrapper::gettag $agent] "agent"]} {
		    continue
		}
		set subAgent [wrapper::getchildren $agent]
		set jidAgent [wrapper::getattribute $agent jid]
		
		# If any groupchat/conference service we need to query its
		# version number to know which protocol to use.
		foreach elem $subAgent {
		    if {[string equal [wrapper::gettag $elem] "groupchat"]} {
			::Jabber::InvokeJlibCmd get_version $jidAgent   \
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
}
    
# Jabber::Agents::GetAgentCallback --
#
#       It receives reports from iq result elements with the
#       jabber:iq:agent namespace.
#
# Arguments:
#       jid:        the jid that we sent get jabber:iq:agent to (from attribute).
#       type:       can be 'ok', or 'error'.
#       
# Results:
#       none. UI maybe updated

proc ::Jabber::Agents::GetAgentCallback {parentJid jid silent jlibName type subiq} {
    
    variable wagents
    variable warrows
    variable wtree
    variable wtreecanvas
    variable arrMsg
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jerror jerror
    
    ::Debug 2 "::Jabber::Agents::GetAgentCallback parentJid=$parentJid,\
      jid=$jid, type=$type"
    
    if {[winfo exists $wagents]} {
	::Jabber::Agents::ControlArrows -1
    }
    
    switch -- $type {
	error {
	    if {$silent} {
		lappend jerror [list [clock format [clock seconds] -format "%H:%M:%S"]  \
		  $jid "Failed getting agent info. The error was: [lindex $subiq 1]"]	    
	    } else {
	    }
	}
	result - ok {
	
	    # Fill in tree.
	    ::Jabber::Agents::AddAgentToTree $parentJid $jid  \
	      [wrapper::getchildren $subiq]
	}
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
    
    ::Debug 4 "::Jabber::Agents::AddAgentToTree parentJid=$parentJid,\
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
    global  prefs this

    variable wagents
    variable warrows
    variable wtree
    variable wtreecanvas
    variable arrMsg
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Jabber::Agents::Build w=$w"
        
    # The frame.
    frame $w -borderwidth 0 -relief flat
    set wagents $w

    # Start with running arrows and message.
    pack [frame $w.bot] -side bottom -fill x -anchor w -padx 8 -pady 6
    set warrows $w.bot.arr
    pack [::chasearrows::chasearrows $warrows -size 16] \
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
      -scrollwidth 400 \
      -xscrollcommand [list $wxsc set]       \
      -yscrollcommand [list $wysc set]       \
      -selectcommand ::Jabber::Agents::SelectCmd   \
      -opencommand ::Jabber::Agents::OpenTreeCmd
    set wtreecanvas [$wtree getcanvas]
    if {[string match "mac*" $this(platform)]} {
	$wtree configure -buttonpresscommand [namespace current]::Popup \
	  -eventlist [list [list <Control-Button-1> [namespace current]::Popup]]
    } else {
	$wtree configure -rightclickcommand [namespace current]::Popup
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
    
proc ::Jabber::Agents::RegisterPopupEntry {menuSpec} {
    variable popMenuDefs
    
    set popMenuDefs(agents,def) [concat $popMenuDefs(agents,def) $menuSpec]
}

# Jabber::Agents::Popup --
#
#       Handle popup menus in agent, typically from right-clicking.
#       
# Arguments:
#       w           widget that issued the command: tree or text
#       v           for the tree widget it is the item path, 
#                   for text the jidhash.
#       
# Results:
#       popup menu displayed

proc ::Jabber::Agents::Popup {w v x y} {
    global  wDlgs this
    variable popMenuDefs
    
    upvar ::Jabber::privatexmlns privatexmlns
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::Agents::Popup w=$w, v='$v', x=$x, y=$y"
    
    # The last element of $v is either a jid, (a namespace,) 
    # a header in roster, a group, or an agents xml tag.
    # The variables name 'jid' is a misnomer.
    # Find also type of thing clicked, 'typeClicked'.
    
    set typeClicked ""
    
    set jid [lindex $v end]
    set jid3 $jid
    set childs [$w children $v]
    if {[regexp {(register|search|groupchat)} $jid match service]} {
	set typeClicked $service
	set jid [lindex $v end-1]
    } elseif {$jid != ""} {
	set typeClicked jid
    }
    set services {}
    foreach c $childs {
	if {[regexp {(register|search|groupchat)} $c match service]} {
	    lappend services $service
	}
    }
    if {[string length $jid] == 0} {
	set typeClicked ""	
    }
    set X [expr [winfo rootx $w] + $x]
    set Y [expr [winfo rooty $w] + $y]
    
    ::Debug 2 "\t jid=$jid, typeClicked=$typeClicked"
    
    # Mads Linden's workaround for menu post problem on mac:
    # all in menubutton commands i add "after 40 the_command"
    # this way i can never have to posting error.
    # it is important after the tk_popup f.ex to
    #
    # destroy .mb
    # update
    #
    # this way the .mb is destroyd before the next window comes up, thats how I
    # got around this.
    
    # Make the appropriate menu.
    set m $jstate(wpopup,agents)
    set i 0
    catch {destroy $m}
    menu $m -tearoff 0
    
    foreach {item type cmd} $popMenuDefs(agents,def) {
	if {[string index $cmd 0] == "@"} {
	    set mt [menu ${m}.sub${i} -tearoff 0]
	    set locname [::msgcat::mc $item]
	    $m add cascade -label $locname -menu $mt -state disabled
	    eval [string range $cmd 1 end] $mt
	    incr i
	} elseif {[string equal $item "separator"]} {
	    $m add separator
	    continue
	} else {
	    
	    # Substitute the jid arguments.
	    set cmd [subst -nocommands $cmd]
	    set locname [::msgcat::mc $item]
	    $m add command -label $locname -command "after 40 $cmd"  \
	      -state disabled
	}
	
	# If a menu should be enabled even if not connected do it here.
	
	if {![::Jabber::IsConnected]} {
	    continue
	}
	if {[string equal $type "any"]} {
	    $m entryconfigure $locname -state normal
	    continue
	}
	
	# State of menu entry. We use the 'type' and 'typeClicked' to sort
	# out which capabilities to offer for the clicked item.
	set state disabled
	
	if {[string equal $type $typeClicked]} {
	    set state normal
	} elseif {[lsearch $services $type] >= 0} {
	    set state normal
	}
	if {[string equal $state "normal"]} {
	    $m entryconfigure $locname -state normal
	}
    }   
    
    # This one is needed on the mac so the menu is built before it is posted.
    update idletasks
    
    # Post popup menu.
    tk_popup $m [expr int($X) - 10] [expr int($Y) - 10]   
    
    # Mac bug... (else can't post menu while already posted if toplevel...)
    if {[string equal "macintosh" $this(platform)]} {
	catch {destroy $m}
	update
    }
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