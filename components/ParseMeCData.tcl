#  ParseMeCData.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements /me parsing in messages.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: ParseMeCData.tcl,v 1.1 2005-08-14 08:37:51 matben Exp $

namespace eval ::ParseMeCData:: {
    
    option add *parseMeCDataOpts      {-foreground blue}     widgetDefault
}

proc ::ParseMeCData::Init { } {
    
    component::register ParseMeCData "Provides /me parsing in messages."

    # Add event hooks.
    ::hooks::register textParseWordHook [list [namespace current]::ParseWordHook]
}

proc ::ParseMeCData::ParseWordHook {type jid w word tagList} {
    
    set handled ""
    if {[string trim $word {;.,}] eq "/me"} {

	switch -- $type {
	    groupchat {
		jlib::splitjid $jid roomjid nick
	    }
	    chat {
		jlib::splitjid $jid nick x
	    }
	    default {
		jlib::splitjid $jid nick x
	    }
	}
	set wd [string map [list "/me" "* $nick"] $word]
	set meopts [option get . parseMeCDataOpts {}]
	eval {$w tag configure tmecdata} $meopts
	$w insert end $wd [concat $tagList tmecdata]
	set handled stop
    }
    return $handled
}


