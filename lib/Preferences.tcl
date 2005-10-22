#  Preferences.tcl ---
#  
#       This file is part of The Coccinella application. It implements the
#       preferences dialog window.
#      
#  Copyright (c) 1999-2005  Mats Bengtsson
#  
# $Id: Preferences.tcl,v 1.83 2005-10-22 14:26:21 matben Exp $
 
package require mnotebook
package require tree

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
        
    variable wtoplevel
    variable wtree
    variable finished
    variable nbframe
    variable lastPage
    variable tableName2Item
    
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
        
    set wtree $frtree.t
    set wysc  $frtree.sby
    set T $wtree
    TreeCtrl $wtree $wysc
    tuscrollbar $wysc -orient vertical -command [list $wtree yview]
    
    pack $wtree -side left -fill both -expand 1
    pack $wysc  -side right -fill y
    
    # Fill tree.
    set item [$T item create -button 1]
    $T item style set $item cTree styText cTag styText
    $T item text $item cTree [mc General] cTag [list General]
    $T item lastchild root $item

    set tableName2Item(General) $item
    
    set item [$T item create -button 1]
    $T item style set $item cTree styText cTag styText
    $T item text $item cTree [mc Jabber] cTag [list Jabber]
    $T item lastchild root $item

    set tableName2Item(Jabber) $item
    
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
	set selectPage $argsArr(-page)
    } elseif {$lastPage ne ""} {
	set selectPage $lastPage
    } else {
	set selectPage {General}
    }
    if {[info exists tableName2Item($selectPage)]} {
	$T selection add $tableName2Item($selectPage)
    }
    
    wm deiconify $w
    
    # Grab and focus.
    focus $w
}

proc ::Preferences::TreeCtrl {T wysc} {
    global  this
    
    treectrl $T -usetheme 1 -selectmode single  \
      -showroot 0 -showrootbutton 0 -showbuttons 1  \
      -yscrollcommand [list ::UI::ScrollSet $wysc \
      [list pack $wysc -side right -fill y]]  \
      -borderwidth 0 -highlightthickness 0 -indent 0 -width 140

    # This is a dummy option.
    set stripeBackground [option get $T stripeBackground {}]
    set stripes [list $stripeBackground {}]
    set bd [option get $T columnBorderWidth {}]

    $T column create -text [mc {Settings Panels}] -tag cTree  \
      -itembackground $stripes -resize 0 -expand 1 -borderwidth $bd
    $T column create -tag cTag -visible 0
    $T configure -treecolumn cTree

    set fill [list $this(sysHighlight) {selected focus} gray {selected !focus}]
    $T element create eText text -lines 1
    $T element create eSelect rect -fill $fill -open e -showfocus 1

    set S [$T style create styText]
    $T style elements $S {eSelect eText}
    $T style layout $S eText -padx 4 -squeeze x -expand ns -ipady 2
    $T style layout $S eSelect -union {eText} -iexpand nes -ipadx {2 0}

    $T notify bind $T <Selection> [list [namespace current]::Selection %T]
}

proc ::Preferences::NewTableItem {spec name} {
    variable wtree
    variable tableName2Item
    
    set T $wtree
    
    set item [$T item create]
    $T item style set $item cTree styText cTag styText
    $T item text $item cTree $name cTag $spec

    set n [llength $spec]
    if {$n == 1} {
	$T item configure $item -button 1
	$T item lastchild root $item
    } else {
	set root [lindex $spec 0]
	set ritem $tableName2Item($root)
	$T item lastchild $ritem $item
    }
    set tableName2Item($spec) $item
    
    return $item
}

proc ::Preferences::GetTableItem {name} {
    variable tableName2Item

    return $tableName2Item($name)
}

proc ::Preferences::HaveTableItem {name} {
    variable tableName2Item

    if {[info exists tableName2Item($name)]} {
	return 1
    } else {
	return 0
    }
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

# Preferences::SavePushBt --
#
#       Saving all settings of panels to the applications state and
#       its preference file.

proc ::Preferences::SavePushBt { } {
    global  prefs wDlgs
    
    variable wtoplevel
    variable finished
    variable needRestart
    variable stopSave

    set needRestart 0
    
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
    variable changed
    
    set ans yes
    set changed 0
        
    # Check if anything changed, if so then warn.
    # Let the code components check for themselves.
    ::hooks::run prefsCancelHook
    
    if {$changed} {
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
    variable tableName2Item
    
    # Which page to be in front next time?
    set T $wtree
    set item [$T selection get]
    if {[llength $item] == 1} {
	set lastPage [$T item element cget $item cTag eText -text]
    }
    ::UI::SaveWinGeom $wtoplevel
    unset -nocomplain tableName2Item
}

# Preferences::HasChanged --
# 
#       Used for components to tell us that something changed with their
#       internal preferences.

proc ::Preferences::HasChanged { } {
    variable changed

    set changed 1
}

proc ::Preferences::NeedRestart { } {
    variable needRestart

    set needRestart 1
}

proc ::Preferences::Selection {T} {
    variable nbframe

    if {[$T selection count] != 1} {
	return
    }
    set item [$T selection get]
    set tag  [$T item element cget $item cTag eText -text]
    set page [lindex $tag end]
    
    if {[$nbframe exists $page]} {
	$nbframe displaypage $page
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