#  PrefNet.tcl ---
#  
#       This file is part of The Coccinella application. 
#       It implements network prefs dialogs and panel.
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
# $Id: PrefNet.tcl,v 1.13 2008-08-21 07:27:27 matben Exp $
 
package provide PrefNet 1.0

namespace eval ::PrefNet:: {

    ::hooks::register prefsInitHook          ::PrefNet::InitPrefsHook  20
    ::hooks::register prefsBuildHook         ::PrefNet::BuildPrefsHook 20
    ::hooks::register prefsSaveHook          ::PrefNet::SavePrefsHook  20
    ::hooks::register prefsCancelHook        ::PrefNet::CancelPrefsHook
    ::hooks::register prefsUserDefaultsHook  ::PrefNet::UserDefaultsHook
}

proc ::PrefNet::InitPrefsHook { } {
    global  prefs jprefs this
        
    # ip numbers, port numbers, and names.
    set prefs(thisServPort) 8235

    # The tinyhttpd server port number and base directory.
    set prefs(httpdPort) 8077
    
    set jprefs(tls,usecertfile) 0
    set jprefs(tls,certfile) ""
    set jprefs(tls,usekeyfile) 0
    set jprefs(tls,keyfile) ""
    set jprefs(tls,usecafile) 0
    set jprefs(tls,cafile) [file join $this(certificatesPath) cacerts.pem]

    ::PrefUtils::Add [list  \
      [list prefs(thisServPort)    prefs_thisServPort    $prefs(thisServPort)]   \
      [list prefs(httpdPort)       prefs_httpdPort       $prefs(httpdPort)]      \
      [list jprefs(tls,usecertfile)  jprefs_tls_usecertfile  $jprefs(tls,usecertfile)]   \
      [list jprefs(tls,certfile)     jprefs_tls_certfile     $jprefs(tls,certfile)]   \
      [list jprefs(tls,usekeyfile)   jprefs_tls_usekeyfile   $jprefs(tls,usekeyfile)]   \
      [list jprefs(tls,keyfile)      jprefs_tls_keyfile      $jprefs(tls,keyfile)]   \
      [list jprefs(tls,usecafile)   jprefs_tls_usecafile   $jprefs(tls,usecafile)]   \
      [list jprefs(tls,cafile)      jprefs_tls_cafile      $jprefs(tls,cafile)]   \
      ]    
    # in case the default certificate location is used, check whether the default 
    # certificate file is in place, if not, copy it.
    if { $jprefs(tls,cafile) eq [file join $this(certificatesPath) cacerts.pem]} {
        if {![file exists $jprefs(tls,cafile)]} { 
            file mkdir $this(certificatesPath)
	    if {[info exists ::starkit::topdir]} {
	        file copy [file join $::starkit::topdir certificates cacerts.pem] $jprefs(tls,cafile)
	    } else {
    		if {[catch {
        	    file copy [file join $this(appPath) certificates cacerts.pem] $jprefs(tls,cafile)
    		} err]} {
        	    ::Debug 2 "::PrefNet::InitPrefsHook: $err"
    		}
	    }
	}
    }
}

proc ::PrefNet::BuildPrefsHook {wtree nbframe} {
    
    if {![::Preferences::HaveTableItem General]} {
	::Preferences::NewTableItem {General} [mc "General"]
    }
    ::Preferences::NewTableItem {General {Network}} [mc "Network"]
    set wpage [$nbframe page {Network}]
    BuildTabPage $wpage
}

proc ::PrefNet::SavePrefsHook { } {
    ::Proxy::SavePrefsHook
    ServersSaveHook
}

proc ::PrefNet::CancelPrefsHook { } {
    ::Proxy::CancelPrefsHook
    NetworkCancelHook
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
    $nb add $nb.proxy -text [mc "Proxy"] -sticky news
    
    ::Proxy::BuildNATFrame $nb.nat
    $nb.nat configure -padding $padding
    $nb add $nb.nat -text [mc "NAT"] -sticky news
     
    BuildServersFrame $nb.serv
    $nb.serv configure -padding $padding
    $nb add $nb.serv -text [mc "Ports"] -sticky news

    BuildCertFrame $nb.cert
    $nb.cert configure -padding $padding
    $nb add $nb.cert -text [mc "Certificates"] -sticky news

    return $wpage
}
    
proc ::PrefNet::BuildServersFrame {w} {
    global  this prefs jprefs

    variable tmpServPrefs
    
    set tmpServPrefs(thisServPort)      $prefs(thisServPort)
    set tmpServPrefs(httpdPort)         $prefs(httpdPort)
    set tmpServPrefs(bytestreams,port)  $jprefs(bytestreams,port)

    ttk::frame $w
    
    set f $w.f
    ttk::frame $f
    pack $f -side top -anchor [option get . dialogAnchor {}]

    ttk::label $f.lserv -text [mc "Built in server"]:
    ttk::label $f.lhttp -text "HTTP:"
    ttk::label $f.lbs   -text [mc "File transfer"]:

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

proc ::PrefNet::BuildCertFrame {w} {
    global  this prefs jprefs
    variable tmpCertPrefs
    
    set tmpCertPrefs(usecertfile) $jprefs(tls,usecertfile)
    set tmpCertPrefs(certfile)    $jprefs(tls,certfile)
    set tmpCertPrefs(usekeyfile)  $jprefs(tls,usekeyfile)
    set tmpCertPrefs(keyfile)     $jprefs(tls,keyfile)
    set tmpCertPrefs(usecafile)   $jprefs(tls,usecafile)
    set tmpCertPrefs(cafile)      $jprefs(tls,cafile)
    
    ttk::frame $w
    
    set f $w.f
    ttk::frame $f
    pack $f -side top -anchor [option get . dialogAnchor {}]
    
    ttk::checkbutton $f.ccert -text [mc "TLS certificate file"] \
      -variable [namespace current]::tmpCertPrefs(usecertfile)
    ttk::entry $f.ecert -textvariable [namespace current]::tmpCertPrefs(certfile)
    ttk::button $f.bcert -text [mc "Browse"]... \
      -command [namespace code BrowseCertFile]
    
    ttk::checkbutton $f.ckey -text [mc "TLS private key file"] \
      -variable [namespace current]::tmpCertPrefs(usekeyfile)
    ttk::entry $f.ekey -textvariable [namespace current]::tmpCertPrefs(keyfile)
    ttk::button $f.bkey -text [mc "Browse"]... \
      -command [namespace code BrowseKeyFile]    
    
    ttk::checkbutton $f.cacert -text [mc "TLS CA certificate file"] \
      -variable [namespace current]::tmpCertPrefs(usecafile)
    ttk::entry $f.ecacert -textvariable [namespace current]::tmpCertPrefs(cafile)
    ttk::button $f.bcacert -text [mc "Browse"]... \
      -command [namespace code BrowseCACertFile]    

    grid  $f.ccert  -  -sticky w
    grid  $f.ecert  $f.bcert
    grid $f.ecert -sticky ew
    
    grid  $f.ckey  -  -sticky w
    grid  $f.ekey  $f.bkey
    grid $f.ekey -sticky ew
        
    grid  $f.cacert  -  -sticky w
    grid  $f.ecacert  $f.bcacert
    grid $f.ecacert -sticky ew
    return $w
}

proc ::PrefNet::BrowseCertFile {} {
    variable tmpCertPrefs
    
    set fileName [tk_getOpenFile -title [mc "TLS certificate file"] -filetypes {}]
    if {[file exists $fileName]} {
	set tmpCertPrefs(certfile) $fileName
    }
}

proc ::PrefNet::BrowseKeyFile {} {
    variable tmpCertPrefs
    
    set fileName [tk_getOpenFile -title [mc "TLS private key file"] -filetypes {}]
    if {[file exists $fileName]} {
	set tmpCertPrefs(keyfile) $fileName
    }
}

proc ::PrefNet::BrowseCACertFile {} {
    variable tmpCertPrefs
    
    set fileName [tk_getOpenFile -title [mc "TLS CA certificate file"] -filetypes {}]
    if {[file exists $fileName]} {
	set tmpCertPrefs(cafile) $fileName
    }
}

proc ::PrefNet::ServersSaveHook {} {
    global  prefs jprefs
    variable tmpServPrefs
    variable tmpCertPrefs

    set prefs(thisServPort)      $tmpServPrefs(thisServPort)
    set prefs(httpdPort)         $tmpServPrefs(httpdPort)
    set jprefs(bytestreams,port) $tmpServPrefs(bytestreams,port)   
    
    foreach key {usecertfile certfile usekeyfile keyfile usecafile cafile} {
	set jprefs(tls,$key) $tmpCertPrefs($key)
    }
    if {$jprefs(tls,usecertfile)} {
	::Jabber::Jlib tls_configure -certfile $jprefs(tls,certfile)
    }
    if {$jprefs(tls,usekeyfile)} {
	::Jabber::Jlib tls_configure -keyfile $jprefs(tls,keyfile)
    }
    if {$jprefs(tls,usecafile)} {
	::Jabber::Jlib tls_configure -cafile $jprefs(tls,cafile)
    }
}

proc ::PrefNet::NetworkCancelHook {} {
    global  prefs jprefs
    variable tmpServPrefs
    variable tmpCertPrefs

    if {![string equal $prefs(thisServPort) $tmpServPrefs(thisServPort)] || \
      ![string equal $prefs(httpdPort) $tmpServPrefs(httpdPort)] || \
      ![string equal $jprefs(bytestreams,port) $tmpServPrefs(bytestreams,port)]} {
	::Preferences::HasChanged
      }
    if {![string equal $jprefs(tls,usecertfile) $tmpCertPrefs(usecertfile)] || \
      ![string equal $jprefs(tls,certfile) $tmpCertPrefs(certfile)] || \
      ![string equal $jprefs(tls,usekeyfile) $tmpCertPrefs(usekeyfile)] || \
      ![string equal $jprefs(tls,keyfile) $tmpCertPrefs(keyfile)] || \
      ![string equal $jprefs(tls,usecafile) $tmpCertPrefs(usecafile)] || \
      ![string equal $jprefs(tls,cafile) $tmpCertPrefs(cafile)]} {
	::Preferences::HasChanged
     }
}

proc ::PrefNet::ServersUserDefaultsHook {} {
    global  prefs jprefs
    variable tmpServPrefs

    set tmpServPrefs(thisServPort)      $prefs(thisServPort)
    set tmpServPrefs(httpdPort)         $prefs(httpdPort)
    set tmpServPrefs(bytestreams,port)  $jprefs(bytestreams,port)    
}

proc ::PrefNet::ServersFree {} {
    variable tmpServPrefs
    unset -nocomplain tmpServPrefs
}
    
#-------------------------------------------------------------------------------
