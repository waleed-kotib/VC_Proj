#  spell.tcl --
#  
#       Package to provide an interface to 'ispell' or 'aspell' and sets
#       ip bindings to a text widget for interactive spell checking.
#      
#  Copyright (c) 2007  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: spell.tcl,v 1.1 2007-10-20 14:10:19 matben Exp $

package provide spell 0.1

namespace eval spell {
    
    variable pipe
    
    variable static
}

proc spell::Init {} {   
    variable pipe

    # ispell and aspell install in /usr/local/bin on my Mac.
    set cmd [auto_execok ispell]
    if {![llength $cmd]} {
	set file [file join /usr/local/bin ispell]
	if {[file executable $file] && ![file isdirectory $file]} {
	    set cmd [list $file]
	} else {
	    set cmd [auto_execok aspell]
	    if {![llength $cmd]} {
		set file [file join /usr/local/bin aspell]
		if {[file executable $file] && ![file isdirectory $file]} {
		    set cmd [list $file]
		}
	    }
	}
    }
    if {[llength $cmd]} {
	set pipe [open |[list $cmd -a] r+]
	fconfigure $pipe -buffering line -blocking 0
	#fconfigure $pipe -encoding ???
	fileevent $pipe readable [namespace code Readable]
    } else {
	return -code error "Failed to find \"ispell\" or \"aspell\""
    }
}

proc spell::Readable {} {
    variable pipe

    if {[catch {eof $pipe} iseof] || $iseof} {
	return
    }
    if {[fblocked $pipe]} {
	return
    }
    set line [read $pipe]
    puts "spell::readable line=$line"
    
    set c [string index $line 0]
    if {$c eq "#"} {
	# Misspelled, no suggestions.
    } elseif {$c eq "&"} {
	# Misspelled, with suggestions.
	set word [lindex $line 1]
	set suggest [lrange $line 4 end]
	set suggest [lapply {string trimleft} [split $suggest ","]]
	puts "suggest=$suggest"

	set suggestions($word) $suggest
    }
}

# spell::new --
# 
#       Constructor for interactive spell checking text widget.

proc spell::new {w} {
    variable pipe
    
    if {[winfo class $w] ne "Text"} {
	return -code error "Usage: spell::new textWidget"
    }
    if {![info exists pipe]} {
	Init
    }
    variable $w
    upvar 0 $w state
    
    Bindings $w
    
}

proc spell::Bindings {w} {
    
    bind $w <KeyPress> {+spell::Event %W %A %K}
    bind $w <Destroy>  {+spell::Free %W}
}

proc spell::Event {w A K} {
    
    puts "spell::Event A=$A, K=$K"
    
    switch -- $K {
	space - Return - Tab {
	    
	    set idx2 [$w index "insert"]
	    set idx1 [$w index "$idx2 -1c wordstart"]
	    set word [$w get $idx1 $idx2]
	    puts "idx1=$idx1, idx2=$idx2, word=$word"
	    Word $w $word
	}
    }
    
    
}

proc spell::Word {w word} {
    variable $w
    upvar 0 $w state
    variable pipe
    variable static
    
    set static(w) $w
    
    puts $pipe $word
}

proc spell::Free {w} {
    variable $w
    upvar 0 $w state
    
    unset -nocomplain $w
}

if {0} {
    toplevel .tt
    pack [text .tt.t]
    spell::new .tt.t
    
}
