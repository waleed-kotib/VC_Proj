#  WBPrefs.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements preference settings for the whiteboard.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: WBPrefs.tcl,v 1.5 2004-12-02 08:22:35 matben Exp $

package provide WBPrefs 1.0

namespace eval ::WBPrefs:: {

    # Define all hooks for preference settings.
    ::hooks::register prefsInitHook          ::WBPrefs::InitPrefsHook
    ::hooks::register prefsBuildHook         ::WBPrefs::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::WBPrefs::SavePrefsHook
    ::hooks::register prefsCancelHook        ::WBPrefs::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::WBPrefs::UserDefaultsPrefsHook
    ::hooks::register prefsDestroyHook       ::WBPrefs::DestroyPrefsHook
}


proc ::WBPrefs::InitPrefsHook { } {
    global  prefs
    upvar ::Jabber::jprefs jprefs
    
    # Whiteboard scrollregion.
    set prefs(canScrollWidth)     1800
    set prefs(canScrollHeight)    1200
    set prefs(mincanScrollWidth)  1800
    set prefs(mincanScrollHeight) 1200

    # Defaults...
    set prefs(canvasFonts) [list Times Helvetica Courier]
    
    # Only manipulate own items?
    set prefs(privacy) 0
    
    # All MIME type stuff... The problem is that they are all arrays... 
    # Invented the ..._array resource specifier!    
    # We should have used accesor functions and not direct access to internal
    # arrays. Sorry for this.
    # 
    ::PreferencesUtils::Add [list  \
      [list prefs(canScrollWidth)  prefs_canScrollWidth  $prefs(canScrollWidth)]  \
      [list prefs(canScrollHeight) prefs_canScrollHeight $prefs(canScrollHeight)]  \
      [list prefs(canvasFonts)     prefs_canvasFonts     $prefs(canvasFonts)]  \
      [list prefs(privacy)         prefs_privacy         $prefs(privacy)]      \
    ]
}

proc ::WBPrefs::BuildPrefsHook {wtree nbframe} {
    
    if {![$wtree isitem Whiteboard]} {
	$wtree newitem {Whiteboard} -text [mc Whiteboard]
    }
    
    $wtree newitem {Whiteboard {Edit Fonts}} -text [mc {Edit Fonts}]
    $wtree newitem {Whiteboard Privacy} -text [mc Privacy]
    
    set wpage [$nbframe page {Whiteboard}]
    BuildWhiteboardPage $wpage

    # Edit Fonts page ----------------------------------------------------------
    set wpage [$nbframe page {Edit Fonts}]
    BuildFontsPage $wpage
    
    # Privacy page -------------------------------------------------------------
    set wpage [$nbframe page {Privacy}]
    BuildPagePrivacy $wpage
}

proc ::WBPrefs::BuildWhiteboardPage {page} {
    global  prefs
    variable tmpPrefs
    
    set tmpPrefs(canScrollWidth)  $prefs(canScrollWidth)
    set tmpPrefs(canScrollHeight) $prefs(canScrollHeight)
    
    set wfr $page.fr
    labelframe $wfr -text [mc {Scrollregion}]
    pack $wfr -side top -padx 8 -pady 4 -anchor w
    set str "You may set a larger size than the default\
      $prefs(mincanScrollWidth)x$prefs(mincanScrollHeight)"
    label $wfr.lh -text $str
    pack $wfr.lh -side top -anchor w -padx 6
    set afr $wfr.fr
    frame $afr
    pack  $afr -side top -anchor w
    label $afr.w -text "[mc width]:"
    label $afr.h -text "[mc height]:"
    entry $afr.width  -width 6 \
      -textvariable [namespace current]::tmpPrefs(canScrollWidth)
    entry $afr.height -width 6 \
      -textvariable [namespace current]::tmpPrefs(canScrollHeight)
    
    grid $afr.w   $afr.width
    grid $afr.h   $afr.height
    grid $afr.w -padx 2 -sticky e
    grid $afr.h -padx 2 -sticky e
}

# Fonts Page ...................................................................

proc ::WBPrefs::BuildFontsPage {page} {
    global  prefs

    variable wlbwb
    variable wlbsys
    variable btimport
    variable btremove
    variable wsamp
    variable fontFamilies
    
    set xpadbt [option get [winfo toplevel $page] xPadBt {}]
    set fontS  [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]
    
    # Labelled frame.
    set wcfr $page.fr
    labelframe $wcfr -text [mc {Import/Remove fonts}]
    pack $wcfr -side top -padx 8 -pady 4
    
    # Overall frame for whole container.
    set frtot [frame $wcfr.frin]
    pack $frtot -padx 4 -pady 2
    
    label $frtot.sysfont -text [mc {System fonts}] -font $fontSB
    label $frtot.wifont -text [mc {Whiteboard fonts}] -font $fontSB
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
    
    # Cache font families since can be slow.
    if {![info exists fontFamilies]} {
	set fontFamilies [font families]
    }
    eval $frtot.fr1.lb insert 0 $fontFamilies
    
    # Mid buttons.
    set btimport $frtot.fr2.imp
    set btremove $frtot.fr2.rm
    pack [button $btimport -text {>>Import>>} -state disabled \
      -font $fontS -padx $xpadbt   \
      -command "[namespace current]::PushBtImport  \
      \[$wlbsys curselection] $wlbsys $wlbwb"] -padx 1 -pady 6 -fill x
    pack [button $btremove -text [mc Remove] -state disabled  \
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
    pack $wlbwb $frtot.fr3.sc -side left -fill y
    eval $wlbwb insert 0 $prefs(canvasFonts)
    
    label $frtot.msg -text [mc preffontmsg] -wraplength 300 \
      -justify left
    set wsamp $frtot.samp
    canvas $wsamp -width 200 -height 48 -highlightthickness 0 -border 1 \
      -relief sunken
    grid $frtot.msg -columnspan 3 -sticky news -padx 4 -pady 2
    grid $frtot.samp -columnspan 3 -sticky news
    
    bind $wlbsys <Button-1> {+ focus %W}
    bind $wlbwb <Button-1> {+ focus %W}
    bind $wlbsys <<ListboxSelect>> [list [namespace current]::SelectFontCmd system]
    bind $wlbwb <<ListboxSelect>> [list [namespace current]::SelectFontCmd wb]
	
    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s.msg configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $frtot $frtot]    
    after idle $script
}
  
proc ::WBPrefs::SelectFontCmd {which} {

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

# PushBtImport, PushBtRemove, PushBtSave, PushBtStandard --
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

proc ::WBPrefs::PushBtImport {indSel wsys wapp} {
    
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
    
proc ::WBPrefs::PushBtRemove {indSel wapp} {
    
    if {$indSel == ""} {
	return
    }
    set fntName [$wapp get $indSel]
    
    # Check that not the standard fonts are removed.
    if {[lsearch {Times Helvetica Courier} $fntName] >= 0} {
	::UI::MessageBox -message [mc messrmstandardfonts] \
	  -icon error -type ok
	return
    }
    $wapp delete $indSel	
}
    
proc ::WBPrefs::PushBtSave { } {
    global  prefs    
    variable wlbwb

    # Do save.
    set prefs(canvasFonts) [$wlbwb get 0 end]
    ::WB::BuildAllFontMenus $prefs(canvasFonts)
}

proc ::WBPrefs::HaveFontListEdits { } {
    global  prefs
    variable wlbwb
    
    # Compare prefs(canvasFonts) with wlbwb content.
    if {[string equal [lsort $prefs(canvasFonts)] [lsort [$wlbwb get 0 end]]]} {
	return 0
    } else {
	return 1
    }
}
    
proc ::WBPrefs::PushBtStandard {wapp} {
    
    # Insert the three standard fonts.
    $wapp delete 0 end
    eval $wapp insert 0 {Times Helvetica Courier}
}

proc ::WBPrefs::BuildPagePrivacy {page} {
    global  prefs
    variable tmpPrefs
    
    set xpadbt [option get [winfo toplevel $page] xPadBt {}]
    
    set tmpPrefs(privacy) $prefs(privacy)

    set labfrpbl $page.fr
    labelframe $labfrpbl -text [mc Privacy]
    pack $labfrpbl -side top -anchor w -padx 8 -pady 4
    set pbl $labfrpbl.frin
    frame $pbl
    pack  $pbl -padx 10 -pady 6 -side left -fill x
    
    label $pbl.msg -text [mc prefpriv] -wraplength 340 -justify left
    checkbutton $pbl.only -anchor w -text "  [mc Privacy]"  \
      -variable [namespace current]::tmpPrefs(privacy)
    pack $pbl.msg $pbl.only -side top -fill x -anchor w
}

proc ::WBPrefs::SavePrefsHook { } {
    global  prefs
    variable tmpPrefs
    
    # Check validity of scrollregion.
    if {![string is integer $tmpPrefs(canScrollWidth)]} {
	set tmpPrefs(canScrollWidth) $prefs(mincanScrollWidth)
    }
    if {![string is integer $tmpPrefs(canScrollHeight)]} {
	set tmpPrefs(canScrollHeight) $prefs(mincanScrollHeight)
    }
    if {$tmpPrefs(canScrollWidth) < $prefs(mincanScrollWidth)} {
	set tmpPrefs(canScrollWidth) $prefs(mincanScrollWidth)
    }
    if {$tmpPrefs(canScrollHeight) < $prefs(mincanScrollHeight)} {
	set tmpPrefs(canScrollHeight) $prefs(mincanScrollHeight)
    }
    
    ::WBPrefs::PushBtSave
    array set prefs [array get tmpPrefs]
    
    # Set scrollregion of all open whiteboards.
    foreach w [::WB::GetAllWhiteboards] {
	::WB::SetScrollregion $w $prefs(canScrollWidth) $prefs(canScrollHeight)
    }
}

proc ::WBPrefs::CancelPrefsHook { } {
    global  prefs
    variable tmpPrefs
	
    if {[::WBPrefs::HaveFontListEdits]} {
	::Preferences::HasChanged
    } else {
	foreach key [array names tmpPrefs] {
	    if {![string equal $prefs($key) $tmpPrefs($key)]} {
		::Preferences::HasChanged
		break
	    }
	}
    }
}

proc ::WBPrefs::UserDefaultsPrefsHook { } {
    global  prefs
    variable tmpPrefs
    variable wlbwb
    
    $wlbwb delete 0 end
    eval {$wlbwb insert 0} $prefs(canvasFonts)
    foreach key [array names tmpPrefs] {
	set tmpPrefs($key) $prefs($key)
    }
}

proc ::WBPrefs::DestroyPrefsHook { } {
    variable tmpPrefs
    
    unset -nocomplain tmpPrefs
}

#-------------------------------------------------------------------------------
