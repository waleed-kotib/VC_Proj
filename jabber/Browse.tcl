#  Browse.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the Browse GUI part.
#      
#  Copyright (c) 2001-2004  Mats Bengtsson
#  
# $Id: Browse.tcl,v 1.58 2004-09-30 12:43:06 matben Exp $

package require chasearrows

package provide Browse 1.0

namespace eval ::Jabber::Browse:: {

    ::hooks::register jabberInitHook     ::Jabber::Browse::NewJlibHook
    ::hooks::register loginHook          ::Jabber::Browse::LoginCmd
    ::hooks::register logoutHook         ::Jabber::Browse::LogoutHook
    ::hooks::register presenceHook       ::Jabber::Browse::PresenceHook

    # Use option database for customization. 
    # Use priority 30 just to override the widgetDefault values!
    #option add *Browse*Tree.background    green            30

    variable wtop {}

    # We keep an reference count that gets increased by one for each request
    # sent, and decremented by one for each response.
    variable arrowRefCount 0
    
    # Options only for internal use. EXPERIMENTAL! See browse.tcl
    #     -setbrowsedjid:   default=1, store the browsed jid even if cached already
    variable options
    array set options {
	-setbrowsedjid 1
    }
    
    # Just a dummy widget name for the running arrows until it's built.
    variable wsearrows .xx
    variable dlguid 0
    
    # Use a unique canvas tag in the tree widget for each jid put there.
    # This is needed for the balloons that need a real canvas tag, and that
    # we can't use jid's for this since they may contain special chars (!)!
    variable treeuid 0

    # Template for the browse popup menu.
    variable popMenuDefs

    set popMenuDefs(browse,def) {
	mMessage       user      {::Jabber::NewMsg::Build -to $jid}
	mChat          user      {::Jabber::Chat::StartThread $jid}
	mWhiteboard    wb        {::Jabber::WB::NewWhiteboardTo $jid}
	mEnterRoom     room      {
	    ::Jabber::GroupChat::EnterOrCreate enter -roomjid $jid -autoget 1
	}
	mCreateRoom    conference {::Jabber::GroupChat::EnterOrCreate create \
	  -server $jid}
	separator      {}        {}
	mInfo          jid       {::Jabber::Browse::GetInfo $jid}
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
	mRefresh       jid       {::Jabber::Browse::Refresh $jid}
	mAddServer     any       {::Jabber::Browse::AddServer}
    }
}

# Jabber::Browse::NewJlibHook --
# 
#       Create a new browse instance when created new jlib.

proc ::Jabber::Browse::NewJlibHook {jlibName} {
    upvar ::Jabber::jstate jstate
    
    set jstate(browse) [browse::new $jlibName  \
      -command ::Jabber::Browse::Command]
    
    ::Jabber::AddClientXmlns [list "jabber:iq:browse"]
}

proc ::Jabber::Browse::LoginCmd { } {
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Browse::SetUIWhen "connect"

    # Get the services for all our servers on the list. Depends on our settings:
    # If browsing fails must use "agents" as a fallback.
    if {[string equal $jprefs(serviceMethod) "browse"]} {
	::Jabber::Browse::GetAll
    }
}

proc ::Jabber::Browse::LogoutHook { } {
    
    if {[lsearch [::Jabber::UI::Pages] "Browser"] >= 0} {
	::Jabber::Browse::SetUIWhen "disconnect"
	::Jabber::Browse::Clear
    }
}

# Jabber::Browse::HaveBrowseTree --
#
#       Does the jid belong to a browse tree? This only if we actually
#       have browsed the server the jid belongs to.

proc ::Jabber::Browse::HaveBrowseTree {jid} {    
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
    
# Jabber::Browse::GetAll --
#
#       Queries (browses) the services available for all the servers
#       that are in 'jprefs(browseServers)' plus the login server.
#
# Arguments:
#       
# Results:
#       none.

proc ::Jabber::Browse::GetAll { } {
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jserver jserver
    
    set allServers $jserver(this)
    foreach server $allServers {
	::Jabber::Browse::Get $server
    }
}

# Jabber::Browse::Get --
#
#       Queries (browses) the services available for the $jid.
#
# Arguments:
#       jid         The jid to browse.
#       args    ?-silent 0/1? (D=0)
#       
# Results:
#       callback scheduled.

proc ::Jabber::Browse::Get {jid args} {    
    upvar ::Jabber::jstate jstate
    
    array set opts {
	-silent 0
    }
    array set opts $args
    
    # Browse services available.
    $jstate(browse) send_get $jid \
      [list [namespace current]::GetCallback $opts(-silent)]
}

proc ::Jabber::Browse::GetCallback {silent browseName type from subiq args} {
    
    ::Debug 2 "::Jabber::Browse::GetCallback type=$type"
    
    switch -- $type {
	error {
	    ::Jabber::Browse::ErrorProc $silent $browseName $type $from $subiq
	}
	ok - result {
	    ::Jabber::Browse::Callback $browseName set $from $subiq
	}
    }
}

# Jabber::Browse::Command --
# 
#       Callback command for the browse 2.0 lib.

proc ::Jabber::Browse::Command {browseName type from subiq args} {
       
    ::Debug 2 "::Jabber::Browse::Command type=$type, from=$from"
    
    set ishandled 0

    switch -- $type {
	error {
	    ::Jabber::Browse::ErrorProc $silent $browseName $type $from $subiq
	}
	set {
	    ::Jabber::Browse::Callback $browseName set $from $subiq
	}
	ok - result {
	    # BAD!!!
	    ::Jabber::Browse::Callback $browseName set $from $subiq
	}
	get {
	    eval {::Jabber::Browse::ParseGet $browseName $from $subiq} $args
	    set ishandled 1
	}
    }
    return $ishandled
}

# Jabber::Browse::Callback --
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

proc ::Jabber::Browse::Callback {browseName type from subiq} {    
    variable wtop
    variable tstate
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Jabber::Browse::Callback browseName=$browseName, type=$type,\
      from=$from, subiq='[string range $subiq 0 60] ...'"

    unset -nocomplain tstate(run,$from)
    ::Jabber::Browse::ControlArrows -1
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
		tk_messageBox -type ok -icon error \
		  -message [FormatTextForMessageBox  \
		  [mc jamesserrbrowse $from [lindex $subiq 1]]]
	    }
	}
	set {
    
	    # It is at this stage we are confident that a Browser page is needed.
	    if {[jlib::jidequal $from $jserver(this)]} {
		::Jabber::UI::NewPage "Browser"
	    }
	    
	    # We shall fill in the browse tree. 
	    # Check that server is not configured with identical jid's.
	    set parents [$jstate(browse) getparents $jid]
	    if {[string equal [lindex $parents end] $jid]} {
		tk_messageBox -type ok -title "Server Error" -message \
		  "The Jabber server has an error in its configuration.\
		  The jid \"$jid\" is duplicated for different services.\
		  Contact the system administrator of $jserver(this)."
		return
	    }
	    ::Jabber::Browse::AddToTree $parents $jid $subiq 1
	    
	    # If we have a conference (groupchat) window.
	    ::Jabber::Browse::DispatchUsers $jid $subiq
	    
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
			    ::Jabber::Browse::Get $confjid -silent 1
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

# Jabber::Browse::DispatchUsers --
#
#       Find any <user> element and send to groupchat.

proc ::Jabber::Browse::DispatchUsers {jid subiq} {
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::Browse::DispatchUsers jid=$jid,\
      subiq='[string range $subiq 0 30] ...'"
    
    # Find any <user> elements.
    if {[string equal [wrapper::gettag $subiq] "user"]} {
	::Jabber::GroupChat::BrowseUser $subiq
    }
    foreach child [wrapper::getchildren $subiq] {
	if {[string equal [wrapper::gettag $child] "user"]} {
	    ::Jabber::GroupChat::BrowseUser $child	    
	}
    }
}

# Jabber::Browse::ErrorProc --
# 
#       Error callback for jabber:iq:browse method. Non errors handled by the
#       browse object.
#
#

proc ::Jabber::Browse::ErrorProc {silent browseName type jid errlist} {
    variable tstate
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    ::Debug 2 "::Jabber::Browse::ErrorProc type=$type, jid=$jid, errlist='$errlist'"

    array unset tstate run,*
    ::Jabber::Browse::ControlArrows 0
    
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
		::Jabber::Agents::GetAll
	    }
	    browse {
		::Jabber::Disco::GetInfo  $jserver(this)
		::Jabber::Disco::GetItems $jserver(this)
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
	    tk_messageBox -icon error -type ok -title [mc Error] \
	      -message [FormatTextForMessageBox \
	      [mc jamesserrbrowse $jid [lindex $errlist 1]]]
	}
    }
}


proc ::Jabber::Browse::Show {w} {    
    upvar ::Jabber::jstate jstate

    if {$jstate(browseVis)} {
	if {[winfo exists $w]} {
	    wm deiconify $w
	} else {
	    ::Jabber::Browse::BuildToplevel $w
	}
    } else {
	wm withdraw $w
    }
}

proc ::Jabber::Browse::BuildToplevel {w} {
    global  prefs

    variable wtop

    if {[winfo exists $w]} {
	return
    }
    set wtop $w
    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
    wm title $w {Jabber Browser}
    
    set fontS [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 12 -ipady 4
    
    message $w.frall.msg -width 220 -font $fontSB -anchor w -text \
      {Services that are available on each Jabber server listed.}
    message $w.frall.msg2 -width 220 -font $fontS -anchor w -text  \
      {Open to display its properties}
    pack $w.frall.msg $w.frall.msg2 -side top -fill x -padx 4 -pady 2

    # And the real stuff.
    pack [::Jabber::Browse::Build $w.frall.br] -side top -fill both -expand 1
    
    wm minsize $w 180 260
    wm maxsize $w 420 2000
}
    
# Jabber::Browse::Build --
#
#       Makes mega widget to show the services available for the $server.
#
# Arguments:
#       w           frame window with everything.
#       
# Results:
#       w

proc ::Jabber::Browse::Build {w} {
    global  this prefs
    
    variable wtree
    variable wsearrows
    variable wtop
    variable btaddserv
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    
    ::Debug 2 "::Jabber::Browse::Build"
    
    # The frame of class Browse.
    frame $w -borderwidth 0 -relief flat -class Browse
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
    ::tree::tree $wtree -width 100 -height 100 -silent 1 -scrollwidth 400 \
      -xscrollcommand [list ::UI::ScrollSet $wxsc \
      [list grid $wxsc -row 1 -column 0 -sticky ew]]  \
      -yscrollcommand [list ::UI::ScrollSet $wysc \
      [list grid $wysc -row 0 -column 1 -sticky ns]]  \
      -selectcommand ::Jabber::Browse::SelectCmd   \
      -closecommand [namespace current]::CloseTreeCmd  \
      -opencommand ::Jabber::Browse::OpenTreeCmd
    
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
    
proc ::Jabber::Browse::RegisterPopupEntry {menuSpec} {
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

# Jabber::Browse::Popup --
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

proc ::Jabber::Browse::Popup {w v x y} {
    global  wDlgs this
    
    variable popMenuDefs
    upvar ::Jabber::privatexmlns privatexmlns
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::Browse::Popup w=$w, v='$v', x=$x, y=$y"
    
    # The last element of $v is either a jid, (a namespace,) 
    # a header in roster, a group, or an agents xml tag.
    # The variables name 'jid' is a misnomer.
    # Find also type of thing clicked, 'typeClicked'.
    
    set typeClicked ""
    
    set jid [lindex $v end]
    set jid3 $jid
    set typesubtype [$jstate(browse) gettype $jid]
    
    if {[regexp {^.+@[^/]+(/.*)?$} $jid match res]} {
	set typeClicked user
	if {[$jstate(jlib) service isroom $jid]} {
	    set typeClicked room
	}
    } elseif {[string match -nocase "conference/*" $typesubtype]} {
	set typeClicked conference
    } elseif {$jid != ""} {
	set typeClicked jid
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
		if {[$jstate(browse) hasnamespace $jid "jabber:iq:${type}"]} {
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

# Jabber::Browse::AddToTree --
#
#       Fills tree with content. Calls itself recursively.
#
# Arguments:
#       parentsJidList: 
#       jid:        the jid of the first element in xmllist.
#                   if empty then get it from the attributes instead.
#       xmllist:    xml list starting after the <iq> tag.

proc ::Jabber::Browse::AddToTree {parentsJidList jid xmllist {browsedjid 0}} {    
    variable wtree
    variable options
    variable treeuid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::nsToText nsToText
    
    ::Debug 6 "::Jabber::Browse::AddToTree parentsJidList='$parentsJidList', jid=$jid"

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

    if {$options(-setbrowsedjid)} {}
    
    switch -exact -- $category {
	ns {
	    
	    # outdated !!!!!!!!!
	    if {0} {
		set ns [wrapper::getcdata $xmllist]
		set txt $ns
		if {[info exists nsToText($ns)]} {
		    set txt $nsToText($ns)
		}
		
		# Namespaces indicate supported feature.
		$wtree newitem [concat $parentsJidList \
		  [wrapper::getcdata $xmllist]] -text $txt -dir 0
	    }
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
	    } elseif {$options(-setbrowsedjid) || !$browsedjid} {
		
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
				::Jabber::Roster::GetPresenceIcon $jid $presArr(-type)
			    } $presList]
			}
			
			set icon [::Jabber::Roster::GetPresenceIcon $jid \
			  "available"]
			
			$wtree newitem $jidList -dir 0 -text $txt \
			  -image $icon -tags $jid -canvastags $treectag
		    } else {
			$wtree newitem $jidList -text $txt -tags $jid \
			  -canvastags $treectag
		    }
		} elseif {[string equal $category "service"]} {
		    $wtree newitem $jidList -text $txt -tags $jid -style $style \
		      -canvastags $treectag
		} else {
		    
		    # This is a service, transport, room, etc.
		    # Do not create if exists which preserves -open.
		    if {![$wtree isitem $jidList]} {
			$wtree newitem $jidList -dir 1 -open 0 -text $txt \
			  -tags $jid -canvastags $treectag
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
		::Jabber::Browse::AddToTree $jidList {} $child
	    }
	}
    }
}

# Jabber::Browse::PresenceHook --
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

proc ::Jabber::Browse::PresenceHook {jid type args} {    
    variable wtree
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::privatexmlns privatexmlns

    ::Debug 2 "::Jabber::Browse::PresenceHook jid=$jid, type=$type, args='$args'"

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
		set icon [eval {::Jabber::Roster::GetPresenceIcon $jidhash $type} $args]
		$wtree itemconfigure $jidList -image $icon
	    } elseif {$type == "unavailable"} {
		
	    }
	}
    } else {
	
	# Replaced by presence element, and disco as a fallback.
	# OUTDATED!!!!!!!!!!!!!
	if {0} {
    
	# If users shall be automatically browsed to.
	# Seems only necessary to find out if Coccinella or not.
	if {$jprefs(autoBrowseUsers) && [string equal $type "available"]} {
	    set coccielem \
	      [$jstate(roster) getextras $jid3 $privatexmlns(servers)]
	    if {$coccielem == {}} {
		if {![::Jabber::Roster::IsTransportHeuristics $jid3]} {
		    if {![$jstate(browse) isbrowsed $jid3]} {
			eval {AutoBrowse $jid3 $type} $args
		    }
		}
	    }	
	}
	}
    }
}

#       OUTDATED!!!
# Jabber::Browse::AutoBrowse --
# 
#       If presence from user browse that user including its resource.
#       
# Arguments:
#       jid:        
#       presence    "available" or "unavailable"

proc ::Jabber::Browse::AutoBrowse {jid presence args} {    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Jabber::Browse::AutoBrowse jid=$jid, presence=$presence, args='$args'"

    array set argsArr $args
    
    switch -- $presence {
	available {
	
	    # Browse only potential Coccinella (all jabber) clients.
	    jlib::splitjidex $jid node host x
	    set type [$jstate(browse) gettype $host]
	    
	    ::Debug 4 "\t type=$type"
	    
	    # We may not yet have browsed this (empty).
	    if {($type == "") || ($type == "service/jabber")} {		
		$jstate(browse) send_get $jid [namespace current]::AutoBrowseCmd
	    }
	}
	unavailable {
	    # empty
	}
    }
}

#       OUTDATED!!!

proc ::Jabber::Browse::AutoBrowseCmd {browseName type jid subiq args} {
    
    ::Debug 2 "::Jabber::Browse::AutoBrowseCmd type=$type"
    
    switch -- $type {
	error {
	    ::Jabber::Browse::ErrorProc 1 $browseName $type $jid $subiq
	}
	result - ok {
	    ::Jabber::Browse::AutoBrowseCallback $browseName $type $jid $subiq
	}
    }
}

#       OUTDATED!!!
# Jabber::Browse::AutoBrowseCallback --
# 
#       The intention here is to signal which services a particular client
#       supports to the UI. If coccinella, for instance.
#       
# Arguments:
#       jid:        

proc ::Jabber::Browse::AutoBrowseCallback {browseName type jid subiq} {    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::privatexmlns privatexmlns    
    
    ::Debug 2 "::Jabber::Browse::AutoBrowseCallback, jid=$jid,\
      [string range "subiq='$subiq'" 0 40]..."
    
    if {[$jstate(browse) hasnamespace $jid "coccinella:wb"] || \
      [$jstate(browse) hasnamespace $jid $privatexmlns(whiteboard)]} {
	
	::hooks::run autobrowsedCoccinellaHook $jid
	::Jabber::Roster::SetCoccinella $jid
    }
}

# Jabber::Browse::SelectCmd --
#
#
# Arguments:
#       w           tree widget
#       v           tree item path
#       
# Results:
#       .

proc ::Jabber::Browse::SelectCmd {w v} {
    
}

# Jabber::Browse::OpenTreeCmd --
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

proc ::Jabber::Browse::OpenTreeCmd {w v} {   
    variable wtree    
    variable tstate
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::Browse::OpenTreeCmd v=$v"

    if {[llength $v]} {
	set jid [lindex $v end]
	
	# If we have not yet browsed this jid, do it now!
	# We should have a method to tell if children have been added to tree!!!
	if {![$jstate(browse) isbrowsed $jid]} {
	    set tstate(run,$jid) 1
	    ::Jabber::Browse::ControlArrows 1
	    
	    # Browse services available.
	    ::Jabber::Browse::Get $jid
	} elseif {[llength [$wtree children $v]] == 0} {
	    set xmllist [$jstate(browse) get $jid]
	    foreach child [wrapper::getchildren $xmllist] {
		::Jabber::Browse::AddToTree $v {} $child
	    }
	}
    }    
}

proc ::Jabber::Browse::CloseTreeCmd {w v} {   
    variable tstate
    
    ::Debug 2 "::Jabber::Browse::CloseTreeCmd v=$v"
    set jid [lindex $v end]
    if {[info exists tstate(run,$jid)]} {
	unset tstate(run,$jid)
	::Jabber::Browse::ControlArrows -1
    }
}

proc ::Jabber::Browse::Refresh {jid} {    
    variable wtree    
    variable tstate
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Jabber::Browse::Refresh jid=$jid"
        
    # Clear internal state of the browse object for this jid.
    $jstate(browse) clear $jid
    
    # Remove all children of this jid from browse tree.
    foreach v [$wtree find withtag $jid] {
	$wtree delitem $v -childsonly 1
    }
    
    # Browse once more, let callback manage rest.
    set tstate(run,$jid) 1
    ::Jabber::Browse::ControlArrows 1
    ::Jabber::Browse::Get $jid
}

proc ::Jabber::Browse::ControlArrows {step} {    
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

# Jabber::Browse::ClearRoom --
#
#       Removes all users from room, typically on exit. Not sure of this one...

proc ::Jabber::Browse::ClearRoom {roomJid} {    
    variable wtree    
    upvar ::Jabber::jstate jstate

    set parentList [$jstate(browse) getparents $roomJid]
    set jidList "$parentList $roomJid"
    foreach v [$wtree find withtag $roomJid] {
	$wtree delitem $v -childsonly 1
    }
}

proc ::Jabber::Browse::Clear { } {    
    variable wtree    
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Jabber::Browse::Clear"
    
    # Remove the complete tree. We could relogin, and then we need a fresh start.
    $wtree delitem {}
    
    # Clears out all cached info in browse object.
    $jstate(browse) clear
}

proc ::Jabber::Browse::CloseDlg {w} {    
    upvar ::Jabber::jstate jstate

    wm withdraw $w
    set jstate(browseVis) 0
}

proc ::Jabber::Browse::AddServer { } {
    global  prefs
    
    variable finishedAdd -1

    set w .jaddsrv
    if {[winfo exists $w]} {
	return
    }
    set finishedAdd 0
    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w [mc {Add Server}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1 -ipadx 12 -ipady 4
    message $w.frall.msg -width 220 -text [mc jabrowseaddserver]
    entry $w.frall.ent -width 24   \
      -textvariable "[namespace current]::addserver"
    pack $w.frall.msg $w.frall.ent -side top -fill x -anchor w -padx 10  \
      -pady 4

    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btadd -text [mc Add] -default active \
      -command [list [namespace current]::DoAddServer $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::CancelAdd $w]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
        
    wm resizable $w 0 0
        
    # Grab and focus.
    set oldFocus [focus]
    focus $w.frall.ent
    catch {grab $w}
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w

    catch {grab release $w}
    catch {focus $oldFocus}
    return [expr {($finishedAdd <= 0) ? "cancel" : "add"}]
}

proc ::Jabber::Browse::CancelAdd {w} {
    variable finishedAdd

    set finishedAdd 0
    destroy $w
}

proc ::Jabber::Browse::DoAddServer {w} {   
    variable addserver
    variable finishedAdd
    upvar ::Jabber::jprefs jprefs
    
    set finishedAdd 1
    destroy $w
    if {[llength $addserver] == 0} {
	return
    }
    
    # Verify that we doesn't have it already.
    if {[lsearch $jprefs(browseServers) $addserver] >= 0} {
	tk_messageBox -type ok -icon info  \
	  -message {We have this server already on our list}
	return
    }
    lappend jprefs(browseServers) $addserver
    
    # Browse services for this server, schedules update tree.
    ::Jabber::Browse::Get $addserver
    
}

# Jabber::Browse::SetUIWhen --
#
#       Update the browse buttons etc to reflect the current state.
#
# Arguments:
#       what        any of "connect", "disconnect"
#

proc ::Jabber::Browse::SetUIWhen {what} {    
    variable btaddserv

    # unused!
    return
    
    switch -- $what {
	connect {
	    $btaddserv configure -state normal
	}
	disconnect {
	    $btaddserv configure -state disabled
	}
    }
}

proc ::Jabber::Browse::GetInfo {jid args} {    
    upvar ::Jabber::jstate jstate
    
    array set opts {
	-silent 0
    }
    array set opts $args
    
    # Browse services available.
    $jstate(browse) send_get $jid ::Jabber::Browse::InfoCB
}

proc ::Jabber::Browse::InfoCB {browseName type jid subiq args} {
    
    ::Debug 4 "::Jabber::Browse::InfoCB type=$type, jid=$jid, '$subiq'"
    
    switch -- $type {
	error {
	    ::Jabber::Browse::ErrorProc 0 $browseName error $jid $subiq
	}
	result - ok {
	    eval {::Jabber::Browse::InfoResultCB $browseName $type $jid $subiq} $args
	}
    }
}

proc ::Jabber::Browse::InfoResultCB {browseName type jid subiq args} {
    global  this
    
    variable dlguid
    upvar ::Jabber::nsToText nsToText

    set w .brres[incr dlguid]
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w "Browse Info: $jid"
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
	    
# Jabber::Browse::ParseGet --
#
#       Respond to an incoming 'jabber:iq:browse' get query.
#       
# Results:
#       boolean (0/1) telling if this was handled or not.

proc ::Jabber::Browse::ParseGet {jlibname from subiq args} {
    global  prefs    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::privatexmlns privatexmlns

    ::Debug 2 "::Jabber::Browse::ParseGet: from=$from, args='$args'"
    
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
    eval {$jstate(jlib) send_iq "result" $xmllist -to $from} $opts
    
    # Tell jlib's iq-handler that we handled the event.
    return 1
}

#-------------------------------------------------------------------------------
