if {[catch {package require Tcl 8.5}]} return
set script ""
if {![info exists ::env(TREECTRL_LIBRARY)]
    && [file exists [file join $dir treectrl.tcl]]} {
    append script "[list set ::treectrl_library $dir]
"
}
append script [list load [file join $dir libtreectrl2.2.dylib] treectrl]
package ifneeded treectrl 2.2.9 $script
