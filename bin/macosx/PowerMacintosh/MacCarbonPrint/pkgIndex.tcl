#
#  We need both dynaimc lib and script support files.

package ifneeded MacCarbonPrint 0.2 "load [file join $dir MacCarbonPrint.dylib]; \
    source [file join $dir maccarbonprint.tcl]"
