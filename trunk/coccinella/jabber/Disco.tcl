#  Disco.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the Disco application part.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: Disco.tcl,v 1.55 2005-02-14 13:48:37 matben Exp $

package provide Disco 1.0

namespace eval ::Disco:: {

    ::hooks::register initHook           ::Disco::InitHook
    ::hooks::register jabberInitHook     ::Disco::NewJlibHook
    ::hooks::register loginHook          ::Disco::LoginHook
    ::hooks::register logoutHook         ::Disco::LogoutHook
    ::hooks::register presenceHook       ::Disco::PresenceHook

    # Standard widgets and standard options.
    option add *Disco.borderWidth           0               50
    option add *Disco.relief                flat            50
    option add *Disco.pad.padX              4               50
    option add *Disco.pad.padY              4               50
    option add *Disco*box.borderWidth       1               50
    option add *Disco*box.relief            sunken          50
    option add *Disco.stat.f.padX           8               50
    option add *Disco.stat.f.padY           2               50

    # Specials.
    option add *Disco.waveImage             wave            widgetDefault

    # Used for discoing ourselves using a node hierarchy.
    variable debugNodes 1
    
    # If number children smaller than this do disco#info.
    variable discoInfoLimit 12
    
    # Common xml namespaces.
    variable xmlns
    array set xmlns {
	disco           http://jabber.org/protocol/disco 
	items           http://jabber.org/protocol/disco#items 
	info            http://jabber.org/protocol/disco#info
    }
    
    # Disco catagories from Jabber :: Registrar determines if dir or not.
    variable branchCategory
    array set branchCategory {
	auth                  0
	automation            1
	client                1
	collaboration         1
	component             1
	conference            1
	directory             1
	gateway               0
	headline              0
	proxy                 0
	pubsub                1
	server                1
	services              1
	store                 1
    }
    
    # Template for the browse popup menu.
    variable popMenuDefs

    # List the features of that each menu entry can handle:
    #   conference: groupchat service, not room
    #   room:       groupchat room
    #   register:   registration support
    #   search:     search support
    #   user:       user that can be communicated with
    #   wb:         whiteboarding
    #   jid:        generic type
    #   "":         not specific
    
    # This does not work if nodes. The limitation is in the protocol.

    set popMenuDefs(disco,def) {
	mMessage       user         {::NewMsg::Build -to $jid}
	mChat          user         {::Chat::StartThread $jid}
	mWhiteboard    {wb room}    {::Jabber::WB::NewWhiteboardTo $jid}
	mEnterRoom     room         {
	    ::GroupChat::EnterOrCreate enter -roomjid $jid -autoget 1
	}
	mCreateRoom    conference   {::GroupChat::EnterOrCreate create \
	  -server $jid}
	separator      {}           {}
	mInfo          jid          {::Disco::InfoCmd $jid $node}
	mLastLogin/Activity jid     {::Jabber::GetLast $jid}
	mLocalTime     jid          {::Jabber::GetTime $jid}
	mvCard         jid          {::VCard::Fetch other $jid}
	mVersion       jid          {::Jabber::GetVersion $jid}
	separator      {}           {}
	mSearch        search       {
	    ::Search::Build -server $jid -autoget 1
	}
	mRegister      register     {
	    ::GenRegister::NewDlg -server $jid -autoget 1
	}
	mUnregister    register     {::Register::Remove $jid}
	separator      {}           {}
	mRefresh       jid          {::Disco::Refresh $jid}
	mAddServer     {}           {::Disco::AddServerDlg}
    }

    variable dlguid 0

    # Use a unique canvas tag in the tree widget for each jid put there.
    # This is needed for the balloons that need a real canvas tag, and that
    # we can't use jid's for this since they may contain special chars (!)!
    variable treeuid 0
}

proc ::Disco::InitHook { } {
    
    
    # We could add more icons for other categories here!
    variable typeIcon
    array set typeIcon [list                                    \
	gateway/aim           [::Rosticons::Get aim/online]     \
	gateway/icq           [::Rosticons::Get icq/online]     \
	gateway/msn           [::Rosticons::Get msn/online]     \
	gateway/yahoo         [::Rosticons::Get yahoo/online]   \
	gateway/x-gadugadu    [::Rosticons::Get gadugadu/online]\
	]
}

proc ::Disco::NewJlibHook {jlibName} {
    variable xmlns
    upvar ::Jabber::jstate jstate
	    
    set jstate(disco) [disco::new $jlibName -command ::Disco::Command]

    ::Jabber::AddClientXmlns [list $xmlns(disco)]
}

proc ::Disco::LoginHook { } {
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jserver jserver
    
    # Get the services for all our servers on the list. Depends on our settings:
    # If disco fails must use "browse" or "agents" as a fallback.
    #
    # We disco servers jid 'items+info', and disco its childrens 'info'.
    if {[string equal $jprefs(serviceMethod) "disco"]} {
	DiscoServer $jserver(this)
    }
}

proc ::Disco::LogoutHook { } {
    
    if {[lsearch [::Jabber::UI::Pages] "Disco"] >= 0} {
	#SetUIWhen "disconnect"
    }
    Clear
}

proc ::Disco::HaveTree { } {    
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jstate jstate
    
    if {[info exists jstate(disco)]} {
	if {[$jstate(disco) isdiscoed items $jserver(this)]} {
	    return 1
	}
    }    
    return 0
}

proc ::Disco::DiscoServer {server} {
    
    GetItems $server
    GetInfo  $server
}

# Disco::GetInfo, GetItems --
#
#       Discover the services available for the $jid.
#
# Arguments:
#       jid         The jid to discover.
#       
# Results:
#       callback scheduled.

proc ::Disco::GetInfo {jid {node ""}} {    
    upvar ::Jabber::jstate jstate
        
    # Discover info for this entity.
    set opts {}
    if {$node != ""} {
	lappend opts -node $node
    }
    eval {$jstate(disco) send_get info $jid [namespace current]::InfoCB} $opts
}

proc ::Disco::GetItems {jid {node ""}} {    
    upvar ::Jabber::jstate jstate
    
    # Discover items for this entity.
    set opts {}
    if {$node != ""} {
	lappend opts -node $node
    }
    eval {$jstate(disco) send_get items $jid [namespace current]::ItemsCB} $opts
}

# Disco::Command --
# 
#       Registered callback for incoming (async) get requests from other
#       entities.

proc ::Disco::Command {disconame discotype from subiq args} {
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Disco::Command discotype=$discotype, from=$from"

    if {[string equal $discotype "info"]} {
	eval {ParseGetInfo $from $subiq} $args
    } elseif {[string equal $discotype "items"]} {
	eval {ParseGetItems $from $subiq} $args
    }
        
    # Tell jlib's iq-handler that we handled the event.
    return 1
}

proc ::Disco::ItemsCB {disconame type from subiq args} {
    variable tstate
    variable wwave
    variable discoInfoLimit
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Disco::ItemsCB type=$type, from=$from"
    
    set from [jlib::jidmap $from]
    
    if {[string equal $type "error"]} {
	
	# As a fallback we use the agents/browse method instead.
	if {[jlib::jidequal $from $jserver(this)]} {
	    
	    switch -- $jprefs(serviceMethod) {
		disco {
		    ::Browse::GetAll
		}
		browse {
		    ::Agents::GetAll
		}
	    }
	}
	::Jabber::AddErrorLog $from "Failed disco $from"
	AddServerErrorCheck $from
	catch {$wwave animate -1}
    } else {
	
	# It is at this stage we are confident that a Disco page is needed.
	if {[jlib::jidequal $from $jserver(this)]} {
	    ::Jabber::UI::NewPage "Disco"
	}
	unset -nocomplain tstate(run,$from)
	$wwave animate -1
	
	# Add to tree:
	#       v = {item item ...}  with item = jid|node
	# These nodes are only identical to the nodes we have just obtained
	# if it is the first node level of this jid.
	set nodes [$jstate(disco) nodes $from]
	if {$nodes == {}} {
	    set parents [$jstate(disco) parents $from]
	    set v [concat $parents [list $from]]
	} else {
	    
	    # Need to look at any children to get any parent node.
	    set child [lindex [wrapper::getchildren $subiq] 0]
	    set node [wrapper::getattribute $child node]
	    set pnode [$jstate(disco) parentnode $from $node]
	    set plist [$jstate(disco) parentitemslist $from $node]
	    set v $plist
	    if {0} {
		::Debug 4 "\t child=$child"
		::Debug 4 "\t nodes=$nodes"
		::Debug 4 "\t node=$node"
		::Debug 4 "\t pnode=$pnode"
		::Debug 4 "\t plist=$plist"
		::Debug 4 "\t v=$v"
	    }
	}
	
	# We add the jid+node corresponding to the subiq element.
	AddToTree $v
	
	# Get info for the login servers children.
	if {$nodes == {}} {
	    set childs [$jstate(disco) children $from]
	    foreach cjid $childs {
		
		# We disco servers jid 'items+info', and disco its childrens 'info'.
		# Perhaps we should discover depending on items category?
		if {[llength $v] == 1} {
		    GetInfo $cjid
		} elseif {[llength $childs] < $discoInfoLimit} {
		    GetInfo $cjid
		}
	    }
	} else {
	    set cnodes [$jstate(disco) nodes $from $pnode]
	    if {[llength $cnodes] < $discoInfoLimit} {
		foreach nd $cnodes {
		    GetInfo $from $nd
		}
	    }
	}
	if {[jlib::jidequal $from $jserver(this)]} {
	    AutoDiscoServers
	}
    }
    
    eval {::hooks::run discoItemsHook $type $from $subiq} $args
}

proc ::Disco::InfoCB {disconame type from subiq args} {
    variable wtree
    variable typeIcon
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Disco::InfoCB type=$type, from=$from"
    
    set from [jlib::jidmap $from]
    set node [wrapper::getattribute $subiq node]
    
    if {[string equal $type "error"]} {
	::Jabber::AddErrorLog $from $subiq
	AddServerErrorCheck $from
    } else {
	
	# The info contains the name attribute (optional) which may
	# need to be set since we get items before name.
	# 
	# BUT the items element may also have a name attribute???
	if {![info exists wtree] || ![winfo exists $wtree]} {
	    return
	}
	set name [$jstate(disco) name $from $node]
	
	# Icon.
	set cattype [lindex [$jstate(disco) types $from $node] 0]
	set icon  ""
	if {[info exists typeIcon($cattype)]} {
	    set icon $typeIcon($cattype)
	}
	
	# Find the 'v' using from jid and any node.
	set v [$jstate(disco) getflatlist $from $node]
	if {[$wtree isitem $v]} {
	    if {$name != ""} {
		$wtree itemconfigure $v -text $name
	    }
	    if {$icon != ""} {
		$wtree itemconfigure $v -image $icon
	    }
	    set treectag [$wtree itemconfigure $v -canvastags]
	    MakeBalloonHelp $from $node $treectag
	}
	SetDirItemUsingCategory $from $node
	
	# Use specific (discoInfoGatewayIcqHook, discoInfoServerImHook,...) 
	# and general (discoInfoHook) hooks.
	set ct [split $cattype /]
	set hookName [string totitle [lindex $ct 0]][string totitle [lindex $ct 1]]
	
	eval {::hooks::run discoInfo${hookName}Hook $type $from $subiq} $args
	eval {::hooks::run discoInfoHook $type $from $subiq} $args
    }
}

proc ::Disco::SetDirItemUsingCategory {jid {node ""}} {
    variable wtree
    upvar ::Jabber::jstate jstate
    
    #puts "::Disco::SetDirItemUsingCategory jid=$jid, node=$node"
    
    if {[IsBranchCategory $jid $node]} {
	set v [$jstate(disco) getflatlist $jid $node]
	#puts "\t v=$v isdir"
	$wtree itemconfigure $v -dir 1 -sortcommand {lsort -dictionary}
    }
}

proc ::Disco::IsBranchCategory {jid {node ""}} {
    
    set isdir 0
    if {$node == ""} {
	if {[IsJidBranchCategory $jid]} {
	    set isdir 1
	}
    } else {
	if {[IsBranchNode $jid $node]} {
	    set isdir 1
	}
    }
    return $isdir
}

proc ::Disco::IsJidBranchCategory {jid} {
    variable branchCategory
    upvar ::Jabber::jstate jstate
        
    # Ad-hoc way to figure out if dir or not. Use the category attribute.
    set isdir 0
    set types [$jstate(disco) types $jid]
    foreach type $types {
	set category [lindex [split $type /] 0]
	if {[info exists branchCategory($category)] && \
	  $branchCategory($category)} {
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

proc ::Disco::IsBranchNode {jid node} {
    upvar ::Jabber::jstate jstate
    
    set isdir 0
    if {[$jstate(disco) iscategorytype hierarchy/branch $jid $node]} {
	set isdir 1
    }
    return $isdir
}
	    
# Disco::ParseGetInfo --
#
#       Respond to an incoming discovery get info query.
#       Some of this is described in [JEP 0115].
#
# Arguments:
#       
# Results:
#       none

proc ::Disco::ParseGetInfo {from subiq args} {
    global  prefs
    variable xmlns
    variable debugNodes
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::coccixmlns coccixmlns
    upvar ::Jabber::xmppxmlns xmppxmlns
    
    ::Debug 2 "::Disco::ParseGetInfo: from=$from args='$args'"
    
    array set argsArr $args
    set ishandled 1
    set type "result"
    set found 0
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }
    set node [wrapper::getattribute $subiq node]
    
    # Every entity MUST have at least one identity, and every entity MUST 
    # support at least the 'http://jabber.org/protocol/disco#info' feature; 
    # however, an entity is not required to return a result...

    if {$node == ""} {
	    
	# No node. Adding private namespaces.
	set vars {}
	foreach ns [::Jabber::GetClientXmlnsList] {
	    lappend vars $ns
	}
	set subtags [list [wrapper::createtag "identity" -attrlist  \
	  [list category client type pc name Coccinella]]]
	lappend subtags [wrapper::createtag "feature" \
	  -attrlist [list var $xmppxmlns(disco,info)]]
	foreach var $vars {
	    lappend subtags [wrapper::createtag "feature" \
	      -attrlist [list var $var]]
	}	
	set found 1
    } elseif {[string equal $node "$coccixmlns(caps)#$prefs(fullVers)"]} {
	
	# Return version number.
	set subtags [list [wrapper::createtag "identity" -attrlist  \
	  [list category client type pc name Coccinella]]]
	lappend subtags [wrapper::createtag "feature" \
	  -attrlist [list var $xmppxmlns(disco,info)]]
	# version number ???
	lappend subtags [wrapper::createtag "feature" \
	  -attrlist [list var "jabber:iq:version"]]
	set found 1
    } elseif {[string equal $node "$coccixmlns(caps)#ftrans"]} {

	# Return entity capabilities [JEP 0115]. File transfer.
	set subtags [list [wrapper::createtag "identity" -attrlist  \
	  [list category client type pc name Coccinella]]]
	lappend subtags [wrapper::createtag "feature" \
	  -attrlist [list var $xmppxmlns(disco,info)]]
	lappend subtags [wrapper::createtag "feature" \
	  -attrlist [list var $coccixmlns(servers)]]
	lappend subtags [wrapper::createtag "feature" \
	  -attrlist [list var jabber:iq:oob]]
	set found 1
   } else {
    
	# Find any matching exts.
	set exts [::Jabber::GetCapsExtKeyList]
	foreach ext $exts {
	    if {[string equal $node "$coccixmlns(caps)#$ext"]} {
		set found 1
		break
	    }
	}
	if {$found} {
	    set subtags [list [wrapper::createtag "identity" -attrlist  \
	      [list category client type pc name Coccinella]]]
	    lappend subtags [wrapper::createtag "feature" \
	      -attrlist [list var $xmppxmlns(disco,info)]]
	    lappend subtags [wrapper::createtag "feature" \
		  -attrlist [list var "$coccixmlns(caps)#$ext"]]
	}
    }
    
    # If still no hit see if node matches...
    if {!$found && $debugNodes} {
	if {$node == "A"} {
	    set subtags [list [wrapper::createtag "identity" -attrlist  \
	      [list category hierarchy type leaf]]]
	    lappend subtags [wrapper::createtag "feature" \
	      -attrlist [list var $xmppxmlns(disco,info)]]
	    set found 1
	} elseif {$node == "B"} {
	    set subtags [list [wrapper::createtag "identity" -attrlist  \
	      [list category hierarchy type branch]]]
	    lappend subtags [wrapper::createtag "feature" \
	      -attrlist [list var $xmppxmlns(disco,info)]]
	    set found 1
	}
    }
    if {!$found} {
	
	# This entity is not found.
	set subtags [list [wrapper::createtag "error" \
	  -attrlist {code 404 type cancel} \
	  -subtags [list [wrapper::createtag "item-not-found" \
	  -attrlist [list xmlns urn:ietf:xml:params:ns:xmpp-stanzas]]]]]
	set type "error"
    }
    if {$node == ""} {
	set attr [list xmlns $xmlns(info)]
    } else {
	set attr [list xmlns $xmlns(info) node $node]
    }
    set xmllist [wrapper::createtag "query" -subtags $subtags -attrlist $attr]
    eval {$jstate(jlib) send_iq $type [list $xmllist] -to $from} $opts
    
    return $ishandled
}
	    
# Disco::ParseGetItems --
#
#       Respond to an incoming discovery get items query.
#
# Arguments:
#       
# Results:
#       none

proc ::Disco::ParseGetItems {from subiq args} {
    variable xmlns
    variable debugNodes
    upvar ::Jabber::jstate jstate    
    
    ::Debug 2 "::Disco::ParseGetItems from=$from args='$args'"

    array set argsArr $args
    set ishandled 0
    set found 0
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }
    set node [wrapper::getattribute $subiq node]

    if {$debugNodes && ($node == "")} {
	set type "result"
	set found 1
	if {[info exists argsArr(-to)]} {
	    set myjid $argsArr(-to)
	} else {
	    set myjid [::Jabber::GetMyJid]
	}
	set subtags {}
	
	# This is just some dummy nodes used for debugging.
	lappend subtags [wrapper::createtag "item" \
	  -attrlist [list jid $myjid node A name "Name A"]]
	lappend subtags [wrapper::createtag "item" \
	  -attrlist [list jid $myjid node B name "Empty branch"]]
	set attr [list xmlns $xmlns(items)]
	if {$node != ""} {
	    lappend attr node $node
	}
	set xmllist [wrapper::createtag "query" -attrlist $attr -subtags $subtags]
    }
    if {!$found} {
	set type "error"
	set subtags [list [wrapper::createtag "error" \
	  -attrlist {code 404 type cancel} \
	  -subtags [list [wrapper::createtag "item-not-found" \
	  -attrlist {xmlns urn:ietf:xml:params:ns:xmpp-stanzas}]]]]
	
	set attr [list xmlns $xmlns(items)]
	set xmllist [wrapper::createtag "query" -attrlist $attr -subtags $subtags]
    }
    eval {$jstate(jlib) send_iq $type [list $xmllist] -to $from} $opts
    
    return $ishandled
}

# UI parts .....................................................................
    
# Disco::Build --
#
#       Makes mega widget to show the services available for the $server.
#
# Arguments:
#       w           frame window with everything.
#       
# Results:
#       w

proc ::Disco::Build {w} {
    global  this prefs
    
    variable wtree
    variable wtop
    variable wwave
    variable btaddserv
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Disco::Build"
    
    set fontS [option get . fontSmall {}]

    # The frame of class Disco. D = -bd 0 -relief flat
    frame $w -class Disco

    # Keep empty frame for any padding.
    frame $w.tpad
    pack  $w.tpad -side top -fill x

    # D = -padx 0 -pady 0
    frame $w.stat
    frame $w.stat.f
    pack  $w.stat   -side bottom -fill x
    pack  $w.stat.f -side bottom -fill x
    set wwave $w.stat.f.wa
    set waveImage [::Theme::GetImage [option get $w waveImage {}]]  
    ::wavelabel::wavelabel $wwave -type image -image $waveImage
    pack $wwave -side bottom -fill x
    
    # Tree frame with scrollbars.
    set wdisco  $w
    set wpad    $w.pad
    set wbox    $w.pad.box
    set wxsc    $wbox.xsc
    set wysc    $wbox.ysc
    set wtree   $wbox.tree
    
    # D = -padx 4 -pady 4
    frame $wpad
    pack  $wpad -side top -fill both -expand 1

    # D = -border 1 -relief sunken
    frame $wbox
    pack  $wbox -side top -fill both -expand 1
    scrollbar $wxsc -command [list $wtree xview] -orient horizontal
    scrollbar $wysc -command [list $wtree yview] -orient vertical
    ::tree::tree $wtree -width 180 -height 100 -silent 1 -scrollwidth 400 \
      -xscrollcommand [list ::UI::ScrollSet $wxsc \
      [list grid $wxsc -row 1 -column 0 -sticky ew]]  \
      -yscrollcommand [list ::UI::ScrollSet $wysc \
      [list grid $wysc -row 0 -column 1 -sticky ns]]  \
      -selectcommand [namespace current]::SelectCmd    \
      -closecommand [namespace current]::CloseTreeCmd  \
      -opencommand [namespace current]::OpenTreeCmd   \
      -eventlist [list [list <<ButtonPopup>> [namespace current]::Popup]]

    if {[string match "mac*" $this(platform)]} {
	$wtree configure -buttonpresscommand [namespace current]::Popup
    }
    grid $wtree -row 0 -column 0 -sticky news
    grid $wysc  -row 0 -column 1 -sticky ns
    grid $wxsc  -row 1 -column 0 -sticky ew
    grid columnconfigure $wbox 0 -weight 1
    grid rowconfigure    $wbox 0 -weight 1
	
    # All tree content is set from browse callback from the browse object.
    
    return $w
}
    
# Disco::RegisterPopupEntry --
# 
#       Components or plugins can add their own menu entries here.

proc ::Disco::RegisterPopupEntry {menuSpec} {
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

# Disco::Popup --
#
#       Handle popup menu in disco dialog.
#       
# Arguments:
#       w           widget that issued the command: tree or text
#       v           tree item path {item item ...}  with item = jid|node
#       
# Results:
#       popup menu displayed

proc ::Disco::Popup {w v x y} {
    global  wDlgs this
    
    variable popMenuDefs
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Disco::Popup w=$w, v='$v', x=$x, y=$y"
        
    set items [$jstate(disco) splititemlist $v]
    set jid  [lindex $items 0 end]
    set node [lindex $items 1 0]

    # An item can have more than one type, for instance,
    # msn.domain can have: {gateway/msn conference/text}
    set categoryList [string tolower [$jstate(disco) types $jid $node]]
    set categoryType [lindex $categoryList 0]
    
    ::Debug 4 "\t jid=$jid, node=$node, categoryList=$categoryList"

    jlib::splitjidex $jid username host res
       
    # List the features of that each menu entry can handle:
    #   conference: groupchat service, not room
    #   room:       groupchat room
    #   register:   registration support
    #   search:     search support
    #   user:       user that can be communicated with
    #   wb:         whiteboarding
    #   jid:        generic type
    #   "":         not specific

    # Make a list of all the features of the clicked item.
    # This is then matched against each menu entries type to set its state.

    set clicked {}
    if {[lsearch -glob $categoryList "conference/*"] >= 0} {
	lappend clicked conference
    }
    if {[lsearch -glob $categoryList "user/*"] >= 0} {
	lappend clicked user
    }
    if {$username != ""} {
	if {[$jstate(disco) isroom $jid]} {
	    lappend clicked room
	} else {
	    lappend clicked user
	}
    }
    foreach name {search register} {
	if {[$jstate(disco) hasfeature "jabber:iq:${name}" $jid]} {
	    lappend clicked $name
	}
    }
    if {[::Roster::IsCoccinella $jid]} {
	lappend clicked wb
    }
    # 'jid' is the generic type.
    if {$jid != ""} {
	lappend clicked jid
    }
    
    ::Debug 2 "\t clicked=$clicked"
        
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
	
	# State of menu entry. 
	# We use the 'type' and 'clicked' lists to set the state.
	if {[listintersectnonempty $type $clicked]} {
	    set state normal
	} elseif {$type == ""} {
	    set state normal
	} else {
	    set state disabled
	}
	if {[string equal $state "normal"]} {
	    $m entryconfigure $locname -state normal
	}
    }   
    
    # This one is needed on the mac so the menu is built before it is posted.
    update idletasks
    
    # Post popup menu.	
    set X [expr [winfo rootx $w] + $x]
    set Y [expr [winfo rooty $w] + $y]
    tk_popup $m [expr int($X) - 10] [expr int($Y) - 10]   
    
    # Mac bug... (else can't post menu while already posted if toplevel...)
    if {[string equal "macintosh" $this(platform)]} {
	catch {destroy $m}
	update
    }
}

proc ::Disco::SelectCmd {w v} {
    
}

# Disco::OpenTreeCmd --
#
#       Callback when open service item in tree.
#       It disco a subelement of the server jid, typically
#       jud.jabber.org, aim.jabber.org etc.
#
# Arguments:
#       w           tree widget
#       v           tree item path {item item ...}  with item = jid|node
#       
# Results:
#       none.

proc ::Disco::OpenTreeCmd {w v} {   
    variable wtree
    variable wwave
    variable tstate
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Disco::OpenTreeCmd v=$v"

    if {[llength $v]} {
	set items [$jstate(disco) splititemlist $v]
	set jid  [lindex $items 0 end]
	set node [lindex $items 1 0]

	# If we have not yet discoed this jid, do it now!
	# We should have a method to tell if children have been added to tree!!!
	if {![$jstate(disco) isdiscoed items $jid $node]} {
	    set tstate(run,$jid) 1
	    $wwave animate 1
	    
	    # Discover services available.
	    GetItems $jid $node
	} elseif {[llength [$wtree children $v]] == 0} {
	    
	    # An item may have been discoed but not from here.
	    set children [$jstate(disco) children $jid]
	    foreach c $children {
		AddToTree [concat $v [list $c]]
	    }
	    set nodes [$jstate(disco) nodes $jid $node]
	    foreach c $nodes {
		AddToTree [concat $v [list $c]]
	    }
	}
	
	# Else it's already in the tree; do nothin.
    }    
}

proc ::Disco::CloseTreeCmd {w v} {
    variable wwave
    variable tstate
    
    ::Debug 2 "::Disco::CloseTreeCmd v=$v"
    set item [lindex $v end]
    if {[info exists tstate(run,$item)]} {
	unset tstate(run,$item)
	$wwave animate -1
    }
}

# Disco::AddToTree --
#
#       Fills tree with content. Calls itself recursively.
#
# Arguments:
#       v           tree item path {item item ...}  with item = jid|node
#

proc ::Disco::AddToTree {v} {    
    variable wtree    
    variable treeuid
    upvar ::Jabber::jstate jstate
 
    # We disco servers jid 'items+info', and disco its childrens 'info'.    
    ::Debug 4 "::Disco::AddToTree v='$v'"

    set items [$jstate(disco) splititemlist $v]
    set jid  [lindex $items 0 end]
    set node [lindex $items 1 0]
    set icon ""
    
    # Ad-hoc way to figure out if dir or not. Use the category attribute.
    # <identity category='server' type='im' name='ejabberd'/>
    if {[llength $v] == 1} {
	set isdir 1
    } else {
	set isdir [IsBranchCategory $jid $node]
	#puts "\t IsBranchCategory=$isdir"
    }
    
    # Display text string. Room participants with their nicknames.
    jlib::splitjid $jid jid2 res
    if {[$jstate(disco) isroom $jid2] && [string length $res]} {
	set name [$jstate(jlib) service nick $jid]
	set isdir 0
	set icon [::Roster::GetPresenceIconFromJid $jid]
    } else {
	set name [$jstate(disco) name $jid $node]
	if {$name == ""} {
	    if {$node == ""} {
		set name $jid
	    } else {
		set name $node
	    }
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
	if {$node == ""} {
	    set tags [list jid $jid]
	} else {
	    set tags [list node $jid $node]
	}
	set opts [list -text $name -tags $tags -style $style -dir $isdir \
	  -image $icon -open $isopen -canvastags $treectag]
	if {$isdir && ([llength $v] >= 2)} {
	    lappend opts -sortcommand {lsort -dictionary}
	}
	eval {$wtree newitem $v} $opts
	
	# Balloon.
	MakeBalloonHelp $jid $node $treectag
    }

    # Add all child or node elements as well.
    # These are mutually exclusive.
    set childs [$jstate(disco) children $jid]
    if {[llength $childs]} {
	::Debug 4 "\t childs=$childs"
	foreach citem $childs {
	    set cv [concat $v [list $citem]]
	    AddToTree $cv
	}	    
    } else {
	if {0} {
	    ::Debug 4 "\t items=$items"
	    ::Debug 4 "\t nodes=[$jstate(disco) nodes $jid $node]"
	}
	foreach cnode [$jstate(disco) nodes $jid $node] {
	    set cv [concat $v [list $cnode]]
	    AddToTree $cv
	}
    }
}

proc ::Disco::MakeBalloonHelp {jid node treectag} {
    variable wtree    
    upvar ::Jabber::jstate jstate
    
    set jidtxt $jid
    if {[string length $jid] > 30} {
	set jidtxt "[string range $jid 0 28]..."
    }
    set msg "jid: $jidtxt"
    if {$node != ""} {
	append msg "\nnode: $node"
    }
    set types [$jstate(disco) types $jid]
    if {$types != {}} {
	append msg "\ntype: $types"
    }
    ::balloonhelp::balloonfortree $wtree $treectag $msg
}

proc ::Disco::Refresh {jid} {    
    variable wtree
    variable wwave
    variable tstate
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Disco::Refresh jid=$jid"
	
    # Clear internal state of the disco object for this jid.
    $jstate(disco) reset $jid
    
    # Remove all children of this jid from disco tree.
    foreach v [$wtree find withtag $jid] {
	$wtree delitem $v -childsonly 1
    }
    
    # Disco once more, let callback manage rest.
    set tstate(run,$jid) 1
    $wwave animate 1
    GetInfo  $jid
    GetItems $jid
}

proc ::Disco::Clear { } {    
    upvar ::Jabber::jstate jstate
    
    $jstate(disco) reset
}

# Disco::PresenceHook --
# 
#       Check if there is a room participant that changes its presence.

proc ::Disco::PresenceHook {jid presence args} {
    variable wtree    
    upvar ::Jabber::jstate jstate
    
    ::Debug 4 "::Disco::PresenceHook $jid, $presence"
     
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
	    ::Roster::GetPresenceIcon $jid3 $presArr(-type)
	} $presList]
	set v [concat [$jstate(disco) parents $jid3] $jid3]
	if {[$wtree isitem $v]} {
	    $wtree itemconfigure $v -image $icon
	}
    }
}

# We should do this using the 'node' attribute of the caps element instead.
# This is made in ::Roster::IsCoccinella instead.

proc ::Disco::TryIdentifyCoccinella {jid3 presence args} {
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::coccixmlns coccixmlns
    
    # Trigger only if unavailable before.
    if {[string equal $presence "available"]} {
	set coccielem  \
	  [$jstate(roster) getextras $jid3 $coccixmlns(servers)]
	if {$coccielem == {}} {
	    if {![::Roster::IsTransportHeuristics $jid3]} {
		if {![$jstate(disco) isdiscoed items $jid3] && \
		  ![$jstate(roster) wasavailable $jid3]} {
		    eval {AutoDisco $jid3 $presence} $args
		}
	    }
	}
    }	
}

# In the future we should use disco to get ip address instead of the
# 'coccinella' element sent with presence. Therefore it is placed here.

proc ::Disco::GetCoccinellaIP {jid3} {
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::coccixmlns coccixmlns
    
    set ip ""
    set cociElem [$jstate(roster) getextras $jid3 $coccixmlns(servers)]
    if {$cociElem != {}} {
	set ipElements [wrapper::getchildswithtag $cociElem ip]
	set ip [wrapper::getcdata [lindex $ipElements 0]]
    }
    return $ip
}

proc ::Disco::AutoDisco {jid presence args} {
    upvar ::Jabber::jstate jstate
    
    # Disco only potential Coccinella (all jabber) clients.
    jlib::splitjidex $jid node host x
    set type [lindex [$jstate(disco) types $host] 0]
    
    ::Debug 4 "::Disco::AutoDisco jid=$jid, type=$type"

    # We may not yet have discoed this (empty).
    if {($type == "") || ($type == "service/jabber")} {		
	$jstate(disco) send_get info $jid [namespace current]::AutoDiscoCmd
    }
}

proc ::Disco::AutoDiscoCmd {disconame type from subiq args} {
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::coccixmlns coccixmlns    
    
    ::Debug 4 "::Disco::AutoDiscoCmd type=$type, from=$from"
    
    switch -- $type {
	error {
	    ::Jabber::AddErrorLog $from "Failed disco: $subiq"
	}
	result - ok {
	    if {[$jstate(disco) hasfeature $coccixmlns(whiteboard) $from] || \
	      [$jstate(disco) hasfeature $coccixmlns(coccinella) $from]} {
		::Roster::SetCoccinella $from
	    }
	}
    }
}

proc ::Disco::InfoCmd {jid {node ""}} {
    upvar ::Jabber::jstate jstate

    ::Debug 4 "::Disco::InfoCmd jid=$jid"
    
    if {![$jstate(disco) isdiscoed info $jid $node]} {
	set xmllist [$jstate(disco) get info xml $jid $node]
	InfoResultCB result $jid $xmllist
    } else {
	set opts {}
	if {$node != ""} {
	    lappend opts -node $node
	}
	eval {
	    $jstate(disco) send_get info $jid [namespace current]::InfoCmdCB
	} $opts
    }
}

proc ::Disco::InfoCmdCB {disconame type jid subiq args} {
    
    ::Debug 4 "::Disco::InfoCmdCB type=$type, jid=$jid"
    
    switch -- $type {
	error {

	}
	result - ok {
	    eval {[namespace current]::InfoResultCB $type $jid $subiq} $args
	}
    }
}

proc ::Disco::InfoResultCB {type jid subiq args} {
    global  this
    
    variable dlguid
    upvar ::Jabber::nsToText nsToText
    upvar ::Jabber::jstate jstate

    set node [wrapper::getattribute $subiq node]
    if {$node == ""} {
	set txt $jid
    } else {
	set txt "$jid, node $node"
    }

    set w .jdinfo[incr dlguid]
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w "Disco Info: $txt"
    set fontS [option get . fontSmall {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 12 -ipady 4
    set wtext $w.frall.t
    set iconInfo [::Theme::GetImage info]
    label $w.frall.l -text "Description of services provided by $txt" \
      -justify left -image $iconInfo -compound left
    text $wtext -wrap word -width 60 -bg gray80 \
      -tabs {180} -spacing1 3 -spacing3 2 -bd 0

    pack $w.frall.l $wtext -side top -anchor w -padx 10 -pady 1
    
    $wtext tag configure head -background gray70 -lmargin1 6
    $wtext tag configure feature -lmargin1 6
    $wtext insert end "Feature\tXML namespace\n" head
    
    set features [$jstate(disco) features $jid $node]
    
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


proc ::Disco::AutoDiscoServers { } {
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jserver jserver
    
    foreach server $jprefs(disco,autoServers) {
	if {![jlib::jidequal $server $jserver(this)]} {
	    DiscoServer $server
	}
    }
}

proc ::Disco::AddServerDlg { } {
    global  wDlgs
    variable addservervar ""
    variable permdiscovar 0
    upvar ::Jabber::jprefs jprefs
    
    set w $wDlgs(jdisaddserv)
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w [mc {Add Server}]
    set fontS [option get . fontSmall {}]
    
    set width 260
    
    # Global frame.
    set wall $w.frall
    frame $wall -borderwidth 1 -relief raised
    pack  $wall -fill both -expand 1
    
    message $wall.msg -text [mc jadisaddserv] \
      -anchor w -justify left -width $width
    pack $wall.msg -side top -padx 8 -pady 6
    
    set wfr $wall.fr
    labelframe $wfr -text [mc Add]
    pack  $wfr -side top -fill x -padx 10 -pady 2
    label $wfr.l -text "[mc Server]:"
    entry $wfr.e -textvariable [namespace current]::addservervar
    checkbutton $wfr.ch -anchor w -text " [mc {Add permanently}]" \
      -variable [namespace current]::permdiscovar

    grid $wfr.l $wfr.e  -pady 2
    grid x      $wfr.ch -pady 2 -sticky ew
    grid $wfr.l -sticky e
    grid $wfr.e -sticky ew
    
    set wfr2 $wall.fr2
    labelframe $wfr2 -text [mc Remove] -padx 4
    pack  $wfr2 -side top -fill x -padx 10 -pady 2
    label  $wfr2.l -wraplength [expr $width-10] -anchor w -justify left\
      -text [mc jadisrmall]
    button $wfr2.b -text [mc Remove] -font $fontS \
      -command [namespace current]::AddServerNone
    pack $wfr2.l -side top
    pack $wfr2.b -side right -padx 6 -pady 2
    
    if {$jprefs(disco,autoServers) == {}} {
	$wfr2.b configure -state disabled
    }
    set frbot [frame $wall.frbot -borderwidth 0]
    pack [button $frbot.btabtokdd -text [mc Add] \
      -command [list [namespace current]::AddServerDo $w]]  \
      -side right -padx 5 -pady 4
    pack [button $frbot.btcancel -text [mc Close] \
      -command [list destroy $w]]  \
      -side right -padx 5 -pady 4
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 2
	
    wm resizable $w 0 0
    
    # Grab and focus.
    set oldFocus [focus]
    focus $wall.fr.e
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {grab release $w}
    catch {focus $oldFocus}
}

proc ::Disco::AddServerNone { } {
    upvar ::Jabber::jprefs jprefs
    
    set jprefs(disco,autoServers) {}
}

proc ::Disco::AddServerDo {w} {
    upvar ::Jabber::jprefs jprefs
    variable addservervar
    variable permdiscovar
    
    destroy $w
    if {$addservervar != ""} {
	DiscoServer $addservervar
	if {$permdiscovar} {
	    set jprefs(disco,autoServers) [lsort -unique \
	      [concat $addservervar [list $jprefs(disco,autoServers)]]]
	}
    }
}

# Disco::AddServerErrorCheck --
# 
#       If we get an error from a server on the 'autoServers' list we
#       shall remove it from the list.

proc ::Disco::AddServerErrorCheck {from} {
    upvar ::Jabber::jprefs jprefs
    
    lprune jprefs(disco,autoServers) $from
}

if {0} {
    proc cb {args} {puts "cb: $args"}
    $::Jabber::jstate(disco) send_get info marilu@jabber.dk/coccinella cb
}

#-------------------------------------------------------------------------------
