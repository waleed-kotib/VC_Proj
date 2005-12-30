#
# This is an example of how to hardcode some configurations at build time
# by including a 'config.tcl' file in resources/
#

array set config {
    login,style         "username"
    login,more          1
    login,profiles      0
    login,autosave      1
    autoupdate,do       1
    autoupdate,url      "http://coccinella.sourceforge.net/updates/update_en.xml"
    profiles,do         1
    profiles,profiles   {evaal {localhost "" ""}}
    profiles,selected   evaal
    profiles,prefspanel 0
    ui,pruneMenus       {mInfo {mDebug mCoccinellaHome} mJabber {mNewAccount}}
}
