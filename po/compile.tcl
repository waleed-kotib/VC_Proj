#!/bin/sh
# The next line restarts using wish \
exec tclsh "$0" "$@"

### Convert gettext .po source files to "compiled" Tcl msgcat .msg files  

# Put contents of the file LINGUAS into variable "linguas"
set fp [open "LINGUAS" r]
set linguas [read $fp]
close $fp

# Execute compile command for each language code
foreach lang $linguas {
	# Create ../msgs/lang.msg file with all translated strings found in ./lang.po
	exec msgfmt --tcl -l $lang -d ../msgs/ ./$lang.po
}