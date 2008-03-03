if {[catch {package require Tcl 8.4}]} return
if {[info tclversion] == 8.4} {
    package ifneeded treectrl 2.2.3 [list load [file join $dir treectrl22.dll] treectrl]
} elseif {[info tclversion] == 8.5} {
    package ifneeded treectrl 2.2.6 [list load [file join $dir 8.5 treectrl22.dll] treectrl]    
}
