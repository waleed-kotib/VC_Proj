# component.tcl --
# 
#       Provides a structure for code components.
#  
#  This file is distributed under BSD style license.
#       
# $Id: component.tcl,v 1.10 2008-05-13 09:13:00 matben Exp $

package provide component 1.0

namespace eval component { 

    # Search path for components, similar to ::auto_path.
    variable auto_path [list]

    variable priv
    set priv(offL) [list]
}

proc component::lappend_auto_path {path} {
    variable auto_path
    lappend auto_path $path
}

# component::exclude --
# 
#       Set list of component names we shall not attempt to load.

proc component::exclude {offL} {
    variable priv    
    set priv(offL) $offL    
}

# component::attempt --
# 
#       Used in cmpntIndex files.

proc component::attempt {name fileName initProc} {
    variable priv

    # This normally calls 'component::define'.
    uplevel #0 [list source $fileName]

    if {[info exists priv($name,name)]} {
	if {[lsearch $priv(offL) $name] < 0} {
	
	    # While 'component::register' may get called here.
	    uplevel #0 $initProc
	}
    }
}

# component::define --
# 
#       Each component defines itself with name and string.
#       It doesn't load anything.

proc component::define {name str} {
    variable priv
    set priv($name,name) $name
    set priv($name,str)  $str
}

proc component::undefine {name} {
    variable priv
    array unset priv $name,*
}

# component::register --
# 
#       Each component register with this function which means it is
#       being loaded.

proc component::register {name} {
    variable priv
    set priv($name,reg) 1
}

proc component::unregister {name} {
    variable priv

    # This is an incomplete way of removing a component.
    array unset priv $name,*
}

proc component::getall {} {
    variable priv

    set ans [list]
    foreach {key value} [array get priv *,name] {
	set name $priv($key)
	lappend ans [list $name $priv($name,str)]
    }
    return [lsort -index 0 $ans]
}

# component::load --
# 
#       Loads all cmpntIndex.tcl files.
#       Each line in the cmpntIndex.tcl file defines a component to be loaded:
#       
#       component::attempt MyCool [file join $dir mycool.tcl] MyCoolInitProc

proc component::load {} {
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
    return [info exists priv($name,reg)]
}

#-------------------------------------------------------------------------------
