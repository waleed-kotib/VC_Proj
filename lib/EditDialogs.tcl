#  EditDialogs.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements dialogs that are used for editing things, such as,
#      for instance, shortcut lists or font families.
#      
#  Copyright (c) 1999-2005  Mats Bengtsson
#  
# $Id: EditDialogs.tcl,v 1.16 2005-11-30 08:32:00 matben Exp $

package provide EditDialogs 1.0

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

    if {[winfo exists $w]} {
	raise $w
	return
    }

    set finEdit -1
    set anyChange 0
    
    # First, make a copy of shortcuts to work on.
    set shortCopy $theShortcuts
    
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox} \
      -closecommand ::EditShortcuts::CloseCmd
    wm title $w [mc {Edit Shortcuts}]

    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    set wcont $wbox.f
    ttk::labelframe $wcont -padding [option get . groupSmallPadding {}] \
      -text [mc {Edit Shortcuts}]
    pack $wcont
        
    # Frame for listbox and scrollbar.
    set frlist $wcont.f
    frame $frlist -bd 1 -relief sunken
    pack  $frlist -side left -fill y
    
    # The listbox.
    set wsb   $frlist.sb
    set wlbox $frlist.lb
    listbox $wlbox -height 8 -width 20 -yscrollcommand [list $wsb set] \
      -selectmode single
    set edshort {}
    foreach ele [lindex $shortCopy 0] {
	lappend edshort "  $ele"
    }
    eval {$wlbox insert 0} $edshort
    ttk::scrollbar $wsb -command [list $wlbox yview]
    pack  $wlbox  -side left -fill both
    pack  $wsb    -side left -fill y
    
    # Buttons at the right side.
    set frbt $wcont.b
    ttk::frame $frbt -padding {10 0 0 0}
    pack $frbt -side right -fill y
    ttk::button $frbt.btadd -text "[mc Add]..."   \
      -command "[namespace current]::AddOrEditShortcuts add  \
      [namespace current]::shortCopy -1 $wlbox"
    ttk::button $frbt.btrem -text [mc Remove]  \
      -command [list [namespace current]::RemoveShortcuts $wlbox]
    
    # Trick: postpone command substitution; only variable substitution.
    ttk::button $frbt.btedit -text "[mc Edit]..."  \
      -command "[namespace current]::AddOrEditShortcuts edit   \
      [namespace current]::shortCopy \[$wlbox curselection] $wlbox"
    
    grid  $frbt.btadd   -sticky ew -pady 8
    grid  $frbt.btrem   -sticky ew -pady 8
    grid  $frbt.btedit  -sticky ew -pady 8
    
    $frbt.btrem  state {disabled}
    $frbt.btedit state {disabled}
    
    # The bottom part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc Save] -default active  \
      -command [list [namespace current]::DoSaveEditedShortcuts   \
      $nameOfShortcutList]
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list [namespace current]::DoCancel $nameOfShortcutList]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side bottom -fill x
    
    bind $w <Return> [list $frbot.btok invoke]
    bind $wlbox <Button-1> {+ focus %W}
    bind $wlbox <Double-Button-1> [list $frbt.btedit invoke]
    bind $wlbox <<ListboxSelect>> [list ::EditShortcuts::SelectCmd %W $frbt]
    
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

proc ::EditShortcuts::SelectCmd {wlbox frbt} {
    
    if {[$wlbox curselection] == {}} {
	$frbt.btrem  state {disabled}
	$frbt.btedit state {disabled}
    } else {
	$frbt.btrem  state {!disabled}
	$frbt.btedit state {!disabled}
    }
}

proc ::EditShortcuts::CloseCmd {w} {
    variable finEdit
    
    set finEdit 0
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
	set ans [::UI::MessageBox -icon error -type yesnocancel \
	  -message [mc shortwarn]]
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

    if {$what eq "edit" && $indShortcuts eq ""} {
	return
    } 
    set w .taddshorts$what
    if {[winfo exists $w]} {
	raise $w
	return
    }
    if {$what eq "add"} {
	set txt [mc {Add Shortcut}]
	set txt1 "[mc {New shortcut}]:"
	set txt2 "[mc shortip]:"
	set txtbt [mc Add]
    } elseif {$what eq "edit"} {
	set txt [mc {Edit Shortcut}]
	set txt1 "[mc Shortcut]:"
	set txt2 "[mc shortip]:"
	set txtbt [mc Save]
    }
    ::UI::Toplevel $w -macstyle documentProc -usemacmainmenu 1 \
      -macclass {document closeBox} \
      -closecommand ::EditShortcuts::CloseAddCmd
    wm title $w $txt
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1
    
    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    # The top part.
    set frtot $wbox.f
    ttk::labelframe $frtot  -padding [option get . groupSmallPadding {}] \
      -text $txt
    pack $frtot
    
    ttk::label $frtot.lbl1 -text $txt1
    ttk::entry $frtot.ent1 -width 36 
    ttk::label $frtot.lbl2 -padding {0 8 0 0} -text $txt2
    ttk::entry $frtot.ent2 -width 36 
    
    grid  $frtot.lbl1  -sticky w
    grid  $frtot.ent1
    grid  $frtot.lbl2  -sticky w
    grid  $frtot.ent2
    
    focus $frtot.ent1
    
    # Get the short pair to edit.
    if {[string equal $what "edit"]} {
	$frtot.ent1 insert 0 [lindex $theShortCopy 0 $indShortcuts]
	$frtot.ent2 insert 0 [lindex $theShortCopy 1 $indShortcuts]
    } elseif {[string equal $what "add"]} {
	
    }
    
    # The bottom part.
    set frbot $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    # Trick: postpone command substitution; only variable substitution.
    ttk::button $frbot.btok -text $txtbt -default active  \
      -command "[namespace current]::PushBtAddOrEditShortcut $what  \
      $nameOfShortsCopy $indShortcuts \[$frtot.ent1 get] \[$frtot.ent2 get] "
    ttk::button $frbot.btcancel -text [mc Cancel]  \
      -command [list set [namespace current]::finAdd 0]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side bottom -fill x
    
    bind $w <Return> [list $frbot.btok invoke]
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
	    eval {$wListBox insert 0} $edshort
	}
	return 1
    } else {
	# Cancel, keep old shortcuts.
	return 0
    }
}

proc ::EditShortcuts::CloseAddCmd {w} {
    variable finAdd
    
    set finAdd 0
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
    if {$what eq "edit" && $ind == -1} {
	set finAdd 0
	return
    }
    if {$short eq "" || $ip eq ""} {
	set finAdd 0
	return
    }
    
    # We now know there is something to be added.
    set shcp [lindex $locShorts 0]
    set lncp [lindex $locShorts 1]
    if {$what eq "add"} {
	
	# Just append at the end.
	lappend shcp $short
	lappend lncp $ip
	set locShorts [list $shcp $lncp]
    } elseif {$what eq "edit"} {
	
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
