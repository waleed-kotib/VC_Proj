# hooks.tcl --
# 
#       Provides a systematic way for code sections to register themselfes
#       for callbacks when certain events happen.
#       
#       Code idea from Alexey Shchepin, (and Vince Darley) Many Thanks!
#       
# $Id: hooks.tcl,v 1.7 2005-12-04 13:29:11 matben Exp $

package provide hooks 1.0


namespace eval hooks { }

proc hooks::register {hook func {seq 50}} {
    variable $hook

    lappend $hook [list $func $seq]
    set $hook [lsort -integer -index 1 [lsort -unique [set $hook]]]
}

proc hooks::deregister {hook func} {
    variable $hook

    if {![::info exists $hook]} {
	return
    }
    set ind -1
    set found 0
    foreach spec [set $hook] {
	incr ind
	if {[string equal $func [lindex $spec 0]]} {
	    set found 1
	    break
	}
    }
    if {$found} {
	set $hook [lreplace [set $hook] $ind $ind]
    }
}

proc hooks::setflag {hook flag} {
    variable flags
    
    set idx [lsearch -exact $flags($hook) $hook]
    set flags($hook) [lreplace $flags($hook) $idx $idx]
}

proc hooks::unsetflag {hook flag} {
    variable flags
    
    if {[lsearch -exact $flags($hook) $flag] < 0} {
	lappend flags($hook) $flag
    }
}

proc hooks::isflag {hook flag} {
    variable flags
    
    return [expr {[lsearch -exact $flags($hook) $flag] < 0} ? 1 : 0]
}

proc hooks::run {hook args} {
    variable flags
    variable $hook

    if {![::info exists $hook]} {
	return
    }
    set flags($hook) {}
    set result ""

    foreach spec [set $hook] {
	set func [lindex $spec 0]
	set code [catch {eval $func $args} state]
	if {$code} {
	    bgerror "Hook $hook failed: $code\n$::errorInfo"
	} elseif {[string equal $state stop]} {
	    set result stop
	    break
	}
    }
    return $result
}

proc hooks::anyregistered {hook} {
    variable $hook

    return [::info exists $hook]
}

proc hooks::info {{hook ""}} {
    variable $hook
    
    if {$hook eq ""} {
	set all {}
	foreach h [::info vars [namespace current]::?*] {
	    set name [string map {::hooks:: ""} $h]
	    lappend all $name
	}
	return $all
    } else {
	if {[::info exists $hook]} {
	    return [set $hook]
	} else {
	    return {}
	}
    }
}

#-------------------------------------------------------------------------------
