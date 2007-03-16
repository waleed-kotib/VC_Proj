if {[catch {package require Tcl 8.4}]} return

package ifneeded treectrl 2.2.3 [list load [file join $dir libtreectrl2.2.dylib] treectrl]
