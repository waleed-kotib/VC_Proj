#  FilePrefs.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements preference settings for whiteboard file importer.
#      
#  Copyright (c) 2004-2007  Mats Bengtsson
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
# $Id: FilePrefs.tcl,v 1.19 2007-08-23 13:01:30 matben Exp $

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
    
    if {![::Preferences::HaveTableItem Whiteboard]} {
	::Preferences::NewTableItem {Whiteboard} [mc Whiteboard]
    }
    ::Preferences::NewTableItem {Whiteboard {File Mappings}} [mc {File Mappings}]

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
    variable wtable
    variable wbuttons
	
    # Work only on copies of list of MIME types in case user presses the 
    # Cancel button. The MIME type works as a key in our database
    # (arrays) of various features.

    unset -nocomplain  \
      tmpMime2Description tmpMimeTypeIsText tmpMime2SuffixList  \
      tmpMimeTypeDoWhat tmpPrefMimeType2Package
    
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
        
    # Make the multi column listbox using treectrl. 
    set wtable $wlc.tree
    set wysc   $wlc.vsb
    ttk::scrollbar $wysc -orient vertical -command [list $wtable yview]
    TreeCtrl $wtable $wysc
    
    grid  $wtable   -column 0 -row 0 -sticky news
    grid  $wlc.vsb  -column 1 -row 0 -sticky ns
    grid columnconfigure $wlc 0 -weight 1
    grid rowconfigure $wlc 0 -weight 1
	
    # Insert all MIME types.
    foreach mime [::Types::GetAllMime] {
	set desc   [::Types::GetDescriptionForMime $mime]
	set doWhat [::Plugins::GetDoWhatForMime $mime]
	set icon   [::Plugins::GetIconForPackage $doWhat 12]
	InsertRow $wtable $mime $desc $doWhat $icon
    }    
    
    # Add, Change, and Remove buttons.
    set wbuttons $wlc.bot
    ttk::frame $wbuttons
    grid $wbuttons -row 1 -column 0 -columnspan 2 -sticky news
    
    ttk::button $wbuttons.rem -text [mc Delete]  \
      -command [namespace current]::DeleteAssociation
    ttk::button $wbuttons.edit -text "[mc Edit]..."  \
      -command [list [namespace current]::OnInspect edit]
    ttk::button $wbuttons.new -text "[mc New]..."  \
      -command [list [namespace current]::OnInspect new]

    pack  $wbuttons.rem  $wbuttons.edit  $wbuttons.new  -side right -padx 10 -pady 5 \
      -fill x -expand 1
    
    $wbuttons.rem  state {disabled}
    $wbuttons.edit state {disabled}
    
    bind $page <Destroy> {+::FilePrefs::Free}
}

proc ::FilePrefs::TreeCtrl {T wysc} {
    global  this
    variable sortColumn
    
    treectrl $T -selectmode browse  \
      -showroot 0 -showrootbutton 0 -showbuttons 0 -showlines 0  \
      -yscrollcommand [list $wysc set]  \
      -borderwidth 0 -highlightthickness 0
    
    # This is a dummy option.
    set itemBackground [option get $T itemBackground {}]
    set bd [option get $T columnBorderWidth {}]
    set bg [option get $T columnBackground {}]

    $T column create -tags cDescription -text [mc Description] \
      -itembackground $itemBackground -expand 1 -squeeze 1 -borderwidth $bd \
      -background $bg
    $T column create -tags cHandled -text [mc {Handled By}] \
      -itembackground $itemBackground -expand 1 -squeeze 1 -borderwidth $bd \
      -background $bg

    set fill [list $this(sysHighlight) {selected focus} gray {selected !focus}]

    $T element create eBorder rect -open new -outline gray -outlinewidth 1 \
      -fill $fill -showfocus 1
    $T element create eText   text -lines 1 -font CociSmallFont
    $T element create eImage  image

    set S [$T style create styText]
    $T style elements $S {eBorder eText}
    $T style layout $S eBorder -detach yes -iexpand xy
    $T style layout $S eText -padx 4 -squeeze x -expand ns -ipady 2
    
    set S [$T style create styImageText]
    $T style elements $S {eBorder eImage eText}
    $T style layout $S eBorder -detach yes -iexpand xy
    $T style layout $S eImage -padx 4 -squeeze x -expand ns -minwidth 16

    $T style layout $S eText -padx 4 -squeeze x -expand ns -ipady 2

    $T column configure cDescription -itemstyle styText
    $T column configure cHandled     -itemstyle styImageText

    $T notify install <Header-invoke>
    $T notify bind $T <Header-invoke> [list [namespace current]::HeaderCmd %T %C]
    $T notify bind $T <Selection>  [list [namespace current]::Selection %T]
    bind $T <Double-1>             [list [namespace current]::Double-1 %W]

    set sortColumn 0
}

proc ::FilePrefs::InsertRow {T mime desc doWhat icon} {
         
    set item [$T item create -tags $mime]
    $T item text $item cDescription $desc cHandled $doWhat
    $T item lastchild root $item
    if {[regexp {(unavailable|reject|save|ask)} $doWhat]} {
	set icon ""
    }
    $T item element configure $item cHandled eImage -image $icon
    return $item
}

proc ::FilePrefs::SetTableForMime {T mime desc doWhat icon} {

    set item [$T item id [list tags $mime]]
    if {[llength $item]} {
	$T item text $item cDescription $desc cHandled $doWhat
	if {![regexp {(unavailable|reject|save|ask)} $doWhat]} {
	    $T item element configure $item cHandled eImage -image $icon
	}
	$T selection add $item
    } else {
	set item [InsertRow $T $mime $desc $doWhat $icon]
	$T see $item
    }
}

proc ::FilePrefs::HeaderCmd {T C} {
    variable sortColumn
	
    if {[$T column compare $C == $sortColumn]} {
	if {[$T column cget $sortColumn -arrow] eq "down"} {
	    set order -increasing
	    set arrow up
	} else {
	    set order -decreasing
	    set arrow down
	}
    } else {
	if {[$T column cget $sortColumn -arrow] eq "down"} {
	    set order -decreasing
	    set arrow down
	} else {
	    set order -increasing
	    set arrow up
	}
	$T column configure $sortColumn -arrow none
	set sortColumn $C
    }
    $T column configure $C -arrow $arrow
    $T item sort root $order -column $C -dictionary
}

proc ::FilePrefs::Selection {T} {
    variable wbuttons
    
    if {[$T selection count] == 1} {
	$wbuttons.rem  state !disabled
	$wbuttons.edit state !disabled
    } else {
	$wbuttons.rem  state disabled
	$wbuttons.edit state disabled
    }
}

proc ::FilePrefs::Double-1 {T} {
    variable wbuttons
    
    $wbuttons.edit invoke
}

proc ::FilePrefs::OnInspect {what} {
    global  wDlgs
    variable wtable
    
    set T $wtable
    
    if {$what eq "edit"} {
	if {[$T selection count] == 1} {
	    set item [$T selection get]
	    set mime [$T item cget $item -tags]
	    Inspect $wDlgs(fileAssoc) edit $mime
	}
    } elseif {$what eq "new"} {
	Inspect $wDlgs(fileAssoc) new
    }
}

# ::FilePrefs::DeleteAssociation --
#
#       Deletes an MIME association.
#
# Arguments:
#       None.
#       
# Results:
#       None.

proc ::FilePrefs::DeleteAssociation { } {
    variable wtable
    variable tmpMime2Description
    variable tmpMimeTypeIsText
    variable tmpMime2SuffixList
    variable tmpPrefMimeType2Package

    set T $wtable
    if {[$T selection count] != 1} {
	return
    }
    set item [$T selection get]
    set mime [$T item cget $item -tags]

    $T item delete $item
    unset -nocomplain \
      tmpMime2Description($mime) \
      tmpMimeTypeIsText($mime) \
      tmpMime2SuffixList($mime) \
      tmpPrefMimeType2Package($mime)
}    

# ::FilePrefs::SaveAssociations --
# 
#       Takes all the temporary arrays that makes up our database, 
#       and sets them to the actual arrays, tmp...(MIME).
#
# Arguments:
#       None.
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
#       what  is "edit" if we want to change an association, or "new" if...
#       
# Results:
#       Dialog is displayed.

proc ::FilePrefs::Inspect {w what {mime ""}} {
    global  prefs this wDlgs
    
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

    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox} -class FilePrefsSet
    wm title $w [mc {Inspect Associations}]
    ::UI::SetWindowPosition $w

    set finishedInspect -1
    
    if {$what eq "edit"} {
	set textVarMime   $mime
	set textVarDesc   $tmpMime2Description($mime)
	set textVarSuffix $tmpMime2SuffixList($mime)
	set codingVar     $tmpMimeTypeIsText($mime)
	
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
	    set packageList [mc None]
	    set packageVar [mc None]
	}
    } elseif {$what eq "new"} {
	set textVarMime   ""
	set textVarDesc   ""
	set textVarSuffix ""
	set codingVar 0
	set receiveVar reject
	set packageVar [mc None]
	set packageList [mc None]
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
        
    if {$what eq "edit"} {
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
    ttk::radiobutton $wha.fc.t -text [mc {As text}]  \
      -variable [namespace current]::codingVar -value 1
    ttk::radiobutton $wha.fc.b -text [mc Binary]  \
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
    
    if {($what eq "edit") && ($packageList eq [mc None])} {
	$wha.x3  state {disabled}
	$wha.x3m state {disabled}
    }
    if {$what eq "new"} {
	$wha.x3 state {disabled}
    }
    
    # Button part
    set frbot $wbox.b
    ttk::frame $frbot
    ttk::button $frbot.btok -style TButton \
      -text [mc Save] -default active  \
      -command [namespace current]::SaveThisAss
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
#       None.
#       
# Results:
#       Modifies the tmp... variables for one MIME type.

proc ::FilePrefs::SaveThisAss { } {
    
    variable wtable
    
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

    set mime $textVarMime
    set desc $textVarDesc
    set suff $textVarSuffix

    # Check that no fields are empty.
    if {($desc eq "") || ($mime eq "") || ($suff eq "")} {
	::UI::MessageBox -title [mc Error] -icon error -type ok  \
	  -message [mc messfieldsmissing]
	return
    }
    
    # Put this specific MIME type associations in the tmp arrays.
    set tmpMime2Description($mime) $desc
    if {$packageVar eq [mc None]} {
	set tmpPrefMimeType2Package($mime) ""
    }
    
    # Map from the correct radiobutton alternative.
    switch -- $receiveVar {
	reject {
	    
	    # This maps either to an actual "reject" or to "unavailable".
	    if {[llength $tmpPrefMimeType2Package($mime)]} {
		set doWhat reject		
	    } else {
		set doWhat unavailable
	    }
	}
	save - ask {
	    set doWhat $receiveVar
	}
	default {
	    
	    # Should be a package.
	    set doWhat $packageVar
	    set tmpPrefMimeType2Package($mime) $packageVar
	}
    }
    set tmpMimeTypeDoWhat($mime)  $doWhat
    set tmpMimeTypeIsText($mime)  $codingVar
    set tmpMime2SuffixList($mime) $suff
    
    # Need to update the Mime type list in the "File Association" dialog.
    set icon [::Plugins::GetIconForPackage $doWhat 12]
    SetTableForMime $wtable $mime $desc $doWhat $icon
      
    set w [winfo toplevel $wtable]
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

proc ::FilePrefs::Free { } {
    variable tmpMime2Description
    variable tmpMimeTypeIsText
    variable tmpMime2SuffixList
    variable tmpMimeTypeDoWhat
    variable tmpPrefMimeType2Package
    
    unset -nocomplain  \
      tmpMime2Description tmpMimeTypeIsText tmpMime2SuffixList  \
      tmpMimeTypeDoWhat tmpPrefMimeType2Package
}
    
#-------------------------------------------------------------------------------
