#  Filter.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements the jabber:iq:filter stuff plus UI.
#      TODO!!!!!!!!!!!!!
#      
#  Copyright (c) 2004  Mats Bengtsson
#  
# $Id: Filter.tcl,v 1.2 2004-04-09 10:32:25 matben Exp $


package provide Filter 1.0


namespace eval ::Jabber::Filter:: {
    
    # Define all hooks for preference settings.
    ::hooks::add prefsInitHook          ::Jabber::Filter::InitPrefsHook
    ::hooks::add prefsBuildHook         ::Jabber::Filter::BuildPrefsHook
    ::hooks::add prefsSaveHook          ::Jabber::Filter::SavePrefsHook
    ::hooks::add prefsCancelHook        ::Jabber::Filter::CancelPrefsHook
    ::hooks::add prefsUserDefaultsHook  ::Jabber::Filter::UserDefaultsHook
}



# Prefs Page ...................................................................

proc ::Jabber::Filter::InitPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    
    # Defaults...
    set jprefs(block,notinrost)     0
    set jprefs(block,list)          {}
	
    ::PreferencesUtils::Add [list  \
      [list ::Jabber::jprefs(block,notinrost)  jprefs_block_notinrost   $jprefs(block,notinrost)]  \
      [list ::Jabber::jprefs(block,list)       jprefs_block_list        $jprefs(block,list)    userDefault] \
      ]
}

proc ::Jabber::Filter::BuildPrefsHook {wtree nbframe} {
    
    $wtree newitem {Jabber Blockers} -text [::msgcat::mc Blockers]
    
    # Blockers page --------------------------------------------------------
    set wpage [$nbframe page {Blockers}]    
    ::Jabber::Filter::BuildPrefsPage $wpage
}

proc ::Jabber::Filter::BuildPrefsPage {page} {
    upvar ::Jabber::jprefs jprefs
    
    variable wlbblock
    variable btrem
    variable wlbblock
    variable tmpJPrefs
    
    set xpadbt [option get [winfo toplevel $page] xPadBt {}]
    
    foreach key {notinrost list} {
	set tmpJPrefs(block,$key) $jprefs(block,$key)
    }
    
    set labfrpbl $page.fr
    labelframe $labfrpbl -text [::msgcat::mc Blockers]
    pack $labfrpbl -side top -anchor w -padx 8 -pady 4
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
    pack [button $btadd -text "[::msgcat::mc Add]..." -padx $xpadbt  \
      -command [list [namespace current]::Add .blkadd]]    \
      -side top -fill x -padx 6 -pady 4
    pack [button $btrem -text [::msgcat::mc Remove] -padx $xpadbt  \
      -command [list [namespace current]::Remove] -state disabled] \
      -side top -fill x -padx 6 -pady 4
    pack [button $pbl.fr.clr -text [::msgcat::mc Clear]  \
      -padx $xpadbt -command [list [namespace current]::Clear]]    \
      -side top -fill x -padx 6 -pady 4
	
    # Special bindings for the listbox.
    bind $wlbblock <Button-1> {+ focus %W}
    bind $wlbblock <<ListboxSelect>> [list [namespace current]::SelectCmd]
}

proc ::Jabber::Filter::SelectCmd { } {

    variable btrem
    variable wlbblock

    if {[llength [$wlbblock curselection]]} {
	$btrem configure -state normal
    } else {
	$btrem configure -state disabled
    }
}

proc ::Jabber::Filter::Add {w} {
    global  this

    variable finished
    variable addJid
    variable wlbblock
    
    set finished 0
    if {[winfo exists $w]} {
	return
    }
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm title $w [::msgcat::mc {Block JID}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1
    
    # Labelled frame.
    set wcfr $w.frall.fr
    labelframe $wcfr -text [::msgcat::mc {JID to block}]
    pack $wcfr -side top -fill both -padx 8 -pady 4 -in $w.frall
    
    # Overall frame for whole container.
    set frtot [frame $wcfr.frin]
    pack $frtot
    message $frtot.msg -borderwidth 0 -aspect 500 \
      -text [::msgcat::mc prefblmsg]
    entry $frtot.ent -width 24 -textvariable [namespace current]::addJid
    set addJid {}
    pack $frtot.msg $frtot.ent -side top -fill x -anchor w -padx 2 -pady 2
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btconn -text [::msgcat::mc Add] -default active \
      -command [list [namespace current]::DoAdd]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [::msgcat::mc Cancel]  \
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

proc ::Jabber::Filter::DoAdd { } {

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

proc ::Jabber::Filter::Remove { } {

    variable wlbblock

    set selectedInd [$wlbblock curselection]
    if {[llength $selectedInd]} {
	foreach ind [lsort -integer -decreasing $selectedInd] {
	    $wlbblock delete $ind
	}
    }
}

proc ::Jabber::Filter::Clear { } {
    
    variable wlbblock

    $wlbblock delete 0 end
}

proc ::Jabber::Filter::SavePrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    array set jprefs [array get tmpJPrefs]
    unset tmpJPrefs
}

proc ::Jabber::Filter::CancelPrefsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
	
    foreach key [array names tmpJPrefs] {
	if {![string equal $jprefs($key) $tmpJPrefs($key)]} {
	    ::Preferences::HasChanged
	    break
	}
    }
}

proc ::Jabber::Filter::UserDefaultsHook { } {
    upvar ::Jabber::jprefs jprefs
    variable tmpJPrefs
    
    foreach key [array names tmpJPrefs] {
	set tmpJPrefs($key) $jprefs($key)
    }
}

#-------------------------------------------------------------------------------
