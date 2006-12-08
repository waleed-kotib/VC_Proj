# TtkDialog.tcl --
# 
#       Use fsdialog on unix to replace the standard ugly ones.
#
#  Copyright (c) 2006 Mats Bengtsson
#  
#  $Id: TtkDialog.tcl,v 1.2 2006-12-08 13:42:52 matben Exp $

namespace eval ::TtkDialog {
    variable scriptDir [file dirname [info script]]
}

proc ::TtkDialog::Init { } {
    variable scriptDir
    
    if {[tk windowingsystem] ne "x11"} {
	return
    }
    if {[catch {package require ui::dialog}]} {
	return
    }
    set fsdialog [file join $scriptDir fsdialog.tcl]
    if {![file exists $fsdialog]} {
	return
    }
    uplevel #0 [list source $fsdialog]
    component::register TtkDialog "Redefines the standard file selection dialogs"

    interp alias {} tk_getOpenFile     {} ttk::getOpenFile
    interp alias {} tk_getSaveFile     {} ttk::getSaveFile
    interp alias {} tk_chooseDirectory {} ttk::chooseDirectory
    interp alias {} tk_messageBox      {} ::TtkDialog::MessageBox
}

proc ::TtkDialog::MessageBox {args} {
    variable button
    
    # @@@ Some of this should probably be in ui::dialog
    set argsA(-parent) .
    array set argsA $args
    set argsA(-variable) [namespace current]::button
    set argsA(-modal) 1
    set w [eval {ui::dialog} [array get argsA]]
    ::tk::PlaceWindow $w widget $argsA(-parent)

    catch {grab $w}
    vwait [namespace current]::button
    grab release $w

    return $button
}

