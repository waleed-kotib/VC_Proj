#
# Immediate loading of Snack because of item types etc.
#
# Jason Tang: http://mini.net/tcl/2647
#  libsnack blocks if sound device is in use; so detect by trying to open /dev/dsp 
# Mats Bengtsson: don't know how general this fix is.

if {![catch {open /dev/dsp "WRONLY NONBLOCK"} f]} {
    close $f
    package ifneeded snack 2.2 "[list load [file join $dir libsnack.so]]; \
      [list source [file join $dir snack.tcl]]"
}
