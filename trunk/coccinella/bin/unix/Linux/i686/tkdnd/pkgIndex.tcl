namespace eval ::dnd {
    proc _load {dir} {
	set version 1.0
	switch $::tcl_platform(platform) {
	  windows {
	    if {[catch {load [file join $dir libtkdnd[string map {. {}} \
		$version][info sharedlibextension]] tkdnd} error]} {
              ## The library was not found. Perhaps under a directory with the
              ## OS name?
              if {[catch {load [file join $dir $::tcl_platform(os) \
                  libtkdnd[string map {. {}} $version][info \
                  sharedlibext]] tkdnd}]} {
                return -code error $error
              }
            }
	  }
	  default {
	    if {[catch {load [file join $dir \
                  libtkdnd$version[info sharedlibextension]] tkdnd} error]} {
              ## The library was not found. Perhaps under a directory with the
              ## OS name?
              if {[catch {load [file join $dir $::tcl_platform(os) \
                  libtkdnd$version[info sharedlibextension]] tkdnd}]} {
                return -code error $error
              }
            }
	  }
	}
	source [file join $dir tkdnd.tcl]
	package provide tkdnd $version
    }
}

package ifneeded tkdnd 1.0  [list ::dnd::_load $dir]
