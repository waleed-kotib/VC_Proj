#  FilePrefs.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements preference settings for whiteboard file importer.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: FilePrefs.tcl,v 1.7 2005-08-14 08:37:52 matben Exp $

package provide FilePrefs 1.0


namespace eval ::FilePrefs:: {

    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          ::FilePrefs::InitPrefsHook
    ::hooks::register prefsBuildHook         ::FilePrefs::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::FilePrefs::SavePrefsHook
    ::hooks::register prefsCancelHook        ::FilePrefs::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::FilePrefs::UserDefaultsHook
    
    option add *FilePrefsSet*Menu.font           CociSmallFont       widgetDefault

    option add *FilePrefsSet*TLabel.style        Small.TLabel        widgetDefault
    option add *FilePrefsSet*TLabelframe.style   Small.TLabelframe   widgetDefault
    option add *FilePrefsSet*TButton.style       Small.TButton       widgetDefault
    option add *FilePrefsSet*TMenubutton.style   Small.TMenubutton   widgetDefault
    option add *FilePrefsSet*TRadiobutton.style  Small.TRadiobutton  widgetDefault
    option add *FilePrefsSet*TCheckbutton.style  Small.TCheckbutton  widgetDefault

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
    ::PrefUtils::Add [list  \
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
	
    # Work only on copies of list of MIME types in case user presses the 
    # Cancel button. The MIME type works as a key in our database
    # (arrays) of various features.

    array set tmpMime2Description     [::Types::GetDescriptionArr]
    array set tmpMimeTypeIsText       [::Types::GetIsMimeTextArr]
    array set tmpMime2SuffixList      [::Types::GetSuffixListArr]
    array set tmpMimeTypeDoWhat       [::Plugins::GetDoWhatForMimeArr]
    array set tmpPrefMimeType2Package [::Plugins::GetPreferredPackageArr]
    
    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    # Frame for everything inside the labeled container.
    set wlc $wc.lc
    ttk::labelframe $wlc -text [mc preffmhelp] \
      -padding [option get . groupSmallPadding {}]
    pack $wlc -side top
        
    # Make the multi column listbox. 
    # Keep an invisible index column with index as a tag.
    set colDef [list 0 [mc Description] 0 [mc {Handled By}] 0 ""]
    set wmclist $wlc.mclist
    
    tablelist::tablelist $wmclist  \
      -columns $colDef -yscrollcommand [list $wlc.vsb set]  \
      -labelcommand tablelist::sortByColumn  \
      -stretch all -width 42 -height 12
    $wmclist columnconfigure 2 -hide 1

    tuscrollbar $wlc.vsb -orient vertical -command [list $wmclist yview]
    
    grid  $wmclist  -column 0 -row 0 -sticky news
    grid  $wlc.vsb  -column 1 -row 0 -sticky ns
    grid columnconfigure $wlc 0 -weight 1
    grid rowconfigure $wlc 0 -weight 1
	
    # Insert all MIME types.
    set i 0
    foreach mime [::Types::GetAllMime] {
	set doWhat [::Plugins::GetDoWhatForMime $mime]
	set icon   [::Plugins::GetIconForPackage $doWhat 12]
	set desc   [::Types::GetDescriptionForMime $mime]
	if {![regexp {(unavailable|reject|save|ask)} $doWhat] && ($icon ne "")} {
	    $wmclist insert end [list " $desc" $doWhat $mime]
	    $wmclist cellconfigure "$i,1" -image $icon
	} else {
	    $wmclist insert end [list " $desc" "     $doWhat" $mime]
	}
	incr i
    }    
    
    # Add, Change, and Remove buttons.
    set wbot $wlc.bot
    ttk::frame $wbot
    grid $wbot -row 1 -column 0 -columnspan 2 -sticky news
    
    ttk::button $wbot.rem -text [mc Delete]  \
      -command [list [namespace current]::DeleteAssociation $wmclist]
    ttk::button $wbot.change -text "[mc Edit]..."  \
      -command [list [namespace current]::Inspect $wDlgs(fileAssoc) edit $wmclist]
    ttk::button $wbot.add -text "[mc New]..."  \
      -command [list [namespace current]::Inspect .setass new $wmclist -1]

    pack  $wbot.rem  $wbot.change  $wbot.add  -side right -padx 10 -pady 5 \
      -fill x -expand 1
    
    $wbot.rem    state {disabled}
    $wbot.change state {disabled}
    
    # Special bindings for the tablelist.
    set body [$wmclist bodypath]
    bind $body <Button-1> {+ focus %W}
    bind $body <Double-1> [list $wbot.change invoke]
    bind $wmclist <<ListboxSelect>> [list [namespace current]::Select $wbot]
}

proc ::FilePrefs::Select {wbot} {

    $wbot.rem state !disabled
    $wbot.change state !disabled
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

    if {$indSel eq ""} {
	set indSel [$wmclist curselection]
	if {$indSel eq ""} {
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
	raise $w
	return
    }
    if {[string length $indSel] == 0} {
	set indSel [$wlist curselection]
    }
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox} -class FilePrefsSet
    wm title $w [mc {Inspect Associations}]
    ::UI::SetWindowPosition $w

    set finishedInspect -1
    
    if {$doWhat eq "edit"} {
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
    } elseif {$doWhat eq "new"} {
	set textVarMime {}
	set textVarDesc {}
	set textVarSuffix {}
	set codingVar 0
	set receiveVar reject
	set packageVar None
	set packageList None
    }

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    # Frame for everything inside the labeled container: "Type of File".
    set wty $wbox.fty
    ttk::labelframe $wty -text [mc {Type of File}] \
      -padding [option get . groupSmallPadding {}]
    pack $wty -fill x
    
    ttk::label $wty.x1 -text "[mc Description]:"
    ttk::entry $wty.x2 -font CociSmallFont -width 30   \
      -textvariable [namespace current]::textVarDesc
    ttk::label $wty.x3 -text "[mc {MIME type}]:"
    ttk::entry $wty.x4 -font CociSmallFont -width 30   \
      -textvariable [namespace current]::textVarMime
    ttk::label $wty.x5 -text "[mc {File suffixes}]:"
    ttk::entry $wty.x6 -font CociSmallFont -width 30   \
      -textvariable [namespace current]::textVarSuffix
    
    grid  $wty.x1  $wty.x2  -sticky e -pady 2
    grid  $wty.x3  $wty.x4  -sticky e -pady 2
    grid  $wty.x5  $wty.x6  -sticky e -pady 2
        
    if {$doWhat eq "edit"} {
	$wty.x2 state {disabled}
	$wty.x4 state {disabled}
    }
    
    # Frame for everything inside the labeled container: "Handling".
    set wha $wbox.fha
    ttk::labelframe $wha -text [mc Handling] \
      -padding [option get . groupSmallPadding {}]
    pack $wha -fill x -pady 10

    ttk::radiobutton $wha.x1 -text [mc {Reject receive}]  \
      -variable [namespace current]::receiveVar -value reject
    ttk::radiobutton $wha.x2 -text [mc preffmsave]  \
      -variable [namespace current]::receiveVar -value save
    ttk::frame $wha.fr
    ttk::radiobutton $wha.x3 -text "[mc {Import using}]:"  \
      -variable [namespace current]::receiveVar -value import
    set wMenu [eval {
	ttk::optionmenu $wha.x3m [namespace current]::packageVar
    } $packageList]
    $wMenu configure -font CociSmallFont     
    ttk::radiobutton $wha.x8 -text [mc {Unknown: Prompt user}]  \
      -variable [namespace current]::receiveVar -value ask
    ttk::frame $wha.fc
    ttk::label $wha.fc.l -text "[mc {File coding}]:"
    ttk::radiobutton $wha.fc.t -text [mc {As text}] -anchor w  \
      -variable [namespace current]::codingVar -value 1
    ttk::radiobutton $wha.fc.b -text [mc Binary] -anchor w   \
      -variable [namespace current]::codingVar -value 0
    
    grid  $wha.x1  -         -sticky w
    grid  $wha.x2  -         -sticky w
    grid  $wha.x3  $wha.x3m  -sticky w
    grid  $wha.x8  -         -sticky w
    grid  $wha.fc  -         -sticky w -padx 16
    
    grid  $wha.fc.l  $wha.fc.t  -sticky w
    grid  x          $wha.fc.b  -sticky w
        
    # If we dont have any registered packages for this MIME, disable this
    # option.
    
    if {($doWhat eq "edit") && ($packageList eq "None")} {
	$wha.x3  state {disabled}
	$wha.x3m state {disabled}
    }
    if {$doWhat eq "new"} {
	$wha.x3 state {disabled}
    }
    
    # Button part
    set frbot $wbox.b
    ttk::frame $frbot
    ttk::button $frbot.btok -style TButton \
      -text [mc Save] -default active  \
      -command [list [namespace current]::SaveThisAss $wlist $indSel]
    ttk::button $frbot.btcancel -style TButton \
      -text [mc Cancel]  \
      -command [list set [namespace current]::finishedInspect 0]
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
    if {($textVarDesc eq "") || ($textVarMime eq "") || ($textVarSuffix eq "")} {
	::UI::MessageBox -title [mc Error] -icon error -type ok  \
	  -message [mc messfieldsmissing]
	return
    }
    
    # Put this specific MIME type associations in the tmp arrays.
    set tmpMime2Description($textVarMime) $textVarDesc
    if {$packageVar eq "None"} {
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
    if {![regexp {(unavailable|reject|save|ask)} $doWhat] && ($icon ne "")} {
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
