# Tcl package index file - handcrafted
#
# $Id: pkgIndexORIG.tcl,v 1.2 2004-08-17 14:10:30 matben Exp $

package ifneeded xml::c 2.0 [list load [file join $dir @RELPATH@ @TCLXML_LIB_FILE@]]
package ifneeded xml::tcl 2.0 [list source [file join $dir xml__tcl.tcl]]
package ifneeded xml::expat 2.0 [list load [file join $dir @RELPATH@ @expat_TCL_LIB_FILE@]]
package ifneeded xml::xerces 2.0 [list load [file join $dir @RELPATH@ @xerces_TCL_LIB_FILE@]]
package ifneeded sgmlparser 1.0 [list source [file join $dir sgmlparser.tcl]]

package ifneeded xpath 1.0 [list source [file join $dir xpath.tcl]]

namespace eval ::xml {}

# Requesting a specific package means we want it to be the default parser class.
# This is achieved by loading it last.

# expat and xerces packages must have xml::c package loaded
package ifneeded expat 2.0 {
    package require xml::c
    package require xmldefs
    package require xml::tclparser
    catch {package require xml::xerces}
    package require xml::expat 2.0
    package provide expat 2.0
}
package ifneeded xerces 2.0 {
    package require xml::c
    package require xmldefs
    package require xml::tclparser
    catch {package require xml::expat}
    package require xml::xerces 2.0
    package provide xerces 2.0
}

# tclparser works with either xml::c or xml::tcl
package ifneeded tclparser 2.0 {
    if {[catch {package require xml::c}]} {
	# No point in trying to load expat or xerces
	package require xml::tcl
	package require xmldefs
	package require xml::tclparser
    } else {
	package require xmldefs
	catch {package require xml::expat}
	catch {package require xml::xerces}
	package require xml::tclparser
    }
    package provide tclparser 2.0
}

# Requesting the generic package leaves the choice of default parser automatic

package ifneeded xml 2.0 {
    if {[catch {package require xml::c}]} {
	package require xml::tcl
	package require xmldefs
	# Only choice is tclparser
	package require xml::tclparser
    } else {
	package require xmldefs
	package require xml::tclparser
	catch {package require xml::expat 2.0}
	catch {package require xml::xerces 2.0}
    }
    package provide xml 2.0
}

if {[info tclversion] <= 8.0} {
    package ifneeded sgml 1.8 [list source [file join $dir sgml-8.0.tcl]]
    package ifneeded xmldefs 2.0 [list source [file join $dir xml-8.0.tcl]]
    package ifneeded xml::tclparser 2.0 [list source [file join $dir tclparser-8.0.tcl]]
} else {
    package ifneeded sgml 1.8 [list source [file join $dir sgml-8.1.tcl]]
    package ifneeded xmldefs 2.0 [list source [file join $dir xml-8.1.tcl]]
    package ifneeded xml::tclparser 2.0 [list source [file join $dir tclparser-8.1.tcl]]
}


