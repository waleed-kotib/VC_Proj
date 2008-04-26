#
#  We need both dynaimc lib and script support files.

package ifneeded tkpath 0.3.0 "[list load [file join $dir tkpath0.3.0.dylib]]; \
    [list source [file join $dir tkpath.tcl]]"
  