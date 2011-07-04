#  Proxy.tcl ---
#  
#       This file is part of The Coccinella application.
#       It is supposed to provide proxy support. 
#      
#  Copyright (c) 2005-2007  Mats Bengtsson
#  
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#   
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#  
# $Id: Proxy.tcl,v 1.18 2007-09-14 08:11:46 matben Exp $
 
package require autoproxy
package require autosocks

package provide Proxy 1.0

namespace eval ::Proxy {
    
    ::hooks::register prefsInitHook          ::Proxy::InitPrefsHook
}

proc ::Proxy::InitPrefsHook { } {
    global  prefs
    
    variable keySpecs
    array set keySpecs {
	useproxy        0
	proxy_type      http
	proxy_host      ""
	proxy_port      ""
	proxy_user      ""
	proxy_pass      ""
	noproxy         ""
	STUNServer	""
	setNATip        0
	NATip           ""
    }
    
    # Just a dummy initialization.
    foreach {key value} [array get keySpecs] {
	set prefs($key) $value
    }
    
    # Configure and set our defaults.
    # @@@ This will only set HTTP proxy (on windows) but we need it to depend
    #     on proxy type!
    # Note: -basic {Proxy-Authorization {Basic bWF0czp6eno=}}
    autoproxy::init    
    autosocks::init
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
      [list prefs(proxy_type)     prefs_proxytype      $prefs(proxy_type)]    \
      [list prefs(proxy_host)     prefs_proxyhost      $prefs(proxy_host)]    \
      [list prefs(proxy_port)     prefs_proxyport      $prefs(proxy_port)]    \
      [list prefs(proxy_user)     prefs_proxyuser      $prefs(proxy_user)]    \
      [list prefs(proxy_pass)     prefs_proxypass      $prefs(proxy_pass)]    \
      [list prefs(noproxy)        prefs_noproxy        $prefs(noproxy)]       \
      [list prefs(STUNServer)     prefs_STUNServer     $prefs(STUNServer)]    \
      [list prefs(setNATip)       prefs_setNATip       $prefs(setNATip)]      \
      [list prefs(NATip)          prefs_NATip          $prefs(NATip)]         \
      ]
    
    # We shall do our http proxy configuration here transparently for any
    # package that uses the http package.
    # Any user settings override the one we get when autoproxy::init. 
    if {$prefs(useproxy)} {
	if {$prefs(proxy_type) eq "http"} {
	    AutoProxyConfig
	} elseif {[string match {socks[45]} $prefs(proxy_type)]} {
	    AutoSocksConfig
	}
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

proc ::Proxy::AutoProxyOff { } {
    ::autoproxy::configure -proxy_host {} -proxy_port {} \
      -basic -user {} -pass {}
}

proc ::Proxy::AutoSocksConfig { } {
    global  prefs
    
    autosocks::config  \
      -proxy     $prefs(proxy_type) \
      -proxyhost $prefs(proxy_host) \
      -proxyport $prefs(proxy_port) \
      -proxyno   $prefs(no_proxy)
    
    if {[string length $prefs(proxy_user)]} {
	autosocks::config  \
	   -proxyusername $prefs(proxy_user) -proxypassword $prefs(proxy_pass)
    }
}

proc ::Proxy::AutoSocksOff { } {
    autosocks::config -proxy {} -proxyno {} -proxyhost {} -proxyport {} \
      -proxyusername {} -proxypassword {}
}

proc ::Proxy::BuildPage {wpage} {
    
    set anchor [option get . dialogAnchor {}]
    
    set wc $wpage.c
    ttk::frame $wc -padding [option get . notebookPageSmallPadding {}]
    pack $wc -side top -anchor $anchor

    # Proxy:
    ttk::labelframe $wc.p -text [mc "Proxy"]  \
      -padding [option get . groupSmallPadding {}]
    pack $wc.p -side top -fill x -anchor $anchor

    BuildFrame $wc.p.f
    pack $wc.p.f -side top -fill x -anchor $anchor

    # NAT:
    ttk::labelframe $wc.n -text [mc "NAT Address"] \
      -padding [option get . groupSmallPadding {}]
    pack $wc.n -side top -fill x -anchor $anchor -pady 8
    
    BuildNATFrame $wc.n.f
    pack $wc.n.f -side top -fill x -anchor $anchor

    return $wpage
}

proc ::Proxy::BuildFrame {w} {
    global  prefs
    variable tmpPrefs
    variable wnoproxy
    variable wprx

    set wprx $w.prxy
    
    set prefs(noproxy) [lsort -unique $prefs(noproxy)]
    
    foreach key {
	setNATip    NATip 
	useproxy    proxy_type  proxy_host  proxy_port 
	proxy_user  proxy_pass  noproxy
    } {
	set tmpPrefs($key) $prefs($key)
    }
        
    variable wprxuse $wprx.use
    variable wuser   $wprx.euser
    variable wpass   $wprx.epass
    
    set menulist {
	{"HTTP Proxy"  -value http}
	{"SOCKS 4"     -value socks4}
	{"SOCKS 5"     -value socks5}
    }
        
    # Proxy.
    ttk::frame $w
    ttk::frame $wprx
    pack $wprx -side top -anchor [option get . dialogAnchor {}]
    
    ttk::label $wprx.msg -wraplength 300 -justify left \
      -text [mc "Usage of this HTTP proxy settings is determined by each profile's settings. File transfers will not work if you use an HTTP proxy."]
    ttk::checkbutton $wprx.use -text [mc "Use proxy"]  \
      -command [namespace code SetUseProxyState]  \
      -variable [namespace current]::tmpPrefs(useproxy)  
    ttk::label $wprx.lmb -text [mc "Type"]:
    ui::optionmenu $wprx.mb -menulist $menulist -direction flush \
      -command [namespace code SetProxyType] \
      -variable [namespace current]::tmpPrefs(proxy_type)
    ttk::label $wprx.lserv -text [mc "Host"]:
    ttk::entry $wprx.eserv -textvariable [namespace current]::tmpPrefs(proxy_host)
    ttk::label $wprx.lport -text [mc "Port"]:
    ttk::entry $wprx.eport -textvariable [namespace current]::tmpPrefs(proxy_port) \
      -width 6
    ttk::label $wprx.luser -text [mc "Username"]:
    ttk::entry $wprx.euser -textvariable [namespace current]::tmpPrefs(proxy_user)
    ttk::label $wprx.lpass -text [mc "Password"]:
    ttk::entry $wprx.epass -textvariable [namespace current]::tmpPrefs(proxy_pass) \
      -show {*}
  
    set wnoproxy $wprx.noproxy
    ttk::label $wprx.lnop -text [mc "Exclude addresses (* as wildcard)."]:
    text $wprx.noproxy -font CociSmallFont -height 4 -width 24 -bd 1 -relief sunken
    
    grid  $wprx.msg  -      -            -sticky w
    grid  $wprx.use  -      -            -sticky w
    grid  x  $wprx.lmb      $wprx.mb     -pady 1
    grid  x  $wprx.lserv    $wprx.eserv  -pady 1
    grid  x  $wprx.lport    $wprx.eport  -pady 1
    grid  x  $wprx.luser    $wprx.euser  -pady 1
    grid  x  $wprx.lpass    $wprx.epass  -pady 1
    grid  x  $wprx.lnop     -            -sticky w
    grid  x  $wprx.noproxy  -            -sticky ew -pady 1
    
    grid  $wprx.lmb  $wprx.lserv  $wprx.lport  $wprx.luser  $wprx.lpass  -sticky e
    grid  $wprx.mb   $wprx.eserv               $wprx.euser  $wprx.epass  -sticky ew
    grid  $wprx.eport  -sticky w
    
    grid columnconfigure $wprx 0 -minsize 12
    
    foreach addr $tmpPrefs(noproxy) {
	$wnoproxy insert end $addr
	$wnoproxy insert end "\n"
    }
    SetUseProxyState
    return $w
}

proc ::Proxy::BuildNATFrame {w} {
    global  prefs
    variable tmpPrefs
    variable wnat
    
    set wnat $w.nat
    variable wnatuse $wnat.use

    set stun 0
    if {![catch {package require stun}]} {
	set stun 1
    }

    foreach key {
	setNATip NATip STUNServer
    } {
	set tmpPrefs($key) $prefs($key)
    }

    # NAT address.
    ttk::frame $w
    ttk::frame $wnat
    pack $wnat -side top -anchor [option get . dialogAnchor {}]

    ttk::checkbutton $wnat.use -text [mc "Use the following external address"] \
      -command [namespace code SetUseNATState]  \
      -variable [namespace current]::tmpPrefs(setNATip)
    ttk::entry $wnat.eip \
      -textvariable [namespace current]::tmpPrefs(NATip)
    if {$stun} {
	ttk::button $wnat.stun -text [mc "Detect"] -command ::Proxy::GetStun
	ttk::label $wnat.stunserverlabel -wraplength 300 \
	  -text  [mc "Use the following STUN Server to detect the external IP address"]
	ttk::entry $wnat.stunserver \
	  -textvariable [namespace current]::tmpPrefs(STUNServer)
	ttk::label $wnat.stunserverexample -text  [mc "(example: stunserver.org)"]
    }
    
    grid  $wnat.use  -  -sticky w
    grid  $wnat.eip  x  -sticky ew
    grid columnconfigure $wnat 0 -weight 1
    if {$stun} {
	grid  $wnat.stun  -column 1 -row 1 -padx 4
	grid  $wnat.stunserverlabel x -sticky ew
	grid  $wnat.stunserver x -sticky ew
	grid  $wnat.stunserverexample x -sticky ew
    }
    SetUseNATState    
    return $w
}

proc ::Proxy::GetStun {} {
    variable tmpPrefs

    ::stun::request $tmpPrefs(STUNServer) -command ::Proxy::GetStunCB -timeout 5000
}

proc ::Proxy::GetStunCB {token status args} {
    variable tmpPrefs

    array set argsA $args
    if {$status eq "ok" && [info exists argsA(-address)]} {
	set tmpPrefs(NATip) $argsA(-address)
    }   
}

proc ::Proxy::SetProxyType {type} {
    variable wuser
    variable wpass
    
    switch -- $type {
	socks5 {
	    $wuser state {!disabled}
	    $wpass state {!disabled}
	} 
	default {
	    $wuser state {disabled}
	    $wpass state {disabled}
	}
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
    variable tmpPrefs
    
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
	    TEntry - TButton - TCheckbutton - TRadiobutton - TMenubutton {
		$w state $ttkstate
	    }
	}
    }
    if {$state eq "normal"} {
	SetProxyType $tmpPrefs(proxy_type)
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
	if {$prefs(proxy_type) eq "http"} {
	    AutoProxyConfig
	    AutoSocksOff
	} elseif {[string match {socks[45]} $prefs(proxy_type)]} {
	    AutoProxyOff
	    AutoSocksConfig
	}
    } else {
	AutoProxyOff
	AutoSocksOff
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
