# ItclApplets.tcl --
# 
# 
# $Id: ItclApplets.tcl,v 1.2 2004-07-24 10:55:47 matben Exp $

namespace eval ::ItclApplets:: {
    
}

proc ::ItclApplets::Init {} {
    global  this auto_path
    
    if {[catch {package require Itcl 3.2}]} {
	return
    }
    
    # Be sure we can auto load all scripts in the applets dir
    # and in its sub dirs.
    if {[lsearch $auto_path $this(appletsPath)] == -1} {
	lappend auto_path $this(appletsPath)
    }
    foreach f [glob -nocomplain -directory $this(appletsPath) -type d *] {
	if {[lsearch $auto_path $f] == -1} {
	    lappend auto_path $f
	}
    }
    
    # This defines the properties of the plugin.
    set defList {
	pack        ItclApplets
	desc        "Itcl Applet Importer"
	ver         0.1
	platform    {macintosh   macosx    windows   unix}
	importProc  ::ItclApplets::Import
	mimes       {application/x-itcl}
    }
     
    # Register the plugin with the applications plugin mechanism.
    # Any 'package require' must have been done before this.
    ::Plugins::Register ItclApplets $defList {}    
}

proc ::ItclApplets::Import {w optListVar args} {
    upvar $optListVar optList

    array set argsArr $args
    array set optArr $optList
    
    ::Debug 4 "::ItclApplets::Import w=$w, optList=$optList, args=$args"
 
    if {![info exists argsArr(-file)]} {
	return -code error "Missing the -file option"
    }
    set fileName $argsArr(-file)
    set errMsg ""
    
    # Extract coordinates and tags which must be there. error checking?
    foreach {x y} $optArr(-coords) break

    # We should have a safe interpreter here! 
    # w, x, y must exist and 'args' must here be the optList!
    set args $optList
    if {[catch {source $fileName} err]} {
	::Debug 4 "\t $err"
	set errMsg $err
    }

    # Success.
    return $errMsg
}

