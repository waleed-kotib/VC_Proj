#
#  We need both dynaimc lib and script support files.

package ifneeded MacCarbonPrint 0.3.3 "[list load [file join $dir MacCarbonPrint0.3.3.dylib]]; \
    [list source [file join $dir maccarbonprint.tcl]]"