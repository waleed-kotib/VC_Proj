#  JUI.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements jabber GUI parts.
#      
#  Copyright (c) 2001-2008  Mats Bengtsson
#  
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#  
# $Id: JUI.tcl,v 1.277 2008-09-24 18:37:58 sdevrieze Exp $

package provide JUI 1.0

namespace eval ::JUI {
    
    # Add all event hooks.
    ::hooks::register quitAppHook            ::JUI::QuitHook
    ::hooks::register loginHook              ::JUI::LoginHook
    ::hooks::register logoutHook             ::JUI::LogoutHook
    ::hooks::register setPresenceHook        ::JUI::SetPresenceHook
    ::hooks::register rosterIconsChangedHook ::JUI::RosterIconsChangedHook
    ::hooks::register prefsInitHook          ::JUI::InitPrefsHook
    ::hooks::register rosterTreeSelectionHook  ::JUI::RosterSelectionHook

    ::hooks::register prefsInitHook          ::JUI::ToyStatusInitPrefsHook
    ::hooks::register quitAppHook            ::JUI::ToyStatusQuitHook

    ::hooks::register prefsInitHook          ::JUI::SlotInitPrefsHook
    ::hooks::register quitAppHook            ::JUI::SlotQuitHook

    # Use option database for customization.
    # Shortcut buttons.
    option add *JMain.connectImage            network-disconnect    widgetDefault
    option add *JMain.connectDisImage         network-disconnect-Dis  widgetDefault
    option add *JMain.connectedImage          network-connect       widgetDefault
    option add *JMain.connectedDisImage       network-connect-Dis   widgetDefault
    option add *JMain.inboxImage              inbox                 widgetDefault
    option add *JMain.inboxDisImage           inbox-Dis             widgetDefault
    option add *JMain.inboxLetterImage        inbox-unread          widgetDefault
    option add *JMain.inboxLetterDisImage     inbox-unread-Dis      widgetDefault
    option add *JMain.adduserImage            list-add-user         widgetDefault
    option add *JMain.adduserDisImage         list-add-user-Dis     widgetDefault
    option add *JMain.stopImage               dialog-error          widgetDefault
    option add *JMain.stopDisImage            dialog-error-Dis      widgetDefault
    option add *JMain.chatImage               chat-message-new      widgetDefault
    option add *JMain.chatDisImage            chat-message-new-Dis  widgetDefault
    option add *JMain.roster16Image           invite                widgetDefault
    option add *JMain.roster16DisImage        invite-Dis            widgetDefault

    # Top header image if any.
    option add *JMain.headImage                   ""              widgetDefault
    option add *JMain.head.borderWidth            0               50 
    option add *JMain.head.relief                 flat            50

    # Other icons.
    option add *JMain.sizeGripImage               sizegrip        widgetDefault
    option add *JMain.secureHighImage             security-high   widgetDefault
    option add *JMain.secureMedImage              security-medium   widgetDefault
    option add *JMain.secureLowImage              security-low   widgetDefault

    option add *JMain.cociEs32                    coccinella2      widgetDefault
    option add *JMain.cociEsActive32              coccinella2-shadow widgetDefault

    # Standard widgets.
    switch -- [tk windowingsystem] {
	aqua {
	    option add *JMain*TNotebook.padding   {0 8 0 4}       50
	    option add *JMain*bot.f.padding       {8 6 4 4}       50
	}
	x11 {
	    option add *JMain*TNotebook.padding   {0 4 0 2}       50
	    option add *JMain*bot.f.padding       {2 4 2 2}       50
	}
	default {
	    option add *JMain*TNotebook.padding   {0 4 0 2}       50
	    option add *JMain*bot.f.padding       {8 6 4 4}       50
	}
    }
    option add *JMain*TMenubutton.padding         {1}             50
    option add *JMain*me.style              Small.Sunken.TLabel startupFile
    # Alternative.
    #option add *JMain*me.style              LSafari startupFile
    
    # Configurations:
    # http adresses to home and bug tracker.
    set ::config(url,home) "http://thecoccinella.org"
    set ::config(url,bugs) "https://bugs.launchpad.net/coccinella/+filebug"
        
    # Type of status menu button.
    set ::config(ui,status,menu)        dynamic   ;# plain|dynamic
    
    # This just sets the initial prefs value.
    set ::config(ui,main,infoType)      server    ;# mejid|mejidres|status|server

    # Experimental...
    set ::config(ui,main,slots)            0
    set ::config(ui,main,combi-status)     0
    set ::config(ui,main,toy-status)       1
    set ::config(ui,main,toy-status-slots) 1
    set ::config(ui,main,combibox)         0
    
    # Let the slots slide up/down. Performance issues with this.
    set ::config(ui,main,slots-slide)      1
    
    # Simplified slide widget which just shows an empty frame for the panel.
    set ::config(ui,main,slots-slide-fake) 1
    
    # This is a trick to get the aqua text borders.
    if {[tk windowingsystem] eq "aqua"} {
	set ::config(ui,aqua-text)      1
    } else {
	set ::config(ui,aqua-text)      0
    }
    
    # Collection of useful and common widget paths.
    variable jwapp
    variable inited 0
    
    set jwapp(w) -
    set jwapp(mystatus) -
    set jwapp(securityWinL) [list]
}

proc ::JUI::Init {} {
    global  this config
    
    # Menu definitions for the Roster/services window.
    variable menuDefs
    variable inited
            
    set mDefsFile {
	{command   mNewAccount...      {::RegisterEx::OnMenu}     {}}
	{command   mRemoveAccount...   {::Register::OnMenuRemove} {}}	
	{command   mNewPassword...     {::Jabber::Passwd::OnMenu} {}}
	{command   mSetupAssistant...  {::SetupAss::SetupAss}     {}}
	{separator}
	{command   mEditProfiles...    {::Profiles::BuildDialog}  {}}
	{command   mEditBC...          {::VCard::OnMenu}          {}}
	{separator}
	{cascade   mImport             {}                         {} {} {
	    {command  mIconSet...      {::Emoticons::ImportSet}   {}}
	    {command  mBC...           {::VCard::Import}          {}}
	}}
	{cascade   mExport             {}                         {} {} {
	    {command  mContacts...     {::Roster::ExportRoster}   {}}
	    {command  mInbox...        {::MailBox::MKExportDlg}   {}}
	    {command  mBC...           {::VCard::OnMenuExport}    {}}
	}}
	{separator}
	{command   mQuit               {::UserActions::DoQuit}    Q}
    }
    if {[tk windowingsystem] eq "aqua"} {
	set mDefsClose [list {command   mCloseWindow  {::UI::CloseWindowEvent}  W}]
	set menuDefs(rost,file) [concat $mDefsClose {separator} $mDefsFile]
    } else {    
	set mDefsPrefs [list {command   mPreferences...  {::Preferences::Build}  {}}]
	set menuDefs(rost,file) [concat $mDefsPrefs {separator} $mDefsFile]
    }
        
    set menuDefs(rost,action) {    
	{command     mLogin...      {::Jabber::OnMenuLogInOut}        L}
	{command     mLogoutWith... {::Jabber::Logout::OnMenuStatus}  {}}
	{separator}
	{command     mMessage...    {::NewMsg::OnMenu}                M}
	{command     mChat...       {::Chat::OnMenu}                  T}
	{cascade     mStatus        {}                                {} {} {}}
	{separator}
	{command     mSearch...     {::Search::OnMenu}                {}}
	{command     mAddContact... {::JUser::OnMenu}                 U}
	{cascade     mRegister...   {}                                {} {} {}}
	{command     mDiscoverServer... {::Disco::OnMenuAddServer}    D}
	{separator}
	{command     mEnterRoom...  {::GroupChat::OnMenuEnter}        R}
	{command     mCreateRoom... {::GroupChat::OnMenuCreate}       {}}
	{command     mEditBookmarks... {::GroupChat::OnMenuBookmark}     {}}
    }

    if {[::Jabber::HaveWhiteboard]} {
	set mWhiteboard \
	  {command   mWhiteboard  {::JWB::OnMenuNewWhiteboard}  N}
	set idx [lsearch $menuDefs(rost,action) *mChat...*]
	incr idx
	set menuDefs(rost,action) \
	  [linsert $menuDefs(rost,action) $idx $mWhiteboard]
    }
    
    set mDefsInfo {    
	{command     mPlugins       {::Component::Dlg}              {}}
	{checkbutton mInbox...      {::MailBox::OnMenu}               I \
	  {-variable ::JUI::state(mailbox,visible)}}
	{cascade     mFontSize      {}                              {} {} {
	    {radio   mNormal        {::Theme::FontConfigSize  0}    {}
	    {-variable prefs(fontSizePlus) -value 0}}
	    {radio   mLargerFont    {::Theme::FontConfigSize +1}    {}
	    {-variable prefs(fontSizePlus) -value 1}}
	    {radio   mLargeFont     {::Theme::FontConfigSize +2}    {}
	    {-variable prefs(fontSizePlus) -value 2}}
	    {radio   mHugeFont      {::Theme::FontConfigSize +6}    {}
	    {-variable prefs(fontSizePlus) -value 6}}
	} }
	{cascade     mShow          {}                              {} {} {
	    {check   mToolbar       {::JUI::OnMenuToggleToolbar}    {} 
	    {-variable ::JUI::state(show,toolbar)}}
	    {check   mTabs          {::JUI::OnMenuToggleNotebook}   {} 
	    {-variable ::JUI::state(show,notebook)}}
	} }
	{cascade     mControlPanel  {}                              {} {} {}}
	{separator {}}
	{command     mErrorLog      {::Jabber::ErrorLogDlg}         {}}
	{checkbutton mDebug         {::Jabber::DebugCmd}            {} \
	  {-variable ::Jabber::jstate(debugCmd)}}
	{command     mBugReport...  {::JUI::OpenBugURL}             {}}
	{separator {}}
	{command     mCoccinellaHome... {::JUI::OpenCoccinellaURL}  {}}
    }
    if {$config(ui,main,toy-status)} {
	# NB: this may depend on our initial state if open or closed.
	set m {command  mShowControlPanel  {::JUI::ToyStatusCmd}  {Shift-O}}
	set idx [lsearch -index 1 $mDefsInfo mControlPanel]
	set mDefsInfo [linsert $mDefsInfo $idx $m]
    }
    if {[tk windowingsystem] eq "aqua"} {
	set menuDefs(rost,info) $mDefsInfo
    } else {
	set mAbout {command  mAboutCoccinella  {::Splash::SplashScreen}  {}}
	set idx [lsearch -index 1 $mDefsInfo mCoccinellaHome...]
	set menuDefs(rost,info) [linsert $mDefsInfo $idx $mAbout]
    }
    
    set menuDefs(rost,edit) {    
	{command   mUndo             {::UI::UndoEvent}          Z}
	{command   mRedo             {::UI::RedoEvent}          Shift-Z}
	{separator}
	{command   mCut              {::UI::CutEvent}           X}
	{command   mCopy             {::UI::CopyEvent}          C}
	{command   mPaste            {::UI::PasteEvent}         V}
	{separator}
	{command   mAll              {::UI::OnMenuAll}          A}
	{separator}
	{command   mFind             {::UI::OnMenuFind}         F}
	{command   mFindNext         {::UI::OnMenuFindAgain}    G}
	{command   mFindPrevious     {::UI::OnMenuFindPrevious} Shift-G}
    }
    
    # We should do this for all menus eventaully.
    ::UI::PruneMenusFromConfig mJabber menuDefs(rost,action)
    ::UI::PruneMenusFromConfig mInfo   menuDefs(rost,info)
        
    # When registering new menu entries they shall be added at:
    variable menuDefsInsertInd

    # Let components register their menus *after* the last separator.
    foreach name {file edit action info} {
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
	action  mAction
	info    mInfo
    }
    if {[tk windowingsystem] eq "aqua"} {
	set menuBarDef [linsert $menuBarDef 2 edit mEdit]
    }
    set inited 1
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
    global  this prefs config jprefs
    
    upvar ::Jabber::jstate jstate
    variable menuBarDef
    variable menuDefs
    variable jwapp
    variable inited

    ::Debug 2 "::JUI::Build w=$w"
    
    if {!$inited} {
	Init
    }
    ::UI::Toplevel $w -class JMain \
      -macclass {document {toolbarButton standardDocument}} \
      -closecommand ::JUI::CloseHook -allowclose 0

    wm title $w $prefs(appName)
    ::UI::SetWindowGeometry $w

    set jwapp(w)     $w
    set jwapp(jmain) $w

    bind $w <<ToolbarButton>> ::JUI::OnToolbarButton

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
    $wmenu.file configure \
      -postcommand [list ::JUI::FilePostCommand $wmenu.file]
    $wmenu.action configure  \
      -postcommand [list ::JUI::ActionPostCommand $wmenu.action]
    $wmenu.info configure \
      -postcommand [list ::JUI::InfoPostCommand $wmenu.info]
    if {[tk windowingsystem] eq "aqua"} {
	$wmenu.edit configure \
	  -postcommand [list ::JUI::EditPostCommand $wmenu.edit]
    }
    $w configure -menu $wmenu
    ::UI::RegisterAccelerator "B" \
      [list ::Status::ExOnMenuCustomStatus $wmenu.action]
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
    set headImage [::Theme::Find32Icon $w headImage]
    if {$headImage ne ""} {
	ttk::label $wall.head -image $headImage
	pack  $wall.head -side top -anchor w
    }

    # Other icons.
    set iconResize    [::Theme::FindIcon elements/[option get $w sizeGripImage {}]]
    set iconRoster    [::Theme::Find16Icon $w roster16Image]
    set iconRosterDis [::Theme::Find16Icon $w roster16DisImage]
    
    set wtbar $wall.tbar
    BuildToolbar $w $wtbar
    pack $wtbar -side top -fill x

    # The top separator shall only be mapped between the toolbar and the notebook.
    ttk::separator $wall.sep -orient horizontal
    pack $wall.sep -side top -fill x
   
    # Experiment!
    if {$config(ui,main,slots)} {
 	SlotBuild $wall.slot
 	pack $wall.slot -side bottom -fill x
    }

    # Status frame. 
    # Need two frames so we can pack resize icon in the corner.
    if {$config(ui,main,combi-status)} {
	set wbot $wall.bot
	ttk::frame $wbot
	pack $wbot -side bottom -fill x
	
	ttk::frame $wbot.r
	pack  $wbot.r  -side right -fill y
	
	if {[tk windowingsystem] ne "aqua"} {
	    ttk::label $wbot.r.size -style Plainer \
	      -compound image -image $iconResize
	} else {
	    ttk::frame $wbot.r.size -width [image width $iconResize] \
	      -height [image height $iconResize]
	}
	ttk::button $wbot.r.secure -style Plainer \
	  -compound image -padding {0 2 2 0}
	
	grid  $wbot.r.secure
	grid  $wbot.r.size    -sticky se
	grid columnconfigure $wbot.r 0 -minsize 20 ;# 16 + 2*2
	grid rowconfigure    $wbot.r 0 -weight 1
	
	set wfstat $wbot.f
	ttk::frame $wfstat
	pack $wfstat -fill x
	
	# Avatar menu button.
	::AvatarMB::Button $wfstat.ava
	
	set wstatcont $wfstat.cont
	if {$config(ui,status,menu) eq "plain"} {
	    ::Status::MainButton $wfstat.bst ::Jabber::jstate(show)
	} elseif {$config(ui,status,menu) eq "dynamic"} {
	    ::Status::ExMainButton $wfstat.bst ::Jabber::jstate(show+status)
	}
	
	set infoType $jprefs(ui,main,InfoType)
	ttk::frame $wfstat.cont
	if {0} {
	    ttk::label $wfstat.me -textvariable ::Jabber::jstate($infoType) -anchor w
	} else {
	    BuildStatusMB $wfstat.me
	}
	pack  $wfstat.ava  -side right -pady 1
	pack  $wfstat.bst  $wfstat.cont  $wfstat.me  -side left
	pack  $wfstat.me  -padx 6 -pady 4 -fill x -expand 1

	set jwapp(mystatus)  $wfstat.bst
	set jwapp(myjid)     $wfstat.me
	set jwapp(statcont)  $wstatcont
	set jwapp(secure)    $wbot.r.secure
	lappend jwapp(securityWinL) $wbot.r.secure
    }
    
    # Experimental.
    if {$config(ui,main,combibox)} {
	BuildCombiBox $wall.comb
	pack $wall.comb -side top -fill x
    }
    
    # Experimental.
    if {$config(ui,main,toy-status)} {
	BuildToyStatus $wall.toy
	pack $wall.toy -side bottom -fill x
    }
    
    # Notebook.
    set wnb $wall.nb
    ttk::notebook $wnb
    tileutils::nb::Traversal $wnb
    pack $wnb -side top -fill both -expand 1
    
    bind $wnb <<NotebookTabChanged>>  {+::JUI::NotebookTabChanged }
    
    # Make the Roster page -----------------------------------------------
    
    # Each notebook page must be a direct child of the notebook and we therefore
    # need to have a container frame which the roster is packed -in.
    set wroster $wall.ro
    ::Roster::Build $wroster
    set wrostco $wnb.cont
    frame $wrostco

    set imSpec [list $iconRoster disabled $iconRosterDis background $iconRosterDis]
    $wnb add $wrostco -compound left -text [mc "Contacts"] -image $imSpec  \
      -sticky news
    pack $wroster -in $wnb.cont -fill both -expand 1

    set jwapp(wtbar)     $wtbar
    set jwapp(tsep)      $wall.sep
    set jwapp(notebook)  $wnb
    set jwapp(roster)    $wroster
    set jwapp(rostcont)  $wrostco
    set jwapp(wslot)     $wall.mp
    
    # Add an extra margin for Login/Logout string lengths.
    set trayMinW [expr {[$wtbar minwidth] + 12}]
    set minW [expr {$trayMinW < 200 ? 200 : $trayMinW}]
    wm geometry $w ${minW}x360
    ::UI::SetWindowGeometry $w
    wm minsize $w $minW 300
    wm maxsize $w 800 2000

    bind $w <<Find>>         [namespace code Find]
    bind $w <<FindAgain>>    [namespace code [list FindAgain +1]]  
    bind $w <<FindPrevious>> [namespace code [list FindAgain -1]]  

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

proc ::JUI::BuildStatusMB {win} {
    global jprefs
    
    set infoType $jprefs(ui,main,InfoType)
   
    ttk::menubutton $win -style SunkenMenubutton \
      -textvariable ::Jabber::jstate($infoType)

    dict set msgD mejid    [mc "Own Contact ID"]
    dict set msgD mejidres [mc "Own Full Contact ID"]
    dict set msgD server   [mc "Server"]
    dict set msgD status   [mc "Status"]
    
    set m $win.m
    menu $m -tearoff 0
    $win configure -menu $m

    dict for {value label} $msgD {
	$m add radiobutton -label $label \
	  -variable ::jprefs(ui,main,InfoType) -value $value \
	  -command ::JUI::StatusMBCmd
    }
    return $win
}

proc ::JUI::StatusMBCmd {} {
    global jprefs
    variable jwapp
    
    set infoType $jprefs(ui,main,InfoType)
    $jwapp(myjid) configure -textvariable ::Jabber::jstate($infoType)
}

#--- Presence Combi Box --------------------------------------------------------

# @@@ PEP Nickname push on login???

namespace eval ::JUI {
    
    option add *PresenceCombiBox.padding {8 4 8 4} widgetDefault
    
    variable combiBox
    set combiBox(w) -
    set combiBox(status)  ""
    set combiBox(statusL) [list]
    
    ::hooks::register loginHook           ::JUI::CombiBoxLoginHook
    ::hooks::register logoutHook          ::JUI::CombiBoxLogoutHook
    ::hooks::register setPresenceHook     ::JUI::CombiBoxPresenceHook
    ::hooks::register setNicknameHook     ::JUI::CombiBoxNicknameHook

}

proc ::JUI::BuildCombiBox {w} {
    global  config
    variable combiBox
    
    ttk::frame $w -class PresenceCombiBox
    
    ::AvatarMB::Button $w.ava -postalign left
    if {$config(ui,status,menu) eq "plain"} {
	::Status::MainButton $w.bst ::Jabber::jstate(show)
    } elseif {$config(ui,status,menu) eq "dynamic"} {
	::Status::ExMainButton $w.bst ::Jabber::jstate(show+status)
    }
    ttk::label $w.nick -style Small.TLabel -text [mc mNotAvailable] -anchor w
    ttk::combobox $w.combo -style Small.TCombobox -font CociSmallFont \
      -values $combiBox(statusL) \
      -textvariable [namespace current]::combiBox(status)
    
    set wcombo $w.combo
    $wcombo state {disabled}

    bind $wcombo <<ComboboxSelected>> ::JUI::CombiBoxSetStatus
    bind $wcombo <Return>             ::JUI::CombiBoxSetStatus
    bind $wcombo <KP_Enter>           ::JUI::CombiBoxSetStatus
    bind $wcombo <FocusIn>            ::JUI::CombiBoxOnFocusIn
    bind $wcombo <FocusOut>           ::JUI::CombiBoxOnFocusOut
    
    grid  $w.ava  $w.bst  $w.nick   -padx 4
    grid  ^       ^       $w.combo  -padx 4
    grid $w.nick -stick ew
    grid $w.combo -stick ew
    grid columnconfigure $w 2 -weight 1
    
    ::balloonhelp::balloonforwindow $w.nick  [mc "Displays your Contact ID or nickname"]
    ::balloonhelp::balloonforwindow $w.combo [mc "Set your presence message"]
    
    set combiBox(w) $w
    set combiBox(wnick)  $w.nick
    set combiBox(wenick) $w.enick
    set combiBox(wcombo) $w.combo  
    set combiBox(status) [mc "Set your presence message"]
    set combiBox(statusSet) 0
    
    return $w
}

proc ::JUI::CombiBoxLoginHook {} {
    upvar ::Jabber::jstate jstate
    variable combiBox
    
    if {![winfo exists $combiBox(w)]} {
	return
    }
    set myjid2 [::Jabber::Jlib myjid2]
    set ujid [jlib::unescapestr $myjid2]
    set wnick $combiBox(wnick)
    $wnick configure -text $ujid

    set server [::Jabber::Jlib getserver]
    ::Jabber::Jlib pep have $server [namespace code CombiBoxHavePEP]
}

proc ::JUI::CombiBoxHavePEP {jlib have} {
    variable combiBox

    if {![winfo exists $combiBox(w)]} {
	return
    }
    if {$have} {
	::balloonhelp::balloonforwindow $combiBox(wnick) "Click to set your nickname (PEP)"
	bind $combiBox(wnick) <Button-1> ::JUI::CombiBoxOnNick
    }
}

proc ::JUI::CombiBoxLogoutHook {} {
    variable combiBox
    
    if {![winfo exists $combiBox(w)]} {
	return
    }
    destroy $combiBox(wenick)
    bind $combiBox(wnick) <Button-1> {}
    $combiBox(wnick) configure -text [mc mNotAvailable]
    set combiBox(nick) ""
    
    # Leave the previous JID/nick?
    #$combiBox(wnick) configure -text ""    
}

proc ::JUI::CombiBoxNicknameHook {nickname} {
    variable combiBox
    upvar ::Jabber::jstate jstate
    
    if {![winfo exists $combiBox(w)]} {
	return
    }
    if {$nickname eq ""} {
	set myjid2 [::Jabber::Jlib myjid2]
	set ujid [jlib::unescapestr $myjid2]
	$combiBox(wnick) configure -text $ujid
    } else {
	$combiBox(wnick) configure -text $nickname	
    }
}

proc ::JUI::CombiBoxPresenceHook {type args} {
    variable combiBox
    
    if {![winfo exists $combiBox(w)]} {
	return
    }
    array set argsA $args
    if {[info exists argsA(-to)]} {
	return
    }
    set wcombo $combiBox(wcombo)
    if {$type eq "unavailable"} {
	$wcombo state {disabled}
    } else {
	$wcombo state {!disabled}
    }
    if {[info exists argsA(-status)] && [string length $argsA(-status)]} {
	set status $argsA(-status)
	set combiBox(status) $status
	set combiBox(statusL) \
	  [lrange [luniqueo [linsert $combiBox(statusL) 0 $status]] 0 12]
	set combiBox(statusSet) 1
	$wcombo configure -values $combiBox(statusL)
    } else {
	set combiBox(status) ""
    }
}

proc ::JUI::CombiBoxOnNick {} {
    variable combiBox
    
    set wenick $combiBox(wenick)
    destroy $wenick
    ttk::entry $wenick -font CociSmallFont \
      -textvariable [namespace current]::combiBox(nick)
    grid  $wenick  -column 2 -row 0 -padx 4 -stick ew
    set combiBox(focus) [focus]
    focus $wenick
    
    bind $wenick <Return>   ::JUI::CombiBoxNickReturn
    bind $wenick <KP_Enter> ::JUI::CombiBoxNickReturn
    bind $wenick <FocusOut> ::JUI::CombiBoxNickEditEnd
}

proc ::JUI::CombiBoxNickReturn {} {
    variable combiBox
    
    if {$combiBox(nick) ne ""} {
	::Nickname::Publish $combiBox(nick)
    } else {
	::Nickname::Retract
    }
    catch {focus $combiBox(focus)}
}

proc ::JUI::CombiBoxNickEditEnd {} {
    variable combiBox
  
    destroy $combiBox(wenick)
}

proc ::JUI::CombiBoxSetStatus {} {
    upvar ::Jabber::jstate jstate
    variable combiBox
    
    ::Jabber::SetStatus $jstate(show) -status $combiBox(status)
    ::Status::ExAddMessage $jstate(show) $combiBox(status)
    catch {focus [winfo toplevel $combiBox(w)]}
}

proc ::JUI::CombiBoxOnFocusIn {} {
    upvar ::Jabber::jstate jstate
    variable combiBox

    puts "::JUI::CombiBoxOnFocusIn"
    if {!$combiBox(statusSet)} {
	set combiBox(status) ""
    }
}

proc ::JUI::CombiBoxOnFocusOut {} {
    upvar ::Jabber::jstate jstate
    variable combiBox

    puts "::JUI::CombiBoxOnFocusOut"
    
    # Reset to actual value.
    set combiBox(status) $jstate(status)
}

#-------------------------------------------------------------------------------

proc ::JUI::ToyStatusInitPrefsHook {} {
    global jprefs

    set jprefs(toystatus,mapped) 1
    
    ::PrefUtils::Add [list \
      [list jprefs(toystatus,mapped) jprefs_toystatus_mapped $jprefs(toystatus,mapped)]  \
      ]
    
}

proc ::JUI::BuildToyStatus {wtoy} {
    global  config jprefs
    variable jwapp
	
    set im  [::Theme::FindIconSize 22 coccinella2]
    set ima [::Theme::FindIconSize 22 coccinella2-shadow]
    set y [expr {[image height $im]/2}]
    
    ttk::frame $wtoy
    
    ttk::button $wtoy.b -style Plain \
      -image [list $im {active !pressed} $ima {active pressed} $im] \
      -command [namespace code ToyStatusCmd]
    ttk::button $wtoy.secure -style Plainer \
      -compound image -padding {2}
    
    pack $wtoy.b -side top -padx 12 -pady 2
    place $wtoy.secure -x 4 -y $y -anchor w
    
    lappend jwapp(securityWinL) $wtoy.secure
    
    set wmp $wtoy.mp
    
    set jwapp(wtoy)    $wtoy
    set jwapp(wtoyb)   $wtoy.b
    set jwapp(wmp)     $wtoy.mp
    set jwapp(wtoysec) $wtoy.secure

    if {$config(ui,main,toy-status-slots)} {
	menu $wtoy.b.m -tearoff 0
	bind $wtoy   <<ButtonPopup>> \
	  [namespace code [list SlotPopup %W %x %y]]
	bind $wtoy.b <<ButtonPopup>> \
	  [namespace code [list SlotPopup %W %x %y]]
	
	set jwapp(slotmenu) $wtoy.b.m
	SlotBuild $wmp
	
	if {$jprefs(toystatus,mapped)} {
	    SlotDisplay
	}
    } else {
	::MegaPresence::Build $wmp -collapse 0
	bind $wtoy.b <<ButtonPopup>> [list ::MegaPresence::Popup %W $wmp %x %y]
    }
    ::balloonhelp::balloonforwindow $wtoy.b [mc "Show Control Panel"]

    return $wtoy
}

proc ::JUI::ToyStatusCmd {} {
    global  config
    variable jwapp

    if {[winfo ismapped $jwapp(wmp)]} {
	if {$config(ui,main,slots-slide)} {
	    if {$config(ui,main,slots-slide-fake)} {
		SlotSlideFakeDown
	    } else {
		SlotSlideDown
	    }
	} else {
	    SlotHide
	}
    } else {
	if {$config(ui,main,slots-slide)} {
	    if {$config(ui,main,slots-slide-fake)} {
		SlotSlideFakeUp
	    } else {
		SlotSlideUp
	    }
	} else {
	    SlotDisplay
	}
    }
}

proc ::JUI::ToyStatusIsMapped {} {
    variable jwapp
    return [winfo ismapped $jwapp(wmp)]
}

proc ::JUI::BuildFakeToyStatus {win} {
    global  config
    variable jwapp
	
    set im  [::Theme::FindIconSize 22 coccinella2]
    set ima [::Theme::FindIconSize 22 coccinella2-shadow]
    set y [expr {[image height $im]/2}]
    
    # Try to pick up some data from the real toy status.
    set imsec ""
    if {[llength $jwapp(securityWinL)]} {
	set imsec [[lindex $jwapp(securityWinL) 0] cget -image]
    }
    array set painfo [pack info $jwapp(wtoyb)]
    array unset painfo -in
    array set plinfo [place info $jwapp(wtoysec)]
    array unset plinfo -in
    
    ttk::frame $win
    
    ttk::button $win.b -style Plain \
      -image [list $im {active !pressed} $ima {active pressed} $im] \
      -command [namespace code ToyStatusCmd]
    ttk::button $win.secure -style Plainer \
      -compound image -padding {2} -image $imsec
    
    pack $win.b {*}[array get painfo]
    place $win.secure {*}[array get plinfo]
    
    if {$config(ui,main,toy-status-slots)} {
	set h [winfo reqheight $jwapp(wmp)]
	ttk::frame $win.pad -height $h
	pack $win.pad -side bottom -fill x
    } else {
	# @@@ TODO
    }    
    return $win
}

proc ::JUI::ToyStatusQuitHook {} {
    global  jprefs
    
    set jprefs(toystatus,mapped) [ToyStatusIsMapped]
}

#-------------------------------------------------------------------------------

namespace eval ::JUI {
    
    variable slot
    set slot(all) [list]
    set slot(allprio) [list]
    set slot(pending) 0
}

proc ::JUI::SlotInitPrefsHook {} {
    global  jprefs
    
    # We keep track of pref values of which slot is mapped here.
    # Then each slot just asks for it. This solution is simpler than if
    # each slot need its own prefs.
    # The initial state always show the Mege Presence slot. and the Search People slot
    set jprefs(slot,mapped) {megapresence search}
    
    ::PrefUtils::Add [list \
      [list jprefs(slot,mapped) jprefs_slot_mapped $jprefs(slot,mapped)]  \
      ]
}

# JUI::SlotRegister --
# 
#       A number of functions to allow components to abtain slots of space
#       in the main window.

proc ::JUI::SlotRegister {name cmd args} {
    variable slot
    
    array set argsA {
	-priority 50
    }
    array set argsA $args
    set prio $argsA(-priority)
    set slot($name,name) $name
    set slot($name,cmd)  $cmd
    set slot($name,prio) $prio
    
    # Sort them in priority order.
    set slot(all) [list]
    lappend slot(allprio) [list $name $prio]
    set slot(allprio) [lsort -integer -index 1 [lsort -unique $slot(allprio)]]
    foreach specL $slot(allprio) {
	lassign $specL name prio
	lappend slot(all) $name
    }    
    
    return $name
}

proc ::JUI::SlotBuild {w} {
    global jprefs
    variable slot
    
    ttk::frame $w -class RosterSlots
    set row 0
    
    # This is just a trick to fool the grid manager to let go also
    # the last remaining space, which is empty in this case.
    grid [ttk::frame $w.0]
    incr row
    
    foreach name $slot(all) {
	set slot($name,row) $row
	set slot($name,win) $w.$row

	uplevel #0 $slot($name,cmd) $w.$row
# 	if {$name in $jprefs(slot,mapped)} {
# 	    grid  $w.$row  -row $row -sticky ew
# 	}
	#grid  $w.$row  -row $row -sticky ew
	incr row
    }
    grid columnconfigure $w 0 -weight 1
    set slot(row) $row
    return $w
}

proc ::JUI::SlotDisplay {} {
    variable jwapp
    pack $jwapp(wmp) -side bottom -fill x
    ::balloonhelp::balloonforwindow $jwapp(wtoyb) [mc "Hide Control Panel"]
}

proc ::JUI::SlotHide {} {
    variable jwapp
    pack forget $jwapp(wmp)
    ::balloonhelp::balloonforwindow $jwapp(wtoyb) [mc "Show Control Panel"]
}

# JUI::SlotSlideUp, SlotSlide, .. ---
#
#       Makes the slot panel slide up and down, way cool!

proc ::JUI::SlotSlideUp {} {
    variable slot
    variable jwapp
    
    if {$slot(pending)} { return }
    set slot(pending) 1

    set wtoy $jwapp(wtoy)
    set h [winfo height $wtoy]
    pack forget $wtoy
    raise $wtoy
    place $wtoy -x 0 -y -$h -rely 1 -relwidth 1
    SlotDisplay
    ::UI::SlideUp $wtoy -y -$h -command [namespace code SlotSlideUpCmd]    
}

proc ::JUI::SlotSlideUpCmd {} {
    variable slot
    variable jwapp

    set slot(pending) 0
    set wtoy $jwapp(wtoy)
    place forget $wtoy
    pack $wtoy -side bottom -fill x
}

proc ::JUI::SlotSlideFakeUp {} {
    variable slot
    variable jwapp

    if {$slot(pending)} { return }
    set slot(pending) 1

    set win .jmain.f.fake
    set jwapp(wtoyfake) $win
    BuildFakeToyStatus $win
    set h [winfo height $jwapp(wtoy)]
    place $win -x 0 -y -$h -rely 1 -relwidth 1
    ::UI::SlideUp $win -y -$h -command [namespace code SlotSlideFakeUpCmd]
}

proc ::JUI::SlotSlideFakeUpCmd {} {
    variable slot
    variable jwapp

    set slot(pending) 0
    SlotDisplay
    update idletasks
    destroy $jwapp(wtoyfake)
}

proc ::JUI::SlotSlideDown {} {
    variable slot
    variable jwapp
    
    if {$slot(pending)} { return }

    set wtoy $jwapp(wtoy)
    set slot(pending) 1
    
    # Start height.
    set h [winfo height $wtoy]
    
    # Stop height.
    array set packA [pack info $jwapp(wtoyb)]
    set hstop [expr {[winfo height $jwapp(wtoyb)] + 2*$packA(-pady)}]
    
    pack forget $wtoy
    raise $wtoy
    place $wtoy -x 0 -y -$h -rely 1 -relwidth 1
    ::UI::SlideDown $wtoy -y $hstop -command [namespace code SlotSlideDownCmd]    
}

proc ::JUI::SlotSlideDownCmd {} {
    variable slot
    variable jwapp

    set slot(pending) 0
    set wtoy $jwapp(wtoy)
    SlotHide
    place forget $wtoy
    pack $wtoy -side bottom -fill x
}

proc ::JUI::SlotSlideFakeDown {} {
    variable slot
    variable jwapp

    if {$slot(pending)} { return }
 
    set win .jmain.f.fake
    set jwapp(wtoyfake) $win
    set slot(pending) 1

    # Stop height.
    array set packA [pack info $jwapp(wtoyb)]
    set hstop [expr {[winfo height $jwapp(wtoyb)] + 2*$packA(-pady)}]
    BuildFakeToyStatus $win
    
    # Start height
    set h [winfo height $jwapp(wtoy)]
    place $win -x 0 -y -$h -rely 1 -relwidth 1
    update idletasks
    SlotHide
    ::UI::SlideDown $win -y $hstop -command [namespace code SlotSlideFakeDownCmd]
}

proc ::JUI::SlotSlideFakeDownCmd {} {
    variable slot
    variable jwapp
    set slot(pending) 0
    destroy $jwapp(wtoyfake)
}

proc ::JUI::SlotPopup {W x y} {
    variable jwapp
        
    set m $jwapp(slotmenu)
    
    set X [expr [winfo rootx $W] + $x]
    set Y [expr [winfo rooty $W] + $y]
    tk_popup $m [expr {int($X) - 0}] [expr {int($Y) - 0}]   
    
    update idletasks
}

proc ::JUI::SlotGetMainMenu {} {
    set minfo [GetMainMenu].info
    return [::UI::MenuMethod $minfo entrycget mControlPanel -menu]
}

proc ::JUI::SlotGetAllMenus {} {
    variable jwapp
    
    set menuL [list]
    set minfo [GetMainMenu].info
    lappend menuL [::UI::MenuMethod $minfo entrycget mControlPanel -menu]
    lappend menuL $jwapp(slotmenu)
    return $menuL
}

proc ::JUI::SlotClose {name} {
    variable slot
    grid forget $slot($name,win)
}

proc ::JUI::SlotShow {name} {
    variable slot
    grid  $slot($name,win)  -row $slot($name,row) -sticky ew
}

proc ::JUI::SlotShowed {name} {
    variable slot
    if {[winfo manager $slot($name,win)] eq ""} {
	return 0
    } else {
	return 1
    }
}

proc ::JUI::SlotQuitHook {} {
    global  jprefs
    variable slot
    
    set names [list]
    foreach name $slot(all) {
	if {[SlotShowed $name]} {
	    lappend names $name
	}
    }
    set jprefs(slot,mapped) $names
}

proc ::JUI::SlotPrefsMapped {name} {
    global  jprefs
    
    if {$name in $jprefs(slot,mapped)} {
	return 1
    } else {
	return 0
    }
}

#-------------------------------------------------------------------------------

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

proc ::JUI::BuildToolbar {w wtbar} {
    
    # Shortcut button part.
    set iconConnect       [::Theme::Find32Icon $w connectImage]
    set iconConnectDis    [::Theme::Find32Icon $w connectDisImage]
    set iconInboxLett     [::Theme::Find32Icon $w inboxLetterImage]
    set iconInboxLettDis  [::Theme::Find32Icon $w inboxLetterDisImage]
    set iconInbox         [::Theme::Find32Icon $w inboxImage]
    set iconInboxDis      [::Theme::Find32Icon $w inboxDisImage]
    set iconAddUser       [::Theme::Find32Icon $w adduserImage]
    set iconAddUserDis    [::Theme::Find32Icon $w adduserDisImage]
    set iconStop          [::Theme::Find32Icon $w stopImage]
    set iconStopDis       [::Theme::Find32Icon $w stopDisImage]
    set iconChat          [::Theme::Find32Icon $w chatImage]
    set iconChatDis       [::Theme::Find32Icon $w chatDisImage]
    
    ::ttoolbar::ttoolbar $wtbar
    
    $wtbar newbutton connect -text [mc "Login"] \
      -image $iconConnect -disabledimage $iconConnectDis \
      -command ::Jabber::OnMenuLogInOut
    if {[::MailBox::HaveMailBox]} {
	$wtbar newbutton inbox -text [mc "Inbox"] \
	  -image $iconInboxLett -disabledimage $iconInboxLettDis  \
	  -command [list ::MailBox::ShowHide -visible 1]
    } else {
	$wtbar newbutton inbox -text [mc "Inbox"] \
	  -image $iconInbox -disabledimage $iconInboxDis  \
	  -command [list ::MailBox::ShowHide -visible 1]
    }
    $wtbar newbutton newuser -text [mc "Contact"] \
      -image $iconAddUser -disabledimage $iconAddUserDis  \
      -command ::JUser::NewDlg -state disabled \
      -balloontext [mc "Add Contact"]
    $wtbar newbutton chat -text [mc mChat] \
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

proc ::JUI::SetToolbarButtonState {name state} {
    variable jwapp
    
    $jwapp(wtbar) buttonconfigure $name -state $state      
}

proc ::JUI::RosterMoveFromPage {} {
    global jprefs
    variable jwapp
    
    set wnb     $jwapp(notebook)
    set wroster $jwapp(roster)

    pack forget $jwapp(tsep)
    pack forget $wroster
    pack forget $wnb
    pack $wroster -side top -fill both -expand 1
    
    set jprefs(ui,main,show,notebook) 0
}

proc ::JUI::RosterMoveToPage {} {
    global jprefs
    variable jwapp
    
    set wnb     $jwapp(notebook)
    set wroster $jwapp(roster)
        
    pack forget $wroster
    if {[winfo ismapped $jwapp(wtbar)]} {
	pack $jwapp(tsep)  -side top -fill x
    }
    pack $wnb     -fill both -expand 1 -side bottom
    pack $wroster -fill both -expand 1 -in $wnb.cont
    raise $wroster
    
    set jprefs(ui,main,show,notebook) 1
}

proc ::JUI::OnToolbarButton {} {
    OnMenuToggleToolbar
}

proc ::JUI::OnMenuToggleToolbar {} {
    variable jwapp
    variable state
    
    if {[llength [grab current]]} { return }
    if {[winfo ismapped $jwapp(wtbar)]} {
	HideToolbar
    } else {
	ShowToolbar
    }
    ::hooks::run uiMainToggleToolbar $state(show,toolbar)
}

proc ::JUI::HideToolbar {} {
    global jprefs
    variable jwapp
    
    pack forget $jwapp(wtbar)
    pack forget $jwapp(tsep)
    set jprefs(ui,main,show,toolbar) 0
}

proc ::JUI::ShowToolbar {} {
    global jprefs
    variable jwapp
    
    pack $jwapp(wtbar) -side top -fill x
    if {[winfo ismapped $jwapp(notebook)]} {
	pack $jwapp(tsep)  -side top -fill x
    }
    set jprefs(ui,main,show,toolbar) 1
}

proc ::JUI::OnMenuToggleNotebook {} {
    variable jwapp
    variable state
    
    if {[llength [grab current]]} { return }
    if {[winfo ismapped $jwapp(notebook)]} {
	RosterMoveFromPage
    } else {
	RosterMoveToPage
    }
    ::hooks::run uiMainToggleNotebook $state(show,notebook)
}

proc ::JUI::ShowNotebook {} {
    variable jwapp
    variable state
    
    if {![winfo ismapped $jwapp(notebook)]} {
	RosterMoveToPage
	set state(show,notebook) 1
	::hooks::run uiMainToggleNotebook $state(show,notebook)
    }
}

proc ::JUI::GetMainWindow {} {
    global wDlgs
    return $wDlgs(jmain)
}

proc ::JUI::GetMainMenu {} {
    variable jwapp
    return $jwapp(wmenu)
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

proc ::JUI::QuitHook {} {
    variable jwapp

    if {[info exists jwapp(jmain)]} {
	::UI::SaveWinGeom $jwapp(jmain)
    }
}

proc ::JUI::SetPresenceHook {type args} {
    
    # empty for the moment
}

proc ::JUI::RosterIconsChangedHook {} {
    variable jwapp
    upvar ::Jabber::jstate jstate
    
    if {[winfo exists $jwapp(mystatus)]} {
	set show $jstate(show)
	$jwapp(mystatus) configure -image [::Rosticons::ThemeGet user/$show]
    }
}

proc ::JUI::RosterSelectionHook {} {
    variable jwapp
    
    set wtbar $jwapp(wtbar)
    set state disabled
    set tags [::RosterTree::GetSelected]
    if {[llength $tags] == 1} {
	lassign [lindex $tags 0] mtag jid
	if {$mtag eq "jid"} {
	    if {[::Jabber::RosterCmd isavailable $jid]} {
		if {![::Roster::IsTransportEx $jid]} {	
		    set state normal
		}
	    }
	}
    }
    $wtbar buttonconfigure chat -state $state    
}

proc ::JUI::SetSecurityIcons {} {
    variable jwapp
    
    if {[llength $jwapp(securityWinL)]} {
	
	# security-high: SASL+TLS with a certificate signed by a trusted source
	# security-medium: {SASL+TLS|TLS on separate port} with a certificate
	# signed by a source that is not trusted (self-signed certificate)
	# security-low: only SASL or no security at all
	set any 0
	set sasl [::Jabber::Jlib connect feature sasl]
	set ssl  [::Jabber::Jlib connect feature ssl]
	set tls  [::Jabber::Jlib connect feature tls]
	set cert 0
	set w $jwapp(w)
	if {$sasl && $tls && $cert} {
	    set str [mc "The connection is secure"]
	    set image [::Theme::Find16Icon $w secureHighImage]
	    set any 1
	} elseif {($sasl && $tls) || $ssl} {
	    set str [mc "The connection is medium secure"]
	    set image [::Theme::Find16Icon $w secureMedImage]
	    set any 1
	} elseif {$sasl} {
	    set str [mc "The connection is insecure"]
	    set image [::Theme::Find16Icon $w secureLowImage]
	    set any 1
	}

	if {$any} {
	    foreach win $jwapp(securityWinL) {
		if {[winfo exists $win]} {
		    $win configure -image $image
		    ::balloonhelp::balloonforwindow $win $str	    
		}
	    }
	}
    }
}

proc ::JUI::UnsetSecurityIcons {} {
    variable jwapp
    
    foreach win $jwapp(securityWinL) {
	if {[winfo exists $win]} {
	    $win configure -image ""
	    ::balloonhelp::balloonforwindow $win ""
	}
    }
}

proc ::JUI::LoginHook {} {
    variable jwapp
    
    SetSecurityIcons

    # The Login/Logout button strings may have different widths.
    set w $jwapp(w)
    set minwidth [$jwapp(wtbar) minwidth]
    set minW [expr $minwidth > 200 ? $minwidth : 200]
    wm minsize $w $minW 300    
}

proc ::JUI::LogoutHook {} {
    
    UnsetSecurityIcons
    SetAppMessage [mc "Logged out"]
    FixUIWhen "disconnect"
    SetConnectState "disconnect"
}
    
proc ::JUI::GetRosterWmenu {} {
    variable jwapp
    return $jwapp(wmenu)
}

proc ::JUI::OpenCoccinellaURL {} {
    global  config
    ::Utils::OpenURLInBrowser $config(url,home)
}

proc ::JUI::OpenBugURL {} {
    global  config
    ::Utils::OpenURLInBrowser $config(url,bugs)
}

proc ::JUI::GetNotebook {} {
    variable jwapp
    return $jwapp(notebook)
}

proc ::JUI::GetRosterFrame {} {
    variable jwapp
    return $jwapp(roster)
}

# JUI::SetAppMessage --
#
#       This is a way for various parts of the code to put some arbitrary
#       text for UI display.

proc ::JUI::SetAppMessage {msg} {

    # @@@ We keep this for future use since we may want a method
    #     to display feedback details.
    ::hooks::run appStatusMessageHook $msg
}

# JUI::MailBoxState --
# 
#       Sets icon to display empty|nonempty inbox state.

proc ::JUI::MailBoxState {mailboxstate} {
    variable jwapp    
    
    set w $jwapp(jmain)
        
    switch -- $mailboxstate {
	empty {
	    set im  [::Theme::Find32Icon $w inboxImage]
	    set imd [::Theme::Find32Icon $w inboxDisImage]
	    $jwapp(wtbar) buttonconfigure inbox  \
	      -image $im -disabledimage $imd
	}
	nonempty {
	    set im  [::Theme::Find32Icon $w inboxLetterImage]
	    set imd [::Theme::Find32Icon $w inboxLetterDisImage]
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
    # @@@ On Mac submenus are not properly built.
    #     Need to open mailbox or click the desktop for them to build!
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
    
    ::UI::MenuMethod $wmenu entryconfigure mCloseWindow -state normal -label [mc "&Close Window"]
    if {[winfo exists [focus]]} {
	if {[winfo class [winfo toplevel [focus]]] eq "JMain"} {
	    ::UI::MenuMethod $wmenu entryconfigure mCloseWindow -state disabled -label [mc "&Close Window"]
	}
    }
    
    # Disable some menus by default and let any hooks enable them.
    set m [::UI::MenuMethod $wmenu entrycget mExport -menu]
    ::UI::MenuMethod $m entryconfigure mBC... -state disabled
    
    set mimport [::UI::MenuMethod $wmenu entrycget mImport -menu]
    ::UI::MenuMethod $mimport entryconfigure mBC... -state disabled
    
    if {([tk windowingsystem] eq "aqua") && [llength [grab current]]} { 
	::UI::MenuDisableAllBut $wmenu mCloseWindow
    } else {
	
	switch -- [GetConnectState] {
	    connectinit {
		::UI::MenuMethod $wmenu entryconfigure mNewAccount... -state disabled -label [mc "&New Account"]...
		::UI::MenuMethod $wmenu entryconfigure mSetupAssistant... -state disabled -label [mc "&Setup Assistant"]...
	    }
	    connectfin - connect {
		::UI::MenuMethod $wmenu entryconfigure mNewAccount... -state disabled -label [mc "&New Account"]...
		::UI::MenuMethod $wmenu entryconfigure mRemoveAccount... -state normal -label [mc "&Remove Account"]...
		::UI::MenuMethod $wmenu entryconfigure mNewPassword... -state normal -label [mc "New P&assword"]...
		::UI::MenuMethod $wmenu entryconfigure mSetupAssistant... -state disabled -label [mc "&Setup Assistant"]...
		::UI::MenuMethod $wmenu entryconfigure mEditProfiles... -state disabled -label [mc "&Edit Profiles"]...
		::UI::MenuMethod $wmenu entryconfigure mEditBC... -state normal -label [mc "Edit &Business Card"]...
		
		::UI::MenuMethod $mimport entryconfigure mBC... -state normal -label [mc "&Business Card"]...
	    }
	    disconnect {
		if {[llength [ui::findalltoplevelwithclass JLogin]]} {
		    ::UI::MenuMethod $wmenu entryconfigure mEditProfiles... -state disabled -label [mc "&Edit Profiles"]...
		    ::UI::MenuMethod $wmenu entryconfigure mNewAccount... -state disabled -label [mc "&New Account"]...
		} else {
		    ::UI::MenuMethod $wmenu entryconfigure mEditProfiles... -state normal -label [mc "&Edit Profiles"]...
		    ::UI::MenuMethod $wmenu entryconfigure mNewAccount... -state normal -label [mc "&New Account"]...
		}
		::UI::MenuMethod $wmenu entryconfigure mNewPassword... -state disabled -label [mc "New P&assword"]...
		::UI::MenuMethod $wmenu entryconfigure mSetupAssistant... -state normal -label [mc "&Setup Assistant"]...
		::UI::MenuMethod $wmenu entryconfigure mEditBC... -state disabled -label [mc "Edit &Business Card"]...
		::UI::MenuMethod $wmenu entryconfigure mRemoveAccount... -state disabled -label [mc "&Remove Account"]...
	    }	
	}   
    }
    
    ::hooks::run menuPostCommand main-file $wmenu
    
    # Dedicated hook for a particular dialog class.
    if {[winfo exists [focus]]} {
	set wclass [winfo class [winfo toplevel [focus]]]
	::hooks::run menu${wclass}FilePostHook $wmenu
    }
    
    # Workaround for mac bug.
    update idletasks
}

proc ::JUI::EditPostCommand {wmenu} {
    
    foreach {mkey mstate} [::UI::GenericCCPMenuStates] {
	::UI::MenuMethod $wmenu entryconfigure $mkey -state $mstate
    }	
    ::UI::MenuMethod $wmenu entryconfigure mAll -state disabled -label [mc "All"]
    ::UI::MenuMethod $wmenu entryconfigure mUndo -state disabled -label [mc "&Undo"]
    ::UI::MenuMethod $wmenu entryconfigure mRedo -state disabled -label [mc "Re&do"]

    set wfocus [focus]
    if {[winfo exists $wfocus]} {
	switch -- [winfo class $wfocus] {
	    Text {
		::UI::MenuMethod $wmenu entryconfigure mAll -state normal -label [mc "All"]
		if {[$wfocus edit modified]} {
		    ::UI::MenuMethod $wmenu entryconfigure mUndo -state normal -label [mc "&Undo"]
		}
		::UI::MenuMethod $wmenu entryconfigure mRedo -state normal -label [mc "Re&do"]
	    }
	    Entry - TEntry {
		::UI::MenuMethod $wmenu entryconfigure mAll -state normal -label [mc "All"]
	    }
	}
    }
    ::UI::MenuMethod $wmenu entryconfigure mFind -state disabled -label [mc "Find"]
    ::UI::MenuMethod $wmenu entryconfigure mFindNext -state disabled -label [mc "Find Next"]
    ::UI::MenuMethod $wmenu entryconfigure mFindPrevious -state disabled -label [mc "Find Previous"]
    
    ::hooks::run menuPostCommand main-edit $wmenu
    
    # Dedicated hook for a particular dialog class. Used by Find.
    if {[winfo exists [focus]]} {
	set wclass [winfo class [winfo toplevel [focus]]]
	::hooks::run menu${wclass}EditPostHook $wmenu
    }
    
    # Workaround for mac bug.
    update idletasks
}

proc ::JUI::ActionPostCommand {wmenu} {
    global wDlgs config
    variable state
    variable jwapp
    
    # The status menu.
    set m [::UI::MenuMethod $wmenu entrycget mStatus -menu]
    $m delete 0 end
    if {$config(ui,status,menu) eq "plain"} {
	::Status::BuildMainMenu $m
    } elseif {$config(ui,status,menu) eq "dynamic"} {
	::Status::ExBuildMainMenu $m
    }
    
    if {([tk windowingsystem] eq "aqua") && [llength [grab current]]} { 
	::UI::MenuDisableAll $wmenu
    } else {
	
	switch -- [GetConnectState] {
	    connectinit {
		::UI::MenuMethod $wmenu entryconfigure mLogin... -state normal \
		  -label [mc "Logout"]
	    }
	    connectfin - connect {
		::UI::MenuMethod $wmenu entryconfigure mRegister... -state normal -label [mc "Re&gister"]...
		::UI::MenuMethod $wmenu entryconfigure mLogin... -state normal \
		  -label [mc "Logout"]
		::UI::MenuMethod $wmenu entryconfigure mLogoutWith... -state normal -label [mc "Logout With Message"]...
		::UI::MenuMethod $wmenu entryconfigure mSearch... -state normal -label [mc "&Search"]...
		::UI::MenuMethod $wmenu entryconfigure mAddContact... -state normal -label [mc "&Add Contact"]...
		::UI::MenuMethod $wmenu entryconfigure mMessage... -state normal -label [mc "&Message"]...
		::UI::MenuMethod $wmenu entryconfigure mChat... -state normal -label [mc "Cha&t"]...
		::UI::MenuMethod $wmenu entryconfigure mStatus -state normal -label [mc "Status"]
		::UI::MenuMethod $wmenu entryconfigure mEnterRoom... -state normal -label [mc "Enter Chat&room"]...
		::UI::MenuMethod $wmenu entryconfigure mCreateRoom... -state normal -label [mc "&Create Chatroom"]...
		::UI::MenuMethod $wmenu entryconfigure mEditBookmarks... -state normal -label [mc "Edit &Bookmarks"]...
		::UI::MenuMethod $wmenu entryconfigure mDiscoverServer... -state normal -label [mc "&Discover Server"]...
	    }
	    disconnect {
		::UI::MenuMethod $wmenu entryconfigure mRegister... -state disabled -label [mc "Re&gister"]...
		if {[llength [ui::findalltoplevelwithclass JProfiles]]} {
		    ::UI::MenuMethod $wmenu entryconfigure mLogin... -state disabled  \
		      -label [mc "Login"]...
		} else {
		    ::UI::MenuMethod $wmenu entryconfigure mLogin... -state normal  \
		      -label [mc "Login"]...
		}
		::UI::MenuMethod $wmenu entryconfigure mLogoutWith... -state disabled -label [mc "Logout With Message"]...
		::UI::MenuMethod $wmenu entryconfigure mSearch... -state disabled -label [mc "&Search"]...
		::UI::MenuMethod $wmenu entryconfigure mAddContact... -state disabled -label [mc "&Add Contact"]...
		::UI::MenuMethod $wmenu entryconfigure mMessage... -state disabled -label [mc "&Message"]...
		::UI::MenuMethod $wmenu entryconfigure mChat... -state disabled -label [mc "Cha&t"]...
		::UI::MenuMethod $wmenu entryconfigure mStatus -state disabled -label [mc "Status"]
		::UI::MenuMethod $wmenu entryconfigure mEnterRoom... -state disabled -label [mc "Enter Chat&room"]...
		::UI::MenuMethod $wmenu entryconfigure mCreateRoom... -state disabled -label [mc "&Create Chatroom"]...
		::UI::MenuMethod $wmenu entryconfigure mEditBookmarks... -state disabled -label [mc "Edit &Bookmarks"]...
		::UI::MenuMethod $wmenu entryconfigure mDiscoverServer... -state disabled -label [mc "&Discover Server"]...
	    }	
	}    
    }
      
    ::hooks::run menuPostCommand main-action $wmenu
    
    # Dedicated hook for a particular dialog class.
    if {[winfo exists [focus]]} {
	set wclass [winfo class [winfo toplevel [focus]]]
	::hooks::run menu${wclass}ActionPostHook $wmenu
    }

    # Workaround for mac bug. Still problems building submenus.
    update idletasks
    if {[tk windowingsystem] eq "aqua"} {
	# Nothing helps!
	#$wmenu add command -label bug
	#$wmenu delete end

	#menu $wmenu.bug
	#$wmenu.bug add command -label bug
	#$wmenu add cascade -menu $wmenu.bug
	#update idletasks
	#destroy $wmenu.bug
	#$wmenu delete end
    }
    update idletasks
}

proc ::JUI::InfoPostCommand {wmenu} {
    global wDlgs config
    variable state
    variable jwapp
    
    # Set -variable value. BUG?
    if {[::MailBox::IsVisible]} {
	set state(mailbox,visible) 1
    } else {
	set state(mailbox,visible) 0
    }
    if {([tk windowingsystem] eq "aqua") && [llength [grab current]]} { 
	::UI::MenuDisableAll $wmenu
    } else {
	
	# For aqua we must do this only for .jmain
	set showState normal
	if {[tk windowingsystem] eq "aqua"} {
	    if {![::UI::IsToplevelActive $wDlgs(jmain)]} {
		set showState disabled
	    }	    
	}
	if {$showState eq "normal"} {
	    ::UI::MenuMethod $wmenu entryconfigure mShow -state normal -label [mc "Show"]
	    
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
	} else {
	    ::UI::MenuMethod $wmenu entryconfigure mShow -state disabled -label [mc "Show"]
	}
    }
    
    if {$config(ui,main,toy-status)} {
	if {[ToyStatusIsMapped]} {
	    ::UI::MenuMethod $wmenu entryconfigure mShowControlPanel \
	      -label [mc "Hide Control Panel"]
	} else {
	    ::UI::MenuMethod $wmenu entryconfigure mShowControlPanel \
	      -label [mc "Show Control Panel"]
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
    ::hooks::run connectState $state
    
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
        
    switch -exact -- $what {
	connectinit {
	    set stopImage [::Theme::Find32Icon $w stopImage]

	    $wtbar buttonconfigure connect -text [mc "Stop"] \
	      -image $stopImage -disabledimage $stopImage
    
	    ::hooks::run connectInitHook
	}
	connectfin - connect {
	    set connectedImage    [::Theme::Find32Icon $w connectedImage]
	    set connectedDisImage [::Theme::Find32Icon $w connectedDisImage]

	    $wtbar buttonconfigure connect -text [mc "Logout"] \
	      -image $connectedImage -disabledimage $connectedDisImage
	    $wtbar buttonconfigure newuser -state normal

	    ::hooks::run connectHook
	}
	disconnect {
	    set iconConnect     [::Theme::Find32Icon $w connectImage]
	    set iconConnectDis  [::Theme::Find32Icon $w connectDisImage]

	    $wtbar buttonconfigure connect -text [mc "Login"] \
	      -image $iconConnect -disabledimage $iconConnectDis
	    $wtbar buttonconfigure newuser -state disabled

	    ::hooks::run disconnectHook
	}
    }
}

proc ::JUI::InitPrefsHook {} {
    global  config jprefs

    set jprefs(ui,main,show,toolbar)  1
    set jprefs(ui,main,show,notebook) 1
    
    set plist [list]
    foreach key {toolbar notebook} {
 	set name jprefs(ui,main,show,$key)
	set rsrc jprefs_ui_main_show_$key
	set val  [set $name]
	lappend plist [list $name $rsrc $val]
    }
    set name jprefs(ui,main,InfoType)
    set rsrc jprefs_ui_main_infoType
    set val  $config(ui,main,infoType)
    lappend plist [list $name $rsrc $val]
    
    ::PrefUtils::Add $plist
}

# JUI::Find, FindAgain --
# 
#       Handle searches in a generic way by just dispatching to relevant target.

proc ::JUI::Find {} {
    variable jwapp
    
    # Dispatch to Roster or Disco or any other page displayed.
    # NB: tile 0.7.8+ has tagged notebook pages.
    if {[winfo ismapped $jwapp(notebook)]} {

	# We assume that the roster page has index 0.
	set current [$jwapp(notebook) index current]
	if {$current == 0} {
	    ::Roster::Find
	} else {
	    # TODO (Disco etc.)
	}
    } else {
	::Roster::Find	
    }
}

proc ::JUI::FindAgain {dir} {
    variable jwapp
    
    # Dispatch to Roster or Disco or any other page displayed.
    # NB: tile 0.7.8+ has tagged notebook pages.
    if {[winfo ismapped $jwapp(notebook)]} {

	# We assume that the roster page has index 0.
	set current [$jwapp(notebook) index current]
	if {$current == 0} {
	    ::Roster::FindAgain $dir
	} else {
	    # TODO (Disco etc.)
	}
    } else {
	::Roster::FindAgain $dir
    }
}

# Support functions for <<Copy>> events to translate emoticons to :-)
# See tk_textCopy

proc ::JUI::CopyEvent {w} {
    if {![catch {set data [$w get sel.first sel.last]}]} {
	clipboard clear -displayof $w
	clipboard append -displayof $w [::Text::TransformSelToPureText $w]
    }   
}

# Some DnD support for entry widgets as drop targets ---------------------------

proc ::JUI::DnDXmppBindTarget {win args} {
    
    if {([tk windowingsystem] ne "aqua") && ![catch {package require tkdnd}]} {
	set argsA(-command) ""
	array set argsA $args
	
	# We must try to handle UTF-8 as well as system encoded xmpp uris. (?)
	foreach type {{text/plain} {text/plain;charset=UTF-8}} {
	    
	    dnd bindtarget $win $type <DragEnter> {
		::JUI::DnDXmppDragEnter %W %D %T
	    }
	    dnd bindtarget $win $type <DragLeave> {
		::JUI::DnDXmppDragLeave %W
	    }
	    dnd bindtarget $win $type <Drop> \
	      [list ::JUI::DnDXmppDrop %W %D %T $argsA(-command)]
	}
    }
}

proc ::JUI::DnDXmppDragEnter {win data type} {
    
    Debug 4 "::JUI::DnDXmppDragEnter win=$win, data=$data, type=$type"
    
    if {[DnDXmppVerify $data $type]} {
	set wclass [winfo class $win]
	if {($wclass eq "TEntry") || ($wclass eq "TCombobox")} {
	    $win state {focus}
	} else {
	    focus $win
	}
	return "default"
    } else {
	return "none"
    }
}

proc ::JUI::DnDXmppDragLeave {win} {
    set wclass [winfo class $win]
    if {($wclass eq "TEntry") || ($wclass eq "TCombobox")} {
	$win state {!focus}
    } else {
	focus [winfo toplevel $win]
    }
}

proc ::JUI::DnDXmppDrop {win data type cmd} {
    
    Debug 4 "::JUI::DnDXmppDrop win=$win, data=$data, type=$type"
    
    if {[DnDXmppVerify $data $type]} {
	set data [DnDXmppExtractJID $data $type]
	if {$cmd eq ""} {
	    $win insert end $data
	} else {
	    uplevel #0 $cmd [list $win $data $type]
	}
    }
}

proc ::JUI::DnDXmppVerify {data type} {
    
    # We must try to handle UTF-8 as well as system encoded xmpp uris.
    if {$type eq "text/plain"} {
	set data [encoding convertfrom $data]
    }
    
    # Seems we accept anything here. Good or bad?
    set ans 1
    set parts [string map {"," ""} $data]
    foreach part $parts {
	if {[string match "xmpp:*" $part]} {
	    continue
	}
    }
    return $ans
}

proc ::JUI::DnDXmppExtractJID {data type} {

    if {$type eq "text/plain"} {
	set data [encoding convertfrom $data]
    }
    
    # @@@ There is currently a problem with unescaped sequences like:
    #     "d\27artagnan@jabber.se"
    #     Bug #153813, Unescaped sequences for xmpp drop targets

    # Strip off any "xmpp:".
    return [string map {"xmpp:" ""} $data]
}

#-------------------------------------------------------------------------------
