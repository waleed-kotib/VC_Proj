# ImageMagic.tcl --
# 
# ImportWindowSnapShot
# Depends on ImageMagic installation
# Contributed by Raymond Tang, adapted as a plugin by Mats Bengtsson.
# 
# Unix/Linux only.
#
# $Id: ImageMagic.tcl,v 1.1 2004-07-23 12:43:02 matben Exp $

namespace eval ::ImageMagic:: {
    
    variable imageType gif
}

proc ::ImageMagic::Init { } {
    global  env tcl_platform
    variable imageType
    variable haveImageMagic
    
    set infile import
    set haveImageMagic 0
    if {[string equal $tcl_platform(platform) "unix"]} {
	foreach name [split $env(PATH) :] {
	    set filename [file join $name $infile]
	    if {[file exists $filename] && [file executable $filename]} {
		set haveImageMagic 1
		break
	    }
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
	    command [mc {Take Snapshot}] {::ImageMagic::ImportWindowSnapShot $wtop} normal {} {} {} \
	]
	::UI::Public::RegisterNewMenu addon [mc mAddons] $menuspec
    }
}

proc ::ImageMagic::ImportWindowSnapShot {wtop} {
    global  env thisHostname prefs
    
    variable imageType
    variable tmpfiles
    variable haveImageMagic
    
    set wCan [::WB::GetCanvasFromWtop $wtop]
    
    if {$haveImageMagic == 0} {
	tk_messageBox -icon error -type ok -message  \
	  "Failed to locate ImageMagic package! Can't do screen snap shot :-("
	return
    }
    set ans [::ImageMagic::BuildDialog .imagic]
    update
    
    if {$ans == "1"} {
	set importapps [exec which import]
	set pidname [format "%x" [format %d [pid]]]
	set tmpname ${pidname}[format "%x" [clock clicks]]
	set tmpfile [file join [glob $prefs(incomingPath)]  \
	  $tmpname.$imageType]
	# puts "// Info - Snap shot window using $importapps ..."
	exec $importapps $tmpfile
	# import to current canvas
	set optList [list -coords [::CanvasUtils::NewImportAnchor $wCan]]
	set errMsg [::Import::DoImport $wCan $optList -file $tmpfile]
	if {$errMsg == ""} {
	    lappend tmpfiles $tmpfile
	} else {
	    tk_messageBox -title [mc Error] -icon error -type ok \
	      -message "Failed importing: $errMsg"
	}
    }
}

proc ::ImageMagic::BuildDialog {w} {
    variable imageType
    variable finished
    
    toplevel $w
    wm title $w {Take Snapshot}
    set finished -1
    set fontS [option get . fontSmall {}]
    set fontSB [option get . fontSmallBold {}]
    
    # Global frame.
    frame $w.frall -borderwidth 1 -relief raised
    pack  $w.frall -fill both -expand 1
    set msg {Click on a window in the desktop or drag a rectangular }
    append msg {area to import into the current whiteboard.}
    message $w.frall.msg -width 260 -font $fontS -text $msg
    pack $w.frall.msg -side top -fill both -expand 1
    
    pack [label $w.frall.la -text {Captured image format:} -font $fontSB]\
      -side top -padx 10 -pady 4 -anchor w
    set frbt $w.frall.frbt
    pack [frame $frbt] -side top -padx 20 -pady 4 -anchor w
    foreach type {bmp gif jpeg png tiff} {
	radiobutton ${frbt}.${type} -text $type -font $fontS   \
	  -variable [namespace current]::imageType -value $type
	grid ${frbt}.${type} -sticky w -padx 20 -pady 1
	
	# Verify that we've got an importer for the format.
	set theMime [::Types::GetMimeTypeForFileName x.$type]
	if {![::Plugins::HaveImporterForMime $theMime]} {
	    ${frbt}.${type} configure -state disabled
	}
    }
    
    # Button part.
    set frbot [frame $w.frall.frbot -borderwidth 0]
    pack [button $frbot.btok -text [mc OK] -default active \
      -command [list set [namespace current]::finished 1]]  \
      -side right -padx 5 -pady 5
    pack [button $frbot.btcancel -text [mc Cancel] \
      -command [list set [namespace current]::finished 0]]  \
      -side right -padx 5 -pady 5
    pack $frbot -side top -fill both -expand 1 -padx 8 -pady 6
    
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

proc ::ImageMagic::ClearImportFiles { wCan } {
    global env thisHostname prefs
    
    variable tmpfiles

    if {$prefs(incomingFilePath) == "" || [string match {*[*?]*} $prefs(incomingFilePath)]} {
	set msg "Dangerous in-box path name '$prefs(incomingFilePath)'"
	tk_messageBox -message $msg -icon warning
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
    set ans [tk_messageBox -message $msg -type okcancel -icon warning]
    if {"$ans" == "ok"} {
	foreach file $all_files {
	    file delete $file
	}
    }
}
