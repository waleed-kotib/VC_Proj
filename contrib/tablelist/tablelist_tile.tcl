#==============================================================================
# Main Tablelist_tile package module.
#
# Copyright (c) 2000-2006  Csaba Nemethi (E-mail: csaba.nemethi@t-online.de)
#==============================================================================

package require Tcl  8.4
package require Tk   8.4
package require tile 0.6
package require tablelist::common

package provide Tablelist_tile $::tablelist::version
package provide tablelist_tile $::tablelist::version

::tablelist::useTile 1
