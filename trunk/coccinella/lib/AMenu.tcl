#  AMenu.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements some menu support functions.
#      
#      @@@ This is supposed to replace much of the other menu code.
#      
#  Copyright (c) 2006  Mats Bengtsson
#  
# $Id: AMenu.tcl,v 1.2 2006-02-22 14:16:44 matben Exp $

package provide AMenu 1.0

namespace eval ::AMenu { 

}

proc ::AMenu::Build {m menuDef} {
    variable menuIndex
    
    set i 0
    set isub 0
    
    bind $m <Destroy> {+::AMenu::Free %W }
    
    foreach line $menuDef {
	set op   [lindex $line 0]
	set name [lindex $line 1]
	set cmd  [lindex $line 2]
	set opts [lindex $line 3]
	
	if {[tk windowingsystem] eq "aqua"} {
	    set idx [lsearch $opts -image]
	    if {$idx >= 0} {
		set opts [lreplace $opts $idx [expr {$idx+1}]]
	    }
	}	
	set lname [mc $name]
	set opts [eval list $opts]
	
	switch -glob -- $op {
	    command {
		eval {$m add command -label $lname  \
		  -command [list after 40 $cmd]} $opts
	    }
	    radio* {
		eval {$m add radiobutton -label $lname  \
		  -command [list after 40 $cmd]} $opts
	    }
	    check* {
		eval {$m add checkbutton -label $lname  \
		  -command [list after 40 $cmd]} $opts
	    }
	    sep* {
		$m add separator
	    }
	    cascade {
		set mt [menu $m.sub$isub -tearoff 0]
		eval {$m add cascade -label $lname -menu $mt} $opts
		if {[string index $cmd 0] eq "@"} {
		    eval [string range $cmd 1 end] $mt
		} else {
		    Build $mt $cmd
		}
		incr isub
	    }
	}
	if {$name ne ""} {
	    set menuIndex($m,$name) [$m index $lname]
	}
	incr i
    }
    return $m
}

proc ::AMenu::GetMenuIndex {m name} {
    variable menuIndex

    if {[info exists menuIndex($m,$name)]} {
	return $menuIndex($m,$name)
    } else {
	return ""
    }
}

proc ::AMenu::GetMenuIndexArray {m} {
    variable menuIndex
    
    set alist {}
    foreach {key value} [array get menuIndex $m,*] {
	set name [string map [list $m, ""] $key]
	lappend alist $name $value
    }
    return $alist
}

proc ::AMenu::EntryConfigure {m index args} {
    
    if {[tk windowingsystem] eq "aqua"} {
	set idx [lsearch $args -image]
	if {$idx >= 0} {
	    set args [lreplace $args $idx [expr {$idx+1}]]
	}
    }
    eval {$m entryconfigure $index} $args
}

proc ::AMenu::Free {m} {
    variable menuIndex
    
    array unset menuIndex $m,*
}

