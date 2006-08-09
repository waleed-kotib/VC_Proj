#  Proxy.tcl ---
#  
#       This file is part of The Coccinella application.
#       It is supposed to provide proxy support for http. 
#      
#  Copyright (c) 2005  Mats Bengtsson
#  
# $Id: Proxy.tcl,v 1.8 2006-08-09 13:28:51 matben Exp $
 
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
	useproxy        0
	proxy_host      ""
	proxy_port      ""
	proxy_user      ""
	proxy_pass      ""
	noproxy         ""
	setNATip        0
	NATip           ""
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
      [list prefs(useproxy)       prefs_useproxy       $prefs(useproxy)]      \
      [list prefs(proxy_host)     prefs_proxyhost      $prefs(proxy_host)]    \
      [list prefs(proxy_port)     prefs_proxyport      $prefs(proxy_port)]    \
      [list prefs(proxy_user)     prefs_proxyuser      $prefs(proxy_user)]    \
      [list prefs(proxy_pass)     prefs_proxypass      $prefs(proxy_pass)]    \
      [list prefs(noproxy)        prefs_noproxy        $prefs(noproxy)]       \
      [list prefs(setNATip)       prefs_setNATip       $prefs(setNATip)]      \
      [list prefs(NATip)          prefs_NATip          $prefs(NATip)]         \
      ]
    
    # We shall do our http proxy configuration here transparently for any
    # package that uses the http package.
    # Any user settings override the one we get when autoproxy::init. 
    if {$prefs(useproxy)} {
	AutoProxyConfig
    }
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
    
    ::Preferences::NewTableItem {General {Proxy Setup}} [mc {Proxy Setup}]
    
    set wpage [$nbframe page {Proxy Setup}]    
    ::Proxy::BuildPage $wpage
}

proc ::Proxy::BuildPage {wpage} {
    global  prefs
    variable tmpPrefs
    variable wnoproxy
    variable wprx
    variable wnat
    
    set stun 0
    if {![catch {package require stun}]} {
	set stun 1
    }
    
    set prefs(noproxy) [lsort -unique $prefs(noproxy)]
    
    foreach key {setNATip NATip \
      useproxy proxy_host proxy_port \
      proxy_user proxy_pass noproxy} {
	set tmpPrefs($key) $prefs($key)
    }
    
    set wc $wpage.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor [option get . dialogAnchor {}]
    
    set wprx $wc.proxy
    set wnat $wc.nat
    variable wprxuse $wprx.use
    variable wnatuse $wnat.use
    
    # Proxy.
    ttk::labelframe $wprx -text [mc {Http Proxy}]  \
      -padding [option get . groupSmallPadding {}]
    
    ttk::label $wprx.msg -wraplength 300 -justify left \
      -text [mc prefproxymsg]
    
    ttk::checkbutton $wprx.use -text [mc {Use proxy}]  \
      -command [namespace code SetUseProxyState]  \
      -variable [namespace current]::tmpPrefs(useproxy)   
    ttk::label $wprx.lserv -text [mc {Proxy Server}]:
    ttk::entry $wprx.eserv -textvariable [namespace current]::tmpPrefs(proxy_host)
    ttk::label $wprx.lport -text [mc {Proxy Port}]:
    ttk::entry $wprx.eport -textvariable [namespace current]::tmpPrefs(proxy_port)
    ttk::label $wprx.luser -text [mc Username]:
    ttk::entry $wprx.euser -textvariable [namespace current]::tmpPrefs(proxy_user)
    ttk::label $wprx.lpass -text [mc Password]:
    ttk::entry $wprx.epass -textvariable [namespace current]::tmpPrefs(proxy_pass)
  
    set wnoproxy $wprx.noproxy
    ttk::label $wprx.lnop -text [mc prefproxyexc]:
    text $wprx.noproxy -font CociSmallFont -height 4 -width 24 -bd 1 -relief sunken
    
    grid  $wprx.msg      -            -sticky w
    grid  x              $wprx.use    -sticky w
    grid  $wprx.lserv    $wprx.eserv  -pady 1
    grid  $wprx.lport    $wprx.eport  -pady 1
    grid  $wprx.luser    $wprx.euser  -pady 1
    grid  $wprx.lpass    $wprx.epass  -pady 1
    grid  $wprx.lnop     -            -sticky w
    grid  $wprx.noproxy  -            -sticky ew -pady 1
    
    grid  $wprx.lserv  $wprx.lport  $wprx.luser  $wprx.lpass  -sticky e
    grid  $wprx.eserv  $wprx.eport  $wprx.euser  $wprx.epass  -sticky ew
    
    foreach addr $tmpPrefs(noproxy) {
	$wnoproxy insert end $addr
	$wnoproxy insert end "\n"
    }
    SetUseProxyState
    
    # NAT address.
    ttk::labelframe $wnat -text [mc {NAT Address}] \
      -padding [option get . groupSmallPadding {}]
    ttk::checkbutton $wnat.use -text [mc prefnatip] \
      -command [namespace code SetUseNATState]  \
      -variable [namespace current]::tmpPrefs(setNATip)
    ttk::entry $wnat.eip \
      -textvariable [namespace current]::tmpPrefs(NATip)
    if {$stun} {
	ttk::button $wnat.stun -text [mc Get] -command ::Proxy::GetStun
    }
    
    grid  $wnat.use  -  -sticky w
    grid  $wnat.eip  x  -sticky ew
    grid columnconfigure $wnat 0 -weight 1
    if {$stun} {
	grid  $wnat.stun  -column 1 -row 1 -padx 4
    }
    SetUseNATState
    
    set anchor [option get . dialogAnchor {}]

    pack  $wprx  -side top -fill x -anchor $anchor
    pack  $wnat  -side top -fill x -anchor $anchor -pady 12
}

proc ::Proxy::GetStun {} {
    ::stun::request stun.fwdnet.net -command ::Proxy::GetStunCB
}

proc ::Proxy::GetStunCB {token status args} {
    variable tmpPrefs
    
    array set aargs $args
    if {$status eq "ok" && [info exists aargs(-address)]} {
	set tmpPrefs(NATip) $aargs(-address)
    }   
}

proc ::Proxy::SetUseProxyState { } {
    variable wprx
    variable wprxuse
    variable tmpPrefs
    
    if {$tmpPrefs(useproxy)} {
	SetChildrenStates $wprx normal
    } else {
	SetChildrenStates $wprx disabled
    }
    $wprxuse state {!disabled}
}

proc ::Proxy::SetUseNATState { } {
    variable wnat
    variable wnatuse
    variable tmpPrefs
    
    if {$tmpPrefs(setNATip)} {
	SetChildrenStates $wnat normal
    } else {
	SetChildrenStates $wnat disabled
    }
    $wnatuse state {!disabled}
}

proc ::Proxy::SetChildrenStates {win _state} {
    
    if {$_state eq "normal" || $_state eq "!disabled"} {
	set state normal
	set ttkstate {!disabled}
    } else {
	set state    disabled
	set ttkstate {disabled}
    }    
    foreach w [winfo children $win] {
	switch -- [winfo class $w] {
	    Text - Entry {
		$w configure -state $state
	    }
	    TEntry - TButton - TCheckbutton - TRadiobutton {
		$w state $ttkstate
	    }
	}
    }
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
    
    if {$prefs(useproxy)} {
	AutoProxyConfig
    } else {
	http::config -proxyfilter {} -proxyhost {} -proxyport {}
    }
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