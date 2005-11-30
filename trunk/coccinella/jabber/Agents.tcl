#  Agents.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the Agent(s) GUI part.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
# $Id: Agents.tcl,v 1.40 2005-11-30 08:32:00 matben Exp $

package provide Agents 1.0

namespace eval ::Agents:: {

    ::hooks::register loginHook      ::Agents::LoginCmd
    ::hooks::register logoutHook     ::Agents::LogoutHook

    option add *Agent.waveImage            wave           widgetDefault
    option add *Agent.backgroundImage      cociexec       widgetDefault

    # Standard widgets and standard options.
    option add *Agent.padding              2               50
    option add *Agent*box.borderWidth      1               50
    option add *Agent*box.relief           sunken          50

    # Template for the agent popup menu.
    variable popMenuDefs
    
    set popMenuDefs(agents,def) {
	mSearch        search    {
	    ::Search::Build -server $jid -autoget 1
	}
	mRegister      register  {
	    ::GenRegister::NewDlg -server $jid -autoget 1
	}
	mUnregister    register  {::Register::Remove $jid}
	separator      {}        {}
	mEnterRoom     groupchat {::GroupChat::EnterOrCreate enter}
	mLastLogin/Activity jid  {::Jabber::GetLast $jid}
	mLocalTime     jid       {::Jabber::GetTime $jid}
	mVersion       jid       {::Jabber::GetVersion $jid}
    }    

    # Temporary.
    variable wagents -
    variable wtab    -
}

proc ::Agents::LoginCmd { } {
    upvar ::Jabber::jprefs jprefs

    # Get the services for all our servers on the list. Depends on our settings:
    # If browsing fails must use "agents" as a fallback.
    if {[string equal $jprefs(serviceMethod) "agents"]} {
	GetAll
    }
}

proc ::Agents::LogoutHook { } {
    variable wtab
    
    if {[winfo exists $wtab]} {
	set wnb [::Jabber::UI::GetNotebook]
	$wnb forget $wtab
	destroy $wtab
    }
}

# Agents::GetAll --
#
#       Queries the services available for all the servers
#       that are in 'jprefs(agentsServers)' plus the login server.
#
# Arguments:
#       
# Results:
#       none.

proc ::Agents::GetAll { } {

    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jserver jserver
    
    set allServers [lsort -unique [concat $jserver(this) $jprefs(agentsServers)]]
    foreach server $allServers {
	Get $server
	GetAgent {} $server -silent 1
    }
}

# Agents::Get --
#
#       Calls get jabber:iq:agents to investigate the services of server jid.
#
# Arguments:
#       jid         The jid server to investigate.
#       
# Results:
#       callback scheduled.

proc ::Agents::Get {jid} {
    
    ::Jabber::JlibCmd agents_get $jid [list ::Agents::AgentsCallback $jid]
}

# Agents::GetAgent --
#
#       args    ?-silent 0/1? (D=0)
#       
# Results:
#       callback scheduled.

proc ::Agents::GetAgent {parentJid jid args} {
    
    array set opts {
	-silent 0
    }
    array set opts $args        
    ::Jabber::JlibCmd agent_get $jid  \
      [list ::Agents::GetAgentCallback $parentJid $jid $opts(-silent)]
}

# Agents::AgentsCallback --
#
#       Fills in agent tree with the info from this response via calls
#       to 'TreeItem'.
#       Makes a get jabber:iq:agent to all <agent> elements from agents get.
#       
# Arguments:
#       jid         The jid we query, the parent of all <agent> elements
#       type        "result" or "error"
#       
# Results:
#       none.

proc ::Agents::AgentsCallback {jid jlibName type subiq} {

    variable wagents
    variable wtree
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    ::Debug 2 "::Agents::AgentsCallback jid=$jid, \
      type=$type\n\tsubiq=$subiq"
    
    switch -- $type {
	error {
	    
	    # Shall we be silent? 
	    if {[winfo exists $wagents]} {
		::UI::MessageBox -type ok -icon error \
		  -message [mc jamesserragentget [lindex $subiq 1]]
	    }
	}
	ok - result {

	    # It is at this stage we are confident that an Agents page is needed.
	    NewPage
	    
	    #$wtree newitem $jid -dir 1 -open 1 -tags $jid
	    set item [::ITree::Item $wtree $jid -button 1 -open 1]
	    set bmsg "jid: $jid"
	    ::balloonhelp::treectrl $wtree $item $bmsg	    
	    
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
			::Jabber::JlibCmd get_version $jidAgent   \
			  [list ::Jabber::CacheGroupchatType $jidAgent]
			
			# The old groupchat protocol is used as a fallback.
			set jstate(conference,$jidAgent) 0
			break
		    }
		}
		
		# Fill in tree items.
		TreeItem $jid $jidAgent $subAgent
		GetAgent $jid $jidAgent -silent 1
	    }
	}
    }
}
    
# Agents::GetAgentCallback --
#
#       It receives reports from iq result elements with the
#       jabber:iq:agent namespace.
#
# Arguments:
#       jid:        the jid that we sent get jabber:iq:agent to (from attribute).
#       type:       can be 'result', or 'error'.
#       
# Results:
#       none. UI maybe updated

proc ::Agents::GetAgentCallback {parentJid jid silent jlibName type subiq} {
    
    variable wagents
    variable wtree
    variable wwave
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Agents::GetAgentCallback parentJid=$parentJid,\
      jid=$jid, type=$type"
    
    if {[winfo exists $wagents]} {
	$wwave animate -1
    }
    
    switch -- $type {
	error {
	    if {$silent} {
		::Jabber::AddErrorLog $jid  \
		  "Failed getting agent info. The error was: [lindex $subiq 1]"
	    } else {
	    }
	}
	result - ok {
	
	    # Fill in tree.
	    TreeItem $parentJid $jid [wrapper::getchildren $subiq]
	}
    }
}

# Agents::TreeItem --
#
#

proc ::Agents::TreeItem {parentJid jid subAgent} {
    
    variable wtree
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Debug 4 "::Agents::TreeItem parentJid=$parentJid, jid=$jid"
    	
    # Loop through the subelement to see what we've got.
    foreach elem $subAgent {
	set tag [wrapper::gettag $elem]
	set agentSubArr($tag) [wrapper::getcdata $elem]
    }
    if {[lsearch [concat $jserver(this) $jprefs(agentsServers)] $jid] < 0} {
	set isServer 0
    } else {
	set isServer 1
    }
    if {$isServer} {	
	if {[info exists agentSubArr(name)]} {
	    ::ITree::ItemConfigure $wtree $jid -text $agentSubArr(name)
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
	set item [::ITree::Item $wtree $v -button 1 -open 1 -text $txt]
	set bmsg "jid: $jid"
	
	foreach tag [array names agentSubArr] {
	    switch -- $tag {
		register - search - groupchat {
		    ::ITree::Item $wtree [concat $v $tag] -text $tag
		}
		service {
		    ::ITree::Item $wtree [concat $v $tag]  \
		      -text "service: $agentSubArr($tag)"
		}
		transport {
		    ::ITree::Item $wtree [concat $v $tag]  \
		      -text $agentSubArr($tag)
		} 
		description {
		    append bmsg "\n$agentSubArr(description)"
		} 
		name {
		    # nothing
		} 
		default {
		    ::ITree::Item $wtree [concat $v $tag] -text $tag
		}
	    }
	}
	::balloonhelp::treectrl $wtree $item $bmsg	    
    }
}

proc ::Agents::NewPage { } {
    variable wtab
    
    set wnb [::Jabber::UI::GetNotebook]
    set wtab $wnb.ag
    if {![winfo exists $wtab]} {
	set im [::Theme::GetImage \
	  [option get [winfo toplevel $wnb] browser16Image {}]]
	set imd [::Theme::GetImage \
	  [option get [winfo toplevel $wnb] browser16DisImage {}]]
	set imSpec [list $im disabled $imd background $imd]
	Build $wtab
	$wnb add $wtab -text [mc Agents] -image $imSpec -compound left
    }
}

# Agents::Build --
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

proc ::Agents::Build {w args} {
    global  prefs this

    variable wagents
    variable wtree
    variable wwave
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Agents::Build w=$w"
        
    set wagents $w
    set wwave   $w.fs
    set wbox    $w.box
    set wtree   $wbox.tree
    set wxsc    $wbox.xsc
    set wysc    $wbox.ysc

    # The frame.
    ttk::frame $w -class Agent
    
    set waveImage [::Theme::GetImage [option get $w waveImage {}]]  
    ::wavelabel::wavelabel $wwave -relief groove -bd 2 \
      -type image -image $waveImage
    pack $wwave -side bottom -fill x -padx 8 -pady 2
    
    # D = -border 1 -relief sunken
    frame $wbox
    pack  $wbox -side top -fill both -expand 1

    set bgimage [::Theme::GetImage [option get $w backgroundImage {}]]

    ttk::scrollbar $wxsc -orient horizontal -command [list $wtree xview]
    ttk::scrollbar $wysc -orient vertical -command [list $wtree yview]
    ::ITree::New $wtree $wxsc $wysc   \
      -selection   ::Agents::Selection     \
      -open        ::Agents::OpenTreeCmd   \
      -buttonpress ::Agents::Popup         \
      -buttonpopup ::Agents::Popup         \
      -backgroundimage $bgimage

    grid  $wtree  -row 0 -column 0 -sticky news
    grid  $wysc   -row 0 -column 1 -sticky ns
    grid  $wxsc   -row 1 -column 0 -sticky ew
    grid columnconfigure $wbox 0 -weight 1
    grid rowconfigure $wbox 0 -weight 1
    
    return $w
}

# Agents::Selection --
#
#
# Arguments:
#       T           tree widget
#       v           tree item path
#       
# Results:
#       .

proc ::Agents::Selection {T v} {
    # empty
}

# Agents::OpenTreeCmd --
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

proc ::Agents::OpenTreeCmd {w v} {
    # empty
}
    
proc ::Agents::RegisterPopupEntry {menuSpec} {
    variable popMenuDefs
    
    set popMenuDefs(agents,def) [concat $popMenuDefs(agents,def) $menuSpec]
}

# Agents::Popup --
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

proc ::Agents::Popup {w v x y} {
    global  wDlgs this
    variable popMenuDefs
    
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Agents::Popup w=$w, v='$v', x=$x, y=$y"
    
    # The last element of $v is either a jid, (a namespace,) 
    # a header in roster, a group, or an agents xml tag.
    # The variables name 'jid' is a misnomer.
    # Find also type of thing clicked, 'typeClicked'.
    
    set typeClicked ""
    
    set jid [lindex $v end]
    set jid3 $jid
    set childs [::ITree::Children $w $v]
    if {[regexp {(register|search|groupchat)} $jid match service]} {
	set typeClicked $service
	set jid [lindex $v end-1]
    } elseif {$jid ne ""} {
	set typeClicked jid
    }
    set services {}
    foreach c $childs {
	set tag [lindex $c end]
	if {[regexp {(register|search|groupchat)} $tag match service]} {
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
	    set locname [mc $item]
	    $m add cascade -label $locname -menu $mt -state disabled
	    eval [string range $cmd 1 end] $mt
	    incr i
	} elseif {[string equal $item "separator"]} {
	    $m add separator
	    continue
	} else {
	    
	    # Substitute the jid arguments. Preserve list structure!
	    set cmd [eval list $cmd]
	    set locname [mc $item]
	    $m add command -label $locname -command [list after 40 $cmd]  \
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

#-------------------------------------------------------------------------------