# Tcl package index file, version 1.1
# This file is generated by the "pkg_mkIndex" command
# and sourced either when an application starts up or
# by a "package unknown" script.  It invokes the
# "package ifneeded" command to set up package-related
# information so that packages will be loaded automatically
# in response to "package require" commands.  When this
# script is sourced, the variable $dir must contain the
# full path name of this file's directory.

package ifneeded CanvasCutCopyPaste 1.0 [list source [file join $dir CanvasCutCopyPaste.tcl]]
package ifneeded CanvasDraw 1.0 [list source [file join $dir CanvasDraw.tcl]]
package ifneeded CanvasText 1.0 [list source [file join $dir CanvasText.tcl]]
package ifneeded CanvasUtils 1.0 [list source [file join $dir CanvasUtils.tcl]]
package ifneeded Connections 1.0 [list source [file join $dir Connections.tcl]]
package ifneeded Dialogs 1.0 [list source [file join $dir Dialogs.tcl]]
package ifneeded FilesAndCanvas 1.0 [list source [file join $dir FilesAndCanvas.tcl]]
package ifneeded FileCache 1.0 [list source [file join $dir FileCache.tcl]]
package ifneeded PreferencesUtils 1.0 [list source [file join $dir PreferencesUtils.tcl]]
package ifneeded Preferences 1.0 [list source [file join $dir Preferences.tcl]]
package ifneeded Sounds 1.0 [list source [file join $dir Sounds.tcl]]
package ifneeded TinyHttpd 1.0 [list source [file join $dir TinyHttpd.tcl]]
package ifneeded Types 1.0 [list source [file join $dir Types.tcl]]
package ifneeded Plugins 1.0 [list source [file join $dir Plugins.tcl]]
package ifneeded AutoUpdate 1.0 [list source [file join $dir AutoUpdate.tcl]]

if {[string equal $::tcl_platform(platform) "windows"]} {
    package ifneeded WindowsUtils 1.0 [list source [file join $dir WindowsUtils.tcl]]
}