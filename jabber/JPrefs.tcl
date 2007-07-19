#  JPrefs.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements miscellaneous preference pages for jabber stuff.
#      
#  Copyright (c) 2001-2005  Mats Bengtsson
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
# $Id: JPrefs.tcl,v 1.49 2007-07-19 06:28:12 matben Exp $

package require ui::fontselector

package provide JPrefs 1.0

namespace eval ::JPrefs:: {
    
    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          ::JPrefs::InitPrefsHook
    ::hooks::register prefsBuildHook         ::JPrefs::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::JPrefs::SavePrefsHook
    ::hooks::register prefsCancelHook        ::JPrefs::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::JPrefs::UserDefaultsHook
    ::hooks::register quitAppHook            ::JPrefs::QuitAppHook
}


proc ::JPrefs::InitPrefsHook { } {
    global  prefs
    upvar ::Jabber::jprefs jprefs
    
    # Defaults...
    set prefs(opacity) 100.0
            
    # Save inbox when quit?
    set jprefs(inboxSave) 0
    
    set jprefs(autoLogin) 0
    
    # List of additional servers to automatically disco.
    set jprefs(disco,autoServers) {}
    
    # The rosters background image is partly controlled by option database.
    set jprefs(rost,useBgImage)     1
    set jprefs(rost,bgImagePath)    ""

    # Empty here means use option database.
    set jprefs(chatFont) ""
    set jprefs(chat,tabbedui) 1
    
    # Open dialogs must be saved specifically for each login jid as:
    # {mejid_1 {jid ?-option value ...?} mejid_2 {...} ...}
    set jprefs(chat,dialogs) {}
    
    set jprefs(rememberDialogs) 0


    # Personal info page:
    # List all iq:register personal info elements.
    set jprefs(iqRegisterElem)   \
      {first last nick email address city state phone url}
    
    # Personal info corresponding to the iq:register namespace.
    foreach key $jprefs(iqRegisterElem) {
	set jprefs(iq:register,$key) {}
    }

    # Personal info corresponding to the iq:register namespace.    
    set jprefsRegList {}
    foreach key $jprefs(iqRegisterElem) {
	lappend jprefsRegList [list  \
	  ::Jabber::jprefs(iq:register,$key) jprefs_iq_register_$key   \
	  $jprefs(iq:register,$key) userDefault]
    }
    ::PrefUtils::Add $jprefsRegList
    
    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(chatFont)         jprefs_chatFont          $jprefs(chatFont)]  \
      [list ::Jabber::jprefs(chat,tabbedui)    jprefs_chat_tabbedui     $jprefs(chat,tabbedui)]  \
      [list ::Jabber::jprefs(inboxSave)        jprefs_inboxSave         $jprefs(inboxSave)]  \
      [list ::Jabber::jprefs(rost,useBgImage)  jprefs_rost_useBgImage   $jprefs(rost,useBgImage)]  \
      [list ::Jabber::jprefs(rost,bgImagePath) jprefs_rost_bgImagePath  $jprefs(rost,bgImagePath)]  \
      [list ::Jabber::jprefs(autoLogin)        jprefs_autoLogin         $jprefs(autoLogin)]  \
      [list ::Jabber::jprefs(disco,autoServers)  jprefs_disco_autoServers  $jprefs(disco,autoServers)]  \
      [list ::Jabber::jprefs(rememberDialogs)  jprefs_rememberDialogs   $jprefs(rememberDialogs)]  \
      [list ::Jabber::jprefs(chat,dialogs)     jprefs_chat_dialogs      $jprefs(chat,dialogs)]  \
      ]
    
    if {[llength $jprefs(chatFont)]} {
	set jprefs(chatFont) [::Utils::GetFontListFromName $jprefs(chatFont)]
    }
    ::PrefUtils::Add [list  \
      [list prefs(opacity)         prefs_opacity          $prefs(opacity)]  \
      ]

    # Set default to empty to save it each time.
    set prefs(tileTheme) ""
    ::PrefUtils::AddMustSave [list  \
      [list prefs(tileTheme)       prefs_tileTheme        $prefs(tileTheme)]  \
      ]
}

proc ::JPrefs::BuildPrefsHook {wtree nbframe} {
        
    ::Preferences::NewTableItem {Jabber Appearance} [mc Appearance]
    ::Preferences::NewTableItem {Jabber Customization} [mc Customization]
     	    
    # Appearance page -------------------------------------------------------
    set wpage [$nbframe page {Appearance}]    
    ::JPrefs::BuildAppearancePage $wpage
	    
    # Customization page -------------------------------------------------------
    set wpage [$nbframe page {Customization}]    
    ::JPrefs::BuildCustomPage $wpage
    
    bind <Destroy> $nbframe +::JPrefs::DestroyPrefsHook
}

proc ::JPrefs::BuildAppearancePage {page} {
    global  this prefs wDlgs
    
    variable tmpJPrefs
    variable tmpPrefs
    upvar ::Jabber::jprefs jprefs
    
    foreach key {rost,useBgImage rost,bgImagePath chat,tabbedui chatFont} {
	set tmpJPrefs($key) $jprefs($key)
    }
    foreach key {opacity} {
	set tmpPrefs($key) $prefs($key)
    }
    
    # An empty themeName is the default value.
    set tmpPrefs(themeName) $prefs(themeName)
    if {$tmpPrefs(themeName) == ""} {
	set tmpPrefs(themeName) [mc None]
    }
    set allrsrc [concat [mc None] [::Theme::GetAllAvailable]]

    # Tile:
    # The descriptive names of the builtin themes:
    set tileThemeList {
	default  	"Default"
	classic  	"Classic"
	alt      	"Revitalized"
	clam            "Clam"
	winnative	"Windows native"
	xpnative	"XP Native"
	aqua    	"Aqua"
	tileqt          "Qt"
	step            "Step"
    }
    array set tileThemeArr $tileThemeList
    
    # Add in any available loadable themes:
    foreach name [tile::availableThemes] {
	if {![info exists tileThemeArr($name)]} {
	    lappend tileThemeList \
	      $name [set tileThemeArr($name) [string totitle $name]]
	}
    }
    foreach {theme name} $tileThemeList {
	if {![catch {package require tile::theme::$theme}]} {
	    lappend menuDef [list $name -value $theme]
	}
    }
    set tmpPrefs(tileTheme) $::tile::currentTheme

    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    set wap $wc.ap
    ttk::labelframe $wap -text [mc Appearance] \
      -padding [option get . groupSmallPadding {}]
     
    ttk::checkbutton $wap.tab -text [mc prefstabui]  \
      -variable [namespace current]::tmpJPrefs(chat,tabbedui)

    # Roster bg image.
    ttk::checkbutton $wap.bgim -text [mc prefrostbgim] \
      -variable [namespace current]::tmpJPrefs(rost,useBgImage)
    ttk::button $wap.bgpick -text "[mc {Pick}]..."  \
      -command [list [namespace current]::PickBgImage rost] -style Small.TButton
    ttk::button $wap.bgdefk -text [mc {Default}]  \
      -command [list [namespace current]::DefaultBgImage rost] -style Small.TButton
	    
    # Chat font.
    ttk::label  $wap.lfont -text [mc prefcufont]
    ttk::button $wap.btfont -text "[mc Pick]..." -style Small.TButton \
      -command [namespace current]::PickFont
    ttk::button $wap.dfont -text [mc {Default}]  \
      -command [namespace current]::DefaultChatFont  \
      -style Small.TButton

    set wthe $wap.the
    ttk::frame $wthe
    ttk::label $wthe.l -text "[mc preftheme]:"
    eval {ttk::optionmenu $wthe.p [namespace current]::tmpPrefs(themeName)} \
      $allrsrc
    
    grid  $wthe.l   $wthe.p

    # Tile's themes (skins).
    # This is applied immediately and unaffected by Cancel/Save actions.
    # The theme state is kept in two variables: 
    #   ::tile::currentTheme and prefs(tileTheme)
    set wskin $wap.skin
    set wmenu $wskin.b.m
    ttk::frame $wskin
    ttk::label $wskin.l -text "[mc {Pick skin}]:"
    
    ui::optionmenu $wskin.b -menulist $menuDef -variable ::tile::currentTheme \
      -command tile::setTheme
        
    # This has been disabled since it starts a child interpreter which needs
    # another ::tileqt::library.
    set tileqt 0
    #if {[lsearch [tile::availableThemes] tileqt] >= 0} {
    #    set tileqt 1
    #	ttk::button $wskin.qt -text "Qt Theme" -command ::JPrefs::BuildQtSetup
    #}
    
    grid  $wskin.l  $wskin.b
    #if {$tileqt} {
    #	grid  $wskin.qt  -column 2 -row 0 -padx 12
    #}
    
    # Window opacities if exists.
    array set wmopts [wm attributes .]
    set haveOpacity 0
    if {[info exists wmopts(-alpha)]} {
	set haveOpacity 1
	set wop $wap.op
	ttk::frame $wop
	ttk::label $wop.l -text "[mc {Set windows opacity}]:"
	ttk::scale $wop.s -orient horizontal -from 50 -to 100 \
	  -variable [namespace current]::tmpPrefs(opacity) \
	  -value $tmpPrefs(opacity)

	grid  $wop.l  $wop.s
    }
    
    grid  $wap.tab    -            -            -padx 2 -pady 2 -sticky w
    grid  $wap.bgim   $wap.bgpick  $wap.bgdefk  -padx 2 -pady 2 -sticky w
    grid  $wap.lfont  $wap.btfont  $wap.dfont   -padx 2 -pady 2 -sticky w
    grid  $wthe       -            -            -padx 2 -pady 2 -sticky w
    grid  $wskin      -            -            -padx 2 -pady 2 -sticky w
    if {$haveOpacity} {
	grid  $wop    -            -            -padx 2 -pady 2 -sticky w
    }
    grid  $wap.lfont  -sticky e
    grid  $wap.bgpick  $wap.bgdefk  $wap.btfont  $wap.dfont  -sticky ew
    
    pack  $wap  -side top -fill x
    
    bind $page <Destroy> +[namespace code OnDestroyAppearancePage]
}

proc ::JPrefs::OnDestroyAppearancePage {} {
    global  prefs
    variable tmpPrefs
    variable tmpJPrefs

    set prefs(tileTheme) $::tile::currentTheme
    
    unset -nocomplain tmpPrefs
    unset -nocomplain tmpJPrefs
}

proc ::JPrefs::BuildQtSetup {} {
    
    set w ._tileqt_su
    ::UI::Toplevel $w -title "Qt Theme"
    tile::theme::tileqt::createThemeConfigurationPanel $w
}

proc ::JPrefs::BuildCustomPage {page} {
    global  this prefs
    
    variable tmpJPrefs
    variable tmpPrefs
    upvar ::Jabber::jprefs jprefs
        
    foreach key {inboxSave rost,useBgImage rost,bgImagePath  \
      autoLogin notifier,state rememberDialogs} {
	if {[info exists jprefs($key)]} {
	    set tmpJPrefs($key) $jprefs($key)
	}
    }

    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    set wcu $wc.fr
    ttk::labelframe $wcu -text [mc Customization] \
      -padding [option get . groupSmallPadding {}]
         
    ttk::checkbutton $wcu.savein -text [mc prefcusave] \
      -variable [namespace current]::tmpJPrefs(inboxSave)
    ttk::checkbutton $wcu.log -text [mc prefcuautologin] \
      -variable [namespace current]::tmpJPrefs(autoLogin)
    ttk::checkbutton $wcu.rem -text [mc prefcuremdlgs] \
      -variable [namespace current]::tmpJPrefs(rememberDialogs)
    if {[string equal $this(platform) "windows"]} {
	ttk::checkbutton $wcu.not -text  "Show notfier window" \
	  -variable [namespace current]::tmpJPrefs(notifier,state)
    }
    
    grid  $wcu.savein  -sticky w
    grid  $wcu.log     -sticky w
    grid  $wcu.rem     -sticky w
    if {[string equal $this(platform) "windows"]} {
	grid  $wcu.not  -sticky w
    }
    
    pack  $wcu  -side top -fill x
}

proc ::JPrefs::PickFont { } {
    variable tmpJPrefs
    
    array set optsA {
	-defaultfont CociSmallFont
	-geovariable prefs(winGeom,jfontsel)
	-command     ::JPrefs::PickFontCommand
    }
    if {[string length $tmpJPrefs(chatFont)]} {
	set optsA(-selectfont) $tmpJPrefs(chatFont)
    } else {
	set optsA(-selectfont) CociSmallFont
    }
    set m [::UI::GetMainMenu]
    set optsA(-menu) $m
    set w [eval ui::fontselector [ui::autoname] [array get optsA]]
    ::UI::SetMenubarAcceleratorBinds $w $m
    $w grab
}

proc ::JPrefs::PickFontCommand {{theFont ""}} {
    variable tmpJPrefs
    
    if {[llength $theFont]} {
	if {[::Utils::FontEqual $theFont CociSmallFont]} {
	    set tmpJPrefs(chatFont) ""
	} else {
	    set tmpJPrefs(chatFont) $theFont
	}
    }
}

proc ::JPrefs::DefaultChatFont { } {
    variable tmpJPrefs

    set tmpJPrefs(chatFont) ""
}

proc ::JPrefs::PickBgImage {where} {
    variable tmpJPrefs

    set types [::Media::GetDlgFileTypesForMimeBase image]
    set ans [tk_getOpenFile -title [mc {Pick Image File}] -filetypes $types]
    if {$ans ne ""} {
	set tmpJPrefs($where,bgImagePath) $ans
    }
}

proc ::JPrefs::DefaultBgImage {where} {
    variable tmpJPrefs

    set tmpJPrefs($where,bgImagePath) ""
}

proc ::JPrefs::SetOpacity {opacity} {
    
    foreach w [winfo children .] {
	if {[winfo ismapped $w]} {
	    wm attributes $w -alpha [expr {$opacity/100.0}]
	}
    }
}

proc ::JPrefs::SavePrefsHook { } {
    global  prefs
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    variable tmpJPrefs
    variable tmpPrefs
    
    if {$tmpPrefs(themeName) == [mc None]} {
	set tmpPrefs(themeName) ""
    }
    foreach key {themeName} {
	if {$prefs($key) != $tmpPrefs($key)} {
	    ::Preferences::NeedRestart
	}
    }
    if {$prefs(opacity) != $tmpPrefs(opacity)} {
	SetOpacity $tmpPrefs(opacity)
    }

    # Roster background image: change only if needed.
    set newBackground 0
    if {($jprefs(rost,useBgImage) != $tmpJPrefs(rost,useBgImage)) || \
      ($jprefs(rost,bgImagePath) != $tmpJPrefs(rost,bgImagePath))} {
	set newBackground 1
    }
    
    array set jprefs [array get tmpJPrefs]
    array set prefs  [array get tmpPrefs]

    # Roster background image.
    if {$newBackground} {
	::RosterTree::SetBackgroundImage
    }
    ::Chat::SetFont $jprefs(chatFont)
}

proc ::JPrefs::CancelPrefsHook { } {
    global  prefs
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    variable tmpPrefs
	
    foreach key [array names tmpJPrefs] {
	if {![string equal $jprefs($key) $tmpJPrefs($key)]} {
	    ::Preferences::HasChanged
	    return
	}
    }
    if {$tmpPrefs(themeName) eq [mc None]} {
	set tmpPrefs(themeName) ""
    }
    
    # We don't store the tileTheme this way.
    unset -nocomplain tmpPrefs(tileTheme)
    
    foreach key [array names tmpPrefs] {
	if {![string equal $prefs($key) $tmpPrefs($key)]} {
	    ::Preferences::HasChanged
	    return
	}
    }
}

proc ::JPrefs::UserDefaultsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	set tmpJPrefs($key) $jprefs($key)
    }
}

proc ::JPrefs::DestroyPrefsHook { } {
    variable tmpPrefs
    variable tmpJPrefs
    
    unset -nocomplain tmpPrefs
    unset -nocomplain tmpJPrefs
}

proc ::JPrefs::QuitAppHook {} {
    global  prefs
    set prefs(tileTheme) $::tile::currentTheme
}

#-------------------------------------------------------------------------------
