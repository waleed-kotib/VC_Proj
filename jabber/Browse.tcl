#  Browse.tcl ---
#  
#      This file is part of the whiteboard application. 
#      It implements the Browse GUI part.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
# $Id: Browse.tcl,v 1.4 2003-05-25 15:03:27 matben Exp $

package provide Browse 1.0

namespace eval ::Jabber::Browse:: {

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
    
    set allServers [lsort -unique [concat $jserver(this) $jprefs(browseServers)]]
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
    $jstate(jlib) browse_get $jid -errorcommand  \
      [list ::Jabber::Browse::ErrorProc $opts(-silent)]
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

# Jabber::Browse::Callback --
#
#       The callback proc from the 'browse' object.
#       It receives reports from iq set and result elements with the
#       jabber:iq:browse namespace.
#
# Arguments:
#       type:       can be 'set', or 'error'.
#       jid:        the jid of the first element in 'subiq'.
#       subiq:      xml list starting after the <iq> tag;
#                   if 'error' then {errorCode errorMsg}
#       
# Results:
#       none. UI maybe updated, jids may be auto browsed.

proc ::Jabber::Browse::Callback {browseName type jid subiq} {
    
    variable wtop
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    ::Jabber::Debug 2 "::Jabber::Browse::Callback browseName=$browseName, type=$type,\
      jid=$jid, subiq='[string range $subiq 0 30] ...'"

    ::Jabber::Browse::ControlArrows -1

    switch -- $type {
	error {
	    
	    # Shall we be silent? 
	    if {[winfo exists $wtop]} {
		tk_messageBox -type ok -icon error \
		  -message [FormatTextForMessageBox  \
		  [::msgcat::mc jamesserrbrowse $jid [lindex $subiq 1]]]
	    }
	}
	set {
    
	    # It is at this stage we are confident that a Browser page is needed.
	    if {[string equal $jid $jserver(this)]} {
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
		    set category [wrapper::getattr [lindex $child 1] category]
		    if {[string equal $category "conference"]} {
			set isConference 1
		    }
		}
		if {$isConference} {
		    catch {unset cattrArr}
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
			if {[info exists cattrArr(type)] &&   \
			  $cattrArr(type) == "public"} {
			    ::Jabber::Browse::Get $confjid -silent 1
			}
		    }
		}
	    }
	}
    }
}

# Jabber::Browse::DispatchUsers --
#
#       Find any <user> element and send to groupchat.

proc ::Jabber::Browse::DispatchUsers {jid subiq} {

    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Browse::DispatchUsers jid=$jid,\
      subiq='[string range $subiq 0 30] ...'"
    
    # Find any <user> elements.
    if {[string equal [lindex $subiq 0] "user"]} {
	::Jabber::GroupChat::BrowseUser $subiq
    }
    foreach child [wrapper::getchildren $subiq] {
	if {[string equal [lindex $child 0] "user"]} {
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

    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jerror jerror
    
    ::Jabber::Debug 2 "::Jabber::Browse::ErrorProc type=$type, jid=$jid, errlist='$errlist'"

    ::Jabber::Browse::ControlArrows 0
    
    # If we got an error browsing an actual server, then remove from list.
    set ind [lsearch -exact $jprefs(browseServers) $jid]
    if {$ind >= 0} {
	set jprefs(browseServers) [lreplace $jprefs(browseServers) $ind $ind]
    }
    
    # Silent...
    if {$silent} {
	lappend jerror [list [clock format [clock seconds] -format "%H:%M:%S"] \
	  $jid  \
	  "Failed browsing: Error code [lindex $errlist 0] and message:\
	  [lindex $errlist 1]"]
    } else {
	tk_messageBox -icon error -type ok -title [::msgcat::mc Error] \
	  -message [FormatTextForMessageBox \
	  [::msgcat::mc jamesserrbrowse $jid [lindex $errlist 1]]]
    }
    
    # As a fallback we use the agents method instead if browsing the login
    # server fails.
    if {[string equal $jid $jserver(this)]} {
	::Jabber::Agents::GetAll
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
    global  this sysFont prefs

    variable wtop

    if {[winfo exists $w]} {
	return
    }
    set wtop $w
    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w {Jabber Browser}
    wm protocol $w WM_DELETE_WINDOW [list ::Jabber::Browse::CloseDlg $w]
    
    # Toplevel menu for mac only. Only when multiinstance.
    if {0 && [string match "mac*" $this(platform)]} {
	$w configure -menu [::Jabber::UI::GetRosterWmenu]
    }
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    
    message $w.frall.msg -width 220 -font $sysFont(sb) -anchor w -text \
      {Services that are available on each Jabber server listed.}
    message $w.frall.msg2 -width 220 -font $sysFont(s) -anchor w -text  \
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
    global  this sysFont prefs
    
    variable wtree
    variable wtreecanvas
    variable wsearrows
    variable wtop
    variable btaddserv
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::Browse::Build"
    
    # The frame.
    frame $w -borderwidth 0 -relief flat
    set wbrowser $w
    
    set frbot [frame $w.frbot -bd 0]
    set wsearrows $frbot.arr        
    pack [::chasearrows::chasearrows $wsearrows -background gray87 -size 16] \
      -side left -padx 5 -pady 0
    pack $frbot -side bottom -fill x -padx 8 -pady 2
    
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
      -selectcommand ::Jabber::Browse::SelectCmd   \
      -opencommand ::Jabber::Browse::OpenTreeCmd   \
      -highlightcolor #6363CE -highlightbackground $prefs(bgColGeneral)
    set wtreecanvas [$wtree getcanvas]
    if {[string match "mac*" $this(platform)]} {
	$wtree configure -buttonpresscommand  \
	  [list ::Jabber::UI::Popup browse]
    } else {
	$wtree configure -rightclickcommand  \
	  [list ::Jabber::UI::Popup browse]
    }
    grid $wtree -row 0 -column 0 -sticky news
    grid $wysc -row 0 -column 1 -sticky ns
    grid $wxsc -row 1 -column 0 -sticky ew
    grid columnconfigure $wbox 0 -weight 1
    grid rowconfigure $wbox 0 -weight 1
        
    # All tree content is set from browse callback from the browse object.
    
    return $w
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
    variable wtreecanvas
    variable options
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::nsToText nsToText
    upvar ::UI::icons icons
    
    ::Jabber::Debug 2 "::Jabber::Browse::AddToTree parentsJidList='$parentsJidList', jid=$jid"

    set category [lindex $xmllist 0]
    array set attrArr [lindex $xmllist 1]
    if {[string equal $category "item"] && [info exists attrArr(category)]} {
	set category $attrArr(category)
    }

    if {$options(-setbrowsedjid)} {}
    
    switch -exact -- $category {
	ns {
	    
	    # outdated !!!!!!!!!
	    if {0} {
		set ns [lindex $xmllist 3]
		set txt $ns
		if {[info exists nsToText($ns)]} {
		    set txt $nsToText($ns)
		}
		
		# Namespaces indicate supported feature.
		$wtree newitem [concat $parentsJidList [lindex $xmllist 3]]  \
		  -text $txt -dir 0
	    }
	}
	default {
    
	    # If the 'jid' is empty we get it from our attributes!
	    if {[string length $jid] == 0} {
		set jid $attrArr(jid)
	    }
	    set jidList [concat $parentsJidList $jid]
	    set allChildren [wrapper::getchildren $xmllist]
	    
	    ::Jabber::Debug 3 "   jidList='$jidList'"
	    
	    if {[info exists attrArr(type)] && [string equal $attrArr(type) "remove"]} {
		
		# Remove this jid from tree widget.
		foreach v [$wtree find withtag $jid] {
		    $wtree delitem $v
		}
	    } elseif {$options(-setbrowsedjid) || !$browsedjid} {
		
		# Set this jid in tree widget.
		set txt $jid
		if {[info exists attrArr(name)]} {
		    set txt $attrArr(name)
		}
		
		# If three-tier jid, then dead-end.
		# Note: it is very unclear how to determine if dead-end without
		# an additional browse of that jid.
		# This is very ad hoc!!!
		if {[regexp {.+@[^/]+/.*} $jid match]} {
		    if {[string equal $category "user"]} {
			$wtree newitem $jidList -dir 0  \
			  -text $txt -image $icons(machead) -tags $jid
		    } else {
			$wtree newitem $jidList -text $txt -tags $jid
		    }
		} elseif {[string equal $category "service"]} {
		    $wtree newitem $jidList -text $txt -tags $jid -style bold
		} else {
		    
		    # This is a service, transport, room, etc.
		    set isOpen [expr [llength $allChildren] ? 1 : 0]
		    $wtree newitem $jidList -dir 1 -open $isOpen -text $txt \
		      -tags $jid
		}
		set typesubtype [$jstate(browse) gettype $jid]
		set jidtxt $jid
		if {[string length $jid] > 30} {
		    set jidtxt "[string range $jid 0 28]..."
		}
		set msg "jid: $jidtxt\ntype: $typesubtype"
		::balloonhelp::balloonforcanvas $wtreecanvas $jid $msg
	    }
	    
	    # If any child elements, call ourself recursively.
	    foreach child $allChildren {
		::Jabber::Browse::AddToTree $jidList {} $child
	    }
	}
    }
}

# Jabber::Browse::Presence --
#
#       Sets the presence of the (<user>) jid in our browse tree.
#
# Arguments:
#       jid  
#       presence    "available", "unavailable", or "unsubscribed"
#       args        list of '-key value' pairs of presence attributes.
#       
# Results:
#       browse tree icon updated.

proc ::Jabber::Browse::Presence {jid presence args} {
    
    variable wtree
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::Browse::Presence jid=$jid, presence=$presence, args='$args'"

    array set argsArr $args
            
    if {![winfo exists $wtree]} {
	return
    }
    set jidhash ${jid}/$argsArr(-resource)
    set parentList [$jstate(browse) getparents $jidhash]
    set jidList [concat $parentList $jidhash]
    if {![$wtree isitem $jidList]} {
	return
    }
    if {$presence == "available"} {
    
	# Add first if not there?    
	set icon [eval {::Jabber::Roster::GetPresenceIcon $jidhash $presence} $args]
	$wtree itemconfigure $jidList -image $icon
    } elseif {$presence == "unavailable"} {

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
#       .

proc ::Jabber::Browse::OpenTreeCmd {w v} {
    
    variable wsearrows
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Browse::OpenTreeCmd v=$v"

    if {[llength $v]} {
	set jid [lindex $v end]
	
	# If we have not yet browsed this jid, do it now!
	if {![$jstate(browse) isbrowsed $jid]} {
	    ::Jabber::Browse::ControlArrows 1
	    
	    # Browse services available.
	    ::Jabber::Browse::Get $jid
	}
    }    
}

proc ::Jabber::Browse::Refresh {jid} {
    
    variable wtree    
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Browse::Refresh jid=$jid"
        
    # Clear internal state of the browse object for this jid.
    $jstate(browse) clear $jid
    
    # Remove all children of this jid from browse tree.
    foreach v [$wtree find withtag $jid] {
	$wtree delitem $v -childsonly 1
    }
    
    # Browse once more, let callback manage rest.
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

    ::Jabber::Debug 2 "::Jabber::Browse::Clear"
    
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
    global  this sysFont prefs
    
    variable finishedAdd -1

    set w .jaddsrv
    if {[winfo exists $w]} {
	return
    }
    set finishedAdd 0
    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w [::msgcat::mc {Add Server}]
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    message $w.frall.msg -width 220 -font $sysFont(s) -text \
      [::msgcat::mc jabrowseaddserver]
    entry $w.frall.ent -width 24   \
      -textvariable "[namespace current]::addserver"
    pack $w.frall.msg $w.frall.ent -side top -fill x -anchor w -padx 10  \
      -pady 4

    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btadd -text [::msgcat::mc Add] -width 8 -default active \
      -command [list [namespace current]::DoAddServer $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
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
    focus $oldFocus
    return [expr {($finishedAdd <= 0) ? "cancel" : "add"}]
}

proc ::Jabber::Browse::DoAddServer {w} {
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

#-------------------------------------------------------------------------------
