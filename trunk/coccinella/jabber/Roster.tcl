#  Roster.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the Roster GUI part.
#      
#  Copyright (c) 2001-2005  Mats Bengtsson
#  
# $Id: Roster.tcl,v 1.114 2005-02-04 07:05:32 matben Exp $

package provide Roster 1.0

namespace eval ::Roster:: {
    global  this
    
    # Add all event hooks we need.
    ::hooks::register loginHook              ::Roster::LoginCmd
    ::hooks::register logoutHook             ::Roster::LogoutHook
    ::hooks::register browseSetHook          ::Roster::BrowseSetHook
    ::hooks::register discoInfoHook          ::Roster::DiscoInfoHook
    
    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          ::Roster::InitPrefsHook
    ::hooks::register prefsBuildHook         ::Roster::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::Roster::SavePrefsHook
    ::hooks::register prefsCancelHook        ::Roster::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::Roster::UserDefaultsHook

    # Use option database for customization. 
    # Use priority 30 just to override the widgetDefault values!
    set fontS  [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]
    
    # Standard widgets and standard options.
    option add *Roster.borderWidth          0               50
    option add *Roster.relief               flat            50
    option add *Roster.pad.padX             4               50
    option add *Roster.pad.padY             4               50
    option add *Roster*box.borderWidth      1               50
    option add *Roster*box.relief           sunken          50
    option add *Roster.stat.f.padX          8               50
    option add *Roster.stat.f.padY          2               50
    
    # Specials.
    option add *Roster.backgroundImage      sky             widgetDefault
    option add *Roster*Tree*dirImage        ""              widgetDefault
    option add *Roster*Tree*onlineImage     lightbulbon     widgetDefault
    option add *Roster*Tree*offlineImage    lightbulboff    widgetDefault
    option add *Roster*Tree*groupImage      ""              widgetDefault
    option add *Roster*rootBackground       ""              widgetDefault
    option add *Roster*rootBackgroundBd     0               widgetDefault
    option add *Roster*rootForeground       ""              widgetDefault
    option add *Roster.waveImage            wave            widgetDefault

    variable wtree    
    variable servtxt
    
    # A unique running identifier.
    variable uid 0
    
    # Use a unique canvas tag in the tree widget for each jid put there.
    # This is needed for the balloons that need a real canvas tag, and that
    # we can't use jid's for this since they may contain special chars (!)!
    variable treeuid 0
    
    variable presToNameArr
    array set presToNameArr {available Online unavailable Offline}
    
    variable dirNameArr
    array set dirNameArr {
	online      Online
	offline     Offline
	transports  Transports
	pending     {Subscription Pending}
    }
    
    # Mappings from <show> element to displayable text and vice versa.
    # chat away xa dnd
    variable mapShowElemToText
    variable mapShowTextToElem
    
    array set mapShowElemToText [list \
      [mc mAvailable]       available  \
      [mc mAway]            away       \
      [mc mChat]            chat       \
      [mc mDoNotDisturb]    dnd        \
      [mc mExtendedAway]    xa         \
      [mc mInvisible]       invisible  \
      [mc mNotAvailable]    unavailable]
    array set mapShowTextToElem [list \
      available       [mc mAvailable]     \
      away            [mc mAway]          \
      chat            [mc mChat]          \
      dnd             [mc mDoNotDisturb]  \
      xa              [mc mExtendedAway]  \
      invisible       [mc mInvisible]     \
      unavailable     [mc mNotAvailable]]

    # The trees 'directories' which should always be there.
    variable closedTreeDirs {}
        
    # Template for the roster popup menu.
    variable popMenuDefs
    
    # General.
    set popMenuDefs(roster,def) {
	mMessage       {head group user}  {::NewMsg::Build -to $jid}
	mChat          {user online}      {::Chat::StartThread $jid3}
	mWhiteboard    {wb online}        {::Jabber::WB::NewWhiteboardTo $jid3}
	mSendFile      user               {::OOB::BuildSet $jid3}
	separator      {}                 {}
	mLastLogin/Activity user          {::Jabber::GetLast $jid}
	mvCard         user               {::VCard::Fetch other $jid}
	mAddNewUser    {}                 {::Jabber::User::NewDlg}
	mEditUser      user               {::Jabber::User::EditDlg $jid}
	mVersion       {user online}      {::Jabber::GetVersion $jid3}
	mChatHistory   {user always}      {::Chat::BuildHistoryForJid $jid}
	mRemoveContact user               {::Roster::SendRemove $jid}
	separator      {}                 {}
	mDirStatus     user               {::Roster::DirectedPresenceDlg $jid}
	mRefreshRoster {}                 {::Roster::Refresh}
    }  

    # Transports.
    set popMenuDefs(roster,trpt,def) {
	mLastLogin/Activity user          {::Jabber::GetLast $jid}
	mvCard         user               {::VCard::Fetch other $jid}
	mAddNewUser    {}                 {::Jabber::User::NewDlg}
	mEditUser      user               {::Jabber::User::EditDlg $jid}
	mVersion       user               {::Jabber::GetVersion $jid3}
	mLoginTrpt     {trpt offline}     {::Roster::LoginTrpt $jid3}
	mLogoutTrpt    {trpt online}      {::Roster::LogoutTrpt $jid3}
	separator      {}                 {}
	mRefreshRoster {}                 {::Roster::Refresh}
    }  

    # Can't run our http server on macs :-(
    if {[string equal $this(platform) "macintosh"]} {
	set popMenuDefs(roster,def) [lreplace $popMenuDefs(roster,def) 9 11]
    }
    
    # Various time values.
    variable timer
    set timer(msg,ms) 10000
    set timer(exitroster,secs) 0
    set timer(pres,secs) 4
}

proc ::Roster::GetNameOrjid {jid} {
    upvar ::Jabber::jstate jstate
       
    set name [$jstate(roster) getname $jid]
    if {$name == ""} {
	set name $jid
    }
    return $name
}

proc ::Roster::GetShortName {jid} {
    upvar ::Jabber::jstate jstate
    
    set name [$jstate(roster) getname $jid]
    if {$name == ""} {	
	jlib::splitjidex $jid node domain res
	if {$node == ""} {
	    set name $domain
	} else {
	    if {[string equal [$jstate(jlib) getthis server] $domain]} {
		set name $node
	    } else {
		set name $jid
	    }
	}
    }
    return $name
}

proc ::Roster::GetDisplayName {jid} {
    upvar ::Jabber::jstate jstate
    
    set name [$jstate(roster) getname $jid]
    if {$name == ""} {
	jlib::splitjidex $jid node domain res
	if {$node == ""} {
	    set name $domain
	} else {
	    set name $node
	}
    }
    return $name
}

proc ::Roster::MapShowToText {show} {
    variable mapShowTextToElem
    
    return $mapShowTextToElem($show)
}

# Roster::Show --
#
#       Show the roster window.
#
# Arguments:
#       w      the toplevel window.
#       
# Results:
#       shows window.

proc ::Roster::Show {w} {
    upvar ::Jabber::jstate jstate

    if {$jstate(rosterVis)} {
	if {[winfo exists $w]} {
	    catch {wm deiconify $w}
	} else {
	    BuildToplevel $w
	}
    } else {
	catch {wm withdraw $w}
    }
}

# Roster::BuildToplevel --
#
#       Build the toplevel roster window.
#
# Arguments:
#       w      the toplevel window.
#       
# Results:
#       shows window.

proc ::Roster::BuildToplevel {w} {
    global  prefs

    variable wtop
    variable servtxt
    upvar ::UI::menuDefs menuDefs

    if {[winfo exists $w]} {
	return
    }
    set wtop $w
    
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1
    wm title $w {Roster (Contact list)}
    wm protocol $w WM_DELETE_WINDOW [list [namespace current]::CloseDlg $w]
    
    set fontSB [option get . fontSmallBold {}]
        
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1
    
    # Top frame for info.
    set frtop $w.frall.frtop
    pack [frame $frtop] -fill x -side top -anchor w -padx 10 -pady 4
    label $frtop.la -text {Connected to:} -font $fontSB
    label $frtop.laserv -textvariable [namespace current]::servtxt
    pack $frtop.la $frtop.laserv -side left -pady 4
    set servtxt {not connected}

    # And the real stuff.
    pack [Build $w.frall.br] -side top -fill both -expand 1
    
    wm maxsize $w 320 800
    wm minsize $w 180 240
}

# Roster::Build --
#
#       Makes mega widget to show the roster.
#
# Arguments:
#       w           frame window with everything.
#       
# Results:
#       w

proc ::Roster::Build {w} {
    global  this wDlgs prefs
        
    variable wtree    
    variable servtxt
    variable btedit
    variable btremove
    variable btrefresh
    variable selItem
    variable wroster
    variable wwave
    variable closedTreeDirs
    variable dirNameArr
    upvar ::Jabber::jprefs jprefs
        
    set fontS [option get . fontSmall {}]

    # The frame of class Roster. D = -bd 0 -relief flat
    frame $w -class Roster
    
    # Keep empty frame for any padding.
    frame $w.tpad
    pack  $w.tpad -side top -fill x
    
    # Tree frame with scrollbars.
    set wroster $w
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
    
    # D = -padx 0 -pady 0
    frame $w.stat
    frame $w.stat.f
    pack  $w.stat   -side bottom -fill x
    pack  $w.stat.f -side bottom -fill x
    set wwave $w.stat.f.wa
    set waveImage [::Theme::GetImage [option get $w waveImage {}]]  
    ::wavelabel::wavelabel $wwave -type image -image $waveImage
    pack $wwave -side bottom -fill x
    
    set opts {}
    if {$jprefs(rost,useBgImage)} {
	
	# Create background image if nonstandard.
	set bgImage ""
	if {[file exists $jprefs(rost,bgImagePath)]} {
	    if {[catch {
		set bgImage [image create photo -file $jprefs(rost,bgImagePath)]
	    }]} {
		set bgImage ""
	    }
	}
	if {$bgImage == ""} {
	    # Default and fallback..
	    set bgImage [::Theme::GetImage [option get $w backgroundImage {}]]
	}
	if {$bgImage != ""} {
	    lappend opts -backgroundimage $bgImage
	}
    }
    set rootOpts [list  \
      -background   [option get $w rootBackground {}] \
      -backgroundbd [option get $w rootBackgroundBd {}] \
      -foreground   [option get $w rootForeground {}]]
    
    eval {
	::tree::tree $wtree -width 100 -height 100 -silent 1  \
	  -sortcommand {lsort -dictionary} -sortlevels {0} \
	  -scrollwidth 400  \
	  -xscrollcommand [list ::UI::ScrollSet $wxsc \
	  [list grid $wxsc -row 1 -column 0 -sticky ew]]  \
	  -yscrollcommand [list ::UI::ScrollSet $wysc \
	  [list grid $wysc -row 0 -column 1 -sticky ns]]  \
	  -selectcommand [namespace current]::SelectCmd   \
	  -doubleclickcommand [namespace current]::DoubleClickCmd  \
	  -eventlist [list [list <<ButtonPopup>> [namespace current]::Popup]]
    } $opts
    
    if {[string match "mac*" $this(platform)]} {
	$wtree configure -buttonpresscommand [namespace current]::Popup
    }

    scrollbar $wxsc -orient horizontal -command [list $wtree xview]
    scrollbar $wysc -orient vertical -command [list $wtree yview]
    grid $wtree -row 0 -column 0 -sticky news
    grid $wysc  -row 0 -column 1 -sticky ns
    grid $wxsc  -row 1 -column 0 -sticky ew
    grid columnconfigure $wbox 0 -weight 1
    grid rowconfigure    $wbox 0 -weight 1
    
    set dirImage     [::Theme::GetImage [option get $wtree dirImage {}]]
    set onlineImage  [::Theme::GetImage [option get $wtree onlineImage {}]]
    set offlineImage [::Theme::GetImage [option get $wtree offlineImage {}]]
    
    # Add root tree dirs.
    eval {$wtree newitem [list $dirNameArr(online)] -dir 1 -text [mc Online] \
      -tags head -image $onlineImage} $rootOpts
    eval {$wtree newitem [list $dirNameArr(offline)] -dir 1 -text [mc Offline] \
      -tags head -image $offlineImage} $rootOpts
    foreach gpres $closedTreeDirs {
	$wtree itemconfigure [list $gpres] -open 0
    }
    return $w
}

proc ::Roster::GetWtree { } {
    variable wtree
    
    return $wtree
}

proc ::Roster::Animate {{step 1}} {
    variable wwave
    
    $wwave animate $step
}

proc ::Roster::Message {str} {
    variable wwave
    
    $wwave message $str
}

proc ::Roster::TimedMessage {str} {
    variable timer
    
    if {[info exists timer(msg)]} {
	after cancel $timer(msg)
    }
    Message $str
    after $timer(msg,ms) [namespace current]::CancelTimedMessage
}

proc ::Roster::CancelTimedMessage { } {
    Message ""
}

proc ::Roster::SetPresenceMessage {jid presence args} {
    variable mapShowTextToElem
    
    array set argsArr $args
    set show $presence
    if {[info exists argsArr(-show)]} {
	set show $argsArr(-show)
    }
    set name [GetDisplayName $jid]
    set str [mc {%s is %s} $name $mapShowTextToElem($show)]
    TimedMessage $str
}

# Roster::LoginCmd --
# 
#       The login hook command.

proc ::Roster::LoginCmd { } {
    
    ::Jabber::JlibCmd roster_get ::Roster::PushProc

    set server [::Jabber::GetServerJid]
    set ::Roster::servtxt $server
    SetUIWhen "connect"
}

proc ::Roster::LogoutHook { } {
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    SetUIWhen "disconnect"

    # Clear roster and browse windows.
    $jstate(roster) reset
    if {$jprefs(rost,clrLogout)} {
	Clear
    }
}

proc ::Roster::SetBackgroundImage {useBgImage bgImagePath} {
    upvar ::Jabber::jprefs jprefs
    variable wtree    
    variable wroster
    
    if {[winfo exists $wtree]} {
	
	# Change only if needed.
	if {($jprefs(rost,useBgImage) != $useBgImage) || \
	  ($jprefs(rost,bgImagePath) != $bgImagePath)} {
	    
	    if {$useBgImage} {
		set bgImage ""
		if {[file exists $bgImagePath]} {
		    if {[catch {
			set bgImage [image create photo -file $bgImagePath]
		    }]} {
			set bgImage ""
		    }
		}
		if {$bgImage == ""} {
		    # Default and fallback..
		    set bgImage [::Theme::GetImage [option get $wroster backgroundImage {}]]
		}
	    } else {
		set bgImage ""
	    }
	    $wtree configure -backgroundimage $bgImage
	}
    }
}

proc ::Roster::CloseDlg {w} {    

    catch {wm withdraw $w}
    set jstate(rosterVis) 0
}

proc ::Roster::Refresh { } {
    variable wwave

    # Get my roster.
    ::Jabber::JlibCmd roster_get [namespace current]::PushProc
    $wwave animate 1
}

# Roster::SendRemove --
#
#       Method to remove another user from my roster.
#
#

proc ::Roster::SendRemove {jidrm} {    
    variable selItem
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Roster::SendRemove jidrm=$jidrm"

    if {[string length $jidrm]} {
	set jid $jidrm
    } else {
	set jid [lindex $selItem end]
    }
    set ans [::UI::MessageBox -title [mc {Remove Item}] \
      -message [mc jamesswarnremove] -icon warning -type yesno -default no]
    if {[string equal $ans "yes"]} {
	$jstate(jlib) roster_remove $jid [namespace current]::PushProc
    }
}

# Roster::SelectCmd --
#
#       Callback when selecting roster item in tree.
#
# Arguments:
#       w           tree widget
#       v           tree item path
#       
# Results:
#       button states set set.

proc ::Roster::SelectCmd {w v} {    
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

# Roster::DoubleClickCmd --
#
#       Callback when double clicking roster item in tree.
#
# Arguments:
#       w           tree widget
#       v           tree item path
#       
# Results:
#       button states set set.

proc ::Roster::DoubleClickCmd {w v} {
    upvar ::Jabber::jprefs jprefs

    if {[llength $v] && ([$w itemconfigure $v -dir] == 0)} {
	
	# According to XMPP def sect. 4.1, we should use user@domain when
	# initiating a new chat or sending a new message that is not a reply.
	set jid [lindex $v end]
	jlib::splitjid $jid jid2 res
	if {[string equal $jprefs(rost,dblClk) "normal"]} {
	    ::NewMsg::Build -to $jid2
	} else {
	    
	    # We let Chat handle this internally.
	    ::Chat::StartThread $jid
	}
    }    
}
    
# Roster::RegisterPopupEntry --
# 
#       Components or plugins can add their own menu entries here.

proc ::Roster::RegisterPopupEntry {menuSpec} {
    variable popMenuDefs
    
    # Keeps track of all registered menu entries.
    variable regPopMenuSpec
    
    # Index of last separator.
    set ind [lindex [lsearch -all $popMenuDefs(roster,def) "separator"] end]
    if {![info exists regPopMenuSpec]} {
	
	# Add separator if this is the first addon entry.
	incr ind 3
	set popMenuDefs(roster,def) [linsert $popMenuDefs(roster,def)  \
	  $ind {separator} {} {}]
	set regPopMenuSpec {}
	set ind [lindex [lsearch -all $popMenuDefs(roster,def) "separator"] end]
    }
    
    # Add new entry just before the last separator
    set v $popMenuDefs(roster,def)
    set popMenuDefs(roster,def) [concat [lrange $v 0 [expr $ind-1]] $menuSpec \
      [lrange $v $ind end]]
    set regPopMenuSpec [concat $regPopMenuSpec $menuSpec]
}

# Roster::Popup --
#
#       Handle popup menu in roster.
#       
# Arguments:
#       w           widget that issued the command: tree or text
#       v           for the tree widget it is the item path, 
#                   for text the jidhash.
#       
# Results:
#       popup menu displayed

proc ::Roster::Popup {w v x y} {
    global  wDlgs this
    variable popMenuDefs
    
    upvar ::Jabber::jstate jstate
    
    ::Debug 2 "::Roster::Popup w=$w, v='$v'"
    
    # This is either online or offline.
    set status [string tolower [lindex $v 0]]

    # The last element of 'v' can be a head, group, or a user (jid).
    set item [lindex $v end]

    set clicked {}
    if {[llength $v]} {
	set tags [$w itemconfigure $v -tags]
    } else {
	set tags ""
    }
    
    # The commands require a number of variables to be defined:
    #       jid, jid3, group, clicked...
    # 
    # These may be lists of jid's if not an individual user was clicked.
    # We use jid3 for the actual content even if only jid2, 
    # and strip off any resource parts for jid (jid2).
    set jid3 {}
    set group {}
    if {[lsearch $tags user] >= 0} {
	set jid3 $item
	lappend clicked user
	if {[IsCoccinella $jid3]} {
	    lappend clicked wb
	}
    } elseif {[lsearch $tags head] >= 0} {
	if {[lsearch $tags trpt] >= 0} {
	    # empty
	} else {
	    lappend clicked head
	    set jid3 [GetAllUsersInItem $w $v]
	}
    } elseif {[lsearch $tags group] >= 0} {
	lappend clicked group
	set jid3 [GetAllUsersInItem $w $v]
	set group $item
    } elseif {[lsearch $tags trpt] >= 0} {
	lappend clicked trpt
	set jid3 $item
	# Transports in own directory.
	if {[$jstate(roster) isavailable $jid3]} {
	    set status online
	} else {
	    set status offline
	}
    }
        
    # Make jid (jid2) of all jid3.
    set jid {}
    foreach u $jid3 {
	jlib::splitjid $u jid2 res
	lappend jid $jid2
    }
    
    ::Debug 2 "\t jid=$jid, jid3=$jid3, clicked=$clicked, status=$status"
        
    # Make the appropriate menu.
    set m $jstate(wpopup,roster)
    set i 0
    catch {destroy $m}
    menu $m -tearoff 0
    
    set menuDef $popMenuDefs(roster,def)	
    foreach click $clicked {
	if {[info exists popMenuDefs(roster,$click,def)]} {
	    set menuDef $popMenuDefs(roster,$click,def)
	}
    }
    
    foreach {item type cmd} $menuDef {
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
	if {![::Jabber::IsConnected] && ([lsearch $type always] < 0)} {
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
	
	# If any online/offline these must also be fulfilled.
	if {[lsearch $type online] >= 0} {
	    if {$status != "online"} {
		set state disabled
	    }
	} elseif {[lsearch $type offline] >= 0} {
	    if {$status != "offline"} {
		set state disabled
	    }
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

proc ::Roster::GetAllUsersInItem {w v} {
    
    set jid3 {}
    foreach u [$w children $v] {
	set ipath [concat $v [list $u]]
	set c [$w children $ipath]
	if {[llength $c] > 0} {
	    set iipath [concat $ipath [list $c]]
	    if {[lsearch [$w itemconfigure $iipath -tags] user] >= 0} {
		lappend jid3 $c
	    }
	} else {
	    if {[lsearch [$w itemconfigure $ipath -tags] user] >= 0} {
		lappend jid3 $u
	    }
	}
    }
    return $jid3
}

# Roster::PushProc --
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

proc ::Roster::PushProc {rostName what {jid {}} args} {    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Debug 2 "--roster-> rostName=$rostName, what=$what, jid=$jid, \
      args='$args'"

    # Extract the args list as an array.
    array set attrArr $args
        
    switch -- $what {
	presence {
	    
	    # If no 'type' attribute given "available" is default.
	    set type "available"
	    if {[info exists attrArr(-type)]} {
		set type $attrArr(-type)
	    }
	    
	    # We may get presence 'available' with empty resource (ICQ)!
	    set jid3 $jid
	    if {[info exists attrArr(-resource)] &&  \
	      [string length $attrArr(-resource)]} {
		set jid3 ${jid}/$attrArr(-resource)
	    }	    
	    if {![$jstate(jlib) service isroom $jid]} {
		eval {Presence $jid3 $type} $args
	    }
	    
	    # General type presence hooks.
	    eval {::hooks::run presenceHook $jid $type} $args

	    # Specific type presence hooks.
	    eval {::hooks::run presence[string totitle $type]Hook $jid $type} $args
	    
	    # Make an additional call for delayed presence.
	    # This only happend when type='available'.
	    if {[info exists attrArr(-x)]} {
		set delayElem [wrapper::getnamespacefromchilds  \
		  $attrArr(-x) x "jabber:x:delay"]
		if {[llength $delayElem]} {
		    eval {::hooks::run presenceDelayHook $jid $type} $args
		}
	    }
	}
	remove {
	    
	    # Must remove all resources, and jid2 if no resources.
    	    set resList [$jstate(roster) getresources $jid]
	    foreach res $resList {
	        Remove ${jid}/${res}
	    }
	    if {$resList == ""} {
	        Remove $jid
	    }
	    RemoveEmptyRootDirs
	}
	set {
	    eval {SetItem $jid} $args
	}
	enterroster {
	    set jstate(inroster) 1
	    Clear
	}
	exitroster {
	    set jstate(inroster) 0
	    ExitRoster
	}
    }
}

# Roster::Clear --
#
#       Clears the complete tree from all jid's and all groups.
#
# Arguments:
#       
# Results:
#       clears tree.

proc ::Roster::Clear { } {    
    variable wtree    
    variable dirNameArr

    ::Debug 2 "::Roster::Clear"

    foreach v [$wtree find withtag head] {
	$wtree delitem $v -childsonly 1
    }
    catch {
	$wtree delitem [list $dirNameArr(pending)]
	$wtree delitem [list $dirNameArr(transports)]
    }
}

proc ::Roster::ExitRoster { } {
    variable wwave
    variable timer

    ::Jabber::UI::SetStatusMessage [mc jarostupdate]
    $wwave animate -1
    set timer(exitroster,secs) [clock seconds]
    
    # Should perhaps fix the directories of the tree widget, such as
    # appending (#items) for each headline.
}

# Roster::SetItem --
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

proc ::Roster::SetItem {jid args} {    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Roster::SetItem jid=$jid, args='$args'"
    
    # Remove any old items first:
    # 1) If we 'get' the roster, the roster is cleared, so we can be
    #    sure that we don't have any "old" item???
    # 2) Must remove all resources for this jid first, and then add back.
    #    Remove also jid2.
    if {!$jstate(inroster)} {
    	set resList [$jstate(roster) getresources $jid]
	foreach res $resList {
	    Remove ${jid}/${res}
	}
	if {$resList == ""} {
	    Remove $jid
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
	::Debug 2 "\t presenceList=$presenceList"
	
	foreach pres $presenceList {
	    unset -nocomplain presArr
	    array set presArr $pres
	    
	    # Put in our roster tree.
	    eval {PutItemInTree $jid $presArr(-type)} \
	      $args $pres
	}
    }
    RemoveEmptyRootDirs
}

# Roster::Presence --
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

proc ::Roster::Presence {jid presence args} {
    variable timer
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate

    ::Debug 2 "::Roster::Presence jid=$jid, presence=$presence, args='$args'"
    array set argsArr $args

    # All presence have a 3-tier jid as 'from' attribute:
    # presence = 'available'   => remove jid2 + jid3,  add jid3
    # presence = 'unavailable' => remove jid2 + jid3,  add jid2
    #                                                  if no jid2/* available
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
    Remove $jid
    
    # Put in our roster tree.
    if {[string equal $presence "unsubscribed"]} {
	set treePres "unavailable"
	if {$jprefs(rost,rmIfUnsub)} {
	    
	    # Must send a subscription remove here to get rid if it completely??
	    # Think this is already been made from our presence callback proc.
	    #$jstate(jlib) roster_remove $jid ::Roster::PushProc
	} else {
	    eval {PutItemInTree $jid2 $treePres} \
	      $itemAttr $args
	}
    } elseif {[string equal $presence "unavailable"]} {
	set treePres $presence
	
	# XMPP specifies that an 'unavailable' element is sent *after* 
	# we've got an subscription='remove' element. Skip it!
	# Problems with transports that have /registered.
	set mjid2 [jlib::jidmap $jid2]
	set users [$jstate(roster) getusers]
	if {([lsearch $users $mjid2] < 0) && ([lsearch $users $jid] < 0)} {
	    return
	}
	
	# Add only if no other jid2/* available.
	set isavailable [$jstate(roster) isavailable $jid2]
	if {!$isavailable} {
	    eval {PutItemInTree $jid2 $treePres} $itemAttr $args
	}
    } else {
	set treePres $presence
	eval {PutItemInTree $jid2 $treePres} $itemAttr $args
    }
    RemoveEmptyRootDirs
    
    # We set timed messages for presences only if significantly after login.
    if {[expr [clock seconds] - $timer(exitroster,secs)] > $timer(pres,secs)} {
	eval {SetPresenceMessage $jid $presence} $args
    }
}

# Roster::Remove --
#
#       Removes a jid item from all groups in the tree.
#
# Arguments:
#       jid         can be 2-tier or 3-tier jid!
#       
# Results:
#       updates tree.

proc ::Roster::Remove {jid} {    
    variable wtree    
    
    ::Debug 2 "::Roster::Remove, jid=$jid"
    
    # If have 3-tier jid:
    #    presence = 'available'   => remove jid2 + jid3
    #    presence = 'unavailable' => remove jid2 + jid3
    # Else if 2-tier jid:  => remove jid2
    
    jlib::splitjid $jid jid2 res
    set mjid2 [jlib::jidmap $jid2]

    foreach v [$wtree find withtag $mjid2] {
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
	set mjid3 [jlib::jidmap $jid]
	foreach v [$wtree find withtag $mjid3] {
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

# Roster::RemoveEmptyRootDirs --
# 
#       Cleanup empty pending and transports dirs.

proc ::Roster::RemoveEmptyRootDirs { } {
    variable wtree    
    variable dirNameArr
    
    foreach key {pending transports} {
	set name $dirNameArr($key)
	if {[$wtree isitem [list $name]] && \
	  [llength [$wtree children [list $name]]] == 0} {
	    $wtree delitem [list $name]
	}
    }
}

# Roster::SetCoccinella --
# 
#       Sets the roster icon of The Coccinella.

proc ::Roster::SetCoccinella {jid} {
    variable wtree    
    upvar ::Jabber::jstate jstate
    
    ::Debug 4 "::Roster::SetCoccinella jid=$jid"
    
    set mjid [jlib::jidmap $jid]
    set icon [GetPresenceIconFromJid $jid]
    foreach v [$wtree find withtag $mjid] {
	$wtree itemconfigure $v -image $icon
    }
}

# Roster::IsCoccinella --
# 
#       Utility function to figure out if we have evidence that jid3 is a 
#       Coccinella.
#       NOTE: some entities (transports) return private presence elements
#       when sending their presence! Workaround! BAD!!!

proc ::Roster::IsCoccinella {jid3} {
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::coccixmlns coccixmlns
    upvar ::Jabber::xmppxmlns xmppxmlns
    
    set ans 0
    if {![IsTransportHeuristics $jid3]} {
	set node [$jstate(roster) getcapsattr $jid3 node]
	if {[string equal $node $coccixmlns(caps)]} {
	    set ans 1
	} elseif {[$jstate(browse) hasnamespace $jid3 "coccinella:wb"] || \
	  [$jstate(browse) hasnamespace $jid3 $coccixmlns(whiteboard)]} {
	    set ans 1
	} elseif {[$jstate(disco) hasfeature $coccixmlns(whiteboard) $jid3] || \
	  [$jstate(disco) hasfeature $coccixmlns(coccinella) $jid3]} {
	    set ans 1
	}
    }
    return $ans
}

# Roster::PutItemInTree --
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

proc ::Roster::PutItemInTree {jid presence args} {    
    variable wtree    
    variable treeuid
    variable presToNameArr
    variable dirNameArr
    variable mapShowElemToText
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    ::Debug 3 "::Roster::PutItemInTree jid=$jid, presence=$presence, args='$args'"

    array set argsArr $args
    
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
    
    set server [jlib::jidmap $jserver(this)]

    set jidx $jid
    set jid3 $jid
    if {[info exists argsArr(-resource)] && ($argsArr(-resource) != "")} {
	set jid3 ${jid2}/$argsArr(-resource)
	if {[string equal $presence "available"]} {
	    set appstr " ($argsArr(-resource))"
	    set jidx ${jid2}/$argsArr(-resource)
	}
    }
    set mjid [jlib::jidmap $jidx]
    ::Debug 5 "\t jidx=$jidx"

    set istrpt [IsTransportHeuristics $jid3]

    # Make display text (itemstr).
    if {$istrpt} {
	set itemstr $jid3
	if {[info exists argsArr(-show)]} {
	    set show $argsArr(-show)
	    if {[info exists mapShowElemToText($show)]} {
		append itemstr " ($mapShowElemToText($show))"
	    } else {
		append itemstr " ($show)"
	    }
	} elseif {[info exists argsArr(-status)]} {
	    append itemstr " ($argsArr(-status))"
	}
    } else {
	if {[info exists argsArr(-name)] && ($argsArr(-name) != "")} {
	    set itemstr $argsArr(-name)
	} elseif {[regexp "^(\[^@\]+)@${server}" $jid match user]} {
	    set itemstr $user
	} else {
	    set itemstr $jid2
	}
	if {[info exists appstr]} {
	    append itemstr $appstr
	}
    }
    set treectag item[incr treeuid]    
    set itemOpts   [list -text $itemstr -canvastags $treectag]    
    set icon       [eval {GetPresenceIcon $jidx $presence} $args]
    set groupImage [::Theme::GetImage [option get $wtree groupImage {}]]
    set presName   $presToNameArr($presence)
    
    if {$istrpt} {
	
	# Transports are treated specially.
	set transports $dirNameArr(transports)
	if {![$wtree isitem [list $transports]]} {
	    $wtree newitem [list $transports] -tags {head trpt} -dir 1 \
	      -text [mc $transports]
	}
	set tags [list trpt $jid3]
	eval {$wtree newitem [list $transports $jid3] -image $icon -tags $tags} \
	  $itemOpts
    } elseif {[info exists argsArr(-ask)] &&  \
      [string equal $argsArr(-ask) "subscribe"]} {
	
	# If we have an ask attribute, put in Pending tree dir.
	# Make it if not already exists.
	set pending $dirNameArr(pending)
	if {![$wtree isitem [list $pending]]} {
	    $wtree newitem [list $pending] -tags head -dir 1 \
	      -text [mc $pending]
	}
	set tags [list user $mjid]
	eval {$wtree newitem [list $pending $jid] -image $icon -tags $tags} \
	  $itemOpts
    } elseif {[info exists argsArr(-groups)] && ($argsArr(-groups) != "")} {
	set groups $argsArr(-groups)
	
	# Add jid for each group.
	foreach grp $groups {
	    
	    # Make group if not exists already.
	    set childs [$wtree children [list $presName]]
	    if {[lsearch -exact $childs $grp] < 0} {
		$wtree newitem [list $presName $grp] -dir 1 \
		  -tags group -image $groupImage
	    }
	    set tags [list user $mjid]
	    eval {$wtree newitem [list $presName $grp $jidx] -image $icon \
	      -tags $tags} $itemOpts
	}
    } else {
	
	# No groups associated with this item.
	set tags [list user $mjid]
	eval {$wtree newitem [list $presName $jidx] -image $icon -tags $tags} \
	  $itemOpts
    }
    
    # Design the balloon help window message.
    eval {BalloonMsg $jidx $presence $treectag} $args
}

proc ::Roster::BalloonMsg {jidx presence treectag args} {
    variable wtree    
    variable mapShowElemToText
    variable presToNameArr
    upvar ::Jabber::jstate jstate

    array set argsArr $args
    
    # Design the balloon help window message.
    set msg "${jidx}: $presToNameArr($presence)"
    if {[string equal $presence "available"]} {
	set delay [$jstate(roster) getx $jidx "jabber:x:delay"]
	if {$delay != ""} {
	    
	    # An ISO 8601 point-in-time specification. clock works!
	    set stamp [wrapper::getattribute $delay stamp]
	    set tstr [::Utils::SmartClockFormat [clock scan $stamp -gmt 1]]
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

# Roster::SetUIWhen --
#
#       Update the roster buttons etc to reflect the current state.
#
# Arguments:
#       what        any of "connect", "disconnect"
#

proc ::Roster::SetUIWhen {what} {    
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

proc ::Roster::GetPresenceIconFromKey {key} {

    return [::Rosticons::Get status/$key]
}

# Roster::GetPresenceIconFromJid --
# 
#       Returns presence icon from jid, typically a full jid.

proc ::Roster::GetPresenceIconFromJid {jid} {
    upvar ::Jabber::jstate jstate
    
    jlib::splitjid $jid jid2 res
    if {$res == ""} {
	set pres [lindex [$jstate(roster) getpresence $jid2] 0]
    } else {
	set pres [$jstate(roster) getpresence $jid2 -resource $res]
    }
    set rost [$jstate(roster) getrosteritem $jid2]
    array set argsArr $pres
    array set argsArr $rost
    
    return [eval {GetPresenceIcon $jid $argsArr(-type)} [array get argsArr]]
}

# Roster::GetPresenceIcon --
#
#       Returns the image appropriate for 'presence', and any 'show' attribute.
#       If presence is to make sense, the jid shall be a 3-tier jid.

proc ::Roster::GetPresenceIcon {jid presence args} {    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    array set argsArr $args
    
    ::Debug 5 "GetPresenceIcon jid=$jid, presence=$presence, args=$args"
    
    # Construct the 'type/sub' specifying the icon.
    set itype status
    set isub  $presence
    
    # Then see if any <show/> element
    if {[info exists argsArr(-subscription)] &&   \
      [string equal $argsArr(-subscription) "none"]} {
	set isub "ask"
    } elseif {[info exists argsArr(-ask)] &&   \
      [string equal $argsArr(-ask) "subscribe"]} {
	set isub "ask"
    } elseif {[info exists argsArr(-show)]} {
	set isub $argsArr(-show)
    }
    
    # Foreign IM systems.
    set foreign 0
    if {$jprefs(rost,haveIMsysIcons)} {
	jlib::splitjidex $jid user host res
	if {![string equal $host $jserver(this)]} {
	
	    # If empty we have likely not yet browsed etc.
	    set cattype [$jstate(jlib) service gettype $host]
	    set subtype [lindex [split $cattype /] 1]
	    if {[lsearch -exact [::Rosticons::GetTypes] $subtype] >= 0} {
		set itype $subtype
		set foreign 1
	    }
	}
    }   
    
    # If whiteboard:
    if {!$foreign && ($presence == "available") && [IsCoccinella $jid]} {
	set itype "whiteboard"
    }
    
    return [::Rosticons::Get $itype/$isub]
}

proc ::Roster::GetMyPresenceIcon { } {

    set status [::Jabber::GetMyStatus]
    return [::Rosticons::Get status/$status]
}

proc ::Roster::DirectedPresenceDlg {jid} {
    global  this wDlgs
    
    variable uid
    
    # Initialize the state variable, an array, that keeps is the storage.
    
    set token [namespace current]::dirpres[incr uid]
    variable $token
    upvar 0 $token state

    set w $wDlgs(jdirpres)$uid
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w [mc {Set Directed Presence}]
    set state(finished) -1
    set state(w)        $w
    set state(jid)      $jid
    set state(status) available
    bind $w <Destroy> [list [namespace current]::DirectedPresenceFree $token %W]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1

    label $w.frall.lmsg -wraplength 200 -justify left -text  \
      [mc jadirpresmsg $jid]
    pack  $w.frall.lmsg -side top -anchor w -padx 4 -pady 1
    
    set fr $w.frall.fstat
    pack [frame $fr -bd 0] -side top -fill x
    pack [label $fr.l -text "[mc Status]:"] -side left -padx 8
    set wmb $fr.mb

    ::Jabber::Status::MenuButton $wmb $token\(status)
    
    pack $wmb -side left -padx 2 -pady 2
    
    # Any status message.   
    pack [label $w.frall.lstat -text "[mc {Status message}]:"]  \
      -side top -anchor w -padx 8 -pady 2
    set wtext $w.frall.txt
    text $wtext -width 40 -height 2 -wrap word
    pack $wtext -side top -padx 8 -pady 2
    set state(wtext) $wtext
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [mc Set] -default active \
      -command [list [namespace current]::SetDirectedPresence $token]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel]  \
      -command [list destroy $w]] \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> {}
	
    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $w.frall.lmsg $w]    
    after idle $script
}

proc ::Roster::SetDirectedPresence {token} {
    variable $token
    upvar 0 $token state
    
    set opts {}
    set allText [string trim [$state(wtext) get 1.0 end] " \n"]
    if {[string length $allText]} {
	set opts [list -status $allText]
    }  
    eval {::Jabber::SetStatus $state(status) -to $state(jid)} $opts
    destroy $state(w)
}

proc ::Roster::DirectedPresenceFree {token w} {
    variable $token
    upvar 0 $token state
    
    if {[string equal [winfo toplevel $w] $w]} {
	unset state
    }
}

proc ::Roster::LoginTrpt {jid3} {
    
    ::Jabber::SetStatus available -to $jid3
}

proc ::Roster::LogoutTrpt {jid3} {
    
    ::Jabber::SetStatus unavailable -to $jid3    
}

# Roster::BrowseSetHook, DiscoInfoHook --
# 
#       It is first when we have obtained either browse or disco info it is
#       possible to set icons of foreign IM users.

proc ::Roster::BrowseSetHook {from subiq} {
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jserver jserver
    
    # Fix icons of foreign IM systems.
    if {$jprefs(rost,haveIMsysIcons)} {
	PostProcessIcons browse $from
    }
}

proc ::Roster::DiscoInfoHook {type from subiq args} {
    variable wtree    
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    if {$type == "error"} {
	return
    }
    if {$jprefs(rost,haveIMsysIcons)} {
	PostProcessIcons disco $from
    }
}

# Roster::PostProcessIcons --
# 
#       This is necessary to get icons for foreign IM systems set correctly.
#       Usually we get the roster before we've got browse/agents/disco 
#       info, so we cannot know if an item is an ICQ etc. when putting it
#       into the roster.
#       
#       Browse and disco return this information differently:
#         browse:  from=login server
#         disco:   from=each specific component
#         
# Arguments:
#       method      "browse" or "disco"
#       
# Results:
#       none.

proc ::Roster::PostProcessIcons {method from} {
    variable wtree    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    if {[string equal $method "browse"]} {
	if {![jlib::jidequal $from $jserver(this)]} {
	    return
	}
	set matchHost 0
    } else {
	set matchHost 1	
    }
    ::Debug 5 "::Roster::PostProcessIcons $from"
    
    set server [jlib::jidmap $jserver(this)]

    foreach v [$wtree find withtag all] {
	set tags [$wtree itemconfigure $v -tags]
	if {$tags == ""} {
	    continue
	}
	if {([lsearch $tags head] >= 0) || ([lsearch $tags group] >= 0)} {
	    continue
	}
	set jid [lindex $v end]
	set mjid [jlib::jidmap $jid]
	jlib::splitjidex $mjid username host res
	
	# Only relevant jid's. Must have full jid here!
	# Exclude jid's that belong to our login jabber server.
	if {![string equal $server $host]} {
	    
	    # Browse always, disco only if from=host.
	    if {!$matchHost || [string equal $from $host]} {
		set icon [GetPresenceIconFromJid $jid]
		if {[string length $icon]} {
		    $wtree itemconfigure $v -image $icon
		}
	    }
	}	
    }   
}

proc ::Roster::ConfigureIcon {v} {

}

#--- Transport utilities -------------------------------------------------------

namespace eval ::Roster:: {
    
    # name description ...
    # Excluding smtp since it works differently.
    variable trptToAddressName {
	jabber      {Jabber Id}
	icq         {ICQ (number)}
	aim         {AIM}
	msn         {MSN}
	yahoo       {Yahoo}
	irc         {IRC}
	x-gadugadu  {Gadu-Gadu}
    }
    variable trptToName {
	jabber      {Jabber}
	icq         {ICQ}
	aim         {AIM}
	msn         {MSN}
	yahoo       {Yahoo}
	irc         {IRC}
	x-gadugadu  {Gadu-Gadu}
    }
    variable nameToTrpt {
	{Jabber}           jabber
	{ICQ}              icq
	{AIM}              aim
	{MSN}              msn
	{Yahoo}            yahoo
	{IRC}              irc
	{Gadu-Gadu}        x-gadugadu
    }
    
    variable  trptToNameArr
    array set trptToNameArr $trptToName
    
    variable  nameToTrptArr
    array set nameToTrptArr $nameToTrpt
    
    variable allTransports {}
    foreach {name spec} $trptToName {
	lappend allTransports $name
    }
}

proc ::Roster::GetNameFromTrpt {trpt} {
    variable  trptToNameArr
   
    if {[info exists trptToNameArr($trpt)]} {
	return $trptToNameArr($trpt)
    } else {
	return $trpt
    }
}

proc ::Roster::GetTrptFromName {type} {
    variable nameToTrptArr
   
    if {[info exists nameToTrptArr($type)]} {
	return $nameToTrptArr($type)
    } else {
	return $type
    }
}

# Roster::GetAllTransportJids --
# 
#       Method to get the jids of all services that are not jabber.

proc ::Roster::GetAllTransportJids { } {
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jstate jstate
    
    set alltrpts [$jstate(jlib) service gettransportjids *]
    set jabbjids [$jstate(jlib) service gettransportjids jabber]
    
    # Exclude jabber services and login server.
    foreach jid $jabbjids {
	set alltrpts [lsearch -all -inline -not $alltrpts $jid]
    }
    return [lsearch -all -inline -not $alltrpts $jserver(this)]
}

proc ::Roster::GetTransportNames {token} {
    variable $token
    upvar 0 $token state
    variable trptToName
    variable allTransports
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jserver jserver
    
    # We must be indenpendent of method; agent, browse, disco
    set trpts {}
    foreach subtype $allTransports {
	set jids [$jstate(jlib) service gettransportjids $subtype]
	if {[llength $jids]} {
	    lappend trpts $subtype
	    set state(servicejid,$subtype) [lindex $jids 0]
	}
    }    

    # Disco doesn't return jabber. Make sure it's first.
    set trpts [lsearch -all -not -inline $trpts jabber]
    set trpts [concat jabber $trpts]
    set state(servicejid,jabber) $jserver(this)

    array set arr $trptToName
    set names {}
    foreach name $trpts {
	lappend names $arr($name)
    }
    return $names
}

proc ::Roster::IsTransport {jid} {
    upvar ::Jabber::jstate jstate
    
    # Some transports (icq) have a jid = icq.jabber.se/registered
    # in the roster, but where we get the 2-tier part. Get 3-tier jid.
    set transport 0
    if {![catch {jlib::splitjidex $jid node host res}]} {
	if {([lsearch [GetAllTransportJids] $host] >= 0) && ($node == "")} {    
	    set transport 1
	}
    }    
    return $transport
}

# This is a really BAD thing to do but I there seems to be no robust method.

proc ::Roster::IsTransportHeuristics {jid} {
    upvar ::Jabber::jstate jstate
    
    # Some transports (icq) have a jid = icq.jabber.se/registered.
    # Others, like MSN, have a jid = msn.jabber.ccc.de.
    set transport 0
    if {![catch {jlib::splitjidex $jid node host res}]} {
	if {($node == "") && ($res == "registered")} {
	    set transport 1
	}
    }
    if {!$transport} {
	set transport [IsTransport $jid]
    }
    return $transport
}

# Prefs page ...................................................................

proc ::Roster::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    
    # Defaults...
    set jprefs(rost,rmIfUnsub)      1
    set jprefs(rost,allowSubNone)   1
    set jprefs(rost,clrLogout)      1
    set jprefs(rost,dblClk)         normal
    
    # Show special icons for foreign IM systems?
    set jprefs(rost,haveIMsysIcons) 1
	
    ::PreferencesUtils::Add [list  \
      [list ::Jabber::jprefs(rost,clrLogout)   jprefs_rost_clrRostWhenOut $jprefs(rost,clrLogout)]  \
      [list ::Jabber::jprefs(rost,dblClk)      jprefs_rost_dblClk       $jprefs(rost,dblClk)]  \
      [list ::Jabber::jprefs(rost,rmIfUnsub)   jprefs_rost_rmIfUnsub    $jprefs(rost,rmIfUnsub)]  \
      [list ::Jabber::jprefs(rost,allowSubNone) jprefs_rost_allowSubNone $jprefs(rost,allowSubNone)]  \
      [list ::Jabber::jprefs(rost,haveIMsysIcons)   jprefs_rost_haveIMsysIcons    $jprefs(rost,haveIMsysIcons)]  \
      ]
    
}

proc ::Roster::BuildPrefsHook {wtree nbframe} {
    
    $wtree newitem {Jabber Roster} -text [mc Roster]
        
    # Roster page ----------------------------------------------------------
    set wpage [$nbframe page {Roster}]
    BuildPageRoster $wpage
}

proc ::Roster::BuildPageRoster {page} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs

    set ypad [option get [winfo toplevel $page] yPad {}]
    
    foreach key {rmIfUnsub allowSubNone clrLogout dblClk haveIMsysIcons} {
	set tmpJPrefs(rost,$key) $jprefs(rost,$key)
    }

    checkbutton $page.rmifunsub -text " [mc prefrorm]"  \
      -variable [namespace current]::tmpJPrefs(rost,rmIfUnsub)
    checkbutton $page.allsubno -text " [mc prefroallow]"  \
      -variable [namespace current]::tmpJPrefs(rost,allowSubNone)
    checkbutton $page.clrout -text " [mc prefroclr]"  \
      -variable [namespace current]::tmpJPrefs(rost,clrLogout)
    checkbutton $page.dblclk -text " [mc prefrochat]" \
      -variable [namespace current]::tmpJPrefs(rost,dblClk)  \
      -onvalue chat -offvalue normal
    checkbutton $page.sysicons -text " [mc prefrosysicons]" \
      -variable [namespace current]::tmpJPrefs(rost,haveIMsysIcons)
    
    pack $page.rmifunsub $page.allsubno $page.clrout $page.dblclk  \
      $page.sysicons -side top -anchor w -pady $ypad -padx 10
}

proc ::Roster::SavePrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    array set jprefs [array get tmpJPrefs]
    unset tmpJPrefs
}

proc ::Roster::CancelPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	if {![string equal $jprefs($key) $tmpJPrefs($key)]} {
	    ::Preferences::HasChanged
	    break
	}
    }
}

proc ::Roster::UserDefaultsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	set tmpJPrefs($key) $jprefs($key)
    }
}

#-------------------------------------------------------------------------------
