#  spell.tcl --
#  
#       Package to provide an interface to 'ispell' and 'aspell' and sets
#       up bindings to a text widget for interactive spell checking.
#      
#  Copyright (c) 2007  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: spell.tcl,v 1.8 2007-10-25 08:19:21 matben Exp $

# TODO: try to simplify the async (fileevent) part of this similar
#       to spell::wordserial perhaps.

package provide spell 0.1

namespace eval spell {
    
    variable spellers [list ispell aspell]
    variable pipe
    variable trigger
    variable static
    
    set static(w) -
    set static(dict) ""
    
    bind SpellText <KeyPress> {spell::Event %W %A %K}
    bind SpellText <Destroy>  {spell::Free %W}
    bind SpellText <Button-1> {spell::Move %W}
    bind SpellText <<Paste>>  {spell::Paste %W}
    bind SpellText <FocusOut> {spell::CheckWord %W "insert -1c"}
    
    option add *spellTagForeground      red     widgetDefault
}

proc spell::have {} {
    variable spellers

    # No clue on Windows.
    set have 0
    if {[tk windowingsystem] ne "win32"} {
	foreach s $spellers {
	    set cmd [AutoExecOK $s]
	    if {[llength $cmd]} {
		set have 1
		break
	    }
	}
    }
    return $have
}

# spell::init --
# 
#       This serves to init any spell checker tools.

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
	lappend cmd -a	
	if {$static(dict) ne ""} {
	    lappend cmd -d $static(dict)
	}
	set pipe [open |$cmd r+]
	fconfigure $pipe -buffering line -blocking 1
	if {$static(speller) eq "ispell"} {
	    #fconfigure $pipe -encoding latin1
	} elseif {$static(speller) eq "aspell"} {
	    fconfigure $pipe -encoding utf-8
	}
	set line [gets $pipe]
	# puts "line=$line"
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
    set state(lastInd)    1.0
    set state(lastWord)   ""
    set state(lastLeft)   ""
    set state(lastRight)  ""
    
    set fg [option get . spellTagForeground {}]
    $w tag configure spell-err -foreground $fg
    Bindings $w    
}

proc spell::Bindings {w} {
    
    # We must handle text *after* any character has been inserted or removed.
    if {[lsearch [bindtags $w] SpellText] < 0} {
	set idx [lsearch [bindtags $w] Text]
	bindtags $w [linsert [bindtags $w] [incr idx] SpellText]
    }
}

# spell::wordserial --
# 
#       Checks a single word and return a list:
#         {correct list-of-suggestions}
#       We must have been init'ed first.

proc spell::wordserial {word} {
    variable serialTrig 1
    variable pipe
    
    # Not the nicest code I have written...
    fileevent $pipe readable [list set [namespace current]::serialTrig 2]
    puts $pipe $word
    vwait [namespace current]::serialTrig
    set line [read $pipe]
    set c [string index $line 0]
    set correct 1
    set suggest [list]
    if {$c eq "&" || $c eq "?"} {
	set correct 0
	set suggest [lrange $line 4 end]
	set suggest [lapply {string trimleft} [split $suggest ","]]
    } elseif {$c eq "#"} {
	set correct 0
    }
    fileevent $pipe readable [namespace code Readable]
    return [list $correct $suggest]
}

# spell::check --
# 
#       Spellcheck complete text widget.
#       We must have been init'ed first.

proc spell::check {w} {
    variable serialTrig 1
    variable pipe
    
    # Not the nicest code I have written...
    fileevent $pipe readable [list set [namespace current]::serialTrig 2]
    
    set nlines [lindex [split [$w index end] "."] 0]
    for {set n 1} {$n <= $nlines} {incr n} {
	set text [$w get "$n.0" "$n.0 lineend"]
	if {$text ne ""} {
	    puts $pipe $text
	    vwait [namespace current]::serialTrig
	    set lines [read $pipe]
	    foreach line [split $lines "\n"] {
		set c [string index $line 0]
		if {$c eq "&" || $c eq "?" || $c eq "#"} {
		    set word [lindex $line 1]
		    set len [string length $word]
		    if {$c eq "#"} {
			set id1 [lindex $line 2]
		    } else {
			set id1 [string trimright [lindex $line 3] ":"]
		    }
		    set id2 [expr {$id1 + $len}]
		    $w tag add spell-err $n.$id1 $n.$id2
		}
	    }
	}
    }    
    fileevent $pipe readable [namespace code Readable]
}

# spell::clear --
# 
#       Removes any spell checking from widget.

proc spell::clear {w} {
    $w tag remove spell-err 1.0 end
    Free $w
    set idx [lsearch [bindtags $w] SpellText]
    if {$idx >= 0} {
	bindtags $w [lreplace [bindtags $w] $idx $idx]
    }
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
    # puts "spell::Readable line='$line'"
    
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
		
	# Guess with guesses.
	$w tag add spell-err $idx1 $idx2
	set word [lindex $line 1]
	set guess [lrange $line 4 end]
	set guess [lapply {string trimleft} [split $guess ","]]
	
    } elseif {($c eq "*") || ($c eq "+") || ($c eq "-")} {
	$w tag remove spell-err $idx1 $idx2
    }
    
    set trigger -
}

proc spell::Event {w A K} {
    variable $w
    upvar 0 $w state
    variable static
    
    # 1) Single character step
    #    a) insert character
    #    b) space
    #    c) delete, to left or right
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
    set ispunct [string is punct -strict $A]
    set ind [$w index "insert"]
    
    set isspace 0
    set isdel 0
    set isleftright 0
    set isedit $ischar
    switch -- $K space - Return - Tab {set isspace 1}
    switch -- $K space - Return - Tab - BackSpace - Delete {set isedit 1}
    switch -- $K BackSpace - Delete {set isdel 1}
    switch -- $K Left - Right {set isleftright 1}
    
    set word [GetWord $w "insert -1c"]
        
    # Detect any move larger than single character.
    set isbigmove 0
    lassign [split $state(lastInd) "."] lrow lpos
    lassign [split $ind "."] row pos
    if {$lrow != $row} {
	set isbigmove 1
    } elseif {[expr {abs($lpos - $pos) > 1}]} {
	set isbigmove 1
    }
    
    set isfix 0
    set isdelright 0
    if {!$isbigmove && $isright} {
	if {$ind eq $state(lastInd)} {
	    
	    # Can be a delete to right.
	    set isfix 1
	    if {$right ne $state(lastRight)} {
		set isdelright 1
		# puts "*** isdelright"
	    }
	}
    }
        
    # puts "spell::Event ischar=$ischar, isedit=$isedit, isbigmove=$isbigmove\
 A=$A, K=$K, left=$left, right=$right, isleft=$isleft, isright=$isright"
    # puts "\t ind=$ind, state(lastInd)=$state(lastInd)"

    if {$isedit && $isleft && $isright} {
	
	# Edit single word.
	# puts "---> edit & left & right"
	CheckWord $w insert
    } elseif {$isspace || $ispunct} {
	
	# Check left word.
	set is1space [string is wordchar -strict [$w get "insert -2c"]]
	if {$is1space} {
	    # puts "---> space (left)"
	    CheckWord $w "insert -2c"
	    
	    # Just split a word, check both sides.
	    if {$isright} {
		# puts "---> space (right)"
		CheckWord $w "insert"
	    }
	}
    } elseif {$isdel && $isleft} {
	# puts "---> del & left"
	
	# Delete to left.
	CheckWord $w "insert -1c"
    } elseif {$isdel && $isright} {
	# puts "---> del & right"
	
	# Delete to left but word to right.
	CheckWord $w "insert"
    } elseif {$isdelright} {
	# puts "---> delright"
	
	# Delete to right.
	CheckWord $w "insert"
    } elseif {$isleftright && $state(lastIsChar)} {
	# puts "---> move (left right)"
	Move $w
    } elseif {$isbigmove} {

	# If we moved, check last word if last character was a wordchar!
	# puts "---> move"
	Move $w
    }    
    set state(lastA)      $A
    set state(lastK)      $K
    set state(lastLeft)   $left
    set state(lastRight)  $right
    set state(lastWord)   $word
    set state(lastIsChar) $ischar
    if {$state(lastInd) ne $ind} {
	set state(lastInd) $ind
    }
}

proc spell::Move {w} {
    variable $w
    upvar 0 $w state
    
    # puts "spell::Move"
	
    # Check both sides.
    set ind $state(lastInd)
    set left  [$w get "$ind -1c"]
    set right [$w get "$ind"]
    set isleft  [string is wordchar -strict $left]
    set isright [string is wordchar -strict $right]
    if {$isleft} {
	CheckWord $w "$ind -1c"
    }
    if {!$isleft && $isright} {
	CheckWord $w "$ind"
    }
}

proc spell::Paste {w} {
    variable $w
    upvar 0 $w state
    

    # Try to check the text between the lastInd and insert.

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
	
	# puts "spell::CheckWord idx1=$idx1, idx2=$idx2, word='$word' -----------"

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
    pack [text .tt.t -width 60 -font {{Lucida Grande} 18}]
    spell::new .tt.t
    set w .tt.t
    
}
