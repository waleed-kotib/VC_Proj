# Tcl package index file - handcrafted
#
# $Id: pkgIndex.tcl,v 1.5 2004-09-02 13:59:38 matben Exp $

# Handcrafted paths for the Coccinella by Mats Bengtsson
# Mats: very much stripped down version to load my patched version only.
#       the 99.0 version number is a ugly trick to make sure it does not
#       interfere with any existing TclXML installation.

package ifneeded xml::tcl 99.0 [list source [file join $dir xml__tcl.tcl]]
package ifneeded sgmlparser 99.0 [list source [file join $dir sgmlparser.tcl]]

package ifneeded xpath 1.0 [list source [file join $dir xpath.tcl]]

namespace eval ::xml {}


package ifneeded tclparser 99.0 {
    package require xml::tcl 99.0
    package require xmldefs
    package require xml::tclparser 99.0
    package provide tclparser 99.0
}

package ifneeded xml 99.0 {
    package require xml::tcl 99.0
    package require xmldefs
    # Only choice is tclparser
    package require xml::tclparser 99.0
    package provide xml 99.0
}

package ifneeded sgml 1.8 [list source [file join $dir sgml-8.1.tcl]]
package ifneeded xmldefs 2.0 [list source [file join $dir xml-8.1.tcl]]
package ifneeded xml::tclparser 99.0 [list source [file join $dir tclparser-8.1.tcl]]



