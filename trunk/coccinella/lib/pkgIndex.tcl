# Tcl package index file, version 1.1
# This file is generated by the "pkg_mkIndex" command
# and sourced either when an application starts up or
# by a "package unknown" script.  It invokes the
# "package ifneeded" command to set up package-related
# information so that packages will be loaded automatically
# in response to "package require" commands.  When this
# script is sourced, the variable $dir must contain the
# full path name of this file's directory.

package ifneeded Dialogs 1.0 [list source [file join $dir Dialogs.tcl]]
package ifneeded FileCache 1.0 [list source [file join $dir FileCache.tcl]]
package ifneeded Httpd 1.0 [list source [file join $dir Httpd.tcl]]
package ifneeded P2P 1.0 [list source [file join $dir P2P.tcl]]
package ifneeded P2PNet 1.0 [list source [file join $dir P2PNet.tcl]]
package ifneeded PreferencesUtils 1.0 [list source [file join $dir PreferencesUtils.tcl]]
package ifneeded Preferences 1.0 [list source [file join $dir Preferences.tcl]]
package ifneeded Sounds 1.0 [list source [file join $dir Sounds.tcl]]
package ifneeded Speech 1.0 [list source [file join $dir Speech.tcl]]
package ifneeded Splash 1.0 [list source [file join $dir Splash.tcl]]
package ifneeded TinyHttpd 1.0 [list source [file join $dir TinyHttpd.tcl]]
package ifneeded Theme 1.0 [list source [file join $dir Theme.tcl]]
package ifneeded TheServer 1.0 [list source [file join $dir TheServer.tcl]]
package ifneeded Types 1.0 [list source [file join $dir Types.tcl]]

if {[string equal $::tcl_platform(platform) "windows"]} {
    package ifneeded WindowsUtils 1.0 [list source [file join $dir WindowsUtils.tcl]]
}