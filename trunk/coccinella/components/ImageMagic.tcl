# ImageMagic.tcl --
# 
# ImportWindowSnapShot
# Depends on ImageMagic installation
# Contributed by Raymond Tang, adapted as a plugin by Mats Bengtsson.
# 
# Unix/Linux only.
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
# $Id: ImageMagic.tcl,v 1.11 2007-07-18 09:40:09 matben Exp $

namespace eval ::ImageMagic:: {
    
    variable imageType gif
}

proc ::ImageMagic::Init { } {
    global  tcl_platform
    variable imageType
    variable haveImageMagic
    variable importcmd
        
    set haveImageMagic 0
    if {[string equal $tcl_platform(platform) "unix"]} {
	set importcmd [lindex [auto_execok import] 0]
	if {[llength $importcmd]} {
	    set haveImageMagic 1
	}	
    }
    
    # Register a menu entry for this component.
    if {$haveImageMagic} {
	component::register ImageMagic  \
	  "Provides bindings to Image Magics import command for taking\
	  screenshots on X11."
	
	# 'type' 'label' 'command' 'opts' {subspec}
	# where subspec defines a cascade menu recursively
	set menuspec [list \
	    command [mc {Take Snapshot}] {::ImageMagic::ImportWindowSnapShot $w} {} {} \
	]
      ::WB::RegisterNewMenu addon [mc mAddons] $menuspec
    }
}

proc ::ImageMagic::ImportWindowSnapShot {w} {
    global  this
    variable imageType
    variable tmpfiles
    variable haveImageMagic
    variable importcmd
    
    set wcan [::WB::GetCanvasFromWtop $w]
    
    if {$haveImageMagic == 0} {
	::UI::MessageBox -icon error -type ok -message  \
	  "Failed to locate ImageMagic package! Can't do screen snap shot :-("
	return
    }
    set ans [::ImageMagic::BuildDialog .imagic]
    update
    
    if {$ans eq "1"} {
	set tmpfile [::tfileutils::tempfile $this(tmpPath) imagemagic]
	append tmpfile .$imageType
	exec $importcmd $tmpfile
	set optList [list -coords [::CanvasUtils::NewImportAnchor $wcan]]
	set errMsg [::Import::DoImport $wcan $optList -file $tmpfile]
	if {$errMsg eq ""} {
	    lappend tmpfiles $tmpfile
	} else {
	    ::UI::MessageBox -title [mc Error] -icon error -type ok \
	      -message "Failed importing: $errMsg"
	}
    }
}

proc ::ImageMagic::BuildDialog {w} {
    variable imageType
    variable finished
    
    ::UI::Toplevel $w -usemacmainmenu 1 -macstyle documentProc \
      -macclass {document closeBox}
    wm title $w {Take Snapshot}
    set finished -1
    
    # Global frame.
    ttk::frame $w.frall
    pack $w.frall -fill both -expand 1

    set wbox $w.frall.f
    ttk::frame $wbox -padding [option get . dialogPadding {}]
    pack $wbox -fill both -expand 1

    set msg "Click on a window in the desktop or drag a rectangular "
    append msg "area to import into the current whiteboard."
    ttk::label $wbox.msg -style Small.TLabel \
      -padding {0 0 0 6} -wraplength 300 -justify left \
      -text $msg
    pack $wbox.msg -side top -fill x -anchor w
    
    ttk::label $wbox.la -text {Captured image format:} -style Small.TLabel
    pack $wbox.la -side top -anchor w

    set frbt $wbox.frbt
    ttk::frame $frbt
    pack $frbt -side top -anchor w
    
    foreach type {bmp gif jpeg png tiff} {
	ttk::radiobutton $frbt.$type -text $type -style Small.TRadiobutton   \
	  -variable [namespace current]::imageType -value $type
	grid $frbt.$type -sticky w -padx 20 -pady 1
	
	# Verify that we've got an importer for the format.
	set theMime [::Types::GetMimeTypeForFileName x.$type]
	if {![::Media::HaveImporterForMime $theMime]} {
	    $frbt.$type configure -state disabled
	}
    }
    
    # Button part.
    set frbot     $wbox.b
    ttk::frame $frbot -padding [option get . okcancelTopPadding {}]
    ttk::button $frbot.btok -text [mc OK] -default active \
      -command [list set [namespace current]::finished 1]
    ttk::button $frbot.btcancel -text [mc Cancel] \
      -command [list set [namespace current]::finished 0]
    set padx [option get . buttonPadX {}]
    if {[option get . okcancelButtonOrder {}] eq "cancelok"} {
	pack $frbot.btok -side right
	pack $frbot.btcancel -side right -padx $padx
    } else {
	pack $frbot.btcancel -side right
	pack $frbot.btok -side right -padx $padx
    }
    pack $frbot -side bottom -fill x
    
    wm resizable $w 0 0
    bind $w <Return> [list $frbot.btok invoke]
    
    # Grab and focus.
    focus $w
    catch {grab $w}
    
    # Wait here for a button press.
    tkwait variable [namespace current]::finished
    
    catch {grab release $w}
    catch {destroy $w}    
    return $finished
}

# Clear Import files from in box
# Argument 
#     w
# 

proc ::ImageMagic::ClearImportFiles {wcan} {
    global  prefs
    
    variable tmpfiles

    if {$prefs(incomingFilePath) eq "" || [string match {*[*?]*} $prefs(incomingFilePath)]} {
	set msg "Dangerous in-box path name '$prefs(incomingFilePath)'"
	::UI::MessageBox -message $msg -icon warning
	return
    }
    if {![file exists $prefs(incomingFilePath)]} {
	file mkdir $prefs(incomingFilePath)
    }
    
    set all_files [glob -nocomplain [file join $prefs(incomingFilePath) {*}]]
    if {$all_files ==""} {
	return
    }
    set msg "Click OK to remove files :\n[join $all_files \n]"
    set ans [::UI::MessageBox -message $msg -type okcancel -icon warning]
    if {"$ans" eq "ok"} {
	foreach file $all_files {
	    file delete $file
	}
    }
}
