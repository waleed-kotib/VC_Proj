# Each plugin is represented by a single line of code.
# The 'dir' variable is set in the ::Plugins:: namespace.
#

#::Plugins::Load [file join $dir Example.tcl] ::Example::Init
::Plugins::Load [file join $dir PluginTextPlain.tcl] ::TextImporter::Init
#::Plugins::Load [file join $dir PDFImporter.tcl] ::PDFImporter::Init

