# pkgIndex.tcl for additional tile pixmap themes.
#
# We don't provide the package is the image subdirectory isn't present,
# or we don't have the right version of Tcl/Tk
#
# To use this automatically within tile, the tile-using application should
# use tile::availableThemes and tile::setTheme 
#
# $Id: pkgIndex.tcl,v 1.2 2008-02-20 15:14:37 matben Exp $

if {![file isdirectory [file join $dir keramik]]} { return }
if {![package vsatisfies [package provide Tcl] 8.4]} { return }

if {[info tclversion] >= 8.5} {
    package ifneeded ttk::theme::keramik 0.3.2 \
      [list source [file join $dir keramik.tcl]]
} else {
    package ifneeded tile::theme::keramik 0.3.2 \
      [list source [file join $dir keramik.tcl]]
}