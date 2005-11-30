#  WBPrefs.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements preference settings for the whiteboard.
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: WBPrefs.tcl,v 1.10 2005-11-30 08:32:00 matben Exp $

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
    
    set prefs(wb,strokePost) 1
    
    # All MIME type stuff... The problem is that they are all arrays... 
    # Invented the ..._array resource specifier!    
    # We should have used accesor functions and not direct access to internal
    # arrays. Sorry for this.
    # 
    ::PrefUtils::Add [list  \
      [list prefs(canScrollWidth)  prefs_canScrollWidth  $prefs(canScrollWidth)]  \
      [list prefs(canScrollHeight) prefs_canScrollHeight $prefs(canScrollHeight)] \
      [list prefs(canvasFonts)     prefs_canvasFonts     $prefs(canvasFonts)]   \
      [list prefs(privacy)         prefs_privacy         $prefs(privacy)]       \
      [list prefs(wb,strokePost)   prefs_wb_strokePost   $prefs(wb,strokePost)] \
    ]
}

proc ::WBPrefs::BuildPrefsHook {wtree nbframe} {
    
    if {![::Preferences::HaveTableItem Whiteboard]} {
	::Preferences::NewTableItem {Whiteboard} [mc Whiteboard]
    }
    ::Preferences::NewTableItem {Whiteboard {Edit Fonts}} [mc {Edit Fonts}]
    ::Preferences::NewTableItem {Whiteboard Privacy} [mc Privacy]
    
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
    set tmpPrefs(wb,strokePost)   $prefs(wb,strokePost)
    
    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    set wsi $wc.si
    ttk::labelframe $wsi -text [mc {Canvas Size}] \
      -padding [option get . groupSmallPadding {}]
    pack  $wsi  -side top -anchor w
    
    ttk::label $wsi.lh -text [mc prefwbscroll $prefs(mincanScrollWidth) \
      $prefs(mincanScrollHeight)]
    pack  $wsi.lh -side top -anchor w -padx 6
    set afr $wsi.fr
    ttk::frame $afr
    pack  $afr -side top -anchor [option get . dialogAnchor {}]
    ttk::label $afr.w -text "[mc Width]:"
    ttk::label $afr.h -text "[mc Height]:"
    ttk::entry $afr.width -font CociSmallFont \
      -width 6 \
      -textvariable [namespace current]::tmpPrefs(canScrollWidth)
    ttk::entry $afr.height -font CociSmallFont \
      -width 6 \
      -textvariable [namespace current]::tmpPrefs(canScrollHeight)  
    
    grid  $afr.w   $afr.width   -pady 2
    grid  $afr.h   $afr.height  -pady 2
    grid  $afr.w  -padx 2 -sticky e
    grid  $afr.h  -padx 2 -sticky e

    ttk::checkbutton $wc.spost -text "Smooth freehand strokes"  \
      -variable [namespace current]::tmpPrefs(wb,strokePost)

    pack  $wc.spost  -side top -anchor w -pady 6
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
    
    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    ttk::label $wc.head -text [mc {Import/Remove fonts}]
    ttk::label $wc.sysfont -text [mc {System fonts}]
    ttk::label $wc.wifont -text [mc {Whiteboard fonts}]
    ttk::frame $wc.fr1
    ttk::frame $wc.fr2
    ttk::frame $wc.fr3

    grid  $wc.head     -        -
    grid  $wc.sysfont  x        $wc.wifont  -padx 4 -pady 6
    grid  $wc.fr1      $wc.fr2  $wc.fr3    
    grid  $wc.fr2   -sticky n -padx 4 -pady 2
    
    set wlbsys $wc.fr1.lb
    set wlbwb  $wc.fr3.lb
    
    # System fonts.
    listbox $wlbsys -width 18 -height 10  \
      -yscrollcommand [list $wc.fr1.sc set]
    ttk::scrollbar $wc.fr1.sc -orient vertical   \
      -command [list $wc.fr1.lb yview]
    pack $wc.fr1.lb $wc.fr1.sc -side left -fill y
    
    # Cache font families since can be slow.
    if {![info exists fontFamilies]} {
	set fontFamilies [font families]
    }
    eval $wc.fr1.lb insert 0 $fontFamilies
    
    # Mid buttons.
    set btimport $wc.fr2.imp
    set btremove $wc.fr2.rm
    ttk::button $btimport -text {>>Import>>} \
      -command "[namespace current]::PushBtImport  \
      \[$wlbsys curselection] $wlbsys $wlbwb"
    ttk::button $btremove -text [mc Remove]  \
      -command "[namespace current]::PushBtRemove  \
      \[$wlbwb curselection] $wlbwb"
    ttk::button $wc.fr2.std -text {Standard}    \
      -command [list [namespace current]::PushBtStandard $wlbwb]
    
    pack  $btimport  $btremove  $wc.fr2.std  -padx 1 -pady 6 -fill x
    
    $btimport state {disabled}
    $btremove state {disabled}
    
    # Whiteboard fonts.
    listbox $wlbwb -width 18 -height 10  \
      -yscrollcommand [list $wc.fr3.sc set]
    ttk::scrollbar $wc.fr3.sc -orient vertical   \
      -command [list $wc.fr3.lb yview]
    pack $wlbwb $wc.fr3.sc -side left -fill y
    eval $wlbwb insert 0 $prefs(canvasFonts)
    
    ttk::label $wc.msg -text [mc preffontmsg] -wraplength 300 \
      -justify left -padding {0 6}
    set wsamp $wc.samp
    canvas $wsamp -width 200 -height 48 -highlightthickness 0 -border 1 \
      -relief sunken -bg white
    grid  $wc.msg   -columnspan 3 -sticky news -padx 4 -pady 2
    grid  $wc.samp  -columnspan 3 -sticky news
    
    bind $wlbsys <Button-1> {+ focus %W}
    bind $wlbwb  <Button-1> {+ focus %W}
    bind $wlbsys <<ListboxSelect>> [list [namespace current]::SelectFontCmd system]
    bind $wlbwb  <<ListboxSelect>> [list [namespace current]::SelectFontCmd wb]
	
    # Trick to resize the labels wraplength.
    set script [format {
	update idletasks
	%s.msg configure -wraplength [expr [winfo reqwidth %s] - 20]
    } $wc $wc]    
    after idle $script
}
  
proc ::WBPrefs::SelectFontCmd {which} {

    variable wlbwb
    variable wlbsys
    variable btimport
    variable btremove
    variable wsamp

    if {$which eq "system"} {
	set selInd [$wlbsys curselection]
	if {[llength $selInd]} {
	    $btimport state {!disabled}
	    set fntName [$wlbsys get $selInd]
	    if {[llength $fntName]} {
		$wsamp delete all
		$wsamp create text 6 24 -anchor w -text {Hello cruel World!}  \
		  -font [list $fntName 36]
	    }
	} else {
	    $btimport state {disabled}
	}
    } elseif {$which eq "wb"} {
	if {[llength [$wlbwb curselection]]} {
	    $btremove state {!disabled}
	} else {
	    $btremove state {disabled}
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
    
    if {$indSel eq ""} {
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
    
    if {$indSel eq ""} {
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
        
    set tmpPrefs(privacy) $prefs(privacy)

    set wc $page.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]

    set wpr $wc.pr
    ttk::labelframe $wpr -text [mc Privacy] \
      -padding [option get . groupSmallPadding {}]
    pack $wpr -side top
    
    ttk::label $wpr.msg -text [mc prefpriv] -wraplength 340 -justify left
    ttk::checkbutton $wpr.only -text [mc Privacy]  \
      -variable [namespace current]::tmpPrefs(privacy)
    
    grid  $wpr.msg   -sticky w
    grid  $wpr.only  -sticky w
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
