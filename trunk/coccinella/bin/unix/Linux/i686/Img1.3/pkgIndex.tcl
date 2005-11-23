# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.3 2005-11-23 12:54:00 matben Exp $

package ifneeded zlibtcl 1.0 [list load [file join $dir libzlibtcl1.0.so]]

# distinguish static and dyn variants, later.
if {0} {
package ifneeded zlibtcl 1.0 [string map [list @dir@ $dir] \
"if {[catch {load [file join @dir@ libzlibtcl1.0.so]}]} {
    load [file join @dir@ libzlibtcl1.0.so]
}"]
}
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.3 2005-11-23 12:54:00 matben Exp $

package ifneeded pngtcl 1.0 [list load [file join $dir libpngtcl1.0.so]]

# distinguish static and dyn variants, later.
if {0} {
package ifneeded pngtcl 1.0 [string map [list @dir@ $dir] \
"if {[catch {load [file join @dir@ libpngtcl1.0.so]}]} {
    load [file join @dir@ libpngtcl1.0.so]
}"]
}
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.3 2005-11-23 12:54:00 matben Exp $

package ifneeded tifftcl 1.0 [list load [file join $dir libtifftcl1.0.so]]

# distinguish static and dyn variants, later.
if {0} {
package ifneeded tifftcl 1.0 [string map [list @dir@ $dir] \
"if {[catch {load [file join @dir@ libtifftcl1.0.so]}]} {
    load [file join @dir@ libtifftcl1.0.so]
}"]
}
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.3 2005-11-23 12:54:00 matben Exp $

package ifneeded jpegtcl 1.0 [list load [file join $dir libjpegtcl1.0.so]]

# distinguish static and dyn variants, later.
if {0} {
package ifneeded jpegtcl 1.0 [string map [list @dir@ $dir] \
"if {[catch {load [file join @dir@ libjpegtcl1.0.so]}]} {
    load [file join @dir@ libjpegtcl1.0.so]
}"]
}
# -*- tcl -*- Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.3 2005-11-23 12:54:00 matben Exp $

package ifneeded img::base 1.3 [list load [file join $dir libtkimg1.3.so]]

package ifneeded Img   1.3 {
    # Compatibility hack. When asking for the old name of the package
    # then load all format handlers and base libraries provided by tkImg.
    # Actually we ask only for the format handlers, the required base
    # packages will be loaded automatically through the usual package
    # mechanism.

    # When reading images without specifying it's format (option -format),
    # the available formats are tried in reversed order as listed here.
    # Therefore file formats with some "magic" identifier, which can be
    # recognized safely, should be added at the end of this list.

    package require img::window
    package require img::tga
    package require img::ico
    package require img::pcx
    package require img::sgi
    package require img::sun
    package require img::xbm
    package require img::xpm
    package require img::ps
    package require img::jpeg
    package require img::png
    package require img::tiff
    package require img::bmp
    package require img::ppm
    package require img::gif
    package require img::pixmap

    package provide Img 1.3
}
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.3 2005-11-23 12:54:00 matben Exp $

package ifneeded "img::bmp" 1.3 [list load [file join $dir libtkimgbmp1.3.so]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.3 2005-11-23 12:54:00 matben Exp $

package ifneeded "img::gif" 1.3 [list load [file join $dir libtkimggif1.3.so]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.3 2005-11-23 12:54:00 matben Exp $

package ifneeded "img::ico" 1.3 [list load [file join $dir libtkimgico1.3.so]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.3 2005-11-23 12:54:00 matben Exp $

package ifneeded "img::jpeg" 1.3 [list load [file join $dir libtkimgjpeg1.3.so]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.3 2005-11-23 12:54:00 matben Exp $

package ifneeded "img::pcx" 1.3 [list load [file join $dir libtkimgpcx1.3.so]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.3 2005-11-23 12:54:00 matben Exp $

package ifneeded "img::pixmap" 1.3 [list load [file join $dir libtkimgpixmap1.3.so]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.3 2005-11-23 12:54:00 matben Exp $

package ifneeded "img::png" 1.3 [list load [file join $dir libtkimgpng1.3.so]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.3 2005-11-23 12:54:00 matben Exp $

package ifneeded "img::ppm" 1.3 [list load [file join $dir libtkimgppm1.3.so]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.3 2005-11-23 12:54:00 matben Exp $

package ifneeded "img::ps" 1.3 [list load [file join $dir libtkimgps1.3.so]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.3 2005-11-23 12:54:00 matben Exp $

package ifneeded "img::sgi" 1.3 [list load [file join $dir libtkimgsgi1.3.so]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.3 2005-11-23 12:54:00 matben Exp $

package ifneeded "img::sun" 1.3 [list load [file join $dir libtkimgsun1.3.so]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.3 2005-11-23 12:54:00 matben Exp $

package ifneeded "img::tga" 1.3 [list load [file join $dir libtkimgtga1.3.so]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.3 2005-11-23 12:54:00 matben Exp $

package ifneeded "img::tiff" 1.3 [list load [file join $dir libtkimgtiff1.3.so]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.3 2005-11-23 12:54:00 matben Exp $

package ifneeded "img::window" 1.3 [list load [file join $dir libtkimgwindow1.3.so]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.3 2005-11-23 12:54:00 matben Exp $

package ifneeded "img::xbm" 1.3 [list load [file join $dir libtkimgxbm1.3.so]]
# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.3 2005-11-23 12:54:00 matben Exp $

package ifneeded "img::xpm" 1.3 [list load [file join $dir libtkimgxpm1.3.so]]
