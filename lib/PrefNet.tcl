#  PrefNet.tcl ---
#  
#       This file is part of The Coccinella application. 
#       It implements network prefs dialogs and panel.
#      
#  Copyright (c) 2005-2007  Mats Bengtsson
#  
# $Id: PrefNet.tcl,v 1.9 2007-04-19 09:31:41 matben Exp $
 
package provide PrefNet 1.0

namespace eval ::PrefNet:: {

    ::hooks::register prefsInitHook          ::PrefNet::InitPrefsHook  20
    ::hooks::register prefsBuildHook         ::PrefNet::BuildPrefsHook 20
    ::hooks::register prefsSaveHook          ::PrefNet::SavePrefsHook  20
    ::hooks::register prefsCancelHook        ::PrefNet::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::PrefNet::UserDefaultsHook
}

proc ::PrefNet::InitPrefsHook { } {
    global  prefs
        
    # ip numbers, port numbers, and names.
    set prefs(thisServPort) 8235

    # The tinyhttpd server port number and base directory.
    set prefs(httpdPort) 8077

    ::PrefUtils::Add [list  \
      [list prefs(thisServPort)    prefs_thisServPort    $prefs(thisServPort)]   \
      [list prefs(httpdPort)       prefs_httpdPort       $prefs(httpdPort)]      \
      ]    
}

proc ::PrefNet::BuildPrefsHook {wtree nbframe} {
    
    if {![::Preferences::HaveTableItem General]} {
	::Preferences::NewTableItem {General} [mc General]
    }
    ::Preferences::NewTableItem {General {Network}} [mc {Network}]
    set wpage [$nbframe page {Network}]
    BuildTabPage $wpage
}

proc ::PrefNet::SavePrefsHook { } {
    ::Proxy::SavePrefsHook
    ServersSaveHook
}

proc ::PrefNet::CancelPrefsHook { } {
    ::Proxy::CancelPrefsHook
    ServersCancelHook
}

proc ::PrefNet::UserDefaultsHook { } {
    ::Proxy::UserDefaultsHook
    ServersUserDefaultsHook
}

proc ::PrefNet::BuildTabPage {wpage} {
    
    set anchor [option get . dialogAnchor {}]
    set padding [option get . notebookPageSmallPadding {}]
    
    set wc $wpage.c
    ttk::frame $wc -padding $padding
    pack $wc -side top -anchor $anchor
 
    set nb $wc.nb
    ttk::notebook $nb -padding {8 8 8 4}
    pack $nb -side top -anchor $anchor
    
    ::Proxy::BuildFrame $nb.proxy
    $nb.proxy configure -padding $padding
    $nb add $nb.proxy -text [mc Proxy] -sticky news
    
    ::Proxy::BuildNATFrame $nb.nat
    $nb.nat configure -padding $padding
    $nb add $nb.nat -text [mc NAT] -sticky news
     
    BuildServersFrame $nb.serv
    $nb.serv configure -padding $padding
    $nb add $nb.serv -text [mc Servers] -sticky news

    return $wpage
}
    
proc ::PrefNet::BuildServersFrame {w} {
    global  this prefs    

    variable tmpServPrefs
    upvar ::Jabber::jprefs jprefs
    
    set tmpServPrefs(thisServPort)      $prefs(thisServPort)
    set tmpServPrefs(httpdPort)         $prefs(httpdPort)
    set tmpServPrefs(bytestreams,port)  $jprefs(bytestreams,port)

    ttk::frame $w
    
    set f $w.f
    ttk::frame $f
    pack $f -side top -anchor [option get . dialogAnchor {}]

    ttk::label $f.lserv -text "[mc {Built in server port}]:"
    ttk::label $f.lhttp -text "[mc {HTTP port}]:"
    ttk::label $f.lbs   -text "[mc {File transfer port}]:"
    ttk::entry $f.eserv -width 6 -textvariable  \
      [namespace current]::tmpServPrefs(thisServPort)
    ttk::entry $f.ehttp -width 6 -textvariable  \
      [namespace current]::tmpServPrefs(httpdPort)
    ttk::entry $f.ebs -width 6 -textvariable  \
      [namespace current]::tmpServPrefs(bytestreams,port)

    grid  $f.lserv  $f.eserv  -sticky e -pady 2
    grid  $f.lhttp  $f.ehttp  -sticky e -pady 2
    grid  $f.lbs    $f.ebs    -sticky e -pady 2
    grid columnconfigure $f 0 -weight 1
    
    if {!$prefs(haveHttpd)} {
	$f.ehttp state {disabled}
    }
    bind $w <Destroy> [namespace code ServersFree]
    return $w
}

proc ::PrefNet::ServersSaveHook {} {
    global  prefs
    variable tmpServPrefs
    upvar ::Jabber::jprefs jprefs

    set prefs(thisServPort)      $tmpServPrefs(thisServPort)
    set prefs(httpdPort)         $tmpServPrefs(httpdPort)
    set jprefs(bytestreams,port) $tmpServPrefs(bytestreams,port)    
}

proc ::PrefNet::ServersCancelHook {} {
    global  prefs
    variable tmpServPrefs
    upvar ::Jabber::jprefs jprefs

    if {![string equal $prefs(thisServPort) $tmpServPrefs(thisServPort)] || \
      ![string equal $prefs(httpdPort) $tmpServPrefs(httpdPort)] || \
      ![string equal $jprefs(bytestreams,port) $tmpServPrefs(bytestreams,port)]} {
	::Preferences::HasChanged
      }
}

proc ::PrefNet::ServersUserDefaultsHook {} {
    global  prefs
    variable tmpServPrefs
    upvar ::Jabber::jprefs jprefs

    set tmpServPrefs(thisServPort)      $prefs(thisServPort)
    set tmpServPrefs(httpdPort)         $prefs(httpdPort)
    set tmpServPrefs(bytestreams,port)  $jprefs(bytestreams,port)    
}

proc ::PrefNet::ServersFree {} {
    variable tmpServPrefs
    unset -nocomplain tmpServPrefs
}
    
#-------------------------------------------------------------------------------
