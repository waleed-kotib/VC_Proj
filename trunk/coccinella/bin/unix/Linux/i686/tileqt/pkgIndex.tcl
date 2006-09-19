#
# pkgIndex.tcl.  Generated from pkgIndex.tcl.in by configure.
#
#package ifneeded tile::theme::tileqt 0.4 [subst {
#    load [file join $dir libtileqt0.4.so] tileqt
#}]

# tileqt crashes on tclkits 8.4.11 and older. Only my own build?

if {[lindex [file system [info library]] 0] ne "native"} {
    if {[package vcompare [info patchlevel] 8.4.12] <= 0} {
	puts stderr "Warning: the tileqt package rejected loading on tclkit 8.4.12 or earlier"
	return
    }   
}
package ifneeded tile::theme::tileqt 0.4  [list load [file join $dir libtileqt0.4.so] tileqt]
