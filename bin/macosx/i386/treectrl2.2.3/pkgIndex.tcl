if {[catch {package require Tcl 8.4}]} return
set script ""
if {![info exists ::env(TREECTRL_LIBRARY)]
    && [file exists [file join $dir treectrl.tcl]]} {
    append script "set ::treectrl_library \"$dir\"
"
}
append script "load \"[file join $dir libtreectrl2.2.dylib]\" treectrl"
package ifneeded treectrl 2.2.3 $script
