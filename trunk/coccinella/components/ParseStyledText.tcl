#  ParseStyledText.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements simplified text font style parsing in messages.
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: ParseStyledText.tcl,v 1.1 2005-12-27 14:53:55 matben Exp $

namespace eval ::ParseStyledText:: {
    
}

proc ::ParseStyledText::Init { } {
    
    component::register ParseStyledText  \
      "Provides simplified text font style parsing in messages:\
      *bold*, /italic/, and _underline_."

    # Add event hooks.
    ::hooks::register textParseWordHook [namespace current]::ParseWordHook
    
    variable parse
    set parse {
	{^\*(.+)\*$}  -weight     bold      tbold
	{^/(.+)/$}    -slant      italic    titalic
	{^_(.+)_$}    -underline  1         tunderline
    }
}

proc ::ParseStyledText::ParseWordHook {type jid w word tagList} {
    variable parse
    
    set handled ""
    foreach {re name value ftag} $parse {
	if {[regexp $re $word m new]} {
	    set font ""
	    foreach tag $tagList {
		set font [$w tag cget $tag -font]
		if {$font ne ""} {
		    break
		}
	    }
	    if {$font ne ""} {
		array set fopts [font configure $font]
		set fopts($name) $value
		$w tag configure $ftag -font [array get fopts]
		$w insert end $new [concat $tagList $ftag]
	    }
	    set handled stop
	    break
	}
    }
    return $handled
}


