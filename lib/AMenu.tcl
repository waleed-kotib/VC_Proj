#  AMenu.tcl ---
#  
#      This file is part of The Coccinella application. 
#      It implements some menu support functions.
#      
#      @@@ This is supposed to replace much of the other menu code.
#      
#  Copyright (c) 2006  Mats Bengtsson
#  
# $Id: AMenu.tcl,v 1.6 2006-03-14 07:18:59 matben Exp $

package provide AMenu 1.0

namespace eval ::AMenu { 

}

# AMenu::Build --
# 
#       High level utility for handling menus.
#       We use the 'name' for the menu entry index which is the untranslated
#       key, typically mLabel etc.
#       
# Arguments:
#       m         menu widget path; must exist
#       menuDef   a list of lines:
#                   {type name command ?{-key value..}?}
#                 name: always the key that is used for msgcat::mc
#       args    -varlist   list of {name value ...} which sets variables used
#                          for substitutions in command and options
#       
# Results:
#       menu widget path

proc ::AMenu::Build {m menuDef args} {
    variable menuIndex
    
    array set aArr {-varlist {}}
    array set aArr $args
    foreach {key value} $aArr(-varlist) {
	set $key $value
    }
    set isub 0
    
    bind $m <Destroy> {+::AMenu::Free %W }
    
    foreach line $menuDef {
	lassign $line op name cmd opts
	
	if {[tk windowingsystem] eq "aqua"} {
	    set idx [lsearch $opts -image]
	    if {$idx >= 0} {
		set opts [lreplace $opts $idx [expr {$idx+1}]]
	    }
	}	
	set lname [mc $name]
	set opts [eval list $opts]

	# Parse any "&" in name to -underline.
	set ampersand [string first & $lname]
	if {$ampersand != -1} {
	    regsub -all & $lname "" lname
	    lappend opts -underline $ampersand
	}

	switch -glob -- $op {
	    com* {
		set cmd [list after 40 [eval list $cmd]]
		eval {$m add command -label $lname -command $cmd} $opts
	    }
	    rad* {
		set cmd [list after 40 [eval list $cmd]]
		eval {$m add radiobutton -label $lname -command $cmd} $opts
	    }
	    che* {
		set cmd [list after 40 [eval list $cmd]]
		eval {$m add checkbutton -label $lname -command $cmd} $opts
	    }
	    sep* {
		$m add separator
	    }
	    cas* {
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

# AMenu::EntryConfigure --
# 
#       As 'menuWidget entryconfigure index ?-keu value...?'
#       but using mLabel as index instead.
#       
# Arguments:
#       m         menu widget path
#       mLabel
#       args
#           
#       
# Results:
#       menu widget path

proc ::AMenu::EntryConfigure {m mLabel args} {
    variable menuIndex
    
    if {[tk windowingsystem] eq "aqua"} {
	set idx [lsearch $args -image]
	if {$idx >= 0} {
	    set args [lreplace $args $idx [expr {$idx+1}]]
	}
    }
    set index $menuIndex($m,$mLabel)
    eval {$m entryconfigure $index} $args
}

proc ::AMenu::EntryExists {m mLabel} {
    variable menuIndex

    if {[info exists menuIndex($m,$mLabel)]} {
	return 1
    } else {
	return 0
    }
}

proc ::AMenu::Free {m} {
    variable menuIndex
    
    array unset menuIndex $m,*
}

