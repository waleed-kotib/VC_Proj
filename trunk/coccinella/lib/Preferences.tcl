#  Preferences.tcl ---
#  
#       This file is part of The Coccinella application. It implements the
#       preferences dialog window.
#      
#  Copyright (c) 1999-2007  Mats Bengtsson
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
# $Id: Preferences.tcl,v 1.97 2007-08-21 14:12:20 matben Exp $
 
package require mnotebook

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
    option add *Preferences*TCombobox.style     Small.TCombobox     widgetDefault
    option add *Preferences*TCombobox.font      CociSmallFont       widgetDefault
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
    if {$page ne ""} {
	$wtree selection clear all
	$wtree selection add [list $page]
    }
}

proc ::Preferences::Build {args} {
    global  this prefs wDlgs
        
    variable wtoplevel
    variable wtree
    variable finished
    variable nbframe
    variable lastPage
    
    array set argsA $args

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
    
    # Padding to avoid resizing.
    pack [frame $frtree.pad -width 150 -height 0] -side top
        
    set wtree $frtree.t
    set wysc  $frtree.sby
    set T $wtree
    TreeCtrl $wtree $wysc
    ttk::scrollbar $wysc -orient vertical -command [list $wtree yview]
    
    pack $wtree -side left -fill both -expand 1
    pack $wysc  -side right -fill y
    
    # Fill tree.
    set item [$T item create -button 1 -tags [list {General}]]
    $T item style set $item cTree styText
    $T item text $item cTree [mc General]
    $T item lastchild root $item

    set item [$T item create -button 1 -tags [list {Jabber}]]
    $T item style set $item cTree styText
    $T item text $item cTree [mc Jabber]
    $T item lastchild root $item

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
    if {[info exists argsA(-page)]} {
	set selectPage $argsA(-page)
    } elseif {$lastPage ne ""} {
	set selectPage $lastPage
    } else {
	set selectPage {General}
    }
    set item [$T item id [list $selectPage]]
    if {[llength $item]} {
	$T selection add $item
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
    set itemBackground [option get $T itemBackground {}]
    set bd [option get $T columnBorderWidth {}]
    set bg [option get $T columnBackground {}]
    set fillT {white {selected focus} black {selected !focus}}

     $T column create -text [mc {Settings Panels}] -tags cTree  \
      -itembackground $itemBackground -resize 0 -expand 1 -borderwidth $bd  \
      -background $bg
     $T configure -treecolumn cTree

    set fill [list $this(sysHighlight) {selected focus} gray {selected !focus}]
    $T element create eText text -lines 1 -fill $fillT
    $T element create eBorder rect -open new -outline gray -outlinewidth 1 \
      -fill $fill -showfocus 1

    set S [$T style create styText]
    $T style elements $S {eBorder eText}
    $T style layout $S eText -padx 4 -squeeze x -expand ns -ipady 2
    $T style layout $S eBorder -detach yes -iexpand xy -indent 0

    $T notify bind $T <Selection>  [list [namespace current]::Selection %T]
}

proc ::Preferences::NewTableItem {name text} {
    variable wtree
        
    set T $wtree
    
    set item [$T item create -tags [list $name]]
    $T item style set $item cTree styText
    $T item text $item cTree $text

    set n [llength $name]
    if {$n == 1} {
	$T item configure $item -button 1
	$T item lastchild root $item
    } else {
	set root [lindex $name 0]
	set ritem [$T item id [list $root]]
	$T item lastchild $ritem $item
    }
    return $item
}

proc ::Preferences::HaveTableItem {name} {
    variable wtree
    return [llength [$wtree item id [list $name]]]
}

# Preferences::Selection --
#
#       Callback when selecting item in tree.
#
# Arguments:
#       T           tree widget
#       
# Results:
#       new page displayed

proc ::Preferences::Selection {T} {
    variable nbframe

    if {[$T selection count] != 1} {
	return
    }
    set item [$T selection get]    
    set tag [lindex [$T item tag names $item] 0]
    set page [lindex $tag end]
    if {[$nbframe exists $page]} {
	$nbframe displaypage $page
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
    variable lastPage
    
    # Which page to be in front next time?
    set T $wtree
    set item [$T selection get]
    if {[llength $item] == 1} {
	set lastPage [lindex [$T item tag names $item] 0]
    }
    ::UI::SaveWinGeom $wtoplevel
}

# Preferences::HasChanged --
# 
#       Used for components to tell us that something changed with their
#       internal preferences.
#       
#       @@@ We could add an option text explaining what was changed.

proc ::Preferences::HasChanged { } {
    variable changed

    set changed 1
}

proc ::Preferences::NeedRestart { } {
    variable needRestart

    set needRestart 1
}

#-------------------------------------------------------------------------------