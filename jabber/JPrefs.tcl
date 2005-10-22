#  JPrefs.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements miscellaneous preference pages for jabber stuff.
#      
#  Copyright (c) 2001-2005  Mats Bengtsson
#  
# $Id: JPrefs.tcl,v 1.31 2005-10-22 14:26:21 matben Exp $

package require ui::fontselector

package provide JPrefs 1.0

namespace eval ::JPrefs:: {
    
    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          ::JPrefs::InitPrefsHook
    ::hooks::register prefsBuildHook         ::JPrefs::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::JPrefs::SavePrefsHook
    ::hooks::register prefsCancelHook        ::JPrefs::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::JPrefs::UserDefaultsHook
    ::hooks::register prefsDestroyHook       ::JPrefs::DestroyPrefsHook
}


proc ::JPrefs::InitPrefsHook { } {
    global  prefs
    upvar ::Jabber::jprefs jprefs
    
    # Defaults...
    set prefs(opacity) 100
    
    # Auto away page:
    set jprefs(autoaway)     0
    set jprefs(xautoaway)    0
    set jprefs(awaymin)      0
    set jprefs(xawaymin)     0
    set jprefs(awaymsg)      ""
    set jprefs(xawaymsg)     [mc prefuserinactive]
    set jprefs(logoutStatus) ""
        
    # Save inbox when quit?
    set jprefs(inboxSave) 0
    
    # Service discovery method: "disco", "agents" or "browse"
    #set jprefs(serviceMethod) "browse"
    set jprefs(serviceMethod) "disco"
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

    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(autoaway)         jprefs_autoaway          $jprefs(autoaway)]  \
      [list ::Jabber::jprefs(xautoaway)        jprefs_xautoaway         $jprefs(xautoaway)]  \
      [list ::Jabber::jprefs(awaymin)          jprefs_awaymin           $jprefs(awaymin)]  \
      [list ::Jabber::jprefs(xawaymin)         jprefs_xawaymin          $jprefs(xawaymin)]  \
      [list ::Jabber::jprefs(awaymsg)          jprefs_awaymsg           $jprefs(awaymsg)]  \
      [list ::Jabber::jprefs(xawaymsg)         jprefs_xawaymsg          $jprefs(xawaymsg)]  \
      [list ::Jabber::jprefs(logoutStatus)     jprefs_logoutStatus      $jprefs(logoutStatus)]  \
      ]
    
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
    
    # We add 'serviceMethod' with a 'serviceMethod2' key so we ignore any 
    # existing installations. This is our new default. 
    # Change back in the future.

    ::PrefUtils::Add [list  \
      [list ::Jabber::jprefs(chatFont)         jprefs_chatFont          $jprefs(chatFont)]  \
      [list ::Jabber::jprefs(chat,tabbedui)    jprefs_chat_tabbedui     $jprefs(chat,tabbedui)]  \
      [list ::Jabber::jprefs(inboxSave)        jprefs_inboxSave         $jprefs(inboxSave)]  \
      [list ::Jabber::jprefs(rost,useBgImage)  jprefs_rost_useBgImage   $jprefs(rost,useBgImage)]  \
      [list ::Jabber::jprefs(rost,bgImagePath) jprefs_rost_bgImagePath  $jprefs(rost,bgImagePath)]  \
      [list ::Jabber::jprefs(serviceMethod)    jprefs_serviceMethod2    $jprefs(serviceMethod)]  \
      [list ::Jabber::jprefs(autoLogin)        jprefs_autoLogin         $jprefs(autoLogin)]  \
      [list ::Jabber::jprefs(disco,autoServers)  jprefs_disco_autoServers  $jprefs(disco,autoServers)]  \
      [list ::Jabber::jprefs(rememberDialogs)  jprefs_rememberDialogs   $jprefs(rememberDialogs)]  \
      [list ::Jabber::jprefs(chat,dialogs)     jprefs_chat_dialogs      $jprefs(chat,dialogs)]  \
      ]
    
    # Default status messages.
    foreach {status str} [::Jabber::Status::GetStatusTextArray] {
	set jprefs(statusMsg,bool,$status) 0
	set jprefs(statusMsg,msg,$status) ""

	::PrefUtils::Add [list  \
	  [list ::Jabber::jprefs(statusMsg,bool,$status)  \
	  jprefs_statusMsg_bool_$status                   \
	  $jprefs(statusMsg,bool,$status)]                \
	  [list ::Jabber::jprefs(statusMsg,msg,$status)   \
	  jprefs_statusMsg_msg_$status                    \
	  $jprefs(statusMsg,msg,$status)]                 \
	  ]
    }
    if {$jprefs(chatFont) != ""} {
	set jprefs(chatFont) [::Utils::GetFontListFromName $jprefs(chatFont)]
    }
    ::PrefUtils::Add [list  \
      [list prefs(opacity)         prefs_opacity          $prefs(opacity)]  \
      ]

}

proc ::JPrefs::BuildPrefsHook {wtree nbframe} {
    
    ::Preferences::NewTableItem {Jabber {Auto Away}} [mc {Auto Away}]
    ::Preferences::NewTableItem {Jabber Appearance} [mc Appearance]
    ::Preferences::NewTableItem {Jabber Customization} [mc Customization]

    # Auto Away page -------------------------------------------------------
    set wpage [$nbframe page {Auto Away}]
    ::JPrefs::BuildAutoAwayPage $wpage

    # Personal Info page ---------------------------------------------------
    #set wpage [$nbframe page {Personal Info}]    
    #::JPrefs::BuildPersInfoPage $wpage
	    
    # Appearance page -------------------------------------------------------
    set wpage [$nbframe page {Appearance}]    
    ::JPrefs::BuildAppearancePage $wpage
	    
    # Customization page -------------------------------------------------------
    set wpage [$nbframe page {Customization}]    
    ::JPrefs::BuildCustomPage $wpage
}

proc ::JPrefs::BuildAutoAwayPage {page} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    foreach key {autoaway awaymin xautoaway xawaymin awaymsg xawaymsg \
      logoutStatus} {
	set tmpJPrefs($key) $jprefs($key)
    }
    foreach {status str} [::Jabber::Status::GetStatusTextArray] {
	set tmpJPrefs(statusMsg,bool,$status) $jprefs(statusMsg,bool,$status)
	set tmpJPrefs(statusMsg,msg,$status)  $jprefs(statusMsg,msg,$status)
    }
    
    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    # Auto away stuff.
    set waa $wc.faa
    set waf $waa.fm
    set was $waa.fs
    ttk::labelframe $waa -text [mc {Auto Away}] \
      -padding [option get . groupSmallPadding {}]

    ttk::label $waa.lab -text [mc prefaaset]

    ttk::frame $waf
    ttk::checkbutton $waf.lminaw -text [mc prefminaw]  \
      -variable [namespace current]::tmpJPrefs(autoaway)
    ttk::entry $waf.eminaw -font CociSmallFont  \
      -width 3  \
      -validate key -validatecommand {::Utils::ValidMinutes %S} \
      -textvariable [namespace current]::tmpJPrefs(awaymin)
    ttk::checkbutton $waf.lminxa -text [mc prefminea]  \
      -variable [namespace current]::tmpJPrefs(xautoaway)
    ttk::entry $waf.eminxa -font CociSmallFont \
      -width 3  \
      -validate key -validatecommand {::Utils::ValidMinutes %S} \
      -textvariable [namespace current]::tmpJPrefs(xawaymin)

    grid  $waf.lminaw  $waf.eminaw  -sticky w -pady 1
    grid  $waf.lminxa  $waf.eminxa  -sticky w -pady 1

    ttk::frame $was
    ttk::label $was.lawmsg -text "[mc {Away status}]:"
    ttk::entry $was.eawmsg -font CociSmallFont \
      -width 32  \
      -textvariable [namespace current]::tmpJPrefs(awaymsg)
    ttk::label $was.lxa -text "[mc {Extended Away status}]:"
    ttk::entry $was.examsg -font CociSmallFont \
      -width 32  \
      -textvariable [namespace current]::tmpJPrefs(xawaymsg)
    
    grid  $was.lawmsg  $was.eawmsg  -sticky e -pady 1
    grid  $was.lxa     $was.examsg  -sticky e -pady 1

    pack  $waa.lab  $waf  $was  -side top -anchor w
    
    # Default logout status.
    array set statusTextArr [::Jabber::Status::GetStatusTextArray]
    set wlo $wc.lo
    ttk::labelframe $wlo -text [mc {Default status descriptions}] \
      -padding [option get . groupSmallPadding {}]
    
    foreach {status str} [array get statusTextArr] {
	ttk::checkbutton $wlo.c$status -text $str \
	  -variable [namespace current]::tmpJPrefs(statusMsg,bool,$status)
	ttk::entry $wlo.e$status -font CociSmallFont \
	  -textvariable [namespace current]::tmpJPrefs(statusMsg,msg,$status)
	  
	grid  $wlo.c$status  $wlo.e$status  -sticky w -pady 1
	grid  $wlo.e$status  -sticky ew
    }
    grid columnconfigure $wlo 1 -weight 1
    
    set anchor [option get . dialogAnchor {}]

    pack  $waa  -side top -fill x -anchor $anchor
    pack  $wlo  -side top -fill x -anchor $anchor -pady 12
}

proc ::JPrefs::BuildPersInfoPage {wpage} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    set ppers ${wpage}.fr
    labelframe $ppers -text [mc {Personal Information}]
    pack $ppers -side top -anchor w -padx 8 -pady 4

    ttk::label $ppers.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 300 -justify left -text [mc prefpers]
    grid $ppers.msg -columnspan 2 -sticky w
    
    label $ppers.first -text "[mc {First name}]:"
    label $ppers.last -text "[mc {Last name}]:"
    label $ppers.nick -text "[mc {Nick name}]:"
    label $ppers.email -text "[mc {Email address}]:"
    label $ppers.address -text "[mc {Address}]:"
    label $ppers.city -text "[mc {City}]:"
    label $ppers.state -text "[mc {State}]:"
    label $ppers.phone -text "[mc {Phone}]:"
    label $ppers.url -text "[mc {Url of homepage}]:"
    
    set row 1
    foreach name $jprefs(iqRegisterElem) {
	set tmpJPrefs(iq:register,$name) $jprefs(iq:register,$name)
	entry $ppers.ent$name -width 30    \
	  -textvariable "[namespace current]::tmpJPrefs(iq:register,$name)"
	grid $ppers.$name -column 0 -row $row -sticky e
	grid $ppers.ent$name -column 1 -row $row -sticky ew 
	incr row
    }    
}

# JPrefs::UpdateAutoAwaySettings --
#
#       If changed present auto away settings, may need to configure
#       our jabber object.

proc ::JPrefs::UpdateAutoAwaySettings { } { 
    global  prefs
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
        
    if {!$jstate(haveJabberUI)} {
	return
    }
   
    set opts {}
    if {$jprefs(autoaway) && [string is integer -strict $jprefs(awaymin)]} {
	lappend opts -autoawaymins $jprefs(awaymin)
    } else {
	lappend opts -autoawaymins 0
    }
    lappend opts -awaymsg $jprefs(awaymsg)
    if {$jprefs(xautoaway) && [string is integer -strict $jprefs(xawaymin)]} {
	lappend opts -xautoawaymins $jprefs(xawaymin)
    } else {
	lappend opts -xautoawaymins 0
    }
    lappend opts -xawaymsg $jprefs(xawaymsg)
    eval {$jstate(jlib) config} $opts
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
    }
    array set tileThemeArr $tileThemeList;

    # Add in any available loadable themes:
    foreach name [tile::availableThemes] {
	if {![info exists tileThemeArr($name)]} {
	    lappend tileThemeList \
	      $name [set tileThemeArr($name) [string totitle $name]]
	}
    }
    set tmpPrefs(tileTheme) ::tile::currentTheme

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
      -command [list set [namespace current]::tmpJprefs(chatFont) ""]  \
      -style Small.TButton

    set wthe $wap.the
    ttk::frame $wthe
    ttk::label $wthe.l -text "[mc preftheme]:"
    eval {ttk::optionmenu $wthe.p [namespace current]::tmpPrefs(themeName)} \
      $allrsrc
    
    # Tile's themes (skins).
    set wskin $wap.skin
    set wmenu $wskin.b.m
    ttk::frame $wskin
    ttk::label $wskin.l -text "[mc {Pick skin}]:"
    ttk::menubutton $wskin.b -textvariable ::tile::currentTheme \
      -menu $wmenu -direction flush
    menu $wmenu -tearoff 0
    
    foreach {theme name} $tileThemeList {
	$wmenu add radiobutton -label $name \
	  -variable ::tile::currentTheme -value $theme \
	  -command [list tile::setTheme $theme]
	if {[lsearch -exact [package names] tile::theme::$theme] == -1} {
	    $wmenu entryconfigure $name -state disabled
	}
    }
    
    grid  $wthe.l   $wthe.p
    grid  $wskin.l  $wskin.b
    
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
}

proc ::JPrefs::BuildCustomPage {page} {
    global  this prefs
    
    variable tmpJPrefs
    variable tmpPrefs
    upvar ::Jabber::jprefs jprefs
        
    foreach key {inboxSave rost,useBgImage rost,bgImagePath serviceMethod \
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
    ttk::separator $wcu.sep -orient horizontal    
    
    ttk::label $wcu.lserv -text [mc prefcudisc]
    ttk::radiobutton $wcu.disco  \
      -text [mc {Disco method}]  \
      -variable [namespace current]::tmpJPrefs(serviceMethod) -value "disco"
    ttk::radiobutton $wcu.browse   \
      -text [mc prefcubrowse]  \
      -variable [namespace current]::tmpJPrefs(serviceMethod) -value "browse"
    ttk::radiobutton $wcu.agents  \
      -text [mc prefcuagent] -value "agents" \
      -variable [namespace current]::tmpJPrefs(serviceMethod)
    
    grid  $wcu.savein  -sticky w
    grid  $wcu.log     -sticky w
    grid  $wcu.rem     -sticky w
    if {[string equal $this(platform) "windows"]} {
	grid  $wcu.not  -sticky w
    }
    grid  $wcu.sep    -sticky ew -pady 6
    grid  $wcu.lserv  -sticky w
    grid  $wcu.disco  -sticky w
    grid  $wcu.browse -sticky w
    grid  $wcu.agents -sticky w
    
    pack  $wcu  -side top -fill x
}

proc ::JPrefs::PickFont { } {
    variable tmpJPrefs
    
    set opts {
	-defaultfont CociSmallFont
	-geovariable prefs(winGeom,jfontsel)
	-command     ::JPrefs::PickFontCommand
    }
    if {[string length $tmpJPrefs(chatFont)]} {
	lappend opts -selectfont $tmpJPrefs(chatFont)
    } else {
	lappend opts -selectfont CociSmallFont
    }
    set m [::UI::GetMainMenu]
    lappend opts -menu $m
    set w [eval ui::fontselector [ui::autoname] $opts]
    ::UI::SetMenuAcceleratorBinds $w $m
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

proc ::JPrefs::PickBgImage {where} {
    variable tmpJPrefs

    set types {
	{{GIF Files}        {.gif}        }
	{{GIF Files}        {}        GIFF}
    }
    set ans [tk_getOpenFile -title [mc {Open GIF Image}] \
      -filetypes $types -defaultextension ".gif"]
    if {$ans != ""} {
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
    
    if {!$jstate(haveJabberUI)} {
	return
    }
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
    array set jprefs [array get tmpJPrefs]
    array set prefs  [array get tmpPrefs]
    
    # If changed present auto away settings, may need to reconfigure.
    ::JPrefs::UpdateAutoAwaySettings    

    # Roster background image.
    ::Roster::SetBackgroundImage $tmpJPrefs(rost,useBgImage) \
      $tmpJPrefs(rost,bgImagePath)
    
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
    
    # @@@ FIX!
    unset tmpPrefs(tileTheme)
    
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
    variable tmpJPrefs

    unset tmpJPrefs
}

#-------------------------------------------------------------------------------
