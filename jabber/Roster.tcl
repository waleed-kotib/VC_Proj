#  Roster.tcl ---
#  
#      This file is part of the whiteboard application. 
#      It implements the Roster GUI part.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
# $Id: Roster.tcl,v 1.23 2003-11-15 07:33:48 matben Exp $

package provide Roster 1.0

namespace eval ::Jabber::Roster:: {
    
    variable wtree    
    variable servtxt
    
    # A unique running identifier.
    variable uid 0
    
    # Use a unique canvas tag in the tree widget for each jid put there.
    # This is needed for the balloons that need a real canvas tag, and that
    # we can't use jid's for this since they may contain special chars (!)!
    variable treeuid 0
    
    # Mapping from presence/show to icon. 
    # Specials for whiteboard clients and foreign IM systems.
    # It is unclear if <show>online</show> is allowed.
    variable presenceIcon
    array set presenceIcon [list                         \
      {available}         [::UI::GetIcon machead]        \
      {unavailable}       [::UI::GetIcon macheadgray]    \
      {chat}              [::UI::GetIcon macheadtalk]    \
      {away}              [::UI::GetIcon macheadaway]    \
      {xa}                [::UI::GetIcon macheadunav]    \
      {dnd}               [::UI::GetIcon macheadsleep]   \
      {online}            [::UI::GetIcon machead]        \
      {invisible}         [::UI::GetIcon macheadinv]     \
      {subnone}           [::UI::GetIcon questmark]      \
      {available,wb}      [::UI::GetIcon macheadwb]      \
      {unavailable,wb}    [::UI::GetIcon macheadgraywb]  \
      {chat,wb}           [::UI::GetIcon macheadtalkwb]  \
      {away,wb}           [::UI::GetIcon macheadawaywb]  \
      {xa,wb}             [::UI::GetIcon macheadunavwb]  \
      {dnd,wb}            [::UI::GetIcon macheadsleepwb] \
      {online,wb}         [::UI::GetIcon macheadwb]      \
      {invisible,wb}      [::UI::GetIcon macheadinvwb]   \
      {subnone,wb}        [::UI::GetIcon questmarkwb]    \
      {available,aim}     [::UI::GetIcon aim_online]     \
      {unavailable,aim}   [::UI::GetIcon aim_offline]    \
      {chat,aim}          [::UI::GetIcon aim_online]     \
      {dnd,aim}           [::UI::GetIcon aim_dnd]        \
      {away,aim}          [::UI::GetIcon aim_away]       \
      {xa,aim}            [::UI::GetIcon aim_xa]         \
      {online,aim}        [::UI::GetIcon aim_online]     \
      {available,icq}     [::UI::GetIcon icq_online]     \
      {unavailable,icq}   [::UI::GetIcon icq_offline]    \
      {chat,icq}          [::UI::GetIcon icq_online]     \
      {dnd,icq}           [::UI::GetIcon icq_dnd]        \
      {away,icq}          [::UI::GetIcon icq_away]       \
      {xa,icq}            [::UI::GetIcon icq_xa]         \
      {online,icq}        [::UI::GetIcon icq_online]     \
      {available,msn}     [::UI::GetIcon msn_online]     \
      {unavailable,msn}   [::UI::GetIcon msn_offline]    \
      {chat,msn}          [::UI::GetIcon msn_online]     \
      {dnd,msn}           [::UI::GetIcon msn_dnd]        \
      {away,msn}          [::UI::GetIcon msn_away]       \
      {xa,msn}            [::UI::GetIcon msn_xa]         \
      {online,msn}        [::UI::GetIcon msn_online]     \
      {available,yahoo}   [::UI::GetIcon yahoo_online]   \
      {unavailable,yahoo} [::UI::GetIcon yahoo_offline]  \
      {chat,yahoo}        [::UI::GetIcon yahoo_online]   \
      {dnd,yahoo}         [::UI::GetIcon yahoo_dnd]      \
      {away,yahoo}        [::UI::GetIcon yahoo_away]     \
      {xa,yahoo}          [::UI::GetIcon yahoo_xa]       \
      {online,yahoo}      [::UI::GetIcon yahoo_online]   \
    ]
}

# Jabber::Roster::Show --
#
#       Show the roster window.
#
# Arguments:
#       w      the toplevel window.
#       
# Results:
#       shows window.

proc ::Jabber::Roster::Show {w} {
    upvar ::Jabber::jstate jstate

    if {$jstate(rosterVis)} {
	if {[winfo exists $w]} {
	    catch {wm deiconify $w}
	} else {
	    ::Jabber::Roster::BuildToplevel $w
	}
    } else {
	catch {wm withdraw $w}
    }
}

# Jabber::Roster::BuildToplevel --
#
#       Build the toplevel roster window.
#
# Arguments:
#       w      the toplevel window.
#       
# Results:
#       shows window.

proc ::Jabber::Roster::BuildToplevel {w} {
    global  this sysFont prefs

    variable wtop
    variable servtxt
    upvar ::UI::menuDefs menuDefs

    if {[winfo exists $w]} {
	return
    }
    set wtop $w
    
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
 	::UI::MacUseMainMenu $w
   } else {

    }
    wm title $w {Roster (Contact list)}
    wm protocol $w WM_DELETE_WINDOW [list [namespace current]::CloseDlg $w]
    
    # Toplevel menu for mac only. Only when multiinstance.
    if {0 && [string match "mac*" $this(platform)]} {
	set wmenu ${w}.menu
	menu $wmenu -tearoff 0
	::UI::BuildAppleMenu $wtop ${wmenu}.apple normal
	::UI::NewMenu $w ${wmenu}.file    mFile    $menuDefs(min,file)     normal
	::UI::NewMenu $w ${wmenu}.edit    mEdit    $menuDefs(min,edit)     normal
	::UI::NewMenu $w ${wmenu}.jabber  mJabber  $menuDefs(main,jabber)  normal
	$w configure -menu ${wmenu}
    }
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
    
    # Top frame for info.
    set frtop $w.frall.frtop
    pack [frame $frtop] -fill x -side top -anchor w -padx 10 -pady 4
    label $frtop.la -text {Connected to:} -font $sysFont(sb)
    label $frtop.laserv -textvariable [namespace current]::servtxt
    pack $frtop.la $frtop.laserv -side left -pady 4
    set servtxt {not connected}

    # And the real stuff.
    pack [::Jabber::Roster::Build $w.frall.br] -side top -fill both -expand 1
    
    wm maxsize $w 320 800
    wm minsize $w 180 240
}

# Jabber::Roster::Build --
#
#       Makes mega widget to show the roster.
#
# Arguments:
#       w           frame window with everything.
#       
# Results:
#       w

proc ::Jabber::Roster::Build {w} {
    global  sysFont this wDlgs prefs
        
    variable wtree    
    variable servtxt
    variable btedit
    variable btremove
    variable btrefresh
    variable selItem
    upvar ::Jabber::jprefs jprefs
        
    # The frame.
    frame $w -borderwidth 0 -relief flat

    # Tree frame with scrollbars.
    set wbox $w.box
    pack [frame $wbox -border 1 -relief sunken]   \
      -side top -fill both -expand 1 -padx 6 -pady 6
    set wtree $wbox.tree
    set wxsc $wbox.xsc
    set wysc $wbox.ysc
    set opts {}
    if {$jprefs(rost,useBgImage)} {
	lappend opts -backgroundimage $jprefs(rost,bgImage)
    }
    set wtree [eval {::tree::tree $wtree -width 180 -height 300 -silent 1  \
      -openicons triangle -treecolor {} -scrollwidth 400  \
      -xscrollcommand [list $wxsc set]       \
      -yscrollcommand [list $wysc set]       \
      -selectcommand [namespace current]::SelectCmd   \
      -doubleclickcommand [namespace current]::DoubleClickCmd   \
      -highlightcolor #6363CE -highlightbackground $prefs(bgColGeneral)} $opts]

    if {[string match "mac*" $this(platform)]} {
	$wtree configure -buttonpresscommand [list ::Jabber::UI::Popup roster] \
	  -eventlist [list [list <Control-Button-1> [list ::Jabber::UI::Popup roster]]]
    } else {
	$wtree configure -rightclickcommand  \
	  [list ::Jabber::UI::Popup roster]
    }

    scrollbar $wxsc -orient horizontal -command [list $wtree xview]
    scrollbar $wysc -orient vertical -command [list $wtree yview]
    grid $wtree -row 0 -column 0 -sticky news
    grid $wysc -row 0 -column 1 -sticky ns
    grid $wxsc -row 1 -column 0 -sticky ew
    grid columnconfigure $wbox 0 -weight 1
    grid rowconfigure $wbox 0 -weight 1    
    
    # Add main tree dirs.
    foreach gpres $jprefs(treedirs) {
	$wtree newitem [list $gpres] -dir 1 -text [::msgcat::mc $gpres] \
	  -tags head
    }
    foreach gpres $jprefs(closedtreedirs) {
	$wtree itemconfigure [list $gpres] -open 0
    }
    return $w
}

proc ::Jabber::Roster::SetBackgroundImage {useBgImage bgImagePath} {
    upvar ::Jabber::jprefs jprefs
    variable wtree    
    
    if {[winfo exists $wtree]} {
	
	# Change only if needed.
	if {($jprefs(rost,useBgImage) != $useBgImage) || \
	  ($jprefs(rost,bgImagePath) != $bgImagePath)} {
	    
	    # Cleanup old.
	    if {$jprefs(rost,bgImage) != ""} {
		image delete $jprefs(rost,bgImage)
	    }
	    if {$jprefs(rost,useBgImage)} {
		set jprefs(rost,bgImage)  \
		  [image create photo -file $jprefs(rost,bgImagePath)]
	    } else {
		set jprefs(rost,bgImage) {}
	    }
	    $wtree configure -backgroundimage $jprefs(rost,bgImage)
	}
    }
}

proc ::Jabber::Roster::CloseDlg {w} {    
    upvar ::Jabber::jstate jstate

    catch {wm withdraw $w}
    set jstate(rosterVis) 0
}

proc ::Jabber::Roster::Refresh { } {
    upvar ::Jabber::jstate jstate

    # Get my roster.
    $jstate(jlib) roster_get [namespace current]::PushProc
}

# Jabber::Roster::SendRemove --
#
#       Method to remove another user from my roster.
#
#

proc ::Jabber::Roster::SendRemove {jidrm} {    
    variable selItem
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::Roster::SendRemove jidrm=$jidrm"

    if {[string length $jidrm]} {
	set jid $jidrm
    } else {
	set jid [lindex $selItem end]
    }
    set ans [tk_messageBox -title [::msgcat::mc {Remove Item}] -message  \
      [FormatTextForMessageBox [::msgcat::mc jamesswarnremove]]  \
      -icon warning -type yesno]
    if {[string equal $ans "yes"]} {
	$jstate(jlib) roster_remove $jid [namespace current]::PushProc
    }
}

# Jabber::Roster::SelectCmd --
#
#       Callback when selecting roster item in tree.
#
# Arguments:
#       w           tree widget
#       v           tree item path
#       
# Results:
#       button states set set.

proc ::Jabber::Roster::SelectCmd {w v} {    
    variable btedit
    variable btremove
    variable selItem
    
    # Not used
    return
    
    set selItem $v
    if {[llength $v] && ([$w itemconfigure $v -dir] == 0)} {
	$btedit configure -state normal
	$btremove configure -state normal
    } else {
	$btedit configure -state disabled
	$btremove configure -state disabled
    }
}

# Jabber::Roster::DoubleClickCmd --
#
#       Callback when double clicking roster item in tree.
#
# Arguments:
#       w           tree widget
#       v           tree item path
#       
# Results:
#       button states set set.

proc ::Jabber::Roster::DoubleClickCmd {w v} {
    global  wDlgs
    
    upvar ::Jabber::jprefs jprefs

    if {[llength $v] && ([$w itemconfigure $v -dir] == 0)} {
	
	# According to XMPP def sect. 4.1, we should use user@domain when
	# initiating a new chat or sending a new message that is not a reply.
	set jid [lindex $v end]
	jlib::splitjid $jid jid2 res
	if {[string equal $jprefs(rost,dblClk) "normal"]} {
	    ::Jabber::NewMsg::Build $wDlgs(jsendmsg) -to $jid2
	} else {
	    ::Jabber::Chat::StartThread $jid2
	}
    }    
}

# Jabber::Roster::PushProc --
#
#       Our callback procedure for roster pushes.
#       Populate our roster tree.
#
# Arguments:
#       rostName
#       what        any of "presence", "remove", "set", "enterroster",
#                   "exitroster"
#       jid         'user@server' without any /resource usually.
#                   Some transports keep a resource part in jid.
#       args        list of '-key value' pairs where '-key' can be
#                   -resource, -from, -type...
#       
# Results:
#       updates the roster UI.

proc ::Jabber::Roster::PushProc {rostName what {jid {}} args} {    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "--roster-> rostName=$rostName, what=$what, jid=$jid, \
      args='$args'"

    # Extract the args list as an array.
    array set attrArr $args
        
    switch -- $what {
	presence {
	    
	    # We may get presence 'available' with empty resource (ICQ)!
	    if {![info exists attrArr(-type)]} {
		puts "   Error: no type attribute"
		return
	    }
	    set type $attrArr(-type)
	    set jid3 $jid
	    if {[info exists attrArr(-resource)] &&  \
	      [string length $attrArr(-resource)]} {
		set jid3 ${jid}/$attrArr(-resource)
	    }
	    
	    # Ordinary members should go into our roster, but presence
	    # from groupchat users shall go into the specific groupchat dialog.
	    if {[$jstate(jlib) service isroom $jid]} {
		eval {::Jabber::GroupChat::Presence $jid $type} $args
		
		# What if agent(s) instead???
		# Dont do this unless we've got browsing for this server.		
		if {[::Jabber::Browse::HaveBrowseTree $jid]} {
		    eval {::Jabber::Browse::Presence $jid $type} $args
		}
	    } else {
		eval {::Jabber::Roster::Presence $jid3 $type} $args
	    
	    	# If users shall be automatically browsed to.
	    	if {$jprefs(autoBrowseUsers) &&  \
		  [string equal $type "available"] &&  \
		  ![$jstate(browse) isbrowsed $jid3]} {
		    eval {::Jabber::Roster::AutoBrowse $jid3 $type} \
		      $args
	    	}
	    }
	    
	    # Any noise?
	    eval {::Jabber::Roster::PresenceSounds $jid $type} $args	    
	}
	remove {
	    
	    # Must remove all resources, and jid2 if no resources.
    	    set resList [$jstate(roster) getresources $jid]
	    foreach res $resList {
	        ::Jabber::Roster::Remove ${jid}/${res}
	    }
	    if {$resList == ""} {
	        ::Jabber::Roster::Remove $jid
	    }
	}
	set {
	    eval {::Jabber::Roster::SetItem $jid} $args
	}
	enterroster {
	    set jstate(inroster) 1
	    ::Jabber::Roster::Clear
	}
	exitroster {
	    set jstate(inroster) 0
	    ::Jabber::Roster::ExitRoster
	}
    }
}

# Jabber::Roster::Clear --
#
#       Clears the complete tree from all jid's and all groups.
#
# Arguments:
#       
# Results:
#       clears tree.

proc ::Jabber::Roster::Clear { } {    
    variable wtree    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::Roster::Clear"

    foreach gpres $jprefs(treedirs) {
	$wtree delitem [list $gpres] -childsonly 1
    }
}

proc ::Jabber::Roster::ExitRoster { } {

    ::Jabber::UI::SetStatusMessage [::msgcat::mc jarostupdate]
    
    # Should perhaps fix the directories of the tree widget, such as
    # appending (#items) for each headline.
}

# Jabber::Roster::SetItem --
#
#       Adds a jid item to the tree.
#
# Arguments:
#       jid         2-tier jid with no /resource part usually, not icq/reg.
#       args        list of '-key value' pairs where '-key' can be
#                   -name
#                   -groups   Note, PLURAL!
#                   -ask
#       
# Results:
#       updates tree.

proc ::Jabber::Roster::SetItem {jid args} {    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::Roster::SetItem jid=$jid, args='$args'"
    
    # Remove any old items first:
    # 1) If we 'get' the roster, the roster is cleared, so we can be
    #    sure that we don't have any "old" item???
    # 2) Must remove all resources for this jid first, and then add back.
    #    Remove also jid2.
    if {!$jstate(inroster)} {
    	set resList [$jstate(roster) getresources $jid]
	foreach res $resList {
	    ::Jabber::Roster::Remove ${jid}/${res}
	}
	if {$resList == ""} {
	    ::Jabber::Roster::Remove $jid
	}
    }
    
    set doAdd 1
    if {!$jprefs(rost,allowSubNone)} {
	
	# Do not add items with subscription='none'.
	set ind [lsearch $args "-subscription"]
	if {($ind >= 0) && [string equal [lindex $args [expr $ind+1]] "none"]} {
	    set doAdd 0
	}
    }
    
    if {$doAdd} {
    
	# We get a sublist for each resource. IMPORTANT!
	# Add all resources for this jid?
	jlib::splitjid $jid jid2 res
	set presenceList [$jstate(roster) getpresence $jid2]
	::Jabber::Debug 2 "      presenceList=$presenceList"
	
	foreach pres $presenceList {
	    catch {unset presArr}
	    array set presArr $pres
	    
	    # Put in our roster tree.
	    eval {::Jabber::Roster::PutItemInTree $jid $presArr(-type)} \
	      $args $pres
	}
    }
}

# Jabber::Roster::Presence --
#
#       Sets the presence of the jid in our UI.
#
# Arguments:
#       jid         3-tier jid usually but can be a 2-tier jid if ICQ...
#       presence    "available", "unavailable", or "unsubscribed"
#       args        list of '-key value' pairs of presence attributes.
#       
# Results:
#       roster tree updated.

proc ::Jabber::Roster::Presence {jid presence args} {    
    upvar ::Jabber::jidToIP jidToIP
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::Roster::Presence jid=$jid, presence=$presence, args='$args'"
    array set argsArr $args

    # All presence have a 3-tier jid as 'from' attribute:
    # presence = 'available'   => remove jid2 + jid3,  add jid3
    # presence = 'unavailable' => remove jid2 + jid3,  add jid2
    # Wrong! We may have 2-tier jids from transports:
    # <presence from='user%hotmail.com@msn.myserver' ...
    # Or 3-tier (icq) with presence = 'unavailable' !
    
    jlib::splitjid $jid jid2 res
    
    # This gets a list '-name ... -groups ...' etc. from our roster.
    set itemAttr [$jstate(roster) getrosteritem $jid2]
    if {$itemAttr == ""} {
	# Needed for icq transports etc.
	set jid3 $jid2/$argsArr(-resource)
	set itemAttr [$jstate(roster) getrosteritem $jid3]
    }
    
    # First remove if there, then add in the right tree dir.
    ::Jabber::Roster::Remove $jid
    
    # Put in our roster tree.
    if {[string equal $presence "unsubscribed"]} {
	set treePres "unavailable"
	if {$jprefs(rost,rmIfUnsub)} {
	    
	    # Must send a subscription remove here to get rid if it completely??
	    # Think this is already been made from our presence callback proc.
	    #$jstate(jlib) roster_remove $jid ::Jabber::Roster::PushProc
	} else {
	    eval {::Jabber::Roster::PutItemInTree $jid2 $treePres} \
	      $itemAttr $args
	}
    } else {
	set treePres $presence
	eval {::Jabber::Roster::PutItemInTree $jid2 $treePres} $itemAttr $args
    }
    if {[string equal $treePres "unavailable"]} {
	
	# Need to remove our cached ip number for this jid.
	catch {unset jidToIP($jid)}
    }
}

# Jabber::Roster::Remove --
#
#       Removes a jid item from all groups in the tree.
#
# Arguments:
#       jid         can be 2-tier or 3-tier jid!
#       
# Results:
#       updates tree.

proc ::Jabber::Roster::Remove {jid} {    
    variable wtree    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::Roster::Remove, jid=$jid"
    
    # If have 3-tier jid:
    #    presence = 'available'   => remove jid2 + jid3
    #    presence = 'unavailable' => remove jid2 + jid3
    # Else if 2-tier jid:  => remove jid2
    
    jlib::splitjid $jid jid2 res

    foreach v [$wtree find withtag $jid2] {
	$wtree delitem $v
	
	# Remove dirs if empty?
	set vparent [lrange $v 0 end-1]
	if {[llength $v] == 3} {
	    if {[llength [$wtree children $vparent]] == 0} {
		$wtree delitem [lrange $v 0 1]
	    }
	}
    }
    if {[string length $res] > 0} {
	
	# We've got a 3-tier jid.
	set jid3 $jid
	foreach v [$wtree find withtag $jid3] {
	    $wtree delitem $v
	    set vparent [lrange $v 0 end-1]
	    if {[llength $v] == 3} {
		if {[llength [$wtree children $vparent]] == 0} {
		    $wtree delitem [lrange $v 0 1]
		}
	    }
	}
    }
}

# Jabber::Roster::AutoBrowse --
# 
#       If presence from user browse that user including its resource.
#       
# Arguments:
#       jid:        
#       presence    "available" or "unavailable"

proc ::Jabber::Roster::AutoBrowse {jid presence args} {    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::Roster::AutoBrowse jid=$jid, presence=$presence, args='$args'"

    array set argsArr $args
    
    if {[string equal $presence "available"]} {   
	
	# Browse only potential Coccinella (all jabber) clients.
	regexp {^(.+@)?([^@/]+)(/.*)?} $jid match pre host
	set type [$jstate(jlib) service gettype $host]
	
	# We may not yet have browsed this (empty).
	if {($type == "") || ($type == "service/jabber")} {
	    $jstate(jlib) browse_get $jid  \
	      -errorcommand [list ::Jabber::Browse::ErrorProc 1]  \
	      -command [list [namespace current]::AutoBrowseCallback]
	}
    } elseif {[string equal $presence "unavailable"]} {
	$jstate(browse) clear $jid
    }
}

# Jabber::Roster::AutoBrowseCallback --
# 
#       The intention here is to signal which services a particular client
#       supports to the UI. If coccinella, for instance.
#       
# Arguments:
#       jid:        

proc ::Jabber::Roster::AutoBrowseCallback {browseName type jid subiq} {    
    variable wtree    
    variable presenceIcon
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::Roster::AutoBrowseCallback, jid=$jid,\
      [string range "subiq='$subiq'" 0 40]..."
    
    if {[$jstate(browse) havenamespace $jid "coccinella:wb"]} {
	
	# Shall we query for its ip address right away?
	if {$jprefs(preGetIP)} {
	    ::Jabber::GetIPnumber $jid
	}
	
	if {[regexp {^(.+@[^/]+)/(.+)$} $jid match jid2 res]} {
	    set presArr(-show) "normal"
	    array set presArr [$jstate(roster) getpresence $jid2 -resource $res]
	    
	    # If available and show = ( normal | empty | chat ) display icon.
	    if {![string equal $presArr(-type) "available"]} {
		return
	    }
	    switch -- $presArr(-show) {
		normal {
		    set icon $presenceIcon(available,wb)
		}
		chat {
		    set icon $presenceIcon(chat,wb)
		}
		default {
		    return
		}
	    }
	    
	    array set rostArr [$jstate(roster) getrosteritem $jid2]
	    
	    if {[info exists rostArr(-groups)] &&  \
	      [string length $rostArr(-groups)]} {
		set groups $rostArr(-groups)
		foreach grp $groups {
		    $wtree itemconfigure [list Online $grp $jid] -image $icon
		}
	    } else {
		
		# No groups associated with this item.
		$wtree itemconfigure [list Online $jid] -image $icon
	    }	    
	}
    }
}

# Jabber::Roster::PutItemInTree --
#
#       Sets the jid in the correct place in our roster tree.
#       Online users shall be put with full 3-tier jid.
#       Offline and other are stored with 2-tier jid with no resource.
#
# Arguments:
#       jid         2-tier jid, or 3-tier for icq etc.
#       presence    "available" or "unavailable"
#       args        list of '-key value' pairs of presence and roster
#                   attributes.
#       
# Results:
#       roster tree updated.

proc ::Jabber::Roster::PutItemInTree {jid presence args} {    
    variable wtree    
    variable treeuid
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::mapShowElemToText mapShowElemToText
    
    ::Jabber::Debug 3 "::Jabber::Roster::PutItemInTree jid=$jid, presence=$presence, args='$args'"

    array set argsArr $args
    array set gpresarr {available Online unavailable Offline}
    
    jlib::splitjid $jid jid2 res

    # Format item:
    #  - If 'name' attribute, use this, else
    #  - if user belongs to login server, use only prefix, else
    #  - show complete 2-tier jid
    # If resource add it within parenthesis '(presence)' but only if Online.
    # 
    # For Online users, the tree item must be a 3-tier jid with resource 
    # since a user may be logged in from more than one resource.
    # Note that some (icq) transports have 3-tier items that are unavailable!
    
    if {[info exists argsArr(-name)] && ($argsArr(-name) != "")} {
	set itemTxt $argsArr(-name)
    } elseif {[regexp "^(\[^@\]+)@$jserver(this)" $jid match user]} {
	set itemTxt $user
    } else {
	set itemTxt $jid2
    }
    set jidx $jid
    if {[string equal $presence "available"]} {
	if {[info exists argsArr(-resource)] && ($argsArr(-resource) != "")} {
	    append itemTxt " ($argsArr(-resource))"
	    set jidx ${jid2}/$argsArr(-resource)
	}
    }
    ::Jabber::Debug 5 "\tjidx=$jidx"
    
    set treectag item[incr treeuid]    
    set itemOpts [list -text $itemTxt -canvastags $treectag]    
    set icon [eval {::Jabber::Roster::GetPresenceIcon $jidx $presence} $args]
	
    # If we have an ask attribute, put in Pending tree dir.
    if {[info exists argsArr(-ask)] &&  \
      [string equal $argsArr(-ask) "subscribe"]} {
	eval {$wtree newitem [list {Subscription Pending} $jid]  \
	  -image $icon -tags $jidx} $itemOpts
    } elseif {[info exists argsArr(-groups)] && ($argsArr(-groups) != "")} {
	set groups $argsArr(-groups)
	
	# Add jid for each group.
	foreach grp $groups {
	    
	    # Make group if not exists already.
	    set childs [$wtree children [list $gpresarr($presence)]]
	    if {[lsearch -exact $childs $grp] < 0} {
		$wtree newitem [list $gpresarr($presence) $grp] -dir 1 \
		  -tags group
	    }
	    eval {$wtree newitem [list $gpresarr($presence) $grp $jidx] \
	      -image $icon -tags $jidx} $itemOpts
	}
    } else {
	
	# No groups associated with this item.
	eval {$wtree newitem [list $gpresarr($presence) $jidx] \
	  -image $icon -tags $jidx} $itemOpts
    }
    
    # Design the balloon help window message.
    if {[info exists argsArr(-name)] && [string length $argsArr(-name)]} {
	set msg "$argsArr(-name): $gpresarr($presence)"
    } else {
	set msg "${jidx}: $gpresarr($presence)"
    }
    if {[string equal $presence "available"]} {
	set delay [$jstate(roster) getx $jidx "jabber:x:delay"]
	if {$delay != ""} {
	    
	    # An ISO 8601 point-in-time specification. clock works!
	    set stamp [wrapper::getattribute $delay stamp]
	    set tstr [::Utils::SmartClockFormat [clock scan $stamp]]
	    append msg "\nOnline since: $tstr"
	}
	if {[info exists argsArr(-show)]} {
	    set show $argsArr(-show)
	    if {[info exists mapShowElemToText($show)]} {
		append msg "\n$mapShowElemToText($show)"
	    } else {
		append msg "\n$show"
	    }
	}
    }
    if {[info exists argsArr(-status)]} {
	append msg "\n$argsArr(-status)"
    }
    
    ::balloonhelp::balloonfortree $wtree $treectag $msg
}

namespace eval ::Jabber::Roster:: {
    
    variable menuDefTrpt
    variable allTransports
    
    # name description ...
    set menuDefTrpt {
	jabber    {Jabber address}
	icq       {ICQ (number)}
	aim       {AIM}
	msn       {MSN Messenger}
	yahoo     {Yahoo Messenger}
	irc       {IRC}
	smtp      {Email address}
    }
    set allTransports {}
    foreach {name spec} $menuDefTrpt {
	lappend allTransports $name
    }
}

# Jabber::Roster::NewOrEditItem --
#
#       
#
# Arguments:
#       which       "new" or "edit"
#       args      -jid theJid
#       
# Results:
#       "cancel" or "add".

proc ::Jabber::Roster::NewOrEditItem {which args} {
    upvar ::Jabber::jstate jstate

    array set argsArr $args
    
    # Some transports (icq) have a jid = icq.jabber.se/registered
    # in the roster, but where we get the 2-tier part. Get 3-tier jid.
    set isTransport 0
    if {[info exists argsArr(-jid)]} {
	set jid $argsArr(-jid)
	if {[regexp {^([^@]+)$} $jid match host]} {
	    set jabbers [$jstate(jlib) service gettransportjids jabber]
	    if {[lsearch $jabbers $host] == -1} {
		
		# This is not a jabber host. Get true roster item.
		#puts "jid=$jid, host=$host"
		set isTransport 1
		set subtype "unknown"
		set users [$jstate(roster) getusers]
		set jid [lsearch -inline -glob $users ${host}*]
		set subscription [$jstate(roster) getsubscription $jid]
		set typesubtype [$jstate(jlib) service gettype $host]
		regexp {^[^/]+/(.+)$} $typesubtype match subtype
		#puts "jid=$jid, users=$users, host=$host"
	    }
	}
    }
    if {$isTransport} {
	tk_messageBox -icon info -title "Transport Info"  \
	  -message [::msgcat::mc jamessowntrpt $subtype $jid $subscription]
	set ans cancel
    } else {
	set ans [eval {::Jabber::Roster::NewOrEditDlg $which} $args]
    }
    return $ans
}

# Jabber::Roster::NewOrEditDlg --
#
#       Build and shows the roster new or edit item window.
#
# Arguments:
#       which       "new" or "edit"
#       args      -jid theJid
#       
# Results:
#       "cancel" or "add".

proc ::Jabber::Roster::NewOrEditDlg {which args} {
    global  sysFont this prefs wDlgs

    variable uid
    variable selItem
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    # Initialize the state variable, an array.    
    set token [namespace current]::dlg[incr uid]
    variable $token
    upvar 0 $token dlgstate

    array set argsArr $args
    set w $wDlgs(jrostnewedit)${uid}
    set dlgstate(w) $w
    set dlgstate(finishedNew) -1

    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
	::UI::MacUseMainMenu $w
    } else {

    }
	
    # Find all our groups for any jid.
    set allGroups [$jstate(roster) getgroups]    
    set usersGroup "None"
    set name ""
    
    # Initialize dialog variables.
    if {[string equal $which "new"]} {
	wm title $w [::msgcat::mc {Add New User}]
	set jid "userName@$jserver(this)"
	set subscribe 1
	set unsubscribe 0
	set subscription "none"
    } else {
	wm title $w [::msgcat::mc {Edit User}]
	if {[info exists argsArr(-jid)]} {
	    set jid $argsArr(-jid)
	} else {
	    set jid [lindex $selItem end]
	}
	set subscribe 0
	set unsubscribe 0
	set subscription "none"
	
	# We should query our roster object for the present values.
	# Note PLURAL!
	set groups [$jstate(roster) getgroups $jid]
	set theItemOpts [$jstate(roster) getrosteritem $jid]
	foreach {key value} $theItemOpts {
	    set keym [string trimleft $key "-"]
	    set $keym $value
	}
	if {[llength $groups] > 0} {
	    set usersGroup [lindex $groups 0]
	}
	if {$usersGroup == ""} {
	    set usersGroup "None"
	}
    }
    
    # Collect the old subscription so we know if to send a new presence.
    set oldSubscription $subscription
    set oldName $name
    set oldUsersGroup $usersGroup
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 12 -ipady 4
    
    if {[string equal $which "new"]} {
	set msg [::msgcat::mc jarostadd]
    } elseif {[string equal $which "edit"]} {
	set msg [::msgcat::mc jarostset $jid]
    }
    message $w.frall.msg -width 300 -font $sysFont(s) -text $msg
    pack $w.frall.msg -side top -fill both -expand 1

    # Entries etc.
    set frmid [frame $w.frall.frmid -borderwidth 0]
    set frjid [frame $frmid.fjid]
    set wtrptpop $frjid.pop
    set wtrptmenu $wtrptpop.menu
    set wjid $frmid.ejid
    
    label $frjid.ljid -text "[::msgcat::mc {Jabber user id}]:"  \
      -font $sysFont(sb) -anchor e
    label $wtrptpop -bd 2 -relief raised -image [::UI::GetIcon popupbt]
    pack $frjid.ljid $wtrptpop -side left
    
    entry $wjid -width 24 -textvariable $token\(jid)
    label $frmid.lnick -text "[::msgcat::mc {Nick name}]:" -font $sysFont(sb) \
      -anchor e
    entry $frmid.enick -width 24 -textvariable $token\(name)
    label $frmid.lgroups -text "[::msgcat::mc Group]:" -font $sysFont(sb) -anchor e
    
    ::combobox::combobox $frmid.egroups -font $sysFont(s) -width 12  \
      -textvariable $token\(usersGroup)
    eval {$frmid.egroups list insert end} "None $allGroups"
        
    # Bind for popup.
    if {[string equal $which "new"]} {
	bind $wtrptpop <Button-1>  \
	  [list [namespace current]::TrptPopup $token %W %X %Y]
	bind $wtrptpop <ButtonRelease-1> \
	  [list [namespace current]::TrptPopupRelease %W]
    }    
    if {[string equal $which "new"]} {
	checkbutton $frmid.csubs -text "  [::msgcat::mc jarostsub]"  \
	  -variable $token\(subscribe)
    } else {
	
	# Give user an opportunity to subscribe/unsubscribe other jid.
	switch -- $subscription {
	    from - none {
		checkbutton $frmid.csubs -text "  [::msgcat::mc jarostsub]"  \
		  -variable $token\(subscribe)
	    }
	    both - to {
		checkbutton $frmid.csubs -text "  [::msgcat::mc jarostunsub]" \
		  -variable $token\(unsubscribe)
	    }
	}
	
	# Present subscription.
	set frsub $frmid.frsub
	label $frmid.lsub -text "[::msgcat::mc Subscription]:"  \
	  -font $sysFont(sb) -anchor e
	frame $frsub
	foreach val {none to from both} txt {None To From Both} {
	    radiobutton ${frsub}.${val} -text [::msgcat::mc $txt]  \
	      -state disabled  \
	      -variable $token\(subscription) -value $val	      
	    pack $frsub.$val -side left -padx 4
	}
	
	# vCard button.
	set frvcard $frmid.vcard
	frame $frvcard
	pack [label $frvcard.lbl -text "[::msgcat::mc jasubgetvcard]:"  \
	  -font $sysFont(sb)] -side left -padx 2
	pack [button $frvcard.bt -text " [::msgcat::mc {Get vCard}]..."  \
	  -font $sysFont(s) -command [list ::VCard::Fetch .kass {other} $jid]] \
	  -side right -padx 2
    }
    grid $frjid -column 0 -row 0 -sticky e
    grid $wjid -column 1 -row 0 -sticky ew 
    grid $frmid.lnick -column 0 -row 1 -sticky e
    grid $frmid.enick -column 1 -row 1 -sticky ew
    grid $frmid.lgroups -column 0 -row 2 -sticky e
    grid $frmid.egroups -column 1 -row 2 -sticky ew
    
    if {[string equal $which "new"]} {
	grid $frmid.csubs -column 1 -row 3 -sticky w -columnspan 2
    } else {
	grid $frmid.csubs -column 1 -row 3 -sticky w -pady 2 -columnspan 2
	grid $frmid.lsub -column 0 -row 4 -sticky e -pady 2
	grid $frsub -column 1 -row 4 -sticky w -columnspan 2 -pady 2
	grid $frvcard -column 0 -row 5 -sticky e -columnspan 2 -pady 2
    }
    pack $frmid -side top -fill both -expand 1
    if {[string equal $which "edit"]} {
	$frmid.ejid configure -state disabled -bg $prefs(bgColGeneral)
    }
    if {[string equal $which "new"]} {
	focus $frmid.ejid
	$frmid.ejid icursor 0
    }
    
    # Cache state variables for the dialog.
    set dlgstate(jid) $jid
    set dlgstate(name) $name
    set dlgstate(oldName) $oldName
    set dlgstate(usersGroup) $usersGroup
    set dlgstate(oldUsersGroup) $oldUsersGroup
    set dlgstate(subscribe) $subscribe
    set dlgstate(unsubscribe) $unsubscribe
    set dlgstate(subscription) $subscription
    set dlgstate(oldSubscription) $oldSubscription
    set dlgstate(wjid) $wjid
    set dlgstate(wtrptmenu) $wtrptmenu
    set dlgstate(which) $which
    
    # Build transport popup menu.
    ::Jabber::Roster::BuildTrptMenu $token
    
    # Button part.
    if {[string equal $which "edit"]} {
	set bttxt [::msgcat::mc Apply]
    } else {
	set bttxt [::msgcat::mc Add]
    }
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btconn -text $bttxt -default active -width 8 \
      -command [list [namespace current]::EditSet $token]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8   \
      -command [list [namespace current]::Cancel $token]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> [list ::Jabber::Roster::EditSet $token]
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w

    catch {focus $oldFocus}
    set ans [expr {($dlgstate(finishedNew) <= 0) ? "cancel" : "add"}]
    unset dlgstate
    return $ans
}

# Jabber::Roster::BuildTrptMenu,  --
# 
#       Procs for handling the transport popup button in NewOrEditItem.

proc ::Jabber::Roster::BuildTrptMenu {token} {
    variable $token
    upvar 0 $token dlgstate    

    variable menuDefTrpt
    variable allTransports
    upvar ::Jabber::jstate jstate
    
    # We must be indenpendent of method; agent, browse, disco
    set trpts {}
    foreach subtype $allTransports {
	set jids [$jstate(jlib) service gettransportjids $subtype]
	if {[llength $jids]} {
	    lappend trpts $subtype
	    set dlgstate(servicejid,$subtype) [lindex $jids 0]
	}
    }    
    
    # Build popup menu.
    set m [menu $dlgstate(wtrptmenu) -tearoff 0]
    array set menuDefTrptDesc $menuDefTrpt
    foreach name $trpts {
	$m add radiobutton -label $menuDefTrptDesc($name) -value $name  \
	  -variable $token\(popuptrpt)  \
	  -command [list [namespace current]::TrptPopupCmd $token]
    }    
    set dlgstate(popuptrpt) jabber
    $dlgstate(wjid) selection range 0 8
    return $dlgstate(wtrptmenu)
}

proc ::Jabber::Roster::TrptPopup {token w x y} {
    global  this
    variable $token
    upvar 0 $token dlgstate    

    # For some reason does we never get a ButtonRelease event here.
    if {![string equal $this(platform) "unix"]} {
	#$w configure -image [::UI::GetIcon popupbtpush]
    }
    tk_popup $dlgstate(wtrptmenu) [expr int($x)] [expr int($y)]
}

proc ::Jabber::Roster::TrptPopupRelease {w} {
        
    #puts "::Jabber::Roster::TrptPopupRelease"
    #$w configure -image [::UI::GetIcon popupbt]
}

proc ::Jabber::Roster::TrptPopupCmd {token} {
    variable $token
    upvar 0 $token dlgstate    

    set wjid $dlgstate(wjid)
    set popuptrpt $dlgstate(popuptrpt)
        
    # Seems to be necessary to achive any selection.
    focus $wjid

    switch -- $popuptrpt {
	jabber {
	    set dlgstate(jid) "userName@$dlgstate(servicejid,jabber)"
	    $wjid selection range 0 8
	}
	aim {
	    set dlgstate(jid) "userName@$dlgstate(servicejid,aim)"
	    $wjid selection range 0 8
	}
	yahoo {
	    set dlgstate(jid) "userName@$dlgstate(servicejid,yahoo)"
	    $wjid selection range 0 8
	}
	icq {
	    set dlgstate(jid) "screeNumber@$dlgstate(servicejid,icq)"
	    $wjid selection range 0 11
	}
	msn {
	    set dlgstate(jid) "userName%hotmail.com@$dlgstate(servicejid,msn)"
	    $wjid selection range 0 8
	}
    }
}

# Jabber::Roster::Cancel --
#

proc ::Jabber::Roster::Cancel {token} {
    variable $token
    upvar 0 $token dlgstate    

    set dlgstate(finishedNew) 0
    destroy $dlgstate(w)
}

# Jabber::Roster::EditSet --
#
#       The button press command when setting roster name or groups of jid.
#
# Arguments:
#       which       "new" or "edit"
#       
# Results:
#       sends roster set.

proc ::Jabber::Roster::EditSet {token} {    
    variable $token
    upvar 0 $token dlgstate    

    variable selItem
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    set jid $dlgstate(jid)
    set name $dlgstate(name)
    set oldName $dlgstate(oldName)
    set usersGroup $dlgstate(usersGroup)
    set oldUsersGroup $dlgstate(oldUsersGroup)
    set subscribe $dlgstate(subscribe)
    set unsubscribe $dlgstate(unsubscribe)
    set subscription $dlgstate(subscription)
    set oldSubscription $dlgstate(oldSubscription)
    set which $dlgstate(which)
    
    # General checks.
    foreach key {jid name usersGroup} {
	set what $key
	if {[regexp $jprefs(invalsExp) $what match junk]} {
	    tk_messageBox -message [FormatTextForMessageBox  \
	      [::msgcat::mc jamessillegalchar $key $what]] \
	      -icon error -type ok
	    return
	}
    }
    
    # In any case the jid should be well formed.
    if {![::Jabber::IsWellFormedJID $jid]} {
	set ans [tk_messageBox -message [FormatTextForMessageBox  \
	  [::msgcat::mc jamessbadjid $jid]] \
	  -icon error -type yesno]
	if {[string equal $ans "no"]} {
	    return
	}
    }
    
    if {[string equal $which "new"]} {
	
	# Warn if already in our roster.
	set allUsers [$jstate(roster) getusers]
	set ind [lsearch -exact $allUsers $jid]
	if {$ind >= 0} {
	    set ans [tk_messageBox -message [FormatTextForMessageBox  \
	      [::msgcat::mc jamessalreadyinrost $jid]] \
	      -icon error -type yesno]
	    if {[string equal $ans "no"]} {
		return
	    }
	}
	
	# Check the jid we are trying to add.
	if {[regexp {([^@]+)$} $jid match host]} {

	    # Exclude jabber services.
	    set jabbers [$jstate(jlib) service gettransportjids jabber]
	    if {[lsearch $jabbers $host] < 0} {	    
	    
		# If this requires a transport component we must be registered.
		set transport [lsearch -inline -regexp $allUsers "^${host}.*"]
		if {$transport == "" } {
		    
		    # Seems we are not registered.
		    set ans [tk_messageBox -type yesno -icon error  \
		      -message [::msgcat::mc jamessaddforeign $host]]
		    if {$ans == "yes"} {
			set didRegister [::Jabber::GenRegister::BuildRegister  \
			  .jtrptreg -server $host -autoget 1]
			return
		    } else {
			return
		    }
		}
	    }
	}
    }
    set dlgstate(finishedNew) 1
    
    # This is the only (?) situation when a client "sets" a roster item.
    # The actual roster item is pushed back to us, and not set from here.
    set opts {}
    if {[string length $name]} {
	lappend opts -name $name
    }
    if {$usersGroup != $oldUsersGroup} {
    	if {$usersGroup == "None"} {
	    set usersGroup ""
    	}
	lappend opts -groups [list $usersGroup]
    }
    if {[string equal $which "new"]} {
	eval {$jstate(jlib) roster_set $jid   \
	  [list [namespace current]::EditSetCommand $jid]} $opts
    } else {
	eval {$jstate(jlib) roster_set $jid   \
	  [list [namespace current]::EditSetCommand $jid]} $opts
    }
    if {[string equal $which "new"]} {
	
	# Send subscribe request.
	if {$subscribe} {
	    $jstate(jlib) send_presence -type "subscribe" -to $jid \
	      -command [namespace current]::PresError
	}
    } else {
	
	# Send (un)subscribe request.
	if {$subscribe} {
	    $jstate(jlib) send_presence -type "subscribe" -to $jid \
	      -command [namespace current]::PresError
	} elseif {$unsubscribe} {
	    $jstate(jlib) send_presence -type "unsubscribe" -to $jid \
	      -command [namespace current]::PresError
	}
    }
    
    destroy $dlgstate(w)
}

# Jabber::Roster::EditSetCommand --
#
#       This is our callback procedure to the roster set command.
#
# Arguments:
#       jid
#       type        "ok" or "error"
#       args

proc ::Jabber::Roster::EditSetCommand {jid type args} {
    
    if {[string equal $type "error"]} {
	foreach {errcode errmsg} [lindex $args 0] break
	tk_messageBox -icon error -type ok -message [FormatTextForMessageBox \
	  [::msgcat::mc jamessfailsetnick $jid $errcode $errmsg]]
    }	
}

# Jabber::Roster::PresError --
# 
#       Callback when sending presence to user for (un)subscription requests.

proc ::Jabber::Roster::PresError {jlibName type args} {
    upvar ::Jabber::jstate jstate
    
    array set argsArr {
	-from       unknown
	-error      {{} Unknown}
	-from       ""
    }
    array set argsArr $args
    
    ::Jabber::Debug 2 "::Jabber::Roster::PresError type=$type, args=$args"

    if {[string equal $type "error"]} {
	foreach {errcode errmsg} $argsArr(-error) break
	set ans [tk_messageBox -icon error -type yesno -message  \
	  "We received an error when (un)subscribing to $argsArr(-from).\
	  The error is: $errmsg ($errcode).\
	  Do you want to remove it from your roster?"]
	if {$ans == "yes"} {
	    $jstate(jlib) roster_remove $argsArr(-from) [namespace current]::PushProc
	}
    }
}

# Jabber::Roster::SetUIWhen --
#
#       Update the roster buttons etc to reflect the current state.
#
# Arguments:
#       what        any of "connect", "disconnect"
#

proc ::Jabber::Roster::SetUIWhen {what} {    
    variable btedit
    variable btremove
    variable btrefresh
    variable servtxt

    # outdated
    return
    
    switch -- $what {
	connect {
	    $btrefresh configure -state normal
	}
	disconnect {
	    set servtxt {not connected}
	    $btedit configure -state disabled
	    $btremove configure -state disabled
	    $btrefresh configure -state disabled
	}
    }
}

proc ::Jabber::Roster::GetPresenceIconFromKey {key} {
    variable presenceIcon
    
    if {[info exists presenceIcon($key)]} {
	return $presenceIcon($key)
    } else {
	return ""
    }
}

# Jabber::Roster::GetPresenceIcon --
#
#       Returns the image appropriate for 'presence', and any 'show' attribute.
#       If presence is to make sense, the jid shall be a 3-tier jid.

proc ::Jabber::Roster::GetPresenceIcon {jid presence args} {    
    variable presenceIcon
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    array set argsArr $args
    
    ::Jabber::Debug 5 "GetPresenceIcon jid=$jid, presence=$presence, args=$args"
    
    # This gives the basic icons.
    set key $presence
    
    # Then see if any <show/> element
    if {[info exists argsArr(-show)] &&  \
      [info exists presenceIcon($argsArr(-show))]} {
	set key $argsArr(-show)
    } elseif {[info exists argsArr(-subscription)] &&   \
      [string equal $argsArr(-subscription) "none"]} {
	set key "subnone"
    }
    
    # Foreign IM systems.
    set haveForeignIM 0
    if {$jprefs(haveIMsysIcons)} {
	if {[regexp {^(.+@)?([^@/]+)(/.*)?} $jid match pre host]} {
	    set typesubtype [$jstate(jlib) service gettype $host]
	
	    # If empty we have likely not yet browsed etc.
	    if {[string length $typesubtype] > 0} {
		if {[regexp {/(aim|icq|msn|yahoo)} $typesubtype match subtype]} {
		    set haveForeignIM 1
		    if {[info exists presenceIcon($key,$subtype)]} {
			append key ",$subtype"
		    }
		}
	    }
	}
    }   
    
    # If whiteboard:
    if {!$haveForeignIM && [$jstate(browse) isbrowsed $jid]} {
	if {[$jstate(browse) havenamespace $jid "coccinella:wb"]} {
	    append key ",wb"
	}
    }
    
    return $presenceIcon($key)
}
  
proc ::Jabber::Roster::GetMyPresenceIcon { } {
    variable presenceIcon
    upvar ::Jabber::jstate jstate

    return $presenceIcon($jstate(status))
}

# Jabber::Roster::PresenceSounds --
#
#       Makes an alert sound corresponding to the jid's presence status.
#
# Arguments:
#       jid  
#       presence    "available", "unavailable", or "unsubscribed"
#       args        list of '-key value' pairs of presence attributes.
#       
# Results:
#       roster tree updated.

proc ::Jabber::Roster::PresenceSounds {jid presence args} {
    
    array set argsArr $args
    
    # Alert sounds.
    if {[info exists argsArr(-show)] && [string equal $argsArr(-show) "chat"]} {
	::Sounds::PlayWhenIdle statchange
    } elseif {[string equal $presence "available"]} {
	::Sounds::PlayWhenIdle online
    } elseif {[string equal $presence "unavailable"]} {
	::Sounds::PlayWhenIdle offline
    }    
}

# Jabber::Roster::BuildPresenceMenu --
# 
#       Sets presence status. Used in popup only so far.
#       
# Arguments:
#       mt          menu widget
#       
# Results:
#       none.

proc ::Jabber::Roster::BuildPresenceMenu {mt} {
    global  prefs
    variable presenceIcon
    upvar ::Jabber::mapShowTextToElem mapShowTextToElem

    if {$prefs(haveMenuImage)} {
	foreach name {available away dnd invisible unavailable} {
	    $mt add radio -label $mapShowTextToElem($name)  \
	      -variable ::Jabber::jstate(status) -value $name   \
	      -command [list ::Jabber::SetStatus $name]  \
	      -compound left -image $presenceIcon($name)
	}
    } else {
	foreach name {available away dnd invisible unavailable} {
	    $mt add radio -label $mapShowTextToElem($name)  \
	      -variable ::Jabber::jstate(status) -value $name   \
	      -command [list ::Jabber::SetStatus $name]
	}
    }
}

# Jabber::Roster::BuildStatusMenuDef --
# 
#       Builds a menuDef list for the status menu.
#       
# Arguments:
#       
# Results:
#       menuDef list.

proc ::Jabber::Roster::BuildStatusMenuDef { } {
    global  prefs
    variable presenceIcon

    set statMenuDef {}
    if {$prefs(haveMenuImage)} {
	foreach mName {mAvailable mAway mDoNotDisturb  \
	  mExtendedAway mInvisible mNotAvailable}      \
	  name {available away dnd xa invisible unavailable} {
	    lappend statMenuDef [list radio $mName  \
	      [list ::Jabber::SetStatus $name] normal {}  \
	      [list -variable ::Jabber::jstate(status) -value $name  \
	      -compound left -image $presenceIcon($name)]]
	}
	lappend statMenuDef {separator}   \
	  {command mAttachMessage         \
	  {::Jabber::SetStatusWithMessage $wDlgs(jpresmsg)}  normal {}}
    } else {
	foreach mName {mAvailable mAway mDoNotDisturb  \
	  mExtendedAway mInvisible mNotAvailable}      \
	  name {available away dnd xa invisible unavailable} {
	    lappend statMenuDef [list radio $mName  \
	      [list ::Jabber::SetStatus $name] normal {} \
	      [list -variable ::Jabber::jstate(status) -value $name]]
	}
	lappend statMenuDef {separator}   \
	  {command mAttachMessage         \
	  {::Jabber::SetStatusWithMessage $wDlgs(jpresmsg)}  normal {}}
    }
    return $statMenuDef
}

# Jabber::Roster::PostProcessIcons --
# 
#       This is necessary to get icons for foreign IM systems set correctly.
#       Usually we get the roster before we've got browse/agents/disco 
#       info, so we cannot know if an item is an ICQ etc. when putting it
#       into the roster.

proc ::Jabber::Roster::PostProcessIcons { } {
    variable wtree    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver

    if {!$jprefs(haveIMsysIcons)} {
	return
    }
    
    foreach v [$wtree find withtag all] {
	set tags [$wtree itemconfigure $v -tags]
	
	switch -- $tags {
	    "" - head - group {
		# skip
	    } 
	    default {
		set jid [lindex $v end]
		#puts "jid=$jid:"
		
		# Exclude jid's that belong to our login jabber server.
 		if {![string match "*@$jserver(this)*" $jid]} {
		    jlib::splitjid $jid jid2 res
		    set pres [$jstate(roster) getpresence $jid2 -resource $res]
		    array set presArr $pres
		    set icon [eval {GetPresenceIcon $jid $presArr(-type)} $pres]
		    #puts "\t$pres, icon=$icon"
		    $wtree itemconfigure $v -image $icon
		}
	    }
	}	
    }   
}

proc ::Jabber::Roster::ConfigureIcon {v} {

    
    
}

#-------------------------------------------------------------------------------
