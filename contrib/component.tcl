# component.tcl --
# 
#       Provides a structure for code components.
#       
# $Id: component.tcl,v 1.3 2004-06-06 07:02:20 matben Exp $

package provide component 1.0


namespace eval component { 

    # Search path for components, similar to ::auto_path.
    variable auto_path {}
}

proc component::lappend_auto_path {path} {
    
    variable auto_path
    
    lappend auto_path $path
}

proc component::attempt {name fileName initProc} {
    variable priv
    
    uplevel #0 [list source $fileName]
    uplevel #0 $initProc
}

proc component::register {name} {
    variable priv
    
    set priv($name) 1
}

# component::load --
# 
#       Loads all cmpntIndex.tcl files.
#       Each line in the cmpntIndex.tcl file defines a component to be loaded:
#       
#       component::attempt MyCool [file join $dir mycool.tcl] MyCoolInitProc

proc component::load { } {
    
    variable auto_path
    
    foreach dir $auto_path {
	loaddir $dir
    }
}

proc component::loaddir {dir} {
    
    # 'dir' must be defined!
    set f [file join $dir cmpntIndex.tcl]
    if {[file exists $f]} {
	source $f
    }
    
    # Search dirs recursively.
    foreach d [glob -directory $dir -nocomplain *] {
	if {[file isdirectory $d]} {
	    loaddir $d
	}
    }
}

proc component::exists {name} {
    variable priv
    
    return [info exists priv($name)]
}

#-------------------------------------------------------------------------------
