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
# $Id: pipes.tcl,v 1.4 2007-11-01 15:59:00 matben Exp $

package provide pipes 1.0

namespace eval pipes {}

proc pipes::register {pipe func {seq 50}} {
    variable $pipe

    lappend $pipe [list $func $seq]
    set $pipe [lsort -integer -index 1 [lsort [set $pipe]]]
}

# Very experimental!

# pipes::run --
# 
#       Pipe the last argument. 
#       Since the order of the registered pipes may vary it is unclear how
#       stable this can be.

proc pipes::run {pipe args} {
    variable $pipe

    if {![info exists $pipe]} {
	return [lindex $args end]
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
    pipes::register testPipe MyFunc
    pipes::register testPipe MyFunc
    pipes::register testPipe MyFunc
    puts "[::pipes::run testPipe abc]"
}

#-------------------------------------------------------------------------------
