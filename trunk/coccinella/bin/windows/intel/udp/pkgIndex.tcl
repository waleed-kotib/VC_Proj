# Handcrafted pkgIndex for tcludp.
if {[info exists ::tcl_platform(debug)]} {
    package ifneeded udp 1.0.8 [list load [file join $dir udp108g.dll]]
} else {
    package ifneeded udp 1.0.8 [list load [file join $dir udp108.dll]]
}
