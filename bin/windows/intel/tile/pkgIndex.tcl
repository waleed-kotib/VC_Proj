if {[catch {package require Tcl 8.4}]} return

# Do not get staticalliy linked tile from here.
if {[lsearch -exact [info loaded] {{} tile}] >= 0} return
if {[package vcompare [info patchlevel] 8.4.6] < 0} return

package ifneeded tile 0.7.1  [list load [file join $dir tile71.dll] tile]
