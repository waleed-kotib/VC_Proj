# AppleEvents.tcl --
# 
#       Experimental!
# 
# $Id: AppleEvents.tcl,v 1.2 2004-08-17 06:19:53 matben Exp $

namespace eval ::AppleEvents:: { }

proc ::AppleEvents::Init { } {
    global  tcl_platform this

    if {![string equal $this(platform) "macosx"]} {
	return
    }
    if {[catch {package require tclAE}]} {
	return
    }
    ::Debug 2 "::AppleEvents::Init"
    
 
    #tclAE::installEventHandler aevt GURL ::AppleEvents::HandleGURL

    #tclAE::installEventHandler aevt oapp aeom::handleOpenApp
    #tclAE::installEventHandler aevt rapp aeom::handleOpenApp
    #tclAE::installEventHandler aevt odoc aeom::handleOpen

    tclAE::installEventHandler aevt pdoc ::AppleEvents::PrintHandler

    # Mac OS X have the Quit menu on the Apple menu instead. Catch it!
    tclAE::installEventHandler aevt quit ::AppleEvents::QuitHandler

    # test...
    tclAE::installEventHandler WWW! OURL ::AppleEvents::HandleOURL
    
    component::register AppleEvents  \
      {Apple event handlers for Launch Services.}
}

proc ::AppleEvents::HandleOURL {theAppleEvent theReplyAE} {

    puts "theAppleEvent=$theAppleEvent"
    puts "theReplyAE=$theReplyAE"
}

proc ::AppleEvents::PrintHandler {theAppleEvent theReplyAE} {

    puts "theAppleEvent=$theAppleEvent"
    puts "theReplyAE=$theReplyAE"
    set eventClass [tclAE::getAttributeData $theAppleEvent evcl]
    set eventID [tclAE::getAttributeData $theAppleEvent evid]
    set pathDesc [tclAE::getKeyDesc $theAppleEvent ----]
    puts "eventClass=$eventClass, eventID=$eventID"
    puts "pathDesc=$pathDesc"
    
    
    #tclAE::disposeDesc $pathDesc

}

proc ::AppleEvents::HandleGURL {theAppleEvent theReplyAE} {
    
    puts "theAppleEvent=$theAppleEvent"
    puts "theReplyAE=$theReplyAE"
    set eventClass [tclAE::getAttributeData $theAppleEvent evcl]
    set eventID [tclAE::getAttributeData $theAppleEvent evid]
    
}

proc ::AppleEvents::QuitHandler {theAppleEvent theReplyAE} {
    
    ::UserActions::DoQuit
}

#-------------------------------------------------------------------------------
