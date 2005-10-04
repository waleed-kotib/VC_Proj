#  ParseMeCData.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements /me parsing in messages.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: ParseMeCData.tcl,v 1.2 2005-10-04 06:24:26 matben Exp $

namespace eval ::ParseMeCData:: {
    
    option add *parseMeCDataOpts      {-foreground blue}     widgetDefault
}

proc ::ParseMeCData::Init { } {
    
    component::register ParseMeCData "Provides /me parsing in messages."

    # Add event hooks.
    ::hooks::register textParseWordHook [namespace current]::ParseWordHook
}

proc ::ParseMeCData::ParseWordHook {type jid w word tagList} {
    
    set handled ""
    if {[string trim $word {;.,}] eq "/me"} {

	switch -- $type {
	    groupchat {
		jlib::splitjid $jid roomjid nick
	    }
	    chat {
		jlib::splitjid $jid jid2 res
		if {[::Jabber::JlibCmd service isroom $jid2]} {
		    set nick $jid
		} else {
		    set nick $jid2
		}
	    }
	    default {
		jlib::splitjid $jid nick -
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


