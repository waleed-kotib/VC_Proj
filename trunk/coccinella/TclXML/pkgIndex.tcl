# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.4 2004-08-17 14:10:30 matben Exp $

# Handcrafted paths for the Coccinella by Mats Bengtsson
# Mats: very much stripped down version to load my patched version only.

package ifneeded xml::tcl 2.0 [list source [file join $dir xml__tcl.tcl]]
package ifneeded sgmlparser 1.0 [list source [file join $dir sgmlparser.tcl]]

package ifneeded xpath 1.0 [list source [file join $dir xpath.tcl]]

namespace eval ::xml {}


package ifneeded tclparser 2.0 {
    package require xml::tcl
    package require xmldefs
    package require xml::tclparser
    package provide tclparser 2.0
}

package ifneeded xml 3.0 {
    package require xml::tcl
    package require xmldefs
    # Only choice is tclparser
    package require xml::tclparser
    package provide xml 3.0
}

package ifneeded sgml 1.8 [list source [file join $dir sgml-8.1.tcl]]
package ifneeded xmldefs 2.0 [list source [file join $dir xml-8.1.tcl]]
package ifneeded xml::tclparser 2.0 [list source [file join $dir tclparser-8.1.tcl]]



