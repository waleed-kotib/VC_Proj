# $Id: pkgIndex.tcl,v 1.1 2004-04-08 07:17:19 matben Exp $
package ifneeded tcom 3.8 \
[list load [file join $dir tcom.dll]]\n[list source [file join $dir tcom.tcl]]
