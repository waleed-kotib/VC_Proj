#  spell.tcl --
#  
#       Package to provide an interface to 'ispell' or 'aspell' and sets
#       ip bindings to a text widget for interactive spell checking.
#      
#  Copyright (c) 2007  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: spell.tcl,v 1.2 2007-10-21 14:29:09 matben Exp $

package provide spell 0.1

namespace eval spell {
    
    variable pipe
    
    variable static
    set static(w) -
}

# spell::init --
# 
#       This serves to init any spell checker tools. It can also be used to
#       test if spell checking available.

proc spell::init {} {   
    variable pipe
    variable static
    
    if {[info exists pipe]} {
	return
    }

    set cmd [AutoExecOK ispell]
    if {![llength $cmd]} {
	set cmd [AutoExecOK aspell]
	if {[llength $cmd]} {
	    set static(speller) aspell
	}
    } else {
	set static(speller) ispell
    }
    if {[llength $cmd]} {
	
	# aspell also understands -a which means it runs as ispell
	set pipe [open |[list $cmd -a] r+]
	fconfigure $pipe -buffering line -blocking 1
	if {$static(speller) eq "ispell"} {
	    #fconfigure $pipe -encoding latin1
	}
	set line [gets $pipe]
	puts "line=$line"
	if {[string range $line 0 3] ne "@(#)"} {
	    return -code error "Wrong identification line: \"$line\""
	}
	fconfigure $pipe -blocking 0
	fileevent $pipe readable [namespace code Readable]
    } else {
	return -code error "Failed to find \"ispell\" or \"aspell\""
    }
}

proc spell::AutoExecOK {name} {
    
    # ispell and aspell install in /usr/local/bin on my Mac.
    set cmd [auto_execok $name]
    if {![llength $cmd]} {
	set file [file join /usr/local/bin $name]
	if {[file executable $file] && ![file isdirectory $file]} {
	    set cmd [list $file]
	}
    }
    return $cmd
}

proc spell::Readable {} {
    variable pipe
    variable static

    if {[catch {eof $pipe} iseof] || $iseof} {
	return
    }
    if {[fblocked $pipe]} {
	return
    }
    set line [gets $pipe]
    puts "spell::readable line=$line"
    
    if {![winfo exists $static(w)]} {
	return
    }
    set w    $static(w)
    set idx1 $static(idx1)
    set idx2 $static(idx2)
    
    set c [string index $line 0]
    if {$c eq "#"} {
	# Misspelled, no suggestions.
	$w tag add spell-err $idx1 $idx2
    } elseif {$c eq "&"} {
	# Misspelled, with suggestions.
	set word [lindex $line 1]
	set suggest [lrange $line 4 end]
	set suggest [lapply {string trimleft} [split $suggest ","]]
	puts "suggest=$suggest"

	set suggestions($word) $suggest
	$w tag add spell-err $idx1 $idx2
	
    } elseif {$c eq "?"} {
	
	
    } elseif {($c eq "*") || ($c eq "+") || ($c eq "-")} {
	$w tag remove spell-err $idx1 $idx2
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
	init
    }
    variable $w
    upvar 0 $w state
    
    $w tag configure spell-err -foreground red
    Bindings $w
    
}

proc spell::Bindings {w} {
    
    # We must handle text *after* any character has been inserted or removed.
    if {[lsearch [bindtags $w] SpellText] < 0} {
	set idx [lsearch [bindtags $w] Text]
	bindtags $w [linsert [bindtags $w] [incr idx] SpellText]
    }
    
    bind SpellText <KeyPress> {spell::Event %W %A %K}
    bind SpellText <Destroy>  {spell::Free %W}
}

proc spell::Event {w A K} {
    variable $w
    upvar 0 $w state
    variable static
    
    set ischar [string is wordchar -strict $A]
    puts "spell::Event A=$A, K=$K, ischar=$ischar"

    set left  [$w get "insert -1c"]
    set right [$w get "insert"]
    puts "\t left=$left, right=$right"
    set isleft  [string is wordchar -strict $left]
    set isright [string is wordchar -strict $right]
    
    if {$isleft && $isright} {
	set idx1 [$w index "insert wordstart"]
	set idx2 [$w index "insert wordend"]
	puts "+++word=[$w get $idx1 $idx2]"
	
    } else {
	
    }
    
    switch -- $K {
	space - Return - Tab {
	    
	    set idx2 [$w index "insert"]
	    set idx1 [$w index "$idx2 -2c wordstart"]
	    set word [$w get $idx1 $idx2]
	    puts "idx1=$idx1, idx2=$idx2, word=$word"
	    set static(w) $w
	    set static(idx1) $idx1
	    set static(idx2) $idx2
	    Word $w $word
	}
	Left - Right - Up - Down {


	}
    }
    
    set state(lastA) $A
    set state(lastK) $K
}

proc spell::Word {w word} {
    variable $w
    upvar 0 $w state
    variable pipe
    variable static
    
    # Must stop user from doing special processing in spell checker
    # by removing any special instruction characters.
    set word [string trimleft $word "*&@+-~#!%`^"]
    if {[catch {
	puts $pipe $word
    }]} {
	
    }
}

proc spell::lapply {cmd alist} {
    set applied [list]
    foreach e $alist {
	lappend applied [uplevel $cmd [list $e]]
    }
    return $applied
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
    set w .tt.t
    
}
