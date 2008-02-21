#  jlibdns.tcl --
#  
#      This file is part of the jabberlib. 
#      It provides support for XEP-0156: 
#          A DNS TXT Resource Record Format for XMPP Connection Methods 
#      and client DNS SRV records (XMPP Core sect. 14.3)
#      
#  Copyright (c) 2006-2008  Mats Bengtsson
#  
# This file is distributed under BSD style license.
#  
# $Id: jlibdns.tcl,v 1.6 2008-02-21 15:00:39 matben Exp $
# 
############################# USAGE ############################################
#
#   NAME
#      jlib::dns - library for DNS lookups
#      
#   SYNOPSIS
#      jlib::dns::get_addr_port domain cmd
#      jlib::dns::get_http_bind_url domain cmd   OUTDATED
#      jlib::dns::get_http_poll_url domain cmd
#      jlib::dns::get_http_bosh_url domain cmd
#
############################# 7.1.2 Initial Registration #######################
#
# <method>
#   <name>_xmpp-client-httppoll</name>
#   <desc>HTTP Polling connection method</desc>
#   <syntax>
#     The http: or https: URL at which to contact the HTTP Polling connection manager or proxy
#   </syntax>
#   <doc>XEP-0025</doc>
# </method>
# 
# <method>
#   <name>_xmpp-client-xbosh</name>
#   <desc>XMPP Over Bosh connection method</desc>
#   <syntax>
#     The http: or https: URL at which to contact the HTTP Binding connection manager or proxy
#   </syntax>
#   <doc>XEP-0206</doc>
# </method>

package require dns 9.9    ;# Fake version to avoid loding buggy version.
package require jlib

package provide jlib::dns 0.1

namespace eval jlib::dns {
    
    variable owner
    array set owner {
	client      _xmpp-client._tcp
	poll        _xmppconnect
    }

    variable nameA
    array set nameA {
	bind        _xmpp-client-httpbind
	bosh        _xmpp-client-xbosh
	poll        _xmpp-client-httppoll
    }
}

proc jlib::dns::get_addr_port {domain cmd args} {
    
    # dns::resolve my throw error!
    set name _xmpp-client._tcp.$domain
    return [eval {dns::resolve $name -type SRV  \
      -command [list [namespace current]::addr_cb $cmd]} $args]
}

proc jlib::dns::addr_cb {cmd token} {
        
    set addrList {}
    if {[dns::status $token] eq "ok"} {
	set result [dns::result $token]
	foreach reply $result {
	    array unset rr
	    array set rr $reply
	    if {[info exists rr(rdata)]} {
		array unset rd
		array set rd $rr(rdata)
		if {[info exists rd(priority)] &&  \
		  [info exists rd(weight)] &&      \
		  [info exists rd(port)] &&        \
		  [info exists rd(target)] &&      \
		  [isUInt16 $rd(priority)] &&      \
		  [isUInt16 $rd(weight)] &&        \
		  [isUInt16 $rd(port)] &&          \
		  ($rd(target) ne ".")} {
		    if {$rd(weight) == 0} {
			set n 0
		    } else {
			set n [expr {($rd(weight)+1)*rand()}]
		    }
		    set priority [expr {$rd(priority)*65536 - $n}]
		    lappend addrList [list $priority $rd(target) $rd(port)]
		}
	    }	    
	}
	if {[llength $addrList]} {
	    set addrPort {}
	    foreach p [lsort -real -index 0 $addrList] {
		lappend addrPort [lrange $p 1 2]
	    }
	    uplevel #0 $cmd [list $addrPort]
	} else {
	    uplevel #0 $cmd [list {} dns-empty]
	}
    } else {
	uplevel #0 $cmd [list {} [dns::error $token]]
    }
    
    # Weird bug!
    #after 2000 [list dns::cleanup $token]
}

proc jlib::dns::isUInt16 {n} {
    return [expr {[string is integer -strict $n] && $n >= 0 && $n < 65536}  \
      ? 1 : 0]
}

proc jlib::dns::get_http_bind_url {domain cmd} {    
    set name _xmppconnect.$domain
    return [dns::resolve $name -type TXT  \
      -command [list [namespace current]::http_cb bind $cmd]]
}

proc jlib::dns::get_http_bosh_url {domain cmd args} {
    set name _xmppconnect.$domain
    return [eval {dns::resolve $name -type TXT  \
      -command [list [namespace current]::http_cb bosh $cmd]} $args]
}

proc jlib::dns::get_http_poll_url {domain cmd args} {
    set name _xmppconnect.$domain
    return [eval {dns::resolve $name -type TXT  \
      -command [list [namespace current]::http_cb poll $cmd]} $args]
}

proc jlib::dns::http_cb {attr cmd token} {
    variable nameA
        
    set found 0
    if {[dns::status $token] eq "ok"} {
	set result [dns::result $token]
	foreach reply $result {
	    array unset rr
	    array set rr $reply
	    if {[info exists rr(rdata)]} {
		if {[regexp "$nameA($attr)=(.*)" $rr(rdata) - url]} {
		    set found 1
		    uplevel #0 $cmd [list $url]
		}
	    }
	}
	if {!$found} {
	    uplevel #0 $cmd [list {} dns-no-resource-record]
	}
    } else {
	uplevel #0 $cmd [list {} [dns::error $token]]
    }

    # Weird bug!
    #after 2000 [list dns::cleanup $token]
}

proc jlib::dns::reset {token} {    
    dns::reset $token
    dns::cleanup $token
}

# Test
if {0} {
    proc cb {args} {puts "---> $args"}
    jlib::dns::get_addr_port gmail.com cb
    jlib::dns::get_addr_port jabber.ru cb
    jlib::dns::get_addr_port jabber.com cb
    # Missing 
    jlib::dns::get_http_poll_url gmail.com cb    
    jlib::dns::get_http_poll_url jabber.ru cb    
    jlib::dns::get_http_poll_url ham9.net cb    
}
