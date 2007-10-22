#  spell.tcl --
#  
#       Package to provide an interface to 'ispell' or 'aspell' and sets
#       ip bindings to a text widget for interactive spell checking.
#      
#  Copyright (c) 2007  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: spell.tcl,v 1.4 2007-10-22 15:20:23 matben Exp $

package provide spell 0.1

namespace eval spell {
    
    variable pipe
    variable spellers [list ispell aspell]
    variable static
    set static(w) -
    
    bind SpellText <KeyPress> {spell::Event %W %A %K}
    bind SpellText <Destroy>  {spell::Free %W}
    bind SpellText <Button-1> {spell::Move %W}
    bind SpellText <FocusOut> {spell::CheckWord %W insert}
}

# spell::init --
# 
#       This serves to init any spell checker tools. It can also be used to
#       test if spell checking available.

proc spell::init {} {   
    variable pipe
    variable spellers
    variable static
    
    if {[info exists pipe] && ([lsearch [file channels] $pipe] >= 0)} {
	return
    }
    foreach s $spellers {
	set cmd [AutoExecOK $s]
	if {[llength $cmd]} {
	    set static(speller) $s
	    break
	}
    }
    if {[llength $cmd]} {
	
	# aspell also understands -a which means it runs as ispell
	set pipe [open |[list $cmd -a] r+]
	fconfigure $pipe -buffering line -blocking 1
	if {$static(speller) eq "ispell"} {
	    #fconfigure $pipe -encoding latin1
	} elseif {$static(speller) eq "aspell"} {
	    fconfigure $pipe -encoding utf-8
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

# spell::Readable --
# 
#       Read and process result from speller.

proc spell::Readable {} {
    variable pipe
    variable static

    if {[catch {eof $pipe} iseof] || $iseof} {
	return
    }
    if {[fblocked $pipe]} {
	return
    }
    set line [read $pipe]
    set line [string trimright $line]
    puts "spell::Readable line='$line'"
    
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
	#puts "suggest=$suggest"

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
    $w tag configure spell-err -foreground red
    Bindings $w    
}

proc spell::Bindings {w} {
    
    # We must handle text *after* any character has been inserted or removed.
    if {[lsearch [bindtags $w] SpellText] < 0} {
	set idx [lsearch [bindtags $w] Text]
	bindtags $w [linsert [bindtags $w] [incr idx] SpellText]
    }
}

proc spell::Move {w} {
    variable $w
    upvar 0 $w state
    
    puts "spell::Move"
    if {[info exists state(lastIn)]} {
	
	# Check both sides.
	set ind $state(lastIn)
	set left  [$w get "$ind -1c"]
	set right [$w get "$ind"]
	set isleft  [string is wordchar -strict $left]
	set isright [string is wordchar -strict $right]
	if {$isleft} {
	    CheckWord $w "$ind -1c"
	}
	if {$isright} {
	    CheckWord $w "$ind"
	}
    }
}

proc spell::Event {w A K} {
    variable $w
    upvar 0 $w state
    variable static
    
    # Check a word when we think we 
    # 1) have finished typing it
    # 2) editing it
    set ischar [string is wordchar -strict $A]

    set left  [$w get "insert -1c"]
    set right [$w get "insert"]
    set isleft  [string is wordchar -strict $left]
    set isright [string is wordchar -strict $right]
    
    set ismove 0
    set isspace 0
    set isdel 0
    set isedit $ischar
    switch -- $K space - Return - Tab {set isspace 1}
    switch -- $K space - Return - Tab - BackSpace - Delete {set isedit 1}
    switch -- $K BackSpace - Delete {set isdel 1}
    switch -- $K Left - Right - Up - Down {set ismove 1}
    
    puts "spell::Event A=$A, K=$K, ischar=$ischar, isedit=$isedit, ismove=$ismove\
\t left=$left, right=$right, isleft=$isleft, isright=$isright"
    
    if {$isedit && $isleft && $isright} {
	
	# Edit single word.
	puts "---> edit & left & right"
	CheckWord $w insert
    } elseif {$isspace} {
	
	# Check left word.
	puts "---> space"
	CheckWord $w "insert -2c"
    } elseif {$isdel && $isleft} {
	puts "---> del & left"
	Move $w
    } elseif {$ismove && (($isleft && !$isright) || (!$isleft && $isright))} {
	puts "---> move"
	Move $w
    }    
    set state(lastA) $A
    set state(lastK) $K
    set state(lastIn) [$w index insert]
    set state(lastIsChar) $ischar
}

proc spell::GetWord {w ind} {
    set idx1 [$w index "$ind wordstart"]
    set idx2 [$w index "$ind wordend"]
    return [$w get $idx1 $idx2]
}

proc spell::CheckWord {w ind} {
    variable static
    
    set idx1 [$w index "$ind wordstart"]
    set idx2 [$w index "$ind wordend"]
    set word [$w get $idx1 $idx2]
    set isword [string is wordchar -strict $word]
    
    puts "spell::CheckWord idx1=$idx1, idx2=$idx2, word=$word"
    
    if {$isword} {
	set static(w) $w
	set static(idx1) $idx1
	set static(idx2) $idx2
	Word $word
    }
}

proc spell::Word {word} {
    variable pipe
    
    # Must stop user from doing special processing in spell checker
    # by removing any special instruction characters.
    set word [string trimleft $word "*&@+-~#!%`^"]
    if {[catch {
	puts $pipe $word
    }]} {
	# error
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
    pack [text .tt.t -width 60 -font {{Lucida Grande} 16}]
    spell::new .tt.t
    set w .tt.t
    
}
