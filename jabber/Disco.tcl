#  Disco.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the Disco application part.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: Disco.tcl,v 1.32 2004-10-01 12:44:11 matben Exp $

package provide Disco 1.0

namespace eval ::Jabber::Disco:: {

    ::hooks::register jabberInitHook     ::Jabber::Disco::NewJlibHook
    ::hooks::register loginHook          ::Jabber::Disco::LoginHook
    ::hooks::register logoutHook         ::Jabber::Disco::LogoutHook
    ::hooks::register presenceHook       ::Jabber::Disco::PresenceHook

    # Common xml namespaces.
    variable xmlns
    array set xmlns {
	disco           http://jabber.org/protocol/disco 
	items           http://jabber.org/protocol/disco#items 
	info            http://jabber.org/protocol/disco#info
    }
    
    # Disco catagories from Jabber :: Registrar determines if dir or not.
    variable categoryShowDir
    array set categoryShowDir {
	auth                  0
	automation            1
	client                1
	collaboration         1
	component             1
	conference            1
	directory             1
	gateway               0
	headline              0
	hierarchy             1
	proxy                 0
	pubsub                1
	server                1
	store                 1
    }
    
    # Template for the browse popup menu.
    variable popMenuDefs

    set popMenuDefs(disco,def) {
	mMessage       user      {::Jabber::NewMsg::Build -to $jid}
	mChat          user      {::Jabber::Chat::StartThread $jid}
	mWhiteboard    wb        {::Jabber::WB::NewWhiteboardTo $jid}
	mEnterRoom     room      {
	    ::Jabber::GroupChat::EnterOrCreate enter -roomjid $jid -autoget 1
	}
	mCreateRoom    conference {::Jabber::GroupChat::EnterOrCreate create \
	  -server $jid}
	separator      {}        {}
	mInfo          jid       {::Jabber::Disco::InfoCmd $jid}
	mLastLogin/Activity jid  {::Jabber::GetLast $jid}
	mLocalTime     jid       {::Jabber::GetTime $jid}
	mvCard         jid       {::VCard::Fetch other $jid}
	mVersion       jid       {::Jabber::GetVersion $jid}
	separator      {}        {}
	mSearch        search    {
	    ::Jabber::Search::Build -server $jid -autoget 1
	}
	mRegister      register  {
	    ::Jabber::GenRegister::NewDlg -server $jid -autoget 1
	}
	mUnregister    register  {::Jabber::Register::Remove $jid}
	separator      {}        {}
	mRefresh       jid       {::Jabber::Disco::Refresh $jid}
    }

    variable dlguid 0

    # Use a unique canvas tag in the tree widget for each jid put there.
    # This is needed for the balloons that need a real canvas tag, and that
    # we can't use jid's for this since they may contain special chars (!)!
    variable treeuid 0

    # We keep an reference count that gets increased by one for each request
    # sent, and decremented by one for each response.
    variable arrowRefCount 0
    
    # We could add more icons for other categories here!
    variable typeIcon
    array set typeIcon [list                                 \
	gateway/aim           [::UI::GetIcon aim_online]     \
	gateway/icq           [::UI::GetIcon icq_online]     \
	gateway/msn           [::UI::GetIcon msn_online]     \
	gateway/yahoo         [::UI::GetIcon yahoo_online]   \
	gateway/x-gadugadu    [::UI::GetIcon gadugadu_online]\
	]
}

proc ::Jabber::Disco::NewJlibHook {jlibName} {
    variable xmlns
    upvar ::Jabber::jstate jstate
	    
    set jstate(disco) [disco::new $jlibName -command  \
      ::Jabber::Disco::Command]

    ::Jabber::AddClientXmlns [list $xmlns(disco)]
}

proc ::Jabber::Disco::LoginHook { } {
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jserver jserver
    
    # Get the services for all our servers on the list. Depends on our settings:
    # If disco fails must use "browse" or "agents" as a fallback.
    #
    # We disco servers jid 'items+info', and disco its childrens 'info'.
    if {[string equal $jprefs(serviceMethod) "disco"]} {
	::Jabber::Disco::GetItems $jserver(this)
	::Jabber::Disco::GetInfo  $jserver(this)
    }
}

proc ::Jabber::Disco::LogoutHook { } {
    
    if {[lsearch [::Jabber::UI::Pages] "Disco"] >= 0} {
	#::Jabber::Disco::SetUIWhen "disconnect"
    }
    ::Jabber::Disco::Clear
}

proc ::Jabber::Disco::HaveTree { } {    
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jstate jstate
    
    if {[info exists jstate(disco)]} {
	if {[$jstate(disco) isdiscoed items $jserver(this)]} {
	    return 1
	}
    }    
    return 0
}

# Jabber::Disco::GetInfo, GetItems --
#
#       Discover the services available for the $jid.
#
# Arguments:
#       jid         The jid to discover.
#       args    ?-silent 0/1? (D=0)
#       
# Results:
#       callback scheduled.

proc ::Jabber::Disco::GetInfo {jid args} {    
    upvar ::Jabber::jstate jstate
    
    array set opts {
	-silent 0
    }
    array set opts $args
    
    # Discover services available.
    $jstate(disco) send_get info  $jid [namespace current]::InfoCB
}

proc ::Jabber::Disco::GetItems {jid args} {    
    upvar ::Jabber::jstate jstate
    
    array set opts {
	-silent 0
    }
    array set opts $args
    
    # Discover services available.
    $jstate(disco) send_get items $jid [namespace current]::ItemsCB
}


proc ::Jabber::Disco::Command {disconame discotype from subiq args} {
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Jabber::Disco::Command discotype=$discotype, from=$from"

    if {[string equal $discotype "info"]} {
	eval {::Jabber::Disco::ParseGetInfo $from $subiq} $args
    } elseif {[string equal $discotype "items"]} {
	eval {::Jabber::Disco::ParseGetItems $from $subiq} $args
    }
        
    # Tell jlib's iq-handler that we handled the event.
    return 1
}

proc ::Jabber::Disco::ItemsCB {disconame type from subiq args} {
    variable tstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Jabber::Disco::ItemsCB type=$type, from=$from"
    set from [jlib::jidmap $from]
    
    switch -- $type {
	error {
	    
	    # As a fallback we use the agents/browse method instead.
	    if {[jlib::jidequal $from $jserver(this)]} {
		
		switch -- $jprefs(serviceMethod) {
		    disco {
			::Jabber::Browse::GetAll
		    }
		    browse {
			::Jabber::Agents::GetAll
		    }
		}
	    }
	    ::Jabber::AddErrorLog $from "Failed disco $from"
	    catch {::Jabber::Disco::ControlArrows -1}
	}
	ok - result {

	    # It is at this stage we are confident that a Disco page is needed.
	    if {[jlib::jidequal $from $jserver(this)]} {
		::Jabber::UI::NewPage "Disco"
	    }
	    unset -nocomplain tstate(run,$from)
	    ::Jabber::Disco::ControlArrows -1

	    # Add to tree.
	    set parents [$jstate(disco) parents $from]
	    set v [concat $parents $from]
	    ::Jabber::Disco::AddToTree $v

	    # Get info for the login servers children.
	    set childs [$jstate(disco) children $from]
	    foreach cjid $childs {
		
		# We disco servers jid 'items+info', and disco its childrens 'info'.
		# 
		# Perhaps we should discover depending on items category?
		if {[jlib::jidequal $from $jserver(this)]} {
		    ::Jabber::Disco::GetInfo $cjid
		}		
	    }	    
	}
    }
    
    eval {::hooks::run discoItemsHook $type $from $subiq} $args
}

proc ::Jabber::Disco::InfoCB {disconame type from subiq args} {
    variable wtree
    variable typeIcon
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::Disco::InfoCB type=$type, from=$from"
    if {$type == "error"} {
	::Jabber::AddErrorLog $from $subiq
	return
    }
    
    # The info contains the name attribute (optional) which may
    # need to be set since we get items before name.
    # 
    # BUT the items element may also have a name attribute???
    if {![info exists wtree] || ![winfo exists $wtree]} {
	return
    }
    set from [jlib::jidmap $from]
    set name [$jstate(disco) name $from]
    
    # Icon.
    set cattype [lindex [$jstate(disco) types $from] 0]
    set icon  ""
    if {[info exists typeIcon($cattype)]} {
	set icon $typeIcon($cattype)
    }
    
    foreach v [$wtree find withtag $from] {
	if {$name != ""} {
	    $wtree itemconfigure $v -text $name
	}
	if {$icon != ""} {
	    $wtree itemconfigure $v -image $icon
	}
	set treectag [$wtree itemconfigure $v -canvastags]
	::Jabber::Disco::MakeBalloonHelp $from $treectag
    }
    ::Jabber::Disco::SetDirItemUsingCategory $from
    
    # Use specific (discoInfoGatewayIcqHook, discoInfoServerImHook,...) 
    # and general (discoInfoHook) hooks.
    set ct [split $cattype /]
    set hookName [string totitle [lindex $ct 0]][string totitle [lindex $ct 1]]
    eval {::hooks::run discoInfo${hookName}Hook $type $from $subiq} $args
    eval {::hooks::run discoInfoHook $type $from $subiq} $args
}

proc ::Jabber::Disco::SetDirItemUsingCategory {jid} {
    variable wtree
    
    if {[::Jabber::Disco::IsDirCategory $jid]} {
	foreach v [$wtree find withtag $jid] {
	    $wtree itemconfigure $v -dir 1
	}
    }
}

proc ::Jabber::Disco::IsDirCategory {jid} {
    variable categoryShowDir
    upvar ::Jabber::jstate jstate
    
    set isdir 0
    
    # Ad-hoc way to figure out if dir or not. Use the category attribute.
    set types [$jstate(disco) types $jid]
    foreach type $types {
	set category [lindex [split $type /] 0]
	if {[info exists categoryShowDir($category)] && \
	  $categoryShowDir($category)} {
	    set isdir 1
	    break
	}
    }
    
    # Don't forget the rooms.
    if {!$isdir} {
	set isdir [$jstate(disco) isroom $jid]
    }
    return $isdir
}
	    
# Jabber::Disco::ParseGetInfo --
#
#       Respond to an incoming discovery get query.
#       
# Results:
#       none

proc ::Jabber::Disco::ParseGetInfo {from subiq args} {
    global  prefs
    variable xmlns
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::coccixmlns coccixmlns

    ::Debug 2 "::Jabber::Disco::ParseGetInfo: args='$args'"
    
    array set argsArr $args
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }
    set node [wrapper::getattribute $subiq node]

    if {$node == ""} {
	    
	# No node. Adding private namespaces.
	set vars {}
	foreach ns [::Jabber::GetClientXmlnsList] {
	    lappend vars $ns
	}
	set subtags [list [wrapper::createtag "identity" -attrlist  \
	  [list category user type client name Coccinella]]]
	foreach var $vars {
	    lappend subtags [wrapper::createtag "feature" -attrlist [list var $var]]
	}	
    } elseif {[string equal $node "$coccixmlns(caps)#$prefs(fullVers)"]} {
	
	# Return entity capabilities [JEP 0115]. Version number.
	# ???
	set subtags {}
    } elseif {[string equal $node "$coccixmlns(caps)#ftrans"]} {

	# Return entity capabilities [JEP 0115]. File transfer.
	# ???
	set subtags {}
    } else {
	set subtags {}
    }
    set attr [list xmlns $xmlns(info)]
    set xmllist [wrapper::createtag "query" -subtags $subtags -attrlist $attr]
    eval {$jstate(jlib) send_iq "result" $xmllist -to $from} $opts
}

proc ::Jabber::Disco::ParseGetItems {from subiq args} {
    variable xmlns
    upvar ::Jabber::jstate jstate    
    
    array set argsArr $args
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }
    set attr [list xmlns $xmlns(items)]
    set xmllist [wrapper::createtag "query" -attrlist $attr]
    eval {$jstate(jlib) send_iq "result" $xmllist -to $from} $opts
}

# UI parts .....................................................................
    
# Jabber::Disco::Build --
#
#       Makes mega widget to show the services available for the $server.
#
# Arguments:
#       w           frame window with everything.
#       
# Results:
#       w

proc ::Jabber::Disco::Build {w} {
    global  this prefs
    
    variable wtree
    variable wsearrows
    variable wtop
    variable btaddserv
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Jabber::Disco::Build"
    
    # The frame of class Disco.
    frame $w -borderwidth 0 -relief flat -class Disco
    set wbrowser $w
    
    set frbot [frame $w.frbot -bd 0]
    set wsearrows $frbot.arr        
    pack [::chasearrows::chasearrows $wsearrows -size 16] \
      -side left -padx 5 -pady 0
    pack $frbot -side bottom -fill x -padx 8 -pady 2
    
    set wbox $w.box
    pack [frame $wbox -border 1 -relief sunken]   \
      -side top -fill both -expand 1 -padx 4 -pady 4
    set wtree $wbox.tree
    set wxsc $wbox.xsc
    set wysc $wbox.ysc
    scrollbar $wxsc -orient horizontal -command [list $wtree xview]
    scrollbar $wysc -orient vertical -command [list $wtree yview]
    ::tree::tree $wtree -width 180 -height 100 -silent 1 -scrollwidth 400 \
      -xscrollcommand [list ::UI::ScrollSet $wxsc \
      [list grid $wxsc -row 1 -column 0 -sticky ew]]  \
      -yscrollcommand [list ::UI::ScrollSet $wysc \
      [list grid $wysc -row 0 -column 1 -sticky ns]]  \
      -selectcommand [namespace current]::SelectCmd    \
      -closecommand [namespace current]::CloseTreeCmd  \
      -opencommand [namespace current]::OpenTreeCmd
    
    if {[string match "mac*" $this(platform)]} {
	$wtree configure -buttonpresscommand [namespace current]::Popup \
	  -eventlist [list [list <Control-Button-1> [namespace current]::Popup] \
	  [list <Button-2> [namespace current]::Popup]]
    } else {
	$wtree configure -rightclickcommand [namespace current]::Popup
    }
    grid $wtree -row 0 -column 0 -sticky news
    grid $wysc -row 0 -column 1 -sticky ns
    grid $wxsc -row 1 -column 0 -sticky ew
    grid columnconfigure $wbox 0 -weight 1
    grid rowconfigure $wbox 0 -weight 1
	
    # All tree content is set from browse callback from the browse object.
    
    return $w
}
    
# Jabber::Disco::RegisterPopupEntry --
# 
#       Components or plugins can add their own menu entries here.

proc ::Jabber::Disco::RegisterPopupEntry {menuSpec} {
    variable popMenuDefs
    
    # Keeps track of all registered menu entries.
    variable regPopMenuSpec
    
    # Index of last separator.
    set ind [lindex [lsearch -all $popMenuDefs(disco,def) "separator"] end]
    if {![info exists regPopMenuSpec]} {
	
	# Add separator if this is the first addon entry.
	incr ind 3
	set popMenuDefs(disco,def) [linsert $popMenuDefs(disco,def)  \
	  $ind {separator} {} {}]
	set regPopMenuSpec {}
	set ind [lindex [lsearch -all $popMenuDefs(disco,def) "separator"] end]
    }
    
    # Add new entry just before the last separator
    set v $popMenuDefs(disco,def)
    set popMenuDefs(disco,def) [concat [lrange $v 0 [expr $ind-1]] $menuSpec \
      [lrange $v $ind end]]
    set regPopMenuSpec [concat $regPopMenuSpec $menuSpec]
}

# Jabber::Disco::Popup --
#
#       Handle popup menu in disco dialog.
#       
# Arguments:
#       w           widget that issued the command: tree or text
#       v           for the tree widget it is the item path, 
#                   for text the jidhash.
#       
# Results:
#       popup menu displayed

proc ::Jabber::Disco::Popup {w v x y} {
    global  wDlgs this
    
    variable popMenuDefs
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Jabber::Disco::Popup w=$w, v='$v', x=$x, y=$y"

    set typeClicked ""
    
    set item [lindex $v end]
    set jid  [lindex $item 0]
    set node [lindex $item 1]
    set categoryList [$jstate(disco) types $item]
    set categoryType [lindex $categoryList 0]
    ::Debug 4 "\t categoryType=$categoryType"

    jlib::splitjidex $jid username host res
    
    if {$username != ""} {
	set typeClicked user
	if {[$jstate(disco) isroom $jid]} {
	    set typeClicked room
	}
    } elseif {[string match -nocase "conference/*" $categoryType]} {
	set typeClicked conference
    } elseif {[string match -nocase "user/*" $categoryType]} {
	set typeClicked user
    } elseif {$jid != ""} {
	set typeClicked jid
    }
    if {$jid == ""} {
	set typeClicked ""	
    }
    set X [expr [winfo rootx $w] + $x]
    set Y [expr [winfo rooty $w] + $y]

    ::Debug 2 "\t jid=$jid, typeClicked=$typeClicked"
    
    # Make the appropriate menu.
    set m $jstate(wpopup,disco)
    set i 0
    catch {destroy $m}
    menu $m -tearoff 0
    
    foreach {item type cmd} $popMenuDefs(disco,def) {
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
	    
	    # Substitute the jid arguments.
	    set cmd [subst -nocommands $cmd]
	    set locname [mc $item]
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
	
	switch -- $type {
	    user {
		if {[string equal $typeClicked "user"]} {
		    set state normal
		}
	    }
	    room {
		if {[string equal $typeClicked "room"]} {
		    set state normal
		}
	    }
	    jid {
		switch -- $typeClicked {
		    jid - user - conference {
			set state normal
		    }
		}
	    } 
	    search - register {
		if {[$jstate(disco) hasfeature "jabber:iq:${type}" $jid]} {
		    set state normal
		}
	    }
	    conference {
		switch -- $typeClicked {
		    conference {
			set state normal
		    }
		}
	    }
	    wb {
		switch -- $typeClicked {
		    room {
			set state normal
		    }
		}
	    }
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

proc ::Jabber::Disco::SelectCmd {w v} {
    
}

# Jabber::Disco::OpenTreeCmd --
#
#       Callback when open service item in tree.
#       It disco a subelement of the server jid, typically
#       jud.jabber.org, aim.jabber.org etc.
#
# Arguments:
#       w           tree widget
#       v           tree item path (jidList: {jabber.org jud.jabber.org} etc.)
#       
# Results:
#       none.

proc ::Jabber::Disco::OpenTreeCmd {w v} {   
    variable wtree
    variable tstate
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::Disco::OpenTreeCmd v=$v"

    if {[llength $v]} {
	set item [lindex $v end]
	set jid  [lindex $item 0]
	set node [lindex $item 1]
	
	# If we have not yet discoed this jid, do it now!
	# We should have a method to tell if children have been added to tree!!!
	if {![$jstate(disco) isdiscoed items $item]} {
	    set tstate(run,$jid) 1
	    ::Jabber::Disco::ControlArrows 1
	    
	    # Discover services available.
	    ::Jabber::Disco::GetItems $jid
	} elseif {[llength [$wtree children $v]] == 0} {
	    
	    # An item may have been discoed but not from here.
	    set children [$jstate(disco) children $item]
	    foreach c $children {
		::Jabber::Disco::AddToTree [concat $v [list $c]]
	    }
	}
	
	# Else it's already in the tree; do nothin.
    }    
}

proc ::Jabber::Disco::CloseTreeCmd {w v} {   
    variable tstate
    
    ::Debug 2 "::Jabber::Disco::CloseTreeCmd v=$v"
    set jid [lindex $v end]
    if {[info exists tstate(run,$jid)]} {
	unset tstate(run,$jid)
	::Jabber::Disco::ControlArrows -1
    }
}

# Jabber::Disco::AddToTree --
#
#       Fills tree with content. Calls itself recursively.
#
# Arguments:
#       v:

proc ::Jabber::Disco::AddToTree {v} {    
    variable wtree    
    variable treeuid
    variable categoryShowDir
    upvar ::Jabber::jstate jstate
 
    # We disco servers jid 'items+info', and disco its childrens 'info'.    
    ::Debug 4 "::Jabber::Disco::AddToTree v='$v'"

    set item [lindex $v end]
    set jid  [lindex $item 0]
    set node [lindex $item 1]
    set icon ""
    
    # Ad-hoc way to figure out if dir or not. Use the category attribute.
    # <identity category='server' type='im' name='ejabberd'/>
    if {[llength $v] == 1} {
	set isdir 1
    } else {
	set isdir [::Jabber::Disco::IsDirCategory $jid]
    }
    
    # Display text string. Room participants with their nicknames.
    jlib::splitjid $jid jid2 res
    if {[$jstate(disco) isroom $jid2] && [string length $res]} {
	set name [$jstate(jlib) service nick $jid]
	set isdir 0
	set icon [::Jabber::Roster::GetPresenceIcon $jid "available"]
    } else {
	set name [$jstate(disco) name $item]
	if {$name == ""} {
	    set name $jid
	}
    }
    
    # Make the first two levels, server and its children bold, rest normal style.
    set style normal
    if {[llength $v] <= 2} {
	set style bold
    }
    set isopen 0
    if {[llength $v] == 1} {
	set isopen 1
    }
        
    # Do not create if exists which preserves -open.
    if {![$wtree isitem $v]} {
	set treectag item[incr treeuid]
	$wtree newitem $v -text $name -tags $item -style $style -dir $isdir \
	  -image $icon -open $isopen -canvastags $treectag
	
	# Balloon.
	::Jabber::Disco::MakeBalloonHelp $item $treectag
    }

    # Add all child elements as well.
    set childs [$jstate(disco) children $item]
    foreach citem $childs {
	set cv [concat $v [list $citem]]
	::Jabber::Disco::AddToTree $cv
     }	    
}

proc ::Jabber::Disco::MakeBalloonHelp {item treectag} {
    variable wtree    
    upvar ::Jabber::jstate jstate
    
    set jid  [lindex $item 0]
    set node [lindex $item 1]
    set jidtxt $jid
    if {[string length $jid] > 30} {
	set jidtxt "[string range $jid 0 28]..."
    }
    set msg "jid: $jidtxt"
    if {$node != ""} {
	append msg "\nnode: $node"
    }
    set types [$jstate(disco) types $jid]
    append msg "\ntype: $types"
    ::balloonhelp::balloonfortree $wtree $treectag $msg
}

proc ::Jabber::Disco::Refresh {jid} {    
    variable wtree
    variable tstate
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::Disco::Refresh jid=$jid"
	
    # Clear internal state of the disco object for this jid.
    $jstate(disco) reset $jid
    
    # Remove all children of this jid from disco tree.
    foreach v [$wtree find withtag $jid] {
	$wtree delitem $v -childsonly 1
    }
    
    # Disco once more, let callback manage rest.
    set tstate(run,$jid) 1
    ::Jabber::Disco::ControlArrows 1
    ::Jabber::Disco::GetInfo  $jid
    ::Jabber::Disco::GetItems $jid
}

proc ::Jabber::Disco::Clear { } {    
    upvar ::Jabber::jstate jstate
    
    $jstate(disco) reset
}

proc ::Jabber::Disco::ControlArrows {step} {    
    variable wsearrows
    variable arrowRefCount
    
    if {![winfo exists $wsearrows]} {
	return
    }
    if {$step == 1} {
	incr arrowRefCount
	if {$arrowRefCount == 1} {
	    $wsearrows start
	}
    } elseif {$step == -1} {
	incr arrowRefCount -1
	if {$arrowRefCount <= 0} {
	    set arrowRefCount 0
	    $wsearrows stop
	}
    } elseif {$step == 0} {
	set arrowRefCount 0
	$wsearrows stop
    }
}

# Jabber::Disco::PresenceHook --
# 
#       Check if there is a room participant that changes its presence.

proc ::Jabber::Disco::PresenceHook {jid presence args} {
    variable wtree    
    upvar ::Jabber::jstate jstate
    
    ::Debug 4 "::Jabber::Disco::PresenceHook $jid, $presence"
     
    jlib::splitjid $jid jid2 res
    array set argsArr $args
    set res ""
    if {[info exists argsArr(-resource)]} {
	set res $argsArr(-resource)
    }
    set jid3 $jid2/$res
    eval {TryIdentifyCoccinella $jid3 $presence} $args

    if {![info exists wtree] || ![winfo exists $wtree]} {
	return
    }
    if {[$jstate(jlib) service isroom $jid2]} {
	set presList [$jstate(roster) getpresence $jid2 -resource $res]
	array set presArr $presList
	set icon [eval {
	    ::Jabber::Roster::GetPresenceIcon $jid3 $presArr(-type)
	} $presList]
	set v [concat [$jstate(disco) parents $jid3] $jid3]
	if {[$wtree isitem $v]} {
	    $wtree itemconfigure $v -image $icon
	}
    }
}

proc ::Jabber::Disco::TryIdentifyCoccinella {jid3 presence args} {
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::coccixmlns coccixmlns
    
    if {[string equal $presence "available"]} {
	set coccielem  \
	  [$jstate(roster) getextras $jid3 $coccixmlns(servers)]
	if {$coccielem == {}} {
	    if {![::Jabber::Roster::IsTransportHeuristics $jid3]} {
		if {![$jstate(disco) isdiscoed items $jid3]} {
		    eval {AutoDisco $jid3 $presence} $args
		}
	    }
	}
    }	
}

proc ::Jabber::Disco::AutoDisco {jid presence args} {
    upvar ::Jabber::jstate jstate
    
    # Disco only potential Coccinella (all jabber) clients.
    jlib::splitjidex $jid node host x
    set type [lindex [$jstate(disco) types $host] 0]
    
    ::Debug 4 "::Jabber::Disco::AutoDisco jid=$jid, type=$type"

    # We may not yet have discoed this (empty).
    if {($type == "") || ($type == "service/jabber")} {		
	$jstate(disco) send_get info $jid [namespace current]::AutoDiscoCmd
    }
}

proc ::Jabber::Disco::AutoDiscoCmd {disconame type from subiq args} {
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::coccixmlns coccixmlns    
    
    ::Debug 4 "::Jabber::Disco::AutoDiscoCmd type=$type, from=$from"
    
    switch -- $type {
	error {
	    ::Jabber::AddErrorLog $from "Failed disco: $subiq"
	}
	result - ok {
	    if {[$jstate(disco) hasfeature $coccixmlns(whiteboard) $from] || \
	      [$jstate(disco) hasfeature $coccixmlns(coccinella) $from]} {
		::Jabber::Roster::SetCoccinella $from
	    }
	}
    }
}

proc ::Jabber::Disco::InfoCmd {jid} {
    upvar ::Jabber::jstate jstate

    ::Debug 4 "::Jabber::Disco::InfoCmd jid=$jid"
    
    if {![$jstate(disco) isdiscoed info $jid]} {
	set xmllist [$jstate(disco) get info $jid xml]
	::Jabber::Disco::InfoResultCB result $jid $xmllist
    } else {
	$jstate(disco) send_get info $jid [namespace current]::InfoCmdCB
    }
}

proc ::Jabber::Disco::InfoCmdCB {disconame type jid subiq args} {
    
    ::Debug 4 "::Jabber::Disco::InfoCmdCB type=$type, jid=$jid"
    
    switch -- $type {
	error {

	}
	result - ok {
	    eval {[namespace current]::InfoResultCB $type $jid $subiq} $args
	}
    }
}

proc ::Jabber::Disco::InfoResultCB {type jid subiq args} {
    global  this
    
    variable dlguid
    upvar ::Jabber::nsToText nsToText
    upvar ::Jabber::jstate jstate

    set w .jdinfo[incr dlguid]
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w "Disco Info: $jid"
    set fontS [option get . fontSmall {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 12 -ipady 4
    set wtext $w.frall.t
    set iconInfo [::Theme::GetImage info]
    label $w.frall.l -text "Description of services provided by $jid" \
      -justify left -image $iconInfo -compound left
    text $wtext -wrap word -width 60 -bg gray80 \
      -tabs {180} -spacing1 3 -spacing3 2 -bd 0

    pack $w.frall.l $wtext -side top -anchor w -padx 10 -pady 1
    
    $wtext tag configure head -background gray70 -lmargin1 6
    $wtext tag configure feature -lmargin1 6
    $wtext insert end "Feature\tXML namespace\n" head
    
    set features [$jstate(disco) features $jid]
    
    set tfont [$wtext cget -font]
    set maxw 0
    foreach ns $features {
	if {[info exists nsToText($ns)]} {
	    set twidth [font measure $tfont $nsToText($ns)]
	    if {$twidth > $maxw} {
		set maxw $twidth
	    }
	}
    }
    $wtext configure -tabs [expr $maxw + 20]
    
    set n 1
    foreach ns $features {
	incr n
	if {[info exists nsToText($ns)]} {
	    $wtext insert end "$nsToText($ns)" feature
	}
	$wtext insert end "\t$ns"
	$wtext insert end \n
    }
    if {$n == 1} {
	$wtext insert end "The component did not return any services"
	incr n
    }
    $wtext configure -height $n

    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btadd -text [mc Close] \
      -command [list destroy $w]]  \
      -side right -padx 5 -pady 4
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 2
	
    wm resizable $w 0 0	
}

if {0} {
    proc cb {args} {puts "cb: $args"}
    $::Jabber::jstate(disco) send_get info marilu@jabber.dk/coccinella cb
}

#-------------------------------------------------------------------------------
