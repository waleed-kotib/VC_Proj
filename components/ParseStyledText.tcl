#  ParseStyledText.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements simplified text font style parsing in messages.
#      
#  Copyright (c) 2005  Mats Bengtsson
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
# $Id: ParseStyledText.tcl,v 1.7 2007-11-01 15:59:00 matben Exp $

namespace eval ::ParseStyledText {}

proc ::ParseStyledText::Init {} {
    
    component::register ParseStyledText \
      "Simplified text font style parsing: *bold*, /italic/, and _underline_."

    # Add event hooks.
    ::hooks::register textParseWordHook [namespace code ParseWordHook]
    ::pipes::register htmlParseWordPipe [namespace code ParseWordPipe]
    
    variable parse
    set parse {
	{^\*(.+)\*$}  -weight     bold      tbold
	{^/(.+)/$}    -slant      italic    titalic
	{^_(.+)_$}    -underline  1         tunderline
    }

    variable phtml
    set phtml {
	{^\*(.+)\*$}  {<b>\1</b>}
	{^/(.+)/$}    {<i>\1</i>}
	{^_(.+)_$}    {<u>\1</u>}
    }
}

proc ::ParseStyledText::ParseWordPipe {type jid word} {
    variable phtml
    
    foreach {re sub} $phtml {
	if {[regsub -- $re $word $sub word]} {
	    return $word
	}
    }
    return $word
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
		array set fopts [font actual $font]
		set fopts($name) $value
		$w tag configure $ftag -font [array get fopts]
		$w insert insert $new [concat $tagList $ftag]
	    }
	    set handled stop
	    break
	}
    }
    return $handled
}


