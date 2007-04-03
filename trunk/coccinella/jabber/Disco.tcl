#  Disco.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the Disco application part.
#      
#  Copyright (c) 2004-2006  Mats Bengtsson
#  
# $Id: Disco.tcl,v 1.104 2007-04-03 14:11:13 matben Exp $

package require jlib::disco
package require ITree

package provide Disco 1.0

namespace eval ::Disco:: {

    ::hooks::register initHook             ::Disco::InitHook
    ::hooks::register jabberInitHook       ::Disco::NewJlibHook
    ::hooks::register loginHook            ::Disco::LoginHook     20
    ::hooks::register logoutHook           ::Disco::LogoutHook
    ::hooks::register presenceHook         ::Disco::PresenceHook
    ::hooks::register uiMainToggleMinimal  ::Disco::ToggleMinimalHook
    ::hooks::register menuPostCommand      ::Disco::MainMenuPostHook
    
    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook        ::Disco::InitPrefsHook

    # Standard widgets and standard options.
    option add *Disco.borderWidth           0               50
    option add *Disco.relief                flat            50
    option add *Disco*box.borderWidth       1               50
    option add *Disco*box.relief            sunken          50
    option add *Disco.padding               4               50

    # Specials.
    option add *Disco.backgroundImage       cociexec        widgetDefault
    option add *Disco.waveImage             wave            widgetDefault
    option add *Disco.fontStyleMixed        0               widgetDefault    
    option add *Disco.minimalPadding        {0}             widgetDefault
    
    # Used for discoing ourselves using a node hierarchy.
    variable debugNodes 0
    
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
	headline              1
	proxy                 0
	pubsub                1
	server                1
	services              1
	store                 1
    }

    # Keeps track of all registered menu entries.
    variable regPopMenuDef {}
    variable regPopMenuType {}

    variable dlguid 0

    # Use a unique canvas tag in the tree widget for each jid put there.
    # This is needed for the balloons that need a real canvas tag, and that
    # we can't use jid's for this since they may contain special chars (!)!
    variable treeuid 0
    
    variable wtab   -
    variable wtree  -
    variable wdisco -
}

proc ::Disco::InitPrefsHook {} {
    upvar ::Jabber::jprefs jprefs
    
    # The disco background image is partly controlled by option database.
    # @@@ The bgImagePath is unused. We should make a more flexible and
    #     generic way to change image similar to desktop images;
    #     A new dialog where you can choose from a selection of images
    #     all contained inside the prefs dir.
    #     If a new image is added, it is copied there. The default image
    #     shall always be there. Possibility to select: "Don't show image".
    set jprefs(disco,useBgImage)     1
    set jprefs(disco,bgImagePath)    ""

    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(disco,useBgImage)   jprefs_disco_useBgImage   $jprefs(disco,useBgImage)]  \
      [list ::Jabber::jprefs(disco,bgImagePath)  jprefs_disco_bgImagePath  $jprefs(disco,bgImagePath)] \
      ]
}

proc ::Disco::InitHook { } {
    upvar ::Jabber::jprefs jprefs

    set jprefs(disco,tmpServers) {} 
    InitMenus
}

proc ::Disco::InitMenus {} {
    
    # Template for the disco popup menu.
    variable popMenuDefs

    set mDefs {
	{command    mMessage       {::NewMsg::Build -to $jid} }
	{command    mChat          {::Chat::StartThread $jid} }
	{command    mEnterRoom     {
	    ::GroupChat::EnterOrCreate enter -roomjid $jid -autoget 1
	} }
	{command    mCreateRoom    {
	    ::GroupChat::EnterOrCreate create -server $jid
	} }
	{separator}
	{command    mInfo          {::UserInfo::Get $jid $node} }
	{separator}
	{command    mSearch        {
	    ::Search::Build -server $jid -autoget 1
	} }
	{command    mRegister      {
	    ::GenRegister::NewDlg -server $jid -autoget 1
	} }
	{command    mUnregister    {::Register::Remove $jid} }
	{separator}
	{cascade    mShow          {
	    {check  mBackgroundImage  {::Disco::SetBackgroundImage} {
		-variable ::Jabber::jprefs(disco,useBgImage)
	    } }
	} }
	{command    mRefresh       {::Disco::Refresh $vstruct} }
	{command    mAddServer     {::Disco::AddServerDlg}     }
    }
    if {[::Jabber::HaveWhiteboard]} {
	set mDefs [linsert $mDefs 2 \
	  {command    mWhiteboard    {::JWB::NewWhiteboardTo $jid} }]

    }
    set popMenuDefs(disco,def) $mDefs

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

    set popMenuDefs(disco,type) {
	{mMessage       {user}          }
	{mChat          {user}          }
	{mWhiteboard    {wb room}       }
	{mEnterRoom     {room}          }
	{mCreateRoom    {conference}    }
	{mInfo          {jid}           }
	{mSearch        {search}        }
	{mRegister      {register}      }
	{mUnregister    {register}      }
	{mShow          {normal}     {
	    {mBackgroundImage  {normal} }
	}}
	{mRefresh       {jid}           }
	{mAddServer     {}              }
    }
}

proc ::Disco::NewJlibHook {jlibName} {
	    
    $jlibName disco registerhandler ::Disco::Handler
}

# Disco::LoginHook --
# 
#       This must be before most other login hooks, at least other doing disco.

proc ::Disco::LoginHook { } {
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    # We disco servers jid 'items+info', and disco its childrens 'info'.
    DiscoServer $jstate(server)
}

proc ::Disco::LogoutHook { } {
    variable wtab
    
    if {[winfo exists $wtab]} {
	set wnb [::JUI::GetNotebook]
	$wnb forget $wtab
	destroy $wtab
    }
    Clear
}

proc ::Disco::HaveTree { } {    
    upvar ::Jabber::jstate jstate
    
    if {[$jstate(jlib) disco isdiscoed items $jstate(server)]} {
	return 1
    } else {
	return 0
    }
}

# Disco::DiscoServer --
# 
#       Disco for both items and info for a server.
#
# Arguments:
#       jid         The jid to discover.
#       args:   -command
#       
# Results:
#       callback scheduled.

proc ::Disco::DiscoServer {server args} {
    
    # It should be enough to get one report.
    eval {GetItems $server} $args
    GetInfo  $server
}

# Disco::GetInfo, GetItems --
#
#       Discover the services available for the $jid.
#
# Arguments:
#       jid         The jid to discover.
#       args:   -node
#               -command
#       
# Results:
#       callback scheduled.

proc ::Disco::GetInfo {jid args} {    
    upvar ::Jabber::jstate jstate
        
    # Discover info for this entity.
    array set arr {
	-node       ""
	-command    ""
    }
    array set arr $args
    set opts {}
    if {$arr(-node) ne ""} {
	lappend opts -node $arr(-node)
    }
    set cmdCB [list [namespace current]::InfoCB $arr(-command)]
    eval {$jstate(jlib) disco send_get info $jid $cmdCB} $opts
}

proc ::Disco::GetItems {jid args} {    
    upvar ::Jabber::jstate jstate
    
    # Discover items for this entity.
    array set arr {
	-node       ""
	-command    ""
    }
    array set arr $args
    set opts {}
    if {$arr(-node) ne ""} {
	lappend opts -node $arr(-node)
    }
    set cmdCB [list [namespace current]::ItemsCB $arr(-command)]
    eval {$jstate(jlib) disco send_get items $jid $cmdCB} $opts
}

proc ::Disco::InfoCB {cmd jlibname type from queryE args} {
    variable wtree
    variable wtab
    upvar ::Jabber::jstate jstate
     
    set from [jlib::jidmap $from]
    set node [wrapper::getattribute $queryE node]
   
    ::Debug 2 "::Disco::InfoCB type=$type, from=$from, node=$node"
    
    if {[string equal $type "error"]} {
	::Jabber::AddErrorLog $from "([lindex $queryE 0]) [lindex $queryE 1]"
	AddServerErrorCheck $from
    } else {
	
	# The info contains the name attribute (optional) which may
	# need to be set since we get items before name.
	# 
	# BUT the items element may also have a name attribute???
	if {![winfo exists $wtab]} {
	    #NewPage
	}
	
	# Google Talk responds to info but not to items.
	if {![winfo exists $wtree]} {
	    return
	}
	
	# There is nothing that stops a JID+node combination from appearing
	# in more than one place of the disco tree. Find them all.
	
	set vlist [::ITree::FindEndItems $wtree [list $from $node]]
	set cattypes [$jstate(jlib) disco types $from $node]

	foreach vstruct $vlist {
	    set icon [::Servicons::GetFromTypeList $cattypes]
	    set name [$jstate(jlib) disco name $from $node]
	    set opts {}	    
	    if {$name ne ""} {
		lappend opts -text $name
	    }
	    if {$icon ne ""} {
		lappend opts -image $icon
	    }
	    if {$node ne ""} {
		lappend opts -button [IsBranchNode $from $node]
	    }
	    if {$opts ne {}} {
		eval {::ITree::ItemConfigure $wtree $vstruct} $opts
	    }
	    MakeBalloonHelp $vstruct
	    SetDirItemUsingCategory $vstruct
	}
	
	# Use specific (discoInfoGatewayIcqHook, discoInfoServerImHook,...) 
	# and general (discoInfoHook) hooks.
	foreach c $cattypes {
	    set ct [split $c /]
	    set hname [string totitle [lindex $ct 0]][string totitle [lindex $ct 1]]   
	    eval {::hooks::run discoInfo${hname}Hook $type $from $queryE} $args
	}
	eval {::hooks::run discoInfoHook $type $from $queryE} $args
    }
    if {$cmd ne ""} {
	eval $cmd [list $type $from $queryE] $args
    }
}

proc ::Disco::ItemsCB {cmd jlibname type from queryE args} {
    variable tstate
    variable wwave
    variable wtree
    variable wtab
    variable discoInfoLimit
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Disco::ItemsCB type=$type, from=$from"
    
    set from [jlib::jidmap $from]
    
    if {[string equal $type "error"]} {
	
	# We have no fallback.
	::Jabber::AddErrorLog $from "Failed disco $from"
	AddServerErrorCheck $from
	catch {$wwave animate -1}
    } else {
	
	# It is at this stage we are confident that a Disco page is needed.
	if {![winfo exists $wtab]} {
	    NewPage
	}
	$wwave animate -1
	
	# Add to tree:
	#       vstruct = {item item ...}  with item = {jid node}
	# These nodes are only identical to the nodes we have just obtained
	# if it is the first node level of this jid!
	# Note that jids and nodes can be mixed!
	set pnode   [wrapper::getattribute $queryE "node"]
	set vlist [::ITree::FindEndItems $wtree [list $from $pnode]]
	if {$vlist eq {}} {
	    
	    # The item is a root item since it does not yet exists.
	    set vlist [list [list [list $from $pnode]]]
	}
	
	# We add the jid+node corresponding to the queryE element.
	foreach vstruct $vlist {
	    unset -nocomplain tstate(run,$vstruct)
	    TreeItem $vstruct
	}
	
	# Get info:
	# We disco servers jid 'items+info', and disco its childrens 'info'.
	# Perhaps we should discover depending on items category?
	set centlist [$jstate(jlib) disco childs $from $pnode]
	set clen [llength $centlist]
	foreach cent $centlist {
	    set cjid  [lindex $cent 0]
	    set cnode [lindex $cent 1]
	    if {[llength $vstruct] == 1} {
		GetInfo $cjid -node $cnode
	    } elseif {$clen < $discoInfoLimit} {
		GetInfo $cjid -node $cnode
	    } elseif {($cnode ne "") && ($clen < $discoInfoLimit)} {
		GetInfo $cjid -node $cnode
	    }
	}
	if {[jlib::jidequal $from $jstate(server)] && ($pnode eq "")} {
	    AutoDiscoServers
	}
    }
    
    eval {::hooks::run discoItemsHook $type $from $queryE} $args

    if {$cmd ne {}} {
	eval $cmd [list $type $from $queryE] $args
    }
}

# Disco::Handler --
# 
#       Registered callback for incoming (async) get requests from other
#       entities.

proc ::Disco::Handler {jlibname discotype from queryE args} {
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Disco::Handler discotype=$discotype, from=$from"

    if {[string equal $discotype "info"]} {
	eval {ParseGetInfo $from $queryE} $args
    } elseif {[string equal $discotype "items"]} {
	eval {ParseGetItems $from $queryE} $args
    }
	
    # Tell jlib's iq-handler that we handled the event.
    return 1
}

proc ::Disco::SetDirItemUsingCategory {vstruct} {
    variable wtree
    upvar ::Jabber::jstate jstate
	
    set jid  [lindex $vstruct end 0]
    set node [lindex $vstruct end 1]

    if {[IsBranchCategory $jid $node]} {
	::ITree::ItemConfigure $wtree $vstruct -button 1
    }
}

proc ::Disco::IsBranchCategory {jid {node ""}} {
    
    set isdir 0
    if {$node eq ""} {
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
    set types [$jstate(jlib) disco types $jid]
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
	set isdir [$jstate(jlib) disco isroom $jid]
    }
    return $isdir
}

proc ::Disco::IsBranchNode {jid node} {
    upvar ::Jabber::jstate jstate
    
    if {0} {
	set isdir 0
	if {[$jstate(jlib) disco iscategorytype hierarchy/branch $jid $node]} {
	    set isdir 1
	}
    } else {
	set isdir 1
	if {[$jstate(jlib) disco iscategorytype hierarchy/leaf $jid $node]} {
	    set isdir 0
	}
    }
    return $isdir
}
	    
# Disco::ParseGetInfo --
#
#       Respond to an incoming discovery get info query.
#       Some of this is described in [XEP 0115].
#
# Arguments:
#       
# Results:
#       none

proc ::Disco::ParseGetInfo {from queryE args} {
    global  prefs this
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
    set node [wrapper::getattribute $queryE node]
    ::Debug 4 "\t node=$node"
    
    # Every entity MUST have at least one identity, and every entity MUST 
    # support at least the 'http://jabber.org/protocol/disco#info' feature; 
    # however, an entity is not required to return a result...

    if {$node eq ""} {
	    
	# No node. Adding private namespaces.
	set vars [concat  \
	  [jlib::disco::getregisteredfeatures] [::Jabber::GetClientXmlnsList]]
	set subtags [list [wrapper::createtag "identity" -attrlist  \
	  [list category client type pc name Coccinella]]]
	lappend subtags [wrapper::createtag "feature" \
	  -attrlist [list var $xmppxmlns(disco,info)]]
	foreach var $vars {
	    lappend subtags [wrapper::createtag "feature" \
	      -attrlist [list var $var]]
	}	
	set found 1
    } elseif {[string equal $node "$coccixmlns(caps)#$this(vers,full)"]} {
	
	# Return version number.
	set subtags [list [wrapper::createtag "identity" -attrlist  \
	  [list category hierarchy type leaf name "Version"]]]
	lappend subtags [wrapper::createtag "feature" \
	  -attrlist [list var "jabber:iq:version"]]
	set found 1
   } else {
    
	# Find any matching exts.
	set exts [::Jabber::GetCapsExtKeyList]
	foreach ext $exts {
	    if {[string equal $node "$coccixmlns(caps)#$ext"]} {
		set found 1
		set subtags [::Jabber::GetCapsExtSubtags $ext]
		break
	    }
	}
    }
    
    # If still no hit see if node matches...
    if {!$found && $debugNodes} {
	if {$node eq "A"} {
	    set subtags [list [wrapper::createtag "identity" -attrlist  \
	      [list category hierarchy type leaf]]]
	    lappend subtags [wrapper::createtag "feature" \
	      -attrlist [list var $xmppxmlns(disco,info)]]
	    set found 1
	} elseif {$node eq "B"} {
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
    if {$node eq ""} {
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

proc ::Disco::ParseGetItems {from queryE args} {
    global  prefs this
    variable xmlns
    variable debugNodes
    upvar ::Jabber::jstate jstate    
    upvar ::Jabber::coccixmlns coccixmlns
    
    ::Debug 2 "::Disco::ParseGetItems from=$from args='$args'"

    array set argsArr $args
    set ishandled 0
    set found 0
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }
    set node [wrapper::getattribute $queryE node]
    
    # Support for caps (XEP-0115).
    if {$node eq ""} {
	set type "result"
	set found 1
	if {[info exists argsArr(-to)]} {
	    set myjid $argsArr(-to)
	} else {
	    set myjid [::Jabber::GetMyJid]
	}
	set subtags {}
	set cnode "$coccixmlns(caps)#$this(vers,full)"
	lappend subtags [wrapper::createtag "item" \
	  -attrlist [list jid $myjid node $cnode]]
	set exts [::Jabber::GetCapsExtKeyList]
	foreach ext $exts {
	    set cnode "$coccixmlns(caps)#$ext"
	    lappend subtags [wrapper::createtag "item" \
	      -attrlist [list jid $myjid node $cnode]]
	}
	if {$debugNodes} {
	
	    # This is just some dummy nodes used for debugging.
	    lappend subtags [wrapper::createtag "item" \
	      -attrlist [list jid $myjid node A name "Name A"]]
	    lappend subtags [wrapper::createtag "item" \
	      -attrlist [list jid $myjid node B name "Empty branch"]]
	}
	set attr [list xmlns $xmlns(items)]
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
    
#  Each item is represented by a structure 'v' or 'vstruct':
#       
#       v = {item item ...}  with item = {jid node}
#       
#  Since a tuple {jid node} is not unique; it can appear in several places
#  in the disco tree, we MUST keep the complete tree structure for an item
#  in order to uniquely identify it in the tree.

proc ::Disco::NewPage { } {
    variable wtab
    
    set wnb [::JUI::GetNotebook]
    set wtab $wnb.di
    if {![winfo exists $wtab]} {
	Build $wtab
	set im [::Theme::GetImage \
	  [option get [winfo toplevel $wnb] browser16Image {}]]
	set imd [::Theme::GetImage \
	  [option get [winfo toplevel $wnb] browser16DisImage {}]]
	set imSpec [list $im disabled $imd background $imd]
	# This seems to pick up *Disco.padding ?
	$wnb add $wtab -text [mc Disco] -image $imSpec -compound left  \
	  -sticky news -padding 0
    }
}

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
    variable wwave
    variable wdisco
    variable wbox
    variable dstyle
    upvar ::Jabber::jprefs jprefs
    
    # The frame of class Disco.
    ttk::frame $w -class Disco
    
    # Tree frame with scrollbars.
    set wdisco  $w
    set wbox    $w.box
    set wxsc    $wbox.xsc
    set wysc    $wbox.ysc
    set wtree   $wbox.tree
    set wwave   $w.wa
    set dstyle  "normal"

    # D = -padx 0 -pady 0
    set waveImage [::Theme::GetImage [option get $w waveImage {}]]  
    ::wavelabel::wavelabel $wwave -relief groove -bd 2 \
      -type image -image $waveImage
    pack $wwave -side bottom -fill x -padx 8 -pady 2
    
    # D = -border 1 -relief sunken
    frame $wbox
    pack  $wbox -side top -fill both -expand 1

    ttk::scrollbar $wxsc -command [list $wtree xview] -orient horizontal
    ttk::scrollbar $wysc -command [list $wtree yview] -orient vertical
    ::ITree::New $wtree $wxsc $wysc   \
      -selection   ::Disco::Selection     \
      -open        ::Disco::OpenTreeCmd   \
      -close       ::Disco::CloseTreeCmd  \
      -buttonpress ::Disco::Popup         \
      -buttonpopup ::Disco::Popup
    
    ::ITree::ElementLayout $wtree image -minwidth 16
    SetBackgroundImage

    grid  $wtree  -row 0 -column 0 -sticky news
    grid  $wysc   -row 0 -column 1 -sticky ns
    grid  $wxsc   -row 1 -column 0 -sticky ew
    grid columnconfigure $wbox 0 -weight 1
    grid rowconfigure    $wbox 0 -weight 1

    # Handle the prefs "Show" state.
    if {$jprefs(ui,main,show,minimal)} {
	StyleMinimal
    }
    return $w
}

proc ::Disco::ToggleMinimalHook {minimal} {
    variable wdisco
    variable dstyle
    
    if {[winfo exists $wdisco]} {
	if {$minimal && ($dstyle eq "normal")} {
	    StyleMinimal
	} elseif {!$minimal && ($dstyle eq "minimal")} {
	    StyleNormal
	}
    }
}

proc ::Disco::StyleMinimal { } {
    variable wdisco
    variable wbox
    variable wwave
    variable dstyle
    
    $wdisco configure -padding [option get $wdisco minimalPadding {}]
    $wbox configure -bd 0
    pack forget $wwave
    set dstyle "minimal"
}

proc ::Disco::StyleNormal { } {
    variable wdisco
    variable wbox
    variable wwave
    variable dstyle
    
    set padding [option get $wdisco padding {}]
    $wdisco configure -padding $padding
    set bd [option get $wbox borderWidth {}]
    $wbox configure -bd $bd
    pack $wwave -side bottom -fill x -padx 8 -pady 2
    set dstyle "normal"
}

proc ::Disco::StyleGet { } {
    variable dstyle

    return $dstyle
}

proc ::Disco::SetBackgroundImage { } {
    upvar ::Jabber::jprefs jprefs
    variable wtree
    variable wdisco
    
    if {$jprefs(disco,useBgImage)} {
	set image [::Theme::GetImage [option get $wdisco backgroundImage {}]]
    } else {
	set image ""
    }
    $wtree configure -backgroundimage $image
}

# Disco::RegisterPopupEntry --
# 
#       Components or plugins can add their own menu entries here.

proc ::Disco::RegisterPopupEntry {menuDef menuType} {
    variable regPopMenuDef
    variable regPopMenuType
    
    set regPopMenuDef  [concat $regPopMenuDef $menuDef]
    set regPopMenuType [concat $regPopMenuType $menuType]
}

proc ::Disco::UnRegisterPopupEntry {name} {
    variable regPopMenuDef
    variable regPopMenuType
    
    set idx [lsearch -glob $regPopMenuDef "* $name *"]
    if {$idx >= 0} {
	set regPopMenuDef [lreplace $regPopMenuDef $idx $idx]
    }
    set idx [lsearch -glob $regPopMenuType "$name *"]
    if {$idx >= 0} {
	set regPopMenuType [lreplace $regPopMenuType $idx $idx]
    }
}

if {0} {
    # test
    set menuDef {
	{command "Hej och HŒ" {puts skit}}
	{command "Nej och GŒ" {puts piss}}
    }
    set menuType {
	{"Hej och HŒ"  {jid}}
    }
    ::Disco::RegisterPopupEntry $menuDef $menuType
}

# Disco::Popup --
#
#       Handle popup menu in disco dialog.
#       
# Arguments:
#       w           widget that issued the command: tree or text
#       vstruct     tree item path {item item ...}  with item = {jid node}
#       
# Results:
#       popup menu displayed

proc ::Disco::Popup {w vstruct x y} {
    global  wDlgs
    variable popMenuDefs
    variable regPopMenuDef
    variable regPopMenuType
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Disco::Popup w=$w, vstruct='$vstruct'"
        
    set jid  [lindex $vstruct end 0]
    set node [lindex $vstruct end 1]

    # An item can have more than one type, for instance,
    # msn.domain can have: {gateway/msn conference/text}
    set categoryList [string tolower [$jstate(jlib) disco types $jid $node]]
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
    #   jid:        generic type, no node
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
    if {$username ne ""} {
	if {[$jstate(jlib) disco isroom $jid]} {
	    lappend clicked room
	} else {
	    lappend clicked user
	}
    }
    foreach name {search register} {
	if {[$jstate(jlib) disco hasfeature "jabber:iq:${name}" $jid]} {
	    lappend clicked $name
	}
    }
    if {[::Roster::IsCoccinella $jid]} {
	lappend clicked wb
    }
    # 'jid' is the generic type.
    if {($jid ne "") && ($node eq "")} {
	lappend clicked jid
    }
    
    ::Debug 2 "\t clicked=$clicked"
    
    # Insert any registered popup menu entries.
    set mDef  $popMenuDefs(disco,def)
    set mType $popMenuDefs(disco,type)
    if {[llength $regPopMenuDef]} {
	set idx [lindex [lsearch -glob -all $mDef {sep*}] end]
	if {$idx eq ""} {
	    set idx end
	}
	foreach line $regPopMenuDef {
	    set mDef [linsert $mDef $idx $line]
	}
	set mDef [linsert $mDef $idx {separator}]
    }
    foreach line $regPopMenuType {
	lappend mType $line
    }
    
    # Make the appropriate menu.
    set m $wDlgs(jpopupdisco)
    catch {destroy $m}
    menu $m -tearoff 0  \
      -postcommand [list ::Disco::PostMenuCmd $m $mType $clicked]
    
    ::AMenu::Build $m $mDef -varlist [list jid $jid node $node vstruct $vstruct]
    
    # This one is needed on the mac so the menu is built before it is posted.
    update idletasks
    
    # Post popup menu.	
    set X [expr [winfo rootx $w] + $x]
    set Y [expr [winfo rooty $w] + $y]
    tk_popup $m [expr int($X) - 10] [expr int($Y) - 10]   
}

proc ::Disco::PostMenuCmd {m mType clicked} {

    ::hooks::run discoPostCommandHook $m $clicked  

    foreach mspec $mType {
	lassign $mspec name type subType

	# State of menu entry. 
	# We use the 'type' and 'clicked' lists to set the state.
	if {$type eq "normal"} {
	    set state normal
	} elseif {[listintersectnonempty $type $clicked]} {
	    set state normal
	} elseif {$type eq ""} {
	    set state normal
	} else {
	    set state disabled
	}
	set midx [::AMenu::GetMenuIndex $m $name]
	if {[string equal $state "disabled"]} {
	    $m entryconfigure $midx -state disabled
	}
	if {[llength $subType]} {
	    set mt [$m entrycget $midx -menu]
	    PostMenuCmd $mt $subType $clicked
	}
    }
}

proc ::Disco::Selection {T v} {
    # empty
}

# Disco::OpenTreeCmd --
#
#       Callback when open service item in tree.
#       It disco a subelement of the server jid, typically
#       jud.jabber.org, aim.jabber.org etc.
#
# Arguments:
#       w           tree widget
#       vstruct     tree item path {item item ...}  with item = {jid node}
#       
# Results:
#       none.

proc ::Disco::OpenTreeCmd {w vstruct} {   
    variable wtree
    variable wwave
    variable tstate
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Disco::OpenTreeCmd vstruct=$vstruct"

    if {[llength $vstruct]} {
	set jid  [lindex $vstruct end 0]
	set node [lindex $vstruct end 1]

	# If we have not yet discoed this jid, do it now!
	# We should have a method to tell if children have been added to tree!!!
	if {![$jstate(jlib) disco isdiscoed items $jid $node]} {
	    set tstate(run,$vstruct) 1
	    $wwave animate 1
	    
	    # Discover services available.
	    GetItems $jid -node $node
	} elseif {[::ITree::Children $wtree $vstruct] == {}} {
	    
	    # An item may have been discoed but not from here.
	    foreach item [$jstate(jlib) disco childs $jid $node] {
		TreeItem [concat $vstruct [list $item]]
	    }
	}
	
	# Else it's already in the tree; do nothin.
    }    
}

proc ::Disco::CloseTreeCmd {w vstruct} {
    variable wwave
    variable tstate
    
    ::Debug 2 "::Disco::CloseTreeCmd vstruct=$vstruct"

    if {[info exists tstate(run,$vstruct)]} {
	unset tstate(run,$vstruct)
	$wwave animate -1
    }
}

# Disco::TreeItem --
#
#       Fills tree with content. Calls itself recursively.
#
# Arguments:
#       vstruct     {{jid node} {jid node} ...}
#

proc ::Disco::TreeItem {vstruct} {    
    variable wtree    
    variable wdisco
    variable treeuid
    upvar ::Jabber::jstate  jstate
    upvar ::Jabber::jprefs  jprefs
    
    # We disco servers jid 'items+info', and disco its childrens 'info'.    
    ::Debug 4 "::Disco::TreeItem vstruct='$vstruct'"
    
    set jid   [lindex $vstruct end 0]
    set node  [lindex $vstruct end 1]
    set pjid  [lindex $vstruct end-1 0]
    set pnode [lindex $vstruct end-1 1]
        
    # If this is a tree root element add only if a discoed server.
    if {($pjid eq "") && ($pnode eq "")} {
	set all [concat $jprefs(disco,tmpServers) $jprefs(disco,autoServers)]
	lappend all $jstate(server)
	if {[lsearch -exact $all $jid] < 0} {
	    return
	}
    }    

    set cattypes [$jstate(jlib) disco types $jid $node]
    set isconference [expr {[lsearch -glob $cattypes conference/*] < 0 ? 0 : 1}]
    
    jlib::splitjid $jid jid2 res
    set isroom [$jstate(jlib) disco isroom $jid2]
    
    # Do not create if exists which preserves -open.
    if {![::ITree::IsItem $wtree $vstruct]} {
	
	# Ad-hoc way to figure out if dir or not. Use the category attribute.
	# <identity category='server' type='im' name='ejabberd'/>
	if {[llength $vstruct] == 1} {
	    set isdir 1
	} else {
	    set isdir [IsBranchCategory $jid $node]
	}
	
	# jid that are children of node is never a dir (?)
	if {($pnode ne "") && ($jid ne $pjid)} {
	    set isdir 0
	}
	
	# Display text string. Room participants with their nicknames.
	set icon ""
	if {$isroom && [string length $res]} {
	    set name [$jstate(jlib) service nick $jid]
	    set isdir 0
	    set icon [::Roster::GetPresenceIconFromJid $jid]
	} else {
	    set name [$jstate(jlib) disco name $jid $node]
	    if {$name eq ""} {
		if {$node eq ""} {
		    set name $jid
		} else {
		    set name $node
		}
	    }
	    set icon [::Servicons::GetFromTypeList $cattypes]
	    
	    # Fallbacks:
	    if {$icon eq ""} {
		if {$isroom} {
		    set icon [::Servicons::Get conference/text]
		} elseif {$node ne ""} {
		    set xtypes [$jstate(jlib) disco types $jid]
		    set icon [::Servicons::GetFromTypeList $xtypes]
		}
	    }
	}	    
	set isopen 0
	if {[llength $vstruct] == 1} {
	    set isopen 1
	}
	set opts [list -text $name -button $isdir -image $icon -open $isopen]
	eval {::ITree::Item $wtree $vstruct} $opts
	
	# Balloon.
	MakeBalloonHelp $vstruct
    }
    
    # Add all child or node elements as well.
    # Note: jid and node childs can be mixed!
    set cstructs [$jstate(jlib) disco childs $jid $node]
        
    foreach c $cstructs {
	set cv [concat $vstruct [list $c]]
	TreeItem $cv
    }
    
    # Sort after all childrens have been added.
    # Which items should be sorted by default? 
    # So far only the rooms and participants.
    if {[llength $cstructs]} {
	if {$isconference || $isroom} {
	    ::ITree::Sort $wtree $vstruct -increasing -dictionary
	}
    }
}

proc ::Disco::MakeBalloonHelp {vstruct} {
    variable wtree    
    upvar ::Jabber::jstate jstate
    
    set jid  [lindex $vstruct end 0]
    set node [lindex $vstruct end 1]

    set jidtxt $jid
    if {[string length $jid] > 30} {
	set jidtxt "[string range $jid 0 28]..."
    }
    set msg "jid: $jidtxt"
    if {$node ne ""} {
	append msg "\nnode: $node"
    }
    set types [$jstate(jlib) disco types $jid $node]
    if {$types != {}} {
	append msg "\ntype: $types"
    }
    set item [::ITree::GetItem $wtree $vstruct]
    ::balloonhelp::treectrl $wtree $item $msg
    
    ::hooks::run discoBalloonhelp $wtree $item $jid
}

proc ::Disco::Refresh {vstruct} {    
    variable wtree
    variable wwave
    variable tstate
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Disco::Refresh vstruct=$vstruct"
	
    set jid  [lindex $vstruct end 0]
    set node [lindex $vstruct end 1]

    # Clear internal state of the disco object for this jid.
    $jstate(jlib) disco reset $jid
    
    # Remove all children of this 'vstruct' from disco tree.
    ::ITree::DeleteChildren $wtree $vstruct
	
    # Disco once more, let callback manage rest.
    set tstate(run,$vstruct) 1
    $wwave animate 1
    GetInfo  $jid -node $node
    GetItems $jid -node $node
}

proc ::Disco::Clear { } {    
    upvar ::Jabber::jstate jstate
    
    $jstate(jlib) disco reset
}

# Disco::PresenceHook --
# 
#       Check if there is a room participant that changes its presence.
#       @@@ The icon can be inconsistent if the user has been auto discoed.

proc ::Disco::PresenceHook {jid presence args} {
    variable wtree    
    upvar ::Jabber::jstate jstate
         
    jlib::splitjid $jid jid2 res
    array set argsArr $args
    set res ""
    if {[info exists argsArr(-resource)]} {
	set res $argsArr(-resource)
    }
    set jid3 $jid2/$res
    set jlib $jstate(jlib)

    if {![winfo exists $wtree]} {
	return
    }
    if {[$jlib service isroom $jid2]} {
	set vlist [::ITree::FindEndItems $wtree [list $jid3 {}]]
	if {[llength $vlist]} {
	    set icon [::Roster::GetPresenceIconFromJid $jid3]
	    foreach vstruct $vlist {
		::ITree::ItemConfigure $wtree $vstruct -image $icon
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
    set cociElem [$jstate(jlib) roster getextras $jid3 $coccixmlns(servers)]
    if {$cociElem != {}} {
	set ipElements [wrapper::getchildswithtag $cociElem ip]
	set ip [wrapper::getcdata [lindex $ipElements 0]]
    }
    return $ip
}

proc ::Disco::InfoCmd {jid {node ""}} {
    upvar ::Jabber::jstate jstate

    ::Debug 4 "::Disco::InfoCmd jid=$jid"
    
    if {![$jstate(jlib) disco isdiscoed info $jid $node]} {
	set xmllist [$jstate(jlib) disco get info xml $jid $node]
	InfoResultCB result $jid $xmllist
    } else {
	set opts {}
	if {$node ne ""} {
	    lappend opts -node $node
	}
	eval {
	    $jstate(jlib) disco send_get info $jid [namespace current]::InfoCmdCB
	} $opts
    }
}

proc ::Disco::InfoCmdCB {jlibname type jid queryE args} {
    
    ::Debug 4 "::Disco::InfoCmdCB type=$type, jid=$jid"
    
    switch -- $type {
	error {

	}
	result - ok {
	    eval {[namespace current]::InfoResultCB $type $jid $queryE} $args
	}
    }
}

proc ::Disco::InfoResultCB {type jid queryE args} {
    global  this
    
    variable dlguid
    upvar ::Jabber::nsToText nsToText
    upvar ::Jabber::jstate jstate

    set node [wrapper::getattribute $queryE node]
    if {$node eq ""} {
	set txt $jid
    } else {
	set txt "$jid, node $node"
    }

    set w .jdinfo[incr dlguid]
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w "Disco Info: $txt"
    
    set im  [::Theme::GetImage info]
    set imd [::Theme::GetImage infoDis]

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    ttk::label $w.frall.head -style Headlabel \
      -text [mc {Disco Info}] -compound left \
      -image [list $im background $imd]
    pack $w.frall.head -side top -anchor w

    ttk::separator $w.frall.s -orient horizontal
    pack $w.frall.s -side top -fill x

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    BuildInfoPage $wbox.f $jid $node
    pack $wbox.f -fill both -expand 1
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btcancel -text [mc Close] \
      -command [list destroy $w]
    pack $frbot.btcancel -side right
    pack $frbot -side top -fill x
	
    wm resizable $w 0 0	
}

proc ::Disco::BuildInfoPage {win jid {node ""}} {
    upvar ::Jabber::nsToText nsToText
    upvar ::Jabber::jstate jstate
    
    if {$node eq ""} {
	set str $jid
    } else {
	set str "$jid, node $node"
    }
    ttk::frame $win
    ttk::label $win.l -padding {0 0 0 8} \
      -text "Description of services provided by $str"
    pack $win.l -side top -anchor w

    set wtext $win.t
    text $wtext -wrap word -width 60 -bg gray80 \
      -highlightthickness 0 -tabs {180} -spacing1 3 -spacing3 2 -bd 0
    set twidth [expr 10*[font measure [$wtext cget -font] "sixmmm"] + 10]
    $win.l configure -wraplength $twidth

    pack $wtext -side top -anchor w
    
    $wtext tag configure head -background gray70 -lmargin1 6
    $wtext tag configure feature -lmargin1 6
    $wtext insert end "Feature\tXML namespace\n" head
    
    set features [$jstate(jlib) disco features $jid $node]
    
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
    $wtext configure -height $n -state disabled
    
    return $win
}

proc ::Disco::AutoDiscoServers { } {
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    # Guard against empty elements. Old bug!
    lprune jprefs(disco,autoServers) {}

    foreach server $jprefs(disco,autoServers) {
	if {![jlib::jidequal $server $jstate(server)]} {
	    DiscoServer $server
	}
    }
}

proc ::Disco::OnMenuAddServer { } {
    if {[llength [grab current]]} { return }
    if {[::JUI::GetConnectState] eq "connectfin"} {
	AddServerDlg
    }
}

# @@@ We should make this a generic way to disco any JID!

proc ::Disco::AddServerDlg { } {
    global  wDlgs
    variable addservervar ""
    variable permdiscovar 0
    upvar ::Jabber::jprefs jprefs
    
    set w $wDlgs(jdisaddserv)

    # Singleton.
    if {[winfo exists $w]} {
	raise $w
	return
    }
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w [mc {Add Server}]
    
    set width 260
    
    # Global frame.
    set wall $w.frall
    ttk::frame $wall
    pack $wall -fill both -expand 1
    
    set wbox $wall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 300 -justify left -text [mc jadisaddserv]
    pack $wbox.msg -side top -anchor w
    
    set wfr $wbox.fr
    ttk::labelframe $wfr -text [mc Add] \
      -padding [option get . notebookPageSmallPadding {}]
    pack $wfr -side top -fill x -pady 4
    ttk::label $wfr.l -text "[mc Server]:"
    ttk::entry $wfr.e -textvariable [namespace current]::addservervar
    #  -validate key -validatecommand {::Jabber::ValidateDomainStr %S}
    ttk::checkbutton $wfr.ch -style Small.TCheckbutton \
      -text [mc {Add permanently}] \
      -variable [namespace current]::permdiscovar

    grid  $wfr.l  $wfr.e   -padx 2 -pady 2
    grid  x       $wfr.ch  -pady 2 -sticky ew
    grid  $wfr.l  -sticky e
    grid  $wfr.e  -sticky ew
    
    set wfr2 $wbox.fr2
    ttk::labelframe $wfr2 -text [mc Remove] \
      -padding [option get . notebookPageSmallPadding {}]
    pack $wfr2 -side top -fill x -pady 4
    ttk::label $wfr2.l -style Small.TLabel \
      -wraplength [expr $width-10] -justify left\
      -text [mc jadisrmall]
    ttk::button $wfr2.b -style Small.TButton \
      -text [mc Remove] -command [namespace current]::AddServerNone

    pack  $wfr2.l  -side top
    pack  $wfr2.b  -side right -padx 6 -pady 2
    
    if {$jprefs(disco,autoServers) == {}} {
	$wfr2.b configure -state disabled
    }
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Add] \
      -command [list [namespace current]::AddServerDo $w]
    ttk::button $frbot.btcancel -text [mc Close] \
      -command [list destroy $w]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side top -fill x
	
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]

    focus $wfr.e
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
    if {$addservervar ne ""} {
	DiscoServer $addservervar -command ::Disco::AddServerCB
	if {$permdiscovar} {
	    lappend jprefs(disco,autoServers) $addservervar
	    set jprefs(disco,autoServers) \
	      [lsort -unique $jprefs(disco,autoServers)]
	} else {
	    lappend jprefs(disco,tmpServers) $addservervar
	    set jprefs(disco,tmpServers) \
	      [lsort -unique $jprefs(disco,tmpServers)]
	}
    }
}

proc ::Disco::AddServerCB {type from queryE args} {
    
    if {$type eq "error"} {
	ui::dialog -icon error -title [mc Error] \
	  -message "We failed discovering the server $from ." \
	  -detail [lindex $queryE 1]
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

proc ::Disco::MainMenuPostHook {type wmenu} {
    
    if {$type eq "main-jabber"} {
	set m [::UI::MenuMethod $wmenu entrycget mRegister -menu]
	$m delete 0 end
	
	if {[::JUI::GetConnectState] eq "connectfin"} {
	    set num 0
	    set server [::Jabber::JlibCmd getserver]
	    set jidL [::Jabber::JlibCmd disco getjidsforfeature "jabber:iq:register"]
	    set jidL [lsearch -all -not -inline $jidL $server]
	    foreach jid $jidL {
		set name [::Jabber::JlibCmd disco name $jid]
		$m add command -label $name  \
		  -command [list ::GenRegister::NewDlg -server $jid -autoget 1]
		incr num
	    }
	    if {$num} {
		$m add separator
	    }
	    $m add command -label JID... \
	      -command [list ::GenRegister::NewDlg -serverstate normal]
	}
	update idletasks
    }
}

#-------------------------------------------------------------------------------
