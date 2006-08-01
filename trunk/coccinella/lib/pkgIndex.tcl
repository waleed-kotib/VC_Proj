# Tcl package index file, version 1.1
# This file is generated by the "pkg_mkIndex" command
# and sourced either when an application starts up or
# by a "package unknown" script.  It invokes the
# "package ifneeded" command to set up package-related
# information so that packages will be loaded automatically
# in response to "package require" commands.  When this
# script is sourced, the variable $dir must contain the
# full path name of this file's directory.

package ifneeded AMenu           1.0 [list source [file join $dir AMenu.tcl]]
package ifneeded Bookmarks       1.0 [list source [file join $dir Bookmarks.tcl]]
package ifneeded Dialogs         1.0 [list source [file join $dir Dialogs.tcl]]
package ifneeded EditDialogs     1.0 [list source [file join $dir EditDialogs.tcl]]
package ifneeded FactoryDefaults 1.0 [list source [file join $dir SetFactoryDefaults.tcl]]
package ifneeded FileCache       1.0 [list source [file join $dir FileCache.tcl]]
package ifneeded Httpd           1.0 [list source [file join $dir Httpd.tcl]]
package ifneeded HttpTrpt        1.0 [list source [file join $dir HttpTrpt.tcl]]
package ifneeded ITree           1.0 [list source [file join $dir ITree.tcl]]
package ifneeded Network         1.0 [list source [file join $dir Network.tcl]]
package ifneeded P2P             1.0 [list source [file join $dir P2P.tcl]]
package ifneeded P2PNet          1.0 [list source [file join $dir P2PNet.tcl]]
package ifneeded PrefGeneral     1.0 [list source [file join $dir PrefGeneral.tcl]]
package ifneeded PrefNet         1.0 [list source [file join $dir PrefNet.tcl]]
package ifneeded PrefUtils       1.0 [list source [file join $dir PrefUtils.tcl]]
package ifneeded Preferences     1.0 [list source [file join $dir Preferences.tcl]]
package ifneeded Proxy           1.0 [list source [file join $dir Proxy.tcl]]
package ifneeded Sounds          1.0 [list source [file join $dir Sounds.tcl]]
package ifneeded Speech          1.0 [list source [file join $dir Speech.tcl]]
package ifneeded Splash          1.0 [list source [file join $dir Splash.tcl]]
package ifneeded TinyHttpd       1.0 [list source [file join $dir TinyHttpd.tcl]]
package ifneeded Theme           1.0 [list source [file join $dir Theme.tcl]]
package ifneeded TheServer       1.0 [list source [file join $dir TheServer.tcl]]
package ifneeded Types           1.0 [list source [file join $dir Types.tcl]]
package ifneeded UI              1.0 [list source [file join $dir UI.tcl]]
package ifneeded UI::WSearch     1.0 [list source [file join $dir WSearch.tcl]]
package ifneeded UserActions     1.0 [list source [file join $dir UserActions.tcl]]
package ifneeded Utils           1.0 [list source [file join $dir Utils.tcl]]

switch -- $::tcl_platform(platform) {
    unix {
	if {[string equal [tk windowingsystem] "aqua"]} {
	    package ifneeded MacintoshUtils 1.0 [list source [file join $dir MacintoshUtils.tcl]]
	}
    }
    windows {
	package ifneeded WindowsUtils 1.0 [list source [file join $dir WindowsUtils.tcl]]
    }
}
