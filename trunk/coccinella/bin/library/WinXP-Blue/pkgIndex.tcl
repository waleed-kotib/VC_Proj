# pkgIndex.tcl for additional tile pixmap themes.
#
# We don't provide the package is the image subdirectory isn't present,
# or we don't have the right version of Tcl/Tk
#
# To use this automatically within tile, the tile-using application should
# use tile::availableThemes and tile::setTheme 
#
# $Id: pkgIndex.tcl,v 1.2 2008-02-20 15:14:37 matben Exp $

if {![file isdirectory [file join $dir WinXP-Blue]]} { return }
if {![package vsatisfies [package provide Tcl] 8.4]} { return }

if {[info tclversion] >= 8.5} {
    package ifneeded ttk::theme::winxpblue 0.5 \
      [list source [file join $dir WinXP-Blue.tcl]]
} else {
    package ifneeded tile::theme::winxpblue 0.5 \
    [list source [file join $dir WinXP-Blue.tcl]]
}