#  JUI.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements jabber GUI parts.
#      
#  Copyright (c) 2001-2007  Mats Bengtsson
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
# $Id: JUI.tcl,v 1.215 2007-10-07 10:32:42 matben Exp $

package provide JUI 1.0

namespace eval ::JUI:: {
    
    # Add all event hooks.
    ::hooks::register quitAppHook            ::JUI::QuitHook
    ::hooks::register loginHook              ::JUI::LoginHook
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
    option add *JMain.resizeHandleImage           resizehandle    widgetDefault

    option add *JMain.cociEs32                    coci-es-32      widgetDefault
    option add *JMain.cociEsActive32              coci-es-shadow-32 widgetDefault

    # Standard widgets.
    switch -- [tk windowingsystem] {
	aqua {
	    option add *JMain*TNotebook.padding   {8 8 8 4}       50
	    option add *JMain*bot.f.padding       {8 6 8 4}       50
	}
	x11 {
	    option add *JMain*TNotebook.padding   {2 4 2 2}       50
	    option add *JMain*bot.f.padding       {2 4 2 2}       50
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
	# Alternative.
	#option add *JMain*me.style              LSafari startupFile
    }
    
    # Configurations:
    set ::config(url,home) "http://thecoccinella.org"
    set ::config(url,bugs)  \
      "http://sourceforge.net/tracker/?group_id=68334&atid=520863"    
    #set ::config(url,bugs) "https://bugs.launchpad.net/coccinella"
        
    set ::config(ui,status,menu)        dynamic   ;# plain|dynamic
    set ::config(ui,main,infoLabel)     server    ;# mejid|mejidres|status|server
    set ::config(ui,main,slots)         0
    set ::config(ui,main,combi-status)  1
    set ::config(ui,main,toy-status)    0
    set ::config(ui,main,combibox)      0
    
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
}

proc ::JUI::Init {} {
    global  this
    
    # Menu definitions for the Roster/services window.
    variable menuDefs
    variable inited
            
    set mDefsFile {
	{command   mPreferences...     {::Preferences::Build}     {}}
	{separator}
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
	set closeM [list {command   mCloseWindow  {::UI::CloseWindowEvent}  W}]
	set menuDefs(rost,file) [concat $closeM $mDefsFile]
    } else {    
	set menuDefs(rost,file) $mDefsFile
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
	{command     mAddContact... {::JUser::OnMenu}                 {}}
	{cascade     mRegister...   {}                                {} {} {}}
	{command     mDiscoverServer... {::Disco::OnMenuAddServer}    {}}
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
	{command     mPlugins       {::Dialogs::InfoComponents}     {}}
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
	{cascade     mShow          {}                                {} {} {
	    {check   mToolbar       {::JUI::OnMenuToggleToolbar}      {} 
	    {-variable ::JUI::state(show,toolbar)}}
	    {check   mTabs          {::JUI::OnMenuToggleNotebook}     {} 
	    {-variable ::JUI::state(show,notebook)}}
	} }
	{separator}
	{command     mErrorLog      {::Jabber::ErrorLogDlg}         {}}
	{checkbutton mDebug         {::Jabber::DebugCmd}            {} \
	  {-variable ::Jabber::jstate(debugCmd)}}
	{command     mBugReport...  {::JUI::OpenBugURL}            {}}
	{separator}
	{command     mCoccinellaHome... {::JUI::OpenCoccinellaURL}     {}}
    }
    if {[tk windowingsystem] eq "aqua"} {
	set menuDefs(rost,info) $mDefsInfo
    } else {
	set mAbout {command  mAboutCoccinella  {::Splash::SplashScreen}  {}}
	set idx [lsearch $mDefsInfo *mCoccinellaHome...*]
	set menuDefs(rost,info) [linsert $mDefsInfo $idx $mAbout]
    }

    set menuDefs(rost,edit) {    
	{command   mCut              {::UI::CutEvent}           X}
	{command   mCopy             {::UI::CopyEvent}          C}
	{command   mPaste            {::UI::PasteEvent}         V}
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
    
    SlotRegister xmessage ::JUI::BuildMessageSlot

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
    global  this prefs config
    
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
    $wmenu.action configure  \
      -postcommand [list ::JUI::ActionPostCommand $wmenu.action]
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
    set iconResize     [::Theme::GetImage [option get $w resizeHandleImage {}]]
    set iconRoster     [::Theme::GetImage [option get $w roster16Image {}]]
    set iconRosterDis  [::Theme::GetImage [option get $w roster16DisImage {}]]
    
    set wtbar $wall.tbar
    BuildToolbar $w $wtbar
    pack $wtbar -side top -fill x

    # The top separator shall only be mapped between the toolbar and the notebook.
    ttk::separator $wall.sep -orient horizontal
    pack $wall.sep -side top -fill x
   
    # Experiment!
    if {$config(ui,main,slots)} {
	::JUI::SlotBuild $wall.slot
	pack $wall.slot -side bottom -fill x
    }

    # Status frame. 
    # Need two frames so we can pack resize icon in the corner.
    if {$config(ui,main,combi-status)} {
	set wbot $wall.bot
	ttk::frame $wbot
	pack $wbot -side bottom -fill x
	
	if {[tk windowingsystem] ne "aqua"} {
	    ttk::label $wbot.size -compound image -image $iconResize
	} else {
	    ttk::frame $wbot.size -width 8
	}
	pack  $wbot.size -side right -anchor s
	
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
	
	set infoLabel $config(ui,main,infoLabel)
	ttk::frame $wfstat.cont
	ttk::label $wfstat.me -textvariable ::Jabber::jstate($infoLabel) -anchor w
	pack  $wfstat.ava  -side right -padx 3 -pady 1
	pack  $wfstat.bst  $wfstat.cont  $wfstat.me  -side left
	pack  $wfstat.me  -padx 3 -pady 4 -fill x -expand 1

	set jwapp(mystatus)  $wfstat.bst
	set jwapp(myjid)     $wfstat.me
	set jwapp(statcont)  $wstatcont
    }
    
    # Experimental.
    if {$config(ui,main,combibox)} {
	BuildCombiBox $wall.comb
	pack $wall.comb -side top -fill x
    }
    
    # Experimental.
    if {$config(ui,main,toy-status)} {
	set im  [::Theme::GetImage [option get $w cociEs32 {}]]
	set ima [::Theme::GetImage [option get $w cociEsActive32 {}]]
	ttk::frame $wall.logo
	pack $wall.logo -side bottom -fill x
	ttk::button $wall.logo.b -style Plain \
	  -image [list $im {active !pressed} $ima {active pressed} $im] \
	  -command [namespace code CociCmd]
	pack $wall.logo.b -side top -fill x -padx 12 -pady 2
	
	set wmp $wall.logo.mp
	::MegaPresence::Build $wmp -collapse 0
	bind $wall.logo.b <<ButtonPopup>> [list ::MegaPresence::Popup %W $wmp %x %y]
	
	::balloonhelp::balloonforwindow $wall.logo.b "Open presence control panel"
	
	set jwapp(wtoy) $wall.logo.b
	set jwapp(wmp)  $wmp
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
    set jwapp(rostcont)  $wrostco
    set jwapp(wslot)     $wall.mp
    
    # Add an extra margin for Login/Logout string lengths.
    set trayMinW [expr {[$wtbar minwidth] + 12}]
    set minW [expr {$trayMinW > 200 ? $trayMinW : 200}]
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
    bind $wcombo <FocusOut>           ::JUI::CombiBoxOnFocusOut
    
    grid  $w.ava  $w.bst  $w.nick   -padx 4
    grid  ^       ^       $w.combo  -padx 4
    grid $w.nick -stick ew
    grid $w.combo -stick ew
    grid columnconfigure $w 2 -weight 1
    
    ::balloonhelp::balloonforwindow $w.nick "Displays your JID or nickname"
    
    set combiBox(w) $w
    set combiBox(wnick)  $w.nick
    set combiBox(wenick) $w.enick
    set combiBox(wcombo) $w.combo    
    
    return $w
}

proc ::JUI::CombiBoxLoginHook {} {
    upvar ::Jabber::jstate jstate
    variable combiBox
    
    if {![winfo exists $combiBox(w)]} {
	return
    }
    set myjid [$jstate(jlib) myjid]
    set ujid [jlib::unescapestr [jlib::barejid $myjid]]
    set wnick $combiBox(wnick)
    $wnick configure -text $ujid

    set server [::Jabber::JlibCmd getserver]
    ::Jabber::JlibCmd pep have $server [namespace code CombiBoxHavePEP]
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
	set myjid [$jstate(jlib) myjid]
	set ujid [jlib::unescapestr [jlib::barejid $myjid]]
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

proc ::JUI::CombiBoxOnFocusOut {} {
    upvar ::Jabber::jstate jstate
    variable combiBox

    # Reset to actual value.
    set combiBox(status) $jstate(status)
}

#-------------------------------------------------------------------------------

proc ::JUI::CociCmd {} {
    variable jwapp
    
    if {[winfo ismapped $jwapp(wmp)]} {
	pack forget $jwapp(wmp)
	::balloonhelp::balloonforwindow $jwapp(wtoy) "Open presence control panel"
    } else {
	pack $jwapp(wmp) -side bottom -fill x
	::balloonhelp::balloonforwindow $jwapp(wtoy) "Hide presence control panel"
    }
}

# @@@ EXPERIMENTAL!

# JUI::SlotRegister --
# 
#       A number of functions to allow components to abtain slots of space
#       in the main window.

proc ::JUI::SlotRegister {name cmd} {
    variable slot
    
    lappend slot(all) $name
    set slot($name,name) $name
    set slot($name,cmd)  $cmd
    return $name
}

proc ::JUI::SlotBuild {w} {
    variable slot
    
    ttk::frame $w -class RosterSlots
    #frame $w -class RosterSlots -bg red
    set row 0
    foreach name $slot(all) {
	uplevel #0 $slot($name,cmd) $w.$row
	grid  $w.$row  -row $row -sticky ew
	set slot($name,row) $row
	set slot($name,win) $w.$row
	set slot($name,display) 1
	incr row
    }
    grid columnconfigure $w 0 -weight 1
    return $w
}

proc ::JUI::SlotClose {name} {
    variable slot

    grid forget $slot($name,win)
}

# A kind of status slot. FIX NAME!

namespace eval ::JUI {
    
    option add *MessageSlot.padding       {4 2 2 2}     50
    option add *MessageSlot.box.padding   {8 2 8 2}     50
    option add *MessageSlot*TEntry.font   CociSmallFont widgetDefault
}

proc ::JUI::BuildMessageSlot {w} {
    variable widgets
    
    ttk::frame $w -class MessageSlot
    
    if {1} {
	set widgets(collapse) 0
	ttk::checkbutton $w.arrow -style Arrow.TCheckbutton \
	  -command [list [namespace current]::MessageSlotCollapse $w] \
	  -variable [namespace current]::widgets(collapse)
	pack $w.arrow -side left -anchor n	
	bind $w.arrow <<ButtonPopup>> [list [namespace current]::MessageSlotPopup $w %x %y]

	set subPath [file join images 16]
	set im  [::Theme::GetImage closeAqua $subPath]
	set ima [::Theme::GetImage closeAquaActive $subPath]
	ttk::button $w.close -style Plain  \
	  -image [list $im active $ima] -compound image  \
	  -command [namespace code [list MessageSlotClose $w]]
	pack $w.close -side right -anchor n	
    }    
    set widgets(value) mejid
    set box $w.box
    set widgets(box) $w.box
    ttk::frame $box
    pack $box -fill x -expand 1
    
    ttk::label $box.e -style Small.Sunken.TLabel \
      -textvariable ::Jabber::jstate(mejid) -anchor w
    
    grid  $box.e  -sticky ew
    grid columnconfigure $box 0 -weight 1
    
    return $w
}

proc ::JUI::MessageSlotCollapse {w} {
    variable widgets

    if {$widgets(collapse)} {
	pack forget $widgets(box)
    } else {
	pack $widgets(box) -fill both -expand 1
    }
    event generate $w <<Xxx>>
}

proc ::JUI::MessageSlotPopup {w x y} {
    
    set m $w.m
    destroy $m
    menu $m -tearoff 0
    
    foreach value {mejid mejidres server status} \
      label [list [mc "Own JID"] [mc "Own full JID"] [mc Server] [mc Status]] {
	$m add radiobutton -label $label \
	  -variable [namespace current]::widgets(value) -value $value \
	  -command [namespace code [list MessageSlotMenuCmd $w $value]]
    }    
    update idletasks
    
    set X [expr [winfo rootx $w] + $x]
    set Y [expr [winfo rooty $w] + $y]
    tk_popup $m [expr {int($X) - 0}] [expr {int($Y) - 0}]   
    
    return -code break
}

proc ::JUI::MessageSlotMenuCmd {w value} {
    variable widgets

    $widgets(box).e configure -textvariable ::Jabber::jstate($value)
}

proc ::JUI::MessageSlotClose {w} {
    SlotClose xmessage
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

proc ::JUI::NotebookGetPage {} {
    variable jwapp
   
    if {[winfo ismapped $jwapp(notebook)]} {
	set current [$jwapp(notebook) index current]

    } else {
	return "roster"
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
    
    $wtbar newbutton connect -text [mc Login] \
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
      -command ::JUser::NewDlg -state disabled \
      -balloontext [mc {Add Contact}]
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
    variable jwapp
    upvar ::Jabber::jprefs jprefs
    
    set wnb     $jwapp(notebook)
    set wroster $jwapp(roster)

    pack forget $jwapp(tsep)
    pack forget $wroster
    pack forget $wnb
    pack $wroster -side bottom -fill both -expand 1
    
    set jprefs(ui,main,show,notebook) 0
}

proc ::JUI::RosterMoveToPage {} {
    variable jwapp
    upvar ::Jabber::jprefs jprefs
    
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
    variable jwapp
    upvar ::Jabber::jprefs jprefs
    
    pack forget $jwapp(wtbar)
    pack forget $jwapp(tsep)
    set jprefs(ui,main,show,toolbar) 0
}

proc ::JUI::ShowToolbar {} {
    variable jwapp
    upvar ::Jabber::jprefs jprefs
    
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
	set status $jstate(show)
	$jwapp(mystatus) configure -image [::Rosticons::Get status/$status]
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
		set state normal
	    }
	}
    }
    $wtbar buttonconfigure chat -state $state    
}

proc ::JUI::LoginHook {} {
    variable jwapp
    
    # The Login/Logout button strings may have different widths.
    set w $jwapp(w)
    set minwidth [$jwapp(wtbar) minwidth]
    set minW [expr $minwidth > 200 ? $minwidth : 200]
    wm minsize $w $minW 300    
}

proc ::JUI::LogoutHook {} {
    
    SetStatusMessage [mc {Logged out}]
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

proc ::JUI::SetStatusMessage {msg} {

    # @@@ We keep this for future use since we may want a method
    #     to display feedback details.
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
    
    ::UI::MenuMethod $wmenu entryconfigure mCloseWindow -state normal
    if {[winfo exists [focus]]} {
	if {[winfo class [winfo toplevel [focus]]] eq "JMain"} {
	    ::UI::MenuMethod $wmenu entryconfigure mCloseWindow -state disabled
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
		::UI::MenuMethod $wmenu entryconfigure mNewAccount... -state disabled
		::UI::MenuMethod $wmenu entryconfigure mSetupAssistant... -state disabled
	    }
	    connectfin - connect {
		::UI::MenuMethod $wmenu entryconfigure mNewAccount... -state disabled
		::UI::MenuMethod $wmenu entryconfigure mRemoveAccount... -state normal
		::UI::MenuMethod $wmenu entryconfigure mNewPassword... -state normal
		::UI::MenuMethod $wmenu entryconfigure mSetupAssistant... -state disabled
		::UI::MenuMethod $wmenu entryconfigure mEditProfiles... -state disabled
		::UI::MenuMethod $wmenu entryconfigure mEditBC... -state normal
		
		::UI::MenuMethod $mimport entryconfigure mBC... -state normal
	    }
	    disconnect {
		if {[llength [ui::findalltoplevelwithclass JLogin]]} {
		    ::UI::MenuMethod $wmenu entryconfigure mEditProfiles... -state disabled
		    ::UI::MenuMethod $wmenu entryconfigure mNewAccount... -state disabled
		} else {
		    ::UI::MenuMethod $wmenu entryconfigure mEditProfiles... -state normal
		    ::UI::MenuMethod $wmenu entryconfigure mNewAccount... -state normal
		}
		::UI::MenuMethod $wmenu entryconfigure mNewPassword... -state disabled
		::UI::MenuMethod $wmenu entryconfigure mSetupAssistant... -state normal
		::UI::MenuMethod $wmenu entryconfigure mEditBC... -state disabled
		::UI::MenuMethod $wmenu entryconfigure mRemoveAccount... -state disabled
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
    ::UI::MenuMethod $wmenu entryconfigure mFind -state disabled
    ::UI::MenuMethod $wmenu entryconfigure mFindNext -state disabled
    ::UI::MenuMethod $wmenu entryconfigure mFindPrevious -state disabled
    
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
		  -label mLogout
	    }
	    connectfin - connect {
		::UI::MenuMethod $wmenu entryconfigure mRegister... -state normal
		::UI::MenuMethod $wmenu entryconfigure mLogin... -state normal \
		  -label mLogout
		::UI::MenuMethod $wmenu entryconfigure mLogoutWith... -state normal
		::UI::MenuMethod $wmenu entryconfigure mSearch... -state normal
		::UI::MenuMethod $wmenu entryconfigure mAddContact... -state normal
		::UI::MenuMethod $wmenu entryconfigure mMessage... -state normal
		::UI::MenuMethod $wmenu entryconfigure mChat... -state normal
		::UI::MenuMethod $wmenu entryconfigure mStatus -state normal
		::UI::MenuMethod $wmenu entryconfigure mEnterRoom... -state normal
		::UI::MenuMethod $wmenu entryconfigure mCreateRoom... -state normal
		::UI::MenuMethod $wmenu entryconfigure mEditBookmarks... -state normal
		::UI::MenuMethod $wmenu entryconfigure mDiscoverServer... -state normal
	    }
	    disconnect {
		::UI::MenuMethod $wmenu entryconfigure mRegister... -state disabled
		if {[llength [ui::findalltoplevelwithclass JProfiles]]} {
		    ::UI::MenuMethod $wmenu entryconfigure mLogin... -state disabled  \
		      -label mLogin...
		} else {
		    ::UI::MenuMethod $wmenu entryconfigure mLogin... -state normal  \
		      -label mLogin...
		}
		::UI::MenuMethod $wmenu entryconfigure mLogoutWith... -state disabled
		::UI::MenuMethod $wmenu entryconfigure mSearch... -state disabled
		::UI::MenuMethod $wmenu entryconfigure mAddContact... -state disabled
		::UI::MenuMethod $wmenu entryconfigure mMessage... -state disabled
		::UI::MenuMethod $wmenu entryconfigure mChat... -state disabled
		::UI::MenuMethod $wmenu entryconfigure mStatus -state disabled
		::UI::MenuMethod $wmenu entryconfigure mEnterRoom... -state disabled
		::UI::MenuMethod $wmenu entryconfigure mCreateRoom... -state disabled
		::UI::MenuMethod $wmenu entryconfigure mEditBookmarks... -state disabled
		::UI::MenuMethod $wmenu entryconfigure mDiscoverServer... -state disabled
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
	} else {
	    ::UI::MenuMethod $wmenu entryconfigure mShow -state disabled
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
	    set stopImage [::Theme::GetImage [option get $w stopImage {}]]

	    $wtbar buttonconfigure connect -text [mc Stop] \
	      -image $stopImage -disabledimage $stopImage
	}
	connectfin - connect {
	    set connectedImage    [::Theme::GetImage [option get $w connectedImage {}]]
	    set connectedDisImage [::Theme::GetImage [option get $w connectedDisImage {}]]

	    $wtbar buttonconfigure connect -text [mc Logout] \
	      -image $connectedImage -disabledimage $connectedDisImage
	    $wtbar buttonconfigure newuser -state normal
	}
	disconnect {
	    set iconConnect     [::Theme::GetImage [option get $w connectImage {}]]
	    set iconConnectDis  [::Theme::GetImage [option get $w connectDisImage {}]]

	    $wtbar buttonconfigure connect -text [mc Login] \
	      -image $iconConnect -disabledimage $iconConnectDis
	    $wtbar buttonconfigure newuser -state disabled
	}
    }
}

proc ::JUI::InitPrefsHook {} {
    upvar ::Jabber::jprefs jprefs

    set jprefs(ui,main,show,toolbar)  1
    set jprefs(ui,main,show,notebook) 1
    
    set plist [list]
    foreach key {toolbar notebook} {
	set name ::Jabber::jprefs(ui,main,show,$key)
	set rsrc jprefs_ui_main_show_$key
	set val  [set $name]
	lappend plist [list $name $rsrc $val]
    }
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

#-------------------------------------------------------------------------------
