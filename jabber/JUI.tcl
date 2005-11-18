#  JUI.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements jabber GUI parts.
#      
#  Copyright (c) 2001-2005  Mats Bengtsson
#  
# $Id: JUI.tcl,v 1.95 2005-11-18 07:52:32 matben Exp $

package provide JUI 1.0


namespace eval ::Jabber::UI:: {
    
    # Add all event hooks.
    ::hooks::register quitAppHook            ::Jabber::UI::QuitHook
    ::hooks::register loginHook              ::Jabber::UI::LoginCmd
    ::hooks::register logoutHook             ::Jabber::UI::LogoutHook
    ::hooks::register setPresenceHook        ::Jabber::UI::SetPresenceHook
    ::hooks::register rosterIconsChangedHook ::Jabber::UI::RosterIconsChangedHook

    # Use option database for customization.
    # Shortcut buttons.
    option add *JMain.connectImage                connect         widgetDefault
    option add *JMain.connectDisImage             connectDis      widgetDefault
    option add *JMain.connectedImage              connected       widgetDefault
    option add *JMain.connectedDisImage           connectedDis    widgetDefault
    option add *JMain.inboxImage                  inbox           widgetDefault
    option add *JMain.inboxDisImage               inboxDis        widgetDefault
    option add *JMain.inboxLetterImage            inboxLetter     widgetDefault
    option add *JMain.inboxLetterDisImage         inboxLetterDis  widgetDefault
    option add *JMain.adduserImage                adduser         widgetDefault
    option add *JMain.adduserDisImage             adduserDis      widgetDefault
    option add *JMain.stopImage                   stop            widgetDefault
    option add *JMain.stopDisImage                stopDis         widgetDefault
    option add *JMain.roster16Image               family16        widgetDefault
    option add *JMain.roster16DisImage            family16Dis     widgetDefault
    option add *JMain.browser16Image              run16           widgetDefault
    option add *JMain.browser16DisImage           run16Dis        widgetDefault

    # Top header image if any.
    option add *JMain.headImage                   ""              widgetDefault
    option add *JMain.head.borderWidth            0               50 
    option add *JMain.head.relief                 flat            50

    option add *JMain.statusWidgetStyle           button          50

    # Other icons.
    option add *JMain.contactOffImage             contactOff      widgetDefault
    option add *JMain.contactOnImage              contactOn       widgetDefault
    option add *JMain.waveImage                   wave            widgetDefault
    option add *JMain.resizeHandleImage           resizehandle    widgetDefault

    # Standard widgets.
    switch -- [tk windowingsystem] {
	aqua - x11 {
	    option add *JMain*TNotebook.padding   {8}             50
	    option add *JMain*bot.f.padding       {8 0 8 4}       50
	}
	default {
	    option add *JMain*TNotebook.padding   {4 4 4 2}       50
	    option add *JMain*bot.f.padding       {8 0 8 0}       50
	}
    }
    option add *JMain*TMenubutton.padding         {1}             50

    # Special for X11 menus to look ok.
    if {[tk windowingsystem] eq "x11"} {
	option add *JMain.Menu.borderWidth        0               50
    }
    
    # Collection of useful and common widget paths.
    variable jwapp
    variable inited 0
}


proc ::Jabber::UI::Init { } {
    global  this
    
    # Menu definitions for the Roster/services window.
    variable menuDefs
    variable inited
    
    if {[string match "mac*" $this(platform)]} {
	set menuDefs(rost,file) {
	    {command   mNewWhiteboard      {::Jabber::WB::NewWhiteboard}  normal   N}
	    {command   mCloseWindow        {::UI::DoCloseWindow}          normal   W}
	    {command   mPreferences...     {::Preferences::Build}         normal   {}}
	    {separator}
	    {command   mQuit               {::UserActions::DoQuit}        normal   Q}
	}
    } else {
	set menuDefs(rost,file) {
	    {command   mNewWhiteboard      {::Jabber::WB::NewWhiteboard}  normal   N}
	    {command   mPreferences...     {::Preferences::Build}         normal   {}}
	    {separator}
	    {command   mQuit               {::UserActions::DoQuit}        normal   Q}
	}
    }
    set menuDefs(rost,jabber) {    
	{command     mNewAccount    {::RegisterEx::New}      normal   {}}
	{command     mLogin         {::Jabber::LoginLogout}           normal   L}
	{command     mLogoutWith    {::Jabber::Logout::WithStatus}    disabled {}}
	{command     mPassword      {::Jabber::Passwd::Build}         disabled {}}
	{separator}
	{checkbutton mMessageInbox  {::MailBox::ShowHide}     normal   I \
	  {-variable ::Jabber::jstate(inboxVis)}}
	{separator}
	{command     mSearch        {::Search::Build}         disabled {}}
	{command     mAddNewUser    {::Jabber::User::NewDlg}       disabled {}}
	{separator}
	{command     mSendMessage   {::NewMsg::Build}         disabled M}
	{command     mChat          {::Chat::StartThreadDlg}  disabled T}
	{cascade     mStatus        {}                                  disabled {} {} {}}
	{separator}
	{command     mEnterRoom     {::GroupChat::EnterOrCreate enter}  disabled R}
	{command     mCreateRoom    {::GroupChat::EnterOrCreate create} disabled {}}
	{command     mEditBookmarks {::GroupChat::EditBookmarks}        disabled {}}
	{separator}
	{command     mvCard         {::VCard::Fetch own}              disabled {}}
	{cascade     mShow          {}                                normal   {} {} {
	    {check   mToolbar       {::Jabber::UI::ToggleToolbar}     normal   {} 
	    {-variable ::Jabber::UI::state(show,toolbar)}}
	    {check   mNotebook      {::Jabber::UI::ToggleNotebook}    normal   {} 
	    {-variable ::Jabber::UI::state(show,notebook)}}}
	}
	{separator}
	{command     mRemoveAccount {::Register::Remove}      disabled {}}	
    }

    if {[tk windowingsystem] eq "aqua"} {
	set menuDefs(rost,info) {    
	    {command     mSetupAssistant {
		package require SetupAss; ::Jabber::SetupAss::SetupAss
	    }                             normal {}}
	    {command     mComponents    {::Dialogs::InfoComponents}   normal   {}}
	    {command     mErrorLog      {::Jabber::ErrorLogDlg}       normal   {}}
	    {checkbutton mDebug         {::Jabber::DebugCmd}          normal   {} \
	      {-variable ::Jabber::jstate(debugCmd)}}
	    {separator}
	    {command     mCoccinellaHome {::Jabber::UI::OpenCoccinellaURL} normal {}}
	    {command     mBugReport      {::Jabber::UI::OpenBugURL}   normal {}}
	}
    } else {
	set menuDefs(rost,info) {    
	    {command     mSetupAssistant {
		package require SetupAss; ::Jabber::SetupAss::SetupAss
	    }                             normal {}}
	    {command     mComponents    {::Dialogs::InfoComponents}   normal   {}}
	    {command     mErrorLog      {::Jabber::ErrorLogDlg}       normal   {}}
	    {checkbutton mDebug         {::Jabber::DebugCmd}          normal   {} \
	      {-variable ::Jabber::jstate(debugCmd)}}
	    {separator}
	    {command     mAboutCoccinella  {::Splash::SplashScreen} normal   {}}
	    {command     mCoccinellaHome   {::Jabber::UI::OpenCoccinellaURL} normal {}}
	    {command     mBugReport        {::Jabber::UI::OpenBugURL}   normal {}}
	}
    }

    # The status menu is built dynamically due to the -image options on 8.4.
    lset menuDefs(rost,jabber) 12 6 [::Jabber::Status::BuildStatusMenuDef]

    set menuDefs(rost,edit) {    
	{command   mCut              {::UI::CutCopyPasteCmd cut}      disabled X}
	{command   mCopy             {::UI::CutCopyPasteCmd copy}     disabled C}
	{command   mPaste            {::UI::CutCopyPasteCmd paste}    disabled V}
    }
    
    # When registering new menu entries they shall be added at:
    variable menuDefsInsertInd

    set menuDefsInsertInd(rost,file)   [expr [llength $menuDefs(rost,file)]-2]
    set menuDefsInsertInd(rost,edit)   [expr [llength $menuDefs(rost,edit)]]
    set menuDefsInsertInd(rost,jabber) [expr [llength $menuDefs(rost,jabber)]-2]
    if {[string match "mac*" $this(platform)]} {
	set menuDefsInsertInd(rost,info)   [expr [llength $menuDefs(rost,info)]-3]
    } else {
	set menuDefsInsertInd(rost,info)   [expr [llength $menuDefs(rost,info)]-4]
    }
    set inited 1
    
    # We should do this for all menus eventaully.
    ::UI::PruneMenusUsingOptsDB mInfo menuDefs(rost,info) menuDefsInsertInd(rost,info)
}


proc ::Jabber::UI::Show {w args} {
    upvar ::Jabber::jstate jstate

    array set argsArr $args
    if {[info exists argsArr(-visible)]} {
	set jstate(rostBrowseVis) $argsArr(-visible)
    }
    ::Debug 2 "::Jabber::UI::Show w=$w, jstate(rostBrowseVis)=$jstate(rostBrowseVis)"

    if {$jstate(rostBrowseVis)} {
	Build $w
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
#       w           toplevel path
#       
# Results:
#       $w

proc ::Jabber::UI::Build {w} {
    global  this prefs
    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    variable menuDefs
    variable jwapp
    variable inited

    ::Debug 2 "::Jabber::UI::Build w=$w"
    
    if {!$inited} {
	Init
    }
    ::UI::Toplevel $w -class JMain \
      -macstyle documentProc -closecommand ::Jabber::UI::CloseHook
    wm title $w $prefs(theAppName)
    ::UI::SetWindowGeometry $w
    set jwapp(jmain) $w

    # Build minimal menu for Jabber stuff.
    MergeMenuDefs
    
    # Make main menus.
    set wmenu $w.menu
    set jwapp(wmenu) $wmenu
    menu $wmenu -tearoff 0
    if {[string match "mac*" $this(platform)]} {
	# @@@ discard when -postcommand implemented
	bind $w <FocusIn>  +[list ::UI::MacFocusFixEditMenu $w $wmenu %W]
	bind $w <FocusOut> +[list ::UI::MacFocusFixEditMenu $w $wmenu %W]
    }    
    if {[string match "mac*" $this(platform)] && $prefs(haveMenus)} {
	set haveAppleMenu 1
    } else {
	set haveAppleMenu 0
    }
    if {$haveAppleMenu} {
	::UI::BuildAppleMenu $w $wmenu.apple normal
    }
    ::UI::NewMenu $w $wmenu.file    mFile     $menuDefs(rost,file)  normal
    if {[tk windowingsystem] eq "aqua"} {
	::UI::NewMenu $w $wmenu.edit  mEdit   $menuDefs(rost,edit)   normal
	$wmenu.edit configure  \
	  -postcommand [list ::Jabber::UI::EditPostCommand $wmenu.edit]
    }
    ::UI::NewMenu $w $wmenu.jabber  mJabber   $menuDefs(rost,jabber) normal
    $wmenu.edit configure  \
      -postcommand [list ::Jabber::UI::JabberPostCommand $wmenu.jabber]
    ::UI::NewMenu $w $wmenu.info    mInfo     $menuDefs(rost,info)   normal
    $w configure -menu $wmenu    
    
    # Global frame.
    set wall $w.f
    ttk::frame $wall
    pack $wall -fill both -expand 1
    
    # Special for X11 menus to look ok.
    if {[tk windowingsystem] eq "x11"} {
	ttk::separator $wall.stop -orient horizontal
	pack $wall.stop -side top -fill x
    }

    # Any header image?
    set headImage [::Theme::GetImage [option get $w headImage {}]]
    if {$headImage ne ""} {
	ttk::label $wall.head -image $headImage
	pack  $wall.head -side top -anchor w
    }

    # Other icons.
    set iconContactOff [::Theme::GetImage [option get $w contactOffImage {}]]
    set iconResize     [::Theme::GetImage [option get $w resizeHandleImage {}]]
    set iconRoster     [::Theme::GetImage [option get $w roster16Image {}]]
    set iconRosterDis  [::Theme::GetImage [option get $w roster16DisImage {}]]
    
    set wtbar $wall.tbar
    BuildToolbar $w $wtbar
    pack $wtbar -side top -fill x
    
    set trayMinW [$wtbar minwidth]

    ttk::separator $wall.sep -orient horizontal
    pack $wall.sep -side top -fill x

    # Status frame.
    set wbot $wall.bot
    ttk::frame $wbot
    pack $wbot -side bottom -fill x
    if {[tk windowingsystem] ne "aqua"} {
	ttk::label $wbot.size -compound image -image $iconResize
	pack  $wbot.size -side right -anchor s
    }
    ttk::frame $wbot.f
    pack $wbot.f -fill x
  
    set statusStyle  [option get $w statusWidgetStyle {}]
    ::Jabber::Status::Widget $wbot.f.bst $statusStyle \
      ::Jabber::jstate(status) -command ::Jabber::SetStatus    
    ttk::label $wbot.f.l -style Small.TLabel \
      -textvariable ::Jabber::jstate(mejid)
    pack  $wbot.f.bst  $wbot.f.l  -side left

    # Notebook.
    set wnb $wall.nb
    ttk::notebook $wnb
    pack $wnb -side bottom -fill both -expand 1
    
    # Make the Roster page -----------------------------------------------
    
    # Each notbook page must be a direct child of the notebook and we therefore
    # need to have a container frame which the roster is packed -in.
    set wroster $wall.ro
    set wrostco $wnb.cont
    ::Roster::Build $wroster
    frame $wrostco

    set imSpec [list $iconRoster disabled $iconRosterDis background $iconRosterDis]
    $wnb add $wrostco -compound left -text [mc Contacts] -image $imSpec -sticky news
    pack $wroster -in $wnb.cont -fill both -expand 1

    set jwapp(wtbar)     $wtbar
    set jwapp(tsep)      $wall.sep
    set jwapp(notebook)  $wnb
    set jwapp(roster)    $wroster
    set jwapp(mystatus)  $wbot.f.bst
    set jwapp(myjid)     $wbot.f.l
    
    set minW [expr $trayMinW > 200 ? $trayMinW : 200]
    wm geometry $w ${minW}x360
    ::UI::SetWindowGeometry $w
    wm minsize $w $minW 320
    wm maxsize $w 420 2000
    
    ::hooks::run jabberBuildMain
    
    return $w
}

proc ::Jabber::UI::BuildToolbar {w wtbar} {
    
    # Shortcut button part.
    set iconConnect       [::Theme::GetImage [option get $w connectImage {}]]
    set iconConnectDis    [::Theme::GetImage [option get $w connectDisImage {}]]
    set iconInboxLett     [::Theme::GetImage [option get $w inboxLetterImage {}]]
    set iconInboxLettDis  [::Theme::GetImage [option get $w inboxLetterDisImage {}]]
    set iconInbox         [::Theme::GetImage [option get $w inboxImage {}]]
    set iconInboxDis      [::Theme::GetImage [option get $w inboxDisImage {}]]
    set iconAddUser       [::Theme::GetImage [option get $w adduserImage {}]]
    set iconAddUserDis    [::Theme::GetImage [option get $w adduserDisImage {}]]
    set iconStop          [::Theme::GetImage [option get $w stopImage {}]]
    set iconStopDis       [::Theme::GetImage [option get $w stopDisImage {}]]
    
    ::ttoolbar::ttoolbar $wtbar
    
    $wtbar newbutton connect -text [mc Connect] \
      -image $iconConnect -disabledimage $iconConnectDis \
      -command ::Login::Dlg
    if {[::MailBox::HaveMailBox]} {
	$wtbar newbutton inbox -text [mc Inbox] \
	  -image $iconInboxLett -disabledimage $iconInboxLettDis  \
	  -command [list ::MailBox::ShowHide -visible 1]
    } else {
	$wtbar newbutton inbox -text [mc Inbox] \
	  -image $iconInbox -disabledimage $iconInboxDis  \
	  -command [list ::MailBox::ShowHide -visible 1]
    }
    $wtbar newbutton newuser -text [mc Contact] \
      -image $iconAddUser -disabledimage $iconAddUserDis  \
      -command ::Jabber::User::NewDlg -state disabled

    ::hooks::run buildJMainButtonTrayHook $wtbar

    return $wtbar
}

proc ::Jabber::UI::RosterMoveFromPage { } {
    variable jwapp
    
    pack forget $jwapp(roster)
    pack forget $jwapp(notebook)
    pack $jwapp(roster) -side bottom -fill both -expand 1
}

proc ::Jabber::UI::RosterMoveToPage { } {
    variable jwapp
    
    pack forget $jwapp(roster)
    pack $jwapp(notebook) -side bottom -fill both -expand 1
    pack $jwapp(roster) -in $jwapp(notebook).cont -fill both -expand 1
    raise $jwapp(roster)
}

proc ::Jabber::UI::GetMainWindow { } {
    global wDlgs
    
    return $wDlgs(jmain)
}

proc ::Jabber::UI::GetMainMenu { } {
    variable jwapp
    
    return $jwapp(wmenu)
}

proc ::Jabber::UI::ToggleToolbar { } {
    variable jwapp
    
    if {[winfo ismapped $jwapp(wtbar)]} {
	pack forget $jwapp(wtbar)
	pack forget $jwapp(tsep)
    } else {
	pack $jwapp(wtbar) -side top -fill x
	pack $jwapp(tsep)  -side top -fill x
    }
}

proc ::Jabber::UI::ToggleNotebook { } {
    variable jwapp
    
    if {[winfo ismapped $jwapp(notebook)]} {
	RosterMoveFromPage
    } else {
	RosterMoveToPage
    }
}

proc ::Jabber::UI::CloseHook {wclose} {    
    variable jwapp
    
    set result ""
    if {[info exists jwapp(jmain)]} {
	set ans [::UserActions::DoQuit -warning 1]
	if {$ans == "no"} {
	    set result stop
	}
    }   
    return $result
}

proc ::Jabber::UI::QuitHook { } {
    variable jwapp

    if {[info exists jwapp(jmain)]} {
	::UI::SaveWinGeom $jwapp(jmain)
    }
}

proc ::Jabber::UI::SetPresenceHook {type args} {
    upvar ::Jabber::jserver jserver
    
    array set argsArr [list -to $jserver(this)]
    array set argsArr $args
    if {[jlib::jidequal $jserver(this) $argsArr(-to)]} {
	WhenSetStatus $type
    }
}

proc ::Jabber::UI::RosterIconsChangedHook { } {
    variable jwapp
    upvar ::Jabber::jstate jstate
    
    set status $jstate(status)
    $jwapp(mystatus) configure -image [::Rosticons::Get status/$status]
}

# Jabber::UI::LoginCmd --
# 
#       The login hook command.

proc ::Jabber::UI::LoginCmd { } {

    # Update UI in Roster window.
    set server [::Jabber::GetServerJid]
    SetStatusMessage [mc jaauthok $server]
    FixUIWhen "connectfin"
}

proc ::Jabber::UI::LogoutHook { } {
    
    SetStatusMessage [mc {Logged out}]
    FixUIWhen "disconnect"
    WhenSetStatus "unavailable"
    
    # Be sure to kill the wave; could end up here when failing to connect.
    StartStopAnimatedWave 0
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

proc ::Jabber::UI::StopConnect { } {
    
    ::Jabber::DoCloseClientConnection
    ::Login::Kill
}    

proc ::Jabber::UI::GetNotebook { } {
    variable jwapp
    
    return $jwapp(notebook)
}

proc ::Jabber::UI::StartStopAnimatedWave {start} {

    ::Roster::Animate $start
}

proc ::Jabber::UI::SetStatusMessage {msg} {

    ::Roster::TimedMessage $msg
}

# Jabber::UI::MailBoxState --
# 
#       Sets icon to display empty|nonempty inbox state.

proc ::Jabber::UI::MailBoxState {mailboxstate} {
    variable jwapp    
    
    set w $jwapp(jmain)
        
    switch -- $mailboxstate {
	empty {
	    set im  [::Theme::GetImage [option get $w inboxImage {}]]
	    set imd [::Theme::GetImage [option get $w inboxDisImage {}]]
	    $jwapp(wtbar) buttonconfigure inbox  \
	      -image $im -disabledimage $imd
	}
	nonempty {
	    set im  [::Theme::GetImage [option get $w inboxLetterImage {}]]
	    set imd [::Theme::GetImage [option get $w inboxLetterDisImage {}]]
	    $jwapp(wtbar) buttonconfigure inbox  \
	      -image $im -disabledimage $imd
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
	
    ::Jabber::Status::Configure $jwapp(mystatus) $type
}

# Jabber::UI::RegisterPopupEntry --
# 
#       Lets plugins/components register their own menu entry.

proc ::Jabber::UI::RegisterPopupEntry {which menuSpec} {
    
    switch -- $which {
	agents {
	    ::Agents::RegisterPopupEntry $menuSpec
	}
	browse {
	    ::Browse::RegisterPopupEntry $menuSpec	    
	}
	groupchat {
	    ::GroupChat::RegisterPopupEntry $menuSpec	    
	}
	roster {
	    ::Roster::RegisterPopupEntry $menuSpec	    
	}
    }
}

# Jabber::UI::RegisterMenuEntry --
# 
#       Lets plugins/components register their own menu entry.

proc ::Jabber::UI::RegisterMenuEntry {mtail menuSpec} {
    
    # Keeps track of all registered menu entries.
    variable extraMenuDefs
    
    # Add these entries in a section above the bottom section.
    # Add separator to section component entries.
    
    if {![info exists extraMenuDefs(rost,$mtail)]} {

	# Add separator if this is the first addon entry.
	set extraMenuDefs(rost,$mtail) {separator}
    }
    lappend extraMenuDefs(rost,$mtail) $menuSpec
}

proc ::Jabber::UI::MergeMenuDefs { } {
    variable menuDefs
    variable menuDefsInsertInd
    variable extraMenuDefs
    
    foreach key [array names extraMenuDefs] {
	set menuDefs($key) [eval {linsert $menuDefs($key)  \
	  $menuDefsInsertInd($key)} $extraMenuDefs($key)]
    }
}

proc ::Jabber::UI::EditPostCommand {wmenu} {
    
    # @@@ The situation with a ttk::entry in readonly state is not understood.
    # @@@ Not sure focus is needed for selections.
    set wfocus [focus]
    set haveFocus 0
    set haveSelection 0
    set editable 1
    
    if {$wfocus ne ""} {
	set wclass [winfo class $wfocus]
	if {[lsearch {Entry Text TEntry} $wclass] >= 0} {
	    set haveFocus 1
	}

	switch -- $wclass {
	    TEntry {
		set haveSelection [$wfocus selection present]
		set state [$wfocus state]
		if {[lsearch $state disabled] >= 0} {
		    set editable 0
		} elseif {[lsearch $state readonly] >= 0} {
		    set editable 0
		}
	    }
	    Entry {
		set haveSelection [$wfocus selection present]
		if {[$wfocus cget -state] eq "disabled"} {
		    set editable 0
		}
	    }
	    Text {
		if {![catch {$wfocus get sel.first sel.last} data]} {
		    if {$data ne ""} {
			set haveSelection 1
		    }
		}
		if {[$wfocus cget -state] eq "disabled"} {
		    set editable 0
		}
	    }
	}
    }    
    
    # Cut, copy and paste menu entries.
    if {$haveSelection} {
	if {$editable} {
	    ::UI::MenuMethod $wmenu entryconfigure mCut  -state normal
	} else {
	    ::UI::MenuMethod $wmenu entryconfigure mCut  -state disabled
	}
	::UI::MenuMethod $wmenu entryconfigure mCopy -state normal    
    } else {
	::UI::MenuMethod $wmenu entryconfigure mCut  -state disabled
	::UI::MenuMethod $wmenu entryconfigure mCopy -state disabled    
    }
    if {[catch {selection get -sel CLIPBOARD} str]} {
	::UI::MenuMethod $wmenu entryconfigure mPaste -state disabled
    } elseif {$editable && $haveFocus && ($str ne "")} {
	::UI::MenuMethod $wmenu entryconfigure mPaste -state normal
    } else {
	::UI::MenuMethod $wmenu entryconfigure mPaste -state disabled
    }
    
    # Workaround for mac bug.
    update idletasks
}

proc ::Jabber::UI::JabberPostCommand {wmenu} {
    global wDlgs
    variable state
    variable jwapp
    
    # For aqua we must do this only for .jmain
    if {[::UI::IsToplevelActive $wDlgs(jmain)]} {
	::UI::MenuMethod $wmenu entryconfigure mShow -state normal
	if {[winfo ismapped $jwapp(wtbar)]} {
	    set state(show,toolbar) 1
	} else {
	    set state(show,toolbar) 0
	}
	if {[winfo ismapped $jwapp(notebook)]} {
	    set state(show,notebook) 1
	} else {
	    set state(show,notebook) 0
	}
    } else {
	::UI::MenuMethod $wmenu entryconfigure mShow -state disabled
    }
    
    # Workaround for mac bug.
    update idletasks
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
        
    set w     $jwapp(jmain)
    set wmenu $jwapp(wmenu)
    set wmj   $wmenu.jabber
    set wmi   $wmenu.info
    set wtbar $jwapp(wtbar)

    set contactOffImage [::Theme::GetImage [option get $w contactOffImage {}]]
    set contactOnImage  [::Theme::GetImage [option get $w contactOnImage {}]]

    switch -exact -- $what {
	connectinit {
	    set stopImage       [::Theme::GetImage [option get $w stopImage {}]]

	    $wtbar buttonconfigure connect -text [mc Stop] \
	      -image $stopImage -disabledimage $stopImage \
	      -command ::Jabber::UI::StopConnect
	    ::UI::MenuMethod $wmj entryconfigure mLogin -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mNewAccount -state disabled
	    ::UI::MenuMethod $wmi entryconfigure mSetupAssistant -state disabled

	    # test... Logout kills login process.
	    ::UI::MenuMethod $wmj entryconfigure mLogin  \
	      -label [mc mLogout] -state normal
	}
	connectfin - connect {
	    set connectedImage    [::Theme::GetImage [option get $w connectedImage {}]]
	    set connectedDisImage [::Theme::GetImage [option get $w connectedDisImage {}]]

	    $wtbar buttonconfigure connect -text [mc Logout] \
	      -image $connectedImage -disabledimage $connectedDisImage \
	      -command ::Jabber::LoginLogout
	    $wtbar buttonconfigure newuser -state normal
	    ::UI::MenuMethod $wmj entryconfigure mNewAccount -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mLogin  \
	      -label [mc mLogout] -state normal
	    ::UI::MenuMethod $wmj entryconfigure mLogoutWith -state normal
	    ::UI::MenuMethod $wmj entryconfigure mPassword -state normal
	    ::UI::MenuMethod $wmj entryconfigure mSearch -state normal
	    ::UI::MenuMethod $wmj entryconfigure mAddNewUser -state normal
	    ::UI::MenuMethod $wmj entryconfigure mSendMessage -state normal
	    ::UI::MenuMethod $wmj entryconfigure mChat -state normal
	    ::UI::MenuMethod $wmj entryconfigure mStatus -state normal
	    ::UI::MenuMethod $wmj entryconfigure mvCard -state normal
	    ::UI::MenuMethod $wmj entryconfigure mEnterRoom -state normal
	    ::UI::MenuMethod $wmj entryconfigure mCreateRoom -state normal
	    ::UI::MenuMethod $wmj entryconfigure mEditBookmarks -state normal
	    ::UI::MenuMethod $wmj entryconfigure mPassword -state normal
	    ::UI::MenuMethod $wmj entryconfigure mRemoveAccount -state normal
	    ::UI::MenuMethod $wmi entryconfigure mSetupAssistant -state disabled
	}
	disconnect {
	    set iconConnect     [::Theme::GetImage [option get $w connectImage {}]]
	    set iconConnectDis  [::Theme::GetImage [option get $w connectDisImage {}]]

	    $wtbar buttonconfigure connect -text [mc Login] \
	      -image $iconConnect -disabledimage $iconConnectDis \
	      -command ::Jabber::LoginLogout
	    $wtbar buttonconfigure newuser -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mNewAccount -state normal
	    ::UI::MenuMethod $wmj entryconfigure mLogin  \
	      -label [mc mLogin] -state normal
	    ::UI::MenuMethod $wmj entryconfigure mLogoutWith -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mPassword -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mSearch -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mAddNewUser -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mSendMessage -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mChat -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mStatus -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mvCard -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mEnterRoom -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mCreateRoom -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mEditBookmarks -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mPassword -state disabled
	    ::UI::MenuMethod $wmj entryconfigure mRemoveAccount -state disabled
	    ::UI::MenuMethod $wmi entryconfigure mSetupAssistant -state normal
	}
    }
}

#-------------------------------------------------------------------------------
