#  JPrefs.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements miscellaneous preference pages for jabber stuff.
#      
#  Copyright (c) 2001-2004  Mats Bengtsson
#  
# $Id: JPrefs.tcl,v 1.4 2004-05-06 13:41:10 matben Exp $

package provide JPrefs 1.0

namespace eval ::Jabber::JPrefs:: {
    
    # Define all hooks for preference settings.
    ::hooks::add prefsInitHook          ::Jabber::JPrefs::InitPrefsHook
    ::hooks::add prefsBuildHook         ::Jabber::JPrefs::BuildPrefsHook
    ::hooks::add prefsSaveHook          ::Jabber::JPrefs::SavePrefsHook
    ::hooks::add prefsCancelHook        ::Jabber::JPrefs::CancelPrefsHook
    ::hooks::add prefsUserDefaultsHook  ::Jabber::JPrefs::UserDefaultsHook
}


proc ::Jabber::JPrefs::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    
    # Defaults...
    # Auto away page:
    set jprefs(autoaway)     0
    set jprefs(xautoaway)    0
    set jprefs(awaymin)      0
    set jprefs(xawaymin)     0
    set jprefs(awaymsg)      ""
    set jprefs(xawaymsg)     "User has been inactive for a while"
    set jprefs(logoutStatus) ""
        
    set jprefs(showMsgNewWin) 1
    
    # Save inbox when quit?
    set jprefs(inboxSave) 0
    set jprefs(inbox2click) "newwin"
    
    # Service discovery method: "disco", "agents" or "browse"
    set jprefs(serviceMethod) "browse"
    
    # The rosters background image is partly controlled by option database.
    set jprefs(rost,useBgImage)     1
    set jprefs(rost,bgImagePath)    ""

    ::PreferencesUtils::Add [list  \
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
    ::PreferencesUtils::Add $jprefsRegList

    ::PreferencesUtils::Add [list  \
      [list ::Jabber::jprefs(showMsgNewWin)    jprefs_showMsgNewWin     $jprefs(showMsgNewWin)]  \
      [list ::Jabber::jprefs(inboxSave)        jprefs_inboxSave         $jprefs(inboxSave)]  \
      [list ::Jabber::jprefs(inbox2click)      jprefs_inbox2click       $jprefs(inbox2click)]  \
      [list ::Jabber::jprefs(rost,useBgImage)  jprefs_rost_useBgImage   $jprefs(rost,useBgImage)]  \
      [list ::Jabber::jprefs(rost,bgImagePath) jprefs_rost_bgImagePath  $jprefs(rost,bgImagePath)]  \
      [list ::Jabber::jprefs(serviceMethod)   jprefs_serviceMethod    $jprefs(serviceMethod)]  \
      ]
}

proc ::Jabber::JPrefs::BuildPrefsHook {wtree nbframe} {
    
    $wtree newitem {Jabber {Auto Away}} -text [::msgcat::mc {Auto Away}]
    $wtree newitem {Jabber {Personal Info}} -text [::msgcat::mc {Personal Info}]
    $wtree newitem {Jabber Customization} -text [::msgcat::mc Customization]

    # Auto Away page -------------------------------------------------------
    set wpage [$nbframe page {Auto Away}]
    ::Jabber::JPrefs::BuildAutoAwayPage $wpage

    # Personal Info page ---------------------------------------------------
    set wpage [$nbframe page {Personal Info}]    
    ::Jabber::JPrefs::BuildPersInfoPage $wpage
	    
    # Customization page -------------------------------------------------------
    set wpage [$nbframe page {Customization}]    
    ::Jabber::JPrefs::BuildCustomPage $wpage
}

proc ::Jabber::JPrefs::BuildAutoAwayPage {page} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs

    set xpadbt [option get [winfo toplevel $page] xPadBt {}]
    
    foreach key {autoaway awaymin xautoaway xawaymin awaymsg xawaymsg \
      logoutStatus} {
	set tmpJPrefs($key) $jprefs($key)
    }
    
    # Auto away stuff.
    set labfrpbl $page.fr
    labelframe $labfrpbl -text [::msgcat::mc {Auto Away}]
    pack $labfrpbl -side top -anchor w -padx 8 -pady 4
    set pbl [frame $labfrpbl.frin]
    pack $pbl -padx 10 -pady 6 -side left
    pack [label $pbl.lab -text [::msgcat::mc prefaaset]] \
      -side top -anchor w
    
    pack [frame $pbl.frma] -side top -anchor w
    checkbutton $pbl.frma.lminaw -anchor w \
      -text "  [::msgcat::mc prefminaw]"  \
      -variable [namespace current]::tmpJPrefs(autoaway)
    entry $pbl.frma.eminaw -width 3  \
      -validate key -validatecommand {::Utils::ValidMinutes %S} \
      -textvariable [namespace current]::tmpJPrefs(awaymin)
    checkbutton $pbl.frma.lminxa -anchor w \
      -text "  [::msgcat::mc prefminea]"  \
      -variable [namespace current]::tmpJPrefs(xautoaway)
    entry $pbl.frma.eminxa -width 3  \
      -validate key -validatecommand {::Utils::ValidMinutes %S} \
      -textvariable [namespace current]::tmpJPrefs(xawaymin)
    grid $pbl.frma.lminaw -column 0 -row 0 -sticky w
    grid $pbl.frma.eminaw -column 1 -row 0 -sticky w
    grid $pbl.frma.lminxa -column 0 -row 1 -sticky w
    grid $pbl.frma.eminxa -column 1 -row 1 -sticky w

    pack [frame $pbl.frmsg] -side top -fill x -anchor w
    label $pbl.frmsg.lawmsg -text "[::msgcat::mc {Away status}]:"
    entry $pbl.frmsg.eawmsg -width 32  \
      -textvariable [namespace current]::tmpJPrefs(awaymsg)
    label $pbl.frmsg.lxa -text "[::msgcat::mc {Extended Away status}]:"
    entry $pbl.frmsg.examsg -width 32  \
      -textvariable [namespace current]::tmpJPrefs(xawaymsg)
    
    grid $pbl.frmsg.lawmsg -column 0 -row 0 -sticky e
    grid $pbl.frmsg.eawmsg -column 1 -row 0 -sticky w
    grid $pbl.frmsg.lxa    -column 0 -row 1 -sticky e
    grid $pbl.frmsg.examsg -column 1 -row 1 -sticky w
    
    # Default logout status.
    set labfrstat $page.frstat
    labelframe $labfrstat -text [::msgcat::mc {Default Logout Status}]
    pack $labfrstat -side top -anchor w -padx 8 -pady 4
    set pstat [frame $labfrstat.frin]
    pack $pstat -padx 10 -pady 6 -side left

    label $pstat.l -text "[::msgcat::mc {Status when logging out}]:"
    entry $pstat.e -width 32  \
      -textvariable [namespace current]::tmpJPrefs(logoutStatus)
    grid $pstat.l -column 0 -row 0 -sticky e
    grid $pstat.e -column 1 -row 0 -sticky w
}

proc ::Jabber::JPrefs::BuildPersInfoPage {wpage} {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    set ppers ${wpage}.fr
    labelframe $ppers -text [::msgcat::mc {Personal Information}]
    pack $ppers -side top -anchor w -padx 8 -pady 4

    message $ppers.msg -text [::msgcat::mc prefpers] -aspect 800
    grid $ppers.msg -columnspan 2 -sticky w
    
    label $ppers.first -text "[::msgcat::mc {First name}]:"
    label $ppers.last -text "[::msgcat::mc {Last name}]:"
    label $ppers.nick -text "[::msgcat::mc {Nick name}]:"
    label $ppers.email -text "[::msgcat::mc {Email address}]:"
    label $ppers.address -text "[::msgcat::mc {Address}]:"
    label $ppers.city -text "[::msgcat::mc {City}]:"
    label $ppers.state -text "[::msgcat::mc {State}]:"
    label $ppers.phone -text "[::msgcat::mc {Phone}]:"
    label $ppers.url -text "[::msgcat::mc {Url of homepage}]:"
    
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

# Jabber::JPrefs::UpdateAutoAwaySettings --
#
#       If changed present auto away settings, may need to configure
#       our jabber object.

proc ::Jabber::JPrefs::UpdateAutoAwaySettings { } { 
    global  prefs
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    
    if {!$jstate(haveJabberUI)} {
	return
    }
    
    array set oldopts [$jstate(jlib) config]
    set reconfig 0
    foreach name {autoaway xautoaway awaymin xawaymin} {
	if {$oldopts(-$name) != $jprefs($name)} {
	    set reconfig 1
	    break
	}
    }
    if {$reconfig} {
	set opts {}
	if {$jprefs(autoaway) || $jprefs(xautoaway)} {
	    foreach name {autoaway xautoaway awaymin xawaymin awaymsg xawaymsg} {
		lappend opts -$name $jprefs($name)
	    }
	}
	eval {$jstate(jlib) config} $opts
    }
}

proc ::Jabber::JPrefs::BuildCustomPage {page} {
    global  this prefs
    
    variable wlbblock
    variable btrem
    variable wlbblock
    variable tmpJPrefs
    variable tmpPrefs
    upvar ::Jabber::jprefs jprefs
    
    set fontS  [option get . fontSmall {}]    
    set fontSB [option get . fontSmallBold {}]
    set xpadbt [option get [winfo toplevel $page] xPadBt {}]
    set ypad   [option get [winfo toplevel $page] yPad {}]

    foreach key {showMsgNewWin inboxSave inbox2click \
      rost,useBgImage rost,bgImagePath serviceMethod} {
	set tmpJPrefs($key) $jprefs($key)
    }
    set tmpPrefs(themeName) $prefs(themeName)

    set labfrpbl $page.fr
    labelframe $labfrpbl -text [::msgcat::mc Customization]
    pack $labfrpbl -side top -anchor w -padx 8 -pady 4
    set pbl [frame $labfrpbl.frin]
    pack $pbl -padx 10 -pady 6 -side left
    
    checkbutton $pbl.newwin -text " [::msgcat::mc prefcushow]" \
      -variable [namespace current]::tmpJPrefs(showMsgNewWin)
    checkbutton $pbl.savein -text " [::msgcat::mc prefcusave]" \
      -variable [namespace current]::tmpJPrefs(inboxSave)
    label $pbl.lmb2 -text [::msgcat::mc prefcu2clk]
    radiobutton $pbl.rb2new -text " [::msgcat::mc prefcuopen]" \
      -value newwin -variable [namespace current]::tmpJPrefs(inbox2click)
    radiobutton $pbl.rb2re   \
      -text " [::msgcat::mc prefcureply]" -value reply \
      -variable [namespace current]::tmpJPrefs(inbox2click)
    
    set frrost $pbl.robg
    frame $frrost
    pack [checkbutton $frrost.cb -text "  [::msgcat::mc prefrostbgim]" \
      -variable [namespace current]::tmpJPrefs(rost,useBgImage)] -side left
    pack [button $frrost.btpick -text "[::msgcat::mc {Pick}]..."  \
      -command [list [namespace current]::PickBgImage rost] -font $fontS] \
      -side left -padx 4
    pack [button $frrost.btdefk -text "[::msgcat::mc {Default}]"  \
      -command [list [namespace current]::DefaultBgImage rost] -font $fontS]  \
      -side left -padx 4
    
    set frtheme $pbl.ftheme
    frame $frtheme
    set wpoptheme $frtheme.pop

    set allrsrc [::Theme::GetAllAvailable]

    set wpopupmenuin [eval {tk_optionMenu $wpoptheme   \
      [namespace current]::tmpPrefs(themeName)} $allrsrc]
    pack [label $frtheme.l -text "[::msgcat::mc preftheme]:"] -side left
    pack $wpoptheme -side left
    
    grid $pbl.newwin -padx 2 -pady $ypad -sticky w -columnspan 2
    grid $pbl.savein -padx 2 -pady $ypad -sticky w -columnspan 2
    grid $pbl.lmb2   -padx 2 -pady $ypad -sticky w -columnspan 2
    grid $pbl.rb2new -padx 2 -pady $ypad -sticky w -columnspan 2
    grid $pbl.rb2re  -padx 2 -pady $ypad -sticky w -columnspan 2
    grid $frrost     -padx 2 -pady $ypad -sticky w -columnspan 2
    grid $frtheme    -padx 2 -pady $ypad -sticky w -columnspan 2
    
    # Disco, Agents or Browse.
    set frdisc $page.ag 
    labelframe $frdisc -text [::msgcat::mc prefcudisc]
    pack $frdisc -side top -anchor w -padx 8 -pady 4
    set pdisc [frame $frdisc.frin]
    pack $pdisc -padx 10 -pady 6 -side left
    radiobutton $pdisc.disco   \
      -text " [::msgcat::mc {Disco method}]"  \
      -variable [namespace current]::tmpJPrefs(serviceMethod) -value "disco"
    radiobutton $pdisc.browse   \
      -text " [::msgcat::mc prefcubrowse]"  \
      -variable [namespace current]::tmpJPrefs(serviceMethod) -value "browse"
    radiobutton $pdisc.agents  \
      -text " [::msgcat::mc prefcuagent]" -value "agents" \
      -variable [namespace current]::tmpJPrefs(serviceMethod)
    grid $pdisc.disco  -padx 2 -pady $ypad -sticky w
    grid $pdisc.browse -padx 2 -pady $ypad -sticky w
    grid $pdisc.agents -padx 2 -pady $ypad -sticky w
}

proc ::Jabber::JPrefs::PickBgImage {where} {
    variable tmpJPrefs

    set types {
	{{GIF Files}        {.gif}        }
	{{GIF Files}        {}        GIFF}
    }
    set ans [tk_getOpenFile -title {Open GIF Image} \
      -filetypes $types -defaultextension ".gif"]
    if {$ans != ""} {
	set tmpJPrefs($where,bgImagePath) $ans
    }
}

proc ::Jabber::JPrefs::DefaultBgImage {where} {
    variable tmpJPrefs

    set tmpJPrefs($where,bgImagePath) ""
}

proc ::Jabber::JPrefs::SavePrefsHook { } {
    global  prefs
    upvar ::Jabber::jprefs jprefs
    upvar ::Jabber::jstate jstate
    variable tmpJPrefs
    variable tmpPrefs
    
    if {!$jstate(haveJabberUI)} {
	return
    }
    array set jprefs [array get tmpJPrefs]
    set prefs(themeName) $tmpPrefs(themeName)

    # If changed present auto away settings, may need to reconfigure.
    ::Jabber::JPrefs::UpdateAutoAwaySettings    

    # Roster background image.
    ::Jabber::Roster::SetBackgroundImage $tmpJPrefs(rost,useBgImage) \
      $tmpJPrefs(rost,bgImagePath)

    unset tmpJPrefs
}

proc ::Jabber::JPrefs::CancelPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	if {![string equal $jprefs($key) $tmpJPrefs($key)]} {
	    ::Preferences::HasChanged
	    break
	}
    }
}

proc ::Jabber::JPrefs::UserDefaultsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	set tmpJPrefs($key) $jprefs($key)
    }
}

#-------------------------------------------------------------------------------
