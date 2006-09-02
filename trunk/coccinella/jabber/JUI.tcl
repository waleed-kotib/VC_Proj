#  JUI.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements jabber GUI parts.
#      
#  Copyright (c) 2001-2005  Mats Bengtsson
#  
# $Id: JUI.tcl,v 1.130 2006-09-02 07:09:59 matben Exp $

package provide JUI 1.0


namespace eval ::JUI:: {
    
    # Add all event hooks.
    ::hooks::register quitAppHook            ::JUI::QuitHook
    ::hooks::register logoutHook             ::JUI::LogoutHook
    ::hooks::register setPresenceHook        ::JUI::SetPresenceHook
    ::hooks::register rosterIconsChangedHook ::JUI::RosterIconsChangedHook
    ::hooks::register prefsInitHook          ::JUI::InitPrefsHook
    ::hooks::register rosterTreeSelectionHook  ::JUI::RosterSelectionHook

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
    option add *JMain.chatImage                   newmsg          widgetDefault
    option add *JMain.chatDisImage                newmsgDis       widgetDefault
    option add *JMain.roster16Image               family16        widgetDefault
    option add *JMain.roster16DisImage            family16Dis     widgetDefault
    option add *JMain.browser16Image              run16           widgetDefault
    option add *JMain.browser16DisImage           run16Dis        widgetDefault

    # Top header image if any.
    option add *JMain.headImage                   ""              widgetDefault
    option add *JMain.head.borderWidth            0               50 
    option add *JMain.head.relief                 flat            50

    # Other icons.
    option add *JMain.contactOffImage             contactOff      widgetDefault
    option add *JMain.contactOnImage              contactOn       widgetDefault
    option add *JMain.waveImage                   wave            widgetDefault
    option add *JMain.resizeHandleImage           resizehandle    widgetDefault

    # Standard widgets.
    switch -- [tk windowingsystem] {
	aqua - x11 {
	    option add *JMain*TNotebook.padding   {8 8 8 4}       50
	    option add *JMain*bot.f.padding       {8 6 8 4}       50
	}
	default {
	    option add *JMain*TNotebook.padding   {4 4 4 2}       50
	    option add *JMain*bot.f.padding       {8 4 8 0}       50
	}
    }
    option add *JMain*TMenubutton.padding         {1}             50

    # Bug in 8.4.1 but ok in 8.4.9
    if {[regexp {^8\.4\.[0-5]$} [info patchlevel]]} {
	option add *JMain*me.style              Small.TLabel startupFile
    } else {
	option add *JMain*me.style              Small.Sunken.TLabel startupFile
    }
    
    # Special for X11 menus to look ok.
    if {[tk windowingsystem] eq "x11"} {
	option add *JMain.Menu.borderWidth        0               50
    }
    
    # Configurations:
    set ::config(url,home) "http://hem.fyristorg.com/matben/"
    set ::config(url,bugs)  \
      "http://sourceforge.net/tracker/?group_id=68334&atid=520863"
        
    # Collection of useful and common widget paths.
    variable jwapp
    variable inited 0
    
    set jwapp(w) -
}


proc ::JUI::Init { } {
    global  this
    
    # Menu definitions for the Roster/services window.
    variable menuDefs
    variable inited
    
    if {[string match "mac*" $this(platform)]} {
	set menuDefs(rost,file) {
	    {command   mNewWhiteboard      {::JWB::NewWhiteboard}     N}
	    {command   mCloseWindow        {::UI::CloseWindowEvent}   W}
	    {command   mPreferences...     {::Preferences::Build}     {}}
	    {separator}
	    {command   mQuit               {::UserActions::DoQuit}    Q}
	}
    } else {
	set menuDefs(rost,file) {
	    {command   mNewWhiteboard      {::JWB::NewWhiteboard}     N}
	    {command   mPreferences...     {::Preferences::Build}     {}}
	    {separator}
	    {command   mQuit               {::UserActions::DoQuit}    Q}
	}
    }
    set menuDefs(rost,jabber) {    
	{command     mNewAccount    {::RegisterEx::OnMenu}            {}}
	{command     mLogin         {::Jabber::OnMenuLogInOut}        L}
	{command     mLogoutWith    {::Jabber::Logout::OnMenuStatus}  {}}
	{command     mPassword      {::Jabber::Passwd::OnMenu}        {}}
	{separator}
	{checkbutton mMessageInbox  {::MailBox::OnMenu}               I \
	  {-variable ::JUI::state(mailbox,visible)}}
	{separator}
	{command     mSearch        {::Search::OnMenu}                {}}
	{command     mAddNewUser    {::JUser::OnMenu}                 {}}
	{cascade     mDisco         {}                                {} {} {
	    {command mAddServer     {::Disco::OnMenuAddServer}        {}}
	}}
	{separator}
	{command     mSendMessage   {::NewMsg::OnMenu}                M}
	{command     mChat          {::Chat::OnMenu}                  T}
	{cascade     mStatus        {}                                {} {} {}}
	{separator}
	{command     mEnterRoom     {::GroupChat::OnMenuEnter}        R}
	{command     mCreateRoom    {::GroupChat::OnMenuCreate}       {}}
	{command     mEditBookmarks {::GroupChat::OnMenuBookmark}     {}}
	{separator}
	{command     mvCard         {::VCard::OnMenu}                 {}}
	{cascade     mShow          {}                                {} {} {
	    {check   mToolbar       {::JUI::OnMenuToggleToolbar}      {} 
	    {-variable ::JUI::state(show,toolbar)}}
	    {check   mNotebook      {::JUI::OnMenuToggleNotebook}     {} 
	    {-variable ::JUI::state(show,notebook)}}
	    {check   mMinimal       {::JUI::OnMenuToggleMinimal}      {} 
	    {-variable ::JUI::state(show,minimal)}} }
	}
	{separator}
	{command     mRemoveAccount {::Register::OnMenuRemove}        {}}	
    }

    if {[tk windowingsystem] eq "aqua"} {
	set menuDefs(rost,info) {    
	    {command     mSetupAssistant {::Jabber::SetupAss::SetupAss} {}}
	    {command     mComponents    {::Dialogs::InfoComponents}     {}}
	    {command     mErrorLog      {::Jabber::ErrorLogDlg}         {}}
	    {checkbutton mDebug         {::Jabber::DebugCmd}            {} \
	      {-variable ::Jabber::jstate(debugCmd)}}
	    {separator}
	    {command     mCoccinellaHome {::JUI::OpenCoccinellaURL}     {}}
	    {command     mBugReport      {::JUI::OpenBugURL}            {}}
	}
    } else {
	set menuDefs(rost,info) {    
	    {command     mSetupAssistant {::Jabber::SetupAss::SetupAss} {}}
	    {command     mComponents    {::Dialogs::InfoComponents}      {}}
	    {command     mErrorLog      {::Jabber::ErrorLogDlg}          {}}
	    {checkbutton mDebug         {::Jabber::DebugCmd}             {} \
	      {-variable ::Jabber::jstate(debugCmd)}}
	    {separator}
	    {command     mAboutCoccinella  {::Splash::SplashScreen}      {}}
	    {command     mCoccinellaHome   {::JUI::OpenCoccinellaURL}    {}}
	    {command     mBugReport        {::JUI::OpenBugURL}           {}}
	}
    }

    # The status menu is built dynamically due to the -image options on 8.4.
    set idx [lindex [lsearchsublists $menuDefs(rost,jabber) mStatus] 0]
    lset menuDefs(rost,jabber) $idx 5 [::Jabber::Status::BuildMenuDef]

    set menuDefs(rost,edit) {    
	{command   mCut              {::UI::CutEvent}        X}
	{command   mCopy             {::UI::CopyEvent}       C}
	{command   mPaste            {::UI::PasteEvent}      V}
    }
    
    # We should do this for all menus eventaully.
    ::UI::PruneMenusFromConfig mJabber menuDefs(rost,jabber)
    ::UI::PruneMenusFromConfig mInfo   menuDefs(rost,info)
        
    # When registering new menu entries they shall be added at:
    variable menuDefsInsertInd

    # Let components register their menus *after* the last separator.
    foreach name {file edit jabber info} {
	set idx [lindex [lsearch -all $menuDefs(rost,$name) separator] end]
	if {$idx < 0} {
	    set idx [llength $menuDefs(rost,$name)]
	}
	set menuDefsInsertInd(rost,$name) $idx
    }
    
    # Defines which menus to use; names and labels.
    variable menuBarDef
    set menuBarDef {
	file    mFile
	jabber  mJabber
	info    mInfo
    }
    if {[tk windowingsystem] eq "aqua"} {
	set menuBarDef [linsert $menuBarDef 2 edit mEdit]
    }
    set inited 1
}

proc ::JUI::Show {w args} {
    upvar ::Jabber::jstate jstate

    array set argsArr $args
    if {[info exists argsArr(-visible)]} {
	set jstate(rostBrowseVis) $argsArr(-visible)
    }
    ::Debug 2 "::JUI::Show w=$w, jstate(rostBrowseVis)=$jstate(rostBrowseVis)"

    if {$jstate(rostBrowseVis)} {
	Build $w
	wm deiconify $w
	raise $w
    } else {
	catch {wm withdraw $w}
    }
}

# JUI::Build --
#
#       A combination tabbed window with roster/disco...
#       Must be persistant since roster/disco etc. are built once.
#       
# Arguments:
#       w           toplevel path
#       
# Results:
#       $w

proc ::JUI::Build {w} {
    global  this prefs
    
    upvar ::Jabber::jstate jstate
    upvar ::Jabber::jprefs jprefs
    variable menuBarDef
    variable menuDefs
    variable jwapp
    variable inited

    ::Debug 2 "::JUI::Build w=$w"
    
    if {!$inited} {
	Init
    }
    ::UI::Toplevel $w -class JMain \
      -macstyle documentProc -closecommand ::JUI::CloseHook  \
      -allowclose 0
    wm title $w $prefs(appName)
    ::UI::SetWindowGeometry $w
    
    set jwapp(w)     $w
    set jwapp(jmain) $w
    
    # Make main menus.
    set wmenu $w.menu
    set jwapp(wmenu) $wmenu
    menu $wmenu -tearoff 0

    if {([tk windowingsystem] eq "aqua") && $prefs(haveMenus)} {
	::UI::BuildAppleMenu $w $wmenu.apple normal
    }    
    foreach {name mLabel} $menuBarDef {
	BuildMenu $name
    }
    
    # Note that in 8.0 on Macintosh and Windows, all commands in a menu systems
    # are executed before any are posted. This is due to the limitations in the 
    # individual platforms' menu managers.
    $wmenu.file configure  \
      -postcommand [list ::JUI::FilePostCommand $wmenu.file]
    $wmenu.jabber configure  \
      -postcommand [list ::JUI::JabberPostCommand $wmenu.jabber]
    $wmenu.info configure  \
      -postcommand [list ::JUI::InfoPostCommand $wmenu.info]
    if {[tk windowingsystem] eq "aqua"} {
	$wmenu.edit configure  \
	  -postcommand [list ::JUI::EditPostCommand $wmenu.edit]
    }
    $w configure -menu $wmenu
    ::UI::SetMenubarAcceleratorBinds $w $wmenu

    
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
    # Need two frames so we can pack resize icon in the corner.
    set wbot $wall.bot
    ttk::frame $wbot
    pack $wbot -side bottom -fill x
    if {[tk windowingsystem] ne "aqua"} {
	ttk::label $wbot.size -compound image -image $iconResize
	pack  $wbot.size -side right -anchor s
    }
    
    set wfstat $wbot.f
    ttk::frame $wfstat
    pack $wfstat -fill x
  
    set wstatcont $wfstat.cont
    ::Jabber::Status::MainButton $wfstat.bst ::Jabber::jstate(status)
    ttk::frame $wfstat.cont
    ttk::label $wfstat.me -textvariable ::Jabber::jstate(mejidres) -anchor w
    pack  $wfstat.bst  $wfstat.cont  $wfstat.me  -side left
    pack  $wfstat.me  -fill x -expand 1 -padx 2 -pady 4
    if {[tk windowingsystem] eq "aqua"} {
	pack $wfstat.me -padx 6
    }
    
    # Notebook.
    set wnb $wall.nb
    ttk::notebook $wnb
    pack $wnb -side bottom -fill both -expand 1
    
    bind $wnb <<NotebookTabChanged>>  {+::JUI::NotebookTabChanged }
    
    # Make the Roster page -----------------------------------------------
    
    # Each notebook page must be a direct child of the notebook and we therefore
    # need to have a container frame which the roster is packed -in.
    set wroster $wall.ro
    set wrostco $wnb.cont
    ::Roster::Build $wroster
    frame $wrostco

    set imSpec [list $iconRoster disabled $iconRosterDis background $iconRosterDis]
    $wnb add $wrostco -compound left -text [mc Contacts] -image $imSpec  \
      -sticky news
    pack $wroster -in $wnb.cont -fill both -expand 1

    set jwapp(wtbar)     $wtbar
    set jwapp(tsep)      $wall.sep
    set jwapp(notebook)  $wnb
    set jwapp(roster)    $wroster
    set jwapp(mystatus)  $wfstat.bst
    set jwapp(myjid)     $wfstat.me
    set jwapp(statcont)  $wstatcont
    
    set minW [expr $trayMinW > 200 ? $trayMinW : 200]
    wm geometry $w ${minW}x360
    ::UI::SetWindowGeometry $w
    wm minsize $w $minW 300
    wm maxsize $w 480 2000
    
    ::hooks::run jabberBuildMain
    
    # Handle the prefs "Show" state.
    if {!$jprefs(ui,main,show,toolbar)} {
	HideToolbar
    }
    if {!$jprefs(ui,main,show,notebook)} {
	RosterMoveFromPage
    }
    return $w
}

proc ::JUI::NotebookTabChanged {} {
    variable jwapp
        
    set state disabled

    # We assume that the roster page has index 0.
    set current [$jwapp(notebook) index current]
    if {$current == 0} {
	set tags [::RosterTree::GetSelected]
	if {[llength $tags] == 1} {
	    lassign [lindex $tags 0] mtag jid
	    if {$mtag eq "jid"} {
		if {[::Jabber::RosterCmd isavailable $jid]} {
		    set state normal
		}
	    }
	}
    }
    $jwapp(wtbar) buttonconfigure chat -state $state  
}

proc ::JUI::StatusCmd {status} {
    
    # @@@ Could perhaps be moved to Status.
    if {[::Jabber::IsConnected]} {
	::Jabber::SetStatus $status
    } else {
	::Login::Dlg
    }
}

proc ::JUI::BuildToolbar {w wtbar} {
    
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
    set iconChat          [::Theme::GetImage [option get $w chatImage {}]]
    set iconChatDis       [::Theme::GetImage [option get $w chatDisImage {}]]
    
    ::ttoolbar::ttoolbar $wtbar
    
    $wtbar newbutton connect -text [mc Connect] \
      -image $iconConnect -disabledimage $iconConnectDis \
      -command ::Jabber::OnMenuLogInOut
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
      -command ::JUser::NewDlg -state disabled
    $wtbar newbutton chat -text [mc Chat] \
      -image $iconChat -disabledimage $iconChatDis  \
      -command ::Chat::OnToolButton -state disabled

    ::hooks::run buildJMainButtonTrayHook $wtbar

    return $wtbar
}

proc ::JUI::BuildMenu {name} {
    variable menuBarDef
    variable menuDefs
    variable menuDefsInsertInd
    variable extraMenuDefs
    variable jwapp

    set w     $jwapp(w)
    set wmenu $jwapp(wmenu)
    
    array set mLabel $menuBarDef
    set menuMerged $menuDefs(rost,$name)
    if {[info exists extraMenuDefs(rost,$name)]} {
	set menuMerged [eval {
	    linsert $menuMerged $menuDefsInsertInd(rost,$name)
	} $extraMenuDefs(rost,$name)]
    }
    ::UI::NewMenu $w $wmenu.$name  $mLabel($name)  $menuMerged
}

proc ::JUI::RosterMoveFromPage { } {
    variable jwapp
    upvar ::Jabber::jprefs jprefs
    
    pack forget $jwapp(roster)
    pack forget $jwapp(notebook)
    pack $jwapp(roster) -side bottom -fill both -expand 1
    set jprefs(ui,main,show,notebook) 0
}

proc ::JUI::RosterMoveToPage { } {
    variable jwapp
    upvar ::Jabber::jprefs jprefs
    
    pack forget $jwapp(roster)
    pack $jwapp(notebook) -side bottom -fill both -expand 1
    pack $jwapp(roster) -in $jwapp(notebook).cont -fill both -expand 1
    raise $jwapp(roster)
    set jprefs(ui,main,show,notebook) 1
}

proc ::JUI::GetMainWindow { } {
    global wDlgs
    
    return $wDlgs(jmain)
}

proc ::JUI::GetMainMenu { } {
    variable jwapp
    
    return $jwapp(wmenu)
}

proc ::JUI::OnMenuToggleToolbar { } {
    variable jwapp
    variable state
    
    if {[winfo ismapped $jwapp(wtbar)]} {
	HideToolbar
    } else {
	ShowToolbar
    }
    ::hooks::run uiMainToggleToolbar $state(show,toolbar)
}

proc ::JUI::HideToolbar { } {
    variable jwapp
    upvar ::Jabber::jprefs jprefs
    
    pack forget $jwapp(wtbar)
    pack forget $jwapp(tsep)
    set jprefs(ui,main,show,toolbar) 0
}

proc ::JUI::ShowToolbar { } {
    variable jwapp
    upvar ::Jabber::jprefs jprefs
    
    pack $jwapp(wtbar) -side top -fill x
    pack $jwapp(tsep)  -side top -fill x
    set jprefs(ui,main,show,toolbar) 1
}

proc ::JUI::OnMenuToggleNotebook { } {
    variable jwapp
    variable state
    
    if {[winfo ismapped $jwapp(notebook)]} {
	RosterMoveFromPage
    } else {
	RosterMoveToPage
    }
    ::hooks::run uiMainToggleNotebook $state(show,notebook)
}

proc ::JUI::OnMenuToggleMinimal { } {
    variable jwapp
    variable state
    upvar ::Jabber::jprefs jprefs

    # Handle via hooks since we can't know which tab pages we have.
    set jprefs(ui,main,show,minimal) $state(show,minimal)
    ::hooks::run uiMainToggleMinimal $state(show,minimal)
}

# JUI::SetAlternativeStatusImage --
# 
#       APIs for handling alternative status images.
#       Each instance is specified by a unique key.
#       
# Arguments:
#       key         unique key to identify this instance; used for widget path
#       image       the image to add or modify
#       
# Results:
#       the label widget added or modified

proc ::JUI::SetAlternativeStatusImage {key image} {
    variable jwapp
    variable altImageKeyToWin
    
    set wstatus $jwapp(statcont)
    if {[info exists altImageKeyToWin($key)]} {
	
	# Configure existing status image.
	set win $altImageKeyToWin($key)
	$altImageKeyToWin($key) configure -image $image
    } else {
	
	# Create new.
	set win $wstatus.$key
	set altImageKeyToWin($key) $win
	ttk::label $win -image $image
	pack $win -side left -padx 2 -pady 2
    }
    return $win
}

proc ::JUI::GetAlternativeStatusImage {key} {
    variable altImageKeyToWin

    if {[info exists altImageKeyToWin($key)]} {
	return [$altImageKeyToWin($key) cget -image]
    } else {
	return ""
    }
}

proc ::JUI::HaveAlternativeStatusImage {key} {
    variable altImageKeyToWin

    if {[info exists altImageKeyToWin($key)]} {
	return 1
    } else {
	return 0
    }
}

proc ::JUI::RemoveAlternativeStatusImage {key} {
    variable jwapp
    variable altImageKeyToWin
    
    if {[info exists altImageKeyToWin($key)]} {
	destroy $altImageKeyToWin($key)
	unset altImageKeyToWin($key)
	set wstatus $jwapp(statcont)
	
	# We want the container to resume its previous space but this seems needed.
	$wstatus configure -width 1
    }    
}

#...............................................................................

proc ::JUI::CloseHook {wclose} {    
    variable jwapp
    
    set result ""
    if {[info exists jwapp(jmain)]} {
	if {![::UserActions::DoQuit -warning 1]} {
	    set result stop
	}
    }   
    return $result
}

proc ::JUI::QuitHook { } {
    variable jwapp

    if {[info exists jwapp(jmain)]} {
	::UI::SaveWinGeom $jwapp(jmain)
    }
}

proc ::JUI::SetPresenceHook {type args} {
    
    # empty for the moment
}

proc ::JUI::RosterIconsChangedHook { } {
    variable jwapp
    upvar ::Jabber::jstate jstate
    
    set status $jstate(status)
    $jwapp(mystatus) configure -image [::Rosticons::Get status/$status]
}

proc ::JUI::RosterSelectionHook { } {
    variable jwapp
    
    set wtbar $jwapp(wtbar)
    set state disabled
    set tags [::RosterTree::GetSelected]
    if {[llength $tags] == 1} {
	lassign [lindex $tags 0] mtag jid
	if {$mtag eq "jid"} {
	    if {[::Jabber::RosterCmd isavailable $jid]} {
		set state normal
	    }
	}
    }
    $wtbar buttonconfigure chat -state $state    
}

proc ::JUI::LogoutHook { } {
    
    SetStatusMessage [mc {Logged out}]
    FixUIWhen "disconnect"
    SetConnectState "disconnect"
    
    # Be sure to kill the wave; could end up here when failing to connect.
    StartStopAnimatedWave 0
}
    
proc ::JUI::GetRosterWmenu { } {
    variable jwapp

    return $jwapp(wmenu)
}

proc ::JUI::OpenCoccinellaURL { } {
    global  config
    
    ::Utils::OpenURLInBrowser $config(url,home)
}

proc ::JUI::OpenBugURL { } {
    global  config
    
    ::Utils::OpenURLInBrowser $config(url,bugs)
}

proc ::JUI::StopConnect { } {
    
    ::Jabber::DoCloseClientConnection
    ::Login::Kill
}    

proc ::JUI::GetNotebook { } {
    variable jwapp
    
    return $jwapp(notebook)
}

proc ::JUI::StartStopAnimatedWave {start} {

    ::Roster::Animate $start
}

proc ::JUI::SetStatusMessage {msg} {

    ::Roster::TimedMessage $msg
}

# JUI::MailBoxState --
# 
#       Sets icon to display empty|nonempty inbox state.

proc ::JUI::MailBoxState {mailboxstate} {
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

# JUI::RegisterMenuEntry --
# 
#       Lets plugins/components register their own menu entry.

proc ::JUI::RegisterMenuEntry {name menuSpec} {
    variable jwapp
    
    # Keeps track of all registered menu entries.
    variable extraMenuDefs
    
    # Add these entries in a section above the bottom section.
    # Add separator to section component entries.
    
    if {![info exists extraMenuDefs(rost,$name)]} {

	# Add separator if this is the first addon entry.
	set extraMenuDefs(rost,$name) {separator}
    }
    lappend extraMenuDefs(rost,$name) $menuSpec
    
    # If already built menu need to rebuild it.
    if {[winfo exists $jwapp(w)]} {
	BuildMenu $name
    }
}

proc ::JUI::DeRegisterMenuEntry {name mLabel} {
    variable jwapp
    variable extraMenuDefs
    
    set ind 0
    if {[info exists extraMenuDefs(rost,$name)]} {
	set v $extraMenuDefs(rost,$name)
	foreach mdef $v {
	    set idx [lsearch $mdef $mLabel]
	    if {$idx == 1} {
		set extraMenuDefs(rost,$name) [lreplace $v $ind $ind]
		
		# If already built menu need to rebuild it.
		if {[winfo exists $jwapp(w)]} {
		    BuildMenu $name
		}
		break
	    }
	    incr ind
	}	
    }
}

proc ::JUI::FilePostCommand {wmenu} {
      
    ::hooks::run menuPostCommand main-file $wmenu
    
    # Workaround for mac bug.
    update idletasks
}

proc ::JUI::EditPostCommand {wmenu} {
    
    foreach {mkey mstate} [::UI::GenericCCPMenuStates] {
	::UI::MenuMethod $wmenu entryconfigure $mkey -state $mstate
    }	
    
    ::hooks::run menuPostCommand main-edit $wmenu

    # Workaround for mac bug.
    update idletasks
}

proc ::JUI::JabberPostCommand {wmenu} {
    global wDlgs
    variable state
    variable jwapp

    # For aqua we must do this only for .jmain
    if {[::UI::IsToplevelActive $wDlgs(jmain)]} {
	::UI::MenuMethod $wmenu entryconfigure mShow -state normal
	
	# Set -variable values.
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
	if {[::Roster::StyleGet] eq "minimal"} {
	    set state(show,minimal) 1
	} else {
	    set state(show,minimal) 0
	}
    } else {
	::UI::MenuMethod $wmenu entryconfigure mShow -state disabled
    }
    
    # Set -variable value.
    if {[::MailBox::IsVisible]} {
	set state(mailbox,visible) 1
    } else {
	set state(mailbox,visible) 0
    }
    
    switch -- [GetConnectState] {
	connectinit {
	    ::UI::MenuMethod $wmenu entryconfigure mNewAccount -state disabled
	    ::UI::MenuMethod $wmenu entryconfigure mLogin -state normal  \
	      -label [mc mLogout]
	}
	connectfin - connect {
	    ::UI::MenuMethod $wmenu entryconfigure mNewAccount -state disabled
	    ::UI::MenuMethod $wmenu entryconfigure mLogin -state normal  \
	      -label [mc mLogout]
	    ::UI::MenuMethod $wmenu entryconfigure mLogoutWith -state normal
	    ::UI::MenuMethod $wmenu entryconfigure mPassword -state normal
	    ::UI::MenuMethod $wmenu entryconfigure mSearch -state normal
	    ::UI::MenuMethod $wmenu entryconfigure mAddNewUser -state normal
	    ::UI::MenuMethod $wmenu entryconfigure mSendMessage -state normal
	    ::UI::MenuMethod $wmenu entryconfigure mChat -state normal
	    ::UI::MenuMethod $wmenu entryconfigure mStatus -state normal
	    ::UI::MenuMethod $wmenu entryconfigure mvCard -state normal
	    ::UI::MenuMethod $wmenu entryconfigure mEnterRoom -state normal
	    ::UI::MenuMethod $wmenu entryconfigure mCreateRoom -state normal
	    ::UI::MenuMethod $wmenu entryconfigure mEditBookmarks -state normal
	    ::UI::MenuMethod $wmenu entryconfigure mRemoveAccount -state normal
	    ::UI::MenuMethod $wmenu entryconfigure mDisco -state normal
	}
	disconnect {
	    ::UI::MenuMethod $wmenu entryconfigure mNewAccount -state normal
	    ::UI::MenuMethod $wmenu entryconfigure mLogin -state normal  \
	      -label [mc mLogin]
	    ::UI::MenuMethod $wmenu entryconfigure mLogoutWith -state disabled
	    ::UI::MenuMethod $wmenu entryconfigure mPassword -state disabled
	    ::UI::MenuMethod $wmenu entryconfigure mSearch -state disabled
	    ::UI::MenuMethod $wmenu entryconfigure mAddNewUser -state disabled
	    ::UI::MenuMethod $wmenu entryconfigure mSendMessage -state disabled
	    ::UI::MenuMethod $wmenu entryconfigure mChat -state disabled
	    ::UI::MenuMethod $wmenu entryconfigure mStatus -state disabled
	    ::UI::MenuMethod $wmenu entryconfigure mvCard -state disabled
	    ::UI::MenuMethod $wmenu entryconfigure mEnterRoom -state disabled
	    ::UI::MenuMethod $wmenu entryconfigure mCreateRoom -state disabled
	    ::UI::MenuMethod $wmenu entryconfigure mEditBookmarks -state disabled
	    ::UI::MenuMethod $wmenu entryconfigure mRemoveAccount -state disabled
	    ::UI::MenuMethod $wmenu entryconfigure mDisco -state disabled
	}	
    }    
        
    ::hooks::run menuPostCommand main-jabber $wmenu
    
    # Workaround for mac bug.
    update idletasks
}

proc ::JUI::InfoPostCommand {wmenu} {

    switch -- [GetConnectState] {
	connectinit {
	    ::UI::MenuMethod $wmenu entryconfigure mSetupAssistant -state disabled
	}
	connectfin - connect {
	    ::UI::MenuMethod $wmenu entryconfigure mSetupAssistant -state disabled
	}
	disconnect {
	    ::UI::MenuMethod $wmenu entryconfigure mSetupAssistant -state normal
	}	
    }    
	
    ::hooks::run menuPostCommand main-info $wmenu
    
    # Workaround for mac bug.
    update idletasks   
}

namespace eval ::JUI {
    variable connectState
    
    set connectState disconnect
}

proc ::JUI::GetConnectState {} {
    variable connectState
    
    return $connectState
}

proc ::JUI::SetConnectState {state} {
    variable connectState
    
    set connectState $state
    return $connectState
}

# JUI::FixUIWhen --
#       
#       Sets the correct state for menus and buttons when 'what'.
#       
# Arguments:
#       what        'connectinit', 'connectfin', 'connect', 'disconnect'
#
# Results:

proc ::JUI::FixUIWhen {what} {
    variable jwapp
        
    set w     $jwapp(jmain)
    set wtbar $jwapp(wtbar)
        
    set contactOffImage [::Theme::GetImage [option get $w contactOffImage {}]]
    set contactOnImage  [::Theme::GetImage [option get $w contactOnImage {}]]

    switch -exact -- $what {
	connectinit {
	    set stopImage [::Theme::GetImage [option get $w stopImage {}]]

	    $wtbar buttonconfigure connect -text [mc Stop] \
	      -image $stopImage -disabledimage $stopImage \
	      -command ::JUI::StopConnect
	}
	connectfin - connect {
	    set connectedImage    [::Theme::GetImage [option get $w connectedImage {}]]
	    set connectedDisImage [::Theme::GetImage [option get $w connectedDisImage {}]]

	    $wtbar buttonconfigure connect -text [mc Logout] \
	      -image $connectedImage -disabledimage $connectedDisImage \
	      -command ::Jabber::OnMenuLogInOut
	    $wtbar buttonconfigure newuser -state normal
	}
	disconnect {
	    set iconConnect     [::Theme::GetImage [option get $w connectImage {}]]
	    set iconConnectDis  [::Theme::GetImage [option get $w connectDisImage {}]]

	    $wtbar buttonconfigure connect -text [mc Login] \
	      -image $iconConnect -disabledimage $iconConnectDis \
	      -command ::Jabber::OnMenuLogInOut
	    $wtbar buttonconfigure newuser -state disabled
	}
    }
}

proc ::JUI::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs

    set jprefs(ui,main,show,toolbar)  1
    set jprefs(ui,main,show,notebook) 1
    set jprefs(ui,main,show,minimal)  0
    
    set plist {}
    foreach key {toolbar notebook minimal} {
	set name ::Jabber::jprefs(ui,main,show,$key)
	set rsrc jprefs_ui_main_show_$key
	set val  [set $name]
	lappend plist [list $name $rsrc $val]
    }
    ::PrefUtils::Add $plist
}

#-------------------------------------------------------------------------------
