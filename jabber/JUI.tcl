#  JUI.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements jabber GUI parts.
#      
#  Copyright (c) 2001-2004  Mats Bengtsson
#  
# $Id: JUI.tcl,v 1.43 2004-06-16 14:17:30 matben Exp $

package provide JUI 1.0


namespace eval ::Jabber::UI:: {

    # Use option database for customization.
    # Shortcut buttons.
    option add *JMain.connectImage                connect         widgetDefault
    option add *JMain.connectDisImage             connectDis      widgetDefault
    option add *JMain.inboxImage                  inbox           widgetDefault
    option add *JMain.inboxDisImage               inboxDis        widgetDefault
    option add *JMain.inboxLetterImage            inboxLetter     widgetDefault
    option add *JMain.inboxLetterDisImage         inboxLetterDis  widgetDefault
    option add *JMain.newuserImage                newuser         widgetDefault
    option add *JMain.newuserDisImage             newuserDis      widgetDefault
    option add *JMain.stopImage                   stop            widgetDefault
    option add *JMain.stopDisImage                stopDis         widgetDefault
    option add *JMain.roster16Image               roster16        widgetDefault
    option add *JMain.browser16Image              browser16       widgetDefault

    # Other icons.
    option add *JMain.contactOffImage             contactOff      widgetDefault
    option add *JMain.contactOnImage              contactOn       widgetDefault
    option add *JMain.waveImage                   wave            widgetDefault
    option add *JMain.resizeHandleImage           resizehandle    widgetDefault

    option add *JMain*Tree.background             #dedede         widgetDefault
    option add *JMain*Tree.backgroundImage        {}              widgetDefault
    option add *JMain*Tree.highlightBackground    white           widgetDefault
    option add *JMain*Tree.highlightColor         black           widgetDefault
    option add *JMain*Tree.indention              14              widgetDefault
    option add *JMain*Tree.styleIcons             plusminus       widgetDefault
    option add *JMain*Tree.pyjamasColor           white           widgetDefault
    option add *JMain*Tree.selectBackground       black           widgetDefault
    option add *JMain*Tree.selectForeground       white           widgetDefault
    option add *JMain*Tree.selectMode             1               widgetDefault
    option add *JMain*Tree.treeColor              gray50          widgetDefault

    option add *JMain*MacTabnotebook.activeForeground    black        widgetDefault
    option add *JMain*MacTabnotebook.activeTabColor      #efefef      widgetDefault
    option add *JMain*MacTabnotebook.activeTabBackground #cdcdcd      widgetDefault
    option add *JMain*MacTabnotebook.activeTabOutline    black        widgetDefault
    option add *JMain*MacTabnotebook.background          white        widgetDefault
    option add *JMain*MacTabnotebook.style               mac          widgetDefault
    option add *JMain*MacTabnotebook.tabBackground       #dedede      widgetDefault
    option add *JMain*MacTabnotebook.tabColor            #cecece      widgetDefault
    option add *JMain*MacTabnotebook.tabOutline          gray20       widgetDefault

    variable treeOpts {background backgroundImage highlightBackground \
      highlightColor indention styleIcons pyjamasColor selectBackground \
      selectForeground selectMode treeColor}
    variable macTabOpts {activeForeground activeTabColor activeTabBackground \
      activeTabOutline background style tabBackground tabColor tabOutline}
    
    # Add all event hooks.
    ::hooks::add quitAppHook            ::Jabber::UI::QuitHook
    ::hooks::add loginHook              ::Jabber::UI::LoginCmd
    ::hooks::add closeWindowHook        ::Jabber::UI::CloseHook
    ::hooks::add logoutHook             ::Jabber::UI::LogoutHook
    ::hooks::add setPresenceHook        ::Jabber::UI::SetPresenceHook
    ::hooks::add groupchatEnterRoomHook ::Jabber::UI::EnterRoomHook
    ::hooks::add groupchatExitRoomHook  ::Jabber::UI::ExitRoomHook

    # Collection of useful and common widget paths.
    variable jwapp
    
    
    # Menu definitions for the Roster/services window.
    variable menuDefs
    set menuDefs(rost,file) {
	{command   mNewWhiteboard      {::Jabber::WB::NewWhiteboard}  normal   N}
	{command   mCloseWindow        {::UI::DoCloseWindow}          normal   W}
	{command   mPreferences...     {::Preferences::Build}         normal   {}}
	{separator}
	{command   mQuit               {::UserActions::DoQuit}        normal   Q}
    }
    set menuDefs(rost,jabber) {    
	{command     mNewAccount    {::Jabber::Register::Register}    normal   {}}
	{command     mLogin         {::Jabber::LoginLogout}           normal   L}
	{command     mLogoutWith    {::Jabber::Logout::WithStatus}    disabled {}}
	{command     mPassword      {::Jabber::Passwd::Build}         disabled {}}
	{separator}
	{checkbutton mMessageInbox  {::Jabber::MailBox::ShowHide}     normal   I \
	  {-variable ::Jabber::jstate(inboxVis)}}
	{separator}
	{command     mSearch        {::Jabber::Search::Build}         disabled {}}
	{command     mAddNewUser    {::Jabber::Roster::NewOrEditItem new} disabled {}}
	{separator}
	{command     mSendMessage   {::Jabber::NewMsg::Build}         disabled M}
	{command     mChat          {::Jabber::Chat::StartThreadDlg}  disabled T}
	{cascade     mStatus        {}                                disabled {} {} {}}
	{separator}
	{command     mEnterRoom     {::Jabber::GroupChat::EnterOrCreate enter} disabled R}
	{cascade     mExitRoom      {}                                disabled {} {} {}}
	{command     mCreateRoom    {::Jabber::GroupChat::EnterOrCreate create} disabled {}}
	{separator}
	{command     mvCard         {::VCard::Fetch own}              disabled {}}
	{separator}
	{command     mSetupAssistant {
	    package require SetupAss
	    ::Jabber::SetupAss::SetupAss}                             normal {}}
	{command     mRemoveAccount {::Jabber::Register::Remove}      disabled {}}	
    }
    set menuDefs(rost,info) {    
	{command   mUpdateCheck        {
	    ::AutoUpdate::Get $prefs(urlAutoUpdate) -silent 0}        normal   {}}
	    {command     mComponents    {::Dialogs::InfoComponents}   normal   {}}
	    {command     mErrorLog      {::Jabber::ErrorLogDlg}       normal   {}}
	    {checkbutton mDebug         {::Jabber::DebugCmd}          normal   {} \
	      {-variable ::Jabber::jstate(debugCmd)}}
	    {separator}
	    {command     mCoccinellaHome {::Jabber::UI::OpenCoccinellaURL} normal {}}
	    {command     mBugReport     {::Jabber::UI::OpenBugURL}   normal {}}
    }

    # The status menu is built dynamically due to the -image options on 8.4.
    if {!$prefs(stripJabber)} {
	lset menuDefs(rost,jabber) 12 6 [::Jabber::Roster::BuildStatusMenuDef]
    }

    set menuDefs(min,edit) {    
	{command   mCut              {::UI::CutCopyPasteCmd cut}      disabled X}
	{command   mCopy             {::UI::CutCopyPasteCmd copy}     disabled C}
	{command   mPaste            {::UI::CutCopyPasteCmd paste}    disabled V}
    }
}

proc ::Jabber::UI::Show {w args} {
    upvar ::Jabber::jstate jstate

    array set argsArr $args
    if {[info exists argsArr(-visible)]} {
	set jstate(rostBrowseVis) $argsArr(-visible)
    }
    ::Debug 2 "::Jabber::UI::Show w=$w, jstate(rostBrowseVis)=$jstate(rostBrowseVis)"

    if {$jstate(rostBrowseVis)} {
	::Jabber::UI::Build $w
	wm deiconify $w
	raise $w
    } else {
	catch {wm withdraw $w}
    }
}

# Jabber::UI::Build --
#
#       A combination tabbed window with roster/agents/browser...
#       Must be persistant since roster/browser etc. are built once.
#       
# Arguments:
#       w         the real toplevel path
#       
# Results:
#       $w

proc ::Jabber::UI::Build {w} {
    global  this prefs
    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    variable menuDefs
    variable jwapp

    ::Debug 2 "::Jabber::UI::Build w=$w"
    
    if {$w != "."} {
	::UI::Toplevel $w -macstyle documentProc
	set wtop ${w}.
    } else {
	set wtop .
    }
    if {[string match "mac*" $this(platform)]} {
	bind $w <FocusIn> "+ ::UI::MacFocusFixEditMenu $w $wtop %W"
	bind $w <FocusOut> "+ ::UI::MacFocusFixEditMenu $w $wtop %W"
    }    
    set jwapp(wtopRost) $w
    wm title $w "The Coccinella"

    # Build minimal menu for Jabber stuff.
    set wmenu ${wtop}menu
    set jwapp(wmenu) $wmenu
    menu $wmenu -tearoff 0
    if {[string match "mac*" $this(platform)] && $prefs(haveMenus)} {
	set haveAppleMenu 1
    } else {
	set haveAppleMenu 0
    }
    if {$haveAppleMenu} {
	::UI::BuildAppleMenu $wtop ${wmenu}.apple normal
    }
    ::UI::NewMenu $wtop ${wmenu}.file    mFile     $menuDefs(rost,file)  normal
    if {[string match "mac*" $this(platform)]} {
	::UI::NewMenu $wtop ${wmenu}.edit  mEdit   $menuDefs(min,edit)   normal
    }
    ::UI::NewMenu $wtop ${wmenu}.jabber  mJabber   $menuDefs(rost,jabber) normal
    ::UI::NewMenu $wtop ${wmenu}.info    mInfo     $menuDefs(rost,info)   normal
    $w configure -menu $wmenu
    
    # Use a frame here just to be able to set the class (JMain) which
    # is useful for setting options.
    set  fall [frame $w.f -class JMain]
    pack $fall -fill both -expand 1
    set jwapp(fall) $fall
    	
    # Shortcut button part.
    set iconConnect     [::Theme::GetImage [option get $fall connectImage {}]]
    set iconConnectDis  [::Theme::GetImage [option get $fall connectDisImage {}]]
    set iconInboxLett   [::Theme::GetImage [option get $fall inboxLetterImage {}]]
    set iconInboxLettDis  [::Theme::GetImage \
      [option get $fall inboxLetterDisImage {}]]
    set iconInbox       [::Theme::GetImage [option get $fall inboxImage {}]]
    set iconInboxDis    [::Theme::GetImage [option get $fall inboxDisImage {}]]
    set iconNewUser     [::Theme::GetImage [option get $fall newuserImage {}]]
    set iconNewUserDis  [::Theme::GetImage [option get $fall newuserDisImage {}]]
    set iconStop        [::Theme::GetImage [option get $fall stopImage {}]]
    set iconStopDis     [::Theme::GetImage [option get $fall stopDisImage {}]]

    # Other icons.
    set iconContactOff [::Theme::GetImage [option get $fall contactOffImage {}]]
    set iconResize     [::Theme::GetImage [option get $fall resizeHandleImage {}]]
    set iconRoster     [::Theme::GetImage [option get $fall roster16Image {}]]
    
    
    set fontS [option get . fontSmall {}]
    
    set wtray ${fall}.top
    ::buttontray::buttontray $wtray 52 -borderwidth 1 -relief raised
    pack $wtray -side top -fill x
    set jwapp(wtray) $wtray
    
    $wtray newbutton connect Connect $iconConnect $iconConnectDis  \
      [list ::Jabber::Login::Login]
    if {[::Jabber::MailBox::HaveMailBox]} {
	$wtray newbutton inbox Inbox $iconInboxLett $iconInboxLettDis  \
	  [list ::Jabber::MailBox::ShowHide -visible 1]
    } else {
	$wtray newbutton inbox Inbox $iconInbox $iconInboxDis  \
	  [list ::Jabber::MailBox::ShowHide -visible 1]
    }
    $wtray newbutton newuser "New User" $iconNewUser $iconNewUserDis  \
      [list ::Jabber::Roster::NewOrEditItem new] \
      -state disabled
    $wtray newbutton stop Stop $iconStop $iconStopDis  \
      [list ::Jabber::UI::StopConnect] -state disabled

    ::hooks::run buildJMainButtonTrayHook $wtray

    set shortBtWidth [$wtray minwidth]

    # Build bottom and up to handle clipping when resizing.
    # Jid entry with electric plug indicator.
    set wbot              ${fall}.jid
    set jwapp(elplug)     ${wbot}.icon
    set jwapp(mystatus)   ${wbot}.stat
    set jwapp(myjid)      ${wbot}.e
    
    pack [frame $wbot -relief raised -borderwidth 1]  \
      -side bottom -fill x -pady 0
    pack [::Jabber::Roster::BuildStatusMenuButton $jwapp(mystatus)] \
      -side left -pady 2 -padx 6
    pack [label ${wbot}.size -image $iconResize]  \
      -padx 0 -pady 0 -side right -anchor s
    pack [label $jwapp(elplug) -image $iconContactOff]  \
      -side right -pady 0 -padx 0
    pack [entry $jwapp(myjid) -state disabled -width 0  \
      -textvariable ::Jabber::jstate(mejid)] \
      -side left -fill x -expand 1 -pady 0 -padx 0
        
    # Build status feedback elements.
    set wstat ${fall}.st
    set jwapp(statmess) ${wstat}.g.c

    pack [frame ${wstat} -relief raised -borderwidth 1]  \
      -side bottom -fill x -pady 0
    pack [frame ${wstat}.g -relief groove -bd 2]  \
      -side top -fill x -padx 8 -pady 2
    pack [canvas $jwapp(statmess) -bd 0 -highlightthickness 0 -height 14]  \
      -side left -pady 1 -padx 6 -fill x -expand true
    $jwapp(statmess) create text 0 0 -anchor nw -text {} -font $fontS \
      -tags stattxt
        
    # Notebook frame.
    set frtbook ${fall}.fnb
    pack [frame $frtbook -bd 1 -relief raised] -fill both -expand 1    
    set nbframe [::mactabnotebook::mactabnotebook ${frtbook}.tn]
    set jwapp(nbframe) $nbframe
    pack $nbframe -fill both -expand 1
    
    # Make the notebook pages.
    # Start with the Roster page -----------------------------------------------
    set ro [$nbframe newpage {Roster} -text [::msgcat::mc Roster]  \
      -image $iconRoster]    
    pack [::Jabber::Roster::Build $ro.ro] -fill both -expand 1

    # Build only Browser and/or Agents page when needed.
    set minWidth [expr $shortBtWidth > 200 ? $shortBtWidth : 200]
    wm geometry $w ${minWidth}x360
    ::UI::SetWindowGeometry $w
    wm minsize $w $minWidth 320
    wm maxsize $w 420 2000
    return $w
}


proc ::Jabber::UI::CloseHook {wclose} {    
    variable jwapp
    
    set result ""
    if {[info exists jwapp(wtopRost)] && [string equal $jwapp(wtopRost) $wclose]} {
	set ans [::UserActions::DoQuit -warning 1]
	if {$ans == "no"} {
	    set result stop
	}
    }   
    return $result
}

proc ::Jabber::UI::QuitHook { } {
    variable jwapp

    if {[info exists jwapp(wtopRost)]} {
	::UI::SaveWinGeom $jwapp(wtopRost)
    }
}

proc ::Jabber::UI::SetPresenceHook {type args} {
    upvar ::Jabber::jserver jserver
    
    array set argsArr [list -to $jserver(this)]
    array set argsArr $args
    if {[jlib::jidequal $jserver(this) $argsArr(-to)]} {
	::Jabber::UI::WhenSetStatus $type
    }
}

# Jabber::UI::LoginCmd --
# 
#       The login hook command.

proc ::Jabber::UI::LoginCmd { } {

    # Update UI in Roster window.
    set server [::Jabber::GetServerJid]
    ::Jabber::UI::SetStatusMessage [::msgcat::mc jaauthok $server]
    ::Jabber::UI::FixUIWhen "connectfin"
}

proc ::Jabber::UI::LogoutHook { } {
    
    ::Jabber::UI::SetStatusMessage [::msgcat::mc {Logged out}]
    ::Jabber::UI::FixUIWhen "disconnect"
    ::Jabber::UI::WhenSetStatus "unavailable"
    
    # Be sure to kill the wave; could end up here when failing to connect.
    ::Jabber::UI::StartStopAnimatedWave 0
    
    ::Jabber::UI::LogoutClear    
}
    
proc ::Jabber::UI::GetRosterWmenu { } {
    variable jwapp

    return $jwapp(wmenu)
}

proc ::Jabber::UI::OpenCoccinellaURL { } {
    
    ::Utils::OpenURLInBrowser "http://hem.fyristorg.com/matben/"
}

proc ::Jabber::UI::OpenBugURL { } {
    
    ::Utils::OpenURLInBrowser  \
      "http://sourceforge.net/tracker/?group_id=68334&atid=520863"
}

# Jabber::UI::NewPage --
#
#       Makes sure that there exists a page in the notebook with the
#       given name. Build it if missing. On return the page always exists.

proc ::Jabber::UI::NewPage {name} {   
    variable jwapp

    set nbframe $jwapp(nbframe)
    set pages [$nbframe pages]
    ::Debug 2 "------::Jabber::UI::NewPage name=$name, pages=$pages"
    
    switch -exact $name {
	Agents {

	    # Agents page
	    if {[lsearch $pages Agents] < 0} {
		set ag [$nbframe newpage {Agents} -text [msgcat::mc Agents]]    
		pack [::Jabber::Agents::Build $ag.ag] -fill both -expand 1
	    }
	}
	Browser {
    
	    # Browser page
	    set iconBrowser [::Theme::GetImage \
	      [option get $jwapp(fall) browser16Image {}]]
	    if {[lsearch $pages Browser] < 0} {
		set br [$nbframe newpage {Browser} -text [msgcat::mc Browser] \
		  -image $iconBrowser]    
		pack [::Jabber::Browse::Build $br.br] -fill both -expand 1
	    }
	}
	Disco {
	    set iconBrowser [::Theme::GetImage \
	      [option get $jwapp(fall) browser16Image {}]]
	    if {[lsearch $pages Disco] < 0} {
		set di [$nbframe newpage {Disco} -text [msgcat::mc Disco] \
		  -image $iconBrowser]    
		pack [::Jabber::Disco::Build $di.di] -fill both -expand 1
	    }
	}
	default {
	    # Nothing
	    return -code error "Not recognized page name $name"
	}
    }    
}

proc ::Jabber::UI::StopConnect { } {
    
    ::Jabber::DoCloseClientConnection
    
    ::Network::KillAll
    ::Jabber::UI::SetStatusMessage ""
    ::Jabber::UI::StartStopAnimatedWave 0
    ::Jabber::UI::FixUIWhen disconnect
}    

proc ::Jabber::UI::Pages { } {
    variable jwapp
    
    return [$jwapp(nbframe) pages]
}

proc ::Jabber::UI::LogoutClear { } {
    variable jwapp
    
    set nbframe $jwapp(nbframe)
    foreach page [$nbframe pages] {
	if {![string equal $page "Roster"]} {
	    $nbframe deletepage $page
	}
    }
}

proc ::Jabber::UI::StartStopAnimatedWave {start} {
    variable jwapp

    set waveImage [::Theme::GetImage [option get $jwapp(fall) waveImage {}]]  
    ::UI::StartStopAnimatedWave $jwapp(statmess) $waveImage $start
}

proc ::Jabber::UI::SetStatusMessage {msg} {
    variable jwapp

    $jwapp(statmess) itemconfigure stattxt -text $msg
}

# Jabber::UI::MailBoxState --
# 
#       Sets icon to display empty|nonempty inbox state.

proc ::Jabber::UI::MailBoxState {mailboxstate} {
    variable jwapp    
    
    set w $jwapp(wtopRost)
    set fall $jwapp(fall)
    
    set iconInboxLett   [::Theme::GetImage [option get $fall inboxLetterImage {}]]
    set iconInboxLettDis  [::Theme::GetImage \
      [option get $fall inboxLetterDisImage {}]]
    
    switch -- $mailboxstate {
	empty {
	    $jwapp(wtray) buttonconfigure inbox -image $iconInboxLett
	}
	nonempty {
	    $jwapp(wtray) buttonconfigure inbox -image $iconInboxLettDis
	}
    }
}

# Jabber::UI::WhenSetStatus --
#
#       Updates UI when set own presence status information.
#       
# Arguments:
#       type        any of 'available', 'unavailable', 'invisible',
#                   'away', 'dnd', 'xa'.
#       
# Results:
#       None.

proc ::Jabber::UI::WhenSetStatus {type} {
    variable jwapp
	
    ::Jabber::Roster::ConfigStatusMenuButton $jwapp(mystatus) $type
}

proc ::Jabber::UI::EnterRoomHook {roomJid protocol} {
    
    ::Jabber::UI::GroupChat enter $roomJid
}

proc ::Jabber::UI::ExitRoomHook {roomJid} {
    
    ::Jabber::UI::GroupChat exit $roomJid
}

# Jabber::UI::GroupChat --
# 
#       Updates UI when enter/exit groupchat room.
#       
# Arguments:
#       what        any of 'enter' or 'exit'.
#       roomJid
#       
# Results:
#       None.

proc ::Jabber::UI::GroupChat {what roomJid} {
    variable jwapp
    
    set wmenu $jwapp(wmenu)
    set wmjexit ${wmenu}.jabber.mexitroom

    ::Debug 4 "::Jabber::UI::GroupChat what=$what, roomJid=$roomJid"

    switch $what {
	enter {
	    $wmjexit add command -label $roomJid  \
	      -command [list ::Jabber::GroupChat::ExitRoom $roomJid]	    
	}
	exit {
	    catch {$wmjexit delete $roomJid}	    
	}
    }
}

# Jabber::UI::RegisterPopupEntry --
# 
#       Lets plugins/components register their own menu entry.

proc ::Jabber::UI::RegisterPopupEntry {which menuSpec} {
    
    switch -- $which {
	agents {
	    ::Jabber::Agents::RegisterPopupEntry $menuSpec
	}
	browse {
	    ::Jabber::Browse::RegisterPopupEntry $menuSpec	    
	}
	groupchat {
	    ::Jabber::GroupChat::RegisterPopupEntry $menuSpec	    
	}
	roster {
	    ::Jabber::Roster::RegisterPopupEntry $menuSpec	    
	}
    }
}

# Jabber::UI::RegisterMenuEntry --
# 
#       Lets plugins/components register their own menu entry.

proc ::Jabber::UI::RegisterMenuEntry {wpath name menuSpec} {
    variable menuDefs
    
    # Keeps track of all registered menu entries.
    variable rostMenuSpec
    
    # Add these entries in a section above the bottom section.
    # Add separator to section component entries.
    
    switch -- $wpath {
	jabber {
	    set ind [lindex [lsearch -all $menuDefs(rost,jabber) "separator"] end]
	    if {![info exists rostMenuSpec(jabber)]} {

		# Add separator if this is the first addon entry.
		set menuDefs(rost,jabber) [linsert $menuDefs(rost,jabber)  \
		  $ind {separator}]
		incr ind
	    }
	    set menuDefs(rost,jabber) [linsert $menuDefs(rost,jabber)  \
	      $ind $menuSpec]
	    lappend rostMenuSpec(jabber) [list $menuSpec]
	}
	file {	    
	    if {![info exists rostMenuSpec(file)]} {
		set menuDefs(rost,file) [linsert $menuDefs(rost,file) end-2 \
		  {separator}]
	    }
	    set menuDefs(rost,file) [linsert $menuDefs(rost,file) end-2 $menuSpec]
	    lappend rostMenuSpec(file) [list $menuSpec]
	}
    }
}

# Jabber::UI::FixUIWhen --
#       
#       Sets the correct state for menus and buttons when 'what'.
#       
# Arguments:
#       what        'connectinit', 'connectfin', 'connect', 'disconnect'
#
# Results:

proc ::Jabber::UI::FixUIWhen {what} {
    variable jwapp
        
    set w     $jwapp(wtopRost)
    set wtop  ${w}.
    set wall  $jwapp(fall)
    set wmenu $jwapp(wmenu)
    set wmj   ${wmenu}.jabber
    set wtray $jwapp(wtray)

    set contactOffImage [::Theme::GetImage [option get $wall contactOffImage {}]]
    set contactOnImage  [::Theme::GetImage [option get $wall contactOnImage {}]]

    switch -exact -- $what {
	connectinit {
	    $wtray buttonconfigure connect -state disabled
	    $wtray buttonconfigure stop -state normal
	    ::UI::MenuMethod $wmj entryconfigure mLogin -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mNewAccount -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mSetupAssistant -state disabled
	}
	connectfin - connect {
	    $wtray buttonconfigure connect -state disabled
	    $wtray buttonconfigure newuser -state normal
	    $wtray buttonconfigure stop -state disabled
	    $jwapp(elplug) configure -image $contactOnImage
	    ::UI::MenuMethod $wmj entryconfigure mNewAccount -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mLogin  \
	      -label [::msgcat::mc mLogout] -state normal
	    ::UI::MenuMethod $wmj entryconfigure mLogoutWith -state normal
	    ::UI::MenuMethod $wmj entryconfigure mPassword -state normal
	    ::UI::MenuMethod $wmj entryconfigure mSearch -state normal
	    ::UI::MenuMethod $wmj entryconfigure mAddNewUser -state normal
	    ::UI::MenuMethod $wmj entryconfigure mSendMessage -state normal
	    ::UI::MenuMethod $wmj entryconfigure mChat -state normal
	    ::UI::MenuMethod $wmj entryconfigure mStatus -state normal
	    ::UI::MenuMethod $wmj entryconfigure mvCard -state normal
	    ::UI::MenuMethod $wmj entryconfigure mEnterRoom -state normal
	    ::UI::MenuMethod $wmj entryconfigure mExitRoom -state normal
	    ::UI::MenuMethod $wmj entryconfigure mCreateRoom -state normal
	    ::UI::MenuMethod $wmj entryconfigure mPassword -state normal
	    ::UI::MenuMethod $wmj entryconfigure mRemoveAccount -state normal
	    ::UI::MenuMethod $wmj entryconfigure mSetupAssistant -state disabled
	}
	disconnect {
	    $wtray buttonconfigure connect -state normal
	    $wtray buttonconfigure newuser -state disabled
	    $wtray buttonconfigure stop -state disabled
	    $jwapp(elplug) configure -image $contactOffImage
	    ::UI::MenuMethod $wmj entryconfigure mNewAccount -state normal
	    ::UI::MenuMethod $wmj entryconfigure mLogin  \
	      -label [::msgcat::mc mLogin] -state normal
	    ::UI::MenuMethod $wmj entryconfigure mLogoutWith -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mPassword -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mSearch -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mAddNewUser -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mSendMessage -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mChat -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mStatus -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mvCard -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mEnterRoom -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mExitRoom -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mCreateRoom -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mPassword -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mRemoveAccount -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mSetupAssistant -state normal
	}
    }
}

#-------------------------------------------------------------------------------
