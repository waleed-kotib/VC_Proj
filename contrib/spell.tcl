#  spell.tcl --
#  
#       Package to provide an interface to 'ispell' and 'aspell' and sets
#       up bindings to a text widget for interactive spell checking.
#      
#  Copyright (c) 2007  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: spell.tcl,v 1.5 2007-10-23 08:01:53 matben Exp $

package provide spell 0.1

namespace eval spell {
    
    variable pipe
    variable spellers [list ispell aspell]
    variable static
    variable trigger
    
    set static(w) -
    set static(dict) ""
    
    bind SpellText <KeyPress> {spell::Event %W %A %K}
    bind SpellText <Destroy>  {spell::Free %W}
    bind SpellText <Button-1> {spell::Move %W}
    bind SpellText <FocusOut> {spell::CheckWord %W "insert -1c"}
    
    option add *spellTagForeground      red     widgetDefault
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
	if {$static(dict) ne ""} {
	    -d $static(dict)
	}
	
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

proc spell:alldicts {} {
    variable static

    set L [list]
    if {$static(speller) eq "aspell"} {
	set cmd [AutoExecOK aspell]
	set names [exec $cmd dicts]
	set L [lsort -unique [lapply {regsub {(-.+)}} $names [list ""]]]
    }
    return $L
}

proc spell::setdict {name} {
    variable static
    
    # NB: aspell and ispell work differently here.
    set static(dict) $name
}

# spell::Readable --
# 
#       Read and process result from speller.

proc spell::Readable {} {
    variable pipe
    variable static
    variable trigger

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
	$w tag add spell-err $idx1 $idx2
	set word [lindex $line 1]
	set suggest [lrange $line 4 end]
	set suggest [lapply {string trimleft} [split $suggest ","]]
	#puts "suggest=$suggest"

	set suggestions($word) $suggest
	
    } elseif {$c eq "?"} {
		
    } elseif {($c eq "*") || ($c eq "+") || ($c eq "-")} {
	$w tag remove spell-err $idx1 $idx2
    }
    
    set trigger -
}

# spell::new --
# 
#       Constructor for interactive spell checking text widget.

proc spell::new {w} {
    variable $w
    upvar 0 $w state
    variable pipe
    
    if {[winfo class $w] ne "Text"} {
	return -code error "Usage: spell::new textWidget"
    }
    if {![info exists pipe]} {
	init
    }    
    set state(lastIsChar) 0
    set fg [option get . spellTagForeground {}]
    $w tag configure spell-err -foreground $fg
    Bindings $w    
}

proc spell::clear {w} {
    $w tag delete spell-err
    Free $w
}

proc spell::Bindings {w} {
    
    # We must handle text *after* any character has been inserted or removed.
    if {[lsearch [bindtags $w] SpellText] < 0} {
	set idx [lsearch [bindtags $w] Text]
	bindtags $w [linsert [bindtags $w] [incr idx] SpellText]
    }
}

proc spell::Event {w A K} {
    variable $w
    upvar 0 $w state
    variable static
    
    # 1) Single character step
    #    a) insert character
    #    b) space
    #    c) delete
    #    d) Left, Right
    # 2) Move, shortcut
    
    # Check a word when we think we 
    # 1) have finished typing it
    # 2) editing it
    set ischar [string is wordchar -strict $A]

    set left  [$w get "insert -1c"]
    set right [$w get "insert"]
    set isleft  [string is wordchar -strict $left]
    set isright [string is wordchar -strict $right]
    set ind [$w index "insert"]
    
    set isspace 0
    set isdel 0
    set isleftright 0
    set isedit $ischar
    switch -- $K space - Return - Tab {set isspace 1}
    switch -- $K space - Return - Tab - BackSpace - Delete {set isedit 1}
    switch -- $K BackSpace - Delete {set isdel 1}
    switch -- $K Left - Right {set isleftright 1}
        
    # Detect any move larger than single character.
    set isbigmove 0
    if {[info exists state(lastInd)]} {
	lassign [split $state(lastInd) "."] lrow lpos
	lassign [split $ind "."] row pos
	if {$lrow != $row} {
	    set isbigmove 1
	} elseif {[expr {abs($lpos - $pos) > 1}]} {
	    set isbigmove 1
	}
    }
        
    puts "spell::Event A=$A, K=$K, ischar=$ischar, isedit=$isedit, isbigmove=$isbigmove\
\t left=$left, right=$right, isleft=$isleft, isright=$isright"
    
    if {$isedit && $isleft && $isright} {
	
	# Edit single word.
	puts "---> edit & left & right"
	CheckWord $w insert
    } elseif {$isspace} {
	
	# Check left word.
	set is1space [string is wordchar -strict [$w get "insert -2c"]]
	if {$is1space} {
	    puts "---> space (left)"
	    CheckWord $w "insert -2c"
	    
	    # Just split a word, check both sides.
	    if {$isright} {
		puts "---> space (right)"
		CheckWord $w "insert"
	    }
	}
    } elseif {$isdel && $isleft} {
	puts "---> del & left"
	CheckWord $w "insert -1c"
    } elseif {$isleftright && $state(lastIsChar)} {
	puts "---> move (left right)"
	Move $w
    } elseif {$isbigmove && $state(lastIsChar)} {

	# If we moved, check last word if last character was a wordchar!
	puts "---> move"
	Move $w
    }    
    set state(lastA) $A
    set state(lastK) $K
    set state(lastInd) $ind
    set state(lastIsChar) $ischar
}

proc spell::Move {w} {
    variable $w
    upvar 0 $w state
    
    puts "spell::Move"
    if {[info exists state(lastInd)]} {
	
	# Check both sides.
	set ind $state(lastInd)
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

proc spell::GetWord {w ind} {
    set idx1 [$w index "$ind wordstart"]
    set idx2 [$w index "$ind wordend"]
    return [$w get $idx1 $idx2]
}

proc spell::CheckWord {w ind} {
    variable static
    variable trigger
    
    set idx1 [$w index "$ind wordstart"]
    set idx2 [$w index "$ind wordend"]
    set word [$w get $idx1 $idx2]
    set isword [string is wordchar -strict $word]
    
    if {$isword} {
	set static(w) $w
	set static(idx1) $idx1
	set static(idx2) $idx2
	
	puts "spell::CheckWord idx1=$idx1, idx2=$idx2, word='$word' --------"

	Word $word
	vwait [namespace current]::trigger
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
	catch {close $pipe}
	unset -nocomplain pipe
    }
}

# A few duplicates to make this independent.

proc spell::lapply {cmd alist {post ""}} {
    set applied [list]
    foreach e $alist {
	lappend applied [uplevel $cmd [list $e] $post]
    }
    return $applied
}

if {![llength [info commands lassign]]} {
    proc lassign {vals args} {uplevel 1 [list foreach $args $vals break] }
}

proc spell::Free {w} {
    variable $w    
    unset -nocomplain $w
}

if {0} {
    toplevel .tt
    pack [text .tt.t -width 60 -font {{Lucida Grande} 16}]
    spell::new .tt.t
    set w .tt.t
    
}
