# AppleEvents.tcl --
# 
#       Experimental!
#       Some code from Alpha.
# 
# $Id: AppleEvents.tcl,v 1.5 2004-11-30 15:11:10 matben Exp $

namespace eval ::AppleEvents:: { }

proc ::AppleEvents::Init { } {
    global  this

    if {![string equal $this(platform) "macosx"]} {
	return
    }
    if {[catch {package require tclAE}]} {
	return
    }
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
    
    component::register AppleEvents  \
      {Apple event handlers for Launch Services.}
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
		set wtop [::WB::NewWhiteboard -file $f]
		::UserActions::DoPrintCanvas $wtop
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
