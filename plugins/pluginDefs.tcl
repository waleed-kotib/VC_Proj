# Each plugin is represented by a single line of code.
# The 'dir' variable is set in the ::Plugins:: namespace.
#

#::Plugins::Load [file join $dir Example.tcl] ::Example::Init
::Plugins::Load [file join $dir PluginTextPlain.tcl] ::TextImporter::Init
::Plugins::Load [file join $dir HtmlImport.tcl] ::HtmlImport::Init
if {[string equal $::tcl_platform(platform) "windows"]} {
    ::Plugins::Load [file join $dir WinImport.tcl] ::WinImport::Init
}
