# component.tcl --
# 
#       Provides a structure for code components.
#       
# $Id: component.tcl,v 1.1 2004-04-16 13:58:27 matben Exp $

package provide component 1.0


namespace eval component { 

    # Search path for components, similar to ::auto_path.
    variable auto_path {}
}


proc component::register {fileName initProc} {
    
    uplevel #0 [list source $fileName]
    uplevel #0 $initProc
}

proc component::load { } {
    
    variable auto_path
    
    foreach dir $auto_path {
	set f [file join $dir cmpntIndex.tcl]
	if {[file exists $f]} {
	    source $f
	}
    }
}

#-------------------------------------------------------------------------------
