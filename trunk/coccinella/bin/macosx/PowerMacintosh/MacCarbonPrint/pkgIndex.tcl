#
#  We need both dynaimc lib and script support files.

package ifneeded MacCarbonPrint 0.2 "[list load [file join $dir MacCarbonPrint.dylib]]; \
    [list source [file join $dir maccarbonprint.tcl]]"