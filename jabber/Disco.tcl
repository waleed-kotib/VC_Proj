#  Disco.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the Disco application part.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: Disco.tcl,v 1.6 2004-04-19 13:58:47 matben Exp $

package provide Disco 1.0

namespace eval ::Jabber::Disco:: {

    ::hooks::add jabberInitHook     ::Jabber::Disco::NewJlibHook
    ::hooks::add loginHook          ::Jabber::Disco::LoginHook
    ::hooks::add logoutHook         ::Jabber::Disco::LogoutHook

    # Common xml namespaces.
    variable xmlns
    array set xmlns {
	disco           http://jabber.org/protocol/disco 
	items           http://jabber.org/protocol/disco#items 
	info            http://jabber.org/protocol/disco#info
    }
    
    # Template for the browse popup menu.
    variable popMenuDefs

    set popMenuDefs(disco,def) {
	mMessage       user      {::Jabber::NewMsg::Build -to $jid}
	mChat          user      {::Jabber::Chat::StartThread $jid}
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
	    ::Jabber::GenRegister::BuildRegister -server $jid -autoget 1
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
	::Jabber::Disco::GetInfo  $jserver(this)
	::Jabber::Disco::GetItems $jserver(this)
    }
}

proc ::Jabber::Disco::LogoutHook { } {
    
    if {[lsearch [::Jabber::UI::Pages] "Disco"] >= 0} {
	#::Jabber::Disco::SetUIWhen "disconnect"
	#::Jabber::Disco::Clear
    }
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


proc ::Jabber::Disco::Command {discotype from subiq args} {
    upvar ::Jabber::jstate jstate

    puts "::Jabber::Disco::Command"
    
    if {[string equal $discotype "info"]} {
	eval {::Jabber::Disco::ParseGetInfo $from $subiq} $args
    } elseif {[string equal $discotype "items"]} {
	eval {::Jabber::Disco::ParseGetItems $from $subiq} $args
    }
        
    # Tell jlib's iq-handler that we handled the event.
    return 1
}

proc ::Jabber::Disco::ItemsCB {type from subiq args} {
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jstate jstate
    
    puts "::Jabber::Disco::ItemsCB type=$type, from=$from"
    
    switch -- $type {
	error {
	    
	    # As a fallback we use the browse method instead.
	    if {[string equal $from $jserver(this)]} {
		
		# This is a bit ugly! Should have a better mechanism!!!
		# Should have another way of invoking alternatives.
		::Jabber::Browse::GetAll
	    }
	}
	ok - result {

	    # It is at this stage we are confident that a Disco page is needed.
	    if {[string equal $from $jserver(this)]} {
		::Jabber::UI::NewPage "Disco"
	    }
	    ::Jabber::Disco::ControlArrows -1
	    
	    # First add the discoed item.
	    set parents [$jstate(disco) parents $from]
	    set v [concat $parents $from]
	    ::Jabber::Disco::AddToTree $v

	    # Then all its children.
	    set childs [$jstate(disco) children $from]
	    foreach cjid $childs {
		set cv [concat $v $cjid]
		::Jabber::Disco::AddToTree $cv
		
		# We disco servers jid 'items+info', and disco its childrens 'info'.
		# 
		# Perhaps we should discover depending on items category?
		if {[string equal $from $jserver(this)]} {
		    ::Jabber::Disco::GetInfo $cjid
		}		
	    }	    
	}
    }
}

proc ::Jabber::Disco::InfoCB {type from subiq args} {
    
    puts "::Jabber::Disco::InfoCB type=$type, from=$from"
    
    # The info contains the name attribute (optional) which may
    # need to be set since we get items before name.
    # 
    # BUT the items element may also have a name attribute???
    
    
}
	    
# Jabber::Disco::ParseGetInfo --
#
#       Respond to an incoming discovery get query.
#       
# Results:
#       none

proc ::Jabber::Disco::ParseGetInfo {from subiq args} {
    variable xmlns
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::Disco::ParseGetInfo: args='$args'"
    
    array set argsArr $args
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }

    # Adding private namespaces.
    set vars {}
    foreach ns [::Jabber::GetClientXmlnsList] {
	lappend vars $ns
    }
    set subtags [list [wrapper::createtag "identity" -attrlist  \
      [list category user type client name Coccinella]]]
    foreach var $vars {
	lappend subtags [wrapper::createtag "feature" -attrlist [list var $var]]
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
    
    ::Jabber::Debug 2 "::Jabber::Disco::Build"
    
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
      -xscrollcommand [list $wxsc set]       \
      -yscrollcommand [list $wysc set]       \
      -selectcommand [namespace current]::SelectCmd   \
      -opencommand [namespace current]::OpenTreeCmd
    
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
	
    # All tree content is set from browse callback from the browse object.
    
    return $w
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

    ::Jabber::Debug 2 "::Jabber::Disco::Popup w=$w, v='$v', x=$x, y=$y"

    set typeClicked ""
    
    set jid [lindex $v end]
    set categoryList [$jstate(disco) types $jid]
    set categoryType [lindex $categoryList 0]
    puts "\t categoryType=$categoryType"

    if {[regexp {^.+@[^/]+(/.*)?$} $jid match res]} {
	set typeClicked user
	# We should call disco directly here!!!!!!
	if {[$jstate(jlib) service isroom $jid]} {
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

    ::Jabber::Debug 2 "\t jid=$jid, typeClicked=$typeClicked"
    
    # Make the appropriate menu.
    set m $jstate(wpopup,disco)
    set i 0
    catch {destroy $m}
    menu $m -tearoff 0
    
    foreach {item type cmd} $popMenuDefs(disco,def) {
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
		if {[$jstate(disco) havefeature "jabber:iq:${type}" $jid]} {
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
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Disco::OpenTreeCmd v=$v"

    if {[llength $v]} {
	set jid [lindex $v end]
	
	# If we have not yet discoed this jid, do it now!
	# We should have a method to tell if children have been added to tree!!!
	if {![$jstate(disco) isdiscoed items $jid]} {
	    ::Jabber::Disco::ControlArrows 1
	    
	    # Discover services available.
	    ::Jabber::Disco::GetItems $jid
	} elseif {[llength [$wtree children $v]] == 0} {
	    
	    # ???
	}
	
	# Else it's already in the tree; do nothin.
    }    
}

# Jabber::Disco::AddToTree --
#
#       Fills tree with content. Calls itself recursively?
#
# Arguments:
#       v:

proc ::Jabber::Disco::AddToTree {v} {    
    variable wtree    
    variable treeuid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
 
    # We disco servers jid 'items+info', and disco its childrens 'info'.
    set treectag item[incr treeuid]
    
    puts "::Jabber::Disco::AddToTree v='$v'"

    set jid [lindex $v end]
    set name [$jstate(disco) name $jid]
    if {$name == ""} {
	set name $jid
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
	$wtree newitem $v -text $name -tags $jid -style $style -dir 1  \
	  -open $isopen -canvastags $treectag
    }
    
    # Add all child elements as well.
    set childs [$jstate(disco) children $jid]
    foreach cjid $childs {
	set cv [concat $v $cjid]
	::Jabber::Disco::AddToTree $cv
     }	    
}

proc ::Jabber::Disco::Refresh {jid} {    
    variable wtree    
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Disco::Refresh jid=$jid"
	
    # Clear internal state of the disco object for this jid.
    $jstate(disco) reset $jid
    
    # Remove all children of this jid from disco tree.
    foreach v [$wtree find withtag $jid] {
	$wtree delitem $v -childsonly 1
    }
    
    # Disco once more, let callback manage rest.
    ::Jabber::Disco::ControlArrows 1
    ::Jabber::Disco::GetItems $jid
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

proc ::Jabber::Disco::InfoCmd {jid} {
    upvar ::Jabber::jstate jstate

    if {![$jstate(disco) isdiscoed info $jid]} {
	set xmllist [$jstate(disco) get info $jid xml]
	::Jabber::Disco::InfoResultCB $jstate(disco) result $jid $xmllist
    } else {
	$jstate(disco) send_get info  $jid [namespace current]::InfoCmdCB
    }
}

proc ::Jabber::Disco::InfoCmdCB {type jid subiq args} {
    
    puts "::Jabber::Disco::InfoCmdCB type=$type, jid=$jid"
    
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
    pack [button $frbot.btadd -text [::msgcat::mc Close] \
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
