#  GroupChat.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the group chat GUI part.
#      
#  Copyright (c) 2001-2003  Mats Bengtsson
#  
# $Id: GroupChat.tcl,v 1.35 2004-01-13 14:50:20 matben Exp $

package provide GroupChat 1.0

# Provides dialog for old-style gc-1.0 groupchat but the rest should work for 
# both groupchat and conference protocols.


namespace eval ::Jabber::GroupChat:: {
    global  wDlgs

    # Use option database for customization. Not used yet...
    set fontS [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]

    option add *GroupChat*mePreForeground      red              widgetDefault
    option add *GroupChat*mePreBackground      ""               widgetDefault
    option add *GroupChat*mePreFont            ""               widgetDefault                                     
    option add *GroupChat*meTextForeground     ""               widgetDefault
    option add *GroupChat*meTextBackground     ""               widgetDefault
    option add *GroupChat*meTextFont           ""               widgetDefault                                     
    option add *GroupChat*theyPreForeground    blue             widgetDefault
    option add *GroupChat*theyPreBackground    ""               widgetDefault
    option add *GroupChat*theyPreFont          ""               widgetDefault
    option add *GroupChat*theyTextForeground   ""               widgetDefault
    option add *GroupChat*theyTextBackground   ""               widgetDefault
    option add *GroupChat*theyTextFont         ""               widgetDefault
    option add *GroupChat*sysPreForeground     #26b412          widgetDefault
    option add *GroupChat*sysForeground        #26b412          widgetDefault
    option add *GroupChat*clockFormat          "%H:%M"          widgetDefault
      
    # List of: {tagName optionName resourceName resourceClass}
    variable groupChatOptions {
	{mepre       -foreground          mePreForeground       Foreground}
	{mepre       -background          mePreBackground       Background}
	{mepre       -font                mePreFont             Font}
	{metext      -foreground          meTextForeground      Foreground}
	{metext      -background          meTextBackground      Background}
	{metext      -font                meTextFont            Font}
	{theypre     -foreground          theyPreForeground     Foreground}
	{theypre     -background          theyPreBackground     Background}
	{theypre     -font                theyPreFont           Font}
	{theytext    -foreground          theyTextForeground    Foreground}
	{theytext    -background          theyTextBackground    Background}
	{theytext    -font                theyTextFont          Font}
	{syspre      -foreground          sysPreForeground      Foreground}
	{sys         -foreground          sysForeground         Foreground}
    }

    # Add all event hooks.
    hooks::add quitAppHook             [list ::UI::SaveWinPrefixGeom $wDlgs(jgc)]
    hooks::add quitAppHook             ::Jabber::GroupChat::GetFirstPanePos
    hooks::add newGroupChatMessageHook ::Jabber::GroupChat::GotMsg
    hooks::add closeWindowHook         ::Jabber::GroupChat::CloseHook
    hooks::add logoutHook              ::Jabber::GroupChat::Logout
    hooks::add presenceHook            ::Jabber::GroupChat::PresenceCallback
    
    # Local stuff
    variable locals
    variable enteruid 0
    variable dlguid 0
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

# Jabber::GroupChat::HaveOrigConference --
#
#       Ad hoc method for finding out if possible to use the original
#       jabber:iq:conference method.

proc ::Jabber::GroupChat::HaveOrigConference {{roomjid {}}} {
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

# Jabber::GroupChat::HaveMUC --
# 
# 

proc ::Jabber::GroupChat::HaveMUC {{roomjid {}}} {
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver

    set ans 0
    if {[string length $roomjid] == 0} {
	
	# Require at least one service that supports muc.
	set jids [$jstate(browse) getservicesforns  \
	  "http://jabber.org/protocol/muc"]
	if {[llength $jids] > 0} {
	    set ans 1
	}
    } else {
	set confserver [$jstate(browse) getparentjid $roomjid]
	if {[$jstate(browse) isbrowsed $confserver]} {
	    set ans [$jstate(browse) havenamespace $confserver  \
	      "http://jabber.org/protocol/muc"]
	}
	::Jabber::Debug 4 "::Jabber::GroupChat::HaveMUC \
	confserver=$confserver, ans=$ans"
    }
    return $ans
}

# Jabber::GroupChat::EnterOrCreate --
#
#       Dispatch entering or creating a room to either 'groupchat' (gc-1.0), 
#       'conference', or 'muc' methods depending on preferences.
#       The 'conference' method requires jabber:iq:browse and 
#       jabber:iq:conference.
#       
# Arguments:
#       what        'enter' or 'create'
#       args        -server, -roomjid, -autoget
#       
# Results:
#       "cancel" or "enter".

proc ::Jabber::GroupChat::EnterOrCreate {what args} {
    variable locals
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    
    array set argsArr $args
    if {[info exists argsArr(-roomjid)]} {
	set roomjid $argsArr(-roomjid)
    } else {
	set roomjid ""
    }

    # Preferred groupchat protocol (gc-1.0|muc).
    # Use 'gc-1.0' as fallback.
    set gchatprotocol "gc-1.0"
    
    # Consistency checking.
    if {![regexp {(gc-1.0|muc)} $jprefs(prefgchatproto)]} {
    	set jprefs(prefgchatproto) muc
    }
    
    switch -- $jprefs(prefgchatproto) {
	gc-1.0 {
	    # Empty
	}
	muc {
	    if {[::Jabber::GroupChat::HaveMUC $roomjid]} {
		set gchatprotocol "muc"
	    } elseif {[::Jabber::GroupChat::HaveOrigConference $roomjid]} {
		set gchatprotocol "conference"
	    }
	}
    }
    ::Jabber::Debug 2 "::Jabber::GroupChat::EnterOrCreate\
      gchatprotocol=$gchatprotocol, what=$what, args='$args'"
    
    switch -- $gchatprotocol {
	gc-1.0 {
	    set ans [eval {::Jabber::GroupChat::BuildEnter} $args]
	}
	conference {
	    if {$what == "enter"} {
		set ans [eval {::Jabber::Conference::BuildEnter} $args]
	    } elseif {$what == "create"} {
		set ans [eval {::Jabber::Conference::BuildCreate} $args]
	    }
	}
	muc {
	    if {$what == "enter"} {
		set ans [eval {::Jabber::MUC::BuildEnter} $args]
	    } elseif {$what == "create"} {
		set ans [eval {::Jabber::Conference::BuildCreate} $args]
	    }
	}
    }    
    
    return $ans
}

# Jabber::GroupChat::SetProtocol --
# 
#       Cache groupchat protocol in use for specific room.

proc ::Jabber::GroupChat::SetProtocol {roomJid protocol} {
    variable locals

    set locals($roomJid,protocol) $protocol
    
    # If groupchat window already exists.
    if {[info exists locals($roomJid,wtop)] && \
    [winfo exists $locals($roomJid,wtop)]} {
	$locals($roomJid,wbtinfo) configure -state normal
	$locals($roomJid,wbtnick) configure -state normal
	$locals($roomJid,wbtinvite) configure -state normal
    }
}

# Jabber::GroupChat::BuildEnter --
#
#       This is to provide support for the old-style 'groupchat 1.0' protocol
#       which shall be used when not server is being browsed.
#       
# Arguments:
#       args        -server, -roomjid, -autoget
#       
# Results:
#       "cancel" or "enter".
     
proc ::Jabber::GroupChat::BuildEnter {args} {
    global  this wDlgs

    variable enteruid
    variable dlguid
    upvar ::Jabber::jstate jstate

    set chatservers [$jstate(jlib) service getjidsfor "groupchat"]
    ::Jabber::Debug 2 "::Jabber::GroupChat::BuildEnter args='$args'"
    ::Jabber::Debug 2 "    service getjidsfor groupchat: '$chatservers'"
    
    if {[llength $chatservers] == 0} {
	tk_messageBox -icon error -message [::msgcat::mc jamessnogchat]
	return
    }

    # State variable to collect instance specific variables.
    set token [namespace current]::enter[incr enteruid]
    variable $token
    upvar 0 $token enter
    
    set w $wDlgs(jgcenter)[incr dlguid]
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc
    wm title $w [::msgcat::mc {Enter/Create Room}]
    set enter(w) $w
    array set enter {
	finished    -1
	server      ""
	roomname    ""
	nickname    ""
    }
    array set argsArr $args
    
    set fontSB [option get . fontSmallBold {}]

    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 4
        
    set enter(server) [lindex $chatservers 0]
    set frmid $w.frall.mid
    pack [frame $frmid] -side top -fill both -expand 1
    set msg [::msgcat::mc jagchatmsg]
    message $frmid.msg -width 260 -text $msg
    label $frmid.lserv -text "[::msgcat::mc Servers]:" -font $fontSB -anchor e

    set wcomboserver $frmid.eserv
    ::combobox::combobox $wcomboserver -width 18  \
      -textvariable $token\(server)
    eval {$frmid.eserv list insert end} $chatservers
    label $frmid.lroom -text "[::msgcat::mc Room]:" -font $fontSB -anchor e
    entry $frmid.eroom -width 24    \
      -textvariable $token\(roomname) -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    label $frmid.lnick -text "[::msgcat::mc {Nick name}]:" -font $fontSB \
      -anchor e
    entry $frmid.enick -width 24    \
      -textvariable $token\(nickname) -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    grid $frmid.msg -column 0 -columnspan 2 -row 0 -sticky ew
    grid $frmid.lserv -column 0 -row 1 -sticky e
    grid $frmid.eserv -column 1 -row 1 -sticky ew 
    grid $frmid.lroom -column 0 -row 2 -sticky e
    grid $frmid.eroom -column 1 -row 2 -sticky ew
    grid $frmid.lnick -column 0 -row 3 -sticky e
    grid $frmid.enick -column 1 -row 3 -sticky ew
    
    if {[info exists argsArr(-roomjid)]} {
	regexp {^([^@]+)@([^/]+)} $argsArr(-roomjid) match enter(roomname) \
	  server
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
      -command [list [namespace current]::DoEnter $token]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btexit -text [::msgcat::mc Cancel] -width 8   \
      -command [list [namespace current]::Cancel $token]]  \
      -side right -padx 5 -pady 5  
    pack $frbot -side bottom -fill x
    
    # Grab and focus.
    set oldFocus [focus]
    focus $w
    bind $w <Return> [list $frbot.btconn invoke]
    
    # Wait here for a button press and window to be destroyed.
    tkwait window $w
    
    catch {focus $oldFocus}
    set finished $enter(finished)
    unset enter
    return [expr {($finished <= 0) ? "cancel" : "enter"}]
}

proc ::Jabber::GroupChat::Cancel {token} {
    variable $token
    upvar 0 $token enter

    set enter(finished) 0
    catch {destroy $enter(w)}
}

proc ::Jabber::GroupChat::DoEnter {token} {
    variable $token
    upvar 0 $token enter

    upvar ::Jabber::jstate jstate
    
    # Verify the fields first.
    if {($enter(server) == "") || ($enter(roomname) == "") ||  \
      ($enter(nickname) == "")} {
	tk_messageBox -title [::msgcat::mc Warning] -type ok -message \
	  [::msgcat::mc jamessgchatfields]
	return
    }

    set roomJid [string tolower $enter(roomname)@$enter(server)]
    $jstate(jlib) groupchat enter $roomJid $enter(nickname) \
      -command [namespace current]::EnterCallback

    set enter(finished) 1
    destroy $enter(w)
}

proc ::Jabber::GroupChat::EnterCallback {jlibName type args} {
    
    array set argsArr $args
    if {[string equal $type "error"]} {
	set msg "We got an error when entering room \"$argsArr(-from)\"."
	if {[info exists argsArr(-error)]} {
	    foreach {errcode errmsg} $argsArr(-error) break
	    append msg " The error code is $errcode: $errmsg"
	}
	tk_messageBox -title "Error Enter Room" -message $msg
	return
    }
    
    # Cache groupchat protocol type (muc|conference|gc-1.0).
    ::Jabber::GroupChat::SetProtocol $argsArr(-from) "gc-1.0"
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
    if {[info exists argsArr(-subject)]} {
	set locals($roomJid,topic) $argsArr(-subject)
    }
    if {[string length $body] > 0} {
	set w $locals($roomJid,wtop)
	
	# This can be room name or nick name.
	foreach {meRoomJid mynick}  \
	  [$jstate(jlib) service hashandnick $roomJid] break
	
	# Old-style groupchat and browser compatibility layer.
	set nick [$jstate(jlib) service nick $fromJid]
	
	set wtext $locals($roomJid,wtext)
	
	set clockFormat [option get $w clockFormat {}]
	if {$clockFormat != ""} {
	    set theTime [clock format [clock seconds] -format $clockFormat]
	    set txt "$theTime <$nick>"
	} else {
	    set txt <$nick>
	}

	$wtext configure -state normal
	if {[string equal $meRoomJid $fromJid]} {
	    set methey me
	} else {
	    set methey they
	}
	$wtext insert end $txt ${methey}pre
	::Text::ParseAndInsert $wtext "  $body" ${methey}text linktag	
	$wtext configure -state disabled
	$wtext see end

	if {$locals($roomJid,got1stMsg) == 0} {
	    set locals($roomJid,got1stMsg) 1
	}
	
	# Run display hooks (speech).
	eval {hooks::run displayGroupChatMessageHook $body} $args
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
    global  this prefs wDlgs
    
    variable groupChatOptions
    variable locals
    variable dlguid
    upvar ::Jabber::mapShowElemToText mapShowElemToText
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::GroupChat::Build roomJid=$roomJid, args='$args'"
    
    # Make unique toplevel name.
    set w $wDlgs(jgc)[incr dlguid]
    
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
    set locals($roomJid,topic) ""
    
    # Toplevel of class GroupChat.
    ::UI::Toplevel $w -class GroupChat -usemacmainmenu 1 -macstyle documentProc
    
    # Not sure how old-style groupchat works here???
    set roomName [$jstate(browse) getname $roomJid]
    
    if {[llength $roomName]} {
	set tittxt $roomName
    } else {
	set tittxt $roomJid
    }
    wm title $w $tittxt
    
    # Toplevel menu for mac only.
    if {[string match "mac*" $this(platform)]} {
	#$w configure -menu [::Jabber::UI::GetRosterWmenu]
    }
    set fontS [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]
    set bg [option get . backgroundGeneral {}]

    foreach {optName optClass} $groupChatOptions {
	set $optName [option get $w $optName $optClass]
    }
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised]   \
      -fill both -expand 1 -ipadx 4
    
    # Widget paths.
    set frmid     $w.frall.frmid
    set wtxt      $frmid.frtxt
    set wtext     $wtxt.0.text
    set wysc      $wtxt.0.ysc
    set wusers    $wtxt.users
    set wtxtsnd   $frmid.frtxtsnd
    set wtextsnd  $wtxtsnd.text
    set wyscsnd   $wtxtsnd.ysc
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btsnd -text [::msgcat::mc Send] -width 8  \
      -default active -command [list [namespace current]::Send $roomJid]] \
      -side right -padx 5 -pady 5
    pack [button $frbot.btexit -text [::msgcat::mc Exit] -width 8   \
      -command [list [namespace current]::Exit $roomJid]]  \
      -side right -padx 5 -pady 5  
    pack [::Jabber::UI::SmileyMenuButton $frbot.smile $wtextsnd]  \
      -side right -padx 5 -pady 5  
    
    # CCP
    pack [frame $w.frall.fccp] -side top -fill x
    set wccp $w.frall.fccp.ccp
    pack [::UI::NewCutCopyPaste $wccp] -padx 10 -pady 2 -side left
    ::UI::CutCopyPasteConfigure $wccp cut -state disabled
    ::UI::CutCopyPasteConfigure $wccp copy -state disabled
    ::UI::CutCopyPasteConfigure $wccp paste -state disabled
    pack [frame $w.frall.fccp.div -bd 2 -relief raised -width 2]  \
      -fill y -side left
    pack [::UI::NewPrint $w.frall.fccp.pr [list [namespace current]::Print $roomJid]] \
      -side left -padx 10
    
    set wbtinvite $w.frall.fccp.inv
    set wbtnick $w.frall.fccp.nick
    set wbtinfo $w.frall.fccp.info
    pack [button $wbtinfo -text "[::msgcat::mc Info]..."  \
      -font $fontS -command [list ::Jabber::MUC::BuildInfo $roomJid]] \
      -side right -padx 4
    pack [button $wbtnick -text "[::msgcat::mc {Nick name}]..."  \
      -font $fontS -command [list ::Jabber::MUC::SetNick $roomJid]] \
      -side right -padx 4
    pack [button $wbtinvite -text "[::msgcat::mc Invite]..."  \
      -font $fontS -command [list ::Jabber::MUC::Invite $roomJid]] \
      -side right -padx 4
    
    pack [frame $w.frall.div2 -bd 2 -relief sunken -height 2] -fill x -side top
    if {!( [info exists locals($roomJid,protocol)] &&  \
      ($locals($roomJid,protocol) == "muc") )} {
	$wbtinfo configure -state disabled
	$wbtnick configure -state disabled
	$wbtinvite configure -state disabled
    }

    # Popup for setting status to this room.
    set allStatus [array names mapShowElemToText]
    set locals($roomJid,status) [::msgcat::mc Available]
    set locals($roomJid,oldStatus) [::msgcat::mc Available]
    set wpopup $frbot.popup
    set wMenu [eval {tk_optionMenu $wpopup  \
      [namespace current]::locals($roomJid,status)} $allStatus]
    $wpopup configure -highlightthickness 0 -width 14 -foreground black
    pack $wpopup -side left -padx 5 -pady 5
    
    pack $frbot -side bottom -fill x -padx 10 -pady 8
    
    # Keep track of all buttons that need to be disabled on logout.
    set locals($roomJid,allBts) [list $frbot.btsnd $frbot.btexit $wpopup]
    
    # Header fields.
    set frtop [frame $w.frall.frtop -borderwidth 0]
    pack $frtop -side top -fill x   
    label $frtop.la -text "[::msgcat::mc {Group chat in room}]:"  \
      -font $fontSB -anchor e
    entry $frtop.en -bg $bg
    label $frtop.ltp -text "[::msgcat::mc Topic]:" -font $fontSB -anchor e
    entry $frtop.etp -bg $bg  \
      -textvariable [namespace current]::locals($roomJid,topic)
    button $frtop.btp -text "[::msgcat::mc Change]..." -font $fontS  \
      -command [list [namespace current]::SetTopic $roomJid]
    
    grid $frtop.la -column 0 -row 0 -sticky e -padx 4 -pady 1
    grid $frtop.en -column 1 -row 0 -sticky ew -padx 4 -pady 1 -columnspan 2
    grid $frtop.ltp -column 0 -row 1 -sticky e -padx 4 -pady 1
    grid $frtop.etp -column 1 -row 1 -sticky ew -padx 4 -pady 1
    grid $frtop.btp -column 2 -row 1 -sticky w -padx 6 -pady 1
    grid columnconfigure $frtop 1 -weight 1
    $frtop.en insert end $roomJid
    $frtop.en configure -state disabled
    $frtop.etp configure -state disabled
    
    # Text chat and user list.
    pack [frame $frmid -height 250 -width 300 -relief sunken -bd 1 -class Pane] \
      -side top -fill both -expand 1 -padx 4 -pady 4
    frame $wtxt -height 200
    frame $wtxt.0
    text $wtext -height 12 -width 1 -font $fontS -state disabled  \
      -borderwidth 1 -relief sunken -yscrollcommand [list $wysc set] -wrap word \
      -cursor {}
    text $wusers -height 12 -width 12 -state disabled  \
      -borderwidth 1 -relief sunken  \
      -spacing1 1 -spacing3 1 -wrap none -cursor {}
    scrollbar $wysc -orient vertical -command [list $wtext yview]
    pack $wtext -side left -fill both -expand 1
    pack $wysc -side right -fill y -padx 2
    
    set imageVertical   \
      [::Theme::GetImage [option get $frmid imageVertical {}]]
    set imageHorizontal \
      [::Theme::GetImage [option get $frmid imageHorizontal {}]]
    set sashVBackground [option get $frmid sashVBackground {}]
    set sashHBackground [option get $frmid sashHBackground {}]

    set paneopts [list -orient horizontal -limit 0.0]
    if {[info exists prefs(paneGeom,groupchatDlgHori)]} {
	lappend paneopts -relative $prefs(paneGeom,groupchatDlgHori)
    } else {
	lappend paneopts -relative {0.8 0.2}
    }
    if {$sashVBackground != ""} {
	lappend paneopts -image "" -handlelook [list -background $sashVBackground]
    } elseif {$imageVertical != ""} {
	lappend paneopts -image $imageVertical
    }    
    eval {::pane::pane $wtxt.0 $wusers} $paneopts
    
    # The tags.
    ::Jabber::GroupChat::ConfigureTextTags $w $wtext
    
    # Text send.
    frame $wtxtsnd -height 100 -width 300
    text $wtextsnd -height 4 -width 1 -font $fontS -wrap word \
      -borderwidth 1 -relief sunken -yscrollcommand [list $wyscsnd set]
    scrollbar $wyscsnd -orient vertical -command [list $wtextsnd yview]
    grid $wtextsnd -column 0 -row 0 -sticky news
    grid $wyscsnd -column 1 -row 0 -sticky ns
    grid columnconfigure $wtxtsnd 0 -weight 1
    grid rowconfigure $wtxtsnd 0 -weight 1
    
    set paneopts [list -orient vertical -limit 0.0]
    if {[info exists prefs(paneGeom,groupchatDlgVert)]} {
	lappend paneopts -relative $prefs(paneGeom,groupchatDlgVert)
    } else {
	lappend paneopts -relative {0.8 0.2}
    }
    if {$sashHBackground != ""} {
	lappend paneopts -image "" -handlelook [list -background $sashHBackground]
    } elseif {$imageHorizontal != ""} {
	lappend paneopts -image $imageHorizontal
    }    
    eval {::pane::pane $wtxt $wtxtsnd} $paneopts
    
    set locals($roomJid,wtext)      $wtext
    set locals($roomJid,wtextsnd)   $wtextsnd
    set locals($roomJid,wusers)     $wusers
    set locals($roomJid,wtxt.0)     $wtxt.0
    set locals($roomJid,wtxt)       $wtxt
    set locals($roomJid,wbtinvite)  $wbtinvite
    set locals($roomJid,wbtnick)    $wbtnick
    set locals($roomJid,wbtinfo)    $wbtinfo
    
    # Add to exit menu.
    ::Jabber::UI::GroupChat "enter" $roomJid
    
    # Necessary to trace the popup menu variable.
    trace variable [namespace current]::locals($roomJid,status) w  \
      [list [namespace current]::TraceStatus $roomJid]
    
    set nwin [llength [::UI::GetPrefixedToplevels $wDlgs(jgc)]]
    if {$nwin == 1} {
	::UI::SetWindowGeometry $w $wDlgs(jgc)
    }
    wm minsize $w 240 320
    wm maxsize $w 800 2000
    
    focus $w
}

proc ::Jabber::GroupChat::CloseHook {wclose} {
    global  wDlgs
    variable locals
    
    set result ""
    if {[string match $wDlgs(jgc)* $wclose]} {
	set w $wclose
	if {[info exists locals($w,room)]} {
	    set roomJid $locals($w,room)
	    set ans [::Jabber::GroupChat::Exit $roomJid]
	    if {$ans == "no"} {
		set result stop
	    }
	}
    }  
    return $result
}

proc ::Jabber::GroupChat::ConfigureTextTags {w wtext} {
    variable groupChatOptions
    upvar ::Jabber::jprefs jprefs
    
    ::Jabber::Debug 2 "::Jabber::GroupChat::ConfigureTextTags"
    
    set space 2
    set alltags {mepre metext theypre theytext syspre sys}
	
    if {[string length $jprefs(chatFont)]} {
	set chatFont $jprefs(chatFont)
	set boldChatFont [lreplace $jprefs(chatFont) 2 2 bold]
    }
    foreach tag $alltags {
	set opts($tag) [list -spacing1 $space]
    }
    foreach spec $groupChatOptions {
	foreach {tag optName resName resClass} $spec break
	set value [option get $w $resName $resClass]
	if {[string length $value]} {
	    lappend opts($tag) $optName $value
	}   
    }
    lappend opts(metext)   -spacing3 $space -lmargin1 20 -lmargin2 20
    lappend opts(theytext) -spacing3 $space -lmargin1 20 -lmargin2 20
    lappend opts(sys)      -spacing3 $space -lmargin1 20 -lmargin2 20
    foreach tag $alltags {
	eval {$wtext tag configure $tag} $opts($tag)
    }
    
    ::Text::ConfigureLinkTagForTextWidget $wtext linktag tact
}

proc ::Jabber::GroupChat::SetTopic {roomJid} {
    variable locals
    upvar ::Jabber::jstate jstate
    
    set topic $locals($roomJid,topic)
    set ans [::UI::MegaDlgMsgAndEntry  \
      [::msgcat::mc {Set New Topic}]  \
      [::msgcat::mc jasettopic]  \
      "[::msgcat::mc {New Topic}]:"  \
      topic [::msgcat::mc Cancel] [::msgcat::mc OK]]

    if {($ans == "ok") && ($topic != "")} {
	if {[catch {
	    $jstate(jlib) send_message $roomJid -type groupchat \
	      -subject $topic
	} err]} {
	    tk_messageBox -type ok -icon error -title "Network Error" \
	      -message "Network error ocurred: $err"
	    return
	}
    }
    return $ans
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

    # Get text to send. Strip off any ending newlines from Return.
    # There might by smiley icons in the text widget. Parse them to text.
    set allText [::Text::TransformToPureText $wtextsnd]
    set allText [string trimright $allText "\n"]
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
	::Jabber::SetStatus $status -to $roomJid
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

proc ::Jabber::GroupChat::PresenceCallback {jid presence args} {
    
    variable locals
    upvar ::Jabber::jstate jstate
    
    if {[$jstate(jlib) service isroom $jid]} {
	::Jabber::Debug 2 "::Jabber::GroupChat::PresenceCallback jid=$jid, presence=$presence, args='$args'"
	
	array set attrArr $args
	
	# Since there should not be any /resource.
	set roomJid $jid
	set jid3 ${jid}/$attrArr(-resource)
	if {[string equal $presence "available"]} {
	    eval {::Jabber::GroupChat::SetUser $roomJid $jid3 $presence} $args
	} elseif {[string equal $presence "unavailable"]} {
	    ::Jabber::GroupChat::RemoveUser $roomJid $jid3
	}
	
	# When kicked etc. from a MUC room...
	# 
	# 
	#  <x xmlns='http://jabber.org/protocol/muc#user'>
	#    <item affiliation='none' role='none'>
	#      <actor jid='fluellen@shakespeare.lit'/>
	#      <reason>Avaunt, you cullion!</reason>
	#    </item>
	#    <status code='307'/>
	#  </x>
	
	if {[info exists attrArr(-x)]} {
	    foreach c $attrArr(-x) {
		set xmlns [wrapper::getattribute $c xmlns]
		
		switch -- $xmlns {
		    "http://jabber.org/protocol/muc#user" {
			# Seems hard to figure out anything here...		    
		    }
		}
	    }
	}
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
#       jid3     $roomjid/hashornick
#       presence    "available", "unavailable", or "unsubscribed"
#       args        list of '-key value' pairs where '-key' can be
#                   -resource, -from, -type, -show...
#       
# Results:
#       updated UI.

proc ::Jabber::GroupChat::SetUser {roomJid jid3 presence args} {
    global  this

    variable locals
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::GroupChat::SetUser roomJid=$roomJid,\
      jid3=$jid3 presence=$presence"

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
    if {![regexp {[^@]+@[^/]+/(.+)} $jid3 match hexstr]} {
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
	set showStatus "subnone"
    }
    
    # Remove any "old" line first. Image takes one character's space.
    set wusers $locals($roomJid,wusers)
    
    # Old-style groupchat and browser compatibility layer.
    set nick [$jstate(jlib) service nick $jid3]
    set icon [eval {::Jabber::Roster::GetPresenceIcon $jid3 $presence} $args]
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

    # Use hex string, nickname (resource) as tag.
    $wusers insert "$begin +1 char" " $nick\n" $hexstr
    $wusers configure -state disabled
    
    # For popping up menu.
    if {[string match "mac*" $this(platform)]} {
	$wusers tag bind $hexstr <Button-1>  \
	  [list ::Jabber::GroupChat::PopupTimer $wusers $jid3 %x %y]
	$wusers tag bind $hexstr <ButtonRelease-1>   \
	  ::Jabber::GroupChat::PopupTimerCancel
	$wusers tag bind $hexstr <Control-Button-1>  \
	  [list ::Jabber::UI::Popup groupchat $wusers $jid3 %x %y]
    } else {
	$wusers tag bind $hexstr <Button-3>  \
	  [list ::Jabber::UI::Popup groupchat $wusers $jid3 %x %y]
    }
    
    # Noise.
    ::Sounds::PlayWhenIdle online
}
    
proc ::Jabber::GroupChat::PopupTimer {w jid3 x y} {
    
    variable locals
    upvar ::Jabber::jstate jstate

    ::Jabber::Debug 2 "::Jabber::GroupChat::PopupTimer w=$w, jid3=$jid3"

    # Set timer for this callback.
    if {[info exists locals(afterid)]} {
	catch {after cancel $locals(afterid)}
    }
    set locals(afterid) [after 1000  \
      [list ::Jabber::UI::Popup groupchat $w $jid3 $x $y]]
}

proc ::Jabber::GroupChat::PopupTimerCancel { } {
    variable locals
    catch {after cancel $locals(afterid)}
}

proc ::Jabber::GroupChat::RemoveUser {roomJid jid3} {

    variable locals    
    if {![winfo exists $locals($roomJid,wusers)]} {
	return
    }
    
    # Get the hex string to use as tag.
    if {![regexp {[^@]+@[^/]+/(.+)} $jid3 match hexstr]} {
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
    ::Sounds::PlayWhenIdle offline
}

# Jabber::GroupChat::ConfigWBStatusMenu --
# 
#       Sets the Jabber/Status menu for groupchat:
#       -variable ... -command {}

proc ::Jabber::GroupChat::ConfigWBStatusMenu {wtop} {   
    variable locals

    array set wbOpts [::WB::ConfigureMain $wtop]
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

# Jabber::GroupChat::Close --
#
#       Handles the closing of a groupchat. Both text and whiteboard dialogs.

proc ::Jabber::GroupChat::Close {roomJid} {
    global  wDlgs
    variable locals
    
    if {[info exists locals($roomJid,wtop)] &&  \
      [winfo exists $locals($roomJid,wtop)]} {
	::UI::SaveWinGeom $wDlgs(jgc) $locals($roomJid,wtop)
    	::UI::SavePanePos groupchatDlgVert $locals($roomJid,wtxt)
    	::UI::SavePanePos groupchatDlgHori $locals($roomJid,wtxt.0) vertical

	
    	# after idle seems to be needed to avoid crashing the mac :-(
    	after idle destroy $locals($roomJid,wtop)
    	trace vdelete [namespace current]::locals($roomJid,status) w  \
      	[list [namespace current]::TraceStatus $roomJid]
    }
    
    # Make sure any associated whiteboard is closed as well.
    set wbwtop [::WB::GetWtopFromJabberType "groupchat" $roomJid]
    if {[string length $wbwtop]} {
	::WB::DestroyMain $wbwtop
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
	::Jabber::UI::GroupChat "exit" $room
	if {[winfo exists $w]} {
	    foreach wbt $locals($room,allBts) {
		$wbt configure -state disabled
	    }
	}
    }
}

proc ::Jabber::GroupChat::GetFirstPanePos { } {
    global  wDlgs
    variable locals
    
    set win [::UI::GetFirstPrefixedToplevel $wDlgs(jgc)]
    if {$win != ""} {
	set roomJid $locals($win,room) 
	::UI::SavePanePos groupchatDlgVert $locals($roomJid,wtxt)
	::UI::SavePanePos groupchatDlgHori $locals($roomJid,wtxt.0) vertical
    }
}

#-------------------------------------------------------------------------------
