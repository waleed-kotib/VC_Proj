# AppleEvents.tcl --
# 
#       Experimental!
#       Some code from Alpha.
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
# $Id: AppleEvents.tcl,v 1.10 2008-02-20 15:14:37 matben Exp $

namespace eval ::AppleEvents {
    
    # Bails with: 
    #     Thread 0 Crashed:
    # 0   libSystem.B.dylib             	0x94a1547a __kill + 10
    # 1   libSystem.B.dylib             	0x94a8c782 raise + 26
    # 2   libSystem.B.dylib             	0x94a9bd3f abort + 73
    # 3   com.tcltk.tcllibrary          	0x0a07f1c2 Tcl_Panic + 0
    # 4   com.tcltk.tcllibrary          	0x0a07f1dd Tcl_Panic + 27
    # 5   com.tcltk.tcllibrary          	0x0a096a4d TclpFree + 104
    # 6   com.tcltk.tcllibrary          	0x0a07ccb4 TclFreeObj + 208
    # 7   com.tcltk.tcllibrary          	0x0a0a2beb Tcl_ObjSetVar2 + 123
    # 8   com.tcltk.tcllibrary          	0x0a0a2c8e Tcl_SetVar2Ex + 96
    # 9   net.jguyer.tclae              	0x0ec5b474 TclaeInitObjectAccessors + 87
    # 10  net.jguyer.tclae              	0x0ec59a5e Tclae_Init + 317
    # 11  com.tcltk.tcllibrary          	0x0a0732ba Tcl_LoadObjCmd + 2164
    
    return
    
    if {![string equal $::this(platform) "macosx"]} {
	return
    }
    if {[catch {package require tclAE}]} {
	return
    }
    component::define AppleEvents "Apple event handlers for Launch Services."
}

proc ::AppleEvents::Init {} {

    ::Debug 2 "::AppleEvents::Init"    
 
    #tclAE::installEventHandler aevt GURL ::AppleEvents::HandleGURL

    tclAE::installEventHandler aevt oapp ::AppleEvents::OpenAppHandler
    tclAE::installEventHandler aevt rapp ::AppleEvents::OpenAppHandler
    tclAE::installEventHandler aevt odoc ::AppleEvents::OpenHandler
    tclAE::installEventHandler aevt pdoc ::AppleEvents::PrintHandler

    # Mac OS X have the Quit menu on the Apple menu instead. Catch it!
    tclAE::installEventHandler aevt quit ::AppleEvents::QuitHandler

    # test...
    tclAE::installEventHandler WWW! OURL ::AppleEvents::HandleOURL
    
    component::register AppleEvents
}

proc ::AppleEvents::HandleOURL {theAppleEvent theReplyAE} {

    ::Debug 4 "::AppleEvents::HandleOURL theAppleEvent=$theAppleEvent"

    
}

proc ::AppleEvents::OpenAppHandler {theAppleEvent theReplyAE} {

    # Have no idea of what to do here...
    ::Debug 4 "::AppleEvents::OpenAppHandler theAppleEvent=$theAppleEvent"
    set eventClass [tclAE::getAttributeData $theAppleEvent evcl]
    set eventID [tclAE::getAttributeData $theAppleEvent evid]
    ::Debug 4 "\t eventClass=$eventClass, eventID=$eventID"
    
    
}

proc ::AppleEvents::OpenHandler {theAppleEvent theReplyAE} {

    ::Debug 4 "::AppleEvents::OpenHandler theAppleEvent=$theAppleEvent"
    set pathDesc [tclAE::getKeyDesc $theAppleEvent ----]
    set paths [ExtractPaths $pathDesc wasList]
    tclAE::disposeDesc $pathDesc
    ::Debug 4 "\t paths=$paths"

    foreach f $paths {	
	switch -- [file extension $f] {
	    .can {
		::WB::NewWhiteboard -file $f
	    }
	}
    }
}

proc ::AppleEvents::PrintHandler {theAppleEvent theReplyAE} {

    set pathDesc [tclAE::getKeyDesc $theAppleEvent ----]
    set paths [ExtractPaths $pathDesc wasList]
    tclAE::disposeDesc $pathDesc

    foreach f $paths {	
	switch -- [file extension $f] {
	    .can {
		set w [::WB::NewWhiteboard -file $f]
		set wcan [::WB::GetCanvasFromWtop $w]
		::UserActions::DoPrintCanvas $wcan
	    }
	}
    }
}

proc ::AppleEvents::HandleGURL {theAppleEvent theReplyAE} {
    
    puts "theAppleEvent=$theAppleEvent"
    set eventClass [tclAE::getAttributeData $theAppleEvent evcl]
    set eventID [tclAE::getAttributeData $theAppleEvent evid]
    
}

proc ::AppleEvents::QuitHandler {theAppleEvent theReplyAE} {
    
    ::UserActions::DoQuit
}

proc ::AppleEvents::ExtractPaths {files {wasList ""}} {
    
    set paths {}
    upvar 1 $wasList listOfPaths
    
    switch -- [tclAE::getDescType $files] {
	"list" {
	    set count [tclAE::countItems $files]
	    
	    for {set item 0} {$item < $count} {incr item} {
		set fileDesc [tclAE::getNthDesc $files $item]		
		lappend paths [ExtractPath $fileDesc]
		tclAE::disposeDesc $fileDesc
	    }
	    set listOfPaths 1
	}
	default {
	    lappend paths [ExtractPath $files]
	    set listOfPaths 1
	}
    }
    return $paths
}

proc ::AppleEvents::ExtractPath {fileDesc} {

    set alisDesc [tclAE::coerceDesc $fileDesc alis]
    set path [tclAE::getData $alisDesc TEXT]
    tclAE::disposeDesc $alisDesc    
    
    return $path
}

#-------------------------------------------------------------------------------
