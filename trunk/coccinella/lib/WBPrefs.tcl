#  WBPrefs.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements preference settings for the whiteboard.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: WBPrefs.tcl,v 1.1 2004-03-28 14:49:24 matben Exp $

package provide WBPrefs 1.0

namespace eval ::WBPrefs:: {

    # Define all hooks for preference settings.
    ::hooks::add prefsInitHook      ::WBPrefs::InitPrefsHook
    ::hooks::add prefsBuildHook     ::WBPrefs::BuildPrefsHook
    ::hooks::add prefsSaveHook      ::WBPrefs::SavePrefsHook
    ::hooks::add prefsCancelHook    ::WBPrefs::CancelPrefsHook
}


proc ::WBPrefs::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    
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
      [list prefs(canvasFonts)     prefs_canvasFonts     $prefs(canvasFonts)]  \
      [list prefs(privacy)         prefs_privacy         $prefs(privacy)]      \
    ]
}

proc ::WBPrefs::BuildPrefsHook {wtree nbframe} {
    
    $wtree newitem {Whiteboard {Edit Fonts}} -text [::msgcat::mc {Edit Fonts}]
    $wtree newitem {Whiteboard Privacy} -text [::msgcat::mc Privacy]
    
    # Edit Fonts page ----------------------------------------------------------
    set wpage [$nbframe page {Edit Fonts}]
    ::WBPrefs::BuildFontsPage $wpage
    
    # Privacy page -------------------------------------------------------------
    set wpage [$nbframe page {Privacy}]
    ::WBPrefs::BuildPagePrivacy $wpage
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
    labelframe $wcfr -text [::msgcat::mc {Import/Remove fonts}]
    pack $wcfr -side top -padx 8 -pady 4
    
    # Overall frame for whole container.
    set frtot [frame $wcfr.frin]
    pack $frtot -padx 4 -pady 2
    
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
    bind $wlbsys <<ListboxSelect>> [list [namespace current]::SelectFontCmd system]
    bind $wlbwb <<ListboxSelect>> [list [namespace current]::SelectFontCmd wb]
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
	tk_messageBox -message [FormatTextForMessageBox  \
	  [::msgcat::mcset en messrmstandardfonts]] \
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
    labelframe $labfrpbl -text [::msgcat::mc Privacy]
    pack $labfrpbl -side top -anchor w -padx 8 -pady 4
    set pbl [frame $labfrpbl.frin]
    pack $pbl -padx 10 -pady 6 -side left
    
    message $pbl.msg -text [::msgcat::mc prefpriv] -aspect 800
    checkbutton $pbl.only -anchor w -text "  [::msgcat::mc Privacy]"  \
      -variable [namespace current]::tmpPrefs(privacy)
    pack $pbl.msg $pbl.only -side top -fill x -anchor w
}

proc ::WBPrefs::SavePrefsHook { } {
    global  prefs
    variable tmpPrefs

    ::WBPrefs::PushBtSave
    array set prefs [array get tmpJPrefs]
    unset tmpPrefs
}

proc ::WBPrefs::CancelPrefsHook { } {
    global  prefs
    variable tmpPrefs
	
    foreach key [array names tmpJPrefs] {
	if {![string equal $prefs($key) $tmpJPrefs($key)]} {
	    ::Preferences::HasChanged
	    break
	}
    }
}

#-------------------------------------------------------------------------------
