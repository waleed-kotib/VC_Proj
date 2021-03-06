#  spell.tcl --
#  
#       Package to provide an interface to 'ispell' and 'aspell' and sets
#       up bindings to a text widget for interactive spell checking.
#      
#  Copyright (c) 2007  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: spell.tcl,v 1.18 2008-01-02 08:20:10 matben Exp $

# TODO: try to simplify the async (fileevent) part of this similar
#       to spell::wordserial perhaps.
#       
# @@@ Despite many attempts I haven't been able to find a robust way to
#     spell test more than a single word in an interactive mode.
#     There is no way to relate what comes out with what was put in
#     when it works async like this.
#     I can only see the C api as a viable solution.
#     Note that in such a case most of this code can still be used.

package provide spell 0.1

namespace eval spell {
    
    variable spellers [list aspell ispell]
    variable pipe
    variable trigger
    variable static
    
    set static(w) -
    set static(dict) ""
    set static(paths) [list]
    set static(speller) ""
    
    bind SpellText <KeyPress> {spell::Event %W %A %K}
    bind SpellText <Destroy>  {spell::Free %W}
    bind SpellText <Button-1> {spell::Move %W}
    bind SpellText <<Paste>>  {spell::Paste %W}
    bind SpellText <FocusOut> {spell::CheckWord %W "insert -1c"}
    
    option add *spellTagForeground      red     widgetDefault
}

# spell::addautopath --
# 
#       We may have a special installation directory for spell checkers.

proc spell::addautopath {path} {
    variable static
    lappend static(paths) $path
}

# spell::have --
# 
#       Checks for an executable.

proc spell::have {} {
    variable spellers
    variable static

    set have 0
    foreach s $spellers {
	set cmd [AutoExecOK $s]
	if {[llength $cmd]} {
	    set have 1
	    set static(speller) $s
	    break
	}
    }
    return $have
}

# spell::init --
# 
#       This serves to init any spell checker tools.
#       Constructor for a 'spell' object.

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
	    
	    # Both we and aspell use utf-8, thus, no translation!
	    fconfigure $pipe -translation binary
	}
	set line [gets $pipe]
	# puts "line=$line"
	if {[string range $line 0 3] ne "@(#)"} {
	    catch {close $pipe}
	    unset -nocomplain pipe
	    return -code error "Wrong identification line: \"$line\""
	}
	fconfigure $pipe -blocking 0
	fileevent $pipe readable [namespace code Readable]
    } else {
	return -code error "Failed to find \"ispell\" or \"aspell\""
    }
    
    # If doing this OO make a state array.
    variable $pipe
    upvar 0 $pipe state
    
    set state(pipe) $pipe
    set state(dict) $static(dict)
    
    return $pipe
}

# spell::free --
# 
#       Destructor of the 'spell' object.

proc spell::free {pipe} {
    variable $pipe
    upvar 0 $pipe state
    
    catch {close $pipe}
    unset -nocomplain state
}

proc spell::speller {} {
    variable static
    if {[info exists static(speller)]} {
	return $static(speller)
    } else {
	return
    }
}

proc spell::reset {} {
    variable pipe
    variable static

    catch {close $pipe}
    unset -nocomplain pipe
    unset -nocomplain static(dicts)
}

proc spell::AutoExecOK {name} {
    global  tcl_platform
    variable static
    
    if {$tcl_platform(platform) eq "windows"} {
	set exe $name.exe
    } else {
	set exe $name
    }
    
    # ispell and aspell install in /usr/local/bin on my Mac.
    # Use 'which' on unix to find it in /sw/...
    set cmd [auto_execok $name]
    if {![llength $cmd]} {
	set search $static(paths) 
	if {$tcl_platform(platform) eq "unix"} {
	    catch {lappend search [file dirname [exec which $name]]}
	}
	if {$tcl_platform(platform) ne "windows"} {
	    lappend search /usr/local/bin
	}
	foreach dir $search {
	    set file [file join $dir $exe]
	    if {[file executable $file] && ![file isdirectory $file]} {
		set cmd [list $file]
		break
	    }
	}
    }
    return $cmd
}

proc spell::alldicts {} {
    variable static

    if {[info exists static(dicts)]} {
	return $static(dicts)
    } else {
	set L [list]
	set cmd [AutoExecOK aspell]
	if {[llength $cmd]} {
	    set names [eval exec $cmd dicts]
	    set L [lsort -unique [lapply {regsub {(-.+)}} $names [list ""]]]
	    set static(dicts) $L
	}
	return $L
    }
}

proc spell::setdict {name} {
    variable static
    
    # NB: aspell and ispell work differently here.
    if {$static(speller) eq "aspell"} {
	set static(dict) $name
    }
}

proc spell::getdict {} {
    variable static
    
    # NB: aspell and ispell work differently here.
    if {$static(speller) eq "aspell"} {
	set cmd [AutoExecOK aspell]
	set lang [eval exec $cmd dump config lang]
	return $lang
    }
    return
}

proc spell::addword {word} {
    variable pipe    
    catch {
	puts $pipe "&$word"
	flush $pipe
    }
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
	if {[catch {init}]} {
	    return
	}
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
    variable serialTrig 0
    variable pipe
    
    # puts "spell::wordserial word='$word'"
    
    # Not the nicest code I have written...
    fileevent $pipe readable [list set [namespace current]::serialTrig 1]
    puts $pipe $word
    flush $pipe
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
    } elseif {$c eq "?"} {
		
	# Guess with guesses.
	$w tag add spell-err $idx1 $idx2
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

}

proc spell::GetWord {w ind} {
    
    # Buggy for utf-8 characters!
    #set idx1 [$w index "$ind wordstart"]
    #set idx2 [$w index "$ind wordend"]
    #return [$w get $idx1 $idx2]
    set ind [$w index $ind]
    set line [$w get "$ind linestart" "$ind lineend"]
    set i [lindex [split $ind .] 1]
    set idx1 [string wordstart $line $i]
    set idx2 [expr {[string wordend $line $i] - 1}]
    return [string range $line $idx1 $idx2]
}

proc spell::GetWordIndices {w ind} {
    
    set ind [$w index $ind]
    set line [$w get "$ind linestart" "$ind lineend"]
    lassign [split $ind .] n i
    set idx1 [string wordstart $line $i]
    set idx2 [string wordend $line $i]
    return [list $n.$idx1 $n.$idx2]
}       

proc spell::CheckWord {w ind} {
    variable static
    variable trigger
    
    set word [GetWord $w $ind]
    set isword [string is wordchar -strict $word]
    
    if {$isword} {
	set static(w) $w
	lassign [GetWordIndices $w $ind] idx1 idx2
	set static(idx1) $idx1
	set static(idx2) $idx2
	
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
	flush $pipe
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
