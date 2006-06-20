#
# Tcl package index file
#
if {[file exists /dev/dsp] && [file writable /dev/dsp]} {
    if {![catch {open /dev/dsp "WRONLY NONBLOCK"} f]} {
	close $f
	package ifneeded iaxclient 0.1 \
	  [list load [file join $dir libiaxclient0.1.so] iaxclient]
    }
}

