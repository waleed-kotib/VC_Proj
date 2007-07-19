# pipes.tcl --
# 
#       Provides a systematic way for code sections to register themselfes
#       for callbacks when certain events happen.
#       It is similar to hooks, but each registered function process its
#       input arguments and returns a result string, which is then used for
#       next call etc.
#  
#  This file is distributed under BSD style license.
#       
# $Id: pipes.tcl,v 1.3 2007-07-19 06:28:11 matben Exp $

package provide pipes 1.0

namespace eval pipes { }

proc pipes::add {pipe func {seq 50}} {
    variable $pipe

    lappend $pipe [list $func $seq]
    set $pipe [lsort -integer -index 1 [lsort [set $pipe]]]
}

# The last argument is the one that gets piped from one invokation to the other.

proc pipes::run {pipe args} {
    variable $pipe

    if {![info exists $pipe]} {
	return
    }

    foreach spec [set $pipe] {
	set func [lindex $spec 0]
	set code [catch {eval $func $args} ans]
	
	switch -- $code {
	    error {
		bgerror "pipe $pipe failed: $code\n$::errorInfo"
	    }
	    break {
		lset args end $ans
		break
	    }
	}
	lset args end $ans
    }
    return [lindex $args end]
}

if {0} {    
    proc MyFunc {str} {return "$str$str"}
    ::pipes::add testPipe MyFunc
    ::pipes::add testPipe MyFunc
    ::pipes::add testPipe MyFunc
    puts "[::pipes::run testPipe abc]"
}

#-------------------------------------------------------------------------------
