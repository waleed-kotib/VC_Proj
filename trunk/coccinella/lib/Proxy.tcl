#  Proxy.tcl ---
#  
#       This file is part of The Coccinella application.
#       It is supposed to provide proxy support for http. 
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: Proxy.tcl,v 1.2 2005-08-28 15:15:05 matben Exp $
 
package require autoproxy

package provide Proxy 1.0

namespace eval ::Proxy:: {
    
    ::hooks::register prefsInitHook          ::Proxy::InitPrefsHook
    ::hooks::register prefsBuildHook         ::Proxy::BuildPrefsHook
    ::hooks::register prefsSaveHook          ::Proxy::SavePrefsHook
    ::hooks::register prefsCancelHook        ::Proxy::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::Proxy::UserDefaultsHook
}

proc ::Proxy::InitPrefsHook { } {
    global  prefs
    
    variable keySpecs
    array set keySpecs {
	setNATip        0
	NATip           ""
	proxyauth       0
	proxy_host      ""
	proxy_port      ""
	proxy_user      ""
	proxy_pass      ""
	noproxy         ""
    }
    
    # Just a dummy initialization.
    foreach {key value} [array get keySpecs] {
	set prefs($key) $value
    }
    
    # Configure and set our defaults.
    # Note: -basic {Proxy-Authorization {Basic bWF0czp6eno=}}
    autoproxy::init    
    foreach {key value} [::autoproxy::configure] {
	switch -- $key {
	    -basic  { 
		# we can't get username & password from this.
	    }
	    -no_proxy - -proxy_port - -proxy_host {
		set name [string trimleft $key "-"]
		set prefs($name) $value
	    }
	}
    }
    
    ::PrefUtils::Add [list  \
      [list prefs(setNATip)       prefs_setNATip       $prefs(setNATip)]      \
      [list prefs(NATip)          prefs_NATip          $prefs(NATip)]         \
      [list prefs(proxy_host)     prefs_proxyhost      $prefs(proxy_host)]    \
      [list prefs(proxy_port)     prefs_proxyport      $prefs(proxy_port)]    \
      [list prefs(proxyauth)      prefs_proxyauth      $prefs(proxyauth)]     \
      [list prefs(proxy_user)     prefs_proxyuser      $prefs(proxy_user)]    \
      [list prefs(proxy_pass)     prefs_proxypass      $prefs(proxy_pass)]    \
      [list prefs(noproxy)        prefs_noproxy        $prefs(noproxy)]       \
      ]
    
    # We shall do our http proxy configuration here transparently for any
    # package that uses the http package.
    # Any user settings override the one we get when autoproxy::init. 
    AutoProxyConfig
}

proc ::Proxy::AutoProxyConfig { } {
    global  prefs
    
    ::autoproxy::configure  \
      -proxy_host $prefs(proxy_host) \
      -proxy_port $prefs(proxy_port) \
      -no_proxy   $prefs(no_proxy)
    
    if {[string length $prefs(proxy_user)]} {
	::autoproxy::configure  \
	  -basic -user $prefs(proxy_user) -pass $prefs(proxy_pass)
    }
}

proc ::Proxy::BuildPrefsHook {wtree nbframe} {
    
    $wtree newitem {General {Proxy Setup}} -text [mc {Proxy Setup}]
    
    set wpage [$nbframe page {Proxy Setup}]    
    ::Proxy::BuildPage $wpage
}

proc ::Proxy::BuildPage {wpage} {
    global  prefs
    variable tmpPrefs
    variable wnoproxy
    
    set prefs(noproxy) [lsort -unique $prefs(noproxy)]
    
    foreach key {setNATip NATip \
      proxy_host proxy_port proxyauth \
      proxy_user proxy_pass noproxy} {
	set tmpPrefs($key) $prefs($key)
    }
    
    set wc $wpage.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]
    
    set wprx $wc.proxy
    set wnat $wc.nat

    # Proxy.
    ttk::labelframe $wprx -text [mc {Http Proxy}]  \
      -padding [option get . groupSmallPadding {}]
    
    ttk::label $wprx.msg -wraplength 300 -justify left \
      -text "Usage of the Http proxy is determined\
      by each profile settings. File transfers wont work if you use Http proxy!"
    
    ttk::label $wprx.lserv -text [mc {Proxy Server}]:
    ttk::entry $wprx.eserv -textvariable [namespace current]::tmpPrefs(proxy_host)
    ttk::label $wprx.lport -text [mc {Proxy Port}]:
    ttk::entry $wprx.eport -textvariable [namespace current]::tmpPrefs(proxy_port)
    ttk::checkbutton $wprx.auth -text [mc {Use proxy authorization}] \
      -variable [namespace current]::tmpPrefs(proxyauth)
    ttk::label $wprx.luser -text [mc Username]:
    ttk::entry $wprx.euser -textvariable [namespace current]::tmpPrefs(proxy_user)
    ttk::label $wprx.lpass -text [mc Password]:
    ttk::entry $wprx.epass -textvariable [namespace current]::tmpPrefs(proxy_pass)
  
    set wnoproxy $wprx.noproxy
    ttk::label $wprx.lnop -text [mc {Exclude addresses (* as wildcard)}]:
    text $wprx.noproxy -font CociSmallFont -height 4 -width 24 -bd 1 -relief sunken
    
    grid  $wprx.msg      -            -sticky w
    grid  $wprx.lserv    $wprx.eserv
    grid  $wprx.lport    $wprx.eport
    grid  x              $wprx.auth   -sticky w
    grid  $wprx.luser    $wprx.euser
    grid  $wprx.lpass    $wprx.epass
    grid  $wprx.lnop     -            -sticky w
    grid  $wprx.noproxy  -            -sticky ew -pady 1
    
    grid  $wprx.lserv  $wprx.lport  $wprx.luser  $wprx.lpass  -sticky e
    grid  $wprx.eserv  $wprx.eport  $wprx.euser  $wprx.epass  -sticky ew
    
    foreach addr $tmpPrefs(noproxy) {
	$wnoproxy insert end $addr
	$wnoproxy insert end "\n"
    }
    
    # NAT address.
    ttk::labelframe $wnat -text [mc {NAT Address}] \
      -padding [option get . groupSmallPadding {}]
    ttk::checkbutton $wnat.cb -text [mc prefnatip] \
      -variable [namespace current]::tmpPrefs(setNATip)
    ttk::entry $wnat.eip \
      -textvariable [namespace current]::tmpPrefs(NATip)

    grid  $wnat.cb  -sticky w
    grid  $wnat.eip -sticky ew
    grid columnconfigure $wnat 0 -weight 1
    
    set anchor [option get . dialogAnchor {}]

    pack  $wprx  -side top -fill x -anchor $anchor
    pack  $wnat  -side top -fill x -anchor $anchor -pady 12
}

proc ::Proxy::GetNoProxyList { } {    
    variable wnoproxy

    set str [string trim [$wnoproxy get 1.0 end]]
    return [lsort -unique [split $str "\n"]]
}

proc ::Proxy::SavePrefsHook { } {
    global  prefs
    variable tmpPrefs
    variable wnoproxy
    
    set tmpPrefs(noproxy) [GetNoProxyList]
    array set prefs [array get tmpPrefs]
    unset tmpPrefs
    
    set prefs(proxy_user) [string trim $prefs(proxy_user)]
    set prefs(proxy_pass) [string trim $prefs(proxy_pass)]
    
    AutoProxyConfig
}

proc ::Proxy::CancelPrefsHook { } {
    global  prefs
    variable tmpPrefs
    variable wnoproxy
    variable keySpecs
    
    set tmpPrefs(noproxy) [GetNoProxyList]
    	
    foreach key [array names keySpecs] {
	if {![string equal $prefs($key) $tmpPrefs($key)]} {
	    puts "\t key=$key, $prefs($key), $tmpPrefs($key)"
	    ::Preferences::HasChanged
	    break
	}
    }
    if {![string equal $prefs(noproxy) $tmpPrefs(noproxy)]} {
	::Preferences::HasChanged
    }
}

proc ::Proxy::UserDefaultsHook { } {
    global  prefs
    variable tmpPrefs
    variable wnoproxy
    variable keySpecs
    
    foreach key [array names keySpecs] {
	set tmpPrefs($key) $prefs($key)
    }
}

#-------------------------------------------------------------------------------
