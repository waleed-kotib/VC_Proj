# URIRegistry.tcl --
# 
# <a href='xmpp:...'/>
# 
# $Id: URIRegistry.tcl,v 1.1 2004-07-26 12:52:17 matben Exp $

namespace eval ::URIRegistry:: {
    
}

proc ::URIRegistry::Init { } {
    global  tcl_platform

    if {![string equal $tcl_platform(platform) "windows"]} {
	return
    }
    if {catch {package require registry}} {
	return
    }
    ::Debug 2 "::URIRegistry::Init"
    

    
    component::register URIRegistry  \
      "Automatically adds an registry entry so that this programe is\
      launched when clicking an uri <a href='xmpp:...'/>."
}

#-------------------------------------------------------------------------------
