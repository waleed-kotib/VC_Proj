if {[catch {package require Tcl 8.4}]} return
package ifneeded tile 0.7.8  [list load [file join $dir libtile078.so] tile]
