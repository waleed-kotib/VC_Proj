# TtkDialog.tcl --
# 
#       Use fsdialog on unix to replace the standard ugly ones.
#
#  Copyright (c) 2007 Mats Bengtsson
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
#  $Id: TtkDialog.tcl,v 1.4 2007-07-18 09:40:10 matben Exp $

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

    # Message catalog.
    set msgdir [file join $::this(msgcatCompPath) TtkDialog]
    if {[file isdirectory $msgdir]} {
	uplevel #0 [list ::msgcat::mcload $msgdir]
    }
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

