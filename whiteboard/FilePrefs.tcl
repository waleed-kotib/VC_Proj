#  FilePrefs.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements preference settings for whiteboard file importer.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: FilePrefs.tcl,v 1.5 2004-11-06 08:15:26 matben Exp $

package provide FilePrefs 1.0


namespace eval ::FilePrefs:: {

    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          ::FilePrefs::InitPrefsHook
    ::hooks::register prefsBuildHook         ::FilePrefs::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::FilePrefs::SavePrefsHook
    ::hooks::register prefsCancelHook        ::FilePrefs::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::FilePrefs::UserDefaultsHook
    
    # Wait for this variable to be set in the "Inspect Associations" dialog.
    variable finishedInspect
	
    # Temporary local copy of Mime types to edit.
    variable tmpMime2Description
    variable tmpMimeTypeIsText
    variable tmpMime2SuffixList
    variable tmpMimeTypeDoWhat
    variable tmpPrefMimeType2Package
}

proc ::FilePrefs::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    
    # Defaults... Set in Types and Plugins.

    
    # All MIME type stuff... The problem is that they are all arrays... 
    # Invented the ..._array resource specifier!    
    # We should have used accesor functions and not direct access to internal
    # arrays. Sorry for this.
    # 
    ::PreferencesUtils::Add [list  \
      [list ::Types::mime2Desc     mime2Desc_array         [::Types::GetDescriptionArr]] \
      [list ::Types::mimeIsText    mimeTypeIsText_array    [::Types::GetIsMimeTextArr]]  \
      [list ::Types::mime2SuffList mime2SuffixList_array   [::Types::GetSuffixListArr]]  \
      [list ::Plugins::mimeTypeDoWhat mimeTypeDoWhat_array [::Plugins::GetDoWhatForMimeArr]] ]
}

proc ::FilePrefs::BuildPrefsHook {wtree nbframe} {
    
    if {![$wtree isitem Whiteboard]} {
	$wtree newitem {Whiteboard} -text [mc Whiteboard]
    }
    $wtree newitem {Whiteboard {File Mappings}} -text [mc {File Mappings}]
    
    # File Mappings ------------------------------------------------------------
    set wpage [$nbframe page {File Mappings}]    
    ::FilePrefs::BuildPage $wpage
}

proc ::FilePrefs::BuildPage {page} {
    global  prefs  wDlgs

    variable tmpMime2Description
    variable tmpMimeTypeIsText
    variable tmpMime2SuffixList
    variable tmpMimeTypeDoWhat
    variable tmpPrefMimeType2Package
    variable wmclist

    set xpadbt [option get [winfo toplevel $page] xPadBt {}]
    set fontS  [option get . fontSmall {}]
	
    # Work only on copies of list of MIME types in case user presses the 
    # Cancel button. The MIME type works as a key in our database
    # (arrays) of various features.

    array set tmpMime2Description     [::Types::GetDescriptionArr]
    array set tmpMimeTypeIsText       [::Types::GetIsMimeTextArr]
    array set tmpMime2SuffixList      [::Types::GetSuffixListArr]
    array set tmpMimeTypeDoWhat       [::Plugins::GetDoWhatForMimeArr]
    array set tmpPrefMimeType2Package [::Plugins::GetPreferredPackageArr]
    
    # Frame for everything inside the labeled container.
    set wcont1 $page.frtop
    labelframe $wcont1 -text [mc preffmhelp]
    pack $wcont1 -side top -anchor w -padx 8 -pady 4
    set fr1 [frame $wcont1.fr]
    
    pack $fr1 -side left -padx 16 -pady 10 -fill x
    
    # Make the multi column listbox. 
    # Keep an invisible index column with index as a tag.
    set colDef [list 0 [mc Description] 0 [mc {Handled By}] 0 ""]
    set wmclist $fr1.mclist
    
    tablelist::tablelist $wmclist  \
      -columns $colDef -yscrollcommand [list $fr1.vsb set]  \
      -labelcommand tablelist::sortByColumn  \
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
	set icon   [::Plugins::GetIconForPackage $doWhat 12]
	set desc   [::Types::GetDescriptionForMime $mime]
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
    button $frbt.rem -text [mc Delete]  \
      -state disabled -padx $xpadbt -font $fontS  \
      -command [list [namespace current]::DeleteAssociation $wmclist]
    button $frbt.change -text "[mc Edit]..."  \
      -state disabled -padx $xpadbt -font $fontS -command  \
      [list [namespace current]::Inspect $wDlgs(fileAssoc) edit $wmclist]
    button $frbt.add -text "[mc New]..." -padx $xpadbt -font $fontS \
      -command [list [namespace current]::Inspect .setass new $wmclist -1]
    pack $frbt.rem $frbt.change $frbt.add -side right -padx 10 -pady 5 \
      -fill x -expand 1
    
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

# ::FilePrefs::DeleteAssociation --
#
#       Deletes an MIME association.
#
# Arguments:
#       wmclist  the multi column listbox widget path.
#       indSel   the index of the one to remove.
# Results:
#       None.

proc ::FilePrefs::DeleteAssociation {wmclist {indSel {}}} {
    
    variable tmpMime2Description
    variable tmpMimeTypeIsText
    variable tmpMime2SuffixList
    variable tmpPrefMimeType2Package

    if {$indSel == ""} {
	set indSel [$wmclist curselection]
	if {$indSel == ""} {
	    return
	}
    }
    foreach {name pack mime} [lrange [$wmclist get $indSel] 0 2] break
    $wmclist delete $indSel
    unset -nocomplain \
      tmpMime2Description($mime) \
      tmpMimeTypeIsText($mime) \
      tmpMime2SuffixList($mime) \
      tmpPrefMimeType2Package($mime)
    
    # Select the next one
    $wmclist selection set $indSel
}    

# ::FilePrefs::SaveAssociations --
# 
#       Takes all the temporary arrays that makes up our database, 
#       and sets them to the actual arrays, tmp...(MIME).
#
# Arguments:
#       
# Results:
#       None.

proc ::FilePrefs::SaveAssociations { } {
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
    
# ::FilePrefs::Inspect --
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

proc ::FilePrefs::Inspect {w doWhat wlist {indSel {}}} {
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
	set indSel [$wlist curselection]
    }
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm title $w [mc {Inspect Associations}]
    set finishedInspect -1
    
    set fontSB [option get . fontSmallBold {}]
    
    if {$doWhat == "edit"} {
	if {$indSel < 0} {
	    error {::FilePrefs::Inspect called with illegal index}
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
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall
    
    # Frame for everything inside the labeled container: "Type of File".
    set wcont1 $w.frtop
    labelframe $wcont1 -text [mc {Type of File}]
    pack $wcont1 -in $w.frall -padx 8 -pady 4
    set fr1 [frame $wcont1.fr]
    label $fr1.x1 -text "[mc Description]:"
    entry $fr1.x2 -width 30   \
      -textvariable [namespace current]::textVarDesc
    label $fr1.x3 -text "[mc {MIME type}]:"
    entry $fr1.x4 -width 30   \
      -textvariable [namespace current]::textVarMime
    label $fr1.x5 -text "[mc {File suffixes}]:"
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
    set wcont2 $w.frmid
    labelframe $wcont2 -text [mc Handling]
    pack $wcont2 -in $w.frall -padx 8 -pady 4
    set fr2 [frame $wcont2.fr]
    radiobutton $fr2.x1 -text " [mc {Reject receive}]"  \
      -variable [namespace current]::receiveVar -value reject
    radiobutton $fr2.x2 -text " [mc preffmsave]"  \
      -variable [namespace current]::receiveVar -value save
    frame $fr2.fr
    radiobutton $fr2.x3 -text " [mc {Import using}]:  "  \
      -variable [namespace current]::receiveVar -value import
    
    set wMenu [eval {
	tk_optionMenu $fr2.opt [namespace current]::packageVar
    } $packageList]
    $wMenu configure -font $fontSB 
    $fr2.opt configure -font $fontSB -highlightthickness 0
    
    radiobutton $fr2.x8 -text " [mc {Unknown: Prompt user}]"  \
      -variable [namespace current]::receiveVar -value ask
    frame $fr2.frcode
    label $fr2.x4 -text " [mc {File coding}]:"
    radiobutton $fr2.x5 -text " [mc {As text}]" -anchor w  \
      -variable [namespace current]::codingVar -value 1
    radiobutton $fr2.x6 -text " [mc Binary]" -anchor w   \
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
    button $w.btok -text [mc Save] -default active  \
      -command [list [namespace current]::SaveThisAss $wlist $indSel]
    button $w.btcancel -text [mc Cancel]  \
      -command "set [namespace current]::finishedInspect 0"
    pack $w.btok $w.btcancel -in $w.frbot -side right -padx 5 -pady 5
    
    ::UI::SetWindowPosition $w
    wm resizable $w 0 0
    bind $w <Return> "$w.btok invoke"
    
    # Wait here for a button press.
    tkwait variable [namespace current]::finishedInspect
    grab release $w
    destroy $w
}

# ::FilePrefs::SaveThisAss --
#
#       Saves the association for one specific MIME type.
#
# Arguments:
#       wlist   the listbox widget path in the "FileAssociations" dialog.
#       indSel  the index of the selected item in 'wlist'. -1 if new.
#       
# Results:
#       Modifies the tmp... variables for one MIME type.

proc ::FilePrefs::SaveThisAss {wlist indSel} {
    
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
	tk_messageBox -title [mc Error] -icon error -type ok  \
	  -message [mc messfieldsmissing]
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

# FilePrefs::IsAnythingChangedQ --
# 
#       Returns 1 if any of the mime settings was changed, and 0 else.

proc ::FilePrefs::IsAnythingChangedQ { } {
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

proc ::FilePrefs::SavePrefsHook { } {

    ::FilePrefs::SaveAssociations
}

proc ::FilePrefs::CancelPrefsHook { } {

    if {[::FilePrefs::IsAnythingChangedQ]} {
	::Preferences::HasChanged
    }
}

proc ::FilePrefs::UserDefaultsHook { } {
    variable tmpMime2Description
    variable tmpMimeTypeIsText
    variable tmpMime2SuffixList
    variable tmpMimeTypeDoWhat
    variable tmpPrefMimeType2Package
    
    array set tmpMime2Description     [::Types::GetDescriptionArr]
    array set tmpMimeTypeIsText       [::Types::GetIsMimeTextArr]
    array set tmpMime2SuffixList      [::Types::GetSuffixListArr]
    array set tmpMimeTypeDoWhat       [::Plugins::GetDoWhatForMimeArr]
    array set tmpPrefMimeType2Package [::Plugins::GetPreferredPackageArr]
}
    
#-------------------------------------------------------------------------------
