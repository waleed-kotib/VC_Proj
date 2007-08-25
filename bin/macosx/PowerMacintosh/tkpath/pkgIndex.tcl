#
#  We need both dynaimc lib and script support files.

package ifneeded tkpath 0.2.6 "[list load [file join $dir tkpath0.2.6.dylib]]; \
    [list source [file join $dir tkpath.tcl]]"