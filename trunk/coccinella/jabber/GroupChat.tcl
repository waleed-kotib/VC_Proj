#  GroupChat.tcl ---
#  
#      This file is part of the whiteboard application. 
#      It implements the group chat GUI part.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
# $Id: GroupChat.tcl,v 1.1 2003-04-28 13:22:54 matben Exp $

package provide GroupChat 1.0

# Provides dialog for old-style gc-1.0 groupchat but the rest should work for 
# both groupchat and conference protocols.

namespace eval ::Jabber::GroupChat:: {
      
    # Local stuff
    variable locals
}

# Jabber::GroupChat::AllConference --
#
#       Returns 1 only if all services that provided groupchat also support
#       the 'jabber:iq:conference' protocol. This is implicitly obtained
#       by obtaining version number for the conference component. UGLY!!!

proc ::Jabber::GroupChat::AllConference { } {

    upvar ::Jabber::jstate jstate

    set anyNonConf 0
    foreach confjid [$jstate(jlib) service getjidsfor "groupchat"] {
	if {[info exists jstate(conference,$confjid)] &&  \
	  ($jstate(conference,$confjid) == 0)} {
	    set anyNonConf 1
	    break
	}
    }
    if {$anyNonConf} {
	return 0
    } else {
	return 1
    }
}

# Jabber::GroupChat::UseOriginalConference --
#
#       Ad hoc method for finding out if possible to use the original
#       jabber:iq:conference method (not MUC).

proc ::Jabber::GroupChat::UseOriginalConference {{roomjid {}}} {
    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver

    set ans 0
    if {[string length $roomjid] == 0} {
	if {[::Jabber::Browse::HaveBrowseTree $jserver(this)] &&  \
	  [::Jabber::GroupChat::AllConference]} {
	    set ans 1
	}
    } else {
	
	# Require that conference service browsed and that we have the
	# original jabber:iq:conference
	set confserver [$jstate(browse) getparentjid $roomjid]
	if {[$jstate(browse) isbrowsed $confserver]} {
	    if {$jstate(conference,$confserver)} {
		set ans 1
	    }
	}
    }
    return $ans
}

# Jabber::GroupChat::EnterRoom --
#
#       Dispatch entering a room to either 'groupchat' or 'conference' methods.
#       The 'conference' method requires jabber:iq:browse and jabber:iq:conference
#       
# Arguments:
#       w           toplevel widget
#       args        -server, -roomjid, -autoget
#       
# Results:
#       "cancel" or "enter".

proc ::Jabber::GroupChat::EnterRoom {w args} {

    upvar ::Jabber::jserver jserver
    
    array set argsArr $args
    if {[info exists argsArr(-roomjid)]} {
	set roomjid $argsArr(-roomjid)
    } else {
	set roomjid ""
    }
    if {[::Jabber::GroupChat::UseOriginalConference $roomjid]} {
	set ans [eval {::Jabber::Conference::BuildEnterRoom $w} $args]
    } else {
	set ans [eval {::Jabber::GroupChat::BuildEnter $w} $args]
    }
    return $ans
}

proc ::Jabber::GroupChat::CreateRoom {w args} {

    upvar ::Jabber::jserver jserver

    array set argsArr $args
    if {[info exists argsArr(-roomjid)]} {
	set roomjid $argsArr(-roomjid)
    } else {
	set roomjid ""
    }
    if {[::Jabber::GroupChat::UseOriginalConference $roomjid]} {
	set ans [eval {::Jabber::Conference::BuildCreateRoom $w} $args]
    } else {
	set ans [eval {::Jabber::GroupChat::BuildEnter $w} $args]
    }
    return $ans
}

# Jabber::GroupChat::BuildEnter --
#
#       This is to provide support for the old-style 'groupchat 1.0' protocol
#       which shall be used when not server is being browsed.
#       
# Arguments:
#       w           toplevel widget
#       args        -server, -roomjid, -autoget
#       
# Results:
#       "cancel" or "enter".
     
proc ::Jabber::GroupChat::BuildEnter {w args} {
    global  this sysFont

    variable finishedEnter -1
    variable gchatserver
    variable gchatroom
    variable gchatnick
    upvar ::Jabber::jstate jstate

    set chatservers [$jstate(jlib) service getjidsfor "groupchat"]
    ::Jabber::Debug 2 "::Jabber::GroupChat::BuildEnter args='$args'"
    ::Jabber::Debug 2 "    service getjidsfor groupchat: '$chatservers'"
    
    if {[llength $chatservers] == 0} {
	tk_messageBox -icon error -message [::msgcat::mc jamessnogchat]
	return
    }
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    wm title $w [::msgcat::mc {Enter/Create Room}]
    set gchatroom ""
    set gchatnick ""
    array set argsArr $args

    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 4
        
    set gchatserver [lindex $chatservers 0]
    set frmid $w.frall.mid
    pack [frame $frmid] -side top -fill both -expand 1
    set msg [::msgcat::mc jagchatmsg]
    message $frmid.msg -width 260 -font $sysFont(s) -text $msg
    label $frmid.lserv -text "[::msgcat::mc Servers]:" -font $sysFont(sb) -anchor e
    set wcomboserver $frmid.eserv
    ::combobox::combobox $wcomboserver -font $sysFont(s) -width 18  \
      -textvariable [namespace current]::gchatserver
    eval {$frmid.eserv list insert end} $chatservers
    label $frmid.lroom -text "[::msgcat::mc Room]:" -font $sysFont(sb) -anchor e
    entry $frmid.eroom -width 24    \
      -textvariable "[namespace current]::gchatroom" -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    label $frmid.lnick -text "[::msgcat::mc {Nick name}]:" -font $sysFont(sb) \
      -anchor e
    entry $frmid.enick -width 24    \
      -textvariable "[namespace current]::gchatnick" -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    grid $frmid.msg -column 0 -columnspan 2 -row 0 -sticky ew
    grid $frmid.lserv -column 0 -row 1 -sticky e
    grid $frmid.eserv -column 1 -row 1 -sticky ew 
    grid $frmid.lroom -column 0 -row 2 -sticky e
    grid $frmid.eroom -column 1 -row 2 -sticky ew
    grid $frmid.lnick -column 0 -row 3 -sticky e
    grid $frmid.enick -column 1 -row 3 -sticky ew
    
    if {[info exists argsArr(-roomjid)]} {
	regexp {^([^@]+)@([^/]+)} $argsArr(-roomjid) match gchatroom server
	$wcomboserver configure -state disabled
	$frmid.eroom configure -state disabled
    }
    if {[info exists argsArr(-server)]} {
	set server $argsArr(-server)
	$wcomboserver configure -state disabled
    }
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btconn -text [::msgcat::mc Enter] -width 8 -default active \
      -command [list [namespace current]::DoEnter $w]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btexit -text [::msgcat::mc Cancel] -width 8   \
      -command [list [namespace current]::Cancel $w]]  \
      -side right -padx 5 -pady 5  
    pack $frbot -side bottom -fill x
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    catch {grab $w}
    bind $w <Return> "$frbot.btconn invoke"
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {grab release $w}
    focus $oldFocus
    return [expr {($finishedEnter <= 0) ? "cancel" : "enter"}]
}

proc ::Jabber::GroupChat::Cancel {w} {
    variable finishedEnter
    
    set finishedEnter 0
    destroy $w
}

proc ::Jabber::GroupChat::DoEnter {w} {

    variable finishedEnter
    variable gchatserver
    variable gchatroom
    variable gchatnick
    upvar ::Jabber::jstate jstate
    
    # Verify the fields first.
    if {([string length $gchatserver] == 0) ||  \
      ([string length $gchatroom] == 0) ||  \
      ([string length $gchatnick] == 0)} {
	tk_messageBox -title [::msgcat::mc Warning] -type ok -message \
	  [::msgcat::mc jamessgchatfields]
	return
    }
    set finishedEnter 1
    destroy $w

    $jstate(jlib) groupchat enter ${gchatroom}@${gchatserver} $gchatnick \
      -command [namespace current]::EnterCallback
}

proc ::Jabber::GroupChat::EnterCallback {jlibName type args} {
    
    if {[string equal $type "error"]} {
	array set argsArr $args
	set msg "We got an error when entering room \"$argsArr(-from)\"."
	if {[info exists argsArr(-error)]} {
	    foreach {errcode errmsg} $argsArr(-error) { break }
	    append msg " The error code is $errcode: $errmsg"
	}
	tk_messageBox -title "Error Enter Room" -message $msg
    }
}

# Jabber::GroupChat::GotMsg --
#
#       Just got a group chat message. Fill in message in existing dialog.
#       If no dialog, make a freash one.
#       
# Arguments:
#       body        the text message.
#       args        ?-key value? pairs
#       
# Results:
#       updates UI.

proc ::Jabber::GroupChat::GotMsg {body args} {
    global  prefs

    variable locals
    upvar ::Jabber::mapShowElemToText mapShowElemToText
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::GroupChat::GotMsg args='$args'"

    array set argsArr $args
    
    # We must follow the roomJid...
    if {[info exists argsArr(-from)]} {
	set fromJid $argsArr(-from)
    } else {
	return -code error {Missing -from attribute in group message!}
    }
    
    # Figure out if from the room or from user.
    if {[regexp {(.+)@([^/]+)(/(.+))?} $fromJid match name host junk res]} {
	set roomJid ${name}@${host}
	if {$res == ""} {
	    # From the room itself.
	}
    } else {
	return -code error "The jid we got \"$fromJid\"was not well-formed!"
    }

    # If we haven't a window for this thread, make one!
    if {[info exists locals($roomJid,wtop)] &&  \
      [winfo exists $locals($roomJid,wtop)]} {
    } else {
	eval {::Jabber::GroupChat::Build $roomJid} $args
    }       
    
    # This can be room name or nick name.
    foreach {meRoomJid mynick} [$jstate(jlib) service hashandnick $roomJid] { break }

    # Old-style groupchat and browser compatibility layer.
    set nick [$jstate(jlib) service nick $fromJid]
    
    set wtext $locals($roomJid,wtext)
    if {$jprefs(chat,showtime)} {
	set theTime [clock format [clock seconds] -format "%H:%M"]
	set txt "$theTime <$nick>"
    } else {
	set txt <$nick>
    }
    $wtext configure -state normal
    if {[string equal $meRoomJid $fromJid]} {
	set meyou me
    } else {
	set meyou you
    }
    $wtext insert end $txt ${meyou}tag
    set textCmds [::Text::ParseAllForTextWidget "  $body" ${meyou}txttag linktag]
    foreach cmd $textCmds {
	eval $wtext $cmd
    }
    $wtext insert end "\n"
    
    $wtext configure -state disabled
    $wtext see end
    if {$locals($roomJid,got1stMsg) == 0} {
	set locals($roomJid,got1stMsg) 1
    }
    
    if {$jprefs(speakChat)} {
	if {$meyou == "me"} {
	    ::UserActions::Speak $body $prefs(voiceUs)
	} else {
	    ::UserActions::Speak $body $prefs(voiceOther)
	}
    }
}

# Jabber::GroupChat::Build --
#
#       Builds the group chat dialog. Independently on protocol 'groupchat'
#       and 'conference'.
#
# Arguments:
#       roomJid     The roomname@server
#       args        ??
#       
# Results:
#       shows window.

proc ::Jabber::GroupChat::Build {roomJid args} {
    global  this sysFont prefs
    
    variable locals
    upvar ::Jabber::mapShowElemToText mapShowElemToText
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::GroupChat::Build roomJid=$roomJid, args='$args'"
    
    # Make unique toplevel name from rooms jid.
    regsub -all {\.} $roomJid {_} wunique
    regsub -all {@} $wunique {_} wunique
    set w ".[string tolower $wunique]"
    
    set locals($roomJid,wtop) $w
    set locals($w,room) $roomJid
    if {[winfo exists $w]} {
	return
    }
    array set argsArr $args
    if {[info exists argsArr(-from)]} {
	set locals($roomJid,jid) $argsArr(-from)
    }
    set locals($roomJid,got1stMsg) 0
    toplevel $w -class GroupChat
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
    } else {

    }
    
    # Not sure how old-style groupchat works here???
    set roomName [$jstate(browse) getname $roomJid]
    
    if {[llength $roomName]} {
	set tittxt $roomName
    } else {
	set tittxt $roomJid
    }
    wm title $w $tittxt
    wm protocol $w WM_DELETE_WINDOW  \
      [list ::Jabber::GroupChat::Exit $roomJid]
    
    # Toplevel menu for mac only.
    if {[string match "mac*" $this(platform)]} {
	$w configure -menu [::Jabber::UI::GetRosterWmenu]
    }

    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 4
        
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btsnd -text [::msgcat::mc Send] -width 8  \
      -default active -command [list [namespace current]::Send $roomJid]] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btexit -text [::msgcat::mc Exit] -width 8   \
      -command [list [namespace current]::Exit $roomJid]]  \
      -side right -padx 5 -pady 5  
    
    # CCP
    pack [frame $w.frall.fccp] -side top -fill x
    set wccp $w.frall.fccp.ccp
    pack [::UI::NewCutCopyPaste $wccp] -padx 10 -pady 2 -side left
    ::UI::CutCopyPasteConfigure $wccp cut -state disabled
    ::UI::CutCopyPasteConfigure $wccp copy -state disabled
    ::UI::CutCopyPasteConfigure $wccp paste -state disabled
    pack [frame $w.frall.fccp.div -bd 2 -relief raised -width 2] -fill y -side left
    pack [::UI::NewPrint $w.frall.fccp.pr [list [namespace current]::Print $roomJid]] \
      -side left -padx 10
    pack [frame $w.frall.div2 -bd 2 -relief sunken -height 2] -fill x -side top

    # Popup for setting status to this room.
    set allStatus [array names mapShowElemToText]
    set locals($roomJid,status) [::msgcat::mc Available]
    set locals($roomJid,oldStatus) [::msgcat::mc Available]
    set wpopup $frbot.popup
    set wMenu [eval {tk_optionMenu $wpopup  \
      [namespace current]::locals($roomJid,status)} $allStatus]
    $wpopup configure -highlightthickness 0 -width 14 \
      -background $prefs(bgColGeneral) -foreground black
    pack $wpopup -side left -padx 5 -pady 5
    
    pack $frbot -side bottom -fill x -padx 10 -pady 8
    
    # Keep track of all buttons that need to be disabled on logout.
    set locals($roomJid,allBts) [list $frbot.btsnd $frbot.btexit $wpopup]
        
    # Header fields.
    set frtop [frame $w.frall.frtop -borderwidth 0]
    pack $frtop -side top -fill x   
    label $frtop.la -text {Group chat in room:} -font $sysFont(sb) -anchor e
    entry $frtop.en -bg $prefs(bgColGeneral)
    grid $frtop.la -column 0 -row 0 -sticky e -padx 8 -pady 2
    grid $frtop.en -column 1 -row 0 -sticky ew -padx 4 -pady 2
    grid columnconfigure $frtop 1 -weight 1
    $frtop.en insert end $roomJid
    $frtop.en configure -state disabled
    
    # Text chat and user list.
    set frmid $w.frall.frmid
    pack [frame $frmid -height 250 -width 300 -relief sunken -bd 1]  \
      -side top -fill both -expand 1 -padx 4 -pady 4
    set wtxt $frmid.frtxt
    frame $wtxt -height 200
    frame $wtxt.0 -bg $prefs(bgColGeneral)
    set wtext $wtxt.0.text
    set wysc $wtxt.0.ysc
    set wusers $wtxt.users
    text $wtext -height 12 -width 1 -font $sysFont(s) -state disabled  \
      -borderwidth 1 -relief sunken -yscrollcommand [list $wysc set] -wrap word \
      -cursor {}
    text $wusers -height 12 -width 12 -font $sysFont(s) -state disabled  \
      -borderwidth 1 -relief sunken -background $prefs(bgColGeneral)  \
      -spacing1 1 -spacing3 1 -wrap none -cursor {}
    scrollbar $wysc -orient vertical -command [list $wtext yview]
    pack $wtext -side left -fill both -expand 1
    pack $wysc -side right -fill y -padx 2

    if {[info exists prefs(paneGeom,groupchatDlgHori)]} {
	set relpos $prefs(paneGeom,groupchatDlgHori)
    } else {
	set relpos {0.8 0.2}
    }
    ::pane::pane $wtxt.0 $wusers -limit 0.0 -relative $relpos -orient horizontal
    
    # The tags.
    set space 2
    $wtext tag configure metag -foreground red -background #cecece  \
      -spacing1 $space -font $sysFont(sb)
    $wtext tag configure metxttag -foreground black -background #cecece  \
      -spacing1 $space -spacing3 $space -lmargin1 20 -lmargin2 20
    $wtext tag configure youtag -foreground blue -spacing1 $space  \
       -font $sysFont(sb)
    $wtext tag configure youtxttag -foreground black -spacing1 $space  \
      -spacing3 $space -lmargin1 20 -lmargin2 20

    # Text send.
    set wtxtsnd $frmid.frtxtsnd
    frame $wtxtsnd -height 100 -width 300
    set wtextsnd $wtxtsnd.text
    set wyscsnd $wtxtsnd.ysc
    text $wtextsnd -height 4 -width 1 -font $sysFont(s) -wrap word \
      -borderwidth 1 -relief sunken -yscrollcommand [list $wyscsnd set]
    scrollbar $wyscsnd -orient vertical -command [list $wtextsnd yview]
    grid $wtextsnd -column 0 -row 0 -sticky news
    grid $wyscsnd -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxtsnd 0 -weight 1
    grid rowconfigure $wtxtsnd 0 -weight 1

    if {[info exists prefs(paneGeom,groupchatDlgVert)]} {
	set relpos $prefs(paneGeom,groupchatDlgVert)
    } else {
	set relpos {0.8 0.2}
    }
    ::pane::pane $wtxt $wtxtsnd -limit 0.0 -relative $relpos -orient vertical
    
    set locals($roomJid,wtext) $wtext
    set locals($roomJid,wtextsnd) $wtextsnd
    set locals($roomJid,wusers) $wusers
    set locals($roomJid,wtxt.0) $wtxt.0
    set locals($roomJid,wtxt) $wtxt
	
    # Add to exit menu.
    ::Jabber::UI::GroupChat "enter" $roomJid
    
    # Necessary to trace the popup menu variable.
    trace variable [namespace current]::locals($roomJid,status) w  \
      [list [namespace current]::TraceStatus $roomJid]

    if {[info exists prefs(winGeom,groupchatDlg)]} {
	wm geometry $w $prefs(winGeom,groupchatDlg)
    }
    wm minsize $w 240 320
    wm maxsize $w 800 2000
    
    focus $w
}

proc ::Jabber::GroupChat::Send {roomJid} {
    global  prefs
    
    variable locals
    upvar ::Jabber::jstate jstate
    
    # Check that still connected to server.
    if {![::Jabber::IsConnected]} {
	tk_messageBox -type ok -icon error -title [::msgcat::mc {Not Connected}] \
	  -message [::msgcat::mc jamessnotconnected]
	return
    }
    set wtextsnd $locals($roomJid,wtextsnd)

    # Get text to send.
    set allText [$wtextsnd get 1.0 "end - 1 char"]
    if {$allText != ""} {	
	if {[catch {
	    $jstate(jlib) send_message $roomJid -type groupchat \
	      -body $allText
	} err]} {
	    tk_messageBox -type ok -icon error -title "Network Error" \
	      -message "Network error ocurred: $err"
	    return
	}
    }
    
    # Clear send.
    $wtextsnd delete 1.0 end
    if {$locals($roomJid,got1stMsg) == 0} {
	set locals($roomJid,got1stMsg) 1
    }
}

# Jabber::GroupChat::TraceStatus --
# 
#       Callback via trace when the status is changed via the menubutton.
#

proc ::Jabber::GroupChat::TraceStatus {roomJid name key op} {

    variable locals
    upvar ::Jabber::mapShowElemToText mapShowElemToText
    upvar ::Jabber::jstate jstate
	
    # Call by name. Must be array.
    #upvar #0 ${name}(${key}) locName    
    upvar ${name}(${key}) locName

    ::Jabber::Debug 3 "::Jabber::GroupChat::TraceStatus roomJid=$roomJid, name=$name, \
      key=$key"
    ::Jabber::Debug 3 "    locName=$locName"

    set status $mapShowElemToText($locName)
    if {$status == "unavailable"} {
	set ans [::Jabber::GroupChat::Exit $roomJid]
	if {$ans == "no"} {
	    set locals($roomJid,status) $locals($roomJid,oldStatus)
	}
    } else {
    
	# Send our status.
	::Jabber::SetStatus $status $roomJid
	set locals($roomJid,oldStatus) $locName
    }
}

# Jabber::GroupChat::Presence --
#
#       Sets the presence of the jid in our UI.
#
# Arguments:
#       jid         'user@server' without resource
#       presence    "available", "unavailable", or "unsubscribed"
#       args        list of '-key value' pairs where '-key' can be
#                   -resource, -from, -type, -show...
#       
# Results:
#       groupchat member list updated.

proc ::Jabber::GroupChat::Presence {jid presence args} {

    variable locals
    
    ::Jabber::Debug 2 "::Jabber::GroupChat::Presence jid=$jid, presence=$presence, args='$args'"

    array set attrArr $args
    
    # Since there should not be any /resource.
    set roomJid $jid
    set jidhash ${jid}/$attrArr(-resource)
    if {[string equal $presence "available"]} {
	eval {::Jabber::GroupChat::SetUser $roomJid $jidhash $presence} $args
    } elseif {[string equal $presence "unavailable"]} {
	::Jabber::GroupChat::RemoveUser $roomJid $jidhash
    }
}

# Jabber::GroupChat::BrowseUser --
#
#       This is a <user> element. Gets called for each <user> element
#       in the jabber:iq:browse set or result iq element.
#       Only called if have conference/browse stuff for this service.

proc ::Jabber::GroupChat::BrowseUser {userXmlList} {
    
    variable locals
    upvar ::Jabber::jstate jstate
    
    ::Jabber::Debug 2 "::Jabber::GroupChat::BrowseUser userXmlList='$userXmlList'"

    array set attrArr [lindex $userXmlList 1]
    
    # Direct it to the correct room. 
    set jid $attrArr(jid)
    set parentList [$jstate(browse) getparents $jid]
    set parent [lindex $parentList end]
    
    # Do something only if joined that room.
    if {[$jstate(browse) isroom $parent] &&  \
      ([lsearch [$jstate(jlib) conference allroomsin] $parent] >= 0)} {
	if {[info exists attrArr(type)] && [string equal $attrArr(type) "remove"]} {
	    ::Jabber::GroupChat::RemoveUser $parent $jid
	} else {
	    ::Jabber::GroupChat::SetUser $parent $jid {}
	}
    }
}

# Jabber::GroupChat::SetUser --
#
#       Adds or updates a user item in the group chat dialog.
#       
# Arguments:
#       roomJid     the room's jid
#       jidhash     $roomjid/hashornick
#       presence    "available", "unavailable", or "unsubscribed"
#       args        list of '-key value' pairs where '-key' can be
#                   -resource, -from, -type, -show...
#       
# Results:
#       updated UI.

proc ::Jabber::GroupChat::SetUser {roomJid jidhash presence args} {
    global  this

    variable locals
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::GroupChat::SetUser roomJid=$roomJid,\
      jidhash=$jidhash presence=$presence"

    array set attrArr $args

    # If we haven't a window for this thread, make one!
    if {[info exists locals($roomJid,wtop)] &&  \
      [winfo exists $locals($roomJid,wtop)]} {
    } else {
	eval {::Jabber::GroupChat::Build $roomJid} $args
    }       
    
    # Get the hex string to use as tag. 
    # In old-style groupchat this is the nick name which should be unique
    # within this room aswell.
    if {![regexp {[^@]+@[^/]+/(.+)} $jidhash match hexstr]} {
	error {Failed finding hex string}
    }    
    
    # If we got a browse push with a <user>, asume is available.
    if {[string length $presence] == 0} {
	set presence available
    }
    
    # Any show attribute?
    set showStatus $presence
    if {[info exists attrArr(-show)] && [string length $attrArr(-show)]} {
	set showStatus $attrArr(-show)
    } elseif {[info exists attrArr(-subscription)] &&   \
      [string equal $attrArr(-subscription) "none"]} {
	set showStatus {subnone}
    }
    
    # Remove any "old" line first. Image takes one character's space.
    set wusers $locals($roomJid,wusers)
    
    # Old-style groupchat and browser compatibility layer.
    set nick [$jstate(jlib) service nick $jidhash]
    set icon [eval {::Jabber::GetPresenceIcon $jidhash $presence} $args]
    $wusers configure -state normal
    set insertInd end
    set begin end
    set range [$wusers tag ranges $hexstr]
    if {[llength $range]} {
	
	# Remove complete line including image.
	set insertInd [lindex $range 0]
	set begin "$insertInd linestart"
	$wusers delete "$insertInd linestart" "$insertInd lineend +1 char"
    }    
    
    # Icon that is popup sensitive.
    $wusers image create $begin -image $icon -align bottom
    $wusers tag add $hexstr "$begin linestart" "$begin lineend"

    # Use hex string (resource) as tag.
    $wusers insert "$begin +1 char" " $nick\n" $hexstr
    $wusers configure -state disabled
    
    # For popping up menu.
    if {[string match "mac*" $this(platform)]} {
	$wusers tag bind $hexstr <Button-1>  \
	  [list ::Jabber::GroupChat::PopupTimer $wusers $jidhash %x %y]
	$wusers tag bind $hexstr <ButtonRelease-1>   \
	  ::Jabber::GroupChat::PopupTimerCancel
    } else {
	$wusers tag bind $hexstr <Button-3>  \
	  [list ::Jabber::UI::Popup groupchat $wusers $jidhash %x %y]
    }
    
    # Noise.
    ::Sounds::Play online
}
    
proc ::Jabber::GroupChat::PopupTimer {w jidhash x y} {
    
    variable locals
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::GroupChat::PopupTimer w=$w, jidhash=$jidhash"

    # Set timer for this callback.
    if {[info exists locals(afterid)]} {
	catch {after cancel $locals(afterid)}
    }
    set locals(afterid) [after 1000  \
      [list ::Jabber::UI::Popup groupchat $w $jidhash $x $y]]
}

proc ::Jabber::GroupChat::PopupTimerCancel { } {
    variable locals
    catch {after cancel $locals(afterid)}
}

proc ::Jabber::GroupChat::RemoveUser {roomJid jidhash} {

    variable locals    
    if {![winfo exists $locals($roomJid,wusers)]} {
	return
    }
    
    # Get the hex string to use as tag.
    if {![regexp {[^@]+@[^/]+/(.+)} $jidhash match hexstr]} {
	error {Failed finding hex string}
    }    
    set wusers $locals($roomJid,wusers)
    $wusers configure -state normal
    set range [$wusers tag ranges $hexstr]
    if {[llength $range]} {
	set insertInd [lindex $range 0]
	$wusers delete "$insertInd linestart" "$insertInd lineend +1 char"
    }
    $wusers configure -state disabled
    
    # Noise.
    ::Sounds::Play offline
}

# Jabber::GroupChat::ConfigWBStatusMenu --
# 
#       Sets the Jabber/Status menu for groupchat:
#       -variable ... -command {}

proc ::Jabber::GroupChat::ConfigWBStatusMenu {wtop} {   
    variable locals

    array set wbOpts [::UI::ConfigureMain $wtop]
    set roomJid $wbOpts(-jid)

    # Orig: {-variable ::Jabber::jstate(status) -value available}
    # Not same values due to the design of the tk_optionMenu.
    foreach mName {mAvailable mAway mDoNotDisturb mNotAvailable} {
	::UI::MenuMethod ${wtop}menu.jabber.mstatus entryconfigure $mName \
	  -command {} -variable [namespace current]::locals($roomJid,status) \
	  -value [::msgcat::mc $mName]
    }
    ::UI::MenuMethod ${wtop}menu.jabber.mstatus entryconfigure mAttachMessage \
      -command {} -state disabled
    
    # Just skip this menu entry.
    ::UI::MenuMethod ${wtop}menu.jabber entryconfigure mExitRoom \
      -state disabled
}

proc ::Jabber::GroupChat::Print {roomJid} {
    variable locals
    set wtext $locals($roomJid,wtext) 
    ::UserActions::DoPrintText $wtext
}

# Jabber::GroupChat::Exit --
#
#       Ask if wants to exit room. If then calls GroupChat::Close to do it.
#       
# Arguments:
#       roomJid
#       
# Results:
#       yes/no if actually exited or not.

proc ::Jabber::GroupChat::Exit {roomJid} {
    
    variable locals
    upvar ::Jabber::jstate jstate
    
    if {[info exists locals($roomJid,wtop)] && \
      [winfo exists $locals($roomJid,wtop)]} {
	set opts [list -parent $locals($roomJid,wtop)]
    } else {
	set opts ""
    }
    
    if {[::Jabber::IsConnected]} {
	set ans [eval {tk_messageBox -icon warning -type yesno  \
	  -message [::msgcat::mc jamesswarnexitroom $roomJid]} $opts]
	if {$ans == "yes"} {
	    ::Jabber::GroupChat::Close $roomJid
	    $jstate(jlib) service exitroom $roomJid
	    ::Jabber::UI::GroupChat "exit" $roomJid
	}
    } else {
	set ans "yes"
	::Jabber::GroupChat::Close $roomJid
    }
    return $ans
}

proc ::Jabber::GroupChat::CloseToplevel {w} {
    variable locals
    
    set roomJid $locals($w,room)     
    ::Jabber::GroupChat::Close $roomJid
}

# Jabber::GroupChat::Close --
#
#       Handles the closing of a groupchat. Both text and whiteboard dialogs.

proc ::Jabber::GroupChat::Close {roomJid} {
    variable locals
    upvar ::Jabber::jstate jstate
    
    if {[info exists locals($roomJid,wtop)] &&  \
      [winfo exists $locals($roomJid,wtop)]} {
    	set locals(winGeom) [list groupchatDlg  \
	  [wm geometry $locals($roomJid,wtop)]]
    	::UI::SavePanePos groupchatDlgVert $locals($roomJid,wtxt) vertical
    	::UI::SavePanePos groupchatDlgHori $locals($roomJid,wtxt.0)
    	::Jabber::GroupChat::GetPanePos $roomJid
    
    	# after idle seems to be needed to avoid crashing the mac :-(
    	after idle destroy $locals($roomJid,wtop)
    	trace vdelete [namespace current]::locals($roomJid,status) w  \
      	[list [namespace current]::TraceStatus $roomJid]
    }
    
    # Make sure any associated whiteboard is closed as well.
    set wbwtop [::UI::GetWtopFromJabberType "groupchat" $roomJid]
    if {[string length $wbwtop]} {
	::UI::DestroyMain $wbwtop
    }
}

# Jabber::GroupChat::Logout --
#
#       Sets logged out status on all groupchats, that is, disable all buttons.

proc ::Jabber::GroupChat::Logout { } {
    
    variable locals
    upvar ::Jabber::jstate jstate

    set allRooms [$jstate(jlib) service allroomsin]
    foreach room $allRooms {
	set w $locals($room,wtop)
	::Jabber::UI::GroupChat "exit" $roomJid
	if {[winfo exists $w]} {
	    foreach wbt $locals($room,allBts) {
		$wbt configure -state disabled
	    }
	}
    }
}

proc ::Jabber::GroupChat::GetWinGeom { } {
    
    variable locals

    set ans {}
    set found 0
    foreach key [array names locals "*,wtop"] {
	if {[winfo exists $locals($key)]} {
	    set wtop $locals($key)
	    set found 1
	    break
	}
    }
    if {$found} {
	set ans [list groupchatDlg [wm geometry $wtop]]
    } elseif {[info exists locals(winGeom)]} {
	set ans $locals(winGeom)
    }
    return $ans
}

# Jabber::GroupChat::GetPanePos --
#
#       Return typical pane position list. If $roomJid is given, pick this
#       particular dialog, else first found.

proc ::Jabber::GroupChat::GetPanePos {{roomJid {}}} {

    variable locals

    set ans {}
    if {$roomJid == ""} {
	set found 0
	foreach key [array names locals "*,wtxt"] {
	    set wtxt $locals($key)
	    set wtxt0 ${wtxt}.0
	    if {[winfo exists $wtxt]} {
		set found 1
		break
	    }
	}
    } else {
	set found 1
	set wtxt $locals($roomJid,wtxt)    
	set wtxt0 $locals($roomJid,wtxt.0)    
    }
    if {$found} {
	array set infoArr [::pane::pane info $wtxt]
	lappend ans groupchatDlgVert   \
	  [list $infoArr(-relheight) [expr 1.0 - $infoArr(-relheight)]]
	array set infoArr0 [::pane::pane info $wtxt0]
	lappend ans groupchatDlgHori   \
	  [list $infoArr0(-relwidth) [expr 1.0 - $infoArr0(-relwidth)]]
	set locals(panePosList) $ans
    } elseif {[info exists locals(panePosList)]} {
	set ans $locals(panePosList)
    } else {
	set ans {}
    }
    return $ans
}

#-------------------------------------------------------------------------------
