#  Preferences.tcl ---
#  
#       This file is part of the whiteboard application. It implements the
#       preferences dialog window.
#      
#  Copyright (c) 1999-2003  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: Preferences.tcl,v 1.23 2003-12-19 15:47:39 matben Exp $
 
package require notebook
package require tree
package require tablelist
package require combobox

package provide Preferences 1.0

namespace eval ::Preferences:: {
    
    # Variable to be used in tkwait.
    variable finished
        
    # Name of the page that was in front last time.
    variable lastPage {}

    # Add all event hooks.
    hooks::add quitAppHook [list ::UI::SaveWinGeom $::wDlgs(prefs)]
}

proc ::Preferences::Build { } {
    global  this prefs wDlgs
    
    variable tmpPrefs
    variable tmpJPrefs
    variable tmpJServer
    
    variable wtoplevel
    variable finished
    variable nbframe
    variable xpadbt
    variable ypad 
    variable ypadtiny
    variable ypadbig
    variable lastPage

    set w $wDlgs(prefs)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    toplevel $w -class Preferences
    wm title $w [::msgcat::mc Preferences]
    wm protocol $w WM_DELETE_WINDOW ::Preferences::CancelPushBt
    set finished 0
    set wtoplevel $w
    
    # Unfortunately it is necessary to do some platform specific things to
    # get the pages to look nice.
    switch -glob -- $this(platform) {
	mac* {
	    eval $::macWindowStyle $w documentProc
	    ::UI::MacUseMainMenu $w
	    set ypadtiny 1
	    set ypad     3
	    set ypadbig  4
	    set xpadbt   7
	}
	windows {
	    set ypadtiny 0
	    set ypad     0
	    set ypadbig  1
	    set xpadbt   4
	}
	default {
	    set ypadtiny 0
	    set ypad     1
	    set ypadbig  2
	    set xpadbt   2
	}
    }    
    
    # Must sort 'jserver(profile)'.
    ::Jabber::SortProfileList
    
    # Work only on a temporary copy in case we cancel.
    catch {unset tmpPrefs}
    catch {unset tmpJPrefs}
    catch {unset tmpJServer}
    array set tmpPrefs [array get prefs]
    array set tmpJPrefs [::Jabber::GetjprefsArray]
    array set tmpJServer [::Jabber::GetjserverArray]
    
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
    
    # Frame for everything except the buttons.
    pack [frame $w.frall.fr] -fill both -expand 1 -side top
    
    # Tree frame with scrollbars.
    pack [frame $w.frall.fr.t -relief sunken -bd 1]   \
      -fill y -side left -padx 4 -pady 4
    set frtree $w.frall.fr.t.frtree
    pack [frame $frtree] -fill both -expand 1 -side left
    pack [label $frtree.la -text [::msgcat::mc {Settings Panels}]  \
      -font $fontSB -relief raised -bd 1 -bg #bdbdbd] -side top -fill x
    set wtree [::tree::tree $frtree.t -width 120 -height 300   \
      -yscrollcommand [list $frtree.sby set]       \
      -selectcommand ::Preferences::SelectCmd   \
      -doubleclickcommand {}]
    scrollbar $frtree.sby -orient vertical -command [list $wtree yview]
    
    pack $wtree -side left -fill both -expand 1
    pack $frtree.sby -side right -fill y
    
    # Fill tree.
    $wtree newitem {General} -text [::msgcat::mc General]
    $wtree newitem {General {Network Setup}} -text [::msgcat::mc {Network Setup}]
    $wtree newitem {General {Proxy Setup}} -text [::msgcat::mc {Proxy Setup}]
    $wtree newitem {General {Sounds & Speech}} -text [::msgcat::mc {Sounds & Speech}]
    $wtree newitem {General Shortcuts} -text [::msgcat::mc Shortcuts]
    #$wtree newitem {General Plugins}
    if {!$prefs(stripJabber)} {
	$wtree newitem {Jabber}
	$wtree newitem {Jabber {User Profiles}} -text [::msgcat::mc {User Profiles}]
	$wtree newitem {Jabber {Personal Info}} -text [::msgcat::mc {Personal Info}]
	$wtree newitem {Jabber {Auto Away}} -text [::msgcat::mc {Auto Away}]
	$wtree newitem {Jabber Subscriptions} -text [::msgcat::mc Subscriptions]
	$wtree newitem {Jabber Roster} -text [::msgcat::mc Roster]
	$wtree newitem {Jabber Conference} -text [::msgcat::mc Conference]
	$wtree newitem {Jabber Blockers} -text [::msgcat::mc Blockers]
	$wtree newitem {Jabber Customization} -text [::msgcat::mc Customization]
    }
    $wtree newitem {Whiteboard} -text [::msgcat::mc Whiteboard]
    $wtree newitem {Whiteboard Drawing} -text [::msgcat::mc Drawing]
    $wtree newitem {Whiteboard Text} -text [::msgcat::mc Text]
    $wtree newitem {Whiteboard Plugins} -text [::msgcat::mc Plugins]
    $wtree newitem {Whiteboard {File Mappings}} -text [::msgcat::mc {File Mappings}]
    $wtree newitem {Whiteboard {Edit Fonts}} -text [::msgcat::mc {Edit Fonts}]
    $wtree newitem {Whiteboard {File Cache}} -text [::msgcat::mc {File Cache}]
    $wtree newitem {Whiteboard Privacy} -text [::msgcat::mc Privacy]
    
    # The notebook and its pages.
    set nbframe [notebook::notebook $w.frall.fr.nb -borderwidth 1 -relief sunken]
    pack $nbframe -expand 1 -fill both -padx 4 -pady 4
    
    # Make the notebook pages.
    
    # Network Setup page -------------------------------------------------------
    set frpnet [$nbframe page {Network Setup}]
    ::Preferences::NetSetup::BuildPage $frpnet
    
    # Proxies Setup page -------------------------------------------------------
    set frpoxy [$nbframe page {Proxy Setup}]
    ::Preferences::Proxies::BuildPage $frpoxy
    
    # Sounds & Speech page -----------------------------------------------------
    set frpss [$nbframe page {Sounds & Speech}]
    ::Preferences::BuildPageSounds $frpss    
    
    # Shortcuts page -----------------------------------------------------------
    set frpshort [$nbframe page Shortcuts]
    ::Preferences::Shorts::BuildPage $frpshort    
    
    if {!$prefs(stripJabber)} {
	
	# User Info page -------------------------------------------------------
	set frpui [$nbframe page {User Profiles}]    
	::Preferences::Profiles::BuildPage $frpui
	
	# Personal Info page ---------------------------------------------------
	set frppers [$nbframe page {Personal Info}]
	::Preferences::BuildPagePersInfo $frppers
	
	# Auto Away page -------------------------------------------------------
	set frpaway [$nbframe page {Auto Away}]
	::Preferences::BuildPageAutoAway $frpaway
	
	# Subscriptions page ---------------------------------------------------
	set frpsubs [$nbframe page {Subscriptions}]
	::Preferences::BuildPageSubscriptions $frpsubs    
	
	# Roster page ----------------------------------------------------------
	set frprost [$nbframe page {Roster}]
	::Preferences::BuildPageRoster $frprost
	
	# Conference page ------------------------------------------------------
	set frpconf [$nbframe page {Conference}]
	::Preferences::BuildPageConf $frpconf
	
	# Blockers page --------------------------------------------------------
	set frbl [$nbframe page {Blockers}]    
	::Preferences::Block::BuildPage $frbl
	
	# Customization page -------------------------------------------------------
	set frcus [$nbframe page {Customization}]    
	::Preferences::Customization::BuildPage $frcus
    }
    
    # Drawing page -------------------------------------------------------------
    set frpdraw [$nbframe page {Drawing}]
    label $frpdraw.msg -text "Something on Drawing page."
    pack $frpdraw.msg -side left -expand yes -pady 8
    
    # Text page ----------------------------------------------------------------
    set frptxt [$nbframe page {Text}]
    label $frptxt.msg -text "Something on Text page."
    pack $frptxt.msg -side left -expand yes -pady 8
    
    # Edit Fonts page ----------------------------------------------------------
    set frpfont [$nbframe page {Edit Fonts}]
    ::Preferences::EditFonts::BuildPage $frpfont
    
    # Plugin page --------------------------------------------------------------
    set frpplug [$nbframe page Plugins]
    ::Preferences::Plugins::BuildPage $frpplug    
    
    # File Mappings ------------------------------------------------------------
    set frfm [$nbframe page {File Mappings}]    
    ::Preferences::FileMap::BuildPage $frfm
    
    # Cache page ---------------------------------------------------------------
    set frca [$nbframe page {File Cache}]  
    ::Preferences::BuildPageCache $frca
    
    # Privacy page -------------------------------------------------------------
    set frppriv [$nbframe page {Privacy}]
    ::Preferences::BuildPagePrivacy $frppriv
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btconn -text [::msgcat::mc Save] -default active -width 8 \
      -command ::Preferences::SavePushBt]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8   \
      -command ::Preferences::CancelPushBt]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btfactory -text [::msgcat::mc {Factory Settings}]   \
      -command [list ::Preferences::ResetToFactoryDefaults "40"]]  \
      -side left -padx 5 -pady 5
    pack [button $frbot.btrevert -text [::msgcat::mc {Revert Panel}]  \
      -command ::Preferences::ResetToUserDefaults]  \
      -side left -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    # Don't set width and height since not resizable (font change ex).
    # .prefs 597x385+177+69
    if {[info exists prefs(winGeom,$w)]} {
	regexp {^[^+-]+((\+|-).+$)} $prefs(winGeom,$w) match pos
	wm geometry $w $pos
    }
    wm resizable $w 0 0
    bind $w <Return> {}
    
    # Which page to be in front?
    if {[llength $lastPage]} {
	$wtree setselection $lastPage
    }
    
    # Grab and focus.
    focus $w
    
    # Wait here for a button press.
    tkwait variable [namespace current]::finished
    
    # Which page to be in front next time?
    set lastPage [$wtree getselection]
    
    # Clean up.
    trace vdelete ::Preferences::tmpPrefs(protocol) w  \
      ::Preferences::NetSetup::TraceNetConfig
    catch {grab release $w}
    catch {destroy $w}  
}

# Preferences::ResetToFactoryDefaults --
#
#       Takes all prefs that is in the master list, and sets all
#       our tmp variables identical to their default (hardcoded) values.
#       All MIME settings are excluded.
#
# Arguments:
#       maxPriority 0 20 40 60 80 100, or equivalent description.
#                   Pick only values with lower priority than maxPriority.
#       
# Results:
#       none. 

proc ::Preferences::ResetToFactoryDefaults {maxPriorityNum} {
    global  prefs
    
    variable tmpPrefs
    variable tmpJPrefs
    variable tmpJServer

    Debug 2 "::Preferences::ResetToFactoryDefaults maxPriorityNum=$maxPriorityNum"
    
    # Warn first.
    set ans [tk_messageBox -title [::msgcat::mc Warning] -type yesno -icon warning \
      -message [FormatTextForMessageBox [::msgcat::mc messfactorydefaults]] \
      -default no]
    if {$ans == "no"} {
	return
    }
    foreach item $prefs(master) {
	set varName [lindex $item 0]
	set resourceName [lindex $item 1]
	set defaultValue [lindex $item 2]
	set varPriority [lindex $item 3]
	if {$varPriority < $maxPriorityNum} {
	
	    # Set only tmp variables. Find the corresponding tmp variable.
	    if {[regsub "^prefs" $varName tmpPrefs tmpVarName]} {
	    } elseif {[regsub "^::Jabber::jprefs" $varName tmpJPrefs tmpVarName]} {
	    } elseif {[regsub "^::Jabber::jserver" $varName tmpJServer tmpVarName]} {
	    } else {
		continue
	    }
	    #puts "varName=$varName, tmpVarName=$tmpVarName"
	    
	    # Treat arrays specially.
	    if {[string match "*_array" $resourceName]} {
		array set $tmpVarName $defaultValue
	    } else {
		set $tmpVarName $defaultValue
	    }
	}
    }
    
    # Make temp array for servers.
    ::Preferences::Profiles::MakeTmpServArr
    
    # Probably more...
    
}

# Preferences::ResetToUserDefaults --
#
#       Revert panels to the state when dialog showed.

proc ::Preferences::ResetToUserDefaults { } {
    global  prefs
    
    variable tmpPrefs
    variable tmpJPrefs
    variable tmpJServer

    Debug 2 "::Preferences::ResetToUserDefaults"

    array set tmpPrefs [array get prefs]
    array set tmpJPrefs [::Jabber::GetjprefsArray]
    array set tmpJServer [::Jabber::GetjserverArray]
    
    # Make temp array for servers.
    ::Preferences::Profiles::MakeTmpServArr

    # Probably more...
        
}

proc ::Preferences::BuildPageSounds {page} {
    global  prefs
    
    variable xpadbt
    variable tmpJPrefs
    variable tmpPrefs
    variable ypad 
    
    set fontSB [option get . fontSmallBold {}]
    
    set labpsp [::mylabelframe::mylabelframe $page.sp [::msgcat::mc {Synthetic speech}]]
    pack $page.sp -side top -anchor w -ipadx 10
    
    checkbutton $labpsp.speak -text "  [::msgcat::mc prefsounsynwb]"  \
      -variable "[namespace current]::tmpPrefs(SpeechOn)"
    checkbutton $labpsp.speakmsg -text "  [::msgcat::mc prefsounsynno]"  \
      -variable "[namespace current]::tmpJPrefs(speakMsg)"
    checkbutton $labpsp.speakchat -text "  [::msgcat::mc prefsounsynch]"  \
      -variable "[namespace current]::tmpJPrefs(speakChat)"
    pack $labpsp.speak -side top -anchor w -padx 10 -pady $ypad
    pack $labpsp.speakmsg -side top -anchor w -padx 10 -pady $ypad
    pack $labpsp.speakchat -side top -anchor w -padx 10 -pady $ypad
    
    if {[::Plugins::HavePackage TclSpeech] || [::Plugins::HavePackage MSSpeech]} {
	
	# Get a list of voices
	set voicelist "None [::UserActions::SpeakGetVoices]"
    } else {
	set voicelist {None}
	$labpsp.speak configure -state disabled
	$labpsp.speakmsg configure -state disabled
	$labpsp.speakchat configure -state disabled
	set tmpPrefs(SpeechOn) 0
    }
    pack [frame $labpsp.fr] -side top -anchor w -padx 26 -pady 2
    label $labpsp.fr.in -text [::msgcat::mc prefsounvoin]
    label $labpsp.fr.out -text [::msgcat::mc prefsounvoou]
    set wpopin $labpsp.fr.popin
    set wpopupmenuin [eval {tk_optionMenu $wpopin   \
      [namespace current]::tmpPrefs(voiceOther)} $voicelist]
    $wpopin configure -highlightthickness 0 -font $fontSB
    set wpopout $labpsp.fr.popout
    set wpopupmenuout [eval {tk_optionMenu $wpopout   \
      [namespace current]::tmpPrefs(voiceUs)} $voicelist]
    $wpopout configure -highlightthickness 0 -font $fontSB
    
    grid $labpsp.fr.in $wpopin -sticky w -pady 1
    grid $labpsp.fr.out $wpopout -sticky w -pady 1
    if {![::Plugins::HavePackage TclSpeech] && ![::Plugins::HavePackage MSSpeech]} {
	$wpopin configure -state disabled
	$wpopout configure -state disabled
    }    
    
    set labpalrt [::mylabelframe::mylabelframe $page.alrt [::msgcat::mc {Alert sounds}]]
    pack $page.alrt -side top -anchor w -ipadx 10
    label $labpalrt.lbl -text [::msgcat::mc prefsounpick]
    pack $labpalrt.lbl -side top -anchor w -padx 6 -pady $ypad
    foreach name {online offline newmsg statchange connected} txt {
	{User is online} 
	{User is offline}
	{New incoming message} 
	{User's status changed}
	{Is connected}} {
	    checkbutton $labpalrt.$name -text "  [::msgcat::mc $txt]"  \
	      -variable "[namespace current]::tmpJPrefs(snd,$name)"
	    pack $labpalrt.$name -side top -anchor w -pady $ypad -padx 10
    }
}

# namespace  ::Preferences::Profiles:: -----------------------------------------

namespace eval ::Preferences::Profiles:: {
    
}

# User Profiles Page ...........................................................

proc ::Preferences::Profiles::BuildPage {page} {
    global  prefs
    
    upvar ::Preferences::tmpJServer tmpJServer
    upvar ::Preferences::tmpJServArr tmpJServArr
    upvar ::Preferences::xpadbt xpadbt
    variable wcombo    
    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable digest
    variable wuserinfofocus
    
    set digest 1
    set fontS [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]
    
    set labpui [::mylabelframe::mylabelframe $page.fr [::msgcat::mc {User Profiles}]]
    pack $page.fr -side left -anchor n -ipadx 10 -ipady 6
    
    message $labpui.msg -text [::msgcat::mc prefprof] -aspect 800
    pack $labpui.msg -side top -fill x

    set pui $labpui.fr
    pack [frame $pui] -side left  
    
    # Make temp array for servers.
    ::Preferences::Profiles::MakeTmpServArr
        
    # Option menu for the servers.
    label $pui.lpop -text "[::msgcat::mc Profile]:" -font $fontSB -anchor e
    
    set wcombo $pui.popup
    ::combobox::combobox $wcombo   \
      -textvariable [namespace current]::profile  \
      -command [namespace current]::Set
    eval {$wcombo list insert end} $tmpJServArr(all)
        
    grid $pui.lpop -column 0 -row 0 -sticky e
    grid $wcombo -column 1 -row 0 -sticky ew
        
    # Verify that the selected also in array.
    if {[lsearch -exact $tmpJServer(profile) $profile] < 0} {
	set profile [lindex $tmpJServer(profile) 0]
    }
    set profile $tmpJServer(profile,selected)    
    set server $tmpJServArr($profile,server)
    set username $tmpJServArr($profile,username)
    set password $tmpJServArr($profile,password)
    set resource $tmpJServArr($profile,resource)
    
    label $pui.lserv -text "[::msgcat::mc {Jabber Server}]:" -font $fontSB \
      -anchor e
    entry $pui.eserv -width 28   \
      -textvariable [namespace current]::server -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    label $pui.luser -text "[::msgcat::mc Username]:" -font $fontSB -anchor e
    entry $pui.euser -width 28  \
      -textvariable [namespace current]::username -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    label $pui.lpass -text "[::msgcat::mc Password]:" -font $fontSB -anchor e
    entry $pui.epass -width 28  \
      -textvariable [namespace current]::password -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    label $pui.lres -text "[::msgcat::mc Resource]:" -font $fontSB -anchor e
    entry $pui.eres -width 28   \
      -textvariable [namespace current]::resource -validate key  \
      -validatecommand {::Jabber::ValidateJIDChars %S}
    checkbutton $pui.cdig -text "  [::msgcat::mc {Scramble password}]"  \
      -variable [namespace current]::digest
    set wuserinfofocus $wcombo

    grid $pui.lserv -column 0 -row 1 -sticky e
    grid $pui.eserv -column 1 -row 1 -sticky w
    grid $pui.luser -column 0 -row 2 -sticky e
    grid $pui.euser -column 1 -row 2 -sticky w
    grid $pui.lpass -column 0 -row 3 -sticky e
    grid $pui.epass -column 1 -row 3 -sticky w
    grid $pui.lres -column 0 -row 4 -sticky e
    grid $pui.eres -column 1 -row 4 -sticky w
    grid $pui.cdig -column 1 -row 5 -sticky w -pady 2

    set puibt [frame $labpui.frbt]
    pack $puibt -padx 4 -pady 6 -side right -fill y -expand 1
    pack [button $puibt.new -font $fontS -text [::msgcat::mc New]  \
      -padx $xpadbt -command [namespace current]::New]   \
      -side top -fill x -pady 4
    pack [button $puibt.app -font $fontS -text [::msgcat::mc Apply] \
      -padx $xpadbt -command [namespace current]::Apply]   \
      -side top -fill x -pady 4
    pack [button $puibt.del -font $fontS -text [::msgcat::mc Delete]  \
      -padx $xpadbt -command [namespace current]::Delete]   \
      -side top -fill x -pady 4
}
    
# Preferences::Profiles::MakeTmpServArr --
#
#       Make temp array for servers.

proc ::Preferences::Profiles::MakeTmpServArr { } {
    
    upvar ::Preferences::tmpJServer tmpJServer
    upvar ::Preferences::tmpJServArr tmpJServArr
    
    # New... Profiles
    set tmpJServArr(all) {}
    foreach {name spec} $tmpJServer(profile) {
	lappend tmpJServArr(all) $name
	foreach [list \
	  tmpJServArr($name,server)   \
	  tmpJServArr($name,username) \
	  tmpJServArr($name,password) \
	  tmpJServArr($name,resource)] $spec break
    }
    set tmpJServArr(all) [lsort -dictionary $tmpJServArr(all)]
}

# ::Preferences::Profiles::UpdateTmpJServerProfile --
#
#       Make the 'tmpJServer(profile)' reflect 'tmpJServArr'.

proc ::Preferences::Profiles::UpdateTmpJServerProfile { } {
    
    upvar ::Preferences::tmpJServer tmpJServer
    upvar ::Preferences::tmpJServArr tmpJServArr
    
    # This is a bit of double counting with two temp storages...
    # New... Profiles
    set tmpJServer(profile) {}
    foreach profile [lsort -dictionary $tmpJServArr(all)] {
	lappend tmpJServer(profile) $profile   \
	  [list $tmpJServArr($profile,server)  \
	  $tmpJServArr($profile,username)      \
	  $tmpJServArr($profile,password)      \
	  $tmpJServArr($profile,resource)]
    }
}

# Preferences::Profiles::Set --
#
#       Callback for the combobox when a new item is selected.

proc ::Preferences::Profiles::Set {wcombo profile} {
    
    upvar ::Preferences::tmpJServArr tmpJServArr
    upvar ::Preferences::tmpJServer tmpJServer
    variable server
    variable username
    variable password
    variable resource
    
    #puts "::Preferences::Profiles::Set profile=$profile"
    
    # In case this is a new profile.
    if {[info exists tmpJServArr($profile,server)]} {
	#puts "   $profile is set"
	set server $tmpJServArr($profile,server)
	set username $tmpJServArr($profile,username)
	set password $tmpJServArr($profile,password)
	set resource $tmpJServArr($profile,resource)
	set tmpJServer(profile,selected) $profile  
    }
}

proc ::Preferences::Profiles::New { } {
    
    variable profile
    variable server
    variable username
    variable password
    variable resource
    variable wuserinfofocus

    set profile {}
    set server {}
    set username {}
    set password {}
    set resource {}
    focus $wuserinfofocus
}

proc ::Preferences::Profiles::Apply { } {
    global  prefs
    
    upvar ::Preferences::tmpJServArr tmpJServArr
    upvar ::Preferences::tmpJServer tmpJServer
    variable wcombo
    variable profile
    variable server
    variable username
    variable password
    variable resource

    #puts "::Preferences::Profiles::Apply profile=$profile"
    
    # Check that necessary entries are non-empty, at least.
    if {($server == "") || ($username == "")} {
	tk_messageBox -type ok -icon error  \
	  -title [::msgcat::mc Error] -message [FormatTextForMessageBox \
	  [::msgcat::mc messfillserveruser]]
	return
    }
    
    # Create a unique profile name if not given.
    if {[string length $profile] == 0} {
	set profile $server

	# Make sure that 'profile' is unique.
	if {[lsearch -exact $tmpJServArr(all) $profile] >= 0} {
	    set i 2
	    set tmpprof $profile
	    set profile ${tmpprof}-${i}
	    while {[lsearch -exact $tmpJServArr(all) $profile] >= 0} {
		incr i
		set profile ${tmpprof}-${i}
	    }
	}
    }
    if {[string length $resource] == 0} {
	set resource "coccinella"
    }
    
    # Handle duplicate servers. Is this good???
    if {[lsearch -exact $tmpJServArr(all) $profile] >= 0} {
	
	# It's there already!
	set ans [tk_messageBox -type yesno -default yes -icon warning  \
	  -title [::msgcat::mc Warning] -message [FormatTextForMessageBox \
	  [::msgcat::mc messprofinuse]]]
	if {$ans == "no"} {
	    ::Preferences::Profiles::Set $wcombo [lindex $tmpJServArr(all) 0]
	    return
	}
    } else {
	$wcombo list insert end $profile
    }
    
    # Store it the temporary array.
    set tmpJServArr(all) [lsort -unique [concat $tmpJServArr(all) $profile]]
    set tmpJServArr($profile,server) $server
    set tmpJServArr($profile,username) $username
    set tmpJServArr($profile,password) $password
    set tmpJServArr($profile,resource) $resource
    set tmpJServer(profile,selected) $profile  
}

proc ::Preferences::Profiles::Delete { } {
    global  prefs
    
    upvar ::Preferences::tmpJServArr tmpJServArr
    variable profile
    variable wcombo
    
    #puts "::Preferences::Profiles::Delete profile=$profile"
    
    # The present state may be something that has not been stored by pressing
    # the Apply button.
    if {[info exists tmpJServArr($profile,server)]} {
	
	set ans [tk_messageBox -title [::msgcat::mc Warning]  \
	  -type yesno -icon warning -default yes \
	  -message [FormatTextForMessageBox [::msgcat::mc messremoveprofile]]]
	if {$ans == "yes"} {
	    unset tmpJServArr($profile,server)
	    unset tmpJServArr($profile,username)
	    unset tmpJServArr($profile,password)
	    unset tmpJServArr($profile,resource)
	    set ind [lsearch $tmpJServArr(all) $profile]
	    if {$ind >= 0} {
		set tmpJServArr(all) [lreplace $tmpJServArr(all) $ind $ind]
		$wcombo list delete $ind
	    }
	    set profile [lindex $tmpJServArr(all) 0]
	    ::Preferences::Profiles::Set $wcombo $profile
	}
    } else {
	set profile [lindex $tmpJServArr(all) 0]
	::Preferences::Profiles::Set $wcombo $profile
    }
}

#-------------------------------------------------------------------------------

proc ::Preferences::BuildPageRoster {page} {

    variable tmpJPrefs
    variable ypad 

    checkbutton $page.rmifunsub -text " [::msgcat::mc prefrorm]"  \
      -variable [namespace current]::tmpJPrefs(rost,rmIfUnsub)
    checkbutton $page.allsubno -text " [::msgcat::mc prefroallow]"  \
      -variable [namespace current]::tmpJPrefs(rost,allowSubNone)
    checkbutton $page.clrout -text " [::msgcat::mc prefroclr]"  \
      -variable [namespace current]::tmpJPrefs(rost,clrLogout)
    checkbutton $page.dblclk -text " [::msgcat::mc prefrochat]" \
      -variable [namespace current]::tmpJPrefs(rost,dblClk)  \
      -onvalue chat -offvalue normal
    checkbutton $page.sysicons -text " [::msgcat::mc prefrosysicons]" \
      -variable [namespace current]::tmpJPrefs(haveIMsysIcons)
    
    pack $page.rmifunsub $page.allsubno $page.clrout $page.dblclk  \
      $page.sysicons -side top -anchor w -pady $ypad -padx 10
}

proc ::Preferences::BuildPageConf {page} {

    variable tmpJPrefs
    variable ypad 

    # Conference (groupchat) stuff.
    set labfr [::mylabelframe::mylabelframe $page.fr [::msgcat::mc {Preferred Protocol}]]
    pack $page.fr -side top -anchor w
    set pbl [frame $labfr.frin]
    pack $pbl -padx 10 -pady 6 -side left
    
    foreach val {gc-1.0 muc}   \
      txt {
	{Groupchat-1.0 (fallback)} 
	{Multi-User-Chat with Conference as fallback}} {
	set wrad ${pbl}.[string map {. ""} $val]
	radiobutton $wrad -text [::msgcat::mc $txt] -value $val  \
	  -variable [namespace current]::tmpJPrefs(prefgchatproto)	      
	grid $wrad -sticky w -pady $ypad
    }
}

proc ::Preferences::BuildPagePersInfo {page} {

    set ppers [::mylabelframe::mylabelframe $page.fr [::msgcat::mc {Personal Information}]]
    pack $page.fr -side left -anchor n -ipadx 10 -ipady 6

    message $ppers.msg -text [::msgcat::mc prefpers] -aspect 800
    grid $ppers.msg -columnspan 2 -sticky ew
    
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
    foreach what [::Jabber::GetIQRegisterElements] {
	entry $ppers.ent$what -width 30    \
	  -textvariable "[namespace current]::tmpJPrefs(iq:register,$what)"
	grid $ppers.$what -column 0 -row $row -sticky e
	grid $ppers.ent$what -column 1 -row $row -sticky ew 
	incr row
    }    
    frame $ppers.bts
    grid $ppers.bts -columnspan 2 -sticky ew
}

proc ::Preferences::BuildPageAutoAway {page} {
    
    variable tmpJPrefs
    variable xpadbt
    
    # Auto away stuff.
    set labfrpbl [::mylabelframe::mylabelframe $page.fr [::msgcat::mc {Auto Away}]]
    pack $page.fr -side top -anchor w
    set pbl [frame $labfrpbl.frin]
    pack $pbl -padx 10 -pady 6 -side left
    pack [label $pbl.lab -text [::msgcat::mc prefaaset]] \
      -side top -anchor w
    
    pack [frame $pbl.frma] -side top -anchor w
    checkbutton $pbl.frma.lminaw -anchor w \
      -text "  [::msgcat::mc prefminaw]"  \
      -variable [namespace current]::tmpJPrefs(autoaway)
    entry $pbl.frma.eminaw -width 3  \
      -validate key -validatecommand {::Preferences::ValidMinutes %S} \
      -textvariable [namespace current]::tmpJPrefs(awaymin)
    checkbutton $pbl.frma.lminxa -anchor w \
      -text "  [::msgcat::mc prefminea]"  \
      -variable [namespace current]::tmpJPrefs(xautoaway)
    entry $pbl.frma.eminxa -width 3  \
      -validate key -validatecommand {::Preferences::ValidMinutes %S} \
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
    grid $pbl.frmsg.lxa -column 0 -row 1 -sticky e
    grid $pbl.frmsg.examsg -column 1 -row 1 -sticky w
    
    # Default logout status.
    set labfrstat [::mylabelframe::mylabelframe $page.frstat {Default Logout Status}]
    pack $page.frstat -side top -anchor w
    set pstat [frame $labfrstat.frin]
    pack $pstat -padx 10 -pady 6 -side left

    label $pstat.l -text "Status when logging out:"
    entry $pstat.e -width 32  \
      -textvariable [namespace current]::tmpJPrefs(logoutStatus)
    grid $pstat.l -column 0 -row 0 -sticky e
    grid $pstat.e -column 1 -row 0 -sticky w
}

proc ::Preferences::ValidMinutes {str} {
    if {[regexp {[0-9]*} $str match]} {
	return 1
    } else {
	bell
	return 0
    }
}

proc ::Preferences::BuildPageSubscriptions {page} {
    
    variable tmpJPrefs
    variable ypad
    
    set labfrpsubs [::mylabelframe::mylabelframe $page.fr [::msgcat::mc Subscribe]]
    pack $page.fr -side top -anchor w
    set psubs [frame $labfrpsubs.frin]
    pack $psubs -padx 10 -pady 6 -side left

    label $psubs.la1 -text [::msgcat::mc prefsuif]
    label $psubs.lin -text [::msgcat::mc prefsuis]
    label $psubs.lnot -text [::msgcat::mc prefsuisnot]
    grid $psubs.la1 -columnspan 2 -sticky w -pady $ypad
    grid $psubs.lin $psubs.lnot -sticky w -pady $ypad
    foreach val {accept reject ask}   \
      txt {Auto-accept Auto-reject {Ask each time}} {
	foreach val2 {inrost notinrost} {
	    radiobutton $psubs.${val2}${val}  \
	      -text [::msgcat::mc $txt] -value $val  \
	      -variable [namespace current]::tmpJPrefs(subsc,$val2)	      
	}
	grid $psubs.inrost${val} $psubs.notinrost${val} -sticky w -pady $ypad
    }

    set frauto [frame $page.auto]
    pack $frauto -side top -anchor w -padx 10 -pady $ypad
    checkbutton $frauto.autosub  \
      -text "  [::msgcat::mc prefsuauto]"  \
      -variable [namespace current]::tmpJPrefs(subsc,auto)
    label $frauto.autola -text "      [::msgcat::mc {Default group}]:"
    entry $frauto.autoent -width 22   \
      -textvariable [namespace current]::tmpJPrefs(subsc,group)
    grid $frauto.autosub -sticky w -columnspan 2 -pady $ypad
    grid $frauto.autola $frauto.autoent -sticky w -pady $ypad
}

proc ::Preferences::BuildPagePrivacy {page} {
    
    variable tmpPrefs
    variable xpadbt
    
    set labfrpbl [::mylabelframe::mylabelframe $page.fr [::msgcat::mc Privacy]]
    pack $page.fr -side left -anchor n
    set pbl [frame $labfrpbl.frin]
    pack $pbl -padx 10 -pady 6 -side left
    
    message $pbl.msg -text [::msgcat::mc prefpriv] -aspect 800
    checkbutton $pbl.only -anchor w \
      -text "  [::msgcat::mc Privacy]" -variable [namespace current]::tmpPrefs(privacy)
    pack $pbl.msg $pbl.only -side top -fill x -anchor w
}

# namespace  ::Preferences::Block:: --------------------------------------------

namespace eval ::Preferences::Block:: {
    
    variable finished
    variable addJid
    variable wlbblock
}

proc ::Preferences::Block::BuildPage {page} {
    
    variable wlbblock
    variable btrem
    variable wlbblock
    upvar ::Preferences::xpadbt xpadbt
    upvar ::Preferences::tmpJPrefs tmpJPrefs
    
    set fontS [option get . fontSmall {}]
    
    set labfrpbl [::mylabelframe::mylabelframe $page.fr [::msgcat::mc Blockers]]
    pack $page.fr -side left -anchor n
    set pbl [frame $labfrpbl.frin]
    pack $pbl -padx 10 -pady 6 -side left
    checkbutton $pbl.only  \
      -text " [::msgcat::mc prefblonly]"  \
      -variable [namespace current]::tmpJPrefs(block,notinrost)
    label $pbl.blk -text " [::msgcat::mc prefblbl]"
    frame $pbl.fr
    grid $pbl.only -sticky w -pady 1
    grid $pbl.blk -sticky w -pady 1
    grid $pbl.fr -sticky news -pady 1
    set wlbblock $pbl.fr.lb
    set wscyblock $pbl.fr.ysc
    listbox $wlbblock -width 22 -height 12 -selectmode extended  \
      -yscrollcommand [list $wscyblock set]   \
      -listvar tmpJPrefs(block,list)
    scrollbar $wscyblock -orient vertical -command [list $wlbblock yview]
    pack $wlbblock -side left -fill both -expand 1
    pack $wscyblock -side left -fill y
    set btadd $pbl.fr.add
    set btrem $pbl.fr.rm
    pack [button $btadd -text "[::msgcat::mc Add]..." -font $fontS -padx $xpadbt  \
      -command [list ::Preferences::Block::Add .blkadd]]    \
      -side top -fill x -padx 6 -pady 4
    pack [button $btrem -text [::msgcat::mc Remove] -font $fontS -padx $xpadbt  \
      -command [list ::Preferences::Block::Remove] -state disabled] \
      -side top -fill x -padx 6 -pady 4
    pack [button $pbl.fr.clr -text [::msgcat::mc Clear] -font $fontS \
      -padx $xpadbt -command [list ::Preferences::Block::Clear]]    \
      -side top -fill x -padx 6 -pady 4
        
    # Special bindings for the listbox.
    bind $wlbblock <Button-1> {+ focus %W}
    bind $wlbblock <<ListboxSelect>> [list [namespace current]::SelectCmd]
}

proc ::Preferences::Block::SelectCmd { } {

    variable btrem
    variable wlbblock

    if {[llength [$wlbblock curselection]]} {
	$btrem configure -state normal
    } else {
	$btrem configure -state disabled
    }
}

proc ::Preferences::Block::Add {w} {
    global  this

    variable finished
    variable addJid
    variable wlbblock
    
    set finished 0
    if {[winfo exists $w]} {
	return
    }
    if {[string match "mac*" $this(platform)]} {
	toplevel $w
	eval $::macWindowStyle $w documentProc
	::UI::MacUseMainMenu $w
    } else {
	toplevel $w
    }
    wm title $w [::msgcat::mc {Block JID}]
    
    # Global frame.
    pack [frame $w.frall -borderwidth 1 -relief raised] -fill both -expand 1
    
    # Labelled frame.
    set wcfr $w.frall.fr
    set wcont [::mylabelframe::mylabelframe $wcfr [::msgcat::mc {JID to block}]]
    pack $wcfr -side top -fill both -ipadx 10 -ipady 6 -in $w.frall
    
    # Overall frame for whole container.
    set frtot [frame $wcont.frin]
    pack $frtot
    message $frtot.msg -borderwidth 0 -aspect 500 \
      -text [::msgcat::mc prefblmsg]
    entry $frtot.ent -width 24    \
      -textvariable "[namespace current]::addJid"
    set addJid {}
    pack $frtot.msg $frtot.ent -side top -fill x -anchor w -padx 2 -pady 2
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btconn -text [::msgcat::mc Add] -width 8 -default active \
      -command [list ::Preferences::Block::DoAdd]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel] -width 8  \
      -command "set [namespace current]::finished 2"]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btconn invoke]
    
    # Grab and focus.
    focus $w
    focus $frtot.ent
    catch {grab $w}
    
    # Wait here for a button press.
    tkwait variable [namespace current]::finished
    
    catch {grab release $w}
    catch {destroy $w}
}

proc ::Preferences::Block::DoAdd { } {

    variable addJid
    variable finished
    variable wlbblock

    if {[::Jabber::IsWellFormedJID $addJid -type any]} {
	$wlbblock insert end $addJid
	set finished 1
    } else {
	set ans [tk_messageBox -type yesno -default no -icon warning  \
	  -title [::msgcat::mc Warning] -message [FormatTextForMessageBox \
	  [::msgcat::mc messblockbadjid $addJid]
	if {$ans == "yes"} {
	    $wlbblock insert end $addJid
	    set finished 1
	}
    }
}

proc ::Preferences::Block::Remove { } {

    variable wlbblock

    set selectedInd [$wlbblock curselection]
    if {[llength $selectedInd]} {
	foreach ind [lsort -integer -decreasing $selectedInd] {
	    $wlbblock delete $ind
	}
    }
}

proc ::Preferences::Block::Clear { } {
    
    variable wlbblock

    $wlbblock delete 0 end
}

# namespace  ::Preferences::Block:: --------------------------------------------

namespace eval ::Preferences::Customization:: {
    
}

proc ::Preferences::Customization::BuildPage {page} {
    global  this
    
    variable wlbblock
    variable btrem
    variable wlbblock
    upvar ::Preferences::xpadbt xpadbt
    upvar ::Preferences::ypad ypad
    
    set fontSB [option get . fontSmallBold {}]

    set labfrpbl [::mylabelframe::mylabelframe $page.fr [::msgcat::mc Customization]]
    pack $page.fr -side top -anchor w
    set pbl [frame $labfrpbl.frin]
    pack $pbl -padx 10 -pady 6 -side left
    
    label $pbl.lfont -text [::msgcat::mc prefcufont]
    button $pbl.btfont -text "[::msgcat::mc Pick]..." -width 8 -font $fontSB \
      -command ::Preferences::Customization::PickFont
    checkbutton $pbl.newwin  \
      -text " [::msgcat::mc prefcushow]" \
      -variable ::Preferences::tmpJPrefs(showMsgNewWin)
    checkbutton $pbl.savein   \
      -text " [::msgcat::mc prefcusave]" \
      -variable ::Preferences::tmpJPrefs(inboxSave)
    label $pbl.lmb2 -text [::msgcat::mc prefcu2clk]
    radiobutton $pbl.rb2new   \
      -text " [::msgcat::mc prefcuopen]" -value "newwin" \
      -variable ::Preferences::tmpJPrefs(inbox2click)
    radiobutton $pbl.rb2re   \
      -text " [::msgcat::mc prefcureply]" -value "reply" \
      -variable ::Preferences::tmpJPrefs(inbox2click)
    
    set frrost $pbl.robg
    frame $frrost
    pack [checkbutton $frrost.cb -text " Use background image (gif) in roster" \
      -variable ::Preferences::tmpJPrefs(rost,useBgImage)] -side left
    pack [button $frrost.btpick -text "Pick..." -font $fontSB  \
      -command [list [namespace current]::PickBgImage rost]] -side left -padx 4
    pack [button $frrost.btdefk -text "Default" -font $fontSB  \
      -command [list [namespace current]::DefaultBgImage rost]]  \
      -side left -padx 4
    
    set frtheme $pbl.ftheme
    frame $frtheme
    set wpoptheme $frtheme.pop
    set allrsrc {}
    foreach f [glob -nocomplain -tails -directory $this(resourcedbPath) *.rdb] {
	lappend allrsrc [file rootname $f]
    }
    set wpopupmenuin [eval {tk_optionMenu $wpoptheme   \
      [namespace parent]::tmpPrefs(themeName)} $allrsrc]
    pack [label $frtheme.l -text {Pick theme, need relaunch:}] -side left
    pack $wpoptheme -side left
    
    grid $pbl.lfont $pbl.btfont -padx 2 -pady $ypad -sticky w
    grid $pbl.newwin $pbl.btfont -padx 2 -pady $ypad -sticky w -columnspan 2
    grid $pbl.savein -padx 2 -pady $ypad -sticky w -columnspan 2
    grid $pbl.lmb2 -padx 2 -pady $ypad -sticky w -columnspan 2
    grid $pbl.rb2new -padx 2 -pady $ypad -sticky w -columnspan 2
    grid $pbl.rb2re -padx 2 -pady $ypad -sticky w -columnspan 2
    grid $frrost -padx 2 -pady $ypad -sticky w -columnspan 2
    grid $frtheme -padx 2 -pady $ypad -sticky w -columnspan 2
    
    # Agents or Browse.
    set frdisc [::mylabelframe::mylabelframe $page.ag {Agents or Browse}]
    pack $page.ag -side top -anchor w
    set pdisc [frame $frdisc.frin]
    pack $pdisc -padx 10 -pady 6 -side left
    label $pdisc.la -text [::msgcat::mc prefcudisc]
    radiobutton $pdisc.browse   \
      -text " [::msgcat::mc prefcubrowse]"  \
      -variable ::Preferences::tmpJPrefs(agentsOrBrowse) -value "browse"
    radiobutton $pdisc.agents  \
      -text " [::msgcat::mc prefcuagent]" -value "agents" \
      -variable ::Preferences::tmpJPrefs(agentsOrBrowse)
    grid $pdisc.la -padx 2 -pady $ypad -sticky w
    grid $pdisc.browse -padx 2 -pady $ypad -sticky w
    grid $pdisc.agents -padx 2 -pady $ypad -sticky w
    

}

proc ::Preferences::Customization::PickFont { } {
    
    upvar ::Preferences::tmpJPrefs tmpJPrefs
    
    set fontS [option get . fontSmall {}]
    array set fontArr [font actual $fontS]

    set opts [list -defaultfont $fontArr(-family)  \
      -defaultsize $fontArr(-size)  \
      -defaultweight $fontArr(-weight)  \
      -initialfont [lindex $tmpJPrefs(chatFont) 0]  \
      -initialsize [lindex $tmpJPrefs(chatFont) 1]  \
      -initialweight [lindex $tmpJPrefs(chatFont) 2]]
    set theFont [eval {::fontselection::fontselection .mnb} $opts]
    if {[llength $theFont]} {
	set tmpJPrefs(chatFont) $theFont
    }
}

proc ::Preferences::Customization::PickBgImage {where} {
    upvar ::Preferences::tmpJPrefs tmpJPrefs

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

proc ::Preferences::Customization::DefaultBgImage {where} {
    upvar ::Preferences::tmpJPrefs tmpJPrefs

    set tmpJPrefs($where,bgImagePath) $tmpJPrefs($where,defBgImagePath)
}

# namespace  ::Preferences::Plugins:: ------------------------------------------

namespace eval ::Preferences::Plugins:: {
    
    variable plugins
}

proc ::Preferences::Plugins::BuildPage {page} {
    global  prefs
    
    variable plugins
    upvar ::Preferences::ypad ypad

    # Conference (groupchat) stuff.
    set labfr [::mylabelframe::mylabelframe $page.fr [::msgcat::mc {Plugin Control}]]
    pack $page.fr -side top -anchor w
    set pbl [frame $labfr.frin]
    pack $pbl -padx 10 -pady 6 -side left
    
    label ${pbl}.lhead -wraplength 300 -anchor w -justify left \
      -text "You may unselect any of these packages if\
      you don't want them loaded. You must relaunch for this to take effect."
    pack ${pbl}.lhead -padx 0 -pady 2 -side top -anchor w
    
    set pfr [frame ${pbl}.frpl]
    pack $pfr -side top -anchor w
    set i 0
    foreach plug [::Plugins::GetAllPackages platform] {
	set icon [::Plugins::GetIconForPackage $plug 12]
	if {$icon != ""} {
	    label ${pfr}.i${i} -image $icon
	    grid ${pfr}.i${i} -row $i -column 0 -sticky w
	}
	set plugins($plug) [::Plugins::IsLoaded $plug]
	checkbutton ${pfr}.c${i} -anchor w -text " $plug"  \
	  -variable [namespace current]::plugins($plug)
	grid ${pfr}.c${i} -row $i -column 1 -padx 2 -pady $ypad -sticky ew
	incr i
    }
}

proc ::Preferences::Plugins::Save { } {
    global prefs
    variable plugins

    set banList {}
    foreach name [array names plugins] {
	if {$plugins($name) == 0} {
	    lappend banList $name
	}
    }
    set prefs(pluginBanList) [lsort -unique $banList]
}

# namespace  ::Preferences::FileMap:: ------------------------------------------

namespace eval ::Preferences::FileMap:: {
    
    # Wait for this variable to be set in the "Inspect Associations" dialog.
    variable finishedInspect
        
    # Temporary local copy of Mime types to edit.
    variable tmpMime2Description
    variable tmpMimeTypeIsText
    variable tmpMime2SuffixList
    variable tmpMimeTypeDoWhat
    variable tmpPrefMimeType2Package
}

proc ::Preferences::FileMap::BuildPage {page} {
    global  prefs  wDlgs

    variable tmpMime2Description
    variable tmpMimeTypeIsText
    variable tmpMime2SuffixList
    variable tmpMimeTypeDoWhat
    variable tmpPrefMimeType2Package
    variable wmclist
    upvar ::Preferences::xpadbt xpadbt
        
    # Work only on copies of list of MIME types in case user presses the 
    # Cancel button. The MIME type works as a key in our database
    # (arrays) of various features.

    array set tmpMime2Description [::Types::GetDescriptionArr]
    array set tmpMimeTypeIsText [::Types::GetIsMimeTextArr]
    array set tmpMime2SuffixList [::Types::GetSuffixListArr]
    array set tmpMimeTypeDoWhat [::Plugins::GetDoWhatForMimeArr]
    array set tmpPrefMimeType2Package [::Plugins::GetPreferredPackageArr]
    
    set fontS [option get . fontSmall {}]
    
    # Frame for everything inside the labeled container.
    set wcont1 [::mylabelframe::mylabelframe $page.frtop [::msgcat::mc preffmhelp]]
    pack $page.frtop -side top -anchor w
    set fr1 [frame $wcont1.fr]
    
    pack $fr1 -side left -padx 16 -pady 10 -fill x
    pack $wcont1 -fill x    
    
    # Make the multi column listbox. 
    # Keep an invisible index column with index as a tag.
    set colDef [list 0 [::msgcat::mc Description] 0 [::msgcat::mc {Handled By}] 0 ""]
    set wmclist $fr1.mclist
    set ns [namespace current]
    
    tablelist::tablelist $wmclist  \
      -columns $colDef -yscrollcommand [list $fr1.vsb set]  \
      -labelcommand "tablelist::sortByColumn"  \
      -stretch all -width 42 -height 12
    $wmclist columnconfigure 2 -hide 1

    scrollbar $fr1.vsb -orient vertical -command [list $wmclist yview]
    
    grid $wmclist -column 0 -row 0 -sticky news
    grid $fr1.vsb -column 1 -row 0 -sticky ns
    grid columnconfigure $fr1 0 -weight 1
    grid rowconfigure $fr1 0 -weight 1
        
    # Insert all MIME types.
    set i 0
    foreach mime [::Types::GetAllMime] {
	set doWhat [::Plugins::GetDoWhatForMime $mime]
	set icon [::Plugins::GetIconForPackage $doWhat 12]
	set desc [::Types::GetDescriptionForMime $mime]
	if {![regexp {(unavailable|reject|save|ask)} $doWhat] && ($icon != "")} {
	    $wmclist insert end [list " $desc" $doWhat $mime]
	    $wmclist cellconfigure "$i,1" -image $icon
	} else {
	    $wmclist insert end [list " $desc" "     $doWhat" $mime]
	}
	incr i
    }    
    
    # Add, Change, and Remove buttons.
    set frbt [frame $fr1.frbot]
    grid $frbt -row 1 -column 0 -columnspan 2 -sticky nsew -padx 0 -pady 0
    button $frbt.rem -text [::msgcat::mc Delete] -font $fontS  \
      -state disabled -width 8 -padx $xpadbt  \
      -command "::Preferences::FileMap::DeleteAssociation $wmclist  \
      \[$wmclist curselection]"
    button $frbt.change -text "[::msgcat::mc Edit]..." -font $fontS  \
      -state disabled -width 8 -padx $xpadbt -command  \
      "${ns}::Inspect $wDlgs(fileAssoc) edit $wmclist \[$wmclist curselection]"
    button $frbt.add -text "[::msgcat::mc New]..." -font $fontS -width 8 -padx $xpadbt \
      -command [list ${ns}::Inspect .setass new $wmclist -1]
    pack $frbt.rem $frbt.change $frbt.add -side right -padx 5 -pady 5
    
    # Special bindings for the tablelist.
    set body [$wmclist bodypath]
    bind $body <Button-1> {+ focus %W}
    bind $body <Double-1> [list $frbt.change invoke]
    bind $wmclist <FocusIn> "$frbt.rem configure -state normal;  \
      $frbt.change configure -state normal"
    bind $wmclist <FocusOut> "$frbt.rem configure -state disabled;  \
      $frbt.change configure -state disabled"
    #bind $wmclist <<ListboxSelect>> [list [namespace current]::SelectMsg]
}

# ::Preferences::FileMap::DeleteAssociation --
#
#       Deletes an MIME association.
#
# Arguments:
#       wmclist  the multi column listbox widget path.
#       indSel   the index of the one to remove.
# Results:
#       None.

proc ::Preferences::FileMap::DeleteAssociation {wmclist {indSel {}}} {
    
    variable tmpMime2Description
    variable tmpMimeTypeIsText
    variable tmpMime2SuffixList
    variable tmpPrefMimeType2Package

    if {$indSel == ""} {
	return
    }
    foreach {name pack mime} [lrange [$wmclist get $indSel] 0 2] break
    $wmclist delete $indSel
    catch {unset tmpMime2Description($mime)}
    catch {unset tmpMimeTypeIsText($mime)}
    catch {unset tmpMime2SuffixList($mime)}
    catch {unset tmpPrefMimeType2Package($mime)}
    
    # Select the next one
    $wmclist selection set $indSel
}    

# ::Preferences::FileMap::SaveAssociations --
# 
#       Takes all the temporary arrays that makes up our database, 
#       and sets them to the actual arrays, tmp...(MIME).
#
# Arguments:
#       
# Results:
#       None.

proc ::Preferences::FileMap::SaveAssociations { } {
    variable tmpMime2Description
    variable tmpMimeTypeIsText
    variable tmpMime2SuffixList
    variable tmpMimeTypeDoWhat
    variable tmpPrefMimeType2Package
        
    ::Types::SetDescriptionArr tmpMime2Description
    ::Types::SetSuffixListArr tmpMime2SuffixList
    ::Types::SetIsMimeTextArr tmpMimeTypeIsText
    ::Plugins::SetDoWhatForMimeArr tmpMimeTypeDoWhat
    ::Plugins::SetPreferredPackageArr tmpPrefMimeType2Package
    
    # Do some consistency checks.
    ::Types::VerifyInternal
    ::Plugins::VerifyPackagesForMimeTypes
}
    
# ::Preferences::FileMap::Inspect --
#
#       Shows a dialog to set the MIME associations for one specific MIME type.
#
# Arguments:
#       w       the toplevel widget path.
#       doWhat  is "edit" if we want to change an association, or "new" if...
#       wlist   the listbox widget path in the "FileAssociations" dialog.
#       indSel  the index of the selected item in 'wlist'.
#       
# Results:
#       Dialog is displayed.

proc ::Preferences::FileMap::Inspect {w doWhat wlist {indSel {}}} {
    global  prefs this
    
    variable textVarDesc
    variable textVarMime
    variable textVarSuffix
    variable packageVar
    variable receiveVar
    variable codingVar
    variable finishedInspect
    
    variable tmpMime2Description
    variable tmpMimeTypeIsText
    variable tmpMime2SuffixList
    variable tmpMimeTypeDoWhat
    variable tmpPrefMimeType2Package
    upvar ::Preferences::ypad ypad

    set receiveVar 0
    set codingVar 0
    
    if {[winfo exists $w]} {
	return
    }
    if {[string length $indSel] == 0} {
	return
    }
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
	::UI::MacUseMainMenu $w
    } else {

    }
    wm title $w [::msgcat::mc {Inspect Associations}]
    set finishedInspect -1
    
    set fontSB [option get . fontSmallBold {}]
    
    if {$doWhat == "edit"} {
	if {$indSel < 0} {
	    error {::Preferences::FileMap::Inspect called with illegal index}
	}
	
	# Find the corresponding MIME type.
	foreach {name pack mime} [lrange [$wlist get $indSel] 0 2] break
	set textVarMime $mime
	set textVarDesc $tmpMime2Description($mime)
	set textVarSuffix $tmpMime2SuffixList($mime)
	set codingVar $tmpMimeTypeIsText($mime)
	
	# Map to the correct radiobutton alternative.
	switch -- $tmpMimeTypeDoWhat($mime) {
	    unavailable - reject {
		set receiveVar reject
	    }
	    save - ask {
		set receiveVar $tmpMimeTypeDoWhat($mime)
	    }
	    default {
		
		# Should be a package.
		set receiveVar import
	    }
	}
	
	# This is for the package menu button.
	set packageList [::Plugins::GetPackageListForMime $mime]
	if {[llength $packageList] > 0} {		    
	    set packageVar $tmpPrefMimeType2Package($mime)
	} else {
	    set packageList None
	    set packageVar None
	}
    } elseif {$doWhat == "new"} {
	set textVarMime {}
	set textVarDesc {}
	set textVarSuffix {}
	set codingVar 0
	set receiveVar reject
	set packageVar None
	set packageList None
    }
    pack [frame $w.frall -borderwidth 1 -relief raised]
    
    # Frame for everything inside the labeled container: "Type of File".
    set wcont1 [::mylabelframe::mylabelframe $w.frtop [::msgcat::mc {Type of File}]]
    pack $w.frtop -in $w.frall -fill x
    set fr1 [frame $wcont1.fr]
    label $fr1.x1 -text "[::msgcat::mc Description]:"
    entry $fr1.x2 -width 30   \
      -textvariable [namespace current]::textVarDesc
    label $fr1.x3 -text "[::msgcat::mc {MIME type}]:"
    entry $fr1.x4 -width 30   \
      -textvariable [namespace current]::textVarMime
    label $fr1.x5 -text "[::msgcat::mc {File suffixes}]:"
    entry $fr1.x6 -width 30   \
      -textvariable [namespace current]::textVarSuffix
    
    set px 1
    set py 1
    grid $fr1.x1 -column 0 -row 0 -sticky e -padx $px -pady $py
    grid $fr1.x2 -column 1 -row 0 -sticky w -padx $px -pady $py
    grid $fr1.x3 -column 0 -row 1 -sticky e -padx $px -pady $py
    grid $fr1.x4 -column 1 -row 1 -sticky w -padx $px -pady $py
    grid $fr1.x5 -column 0 -row 2 -sticky e -padx $px -pady $py
    grid $fr1.x6 -column 1 -row 2 -sticky w -padx $px -pady $py
    
    pack $fr1 -side left -padx 8 -fill x
    pack $wcont1 -fill x    
    
    if {$doWhat == "edit"} {
	$fr1.x2 configure -state disabled
	$fr1.x4 configure -state disabled
    }
    
    # Frame for everything inside the labeled container: "Handling".
    set wcont2 [::mylabelframe::mylabelframe $w.frmid [::msgcat::mc Handling]]
    pack $w.frmid -in $w.frall -fill x
    set fr2 [frame $wcont2.fr]
    radiobutton $fr2.x1 -text " [::msgcat::mc {Reject receive}]"  \
      -variable [namespace current]::receiveVar -value reject
    radiobutton $fr2.x2 -text " [::msgcat::mc preffmsave]"  \
      -variable [namespace current]::receiveVar -value save
    frame $fr2.fr
    radiobutton $fr2.x3 -text " [::msgcat::mc {Import using}]:  "  \
      -variable [namespace current]::receiveVar -value import
    
    set wMenu [eval {
	tk_optionMenu $fr2.opt [namespace current]::packageVar
    } $packageList]
    $wMenu configure -font $fontSB 
    $fr2.opt configure -font $fontSB -highlightthickness 0
    
    radiobutton $fr2.x8 -text " [::msgcat::mc {Unknown: Prompt user}]"  \
      -variable [namespace current]::receiveVar -value ask
    frame $fr2.frcode
    label $fr2.x4 -text " [::msgcat::mc {File coding}]:"
    radiobutton $fr2.x5 -text " [::msgcat::mc {As text}]" -anchor w  \
      -variable [namespace current]::codingVar -value 1
    radiobutton $fr2.x6 -text " [::msgcat::mc Binary]" -anchor w   \
      -variable [namespace current]::codingVar -value 0
    
    # If we dont have any registered packages for this MIME, disable this
    # option.
    
    if {($doWhat == "edit") && ($packageList == "None")} {
	$fr2.x3 configure -state disabled
	$fr2.opt configure -state disabled
    }
    if {$doWhat == "new"} {
	$fr2.x3 configure -state disabled
    }
    pack $fr2.x1 $fr2.x2 $fr2.fr -side top -padx 10 -pady $ypad -anchor w
    pack $fr2.x3 $fr2.opt -in $fr2.fr -side left -padx 0 -pady 0
    pack $fr2.x8 -side top -padx 10 -pady $ypad -anchor w
    pack $fr2.frcode -side top -padx 10 -pady $ypad -anchor w
    grid $fr2.x4 $fr2.x5 -in $fr2.frcode -sticky w -padx 3 -pady $ypad
    grid x       $fr2.x6 -in $fr2.frcode -sticky w -padx 3 -pady $ypad
    
    pack $fr2 -side left -padx 8 -fill x
    pack $wcont2 -fill x    
    
    # Button part
    pack [frame $w.frbot -borderwidth 0] -in $w.frall -fill both  \
      -padx 8 -pady 6
    button $w.ok -text [::msgcat::mc Save] -width 8 -default active  \
      -command [list [namespace current]::SaveThisAss $wlist $indSel]
    button $w.cancel -text [::msgcat::mc Cancel] -width 8   \
      -command "set [namespace current]::finishedInspect 0"
    pack $w.ok $w.cancel -in $w.frbot -side right -padx 5 -pady 5
    
    if {[info exists prefs(winGeom,$w)]} {
	wm geometry $w $prefs(winGeom,$w)
    }
    wm resizable $w 0 0
    bind $w <Return> "$w.ok invoke"
    
    # Wait here for a button press.
    tkwait variable [namespace current]::finishedInspect
    grab release $w
    destroy $w
}

# ::Preferences::FileMap::SaveThisAss --
#
#       Saves the association for one specific MIME type.
#
# Arguments:
#       wlist   the listbox widget path in the "FileAssociations" dialog.
#       indSel  the index of the selected item in 'wlist'. -1 if new.
#       
# Results:
#       Modifies the tmp... variables for one MIME type.

proc ::Preferences::FileMap::SaveThisAss {wlist indSel} {
    
    # Variables for entries etc.
    variable textVarDesc
    variable textVarMime
    variable textVarSuffix
    variable packageVar
    variable receiveVar
    variable codingVar
    variable finishedInspect
    
    # The temporary copies of the MIME associations.
    variable tmpMime2Description
    variable tmpMimeTypeIsText
    variable tmpMime2SuffixList
    variable tmpMimeTypeDoWhat
    variable tmpPrefMimeType2Package

    # Check that no fields are empty.
    if {($textVarDesc == "") || ($textVarMime == "") || ($textVarSuffix == "")} {
	tk_messageBox -title [::msgcat::mc Error] -icon error -type ok  \
	  -message [::msgcat::mc messfieldsmissing]
	return
    }
    
    # Put this specific MIME type associations in the tmp arrays.
    set tmpMime2Description($textVarMime) $textVarDesc
    if {$packageVar == "None"} {
	set tmpPrefMimeType2Package($textVarMime) ""
    }
    
    # Map from the correct radiobutton alternative.
    switch -- $receiveVar {
	reject {
	    
	    # This maps either to an actual "reject" or to "unavailable".
	    if {[llength $tmpPrefMimeType2Package($textVarMime)]} {
		set tmpMimeTypeDoWhat($textVarMime) reject		
	    } else {
		set tmpMimeTypeDoWhat($textVarMime) unavailable
	    }
	}
	save - ask {
	    set tmpMimeTypeDoWhat($textVarMime) $receiveVar
	}
	default {
	    
	    # Should be a package.
	    set tmpMimeTypeDoWhat($textVarMime) $packageVar
	    set tmpPrefMimeType2Package($textVarMime) $packageVar
	}
    }
    set tmpMimeTypeIsText($textVarMime) $codingVar
    set tmpMime2SuffixList($textVarMime) $textVarSuffix
    
    # Need to update the Mime type list in the "File Association" dialog.
    
    if {$indSel == -1} {

	# New association.
	set indInsert end
    } else {
	
	# Delete old, add new below.
	$wlist delete $indSel
	set indInsert $indSel
    }	
	
    set doWhat $tmpMimeTypeDoWhat($textVarMime)
    set icon [::Plugins::GetIconForPackage $doWhat 12]
    if {![regexp {(unavailable|reject|save|ask)} $doWhat] && ($icon != "")} {
	$wlist insert $indInsert [list " $tmpMime2Description($textVarMime)" \
	  $doWhat $textVarMime]
	$wlist cellconfigure "$indInsert,1" -image $icon
    } else {
	$wlist insert $indInsert [list " $tmpMime2Description($textVarMime)" \
	  "     $doWhat" $textVarMime]
    }
    if {$indSel >= 0} {
	$wlist selection set $indSel
    } 
    set w [winfo toplevel $wlist]
    ::UI::SaveWinGeom $w
    set finishedInspect 1
}

# Preferences::FileMap::IsAnythingChangedQ --
# 
#       Returns 1 if any of the mime settings was changed, and 0 else.

proc ::Preferences::FileMap::IsAnythingChangedQ { } {
    variable tmpMime2Description
    variable tmpMimeTypeIsText
    variable tmpMime2SuffixList
    variable tmpMimeTypeDoWhat

    set allMimeList [lsort [::Types::GetAllMime]]
    set tmpAllMimeList [lsort [array names tmpMime2Description]]
    if {$allMimeList != $tmpAllMimeList} {
	return 1
    }
    foreach m $allMimeList {	
	set doWhat [::Plugins::GetDoWhatForMime $m]
	set desc [::Types::GetDescriptionForMime $m]
	set suffList [::Types::GetSuffixListForMime $m]
	set isText [::Types::IsMimeText $m]
	if {($desc != $tmpMime2Description($m)) ||  \
	  ($suffList != $tmpMime2SuffixList($m)) ||  \
	  ($isText != $tmpMimeTypeIsText($m)) ||  \
	  ($doWhat != $tmpMimeTypeDoWhat($m))} {
	    return 1
	}
    }
    return 0
}

# namespace  ::Preferences::NetSetup:: -----------------------------------------

namespace eval ::Preferences::NetSetup:: {

}
    
proc ::Preferences::NetSetup::BuildPage {page} {
    global  prefs this state

    variable wopt

    upvar ::Preferences::ypadtiny ypadtiny
    upvar ::Preferences::ypadbig ypadbig
    
    set fontSB [option get . fontSmallBold {}]
        
    set wcont [::mylabelframe::mylabelframe $page.fr [::msgcat::mc prefnetconf]]
    pack $page.fr -side top -anchor w

    # Frame for everything inside the labeled container.
    set fr [frame $wcont.fr]    
    message $fr.msg -width 260 -text [::msgcat::mc prefnethead]
    
    # The actual options.
    set fropt [frame $fr.fropt]
    set wopt $fropt
        
    # The Jabber server.
    radiobutton $fropt.jabb -text [::msgcat::mc {Jabber Client}]  \
      -font $fontSB -value jabber  \
      -variable ::Preferences::tmpPrefs(protocol)
    message $fropt.jabbmsg -width 160  \
      -text [::msgcat::mc prefnetjabb]
    
    # For the symmetric network config.
    radiobutton $fropt.symm -text [::msgcat::mc {Peer-to-Peer}]  \
      -font $fontSB -variable ::Preferences::tmpPrefs(protocol)  \
      -value symmetric
    if {$state(isServerUp)} {
	#$fropt.symm configure -state disabled
    }
    checkbutton $fropt.auto -text "  [::msgcat::mc {Auto Connect}]"  \
      -font $fontSB  \
      -variable ::Preferences::tmpPrefs(autoConnect)
    message $fropt.automsg -width 160  \
      -text [::msgcat::mc prefnetauto]
    checkbutton $fropt.multi -text "  [::msgcat::mc {Multi Connect}]"  \
      -font $fontSB  \
      -variable ::Preferences::tmpPrefs(multiConnect)
    message $fropt.multimsg -width 160  \
      -text [::msgcat::mc prefnetmulti]
    if {[string equal $prefs(protocol) "symmetric"]} { 
	$fropt.auto configure -state disabled
	$fropt.multi configure -state disabled
    }    
    
    button $fropt.adv -text "[::msgcat::mc Advanced]..." -command  \
      [list ::Preferences::NetSetup::Advanced]
    
    # If already connected don't allow network topology to be changed.
    if {[llength [::Network::GetIP to]] > 0} {
	$fropt.jabb configure -state disabled
	$fropt.symm configure -state disabled
    }
    if {$prefs(stripJabber) ||  \
      ($prefs(protocol) == "server") || ($prefs(protocol) == "client")} {
	$fropt.jabb configure -state disabled
	$fropt.symm configure -state disabled
    }
    grid $fropt.jabb -column 0 -row 0 -rowspan 4 -sticky nw -padx 10 -pady $ypadtiny
    grid $fropt.jabbmsg -column 1 -row 0 -sticky w -padx 10 -pady $ypadtiny
    grid $fropt.symm -column 0 -row 1 -rowspan 4 -sticky nw -padx 10 -pady $ypadtiny
    grid $fropt.auto -column 1 -row 1 -sticky w -padx 10 -pady $ypadtiny
    grid $fropt.automsg -column 1 -row 2 -sticky w -padx 10 -pady $ypadtiny
    grid $fropt.multi -column 1 -row 3 -sticky w -padx 10 -pady $ypadtiny
    grid $fropt.multimsg -column 1 -row 4 -sticky w -padx 10 -pady $ypadtiny
    grid $fropt.adv -column 0 -row 6 -sticky w -padx 10 -pady $ypadbig

    pack $fr.msg -side top -padx 2 -pady $ypadbig
    pack $fropt -side top -padx 5 -pady $ypadbig
    pack $fr -side left -padx 2    
    pack $wcont -fill x    
    
    trace variable ::Preferences::tmpPrefs(protocol) w  \
      [namespace current]::TraceNetConfig
}

# ::Preferences::NetSetup::TraceNetConfig --
#
#       Trace command for the 'tmpPrefs(protocol)' variable that is
#       used for the network type radio buttons.
#       
# Arguments:
#       name   the toplevel window.
#       index  array index.
#       op     operation.
#       
# Results:
#       shows dialog.

proc ::Preferences::NetSetup::TraceNetConfig {name index op} {
    
    variable wopt
    upvar ::Preferences::tmpPrefs tmpPrefs
    
    Debug 2 "::Preferences::NetSetup::TraceNetConfig"

    set fropt $wopt
    if {$tmpPrefs(protocol) == {symmetric}} { 
	$fropt.auto configure -state normal
	$fropt.multi configure -state normal
    } elseif {$tmpPrefs(protocol) == {central}} {
	$fropt.auto configure -state disabled
	$fropt.multi configure -state disabled
    } elseif {$tmpPrefs(protocol) == {jabber}} {
	$fropt.auto configure -state disabled
	$fropt.multi configure -state disabled
    }
}

# ::Preferences::NetSetup::UpdateUI --
#
#       If network setup changed be sure to update the UI to reflect this.
#       Must be called after saving in 'prefs' etc.
#       
# Arguments:
#       
# Results:
#       .

proc ::Preferences::NetSetup::UpdateUI { } {
    global  prefs state wDlgs
    
    Debug 2 "::Preferences::NetSetup::UpdateUI"
    
    # Update menus.
    switch -- $prefs(protocol) {
	jabber {
	    
	    # Show our combination window.
	    ::Jabber::UI::Show $wDlgs(jrostbro)
	}
	central {
	    
	    # We are only a client.
	    ::UI::MenuMethod .menu.file entryconfigure mOpenConnection  \
	      -command [list ::OpenConnection::OpenConnection $wDlgs(openConn)]
	    .menu entryconfigure *Jabber* -state disabled
	    
	    # Hide our combination window.
	    ::Jabber::UI::Close $wDlgs(jrostbro)
	}
	default {
	    ::UI::MenuMethod .menu.file entryconfigure mOpenConnection   \
	      -command [list ::OpenConnection::OpenConnection $wDlgs(openConn)]
	    if {!$prefs(stripJabber)} {
		.menu entryconfigure *Jabber* -state disabled
		
		# Hide our combination window.
		::Jabber::UI::Close $wDlgs(jrostbro)
	    }
	}
    }
    
    # Other UI updates needed.
    foreach w [::WB::GetAllWhiteboards] {
	set wtop [::UI::GetToplevelNS $w]
	::WB::SetCommHead $wtop $prefs(protocol)
	
	switch -- $prefs(protocol) {
	    jabber {
		::Jabber::BuildJabberEntry $wtop
	    }
	    default {
		::WB::DeleteJabberEntry $wtop
	    }
	}
    }
}

# Preferences::NetSetup::Advanced --
#
#       Shows dialog for setting the "advanced" network options.
#       
# Arguments:
#       
# Results:
#       shows dialog.

proc ::Preferences::NetSetup::Advanced {  } {
    global  this prefs

    variable finishedAdv -1
    
    set w .dlgAdvNet
    if {[string match "mac*" $this(platform)]} {
	toplevel $w
	eval $::macWindowStyle $w documentProc
	::UI::MacUseMainMenu $w
    } else {
	toplevel $w
    }
    wm title $w [::msgcat::mc {Advanced Setup}]
    
    set fontSB [option get . fontSmallBold {}]
    
    pack [frame $w.frall -borderwidth 1 -relief raised]
    set wcont [::mylabelframe::mylabelframe $w.frtop [::msgcat::mc {Advanced Configuration}]]
    pack $w.frtop -in $w.frall -side top -fill both
    
    # Frame for everything inside the labeled container.
    set fr [frame $wcont.fr]
    message $fr.msg -width 260 -text [::msgcat::mc prefnetadv]
    
    # The actual options.
    set fropt [frame $fr.fropt]

    label $fropt.lserv -text "[::msgcat::mc {Built in server port}]:"  \
      -font $fontSB
    label $fropt.lhttp -text "[::msgcat::mc {HTTP port}]:" \
      -font $fontSB
    label $fropt.ljab -text "[::msgcat::mc {Jabber server port}]:"  \
      -font $fontSB
    entry $fropt.eserv -width 6 -textvariable  \
      ::Preferences::tmpPrefs(thisServPort)
    entry $fropt.ehttp -width 6 -textvariable  \
      ::Preferences::tmpPrefs(httpdPort)
    entry $fropt.ejab -width 6 -textvariable  \
      ::Preferences::tmpJPrefs(port)

    if {!$prefs(haveHttpd)} {
	$fropt.ehttp configure -state disabled
    }
    
    set py 0
    set px 2
    set row 0
    foreach wid {serv http jab} {
	grid $fropt.l$wid -column 0 -row $row -sticky e   \
	  -padx $px -pady $py
	grid $fropt.e$wid -column 1 -row $row -sticky w   \
	  -padx $px -pady $py
	incr row
    }
        
    pack $fr.msg -side top -padx 2 -pady 6
    pack $fropt -side top -padx 5 -pady 6
    pack $fr -side left -padx 2    
    pack $wcont -fill x    
    
    # Button part.
    pack [frame $w.frbot -borderwidth 0] -in $w.frall -fill both  \
      -padx 8 -pady 6 -side bottom
    pack [button $w.ok -text [::msgcat::mc Save] -width 8 -default active \
      -command [namespace current]::AdvSetupSave]  \
      -in $w.frbot -side right -padx 5 -pady 5
    pack [button $w.cancel -text [::msgcat::mc Cancel] -width 8   \
      -command "set [namespace current]::finishedAdv 0"]  \
      -in $w.frbot -side right -padx 5 -pady 5
    wm resizable $w 0 0
    bind $w <Return> "$w.ok invoke"
    
    # Grab and focus.
    focus $w
    catch {grab $w}    
    tkwait variable [namespace current]::finishedAdv
    
    # Clean up.
    catch {unset finishedAdv}
    catch {grab release $w}
    destroy $w
}
    
# ::Preferences::NetSetup::AdvSetupSave --
#
#       Saves the values set in dialog in the preference variables.
#       It saves these port numbers independently of the main panel!!!
#       Is this the right thing to do???
#       
# Arguments:
#       
# Results:
#       none.

proc ::Preferences::NetSetup::AdvSetupSave {  } {
    global  prefs
    
    variable finishedAdv
    upvar ::Preferences::tmpPrefs tmpPrefs
    upvar ::Preferences::tmpJPrefs tmpJPrefs
    upvar ::Jabber::jprefs jprefs

    set prefs(thisServPort) $tmpPrefs(thisServPort)
    set prefs(httpdPort) $tmpPrefs(httpdPort)
    set jprefs(port) $tmpJPrefs(port)

    set finishedAdv 1
}

# namespace  ::Preferences::Shorts:: -------------------------------------------

namespace eval ::Preferences::Shorts:: {
    
    variable finished
}

proc ::Preferences::Shorts::BuildPage {page} {
    
    variable btadd
    variable btrem
    variable btedit
    variable wlbox
    variable shortListVar
    upvar ::Preferences::tmpPrefs tmpPrefs
    
    set fontS [option get . fontSmall {}]
    
    set wcont [::mylabelframe::mylabelframe $page.frtop [::msgcat::mc {Edit Shortcuts}]]
    pack $page.frtop -side top -anchor w
    
    # Overall frame for whole container.
    set frtot [frame $wcont.fr]
    message $frtot.msg -borderwidth 0 -aspect 600 \
      -text [::msgcat::mc prefshortcut]
    pack $frtot.msg -side top -padx 4 -pady 6
    
    # Frame for listbox and scrollbar.
    set frlist [frame $frtot.lst]
    
    # The listbox.
    set wsb $frlist.sb
    set shortListVar {}
    foreach pair $tmpPrefs(shortcuts) {
	lappend shortListVar [lindex $pair 0]
    }
    set wlbox [listbox $frlist.lb -height 10 -width 18   \
      -listvar [namespace current]::shortListVar \
      -yscrollcommand [list $wsb set] -selectmode extended]
    scrollbar $wsb -command [list $wlbox yview]
    pack $wlbox -side left -fill both
    pack $wsb -side left -fill both
    pack $frlist -side left
    
    # Buttons at the right side.
    frame $frtot.btfr
    set btadd $frtot.btfr.btadd
    set btrem $frtot.btfr.btrem
    set btedit $frtot.btfr.btedit
    button $btadd -text "[::msgcat::mc Add]..." -font $fontS  \
      -command [list [namespace current]::AddOrEdit add]
    button $btrem -text [::msgcat::mc Remove] -font $fontS -state disabled  \
      -command [namespace current]::Remove
    button $btedit -text "[::msgcat::mc Edit]..." -state disabled -font $fontS \
      -command [list [namespace current]::AddOrEdit edit]
    pack $frtot.btfr -side top
    pack $btadd $btrem $btedit -side top -fill x -padx 4 -pady 4
    
    pack $frtot -side left -padx 6 -pady 6    
    pack $wcont -fill x    
    
    # Listbox bindings.
    bind $wlbox <Button-1> {+ focus %W}
    bind $wlbox <Double-Button-1> [list $btedit invoke]
    bind $wlbox <<ListboxSelect>> [list [namespace current]::SelectCmd]
}

proc ::Preferences::Shorts::SelectCmd { } {

    variable btadd
    variable btrem
    variable btedit
    variable wlbox

    if {[llength [$wlbox curselection]]} {
	$btrem configure -state normal
    } else {
	$btrem configure -state disabled
	$btedit configure -state disabled
    }
    if {[llength [$wlbox curselection]] == 1} {
	$btedit configure -state normal
    }
}

proc ::Preferences::Shorts::Remove { } {
    
    variable wlbox
    variable shortListVar
    upvar ::Preferences::tmpPrefs tmpPrefs

    set selInd [$wlbox curselection]
    if {[llength $selInd]} {
	foreach ind [lsort -integer -decreasing $selInd] {
	    set shortListVar [lreplace $shortListVar $ind $ind]
	    set tmpPrefs(shortcuts) [lreplace $tmpPrefs(shortcuts) $ind $ind]
	}
    }
}

# ::Preferences::Shorts::AddOrEdit --
#
#       Callback when the "add" or "edit" buttons pushed. New toplevel dialog
#       for editing an existing shortcut, or adding a fresh one.
#
# Arguments:
#       what           "add" or "edit".
#       
# Results:
#       shows dialog.

proc ::Preferences::Shorts::AddOrEdit {what} {
    global  this
    
    variable wlbox
    variable finAdd
    variable shortListVar
    variable shortTextVar
    variable longTextVar
    upvar ::Preferences::tmpPrefs tmpPrefs
    
    Debug 2 "::Preferences::Shorts::AddOrEdit"

    set indShortcuts [lindex [$wlbox curselection] 0]
    if {$what == "edit" && $indShortcuts == ""} {
	return
    } 
    set w .taddshorts$what
    if {[winfo exists $w]} {
	return
    }
    toplevel $w
    if {[string match "mac*" $this(platform)]} {
	eval $::macWindowStyle $w documentProc
	::UI::MacUseMainMenu $w
    } else {
	#
    }
    if {$what == "add"} {
	set txt [::msgcat::mc {Add Shortcut}]
	set txt1 "[::msgcat::mc {New shortcut}]:"
	set txt2 "[::msgcat::mc prefshortip]:"
	set txtbt [::msgcat::mc Add]
	set shortTextVar {}
	set longTextVar {}
    } elseif {$what == "edit"} {
	set txt [::msgcat::mc {Edit Shortcut}]
	set txt1 "[::msgcat::mc Shortcut]:"
	set txt2 "[::msgcat::mc prefshortip]:"
	set txtbt [::msgcat::mc Save]
    }
    set finAdd 0
    wm title $w $txt
    
    set fontSB [option get . fontSmallBold {}]
    
    pack [frame $w.frall -borderwidth 1 -relief raised]
    
    # The top part.
    set wcont [::mylabelframe::mylabelframe $w.frtop $txt]
    pack $w.frtop -in $w.frall
    
    # Overall frame for whole container.
    set frtot [frame $wcont.fr]
    label $frtot.lbl1 -text $txt1 -font $fontSB
    entry $frtot.ent1 -width 36 -textvariable [namespace current]::shortTextVar
    label $frtot.lbl2 -text $txt2 -font $fontSB
    entry $frtot.ent2 -width 36 -textvariable [namespace current]::longTextVar
    grid $frtot.lbl1 -sticky w -padx 6 -pady 1
    grid $frtot.ent1 -sticky ew -padx 6 -pady 1
    grid $frtot.lbl2 -sticky w -padx 6 -pady 1
    grid $frtot.ent2 -sticky ew -padx 6 -pady 1
    
    pack $frtot -side left -padx 16 -pady 10
    pack $wcont -fill x    
    focus $frtot.ent1
    
    # Get the short pair to edit.
    if {[string equal $what "edit"]} {
	set shortTextVar [lindex [lindex $tmpPrefs(shortcuts) $indShortcuts] 0]
	set longTextVar [lindex [lindex $tmpPrefs(shortcuts) $indShortcuts] 1]
    } elseif {[string equal $what "add"]} {
	
    }
    
    # The bottom part.
    pack [frame $w.frbot -borderwidth 0] -in $w.frall -fill both  \
      -padx 8 -pady 6
    button $w.frbot.bt1 -text "$txtbt" -width 8 -default active  \
      -command [list [namespace current]::PushBtAddOrEdit $what]
    pack $w.frbot.bt1 -side right -padx 5 -pady 5
    pack [button $w.frbot.bt2 -text [::msgcat::mc Cancel] -width 8  \
      -command "set [namespace current]::finAdd 2"]  \
      -side right -padx 5 -pady 5
    
    bind $w <Return> [list $w.frbot.bt1 invoke]
    wm resizable $w 0 0
    
    # Grab and focus.
    focus $w
    catch {grab $w}
    tkwait variable [namespace current]::finAdd
    
    catch {grab release $w}
    destroy $w
}

proc ::Preferences::Shorts::PushBtAddOrEdit {what} {
    
    variable wlbox
    variable finAdd
    variable shortListVar
    variable shortTextVar
    variable longTextVar
    upvar ::Preferences::tmpPrefs tmpPrefs

    if {($shortTextVar == "") || ($longTextVar == "")} {
	set finAdd 1
	return
    }
    if {$what == "add"} {
 
	# Save shortcuts in listbox.
	lappend shortListVar $shortTextVar
	lappend tmpPrefs(shortcuts) [list $shortTextVar $longTextVar]
    } else {
	
	# Edit. Replace old with new.
	set ind [lindex [$wlbox curselection] 0]
	set shortListVar [lreplace $shortListVar $ind $ind $shortTextVar]
	set tmpPrefs(shortcuts) [lreplace $tmpPrefs(shortcuts) $ind $ind   \
	  [list $shortTextVar $longTextVar]]
    }
    set finAdd 1
}

# namespace  ::Preferences::EditFonts:: ----------------------------------------
# 
#       These procedures implement the dialog of importing fonts to the 
#       whiteboard.

namespace eval ::Preferences::EditFonts:: {
    
    namespace export EditFontFamilies
}

proc ::Preferences::EditFonts::BuildPage {page} {
    global  prefs

    variable wlbwb
    variable wlbsys
    variable btimport
    variable btremove
    variable wsamp
    upvar ::Preferences::xpadbt xpadbt
    
    set fontS [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]
    
    # Labelled frame.
    set wcfr $page.fr
    set wcont [::mylabelframe::mylabelframe $wcfr [::msgcat::mc {Import/Remove fonts}]]
    pack $wcfr -side top -fill both -ipadx 8 -ipady 4
    
    # Overall frame for whole container.
    set frtot [frame $wcont.frin]
    pack $frtot
    
    label $frtot.sysfont -text [::msgcat::mc {System fonts}] -font $fontSB
    label $frtot.wifont -text [::msgcat::mc {Whiteboard fonts}] -font $fontSB
    grid $frtot.sysfont x $frtot.wifont -padx 4 -pady 6
    
    grid [frame $frtot.fr1] -column 0 -row 1
    grid [frame $frtot.fr2] -column 1 -row 1 -sticky n -padx 4 -pady 2
    grid [frame $frtot.fr3] -column 2 -row 1
    set wlbsys $frtot.fr1.lb
    set wlbwb $frtot.fr3.lb
    
    # System fonts.
    listbox $wlbsys -width 20 -height 10  \
      -yscrollcommand [list $frtot.fr1.sc set]
    scrollbar $frtot.fr1.sc -orient vertical   \
      -command [list $frtot.fr1.lb yview]
    pack $frtot.fr1.lb $frtot.fr1.sc -side left -fill y
    eval $frtot.fr1.lb insert 0 [font families]
    
    # Mid buttons.
    set btimport $frtot.fr2.imp
    set btremove $frtot.fr2.rm
    pack [button $btimport -text {>>Import>>} -state disabled \
      -font $fontS -padx $xpadbt   \
      -command "[namespace current]::PushBtImport  \
      \[$wlbsys curselection] $wlbsys $wlbwb"] -padx 1 -pady 6 -fill x
    pack [button $btremove -text [::msgcat::mc Remove] -state disabled  \
      -font $fontS -padx $xpadbt   \
      -command "[namespace current]::PushBtRemove  \
      \[$wlbwb curselection] $wlbwb"] -padx 1 -pady 6 -fill x
    pack [button $frtot.fr2.std -text {Standard} -font $fontS    \
      -padx $xpadbt -command "[namespace current]::PushBtStandard $wlbwb"] \
      -padx 1 -pady 6 -fill x
    
    # Whiteboard fonts.
    listbox $wlbwb -width 20 -height 10  \
      -yscrollcommand [list $frtot.fr3.sc set]
    scrollbar $frtot.fr3.sc -orient vertical   \
      -command [list $frtot.fr3.lb yview]
    pack $frtot.fr3.lb $frtot.fr3.sc -side left -fill y
    eval $frtot.fr3.lb insert 0 $prefs(canvasFonts)
    
    message $frtot.msg -text [::msgcat::mc preffontmsg] -aspect 600
    set wsamp $frtot.samp
    canvas $wsamp -width 200 -height 48 -highlightthickness 0 -border 1 \
      -relief sunken
    grid $frtot.msg -columnspan 3 -sticky news
    grid $frtot.samp -columnspan 3 -sticky news
    
    bind $wlbsys <Button-1> {+ focus %W}
    bind $wlbwb <Button-1> {+ focus %W}
    bind $wlbsys <<ListboxSelect>> [list [namespace current]::SelectCmd system]
    bind $wlbwb <<ListboxSelect>> [list [namespace current]::SelectCmd wb]
}
  
proc ::Preferences::EditFonts::SelectCmd {which} {

    variable wlbwb
    variable wlbsys
    variable btimport
    variable btremove
    variable wsamp

    if {$which == "system"} {
	set selInd [$wlbsys curselection]
	if {[llength $selInd]} {
	    $btimport configure -state normal
	    set fntName [$wlbsys get $selInd]
	    if {[llength $fntName]} {
		$wsamp delete all
		$wsamp create text 6 24 -anchor w -text {Hello cruel World!}  \
		  -font [list $fntName 36]
	    }
	} else {
	    $btimport configure -state disabled
	}
    } elseif {$which == "wb"} {
	if {[llength [$wlbwb curselection]]} {
	    $btremove configure -state normal
	} else {
	    $btremove configure -state disabled
	}
    }
}

# EditFonts::PushBtImport, PushBtRemove, PushBtSave, PushBtStandard --
#
#       Callbacks for the various buttons in the FontFamilies dialog.
#   
# Arguments:
#       indSel    the index of the selected line in the listbox.
#       wsys      the system font listbox widget.
#       wapp      the application font listbox widget.
#       
# Results:
#       content in listbox updated.

proc ::Preferences::EditFonts::PushBtImport {indSel wsys wapp} {
    
    if {$indSel == ""} {
	return
    }
    set fntName [$wsys get $indSel]
    
    # Check that it is not there already.
    set allFntApp [$wapp get 0 end]
    if {[lsearch $allFntApp $fntName] >= 0} {
	return
    }
    $wapp insert end $fntName	
}
    
proc ::Preferences::EditFonts::PushBtRemove {indSel wapp} {
    
    if {$indSel == ""} {
	return
    }
    set fntName [$wapp get $indSel]
    
    # Check that not the standard fonts are removed.
    if {[lsearch {Times Helvetica Courier} $fntName] >= 0} {
	tk_messageBox -message [FormatTextForMessageBox  \
	  [::msgcat::mcset en messrmstandardfonts]] \
	  -icon error -type ok
	return
    }
    $wapp delete $indSel	
}
    
proc ::Preferences::EditFonts::PushBtSave { } {
    global  prefs
    
    variable wlbwb

    # Do save.
    set prefs(canvasFonts) [$wlbwb get 0 end]
    ::WB::BuildAllFontMenus $prefs(canvasFonts)
}
    
proc ::Preferences::EditFonts::PushBtStandard {wapp} {
    
    # Insert the three standard fonts.
    $wapp delete 0 end
    eval $wapp insert 0 {Times Helvetica Courier}
}


# namespace  ::Preferences::Proxies:: ----------------------------------------
# 
#       This is supposed to provide proxy support etc. 

namespace eval ::Preferences::Proxies:: {
    
}

proc ::Preferences::Proxies::BuildPage {page} {
    
    upvar ::Preferences::ypad ypad
    
    set pcnat [::mylabelframe::mylabelframe $page.nat {NAT Address}]
    pack $page.nat -side top -anchor w -ipadx 10 -ipady 6
    checkbutton $pcnat.cb \
      -text {  Use the following ip address as seen from the outside} \
      -variable [namespace current]::tmpPrefs(setNATip)
    entry $pcnat.eip -textvariable [namespace current]::tmpPrefs(NATip) \
      -width 32
    grid $pcnat.cb -sticky w -pady $ypad
    grid $pcnat.eip -sticky ew -pady $ypad
    
    set pca [::mylabelframe::mylabelframe $page.fr {Proxies}]
    pack $page.fr -side top -anchor w -ipadx 10 -ipady 6
    label $pca.la -text {No firewall support... yet}
    grid $pca.la -sticky w
}

#-------------------------------------------------------------------------------

proc ::Preferences::BuildPageCache {page} {
    
    variable ypad
    
    set pca [::mylabelframe::mylabelframe $page.fr [::msgcat::mc {File Cache}]]
    pack $page.fr -side left -anchor n -ipadx 10 -ipady 6
    label $pca.la -text [::msgcat::mc prefcahow]
    radiobutton $pca.never    \
      -variable [namespace current]::tmpPrefs(checkCache) -value never \
      -text [::msgcat::mc prefcanev]
    radiobutton $pca.always    \
      -variable [namespace current]::tmpPrefs(checkCache) -value always \
      -text [::msgcat::mc prefcaalw]
    label $pca.la2 -text "     [::msgcat::mc prefcaor]"
    grid $pca.la -sticky w
    grid $pca.never -sticky w -pady $ypad
    grid $pca.always -sticky w -pady $ypad
    grid $pca.la2 -sticky w

    foreach val {launch hour day week month}   \
      txt {{Launch time} {One hour} {One day} {One week} {One month}} {
	radiobutton $pca.$val -text [::msgcat::mc $txt]   \
	  -variable [namespace current]::tmpPrefs(checkCache) -value $val
	grid $pca.$val -sticky w -pady $ypad
    }
}

# Preferences::SavePushBt --
#
#       Saving all settings of panels to the applications state and
#       its preference file.

proc ::Preferences::SavePushBt { } {
    global  prefs
    
    variable finished
    variable tmpPrefs
    variable tmpJPrefs
    variable tmpJServer
    
    set protocolSet 0
    
    # Was protocol changed?
    if {![string equal $prefs(protocol) $tmpPrefs(protocol)]} {
	set ans [tk_messageBox -title Relaunch -icon info -type yesno \
	  -message [FormatTextForMessageBox [::msgcat::mc messprotocolch]]]
	if {$ans == "no"} {
	    set finished 1
	    return
	} else {
	    set protocolSet 1
	}
    }
        
    # Make all temporary prefs reflect the current settings of the panels.
    if {!$prefs(stripJabber)} {
	::Preferences::Profiles::UpdateTmpJServerProfile
	if {!$protocolSet} {
	    ::Jabber::Roster::SetBackgroundImage $tmpJPrefs(rost,useBgImage) \
	      $tmpJPrefs(rost,bgImagePath)
	}
    }
    
    # Copy the temporary copy to the real variables.
    array set prefs [array get tmpPrefs]
    ::Jabber::SetjprefsArray [array get tmpJPrefs]
    ::Jabber::SetjserverArray [array get tmpJServer]
    
    # and the same for all MIME stuff etc.
    ::Preferences::FileMap::SaveAssociations    
    ::Preferences::EditFonts::PushBtSave
    #::Preferences::NetSetup::UpdateUI
    
    if {!$prefs(stripJabber)} {
	
	# If changed present auto away settings, may need to reconfigure.
	::Jabber::UpdateAutoAwaySettings    
	::Jabber::Chat::SetFont $tmpJPrefs(chatFont)
    }
    
    # Reset file cache doesn't hurt.
    ::FileCache::SetBestBefore $prefs(checkCache) $prefs(incomingPath)
    
    ::Preferences::Plugins::Save
    
    # Save the preference file.
    ::PreferencesUtils::SaveToFile
    
    set finished 1
}
    
# Preferences::CancelPushBt --
#
#       User presses the cancel button. Warn if anything changed.

proc ::Preferences::CancelPushBt { } {
    global  prefs
    
    variable wtoplevel
    variable finished
    variable tmpPrefs
    variable tmpJPrefs
    variable tmpJServer
    upvar ::Jabber::jserver jserver
    upvar ::Jabber::jprefs jprefs
    
    # Make all temporary prefs reflect the current settings of the panels.
    if {!$prefs(stripJabber)} {
	::Preferences::Profiles::UpdateTmpJServerProfile
    }
    
    # Check if anything changed, if so then warn.
    set hasChanged 0
    foreach {arrName tmpName} {
	prefs      tmpPrefs 
	jserver    tmpJServer 
	jprefs     tmpJPrefs
    } {
	if {!$hasChanged} {
	    foreach key [array names $arrName] {		
		set locName ${arrName}($key)
		upvar 0 $locName arrVal 
		set locName ${tmpName}($key)
		upvar 0 $locName tmpVal 
		
		if {![info exists $tmpName]} {
		    ::Debug 3 "\tdiff: locName=$locName"
		    set hasChanged 1
		    break
		}
		if {![string equal $arrVal $tmpVal]} {
		    ::Debug 3 "\tdiff: locName=$locName,\n\tarrVal=$arrVal,\n\ttmpVal=$tmpVal"
		    set hasChanged 1
		    break
		}
	    }
	}
    }
    
    # Check all MIME type stuff.
    if {!$hasChanged} {
	set hasChanged [::Preferences::FileMap::IsAnythingChangedQ]
    }
    if {$hasChanged} {
	set ans [tk_messageBox -title [::msgcat::mc Warning]  \
	  -type yesno -default no \
	  -message [FormatTextForMessageBox [::msgcat::mc messprefschanged]]]
	if {$ans == "yes"} {
	    set finished 2
	}
    } else {
	set finished 2
    }
    if {$finished == 2} {
	::UI::SaveWinGeom $wtoplevel
    }
}

# Preferences::SelectCmd --
#
#       Callback when selecting item in tree.
#
# Arguments:
#       w           tree widget
#       v           tree item path
#       
# Results:
#       new page displayed

proc ::Preferences::SelectCmd {w v} {

    variable nbframe

    if {[llength $v] && ([$w itemconfigure $v -dir] == 0)} {
	$nbframe displaypage [lindex $v end]
    }    
}

#-------------------------------------------------------------------------------