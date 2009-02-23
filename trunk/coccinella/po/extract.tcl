#!/bin/sh
# The next line restarts using wish \
exec tclsh "$0" "$@"

### Extract strings from source to template.pot

# Put contents of the file ../VERSION into variable "version"
set fp [open "../VERSION" r]
set version [read $fp]
close $fp

# Extract command
exec xgettext --sort-by-file --msgid-bugs-address=https://bugs.launchpad.net/coccinella/+filebug --copyright-holder="The-Coccinella-Project" --package-name=Coccinella --package-version=$version --from-code=UTF-8 --add-comments=TRANSLATORS --language=tcl --keyword=mc --files-from=./POTFILES.in --output=./template.pot