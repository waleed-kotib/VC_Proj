#  EditDialogs.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements dialogs that are used for editing things, such as,
#      for instance, shortcut lists or font families.
#      
#  Copyright (c) 1999-2002  Mats Bengtsson
#  
#  See the README file for license, bugs etc.
#  
# $Id: EditDialogs.tcl,v 1.11 2004-03-16 15:09:08 matben Exp $


#       ::EditShortcuts:: implements dialogs for editing shortcuts. 
#       Typical shortcut lists is shorts for ip domain names, or streaming 
#       server ip names.

namespace eval ::EditShortcuts:: {
    
    # We take a copy of the shortcuts to work on.
    variable shortCopy
    
    # Signal warning if changed something while pressing cancel.
    variable anyChange
    
    # Variables to be used in tkwait.
    variable finEdit
    variable finAdd
}

# EditShortcuts::EditShortcuts --
#
#       A way to handle typical shortcut options consisting of a long name
#       and a short name. Helps managing such lists.
#   
# Arguments:
#       w      the toplevel window.
#       nameOfShortcutList   the list *name* 
#       
# Results:
#       shows dialog.

proc ::EditShortcuts::EditShortcuts {w nameOfShortcutList} {
    global  shortCopy this
    
    variable shortCopy
    variable anyChange
    variable finEdit
    variable finAdd
    
    # Call by reference.
    upvar #0 $nameOfShortcutList theShortcuts
    set finEdit -1
    set anyChange 0
    
    # First, make a copy of shortcuts to work on.
    set shortCopy $theShortcuts
    
    if {[winfo exists $w]} {
	return
    }
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    wm title $w [::msgcat::mc {Edit Shortcuts}]
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall
    
    # The top part.
    set wcont $w.frtop
    labelframe $wcont -text [::msgcat::mc {Edit Shortcuts}]]
    pack $wcont -in $w.frall
    
    # Overall frame for whole container.
    set frtot [frame $wcont.fr]
    
    # Frame for listbox and scrollbar.
    set frlist [frame $frtot.lst]
    
    # The listbox.
    set wsb $frlist.sb
    set wlbox [listbox $frlist.lb -height 7 -width 18 -yscrollcommand "$wsb set"]
    set edshort {}
    foreach ele [lindex $shortCopy 0] {
	lappend edshort "  $ele"
    }
    eval "$wlbox insert 0 $edshort"
    scrollbar $wsb -command "$wlbox yview"
    pack $wlbox  -side left -fill both
    pack $wsb -side left -fill both
    
    # Buttons at the right side.
    button $frtot.btadd -text "[::msgcat::mc Add]..."   \
      -command "[namespace current]::AddOrEditShortcuts add  \
      [namespace current]::shortCopy -1 $wlbox"
    button $frtot.btrem -text [::msgcat::mc Remove] -state disabled  \
      -command "[namespace current]::RemoveShortcuts $wlbox"
    
    # Trick: postpone command substitution; only variable substitution.
    button $frtot.btedit -text "[::msgcat::mc Edit]..." -state disabled  \
      -command "[namespace current]::AddOrEditShortcuts edit   \
      [namespace current]::shortCopy \[$wlbox curselection] $wlbox"
    
    grid $frlist -rowspan 3
    grid $frtot.btadd -column 1 -row 0 -sticky ew -padx 10
    grid $frtot.btrem -column 1 -row 1 -sticky ew -padx 10
    grid $frtot.btedit -column 1 -row 2 -sticky ew -padx 10
    
    pack $frtot -side left -padx 16 -pady 10    
    pack $wcont -fill x    
    
    # The bottom part.
    pack [frame $w.frbot -borderwidth 0] -in $w.frall -fill both   \
      -padx 8 -pady 6
    pack [button $w.frbot.bt1 -text [::msgcat::mc Save] -default active  \
      -command [list [namespace current]::DoSaveEditedShortcuts   \
      $nameOfShortcutList]]   \
      -side right -padx 5 -pady 5
    pack [button $w.frbot.btcancel -text [::msgcat::mc Cancel]  \
      -command [list [namespace current]::DoCancel $nameOfShortcutList]]  \
      -side right -padx 5 -pady 5
    
    bind $w <Return> [list $w.frbot.bt1 invoke]
    bind $wlbox <Button-1> {+ focus %W}
    bind $wlbox <Double-Button-1> "$frtot.btedit invoke"
    bind $wlbox <FocusIn> "$frtot.btrem configure -state normal;  \
      $frtot.btedit configure -state normal"
    bind $wlbox <FocusOut> "$frtot.btrem configure -state disabled;  \
      $frtot.btedit configure -state disabled"
    wm resizable $w 0 0
    
    # Grab and focus.
    catch {grab $w}
    tkwait variable [namespace current]::finEdit
    
    catch {grab release $w}
    destroy $w
    if {$finEdit == 1} {
	
	# Save shortcuts.
	return 1
    } elseif {$finEdit == 0} {
	
	# Cancel
	return 0
    }
}

# EditShortcuts::DoSaveEditedShortcuts, DoCancel --
#
#       Callbacks for the various buttons in the EditShortcuts dialog.
#   
# Arguments:
#       nameOfShortcutList    the name of the list that relates shorts
#                  with full names.
#       
# Results:
#       .

proc ::EditShortcuts::DoSaveEditedShortcuts {nameOfShortcutList} {
    
    variable shortCopy
    variable finEdit

    # Call by reference.
    upvar #0 $nameOfShortcutList theShortcuts
    set theShortcuts $shortCopy
    set finEdit 1
}

proc ::EditShortcuts::DoCancel {nameOfShortcutList} {
    
    variable anyChange
    variable finEdit

    # Cancel, keep old shortcuts. If changed something then warn.
    if {$anyChange} {
	set ans [tk_messageBox -icon error -type yesnocancel -message \
	  [FormatTextForMessageBox [::msgcat::mc shortwarn]]]
	if {[string equal $ans "yes"]} {
	    DoSaveEditedShortcuts $nameOfShortcutList
	    return
	} elseif {[string equal $ans "no"]} {
	    set finEdit 0
	    return
	} elseif {[string equal $ans "cancel"]} {
	    return
	}
    }
    set finEdit 0
}
	
# EditShortcuts::AddOrEditShortcuts --
#
#       Callback when the "add" or "edit" buttons pushed. New toplevel dialog
#       for editing an existing shortcut, or adding a fresh one.
#
# Arguments:
#       what           "add" or "edit".
#       nameOfShortsCopy     the name of the list that relates shorts
#                      with full names.
#       indShortcuts   the index in the shortcut list (-1 if add).
#       wListBox       widget path of list box; if empty, do not update 
#                      listbox entry.
#       
# Results:
#       shows dialog.

proc ::EditShortcuts::AddOrEditShortcuts {what nameOfShortsCopy indShortcuts  \
  {wListBox {}}} {
    global  this
    
    variable finAdd

    # Call by reference.
    upvar #0 $nameOfShortsCopy theShortCopy
    
    Debug 2 "AddOrEditShortcuts:: nameOfShortsCopy=$nameOfShortsCopy"

    if {$what == "edit" && $indShortcuts == ""} {
	return
    } 
    set w .taddshorts$what
    if {[winfo exists $w]} {
	return
    }
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox}
    if {$what == "add"} {
	set txt [::msgcat::mc {Add Shortcut}]
	set txt1 "[::msgcat::mc {New shortcut}]:"
	set txt2 "[::msgcat::mc shortip]:"
	set txtbt [::msgcat::mc Add]
    } elseif {$what == "edit"} {
	set txt [::msgcat::mc {Edit Shortcut}]
	set txt1 "[::msgcat::mc Shortcut]:"
	set txt2 "[::msgcat::mc shortip]:"
	set txtbt [::msgcat::mc Save]
    }
    wm title $w $txt
    set fontSB [option get . fontSmallBold {}]
    
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall
    
    # The top part.
    set wcont $w.frtop
    labelframe $wcont -text $txt]
    pack $wcont -in $w.frall
    
    # Overall frame for whole container.
    set frtot [frame $wcont.fr]
    label $frtot.lbl1 -text $txt1 -font $fontSB
    entry $frtot.ent1 -width 36 
    label $frtot.lbl2 -text $txt2 -font $fontSB
    entry $frtot.ent2 -width 36 
    grid $frtot.lbl1 -sticky w -padx 6 -pady 1
    grid $frtot.ent1 -sticky ew -padx 6 -pady 1
    grid $frtot.lbl2 -sticky w -padx 6 -pady 1
    grid $frtot.ent2 -sticky ew -padx 6 -pady 1
    
    pack $frtot -side left -padx 16 -pady 10
    pack $wcont -fill x    
    focus $frtot.ent1
    
    # Get the short pair to edit.
    if {[string equal $what "edit"]} {
	$frtot.ent1 insert 0 [lindex [lindex $theShortCopy 0] $indShortcuts]
	$frtot.ent2 insert 0 [lindex [lindex $theShortCopy 1] $indShortcuts]
    } elseif {[string equal $what "add"]} {
	
    }
    
    # The bottom part.
    pack [frame $w.frbot -borderwidth 0] -in $w.frall -fill both  \
      -padx 8 -pady 6
    # Trick: postpone command substitution; only variable substitution.
    button $w.frbot.bt1 -text "$txtbt" -default active  \
      -command "[namespace current]::PushBtAddOrEditShortcut $what  \
      $nameOfShortsCopy $indShortcuts \[$frtot.ent1 get] \[$frtot.ent2 get] "
    pack $w.frbot.bt1 -side right -padx 5 -pady 5
    pack [button $w.frbot.btcancel -text [::msgcat::mc Cancel]  \
      -command "set [namespace current]::finAdd 0"]  \
      -side right -padx 5 -pady 5
    
    bind $w <Return> "$w.frbot.bt1 invoke"
    wm resizable $w 0 0
    
    # Grab and focus.
    focus $w
    catch {grab $w}
    tkwait variable [namespace current]::finAdd
    
    catch {grab release $w}
    destroy $w
    if {$finAdd == 1} {
	# Save shortcuts in listbox.
	# Remove old and insert new content in listbox.
	if {[string length $wListBox] > 0} {
	    $wListBox delete 0 end
	    set edshort {}
	    foreach ele [lindex $theShortCopy 0] {
		lappend edshort "  $ele"
	    }
	    eval "$wListBox insert 0 $edshort"
	}
	return 1
    } else {
	# Cancel, keep old shortcuts.
	return 0
    }
}

# EditShortcuts::PushBtAddOrEditShortcut, EditShortcuts::RemoveShortcuts --
#  
#       Callback when pushing the "Add" or "Save" button in the add or 
#       edit shortcuts dialog.
#  
# Arguments:
#       what           "add" or "edit".
#       nameOfShorts   the name of the list that relates shorts
#                      with full names.
#       ind            the index in the shortcut list (-1 if add).
#       short
#       ip
#       wlist
#       
# Results:
#       Either replace or add shorts at the end.

proc ::EditShortcuts::PushBtAddOrEditShortcut {what nameOfShorts ind short ip} {
    
    variable anyChange
    variable finAdd

    # Call by reference.
    upvar #0 $nameOfShorts locShorts
    #puts "PushBtAddOrEditShortcut:: ind=$ind, short=$short, ip=$ip"
    set anyChange 0
    if {$what == "edit" && $ind == -1} {
	set finAdd 0
	return
    }
    if {$short == "" || $ip == ""} {
	set finAdd 0
	return
    }
    
    # We now know there is something to be added.
    set shcp [lindex $locShorts 0]
    set lncp [lindex $locShorts 1]
    if {$what == "add"} {
	
	# Just append at the end.
	lappend shcp $short
	lappend lncp $ip
	set locShorts [list $shcp $lncp]
    } elseif {$what == "edit"} {
	
	# Replace old with new.
	set shcp [lreplace $shcp $ind $ind $short]
	set lncp [lreplace $lncp $ind $ind $ip]
	set locShorts [list $shcp $lncp]
    }
    set anyChange 1
    set finAdd 1
}

proc ::EditShortcuts::RemoveShortcuts {wlist} {
    
    variable shortCopy
    variable anyChange

    set ind [$wlist curselection]
    if {$ind < 0} {
	return
    }
    $wlist delete $ind
    set shortlist [lreplace [lindex $shortCopy 0] $ind $ind]
    set iplist [lreplace [lindex $shortCopy 1] $ind $ind]
    set shortCopy [list $shortlist $iplist]
    set anyChange 1
}

#--- end of EditShortcuts ------------------------------------------------------
#-------------------------------------------------------------------------------
