#  undo.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements a generic undo/redo stack.
#      
#  Copyright (c) 2002  Mats Bengtsson
#  
# $Id: undo.tcl,v 1.4 2004-07-30 12:55:53 matben Exp $

package provide undo 0.1

namespace eval undo {

    variable uid 0
    
    # These variables are used to keep the undo and history stacks.
    variable undoStack
    variable histStack
    
    # Keep a pointer to the index into these stacks.
    variable stackPtr
}

proc undo::new {args} {

    variable uid
    variable undoStack
    variable histStack
    variable stackPtr
    variable opts

    set token [namespace current]::[incr uid]
    foreach {key value} {
	-command     ""
    } {	
	set opts($token,$key) $value
    }
    foreach {key value} $args {	
	set opts($token,$key) $value
    }
    reset $token
    return $token
}

proc undo::reset {token} {

    variable undoStack
    variable histStack
    variable stackPtr
    variable opts

    set undoStack($token) {}
    set histStack($token) {}
    set stackPtr($token) 0
    if {[string length $opts($token,-command)]} {
	uplevel #0 $opts($token,-command) [list $token undo disabled]
	uplevel #0 $opts($token,-command) [list $token redo disabled]
    }
}

proc undo::delete {token} {

    variable undoStack
    variable histStack
    variable stackPtr

    unset -nocomplain undoStack($token) histStack($token) stackPtr($token)
}

proc undo::add {token undocmd redocmd} {
    
    variable undoStack
    variable histStack
    variable stackPtr
    variable opts
    
    if {$stackPtr($token) < [llength $undoStack($token)]} {
	set ind [expr $stackPtr($token) - 1]
	set undoStack($token) [lrange $undoStack($token) 0 $ind]
	set histStack($token) [lrange $histStack($token) 0 $ind]
    } elseif {[llength $undoStack($token)] == 50} {
	set undoStack($token) [lreplace $undoStack($token) 0 0]
	set histStack($token) [lreplace $histStack($token) 0 0]
    }
    lappend undoStack($token) $undocmd
    lappend histStack($token) $redocmd
    set stackPtr($token) [llength $undoStack($token)]
    if {[string length $opts($token,-command)]} {
	if {$stackPtr($token) == 1} {
	    uplevel #0 $opts($token,-command) [list $token undo normal]
	}
    }
}

proc undo::undo {token} {
    
    variable undoStack
    variable stackPtr
    variable opts
    
    if {$stackPtr($token) <= 0} {
	return -code error "Undo stack reached bottom"
    }
    incr stackPtr($token) -1
    set cmd [lindex $undoStack($token) $stackPtr($token)]
    uplevel #0 $cmd
    if {[string length $opts($token,-command)]} {
	uplevel #0 $opts($token,-command) [list $token redo normal]
	if {$stackPtr($token) <= 0} {
	    uplevel #0 $opts($token,-command) [list $token undo disabled]
	}
    }
}

proc undo::redo {token} {

    variable histStack
    variable stackPtr
    variable opts

    if {$stackPtr($token) == [llength $histStack($token)]} {
	return -code error "History stack reached top"
    }
    set cmd [lindex $histStack($token) $stackPtr($token)]
    incr stackPtr($token)
    uplevel #0 $cmd
    if {[string length $opts($token,-command)]} {
	uplevel #0 $opts($token,-command) [list $token undo normal]
	if {$stackPtr($token) == [llength $histStack($token)]} {
	    uplevel #0 $opts($token,-command) [list $token redo disabled]
	}
    }
}

proc undo::dump {token} {

    variable stackPtr
    variable undoStack
    variable histStack

    puts "Dumping undo stacks for token=$token; stackPtr=$stackPtr($token)"
    puts "\n    Undo stack:"
    set i 0
    foreach cmd $undoStack($token) {
	puts "    $i    $cmd"
	incr i
    }
    puts "\n    History stack:"
    set i 0
    foreach cmd $histStack($token) {
	puts "    $i    $cmd"
	incr i
    }    
}

#-------------------------------------------------------------------------------
