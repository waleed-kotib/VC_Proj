#  Spell.tcl --
#  
#      This file is part of The Coccinella application. 
#      It provides an application interface to the 'spell' package.
#      
#  Copyright (c) 2007  Mats Bengtsson
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
# $Id: Spell.tcl,v 1.8 2007-11-06 15:01:23 matben Exp $

package require spell

namespace eval ::Spell {}

proc ::Spell::Init {} {
    global  tcl_platform this
    
    if {$tcl_platform(platform) eq "windows"} {
	set programs {C:\Program}
	if {[info exists ::env(ProgramFiles)]} {
	    set programs $::env(ProgramFiles)
	}
	spell::addautopath [file join $programs Aspell bin]
    }
    if {![spell::have]} {
	return
    }
    set speller [spell::speller]
    
    component::register Spell \
      "Provides an interface to the aspell and ispell spellers."

    set menuDef {checkbutton mCheckSpell      {::Spell::OnMenu}  {} \
      {-variable ::Spell::state(on)}}
    ::JUI::RegisterMenuEntry info $menuDef
    if {$speller eq "aspell"} {
	set menuDef {cascade mDictionaries      {}  {} }
	::JUI::RegisterMenuEntry info $menuDef
    }

    # Add event hooks.
    ::hooks::register prefsInitHook         [namespace code InitPrefsHook]
    ::hooks::register textSpellableNewHook  [namespace code TextHook]
    ::hooks::register menuPostCommand       [namespace code MenuPost]
    
    variable wall [list]
}

proc ::Spell::InitPrefsHook {} {
    variable state

    set state(on)   0    
    set state(dict) en
    
    ::PrefUtils::Add [list  \
      [list ::Spell::state(on)   spell_state_on   $state(on)] \
      [list ::Spell::state(dict) spell_state_dict $state(dict)] \
      ]
    spell::setdict $state(dict)
}

proc ::Spell::OnMenu {} {
    variable state
    variable wall
    
    if {$state(on)} {
	foreach w $wall {
	    spell::new $w
	    
	    # @@@ We must have a kind of plugin architecture here so it is
	    # possible to add multiple popup menu entries.
	    # Generic text binding <<ButtonPopup>> that just does ::hooks::run
	    # Interested parties that have registered for the hook then make
	    # a call and add their menu entries if any. Then the generic 
	    # code is able to display menu or not.

	    bind $w <<ButtonPopup>> [namespace code [list Popup %W %x %y]]
	}
    } else {
	Clear
    }
}

proc ::Spell::MenuPost {which wmenu} {
    
    if {$which eq "main-info"} {
	set m [::UI::MenuMethod $wmenu entrycget mDictionaries -menu]
	
	# ispell doesn't put the dict menu there.
	if {$m eq ""} {
	    return
	}
	$m delete 0 end
	set dicts [spell::alldicts]
	foreach dict $dicts {
	    $m add radiobutton -label $dict -value $dict \
	      -variable [namespace current]::state(dict) \
	      -command [namespace code [list SetDict $dict]]
	}
	update idletasks
    }
}

proc ::Spell::Clear {} {
    variable wall
    
    foreach w $wall {
	spell::clear $w
	bind $w <<ButtonPopup>> {}
    }
}

proc ::Spell::SetDict {name} {
    
    spell::reset
    Clear
    spell::setdict $name
    spell::init
    OnMenu
}

proc ::Spell::Popup {w x y} {
    variable pop
    
    set word [spell::GetWord $w current]
    set isword [string is wordchar -strict $word]
    if {$isword} {
	lassign [spell::wordserial $word] correct suggest
	if {!$correct && [llength $suggest]} {
	    lassign [spell::GetWordIndices $w current] idx1 idx2
	    set pop(idx1) $idx1
	    set pop(idx2) $idx2
	    set pop(word) $word
	    set menu $w.menuspell
	    catch {destroy $menu}
	    menu $menu -tearoff 0
	    foreach s $suggest {
		$menu add command -label $s \
		  -command [namespace code [list Cmd $w $s]]
	    }
	    $menu add separator
	    $menu add command -label [mc mAddToDictionary] \
	      -command [namespace code [list AddWord $w]]
	    set X [expr [winfo rootx $w] + $x]
	    set Y [expr [winfo rooty $w] + $y]
	    tk_popup $menu [expr int($X) - 10] [expr int($Y) - 10]   
	    update
	    bind $menu <Unmap> {after idle {catch {destroy %W}}}	    
	}
    }
}

proc ::Spell::Cmd {w new} {
    variable pop

    # Try to preserver cases to some extent.
    if {[string is lower $pop(word)]} {
	set str [string tolower $new]
    } elseif {[string is upper $pop(word)]} {
	set str [string toupper $new]
    } elseif {[string is upper [string index $pop(word) 0]]} {
	set str [string toupper [string index $new 0]][string range $new 1 end]
    } else {
	set str $new
    }
    $w delete $pop(idx1) $pop(idx2)
    $w insert $pop(idx1) $str
    unset -nocomplain pop
}

proc ::Spell::AddWord {w} {
    variable pop
    spell::addword $pop(word)
}

proc ::Spell::TextHook {w} {
    variable wall
    variable state

    if {$state(on)} {
	spell::new $w
	bind $w <<ButtonPopup>> [namespace code [list Popup %W %x %y]]
    }
    bind $w <Destroy> {+Spell::OnDestroy %W}
    lappend wall $w
}

proc Spell::OnDestroy {w} {
    variable wall
    lprune wall $w
}

