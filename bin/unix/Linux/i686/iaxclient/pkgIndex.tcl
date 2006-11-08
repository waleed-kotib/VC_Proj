#
# Tcl package index file
#
if {[file exists /dev/dsp] && [file writable /dev/dsp]} {
    if {![catch {open /dev/dsp "WRONLY NONBLOCK"} f]} {
	close $f
	package ifneeded iaxclient 0.2 \
	  "[list load [file join $dir libiaxclient0.2.so] iaxclient]; \
	  [list source [file join $dir iaxclient.tcl]]"
    }
}

