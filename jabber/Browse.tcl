#  Browse.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the Browse GUI part.
#      
#  Copyright (c) 2001-2005  Mats Bengtsson
#  
# $Id: Browse.tcl,v 1.78 2005-10-26 14:38:34 matben Exp $

package provide Browse 1.0

namespace eval ::Browse:: {

    ::hooks::register jabberInitHook     ::Browse::NewJlibHook
    ::hooks::register loginHook          ::Browse::LoginCmd
    ::hooks::register logoutHook         ::Browse::LogoutHook
    ::hooks::register presenceHook       ::Browse::PresenceHook

    # Use option database for customization. 
    # Use priority 30 just to override the widgetDefault values!
    option add *Browse.waveImage            wave            widgetDefault

    # Standard widgets and standard options.
    option add *Browse.padding              4               50
    option add *Browse*box.borderWidth      1               50
    option add *Browse*box.relief           sunken          50

    variable wtop  -
    variable wwave -
    variable wtab  -
    variable wtree -
    
    variable dlguid 0
    
    # Use a unique canvas tag in the tree widget for each jid put there.
    # This is needed for the balloons that need a real canvas tag, and that
    # we can't use jid's for this since they may contain special chars (!)!
    variable treeuid 0

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

    set popMenuDefs(browse,def) {
	mMessage       user      {::NewMsg::Build -to $jid}
	mChat          user      {::Chat::StartThread $jid}
	mWhiteboard    {wb room} {::Jabber::WB::NewWhiteboardTo $jid}
	mEnterRoom     room      {
	    ::GroupChat::EnterOrCreate enter -roomjid $jid -autoget 1
	}
	mCreateRoom    conference {::GroupChat::EnterOrCreate create \
	  -server $jid}
	separator      {}        {}
	mInfo          jid       {::Browse::GetInfo $jid}
	mLastLogin/Activity jid  {::Jabber::GetLast $jid}
	mLocalTime     jid       {::Jabber::GetTime $jid}
	mvCard         jid       {::VCard::Fetch other $jid}
	mVersion       jid       {::Jabber::GetVersion $jid}
	separator      {}        {}
	mSearch        search    {
	    ::Search::Build -server $jid -autoget 1
	}
	mRegister      register  {
	    ::GenRegister::NewDlg -server $jid -autoget 1
	}
	mUnregister    register  {::Register::Remove $jid}
	separator      {}        {}
	mRefresh       jid       {::Browse::Refresh $jid}
	mAddServer     {}        {::Browse::AddServer}
    }
}

# Browse::NewJlibHook --
# 
#       Create a new browse instance when created new jlib.

proc ::Browse::NewJlibHook {jlibName} {
    upvar ::Jabber::jstate jstate
    
    # We could add more icons for other categories here!
    variable typeIcon
    array set typeIcon [list                                    \
      service/aim           [::Rosticons::Get aim/online]     \
      service/icq           [::Rosticons::Get icq/online]     \
      service/msn           [::Rosticons::Get msn/online]     \
      service/yahoo         [::Rosticons::Get yahoo/online]   \
      service/x-gadugadu    [::Rosticons::Get gadugadu/online]\
      service/smtp          [::Rosticons::Get smtp/online]\
      ]

    set jstate(browse) [browse::new $jlibName  \
      -command [namespace current]::Command]
    
    ::Jabber::AddClientXmlns [list "jabber:iq:browse"]
}

proc ::Browse::LoginCmd { } {
    upvar ::Jabber::jprefs jprefs
    
    # Get the services for all our servers on the list. Depends on our settings:
    # If browsing fails must use "agents" as a fallback.
    if {[string equal $jprefs(serviceMethod) "browse"]} {
	GetAll
    }
}

proc ::Browse::LogoutHook { } {    
    variable wtab
    
    Clear
    if {[winfo exists $wtab]} {
	set wnb [::Jabber::UI::GetNotebook]
	$wnb forget $wtab
	destroy $wtab
    }
}

# Browse::HaveBrowseTree --
#
#       Does the jid belong to a browse tree? This only if we actually
#       have browsed the server the jid belongs to.

proc ::Browse::HaveBrowseTree {jid} {    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jstate jstate
    
    set allServers [lsort -unique [concat $jserver(this) $jprefs(browseServers)]]
	
    # This is not foolproof!!!
    foreach server $allServers {
	if {[string match "*$server" $jid]} {
	    if {[$jstate(browse) isbrowsed $server]} {
		return 1
	    }
	}
    }    
    return 0
}
    
# Browse::GetAll --
#
#       Queries (browses) the services available for all the servers
#       that are in 'jprefs(browseServers)' plus the login server.
#
# Arguments:
#       
# Results:
#       none.

proc ::Browse::GetAll { } {
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jserver jserver
    
    set allServers $jserver(this)
    foreach server $allServers {
	Get $server
    }
}

# Browse::Get --
#
#       Queries (browses) the services available for the $jid.
#
# Arguments:
#       jid         The jid to browse.
#       args    ?-silent 0/1? (D=0)
#       
# Results:
#       callback scheduled.

proc ::Browse::Get {jid args} {    
    upvar ::Jabber::jstate jstate
    
    array set opts {
	-silent 0
    }
    array set opts $args
    
    # Browse services available.
    $jstate(browse) send_get $jid \
      [list [namespace current]::GetCallback $opts(-silent)]
}

proc ::Browse::GetCallback {silent browseName type from subiq args} {
    
    ::Debug 2 "::Browse::GetCallback type=$type"
    
    switch -- $type {
	error {
	    ErrorProc $silent $browseName $type $from $subiq
	}
	ok - result {
	    Callback $browseName set $from $subiq
	}
    }
}

# Browse::Command --
# 
#       Callback command for the browse 2.0 lib.

proc ::Browse::Command {browseName type from subiq args} {
       
    ::Debug 2 "::Browse::Command type=$type, from=$from"
    
    set ishandled 0

    switch -- $type {
	error {
	    ErrorProc $silent $browseName $type $from $subiq
	}
	set {
	    Callback $browseName set $from $subiq
	    
	    # This is critical for the old jabber:iq:conference !
	    set ishandled 1
	}
	ok - result {
	    # BAD!!!
	    Callback $browseName set $from $subiq
	}
	get {
	    eval {ParseGet $browseName $from $subiq} $args
	    set ishandled 1
	}
    }
    return $ishandled
}

# Browse::Callback --
#
#       It receives reports from iq set and result elements with the
#       jabber:iq:browse namespace.
#
# Arguments:
#       type:       can be 'set', or 'error'.
#       from:       the from attribute
#       subiq:      xml list starting after the <iq> tag;
#                   if 'error' then {errorCode errorMsg}
#       
# Results:
#       none. UI maybe updated, jids may be auto browsed.

proc ::Browse::Callback {browseName type from subiq} {    
    variable wtop
    variable wwave
    variable tstate
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Browse::Callback browseName=$browseName, type=$type,\
      from=$from, subiq='[string range $subiq 0 60] ...'"

    unset -nocomplain tstate(run,$from)
    if {[winfo exists $wwave]} {
	$wwave animate -1
    }
    array set attrArr [wrapper::getattrlist $subiq]

    # Docs say that jid is required attribute but... 
    # <conference> and <service> seem to lack jid.
    # If no jid attribute it is probably(?) assumed to be 'fromJid.
    if {![info exists attrArr(jid)]} {
	set jid $from
    } else {
	set jid $attrArr(jid)
    }

    switch -- $type {
	error {
	    
	    # Shall we be silent? 
	    if {[winfo exists $wtop]} {
		::UI::MessageBox -type ok -icon error \
		  -message [mc jamesserrbrowse $from [lindex $subiq 1]]
	    }
	}
	set {
    
	    # It is at this stage we are confident that a Browser page is needed.
	    if {[jlib::jidequal $from $jserver(this)]} {
		NewPage
	    }
	    
	    # We shall fill in the browse tree. 
	    # Check that server is not configured with identical jid's.
	    set parents [$jstate(browse) getparents $jid]
	    if {[string equal [lindex $parents end] $jid]} {
		::UI::MessageBox -type ok -title "Server Error" -message \
		  "The Jabber server has an error in its configuration.\
		  The jid \"$jid\" is duplicated for different services.\
		  Contact the system administrator of $jserver(this)."
		return
	    }
	    AddToTree $parents $jid $subiq 1
	    
	    # If we have a conference (groupchat) window.
	    DispatchUsers $jid $subiq
	    
	    # Browse all services for any public (jabber) conference servers.
	    # Two things: 
	    #     1) we need to query its version number to know which 
	    #        protocol to use. 
	    #        The old groupchat protocol is used as a fallback.
	    #     2) if belongs to our login server, then browse it
	       
	    foreach child [wrapper::getchildren $subiq] {
		
		# We need to take into account the changed browse syntax:
		# 1)  <conference ...
		# 2)  <item category='conference' ...
		set isConference 0
		set tag [lindex $child 0]
		if {[string equal $tag "conference"]} {
		    set isConference 1
		} elseif {[string equal $tag "item"]} {
		    set category [wrapper::getattribute $child category]
		    if {[string equal $category "conference"]} {
			set isConference 1
		    }
		}
		if {$isConference} {
		    unset -nocomplain cattrArr
		    array set cattrArr [lindex $child 1]
		    set confjid $cattrArr(jid)
		    
		    # Exclude the rooms.
		    if {![string match "*@*" $confjid]} {
			
			# Keep a record of which components that support the
			# jabber:iq:conference namespace
			if {![info exists jstate(conference,$confjid)]} {
			    set jstate(conference,$confjid) 0
			}
			
			# Protocol: (groupchat | conference | muc)
			if {![info exists jstate(groupchatprotocol,$confjid)]} {
			    set jstate(groupchatprotocol,$confjid) "groupchat"
			}
			
			# In principle the <ns/> elements shall signal type
			# of protocol. Some 'jabber:iq:conference' services
			# don't advertise themself with this namespace.
			# As a fallback we try to look at its version info.
			set haveNS 0
			foreach c [wrapper::getchildren $child] {
			    if {[string equal [lindex $c 0] "ns"]} {
				set haveNS 1
				break
			    }
			}
			
			if {!$haveNS && [info exists cattrArr(type)] &&  \
			  ($cattrArr(type) == "public" ||  \
			  $cattrArr(type) == "private")} {
			    $jstate(jlib) get_version $confjid   \
			      [list ::Jabber::CacheGroupchatType $confjid]
			}

			# Auto browse only 'public' jabber conferences.
			if {$jprefs(autoBrowseConference) &&  \
			  [info exists cattrArr(type)] &&   \
			  ($cattrArr(type) == "public")} {
			    Get $confjid -silent 1
			}
		    }
		}
		# Ende: foreach child
	    }
	    
	    # Let other interested parties know we've got browse info.
	    ::hooks::run browseSetHook $from $subiq
	}
    }
}

# Browse::DispatchUsers --
#
#       Find any <user> element and send to groupchat.

proc ::Browse::DispatchUsers {jid subiq} {
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Browse::DispatchUsers jid=$jid,\
      subiq='[string range $subiq 0 30] ...'"
    
    # Find any <user> elements.
    if {[string equal [wrapper::gettag $subiq] "user"]} {
	::GroupChat::BrowseUser $subiq
    }
    foreach child [wrapper::getchildren $subiq] {
	if {[string equal [wrapper::gettag $child] "user"]} {
	    ::GroupChat::BrowseUser $child	    
	}
    }
}

# Browse::ErrorProc --
# 
#       Error callback for jabber:iq:browse method. Non errors handled by the
#       browse object.
#
#

proc ::Browse::ErrorProc {silent browseName type jid errlist} {
    variable tstate
    variable wwave
    variable wtree
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    ::Debug 2 "::Browse::ErrorProc type=$type, jid=$jid, errlist='$errlist'"

    array unset tstate run,*
    if {[winfo exists $wwave]} {
	$wwave animate 0
    }
    
    # If we got an error browsing an actual server, then remove from list.
    set ind [lsearch -exact $jprefs(browseServers) $jid]
    if {$ind >= 0} {
	set jprefs(browseServers) [lreplace $jprefs(browseServers) $ind $ind]
    }
    
    # As a fallback we use the disco or agents method instead if browsing 
    # the login server fails.
    if {[jlib::jidequal $jid $jserver(this)]} {

	switch -- $jprefs(serviceMethod) {
	    disco {
		::Agents::GetAll
	    }
	    browse {
		::Disco::DiscoServer $jserver(this)
	    }
	}	
	::Jabber::AddErrorLog $jid  \
	  "Failed browsing: Error code [lindex $errlist 0] and message:\
	  [lindex $errlist 1]"
    } else {
	
	# Silent...
	if {$silent} {
	    ::Jabber::AddErrorLog $jid  \
	      "Failed browsing: Error code [lindex $errlist 0] and message:\
	      [lindex $errlist 1]"
	} else {
	    ::UI::MessageBox -icon error -type ok -title [mc Error] \
	      -message [mc jamesserrbrowse $jid [lindex $errlist 1]]
	}
    }
}

proc ::Browse::NewPage { } {
    variable wtab
    
    set wnb [::Jabber::UI::GetNotebook]
    set wtab $wnb.br
    if {![winfo exists $wtab]} {
	set im [::Theme::GetImage \
	  [option get [winfo toplevel $wnb] browser16Image {}]]
	set imd [::Theme::GetImage \
	  [option get [winfo toplevel $wnb] browser16DisImage {}]]
	set imSpec [list $im disabled $imd background $imd]
	Build $wtab
	$wnb add $wtab -text [mc Browser] -image $imSpec -compound left
    }
}
    
# Browse::Build --
#
#       Makes mega widget to show the services available for the $server.
#
# Arguments:
#       w           frame window with everything.
#       
# Results:
#       w

proc ::Browse::Build {w} {
    global  this prefs
    
    variable wtree
    variable wtop
    variable wwave
    variable btaddserv
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Browse::Build"

    set wbrowser $w
    set wwave    $w.fs
    set wbox     $w.box
    set wtree    $wbox.tree
    set wxsc     $wbox.xsc
    set wysc     $wbox.ysc

    # The frame of class Browse.
    ttk::frame $w -class Browse
        
    set waveImage [::Theme::GetImage [option get $w waveImage {}]]  
    ::wavelabel::wavelabel $wwave -relief groove -bd 2 \
      -type image -image $waveImage
    pack $wwave -side bottom -fill x -padx 8 -pady 2

    # D = -border 1 -relief sunken
    frame $wbox
    pack  $wbox -side top -fill both -expand 1

    tuscrollbar $wxsc -command [list $wtree xview] -orient horizontal
    tuscrollbar $wysc -command [list $wtree yview] -orient vertical
    ::tree::tree $wtree -width 100 -height 100 -silent 1 -scrollwidth 400 \
      -xscrollcommand [list ::UI::ScrollSet $wxsc \
      [list grid $wxsc -row 1 -column 0 -sticky ew]]  \
      -yscrollcommand [list ::UI::ScrollSet $wysc \
      [list grid $wysc -row 0 -column 1 -sticky ns]]  \
      -selectcommand [namespace current]::SelectCmd   \
      -closecommand [namespace current]::CloseTreeCmd  \
      -opencommand [namespace current]::OpenTreeCmd  \
      -eventlist [list [list <<ButtonPopup>> [namespace current]::Popup]]

    if {[string match "mac*" $this(platform)]} {
	$wtree configure -buttonpresscommand [namespace current]::Popup
    }
    grid  $wtree  -row 0 -column 0 -sticky news
    grid  $wysc   -row 0 -column 1 -sticky ns
    grid  $wxsc   -row 1 -column 0 -sticky ew
    grid columnconfigure $wbox 0 -weight 1
    grid rowconfigure $wbox 0 -weight 1
        
    # All tree content is set from browse callback from the browse object.
    
    return $w
}
    
proc ::Browse::RegisterPopupEntry {menuSpec} {
    variable popMenuDefs
    
    # Keeps track of all registered menu entries.
    variable regPopMenuSpec
    
    # Index of last separator.
    set ind [lindex [lsearch -all $popMenuDefs(browse,def) "separator"] end]
    if {![info exists regPopMenuSpec]} {
	
	# Add separator if this is the first addon entry.
	incr ind 3
	set popMenuDefs(browse,def) [linsert $popMenuDefs(browse,def)  \
	  $ind {separator} {} {}]
	set regPopMenuSpec {}
	set ind [lindex [lsearch -all $popMenuDefs(browse,def) "separator"] end]
    }
    
    # Add new entry just before the last separator
    set v $popMenuDefs(browse,def)
    set popMenuDefs(browse,def) [concat [lrange $v 0 [expr $ind-1]] $menuSpec \
      [lrange $v $ind end]]
    set regPopMenuSpec [concat $regPopMenuSpec $menuSpec]
}

# Browse::Popup --
#
#       Handle popup menu in browse dialog.
#       
# Arguments:
#       w           widget that issued the command: tree or text
#       v           for the tree widget it is the item path, 
#                   for text the jidhash.
#       
# Results:
#       popup menu displayed

proc ::Browse::Popup {w v x y} {
    global  wDlgs this
    
    variable popMenuDefs
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Browse::Popup w=$w, v='$v', x=$x, y=$y"
    
    set jid [lindex $v end]
    set typesubtype [$jstate(browse) gettype $jid]
    jlib::splitjidex $jid username host res

    ::Debug 4 "\t jid=$jid, typesubtype=$typesubtype"
    
    # Make a list of all the features of the clicked item.
    # This is then matched against each menu entries type to set its state.

    set clicked {}
    if {[lsearch -glob $typesubtype "conference/*"] >= 0} {
	lappend clicked conference
    }
    if {[lsearch -glob $typesubtype "user/*"] >= 0} {
	lappend clicked user
    }
    if {$username != ""} {
	if {[$jstate(browse) isroom $jid]} {
	    lappend clicked room
	} else {
	    lappend clicked user
	}
    }
    foreach name {search register} {
	if {[$jstate(browse) hasnamespace $jid "jabber:iq:${name}"]} {
	    lappend clicked $name
	}
    }
    if {[::Roster::IsCoccinella $jid]} {
	lappend clicked wb
    }
    if {$jid != ""} {
	lappend clicked jid
    }
    
    ::Debug 2 "\t clicked=$clicked"

    # Mads Linden's workaround for menu post problem on mac:
    # all in menubutton commands i add "after 40 the_command"
    # this way i can never have to posting error.
    # it is important after the tk_popup f.ex to
    #
    # destroy .mb
    # update
    #
    # this way the .mb is destroyed before the next window comes up, thats how I
    # got around this.
    
    # Make the appropriate menu.
    set m $jstate(wpopup,browse)
    set i 0
    catch {destroy $m}
    menu $m -tearoff 0
    
    foreach {item type cmd} $popMenuDefs(browse,def) {
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

# Browse::AddToTree --
#
#       Fills tree with content. Calls itself recursively.
#
# Arguments:
#       parentsJidList: 
#       jid:        the jid of the first element in xmllist.
#                   if empty then get it from the attributes instead.
#       xmllist:    xml list starting after the <iq> tag.

proc ::Browse::AddToTree {parentsJidList jid xmllist {browsedjid 0}} {    
    variable wtree
    variable treeuid
    variable typeIcon
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::nsToText nsToText
    
    
    # Verify that parent tree item really exists!
    if {![$wtree isitem $parentsJidList]} {
	return
    }
    
    set category [wrapper::gettag $xmllist]
    array set attrArr [wrapper::getattrlist $xmllist]
    if {[string equal $category "item"] && [info exists attrArr(category)]} {
	set category $attrArr(category)
    }
    set treectag item[incr treeuid]
    
    switch -exact -- $category {
	ns {
	    # empty
	}
	default {
    
	    # If the 'jid' is empty we get it from our attributes!
	    if {[string length $jid] == 0} {
		set jid $attrArr(jid)
	    }
	    set jidList [concat $parentsJidList $jid]
	    set allChildren [wrapper::getchildren $xmllist]
	    
	    ::Debug 6 "\t jidList='$jidList'"
	    
	    if {[info exists attrArr(type)] && \
	      [string equal $attrArr(type) "remove"]} {
		
		# Remove this jid from tree widget.
		foreach v [$wtree find withtag $jid] {
		    $wtree delitem $v
		}
	    } else {
		
		# Set this jid in tree widget.
		set txt $jid		
		if {[info exists attrArr(name)]} {
		    set txt $attrArr(name)
		} elseif {[regexp {^([^@]+)@.*} $jid match user]} {
		    set txt $user
		}
		set openParent 0
		
		# Make the first two levels, server and its children bold, rest normal style.
		set style normal
		if {[llength $jidList] <= 2} {
		    set style bold
		}
		set cattype [$jstate(browse) gettype $jid]
		
		# If three-tier jid, then dead-end.
		# Note: it is very unclear how to determine if dead-end without
		# an additional browse of that jid.
		# This is very ad hoc!!!
		if {[regexp {^([^@]+@[^/]+)/(.*)$} $jid match jid2 res]} {
		    if {[string equal $category "user"]} {
			
			# This seems to work well only for MUC; skip it.
			# No presence seem to exist for the room jid in conference.
			if {0} {
			    set presList [$jstate(roster) getpresence $jid2 \
			      -resource $res]
			    array set presArr $presList
			    set icon [eval {
				::Roster::GetPresenceIcon $jid $presArr(-type)
			    } $presList]
			}
			
			set icon [::Roster::GetPresenceIcon $jid \
			  "available"]
			
			$wtree newitem $jidList -dir 0 -text $txt \
			  -image $icon -tags [list $jid] -canvastags $treectag
		    } else {
			$wtree newitem $jidList -text $txt -tags [list $jid] \
			  -canvastags $treectag
		    }
		} elseif {[string equal $category "service"]} {
		    set icon  ""
		    if {[info exists typeIcon($cattype)]} {
			set icon $typeIcon($cattype)
		    }
		    $wtree newitem $jidList -text $txt -tags [list $jid] \
		      -fontstyle $style -canvastags $treectag -image $icon
		} else {
		    
		    # This is a service, transport, room, etc.
		    # Do not create if exists which preserves -open.
		    if {![$wtree isitem $jidList]} {
			$wtree newitem $jidList -dir 1 -open 0 -text $txt \
			  -tags [list $jid] -canvastags $treectag
		    }
		}

		set typesubtype [$jstate(browse) gettype $jid]
		set jidtxt $jid
		if {[string length $jid] > 30} {
		    set jidtxt "[string range $jid 0 28]..."
		}
		set msg "jid: $jidtxt\ntype: $typesubtype"
		::balloonhelp::balloonfortree $wtree $treectag $msg
	    }
	    
	    # If any child elements, call ourself recursively.
	    foreach child $allChildren {
		AddToTree $jidList {} $child
	    }
	}
    }
}

# Browse::PresenceHook --
#
#       Sets the presence of the (<user>) jid in our browse tree.
#
# Arguments:
#       jid  
#       type        "available", "unavailable", or "unsubscribed"
#       args        list of '-key value' pairs of presence attributes.
#       
# Results:
#       browse tree icon updated.

proc ::Browse::PresenceHook {jid type args} {    
    variable wtree
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::coccixmlns coccixmlns

    ::Debug 2 "::Browse::PresenceHook jid=$jid, type=$type, args='$args'"

    array set argsArr $args
    set jid3 $jid
    if {[info exists argsArr(-resource)] &&  \
      [string length $argsArr(-resource)]} {
	set jid3 ${jid}/$argsArr(-resource)
    }

    if {[$jstate(jlib) service isroom $jid]} {
	if {[HaveBrowseTree $jid]} {
	    
	    if {![winfo exists $wtree]} {
		return
	    }
	    set jidhash ${jid}/$argsArr(-resource)
	    set parentList [$jstate(browse) getparents $jidhash]
	    set jidList [concat $parentList [list $jidhash]]
	    if {![$wtree isitem $jidList]} {
		return
	    }
	    if {$type == "available"} {
		
		# Add first if not there?    
		set icon [eval {::Roster::GetPresenceIcon $jidhash $type} $args]
		$wtree itemconfigure $jidList -image $icon
	    } elseif {$type == "unavailable"} {
		
	    }
	}
    } else {
	
	# Replaced by presence element, and disco as a fallback.
    }
}

# Browse::SelectCmd --
#
#
# Arguments:
#       w           tree widget
#       v           tree item path
#       
# Results:
#       .

proc ::Browse::SelectCmd {w v} {
    
}

# Browse::OpenTreeCmd --
#
#       Callback when open service item in tree.
#       It browses a subelement of the server jid, typically
#       jud.jabber.org, aim.jabber.org etc.
#
# Arguments:
#       w           tree widget
#       v           tree item path (jidList: {jabber.org jud.jabber.org} etc.)
#       
# Results:
#       none.

proc ::Browse::OpenTreeCmd {w v} {   
    variable wtree
    variable wwave
    variable tstate
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Browse::OpenTreeCmd v=$v"

    if {[llength $v]} {
	set jid [lindex $v end]
	
	# If we have not yet browsed this jid, do it now!
	# We should have a method to tell if children have been added to tree!!!
	if {![$jstate(browse) isbrowsed $jid]} {
	    set tstate(run,$jid) 1
	    $wwave animate 1
	    
	    # Browse services available.
	    Get $jid
	} elseif {[llength [$wtree children $v]] == 0} {
	    set xmllist [$jstate(browse) get $jid]
	    foreach child [wrapper::getchildren $xmllist] {
		AddToTree $v {} $child
	    }
	}
    }    
}

proc ::Browse::CloseTreeCmd {w v} {   
    variable wwave
    variable tstate
    
    ::Debug 2 "::Browse::CloseTreeCmd v=$v"
    set jid [lindex $v end]
    if {[info exists tstate(run,$jid)]} {
	unset tstate(run,$jid)
	$wwave animate -1
    }
}

proc ::Browse::Refresh {jid} {    
    variable wtree
    variable wwave
    variable tstate
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Browse::Refresh jid=$jid"
        
    # Clear internal state of the browse object for this jid.
    $jstate(browse) clear $jid
    
    # Remove all children of this jid from browse tree.
    foreach v [$wtree find withtag $jid] {
	$wtree delitem $v -childsonly 1
    }
    
    # Browse once more, let callback manage rest.
    set tstate(run,$jid) 1
    $wwave animate 1
    Get $jid
}

# Browse::ClearRoom --
#
#       Removes all users from room, typically on exit. Not sure of this one...

proc ::Browse::ClearRoom {roomJid} {    
    variable wtree    
    upvar ::Jabber::jstate jstate

    set parentList [$jstate(browse) getparents $roomJid]
    set jidList "$parentList $roomJid"
    foreach v [$wtree find withtag $roomJid] {
	$wtree delitem $v -childsonly 1
    }
}

proc ::Browse::Clear { } {    
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Browse::Clear"
        
    # Clears out all cached info in browse object.
    $jstate(browse) clear
}

proc ::Browse::CloseDlg {w} {    
    upvar ::Jabber::jstate jstate

    wm withdraw $w
    set jstate(browseVis) 0
}

proc ::Browse::AddServer { } {
    global  prefs
    
    variable finishedAdd -1

    set w .jaddsrv
    if {[winfo exists $w]} {
	raise $w
	return
    }
    set finishedAdd 0
    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w [mc {Add Server}]
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 300 -justify left \
      -text [mc jabrowseaddserver]
    ttk::entry $wbox.ent -width 24  \
      -textvariable [namespace current]::addserver \
      -validate key -validatecommand {::Jabber::ValidateDomainStr %S}
    pack  $wbox.msg  $wbox.ent  -side top -fill x -anchor w -pady 2

    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Add] -default active \
      -command [list [namespace current]::DoAddServer $w]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelAdd $w]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side bottom -fill x

    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
        
    # Grab and focus.
    set oldFocus [focus]
    focus $wbox.ent
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w

    catch {grab release $w}
    catch {focus $oldFocus}
    return [expr {($finishedAdd <= 0) ? "cancel" : "add"}]
}

proc ::Browse::CancelAdd {w} {
    variable finishedAdd

    set finishedAdd 0
    destroy $w
}

proc ::Browse::DoAddServer {w} {   
    variable addserver
    variable finishedAdd
    variable wtree
    upvar ::Jabber::jprefs jprefs
    
    set finishedAdd 1
    destroy $w
    if {$addserver == ""} {
	return
    }
    
    # Verify that we doesn't have it already.
    if {[$wtree isitem $addserver]} {
	::UI::MessageBox -type ok -icon info  \
	  -message {We have this server already on our list}
	return
    }
    lappend jprefs(browseServers) $addserver
    set jprefs(browseServers) [lsort -unique $jprefs(browseServers)]
    
    # Browse services for this server, schedules update tree.
    Get $addserver
    
}

proc ::Browse::GetInfo {jid args} {    
    upvar ::Jabber::jstate jstate
    
    array set opts {
	-silent 0
    }
    array set opts $args
    
    # Browse services available.
    $jstate(browse) send_get $jid ::Browse::InfoCB
}

proc ::Browse::InfoCB {browseName type jid subiq args} {
    
    ::Debug 4 "::Browse::InfoCB type=$type, jid=$jid, '$subiq'"
    
    switch -- $type {
	error {
	    ErrorProc 0 $browseName error $jid $subiq
	}
	result - ok {
	    eval {InfoResultCB $browseName $type $jid $subiq} $args
	}
    }
}

proc ::Browse::InfoResultCB {browseName type jid subiq args} {
    global  this
    
    variable dlguid
    upvar ::Jabber::nsToText nsToText

    set w .brres[incr dlguid]
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w "Browse Info: $jid"
    
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
    
    $wtext tag configure head -background gray70
    $wtext insert end "XML namespace\tDescription\n" head
    set n 1
    foreach c [wrapper::getchildren $subiq] {
	if {[wrapper::gettag $c] == "ns"} {
	    incr n
	    set ns [wrapper::getcdata $c]
	    $wtext insert end $ns
	    if {[info exists nsToText($ns)]} {
		$wtext insert end "\t$nsToText($ns)"
	    }
	    $wtext insert end \n
	}
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
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
	
    wm resizable $w 0 0	
}
	    
# Browse::ParseGet --
#
#       Respond to an incoming 'jabber:iq:browse' get query.
#       
# Results:
#       boolean (0/1) telling if this was handled or not.

proc ::Browse::ParseGet {jlibname from subiq args} {
    global  prefs    
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Browse::ParseGet: from=$from, args='$args'"
    
    array set argsArr $args
    
    # Return any id!
    set opts {}
    if {[info exists argsArr(-id)]} {
	set opts [list -id $argsArr(-id)]
    }
    
    # Adding all xml namespaces.
    set subtags {}
    foreach ns [::Jabber::GetClientXmlnsList] {
	lappend subtags [wrapper::createtag "ns" -chdata $ns]
    }
    
    set attr [list xmlns jabber:iq:browse jid $jstate(mejidresmap)  \
      type client category user]
    set xmllist [wrapper::createtag "item" -subtags $subtags -attrlist $attr]
    eval {$jstate(jlib) send_iq "result" [list $xmllist] -to $from} $opts
    
    # Tell jlib's iq-handler that we handled the event.
    return 1
}

#-------------------------------------------------------------------------------
