# AppleEvents.tcl --
# 
# 
# $Id: AppleEvents.tcl,v 1.1 2004-08-15 06:55:21 matben Exp $

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

    
    component::register AppleEvents  \
      {Apple event handlers for Launch Services.}
}

proc ::AppleEvents::PrintHandler {theAESubDesc theReplyAE} {

    puts "theAESubDesc=$theAESubDesc"
    puts "theReplyAE=$theReplyAE"
    
}

proc ::AppleEvents::HandleGURL {theAESubDesc theReplyAE} {
    
    puts "theAESubDesc=$theAESubDesc"
    puts "theReplyAE=$theReplyAE"
    set code [tclAE::subdesc::getKeyData $theAESubDesc ----]
    

}

proc ::AppleEvents::QuitHandler {theAESubDesc theReplyAE} {
    
    ::UserActions::DoQuit
}

#-------------------------------------------------------------------------------
