# URIRegistry.tcl --
# 
# <a href='xmpp:jid[?query]'/>
# 
# $Id: URIRegistry.tcl,v 1.6 2005-08-14 08:37:51 matben Exp $

namespace eval ::URIRegistry:: { }

proc ::URIRegistry::Init { } {
    global  tcl_platform this

    if {![string equal $tcl_platform(platform) "windows"]} {
	return
    }
    if {[catch {package require registry}]} {
	return
    }
    ::Debug 2 "::URIRegistry::Init"
    
    # Find the exe we are running. Starkits?
    if {[info exists ::starkit::topdir]} {
	set exe [file nativename [info nameofexecutable]]
	set cmd "\"$exe\" -uri \"%1\""
    } else {
	set exe [file nativename [info nameofexecutable]]
	set app [file nativename $this(script)]
	set cmd "\"$exe\" \"$app\" -uri \"%1\""
    }
    if {[catch {
	registry set HKEY_CLASSES_ROOT\\xmpp {} "URL:xmpp Protocol"
	registry set HKEY_CLASSES_ROOT\\xmpp "URL Protocol" {}
	registry set HKEY_CLASSES_ROOT\\xmpp\\Shell
	registry set HKEY_CLASSES_ROOT\\xmpp\\Shell\\open
	registry set HKEY_CLASSES_ROOT\\xmpp\\Shell\\open\\command {} $cmd
    }]} {
	return 
    }
    component::register URIRegistry  \
      {Automatically adds an registry entry so that this program is\
      launched when clicking an uri <a href='xmpp:jid[?query]'/>.}
}

#-------------------------------------------------------------------------------
