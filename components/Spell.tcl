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
# $Id: Spell.tcl,v 1.1 2007-10-23 13:48:59 matben Exp $

package require spell

namespace eval ::Spell {}

proc ::Spell::Init {} {
    
    if {![spell::have]} {
	return
    }
    component::register Spell \
      "Provides an interface to the aspell and ispell spellers."

    set menuDef {checkbutton mSpellCheck      {::Spell::OnMenu}  {} \
      {-variable ::Spell::state(on)}}
    ::JUI::RegisterMenuEntry info $menuDef

    # Add event hooks.
    ::hooks::register prefsInitHook         [namespace code InitPrefsHook]
    ::hooks::register textSpellableNewHook  [namespace code TextHook]
    
    variable wall [list]
}

proc ::Spell::InitPrefsHook {} {
    variable state

    set state(on) 0    
    ::PrefUtils::Add [list [list state(on) spell_state_on $state(on)] ]
}

proc ::Spell::OnMenu {} {
    variable state
    variable wall
    
    puts "::Spell::OnMenu $state(on)"
    if {$state(on)} {
	foreach w $wall {
	    # @@@ Shall have a method to check complete text widget.
	    spell::new $w
	}
    } else {
	foreach w $wall {
	    spell::clear $w
	}
    }
}

proc ::Spell::TextHook {w} {
    variable wall
    variable state

    if {$state(on)} {
	spell::new $w
    }
    bind $w <Destroy> {+Spell::OnDestroy %W}
    lappend wall $w
}

proc Spell::OnDestroy {w} {
    variable wall
    lprune wall $w
}

