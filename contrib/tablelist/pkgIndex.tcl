#==============================================================================
# Tablelist and Tablelist_tile package index file.
#
# Copyright (c) 2000-2008  Csaba Nemethi (E-mail: csaba.nemethi@t-online.de)
#==============================================================================

#
# Regular packages:
#
package ifneeded tablelist         4.9.1 \
	[list source [file join $dir tablelist.tcl]]
package ifneeded tablelist_tile    4.9.1 \
	[list source [file join $dir tablelist_tile.tcl]]

#
# Aliases:
#
package ifneeded Tablelist         4.9.1 \
	[list package require -exact tablelist	    4.9.1]
package ifneeded Tablelist_tile    4.9.1 \
	[list package require -exact tablelist_tile 4.9.1]

#
# Code common to all packages:
#
package ifneeded tablelist::common 4.9.1 \
        "namespace eval ::tablelist { proc DIR {} {return [list $dir]} } ;\
	 source [list [file join $dir tablelistPublic.tcl]]"
