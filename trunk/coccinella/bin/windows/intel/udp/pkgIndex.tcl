# Handcrafted pkgIndex for tcludp.
if {[info exists ::tcl_platform(debug)]} {
    package ifneeded udp 1.0.7 [list load [file join $dir udp107g.dll]]
} else {
    package ifneeded udp 1.0.7 [list load [file join $dir udp107.dll]]
}
