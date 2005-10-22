if {[catch {package require Tcl 8.4}]} return

package ifneeded treectrl 2.1 [list load [file join $dir treectrl21.dll] treectrl]
