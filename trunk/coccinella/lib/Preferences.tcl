#  Preferences.tcl ---
#  
#       This file is part of The Coccinella application. It implements the
#       preferences dialog window.
#      
#  Copyright (c) 1999-2005  Mats Bengtsson
#  
# $Id: Preferences.tcl,v 1.80 2005-09-20 14:09:51 matben Exp $
 
package require mnotebook
package require tree
package require tablelist
package require combobox

package provide Preferences 1.0

namespace eval ::Preferences:: {
    global  this
    
    # Variable to be used in tkwait.
    variable finished
        
    # Name of the page that was in front last time.
    variable lastPage {}

    # Add all event hooks.
    ::hooks::register quitAppHook     ::Preferences::QuitAppHook


    option add *Preferences*Menu.font           CociSmallFont       widgetDefault

    option add *Preferences*TLabel.style        Small.TLabel        widgetDefault
    option add *Preferences*TLabelframe.style   Small.TLabelframe   widgetDefault
    option add *Preferences*TButton.style       Small.TButton       widgetDefault
    option add *Preferences*TMenubutton.style   Small.TMenubutton   widgetDefault
    option add *Preferences*TRadiobutton.style  Small.TRadiobutton  widgetDefault
    option add *Preferences*TCheckbutton.style  Small.TCheckbutton  widgetDefault
    option add *Preferences*TEntry.style        Small.TEntry        widgetDefault
    option add *Preferences*TEntry.font         CociSmallFont       widgetDefault
    #option add *Preferences*TScale.style        Small.TScale        widgetDefault
    
}

# Preferences::SetMiscPrefs --
#
#       Set defaults in the option database for widget classes.
#       Set the user preferences from the preferences file if they are there,
#       else take the hardcoded defaults.
#       'prefsList': a list of lists where each sublist defines an item in the
#       following way:  
#       
#         {theVarName itsResourceName itsHardCodedDefaultValue {priority 20}}.
#         
# Note: it may prove useful to have the versions numbers as the first elements!

proc ::Preferences::SetMiscPrefs { } {
    global  prefs this
    
    ::Debug 2 "::Preferences::SetMiscPrefs"
    
    ::PrefUtils::Add [list  \
      [list prefs(remotePort)      prefs_remotePort      $prefs(remotePort)]     \
      [list prefs(postscriptOpts)  prefs_postscriptOpts  $prefs(postscriptOpts)] \
      [list prefs(firstLaunch)     prefs_firstLaunch     $prefs(firstLaunch)     userDefault] \
      [list prefs(unixPrintCmd)    prefs_unixPrintCmd    $prefs(unixPrintCmd)]   \
      [list prefs(webBrowser)      prefs_webBrowser      $prefs(webBrowser)]     \
      [list prefs(userPath)        prefs_userPath        $prefs(userPath)]       \
      [list prefs(winGeom)         prefs_winGeom         $prefs(winGeom)]        \
      [list prefs(paneGeom)        prefs_paneGeom        $prefs(paneGeom)]       \
      [list prefs(sashPos)         prefs_sashPos         $prefs(sashPos)]        \
      ]
		
    set prefs(wasFirstLaunch) 0
    if {$prefs(firstLaunch)} {
	set prefs(wasFirstLaunch) 1
    }    
    # Map list of win geoms into an array.
    foreach {win geom} $prefs(winGeom) {
	set prefs(winGeom,$win) $geom
    }
    foreach {win pos} $prefs(paneGeom) {
	set prefs(paneGeom,$win) $pos
    }
    foreach {win pos} $prefs(sashPos) {
	set prefs(sashPos,$win) $pos
    }
    
    # This is used only to track upgrades.
    ::PrefUtils::AddMustSave [list  \
      [list this(vers,previous)    this_previousVers     $this(vers,previous)    userDefault] \
      ]
    
    set this(vers,old)      $this(vers,previous)
    set this(vers,previous) $this(vers,full)
}

proc ::Preferences::Upgraded { } {
    global  this
    
    set vcomp [package vcompare $this(vers,old) $this(vers,full)]
    return [expr {$vcomp < 0 ? 1 : 0}]
}

proc ::Preferences::UpgradedFromVersion {version} {
    global  this
    
    if {[Upgraded] && [package vcompare $version $this(vers,old)] <= 0} {
	return 1
    } else {
	return 0
    }
}

proc ::Preferences::FirstLaunch { } {
    global  prefs
    
    return $prefs(wasFirstLaunch)
}

proc ::Preferences::QuitAppHook { } {
    global  wDlgs

    ::UI::SaveWinGeom $wDlgs(prefs)
}

proc ::Preferences::Show {{page {}}} {
    global  wDlgs
    variable wtree
    
    set w $wDlgs(prefs)
    if {[winfo exists $w]} {
	raise $w
    } else {
	Build
    }
    if {[string length $page]} {
	$wtree setselection $page
    }
}

proc ::Preferences::Build {args} {
    global  this prefs wDlgs
    
    variable tmpPrefs
    variable tmpJPrefs
    
    variable wtoplevel
    variable wtree
    variable finished
    variable nbframe
    variable lastPage
    
    array set argsArr $args

    set w $wDlgs(prefs)
    if {[winfo exists $w]} {
	raise $w
	return
    }
    ::UI::Toplevel $w -class Preferences \
      -usemacmainmenu 1 -macstyle documentProc -macclass {document closeBox} \
      -closecommand ::Preferences::CloseHook
    wm title $w [mc Preferences]
    wm withdraw $w
    ::UI::SetWindowPosition $w
    
    set finished 0
    set wtoplevel $w
        
    # Work only on a temporary copy in case we cancel.
    unset -nocomplain tmpPrefs tmpJPrefs
    array set tmpPrefs [array get prefs]
    array set tmpJPrefs [::Jabber::GetjprefsArray]
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    # Frame for everything except the buttons.
    set wcont $wbox.f
    ttk::frame $wcont
    pack $wcont -fill both -expand 1 -side top
    
    # Tree frame with scrollbars.
    frame $wcont.t -relief sunken -bd 1
    pack  $wcont.t -fill y -side left -padx 4 -pady 4
    set frtree $wcont.t.frtree
    frame $frtree
    pack  $frtree -fill both -expand 1 -side left
    
    # Set a width in the label to act as a spacer when scrollbar is unpacked.
    frame $frtree.fl -relief raised -bd 1
    ttk::label $frtree.fl.l -text [mc {Settings Panels}] -width 24
    pack $frtree.fl -side top -fill x
    pack $frtree.fl.l
    
    set wtree $frtree.t
    ::tree::tree $wtree -width 100 -height 300 -indention 0 \
      -yscrollcommand [list ::UI::ScrollSet $frtree.sby \
      [list pack $frtree.sby -side right -fill y]]  \
      -selectcommand ::Preferences::SelectCmd   \
      -doubleclickcommand {} \
      -showrootbutton 1 -indention 0 -xmargin 6
    #  -showrootbutton 1 -indention {0 10} -xmargin {0 8}
    tuscrollbar $frtree.sby -orient vertical -command [list $wtree yview]
    
    pack $wtree -side left -fill both -expand 1
    pack $frtree.sby -side right -fill y
    
    # Fill tree.
    $wtree newitem {General} -text [mc General]
    $wtree newitem {Jabber}
    
    # The notebook and its pages.
    set nbframe [::mnotebook::mnotebook $wcont.nb -borderwidth 1 -relief sunken]
    pack $nbframe -expand 1 -fill both -padx 4 -pady 4
    
    # Make the notebook pages.    
    # Each code component makes its own page.
    ::hooks::run prefsBuildHook $wtree $nbframe
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -style TButton \
      -text [mc Save] -default active \
      -command ::Preferences::SavePushBt
    ttk::button $frbot.btcancel -style TButton \
      -text [mc Cancel]  \
      -command ::Preferences::Cancel
    ttk::button $frbot.btfactory -style TButton \
      -text [mc {Factory Settings}]   \
      -command [list ::Preferences::ResetToFactoryDefaults "40"]
    ttk::button $frbot.btrevert -style TButton \
      -text [mc {Revert Panel}]  \
      -command ::Preferences::ResetToUserDefaults
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok     -side right -fill y
	pack $frbot.btcancel -side right -fill y -padx $padx
    } else {
	pack $frbot.btcancel -side right -fill y
	pack $frbot.btok     -side right -fill y -padx $padx
    }
    pack $frbot.btfactory -side left -fill y
    pack $frbot.btrevert  -side left -fill y -padx $padx
    pack $frbot -side top -fill x

    wm resizable $w 0 0
    bind $w <Return> {}
    
    # Which page to be in front?
    if {[info exists argsArr(-page)]} {
	$wtree setselection $argsArr(-page)
    } elseif {[llength $lastPage]} {
	$wtree setselection $lastPage
    }    
    wm deiconify $w
    
    # Grab and focus.
    focus $w
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

    Debug 2 "::Preferences::ResetToFactoryDefaults maxPriorityNum=$maxPriorityNum"
    
    # Warn first.
    set ans [::UI::MessageBox -title [mc Warning] -type yesno -icon warning \
      -message [mc messfactorydefaults] -default no]
    if {$ans eq "no"} {
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
}

# Preferences::ResetToUserDefaults --
#
#       Revert panels to the state when dialog showed.

proc ::Preferences::ResetToUserDefaults { } {
    
    # Run hook for the components.
    ::hooks::run prefsUserDefaultsHook
}

# namespace  ::Preferences::Net:: -----------------------------------------

namespace eval ::Preferences::Net:: {

    ::hooks::register prefsInitHook          ::Preferences::Net::InitPrefsHook  20
    ::hooks::register prefsBuildHook         ::Preferences::Net::BuildPrefsHook 20
    ::hooks::register prefsSaveHook          ::Preferences::Net::SavePrefsHook  20
    ::hooks::register prefsCancelHook        ::Preferences::Net::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::Preferences::Net::UserDefaultsHook
    ::hooks::register prefsDestroyHook       ::Preferences::Net::DestroyPrefsHook

    variable opts
    set opts(main) {protocol autoConnect multiConnect}
    set opts(adv)  {thisServPort httpdPort}
    set opts(all)  [concat $opts(main) $opts(adv)]
}

proc ::Preferences::Net::InitPrefsHook { } {
    global  prefs
    
    # Connect automatically to connecting clients if 'symmetricNet'.
    set prefs(autoConnect) 1                
    
    # Disconnect automatically to disconnecting clients.
    set prefs(autoDisconnect) $prefs(autoConnect)	
    
    # When connecting to other client, connect automatically to all *its* clients.
    set prefs(multiConnect) 1
    
    ::PrefUtils::Add [list  \
      [list prefs(protocol)        prefs_protocol        $prefs(protocol)]       \
      [list prefs(autoConnect)     prefs_autoConnect     $prefs(autoConnect)]    \
      [list prefs(multiConnect)    prefs_multiConnect    $prefs(multiConnect)]   \
      [list prefs(thisServPort)    prefs_thisServPort    $prefs(thisServPort)]   \
      [list prefs(httpdPort)       prefs_httpdPort       $prefs(httpdPort)]      \
      ]    
}

proc ::Preferences::Net::BuildPrefsHook {wtree nbframe} {
    
    $wtree newitem {General {Network Setup}} -text [mc {Network Setup}]
    set wpage [$nbframe page {Network Setup}]
    ::Preferences::Net::BuildPage $wpage
}

proc ::Preferences::Net::SavePrefsHook { } {
    global prefs wDlgs
    variable tmpPrefs
    
    set protocolSet 0
        
    # Was protocol changed?
    if {![string equal $prefs(protocol) $tmpPrefs(protocol)]} {	
	set ans [::UI::MessageBox -title Relaunch -icon info -type yesno \
	  -message [mc messprotocolch] -parent $wDlgs(prefs)]
	if {$ans eq "no"} {
	    set finished 1
	    return stop
	} else {
	    set protocolSet 1
	}
    }
    
    if {$protocolSet} {

	switch -- $tmpPrefs(protocol) {
	    jabber {
		package require Jabber
	    }
	    symmetric - server - client {
		package require P2P
		package require P2PNet
	    }
	}
    }
    
    array set prefs [array get tmpPrefs]
}

proc ::Preferences::Net::CancelPrefsHook { } {
    global prefs
    variable tmpPrefs
	
    foreach key [array names tmpPrefs] {
	if {![string equal $prefs($key) $tmpPrefs($key)]} {
	    ::Preferences::HasChanged
	    break
	}
    }
}

proc ::Preferences::Net::UserDefaultsHook { } {
    global prefs
    variable tmpPrefs
    
    foreach key [array names tmpPrefs] {
	set tmpPrefs($key) $prefs($key)
    }
}

proc ::Preferences::Net::DestroyPrefsHook { } {
    variable tmpPrefs
    
    unset -nocomplain tmpPrefs
}
    
proc ::Preferences::Net::BuildPage {page} {
    global  prefs this state

    variable wfr
    variable tmpPrefs
    variable tmpAdvPrefs
    variable opts
    
    foreach key $opts(main) {
	set tmpPrefs($key) $prefs($key)
    }
    foreach key $opts(adv) {
	set tmpAdvPrefs($key) $prefs($key)
    }
    
    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    set wfr $wc.f
    ttk::labelframe $wfr -text [mc prefnetconf] \
      -padding [option get . groupSmallPadding {}]

    ttk::label $wfr.msg -wraplength 200 -justify left \
      -padding {0 0 0 8} -text [mc prefnethead]
    pack $wfr.msg -side top
            
    # The Jabber server.
    ttk::radiobutton $wfr.jabb -text [mc {Jabber Client}]  \
      -value jabber -variable [namespace current]::tmpPrefs(protocol)
    ttk::label $wfr.jabbmsg -wraplength 200 -justify left  \
      -text [mc prefnetjabb]
    
    # For the symmetric network config.
    ttk::radiobutton $wfr.symm -text [mc {Peer-to-Peer}]  \
      -variable [namespace current]::tmpPrefs(protocol) -value symmetric
    ttk::checkbutton $wfr.auto -text [mc {Auto Connect}]  \
      -variable [namespace current]::tmpPrefs(autoConnect)
    ttk::label $wfr.automsg -wraplength 200 -justify left  \
      -text [mc prefnetauto]
    ttk::checkbutton $wfr.multi -text [mc {Multi Connect}]  \
      -variable [namespace current]::tmpPrefs(multiConnect)
    ttk::label $wfr.multimsg -wraplength 200 -justify left  \
      -text [mc prefnetmulti]
    ttk::button $wfr.adv -text "[mc Advanced]..." \
      -command [list ::Preferences::Net::Advanced]
    
    grid  $wfr.msg    -              -sticky w
    grid  $wfr.jabb   $wfr.jabbmsg   -sticky nw
    grid  $wfr.symm   $wfr.auto      -sticky w
    grid  x           $wfr.automsg   -sticky w
    grid  x           $wfr.multi     -sticky w
    grid  x           $wfr.multimsg  -sticky w
    grid  $wfr.adv    -              -sticky w
    
    pack  $wfr  -fill x

    if {![string equal $prefs(protocol) "symmetric"]} { 
	$wfr.auto  state {disabled}
	$wfr.multi state {disabled}
    }    

    # If already connected don't allow network topology to be changed.
    
    switch -- $prefs(protocol) {
	jabber {
	    set connected [::Jabber::IsConnected]
	}
	default {
	    set connected [llength [::P2PNet::GetIP to]]
	}
    }
    if {$connected} {
	$wfr.jabb state {disabled}
	$wfr.symm state {disabled}
    }
    if {($prefs(protocol) eq "server") || ($prefs(protocol) eq "client")} {
	$wfr.jabb state {disabled}
	$wfr.symm state {disabled}
    }
    
    trace variable [namespace current]::tmpPrefs(protocol) w  \
      [namespace current]::TraceNetConfig
	
    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $wfr.msg $page]    
    after idle $script
}

# ::Preferences::Net::TraceNetConfig --
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

proc ::Preferences::Net::TraceNetConfig {name index op} {
    
    variable wfr
    variable tmpPrefs
    
    Debug 2 "::Preferences::Net::TraceNetConfig"

    switch -- $tmpPrefs(protocol) {
	symmetric {
	    $wfr.auto  state {!disabled}
	    $wfr.multi state {!disabled}
	}
	central {
	    $wfr.auto  state {disabled}
	    $wfr.multi state {disabled}
	}
	jabber {
	    $wfr.auto  state {disabled}
	    $wfr.multi state {disabled}
	}
    }
}

# ::Preferences::Net::UpdateUI --
#
#       If network setup changed be sure to update the UI to reflect this.
#       Must be called after saving in 'prefs' etc.
#       
# Arguments:
#       
# Results:
#       .

proc ::Preferences::Net::UpdateUI { } {
    global  prefs state wDlgs
    
    Debug 2 "::Preferences::Net::UpdateUI"
    
    set wmenu [::UI::GetMainMenu]
    
    # Update menus.
    switch -- $prefs(protocol) {
	jabber {
	    
	    # Show our combination window.
	    ::Jabber::UI::Show $wDlgs(jmain)
	}
	central {
	    
	    # We are only a client.
	    ::UI::MenuMethod $wmenu.file entryconfigure mOpenConnection  \
	      -command [list ::P2PNet::OpenConnection $wDlgs(openConn)]
	    $wmenu entryconfigure *Jabber* -state disabled
	    
	    # Hide our combination window.
	    ::Jabber::UI::Close $wDlgs(jmain)
	}
	default {
	    ::UI::MenuMethod $wmenu.file entryconfigure mOpenConnection   \
	      -command [list ::P2PNet::OpenConnection $wDlgs(openConn)]
	    $wmenu entryconfigure *Jabber* -state disabled
		
	    # Hide our combination window.
	    ::Jabber::UI::Close $wDlgs(jmain)
	}
    }
    
    # Other UI updates needed.
    foreach w [::WB::GetAllWhiteboards] {
	# ???
    }
}

# Preferences::Net::Advanced --
#
#       Shows dialog for setting the "advanced" network options.
#       
# Arguments:
#       
# Results:
#       shows dialog.

proc ::Preferences::Net::Advanced {  } {
    global  this prefs

    variable finishedAdv -1
    
    set w .dlgAdvNet
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm title $w [mc {Advanced Setup}]
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1
    
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 320 -justify left -text [mc prefnetadv]
    pack $wbox.msg -side top -anchor w
    
    # The actual options.
    set frmid $wbox.frmid
    ttk::frame $frmid
    pack $frmid -side top -fill both -expand 1

    ttk::label $frmid.lserv -text "[mc {Built in server port}]:"
    ttk::label $frmid.lhttp -text "[mc {HTTP port}]:"
    ttk::entry $frmid.eserv -width 6 -textvariable  \
      [namespace current]::tmpAdvPrefs(thisServPort)
    ttk::entry $frmid.ehttp -width 6 -textvariable  \
      [namespace current]::tmpAdvPrefs(httpdPort)

    grid  $frmid.lserv  $frmid.eserv  -sticky e -pady 2
    grid  $frmid.lhttp  $frmid.ehttp  -sticky e -pady 2
    
    if {!$prefs(haveHttpd)} {
	$frmid.ehttp state {disabled}
    }
    
    # Button part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Save] -default active \
      -command [namespace current]::AdvSetupSave
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list set [namespace current]::finishedAdv 0]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side top -fill x

    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    
    # Grab and focus.
    focus $w
    catch {grab $w}    
    tkwait variable [namespace current]::finishedAdv
    
    # Clean up.
    unset -nocomplain finishedAdv
    catch {grab release $w}
    destroy $w
}
    
# ::Preferences::Net::AdvSetupSave --
#
#       Saves the values set in dialog in the preference variables.
#       It saves these port numbers independently of the main panel!!!
#       Is this the right thing to do???
#       
# Arguments:
#       
# Results:
#       none.

proc ::Preferences::Net::AdvSetupSave {  } {
    global  prefs
    
    variable finishedAdv
    variable tmpAdvPrefs
    variable opts

    foreach key $opts(adv) {
	set prefs($key) $tmpAdvPrefs($key)
    }
    set finishedAdv 1
}

#-------------------------------------------------------------------------------

# Preferences::SavePushBt --
#
#       Saving all settings of panels to the applications state and
#       its preference file.

proc ::Preferences::SavePushBt { } {
    global  prefs wDlgs
    
    variable wtoplevel
    variable finished
    variable tmpPrefs
    variable tmpJPrefs
    variable needRestart
    variable stopSave

    set needRestart 0
    
    # Copy the temporary copy to the real variables.
    array set prefs [array get tmpPrefs]
    ::Jabber::SetjprefsArray [array get tmpJPrefs]
    
    # Let components store themselves.
    set ans [::hooks::run prefsSaveHook]    
    if {$ans eq "stop"} {
	return
    }

    if {$needRestart} {
	set ans [::UI::MessageBox -title [mc Warning]  \
	  -type ok -parent $wDlgs(prefs) -icon info \
	  -message [mc messprefsrestart]]
    }

    # Save the preference file.
    ::PrefUtils::SaveToFile
    CleanUp
    
    set finished 1
    destroy $wtoplevel
    ::hooks::run prefsDestroyHook
}

proc ::Preferences::CloseHook {wclose} {
    
    set result ""
    set ans [Cancel]
    if {$ans eq "no"} {
	set result stop
    }   
    return $result
}

# Preferences::Cancel --
#
#       User presses the cancel button. Warn if anything changed.

proc ::Preferences::Cancel { } {
    global  prefs wDlgs
    
    variable wtoplevel
    variable finished
    variable tmpPrefs
    variable tmpJPrefs
    variable hasChanged
    upvar ::Jabber::jprefs jprefs
    
    set ans yes
        
    # Check if anything changed, if so then warn.
    set hasChanged 0
    foreach {arrName tmpName} {
	prefs      tmpPrefs 
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

    # Let the code components check for themselves.
    ::hooks::run prefsCancelHook
    
    if {$hasChanged} {
	set ans [::UI::MessageBox -title [mc Warning]  \
	  -type yesno -default no -parent $wDlgs(prefs) -icon warning \
	  -message [mc messprefschanged]]
	if {$ans eq "yes"} {
	    set finished 2
	}
    } else {
	set finished 2
    }
    if {$finished == 2} {
	CleanUp
	destroy $wtoplevel
	::hooks::run prefsDestroyHook
    }
    return $ans
}

proc ::Preferences::CleanUp { } {
    variable wtoplevel
    variable wtree
    variable lastPage
    variable tmpPrefs
    
    # Which page to be in front next time?
    set lastPage [$wtree getselection]
    
    # Clean up.
    trace vdelete ::Preferences::tmpPrefs(protocol) w  \
      ::Preferences::Net::TraceNetConfig

    ::UI::SaveWinGeom $wtoplevel
}

# Preferences::HasChanged --
# 
#       Used for components to tell us that something changed with their
#       internal preferences.

proc ::Preferences::HasChanged { } {
    variable hasChanged

    set hasChanged 1
}

proc ::Preferences::NeedRestart { } {
    variable needRestart

    set needRestart 1
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
	#$nbframe displaypage [lindex $v end]
    }    
    if {[llength $v]} {
	set page [lindex $v end]
	if {[$nbframe exists $page]} {
	    $nbframe displaypage $page
	}
    }    
}

#-------------------------------------------------------------------------------